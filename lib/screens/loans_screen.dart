import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../utils/format.dart';
import '../utils/platform.dart';
import '../widgets/amount_field.dart';
import '../widgets/data_aware.dart';
import '../widgets/state_views.dart';

/// The text of a loan's entries in Activity, in the UI language: money out
/// is "Payment for Ahmad", money in "Payment from Ahmad".
String Function(String type, String person) loanDescriber(AppLocalizations l) =>
    (type, person) => type == 'expense' ? l.loanPaymentFor(person) : l.loanPaymentFrom(person);

/// One person's loans (names match ignoring case, as the database does),
/// in the order of their newest loan. [net] is what they owe you, less
/// what you owe them, over open loans.
List<({String name, List<Loan> loans, int net})> loansByPerson(List<Loan> loans) {
  final groups = <String, List<Loan>>{};
  for (final loan in loans) {
    groups.putIfAbsent(loan.person.toLowerCase(), () => []).add(loan);
  }
  return [
    for (final g in groups.values)
      (name: g.first.person, loans: g, net: g.fold(0, (sum, l) => sum + (l.lent ? l.remainingFils : -l.remainingFils))),
  ];
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Shows the new-loan sheet and saves what it returns.
Future<void> addLoan(BuildContext context, {String? person}) async {
  final draft = await showModalBottomSheet<_LoanDraft>(
      context: context, isScrollControlled: true, builder: (_) => _LoanFormSheet(person: person));
  if (draft == null || !context.mounted) return;
  final l = context.l10n;
  try {
    await FinanceRepo().insertLoan(
      direction: draft.direction,
      person: draft.person,
      amountFils: draft.amountFils,
      date: draft.date,
      dueDate: draft.dueDate,
      note: draft.note,
      description: loanDescriber(l)(draft.direction == 'lent' ? 'expense' : 'income', draft.person),
    );
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.addFailed('$e'))));
  }
}

/// Everyone you lent to or borrowed from, with what's still owed.
class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> with DataAware {
  final _repo = FinanceRepo();
  List<Loan> _loans = [];
  Object? _error;
  bool _loading = true;
  bool _settled = false;

  @override
  void onDataChanged() => _load();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loans = await _repo.loans();
      if (!mounted) return;
      setState(() {
        _loans = loans;
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
    final totals = loanTotals(_loans);
    // Open: anyone with something still owed; Settled: everyone else.
    final people = [for (final p in loansByPerson(_loans)) if (p.loans.any((x) => x.open) != _settled) p];
    return Scaffold(
      appBar: AppBar(title: Text(l.loans)),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: null, onPressed: () => addLoan(context), icon: const Icon(Icons.add), label: Text(l.newLoan)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error.toString(), onRetry: _load)
              : _loans.isEmpty
                  ? EmptyView(icon: Icons.handshake_outlined, title: l.noLoansYet, subtitle: l.noLoansHint)
                  : ListView(
                      // Room below the last row so the floating button never covers it.
                      padding: EdgeInsets.fromLTRB(pad, 8, pad, 88),
                      children: [
                        Row(children: [
                          Expanded(child: _TotalTile(label: l.owedToYou, fils: totals.owedToYou, good: true)),
                          const SizedBox(width: 12),
                          Expanded(child: _TotalTile(label: l.youOwe, fils: totals.youOwe)),
                        ]),
                        const SizedBox(height: 16),
                        Center(
                          child: SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(value: false, label: Text(l.loansUnsettled)),
                              ButtonSegment(value: true, label: Text(l.loansSettled)),
                            ],
                            selected: {_settled},
                            onSelectionChanged: (s) => setState(() => _settled = s.first),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (people.isEmpty)
                          EmptyView(icon: Icons.handshake_outlined, title: _settled ? l.noSettledLoans : l.noOpenLoans)
                        else
                          for (final p in people) _personTile(context, p),
                      ],
                    ),
    );
  }

