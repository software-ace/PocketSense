import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/models/models.dart';
import 'package:pocket_sense/utils/voice_parser.dart';

void main() {
  final cats = [
    Category(id: 1, name: 'Dining Out', type: 'expense', color: '#000', icon: 'tag'),
    Category(id: 2, name: 'Transport', type: 'expense', color: '#000', icon: 'tag'),
    Category(id: 3, name: 'Groceries', type: 'expense', color: '#000', icon: 'tag'),
    Category(id: 4, name: 'Salary', type: 'income', color: '#000', icon: 'tag'),
    Category(id: 5, name: 'PC', type: 'expense', color: '#000', icon: 'tag'),
  ];
  final now = DateTime(2026, 9, 27, 15); // a Sunday
  VoiceDraft parse(String s) => parseVoiceEntry(s, categories: cats, now: now);

  test('full sentence: amount, purpose, merchant, date, category', () {
    final d = parse('Spent 8.50 on coffee at Blue Bottle yesterday');
    expect(d.amountFils, 8500);
    expect(d.type, 'expense');
    expect(d.description, 'Coffee');
    expect(d.merchant, 'Blue Bottle');
    expect(d.date, DateTime(2026, 9, 26));
    expect(d.categoryId, 1, reason: 'coffee → Dining Out');
  });

  test('JD prefix, thousands separator and three decimals', () {
    expect(parse('paid JD 1,250 rent').amountFils, 1250000);
    expect(parse('12.5 lunch').amountFils, 12500);
    expect(parse('lunch 3.750').amountFils, 3750);
  });

  test('"dinars and fils" wording', () {
    final d = parse('12 dinars and 500 fils for groceries');
    expect(d.amountFils, 12500);
    expect(d.description, 'Groceries');
    expect(parse('2 JD and 50 fils coffee').amountFils, 2050, reason: 'a count of fils, not a decimal');
    expect(parse('1 dinar and 25 piasters bus').amountFils, 1250, reason: 'a piaster is 10 fils');
  });

  test('income from words and category, merchant after "from"', () {
    final d = parse('received 500 from Acme for the website');
    expect(d.type, 'income');
    expect(d.amountFils, 500000);
    expect(d.merchant, 'Acme');
    expect(d.description, 'The website');

    final s = parse('salary 3000');
    expect(s.type, 'income');
    expect(s.categoryId, 4);
  });

  test("the user's own category names win over hints", () {
    expect(parse('bought a new mouse for my PC 40').categoryId, 5);
  });

  test('relative dates', () {
    expect(parse('taxi 15 3 days ago').date, DateTime(2026, 9, 24));
    final early = parse('30 days ago taxi 15');
    expect(early.amountFils, 15000, reason: '"30 days" is a date, not the amount');
    expect(early.date, DateTime(2026, 8, 28));
    expect(parse('lunch 20 last friday').date, DateTime(2026, 9, 25));
    expect(parse('lunch 20 on sunday').date, DateTime(2026, 9, 20), reason: 'said on a Sunday → a week ago');
    expect(parse('lunch 20 day before yesterday').date, DateTime(2026, 9, 25));
    expect(parse('lunch 20').date, DateTime(2026, 9, 27));
  });

  test('uber → Transport; unmatched categories stay empty', () {
    expect(parse('uber 23').categoryId, 2);
    expect(parse('gift for mom 30').categoryId, isNull);
  });

  test('no amount leaves it empty for the user to type', () {
    final d = parse('coffee at Starbucks');
    expect(d.amountFils, isNull);
    expect(d.merchant, 'Starbucks');
  });

  test('an income category is dropped for an expense sentence', () {
    // "salary" makes it income; a mismatch between type and category must not survive.
    final d = parse('spent 10 on salary advance fees');
    expect(d.categoryId == null || cats.firstWhere((c) => c.id == d.categoryId).type == d.type, isTrue);
  });
}
