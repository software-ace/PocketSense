import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pocket_sense/data/db_key.dart';
import 'package:pocket_sense/data/local_store.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('pocketsense_enc'));
  tearDown(() => dir.delete(recursive: true));

  test('the database file on disk is encrypted, and opens again with its key', () async {
    final file = p.join(dir.path, 'test.db');
    final key = DbKey.generate();

    final db = await LocalStore.openEncryptedFfi(file, key);
    await db.insert('transactions', {'id': 1, 'amount_fils': 1, 'type': 'expense', 'date': '2026-09-29', 'description': 'Secret lunch'});
    await db.close();

    final bytes = await File(file).readAsBytes();
    expect(latin1.decode(bytes.take(15).toList()), isNot('SQLite format 3'));
    expect(latin1.decode(bytes).contains('Secret lunch'), isFalse);

    final again = await LocalStore.openEncryptedFfi(file, key);
    expect((await again.query('transactions')).single['description'], 'Secret lunch');
    await again.close();
  });

  test('a wrong key cannot open it', () async {
    final file = p.join(dir.path, 'test.db');
    await (await LocalStore.openEncryptedFfi(file, DbKey.generate())).close();
    expect(() => LocalStore.openEncryptedFfi(file, DbKey.generate()), throwsA(anything));
  });

  test('generated keys are 256-bit hex and differ', () {
    final a = DbKey.generate(), b = DbKey.generate();
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(a, isNot(b));
  });
}
