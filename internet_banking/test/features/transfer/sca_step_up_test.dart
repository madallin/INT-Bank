import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transfer/screens/transfer_screen.dart';
import 'package:internet_banking/features/transfer/widgets/sca_pin_sheet.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

/// Large payments must be confirmed with the PIN, against the details the bank
/// bound to its challenge (server: StrongCustomerAuthService).
void main() {
  setUpAll(setUpTestApp);

  const toIban = 'RO26INTBRON0000000000001';
  const challenge = FakeResponse(428, {
    'success': false,
    'code': 'SCA_REQUIRED',
    'error': 'Confirmă plata cu PIN-ul',
    'challengeId': 'sca-123',
    'amount': 1500,
    'currency': 'RON',
    'toIban': toIban,
  });

  Finder fieldFor(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
        matching: find.byType(TextField),
      );

  Future<void> fillAndConfirm(WidgetTester tester) async {
    await tester.enterText(fieldFor('IBAN destinatar'), toIban);
    await tester.enterText(fieldFor('Nume beneficiar'), 'Ion Popescu');
    await tester.enterText(fieldFor('Suma (RON)'), '1500');
    await tester.enterText(fieldFor('Motiv transfer'), 'avans');
    await tester.ensureVisible(find.text('Transferă acum'));
    await tester.tap(find.text('Transferă acum'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmă transferul'));
    await tester.tap(find.text('Confirmă transferul'));
    await settle(tester);
  }

  Future<void> typePin(WidgetTester tester, String pin) async {
    for (final digit in pin.split('')) {
      await tester.tap(find.descendant(of: find.byType(ScaPinSheet), matching: find.text(digit)));
      await tester.pump();
    }
    await settle(tester);
  }

  Widget screen() => testApp(const TransferScreen(
        userId: 1,
        userIban: 'RO49INTB0001RON0000000001',
        availableBalance: 5000,
      ));

  testWidgets('asks for the PIN, lets a wrong PIN be retried, then pays', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1600));
    final api = FakeApi({
      'POST /users/1/transfer': const FakeSequence([
        challenge,
        FakeResponse(400, {'success': false, 'code': 'SCA_PIN_INVALID', 'error': 'PIN incorect', 'remainingAttempts': 2}),
        {'success': true, 'trackingId': 'TRK-9', 'status': 'COMPLETED'},
      ]),
    })..install();

    await tester.pumpWidget(screen());
    await fillAndConfirm(tester);

    // The sheet shows the payment exactly as the bank bound it.
    expect(find.text('Confirmă plata'), findsOneWidget);
    Finder inSheet(String text) => find.descendant(of: find.byType(ScaPinSheet), matching: find.text(text));
    expect(inSheet('1.500,00 RON'), findsOneWidget);
    expect(inSheet('ION POPESCU'), findsOneWidget);
    expect(inSheet('RO26 INTB RON0 0000 0000 0001'), findsOneWidget);

    await typePin(tester, '111111');
    expect(find.text('PIN incorect. Mai ai 2 încercări.'), findsOneWidget);
    expect(find.text('Confirmă plata'), findsOneWidget, reason: 'sheet stays open for a retry');

    await typePin(tester, '246802');
    await tester.pumpAndSettle();
    expect(find.text('Transfer efectuat'), findsOneWidget);

    final sent = api.sentBodies.whereType<Map>().toList();
    expect(sent.first.containsKey('scaPin'), isFalse);
    expect(sent.last['scaChallengeId'], 'sca-123');
    expect(sent.last['scaPin'], '246802');
  });

  testWidgets('a locked PIN closes the sheet and explains why', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1600));
    FakeApi({
      'POST /users/1/transfer': const FakeSequence([
        challenge,
        FakeResponse(423, {'success': false, 'code': 'SCA_LOCKED', 'error': 'PIN blocat'}),
      ]),
    }).install();

    await tester.pumpWidget(screen());
    await fillAndConfirm(tester);
    await typePin(tester, '111111');
    await tester.pumpAndSettle();

    expect(find.text('Confirmă plata'), findsNothing);
    expect(find.textContaining('blocat temporar'), findsOneWidget);
    expect(find.text('Transfer efectuat'), findsNothing);
  });

  testWidgets('cancelling the PIN sheet sends nothing more', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1600));
    final api = FakeApi({'POST /users/1/transfer': challenge})..install();

    await tester.pumpWidget(screen());
    await fillAndConfirm(tester);
    await tester.tap(find.text('Anulează'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmă plata'), findsNothing);
    expect(api.calls.where((c) => c == 'POST /users/1/transfer'), hasLength(1));
  });
}
