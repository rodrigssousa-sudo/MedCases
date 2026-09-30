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

class DenseInventoryApi extends InventoryApi {
  @override
  Future<Map<String, dynamic>> call(
      String op, Map<String, dynamic> payload) async {
    final result = await super.call(op, payload);
    final sample = (result['rows'] as List?)?.first;
    if (sample == null) return result;
    return {
      ...result,
      'rows': List.generate(
          25,
          (i) => {
                ...Map<String, dynamic>.from(sample as Map),
                'displayName': 'Item $i',
                'canonicalId': 'technical-secret-id-$i',
              })
    };
  }
}

void main() {
  testWidgets(
      'both inventories show eight complete rows with compact pinned toolbar',
      (t) async {
    await t.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    for (final kind in ['drugs', 'pathologies']) {
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        const SizedBox(height: 110),
        Expanded(
            child: ContentInventorySection(
                key: ValueKey(kind), kind: kind, api: DenseInventoryApi())),
      ]))));
      await t.pumpAndSettle();
      for (var i = 0; i < 8; i++) {
        final rect = t.getRect(find.byKey(ValueKey('inventory-row-$i')));
        expect(rect.height, 56);
        expect(rect.bottom, lessThanOrEqualTo(856));
      }
      expect(find.textContaining('technical-secret-id'), findsNothing);
      final top = t.getTopLeft(find.byType(TextField));
      await t.drag(
          find.byKey(const ValueKey('inventory-row-4')), const Offset(0, -350));
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.byType(TextField)), top);
      expect(t.takeException(), isNull);
    }
  });
  testWidgets('tablet inventory remains usable without layout overflow',
      (t) async {
    await t.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ContentInventorySection(
                kind: 'drugs', api: DenseInventoryApi()))));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Item 0'), findsOneWidget);
  });
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
