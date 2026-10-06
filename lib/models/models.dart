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


