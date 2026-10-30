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
  String? _assignedToName;
  String _frequency = 'Hebdomadaire';
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  List<String> _buildCandidateNames() {
    final roommates = ref.watch(roommatesProvider);
    final user = ref.watch(currentUserProvider);
    final names = <String>{
      if (user != null && user.fullName.trim().isNotEmpty) user.fullName.trim(),
      for (final r in roommates)
        if (r.name.trim().isNotEmpty) r.name.trim(),
    }.toList();
    return names;
  }

  Future<void> _save() async {
    final candidates = _buildCandidateNames();
    final selected = _assignedToName ?? (candidates.isNotEmpty ? candidates.first : null);
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
        assignedToName: selected,
        dueDate: DateTime.now().add(const Duration(days: 3)),
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
    final candidates = _buildCandidateNames();
    final effectiveAssigned =
        (_assignedToName != null && candidates.contains(_assignedToName))
        ? _assignedToName
        : (candidates.isNotEmpty ? candidates.first : null);

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
                      value: effectiveAssigned,
                      hint: 'Choisir le colocataire',
                      items: candidates,
                      itemLabel: (name) => name,
                      onChanged: (v) => setState(() => _assignedToName = v),
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
              const Text(
                'Fréquence de rotation',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
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
