import 'package:flutter/material.dart';

import '../design_system/tokens/app_colors.dart';

/// Matière (partagée par Planning, Révisions et Notes).
@immutable
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.shortName,
    required this.colorIndex,
    required this.icon,
    this.coefficient = 1,
    this.teacher = '',
  });

  final String id;
  final String name;
  final String shortName;

  /// Index dans [AppColors.subjectPalette].
  final int colorIndex;
  final IconData icon;
  final double coefficient;
  final String teacher;

  Color get color => AppColors.subjectPalette[colorIndex % AppColors.subjectPalette.length];

  @override
  bool operator ==(Object other) => other is Subject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
