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
    expect(d.amountCents, 850);
    expect(d.type, 'expense');
    expect(d.description, 'Coffee');
    expect(d.merchant, 'Blue Bottle');
    expect(d.date, DateTime(2026, 9, 26));
    expect(d.categoryId, 1, reason: 'coffee → Dining Out');
  });

  test('dollar sign and thousands separator', () {
    expect(parse('paid \$1,250 rent').amountCents, 125000);
    expect(parse('\$12.5 lunch').amountCents, 1250);
  });

  test('"dollars and cents" wording', () {
    expect(parse('12 dollars and 40 cents for groceries').amountCents, 1240);
  });

  test('income from words and category, merchant after "from"', () {
    final d = parse('received 500 from Acme for the website');
    expect(d.type, 'income');
    expect(d.amountCents, 50000);
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
    expect(early.amountCents, 1500, reason: '"30 days" is a date, not the amount');
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
    expect(d.amountCents, isNull);
    expect(d.merchant, 'Starbucks');
  });

  test('an income category is dropped for an expense sentence', () {
    // "salary" makes it income; a mismatch between type and category must not survive.
    final d = parse('spent 10 on salary advance fees');
    expect(d.categoryId == null || cats.firstWhere((c) => c.id == d.categoryId).type == d.type, isTrue);
  });
}
