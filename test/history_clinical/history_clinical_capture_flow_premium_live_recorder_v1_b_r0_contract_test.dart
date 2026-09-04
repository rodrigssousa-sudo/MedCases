import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String classSlice(String source, String className, String nextClassName) {
  final start = source.indexOf('class $className');
  final end = source.indexOf('class $nextClassName', start + 1);
  expect(start, greaterThanOrEqualTo(0), reason: className);
  expect(end, greaterThan(start), reason: nextClassName);
  return source.substring(start, end);
}

void main() {
  late String recorder;
  late String service;
  late String mobile;
  late String web;

  setUpAll(() {
    recorder = read('lib/screens/clinical_recorder_sheet.dart');
    service = read('lib/services/clinical_recorder_service.dart');
    mobile = read('lib/services/stt_helper_mobile.dart');
    web = read('lib/services/stt_helper_web.dart');
  });

  test('chooser converges to canonical compact premium surface', () {
    final owner = classSlice(
      recorder,
      '_FlowSelectionModal',
      '_FlowOption',
    );

    for (final token in const <String>[
      'MEDCASES_HC_CAPTURE_PREMIUM_CHOOSER_V1_B_R0',
      'Color(0xFF1A1D23)',
      'Color(0xFFECF1F3)',
      'EdgeInsets.fromLTRB(',
      'Seleccione cómo desea capturar la historia clínica.',
      'Selecione como deseja capturar a história clínica.',
      'Grabar consulta y transcribir todo',
      'Gravar consulta e transcrever tudo',
      'Completar manualmente',
      'Preencher manualmente',
      'Grabar por bloques SOAP',
      'Gravar por blocos SOAP',
    ]) {
      expect(owner, contains(token), reason: token);
    }

    expect(owner, contains('_openRecorder(context, RecorderMode.continuous)'));
    expect(owner, contains('onManual();'));
    expect(owner, contains('_openRecorder(context, RecorderMode.soapBlocks)'));
  });

  test('IA option is distinctive without gradient or shadow', () {
    final owner = classSlice(
      recorder,
      '_FlowOption',
      '_RecorderPage',
    );

    for (final token in const <String>[
      'LIGHT_MODE_PREMIUM_V1_A_R14_FLOW_OPTION',
      'MEDCASES_HC_CAPTURE_PREMIUM_FLOW_OPTION_V1_B_R0',
      'final titleColor',
      'final subtitleColor',
      'final dividerColor',
      'Color(0xFF0F172A)',
      'Color(0xFF64748B)',
      'Color(0xFFE2E8F0)',
      'Color(0xFF202A29)',
      'Color(0xFFF4FAF7)',
      "Color(0xFF0E8000)",
    ]) {
      expect(owner, contains(token), reason: token);
    }

    expect(owner, contains("'IA'"));
    expect(owner, isNot(contains('LinearGradient(')));
    expect(owner, isNot(contains('BoxShadow(')));
  });

  test('live recorder has clear states and canonical geometry', () {
    final owner = classSlice(
      recorder,
      '_RecorderPageState',
      '_ControlBtn',
    );

    for (final token in const <String>[
      'MEDCASES_HC_CAPTURE_PREMIUM_LIVE_RECORDER_V1_B_R0',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R11_R2_SOAP_LIGHT_SHELL',
      'toolbarHeight: 48',
      'width: 36',
      'height: 36',
      'Color(0xFF1A1D23)',
      'Color(0xFFECF1F3)',
      'Color(0xFF252930)',
      "'ESCUCHANDO'",
      "'ESCUTANDO'",
      "'PAUSADO'",
      "'PROCESANDO IA'",
      "'PROCESSANDO IA'",
      "'EN VIVO'",
      "'AO VIVO'",
      'Transcripción en tiempo real',
      'Transcrição em tempo real',
      'Se actualiza mientras habla.',
      'Atualiza enquanto você fala.',
      'SelectableText(',
      'controller: _scrollCtrl',
      'BouncingScrollPhysics',
      'final hasTranscript =',
      '_isProcessing || !hasTranscript',
    ]) {
      expect(owner, contains(token), reason: token);
    }

    expect(owner, contains('_elapsedSec > 750'));
    expect(owner, contains('Color(0xFFEF4444)'));
    expect(owner, contains('Color(0xFF10B981)'));
    expect(owner, isNot(contains('BoxShadow(')));
    expect(owner, isNot(contains('LinearGradient(')));
  });

  test('SOAP navigation and capture callbacks remain productive', () {
    for (final token in const <String>[
      'RecorderMode.continuous',
      'RecorderMode.soapBlocks',
      'onManual();',
      'onSoapData: onSoapData',
      '_currentBlock',
      '_nextSoapBlock',
      '_finishRecording',
      'ClinicalRecorderService',
      'SoapAiProcessor.structure',
      'Navigator.pushReplacement',
      'widget.onSoapData(confirmed);',
      '_recorder.transcriptStream.listen',
      '_scrollCtrl.animateTo',
    ]) {
      expect(recorder, contains(token), reason: token);
    }
  });

  test('control buttons are compact and disabled-aware', () {
    final owner = classSlice(
      recorder,
      '_ControlBtn',
      '_SoapReviewPage',
    );

    expect(
      owner,
      contains('MEDCASES_HC_CAPTURE_PREMIUM_CONTROL_BUTTON_V1_B_R0'),
    );
    expect(owner, contains('final enabled = onTap != null;'));
    expect(owner, contains('width: 44'));
    expect(owner, contains('height: 44'));
    expect(owner, contains('size: 20'));
    expect(owner, isNot(contains('BoxShadow(')));
  });

  test('STT partial and final core remains enabled and session-safe', () {
    for (final token in const <String>[
      "String _partialTranscript = '';",
      'int _sessionEpoch = 0;',
      'Timer? _restartTimer;',
      'onPartialResult: (text)',
      '_commitFinal(epoch, text);',
      '_scheduleRestart(',
      '_rotateSession(epoch)',
    ]) {
      expect(service, contains(token), reason: token);
    }

    expect(mobile, contains('partialResults: true'));
    expect(mobile, contains('ListenMode.dictation'));
    expect(mobile, contains('_onPartialResultCb?.call(words);'));
    expect(mobile, contains('sessionEpoch != _activeSessionEpoch'));
    expect(web, contains('onPartialResult?.call(transcript);'));
  });
}
