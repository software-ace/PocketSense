// Dart port of backend/recurring.py next_occurrence / days_until.
// Pure, deterministic date math — no model involved. Mirrors the JS/Python
// semantics exactly (month overflow rolls forward like `new Date(y, m+n, day)`).

import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Advance [d] by [n] calendar months, preserving day-of-month with overflow
/// rolling into the following month.
DateTime _addMonths(DateTime d, int n) {
  final total = (d.year * 12 + (d.month - 1)) + n;
  var year = total ~/ 12;
  var month = total % 12 + 1;
  if (month < 1) {
    month += 12;
    year -= 1;
  }
  final lastDay = _daysInMonth(year, month);
  if (d.day <= lastDay) {
    return DateTime(year, month, d.day);
  }
  final overflow = d.day - lastDay;
  final nt = year * 12 + month; // next month, 0-based
  final ny = nt ~/ 12;
  final nm = nt % 12 + 1;
  return DateTime(ny, nm, overflow);
}

/// Candidate in [frm]'s month at the anchor's day-of-month, rolling overflow
/// forward like JS `new Date(year, monthIndex, anchorDay)`.
DateTime _candidateAtAnchorDay(DateTime frm, int anchorDay) {
  final total = frm.year * 12 + (frm.month - 1);
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = _daysInMonth(year, month);
  if (anchorDay <= lastDay) {
    return DateTime(year, month, anchorDay);
  }
  final overflow = anchorDay - lastDay;
  final nt = total + 1;
  final ny = nt ~/ 12;
  final nm = nt % 12 + 1;
  return DateTime(ny, nm, overflow);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Next occurrence on or after [from] for a frequency anchored at [anchor].
DateTime nextOccurrence(String frequency, DateTime anchor, DateTime from) {
  final a = _dateOnly(anchor);
  final f = _dateOnly(from);

  if (frequency == 'weekly' || frequency == 'biweekly') {
    final weeks = frequency == 'weekly' ? 1 : 2;
    // Weekday index: DateTime.weekday is Mon=1..Sun=7; convert to Mon=0..Sun=6.
    final anchorWd = a.weekday % 7;
    final frmWd = f.weekday % 7;
    var delta = (anchorWd - frmWd) % 7;
    if (delta < 0) delta += 7;
    var cand = f.add(Duration(days: delta));
    while (cand.isBefore(f)) {
      cand = cand.add(Duration(days: weeks * 7));
    }
    return cand;
  }

  if (frequency == 'monthly') {
    var cand = _candidateAtAnchorDay(f, a.day);
    if (cand.isBefore(f)) cand = _addMonths(cand, 1);
    return cand;
  }

  if (frequency == 'quarterly') {
    var cand = _candidateAtAnchorDay(f, a.day);
    if (cand.isBefore(f)) cand = _addMonths(cand, 3);
    return cand;
  }

  if (frequency == 'yearly') {
    var cand = _candidateAtAnchorDay(f, a.day);
    if (cand.isBefore(f)) cand = _addMonths(cand, 12);
    return cand;
  }

  throw ArgumentError('unknown frequency: $frequency');
}

/// Days from today until [isoDate] (negative if overdue/past).
int daysUntil(DateTime isoDate) {
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(isoDate.year, isoDate.month, isoDate.day);
  return b.difference(a).inDays;
}

/// Every frequency the app offers, in display order.
const frequencies = ['weekly', 'biweekly', 'monthly', 'quarterly', 'yearly'];

String formatFrequency(AppLocalizations l, String freq) => switch (freq) {
      'weekly' => l.freqWeekly,
      'biweekly' => l.freqBiweekly,
      'monthly' => l.freqMonthly,
      'quarterly' => l.freqQuarterly,
      'yearly' => l.freqYearly,
      _ => freq,
    };

/// Convenience: "Oct 5" style short date.
String fmtShortDate(DateTime d) => DateFormat('MMM d').format(d.toLocal());
