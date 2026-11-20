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

// ── Analyse IA de l'historique ────────────────────────────────────────────────

int _readInt(dynamic v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

double _readDouble(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

List<T> _readList<T>(dynamic v, T Function(Map<String, dynamic>) fromJson) => v is List
    ? v.whereType<Map<String, dynamic>>().map(fromJson).toList()
    : <T>[];

/// Tendance repérée par l'IA (`progres`, `negligee`, `moment`, `regularite`, `notes`).
@immutable
class StudyObservation {
  const StudyObservation({required this.type, required this.texte});

  factory StudyObservation.fromJson(Map<String, dynamic> json) => StudyObservation(
    type: (json['type'] ?? '').toString(),
    texte: (json['texte'] ?? '').toString(),
  );

  final String type;
  final String texte;
}

/// Lien entre temps de révision et moyenne d'une matière.
@immutable
class GradeLink {
  const GradeLink({
    required this.subjectName,
    required this.minutesRevisees,
    required this.moyenne,
    this.commentaire = '',
  });

  factory GradeLink.fromJson(Map<String, dynamic> json) => GradeLink(
    subjectName: (json['subjectName'] ?? '').toString(),
    minutesRevisees: _readInt(json['minutesRevisees']),
    moyenne: _readDouble(json['moyenne']),
    commentaire: (json['commentaire'] ?? '').toString(),
  );

  final String subjectName;
  final int minutesRevisees;
  final double moyenne;
  final String commentaire;
}

/// Session proposée par l'IA, validée par le serveur.
@immutable
class SessionRecommendation {
  const SessionRecommendation({
    required this.subjectId,
    required this.subjectName,
    required this.dureeMinutes,
    required this.date,
    this.raison = '',
  });

  factory SessionRecommendation.fromJson(Map<String, dynamic> json) => SessionRecommendation(
    subjectId: (json['subjectId'] ?? '').toString(),
    subjectName: (json['subjectName'] ?? '').toString(),
    dureeMinutes: _readInt(json['dureeMinutes'], 30),
    date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
    raison: (json['raison'] ?? '').toString(),
  );

  final String subjectId;
  final String subjectName;
  final int dureeMinutes;
  final DateTime date;
  final String raison;
}

/// Résultat complet de `POST /api/study-sessions/insights`.
@immutable
class StudyInsights {
  const StudyInsights({
    required this.resume,
    this.observations = const [],
    this.liensNotes = const [],
    this.recommandations = const [],
    this.donneesInsuffisantes = false,
  });

  factory StudyInsights.fromJson(Map<String, dynamic> json) => StudyInsights(
    resume: (json['resume'] ?? '').toString(),
    observations: _readList(json['observations'], StudyObservation.fromJson),
    liensNotes: _readList(json['liensNotes'], GradeLink.fromJson),
    recommandations: _readList(json['recommandations'], SessionRecommendation.fromJson),
    donneesInsuffisantes: json['donneesInsuffisantes'] == true,
  );

  final String resume;
  final List<StudyObservation> observations;
  final List<GradeLink> liensNotes;
  final List<SessionRecommendation> recommandations;
  final bool donneesInsuffisantes;

  StudyInsights withoutRecommendation(int index) => StudyInsights(
    resume: resume,
    observations: observations,
    liensNotes: liensNotes,
    recommandations: [
      for (var i = 0; i < recommandations.length; i++)
        if (i != index) recommandations[i],
    ],
    donneesInsuffisantes: donneesInsuffisantes,
  );
}
