import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/backup.dart';
import 'package:pocket_sense/data/db_key.dart';
import 'package:pocket_sense/data/passphrase_vault.dart';
import 'package:pocket_sense/security/vault_gate.dart';

void main() {
  late File file;
  setUp(() {
    final dir = Directory.systemTemp.createTempSync('vault');
    addTearDown(() => dir.deleteSync(recursive: true));
    file = File('${dir.path}/secrets.vault');
  });
  tearDown(() => PassphraseVault.current = null);

  test('secrets come back with the passphrase, and not without it', () async {
    final v = await PassphraseVault.create('correct horse', at: file);
    // Together, as the app's first launch writes them: neither may be lost.
    await Future.wait([v.write('a', '1'), v.write('b', '2')]);
    await v.delete('a');

    final again = await PassphraseVault.open('correct horse', at: file);
    expect((again.read('a'), again.read('b')), (null, '2'));
    expect(file.readAsStringSync(), isNot(contains('"b"')), reason: 'encrypted on disk');
    expect(File('${file.path}.tmp').existsSync(), isFalse);
    if (!Platform.isWindows) expect(file.statSync().mode & 0x1ff, 0x180, reason: 'readable by its owner only (600)');

    await expectLater(PassphraseVault.open('wrong horse', at: file),
        throwsA(isA<BackupException>().having((e) => e.problem, 'problem', BackupProblem.wrongPassword)));
  });

  test('while a vault is open, secureStorage reads and writes it', () async {
    PassphraseVault.current = await PassphraseVault.create('correct horse', at: file);
    await secureStorage.write(key: 'k', value: 'v');
    expect(await secureStorage.read(key: 'k'), 'v');
    expect((await PassphraseVault.open('correct horse', at: file)).read('k'), 'v');
    await secureStorage.delete(key: 'k');
    expect(await secureStorage.read(key: 'k'), isNull);
  });

  test('a failed write fails only itself: the next one still saves', () async {
    final v = await PassphraseVault.create('correct horse', at: file);
    final dir = file.parent;
    dir.deleteSync(recursive: true); // like a full disk: the write can't land
    await expectLater(v.write('a', '1'), throwsA(isA<FileSystemException>()));
    dir.createSync();
    await v.write('b', '2');
    final again = await PassphraseVault.open('correct horse', at: file);
    expect((again.read('a'), again.read('b')), ('1', '2'), reason: 'the second save writes the whole map');
  });

  group('the gate', () {
    Future<VaultNeed> decide({bool linux = true, bool open = false, bool vault = false, bool keyring = false, bool data = false}) {
      var askedKeyring = false;
      return VaultGate.decide(
        linux: linux,
        vaultOpen: open,
        vaultExists: () async => vault,
        keyringAvailable: () async {
          askedKeyring = true;
          return keyring;
        },
        dataExists: () async => data,
      ).then((need) {
        // Asking the keyring can pop up an unlock prompt: never when a vault is there.
        if (vault) expect(askedKeyring, isFalse);
        return need;
      });
    }

    test('keyring there, or not Linux: straight in', () async {
      expect(await decide(keyring: true), VaultNeed.none);
      expect(await decide(linux: false), VaultNeed.none);
      expect(await decide(open: true), VaultNeed.none);
    });

    test('a vault asks for its passphrase, keyring or not', () async {
      expect(await decide(vault: true), VaultNeed.unlock);
      expect(await decide(vault: true, keyring: true), VaultNeed.unlock);
    });

    test('no keyring: a new vault only on a fresh install, never over data whose key is in the keyring', () async {
      expect(await decide(), VaultNeed.create);
      expect(await decide(data: true), VaultNeed.none, reason: "Boot then says the keyring is down and offers Try again");
    });
  });
}
