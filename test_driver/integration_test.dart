import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

// Writes the screenshots integration_test/screenshots_test.dart reports, at
// the repo-relative paths it gives them.
Future<void> main() => integrationDriver(responseDataCallback: (data) async {
      for (final MapEntry(:key, :value) in (data ?? const {}).entries) {
        File(key)
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(base64.decode(value as String));
        stdout.writeln('wrote $key');
      }
    });
