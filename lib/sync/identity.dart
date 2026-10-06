import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/db_key.dart';

/// Thrown when a message from a peer fails authentication: wrong key,
/// tampered, or not meant for this device.
class SyncAuthError implements Exception {
  @override
  String toString() => 'SyncAuthError';
}

/// This device's sync key pair (X25519), kept in the OS keystore like
/// [DbKey]. Paired devices know each other by public key; [id] is a short
/// fingerprint of it.
class SyncIdentity {
  SyncIdentity._(this.keyPair, this.publicKey, this.id);

  final SimpleKeyPair keyPair;
  final List<int> publicKey;
  final String id;

  static const _storage = FlutterSecureStorage();
  static const _name = 'pocketsense.sync_key.v1';
  static final _x25519 = X25519();
  static final _aes = AesGcm.with256bits();

  /// The stored identity, created on first use.
  static Future<SyncIdentity> obtain() async {
    try {
      var seed = await _storage.read(key: _name);
      if (seed == null) {
        seed = base64.encode(randomBytes(32));
        await _storage.write(key: _name, value: seed);
      }
      return await fromSeed(base64.decode(seed));
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

  static Future<SyncIdentity> fromSeed(List<int> seed) async {
    final kp = await _x25519.newKeyPairFromSeed(seed);
    final pub = (await kp.extractPublicKey()).bytes;
    return SyncIdentity._(kp, pub, await idOf(pub));
  }

  static Future<String> idOf(List<int> publicKey) async => _hex((await Sha256().hash(publicKey)).bytes.sublist(0, 8));

  /// The key this device and [peerPublicKey] share: X25519, then HKDF bound
  /// to both public keys. No forward secrecy, deliberately: whoever has a
  /// device's private key also has the device, and its whole database.
  Future<SecretKey> sharedKey(List<int> peerPublicKey) async {
    final secret = await _x25519.sharedSecretKey(
        keyPair: keyPair, remotePublicKey: SimplePublicKey(peerPublicKey, type: KeyPairType.x25519));
    final keys = [_hex(publicKey), _hex(peerPublicKey)]..sort();
    return Hkdf(hmac: Hmac.sha256(), outputLength: 32)
        .deriveKey(secretKey: secret, nonce: utf8.encode('pocketsense-sync-v1'), info: utf8.encode(keys.join()));
  }

  /// Encrypts [message] under [key]. [label] (who → whom, which request) is
  /// authenticated too, so a sealed message can't be replayed somewhere else.
  static Future<Map<String, String>> seal(SecretKey key, String label, Object? message) async {
    final box = await _aes.encrypt(utf8.encode(jsonEncode(message)), secretKey: key, aad: utf8.encode(label));
    return {'nonce': base64.encode(box.nonce), 'data': base64.encode([...box.cipherText, ...box.mac.bytes])};
  }

  static Future<Object?> open(SecretKey key, String label, Object? sealed) async {
    try {
      final m = sealed as Map;
      final data = base64.decode(m['data'] as String);
      final box = SecretBox(data.sublist(0, data.length - 16),
          nonce: base64.decode(m['nonce'] as String), mac: Mac(data.sublist(data.length - 16)));
      return jsonDecode(utf8.decode(await _aes.decrypt(box, secretKey: key, aad: utf8.encode(label))));
    } catch (_) {
      throw SyncAuthError();
    }
  }

  /// The commitment the responder sends before seeing the initiator's nonce,
  /// so it can't pick its nonce to make a man-in-the-middle's codes match.
  static Future<List<int>> commitment(List<int> responderKey, List<int> initiatorKey, List<int> responderNonce) async =>
      (await Sha256().hash([...responderKey, ...initiatorKey, ...responderNonce])).bytes;

  /// The 6-digit code both screens show; the users compare them. The same
  /// scheme as Bluetooth's numeric comparison.
  static Future<String> pairingCode(List<int> initiatorKey, List<int> responderKey, List<int> initiatorNonce, List<int> responderNonce) async {
    final h = (await Sha256().hash([...initiatorKey, ...responderKey, ...initiatorNonce, ...responderNonce])).bytes;
    final n = ((h[0] << 24) | (h[1] << 16) | (h[2] << 8) | h[3]) % 1000000;
    return n.toString().padLeft(6, '0');
  }

  static List<int> randomBytes(int n) {
    final rng = Random.secure();
    return [for (var i = 0; i < n; i++) rng.nextInt(256)];
  }

  static String _hex(List<int> bytes) => [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();
}
