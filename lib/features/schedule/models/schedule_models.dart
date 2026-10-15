import 'package:flutter/material.dart';

enum DeadlineType {
  exam('Examen', Icons.assignment_late_rounded),
  homework('Devoir', Icons.assignment_rounded),
  project('Projet', Icons.folder_shared_rounded);

  const DeadlineType(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum Priority {
  high('Urgent', Color(0xFFEF4444)),
  medium('Moyen', Color(0xFFF59E0B)),
  low('Faible', Color(0xFF3B82F6));

  const Priority(this.label, this.color);
  final String label;
  final Color color;
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
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - '
      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';
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
