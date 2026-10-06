import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/auto_backup.dart';
import 'package:pocket_sense/data/backup.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late Directory dir;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    FlutterSecureStorage.setMockInitialValues({});
    LocalStore.overrideInstanceForTest(await LocalStore.openInMemoryForTest());
    await FinanceRepo().insertCategory(name: 'Food', type: 'expense', color: '#000000');
    dir = await Directory.systemTemp.createTemp('pocketsense-auto');
    await AppSettings.setAutoBackupDir(null);
  });

  tearDown(() => dir.delete(recursive: true));

  List<String> files() => [for (final f in dir.listSync()) f.uri.pathSegments.last]..sort();

  test('keeps the newest 10, and each file opens with the password', () async {
    for (var day = 1; day <= 12; day++) {
      await AutoBackup.write(dir.path, 'pw-12345', DateTime(2026, 10, day), iterations: 1000);
    }
    expect(files(), [for (var day = 3; day <= 12; day++) 'pocketsense-auto-2026-10-${'$day'.padLeft(2, '0')}.json']);
    final text = await File('${dir.path}/pocketsense-auto-2026-10-12.json').readAsString();
    expect(await Backup.decrypt(text, 'pw-12345'), contains('"Food"'));
  });

  test('runs at most once a day, and only when turned on', () async {
    await BackupPassword.save('pw-12345');
    final now = DateTime(2026, 10, 1, 9);

    await AutoBackup.runIfDue(now: now);
    expect(files(), isEmpty, reason: 'off');

    await AppSettings.setAutoBackupDir(dir.path);
    await AutoBackup.runIfDue(now: now);
    expect(files(), ['pocketsense-auto-2026-10-01.json']);
    expect(AppSettings.autoBackup.value.last, '2026-10-01');

    final written = File('${dir.path}/pocketsense-auto-2026-10-01.json').lastModifiedSync();
    await AutoBackup.runIfDue(now: now.add(const Duration(hours: 5)));
    expect(File('${dir.path}/pocketsense-auto-2026-10-01.json').lastModifiedSync(), written, reason: 'same day');
  });

  test('a failure is recorded for Settings, not thrown', () async {
    await AppSettings.setAutoBackupDir(dir.path); // but no backup password saved
    await AutoBackup.runIfDue(now: DateTime(2026, 10, 1));
    expect(files(), isEmpty);
    expect(AppSettings.autoBackup.value.error, contains('no backup password'));
  });
}
