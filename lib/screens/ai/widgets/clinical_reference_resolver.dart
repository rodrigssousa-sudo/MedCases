import '../../../data/evidence_database.dart';
import '../../../data/protocols_database.dart';
import '../../../models/drug_model.dart';
import '../../../models/protocol_model.dart';

class ClinicalReferenceData {
  final List<String> lines;
  final String sourceType;
  final String? protocolId;
  final List<String> drugKeys;

  const ClinicalReferenceData({
    required this.lines,
    required this.sourceType,
    this.protocolId,
    this.drugKeys = const [],
  });
}

/// Resolve referências clínicas sem acessar estado de UI ou Provider.
///
/// Hierarquia:
/// 1. Um único fármaco reconhecido → evidência específica do fármaco.
/// 2. Vários fármacos ou tema clínico → referências do protocolo correspondente.
/// 3. Sem correspondência segura → bibliografia clínica geral já adotada no app.
class ClinicalReferenceResolver {
  ClinicalReferenceResolver._();

  static final RegExp _pharmacologicalContextPattern = RegExp(
    r'\b(dosis|dose|administr|mg\/kg|mcg\/kg|infus[ií]on|bolo|iv|im|sc|'
    r'ampollas?|comprimido|antibi[oó]tico|analg[eé]sico|sedaci[oó]n|'
    r'anticoagulante|vasopressor|broncodilatador|farmacol[oó]gic)\b',
    caseSensitive: false,
  );

  static const List<String> _drugKeywords = [
    'adenosina',
    'amiodarona',
    'noradrenalina',
    'adrenalina',
    'epinefrina',
    'atropina',
    'morfina',
    'fentanil',
    'fentanilo',
    'ketamina',
    'midazolam',
    'propofol',
    'dexmedetomidina',
    'haloperidol',
    'metoprolol',
    'furosemida',
    'dobutamina',
    'dopamina',
    'vasopresina',
    'nitroglicerina',
    'heparina',
    'enoxaparina',
    'rivaroxabana',
    'varfarina',
    'clopidogrel',
    'salbutamol',
    'dexametasona',
    'insulina',
    'metformina',
    'omeprazol',
    'ondansetrona',
    'enalapril',
    'losartana',
    'paracetamol',
    'ibuprofeno',
    'tramadol',
    'naloxona',
    'succinilcolina',
    'ceftriaxona',
    'vancomicina',
    'meropenem',
    'piperacilina',
    'fluconazol',
    'aciclovir',
    'sulfato de magnesio',
    'ácido tranexámico',
    'levetiracetam',
    'fenitoína',
    'clonazepam',
  ];

  static ClinicalReferenceData resolve({
    required String userText,
    required String aiText,
    required String lang,
  }) {
    final isEs = lang == 'es';
    final drugs = _detectDrugs(aiText);

    // A single recognized medication already has a typed evidence owner.
    // Prefer its actual bibliographic records instead of generic textbooks.
    if (drugs.length == 1) {
      final ev = drugs.single;
      return ClinicalReferenceData(
        sourceType: 'single_drug',
        drugKeys: [ev.drugKey],
        lines: _singleDrugReferenceLines(ev, isEs: isEs),
      );
    }

    // Domain identity is intentionally derived only from the user's query and
    // the first visible answer heading. We do NOT scan the whole answer because
    // differential diagnoses can mention unrelated specialties.
    final domain = _referenceDomain(userText, aiText);

    final matchedProtocol = _isUndifferentiatedResponse(aiText)
        ? null
        : _matchProtocol(userText, aiText);

    // A semantically matched protocol is accepted only when it is compatible
    // with an explicitly identified reference domain. This prevents failures
    // such as a pulmonary/thoracic question receiving a renal/KDIGO reference.
    final protocol = matchedProtocol != null &&
            _protocolCompatibleWithDomain(matchedProtocol, domain)
        ? matchedProtocol
        : null;

    if (protocol != null) {
      final title = protocol.getField(protocol.title, lang);
      final protocolReferences = protocol.getList(protocol.references, lang);

      final candidateReferences = <String>[
        ..._curatedReferencesForDomain(domain),
        ...protocolReferences.where(
          (reference) => _referenceCompatibleWithDomain(reference, domain),
        ),
      ];

      final references = _mergeReferenceLines(
        candidateReferences,
        limit: 3,
      );

      final lines = <String>[
        isEs ? 'Tema clínico: $title' : 'Tema clínico: $title',
        ...references,
      ];

      if (references.isEmpty) {
        lines.add(_generalMedicineReference);
      }

      return ClinicalReferenceData(
        sourceType:
            drugs.length > 1 ? 'polypharmacy_protocol' : 'clinical_protocol',
        protocolId: protocol.id,
        drugKeys: drugs.map((e) => e.drugKey).toList(growable: false),
        lines: lines,
      );
    }

    final specialtyReferences = _curatedReferencesForDomain(domain);
    if (domain != null && specialtyReferences.isNotEmpty) {
      return ClinicalReferenceData(
        sourceType: 'specialty_fallback_$domain',
        drugKeys: drugs.map((e) => e.drugKey).toList(growable: false),
        lines: _mergeReferenceLines(specialtyReferences, limit: 3),
      );
    }

    // Truly nonspecific questions receive a neutral current general-medicine
    // reference. We deliberately do not guess a specialty.
    return ClinicalReferenceData(
      sourceType:
          drugs.length > 1 ? 'polypharmacy_fallback' : 'general_fallback',
      drugKeys: drugs.map((e) => e.drugKey).toList(growable: false),
      lines: const <String>[_generalMedicineReference],
    );
  }

