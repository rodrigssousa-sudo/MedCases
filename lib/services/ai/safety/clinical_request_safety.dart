import 'clinical_patient_quantity.dart';
import 'clinical_query_scope.dart';
import 'study_query_scope.dart';
import '../../study/study_reference_boundary.dart';
import 'clinical_dose_scope.dart';
import 'ai_stream_trace.dart';
import '../../ai_pipeline/plantao/contracts/plantao_clinical_regimen_contract.dart';
import '../../ai_pipeline/ai_request_contract.dart';
import '../../plantao_global_clinical_response_gate.dart';

enum Answerability { answer, answerWithLimitations, askForMissingData, abstain }

enum SafetyGate {
  modeMatch,
  criticalDataComplete,
  medicationEvidence,
  numericValidation,
  contradictionCheck,
  unsupportedCriticalClaims,
  evidenceBinding
}

enum SafetyVerdict { pass, notApplicable, failClosed }

enum ClinicalCertainty { confirmed, likely, possible, insufficientData }

enum EvidenceFidelity { exact, unsupported }

enum EvidenceFreshness { reviewDateProvided, unknown }

enum MassUnit { g, mg, mcg }

/// No clinical ranges or dose recommendations: dimensional arithmetic only.
class ClinicalArithmetic {
  static final _equation = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(mcg|mg|g)\s*=\s*(\d+(?:[.,]\d+)?)\s*(mcg|mg|g)\b',
      caseSensitive: false);
  static bool isPureMassEquation(String text) {
    final match = _equation.firstMatch(text.trim());
    return match != null && match.start == 0 && match.end == text.trim().length;
  }

  static bool? validateMassEquations(String text) {
    final equations = _equation.allMatches(text);
    if (equations.isEmpty) return null;
    for (final e in equations) {
      try {
        final from = MassUnit.values.byName(e.group(2)!.toLowerCase());
        final to = MassUnit.values.byName(e.group(4)!.toLowerCase());
        final expected = convertMass(decimal(e.group(1)!), from, to);
        final actual = decimal(e.group(3)!);
        if ((expected - actual).abs() > expected.abs() * 1e-12) return false;
      } on FormatException {
        return false;
      }
    }
    return true;
  }

  /// Recognizes complete dimensional equations only. Mathematical validity
  /// never grants pharmacological authority to their operands or result.
  static bool? validateClinicalEquations(String text, ClinicalFacts facts) {
    final checks = <bool>[];
    final mass = validateMassEquations(text);
    if (mass != null) checks.add(mass);
    const n = r'(\d+(?:[.,]\d+)?)';
    const u = r'(mcg|mg|g)';
    void check(String pattern, double Function(RegExpMatch) expected,
        int resultGroup) {
      for (final m in RegExp(pattern, caseSensitive: false).allMatches(text)) {
        try {
          final target = decimal(m.group(resultGroup)!);
          final value = expected(m);
          checks.add(
              value.isFinite && (value - target).abs() <= target.abs() * 1e-12);
        } on FormatException {
          checks.add(false);
        }
      }
    }

    double value(RegExpMatch m, int group) => decimal(m.group(group)!);
    MassUnit unit(RegExpMatch m, int group) =>
        MassUnit.values.byName(m.group(group)!.toLowerCase());
    double weight(RegExpMatch m, int group) {
      final kg = value(m, group);
      if (facts.weightKg == null || facts.weightKg != kg) {
        throw const FormatException('weight_context_mismatch');
      }
      return kg;
    }

    check(
        '$n\\s*$u\\s*/\\s*kg\\s*[x×*]\\s*$n\\s*kg\\s*=\\s*$n\\s*$u\\b',
        (m) => totalDose(
            perKg: convertMass(value(m, 1), unit(m, 2), unit(m, 5)),
            weightKg: weight(m, 3)),
        4);
    check(
        '$n\\s*$u\\s*/\\s*$n\\s*(?:tomadas|doses)\\s*=\\s*$n\\s*$u\\b',
        (m) => perAdministration(
            total: convertMass(value(m, 1), unit(m, 2), unit(m, 5)),
            administrations: value(m, 3)),
        4);
    check(
        '$n\\s*$u\\s*/\\s*$n\\s*ml\\s*=\\s*$n\\s*$u\\s*/\\s*ml\\b',
        (m) => concentration(
            mass: convertMass(value(m, 1), unit(m, 2), unit(m, 5)),
            volumeMl: value(m, 3)),
        4);
    check(
        '$n\\s*$u\\s*/\\s*kg\\s*/\\s*min\\s*[x×*]\\s*$n\\s*kg\\s*/\\s*$n\\s*$u\\s*/\\s*ml\\s*=\\s*$n\\s*ml\\s*/\\s*h\\b',
        (m) {
      final concentration = convertMass(value(m, 4), unit(m, 5), MassUnit.mcg);
      if (facts.number('concentrationMcgMl') != concentration) {
        throw const FormatException('concentration_context_mismatch');
      }
      return infusionMlHour(
          mcgKgMinute: convertMass(value(m, 1), unit(m, 2), MassUnit.mcg),
          weightKg: weight(m, 3),
          mcgMl: concentration);
    }, 6);
    return checks.isEmpty ? null : checks.every((valid) => valid);
  }

  static double convertMass(double value, MassUnit from, MassUnit to) {
    _positive(value);
    const scales = {
      MassUnit.g: 1000000.0,
      MassUnit.mg: 1000.0,
      MassUnit.mcg: 1.0
    };
    return _positive(value * scales[from]! / scales[to]!);
  }

  static double totalDose({required double perKg, required double weightKg}) =>
      _positive(_positive(perKg) * _positive(weightKg));
  static double perAdministration(
          {required double total, required double administrations}) =>
      _positive(_positive(total) / _positive(administrations));
  static double concentration(
          {required double mass, required double volumeMl}) =>
      _positive(_positive(mass) / _positive(volumeMl));
  static double infusionMlHour(
          {required double mcgKgMinute,
          required double weightKg,
          required double mcgMl}) =>
      _positive(
          _positive(mcgKgMinute) * _positive(weightKg) * 60 / _positive(mcgMl));
  static double decimal(String input) {
    // Reject ambiguous thousands separators, exponents and mixed punctuation.
    if (!RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(input.trim())) {
      throw const FormatException('invalid_decimal');
    }
    return _positive(double.parse(input.trim().replaceAll(',', '.')));
  }

  static double _positive(double v) {
    if (!v.isFinite || v <= 0) throw const FormatException('invalid_quantity');
    return v;
  }
}

