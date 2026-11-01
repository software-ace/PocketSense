import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the home-screen widget or an app-icon shortcut asked for (Android).
enum QuickAdd { expense, income, voice }

/// Requests from MainActivity (channel pocketsense/quickadd): one waiting
/// from launch, then each one tapped while the app is running.
/// Activity opens the form for it once the app is unlocked.
abstract final class QuickAddRequests {
  static const _channel = MethodChannel('pocketsense/quickadd');

  /// The latest request not acted on yet; whoever acts on it sets it back to null.
  static final pending = ValueNotifier<QuickAdd?>(null);

  static void listen() {
    if (!Platform.isAndroid) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'open') pending.value = parse(call.arguments as String?);
    });
    _channel.invokeMethod<String>('take').then((a) => pending.value ??= parse(a)).ignore();
  }

  @visibleForTesting
  static QuickAdd? parse(String? action) => QuickAdd.values.asNameMap()[action];
}
