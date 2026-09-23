import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/user_model.dart';
import 'package:medcases/screens/support_ticket_screen.dart';
import '../guides/guide_runtime_fixture.dart';

class _SupportProvider extends GuideAppProvider {
  _SupportProvider() : super('pt');
  @override
  UserModel get currentUser => UserModel(
      uid: 'runtime-test',
      email: '',
      displayName: 'CAMPO_TESTE',
      createdAt: DateTime.utc(2026));
}

Future<void> verifySupportSuccess(WidgetTester tester) async {
  final io = await GuideHarness.open(tester);
  final store = io.store;
  final provider = _SupportProvider();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
    io.provider.dispose();
  });
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SupportTicketScreen(p: provider, dark: true))));
  await tester.pumpAndSettle();
  final field = find.byType(TextField);
  await tester.ensureVisible(field);
  await tester.enterText(field, 'CAMPO_TESTE');
  final button = find.text('Enviar ao suporte');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
  expect(store.writes, hasLength(1));
  expect(store.writes.single['userId'], 'runtime-test');
  expect(store.writes.single['message'], 'CAMPO_TESTE');
  expect(store.writes.single['status'], 'new');
  expect(store.writes.single['path'], startsWith('support_tickets/MC-'));
  final confirmation = find.textContaining('Solicitação enviada · MC-');
  await tester.ensureVisible(confirmation);
  expect(confirmation, findsOneWidget);
  expect(
      tester.widget<Text>(confirmation).style!.color, const Color(0xFF0D6B57));
  expect(tester.widget<TextField>(field).controller!.text, isEmpty);
  expect(tester.takeException(), isNull);
}
