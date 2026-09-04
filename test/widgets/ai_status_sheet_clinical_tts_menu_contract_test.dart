import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String aiScreen;
  late String statusSheet;

  setUpAll(() {
    aiScreen = File('lib/screens/ai_screen.dart').readAsStringSync();
    statusSheet = File(
      'lib/screens/ai/widgets/ai_status_sheet.dart',
    ).readAsStringSync();
  });

  group('AiStatusSheet fixed clinical TTS contract', () {
    test('removes TTS settings ownership from the M status sheet', () {
      expect(statusSheet, isNot(contains('ClinicalTtsService')));
      expect(statusSheet, isNot(contains('ClinicalTtsVoicePreference')));
      expect(statusSheet, isNot(contains('ClinicalTtsSpeedPreset')));
      expect(statusSheet, isNot(contains('_buildClinicalTtsSettings')));
      expect(statusSheet, isNot(contains('_selectVoicePreference')));
      expect(statusSheet, isNot(contains('_selectSpeedPreset')));
      expect(statusSheet, isNot(contains('_persistSpeechRate')));
      expect(aiScreen, isNot(contains('clinicalTtsService: _clinicalTts')));
    });

    test('removes user voice gender and speed controls', () {
      expect(statusSheet, isNot(contains("'Femenina'")));
      expect(statusSheet, isNot(contains("'Feminina'")));
      expect(statusSheet, isNot(contains("'Masculina'")));
      expect(statusSheet, isNot(contains("'VELOCIDAD'")));
      expect(statusSheet, isNot(contains("'VELOCIDADE'")));
      expect(statusSheet, isNot(contains('ChoiceChip(')));
      expect(statusSheet, isNot(contains('Slider(')));
      expect(statusSheet, isNot(contains('divisions: 40')));
    });

    test('keeps the M sheet and server/account content intact', () {
      expect(aiScreen, contains('AiStatusSheet('));
      expect(statusSheet, contains('SERVIDOR MEDCASES IA'));
      expect(statusSheet, contains('Conectar con Google'));
      expect(statusSheet, contains('SingleChildScrollView('));
      expect(
        statusSheet,
        contains('maxHeight: MediaQuery.of(context).size.height * 0.92'),
      );
    });
  });
}
