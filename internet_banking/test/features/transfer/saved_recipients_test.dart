import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:internet_banking/features/transfer/screens/transfer_screen.dart';

import '../../support/fake_api.dart';
import '../../support/test_app.dart';

void main() {
  setUpAll(setUpTestApp);

  Future<FakeApi> open(WidgetTester tester, {Map<String, Object> routes = const {}}) async {
    usePhoneViewport(tester, size: const Size(400, 1800));
    final api = demoCustomerApi();
    api.routes.addAll(routes);
    api.install();
    await tester.pumpWidget(testApp(const TransferScreen(userId: 1, userIban: 'RO49INTB0001RON0000000001', availableBalance: 500)));
    await settle(tester);
    return api;
  }

  testWidgets('saved recipients sit at the top and one tap fills the form', (tester) async {
    await open(tester, routes: {
      'GET /users/1/beneficiaries': {
        'beneficiaries': [
          {'name': 'ION POPESCU', 'iban': 'RO26INTBRON0000000000001'},
          {'name': 'ANA IONESCU', 'nickname': 'Ana', 'iban': 'RO96INTBRON0000000000002'},
        ],
      },
    });

    expect(find.text('Destinatari salvați'), findsOneWidget);
    expect(find.text('IP'), findsOneWidget);
    expect(find.text('Ana'), findsWidgets, reason: 'a nickname wins over the legal name');

    await tester.tap(find.bySemanticsLabel('Transferă către ION POPESCU'));
    await tester.pump();

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, 'RO26 INTB RON0 0000 0000 0001');
    expect(fields[1].controller!.text, 'ION POPESCU');
    expect(fields[2].focusNode!.hasFocus, isTrue, reason: 'the amount is next');
  });

  testWidgets('without saved recipients, or when they cannot load, the form is unchanged', (tester) async {
    await open(tester, routes: {'GET /users/1/beneficiaries': {'beneficiaries': []}});
    expect(find.text('Destinatari salvați'), findsNothing);

    await open(tester, routes: {'GET /users/1/beneficiaries': const FakeResponse(500, {'error': 'boom'})});
    expect(find.text('Destinatari salvați'), findsNothing);
    expect(find.text('IBAN destinatar'), findsOneWidget);
  });
}
