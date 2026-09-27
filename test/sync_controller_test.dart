import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/sync_controller.dart';
import 'package:pocket_sense/data/sync_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final sync = SyncController.instance;

  test('ready is open when no session is attached, so reads never hang', () async {
    await sync.detach();
    await expectLater(sync.ready.timeout(const Duration(milliseconds: 50)), completes);
  });

  test('attach gates reads until the first sync; detach releases them', () async {
    final store = await LocalStore.openInMemoryForTest();
    // Never contacted: we only attach and detach.
    sync.attach(SyncEngine(store, SupabaseClient('http://localhost', 'test-key')));

    var released = false;
    sync.ready.then((_) => released = true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(released, isFalse, reason: 'first sync has not run yet');

    await sync.detach();
    await Future<void>.delayed(Duration.zero);
    expect(released, isTrue);
    expect(sync.status.value.state, SyncState.idle);
  });
}
