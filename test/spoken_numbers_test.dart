import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_sense/models/models.dart';
import 'package:pocket_sense/utils/spoken_numbers.dart';
import 'package:pocket_sense/utils/voice_parser.dart';

void main() {
  group('normalizeSpokenText', () {
    final cases = {
      // Whole numbers
      'SPENT TEN ON LUNCH': 'spent 10 on lunch',
      'twenty five': '25',
      'one hundred twenty three': '123',
      'a hundred and five': '105',
      'two thousand five hundred': '2500',
      'a thousand': '1000',
      'twelve thousand and forty': '12040',
      // Prices the way people say them
      'twelve fifty': '12.50',
      'nineteen ninety nine': '19.99',
      'one twenty five': '1.25',
      'nine oh five': '9.05',
      'twelve point five': '12.5',
      'three point one four': '3.14',
      // Cents only follow a small amount; big amounts stay whole
      'three hundred fifty': '350',
      // Words that aren't numbers are untouched
      'THREE DAYS AGO AT BLUE BOTTLE': '3 days ago at blue bottle',
      'a coffee': 'a coffee',
      'point of sale': 'point of sale',
      '': '',
    };
    cases.forEach((spoken, expected) {
      test('"$spoken" → "$expected"', () => expect(normalizeSpokenText(spoken), expected));
    });
  });

  test('desktop transcript parses like the Android one', () {
    final now = DateTime(2026, 9, 28);
    final cats = [Category(id: 1, name: 'Dining Out', type: 'expense', color: '#000')];
    final d = parseVoiceEntry(normalizeSpokenText('SPENT TWELVE FIFTY ON LUNCH AT SUBWAY YESTERDAY'), categories: cats, now: now);
    expect(d.amountFils, 12500);
    expect(d.type, 'expense');
    expect(d.merchant, 'Subway');
    expect(d.description, 'Lunch');
    expect(d.categoryId, 1);
    expect(d.date, DateTime(2026, 9, 27));
  });
}
