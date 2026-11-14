import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../security/amount_privacy.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../utils/recurring.dart';
import '../widgets/amount_field.dart';
import '../widgets/data_aware.dart';
import '../widgets/reminder_countdown.dart';
import '../widgets/reminder_field.dart';
import '../widgets/state_views.dart';
import 'loans_screen.dart' show AmountDateSheet, DateField, NetLabel, TotalTile;
import 'settings_screen.dart';
import 'sync_screen.dart';

/// The text of a circle's entries in Activity, in the UI language:
/// "Payment to Family circle", "Payout from Family circle".
String Function(String type, String name) circleDescriber(AppLocalizations l) =>
    (type, name) => type == 'expense' ? l.circlePaymentTo(name) : l.circlePayoutFrom(name);

/// Shows the new-circle sheet and saves what it returns.
Future<void> addCircle(BuildContext context) async {
  final d = await showModalBottomSheet<_CircleDraft>(context: context, isScrollControlled: true, builder: (_) => const _CircleFormSheet());
  if (d == null || !context.mounted) return;
  final l = context.l10n;
  try {
    await FinanceRepo().insertCircle(
      name: d.name,
      contributionFils: d.contributionFils,
      rounds: d.rounds,
      frequency: d.frequency,
      startDate: d.startDate,
      payoutRound: d.payoutRound,
      note: d.note,
      reminderDays: d.reminderDays,
      dueMinutes: d.dueMinutes,
    );
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.addFailed('$e'))));
  }
}

/// Every savings circle you're in, with where you stand in each.
class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key, this.tab = false});

  /// A desktop rail tab rather than a page pushed from Home, as for Loans.
  final bool tab;

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> with DataAware {
  List<Circle> _circles = [];
  Object? _error;
  bool _loading = true;
  bool _finished = false;

  @override
  void onDataChanged() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final circles = await FinanceRepo().circles();
      if (!mounted) return;
      setState(() {
        _circles = circles;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pad = PlatformUi.hPadding(context);
    final totals = circleTotals(_circles);
    final shown = [for (final c in _circles) if (c.done == _finished) c];
    return Scaffold(
      appBar: AppBar(title: Text(l.circles), actions: widget.tab ? const [AmountsButton(), SyncButton(), SettingsButton()] : null),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: null, onPressed: () => addCircle(context), icon: const Icon(Icons.add), label: Text(l.newCircle)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error.toString(), onRetry: _load)
              : _circles.isEmpty
                  ? EmptyView(icon: Icons.groups_outlined, title: l.noCirclesYet, subtitle: l.noCirclesHint)
                  : ListView(
                      // Room below the last row so the floating button never covers it.
                      padding: EdgeInsets.fromLTRB(pad, 8, pad, 88),
                      children: [
                        Row(children: [
                          Expanded(child: TotalTile(label: l.circlesOweYou, fils: totals.owedToYou, good: true)),
                          const SizedBox(width: 12),
                          Expanded(child: TotalTile(label: l.youOweCircles, fils: totals.youOwe)),
                        ]),
                        const SizedBox(height: 16),
                        Center(
                          child: SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(value: false, label: Text(l.circlesActive)),
                              ButtonSegment(value: true, label: Text(l.circlesFinished)),
                            ],
                            selected: {_finished},
                            onSelectionChanged: (s) => setState(() => _finished = s.first),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (shown.isEmpty)
                          EmptyView(icon: Icons.groups_outlined, title: _finished ? l.noFinishedCircles : l.noActiveCircles)
                        else
                          for (final c in shown) _tile(context, c),
                      ],
                    ),
    );
  }

  Widget _tile(BuildContext context, Circle c) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final next = c.nextRound;
    final overdue = c.overdue(todayDate());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CircleScreen(circleId: c.id))),
      leading: CircleAvatar(radius: 18, child: Text(c.name.characters.firstOrNull?.toUpperCase() ?? '')),
      title: Text(c.name),
      subtitle: next == null
          ? null
          : Text(
              '${l.circleRoundOf(next, c.rounds)} · '
              '${overdue ? l.overdueSince(formatDate(c.dueDate(next))) : l.dueOn(formatDate(c.dueDate(next)))}',
              style: overdue ? TextStyle(color: theme.colorScheme.error) : null),
      trailing: _finished ? Text(l.circlesFinished, style: TextStyle(color: theme.colorScheme.outline)) : NetLabel(net: -c.positionFils, toYou: l.circleOwesYou, byYou: l.youOweCircle),
    );
  }
}

