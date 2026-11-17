import '../models/models.dart';
import 'recurring.dart';

/// One thing due on one day: a recurring item's occurrence, a loan's due
/// date, a circle round you pay, or your circle payout. Exactly one of
/// [recurring], [loan] and [circle] is set.
class CalendarItem {
  CalendarItem(this.date, this.amountFils, {required this.incoming, this.paid = false, this.overdue = false, this.recurring, this.loan, this.circle, this.round, this.payout = false});

  final DateTime date;
  final int amountFils;
  final bool incoming;

  /// A circle round paid, or a payout received.
  final bool paid;
  final bool overdue;
  final RecurringExpense? recurring;
  final Loan? loan;
  final Circle? circle;
  final int? round;
  final bool payout;
}

/// Everything due in [month] of [year]. Paused recurring items and settled
/// or undated loans have no due date, so they're left out.
List<CalendarItem> monthItems(int year, int month, {required List<RecurringExpense> recurring, required List<Loan> loans, required List<Circle> circles, required DateTime today}) {
  final start = DateTime(year, month, 1), end = DateTime(year, month + 1, 0);
  bool inMonth(DateTime d) => !d.isBefore(start) && !d.isAfter(end);
  final out = <CalendarItem>[];
  for (final r in recurring.where((r) => r.active)) {
    for (var d = nextOccurrence(r.frequency, r.anchorDate, start); !d.isAfter(end); d = nextOccurrence(r.frequency, r.anchorDate, DateTime(d.year, d.month, d.day + 1))) {
      out.add(CalendarItem(d, r.amountFils, incoming: r.type == 'income', recurring: r));
    }
  }
  for (final l in loans) {
    if (l.open && l.dueDate != null && inMonth(l.dueDate!)) out.add(_loanItem(l, today));
  }
  for (final c in circles) {
    for (var r = 1; r <= c.rounds; r++) {
      final d = c.dueDate(r);
      if (inMonth(d)) out.addAll(_roundItems(c, r, today));
    }
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Open loans past their due date, unpaid circle rounds before [today] and
/// payouts not received by their day,
/// oldest first, whatever month is on screen.
List<CalendarItem> overdueItems({required List<Loan> loans, required List<Circle> circles, required DateTime today}) {
  final out = [
    for (final l in loans)
      if (l.overdue(today)) _loanItem(l, today),
    for (final c in circles) ...[
      // Paid rounds are oldest first, so only rounds after them can be late.
      for (var r = c.paidRounds + 1; r <= c.rounds && c.dueDate(r).isBefore(today); r++) ..._roundItems(c, r, today).where((i) => i.overdue && !i.payout),
      // Your payout, if its day has passed and nothing came in; it can fall in a round you've paid.
      ..._roundItems(c, c.payoutRound, today).where((i) => i.payout && i.overdue),
    ],
  ];
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// What's still to come in [items] from [today] on: not paid, not past.
({int coming, int going}) stillDue(Iterable<CalendarItem> items, DateTime today) {
  final rest = items.where((i) => !i.paid && !i.date.isBefore(today));
  int sum(bool incoming) => rest.where((i) => i.incoming == incoming).fold(0, (a, i) => a + i.amountFils);
  return (coming: sum(true), going: sum(false));
}

CalendarItem _loanItem(Loan l, DateTime today) => CalendarItem(l.dueDate!, l.remainingFils, incoming: l.lent, overdue: l.overdue(today), loan: l);

List<CalendarItem> _roundItems(Circle c, int r, DateTime today) {
  final d = c.dueDate(r), paid = r <= c.paidRounds;
  return [
    CalendarItem(d, c.contributionFils, incoming: false, paid: paid, overdue: !paid && d.isBefore(today), circle: c, round: r),
    if (r == c.payoutRound) CalendarItem(d, c.potFils, incoming: true, paid: c.received, overdue: !c.received && d.isBefore(today), circle: c, round: r, payout: true),
  ];
}
