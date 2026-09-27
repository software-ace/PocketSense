import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_store.dart';
import 'sync_controller.dart';
import 'sync_engine.dart';

/// Binds the local store and sync to exactly one signed-in account at a time.
class DataSession {
  DataSession._();

  static String? _userId;
  static Future<void>? _pending;

  static String? get userId => _userId;

  /// Open [userId]'s local database and start syncing it. Safe to call
  /// repeatedly (auth events fire more than once for the same user).
  static Future<void> start(String userId) => _serial(() async {
        if (_userId == userId) return;
        await _stop();
        final store = await LocalStore.openForUser(userId);
        final sync = SyncController.instance..attach(SyncEngine(store, Supabase.instance.client));
        store.onAppend = sync.onLocalWrite;
        _userId = userId;
        unawaited(sync.syncNow());
      });

  /// Stop syncing and close the database. Queued changes stay in the user's
  /// file and upload the next time they sign in on this device.
  static Future<void> end() => _serial(_stop);

  static Future<void> _stop() async {
    if (_userId == null) return;
    await SyncController.instance.detach();
    await LocalStore.closeCurrent();
    _userId = null;
  }

  // Auth events can arrive back to back; never let two transitions interleave.
  static Future<void> _serial(Future<void> Function() op) {
    final next = (_pending ?? Future<void>.value()).then((_) => op());
    _pending = next.catchError((_) {});
    return next;
  }
}
