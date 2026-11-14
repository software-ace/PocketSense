import 'dart:io';

import 'package:path/path.dart' as p;

/// Where Pocket Sense keeps its files on the desktop (databases, speech
/// model), created on first use: ~/.local/share/pocket_sense on Linux,
/// %LOCALAPPDATA%\pocket_sense on Windows. Local, not roaming: the database
/// key stays in this machine's keystore.
///
/// In a Flatpak, XDG_DATA_HOME is the app's own folder under ~/.var/app, and
/// that wins. Installs from before Pocket Sense read XDG_DATA_HOME used
/// ~/.local/share/pocket_sense whatever it said, so that folder wins while it
/// exists; a sandbox can't see it, so it never wins there.
String desktopDataDir([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  if (Platform.isWindows) {
    return _create(p.join(env['LOCALAPPDATA'] ?? env['USERPROFILE'] ?? '.', 'pocket_sense'));
  }
  final legacy = p.join(env['HOME'] ?? '.', '.local', 'share', 'pocket_sense');
  final xdg = env['XDG_DATA_HOME'] ?? '';
  final dir = xdg.isEmpty || Directory(legacy).existsSync() ? legacy : p.join(xdg, 'pocket_sense');
  return _create(dir);
}

String _create(String dir) {
  Directory(dir).createSync(recursive: true);
  return dir;
}
