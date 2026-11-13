// Row models for the on-device database. fromMap takes a row (snake_case
// keys), plus category_name / category_color where the repo joins them in.

class Category {
  final int id;
  final String name;
  final String type; // 'income' | 'expense'
  final String color;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as int,
        name: m['name'] as String? ?? '',
        type: m['type'] as String? ?? 'expense',
        color: m['color'] as String? ?? '#6366f1',
      );
}

class Merchant {
  final int id;
  final String name;

  Merchant({required this.id, required this.name});

  factory Merchant.fromMap(Map<String, dynamic> m) =>
      Merchant(id: m['id'] as int, name: m['name'] as String? ?? '');
}

class Transaction {
  final int id;
  final int amountFils;
  final String type; // 'income' | 'expense'
  final DateTime date;
  final String description;
  final String? merchant;
  final int? categoryId;
  final String? categoryName;
  final String? categoryColor;
  /// When the entry was recorded (local time). [date] is date-only, so this
  /// is the only source of a time of day. Null for legacy rows.
  final DateTime? createdAt;
  /// The loan this entry lends, borrows or repays, if any.
  final int? loanId;
  /// The savings circle this entry pays into or is the payout of, if any.
  final int? circleId;
  /// The account its money came from or went into.
  final int? accountId;

  Transaction({
    required this.id,
    required this.amountFils,
    required this.type,
    required this.date,
    required this.description,
    this.merchant,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    this.createdAt,
    this.loanId,
    this.circleId,
    this.accountId,
  });

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as int,
        amountFils: m['amount_fils'] as int,
        type: m['type'] as String? ?? 'expense',
        date: DateTime.parse(m['date'].toString()),
        description: m['description'] as String? ?? '',
        merchant: m['merchant'] as String?,
        categoryId: m['category_id'] as int?,
        categoryName: m['category_name'] as String?,
        categoryColor: m['category_color'] as String?,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal(),
        accountId: m['account_id'] as int?,
        loanId: m['loan_id'] as int?,
        circleId: m['circle_id'] as int?,
      );
}

class Budget {
  final int id;
  final int categoryId;
  final int limitFils;
  final String period;
  final String? categoryName;
  final String? categoryColor;

  Budget({
    required this.id,
    required this.categoryId,
    required this.limitFils,
    required this.period,
    this.categoryName,
    this.categoryColor,
  });

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as int,
        categoryId: m['category_id'] as int,
        limitFils: m['limit_fils'] as int,
        period: m['period'] as String? ?? 'monthly',
        categoryName: m['category_name'] as String?,
        categoryColor: m['category_color'] as String?,
      );
}

class RecurringExpense {
  final int id;
  final String description;
  final int amountFils;
  final String type; // 'income' | 'expense'
  final String frequency; // 'weekly'|'biweekly'|'monthly'|'quarterly'|'yearly'
  final DateTime anchorDate;
  final int? categoryId;
  final bool active;
  final String? categoryName;
  final String? merchant;
  final String? notes;
  /// When on its due date it's due, in minutes after midnight.
  final int dueMinutes;
  /// Remind this many days before (0: on the day); null: no reminder.
  final int? reminderDays;
  /// The account it's posted to.
  final int? accountId;

  RecurringExpense({
    required this.id,
    required this.description,
    required this.amountFils,
    this.type = 'expense',
    required this.frequency,
    required this.anchorDate,
    this.categoryId,
    required this.active,
    this.categoryName,
    this.merchant,
    this.notes,
    this.dueMinutes = defaultReminderMinutes,
    this.reminderDays,
    this.accountId,
  });
}

/// 9:00, when a reminder or a due time isn't set.
const defaultReminderMinutes = 9 * 60;

/// Money lent to or borrowed from someone. The amounts are sums over the
/// loan's transactions: for a loan you lent, its expenses are what you lent
/// and its incomes the repayments; a borrowed one is the reverse.
class Loan {
  final int id;
  final String direction; // 'lent' | 'borrowed'
  final String person;
  final DateTime? dueDate;
  final String? note;
  final int amountFils;
  final int repaidFils;
  /// The first lending or borrowing entry's date; null if it was deleted.
  final DateTime? date;
  /// As for [RecurringExpense.reminderDays]; only with a [dueDate].
  final int? reminderDays;
  /// As for [RecurringExpense.dueMinutes].
  final int dueMinutes;

