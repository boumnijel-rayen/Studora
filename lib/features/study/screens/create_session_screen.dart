import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/study_models.dart';
import '../providers/study_providers.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  String? _selectedSubjectId;
  int _durationMinutes = 45;
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _notesCtrl.dispose();
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

    final session = StudySession(
      id: 'ss-${DateTime.now().millisecondsSinceEpoch}',
      subjectId: subject.id,
      subjectName: subject.name,
      durationMinutes: _durationMinutes,
      date: _date,
      colorIndex: subject.colorIndex,
      notes: _notesCtrl.text.trim(),
    );

    ref.read(studySessionsProvider.notifier).add(session);
    AppSnackbar.success(context, 'Session de révision planifiée !');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const subjects = MockSharedData.subjects;

    return AppScaffold(
      title: 'Planifier une révision',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDropdownField<String>(
                label: 'Matière à réviser',
                value: _selectedSubjectId,
                hint: 'Choisir la matière',
                items: subjects.map((s) => s.id).toList(),
                itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
                onChanged: (v) => setState(() => _selectedSubjectId = v),
              ),
              AppSpacing.gapMd,
              AppDateField(
                label: 'Date de révision',
                initialValue: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              AppSpacing.gapMd,
              const Text('Durée prévue', style: TextStyle(fontWeight: FontWeight.w600)),
              AppSpacing.gapXs,
              Row(
                children: [
                  for (final m in [25, 45, 60, 90]) ...[
                    ChoiceChip(
                      label: Text('$m min'),
                      selected: _durationMinutes == m,
                      onSelected: (_) => setState(() => _durationMinutes = m),
                    ),
                    AppSpacing.gapXs,
                  ],
                ],
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _notesCtrl,
                label: 'Objectif de la session',
                hint: 'ex: Résumer le chapitre 3, faire 3 exercices de TD...',
                maxLines: 3,
                validator: Validators.required('Veuillez définir un objectif'),
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Ajouter au planning',
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
