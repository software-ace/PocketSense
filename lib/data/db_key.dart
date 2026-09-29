import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The OS keystore couldn't be reached (Linux: no Secret Service running, or
/// the keyring is locked). Without it the database can't be opened, and we
/// never fall back to an unencrypted one.
class KeyStoreUnavailable implements Exception {
  KeyStoreUnavailable(this.detail);
  final String detail;

  @override
  String toString() => 'The system keyring is unavailable ($detail). Pocket Sense keeps its '
      'encryption key there. On Linux, make sure a Secret Service provider such as '
      'GNOME Keyring or KWallet is running and unlocked.';
}

/// A database file exists but its key is gone (e.g. the keyring was reset).
/// The data can't be recovered; the only way forward is to erase it.
class DbKeyLost implements Exception {
  @override
  String toString() => "Your data is encrypted, but its key is no longer in the system keyring, "
      "so it can't be opened. You can erase it and start over.";
}

/// The database encryption key: 32 random bytes, hex-encoded, kept in the OS
/// keystore (Android Keystore; Secret Service on Linux). Independent of the
/// app-lock PIN, so forgetting the PIN never makes data unreadable.
class DbKey {
  DbKey._();

  static const _storage = FlutterSecureStorage();
  static const _name = 'pocketsense.db_key.v1';

  /// Returns the key, creating it when [dbExists] is false. A missing key for
  /// an existing database is [DbKeyLost] — minting a new one would just fail
  /// to open the file later with a less helpful error.
  static Future<String> obtain({required bool dbExists}) async {
    try {
      final existing = await _storage.read(key: _name);
      if (existing != null && existing.isNotEmpty) return existing;
      if (dbExists) throw DbKeyLost();
      final key = generate();
      await _storage.write(key: _name, value: key);
      return key;
    } on PlatformException catch (e) {
      throw KeyStoreUnavailable(e.message ?? e.code);
    }
  }

  static Future<void> delete() async {
    try {
      await _storage.delete(key: _name);
    } on PlatformException catch (e) {
      throw KeyStoreUnavailable(e.message ?? e.code);
    }
  }

  static String generate() {
    final rng = Random.secure();
    return [for (var i = 0; i < 32; i++) rng.nextInt(256).toRadixString(16).padLeft(2, '0')].join();
  }
}
