import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/widgets/success_badge.dart';

import '../support/test_app.dart';

void main() {
  setUpAll(setUpTestApp);

  testWidgets('pops in over about a second, then holds still', (tester) async {
    await tester.pumpWidget(testApp(const Scaffold(body: Center(child: SuccessBadge(haptic: false)))));
    final box = find.descendant(of: find.byType(SuccessBadge), matching: find.byType(CustomPaint));

    await tester.pump(const Duration(milliseconds: 100));
    final early = tester.getSize(find.byType(Transform).last);
    await tester.pump(const Duration(milliseconds: 1000));
    final late = tester.getSize(find.byType(Transform).last);

    expect(box, findsWidgets);
    expect(late.width, greaterThanOrEqualTo(early.width));
    expect(tester.hasRunningAnimations, isFalse, reason: 'nothing keeps animating afterwards');
  });

  testWidgets('with animations removed it is finished at once', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: testApp(const Scaffold(body: Center(child: SuccessBadge(haptic: false)))),
      ),
    );
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('buzzes once when it appears', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(testApp(const Scaffold(body: Center(child: SuccessBadge()))));
    await tester.pump(const Duration(seconds: 2));

    expect(calls, hasLength(1));
  });
}
