import 'package:intl/intl.dart';

/// Formats an integer-cent amount as a signed, currency-styled string.
/// Matches the React client's display convention (single currency, cents).
String formatMoney(int? cents, {bool showSign = false}) {
  if (cents == null) return '—';
  final negative = cents < 0;
  final abs = cents.abs();
  final dollars = NumberFormat('#,##0.00', 'en_US').format(abs / 100);
  final prefix = negative ? '-' : (showSign && !negative ? '+' : '');
  return '$prefix\$$dollars';
}

/// Parses "YYYY-MM-DD" or an ISO datetime into a [DateTime], best-effort.
DateTime? parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final s = raw.toString();
  // Date-only (YYYY-MM-DD): treat as local midnight to avoid TZ shifts.
  if (s.length == 10) {
    final p = s.split('-');
    if (p.length == 3) {
      return DateTime(int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 1, int.tryParse(p[2]) ?? 1);
    }
  }
  return DateTime.tryParse(s);
}

String formatDate(dynamic raw) {
  final dt = parseDate(raw);
  if (dt == null) return '';
  return DateFormat('MMM d, yyyy').format(dt.toLocal());
}