  static const String _generalMedicineReference =
      "Harrison's Principles of Internal Medicine, 22nd ed. (2025)";

  static List<String> _singleDrugReferenceLines(
    DrugEvidenceModel evidence, {
    required bool isEs,
  }) {
    final lines = <String>[
      'Fármaco: ${evidence.displayName}',
      isEs
          ? 'Directriz: ${evidence.guidelineSource}'
          : 'Diretriz: ${evidence.guidelineSource}',
    ];

    for (final reference in evidence.references.take(2)) {
      final compact = _formatDrugEvidenceReference(reference);
      if (compact.isNotEmpty) {
        lines.add(compact);
      }
    }

    if (evidence.references.isEmpty) {
      lines.add(
        isEs
            ? 'Fuente principal: ${evidence.primarySource}'
            : 'Fonte principal: ${evidence.primarySource}',
      );
    }

    return _mergeReferenceLines(lines, limit: 4);
  }

  static String _formatDrugEvidenceReference(DrugEvidenceRef reference) {
    final source = reference.source.trim();
    final title = reference.title.trim();
    final year = reference.year.trim();

    final prefix = source.isEmpty ? '' : '$source — ';
    final suffix = year.isEmpty ? '' : ' ($year)';
    return '$prefix$title$suffix'.trim();
  }

  static String? _referenceDomain(String userText, String aiText) {
    final firstHeading = aiText
        .split('\n')
        .firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => '',
        )
        .trim();

