import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/vaults/screens/vaults_screen.dart';

void main() {
  testWidgets('VaultsScreen renders summary, vaults list, and round-up controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VaultsScreen(userId: 42),
      ),
    );
    await tester.pumpAndSettle();

    // Verify headers and initial state
    expect(find.text('Seifuri de Economii'), findsOneWidget);
    expect(find.text('TOTAL ECONOMII'), findsOneWidget);
    expect(find.text('Fond de Urgență'), findsOneWidget);
    expect(find.text('Vacanță Grecia'), findsOneWidget);
    expect(find.text('Upgrade Laptop'), findsOneWidget);
    expect(find.text('Mărunțiș Automat (Round-Up)'), findsOneWidget);

    // Verify Round-up multiplier chips
    expect(find.text('1x'), findsOneWidget);
    expect(find.text('2x'), findsOneWidget);
    expect(find.text('3x'), findsOneWidget);

    // Tap on 2x multiplier
    await tester.tap(find.text('2x'));
    await tester.pumpAndSettle();

    // Verify FAB to create new vault
    expect(find.text('Seif Nou'), findsOneWidget);
  });
}
