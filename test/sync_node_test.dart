import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/sync/identity.dart';
import 'package:pocket_sense/sync/sync_node.dart';

Future<SyncNode> node(String name, int seed) async {
  final store = await LocalStore.openInMemoryForTest();
  final n = SyncNode(identity: await SyncIdentity.fromSeed(List.filled(32, seed)), store: () async => store, name: name);
  await n.start(port: 0);
  addTearDown(n.stop);
  return n;
}

final loopback = InternetAddress.loopbackIPv4;

Future<int> count(SyncNode n, String table) async => (await (await n.store()).db.query(table)).length;

void main() {
  test('two devices pair once the codes match, then sync both ways', () async {
    final a = await node('Laptop', 1), b = await node('Phone', 2);
    String? codeOnB;
    b.onPairRequest = (r) async {
      expect(r.name, 'Laptop');
      codeOnB = r.code;
      return true;
    };
    String? codeOnA;
    final paired = await a.pair(loopback, b.port, confirm: (code, name) async {
      expect(name, 'Phone');
      codeOnA = code;
      return true;
    });
    expect(codeOnA, matches(RegExp(r'^\d{6}$')));
    expect(codeOnA, codeOnB, reason: 'both screens show the same code');
    expect(paired.peer.name, 'Phone');
    expect(await count(b, 'peers'), 1);

    await (await a.store()).insertRow('transactions', {'amount_fils': 1, 'type': 'expense', 'date': '2026-09-01', 'description': 'a'});
    await (await b.store()).insertRow('transactions', {'amount_fils': 2, 'type': 'expense', 'date': '2026-09-01', 'description': 'b'});
    final n = await a.syncWith(paired.peer, loopback, b.port);
    expect(n, 1);
    expect(await count(a, 'transactions'), 2);
    expect(await count(b, 'transactions'), 2);

    // Nothing new: nothing changes, either way.
    final again = Peer((await (await a.store()).db.query('peers')).single);
    expect(await a.syncWith(again, loopback, b.port), 0);
  });

  test('pairing fails when either user says the codes differ', () async {
    final a = await node('A', 1), b = await node('B', 2);
    b.onPairRequest = (_) async => false;
    await expectLater(a.pair(loopback, b.port, confirm: (_, _) async => true),
        throwsA(isA<SyncFailure>().having((e) => e.problem, 'problem', SyncProblem.declined)));

    var cancelled = false;
    b.onPairRequest = (r) async {
      await r.cancelled.future;
      cancelled = true;
      return false;
    };
    await expectLater(a.pair(loopback, b.port, confirm: (_, _) async => false), throwsA(isA<SyncFailure>()));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(cancelled, isTrue, reason: "B's prompt closes when A says no");
    expect(await count(a, 'peers'), 0);
    expect(await count(b, 'peers'), 0);
  });

  test('a device refuses pairing unless its pairing screen is open', () async {
    final a = await node('A', 1), b = await node('B', 2);
    await expectLater(a.pair(loopback, b.port, confirm: (_, _) async => true), throwsA(isA<SyncFailure>()));
  });

  test('an unpaired device, or a forged key, gets nothing', () async {
    final a = await node('A', 1), b = await node('B', 2);
    b.onPairRequest = (_) async => true;
    final paired = await a.pair(loopback, b.port, confirm: (_, _) async => true);

    // B forgets A: A is told it isn't paired any more.
    await (await b.store()).db.delete('peers');
    await expectLater(a.syncWith(paired.peer, loopback, b.port),
        throwsA(isA<SyncFailure>().having((e) => e.problem, 'problem', SyncProblem.notPaired)));

    // A device B never paired with gets nothing either.
    final c = await node('C', 3);
    await expectLater(c.syncWith(Peer({...paired.peer.row}), loopback, b.port),
        throwsA(isA<SyncFailure>().having((e) => e.problem, 'problem', SyncProblem.notPaired)));
  });

  test('a sealed message opens only with the same key and label', () async {
    final a = await SyncIdentity.fromSeed(List.filled(32, 1));
    final b = await SyncIdentity.fromSeed(List.filled(32, 2));
    final c = await SyncIdentity.fromSeed(List.filled(32, 3));
    final ab = await a.sharedKey(b.publicKey);
    expect(await SyncIdentity.open(await b.sharedKey(a.publicKey), 'x', await SyncIdentity.seal(ab, 'x', {'n': 1})), {'n': 1});

    final sealed = await SyncIdentity.seal(ab, 'sync:a>b', {'n': 1});
    await expectLater(SyncIdentity.open(await c.sharedKey(b.publicKey), 'sync:a>b', sealed), throwsA(isA<SyncAuthError>()));
    await expectLater(SyncIdentity.open(ab, 'sync:b>a', sealed), throwsA(isA<SyncAuthError>()), reason: 'replayed the other way');
    final tampered = {...sealed, 'data': sealed['data']!.replaceRange(0, 2, sealed['data']!.startsWith('AA') ? 'BB' : 'AA')};
    await expectLater(SyncIdentity.open(ab, 'sync:a>b', tampered), throwsA(isA<SyncAuthError>()));
  });

  test('only local network addresses are accepted', () {
    for (final a in ['10.0.0.5', '172.16.1.1', '172.31.255.1', '192.168.1.20', '127.0.0.1', '169.254.3.4']) {
      expect(SyncNode.isLocal(InternetAddress(a)), isTrue, reason: a);
    }
    for (final a in ['8.8.8.8', '172.32.0.1', '100.64.0.1', '192.169.0.1']) {
      expect(SyncNode.isLocal(InternetAddress(a)), isFalse, reason: a);
    }
  });
}
