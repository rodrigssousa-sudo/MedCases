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
    history = File(
      'lib/screens/history_screen.dart',
    ).readAsStringSync();
    recorder = File(
      'lib/screens/clinical_recorder_sheet.dart',
    ).readAsStringSync();
  });

  test('Sinais Vitais usam grid responsivo e referências discretas', () {
    final owner = classSlice(history, '_VitalSignsWidgetState');
    expect(owner, contains('LayoutBuilder('));
    expect(RegExp(r'\b_pair\s*\(').allMatches(owner).length,
        greaterThanOrEqualTo(5));
    for (final reference in <String>[
      '120/80 mmHg',
      '60–100 bpm',
      '12–20 irpm',
      '36–37,5 °C',
      '≥ 95%',
      '70–140 mg/dL',
    ]) {
      expect(owner, contains(reference));
    }
    expect(owner, contains('action: TextInputAction.done'));
    expect(owner, contains('TextInputType.numberWithOptions'));
  });

  test('Laboratório fica dark fechado e expandido', () {
    final owner = classSlice(history, '_LabStructuredWidgetState');
    expect(owner, contains('color: const Color(0xFF252930)'));
    expect(owner, isNot(contains('0xFFF7FFFE')));
    expect(owner, contains('fillColor: const Color(0xFF2D3340)'));
    expect(owner, contains('ImageSource.camera'));
    expect(owner, contains('ImageSource.gallery'));
    expect(owner, contains('_LabOcrService.extractText'));
  });

  test('ECG fica dark, legível e sem dourado dominante', () {
    final owner = classSlice(history, '_EcgStructuredWidgetState');
    expect(owner, contains('color: const Color(0xFF252930)'));
    expect(owner, contains('const Color(0xFF143B32)'));
    expect(owner, isNot(contains('kGold')));
    expect(owner, isNot(contains('kGoldLight')));
    expect(owner, isNot(contains('color: sel ? kDark : Colors.white')));
  });

  test('picker principal é compacto e preserva câmera, galeria e OCR', () {
    final owner = classSlice(recorder, '_OcrScannerModalState');
    final sourceButton = classSlice(recorder, '_OcrSourceBtn');
    expect(owner, isNot(contains('0xFF6366F1')));
    expect(owner, isNot(contains('0xFF0F766E')));
    expect(owner, contains('_pickAndProcess(ImageSource.camera)'));
    expect(owner, contains('_pickAndProcess(ImageSource.gallery)'));
    expect(owner, contains('_picker.pickImage'));
    expect(owner, contains('SoapAiProcessor.ocrExam'));
    expect(owner, contains('indent: 56'));
    expect(sourceButton, contains('final String subtitle;'));
    expect(sourceButton, isNot(contains('final Color color;')));
  });

  test('botão principal do scanner permanece no owner aprovado', () {
    final owner = classSlice(history, '_OcrExamButton');
    expect(owner, contains('ClinicalRecorderSheet.showOcrScanner'));
    expect(owner, contains('Color(0xFF14213D)'));
    expect(owner, contains('Color(0xFF147D64)'));
  });

  test('não há corrupção de token de cor', () {
    expect(history, isNot(contains('const Color(0xFF252930)24')));
    expect(recorder, isNot(contains('const Color(0xFF252930)24')));
  });
}
