import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/data/models/card_model.dart';
import 'package:internet_banking/features/cards/screens/card_settings_screen.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

const _frozenOfflineCard = CardModel(
  id: 11,
  accountId: 101,
  cardNumber: '4111111111114821',
  cardHolder: 'Ion Popescu',
  expiryDate: '09/29',
  cvv: '***',
  cardType: 'VISA',
  spendingLimit: 1500,
  isBlocked: true,
  status: 'frozen',
  onlinePayments: false,
  contactless: true,
);

bool switchValue(WidgetTester tester, String title) => tester
    .widget<SwitchListTile>(find.ancestor(of: find.text(title), matching: find.byType(SwitchListTile)))
    .value;

void main() {
  setUpAll(setUpTestApp);

  testWidgets('starts from the state the bank reports for the card', (tester) async {
    usePhoneViewport(tester, size: const Size(390, 1400));
    FakeApi({}).install();

    await tester.pumpWidget(testApp(const CardSettingsScreen(userId: 1, card: _frozenOfflineCard)));
    await settle(tester);

    expect(switchValue(tester, 'Blocare temporară card'), isTrue);
    expect(switchValue(tester, 'Plăți online (e-Commerce)'), isFalse);
    expect(switchValue(tester, 'Plăți contactless POS'), isTrue);
  });

  testWidgets('a payment option the bank did not save is switched back', (tester) async {
    usePhoneViewport(tester, size: const Size(390, 1400));
    final api = FakeApi({})..install(); // PUT /limits is unmatched -> 404

    await tester.pumpWidget(testApp(const CardSettingsScreen(userId: 1, card: _frozenOfflineCard)));
    await settle(tester);

    final online = find.ancestor(of: find.text('Plăți online (e-Commerce)'), matching: find.byType(SwitchListTile));
    await tester.ensureVisible(online);
    await tester.tap(online);
    await settle(tester);

    expect(api.calls, contains('PUT /users/1/cards/11/limits'));
    expect(switchValue(tester, 'Plăți online (e-Commerce)'), isFalse);
  });
}
