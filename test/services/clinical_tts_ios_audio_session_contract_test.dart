import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Clinical TTS iOS audio-session contract', () {
    late String source;

    setUpAll(() {
      source = File(
        'lib/services/clinical_tts_service.dart',
      ).readAsStringSync();
    });

    test('keeps iOS audio ownership inside the native adapter', () {
      expect(
        source,
        contains('Future<void> prepareForSpeech();'),
      );
      expect(
        source,
        contains('Future<void> _configureIosAudioSession() async'),
      );
      expect(
        source,
        contains('await _adapter.prepareForSpeech();'),
      );
      expect(
        source,
        contains(
          'defaultTargetPlatform != TargetPlatform.iOS',
        ),
      );
    });

    test('reclaims audible playback after STT or silent mode', () {
      expect(
        source,
        contains('IosTextToSpeechAudioCategory.playback'),
      );
      expect(
        source,
        contains('IosTextToSpeechAudioMode.spokenAudio'),
      );
      expect(
        source,
        contains(
          'IosTextToSpeechAudioCategoryOptions.allowBluetooth',
        ),
      );
      expect(
        source,
        contains(
          'IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP',
        ),
      );
      expect(
        source,
        contains(
          'IosTextToSpeechAudioCategoryOptions.duckOthers',
        ),
      );
      expect(
        source,
        contains('await _flutterTts.setSharedInstance(true);'),
      );
    });

    test('exposes native lifecycle and explicit speak failures', () {
      expect(source, contains('.setStartHandler('));
      expect(source, contains('.setCompletionHandler('));
      expect(source, contains('.setCancelHandler('));
      expect(source, contains('.setErrorHandler('));
      expect(
        source,
        contains(
          'final dynamic result = await _flutterTts.speak(text);',
        ),
      );
      expect(
        source,
        contains('if (result == 0 || result == false)'),
      );
    });

    test('does not move audio-session ownership to AiScreen', () {
      final String screen = File(
        'lib/screens/ai_screen.dart',
      ).readAsStringSync();

      expect(screen, isNot(contains('setIosAudioCategory')));
      expect(screen, isNot(contains('setSharedInstance')));
      expect(screen, isNot(contains('IosTextToSpeechAudio')));
    });
  });
}
