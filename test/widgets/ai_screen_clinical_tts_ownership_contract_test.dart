import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/ai_screen.dart').readAsStringSync();
  });

  group('AiScreen ClinicalTtsService ownership contract', () {
    test('removes direct ownership of flutter_tts', () {
      expect(
        source,
        isNot(contains("package:flutter_tts/flutter_tts.dart")),
      );
      expect(source, isNot(contains('FlutterTts')));
      expect(source, isNot(contains('late final FlutterTts _tts')));
      expect(source, isNot(contains('_tts = FlutterTts()')));
      expect(source, isNot(contains('_tts.setSpeechRate(0.95)')));
    });

    test('delegates the complete clinical reading pipeline', () {
      expect(
        source,
        contains("import '../services/clinical_tts_service.dart';"),
      );
      expect(
        source,
        contains(
          'final ClinicalTtsService _clinicalTts = ClinicalTtsService();',
        ),
      );
      expect(source, contains('await _clinicalTts.initialize();'));
      expect(source, contains('await _clinicalTts.stop();'));
      expect(source, contains('await _clinicalTts.speak('));
      expect(source, contains('languageCode: lang'));
      expect(source, contains('_clinicalTts.dispose();'));
    });

    test('keeps only visual playback state in AiScreen', () {
      expect(source, contains('bool _ttsReady = false;'));
      expect(source, contains('int _ttsPlayingIndex ='));
      expect(source, contains('ttsPlaying: _ttsPlayingIndex == i'));
      expect(source, contains('ttsReady: _ttsReady'));
      expect(source, contains('onTts: _ttsReady'));
      expect(
        source,
        contains(
          'Future<void> _toggleTts(int msgIndex, String text, String lang)',
        ),
      );
    });

    test('removes local normalization and legacy speed', () {
      expect(source, isNot(contains('String _cleanForSpeech(String text)')));
      expect(source, isNot(contains('setSpeechRate(0.95)')));
      // O mesmo ternário continua legitimamente no STT (ditado).
      // O contrato TTS deve bloquear apenas configuração direta no leitor.
      expect(source, isNot(contains('await _tts.setLanguage(locale)')));
      expect(source, isNot(contains('await _tts.speak(cleaned)')));
    });

    test('does not expose TTS settings through the M status sheet', () {
      expect(source, isNot(contains('ClinicalTtsVoicePreference.')));
      expect(source, isNot(contains('ClinicalTtsSpeedPreset.')));
      expect(source, isNot(contains('clinicalTtsService: _clinicalTts')));
    });
  });
}
