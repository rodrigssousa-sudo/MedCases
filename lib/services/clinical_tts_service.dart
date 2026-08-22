import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ClinicalTtsVoicePreference {
  automatic,
  feminine,
  masculine,
}

enum ClinicalTtsSpeedPreset {
  slow,
  comfortable,
  normal,
  fast,
}

class ClinicalTtsPreferences {
  const ClinicalTtsPreferences({
    this.voicePreference = ClinicalTtsVoicePreference.automatic,
    this.speechRate = comfortableSpeechRate,
  });

  static const double minimumSpeechRate = 0.25;
  static const double maximumSpeechRate = 0.65;
  static const double slowSpeechRate = 0.34;
  static const double comfortableSpeechRate = 0.42;
  static const double naturalSpeechRate = 0.47;
  static const double normalSpeechRate = 0.48;
  static const double fastSpeechRate = 0.56;

  final ClinicalTtsVoicePreference voicePreference;
  final double speechRate;

  ClinicalTtsPreferences copyWith({
    ClinicalTtsVoicePreference? voicePreference,
    double? speechRate,
  }) {
    return ClinicalTtsPreferences(
      voicePreference: voicePreference ?? this.voicePreference,
      speechRate: speechRate ?? this.speechRate,
    );
  }
}

class ClinicalTtsVoice {
  ClinicalTtsVoice({
    required this.name,
    required this.locale,
    required this.metadata,
  });

  factory ClinicalTtsVoice.fromMap(Map<String, dynamic> map) {
    return ClinicalTtsVoice(
      name: _firstNonEmpty(<dynamic>[
        map['name'],
        map['voice_name'],
      ]),
      locale: _firstNonEmpty(<dynamic>[
        map['locale'],
        map['language'],
      ]),
      metadata: Map<String, dynamic>.unmodifiable(map),
    );
  }

  final String name;
  final String locale;
  final Map<String, dynamic> metadata;

  String? get declaredGender {
    final dynamic rawGender =
        metadata['gender'] ?? metadata['Gender'] ?? metadata['voice_gender'];

    if (rawGender == null) {
      return null;
    }

    final String value = rawGender.toString().trim().toLowerCase();

    if (value.isEmpty) {
      return null;
    }

    if (value == 'f' ||
        value.contains('female') ||
        value.contains('feminine') ||
        value.contains('feminina') ||
        value.contains('femenina') ||
        value.contains('mujer')) {
      return 'female';
    }

    if (value == 'm' ||
        value.contains('male') ||
        value.contains('masculine') ||
        value.contains('masculina') ||
        value.contains('masculino') ||
        value.contains('hombre')) {
      return 'male';
    }

    return null;
  }

  int get qualityScore {
    final String qualityText = <dynamic>[
      metadata['quality'],
      metadata['voice_quality'],
      metadata['features'],
      metadata['identifier'],
      name,
    ].where((dynamic value) => value != null).map((dynamic value) {
      return value.toString().toLowerCase();
    }).join(' ');

    if (qualityText.contains('premium')) {
      return 500;
    }

    if (qualityText.contains('enhanced')) {
      return 400;
    }

    if (qualityText.contains('neural') || qualityText.contains('natural')) {
      return 300;
    }

    if (qualityText.contains('high')) {
      return 200;
    }

    if (qualityText.contains('compact')) {
      return 50;
    }

    return 100;
  }

  Map<String, String> toNativeVoice() {
    final String identifier = _firstNonEmpty(<dynamic>[
      metadata['identifier'],
      metadata['voice_identifier'],
    ]);

    // iOS supports selecting the exact native voice by identifier. Prefer
    // identifier-only so the premium/enhanced variant selected above is not
    // re-resolved by name/locale.
    if (identifier.isNotEmpty) {
      return <String, String>{'identifier': identifier};
    }

    final Map<String, String> voice = <String, String>{};

    if (name.isNotEmpty) {
      voice['name'] = name;
    }

    if (locale.isNotEmpty) {
      voice['locale'] = locale;
    }

    return voice;
  }
}

class ClinicalTtsSegment {
  const ClinicalTtsSegment({
    required this.text,
    required this.pauseAfter,
    required this.isTitle,
  });

  final String text;
  final Duration pauseAfter;
  final bool isTitle;
}

abstract class ClinicalTtsAdapter {
  Future<List<Map<String, dynamic>>> getVoices();

  Future<List<String>> getLanguages();

  Future<void> setLanguage(String locale);

  Future<void> setVoice(Map<String, String> voice);

