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

  final String id;
  final String name;
  final String description;
  final String subjectId;
  final String subjectName;
  final List<String> memberNames;
  final String code;
  final int colorIndex;
  final bool isJoined;

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
  });

  final String id;
  final String groupId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
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
  });

  final String id;
  final String groupId;
  final String title;
  final DateTime date;
  final String location;
  final List<String> participantNames;
}

@immutable
class GroupResource {
  const GroupResource({
    required this.id,
    required this.groupId,
    required this.title,
    required this.type,
    required this.author,
    required this.size,
  });

  final String id;
  final String groupId;
  final String title;
  final String type; // PDF, Lien, Note
  final String author;
  final String size;
}
