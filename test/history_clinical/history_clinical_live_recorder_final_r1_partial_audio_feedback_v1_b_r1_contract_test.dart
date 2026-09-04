import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String slice(
  String source,
  String startToken,
  String endToken,
) {
  final start = source.indexOf(startToken);
  final end = source.indexOf(endToken, start + startToken.length);
  expect(start, greaterThanOrEqualTo(0), reason: startToken);
  expect(end, greaterThan(start), reason: endToken);
  return source.substring(start, end);
}

void main() {
  late String recorder;
  late String service;
  late String helper;
  late String mobile;
  late String web;

  setUpAll(() {
    recorder = read('lib/screens/clinical_recorder_sheet.dart');
    service = read('lib/services/clinical_recorder_service.dart');
    helper = read('lib/services/stt_helper.dart');
    mobile = read('lib/services/stt_helper_mobile.dart');
    web = read('lib/services/stt_helper_web.dart');
  });

  test('R1 recorder surfaces confirmed and partial transcript separately', () {
    for (final token in const <String>[
      'MEDCASES_HC_LIVE_RECORDER_FINAL_R1_V1_B_R1',
      "String _confirmedTranscript = '';",
      "String _partialTranscript = '';",
      '_confirmedTranscript = _recorder.fullTranscript;',
      '_partialTranscript = _recorder.partialTranscript;',
      'final confirmedText =',
      'final partialText =',
      'fontStyle: FontStyle.italic',
      'Se actualiza mientras habla.',
      'Atualiza enquanto você fala.',
      'La hipótesis se consolida automáticamente.',
      'A hipótese é consolidada automaticamente.',
    ]) {
      expect(recorder, contains(token), reason: token);
    }
  });

  test('R1 recorder consumes real normalized audio level', () {
    for (final token in const <String>[
      'StreamSubscription<double>? _soundLevelSub;',
      '_recorder.soundLevelStream.listen((level)',
      'final visibleSoundLevel =',
      'meterHeight(int index)',
      'AnimatedContainer(',
      'duration: const Duration(milliseconds: 90)',
    ]) {
      expect(recorder, contains(token), reason: token);
    }

    expect(
      recorder,
      contains('_soundLevelSub?.cancel();'),
    );
  });

  test('empty state is compact dynamic and localized', () {
    for (final token in const <String>[
      'Escuchando…',
      'Escutando…',
      'Grabación pausada',
      'Gravação pausada',
      'Hable normalmente con el paciente. El texto aparecerá aquí.',
      'Fale normalmente com o paciente. O texto aparecerá aqui.',
      'padding: const EdgeInsets.only(top: 12)',
      'BorderRadius.circular(8)',
    ]) {
      expect(recorder, contains(token), reason: token);
    }
  });

  test('live chip is demoted and heavy effects stay absent', () {
    final r1 = slice(
      recorder,
      '// MEDCASES_HC_LIVE_RECORDER_FINAL_R1_V1_B_R1',
      'class _ControlBtn',
    );

    expect(r1, contains('fontSize: 8.5'));
    expect(r1, contains("'EN VIVO'"));
    expect(r1, contains("'AO VIVO'"));
    expect(r1, isNot(contains('BoxShadow(')));
    expect(r1, isNot(contains('LinearGradient(')));
  });

  test('service adds observability without replacing transcript contract', () {
    for (final token in const <String>[
      'String get partialTranscript => _partialTranscript;',
      'final _soundLevelCtrl = StreamController<double>.broadcast();',
      'Stream<double> get soundLevelStream => _soundLevelCtrl.stream;',
      'onSoundLevelChange: (level)',
      'level.clamp(0.0, 1.0).toDouble()',
      '_soundLevelCtrl.add(normalized);',
      '_soundLevelCtrl.close();',
      'Stream<String> get transcriptStream => _transcriptCtrl.stream;',
    ]) {
      expect(service, contains(token), reason: token);
    }
  });

  test('partial final STT algorithms remain canonical', () {
    expect(helper, contains('void Function(String text)? onPartialResult'));
    expect(helper, contains('void Function(double level)? onSoundLevelChange'));
    expect(mobile, contains('partialResults: true'));
    expect(mobile, contains('ListenMode.dictation'));
    expect(mobile, contains('_onPartialResultCb?.call(words);'));
    expect(mobile, contains('sessionEpoch != _activeSessionEpoch'));
    expect(web, contains('onPartialResult?.call(transcript);'));
  });

  test('processing and SOAP callbacks remain wired', () {
    for (final token in const <String>[
      '_finishRecording',
      '_togglePause',
      '_nextSoapBlock',
      'SoapAiProcessor.structure(finalText, lang: widget.lang)',
      'widget.onSoapData(confirmed);',
      '_isProcessing || !hasTranscript',
      'controller: _scrollCtrl',
      '_scrollCtrl.animateTo(',
    ]) {
      expect(recorder, contains(token), reason: token);
    }
  });
}
