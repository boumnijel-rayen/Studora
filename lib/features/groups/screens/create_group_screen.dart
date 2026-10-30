import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/group_models.dart';
import '../providers/groups_providers.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedSubjectId;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final subjects = ref.read(subjectsProvider);
    if (!_formKey.currentState!.validate() || _selectedSubjectId == null) {
      if (_selectedSubjectId == null) {
        AppSnackbar.error(context, 'Veuillez choisir ou créer une matière');
      }
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      AppSnackbar.error(context, 'Session expirée. Veuillez vous reconnecter.');
      return;
    }

    final subject = subjects.where((s) => s.id == _selectedSubjectId).firstOrNull;
    if (subject == null) return;

    setState(() => _isSaving = true);

    final group = StudyGroup(
      id: '',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      subjectId: subject.id,
      subjectName: subject.name,
      memberNames: [user.fullName],
      code: '', // Généré par le serveur.
      colorIndex: subject.colorIndex,
      isJoined: true,
    );

    try {
      final created = await ref.read(groupsAsyncProvider.notifier).addGroup(group);
      if (!mounted) return;
      AppSnackbar.success(context, 'Groupe créé avec succès ! Code : ${created.code}');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, ApiException.fromError(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
    final validSubjectId = subjects.any((s) => s.id == _selectedSubjectId) ? _selectedSubjectId : null;

    return AppScaffold(
      title: 'Créer un groupe',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _nameCtrl,
                label: 'Nom du groupe',
                hint: 'ex: Entraide Algorithmique Promo 2026',
                validator: Validators.required(),
              ),
              AppSpacing.gapMd,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppDropdownField<String>(
                      label: 'Matière associée',
                      value: validSubjectId,
                      hint: subjects.isEmpty ? 'Créez d\'abord une matière →' : 'Sélectionner une matière',
                      items: subjects.map((s) => s.id).toList(),
                      itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
                      onChanged: (v) => setState(() => _selectedSubjectId = v),
                    ),
                  ),
                  AppSpacing.gapXs,
                  IconButton.filledTonal(
                    tooltip: 'Nouvelle matière',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () async {
                      final created = await showCreateSubjectSheet(context, ref);
                      if (created != null && mounted) {
                        setState(() => _selectedSubjectId = created.id);
                      }
                    },
                  ),
                ],
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _descCtrl,
                label: 'Description & Objectifs du groupe',
                hint: 'Règles, fréquence de travail, préparation partiels...',
                maxLines: 3,
                validator: Validators.required(),
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Créer le groupe d\'étude',
                icon: Icons.check_rounded,
                isLoading: _isSaving,
                expand: true,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
