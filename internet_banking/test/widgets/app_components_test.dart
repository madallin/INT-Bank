import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:internet_banking/core/utils/helpers.dart';
import 'package:internet_banking/theme/app_theme.dart';
import 'package:internet_banking/theme/app_tokens.dart';
import 'package:internet_banking/widgets/app_button.dart';
import 'package:internet_banking/widgets/error_retry_view.dart';
import 'package:internet_banking/widgets/pin_dot_indicator.dart';
import 'package:internet_banking/widgets/pin_pad.dart';
import 'package:internet_banking/widgets/step_indicator.dart';

Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  setUpAll(() {
    // Same setting as main.dart: fonts must come from assets/google_fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(host(AppButton(label: 'Trimite', onPressed: () => taps++)));
      await tester.tap(find.text('Trimite'));
      expect(taps, 1);
    });

    testWidgets('is announced as a disabled button without onPressed', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const AppButton(label: 'Trimite', onPressed: null)));
      expect(
        tester.getSemantics(find.byType(AppButton)),
        matchesSemantics(
          label: 'Trimite',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('blocks taps and announces progress while loading', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(host(AppButton(
        label: 'Trimite',
        isLoading: true,
        onPressed: () => taps++,
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(taps, 0);
      expect(find.bySemanticsLabel('Trimite, se procesează'), findsOneWidget);
      handle.dispose();
    });
  });

  group('PinPad', () {
    testWidgets('reports digits and deletes', (tester) async {
      final typed = <String>[];
      var deletes = 0;
      await tester.pumpWidget(host(PinPad(onDigit: typed.add, onDelete: () => deletes++)));
      await tester.tap(find.text('5'));
      await tester.tap(find.text('0'));
      await tester.tap(find.bySemanticsLabel('Șterge ultima cifră'));
      expect(typed, ['5', '0']);
      expect(deletes, 1);
    });

    testWidgets('ignores input while disabled', (tester) async {
      final typed = <String>[];
      await tester.pumpWidget(host(PinPad(onDigit: typed.add, onDelete: () {}, enabled: false)));
      await tester.tap(find.text('7'));
      await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
      expect(typed, isEmpty);
    });

    testWidgets('accepts a hardware keyboard', (tester) async {
      final typed = <String>[];
      var deletes = 0;
      await tester.pumpWidget(host(PinPad(onDigit: typed.add, onDelete: () => deletes++)));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(typed, ['3']);
      expect(deletes, 1);
    });

    testWidgets('keys meet the minimum tap target', (tester) async {
      await tester.pumpWidget(host(PinPad(onDigit: (_) {}, onDelete: () {})));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    });
  });

  testWidgets('PIN dots and steps describe progress to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const Column(children: [
      PinDotIndicator(length: 3),
      StepIndicator(currentStep: 1),
    ])));
    expect(find.bySemanticsLabel('3 din 6 cifre introduse'), findsOneWidget);
    expect(find.bySemanticsLabel('Pasul 2 din 3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('ErrorRetryView retries', (tester) async {
    var retries = 0;
    await tester.pumpWidget(host(ErrorRetryView(message: 'Eșec', onRetry: () => retries++)));
    await tester.tap(find.text('Reîncearcă'));
    expect(retries, 1);
  });

  testWidgets('snackbar helper replaces the visible message', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(host(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    showErrorSnackBar(ctx, 'Prima eroare');
    await tester.pump();
    showSuccessSnackBar(ctx, 'Gata');
    await tester.pumpAndSettle();
    expect(find.text('Prima eroare'), findsNothing);
    expect(find.text('Gata'), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, AppColors.light.brand);
  });

  testWidgets('bundled fonts load without network access', (tester) async {
    await tester.pumpWidget(host(Column(children: [
      Text('Inter', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      Text('Poppins', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      Text('Mono', style: AppTheme.mono(fontWeight: FontWeight.w700)),
    ])));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('theme exposes the colour tokens', () {
    expect(AppTheme.light().extension<AppColors>(), AppColors.light);
    expect(AppTheme.dark().extension<AppColors>(), AppColors.dark);
  });
}
