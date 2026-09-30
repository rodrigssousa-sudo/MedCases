import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/admin_v2/content_inventory_section.dart';
import 'package:medcases/screens/admin_v2/admin_operations_section.dart';

class InventoryApi extends AdminOperationsApi {
  final calls = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> call(
      String operation, Map<String, dynamic> payload) async {
    calls.add({'operation': operation, ...payload});
    if (payload['action'] == 'history')
      return {
        'runs': [
          {'state': 'COMPLETE', 'itemsRead': 1}
        ]
      };
    return {
      'generation': 'a' * 40,
      'meta': {
        'syncState': 'SYNCED',
        'counts': {'total': 1, 'ptEs': 1}
      },
      'rows': [
        {
          'recordId': 'b' * 40,
          'canonicalId': 'fixture',
          'displayName': 'Exemplo',
          'namePt': 'Exemplo',
          'nameEs': 'Ejemplo',
          'ptAvailable': true,
          'esAvailable': true,
          'status': 'UNKNOWN',
          'withoutReview': true,
          'queueReasons': ['NEEDS_REVIEW']
        }
      ],
      'nextCursor': payload['cursor'] == null ? 'b' * 40 : null
    };
  }
}

void main() {
  Future<void> setup(WidgetTester t, InventoryApi api) async {
    await t.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
        home:
            Scaffold(body: ContentInventorySection(kind: 'drugs', api: api))));
    await t.pumpAndSettle();
  }

  testWidgets('metadata cards and detail are read only', (t) async {
    final api = InventoryApi();
    await setup(t, api);
    expect(find.text('Exemplo'), findsOneWidget);
    expect(find.text('Total: 1'), findsOneWidget);
    await t.tap(find.text('Exemplo'));
    await t.pumpAndSettle();
    expect(find.text('Copiar ID'), findsOneWidget);
    expect(find.text('Abrir fonte'), findsOneWidget);
    expect(find.text('Salvar'), findsNothing);
    expect(find.text('Aprovar'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('search and pagination go to authenticated backend', (t) async {
    final api = InventoryApi();
    await setup(t, api);
    await t.enterText(find.byType(TextField), 'Exemplo');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(api.calls.last['search'], 'Exemplo');
    await t.tap(find.text('Próxima'));
    await t.pumpAndSettle();
    expect(api.calls.last['cursor'], 'b' * 40);
    expect(api.calls.last['generation'], 'a' * 40);
  });
  testWidgets('sync history remains metadata only', (t) async {
    final api = InventoryApi();
    await setup(t, api);
    await t.tap(find.text('Histórico de sync'));
    await t.pumpAndSettle();
    expect(find.text('COMPLETE · 1 itens'), findsOneWidget);
  });
}
