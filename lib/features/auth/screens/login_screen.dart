import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../auth_routes.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = await ref.read(sessionProvider.notifier).login(
        identifier: _emailCtrl.text,
        password: _passCtrl.text,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;
      AppSnackbar.success(context, 'Ravi de vous revoir, ${user.firstName.isNotEmpty ? user.firstName : user.fullName} !');
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.background,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.maxFormWidth),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: AppRadius.brXl,
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 38),
                    ),
                  ),
                  AppSpacing.gapMd,
                  Text(
                    'Connexion',
                    style: context.text.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXxs,
                  Text(
                    'Accédez à votre espace d\'études Studora',
                    style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.gapXl,

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

                  // Champs de formulaire
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Adresse e-mail universitaire',
                    hint: 'prenom.nom@univ.fr',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.compose([
                      Validators.required('Veuillez saisir votre e-mail'),
                      Validators.email(),
                    ]),
                  ),
                  AppSpacing.gapMd,
                  AppPasswordField(
                    controller: _passCtrl,
                    label: 'Mot de passe',
                    onSubmitted: (_) => _submit(),
                    validator: Validators.required('Veuillez saisir votre mot de passe'),
                  ),
                  AppSpacing.gapSm,

                  // Se souvenir de moi & Mot de passe oublié
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v ?? false),
                          ),
                          Text('Se souvenir', style: context.text.bodyMedium),
                        ],
                      ),
                      TextButton(
                        onPressed: () => context.push(AuthRoutes.forgotPassword),
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ],
                  ),
                  AppSpacing.gapLg,

                  // Bouton Se connecter
                  AppButton(
                    label: 'Se connecter',
                    icon: Icons.login_rounded,
                    expand: true,
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                  AppSpacing.gapXl,

                  // Lien d'inscription
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Pas encore de compte ?', style: context.text.bodyMedium),
                      TextButton(
                        onPressed: () => context.push(AuthRoutes.register),
                        child: const Text('Créer un compte'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
