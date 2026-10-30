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
    this.taskId,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final subjectMap = json['subject'] is Map<String, dynamic>
        ? json['subject'] as Map<String, dynamic>
        : null;
    final taskMap = json['task'] is Map<String, dynamic>
        ? json['task'] as Map<String, dynamic>
        : null;

    return StudySession(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      subjectId: (json['subjectId'] ?? subjectMap?['id'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? subjectMap?['name'] ?? '').toString(),
      durationMinutes: (json['durationMinutes'] is num)
          ? (json['durationMinutes'] as num).toInt()
          : int.tryParse('${json['durationMinutes']}') ?? 25,
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      colorIndex: (json['colorIndex'] is num)
          ? (json['colorIndex'] as num).toInt()
          : int.tryParse('${json['colorIndex']}') ?? 0,
      notes: (json['notes'] ?? '').toString(),
      isCompleted: json['isCompleted'] == true,
      linkedDeadlineTitle: json['linkedDeadlineTitle']?.toString(),
      taskId: (json['taskId'] ?? taskMap?['id'])?.toString(),
    );
  }

  final String id;
  final String subjectId;
  final String subjectName;
  final int durationMinutes;
  final DateTime date;
  final int colorIndex;
  final String notes;
  final bool isCompleted;
  final String? linkedDeadlineTitle;
  final String? taskId;

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'subjectName': subjectName,
    'durationMinutes': durationMinutes,
    'date': date.toUtc().toIso8601String(),
    'colorIndex': colorIndex,
    'notes': notes,
    'isCompleted': isCompleted,
    if (linkedDeadlineTitle != null) 'linkedDeadlineTitle': linkedDeadlineTitle,
  };

  StudySession copyWith({
    String? subjectId,
    String? subjectName,
    int? durationMinutes,
    DateTime? date,
    int? colorIndex,
    String? notes,
    bool? isCompleted,
    String? linkedDeadlineTitle,
    String? taskId,
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
    taskId: taskId ?? this.taskId,
  );
}

@immutable
class StudyTask {
  const StudyTask({
    required this.id,
    required this.subjectId,
    required this.title,
    this.isCompleted = false,
    this.dueDate,
  });

  factory StudyTask.fromJson(Map<String, dynamic> json) {
    final subjectMap = json['subject'] is Map<String, dynamic>
        ? json['subject'] as Map<String, dynamic>
        : null;
    final dueRaw = json['dueDate']?.toString();

    return StudyTask(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      subjectId: (json['subjectId'] ?? subjectMap?['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      isCompleted: json['isCompleted'] == true,
      dueDate: dueRaw == null ? null : DateTime.tryParse(dueRaw),
    );
  }

  final String id;
  final String subjectId;
  final String title;
  final bool isCompleted;
  final DateTime? dueDate;

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'title': title,
    'isCompleted': isCompleted,
    if (dueDate != null) 'dueDate': dueDate!.toUtc().toIso8601String(),
  };

  StudyTask copyWith({
    String? title,
    bool? isCompleted,
    DateTime? dueDate,
  }) => StudyTask(
    id: id,
    subjectId: subjectId,
    title: title ?? this.title,
    isCompleted: isCompleted ?? this.isCompleted,
    dueDate: dueDate ?? this.dueDate,
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
