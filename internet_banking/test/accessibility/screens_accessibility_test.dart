import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_api.dart';
import '../support/screens.dart';
import '../support/test_app.dart';

/// Every screen, in both themes, both languages and at normal and large
/// text, must:
///  * offer 48dp (Android) / 44pt (iOS) tap targets,
///  * label everything tappable for screen readers,
///  * lay out without overflowing.
///
/// Text contrast is asserted from the colour tokens in
/// `test/theme/contrast_test.dart` instead of [textContrastGuideline], which
/// samples anti-aliased pixels and under-reports thin text.
void main() {
  setUpAll(setUpTestApp);
  final api = demoCustomerApi();
  setUp(api.install);

  for (final locale in const [Locale('ro'), Locale('en')]) {
    for (final brightness in Brightness.values) {
      for (final scale in const [1.0, 1.3]) {
        for (final screen in appScreens.entries) {
          testWidgets(
            '${screen.key} · ${locale.languageCode} · ${brightness.name} · text x$scale',
            (tester) async {
              final semantics = tester.ensureSemantics();
              usePhoneViewport(tester);

              final overflows = <String>[];
              final previous = FlutterError.onError;
              FlutterError.onError = (details) {
                final message = details.exceptionAsString();
                if (!message.contains('overflowed')) return;
                // Name the widget and source line so failures are actionable.
                final where = RegExp(
                  r'The relevant error-causing widget was:\s*\n\s*(.+)\n\s*(.+)',
                ).firstMatch(details.toString());
                overflows.add(
                  '${message.split('\n').first}'
                  '${where == null ? '' : ' (${where.group(1)} at ${where.group(2)!.split('/lib/').last})'}',
                );
              };
              addTearDown(() => FlutterError.onError = previous);

              await tester.pumpWidget(
                testApp(
                  screen.value(),
                  brightness: brightness,
                  textScale: scale,
                  locale: locale,
                ),
              );
              await settle(tester, rounds: 10);

              FlutterError.onError = previous;
              expect(overflows, isEmpty, reason: 'layout overflow');
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );

              // Dispose timers and listeners before the next case.
              await tester.pumpWidget(const SizedBox());
              await tester.pump(const Duration(seconds: 2));
              semantics.dispose();
            },
          );
        }
      }
    }
  }
}
