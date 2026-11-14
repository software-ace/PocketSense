import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/screens/loans_screen.dart';

import 'helpers/localized_app.dart';

void main() {
  testWidgets('opens on a date outside its usual range, as an imported entry may have', (tester) async {
    for (final date in [DateTime(1999, 5, 1), DateTime(2099, 5, 1)]) {
      await tester.pumpWidget(localizedApp(Scaffold(
          body: DateField(label: 'Date', value: date, onPicked: (_) {}, lastDate: DateTime.now().add(const Duration(days: 365))))));
      await tester.tap(find.text('Date'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$date');
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
  });
}