/// One circle: its terms, where you stand, and its schedule.
class CircleScreen extends StatefulWidget {
  const CircleScreen({super.key, required this.circleId, this.pay = false});
  final int circleId;

  /// Opens Record payment once loaded (a reminder's Create Transaction).
  final bool pay;

  @override
  State<CircleScreen> createState() => _CircleScreenState();
}

class _CircleScreenState extends State<CircleScreen> with DataAware {
  late bool _payPending = widget.pay;
  final _repo = FinanceRepo();
  Circle? _circle;
  int _entries = 0;
  Object? _error;
  bool _loading = true;

  @override
  void onDataChanged() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await _repo.circle(widget.circleId);
      final entries = await _repo.transactions(circleId: widget.circleId, limit: 1 << 30);
      if (!mounted) return;
      setState(() {
        _circle = c;
        _entries = entries.length;
        _error = null;
        _loading = false;
      });
      if (_payPending && c != null && c.leftToPayFils > 0) {
        _payPending = false;
        WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _record(c, 'expense') : null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Record payment ([type] expense) or Record payout (income).
  Future<void> _record(Circle c, String type) async {
    final l = context.l10n;
    final payout = type == 'income';
    final draft = await showModalBottomSheet<({int amountFils, DateTime date})>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AmountDateSheet(
              title: payout ? l.recordCirclePayout : l.recordCirclePayment,
              subtitle: c.name,
              // A payment starts at what finishes the current round, a payout at the whole pot.
              initialFils: payout ? c.potFils : (c.contributionFils - c.partialFils).clamp(0, c.leftToPayFils),
              maxFils: payout ? null : c.leftToPayFils,
            ));
    if (draft == null || !mounted) return;
    try {
      await _repo.recordCircleEntry(c.id, type: type, amountFils: draft.amountFils, date: draft.date, description: circleDescriber(l)(type, c.name));
    } catch (e) {
      if (mounted) _toast(l.addFailed('$e'));
    }
  }

  Future<void> _edit(Circle c) async {
    final d = await showModalBottomSheet<_CircleDraft>(context: context, isScrollControlled: true, builder: (_) => _CircleFormSheet(existing: c));
    if (d == null || !mounted) return;
    final l = context.l10n;
    try {
      await _repo.updateCircle(c.id,
          name: d.name,
          contributionFils: d.contributionFils,
          rounds: d.rounds,
          frequency: d.frequency,
          startDate: d.startDate,
          payoutRound: d.payoutRound,
          note: d.note,
          reminderDays: d.reminderDays,
          dueMinutes: d.dueMinutes,
          describe: circleDescriber(l));
    } catch (e) {
      if (mounted) _toast(l.updateFailed('$e'));
    }
  }

