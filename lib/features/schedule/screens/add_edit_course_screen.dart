import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/schedule_models.dart';
import '../providers/schedule_providers.dart';

class AddEditCourseScreen extends ConsumerStatefulWidget {
  const AddEditCourseScreen({super.key});

  @override
  ConsumerState<AddEditCourseScreen> createState() => _AddEditCourseScreenState();
}

class _AddEditCourseScreenState extends ConsumerState<AddEditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubjectId;
  int _selectedDay = 1; // Lundi
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  final _roomCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _roomCtrl.dispose();
    _teacherCtrl.dispose();
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

    final newCourse = Course(
      id: 'c-${DateTime.now().millisecondsSinceEpoch}',
      subjectId: subject.id,
      subjectName: subject.name,
      room: _roomCtrl.text.trim(),
      teacher: _teacherCtrl.text.trim().isNotEmpty ? _teacherCtrl.text.trim() : subject.teacher,
      dayOfWeek: _selectedDay,
      startTime: _startTime,
      endTime: _endTime,
      colorIndex: subject.colorIndex,
      notes: _notesCtrl.text.trim(),
    );

    ref.read(coursesProvider.notifier).add(newCourse);
    AppSnackbar.success(context, 'Nouveau cours ajouté au planning !');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const subjects = MockSharedData.subjects;

    return AppScaffold(
      title: 'Nouveau Cours',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDropdownField<String>(
                label: 'Matière',
                value: _selectedSubjectId,
                hint: 'Sélectionner la matière',
                items: subjects.map((s) => s.id).toList(),
                itemLabel: (id) => subjects.firstWhere((s) => s.id == id).name,
                onChanged: (v) {
                  setState(() {
                    _selectedSubjectId = v;
                    if (v != null) {
                      _teacherCtrl.text = subjects.firstWhere((s) => s.id == v).teacher;
                    }
                  });
                },
              ),
              AppSpacing.gapMd,
              AppDropdownField<int>(
                label: 'Jour de la semaine',
                value: _selectedDay,
                items: const [1, 2, 3, 4, 5, 6],
                itemLabel: (d) => switch (d) {
                  1 => 'Lundi',
                  2 => 'Mardi',
                  3 => 'Mercredi',
                  4 => 'Jeudi',
                  5 => 'Vendredi',
                  _ => 'Samedi',
                },
                onChanged: (v) => setState(() => _selectedDay = v ?? 1),
              ),
              AppSpacing.gapMd,
              Row(
                children: [
                  Expanded(
                    child: AppTimeField(
                      label: 'Heure de début',
                      initialValue: _startTime,
                      onChanged: (t) => setState(() => _startTime = t),
                    ),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: AppTimeField(
                      label: 'Heure de fin',
                      initialValue: _endTime,
                      onChanged: (t) => setState(() => _endTime = t),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _roomCtrl,
                label: 'Salle / Bâtiment',
                hint: 'ex: Amphi B ou Salle 204',
                prefixIcon: Icons.room_outlined,
                validator: Validators.required(),
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _teacherCtrl,
                label: 'Enseignant responsable',
                hint: 'ex: Mme Laurent',
                prefixIcon: Icons.person_outline_rounded,
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _notesCtrl,
                label: 'Remarques (optionnel)',
                hint: 'Chapitres traités, matériel requis...',
                maxLines: 3,
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Enregistrer le cours',
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
