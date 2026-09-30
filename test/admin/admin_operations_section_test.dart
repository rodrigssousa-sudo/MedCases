import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/admin_v2/admin_operations_section.dart';

class FakeApi extends AdminOperationsApi {
  final calls = <Map<String, dynamic>>[];
  bool failMutation = false;
  @override
  Future<Map<String, dynamic>> call(
    String op,
    Map<String, dynamic> data,
  ) async {
    calls.add({'operation': op, ...data});
    if (op == 'mutate' && failMutation) {
      failMutation = false;
      throw Exception('network');
    }
    if (op == 'mutate') return {'status': 'UPDATED'};
    if (op == 'detail')
      return {
        'id': 'fixture',
        'name': 'QA',
        'email': 'qa@example.invalid',
        'status': 'pending',
        'role': 'user',
      };
    if (op == 'overview')
      return {
        'users': 1,
        'services': [
          {'service': 'AssemblyAI', 'state': 'UNKNOWN'},
        ],
      };
    return {
      'items': [
        {'id': 'fixture', 'status': 'pending', 'role': 'user'},
      ],
      'source': 'synthetic',
      'sourceState': 'AVAILABLE',
      'total': 2,
      'nextCursor': data['cursor'] == null ? 'fixture' : null,
    };
  }
}

class PendingAttemptApi extends AdminOperationsApi {
  int calls = 0;
  final completion = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>> call(String op, Map<String, dynamic> data) {
    calls++;
    return completion.future;
  }
}

void main() {
  testWidgets(
    'attempt auto-refresh never overlaps a pending request and stops on dispose',
    (t) async {
      final api = PendingAttemptApi();
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: AdminOperationsSection(
              table: 'transcriptionAttempts',
              title: 'Tentativas',
              api: api,
            ),
          ),
        ),
      );
      await t.pump(const Duration(seconds: 90));
      expect(api.calls, 1);
      api.completion.complete({
        'items': <dynamic>[],
        'total': 0,
        'source': 'transcriptionAttempts',
      });
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 30));
      await t.pumpAndSettle();
      expect(api.calls, 2);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(minutes: 10));
      expect(api.calls, 2);
    },
  );

  testWidgets('Supervisor metadata view has no write controls', (t) async {
    final api = FakeApi();
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: AdminOperationsSection(
            table: 'users',
            title: 'Users',
            api: api,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Papel'), findsNothing);
    expect(find.text('Atualizar status'), findsNothing);
    expect(find.text('Ver'), findsOneWidget);
  });
  testWidgets('server cursor and exact search sent to backend', (t) async {
    final api = FakeApi();
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: AdminOperationsSection(
            table: 'users',
            title: 'Users',
            api: api,
          ),
        ),
      ),
    );
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
  testWidgets('section transition loads new source without stale user data', (
    t,
  ) async {
    final api = FakeApi();
    Future<void> show(String table) async {
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: AdminOperationsSection(table: table, title: table, api: api),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    await show('users');
    await show('health');
    expect(api.calls.last['operation'], 'overview');
    expect(find.textContaining('AssemblyAI'), findsOneWidget);
  });
  testWidgets('ambiguous retry reuses exact mutation request', (t) async {
    final api = FakeApi()..failMutation = true;
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: AdminOperationsSection(
            table: 'users',
            title: 'Users',
            readOnly: false,
            api: api,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Ver'));
    await t.tap(find.text('Ver'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Atualizar status'));
    await t.tap(find.text('Atualizar status'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'Synthetic support');
    await t.tap(find.text('Confirmar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Fechar'));
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
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: AdminOperationsSection(
            table: 'campaigns',
            title: 'Campaigns',
            readOnly: false,
            api: api,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Nova campanha'), findsOneWidget);
    expect(find.text('Enviar'), findsNothing);
  });
}
