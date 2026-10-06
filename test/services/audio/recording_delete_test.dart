import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/audio/recording_session_controller.dart';
import 'package:medcases/services/audio/recording_deletion_store.dart';
import 'reconstruction_recording_owner_test.dart' show Capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late RecordingSessionController controller;
  late Capture capture;
  String? owner;
  var counter = 0;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    owner = 'delete-owner-${counter++}';
    RecordingDeletionStore.ownerOverride = () => owner;
    root = await Directory.systemTemp.createTemp('delete1709-test-');
    capture = Capture();
    controller = RecordingSessionController(
        currentUid: () => owner,
        storageRoot: () async => root,
        captureFactory: () => capture,
        authorize: (_) async {},
        automaticTicks: false);
  });
  tearDown(() async {
    controller.dispose();
    RecordingDeletionStore.ownerOverride = null;
    await root.delete(recursive: true);
  });
  Future<String> recorded() async {
    await controller.start(language: 'pt', mode: 'study');
    await controller.stop();
    return controller.session!.sessionId;
  }

  test(
      'cancel confirmation preserves files; explicit delete removes only owned directory',
      () async {
    final id = await recorded();
    final directory = File(capture.path!).parent;
    await File('${directory.path}/derived.wav').writeAsBytes([1]);
    await File('${directory.path}/checkpoint.json').writeAsString('{}');
    final other = File('${root.path}/other-session/master.m4a');
    await other.parent.create(recursive: true);
    await other.writeAsBytes([2]);
    await controller.deleteRecording(id, confirmed: false);
    expect(await directory.exists(), true);
    await controller.deleteRecording(id,
        confirmed: true, cleanup: (_) async => throw StateError('offline'));
    expect(await directory.exists(), false);
    expect(await other.readAsBytes(), [2]);
    expect(await RecordingDeletionStore.state(owner!, id), 'deleted');
  });
  test('active recording cannot be deleted', () async {
    await controller.start(language: 'es', mode: 'study');
    await expectLater(
        controller.deleteRecording(controller.session!.sessionId,
            confirmed: true),
        throwsStateError);
    expect(await File(capture.path!).exists(), true);
    await controller.stop();
  });
  test('foreign UID cannot delete original owner audio', () async {
    final id = await recorded();
    final file = File(capture.path!);
    owner = 'different';
    await expectLater(
        controller.deleteRecording(id, confirmed: true), throwsStateError);
    expect(await file.exists(), true);
  });
  test('failed disk erase remains blocked, explicit retry completes', () async {
    final id = await recorded();
    await expectLater(
        controller.deleteRecording(id,
            confirmed: true,
            cleanup: (_) async {},
            eraseOverride: (_) async => throw FileSystemException('test')),
        throwsA(isA<FileSystemException>()));
    expect(await RecordingDeletionStore.state(owner!, id), 'deleting');
    expect(await File(capture.path!).exists(), true);
    await controller.deleteRecording(id,
        confirmed: true, cleanup: (_) async {});
    expect(await File(capture.path!).exists(), false);
  });
  test('late provider result cannot resurrect deleted session or notify',
      () async {
    final id = await recorded();
    final pending = Completer<String>();
    final entered = Completer<void>();
    final future = controller.transcribe((_, __) async {
      entered.complete();
      return pending.future;
    });
    final outcome = expectLater(future, throwsA(anything));
    await entered.future;
    await controller.deleteRecording(id,
        confirmed: true, cleanup: (_) async {});
    pending.complete('synthetic late result');
    await outcome;
    expect(controller.session, isNull);
    expect(await File(capture.path!).exists(), false);
    expect(controller.completion.value, isNull);
  });
}
