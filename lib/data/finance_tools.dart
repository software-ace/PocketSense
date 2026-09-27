import 'dart:convert';

import 'package:llamadart/llamadart.dart';

import '../models/models.dart';
import 'repo.dart';

/// Deterministic tool layer exposing [FinanceRepo] queries to the on-device
/// LLM as llamadart [ToolDefinition]s. All handlers are read-only or guarded
/// inserts — the model can look up and add records, but never bulk-delete.
class FinanceTools {
  final FinanceRepo _repo = FinanceRepo();

  static const systemPrompt = '''
You are Pocket Sense, a personal finance assistant running fully offline on the user's phone.
Answer questions about the user's own money using the tools available to you.

Rules:
- Amounts from tools are integer cents. Convert to dollars with two decimals when speaking (e.g. 4520 -> \$45.20).
- Dates come back as YYYY-MM-DD.
- Always call a tool before stating any number about the user's data. Never guess or invent figures.
- Be concise and conversational. Plain text only, no markdown tables.
- If a question is outside their finances, say so briefly and steer back.
''';

  List<ToolDefinition> get all => [
        listCategories,
        recentTransactions,
        searchTransactions,
        monthlySummary,
        spendingByCategory,
        budgetsStatus,
        recurringList,
        addTransaction,
      ];

  // ── Read tools ───────────────────────────────────────────────────────

  ToolDefinition get listCategories => ToolDefinition(
        name: 'list_categories',
        description:
            'Lists all expense/income categories with id, name, type, color and icon.',
        parameters: [],
        handler: (p) async {
          final cats = await _repo.categories();
          return jsonEncode(cats.map((c) => {
                'id': c.id,
                'name': c.name,
                'type': c.type,
                'color': c.color,
                'icon': c.icon,
              }).toList());
        },
      );

  ToolDefinition get recentTransactions => ToolDefinition(
        name: 'recent_transactions',
        description:
            "Returns recent transactions, newest first. Optionally filter by type (\"income\"/\"expense\"), category_id, or date range.",
        parameters: [
          ToolParam.string('type', description: "Filter: 'income' or 'expense'. Omit for both."),
          ToolParam.integer('category_id', description: 'Only transactions in this category.'),
          ToolParam.string('from', description: 'Start date inclusive, YYYY-MM-DD.'),
          ToolParam.string('to', description: 'End date inclusive, YYYY-MM-DD.'),
          ToolParam.integer('limit', description: 'Max results, default 20.'),
        ],
        handler: (p) async {
          DateTime? from, to;
          if (p.getString('from') != null) {
            from = _parseDate(p.getRequiredString('from'));
          }
          if (p.getString('to') != null) {
            to = _parseDate(p.getRequiredString('to'));
          }
          final txs = await _repo.transactions(
            type: p.getString('type'),
            categoryId: p.getInt('category_id'),
            from: from,
            to: to,
            limit: p.getInt('limit') ?? 20,
          );
          return jsonEncode(txs.map(_txJson).take(30).toList());
        },
      );

  ToolDefinition get searchTransactions => ToolDefinition(
        name: 'search_transactions',
        description:
            'Full-text search across transaction descriptions and merchants (e.g. "coffee", "uber").',
        parameters: [
          ToolParam.string('query', description: 'Search term to match against description or merchant.'),
          ToolParam.integer('limit', description: 'Max results, default 20.'),
        ],
        handler: (p) async {
          final q = p.getRequiredString('query');
          final txs = await _repo.transactions(q: q, limit: p.getInt('limit') ?? 20);
          return jsonEncode(txs.map(_txJson).take(30).toList());
        },
      );

  ToolDefinition get monthlySummary => ToolDefinition(
        name: 'monthly_summary',
        description:
            'Total income and expense (cents) for a month, plus net. Pass year and month (1-12). Defaults to current month.',
        parameters: [
          ToolParam.integer('year', description: 'Four-digit year, e.g. 2026.'),
          ToolParam.integer('month', description: 'Month 1-12.'),
        ],
        handler: (p) async {
          final now = DateTime.now();
          final y = p.getInt('year') ?? now.year;
          final m = p.getInt('month') ?? now.month;
          final start = DateTime(y, m, 1);
          final end = m == 12 ? DateTime(y + 1, 1, 1) : DateTime(y, m + 1, 1);
          final t = await _repo.totals(start, end.subtract(const Duration(days: 1)));
          return jsonEncode({
            'month': '$y-${m.toString().padLeft(2, '0')}',
            'income_cents': t.income,
            'expense_cents': t.expense,
            'net_cents': t.income - t.expense,
          });
        },
      );