/// Values are user assertions, never established from a model answer.
class ClinicalFacts {
  ClinicalFacts(
      {Map<String, String> values = const {},
      Iterable<String> rejected = const []})
      : values = Map.unmodifiable(values),
        rejected = List.unmodifiable(rejected);
  final Map<String, String> values;
  final List<String> rejected;
  double? number(String key) =>
      double.tryParse((values[key] ?? '').replaceAll(',', '.'));
  double? get ageYears => number('ageYears');
  double? get weightKg => number('weightKg');
  String? get sex => values['sex'];
  double? get renalFunction => number('renalFunction');
  bool? get pregnancy =>
      values['pregnancy'] == null ? null : values['pregnancy'] == 'true';
  String? get allergies => values['allergies'];
  String? get currentMedications => values['currentMedications'];

  static ClinicalFacts fromUserText(String text) {
    text = ClinicalPatientQuantity.normalize(text);
    final facts = <String, String>{};
    final conflicts = <String>[];
    void capture(String key, String pattern, {bool numeric = false}) {
      final values = RegExp(pattern, caseSensitive: false)
          .allMatches(text)
          .where((m) {
            final start = text.lastIndexOf(
                RegExp(r'[\n;.!?]'), m.start == 0 ? 0 : m.start - 1);
            final prefix = text
                .substring(start < 0 ? 0 : start + 1, m.start)
                .toLowerCase();
            return !RegExp(
                    r'\b(?:nao|não|no|sin|sem|se|si|if|talvez|possivel|posible|possible|hipotetico|hipotético)\b')
                .hasMatch(prefix);
          })
          .map((m) => m.group(1)!.trim().toLowerCase())
          .toSet();
      if (values.length > 1) {
        conflicts.add(key);
        return;
      }
      if (values.isEmpty) return;
      final value = values.single;
      final previous = facts[key];
      if (numeric) {
        try {
          facts[key] = ClinicalArithmetic.decimal(value).toString();
        } on FormatException {
          conflicts.add(key);
        }
      } else {
        facts[key] = value;
      }
      if (previous != null && facts[key] != previous) {
        conflicts.add(key);
        facts.remove(key);
      }
    }

    capture('medicationContext',
        r'\b(?:dose|doses|dosis|uso)\s+(?:de|da|do|del)\s+([a-záéíóúãõêç-]+)(?=\s|[.,;?!]|$)');
    capture('indication',
        r'\b(?:indica[çc][aã]o|indicaci[oó]n)\s*[:=]\s*([^\n;?!]+)');
    capture('indication',
        r'\b(?:uso|dose|doses|dosis)\s+(?:de|da|do|del)\s+[a-záéíóúãõêç-]+\s+(?:en|em|para)\s+(?!(?:un|um|este|esse|esta|mi|meu)\s+(?:peso|paciente|caso)|\d)([^\n;?!]+)');
    capture('ageYears',
        r'\b(?:idade|edad|age)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*(?:anos|años|years)?',
        numeric: true);
    capture('ageYears', r'\b(\d+(?:[.,]\d+)?)\s*(?:anos|años|years)\b',
        numeric: true);
    capture('weightKg', ClinicalPatientQuantity.weightPattern, numeric: true);
    capture('renalFunction',
        r'\b(?:clcr|egfr|tfg)\s*[:=]?\s*(\d+(?:[.,]\d+)?)\s*ml\s*/\s*min',
        numeric: true);
    capture('findings', r'\b(?:achados|hallazgos|findings)\s*[:=]\s*([^\n;]+)');
    capture('bodySurfaceArea',
        r'\b(?:superfície corporal|superficie corporal|bsa)\s*[:=]\s*(\d+(?:[.,]\d+)?)\s*m[²2]',
        numeric: true);
    capture('hepaticFunction',
        r'\b(?:função hepática|funci[oó]n hep[aá]tica|hepatic function)\s*[:=]\s*([^\n;]+)');
    capture('sex',
        r'\b(?:sexo|sex)\s*[:=]\s*(masculino|feminino|femenino|male|female)\b');
    capture('allergies', r'\b(?:alergias|allergies)\s*[:=]\s*([^\n;]+)');
    capture('currentMedications',
        r'\b(?:medicamentos atuais|medicaciones actuales|current medications)\s*[:=]\s*([^\n;]+)');
    capture('pregnancy',
        r'\b(?:gestante|embarazada|pregnant)\s*[:=]\s*(true|false)\b');
    for (final key in [
      'fc',
      'fr',
      'spo2',
      'temperatura',
      'creatinina',
      'potassio',
      'potasio',
      'lactato'
    ]) {
      capture(key, '\\b$key\\s*[:=]\\s*(\\d+(?:[.,]\\d+)?)', numeric: true);
    }
    if (['feminino', 'femenino', 'female'].contains(facts['sex'])) {
      facts['sex'] = 'female';
    }
    if (['masculino', 'male'].contains(facts['sex'])) facts['sex'] = 'male';
    final concentrations = RegExp(
            r'\b(\d+(?:[.,]\d+)?)\s*(mcg|mg|g)\s*/\s*(\d*(?:[.,]\d+)?)\s*ml\b',
            caseSensitive: false)
        .allMatches(text);
    final concentrationValues = <double>{};
    for (final match in concentrations) {
      try {
        final mass = ClinicalArithmetic.convertMass(
            ClinicalArithmetic.decimal(match.group(1)!),
            MassUnit.values.byName(match.group(2)!.toLowerCase()),
            MassUnit.mcg);
        final volume = match.group(3)!.isEmpty
            ? 1.0
            : ClinicalArithmetic.decimal(match.group(3)!);
        concentrationValues.add(
            ClinicalArithmetic.concentration(mass: mass, volumeMl: volume));
      } on FormatException {
        conflicts.add('concentration');
      }
    }
    if (concentrationValues.length > 1) conflicts.add('concentration');
    if (concentrationValues.length == 1 &&
        !conflicts.contains('concentration')) {
      facts['concentrationMcgMl'] = concentrationValues.single.toString();
    }
    return ClinicalFacts(values: facts, rejected: conflicts);
  }
}

