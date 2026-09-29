import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/admin_v2/admin_operations_section.dart';
import 'package:medcases/screens/admin_v2/admin_notifications_section.dart';

class NotificationsApi extends AdminOperationsApi {
  final read = <String>{};
  final writes = <Map<String, dynamic>>[];
  Completer<Map<String, dynamic>>? delayedPage;
  bool failAfterWrite = false;
  Map<String, dynamic> page() => {
        'items': [
          for (final id in ['one', 'two'])
            {'notificationId': id, 'title': id, 'read': read.contains(id)}
        ],
        'unreadCount': 2 - read.length,
        'nextCursor': null
      };
  @override
  Future<Map<String, dynamic>> call(
      String op, Map<String, dynamic> data) async {
    if (op == 'notificationPage')
      return delayedPage?.future ?? Future.value(page());
    writes.add(Map.from(data));
    if (data['all'] == true) {
      read.addAll(['one', 'two']);
    } else {
      read.add(data['notificationId'] as String);
    }
    if (failAfterWrite) {
      failAfterWrite = false;
      throw Exception('network');
    }
    return {
      'readIds': read.toList(),
      'unreadCount': 2 - read.length,
      'nextCursor': null
    };
  }
}

Future<void> mount(WidgetTester t, NotificationsApi api) async {
  await t.pumpWidget(MaterialApp(
      home: Scaffold(
          body: AdminNotificationsSection(readOnly: false, api: api))));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('A E single read removes only selected row and updates badge',
      (t) async {
    final api = NotificationsApi();
    await mount(t, api);
    await t.tap(find.text('Marcar como lida').first);
    await t.pumpAndSettle();
    expect(find.text('one'), findsNothing);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('Não lidas: 1'), findsOneWidget);
  });
  testWidgets('B C ALL shows read state after refresh and new session',
      (t) async {
    final api = NotificationsApi();
    await mount(t, api);
    await t.tap(find.text('Marcar como lida').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Todas'));
    await t.pumpAndSettle();
    expect(find.text('one'), findsOneWidget);
    expect(find.text('Marcar como lida'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Lida'), findsOneWidget);
    await t.tap(find.byTooltip('Atualizar'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(Chip, 'Lida'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await mount(t, api);
    expect(find.text('one'), findsNothing);
  });
  testWidgets(
      'D double click sends one request; network retry keeps request ID',
      (t) async {
    final api = NotificationsApi()..failAfterWrite = true;
    await mount(t, api);
    final button = find.text('Marcar como lida').first;
    await t.tap(button);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(api.writes.length, 1);
    await t.tap(find.text('Confirmar leitura pendente'));
    await t.pumpAndSettle();
    expect(api.writes[0]['requestId'], api.writes[1]['requestId']);
    expect(find.text('Não lidas: 1'), findsOneWidget);
  });
  testWidgets('F mark all clears list and badge', (t) async {
    final api = NotificationsApi();
    await mount(t, api);
    await t.tap(find.text('Marcar todas como lidas'));
    await t.pumpAndSettle();
    expect(find.text('one'), findsNothing);
    expect(find.text('two'), findsNothing);
    expect(find.text('Não lidas: 0'), findsOneWidget);
  });
  testWidgets('G delayed page response cannot overwrite confirmed mutation',
      (t) async {
    final api = NotificationsApi();
    await mount(t, api);
    final old = api.page();
    api.delayedPage = Completer();
    await t.tap(find.byTooltip('Atualizar'));
    await t.pump();
    await t.tap(find.text('Marcar como lida').first);
    await t.pump();
    api.delayedPage!.complete(old);
    await t.pumpAndSettle();
    expect(find.text('one'), findsNothing);
    expect(find.text('Não lidas: 1'), findsOneWidget);
  });
}
