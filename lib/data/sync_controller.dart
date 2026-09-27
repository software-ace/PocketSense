import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'sync_engine.dart';

enum SyncState { idle, syncing, offline, error }

@immutable
class SyncStatus {
  final SyncState state;
  final int pending; // local changes not yet on the server
  final DateTime? lastSynced;
  final String? error;
  const SyncStatus({this.state = SyncState.idle, this.pending = 0, this.lastSynced, this.error});

  SyncStatus copyWith({SyncState? state, int? pending, DateTime? lastSynced, String? error, bool clearError = false}) => SyncStatus(
        state: state ?? this.state,
        pending: pending ?? this.pending,
        lastSynced: lastSynced ?? this.lastSynced,
        error: clearError ? null : (error ?? this.error),
      );
}

/// App-wide owner of when sync runs. Sync used to fire only on launch and on
/// connectivity changes, so a delete made while online sat in the outbox until
/// the next restart. Now every local write schedules a (debounced) sync, and
/// runs are serialized so two overlapping pushes can't replay the same entry.
class SyncController {
  SyncController._();
  static final SyncController instance = SyncController._();

  static const _debounce = Duration(milliseconds: 800);
  static const _offlineRetry = Duration(seconds: 30);

  SyncEngine? _engine;
  Timer? _timer;
  Future<void>? _running;
  bool _rerun = false;

  final ValueNotifier<SyncStatus> status = ValueNotifier(const SyncStatus());

  /// Bumped whenever local data changes (own write or pulled from server).
  /// Tabs live in an IndexedStack and never rebuild on their own, so they
  /// listen to this to stay current.
  final ValueNotifier<int> dataChanged = ValueNotifier(0);

  void attach(SyncEngine engine) => _engine = engine;

  /// Called by the store each time a mutation is queued.
  void onLocalWrite() {
    dataChanged.value++;
    unawaited(_refreshPending());
    schedule();
  }

  void schedule([Duration delay = _debounce]) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(syncNow()));
  }

  /// Run a sync now, or — if one is in flight — queue exactly one more after
  /// it so changes made mid-sync still go out. Never throws; see [status].
  Future<void> syncNow() async {
    _timer?.cancel();
    if (_running != null) {
      _rerun = true;
      return _running;
    }
    _running = _run();
    try {
      await _running;
    } finally {
      _running = null;
    }
    if (_rerun) {
      _rerun = false;
      await syncNow();
    }
  }

  Future<void> _run() async {
    final engine = _engine;
    if (engine == null) return;
    status.value = status.value.copyWith(state: SyncState.syncing);
    try {
      final changed = await engine.sync();
      if (changed) dataChanged.value++;
      status.value = status.value.copyWith(state: SyncState.idle, lastSynced: DateTime.now(), clearError: true);
    } catch (e, st) {
      debugPrint('sync failed: $e\n$st');
      final offline = _looksOffline(e);
      status.value = status.value.copyWith(state: offline ? SyncState.offline : SyncState.error, error: e.toString());
      if (offline) schedule(_offlineRetry);
    } finally {
      await _refreshPending();
    }
  }

  Future<void> _refreshPending() async {
    final engine = _engine;
    if (engine == null) return;
    final n = (await engine.store.pending()).length;
    status.value = status.value.copyWith(pending: n);
  }

  static bool _looksOffline(Object e) {
    final cause = e is SyncPushException ? e.cause : e;
    if (cause is SocketException || cause is TimeoutException || cause is HandshakeException) return true;
    // http's ClientException isn't a direct dependency; match by text.
    final s = cause.toString();
    return s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup');
  }
}
