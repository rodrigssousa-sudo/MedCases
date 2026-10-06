import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/transcription_diagnostics.dart';
import 'package:medcases/services/audio/recording_derived_audio.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/screens/durable_recording_screen.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
 TestWidgetsFlutterBinding.ensureInitialized();
 test('unchanged server 200 cannot reset no-progress deadline', () {
  var time=DateTime.utc(2026);final w=TranscriptionProgressWatch(now:()=>time);
  w.observe('0:processing',completed:0,stage:'processing');
  for(var i=0;i<6;i++) {time=time.add(const Duration(seconds:16));w.observe('0:processing',completed:0,stage:'processing');}
  expect(w.stalled,true);
  w.observe('1:done',completed:1,stage:'done');expect(w.stalled,false);
  expect(w.lastCompletedSegmentCount,1);
 });
 test('backoff bounded at 30 seconds',(){final w=TranscriptionProgressWatch();expect(List.generate(7,(_)=>w.nextDelay().inSeconds),[2,4,8,16,30,30,30]);});
 test('errors remain typed without provider details',(){expect(TranscriptionFailure.classify(const SocketException('private')).code,'NETWORK_FAILURE');expect(TranscriptionFailure.classify(TimeoutException('private')).code,'TIMEOUT');expect(TranscriptionFailure.classify(StateError('status_401')).code,'AUTH_FAILURE');expect(TranscriptionFailure.classify(StateError('audio_missing')).retryable,false);});
 test('canonical PCM duration includes every frame, not display clock',(){
  final b=Uint8List(44+24000*2*15);final d=ByteData.sublistView(b);
  void text(int n,String s)=>b.setRange(n,n+s.length,s.codeUnits);
  text(0,'RIFF');text(8,'WAVEfmt ');text(36,'data');
  d.setUint32(16,16,Endian.little);d.setUint16(20,1,Endian.little);d.setUint32(24,24000,Endian.little);d.setUint16(32,2,Endian.little);d.setUint32(40,b.length-44,Endian.little);
  expect(transcriptionMediaDurationMs(b),15000);d.setUint32(40,b.length,Endian.little);expect(()=>transcriptionMediaDurationMs(b),throwsFormatException);
 });
 test('privacy timing rejects arbitrary contents',(){final job=<String,dynamic>{};markTranscriptionTime(job,'T0');expect(job['timings']['T0'],isA<int>());expect(()=>markTranscriptionTime(job,'patient text'),throwsArgumentError);});

 late Directory root;late RecordingSessionController c;late Capture capture;
 setUp(()async{SharedPreferences.setMockInitialValues({});root=await Directory.systemTemp.createTemp('recorder-perf-');capture=Capture();c=RecordingSessionController(currentUid:()=> 'test',storageRoot:()async=>root,captureFactory:()=>capture,authorize:(_)async{},automaticTicks:false);});
 tearDown(()async{c.dispose();await root.delete(recursive:true);});
 test('cancel network wait responds immediately and late result cannot complete session',()async{
  await c.start(language:'es',mode:'study');await c.stop();
  final network=Completer<String>(),entered=Completer<void>();
  final run=c.transcribe((s,p)async{entered.complete();return network.future;});
  final error=expectLater(run,throwsA(isA<TranscriptionFailure>()));await entered.future;
  await c.cancelTranscription().timeout(const Duration(seconds:1));await error;
  expect(c.processing,false);expect(c.session!.transcriptionState,'pending');
  expect(await File(capture.path!).readAsBytes(),[1,2,3]);
  await c.transcribe((s,p)async=>'new synthetic result');
  network.complete('old synthetic result');await Future<void>.delayed(Duration.zero);
  expect(c.session!.transcript,'new synthetic result');
 });
 test('retry clears historical error before entering processing',()async{
  await c.start(language:'pt',mode:'study');await c.stop();
  await expectLater(c.transcribe((s,p)async=>throw const SocketException('offline')),throwsA(isA<SocketException>()));
  await c.transcribe((s,p)async{expect(s.lastErrorCategory,isNull);expect(s.recoveryAvailable,false);return 'synthetic';});
 });
 testWidgets('processing navigation remains immediately available; cards removed',(tester)async{
  await tester.runAsync(()async{await c.start(language:'es',mode:'study');await c.stop();});
  c.session!.phase=RecordingPhase.transcribing;c.session!.transcriptionState='processing';
  final nav=GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(navigatorKey:nav,home:const Scaffold(body:Text('Home'))));
  nav.currentState!.push(MaterialPageRoute<void>(builder:(_)=>DurableRecordingScreen(isEs:true,mode:'study',controller:c)));
  await tester.pump();await tester.pump(const Duration(milliseconds:400));
  expect(find.text('IA de la sesión'),findsNothing);expect(find.text('Sesión guardada'),findsNothing);
  await tester.tap(find.byTooltip('Volver sin interrumpir'));await tester.pump();await tester.pump(const Duration(milliseconds:400));
  expect(find.text('Home'),findsOneWidget);expect(c.processing,true);
 });
}
