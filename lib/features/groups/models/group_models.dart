import 'package:flutter/material.dart';

@immutable
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.subjectId,
    required this.subjectName,
    required this.memberNames,
    required this.code,
    this.colorIndex = 6,
    this.isJoined = true,
  });

  factory StudyGroup.fromJson(Map<String, dynamic> json) {
    final subjectMap = json['subject'] is Map<String, dynamic>
        ? json['subject'] as Map<String, dynamic>
        : null;
    final rawMembers = json['memberNames'];
    final memberNames = rawMembers is List
        ? rawMembers.map((e) => e.toString()).toList()
        : const <String>[];

    return StudyGroup(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      subjectId: (json['subjectId'] ?? subjectMap?['id'] ?? '').toString(),
      subjectName: (json['subjectName'] ?? subjectMap?['name'] ?? '').toString(),
      memberNames: memberNames,
      code: (json['code'] ?? '').toString(),
      colorIndex: (json['colorIndex'] is num)
          ? (json['colorIndex'] as num).toInt()
          : int.tryParse('${json['colorIndex']}') ?? 6,
      isJoined: json['isJoined'] != false,
    );
  }

  final String id;
  final String name;
  final String description;
  final String subjectId;
  final String subjectName;
  final List<String> memberNames;
  final String code;
  final int colorIndex;
  final bool isJoined;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'subjectId': subjectId,
    'subjectName': subjectName,
    'memberNames': memberNames,
    'code': code,
    'colorIndex': colorIndex,
  };

  StudyGroup copyWith({
    String? name,
    String? description,
    List<String>? memberNames,
    bool? isJoined,
  }) => StudyGroup(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    subjectId: subjectId,
    subjectName: subjectName,
    memberNames: memberNames ?? this.memberNames,
    code: code,
    colorIndex: colorIndex,
    isJoined: isJoined ?? this.isJoined,
  );
}

@immutable
class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isMe,
    this.senderId,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final senderMap = json['sender'] is Map<String, dynamic>
        ? json['sender'] as Map<String, dynamic>
        : null;
    final senderId = (json['senderId'] ?? senderMap?['id'])?.toString();
    final isMeFlag = json['isMe'] is bool
        ? json['isMe'] as bool
        : (currentUserId != null && senderId == currentUserId);

    return GroupMessage(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      groupId: (json['groupId'] ?? '').toString(),
      senderName: (json['senderName'] ?? 'Étudiant').toString(),
      text: (json['text'] ?? '').toString(),
      timestamp: DateTime.tryParse((json['timestamp'] ?? json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      isMe: isMeFlag,
      senderId: senderId,
    );
  }

  final String id;
  final String groupId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String? senderId;

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'senderName': senderName,
    'text': text,
    'timestamp': timestamp.toUtc().toIso8601String(),
  };
}

@immutable
class GroupActivity {
  const GroupActivity({
    required this.id,
    required this.groupId,
    required this.title,
    required this.date,
    required this.location,
    required this.participantNames,
    this.description = '',
  });

  factory GroupActivity.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participantNames'];
    return GroupActivity(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      groupId: (json['groupId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      location: (json['location'] ?? '').toString(),
      participantNames: rawParticipants is List
          ? rawParticipants.map((e) => e.toString()).toList()
          : const <String>[],
    );
  }

  final String id;
  final String groupId;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final List<String> participantNames;

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'title': title,
    'description': description,
    'date': date.toUtc().toIso8601String(),
    'location': location,
    'participantNames': participantNames,
  };
}