  Future<void> setSpeechRate(double speechRate);

  Future<void> setPitch(double pitch);

  Future<void> setVolume(double volume);

  Future<void> awaitSpeakCompletion(bool enabled);

  Future<void> prepareForSpeech();

  Future<void> speak(String text);

  Future<void> stop();
}

class FlutterTtsClinicalAdapter implements ClinicalTtsAdapter {
  FlutterTtsClinicalAdapter({
    FlutterTts? flutterTts,
  }) : _flutterTts = flutterTts ?? FlutterTts() {
    _flutterTts.setStartHandler(() {
      _debugLog('start');
    });
    _flutterTts.setCompletionHandler(() {
      _debugLog('complete');
    });
    _flutterTts.setCancelHandler(() {
      _debugLog('cancel');
    });
    _flutterTts.setErrorHandler((dynamic message) {
      _debugLog('error=$message');
    });
  }

  final FlutterTts _flutterTts;

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[ClinicalTts][native] $message');
    }
  }

  Future<void> _configureIosAudioSession() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }

    await _flutterTts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      <IosTextToSpeechAudioCategoryOptions>[
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ],
      IosTextToSpeechAudioMode.spokenAudio,
    );
    await _flutterTts.setSharedInstance(true);
    _debugLog('audioSession=playback/spokenAudio active');
  }

  @override
  Future<void> awaitSpeakCompletion(bool enabled) async {
    await _flutterTts.awaitSpeakCompletion(enabled);
  }

  @override
  Future<List<String>> getLanguages() async {
    final dynamic rawLanguages = await _flutterTts.getLanguages;

    if (rawLanguages is! Iterable<dynamic>) {
      return <String>[];
    }

    return rawLanguages
        .map((dynamic value) => value.toString().trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<Map<String, dynamic>>> getVoices() async {
    final dynamic rawVoices = await _flutterTts.getVoices;

    if (rawVoices is! Iterable<dynamic>) {
      return <Map<String, dynamic>>[];
    }

    return rawVoices
        .map<Map<String, dynamic>>(_asStringDynamicMap)
        .where((Map<String, dynamic> voice) => voice.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> setLanguage(String locale) async {
    await _flutterTts.setLanguage(locale);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  @override
  Future<void> setSpeechRate(double speechRate) async {
    await _flutterTts.setSpeechRate(speechRate);
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    await _flutterTts.setVoice(voice);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume);
  }

  @override
  Future<void> prepareForSpeech() async {
    await _configureIosAudioSession();
  }

  @override
  Future<void> speak(String text) async {
    final dynamic result = await _flutterTts.speak(text);
    _debugLog('speakResult=$result chars=${text.length}');

    if (result == 0 || result == false) {
      throw StateError(
        'Clinical TTS native speak failed: $result',
      );
    }
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}

abstract class ClinicalTtsPreferenceStore {
  Future<String?> readString(String key);

  Future<double?> readDouble(String key);

  Future<void> writeString(String key, String value);

  Future<void> writeDouble(String key, double value);
}

class SharedPreferencesClinicalTtsStore implements ClinicalTtsPreferenceStore {
  Future<SharedPreferences> _preferences() {
    return SharedPreferences.getInstance();
  }

  @override
  Future<double?> readDouble(String key) async {
    final SharedPreferences preferences = await _preferences();
    return preferences.getDouble(key);
  }

  @override
  Future<String?> readString(String key) async {
    final SharedPreferences preferences = await _preferences();
    return preferences.getString(key);
  }

  @override
  Future<void> writeDouble(String key, double value) async {
    final SharedPreferences preferences = await _preferences();
    await preferences.setDouble(key, value);
  }

  @override
  Future<void> writeString(String key, String value) async {
    final SharedPreferences preferences = await _preferences();
    await preferences.setString(key, value);
  }
}

class ClinicalTtsService {
  ClinicalTtsService({
    ClinicalTtsAdapter? adapter,
    ClinicalTtsPreferenceStore? preferenceStore,
    Future<void> Function(Duration duration)? delay,
  })  : _adapter = adapter ?? FlutterTtsClinicalAdapter(),
        _preferenceStore =
            preferenceStore ?? SharedPreferencesClinicalTtsStore(),
        _delay = delay ?? _defaultDelay;

  static const String _voicePreferenceKey = 'clinical_tts_voice_preference';
  static const String _speechRateKey = 'clinical_tts_speech_rate';

  static const List<String> _spanishLocalePriority = <String>[
    'es-AR',
    'es-UY',
    'es-CL',
    'es-MX',
    'es-US',
    'es-419',
    'es-ES',
  ];

  final ClinicalTtsAdapter _adapter;
  final ClinicalTtsPreferenceStore _preferenceStore;
  final Future<void> Function(Duration duration) _delay;

  ClinicalTtsPreferences _preferences = const ClinicalTtsPreferences();

  Future<void>? _initialization;
  int _generation = 0;

  ClinicalTtsPreferences get preferences => _preferences;

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    // Voice and cadence are product-owned. Legacy persisted selectors are
    // intentionally ignored so every user receives the same clinical reading
    // profile while PT/ES locale resolution remains automatic.
    _preferences = const ClinicalTtsPreferences(
      voicePreference: ClinicalTtsVoicePreference.automatic,
      speechRate: ClinicalTtsPreferences.naturalSpeechRate,
    );

    await _adapter.awaitSpeakCompletion(true);
  }

  Future<List<ClinicalTtsVoice>> enumerateVoices() async {
    await initialize();

    final List<Map<String, dynamic>> rawVoices = await _adapter.getVoices();

    return rawVoices
        .map<ClinicalTtsVoice>(ClinicalTtsVoice.fromMap)
        .where((ClinicalTtsVoice voice) {
      return voice.name.isNotEmpty || voice.locale.isNotEmpty;
    }).toList(growable: false);
  }

  Future<void> setVoicePreference(
    ClinicalTtsVoicePreference preference,
  ) async {
    await initialize();

    _preferences = _preferences.copyWith(
      voicePreference: preference,
    );

    await _preferenceStore.writeString(
      _voicePreferenceKey,
      _voicePreferenceStorageValue(preference),
    );
  }

  Future<void> setSpeechRate(double speechRate) async {
    await initialize();

    final double safeRate = speechRate
        .clamp(
          ClinicalTtsPreferences.minimumSpeechRate,
          ClinicalTtsPreferences.maximumSpeechRate,
        )
        .toDouble();

    _preferences = _preferences.copyWith(
      speechRate: safeRate,
    );

    await _preferenceStore.writeDouble(
      _speechRateKey,
      safeRate,
    );
  }

  Future<void> setSpeedPreset(
    ClinicalTtsSpeedPreset preset,
  ) async {
    double speechRate;

    switch (preset) {
      case ClinicalTtsSpeedPreset.slow:
        speechRate = ClinicalTtsPreferences.slowSpeechRate;
        break;
      case ClinicalTtsSpeedPreset.comfortable:
        speechRate = ClinicalTtsPreferences.comfortableSpeechRate;
        break;
      case ClinicalTtsSpeedPreset.normal:
        speechRate = ClinicalTtsPreferences.normalSpeechRate;
        break;
      case ClinicalTtsSpeedPreset.fast:
        speechRate = ClinicalTtsPreferences.fastSpeechRate;
        break;
    }

    await setSpeechRate(speechRate);
  }

  String resolveLocale(
    String languageCode,
    Iterable<String> availableLocales,
  ) {
    final String normalizedLanguage = languageCode.trim().toLowerCase();

    if (normalizedLanguage == 'pt' ||
        normalizedLanguage.startsWith('pt-') ||
        normalizedLanguage.startsWith('pt_')) {
      return 'pt-BR';
    }

    final Map<String, String> normalizedAvailable = <String, String>{};

    for (final String locale in availableLocales) {
      final String normalized = _normalizeLocale(locale);

      if (normalized.isNotEmpty &&
          !normalizedAvailable.containsKey(normalized)) {
        normalizedAvailable[normalized] = normalized;
      }
    }

    for (final String candidate in _spanishLocalePriority) {
      if (normalizedAvailable.containsKey(
        _normalizeLocale(candidate),
      )) {
        return candidate;
      }
    }

    return 'es-ES';
  }

  ClinicalTtsVoice? selectBestVoice({
    required List<ClinicalTtsVoice> voices,
    required String locale,
    ClinicalTtsVoicePreference? preference,
  }) {
    if (voices.isEmpty) {
      return null;
    }

    final String normalizedLocale = _normalizeLocale(locale);
    final String language = normalizedLocale.split('-').first;

    List<ClinicalTtsVoice> candidates = voices.where(
      (ClinicalTtsVoice voice) {
        return _normalizeLocale(voice.locale) == normalizedLocale;
      },
    ).toList(growable: false);

    if (candidates.isEmpty) {
      candidates = voices.where((ClinicalTtsVoice voice) {
        return _normalizeLocale(voice.locale).startsWith('$language-');
      }).toList(growable: false);
    }

    if (candidates.isEmpty) {
      candidates = List<ClinicalTtsVoice>.from(voices);
    }

    final ClinicalTtsVoicePreference effectivePreference =
        preference ?? _preferences.voicePreference;
    final String? requestedGender = _requestedGender(effectivePreference);

    if (requestedGender != null) {
      final List<ClinicalTtsVoice> genderMatches =
          candidates.where((ClinicalTtsVoice voice) {
        return voice.declaredGender == requestedGender;
      }).toList(growable: false);

      if (genderMatches.isNotEmpty) {
        candidates = genderMatches;
      }
    }

    final List<ClinicalTtsVoice> sorted =
        List<ClinicalTtsVoice>.from(candidates);

    sorted.sort((
      ClinicalTtsVoice first,
      ClinicalTtsVoice second,
    ) {
      final int qualityComparison =
          second.qualityScore.compareTo(first.qualityScore);

      if (qualityComparison != 0) {
        return qualityComparison;
      }

      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });

    return sorted.first;
  }

  String normalizeForSpeech(
    String rawText, {
    required String languageCode,
  }) {
    final bool portuguese = languageCode.trim().toLowerCase().startsWith('pt');

    String text = rawText.replaceAll('\r\n', '\n');

    text = text.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      '\n',
    );
    text = _removeIndentedCodeBlocks(text);
    text = _removeFinalReferences(text);

    text = text.replaceAll(
      RegExp(
        r'<!--\s*NEXT_ACTION[\s\S]*?-->',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'<\s*NEXT_ACTION\b[^>]*>[\s\S]*?<\s*/\s*NEXT_ACTION\s*>',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'<\s*NEXT_ACTION\b[^>]*/\s*>',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'^\s*(?:\[|<)?NEXT_ACTION\b.*$',
        caseSensitive: false,
        multiLine: true,
      ),
      ' ',
    );

    text = text.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
      (Match match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (Match match) => match.group(1) ?? '',
    );
    text = text.replaceAll(
      RegExp(
        r'https?:\/\/[^\s)>\]]+',
        caseSensitive: false,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(r'<[^>]+>'),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'^\s*\|?[\s:|-]{3,}\|?\s*$',
        multiLine: true,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'^\s{0,3}(?:[-*_]\s*){3,}$',
        multiLine: true,
      ),
      ' ',
    );
    text = text.replaceAll(
      RegExp(
        r'^\s{0,3}#{1,6}\s*',
        multiLine: true,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'^\s{0,3}>\s?',
        multiLine: true,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'^\s*(?:[-+*]|\d+[.)])\s+',
        multiLine: true,
      ),
      '',
    );

    text = text
        .replaceAll('**', '')
        .replaceAll('__', '')
        .replaceAll('~~', '')
        .replaceAll('`', '')
        .replaceAll('|', ' ');

    text = _removeVisualEmoji(text);
    text = _expandClinicalLanguage(
      text,
      portuguese: portuguese,
    );
    text = _prepareNaturalProsody(
      text,
      portuguese: portuguese,
    );

    return _normalizeWhitespace(text);
  }

  List<ClinicalTtsSegment> buildSegments(
    String rawText, {
    required String languageCode,
  }) {
    final String normalized = normalizeForSpeech(
      rawText,
      languageCode: languageCode,
    );

    if (normalized.isEmpty) {
      return <ClinicalTtsSegment>[];
    }

    final String continuous = normalized
        .replaceAll(RegExp(r'\s*\n+\s*'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (continuous.isEmpty) {
      return <ClinicalTtsSegment>[];
    }

    final List<String> utterances;

    if (continuous.length <= 4200) {
      utterances = <String>[continuous];
    } else {
      utterances = _packNaturalUtterances(
        _splitSentences(continuous),
        maximumCharacters: 4200,
      );
    }

    return List<ClinicalTtsSegment>.generate(
      utterances.length,
      (int index) => ClinicalTtsSegment(
        text: utterances[index],
        pauseAfter: Duration.zero,
        isTitle: false,
      ),
      growable: false,
    );
  }

  List<String> _packNaturalUtterances(
    List<String> sentences, {
    required int maximumCharacters,
  }) {
    if (sentences.isEmpty) {
      return <String>[];
    }

    final List<String> utterances = <String>[];
    final StringBuffer current = StringBuffer();

    void flush() {
      final String text = current.toString().trim();

      if (text.isNotEmpty) {
        utterances.add(text);
      }

      current.clear();
    }

    for (final String sentence in sentences) {
      final String cleanSentence = sentence.trim();

      if (cleanSentence.isEmpty) {
        continue;
      }

      final int projectedLength = current.isEmpty
          ? cleanSentence.length
          : current.length + 1 + cleanSentence.length;

      if (current.isNotEmpty && projectedLength > maximumCharacters) {
        flush();
      }

      if (current.isNotEmpty) {
        current.write(' ');
      }

      current.write(cleanSentence);
    }

    flush();
    return utterances;
  }

  Future<void> speak(
    String rawText, {
    required String languageCode,
  }) async {
    final int generation = ++_generation;

    await initialize();

    if (generation != _generation) {
      return;
    }

    await _adapter.stop();

    if (generation != _generation) {
      return;
    }

    final List<ClinicalTtsSegment> segments = buildSegments(
      rawText,
      languageCode: languageCode,
    );

    if (segments.isEmpty) {
      return;
    }

    await _adapter.prepareForSpeech();

    if (generation != _generation) {
      return;
    }

    await _configureForLanguage(languageCode);

    if (generation != _generation) {
      return;
    }

    for (final ClinicalTtsSegment segment in segments) {
      if (generation != _generation) {
        return;
      }

      await _adapter.speak(segment.text);

      if (generation != _generation) {
        return;
      }

      if (segment.pauseAfter > Duration.zero) {
        await _delay(segment.pauseAfter);
      }
    }
  }

  Future<void> stop() async {
    _generation += 1;
    await _adapter.stop();
  }

  Future<void> dispose() {
    return stop();
  }

  Future<void> _configureForLanguage(
    String languageCode,
  ) async {
    final List<Map<String, dynamic>> rawVoices = await _adapter.getVoices();
    final List<String> languages = await _adapter.getLanguages();

    final List<ClinicalTtsVoice> voices = rawVoices
        .map<ClinicalTtsVoice>(ClinicalTtsVoice.fromMap)
        .toList(growable: false);

    final List<String> availableLocales = <String>[
      ...languages,
      ...voices.map((ClinicalTtsVoice voice) => voice.locale),
    ];

    final String locale = resolveLocale(
      languageCode,
      availableLocales,
    );
    final ClinicalTtsVoice? voice = selectBestVoice(
      voices: voices,
      locale: locale,
      preference: ClinicalTtsVoicePreference.automatic,
    );

    await _adapter.setLanguage(locale);

    if (voice != null) {
      final Map<String, String> nativeVoice = voice.toNativeVoice();

      if (nativeVoice.isNotEmpty) {
        await _adapter.setVoice(nativeVoice);
      }
    }

    const double safeRate = ClinicalTtsPreferences.naturalSpeechRate;

    await _adapter.setSpeechRate(safeRate);
    await _adapter.setPitch(1.0);
    await _adapter.setVolume(1.0);

    if (voice != null) {
      final String quality = voice.metadata['quality']?.toString() ?? 'unknown';
      _debugNaturalVoiceSelection(
        voice: voice,
        locale: locale,
        quality: quality,
        speechRate: safeRate,
      );
    }
  }

  void _debugNaturalVoiceSelection({
    required ClinicalTtsVoice voice,
    required String locale,
    required String quality,
    required double speechRate,
  }) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[ClinicalTts][voice] selectedVoice=${voice.name} '
      'identifier=${voice.metadata['identifier'] ?? 'unknown'} '
      'locale=$locale quality=$quality '
      'gender=${voice.declaredGender ?? 'unknown'} '
      'rate=$speechRate',
    );
  }

  static Future<void> _defaultDelay(Duration duration) {
    return Future<void>.delayed(duration);
  }
}

Map<String, dynamic> _asStringDynamicMap(dynamic value) {
  final Map<String, dynamic> result = <String, dynamic>{};

  if (value is Map<dynamic, dynamic>) {
    value.forEach((dynamic key, dynamic item) {
      result[key.toString()] = item;
    });
  }

  return result;
}

String _firstNonEmpty(Iterable<dynamic> values) {
  for (final dynamic value in values) {
    if (value == null) {
      continue;
    }

    final String text = value.toString().trim();

    if (text.isNotEmpty) {
      return text;
    }
  }

  return '';
}

String _voicePreferenceStorageValue(
  ClinicalTtsVoicePreference preference,
) {
  switch (preference) {
    case ClinicalTtsVoicePreference.automatic:
      return 'automatic';
    case ClinicalTtsVoicePreference.feminine:
      return 'feminine';
    case ClinicalTtsVoicePreference.masculine:
      return 'masculine';
  }
}

String? _requestedGender(
  ClinicalTtsVoicePreference preference,
) {
  switch (preference) {
    case ClinicalTtsVoicePreference.automatic:
      return null;
    case ClinicalTtsVoicePreference.feminine:
      return 'female';
    case ClinicalTtsVoicePreference.masculine:
      return 'male';
  }
}

String _normalizeLocale(String locale) {
  final String cleaned = locale.trim().replaceAll('_', '-');

  if (cleaned.isEmpty) {
    return '';
  }

  final List<String> pieces = cleaned.split('-');

  if (pieces.length == 1) {
    return pieces.first.toLowerCase();
  }

  return <String>[
    pieces.first.toLowerCase(),
    pieces[1].toUpperCase(),
    ...pieces.skip(2),
  ].join('-');
}

String _removeIndentedCodeBlocks(String text) {
  final List<String> retained = <String>[];

  for (final String line in text.split('\n')) {
    if (line.startsWith('    ') || line.startsWith('\t')) {
      continue;
    }

    retained.add(line);
  }

  return retained.join('\n');
}

String _removeFinalReferences(String text) {
  final RegExp heading = RegExp(
    r'^\s{0,3}(?:#{1,6}\s*)?'
    r'(?:refer[eê]ncias?(?:\s+bibliogr[aá]ficas?)?'
    r'|referencias?(?:\s+bibliogr[aá]ficas?)?'
    r'|bibliograf(?:ia|ía)'
    r'|fuentes?)\s*:?\s*$',
    caseSensitive: false,
    multiLine: true,
  );

  final Match? match = heading.firstMatch(text);

  if (match == null) {
    return text;
  }

  return text.substring(0, match.start);
}

String _expandClinicalLanguage(
  String text, {
  required bool portuguese,
}) {
  String result = text;

  result = result.replaceAll(
    RegExp(
      r'\bmcg\s*/\s*kg\s*/\s*min\b',
      caseSensitive: false,
    ),
    portuguese
        ? 'microgramas por quilograma por minuto'
        : 'microgramos por kilogramo por minuto',
  );
  result = result.replaceAll(
    RegExp(
      r'(?:µg|μg)\s*/\s*kg\s*/\s*min',
      caseSensitive: false,
    ),
    portuguese
        ? 'microgramas por quilograma por minuto'
        : 'microgramos por kilogramo por minuto',
  );
  result = result.replaceAll(
    RegExp(
      r'\bmg\s*/\s*kg\b',
      caseSensitive: false,
    ),
    portuguese ? 'miligramas por quilograma' : 'miligramos por kilogramo',
  );
  result = result.replaceAll(
    RegExp(
      r'\bmL\s*/\s*h\b',
      caseSensitive: false,
    ),
    'mililitros por hora',
  );
  result = result.replaceAllMapped(
    RegExp(r'\b(\d{2,3})\s*/\s*(\d{2,3})\b'),
    (Match match) {
      return '${match.group(1)} por ${match.group(2)}';
    },
  );
  result = result.replaceAllMapped(
    RegExp(r'\b(\d+(?:[.,]\d+)?)\s*%'),
    (Match match) {
      final String number = match.group(1) ?? '';

      return portuguese ? '$number por cento' : '$number por ciento';
    },
  );

  final Map<String, String> abbreviations = portuguese
      ? <String, String>{
          'PAM': 'pressão arterial média',
          'PA': 'pressão arterial',
          'FC': 'frequência cardíaca',
          'FR': 'frequência respiratória',
          'ECG': 'eletrocardiograma',
          'IAM': 'infarto agudo do miocárdio',
          'PCR': 'parada cardiorrespiratória',
          'TFG': 'taxa de filtração glomerular',
          'SpO2': 'saturação periférica de oxigênio',
          'SpO₂': 'saturação periférica de oxigênio',
          'SatO2': 'saturação de oxigênio',
          'SatO₂': 'saturação de oxigênio',
          'VO': 'via oral',
          'EV': 'via endovenosa',
          'IV': 'via intravenosa',
          'IM': 'via intramuscular',
          'SC': 'via subcutânea',
        }
      : <String, String>{
          'PAM': 'presión arterial media',
          'PA': 'presión arterial',
          'FC': 'frecuencia cardíaca',
          'FR': 'frecuencia respiratoria',
          'ECG': 'electrocardiograma',
          'IAM': 'infarto agudo de miocardio',
          'PCR': 'paro cardiorrespiratorio',
          'TFG': 'tasa de filtrado glomerular',
          'SpO2': 'saturación periférica de oxígeno',
          'SpO₂': 'saturación periférica de oxígeno',
          'SatO2': 'saturación de oxígeno',
          'SatO₂': 'saturación de oxígeno',
          'VO': 'vía oral',
          'EV': 'vía endovenosa',
          'IV': 'vía intravenosa',
          'IM': 'vía intramuscular',
          'SC': 'vía subcutánea',
        };

  for (final MapEntry<String, String> entry in abbreviations.entries) {
    result = result.replaceAll(
      RegExp('\\b${RegExp.escape(entry.key)}\\b'),
      entry.value,
    );
  }

  final List<MapEntry<RegExp, String>> units = <MapEntry<RegExp, String>>[
    MapEntry<RegExp, String>(
      RegExp(r'\bmmHg\b', caseSensitive: false),
      portuguese ? 'milímetros de mercúrio' : 'milímetros de mercurio',
    ),
    MapEntry<RegExp, String>(
      RegExp(r'\bmEq\b', caseSensitive: false),
      'miliequivalentes',
    ),
    MapEntry<RegExp, String>(
      RegExp(r'\bbpm\b', caseSensitive: false),
      portuguese ? 'batimentos por minuto' : 'latidos por minuto',
    ),
    MapEntry<RegExp, String>(
      RegExp(r'\bmcg\b', caseSensitive: false),
      portuguese ? 'microgramas' : 'microgramos',
    ),
    MapEntry<RegExp, String>(
      RegExp(r'(?:µg|μg)', caseSensitive: false),
      portuguese ? 'microgramas' : 'microgramos',
    ),
    MapEntry<RegExp, String>(
      RegExp(r'\bmg\b', caseSensitive: false),
      portuguese ? 'miligramas' : 'miligramos',
    ),
    MapEntry<RegExp, String>(
      RegExp(r'\bmL\b', caseSensitive: false),
      'mililitros',
    ),
  ];

  for (final MapEntry<RegExp, String> unit in units) {
    result = result.replaceAll(unit.key, unit.value);
  }

  return result;
}

String _prepareNaturalProsody(
  String text, {
  required bool portuguese,
}) {
  String result = text;

  result = result.replaceAll(
    RegExp(r'\bHARD\s+STOP\b', caseSensitive: false),
    'Alerta clínico crítico',
  );

  result = result.replaceAllMapped(
    RegExp(
      r'(\d+(?:[.,]\d+)?)\s*[–—-]\s*(\d+(?:[.,]\d+)?)'
      r'(?=\s*(?:microgramas|microgramos|miligramas|miligramos|'
      r'mililitros|milímetros|miliequivalentes|batimentos|latidos|%))',
      caseSensitive: false,
    ),
    (Match match) => '${match.group(1)} a ${match.group(2)}',
  );

  result = result.replaceAllMapped(
    RegExp(
      r'\b(\d{1,2})\s*/\s*(\d{1,2})\s*h\b',
      caseSensitive: false,
    ),
    (Match match) {
      final String first = match.group(1) ?? '';
      final String second = match.group(2) ?? '';

      if (first != second) {
        return match.group(0) ?? '';
      }

      return portuguese ? 'a cada $first horas' : 'cada $first horas';
    },
  );

  result = result.replaceAllMapped(
    RegExp(r'\b(\d+)\s*x\s*/\s*dia\b', caseSensitive: false),
    (Match match) {
      final int count = int.tryParse(match.group(1) ?? '') ?? 0;

      if (count == 1) {
        return portuguese ? 'uma vez por dia' : 'una vez al día';
      }

      return portuguese
          ? '$count vezes por dia'
          : '$count veces al día';
    },
  );

  final List<MapEntry<RegExp, String>> remainingUnits =
      <MapEntry<RegExp, String>>[
    MapEntry<RegExp, String>(
      RegExp(
        r'\bmicrogramas\s*/\s*min\b',
        caseSensitive: false,
      ),
      'microgramas por minuto',
    ),
    MapEntry<RegExp, String>(
      RegExp(
        r'\bmicrogramos\s*/\s*min\b',
        caseSensitive: false,
      ),
      'microgramos por minuto',
    ),
    MapEntry<RegExp, String>(
      RegExp(
        r'\bmiligramas\s*/\s*min\b',
        caseSensitive: false,
      ),
      'miligramas por minuto',
    ),
    MapEntry<RegExp, String>(
      RegExp(
        r'\bmiligramos\s*/\s*min\b',
        caseSensitive: false,
      ),
      'miligramos por minuto',
    ),
    MapEntry<RegExp, String>(
      RegExp(
        r'\bmiligramas\s*/\s*dia\b',
        caseSensitive: false,
      ),
      'miligramas por dia',
    ),
    MapEntry<RegExp, String>(
      RegExp(
        r'\bmiligramos\s*/\s*d[ií]a\b',
        caseSensitive: false,
      ),
      'miligramos por día',
    ),
  ];

  for (final MapEntry<RegExp, String> unit in remainingUnits) {
    result = result.replaceAll(unit.key, unit.value);
  }

  result = result.replaceAll(
    RegExp(
      r'\bvia oral\s*/\s*via sublingual\b',
      caseSensitive: false,
    ),
    portuguese
        ? 'via oral ou via sublingual'
        : 'vía oral o vía sublingual',
  );
  result = result.replaceAll(
    RegExp(
      r'\bvía oral\s*/\s*vía sublingual\b',
      caseSensitive: false,
    ),
    'vía oral o vía sublingual',
  );

  result = result
      .replaceAll(
        '≥',
        portuguese ? ' maior ou igual a ' : ' mayor o igual a ',
      )
      .replaceAll(
        '≤',
        portuguese ? ' menor ou igual a ' : ' menor o igual a ',
      )
      .replaceAll(
        '>',
        portuguese ? ' maior que ' : ' mayor que ',
      )
      .replaceAll('<', ' menor que ');

  final List<String> preparedLines = <String>[];

  for (final String rawLine in result.split('\n')) {
    String line = rawLine.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (line.isEmpty) {
      if (preparedLines.isNotEmpty && preparedLines.last.isNotEmpty) {
        preparedLines.add('');
      }

      continue;
    }

    if (line.endsWith(':')) {
      line = '${line.substring(0, line.length - 1)}.';
    } else if (!RegExp(r'[.!?]$').hasMatch(line)) {
      line = '$line.';
    }

    preparedLines.add(line);
  }

  while (preparedLines.isNotEmpty && preparedLines.last.isEmpty) {
    preparedLines.removeLast();
  }

  return preparedLines.join('\n');
}

String _removeVisualEmoji(String text) {
  final StringBuffer buffer = StringBuffer();

  for (final int rune in text.runes) {
    if (!_isVisualEmojiRune(rune)) {
      buffer.writeCharCode(rune);
    }
  }

  return buffer.toString();
}

bool _isVisualEmojiRune(int rune) {
  return rune == 0x200D ||
      rune == 0xFE0F ||
      rune == 0x20E3 ||
      (rune >= 0x1F1E6 && rune <= 0x1F1FF) ||
      (rune >= 0x1F300 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      (rune >= 0x2300 && rune <= 0x23FF);
}

String _normalizeWhitespace(String text) {
  final List<String> lines = <String>[];

  for (final String rawLine in text.split('\n')) {
    final String line = rawLine.replaceAll(RegExp(r'[ \t]+'), ' ').trim();

    if (line.isEmpty) {
      if (lines.isNotEmpty && lines.last.isNotEmpty) {
        lines.add('');
      }

      continue;
    }

    lines.add(line);
  }

  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }

  return lines.join('\n').trim();
}

List<String> _splitSentences(String paragraph) {
  final List<String> sentences = <String>[];
  final StringBuffer buffer = StringBuffer();

  for (int index = 0; index < paragraph.length; index += 1) {
    final String character = paragraph[index];
    buffer.write(character);

    final bool punctuation = character == '.' ||
        character == '!' ||
        character == '?' ||
        character == ';';

    if (!punctuation) {
      continue;
    }

    final bool atEnd = index == paragraph.length - 1;
    final bool followedByWhitespace =
        !atEnd && RegExp(r'\s').hasMatch(paragraph[index + 1]);

    if (atEnd || followedByWhitespace) {
      final String sentence = buffer.toString().trim();

      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }

      buffer.clear();
    }
  }

  final String remainder = buffer.toString().trim();

  if (remainder.isNotEmpty) {
    sentences.add(remainder);
  }

  if (sentences.isEmpty && paragraph.trim().isNotEmpty) {
    sentences.add(paragraph.trim());
  }

  return sentences;
}
