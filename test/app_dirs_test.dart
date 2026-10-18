import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_sense/utils/app_dirs.dart';

void main() {
  late Directory home;
  setUp(() => home = Directory.systemTemp.createTempSync('home'));
  tearDown(() => home.deleteSync(recursive: true));

  String legacy() => p.join(home.path, '.local', 'share', 'pocket_sense');
  String xdg() => p.join(home.path, 'xdg');

  test('without XDG_DATA_HOME, ~/.local/share', () {
    expect(linuxDataDir({'HOME': home.path}), legacy());
  });

  test('a Flatpak (or a new install with XDG_DATA_HOME) uses XDG_DATA_HOME', () {
    expect(linuxDataDir({'HOME': home.path, 'XDG_DATA_HOME': xdg()}), p.join(xdg(), 'pocket_sense'));
  });

  test('an existing install keeps its folder even with XDG_DATA_HOME set', () {
    Directory(legacy()).createSync(recursive: true);
    expect(linuxDataDir({'HOME': home.path, 'XDG_DATA_HOME': xdg()}), legacy());
  });
}
