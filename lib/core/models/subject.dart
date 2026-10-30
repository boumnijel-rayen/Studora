import 'package:flutter/material.dart';

import '../design_system/tokens/app_colors.dart';

/// Matière (partagée par Planning, Révisions, Groupes et Notes, persistée dans Strapi).
@immutable
class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.shortName,
    required this.colorIndex,
    required this.icon,
    this.iconKey = 'book',
    this.coefficient = 1,
    this.teacher = '',
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] ?? '').toString();
    final shortRaw = (json['shortName'] ?? '').toString();
    final shortName = shortRaw.isNotEmpty
        ? shortRaw
        : (name.length <= 6 ? name : name.substring(0, 6));
    final iconKey = (json['iconKey'] ?? 'book').toString();

    return Subject(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      name: name,
      shortName: shortName,
      colorIndex: (json['colorIndex'] is num)
          ? (json['colorIndex'] as num).toInt()
          : int.tryParse('${json['colorIndex']}') ?? 0,
      iconKey: iconKey,
      icon: iconFromKey(iconKey),
      coefficient: (json['coefficient'] is num)
          ? (json['coefficient'] as num).toDouble()
          : double.tryParse('${json['coefficient']}') ?? 1.0,
      teacher: (json['teacher'] ?? '').toString(),
    );
  }

  final String id;
  final String name;
  final String shortName;

  /// Index dans [AppColors.subjectPalette].
  final int colorIndex;
  final IconData icon;
  final String iconKey;
  final double coefficient;
  final String teacher;

  Color get color => AppColors.subjectPalette[colorIndex % AppColors.subjectPalette.length];

  Map<String, dynamic> toJson() => {
    'name': name,
    'shortName': shortName,
    'colorIndex': colorIndex,
    'iconKey': iconKey,
    'coefficient': coefficient,
    'teacher': teacher,
  };

  static IconData iconFromKey(String key) => switch (key) {
    'math' || 'functions' => Icons.functions_rounded,
    'algo' || 'code' => Icons.account_tree_rounded,
    'mobile' || 'phone' => Icons.phone_iphone_rounded,
    'bdd' || 'storage' => Icons.storage_rounded,
    'reseau' || 'network' => Icons.lan_rounded,
    'lang' || 'translate' => Icons.translate_rounded,
    'science' => Icons.science_rounded,
    _ => Icons.menu_book_rounded,
  };

  @override
  bool operator ==(Object other) => other is Subject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
