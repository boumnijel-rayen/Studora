import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/core.dart';
import '../models/study_models.dart';
import '../providers/study_providers.dart';

class PomodoroSettingsScreen extends ConsumerStatefulWidget {
  const PomodoroSettingsScreen({super.key});

  @override
  ConsumerState<PomodoroSettingsScreen> createState() => _PomodoroSettingsScreenState();
}

class _PomodoroSettingsScreenState extends ConsumerState<PomodoroSettingsScreen> {
  late int _work;
  late int _shortBreak;
  late int _longBreak;
  late int _cycles;
  late bool _autoStart;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(pomodoroConfigProvider);
    _work = cfg.workMinutes;
    _shortBreak = cfg.shortBreakMinutes;
    _longBreak = cfg.longBreakMinutes;
    _cycles = cfg.sessionsBeforeLongBreak;
    _autoStart = cfg.autoStartBreaks;
  }

  void _save() {
    final updated = PomodoroConfig(
      workMinutes: _work,
      shortBreakMinutes: _shortBreak,
      longBreakMinutes: _longBreak,
      sessionsBeforeLongBreak: _cycles,
      autoStartBreaks: _autoStart,
    );
    ref.read(pomodoroConfigProvider.notifier).update(updated);
    AppSnackbar.success(context, 'Réglages Pomodoro appliqués !');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'Réglages Pomodoro',
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const AppSectionHeader(title: 'Durées des intervalles'),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              _SliderRow(
                title: 'Temps de travail / focus',
                value: _work,
                unit: 'min',
                min: 15,
                max: 60,
                divisions: 9,
                onChanged: (v) => setState(() => _work = v.toInt()),
              ),
              const Divider(),
              _SliderRow(
                title: 'Pause courte',
                value: _shortBreak,
                unit: 'min',
                min: 3,
                max: 15,
                divisions: 12,
                onChanged: (v) => setState(() => _shortBreak = v.toInt()),
              ),
              const Divider(),
              _SliderRow(
                title: 'Pause longue',
                value: _longBreak,
                unit: 'min',
                min: 10,
                max: 30,
                divisions: 4,
                onChanged: (v) => setState(() => _longBreak = v.toInt()),
              ),
            ],
          ),
        ),
        AppSpacing.gapLg,

        const AppSectionHeader(title: 'Cycles et automatisation'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sessions avant pause longue', style: context.text.bodyLarge),
                          Text('Nombre d\'intervalles de travail successifs', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    DropdownButton<int>(
                      value: _cycles,
                      underline: const SizedBox(),
                      items: const [2, 3, 4, 5, 6].map((i) => DropdownMenuItem(value: i, child: Text('$i'))).toList(),
                      onChanged: (v) => setState(() => _cycles = v ?? 4),
                    ),
                  ],
                ),
              ),
              const Divider(),
              AppSwitchTile(
                title: 'Démarrage automatique des pauses',
                subtitle: 'Enchaîner immédiatement la pause sans action manuelle',
                value: _autoStart,
                onChanged: (v) => setState(() => _autoStart = v),
              ),
            ],
          ),
        ),
        AppSpacing.gapXl,

        AppButton(
          label: 'Enregistrer les réglages',
          icon: Icons.check_rounded,
          expand: true,
          onPressed: _save,
        ),
      ],
    ),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.title,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final int value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: context.text.bodyLarge),
          Text('$value $unit', style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
        ],
      ),
      Slider(
        value: value.toDouble(),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    ],
  );
}
