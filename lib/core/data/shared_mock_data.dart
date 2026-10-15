import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../models/subject.dart';

/// Données fictives partagées entre modules.
abstract final class MockSharedData {
  static const AppUser demoUser = AppUser(
    id: 'u-001',
    firstName: 'Rayen',
    lastName: 'Ben Ali',
    email: 'rayen.benali@univ.fr',
    university: 'Université Paris-Saclay',
    program: 'Licence Informatique',
    year: 3,
    bio: 'Passionné de développement mobile et de café ☕',
    phone: '06 12 34 56 78',
  );

  static const List<Subject> subjects = [
    Subject(id: 's-math', name: 'Mathématiques', shortName: 'Maths', colorIndex: 0, icon: Icons.functions_rounded, coefficient: 4, teacher: 'Mme Laurent'),
    Subject(id: 's-algo', name: 'Algorithmique', shortName: 'Algo', colorIndex: 3, icon: Icons.account_tree_rounded, coefficient: 4, teacher: 'M. Garcia'),
    Subject(id: 's-mobile', name: 'Développement mobile', shortName: 'Mobile', colorIndex: 2, icon: Icons.phone_iphone_rounded, coefficient: 3, teacher: 'M. Nguyen'),
    Subject(id: 's-bdd', name: 'Bases de données', shortName: 'BDD', colorIndex: 5, icon: Icons.storage_rounded, coefficient: 3, teacher: 'Mme Dubois'),
    Subject(id: 's-reseau', name: 'Réseaux', shortName: 'Réseaux', colorIndex: 6, icon: Icons.lan_rounded, coefficient: 2, teacher: 'M. Martin'),
    Subject(id: 's-anglais', name: 'Anglais', shortName: 'Anglais', colorIndex: 4, icon: Icons.translate_rounded, coefficient: 2, teacher: 'Mrs Smith'),
    Subject(id: 's-physique', name: 'Physique', shortName: 'Physique', colorIndex: 1, icon: Icons.science_rounded, coefficient: 2, teacher: 'M. Petit'),
  ];
}

/// Liste des matières de l'étudiant.
final subjectsProvider = Provider<List<Subject>>((ref) => MockSharedData.subjects);

/// Recherche d'une matière par id.
final subjectByIdProvider = Provider.family<Subject?, String>((ref, id) {
  for (final s in ref.watch(subjectsProvider)) {
    if (s.id == id) return s;
  }
  return null;
});
