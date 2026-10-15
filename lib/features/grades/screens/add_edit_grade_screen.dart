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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _valueCtrl.dispose();
    _coeffCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _selectedSubjectId == null) {
      if (_selectedSubjectId == null) {
        AppSnackbar.error(context, 'Veuillez choisir une matière');
      }
      return;
    }

    final val = double.tryParse(_valueCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;
    final coeff = double.tryParse(_coeffCtrl.text.replaceAll(',', '.').trim()) ?? 1.0;
    final subject = MockSharedData.subjects.firstWhere((s) => s.id == _selectedSubjectId);

    final grade = Grade(
      id: 'gr-${DateTime.now().millisecondsSinceEpoch}',
      subjectId: subject.id,
      subjectName: subject.name,
      title: _titleCtrl.text.trim(),
      value: val,
      coefficient: coeff,
      date: _date,
    );

    ref.read(gradesProvider.notifier).add(grade);
    AppSnackbar.success(context, 'Note de ${val.toStringAsFixed(1)}/20 enregistrée !');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const subjects = MockSharedData.subjects;

    return AppScaffold(
      title: 'Ajouter une note',
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
                onChanged: (v) => setState(() => _selectedSubjectId = v),
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