class ClinicalMemorySnapshot {
  ClinicalMemorySnapshot(
      {required this.confirmedFacts,
      Iterable<String> workingHypotheses = const [],
      Iterable<String> unresolvedQuestions = const [],
      Iterable<String> rejectedAssumptions = const [],
      Iterable<String> evidenceIds = const []})
      : workingHypotheses = List.unmodifiable(workingHypotheses),
        unresolvedQuestions = List.unmodifiable(unresolvedQuestions),
        rejectedAssumptions = List.unmodifiable(rejectedAssumptions),
        evidenceIds = List.unmodifiable(evidenceIds);
  final ClinicalFacts confirmedFacts;
  final List<String> workingHypotheses,
      unresolvedQuestions,
      rejectedAssumptions,
      evidenceIds;
  String? get currentMedications => confirmedFacts.currentMedications;
  Map<String, String> get relevantLabs => Map.unmodifiable({
        for (final k in ['creatinina', 'potassio', 'potasio', 'lactato'])
          if (confirmedFacts.values[k] != null) k: confirmedFacts.values[k]!
      });
  Map<String, String> get relevantVitals => Map.unmodifiable({
        for (final k in ['fc', 'fr', 'spo2', 'temperatura'])
          if (confirmedFacts.values[k] != null) k: confirmedFacts.values[k]!
      });
}

/// RAM only, owned by the existing ClinicalSessionMemory lifecycle.
class ClinicalSafetyMemory {
  String? _uid, _sessionId;
  bool _awaitingIndication = false;
  bool acceptsIndicationReply(String text) =>
      _awaitingIndication &&
      text.trim().isNotEmpty &&
      text.length <= 160 &&
      !RegExp(r'\?|\b(?:dose|doses|dosis|peso|paciente|novo|nuevo|nova|nueva|outro|otro|mude|cambia|expl[ií]c\w*|expliqu\w*|resuma|resume|calcular|contin\w*|segu\w*|eso|isso|n[aã]o|no)\b',
              caseSensitive: false)
          .hasMatch(text);

  ClinicalFacts _facts = ClinicalFacts();
  void reset() {
    _uid = null;
    _sessionId = null;
    _awaitingIndication = false;
    _facts = ClinicalFacts();
  }

  ClinicalMemorySnapshot capture(
      {required String uid,
      required String sessionId,
      required String userQuery,
      bool newPatient = false,
      Iterable<String> priorUserTurns = const []}) {
    final differentOwner = _uid != uid || _sessionId != sessionId;
    if (differentOwner || newPatient) reset();
    if (differentOwner && !newPatient) {
      for (final prior in priorUserTurns) {
        capture(uid: uid, sessionId: sessionId, userQuery: prior);
      }
    }
    _uid = uid;
    _sessionId = sessionId;
    final supplied = ClinicalFacts.fromUserText(userQuery);
    final values = {..._facts.values};
    // Only a reply to our pending indication question supplies an unlabeled
    // indication; arbitrary assistant prose is never captured as patient data.
    if (acceptsIndicationReply(userQuery) &&
        supplied.values['indication'] == null &&
        supplied.values['weightKg'] == null &&
        userQuery.trim().isNotEmpty &&
        userQuery.length <= 160 &&
        !RegExp(r'^(?:[¿¡]\s*)?(?:contin|segu|eso|isso|n[aã]o|no\b)',
                caseSensitive: false)
            .hasMatch(userQuery.trim())) {
      values['indication'] = userQuery.trim();
    }

    // Corrections must be explicit; conflicting immutable attributes are unknown.
    final conflicts = {..._facts.rejected, ...supplied.rejected};
    for (final entry in supplied.values.entries) {
      final explicitWeightScenario = entry.key == 'weightKg' &&
          RegExp(r'^\s*[¿¡]?\s*(?:y|e)\s+para\s+', caseSensitive: false)
              .hasMatch(userQuery);
      if (!explicitWeightScenario &&
          ['ageYears', 'sex', 'weightKg', 'pregnancy'].contains(entry.key) &&
          values[entry.key] != null &&
          values[entry.key] != entry.value) {
        conflicts.add(entry.key);
        values.remove(entry.key);
      } else {
        values[entry.key] = entry.value;
      }
    }
    for (final key in conflicts) {
      values.remove(key);
    }
    _facts = ClinicalFacts(values: values, rejected: conflicts);
    _awaitingIndication = (ClinicalQueryScopePolicy.classify(userQuery) ==
                ClinicalQueryScope.calculationOrIndividualization ||
            _awaitingIndication) &&
        _facts.weightKg != null &&
        values['medicationContext'] != null &&
        values['indication'] == null;

    return ClinicalMemorySnapshot(
        confirmedFacts: _facts,
        rejectedAssumptions: conflicts,
        unresolvedQuestions: conflicts);
  }
}

