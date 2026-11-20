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
      id: (json['documentId'] ?? json['id'] ?? '').toString(),
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
    this.attachmentName,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentSize,
  });

  factory GroupMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final senderMap = json['sender'] is Map<String, dynamic>
        ? json['sender'] as Map<String, dynamic>
        : null;
    final senderId = (json['senderId'] ?? senderMap?['id'])?.toString();
    final isMeFlag = json['isMe'] is bool
        ? json['isMe'] as bool
        : (currentUserId != null && senderId == currentUserId);

    final rawSize = json['attachmentSize'];
    final int? parsedSize = rawSize is num
        ? rawSize.toInt()
        : int.tryParse('$rawSize');

    return GroupMessage(
      id: (json['documentId'] ?? json['id'] ?? '').toString(),
      groupId: (json['groupId'] ?? '').toString(),
      senderName: (json['senderName'] ?? 'Étudiant').toString(),
      text: (json['text'] ?? '').toString(),
      timestamp: DateTime.tryParse((json['timestamp'] ?? json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      isMe: isMeFlag,
      senderId: senderId,
      attachmentName: json['attachmentName']?.toString(),
      attachmentUrl: json['attachmentUrl']?.toString(),
      attachmentType: json['attachmentType']?.toString(),
      attachmentSize: parsedSize,
    );
  }

  final String id;
  final String groupId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMe;
  final String? senderId;
  final String? attachmentName;
  final String? attachmentUrl;
  final String? attachmentType;
  final int? attachmentSize;

  bool get hasAttachment =>
      (attachmentName != null && attachmentName!.trim().isNotEmpty) ||
      text.startsWith('📄 Document joint :');

  String get resolvedAttachmentName {
    if (attachmentName != null && attachmentName!.trim().isNotEmpty) {
      return attachmentName!.trim();
    }
    if (text.startsWith('📄 Document joint :')) {
      return text.replaceFirst('📄 Document joint : ', '').trim();
    }
    return '';
  }

  String get attachmentExtension {
    if (!hasAttachment) return '';
    final name = resolvedAttachmentName;
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    return 'pdf';
  }

  String get formattedAttachmentSize {
    if (attachmentSize == null || attachmentSize! <= 0) return '';
    final bytes = attachmentSize!;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'senderName': senderName,
    'text': text,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (attachmentName != null) 'attachmentName': attachmentName,
    if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
    if (attachmentType != null) 'attachmentType': attachmentType,
    if (attachmentSize != null) 'attachmentSize': attachmentSize,
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
    this.time = '',
    this.duration = '',
  });

  factory GroupActivity.fromJson(Map<String, dynamic> json) {
    final rawParticipants = json['participantNames'];
    return GroupActivity(
      id: (json['documentId'] ?? json['id'] ?? '').toString(),
      groupId: (json['groupId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      date: DateTime.tryParse((json['date'] ?? '').toString()) ?? DateTime.now(),
      location: (json['location'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      duration: (json['duration'] ?? '').toString(),
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
  final String time;
  final String duration;
  final List<String> participantNames;

  Map<String, dynamic> toJson() => {
    'groupId': groupId,
    'title': title,
    'description': description,
    'date': date.toUtc().toIso8601String(),
    'location': location,
    if (time.isNotEmpty) 'time': time,
    if (duration.isNotEmpty) 'duration': duration,
    'participantNames': participantNames,
  };
}
