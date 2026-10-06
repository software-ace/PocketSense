import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pbkdf2.dart';

/// Where the lock keeps its secrets. The app uses the OS keystore; tests
/// pass an in-memory map.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _KeystoreSecretStore implements SecretStore {
  static const _s = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

sealed class PinResult {}

class PinAccepted extends PinResult {}

class PinRejected extends PinResult {
  PinRejected(this.triesBeforeWait);

  /// Wrong attempts left before the next wait kicks in.
  final int triesBeforeWait;
}

class PinLockedOut extends PinResult {
  PinLockedOut(this.wait);
  final Duration wait;
}

/// The app-lock PIN: a salted PBKDF2 hash in the OS keystore, with wrong
/// guesses throttled. This is a UI lock; the database has its own key, so
/// a forgotten PIN never makes data unreadable, only unreachable.
class AppLock {
  AppLock({SecretStore? store, DateTime Function()? clock, this.iterations = 100000})
      : _store = store ?? _KeystoreSecretStore(),
        _now = clock ?? DateTime.now;

  static AppLock instance = AppLock();

  final SecretStore _store;
  final DateTime Function() _now;
  final int iterations;

  static const minLength = 4;
  static const maxLength = 6;

  /// Wrong guesses allowed before the first wait; then 30 s, doubling.
  static const freeTries = 5;
  static const firstWait = Duration(seconds: 30);

  static const _kHash = 'lock.pin.hash';
  static const _kSalt = 'lock.pin.salt';
  static const _kIter = 'lock.pin.iterations';
  static const _kLength = 'lock.pin.length';
  static const _kFailures = 'lock.failures';
  static const _kLockedUntil = 'lock.locked_until';
  static const _kBiometric = 'lock.biometric';

  Future<bool> get enabled async => await _store.read(_kHash) != null;

  /// Digits in the PIN, so the keypad can submit as soon as it's complete.
  Future<int?> get pinLength async => int.tryParse(await _store.read(_kLength) ?? '');

  static bool isValidPin(String pin) =>
      pin.length >= minLength && pin.length <= maxLength && RegExp(r'^\d+$').hasMatch(pin);

  /// Sets (or replaces) the PIN, which turns the lock on.
  Future<void> setPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN must be $minLength–$maxLength digits');
    final rng = Random.secure();
    final salt = List.generate(16, (_) => rng.nextInt(256));
    final hash = await _hash(pin, salt, iterations);
    await _store.write(_kSalt, base64.encode(salt));
    await _store.write(_kIter, '$iterations');
    await _store.write(_kLength, '${pin.length}');
    await _store.write(_kHash, base64.encode(hash));
    await _clearFailures();
  }

  /// Turns the lock (and biometric unlock) off.
  Future<void> disable() async {
    for (final k in [_kHash, _kSalt, _kIter, _kLength, _kFailures, _kLockedUntil, _kBiometric]) {
      await _store.delete(k);
    }
  }

  /// How long until another guess is allowed, or null if one is allowed now.
  Future<Duration?> waitRemaining() async {
    final until = DateTime.tryParse(await _store.read(_kLockedUntil) ?? '');
    if (until == null) return null;
    final left = until.difference(_now());
    return left > Duration.zero ? left : null;
  }

  Future<PinResult> verify(String pin) async {
    final wait = await waitRemaining();
    if (wait != null) return PinLockedOut(wait);
    final hash = await _store.read(_kHash);
    final salt = await _store.read(_kSalt);
    if (hash == null || salt == null) return PinAccepted(); // lock is off
    final iter = int.tryParse(await _store.read(_kIter) ?? '') ?? iterations;
    final ok = constantTimeEquals(await _hash(pin, base64.decode(salt), iter), base64.decode(hash));
    if (ok) {
      await _clearFailures();
      return PinAccepted();
    }
    // Counted in the keystore, so restarting the app doesn't reset it.
    final failures = (int.tryParse(await _store.read(_kFailures) ?? '') ?? 0) + 1;
    await _store.write(_kFailures, '$failures');
    if (failures < freeTries) return PinRejected(freeTries - failures);
    final lockout = firstWait * (1 << (failures - freeTries).clamp(0, 10));
    await _store.write(_kLockedUntil, _now().add(lockout).toIso8601String());
    return PinLockedOut(lockout);
  }

  /// A successful biometric unlock also clears the wrong-PIN count.
  Future<void> unlockedByBiometrics() => _clearFailures();

  Future<bool> get biometricsEnabled async => await _store.read(_kBiometric) == 'on';

  Future<void> setBiometrics(bool on) => on ? _store.write(_kBiometric, 'on') : _store.delete(_kBiometric);

  Future<void> _clearFailures() async {
    await _store.delete(_kFailures);
    await _store.delete(_kLockedUntil);
  }

  // Off the UI isolate: 100k iterations can take most of a second on a phone.
  static Future<List<int>> _hash(String pin, List<int> salt, int iterations) =>
      Isolate.run(() => pbkdf2Sha256(utf8.encode(pin), salt, iterations, 32));
}

@visibleForTesting
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}
