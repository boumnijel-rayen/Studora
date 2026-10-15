import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/roommate_models.dart';
import '../providers/roommates_providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String? _paidByName = 'Rayen Ben Ali';
  String _category = 'Alimentation';
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _paidByName == null) return;

    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;

    final newExp = Expense(
      id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      amount: amount,
      paidByName: _paidByName!,
      date: _date,
      category: _category,
    );

    ref.read(expensesProvider.notifier).add(newExp);
    AppSnackbar.success(context, 'Dépense de ${amount.toStringAsFixed(2)} € enregistrée !');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final roommates = ref.watch(roommatesProvider);

    return AppScaffold(
      title: 'Nouvelle dépense',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _titleCtrl,
                label: 'Description de la dépense',
                hint: 'ex: Courses Monoprix, Sacs poubelles, Détergent...',
                validator: Validators.required(),
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _amountCtrl,
                label: 'Montant total payé (€)',
                hint: 'ex: 45.80',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: Validators.compose([
                  Validators.required(),
                  Validators.amount(),
                ]),
              ),
              AppSpacing.gapMd,
              AppDropdownField<String>(
                label: 'Payé par',
                value: _paidByName,
                items: roommates.map((r) => r.name).toList(),
                itemLabel: (name) => name,
                onChanged: (v) => setState(() => _paidByName = v),
              ),
              AppSpacing.gapMd,
              const Text('Catégorie', style: TextStyle(fontWeight: FontWeight.w600)),
              AppSpacing.gapXs,
              Row(
                children: [
                  for (final cat in ['Alimentation', 'Factures', 'Ménage', 'Autre']) ...[
                    ChoiceChip(
                      label: Text(cat),
                      selected: _category == cat,
                      onSelected: (_) => setState(() => _category = cat),
                    ),
                    AppSpacing.gapXs,
                  ],
                ],
              ),
              AppSpacing.gapMd,
              AppDateField(
                label: 'Date de paiement',
                initialValue: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
              AppSpacing.gapXl,
              AppButton(
                label: 'Enregistrer la dépense',
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
