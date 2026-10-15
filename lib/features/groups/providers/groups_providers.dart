import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';

final _initialGroups = [
  const StudyGroup(
    id: 'g-1',
    name: 'Team Algo & Complexité',
    description: 'Préparation des examens et partage des corrigés de TD en Algorithmique.',
    subjectId: 's-algo',
    subjectName: 'Algorithmique',
    memberNames: ['Rayen Ben Ali', 'Alice Dubois', 'Thomas Leroy', 'Inès Mansour'],
    code: 'ALGO42',
    colorIndex: 3,
    isJoined: true,
  ),
  const StudyGroup(
    id: 'g-2',
    name: 'Dev Mobile Flutter L3',
    description: 'Entraide sur les widgets, Riverpod et la mise en commun des projets d\'application.',
    subjectId: 's-mobile',
    subjectName: 'Développement mobile',
    memberNames: ['Rayen Ben Ali', 'Marc Dupont', 'Sophie Bernard'],
    code: 'FLUT77',
    colorIndex: 2,
    isJoined: true,
  ),
  const StudyGroup(
    id: 'g-3',
    name: 'Prépa Partiels Maths',
    description: 'Groupe d\'entraînement intensif aux équations et séries.',
    subjectId: 's-math',
    subjectName: 'Mathématiques',
    memberNames: ['Alice Dubois', 'Inès Mansour', 'Lucas Martin'],
    code: 'MATH99',
    colorIndex: 0,
    isJoined: false,
  ),
];

final _initialMessages = <String, List<GroupMessage>>{
  'g-1': [
    GroupMessage(
      id: 'm-1',
      groupId: 'g-1',
      senderName: 'Alice Dubois',
      text: 'Salut tout le monde ! On se retrouve à la BU vers 14h pour le TD 3 ?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      isMe: false,
    ),
    GroupMessage(
      id: 'm-2',
      groupId: 'g-1',
      senderName: 'Thomas Leroy',
      text: 'Carrément, j\'ai bloqué sur la question de récursivité terminale.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 32)),
      isMe: false,
    ),
    GroupMessage(
      id: 'm-3',
      groupId: 'g-1',
      senderName: 'Rayen Ben Ali',
      text: 'Ça marche pour moi ! J\'apporte mes fiches de synthèse.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      isMe: true,
    ),
  ],
  'g-2': [
    GroupMessage(
      id: 'm-20',
      groupId: 'g-2',
      senderName: 'Marc Dupont',
      text: 'Est-ce que vous avez testé les animations avec TweenAnimationBuilder ?',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      isMe: false,
    ),
  ],
};

class GroupsNotifier extends Notifier<List<StudyGroup>> {
  @override
  List<StudyGroup> build() => _initialGroups;

  void addGroup(StudyGroup group) => state = [...state, group];

  void joinGroup(String code) {
    state = [
      for (final g in state)
        if (g.code.toUpperCase() == code.toUpperCase())
          g.copyWith(isJoined: true, memberNames: [...g.memberNames, 'Rayen Ben Ali'])
        else
          g,
    ];
  }
}

final groupsProvider = NotifierProvider<GroupsNotifier, List<StudyGroup>>(GroupsNotifier.new);

class GroupMessagesNotifier extends Notifier<Map<String, List<GroupMessage>>> {
  @override
  Map<String, List<GroupMessage>> build() => _initialMessages;

  void sendMessage(String groupId, String text, String senderName) {
    final newMsg = GroupMessage(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
      isMe: true,
    );

    final current = state[groupId] ?? [];
    state = {...state, groupId: [...current, newMsg]};
  }

  void addIncomingMessage(String groupId, String senderName, String text) {
    final reply = GroupMessage(
      id: 'm-${DateTime.now().millisecondsSinceEpoch}',
      groupId: groupId,
      senderName: senderName,
      text: text,
      timestamp: DateTime.now(),
      isMe: false,
    );
    final current = state[groupId] ?? [];
    state = {...state, groupId: [...current, reply]};
  }
}

final groupMessagesProvider =
    NotifierProvider<GroupMessagesNotifier, Map<String, List<GroupMessage>>>(GroupMessagesNotifier.new);