  Widget _personTile(BuildContext context, ({String name, List<Loan> loans, int net}) p) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final today = _today();
    // The soonest due date among open loans; an overdue one shows first.
    final due = p.loans.where((x) => x.open && x.dueDate != null).map((x) => x.dueDate!).fold<DateTime?>(
        null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final overdue = due != null && due.isBefore(today);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PersonLoansScreen(person: p.name))),
      leading: CircleAvatar(radius: 18, child: Text(p.name.characters.first.toUpperCase())),
      title: Text(p.name),
      subtitle: due == null
          ? null
          : Text(overdue ? l.overdueSince(formatDate(due)) : l.dueOn(formatDate(due)),
              style: overdue ? TextStyle(color: theme.colorScheme.error) : null),
      trailing: _settled
          ? Text(l.loansSettled, style: TextStyle(color: theme.colorScheme.outline))
          : _NetLabel(net: p.net),
    );
  }
}

/// "Owes you" or "You owe" over the amount, or "Even".
class _NetLabel extends StatelessWidget {
  const _NetLabel({required this.net, this.large = false});
  final int net;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final label = net > 0 ? l.owesYou : (net < 0 ? l.youOwe : l.loanEven);
    final style = (large ? theme.textTheme.headlineSmall : theme.textTheme.bodyLarge)
        ?.copyWith(fontWeight: FontWeight.w600, color: net > 0 ? Colors.green : null);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: large ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        if (net != 0) Text(formatMoney(net.abs()), style: style),
      ],
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({required this.label, required this.fils, this.good = false});
  final String label;
  final int fils;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(formatMoney(fils),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: good && fils > 0 ? Colors.green : null)),
        ]),
      ),
    );
  }
}

/// One person's loans, open ones first.
class PersonLoansScreen extends StatefulWidget {
  const PersonLoansScreen({super.key, required this.person});
  final String person;

  @override
  State<PersonLoansScreen> createState() => _PersonLoansScreenState();
}

class _PersonLoansScreenState extends State<PersonLoansScreen> with DataAware {
  List<Loan> _loans = [];
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
      final all = await FinanceRepo().loans();
      if (!mounted) return;
      setState(() {
        _loans = [for (final x in all) if (x.person.toLowerCase() == widget.person.toLowerCase()) x];
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
    final open = _loans.where((x) => x.open).toList();
    final settled = _loans.where((x) => !x.open).toList();
    final net = loansByPerson(_loans).firstOrNull?.net ?? 0;
    Widget header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.outline)));
    return Scaffold(
      appBar: AppBar(title: Text(widget.person)),
      floatingActionButton: FloatingActionButton.extended(
          heroTag: null, onPressed: () => addLoan(context, person: widget.person), icon: const Icon(Icons.add), label: Text(l.newLoan)),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error.toString(), onRetry: _load)
              : _loans.isEmpty
                  ? EmptyView(icon: Icons.handshake_outlined, title: l.noLoansYet)
                  : ListView(padding: EdgeInsets.fromLTRB(pad, 8, pad, 88), children: [
                      _NetLabel(net: net, large: true),
                      if (open.isNotEmpty) ...[header(l.loansUnsettled), for (final x in open) _LoanCard(loan: x)],
                      if (settled.isNotEmpty) ...[header(l.loansSettled), for (final x in settled) _LoanCard(loan: x)],
                    ]),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final quiet = loan.open ? null : theme.colorScheme.outline;
    final overdue = loan.overdue(_today());
    final date = loan.date;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LoanScreen(loanId: loan.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text(
                    date == null ? (loan.lent ? l.iLent : l.iBorrowed) : (loan.lent ? l.lentOn(formatDate(date)) : l.borrowedOn(formatDate(date))),
                    style: theme.textTheme.titleSmall?.copyWith(color: quiet)),
              ),
              Text(formatMoney(loan.amountFils), style: theme.textTheme.titleSmall?.copyWith(color: quiet)),
            ]),
            const SizedBox(height: 10),
            _Progress(loan: loan),
            if (loan.open) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(l.amountRepaid(formatMoney(loan.repaidFils)), style: theme.textTheme.bodySmall)),
                Text(l.amountLeft(formatMoney(loan.remainingFils)),
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: loan.lent ? Colors.green : null)),
              ]),
              if (loan.dueDate != null) ...[
                const SizedBox(height: 4),
                Text(overdue ? l.overdueSince(formatDate(loan.dueDate!)) : l.dueOn(formatDate(loan.dueDate!)),
                    style: theme.textTheme.bodySmall?.copyWith(color: overdue ? theme.colorScheme.error : null)),
              ],
            ],
          ]),
        ),
      ),
    );
  }
}

