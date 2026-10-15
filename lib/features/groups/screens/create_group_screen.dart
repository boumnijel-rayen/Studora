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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _selectedSubjectId == null) {
      if (_selectedSubjectId == null) {
        AppSnackbar.error(context, 'Veuillez choisir une matière');
      }
      return;
    }

    final subject = MockSharedData.subjects.firstWhere((s) => s.id == _selectedSubjectId);
    final user = ref.read(currentUserProvider) ?? MockSharedData.demoUser;
    final code = '${subject.shortName.toUpperCase().substring(0, 3)}${DateTime.now().millisecond % 99}';

    final group = StudyGroup(
      id: 'g-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      subjectId: subject.id,
      subjectName: subject.name,
      memberNames: [user.fullName],
      code: code,
      colorIndex: subject.colorIndex,
      isJoined: true,
    );

    ref.read(groupsProvider.notifier).addGroup(group);
    AppSnackbar.success(context, 'Groupe créé avec succès ! Code : $code');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const subjects = MockSharedData.subjects;

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
              AppDropdownField<String>(
                label: 'Matière associée',
                value: _selectedSubjectId,
                hint: 'Sélectionner une matière',
                items: subjects.map((s) => s.id).toList(),
                itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
                onChanged: (v) => setState(() => _selectedSubjectId = v),
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
