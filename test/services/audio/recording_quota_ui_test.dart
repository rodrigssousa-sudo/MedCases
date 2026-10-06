import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/screens/durable_recording_screen.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/transcription_quota.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

TranscriptionQuota balance(int available,
        {String period = '2026-10', int allowanceMinutes = 35}) =>
    TranscriptionQuota(
        owner: 'qa',
        period: period,
        premium: false,
        allowanceMs: allowanceMinutes * 60000,
        usedMs: (allowanceMinutes - available) * 60000,
        reservedMs: 0,
        remainingMs: available * 60000);

// Metadata recovery is orthogonal; use the real quota/controller/view path.
class UiController extends RecordingSessionController {
  UiController(Directory root, Future<TranscriptionQuota> Function() read)
      : super(
            currentUid: () => 'qa',
            storageRoot: () async => root,
            captureFactory: Capture.new,
            authorize: (_) async {},
            resolveQuota: read,
            automaticTicks: false);
  @override
  Future<void> open({String? requestedSessionId}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('quota-ui-');
  });
  tearDown(() async => root.delete(recursive: true));

  test('UI_CACHE_REFRESH: late 15 cannot overwrite newer 35', () async {
    final old = Completer<TranscriptionQuota>(),
        fresh = Completer<TranscriptionQuota>();
    var reads = 0;
    final c =
        UiController(root, () => ++reads == 1 ? old.future : fresh.future);
    try {
      final a = c.refreshQuota(), b = c.refreshQuota();
      fresh.complete(balance(35));
      await b;
      old.complete(balance(15));
      await a;
      expect(c.quota!.remainingTime, '35:00');
    } finally {
      c.dispose();
    }
  });

  for (final item in [
    ('UI_FREE_BASE_ONLY', 15),
    ('UI_FREE_WITH_EXTRA_20', 35),
    ('UI_FREE_WITH_PARTIALLY_USED_EXTRA', 10)
  ]) {
    testWidgets(item.$1, (tester) async {
      final c = UiController(
          root,
          () async => balance(item.$2,
              allowanceMinutes: item.$1 == 'UI_FREE_BASE_ONLY' ? 15 : 35));
      await tester.pumpWidget(MaterialApp(
          home: DurableRecordingScreen(
              isEs: false, mode: 'study', controller: c)));
      await tester.pump();
      await tester.pump();
      expect(
          find.text('Transcrição disponível: ${item.$2}:00'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
  for (final scenario in ['UI_AFTER_DAY_CHANGE', 'UI_AFTER_MONTH_BOUNDARY']) {
    testWidgets(scenario, (tester) async {
      var value = balance(20);
      final c = UiController(root, () async => value);
      await tester.pumpWidget(MaterialApp(
          home: DurableRecordingScreen(
              isEs: true, mode: 'study', controller: c)));
      await tester.pump();
      await tester.pump();
      expect(find.text('Transcripción disponible: 20:00'), findsOneWidget);
      // Only the server determines rollover; the client formats its response.
      value = scenario == 'UI_AFTER_MONTH_BOUNDARY'
          ? balance(35, period: '2026-11')
          : balance(20);
      await c.refreshQuota();
      await tester.pump();
      expect(find.text('Transcripción disponible: ${value.remainingTime}'),
          findsOneWidget);
      expect(c.quota!.period, value.period);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
  testWidgets(
      'UI_AFTER_APP_RESTART reads effective balance instead of base cache',
      (tester) async {
    for (var i = 0; i < 2; i++) {
      final displayed = i == 0 ? 15 : 35;
      final c = UiController(root, () async => balance(displayed));
      await tester.pumpWidget(MaterialApp(
          home: DurableRecordingScreen(
              isEs: false, mode: 'study', controller: c)));
      await tester.pump();
      await tester.pump();
      expect(
          find.text('Transcrição disponível: $displayed:00'), findsOneWidget);
      if (i == 1)
        expect(find.text('Transcrição disponível: 15:00'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    }
  });
  testWidgets(
      'UI_CACHE_REFRESH shows pending, then fresh balance without old fallback',
      (tester) async {
    var value = Future.value(balance(15));
    final c = UiController(root, () => value);
    await tester.pumpWidget(MaterialApp(
        home:
            DurableRecordingScreen(isEs: false, mode: 'study', controller: c)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Transcrição disponível: 15:00'), findsOneWidget);
    final pending = Completer<TranscriptionQuota>();
    value = pending.future;
    final refresh = c.refreshQuota();
    await tester.pump();
    expect(find.text('Transcrição disponível: 15:00'), findsNothing);
    expect(find.text('Atualizando saldo de transcrição…'), findsOneWidget);
    pending.complete(balance(35));
    await refresh;
    await tester.pump();
    expect(find.text('Transcrição disponível: 35:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  for (final action in [
    'UI_TRANSCRIPTION_BALANCE_WHILE_CAPTURE_UNLIMITED',
    'UI_TRANSCRIPTION_REFRESH_WHILE_RESUME_UNLIMITED'
  ]) {
    testWidgets(action, (tester) async {
      var value = balance(35);
      final c = (await tester
          .runAsync(() async => UiController(root, () async => value)))!;
      await tester.pumpWidget(MaterialApp(
          home: DurableRecordingScreen(
              isEs: false, mode: 'study', controller: c)));
      await tester.pump();
      await tester.pump();
      await tester.runAsync(() => c.start(language: 'pt', mode: 'study'));
      if (action == 'UI_TRANSCRIPTION_REFRESH_WHILE_RESUME_UNLIMITED') {
        await tester.runAsync(c.pause);
        value = balance(25);
        await tester.runAsync(c.resume);
      }
      await tester.pump();
      await tester.runAsync(c.refreshQuota);
      await tester.pump();
      expect(c.durationPolicy.unlimited, true);
      expect(c.quota!.remainingMs, value.remainingMs);
      expect(find.text('Transcrição disponível: ${c.quota!.remainingTime}'),
          findsOneWidget);
      await tester.runAsync(c.stop);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
  test('old refresh failure cannot erase newer accepted quota', () async {
    final old = Completer<TranscriptionQuota>();
    var reads = 0;
    final c = UiController(
        root, () => ++reads == 1 ? old.future : Future.value(balance(35)));
    try {
      final a = c.refreshQuota();
      await c.refreshQuota();
      old.completeError(StateError('offline'));
      await a;
      expect(c.quota!.remainingTime, '35:00');
    } finally {
      c.dispose();
    }
  });
  testWidgets(
      'UI incident balance includes intact extra after base consumption',
      (tester) async {
    final c = UiController(
        root,
        () async => TranscriptionQuota.parse('qa', {
              'month': '2026-10',
              'tier': 'free',
              'allowanceMs': 2100000,
              'usedMs': 899968,
              'reservedMs': 0,
              'remainingMs': 1200032,
            }));
    await tester.pumpWidget(MaterialApp(
        home:
            DurableRecordingScreen(isEs: false, mode: 'study', controller: c)));
    await tester.pump();
    await tester.pump();
    expect(c.quota!.remainingMs, 1200032);
    expect(find.text('Transcrição disponível: 20:01'), findsOneWidget);
    expect(find.text('Transcrição disponível: 15:00'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
