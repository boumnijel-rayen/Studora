import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/grade_models.dart';
import '../providers/grades_providers.dart';

class AddEditGradeScreen extends ConsumerStatefulWidget {
  const AddEditGradeScreen({super.key});

  @override
  ConsumerState<AddEditGradeScreen> createState() => _AddEditGradeScreenState();
}

class _AddEditGradeScreenState extends ConsumerState<AddEditGradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _coeffCtrl = TextEditingController(text: '1.0');
  String? _selectedSubjectId;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _valueCtrl.dispose();
    _coeffCtrl.dispose();
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

    final val = double.tryParse(_valueCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;
    final coeff = double.tryParse(_coeffCtrl.text.replaceAll(',', '.').trim()) ?? 1.0;
    final subject = subjects.where((s) => s.id == _selectedSubjectId).firstOrNull;
    if (subject == null) return;

    setState(() => _isSaving = true);

    final grade = Grade(
      id: '',
      subjectId: subject.id,
      subjectName: subject.name,
      title: _titleCtrl.text.trim(),
      value: val,
      coefficient: coeff,
      date: _date,
    );

    try {
      await ref.read(gradesAsyncProvider.notifier).add(grade);
      if (!mounted) return;
      AppSnackbar.success(context, 'Note de ${val.toStringAsFixed(1)}/20 enregistrée !');
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
      title: 'Ajouter une note',
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
                      value: validSubjectId,
                      hint: subjects.isEmpty ? 'Créez d\'abord une matière →' : 'Sélectionner la matière',
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
                controller: _titleCtrl,
                label: 'Intitulé de l\'évaluation',
                hint: 'ex: Partiel final, TP noté 2, QCM...',
                validator: Validators.required(),
              ),
              AppSpacing.gapMd,
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _valueCtrl,
                      label: 'Note obtenue (sur 20)',
                      hint: 'ex: 14.5',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: Validators.compose([
                        Validators.required(),
                        Validators.grade(),
                      ]),
                    ),
                  ),
                  AppSpacing.gapSm,
                  Expanded(
                    child: AppTextField(
                      controller: _coeffCtrl,
                      label: 'Coefficient',
                      hint: 'ex: 2.0',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: Validators.compose([
                        Validators.required(),
                        Validators.number(min: 0.25, max: 10),
                      ]),
                    ),
                  ),
                ],
              ),
              AppSpacing.gapMd,
              AppDateField(
                label: 'Date de l\'évaluation',
                initialValue: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Enregistrer la note',
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
