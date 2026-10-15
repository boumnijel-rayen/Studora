/// Validateurs de formulaires partagés (messages en français).
///
/// ```dart
/// AppTextField(validator: Validators.compose([Validators.required(), Validators.email()]))
/// ```
abstract final class Validators {
  static String? Function(String?) required([String message = 'Ce champ est obligatoire']) =>
      (v) => (v == null || v.trim().isEmpty) ? message : null;

  static String? Function(String?) email([String message = 'Adresse e-mail invalide']) =>
      (v) {
        if (v == null || v.trim().isEmpty) return null;
        final ok = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$').hasMatch(v.trim());
        return ok ? null : message;
      };

  static String? Function(String?) minLength(int n, [String? message]) =>
      (v) => (v != null && v.isNotEmpty && v.length < n) ? (message ?? 'Au moins $n caractères') : null;

  static String? Function(String?) maxLength(int n, [String? message]) =>
      (v) => (v != null && v.length > n) ? (message ?? 'Maximum $n caractères') : null;

  /// Au moins 8 caractères, une majuscule et un chiffre.
  static String? Function(String?) password() => (v) {
    if (v == null || v.isEmpty) return null;
    if (v.length < 8) return 'Au moins 8 caractères';
    if (!RegExp('[A-Z]').hasMatch(v)) return 'Au moins une majuscule';
    if (!RegExp('[0-9]').hasMatch(v)) return 'Au moins un chiffre';
    return null;
  };

  static String? Function(String?) match(String Function() other, [String message = 'Les valeurs ne correspondent pas']) =>
      (v) => v != other() ? message : null;

  static String? Function(String?) number({double? min, double? max}) => (v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.replaceAll(',', '.').trim());
    if (n == null) return 'Nombre invalide';
    if (min != null && n < min) return 'Minimum : ${_fmt(min)}';
    if (max != null && n > max) return 'Maximum : ${_fmt(max)}';
    return null;
  };

  /// Note sur 20.
  static String? Function(String?) grade() => number(min: 0, max: 20);

  /// Montant positif.
  static String? Function(String?) amount() => (v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = double.tryParse(v.replaceAll(',', '.').trim());
    if (n == null) return 'Montant invalide';
    if (n <= 0) return 'Le montant doit être positif';
    return null;
  };

  static String? Function(String?) phone([String message = 'Numéro invalide']) => (v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^\+?[0-9 .-]{8,}$').hasMatch(v.trim()) ? null : message;
  };

  /// Combine plusieurs validateurs (premier message d'erreur retourné).
  static String? Function(String?) compose(List<String? Function(String?)> validators) => (v) {
    for (final f in validators) {
      final r = f(v);
      if (r != null) return r;
    }
    return null;
  };

  /// Validateur générique pour les champs non textuels (date, liste…).
  static String? Function(T?) requiredValue<T>([String message = 'Ce champ est obligatoire']) =>
      (v) => v == null ? message : null;

  static String _fmt(double d) => d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}

/// Convertit une saisie (« 12,5 ») en double.
double? parseDecimal(String? v) => v == null ? null : double.tryParse(v.replaceAll(',', '.').trim());
