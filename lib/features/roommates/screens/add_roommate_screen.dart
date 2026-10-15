import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';
import '../providers/roommates_providers.dart';

class AddRoommateScreen extends ConsumerStatefulWidget {
  const AddRoommateScreen({super.key});

  @override
  ConsumerState<AddRoommateScreen> createState() => _AddRoommateScreenState();
}

class _AddRoommateScreenState extends ConsumerState<AddRoommateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _roomCtrl = TextEditingController(text: 'Chambre 4');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final newRoommate = Roommate(
      id: 'rm-${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      roomNumber: _roomCtrl.text.trim(),
      isPresent: true,
    );

    ref.read(roommatesProvider.notifier).add(newRoommate);
    AppSnackbar.success(context, 'Colocataire ajouté !');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Nouveau colocataire',
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
              label: 'Numéro de téléphone',
              hint: '06 12 34 56 78',
              keyboardType: TextInputType.phone,
              validator: Validators.compose([Validators.required(), Validators.phone()]),
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _emailCtrl,
              label: 'Adresse e-mail',
              hint: 'thomas@univ.fr',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.compose([Validators.required(), Validators.email()]),
            ),
            AppSpacing.gapMd,
            AppTextField(
              controller: _roomCtrl,
              label: 'Identifiant / Nom de la chambre',
              hint: 'ex: Chambre 4 (étage 1)',
              validator: Validators.required(),
            ),
            AppSpacing.gapXl,
            AppButton(
              label: 'Ajouter à la colocation',
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
