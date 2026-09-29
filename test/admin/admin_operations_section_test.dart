import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/admin_v2/admin_operations_section.dart';

class FakeApi extends AdminOperationsApi {
  final calls = <Map<String, dynamic>>[];
  bool failMutation = false;
  @override
  Future<Map<String, dynamic>> call(
      String op, Map<String, dynamic> data) async {
    calls.add({'operation': op, ...data});
    if (op == 'mutate' && failMutation) {
      failMutation = false;
      throw Exception('network');
    }
    if (op == 'mutate') return {'status': 'UPDATED'};
    if (op == 'overview')
      return {
        'users': 1,
        'services': [
          {'service': 'AssemblyAI', 'state': 'UNKNOWN'}
        ]
      };
    return {
      'items': [
        {'id': 'fixture', 'status': 'pending', 'role': 'user'}
      ],
      'source': 'synthetic',
      'sourceState': 'AVAILABLE',
      'total': 2,
      'nextCursor': data['cursor'] == null ? 'fixture' : null
    };
  }
}

void main() {
  testWidgets('Supervisor metadata view has no write controls', (t) async {
    final api = FakeApi();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminOperationsSection(
                table: 'users', title: 'Users', api: api))));
    await t.pumpAndSettle();
    expect(find.text('Papel'), findsNothing);
    expect(find.text('Status'), findsNothing);
    expect(find.text('Detalhe e uso'), findsOneWidget);
  });
  testWidgets('server cursor and exact search sent to backend', (t) async {
    final api = FakeApi();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminOperationsSection(
                table: 'users', title: 'Users', api: api))));
    await t.pumpAndSettle();
    await t.tap(find.text('Próxima página'));
    await t.pumpAndSettle();
    expect(api.calls.last['cursor'], 'fixture');
    await t.enterText(find.byType(TextField), 'qa@example.invalid');
    await t.tap(find.text('Buscar'));
    await t.pumpAndSettle();
    expect(api.calls.last['value'], 'qa@example.invalid');
    expect(api.calls.last.containsKey('cursor'), false);
  });
  testWidgets('section transition loads new source without stale user data',
      (t) async {
    final api = FakeApi();
    Future<void> show(String table) async {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: AdminOperationsSection(
                  table: table, title: table, api: api))));
      await t.pumpAndSettle();
    }

    await show('users');
    await show('health');
    expect(api.calls.last['operation'], 'overview');
    expect(find.textContaining('AssemblyAI'), findsOneWidget);
  });
  testWidgets('ambiguous retry reuses exact mutation request', (t) async {
    final api = FakeApi()..failMutation = true;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminOperationsSection(
                table: 'users', title: 'Users', readOnly: false, api: api))));
    await t.pumpAndSettle();
    await t.tap(find.text('Status'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'Synthetic support');
    await t.tap(find.text('Confirmar'));
    await t.pumpAndSettle();
    final first = api.calls.firstWhere((r) => r['operation'] == 'mutate');
    await t.tap(find.text('Confirmar resultado'));
    await t.pumpAndSettle();
    final writes = api.calls.where((r) => r['operation'] == 'mutate').toList();
    expect(writes.length, 2);
    expect(writes.last, first);
  });
  testWidgets('campaign page does not expose send', (t) async {
    final api = FakeApi();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminOperationsSection(
                table: 'campaigns',
                title: 'Campaigns',
                readOnly: false,
                api: api))));
    await t.pumpAndSettle();
    expect(find.text('Novo rascunho PT/ES'), findsOneWidget);
    expect(find.text('Enviar'), findsNothing);
  });
}
