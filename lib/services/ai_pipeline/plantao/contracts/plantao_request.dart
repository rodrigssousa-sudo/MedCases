import 'plantao_continuation_type.dart';
import 'plantao_section.dart';

enum PlantaoLanguage { ptBr, es }

extension PlantaoLanguageWire on PlantaoLanguage {
  String get wireName {
    switch (this) {
      case PlantaoLanguage.ptBr:
        return 'pt_BR';
      case PlantaoLanguage.es:
        return 'es';
    }
  }
}

PlantaoLanguage plantaoLanguageFromWire(String value) {
  switch (value) {
    case 'pt_BR':
      return PlantaoLanguage.ptBr;
    case 'es':
      return PlantaoLanguage.es;
  }
  throw FormatException('Unknown PlantaoLanguage: $value');
}

enum PlantaoRequestTrigger { userInput, nextAction, retry, historyResume }

extension PlantaoRequestTriggerWire on PlantaoRequestTrigger {
  String get wireName {
    switch (this) {
      case PlantaoRequestTrigger.userInput:
        return 'user_input';
      case PlantaoRequestTrigger.nextAction:
        return 'next_action';
      case PlantaoRequestTrigger.retry:
        return 'retry';
      case PlantaoRequestTrigger.historyResume:
        return 'history_resume';
    }
  }
}

PlantaoRequestTrigger plantaoRequestTriggerFromWire(String value) {
  switch (value) {
    case 'user_input':
      return PlantaoRequestTrigger.userInput;
    case 'next_action':
      return PlantaoRequestTrigger.nextAction;
    case 'retry':
      return PlantaoRequestTrigger.retry;
    case 'history_resume':
      return PlantaoRequestTrigger.historyResume;
  }
  throw FormatException('Unknown PlantaoRequestTrigger: $value');
}

class PlantaoRequestValidationException implements Exception {
  PlantaoRequestValidationException(this.violations);

  final List<String> violations;

  @override
  String toString() {
    return 'PlantaoRequestValidationException(${violations.join(', ')})';
  }
}

class PlantaoRequest {
  PlantaoRequest({
    required this.requestId,
    required this.sessionId,
    required this.question,
    required this.language,
    required this.trigger,
    required this.continuationType,
    required Iterable<PlantaoSection> requestedSections,
    this.strictClinicalMode = true,
    Map<String, Object?>? patientContext,
    Map<String, Object?>? memoryContext,
    Map<String, Object?>? clientContext,
  }) : requestedSections = List<PlantaoSection>.unmodifiable(requestedSections),
       patientContext = patientContext == null
           ? null
           : Map<String, Object?>.unmodifiable(patientContext),
       memoryContext = memoryContext == null
           ? null
           : Map<String, Object?>.unmodifiable(memoryContext),
       clientContext = clientContext == null
           ? null
           : Map<String, Object?>.unmodifiable(clientContext);

  final String requestId;
  final String sessionId;
  final String question;
  final PlantaoLanguage language;
  final PlantaoRequestTrigger trigger;
  final PlantaoContinuationType continuationType;
  final List<PlantaoSection> requestedSections;
  final bool strictClinicalMode;
  final Map<String, Object?>? patientContext;
  final Map<String, Object?>? memoryContext;
  final Map<String, Object?>? clientContext;

  static const String mode = 'plantao';

  List<String> validate() {
    final List<String> violations = <String>[];

    if (requestId.trim().isEmpty) {
      violations.add('requestId must not be empty');
    }
    if (sessionId.trim().isEmpty) {
      violations.add('sessionId must not be empty');
    }
    if (question.trim().isEmpty) {
      violations.add('question must not be empty');
    }
    if (trigger == PlantaoRequestTrigger.nextAction &&
        continuationType == PlantaoContinuationType.initial) {
      violations.add('next_action requires a non-initial continuationType');
    }
    if (continuationType.requiresFocusedSections && requestedSections.isEmpty) {
      violations.add('examsEvolution requires at least one focused section');
    }

    for (final PlantaoSection section in requestedSections) {
      if (!continuationType.allowsSection(section)) {
        violations.add(
          '${continuationType.name} does not allow ${section.name}',
        );
      }
    }

    return List<String>.unmodifiable(violations);
  }

  void ensureValid() {
    final List<String> violations = validate();
    if (violations.isNotEmpty) {
      throw PlantaoRequestValidationException(violations);
    }
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'requestId': requestId,
      'sessionId': sessionId,
      'question': question,
      'language': language.wireName,
      'mode': mode,
      'trigger': trigger.wireName,
      'continuationType': continuationType.name,
      'requestedSections': requestedSections
          .map((PlantaoSection section) => section.name)
          .toList(growable: false),
      'strictClinicalMode': strictClinicalMode,
      'patientContext': patientContext,
      'memoryContext': memoryContext,
      'clientContext': clientContext,
    };
  }

  factory PlantaoRequest.fromJson(Map<String, Object?> json) {
    if (json['mode'] != mode) {
      throw const FormatException('PlantaoRequest mode must be plantao');
    }

    final Object? rawSections = json['requestedSections'];
    if (rawSections is! List<Object?>) {
      throw const FormatException('requestedSections must be a list');
    }

    return PlantaoRequest(
      requestId: json['requestId'] as String,
      sessionId: json['sessionId'] as String,
      question: json['question'] as String,
      language: plantaoLanguageFromWire(json['language'] as String),
      trigger: plantaoRequestTriggerFromWire(json['trigger'] as String),
      continuationType: plantaoContinuationTypeFromWire(
        json['continuationType'] as String,
      ),
      requestedSections: rawSections.map(
        (Object? item) => plantaoSectionFromWire(item as String),
      ),
      strictClinicalMode: json['strictClinicalMode'] as bool? ?? true,
      patientContext: _nullableObjectMap(json['patientContext']),
      memoryContext: _nullableObjectMap(json['memoryContext']),
      clientContext: _nullableObjectMap(json['clientContext']),
    );
  }

  static Map<String, Object?>? _nullableObjectMap(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! Map<Object?, Object?>) {
      throw const FormatException('Expected an object map');
    }
    return value.map(
      (Object? key, Object? item) =>
          MapEntry<String, Object?>(key as String, item),
    );
  }
}
