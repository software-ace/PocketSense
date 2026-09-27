/// The calendar window a budget is measured against, as inclusive dates.
/// Weeks start on Monday (ISO 8601); months run from the 1st to the last day.
({DateTime start, DateTime end}) budgetPeriod(String period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  if (period == 'weekly') {
    final start = today.subtract(Duration(days: today.weekday - DateTime.monday));
    // Calendar arithmetic, not +6×24h, so DST changes can't shift the end date.
    return (start: start, end: DateTime(start.year, start.month, start.day + 6));
  }
  return (start: DateTime(today.year, today.month, 1), end: DateTime(today.year, today.month + 1, 0));
}
