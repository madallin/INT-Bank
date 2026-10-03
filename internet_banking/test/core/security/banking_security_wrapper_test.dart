import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/core/security/banking_security_wrapper.dart';
import 'package:internet_banking/core/security/session_timeout_service.dart';

void main() {
  testWidgets('BankingSecurityWrapper renders child normally when active', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BankingSecurityWrapper(
          child: Scaffold(
            body: Text('Protected Bank Content'),
          ),
        ),
      ),
    );

    expect(find.text('Protected Bank Content'), findsOneWidget);
    expect(find.text('Sesiune Expirată'), findsNothing);
    expect(find.text('INTBank • Protecție Confidențialitate'), findsNothing);
  });

  testWidgets('BankingSecurityWrapper shows lock overlay when session times out', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BankingSecurityWrapper(
          child: Scaffold(
            body: Text('Protected Bank Content'),
          ),
        ),
      ),
    );

    expect(find.text('Sesiune Expirată'), findsNothing);

    // Trigger session lock
    SessionTimeoutService.instance.lockSession();
    await tester.pump();

    expect(find.text('Sesiune Expirată'), findsOneWidget);
    expect(find.text('Reautentificare'), findsOneWidget);

    // Unlock session
    await tester.tap(find.text('Reautentificare'));
    await tester.pump();

    expect(find.text('Sesiune Expirată'), findsNothing);
  });
}
