import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/grade_models.dart';
import '../providers/grades_providers.dart';

/// Import de notes par IA : l'étudiant choisit un relevé (photo ou PDF),
/// l'IA en extrait les notes, puis il les vérifie avant de les enregistrer.
class ImportGradesScreen extends ConsumerStatefulWidget {
  const ImportGradesScreen({super.key});

  @override
  ConsumerState<ImportGradesScreen> createState() => _ImportGradesScreenState();
}

enum _Phase { pick, analysing, review }

/// Choix « créer la matière détectée » dans la liste déroulante d'une ligne.
const _newSubjectKey = '__new_subject__';

const _maxFileBytes = 4 * 1024 * 1024;

const _mimeTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
};

/// Une note détectée, modifiable par l'étudiant avant l'enregistrement.
class _DraftRow {
  _DraftRow(this.source, {required this.duplicate})
    : selected = !duplicate,
      subjectChoice = source.subjectId ?? (source.subjectName.isEmpty ? null : _newSubjectKey),
      date = source.date ?? DateTime.now(),
      titleCtrl = TextEditingController(text: source.title),
      valueCtrl = TextEditingController(text: _trim(source.value)),
      coeffCtrl = TextEditingController(text: _trim(source.coefficient));

  final ScannedGrade source;

  /// Une note identique existe déjà : décochée par défaut.
  final bool duplicate;
  bool selected;

  /// Identifiant d'une matière existante, [_newSubjectKey] ou null (à choisir).
  String? subjectChoice;
  DateTime date;
  final TextEditingController titleCtrl;
  final TextEditingController valueCtrl;
  final TextEditingController coeffCtrl;

  void dispose() {
    titleCtrl.dispose();
    valueCtrl.dispose();
    coeffCtrl.dispose();
  }
}

