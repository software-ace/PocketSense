import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/security/pbkdf2.dart';

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  // Expected values from Python's hashlib.pbkdf2_hmac('sha256', ...).
  test('matches reference PBKDF2-HMAC-SHA256 output', () {
    expect(hex(pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 1, 32)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    expect(hex(pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 4096, 32)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
  });

  test('longer than one block', () {
    final out = pbkdf2Sha256(utf8.encode('password'), utf8.encode('salt'), 1, 40);
    expect(out, hasLength(40));
    expect(hex(out.sublist(0, 32)), '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
  });

  test('constantTimeEquals', () {
    expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
    expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
  });

  test('cost of the app-lock setting (100k iterations)', () {
    final sw = Stopwatch()..start();
    final out = pbkdf2Sha256(utf8.encode('1234'), List.generate(16, (i) => i), 100000, 32);
    sw.stop();
    expect(hex(out), '869e6c8350c5beb0acc399fbaac3b60d220433896b26a647734d0d8f1586e1fa');
    // ignore: avoid_print
    print('PBKDF2 100k iterations: ${sw.elapsedMilliseconds} ms');
  });
}
