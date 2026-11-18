import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../auth_routes.dart';

enum _ResetStep { email, otp, newPassword, done }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);
    // Le formulaire e-mail n'est dans l'arbre que lors de l'étape `email`.
    // Depuis l'étape OTP ("Renvoyer le code"), on saute la validation du Form.
    final emailForm = _emailFormKey.currentState;
    if (emailForm != null && !emailForm.validate()) return;
    // Sécurité : si l'e-mail est vide (ne devrait jamais arriver), on ne fait rien.
    if (_emailCtrl.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(sessionProvider.notifier).requestPasswordReset(_emailCtrl.text);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = _ResetStep.otp;
      });
      AppSnackbar.success(context, 'Un code à 6 chiffres a été envoyé sur votre adresse e-mail.');
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

  Future<void> _verifyOtp() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(sessionProvider.notifier).verifyResetOtp(
        email: _emailCtrl.text,
        code: _otpCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = _ResetStep.newPassword;
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

  Future<void> _submitNewPassword() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(sessionProvider.notifier).resetPassword(
        email: _emailCtrl.text,
        code: _otpCtrl.text,
        password: _passCtrl.text,
        passwordConfirmation: _confirmCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = _ResetStep.done;
      });
      AppSnackbar.success(context, 'Votre mot de passe a été réinitialisé avec succès.');
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
          child: switch (_step) {
            _ResetStep.email => _buildEmailStep(context),
            _ResetStep.otp => _buildOtpStep(context),
            _ResetStep.newPassword => _buildNewPasswordStep(context),
            _ResetStep.done => _buildDoneStep(context),
          },
        ),
      ),
    ),
  );

  Widget _buildEmailStep(BuildContext context) => Form(
    key: _emailFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Mot de passe oublié ?', style: context.text.headlineSmall),
        AppSpacing.gapXs,
        Text(
          'Indiquez votre adresse e-mail pour recevoir un code de vérification à 6 chiffres (OTP).',
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
          label: 'Adresse e-mail',
          hint: 'prenom.nom@univ.fr',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.compose([Validators.required(), Validators.email()]),
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Envoyer le code',
          icon: Icons.send_rounded,
          isLoading: _isLoading,
          expand: true,
          onPressed: _sendOtp,
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
  );

  Widget _buildOtpStep(BuildContext context) => Form(
    key: _otpFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pin_outlined, size: 38, color: context.colors.primary),
          ),
        ),
        AppSpacing.gapLg,
        Text(
          'Vérification du code OTP',
          style: context.text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXs,
        Text(
          'Saisissez le code à 6 chiffres envoyé à :\n${_emailCtrl.text.trim()}',
          style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXl,
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            style: context.text.bodySmall?.copyWith(color: context.colors.error),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapMd,
        ],
        AppTextField(
          controller: _otpCtrl,
          label: 'Code à 6 chiffres',
          hint: '123456',
          prefixIcon: Icons.lock_clock_outlined,
          keyboardType: TextInputType.number,
          maxLength: 6,
          validator: (v) {
            final clean = v?.trim() ?? '';
            if (clean.isEmpty) return 'Veuillez saisir le code reçu';
            if (!RegExp(r'^\d{6}$').hasMatch(clean)) {
              return 'Le code doit contenir exactement 6 chiffres';
            }
            return null;
          },
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Valider le code',
          icon: Icons.verified_outlined,
          isLoading: _isLoading,
          expand: true,
          onPressed: _verifyOtp,
        ),
        AppSpacing.gapSm,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _isLoading ? null : _sendOtp,
              child: const Text('Renvoyer le code'),
            ),
            const Text('•'),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                        _errorMessage = null;
                        _step = _ResetStep.email;
                      }),
              child: const Text('Modifier l\'e-mail'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildNewPasswordStep(BuildContext context) => Form(
    key: _resetFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.colors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.verified_user_rounded, size: 38, color: context.colors.success),
          ),
        ),
        AppSpacing.gapLg,
        Text(
          'Nouveau mot de passe',
          style: context.text.headlineSmall,
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXs,
        Text(
          'Votre code OTP est validé. Choisissez maintenant votre nouveau mot de passe.',
          style: context.text.bodyMedium?.copyWith(color: context.colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXl,
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            style: context.text.bodySmall?.copyWith(color: context.colors.error),
            textAlign: TextAlign.center,
          ),
          AppSpacing.gapMd,
        ],
        AppPasswordField(
          controller: _passCtrl,
          label: 'Nouveau mot de passe',
          validator: Validators.password(),
        ),
        AppSpacing.gapMd,
        AppPasswordField(
          controller: _confirmCtrl,
          label: 'Confirmer le mot de passe',
          validator: (v) => v != _passCtrl.text ? 'Les mots de passe ne correspondent pas' : null,
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Réinitialiser le mot de passe',
          icon: Icons.lock_reset_rounded,
          isLoading: _isLoading,
          expand: true,
          onPressed: _submitNewPassword,
        ),
      ],
    ),
  );

  Widget _buildDoneStep(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: context.colors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_circle_rounded, size: 44, color: context.colors.success),
        ),
      ),
      AppSpacing.gapLg,
      Text(
        'Mot de passe mis à jour !',
        style: context.text.headlineSmall,
        textAlign: TextAlign.center,
      ),
      AppSpacing.gapSm,
      Text(
        'Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
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
  );
}
