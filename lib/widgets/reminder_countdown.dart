import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/reminders.dart';

/// [left] in words, zero units left out: "2 days, 9 seconds". Seconds always
/// show, so a countdown visibly ticks.
String countdownText(AppLocalizations l, Duration left) => [
      if (left.inDays > 0) l.countdownDays(left.inDays),
      if (left.inHours % 24 > 0) l.countdownHours(left.inHours % 24),
      if (left.inMinutes % 60 > 0) l.countdownMinutes(left.inMinutes % 60),
      l.countdownSeconds(left.inSeconds % 60),
    ].join(l.countdownSeparator);

/// "Your next reminder in: 2 days, 4 hours, 5 minutes, 9 seconds", counting
/// down each second to the reminder the scheduler will give for [item],
/// [loan] or [circle] (the same rules); nothing when none is still to come.
class ReminderCountdown extends StatefulWidget {
  const ReminderCountdown({super.key, this.item, this.loan, this.circle, this.compact = false, this.inTable = false});
  final RecurringExpense? item;
  final Loan? loan;
  final Circle? circle;

  /// A list row's second line: small type and icon, no space below.
  final bool compact;

  /// In a desktop table cell: just the time, wrapped to a narrow width, with
  /// the sentence as a tooltip. The whole line (longer still in Arabic)
  /// widened the table past the window and squeezed its headers.
  final bool inTable;

  @override
  State<ReminderCountdown> createState() => _ReminderCountdownState();
}

class _ReminderCountdownState extends State<ReminderCountdown> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final now = DateTime.now();
    // A recurring item is due at least yearly, so a year and a bit always
    // holds its next reminder (and keeps a weekly one's list short, as this
    // runs every second). A loan or a circle (at most 120 months) gets 11 years.
    final to = w.item != null ? now.add(const Duration(days: 400)) : DateTime(now.year + 11);
    final next = remindersBetween([?w.item], [?w.loan], now, to, [?w.circle]).firstOrNull;
    if (next == null) return const SizedBox.shrink();
    final l = context.l10n;
    final time = countdownText(l, next.at.difference(now));
    final text = w.circle != null ? l.circleNextReminder(time) : l.nextReminderIn(time);
    final theme = Theme.of(context);
    if (w.inTable) {
      return Tooltip(
        message: text,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.notifications_active_outlined, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(child: Text(time, style: theme.textTheme.bodySmall)),
          ]),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: w.compact ? 2 : 0, bottom: w.compact ? 0 : 12),
      child: Row(children: [
        Icon(Icons.notifications_active_outlined, size: w.compact ? 14 : 18, color: theme.colorScheme.primary),
        SizedBox(width: w.compact ? 4 : 8),
        Flexible(child: Text(text, style: w.compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)),
      ]),
    );
  }
}
