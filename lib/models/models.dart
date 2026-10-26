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
        loanId: m['loan_id'] as int?,
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
  });
}

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

  Loan({
    required this.id,
    required this.direction,
    required this.person,
    this.dueDate,
    this.note,
    required this.amountFils,
    required this.repaidFils,
    this.date,
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
      );
}

/// What's still owed to you and by you, over [loans].
({int owedToYou, int youOwe}) loanTotals(Iterable<Loan> loans) => (
      owedToYou: loans.where((l) => l.lent).fold(0, (sum, l) => sum + l.remainingFils),
      youOwe: loans.where((l) => !l.lent).fold(0, (sum, l) => sum + l.remainingFils),
    );
