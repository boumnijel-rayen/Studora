import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../providers/roommates_providers.dart';

/// Affiché tant que l'utilisateur n'appartient à aucun groupe de colocation.
class ColocationSetupScreen extends ConsumerStatefulWidget {
  const ColocationSetupScreen({super.key});

  @override
  ConsumerState<ColocationSetupScreen> createState() => _ColocationSetupScreenState();
}

class _ColocationSetupScreenState extends ConsumerState<ColocationSetupScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  int _tabIndex = 0; // 0 = Rejoindre, 1 = Créer
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _detailsCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving || !_createFormKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final created = await ref.read(colocationAsyncProvider.notifier).create(
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        details: _detailsCtrl.text.trim(),
      );
      if (!mounted) return;
      AppSnackbar.success(context, 'Groupe « ${created.name} » créé !');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, ApiException.fromError(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _join() async {
    if (_saving || !_joinFormKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final joined = await ref.read(colocationAsyncProvider.notifier).join(code: _codeCtrl.text);
      if (!mounted) return;
      AppSnackbar.success(context, 'Bienvenue dans « ${joined.name} » !');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, ApiException.fromError(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Colocation',
    subtitle: 'Vous n\'avez pas encore de groupe',
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        AppSegmentedControl<int>(
          segments: const {0: 'Rejoindre', 1: 'Créer'},
          selected: _tabIndex,
          onChanged: (i) => setState(() => _tabIndex = i),
        ),
        AppSpacing.gapLg,
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _tabIndex == 0 ? _buildJoinForm() : _buildCreateForm(),
        ),
      ],
    ),
  );

  Widget _buildJoinForm() => Form(
    key: _joinFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Rejoindre un groupe', style: context.text.titleMedium),
        AppSpacing.gapXs,
        Text(
          'Demandez la clé d\'invitation au propriétaire du groupe.',
          style: context.text.bodySmall,
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _codeCtrl,
          label: 'Clé d\'invitation',
          hint: 'ex: AB3D5F7H',
          prefixIcon: Icons.key_rounded,
          validator: Validators.required(),
          onSubmitted: (_) => _join(),
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Rejoindre le groupe',
          icon: Icons.login_rounded,
          isLoading: _saving,
          expand: true,
          onPressed: _join,
        ),
      ],
    ),
  );

  Widget _buildCreateForm() => Form(
    key: _createFormKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Créer un groupe', style: context.text.titleMedium),
        AppSpacing.gapXs,
        Text(
          'Vous en serez le propriétaire et recevrez une clé à partager avec vos colocataires.',
          style: context.text.bodySmall,
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _nameCtrl,
          label: 'Nom du groupe',
          hint: 'ex: Appart Victor Hugo',
          prefixIcon: Icons.home_rounded,
          validator: Validators.required(),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _addressCtrl,
          label: 'Adresse',
          hint: 'ex: 12 rue Victor Hugo, Tunis',
          prefixIcon: Icons.location_on_outlined,
          validator: Validators.required(),
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _detailsCtrl,
          label: 'Informations complémentaires (facultatif)',
          hint: 'ex: Étage 3, code de la porte, règles de la maison...',
          maxLines: 3,
        ),
        AppSpacing.gapLg,
        AppButton(
          label: 'Créer le groupe',
          icon: Icons.add_home_rounded,
          isLoading: _saving,
          expand: true,
          onPressed: _create,
        ),
      ],
    ),
  );
}
