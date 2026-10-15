import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Formatage des dates, heures, nombres et montants (fr_FR).
abstract final class Formatters {
  static final _day = DateFormat('EEEE d MMMM', 'fr_FR');
  static final _short = DateFormat('d MMM', 'fr_FR');
  static final _full = DateFormat('d MMMM y', 'fr_FR');
  static final _time = DateFormat('HH:mm', 'fr_FR');
  static final _weekday = DateFormat('EEE', 'fr_FR');

  /// « mercredi 15 octobre »
  static String day(DateTime d) => _capitalize(_day.format(d));

  /// « 15 oct. »
  static String shortDate(DateTime d) => _short.format(d);

  /// « 15 octobre 2026 »
  static String fullDate(DateTime d) => _full.format(d);

  /// « 09:30 »
  static String time(DateTime d) => _time.format(d);

  /// « 09:30 »
  static String timeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// « mer. »
  static String weekday(DateTime d) => _weekday.format(d);

  /// « 14,25 »
  static String decimal(num v, {int digits = 2}) =>
      NumberFormat.decimalPatternDigits(locale: 'fr_FR', decimalDigits: digits).format(v);

  /// « 12,50 € »
  static String money(num v, {String symbol = '€'}) =>
      NumberFormat.currency(locale: 'fr_FR', symbol: symbol, decimalDigits: 2).format(v);

  /// « 25 min », « 1 h 30 »
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '$m min';
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
  }

  /// « il y a 5 min », « dans 2 j »…
  static String relative(DateTime d, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = d.difference(ref);
    final past = diff.isNegative;
    final a = diff.abs();
    String v;
    if (a.inMinutes < 1) return 'à l\'instant';
    if (a.inMinutes < 60) {
      v = '${a.inMinutes} min';
    } else if (a.inHours < 24) {
      v = '${a.inHours} h';
    } else {
      v = '${a.inDays} j';
    }
    return past ? 'il y a $v' : 'dans $v';
  }

  /// Jours restants avant [d] (0 = aujourd'hui).
  static int daysUntil(DateTime d, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final a = DateTime(n.year, n.month, n.day);
    final b = DateTime(d.year, d.month, d.day);
    return b.difference(a).inDays;
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

extension DateTimeX on DateTime {
  bool isSameDay(DateTime o) => year == o.year && month == o.month && day == o.day;
  DateTime get dateOnly => DateTime(year, month, day);
  DateTime get startOfWeek => dateOnly.subtract(Duration(days: weekday - 1));
}
