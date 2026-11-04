import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../utils/reminder_notifications.dart';

/// Shows [minutes] after midnight as the locale writes a time ("9:00 AM").
String formatMinutes(BuildContext context, int minutes) =>
    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));

/// Picks a time of day; [onPicked] gets it in minutes after midnight.
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.label, required this.minutes, required this.onPicked});
  final String label;
  final int minutes;
  final ValueChanged<int> onPicked;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
          if (t != null) onPicked(t.hour * 60 + t.minute);
        },
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule, size: 18)),
          child: Text(formatMinutes(context, minutes)),
        ),
      );
}

/// A form's Reminder: Off, the same day, or 1, 3 or 7 days before, at the
/// item's due time. [days] is null when off.
class ReminderField extends StatefulWidget {
  const ReminderField({super.key, required this.days, required this.onChanged});
  final int? days;
  final ValueChanged<int?> onChanged;

  @override
  State<ReminderField> createState() => _ReminderFieldState();
}

class _ReminderFieldState extends State<ReminderField> {
  static const _off = -1;
  bool _allowed = true;
  bool _limited = false;

  @override
  void initState() {
    super.initState();
    if (widget.days != null) ReminderNotifications.allowed().then((a) => mounted ? setState(() => _allowed = a) : null);
    ReminderNotifications.backgroundLimited().then((v) => mounted ? setState(() => _limited = v) : null);
  }

  Future<void> _choose(int choice) async {
    final wasOff = widget.days == null;
    widget.onChanged(choice == _off ? null : choice);
    // The first reminder asks for the permission (Android 13+).
    if (wasOff && choice != _off) {
      final allowed = await ReminderNotifications.allowed(ask: true);
      if (mounted) setState(() => _allowed = allowed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final days = widget.days;
    final on = days != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<int>(
        initialValue: days ?? _off,
        // Fills a narrow dialog instead of overflowing it.
        isExpanded: true,
        decoration: InputDecoration(labelText: l.reminder, prefixIcon: const Icon(Icons.notifications_outlined)),
        items: [
          DropdownMenuItem(value: _off, child: Text(l.reminderOff)),
          DropdownMenuItem(value: 0, child: Text(l.reminderSameDayDueTime)),
          DropdownMenuItem(value: 1, child: Text(l.reminderDaysBefore(1))),
          DropdownMenuItem(value: 3, child: Text(l.reminderDaysBefore(3))),
          DropdownMenuItem(value: 7, child: Text(l.reminderWeekBefore)),
          // Any other number (set by an earlier build) is kept until changed.
          if (days != null && ![0, 1, 3, 7].contains(days)) DropdownMenuItem(value: days, child: Text(l.reminderDaysBefore(days))),
        ],
        onChanged: (v) => _choose(v!),
      ),
      if (on && !_allowed)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.reminderPermissionOff, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        )
      // Can't tell whether it's been done (no API), so it stays as a hint.
      else if (on && _limited)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(l.reminderBackgroundNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
            TextButton(onPressed: ReminderNotifications.openAppSettings, child: Text(l.reminderOpenSettings)),
          ]),
        )
      else if (on && Platform.isLinux)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.reminderDesktopNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ),
    ]);
  }
}
