import '../models/models.dart';
import '../utils/budget_period.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';
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
    // The starter Cash account too, while it still has a starter name.
    final cash = names[LocalStore.cashNameKey];
    final row = (await store.selectRows('accounts', where: 'uid = ?', whereArgs: [LocalStore.cashUid])).firstOrNull;
    final starters = {for (final l in AppLocalizations.supportedLocales) lookupAppLocalizations(l).cashAccount.toLowerCase()};
    if (cash != null && row != null && row['name'] != cash && starters.contains((row['name'] as String).toLowerCase())) {
      await store.updateRow('accounts', row['id'] as int, {'name': cash});
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
    int? loanId,
    int? circleId,
    int? accountId,
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
    if (loanId != null) {
      where.add('loan_id = ?');
      args.add(loanId);
    }
    if (circleId != null) {
      where.add('circle_id = ?');
      args.add(circleId);
    }
    if (accountId != null) {
      where.add('account_id = ?');
      args.add(accountId);
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
    int? accountId,
  }) async {
    final store = await _db;
    return store.insertRow('transactions', {
      'amount_fils': amountFils,
      'type': type,
      'date': _isoDate(date),
      'description': description,
      'merchant': merchant,
      'category_id': categoryId,
      'account_id': accountId ?? await defaultAccountId(),
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
    int? accountId,
  }) async {
    final store = await _db;
    final values = <String, dynamic>{
      'amount_fils': amountFils,
      'type': type,
      'date': _isoDate(date),
      'description': description,
      // Written even when null: that's how the form clears them.
      'merchant': merchant,
      'category_id': categoryId,
      'account_id': ?accountId,
    };
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
          dueMinutes: m['due_time'] as int? ?? defaultReminderMinutes,
          reminderDays: m['reminder_days'] as int?,
          accountId: m['account_id'] as int?,
        )).toList()
      ..sort((a, b) {
        final byActive = b.active == a.active ? 0 : (b.active ? 1 : -1);
        return byActive != 0 ? byActive : a.description.compareTo(b.description);
      });
    return list;
  }

  Future<int> insertRecurring({required String description, required int amountFils, String type = 'expense', required String frequency, required DateTime anchorDate, int? categoryId, String? merchant, String? notes, bool active = true, int dueMinutes = defaultReminderMinutes, int? reminderDays, int? accountId}) async {
    final store = await _db;
    final account = accountId ?? await defaultAccountId();
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
      'due_time': dueMinutes,
      'reminder_days': reminderDays,
      'account_id': account,
    });
  }

  Future<void> updateRecurring(int id, {required String description, required int amountFils, String type = 'expense', required String frequency, required DateTime anchorDate, int? categoryId, String? merchant, String? notes, bool? active, int dueMinutes = defaultReminderMinutes, int? reminderDays, int? accountId}) async {
    final store = await _db;
    final values = <String, dynamic>{
      'description': description,
      'amount_fils': amountFils,
      'type': type,
      'frequency': frequency,
      'anchor_date': _isoDate(anchorDate),
      // Written even when null: that's how the form clears them.
      'category_id': categoryId,
      'merchant': merchant,
      'notes': notes,
      'due_time': dueMinutes,
      'reminder_days': reminderDays,
      'account_id': ?accountId,
    };
    if (active != null) values['active'] = active ? 1 : 0;
    await store.updateRow('recurring_expenses', id, values);
  }

  Future<void> deleteRecurring(int id) async {
    final store = await _db;
    await store.deleteRow('recurring_expenses', id);
  }

  /// Record this recurring item as a transaction dated today. [description]
  /// comes from the UI, in its language.
  Future<void> postRecurring(RecurringExpense r, {required String description}) async {
    // Its own account, unless that was closed or deleted since.
    final open = {for (final a in await accounts()) if (!a.closed) a.id};
    await insertTransaction(
      amountFils: r.amountFils,
      type: r.type,
      date: DateTime.now(),
      description: description,
      merchant: (r.merchant?.isEmpty ?? true) ? null : r.merchant,
      categoryId: r.categoryId,
      accountId: open.contains(r.accountId) ? r.accountId : null,
    );
  }

  // ── Accounts and transfers ───────────────────────────────────────────

  /// Every account with its balance: open ones first, then in the order added.
  Future<List<Account>> accounts() async {
    final store = await _db;
    final rows = await store.db.rawQuery('''
      SELECT a.id, a.uid, a.name, a.kind, a.opening_fils, a.closed,
        a.opening_fils
          + coalesce((SELECT sum(CASE t.type WHEN 'income' THEN t.amount_fils ELSE -t.amount_fils END)
                      FROM transactions t WHERE t.account_id = a.id), 0)
          + coalesce((SELECT sum(amount_fils) FROM transfers WHERE to_account_id = a.id), 0)
          - coalesce((SELECT sum(amount_fils) FROM transfers WHERE from_account_id = a.id), 0) AS balance,
        (SELECT count(*) FROM transactions t WHERE t.account_id = a.id) AS entries
      FROM accounts a
      ORDER BY a.closed, a.id
    ''');
    return [
      for (final m in rows)
        Account(
          id: m['id'] as int,
          uid: m['uid'] as String? ?? '',
          name: m['name'] as String? ?? '',
          kind: Account.kinds.contains(m['kind']) ? m['kind'] as String : 'cash',
          openingFils: m['opening_fils'] as int? ?? 0,
          closed: (m['closed'] as int? ?? 0) == 1,
          balanceFils: m['balance'] as int? ?? 0,
          entries: m['entries'] as int? ?? 0,
        ),
    ];
  }

  /// Where new entries go: the account chosen on this device while it's
  /// open, else Cash, else the first open one.
  Future<int> defaultAccountId() async {
    final store = await _db;
    final open = await store.db.query('accounts', columns: ['id', 'uid'], where: 'closed = 0', orderBy: 'id');
    final chosen = AppSettings.defaultAccount.value;
    for (final uid in [?chosen, LocalStore.cashUid]) {
      final hit = open.where((r) => r['uid'] == uid).firstOrNull;
      if (hit != null) return hit['id'] as int;
    }
    if (open.isNotEmpty) return open.first['id'] as int;
    // None open (a peer closed the last one): any account, else a new Cash.
    final any = (await store.db.query('accounts', columns: ['id'], orderBy: 'id', limit: 1)).firstOrNull;
    return any?['id'] as int? ?? await insertAccount(name: 'Cash', kind: 'cash');
  }

  Future<int> insertAccount({required String name, required String kind, int openingFils = 0}) async =>
      (await _db).insertRow('accounts', {'name': name.trim(), 'kind': kind, 'opening_fils': openingFils});

  Future<void> updateAccount(int id, {required String name, required String kind, required int openingFils}) async =>
      (await _db).updateRow('accounts', id, {'name': name.trim(), 'kind': kind, 'opening_fils': openingFils});

  Future<void> setDefaultAccount(int id) async {
    final uid = (await (await _db).selectRows('accounts', where: 'id = ?', whereArgs: [id])).first['uid'] as String;
    await AppSettings.setDefaultAccount(uid);
  }

  Future<void> reopenAccount(int id) async => (await _db).updateRow('accounts', id, {'closed': 0});

  /// Closes an account: kept with its history, hidden from Home, pickers and
  /// Transfer. Money left in it moves to [intoId] first, as a transfer (a
  /// negative balance, a card's debt, is paid from [intoId] instead), and so
  /// do its recurring items, so nothing posts into a hidden account. [intoId]
  /// also becomes the default if this one was. The last open account can't
  /// be closed.
  Future<void> closeAccount(int id, {int? intoId}) async {
    final store = await _db;
    final all = await accounts();
    final account = all.firstWhere((a) => a.id == id);
    final open = all.where((a) => !a.closed).toList();
    if (account.closed) return;
    if (open.length <= 1) throw StateError('The last open account can\'t be closed');
    final recurring = await store.selectRows('recurring_expenses', where: 'account_id = ?', whereArgs: [id]);
    final needsTarget = account.balanceFils != 0 || recurring.isNotEmpty;
    if (needsTarget && !open.any((a) => a.id == intoId && a.id != id)) {
      throw ArgumentError('An open account to move the balance and recurring items into is needed');
    }
    final wasDefault = await defaultAccountId() == id;
    await store.write((txn) async {
      if (account.balanceFils != 0) {
        final out = account.balanceFils > 0;
        await store.insertIn(txn, 'transfers', {
          'from_account_id': out ? id : intoId,
          'to_account_id': out ? intoId : id,
          'amount_fils': account.balanceFils.abs(),
          'date': _isoDate(DateTime.now()),
          'created_at': LocalStore.nowIso(),
        });
      }
      for (final r in recurring) {
        await store.updateIn(txn, 'recurring_expenses', r['id'] as int, {'account_id': intoId});
      }
      await store.updateIn(txn, 'accounts', id, {'closed': 1});
    });
    if (wasDefault && intoId != null) await setDefaultAccount(intoId);
  }

  /// Deletes an account. Nothing in it is lost: its entries, recurring
  /// items, transfers and opening balance move to [intoId] (transfers
  /// between the two would then go from an account to itself, so those
  /// go). [intoId] also becomes the default if this one was. The last open
  /// account can't be deleted.
  Future<void> deleteAccount(int id, {required int intoId}) async {
    final store = await _db;
    final all = await accounts();
    final account = all.firstWhere((a) => a.id == id);
    if (intoId == id || !all.any((a) => a.id == intoId)) throw ArgumentError('Pick another account');
    if (!account.closed && all.where((a) => !a.closed).length <= 1) throw StateError('The last open account can\'t be deleted');
    final wasDefault = await defaultAccountId() == id;
    await store.write((txn) async {
      await store.moveAccountIn(txn, id, intoId);
      await store.deleteIn(txn, 'accounts', id);
    });
    if (wasDefault) await setDefaultAccount(intoId);
  }

  /// Transfers, newest first; [accountId]: only those in or out of it.
  Future<List<Transfer>> transfers({int? accountId}) async {
    final rows = await (await _db).selectRows('transfers',
        where: accountId == null ? null : 'from_account_id = ? OR to_account_id = ?', whereArgs: accountId == null ? null : [accountId, accountId]);
    return rows.map(Transfer.fromMap).toList()
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0));
      });
  }

  static void _checkTransfer(int fromId, int toId, int amountFils) {
    if (fromId == toId) throw ArgumentError('A transfer needs two different accounts');
    if (amountFils <= 0) throw ArgumentError('A transfer must be more than 0');
  }

  Future<int> insertTransfer({required int fromId, required int toId, required int amountFils, required DateTime date, String? note}) async {
    _checkTransfer(fromId, toId, amountFils);
    return (await _db).insertRow('transfers', {
      'from_account_id': fromId,
      'to_account_id': toId,
      'amount_fils': amountFils,
      'date': _isoDate(date),
      'note': note,
      'created_at': LocalStore.nowIso(),
    });
  }

  Future<void> updateTransfer(int id, {required int fromId, required int toId, required int amountFils, required DateTime date, String? note}) async {
    _checkTransfer(fromId, toId, amountFils);
    await (await _db).updateRow('transfers', id,
        {'from_account_id': fromId, 'to_account_id': toId, 'amount_fils': amountFils, 'date': _isoDate(date), 'note': note});
  }

  Future<void> deleteTransfer(int id) async => (await _db).deleteRow('transfers', id);

  // ── Loans ────────────────────────────────────────────────────────────

  // Which of a loan's entries is what was lent or borrowed (the rest repay it).
  static const _principalType = "CASE l.direction WHEN 'lent' THEN 'expense' ELSE 'income' END";

  /// Every loan, with its amounts summed from its entries, newest first.
  Future<List<Loan>> loans() async {
    final store = await _db;
    final rows = await store.db.rawQuery('''
      SELECT l.id, l.direction, l.person, l.due_date, l.note, l.reminder_days, l.due_time,
        coalesce(sum(CASE WHEN t.type = $_principalType THEN t.amount_fils END), 0) AS amount_fils,
        coalesce(sum(CASE WHEN t.type != $_principalType THEN t.amount_fils END), 0) AS repaid_fils,
        min(CASE WHEN t.type = $_principalType THEN t.date END) AS date
      FROM loans l LEFT JOIN transactions t ON t.loan_id = l.id
      GROUP BY l.id
      ORDER BY date DESC, l.id DESC
    ''');
    return rows.map(Loan.fromMap).toList();
  }

  Future<Loan?> loan(int id) async => (await loans()).where((l) => l.id == id).firstOrNull;

  /// The starter category loan entries of [type] go in; null if deleted.
  Future<int?> _loanCategoryId(String type) => _starterCategoryId(LocalStore.loanCategoryKeys[type == 'expense' ? 0 : 1]);

  Future<int?> _starterCategoryId(String key) async =>
      (await (await _db).selectRows('categories', where: 'uid = ?', whereArgs: ['default:$key'])).firstOrNull?['id'] as int?;

  Map<String, Object?> _loanEntry(int loanId, String type, int amountFils, DateTime date, String description, int? categoryId, int accountId) => {
        'amount_fils': amountFils,
        'type': type,
        'date': _isoDate(date),
        'description': description,
        'category_id': categoryId,
        'loan_id': loanId,
        'account_id': accountId,
        'created_at': LocalStore.nowIso(),
      };

  /// Records a loan and the entry that moves its money: an expense for one
  /// you lent, an income for one you borrowed. [description] comes from the
  /// UI, in its language ("Payment for Ahmad").
  Future<int> insertLoan({
    required String direction,
    required String person,
    required int amountFils,
    required DateTime date,
    DateTime? dueDate,
    String? note,
    int? reminderDays,
    int dueMinutes = defaultReminderMinutes,
    required String description,
  }) async {
    final store = await _db;
    final type = direction == 'lent' ? 'expense' : 'income';
    final categoryId = await _loanCategoryId(type);
    final accountId = await defaultAccountId();
    return store.write((txn) async {
      final id = await store.insertIn(txn, 'loans', {
        'direction': direction,
        'person': person.trim(),
        'due_date': dueDate == null ? null : _isoDate(dueDate),
        'note': note,
        'reminder_days': dueDate == null ? null : reminderDays,
        'due_time': dueMinutes,
      });
      await store.insertIn(txn, 'transactions', _loanEntry(id, type, amountFils, date, description, categoryId, accountId));
      return id;
    });
  }

  /// Records a repayment: [amountFils] up to what's left, or all of it
  /// (settling the loan) when null. [description] as for [insertLoan].
  Future<void> recordRepayment(int loanId, {int? amountFils, required DateTime date, required String description}) async {
    final loan = await this.loan(loanId) ?? (throw StateError('No loan $loanId'));
    final fils = amountFils ?? loan.remainingFils;
    if (fils <= 0 || fils > loan.remainingFils) throw ArgumentError('A repayment must be more than 0 and at most ${loan.remainingFils}');
    final categoryId = await _loanCategoryId(loan.repaymentType);
    final accountId = await defaultAccountId();
    await (await _db).insertRow('transactions', _loanEntry(loanId, loan.repaymentType, fils, date, description, categoryId, accountId));
  }

  /// Edits a loan. [amountFils] and [date] change its lending or borrowing
  /// entry, and the amount can't go below what was already repaid. Entries
  /// still described as [describe] made them follow a new name; ones the
  /// user reworded are left alone.
  Future<void> updateLoan(
    int id, {
    required String person,
    required int amountFils,
    required DateTime date,
    DateTime? dueDate,
    String? note,
    int? reminderDays,
    int dueMinutes = defaultReminderMinutes,
    required String Function(String type, String person) describe,
  }) async {
    final store = await _db;
    final loan = await this.loan(id) ?? (throw StateError('No loan $id'));
    if (amountFils < loan.repaidFils) throw ArgumentError('Less than the ${loan.repaidFils} already repaid');
    final name = person.trim();
    final entries = await transactions(loanId: id, limit: 1 << 30);
    // The first is "the" entry; any other (made one in Activity) stays as it is.
    final principals = entries.where((t) => t.type == loan.principalType).toList()..sort((a, b) => a.date.compareTo(b.date));
    final rest = principals.skip(1).fold(0, (sum, t) => sum + t.amountFils);
    if (amountFils - rest <= 0) throw ArgumentError('The other entries already make ${loan.amountFils}');
    final categoryId = principals.isEmpty ? await _loanCategoryId(loan.principalType) : null;
    final accountId = await defaultAccountId();
    await store.write((txn) async {
      await store.updateIn(txn, 'loans', id, {
        'person': name,
        'due_date': dueDate == null ? null : _isoDate(dueDate),
        'note': note,
        'reminder_days': dueDate == null ? null : reminderDays,
        'due_time': dueMinutes,
      });
      for (final t in entries) {
        final values = <String, Object?>{
          if (name != loan.person && t.description == describe(t.type, loan.person)) 'description': describe(t.type, name),
          if (t == principals.firstOrNull) ...{'amount_fils': amountFils - rest, 'date': _isoDate(date)},
        };
        if (values.isNotEmpty) await store.updateIn(txn, 'transactions', t.id, values);
      }
      // Its entry was deleted in Activity: the edit puts one back.
      if (principals.isEmpty) {
        await store.insertIn(txn, 'transactions', _loanEntry(id, loan.principalType, amountFils, date, describe(loan.principalType, name), categoryId, accountId));
      }
    });
  }

  /// Deletes a loan and every entry it made. Returns how many entries went.
  Future<int> deleteLoan(int id) async {
    final store = await _db;
    return store.write((txn) async {
      final entries = await txn.query('transactions', columns: ['id'], where: 'loan_id = ?', whereArgs: [id]);
      for (final e in entries) {
        await store.deleteIn(txn, 'transactions', e['id'] as int);
      }
      await store.deleteIn(txn, 'loans', id);
      return entries.length;
    });
  }

  // ── Savings circles ──────────────────────────────────────────────────

  /// Every circle, with what's been paid in and received summed from its
  /// entries, latest start first.
  Future<List<Circle>> circles() async {
    final rows = await (await _db).db.rawQuery('''
      SELECT c.*,
        coalesce(sum(CASE WHEN t.type = 'expense' THEN t.amount_fils END), 0) AS paid_fils,
        coalesce(sum(CASE WHEN t.type = 'income' THEN t.amount_fils END), 0) AS received_fils
      FROM circles c LEFT JOIN transactions t ON t.circle_id = c.id
      GROUP BY c.id
      ORDER BY c.start_date DESC, c.id DESC
    ''');
    return rows.map(Circle.fromMap).toList();
  }

  Future<Circle?> circle(int id) async => (await circles()).where((c) => c.id == id).firstOrNull;

  Map<String, Object?> _circleRow(String name, int contributionFils, int rounds, String frequency, DateTime startDate, int payoutRound,
      String? note, int? reminderDays, int dueMinutes) {
    if (contributionFils <= 0 || rounds < 2 || rounds > Circle.maxRounds || payoutRound < 1 || payoutRound > rounds) {
      throw ArgumentError('A circle needs a contribution, 2 to ${Circle.maxRounds} rounds and a turn among them');
    }
    if (!Circle.frequencies.contains(frequency)) throw ArgumentError('Unknown frequency $frequency');
    return {
      'name': name.trim(),
      'contribution_fils': contributionFils,
      'rounds': rounds,
      'frequency': frequency,
      'start_date': _isoDate(startDate),
      'payout_round': payoutRound,
      'note': note,
      'reminder_days': reminderDays,
      'due_time': dueMinutes,
    };
  }

  Future<int> insertCircle({
    required String name,
    required int contributionFils,
    required int rounds,
    required String frequency,
    required DateTime startDate,
    required int payoutRound,
    String? note,
    int? reminderDays,
    int dueMinutes = defaultReminderMinutes,
  }) async =>
      (await _db).insertRow('circles', _circleRow(name, contributionFils, rounds, frequency, startDate, payoutRound, note, reminderDays, dueMinutes));

  /// Edits a circle's terms; its entries stay. Entries still described as
  /// [describe] made them follow a new name, as for [updateLoan].
  Future<void> updateCircle(
    int id, {
    required String name,
    required int contributionFils,
    required int rounds,
    required String frequency,
    required DateTime startDate,
    required int payoutRound,
    String? note,
    int? reminderDays,
    int dueMinutes = defaultReminderMinutes,
    required String Function(String type, String name) describe,
  }) async {
    final store = await _db;
    final old = await circle(id) ?? (throw StateError('No circle $id'));
    final row = _circleRow(name, contributionFils, rounds, frequency, startDate, payoutRound, note, reminderDays, dueMinutes);
    final renamed = row['name'] != old.name;
    final entries = renamed ? await transactions(circleId: id, limit: 1 << 30) : const <Transaction>[];
    await store.write((txn) async {
      await store.updateIn(txn, 'circles', id, row);
      for (final t in entries) {
        if (t.description == describe(t.type, old.name)) {
          await store.updateIn(txn, 'transactions', t.id, {'description': describe(t.type, row['name'] as String)});
        }
      }
    });
  }

  /// Records money paid into a circle ([type] expense) or its payout to you
  /// (income), in the default account. [description] comes from the UI.
  Future<void> recordCircleEntry(int circleId, {required String type, required int amountFils, required DateTime date, required String description}) async {
    if (amountFils <= 0) throw ArgumentError('An amount must be more than 0');
    final key = LocalStore.circleCategoryKeys[type == 'expense' ? 0 : 1];
    await (await _db).insertRow('transactions', {
      'amount_fils': amountFils,
      'type': type,
      'date': _isoDate(date),
      'description': description,
      'category_id': await _starterCategoryId(key),
      'circle_id': circleId,
      'account_id': await defaultAccountId(),
      'created_at': LocalStore.nowIso(),
    });
  }

  /// Deletes a circle and every entry it made. Returns how many entries went.
  Future<int> deleteCircle(int id) async {
    final store = await _db;
    return store.write((txn) async {
      final entries = await txn.query('transactions', columns: ['id'], where: 'circle_id = ?', whereArgs: [id]);
      for (final e in entries) {
        await store.deleteIn(txn, 'transactions', e['id'] as int);
      }
      await store.deleteIn(txn, 'circles', id);
      return entries.length;
    });
  }

  // ── Aggregates (computed over local rows) ────────────────────────────

  /// Aggregate income/expense fils within [from],[to].
  /// [accountId]: only that account's entries.
  Future<({int income, int expense})> totals(DateTime from, DateTime to, {int? accountId}) async {
    final store = await _db;
    final lo = _isoDate(from);
    final hi = _isoDate(to);
    final account = accountId == null ? '' : ' AND account_id = $accountId';
    final exp = await store.selectRows('transactions',
        where: 'date >= ? AND date <= ? AND type = ?$account', whereArgs: [lo, hi, 'expense']);
    final inc = await store.selectRows('transactions',
        where: 'date >= ? AND date <= ? AND type = ?$account', whereArgs: [lo, hi, 'income']);
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

  /// The months that have any entries, newest first, as the 1st of each.
  Future<List<DateTime>> transactionMonths() async {
    final store = await _db;
    // Dates are stored as yyyy-MM-dd, so the first 7 characters are the month.
    final rows = await store.db.rawQuery('SELECT DISTINCT substr(date, 1, 7) AS m FROM transactions ORDER BY m DESC');
    return [for (final r in rows) DateTime.parse('${r['m']}-01')];
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
    // Calendar days, not 24-hour steps: across a clock change those land an
    // hour off midnight, a day early, and the chart gets an extra bar.
    final start = DateTime(end.year, end.month, end.day - (days - 1));
    final txs = await transactions(from: start, to: end, type: 'expense', limit: 2000);
    // Calendar days, so a DST change can't skip or repeat one.
    final byDay = {for (var i = 0; i < days; i++) DateTime(start.year, start.month, start.day + i): 0};
    for (final t in txs) {
      byDay.update(t.date, (f) => f + t.amountFils, ifAbsent: () => t.amountFils);
    }
    return [for (final e in byDay.entries) (day: e.key, fils: e.value)];
  }
}
