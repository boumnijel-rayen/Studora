import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _universityCtrl;
  late final TextEditingController _programCtrl;
  late final TextEditingController _bioCtrl;
  late int _year;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final u = ref.read(currentUserProvider);
    _firstNameCtrl = TextEditingController(text: u?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: u?.lastName ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _phoneCtrl = TextEditingController(text: u?.phone ?? '');
    _universityCtrl = TextEditingController(text: u?.university ?? '');
    _programCtrl = TextEditingController(text: u?.program ?? '');
    _bioCtrl = TextEditingController(text: u?.bio ?? '');
    _year = u?.year ?? 1;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _universityCtrl.dispose();
    _programCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final current = ref.read(currentUserProvider);
    if (current == null) {
      AppSnackbar.error(context, 'Session expirée. Veuillez vous reconnecter.');
      return;
    }

    setState(() => _isLoading = true);

    final updated = current.copyWith(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      university: _universityCtrl.text.trim(),
      program: _programCtrl.text.trim(),
      year: _year,
      bio: _bioCtrl.text.trim(),
    );

    try {
      await ref.read(sessionProvider.notifier).updateProfile(updated);
      if (!mounted) return;
      AppSnackbar.success(context, 'Profil mis à jour avec succès !');
      Navigator.pop(context);
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
    title: 'Modifier le profil',
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
                Center(
                  child: AppAvatar(
                    name: '${_firstNameCtrl.text} ${_lastNameCtrl.text}'.trim(),
                    size: AppSizes.avatarXl,
                  ),
                ),
                AppSpacing.gapLg,
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: context.text.bodySmall?.copyWith(color: context.colors.error),
                  ),
                  AppSpacing.gapMd,
                ],
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _firstNameCtrl,
                        label: 'Prénom',
                        validator: Validators.required(),
                      ),
                    ),
                    AppSpacing.gapSm,
                    Expanded(
                      child: AppTextField(
                        controller: _lastNameCtrl,
                        label: 'Nom',
                        validator: Validators.required(),
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapMd,
                AppTextField(
                  controller: _emailCtrl,
                  label: 'E-mail universitaire',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.compose([Validators.required(), Validators.email()]),
                ),
                AppSpacing.gapMd,
                AppTextField(
                  controller: _phoneCtrl,
                  label: 'Téléphone',
                  keyboardType: TextInputType.phone,
                ),
                AppSpacing.gapMd,
                AppTextField(
                  controller: _universityCtrl,
                  label: 'Université / Établissement',
                  validator: Validators.required(),
                ),
                AppSpacing.gapMd,
                AppTextField(
                  controller: _programCtrl,
                  label: 'Filière / Programme',
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
                AppTextField(
                  controller: _bioCtrl,
                  label: 'Bio / Description personnelle',
                  maxLines: 3,
                ),
                AppSpacing.gapXl,
                AppButton(
                  label: 'Enregistrer les modifications',
                  icon: Icons.check_rounded,
                  isLoading: _isLoading,
                  expand: true,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
