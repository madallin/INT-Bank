import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/utils/day_groups.dart';
import 'package:internet_banking/core/utils/formatters.dart';
import 'package:internet_banking/core/utils/helpers.dart';
import 'package:internet_banking/l10n/l10n.dart';

import 'amount_input_formatter_test.dart' show paste, typeKeys;

/// The English app shows and accepts English numbers and dates; Romanian is unchanged.
void main() {
  tearDown(() => AppL10n.update(lookupAppLocalizations(const Locale('ro'))));

  test('Romanian stays 1.234,56 and dd.MM.yyyy', () {
    AppL10n.update(lookupAppLocalizations(const Locale('ro')));
    expect(formatMoney(12345.67, 'RON'), '12.345,67 RON');
    expect(formatDate(DateTime(2026, 10, 9)), '09.10.2026');
    expect(parseAmount('1.234,5'), 1234.5);
  });

  test('English shows 1,234.56 and an unambiguous date', () {
    AppL10n.update(lookupAppLocalizations(const Locale('en')));
    expect(formatMoney(12345.67, 'RON'), '12,345.67 RON');
    expect(formatMoney(-1250, 'EUR', showSign: true), '-1,250.00 EUR');
    expect(formatRate(4.9712), '4.9712');
    expect(formatPercent(58.4), '58.4%');
    expect(formatDate(DateTime(2026, 10, 9)), '9 Oct 2026');
    expect(formatDateTime(DateTime(2026, 1, 2, 14, 5)), '2 Jan 2026, 14:05');
    expect(dayLabel(DateTime(2026, 9, 30), now: DateTime(2026, 10, 9)), '30 Sep 2026');
  });

  test('English typing uses the same separators as the display', () {
    AppL10n.update(lookupAppLocalizations(const Locale('en')));
    expect(typeKeys('1234'), '1,234');
    expect(typeKeys('1234.5'), '1,234.5');
    expect(typeKeys('12,5'), '12.5', reason: 'a keyboard comma with one digit after it is the decimal point');
    expect(paste('1,500'), '1,500', reason: 'three digits after it: a thousands group');
    expect(parseAmount('1,234.56'), 1234.56);
    expect(parseAmount(formatAmount(98765.4)), 98765.4, reason: 'what is shown can be read back');
  });
}