/// How much of a loan has been repaid.
class _Progress extends StatelessWidget {
  const _Progress({required this.loan});
  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        minHeight: 8,
        value: loan.amountFils == 0 ? 1 : (loan.repaidFils / loan.amountFils).clamp(0, 1),
        color: loan.open ? Colors.green : scheme.outline,
        backgroundColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}

/// A loan, its repayments, and what can be done with it.
class LoanScreen extends StatefulWidget {
  const LoanScreen({super.key, required this.loanId});
  final int loanId;

  @override
  State<LoanScreen> createState() => _LoanScreenState();
}

class _LoanScreenState extends State<LoanScreen> with DataAware {
  final _repo = FinanceRepo();
  Loan? _loan;
  List<Transaction> _entries = [];
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
      final loan = await _repo.loan(widget.loanId);
      final entries = await _repo.transactions(loanId: widget.loanId, limit: 1 << 30);
      if (!mounted) return;
      setState(() {
        _loan = loan;
        _entries = entries;
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

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _repay(Loan loan) async {
    final draft = await showModalBottomSheet<({int amountFils, DateTime date})>(
        context: context, isScrollControlled: true, builder: (_) => _RepaymentSheet(loan: loan));
    if (draft == null || !mounted) return;
    final l = context.l10n;
    try {
      await _repo.recordRepayment(loan.id,
          amountFils: draft.amountFils, date: draft.date, description: loanDescriber(l)(loan.repaymentType, loan.person));
    } catch (e) {
      if (mounted) _toast(l.addFailed('$e'));
    }
  }

  Future<void> _settle(Loan loan) async {
    final l = context.l10n;
    final left = formatMoney(loan.remainingFils);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.l10n.settleLoanTitle),
        content: Text(loan.lent ? c.l10n.settleLentBody(loan.person, left) : c.l10n.settleBorrowedBody(loan.person, left)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.l10n.settleLoan)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.recordRepayment(loan.id, date: _today(), description: loanDescriber(l)(loan.repaymentType, loan.person));
    } catch (e) {
      if (mounted) _toast(l.addFailed('$e'));
    }
  }

  Future<void> _edit(Loan loan) async {
    final draft = await showModalBottomSheet<_LoanDraft>(
        context: context, isScrollControlled: true, builder: (_) => _LoanFormSheet(existing: loan));
    if (draft == null || !mounted) return;
    final l = context.l10n;
    try {
      await _repo.updateLoan(loan.id,
          person: draft.person,
          amountFils: draft.amountFils,
          date: draft.date,
          dueDate: draft.dueDate,
          note: draft.note,
          describe: loanDescriber(l));
    } catch (e) {
      if (mounted) _toast(l.updateFailed('$e'));
    }
  }

