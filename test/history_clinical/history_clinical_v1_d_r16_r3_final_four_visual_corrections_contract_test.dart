import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classSlice(String source, String name) {
  final pattern = RegExp(
    '^\\s*class\\s+${RegExp.escape(name)}\\b[^\\{]*\\{',
    multiLine: true,
  );
  final matches = pattern.allMatches(source).toList();
  expect(matches, hasLength(1), reason: 'owner $name deve existir uma vez');

  final opening = source.indexOf('{', matches.single.start);
  var depth = 0;
  var quote = '';
  var inString = false;
  var escaped = false;

  for (var index = opening; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == quote) {
        inString = false;
      }
      continue;
    }
    if (char == "'" || char == '"') {
      inString = true;
      quote = char;
      continue;
    }
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) {
        return source.substring(matches.single.start, index + 1);
      }
    }
  }
  fail('owner $name sem fechamento');
}

void main() {
  late String history;
  late String recorder;

  setUpAll(() {
    history = File('lib/screens/history_screen.dart').readAsStringSync();
    recorder = File(
      'lib/screens/clinical_recorder_sheet.dart',
    ).readAsStringSync();
  });

  test('seletor de sexo usa altura delicada', () {
    final owner = classSlice(history, '_HistoryEditorState');
    expect(owner, contains('final selected = _draft.patientSex;'));
    expect(owner, contains('height: 44,'));
  });

  test('editor mantém respiro superior e inferior', () {
    final owner = classSlice(history, '_HistoryEditorState');
    expect(
      owner,
      contains('MediaQuery.viewInsetsOf(context).bottom > 0 ? 30 : 26'),
    );
    expect(owner, contains('_micBarExpanded ? 164.0 : 104.0'));
    expect(owner, contains(': 64.0;'));
  });

  test('subtítulos ficam claros e referências permanecem discretas', () {
    final vitals = classSlice(history, '_VitalSignsWidgetState');
    final lab = classSlice(history, '_LabStructuredWidgetState');
    final ecg = classSlice(history, '_EcgStructuredWidgetState');

    expect(vitals, contains('Color(0xFFE8F0EC)'));
    expect(vitals, contains('Color(0xFF7F8C86)'));
    expect(lab, isNot(contains('Color(0xFF8D9A94)')));
    expect(ecg, isNot(contains('Color(0xFF8D9A94)')));
    expect(lab, contains('Colors.white30'));
    expect(ecg, contains('Colors.white30'));
  });

  test('picker fica flat e grafite', () {
    final modal = classSlice(recorder, '_OcrScannerModalState');
    final sourceButton = classSlice(recorder, '_OcrSourceBtn');

    expect(modal, contains('Color(0xFF1A1D23)'));
    expect(modal, isNot(contains('Color(0xFF1A1F2E)')));
    expect(modal, contains('indent: 36'));
    expect(modal, isNot(contains('indent: 56')));
    expect(sourceButton, isNot(contains('Container(')));
    expect(sourceButton, contains('Color(0xFF10B981)'));
  });

  test('câmera, galeria e OCR permanecem conectados', () {
    final modal = classSlice(recorder, '_OcrScannerModalState');
    expect(modal, contains('_pickAndProcess(ImageSource.camera)'));
    expect(modal, contains('_pickAndProcess(ImageSource.gallery)'));
    expect(modal, contains('_picker.pickImage'));
    expect(modal, contains('SoapAiProcessor.ocrExam'));
  });

  test('contratos R15 permanecem', () {
    final vitals = classSlice(history, '_VitalSignsWidgetState');
    final lab = classSlice(history, '_LabStructuredWidgetState');
    final ecg = classSlice(history, '_EcgStructuredWidgetState');

    expect(vitals, contains('120/80 mmHg'));
    expect(vitals, contains('70–140 mg/dL'));
    expect(lab, contains('Color(0xFF252930)'));
    expect(lab, isNot(contains('0xFFF7FFFE')));
    expect(ecg, contains('Color(0xFF143B32)'));
    expect(ecg, isNot(contains('kGold')));
  });
}
