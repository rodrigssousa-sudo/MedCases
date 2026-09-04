import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:medcases/services/clinical_tts_service.dart';

void main() {
  group('ClinicalTtsService fixed natural profile', () {
    test('loads the product-owned automatic natural profile', () async {
      final FakeClinicalTtsAdapter adapter = FakeClinicalTtsAdapter();
      final FakeClinicalTtsPreferenceStore store =
          FakeClinicalTtsPreferenceStore();
      final ClinicalTtsService service = ClinicalTtsService(
        adapter: adapter,
        preferenceStore: store,
        delay: _noDelay,
      );

      await service.initialize();

      expect(
        service.preferences.voicePreference,
        ClinicalTtsVoicePreference.automatic,
      );
      expect(
        service.preferences.speechRate,
        ClinicalTtsPreferences.naturalSpeechRate,
      );
      expect(adapter.awaitCompletionEnabled, isTrue);
    });

    test('ignores legacy stored voice and speed during runtime configuration', () async {
      final FakeClinicalTtsPreferenceStore store =
          FakeClinicalTtsPreferenceStore();
      store.values['clinical_tts_voice_preference'] = 'masculine';
      store.values['clinical_tts_speech_rate'] = 0.25;

      final FakeClinicalTtsAdapter adapter = FakeClinicalTtsAdapter(
        voices: <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Enhanced Male',
            'locale': 'pt-BR',
            'quality': 'enhanced',
            'gender': 'male',
            'identifier': 'voice.enhanced.male',
          },
          <String, dynamic>{
            'name': 'Premium Natural',
            'locale': 'pt-BR',
            'quality': 'premium',
            'gender': 'female',
            'identifier': 'voice.premium.natural',
          },
        ],
        languages: <String>['pt-BR'],
      );
      final ClinicalTtsService service = ClinicalTtsService(
        adapter: adapter,
        preferenceStore: store,
        delay: _noDelay,
      );

      await service.speak('Conduta clínica.', languageCode: 'pt-BR');

      expect(
        adapter.selectedSpeechRate,
        ClinicalTtsPreferences.naturalSpeechRate,
      );
      expect(
        adapter.selectedVoice,
        equals(<String, String>{'identifier': 'voice.premium.natural'}),
      );
    });

    test('clamps and persists the speech rate', () async {
      final FakeClinicalTtsPreferenceStore store =
          FakeClinicalTtsPreferenceStore();
      final ClinicalTtsService service = ClinicalTtsService(
        adapter: FakeClinicalTtsAdapter(),
        preferenceStore: store,
        delay: _noDelay,
      );

      await service.setSpeechRate(0.95);

      expect(
        service.preferences.speechRate,
        ClinicalTtsPreferences.maximumSpeechRate,
      );
      expect(
        store.values['clinical_tts_speech_rate'],
        ClinicalTtsPreferences.maximumSpeechRate,
      );

      await service.setSpeechRate(0.10);

      expect(
        service.preferences.speechRate,
        ClinicalTtsPreferences.minimumSpeechRate,
      );
    });

    test('persists the public voice preference', () async {
      final FakeClinicalTtsPreferenceStore store =
          FakeClinicalTtsPreferenceStore();
      final ClinicalTtsService service = ClinicalTtsService(
        adapter: FakeClinicalTtsAdapter(),
        preferenceStore: store,
        delay: _noDelay,
      );

      await service.setVoicePreference(
        ClinicalTtsVoicePreference.feminine,
      );

      expect(
        store.values['clinical_tts_voice_preference'],
        'feminine',
      );
    });
  });

  group('ClinicalTtsService locale selection', () {
    test('forces pt-BR for Portuguese', () {
      final ClinicalTtsService service = _service();

      expect(
        service.resolveLocale(
          'pt',
          <String>['pt-PT', 'en-US'],
        ),
        'pt-BR',
      );
    });

    test('uses the approved Spanish priority', () {
      final ClinicalTtsService service = _service();

      expect(
        service.resolveLocale(
          'es',
          <String>['es-ES', 'es-MX', 'es_AR'],
        ),
        'es-AR',
      );
      expect(
        service.resolveLocale(
          'es',
          <String>['es-ES', 'es-US', 'es-MX'],
        ),
        'es-MX',
      );
      expect(
        service.resolveLocale(
          'es',
          <String>['fr-FR'],
        ),
        'es-ES',
      );
    });
  });

  group('ClinicalTtsService voice selection', () {
    test('prioritizes premium and enhanced voices', () {
      final ClinicalTtsVoice? selected = _service().selectBestVoice(
        voices: <ClinicalTtsVoice>[
          _voice(
            name: 'Compact',
            locale: 'es-AR',
            quality: 'compact',
          ),
          _voice(
            name: 'Enhanced',
            locale: 'es-AR',
            quality: 'enhanced',
          ),
          _voice(
            name: 'Premium',
            locale: 'es-AR',
            quality: 'premium',
          ),
        ],
        locale: 'es-AR',
      );

      expect(selected?.name, 'Premium');
    });

    test('uses gender only when metadata declares it', () {
      final ClinicalTtsVoice? selected = _service().selectBestVoice(
        voices: <ClinicalTtsVoice>[
          _voice(
            name: 'Unknown Premium',
            locale: 'pt-BR',
            quality: 'premium',
          ),
          _voice(
            name: 'Reported Female',
            locale: 'pt-BR',
            quality: 'enhanced',
            gender: 'female',
          ),
        ],
        locale: 'pt-BR',
        preference: ClinicalTtsVoicePreference.feminine,
      );

      expect(selected?.name, 'Reported Female');
    });

    test('does not infer an unavailable gender', () {
      final ClinicalTtsVoice? selected = _service().selectBestVoice(
        voices: <ClinicalTtsVoice>[
          _voice(
            name: 'Unknown Enhanced',
            locale: 'pt-BR',
            quality: 'enhanced',
          ),
          _voice(
            name: 'Unknown Premium',
            locale: 'pt-BR',
            quality: 'premium',
          ),
        ],
        locale: 'pt-BR',
        preference: ClinicalTtsVoicePreference.masculine,
      );

      expect(selected?.name, 'Unknown Premium');
      expect(selected?.declaredGender, isNull);
    });
  });

  group('ClinicalTtsService normalization', () {
    test('expands Portuguese clinical notation', () {
      final String normalized = _service().normalizeForSpeech(
        'PA 80/40, FC 110 bpm. '
        'Noradrenalina 0,1 mcg/kg/min EV. '
        'SF 500 mL a 100 mL/h. SpO2 92%.',
        languageCode: 'pt-BR',
      );

      expect(normalized, contains('pressão arterial 80 por 40'));
      expect(normalized, contains('frequência cardíaca'));
      expect(normalized, contains('batimentos por minuto'));
      expect(
        normalized,
        contains('microgramas por quilograma por minuto'),
      );
      expect(normalized, contains('via endovenosa'));
      expect(normalized, contains('mililitros por hora'));
      expect(
        normalized,
        contains('saturação periférica de oxigênio'),
      );
      expect(normalized, contains('92 por cento'));
      expect(
        _service().normalizeForSpeech(
          'Noradrenalina 0,1–0,5 mcg/kg/min EV 8/8 h.',
          languageCode: 'pt-BR',
        ),
        contains(
          '0,1 a 0,5 microgramas por quilograma por minuto '
          'via endovenosa a cada 8 horas.',
        ),
      );
    });

    test('expands Spanish clinical notation', () {
      final String normalized = _service().normalizeForSpeech(
        'PAM 65 mmHg. ECG con IAM. '
        'Adrenalina 1 mg IV. SatO2 90%.',
        languageCode: 'es-AR',
      );

      expect(normalized, contains('presión arterial media'));
      expect(normalized, contains('milímetros de mercurio'));
      expect(normalized, contains('electrocardiograma'));
      expect(
        normalized,
        contains('infarto agudo de miocardio'),
      );
      expect(normalized, contains('miligramos'));
      expect(normalized, contains('vía intravenosa'));
      expect(normalized, contains('saturación de oxígeno'));
      expect(normalized, contains('90 por ciento'));
      expect(
        _service().normalizeForSpeech(
          'HARD STOP: adrenalina 0,01–0,03 mg/kg IM 1x/dia.',
          languageCode: 'es-AR',
        ),
        contains(
          'Alerta clínico crítico: adrenalina 0,01 a 0,03 '
          'miligramos por kilogramo vía intramuscular una vez al día.',
        ),
      );
    });

    test('removes visual-only and non-spoken content', () {
      final String normalized = _service().normalizeForSpeech(
        '''
# Conduta clínica 🩺

**Administrar:** [protocolo](https://example.com/protocolo).

<!-- NEXT_ACTION: continuar -->
```dart
print('não falar');
```

## Referências
1. Livro médico.
''',
        languageCode: 'pt-BR',
      );

      expect(normalized, contains('Conduta clínica'));
      expect(normalized, contains('Administrar: protocolo.'));
      expect(normalized, isNot(contains('https://')));
      expect(normalized, isNot(contains('NEXT_ACTION')));
      expect(normalized, isNot(contains('print')));
      expect(normalized, isNot(contains('Referências')));
      expect(normalized, isNot(contains('Livro médico')));
      expect(normalized, isNot(contains('🩺')));
    });
  });

  group('ClinicalTtsService segmentation and queue', () {
    test('prepares the native audio session once before speaking', () async {
      final FakeClinicalTtsAdapter adapter = FakeClinicalTtsAdapter();

      final ClinicalTtsService service = ClinicalTtsService(
        adapter: adapter,
        preferenceStore: FakeClinicalTtsPreferenceStore(),
        delay: _noDelay,
      );

      await service.speak(
        'Avaliar PA.',
        languageCode: 'pt-BR',
      );

      expect(adapter.prepareForSpeechCount, 1);
      expect(adapter.spoken, <String>['Avaliar pressão arterial.']);
    });

    test('merges titles and short paragraphs into one natural utterance', () {
      final ClinicalTtsService service = _service();

      final List<ClinicalTtsSegment> segments = service.buildSegments(
        'Conduta imediata\n\n'
        'Avaliar PA. Monitorar FC e SpO2.\n\n'
        'Reavaliar em cinco minutos.',
        languageCode: 'pt-BR',
      );

      expect(segments, hasLength(1));
      expect(segments.single.isTitle, isFalse);
      expect(segments.single.pauseAfter, Duration.zero);
      expect(
        segments.single.text,
        contains(
          'Conduta imediata. Avaliar pressão arterial. Monitorar frequência cardíaca',
        ),
      );
      expect(segments.single.text, endsWith('Reavaliar em cinco minutos.'));
      expect(segments.single.text, isNot(contains('\n')));
    });

    test('turns clinical list lines into clean continuous speech', () {
      final ClinicalTtsService service = _service();

      final List<ClinicalTtsSegment> segments = service.buildSegments(
        'CONDUTA IMEDIATA:\n'
        'Noradrenalina 0,1–0,5 mcg/kg/min EV\n'
        'Monitorar PA e FC',
        languageCode: 'pt-BR',
      );

      expect(segments, hasLength(1));
      expect(segments.single.text, isNot(contains('\n')));
      expect(segments.single.text, contains('CONDUTA IMEDIATA.'));
      expect(segments.single.text, contains('0,1 a 0,5'));
      expect(segments.single.text, contains('via endovenosa.'));
      expect(segments.single.text, endsWith('frequência cardíaca.'));
    });

    test('packs long paragraphs only at complete sentence boundaries', () {
      final ClinicalTtsService service = _service();

      final String sentence =
          'Monitorar pressão arterial e frequência cardíaca. ';
      final String paragraph = List<String>.filled(
        120,
        sentence,
      ).join();

      final List<ClinicalTtsSegment> segments = service.buildSegments(
        paragraph,
        languageCode: 'pt-BR',
      );

      expect(segments.length, greaterThan(1));

      for (final ClinicalTtsSegment segment in segments) {
        expect(segment.text.length, lessThanOrEqualTo(4200));
        expect(segment.text, endsWith('.'));
        expect(segment.isTitle, isFalse);
      }
    });

    test('speaks prepared segments serially', () async {
      final FakeClinicalTtsAdapter adapter = FakeClinicalTtsAdapter(
        voices: <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'Premium AR',
            'locale': 'es-AR',
            'quality': 'premium',
            'identifier': 'com.apple.voice.premium.es-AR.PremiumAR',
          },
        ],
        languages: <String>['es-AR', 'es-ES'],
      );
      final List<Duration> pauses = <Duration>[];

      final ClinicalTtsService service = ClinicalTtsService(
        adapter: adapter,
        preferenceStore: FakeClinicalTtsPreferenceStore(),
        delay: (Duration duration) async {
          pauses.add(duration);
        },
      );

      await service.speak(
        'Conducta\n\n'
        'Controlar PA. Repetir ECG.',
        languageCode: 'es',
      );

      expect(
        adapter.spoken,
        <String>[
          'Conducta. Controlar presión arterial. Repetir electrocardiograma.',
        ],
      );
      expect(adapter.selectedLanguage, 'es-AR');
      expect(
        adapter.selectedVoice,
        equals(<String, String>{
          'identifier': 'com.apple.voice.premium.es-AR.PremiumAR',
        }),
      );
      expect(
        adapter.selectedSpeechRate,
        ClinicalTtsPreferences.naturalSpeechRate,
      );
      expect(pauses, isEmpty);
    });

    test('a newer generation invalidates pending long-form utterances', () async {
      final Completer<void> firstSpeakGate = Completer<void>();
      final FakeClinicalTtsAdapter adapter = FakeClinicalTtsAdapter(
        firstSpeakGate: firstSpeakGate,
      );
      final ClinicalTtsService service = ClinicalTtsService(
        adapter: adapter,
        preferenceStore: FakeClinicalTtsPreferenceStore(),
        delay: _noDelay,
      );

      final String longFirstGeneration = <String>[
        ...List<String>.filled(220, 'Primeiro segmento clinico completo.'),
        'Marcador tardio que nao deve ser falado.',
      ].join(' ');

      final Future<void> firstGeneration = service.speak(
        longFirstGeneration,
        languageCode: 'pt-BR',
      );

      await adapter.firstSpeakStarted.future;

      final Future<void> secondGeneration = service.speak(
        'Terceiro.',
        languageCode: 'pt-BR',
      );

      await secondGeneration;
      firstSpeakGate.complete();
      await firstGeneration;

      expect(
        adapter.spoken.any((String text) => text.contains('Primeiro segmento')),
        isTrue,
      );
      expect(adapter.spoken, contains('Terceiro.'));
      expect(
        adapter.spoken.any((String text) => text.contains('Marcador tardio')),
        isFalse,
      );
      expect(adapter.stopCount, greaterThanOrEqualTo(2));
    });
  });
}