class ClinicalEvidenceItem {
  const ClinicalEvidenceItem(
      {required this.id,
      required this.version,
      required this.claim,
      required this.reviewDate,
      this.medicationAuthorized = false,
      this.authorizedPolicy = false});
  final String id, version, claim;
  final DateTime? reviewDate;
  // Only an authorized structured medication adapter may set this. Protocol
  // prose, LLM DTOs, patient medications and shadow drug data are NOT authority.
  final bool medicationAuthorized;
  final bool authorizedPolicy;
  EvidenceFreshness get freshness => reviewDate == null
      ? EvidenceFreshness.unknown
      : EvidenceFreshness.reviewDateProvided;
}

class ClinicalEvidenceBundle {
  ClinicalEvidenceBundle({Iterable<ClinicalEvidenceItem> items = const []})
      : items = List.unmodifiable(items);
  final List<ClinicalEvidenceItem> items;
  static const schemaVersion = 'clinical_safety_v1';
  factory ClinicalEvidenceBundle.forRequest({
    required String query,
    required ClinicalFacts facts,
    required String language,
    ClinicalEvidenceBundle? protocolEvidence,
  }) {
    final contract = PlantaoClinicalRegimenResolver.resolve(
      query: query,
      patientAge: facts.ageYears?.toInt().toString(),
    );
    return ClinicalEvidenceBundle(items: [
      ...?protocolEvidence?.items,
      if (contract != null &&
          facts.ageYears != null &&
          facts.ageYears! >= 18 &&
          const [
            'nenhuma',
            'ninguna',
            'none',
            'negadas',
            'no conocidas',
            'sem alergias conhecidas'
          ].contains(facts.allergies))
        for (final medication in contract.medications)
          ClinicalEvidenceItem(
            id: '${PlantaoClinicalRegimenContract.sourceId}:${contract.scenario.name}:${medication.drugId}',
            version: PlantaoClinicalRegimenContract.policyVersion,
            claim: medication.line(isEs: language.startsWith('es')),
            reviewDate:
                null, // No review date invented from the policy version.
            medicationAuthorized: true, authorizedPolicy: true,
          ),
    ]);
  }

  factory ClinicalEvidenceBundle.fromMachinePack(
      PlantaoGlobalClinicalContextPack? pack) {
    if (pack == null ||
        !pack.hasMachineNativeAuthority ||
        (pack.guidelineVersion ?? '').isEmpty) {
      return ClinicalEvidenceBundle();
    }
    // Conditional/prohibited instructions cannot be promoted to unconditional facts.
    return ClinicalEvidenceBundle(items: [
      for (var i = 0; i < pack.requiredActions.length; i++)
        ClinicalEvidenceItem(
            id: '${pack.protocolKey}:required:$i',
            version: pack.guidelineVersion!,
            claim: pack.requiredActions[i],
            reviewDate: DateTime.tryParse(pack.clinicalReviewDate ?? ''))
    ]);
  }
}

class ClinicalRequestContext {
  ClinicalRequestContext(
      {required this.requestId,
      required this.sessionId,
      required this.uid,
      required this.mode,
      required this.language,
      required this.userQuery,
      required this.memory,
      required this.evidence,
      required this.createdAt,
      Iterable<String>? studyReferenceRecords,
      this.ownsRequest})
      : verifiesStudyReferences = studyReferenceRecords != null,
        studyReferences =
            StudyReferenceBoundary(studyReferenceRecords ?? const []),
        knownFacts = memory.confirmedFacts,
        unknownCriticalFacts = List.unmodifiable(mode == AiRequestMode.estudo
            ? _studyMissing(userQuery, memory.confirmedFacts)
            : _missing(userQuery, memory.confirmedFacts,
                generalEducation: true));
  final String requestId, sessionId, uid, language, userQuery;
  final bool Function()? ownsRequest;
  final AiRequestMode mode;
  final ClinicalMemorySnapshot memory;
  final ClinicalFacts knownFacts;
  final ClinicalEvidenceBundle evidence;
  final StudyReferenceBoundary studyReferences;
  final bool verifiesStudyReferences;
  final DateTime createdAt;
  final List<String> unknownCriticalFacts;
  double? get patientAge => knownFacts.ageYears;
  String? get sex => knownFacts.sex;
  double? get weightKg => knownFacts.weightKg;
  double? get renalFunction => knownFacts.renalFunction;
  bool? get pregnancy => knownFacts.pregnancy;
  String? get allergies => knownFacts.allergies;
  String? get currentMedications => knownFacts.currentMedications;

  ClinicalQueryScope get queryScope => mode == AiRequestMode.estudo
      ? StudyQueryScope.classify(userQuery)
      : ClinicalQueryScopePolicy.classify(userQuery);
  bool get isGeneralEducationalQuery =>
      queryScope == ClinicalQueryScope.generalEducational;
  bool get isStudyMixedRequest =>
      mode == AiRequestMode.estudo &&
      queryScope == ClinicalQueryScope.calculationOrIndividualization &&
      StudyQueryScope.hasEducationalRequest(userQuery);

