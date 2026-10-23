import '../models/models.dart';
import '../utils/budget_period.dart';
import 'local_store.dart';

// Date-only strings parse as local midnight; anything after the date is ignored.
DateTime _dateOnly(Object? raw) => DateTime.parse(raw.toString().substring(0, 10));

String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);

/// Data-access layer over the on-device [LocalStore]. Screens create one
/// wherever they need it; it holds no state of its own.
class FinanceRepo {
  Future<LocalStore> get _db => LocalStore.instance();

  // ── Categories ───────────────────────────────────────────────────────

  Future<List<Category>> categories() async {
    final store = await _db;
    final rows = await store.selectRows('categories');
    final list = rows
        .map(Category.fromMap)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<int> insertCategory({required String name, required String type, required String color}) async =>
      (await _db).insertRow('categories', {'name': name, 'type': type, 'color': color});

  Future<void> updateCategory(int id, {required String name, required String type, required String color}) async =>
      (await _db).updateRow('categories', id, {'name': name, 'type': type, 'color': color});

  Future<void> deleteCategory(int id) async {
    final store = await _db;
    await store.deleteRow('categories', id);
  }

  /// Renames starter categories to [names] (key → name in the UI language),
  /// but only those still called one of their [defaultNames] (key → every
  /// default name, lower-cased), so names the user chose are kept. A rename
  /// that would clash with another category's name is skipped. Returns how
  /// many were renamed.
  /// Skipped once paired: the categories are shared then, and two devices
  /// in different languages would keep renaming them back and forth.
  Future<int> localizeStarterCategories(Map<String, String> names, Map<String, Set<String>> defaultNames) async {
    final store = await _db;
    if ((await store.selectRows('peers')).isNotEmpty) return 0;
    final cats = await categories();
    final taken = {for (final c in cats) c.name.toLowerCase()};
    var renamed = 0;
    for (final c in cats) {
      final key = defaultNames.entries.where((e) => e.value.contains(c.name.toLowerCase())).firstOrNull?.key;
      final target = key == null ? null : names[key];
      if (target == null || target == c.name) continue;
      if (target.toLowerCase() != c.name.toLowerCase() && taken.contains(target.toLowerCase())) continue;
      await store.updateRow('categories', c.id, {'name': target});
      taken
        ..remove(c.name.toLowerCase())
        ..add(target.toLowerCase());
      renamed++;
    }
    return renamed;
  }

  // ── Merchants ────────────────────────────────────────────────────────

  Future<List<Merchant>> merchants() async {
    final store = await _db;
    final rows = await store.selectRows('merchants');
    final list = rows.map(Merchant.fromMap).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Adds [name] to the merchant list (trimmed). A merchant already in the
  /// list under a different spelling of the same name wins, so the caller
  /// always ends up with one row per name; the returned id is the one to
  /// treat as chosen.
  Future<int> insertMerchant(String name) async {
    final store = await _db;
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('empty merchant name');
    final existing = (await store.selectRows('merchants', where: 'name = ?', whereArgs: [clean])).firstOrNull;
    if (existing != null) return existing['id'] as int;
    return store.insertRow('merchants', {'name': clean});
  }

  /// Renames a merchant and, so the past stays consistent with the list,
  /// rewrites every transaction and recurring item that spelled the old
  /// name (any case, maybe padded with spaces) with the new one. Renaming
  /// to a name that only differs in case is a spelling fix: the entries'
  /// text is left alone.
  Future<void> renameMerchant(int id, String name) async {
    final store = await _db;
    final clean = name.trim();
    if (clean.isEmpty) throw ArgumentError('empty merchant name');
    final row = (await store.selectRows('merchants', where: 'id = ?', whereArgs: [id])).firstOrNull;
    if (row == null) throw StateError('No merchant $id');
    final old = row['name'] as String;
    if (old.toLowerCase() == clean.toLowerCase()) {
      if (old != clean) await store.updateRow('merchants', id, {'name': clean});
      return;
    }
    final clash = (await store.selectRows('merchants', where: 'name = ?', whereArgs: [clean])).firstOrNull;
    if (clash != null) throw StateError('A merchant called "$clean" already exists');
    await store.updateRow('merchants', id, {'name': clean});
    for (final t in const ['transactions', 'recurring_expenses']) {
      for (final r in await store.selectRows(t, where: 'merchant IS NOT NULL', whereArgs: const [])) {
        final m = r['merchant'] as String;
        if (m == clean || m.trim().toLowerCase() != old.toLowerCase()) continue;
        await store.updateRow(t, r['id'] as int, {'merchant': clean});
      }
    }
  }

  /// Removes a merchant from the list. Past transactions keep their text,
  /// so history and the charts stay as they are.
  Future<void> deleteMerchant(int id) async => (await _db).deleteRow('merchants', id);

  // ── Transactions ─────────────────────────────────────────────────────

  Future<List<Transaction>> transactions({
    String? type,
    DateTime? from,
    DateTime? to,
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
    final txs = rows.map((m) {
      final c = catById[m['category_id']];
      return Transaction.fromMap({...m, 'category_name': c?.name, 'category_color': c?.color});
    }).toList()
      ..sort(_newestFirst);
    return txs.take(limit).toList();
  }

  // Same-day entries fall back to entry time; rows without one sort last.
  static int _newestFirst(Transaction a, Transaction b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) return byDate;
    final ca = a.createdAt, cb = b.createdAt;
    if (ca == null || cb == null) return (ca == null ? 1 : 0) - (cb == null ? 1 : 0);
    return cb.compareTo(ca);
  }

  Future<int> insertTransaction({
    required int amountFils,
    required String type,
    required DateTime date,
    required String description,
    String? merchant,
    int? categoryId,
  }) async {
    final store = await _db;
    return store.insertRow('transactions', {
      'amount_fils': amountFils,
      'type': type,
      'date': _isoDate(date),
      'description': description,
      'merchant': merchant,
      'category_id': categoryId,
      'created_at': LocalStore.nowIso(),
    });
  }

  Future<void> updateTransaction(
    int id, {
    required int amountFils,
    required String type,
    required DateTime date,
    required String description,
    String? merchant,
    int? categoryId,
  }) async {
    final store = await _db;
    final values = <String, dynamic>{
      'amount_fils': amountFils,
      'type': type,
      'date': _isoDate(date),
      'description': description,
    };
    if (merchant != null) values['merchant'] = merchant;
    if (categoryId != null) values['category_id'] = categoryId;
    await store.updateRow('transactions', id, values);
  }

  Future<void> deleteTransaction(int id) async {
    final store = await _db;
    await store.deleteRow('transactions', id);
  }

  // ── Budgets ──────────────────────────────────────────────────────────

  Future<List<Budget>> budgets() async {
    final store = await _db;
    final rows = await store.selectRows('budgets');
    final cats = await categories();
    final catById = {for (final c in cats) c.id: c};
    return rows.map((m) {
      final c = catById[m['category_id']];
      return Budget.fromMap({...m, 'category_name': c?.name, 'category_color': c?.color});
    }).toList();
  }

  /// Budgets with what has been spent in their category during their
  /// own current period (this week for weekly, this month for monthly).
  Future<List<({Budget budget, int spentFils, DateTime start, DateTime end})>> budgetProgress({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final active = await budgets();
    if (active.isEmpty) return [];
    final windows = {for (final b in active) b.id: budgetPeriod(b.period, at)};
    // One query covering every window, then bucket per budget.
    final from = windows.values.map((w) => w.start).reduce((a, b) => a.isBefore(b) ? a : b);
    final to = windows.values.map((w) => w.end).reduce((a, b) => a.isAfter(b) ? a : b);
    final txs = await transactions(from: from, to: to, type: 'expense', limit: 1 << 30);
    return [
      for (final b in active)
        (
          budget: b,
          spentFils: txs
              .where((t) => t.categoryId == b.categoryId && !t.date.isBefore(windows[b.id]!.start) && !t.date.isAfter(windows[b.id]!.end))
              .fold(0, (sum, t) => sum + t.amountFils),
          start: windows[b.id]!.start,
          end: windows[b.id]!.end,
        ),
    ];
  }

  Future<int> insertBudget({required int categoryId, required int limitFils, String period = 'monthly'}) async =>
      (await _db).insertRow('budgets', {'category_id': categoryId, 'limit_fils': limitFils, 'period': period});

  Future<void> updateBudget(int id, {required int categoryId, required int limitFils, required String period}) async =>
      (await _db).updateRow('budgets', id, {'category_id': categoryId, 'limit_fils': limitFils, 'period': period});

  Future<void> deleteBudget(int id) async {
    final store = await _db;
    await store.deleteRow('budgets', id);
  }

  // ── Recurring expenses ───────────────────────────────────────────────

  Future<List<RecurringExpense>> recurring() async {
    final store = await _db;
    final rows = await store.selectRows('recurring_expenses');
    final cats = await categories();
    final catById = {for (final c in cats) c.id: c};
    final list = rows.map((m) => RecurringExpense(
          id: m['id'] as int,
          description: m['description'] as String? ?? '',
          amountFils: m['amount_fils'] as int,
          type: m['type'] as String? ?? 'expense',
          frequency: m['frequency'] as String? ?? 'monthly',
          anchorDate: _dateOnly(m['anchor_date']),
          categoryId: m['category_id'] as int?,
          active: (m['active'] as int? ?? 1) == 1,
          categoryName: m['category_id'] == null ? null : catById[m['category_id'] as int]?.name,
          merchant: m['merchant'] as String?,
          notes: m['notes'] as String?,
        )).toList()
      ..sort((a, b) {
        final byActive = b.active == a.active ? 0 : (b.active ? 1 : -1);
        return byActive != 0 ? byActive : a.description.compareTo(b.description);
      });
    return list;
  }

  Future<int> insertRecurring({required String description, required int amountFils, String type = 'expense', required String frequency, required DateTime anchorDate, int? categoryId, String? merchant, String? notes, bool active = true}) async {
    final store = await _db;
    return store.insertRow('recurring_expenses', {
      'description': description,
      'amount_fils': amountFils,
      'type': type,
      'frequency': frequency,
      'anchor_date': _isoDate(anchorDate),
      'active': active ? 1 : 0,
      'category_id': categoryId,
      'merchant': merchant,
      'notes': notes,
    });
  }

  Future<void> updateRecurring(int id, {required String description, required int amountFils, String type = 'expense', required String frequency, required DateTime anchorDate, int? categoryId, String? merchant, String? notes, bool? active}) async {
    final store = await _db;
    final values = <String, dynamic>{
      'description': description,
      'amount_fils': amountFils,
      'type': type,
      'frequency': frequency,
      'anchor_date': _isoDate(anchorDate),
    };
    if (categoryId != null) values['category_id'] = categoryId;
    if (merchant != null) values['merchant'] = merchant;
    if (notes != null) values['notes'] = notes;
    if (active != null) values['active'] = active ? 1 : 0;
    await store.updateRow('recurring_expenses', id, values);
  }

  Future<void> deleteRecurring(int id) async {
    final store = await _db;
    await store.deleteRow('recurring_expenses', id);
  }

  /// Record this recurring item as a transaction dated today. [description]
  /// comes from the UI, in its language.
  Future<void> postRecurring(RecurringExpense r, {required String description}) => insertTransaction(
        amountFils: r.amountFils,
        type: r.type,
        date: DateTime.now(),
        description: description,
        merchant: (r.merchant?.isEmpty ?? true) ? null : r.merchant,
        categoryId: r.categoryId,
      );

  // ── Aggregates (computed over local rows) ────────────────────────────

  /// Aggregate income/expense fils within [from],[to].
  Future<({int income, int expense})> totals(DateTime from, DateTime to) async {
    final store = await _db;
    final lo = _isoDate(from);
    final hi = _isoDate(to);
    final exp = await store.selectRows('transactions',
        where: 'date >= ? AND date <= ? AND type = ?', whereArgs: [lo, hi, 'expense']);
    final inc = await store.selectRows('transactions',
        where: 'date >= ? AND date <= ? AND type = ?', whereArgs: [lo, hi, 'income']);
    int sum(List<Map<String, dynamic>> l) => l.fold(0, (a, b) => a + (b['amount_fils'] as int));
    return (income: sum(inc), expense: sum(exp));
  }

  /// Expense fils grouped by category within [from],[to]. Uncategorized
  /// spending has a null label; the screen names it in the UI language.
  Future<List<({String? label, int fils, String? color})>> spendingByCategory(
      DateTime from, DateTime to) async {
    final txs = await transactions(from: from, to: to, type: 'expense', limit: 1000);
    final map = <int?, ({String? label, int fils, String? color})>{};
    for (final t in txs) {
      final existing = map[t.categoryId];
      map[t.categoryId] = (label: t.categoryName, fils: (existing?.fils ?? 0) + t.amountFils, color: t.categoryColor);
    }
    return map.values.toList()..sort((a, b) => b.fils.compareTo(a.fils));
  }

  /// Expense fils per merchant, largest first. Names match ignoring case and
  /// surrounding spaces, and show as last typed; [label] is null for
  /// expenses without a merchant.
  Future<List<({String? label, int fils})>> spendingByMerchant(DateTime from, DateTime to) async {
    final txs = await transactions(from: from, to: to, type: 'expense', limit: 1000);
    final map = <String, ({String? label, int fils})>{};
    for (final t in txs) {
      final name = t.merchant?.trim() ?? '';
      final existing = map[name.toLowerCase()];
      map[name.toLowerCase()] = (label: existing?.label ?? (name.isEmpty ? null : name), fils: (existing?.fils ?? 0) + t.amountFils);
    }
    return map.values.toList()..sort((a, b) => b.fils.compareTo(a.fils));
  }

  /// Income and expense fils per calendar month, oldest first: the [months]
  /// months up to and including [now]'s.
  Future<List<({DateTime month, int income, int expense})>> monthlyTotals(DateTime now, {int months = 6}) async {
    final first = DateTime(now.year, now.month - months + 1);
    final txs = await transactions(from: first, to: now, limit: 1 << 30);
    final income = List.filled(months, 0), expense = List.filled(months, 0);
    for (final t in txs) {
      final i = (t.date.year - first.year) * 12 + t.date.month - first.month;
      if (t.type == 'income') {
        income[i] += t.amountFils;
      } else {
        expense[i] += t.amountFils;
      }
    }
    return [for (var i = 0; i < months; i++) (month: DateTime(first.year, first.month + i), income: income[i], expense: expense[i])];
  }

  /// Expense fils spent so far by each day of the month, for comparing the
  /// pace of spending: this month up to [now]'s day, and all of last month.
  Future<({List<int> thisMonth, List<int> lastMonth})> monthPace(DateTime now) async {
    final txs = await transactions(from: DateTime(now.year, now.month - 1), to: now, type: 'expense', limit: 1 << 30);
    final thisDaily = List.filled(now.day, 0);
    final lastDaily = List.filled(DateTime(now.year, now.month, 0).day, 0);
    for (final t in txs) {
      (t.date.month == now.month ? thisDaily : lastDaily)[t.date.day - 1] += t.amountFils;
    }
    List<int> running(List<int> daily) {
      var sum = 0;
      return [for (final f in daily) sum += f];
    }

    return (thisMonth: running(thisDaily), lastMonth: running(lastDaily));
  }

  /// Average expense fils per weekday, Monday first, over the [weeks] weeks
  /// ending with [now]'s day, so every weekday counts exactly [weeks] times.
  Future<List<int>> weekdayAverages(DateTime now, {int weeks = 12}) async {
    final from = DateTime(now.year, now.month, now.day - weeks * 7 + 1);
    final txs = await transactions(from: from, to: now, type: 'expense', limit: 1 << 30);
    final totals = List.filled(7, 0);
    for (final t in txs) {
      totals[t.date.weekday - 1] += t.amountFils;
    }
    return [for (final f in totals) (f / weeks).round()];
  }

  /// Daily expense fils for the last [days] days ending at [end].
  Future<List<({DateTime day, int fils})>> dailySpending(
      {required DateTime end, int days = 30}) async {
    final start = end.subtract(Duration(days: days - 1));
    final txs = await transactions(from: start, to: end, type: 'expense', limit: 2000);
    // Calendar days, so a DST change can't skip or repeat one.
    final byDay = {for (var i = 0; i < days; i++) DateTime(start.year, start.month, start.day + i): 0};
    for (final t in txs) {
      byDay.update(t.date, (f) => f + t.amountFils, ifAbsent: () => t.amountFils);
    }
    return [for (final e in byDay.entries) (day: e.key, fils: e.value)];
  }
}
