import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/security/amount_privacy.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:pocket_sense/utils/format.dart';

import 'helpers/localized_app.dart';

/// Const, so only Hide amounts' rebuild-everything can update it.
class _Amount extends StatelessWidget {
  const _Amount();

  @override
  Widget build(BuildContext context) => Text(formatMoney(9500, locale: 'en'));
}

void main() {
  setUp(() {
    AppSettings.hideAmounts.value = true;
    AmountPrivacy.revealed.value = false;
    AmountPrivacy.init();
  });
  tearDown(() {
    AppSettings.hideAmounts.value = false; // leaves maskAmounts off
    AmountPrivacy.revealed.value = false;
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(localizedApp(Scaffold(appBar: AppBar(actions: const [AmountsButton()]), body: const _Amount())));
    await tester.pumpAndSettle();
  }

  Future<void> tapEye(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets('the eye shows amounts, and hides them again', (tester) async {
    await pumpApp(tester);
    expect(find.text('JOD •••'), findsOneWidget);
    expect(find.textContaining('9.500'), findsNothing, reason: 'the real digits are never drawn');

    await tapEye(tester, 'Show amounts');
    expect(find.text('JOD 9.500'), findsOneWidget);
    await tapEye(tester, 'Hide amounts');
    expect(find.text('JOD •••'), findsOneWidget);
  });

  testWidgets('with Hide amounts off there is no eye and amounts show', (tester) async {
    AppSettings.hideAmounts.value = false;
    await pumpApp(tester);
    expect(find.byType(IconButton), findsNothing);
    expect(find.text('JOD 9.500'), findsOneWidget);
  });
}
