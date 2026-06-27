import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:internet_banking/main.dart';

void main() {
  testWidgets('App renders MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    // Advance past the 4-second SplashScreen timer
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
