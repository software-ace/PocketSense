import 'dart:convert';

import 'local_store.dart';

/// Why a backup file was refused. Shown to the user, so each has its own
/// message in the UI.
enum BackupProblem { notJson, notABackup, tooNew, wrongCurrency, badData }

class BackupException implements Exception {
  BackupException(this.problem, [this.detail]);
  final BackupProblem problem;
  final String? detail;

  @override
  String toString() => 'BackupException(${problem.name}${detail == null ? '' : ': $detail'})';
}

typedef ImportSummary = ({int categories, int transactions, int budgets, int recurring});

/// Plain JSON backup of everything in the database. Unencrypted by design
/// (it's how data leaves the app), so the UI warns before writing one.
class Backup {
  Backup._();

  static const format = 'pocketsense-backup';
  static const version = 1;
  static const currency = 'JOD';

  // Parents first: this is the insert order, and reversed the delete order.
  static const _tables = ['categories', 'transactions', 'budgets', 'recurring_expenses'];

  // Columns that must be present (and not null) in every row.
  static const _required = {
    'categories': ['id', 'name', 'type', 'color'],
    'transactions': ['id', 'amount_fils', 'type', 'date', 'description'],
    'budgets': ['id', 'category_id', 'limit_fils'],
    'recurring_expenses': ['id', 'description', 'amount_fils', 'frequency', 'anchor_date'],
  };

  // SQLite would store "abc" in an INTEGER column, so check types up front.
  static const _intColumns = {'id', 'amount_fils', 'limit_fils', 'category_id', 'active'};

  static Map<String, Object?> _row(String table, Object? r, Set<String> columns) {
    if (r is! Map) throw BackupException(BackupProblem.badData, table);
    for (final c in _required[table]!) {
      if (r[c] == null) throw BackupException(BackupProblem.badData, '$table: missing $c');
    }
    for (final c in _intColumns) {
      if (r[c] != null && r[c] is! int) throw BackupException(BackupProblem.badData, '$table: $c is not a whole number');
    }
    final type = r['type'];
    if (type != null && type != 'income' && type != 'expense') throw BackupException(BackupProblem.badData, '$table: type $type');
    // Only known columns: a newer app's extra fields are dropped rather than
    // failing the insert.
    return {for (final e in r.entries) if (columns.contains(e.key)) e.key as String: e.value};
  }

  static Future<String> export(LocalStore store, {DateTime? now}) async {
    final tables = <String, Object>{};
    for (final t in _tables) {
      tables[t] = await store.db.query(t, orderBy: 'id');
    }
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exported_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'currency': currency,
      'tables': tables,
    });
  }

  /// Replaces everything in [store] with the backup in [json]. Validates
  /// first, then swaps inside one transaction, so a bad file leaves the
  /// current data untouched.
  static Future<ImportSummary> import(LocalStore store, String json) async {
    final Object? doc;
    try {
      doc = jsonDecode(json);
    } on FormatException catch (e) {
      throw BackupException(BackupProblem.notJson, e.message);
    }
    if (doc is! Map || doc['format'] != format || doc['tables'] is! Map) {
      throw BackupException(BackupProblem.notABackup);
    }
    final v = doc['version'];
    if (v is! int || v < 1) throw BackupException(BackupProblem.notABackup);
    if (v > version) throw BackupException(BackupProblem.tooNew, '$v');
    if (doc['currency'] != currency) throw BackupException(BackupProblem.wrongCurrency, '${doc['currency']}');

    final rows = <String, List<Map<String, Object?>>>{};
    for (final t in _tables) {
      final list = (doc['tables'] as Map)[t] ?? const [];
      if (list is! List) throw BackupException(BackupProblem.badData, t);
      final columns = {for (final c in await store.db.rawQuery('PRAGMA table_info($t)')) c['name'] as String};
      rows[t] = [for (final r in list) _row(t, r, columns)];
    }

    try {
      await store.db.transaction((txn) async {
        for (final t in _tables.reversed) {
          await txn.delete(t);
        }
        for (final t in _tables) {
          final batch = txn.batch();
          for (final r in rows[t]!) {
            batch.insert(t, r);
          }
          await batch.commit(noResult: true);
        }
      });
    } catch (e) {
      // Constraint failures (duplicate ids, a budget for a missing category,
      // wrong types) land here, after the transaction rolled back.
      throw BackupException(BackupProblem.badData, '$e');
    }
    store.notifyChanged();
    return (
      categories: rows['categories']!.length,
      transactions: rows['transactions']!.length,
      budgets: rows['budgets']!.length,
      recurring: rows['recurring_expenses']!.length,
    );
  }
}
