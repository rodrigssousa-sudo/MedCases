import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/screens/durable_recording_screen.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/audio/transcription_diagnostics.dart';
import 'package:medcases/services/server_usage_authority.dart';
import 'package:medcases/services/transcription_quota.dart';
import 'package:medcases/services/study/recorded_study_transcription.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late RecordingSessionController service;
  late DateTime now;
  var used = 1877296;
  var reserved = 3307078;
  var reads = 0;
  TranscriptionQuota balance() => TranscriptionQuota.parse('owner', {
    'month': '2026-09', 'tier': 'premium', 'allowanceMs': 5400000,
    'usedMs': used, 'reservedMs': reserved,
    'remainingMs': 5400000-used-reserved,
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('consolidated1709-');
    now = DateTime.utc(2026, 9, 26);
    used = 1877296; reserved = 3307078; reads = 0;
    service = RecordingSessionController(currentUid: () => 'owner',
      storageRoot: () async => root, captureFactory: () => Capture(),
      authorize: (_) async {}, now: () => now, automaticTicks: false,
      resolveQuota: () async { reads++; return balance(); });
  });
  tearDown(() async { service.dispose(); await root.delete(recursive: true); });

  test('provider block is preserved and preflight prevents any reserve HTTP call', () async {
    final calls = <String>[];
    final authority = ServerUsageAuthority(uid: () => 'owner', token: () async => 'synthetic',
      client: MockClient((request) async {
        calls.add(request.url.path);
        return http.Response(jsonEncode({'code': TranscriptionFailure.providerBlockedCode, 'retryable': false}),403);
      }));
    await expectLater(authority.reserve('owner', {'kinds': ['transcription'], 'maximumMs': 1000}),
      throwsA(isA<TranscriptionFailure>().having((e)=>e.code,'code',TranscriptionFailure.providerBlockedCode).having((e)=>e.retryable,'retryable',false)));
    expect(calls, ['/api/usage/eligibility']);
  });
  test('legacy receipt is forwarded for safe release and not recreated', () async {
    final authority = ServerUsageAuthority(uid: () => 'owner', token: () async => 'synthetic',
      client: MockClient((request) async {
        expect(request.headers['X-MedCases-Usage-Reservation'], 'a'*64);
        expect(request.headers['X-MedCases-Usage-Attempt'], 'attempt');
        return http.Response('{"eligible":true}',200);
      }));
    await authority.eligibility('owner', reservationHeaders: {'X-MedCases-Usage-Reservation':'a'*64,'X-MedCases-Usage-Attempt':'attempt'});
  });
  test('nonretryable persists across reopen, retains audio, refreshes balance', () async {
    await service.start(language:'pt',mode:'study'); await service.stop();
    final id = service.session!.sessionId;
    await expectLater(service.transcribe((_,__) async {
      reserved=0;
      throw const TranscriptionFailure(TranscriptionFailure.providerBlockedCode,retryable:false);
    }), throwsA(isA<TranscriptionFailure>()));
    expect(service.canTranscribe,false);
    expect(service.quota!.remainingTime,'58:43');
    expect(reads,greaterThanOrEqualTo(1));
    expect(await service.audioRetained(id),true);
    await service.openSession(id);
    expect(service.session!.transcriptionState,'terminalError');
    expect(service.canTranscribe,false);
  });
  test('retryable failure still permits retry without losing audio', () async {
    await service.start(language:'pt',mode:'study'); await service.stop();
    await expectLater(service.transcribe((_,__) async => throw const TranscriptionFailure('TIMEOUT')),throwsA(isA<TranscriptionFailure>()));
    expect(service.canTranscribe,true);
    expect(await service.transcribe((_,__) async => 'Synthetic result'),'Synthetic result');
  });
  for(final es in [false,true]) {
    testWidgets('one authoritative balance and no post-stop warning ${es?'ES':'PT'}', (tester) async {
      await tester.runAsync(() async { await service.start(language:es?'es':'pt',mode:'study'); await service.stop(); });
      service.session!.lastErrorCategory=TranscriptionFailure.providerBlockedCode;
      service.session!.transcriptionState='terminalError';
      service.session!.phase=RecordingPhase.recoverableError;
      await tester.pumpWidget(MaterialApp(home:DurableRecordingScreen(isEs:es,mode:'study',controller:service,onRecorded:(){})));
      await tester.runAsync(() async {}); await tester.pumpAndSettle();
      expect(find.text(es?'Transcripción disponible: 03:36':'Transcrição disponível: 03:36'),findsOneWidget);
      expect(find.textContaining('5 minutos restantes'),findsNothing);
      expect(find.text(es?'Reintentar':'Tentar novamente'),findsNothing);
      expect(find.text(TranscriptionFailure.unavailableMessage(isEs:es)),findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('capture warning is transient and removed when paused', (tester) async {
    reserved = 0;
    await tester.runAsync(() => service.start(language:'pt',mode:'study'));
    await tester.pumpWidget(MaterialApp(
      builder:(context, child) => MediaQuery(data:MediaQuery.of(context).copyWith(disableAnimations:true),child:child!),
      home:DurableRecordingScreen(isEs:false,mode:'study',controller:service)));
    await tester.runAsync(() async {}); await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3)); await tester.pumpAndSettle();
    service.session!.job['durationLimitMs'] = 300001;
    now = now.add(const Duration(seconds: 2));
    await tester.runAsync(() => service.tick()); await tester.pump(); await tester.pump(const Duration(milliseconds:300));
    expect(find.text('5 minutos restantes'),findsOneWidget);
    // Capture elapsed never replaces the endpoint's authoritative balance.
    expect(find.text('Transcrição disponível: 58:43'),findsOneWidget);
    await tester.runAsync(() => service.pause()); await tester.pumpAndSettle();
    expect(find.text('5 minutos restantes'),findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  test('legacy alias dedup retains ambiguous checkpoints and other owners', () async {
    final study=Study(id:'study',title:'Synthetic',locale:'pt',createdAtUtc:now,sources:[
      StudySource(id:'source',type:StudySourceType.recordedAudio,title:'Synthetic',state:StudySourceState.transcriptionPending,createdAtUtc:now,recordingSessionId:'session')]);
    final prefs=await SharedPreferences.getInstance();
    const key='medcases.recorded.pending.owner.study';
    final raw=jsonEncode({'sourceId':'source','sessionId':'session'});
    await prefs.setString(key,raw); await prefs.setString('$key.session','different');
    expect(await RecordedStudyTranscription.deduplicateLegacyAlias(prefs,study,'owner',()=> 'owner'),false);
    await prefs.setString('$key.session',raw);
    expect(await RecordedStudyTranscription.deduplicateLegacyAlias(prefs,study,'owner',()=> 'other'),false);
    expect(await RecordedStudyTranscription.deduplicateLegacyAlias(prefs,study,'owner',()=> 'owner'),true);
    expect(prefs.getString('$key.session'),raw); expect(prefs.containsKey(key),false);
    expect(await RecordedStudyTranscription.deduplicateLegacyAlias(prefs,study,'owner',()=> 'owner'),false);
  });
}