  Future<void> _delete(Circle c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(d.l10n.deleteCircleTitle),
        content: Text(d.l10n.deleteLoanBody(_entries)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(d.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(d.l10n.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteCircle(c.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _toast(context.l10n.deleteFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final c = _circle;
    if (_loading || _error != null || c == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.circleTitle)),
        body: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error.toString(), onRetry: _load)
                : EmptyView(icon: Icons.groups_outlined, title: l.noCirclesYet),
      );
    }
    final pad = PlatformUi.hPadding(context);
    final today = todayDate();
    final next = c.nextRound;
    final overdue = c.overdue(today);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    return Scaffold(
      appBar: AppBar(title: Text(l.circleTitle), actions: [
        IconButton(icon: const Icon(Icons.edit_outlined), tooltip: l.edit, onPressed: () => _edit(c)),
        IconButton(icon: const Icon(Icons.delete_outline), tooltip: l.delete, onPressed: () => _delete(c)),
      ]),
      body: ListView(padding: EdgeInsets.fromLTRB(pad, 8, pad, 16), children: [
        Text(c.name, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 4),
        Text(l.circlePayoutOf(formatMoney(c.potFils)), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('${l.circleTurnOn(formatDate(c.payoutDate))} · ${l.circleRoundOf(c.payoutRound, c.rounds)}', style: theme.textTheme.bodyMedium),
        Text(l.circleTerms(formatMoney(c.contributionFils), c.rounds, formatFrequency(l, c.frequency)), style: muted),
        if (c.note?.isNotEmpty ?? false) ...[const SizedBox(height: 8), Text(c.note!)],
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: (c.paidFils / c.potFils).clamp(0, 1),
            color: c.done ? theme.colorScheme.outline : Colors.green,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(l.circlePaid(formatMoney(c.paidFils)), style: theme.textTheme.bodySmall)),
          Text(c.leftToPayFils > 0 ? l.amountLeft(formatMoney(c.leftToPayFils)) : l.circlesFinished,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ]),
        if (next != null) ...[
          const SizedBox(height: 4),
          Text(overdue ? l.overdueSince(formatDate(c.dueDate(next))) : l.dueOn(formatDate(c.dueDate(next))),
              style: theme.textTheme.bodySmall?.copyWith(color: overdue ? theme.colorScheme.error : null)),
        ],
        if (c.received) ...[
          const SizedBox(height: 4),
          Text(l.circlePayoutReceived(formatMoney(c.receivedFils)), style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
        ],
        const SizedBox(height: 16),
        NetLabel(net: -c.positionFils, toYou: l.circleOwesYou, byYou: l.youOweCircle, large: true),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TotalTile(label: l.circleUpToTurn, fils: c.upToTurnFils)),
          const SizedBox(width: 12),
          Expanded(child: TotalTile(label: l.circleAfterTurn, fils: c.afterTurnFils)),
        ]),
        const SizedBox(height: 24),
        ReminderCountdown(circle: c),
        Text(l.circleSchedule, style: theme.textTheme.titleMedium),
        for (var round = 1; round <= c.rounds; round++) _roundTile(context, c, round, today),
      ]),
      // Record payment is the main action until everything's paid.
      bottomNavigationBar: c.done
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (c.leftToPayFils > 0) FilledButton(onPressed: () => _record(c, 'expense'), child: Text(l.recordCirclePayment)),
                  if (c.leftToPayFils > 0 && !c.received) const SizedBox(height: 8),
                  if (!c.received) OutlinedButton(onPressed: () => _record(c, 'income'), child: Text(l.recordCirclePayout)),
                ]),
              ),
            ),
    );
  }

  Widget _roundTile(BuildContext context, Circle c, int round, DateTime today) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final due = c.dueDate(round);
    final paid = round <= c.paidRounds;
    final partly = round == c.nextRound && c.partialFils > 0;
    final late = !paid && due.isBefore(today);
    final turn = round == c.payoutRound;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: paid
          ? const Icon(Icons.check_circle, color: Colors.green)
          : Icon(partly ? Icons.timelapse : (late ? Icons.error_outline : Icons.radio_button_unchecked),
              color: late ? scheme.error : scheme.outline),
      title: Text(formatDate(due), style: late ? TextStyle(color: scheme.error) : null),
      subtitle: Text([
        l.circleRoundOf(round, c.rounds),
        if (partly) l.circlePaid(formatMoney(c.partialFils)),
        if (turn) l.circlePayoutOf(formatMoney(c.potFils)),
      ].join(' · ')),
      // Your turn: a flag, green once the payout is in.
      trailing: turn ? Icon(Icons.flag, color: c.received ? Colors.green : scheme.primary) : null,
    );
  }
}

