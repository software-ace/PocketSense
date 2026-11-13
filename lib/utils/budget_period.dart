/// The calendar window a budget is measured against, as inclusive dates.
/// Weeks start on Monday (ISO 8601); months run from the 1st to the last day.
({DateTime start, DateTime end}) budgetPeriod(String period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (period == 'weekly') {
    // Calendar arithmetic, not 24-hour steps, so a clock change can't move
    // either end off midnight (it dropped a whole Monday in Egypt).
    final start = DateTime(today.year, today.month, today.day - (today.weekday - DateTime.monday));
    return (start: start, end: DateTime(start.year, start.month, start.day + 6));
  }
  return (start: DateTime(today.year, today.month, 1), end: DateTime(today.year, today.month + 1, 0));
}
