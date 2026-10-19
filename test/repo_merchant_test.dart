import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';

void main() {
  final repo = FinanceRepo();
  final day = DateTime(2026, 10, 10);

  setUp(() async => LocalStore.overrideInstanceForTest(await LocalStore.openInMemoryForTest()));

  Future<void> spend(int fils, String? merchant, {String type = 'expense', DateTime? date}) =>
      repo.insertTransaction(amountFils: fils, type: type, date: date ?? day, description: '', merchant: merchant);

  test('groups expenses by merchant, ignoring case and spaces, largest first', () async {
    await spend(1000, 'reem ', date: DateTime(2026, 10, 1));
    await spend(2500, 'Reem');
    await spend(4000, 'Carrefour');
    await spend(700, null);
    await spend(300, '  ');
    await spend(9000, 'Employer', type: 'income');

    final rows = await repo.spendingByMerchant(DateTime(2026, 9, 20), DateTime(2026, 10, 19));
    expect(rows, [
      (label: 'Carrefour', fils: 4000),
      (label: 'Reem', fils: 3500), // as most recently typed
      (label: null, fils: 1000), // no merchant, blank or missing
    ]);
  });
}
