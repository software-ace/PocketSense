import 'dart:math';

import '../main.dart' show initialSyncDone;
import '../models/models.dart';
import 'local_store.dart';

DateTime _dateOnly(dynamic raw) {
  final s = raw.toString().substring(0, 10);
  final p = s.split('-');
  return DateTime(int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 1, int.tryParse(p[2]) ?? 1);
}

// Ids are chosen on the device and sent with the insert. Previously the insert
// payload dropped the id, so Postgres assigned a different one and every later
// update/delete targeted a local id the server didn't have. Epoch-ms × 1000 +
// random keeps ids unique across devices and far above the table's own
// identity sequence, while staying below 2^53 for safe JSON round-trips.
final _rng = Random();
int _lastId = 0;
int newRowId() {
  final candidate = DateTime.now().millisecondsSinceEpoch * 1000 + _rng.nextInt(1000);
  _lastId = candidate > _lastId ? candidate : _lastId + 1;
  return _lastId;
}

String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

/// Offline-first data-access layer. Reads come from the local SQLite mirror;
/// writes apply locally AND queue to the outbox for push to Supabase. Screens
/// are unchanged — they talk to this same interface as before.
class FinanceRepo {
  /// Gates every read until the first sync round-trip completes (or times out),
  /// so screens never render an empty DB that is merely mid-seed.
  Future<LocalStore> get _db async {
    if (!initialSyncDone.isCompleted) {
      await initialSyncDone.future.timeout(const Duration(seconds: 15));
    }
    return LocalStore.instance();
  }

  // ── Categories ───────────────────────────────────────────────────────

