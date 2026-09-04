class PlantaoGlobalClinicalContextPack {
  const PlantaoGlobalClinicalContextPack({
    this.pathologyKey,
    this.protocolKey,
    this.guidelineVersion,
    this.clinicalReviewDate,
    this.requiredActions = const <String>[],
    this.prohibitedActions = const <String>[],
    this.conditionalActions = const <String>[],
    this.classificationDependencies = const <String>[],
    this.scoreDependencies = const <String>[],
    this.authoritative = false,
  });

  final String? pathologyKey;
  final String? protocolKey;
  final String? guidelineVersion;
  final String? clinicalReviewDate;
  final List<String> requiredActions;
  final List<String> prohibitedActions;
  final List<String> conditionalActions;
  final List<String> classificationDependencies;
  final List<String> scoreDependencies;
  final bool authoritative;

  bool get hasMachineNativeAuthority =>
      authoritative &&
      (pathologyKey?.trim().isNotEmpty ?? false) &&
      (protocolKey?.trim().isNotEmpty ?? false);
}

class PlantaoGlobalClinicalGateIssue {
  const PlantaoGlobalClinicalGateIssue({
    required this.code,
    required this.critical,
    required this.detail,
  });

  final String code;
  final bool critical;
  final String detail;
}

class PlantaoGlobalClinicalGateResult {
  const PlantaoGlobalClinicalGateResult({
    required this.finalText,
    required this.issues,
    required this.projected,
    required this.machineAuthorityEvaluated,
  });

  final String finalText;
  final List<PlantaoGlobalClinicalGateIssue> issues;
  final bool projected;
  final bool machineAuthorityEvaluated;

  bool get hasCriticalIssue => issues.any((issue) => issue.critical);
}

class PlantaoGlobalClinicalResponseGate {
  const PlantaoGlobalClinicalResponseGate._();

  static const String contractVersion = 'M56B_GLOBAL_CLINICAL_RESPONSE_GATE_V1';

  static PlantaoGlobalClinicalGateResult finalizeForPresentation({
    required String userText,
    required String rawText,
    required String language,
    PlantaoGlobalClinicalContextPack? contextPack,
    bool enforceRequiredActions = true,
  }) {
    final normalized = _stripDecorativePictographs(
      rawText,
    ).replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    if (normalized.isEmpty) {
      return const PlantaoGlobalClinicalGateResult(
        finalText: '',
        issues: <PlantaoGlobalClinicalGateIssue>[
          PlantaoGlobalClinicalGateIssue(
            code: 'empty_final_text',
            critical: true,
            detail: 'Provider returned empty clinical text.',
          ),
        ],
        projected: false,
        machineAuthorityEvaluated: false,
      );
    }

    final canonicalProjected = _projectCanonicalSections(
      normalized,
      language: language,
    );
    final projected = _m70bDeduplicateDetailedRegimenAcrossSections(
      canonicalProjected,
    );
    // M70C_PRE_DEDUP_MACHINE_VALIDATION_POST_DEDUP_PRESENTATION_V1
    // Two representations, two responsibilities:
    // - canonicalProjected: complete clinical evidence used by machine-native
    //   required/prohibited action validation (M61/M62/M63 safety contract).
    // - projected: user-visible presentation after conservative M70B
    //   cross-section regimen dedup.
    // Presentation compression must never erase evidence before safety checks.
    final issues = <PlantaoGlobalClinicalGateIssue>[
      ..._validatePresentation(projected),
      if (contextPack != null)
        ..._validateAgainstMachinePack(
          canonicalProjected,
          contextPack,
          enforceRequiredActions: enforceRequiredActions,
        ),
    ];

    return PlantaoGlobalClinicalGateResult(
      finalText: projected,
      issues: issues,
      projected: projected != normalized,
      machineAuthorityEvaluated:
          contextPack?.hasMachineNativeAuthority ?? false,
    );
  }

