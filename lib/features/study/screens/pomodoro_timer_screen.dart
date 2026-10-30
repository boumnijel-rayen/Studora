import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/core.dart';
import '../models/study_models.dart';
import '../providers/study_providers.dart';
import '../study_routes.dart';

enum PomodoroMode {
  work('Focus Études', AppColors.moduleStudy, 25),
  shortBreak('Pause Courte', AppColors.tertiary, 5),
  longBreak('Pause Longue', AppColors.moduleSchedule, 15);

  const PomodoroMode(this.label, this.color, this.defaultMinutes);
  final String label;
  final Color color;
  final int defaultMinutes;
}

class PomodoroTimerScreen extends ConsumerStatefulWidget {
  const PomodoroTimerScreen({super.key});

  @override
  ConsumerState<PomodoroTimerScreen> createState() => _PomodoroTimerScreenState();
}

class _PomodoroTimerScreenState extends ConsumerState<PomodoroTimerScreen> {
  PomodoroMode _mode = PomodoroMode.work;
  late int _remainingSeconds;
  late int _totalSeconds;
  Timer? _timer;
  bool _isRunning = false;
  int _completedSessions = 0;
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(pomodoroConfigProvider);
    final subjects = ref.read(subjectsProvider);
    if (subjects.isNotEmpty) {
      _selectedSubjectId = subjects.first.id;
    }
    _initMode(PomodoroMode.work, cfg.workMinutes);
  }

  void _initMode(PomodoroMode mode, int minutes) {
    _mode = mode;
    _totalSeconds = minutes * 60;
    _remainingSeconds = _totalSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _onFinished();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  Future<void> _onFinished() async {
    _timer?.cancel();
    final completedWork = _mode == PomodoroMode.work;
    setState(() {
      _isRunning = false;
      if (completedWork) {
        _completedSessions++;
      }
    });

    final cfg = ref.read(pomodoroConfigProvider);
    if (completedWork) {
      // Enregistre la session réalisée dans Strapi
      final subjects = ref.read(subjectsProvider);
      final subject = subjects.where((s) => s.id == _selectedSubjectId).firstOrNull;
      if (subject != null) {
        try {
          await ref.read(studySessionsAsyncProvider.notifier).add(
            StudySession(
              id: '',
              subjectId: subject.id,
              subjectName: subject.name,
              durationMinutes: cfg.workMinutes,
              date: DateTime.now(),
              colorIndex: subject.colorIndex,
              notes: 'Session Pomodoro réalisée',
              isCompleted: true,
            ),
          );
        } catch (_) {}
      }

      if (!mounted) return;
      final isLong = _completedSessions % cfg.sessionsBeforeLongBreak == 0;
      _switchMode(isLong ? PomodoroMode.longBreak : PomodoroMode.shortBreak);
      AppSnackbar.success(context, 'Bravo ! Session enregistrée. Prenez une pause méritée ☕');
      if (cfg.autoStartBreaks) {
        _startTimer();
      }
    } else {
      _switchMode(PomodoroMode.work);
      if (mounted) {
        AppSnackbar.info(context, 'Pause terminée, retour au travail ! 💪');
      }
    }
  }

  void _switchMode(PomodoroMode mode) {
    final cfg = ref.read(pomodoroConfigProvider);
    final min = switch (mode) {
      PomodoroMode.work => cfg.workMinutes,
      PomodoroMode.shortBreak => cfg.shortBreakMinutes,
      PomodoroMode.longBreak => cfg.longBreakMinutes,
    };
    setState(() {
      _initMode(mode, min);
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
    final validSubjectId = subjects.any((s) => s.id == _selectedSubjectId)
        ? _selectedSubjectId
        : (subjects.isNotEmpty ? subjects.first.id : null);
    final progress = _totalSeconds == 0 ? 0.0 : (_totalSeconds - _remainingSeconds) / _totalSeconds;

    return AppScaffold(
      title: 'Minuteur Pomodoro',
      actions: [
        IconButton(
          tooltip: 'Réglages Pomodoro',
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => context.push(StudyRoutes.pomodoroSettings),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          const hPadding = AppSpacing.md;
          final contentWidth = constraints.maxWidth - hPadding * 2;
          final ringSize = (contentWidth * 0.78).clamp(180.0, 260.0);

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: hPadding, vertical: AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final m in PomodoroMode.values)
                        ChoiceChip(
                          label: Text(m.label),
                          selected: _mode == m,
                          selectedColor: m.color.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontWeight: _mode == m ? FontWeight.bold : FontWeight.normal,
                            color: _mode == m ? m.color : context.colors.textSecondary,
                          ),
                          onSelected: (_) => _switchMode(m),
                        ),
                    ],
                  ),
                  AppSpacing.gapLg,

                  // Matière active
                  if (_mode == PomodoroMode.work && subjects.isNotEmpty) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bookmark_outline_rounded, size: 16),
                        AppSpacing.gapXxs,
                        Text('Focus sur : ', style: context.text.bodyMedium),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: DropdownButton<String>(
                              value: validSubjectId,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: subjects
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _selectedSubjectId = v),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.gapMd,
                  ],

                  // Grand anneau Pomodoro
                  AppProgressRing(
                    value: progress,
                    size: ringSize,
                    strokeWidth: ringSize >= 240 ? 16 : 12,
                    gradient: AppColors.focusGradient,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatTime(_remainingSeconds),
                              style: context.text.displayLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          AppSpacing.gapXxs,
                          Text(
                            _isRunning ? 'Concentration en cours' : 'En pause',
                            textAlign: TextAlign.center,
                            style: context.text.bodySmall?.copyWith(color: context.colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppSpacing.gapLg,

                  // Indicateur de sessions bouclées
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final filled = index < (_completedSessions % 4);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: filled ? _mode.color : context.colors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                  AppSpacing.gapXxs,
                  Text(
                    '$_completedSessions session${_completedSessions > 1 ? 's' : ''} validée${_completedSessions > 1 ? 's' : ''} aujourd\'hui',
                    textAlign: TextAlign.center,
                    style: context.text.labelSmall?.copyWith(color: context.colors.textSecondary),
                  ),
                  AppSpacing.gapXl,

                  // Boutons d'action
                  _buildActions(contentWidth),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static const double _inlineActionsMinWidth = 460;

  Widget _buildActions(double availableWidth) {
    final playButton = FloatingActionButton.large(
      heroTag: 'pomodoro-play',
      tooltip: _isRunning ? 'Mettre en pause' : 'Démarrer',
      backgroundColor: _mode.color,
      foregroundColor: Colors.white,
      onPressed: _isRunning ? _pauseTimer : _startTimer,
      child: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40),
    );
    final resetButton = AppButton(
      label: 'Réinitialiser',
      variant: AppButtonVariant.ghost,
      icon: Icons.replay_rounded,
      onPressed: _resetTimer,
    );
    final skipButton = AppButton(
      label: 'Passer',
      variant: AppButtonVariant.ghost,
      icon: Icons.skip_next_rounded,
      onPressed: _onFinished,
    );

    if (availableWidth >= _inlineActionsMinWidth) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [resetButton, AppSpacing.gapMd, playButton, AppSpacing.gapMd, skipButton],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        playButton,
        AppSpacing.gapMd,
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [resetButton, skipButton],
        ),
      ],
    );
  }
}
