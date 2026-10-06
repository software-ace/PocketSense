import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show ConflictAlgorithm;

import '../security/pbkdf2.dart';
import 'local_store.dart';

/// Why a backup file was refused. Shown to the user, so each has its own
/// message in the UI.
enum BackupProblem { notJson, notABackup, tooNew, wrongCurrency, badData, wrongPassword }

class BackupException implements Exception {
  BackupException(this.problem, [this.detail]);
  final BackupProblem problem;
  final String? detail;

  @override
  String toString() => 'BackupException(${problem.name}${detail == null ? '' : ': $detail'})';
}

typedef ImportSummary = ({int categories, int transactions, int budgets, int recurring});

/// JSON backup of everything in the database. [export] gives the plain JSON;
/// [encrypt] wraps it for writing to a file, and [import] reads either.
class Backup {
  Backup._();

  static const format = 'pocketsense-backup';
  static const encryptedFormat = 'pocketsense-backup-encrypted';

  // PBKDF2 turns the password into the AES key. Pure Dart, so not the
  // 600k OWASP suggests: 200k is about 2 s on a phone, in an isolate.
  static const _iterations = 200000;
  static final _aes = AesGcm.with256bits();

  /// Wraps [json] in an AES-256-GCM envelope keyed by [password].
  static Future<String> encrypt(String json, String password, {int? iterations}) async {
    iterations ??= _iterations;
    final rng = Random.secure();
    final salt = [for (var i = 0; i < 16; i++) rng.nextInt(256)];
    final key = await _key(password, salt, iterations);
    final box = await _aes.encrypt(utf8.encode(json), secretKey: SecretKey(key));
    return jsonEncode({
      'format': encryptedFormat,
      'version': 1,
      'kdf': 'pbkdf2-sha256',
      'iterations': iterations,
      'salt': base64.encode(salt),
      'nonce': base64.encode(box.nonce),
      'data': base64.encode([...box.cipherText, ...box.mac.bytes]),
    });
  }

  /// True for a file made by [encrypt]; it then needs a password to [import].
  static bool isEncrypted(String text) {
    try {
      final doc = jsonDecode(text);
      return doc is Map && doc['format'] == encryptedFormat;
    } on FormatException {
      return false;
    }
  }

  /// The plain JSON inside an [encrypt]ed file. A wrong password and a
  /// damaged file fail the same GCM check: [BackupProblem.wrongPassword].
  static Future<String> decrypt(String text, String password) async {
    final Map doc;
    final List<int> salt, nonce, data;
    final int iterations;
    try {
      doc = jsonDecode(text) as Map;
      if (doc['version'] is! int || (doc['version'] as int) > 1) throw BackupException(BackupProblem.tooNew, '${doc['version']}');
      iterations = doc['iterations'] as int;
      salt = base64.decode(doc['salt'] as String);
      nonce = base64.decode(doc['nonce'] as String);
      data = base64.decode(doc['data'] as String);
    } on BackupException {
      rethrow;
    } catch (_) {
      throw BackupException(BackupProblem.notABackup);
    }
    if (data.length < 16) throw BackupException(BackupProblem.notABackup);
    final box = SecretBox(data.sublist(0, data.length - 16), nonce: nonce, mac: Mac(data.sublist(data.length - 16)));
    try {
      return utf8.decode(await _aes.decrypt(box, secretKey: SecretKey(await _key(password, salt, iterations))));
    } on SecretBoxAuthenticationError {
      throw BackupException(BackupProblem.wrongPassword);
    }
  }

  static Future<List<int>> _key(String password, List<int> salt, int iterations) =>
      Isolate.run(() => pbkdf2Sha256(utf8.encode(password), salt, iterations, 32));

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
    if (r['uid'] != null && r['uid'] is! String) throw BackupException(BackupProblem.badData, '$table: uid');
    // Only known columns: a newer app's extra fields are dropped rather than
    // failing the insert.
    return {for (final e in r.entries) if (columns.contains(e.key)) e.key as String: e.value};
  }

  static Future<String> export(LocalStore store, {DateTime? now}) async {
    final tables = <String, Object>{};
    for (final t in _tables) {
      // uid is kept, so a restore stays the same rows to paired devices;
      // hlc and seq are this device's sync bookkeeping.
      tables[t] = [
        for (final r in await store.db.query(t, orderBy: 'id')) {...r}..remove('hlc')..remove('seq'),
      ];
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
  /// current data untouched. The swap is stamped as a change made here, so
  /// paired devices get the same data on their next sync.
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
        final previous = {for (final t in _tables) t: {for (final r in await txn.query(t, columns: ['uid'])) r['uid'] as String}};
        for (final t in _tables.reversed) {
          await txn.delete(t);
        }
        for (final t in _tables) {
          final batch = txn.batch();
          for (final r in rows[t]!) {
            // Older backups have no uid.
            final uid = r['uid'] as String? ?? LocalStore.randomHex(16);
            previous[t]!.remove(uid);
            batch.delete('tombstones', where: 'tbl = ? AND uid = ?', whereArgs: [t, uid]);
            batch.insert(t, {...r, 'uid': uid, ...store.stamp()});
          }
          for (final uid in previous[t]!) {
            batch.insert('tombstones', {'tbl': t, 'uid': uid, ...store.stamp()}, conflictAlgorithm: ConflictAlgorithm.replace);
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

/// The backup password, kept in the OS keystore next to the database key so
/// automatic backups can run unattended. The user must still remember it: a
/// backup restored on another device asks for it.
class BackupPassword {
  BackupPassword._();

  static const _storage = FlutterSecureStorage();
  static const _name = 'pocketsense.backup_password.v1';
  static const minLength = 8;

  static Future<String?> read() => _storage.read(key: _name);
  static Future<void> save(String password) => _storage.write(key: _name, value: password);
  static Future<void> delete() => _storage.delete(key: _name);
}