ClinicalTtsService _service() {
  return ClinicalTtsService(
    adapter: FakeClinicalTtsAdapter(),
    preferenceStore: FakeClinicalTtsPreferenceStore(),
    delay: _noDelay,
  );
}

Future<void> _noDelay(Duration duration) async {}

ClinicalTtsVoice _voice({
  required String name,
  required String locale,
  required String quality,
  String? gender,
}) {
  return ClinicalTtsVoice.fromMap(
    <String, dynamic>{
      'name': name,
      'locale': locale,
      'quality': quality,
      if (gender != null) 'gender': gender,
    },
  );
}

class FakeClinicalTtsPreferenceStore implements ClinicalTtsPreferenceStore {
  final Map<String, Object> values = <String, Object>{};

  @override
  Future<double?> readDouble(String key) async {
    final Object? value = values[key];
    return value is double ? value : null;
  }

  @override
  Future<String?> readString(String key) async {
    final Object? value = values[key];
    return value is String ? value : null;
  }

  @override
  Future<void> writeDouble(String key, double value) async {
    values[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    values[key] = value;
  }
}

class FakeClinicalTtsAdapter implements ClinicalTtsAdapter {
  FakeClinicalTtsAdapter({
    List<Map<String, dynamic>>? voices,
    List<String>? languages,
    this.firstSpeakGate,
  })  : voices = voices ?? <Map<String, dynamic>>[],
        languages = languages ?? <String>[];

