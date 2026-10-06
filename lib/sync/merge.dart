import 'package:sqflite_sqlcipher/sqflite.dart' as sq;

import '../data/local_store.dart';

/// Changes from a peer that don't hold together. Nothing was applied.
class SyncDataException implements Exception {
  SyncDataException(this.detail);
  final String detail;

  @override
  String toString() => 'SyncDataException($detail)';
}

/// What sync sends between devices, and how it's merged in. Rows travel
/// with their uid instead of the local integer id, and category_uid instead
/// of category_id. Each row is last-writer-wins by its hlc.
///
/// ponytail: last-writer-wins per row, not per field: two devices editing
/// different fields of the same entry while apart keep only the later edit.
/// Merge per field if that ever bites.
class Merge {
  Merge._();

  static const _children = ['transactions', 'budgets', 'recurring_expenses'];

  /// Every row and tombstone this device stamped after [since], and the seq
  /// they go up to. One snapshot, so nothing written meanwhile is skipped.
  /// ponytail: one payload, no paging; a few MB for years of entries. Page
  /// by table if it ever gets near the request size limit.
  static Future<Map<String, Object?>> changesSince(LocalStore store, int since) => store.db.transaction((txn) async {
        final catUid = {for (final r in await txn.query('categories', columns: ['id', 'uid'])) r['id']: r['uid']};
        final tables = <String, Object>{};
        for (final t in LocalStore.syncedTables) {
          tables[t] = [
            for (final r in await txn.query(t, where: 'seq > ?', whereArgs: [since]))
              {
                for (final e in r.entries)
                  if (e.key != 'id' && e.key != 'seq' && e.key != 'category_id') e.key: e.value,
                if (r.containsKey('category_id')) 'category_uid': catUid[r['category_id']],
              },
          ];
        }
        final tombstones = await txn.query('tombstones', columns: ['tbl', 'uid', 'hlc'], where: 'seq > ?', whereArgs: [since]);
        final union = [for (final t in [...LocalStore.syncedTables, 'tombstones']) 'SELECT seq FROM $t'].join(' UNION ALL ');
        final top = (await txn.rawQuery('SELECT max(seq) AS s FROM ($union)')).first['s'] as int? ?? 0;
        return {'tables': tables, 'tombstones': tombstones, 'up_to': top > since ? top : since};
      });

  // Columns that must be present (and not null) in every row from a peer.
  static const _required = {
    'categories': ['name', 'type', 'color'],
    'transactions': ['amount_fils', 'type', 'date', 'description'],
    'budgets': ['category_uid', 'limit_fils'],
    'recurring_expenses': ['description', 'amount_fils', 'frequency', 'anchor_date'],
  };
  static const _intColumns = {'amount_fils', 'limit_fils', 'active'};
  static const _dateColumns = {'date', 'anchor_date'};

  static bool _isUid(Object? v) => v is String && v.isNotEmpty && v.length <= 64;
  static bool _isHlc(Object? v) => v is String && LocalStore.hlcPattern.hasMatch(v);

