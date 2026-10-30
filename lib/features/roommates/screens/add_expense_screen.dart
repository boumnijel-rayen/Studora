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
  final _excludedIds = <String>{};
  String? _paidById;
  String _category = 'Alimentation';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String? _effectivePayer(List<Roommate> members) {
    if (members.any((m) => m.id == _paidById)) return _paidById;
    return ref.read(currentRoommateProvider)?.id ?? members.firstOrNull?.id;
  }

  Future<void> _save() async {
    final members = ref.read(roommatesProvider);
    final payer = _effectivePayer(members);
    final participantIds = [
      for (final m in members)
        if (!_excludedIds.contains(m.id)) m.id,
    ];
    if (!_formKey.currentState!.validate() || payer == null) return;
    if (participantIds.isEmpty) {
      AppSnackbar.error(context, 'Sélectionnez au moins un colocataire pour le partage');
      return;
    }

    setState(() => _saving = true);
    try {
      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.').trim()) ?? 0.0;

      final newExp = Expense(
        id: '',
        title: _titleCtrl.text.trim(),
        amount: amount,
        paidById: payer,
        paidByName: '',
        date: _date,
        category: _category,
        participantIds: participantIds,
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
    final members = ref.watch(roommatesProvider);
    final names = {for (final m in members) m.id: m.name};
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
                value: _effectivePayer(members),
                items: names.keys.toList(),
                itemLabel: (id) => names[id] ?? '',
                onChanged: (v) => setState(() => _paidById = v),
              ),
              AppSpacing.gapMd,
              const Text('Partagée entre', style: TextStyle(fontWeight: FontWeight.w600)),
              AppSpacing.gapXs,
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final m in members)
                    FilterChip(
                      label: Text(m.name),
                      selected: !_excludedIds.contains(m.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _excludedIds.remove(m.id);
                        } else {
                          _excludedIds.add(m.id);
                        }
                      }),
                    ),
                ],
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
