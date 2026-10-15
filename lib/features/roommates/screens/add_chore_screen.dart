import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';
import '../providers/roommates_providers.dart';

class AddChoreScreen extends ConsumerStatefulWidget {
  const AddChoreScreen({super.key});

  @override
  ConsumerState<AddChoreScreen> createState() => _AddChoreScreenState();
}

class _AddChoreScreenState extends ConsumerState<AddChoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  String? _assignedToName;
  String _frequency = 'Hebdomadaire';

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _assignedToName == null) {
      if (_assignedToName == null) {
        AppSnackbar.error(context, 'Veuillez assigner la tâche à un colocataire');
      }
      return;
    }

    final chore = Chore(
      id: 'ch-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      assignedToName: _assignedToName!,
      dueDate: DateTime.now().add(const Duration(days: 3)),
      frequency: _frequency,
    );

    ref.read(choresProvider.notifier).add(chore);
    AppSnackbar.success(context, 'Tâche ménagère ajoutée au planning !');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final roommates = ref.watch(roommatesProvider);

    return AppScaffold(
      title: 'Nouvelle Tâche',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _titleCtrl,
                label: 'Intitulé de la tâche ménagère',
                hint: 'ex: Laver le réfrigérateur, passer l\'aspirateur...',
                validator: Validators.required(),
              ),
              AppSpacing.gapMd,
              AppDropdownField<String>(
                label: 'Assignée à',
                value: _assignedToName,
                hint: 'Choisir le colocataire',
                items: roommates.map((r) => r.name).toList(),
                itemLabel: (name) => name,
                onChanged: (v) => setState(() => _assignedToName = v),
              ),
              AppSpacing.gapMd,
              const Text('Fréquence de rotation', style: TextStyle(fontWeight: FontWeight.w600)),
              AppSpacing.gapXs,
              Row(
                children: [
                  for (final f in ['Quotidien', 'Hebdomadaire', 'Mensuel']) ...[
                    ChoiceChip(
                      label: Text(f),
                      selected: _frequency == f,
                      onSelected: (_) => setState(() => _frequency = f),
                    ),
                    AppSpacing.gapXs,
                  ],
                ],
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Enregistrer la tâche',
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
