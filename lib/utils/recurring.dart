// Pure, deterministic date math for recurring items. A month step keeps the
// day but never spills into the next month: Jan 31, Feb 28, Mar 31, Apr 30.

import '../l10n/app_localizations.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// [d] plus [months] months, on the same day or that month's last if it's
/// shorter (Jan 31 + 1 is Feb 28, + 2 is Mar 31; Feb 29 + 12 is Feb 28).
DateTime addMonths(DateTime d, int months) {
  final last = DateTime(d.year, d.month + months + 1, 0).day;
  return DateTime(d.year, d.month + months, d.day < last ? d.day : last);
}

/// Next occurrence on or after [from] for a frequency anchored at [anchor]:
/// the first of anchor, anchor + 1 period, anchor + 2 periods… that isn't
/// before [from]. Steps are always counted from the anchor, so a yearly item
/// keeps its month, a quarterly one its 3-month rhythm and a bi-weekly one its
/// week. A future anchor is its own first occurrence.
DateTime nextOccurrence(String frequency, DateTime anchor, DateTime from) {
  final a = _dateOnly(anchor);
  final f = _dateOnly(from);
  if (!a.isBefore(f)) return a;

  final days = switch (frequency) { 'weekly' => 7, 'biweekly' => 14, _ => 0 };
  if (days > 0) {
    // Whole days between two midnights, rounded so a DST change can't skew it.
    final gap = (f.difference(a).inHours / 24).round();
    final k = (gap + days - 1) ~/ days;
    // Calendar-day arithmetic, not Duration, for the same reason.
    return DateTime(a.year, a.month, a.day + k * days);
  }

  final months = switch (frequency) {
    'monthly' => 1,
    'quarterly' => 3,
    'yearly' => 12,
    _ => throw ArgumentError('unknown frequency: $frequency'),
  };
  // Start from the last step that can't be past [from], then walk forward.
  var k = ((f.year - a.year) * 12 + (f.month - a.month)) ~/ months;
  if (k > 0) k--;
  var cand = addMonths(a, k * months);
  while (cand.isBefore(f)) {
    k++;
    cand = addMonths(a, k * months);
  }
  return cand;
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