  Future<void> _delete(Loan loan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.l10n.deleteLoanTitle),
        content: Text(c.l10n.deleteLoanBody(_entries.length)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(c.l10n.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deleteLoan(loan.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) _toast(context.l10n.deleteFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final loan = _loan;
    if (_loading || _error != null || loan == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l.loanTitle)),
        body: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error.toString(), onRetry: _load)
                : EmptyView(icon: Icons.handshake_outlined, title: l.noLoansYet),
      );
    }
    final pad = PlatformUi.hPadding(context);
    final repayments = _entries.where((t) => t.type == loan.repaymentType).toList();
    final overdue = loan.overdue(_today());
    final dates = [
      if (loan.date != null) DateFormat.yMMMd().format(loan.date!),
      if (loan.dueDate != null) l.dueOn(formatDate(loan.dueDate!)),
    ].join(' · ');
    return Scaffold(
      appBar: AppBar(title: Text(l.loanTitle), actions: [
        IconButton(icon: const Icon(Icons.edit_outlined), tooltip: l.edit, onPressed: () => _edit(loan)),
        IconButton(icon: const Icon(Icons.delete_outline), tooltip: l.delete, onPressed: () => _delete(loan)),
      ]),
      body: ListView(padding: EdgeInsets.fromLTRB(pad, 8, pad, 16), children: [
        Text(loan.lent ? l.youLentPerson(loan.person) : l.youBorrowedFrom(loan.person),
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 4),
        Text(formatMoney(loan.amountFils), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (dates.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(dates, style: theme.textTheme.bodySmall?.copyWith(color: overdue ? theme.colorScheme.error : null)),
        ],
        if (loan.note?.isNotEmpty ?? false) ...[const SizedBox(height: 8), Text(loan.note!)],
        const SizedBox(height: 16),
        _Progress(loan: loan),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(l.amountRepaid(formatMoney(loan.repaidFils)), style: theme.textTheme.bodySmall)),
          Text(loan.open ? l.amountLeft(formatMoney(loan.remainingFils)) : l.loansSettled,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: loan.open && loan.lent ? Colors.green : null)),
        ]),
        const SizedBox(height: 24),
        Text(l.repayments, style: theme.textTheme.titleMedium),
        if (repayments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(l.noRepaymentsYet, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          )
        else
          for (final t in repayments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(DateFormat.yMMMd().format(t.date)),
              trailing: Text(formatMoney(t.amountFils), style: theme.textTheme.bodyLarge),
            ),
      ]),
      // Record repayment is the main action; Settle sits under it, so it
      // isn't tapped by accident.
      bottomNavigationBar: !loan.open
          ? null
          : SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton(onPressed: () => _repay(loan), child: Text(l.recordRepayment)),
                  const SizedBox(height: 8),
                  OutlinedButton(onPressed: () => _settle(loan), child: Text(l.settleLoan)),
                ]),
              ),
            ),
    );
  }
}

/// A date field: shows [value] and opens a date picker when tapped.
class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onPicked, this.onCleared});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback? onCleared;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final today = _today();
    final v = value;
    String text() {
      final day = DateFormat.yMMMEd().format(v!);
      return switch (v.difference(today).inDays) { 0 => l.dateToday(day), -1 => l.dateYesterday(day), _ => day };
    }

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showDatePicker(
            context: context, initialDate: v ?? today, firstDate: DateTime(2000), lastDate: DateTime(today.year + 10, 12, 31));
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: v != null && onCleared != null
              ? IconButton(icon: const Icon(Icons.close, size: 18), tooltip: l.clearDueDate, onPressed: onCleared)
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(v == null ? '' : text()),
      ),
    );
  }
}

class _LoanDraft {
  final String direction;
  final String person;
  final int amountFils;
  final DateTime date;
  final DateTime? dueDate;
  final String? note;
  _LoanDraft(this.direction, this.person, this.amountFils, this.date, this.dueDate, this.note);
}

/// New loan, laid out like New transaction; with [existing], edits it (its
/// direction then stays as it is).
class _LoanFormSheet extends StatefulWidget {
  const _LoanFormSheet({this.existing, this.person});
  final Loan? existing;
  final String? person;

