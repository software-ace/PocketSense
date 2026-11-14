import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../settings/app_settings.dart';
import '../utils/format.dart';

/// Hide amounts: while the setting is on, every amount reads ••• until the
/// eye in the top bar shows them.
abstract final class AmountPrivacy {
  /// Revealed for now: hidden again after the app lock's time away
  /// (LockGate), when the setting is turned back on, and at every launch.
  static final revealed = ValueNotifier(false);

  static void init() {
    AppSettings.hideAmounts.addListener(_apply);
    revealed.addListener(_apply);
    _apply();
  }

  static void _apply() {
    final mask = AppSettings.hideAmounts.value && !revealed.value;
    if (mask == maskAmounts) return;
    maskAmounts = mask;
    // formatMoney is a plain function nothing depends on, so rebuild every
    // widget, as hot reload does; their state stays.
    WidgetsBinding.instance.rootElement?.visitChildren(_rebuild);
  }

  static void _rebuild(Element e) {
    e.markNeedsBuild();
    e.visitChildren(_rebuild);
  }
}

/// The eye in each tab's top bar, while Hide amounts is on: shows or hides
/// amounts.
class AmountsButton extends StatelessWidget {
  const AmountsButton({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([AppSettings.hideAmounts, AmountPrivacy.revealed]),
        builder: (context, _) {
          if (!AppSettings.hideAmounts.value) return const SizedBox.shrink();
          final shown = AmountPrivacy.revealed.value;
          return IconButton(
            tooltip: shown ? context.l10n.hideAmounts : context.l10n.showAmounts,
            icon: Icon(shown ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => AmountPrivacy.revealed.value = !shown,
          );
        },
      );
}
