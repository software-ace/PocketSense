import 'dart:io';

import 'package:path/path.dart' as p;

/// Where Pocket Sense keeps its files on Linux (databases, speech model),
/// created on first use: `$XDG_DATA_HOME/pocket_sense`, which in a Flatpak is
/// the app's own folder under ~/.var/app. Installs from before this used
/// ~/.local/share/pocket_sense whatever XDG_DATA_HOME said, so that folder
/// wins while it exists; a sandbox can't see it, so it never wins there.
String linuxDataDir([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  final legacy = p.join(env['HOME'] ?? '.', '.local', 'share', 'pocket_sense');
  final xdg = env['XDG_DATA_HOME'] ?? '';
  final dir = xdg.isEmpty || Directory(legacy).existsSync() ? legacy : p.join(xdg, 'pocket_sense');
  Directory(dir).createSync(recursive: true);
  return dir;
}
