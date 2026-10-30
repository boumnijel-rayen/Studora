import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/schedule_models.dart';
import '../providers/schedule_providers.dart';

class AddEditCourseScreen extends ConsumerStatefulWidget {
  const AddEditCourseScreen({super.key, this.existingCourse});
  final Course? existingCourse;

  @override
  ConsumerState<AddEditCourseScreen> createState() => _AddEditCourseScreenState();
}

class _AddEditCourseScreenState extends ConsumerState<AddEditCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubjectId;
  int _selectedDay = 1; // Lundi
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 30);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 30);
  late final TextEditingController _roomCtrl;
  late final TextEditingController _teacherCtrl;
  late final TextEditingController _notesCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCourse;
    _selectedSubjectId = existing?.subjectId.isNotEmpty == true ? existing!.subjectId : null;
    _selectedDay = existing?.dayOfWeek ?? 1;
    _startTime = existing?.startTime ?? const TimeOfDay(hour: 8, minute: 30);
    _endTime = existing?.endTime ?? const TimeOfDay(hour: 10, minute: 30);
    _roomCtrl = TextEditingController(text: existing?.room ?? '');
    _teacherCtrl = TextEditingController(text: existing?.teacher ?? '');
    _notesCtrl = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _roomCtrl.dispose();
    _teacherCtrl.dispose();
    _notesCtrl.dispose();
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

    final subject = subjects.where((s) => s.id == _selectedSubjectId).firstOrNull;
    if (subject == null) {
      AppSnackbar.error(context, 'Matière introuvable');
      return;
    }

    setState(() => _isSaving = true);

    final coursePayload = Course(
      id: widget.existingCourse?.id ?? '',
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

    try {
      if (widget.existingCourse != null) {
        await ref.read(coursesAsyncProvider.notifier).updateCourse(coursePayload);
        if (!mounted) return;
        AppSnackbar.success(context, 'Cours modifié avec succès !');
      } else {
        await ref.read(coursesAsyncProvider.notifier).add(coursePayload);
        if (!mounted) return;
        AppSnackbar.success(context, 'Nouveau cours ajouté au planning !');
      }
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackbar.error(context, ApiException.fromError(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjectsAsync = ref.watch(subjectsAsyncProvider);
    final subjects = subjectsAsync.asData?.value ?? const <Subject>[];
    final validSelectedId = subjects.any((s) => s.id == _selectedSubjectId) ? _selectedSubjectId : null;

    return AppScaffold(
      title: widget.existingCourse == null ? 'Nouveau Cours' : 'Modifier le cours',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppDropdownField<String>(
                      label: 'Matière',
                      value: validSelectedId,
                      hint: subjects.isEmpty ? 'Créez d\'abord une matière →' : 'Sélectionner la matière',
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
                  ),
                  AppSpacing.gapXs,
                  IconButton.filledTonal(
                    tooltip: 'Nouvelle matière',
                    icon: const Icon(Icons.add_rounded),
                    onPressed: () async {
                      final created = await showCreateSubjectSheet(context, ref);
                      if (created != null && mounted) {
                        setState(() {
                          _selectedSubjectId = created.id;
                          _teacherCtrl.text = created.teacher;
                        });
                      }
                    },
                  ),
                ],
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