/// « 14 » plutôt que « 14.0 », « 14.5 » inchangé.
String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class _ImportGradesScreenState extends ConsumerState<ImportGradesScreen> {
  final _formKey = GlobalKey<FormState>();
  _Phase _phase = _Phase.pick;
  List<_DraftRow> _rows = [];

  /// Toutes les lignes créées, libérées à la fermeture de l'écran.
  final List<_DraftRow> _allRows = [];
  bool _isSaving = false;

  @override
  void dispose() {
    for (final row in _allRows) {
      row.dispose();
    }
    super.dispose();
  }

  bool _isDuplicate(ScannedGrade scanned, List<Grade> existing) => existing.any(
    (g) =>
        g.subjectId == scanned.subjectId &&
        g.title.trim().toLowerCase() == scanned.title.trim().toLowerCase() &&
        (g.value - scanned.value).abs() < 0.01,
  );

  Future<void> _pickAndAnalyse() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _mimeTypes.keys.toList(),
        // Les photos de téléphone dépassent souvent 4 Mo : on les compresse.
        compressionQuality: 70,
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Impossible d\'ouvrir le sélecteur de fichiers.');
      return;
    }
    if (file == null || !mounted) return;

    final mimeType = _mimeTypes[file.extension?.toLowerCase()];
    if (mimeType == null) {
      AppSnackbar.error(context, 'Format non pris en charge. Choisissez une image ou un PDF.');
      return;
    }

    setState(() => _phase = _Phase.analysing);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxFileBytes) {
        throw const ApiException(
          kind: ApiErrorKind.validation,
          message: 'Le fichier est trop volumineux (4 Mo maximum).',
        );
      }

      final scanned = await ref
          .read(gradesAsyncProvider.notifier)
          .scanDocument(bytes: bytes, mimeType: mimeType);
      if (!mounted) return;

      if (scanned.isEmpty) {
        setState(() => _phase = _Phase.pick);
        AppSnackbar.info(context, 'Aucune note n\'a été trouvée dans ce document.');
        return;
      }

      final existing = ref.read(gradesProvider);
      setState(() {
        _rows = [
          for (final s in scanned) _DraftRow(s, duplicate: _isDuplicate(s, existing)),
        ];
        _allRows.addAll(_rows);
        _phase = _Phase.review;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.pick);
      AppSnackbar.error(context, ApiException.fromError(e).message);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      AppSnackbar.error(context, 'Corrigez les notes signalées avant d\'enregistrer.');
      return;
    }

    final selected = _rows.where((r) => r.selected).toList();
    if (selected.isEmpty) return;

    setState(() => _isSaving = true);
    final subjectsNotifier = ref.read(subjectsAsyncProvider.notifier);
    final gradesNotifier = ref.read(gradesAsyncProvider.notifier);
    final createdSubjects = <String, Subject>{};
    var savedCount = 0;

    try {
      for (final row in selected) {
        final Subject subject;
        if (row.subjectChoice == _newSubjectKey) {
          // Une seule création par nom, même si plusieurs notes la partagent.
          final key = row.source.subjectName.trim().toLowerCase();
          subject = createdSubjects[key] ??= await subjectsNotifier.createSubject(
            name: row.source.subjectName,
          );
          row.subjectChoice = subject.id;
        } else {
          subject = ref.read(subjectsProvider).firstWhere((s) => s.id == row.subjectChoice);
        }

        await gradesNotifier.add(
          Grade(
            id: '',
            subjectId: subject.id,
            subjectName: subject.name,
            title: row.titleCtrl.text.trim(),
            value: parseDecimal(row.valueCtrl.text) ?? 0,
            coefficient: parseDecimal(row.coeffCtrl.text) ?? 1,
            date: row.date,
          ),
        );
        savedCount++;
        // Retirée de la liste : un nouvel essai ne la créera pas en double.
        _rows.remove(row);
      }

      if (!mounted) return;
      AppSnackbar.success(
        context,
        savedCount > 1 ? '$savedCount notes importées !' : 'Note importée !',
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final prefix = savedCount > 0 ? '$savedCount note(s) importée(s), puis une erreur : ' : '';
      AppSnackbar.error(context, '$prefix${ApiException.fromError(e).message}');
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Importer un relevé',
    subtitle: switch (_phase) {
      _Phase.pick => 'Lecture automatique par IA',
      _Phase.analysing => 'Analyse en cours',
      _Phase.review => 'Vérifiez avant d\'enregistrer',
    },
    body: switch (_phase) {
      _Phase.pick => _buildPick(context),
      _Phase.analysing => const AppLoader(
        message: 'Lecture du document… cela peut prendre jusqu\'à une minute.',
      ),
      _Phase.review => _buildReview(context),
    },
    bottomBar: _phase == _Phase.review ? _buildSaveBar(context) : null,
  );

  Widget _buildPick(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              const AppIconBox(
                icon: Icons.document_scanner_rounded,
                color: AppColors.moduleGrades,
                size: 56,
              ),
              AppSpacing.gapMd,
              Text(
                'Ajoutez toutes vos notes d\'un coup',
                style: context.text.titleMedium,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapXs,
              Text(
                'Choisissez une photo, une capture d\'écran ou un PDF de votre relevé. '
                'L\'IA détecte les notes, puis vous les vérifiez avant l\'enregistrement.',
                style: context.text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapLg,
              AppButton(
                label: 'Choisir un fichier',
                icon: Icons.upload_file_rounded,
                expand: true,
                onPressed: _pickAndAnalyse,
              ),
              AppSpacing.gapXs,
              Text('JPG, PNG, WebP ou PDF • 4 Mo maximum', style: context.text.labelSmall),
            ],
          ),
        ),
        AppSpacing.gapMd,
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.privacy_tip_outlined, color: AppColors.info),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  'Le document est envoyé à un service d\'IA externe (Gemini, de Google) pour '
                  'être lu. Studora ne le conserve pas, mais Google peut l\'utiliser pour '
                  'améliorer ses services.',
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildReview(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
    final uncertainCount = _rows.where((r) => r.source.uncertain).length;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            '${_rows.length} note${_rows.length > 1 ? 's' : ''} détectée${_rows.length > 1 ? 's' : ''}. '
            'Corrigez ou décochez ce qui ne convient pas.'
            '${uncertainCount > 0 ? ' $uncertainCount ligne${uncertainCount > 1 ? 's' : ''} à vérifier en priorité.' : ''}',
            style: context.text.bodyMedium,
          ),
          AppSpacing.gapMd,
          for (final row in _rows) ...[
            _DraftRowCard(
              key: ObjectKey(row),
              row: row,
              subjects: subjects,
              enabled: !_isSaving,
              onChanged: () => setState(() {}),
            ),
            AppSpacing.gapSm,
          ],
          AppButton(
            label: 'Analyser un autre document',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.ghost,
            onPressed: _isSaving ? null : _pickAndAnalyse,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar(BuildContext context) {
    final count = _rows.where((r) => r.selected).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppButton(
          label: count == 0
              ? 'Aucune note sélectionnée'
              : 'Ajouter $count note${count > 1 ? 's' : ''}',
          icon: Icons.check_rounded,
          expand: true,
          isLoading: _isSaving,
          onPressed: count == 0 ? null : _save,
        ),
      ),
    );
  }
}

