import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pocket_sense/settings/app_settings.dart';
import 'package:pocket_sense/utils/format.dart';

void main() {
  group('formatMoney', () {
    test('English: JOD prefix, three decimals, Latin digits', () {
      expect(formatMoney(12500, locale: 'en'), 'JOD\u00A012.500');
      expect(formatMoney(1234567, locale: 'en'), 'JOD\u00A01,234.567');
      expect(formatMoney(-50, locale: 'en'), '-JOD\u00A00.050');
      expect(formatMoney(1000, showSign: true, locale: 'en'), '+JOD\u00A01.000');
      expect(formatMoney(null), '—');
    });

    test('Arabic: د.أ suffix, Latin digits, number isolated left-to-right', () {
      expect(formatMoney(12500, locale: 'ar'), '\u206612.500\u2069\u00A0د.أ');
      expect(formatMoney(-12500, locale: 'ar'), '\u2066-12.500\u2069\u00A0د.أ');
      expect(formatMoney(12500, locale: 'ar_JO'), contains('12.500'));
    });
  });

  group('parseAmount', () {
    test('whole, one, two and three decimals', () {
      expect(parseAmount('12'), 12000);
      expect(parseAmount('12.5'), 12500);
      expect(parseAmount('12.50'), 12500);
      expect(parseAmount('12.505'), 12505);
      expect(parseAmount('.5'), 500);
      expect(parseAmount('12.'), 12000);
    });

    test('thousands separators and spaces', () {
      expect(parseAmount('1,250.75'), 1250750);
      expect(parseAmount(' 1 250 '), 1250000);
    });

    test('Arabic-Indic digits and the Arabic decimal separator', () {
      expect(parseAmount('١٢٫٥'), 12500);
      expect(parseAmount('١٬٢٥٠'), 1250000);
      expect(parseAmount('۱۲.۵'), 12500);
    });

    test('rejects nonsense and sub-fils precision', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('.'), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('1.2345'), isNull);
      expect(parseAmount('-5'), isNull);
      expect(parseAmount('1.2.3'), isNull);
    });
  });

  test('amountToInput round-trips through parseAmount', () {
    expect(amountToInput(12500), '12.5');
    expect(amountToInput(12000), '12');
    expect(amountToInput(12505), '12.505');
    expect(amountToInput(50), '0.05');
    for (final f in [0, 1, 10, 999, 1000, 12345, 987654321]) {
      expect(parseAmount(amountToInput(f)), f);
    }
  });

  test('compactAmount', () {
    expect(compactAmount(250), '250');
    expect(compactAmount(12.5), '12.5');
    expect(compactAmount(1500), '1.5k');
    expect(compactAmount(2000), '2k');
  });

  test('currencyAffix follows the language', () {
    expect(currencyAffix(locale: 'en'), (prefix: 'JOD ', suffix: null));
    expect(currencyAffix(locale: 'ar'), (prefix: null, suffix: ' د.أ'));
  });

  group('other currencies', () {
    tearDown(() => appCurrency = currencies.first);

    test('decimals follow the currency: 2 for USD, 0 for JPY, 3 for KWD', () {
      expect([for (final c in ['USD', 'JPY', 'KWD', 'JOD']) Currency.byCode(c)!.decimals], [2, 0, 3, 3]);
    });

    test('formatMoney: the code in English, the Arabic symbol or the code in Arabic', () {
      appCurrency = Currency.byCode('USD')!;
      expect(formatMoney(12500, locale: 'en'), 'USD\u00A012.50');
      expect(formatMoney(12500, locale: 'ar'), '\u206612.50\u2069\u00A0USD');
      appCurrency = Currency.byCode('SAR')!;
      expect(formatMoney(-3000, locale: 'ar'), '\u2066-3.00\u2069\u00A0ر.س');
      appCurrency = Currency.byCode('JPY')!;
      expect(formatMoney(1500000, locale: 'en'), 'JPY\u00A01,500');
    });

    test('parseAmount allows only as many decimals as the currency has', () {
      appCurrency = Currency.byCode('USD')!;
      expect(parseAmount('12.5'), 12500);
      expect(parseAmount('12.55'), 12550);
      expect(parseAmount('12.555'), isNull);
      appCurrency = Currency.byCode('JPY')!;
      expect(parseAmount('1,500'), 1500000);
      expect(parseAmount('1500.5'), isNull);
    });

    test('every currency on offer fits in fils', () {
      for (final c in currencies) {
        expect(c.decimals, lessThanOrEqualTo(3), reason: c.code);
      }
      expect(currencies.map((c) => c.code).toSet(), hasLength(currencies.length));
    });
  });

  group('formatDate', () {
    // The app gets this from Flutter's localization delegates.
    setUpAll(() => initializeDateFormatting());
    tearDown(() => Intl.defaultLocale = null);

    test('English: month first', () {
      AppSettings.applyToIntl(const Locale('en'));
      expect(formatDate(DateTime(2026, 10, 1)), 'Oct 1, 2026');
    });

    test('Arabic: day first, no English comma', () {
      AppSettings.applyToIntl(const Locale('ar'));
      expect(formatDate(DateTime(2026, 10, 1)), '1 أكتوبر 2026');
    });
  });
}