  /// Checks every row before anything is written. A paired device is
  /// trusted, but a bug or a newer app on it mustn't break this database.
  static Future<({Map<String, List<Map<String, Object?>>> rows, List<Map<String, Object?>> tombstones})> _validate(
      LocalStore store, Object? changes) async {
    if (changes is! Map || changes['tables'] is! Map || changes['tombstones'] is! List) throw SyncDataException('shape');
    final rows = <String, List<Map<String, Object?>>>{};
    for (final t in LocalStore.syncedTables) {
      final list = (changes['tables'] as Map)[t] ?? const [];
      if (list is! List) throw SyncDataException(t);
      // Only known columns: a newer app's extra fields are dropped.
      final columns = {
        for (final c in await store.db.rawQuery('PRAGMA table_info($t)')) c['name'] as String,
        'category_uid',
      }..removeAll(['id', 'seq', 'category_id']);
      rows[t] = [
        for (final r in list)
          () {
            if (r is! Map || !_isUid(r['uid']) || !_isHlc(r['hlc'])) throw SyncDataException('$t: uid or hlc');
            for (final c in _required[t]!) {
              if (r[c] == null) throw SyncDataException('$t: missing $c');
            }
            for (final c in _intColumns) {
              if (r[c] != null && r[c] is! int) throw SyncDataException('$t: $c');
            }
            for (final c in _dateColumns) {
              if (r[c] != null && DateTime.tryParse('${r[c]}') == null) throw SyncDataException('$t: $c');
            }
            final type = r['type'];
            if (type != null && type != 'income' && type != 'expense') throw SyncDataException('$t: type');
            if (r['category_uid'] != null && !_isUid(r['category_uid'])) throw SyncDataException('$t: category_uid');
            return {for (final e in r.entries) if (columns.contains(e.key)) e.key as String: e.value};
          }(),
      ];
    }
    final tombstones = [
      for (final tb in changes['tombstones'] as List)
        if (tb is Map && LocalStore.syncedTables.contains(tb['tbl']) && _isUid(tb['uid']) && _isHlc(tb['hlc']))
          {'tbl': tb['tbl'], 'uid': tb['uid'], 'hlc': tb['hlc']}
        else
          throw SyncDataException('tombstone'),
    ];
    return (rows: rows, tombstones: tombstones);
  }