  Future<List<Category>> categories() async {
    final store = await _db;
    final rows = await store.selectRows('categories');
    final list = (rows ?? [])
        .map(Category.fromMap)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<int> insertCategory({required String name, required String type, required String color, String icon = 'tag'}) async {
    final store = await _db;
    final id = newRowId();
    final row = {'id': id, 'name': name, 'type': type, 'color': color, 'icon': icon, 'updated_at': LocalStore.nowIso()};
    await store.insertRow('categories', row);
    await store.append(table: 'categories', op: 'insert', payload: row);
    return id;
  }

  Future<void> updateCategory(int id, {required String name, required String type, required String color, String icon = 'tag'}) async {
    final store = await _db;
    final values = {'name': name, 'type': type, 'color': color, 'icon': icon, 'updated_at': LocalStore.nowIso()};
    await store.updateRow('categories', id, values);
    await store.append(table: 'categories', op: 'update', payload: {'id': id, ...values});
  }

  Future<void> deleteCategory(int id) async {
    final store = await _db;
    await store.deleteRow('categories', id);
    await store.append(table: 'categories', op: 'delete', payload: {'id': id});
  }

  // ── Transactions ─────────────────────────────────────────────────────

  Future<List<Transaction>> transactions({
    String? type,
    DateTime? from,
    DateTime? to,
    int? categoryId,
    String? q,
    int limit = 200,
  }) async {
    final store = await _db;
    var where = <String>[];
    final args = <Object?>[];
    if (type != null) {
      where.add('type = ?');
      args.add(type);
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (from != null) {
      where.add('date >= ?');
      args.add(_isoDate(from));
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(_isoDate(to));
    }
    if (q != null && q.isNotEmpty) {
      where.add('(description LIKE ? OR merchant LIKE ?)');
      args.addAll(['%$q%', '%$q%']);
    }
    final w = where.isEmpty ? null : where.join(' AND ');
    final rows = await store.selectRows('transactions', where: w, whereArgs: args);
    final cats = await categories();
    final catById = {for (final c in cats) c.id: c};
    final txs = (rows ?? []).map((m) {
      final t = Transaction(
        id: m['id'] as int,
        amountCents: m['amount_cents'] as int,
        type: m['type'] as String? ?? 'expense',
        date: DateTime.parse(m['date'].toString()),
        description: m['description'] as String? ?? '',
        merchant: m['merchant'] as String?,
        categoryId: m['category_id'] as int?,
        source: m['source'] as String? ?? 'manual',
        notes: m['notes'] as String?,
        createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal(),
      );
      final c = t.categoryId == null ? null : catById[t.categoryId];
      return _withCat(t, c);
    }).toList()
      ..sort(_newestFirst);
    return txs.take(limit).toList();
  }

  Transaction _withCat(Transaction t, Category? c) => Transaction(
        id: t.id,
        amountCents: t.amountCents,
        type: t.type,
        date: t.date,
        description: t.description,
        merchant: t.merchant,
        categoryId: t.categoryId,
        source: t.source,
        notes: t.notes,
        categoryName: c?.name,
        categoryColor: c?.color,
        categoryIcon: c?.icon,
        createdAt: t.createdAt,
      );

  // Same-day entries fall back to entry time; rows without one sort last.
  static int _newestFirst(Transaction a, Transaction b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    final ca = a.createdAt, cb = b.createdAt;
    if (ca == null || cb == null) return (ca == null ? 1 : 0) - (cb == null ? 1 : 0);
    return cb.compareTo(ca);
  }

  Future<int> insertTransaction({
    required int amountCents,
    required String type,
    required DateTime date,
    required String description,
    String? merchant,
    int? categoryId,
    String? notes,
    String source = 'manual',
  }) async {
    final store = await _db;
    final id = newRowId();
    final row = <String, dynamic>{
      'id': id,
      'amount_cents': amountCents,
      'type': type,
      'date': _isoDate(date),
      'description': description,
      'source': source,
      'created_at': LocalStore.nowIso(),
      'updated_at': LocalStore.nowIso(),
    };
    if (merchant != null) row['merchant'] = merchant;
    if (categoryId != null) row['category_id'] = categoryId;
    if (notes != null) row['notes'] = notes;
    await store.insertRow('transactions', row);
    await store.append(table: 'transactions', op: 'insert', payload: row);
    return id;
  }

  Future<void> updateTransaction(
    int id, {
    required int amountCents,
    required String type,
    required DateTime date,
    required String description,
    String? merchant,
    int? categoryId,
  }) async {
    final store = await _db;
    final values = <String, dynamic>{
      'amount_cents': amountCents,
      'type': type,
      'date': _isoDate(date),
      'description': description,
      'updated_at': LocalStore.nowIso(),
    };
    if (merchant != null) values['merchant'] = merchant;
    if (categoryId != null) values['category_id'] = categoryId;
    await store.updateRow('transactions', id, values);
    await store.append(table: 'transactions', op: 'update', payload: {'id': id, ...values});
  }

  Future<void> deleteTransaction(int id) async {
    final store = await _db;
    await store.deleteRow('transactions', id);
    await store.append(table: 'transactions', op: 'delete', payload: {'id': id});
  }

  // ── Budgets ──────────────────────────────────────────────────────────

  Future<List<Budget>> budgets() async {
    final store = await _db;
    final rows = await store.selectRows('budgets');
    final cats = await categories();
    final catById = {for (final c in cats) c.id: c};
    return (rows ?? []).map((m) {
      final b = Budget(
        id: m['id'] as int,
        categoryId: m['category_id'] as int,
        limitCents: m['limit_cents'] as int,
        period: m['period'] as String? ?? 'monthly',
        active: (m['active'] as int? ?? 1) == 1,
      );
      final c = catById[b.categoryId];
      return Budget(
        id: b.id,
        categoryId: b.categoryId,
        limitCents: b.limitCents,
        period: b.period,
        active: b.active,
        categoryName: c?.name,
        categoryColor: c?.color,
      );
    }).toList();
  }

  Future<int> insertBudget({required int categoryId, required int limitCents, String period = 'monthly'}) async {
    final store = await _db;
    final id = newRowId();
    final row = {'id': id, 'category_id': categoryId, 'limit_cents': limitCents, 'period': period, 'active': 1, 'updated_at': LocalStore.nowIso()};
    await store.insertRow('budgets', row);
    await store.append(table: 'budgets', op: 'insert', payload: row);
    return id;
  }

  Future<void> updateBudget(int id, {required int categoryId, required int limitCents, required String period}) async {
    final store = await _db;
    final values = {'category_id': categoryId, 'limit_cents': limitCents, 'period': period, 'updated_at': LocalStore.nowIso()};
    await store.updateRow('budgets', id, values);
    await store.append(table: 'budgets', op: 'update', payload: {'id': id, ...values});
  }

  Future<void> deleteBudget(int id) async {
    final store = await _db;
    await store.deleteRow('budgets', id);
    await store.append(table: 'budgets', op: 'delete', payload: {'id': id});
  }

  // ── Recurring expenses ───────────────────────────────────────────────

  Future<List<RecurringExpense>> recurring() async {
    final store = await _db;
    final rows = await store.selectRows('recurring_expenses');
    final cats = await categories();
    final catById = {for (final c in cats) c.id: c};
    final list = (rows ?? []).map((m) => RecurringExpense(
          id: m['id'] as int,
          description: m['description'] as String? ?? '',
          amountCents: m['amount_cents'] as int,
          frequency: m['frequency'] as String? ?? 'monthly',
          anchorDate: _dateOnly(m['anchor_date']),
          categoryId: m['category_id'] as int?,
          active: (m['active'] as int? ?? 1) == 1,
          categoryName: m['category_id'] == null ? null : catById[m['category_id'] as int]?.name,
          merchant: m['merchant'] as String?,
          notes: m['notes'] as String?,
          lastPosted: m['last_posted'] != null ? _dateOnly(m['last_posted']) : null,
        )).toList()
      ..sort((a, b) {
        final byActive = b.active == a.active ? 0 : (b.active ? 1 : -1);
        return byActive != 0 ? byActive : a.description.compareTo(b.description);
      });
    return list;
  }

  Future<int> insertRecurring({required String description, required int amountCents, required String frequency, required DateTime anchorDate, int? categoryId, String? merchant, String? notes, bool active = true}) async {
    final store = await _db;
    final id = newRowId();
    final row = <String, dynamic>{
      'id': id,
      'description': description,
      'amount_cents': amountCents,
      'frequency': frequency,
      'anchor_date': _isoDate(anchorDate),
      'active': active ? 1 : 0,
      'updated_at': LocalStore.nowIso(),
    };
    if (categoryId != null) row['category_id'] = categoryId;
    if (merchant != null) row['merchant'] = merchant;
    if (notes != null) row['notes'] = notes;
    await store.insertRow('recurring_expenses', row);
    await store.append(table: 'recurring_expenses', op: 'insert', payload: row);
    return id;
  }

  Future<void> updateRecurring(int id, {required String description, required int amountCents, required String frequency, required DateTime anchorDate, int? categoryId, String? merchant, String? notes, bool? active}) async {
    final store = await _db;
    final values = <String, dynamic>{
      'description': description,
      'amount_cents': amountCents,
      'frequency': frequency,
      'anchor_date': _isoDate(anchorDate),
      'updated_at': LocalStore.nowIso(),
    };
    if (categoryId != null) values['category_id'] = categoryId;
    if (merchant != null) values['merchant'] = merchant;
    if (notes != null) values['notes'] = notes;
    if (active != null) values['active'] = active ? 1 : 0;
    await store.updateRow('recurring_expenses', id, values);
    await store.append(table: 'recurring_expenses', op: 'update', payload: {'id': id, ...values});
  }

  Future<void> deleteRecurring(int id) async {
    final store = await _db;
    await store.deleteRow('recurring_expenses', id);
    await store.append(table: 'recurring_expenses', op: 'delete', payload: {'id': id});
  }

  Future<void> toggleRecurring(int id, bool active) async {
    final store = await _db;
    final values = {'active': active ? 1 : 0, 'updated_at': LocalStore.nowIso()};
    await store.updateRow('recurring_expenses', id, values);
    await store.append(table: 'recurring_expenses', op: 'update', payload: {'id': id, ...values});
  }

  /// Record this recurring expense as a transaction dated today, then advance last_posted.
  Future<void> postRecurring(RecurringExpense r) async {
    final store = await _db;
    final today = DateTime.now();
    final txId = newRowId();
    final txRow = <String, dynamic>{
      'id': txId,
      'amount_cents': r.amountCents,
      'type': 'expense',
      'description': '${r.description} (recurring)',
      'date': _isoDate(today),
      'source': 'manual',
      'notes': 'Auto-posted from recurring expense #${r.id}',
      'created_at': LocalStore.nowIso(),
      'updated_at': LocalStore.nowIso(),
    };
    if (r.categoryId != null) txRow['category_id'] = r.categoryId;
    if (r.merchant != null && r.merchant!.isNotEmpty) txRow['merchant'] = r.merchant;
    await store.insertRow('transactions', txRow);
    await store.append(table: 'transactions', op: 'insert', payload: txRow);

    final recValues = {'last_posted': _isoDate(today), 'updated_at': LocalStore.nowIso()};
    await store.updateRow('recurring_expenses', r.id, recValues);
    await store.append(table: 'recurring_expenses', op: 'update', payload: {'id': r.id, ...recValues});
  }

  // ── Aggregates (computed over local rows) ────────────────────────────

  /// Aggregate income/expense cents within [from],[to].
  Future<({int income, int expense})> totals(DateTime from, DateTime to) async {
    final store = await _db;
    final lo = _isoDate(from);
    final hi = _isoDate(to);
    final exp = await store.selectRows('transactions',
        where: 'date >= ? AND date <= ? AND type = ?', whereArgs: [lo, hi, 'expense']);
    final inc = await store.selectRows('transactions',
        where: 'date >= ? AND date <= ? AND type = ?', whereArgs: [lo, hi, 'income']);
    int sum(List<Map<String, dynamic>>? l) =>
        (l ?? []).fold(0, (a, b) => a + (b['amount_cents'] as int));
    return (income: sum(inc), expense: sum(exp));
  }

  /// Expense cents grouped by category name within [from],[to].
  Future<List<({String label, int cents, String? color})>> spendingByCategory(
      DateTime from, DateTime to) async {
    final txs = await transactions(from: from, to: to, type: 'expense', limit: 1000);
    final map = <String, ({String label, int cents, String? color})>{};
    for (final t in txs) {
      final name = t.categoryName ?? 'Uncategorized';
      final existing = map[name];
      if (existing == null) {
        map[name] = (label: name, cents: t.amountCents, color: t.categoryColor);
      } else {
        map[name] = (label: name, cents: existing.cents + t.amountCents, color: t.categoryColor);
      }
    }
    return map.values.toList()..sort((a, b) => b.cents.compareTo(a.cents));
  }

  /// Daily expense cents for the last [days] days ending at [end].
  Future<List<({DateTime day, int cents})>> dailySpending(
      {required DateTime end, int days = 30}) async {
    final start = end.subtract(Duration(days: days - 1));
    final txs = await transactions(from: start, to: end, type: 'expense', limit: 2000);
    final byDay = <String, int>{};
    for (var i = 0; i < days; i++) {
      final d = start.add(Duration(days: i));
      byDay[_isoDate(d)] = 0;
    }
    for (final t in txs) {
      final key = _isoDate(t.date);
      byDay[key] = (byDay[key] ?? 0) + t.amountCents;
    }
    return byDay.entries.map((e) {
      final p = e.key.split('-');
      return (day: DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2])), cents: e.value);
    }).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
  }

  /// Monthly net (income − expense) for the last [months] months.
  Future<List<({String label, int net})>> monthlyNet({int months = 6}) async {
    final now = DateTime.now();
    final result = <({String label, int net})>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final nextM = m.isBefore(DateTime(now.year, now.month, 1))
          ? DateTime(m.year, m.month + 1, 1)
          : DateTime(m.year + 1, 1, 1);
      final t = await totals(m, nextM.subtract(const Duration(days: 1)));
      result.add((label: '${m.year}-${m.month.toString().padLeft(2, '0')}', net: t.income - t.expense));
    }
    return result;
  }

}
