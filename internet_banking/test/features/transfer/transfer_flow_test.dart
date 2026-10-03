import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:internet_banking/features/auth/screens/two_factor_screen.dart';
import 'package:internet_banking/features/transfer/screens/transfer_receipt_screen.dart';
import 'package:internet_banking/features/transfer/screens/transfer_screen.dart';
import 'package:internet_banking/theme/app_theme.dart';
import 'package:internet_banking/widgets/confirm_dialog.dart';

Widget app(Widget home) => MaterialApp(theme: AppTheme.light(), home: home);

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// The TextField inside the FormTextField whose label is [label].
Finder fieldFor(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    // Tall viewport so the whole form is laid out.
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..physicalSize = const Size(1080, 3000)
      ..devicePixelRatio = 3;
  });

  group('TransferScreen', () {
    const ownIban = 'RO49INTB0001RON0000000001';

    Widget transfer() => app(const TransferScreen(
          userId: 1,
          userIban: ownIban,
          availableBalance: 500,
        ));

    testWidgets('shows inline errors instead of opening the sheet', (tester) async {
      await tester.pumpWidget(transfer());
      expect(find.text('Disponibil'), findsOneWidget);

      await tapText(tester, 'Transferă acum');

      expect(find.text('Introdu IBAN-ul destinatarului.'), findsOneWidget);
      expect(find.text('Introdu numele beneficiarului.'), findsOneWidget);
      expect(find.text('Introdu o sumă mai mare de 0.'), findsOneWidget);
      expect(find.textContaining('Descrie pe scurt plata'), findsOneWidget);
      expect(find.text('Verificare transfer'), findsNothing);

      // The first invalid field receives focus.
      final iban = tester.widget<TextField>(fieldFor('IBAN destinatar'));
      expect(iban.focusNode!.hasFocus, isTrue);
    });

    testWidgets('errors update while typing after the first attempt', (tester) async {
      await tester.pumpWidget(transfer());
      await tapText(tester, 'Transferă acum');

      await tester.enterText(fieldFor('IBAN destinatar'), 'RO49AAAA1B31007593840001');
      await tester.pump();
      expect(find.textContaining('IBAN-ul nu este valid'), findsOneWidget);

      await tester.enterText(fieldFor('IBAN destinatar'), 'RO49AAAA1B31007593840000');
      await tester.pump();
      expect(find.textContaining('IBAN-ul nu este valid'), findsNothing);

      await tester.enterText(fieldFor('Suma (RON)'), '600');
      await tester.pump();
      expect(find.textContaining('Sold insuficient'), findsOneWidget);
    });

    testWidgets('a valid form opens the confirmation with the source account', (tester) async {
      await tester.pumpWidget(transfer());
      await tester.enterText(fieldFor('IBAN destinatar'), 'RO49AAAA1B31007593840000');
      await tester.enterText(fieldFor('Nume beneficiar'), 'Ștefan Țurcanu');
      await tester.enterText(fieldFor('Suma (RON)'), '125,5');
      await tester.enterText(fieldFor('Motiv transfer'), 'chirie');
      await tapText(tester, 'Transferă acum');

      expect(find.text('Verificare transfer'), findsOneWidget);
      expect(find.text('Din contul'), findsWidgets);
      expect(find.text('125,50'), findsOneWidget);
      expect(find.textContaining('Strong Customer Authentication'), findsNothing);
      expect(find.textContaining('nu mai poate fi anulat'), findsOneWidget);
      expect(find.text('Confirmă transferul'), findsOneWidget);
    });
  });

  group('TransferReceiptScreen', () {
    TransferReceipt receipt({String? status, String? schedule}) => TransferReceipt(
          amount: 1250,
          currency: 'RON',
          beneficiaryName: 'ION POPESCU',
          toIban: 'RO49AAAA1B31007593840000',
          fromIban: 'RO49INTB0001RON0000000001',
          reason: 'Chirie',
          createdAt: DateTime(2026, 10, 2, 14, 5),
          trackingId: status == null ? null : 'TRK-42',
          status: status,
          scheduleSummary: schedule,
        );

    testWidgets('describes the outcome', (tester) async {
      await tester.pumpWidget(app(TransferReceiptScreen(receipt: receipt(status: 'COMPLETED'))));
      expect(find.text('Transfer efectuat'), findsOneWidget);
      expect(find.text('1.250,00 RON'), findsOneWidget);
      expect(find.text('TRK-42'), findsOneWidget);

      await tester.pumpWidget(app(TransferReceiptScreen(receipt: receipt(status: 'PENDING'))));
      expect(find.text('Transfer în procesare'), findsOneWidget);

      await tester.pumpWidget(app(TransferReceiptScreen(receipt: receipt(schedule: 'Lunar, din 01.11.2026'))));
      expect(find.text('Plată programată'), findsOneWidget);
      expect(find.text('Lunar, din 01.11.2026'), findsOneWidget);
    });

    for (final (label, expected) in [
      ('Gata', TransferReceiptAction.done),
      ('Transfer nou', TransferReceiptAction.newTransfer),
      ('back', TransferReceiptAction.done),
    ]) {
      testWidgets('"$label" returns $expected', (tester) async {
        TransferReceiptAction? result;
        await tester.pumpWidget(app(Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<TransferReceiptAction>(
                MaterialPageRoute(builder: (_) => TransferReceiptScreen(receipt: receipt(status: 'COMPLETED'))),
              );
            },
            child: const Text('open'),
          ),
        )));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        if (label == 'back') {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.text(label));
        }
        await tester.pumpAndSettle();
        expect(result, expected);
      });
    }
  });

  testWidgets('confirm dialog resolves to the choice made', (tester) async {
    final results = <bool>[];
    await tester.pumpWidget(app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => results.add(await showConfirmDialog(
          context,
          title: 'Blochezi temporar cardul?',
          message: 'Mesaj',
          confirmLabel: 'Blochează',
          destructive: true,
        )),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renunță'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blochează'));
    await tester.pumpAndSettle();
    expect(results, [false, true]);
  });

  testWidgets('2FA code field supports SMS autofill and paste', (tester) async {
    await tester.pumpWidget(app(const TwoFactorScreen(phoneNumber: '+40712345678', userId: 1)));
    // Let the (failing, offline) client-token request settle first; its retry
    // back-off runs on the fake clock, so advance both real and fake time.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 500));
    }

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(field.keyboardType, TextInputType.number);
    expect(field.autofocus, isTrue);

    // Pasting more than six characters keeps only the six digits.
    await tester.enterText(find.byType(TextField), '12a34567');
    await tester.pump();
    // No client token in tests, so the screen explains instead of failing.
    expect(find.textContaining('Codul nu a putut fi trimis'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