class _DraftRowCard extends StatelessWidget {
  const _DraftRowCard({
    super.key,
    required this.row,
    required this.subjects,
    required this.enabled,
    required this.onChanged,
  });

  final _DraftRow row;
  final List<Subject> subjects;
  final bool enabled;
  final VoidCallback onChanged;

  /// Les lignes décochées ne bloquent pas l'enregistrement.
  String? Function(String?) _whenSelected(String? Function(String?) validator) =>
      (v) => row.selected ? validator(v) : null;

  @override
  Widget build(BuildContext context) {
    final source = row.source;
    final detectedName = source.subjectName.trim();
    final choices = [
      ...subjects.map((s) => s.id),
      if (detectedName.isNotEmpty) _newSubjectKey,
    ];
    final converted = source.originalScale != 20;

    return Opacity(
      opacity: row.selected ? 1 : 0.55,
      child: AppCard(
        borderColor: source.uncertain && row.selected ? context.colors.warning : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Checkbox(
                  value: row.selected,
                  onChanged: enabled
                      ? (v) {
                          row.selected = v ?? false;
                          onChanged();
                        }
                      : null,
                ),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      if (source.uncertain)
                        const AppBadge(
                          label: 'À vérifier',
                          tone: AppBadgeTone.warning,
                          icon: Icons.help_outline_rounded,
                        ),
                      if (row.duplicate)
                        const AppBadge(label: 'Déjà enregistrée', tone: AppBadgeTone.neutral),
                      if (converted)
                        AppBadge(
                          label: 'Lu : ${_trim(source.originalValue)}/${_trim(source.originalScale)}',
                          tone: AppBadgeTone.info,
                        ),
                      if (detectedName.isNotEmpty)
                        AppBadge(label: detectedName, tone: AppBadgeTone.primary),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.gapXs,
            IgnorePointer(
              ignoring: !enabled || !row.selected,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppDropdownField<String>(
                    label: 'Matière',
                    hint: 'Choisir la matière',
                    value: choices.contains(row.subjectChoice) ? row.subjectChoice : null,
                    items: choices,
                    itemLabel: (id) => id == _newSubjectKey
                        ? 'Créer « $detectedName »'
                        : subjects.firstWhere((s) => s.id == id).name,
                    validator: (v) => row.selected && v == null ? 'Choisissez une matière' : null,
                    onChanged: (v) {
                      row.subjectChoice = v;
                      onChanged();
                    },
                  ),
                  AppSpacing.gapSm,
                  AppTextField(
                    controller: row.titleCtrl,
                    label: 'Intitulé',
                    validator: _whenSelected(Validators.required()),
                  ),
                  AppSpacing.gapSm,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: row.valueCtrl,
                          label: 'Note (sur 20)',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _whenSelected(
                            Validators.compose([Validators.required(), Validators.grade()]),
                          ),
                        ),
                      ),
                      AppSpacing.gapSm,
                      Expanded(
                        child: AppTextField(
                          controller: row.coeffCtrl,
                          label: 'Coefficient',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: _whenSelected(
                            Validators.compose([
                              Validators.required(),
                              Validators.number(min: 0.25, max: 10),
                            ]),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.gapSm,
                  AppDateField(
                    label: source.date == null ? 'Date (absente du document)' : 'Date',
                    initialValue: row.date,
                    firstDate: DateTime(2000),
                    onChanged: (d) => row.date = d,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