  bool get isOperationalRequest =>
      !isGeneralEducationalQuery &&
      !ClinicalDoseScope.referenceRequest(userQuery) &&
      (ClinicalSafetyPass.operational(userQuery) ||
          (!RegExp(r'(?:curva|rela[çc][aã]o|relaci[oó]n) dose.resposta|dose.response',
                      caseSensitive: false)
                  .hasMatch(userQuery) &&
              RegExp(r'\b(?:dose|dosis|posologia|prescri|preparo|dilui|diluci|infus|mg/kg|mcg/kg|ml/h|ajuste renal|ajuste hep)',
                      caseSensitive: false)
                  .hasMatch(userQuery)));

  Answerability get answerability => knownFacts.rejected.isNotEmpty &&
          !(mode == AiRequestMode.estudo && isGeneralEducationalQuery)
      ? Answerability.abstain
      : unknownCriticalFacts.isNotEmpty
          ? (isStudyMixedRequest ||
                  (mode != AiRequestMode.estudo &&
                      ClinicalDoseScope.referenceLabel(userQuery))
              ? Answerability.answerWithLimitations
              : Answerability.askForMissingData)
          : evidence.items.isEmpty
              ? Answerability.answerWithLimitations
              : Answerability.answer;
  bool get mayGenerate =>
      answerability != Answerability.abstain &&
      answerability != Answerability.askForMissingData;

  /// A weight assertion is not an authorized pharmacological rule. No rule is
  /// inferred from model prose or shadow data; existing typed evidence alone
  /// can authorize a personalized medication output.
  String? get unsupportedWeightCalculationMessage {
    if (queryScope != ClinicalQueryScope.calculationOrIndividualization ||
        weightKg == null ||
        unknownCriticalFacts.isNotEmpty ||
        knownFacts.rejected.isNotEmpty ||
        knownFacts.values['medicationContext'] == null ||
        knownFacts.values['indication'] == null ||
        !RegExp(r'\b(?:dose|dosis|doses)\b', caseSensitive: false)
            .hasMatch(userQuery) ||
        evidence.items.any((item) => item.medicationAuthorized)) return null;
    final drug = knownFacts.values['medicationContext']!;
    final indication = knownFacts.values['indication']!;
    final weight =
        weightKg! % 1 == 0 ? weightKg!.toInt().toString() : weightKg.toString();
    return language.startsWith('es')
        ? 'Tengo $drug, la indicación $indication y el peso $weight kg. No dispongo de una regla posológica autorizada para calcular esta dosis individualizada. Confirma el esquema de esa indicación en el protocolo vigente; conservaré estos datos en la conversación.'
        : 'Tenho $drug, a indicação $indication e o peso $weight kg. Não disponho de uma regra posológica autorizada para calcular esta dose individualizada. Confirme o esquema dessa indicação no protocolo vigente; manterei estes dados na conversa.';
  }

  void requireTransport({required String mode, required String language}) {
    if (mode != this.mode.name ||
        language != this.language ||
        !mayGenerate ||
        ownsRequest?.call() == false) {
      AiStreamTrace.mark(
          'TRANSPORT_MODE_MATCH', mode == this.mode.name ? 1 : 0);
      AiStreamTrace.mark(
          'TRANSPORT_LANGUAGE_MATCH', language == this.language ? 1 : 0);
      AiStreamTrace.mark('TRANSPORT_MAY_GENERATE', mayGenerate ? 1 : 0);
      AiStreamTrace.mark('REFUSAL_TRANSPORT_REJECTED', 0);
      throw StateError('CLINICAL_SAFETY_TRANSPORT_REJECTED');
    }
  }

  static List<String> _missing(String query, ClinicalFacts facts,
      {bool generalEducation = false}) {
    if (generalEducation &&
        ClinicalQueryScopePolicy.classify(query) ==
            ClinicalQueryScope.generalEducational) {
      return const [];
    }
    if (!generalEducation && ClinicalDoseScope.referenceRequest(query))
      return const [];
    final q = query.toLowerCase();
    final dose = RegExp(
            r'\b(?:dose|doses|dosis|posologia|posología|ajuste|ajustar|calcular|calcule|calcula)\b|\b(?:mg|mcg)\s*/\s*kg',
            caseSensitive: false)
        .hasMatch(q);
    final pediatric =
        RegExp(r'pedi[aá]tr|crian[çc]a|niñ[oa]|neonat|lactente').hasMatch(q) ||
            (facts.ageYears != null && facts.ageYears! < 18);
    final missing = <String>[];
    // A bare hepatic-class adjustment supplies no target medication/regimen.
    // Ask for that context, not the Child-Pugh class already stated by the user.
    if (generalEducation &&
        ClinicalQueryScopePolicy.classify(query) ==
            ClinicalQueryScope.calculationOrIndividualization &&
        RegExp(r'^\s*[¿¡]?\s*(?:ajuste|ajusta|ajustar)\s+(?:(?:para|por|com|con)\s+)?child[ -]?pugh\s*[abc]\s*[?.]?\s*$')
            .hasMatch(q)) {
      missing.add('medicationContext');
    }
    if (generalEducation && dose && pediatric && facts.ageYears == null) {
      missing.add('ageYears');
    }
    if (dose &&
        ClinicalDoseScope.individualized(query) &&
        RegExp(r'(?:deste|desse|este|esse|este) medicamento|this medication')
            .hasMatch(q)) {
      missing.add('medicationContext');
    }
    if (dose && ClinicalDoseScope.individualized(query)) {
      if (RegExp(r'idade|edad|pedi[aá]tr|crian[çc]a|niñ[oa]').hasMatch(q) &&
          facts.ageYears == null) missing.add('ageYears');
      if (RegExp(r'gesta|gr[aá]vid|embaraz').hasMatch(q) &&
          facts.pregnancy == null) missing.add('pregnancy');
      if (RegExp(r'superf[ií]cie|superficie|m2|m²|\bbsa\b').hasMatch(q) &&
          facts.number('bodySurfaceArea') == null)
        missing.add('bodySurfaceArea');
      if (RegExp(r'intera[çc]|interacci').hasMatch(q) &&
          facts.currentMedications == null) missing.add('currentMedications');
    }
    if (dose &&
        (pediatric ||
            RegExp(r'(?:m[gc]g|µg)\s*/\s*kg|por peso|obesidade|obesidad')
                .hasMatch(q)) &&
        facts.weightKg == null) {
      missing.add('weightKg');
    }
    if (dose &&
        RegExp(r'renal|clcr|egfr|tfg|di[aá]lis').hasMatch(q) &&
        facts.renalFunction == null) {
      missing.add('renalFunction');
    }
    if (dose &&
        RegExp(r'hep[aá]tic|f[ií]gado|h[ií]gado').hasMatch(q) &&
        facts.values['hepaticFunction'] == null) {
      missing.add('hepaticFunction');
    }
    if (RegExp(r'infus|dilui|dilu[cç]|ml\s*/\s*h|bomba').hasMatch(q) &&
        RegExp(r'c[aá]lcul|ml\s*/\s*h|prepar|dilu|velocidade|velocidad|dose|dosis|administr|infundir')
            .hasMatch(q)) {
      if (facts.number('concentrationMcgMl') == null) {
        missing.add('concentration');
      }
      if (RegExp(r'/\s*kg|por peso').hasMatch(q) &&
          facts.weightKg == null &&
          !missing.contains('weightKg')) {
        missing.add('weightKg');
      }
    }
    if (generalEducation &&
        dose &&
        missing.isEmpty &&
        facts.values.keys
            .every((k) => k == 'medicationContext' || k == 'indication') &&
        RegExp(r'(?:este|esse|meu|mi)\s+paciente', caseSensitive: false)
            .hasMatch(query)) {
      missing.add('medicationContext');
    }
    if (dose &&
        ClinicalQueryScopePolicy.classify(query) ==
            ClinicalQueryScope.calculationOrIndividualization &&
        facts.weightKg != null &&
        facts.values['medicationContext'] != null &&
        facts.values['indication'] == null) {
      missing.add('indication');
    }
    return missing;
  }

