import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/admin_v2/admin_dashboard_section.dart';
import 'package:medcases/screens/admin_v2/admin_operations_section.dart';
import 'package:medcases/screens/admin_v2/admin_visual_widgets.dart';
import 'package:medcases/screens/admin_v2/control_center_section.dart';

class VisualApi extends AdminOperationsApi {
  final calls = <Map<String, dynamic>>[];
  final user = <String, dynamic>{
    'id': 'hidden-uid',
    'name': 'QA Visual',
    'email': 'visual@example.invalid',
    'plan': 'free',
    'entitlementLabel': 'FREE',
    'status': 'approved'
  };
  @override
  Future<Map<String, dynamic>> call(String op, Map<String, dynamic> p) async {
    calls.add({'op': op, ...p});
    if (op == 'detail')
      return {
        ...user,
        'manualAvailableSeconds': 600,
        'manualConsumedMs': 120000
      };
    if (op == 'metrics')
      return {
        'total': 10,
        'premium': 3,
        'free': 7,
        'modes': {'study': 4},
        'observedAt': 1790688066779,
        'series': [
          {
            'date': '2026-09-29',
            'growth': 2,
            'requests': 4,
            'consumedMinutes': 6
          }
        ]
      };
    return {
      'items': [user],
      'total': 1
    };
  }
}

class CreditApi extends AdminControlApi {
  final writes = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(String op, Map<String, dynamic> p) async {
    if (op == 'mutate') writes.add(p);
    return {'items': <dynamic>[]};
  }
}

void main() {
  testWidgets(
      'desktop and tablet dashboard render real series and explicit unavailable data',
      (t) async {
    for (final width in [1440.0, 768.0]) {
      await t.binding.setSurfaceSize(Size(width, 1000));
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: AdminDashboardSection(
                      key: ValueKey(width), api: VisualApi())))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      final charts = t.widgetList<AdminChart>(find.byType(AdminChart)).toList();
      expect(
          charts.firstWhere((x) => x.title == 'Consumo de transcrição').values,
          {'09-29': 6.0});
      expect(charts.firstWhere((x) => x.title == 'Custo acumulado').values,
          isEmpty);
    }
    await t.binding.setSurfaceSize(null);
  });
  testWidgets(
      'user detail grants selected user without UID entry and hides metadata initially',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final api = VisualApi(), credits = CreditApi();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminOperationsSection(
                table: 'users',
                title: 'Usuários',
                readOnly: false,
                api: api,
                creditApi: credits))));
    await t.pumpAndSettle();
    expect(find.text('hidden-uid'), findsNothing);
    await t.tap(find.text('Ver'));
    await t.pumpAndSettle();
    await t.tap(find.text('Conceder tempo'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'UID do usuário'), findsNothing);
    expect(find.text('Expiração opcional'), findsOneWidget);
    await t.enterText(
        find.widgetWithText(TextField, 'Minutos adicionais'), '5');
    await t.enterText(
        find.widgetWithText(TextField, 'Justificativa obrigatória'),
        'QA visual sintética');
    await t.tap(find.text('Confirmar concessão'));
    await t.pumpAndSettle();
    expect(credits.writes.single['userId'], 'hidden-uid');
    expect(credits.writes.single['amountSeconds'], 300);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'Master can manage manual Premium with selected identity and reason',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final api = VisualApi();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AdminOperationsSection(
                table: 'users',
                title: 'Usuários',
                readOnly: false,
                master: true,
                api: api))));
    await t.pumpAndSettle();
    await t.tap(find.text('Ver'));
    await t.pumpAndSettle();
    await t.tap(find.text('Gerenciar Premium'));
    await t.pumpAndSettle();
    await t.enterText(
        find.widgetWithText(TextField, 'Justificativa obrigatória'),
        'QA manual access');
    await t.tap(find.text('Confirmar acesso'));
    await t.pumpAndSettle();
    final mutation = api.calls.lastWhere((r) => r['op'] == 'mutate');
    expect(mutation['action'], 'setManualPremium');
    expect(mutation['targetId'], 'hidden-uid');
    expect(mutation['enabled'], true);
    expect(t.takeException(), isNull);
  });
  testWidgets('record overview hides technical IDs and exposes readable dates and stages', (t) async {
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AdminRecordDetail({
      'id': 'hidden-record-id', 'userName': 'QA', 'state': 'COMPLETED',
      'durationMs': 60000, 'createdAt': 1790688066779,
      'timeline': [{'stage': 'TRANSCRIPT_PERSISTED', 'at': 1790688066779}],
    })))));
    await t.pumpAndSettle();
    expect(find.text('hidden-record-id'), findsNothing);
    expect(find.text('Concluído'), findsOneWidget);
    expect(find.text('Transcrição salva'), findsOneWidget);
    expect(find.text('1.0 min'), findsOneWidget);
    expect(find.text('1790688066779'), findsNothing);
  });
  test('dates and operations are human readable', () {
    expect(adminDate(1790688066779), isNot(contains('1790688066779')));
    expect(adminLabel('markNotificationRead'), 'Notificação marcada como lida');
  });
}
