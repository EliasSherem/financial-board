import 'package:intl/intl.dart';

final DateFormat _df = DateFormat('dd/MM/yyyy');
final NumberFormat _usd = NumberFormat.currency(locale: 'en_US', symbol: '\$');

String formatDate(DateTime d) => _df.format(d);

DateTime? parseYmdLocal(String input) {
  try {
    final s = input.trim();
    if (s.isEmpty) return null;
    final head = s.length >= 10 ? s.substring(0, 10) : s;
    final headMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(head);
    if (headMatch != null) {
      final year = int.parse(headMatch.group(1)!);
      final month = int.parse(headMatch.group(2)!);
      final day = int.parse(headMatch.group(3)!);
      return DateTime(year, month, day);
    }
    final iso = DateTime.tryParse(s);
    if (iso != null) {
      return iso.isUtc ? iso.toLocal() : iso;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Format a date string like `YYYY-MM-DD` or ISO8601 into `DD/MM/YYYY`.
/// If parsing fails, returns the original input.
String formatYmd(String input) {
  try {
    final d = parseYmdLocal(input);
    if (d != null) return _df.format(d);
    return input;
  } catch (_) {
    return input;
  }
}

/// Parse a dd/MM/yyyy string; returns null if it can't be parsed.
DateTime? parseDdMmYyyy(String s) {
  try {
    return DateFormat('dd/MM/yyyy').parseStrict(s);
  } catch (_) {
    return null;
  }
}

/// Convert dd/MM/yyyy to YYYY-MM-DD (for API inputs). If parsing fails, returns original.
String ddMmYyyyToYmd(String s) {
  final d = parseDdMmYyyy(s);
  if (d == null) return s;
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

// Money formatting
String money(num v) => _usd.format(v);
String moneyAbs(num v) => _usd.format(v.abs());
String signedMoney(num v) => (v >= 0 ? '+' : '-') + _usd.format(v.abs());

