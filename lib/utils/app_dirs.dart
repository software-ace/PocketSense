import 'dart:io';

import 'package:path/path.dart' as p;

/// Where Pocket Sense keeps its files on the desktop (databases, speech
/// model), created on first use: ~/.local/share/pocket_sense on Linux,
/// %LOCALAPPDATA%\pocket_sense on Windows. Local, not roaming: the database
/// key stays in this machine's keystore.
String desktopDataDir() {
  final env = Platform.environment;
  final dir = Platform.isWindows
      ? p.join(env['LOCALAPPDATA'] ?? env['USERPROFILE'] ?? '.', 'pocket_sense')
      : p.join(env['HOME'] ?? '.', '.local', 'share', 'pocket_sense');
  Directory(dir).createSync(recursive: true);
  return dir;
}