  ToolDefinition get spendingByCategory => ToolDefinition(
        name: 'spending_by_category',
        description:
            'Expense totals per category for a date range, sorted descending. Defaults to the last 30 days.',
        parameters: [
          ToolParam.string('from', description: 'Start date inclusive, YYYY-MM-DD.'),
          ToolParam.string('to', description: 'End date inclusive, YYYY-MM-DD.'),
        ],
        handler: (p) async {
          final now = DateTime.now();
          final to = p.getString('to') != null
              ? _parseDate(p.getRequiredString('to'))
              : now;
          final from = p.getString('from') != null
              ? _parseDate(p.getRequiredString('from'))
              : to.subtract(const Duration(days: 29));
          final rows = await _repo.spendingByCategory(from, to);
          return jsonEncode(rows.map((r) => {
                'category': r.label,
                'spent_cents': r.cents,
              }).toList());
        },
      );

  ToolDefinition get budgetsStatus => ToolDefinition(
        name: 'budget_status',
        description:
            'All active budgets with their limit, and how much has been spent in each category this calendar month.',
        parameters: [],
        handler: (p) async {
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          final budgets = await _repo.budgets();
          final spend = await _repo.spendingByCategory(
              monthStart, now.subtract(const Duration(milliseconds: 1)));
          final spendByName = {for (final s in spend) s.label: s.cents};
          return jsonEncode(budgets.where((b) => b.active).map((b) {
                final catName = b.categoryName ?? '?';
                final used = spendByName[catName] ?? 0;
                return {
                  'category': catName,
                  'limit_cents': b.limitCents,
                  'spent_cents_this_month': used,
                  'remaining_cents': b.limitCents - used,
                  'over_budget': used > b.limitCents,
                };
              }).toList());
        },
      );

  ToolDefinition get recurringList => ToolDefinition(
        name: 'recurring_expenses',
        description:
            'Lists all recurring items — expenses (subscriptions, rent, bills) and income (salary, etc.) — with type, amount, frequency and next anchor date.',
        parameters: [],
        handler: (p) async {
          final items = await _repo.recurring();
          return jsonEncode(items.map((r) => {
                'description': r.description,
                'type': r.type,
                'amount_cents': r.amountCents,
                'frequency': r.frequency,
                'category': r.categoryName,
                'active': r.active,
              }).toList());
        },
      );

  // ── Write tool (guarded insert) ──────────────────────────────────────

  ToolDefinition get addTransaction => ToolDefinition(
        name: 'add_transaction',
        description:
            'Adds a single new transaction. Use when the user explicitly asks to log/add/record an expense or income. Confirm the amount and description come straight from the user\'s request.',
        parameters: [
          ToolParam.string('type', description: "'expense' or 'income'."),
          ToolParam.number('amount', description: 'Amount in whole currency units, e.g. 12.50 for twelve dollars fifty.'),
          ToolParam.string('description', description: 'Short human-readable description.'),
          ToolParam.string('date', description: 'YYYY-MM-DD. Default today.'),
          ToolParam.string('merchant', description: 'Merchant name if known.'),
          ToolParam.integer('category_id', description: 'Existing category id (call list_categories first).'),
        ],
        handler: (p) async {
          final type = p.getRequiredString('type').toLowerCase() == 'income'
              ? 'income'
              : 'expense';
          final amount = p.getDouble('amount') ?? 0;
          final cents = (amount * 100).round();
          if (cents <= 0) {
            return jsonEncode({'error': 'amount must be positive'});
          }
          final desc = p.getRequiredString('description');
          DateTime date = DateTime.now();
          if (p.getString('date') != null) {
            date = _parseDate(p.getRequiredString('date'));
          }
          final id = await _repo.insertTransaction(
            amountCents: cents,
            type: type,
            date: date,
            description: desc,
            merchant: p.getString('merchant'),
            categoryId: p.getInt('category_id'),
          );
          return jsonEncode({'ok': true, 'id': id});
        },
      );

  // ── Helpers ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _txJson(Transaction t) => {
        'id': t.id,
        'type': t.type,
        'amount_cents': t.amountCents,
        'date': '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}',
        'description': t.description,
        'merchant': t.merchant,
        'category': t.categoryName,
      };

  static DateTime _parseDate(String s) {
    final parts = s.split('-');
    if (parts.length == 3) {
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }
    return DateTime.now();
  }
}