  @override
  State<_LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends State<_LoanFormSheet> {
  late String _direction = widget.existing?.direction ?? 'lent';
  late final _personCtrl = TextEditingController(text: widget.existing?.person ?? widget.person ?? '');
  late final _amountCtrl = TextEditingController(text: widget.existing == null ? '' : amountToInput(widget.existing!.amountFils));
  late final _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _date = widget.existing?.date ?? _today();
  late DateTime? _due = widget.existing?.dueDate;
  List<({String name, List<Loan> loans, int net})> _people = [];
  final _formKey = GlobalKey<FormState>();
  // Errors show only after a save attempt, then update as the user types.
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    FinanceRepo().loans().then((loans) {
      if (mounted) setState(() => _people = loansByPerson(loans));
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _personCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  // Names from earlier loans that contain what's typed, until it's an exact hit.
  List<({String name, List<Loan> loans, int net})> _suggestions() {
    final q = _personCtrl.text.trim().toLowerCase();
    if (q.isEmpty || _people.any((p) => p.name.toLowerCase() == q)) return const [];
    return _people.where((p) => p.name.toLowerCase().contains(q)).take(3).toList();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      return;
    }
    final note = _noteCtrl.text.trim();
    Navigator.pop(context,
        _LoanDraft(_direction, _personCtrl.text.trim(), parseAmount(_amountCtrl.text)!, _date, _due, note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final existing = widget.existing;
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
              Text(existing == null ? l.newLoan : l.editLoan, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'lent', label: Text(l.iLent)),
                  ButtonSegment(value: 'borrowed', label: Text(l.iBorrowed)),
                ],
                selected: {_direction},
                onSelectionChanged: existing == null ? (s) => setState(() => _direction = s.first) : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _personCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l.loanPerson),
                validator: (v) => (v ?? '').trim().isEmpty ? l.enterPerson : null,
              ),
              for (final p in _suggestions())
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline, size: 18),
                  title: Text(p.name),
                  trailing: p.net == 0
                      ? null
                      : Text('${p.net > 0 ? l.owesYou : l.youOwe} ${formatMoney(p.net.abs())}', style: Theme.of(context).textTheme.bodySmall),
                  onTap: () => setState(() => _personCtrl.text = p.name),
                ),
              const SizedBox(height: 12),
              AmountField(
                controller: _amountCtrl,
                label: l.amount,
                // An edit can't make the loan smaller than what's been paid back.
                check: (fils) => existing != null && fils < existing.repaidFils ? l.amountAtLeastRepaid(formatMoney(existing.repaidFils)) : null,
              ),
              const SizedBox(height: 12),
              _DateField(label: l.date, value: _date, onPicked: (d) => setState(() => _date = d)),
              const SizedBox(height: 12),
              _DateField(
                  label: l.dueDateOptional,
                  value: _due,
                  onPicked: (d) => setState(() => _due = d),
                  onCleared: () => setState(() => _due = null)),
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

/// Record repayment: the amount starts at what's left and can't go above it.
class _RepaymentSheet extends StatefulWidget {
  const _RepaymentSheet({required this.loan});
  final Loan loan;

  @override
  State<_RepaymentSheet> createState() => _RepaymentSheetState();
}

class _RepaymentSheetState extends State<_RepaymentSheet> {
  // Selected, so typing a partial amount replaces it.
  late final _amountCtrl = TextEditingController(text: amountToInput(widget.loan.remainingFils))
    ..selection = TextSelection(baseOffset: 0, extentOffset: amountToInput(widget.loan.remainingFils).length);
  DateTime _date = _today();
  final _formKey = GlobalKey<FormState>();
  var _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final loan = widget.loan;
    final left = formatMoney(loan.remainingFils);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidate,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.recordRepayment, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${loan.lent ? l.youLentPerson(loan.person) : l.youBorrowedFrom(loan.person)} · ${l.amountLeft(left)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 16),
              AmountField(
                controller: _amountCtrl,
                label: l.amount,
                autofocus: true,
                helperText: l.repayUpTo(left),
                check: (fils) => fils > loan.remainingFils ? l.amountAtMost(left) : null,
              ),
              const SizedBox(height: 12),
              _DateField(label: l.date, value: _date, onPicked: (d) => setState(() => _date = d)),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) {
                    setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
                    return;
                  }
                  Navigator.pop(context, (amountFils: parseAmount(_amountCtrl.text)!, date: _date));
                },
                child: Text(l.save),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
