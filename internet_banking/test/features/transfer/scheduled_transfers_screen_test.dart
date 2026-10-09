import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transfer/screens/scheduled_transfers_screen.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

void main() {
  setUpAll(setUpTestApp);

  testWidgets('lists standing orders from the API, with their run status', (tester) async {
    usePhoneViewport(tester, size: const Size(400, 1400));
    demoCustomerApi().install();

    await tester.pumpWidget(testApp(const ScheduledTransfersScreen(userId: 1)));
    await settle(tester);

    expect(find.text('ANA IONESCU'), findsOneWidget);
    expect(find.text('210,00 RON'), findsOneWidget);

    // A paused order says so, and why.
    expect(find.text('ION POPESCU'), findsOneWidget);
    expect(find.text('Suspendată'), findsOneWidget);
    expect(find.text('Ultima încercare: Limita zilnica depasita'), findsOneWidget);

    // Dates and IBANs read like everywhere else in the app, not as raw server text.
    expect(find.textContaining('01.11.2026'), findsOneWidget);
    expect(find.text('RO96 INTB RON0 0000 0000 0002'), findsOneWidget);
    expect(find.textContaining('2026-11-01'), findsNothing);

    // Cancelled orders are history, not something to manage.
    expect(find.text('VECHI'), findsNothing);
    expect(find.byTooltip('Anulează'), findsNWidgets(2));
  });
}
