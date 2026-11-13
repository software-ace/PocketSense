import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/app_dirs.dart';
import 'backup.dart';

/// Linux without a system keyring (no Secret Service: a bare window manager,
/// a test container): the secrets the keyring would hold, in one file
/// encrypted with a passphrase typed at each launch. While [current] is
/// set, `secureStorage` reads and writes here instead of the keyring.
///
/// Same envelope as an encrypted backup (PBKDF2-SHA256 → AES-256-GCM), so a
/// copied file is as hard to open as a backup without its password.
class PassphraseVault {
  PassphraseVault._(this._file, this._passphrase, this._values);

  static PassphraseVault? current;

  static const minLength = BackupPassword.minLength;

  final File _file;
  final String _passphrase;
  final Map<String, String> _values;
  Future<void> _saving = Future.value();

  static File file() => File(p.join(desktopDataDir(), 'secrets.vault'));

  static Future<PassphraseVault> create(String passphrase, {File? at}) async {
    final v = PassphraseVault._(at ?? file(), passphrase, {});
    await v._save();
    return v;
  }

  /// A wrong passphrase (or a damaged file) is [BackupProblem.wrongPassword].
  static Future<PassphraseVault> open(String passphrase, {File? at}) async {
    final f = at ?? file();
    final json = await Backup.decrypt(await f.readAsString(), passphrase);
    return PassphraseVault._(f, passphrase, Map<String, String>.from(jsonDecode(json) as Map));
  }

  String? read(String key) => _values[key];

  Future<void> write(String key, String value) {
    _values[key] = value;
    return _save();
  }

  Future<void> delete(String key) async {
    if (_values.remove(key) != null) await _save();
  }

  // One at a time, each the whole map: two saves racing on the temp file
  // could otherwise leave it half-written. A failed save (disk full) fails
  // its caller only; the next one still writes.
  Future<void> _save() => _saving = _saving.catchError((_) {}).then((_) => _write());

  // Through a temp file and a rename, so a crash leaves the old vault or the
  // new one, never half of one.
  Future<void> _write() async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString('');
    if (!Platform.isWindows) await Process.run('chmod', ['600', tmp.path]);
    await tmp.writeAsString(await Backup.encrypt(jsonEncode(_values), _passphrase), flush: true);
    await tmp.rename(_file.path);
  }
}
