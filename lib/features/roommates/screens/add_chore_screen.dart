import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';
import '../providers/roommates_providers.dart';
import '../roommates_routes.dart';

class AddChoreScreen extends ConsumerStatefulWidget {
  const AddChoreScreen({super.key});

  @override
  ConsumerState<AddChoreScreen> createState() => _AddChoreScreenState();
}

class _AddChoreScreenState extends ConsumerState<AddChoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  String? _assignedToId;
  String _frequency = 'Hebdomadaire';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String? _effectiveAssignee(List<Roommate> members) {
    if (members.any((m) => m.id == _assignedToId)) return _assignedToId;
    return ref.read(currentRoommateProvider)?.id ?? members.firstOrNull?.id;
  }

  Future<void> _save() async {
    final members = ref.read(roommatesProvider);
    final selected = _effectiveAssignee(members);
    if (!_formKey.currentState!.validate() || selected == null) {
      if (selected == null) {
        AppSnackbar.error(context, 'Veuillez assigner la tâche à un colocataire');
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final chore = Chore(
        id: '',
        title: _titleCtrl.text.trim(),
        assignedToId: selected,
        assignedToName: '',
        dueDate: _dueDate,
        frequency: _frequency,
      );

      await ref.read(choresAsyncProvider.notifier).add(chore);
      if (!mounted) return;
      AppSnackbar.success(context, 'Tâche ménagère ajoutée au planning !');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Impossible d\'enregistrer la tâche.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(roommatesProvider);
    final names = {for (final m in members) m.id: m.name};

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
              Row(
                children: [
                  Expanded(
                    child: AppDropdownField<String>(
                      label: 'Assignée à',
                      value: _effectiveAssignee(members),
                      hint: 'Choisir le colocataire',
                      items: names.keys.toList(),
                      itemLabel: (id) => names[id] ?? '',
                      onChanged: (v) => setState(() => _assignedToId = v),
                    ),
                  ),
                  AppSpacing.gapXs,
                  IconButton(
                    tooltip: 'Nouveau colocataire',
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    onPressed: () => context.push(RoommatesRoutes.newRoommate),
                  ),
                ],
              ),
              AppSpacing.gapMd,
              AppDateField(
                label: 'À faire pour le',
                initialValue: _dueDate,
                onChanged: (d) => setState(() => _dueDate = d),
              ),
              AppSpacing.gapMd,
              const Text(
                'Fréquence de rotation',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              AppSpacing.gapXs,
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final f in ['Une seule fois', 'Quotidien', 'Hebdomadaire', 'Mensuel'])
                    ChoiceChip(
                      label: Text(f),
                      selected: _frequency == f,
                      onSelected: (_) => setState(() => _frequency = f),
                    ),
                ],
              ),
              if (_frequency != 'Une seule fois') ...[
                AppSpacing.gapXs,
                Text(
                  'Une fois validée, la tâche revient automatiquement pour le colocataire suivant.',
                  style: context.text.bodySmall,
                ),
              ],
              AppSpacing.gapXl,
              AppButton(
                label: 'Enregistrer la tâche',
                icon: Icons.check_rounded,
                isLoading: _saving,
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
