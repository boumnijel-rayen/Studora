import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../auth_routes.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  int _step = 1;
  bool _isLoading = false;
  String? _errorMessage;

  // Étape 1 : Identité
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Étape 2 : Cursus & Sécurité
  final _universityCtrl = TextEditingController();
  final _programCtrl = TextEditingController();
  int _year = 1;
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  // Étape 3 : Formule d'abonnement
  PlanTier _selectedPlan = PlanTier.core;
  AppUser? _registeredUser;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _universityCtrl.dispose();
    _programCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  /// Active la session utilisateur et redirige vers l'accueil une fois l'inscription
  /// (et l'éventuel paiement Stripe) terminée.
  Future<void> _completeRegistrationAndGoHome(AppUser user) async {
    ref.read(sessionProvider.notifier).signIn(user);
    await ref.read(preferencesProvider.notifier).fetchFromBackend();
    await ref.read(subscriptionProvider.notifier).fetchFromBackend();
    if (!mounted) return;
    context.go('/home');
  }

  /// Sélectionne un plan à l'étape 3. Si le plan est payant (Plus ou Ultimate),
  /// déclenche automatiquement la création du compte et l'ouverture de Stripe PaymentSheet.
  Future<void> _onPlanSelected(PlanTier tier) async {
    if (_isLoading) return;
    setState(() {
      _selectedPlan = tier;
      _errorMessage = null;
    });
    if (tier.isPaid) {
      await _submit();
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);

    if (_step < 3) {
      if (!_formKey.currentState!.validate()) return;
      setState(() => _step += 1);
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Crée le compte sans activer immédiatement `sessionProvider` afin que GoRouter
      // ne redirige pas vers `/home` avant l'ouverture de la PaymentSheet Stripe.
      final user = _registeredUser ??
          await ref.read(sessionProvider.notifier).register(
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            university: _universityCtrl.text.trim(),
            program: _programCtrl.text.trim(),
            year: _year,
            password: _passCtrl.text,
            activateSession: false,
          );
      _registeredUser = user;

      // Plan gratuit Core : accès direct sans paiement
      if (!_selectedPlan.isPaid) {
        if (!mounted) return;
        AppSnackbar.success(
          context,
          'Compte créé avec succès ! Bienvenue ${user.firstName}',
        );
        await _completeRegistrationAndGoHome(user);
        return;
      }

      // Plan payant Plus ou Ultimate : ouverture automatique de Stripe PaymentSheet
      final prefs = ref.read(preferencesProvider);
      final result = await ref
          .read(subscriptionProvider.notifier)
          .selectPlan(_selectedPlan, themeMode: prefs.themeMode);

      if (!mounted) return;
      switch (result) {
        case PlanChangeResult.activated:
          AppSnackbar.success(
            context,
            'Bienvenue ${user.firstName} ! Votre abonnement ${_selectedPlan.name} est actif.',
          );
          await _completeRegistrationAndGoHome(user);
        case PlanChangeResult.confirmationPending:
          AppSnackbar.info(
            context,
            'Paiement envoyé. Votre abonnement ${_selectedPlan.name} sera activé dès confirmation Stripe.',
          );
          await _completeRegistrationAndGoHome(user);
        case PlanChangeResult.paymentCanceled:
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Le paiement a été annulé. Touchez à nouveau le plan ${_selectedPlan.name} pour réessayer ou continuez avec le plan gratuit Core.';
          });
        case PlanChangeResult.scheduledCancellation:
        case PlanChangeResult.resumed:
          await _completeRegistrationAndGoHome(user);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
      AppSnackbar.error(context, e.message);
    } catch (e) {
      if (!mounted) return;
      final err = ApiException.fromError(e);
      setState(() {
        _isLoading = false;
        _errorMessage = err.message;
      });
      AppSnackbar.error(context, err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(subscriptionCatalogProvider);
    final plans =
        catalogAsync.asData?.value ??
        PlanTier.values.map(SubscriptionPlanInfo.fromTier).toList();

    final primaryButtonLabel = switch (_step) {
      1 || 2 => 'Continuer',
      _ => _selectedPlan.isPaid
          ? 'Payer ${_selectedPlan.shortPriceLabel} et activer ${_selectedPlan.name}'
          : 'Continuer gratuitement avec Core',
    };

    return AppScaffold(
      title: 'Inscription',
      subtitle: 'Étape $_step sur 3',
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxFormWidth),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Barre de progression en 3 étapes
                  Row(
                    children: [
                      for (var i = 1; i <= 3; i++) ...[
                        if (i > 1) AppSpacing.gapXs,
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: _step >= i
                                  ? context.colors.primary
                                  : context.colors.border,
                              borderRadius: AppRadius.brFull,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.gapLg,

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: context.colors.error.withValues(alpha: 0.1),
                        borderRadius: AppRadius.brMd,
                        border: Border.all(
                          color: context.colors.error.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: context.colors.error,
                            size: 20,
                          ),
                          AppSpacing.gapXs,
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppSpacing.gapMd,
                  ],

                  if (_step == 1) ...[
                    Text('Informations personnelles', style: context.text.titleLarge),
                    AppSpacing.gapXxs,
                    Text(
                      'Dites-nous qui vous êtes pour personnaliser votre espace.',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    AppSpacing.gapLg,
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _firstNameCtrl,
                            label: 'Prénom',
                            hint: 'ex: Camille',
                            validator: Validators.required(),
                          ),
                        ),
                        AppSpacing.gapSm,
                        Expanded(
                          child: AppTextField(
                            controller: _lastNameCtrl,
                            label: 'Nom',
                            hint: 'ex: Martin',
                            validator: Validators.required(),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                    AppTextField(
                      controller: _emailCtrl,
                      label: 'Adresse e-mail universitaire',
                      hint: 'prenom.nom@univ.fr',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.compose([
                        Validators.required(),
                        Validators.email(),
                      ]),
                    ),
                    AppSpacing.gapMd,
                    AppTextField(
                      controller: _phoneCtrl,
                      label: 'Numéro de téléphone (optionnel)',
                      hint: '06 12 34 56 78',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                  ] else if (_step == 2) ...[
                    Text('Cursus & Sécurité', style: context.text.titleLarge),
                    AppSpacing.gapXxs,
                    Text(
                      'Configurez votre université et vos identifiants.',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    AppSpacing.gapLg,
                    AppTextField(
                      controller: _universityCtrl,
                      label: 'Université / École',
                      hint: 'ex: Sorbonne Université',
                      prefixIcon: Icons.account_balance_outlined,
                      validator: Validators.required(),
                    ),
                    AppSpacing.gapMd,
                    AppTextField(
                      controller: _programCtrl,
                      label: 'Filière / Spécialité',
                      hint: 'ex: Licence Informatique',
                      prefixIcon: Icons.school_outlined,
                      validator: Validators.required(),
                    ),
                    AppSpacing.gapMd,
                    AppDropdownField<int>(
                      label: 'Année d\'études',
                      value: _year,
                      items: const [1, 2, 3, 4, 5],
                      itemLabel: (y) => 'Année $y (Bac+$y)',
                      onChanged: (v) => setState(() => _year = v ?? 1),
                    ),
                    AppSpacing.gapMd,
                    AppPasswordField(
                      controller: _passCtrl,
                      label: 'Mot de passe',
                      validator: Validators.password(),
                    ),
                    AppSpacing.gapMd,
                    AppPasswordField(
                      controller: _confirmPassCtrl,
                      label: 'Confirmer le mot de passe',
                      validator: Validators.match(
                        () => _passCtrl.text,
                        'Les mots de passe ne correspondent pas',
                      ),
                    ),
                  ] else ...[
                    Text('Choisissez votre formule', style: context.text.titleLarge),
                    AppSpacing.gapXxs,
                    Text(
                      'Sélectionnez un plan payant pour ouvrir directement le paiement sécurisé Stripe, ou choisissez le plan gratuit Core.',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    AppSpacing.gapLg,
                    for (final planInfo in plans) ...[
                      SubscriptionPlanCard(
                        planInfo: planInfo,
                        isSelected: _selectedPlan == planInfo.tier,
                        isActionLoading: _isLoading && _selectedPlan == planInfo.tier,
                        onTap: _isLoading
                            ? null
                            : () => _onPlanSelected(planInfo.tier),
                      ),
                      AppSpacing.gapSm,
                    ],
                  ],

                  AppSpacing.gapXl,
                  Row(
                    children: [
                      if (_step > 1 && _registeredUser == null) ...[
                        Expanded(
                          child: AppButton(
                            label: 'Précédent',
                            variant: AppButtonVariant.secondary,
                            onPressed: _isLoading
                                ? null
                                : () => setState(() => _step -= 1),
                          ),
                        ),
                        AppSpacing.gapSm,
                      ],
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: primaryButtonLabel,
                          isLoading: _isLoading,
                          expand: true,
                          onPressed: _submit,
                        ),
                      ),
                    ],
                  ),
                  if (_registeredUser != null && _selectedPlan.isPaid) ...[
                    AppSpacing.gapSm,
                    Center(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => _completeRegistrationAndGoHome(_registeredUser!),
                        child: const Text('Continuer avec le plan gratuit Core'),
                      ),
                    ),
                  ],
                  AppSpacing.gapMd,
                  if (_registeredUser == null)
                    Center(
                      child: TextButton(
                        onPressed: () => context.go(AuthRoutes.login),
                        child: const Text('Déjà un compte ? Se connecter'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
