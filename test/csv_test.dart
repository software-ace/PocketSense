import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/data/csv_files.dart';
import 'package:pocket_sense/data/local_store.dart';
import 'package:pocket_sense/data/repo.dart';
import 'package:pocket_sense/screens/categories_screen.dart';
import 'package:pocket_sense/screens/import_preview_screen.dart';
import 'package:pocket_sense/screens/merchants_screen.dart';
import 'package:pocket_sense/utils/csv.dart';

import 'helpers/screen_with_db.dart';

void main() {
  group('csv', () {
    test('quotes only what needs it, and reads it all back', () {
      final rows = [
        ['plain', 'a,b', 'say "hi"', 'two\nlines', 'قهوة', ''],
      ];
      final text = encodeCsv(rows);
      expect(text, '﻿"plain","a,b","say ""hi""","two\nlines","قهوة",""\r\n');
      expect(decodeCsv(text), rows);
    });

    test('a quote inside an unquoted field is just a character, not the start of quoting', () {
      expect(decodeCsv('name\nScreen 15" monitor,x\nCarrefour\n'), [
        ['name'],
        ['Screen 15" monitor', 'x'],
        ['Carrefour'],
      ]);
    });

    test('LF or CRLF, no BOM, blank lines skipped', () {
      expect(decodeCsv('a,b\n\nc,d\r\n'), [
        ['a', 'b'],
        ['c', 'd'],
      ]);
    });
  });

  group('CsvFiles', () {
    final repo = FinanceRepo();
    setUp(() async => LocalStore.overrideInstanceForTest(await LocalStore.openInMemoryForTest(seed: true)));

    Future<int> count() async => (await repo.transactions(limit: 1 << 30)).length;

    Future<CsvPreview> preview(String csv, [CsvKind kind = CsvKind.transactions]) => CsvFiles.preview(kind, csv);
    Future<ImportSummary> importText(String csv, [CsvKind kind = CsvKind.transactions]) async => CsvFiles.importPreview(await preview(csv, kind));

    test('transactions: export, then import into another database, gives the same entries', () async {
      final food = (await repo.categories()).firstWhere((c) => c.type == 'expense');
      await repo.insertTransaction(
        amountFils: 3500,
        type: 'expense',
        date: DateTime(2026, 11, 2),
        description: 'Lunch, with "Sam"',
        merchant: 'Reem',
        categoryId: food.id,
      );
      await repo.insertTransaction(amountFils: 900000, type: 'income', date: DateTime(2026, 11, 1), description: 'Salary');
      final csv = await CsvFiles.export(CsvKind.transactions);
      expect(csv.split('\r\n')[1], '"2026-11-01","income","900","Salary","",""', reason: 'oldest first');

      LocalStore.overrideInstanceForTest(await LocalStore.openInMemoryForTest(seed: true));
      expect(await importText(csv), (added: 2, duplicates: 0, rejected: 0, categoriesMatched: 1, newMerchants: 1, uncategorized: 1));
      final lunch = (await repo.transactions()).firstWhere((t) => t.type == 'expense');
      expect([lunch.description, lunch.merchant, lunch.categoryName, lunch.amountFils], ['Lunch, with "Sam"', 'Reem', food.name, 3500]);
      expect((await repo.merchants()).map((m) => m.name), ['Reem'], reason: 'a new merchant is saved to the list');
    });

    test('the preview writes nothing; importing twice adds nothing, and two identical entries in one file both stay', () async {
      const csv = 'date,type,amount,description\n2026-11-03,expense,1.5,Coffee\n2026-11-03,expense,1.5,Coffee\n';
      final p = await preview(csv);
      expect(p.rows.map((r) => r.verdict), [CsvVerdict.add, CsvVerdict.add]);
      expect(await count(), 0, reason: 'nothing written before Import');
      expect((await CsvFiles.importPreview(p)).added, 2);
      expect((await preview(csv)).rows.map((r) => r.verdict), [CsvVerdict.duplicate, CsvVerdict.duplicate]);
      expect((await importText(csv)).added, 0);
      expect(await count(), 2);
    });

    test('a category you do not have leaves the entry uncategorized; columns match by name in any order', () async {
      final r = await importText(' Amount ,DESCRIPTION,date,type,category\n2,Book,2026-11-04,expense,Nope\n');
      expect([r.added, r.uncategorized, r.categoriesMatched], [1, 1, 0]);
      expect((await repo.transactions()).single.categoryId, isNull);
    });

    test('bad rows are rejected with the column at fault, and the rest still import', () async {
      const csv =
          'date,type,amount,description\n'
          '2026-11-05,expense,2,Fine\n'
          '05/11/2026,expense,2,Wrong date\n'
          '2026-02-30,expense,2,No such day\n'
          '2026-11-05,spent,2,Wrong type\n'
          '2026-11-05,expense,-2,Negative\n'
          '2026-11-05,expense,,Empty\n';
      final p = await preview(csv);
      expect(
        [for (final r in p.rows) (r.row, r.verdict, r.problem)],
        [
          (2, CsvVerdict.add, null),
          (3, CsvVerdict.rejected, 'date'),
          (4, CsvVerdict.rejected, 'date'),
          (5, CsvVerdict.rejected, 'type'),
          (6, CsvVerdict.rejected, 'amount'),
          (7, CsvVerdict.rejected, 'amount'),
        ],
      );
      expect((await CsvFiles.importPreview(p)).added, 1);
      expect(await count(), 1);
      await expectLater(
        preview('when,what\n'),
        throwsA(isA<CsvLayoutException>().having((e) => e.missing, 'missing', ['date', 'type', 'amount', 'description'])),
      );
    });

    test('categories and merchants: a name you have, in any case, or repeated in the file, is a duplicate', () async {
      final before = (await repo.categories()).length;
      final existing = (await repo.categories()).first.name.toUpperCase();
      final p = await preview('name,type,color\n$existing,expense,\nPets,expense,#AA00FF\npets,expense,\nGifts,income,\n,expense,\nX,expense,red\n', CsvKind.categories);
      expect([for (final r in p.rows) (r.verdict, r.problem)], [
        (CsvVerdict.duplicate, null),
        (CsvVerdict.add, null),
        (CsvVerdict.duplicate, null),
        (CsvVerdict.add, null),
        (CsvVerdict.rejected, 'name'),
        (CsvVerdict.rejected, 'color'),
      ]);
      expect((await CsvFiles.importPreview(p)).added, 2);
      expect((await repo.categories()).length, before + 2);
      final pets = (await repo.categories()).firstWhere((c) => c.name == 'Pets');
      expect(pets.color, '#aa00ff');
      expect((await repo.categories()).firstWhere((c) => c.name == 'Gifts').color, '#64748b', reason: 'no color: gray');

      await repo.insertMerchant('Reem');
      await repo.insertMerchant('Abdali Mall');
      final r = await importText('name\nREEM\nCarrefour\n', CsvKind.merchants);
      expect([r.added, r.duplicates, r.rejected], [1, 1, 0]);
      expect(await CsvFiles.export(CsvKind.merchants), '\ufeff"name"\r\n"Abdali Mall"\r\n"Carrefour"\r\n"Reem"\r\n');
    });
  });

  group('screens', () {
    setUp(useSeededTestDb);
    testWidgets('the import preview filters by its counters, and Import shows what it did', (tester) async {
      const csv = 'date,type,amount,description,merchant\n'
          '2026-10-28,expense,12.75,Morning coffee,Rumi Cafe\n'
          '2026-10-27,income,850,October salary,\n'
          '2026-10-26,expense,,Taxi ride,Uber\n'
          '2026-10-25,expense,"12,5",Bread,\n';
      final preview = (await tester.runAsync(() => CsvFiles.preview(CsvKind.transactions, csv)))!;
      await pumpScreenWithDb(tester, ImportPreviewScreen(fileName: 'bank-export-oct.csv', bytes: 2048, preview: preview));

      expect(find.text('bank-export-oct.csv'), findsOneWidget);
      expect(find.text('File layout'), findsOneWidget);
      expect(find.textContaining('2026-11-08,expense,12.75'), findsOneWidget, reason: 'open by itself: rows were rejected');
      await tester.scrollUntilVisible(find.text('Bread'), 200, scrollable: find.byType(Scrollable).first);
      // Built, if just past the edge of the test screen.
      expect(find.text('−12.75', skipOffstage: false), findsOneWidget, reason: 'spending shows as minus');
      expect(find.text('+850', skipOffstage: false), findsOneWidget);
      expect(find.text('No amount in the amount column.'), findsOneWidget);
      expect(find.text('Use a decimal point: 12.5, not 12,5.'), findsOneWidget);

      // The counters scroll with the page.
      await tester.scrollUntilVisible(find.text('rejected'), -200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('rejected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('rejected'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Taxi ride'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Taxi ride', skipOffstage: false), findsOneWidget);
      expect(find.text('Bread', skipOffstage: false), findsOneWidget);
      expect(find.text('Morning coffee', skipOffstage: false), findsNothing);

      await tester.tap(find.text('Import 2 transactions'));
      await settleWithDb(tester);
      expect(find.text('Import complete'), findsOneWidget);
      expect(find.text('Rejected rows'), findsOneWidget);
      expect((await tester.runAsync(() => FinanceRepo().transactions()))!.length, 2);
    });

    testWidgets('two taps on Import before the screen redraws import once', (tester) async {
      // No merchant: a new one's unique name would make a second write fail on its own.
      final preview = (await tester.runAsync(() => CsvFiles.preview(CsvKind.transactions, 'date,type,amount,description\n2026-10-28,expense,1,Coffee\n')))!;
      await pumpScreenWithDb(tester, ImportPreviewScreen(fileName: 'a.csv', bytes: 60, preview: preview));
      await tester.tap(find.text('Import 1 transaction'));
      await tester.tap(find.text('Import 1 transaction'), warnIfMissed: false);
      await settleWithDb(tester);
      expect((await tester.runAsync(() => FinanceRepo().transactions()))!.length, 1);
    });

    testWidgets('merchants use the same preview, with their own columns, rules and button', (tester) async {
      await tester.runAsync(() => FinanceRepo().insertMerchant('Reem'));
      final preview = (await tester.runAsync(() => CsvFiles.preview(CsvKind.merchants, 'name\nAbdali Mall\nreem\n\n')))!;
      await pumpScreenWithDb(tester, ImportPreviewScreen(fileName: 'merchants.csv', bytes: 40, preview: preview));
      expect(find.text('Import Merchants'), findsOneWidget);
      expect(find.text('Abdali Mall'), findsOneWidget);
      expect(find.text('Duplicate'), findsOneWidget);
      expect(find.text('Import 1 merchant'), findsOneWidget);
      await tester.tap(find.text('Import 1 merchant'));
      await settleWithDb(tester);
      expect(find.text('Merchants added'), findsOneWidget);
      expect(find.text('Already in your list'), findsOneWidget);
    });

    for (final (name, screen) in [('Categories', const CategoriesScreen()), ('Merchants', const MerchantsScreen())]) {
      testWidgets('$name has Import CSV and Export CSV in its ⋮ menu', (tester) async {
        await pumpScreenWithDb(tester, screen);
        await tester.tap(find.byType(PopupMenuButton<bool>));
        await tester.pumpAndSettle();
        expect(find.text('Import CSV'), findsOneWidget);
        expect(find.text('Export CSV'), findsOneWidget);
      });
    }
  });
}
