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
  final _emailCtrl = TextEditingController(text: 'rayen.benali@univ.fr');
  final _passCtrl = TextEditingController(text: 'Studora2026!');
  bool _isLoading = false;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    ref.read(sessionProvider.notifier).signIn(MockSharedData.demoUser);
    AppSnackbar.success(context, 'Ravi de vous revoir, ${MockSharedData.demoUser.firstName} !');
    context.go('/home');
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

                  // Champs de formulaire
                  AppTextField(
                    controller: _emailCtrl,
                    label: 'Adresse e-mail universitaire',
                    hint: 'prenom.nom@univ.fr',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.compose([
                      Validators.required('Veuillez saisir votre e-mail'),
                      Validators.email(),
                    ]),
                  ),
                  AppSpacing.gapMd,
                  AppPasswordField(
                    controller: _passCtrl,
                    label: 'Mot de passe',
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
                  AppSpacing.gapSm,

                  // Remplissage rapide Démo
                  AppButton(
                    label: 'Remplir compte Démo',
                    variant: AppButtonVariant.ghost,
                    icon: Icons.flash_on_rounded,
                    onPressed: () {
                      _emailCtrl.text = 'rayen.benali@univ.fr';
                      _passCtrl.text = 'Studora2026!';
                    },
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