  static List<String> _studyMissing(String query, ClinicalFacts facts) {
    final scope = StudyQueryScope.classify(query);
    if (scope == ClinicalQueryScope.generalEducational) return const [];
    final missing = _missing(query, facts, generalEducation: true).toSet();
    // A number such as eGFR 22 does not identify the medicine, indication or
    // regimen to adjust. Neither does “exact dose for this case”.
    if (scope == ClinicalQueryScope.calculationOrIndividualization &&
        (RegExp(r'^\s*(?:calcule|calcula|ajuste|ajusta)\s+(?:para\s+)?(?:este paciente|eGFR\s*\d+|Child[ -]?Pugh\s*[ABC])\s*[?.]?\s*$',
                    caseSensitive: false)
                .hasMatch(query) ||
            RegExp(r'\b(?:dose|dosis)\s+(?:exat[ao]|exact[ao])\s+para\s+(?:este|esse)\s+caso',
                    caseSensitive: false)
                .hasMatch(query) ||
            RegExp(r'\b(?:calcule|calcula)\b.{0,40}\b(?:este|esse|meu|mi)\s+paciente',
                    caseSensitive: false)
                .hasMatch(query))) {
      missing.add('medicationContext');
    }
    return missing.toList();
  }

  String get safeMessage {
    final es = language.startsWith('es');
    if (unknownCriticalFacts.length == 1 &&
        unknownCriticalFacts.single == 'indication') {
      final weight = weightKg! % 1 == 0
          ? weightKg!.toInt().toString()
          : weightKg.toString();
      final drug = knownFacts.values['medicationContext']!;
      return es
          ? 'Ya tengo el peso: $weight kg. ¿Cuál es la indicación clínica para $drug?'
          : 'Já tenho o peso: $weight kg. Qual é a indicação clínica de $drug?';
    }
    if (unknownCriticalFacts.isNotEmpty) {
      final labels = {
        'medicationContext': es
            ? 'medicamento, indicación y datos del paciente relevantes al ajuste'
            : 'medicamento, indicação e dados do paciente relevantes ao ajuste',
        'weightKg': es ? 'peso en kg' : 'peso em kg',
        'renalFunction': es
            ? 'función renal (ClCr/eGFR con unidad)'
            : 'função renal (ClCr/eGFR com unidade)',
        'hepaticFunction': es ? 'función hepática' : 'função hepática',
        'ageYears': es ? 'edad' : 'idade',
        'pregnancy': es ? 'estado de gestación' : 'estado de gestação',
        'bodySurfaceArea': es ? 'superficie corporal' : 'superfície corporal',
        'currentMedications':
            es ? 'medicaciones actuales' : 'medicamentos atuais',
        'concentration': es
            ? 'formulación y concentración (masa/volumen)'
            : 'formulação e concentração (massa/volume)'
      };
      return '${es ? 'Datos necesarios' : 'Dados necessários'}: ${unknownCriticalFacts.map((k) => labels[k] ?? k).join('; ')}. ${es ? 'No se calculó una dosis individualizada.' : 'Nenhuma dose individualizada foi calculada.'}';
    }
    return es
        ? 'No hay soporte verificable suficiente para presentar esta respuesta clínica con seguridad. Confirma los datos del caso y consulta una fuente clínica autorizada.'
        : 'Não há suporte verificável suficiente para apresentar esta resposta clínica com segurança. Confirme os dados do caso e consulte uma fonte clínica autorizada.';
  }
}

