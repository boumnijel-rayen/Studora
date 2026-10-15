import 'package:flutter/foundation.dart';

@immutable
class StudySession {
  const StudySession({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.durationMinutes,
    required this.date,
    required this.colorIndex,
    this.notes = '',
    this.isCompleted = false,
    this.linkedDeadlineTitle,
  });

  final String id;
  final String subjectId;
  final String subjectName;
  final int durationMinutes;
  final DateTime date;
  final int colorIndex;
  final String notes;
  final bool isCompleted;
  final String? linkedDeadlineTitle;

  StudySession copyWith({
    String? subjectId,
    String? subjectName,
    int? durationMinutes,
    DateTime? date,
    int? colorIndex,
    String? notes,
    bool? isCompleted,
    String? linkedDeadlineTitle,
  }) => StudySession(
    id: id,
    subjectId: subjectId ?? this.subjectId,
    subjectName: subjectName ?? this.subjectName,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    date: date ?? this.date,
    colorIndex: colorIndex ?? this.colorIndex,
    notes: notes ?? this.notes,
    isCompleted: isCompleted ?? this.isCompleted,
    linkedDeadlineTitle: linkedDeadlineTitle ?? this.linkedDeadlineTitle,
  );
}

@immutable
class StudyTask {
  const StudyTask({
    required this.id,
    required this.subjectId,
    required this.title,
    this.isCompleted = false,
  });

  final String id;
  final String subjectId;
  final String title;
  final bool isCompleted;

  StudyTask copyWith({bool? isCompleted}) => StudyTask(
    id: id,
    subjectId: subjectId,
    title: title,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}

@immutable
class PomodoroConfig {
  const PomodoroConfig({
    this.workMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.sessionsBeforeLongBreak = 4,
    this.autoStartBreaks = false,
  });

  final int workMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int sessionsBeforeLongBreak;
  final bool autoStartBreaks;

  PomodoroConfig copyWith({
    int? workMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? sessionsBeforeLongBreak,
    bool? autoStartBreaks,
  }) => PomodoroConfig(
    workMinutes: workMinutes ?? this.workMinutes,
    shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
    longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
    sessionsBeforeLongBreak: sessionsBeforeLongBreak ?? this.sessionsBeforeLongBreak,
    autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
  );
}
