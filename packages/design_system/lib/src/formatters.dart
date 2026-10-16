import 'package:intl/intl.dart';

abstract final class Money {
  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  /// Money travels as integer cents: no floating-point rounding errors.
  static String format(int cents) => _brl.format(cents / 100).replaceAll(' ', ' ');

  /// "1.234,56" / "1234,5" / "1234.56" → cents; null if invalid.
  static int? parse(String input) {
    var clean = input.replaceAll(r'R$', '').replaceAll(' ', '').trim();
    if (clean.isEmpty) return null;
    if (clean.contains(',')) clean = clean.replaceAll('.', '').replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(clean)) return null;
    final parts = clean.split('.');
    final cents = parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0;
    return int.parse(parts[0]) * 100 + cents;
  }
}

abstract final class Dates {
  static String dayHeader(DateTime day, {DateTime? now}) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final d = DateUtils.dateOnly(day);
    if (d == today) return 'Hoje';
    if (d == today.subtract(const Duration(days: 1))) return 'Ontem';
    final text = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d);
    return text[0].toUpperCase() + text.substring(1);
  }

  static String time(DateTime t) => DateFormat.Hm().format(t);
}

/// Local copy to avoid importing Flutter's material library in pure formatting code.
abstract final class DateUtils {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
