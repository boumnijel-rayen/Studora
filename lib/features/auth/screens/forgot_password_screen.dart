import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../auth_routes.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(sessionProvider.notifier).requestPasswordReset(_emailCtrl.text);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _sent = true;
      });
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
    title: 'Récupération',
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxFormWidth),
          child: _sent
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: context.colors.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mark_email_read_rounded, size: 44, color: context.colors.success),
                    ),
                    AppSpacing.gapLg,
                    Text('E-mail envoyé !', style: context.text.headlineSmall, textAlign: TextAlign.center),
                    AppSpacing.gapSm,
                    Text(
                      'Un lien de réinitialisation sécurisé a été envoyé à :\n${_emailCtrl.text}',
                      style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapXl,
                    AppButton(
                      label: 'Retour à la connexion',
                      expand: true,
                      onPressed: () => context.go(AuthRoutes.login),
                    ),
                  ],
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Mot de passe oublié ?', style: context.text.headlineSmall),
                      AppSpacing.gapXs,
                      Text(
                        'Indiquez votre adresse e-mail universitaire pour recevoir les instructions de réinitialisation.',
                        style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
                      ),
                      AppSpacing.gapXl,
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: context.text.bodySmall?.copyWith(color: context.colors.error),
                        ),
                        AppSpacing.gapMd,
                      ],
                      AppTextField(
                        controller: _emailCtrl,
                        label: 'Adresse e-mail universitaire',
                        hint: 'prenom.nom@univ.fr',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.compose([Validators.required(), Validators.email()]),
                      ),
                      AppSpacing.gapLg,
                      AppButton(
                        label: 'Envoyer le lien',
                        icon: Icons.send_rounded,
                        isLoading: _isLoading,
                        expand: true,
                        onPressed: _submit,
                      ),
                      AppSpacing.gapSm,
                      Center(
                        child: TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Annuler et revenir'),
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