  Loan({
    required this.id,
    required this.direction,
    required this.person,
    this.dueDate,
    this.note,
    required this.amountFils,
    required this.repaidFils,
    this.date,
    this.reminderDays,
    this.dueMinutes = defaultReminderMinutes,
  });

  bool get lent => direction == 'lent';
  /// The entry type of what was lent or borrowed; repayments are the other.
  String get principalType => lent ? 'expense' : 'income';
  String get repaymentType => lent ? 'income' : 'expense';
  /// Never below 0, even if entries were edited to repay more than lent.
  int get remainingFils => amountFils > repaidFils ? amountFils - repaidFils : 0;
  bool get open => remainingFils > 0;

  bool overdue(DateTime today) => open && dueDate != null && dueDate!.isBefore(DateTime(today.year, today.month, today.day));

  factory Loan.fromMap(Map<String, dynamic> m) => Loan(
        id: m['id'] as int,
        direction: m['direction'] as String? ?? 'lent',
        person: m['person'] as String? ?? '',
        dueDate: DateTime.tryParse(m['due_date']?.toString() ?? ''),
        note: m['note'] as String?,
        amountFils: m['amount_fils'] as int? ?? 0,
        repaidFils: m['repaid_fils'] as int? ?? 0,
        date: DateTime.tryParse(m['date']?.toString() ?? ''),
        reminderDays: m['reminder_days'] as int?,
        dueMinutes: m['due_time'] as int? ?? defaultReminderMinutes,
      );
}

/// What's still owed to you and by you, over [loans].
({int owedToYou, int youOwe}) loanTotals(Iterable<Loan> loans) => (
      owedToYou: loans.where((l) => l.lent).fold(0, (sum, l) => sum + l.remainingFils),
      youOwe: loans.where((l) => !l.lent).fold(0, (sum, l) => sum + l.remainingFils),
    );

/// A savings circle (ROSCA, جمعية): every member pays [contributionFils]
/// each round, and each round one member takes the whole pot. Yours is
/// round [payoutRound]. Payments are its expense entries, the payout its
/// income entries; everything else here is worked out from those.
class Circle {
  Circle({
    required this.id,
    required this.name,
    required this.contributionFils,
    required this.rounds,
    required this.frequency,
    required this.startDate,
    required this.payoutRound,
    this.note,
    this.reminderDays,
    this.dueMinutes = defaultReminderMinutes,
    this.paidFils = 0,
    this.receivedFils = 0,
  });

  final int id;
  final String name;
  final int contributionFils;
  /// How many rounds, one per member.
  final int rounds;
  final String frequency; // one of [frequencies]
  /// Round 1's due date.
  final DateTime startDate;
  final int payoutRound;
  final String? note;
  /// As for [RecurringExpense.reminderDays], before each unpaid round.
  final int? reminderDays;
  final int dueMinutes;
  final int paidFils;
  final int receivedFils;

  static const frequencies = ['weekly', 'biweekly', 'monthly'];
  static const maxRounds = 120;

  /// What each member pays in all, and what each takes on their turn.
  int get potFils => contributionFils * rounds;

  /// Round [round]'s due date. A month-end start stays at month end
  /// (Jan 31, Feb 28, Mar 31…) rather than spilling into the next month.
  DateTime dueDate(int round) {
    final k = round - 1, s = startDate;
    return switch (frequency) {
      'weekly' => DateTime(s.year, s.month, s.day + 7 * k),
      'biweekly' => DateTime(s.year, s.month, s.day + 14 * k),
      _ => DateTime(s.year, s.month + k, s.day.clamp(1, DateTime(s.year, s.month + k + 1, 0).day)),
    };
  }

  DateTime get payoutDate => dueDate(payoutRound);

