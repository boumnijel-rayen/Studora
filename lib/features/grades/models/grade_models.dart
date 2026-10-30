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

  factory Grade.fromJson(Map<String, dynamic> json) {
    final subjectMap = json['subject'] is Map<String, dynamic>
        ? json['subject'] as Map<String, dynamic>
        : null;

    return Grade(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      subjectId: (json['subjectId'] ?? subjectMap?['id'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? subjectMap?['name'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      value: (json['value'] is num)
          ? (json['value'] as num).toDouble()
          : double.tryParse('${json['value']}') ?? 0.0,
      coefficient: (json['coefficient'] is num)
          ? (json['coefficient'] as num).toDouble()
          : double.tryParse('${json['coefficient']}') ?? 1.0,
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  final String id;
  final String subjectId;
  final String subjectName;
  final String title;
  final double value; // 0 à 20
  final double coefficient;
  final DateTime date;

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'subjectName': subjectName,
    'title': title,
    'value': value,
    'coefficient': coefficient,
    'date': date.toUtc().toIso8601String(),
  };
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

  factory AcademicGoal.fromJson(Map<String, dynamic> json) {
    final subjectMap = json['subject'] is Map<String, dynamic>
        ? json['subject'] as Map<String, dynamic>
        : null;
    final rawSubId = json['subjectId'] ?? subjectMap?['id'];
    final subId = (rawSubId == null || rawSubId.toString().isEmpty)
        ? null
        : rawSubId.toString();

    return AcademicGoal(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      targetAverage: (json['targetAverage'] is num)
          ? (json['targetAverage'] as num).toDouble()
          : double.tryParse('${json['targetAverage']}') ?? 10.0,
      subjectName: (json['subjectName'] ?? subjectMap?['name'] ?? 'Moyenne Générale').toString(),
      subjectId: subId,
    );
  }

  final String id;
  final String title;
  final double targetAverage;
  final String subjectName;
  final String? subjectId; // null = moyenne générale

  Map<String, dynamic> toJson() => {
    'title': title,
    'targetAverage': targetAverage,
    'subjectName': subjectName,
    if (subjectId != null) 'subjectId': subjectId,
  };
}
