import 'dart:io';

import 'package:path/path.dart' as p;

import '../settings/app_settings.dart';
import 'backup.dart';
import 'local_store.dart';

/// Daily encrypted backup to the folder chosen in Settings, keeping the
/// newest [keep]. Runs when the app opens or comes back, at most once a day.
class AutoBackup {
  AutoBackup._();

  static const keep = 10;
  static final _name = RegExp(r'^pocketsense-auto-\d{4}-\d{2}-\d{2}\.json$');
  static bool _running = false;

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Backs up unless it's off, already done today, or already running.
  /// Failures are recorded for Settings to show, never thrown.
  static Future<void> runIfDue({DateTime? now}) async {
    final s = AppSettings.autoBackup.value;
    final today = _day(now ?? DateTime.now());
    if (s.dir == null || s.last == today || _running) return;
    _running = true;
    try {
      final password = await BackupPassword.read();
      if (password == null) throw StateError('no backup password');
      await write(s.dir!, password, now ?? DateTime.now());
      await AppSettings.setAutoBackupResult(last: today);
    } catch (e) {
      await AppSettings.setAutoBackupResult(error: '$e');
    } finally {
      _running = false;
    }
  }

  /// Writes today's file (replacing an earlier one from today) and deletes
  /// all but the newest [keep].
  static Future<void> write(String dir, String password, DateTime now, {int? iterations}) async {
    final json = await Backup.export(await LocalStore.instance(), now: now);
    final sealed = await Backup.encrypt(json, password, iterations: iterations);
    final file = File(p.join(dir, 'pocketsense-auto-${_day(now)}.json'));
    // Write beside it, then rename: a crash mid-write never leaves a half file.
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(sealed, flush: true);
    await tmp.rename(file.path);

    final backups = [
      for (final f in Directory(dir).listSync())
        if (f is File && _name.hasMatch(p.basename(f.path))) f,
    ]..sort((a, b) => b.path.compareTo(a.path)); // dated names: newest first
    for (final old in backups.skip(keep)) {
      await old.delete();
    }
  }

  /// Whether the app can create files in [dir] (Android only allows some).
  static Future<bool> canWrite(String dir) async {
    try {
      final probe = File(p.join(dir, '.pocketsense-probe'));
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}
