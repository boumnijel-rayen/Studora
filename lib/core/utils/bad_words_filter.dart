/// Utilitaire de filtrage des propos injurieux ou déplacés (bad words).
abstract final class BadWordsFilter {
  static final Set<String> _badWords = {
    'merde',
    'connard',
    'connasse',
    'pute',
    'salope',
    'enculé',
    'encule',
    'fdp',
    'putain',
    'batard',
    'ntm',
    'con',
    'connards',
    'salaud',
    'connasses',
    'pd',
    'enculés',
    'bite',
    'couille',
    'enculeur',
  };

  static bool containsBadWords(String text) {
    if (text.isEmpty) return false;
    final clean = text.toLowerCase();
    final words = clean.replaceAll(RegExp(r'[^\w\sàâäéèêëîïôöùûüç]'), '').split(RegExp(r'\s+'));

    for (final word in words) {
      if (_badWords.contains(word)) {
        return true;
      }
    }

    for (final bad in _badWords) {
      if (bad.length >= 4 && clean.contains(bad)) {
        return true;
      }
    }

    return false;
  }
}
