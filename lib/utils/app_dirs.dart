import 'dart:io';

import 'package:path/path.dart' as p;

/// Where Pocket Sense keeps its files on Linux (databases, speech model):
/// ~/.local/share/pocket_sense, created on first use.
String linuxDataDir() {
  final home = Platform.environment['HOME'] ?? '.';
  final dir = p.join(home, '.local', 'share', 'pocket_sense');
  Directory(dir).createSync(recursive: true);
  return dir;
}