  /// Merges a peer's [changes] in, in one transaction. Returns how many rows
  /// changed here; a change already seen counts zero, so echoes die out.
  static Future<int> apply(LocalStore store, Object? changes) async {
    final v = await _validate(store, changes);
    for (final r in [...v.rows.values.expand((l) => l), ...v.tombstones]) {
      store.observeHlc(r['hlc'] as String);
    }
    var changed = 0;
    await store.db.transaction((txn) async {
      Future<String> newest(String table, String uid) async {
        final row = (await txn.query(table, columns: ['hlc'], where: 'uid = ?', whereArgs: [uid])).firstOrNull;
        final tomb = (await txn.query('tombstones', columns: ['hlc'], where: 'tbl = ? AND uid = ?', whereArgs: [table, uid])).firstOrNull;
        final a = row?['hlc'] as String? ?? '', b = tomb?['hlc'] as String? ?? '';
        return a.compareTo(b) > 0 ? a : b;
      }

      Future<void> tombstone(String table, String uid, Map<String, Object> stamp) => txn.insert(
          'tombstones', {'tbl': table, 'uid': uid, ...stamp}, conflictAlgorithm: sq.ConflictAlgorithm.replace);

      // Moves every child of category [from] to [to], as a fresh local edit,
      // so the move reaches peers that still point at [from].
      Future<void> repoint(int from, int to) async {
        for (final t in _children) {
          await txn.update(t, {'category_id': to, ...store.stamp()}, where: 'category_id = ?', whereArgs: [from]);
        }
      }

      // Category uid → the uid it was merged into by a name clash in this
      // batch, so the loser's children in the batch follow it. A uid, not a
      // local id: the winner may itself be merged on by a later row.
      final alias = <String, String>{};

      Future<int?> categoryId(String? uid) async {
        for (var hops = 0; uid != null && alias.containsKey(uid) && hops < 100; hops++) {
          uid = alias[uid];
        }
        if (uid == null) return null;
        return (await txn.query('categories', columns: ['id'], where: 'uid = ?', whereArgs: [uid])).firstOrNull?['id'] as int?;
      }

      // Rows go first, then tombstones (except a category's, when one with
      // its name arrives: see below). Uncategorizing a deleted category's
      // entries is then a fresh change only for entries this batch didn't
      // already bring a newer version of.
      final incomingRows = {for (final r in v.rows.values.expand((l) => l)) r['uid'] as String: r['hlc'] as String};
      Future<bool> applyTombstone(String table, String uid, String hlc) async {
        if ((await newest(table, uid)).compareTo(hlc) >= 0) return false;
        final id = (await txn.query(table, columns: ['id'], where: 'uid = ?', whereArgs: [uid])).firstOrNull?['id'] as int?;
        if (id != null) {
          if (table == 'categories') await store.releaseCategory(txn, id, incoming: incomingRows);
          await txn.delete(table, where: 'id = ?', whereArgs: [id]);
        }
        await tombstone(table, uid, {'hlc': hlc, 'seq': store.nextSeq()});
        changed++;
        return true;
      }

      final incomingTombstones = {for (final tb in v.tombstones) '${tb['tbl']}/${tb['uid']}': tb['hlc'] as String};

      for (final t in LocalStore.syncedTables) {
        for (final r in v.rows[t]!) {
          final uid = r['uid'] as String;
          if ((await newest(t, uid)).compareTo(r['hlc'] as String) >= 0) continue;
          final values = {for (final e in r.entries) if (e.key != 'category_uid') e.key: e.value, 'seq': store.nextSeq()};
          if (r.containsKey('category_uid')) {
            final catUid = r['category_uid'] as String?;
            final cid = await categoryId(catUid);
            // Its category was deleted here. As on delete, a budget goes and
            // an entry or recurring item is uncategorized, both as fresh
            // changes, so the devices that still have the category agree.
            if (cid == null && catUid != null) {
              if (t == 'budgets') {
                await txn.delete(t, where: 'uid = ?', whereArgs: [uid]);
                await tombstone(t, uid, store.stamp());
                changed++;
                continue;
              }
              values.addAll(store.stamp());
            }
            values['category_id'] = cid;
            // Moved to the category that won a clash: a fresh edit, so it
            // overrides the copy the sender is about to uncategorize.
            if (alias.containsKey(catUid)) values.addAll(store.stamp());
          }
          final local = (await txn.query(t, columns: ['id'], where: 'uid = ?', whereArgs: [uid])).firstOrNull?['id'] as int?;
          await txn.delete('tombstones', where: 'tbl = ? AND uid = ?', whereArgs: [t, uid]);
          changed++;

          if (t == 'categories') {
            // Names are unique here. Two devices that each made "Coffee" have
            // two uids for one name: both keep the lower uid, so they agree.
            var other = (await txn.query('categories',
                    columns: ['id', 'uid'], where: 'name = ? AND uid != ?', whereArgs: [r['name'], uid]))
                .firstOrNull;
            // Deleted in this same batch, then re-created under its name: no clash.
            final deleted = incomingTombstones['categories/${other?['uid']}'];
            if (other != null && deleted != null && await applyTombstone('categories', other['uid'] as String, deleted)) {
              other = null;
            }
            if (other != null) {
              final otherId = other['id'] as int, otherUid = other['uid'] as String;
              if (uid.compareTo(otherUid) > 0) {
                // Ours wins: the incoming one is merged into it.
                if (local != null) {
                  await repoint(local, otherId);
                  await txn.delete('categories', where: 'id = ?', whereArgs: [local]);
                }
                await tombstone(t, uid, store.stamp());
                alias[uid] = otherUid;
                continue;
              }
              // Theirs wins: ours is merged into it.
              await tombstone(t, otherUid, store.stamp());
              alias[otherUid] = uid;
              if (local != null) {
                await repoint(otherId, local);
                await txn.delete('categories', where: 'id = ?', whereArgs: [otherId]);
              } else {
                // Take over our row, so its children follow without moving,
                // then restamp them so peers learn their category's new uid.
                await txn.update('categories', values, where: 'id = ?', whereArgs: [otherId]);
                await repoint(otherId, otherId);
                continue;
              }
            }
          }
          if (local != null) {
            await txn.update(t, values, where: 'id = ?', whereArgs: [local]);
          } else {
            await txn.insert(t, values);
          }
        }
      }

      for (final tb in v.tombstones) {
        await applyTombstone(tb['tbl'] as String, tb['uid'] as String, tb['hlc'] as String);
      }
    });
    if (changed > 0) store.notifyChanged();
    return changed;
  }
}
