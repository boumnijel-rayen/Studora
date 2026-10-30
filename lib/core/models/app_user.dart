import 'package:flutter/foundation.dart';

/// Utilisateur connecté (partagé par tous les modules, synchronisé avec Strapi `users-permissions`).
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
    this.role = 'authenticated',
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final username = (json['username'] ?? '').toString().trim();
    var firstName = (json['firstName'] ?? '').toString().trim();
    var lastName = (json['lastName'] ?? '').toString().trim();

    if (firstName.isEmpty && username.isNotEmpty) {
      final parts = username.split(RegExp(r'\s+'));
      firstName = parts.first;
      if (lastName.isEmpty && parts.length > 1) {
        lastName = parts.sublist(1).join(' ');
      }
    }

    String roleName = 'authenticated';
    final rawRole = json['role'];
    if (rawRole is Map<String, dynamic>) {
      roleName = (rawRole['type'] ?? rawRole['name'] ?? 'authenticated').toString();
    } else if (rawRole is String && rawRole.isNotEmpty) {
      roleName = rawRole;
    }

    return AppUser(
      id: (json['id'] ?? json['documentId'] ?? '').toString(),
      firstName: firstName,
      lastName: lastName,
      email: (json['email'] ?? '').toString(),
      university: (json['university'] ?? '').toString(),
      program: (json['program'] ?? '').toString(),
      year: (json['year'] is num) ? (json['year'] as num).toInt() : int.tryParse('${json['year']}') ?? 1,
      bio: (json['bio'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      role: roleName,
    );
  }

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
  final String role;

  String get fullName {
    final combined = '$firstName $lastName'.trim();
    return combined.isNotEmpty ? combined : email;
  }

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'university': university,
    'program': program,
    'year': year,
    'bio': bio,
    'phone': phone,
  };

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? university,
    String? program,
    int? year,
    String? bio,
    String? phone,
    String? role,
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
    role: role ?? this.role,
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
      other.phone == phone &&
      other.role == role;

  @override
  int get hashCode =>
      Object.hash(id, firstName, lastName, email, university, program, year, bio, phone, role);
}
