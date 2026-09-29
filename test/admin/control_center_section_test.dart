import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/admin_v2/control_center_section.dart';

class FakeAdminApi extends AdminControlApi {
  final mutations = <Map<String, dynamic>>[];
  bool failFirst = true;
  @override
  Future<Map<String, dynamic>> call(
      String operation, Map<String, dynamic> payload) async {
    if (operation == 'list') return {'items': <dynamic>[], 'nextCursor': null};
    mutations.add(Map.of(payload));
    if (failFirst) {
      failFirst = false;
      throw StateError('transport lost after commit');
    }
    return {'grantedSeconds': 600};
  }
}

void main() {
  testWidgets('ambiguous transport retry keeps the same grant id and amount',
      (tester) async {
    final api = FakeAdminApi();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ControlCenterSection(
                table: 'credits',
                title: 'Tempo adicional',
                readOnly: false,
                api: api))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conceder tempo'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'UID do usuário'), 'synthetic');
    await tester.enterText(
        find.widgetWithText(TextField, 'Minutos adicionais'), '10');
    await tester.enterText(
        find.widgetWithText(TextField, 'Justificativa obrigatória'),
        'Teste de suporte');
    await tester.tap(find.text('Confirmar concessão'));
    await tester.pumpAndSettle();
    expect(api.mutations.length, 1);
    expect(api.mutations.single['amountSeconds'], 600);
    await tester.tap(find.text('Confirmar resultado'));
    await tester.pumpAndSettle();
    expect(api.mutations.length, 2);
    expect(api.mutations[1], api.mutations[0]);
    expect(find.text('Operação aguardando confirmação'), findsNothing);
  });
  testWidgets('supervisor cannot open grant controls', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ControlCenterSection(
                table: 'credits',
                title: 'Tempo',
                readOnly: true,
                api: FakeAdminApi()))));
    await tester.pumpAndSettle();
    expect(find.text('Conceder tempo'), findsNothing);
  });
  testWidgets('clinical inventories have no upload controls', (tester) async {
    for (final table in ['pathologies', 'drugs']) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ControlCenterSection(
                  key: ValueKey(table),
                  table: table,
                  title: table,
                  api: FakeAdminApi()))));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.upload), findsNothing);
      expect(find.textContaining('Sem upload manual'), findsOneWidget);
    }
  });
}
