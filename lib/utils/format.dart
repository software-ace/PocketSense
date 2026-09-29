import 'package:intl/intl.dart';

// Money is Jordanian dinars, stored everywhere as integer fils
// (1 JOD = 1000 fils), so sums never pick up floating-point error.
const filsPerDinar = 1000;

bool _arabic(String? locale) => (locale ?? Intl.getCurrentLocale()).startsWith('ar');

/// Latin digits in both languages (what Jordanian banks and shops print), so
/// the pattern always uses 'en' number symbols regardless of the UI language.
final _amount = NumberFormat('#,##0.000', 'en');

/// "JOD 12.500" in English; "12.500 د.أ" in Arabic. The number sits in a
/// left-to-right isolate so a minus sign stays next to it in RTL text.
String formatMoney(int? fils, {bool showSign = false, String? locale}) {
  if (fils == null) return '—';
  final sign = fils < 0 ? '-' : (showSign ? '+' : '');
  final n = _amount.format(fils.abs() / filsPerDinar);
  return _arabic(locale) ? '\u2066$sign$n\u2069\u00A0د.أ' : '${sign}JOD\u00A0$n';
}

/// Short axis label without the currency, e.g. "1.5k" or "250".
String compactAmount(double dinars) {
  String trim(double v) => v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
  return dinars >= 1000 ? '${trim(dinars / 1000)}k' : trim(dinars);
}

/// The currency label for an amount field: a prefix in English, a suffix in
/// Arabic, matching [formatMoney].
({String? prefix, String? suffix}) currencyAffix({String? locale}) =>
    _arabic(locale) ? (prefix: null, suffix: ' د.أ') : (prefix: 'JOD ', suffix: null);

const _easternDigits = '٠١٢٣٤٥٦٧٨٩';
const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

/// Parses what someone typed into an amount field into fils. Accepts Latin
/// or Arabic-Indic digits, `.` or `٫` as the decimal point, and thousands
/// separators. Returns null for anything else, including more than three
/// decimals (there is nothing smaller than a fils).
int? parseAmount(String input) {
  final b = StringBuffer();
  for (final ch in input.trim().split('')) {
    final e = _easternDigits.indexOf(ch), f = _persianDigits.indexOf(ch);
    if (e >= 0) {
      b.write(e);
    } else if (f >= 0) {
      b.write(f);
    } else if (ch == '٫') {
      b.write('.');
    } else if (ch != ',' && ch != '٬' && ch != ' ' && ch != '\u00A0') {
      b.write(ch);
    }
  }
  final m = RegExp(r'^(\d*)(?:\.(\d{0,3}))?$').firstMatch(b.toString());
  if (m == null || (m.group(1)!.isEmpty && (m.group(2) ?? '').isEmpty)) return null;
  final whole = m.group(1)!.isEmpty ? 0 : int.parse(m.group(1)!);
  final frac = int.parse((m.group(2) ?? '').padRight(3, '0'));
  return whole * filsPerDinar + frac;
}

/// Pre-fills an amount field: 12500 → "12.5", 12000 → "12".
String amountToInput(int fils) {
  final whole = fils ~/ filsPerDinar;
  final frac = (fils % filsPerDinar).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? '$whole' : '$whole.$frac';
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