  // M70B_CROSS_SECTION_DETAILED_REGIMEN_DEDUP_V1
  // Conservative post-provider normalization: remove from Conducta/Conduta
  // inmediata only regimen fragments already present in Tratamiento/Tratamento
  // farmacológico for the same medication identity. Never invent/move content.
  // Never call a provider/network from this gate.
  static final RegExp _m70bDoseFragment = RegExp(
    r'\b\d+(?:[.,]\d+)?\s*'
    r'(?:mcg|ug|µg|mg|g|ml|l|u|ui|iu|meq|mmol)'
    r'(?:\s*/\s*(?:kg|ml|l|h|min))?'
    r'(?:\s*/\s*(?:h|min))?\b',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _m70bIntervalFragment = RegExp(
    r'\b(?:cada|a\s+los|apos|após|despues\s+de|después\s+de|'
    r'repetir(?:\s+cada)?|repetir\s+em)\s+'
    r'\d+(?:\s*[-–]\s*\d+)?\s*(?:min(?:utos?)?|h(?:oras?)?)\b',
    caseSensitive: false,
    unicode: true,
  );

  static const Set<String> _m70bMedicationIdentityStopWords = <String>{
    'administrar',
    'administre',
    'administracao',
    'administracion',
    'iniciar',
    'inicie',
    'aplicar',
    'aplique',
    'usar',
    'use',
    'dar',
    'oferecer',
    'ofrecer',
    'farmaco',
    'medicamento',
    'tratamiento',
    'tratamento',
    'solucion',
    'solucao',
    'intravenoso',
    'intravenosa',
    'intramuscular',
    'subcutaneo',
    'subcutanea',
    'oral',
    'via',
    'bolo',
    'bolus',
    'infusion',
    'infusao',
    'iv',
    'ev',
    'im',
    'vo',
    'sc',
  };

  static String _m70bDeduplicateDetailedRegimenAcrossSections(String text) {
    final lines = text.split('\n');
    final treatmentLines = <String>[];
    String? active;

    for (final line in lines) {
      final key = _sectionKey(line.trim());
      if (key != null) {
        active = key;
        continue;
      }
      if (active == 'treatment' && line.trim().isNotEmpty) {
        treatmentLines.add(line);
      }
    }
    if (treatmentLines.isEmpty) return text;

    active = null;
    var changed = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final key = _sectionKey(line.trim());
      if (key != null) {
        active = key;
        continue;
      }
      if (active != 'immediate' || line.trim().isEmpty) continue;
      final out = _m70bDeduplicateImmediateLine(line, treatmentLines);
      if (out != line) {
        lines[i] = out;
        changed = true;
      }
    }
    return changed ? lines.join('\n').trim() : text;
  }