    return _domainFromNormalized(
      _normalize('$userText $firstHeading'),
      allowSourceAliases: false,
    );
  }

  static String? _protocolReferenceDomain(ProtocolModel protocol) {
    final corpus = _normalize(
      '${protocol.id.replaceAll('_', ' ')} '
      '${protocol.title['pt'] ?? ''} '
      '${protocol.title['es'] ?? ''}',
    );
    return _domainFromNormalized(corpus, allowSourceAliases: false);
  }

  static bool _protocolCompatibleWithDomain(
    ProtocolModel protocol,
    String? requestedDomain,
  ) {
    if (requestedDomain == null) return true;
    final protocolDomain = _protocolReferenceDomain(protocol);
    return protocolDomain == requestedDomain;
  }

  static bool _referenceCompatibleWithDomain(
    String reference,
    String? requestedDomain,
  ) {
    if (requestedDomain == null) return true;

    final referenceDomain = _domainFromNormalized(
      _normalize(reference),
      allowSourceAliases: true,
    );

    // Unknown/generic bibliographic lines are tolerated; only an explicitly
    // conflicting specialty is rejected.
    return referenceDomain == null || referenceDomain == requestedDomain;
  }

  static String? _domainFromNormalized(
    String value, {
    required bool allowSourceAliases,
  }) {
    bool containsAny(Iterable<String> needles) =>
        needles.any((needle) => value.contains(needle));

    bool hasWord(String word) => ' $value '.contains(' $word ');

    final pediatric = containsAny(const <String>[
      'pediatr',
      'crianca',
      'nino',
      'infante',
      'adolescente',
    ]);

    final pneumonia = containsAny(const <String>[
      'pneumonia',
      'neumonia',
    ]);

    final sepsis = containsAny(const <String>[
      'sepsis',
      'sepse',
      'choque septico',
      'shock septico',
    ]);

    final arrest = containsAny(const <String>[
          'parada cardiorrespiratoria',
          'paro cardiorrespiratorio',
          'ressuscitacao',
          'reanimacion cardiopulmonar',
        ]) ||
        hasWord('rcp');

    if (pediatric && pneumonia) return 'pediatric_pneumonia';
    if (pediatric && sepsis) return 'pediatric_sepsis';
    if (pediatric && arrest) return 'pediatric_resuscitation';

    if (containsAny(const <String>[
      'coleducolitiasis',
      'coledocolitiasis',
      'coledocolitiase',
      'coleducolitiase',
      'choledocholithiasis',
      'sindrome coledociano',
      'calculo coledociano',
      'calculo no coledoco',
      'calculo en coledoco',
      'common bile duct stone',
      'common bile duct stones',
    ])) {
      return 'choledocholithiasis';
    }

    if (containsAny(const <String>[
      'derrame pleural',
      'pleural effusion',
      'efusao pleural',
      'infeccion pleural',
      'infeccao pleural',
      'pleural infection',
      'empiema pleural',
      'empiema',
      'empyema',
      'derrame parapneumonico',
      'parapneumonic effusion',
      'enfermedad pleural',
      'doenca pleural',
      'pleural disease',
    ])) {
      return 'pleural_disease';
    }

    if (containsAny(const <String>[
      'pneumotorax',
      'neumotorax',
      'hemotorax',
      'trauma toracico',
      'traumatismo toracico',
      'torax abierto',
      'torax aberto',
      'ferimento toracico',
      'herida toracica',
    ])) {
      return 'thoracic_trauma';
    }

    if (containsAny(const <String>['asma']) ||
        (allowSourceAliases && hasWord('gina'))) {
      return 'asthma';
    }

    if (containsAny(const <String>['epoc', 'dpoc', 'copd']) ||
        (allowSourceAliases && hasWord('gold'))) {
      return 'copd';
    }

    if (pneumonia ||
        (allowSourceAliases &&
            containsAny(const <String>[
              'community acquired pneumonia',
              'ats pneumonia',
              'ats/idsa cap',
            ]))) {
      return 'adult_pneumonia';
    }

    if (hasWord('tep') ||
        containsAny(const <String>[
          'tromboembolismo pulmonar',
          'embolia pulmonar',
          'pulmonary embolism',
        ])) {
      return 'pulmonary_embolism';
    }

    if (hasWord('iam') ||
        hasWord('stemi') ||
        hasWord('nstemi') ||
        hasWord('scasst') ||
        hasWord('iamcsst') ||
        containsAny(const <String>[
          'infarto agudo',
          'sindrome coronariana aguda',
          'sindrome coronaria aguda',
          'acute coronary syndrome',
        ]) ||
        (allowSourceAliases &&
            containsAny(const <String>[
              'acute coronary syndromes guideline',
              'acc/aha/acep/naemsp/scai',
            ]))) {
      return 'acute_coronary_syndrome';
    }

    if (arrest ||
        (allowSourceAliases &&
            containsAny(const <String>[
              'cpr and ecc',
              'cardiopulmonary resuscitation',
            ]))) {
      return 'resuscitation';
    }

    if (sepsis ||
        (allowSourceAliases &&
            containsAny(const <String>[
              'surviving sepsis',
              'septic shock guideline',
            ]))) {
      return 'sepsis';
    }

    if (containsAny(const <String>[
          'cetoacidose diabetica',
          'cetoacidosis diabetica',
          'ketoacidosis diabetica',
          'diabetic ketoacidosis',
          'estado hiperosmolar',
          'estado hiperglicemico hiperosmolar',
          'hyperglycemic crisis',
        ]) ||
        hasWord('dka') ||
        hasWord('cad') ||
        hasWord('hhs') ||
        hasWord('ehh')) {
      return 'hyperglycemic_crisis';
    }

    if (containsAny(const <String>['diabetes', 'diabetico', 'diabetica']) ||
        (allowSourceAliases &&
            containsAny(const <String>['standards of care in diabetes']))) {
      return 'diabetes';
    }

    if (containsAny(const <String>[
          'doenca renal cronica',
          'enfermedad renal cronica',
          'chronic kidney disease',
        ]) ||
        hasWord('ckd') ||
        hasWord('drc') ||
        (allowSourceAliases && hasWord('kdigo'))) {
      return 'chronic_kidney_disease';
    }

    if (containsAny(const <String>[
          'acidente vascular cerebral isquemico',
          'accidente cerebrovascular isquemico',
          'ictus isquemico',
          'ischemic stroke',
          'ischaemic stroke',
        ]) ||
        (allowSourceAliases &&
            containsAny(const <String>[
              'acute ischemic stroke',
              'acute ischaemic stroke',
            ]))) {
      return 'acute_ischemic_stroke';
    }

    if (containsAny(const <String>[
      'anafilax',
      'anaphylax',
    ])) {
      return 'anaphylaxis';
    }

    if (allowSourceAliases) {
      if (containsAny(const <String>[
        'atls 11',
        'wses-aast',
        'thoracic trauma',
      ])) {
        return 'thoracic_trauma';
      }
      if (containsAny(const <String>['aha/asa']) &&
          containsAny(const <String>['stroke', 'ischemic', 'ischaemic'])) {
        return 'acute_ischemic_stroke';
      }
      if (containsAny(const <String>['aaaai', 'acaai', 'jtfpp']) &&
          containsAny(const <String>['anaphylaxis', 'anafilax'])) {
        return 'anaphylaxis';
      }
      if (containsAny(const <String>['esc/ers', 'acute pulmonary embolism'])) {
        return 'pulmonary_embolism';
      }
      if (containsAny(const <String>['pids', 'pediatric pneumonia'])) {
        return 'pediatric_pneumonia';
      }
      if (containsAny(const <String>['pediatric sepsis'])) {
        return 'pediatric_sepsis';
      }
      if (containsAny(const <String>[
        'pals',
        'pediatric advanced life support',
      ])) {
        return 'pediatric_resuscitation';
      }
    }

    return null;
  }

  // Curated primary guideline index. These are presentation references only;
  // they do not mutate diagnosis, treatment, dose, routing or persistence.
  // Source versions were reconciled for this build on 2026-08-15.
  static List<String> _curatedReferencesForDomain(String? domain) {
    switch (domain) {
      case 'choledocholithiasis':
        return const <String>[
          'ASGE — Guideline on the role of endoscopy in the evaluation and management of choledocholithiasis. Gastrointest Endosc. 2019;89:1075-1105.e15',
          'ESGE — Endoscopic management of common bile duct stones. Endoscopy. 2019;51:472-491. doi:10.1055/a-0862-0346',
        ];
      case 'pleural_disease':
        return const <String>[
          'BTS — Guideline for Pleural Disease (2023)',
          'BTS — Clinical Statement on Pleural Procedures (2023)',
        ];
      case 'thoracic_trauma':
        return const <String>[
          'ACS — ATLS 11: Thoracic Trauma (2025)',
          'WSES-AAST — Thoracic trauma guidelines. World J Emerg Surg. 2025;20:78. doi:10.1186/s13017-025-00651-1',
        ];
      case 'asthma':
        return const <String>[
          'GINA — Global Strategy for Asthma Management and Prevention (2026)',
        ];
      case 'copd':
        return const <String>[
          'GOLD — Global Strategy for Prevention, Diagnosis and Management of COPD (2026)',
        ];
      case 'adult_pneumonia':
        return const <String>[
          'ATS — Clinical Practice Guideline update for community-acquired pneumonia in adults (2025)',
        ];
      case 'pediatric_pneumonia':
        return const <String>[
          'IDSA/PIDS — Community-Acquired Pneumonia in Infants and Children >3 months (2026)',
        ];
      case 'pulmonary_embolism':
        return const <String>[
          'ESC/ERS — Guidelines for diagnosis and management of acute pulmonary embolism (2019)',
        ];
      case 'acute_coronary_syndrome':
        return const <String>[
          'ACC/AHA/ACEP/NAEMSP/SCAI — Guideline for Management of Acute Coronary Syndromes (2025)',
        ];
      case 'resuscitation':
        return const <String>[
          'AHA — Guidelines for CPR and Emergency Cardiovascular Care (2025)',
        ];
      case 'pediatric_resuscitation':
        return const <String>[
          'AHA — Pediatric Advanced Life Support, CPR and ECC Guidelines (2025)',
        ];
      case 'sepsis':
        return const <String>[
          'Surviving Sepsis Campaign / SCCM — Adult sepsis and septic shock guidelines (2026)',
        ];
      case 'pediatric_sepsis':
        return const <String>[
          'Surviving Sepsis Campaign / SCCM — Pediatric sepsis and septic shock guidelines (2026)',
        ];
      case 'hyperglycemic_crisis':
        return const <String>[
          'ADA/EASD/JBDS/AACE/DTS — Hyperglycemic Crises in Adults: Consensus Report (2024)',
          'ADA — Standards of Care in Diabetes (2026)',
        ];
      case 'diabetes':
        return const <String>[
          'ADA — Standards of Care in Diabetes (2026)',
        ];
      case 'chronic_kidney_disease':
        return const <String>[
          'KDIGO — Clinical Practice Guideline for Evaluation and Management of CKD (2024)',
        ];
      case 'acute_ischemic_stroke':
        return const <String>[
          'AHA/ASA — Guideline for the Early Management of Acute Ischemic Stroke (2026)',
        ];
      case 'anaphylaxis':
        return const <String>[
          'AAAAI/ACAAI JTFPP — Anaphylaxis: 2023 Practice Parameter Update',
        ];
      default:
        return const <String>[];
    }
  }

  static List<String> _mergeReferenceLines(
    Iterable<String> lines, {
    required int limit,
  }) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final key = _normalize(line);
      if (key.isEmpty || !seen.add(key)) continue;

      result.add(line);
      if (result.length >= limit) break;
    }

    return result;
  }

  static List<DrugEvidenceModel> _detectDrugs(String text) {
    if (!_pharmacologicalContextPattern.hasMatch(text)) {
      return const [];
    }

    final normalized = _normalize(text);
    final found = <String, DrugEvidenceModel>{};

    for (final keyword in _drugKeywords) {
      if (!normalized.contains(_normalize(keyword))) continue;
      final evidence = getGlobalEvidence(keyword);
      if (evidence != null) {
        found[evidence.drugKey] = evidence;
      }
    }

    return found.values.toList(growable: false);
  }

  static bool _isUndifferentiatedResponse(String aiText) {
    final normalized = _normalize(
      aiText.length > 360 ? aiText.substring(0, 360) : aiText,
    );

    return normalized.contains('diferenciais prioritarios') ||
        normalized.contains('diferenciales prioritarios');
  }

  static ProtocolModel? _matchExplicitDiverticulitisPhenotypeProtocol({
    required String query,
    required String responseHeading,
  }) {
    final corpus = '$query $responseHeading';
    if (!corpus.contains('diverticulit')) return null;

    final explicitlyUncomplicated = <String>[
      'nao complicada',
      'no complicada',
      'sem complicacao',
      'sin complicacion',
      'uncomplicated',
    ].any(corpus.contains);

    final explicitlyComplicated = !explicitlyUncomplicated &&
        <String>[
          'diverticulitis complicada',
          'diverticulite complicada',
          'absceso',
          'abscesso',
          'abscess',
          'perfor',
          'periton',
          'fistul',
          'obstruccion',
          'obstrucao',
          'obstruction',
          'sepsis',
          'sepse',
        ].any(corpus.contains);

    final targetId = explicitlyUncomplicated
        ? 'diverticulitis_aguda_015'
        : (explicitlyComplicated ? 'diverticulitis_complicada_2026' : null);
    if (targetId == null) return null;

    for (final protocol in protocolsDatabase) {
      if (protocol.id == targetId) return protocol;
    }
    return null;
  }

  static ProtocolModel? _matchProtocol(String userText, String aiText) {
    final query = _normalize(userText);
    final responseHeading = _normalize(
      aiText.split('\n').firstWhere(
            (line) => line.trim().isNotEmpty,
            orElse: () => '',
          ),
    );

    final diverticulitisPhenotypeProtocol =
        _matchExplicitDiverticulitisPhenotypeProtocol(
      query: query,
      responseHeading: responseHeading,
    );
    if (diverticulitisPhenotypeProtocol != null) {
      return diverticulitisPhenotypeProtocol;
    }

    Set<String> semanticTokens(String value) => _normalize(value)
        .split(RegExp(r'\s+'))
        .where((term) => term.length >= 3)
        .where((term) => !_stopWords.contains(term))
        .where((term) => RegExp(r'[a-z]').hasMatch(term))
        .toSet();

    bool containsTokenSequence(String haystack, String needle) {
      if (needle.isEmpty) return false;
      return ' $haystack '.contains(' $needle ');
    }

    const ambiguousProtocolTerms = <String>{'pcr'};
    const weakIdentityTerms = <String>{
      'aguda',
      'agudo',
      'grave',
      'cronica',
      'cronico',
      'adulto',
      'adulta',
      'pediatrico',
      'pediatrica',
      'sindrome',
      'caso',
      'clinico',
      'clinica',
      'sem',
      'sin',
      'diagnostico',
      'diagnostica',
      'tratamento',
      'tratamiento',
      'manejo',
      'abordagem',
      'abordaje',
      'protocolo',
      'resposta',
      'respuesta',
      'geral',
      'general',
      'fechado',
      'cerrado',
    };

    final queryTerms = semanticTokens(query);
    final headingTerms = semanticTokens(responseHeading);

    ProtocolModel? best;
    var bestScore = 0;
    ProtocolModel? exactMultiTokenQueryBest;
    var exactMultiTokenQueryBestScore = 0;

    for (final protocol in protocolsDatabase) {
      final id = _normalize(protocol.id.replaceAll('_', ' '));
      final title = _normalize(
        '${protocol.title['pt'] ?? ''} ${protocol.title['es'] ?? ''}',
      );
      final idTerms = semanticTokens(id);
      final protocolTerms = semanticTokens('$id $title');
      final titleTerms = semanticTokens(title);

      final queryMatches = queryTerms.intersection(protocolTerms);
      final headingMatches = headingTerms.intersection(titleTerms);

      final reliableQueryMatches = queryMatches
          .where((term) => !ambiguousProtocolTerms.contains(term))
          .toSet();
      final reliableHeadingMatches = headingMatches
          .where((term) => !ambiguousProtocolTerms.contains(term))
          .toSet();

      final distinctiveQueryMatches = reliableQueryMatches
          .where((term) => !weakIdentityTerms.contains(term))
          .toSet();
      final distinctiveHeadingMatches = reliableHeadingMatches
          .where((term) => !weakIdentityTerms.contains(term))
          .toSet();

      final distinctiveIdTerms = idTerms
          .where((term) => !ambiguousProtocolTerms.contains(term))
          .where((term) => !weakIdentityTerms.contains(term))
          .toSet();

      final queryPhraseMatch = queryTerms.isNotEmpty &&
          !queryTerms.any(ambiguousProtocolTerms.contains) &&
          (containsTokenSequence(id, query) ||
              containsTokenSequence(title, query));

      final singleQueryIdentity = queryTerms.length == 1 &&
          reliableQueryMatches.length == 1 &&
          distinctiveQueryMatches.length == 1;

      final strongQueryIdentity = queryPhraseMatch ||
          singleQueryIdentity ||
          (reliableQueryMatches.length >= 2 &&
              distinctiveQueryMatches.isNotEmpty);

      // Heading identity must identify the protocol, not merely share a
      // workflow word such as "diagnóstico" or "tratamento".
      final headingIdMatches = headingTerms.intersection(distinctiveIdTerms);

      // Support compact diagnostic aliases present in the protocol title but
      // not literally in its id, e.g. IAMCSST for iam_supra. The alias must
      // itself be a matched distinctive title token and be lexically tied to
      // a non-ambiguous id token.
      final headingAliasMatches = distinctiveHeadingMatches.where((term) {
        if (term.length < 5) return false;
        return idTerms.any((idTerm) =>
            idTerm.length >= 3 &&
            !ambiguousProtocolTerms.contains(idTerm) &&
            !weakIdentityTerms.contains(idTerm) &&
            (term.contains(idTerm) || idTerm.contains(term)));
      }).toSet();

      final strongHeadingIdentity =
          headingIdMatches.isNotEmpty || headingAliasMatches.isNotEmpty;

      if (!strongQueryIdentity && !strongHeadingIdentity) continue;

      var score =
          reliableQueryMatches.length * 6 + reliableHeadingMatches.length * 4;
      if (queryPhraseMatch) score += 10;
      if (singleQueryIdentity) score += 8;
      if (headingIdMatches.isNotEmpty) score += 12;
      if (headingAliasMatches.isNotEmpty) score += 12;

      if (queryTerms.length >= 2 &&
          queryPhraseMatch &&
          score > exactMultiTokenQueryBestScore) {
        exactMultiTokenQueryBestScore = score;
        exactMultiTokenQueryBest = protocol;
      }

      if (score > bestScore) {
        bestScore = score;
        best = protocol;
      }
    }

    return exactMultiTokenQueryBest ?? best;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static const Set<String> _stopWords = {
    'a',
    'o',
    'e',
    'de',
    'da',
    'do',
    'das',
    'dos',
    'em',
    'com',
    'para',
    'por',
    'um',
    'uma',
    'el',
    'la',
    'los',
    'las',
    'del',
    'en',
    'con',
    'que',
    'como',
    'qual',
    'cuál',
  };
}
