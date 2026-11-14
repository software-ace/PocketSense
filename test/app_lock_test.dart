import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/security/app_lock.dart';
import 'package:pocket_sense/security/pbkdf2.dart';

void main() {
  late MemorySecretStore store;
  late DateTime now;
  late AppLock lock;

  setUp(() {
    store = MemorySecretStore();
    now = DateTime(2026, 9, 29, 12);
    lock = AppLock(store: store, clock: () => now, iterations: 1000);
  });

  test('off until a PIN is set', () async {
    expect(await lock.enabled, isFalse);
    await lock.setPin('1234');
    expect(await lock.enabled, isTrue);
    expect(await lock.pinLength, 4);
  });

  test('the PIN itself is never stored, only a salted hash', () async {
    await lock.setPin('482913');
    expect(store.values.values.join(), isNot(contains('482913')));
    final first = store.values['lock.pin'];
    await lock.setPin('482913');
    expect(store.values['lock.pin'], isNot(first), reason: 'a fresh salt every time');
  });

  test('accepts the right PIN, rejects a wrong one', () async {
    await lock.setPin('1234');
    expect(await lock.verify('1234'), isA<PinAccepted>());
    final r = await lock.verify('9999');
    expect(r, isA<PinRejected>());
    expect((r as PinRejected).triesBeforeWait, AppLock.freeTries - 1);
  });

  test('only 4–6 digits are allowed', () {
    expect(AppLock.isValidPin('123'), isFalse);
    expect(AppLock.isValidPin('1234567'), isFalse);
    expect(AppLock.isValidPin('12a4'), isFalse);
    expect(AppLock.isValidPin('١٢٣٤'), isFalse, reason: 'the keypad produces Latin digits');
    expect(() => lock.setPin('12'), throwsArgumentError);
  });

  test('after 5 wrong PINs it waits 30 s, then doubles, even for the right PIN', () async {
    await lock.setPin('1234');
    for (var i = 0; i < AppLock.freeTries - 1; i++) {
      expect(await lock.verify('0000'), isA<PinRejected>());
    }
    final fifth = await lock.verify('0000');
    expect((fifth as PinLockedOut).wait, const Duration(seconds: 30));
    expect(await lock.verify('1234'), isA<PinLockedOut>(), reason: 'no guessing during the wait');

    now = now.add(const Duration(seconds: 31));
    final sixth = await lock.verify('0000');
    expect((sixth as PinLockedOut).wait, const Duration(seconds: 60));

    now = now.add(const Duration(seconds: 61));
    expect(await lock.verify('1234'), isA<PinAccepted>());
    expect((await lock.verify('0000') as PinRejected).triesBeforeWait, AppLock.freeTries - 1, reason: 'success resets the count');
  });

  test('the wrong-PIN count survives a restart', () async {
    await lock.setPin('1234');
    for (var i = 0; i < AppLock.freeTries; i++) {
      await lock.verify('0000');
    }
    final restarted = AppLock(store: store, clock: () => now, iterations: 1000);
    expect(await restarted.waitRemaining(), isNotNull);
  });

  test('disable removes the PIN and biometric unlock', () async {
    await lock.setPin('1234');
    await lock.setBiometrics(true);
    await lock.disable();
    expect(await lock.enabled, isFalse);
    expect(await lock.biometricsEnabled, isFalse);
    expect(store.values, isEmpty);
  });

  test('a change of PIN that fails leaves the old PIN working', () async {
    await lock.setPin('1234');
    final failing = _FailingWrites(store);
    final broken = AppLock(store: failing, clock: () => now, iterations: 1000);
    await expectLater(broken.setPin('5678'), throwsA(isA<StateError>()));
    expect(await lock.verify('1234'), isA<PinAccepted>(), reason: 'nothing half written');
  });

  test('a PIN stored the old way (four keys) still works, and moves to one key when changed', () async {
    final salt = [1, 2, 3, 4];
    store.values.addAll({
      'lock.pin.salt': base64.encode(salt),
      'lock.pin.iterations': '1000',
      'lock.pin.length': '4',
      'lock.pin.hash': base64.encode(pbkdf2Sha256(utf8.encode('2468'), salt, 1000, 32)),
    });
    expect((await lock.enabled, await lock.pinLength), (true, 4));
    expect(await lock.verify('2468'), isA<PinAccepted>());
    expect(await lock.verify('1111'), isA<PinRejected>());

    await lock.setPin('135790');
    expect(store.values.keys.where((k) => k.startsWith('lock.pin')), ['lock.pin']);
    expect(await lock.verify('135790'), isA<PinAccepted>());
  });
}

/// Every write fails, as a keystore that stops answering mid-change.
class _FailingWrites implements SecretStore {
  _FailingWrites(this.inner);
  final SecretStore inner;
  @override
  Future<String?> read(String key) => inner.read(key);
  @override
  Future<void> write(String key, String value) async => throw StateError('keystore');
  @override
  Future<void> delete(String key) => inner.delete(key);
}