  static String _m70bDeduplicateImmediateLine(
    String line,
    List<String> treatmentLines,
  ) {
    final identity = _m70bMedicationIdentityTokens(line);
    final fragments = _m70bFragments(line);
    if (identity.isEmpty || fragments.isEmpty) return line;

    String? bestTreatment;
    var bestShared = 0;
    for (final treatment in treatmentLines) {
      final treatmentIdentity = _m70bMedicationIdentityTokens(treatment);
      if (treatmentIdentity.isEmpty ||
          identity.intersection(treatmentIdentity).isEmpty) {
        continue;
      }
      final treatmentFolded = _fold(treatment);
      var shared = 0;
      for (final fragment in fragments) {
        if (treatmentFolded.contains(_fold(fragment))) shared++;
      }
      if (shared > bestShared) {
        bestShared = shared;
        bestTreatment = treatment;
      }
    }
    if (bestTreatment == null || bestShared == 0) return line;

    final treatmentFolded = _fold(bestTreatment);
    final clauses = line.split(';');
    final kept = <String>[];
    for (var i = 0; i < clauses.length; i++) {
      final original = clauses[i];
      final folded = _fold(
        original,
      ).replaceAll(RegExp(r'^[#*_\-\s•]+'), '').trim();

      if (i > 0 &&
          _m70bIsDetailOnlyClause(folded) &&
          folded.length >= 5 &&
          treatmentFolded.contains(folded)) {
        continue;
      }

      var clause = _m70bRemoveOwnedFragments(
        original,
        treatmentFolded: treatmentFolded,
      );
      clause = clause
          .replaceAll(
            RegExp(
              r'\s+(?:de\s+la|da|de)\s+soluci[oó]n'
              r'(?=\s+(?:en|na|no|por|;|,|\.|$))',
              caseSensitive: false,
              unicode: true,
            ),
            '',
          )
          .replaceAll(RegExp(r'\(\s*\)'), '')
          .replaceAll(RegExp(r'\s+([,.;])'), r'$1')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();

      if (clause.isEmpty) continue;
      if (i > 0 &&
          RegExp(
            r'^(maximo|máximo)\b',
            caseSensitive: false,
          ).hasMatch(clause) &&
          !_m70bDoseFragment.hasMatch(clause)) {
        continue;
      }
      kept.add(clause);
    }

    if (kept.isEmpty) return line;
    final out = kept
        .join('; ')
        .replaceAll(RegExp(r';\s*;'), ';')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(out) || out.length < 8) return line;
    return out;
  }

  static String _m70bRemoveOwnedFragments(
    String input, {
    required String treatmentFolded,
  }) {
    final matches = <RegExpMatch>[
      ..._m70bDoseFragment.allMatches(input),
      ..._m70bIntervalFragment.allMatches(input),
    ]..sort((a, b) => b.start.compareTo(a.start));

    var out = input;
    for (final match in matches) {
      final fragment = match.group(0);
      if (fragment == null || fragment.trim().isEmpty) continue;
      if (!treatmentFolded.contains(_fold(fragment))) continue;
      out = out.replaceRange(match.start, match.end, '');
    }
    return out;
  }

  static List<String> _m70bFragments(String line) => <String>[
    for (final match in _m70bDoseFragment.allMatches(line))
      if ((match.group(0) ?? '').trim().isNotEmpty) match.group(0)!.trim(),
    for (final match in _m70bIntervalFragment.allMatches(line))
      if ((match.group(0) ?? '').trim().isNotEmpty) match.group(0)!.trim(),
  ];

  static Set<String> _m70bMedicationIdentityTokens(String line) {
    final dose = _m70bDoseFragment.firstMatch(line);
    final interval = _m70bIntervalFragment.firstMatch(line);
    var boundary = line.length;
    if (dose != null && dose.start < boundary) boundary = dose.start;
    if (interval != null && interval.start < boundary)
      boundary = interval.start;

    final prefix = _fold(
      line.substring(0, boundary),
    ).replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();
    return prefix
        .split(RegExp(r'\s+'))
        .where(
          (token) =>
              token.length >= 3 &&
              !_m70bMedicationIdentityStopWords.contains(token),
        )
        .toSet();
  }

  static bool _m70bIsDetailOnlyClause(String folded) {
    return folded.startsWith('maximo') ||
        folded.startsWith('repetir') ||
        folded.startsWith('cada ') ||
        folded.startsWith('intervalo') ||
        folded.startsWith('frecuencia') ||
        folded.startsWith('frequencia') ||
        folded.startsWith('administrar en ') ||
        folded.startsWith('administrar em ');
  }

  static List<PlantaoGlobalClinicalGateIssue> _validatePresentation(
    String text,
  ) {
    final issues = <PlantaoGlobalClinicalGateIssue>[];
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      issues.add(
        const PlantaoGlobalClinicalGateIssue(
          code: 'missing_title',
          critical: true,
          detail: 'No visible pathology/topic title.',
        ),
      );
      return issues;
    }

    if (_isGenericTaskHeading(lines.first)) {
      issues.add(
        const PlantaoGlobalClinicalGateIssue(
          code: 'generic_task_title',
          critical: true,
          detail:
              'First visible heading is a task instead of a pathology/topic.',
        ),
      );
    }

    final lower = _fold(text);
    final immediate = _firstIndexOfAny(lower, const <String>[
      'conducta inmediata',
      'conduta imediata',
      'manejo inmediato',
    ]);
    final treatment = _firstIndexOfAny(lower, const <String>[
      'tratamiento farmacologico',
      'tratamento farmacologico',
    ]);
    if (treatment >= 0 && immediate >= 0 && treatment < immediate) {
      issues.add(
        const PlantaoGlobalClinicalGateIssue(
          code: 'treatment_before_immediate',
          critical: true,
          detail: 'Pharmacologic treatment appears before immediate conduct.',
        ),
      );
    }

    return issues;
  }

  static List<PlantaoGlobalClinicalGateIssue> _validateAgainstMachinePack(
    String text,
    PlantaoGlobalClinicalContextPack pack, {
    bool enforceRequiredActions = true,
  }) {
    if (!pack.hasMachineNativeAuthority) {
      return const <PlantaoGlobalClinicalGateIssue>[];
    }

    final haystack = _fold(text);
    final issues = <PlantaoGlobalClinicalGateIssue>[];

    // M64_FOCUSED_CONTINUATION_MACHINE_GATE_SCOPE_V1
    // Historical requiredActions are mandatory on initial/full-treatment
    // responses. Focused non-treatment continuations (e.g. disposition,
    // monitoring/evolution, exams) validate their requested scope without
    // forcing a replay of already-satisfied acute actions. Prohibited actions
    // remain enforced for every turn.
    if (enforceRequiredActions) {
      for (final requiredAction in pack.requiredActions) {
        final needle = _fold(requiredAction).trim();
        if (needle.isEmpty) continue;
        if (!_containsClinicalAction(
          haystack,
          needle,
          matchNeedlePolarity: true,
        )) {
          issues.add(
            PlantaoGlobalClinicalGateIssue(
              code: 'required_action_missing',
              critical: true,
              detail: requiredAction,
            ),
          );
        }
      }
    }

    for (final prohibitedAction in pack.prohibitedActions) {
      final needle = _fold(prohibitedAction).trim();
      if (needle.isEmpty) continue;
      if (_containsClinicalAction(
        haystack,
        needle,
        requirePositiveRecommendation: true,
      )) {
        issues.add(
          PlantaoGlobalClinicalGateIssue(
            code: 'prohibited_action_present',
            critical: true,
            detail: prohibitedAction,
          ),
        );
      }
    }

    return issues;
  }

  static String _projectCanonicalSections(
    String text, {
    required String language,
  }) {
    final rawLines = text.split('\n');
    final nonEmpty = <int>[
      for (var i = 0; i < rawLines.length; i++)
        if (rawLines[i].trim().isNotEmpty) i,
    ];
    if (nonEmpty.isEmpty) return text;

    var titleIndex = nonEmpty.first;
    if (_isGenericTaskHeading(rawLines[titleIndex])) {
      for (final index in nonEmpty.skip(1)) {
        final candidate = rawLines[index].trim();
        if (!_isKnownSectionHeading(candidate) &&
            !_isGenericTaskHeading(candidate) &&
            !candidate.startsWith('|') &&
            !candidate.startsWith('-')) {
          titleIndex = index;
          break;
        }
      }
    }

    final title = rawLines[titleIndex].trim();
    final sections = <String, List<String>>{};
    final free = <String>[];
    String? active;

    for (var i = 0; i < rawLines.length; i++) {
      if (i == titleIndex) continue;
      final line = rawLines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (active != null) sections[active]!.add('');
        continue;
      }

      if (_sameMeaning(trimmed, title)) continue;

      final key = _sectionKey(trimmed);
      if (key != null) {
        active = key;
        sections.putIfAbsent(key, () => <String>[]);
        continue;
      }

      if (active == null) {
        if (!_isGenericTaskHeading(trimmed)) free.add(line);
      } else {
        sections[active]!.add(line);
      }
    }

    final isEs = language.toLowerCase().startsWith('es');
    final labels = <String, String>{
      'immediate': isEs ? 'Conducta inmediata' : 'Conduta imediata',
      'treatment': isEs
          ? 'Tratamiento farmacológico'
          : 'Tratamento farmacológico',
      'classification': isEs ? 'Clasificación' : 'Classificação',
      'monitoring': isEs
          ? 'Monitorización y reevaluación'
          : 'Monitorização e reavaliação',
      'keyPoints': isEs ? 'Puntos clave' : 'Pontos-chave',
      'redFlags': 'RED FLAGS',
      'limitations': isEs
          ? 'Limitaciones / datos faltantes'
          : 'Limitações / dados faltantes',
    };

    final out = <String>[title];
    if (free.any((line) => line.trim().isNotEmpty)) {
      out
        ..add('')
        ..addAll(_trimBlankEdges(free));
    }

    for (final key in const <String>[
      'immediate',
      'treatment',
      'classification',
      'monitoring',
      'keyPoints',
      'redFlags',
      'limitations',
    ]) {
      final body = sections[key];
      if (body == null || !body.any((line) => line.trim().isNotEmpty)) continue;
      out
        ..add('')
        ..add(labels[key]!)
        ..addAll(_trimBlankEdges(body));
    }

    return out.join('\n').trim();
  }

  static List<String> _trimBlankEdges(List<String> source) {
    var start = 0;
    var end = source.length;
    while (start < end && source[start].trim().isEmpty) {
      start++;
    }
    while (end > start && source[end - 1].trim().isEmpty) {
      end--;
    }
    return source.sublist(start, end);
  }

  static String? _sectionKey(String line) {
    final value = _fold(
      line
          .replaceAll(RegExp(r'^[#*_\-\s]+'), '')
          .replaceAll(RegExp(r'[#*_\s:]+$'), ''),
    ).trim();

    if (value == 'conducta inmediata' ||
        value == 'conduta imediata' ||
        value == 'manejo inmediato') {
      return 'immediate';
    }
    if (value == 'tratamiento farmacologico' ||
        value == 'tratamento farmacologico') {
      return 'treatment';
    }
    if (value == 'clasificacion' ||
        value == 'classificacao' ||
        value.startsWith('clasificacion ') ||
        value.startsWith('classificacao ')) {
      return 'classification';
    }
    if (value == 'monitorizacion' ||
        value == 'monitoramento' ||
        value == 'monitorizacao' ||
        value == 'reevaluacion' ||
        value == 'reavaliacao' ||
        value == 'monitorizacion y reevaluacion' ||
        value == 'monitorizacao e reavaliacao') {
      return 'monitoring';
    }
    if (value == 'puntos clave' ||
        value == 'pontos chave' ||
        value == 'pontos-chave') {
      return 'keyPoints';
    }
    if (value == 'red flags' ||
        value == 'senales de alarma' ||
        value == 'sinais de alarme') {
      return 'redFlags';
    }
    if (value.startsWith('limitaciones') ||
        value.startsWith('limitacoes') ||
        value.startsWith('datos faltantes') ||
        value.startsWith('dados faltantes')) {
      return 'limitations';
    }
    return null;
  }

  static bool _isKnownSectionHeading(String line) => _sectionKey(line) != null;

  static bool _isGenericTaskHeading(String value) {
    final folded = _fold(
      value
          .replaceAll(RegExp(r'^[#*_\-\s]+'), '')
          .replaceAll(RegExp(r'[#*_\s:]+$'), ''),
    ).trim();
    return const <String>{
      'conducta clinica inmediata',
      'conduta clinica imediata',
      'conducta inmediata',
      'conduta imediata',
      'orientacion clinica',
      'orientacao clinica',
      'clasificacion del paciente',
      'classificacao do paciente',
    }.contains(folded);
  }

  static String _stripDecorativePictographs(String input) {
    return input
        .replaceAll('\u{1F7E5}', '')
        .replaceAll('\u{1F534}', '')
        .replaceAll('\u{26A0}', '')
        .replaceAll('\u{FE0F}', '')
        .trimLeft();
  }

  // M56C_MACHINE_NATIVE_ACTION_MATCHER_V2
  // PT/ES tolerant, conservative and negation-aware.
  // M56C_MACHINE_NATIVE_ACTION_MATCHER_V3
  // Exact authored text is checked on the complete visible line before
  // punctuation tokenization. Required actions mirror authored polarity;
  // prohibited actions continue to require a positive recommendation.
  // M62_MACHINE_NATIVE_EVIDENCE_BACKED_REQUIRED_PROJECTOR_V1
  // Provider output remains a proposal. Runtime may repair only a critical
  // required_action_missing when the proposal already contains strong,
  // polarity-consistent clinical evidence for that SAME authored directive.
  // The materialized text is copied verbatim from the authoritative pack.
  // There is no provider call, network access, pathology exception or
  // cross-patient inference here. Any uncertainty returns the original pass-1
  // result, preserving M58 fail-closed behavior.
  static PlantaoGlobalClinicalGateResult
  repairEvidenceBackedRequiredActionsForPresentation({
    required String userText,
    required String language,
    required PlantaoGlobalClinicalGateResult pass1,
    PlantaoGlobalClinicalContextPack? contextPack,
  }) {
    final pack = contextPack;
    if (!pass1.hasCriticalIssue ||
        pack == null ||
        !pack.hasMachineNativeAuthority ||
        pack.requiredActions.isEmpty) {
      return pass1;
    }

    // Dependency-bearing answers can change meaning with a classification or
    // score result. Do not deterministically project them in M62.
    if (pack.classificationDependencies.isNotEmpty ||
        pack.scoreDependencies.isNotEmpty) {
      return pass1;
    }

    // Never project around another safety failure. The only eligible pass-1
    // state is one or more required_action_missing issues and nothing else.
    if (pass1.issues.isEmpty ||
        pass1.issues.any(
          (issue) => issue.code != 'required_action_missing' || !issue.critical,
        )) {
      return pass1;
    }

    var candidate = pass1.finalText;
    for (final issue in pass1.issues) {
      final authored = pack.requiredActions.where(
        (action) => _fold(action).trim() == _fold(issue.detail).trim(),
      );
      if (authored.length != 1) return pass1;

      final repaired = _materializeEvidenceBackedRequiredAction(
        candidate,
        authored.single,
      );
      if (repaired == null || repaired == candidate) return pass1;
      candidate = repaired;
    }

    final pass2 = finalizeForPresentation(
      userText: userText,
      rawText: candidate,
      language: language,
      contextPack: pack,
    );

    // Atomic rule: only a completely clean pass-2 is allowed to replace
    // pass-1. Otherwise the original critical result survives unchanged.
    if (pass2.issues.isNotEmpty || pass2.hasCriticalIssue) return pass1;
    return pass2;
  }

  static String? _materializeEvidenceBackedRequiredAction(
    String text,
    String authoredAction,
  ) {
    final authoredFolded = _fold(authoredAction).trim();
    final expectedTokens = _clinicalActionTokens(authoredFolded);
    if (expectedTokens.length < 4) return null;

    final authoredNegated = _isNegatedClinicalClause(authoredFolded);
    final authoredClauses = authoredFolded
        .split(RegExp(r'[.;:]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final lines = text.split('\n');

    int matchedCount(List<String> expected, List<String> actual) {
      var matched = 0;
      for (final token in expected) {
        if (actual.any(
          (candidate) => _clinicalTokenEquivalent(token, candidate),
        )) {
          matched++;
        }
      }
      return matched;
    }

    bool actionLike(String value) =>
        RegExp(r'^\s*(?:[-*•]\s+|\d+[.)]\s+)').hasMatch(value);

    String actionBody(String value) =>
        value.replaceFirst(RegExp(r'^\s*(?:[-*•]\s+|\d+[.)]\s+)'), '').trim();

    String prefixOf(String value) =>
        RegExp(r'^\s*(?:[-*•]\s+|\d+[.)]\s+)').firstMatch(value)?.group(0) ??
        '- ';

    bool polarityMatches(String value) =>
        _isNegatedClinicalClause(_fold(actionBody(value))) == authoredNegated;

    ({int lineIndex, double score, int matched})? best;

    void considerSingle(int index) {
      final raw = lines[index];
      if (!actionLike(raw) || !polarityMatches(raw)) return;
      final actual = _clinicalActionTokens(_fold(actionBody(raw)));
      if (actual.isEmpty) return;
      final matched = matchedCount(expectedTokens, actual);
      final requiredMatched = expectedTokens.length <= 5
          ? expectedTokens.length
          : ((expectedTokens.length * 0.60).ceil()).clamp(
              4,
              expectedTokens.length,
            );
      final score = matched / expectedTokens.length;
      if (matched < requiredMatched || score < 0.60) return;
      if (best == null || score > best!.score) {
        best = (lineIndex: index, score: score, matched: matched);
      }
    }

    for (var i = 0; i < lines.length; i++) {
      considerSingle(i);
    }

    // A semicolon-authored action may have been rendered as two adjacent
    // numbered/bulleted actions (the exact physical ABC + oxygen case). This
    // is projector evidence only; M61 matcher semantics remain line-scoped.
    if (authoredClauses.length >= 2) {
      for (var i = 0; i < lines.length; i++) {
        if (!actionLike(lines[i]) || !polarityMatches(lines[i])) continue;
        var j = i + 1;
        while (j < lines.length && lines[j].trim().isEmpty) {
          j++;
        }
        if (j >= lines.length ||
            !actionLike(lines[j]) ||
            !polarityMatches(lines[j])) {
          continue;
        }

        final left = _clinicalActionTokens(_fold(actionBody(lines[i])));
        final right = _clinicalActionTokens(_fold(actionBody(lines[j])));
        if (left.isEmpty || right.isEmpty) continue;

        final leftContribution = matchedCount(expectedTokens, left);
        final rightContribution = matchedCount(expectedTokens, right);
        if (leftContribution < 2 || rightContribution < 2) continue;

        final union = <String>{...left, ...right}.toList(growable: false);
        final matched = matchedCount(expectedTokens, union);
        final score = matched / expectedTokens.length;
        final requiredMatched = ((expectedTokens.length * 0.70).ceil()).clamp(
          4,
          expectedTokens.length,
        );
        if (matched < requiredMatched || score < 0.70) continue;

        if (best == null || score > best!.score) {
          best = (lineIndex: i, score: score, matched: matched);
        }
      }
    }

    final selected = best;
    if (selected == null) return null;

    // Replace only the best evidenced action line. For a split two-line
    // proposal, the adjacent provider line is retained as supplemental detail;
    // no provider content is silently deleted.
    lines[selected.lineIndex] =
        '${prefixOf(lines[selected.lineIndex])}$authoredAction';
    return lines.join('\n');
  }

  static bool _containsClinicalAction(
    String haystack,
    String needle, {
    bool requirePositiveRecommendation = false,
    bool matchNeedlePolarity = false,
  }) {
    if (needle.isEmpty) return true;

    final needleNegated = _isNegatedClinicalClause(needle);

    bool allowedPolarity(String candidate) {
      final candidateNegated = _isNegatedClinicalClause(candidate);
      if (matchNeedlePolarity) {
        return candidateNegated == needleNegated;
      }
      if (requirePositiveRecommendation) {
        return !candidateNegated;
      }
      return true;
    }

    final actionTokens = _clinicalActionTokens(needle);
    if (actionTokens.isEmpty) return false;

    final lines = haystack
        .split(RegExp(r'[\n\r]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);

    for (final line in lines) {
      // Preserve negation/polarity scope for the entire visible line. A line
      // beginning with "No ..." must not become positive merely because a
      // semicolon creates a later subclause without repeating "No".
      if (!allowedPolarity(line)) continue;

      if (line.contains(needle)) return true;

      // M61_MACHINE_NATIVE_LINE_AGGREGATE_TOKEN_FALLBACK_V1
      // A paraphrased authored action may span multiple punctuation clauses
      // on the SAME visible line. M56C V3 compared the complete authored token
      // set against each clause independently after exact-text mismatch, which
      // can false-negative an otherwise semantically complete line. Aggregate
      // only within this already polarity-approved line; never across lines.
      final lineTokens = _clinicalActionTokens(line);
      if (lineTokens.isNotEmpty) {
        var lineMatched = 0;
        for (final expected in actionTokens) {
          if (lineTokens.any(
            (actual) => _clinicalTokenEquivalent(expected, actual),
          )) {
            lineMatched++;
          }
        }

        final lineRequired = actionTokens.length <= 3
            ? actionTokens.length
            : ((actionTokens.length * 0.70).ceil());

        if (lineMatched >= lineRequired) return true;
      }

      final clauses = line
          .split(RegExp(r'[.;:]+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty);

      for (final clause in clauses) {
        final clauseTokens = _clinicalActionTokens(clause);
        if (clauseTokens.isEmpty) continue;

        var matched = 0;
        for (final expected in actionTokens) {
          if (clauseTokens.any(
            (actual) => _clinicalTokenEquivalent(expected, actual),
          )) {
            matched++;
          }
        }

        final required = actionTokens.length <= 3
            ? actionTokens.length
            : ((actionTokens.length * 0.70).ceil());

        if (matched >= required) return true;
      }
    }

    return false;
  }

  static List<String> _clinicalActionTokens(String value) {
    const keepShort = <String>{'im', 'iv', 'vo'};
    const stopWords = <String>{
      'para',
      'por',
      'con',
      'com',
      'sem',
      'sin',
      'del',
      'las',
      'los',
      'una',
      'uno',
      'uma',
      'que',
      'debe',
      'deben',
      'deve',
      'devem',
      'usar',
      'uso',
      'utilizar',
      'hacer',
      'fazer',
      'paciente',
    };

    return value
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .where((token) => token.length >= 4 || keepShort.contains(token))
        .where((token) => !stopWords.contains(token))
        .map(_canonicalClinicalToken)
        .toSet()
        .toList(growable: false);
  }

  static String _canonicalClinicalToken(String token) {
    const aliases = <String, String>{
      'adrenalina': 'epinephrine',
      'epinefrina': 'epinephrine',
      'epinephrine': 'epinephrine',
      'choque': 'shock',
      'shock': 'shock',
      'acesso': 'access',
      'acceso': 'access',
      'access': 'access',
      'imediatamente': 'immediate',
      'inmediatamente': 'immediate',
      'imediato': 'immediate',
      'inmediato': 'immediate',
      'imediata': 'immediate',
      'inmediata': 'immediate',
      'oxigenio': 'oxygen',
      'oxigeno': 'oxygen',
      'oxygen': 'oxygen',
      'intravenoso': 'iv',
      'intravenosa': 'iv',
      'intramuscular': 'im',
      'cristaloide': 'crystalloid',
      'cristaloides': 'crystalloid',
      'isotonico': 'isotonic',
      'isotonica': 'isotonic',
      'rapido': 'rapid',
      'rapida': 'rapid',
      'rapidamente': 'rapid',
      'routine': 'routine',
      'rutina': 'routine',
      'rotina': 'routine',
      'corticoide': 'corticosteroid',
      'corticoides': 'corticosteroid',
      'corticosteroide': 'corticosteroid',
      'corticosteroides': 'corticosteroid',
    };
    return aliases[token] ?? token;
  }

  static bool _clinicalTokenEquivalent(String a, String b) {
    if (a == b) return true;
    final maxLen = a.length > b.length ? a.length : b.length;
    if (maxLen < 5) return false;

    final distance = _levenshteinDistance(a, b);
    if (distance <= 1) return true;
    return maxLen >= 10 && distance <= 2;
  }

  static int _levenshteinDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 0; i < a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final substitution =
            previous[j] + (a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1);
        final insertion = current[j] + 1;
        final deletion = previous[j + 1] + 1;
        var best = substitution < insertion ? substitution : insertion;
        if (deletion < best) best = deletion;
        current[j + 1] = best;
      }
      previous = current;
    }
    return previous[b.length];
  }

  // M56C_R6_DIRECTIVE_POLARITY_V3
  // Language-agnostic polarity without confusing Portuguese "no" (= em + o)
  // with Spanish "no". Punctuation is normalized before phrase matching so
  // "no son de rutina." and "no se recomienda;" remain negative guidance.
  static bool _isNegatedClinicalClause(String clause) {
    var value = clause.trimLeft();

    while (value.isNotEmpty &&
        (value.startsWith('-') ||
            value.startsWith('*') ||
            value.startsWith('•'))) {
      value = value.substring(1).trimLeft();
    }

    final normalized = value
        .replaceAll(RegExp(r'[^a-z0-9_ ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (normalized.isEmpty) return false;

    final tokens = normalized.split(' ');
    final first = tokens.first;

    // Portuguese "nao" is unambiguous negation after _fold().
    if (first == 'nao') return true;

    // Spanish "no" is only considered a leading negator when followed by an
    // infinitive or by a canonical negative recommendation construction.
    // This keeps Portuguese phrases such as "no choque", "no paciente" and
    // "no trauma" positive.
    if (first == 'no' && tokens.length >= 2) {
      final second = tokens[1];
      final infinitive =
          second.endsWith('ar') ||
          second.endsWith('er') ||
          second.endsWith('ir');
      final negativeConstruction =
          second == 'se' ||
          second == 'es' ||
          second == 'son' ||
          second == 'debe' ||
          second == 'deben';
      if (infinitive || negativeConstruction) return true;
    }

    const leadingNegativeDirectives = <String>[
      'evitar ',
      'evite ',
      'contraindicado ',
      'contraindicada ',
      'contraindicar ',
      'sin indicacion ',
      'sem indicacao ',
    ];
    if (leadingNegativeDirectives.any(normalized.startsWith)) return true;

    final padded = ' $normalized ';
    const explicitNegativePhrases = <String>[
      ' no administrar ',
      ' no usar ',
      ' no iniciar ',
      ' no indicar ',
      ' no realizar ',
      ' no retrasar ',
      ' no suspender ',
      ' no se recomienda ',
      ' no es de rutina ',
      ' no son de rutina ',
      ' nao administrar ',
      ' nao usar ',
      ' nao iniciar ',
      ' nao indicar ',
      ' nao realizar ',
      ' nao atrasar ',
      ' nao suspender ',
      ' nao se recomenda ',
      ' nao e de rotina ',
      ' nao sao de rotina ',
      ' debe evitarse ',
      ' devem ser evitados ',
      ' devem ser evitadas ',
      ' deve ser evitado ',
      ' deve ser evitada ',
    ];
    return explicitNegativePhrases.any(padded.contains);
  }

  static int _firstIndexOfAny(String haystack, List<String> needles) {
    var best = -1;
    for (final needle in needles) {
      final index = haystack.indexOf(needle);
      if (index >= 0 && (best < 0 || index < best)) best = index;
    }
    return best;
  }

  static bool _sameMeaning(String a, String b) => _fold(a) == _fold(b);

  static String _fold(String input) {
    var value = input.toLowerCase();
    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };
    replacements.forEach((from, to) {
      value = value.replaceAll(from, to);
    });
    return value;
  }
}