class _CircleDraft {
  _CircleDraft(this.name, this.contributionFils, this.rounds, this.frequency, this.startDate, this.payoutRound, this.note, this.reminderDays,
      this.dueMinutes);
  final String name;
  final int contributionFils;
  final int rounds;
  final String frequency;
  final DateTime startDate;
  final int payoutRound;
  final String? note;
  final int? reminderDays;
  final int dueMinutes;
}

/// New circle; with [existing], edits it.
class _CircleFormSheet extends StatefulWidget {
  const _CircleFormSheet({this.existing});
  final Circle? existing;

  @override
  State<_CircleFormSheet> createState() => _CircleFormSheetState();
}

class _CircleFormSheetState extends State<_CircleFormSheet> {
  late final _c = widget.existing;
  late final _nameCtrl = TextEditingController(text: _c?.name ?? '');
  late final _amountCtrl = TextEditingController(text: _c == null ? '' : amountToInput(_c.contributionFils));
  late final _roundsCtrl = TextEditingController(text: '${_c?.rounds ?? 10}');
  late final _turnCtrl = TextEditingController(text: '${_c?.payoutRound ?? 1}');
  late final _noteCtrl = TextEditingController(text: _c?.note ?? '');
  late String _frequency = _c?.frequency ?? 'monthly';
  late DateTime _start = _c?.startDate ?? todayDate();
  late int? _reminderDays = _c?.reminderDays;
  late int _dueMinutes = _c?.dueMinutes ?? defaultReminderMinutes;
  final _formKey = GlobalKey<FormState>();
  // Errors show only after a save attempt, then update as the user types.
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _amountCtrl, _roundsCtrl, _turnCtrl, _noteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  int? get _rounds {
    final n = int.tryParse(latinDigits(_roundsCtrl.text));
    return n != null && n >= 2 && n <= Circle.maxRounds ? n : null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final note = _noteCtrl.text.trim();
    Navigator.pop(
        context,
        _CircleDraft(_nameCtrl.text.trim(), parseAmount(_amountCtrl.text)!, _rounds!, _frequency, _start, int.parse(latinDigits(_turnCtrl.text)),
            note.isEmpty ? null : note, _reminderDays, _dueMinutes));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final frequency = Circle.frequencies.contains(_frequency) ? _frequency : 'monthly';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      // Keeps Save above the navigation bar: Android 15+ draws apps behind it.
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_c == null ? l.newCircle : l.editCircle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: l.circleName),
                validator: (v) => (v ?? '').trim().isEmpty ? l.enterCircleName : null,
              ),
              const SizedBox(height: 12),
              AmountField(controller: _amountCtrl, label: l.circleContribution),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: TextFormField(
                    controller: _roundsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l.circleRounds, errorMaxLines: 2),
                    // The turn's limit follows the rounds.
                    onChanged: (_) => setState(() {}),
                    validator: (_) => _rounds == null ? l.circleRoundsRange(Circle.maxRounds) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _turnCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l.circleYourTurn, errorMaxLines: 2),
                    validator: (v) {
                      final rounds = _rounds ?? Circle.maxRounds;
                      final n = int.tryParse(latinDigits(v ?? ''));
                      return n == null || n < 1 || n > rounds ? l.circleTurnRange(rounds) : null;
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [for (final f in Circle.frequencies) ButtonSegment(value: f, label: Text(formatFrequency(l, f)))],
                selected: {frequency},
                onSelectionChanged: (s) => setState(() => _frequency = s.first),
              ),
              const SizedBox(height: 12),
              DateField(label: l.circleFirstPayment, value: _start, onPicked: (d) => setState(() => _start = d)),
              const SizedBox(height: 12),
              TimeField(label: l.dueTime, minutes: _dueMinutes, onPicked: (m) => setState(() => _dueMinutes = m)),
              const SizedBox(height: 12),
              ReminderField(days: _reminderDays, onChanged: (d) => setState(() => _reminderDays = d)),
              const SizedBox(height: 12),
              TextField(controller: _noteCtrl, decoration: InputDecoration(labelText: l.notesOptional)),
              const SizedBox(height: 20),
              FilledButton(onPressed: _save, child: Text(l.save)),
            ]),
          ),
        ),
      ),
    );
  }
}