  final List<Map<String, dynamic>> voices;
  final List<String> languages;
  final Completer<void>? firstSpeakGate;

  final Completer<void> firstSpeakStarted = Completer<void>();
  final List<String> spoken = <String>[];

  bool awaitCompletionEnabled = false;
  String? selectedLanguage;
  Map<String, String>? selectedVoice;
  double? selectedSpeechRate;
  double? selectedPitch;
  double? selectedVolume;
  int prepareForSpeechCount = 0;
  int stopCount = 0;
  int _speakCount = 0;

  @override
  Future<void> awaitSpeakCompletion(bool enabled) async {
    awaitCompletionEnabled = enabled;
  }

  @override
  Future<List<String>> getLanguages() async {
    return List<String>.from(languages);
  }

  @override
  Future<List<Map<String, dynamic>>> getVoices() async {
    return voices
        .map<Map<String, dynamic>>(
          (Map<String, dynamic> voice) => Map<String, dynamic>.from(voice),
        )
        .toList(growable: false);
  }

  @override
  Future<void> prepareForSpeech() async {
    prepareForSpeechCount += 1;
  }

  @override
  Future<void> setLanguage(String locale) async {
    selectedLanguage = locale;
  }

  @override
  Future<void> setPitch(double pitch) async {
    selectedPitch = pitch;
  }

  @override
  Future<void> setSpeechRate(double speechRate) async {
    selectedSpeechRate = speechRate;
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    selectedVoice = Map<String, String>.from(voice);
  }

  @override
  Future<void> setVolume(double volume) async {
    selectedVolume = volume;
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    _speakCount += 1;

    if (_speakCount == 1 && firstSpeakGate != null) {
      if (!firstSpeakStarted.isCompleted) {
        firstSpeakStarted.complete();
      }

      await firstSpeakGate!.future;
    }
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}
