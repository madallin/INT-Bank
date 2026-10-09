import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/utils/day_groups.dart';
import 'package:internet_banking/l10n/l10n.dart';

void main() {
  setUp(() => AppL10n.update(lookupAppLocalizations(const Locale('ro'))));

  test('groups a newest-first list into runs of the same calendar day', () {
    final items = [
      DateTime(2026, 10, 6, 23, 59),
      DateTime(2026, 10, 6, 0, 1),
      DateTime(2026, 10, 5, 12),
      null,
      DateTime(2026, 10, 4, 8),
    ];

    final groups = groupByDay<DateTime?>(items, (d) => d);

    expect(groups.map((g) => g.day), [DateTime(2026, 10, 6), DateTime(2026, 10, 5), null, DateTime(2026, 10, 4)]);
    expect(groups.map((g) => g.items.length), [2, 1, 1, 1]);
    expect(groupByDay<DateTime?>(const [], (d) => d), isEmpty);
  });

  test('says today and yesterday, otherwise the date, in the active language', () {
    final now = DateTime(2026, 10, 7, 0, 30);

    expect(dayLabel(DateTime(2026, 10, 7, 23), now: now), 'Astăzi');
    expect(dayLabel(DateTime(2026, 10, 6, 1), now: now), 'Ieri');
    expect(dayLabel(DateTime(2026, 10, 5), now: now), '05.10.2026');

    AppL10n.update(lookupAppLocalizations(const Locale('en')));
    expect(dayLabel(DateTime(2026, 10, 7), now: now), 'Today');
    expect(dayLabel(DateTime(2026, 10, 6), now: now), 'Yesterday');
  });
}
