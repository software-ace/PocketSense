// Pure: which reminders fall in a time window, and what each one says.
// The notification service (reminder_notifications.dart) schedules them.

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import 'format.dart';
import 'recurring.dart';

/// One reminder for one due date. [payload] names what it's about:
/// `recurring:<id>` or `loan:<id>`.
class Reminder {
  const Reminder({required this.at, required this.due, required this.payload, this.item, this.loan});
  final DateTime at;
  final DateTime due;
  final String payload;
  final RecurringExpense? item;
  final Loan? loan;

  /// The same for every run, so rescheduling replaces rather than doubles it.
  int get id => Object.hash(payload, at.millisecondsSinceEpoch) & 0x7fffffff;
}

// Synced rows come from other devices: anything out of range is ignored.
int? _days(int? d) => d != null && d >= 0 && d <= 365 ? d : null;
int _minutes(int m) => m >= 0 && m < 24 * 60 ? m : defaultReminderMinutes;

DateTime _at(DateTime due, int daysBefore, int minutes) =>
    DateTime(due.year, due.month, due.day - daysBefore, minutes ~/ 60, minutes % 60);

/// Every reminder after [from], up to and including [to], soonest first.
/// Paused items, settled loans and loans without a due date have none. A
/// loan reminded days before is reminded again on the day if still open.
List<Reminder> remindersBetween(Iterable<RecurringExpense> items, Iterable<Loan> loans, DateTime from, DateTime to) {
  final out = <Reminder>[];
  void add(Reminder r) {
    if (r.at.isAfter(from) && !r.at.isAfter(to)) out.add(r);
  }

  for (final r in items) {
    final days = _days(r.reminderDays);
    if (!r.active || days == null) continue;
    // The first due date whose reminder can't be before [from].
    var due = nextOccurrence(r.frequency, r.anchorDate, DateTime(from.year, from.month, from.day + days));
    while (true) {
      final at = _at(due, days, _minutes(r.dueMinutes));
      if (at.isAfter(to)) break;
      add(Reminder(at: at, due: due, payload: 'recurring:${r.id}', item: r));
      due = nextOccurrence(r.frequency, r.anchorDate, DateTime(due.year, due.month, due.day + 1));
    }
  }
  for (final l in loans) {
    final days = _days(l.reminderDays);
    final due = l.dueDate;
    if (!l.open || due == null || days == null) continue;
    for (final before in {days, 0}) {
      add(Reminder(at: _at(due, before, _minutes(l.dueMinutes)), due: due, payload: 'loan:${l.id}', loan: l));
    }
  }
  return out..sort((a, b) => a.at.compareTo(b.at));
}

/// The notification's text, counted from [today] (a missed reminder shown
/// late says how late). [amounts]: the setting to include them; [locale]
/// formats them.
String reminderText(AppLocalizations l, Reminder r, DateTime today, {required bool amounts, required String locale}) {
  // Rounded: across a DST change two midnights are 23 or 25 hours apart.
  final days = (DateTime(r.due.year, r.due.month, r.due.day).difference(DateTime(today.year, today.month, today.day)).inHours / 24).round();
  final when = days >= 0 ? l.reminderWhen(days) : l.reminderLate(-days);
  String money(int fils) => formatMoney(fils, locale: locale, showHidden: true);
  final item = r.item;
  if (item != null) {
    return amounts ? l.reminderRecurringAmount(item.description, money(item.amountFils), when) : l.reminderRecurring(item.description, when);
  }
  final loan = r.loan!;
  if (!amounts) return l.reminderLoan(loan.person, when);
  return loan.lent ? l.reminderLent(loan.person, money(loan.remainingFils), when) : l.reminderBorrowed(loan.person, money(loan.remainingFils), when);
}
