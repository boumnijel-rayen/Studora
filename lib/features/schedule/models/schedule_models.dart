import 'package:flutter/material.dart';

enum DeadlineType {
  exam('Examen', Icons.assignment_late_rounded),
  homework('Devoir', Icons.assignment_rounded),
  project('Projet', Icons.folder_shared_rounded);

  const DeadlineType(this.label, this.icon);
  final String label;
  final IconData icon;

  static DeadlineType fromString(String value) => switch (value) {
    'exam' => DeadlineType.exam,
    'project' => DeadlineType.project,
    _ => DeadlineType.homework,
  };
}

enum Priority {
  high('Urgent', Color(0xFFEF4444)),
  medium('Moyen', Color(0xFFF59E0B)),
  low('Faible', Color(0xFF3B82F6));

  const Priority(this.label, this.color);
  final String label;
  final Color color;

  static Priority fromString(String value) => switch (value) {
    'high' => Priority.high,
    'low' => Priority.low,
    _ => Priority.medium,
  };
}

@immutable
class Course {
  const Course({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.room,
    required this.teacher,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.colorIndex,
    this.notes = '',
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    final subjectMap = json['subject'] is Map<String, dynamic>
        ? json['subject'] as Map<String, dynamic>
        : null;
    final subjectId = (json['subjectId'] ?? subjectMap?['id'] ?? '').toString();
    final subjectName = (json['subjectName'] ?? subjectMap?['name'] ?? '').toString();

    return Course(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      subjectId: subjectId,
      subjectName: subjectName,
      room: (json['room'] ?? '').toString(),
      teacher: (json['teacher'] ?? '').toString(),
      dayOfWeek: (json['dayOfWeek'] is num)
          ? (json['dayOfWeek'] as num).toInt()
          : int.tryParse('${json['dayOfWeek']}') ?? 1,
      startTime: _parseTime((json['startTime'] ?? '08:30').toString()),
      endTime: _parseTime((json['endTime'] ?? '10:30').toString()),
      colorIndex: (json['colorIndex'] is num)
          ? (json['colorIndex'] as num).toInt()
          : int.tryParse('${json['colorIndex']}') ?? 0,
      notes: (json['notes'] ?? '').toString(),
    );
  }

  final String id;
  final String subjectId;
  final String subjectName;
  final String room;
  final String teacher;
  final int dayOfWeek; // 1 = Lundi, 5 = Vendredi
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final int colorIndex;
  final String notes;

  String get timeSlot =>
      '${_fmtTime(startTime)} - ${_fmtTime(endTime)}';

  Map<String, dynamic> toJson() => {
    'subjectName': subjectName,
    'room': room,
    'teacher': teacher,
    'dayOfWeek': dayOfWeek,
    'startTime': _fmtTime(startTime),
    'endTime': _fmtTime(endTime),
    'colorIndex': colorIndex,
    'notes': notes,
  };

  Course copyWith({
    String? subjectId,
    String? subjectName,
    String? room,
    String? teacher,
    int? dayOfWeek,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    int? colorIndex,
    String? notes,
  }) => Course(
    id: id,
    subjectId: subjectId ?? this.subjectId,
    subjectName: subjectName ?? this.subjectName,
    room: room ?? this.room,
    teacher: teacher ?? this.teacher,
    dayOfWeek: dayOfWeek ?? this.dayOfWeek,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
    colorIndex: colorIndex ?? this.colorIndex,
    notes: notes ?? this.notes,
  );

  static String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay _parseTime(String raw) {
    final parts = raw.split(':');
    final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 8 : 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }
}

@immutable
class Deadline {
  const Deadline({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.subjectName,
    required this.dueDate,
    required this.type,
    required this.priority,
    this.isCompleted = false,
    this.description = '',
    this.reminderBeforeMinutes = 30,
  });

  factory Deadline.fromJson(Map<String, dynamic> json) {
    final subjectMap = json['subject'] is Map<String, dynamic>
        ? json['subject'] as Map<String, dynamic>
        : null;
    return Deadline(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subjectId: (json['subjectId'] ?? subjectMap?['id'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? subjectMap?['name'] ?? '').toString(),
      dueDate: DateTime.tryParse((json['dueDate'] ?? '').toString()) ?? DateTime.now(),
      type: DeadlineType.fromString((json['type'] ?? 'homework').toString()),
      priority: Priority.fromString((json['priority'] ?? 'medium').toString()),
      isCompleted: json['isCompleted'] == true,
      description: (json['description'] ?? '').toString(),
      reminderBeforeMinutes: (json['reminderBeforeMinutes'] is num)
          ? (json['reminderBeforeMinutes'] as num).toInt()
          : 30,
    );
  }

  final String id;
  final String title;
  final String subjectId;
  final String subjectName;
  final DateTime dueDate;
  final DeadlineType type;
  final Priority priority;
  final bool isCompleted;
  final String description;
  final int reminderBeforeMinutes;

  Map<String, dynamic> toJson() => {
    'title': title,
    'subjectName': subjectName,
    'dueDate': dueDate.toUtc().toIso8601String(),
    'type': type.name,
    'priority': priority.name,
    'isCompleted': isCompleted,
    'description': description,
    'reminderBeforeMinutes': reminderBeforeMinutes,
  };

  Deadline copyWith({
    String? title,
    String? subjectId,
    String? subjectName,
    DateTime? dueDate,
    DeadlineType? type,
    Priority? priority,
    bool? isCompleted,
    String? description,
    int? reminderBeforeMinutes,
  }) => Deadline(
    id: id,
    title: title ?? this.title,
    subjectId: subjectId ?? this.subjectId,
    subjectName: subjectName ?? this.subjectName,
    dueDate: dueDate ?? this.dueDate,
    type: type ?? this.type,
    priority: priority ?? this.priority,
    isCompleted: isCompleted ?? this.isCompleted,
    description: description ?? this.description,
    reminderBeforeMinutes: reminderBeforeMinutes ?? this.reminderBeforeMinutes,
  );
}
