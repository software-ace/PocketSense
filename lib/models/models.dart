// Lightweight row models mirroring the Postgres schema. Each has a
// constructor that maps a raw PostgREST map (snake_case keys) into fields.

class Category {
  final int id;
  final String name;
  final String type; // 'income' | 'expense'
  final String color;
  final String icon;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
        id: m['id'] as int,
        name: m['name'] as String? ?? '',
        type: m['type'] as String? ?? 'expense',
        color: m['color'] as String? ?? '#6366f1',
        icon: m['icon'] as String? ?? 'tag',
      );
}

class Transaction {
  final int id;
  final int amountCents;
  final String type; // 'income' | 'expense'
  final DateTime date;
  final String description;
  final String? merchant;
  final int? categoryId;
  final String source;
  final String? notes;
  final String? categoryName;
  final String? categoryColor;
  final String? categoryIcon;
  /// When the entry was recorded (local time). [date] is date-only, so this
  /// is the only source of a time of day. Null for legacy rows.
  final DateTime? createdAt;

  Transaction({
    required this.id,
    required this.amountCents,
    required this.type,
    required this.date,
    required this.description,
    this.merchant,
    this.categoryId,
    required this.source,
    this.notes,
    this.categoryName,
    this.categoryColor,
    this.categoryIcon,
    this.createdAt,
  });

  factory Transaction.fromMap(Map<String, dynamic> m) => Transaction(
        id: m['id'] as int,
        amountCents: m['amount_cents'] as int,
        type: m['type'] as String? ?? 'expense',
        date: DateTime.parse(m['date'].toString()),
        description: m['description'] as String? ?? '',
        merchant: m['merchant'] as String?,
        categoryId: m['category_id'] as int?,
        source: m['source'] as String? ?? 'manual',
        notes: m['notes'] as String?,
        categoryName: m['category_name'] as String?,
        categoryColor: m['category_color'] as String?,
        categoryIcon: m['category_icon'] as String?,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal(),
      );
}

class Budget {
  final int id;
  final int categoryId;
  final int limitCents;
  final String period;
  final bool active;
  final String? categoryName;
  final String? categoryColor;

  Budget({
    required this.id,
    required this.categoryId,
    required this.limitCents,
    required this.period,
    required this.active,
    this.categoryName,
    this.categoryColor,
  });

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as int,
        categoryId: m['category_id'] as int,
        limitCents: m['limit_cents'] as int,
        period: m['period'] as String? ?? 'monthly',
        active: m['active'] is bool ? m['active'] as bool : (m['active'] as int? ?? 1) == 1,
        categoryName: m['category_name'] as String?,
        categoryColor: m['category_color'] as String?,
      );
}

class RecurringExpense {
  final int id;
  final String description;
  final int amountCents;
  final String frequency; // 'weekly'|'biweekly'|'monthly'|'quarterly'|'yearly'
  final DateTime anchorDate;
  final int? categoryId;
  final bool active;
  final String? categoryName;
  final String? merchant;
  final String? notes;
  final DateTime? lastPosted;

  RecurringExpense({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.frequency,
    required this.anchorDate,
    this.categoryId,
    required this.active,
    this.categoryName,
    this.merchant,
    this.notes,
    this.lastPosted,
  });
}


