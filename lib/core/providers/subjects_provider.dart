import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/design_system.dart';
import '../models/subject.dart';
import '../network/strapi_client.dart';
import '../services/session_service.dart';

/// Notifier asynchrone connecté à Strapi (`/api/subjects`) pour gérer
/// les matières de l'utilisateur connecté.
class SubjectsAsyncNotifier extends AsyncNotifier<List<Subject>> {
  @override
  Future<List<Subject>> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const [];

    final client = ref.read(strapiClientProvider);
    final items = await client.getList('/subjects');
    return items.map(Subject.fromJson).toList();
  }

  Future<Subject> createSubject({
    required String name,
    String? shortName,
    int colorIndex = 0,
    String iconKey = 'book',
    double coefficient = 1.0,
    String teacher = '',
  }) async {
    final client = ref.read(strapiClientProvider);
    final trimmedName = name.trim();
    final trimmedShort = (shortName == null || shortName.trim().isEmpty)
        ? (trimmedName.length <= 6 ? trimmedName : trimmedName.substring(0, 6))
        : shortName.trim();

    final response = await client.post(
      '/subjects',
      body: {
        'name': trimmedName,
        'shortName': trimmedShort,
        'colorIndex': colorIndex,
        'iconKey': iconKey,
        'coefficient': coefficient,
        'teacher': teacher.trim(),
      },
    );

    final created = Subject.fromJson(StrapiClient.unwrapMap(response));
    final current = state.asData?.value ?? const <Subject>[];
    state = AsyncData([...current, created]);
    return created;
  }

  Future<void> deleteSubject(String id) async {
    final client = ref.read(strapiClientProvider);
    await client.delete('/subjects/$id');
    final current = state.asData?.value ?? const <Subject>[];
    state = AsyncData(current.where((s) => s.id != id).toList());
  }
}

final subjectsAsyncProvider =
    AsyncNotifierProvider<SubjectsAsyncNotifier, List<Subject>>(SubjectsAsyncNotifier.new);

/// Liste synchrone des matières chargées depuis le backend (vide tant que non chargée).
final subjectsProvider = Provider<List<Subject>>((ref) {
  return ref.watch(subjectsAsyncProvider).asData?.value ?? const [];
});

/// Recherche d'une matière par id.
final subjectByIdProvider = Provider.family<Subject?, String>((ref, id) {
  for (final s in ref.watch(subjectsProvider)) {
    if (s.id == id) return s;
  }
  return null;
});

/// Ouvre une feuille modale permettant de créer une matière dans Strapi.
Future<Subject?> showCreateSubjectSheet(BuildContext context, WidgetRef ref) {
  return AppBottomSheet.show<Subject>(
    context,
    title: 'Nouvelle matière',
    child: const _CreateSubjectSheet(),
  );
}

class _CreateSubjectSheet extends ConsumerStatefulWidget {
  const _CreateSubjectSheet();

  @override
  ConsumerState<_CreateSubjectSheet> createState() => _CreateSubjectSheetState();
}

class _CreateSubjectSheetState extends ConsumerState<_CreateSubjectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _shortCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _coeffCtrl = TextEditingController(text: '1.0');
  int _colorIndex = 0;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortCtrl.dispose();
    _teacherCtrl.dispose();
    _coeffCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final coeff = double.tryParse(_coeffCtrl.text.replaceAll(',', '.').trim()) ?? 1.0;
      final created = await ref.read(subjectsAsyncProvider.notifier).createSubject(
        name: _nameCtrl.text,
        shortName: _shortCtrl.text,
        teacher: _teacherCtrl.text,
        coefficient: coeff,
        colorIndex: _colorIndex,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _nameCtrl,
          label: 'Nom de la matière',
          hint: 'ex: Mathématiques, Algorithmique...',
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom obligatoire' : null,
        ),
        AppSpacing.gapMd,
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _shortCtrl,
                label: 'Abréviation',
                hint: 'ex: Maths',
              ),
            ),
            AppSpacing.gapSm,
            Expanded(
              child: AppTextField(
                controller: _coeffCtrl,
                label: 'Coefficient',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        AppSpacing.gapMd,
        AppTextField(
          controller: _teacherCtrl,
          label: 'Enseignant (optionnel)',
          hint: 'ex: Mme Laurent',
        ),
        AppSpacing.gapMd,
        Wrap(
          spacing: AppSpacing.xs,
          children: List.generate(AppColors.subjectPalette.length, (i) {
            final selected = _colorIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _colorIndex = i),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.subjectPalette[i],
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: context.colors.textPrimary, width: 2.5) : null,
                ),
              ),
            );
          }),
        ),
        if (_error != null) ...[
          AppSpacing.gapSm,
          Text(_error!, style: context.text.bodySmall?.copyWith(color: context.colors.error)),
        ],
        AppSpacing.gapLg,
        AppButton(
          label: 'Créer la matière',
          icon: Icons.check_rounded,
          isLoading: _saving,
          expand: true,
          onPressed: _submit,
        ),
      ],
    ),
  );
}

