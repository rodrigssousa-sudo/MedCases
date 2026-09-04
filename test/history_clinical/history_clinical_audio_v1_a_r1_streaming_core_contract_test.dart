import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String readSource(String path) => File(path).readAsStringSync();

String methodSlice(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  if (startIndex < 0 || endIndex < 0) {
    throw StateError('Unable to slice $start → $end');
  }
  return source.substring(startIndex, endIndex);
}

void main() {
  late String helper;
  late String mobile;
  late String web;
  late String stub;
  late String recorder;

  setUpAll(() {
    helper = readSource('lib/services/stt_helper.dart');
    mobile = readSource('lib/services/stt_helper_mobile.dart');
    web = readSource('lib/services/stt_helper_web.dart');
    stub = readSource('lib/services/stt_helper_stub.dart');
    recorder = readSource('lib/services/clinical_recorder_service.dart');
  });

  test('public STT contract exposes optional partial results compatibly', () {
    for (final source in <String>[helper, mobile, web, stub]) {
      expect(
        source,
        contains('void Function(String text)? onPartialResult'),
      );
    }
    expect(helper, contains('onPartialResult: onPartialResult'));
  });

  test('mobile provider replaces partial hypotheses and guards old sessions',
      () {
    expect(mobile, contains('partialResults: true'));
    expect(mobile, contains('_onPartialResultCb?.call(words);'));
    expect(mobile, contains('sessionEpoch != _activeSessionEpoch'));
    expect(mobile, contains('bool _terminalDelivered = false;'));
    expect(
      mobile,
      contains('onResult: (result) => _handleResult(result, sessionEpoch)'),
    );
    expect(mobile, isNot(contains('onResult: "\$words"')));
  });

  test('web provider forwards partial and final without repeated terminal', () {
    expect(web, contains('onPartialResult?.call(transcript);'));
    expect(
        web, contains('if (ended || sessionEpoch != _sessionEpoch) return;'));
    expect(web, contains('finishEnd();'));
  });

  test('clinical recorder owns one restart and reconciles partial to final',
      () {
    expect(recorder, contains("String _partialTranscript = '';"));
    expect(recorder, contains('int _sessionEpoch = 0;'));
    expect(recorder, contains('Timer? _restartTimer;'));
    expect(recorder, contains('onPartialResult: (text)'));
    expect(recorder, contains('_partialTranscript = partial;'));
    expect(recorder, contains('_commitFinal(epoch, text);'));
    expect(recorder, contains('_scheduleRestart('));
    expect(recorder, contains('_rotateSession(epoch)'));
    expect(recorder, isNot(contains('_sessionBuffer')));
    expect(recorder, isNot(contains('Future.delayed(')));
  });

  test('pause and stop keep the session valid until provider finalization', () {
    final pause = methodSlice(
      recorder,
      '  void pause()',
      '  void resume()',
    );
    final stop = methodSlice(
      recorder,
      '  Future<String> stop()',
      '  // ─────────────────────────────────────────────────────────────────────────\n  // dispose()',
    );

    expect(pause, contains('_pauseStopInFlight = true;'));
    expect(pause, contains('await SttHelper.stop();'));
    expect(stop, contains('await SttHelper.stop();'));
    expect(stop.indexOf('await SttHelper.stop();'),
        lessThan(stop.indexOf('_sessionEpoch++;')));
  });

  test('dispose invalidates callbacks before closing streams', () {
    final dispose = methodSlice(
      recorder,
      '  void dispose()',
      '  // ── Internals',
    );
    expect(dispose, contains('_disposed = true;'));
    expect(dispose, contains('_sessionEpoch++;'));
    expect(dispose, contains('unawaited(SttHelper.stop());'));
    expect(dispose, contains('_transcriptCtrl.close()'));
  });

  test('PT and ES locale selection remains synchronized with app language', () {
    expect(
      recorder,
      contains(
          "_currentLang.toLowerCase().startsWith('es') ? 'es-ES' : 'pt-BR'"),
    );
  });
}
