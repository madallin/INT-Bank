import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/error/screens/error_screen.dart';
import 'package:internet_banking/features/home/screens/home_screen.dart';
import 'package:internet_banking/features/home/widgets/home_card.dart';
import 'package:internet_banking/features/splash/splash_screen.dart';
import 'package:internet_banking/features/welcome/welcome_screen.dart';

import '../support/fake_api.dart';
import '../support/test_app.dart';

/// Start-up and Home must not make the customer wait or burn frames for nothing.
void main() {
  setUpAll(setUpTestApp);

  group('Splash', () {
    testWidgets('leaves as soon as the checks are done, after a short brand moment', (tester) async {
      usePhoneViewport(tester);
      FakeApi({'GET /health': {'status': 'UP'}}).install();

      await tester.pumpWidget(testApp(const SplashScreen()));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(WelcomeScreen), findsNothing, reason: 'the logo shows for at least 600 ms');

      await tester.pump(SplashScreen.minimumShown);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(WelcomeScreen), findsOneWidget, reason: 'well before the old fixed 4 seconds');
    });

    testWidgets('without the bank it says so instead of waiting', (tester) async {
      usePhoneViewport(tester);
      FakeApi({'GET /health': const FakeResponse(503, {'status': 'DOWN'})}).install();

      await tester.pumpWidget(testApp(const SplashScreen()));
      await settle(tester, rounds: 3);

      expect(find.byType(ErrorScreen), findsOneWidget);
    });
  });

  group('Home card details', () {
    testWidgets('turn back by themselves after a minute, without rebuilding Home every second', (tester) async {
      usePhoneViewport(tester, size: const Size(400, 1600));
      demoCustomerApi().install();
      await tester.pumpWidget(testApp(const HomeScreen(userId: 1)));
      await settle(tester);

      tester.widget<HomeCardFront>(find.byType(HomeCardFront)).onToggleReveal();
      await tester.pumpAndSettle();
      expect(find.byType(HomeCardBack), findsOneWidget);

      // Nothing on screen counts down, so a quiet second needs no new frame.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.pump(HomeScreen.cardRevealDuration - const Duration(seconds: 2));
      expect(find.byType(HomeCardBack), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byType(HomeCardFront), findsOneWidget);
      expect(find.byType(HomeCardBack), findsNothing);
    });
  });
}
