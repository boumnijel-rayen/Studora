import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/study_models.dart';
import '../providers/study_providers.dart';

/// Carte « ✨ Analyse IA » de l'écran Historique.
class StudyInsightsCard extends ConsumerWidget {
  const StudyInsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(studyInsightsProvider);
    final notifier = ref.read(studyInsightsProvider.notifier);

    return AppCard(
      borderColor: AppColors.moduleStudy.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('✨ Analyse IA', style: context.text.titleMedium),
          AppSpacing.gapSm,
          insightsAsync.when(
            skipLoadingOnRefresh: false,
            skipLoadingOnReload: false,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: AppLoader(message: 'Analyse de ton historique…'),
            ),
            error: (err, _) => AppErrorState.fromError(err, onRetry: notifier.analyze),
            data: (insights) => insights == null
                ? _Intro(onAnalyze: notifier.analyze)
                : _Results(insights: insights, onReanalyze: notifier.analyze),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onAnalyze});

  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        "L'IA analyse tes sessions, tes notes et tes échéances à venir, "
        'puis te propose des sessions de révision adaptées.',
        style: context.text.bodyMedium,
      ),
      AppSpacing.gapMd,
      AppButton(
        label: 'Analyser mon historique',
        icon: Icons.auto_awesome_rounded,
        expand: true,
        onPressed: onAnalyze,
      ),
    ],
  );
}

class _Results extends StatelessWidget {
  const _Results({required this.insights, required this.onReanalyze});

  final StudyInsights insights;
  final VoidCallback onReanalyze;

  static String _iconFor(String type) => switch (type) {
    'progres' => '📈',
    'negligee' => '⚠️',
    'moment' => '🕒',
    'regularite' => '🔁',
    'notes' => '🎯',
    _ => '•',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(insights.resume, style: context.text.bodyMedium),

      if (insights.observations.isNotEmpty) ...[
        AppSpacing.gapMd,
        for (final o in insights.observations) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_iconFor(o.type), style: context.text.bodyMedium),
              AppSpacing.gapSm,
              Expanded(child: Text(o.texte, style: context.text.bodyMedium)),
            ],
          ),
          AppSpacing.gapXs,
        ],
      ],

      if (insights.liensNotes.isNotEmpty) ...[
        AppSpacing.gapMd,
        Text('Révisions ↔ Notes', style: context.text.titleSmall),
        AppSpacing.gapSm,
        for (final l in insights.liensNotes) ...[
          Row(
            children: [
              Expanded(child: Text(l.subjectName, style: context.text.bodyMedium)),
              AppBadge(label: '${l.minutesRevisees} min', tone: AppBadgeTone.info),
              AppSpacing.gapXs,
              AppBadge(
                label: '${Formatters.decimal(l.moyenne, digits: 1)} /20',
                tone: l.moyenne >= 10 ? AppBadgeTone.success : AppBadgeTone.warning,
              ),
            ],
          ),
          if (l.commentaire.isNotEmpty)
            Text(l.commentaire, style: context.text.bodySmall),
          AppSpacing.gapSm,
        ],
      ],

      if (insights.recommandations.isNotEmpty) ...[
        AppSpacing.gapMd,
        Text('Sessions recommandées', style: context.text.titleSmall),
        AppSpacing.gapSm,
        for (final r in insights.recommandations) ...[
          _RecommendationButton(key: ObjectKey(r), recommendation: r),
          AppSpacing.gapSm,
        ],
      ],

      AppSpacing.gapSm,
      AppButton(
        label: 'Réanalyser',
        icon: Icons.refresh_rounded,
        variant: AppButtonVariant.ghost,
        expand: true,
        onPressed: onReanalyze,
      ),
    ],
  );
}

/// Bouton qui crée réellement la session recommandée, désactivé pendant la création.
class _RecommendationButton extends ConsumerStatefulWidget {
  const _RecommendationButton({super.key, required this.recommendation});

  final SessionRecommendation recommendation;

  @override
  ConsumerState<_RecommendationButton> createState() => _RecommendationButtonState();
}

class _RecommendationButtonState extends ConsumerState<_RecommendationButton> {
  bool _saving = false;

  /// « demain 18h », « aujourd'hui 9h30 », « jeu. 14h ».
  static String _when(DateTime date) {
    final local = date.toLocal();
    final days = local.dateOnly.difference(DateTime.now().dateOnly).inDays;
    final dayLabel = switch (days) {
      0 => "aujourd'hui",
      1 => 'demain',
      _ => Formatters.weekday(local),
    };
    final minutes = local.minute == 0 ? '' : local.minute.toString().padLeft(2, '0');
    return '$dayLabel ${local.hour}h$minutes';
  }

  Future<void> _apply() async {
    if (_saving) return;
    final rec = widget.recommendation;
    final subject = ref.read(subjectsProvider).where((s) => s.id == rec.subjectId).firstOrNull;
    if (subject == null) {
      AppSnackbar.error(context, 'Cette matière n\'existe plus.');
      return;
    }

    setState(() => _saving = true);
    try {
      final session = StudySession(
        id: '',
        subjectId: subject.id,
        subjectName: subject.name,
        durationMinutes: rec.dureeMinutes,
        date: rec.date,
        colorIndex: subject.colorIndex,
        notes: rec.raison,
        isCompleted: false,
      );
      await ref.read(studySessionsAsyncProvider.notifier).add(session);

      final current = ref.read(studyInsightsProvider).asData?.value;
      final index = current?.recommandations.indexOf(rec) ?? -1;
      ref.read(studyInsightsProvider.notifier).markApplied(index);
      if (!mounted) return;
      AppSnackbar.success(context, 'Session planifiée !');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, ApiException.fromError(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recommendation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: '+ ${rec.dureeMinutes} min de ${rec.subjectName} · ${_when(rec.date)}',
          variant: AppButtonVariant.tonal,
          isLoading: _saving,
          expand: true,
          onPressed: _saving ? null : _apply,
        ),
        if (rec.raison.isNotEmpty) ...[
          AppSpacing.gapXxs,
          Text(rec.raison, style: context.text.bodySmall),
        ],
      ],
    );
  }
}
