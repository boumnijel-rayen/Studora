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
  String? _paidByName;
  String _category = 'Alimentation';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  List<String> _buildCandidateNames() {
    final roommates = ref.watch(roommatesProvider);
    final user = ref.watch(currentUserProvider);
    return <String>{
      if (user != null && user.fullName.trim().isNotEmpty) user.fullName.trim(),
      for (final r in roommates)
        if (r.name.trim().isNotEmpty) r.name.trim(),
    }.toList();
  }

  Future<void> _save() async {
    final candidates = _buildCandidateNames();
    final payer = _paidByName ?? (candidates.isNotEmpty ? candidates.first : null);
    if (!_formKey.currentState!.validate() || payer == null) return;

    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;

      final newExp = Expense(
        id: '',
        title: _titleCtrl.text.trim(),
        amount: amount,
        paidByName: payer,
        date: _date,
        category: _category,
      );

      await ref.read(expensesAsyncProvider.notifier).add(newExp);
      if (!mounted) return;
      final currency = ref.read(preferencesProvider).currency;
      AppSnackbar.success(
        context,
        'Dépense de ${Formatters.money(amount, symbol: currency)} enregistrée !',
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.error(context, 'Impossible d\'enregistrer la dépense.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _buildCandidateNames();
    final effectivePayer =
        (_paidByName != null && candidates.contains(_paidByName))
        ? _paidByName
        : (candidates.isNotEmpty ? candidates.first : null);
    final currency = ref.watch(preferencesProvider).currency;

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
                hint: 'ex: Courses supermarché, Sacs poubelles, Détergent...',
                validator: Validators.required(),
              ),
              AppSpacing.gapMd,
              AppTextField(
                controller: _amountCtrl,
                label: 'Montant total payé ($currency)',
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
                value: effectivePayer,
                items: candidates,
                itemLabel: (name) => name,
                onChanged: (v) => setState(() => _paidByName = v),
              ),
              AppSpacing.gapMd,
              const Text('Catégorie', style: TextStyle(fontWeight: FontWeight.w600)),
              AppSpacing.gapXs,
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final cat in ['Alimentation', 'Factures', 'Ménage', 'Autre'])
                    ChoiceChip(
                      label: Text(cat),
                      selected: _category == cat,
                      onSelected: (_) => setState(() => _category = cat),
                    ),
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