class ClinicalClaimBinding {
  const ClinicalClaimBinding(
      {required this.claim,
      this.evidenceId,
      this.evidenceVersion,
      required this.fidelity,
      required this.freshness,
      required this.certainty});
  final String claim;
  final String? evidenceId, evidenceVersion;
  final EvidenceFidelity fidelity;
  final EvidenceFreshness freshness;
  final ClinicalCertainty certainty;
}

class ClinicalSafetyResult {
  ClinicalSafetyResult(
      {required Map<SafetyGate, SafetyVerdict> gates,
      required Iterable<ClinicalClaimBinding> claims,
      required this.numericChecks,
      required this.contradictions})
      : gates = Map.unmodifiable(gates),
        claims = List.unmodifiable(claims);
  final Map<SafetyGate, SafetyVerdict> gates;
  final List<ClinicalClaimBinding> claims;
  final int numericChecks, contradictions;
  bool get allowed => !gates.values.contains(SafetyVerdict.failClosed);
  String telemetry(ClinicalRequestContext c) =>
      '[AI_SAFETY] requestIdHash=${c.requestId.hashCode.toUnsigned(32)} mode=${c.mode.name} answerability=${c.answerability.name} evidenceCount=${c.evidence.items.length} numericChecks=$numericChecks contradictions=$contradictions result=${allowed ? 'PASS' : 'FAIL_CLOSED'}';
}

class ClinicalSafetyPass {
  static String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[*#_`]'), '')
      .replaceFirst(RegExp(r'^\s*(?:[•●▪-]|\d+[.)])\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  static bool medicationOperation(String text,
      {bool laboratoryMeasurements = false}) {
    // Serum/plasma laboratory concentrations are measurements, not doses.
    // Do not exempt formulations, routes or administration instructions.
    final laboratoryContext = RegExp(
            r'\b(?:s[eé]ric[oa]s?|plasm[aá]tic[oa]s?)\b',
            caseSensitive: false)
        .hasMatch(text);
    final administrationContext = RegExp(
            r'\b(?:iv|vo|sc|im|intraven\w*|infus\w*|infund\w*|dilu\w*|prepar\w*|administr\w*|prescri\w*)\b',
            caseSensitive: false)
        .hasMatch(text);
    final candidate =
        laboratoryMeasurements && laboratoryContext && !administrationContext
            ? text.replaceAll(
                RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:meq|mmol)\s*/\s*l\b',
                    caseSensitive: false),
                '')
            : text;
    return RegExp(
            r'\b\d+(?:[.,]\d+)?\s*(?:mg|mcg|ug|µg|g|ml|u|ui|iu|meq|mmol|gotas?|comprimidos?|ampolas?)\b|'
            r'\b(?:dose|dosis|posologia|via|intervalo|preparo|dilui[çc][aã]o|diluci[oó]n|formula[çc][aã]o|concentra[çc][aã]o)\s*[:=]\s*\S|'
            r'\b(?:administrar|administre|administr[eé]|prescrever|prescreva|prescribir|tomar|tome|injete|injetar|diluir|dilua|infundir|receber|receba|usar|use|utilize|titular|recomenda-se|recomienda)\b|'
            r'\bvia\s+(?:oral|intravenosa|intramuscular|subcutanea|subcutânea)|\b(?:mg|mcg|µg)\s*/\s*kg|\bml\s*/\s*h',
            caseSensitive: false)
        .hasMatch(candidate);
  }

  static bool operational(String text, {bool laboratoryMeasurements = false}) =>
      medicationOperation(text,
          laboratoryMeasurements: laboratoryMeasurements) ||
      RegExp(r'\b(?:iniciar|inicie|suspender|suspenda|indicar|indique|intubar|intube|realizar|realize|internar|alta hospital|diagn[oó]stico confirmado)\b',
              caseSensitive: false)
          .hasMatch(text);

  /// Terminal headings establish scope; an invented drug without a number in
  /// a prescription section cannot evade the operational gate.
  static Iterable<String> _criticalLines(String output,
      {bool laboratoryMeasurements = false}) sync* {
    var prescriptionSection = false;
    for (final line in output.split('\n')) {
      final n = _normalize(line);
      if (n.isEmpty) continue;
      if (RegExp(
              r'^(?:tratamento farmacol[oó]gico|tratamiento farmacol[oó]gico|prescri[çc][aã]o|prescripci[oó]n|posologia|doses|dosis)\s*:?$')
          .hasMatch(n)) {
        prescriptionSection = true;
        continue;
      }
      if (RegExp(r'^\s*#{1,4}\s').hasMatch(line) &&
          !operational(line, laboratoryMeasurements: laboratoryMeasurements)) {
        prescriptionSection = false;
      }
      if (prescriptionSection ||
          operational(line, laboratoryMeasurements: laboratoryMeasurements))
        yield line;
    }
  }

