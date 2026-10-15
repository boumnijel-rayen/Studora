import 'package:flutter/foundation.dart';

/// Utilisateur connecté (partagé par tous les modules).
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.university = '',
    this.program = '',
    this.year = 1,
    this.bio = '',
    this.phone = '',
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String university;

  /// Filière (ex. « Licence Informatique »).
  final String program;

  /// Année d'études (1 = L1 …).
  final int year;
  final String bio;
  final String phone;

  String get fullName => '$firstName $lastName';

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? university,
    String? program,
    int? year,
    String? bio,
    String? phone,
  }) => AppUser(
    id: id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    university: university ?? this.university,
    program: program ?? this.program,
    year: year ?? this.year,
    bio: bio ?? this.bio,
    phone: phone ?? this.phone,
  );

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.firstName == firstName &&
      other.lastName == lastName &&
      other.email == email &&
      other.university == university &&
      other.program == program &&
      other.year == year &&
      other.bio == bio &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(id, firstName, lastName, email, university, program, year, bio, phone);
}
