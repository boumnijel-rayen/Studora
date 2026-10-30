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

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    if (_step == 1) {
      setState(() => _step = 2);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final newUser = await ref.read(sessionProvider.notifier).register(
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        university: _universityCtrl.text.trim(),
        program: _programCtrl.text.trim(),
        year: _year,
        password: _passCtrl.text,
      );

      if (!mounted) return;
      AppSnackbar.success(context, 'Compte créé avec succès ! Bienvenue ${newUser.firstName} 🎉');
      context.go('/home');
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
  Widget build(BuildContext context) => AppScaffold(
    title: 'Inscription',
    subtitle: 'Étape $_step sur 2',
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
                // Barre d'étape
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          borderRadius: AppRadius.brFull,
                        ),
                      ),
                    ),
                    AppSpacing.gapXs,
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _step == 2 ? context.colors.primary : context.colors.border,
                          borderRadius: AppRadius.brFull,
                        ),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapLg,

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: context.colors.error.withValues(alpha: 0.1),
                      borderRadius: AppRadius.brMd,
                      border: Border.all(color: context.colors.error.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: context.colors.error, size: 20),
                        AppSpacing.gapXs,
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: context.text.bodySmall?.copyWith(color: context.colors.error),
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
                    style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
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
                    validator: Validators.compose([Validators.required(), Validators.email()]),
                  ),
                  AppSpacing.gapMd,
                  AppTextField(
                    controller: _phoneCtrl,
                    label: 'Numéro de téléphone (optionnel)',
                    hint: '06 12 34 56 78',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                ] else ...[
                  Text('Cursus & Sécurité', style: context.text.titleLarge),
                  AppSpacing.gapXxs,
                  Text(
                    'Configurez votre université et vos identifiants.',
                    style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
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
                ],

                AppSpacing.gapXl,
                Row(
                  children: [
                    if (_step == 2) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Précédent',
                          variant: AppButtonVariant.secondary,
                          onPressed: () => setState(() => _step = 1),
                        ),
                      ),
                      AppSpacing.gapSm,
                    ],
                    Expanded(
                      child: AppButton(
                        label: _step == 1 ? 'Continuer' : 'Finaliser',
                        isLoading: _isLoading,
                        expand: true,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapMd,
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
