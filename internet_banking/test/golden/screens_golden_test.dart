@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/screens.dart';
import '../support/test_app.dart';

/// Screenshots of key screens in both themes, to catch unintended visual changes.
/// Run locally: flutter test --tags golden   (refresh: add --update-goldens)
void main() {
  setUpAll(setUpTestApp);

  const screens = [
    'welcome', 'home', 'shell', 'account_detail', 'payments', 'profile', 'transfer', 'receipt', 'history', 'exchange', 'analytics', 'vaults', 'card_settings', 'sca_sheet', 'scheduled',
  ];

  for (final name in screens) {
    for (final brightness in Brightness.values) {
      testWidgets('$name ${brightness.name}', (tester) async {
        usePhoneViewport(tester, size: const Size(390, 844));
        demoCustomerApi().install();
        await tester.pumpWidget(testApp(appScreens[name]!(), brightness: brightness));
        await settle(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${name}_${brightness.name}.png'));
      });
    }
  }
}