  static ClinicalSafetyResult evaluate(
      {required ClinicalRequestContext context,
      required String output,
      required AiRequestMode outputMode,
      Iterable<String> structuredClaims = const []}) {
    final gates = {
      for (final gate in SafetyGate.values) gate: SafetyVerdict.notApplicable
    };
    gates[SafetyGate.modeMatch] = outputMode == context.mode
        ? SafetyVerdict.pass
        : SafetyVerdict.failClosed;
    gates[SafetyGate.criticalDataComplete] = context.mayGenerate &&
            ClinicalRequestContext._missing(output, context.knownFacts,
                    generalEducation: context.isGeneralEducationalQuery)
                .isEmpty
        ? SafetyVerdict.pass
        : SafetyVerdict.failClosed;
    final outputFacts = ClinicalFacts.fromUserText(output);
    var contradictions =
        context.knownFacts.rejected.length + outputFacts.rejected.length;
    final generalConditionalReference = context.isGeneralEducationalQuery &&
        context.knownFacts.values.isEmpty &&
        !ClinicalDoseScope.patientSpecificFragment(output) &&
        RegExp(r'\b(?:si|se|cuando|quando|en caso|em caso)\b|[<>≤≥]|\b(?:mayores|menores|maiores)\s+de\s+\d',
                caseSensitive: false)
            .hasMatch(output);
    for (final entry in outputFacts.values.entries) {
      // Conditional population thresholds are not asserted patient facts.
      if (!generalConditionalReference &&
          context.knownFacts.values[entry.key] != entry.value) {
        contradictions++;
      }
    }
    final negative = RegExp(
        r'\b(?:sem|sin|nao|não|no|ausente|nega|niega|denies|without)\b',
        caseSensitive: false);
    for (final sentence in output.split(RegExp(r'[\n;.!?]+'))) {
      if (!negative.hasMatch(sentence)) continue;
      final positiveText = sentence.replaceAll(negative, '');
      final contradictedFacts = ClinicalFacts.fromUserText(positiveText);
      if (contradictedFacts.values.keys
          .any(context.knownFacts.values.containsKey)) {
        contradictions++;
      }
      final findings = context.knownFacts.values['findings'];
      if (findings != null &&
          findings.split(',').any((f) =>
              f.trim().isNotEmpty &&
              sentence.toLowerCase().contains(f.trim().toLowerCase()))) {
        contradictions++;
      }
    }
    gates[SafetyGate.contradictionCheck] =
        contradictions == 0 ? SafetyVerdict.pass : SafetyVerdict.failClosed;
    final equations = ClinicalArithmetic.validateClinicalEquations(
        output, context.knownFacts);
    if (equations != null) {
      gates[SafetyGate.numericValidation] =
          equations ? SafetyVerdict.pass : SafetyVerdict.failClosed;
    }
    final claims = <ClinicalClaimBinding>[];
    var numericChecks = equations == null ? 0 : 1;
    final lines = {
      ..._criticalLines(output,
          laboratoryMeasurements: context.mode == AiRequestMode.plantao),
      ...structuredClaims.where((s) => s.trim().isNotEmpty)
    };
    for (final line in lines) {
      final mathOnly = ClinicalArithmetic.isPureMassEquation(line);
      if (mathOnly && ClinicalArithmetic.validateMassEquations(line) == true) {
        claims.add(ClinicalClaimBinding(
            claim: line,
            evidenceId: 'SI_MASS_CONVERSION',
            evidenceVersion: 'g_mg_mcg_v1',
            fidelity: EvidenceFidelity.exact,
            freshness: EvidenceFreshness.unknown,
            certainty: ClinicalCertainty.confirmed));
        continue;
      }
      final medication = medicationOperation(line,
          laboratoryMeasurements: context.mode == AiRequestMode.plantao);
      final normalized = _normalize(line);
      ClinicalEvidenceItem? evidence;
      for (final item in context.evidence.items) {
        if (item.id.isNotEmpty &&
            item.version.isNotEmpty &&
            (item.authorizedPolicy ||
                (item.reviewDate != null &&
                    !item.reviewDate!.isAfter(context.createdAt))) &&
            (!medication || item.medicationAuthorized) &&
            _normalize(item.claim) == normalized) {
          evidence = item;
          break;
        }
      }
      // Exact claim binding deliberately rejects partial regimens/negation changes.
      final supported = evidence != null;
      claims.add(ClinicalClaimBinding(
          claim: line,
          evidenceId: evidence?.id,
          evidenceVersion: evidence?.version,
          fidelity:
              supported ? EvidenceFidelity.exact : EvidenceFidelity.unsupported,
          freshness: evidence?.freshness ?? EvidenceFreshness.unknown,
          certainty: supported
              ? ClinicalCertainty.confirmed
              : ClinicalCertainty.insufficientData));
      if (medication) {
        gates[SafetyGate.medicationEvidence] = !supported ||
                gates[SafetyGate.medicationEvidence] == SafetyVerdict.failClosed
            ? SafetyVerdict.failClosed
            : SafetyVerdict.pass;
      }
      if (RegExp(r'\d|NaN|Infinity', caseSensitive: false).hasMatch(line)) {
        numericChecks++;
        // Free-text computed regimens have no typed operands/provenance. Do not
        // pretend a regex has verified their arithmetic. Authorized exact values
        // are retained; newly calculated values require the typed arithmetic API.
        final numericEquation = ClinicalArithmetic.validateClinicalEquations(
            line, context.knownFacts);
        if ((!supported && numericEquation != true) ||
            numericEquation == false ||
            RegExp(r'NaN|Infinity|\b0\s*(?:kg|mg|mcg|ml)\b',
                    caseSensitive: false)
                .hasMatch(line)) {
          gates[SafetyGate.numericValidation] = SafetyVerdict.failClosed;
        } else if (gates[SafetyGate.numericValidation] !=
            SafetyVerdict.failClosed) {
          gates[SafetyGate.numericValidation] = SafetyVerdict.pass;
        }
      }
    }
    if (context.isOperationalRequest &&
        context.evidence.items.isEmpty &&
        claims.isEmpty) {
      gates[SafetyGate.unsupportedCriticalClaims] = SafetyVerdict.failClosed;
    }
    if (claims.isNotEmpty) {
      final verdict = claims.every((c) => c.fidelity == EvidenceFidelity.exact)
          ? SafetyVerdict.pass
          : SafetyVerdict.failClosed;
      gates[SafetyGate.evidenceBinding] = verdict;
      gates[SafetyGate.unsupportedCriticalClaims] = verdict;
    }
    return ClinicalSafetyResult(
        gates: gates,
        claims: claims,
        numericChecks: numericChecks,
        contradictions: contradictions);
  }
}
