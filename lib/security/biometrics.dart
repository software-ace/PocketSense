import 'dart:io';

import 'package:local_auth/local_auth.dart';

/// Fingerprint / face unlock through the system prompt. Android only:
/// local_auth has no Linux implementation, so Linux is PIN-only.
class Biometrics {
  static final instance = Biometrics();

  final _auth = LocalAuthentication();

  /// True when the device has a biometric enrolled that the app can use.
  Future<bool> available() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system prompt. Any failure or cancel is just "not now": the
  /// PIN is always there as the fallback.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }
}