  /// Rounds paid in full, oldest first; what's over goes to the next one.
  int get paidRounds => (paidFils ~/ contributionFils).clamp(0, rounds);
  int get partialFils => paidRounds < rounds ? paidFils % contributionFils : 0;
  int get leftToPayFils => potFils > paidFils ? potFils - paidFils : 0;

  /// The first round not paid in full; null when all are.
  int? get nextRound => paidRounds < rounds ? paidRounds + 1 : null;
  bool get received => receivedFils > 0;
  bool get done => leftToPayFils == 0 && received;

  /// Received less paid: above 0 you owe the circle (your turn came early,
  /// like a loan), below 0 it owes you (you've saved ahead of your turn).
  int get positionFils => receivedFils - paidFils;

  /// Contributions up to and including your turn, and after it.
  int get upToTurnFils => contributionFils * payoutRound;
  int get afterTurnFils => contributionFils * (rounds - payoutRound);

  bool overdue(DateTime today) {
    final r = nextRound;
    return r != null && dueDate(r).isBefore(DateTime(today.year, today.month, today.day));
  }

  // Rows can come from a peer or a backup: keep the math defined (no
  // division by 0, a turn inside the circle, a schedule of bounded length).
  factory Circle.fromMap(Map<String, dynamic> m) {
    final rounds = (m['rounds'] as int? ?? 1).clamp(1, maxRounds);
    return Circle(
      id: m['id'] as int,
      name: m['name'] as String? ?? '',
      contributionFils: (m['contribution_fils'] as int? ?? 1).clamp(1, 1 << 40),
      rounds: rounds,
      frequency: m['frequency'] as String? ?? 'monthly',
      startDate: DateTime.tryParse(m['start_date']?.toString() ?? '') ?? DateTime(2000),
      payoutRound: (m['payout_round'] as int? ?? 1).clamp(1, rounds),
      note: m['note'] as String?,
      reminderDays: m['reminder_days'] as int?,
      dueMinutes: m['due_time'] as int? ?? defaultReminderMinutes,
      paidFils: m['paid_fils'] as int? ?? 0,
      receivedFils: m['received_fils'] as int? ?? 0,
    );
  }
}

/// What circles owe you and what you owe them, over [circles].
({int owedToYou, int youOwe}) circleTotals(Iterable<Circle> circles) => (
      owedToYou: circles.fold(0, (sum, c) => sum + (c.positionFils < 0 ? -c.positionFils : 0)),
      youOwe: circles.fold(0, (sum, c) => sum + (c.positionFils > 0 ? c.positionFils : 0)),
    );

/// Somewhere money is kept: cash, a bank account, savings or a card.
class Account {
  Account({
    required this.id,
    required this.uid,
    required this.name,
    required this.kind,
    required this.openingFils,
    required this.closed,
    required this.balanceFils,
    required this.entries,
  });

  final int id;
  final String uid;
  final String name;

  /// One of [kinds]; an unknown one (from a newer app) shows as cash.
  final String kind;

  /// What was in it when it was added; not income.
  final int openingFils;

  /// Closed: kept with its history, hidden from Home, pickers and Transfer.
  final bool closed;

  /// Opening balance + income − spending + transfers in − transfers out.
  /// Negative for a card that's owed.
  final int balanceFils;

  /// How many entries are in it (transfers not counted).
  final int entries;

  static const kinds = ['cash', 'bank', 'savings', 'card'];
}

/// Money moved between two of your accounts: neither income nor spending.
class Transfer {
  Transfer({
    required this.id,
    required this.fromId,
    required this.toId,
    required this.amountFils,
    required this.date,
    this.note,
    this.createdAt,
  });

  final int id;
  final int? fromId;
  final int? toId;
  final int amountFils;
  final DateTime date;
  final String? note;
  final DateTime? createdAt;

  factory Transfer.fromMap(Map<String, dynamic> m) => Transfer(
        id: m['id'] as int,
        fromId: m['from_account_id'] as int?,
        toId: m['to_account_id'] as int?,
        amountFils: m['amount_fils'] as int,
        date: DateTime.parse(m['date'].toString()),
        note: m['note'] as String?,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal(),
      );
}
