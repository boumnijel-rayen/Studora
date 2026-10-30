import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';
import '../providers/roommates_providers.dart';

/// Ajoute un colocataire, ou modifie sa fiche quand [roommateId] est fourni.
class AddRoommateScreen extends ConsumerStatefulWidget {
  const AddRoommateScreen({super.key, this.roommateId});

  final String? roommateId;

  @override
  ConsumerState<AddRoommateScreen> createState() => _AddRoommateScreenState();
}

class _AddRoommateScreenState extends ConsumerState<AddRoommateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _roomCtrl = TextEditingController(text: 'Chambre 1');
  Roommate? _existing;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _existing = ref
        .read(roommatesProvider)
        .where((r) => r.id == widget.roommateId)
        .firstOrNull;
    final existing = _existing;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _phoneCtrl.text = existing.phone;
      _emailCtrl.text = existing.email;
      _roomCtrl.text = existing.roomNumber;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final existing = _existing;
      final notifier = ref.read(roommatesAsyncProvider.notifier);
      if (existing != null) {
        await notifier.edit(
          existing.copyWith(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            roomNumber: _roomCtrl.text.trim(),
          ),
        );
      } else {
        await notifier.add(
          Roommate(
            id: '',
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            roomNumber: _roomCtrl.text.trim(),
            isPresent: true,
          ),
        );
      }
      if (!mounted) return;
      AppSnackbar.success(context, existing != null ? 'Fiche mise à jour !' : 'Colocataire ajouté !');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Impossible d\'enregistrer ce colocataire.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: _existing != null ? 'Modifier la fiche' : 'Nouveau colocataire',
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _nameCtrl,
              label: 'Nom et Prénom',
              hint: 'ex: Thomas Martin',
              validator: Validators.required(),
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _phoneCtrl,
              label: 'Numéro de téléphone (facultatif)',
              hint: '06 12 34 56 78',
              keyboardType: TextInputType.phone,
              validator: Validators.phone(),
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _emailCtrl,
              label: 'Adresse e-mail (facultative)',
              hint: 'thomas@univ.fr',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email(),
            ),
            if (_existing == null) ...[
              AppSpacing.gapXs,
              Text(
                'S\'il rejoint la colocation avec cette adresse, cette fiche sera reliée à son compte.',
                style: context.text.bodySmall,
              ),
            ],
            AppSpacing.gapMd,
            AppTextField(
              controller: _roomCtrl,
              label: 'Identifiant / Nom de la chambre',
              hint: 'ex: Chambre 2 (étage 1)',
              validator: Validators.required(),
            ),
            AppSpacing.gapXl,
            AppButton(
              label: _existing != null ? 'Enregistrer' : 'Ajouter à la colocation',
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
