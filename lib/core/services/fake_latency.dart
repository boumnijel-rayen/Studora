import 'dart:math';

/// Simule la latence (et éventuellement l'échec) d'un appel réseau.
///
/// À utiliser dans TOUS les mock repositories pour afficher
/// les états de chargement et d'erreur :
/// ```dart
/// Future<List<Course>> fetchCourses() => FakeLatency.run(() => _courses);
/// ```
abstract final class FakeLatency {
  static final _rng = Random();

  /// Probabilité globale d'échec simulé (0 = jamais). Utile en démo.
  static double failureRate = 0;

  static Future<T> run<T>(
    T Function() body, {
    int minMs = 300,
    int maxMs = 800,
  }) async {
    await Future<void>.delayed(Duration(milliseconds: minMs + _rng.nextInt(maxMs - minMs + 1)));
    if (failureRate > 0 && _rng.nextDouble() < failureRate) {
      throw const SimulatedNetworkException();
    }
    return body();
  }
}

class SimulatedNetworkException implements Exception {
  const SimulatedNetworkException();
  @override
  String toString() => 'Erreur réseau simulée';
}
