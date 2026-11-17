import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/calendar.dart';
import '../utils/format.dart';
import '../utils/recurring.dart';
import 'circles_screen.dart';
import 'loans_screen.dart';

/// The Recurring screen's month view: recurring items, loan due dates and
/// circle rounds on one calendar, with what's still due this month and
/// what's overdue.
class RecurringCalendar extends StatefulWidget {
  const RecurringCalendar({super.key, required this.recurring, required this.loans, required this.circles, required this.onEdit});

  final List<RecurringExpense> recurring;
  final List<Loan> loans;
  final List<Circle> circles;
  final void Function(RecurringExpense) onEdit;

  @override
  State<RecurringCalendar> createState() => _RecurringCalendarState();
}

class _RecurringCalendarState extends State<RecurringCalendar> {
  // Null until the user picks a day or a month; till then both follow today, even past midnight.
  DateTime? _picked, _shown;
  DateTime get _selected => _picked ?? todayDate();
  DateTime get _month => _shown ?? DateTime(_selected.year, _selected.month);

  void _goMonth(int delta) => setState(() {
    final m = _month;
    _shown = _picked = DateTime(m.year, m.month + delta);
  });

  Color _color(ColorScheme scheme, CalendarItem i) => i.overdue
      ? scheme.error
      : i.incoming
      ? Colors.green
      : i.loan != null
      ? Colors.orange
      : i.circle != null
      ? Colors.teal
      : scheme.primary;

  void _open(CalendarItem i) {
    if (i.recurring != null) return widget.onEdit(i.recurring!);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => i.loan != null ? PersonLoansScreen(person: i.loan!.person) : CircleScreen(circleId: i.circle!.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final today = todayDate();
    final items = monthItems(_month.year, _month.month, recurring: widget.recurring, loans: widget.loans, circles: widget.circles, today: today);
    final overdue = overdueItems(loans: widget.loans, circles: widget.circles, today: today);
    final due = stillDue(items, today);
    final byDay = <int, List<CalendarItem>>{};
    for (final i in items) {
      (byDay[i.date.day] ??= []).add(i);
    }
    final dayItems = byDay[_selected.month == _month.month ? _selected.day : 0] ?? const [];
    final dayLabel = DateFormat.MMMMEEEEd().format(_selected);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), tooltip: MaterialLocalizations.of(context).previousMonthTooltip, onPressed: () => _goMonth(-1)),
            Expanded(
              child: Text(DateFormat.yMMMM().format(_month), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), tooltip: MaterialLocalizations.of(context).nextMonthTooltip, onPressed: () => _goMonth(1)),
          ],
        ),
        _grid(context, byDay, today),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _tile(theme, l.stillComingIn, formatMoney(due.coming, showSign: true), Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _tile(theme, l.stillGoingOut, formatMoney(due.going), null)),
          ],
        ),
        if (overdue.isNotEmpty) ...[const SizedBox(height: 8), _overdueTile(theme, overdue), _heading(theme, l.calendarOverdue), for (final i in overdue) _card(theme, i, today)],
        _heading(theme, _selected == today ? l.calendarToday(dayLabel) : dayLabel),
        if (dayItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              l.calendarNothingDue,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.outline),
            ),
          )
        else
          for (final i in dayItems) _card(theme, i, today),
      ],
    );
  }

  Widget _grid(BuildContext context, Map<int, List<CalendarItem>> byDay, DateTime today) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final material = MaterialLocalizations.of(context);
    // Sunday is 0 here; Arabic locales start the week on Saturday.
    final first = material.firstDayOfWeekIndex;
    final lead = (_month.weekday % 7 - first + 7) % 7;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.95,
      children: [
        for (var i = 0; i < 7; i++)
          Center(
            child: Text(material.narrowWeekdays[(first + i) % 7], style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
          ),
        for (var i = 0; i < lead; i++) const SizedBox.shrink(),
        for (var n = 1; n <= days; n++) _day(theme, DateTime(_month.year, _month.month, n), byDay[n] ?? const [], today),
      ],
    );
  }

  Widget _day(ThemeData theme, DateTime d, List<CalendarItem> items, DateTime today) {
    final scheme = theme.colorScheme;
    final selected = d == _selected, isToday = d == today;
    final fg = selected ? scheme.onSecondaryContainer : (d.isBefore(today) ? scheme.outline : null);
    return Semantics(
      button: true,
      selected: selected,
      label: '${DateFormat.yMMMMEEEEd().format(d)}, ${context.l10n.calendarDayItems(items.length)}',
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _picked = d),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: isToday
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.primary, width: 1.5),
                      )
                    : null,
                child: Text(DateFormat.d().format(d), style: theme.textTheme.bodyMedium?.copyWith(color: fg)),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final i in items.take(3))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(color: _color(scheme, i), shape: BoxShape.circle),
                      ),
                    if (items.length > 3) Text('+', style: TextStyle(fontSize: 9, height: 0.7, color: scheme.outline)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(ThemeData theme, String label, String amount, Color? color) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          Text(
            amount,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    ),
  );

  Widget _overdueTile(ThemeData theme, List<CalendarItem> overdue) {
    final l = context.l10n;
    final scheme = theme.colorScheme;
    int sum(bool incoming) => overdue.where((i) => i.incoming == incoming).fold(0, (a, i) => a + i.amountFils);
    final owed = sum(true), owe = sum(false);
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.calendarOverdueCount(overdue.length), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer)),
            Text(
              [if (owed > 0) '${l.owedToYou}: ${formatMoney(owed, showSign: true)}', if (owe > 0) '${l.youOwe}: ${formatMoney(owe)}'].join(' · '),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
    child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.outline)),
  );

  Widget _card(ThemeData theme, CalendarItem i, DateTime today) {
    final l = context.l10n;
    final scheme = theme.colorScheme;
    final r = i.recurring, loan = i.loan, c = i.circle;
    final (IconData icon, String title, String subtitle) = r != null
        ? (i.incoming ? Icons.arrow_upward : Icons.event_repeat, r.description, [formatFrequency(l, r.frequency), ?r.categoryName].join(' · '))
        : loan != null
        ? (Icons.handshake_outlined, loan.lent ? l.loanPaymentFrom(loan.person) : l.loanPaymentFor(loan.person), [l.loanTitle, ?loan.note].join(' · '))
        : (Icons.groups_outlined, i.payout ? l.circlePayoutFrom(c!.name) : l.circlePaymentTo(c!.name), l.circleRoundOf(i.round!, c.rounds));
    final days = daysUntil(i.date);
    final (String? status, Color? statusColor) = i.paid
        ? (i.payout ? l.calendarReceived : l.calendarPaid, Colors.green)
        : i.overdue
        ? (l.calendarOverdue, scheme.error)
        : days >= 0
        ? (days == 0 ? l.dueToday : l.dueInDays(days), scheme.outline)
        : (null, null);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () => _open(i),
        leading: CircleAvatar(child: Icon(icon, color: _color(scheme, i))),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatMoney(i.amountFils, showSign: i.incoming),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: i.incoming ? Colors.green : null),
            ),
            if (status != null) Text(status, style: theme.textTheme.bodySmall?.copyWith(color: statusColor)),
          ],
        ),
      ),
    );
  }
}
