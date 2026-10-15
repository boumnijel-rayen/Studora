import 'package:flutter/foundation.dart';

@immutable
class Grade {
  const Grade({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.title,
    required this.value,
    required this.coefficient,
    required this.date,
  });

  final String id;
  final String subjectId;
  final String subjectName;
  final String title;
  final double value; // 0 à 20
  final double coefficient;
  final DateTime date;
}

@immutable
class AcademicGoal {
  const AcademicGoal({
    required this.id,
    required this.title,
    required this.targetAverage,
    required this.subjectName,
    this.subjectId,
  });

  final String id;
  final String title;
  final double targetAverage;
  final String subjectName;
  final String? subjectId; // null = moyenne générale
}
