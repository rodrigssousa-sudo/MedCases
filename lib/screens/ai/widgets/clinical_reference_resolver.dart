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

  // M54_PHYSICAL_EXPLICIT_DISEASE_REFERENCE_PRECEDENCE_V1
  //
  // Disease identity explicitly present in the user request or first disease
  // heading has precedence over specialty/drug fallbacks. This is intentionally
  // narrow to the physical blockers; the existing global resolver remains owner
  // for all other pathologies.
  static ProtocolModel? _m54ExplicitDiseaseProtocol(
    String userText,
    String aiText,
  ) {
    // M56A_ANAPHYLAXIS_EARLY_HEADING_RESOLVER_V1
    final earlyHeadingWindow = aiText
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(6)
        .join(' ');

    final corpus = _normalize('$userText $earlyHeadingWindow');
    String? targetId;

    if (corpus.contains('bronquiolite') ||
        corpus.contains('bronquiolitis') ||
        corpus.contains('bronchiolitis')) {
      targetId = 'bronquiolite_aguda';
    } else if (corpus.contains('anafilaxia') ||
        corpus.contains('anaphylaxis') ||
        corpus.contains('anafilact')) {
      targetId = 'anafilaxia';
    } else {
      final explicitStemi =
          corpus.contains('iamcest') ||
          corpus.contains('iamcsst') ||
          corpus.contains('stemi') ||
          corpus.contains('infarto agudo de miocardio con elevacion del st') ||
          corpus.contains('infarto agudo do miocardio com elevacao do st') ||
          corpus.contains('infarto con elevacion del st') ||
          corpus.contains('infarto com supra');

      final explicitNoCongestion =
          RegExp(r'\bkillip\s*(?:i|1)\b').hasMatch(corpus) ||
          corpus.contains('sin congestion') ||
          corpus.contains('sem congestao') ||
          corpus.contains('sin edema pulmonar') ||
          corpus.contains('sem edema pulmonar') ||
          corpus.contains('sin edema agudo de pulmon') ||
          corpus.contains('sem edema agudo de pulmao') ||
          corpus.contains('sin estertores') ||
          corpus.contains('sem estertores') ||
          corpus.contains('sin ingurgitacion yugular') ||
          corpus.contains('sem turgencia jugular');

      if (explicitStemi && explicitNoCongestion) {
        targetId = 'iam_supra';
      }
    }

    if (targetId == null) return null;
    for (final protocol in protocolsDatabase) {
      if (protocol.id == targetId) return protocol;
    }
    return null;
  }

  static ClinicalReferenceData resolve({
    required String userText,
    required String aiText,
    required String lang,
  }) {
    final isEs = lang == 'es';
    final drugs = _detectDrugs(aiText);
    final m54ExplicitDiseaseProtocol = _m54ExplicitDiseaseProtocol(
      userText,
      aiText,
    );

    // A single recognized medication already has a typed evidence owner.
    // Prefer its actual bibliographic records instead of generic textbooks.
    if (drugs.length == 1 && m54ExplicitDiseaseProtocol == null) {
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
    final detectedDomain = _referenceDomain(userText, aiText);
    final domain = detectedDomain;

    final matchedProtocol =
        m54ExplicitDiseaseProtocol ??
        (_isUndifferentiatedResponse(aiText)
            ? null
            : _matchProtocol(userText, aiText));

    // A semantically matched protocol is accepted only when it is compatible
    // with an explicitly identified reference domain. This prevents failures
    // such as a pulmonary/thoracic question receiving a renal/KDIGO reference.
    final protocol =
        m54ExplicitDiseaseProtocol ??
        (matchedProtocol != null &&
                _protocolCompatibleWithDomain(matchedProtocol, domain)
            ? matchedProtocol
            : null);

    if (protocol != null) {
      final title = protocol.getField(protocol.title, lang);
      final protocolReferences = protocol.getList(protocol.references, lang);

      final curatedReferences = _curatedReferencesForDomain(domain);
      final candidateReferences = <String>[
        ...curatedReferences,
        if (!_top150Batch01Domains.contains(domain) &&
            !_top150Batch02Domains.contains(domain) &&
            !_top150Batch03Domains.contains(domain) &&
            !_top150Batch04Domains.contains(domain) &&
            !_top150Batch05Domains.contains(domain) &&
            !_top150Batch06Domains.contains(domain) &&
            !_top150Batch07Domains.contains(domain) &&
            !_top150Batch08Domains.contains(domain) &&
            !_top150Batch09Domains.contains(domain) &&
            !_top150Batch10Domains.contains(domain) &&
            !_top200ExpansionBatch11Domains.contains(domain) &&
            !_top200ExpansionBatch12Domains.contains(domain) &&
            !_top200ExpansionBatch13Domains.contains(domain) &&
            !_top200ExpansionBatch14Domains.contains(domain) &&
            !_top200ExpansionBatch15Domains.contains(domain) &&
            !_top200ExpansionBatch16Domains.contains(domain) &&
            !_top200ExpansionBatch17Domains.contains(domain) &&
            !_top200ExpansionBatch18Domains.contains(domain) &&
            !_top200ExpansionBatch19Domains.contains(domain) &&
            !_top200ExpansionBatch20Domains.contains(domain) &&
            !_top200ExpansionBatch21Domains.contains(domain) &&
            !_top200ExpansionBatch22Domains.contains(domain) &&
            !_top200ExpansionBatch23Domains.contains(domain) &&
            !_top200ExpansionBatch24Domains.contains(domain) &&
            !_top200ExpansionBatch25Domains.contains(domain) &&
            !_top200ExpansionBatch26Domains.contains(domain) &&
            !_top200ExpansionBatch27Domains.contains(domain) &&
            !_top200ExpansionBatch28Domains.contains(domain) &&
            !_top200ExpansionBatch29Domains.contains(domain) &&
            !_top200ExpansionBatch30Domains.contains(domain))
          ...protocolReferences.where(
            (reference) => _referenceCompatibleWithDomain(reference, domain),
          ),
      ];

      final references = _mergeReferenceLines(candidateReferences, limit: 4);

      final lines = <String>[
        isEs ? 'Tema clínico: $title' : 'Tema clínico: $title',
        ...references,
      ];

      if (references.isEmpty) {
        lines.add(_generalMedicineReference);
      }

      return ClinicalReferenceData(
        sourceType: drugs.length > 1
            ? 'polypharmacy_protocol'
            : 'clinical_protocol',
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
        lines: _mergeReferenceLines(specialtyReferences, limit: 4),
      );
    }

    // Truly nonspecific questions receive a neutral current general-medicine
    // reference. We deliberately do not guess a specialty.
    return ClinicalReferenceData(
      sourceType: drugs.length > 1
          ? 'polypharmacy_fallback'
          : 'general_fallback',
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
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '')
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

    final pneumonia = containsAny(const <String>['pneumonia', 'neumonia']);

    final sepsis = containsAny(const <String>[
      'sepsis',
      'sepse',
      'choque septico',
      'shock septico',
    ]);

    final arrest =
        containsAny(const <String>[
          'parada cardiorrespiratoria',
          'paro cardiorrespiratorio',
          'ressuscitacao',
          'reanimacion cardiopulmonar',
        ]) ||
        hasWord('rcp');

    if (pediatric && pneumonia) return 'pediatric_pneumonia';
    if (containsAny(const <String>[
      'infeccao neonatal',
      'infecção neonatal',
      'sepsis neonatal',
      'sepse neonatal',
      'sepsis del recien nacido',
      'sepsis del recién nacido',
      'neonatal infection',
      'neonatal sepsis',
      'early onset neonatal infection',
      'late onset neonatal infection',
    ])) {
      return 'neonatal_infection_nice_2026';
    }

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

    // Top200 Expansion / Batch 16 — endocrinology and metabolism.
    // Specific electrolyte, pituitary and adrenal entities precede generic endocrine owners.

    if (containsAny(const <String>[
      'diabetes insipido',
      'diabetes insípido',
      'diabetes insipida',
      'diabetes insípida',
      'diabetes insipidus',
      'central diabetes insipidus',
      'arginine vasopressin deficiency',
      'avp deficiency',
      'avp-d',
      'deficiencia de vasopressina',
      'deficiência de vasopressina',
      'deficiencia de arginina vasopresina',
      'deficiencia de arginina vasopresina',
    ])) {
      return 'arginine_vasopressin_deficiency_ese_es_2026';
    }

    if (containsAny(const <String>[
      'siadh',
      'sindrome de secrecao inapropriada de adh',
      'síndrome de secreção inapropriada de adh',
      'sindrome de secrecion inadecuada de adh',
      'síndrome de secreción inadecuada de adh',
      'syndrome of inappropriate antidiuretic hormone',
      'syndrome of inappropriate antidiuresis',
      'inappropriate antidiuresis',
    ])) {
      return 'siadh_hyponatremia_ese';
    }

    if (containsAny(const <String>[
      'hipercalcemia',
      'hypercalcemia',
      'hipercalcemia grave',
      'severe hypercalcemia',
      'hypercalcaemia',
    ])) {
      return 'hypercalcemia_endocrine_society_2023';
    }

    if (containsAny(const <String>[
      'hipocalcemia',
      'hypocalcemia',
      'hypocalcaemia',
      'hipocalcemia sintomatica',
      'hipocalcemia sintomática',
      'symptomatic hypocalcemia',
    ])) {
      return 'hypocalcemia_hypoparathyroidism_ese_2025';
    }

    if (containsAny(const <String>[
      'hipomagnesemia',
      'hypomagnesemia',
      'hypomagnesaemia',
      'deficiencia de magnesio',
      'deficiência de magnésio',
      'magnesium deficiency',
    ])) {
      return 'hypomagnesemia_core_curriculum_2024';
    }

    if (containsAny(const <String>[
      'hipofosfatemia',
      'hypophosphatemia',
      'hypophosphataemia',
      'deficiencia de fosfato',
      'deficiência de fosfato',
      'phosphate deficiency',
    ])) {
      return 'hypophosphatemia_consensus_2025';
    }

    if (containsAny(const <String>[
      'hipertrigliceridemia grave',
      'hipertrigliceridemia severa',
      'severe hypertriglyceridemia',
      'severe hypertriglyceridaemia',
      'triglicerideos acima de 500',
      'triglicérides acima de 500',
      'triglycerides above 500',
      'triglycerides over 500',
    ])) {
      return 'severe_hypertriglyceridemia_acc_aha_2026';
    }

    if (containsAny(const <String>[
      'sindrome metabolica',
      'síndrome metabólica',
      'sindrome metabolico',
      'síndrome metabólico',
      'metabolic syndrome',
      'metabolic syndrome mets',
      'sindrome x metabolica',
      'síndrome x metabólica',
    ])) {
      return 'metabolic_syndrome_harmonized';
    }

    if (containsAny(const <String>[
      'hipopituitarismo',
      'hypopituitarism',
      'panhypopituitarism',
      'panhipopituitarismo',
      'pituitary hormone deficiency',
      'deficiencia hormonal hipofisaria',
      'deficiência hormonal hipofisária',
    ])) {
      return 'hypopituitarism_endocrine_society';
    }

    if (containsAny(const <String>[
      'incidentaloma adrenal',
      'incidentaloma suprarrenal',
      'adrenal incidentaloma',
      'adrenal incidental mass',
      'massa adrenal incidental',
      'masa suprarrenal incidental',
    ])) {
      return 'adrenal_incidentaloma_ese_2023';
    }

    // Top200 Expansion / Batch 15 — hepatology and pancreas.
    // Specific entities precede generic hepatitis, cholangitis, cirrhosis and pancreatitis owners.

    if (containsAny(const <String>[
      'hepatite alcoolica',
      'hepatite alcoólica',
      'hepatitis alcoholica',
      'hepatitis alcohólica',
      'alcoholic hepatitis',
      'alcohol-associated hepatitis',
      'alcohol associated hepatitis',
      'acute alcoholic hepatitis',
    ])) {
      return 'alcohol_associated_hepatitis_acg_2024';
    }

    if (containsAny(const <String>[
      'doenca hepatica associada ao alcool',
      'doença hepática associada ao álcool',
      'doenca hepatica alcoolica',
      'doença hepática alcoólica',
      'enfermedad hepatica asociada al alcohol',
      'enfermedad hepática asociada al alcohol',
      'enfermedad hepatica alcoholica',
      'enfermedad hepática alcohólica',
      'alcohol-associated liver disease',
      'alcohol associated liver disease',
      'alcohol-related liver disease',
      'alcohol related liver disease',
      'alcoholic liver disease',
    ])) {
      return 'alcohol_associated_liver_disease_acg_2024';
    }

    if (containsAny(const <String>[
      'hepatite autoimune',
      'hepatitis autoinmune',
      'autoimmune hepatitis',
      'aih hepatitis',
      'aih hepatite',
    ])) {
      return 'autoimmune_hepatitis_easl_2025';
    }

    if (containsAny(const <String>[
      'colangite biliar primaria',
      'colangite biliar primária',
      'colangitis biliar primaria',
      'primary biliary cholangitis',
      'pbc cholangitis',
      'cbp colangite',
    ])) {
      return 'primary_biliary_cholangitis_aasld_2021';
    }

    if (containsAny(const <String>[
      'colangite esclerosante primaria',
      'colangite esclerosante primária',
      'colangitis esclerosante primaria',
      'primary sclerosing cholangitis',
      'psc cholangitis',
      'cep colangite',
    ])) {
      return 'primary_sclerosing_cholangitis_aasld_2022';
    }

    if (containsAny(const <String>[
      'insuficiencia pancreatica exocrina',
      'insuficiência pancreática exócrina',
      'insuficiencia pancreatica exocrina',
      'insuficiencia pancreática exocrina',
      'exocrine pancreatic insufficiency',
      'exocrine pancreatic insufficiency epi',
      'pancreatic exocrine insufficiency',
    ])) {
      return 'exocrine_pancreatic_insufficiency_aga_2023';
    }

    if (containsAny(const <String>[
      'cisto pancreatico',
      'cisto pancreático',
      'quiste pancreatico',
      'quiste pancreático',
      'pancreatic cyst',
      'pancreatic cystic lesion',
      'neoplasia mucinosa pancreatica',
      'neoplasia mucinosa pancreática',
      'neoplasia mucinosa pancreatica',
      'neoplasia mucinosa pancreática',
      'mucinous pancreatic neoplasm',
      'intraductal papillary mucinous neoplasm',
      'ipmn',
      'neoplasia mucinosa papilar intraductal',
    ])) {
      return 'pancreatic_cyst_ipmn_kyoto_2024';
    }

    if (containsAny(const <String>[
      'pancreatite cronica',
      'pancreatite crônica',
      'pancreatitis cronica',
      'pancreatitis crónica',
      'chronic pancreatitis',
      'pancreatite cronica calcificante',
      'pancreatite crônica calcificante',
      'chronic calcific pancreatitis',
    ])) {
      return 'chronic_pancreatitis_acg_2020';
    }

    if (containsAny(const <String>[
      'hemocromatose hereditaria',
      'hemocromatose hereditária',
      'hemocromatosis hereditaria',
      'hereditary hemochromatosis',
      'hereditary haemochromatosis',
      'hfe hemochromatosis',
      'hfe haemochromatosis',
    ])) {
      return 'hereditary_hemochromatosis_easl_2022';
    }

    if (containsAny(const <String>[
      'doenca de wilson',
      'doença de wilson',
      'enfermedad de wilson',
      'wilson disease',
      'wilsons disease',
      'hepatolenticular degeneration',
      'degeneracao hepatolenticular',
      'degeneração hepatolenticular',
      'degeneracion hepatolenticular',
      'degeneración hepatolenticular',
    ])) {
      return 'wilson_disease_easl_2025';
    }

    // Top200 Expansion / Batch 14 — gastroenterology.
    // Specific diagnoses precede generic GI bleeding, dyspepsia, IBD and H. pylori owners.

    if (containsAny(const <String>[
      'gastroparesia',
      'gastroparesis',
      'delayed gastric emptying',
      'retardo do esvaziamento gastrico',
      'retardo do esvaziamento gástrico',
      'vaciamiento gastrico retardado',
      'vaciamiento gástrico retardado',
    ])) {
      return 'gastroparesis_aga_2025';
    }

    if (containsAny(const <String>[
      'gastropatia por aine',
      'gastropatia por aines',
      'gastropatía por aine',
      'gastropatía por aines',
      'gastrite por aine',
      'gastritis por aine',
      'nsaid gastropathy',
      'nsaid gastritis',
      'nsaid induced gastropathy',
      'anti inflammatory induced gastropathy',
    ])) {
      return 'nsaid_gastropathy_ulcer_prevention';
    }

    if (containsAny(const <String>[
      'ulcera peptica',
      'úlcera péptica',
      'ulcera peptica',
      'úlcera péptica',
      'peptic ulcer disease',
      'gastric ulcer',
      'duodenal ulcer',
      'ulcera gastrica',
      'úlcera gástrica',
      'ulcera duodenal',
      'úlcera duodenal',
    ])) {
      return 'peptic_ulcer_disease_esge_2026';
    }

    if (containsAny(const <String>[
      'dispepsia funcional',
      'functional dyspepsia',
      'dispepsia funcional pos prandial',
      'dispepsia funcional pós-prandial',
      'postprandial distress syndrome',
      'epigastric pain syndrome',
    ])) {
      return 'functional_dyspepsia_bsg_2022';
    }

    if (containsAny(const <String>[
      'doenca diverticular nao complicada',
      'doença diverticular não complicada',
      'enfermedad diverticular no complicada',
      'uncomplicated diverticular disease',
      'symptomatic uncomplicated diverticular disease',
      'diverticulose sintomatica',
      'diverticulose sintomática',
      'diverticulosis sintomatica',
      'diverticulosis sintomática',
    ])) {
      return 'uncomplicated_diverticular_disease_acg_2026';
    }

    if (containsAny(const <String>[
      'colite isquemica',
      'colite isquêmica',
      'colitis isquemica',
      'colitis isquémica',
      'ischemic colitis',
      'ischaemic colitis',
      'colon ischemia',
      'colonic ischemia',
    ])) {
      return 'ischemic_colitis_acg';
    }

    if (containsAny(const <String>[
      'colite microscopica',
      'colite microscópica',
      'colitis microscopica',
      'colitis microscópica',
      'microscopic colitis',
      'collagenous colitis',
      'lymphocytic colitis',
      'colite colagenosa',
      'colite linfocitica',
      'colite linfocítica',
    ])) {
      return 'microscopic_colitis_ueg_emcg_2021';
    }

    if (containsAny(const <String>[
      'proctite',
      'proctitis',
      'proctite aguda',
      'proctitis aguda',
      'ulcerative proctitis',
      'proctite ulcerativa',
      'proctitis ulcerativa',
    ])) {
      return 'proctitis_multietiology_guidance';
    }

    if (containsAny(const <String>[
      'incontinencia fecal',
      'incontinência fecal',
      'incontinencia fecal',
      'fecal incontinence',
      'faecal incontinence',
      'anal incontinence',
    ])) {
      return 'fecal_incontinence_ascrs_2023';
    }

    if (containsAny(const <String>[
      'hemorragia digestiva baixa',
      'hemorragia gastrointestinal baixa',
      'hemorragia digestiva baja',
      'hemorragia gastrointestinal baja',
      'lower gastrointestinal bleeding',
      'lower gi bleeding',
      'acute lower gi bleed',
      'hematochezia with lower gi bleeding',
    ])) {
      return 'lower_gi_bleeding_acg_2023';
    }

    // Top200 Expansion / Batch 13 — pneumology and pleural disease.
    // Specific entities precede generic pneumonia/cough/respiratory owners.

    if (!containsAny(const <String>[
          'pneumotorax aberto',
          'pneumotórax aberto',
          'neumotorax abierto',
          'neumotórax abierto',
          'open pneumothorax',
          'pneumotorax hipertensivo',
          'pneumotórax hipertensivo',
          'neumotorax a tension',
          'neumotórax a tensión',
          'tension pneumothorax',
          'pneumotorax traumatico',
          'pneumotórax traumático',
          'neumotorax traumatico',
          'neumotórax traumático',
          'traumatic pneumothorax',
        ]) &&
        containsAny(const <String>[
          'pneumotorax espontaneo',
          'pneumotórax espontâneo',
          'neumotorax espontaneo',
          'neumotórax espontáneo',
          'spontaneous pneumothorax',
          'primary spontaneous pneumothorax',
          'secondary spontaneous pneumothorax',
        ])) {
      return 'spontaneous_pneumothorax_ers_bts_2024';
    }

    if (!containsAny(const <String>[
          'hemotorax macico',
          'hemotórax maciço',
          'hemotorax massivo',
          'hemotórax massivo',
          'hemotorax masivo',
          'hemotórax masivo',
          'massive hemothorax',
          'hemotorax traumatico',
          'hemotórax traumático',
          'hemotorax traumatico',
          'hemotórax traumático',
          'traumatic hemothorax',
        ]) &&
        containsAny(const <String>['hemotorax', 'hemotórax', 'hemothorax'])) {
      return 'hemothorax_trauma_guidelines';
    }

    if (containsAny(const <String>[
      'empiema pleural',
      'empiema toracico',
      'empiema torácico',
      'empiema',
      'pleural empyema',
      'thoracic empyema',
      'pleural infection',
      'infected pleural effusion',
      'parapneumonic effusion',
      'parapneumonic pleural effusion',
      'derrame parapneumonico',
      'efusao parapneumonica',
      'infeccao pleural',
      'infecção pleural',
      'infeccion pleural',
      'infección pleural',
    ])) {
      return 'pleural_empyema_bts_2023';
    }

    if (containsAny(const <String>[
      'derrame pleural',
      'derrame pleural unilateral',
      'efusao pleural',
      'efusão pleural',
      'efusion pleural',
      'efusión pleural',
      'pleural effusion',
      'unilateral pleural effusion',
    ])) {
      return 'pleural_effusion_bts_2023';
    }

    if (containsAny(const <String>[
      'abscesso pulmonar',
      'absceso pulmonar',
      'lung abscess',
      'pulmonary abscess',
    ])) {
      return 'lung_abscess_lower_respiratory_guidance';
    }

    if (containsAny(const <String>[
      'pneumonia aspirativa',
      'pneumonia por aspiracao',
      'pneumonia por aspiração',
      'neumonia aspirativa',
      'neumonia por aspiracion',
      'neumonía por aspiración',
      'aspiration pneumonia',
      'aspiration pneumonitis',
    ])) {
      return 'aspiration_pneumonia_bts_2023';
    }

    if (containsAny(const <String>[
      'bronquite aguda',
      'bronquitis aguda',
      'acute bronchitis',
      'acute uncomplicated bronchitis',
    ])) {
      return 'acute_bronchitis_antibiotic_stewardship';
    }

    if (containsAny(const <String>[
      'fibrose cistica',
      'fibrose cística',
      'fibrosis quistica',
      'fibrosis quística',
      'cystic fibrosis',
      'mucoviscidose',
      'mucoviscidosis',
    ])) {
      return 'cystic_fibrosis_ecfs_cff_2024';
    }

    if (containsAny(const <String>[
      'tosse cronica',
      'tosse crônica',
      'tos cronica',
      'tos crónica',
      'chronic cough',
      'refractory chronic cough',
    ])) {
      return 'chronic_cough_ers_bts';
    }

    if (containsAny(const <String>[
      'sarcoidose pulmonar',
      'sarcoidosis pulmonar',
      'pulmonary sarcoidosis',
      'sarcoidosis lung',
    ])) {
      return 'pulmonary_sarcoidosis_ers_ats';
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

    // Top200 Expansion / Batch 30 — ENT and ophthalmology.
    // Acute/chronic sinonasal, external-ear/hearing and specific ocular disease
    // owners precede generic ENT, red-eye, vision-loss and ophthalmic owners.

    if (containsAny(const <String>[
      'rinossinusite aguda',
      'rinossinusite bacteriana aguda',
      'sinusite aguda',
      'sinusite bacteriana aguda',
      'rinosinusitis aguda',
      'rinosinusitis bacteriana aguda',
      'sinusitis aguda',
      'sinusitis bacteriana aguda',
      'acute rhinosinusitis',
      'acute bacterial rhinosinusitis',
      'acute sinusitis',
      'abrs sinusitis',
    ])) {
      return 'acute_rhinosinusitis_aao_hns_2025';
    }

    if (containsAny(const <String>[
      'rinossinusite cronica',
      'rinossinusite crônica',
      'sinusite cronica',
      'sinusite crônica',
      'rinossinusite cronica com polipos',
      'rinossinusite crônica com pólipos',
      'rinosinusitis cronica',
      'rinosinusitis crónica',
      'sinusitis cronica',
      'sinusitis crónica',
      'chronic rhinosinusitis',
      'chronic sinusitis',
      'crs with nasal polyps',
      'crs without nasal polyps',
      'crswnp',
      'crssnp',
    ])) {
      return 'chronic_rhinosinusitis_aao_hns_2025';
    }

    if (containsAny(const <String>[
      'rinite alergica',
      'rinite alérgica',
      'rinite sazonal alergica',
      'rinite sazonal alérgica',
      'rinitis alergica',
      'rinitis alérgica',
      'rinitis alergica estacional',
      'rinitis alérgica estacional',
      'allergic rhinitis',
      'seasonal allergic rhinitis',
      'perennial allergic rhinitis',
      'hay fever allergic rhinitis',
    ])) {
      return 'allergic_rhinitis_aria_eaaci_2026';
    }

    if (containsAny(const <String>[
      'otite externa aguda',
      'otite externa difusa',
      'ouvido de nadador',
      'otitis externa aguda',
      'otitis externa difusa',
      'oido de nadador',
      'oído de nadador',
      'acute otitis externa',
      'diffuse acute otitis externa',
      'swimmers ear',
      "swimmer's ear",
      'aoe external ear',
    ])) {
      return 'acute_otitis_externa_aao_hns_current';
    }

    if (containsAny(const <String>[
      'perda auditiva neurossensorial subita',
      'perda auditiva neurossensorial súbita',
      'surdez subita neurossensorial',
      'surdez súbita neurossensorial',
      'hipoacusia neurosensorial subita',
      'hipoacusia neurosensorial súbita',
      'sudden sensorineural hearing loss',
      'sudden neurosensory hearing loss',
      'idiopathic sudden sensorineural hearing loss',
      'ssnhl',
      'issnhl',
    ])) {
      return 'sudden_sensorineural_hearing_loss_aao_hns_japan';
    }

    if (containsAny(const <String>[
      'conjuntivite bacteriana',
      'conjuntivite viral',
      'conjuntivite infecciosa',
      'conjuntivitis bacteriana',
      'conjuntivitis viral',
      'conjuntivitis infecciosa',
      'bacterial conjunctivitis',
      'viral conjunctivitis',
      'infectious conjunctivitis',
      'pink eye conjunctivitis',
    ])) {
      return 'conjunctivitis_aao_2024';
    }

    if (containsAny(const <String>[
      'ceratite bacteriana',
      'ceratite infecciosa',
      'ulcera de cornea infecciosa',
      'úlcera de córnea infecciosa',
      'queratitis bacteriana',
      'queratitis infecciosa',
      'ulcera corneal infecciosa',
      'úlcera corneal infecciosa',
      'bacterial keratitis',
      'infectious keratitis',
      'microbial keratitis',
      'infectious corneal ulcer',
    ])) {
      return 'bacterial_keratitis_aao_2024';
    }

    if (containsAny(const <String>[
      'uveite anterior',
      'uveíte anterior',
      'uveite intermediaria',
      'uveíte intermediária',
      'uveite posterior',
      'uveíte posterior',
      'panuveite',
      'uveitis anterior',
      'uveitis intermedia',
      'uveitis posterior',
      'panuveitis',
      'anterior uveitis',
      'intermediate uveitis',
      'posterior uveitis',
      'noninfectious uveitis',
      'non-infectious uveitis',
      'panuveitis',
    ])) {
      return 'uveitis_dog_ser_consensus_2025';
    }

    if (containsAny(const <String>[
      'glaucoma primario de angulo aberto',
      'glaucoma primário de ângulo aberto',
      'glaucoma de angulo aberto',
      'glaucoma de ângulo aberto',
      'glaucoma primario de angulo abierto',
      'glaucoma primário de ángulo abierto',
      'glaucoma de angulo abierto',
      'glaucoma de ángulo abierto',
      'primary open angle glaucoma',
      'primary open-angle glaucoma',
      'open angle glaucoma',
      'open-angle glaucoma',
      'poag glaucoma',
    ])) {
      return 'primary_open_angle_glaucoma_aao_2026';
    }

    if (containsAny(const <String>[
      'catarata senil',
      'catarata relacionada a idade',
      'catarata relacionada à idade',
      'catarata do adulto',
      'catarata senil',
      'catarata relacionada con la edad',
      'catarata del adulto',
      'age related cataract',
      'age-related cataract',
      'adult cataract',
      'senile cataract',
    ])) {
      return 'adult_cataract_aao_nice_current';
    }

    // Top200 Expansion / Batch 29 — pediatrics.
    // Explicit pediatric infectious, airway, ENT, hydration, vasculitic,
    // exanthem, seizure and neurodevelopmental entities precede generic owners.

    if (containsAny(const <String>[
      'coqueluche pediatrica',
      'coqueluche pediátrica',
      'tosse comprida pediatrica',
      'tosse comprida pediátrica',
      'tos ferina pediatrica',
      'tos ferina pediátrica',
      'tosferina pediatrica',
      'tosferina pediátrica',
      'pertussis pediatrica',
      'pertussis pediátrica',
      'pediatric pertussis',
      'paediatric pertussis',
      'whooping cough child',
      'whooping cough infant',
      'bordetella pertussis child',
      'bordetella pertussis infant',
    ])) {
      return 'pediatric_pertussis_cdc_2026';
    }

    if (containsAny(const <String>[
      'crupe pediatrico',
      'crupe pediátrico',
      'laringotraqueite viral',
      'laringotraqueobronquite',
      'laringitis obstructiva pediatrica',
      'laringitis obstructiva pediátrica',
      'crup pediatrico',
      'crup pediátrico',
      'pediatric croup',
      'paediatric croup',
      'viral croup child',
      'laryngotracheobronchitis',
      'viral laryngotracheitis child',
    ])) {
      return 'pediatric_croup_cps_2026';
    }

    if (containsAny(const <String>[
      'otite media aguda pediatrica',
      'otite média aguda pediátrica',
      'oma pediatrica',
      'oma pediátrica',
      'otitis media aguda pediatrica',
      'otitis media aguda pediátrica',
      'oma pediatrica',
      'oma pediátrica',
      'pediatric acute otitis media',
      'paediatric acute otitis media',
      'acute otitis media child',
      'acute otitis media infant',
      'aom child',
    ])) {
      return 'pediatric_acute_otitis_media_aap_nice';
    }

    if (containsAny(const <String>[
      'escarlatina pediatrica',
      'escarlatina pediátrica',
      'febre escarlate pediatrica',
      'febre escarlate pediátrica',
      'escarlatina pediatrica',
      'escarlatina pediátrica',
      'scarlet fever child',
      'scarlet fever pediatric',
      'scarlet fever paediatric',
      'scarlatina child',
      'group a strep scarlet fever child',
    ])) {
      return 'pediatric_scarlet_fever_cdc_2026';
    }

    // Dehydration is placed before gastroenteritis only for explicit pediatric
    // dehydration wording, so AGE with dehydration remains owned by AGE.
    if (containsAny(const <String>[
      'desidratacao pediatrica',
      'desidratação pediátrica',
      'desidratacao infantil',
      'desidratação infantil',
      'deshidratacion pediatrica',
      'deshidratación pediátrica',
      'deshidratacion infantil',
      'deshidratación infantil',
      'pediatric dehydration',
      'paediatric dehydration',
      'dehydration in children',
      'dehydration in child',
      'dehydrated child',
    ])) {
      return 'pediatric_dehydration_rch_2026';
    }

    if (containsAny(const <String>[
      'gastroenterite aguda pediatrica',
      'gastroenterite aguda pediátrica',
      'gastroenterite viral pediatrica',
      'gastroenterite viral pediátrica',
      'gastroenteritis aguda pediatrica',
      'gastroenteritis aguda pediátrica',
      'gastroenteritis viral pediatrica',
      'gastroenteritis viral pediátrica',
      'pediatric acute gastroenteritis',
      'paediatric acute gastroenteritis',
      'acute gastroenteritis child',
      'viral gastroenteritis child',
      'acute watery diarrhea child',
      'acute watery diarrhoea child',
    ])) {
      return 'pediatric_acute_gastroenteritis_who_2024';
    }

    if (containsAny(const <String>[
      'doenca de kawasaki',
      'doença de kawasaki',
      'sindrome de kawasaki',
      'síndrome de kawasaki',
      'enfermedad de kawasaki',
      'sindrome de kawasaki',
      'síndrome de kawasaki',
      'kawasaki disease',
      'kawasaki syndrome',
      'mucocutaneous lymph node syndrome',
    ])) {
      return 'kawasaki_disease_aha_2024';
    }

    if (containsAny(const <String>[
      'doenca mao pe boca',
      'doença mão pé boca',
      'doenca mao-pe-boca',
      'doença mão-pé-boca',
      'enfermedad mano pie boca',
      'enfermedad mano-pie-boca',
      'hand foot and mouth disease',
      'hand-foot-and-mouth disease',
      'hfmd child',
      'coxsackie hand foot mouth',
    ])) {
      return 'hand_foot_mouth_disease_cdc_who';
    }

    if (containsAny(const <String>[
      'convulsao febril',
      'convulsão febril',
      'crise convulsiva febril',
      'convulsión febril',
      'convulsion febril',
      'crisis febril convulsiva',
      'febrile seizure',
      'simple febrile seizure',
      'complex febrile seizure',
      'febrile convulsion',
    ])) {
      return 'febrile_seizure_aap_rch_current';
    }

    if (containsAny(const <String>[
      'transtorno do espectro autista',
      'transtorno do espectro do autismo',
      'tea pediatrico',
      'tea pediátrico',
      'trastorno del espectro autista',
      'tea pediatrico',
      'tea pediátrico',
      'autism spectrum disorder',
      'autistic spectrum disorder',
      'pediatric autism',
      'paediatric autism',
      'asd child autism',
    ])) {
      return 'autism_spectrum_disorder_aap_2025';
    }

    // Top200 Expansion / Batch 28 — gynecology and obstetrics.
    // Specific benign uterine, vaginitis/STI and obstetric placental/membrane
    // entities precede generic bleeding, vaginitis, pregnancy and preterm owners.

    if (containsAny(const <String>[
      'mioma uterino',
      'miomas uterinos',
      'leiomioma uterino',
      'leiomiomas uterinos',
      'fibroma uterino',
      'fibromas uterinos',
      'mioma uterino',
      'miomas uterinos',
      'leiomioma uterino',
      'leiomiomas uterinos',
      'uterine fibroid',
      'uterine fibroids',
      'uterine leiomyoma',
      'uterine leiomyomas',
    ])) {
      return 'uterine_fibroids_acog_nice_2025';
    }

    if (containsAny(const <String>[
      'adenomiose',
      'adenomiose uterina',
      'adenomiosis',
      'adenomiosis uterina',
      'adenomyosis',
      'uterine adenomyosis',
      'diffuse adenomyosis',
      'focal adenomyosis',
    ])) {
      return 'adenomyosis_asea_nice_2023';
    }

    if (containsAny(const <String>[
      'vaginose bacteriana',
      'vaginosis bacteriana',
      'bacterial vaginosis',
      'bv vaginosis',
      'vb vaginose',
      'gardnerella bacterial vaginosis',
    ])) {
      return 'bacterial_vaginosis_cdc_who_acog_2025';
    }

    if (containsAny(const <String>[
      'candidiase vulvovaginal',
      'candidíase vulvovaginal',
      'candidiase vaginal',
      'candidíase vaginal',
      'candidiasis vulvovaginal',
      'candidiasis vaginal',
      'vulvovaginal candidiasis',
      'vaginal candidiasis',
      'vvc candidiasis',
      'yeast vaginitis',
    ])) {
      return 'vulvovaginal_candidiasis_cdc_who_idsa';
    }

    if (containsAny(const <String>[
      'tricomoníase',
      'tricomoniase',
      'tricomoniasis',
      'trichomoniasis',
      'trichomonas vaginalis',
      'infeccao por trichomonas',
      'infecção por trichomonas',
      'infeccion por trichomonas',
      'infección por trichomonas',
    ])) {
      return 'trichomoniasis_cdc_who_current';
    }

    if (containsAny(const <String>[
      'doenca trofoblastica gestacional',
      'doença trofoblástica gestacional',
      'neoplasia trofoblastica gestacional',
      'neoplasia trofoblástica gestacional',
      'mola hidatiforme',
      'enfermedad trofoblastica gestacional',
      'enfermedad trofoblástica gestacional',
      'neoplasia trofoblastica gestacional',
      'neoplasia trofoblástica gestacional',
      'mola hidatidiforme',
      'gestational trophoblastic disease',
      'gestational trophoblastic neoplasia',
      'hydatidiform mole',
      'molar pregnancy',
      'gtd pregnancy',
      'gtn trophoblastic',
    ])) {
      return 'gestational_trophoblastic_disease_figo_2025';
    }

    if (containsAny(const <String>[
      'hiperemese gravidica',
      'hiperêmese gravídica',
      'hiperemesis gravidica',
      'hiperemesis gravídica',
      'hiperemesis gravidarum',
      'hyperemesis gravidarum',
      'severe nausea vomiting pregnancy',
      'nausea vomiting pregnancy hyperemesis',
      'hg pregnancy',
    ])) {
      return 'hyperemesis_gravidarum_rcog_2024';
    }

    if (containsAny(const <String>[
      'placenta previa',
      'placenta prévia',
      'placenta previa total',
      'placenta previa parcial',
      'placenta previa',
      'placenta previa total',
      'placenta previa parcial',
      'placenta praevia',
      'placenta previa',
      'low lying placenta previa',
      'low-lying placenta previa',
    ])) {
      return 'placenta_previa_rcog_2026';
    }

    if (containsAny(const <String>[
      'descolamento prematuro de placenta',
      'descolamento prematuro da placenta',
      'desprendimento prematuro de placenta',
      'desprendimiento prematuro de placenta',
      'desprendimiento placentario',
      'abruptio placentae',
      'placental abruption',
      'chronic placental abruption',
      'acute placental abruption',
    ])) {
      return 'placental_abruption_rcog_acog_current';
    }

    if (containsAny(const <String>[
      'ruptura prematura de membranas',
      'rotura prematura de membranas',
      'ruptura pre termo de membranas',
      'ruptura pré-termo de membranas',
      'rotura pretermino de membranas',
      'rotura pretérmino de membranas',
      'prelabor rupture of membranes',
      'prelabour rupture of membranes',
      'preterm prelabor rupture of membranes',
      'preterm prelabour rupture of membranes',
      'prom pregnancy',
      'pprom',
    ])) {
      return 'prelabor_rupture_membranes_acog_2026';
    }

    // Top200 Expansion / Batch 27 — dermatology autoimmune and tumors.
    // Specific dermatophyte/Candida/HS/autoimmune bullous/pigmentary/hair and
    // cutaneous tumor entities precede generic fungal, alopecia and skin-cancer owners.

    if (containsAny(const <String>[
      'tinea corporis',
      'tinea cruris',
      'tinea pedis',
      'tinea faciei',
      'tinea manuum',
      'dermatofitose cutanea',
      'dermatofitose cutânea',
      'dermatofitosis cutanea',
      'dermatofitosis cutánea',
      'cutaneous dermatophytosis',
      'dermatophyte infection skin',
      'ringworm',
    ])) {
      return 'cutaneous_dermatophytosis_aad_cdc_2026';
    }

    if (containsAny(const <String>[
      'candidiase cutanea',
      'candidíase cutânea',
      'candidiase de pele',
      'candidíase de pele',
      'candidiasis cutanea',
      'candidiasis cutánea',
      'cutaneous candidiasis',
      'candida intertrigo',
      'candidal intertrigo',
      'cutaneous candida infection',
    ])) {
      return 'cutaneous_candidiasis_idsa_cdc_current';
    }

    if (containsAny(const <String>[
      'hidradenite supurativa',
      'hidradenite supurativa',
      'hidradenitis supurativa',
      'hidradenitis suppurativa',
      'acne inversa',
      'acne inversa',
      'hs hidradenitis',
      'hs hidradenite',
    ])) {
      return 'hidradenitis_suppurativa_aad_2026';
    }

    if (containsAny(const <String>[
      'vitiligo',
      'vitiligo nao segmentar',
      'vitiligo não segmentar',
      'vitiligo no segmentario',
      'vitiligo no segmentario',
      'nonsegmental vitiligo',
      'non-segmental vitiligo',
      'segmental vitiligo',
    ])) {
      return 'vitiligo_bad_2021_current';
    }

    if (containsAny(const <String>[
      'alopecia areata',
      'alopecia areata em placas',
      'alopecia areata en placas',
      'alopecia totalis',
      'alopecia universalis',
      'patchy alopecia areata',
      'autoimmune alopecia areata',
    ])) {
      return 'alopecia_areata_bad_living_2024';
    }

    if (containsAny(const <String>[
      'penfigo vulgar',
      'pênfigo vulgar',
      'penfigo vulgar',
      'pénfigo vulgar',
      'pemphigus vulgaris',
      'mucocutaneous pemphigus vulgaris',
      'mucosal pemphigus vulgaris',
    ])) {
      return 'pemphigus_vulgaris_eadv_2020_current';
    }

    if (containsAny(const <String>[
      'penfigoide bolhoso',
      'penfigoide bolhoso',
      'penfigoide ampolloso',
      'penfigoide ampolloso',
      'bullous pemphigoid',
      'bp pemphigoid',
      'autoimmune bullous pemphigoid',
    ])) {
      return 'bullous_pemphigoid_eadv_2022_current';
    }

    if (containsAny(const <String>[
      'melanoma cutaneo',
      'melanoma cutâneo',
      'melanoma de pele',
      'melanoma cutaneo',
      'melanoma cutáneo',
      'cutaneous melanoma',
      'skin melanoma',
      'malignant melanoma skin',
    ])) {
      return 'cutaneous_melanoma_aad_current';
    }

    if (containsAny(const <String>[
      'carcinoma basocelular',
      'cancer basocelular',
      'câncer basocelular',
      'carcinoma basocelular cutaneo',
      'carcinoma basocelular cutáneo',
      'basal cell carcinoma',
      'basal cell skin cancer',
      'bcc skin cancer',
    ])) {
      return 'basal_cell_carcinoma_aad_current';
    }

    if (containsAny(const <String>[
      'carcinoma espinocelular cutaneo',
      'carcinoma espinocelular cutâneo',
      'carcinoma de celulas escamosas cutaneo',
      'carcinoma de células escamosas cutâneo',
      'carcinoma epidermoide cutaneo',
      'carcinoma epidermoide cutáneo',
      'cutaneous squamous cell carcinoma',
      'squamous cell carcinoma of skin',
      'cutaneous scc',
      'cscc',
    ])) {
      return 'cutaneous_squamous_cell_carcinoma_aad_current';
    }

    // Top200 Expansion / Batch 26 — inflammatory and infectious dermatology.
    // Specific dermatitis, urticaria/angioedema, acne/rosacea and superficial
    // infection/infestation entities precede generic eczema/SSTI owners.

    if (containsAny(const <String>[
      'dermatite atopica',
      'dermatite atópica',
      'eczema atopico',
      'eczema atópico',
      'dermatitis atopica',
      'dermatitis atópica',
      'eczema atopico',
      'eczema atópico',
      'atopic dermatitis',
      'atopic eczema',
    ])) {
      return 'atopic_dermatitis_aad_2026';
    }

    if (containsAny(const <String>[
      'dermatite de contato',
      'dermatite de contacto',
      'dermatite alergica de contato',
      'dermatite alérgica de contato',
      'dermatite irritativa de contato',
      'dermatitis de contacto',
      'dermatitis alergica de contacto',
      'dermatitis alérgica de contacto',
      'contact dermatitis',
      'allergic contact dermatitis',
      'irritant contact dermatitis',
    ])) {
      return 'contact_dermatitis_bad_escd_2025';
    }

    if (containsAny(const <String>[
      'dermatite seborreica',
      'dermatite seborreica do couro cabeludo',
      'dermatitis seborreica',
      'dermatitis seborreica del cuero cabelludo',
      'seborrheic dermatitis',
      'seborrhoeic dermatitis',
      'scalp seborrheic dermatitis',
      'scalp seborrhoeic dermatitis',
    ])) {
      return 'seborrheic_dermatitis_eadv_2026';
    }

    if (containsAny(const <String>[
      'psoriase',
      'psoríase',
      'psoriasis',
      'psoriasis vulgar',
      'psoriasis em placas',
      'psoriasis en placas',
      'plaque psoriasis',
    ])) {
      return 'psoriasis_aad_npf_current';
    }

    if (containsAny(const <String>[
      'urticaria cronica',
      'urticária crônica',
      'urticaria cronica espontanea',
      'urticária crônica espontânea',
      'urticaria cronica espontanea',
      'urticaria crónica espontánea',
      'chronic urticaria',
      'chronic spontaneous urticaria',
      'csu urticaria',
    ])) {
      return 'chronic_urticaria_euroguiderm_eaaci_2022';
    }

    if (containsAny(const <String>[
      'angioedema hereditario',
      'angioedema hereditário',
      'angioedema por bradicinina',
      'angioedema sem urticaria',
      'angioedema sem urticária',
      'angioedema hereditario',
      'angioedema por bradicinina',
      'angioedema sin urticaria',
      'hereditary angioedema',
      'bradykinin mediated angioedema',
      'bradykinin-mediated angioedema',
      'angioedema without urticaria',
      'hae angioedema',
    ])) {
      return 'hereditary_angioedema_wao_2025';
    }

    if (containsAny(const <String>[
      'acne vulgar',
      'acne vulgaris',
      'acne inflamatoria',
      'acne inflamatória',
      'acne inflamatorio',
      'acne inflamatorio',
      'acne inflammatory',
      'inflammatory acne',
    ])) {
      return 'acne_vulgaris_aad_2024';
    }

    if (containsAny(const <String>[
      'rosacea',
      'rosácea',
      'rosacea papulopustular',
      'rosácea papulopustular',
      'rosacea papulopustular',
      'papulopustular rosacea',
      'erythematotelangiectatic rosacea',
      'ocular rosacea',
    ])) {
      return 'rosacea_global_consensus_2024';
    }

    if (containsAny(const <String>[
      'impetigo',
      'impetigo bolhoso',
      'impetigo no bolhoso',
      'impetigo não bolhoso',
      'impetigo ampolloso',
      'impetigo no ampolloso',
      'bullous impetigo',
      'nonbullous impetigo',
      'non-bullous impetigo',
    ])) {
      return 'impetigo_nice_2026';
    }

    if (containsAny(const <String>[
      'escabiose',
      'sarna',
      'sarna humana',
      'escabiosis',
      'sarna humana',
      'scabies',
      'human scabies',
      'crusted scabies',
      'sarna norueguesa',
      'sarna noruega',
    ])) {
      return 'scabies_cdc_current';
    }

    // Top200 Expansion / Batch 25 — rheumatology and musculoskeletal.
    // Specific inflammatory/crystal/paediatric/vasospastic/spine/shoulder entities
    // precede generic pain, arthritis, low-back, sciatica and shoulder owners.

    if (containsAny(const <String>[
      'fibromialgia',
      'sindrome de fibromialgia',
      'síndrome de fibromialgia',
      'fibromialgia',
      'fibromyalgia',
      'fibromyalgia syndrome',
      'chronic widespread pain fibromyalgia',
    ])) {
      return 'fibromyalgia_eular_nice_current';
    }

    if (containsAny(const <String>[
      'artrite reativa',
      'artritis reactiva',
      'reactive arthritis',
      'post infectious reactive arthritis',
      'post-infectious reactive arthritis',
      'reiter syndrome',
      'sindrome de reiter',
      'síndrome de reiter',
    ])) {
      return 'reactive_arthritis_acr_2025';
    }

    if (containsAny(const <String>[
      'doenca por deposicao de pirofosfato de calcio',
      'doença por deposição de pirofosfato de cálcio',
      'enfermedad por deposito de pirofosfato de calcio',
      'enfermedad por depósito de pirofosfato de calcio',
      'calcium pyrophosphate deposition disease',
      'calcium pyrophosphate deposition',
      'cppd',
      'pseudogota',
      'pseudogout',
      'condrocalcinose',
      'chondrocalcinosis',
    ])) {
      return 'cppd_acr_eular_2023';
    }

    if (containsAny(const <String>[
      'polimiosite',
      'polimiositis',
      'polymyositis',
      'dermatomiosite',
      'dermatomiositis',
      'dermatomyositis',
      'miopatia inflamatoria idiopatica',
      'miopatia inflamatória idiopática',
      'miopatia inflamatoria idiopatica',
      'miopatía inflamatoria idiopática',
      'idiopathic inflammatory myopathy',
      'idiopathic inflammatory myositis',
      'iim myositis',
    ])) {
      return 'idiopathic_inflammatory_myopathy_bsr_2022';
    }

    if (containsAny(const <String>[
      'artrite idiopatica juvenil',
      'artrite idiopática juvenil',
      'artritis idiopatica juvenil',
      'artritis idiopática juvenil',
      'juvenile idiopathic arthritis',
      'jia arthritis',
      'aiJ juvenil',
      'aij juvenil',
    ])) {
      return 'juvenile_idiopathic_arthritis_acr_2026';
    }

    if (containsAny(const <String>[
      'raynaud primario',
      'raynaud primário',
      'fenomeno de raynaud primario',
      'fenômeno de raynaud primário',
      'raynaud primario',
      'raynaud primário',
      'fenomeno de raynaud primario',
      'fenómeno de raynaud primario',
      'primary raynaud',
      'primary raynaud phenomenon',
      "primary raynaud's phenomenon",
      'primary raynaud disease',
    ])) {
      return 'primary_raynaud_acr_2025';
    }

    if (containsAny(const <String>[
      'lombalgia inespecifica',
      'lombalgia inespecífica',
      'dor lombar inespecifica',
      'dor lombar inespecífica',
      'lumbalgia inespecifica',
      'lumbalgia inespecífica',
      'dolor lumbar inespecifico',
      'dolor lumbar inespecífico',
      'nonspecific low back pain',
      'non specific low back pain',
      'non-specific low back pain',
      'chronic primary low back pain',
      'mechanical low back pain',
    ])) {
      return 'nonspecific_low_back_pain_who_nice';
    }

    if (containsAny(const <String>[
      'radiculopatia lombar',
      'radiculopatia lumbar',
      'lumbar radiculopathy',
      'ciatalgia',
      'ciatica',
      'ciática',
      'sciatica',
      'lumbosciatica',
      'lumbociatalgia',
      'lumbar nerve root pain',
    ])) {
      return 'lumbar_radiculopathy_sciatica_nice';
    }

    if (containsAny(const <String>[
      'cervicalgia inespecifica',
      'cervicalgia inespecífica',
      'dor cervical inespecifica',
      'dor cervical inespecífica',
      'cervicalgia inespecifica',
      'cervicalgia inespecífica',
      'dolor cervical inespecifico',
      'dolor cervical inespecífico',
      'nonspecific neck pain',
      'non-specific neck pain',
      'mechanical neck pain',
      'neck pain with mobility deficits',
    ])) {
      return 'nonspecific_cervicalgia_jospt_current';
    }

    if (containsAny(const <String>[
      'lesao do manguito rotador',
      'lesão do manguito rotador',
      'sindrome do manguito rotador',
      'síndrome do manguito rotador',
      'lesion del manguito rotador',
      'lesión del manguito rotador',
      'rotator cuff injury',
      'rotator cuff tear',
      'rotator cuff syndrome',
      'rotator cuff tendinopathy',
      'rotator cuff tendinitis',
      'rotator cuff tendon tear',
    ])) {
      return 'rotator_cuff_injury_aaos_2025';
    }

    // Top200 Expansion / Batch 24 — oncology.
    // Specific hematologic and solid tumour entities precede generic leukemia,
    // lymphoma, organ-cancer and broad oncology owners.

    if (containsAny(const <String>[
      'leucemia linfoblastica aguda',
      'leucemia linfoblástica aguda',
      'leucemia linfoide aguda',
      'leucemia linfocitica aguda',
      'leucemia linfocítica aguda',
      'leucemia linfoblastica aguda',
      'leucemia linfoblástica aguda',
      'leucemia linfoide aguda',
      'acute lymphoblastic leukemia',
      'acute lymphoblastic leukaemia',
      'acute lymphocytic leukemia',
      'acute lymphocytic leukaemia',
      'adult all leukemia',
      'adult all leukaemia',
    ])) {
      return 'adult_acute_lymphoblastic_leukemia_eln_2024';
    }

    if (containsAny(const <String>[
      'linfoma de hodgkin',
      'linfoma hodgkin',
      'linfoma de hodgkin clasico',
      'linfoma de hodgkin clássico',
      'linfoma de hodgkin clasico',
      'linfoma de hodgkin clásico',
      'hodgkin lymphoma',
      'classical hodgkin lymphoma',
      'classic hodgkin lymphoma',
      'hodgkin disease',
    ])) {
      return 'classical_hodgkin_lymphoma_bsh_nci';
    }

    if (containsAny(const <String>[
      'linfoma difuso de grandes celulas b',
      'linfoma difuso de grandes células b',
      'linfoma difuso de celulas b grandes',
      'linfoma difuso de células b grandes',
      'linfoma difuso de celulas b grandes',
      'linfoma difuso de células b grandes',
      'diffuse large b cell lymphoma',
      'diffuse large b-cell lymphoma',
      'dlbcl',
      'large b cell lymphoma',
      'large b-cell lymphoma',
    ])) {
      return 'diffuse_large_b_cell_lymphoma_bsh_2025';
    }

    if (containsAny(const <String>[
      'cancer de mama',
      'câncer de mama',
      'carcinoma de mama',
      'cancer de mama',
      'cáncer de mama',
      'carcinoma mamario',
      'breast cancer',
      'breast carcinoma',
      'invasive breast cancer',
      'metastatic breast cancer',
    ])) {
      return 'breast_cancer_esmo_nci_current';
    }

    if (containsAny(const <String>[
      'cancer de prostata',
      'câncer de próstata',
      'carcinoma de prostata',
      'carcinoma de próstata',
      'cancer de prostata',
      'cáncer de próstata',
      'prostate cancer',
      'prostatic carcinoma',
      'metastatic prostate cancer',
      'castration resistant prostate cancer',
      'castration-resistant prostate cancer',
    ])) {
      return 'prostate_cancer_eau_2026';
    }

    if (containsAny(const <String>[
      'cancer de pulmao de nao pequenas celulas',
      'câncer de pulmão de não pequenas células',
      'carcinoma pulmonar de nao pequenas celulas',
      'carcinoma pulmonar de não pequenas células',
      'cancer de pulmon de celulas no pequenas',
      'cáncer de pulmón de células no pequeñas',
      'non small cell lung cancer',
      'non-small-cell lung cancer',
      'non-small cell lung cancer',
      'nsclc',
    ])) {
      return 'non_small_cell_lung_cancer_esmo_nci_current';
    }

    if (containsAny(const <String>[
      'cancer colorretal',
      'câncer colorretal',
      'carcinoma colorretal',
      'cancer colorectal',
      'cáncer colorrectal',
      'carcinoma colorrectal',
      'colorectal cancer',
      'colorectal carcinoma',
      'metastatic colorectal cancer',
      'colon and rectal cancer',
      'colon cancer',
      'rectal cancer',
    ])) {
      return 'colorectal_cancer_asco_nci_current';
    }

    if (containsAny(const <String>[
      'cancer do colo do utero',
      'câncer do colo do útero',
      'cancer cervical',
      'câncer cervical',
      'carcinoma do colo uterino',
      'cancer de cuello uterino',
      'cáncer de cuello uterino',
      'cancer cervical',
      'cáncer cervical',
      'cervical cancer',
      'cervical carcinoma',
      'uterine cervical cancer',
    ])) {
      return 'cervical_cancer_esgo_2023_current';
    }

    if (containsAny(const <String>[
      'cancer de ovario',
      'câncer de ovário',
      'carcinoma epitelial de ovario',
      'carcinoma epitelial de ovário',
      'cancer de ovario',
      'cáncer de ovario',
      'carcinoma epitelial de ovario',
      'ovarian cancer',
      'epithelial ovarian cancer',
      'ovarian carcinoma',
      'high grade serous ovarian cancer',
      'high-grade serous ovarian cancer',
    ])) {
      return 'ovarian_cancer_esgo_esmo_2024';
    }

    if (containsAny(const <String>[
      'cancer de pancreas',
      'câncer de pâncreas',
      'adenocarcinoma ductal pancreatico',
      'adenocarcinoma ductal pancreático',
      'cancer de pancreas',
      'cáncer de páncreas',
      'adenocarcinoma ductal pancreatico',
      'adenocarcinoma ductal pancreático',
      'pancreatic cancer',
      'pancreatic ductal adenocarcinoma',
      'pancreatic adenocarcinoma',
      'metastatic pancreatic cancer',
      'pdac pancreatic',
    ])) {
      return 'pancreatic_cancer_esmo_2025';
    }

    // Top200 Expansion / Batch 23 — hematology.
    // Specific cytopenias/coagulopathy/MPN/CLL entities precede generic anemia,
    // thrombocytopenia, leukemia/lymphoma and myeloproliferative owners.

    if (containsAny(const <String>[
      'anemia da doenca cronica',
      'anemia da doença crônica',
      'anemia de doenca cronica',
      'anemia de doença crônica',
      'anemia da inflamacao',
      'anemia da inflamação',
      'anemia de enfermedad cronica',
      'anemia de enfermedad crónica',
      'anemia de inflamacion',
      'anemia de inflamación',
      'anemia of chronic disease',
      'anemia of inflammation',
      'anaemia of chronic disease',
      'anaemia of inflammation',
      'inflammatory anemia',
      'inflammatory anaemia',
    ])) {
      return 'anemia_of_inflammation_ash_current';
    }

    if (containsAny(const <String>[
      'deficiencia de folato',
      'deficiência de folato',
      'deficiencia de acido folico',
      'deficiência de ácido fólico',
      'anemia por deficiencia de folato',
      'anemia por deficiência de folato',
      'deficiencia de folato',
      'deficiencia de ácido fólico',
      'deficiencia de acido folico',
      'folate deficiency',
      'folic acid deficiency',
      'folate deficiency anemia',
      'folate deficiency anaemia',
    ])) {
      return 'folate_deficiency_nih_who_bsh';
    }

    if (containsAny(const <String>[
      'anemia aplastica',
      'anemia aplástica',
      'aplasia medular',
      'anemia aplasica',
      'anemia aplásica',
      'aplasia medular adquirida',
      'aplastic anemia',
      'aplastic anaemia',
      'acquired aplastic anemia',
      'acquired aplastic anaemia',
      'severe aplastic anemia',
      'severe aplastic anaemia',
    ])) {
      return 'acquired_aplastic_anemia_ash_2026';
    }

    if (containsAny(const <String>[
      'deficiencia de g6pd',
      'deficiência de g6pd',
      'deficiencia de glucosa 6 fosfato deshidrogenasa',
      'deficiencia de glucosa-6-fosfato deshidrogenasa',
      'glucose 6 phosphate dehydrogenase deficiency',
      'glucose-6-phosphate dehydrogenase deficiency',
      'g6pd deficiency',
      'favismo por g6pd',
      'favism g6pd',
    ])) {
      return 'g6pd_deficiency_who_2025';
    }

    if (containsAny(const <String>[
      'hemofilia a',
      'hemophilia a',
      'haemophilia a',
      'deficiencia de fator viii hemofilia',
      'deficiência de fator viii hemofilia',
      'factor viii deficiency hemophilia',
      'factor viii deficiency haemophilia',
      'hemofilia b',
      'hemophilia b',
      'haemophilia b',
      'deficiencia de fator ix hemofilia',
      'deficiência de fator ix hemofilia',
      'factor ix deficiency hemophilia',
      'factor ix deficiency haemophilia',
    ])) {
      return 'hemophilia_ab_wfh_living_2026';
    }

    if (containsAny(const <String>[
      'coagulacao intravascular disseminada',
      'coagulação intravascular disseminada',
      'coagulacao intravascular disseminada aguda',
      'coagulación intravascular diseminada',
      'coagulacion intravascular diseminada',
      'disseminated intravascular coagulation',
      'disseminated intravascular coagulopathy',
      'consumptive coagulopathy dic',
      'coagulopatia de consumo cid',
      'coagulopatia de consumo civd',
    ])) {
      return 'disseminated_intravascular_coagulation_isth_2025';
    }

    // Myelofibrosis must precede PV/ET because post-PV/post-ET MF contains
    // the names of its antecedent neoplasms.
    if (containsAny(const <String>[
      'mielofibrose primaria',
      'mielofibrose primária',
      'mielofibrosis primaria',
      'primary myelofibrosis',
      'mielofibrose pos policitemia vera',
      'mielofibrose pós-policitemia vera',
      'mielofibrosis post policitemia vera',
      'post polycythemia vera myelofibrosis',
      'post-polycythemia vera myelofibrosis',
      'mielofibrose pos trombocitemia essencial',
      'mielofibrose pós-trombocitemia essencial',
      'mielofibrosis post trombocitemia esencial',
      'post essential thrombocythemia myelofibrosis',
      'post-essential thrombocythemia myelofibrosis',
    ])) {
      return 'myelofibrosis_bsh_2023_current';
    }

    if (containsAny(const <String>[
      'policitemia vera',
      'policitemia vera jak2',
      'polycythemia vera',
      'polycythaemia vera',
      'jak2 positive polycythemia vera',
      'jak2 positive polycythaemia vera',
    ])) {
      return 'polycythemia_vera_bsh_eln_current';
    }

    if (containsAny(const <String>[
      'trombocitemia essencial',
      'trombocitemia esencial',
      'essential thrombocythemia',
      'essential thrombocythaemia',
      'jak2 essential thrombocythemia',
      'calr essential thrombocythemia',
      'mpl essential thrombocythemia',
    ])) {
      return 'essential_thrombocythemia_2024_current';
    }

    if (containsAny(const <String>[
      'leucemia linfocitica cronica',
      'leucemia linfocítica crônica',
      'leucemia linfocitica cronica de celulas b',
      'leucemia linfocítica crônica de células b',
      'leucemia linfocitica cronica',
      'leucemia linfocítica crónica',
      'chronic lymphocytic leukemia',
      'chronic lymphocytic leukaemia',
      'b cell chronic lymphocytic leukemia',
      'b-cell chronic lymphocytic leukemia',
      'cll leukemia',
      'cll leukaemia',
    ])) {
      return 'chronic_lymphocytic_leukemia_bsh_2025';
    }

    // Top200 Expansion / Batch 22 — psychiatry and dependence.
    // Specific anxiety/OCD/PTSD/eating/addiction/insomnia/personality entities
    // precede generic anxiety, bipolar, SUD, opioid, cannabis and sleep owners.

    if (containsAny(const <String>[
      'transtorno do panico',
      'transtorno do pânico',
      'transtorno de panico',
      'transtorno de pânico',
      'trastorno de panico',
      'trastorno de pánico',
      'panic disorder',
      'panic disorder with agoraphobia',
      'panic disorder without agoraphobia',
    ])) {
      return 'panic_disorder_nice_2026';
    }

    if (containsAny(const <String>[
      'transtorno de ansiedade social',
      'ansiedade social',
      'fobia social',
      'trastorno de ansiedad social',
      'ansiedad social',
      'fobia social',
      'social anxiety disorder',
      'social phobia',
    ])) {
      return 'social_anxiety_disorder_nice_2026';
    }

    if (containsAny(const <String>[
      'transtorno obsessivo compulsivo',
      'transtorno obsessivo-compulsivo',
      'trastorno obsesivo compulsivo',
      'trastorno obsesivo-compulsivo',
      'obsessive compulsive disorder',
      'obsessive-compulsive disorder',
      'ocd psychiatric',
      'toc psiquiatrico',
      'toc psiquiátrico',
    ])) {
      return 'obsessive_compulsive_disorder_nice_2026';
    }

    if (containsAny(const <String>[
      'transtorno de estresse pos traumatico',
      'transtorno de estresse pós-traumático',
      'transtorno de estresse pós traumatico',
      'trastorno de estres postraumatico',
      'trastorno de estrés postraumático',
      'post traumatic stress disorder',
      'post-traumatic stress disorder',
      'ptsd',
      'tept',
    ])) {
      return 'posttraumatic_stress_disorder_va_dod_2023';
    }

    if (containsAny(const <String>[
      'anorexia nervosa',
      'anorexia nervosa restritiva',
      'anorexia nerviosa',
      'restricting type anorexia nervosa',
      'restrictive anorexia nervosa',
    ])) {
      return 'anorexia_nervosa_apa_nice_current';
    }

    if (containsAny(const <String>[
      'bulimia nervosa',
      'bulimia nerviosa',
      'bulimia nervosa purging',
      'bulimia nerviosa purgativa',
      'bulimia with purging',
    ])) {
      return 'bulimia_nervosa_apa_nice_current';
    }

    if (containsAny(const <String>[
      'transtorno por uso de opioides',
      'transtorno por uso de opioide',
      'trastorno por consumo de opioides',
      'opioid use disorder',
      'opioid dependence',
      'dependencia de opioides',
      'dependência de opioides',
      'oud addiction',
    ])) {
      return 'opioid_use_disorder_asam_samhsa_current';
    }

    if (containsAny(const <String>[
      'transtorno por uso de cannabis',
      'transtorno por uso de maconha',
      'trastorno por consumo de cannabis',
      'trastorno por consumo de marihuana',
      'cannabis use disorder',
      'marijuana use disorder',
      'cannabis dependence',
      'marijuana dependence',
      'dependencia de cannabis',
      'dependência de cannabis',
      'cud cannabis',
    ])) {
      return 'cannabis_use_disorder_who_samhsa_current';
    }

    if (containsAny(const <String>[
      'insonia cronica',
      'insônia crônica',
      'insomnio cronico',
      'insomnio crónico',
      'chronic insomnia',
      'chronic insomnia disorder',
      'persistent insomnia disorder',
    ])) {
      return 'chronic_insomnia_aasm_current';
    }

    if (containsAny(const <String>[
      'transtorno de personalidade borderline',
      'personalidade borderline',
      'transtorno de personalidade limitrofe',
      'transtorno de personalidade limítrofe',
      'trastorno limite de la personalidad',
      'trastorno de personalidad borderline',
      'borderline personality disorder',
      'emotionally unstable personality disorder borderline',
      'bpd personality',
    ])) {
      return 'borderline_personality_disorder_nice_current';
    }

    // Top200 Expansion / Batch 21 — neuromuscular and degenerative neurology.
    // Specific ALS, entrapment/nutritional/diabetic neuropathy, movement disorders,
    // NPH, RLS and DCM precede generic Parkinson/tremor/neuropathy/spine owners.

    if (containsAny(const <String>[
      'esclerose lateral amiotrofica',
      'esclerose lateral amiotrófica',
      'esclerosis lateral amiotrofica',
      'esclerosis lateral amiotrófica',
      'amyotrophic lateral sclerosis',
      'motor neuron disease als',
      'motor neurone disease als',
      'doenca do neuronio motor ela',
      'doença do neurônio motor ela',
      'enfermedad de motoneurona ela',
      'ela neurologica',
      'ela neurológica',
      'als neurologic',
      'als neurological',
    ])) {
      return 'amyotrophic_lateral_sclerosis_ean_2024';
    }

    if (containsAny(const <String>[
      'neuropatia diabetica',
      'neuropatia diabética',
      'neuropatia diabetica periferica',
      'neuropatia diabética periférica',
      'neuropatia diabetica dolorosa',
      'neuropatia diabética dolorosa',
      'neuropatia diabetica',
      'neuropatia diabética',
      'diabetic neuropathy',
      'diabetic peripheral neuropathy',
      'painful diabetic neuropathy',
      'painful diabetic polyneuropathy',
      'distal symmetric diabetic polyneuropathy',
      'dpn diabetes',
    ])) {
      return 'diabetic_peripheral_neuropathy_ada_aan_2026';
    }

    if (containsAny(const <String>[
      'sindrome do tunel do carpo',
      'síndrome do túnel do carpo',
      'sindrome del tunel carpiano',
      'síndrome del túnel carpiano',
      'carpal tunnel syndrome',
      'median nerve entrapment wrist',
      'compressao do nervo mediano no carpo',
      'compressão do nervo mediano no carpo',
      'compresion del nervio mediano en el carpo',
      'compresión del nervio mediano en el carpo',
      'cts carpal',
    ])) {
      return 'carpal_tunnel_syndrome_aaos_2024';
    }

    if (containsAny(const <String>[
      'hidrocefalia de pressao normal',
      'hidrocefalia de pressão normal',
      'hidrocefalia de presion normal',
      'hidrocefalia de presión normal',
      'normal pressure hydrocephalus',
      'idiopathic normal pressure hydrocephalus',
      'inph',
      'hpn idiopatica',
      'hpn idiopática',
      'hpn idiopatica',
      'hpn idiopática',
      'desh hydrocephalus',
    ])) {
      return 'idiopathic_normal_pressure_hydrocephalus_2021';
    }

    if (containsAny(const <String>[
      'tremor essencial',
      'temblor esencial',
      'essential tremor',
      'essential tremor plus',
      'familial essential tremor',
      'tremor familiar essencial',
      'temblor esencial familiar',
    ])) {
      return 'essential_tremor_mds_2026';
    }

    if (containsAny(const <String>[
      'doenca de huntington',
      'doença de huntington',
      'enfermedad de huntington',
      'huntington disease',
      "huntington's disease",
      'coreia de huntington',
      'coréia de huntington',
      'corea de huntington',
      'huntington chorea',
    ])) {
      return 'huntington_disease_dgn_ehdn_2023';
    }

    if (containsAny(const <String>[
      'distonia primaria',
      'distonia primária',
      'distonia focal',
      'distonia generalizada',
      'distonia cervical',
      'distonia primaria',
      'distonía primaria',
      'distonía focal',
      'distonía generalizada',
      'distonía cervical',
      'primary dystonia',
      'focal dystonia',
      'generalized dystonia',
      'generalised dystonia',
      'cervical dystonia',
      'idiopathic dystonia',
    ])) {
      return 'dystonia_mds_ean_current';
    }

    if (containsAny(const <String>[
      'sindrome das pernas inquietas',
      'síndrome das pernas inquietas',
      'sindrome de piernas inquietas',
      'síndrome de piernas inquietas',
      'restless legs syndrome',
      'willis ekbom disease',
      'willis-ekbom disease',
      'rls sleep',
      'spi pernas inquietas',
    ])) {
      return 'restless_legs_syndrome_aasm_2025';
    }

    if (containsAny(const <String>[
      'neuropatia nutricional',
      'neuropatia periferica nutricional',
      'neuropatia periférica nutricional',
      'neuropatia por deficiencia de vitamina b12',
      'neuropatia por deficiência de vitamina b12',
      'neuropatia por deficiencia de tiamina',
      'neuropatia por deficiência de tiamina',
      'neuropatia por deficiencia de cobre',
      'neuropatia por deficiência de cobre',
      'neuropatia nutricional',
      'neuropatia periferica nutricional',
      'neuropatia periférica nutricional',
      'neuropatia por deficit de vitamina b12',
      'neuropatia por déficit de vitamina b12',
      'nutritional neuropathy',
      'nutritional peripheral neuropathy',
      'vitamin b12 deficiency neuropathy',
      'thiamine deficiency neuropathy',
      'copper deficiency neuropathy',
    ])) {
      return 'nutritional_peripheral_neuropathy_nice_2026';
    }

    if (containsAny(const <String>[
      'mielopatia cervical degenerativa',
      'mielopatia cervical espondilotica',
      'mielopatia cervical espondilótica',
      'mielopatia cervical degenerativa',
      'mielopatia cervical espondilotica',
      'mielopatía cervical espondilótica',
      'degenerative cervical myelopathy',
      'cervical spondylotic myelopathy',
      'degenerative cervical cord compression myelopathy',
      'dcm cervical myelopathy',
      'csm cervical myelopathy',
    ])) {
      return 'degenerative_cervical_myelopathy_aospine_2025';
    }

    // Top200 Expansion / Batch 20 — neurovascular, headache and vestibular.
    // Specific TIA/hemorrhage/CVT/headache/vestibular/facial entities precede
    // generic stroke, headache, vertigo/dizziness and facial-palsy owners.

    if (containsAny(const <String>[
      'ataque isquemico transitorio',
      'ataque isquêmico transitório',
      'ataque isquemico transitório',
      'ataque isquêmico transitorio',
      'ataque isquemico transitorio cerebral',
      'ataque isquêmico transitório cerebral',
      'ataque isquemico transitorio',
      'ataque isquémico transitorio',
      'accidente isquemico transitorio',
      'accidente isquémico transitorio',
      'transient ischemic attack',
      'transient ischaemic attack',
      'tia neurologic',
      'ait neurologico',
      'ait neurológico',
    ])) {
      return 'transient_ischemic_attack_aha_2023';
    }

    if (containsAny(const <String>[
      'hemorragia intracerebral espontanea',
      'hemorragia intracerebral espontânea',
      'hemorragia intracerebral espontanea',
      'hemorragia intracerebral espontánea',
      'hemorragia intracerebral',
      'intracerebral hemorrhage',
      'intracerebral haemorrhage',
      'spontaneous ich',
      'spontaneous intracerebral hemorrhage',
      'spontaneous intracerebral haemorrhage',
    ])) {
      return 'spontaneous_intracerebral_hemorrhage_aha_2022';
    }

    if (containsAny(const <String>[
      'hemorragia subaracnoidea aneurismatica',
      'hemorragia subaracnóidea aneurismática',
      'hemorragia subaracnoidea aneurismatica',
      'hemorragia subaracnoidea aneurismática',
      'hemorragia subaracnoidea',
      'hemorragia subaracnóidea',
      'subarachnoid hemorrhage',
      'subarachnoid haemorrhage',
      'aneurysmal subarachnoid hemorrhage',
      'aneurysmal subarachnoid haemorrhage',
      'asah',
    ])) {
      return 'aneurysmal_subarachnoid_hemorrhage_aha_2023';
    }

    if (containsAny(const <String>[
      'trombose venosa cerebral',
      'trombosis venosa cerebral',
      'cerebral venous thrombosis',
      'cerebral venous sinus thrombosis',
      'cerebral sinus venous thrombosis',
      'trombose de seio venoso cerebral',
      'trombosis de seno venoso cerebral',
      'cvt cerebral',
      'cvst',
    ])) {
      return 'cerebral_venous_thrombosis_aha_2024';
    }

    if (containsAny(const <String>[
      'neuralgia do trigemeo',
      'neuralgia do trigêmeo',
      'neuralgia del trigemino',
      'neuralgia del trigémino',
      'trigeminal neuralgia',
      'tic douloureux',
    ])) {
      return 'trigeminal_neuralgia_ean_2019';
    }

    if (containsAny(const <String>[
      'cefaleia em salvas',
      'cefalea en racimos',
      'cluster headache',
      'cluster headaches',
      'trigeminal autonomic cephalalgia cluster',
      'tac cluster headache',
    ])) {
      return 'cluster_headache_ean_2023';
    }

    if (containsAny(const <String>[
      'cefaleia tensional',
      'cefaleia tipo tensao',
      'cefaleia tipo tensão',
      'cefalea tensional',
      'cefalea tipo tension',
      'cefalea tipo tensión',
      'tension type headache',
      'tension-type headache',
      'tension headache',
    ])) {
      return 'tension_type_headache_nice_2025';
    }

    if (containsAny(const <String>[
      'vertigem posicional paroxistica benigna',
      'vertigem posicional paroxística benigna',
      'vertigo posicional paroxistico benigno',
      'vértigo posicional paroxístico benigno',
      'benign paroxysmal positional vertigo',
      'bppv',
      'vppb',
    ])) {
      return 'bppv_aao_hns_2026';
    }

    if (containsAny(const <String>[
      'neurite vestibular',
      'neuritis vestibular',
      'vestibular neuritis',
      'vestibular neuronitis',
      'acute unilateral vestibulopathy',
      'vestibulopatia unilateral aguda',
      'vestibulopatia unilateral aguda',
    ])) {
      return 'vestibular_neuritis_barany_2022';
    }

    if (containsAny(const <String>[
      'paralisia de bell',
      'paralisia facial de bell',
      'paralisis de bell',
      'parálisis de bell',
      'bell palsy',
      "bell's palsy",
      'idiopathic facial palsy',
      'paralisia facial idiopatica',
      'paralisia facial idiopática',
      'paralisis facial idiopatica',
      'parálisis facial idiopática',
    ])) {
      return 'bell_palsy_aao_hns_2026';
    }

    // Top200 Expansion / Batch 19 — tropical and emerging infectious disease.
    // Specific arboviral, zoonotic and tropical entities precede generic dengue,
    // hepatitis, sepsis, malaria and leishmaniasis owners.

    if (containsAny(const <String>[
      'leptospirose',
      'leptospirosis',
      'leptospira infection',
      'doenca de weil',
      'doença de weil',
      'enfermedad de weil',
      'weil disease',
    ])) {
      return 'leptospirosis_cdc_2026';
    }

    if (containsAny(const <String>[
      'doenca de chagas',
      'doença de chagas',
      'enfermedad de chagas',
      'chagas disease',
      'tripanossomiase americana',
      'tripanossomíase americana',
      'tripanosomiasis americana',
      'american trypanosomiasis',
      'trypanosoma cruzi',
    ])) {
      return 'chagas_who_paho_2026';
    }

    if (containsAny(const <String>[
      'leishmaniose visceral',
      'leishmaniasis visceral',
      'visceral leishmaniasis',
      'kala azar',
      'kala-azar',
      'leishmaniose visceral americana',
      'leishmaniasis visceral americana',
    ])) {
      return 'visceral_leishmaniasis_who_2026';
    }

    if (containsAny(const <String>[
      'febre amarela',
      'fiebre amarilla',
      'yellow fever',
      'yellow fever virus',
      'virus da febre amarela',
      'vírus da febre amarela',
      'virus de la fiebre amarilla',
    ])) {
      return 'yellow_fever_who_cdc_2026';
    }

    if (containsAny(const <String>[
      'chikungunya',
      'chikunguña',
      'chikungunha',
      'chikungunya virus disease',
      'febre chikungunya',
      'fiebre chikungunya',
    ])) {
      return 'chikungunya_who_cdc_2026';
    }

    if (containsAny(const <String>[
      'zika',
      'zika virus',
      'virus zika',
      'vírus zika',
      'zika virus disease',
      'doenca pelo virus zika',
      'doença pelo vírus zika',
      'enfermedad por virus zika',
    ])) {
      return 'zika_who_cdc_2025';
    }

    if (containsAny(const <String>[
      'febre tifoide',
      'febre tifóide',
      'fiebre tifoidea',
      'typhoid fever',
      'salmonella typhi',
      'salmonella enterica typhi',
      'enteric fever typhoid',
    ])) {
      return 'typhoid_fever_cdc_2026';
    }

    if (containsAny(const <String>[
      'brucelose',
      'brucelosis',
      'brucellosis',
      'brucella infection',
      'febre de malta',
      'fiebre de malta',
      'malta fever',
    ])) {
      return 'brucellosis_cdc_2026';
    }

    if (containsAny(const <String>[
      'febre maculosa',
      'fiebre manchada',
      'spotted fever',
      'rocky mountain spotted fever',
      'rmsf',
      'rickettsiose',
      'rickettsiosis',
      'rickettsial disease',
      'rickettsia rickettsii',
    ])) {
      return 'spotted_fever_rickettsiosis_cdc_2025';
    }

    if (containsAny(const <String>[
      'mpox',
      'monkeypox',
      'monkeypox virus',
      'virus mpox',
      'vírus mpox',
      'variola dos macacos',
      'varíola dos macacos',
      'viruela simica',
      'viruela símica',
      'viruela del mono',
    ])) {
      return 'mpox_who_cdc_2026';
    }

    // Top200 Expansion / Batch 18 — infectious viral and bacterial disease.
    // Specific viral, skin/soft-tissue and osteoarticular entities precede generic
    // HIV/OI, hepatitis, cellulitis/SSTI and sepsis owners.

    if (containsAny(const <String>[
      'herpes zoster',
      'herpes-zoster',
      'zoster',
      'zona',
      'shingles',
      'cobreiro',
    ])) {
      return 'herpes_zoster_cdc_nih_2026';
    }

    if (containsAny(const <String>[
      'varicela',
      'varicella',
      'chickenpox',
      'catapora',
      'varicela primaria',
      'varicela primária',
      'primary varicella',
    ])) {
      return 'varicella_cdc_nih_2026';
    }

    if (containsAny(const <String>[
      'mononucleose infecciosa',
      'mononucleosis infecciosa',
      'infectious mononucleosis',
      'mononucleosis',
      'epstein barr mononucleosis',
      'epstein-barr mononucleosis',
      'ebv mononucleosis',
    ])) {
      return 'infectious_mononucleosis_ebv_cdc';
    }

    if (containsAny(const <String>[
      'citomegalovirus',
      'cytomegalovirus',
      'cmv disease',
      'doenca por cmv',
      'doença por cmv',
      'enfermedad por cmv',
      'retinite por cmv',
      'retinitis por cmv',
      'cmv retinitis',
    ])) {
      return 'cytomegalovirus_disease_nih_2026';
    }

    if (containsAny(const <String>[
      'toxoplasmose',
      'toxoplasmosis',
      'toxoplasma gondii',
      'toxoplasmose cerebral',
      'toxoplasmosis cerebral',
      'toxoplasma encephalitis',
      'encefalite por toxoplasma',
      'encefalitis por toxoplasma',
    ])) {
      return 'toxoplasmosis_cdc_nih_2026';
    }

    if (containsAny(const <String>[
      'hepatite a',
      'hepatitis a',
      'hepatitis viral a',
      'hepatite viral a',
      'hav infection',
      'hepatitis a virus',
      'virus da hepatite a',
      'vírus da hepatite a',
      'virus de hepatitis a',
    ])) {
      return 'hepatitis_a_cdc_2025';
    }

    if (containsAny(const <String>[
      'erisipela',
      'erysipelas',
      'erisipelas',
      'erisipela facial',
      'facial erysipelas',
    ])) {
      return 'erysipelas_idsa_nice';
    }

    if (containsAny(const <String>[
      'celulite bacteriana',
      'celulitis bacteriana',
      'bacterial cellulitis',
      'celulite nao purulenta',
      'celulite não purulenta',
      'celulitis no purulenta',
      'nonpurulent cellulitis',
      'non-purulent cellulitis',
    ])) {
      return 'cellulitis_ssti_idsa_nice';
    }

    if (containsAny(const <String>[
      'osteomielite',
      'osteomielitis',
      'osteomyelitis',
      'osteomielite hematogenica',
      'osteomielite hematogênica',
      'hematogenous osteomyelitis',
      'vertebral osteomyelitis',
      'osteomielite vertebral',
      'osteomielitis vertebral',
    ])) {
      return 'osteomyelitis_idsa_pids';
    }

    if (containsAny(const <String>[
      'artrite septica',
      'artrite séptica',
      'artritis septica',
      'artritis séptica',
      'septic arthritis',
      'acute bacterial arthritis',
      'artrite bacteriana aguda',
      'artritis bacteriana aguda',
      'native joint septic arthritis',
    ])) {
      return 'septic_arthritis_sanjo_pids_idsa';
    }

    if (containsAny(const <String>['asma']) ||
        (allowSourceAliases && hasWord('gina'))) {
      return 'asthma';
    }

    if (containsAny(const <String>['epoc', 'dpoc', 'copd']) ||
        (allowSourceAliases && hasWord('gold'))) {
      return 'copd';
    }

    if (containsAny(const <String>[
      'hipertensao portal',
      'hipertensão portal',
      'hipertension portal',
      'portal hypertension',
      'cirrose hepatica',
      'cirrose hepática',
      'cirrosis hepatica',
      'liver cirrhosis',
      'cirrhosis',
    ])) {
      return 'cirrhosis_portal_hypertension';
    }

    if (containsAny(const <String>[
      'hiperaldosteronismo primario',
      'hiperaldosteronismo primário',
      'aldosteronismo primario',
      'aldosteronismo primário',
      'primary aldosteronism',
      'sindrome de conn',
      'conn syndrome',
    ])) {
      return 'primary_aldosteronism';
    }

    if (containsAny(const <String>[
      'feocromocitoma',
      'pheochromocytoma',
      'paraganglioma',
    ])) {
      return 'pheochromocytoma_paraganglioma';
    }

    if (containsAny(const <String>[
      'sindrome de cushing',
      'síndrome de cushing',
      'cushing syndrome',
      'hipercortisolismo',
      'hypercortisolism',
    ])) {
      return 'cushing_syndrome';
    }

    if (containsAny(const <String>[
      'hipertensao pulmonar',
      'hipertensão pulmonar',
      'hipertension pulmonar',
      'pulmonary hypertension',
      'pulmonary arterial hypertension',
      'hipertensao arterial pulmonar',
      'hipertensão arterial pulmonar',
    ])) {
      return 'pulmonary_hypertension_esc_ers_2022';
    }

    if (containsAny(const <String>[
      'pre eclampsia',
      'pré eclâmpsia',
      'pre-eclampsia',
      'pre-eclâmpsia',
      'preeclampsia',
      'preeclampsia grave',
      'eclampsia',
      'eclâmpsia',
      'hipertensao na gestacao',
      'hipertensão na gestação',
      'hipertension en el embarazo',
      'hypertension in pregnancy',
    ])) {
      return 'preeclampsia_eclampsia_nice_2023';
    }

    // Top200 Expansion / Batch 12 — aorta, syncope and thrombosis.
    // Specific entities intentionally precede the generic cardiology bundle.

    if (containsAny(const <String>[
      'aneurisma de aorta abdominal',
      'aneurisma da aorta abdominal',
      'aneurisma aortico abdominal',
      'aneurisma aórtico abdominal',
      'aneurisma de aorta abdominal',
      'aneurisma aortico abdominal',
      'abdominal aortic aneurysm',
    ])) {
      return 'abdominal_aortic_aneurysm_esc_2024';
    }

    if (containsAny(const <String>[
      'aneurisma de aorta toracica',
      'aneurisma de aorta torácica',
      'aneurisma da aorta toracica',
      'aneurisma da aorta torácica',
      'aneurisma aortico toracico',
      'aneurisma aórtico torácico',
      'aneurisma de aorta toracica',
      'aneurisma de aorta torácica',
      'thoracic aortic aneurysm',
    ])) {
      return 'thoracic_aortic_aneurysm_esc_2024';
    }

    if (containsAny(const <String>[
      'postural orthostatic tachycardia syndrome',
      'postural tachycardia syndrome',
      'sindrome de taquicardia postural ortostatica',
      'síndrome de taquicardia postural ortostática',
      'sindrome de taquicardia postural ortostatica',
      'síndrome de taquicardia postural ortostática',
      'pots syndrome',
      'pots',
    ])) {
      return 'postural_orthostatic_tachycardia_syndrome';
    }

    if (containsAny(const <String>[
      'hipotensao ortostatica',
      'hipotensão ortostática',
      'hipotension ortostatica',
      'hipotensión ortostática',
      'orthostatic hypotension',
      'postural hypotension',
    ])) {
      return 'orthostatic_hypotension_aha_2024';
    }

    if (containsAny(const <String>[
      'sincope vasovagal',
      'síncope vasovagal',
      'sincope reflexa',
      'síncope reflexa',
      'sincope refleja',
      'síncope refleja',
      'vasovagal syncope',
      'reflex syncope',
      'neurocardiogenic syncope',
    ])) {
      return 'vasovagal_reflex_syncope';
    }

    if (containsAny(const <String>[
      'tromboflebite superficial',
      'tromboflebitis superficial',
      'trombose venosa superficial',
      'trombosis venosa superficial',
      'superficial vein thrombosis',
      'superficial venous thrombosis',
      'superficial thrombophlebitis',
    ])) {
      return 'superficial_venous_thrombosis_esvs_2021';
    }

    if (containsAny(const <String>[
      'trombose venosa profunda',
      'trombosis venosa profunda',
      'deep vein thrombosis',
      'deep venous thrombosis',
      'tvp membro inferior',
      'tvp de membro inferior',
      'dvt lower extremity',
    ])) {
      return 'deep_vein_thrombosis_ash';
    }

    if (containsAny(const <String>[
      'insuficiencia venosa cronica',
      'insuficiência venosa crônica',
      'insuficiencia venosa cronica',
      'insuficiencia venosa crónica',
      'chronic venous insufficiency',
      'chronic venous disease',
      'doenca venosa cronica',
      'doença venosa crônica',
      'enfermedad venosa cronica',
      'enfermedad venosa crónica',
    ])) {
      return 'chronic_venous_disease_esvs_2022';
    }

    if (containsAny(const <String>[
      'febre reumatica',
      'febre reumática',
      'fiebre reumatica',
      'fiebre reumática',
      'acute rheumatic fever',
      'rheumatic fever',
      'cardiopatia reumatica',
      'cardiopatia reumática',
      'cardiopatia reumatica',
      'cardiopatía reumática',
      'rheumatic heart disease',
    ])) {
      return 'rheumatic_fever_rheumatic_heart_disease_who_2024';
    }

    if (containsAny(const <String>[
      'emergencia hipertensiva',
      'emergência hipertensiva',
      'emergencia hipertensiva',
      'crise hipertensiva',
      'crisis hipertensiva',
      'hypertensive emergency',
      'hypertensive crisis',
      'severe hypertension with target organ damage',
    ])) {
      return 'hypertensive_emergency_aha_2024';
    }

    // Top200 Expansion / Batch 11 — specific cardiology precedence.

    if (containsAny(const <String>[
      'wolff parkinson white',
      'wolff-parkinson-white',
      'sindrome de wolff parkinson white',
      'síndrome de wolff-parkinson-white',
      'sindrome wolff parkinson white',
      'sindrome de wolff-parkinson-white',
      'wpw syndrome',
      'wpw',
    ])) {
      return 'wolff_parkinson_white_wpw';
    }

    if (containsAny(const <String>[
      'sindrome do qt longo',
      'síndrome do qt longo',
      'sindrome de qt largo',
      'síndrome de qt largo',
      'long qt syndrome',
      'long-qt syndrome',
      'lqts',
    ])) {
      return 'long_qt_syndrome';
    }

    if (containsAny(const <String>[
      'sindrome de brugada',
      'síndrome de brugada',
      'brugada syndrome',
      'brugada',
    ])) {
      return 'brugada_syndrome';
    }

    if (containsAny(const <String>[
      'flutter atrial',
      'flutter auricular',
      'atrial flutter',
      'aleteo auricular',
    ])) {
      return 'atrial_flutter';
    }

    if (!containsAny(const <String>[
          'taquicardia ventricular nao sustentada',
          'taquicardia ventricular não sustentada',
          'taquicardia ventricular no sostenida',
          'non sustained ventricular tachycardia',
          'non-sustained ventricular tachycardia',
          'nonsustained ventricular tachycardia',
          'nsVT',
          'nsvt',
        ]) &&
        containsAny(const <String>[
          'taquicardia ventricular sustentada',
          'taquicardia ventricular sostenida',
          'sustained ventricular tachycardia',
          'sustained vt',
          'tv sustentada',
          'vt sustentada',
        ])) {
      return 'sustained_ventricular_tachycardia';
    }

    if (containsAny(const <String>[
      'bloqueio atrioventricular',
      'bloqueio auriculoventricular',
      'bloqueo auriculoventricular',
      'bloqueo atrioventricular',
      'atrioventricular block',
      'atrioventricular heart block',
      'av block',
      'bav cardiaco',
      'bav cardíaco',
    ])) {
      return 'atrioventricular_block';
    }

    if (containsAny(const <String>[
      'cardiomiopatia dilatada',
      'miocardiopatia dilatada',
      'miocardiopatía dilatada',
      'dilated cardiomyopathy',
      'dcm cardiomyopathy',
    ])) {
      return 'dilated_cardiomyopathy_esc_2023';
    }

    if (containsAny(const <String>[
      'takotsubo',
      'cardiomiopatia por estresse',
      'cardiomiopatia de estresse',
      'miocardiopatia por estres',
      'miocardiopatía por estrés',
      'stress cardiomyopathy',
      'broken heart syndrome',
      'sindrome do coracao partido',
      'síndrome do coração partido',
    ])) {
      return 'takotsubo_syndrome_consensus_2024';
    }

    if (!containsAny(const <String>[
          'coronaria instavel',
          'coronária instável',
          'coronaria inestable',
          'unstable coronary',
          'acute coronary',
          'sindrome coronariana aguda',
          'síndrome coronariana aguda',
          'sindrome coronaria aguda',
          'síndrome coronaria aguda',
          'myocardial infarction',
          'infarto agudo',
        ]) &&
        containsAny(const <String>[
          'sindrome coronariana cronica',
          'síndrome coronariana crônica',
          'sindrome coronaria cronica',
          'síndrome coronaria crónica',
          'chronic coronary syndrome',
          'chronic coronary disease',
          'doenca arterial coronariana cronica',
          'doença arterial coronariana crônica',
          'enfermedad arterial coronaria cronica',
          'enfermedad arterial coronaria crónica',
          'doenca coronariana estavel',
          'doença coronariana estável',
          'enfermedad coronaria estable',
          'coronary artery disease',
          'stable cad',
          'dac estavel',
          'dac estável',
        ])) {
      return 'chronic_coronary_syndrome_esc_2024';
    }

    if (containsAny(const <String>[
      'taquicardia supraventricular paroxistica',
      'taquicardia supraventricular paroxística',
      'taquicardia paroxistica supraventricular',
      'taquicardia paroxística supraventricular',
      'paroxysmal supraventricular tachycardia',
      'paroxysmal svt',
      'psvt',
      'tsvp',
      'tpsv',
    ])) {
      return 'paroxysmal_supraventricular_tachycardia';
    }

    if (containsAny(const <String>[
      'hipertens',
      'hypertension',
      'high blood pressure',
    ])) {
      return 'hypertension';
    }

    if (containsAny(const <String>[
      'fibrilacao atrial',
      'fibrilacion auricular',
      'fibrilacion atrial',
      'atrial fibrillation',
    ])) {
      return 'atrial_fibrillation';
    }

    if (containsAny(const <String>[
      'insuficiencia cardiaca',
      'heart failure',
      'falencia cardiaca',
    ])) {
      return 'heart_failure';
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

    if (containsAny(const <String>[
      'diabetes gestacional',
      'diabetes gestacional na gravidez',
      'diabetes gestacional no embarazo',
      'gestational diabetes',
      'gdm',
    ])) {
      return 'gestational_diabetes_ada_2026';
    }

    if (containsAny(const <String>['diabetes', 'diabetico', 'diabetica']) ||
        (allowSourceAliases &&
            containsAny(const <String>['standards of care in diabetes']))) {
      return 'diabetes';
    }

    // Top200 Expansion / Batch 17 — nephrology and urology.
    // Specific glomerular, tubular and urologic entities precede generic AKI,
    // nephrotic syndrome, UTI/cystitis, LUTS/BPH and TMA owners.

    if (containsAny(const <String>[
      'glomerulonefrite pos estreptococica',
      'glomerulonefrite pós-estreptocócica',
      'glomerulonefritis postestreptococica',
      'glomerulonefritis postestreptocócica',
      'post streptococcal glomerulonephritis',
      'post-streptococcal glomerulonephritis',
      'psgn',
      'gn pos estreptococica',
      'gn pós-estreptocócica',
    ])) {
      return 'poststreptococcal_infection_related_gn_kdigo';
    }

    if (containsAny(const <String>[
      'anti gbm',
      'anti-gbm',
      'doenca anti membrana basal glomerular',
      'doença anti membrana basal glomerular',
      'enfermedad anti membrana basal glomerular',
      'anti glomerular basement membrane disease',
      'anti-glomerular basement membrane disease',
      'goodpasture',
      'goodpastures syndrome',
      'sindrome de goodpasture',
      'síndrome de goodpasture',
    ])) {
      return 'anti_gbm_goodpasture_kdigo';
    }

    if (containsAny(const <String>[
      'nefropatia membranosa',
      'nefropatia membranosa primaria',
      'nefropatia membranosa primária',
      'nefropatia membranosa primaria',
      'membranous nephropathy',
      'primary membranous nephropathy',
      'membranous glomerulopathy',
      'pla2r membranous',
    ])) {
      return 'membranous_nephropathy_kdigo';
    }

    if (containsAny(const <String>[
      'glomeruloesclerose segmentar e focal',
      'glomeruloesclerose segmentar focal',
      'glomeruloesclerosis focal y segmentaria',
      'focal segmental glomerulosclerosis',
      'focal segmental glomerular sclerosis',
      'fsgs',
      'gesf',
    ])) {
      return 'fsgs_kdigo';
    }

    if (containsAny(const <String>[
      'sindrome hemolitico uremica',
      'síndrome hemolítico-urêmica',
      'sindrome hemolitico uremico',
      'síndrome hemolítico urémico',
      'hemolytic uremic syndrome',
      'haemolytic uraemic syndrome',
      'atypical hus',
      'atypical hemolytic uremic syndrome',
      'ahus',
      'shu atipica',
      'shu atípica',
      'shu atipico',
      'shu atípico',
    ])) {
      return 'hemolytic_uremic_syndrome_complement_2026';
    }

    if (containsAny(const <String>[
      'nefrite intersticial aguda',
      'nefritis intersticial aguda',
      'acute interstitial nephritis',
      'acute tubulointerstitial nephritis',
      'drug induced interstitial nephritis',
      'drug-induced interstitial nephritis',
      'nia medicamentosa',
      'ain kidney',
    ])) {
      return 'acute_interstitial_nephritis_2024';
    }

    if (containsAny(const <String>[
      'acidose tubular renal',
      'acidosis tubular renal',
      'renal tubular acidosis',
      'rta type 1',
      'rta type 2',
      'rta type 4',
      'atr tipo 1',
      'atr tipo 2',
      'atr tipo 4',
    ])) {
      return 'renal_tubular_acidosis_core_2025';
    }

    if (containsAny(const <String>[
      'cistite intersticial',
      'cistitis intersticial',
      'interstitial cystitis',
      'bladder pain syndrome',
      'painful bladder syndrome',
      'sindrome da dor vesical',
      'síndrome da dor vesical',
      'sindrome de dolor vesical',
      'síndrome de dolor vesical',
      'ic bps',
      'ic/bps',
    ])) {
      return 'interstitial_cystitis_bladder_pain_2026';
    }

    if (containsAny(const <String>[
      'prostatite bacteriana',
      'prostatitis bacteriana',
      'bacterial prostatitis',
      'acute bacterial prostatitis',
      'chronic bacterial prostatitis',
      'prostatite bacteriana aguda',
      'prostatite bacteriana cronica',
      'prostatite bacteriana crônica',
      'prostatitis bacteriana aguda',
      'prostatitis bacteriana cronica',
      'prostatitis bacteriana crónica',
    ])) {
      return 'bacterial_prostatitis_eau_2026';
    }

    if (containsAny(const <String>[
      'hiperplasia prostatica benigna',
      'hiperplasia prostática benigna',
      'hiperplasia prostatica benigna',
      'hiperplasia prostática benigna',
      'benign prostatic hyperplasia',
      'benign prostatic enlargement',
      'benign prostatic obstruction',
      'bph',
      'hpb',
    ])) {
      return 'benign_prostatic_hyperplasia_luts_2026';
    }

    if (containsAny(const <String>[
      'lesao renal aguda',
      'lesão renal aguda',
      'injuria renal aguda',
      'injúria renal aguda',
      'lesion renal aguda',
      'acute kidney injury',
      'acute kidney disease',
      'aki',
      'akd',
    ])) {
      return 'acute_kidney_injury_aki_akd';
    }

    if (containsAny(const <String>[
      'nefropatia por iga',
      'nefropatia iga',
      'nefropatia por iga',
      'vasculite por iga',
      'vasculitis por iga',
      'iga nephropathy',
      'iga vasculitis',
    ])) {
      return 'iga_nephropathy_vasculitis_2025';
    }

    if (containsAny(const <String>[
      'doenca renal policistica autossomica dominante',
      'doença renal policística autossômica dominante',
      'poliquistosis renal autosomica dominante',
      'autosomal dominant polycystic kidney disease',
      'adpkd',
    ])) {
      return 'adpkd_kdigo_2025';
    }

    if (containsAny(const <String>[
      'anemia na doenca renal cronica',
      'anemia na doença renal crônica',
      'anemia en enfermedad renal cronica',
      'anemia in chronic kidney disease',
      'anemia in ckd',
      'anemia ckd',
    ])) {
      return 'anemia_ckd_kdigo_2026';
    }

    if (containsAny(const <String>[
      'sindrome nefrotica infantil',
      'síndrome nefrótica infantil',
      'sindrome nefrotico infantil',
      'sindrome nefrotica pediatrica',
      'síndrome nefrótica pediátrica',
      'nephrotic syndrome in children',
      'pediatric nephrotic syndrome',
      'paediatric nephrotic syndrome',
    ])) {
      return 'pediatric_nephrotic_syndrome_kdigo_2025';
    }

    if (containsAny(const <String>[
      'calculo renal',
      'cálculo renal',
      'calculos renais',
      'cálculos renais',
      'litiasis renal',
      'litiasis ureteral',
      'nefrolitiase',
      'nefrolitíase',
      'kidney stone',
      'kidney stones',
      'ureteral stone',
      'ureteral stones',
      'nephrolithiasis',
    ])) {
      return 'kidney_ureteral_stones_aua_2026';
    }

    if (containsAny(const <String>[
      'hipercalemia',
      'hipercalemia aguda',
      'hiperpotassemia',
      'hiperpotasemia',
      'hyperkalaemia',
      'hyperkalemia',
    ])) {
      return 'hyperkalemia_ukka_2023';
    }

    if (containsAny(const <String>[
      'hiponatremia',
      'hyponatraemia',
      'hyponatremia',
    ])) {
      return 'hyponatremia_european_2014';
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
      'endocardite infecciosa',
      'endocarditis infecciosa',
      'infective endocarditis',
    ])) {
      return 'infective_endocarditis';
    }

    if (containsAny(const <String>[
      'meningite bacteriana',
      'meningitis bacteriana',
      'bacterial meningitis',
    ])) {
      return 'bacterial_meningitis';
    }

    if (containsAny(const <String>[
      'sindrome aortica aguda',
      'sindrome aortico agudo',
      'acute aortic syndrome',
      'disseccao aortica',
      'disseccion aortica',
      'aortic dissection',
    ])) {
      return 'acute_aortic_syndrome';
    }

    if (containsAny(const <String>[
      'miocardite',
      'miocarditis',
      'myocarditis',
    ])) {
      return 'myocarditis';
    }

    if (containsAny(const <String>['pericardite', 'pericarditis'])) {
      return 'pericarditis';
    }

    if (containsAny(const <String>[
      'cardiomiopatia hipertrofica',
      'miocardiopatia hipertrofica',
      'hypertrophic cardiomyopathy',
    ])) {
      return 'hypertrophic_cardiomyopathy';
    }

    if (containsAny(const <String>[
      'doenca valvar',
      'doenca valvular',
      'enfermedad valvular',
      'valvulopatia',
      'valvular heart disease',
    ])) {
      return 'valvular_heart_disease';
    }

    if (containsAny(const <String>[
      'dislipidemia',
      'dyslipidemia',
      'hipercolesterolemia',
      'hypercholesterolemia',
    ])) {
      return 'dyslipidemia';
    }

    if (containsAny(const <String>[
      'doenca arterial periferica',
      'enfermedad arterial periferica',
      'peripheral artery disease',
      'peripheral arterial disease',
      'claudicacao intermitente',
      'claudicacion intermitente',
      'intermittent claudication',
    ])) {
      return 'peripheral_artery_disease';
    }

    if (containsAny(const <String>['helicobacter pylori', 'h pylori'])) {
      return 'h_pylori';
    }

    if (containsAny(const <String>[
      'hemorragia digestiva alta',
      'sangramento digestivo alto',
      'sangramento gastrointestinal alto',
      'upper gastrointestinal bleeding',
      'upper gi bleeding',
      'hematemese',
      'hematemesis',
    ])) {
      return 'upper_gi_bleeding';
    }

    if (containsAny(const <String>[
      'apendicite',
      'apendicitis',
      'appendicitis',
    ])) {
      return 'acute_appendicitis';
    }

    if (containsAny(const <String>[
      'colecistite aguda',
      'colecistitis aguda',
      'acute cholecystitis',
      'cholecystitis',
    ])) {
      return 'acute_cholecystitis';
    }

    if (containsAny(const <String>[
      'colangite aguda',
      'colangitis aguda',
      'acute cholangitis',
      'cholangitis',
    ])) {
      return 'acute_cholangitis';
    }

    if (containsAny(const <String>[
      'diverticulite aguda',
      'diverticulitis aguda',
      'acute diverticulitis',
      'diverticulitis',
    ])) {
      return 'acute_diverticulitis';
    }

    if (containsAny(const <String>[
      'artrite reumatoide',
      'artritis reumatoide',
      'rheumatoid arthritis',
    ])) {
      return 'rheumatoid_arthritis';
    }

    if (containsAny(const <String>[
      'nefrite lupica',
      'nefritis lupica',
      'lupus nephritis',
    ])) {
      return 'lupus_nephritis';
    }

    if (containsAny(const <String>[
      'lupus eritematoso sistemico',
      'systemic lupus erythematosus',
      'sle',
    ])) {
      return 'systemic_lupus_erythematosus';
    }

    if (containsAny(const <String>[
      'gota',
      'gout',
      'artrite gotosa',
      'artritis gotosa',
    ])) {
      return 'gout';
    }

    if (containsAny(const <String>[
      'osteoartrite',
      'osteoartritis',
      'osteoarthritis',
    ])) {
      return 'osteoarthritis';
    }

    if (containsAny(const <String>[
      'artrite psoriasica',
      'artritis psoriasica',
      'psoriatic arthritis',
    ])) {
      return 'psoriatic_arthritis';
    }

    if (containsAny(const <String>[
      'espondiloartrite axial',
      'espondiloartritis axial',
      'axial spondyloarthritis',
      'axspa',
    ])) {
      return 'axial_spondyloarthritis';
    }

    if (containsAny(const <String>[
      'esclerose sistemica',
      'esclerosis sistemica',
      'systemic sclerosis',
      'esclerodermia sistemica',
      'systemic scleroderma',
    ])) {
      return 'systemic_sclerosis';
    }

    if (containsAny(const <String>[
      'vasculite anca',
      'vasculitis anca',
      'anca-associated vasculitis',
      'anca associated vasculitis',
    ])) {
      return 'anca_associated_vasculitis';
    }

    if (containsAny(const <String>[
      'arterite de celulas gigantes',
      'arteritis de celulas gigantes',
      'giant cell arteritis',
      'arterite temporal',
      'temporal arteritis',
    ])) {
      return 'giant_cell_arteritis';
    }

    if (containsAny(const <String>[
      'sindrome de sjogren',
      'síndrome de sjögren',
      'sjogren',
      'sjögren',
      'sjoegren',
      'sj gren',
      'sjogren syndrome',
      'sjögren syndrome',
      'sjoegren syndrome',
      'sj gren syndrome',
      'sjogrens syndrome',
    ])) {
      return 'sjogren_syndrome';
    }

    if (containsAny(const <String>[
      'sindrome antifosfolipide',
      'sindrome antifosfolipido',
      'antiphospholipid syndrome',
      'aps',
    ])) {
      return 'antiphospholipid_syndrome';
    }

    if (containsAny(const <String>[
      'doenca de behcet',
      'enfermedad de behcet',
      'behcet disease',
      'behcet syndrome',
    ])) {
      return 'behcet_syndrome';
    }

    if (containsAny(const <String>[
      'polimialgia reumatica',
      'polymyalgia rheumatica',
      'pmr',
    ])) {
      return 'polymyalgia_rheumatica';
    }

    if (containsAny(const <String>[
      'doenca de still',
      'enfermedad de still',
      'still disease',
      'adult onset still',
      'adult-onset still',
    ])) {
      return 'still_disease';
    }

    if (containsAny(const <String>[
      'esofagite eosinofilica',
      'esofagitis eosinofilica',
      'eosinophilic esophagitis',
    ])) {
      return 'eosinophilic_esophagitis';
    }

    if (containsAny(const <String>[
      'esofago de barrett',
      'esofago barrett',
      'barrett esophagus',
      'barretts esophagus',
      'barrett',
    ])) {
      return 'barrett_esophagus';
    }

    if (containsAny(const <String>[
      'doenca do refluxo gastroesofagico',
      'doença do refluxo gastroesofágico',
      'enfermedad por reflujo gastroesofagico',
      'refluxo gastroesofagico',
      'reflujo gastroesofagico',
      'gastroesophageal reflux disease',
      'gerd',
    ])) {
      return 'gastroesophageal_reflux_disease';
    }

    if (containsAny(const <String>[
      'retocolite ulcerativa',
      'colite ulcerativa',
      'colitis ulcerosa',
      'ulcerative colitis',
    ])) {
      return 'ulcerative_colitis';
    }

    if (containsAny(const <String>[
      'doenca de crohn',
      'doença de crohn',
      'enfermedad de crohn',
      'crohn disease',
      'crohns disease',
    ])) {
      return 'crohn_disease';
    }

    if (containsAny(const <String>[
      'doenca celiaca',
      'doença celíaca',
      'enfermedad celiaca',
      'celiac disease',
      'coeliac disease',
    ])) {
      return 'celiac_disease';
    }

    if (containsAny(const <String>[
      'sindrome do intestino irritavel',
      'síndrome do intestino irritável',
      'sindrome de intestino irritable',
      'irritable bowel syndrome',
    ])) {
      return 'irritable_bowel_syndrome';
    }

    if (containsAny(const <String>[
      'constipacao idiopatica cronica',
      'constipação idiopática crônica',
      'constipacion idiopatica cronica',
      'constipacao cronica',
      'constipación crónica',
      'chronic idiopathic constipation',
      'chronic constipation',
    ])) {
      return 'chronic_idiopathic_constipation';
    }

    if (containsAny(const <String>[
      'masld',
      'mash',
      'doenca hepatica esteatotica associada a disfuncao metabolica',
      'enfermedad hepatica esteatosica asociada a disfuncion metabolica',
      'metabolic dysfunction-associated steatotic liver disease',
      'metabolic dysfunction associated steatotic liver disease',
      'esteatose hepatica metabolica',
    ])) {
      return 'masld_mash';
    }

    if (containsAny(const <String>[
      'encefalopatia hepatica',
      'encefalopatia hepática',
      'encefalopatia hepatica',
      'hepatic encephalopathy',
    ])) {
      return 'hepatic_encephalopathy';
    }

    if (containsAny(const <String>[
      'peritonite bacteriana espontanea',
      'peritonite bacteriana espontânea',
      'peritonitis bacteriana espontanea',
      'spontaneous bacterial peritonitis',
      'sindrome hepatorrenal',
      'síndrome hepatorrenal',
      'hepatorenal syndrome',
      'ascite cirrotica',
      'ascites cirrotica',
      'cirrhotic ascites',
    ])) {
      return 'ascites_sbp_hrs';
    }

    if (containsAny(const <String>[
      'carcinoma hepatocelular',
      'hepatocellular carcinoma',
      'cancer hepatocelular',
      'câncer hepatocelular',
    ])) {
      return 'hepatocellular_carcinoma';
    }

    if (containsAny(const <String>[
      'hepatite b cronica',
      'hepatitis b cronica',
      'chronic hepatitis b',
      'hepatite b',
      'hepatitis b',
    ])) {
      return 'chronic_hepatitis_b';
    }

    if (containsAny(const <String>[
      'hepatite c cronica',
      'hepatitis c cronica',
      'chronic hepatitis c',
      'hepatite c',
      'hepatitis c',
    ])) {
      return 'hepatitis_c';
    }

    if (containsAny(const <String>[
      'hipotireoidismo na gravidez',
      'hipotiroidismo en el embarazo',
      'hypothyroidism in pregnancy',
      'hipertireoidismo na gravidez',
      'hipertiroidismo en el embarazo',
      'hyperthyroidism in pregnancy',
      'doenca tireoidiana na gravidez',
      'doença tireoidiana na gravidez',
      'enfermedad tiroidea en el embarazo',
      'thyroid disease in pregnancy',
      'thyroid disease during pregnancy',
    ])) {
      return 'thyroid_disease_pregnancy';
    }

    if (containsAny(const <String>[
      'cancer diferenciado de tireoide',
      'câncer diferenciado de tireoide',
      'cancer diferenciado de tiroides',
      'differentiated thyroid cancer',
      'carcinoma diferenciado de tireoide',
      'carcinoma diferenciado de tiroides',
    ])) {
      return 'differentiated_thyroid_cancer';
    }

    if (containsAny(const <String>[
      'hipotireoidismo',
      'hipotiroidismo',
      'hypothyroidism',
      'hashimoto',
    ])) {
      return 'hypothyroidism';
    }

    if (containsAny(const <String>[
      'hipertireoidismo',
      'hipertiroidismo',
      'hyperthyroidism',
      'doenca de graves',
      'doença de graves',
      'enfermedad de graves',
      'graves disease',
    ])) {
      return 'hyperthyroidism_graves';
    }

    if (containsAny(const <String>[
      'insuficiencia adrenal primaria',
      'insuficiência adrenal primária',
      'insuficiencia suprarrenal primaria',
      'primary adrenal insufficiency',
      'doenca de addison',
      'doença de addison',
      'addison disease',
    ])) {
      return 'primary_adrenal_insufficiency';
    }

    if (containsAny(const <String>['osteoporose', 'osteoporosis'])) {
      return 'osteoporosis';
    }

    if (containsAny(const <String>[
      'hiperparatireoidismo primario',
      'hiperparatireoidismo primário',
      'hiperparatiroidismo primario',
      'primary hyperparathyroidism',
    ])) {
      return 'primary_hyperparathyroidism';
    }

    if (containsAny(const <String>[
      'hipoparatireoidismo',
      'hipoparatiroidismo',
      'hypoparathyroidism',
    ])) {
      return 'hypoparathyroidism';
    }

    if (containsAny(const <String>[
      'sindrome de hipoventilacao da obesidade',
      'síndrome de hipoventilação da obesidade',
      'sindrome de hipoventilacion por obesidad',
      'obesity hypoventilation syndrome',
      'ohs',
    ])) {
      return 'obesity_hypoventilation_nice';
    }

    if (containsAny(const <String>[
      'obesidade infantil',
      'obesidade pediatrica',
      'obesidade pediátrica',
      'obesidad infantil',
      'obesidad pediatrica',
      'obesidad pediátrica',
      'childhood obesity',
      'pediatric obesity',
      'paediatric obesity',
      'obesity in children',
      'obesity in adolescents',
    ])) {
      return 'pediatric_obesity_nice_2026';
    }

    if (containsAny(const <String>['obesidade', 'obesidad', 'obesity'])) {
      return 'obesity_pharmacotherapy';
    }

    if (containsAny(const <String>[
      'sindrome dos ovarios policisticos',
      'síndrome dos ovários policísticos',
      'sindrome de ovario poliquistico',
      'síndrome de ovario poliquístico',
      'polycystic ovary syndrome',
      'pcos',
      'sop',
    ])) {
      return 'polycystic_ovary_syndrome';
    }

    if (containsAny(const <String>['acromegalia', 'acromegaly'])) {
      return 'acromegaly';
    }

    if (containsAny(const <String>[
      'hiperprolactinemia',
      'hyperprolactinemia',
      'prolactinoma',
    ])) {
      return 'hyperprolactinemia_prolactinoma';
    }

    if (containsAny(const <String>[
      'prep para hiv',
      'prep hiv',
      'profilaxia pre exposicao hiv',
      'profilaxia pre-exposicao hiv',
      'profilaxis preexposicion vih',
      'pre exposure prophylaxis hiv',
      'pre-exposure prophylaxis hiv',
    ])) {
      return 'hiv_prep';
    }

    if (containsAny(const <String>[
      'pep para hiv',
      'pep hiv',
      'profilaxia pos exposicao hiv',
      'profilaxia pós exposição hiv',
      'profilaxis posexposicion vih',
      'post exposure prophylaxis hiv',
      'post-exposure prophylaxis hiv',
      'npep hiv',
    ])) {
      return 'hiv_pep';
    }

    if (containsAny(const <String>[
      'infeccoes oportunistas no hiv',
      'infecções oportunistas no hiv',
      'infecciones oportunistas vih',
      'hiv opportunistic infections',
      'hiv oi',
      'aids opportunistic infections',
    ])) {
      return 'hiv_opportunistic_infections';
    }

    if (containsAny(const <String>[
      'tratamento antirretroviral hiv',
      'tratamento antirretroviral do hiv',
      'tratamiento antirretroviral vih',
      'antiretroviral therapy hiv',
      'art hiv',
      'hiv treatment',
      'vih tratamiento',
    ])) {
      return 'hiv_antiretroviral_therapy';
    }

    if (containsAny(const <String>[
      'tuberculose',
      'tuberculosis',
      'tb pulmonar',
      'pulmonary tb',
    ])) {
      return 'tuberculosis';
    }

    if (containsAny(const <String>['malaria', 'malária', 'paludismo'])) {
      return 'malaria';
    }

    if (containsAny(const <String>[
      'dengue',
      'chikungunya',
      'zika',
      'arbovirose',
      'arbovirosis',
      'arboviral disease',
    ])) {
      return 'arboviral_disease';
    }

    if (containsAny(const <String>['sifilis', 'sífilis', 'syphilis'])) {
      return 'syphilis';
    }

    if (containsAny(const <String>[
      'gonorreia',
      'gonorrea',
      'gonorrhea',
      'gonococo',
      'gonococcal infection',
    ])) {
      return 'gonorrhea';
    }

    if (containsAny(const <String>[
      'clamidia',
      'clamídia',
      'chlamydia',
      'chlamydial infection',
    ])) {
      return 'chlamydia';
    }

    if (containsAny(const <String>[
      'herpes genital',
      'genital herpes',
      'hsv genital',
    ])) {
      return 'genital_herpes';
    }

    if (containsAny(const <String>[
      'doenca inflamatoria pelvica',
      'doença inflamatória pélvica',
      'enfermedad inflamatoria pelvica',
      'pelvic inflammatory disease',
      'pid ginecologica',
      'dip ginecologica',
    ])) {
      return 'pelvic_inflammatory_disease';
    }

    if (containsAny(const <String>[
      'clostridioides difficile',
      'clostridium difficile',
      'c difficile',
      'c. difficile',
      'colite por c difficile',
    ])) {
      return 'clostridioides_difficile';
    }

    if (containsAny(const <String>[
      'covid 19',
      'covid-19',
      'sars cov 2',
      'sars-cov-2',
      'coronavirus disease 2019',
    ])) {
      return 'covid_19';
    }

    if (containsAny(const <String>[
      'influenza',
      'gripe influenza',
      'seasonal flu',
      'seasonal influenza',
    ])) {
      return 'influenza';
    }

    if (containsAny(const <String>[
      'abstinencia alcoolica',
      'abstinência alcoólica',
      'abstinencia alcoholica',
      'alcohol withdrawal',
      'delirium tremens',
      'delirium por abstinencia',
      'delirium por abstinência',
    ])) {
      return 'alcohol_withdrawal';
    }

    if (containsAny(const <String>[
      'status epilepticus',
      'estado de mal epileptico',
      'estado de mal epiléptico',
      'estatus epileptico',
      'estatus epiléptico',
      'crise epileptica prolongada',
      'crise epiléptica prolongada',
    ])) {
      return 'status_epilepticus';
    }

    if (containsAny(const <String>[
      'epilepsia',
      'epilepsy',
      'crises epilepticas recorrentes',
      'crises epilépticas recorrentes',
      'seizure disorder',
    ])) {
      return 'epilepsy';
    }

    if (containsAny(const <String>[
      'enxaqueca',
      'migranea',
      'migraña',
      'migraine',
    ])) {
      return 'migraine';
    }

    if (containsAny(const <String>[
      'doenca de parkinson',
      'doença de parkinson',
      'enfermedad de parkinson',
      'parkinson disease',
      'parkinsons disease',
      'parkinson',
    ])) {
      return 'parkinson_disease';
    }

    if (containsAny(const <String>[
      'esclerose multipla',
      'esclerose múltipla',
      'esclerosis multiple',
      'multiple sclerosis',
    ])) {
      return 'multiple_sclerosis';
    }

    if (containsAny(const <String>[
      'miastenia gravis',
      'myasthenia gravis',
      'crise miastenica',
      'crise miastênica',
      'myasthenic crisis',
    ])) {
      return 'myasthenia_gravis';
    }

    if (containsAny(const <String>[
      'guillain barre',
      'guillain-barré',
      'guillain barre syndrome',
      'guillain-barré syndrome',
      'sindrome de guillain barre',
      'síndrome de guillain-barré',
    ])) {
      return 'guillain_barre_syndrome';
    }

    if (containsAny(const <String>[
      'delirium',
      'estado confusional agudo',
      'acute confusional state',
    ])) {
      return 'delirium';
    }

    if (containsAny(const <String>[
      'demencia',
      'demência',
      'dementia',
      'doenca de alzheimer',
      'doença de alzheimer',
      'enfermedad de alzheimer',
      'alzheimer disease',
      'alzheimers disease',
    ])) {
      return 'dementia_alzheimer';
    }

    if (containsAny(const <String>[
      'dor neuropatica',
      'dor neuropática',
      'dolor neuropatico',
      'dolor neuropático',
      'neuropathic pain',
    ])) {
      return 'neuropathic_pain';
    }

    if (containsAny(const <String>[
      'transtorno bipolar',
      'trastorno bipolar',
      'bipolar disorder',
      'mania bipolar',
      'depressao bipolar',
      'depressão bipolar',
      'bipolar depression',
    ])) {
      return 'bipolar_disorder';
    }

    if (containsAny(const <String>[
      'depressao maior',
      'depressão maior',
      'transtorno depressivo maior',
      'trastorno depresivo mayor',
      'major depressive disorder',
      'major depression',
    ])) {
      return 'major_depressive_disorder';
    }

    if (containsAny(const <String>[
      'ansiedade generalizada',
      'ansiedad generalizada',
      'generalised anxiety disorder',
      'generalized anxiety disorder',
      'transtorno de panico',
      'transtorno de pânico',
      'trastorno de panico',
      'panic disorder',
    ])) {
      return 'gad_panic_disorder';
    }

    if (containsAny(const <String>[
      'esquizofrenia',
      'schizophrenia',
      'psicose',
      'psicosis',
      'psychosis',
    ])) {
      return 'schizophrenia_psychosis';
    }

    if (containsAny(const <String>[
      'anemia ferropriva',
      'anemia por deficiencia de ferro',
      'anemia por deficiência de ferro',
      'anemia ferropenica',
      'anemia ferropénica',
      'iron deficiency anemia',
    ])) {
      return 'iron_deficiency_anemia';
    }

    if (containsAny(const <String>[
      'deficiencia de vitamina b12',
      'deficiência de vitamina b12',
      'vitamin b12 deficiency',
      'anemia megaloblastica por b12',
      'anemia megaloblástica por b12',
    ])) {
      return 'vitamin_b12_deficiency';
    }

    if (containsAny(const <String>[
      'anemia hemolitica autoimune',
      'anemia hemolítica autoimune',
      'anemia hemolitica autoinmune',
      'autoimmune hemolytic anemia',
      'aiha',
    ])) {
      return 'autoimmune_hemolytic_anemia';
    }

    if (containsAny(const <String>[
      'doenca falciforme',
      'doença falciforme',
      'anemia falciforme',
      'sickle cell disease',
      'sickle cell anemia',
    ])) {
      return 'sickle_cell_disease';
    }

    if (containsAny(const <String>[
      'talassemia beta dependente de transfusao',
      'talassemia beta dependente de transfusão',
      'beta talassemia transfusional',
      'transfusion dependent thalassemia',
      'transfusion-dependent thalassemia',
      'thalassemia major',
      'talassemia major',
    ])) {
      return 'transfusion_dependent_thalassemia';
    }

    if (containsAny(const <String>[
      'purpura trombocitopenica imune',
      'púrpura trombocitopênica imune',
      'trombocitopenia imune',
      'immune thrombocytopenia',
      'itp',
    ])) {
      return 'immune_thrombocytopenia';
    }

    if (containsAny(const <String>[
      'purpura trombotica trombocitopenica',
      'púrpura trombótica trombocitopênica',
      'thrombotic thrombocytopenic purpura',
      'ttp',
      'ptt trombotica',
    ])) {
      return 'thrombotic_thrombocytopenic_purpura';
    }

    if (containsAny(const <String>[
      'trombocitopenia induzida por heparina',
      'trombocitopenia inducida por heparina',
      'heparin induced thrombocytopenia',
      'heparin-induced thrombocytopenia',
      'hit',
    ])) {
      return 'heparin_induced_thrombocytopenia';
    }

    if (containsAny(const <String>[
      'doenca de von willebrand',
      'doença de von willebrand',
      'enfermedad de von willebrand',
      'von willebrand disease',
      'vwd',
    ])) {
      return 'von_willebrand_disease';
    }

    if (containsAny(const <String>[
      'limiar de transfusao',
      'limiar de transfusão',
      'umbral transfusional',
      'red blood cell transfusion threshold',
      'transfusion threshold',
      'transfusao de hemacias',
      'transfusão de hemácias',
    ])) {
      return 'red_blood_cell_transfusion';
    }

    if (containsAny(const <String>[
      'leucemia mieloide aguda',
      'leucemia mieloide aguda em idoso',
      'acute myeloid leukemia',
      'aml older adults',
      'aml',
    ])) {
      return 'acute_myeloid_leukemia';
    }

    if (containsAny(const <String>[
      'amiloidose al',
      'amiloidose de cadeia leve',
      'light chain amyloidosis',
      'al amyloidosis',
    ])) {
      return 'light_chain_amyloidosis';
    }

    if (containsAny(const <String>[
      'mieloma multiplo',
      'mieloma múltiplo',
      'multiple myeloma',
      'smoldering multiple myeloma',
    ])) {
      return 'multiple_myeloma';
    }

    if (containsAny(const <String>[
      'trombose associada ao cancer',
      'trombose associada ao câncer',
      'cancer associated thrombosis',
      'cancer-associated thrombosis',
      'vte in cancer',
      'tromboembolismo no cancer',
      'tromboembolismo no câncer',
    ])) {
      return 'cancer_associated_vte';
    }

    if (containsAny(const <String>[
      'teste de trombofilia',
      'testes de trombofilia',
      'trombofilia hereditaria',
      'trombofilia hereditária',
      'thrombophilia testing',
      'hereditary thrombophilia testing',
    ])) {
      return 'thrombophilia_testing';
    }

    if (containsAny(const <String>[
      'bronquiectasia',
      'bronquiectasias',
      'bronchiectasis',
    ])) {
      return 'bronchiectasis_ers_2025';
    }

    if (containsAny(const <String>[
      'sindrome do desconforto respiratorio agudo',
      'síndrome do desconforto respiratório agudo',
      'sindrome de dificultad respiratoria aguda',
      'acute respiratory distress syndrome',
      'ards',
      'sdra',
    ])) {
      return 'ards_ats_2024';
    }

    if (containsAny(const <String>[
      'fibrose pulmonar idiopatica',
      'fibrose pulmonar idiopática',
      'fibrosis pulmonar idiopatica',
      'idiopathic pulmonary fibrosis',
      'fibrose pulmonar progressiva',
      'progressive pulmonary fibrosis',
      'ipf',
      'ppf',
    ])) {
      return 'ipf_ppf_ats_ers_2022';
    }

    if (containsAny(const <String>[
      'apneia obstrutiva do sono',
      'apneia obstrutiva de sono',
      'apnea obstructiva del sueno',
      'apnea obstructiva del sueño',
      'obstructive sleep apnea',
      'obstructive sleep apnoea',
      'osahs',
      'osa',
    ])) {
      return 'obstructive_sleep_apnea_nice';
    }

    if (containsAny(const <String>[
      'pneumonite por hipersensibilidade',
      'neumonitis por hipersensibilidad',
      'hypersensitivity pneumonitis',
      'alveolite alergica extrinseca',
      'alveolite alérgica extrínseca',
    ])) {
      return 'hypersensitivity_pneumonitis_ats_2020';
    }

    if (containsAny(const <String>[
      'hemorragia pos parto',
      'hemorragia pós parto',
      'hemorragia pos-parto',
      'hemorragia pós-parto',
      'hemorragia postpartum',
      'hemorragia postparto',
      'postpartum hemorrhage',
      'postpartum haemorrhage',
      'pph obstetrica',
      'pph obstétrica',
    ])) {
      return 'postpartum_hemorrhage_who_2025';
    }

    if (containsAny(const <String>[
      'gravidez ectopica',
      'gravidez ectópica',
      'embarazo ectopico',
      'embarazo ectópico',
      'ectopic pregnancy',
    ])) {
      return 'ectopic_pregnancy_nice_2026';
    }

    if (containsAny(const <String>[
      'abortamento espontaneo',
      'abortamento espontâneo',
      'aborto espontaneo',
      'aborto espontâneo',
      'perda gestacional precoce',
      'perdida gestacional temprana',
      'pérdida gestacional temprana',
      'miscarriage',
      'early pregnancy loss',
    ])) {
      return 'miscarriage_nice_2026';
    }

    if (containsAny(const <String>['endometriose', 'endometriosis'])) {
      return 'endometriosis_nice_2024';
    }

    if (containsAny(const <String>[
      'sangramento menstrual intenso',
      'sangramento uterino intenso',
      'menorragia',
      'menorrhagia',
      'heavy menstrual bleeding',
      'hmb ginecologico',
      'hmb ginecológico',
    ])) {
      return 'heavy_menstrual_bleeding_nice';
    }

    if (containsAny(const <String>[
      'menopausa',
      'menopausia',
      'menopause',
      'sintomas vasomotores',
      'vasomotor symptoms',
    ])) {
      return 'menopause_nice_2026';
    }

    if (containsAny(const <String>[
      'bronquiolite',
      'bronquiolitis',
      'bronchiolitis',
    ])) {
      return 'pediatric_bronchiolitis_nice';
    }

    if (containsAny(const <String>[
      'febre em menor de 5 anos',
      'febre em menores de 5 anos',
      'fiebre en menor de 5 anos',
      'fiebre en menores de 5 anos',
      'fever in under 5',
      'fever under 5',
    ])) {
      return 'fever_under_five_nice';
    }

    if (containsAny(const <String>[
      'ictericia neonatal',
      'icterícia neonatal',
      'jaundice neonatal',
      'newborn jaundice',
      'neonatal jaundice',
    ])) {
      return 'neonatal_jaundice_nice_2023';
    }

    if (containsAny(const <String>[
      'tdah',
      'tadh',
      'adhd',
      'attention deficit hyperactivity disorder',
      'transtorno de deficit de atencao e hiperatividade',
      'transtorno de déficit de atenção e hiperatividade',
      'trastorno por deficit de atencion e hiperactividad',
      'trastorno por déficit de atención e hiperactividad',
    ])) {
      return 'adhd_nice_current';
    }

    if (containsAny(const <String>[
      'itu pediatrica',
      'itu pediátrica',
      'itu infantil',
      'infeccao urinaria em crianca',
      'infecção urinária em criança',
      'infeccion urinaria pediatrica',
      'infección urinaria pediátrica',
      'urinary tract infection in child',
      'urinary tract infection in children',
      'pediatric urinary tract infection',
      'paediatric urinary tract infection',
    ])) {
      return 'pediatric_uti_nice_2022';
    }

    if (containsAny(const <String>[
      'infeccao urinaria',
      'infeccion urinaria',
      'infeccao do trato urinario',
      'infeccion del tracto urinario',
      'urinary tract infection',
      'pielonefr',
      'pyeloneph',
      'cistite',
      'cistitis',
    ])) {
      return 'urinary_tract_infection';
    }

    if (containsAny(const <String>[
      'pancreatite',
      'pancreatitis',
      'acute pancreatitis',
    ])) {
      return 'acute_pancreatitis';
    }

    if (containsAny(const <String>['anafilax', 'anaphylax'])) {
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
  static const Set<String> _top150Batch01Domains = <String>{
    'asthma',
    'copd',
    'diabetes',
    'hyperglycemic_crisis',
    'hypertension',
    'acute_coronary_syndrome',
    'atrial_fibrillation',
    'heart_failure',
    'pulmonary_embolism',
    'acute_ischemic_stroke',
    'chronic_kidney_disease',
    'sepsis',
    'adult_pneumonia',
    'urinary_tract_infection',
    'acute_pancreatitis',
  };

  static const Set<String> _top150Batch02Domains = <String>{
    'dyslipidemia',
    'valvular_heart_disease',
    'myocarditis',
    'pericarditis',
    'peripheral_artery_disease',
    'acute_aortic_syndrome',
    'hypertrophic_cardiomyopathy',
    'infective_endocarditis',
    'bacterial_meningitis',
    'h_pylori',
    'upper_gi_bleeding',
    'acute_appendicitis',
    'acute_cholecystitis',
    'acute_cholangitis',
    'acute_diverticulitis',
  };

  static const Set<String> _top150Batch03Domains = <String>{
    'rheumatoid_arthritis',
    'systemic_lupus_erythematosus',
    'lupus_nephritis',
    'gout',
    'osteoarthritis',
    'psoriatic_arthritis',
    'axial_spondyloarthritis',
    'systemic_sclerosis',
    'anca_associated_vasculitis',
    'giant_cell_arteritis',
    'sjogren_syndrome',
    'antiphospholipid_syndrome',
    'behcet_syndrome',
    'polymyalgia_rheumatica',
    'still_disease',
  };

  static const Set<String> _top150Batch04Domains = <String>{
    'gastroesophageal_reflux_disease',
    'barrett_esophagus',
    'eosinophilic_esophagitis',
    'ulcerative_colitis',
    'crohn_disease',
    'celiac_disease',
    'irritable_bowel_syndrome',
    'chronic_idiopathic_constipation',
    'masld_mash',
    'cirrhosis_portal_hypertension',
    'ascites_sbp_hrs',
    'hepatic_encephalopathy',
    'hepatocellular_carcinoma',
    'chronic_hepatitis_b',
    'hepatitis_c',
  };

  static const Set<String> _top150Batch05Domains = <String>{
    'hypothyroidism',
    'hyperthyroidism_graves',
    'differentiated_thyroid_cancer',
    'thyroid_disease_pregnancy',
    'primary_adrenal_insufficiency',
    'cushing_syndrome',
    'primary_aldosteronism',
    'pheochromocytoma_paraganglioma',
    'osteoporosis',
    'primary_hyperparathyroidism',
    'hypoparathyroidism',
    'obesity_pharmacotherapy',
    'polycystic_ovary_syndrome',
    'acromegaly',
    'hyperprolactinemia_prolactinoma',
  };

  static const Set<String> _top150Batch06Domains = <String>{
    'hiv_antiretroviral_therapy',
    'hiv_opportunistic_infections',
    'hiv_prep',
    'hiv_pep',
    'tuberculosis',
    'malaria',
    'arboviral_disease',
    'syphilis',
    'gonorrhea',
    'chlamydia',
    'genital_herpes',
    'pelvic_inflammatory_disease',
    'clostridioides_difficile',
    'covid_19',
    'influenza',
  };

  static const Set<String> _top150Batch07Domains = <String>{
    'epilepsy',
    'status_epilepticus',
    'migraine',
    'parkinson_disease',
    'multiple_sclerosis',
    'myasthenia_gravis',
    'guillain_barre_syndrome',
    'delirium',
    'dementia_alzheimer',
    'neuropathic_pain',
    'major_depressive_disorder',
    'bipolar_disorder',
    'gad_panic_disorder',
    'schizophrenia_psychosis',
    'alcohol_withdrawal',
  };

  static const Set<String> _top150Batch08Domains = <String>{
    'iron_deficiency_anemia',
    'vitamin_b12_deficiency',
    'autoimmune_hemolytic_anemia',
    'sickle_cell_disease',
    'transfusion_dependent_thalassemia',
    'immune_thrombocytopenia',
    'thrombotic_thrombocytopenic_purpura',
    'heparin_induced_thrombocytopenia',
    'von_willebrand_disease',
    'red_blood_cell_transfusion',
    'acute_myeloid_leukemia',
    'light_chain_amyloidosis',
    'multiple_myeloma',
    'cancer_associated_vte',
    'thrombophilia_testing',
  };

  static const Set<String> _top150Batch09Domains = <String>{
    'acute_kidney_injury_aki_akd',
    'iga_nephropathy_vasculitis_2025',
    'adpkd_kdigo_2025',
    'anemia_ckd_kdigo_2026',
    'pediatric_nephrotic_syndrome_kdigo_2025',
    'kidney_ureteral_stones_aua_2026',
    'hyperkalemia_ukka_2023',
    'hyponatremia_european_2014',
    'pulmonary_hypertension_esc_ers_2022',
    'bronchiectasis_ers_2025',
    'ards_ats_2024',
    'ipf_ppf_ats_ers_2022',
    'obstructive_sleep_apnea_nice',
    'obesity_hypoventilation_nice',
    'hypersensitivity_pneumonitis_ats_2020',
  };

  static const Set<String> _top150Batch10Domains = <String>{
    'preeclampsia_eclampsia_nice_2023',
    'postpartum_hemorrhage_who_2025',
    'gestational_diabetes_ada_2026',
    'ectopic_pregnancy_nice_2026',
    'miscarriage_nice_2026',
    'endometriosis_nice_2024',
    'heavy_menstrual_bleeding_nice',
    'menopause_nice_2026',
    'pediatric_bronchiolitis_nice',
    'fever_under_five_nice',
    'pediatric_uti_nice_2022',
    'neonatal_jaundice_nice_2023',
    'neonatal_infection_nice_2026',
    'pediatric_obesity_nice_2026',
    'adhd_nice_current',
  };

  static const Set<String> _top200ExpansionBatch30Domains = <String>{
    'acute_rhinosinusitis_aao_hns_2025',
    'chronic_rhinosinusitis_aao_hns_2025',
    'allergic_rhinitis_aria_eaaci_2026',
    'acute_otitis_externa_aao_hns_current',
    'sudden_sensorineural_hearing_loss_aao_hns_japan',
    'conjunctivitis_aao_2024',
    'bacterial_keratitis_aao_2024',
    'uveitis_dog_ser_consensus_2025',
    'primary_open_angle_glaucoma_aao_2026',
    'adult_cataract_aao_nice_current',
  };

  static const Set<String> _top200ExpansionBatch29Domains = <String>{
    'pediatric_pertussis_cdc_2026',
    'pediatric_croup_cps_2026',
    'pediatric_acute_otitis_media_aap_nice',
    'pediatric_scarlet_fever_cdc_2026',
    'pediatric_acute_gastroenteritis_who_2024',
    'pediatric_dehydration_rch_2026',
    'kawasaki_disease_aha_2024',
    'hand_foot_mouth_disease_cdc_who',
    'febrile_seizure_aap_rch_current',
    'autism_spectrum_disorder_aap_2025',
  };

  static const Set<String> _top200ExpansionBatch28Domains = <String>{
    'uterine_fibroids_acog_nice_2025',
    'adenomyosis_asea_nice_2023',
    'bacterial_vaginosis_cdc_who_acog_2025',
    'vulvovaginal_candidiasis_cdc_who_idsa',
    'trichomoniasis_cdc_who_current',
    'gestational_trophoblastic_disease_figo_2025',
    'hyperemesis_gravidarum_rcog_2024',
    'placenta_previa_rcog_2026',
    'placental_abruption_rcog_acog_current',
    'prelabor_rupture_membranes_acog_2026',
  };

  static const Set<String> _top200ExpansionBatch27Domains = <String>{
    'cutaneous_dermatophytosis_aad_cdc_2026',
    'cutaneous_candidiasis_idsa_cdc_current',
    'hidradenitis_suppurativa_aad_2026',
    'vitiligo_bad_2021_current',
    'alopecia_areata_bad_living_2024',
    'pemphigus_vulgaris_eadv_2020_current',
    'bullous_pemphigoid_eadv_2022_current',
    'cutaneous_melanoma_aad_current',
    'basal_cell_carcinoma_aad_current',
    'cutaneous_squamous_cell_carcinoma_aad_current',
  };

  static const Set<String> _top200ExpansionBatch26Domains = <String>{
    'atopic_dermatitis_aad_2026',
    'contact_dermatitis_bad_escd_2025',
    'seborrheic_dermatitis_eadv_2026',
    'psoriasis_aad_npf_current',
    'chronic_urticaria_euroguiderm_eaaci_2022',
    'hereditary_angioedema_wao_2025',
    'acne_vulgaris_aad_2024',
    'rosacea_global_consensus_2024',
    'impetigo_nice_2026',
    'scabies_cdc_current',
  };

  static const Set<String> _top200ExpansionBatch25Domains = <String>{
    'fibromyalgia_eular_nice_current',
    'reactive_arthritis_acr_2025',
    'cppd_acr_eular_2023',
    'idiopathic_inflammatory_myopathy_bsr_2022',
    'juvenile_idiopathic_arthritis_acr_2026',
    'primary_raynaud_acr_2025',
    'nonspecific_low_back_pain_who_nice',
    'lumbar_radiculopathy_sciatica_nice',
    'nonspecific_cervicalgia_jospt_current',
    'rotator_cuff_injury_aaos_2025',
  };

  static const Set<String> _top200ExpansionBatch24Domains = <String>{
    'adult_acute_lymphoblastic_leukemia_eln_2024',
    'classical_hodgkin_lymphoma_bsh_nci',
    'diffuse_large_b_cell_lymphoma_bsh_2025',
    'breast_cancer_esmo_nci_current',
    'prostate_cancer_eau_2026',
    'non_small_cell_lung_cancer_esmo_nci_current',
    'colorectal_cancer_asco_nci_current',
    'cervical_cancer_esgo_2023_current',
    'ovarian_cancer_esgo_esmo_2024',
    'pancreatic_cancer_esmo_2025',
  };

  static const Set<String> _top200ExpansionBatch23Domains = <String>{
    'anemia_of_inflammation_ash_current',
    'folate_deficiency_nih_who_bsh',
    'acquired_aplastic_anemia_ash_2026',
    'g6pd_deficiency_who_2025',
    'hemophilia_ab_wfh_living_2026',
    'disseminated_intravascular_coagulation_isth_2025',
    'polycythemia_vera_bsh_eln_current',
    'essential_thrombocythemia_2024_current',
    'myelofibrosis_bsh_2023_current',
    'chronic_lymphocytic_leukemia_bsh_2025',
  };

  static const Set<String> _top200ExpansionBatch22Domains = <String>{
    'panic_disorder_nice_2026',
    'social_anxiety_disorder_nice_2026',
    'obsessive_compulsive_disorder_nice_2026',
    'posttraumatic_stress_disorder_va_dod_2023',
    'anorexia_nervosa_apa_nice_current',
    'bulimia_nervosa_apa_nice_current',
    'opioid_use_disorder_asam_samhsa_current',
    'cannabis_use_disorder_who_samhsa_current',
    'chronic_insomnia_aasm_current',
    'borderline_personality_disorder_nice_current',
  };

  static const Set<String> _top200ExpansionBatch21Domains = <String>{
    'amyotrophic_lateral_sclerosis_ean_2024',
    'diabetic_peripheral_neuropathy_ada_aan_2026',
    'carpal_tunnel_syndrome_aaos_2024',
    'idiopathic_normal_pressure_hydrocephalus_2021',
    'essential_tremor_mds_2026',
    'huntington_disease_dgn_ehdn_2023',
    'dystonia_mds_ean_current',
    'restless_legs_syndrome_aasm_2025',
    'nutritional_peripheral_neuropathy_nice_2026',
    'degenerative_cervical_myelopathy_aospine_2025',
  };

  static const Set<String> _top200ExpansionBatch20Domains = <String>{
    'transient_ischemic_attack_aha_2023',
    'spontaneous_intracerebral_hemorrhage_aha_2022',
    'aneurysmal_subarachnoid_hemorrhage_aha_2023',
    'cerebral_venous_thrombosis_aha_2024',
    'trigeminal_neuralgia_ean_2019',
    'cluster_headache_ean_2023',
    'tension_type_headache_nice_2025',
    'bppv_aao_hns_2026',
    'vestibular_neuritis_barany_2022',
    'bell_palsy_aao_hns_2026',
  };

  static const Set<String> _top200ExpansionBatch19Domains = <String>{
    'leptospirosis_cdc_2026',
    'chagas_who_paho_2026',
    'visceral_leishmaniasis_who_2026',
    'yellow_fever_who_cdc_2026',
    'chikungunya_who_cdc_2026',
    'zika_who_cdc_2025',
    'typhoid_fever_cdc_2026',
    'brucellosis_cdc_2026',
    'spotted_fever_rickettsiosis_cdc_2025',
    'mpox_who_cdc_2026',
  };

  static const Set<String> _top200ExpansionBatch18Domains = <String>{
    'herpes_zoster_cdc_nih_2026',
    'varicella_cdc_nih_2026',
    'infectious_mononucleosis_ebv_cdc',
    'cytomegalovirus_disease_nih_2026',
    'toxoplasmosis_cdc_nih_2026',
    'hepatitis_a_cdc_2025',
    'cellulitis_ssti_idsa_nice',
    'erysipelas_idsa_nice',
    'osteomyelitis_idsa_pids',
    'septic_arthritis_sanjo_pids_idsa',
  };

  static const Set<String> _top200ExpansionBatch17Domains = <String>{
    'poststreptococcal_infection_related_gn_kdigo',
    'anti_gbm_goodpasture_kdigo',
    'membranous_nephropathy_kdigo',
    'fsgs_kdigo',
    'hemolytic_uremic_syndrome_complement_2026',
    'acute_interstitial_nephritis_2024',
    'renal_tubular_acidosis_core_2025',
    'interstitial_cystitis_bladder_pain_2026',
    'benign_prostatic_hyperplasia_luts_2026',
    'bacterial_prostatitis_eau_2026',
  };

  static const Set<String> _top200ExpansionBatch16Domains = <String>{
    'arginine_vasopressin_deficiency_ese_es_2026',
    'siadh_hyponatremia_ese',
    'hypercalcemia_endocrine_society_2023',
    'hypocalcemia_hypoparathyroidism_ese_2025',
    'hypomagnesemia_core_curriculum_2024',
    'hypophosphatemia_consensus_2025',
    'severe_hypertriglyceridemia_acc_aha_2026',
    'metabolic_syndrome_harmonized',
    'hypopituitarism_endocrine_society',
    'adrenal_incidentaloma_ese_2023',
  };

  static const Set<String> _top200ExpansionBatch15Domains = <String>{
    'alcohol_associated_hepatitis_acg_2024',
    'alcohol_associated_liver_disease_acg_2024',
    'autoimmune_hepatitis_easl_2025',
    'primary_biliary_cholangitis_aasld_2021',
    'primary_sclerosing_cholangitis_aasld_2022',
    'chronic_pancreatitis_acg_2020',
    'exocrine_pancreatic_insufficiency_aga_2023',
    'pancreatic_cyst_ipmn_kyoto_2024',
    'hereditary_hemochromatosis_easl_2022',
    'wilson_disease_easl_2025',
  };

  static const Set<String> _top200ExpansionBatch14Domains = <String>{
    'peptic_ulcer_disease_esge_2026',
    'nsaid_gastropathy_ulcer_prevention',
    'functional_dyspepsia_bsg_2022',
    'gastroparesis_aga_2025',
    'uncomplicated_diverticular_disease_acg_2026',
    'lower_gi_bleeding_acg_2023',
    'microscopic_colitis_ueg_emcg_2021',
    'ischemic_colitis_acg',
    'proctitis_multietiology_guidance',
    'fecal_incontinence_ascrs_2023',
  };

  static const Set<String> _top200ExpansionBatch13Domains = <String>{
    'spontaneous_pneumothorax_ers_bts_2024',
    'hemothorax_trauma_guidelines',
    'pleural_effusion_bts_2023',
    'pleural_empyema_bts_2023',
    'lung_abscess_lower_respiratory_guidance',
    'aspiration_pneumonia_bts_2023',
    'acute_bronchitis_antibiotic_stewardship',
    'chronic_cough_ers_bts',
    'pulmonary_sarcoidosis_ers_ats',
    'cystic_fibrosis_ecfs_cff_2024',
  };

  static const Set<String> _top200ExpansionBatch12Domains = <String>{
    'abdominal_aortic_aneurysm_esc_2024',
    'thoracic_aortic_aneurysm_esc_2024',
    'deep_vein_thrombosis_ash',
    'chronic_venous_disease_esvs_2022',
    'superficial_venous_thrombosis_esvs_2021',
    'vasovagal_reflex_syncope',
    'orthostatic_hypotension_aha_2024',
    'postural_orthostatic_tachycardia_syndrome',
    'rheumatic_fever_rheumatic_heart_disease_who_2024',
    'hypertensive_emergency_aha_2024',
  };

  static const Set<String> _top200ExpansionBatch11Domains = <String>{
    'chronic_coronary_syndrome_esc_2024',
    'paroxysmal_supraventricular_tachycardia',
    'atrial_flutter',
    'sustained_ventricular_tachycardia',
    'atrioventricular_block',
    'wolff_parkinson_white_wpw',
    'long_qt_syndrome',
    'brugada_syndrome',
    'dilated_cardiomyopathy_esc_2023',
    'takotsubo_syndrome_consensus_2024',
  };

  // Batch 01 — current official authorities.
  // These strings are reference metadata only. They do not alter diagnosis,
  // treatment, dose, routing, persistence, model prompts or streaming.
  static List<String> _curatedReferencesForDomain(String? domain) {
    switch (domain) {
      case 'choledocholithiasis':
        return const <String>[
          'ASGE — Guideline on the role of endoscopy in the evaluation and management of choledocholithiasis. Gastrointest Endosc. 2019;89:1075-1105.e15',
          'ESGE — Endoscopic management of common bile duct stones. Endoscopy. 2019;51:472-491. doi:10.1055/a-0862-0346',
        ];
      case 'thoracic_trauma':
        return const <String>[
          'ACS — ATLS 11: Thoracic Trauma (2025)',
          'WSES-AAST — Thoracic trauma guidelines. World J Emerg Surg. 2025;20:78. doi:10.1186/s13017-025-00651-1',
        ];

      case 'asthma':
        return const <String>[
          'GINA — Global Strategy for Asthma Management and Prevention (2026) — https://ginasthma.org/2026-gina-strategy-report/',
          'GINA — Summary Guide for Asthma Management and Prevention (2026) — https://ginasthma.org/reports/',
          'GINA — Difficult-to-Treat & Severe Asthma Guide (2026) — https://ginasthma.org/2026-gina-severe-asthma-guide/',
        ];

      case 'copd':
        return const <String>[
          'GOLD — Global Strategy for Prevention, Diagnosis and Management of COPD (2026) — https://goldcopd.org/2026-gold-report-and-pocket-guide/',
          'GOLD — Pocket Guide to COPD Diagnosis, Management and Prevention (2026) — https://goldcopd.org/wp-content/uploads/2026/01/GOLD-Pocket-Guide-2026-v1.1-20Nov2025_WMV2.pdf',
          'GOLD — Official translated materials, including Spanish 2026 (2026) — https://goldcopd.org/translated-gold-pocket-guides/',
        ];

      case 'diabetes':
        return const <String>[
          'ADA — Diagnosis and Classification of Diabetes: Standards of Care in Diabetes (2026) — https://diabetesjournals.org/care/article/49/Supplement_1/S27/163926/2-Diagnosis-and-Classification-of-Diabetes',
          'ADA — Pharmacologic Approaches to Glycemic Treatment: Standards of Care in Diabetes (2026) — https://diabetesjournals.org/care/article/49/Supplement_1/S183/163934/9-Pharmacologic-Approaches-to-Glycemic-Treatment',
          'ADA — Glycemic Goals, Hypoglycemia, and Hyperglycemic Crises: Standards of Care in Diabetes (2026) — https://diabetesjournals.org/care/article/49/Supplement_1/S132/163927/6-Glycemic-Goals-Hypoglycemia-and-Hyperglycemic',
        ];

      case 'hyperglycemic_crisis':
        return const <String>[
          'ADA/EASD/JBDS/AACE/DTS — Hyperglycemic Crises in Adults With Diabetes: Consensus Report (2024) — https://diabetesjournals.org/care/article/47/8/1257/156808/Hyperglycemic-Crises-in-Adults-With-Diabetes-A',
          'ADA — Glycemic Goals, Hypoglycemia, and Hyperglycemic Crises: Standards of Care in Diabetes (2026) — https://diabetesjournals.org/care/article/49/Supplement_1/S132/163927/6-Glycemic-Goals-Hypoglycemia-and-Hyperglycemic',
          'ADA — Diabetes Care in the Hospital: Standards of Care in Diabetes (2026) — https://diabetesjournals.org/care/article/49/Supplement_1/S339/163925/16-Diabetes-Care-in-the-Hospital-Standards-of-Care',
        ];

      case 'hypertension':
        return const <String>[
          'AHA/ACC Multisociety — High Blood Pressure Guideline (2025) — https://professional.heart.org/en/science-news/2025-high-blood-pressure-guideline',
          'ESC — Guidelines for the Management of Elevated Blood Pressure and Hypertension (2024) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/elevated-blood-pressure-and-hypertension/',
          'AHA/ACC — Risk Assessment to Guide Blood Pressure Management (2025) — https://professional.heart.org/en/science-news/use-of-risk-assessment-to-guide-decision-making-for-blood-pressure-management',
        ];

      case 'acute_coronary_syndrome':
        return const <String>[
          'ACC/AHA/ACEP/NAEMSP/SCAI — Guideline for Management of Acute Coronary Syndromes (2025) — https://professional.heart.org/en/science-news/2025-guideline-for-the-management-of-patients-with-acute-coronary-syndromes',
          'ESC — Guidelines for the Management of Acute Coronary Syndromes (2023) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/acute-coronary-syndromes/',
          'ACC/AHA/ACEP/NAEMSP/SCAI — Full guideline DOI (2025) — https://doi.org/10.1161/CIR.0000000000001309',
        ];

      case 'atrial_fibrillation':
        return const <String>[
          'ESC — Guidelines for the Management of Atrial Fibrillation (2024) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/atrial-fibrillation/',
          'ACC/AHA/ACCP/HRS — Guideline for the Diagnosis and Management of Atrial Fibrillation (2023) — https://professional.heart.org/en/science-news/2023-acc-aha-accp-hrs-guideline-for-the-diagnosis-and-management-of-atrial-fibrillation',
          'ACC/AHA/ACCP/HRS — Full guideline DOI (2023) — https://doi.org/10.1161/CIR.0000000000001193',
        ];

      case 'heart_failure':
        return const <String>[
          'AHA/ACC/HFSA — Guideline for the Management of Heart Failure (2022) — https://professional.heart.org/en/science-news/2022-guideline-for-the-management-of-heart-failure',
          'ESC — Focused Update of the 2021 Heart Failure Guidelines (2023) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/focused-update-on-heart-failure/',
          'AHA/ACC/HFSA — Full guideline DOI (2022) — https://doi.org/10.1161/CIR.0000000000001063',
        ];

      case 'pulmonary_embolism':
        return const <String>[
          'AHA/ACC/ACCP/ACEP/CHEST/SCAI/SHM/SIR/SVM/SVN — Acute Pulmonary Embolism Guideline (2026) — https://professional.heart.org/en/science-news/2026-guideline-for-the-evaluation-and-management-of-acute-pulmonary-embolism-in-adults',
          'AHA/ACC Multisociety — Circulation full guideline DOI (2026) — https://doi.org/10.1161/CIR.0000000000001415',
          'JACC — 2026 Acute Pulmonary Embolism Guideline — https://doi.org/10.1016/j.jacc.2025.11.005',
          'JACC — Correction to 2026 Acute Pulmonary Embolism Guideline (11 Aug 2026) — https://doi.org/10.1016/j.jacc.2026.06.033',
        ];

      case 'acute_ischemic_stroke':
        return const <String>[
          'AHA/ASA — Guideline for the Early Management of Acute Ischemic Stroke (2026) — https://professional.heart.org/en/science-news/2026-guideline-for-the-early-management-of-patients-with-acute-ischemic-stroke',
          'AHA/ASA — Acute Ischemic Stroke guideline hub (2026) — https://professional.heart.org/en/guidelines-statements/2026-guideline-for-the-early-management-of-patients-with-acute-ischemic-strokestr0000000000000513',
          'AHA/ASA — Full guideline DOI (2026) — https://doi.org/10.1161/STR.0000000000000513',
        ];

      case 'chronic_kidney_disease':
        return const <String>[
          'KDIGO — Clinical Practice Guideline for Evaluation and Management of CKD (2024) — https://kdigo.org/guidelines/ckd-evaluation-and-management/',
          'KDIGO — 2024 CKD Guideline PDF (2024) — https://kdigo.org/wp-content/uploads/2024/03/KDIGO-2024-CKD-Guideline.pdf',
          'KDIGO — Kidney International guideline DOI (2024) — https://doi.org/10.1016/j.kint.2023.10.018',
        ];

      case 'sepsis':
        return const <String>[
          'Surviving Sepsis Campaign / SCCM / ESICM — Adult Guidelines (2026) — https://www.sccm.org/survivingsepsiscampaign/guidelines-and-resources/surviving-sepsis-campaign-adult-guidelines',
          'Surviving Sepsis Campaign — International Guidelines for Management of Sepsis and Septic Shock (2026) — https://www.sccm.org/clinical-resources/guidelines/guidelines/surviving-sepsis-campaign-international-guidelines-for-management-of-sepsis-and-septic-shock-2026',
          'SCCM / ESICM — Full guideline DOI (2026) — https://doi.org/10.1097/CCM.0000000000007075',
        ];

      case 'adult_pneumonia':
        return const <String>[
          'ATS — Diagnosis and Management of Community-acquired Pneumonia: Clinical Practice Guideline (2025) — https://doi.org/10.1164/rccm.202507-1692ST',
          'ATS — Official CAP guideline PDF (approved 2025) — https://www.atsjournals.org/doi/pdf/10.1164/rccm.202507-1692st',
          'ATS/IDSA — CAP guideline implementation resources (2019 baseline) — https://www.thoracic.org/statements/guideline-implementation-tools/diagnosis-and-treatment-of-cap.php',
        ];

      case 'dyslipidemia':
        return const <String>[
          'ACC/AHA Multisociety — Guideline on the Management of Dyslipidemia (2026) — https://professional.heart.org/en/science-news/2026-guideline-on-the-management-of-dyslipidemia',
          'AHA — 2026 Dyslipidemia Guideline Hub (2026) — https://professional.heart.org/en/guidelines-statements/2026-accahaaacvprabcacpmadaagsaphaaspcnlapcna-guideline-on-the-management-ofcir0000000000001423',
          'ACC/AHA Multisociety — Full guideline DOI (2026) — https://doi.org/10.1161/CIR.0000000000001423',
        ];

      case 'valvular_heart_disease':
        return const <String>[
          'ESC/EACTS — Guidelines for the Management of Valvular Heart Disease (2025) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/valvular-heart-disease/',
          'ESC — Pocket Guidelines on Valvular Heart Disease (2025) — https://www.escardio.org/guidelines/clinical-practice-guidelines/pocket-guidelines/valvular-heart-disease/',
          'ESC/EACTS — European Heart Journal guideline DOI (2025) — https://doi.org/10.1093/eurheartj/ehaf194',
        ];

      case 'myocarditis':
        return const <String>[
          'ESC — Guidelines for the Management of Myocarditis and Pericarditis (2025) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/myocarditis-and-pericarditis/',
          'ESC — Myocarditis and Pericarditis guideline DOI (2025) — https://doi.org/10.1093/eurheartj/ehaf192',
          'ESC — Guideline release and implementation overview (2025) — https://www.escardio.org/news/press/press-releases/New-Guidelines-for-myocarditis-and-pericarditis-aim-to-improve-diagnosis-and-treatment-and-help-patients-return-to-exercise-and-work-more-quickly/',
        ];

      case 'pericarditis':
        return const <String>[
          'ESC — Guidelines for the Management of Myocarditis and Pericarditis (2025) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/myocarditis-and-pericarditis/',
          'ESC — Myocarditis and Pericarditis guideline DOI (2025) — https://doi.org/10.1093/eurheartj/ehaf192',
          'ESC — Patient guideline resources for Myocarditis and Pericarditis (2025) — https://www.escardio.org/guidelines/clinical-practice-guidelines/guidelines-for-patients/',
        ];

      case 'peripheral_artery_disease':
        return const <String>[
          'ACC/AHA Multisociety — Guideline for the Management of Lower Extremity Peripheral Artery Disease (2024) — https://professional.heart.org/en/science-news/2024-guideline-for-the-management-of-lower-extremity-peripheral-artery-disease',
          'AHA — 2024 Peripheral Artery Disease Guideline Hub (2024) — https://professional.heart.org/en/guidelines-statements/2024-accahaaacvprapmaabcscaisvmsvnsvssirvess-guideline-for-the-management-ofcir0000000000001251',
          'ACC/AHA Multisociety — Full PAD guideline DOI (2024) — https://doi.org/10.1161/CIR.0000000000001251',
        ];

      case 'acute_aortic_syndrome':
        return const <String>[
          'ESC — Guidelines for the Management of Peripheral Arterial and Aortic Diseases (2024) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/peripheral-arterial-and-aortic-diseases/',
          'ACC/AHA — Guideline for the Diagnosis and Management of Aortic Disease (2022) — https://professional.heart.org/en/science-news/2022-guideline-for-the-diagnosis-and-management-of-aortic-disease',
          'ACC/AHA — Full Aortic Disease guideline DOI (2022) — https://doi.org/10.1161/CIR.0000000000001106',
        ];

      case 'hypertrophic_cardiomyopathy':
        return const <String>[
          'AHA/ACC/AMSSM/HRS/PACES/SCMR — Guideline for the Management of Hypertrophic Cardiomyopathy (2024; reaffirmed current 2025) — https://professional.heart.org/en/science-news/2024-guideline-for-the-management-of-hypertrophic-cardiomyopathy',
          'AHA — 2024 Hypertrophic Cardiomyopathy Guideline Hub — https://professional.heart.org/en/guidelines-statements/2024-ahaaccamssmhrspacesscmr-guideline-for-the-management-of-hypertrophiccir0000000000001250',
          'AHA — Top Things to Know: Hypertrophic Cardiomyopathy Guideline (2024) — https://professional.heart.org/en/science-news/2024-guideline-for-the-management-of-hypertrophic-cardiomyopathy/top-things-to-know',
        ];

      case 'infective_endocarditis':
        return const <String>[
          'ESC — Guidelines for the Management of Endocarditis (2023) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/endocarditis/',
          'ESC — Endocarditis guideline DOI (2023) — https://doi.org/10.1093/eurheartj/ehad193',
          'PubMed — ESC Endocarditis guideline record (2023) — https://pubmed.ncbi.nlm.nih.gov/37622656/',
        ];

      case 'bacterial_meningitis':
        return const <String>[
          'WHO — Guidelines on Meningitis Diagnosis, Treatment and Care (2025) — https://www.who.int/publications/i/item/9789240108042',
          'WHO — Practical Manual on Meningitis Diagnosis, Treatment and Care (2026) — https://www.who.int/publications/i/item/9789240121027',
          'WHO — Executive Summary of Meningitis Guidelines (2025) — https://www.who.int/publications/i/item/B09452',
        ];

      case 'h_pylori':
        return const <String>[
          'ACG — Clinical Guideline: Treatment of Helicobacter pylori Infection (2024) — https://gi.org/journals-publications/ebgi/schoenfeld_sep2024/',
          'PubMed — ACG H. pylori guideline record (2024) — https://pubmed.ncbi.nlm.nih.gov/39626064/',
          'ACG — Full H. pylori guideline DOI (2024) — https://doi.org/10.14309/ajg.0000000000002968',
        ];

      case 'upper_gi_bleeding':
        return const <String>[
          'ACG — Upper Gastrointestinal and Ulcer Bleeding Guideline (2021; current ACG listing) — https://gi.org/guidelines/',
          'PubMed — ACG Upper Gastrointestinal and Ulcer Bleeding guideline record (2021) — https://pubmed.ncbi.nlm.nih.gov/33929377/',
          'ACG — Full Upper GI Bleeding guideline DOI (2021) — https://doi.org/10.14309/ajg.0000000000001245',
        ];

      case 'acute_appendicitis':
        return const <String>[
          'WSES — Diagnosis and Treatment of Acute Appendicitis: Jerusalem Guidelines Update (2020) — https://wjes.biomedcentral.com/articles/10.1186/s13017-020-00306-3',
          'PubMed — WSES Acute Appendicitis guideline record (2020) — https://pubmed.ncbi.nlm.nih.gov/32295644/',
          'WSES — Acute Appendicitis guideline DOI (2020) — https://doi.org/10.1186/s13017-020-00306-3',
        ];

      case 'acute_cholecystitis':
        return const <String>[
          'WSES — Updated Guidelines for Acute Calculous Cholecystitis (2020) — https://wjes.biomedcentral.com/articles/10.1186/s13017-020-00336-x',
          'PubMed — WSES Acute Calculous Cholecystitis guideline record (2020) — https://pubmed.ncbi.nlm.nih.gov/33153472/',
          'WSES — Acute Calculous Cholecystitis guideline DOI (2020) — https://doi.org/10.1186/s13017-020-00336-x',
        ];

      case 'acute_cholangitis':
        return const <String>[
          'Tokyo Guidelines — Initial Management and Flowchart for Acute Cholangitis (TG18) — https://pubmed.ncbi.nlm.nih.gov/28941329/',
          'Tokyo Guidelines — Acute Cholangitis initial management DOI (2018) — https://doi.org/10.1002/jhbp.509',
          'Tokyo Guidelines — Antimicrobial Therapy for Acute Cholangitis and Cholecystitis (TG18) — https://pubmed.ncbi.nlm.nih.gov/29090866/',
        ];

      case 'acute_diverticulitis':
        return const <String>[
          'ACP — Diagnosis and Management of Acute Left-Sided Colonic Diverticulitis (2022; current ACP guideline) — https://www.acponline.org/clinical_information/guidelines/',
          'PubMed — ACP Acute Diverticulitis guideline record (2022) — https://pubmed.ncbi.nlm.nih.gov/35038273/',
          'ACP — Full Acute Diverticulitis guideline DOI (2022) — https://doi.org/10.7326/M21-2710',
        ];

      case 'rheumatoid_arthritis':
        return const <String>[
          'EULAR — Rheumatoid Arthritis pharmacologic management: 2025 update (published 2026) — https://www.eular.org/recommendations-management',
          'PubMed — EULAR Rheumatoid Arthritis 2025 update (2026) — https://pubmed.ncbi.nlm.nih.gov/41826212/',
          'EULAR — Rheumatoid Arthritis 2025 update DOI — https://doi.org/10.1016/j.ard.2026.01.023',
        ];

      case 'systemic_lupus_erythematosus':
        return const <String>[
          'ACR — Systemic Lupus Erythematosus Guideline (2025) — https://rheumatology.org/lupus-guideline',
          'PubMed — ACR Systemic Lupus Erythematosus Guideline (2025) — https://pubmed.ncbi.nlm.nih.gov/41182321/',
          'ACR — Systemic Lupus Erythematosus Guideline DOI — https://doi.org/10.1002/acr.25690',
        ];

      case 'lupus_nephritis':
        return const <String>[
          'ACR — Lupus Nephritis Guideline (2024; final publication 2025) — https://rheumatology.org/lupus-guideline',
          'KDIGO — Clinical Practice Guideline for Lupus Nephritis (2024) — https://kdigo.org/guidelines/lupus-nephritis/',
          'PubMed — ACR Lupus Nephritis Guideline record — https://pubmed.ncbi.nlm.nih.gov/40127995/',
        ];

      case 'gout':
        return const <String>[
          'ACR — Guideline for the Management of Gout (2020; current ACR guideline) — https://rheumatology.org/gout-guideline',
          'PubMed — ACR Gout Guideline record — https://pubmed.ncbi.nlm.nih.gov/32391934/',
          'ACR — Gout Guideline DOI — https://doi.org/10.1002/acr.24180',
        ];

      case 'osteoarthritis':
        return const <String>[
          'ACR/Arthritis Foundation — Osteoarthritis of Hand, Hip and Knee Guideline (2019; current ACR guideline) — https://rheumatology.org/osteoarthritis-guideline',
          'PubMed — ACR/AF Osteoarthritis Guideline record — https://pubmed.ncbi.nlm.nih.gov/31908149/',
          'ACR/AF — Osteoarthritis Guideline DOI — https://doi.org/10.1002/acr.24131',
        ];

      case 'psoriatic_arthritis':
        return const <String>[
          'EULAR — Psoriatic Arthritis pharmacologic management: 2023 update — https://www.eular.org/recommendations-management',
          'PMC — EULAR Psoriatic Arthritis 2023 update — https://pmc.ncbi.nlm.nih.gov/articles/PMC11103320/',
          'EULAR — Psoriatic Arthritis 2023 update DOI — https://doi.org/10.1136/ard-2024-225531',
        ];

      case 'axial_spondyloarthritis':
        return const <String>[
          'ASAS/EULAR — Axial Spondyloarthritis management: 2022 update — https://www.eular.org/recommendations-management',
          'PubMed — ASAS/EULAR Axial Spondyloarthritis 2022 update — https://pubmed.ncbi.nlm.nih.gov/36270658/',
          'ASAS/EULAR — Axial Spondyloarthritis DOI — https://doi.org/10.1136/ard-2022-223296',
        ];

      case 'systemic_sclerosis':
        return const <String>[
          'EULAR — Systemic Sclerosis treatment: 2023 update — https://www.eular.org/recommendations-management',
          'PubMed — EULAR Systemic Sclerosis 2023 update — https://pubmed.ncbi.nlm.nih.gov/39874231/',
          'EULAR — Systemic Sclerosis 2023 update DOI — https://doi.org/10.1136/ard-2024-226430',
        ];

      case 'anca_associated_vasculitis':
        return const <String>[
          'EULAR — ANCA-associated Vasculitis management: 2022 update — https://www.eular.org/recommendations-management',
          'PubMed — EULAR ANCA-associated Vasculitis 2022 update — https://pubmed.ncbi.nlm.nih.gov/36927642/',
          'EULAR — ANCA-associated Vasculitis DOI — https://doi.org/10.1136/ard-2022-223764',
        ];

      case 'giant_cell_arteritis':
        return const <String>[
          'ACR/Vasculitis Foundation — Giant Cell Arteritis and Takayasu Arteritis Guideline (2021) — https://rheumatology.org/vasculitis-guideline',
          'PubMed — ACR/VF Giant Cell Arteritis Guideline — https://pubmed.ncbi.nlm.nih.gov/34235871/',
          'ACR/VF — Giant Cell Arteritis Guideline DOI — https://doi.org/10.1002/acr.24632',
        ];

      case 'sjogren_syndrome':
        return const <String>[
          'EULAR — Sjögren Syndrome management recommendations (2019; published 2020) — https://www.eular.org/recommendations-management',
          'PubMed — EULAR Sjögren Syndrome recommendations — https://pubmed.ncbi.nlm.nih.gov/31672775/',
          'EULAR — Sjögren Syndrome recommendations DOI — https://doi.org/10.1136/annrheumdis-2019-216114',
        ];

      case 'antiphospholipid_syndrome':
        return const <String>[
          'EULAR — Antiphospholipid Syndrome management recommendations (2019; current EULAR management guidance) — https://www.eular.org/recommendations-management',
          'PubMed — EULAR Antiphospholipid Syndrome recommendations — https://pubmed.ncbi.nlm.nih.gov/31092409/',
          'EULAR — Antiphospholipid Syndrome recommendations DOI — https://doi.org/10.1136/annrheumdis-2019-215213',
        ];

      case 'behcet_syndrome':
        return const <String>[
          'EULAR — Behçet Syndrome: 2025 update (published 2026) — https://www.eular.org/recommendations-management',
          'PubMed — EULAR Behçet Syndrome 2025 update — https://pubmed.ncbi.nlm.nih.gov/41876291/',
          'EULAR — Behçet Syndrome 2025 update DOI — https://doi.org/10.1016/j.ard.2026.02.009',
        ];

      case 'polymyalgia_rheumatica':
        return const <String>[
          'EULAR/ACR — Polymyalgia Rheumatica management recommendations (2015; current collaborative guidance) — https://www.eular.org/recommendations-eular-acr',
          'PubMed — EULAR/ACR Polymyalgia Rheumatica recommendations — https://pubmed.ncbi.nlm.nih.gov/26352874/',
          'EULAR/ACR — Polymyalgia Rheumatica recommendations DOI — https://doi.org/10.1002/art.39333',
        ];

      case 'still_disease':
        return const <String>[
          'EULAR/PReS — Diagnosis and Management of Still Disease (2024) — https://www.eular.org/recommendations-management',
          'PubMed — EULAR/PReS Still Disease recommendations — https://pubmed.ncbi.nlm.nih.gov/39317417/',
          'EULAR/PReS — Still Disease recommendations DOI — https://doi.org/10.1136/ard-2024-225851',
        ];

      case 'gastroesophageal_reflux_disease':
        return const <String>[
          'ACG — Clinical Guideline for Diagnosis and Management of GERD (2022) — https://pubmed.ncbi.nlm.nih.gov/34807007/',
          'PMC — ACG GERD Guideline full-text archive (2022) — https://pmc.ncbi.nlm.nih.gov/articles/PMC8754510/',
          'ACG — GERD Guideline DOI (2022) — https://doi.org/10.14309/ajg.0000000000001538',
        ];

      case 'barrett_esophagus':
        return const <String>[
          'ACG — Updated Guideline: Diagnosis and Management of Barrett Esophagus (2022) — https://pubmed.ncbi.nlm.nih.gov/35354777/',
          'PMC — Updated ACG Barrett Esophagus Guideline full-text archive (2022) — https://pmc.ncbi.nlm.nih.gov/articles/PMC10259184/',
          'ACG — Barrett Esophagus Guideline DOI (2022) — https://doi.org/10.14309/ajg.0000000000001680',
        ];

      case 'eosinophilic_esophagitis':
        return const <String>[
          'ACG — Clinical Guideline: Diagnosis and Management of Eosinophilic Esophagitis (2025) — https://gi.org/topics/eosinophilic-esophagitis/',
          'PubMed — ACG Eosinophilic Esophagitis Guideline (2025) — https://pubmed.ncbi.nlm.nih.gov/39745304/',
          'ACG — Eosinophilic Esophagitis Guideline DOI (2025) — https://doi.org/10.14309/ajg.0000000000003194',
        ];

      case 'ulcerative_colitis':
        return const <String>[
          'ACG — Clinical Guideline Update: Ulcerative Colitis in Adults (2025) — https://gi.org/journals-publications/ebgi/alkazzi_aug2025/',
          'PubMed — ACG Ulcerative Colitis in Adults Guideline (2025) — https://pubmed.ncbi.nlm.nih.gov/40701556/',
          'ACG — Ulcerative Colitis Guideline DOI (2025) — https://doi.org/10.14309/ajg.0000000000003463',
        ];

      case 'crohn_disease':
        return const <String>[
          'ACG — Clinical Guideline: Management of Crohn Disease in Adults (2025) — https://gi.org/journals-publications/ebgi/zhai_dalal_sep2025/',
          'PubMed — ACG Crohn Disease in Adults Guideline (2025) — https://pubmed.ncbi.nlm.nih.gov/40701562/',
          'ACG — Crohn Disease Guideline DOI (2025) — https://doi.org/10.14309/ajg.0000000000003465',
        ];

      case 'celiac_disease':
        return const <String>[
          'ACG — Guidelines Update: Diagnosis and Management of Celiac Disease (2023) — https://gi.org/guidelines/',
          'PubMed — ACG Celiac Disease Guideline Update (2023) — https://pubmed.ncbi.nlm.nih.gov/36602836/',
          'ACG — Celiac Disease Guideline DOI (2023) — https://doi.org/10.14309/ajg.0000000000002075',
        ];

      case 'irritable_bowel_syndrome':
        return const <String>[
          'ACG — Clinical Guideline: Management of Irritable Bowel Syndrome (2021; current ACG guideline) — https://gi.org/guidelines/',
          'PubMed — ACG Irritable Bowel Syndrome Guideline (2021) — https://pubmed.ncbi.nlm.nih.gov/33315591/',
          'ACG — Irritable Bowel Syndrome Guideline DOI (2021) — https://doi.org/10.14309/ajg.0000000000001036',
        ];

      case 'chronic_idiopathic_constipation':
        return const <String>[
          'AGA/ACG — Pharmacological Management of Chronic Idiopathic Constipation (2023) — https://gastro.org/clinical-guidance/pharmacological-management-of-chronic-idiopathic-constipation-cic/',
          'PubMed — AGA/ACG Chronic Idiopathic Constipation Guideline (2023) — https://pubmed.ncbi.nlm.nih.gov/37211380/',
          'AGA/ACG — Chronic Idiopathic Constipation Guideline DOI (2023) — https://doi.org/10.1053/j.gastro.2023.03.214',
        ];

      case 'masld_mash':
        return const <String>[
          'AASLD — Clinical Assessment and Management of MASLD/MASH, including 2025 therapy updates — https://www.aasld.org/practice-guidelines/clinical-assessment-and-management-metabolic-dysfunction-associated-steatotic',
          'PubMed — AASLD Practice Guidance on fatty liver disease underlying current MASLD framework (2023) — https://pubmed.ncbi.nlm.nih.gov/36727674/',
          'AASLD — Practice Guidance DOI (2023; with subsequent MASLD/MASH updates) — https://doi.org/10.1097/HEP.0000000000000323',
        ];

      case 'cirrhosis_portal_hypertension':
        return const <String>[
          'AASLD — Risk Stratification and Management of Portal Hypertension and Varices in Cirrhosis (2024) — https://www.aasld.org/practice-guidelines/portal-hypertension-bleeding-cirrhosis',
          'PubMed — AASLD Portal Hypertension and Varices Practice Guidance (2024) — https://pubmed.ncbi.nlm.nih.gov/37870298/',
          'Baveno VII — Renewing Consensus in Portal Hypertension (2022) — https://doi.org/10.1016/j.jhep.2021.12.022',
        ];

      case 'ascites_sbp_hrs':
        return const <String>[
          'AASLD — Ascites, Spontaneous Bacterial Peritonitis and Hepatorenal Syndrome Guidance (2021; current AASLD guidance) — https://www.aasld.org/practice-guidelines/diagnosis-evaluation-and-management-ascites-spontaneous-bacterial-peritonitis',
          'PubMed — AASLD Ascites/SBP/HRS Practice Guidance (2021) — https://pubmed.ncbi.nlm.nih.gov/33942342/',
          'AASLD — Ascites/SBP/HRS Practice Guidance DOI (2021) — https://doi.org/10.1002/hep.31884',
        ];

      case 'hepatic_encephalopathy':
        return const <String>[
          'ACG — Clinical Guideline: Hepatic Encephalopathy (2026) — https://gi.org/guidelines/',
          'PubMed — ACG Hepatic Encephalopathy Guideline (2026) — https://pubmed.ncbi.nlm.nih.gov/41773757/',
          'ACG — Hepatic Encephalopathy Guideline DOI (2026) — https://doi.org/10.14309/ajg.0000000000003899',
        ];

      case 'hepatocellular_carcinoma':
        return const <String>[
          'AASLD — Prevention, Diagnosis and Treatment of Hepatocellular Carcinoma Practice Guidance (2023; current AASLD guidance) — https://www.aasld.org/practice-guidelines/management-hepatocellular-carcinoma',
          'PubMed — AASLD Hepatocellular Carcinoma Practice Guidance (2023) — https://pubmed.ncbi.nlm.nih.gov/37199193/',
          'AASLD — Hepatocellular Carcinoma Practice Guidance DOI (2023) — https://doi.org/10.1097/HEP.0000000000000466',
        ];

      case 'chronic_hepatitis_b':
        return const <String>[
          'AASLD/IDSA — Practice Guideline on Treatment of Chronic Hepatitis B (2025; journal issue 2026) — https://www.aasld.org/practice-guidelines/hepatitis-b',
          'PubMed — AASLD/IDSA Chronic Hepatitis B Practice Guideline (2025/2026) — https://pubmed.ncbi.nlm.nih.gov/41186418/',
          'AASLD/IDSA — Chronic Hepatitis B Guideline DOI — https://doi.org/10.1097/HEP.0000000000001549',
        ];

      case 'hepatitis_c':
        return const <String>[
          'AASLD/IDSA — Hepatitis C Guidance (living guidance; 2023 published update) — https://www.aasld.org/practice-guidelines/hepatitis-c',
          'IDSA — AASLD/IDSA HCV Guidance 2023 Update — https://www.idsociety.org/practice-guideline/hcv-guidance/',
          'PubMed — AASLD/IDSA Hepatitis C Guidance 2023 Update — https://pubmed.ncbi.nlm.nih.gov/37229695/',
        ];

      case 'hypothyroidism':
        return const <String>[
          'ATA — Guidelines for Treatment of Hypothyroidism (2014; current ATA replacement guidance) — https://www.thyroid.org/new-hypothyroidism-treatment-guidelines-from-american-thyroid-association-published-in-thyroid-journal/',
          'ATA — Professional Guidelines and Statements catalog — https://www.thyroid.org/professionals/ata-professional-guidelines/',
          'ATA — Adult Hypothyroidism clinical resource — https://www.thyroid.org/hypothyroidism/',
        ];

      case 'hyperthyroidism_graves':
        return const <String>[
          'ATA — Guidelines for Diagnosis and Management of Hyperthyroidism and Thyrotoxicosis (2016; current ATA guideline) — https://www.thyroid.org/guidelines-hyperthyroidism-thyrotoxicosis/',
          'ATA — Professional Guidelines and Statements catalog — https://www.thyroid.org/professionals/ata-professional-guidelines/',
          'ATA — Graves Disease clinical resource — https://www.thyroid.org/graves-disease/',
        ];

      case 'differentiated_thyroid_cancer':
        return const <String>[
          'ATA — Management Guidelines for Adult Differentiated Thyroid Cancer (2025) — https://www.thyroid.org/new-ata-guidelines-adult-patients-differentiated-thyroid-cancer/',
          'PubMed — 2025 ATA Differentiated Thyroid Cancer Guideline — https://pubmed.ncbi.nlm.nih.gov/40844370/',
          'ATA — Differentiated Thyroid Cancer Guideline DOI (2025) — https://doi.org/10.1177/10507256251363120',
        ];

      case 'thyroid_disease_pregnancy':
        return const <String>[
          'ATA — Guidelines for Thyroid Disease in Preconception, Pregnancy and Postpartum (2026) — https://www.thyroid.org/professionals/ata-professional-guidelines/',
          'ATA — Thyroid Disease in Pregnancy clinical resources — https://www.thyroid.org/thyroid-disease-pregnancy/',
          'ATA — 2026 Pregnancy/Postpartum Guideline DOI — https://doi.org/10.1177/10507256261445624',
        ];

      case 'primary_adrenal_insufficiency':
        return const <String>[
          'Endocrine Society — Primary Adrenal Insufficiency Clinical Practice Guideline — https://www.endocrine.org/clinical-practice-guidelines/primary-adrenal-insufficiency',
          'PubMed — Endocrine Society Primary Adrenal Insufficiency Guideline (2016) — https://pubmed.ncbi.nlm.nih.gov/26760044/',
          'Endocrine Society — Primary Adrenal Insufficiency Guideline DOI — https://doi.org/10.1210/jc.2015-1710',
        ];

      case 'cushing_syndrome':
        return const <String>[
          'Endocrine Society — Treatment of Cushing Syndrome Clinical Practice Guideline — https://www.endocrine.org/clinical-practice-guidelines/treatment-of-cushing-syndrome',
          'PubMed — Endocrine Society Treatment of Cushing Syndrome Guideline — https://pubmed.ncbi.nlm.nih.gov/26222757/',
          'Endocrine Society — Cushing Syndrome Guideline DOI — https://doi.org/10.1210/jc.2015-1818',
        ];

      case 'primary_aldosteronism':
        return const <String>[
          'Endocrine Society — Primary Aldosteronism Clinical Practice Guideline (2025) — https://www.endocrine.org/clinical-practice-guidelines/primary-aldosteronism-2',
          'Endocrine Society — Primary Aldosteronism guideline resources (2025) — https://www.endocrine.org/clinical-practice-guidelines',
          'PubMed — Primary Aldosteronism Endocrine Society 2025 guideline search — https://pubmed.ncbi.nlm.nih.gov/?term=Primary+Aldosteronism+Endocrine+Society+2025+Guideline',
        ];

      case 'pheochromocytoma_paraganglioma':
        return const <String>[
          'Endocrine Society — Pheochromocytoma and Paraganglioma Clinical Practice Guideline — https://www.endocrine.org/clinical-practice-guidelines/pheochromocytoma-and-paraganglioma',
          'PubMed — Endocrine Society Pheochromocytoma/Paraganglioma Guideline — https://pubmed.ncbi.nlm.nih.gov/24893135/',
          'Endocrine Society — Pheochromocytoma/Paraganglioma Guideline DOI — https://doi.org/10.1210/jc.2014-1498',
        ];

      case 'osteoporosis':
        return const <String>[
          'Endocrine Society — Pharmacological Management of Osteoporosis in Postmenopausal Women — https://www.endocrine.org/clinical-practice-guidelines/osteoporosis-in-postmenopausal-women',
          'PubMed — Endocrine Society Osteoporosis Guideline Update search — https://pubmed.ncbi.nlm.nih.gov/?term=Endocrine+Society+osteoporosis+guideline+romosozumab+2020',
          'Endocrine Society — Osteoporosis Guideline Update DOI — https://doi.org/10.1210/clinem/dgaa048',
        ];

      case 'primary_hyperparathyroidism':
        return const <String>[
          'Fifth International Workshop — Evaluation and Management of Primary Hyperparathyroidism (2022) — https://pubmed.ncbi.nlm.nih.gov/36245251/',
          'JBMR — Primary Hyperparathyroidism Workshop Guideline DOI (2022) — https://doi.org/10.1002/jbmr.4677',
          'PubMed — Primary Hyperparathyroidism Fifth Workshop guideline search — https://pubmed.ncbi.nlm.nih.gov/?term=Fifth+International+Workshop+Primary+Hyperparathyroidism+2022+guidelines',
        ];

      case 'hypoparathyroidism':
        return const <String>[
          'International Task Force — Hypoparathyroidism Guidelines update (2022) — https://pubmed.ncbi.nlm.nih.gov/?term=Hypoparathyroidism+International+Task+Force+2022+guidelines',
          'JBMR — Hypoparathyroidism International Task Force Guideline DOI (2022) — https://doi.org/10.1002/jbmr.4691',
          'Endocrine Society — Hypoparathyroidism clinical resource — https://www.endocrine.org/patient-engagement/endocrine-library/hypoparathyroidism',
        ];

      case 'obesity_pharmacotherapy':
        return const <String>[
          'AGA — Pharmacological Interventions for Adults With Obesity Guideline (2022) — https://gastro.org/clinical-guidance/pharmacological-interventions-for-adults-with-obesity/',
          'PubMed — AGA Pharmacological Interventions for Adults With Obesity Guideline — https://pubmed.ncbi.nlm.nih.gov/?term=AGA+Guideline+Pharmacological+Interventions+Adults+Obesity+2022',
          'AGA — Obesity Pharmacotherapy Guideline DOI — https://doi.org/10.1053/j.gastro.2022.08.045',
        ];

      case 'polycystic_ovary_syndrome':
        return const <String>[
          'International Evidence-based Guideline for PCOS (2023) — https://www.monash.edu/medicine/mchri/pcos/guideline',
          'Monash — International Evidence-based PCOS Guideline PDF (2023) — https://www.monash.edu/__data/assets/pdf_file/0003/3379521/Evidence-Based-Guidelines-2023.pdf',
          'PubMed — International PCOS Guideline 2023 search — https://pubmed.ncbi.nlm.nih.gov/?term=International+Evidence-based+Guideline+PCOS+2023',
        ];

      case 'acromegaly':
        return const <String>[
          'Endocrine Society — Acromegaly Clinical Practice Guideline — https://www.endocrine.org/clinical-practice-guidelines/acromegaly',
          'PubMed — Endocrine Society Acromegaly Guideline — https://pubmed.ncbi.nlm.nih.gov/25356808/',
          'Endocrine Society — Acromegaly Guideline DOI — https://doi.org/10.1210/jc.2014-2700',
        ];

      case 'hyperprolactinemia_prolactinoma':
        return const <String>[
          'Pituitary Society — International Consensus Statement on Diagnosis and Management of Prolactinomas (2023) — https://www.nature.com/articles/s41574-023-00886-5',
          'PubMed — Pituitary Society Prolactinoma International Consensus Statement (2023) — https://pubmed.ncbi.nlm.nih.gov/37670148/',
          'Pituitary Society — Prolactinoma International Consensus Statement DOI (2023) — https://doi.org/10.1038/s41574-023-00886-5',
          'Endocrine Society / Pituitary Society — Diagnosis and Treatment of Hyperprolactinemia Guideline (2011; complementary broader hyperprolactinemia guidance) — https://www.endocrine.org/clinical-practice-guidelines/hyperprolactinemia',
        ];

      case 'hiv_antiretroviral_therapy':
        return const <String>[
          'NIH/DHHS — Guidelines for the Use of Antiretroviral Agents in Adults and Adolescents With HIV (updated 2026) — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-arv',
          'NIH/DHHS — What Is New in Adult and Adolescent ARV Guidelines (2026) — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-arv/whats-new?view=full',
          'NIH/DHHS — Adult and Adolescent ARV Guideline Panel Roster / current guideline framework (2026) — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-arv/panel-roster?view=full',
        ];

      case 'hiv_opportunistic_infections':
        return const <String>[
          'NIH/CDC/HIVMA — Guidelines for Prevention and Treatment of Opportunistic Infections in Adults and Adolescents With HIV (reviewed 2026) — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-opportunistic-infections',
          'NIH/CDC/HIVMA — What Is New in Adult and Adolescent OI Guidelines (2026) — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-opportunistic-infections/whats-new?view=full',
          'NIH/CDC/HIVMA — Treatment of HIV-Associated Opportunistic Infections Table (2026) — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-opportunistic-infections/treatment-hiv-associated',
        ];

      case 'hiv_prep':
        return const <String>[
          'CDC HIV Nexus — Clinical Guidance for PrEP (updated 2026) — https://www.cdc.gov/hivnexus/hcp/prep/index.html',
          'CDC — HIV Nexus Clinical Resources for Health Care Providers (current 2026) — https://www.cdc.gov/hivnexus/hcp/index.html',
          'CDC — HIV Prevention / PrEP public health resource (current 2026) — https://www.cdc.gov/hiv/prevention/prep.html',
        ];

      case 'hiv_pep':
        return const <String>[
          'CDC — Nonoccupational HIV Postexposure Prophylaxis Recommendations (2025) — https://www.cdc.gov/mmwr/volumes/74/rr/rr7401a1.htm',
          'CDC HIV Nexus — Clinical Guidance for PEP (current) — https://www.cdc.gov/hivnexus/hcp/pep/index.html',
          'CDC — 2025 nPEP Recommendations DOI — https://doi.org/10.15585/mmwr.rr7401a1',
        ];

      case 'tuberculosis':
        return const <String>[
          'WHO — Consolidated Guidelines on Tuberculosis, Module 4: Treatment and Care (2025) — https://www.who.int/publications/i/item/9789240107243',
          'WHO — Consolidated Guidelines on Tuberculosis, Module 3: Diagnosis (2025) — https://www.who.int/publications/i/item/9789240107984',
          'WHO — Operational Handbook on Tuberculosis, Module 3: Diagnosis (2025) — https://www.who.int/publications/i/item/9789240110991',
        ];

      case 'malaria':
        return const <String>[
          'WHO — Guidelines for Malaria (2025) — https://www.who.int/publications/i/item/guidelines-for-malaria/',
          'WHO Global Malaria Programme — Consolidated Malaria Guidelines (2025) — https://www.who.int/teams/global-malaria-programme/guidelines-for-malaria',
          'WHO — Guidelines for Malaria reference DOI (2025) — https://doi.org/10.2471/B09514',
        ];

      case 'arboviral_disease':
        return const <String>[
          'WHO — Guidelines for Clinical Management of Arboviral Diseases: Dengue, Chikungunya, Zika and Yellow Fever (2025) — https://www.who.int/publications/i/item/9789240111110',
          'WHO — Arboviral Diseases Guideline publication record (2025) — https://www.who.int/publications/b/79410',
          'WHO — Guideline Development Group for Dengue, Chikungunya, Zika and Yellow Fever (2025) — https://www.who.int/groups/guideline-development-group-guidelines-for-clinical-management-of-dengue-chikungunya-zika-and-yellow-fever',
        ];

      case 'syphilis':
        return const <String>[
          'CDC — Syphilis: STI Treatment Guidelines (2021; current CDC treatment guideline with 2026 updates) — https://www.cdc.gov/std/treatment-guidelines/syphilis.htm',
          'CDC — Sexually Transmitted Infections Treatment Guidelines (2021) — https://www.cdc.gov/mmwr/volumes/70/rr/rr7004a1.htm',
          'CDC — STI Screening Recommendations including Syphilis (current review) — https://www.cdc.gov/std/treatment-guidelines/screening-recommendations.htm',
        ];

      case 'gonorrhea':
        return const <String>[
          'CDC — Gonococcal Infections Among Adolescents and Adults: STI Treatment Guidelines (2021) — https://www.cdc.gov/std/treatment-guidelines/gonorrhea-adults.htm',
          'CDC — Sexually Transmitted Infections Treatment Guidelines (2021) — https://www.cdc.gov/mmwr/volumes/70/rr/rr7004a1.htm',
          'CDC — STI Screening Recommendations including Gonorrhea (current review) — https://www.cdc.gov/std/treatment-guidelines/screening-recommendations.htm',
        ];

      case 'chlamydia':
        return const <String>[
          'CDC — Chlamydial Infections: STI Treatment Guidelines (2021) — https://www.cdc.gov/std/treatment-guidelines/chlamydia.htm',
          'CDC — Sexually Transmitted Infections Treatment Guidelines (2021) — https://www.cdc.gov/mmwr/volumes/70/rr/rr7004a1.htm',
          'CDC — STI Screening Recommendations including Chlamydia (current review) — https://www.cdc.gov/std/treatment-guidelines/screening-recommendations.htm',
        ];

      case 'genital_herpes':
        return const <String>[
          'CDC — Genital Herpes: STI Treatment Guidelines (2021) — https://www.cdc.gov/std/treatment-guidelines/herpes.htm',
          'CDC — Sexually Transmitted Infections Treatment Guidelines (2021) — https://www.cdc.gov/mmwr/volumes/70/rr/rr7004a1.htm',
          'CDC — STI Screening Recommendations including Herpes (current review) — https://www.cdc.gov/std/treatment-guidelines/screening-recommendations.htm',
        ];

      case 'pelvic_inflammatory_disease':
        return const <String>[
          'CDC — Pelvic Inflammatory Disease: STI Treatment Guidelines (2021) — https://www.cdc.gov/std/treatment-guidelines/pid.htm',
          'CDC — Sexually Transmitted Infections Treatment Guidelines (2021) — https://www.cdc.gov/mmwr/volumes/70/rr/rr7004a1.htm',
          'CDC — Chlamydial Infections: STI Treatment Guidelines (2021; PID-linked pathogen guidance) — https://www.cdc.gov/std/treatment-guidelines/chlamydia.htm',
        ];

      case 'clostridioides_difficile':
        return const <String>[
          'SHEA/IDSA — Focused Update for Management of Clostridioides difficile Infection in Adults (2021) — https://www.idsociety.org/practice-guideline/clostridioides-difficile-2021-focused-update/',
          'SHEA/IDSA — Clostridioides difficile Focused Update DOI (2021) — https://doi.org/10.1093/cid/ciab549',
          'IDSA/SHEA — Comprehensive C. difficile Guideline baseline (2017/2018; complemented by 2021 update) — https://www.idsociety.org/practice-guideline/clostridium-difficile',
        ];

      case 'covid_19':
        return const <String>[
          'IDSA — Guidelines on Treatment and Management of Patients with COVID-19 (current 2025) — https://www.idsociety.org/practice-guideline/covid-19-guideline-treatment-and-management/',
          'IDSA — COVID-19 Guideline current landing page (2025) — https://www.idsociety.org/COVID19guidelines',
          'CDC — COVID-19 Outpatient Treatment Clinical Care (current) — https://www.cdc.gov/covid/hcp/clinical-care/outpatient-treatment.html',
        ];

      case 'influenza':
        return const <String>[
          'CDC — Influenza Antiviral Medications: Summary for Clinicians (2026) — https://www.cdc.gov/flu/hcp/antivirals/summary-clinicians.html',
          'CDC — About Influenza Antiviral Medications (2026) — https://www.cdc.gov/Flu/professionals/antivirals/',
          'IDSA — Clinical Practice Guidelines for Seasonal Influenza (2018; current comprehensive IDSA guideline) — https://www.idsociety.org/practice-guideline/influenza/',
        ];

      case 'epilepsy':
        return const <String>[
          'NICE — Epilepsies in Children, Young People and Adults NG217 (updated 2025) — https://www.nice.org.uk/guidance/ng217',
          'NICE — Diagnosis and Assessment of Epilepsy NG217 (2025) — https://www.nice.org.uk/guidance/ng217/chapter/1-Diagnosis-and-assessment-of-epilepsy',
          'NICE — Treating Epileptic Seizures NG217 (2025) — https://www.nice.org.uk/guidance/ng217/chapter/5-Treating-epileptic-seizures-in-children-young-people-and-adults',
        ];

      case 'status_epilepticus':
        return const <String>[
          'NICE — Status Epilepticus, Repeated or Cluster Seizures and Prolonged Seizures NG217 (updated 2025) — https://www.nice.org.uk/guidance/ng217/chapter/7-Treating-status-epilepticus-repeated-or-cluster-seizures-and-prolonged-seizures',
          'NICE — Epilepsies NG217 overview (updated 2025) — https://www.nice.org.uk/guidance/ng217',
          'NICE — Epilepsies NG217 update information (2025) — https://www.nice.org.uk/guidance/ng217/chapter/Update-information',
        ];

      case 'migraine':
        return const <String>[
          'ACP — Prevention of Episodic Migraine Headache Using Pharmacologic Treatments in Outpatient Settings (2025) — https://pubmed.ncbi.nlm.nih.gov/39899861/',
          'American Headache Society — CGRP-targeting Therapies as First-line Migraine Prevention (2024) — https://pubmed.ncbi.nlm.nih.gov/38466028/',
          'NICE — Headaches in Over 12s: Diagnosis and Management CG150 (updated 2025) — https://www.nice.org.uk/guidance/cg150',
        ];

      case 'parkinson_disease':
        return const <String>[
          'NICE — Parkinson Disease in Adults NG71 (current; reviewed 2024, minor update 2026) — https://www.nice.org.uk/guidance/ng71',
          'NICE — Parkinson Disease in Adults Recommendations NG71 — https://www.nice.org.uk/guidance/ng71/chapter/Recommendations',
          'NICE — Parkinson Disease in Adults Update Information NG71 (2026) — https://www.nice.org.uk/guidance/ng71/chapter/Update-information',
        ];

      case 'multiple_sclerosis':
        return const <String>[
          'NICE — Multiple Sclerosis in Adults: Management NG220 (updated 2026) — https://www.nice.org.uk/guidance/ng220',
          'NICE — Multiple Sclerosis Recommendations NG220 (2026; incorporates 2024 McDonald criteria) — https://www.nice.org.uk/guidance/ng220/chapter/Recommendations',
          'NICE — Multiple Sclerosis Update Information NG220 (2026) — https://www.nice.org.uk/guidance/ng220/chapter/Update-information',
        ];

      case 'myasthenia_gravis':
        return const <String>[
          'International Consensus Guidance — Management of Myasthenia Gravis: 2020 Update (published 2021) — https://pubmed.ncbi.nlm.nih.gov/33144515/',
          'PMC — International Consensus Guidance for Management of Myasthenia Gravis (2021) — https://pmc.ncbi.nlm.nih.gov/articles/PMC7884987/',
          'International Consensus Guidance — Myasthenia Gravis DOI (2021) — https://doi.org/10.1212/WNL.0000000000011124',
        ];

      case 'guillain_barre_syndrome':
        return const <String>[
          'EAN/PNS — Guideline on Diagnosis and Treatment of Guillain-Barré Syndrome (2023) — https://pubmed.ncbi.nlm.nih.gov/37814551/',
          'EAN/PNS — Guillain-Barré Syndrome Guideline European Journal of Neurology version (2023) — https://pubmed.ncbi.nlm.nih.gov/37814552/',
          'Peripheral Nerve Society — Published Guidelines including EAN/PNS GBS Guideline (2023) — https://pnsociety.com/resources/guidelines/',
        ];

      case 'delirium':
        return const <String>[
          'NICE — Delirium: Prevention, Diagnosis and Management CG103 (updated 2023) — https://www.nice.org.uk/guidance/cg103',
          'NICE — Delirium Recommendations CG103 (2023) — https://www.nice.org.uk/guidance/cg103/chapter/Recommendations',
          'NCBI Bookshelf — NICE Delirium Guideline (updated 2023) — https://www.ncbi.nlm.nih.gov/books/NBK553009/',
        ];

      case 'dementia_alzheimer':
        return const <String>[
          'NICE — Dementia: Assessment, Management and Support NG97 (current; reviewed 2025) — https://www.nice.org.uk/guidance/ng97',
          'NICE — Dementia NG97 Update Information (2025) — https://www.nice.org.uk/guidance/ng97/chapter/Update-information',
          'NICE — Dementia NG97 Exceptional Surveillance (2025; recommendations retained) — https://www.nice.org.uk/guidance/ng97/evidence/october-2025-exceptional-surveillance-of-dementia-assessment-management-and-support-for-people-15489519805',
        ];

      case 'neuropathic_pain':
        return const <String>[
          'NICE — Neuropathic Pain in Adults CG173 (current; updated 2020) — https://www.nice.org.uk/guidance/cg173',
          'NICE — Neuropathic Pain Pharmacological Management Recommendations CG173 (2020) — https://www.nice.org.uk/guidance/cg173/chapter/Recommendations',
          'NICE — Neuropathic Pain CG173 guideline PDF (current) — https://www.nice.org.uk/guidance/cg173/resources/neuropathic-pain-in-adults-pharmacological-management-in-nonspecialist-settings-pdf-35109750554053',
        ];

      case 'major_depressive_disorder':
        return const <String>[
          'NICE — Depression in Adults: Treatment and Management NG222 (2022; reviewed 2026 and retained) — https://www.nice.org.uk/guidance/ng222',
          'NICE — Depression in Adults Recommendations NG222 (current 2026) — https://www.nice.org.uk/guidance/ng222/chapter/Recommendations',
          'VA/DoD — Clinical Practice Guideline for Management of Major Depressive Disorder (2022) — https://www.healthquality.va.gov/HEALTHQUALITY/guidelines/MH/mdd/VADODMDDCPGFinal508.pdf',
        ];

      case 'bipolar_disorder':
        return const <String>[
          'NICE — Bipolar Disorder: Assessment and Management CG185 (updated 2025) — https://www.nice.org.uk/guidance/cg185',
          'NICE — Bipolar Disorder Recommendations CG185 (2025) — https://www.nice.org.uk/guidance/cg185/chapter/recommendations',
          'VA/DoD — Clinical Practice Guideline for Management of Bipolar Disorder (2023) — https://healthquality.va.gov/HEALTHQUALITY/guidelines/MH/bd/VA-DoD-CPG-BD-Full-CPGFinal508.pdf',
        ];

      case 'gad_panic_disorder':
        return const <String>[
          'NICE — Generalised Anxiety Disorder and Panic Disorder in Adults CG113 (current; reviewed 2024) — https://www.nice.org.uk/guidance/cg113',
          'NICE — GAD and Panic Disorder Recommendations CG113 — https://www.nice.org.uk/guidance/cg113/chapter/Recommendations',
          'NICE — GAD and Panic Disorder Evidence and Surveillance CG113 (reviewed 2024) — https://www.nice.org.uk/guidance/cg113/evidence',
        ];

      case 'schizophrenia_psychosis':
        return const <String>[
          'NICE — Psychosis and Schizophrenia in Adults CG178 (current; reviewed 2025) — https://www.nice.org.uk/guidance/cg178',
          'NICE — Psychosis and Schizophrenia Update Information CG178 (2025) — https://www.nice.org.uk/guidance/cg178/chapter/Update-information',
          'NICE — Psychosis and Schizophrenia Exceptional Surveillance (2025; guideline retained) — https://www.nice.org.uk/guidance/cg178/evidence/july-2025-exceptional-surveillance-of-psychosis-and-schizophrenia-in-adults-prevention-and-15425782525',
        ];

      case 'alcohol_withdrawal':
        return const <String>[
          'NICE — Alcohol-use Disorders: Physical Complications CG100, Acute Alcohol Withdrawal (current guidance) — https://www.nice.org.uk/guidance/cg100',
          'NICE — Acute Alcohol Withdrawal Recommendations CG100 — https://www.nice.org.uk/guidance/cg100/chapter/recommendations',
          'NICE — Alcohol-use Disorders Physical Complications guideline PDF (current resource 2026) — https://www.nice.org.uk/guidance/cg100/resources/alcoholuse-disorders-diagnosis-and-management-of-physical-complications-pdf-35109322251973',
        ];

      case 'iron_deficiency_anemia':
        return const <String>[
          'AGA — Clinical Practice Update on Management of Iron Deficiency Anemia (2024) — https://gastro.org/clinical-guidance/management-of-iron-deficiency-anemia/',
          'PubMed — AGA Clinical Practice Update on Iron Deficiency Anemia (2024) — https://pubmed.ncbi.nlm.nih.gov/38864796/',
          'AGA — Iron Deficiency Anemia Clinical Practice Update DOI (2024) — https://doi.org/10.1016/j.cgh.2024.03.046',
        ];

      case 'vitamin_b12_deficiency':
        return const <String>[
          'NICE — Vitamin B12 Deficiency in Over 16s: Diagnosis and Management NG239 (2024) — https://www.nice.org.uk/guidance/ng239',
          'NICE — Vitamin B12 Deficiency Recommendations NG239 (2024) — https://www.nice.org.uk/guidance/ng239/chapter/recommendations',
          'NICE — Vitamin B12 Deficiency Update Information NG239 (2024) — https://www.nice.org.uk/guidance/NG239/chapter/update-information',
        ];

      case 'autoimmune_hemolytic_anemia':
        return const <String>[
          'International Consensus — Diagnosis and Treatment of Autoimmune Hemolytic Anemia in Adults (2020) — https://pubmed.ncbi.nlm.nih.gov/31839434/',
          'International Consensus — Autoimmune Hemolytic Anemia DOI (2020) — https://doi.org/10.1016/j.blre.2019.100648',
          'PubMed — Warm Autoimmune Hemolytic Anemia APAC Expert Consensus (2025) — https://pubmed.ncbi.nlm.nih.gov/41210898/',
        ];

      case 'sickle_cell_disease':
        return const <String>[
          'ASH — Clinical Practice Guidelines on Sickle Cell Disease (current collection; reviewed through 2023) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/sickle-cell-disease-guidelines',
          'ASH — Sickle Cell Disease Acute and Chronic Pain Guidance (reviewed 2023) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/sickle-cell-disease-guidelines/scd-guidelines-management-of-acute-and-chronic-pain',
          'ASH — Sickle Cell Disease Cardiopulmonary and Kidney Guidance (reviewed 2023) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/sickle-cell-disease-guidelines/scd-guidelines-cardiopulmonary-and-kidney-disease',
        ];

      case 'transfusion_dependent_thalassemia':
        return const <String>[
          'TIF — Guidelines for Management of Transfusion-Dependent Beta-Thalassaemia, 5th edition (2025) — https://thalassaemia.org.cy/download/guidelines-for-the-management-of-transfusion-dependent-%CE%B2-thalassaemia-5th-edition-2025/',
          'PubMed/NCBI Bookshelf — TIF Transfusion-Dependent Beta-Thalassaemia Guidelines, 5th edition (2025) — https://pubmed.ncbi.nlm.nih.gov/40367250/',
          'PubMed — TIF Transfusion-Dependent Thalassemia Guidelines summary (2022; prior edition baseline) — https://pubmed.ncbi.nlm.nih.gov/35928543/',
        ];

      case 'immune_thrombocytopenia':
        return const <String>[
          'ASH — Clinical Practice Guidelines on Immune Thrombocytopenia (2019; current ASH guideline under annual review) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/immune-thrombocytopenia-guidelines',
          'ASH — ITP Guideline development and evidence framework (2019) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/immune-thrombocytopenia-guidelines/itp-development-process',
          'ASH — 2019 ITP guideline release and current guidance summary — https://www.hematology.org/newsroom/press-releases/2019/new-clinical-practice-guidelines-on-immune-thrombocytopenia-released',
        ];

      case 'thrombotic_thrombocytopenic_purpura':
        return const <String>[
          'ISTH — Focused Update of TTP Management Guidelines (2025) — https://pubmed.ncbi.nlm.nih.gov/40533296/',
          'ISTH — TTP Focused Update DOI (2025) — https://doi.org/10.1016/j.jtha.2025.06.002',
          'ISTH — TTP Diagnosis Guideline baseline (2020) — https://pubmed.ncbi.nlm.nih.gov/32914582/',
        ];

      case 'heparin_induced_thrombocytopenia':
        return const <String>[
          'ASH — VTE Guideline: Heparin-Induced Thrombocytopenia (2018; reviewed 2022 and retained) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/venous-thromboembolism-guidelines/heparin-induced-thrombocytopenia',
          'ASH — VTE Clinical Practice Guidelines collection including HIT (current) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/venous-thromboembolism-guidelines',
          'ASH — VTE Guidelines snapshot collection including HIT (updated 2023) — https://www.hematology.org/-/media/hematology/files/clinicians/guidelines/vte/ash-vte-guidelines_snapshot-set-2023-updated.pdf',
        ];

      case 'von_willebrand_disease':
        return const <String>[
          'ASH/ISTH/NHF/WFH — Clinical Practice Guidelines on von Willebrand Disease (2021) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/von-willebrand-disease',
          'ASH/ISTH/NHF/WFH — VWD Guideline Development Process (2021) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/von-willebrand-disease/development-process',
          'ASH/ISTH/NHF/WFH — VWD Guideline release and summary (2021) — https://www.hematology.org/newsroom/press-releases/2021/guidelines-on-the-diagnosis-and-management-of-von-willebrand-disease',
        ];

      case 'red_blood_cell_transfusion':
        return const <String>[
          'AABB — Red Blood Cell Transfusion: International Guidelines (2023) — https://www.aabb.org/news-resources/resources/clinical-practice-resources',
          'PubMed — 2023 AABB International Red Blood Cell Transfusion Guidelines — https://pubmed.ncbi.nlm.nih.gov/37824153/',
          'AABB — Red Blood Cell Transfusion Guideline DOI (2023) — https://doi.org/10.1001/jama.2023.12914',
        ];

      case 'acute_myeloid_leukemia':
        return const <String>[
          'ASH — Acute Myeloid Leukemia in Older Adults Clinical Practice Guideline (2025) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/acute-myeloid-leukemia-guidelines',
          'ASH — AML 2025 Guideline Snapshot — https://www.hematology.org/-/media/hematology/files/clinicians/guidelines/ash-guidelines-update-2025/aml-snapshot-final.pdf',
          'ASH — AML 2025 Guideline DOI — https://doi.org/10.1182/bloodadvances.2025017934',
        ];

      case 'light_chain_amyloidosis':
        return const <String>[
          'ASH — Clinical Practice Guidelines on Diagnosis of Light Chain Amyloidosis (2026) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/amyloidosis-guidelines',
          'PubMed — ASH Light Chain Amyloidosis Diagnosis Guideline (2026) — https://pubmed.ncbi.nlm.nih.gov/41592868/',
          'ASH — Light Chain Amyloidosis Guideline DOI (2026) — https://doi.org/10.1182/bloodadvances.2025017073',
        ];

      case 'multiple_myeloma':
        return const <String>[
          'EHA/EMN — Evidence-Based Guidelines for Multiple Myeloma (2025) — https://pubmed.ncbi.nlm.nih.gov/40624367/',
          'EHA/EMN — Multiple Myeloma Guideline DOI (2025) — https://doi.org/10.1038/s41571-025-01041-x',
          'Nature Reviews Clinical Oncology — EHA/EMN Multiple Myeloma Guidelines (2025) — https://www.nature.com/articles/s41571-025-01041-x',
        ];

      case 'cancer_associated_vte':
        return const <String>[
          'ASH — VTE Prevention and Treatment in Patients With Cancer (2021; current under annual review) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/venous-thromboembolism-guidelines/cancer',
          'PubMed — ASH VTE in Cancer Guidelines (2021) — https://pubmed.ncbi.nlm.nih.gov/33570602/',
          'ASH — VTE in Cancer Guideline DOI (2021) — https://doi.org/10.1182/bloodadvances.2020003442',
        ];

      case 'thrombophilia_testing':
        return const <String>[
          'ASH — VTE Guideline: Thrombophilia Testing (2023) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/venous-thromboembolism-guidelines/thrombophilia',
          'PubMed — ASH Thrombophilia Testing Guideline (2023) — https://pubmed.ncbi.nlm.nih.gov/37195076/',
          'ASH — Thrombophilia Testing Guideline DOI (2023) — https://doi.org/10.1182/bloodadvances.2023010177',
        ];

      case 'acute_kidney_injury_aki_akd':
        return const <String>[
          'KDIGO — Acute Kidney Injury Guideline (2012; current final guideline while 2026 update remains draft/public-review material) — https://kdigo.org/guidelines/acute-kidney-injury/',
          'KDIGO — Clinical Practice Guideline for Acute Kidney Injury (2012 final) — https://kdigo.org/wp-content/uploads/2016/10/KDIGO-2012-AKI-Guideline-English.pdf',
          'KDIGO — 2026 AKI/AKD Guideline Draft Available for Public Review (DRAFT, not final) — https://kdigo.org/kdigo-2026-aki-akd-guideline-draft-available-for-public-review/',
        ];

      case 'iga_nephropathy_vasculitis_2025':
        return const <String>[
          'KDIGO — IgA Nephropathy and IgA Vasculitis Guideline (2025) — https://kdigo.org/guidelines/iga-nephropathy/',
          'PubMed — KDIGO IgAN/IgAV Clinical Practice Guideline (2025) — https://pubmed.ncbi.nlm.nih.gov/40975564/',
          'KDIGO — IgAN/IgAV Guideline DOI (2025) — https://doi.org/10.1016/j.kint.2025.04.004',
        ];

      case 'adpkd_kdigo_2025':
        return const <String>[
          'KDIGO — ADPKD Clinical Practice Guideline (2025) — https://kdigo.org/guidelines/autosomal-dominant-polycystic-kidney-disease-adpkd/',
          'PubMed — KDIGO ADPKD Clinical Practice Guideline (2025) — https://pubmed.ncbi.nlm.nih.gov/39848759/',
          'KDIGO — ADPKD Guideline DOI (2025) — https://doi.org/10.1016/j.kint.2024.07.009',
        ];

      case 'anemia_ckd_kdigo_2026':
        return const <String>[
          'KDIGO — Anemia in CKD Clinical Practice Guideline (2026) — https://kdigo.org/guidelines/anemia-in-ckd/',
          'PubMed — KDIGO Anemia in CKD Guideline (2026) — https://pubmed.ncbi.nlm.nih.gov/41485812/',
          'KDIGO — Anemia in CKD Guideline DOI (2026) — https://doi.org/10.1016/j.kint.2025.06.006',
        ];

      case 'pediatric_nephrotic_syndrome_kdigo_2025':
        return const <String>[
          'KDIGO — Nephrotic Syndrome in Children Guideline (2025) — https://kdigo.org/guidelines/nephrotic-syndrome-in-children/',
          'PubMed — KDIGO Nephrotic Syndrome in Children Guideline (2025) — https://pubmed.ncbi.nlm.nih.gov/40254391/',
          'KDIGO — Nephrotic Syndrome in Children Guideline DOI (2025) — https://doi.org/10.1016/j.kint.2024.11.007',
        ];

      case 'kidney_ureteral_stones_aua_2026':
        return const <String>[
          'AUA — Surgical Management of Kidney and Ureteral Stones Guideline Part I (2026) — https://pubmed.ncbi.nlm.nih.gov/41263323/',
          'AUA — Surgical Management of Kidney and Ureteral Stones Guideline Part II (2026) — https://pubmed.ncbi.nlm.nih.gov/41263322/',
          'AUA — Surgical Management of Kidney and Ureteral Stones Guideline Part III (2026) — https://pubmed.ncbi.nlm.nih.gov/41263325/',
          'AUA — Kidney and Ureteral Stones Guideline Part I DOI (2026) — https://doi.org/10.1097/JU.0000000000004842',
        ];

      case 'hyperkalemia_ukka_2023':
        return const <String>[
          'UK Kidney Association — Management of Hyperkalaemia in Adults (2023; review due 2026) — https://www.ukkidney.org/health-professionals/guidelines/treatment-acute-hyperkalaemia-adults-0',
          'UK Kidney Association — Hyperkalaemia Clinical Practice Guideline PDF (2023) — https://www.ukkidney.org/sites/renal.org/files/FINAL%20VERSION%20-%20UKKA%20CLINICAL%20PRACTICE%20GUIDELINE%20-%20MANAGEMENT%20OF%20HYPERKALAEMIA%20IN%20ADULTS%20-%20191223_0.pdf',
          'UK Kidney Association — Hyperkalaemia in Hospital recommendations (current 2023 guideline framework) — https://guidelines.ukkidney.org/hyperkalaemia/11-1-ii-hyperkalaemia-in-hospital/11-1-9-ii-hyperkalaemia-in-hospital-21-1-21-4/',
        ];

      case 'hyponatremia_european_2014':
        return const <String>[
          'European Society of Endocrinology — Diagnosis and Treatment of Hyponatraemia Guideline (2014; current endorsed guideline) — https://www.endocrine.org/clinical-practice-guidelines/collaborated-and-endorsed-guidelines',
          'European Clinical Practice Guideline — Diagnosis and Treatment of Hyponatraemia (2014) — https://academic.oup.com/ejendo/article/170/3/G1/6668028',
          'European Hyponatraemia Guideline DOI (2014) — https://doi.org/10.1530/EJE-13-1020',
        ];

      case 'pulmonary_hypertension_esc_ers_2022':
        return const <String>[
          'ESC/ERS — Guidelines for Diagnosis and Treatment of Pulmonary Hypertension (2022; current ESC/ERS guideline) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/pulmonary-hypertension/',
          'PubMed — ESC/ERS Pulmonary Hypertension Guideline (2022) — https://pubmed.ncbi.nlm.nih.gov/36017548/',
          'ESC/ERS — Pulmonary Hypertension Guideline DOI (2022) — https://doi.org/10.1093/eurheartj/ehac237',
        ];

      case 'bronchiectasis_ers_2025':
        return const <String>[
          'ERS — Clinical Practice Guideline for Management of Adult Bronchiectasis (2025) — https://pubmed.ncbi.nlm.nih.gov/41016738/',
          'ERS — Adult Bronchiectasis Guideline DOI (2025) — https://doi.org/10.1183/13993003.01126-2025',
          'ERS — Bronchiectasis Guideline 2025 Summary and Implementation Guide (2026) — https://pubmed.ncbi.nlm.nih.gov/42259823/',
        ];

      case 'ards_ats_2024':
        return const <String>[
          'ATS — Update on Management of Adult Acute Respiratory Distress Syndrome (2024) — https://pubmed.ncbi.nlm.nih.gov/38032683/',
          'PMC — ATS ARDS Clinical Practice Guideline full text (2024) — https://pmc.ncbi.nlm.nih.gov/articles/PMC10870893/',
          'ATS — ARDS Guideline DOI (2024) — https://doi.org/10.1164/rccm.202311-2011ST',
        ];

      case 'ipf_ppf_ats_ers_2022':
        return const <String>[
          'ATS/ERS/JRS/ALAT — Idiopathic Pulmonary Fibrosis Update and Progressive Pulmonary Fibrosis Guideline (2022) — https://pubmed.ncbi.nlm.nih.gov/35486072/',
          'PMC — IPF/PPF ATS/ERS/JRS/ALAT Guideline full text (2022) — https://pmc.ncbi.nlm.nih.gov/articles/PMC9851481/',
          'ATS/ERS/JRS/ALAT — IPF/PPF Guideline DOI (2022) — https://doi.org/10.1164/rccm.202202-0399ST',
        ];

      case 'obstructive_sleep_apnea_nice':
        return const <String>[
          'NICE — Obstructive Sleep Apnoea/Hypopnoea Syndrome and Obesity Hypoventilation Syndrome NG202 (2021; links updated 2025) — https://www.nice.org.uk/guidance/NG202',
          'NICE — OSAHS Recommendations NG202 (current; update information 2025) — https://www.nice.org.uk/guidance/ng202/chapter/obstructive-sleep-apnoeahypopnoea-syndrome',
          'NICE — NG202 Update Information (March 2025) — https://www.nice.org.uk/guidance/ng202/chapter/Update-information',
        ];

      case 'obesity_hypoventilation_nice':
        return const <String>[
          'NICE — Obesity Hypoventilation Syndrome Recommendations NG202 (current; update information 2025) — https://www.nice.org.uk/guidance/NG202/chapter/2-obesity-hypoventilation-syndrome',
          'NICE — OSAHS and Obesity Hypoventilation Syndrome NG202 overview — https://www.nice.org.uk/guidance/NG202',
          'NICE — NG202 Update Information (March 2025) — https://www.nice.org.uk/guidance/ng202/chapter/Update-information',
        ];

      case 'hypersensitivity_pneumonitis_ats_2020':
        return const <String>[
          'ATS/JRS/ALAT — Diagnosis of Hypersensitivity Pneumonitis in Adults Guideline (2020; with later errata) — https://pubmed.ncbi.nlm.nih.gov/32706311/',
          'PMC — ATS/JRS/ALAT Hypersensitivity Pneumonitis Guideline full text (2020) — https://pmc.ncbi.nlm.nih.gov/articles/PMC7397797/',
          'ATS/JRS/ALAT — Hypersensitivity Pneumonitis Guideline DOI (2020) — https://doi.org/10.1164/rccm.202005-2032ST',
        ];

      case 'preeclampsia_eclampsia_nice_2023':
        return const <String>[
          'NICE — Hypertension in Pregnancy: Diagnosis and Management NG133, including Pre-eclampsia (updated 2023) — https://www.nice.org.uk/guidance/ng133',
          'NICE — Hypertension in Pregnancy Recommendations NG133 (current) — https://www.nice.org.uk/guidance/ng133/chapter/recommendations',
          'NICE — Hypertension in Pregnancy Update Information, PLGF-based Testing for Pre-eclampsia (2023) — https://www.nice.org.uk/guidance/ng133/chapter/Update-information',
        ];

      case 'postpartum_hemorrhage_who_2025':
        return const <String>[
          'WHO/FIGO/ICM — Consolidated Guidelines for Prevention, Diagnosis and Treatment of Postpartum Haemorrhage (2025) — https://www.who.int/publications/b/81071',
          'WHO — Postpartum Haemorrhage Guideline publication record (2025) — https://www.who.int/southeastasia/publications/i/item/9789240115637',
          'WHO — Postpartum Haemorrhage Implementation Guide (2026) — https://www.who.int/publications/i/item/9789240116115',
        ];

      case 'gestational_diabetes_ada_2026':
        return const <String>[
          'ADA — Standards of Care in Diabetes 2026: Management of Diabetes in Pregnancy (2026) — https://diabetesjournals.org/care/article/49/Supplement_1/S321/163918/15-Management-of-Diabetes-in-Pregnancy-Standards',
          'NICE — Diabetes in Pregnancy NG3, including Gestational Diabetes (current; reviewed 2025) — https://www.nice.org.uk/guidance/ng3/',
          'NICE — Diabetes in Pregnancy Recommendations, Gestational Diabetes Management — https://www.nice.org.uk/guidance/ng3/chapter/recommendations',
        ];

      case 'ectopic_pregnancy_nice_2026':
        return const <String>[
          'NICE — Ectopic Pregnancy and Miscarriage: Diagnosis and Initial Management NG126 (updated 2026) — https://www.nice.org.uk/guidance/ng126',
          'NICE — Ectopic Pregnancy and Miscarriage Recommendations NG126 (2026) — https://www.nice.org.uk/guidance/ng126/chapter/recommendations',
          'NICE — Ectopic Pregnancy and Miscarriage Update Information, Anti-D update (2026) — https://www.nice.org.uk/guidance/ng126/chapter/Update-information',
        ];

      case 'miscarriage_nice_2026':
        return const <String>[
          'NICE — Management of Miscarriage NG126 (updated 2026) — https://www.nice.org.uk/guidance/ng126/chapter/management-of-miscarriage',
          'NICE — Ectopic Pregnancy and Miscarriage NG126 overview (updated 2026) — https://www.nice.org.uk/guidance/ng126',
          'NICE — NG126 Update Information including 2026 Anti-D and 2023 Medical Management updates — https://www.nice.org.uk/guidance/ng126/chapter/Update-information',
        ];

      case 'endometriosis_nice_2024':
        return const <String>[
          'NICE — Endometriosis: Diagnosis and Management NG73 (updated 2024; reviewed 2025) — https://www.nice.org.uk/guidance/ng73',
          'NICE — Endometriosis Recommendations NG73 (2024 update) — https://www.nice.org.uk/guidance/ng73/chapter/Recommendations',
          'NICE — Endometriosis Update Information NG73 (2024; links updated 2026) — https://www.nice.org.uk/guidance/ng73/chapter/Update-information',
        ];

      case 'heavy_menstrual_bleeding_nice':
        return const <String>[
          'NICE — Heavy Menstrual Bleeding: Assessment and Management NG88 (current; reviewed 2024) — https://www.nice.org.uk/guidance/ng88',
          'NICE — Heavy Menstrual Bleeding Recommendations NG88 (current) — https://www.nice.org.uk/guidance/ng88/chapter/recommendations',
          'NICE — Heavy Menstrual Bleeding Update Information NG88 (current; links updated 2024) — https://www.nice.org.uk/guidance/ng88/chapter/update-information',
        ];

      case 'menopause_nice_2026':
        return const <String>[
          'NICE — Menopause: Identification and Management NG23 (updated 2026) — https://www.nice.org.uk/guidance/ng23',
          'NICE — Menopause Recommendations NG23 (2026) — https://www.nice.org.uk/guidance/ng23/chapter/Recommendations',
          'NICE — Menopause Update Information NG23 (April 2026) — https://www.nice.org.uk/guidance/NG23/chapter/update-information',
        ];

      case 'pediatric_bronchiolitis_nice':
        return const <String>[
          'NICE — Bronchiolitis in Children: Diagnosis and Management NG9 (updated 2021; current) — https://www.nice.org.uk/guidance/ng9',
          'NICE — Bronchiolitis in Children Recommendations NG9 (2021) — https://www.nice.org.uk/guidance/ng9/chapter/Recommendations',
          'NICE — Bronchiolitis in Children Context and current guideline scope (2021) — https://www.nice.org.uk/guidance/ng9/chapter/Context',
        ];

      case 'fever_under_five_nice':
        return const <String>[
          'NICE — Fever in Under 5s: Assessment and Initial Management NG143 (current; reviewed 2025) — https://www.nice.org.uk/guidance/NG143',
          'NICE — Fever in Under 5s Recommendations NG143 (current) — https://www.nice.org.uk/guidance/ng143/chapter/recommendations',
          'NICE — Fever in Under 5s public guideline resource, current review retained (2025) — https://www.nice.org.uk/guidance/ng143/informationforpublic',
        ];

      case 'pediatric_uti_nice_2022':
        return const <String>[
          'NICE — Urinary Tract Infection in Under 16s: Diagnosis and Management NG224 (2022; links updated 2025) — https://www.nice.org.uk/guidance/ng224',
          'NICE — UTI in Under 16s Recommendations NG224 (2022) — https://www.nice.org.uk/guidance/ng224/chapter/Recommendations',
          'NICE — UTI in Under 16s Update Information NG224 (2022; links updated 2025) — https://www.nice.org.uk/guidance/ng224/chapter/Update-information',
        ];

      case 'neonatal_jaundice_nice_2023':
        return const <String>[
          'NICE — Jaundice in Newborn Babies Under 28 Days CG98 (updated 2023) — https://www.nice.org.uk/Guidance/CG98',
          'NICE — Neonatal Jaundice Recommendations CG98 (2023) — https://www.nice.org.uk/guidance/cg98/chapter/recommendations',
          'NICE — Neonatal Jaundice Update Information CG98 (October 2023) — https://www.nice.org.uk/guidance/cg98/chapter/Update-information',
        ];

      case 'neonatal_infection_nice_2026':
        return const <String>[
          'NICE — Neonatal Infection: Antibiotics for Prevention and Treatment NG195 (updated 2026) — https://www.nice.org.uk/guidance/ng195',
          'NICE — Neonatal Infection Antibiotic Principles NG195 (2026) — https://www.nice.org.uk/guidance/ng195/chapter/Principles-around-use-of-antibiotics-for-early-onset-or-late-onset-neonatal-infection',
          'NICE — Neonatal Infection Update Information NG195 (May 2026) — https://www.nice.org.uk/guidance/ng195/chapter/Update-information',
        ];

      case 'pediatric_obesity_nice_2026':
        return const <String>[
          'NICE — Overweight and Obesity Management NG246, including Children and Young People (updated 2026) — https://www.nice.org.uk/guidance/ng246/',
          'NICE — Overweight and Obesity Management Recommendations NG246 (2026) — https://www.nice.org.uk/guidance/ng246/chapter/recommendations',
          'NICE — Overweight and Obesity Management NG246 overview and current review (2026) — https://www.nice.org.uk/guidance/ng246',
        ];

      case 'adhd_nice_current':
        return const <String>[
          'NICE — Attention Deficit Hyperactivity Disorder: Diagnosis and Management NG87 (current; links updated 2025) — https://www.nice.org.uk/guidance/ng87',
          'NICE — ADHD Recommendations NG87 (current) — https://www.nice.org.uk/guidance/ng87/chapter/recommendations',
          'NICE — ADHD Update Information NG87 (core update 2019; current links updated 2025) — https://www.nice.org.uk/guidance/ng87/chapter/Update-information',
        ];

      case 'acute_rhinosinusitis_aao_hns_2025':
        return const <String>[
          'AAO-HNSF — Clinical Practice Guideline: Adult Sinusitis Update (2025) — https://www.entnet.org/quality-practice/quality-products/clinical-practice-guidelines/cpg-adult-sinusitis/',
          'Otolaryngology–Head and Neck Surgery — Adult Sinusitis Update Full Guideline (2025) — https://aao-hnsfjournals.onlinelibrary.wiley.com/doi/10.1002/ohn.1344',
          'PubMed — Executive Summary of Adult Sinusitis Update (2025) — https://pubmed.ncbi.nlm.nih.gov/40741969/',
        ];

      case 'chronic_rhinosinusitis_aao_hns_2025':
        return const <String>[
          'AAO-HNSF — Clinical Practice Guideline: Surgical Management of Chronic Rhinosinusitis (2025) — https://www.entnet.org/quality-practice/quality-products/clinical-practice-guidelines/cpg-surgical-management-of-chronic-rhinosinusitis/',
          'Otolaryngology–Head and Neck Surgery — Surgical Management of Chronic Rhinosinusitis Full Guideline (2025) — https://aao-hnsfjournals.onlinelibrary.wiley.com/doi/10.1002/ohn.1287',
          'AAO-HNSF — Adult Sinusitis Update: Chronic Rhinosinusitis Diagnostic and Medical Management Statements (2025) — https://www.entnet.org/quality-practice/quality-products/clinical-practice-guidelines/cpg-adult-sinusitis/',
        ];

      case 'allergic_rhinitis_aria_eaaci_2026':
        return const <String>[
          'ARIA–EAACI — Allergic Rhinitis 2024–2025 Guideline Hub, current 2026 — https://aria.med.up.pt/',
          'ARIA–EAACI — 2024–2025 Revision Part I: Intranasal Treatments (2026) — https://pmc.ncbi.nlm.nih.gov/articles/PMC13040648/',
          'ARIA–EAACI — 2024–2025 Revision Part II: Oral and Ocular Treatments (2026) — https://pmc.ncbi.nlm.nih.gov/articles/PMC13256267/',
        ];

      case 'acute_otitis_externa_aao_hns_current':
        return const <String>[
          'AAO-HNSF — Clinical Practice Guideline: Acute Otitis Externa, current Academy guideline — https://www.entnet.org/quality-practice/quality-products/clinical-practice-guidelines/aoe/',
          'PubMed — AAO-HNSF Clinical Practice Guideline: Acute Otitis Externa — https://pubmed.ncbi.nlm.nih.gov/24491310/',
          'ACR — Appropriateness Criteria: Inflammatory Ear Disease (2025), including otitis externa imaging — https://www.sciencedirect.com/science/article/pii/S1546144025001322',
        ];

      case 'sudden_sensorineural_hearing_loss_aao_hns_japan':
        return const <String>[
          'AAO-HNSF — Clinical Practice Guideline: Sudden Hearing Loss Update, current Academy guideline — https://www.entnet.org/quality-practice/quality-products/clinical-practice-guidelines/sudden-hearing-loss-update/',
          'Otolaryngology–Head and Neck Surgery — Sudden Hearing Loss Update Full Guideline — https://aao-hnsfjournals.onlinelibrary.wiley.com/doi/10.1177/0194599819859885',
          'Japan Audiological Society — Clinical Practice Guidelines for Acute Sensorineural Hearing Loss (2024) — https://pubmed.ncbi.nlm.nih.gov/38968877/',
        ];

      case 'conjunctivitis_aao_2024':
        return const <String>[
          'AAO — Conjunctivitis Preferred Practice Pattern (2024) — https://www.aaojournal.org/article/S0161-6420%2824%2900009-5/fulltext',
          'AAO — Conjunctivitis Preferred Practice Pattern Abstract and Publication Record (2024) — https://www.aaojournal.org/article/S0161-6420%2824%2900009-5/abstract',
          'AAO EyeWiki — Bacterial Conjunctivitis, current 2026 clinical reference — https://eyewiki.aao.org/Bacterial_Conjunctivitis',
        ];

      case 'bacterial_keratitis_aao_2024':
        return const <String>[
          'AAO — Bacterial Keratitis Preferred Practice Pattern (2024) — https://www.aaojournal.org/article/S0161-6420%2824%2900007-1/fulltext',
          'AAO EyeWiki — Bacterial Keratitis, current 2026 clinical reference — https://eyewiki.aao.org/Bacterial_Keratitis',
          'AAO Eye Health — Bacterial Keratitis Clinical Patient Reference — https://www.aao.org/eye-health/diseases/bacterial-keratitis-27',
        ];

      case 'uveitis_dog_ser_consensus_2025':
        return const <String>[
          'DOG/BVA — S1 Guideline: Non-Infectious Anterior Uveitis, published 2025 — https://pubmed.ncbi.nlm.nih.gov/38438812/',
          'SER — Recommendations for the Treatment of Uveitis, evidence-based GRADE recommendations — https://pubmed.ncbi.nlm.nih.gov/37839964/',
          'Consensus Guideline — Chronic Noninfectious Uveitis Affecting the Posterior Segment (2024) — https://pubmed.ncbi.nlm.nih.gov/39254498/',
        ];

      case 'primary_open_angle_glaucoma_aao_2026':
        return const <String>[
          'AAO — Primary Open-Angle Glaucoma Preferred Practice Pattern (2026) — https://pubmed.ncbi.nlm.nih.gov/41665583/',
          'AAO/Ophthalmology — Primary Open-Angle Glaucoma Preferred Practice Pattern Full Record (2026) — https://www.aaojournal.org/article/S0161-6420%2825%2900815-2/fulltext',
          'AAO — 2026 IRIS Registry Glaucoma Quality Measure Specifications — https://assets.aao.org/2026-07/CQM%20Specifications.pdf',
        ];

      case 'adult_cataract_aao_nice_current':
        return const <String>[
          'AAO — Cataract in the Adult Eye Preferred Practice Pattern, valid through 2026 unless superseded — https://www.aaojournal.org/article/S0161-6420%2821%2900750-8/fulltext',
          'PubMed — Cataract in the Adult Eye Preferred Practice Pattern — https://pubmed.ncbi.nlm.nih.gov/34780842/',
          'NICE — Cataracts in Adults: Management NG77, reviewed May 2025 — https://www.nice.org.uk/guidance/ng77',
        ];

      case 'pediatric_pertussis_cdc_2026':
        return const <String>[
          'CDC — Clinical Overview of Pertussis, updated December 2025 — https://www.cdc.gov/pertussis/hcp/clinical-overview/index.html',
          'CDC — Treatment of Pertussis, updated December 2025 — https://www.cdc.gov/pertussis/hcp/clinical-care/',
          'CDC — Antibiotic-Resistant Bordetella pertussis, updated June 2026 — https://www.cdc.gov/pertussis/hcp/antibiotic-resistance/index.html',
        ];

      case 'pediatric_croup_cps_2026':
        return const <String>[
          'Canadian Paediatric Society — Acute Management of Croup in the Emergency Department, updated March 2026 — https://cps.ca/en/documents/position/acute-management-of-croup',
          'Royal Children’s Hospital Melbourne — Croup Clinical Practice Guideline, PIC endorsed — https://www.rch.org.au/clinicalguide/guideline_index/Croup_Laryngotracheobronchitis/',
          'Royal Children’s Hospital Melbourne — Acute Upper Airway Obstruction Clinical Practice Guideline — https://www.rch.org.au/clinicalguide/guideline_index/Acute_upper_airway_obstruction/',
        ];

      case 'pediatric_acute_otitis_media_aap_nice':
        return const <String>[
          'AAP — Clinical Practice Guideline: The Diagnosis and Management of Acute Otitis Media — https://publications.aap.org/pediatrics/article/131/3/e964/30912/The-Diagnosis-and-Management-of-Acute-Otitis-Media',
          'AAP Red Book 2024–2027 — Systems-Based Treatment Table: Acute Otitis Media — https://publications.aap.org/redbook/book/755/chapter/14074070/Systems-Based-Treatment-Table',
          'NICE — Otitis Media (Acute): Antimicrobial Prescribing NG91, current with November 2025 maintenance — https://www.nice.org.uk/guidance/ng91',
        ];

      case 'pediatric_scarlet_fever_cdc_2026':
        return const <String>[
          'CDC — Clinical Guidance for Scarlet Fever, updated February 2026 — https://www.cdc.gov/group-a-strep/hcp/clinical-guidance/scarlet-fever.html',
          'CDC — Group A Streptococcus Healthcare Provider Clinical Guidance Hub — https://www.cdc.gov/group-a-strep/hcp/index.html',
          'AAP Red Book 2024–2027 — Systems-Based Treatment Table: Group A Streptococcal Pharyngitis and Scarlet Fever Context — https://publications.aap.org/redbook/book/755/chapter/14074070/Systems-Based-Treatment-Table',
        ];

      case 'pediatric_acute_gastroenteritis_who_2024':
        return const <String>[
          'WHO — Guideline on Management of Pneumonia and Diarrhoea in Children up to 10 Years of Age (2024) — https://www.who.int/publications/i/item/9789240103412',
          'Royal Children’s Hospital Melbourne — Gastroenteritis Clinical Practice Guideline, updated August 2025 — https://www.rch.org.au/clinicalguide/guideline_index/Gastroenteritis/',
          'WHO — Diarrhoeal Disease: ORS, Zinc and Severe Dehydration Management — https://www.who.int/news-room/fact-sheets/detail/diarrhoeal-disease',
        ];

      case 'pediatric_dehydration_rch_2026':
        return const <String>[
          'Royal Children’s Hospital Melbourne — Dehydration Clinical Practice Guideline, updated April 2026 — https://www.rch.org.au/clinicalguide/guideline_index/dehydration/',
          'WHO — Guideline on Management of Diarrhoea in Children up to 10 Years: Dehydration and ORS (2024) — https://www.who.int/publications/i/item/9789240103412',
          'WHO — Diarrhoea Health Topic: Oral Rehydration and Management of Severe Dehydration — https://www.who.int/health-topics/diarrhoea',
        ];

      case 'kawasaki_disease_aha_2024':
        return const <String>[
          'AHA — Update on Diagnosis and Management of Kawasaki Disease: Scientific Statement (2024) — https://professional.heart.org/en/guidelines-statements/update-on-diagnosis-and-management-of-kawasaki-disease-a-scientific-statementcir0000000000001295',
          'Circulation/AHA — Full Scientific Statement: Kawasaki Disease Update (2024) — https://www.ahajournals.org/doi/10.1161/CIR.0000000000001295',
          'AHA — Top Things to Know: Kawasaki Disease Update (2024), with 2025 correction incorporated — https://professional.heart.org/en/science-news/update-on-diagnosis-and-management-of-kawasaki-disease/top-things-to-know',
        ];

      case 'hand_foot_mouth_disease_cdc_who':
        return const <String>[
          'CDC — About Hand, Foot, and Mouth Disease — https://www.cdc.gov/hand-foot-mouth/about/index.html',
          'CDC — HFMD Symptoms and Complications — https://www.cdc.gov/hand-foot-mouth/signs-symptoms/index.html',
          'WHO — A Guide to Clinical Management and Public Health Response for Hand, Foot and Mouth Disease — https://iris.who.int/bitstream/handle/10665/207490/9789290615255_eng.pdf',
        ];

      case 'febrile_seizure_aap_rch_current':
        return const <String>[
          'AAP — Clinical Practice Guideline: Neurodiagnostic Evaluation of the Child With a Simple Febrile Seizure — https://publications.aap.org/pediatrics/article/127/2/389/65189/Febrile-Seizures-Guideline-for-the-Neurodiagnostic',
          'Royal Children’s Hospital Melbourne — Febrile Seizure Clinical Practice Guideline — https://www.rch.org.au/clinicalguide/guideline_index/Febrile_seizure/',
          'AAP — Emergency Department Advanced Imaging Strategies for Common Pediatric Conditions (2024): Febrile Seizure Imaging Guidance — https://publications.aap.org/pediatrics/article-pdf/154/1/e2024066854/1671865/peds.2024-066854.pdf',
        ];

      case 'autism_spectrum_disorder_aap_2025':
        return const <String>[
          'AAP — Identification, Evaluation, and Management of Children With Autism Spectrum Disorder, reaffirmed October 2025 — https://publications.aap.org/pediatrics/article/145/1/e20193447/36917/Identification-Evaluation-and-Management-of',
          'CDC — Clinical Screening for Autism Spectrum Disorder, updated April 2025 — https://www.cdc.gov/autism/hcp/diagnosis/screening.html',
          'CDC — Clinical Testing and Diagnosis for Autism Spectrum Disorder, updated May 2025 — https://www.cdc.gov/autism/hcp/diagnosis/index.html',
        ];

      case 'uterine_fibroids_acog_nice_2025':
        return const <String>[
          'ACOG — Management of Symptomatic Uterine Leiomyomas, Practice Bulletin 228, reaffirmed 2025 — https://www.acog.org/clinical/clinical-guidance/practice-bulletin/articles/2021/06/management-of-symptomatic-uterine-leiomyomas',
          'NICE — Heavy Menstrual Bleeding NG88: Recommendations for Uterine Fibroids — https://www.nice.org.uk/guidance/ng88/chapter/Recommendations',
          'ACOG — Uterine Fibroids: Clinical Patient Reference — https://www.acog.org/womens-health/faqs/uterine-fibroids',
        ];

      case 'adenomyosis_asea_nice_2023':
        return const <String>[
          'Asian Society of Endometriosis and Adenomyosis — Guideline for Managing Adenomyosis (2023) — https://onlinelibrary.wiley.com/doi/10.1002/rmb2.12535',
          'PubMed — Asian Society Guideline for Managing Adenomyosis (2023) — https://pubmed.ncbi.nlm.nih.gov/37701076/',
          'NICE — Heavy Menstrual Bleeding NG88: Investigation when Adenomyosis is Suspected — https://www.nice.org.uk/guidance/ng88/chapter/Recommendations',
        ];

      case 'bacterial_vaginosis_cdc_who_acog_2025':
        return const <String>[
          'CDC — Bacterial Vaginosis: STI Treatment Guidelines — https://www.cdc.gov/std/treatment-guidelines/bv.htm',
          'WHO — Recommendations for Treatment of Bacterial Vaginosis, Candida and Trichomonas (2024/2025) — https://iris.who.int/bitstream/handle/10665/378215/9789240096370-eng.pdf',
          'ACOG — Vaginitis in Nonpregnant Patients, Practice Bulletin 215, reaffirmed 2025 with BV update — https://www.acog.org/clinical/clinical-guidance/practice-bulletin/articles/2020/01/vaginitis-in-nonpregnant-patients',
        ];

      case 'vulvovaginal_candidiasis_cdc_who_idsa':
        return const <String>[
          'CDC — Vulvovaginal Candidiasis: STI Treatment Guidelines — https://www.cdc.gov/std/treatment-guidelines/candidiasis.htm',
          'WHO — Recommendations for Treatment of Candida albicans and Other Vaginal Infections — https://iris.who.int/bitstream/handle/10665/378215/9789240096370-eng.pdf',
          'IDSA — Clinical Practice Guideline for the Management of Candidiasis, current listing — https://www.idsociety.org/practice-guideline/candidiasis/',
        ];

      case 'trichomoniasis_cdc_who_current':
        return const <String>[
          'CDC — Trichomoniasis: STI Treatment Guidelines — https://www.cdc.gov/std/treatment-guidelines/trichomoniasis.htm',
          'WHO — Recommendations for Treatment of Trichomonas vaginalis, current guideline — https://iris.who.int/bitstream/handle/10665/378215/9789240096370-eng.pdf',
          'ACOG — Vaginitis in Nonpregnant Patients, Practice Bulletin 215, reaffirmed 2025 — https://www.acog.org/clinical/clinical-guidance/practice-bulletin/articles/2020/01/vaginitis-in-nonpregnant-patients',
        ];

      case 'gestational_trophoblastic_disease_figo_2025':
        return const <String>[
          'FIGO Cancer Report — Diagnosis and Management of Gestational Trophoblastic Disease: 2025 Update — https://pmc.ncbi.nlm.nih.gov/articles/PMC12411817/',
          'Society of Gynecologic Oncology — Evidence-Based Review and Recommendation on Gestational Trophoblastic Disease — https://www.sgo.org/resources/epidemiology-diagnosis-and-treatment-of-gestational-trophoblastic-disease-a-society-of-gynecologic-oncology-evidenced-based-review-and-recommendation/',
          'SOGC — Guideline No. 408: Management of Gestational Trophoblastic Diseases — https://pubmed.ncbi.nlm.nih.gov/33384141/',
        ];

      case 'hyperemesis_gravidarum_rcog_2024':
        return const <String>[
          'RCOG — Management of Nausea and Vomiting in Pregnancy and Hyperemesis Gravidarum, Green-top Guideline 69, 2nd Edition 2024 — https://www.rcog.org.uk/guidance/browse-all-guidance/green-top-guidelines/the-management-of-nausea-and-vomiting-of-pregnancy-and-hyperemesis-gravidarum-green-top-guideline-no-69/',
          'PubMed — RCOG Green-top Guideline 69: Hyperemesis Gravidarum (2024) — https://pubmed.ncbi.nlm.nih.gov/38311315/',
          'ACOG — Nausea and Vomiting of Pregnancy, Practice Bulletin 189, reaffirmed 2024 — https://www.acog.org/clinical/clinical-guidance/practice-bulletin/articles/2018/01/nausea-and-vomiting-of-pregnancy',
        ];

      case 'placenta_previa_rcog_2026':
        return const <String>[
          'RCOG — Placenta Praevia and Placenta Accreta: Diagnosis and Management, Green-top Guideline 27a, 5th Edition 2026 — https://www.rcog.org.uk/guidance/browse-all-guidance/green-top-guidelines/placenta-praevia-and-placenta-accreta-diagnosis-and-management-green-top-guideline-no-27a/',
          'RCOG — 2026 Update to Clinical Guidance on Placenta Praevia and Placenta Accreta Spectrum — https://www.rcog.org.uk/news/rcog-publishes-update-to-clinical-guidance-on-placenta-praevia-and-placenta-accreta-spectrum/',
          'NICE — Caesarean Birth NG192: Placenta Praevia Recommendations — https://www.nice.org.uk/guidance/NG192/chapter/recommendations',
        ];

      case 'placental_abruption_rcog_acog_current':
        return const <String>[
          'RCOG — Antepartum Haemorrhage Green-top Guideline 63: Placental Abruption — https://www.rcog.org.uk/guidance/browse-all-guidance/green-top-guidelines/antepartum-haemorrhage-green-top-guideline-no-63/',
          'ACOG — Indications for Outpatient Antenatal Fetal Surveillance: Chronic Placental Abruption — https://www.acog.org/clinical/clinical-guidance/committee-opinion/articles/2021/06/indications-for-outpatient-antenatal-fetal-surveillance',
          'ACOG/SMFM — Medically Indicated Late-Preterm and Early-Term Deliveries: Placental Conditions — https://www.acog.org/clinical/clinical-guidance/committee-opinion/articles/2021/07/medically-indicated-late-preterm-and-early-term-deliveries',
        ];

      case 'prelabor_rupture_membranes_acog_2026':
        return const <String>[
          'ACOG — Prelabor Rupture of Membranes, Practice Bulletin 217, reaffirmed 2026 — https://www.acog.org/clinical/clinical-guidance/practice-bulletin/articles/2020/03/prelabor-rupture-of-membranes',
          'ACOG — Increased Risk of Maternal Morbidity with Previable and Periviable PPROM, Practice Advisory 2025 — https://www.acog.org/clinical/clinical-guidance/practice-advisory/articles/2025/05/increased-risk-of-maternal-morbidity-associated-with-previable-and-periviable-preterm-prelabor-rupture-of-membranes',
          'RCOG — Care of Women with Suspected PPROM from 24+0 Weeks, Green-top Guideline 73, reviewed 2024/current 2026 — https://www.rcog.org.uk/guidance/browse-all-guidance/green-top-guidelines/care-of-women-presenting-with-suspected-preterm-prelabour-rupture-of-membranes-from-24plus0-weeks-of-gestation-green-top-guideline-no-73/',
        ];

      case 'cutaneous_dermatophytosis_aad_cdc_2026':
        return const <String>[
          'AAD — Trichophyton indotineae and Other Severe or Antifungal-Resistant Dermatophytoses, current 2026 — https://www.aad.org/member/clinical-quality/clinical-care/emerging-diseases/dermatophytes',
          'AAD — Preventing and Treating Trichophyton indotineae and Dermatophyte Infection — https://www.aad.org/member/clinical-quality/clinical-care/emerging-diseases/dermatophytes/preventing-treating-trichophyton-indotineae',
          'CDC — Expert Review of Skin and Hair Dermatophytoses in an Era of Antifungal Resistance — https://stacks.cdc.gov/view/cdc/158164',
        ];

      case 'cutaneous_candidiasis_idsa_cdc_current':
        return const <String>[
          'IDSA — Clinical Practice Guideline for the Management of Candidiasis, listed as current — https://www.idsociety.org/practice-guideline/candidiasis/',
          'IDSA — Skin and Soft Tissue Infection Guideline: Superficial Cutaneous Candidiasis — https://www.idsociety.org/practice-guideline/skin-and-soft-tissue-infections/',
          'CDC — About Candidiasis and Candida Infections — https://www.cdc.gov/candidiasis/about/index.html',
        ];

      case 'hidradenitis_suppurativa_aad_2026':
        return const <String>[
          'AAD — Hidradenitis Suppurativa: Diagnosis and Treatment, updated June 2026 — https://www.aad.org/public/diseases/a-z/hidradenitis-suppurativa-treatment',
          'AAD — Hidradenitis Suppurativa: Overview — https://www.aad.org/diseases/a-z/hidradenitis-suppurativa-overview',
          'North American HS Foundations — Clinical Management Guidelines Part II: Medical Management — https://pubmed.ncbi.nlm.nih.gov/30872149/',
        ];

      case 'vitiligo_bad_2021_current':
        return const <String>[
          'British Association of Dermatologists — Guidelines for the Management of People with Vitiligo (2021), current BAD reference — https://pubmed.ncbi.nlm.nih.gov/34160061/',
          'British Association of Dermatologists — Vitiligo Clinical Referral and Management Guidance — https://www.bad.org.uk/referrals/vitiligo',
          'British Association of Dermatologists — Vitiligo Information with Guideline Link, updated 2026 — https://www.bad.org.uk/pils/vitiligo',
        ];

      case 'alopecia_areata_bad_living_2024':
        return const <String>[
          'British Association of Dermatologists — Living Guideline for Managing People with Alopecia Areata (2024) — https://pubmed.ncbi.nlm.nih.gov/39534978/',
          'BAD — Alopecia Areata Living Guideline Presentation (2024) — https://cdn.bad.org.uk/uploads/2021/12/09094658/Alopecia-areata-living-guideline-Presentation.pdf',
          'NICE — Ritlecitinib for Treating Severe Alopecia Areata in People 12 Years and Over (TA958) — https://www.nice.org.uk/guidance/ta958',
        ];

      case 'pemphigus_vulgaris_eadv_2020_current':
        return const <String>[
          'EADV — Updated S2K Guideline on Management of Pemphigus Vulgaris and Foliaceus — https://pubmed.ncbi.nlm.nih.gov/32830877/',
          'EADV — Clinical Guidelines Hub: Pemphigus Vulgaris and Foliaceus — https://eadv.org/publications/jeadv/clinical-guidelines-recommendations-position-statements/',
          'EADV Autoimmune Bullous Diseases Task Force — Pemphigus Vulgaris and Foliaceus Clinical Information — https://eadv.org/wp-content/uploads/2024/04/aibd-pemphigus-vulgaris-foliaceus-eadv.pdf',
        ];

      case 'bullous_pemphigoid_eadv_2022_current':
        return const <String>[
          'EADV — Updated S2K Guideline for Management of Bullous Pemphigoid (2022) — https://pubmed.ncbi.nlm.nih.gov/35766904/',
          'EADV — Clinical Guidelines and Recommendations Hub: Autoimmune Bullous Diseases — https://eadv.org/publications/jeadv/clinical-guidelines-recommendations-position-statements/',
          'European Journal of Dermatology — Bullous Pemphigoid Diagnosis and Management Review based on EADV guidance — https://pubmed.ncbi.nlm.nih.gov/37204616/',
        ];

      case 'cutaneous_melanoma_aad_current':
        return const <String>[
          'AAD — Melanoma Clinical Guideline, current pending 2026 update — https://www.aad.org/member/clinical-quality/guidelines/melanoma',
          'AAD — Clinical Guidelines Index: Melanoma Update Status, 2026 — https://www.aad.org/member/clinical-quality/guidelines',
          'NCI — Melanoma Treatment PDQ, Health Professional Version — https://www.cancer.gov/types/skin/hp/melanoma-treatment-pdq',
        ];

      case 'basal_cell_carcinoma_aad_current':
        return const <String>[
          'AAD — Basal Cell Carcinoma Clinical Guideline — https://www.aad.org/member/clinical-quality/guidelines/bcc',
          'AAD — Basal Cell Carcinoma: Diagnosis and Treatment, updated 2025 — https://www.aad.org/public/diseases/skin-cancer/basal-cell-carcinoma',
          'NCI — Skin Cancer Treatment PDQ: Basal Cell Carcinoma — https://www.cancer.gov/types/skin/hp/skin-treatment-pdq',
        ];

      case 'cutaneous_squamous_cell_carcinoma_aad_current':
        return const <String>[
          'AAD — Cutaneous Squamous Cell Carcinoma Clinical Guideline — https://www.aad.org/member/clinical-quality/guidelines/scc',
          'AAD — Squamous Cell Carcinoma: Diagnosis and Treatment, updated January 2026 — https://www.aad.org/public/diseases/skin-cancer/squamous-cell-carcinoma',
          'NCI — Skin Cancer Treatment PDQ: Cutaneous Squamous Cell Carcinoma — https://www.cancer.gov/types/skin/hp/skin-treatment-pdq',
        ];

      case 'atopic_dermatitis_aad_2026':
        return const <String>[
          'AAD — Atopic Dermatitis Clinical Guideline, including 2025 focused adult update — https://www.aad.org/member/clinical-quality/guidelines/atopic-dermatitis',
          'AAD — Pediatric Atopic Dermatitis Guidelines (2026) — https://www.aad.org/news/aad-issues-first-pediatric-atopic-dermatitis-guidelines',
          'AAD — Updated Adult Atopic Dermatitis Topical Therapy Guideline — https://www.aad.org/news/updated-atopic-dermatitis-guidelines-topical-therapies',
        ];

      case 'contact_dermatitis_bad_escd_2025':
        return const <String>[
          'British Association of Dermatologists — Contact Dermatitis, updated June 2025 — https://www.bad.org.uk/pils/contact-dermatitis',
          'European Society of Contact Dermatitis — Guideline for Diagnostic Patch Testing — https://pubmed.ncbi.nlm.nih.gov/26179009/',
          'British Association of Dermatologists — Guidelines for Management of Contact Dermatitis — https://pubmed.ncbi.nlm.nih.gov/29045841/',
        ];

      case 'seborrheic_dermatitis_eadv_2026':
        return const <String>[
          'EADV-supported Expert Consensus — Practical Recommendations for Seborrheic Dermatitis Management (2026) — https://onlinelibrary.wiley.com/doi/10.1111/jdv.70444',
          'European Journal of Dermatology — International Expert Consensus on Adult Scalp Seborrheic Dermatitis (2024) — https://pubmed.ncbi.nlm.nih.gov/38919137/',
          'AAD — Seborrheic Dermatitis: Diagnosis and Treatment — https://www.aad.org/public/diseases/a-z/seborrheic-dermatitis-treatment',
        ];

      case 'psoriasis_aad_npf_current':
        return const <String>[
          'AAD/NPF — Psoriasis Clinical Guideline Hub, current 2026 — https://www.aad.org/member/clinical-quality/guidelines/psoriasis',
          'AAD — Clinical Guidelines Index: Psoriasis and 2026 update status — https://www.aad.org/member/clinical-quality/guidelines',
          'AAD/NPF — Guidelines of Care for Management and Treatment of Psoriasis with Biologics — https://pubmed.ncbi.nlm.nih.gov/30772098/',
        ];

      case 'chronic_urticaria_euroguiderm_eaaci_2022':
        return const <String>[
          'EAACI/GA²LEN/EuroGuiDerm/APAAACI — International Guideline for Urticaria — https://eaaci.org/guidelines-position-papers/the-international-eaaci-ga%C2%B2len-euroguiderm-apaaaci-guideline-for-the-definition-classification-diagnosis-and-management-of-urticaria/',
          'EAACI — Biologicals Guideline: Omalizumab for Chronic Spontaneous Urticaria — https://eaaci.org/guidelines-position-papers/eaaci-biologicals-guidelines-omalizumab-for-the-treatment-of-chronic-spontaneous-urticaria-in-adults-and-in-the-paediatric-population-12-17-years-old/',
          'PubMed — International Urticaria Guideline, Allergy 2022 — https://pubmed.ncbi.nlm.nih.gov/34536239/',
        ];

      case 'hereditary_angioedema_wao_2025':
        return const <String>[
          'WAO — 2025 Guidelines for Classification, Diagnosis and Treatment of Hereditary Angioedema — https://pubmed.ncbi.nlm.nih.gov/42165046/',
          'WAO — Open Access 2025 Hereditary Angioedema Guideline — https://pmc.ncbi.nlm.nih.gov/articles/PMC13184495/',
          'WAO/EAACI — International Guideline for Management of Hereditary Angioedema — https://eaaci.org/guidelines-position-papers/the-international-wao-eaaci-guideline-for-the-management-of-hereditary-angioedema-the-2021-revision-and-update/',
        ];

      case 'acne_vulgaris_aad_2024':
        return const <String>[
          'AAD — Acne Clinical Guideline, current 2026 — https://www.aad.org/member/clinical-quality/guidelines/acne',
          'JAAD/AAD — Guidelines of Care for the Management of Acne Vulgaris (2024) — https://pubmed.ncbi.nlm.nih.gov/38300170/',
          'AAD — Acne Guideline Update Clinical News — https://www.aad.org/news/updated-guidelines-acne-management',
        ];

      case 'rosacea_global_consensus_2024':
        return const <String>[
          'JAMA Dermatology — Rosacea Core Domain Set for Clinical Trials and Practice: Consensus Statement (2024) — https://pubmed.ncbi.nlm.nih.gov/38656294/',
          'Dermatology and Therapy — Diagnostic and Therapeutic Gaps in Rosacea Management: Consensus Opinion (2024) — https://pmc.ncbi.nlm.nih.gov/articles/PMC10891023/',
          'Global ROSacea COnsensus — Rosacea Treatment Update, phenotype-based recommendations — https://academic.oup.com/bjd/article/176/2/465/6601866',
        ];

      case 'impetigo_nice_2026':
        return const <String>[
          'NICE — Impetigo: Antimicrobial Prescribing (NG153), current 2026 — https://www.nice.org.uk/guidance/ng153',
          'NICE — Impetigo Antimicrobial Prescribing Full Guideline PDF (2026) — https://www.nice.org.uk/guidance/ng153/resources/impetigo-antimicrobial-prescribing-pdf-66141838603717',
          'NICE — Impetigo Antimicrobial Prescribing Visual Summary — https://www.nice.org.uk/guidance/ng153/resources/visual-summary-pdf-7084853533',
        ];

      case 'scabies_cdc_current':
        return const <String>[
          'CDC — Clinical Care of Scabies — https://www.cdc.gov/scabies/hcp/clinical-care/index.html',
          'CDC — About Scabies — https://www.cdc.gov/scabies/about/index.html',
          'CDC STI Treatment Guidelines — Ectoparasitic Infections: Scabies — https://www.cdc.gov/std/treatment-guidelines/ectoparasitic.htm',
        ];

      case 'fibromyalgia_eular_nice_current':
        return const <String>[
          'EULAR — Revised Recommendations for the Management of Fibromyalgia — https://ard.bmj.com/content/76/2/318',
          'NICE — Chronic Pain NG193: Fibromyalgia as Chronic Primary Pain — https://www.nice.org.uk/guidance/ng193',
          'ACR — Fibromyalgia Criteria and Diagnostic Reference Center — https://rheumatology.org/criteria',
        ];

      case 'reactive_arthritis_acr_2025':
        return const <String>[
          'ACR — Reactive Arthritis, updated February 2025 — https://rheumatology.org/patients/reactive-arthritis',
          'Clinical Medicine — Reactive Arthritis: A Clinical Review — https://pubmed.ncbi.nlm.nih.gov/34528623/',
          'Current Rheumatology Reports — Treatment of Reactive Arthritis with Biological Agents (2024) — https://pubmed.ncbi.nlm.nih.gov/39312088/',
        ];

      case 'cppd_acr_eular_2023':
        return const <String>[
          'ACR/EULAR — 2023 Classification Criteria for Calcium Pyrophosphate Deposition Disease — https://www.eular.org/recommendations-classification-response-criteria-diagnostic',
          'Annals of the Rheumatic Diseases — 2023 ACR/EULAR CPPD Classification Criteria — https://ard.bmj.com/content/82/10/1248',
          'EULAR — Recommendations for Calcium Pyrophosphate Deposition: Management — https://www.eular.org/recommendations-management',
        ];

      case 'idiopathic_inflammatory_myopathy_bsr_2022':
        return const <String>[
          'BSR — Guideline for Management of Paediatric, Adolescent and Adult Idiopathic Inflammatory Myopathy (2022) — https://www.rheumatology.org.uk/guidelines',
          'PubMed — British Society for Rheumatology Idiopathic Inflammatory Myopathy Guideline — https://pubmed.ncbi.nlm.nih.gov/35355064/',
          'EULAR/ACR — Classification Criteria for Adult and Juvenile Idiopathic Inflammatory Myopathies — https://www.eular.org/recommendations-eular-acr',
        ];

      case 'juvenile_idiopathic_arthritis_acr_2026':
        return const <String>[
          'ACR — 2026 Juvenile Idiopathic Arthritis Clinical Practice Guideline — https://rheumatology.org/juvenile-idiopathic-arthritis-guideline',
          'ACR — Updated Juvenile Idiopathic Arthritis Guidelines Released May 13, 2026 — https://rheumatology.org/press-releases/the-american-college-of-rheumatology-releases-updated-guidelines-for-treatment-of-juvenile-idiopathic-arthritis',
          'EULAR/PReS — Recommendations for Diagnosis and Management of Still’s Disease including systemic JIA (2024) — https://www.eular.org/recommendations-management',
        ];

      case 'primary_raynaud_acr_2025':
        return const <String>[
          'ACR — Raynaud’s Phenomenon, updated February 2025 — https://rheumatology.org/patients/raynauds-phenomenon',
          'Vascular Specialist International — Raynaud’s Phenomenon: Current Update on Diagnosis and Treatment (2024) — https://pubmed.ncbi.nlm.nih.gov/39040029/',
          'Journal of the American Academy of Dermatology — Treatment of Primary and Secondary Raynaud’s Phenomenon — https://pubmed.ncbi.nlm.nih.gov/35809802/',
        ];

      case 'nonspecific_low_back_pain_who_nice':
        return const <String>[
          'WHO — Guideline for Non-Surgical Management of Chronic Primary Low Back Pain (2023) — https://www.who.int/publications/i/item/9789240081789',
          'WHO — Chronic Primary Low Back Pain Guideline Executive Summary — https://www.who.int/publications/b/71563',
          'NICE — Low Back Pain and Sciatica in Over 16s: Assessment and Management (NG59) — https://www.nice.org.uk/guidance/ng59',
        ];

      case 'lumbar_radiculopathy_sciatica_nice':
        return const <String>[
          'NICE — Low Back Pain and Sciatica in Over 16s: Assessment and Management (NG59) — https://www.nice.org.uk/guidance/ng59',
          'NICE — NG59 Recommendations: Sciatica Pharmacological and Non-Surgical Management — https://www.nice.org.uk/guidance/ng59/chapter/recommendations',
          'NICE — Low Back Pain and Sciatica NG59 Full Guideline Resource — https://www.nice.org.uk/guidance/ng59/resources/low-back-pain-and-sciatica-in-over-16sassessment-and-management-1837521693637',
        ];

      case 'nonspecific_cervicalgia_jospt_current':
        return const <String>[
          'JOSPT/APTA Orthopaedic Section — Neck Pain: Revision 2017 Clinical Practice Guideline — https://pubmed.ncbi.nlm.nih.gov/28666405/',
          'JOSPT — Neck Pain Guidelines: Using the Evidence to Guide Physical Therapist Practice — https://pubmed.ncbi.nlm.nih.gov/28666402/',
          'NICE — Suspected Neurological Conditions: Cervical Radiculopathy Recognition and Referral — https://www.nice.org.uk/guidance/ng127/chapter/recommendations',
        ];

      case 'rotator_cuff_injury_aaos_2025':
        return const <String>[
          'AAOS — Management of Rotator Cuff Injuries Evidence-Based Clinical Practice Guideline (2025) — https://www.aaos.org/rccpg2025',
          'AAOS — Rotator Cuff Clinical Practice Guideline Resources and Evidence Tables — https://www.aaos.org/quality/quality-programs/upper-extremity-programs/rotator-cuff-injuries/',
          'AAOS OrthoInfo — Rotator Cuff Tears: Clinical Background and Management — https://orthoinfo.aaos.org/en/diseases--conditions/rotator-cuff-tears/',
        ];

      case 'adult_acute_lymphoblastic_leukemia_eln_2024':
        return const <String>[
          'European LeukemiaNet — Management of ALL in Adults: 2024 ELN Recommendations — https://pubmed.ncbi.nlm.nih.gov/38306595/',
          'European LeukemiaNet — Diagnosis, Prognostic Factors and Assessment of ALL in Adults: 2024 ELN Recommendations — https://pubmed.ncbi.nlm.nih.gov/38295337/',
          'NCI — Acute Lymphoblastic Leukemia Treatment PDQ, Health Professional Version — https://www.cancer.gov/types/leukemia/hp/adult-all-treatment-pdq',
        ];

      case 'classical_hodgkin_lymphoma_bsh_nci':
        return const <String>[
          'BSH — Guideline for the First-Line Management of Classical Hodgkin Lymphoma — https://b-s-h.org.uk/guidelines/guidelines/guideline-for-the-first-line-management-of-classical-hodgkin-lymphoma',
          'NCI — Hodgkin Lymphoma Treatment PDQ, Health Professional Version — https://www.cancer.gov/types/lymphoma/hp/adult-hodgkin-treatment-pdq',
          'ESMO — Hodgkin Lymphoma Clinical Practice Guideline Slide Set — https://www.esmo.org/content/download/281767/5568640/1/Clinical-Practice-Guidelines-Slideset-Hodgkin-Lymphoma.pdf',
        ];

      case 'diffuse_large_b_cell_lymphoma_bsh_2025':
        return const <String>[
          'BSH — Management of Newly Diagnosed Large B-Cell Lymphoma (2024) — https://cms.b-s-h.org.uk/guidelines/guidelines/the-management-of-newly-diagnosed-large-b-cell-lymphoma',
          'BSH — Management of Relapsed or Refractory Large B-Cell Lymphoma (2025) — https://b-s-h.org.uk/guidelines/guidelines/management-of-relapsed-or-refractory-large-b-cell-lymphoma',
          'NCI — Aggressive B-Cell Non-Hodgkin Lymphoma Treatment PDQ, including DLBCL — https://www.cancer.gov/types/lymphoma/hp/aggressive-b-cell-lymphoma-treatment-pdq',
        ];

      case 'breast_cancer_esmo_nci_current':
        return const <String>[
          'NCI — Breast Cancer Treatment PDQ, Health Professional Version (2025) — https://www.cancer.gov/types/breast/hp/breast-treatment-pdq',
          'ESMO — Breast Cancer Pocket Guideline and Metastatic Breast Cancer Living Guideline — https://data.esmo.org/guidelines/pdf/publicassets/ESMO_2023_BreastCancer.pdf',
          'ESMO — Metastatic Breast Cancer Living Guideline — https://www.esmo.org/living-guidelines/esmo-metastatic-breast-cancer-living-guideline',
        ];

      case 'prostate_cancer_eau_2026':
        return const <String>[
          'EAU — Prostate Cancer Guideline, 2026 Edition — https://uroweb.org/guidelines/prostate-cancer',
          'EAU — Prostate Cancer Guideline: Summary of Changes 2026 — https://uroweb.org/guidelines/prostate-cancer/summary-of-changes',
          'NCI — Prostate Cancer Treatment PDQ, Health Professional Version (2025) — https://www.cancer.gov/types/prostate/hp/prostate-treatment-pdq',
        ];

      case 'non_small_cell_lung_cancer_esmo_nci_current':
        return const <String>[
          'NCI — Non-Small Cell Lung Cancer Treatment PDQ, Health Professional Version (2025) — https://www.cancer.gov/types/lung/hp/non-small-cell-lung-treatment-pdq',
          'ESMO — Metastatic NSCLC with Actionable Oncogenic Driver Alterations Clinical Practice Guideline — https://www.annalsofoncology.org/article/S0923-7534(22)04781-0/fulltext',
          'ESMO — Metastatic NSCLC without Actionable Oncogenic Driver Alterations Clinical Practice Guideline — https://www.annalsofoncology.org/article/S0923-7534(22)04785-8/fulltext',
        ];

      case 'colorectal_cancer_asco_nci_current':
        return const <String>[
          'ASCO — Treatment of Metastatic Colorectal Cancer Clinical Practice Guideline — https://pubmed.ncbi.nlm.nih.gov/36252154/',
          'NCI — Colon Cancer Treatment PDQ, Health Professional Version — https://www.cancer.gov/types/colorectal/hp/colon-treatment-pdq',
          'NCI — Rectal Cancer Treatment PDQ, Health Professional Version — https://www.cancer.gov/types/colorectal/hp/rectal-treatment-pdq',
        ];

      case 'cervical_cancer_esgo_2023_current':
        return const <String>[
          'ESGO/ESTRO/ESP — Guidelines for Management of Patients with Cervical Cancer, Update 2023 — https://pubmed.ncbi.nlm.nih.gov/37145263/',
          'ESGO/ESTRO/ESP — Cervical Cancer Pocket Guidelines, Update 2023 — https://www.esgo.org/media/2019/03/Pocket-Guidelines_Cervical-cancer_June2023.pdf',
          'NCI — Cervical Cancer Treatment PDQ, Health Professional Version — https://www.cancer.gov/types/cervical/hp/cervical-treatment-pdq',
        ];

      case 'ovarian_cancer_esgo_esmo_2024':
        return const <String>[
          'ESGO-ESMO-ESP — Ovarian Cancer Consensus Recommendations: Early, Advanced and Recurrent Disease (2024) — https://pubmed.ncbi.nlm.nih.gov/38307807/',
          'ESGO — Ovarian Cancer Pocket Guidelines, Published 2024 — https://www.esgo.org/media/2025/08/Pocket-Guidelines_Ovarian-cancer-consensus.pdf',
          'NCI — Ovarian Epithelial, Fallopian Tube and Primary Peritoneal Cancer Treatment PDQ — https://www.cancer.gov/types/ovarian/hp/ovarian-epithelial-treatment-pdq',
        ];

      case 'pancreatic_cancer_esmo_2025':
        return const <String>[
          'ESMO — Clinical Practice Guideline Express Update on Metastatic Pancreatic Cancer (2025) — https://pubmed.ncbi.nlm.nih.gov/40287191/',
          'ESMO Open — Pancreatic Cancer Guideline Express Update, Open Access (2025) — https://pmc.ncbi.nlm.nih.gov/articles/PMC12125698/',
          'NCI — Pancreatic Cancer Treatment PDQ, Health Professional Version — https://www.cancer.gov/types/pancreatic/hp/pancreatic-treatment-pdq',
        ];

      case 'anemia_of_inflammation_ash_current':
        return const <String>[
          'ASH/Blood — Anemia of Inflammation: diagnostic and pathophysiologic reference — https://ashpublications.org/blood/article/133/1/40/6617/Anemia-of-inflammation',
          'ASH/Blood — The Role of Iron in Chronic Inflammatory Diseases and Anemia of Inflammation (2022) — https://ashpublications.org/blood/article/140/19/2011/486362/The-role-of-iron-in-chronic-inflammatory-diseases',
          'Annual Review of Immunology — Immune Mechanisms in Inflammatory Anemia (2023) — https://www.annualreviews.org/content/journals/10.1146/annurev-immunol-101320-125839',
        ];

      case 'folate_deficiency_nih_who_bsh':
        return const <String>[
          'NIH Office of Dietary Supplements — Folate: Fact Sheet for Health Professionals — https://ods.od.nih.gov/factsheets/Folate-HealthProfessional/',
          'WHO — Guideline: Optimal Serum and Red Blood Cell Folate Concentrations in Women of Reproductive Age — https://www.who.int/publications/i/item/9789241549042',
          'British Society for Haematology — Diagnosis of B12 and Folate Deficiency reference page and current supersession notice — https://b-s-h.org.uk/guidelines/guidelines/diagnosis-of-b12-and-folate-deficiency',
        ];

      case 'acquired_aplastic_anemia_ash_2026':
        return const <String>[
          'ASH — 2026 Guidelines for Diagnosis and Management of Severe and Very Severe Acquired Aplastic Anemia — https://www.hematology.org/newsroom/press-releases/2026/ash-guidelines-on-severe-acquired-aplastic-anemia',
          'ASH — Aplastic Anemia 2026 Clinical Practice Guideline Pocket Guide — https://www.hematology.org/-/media/hematology/files/clinicians/guidelines/ash-cpg-aplastic-anemia-pocket-guide-6-panel-0320-nocropmarks.pdf',
          'BSH — Guidelines for the Diagnosis and Management of Adult Aplastic Anaemia (2024) — https://b-s-h.org.uk/guidelines/guidelines/guidelines-for-the-diagnosis-and-management-of-adult-aplastic-anaemia',
        ];

      case 'g6pd_deficiency_who_2025':
        return const <String>[
          'WHO — Guidelines for Malaria, 13 August 2025: G6PD testing and safe primaquine/tafenoquine use — https://iris.who.int/bitstream/handle/10665/382254/B09514-eng.pdf?sequence=1',
          'WHO — Updated WHO Classification of Genetic Variants Causing G6PD Deficiency — https://pmc.ncbi.nlm.nih.gov/articles/PMC11276151/',
          'WHO — Guide to G6PD Deficiency Rapid Diagnostic Testing to Support P. vivax Radical Cure — https://www.who.int/publications/i/item/9789241514286',
        ];

      case 'hemophilia_ab_wfh_living_2026':
        return const <String>[
          'WFH — Guidelines for the Management of Hemophilia: Living Guideline Topics, current 2026 — https://guidelines.wfh.org/guidelines/',
          'WFH — Guidelines for the Management of Hemophilia, Complete 3rd Edition — https://elearning.wfh.org/resource/treatment-guidelines/',
          'WFH — Diagnosis of Hemophilia and Other Bleeding Disorders: Laboratory Manual, 3rd Edition (2025) — https://elearning.wfh.org/resource/diagnosis-of-hemophilia-and-other-bleeding-disorders-a-laboratory-manual/',
        ];

      case 'disseminated_intravascular_coagulation_isth_2025':
        return const <String>[
          'ISTH SSC — Updated Definition and Scoring of Disseminated Intravascular Coagulation (2025) — https://www.jthjournal.org/article/S1538-7836(25)00220-X/fulltext',
          'ISTH SSC — Global Practice and Challenges in Diagnosis and Management of DIC (2026) — https://www.jthjournal.org/article/S1538-7836(26)00064-4/fulltext',
          'BSH — Guidelines for Diagnosis and Management of Disseminated Intravascular Coagulation — https://b-s-h.org.uk/guidelines/guidelines/guidelines-for-the-diagnosis-and-management-of-disseminated-intravascular-coagulation',
        ];

      case 'polycythemia_vera_bsh_eln_current':
        return const <String>[
          'BSH — Diagnosis and Management of Polycythaemia Vera — https://b-s-h.org.uk/guidelines/guidelines/diagnosis-and-management-of-polycythaemia-vera',
          'European LeukemiaNet — Appropriate Management of Polycythaemia Vera with Cytoreductive Drug Therapy: ELN 2021 Recommendations — https://www.leukemia-net.org/sites/leukemia-net/content/e58/e510/e511/e11526/Marchettietal_LancetHematology2021.Appropriatemanagementofpolycythaemiaverawithcytoreductivedrugtherapy-EuropeanLeukemiaNet2021recommendations.Summary.pdf',
          'European LeukemiaNet — Myeloproliferative Neoplasms Recommendations Hub — https://www.leukemia-net.org/leukemias/mpn/project_info/',
        ];

      case 'essential_thrombocythemia_2024_current':
        return const <String>[
          'American Journal of Hematology — Essential Thrombocythemia: 2024 Update on Diagnosis, Risk Stratification and Management — https://pubmed.ncbi.nlm.nih.gov/38269572/',
          'European LeukemiaNet — Myeloproliferative Neoplasms Recommendations Hub — https://www.leukemia-net.org/leukemias/mpn/project_info/',
          'BSH — Investigation and Management of Thrombocytosis without JAK2, CALR or MPL Mutations (2025): critical ET differential — https://b-s-h.org.uk/guidelines/guidelines/investigation-and-management-of-thrombocytosis-without-jak2-calr-or-mpl-mutations-guideline',
        ];

      case 'myelofibrosis_bsh_2023_current':
        return const <String>[
          'BSH — The Management of Myelofibrosis Guideline (2023; reviewed 2024) — https://cms.b-s-h.org.uk/guidelines/guidelines/the-management-of-myelofibrosis-a-british-society-for-haematology-guideline',
          'BSH — Diagnosis and Evaluation of Prognosis of Myelofibrosis (2023) — https://b-s-h.org.uk/guidelines/guidelines/diagnosis-and-evaluation-of-prognosis-of-myelofibrosis',
          'European LeukemiaNet — Myeloproliferative Neoplasms Recommendations Hub — https://www.leukemia-net.org/leukemias/mpn/project_info/',
        ];

      case 'chronic_lymphocytic_leukemia_bsh_2025':
        return const <String>[
          'BSH — 2025 Guideline for the Treatment of Chronic Lymphocytic Leukaemia — https://cms.b-s-h.org.uk/guidelines/guidelines/2025-british-society-for-haematology-guideline-for-the-treatment-of-chronic-lymphocytic-leukaemia',
          'GELLC — Guidelines for Diagnosis and Treatment of Chronic Lymphocytic Leukemia/Small Lymphocytic Lymphoma (2025) — https://pubmed.ncbi.nlm.nih.gov/39799061/',
          'iwCLL — Guidelines for Diagnosis, Indications for Treatment, Response Assessment and Supportive Management of CLL — https://pubmed.ncbi.nlm.nih.gov/29540348/',
        ];

      case 'panic_disorder_nice_2026':
        return const <String>[
          'NICE — Generalised Anxiety Disorder and Panic Disorder in Adults: Management (CG113), current in 2026 — https://www.nice.org.uk/guidance/cg113',
          'NICE — Panic Disorder Recommendations, CG113 — https://www.nice.org.uk/guidance/cg113/chapter/Recommendations',
          'NICE — CG113 Update Information, April 2026 — https://www.nice.org.uk/guidance/CG113/chapter/update-information',
        ];

      case 'social_anxiety_disorder_nice_2026':
        return const <String>[
          'NICE — Social Anxiety Disorder: Recognition, Assessment and Treatment (CG159) — https://www.nice.org.uk/guidance/cg159',
          'NICE — Social Anxiety Disorder Recommendations — https://www.nice.org.uk/Guidance/CG159/chapter/recommendations',
          'NICE — Social Anxiety Disorder Treatments for Adults — https://www.nice.org.uk/guidance/cg159/ifp/chapter/Treatments-for-adults',
        ];

      case 'obsessive_compulsive_disorder_nice_2026':
        return const <String>[
          'NICE — Obsessive-Compulsive Disorder and Body Dysmorphic Disorder: Treatment (CG31), reviewed 2024 with update in progress — https://www.nice.org.uk/guidance/cg31',
          'NICE — OCD/BDD Recommendations — https://www.nice.org.uk/guidance/cg31/chapter/Recommendations',
          'NICE — OCD/BDD Guidance History and Current Review Status — https://www.nice.org.uk/guidance/cg31/history',
        ];

      case 'posttraumatic_stress_disorder_va_dod_2023':
        return const <String>[
          'VA/DoD — Clinical Practice Guideline for Management of PTSD and Acute Stress Disorder (2023) — https://www.healthquality.va.gov/guidelines/MH/ptsd/',
          'VA/DoD — PTSD/ASD Full Clinical Practice Guideline — https://www.healthquality.va.gov/guidelines/MH/ptsd/VA-DoD-CPG-PTSD-Full-CPG-Edited-11162024.pdf',
          'VA National Center for PTSD — Overview of Psychotherapy for PTSD — https://www.ptsd.va.gov/professional/treat/txessentials/overview_therapy.asp',
        ];

      case 'anorexia_nervosa_apa_nice_current':
        return const <String>[
          'APA — Practice Guideline for the Treatment of Patients With Eating Disorders (2023) — https://psychiatryonline.org/doi/pdf/10.1176/appi.ajp.23180001',
          'NICE — Eating Disorders: Recognition and Treatment (NG69), current review status — https://www.nice.org.uk/guidance/NG69',
          'NICE — Eating Disorders Recommendations: Anorexia Nervosa — https://www.nice.org.uk/guidance/NG69/chapter/recommendations',
        ];

      case 'bulimia_nervosa_apa_nice_current':
        return const <String>[
          'APA — Practice Guideline for the Treatment of Patients With Eating Disorders (2023): Bulimia Nervosa — https://psychiatryonline.org/doi/pdf/10.1176/appi.ajp.23180001',
          'NICE — Eating Disorders: Recognition and Treatment (NG69) — https://www.nice.org.uk/guidance/NG69',
          'NICE — Eating Disorders Recommendations: Bulimia Nervosa — https://www.nice.org.uk/guidance/NG69/chapter/recommendations',
        ];

      case 'opioid_use_disorder_asam_samhsa_current':
        return const <String>[
          'ASAM — National Practice Guideline for Treatment of Opioid Use Disorder, Focused Update — https://www.asam.org/quality-care/clinical-guidelines/national-practice-guideline',
          'SAMHSA — Medications for Opioid Use Disorder, TIP 63 — https://library.samhsa.gov/product/tip-63-medications-opioid-use-disorder-full-document/pep21-02-01-002',
          'SAMHSA — Substance Use Disorder Treatment Options, current 2026 — https://www.samhsa.gov/substance-use/treatment/options',
        ];

      case 'cannabis_use_disorder_who_samhsa_current':
        return const <String>[
          'WHO — mhGAP Guideline for Mental, Neurological and Substance Use Disorders, Third Edition — https://www.who.int/publications/i/item/9789240084278',
          'SAMHSA — Brief Counseling for Marijuana Dependence: Manual for Treating Adults — https://library.samhsa.gov/sites/default/files/sma15-4211.pdf',
          'SAMHSA — Substance Use Disorder Treatment Options, current 2026 — https://www.samhsa.gov/substance-use/treatment/options',
        ];

      case 'chronic_insomnia_aasm_current':
        return const <String>[
          'AASM — Practice Guidelines: Insomnia — https://aasm.org/clinical-resources/practice-standards/practice-guidelines/',
          'AASM — Behavioral and Psychological Treatments for Chronic Insomnia Disorder in Adults — https://jcsm.aasm.org/doi/10.5664/jcsm.8986',
          'AASM — Pharmacologic Treatment of Chronic Insomnia in Adults — https://jcsm.aasm.org/doi/10.5664/jcsm.6470',
        ];

      case 'borderline_personality_disorder_nice_current':
        return const <String>[
          'NICE — Borderline Personality Disorder: Recognition and Management (CG78), reviewed 2024 — https://www.nice.org.uk/guidance/cg78',
          'NICE — Borderline Personality Disorder Recommendations — https://www.nice.org.uk/guidance/cg78/chapter/Recommendations',
          'NICE — Borderline Personality Disorder Update Information — https://www.nice.org.uk/guidance/cg78/chapter/Update-information',
        ];

      case 'amyotrophic_lateral_sclerosis_ean_2024':
        return const <String>[
          'EAN/ERN EURO-NMD — Guideline on Management of Amyotrophic Lateral Sclerosis (2024) — https://pubmed.ncbi.nlm.nih.gov/38470068/',
          'NICE — Motor Neurone Disease: Assessment and Management (NG42), current with 2026 updates — https://www.nice.org.uk/guidance/ng42',
          'Japanese Society of Neurology — ALS Clinical Practice Guideline Update 2023 — https://pubmed.ncbi.nlm.nih.gov/38522911/',
        ];

      case 'diabetic_peripheral_neuropathy_ada_aan_2026':
        return const <String>[
          'ADA — Standards of Care in Diabetes 2026: Retinopathy, Neuropathy, and Foot Care — https://diabetesjournals.org/care/article/49/Supplement_1/S261/163919/12-Retinopathy-Neuropathy-and-Foot-Care-Standards',
          'AAN — Oral and Topical Treatment of Painful Diabetic Polyneuropathy Guideline Update, reaffirmed 2025 — https://www.aan.com/Guidelines/home/GuidelineDetail/1037',
          'Neurology/AAN — Painful Diabetic Polyneuropathy Practice Guideline Update Summary — https://pubmed.ncbi.nlm.nih.gov/34965987/',
        ];

      case 'carpal_tunnel_syndrome_aaos_2024':
        return const <String>[
          'AAOS/ASSH — Clinical Practice Guideline on Management of Carpal Tunnel Syndrome (2024) — https://www.aaos.org/quality/quality-programs/upper-extremity-programs/carpal-tunnel-syndrome/',
          'AAOS — Carpal Tunnel Syndrome Guideline Update and Evidence Summary (2024) — https://www.aaos.org/aaos-home/newsroom/press-releases/carpal-tunnel-syndrome-aaos-updates-clinical-practice-guideline/',
          'AAOS/ASSH — Carpal Tunnel Syndrome Clinical Practice Guideline Summary — https://pubmed.ncbi.nlm.nih.gov/39637428/',
        ];

      case 'idiopathic_normal_pressure_hydrocephalus_2021':
        return const <String>[
          'Japanese Society of Normal Pressure Hydrocephalus — iNPH Management Guidelines, Third Edition — https://pmc.ncbi.nlm.nih.gov/articles/PMC7905302/',
          'PubMed — Idiopathic Normal Pressure Hydrocephalus Guidelines, Third Edition — https://pubmed.ncbi.nlm.nih.gov/33455998/',
          'Neurologia Medico-Chirurgica/J-STAGE — iNPH Guidelines, Third Edition — https://www.jstage.jst.go.jp/article/nmc/61/2/61_st.2020-0292/_article',
        ];

      case 'essential_tremor_mds_2026':
        return const <String>[
          'MDS — Tremor & Essential Tremor Clinical Overview; 2026 EBM Treatment Review listed as current key recommendation — https://www.movementdisorders.org/MDS/About/Movement-Disorder-Overviews/Tremor--Essential-Tremor.htm',
          'MDS Task Force — Consensus Statement on Classification of Tremors — https://pubmed.ncbi.nlm.nih.gov/29193359/',
          'AAN — Evidence-Based Guideline Update: Treatment of Essential Tremor — https://www.neurology.org/doi/10.1212/WNL.0b013e318236f0fd',
        ];

      case 'huntington_disease_dgn_ehdn_2023':
        return const <String>[
          'German Neurological Society — Symptomatic Treatment Options for Huntington Disease Guideline (2023) — https://pubmed.ncbi.nlm.nih.gov/37968732/',
          'European Huntington Disease Network — International Guidelines for Treatment of Huntington Disease — https://pubmed.ncbi.nlm.nih.gov/31333565/',
          'NICE — Rehabilitation for Chronic Neurological Disorders (NG252, 2025), including Huntington Disease — https://www.nice.org.uk/guidance/ng252',
        ];

      case 'dystonia_mds_ean_current':
        return const <String>[
          'Movement Disorder Society — Dystonia Clinical Overview and Key Guideline Recommendations — https://www.movementdisorders.org/MDS/About/Movement-Disorder-Overviews/Dystonia.htm',
          'MDS-European Section/EFNS — Guidelines on Diagnosis and Treatment of Primary Dystonia — https://www.movementdisorders.org/MDS-Files1/MDS-ES/guidelines_on_dystonia.pdf',
          'EAN/MDS-ES — Subspecialty Scientific Panel on Movement Disorders and European Dystonia Guidelines — https://www.movementdisorders.org/MDS/Regional-Sections/European-Section/EFNS-MDS-ES-Scientist-Panel-on-PD-and-Other-Movement-Disorders.htm',
        ];

      case 'restless_legs_syndrome_aasm_2025':
        return const <String>[
          'AASM — Treatment of Restless Legs Syndrome and Periodic Limb Movement Disorder Clinical Practice Guideline (2025) — https://aasm.org/clinical-resources/practice-standards/practice-guidelines/',
          'AASM — New Guideline Provides Treatment Recommendations for Restless Legs Syndrome — https://aasm.org/new-guideline-provides-treatment-recommendations-for-restless-legs-syndrome/',
          'AASM — Full RLS/PLMD Clinical Practice Guideline — https://aasm.org/wp-content/uploads/2024/03/Treatment-of-RLS-and-PLMD-CPG.pdf',
        ];

      case 'nutritional_peripheral_neuropathy_nice_2026':
        return const <String>[
          'NICE — Vitamin B12 Deficiency in Over 16s: Diagnosis and Management (NG239, 2024) — https://www.nice.org.uk/guidance/ng239',
          'NICE — Suspected Neurological Conditions: Peripheral Neuropathy Recognition and Referral — https://www.nice.org.uk/guidance/ng127/chapter/Recommendations-for-adults-aged-over-16',
          'UK Department of Health and Social Care — Clinical Guidelines for Alcohol Treatment: Thiamine and Neurological Complications, updated 2026 — https://www.gov.uk/guidance/clinical-guidelines-for-alcohol-treatment/10-pharmacological-interventions',
        ];

      case 'degenerative_cervical_myelopathy_aospine_2025':
        return const <String>[
          'AO Spine — Clinical Practice Recommendations for Diagnosis and Management of Degenerative Cervical Myelopathy (2025) — https://pubmed.ncbi.nlm.nih.gov/40257837/',
          'AO Spine — Knowledge Forum Spinal Cord Injury: Current DCM Clinical Practice Recommendations — https://www.aofoundation.org/spine/research/research-programs/knowledge-forum-spinal-cord-injury',
          'AO Spine/Global Spine Journal — Clinical Practice Guideline for Management of Degenerative Cervical Myelopathy — https://pubmed.ncbi.nlm.nih.gov/29164035/',
        ];

      case 'transient_ischemic_attack_aha_2023':
        return const <String>[
          'AHA — Diagnosis, Workup, Risk Reduction of Transient Ischemic Attack in the Emergency Department: Scientific Statement (2023) — https://professional.heart.org/en/science-news/diagnosis-workup-risk-reduction-of-transient-ischemic-attack-in-the-emergency-department-setting',
          'AHA — TIA Scientific Statement Hub (2023) — https://professional.heart.org/en/guidelines-statements/diagnosis-workup-risk-reduction-of-transient-ischemic-attack-in-the-emergencystr0000000000000418',
          'AHA/ASA — Guideline for Prevention of Stroke in Patients With Stroke and TIA (2021) — https://professional.heart.org/en/science-news/2021-guideline-for-the-prevention-of-stroke-in-patients-with-stroke-and-transient-ischemic-attack',
        ];

      case 'spontaneous_intracerebral_hemorrhage_aha_2022':
        return const <String>[
          'AHA/ASA — Guideline for Management of Patients With Spontaneous Intracerebral Hemorrhage (2022) — https://professional.heart.org/en/guidelines-statements/2022-guideline-for-the-management-of-patients-with-spontaneous-intracerebralstr0000000000000407',
          'Stroke — Full AHA/ASA Spontaneous Intracerebral Hemorrhage Guideline (2022) — https://www.ahajournals.org/doi/10.1161/STR.0000000000000407',
          'AHA — Top Things to Know: Spontaneous Intracerebral Hemorrhage Guideline (2022) — https://professional.heart.org/en/science-news/2022-guideline-for-the-management-of-patients-with-spontaneous-intracerebral-hemorrhage/top-things-to-know',
        ];

      case 'aneurysmal_subarachnoid_hemorrhage_aha_2023':
        return const <String>[
          'AHA/ASA — Guideline for Management of Patients With Aneurysmal Subarachnoid Hemorrhage (2023) — https://professional.heart.org/en/guidelines-statements/2023-guideline-for-the-management-of-patients-with-aneurysmal-subarachnoidstr0000000000000436',
          'AHA — Science News: Aneurysmal Subarachnoid Hemorrhage Guideline (2023) — https://professional.heart.org/en/science-news/2023-guideline-for-the-management-of-patients-with-aneurysmal-subarachnoid-hemorrhage',
          'AHA — Top Things to Know: Aneurysmal Subarachnoid Hemorrhage Guideline (2023) — https://professional.heart.org/en/science-news/2023-guideline-for-the-management-of-patients-with-aneurysmal-subarachnoid-hemorrhage/top-things-to-know',
        ];

      case 'cerebral_venous_thrombosis_aha_2024':
        return const <String>[
          'AHA — Diagnosis and Management of Cerebral Venous Thrombosis: Scientific Statement (2024) — https://professional.heart.org/en/science-news/diagnosis-and-management-of-cerebral-venous-thrombosis',
          'AHA — Cerebral Venous Thrombosis Scientific Statement Hub (2024) — https://professional.heart.org/en/guidelines-statements/diagnosis-and-management-of-cerebral-venous-thrombosis-a-scientific-statementstr0000000000000456',
          'AHA — Top Things to Know: Cerebral Venous Thrombosis (2024) — https://professional.heart.org/en/science-news/diagnosis-and-management-of-cerebral-venous-thrombosis/top-things-to-know',
        ];

      case 'trigeminal_neuralgia_ean_2019':
        return const <String>[
          'EAN — European Academy of Neurology Guideline on Trigeminal Neuralgia (2019) — https://pubmed.ncbi.nlm.nih.gov/30860637/',
          'European Journal of Neurology — EAN Trigeminal Neuralgia Guideline, DOI 10.1111/ene.13950 — https://doi.org/10.1111/ene.13950',
          'EAN — Guideline Reference Center listing current Trigeminal Neuralgia guideline — https://www.ean.org/research/ean-guidelines/guideline-reference-center',
        ];

      case 'cluster_headache_ean_2023':
        return const <String>[
          'EAN — European Academy of Neurology Guidelines on Treatment of Cluster Headache (2023) — https://pubmed.ncbi.nlm.nih.gov/37515405/',
          'European Journal of Neurology — EAN Cluster Headache Guideline (2023) — https://doi.org/10.1111/ene.15956',
          'EAN — Cluster Headache Guideline Infographic, current guideline collection — https://www.ean.org/fileadmin/user_upload/ean/ean/research/EAN_Guidelines/Infographic_Guidelines_2025_Online_version.pdf',
        ];

      case 'tension_type_headache_nice_2025':
        return const <String>[
          'NICE — Headaches in over 12s: Diagnosis and Management (CG150), updated June 2025 — https://www.nice.org.uk/guidance/cg150',
          'NICE — Recommendations: Tension-Type Headache Diagnosis and Management, updated 2025 — https://www.nice.org.uk/guidance/cg150/chapter/recommendations',
          'NICE — Quality Standard: Classification of Headache Type, source CG150 updated 2025 — https://www.nice.org.uk/guidance/qs42/chapter/quality-statement-1-classification-of-headache-type',
        ];

      case 'bppv_aao_hns_2026':
        return const <String>[
          'AAO-HNSF — Clinical Practice Guideline: Benign Paroxysmal Positional Vertigo (Update) — https://www.entnet.org/quality-practice/quality-products/clinical-practice-guidelines/bppv/',
          'AAO-HNSF — 2026 Standard BPPV Management Measure supporting the current BPPV guideline — https://www.entnet.org/wp-content/uploads/2025/12/2026_AAO32_12192025.pdf',
          'PubMed — Clinical Practice Guideline: Benign Paroxysmal Positional Vertigo Update — https://pubmed.ncbi.nlm.nih.gov/28248609/',
        ];

      case 'vestibular_neuritis_barany_2022':
        return const <String>[
          'Bárány Society — Acute Unilateral Vestibulopathy/Vestibular Neuritis Diagnostic Criteria (2022) — https://pmc.ncbi.nlm.nih.gov/articles/PMC9661346/',
          'PubMed — Bárány Society Vestibular Neuritis Consensus Diagnostic Criteria (2022) — https://pubmed.ncbi.nlm.nih.gov/35723133/',
          'Journal of Vestibular Research — Acute Unilateral Vestibulopathy/Vestibular Neuritis Consensus (2022) — https://journals.sagepub.com/doi/full/10.3233/VES-220201',
        ];

      case 'bell_palsy_aao_hns_2026':
        return const <String>[
          'AAO-HNSF — Clinical Practice Guideline: Bell’s Palsy — https://www.entnet.org/quality-practice/quality-products/clinical-practice-guidelines/bells-palsy/',
          'AAO-HNSF — Bell’s Palsy 2026 Quality Measure referencing current guideline recommendations — https://www.entnet.org/resource/aao13-bells-palsy-inappropriate-use-of-magnetic-resonance-imaging-or-computed-tomography-scan-2026/',
          'AAO-HNSF — Bell’s Palsy Guideline Press Release and Key Action Statements — https://www.entnet.org/resource/aao-hnsf-clinical-practice-guideline-bells-palsy-press-release-fact-sheet/',
        ];

      case 'leptospirosis_cdc_2026':
        return const <String>[
          'CDC — Clinical Overview of Leptospirosis (2026) — https://www.cdc.gov/leptospirosis/hcp/clinical-overview/index.html',
          'CDC Yellow Book 2026 — Leptospirosis — https://www.cdc.gov/yellow-book/hcp/travel-associated-infections-diseases/leptospirosis.html',
          'CDC/CSTE — Leptospirosis 2025 Case Definition — https://ndc.services.cdc.gov/case-definitions/leptospirosis/',
        ];

      case 'chagas_who_paho_2026':
        return const <String>[
          'WHO — Chagas Disease (American Trypanosomiasis): Questions and Answers (2026) — https://www.who.int/news-room/questions-and-answers/item/chagas-disease',
          'WHO — Chagas Disease Fact Sheet (2026) — https://www.who.int/news-room/fact-sheets/detail/chagas-disease-%28american-trypanosomiasis%29',
          'PAHO/WHO — Guidelines for the Diagnosis and Treatment of Chagas Disease — https://www.who.int/publications/i/item/9789275120439',
        ];

      case 'visceral_leishmaniasis_who_2026':
        return const <String>[
          'WHO — Updated Treatment Guidelines for Visceral Leishmaniasis and PKDL (2026) — https://www.who.int/news/item/29-07-2026-who-updates-treatment-guidelines-on-visceral-and-post-kala-azar-dermal-leishmaniasis',
          'WHO — Leishmaniasis Health Topic and 2026 Visceral Leishmaniasis Guideline Hub — https://www.who.int/health-topics/leishmaniasis',
          'CDC — Clinical Care of Leishmaniasis: Visceral Leishmaniasis — https://www.cdc.gov/leishmaniasis/hcp/clinical-care/index.html',
        ];

      case 'yellow_fever_who_cdc_2026':
        return const <String>[
          'WHO — Guidelines for Clinical Management of Arboviral Diseases: Dengue, Chikungunya, Zika and Yellow Fever (2025) — https://www.who.int/publications/i/item/9789240111110',
          'CDC — Clinical Features and Diagnosis of Yellow Fever (2025) — https://www.cdc.gov/yellow-fever/hcp/clinical-diagnosis/index.html',
          'CDC — Yellow Fever Vaccine Information for Healthcare Providers (2026) — https://www.cdc.gov/yellow-fever/hcp/vaccine/index.html',
        ];

      case 'chikungunya_who_cdc_2026':
        return const <String>[
          'WHO — Guidelines for Clinical Management of Arboviral Diseases: Chikungunya (2025) — https://www.who.int/publications/i/item/9789240111110',
          'CDC — Treatment and Prevention of Chikungunya Virus Disease (2026) — https://www.cdc.gov/chikungunya/hcp/treatment-prevention/index.html',
          'CDC Yellow Book 2026 — Chikungunya — https://www.cdc.gov/yellow-book/hcp/travel-associated-infections-diseases/chikungunya.html',
        ];

      case 'zika_who_cdc_2025':
        return const <String>[
          'WHO — Guidelines for Clinical Management of Arboviral Diseases: Zika (2025) — https://www.who.int/publications/i/item/9789240111110',
          'CDC — Clinical Testing and Diagnosis for Zika Virus Disease (2025) — https://www.cdc.gov/zika/hcp/diagnosis-testing/index.html',
          'CDC — Treatment and Prevention of Zika Virus Disease (2025) — https://www.cdc.gov/zika/hcp/clinical-care/index.html',
        ];

      case 'typhoid_fever_cdc_2026':
        return const <String>[
          'CDC — Clinical Guidance for Typhoid Fever and Paratyphoid Fever — https://www.cdc.gov/typhoid-fever/hcp/clinical-guidance/index.html',
          'CDC Yellow Book 2026 — Typhoid and Paratyphoid Fever — https://www.cdc.gov/yellow-book/hcp/travel-associated-infections-diseases/typhoid-and-paratyphoid-fever.html',
          'CDC — Clinician Resources for Typhoid Fever and Paratyphoid Fever (2025) — https://www.cdc.gov/typhoid-fever/hcp/clinician-resources/index.html',
        ];

      case 'brucellosis_cdc_2026':
        return const <String>[
          'CDC — Clinical Overview of Brucellosis (2026) — https://www.cdc.gov/brucellosis/hcp/clinical-overview/index.html',
          'CDC — Laboratory Risks for Brucellosis (2026) — https://www.cdc.gov/brucellosis/hcp/laboratory-risks/index.html',
          'WHO — Brucellosis in Humans and Animals: Clinical Diagnosis and Treatment Reference — https://iris.who.int/bitstream/10665/43597/1/WHO_CDS_EPR_2006.7_eng.pdf',
        ];

      case 'spotted_fever_rickettsiosis_cdc_2025':
        return const <String>[
          'CDC — Clinical Care of Other Spotted Fever Rickettsioses (2025) — https://www.cdc.gov/other-spotted-fever/hcp/clinical-care/index.html',
          'CDC — Clinical Care of Rocky Mountain Spotted Fever (2025) — https://www.cdc.gov/rocky-mountain-spotted-fever/hcp/clinical-care/index.html',
          'CDC — Clinical and Laboratory Diagnosis for Other Spotted Fever Rickettsioses — https://www.cdc.gov/other-spotted-fever/hcp/diagnosis-testing/index.html',
        ];

      case 'mpox_who_cdc_2026':
        return const <String>[
          'WHO — Clinical Management and Infection Prevention and Control for Mpox: Living Guideline (2025) — https://iris.who.int/bitstream/handle/10665/381567/B09434-eng.pdf?sequence=1',
          'CDC — Caring for Patients with Monkeypox (2026) — https://www.cdc.gov/mpox/hcp/clinical-care/index.html',
          'CDC — Tecovirimat (TPOXX) for Treatment of Monkeypox (2026) — https://www.cdc.gov/monkeypox/hcp/clinical-care/tecovirimat.html',
        ];

      case 'herpes_zoster_cdc_nih_2026':
        return const <String>[
          'CDC — Clinical Overview of Shingles (Herpes Zoster) — https://www.cdc.gov/shingles/hcp/clinical-overview/index.html',
          'NIH — Varicella-Zoster Virus Disease: Adult and Adolescent Opportunistic Infections, updated 2026 — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-opportunistic-infections/varicella-zoster',
          'CDC — Shingles Vaccine Recommendations for Healthcare Professionals — https://www.cdc.gov/shingles/hcp/vaccine-considerations/index.html',
        ];

      case 'varicella_cdc_nih_2026':
        return const <String>[
          'CDC — Clinical Overview of Chickenpox (Varicella) — https://www.cdc.gov/chickenpox/hcp/clinical-overview/index.html',
          'CDC — Clinical Guidance for People at Risk for Severe Varicella — https://www.cdc.gov/chickenpox/hcp/clinical-guidance/index.html',
          'NIH — Varicella-Zoster Virus Disease: Adult and Adolescent Opportunistic Infections, updated 2026 — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-opportunistic-infections/varicella-zoster',
        ];

      case 'infectious_mononucleosis_ebv_cdc':
        return const <String>[
          'CDC — About Infectious Mononucleosis (Mono) — https://www.cdc.gov/epstein-barr/about/mononucleosis.html',
          'CDC — Clinical Overview of Epstein-Barr Virus (EBV) — https://www.cdc.gov/epstein-barr/hcp/clinical-overview/index.html',
          'CDC — Laboratory Testing for Epstein-Barr Virus (EBV) — https://www.cdc.gov/epstein-barr/php/laboratories/index.html',
        ];

      case 'cytomegalovirus_disease_nih_2026':
        return const <String>[
          'NIH — Cytomegalovirus Disease: Adult and Adolescent Opportunistic Infections, reviewed 2026 — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-opportunistic-infections/cytomegalovirus',
          'CDC — Clinical Overview of CMV and Congenital CMV — https://www.cdc.gov/cytomegalovirus/hcp/clinical-overview/index.html',
          'CDC — Cytomegalovirus: Infection Control and Clinical Features — https://www.cdc.gov/infection-control/hcp/healthcare-personnel-epidemiology-control/cytomegalovirus.html',
        ];

      case 'toxoplasmosis_cdc_nih_2026':
        return const <String>[
          'CDC — Clinical Care of Toxoplasmosis, updated 2026 — https://www.cdc.gov/toxoplasmosis/hcp/clinical-care/index.html',
          'CDC — Clinical Overview of Toxoplasmosis — https://www.cdc.gov/toxoplasmosis/hcp/clinical-overview/index.html',
          'NIH — Toxoplasma gondii Encephalitis: Adult and Adolescent Opportunistic Infections — https://clinicalinfo.hiv.gov/en/guidelines/hiv-clinical-guidelines-adult-and-adolescent-opportunistic-infections/toxoplasma-gondii',
        ];

      case 'hepatitis_a_cdc_2025':
        return const <String>[
          'CDC — Clinical Overview of Hepatitis A, updated 2025 — https://www.cdc.gov/hepatitis-a/hcp/clinical-overview/index.html',
          'CDC — Clinical Care of Hepatitis A, updated 2025 — https://www.cdc.gov/hepatitis-a/hcp/clinical-care/index.html',
          'CDC — Hepatitis A Resources and Clinical Guidance for Health Care Professionals — https://www.cdc.gov/hepatitis-a/hcp/provider-resources/index.html',
        ];

      case 'cellulitis_ssti_idsa_nice':
        return const <String>[
          'IDSA — Practice Guideline for Diagnosis and Management of Skin and Soft Tissue Infections — https://www.idsociety.org/practice-guideline/skin-and-soft-tissue-infections/',
          'NICE — Cellulitis and Erysipelas: Antimicrobial Prescribing (NG141) — https://www.nice.org.uk/guidance/ng141',
          'NICE — Cellulitis and Erysipelas Antimicrobial Prescribing Visual Summary — https://www.nice.org.uk/guidance/ng141/resources/visual-summary-pdf-6908401837',
        ];

      case 'erysipelas_idsa_nice':
        return const <String>[
          'NICE — Cellulitis and Erysipelas: Antimicrobial Prescribing (NG141) — https://www.nice.org.uk/guidance/ng141',
          'IDSA — Practice Guideline for Diagnosis and Management of Skin and Soft Tissue Infections — https://www.idsociety.org/practice-guideline/skin-and-soft-tissue-infections/',
          'NICE — Cellulitis and Erysipelas Antimicrobial Prescribing Visual Summary — https://www.nice.org.uk/guidance/ng141/resources/visual-summary-pdf-6908401837',
        ];

      case 'osteomyelitis_idsa_pids':
        return const <String>[
          'IDSA — Clinical Practice Guideline for Diagnosis and Treatment of Native Vertebral Osteomyelitis in Adults — https://www.idsociety.org/practice-guideline/vertebral-osteomyelitis/',
          'PIDS/IDSA — Guideline on Diagnosis and Management of Acute Hematogenous Osteomyelitis in Pediatrics — https://www.idsociety.org/practice-guideline/bone-and-joint-infections-aha-osteomyelitis/',
          'PIDS/IDSA — Acute Hematogenous Osteomyelitis in Pediatrics full guideline — https://www.idsociety.org/globalassets/idsa/practice-guidelines/piab027.pdf',
        ];

      case 'septic_arthritis_sanjo_pids_idsa':
        return const <String>[
          'SANJO/EBJIS — Guideline for Management of Septic Arthritis in Native Joints (2023) — https://jbji.copernicus.org/articles/8/29/2023/',
          'PIDS/IDSA — Guideline on Diagnosis and Management of Acute Bacterial Arthritis in Pediatrics (2023) — https://www.idsociety.org/practice-guideline/acute-bacterial-arthritis-in-pediatrics2/',
          'PIDS/IDSA — Acute Bacterial Arthritis in Pediatrics full guideline — https://www.idsociety.org/globalassets/idsa/practice-guidelines/piad089.pdf',
        ];

      case 'poststreptococcal_infection_related_gn_kdigo':
        return const <String>[
          'KDIGO — Clinical Practice Guideline for Glomerular Diseases: Infection-Related Glomerulonephritis (2021; continuously reassessed) — https://kdigo.org/guidelines/gd/',
          'KDIGO — Full Glomerular Diseases Guideline, Chapter 7 Infection-Related Glomerulonephritis (2021) — https://kdigo.org/wp-content/uploads/2021/10/KDIGO-2021-Guideline-for-the-Management-of-Glomerular-Diseases.pdf',
          'KDIGO Glomerular Diseases Work Group — Practice Guideline indexed in PubMed — https://pubmed.ncbi.nlm.nih.gov/34556256/',
        ];

      case 'anti_gbm_goodpasture_kdigo':
        return const <String>[
          'KDIGO — Glomerular Diseases Guideline: Anti-GBM Disease (2021; continuously reassessed) — https://kdigo.org/guidelines/gd/',
          'KDIGO — Full Glomerular Diseases Guideline, Chapter 11 Anti-GBM Antibody Glomerulonephritis — https://kdigo.org/wp-content/uploads/2021/10/KDIGO-2021-Guideline-for-the-Management-of-Glomerular-Diseases.pdf',
          'KDIGO — Executive Summary of the Glomerular Diseases Guideline — https://pubmed.ncbi.nlm.nih.gov/34556300/',
        ];

      case 'membranous_nephropathy_kdigo':
        return const <String>[
          'KDIGO — Glomerular Diseases Guideline: Membranous Nephropathy (2021; continuously reassessed) — https://kdigo.org/guidelines/gd/',
          'KDIGO — Key Takeaways for Clinicians: Membranous Nephropathy — https://kdigo.org/guidelines/gd/kdigo-gd-guideline-key-takeaways-for-clinicians-membranous-nephropathy/',
          'CARI — 2025 Commentary on KDIGO Glomerular Diseases Guidance, including Membranous Nephropathy — https://onlinelibrary.wiley.com/doi/10.1111/nep.70119',
        ];

      case 'fsgs_kdigo':
        return const <String>[
          'KDIGO — Glomerular Diseases Guideline: Focal Segmental Glomerulosclerosis (2021; continuously reassessed) — https://kdigo.org/guidelines/gd/',
          'KDIGO — Key Takeaways for Clinicians: FSGS — https://kdigo.org/wp-content/uploads/2017/02/KDIGO-Glomerular-Disease-Guideline-Key-Takeaways.pdf',
          'KDIGO Glomerular Diseases Work Group — Full Practice Guideline indexed in PubMed — https://pubmed.ncbi.nlm.nih.gov/34556256/',
        ];

      case 'hemolytic_uremic_syndrome_complement_2026':
        return const <String>[
          'KDIGO — Complement-Mediated Kidney Diseases: Atypical HUS and C3G Controversies Conference Scope (2026) — https://kdigo.org/wp-content/uploads/2025/08/KDIGO-Complement-2026_Scope-of-Work-for-Public-Review.pdf',
          'Brazilian Society of Nephrology — Expert Consensus on Diagnosis and Treatment of Atypical HUS (2024/2025) — https://pmc.ncbi.nlm.nih.gov/articles/PMC11804885/',
          'Expert Consensus — Individualised Management of Atypical Hemolytic Uremic Syndrome in Adults (2023) — https://pubmed.ncbi.nlm.nih.gov/38105887/',
        ];

      case 'acute_interstitial_nephritis_2024':
        return const <String>[
          'Clinical Kidney Journal — Infection- versus Antibiotic-Induced Acute Interstitial Nephritis: Narrative Review (2024) — https://pubmed.ncbi.nlm.nih.gov/38572500/',
          'Nephron — Facing the Challenge of Drug-Induced Acute Interstitial Nephritis (2023) — https://pubmed.ncbi.nlm.nih.gov/35830831/',
          'Nature Reviews Nephrology — Urinary CXCL9 as a Biomarker for Acute Interstitial Nephritis (2023) — https://www.nature.com/articles/s41581-023-00749-2',
        ];

      case 'renal_tubular_acidosis_core_2025':
        return const <String>[
          'American Journal of Kidney Diseases — Renal Tubular Acidosis: Core Curriculum 2025 — https://pubmed.ncbi.nlm.nih.gov/39864011/',
          'Clinical Journal of the ASN — Primary Distal Renal Tubular Acidosis: Toward Optimal Correction (2024) — https://pubmed.ncbi.nlm.nih.gov/38967973/',
          'Indian Journal of Endocrinology and Metabolism — Approach to Renal Tubular Acidosis: Review (2026) — https://pubmed.ncbi.nlm.nih.gov/41918597/',
        ];

      case 'interstitial_cystitis_bladder_pain_2026':
        return const <String>[
          'EAU — Guidelines on Chronic Pelvic Pain: Primary Bladder Pain Syndrome (2026) — https://uroweb.org/guidelines/chronic-pelvic-pain',
          'EAU — Diagnostic Evaluation of Primary Bladder Pain Syndrome (2026) — https://uroweb.org/guidelines/chronic-pelvic-pain/chapter/diagnostic-evaluation',
          'AUA — Diagnosis and Treatment of Interstitial Cystitis/Bladder Pain Syndrome Guideline (2022) — https://www.auanet.org/documents/Guidelines/PDF/IC_BPS_8.30.22.pdf',
        ];

      case 'benign_prostatic_hyperplasia_luts_2026':
        return const <String>[
          'EAU — Guidelines on Management of Non-neurogenic Male LUTS / Benign Prostatic Obstruction (2026) — https://uroweb.org/guidelines/management-of-non-neurogenic-male-luts',
          'EAU — 2026 Male LUTS Guideline Summary of Changes — https://uroweb.org/guidelines/management-of-non-neurogenic-male-luts/summary-of-changes/2026',
          'AUA — Management of LUTS Attributed to Benign Prostatic Hyperplasia Guideline, amended 2023 — https://www.auanet.org/documents/Guidelines/PDF/2023%20Guidelines/BPH%20Unabridged%2009-26-23%20Final.pdf',
        ];

      case 'bacterial_prostatitis_eau_2026':
        return const <String>[
          'EAU — Guidelines on Urological Infections: Bacterial Prostatitis (2026) — https://uroweb.org/guidelines/urological-infections',
          'EAU — Urological Infections Guideline, Bacterial Prostatitis chapter (2026) — https://uroweb.org/guidelines/urological-infections/chapter/the-guideline',
          'EAU — Urological Infections 2026 Summary of Changes — https://uroweb.org/guidelines/urological-infections/summary-of-changes',
        ];

      case 'arginine_vasopressin_deficiency_ese_es_2026':
        return const <String>[
          'ESE/Endocrine Society — Joint Arginine Vasopressin Deficiency Guideline: Updates, Insights and Next Steps (2026) — https://academic.oup.com/ejendo/article/195/Supplement_1/lvag096.042/8754539',
          'Endocrine Society — Hormone Replacement in Hypopituitarism: Central Diabetes Insipidus recommendations — https://www.endocrine.org/clinical-practice-guidelines/hormone-replacement-in-hypopituitarism',
          'JCEM — Arginine Vasopressin Deficiency and Oxytocin Deficiency in the Endocrine Clinic (2026) — https://academic.oup.com/jcem/article/111/4/922/8374621',
        ];

      case 'siadh_hyponatremia_ese':
        return const <String>[
          'ESE/ESICM/ERA — Clinical Practice Guideline on Diagnosis and Treatment of Hyponatraemia — https://www.ese-hormones.org/publications/directory/ese-clinical-guideline-for-the-management-of-hyponatraemia/',
          'European Hyponatraemia Guideline — PubMed indexed recommendations including SIADH — https://pubmed.ncbi.nlm.nih.gov/24562549/',
          'ESE-endorsed review of current severe symptomatic hyponatraemia practice (2025) — https://pubmed.ncbi.nlm.nih.gov/40455923/',
        ];

      case 'hypercalcemia_endocrine_society_2023':
        return const <String>[
          'Endocrine Society — Treatment of Hypercalcemia of Malignancy in Adults Clinical Practice Guideline (2022/2023) — https://support.endocrine.org/clinical-practice-guidelines/hypercalcemia',
          'Fifth International Workshop — Evaluation and Management of Primary Hyperparathyroidism (2022) — https://pubmed.ncbi.nlm.nih.gov/36245251/',
          'Endocrine Society — Clinical Practice Guidelines repository, Bone and Mineral disorders — https://www.endocrine.org/clinical-practice-guidelines',
        ];

      case 'hypocalcemia_hypoparathyroidism_ese_2025':
        return const <String>[
          'ESE — Revised Clinical Practice Guideline: Treatment of Chronic Hypoparathyroidism in Adults (2025) — https://pubmed.ncbi.nlm.nih.gov/41231236/',
          'International Panel — Best Practice Recommendations for Diagnosis and Management of Hypoparathyroidism (2025) — https://pubmed.ncbi.nlm.nih.gov/40581321/',
          'Second International Workshop — Evaluation and Management of Hypoparathyroidism (2022) — https://pubmed.ncbi.nlm.nih.gov/36054621/',
        ];

      case 'hypomagnesemia_core_curriculum_2024':
        return const <String>[
          'American Journal of Kidney Diseases — Magnesium Disorders: Core Curriculum 2024 — https://pubmed.ncbi.nlm.nih.gov/38372687/',
          'Mayo Clinic Proceedings — Acquired Disorders of Hypomagnesemia (2023) — https://pubmed.ncbi.nlm.nih.gov/36872194/',
          'KDIGO — CKD Guideline hub for electrolyte and kidney disease context — https://kdigo.org/guidelines/ckd-evaluation-and-management/',
        ];

      case 'hypophosphatemia_consensus_2025':
        return const <String>[
          'BMC Medicine — Evaluation and Supplementation of Hypophosphatemia: Umbrella Review of Guidelines (2025) — https://pubmed.ncbi.nlm.nih.gov/41146174/',
          'Journal of Endocrinological Investigation — Adult Hypophosphatemia Delphi Consensus (2025) — https://pubmed.ncbi.nlm.nih.gov/39377903/',
          'Lancet Diabetes & Endocrinology — Approach to Patients With Hypophosphataemia — https://pubmed.ncbi.nlm.nih.gov/31924563/',
        ];

      case 'severe_hypertriglyceridemia_acc_aha_2026':
        return const <String>[
          'ACC/AHA Multisociety — Guideline on the Management of Dyslipidemia, including Hypertriglyceridemia (2026) — https://www.acc.org/latest-in-cardiology/journal-scans/2026/03/13/15/20/acc-aha-release-new-clinical-guideline-for-managing-dyslipidemia',
          'ACC/AHA — Updated Guideline for Managing Lipids and Triglycerides (2026) — https://www.acc.org/about-acc/press-releases/2026/03/13/18/01/accaha-issue-updated-guideline-for-managing-lipids-cholesterol',
          'ACC — Expert Consensus Decision Pathway on Persistent and Severe Hypertriglyceridemia (2021) — https://www.acc.org/Latest-in-Cardiology/ten-points-to-remember/2021/07/27/21/04/2021-ACC-ECDP-Hypertriglyceridemia',
        ];

      case 'metabolic_syndrome_harmonized':
        return const <String>[
          'AHA — Heart Disease and Stroke Statistics: Metabolic Syndrome definition and burden (2024) — https://www.heart.org/en/-/media/Files/Professional/Quality-Improvement/Get-With-the-Guidelines/Get-With-The-Guidelines-AFIB/AFib-Month/2024-AHA-Statistical-Update.pdf',
          'IDF — Metabolic Syndrome consensus definition and criteria — https://idf.org/about-diabetes/resources/',
          'IDF/NHLBI/AHA and partner societies — Harmonizing the Metabolic Syndrome (2009, current harmonized definition) — https://pubmed.ncbi.nlm.nih.gov/19805654/',
        ];

      case 'hypopituitarism_endocrine_society':
        return const <String>[
          'Endocrine Society — Hormonal Replacement in Hypopituitarism in Adults Clinical Practice Guideline — https://www.endocrine.org/clinical-practice-guidelines/hormone-replacement-in-hypopituitarism',
          'Endocrine Society Guideline — Hypopituitarism indexed in PubMed — https://pubmed.ncbi.nlm.nih.gov/27736313/',
          'Pituitary Society — Hypopituitarism clinical education and current management resource — https://pituitarysociety.org/hypopituitarism/',
        ];

      case 'adrenal_incidentaloma_ese_2023':
        return const <String>[
          'ESE/ENSAT — Clinical Practice Guideline on Management of Adrenal Incidentalomas (2023), endorsed by Endocrine Society — https://www.ese-hormones.org/publications/directory/ese-clinical-practice-guideline-on-the-management-of-adrenal-incidentalomas-in-collaboration-with-the-european-network-for-the-study-of-adrenal-tumors/',
          'European Journal of Endocrinology — Full Adrenal Incidentaloma Guideline (2023) — https://academic.oup.com/ejendo/article/189/1/G1/7198474',
          'ESE/ENSAT Adrenal Incidentaloma Guideline — PubMed indexed (2023) — https://pubmed.ncbi.nlm.nih.gov/37318239/',
        ];

      case 'alcohol_associated_hepatitis_acg_2024':
        return const <String>[
          'ACG — Clinical Guideline: Alcohol-Associated Liver Disease, including alcohol-associated hepatitis (2024) — https://pmc.ncbi.nlm.nih.gov/articles/PMC11040545/',
          'AASLD — Practice Guidelines: Alcohol-Associated Liver Disease — https://www.aasld.org/practice-guidelines',
          'EASL — Clinical Practice Guidelines: Management of Alcohol-Related Liver Disease — https://easl.eu/publication/management-of-alcohol-related-liver-disease/',
        ];

      case 'alcohol_associated_liver_disease_acg_2024':
        return const <String>[
          'ACG — Clinical Guideline: Alcohol-Associated Liver Disease (2024) — https://pmc.ncbi.nlm.nih.gov/articles/PMC11040545/',
          'ACG — Liver: Alcohol-Associated Liver Disease Guideline hub (2024) — https://gi.org/guidelines/',
          'AASLD — Practice Guidelines: Alcohol-Associated Liver Disease — https://www.aasld.org/practice-guidelines',
        ];

      case 'autoimmune_hepatitis_easl_2025':
        return const <String>[
          'EASL — Clinical Practice Guidelines on the Management of Autoimmune Hepatitis (2025) — https://easl.eu/publication/clinical-practice-guidelines-on-the-management-of-autoimmune-hepatitis/',
          'AASLD — Diagnosis and Management of Autoimmune Hepatitis (2019) — https://www.aasld.org/practice-guidelines/management-autoimmune-hepatitis',
          'AASLD — Autoimmune Hepatitis clinical diagnostic review based on current guidance — https://www.aasld.org/liver-fellow-network/core-series/back-basics/back-basics-ana-lyzing-autoimmune-hepatitis',
        ];

      case 'primary_biliary_cholangitis_aasld_2021':
        return const <String>[
          'AASLD — Primary Biliary Cholangitis: 2021 Practice Guidance Update — https://www.aasld.org/practice-guidelines/primary-biliary-cholangitis',
          'AASLD — PBC 2021 Practice Guidance Update indexed in PubMed — https://pubmed.ncbi.nlm.nih.gov/34431119/',
          'EASL — Clinical Practice Guidelines: Diagnosis and Management of Primary Biliary Cholangitis — https://easl.eu/publication/the-diagnosis-and-management-of-patients-with-primary-biliary-cholangitis/',
        ];

      case 'primary_sclerosing_cholangitis_aasld_2022':
        return const <String>[
          'AASLD — Practice Guidance on Primary Sclerosing Cholangitis and Cholangiocarcinoma (2022) — https://www.aasld.org/practice-guidelines/primary-sclerosing-cholangitis-and-cholangiocarcinoma',
          'AASLD/Hepatology — PSC and Cholangiocarcinoma Practice Guidance (2022) — https://aasldpubs.onlinelibrary.wiley.com/doi/10.1002/hep.32771',
          'EASL — Clinical Practice Guidelines on Sclerosing Cholangitis — https://easl.eu/publication/easl-clinical-practice-guidelines-on-sclerosing-cholangitis/',
        ];

      case 'chronic_pancreatitis_acg_2020':
        return const <String>[
          'ACG — Clinical Guideline: Chronic Pancreatitis (2020) — https://gi.org/guidelines/',
          'ACG — Chronic Pancreatitis Guideline indexed in PubMed — https://pubmed.ncbi.nlm.nih.gov/32022720/',
          'AGA — Clinical Practice Update on Endoscopic Approach to Recurrent Acute and Chronic Pancreatitis — https://pubmed.ncbi.nlm.nih.gov/36008176/',
        ];

      case 'exocrine_pancreatic_insufficiency_aga_2023':
        return const <String>[
          'AGA — Clinical Practice Update: Epidemiology, Evaluation and Management of Exocrine Pancreatic Insufficiency (2023) — https://gastro.org/clinical-guidance/epidemiology-evaluation-management-exocrine-pancreatic-insufficiency/',
          'AGA — Best Practice Advice on Exocrine Pancreatic Insufficiency (2023) — https://gastro.org/news/15-pieces-advice-exocrine-pancreatic-insufficiency/',
          'UEG — European Guideline for the Diagnosis and Treatment of Pancreatic Exocrine Insufficiency — https://ueg.eu/a/335',
        ];

      case 'pancreatic_cyst_ipmn_kyoto_2024':
        return const <String>[
          'IAP — International Evidence-Based Kyoto Guidelines for Management of IPMN (2024) — https://www.ahpba.org/wp-content/uploads/2025/02/Kyoto-IPMN-Guidelines-2024.pdf',
          'ACG — Clinical Guideline: Diagnosis and Management of Pancreatic Cysts — https://acgcdn.gi.org/wp-content/uploads/2018/04/ACG-Pancreatic-Cysts-Guideline-Summary.pdf',
          'AGA — Diagnosis and Management of Asymptomatic Neoplastic Pancreatic Cysts — https://gastro.org/clinical-guidance/diagnosis-and-management-of-asymptomatic-neoplastic-pancreatic-cysts/',
        ];

      case 'hereditary_hemochromatosis_easl_2022':
        return const <String>[
          'EASL — Clinical Practice Guidelines on Haemochromatosis (2022) — https://easl.eu/wp-content/uploads/2022/06/PIIS01688278220021121.pdf',
          'EASL — Haemochromatosis Guideline overview (2022) — https://easl.eu/news/cpgs-2022-haemochromatosis/',
          'ACG — Clinical Guideline: Hereditary Hemochromatosis (2019) — https://gi.org/guidelines/',
        ];

      case 'wilson_disease_easl_2025':
        return const <String>[
          'EASL-ERN — Clinical Practice Guidelines on the Management of Wilson Disease (2025) — https://easl.eu/news/easl-cpgs-wilsons-disease/',
          'AASLD — Diagnosis and Treatment of Wilson Disease: 2022 Practice Guidance — https://www.aasld.org/practice-guidelines/diagnosis-and-treatment-wilson-disease',
          'AASLD — Wilson Disease clinical education based on current guidance — https://www.aasld.org/liver-fellow-network/core-series/practice-questions/hepatology-practice-questions-edition-2',
        ];

      case 'peptic_ulcer_disease_esge_2026':
        return const <String>[
          'ESGE — Endoscopic Diagnosis and Management of Peptic Ulcer Bleeding: Guideline Update (2026) — https://www.esge.com/guidelines',
          'ACG — Clinical Guideline: Upper Gastrointestinal and Ulcer Bleeding (2021) — https://pubmed.ncbi.nlm.nih.gov/33929377/',
          'ACG — Clinical Guideline: Treatment of Helicobacter pylori Infection (2024) — https://gi.org/journals-publications/ebgi/schoenfeld_sep2024/',
        ];

      case 'nsaid_gastropathy_ulcer_prevention':
        return const <String>[
          'ACG — Guidelines for Prevention of NSAID-Related Ulcer Complications — https://pubmed.ncbi.nlm.nih.gov/19240698/',
          'NICE — Gastro-oesophageal Reflux Disease and Dyspepsia in Adults: Investigation and Management (CG184) — https://www.nice.org.uk/guidance/cg184',
          'ESGE — Peptic Ulcer Bleeding Guideline Update (2026) — https://www.esge.com/guidelines',
        ];

      case 'functional_dyspepsia_bsg_2022':
        return const <String>[
          'BSG — Guidelines on the Management of Functional Dyspepsia (2022) — https://gut.bmj.com/content/71/9/1697',
          'ACG/CAG — Clinical Guideline: Management of Dyspepsia (2017) — https://pubmed.ncbi.nlm.nih.gov/28631728/',
          'NICE — Dyspepsia and GORD in Adults (CG184) — https://www.nice.org.uk/guidance/cg184',
        ];

      case 'gastroparesis_aga_2025':
        return const <String>[
          'AGA — Clinical Practice Guideline on Management of Gastroparesis (2025) — https://gastro.org/clinical-guidance/clinical-guidance-on-the-management-of-gastroparesis/',
          'ACG — Clinical Guideline: Gastroparesis (2022) — https://pubmed.ncbi.nlm.nih.gov/35926490/',
          'ACG — Gastroparesis Clinical Topic, updated April 2026 — https://gi.org/topics/gastroparesis/',
        ];

      case 'uncomplicated_diverticular_disease_acg_2026':
        return const <String>[
          'ACG — Clinical Guideline: Colonic Diverticulitis (2026) — https://gi.org/guidelines/',
          'AGA — Clinical Practice Update on Medical Management of Colonic Diverticulitis — https://gastro.org/clinical-guidance/medical-management-of-colonic-diverticulitis/',
          'ASCRS — Clinical Practice Guidelines for Treatment of Left-Sided Colonic Diverticulitis (2020) — https://fascrs.org/ascrs/media/files/DCR-tics-CPG-2020.pdf',
        ];

      case 'lower_gi_bleeding_acg_2023':
        return const <String>[
          'ACG — Updated Clinical Guideline: Management of Patients With Acute Lower Gastrointestinal Bleeding (2023) — https://gi.org/guidelines/',
          'ESGE — Guideline: Diagnosis and Management of Acute Lower Gastrointestinal Bleeding (2021) — https://www.esge.com/diagnosis-and-management-of-acute-lower-gastrointestinal-bleeding-esge-guideline',
          'ACG — Lower Gastrointestinal Bleeding Clinical Topic — https://gi.org/topics/lower-gi-bleeding/',
        ];

      case 'microscopic_colitis_ueg_emcg_2021':
        return const <String>[
          'UEG/EMCG — European Guidelines on Microscopic Colitis (2021) — https://pubmed.ncbi.nlm.nih.gov/33619914/',
          'UEG/EMCG — European Guidelines on Microscopic Colitis, full text — https://pmc.ncbi.nlm.nih.gov/articles/PMC8259259/',
          'AGA — Medical Management of Microscopic Colitis — https://gastro.org/clinical-guidance/medical-management-of-microscopic-colitis/',
        ];

      case 'ischemic_colitis_acg':
        return const <String>[
          'ACG — Clinical Guideline: Colon Ischemia, recommendations summary — https://acgcdn.gi.org/wp-content/uploads/2018/04/ACG-Colon-Ischemia-Guideline-Summary.pdf',
          'ACG — Clinical Guideline: Epidemiology, Diagnosis and Management of Colon Ischemia — https://pubmed.ncbi.nlm.nih.gov/25559486/',
          'ACG — Gastroenterology Guidelines repository, Colon Ischemia — https://gi.org/guidelines/',
        ];

      case 'proctitis_multietiology_guidance':
        return const <String>[
          'CDC — STI Treatment Guidelines: Proctitis, Proctocolitis and Enteritis — https://www.cdc.gov/std/treatment-guidelines/proctitis.htm',
          'ACG — Clinical Guideline: Ulcerative Colitis in Adults, including ulcerative proctitis (2025) — https://gi.org/guidelines/',
          'ASCRS — Clinical Practice Guidelines for Surgical Management of Ulcerative Colitis — https://fascrs.org/ascrs/media/files/2021-Ulcerative-Colitis-CPG.pdf',
        ];

      case 'fecal_incontinence_ascrs_2023':
        return const <String>[
          'ASCRS — Clinical Practice Guidelines for the Management of Fecal Incontinence (2023) — https://fascrs.org/ascrs/media/files/2023-Fecal-Incontinence-CPG.pdf',
          'UEG/ESCP/ESNM/ESPCG — Guideline for Diagnosis and Treatment of Faecal Incontinence (2022) — https://pmc.ncbi.nlm.nih.gov/articles/PMC9004250/',
          'UEG/ESCP/ESNM/ESPCG — Faecal Incontinence Guideline indexed in PubMed (2022) — https://pubmed.ncbi.nlm.nih.gov/35303758/',
        ];

      case 'spontaneous_pneumothorax_ers_bts_2024':
        return const <String>[
          'ERS/EACTS/ESTS — Joint Clinical Practice Guidelines on Adults With Spontaneous Pneumothorax (2024) — https://publications.ersnet.org/content/erj/63/5/2300797',
          'BTS — Guideline for Pleural Disease: Spontaneous Pneumothorax (2023) — https://thorax.bmj.com/content/78/Suppl_3/s1',
          'BTS — Clinical Statement on Pleural Procedures (2023) — https://thorax.bmj.com/content/78/Suppl_3/s43',
        ];

      case 'hemothorax_trauma_guidelines':
        return const <String>[
          'EAST — Practice Management Guideline: Hemothorax and Occult Pneumothorax — https://www.east.org/education-resources/practice-management-guidelines/details/hemothorax-and-occult-pneumothorax-management-of',
          'WSES-AAST — Thoracic Trauma Guidelines — https://www.wses.org.uk/guidelines',
          'Western Trauma Association — Critical Decisions in Thoracic Trauma — https://www.westerntrauma.org/western-trauma-association-algorithms/',
        ];

      case 'pleural_effusion_bts_2023':
        return const <String>[
          'BTS — Guideline for Pleural Disease: Undiagnosed Unilateral Pleural Effusion (2023) — https://thorax.bmj.com/content/78/Suppl_3/s1',
          'BTS — Clinical Statement on Pleural Procedures (2023) — https://thorax.bmj.com/content/78/Suppl_3/s43',
          'ATS/STS/STR — Clinical Practice Guideline on Management of Malignant Pleural Effusions (2018) — https://www.thoracic.org/statements/resources/lcod/management-of-malignant-pleural-effusions-implementation-tools.pdf',
        ];

      case 'pleural_empyema_bts_2023':
        return const <String>[
          'BTS — Guideline for Pleural Disease: Pleural Infection/Empyema (2023) — https://thorax.bmj.com/content/78/Suppl_3/s1',
          'BTS — Clinical Statement on Pleural Procedures, including intrapleural therapy and drainage (2023) — https://thorax.bmj.com/content/78/Suppl_3/s43',
          'AATS — Consensus Guidelines for the Management of Empyema — https://www.aats.org/resources/the-american-association-for-thoracic-surgery-consensus-guidelines-for-the-management-of-empyema',
        ];

      case 'lung_abscess_lower_respiratory_guidance':
        return const <String>[
          'BTS — Clinical Statement on Aspiration Pneumonia, relevant to aspiration-associated lung abscess (2023) — https://www.brit-thoracic.org.uk/document-library/clinical-statements/aspiration-pneumonia/bts-clinical-statement-on-aspiration-pneumonia/',
          'ATS/IDSA — Clinical Practice Guideline for Community-Acquired Pneumonia in Adults (2019) — https://www.idsociety.org/practice-guideline/community-acquired-pneumonia-cap-in-adults/',
          'ERS/ESICM/ESCMID/ALAT — Guidelines for Severe Community-Acquired Pneumonia (2023) — https://publications.ersnet.org/content/erj/61/4/2200735',
        ];

      case 'aspiration_pneumonia_bts_2023':
        return const <String>[
          'BTS — Clinical Statement on Aspiration Pneumonia (2023) — https://www.brit-thoracic.org.uk/document-library/clinical-statements/aspiration-pneumonia/bts-clinical-statement-on-aspiration-pneumonia/',
          'ATS/IDSA — Clinical Practice Guideline for Community-Acquired Pneumonia in Adults (2019) — https://www.idsociety.org/practice-guideline/community-acquired-pneumonia-cap-in-adults/',
          'ERS/ESICM/ESCMID/ALAT — Guidelines for Severe Community-Acquired Pneumonia (2023) — https://publications.ersnet.org/content/erj/61/4/2200735',
        ];

      case 'acute_bronchitis_antibiotic_stewardship':
        return const <String>[
          'CDC — Outpatient Clinical Care for Adults: Acute Uncomplicated Bronchitis — https://www.cdc.gov/antibiotic-use/hcp/clinical-care/adult-outpatient.html',
          'ACP/CDC — Appropriate Antibiotic Use for Acute Respiratory Tract Infection in Adults — https://www.acpjournals.org/doi/10.7326/M15-1840',
          'NICE — Acute Cough: Antimicrobial Prescribing (NG120) — https://www.nice.org.uk/guidance/ng120',
        ];

      case 'chronic_cough_ers_bts':
        return const <String>[
          'ERS — Guidelines on the Diagnosis and Treatment of Chronic Cough in Adults and Children (2020) — https://publications.ersnet.org/content/erj/55/1/1901136',
          'BTS — Clinical Statement on Chronic Cough in Adults (2023) — https://www.brit-thoracic.org.uk/document-library/clinical-statements/cough-in-adults/chronic-cough-in-adults/',
          'CHEST — Guideline and Expert Panel Reports on Cough — https://www.chestnet.org/Guidelines-and-Topic-Collections/Guidelines/Cough',
        ];

      case 'pulmonary_sarcoidosis_ers_ats':
        return const <String>[
          'ERS — Clinical Practice Guidelines on Treatment of Sarcoidosis (2021) — https://publications.ersnet.org/content/erj/58/6/2004079',
          'ATS — Clinical Practice Guideline: Diagnosis and Detection of Sarcoidosis (2020) — https://www.thoracic.org/statements/resources/interstitial-lung-disease/sarcoidosis-guideline.pdf',
          'BTS — Clinical Statement on Pulmonary Sarcoidosis — https://www.brit-thoracic.org.uk/document-library/clinical-statements/sarcoidosis/bts-clinical-statement-on-pulmonary-sarcoidosis/',
        ];

      case 'cystic_fibrosis_ecfs_cff_2024':
        return const <String>[
          'ECFS — Standards for the Care of People With Cystic Fibrosis, 3rd Edition (2023–2024) — https://www.ecfs.eu/sites/default/files/standards-of-care-files/Index.pdf',
          'ECFS — Standards for Care: Establishing and Maintaining Health (2024) — https://www.ecfs.eu/sites/default/files/SoC%20paper%202%202023.pdf',
          'Cystic Fibrosis Foundation — Clinical Care Guidelines — https://www.cff.org/medical-professionals/clinical-care-guidelines',
        ];

      case 'abdominal_aortic_aneurysm_esc_2024':
        return const <String>[
          'ESC — Guidelines for the Management of Peripheral Arterial and Aortic Diseases (2024) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/peripheral-arterial-and-aortic-diseases/',
          'ACC/AHA — Guideline for the Diagnosis and Management of Aortic Disease (2022) — https://www.acc.org/Guidelines/Guidelines/2022/11/02/14/08/Aortic-Disease',
          'ESC — Pocket Guidelines on Peripheral Arterial and Aortic Diseases (2024) — https://www.escardio.org/guidelines/clinical-practice-guidelines/pocket-guidelines/peripheral-arterial-and-aortic-diseases/',
        ];

      case 'thoracic_aortic_aneurysm_esc_2024':
        return const <String>[
          'ESC — Guidelines for the Management of Peripheral Arterial and Aortic Diseases (2024) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/peripheral-arterial-and-aortic-diseases/',
          'ACC/AHA — Guideline for the Diagnosis and Management of Aortic Disease (2022) — https://www.acc.org/Guidelines/Guidelines/2022/11/02/14/08/Aortic-Disease',
          'ACC/AHA — Aortic Disease Guideline Key Perspectives (2022) — https://www.acc.org/Latest-in-Cardiology/ten-points-to-remember/2022/11/01/12/21/2022-Guideline-on-Aortic-Disease-2-gl-ad',
        ];

      case 'deep_vein_thrombosis_ash':
        return const <String>[
          'ASH — VTE Guidelines: Treatment of Deep Vein Thrombosis and Pulmonary Embolism (2020; actively reviewed) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/venous-thromboembolism-guidelines/treatment',
          'ASH — VTE Guidelines: Diagnosis of Venous Thromboembolism (2018; actively reviewed) — https://www.hematology.org/education/clinicians/guidelines-and-quality-care/clinical-practice-guidelines/venous-thromboembolism-guidelines/diagnosis',
          'ESVS — Clinical Practice Guidelines on the Management of Venous Thrombosis (2021) — https://esvs.org/wp-content/uploads/2020/12/VT-Guidelines-PDF.pdf',
        ];

      case 'chronic_venous_disease_esvs_2022':
        return const <String>[
          'ESVS — Clinical Practice Guidelines on Chronic Venous Disease of the Lower Limbs (2022) — https://esvs.org/wp-content/uploads/2023/03/ESVS-2022-CVD-Guidelines.pdf',
          'SVS/AVF/AVLS — Clinical Practice Guidelines for Varicose Veins, Parts I and II (2022–2023) — https://vascular.org/research-quality/guidelines-and-reporting-standards/clinical-practice-guidelines',
          'ESVS — Chronic Venous Disease Guideline indexed in PubMed (2022) — https://pubmed.ncbi.nlm.nih.gov/35027279/',
        ];

      case 'superficial_venous_thrombosis_esvs_2021':
        return const <String>[
          'ESVS — Clinical Practice Guidelines on the Management of Venous Thrombosis, including superficial vein thrombosis (2021) — https://esvs.org/wp-content/uploads/2020/12/VT-Guidelines-PDF.pdf',
          'ESVS — Venous Thrombosis Guideline indexed in PubMed (2021) — https://pubmed.ncbi.nlm.nih.gov/33334670/',
          'CHEST — Antithrombotic Therapy for VTE Disease, Second Update; includes spontaneous superficial vein thrombosis (2021) — https://journal.chestnet.org/article/S0012-3692%2821%2901506-3/fulltext',
        ];

      case 'vasovagal_reflex_syncope':
        return const <String>[
          'ESC — Guidelines for Diagnosis and Management of Syncope (2018) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/syncope/',
          'ACC/AHA/HRS — Guideline for the Evaluation and Management of Patients With Syncope (2017) — https://www.acc.org/guidelines/hubs/syncope',
          'HRS — Expert Consensus Statement on POTS, Inappropriate Sinus Tachycardia and Vasovagal Syncope (2015) — https://www.hrsonline.org/wp-content/uploads/2025/02/2015-HRS-POTS-IST-VVS.pdf',
        ];

      case 'orthostatic_hypotension_aha_2024':
        return const <String>[
          'AHA — Scientific Statement: Orthostatic Hypotension in Adults With Hypertension (2024) — https://professional.heart.org/en/science-news/orthostatic-hypotension-in-adults-with-hypertension',
          'ESC — Guidelines for Diagnosis and Management of Syncope, including orthostatic intolerance syndromes (2018) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/syncope/',
          'ACC/AHA/HRS — Guideline for Evaluation and Management of Syncope (2017) — https://www.acc.org/Guidelines/Guidelines/2017/03/09/08/27/Syncope',
        ];

      case 'postural_orthostatic_tachycardia_syndrome':
        return const <String>[
          'HRS — Expert Consensus Statement on Postural Tachycardia Syndrome, IST and Vasovagal Syncope (2015) — https://www.hrsonline.org/wp-content/uploads/2025/02/2015-HRS-POTS-IST-VVS.pdf',
          'Canadian Cardiovascular Society — Position Statement on POTS and Chronic Orthostatic Intolerance (2020) — https://pubmed.ncbi.nlm.nih.gov/32145864/',
          'NIH Expert Consensus Meeting — POTS State of the Science and Clinical Care, Part 1 (2021) — https://pubmed.ncbi.nlm.nih.gov/34144933/',
        ];

      case 'rheumatic_fever_rheumatic_heart_disease_who_2024':
        return const <String>[
          'WHO — Guideline on the Prevention and Diagnosis of Rheumatic Fever and Rheumatic Heart Disease (2024) — https://www.who.int/publications/i/item/9789240100077',
          'CDC — Clinical Guidance for Acute Rheumatic Fever (2025) — https://www.cdc.gov/group-a-strep/hcp/clinical-guidance/acute-rheumatic-fever.html',
          'AHA — Revised Jones Criteria for the Diagnosis of Acute Rheumatic Fever (2015) — https://professional.heart.org/en/science-news/revised-jones-criteria-for-the-diagnosis-of-acute-rheumatic-fever',
        ];

      case 'hypertensive_emergency_aha_2024':
        return const <String>[
          'AHA — Scientific Statement: Management of Elevated Blood Pressure in the Acute Care Setting (2024) — https://professional.heart.org/en/science-news/management-of-elevated-blood-pressure-in-the-acute-care-setting',
          'AHA/ACC Multisociety — High Blood Pressure Guideline (2025) — https://professional.heart.org/en/science-news/2025-high-blood-pressure-guideline',
          'ESC — Guidelines for the Management of Elevated Blood Pressure and Hypertension (2024) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/elevated-blood-pressure-and-hypertension/',
        ];

      case 'chronic_coronary_syndrome_esc_2024':
        return const <String>[
          'ESC — Guidelines for the Management of Chronic Coronary Syndromes (2024) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/chronic-coronary-syndromes/',
          'ACC/AHA/ACCP/ASPC/NLA/PCNA — Guideline for the Management of Patients With Chronic Coronary Disease (2023) — https://www.acc.org/Guidelines/Hubs/Chronic-Coronary-Disease',
          'AHA/ACC Multisociety — Chronic Coronary Disease Guideline hub (2023) — https://professional.heart.org/en/guidelines-statements/2023-ahaaccaccpaspcnlapcna-guideline-for-the-management-of-patients-withcir0000000000001168',
        ];

      case 'paroxysmal_supraventricular_tachycardia':
        return const <String>[
          'ESC — Guidelines for the Management of Patients with Supraventricular Tachycardia (2019) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/supraventricular-tachycardia/',
          'ACC/AHA/HRS — Guideline for the Management of Adult Patients With Supraventricular Tachycardia (2015) — https://www.acc.org/Guidelines/Hubs/Supraventricular-Tachycardia',
          'AHA/ACC/HRS — Supraventricular Tachycardia Guideline hub (2015) — https://professional.heart.org/en/guidelines-statements/2015-accahahrs-guideline-for-the-management-of-adult-patients-withe506',
        ];

      case 'atrial_flutter':
        return const <String>[
          'ESC — Guidelines for the Management of Atrial Fibrillation, including atrial flutter considerations (2024) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/atrial-fibrillation/',
          'ESC — Guidelines for Supraventricular Tachycardia, including atrial flutter (2019) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/supraventricular-tachycardia/',
          'ACC/AHA/HRS — Guideline for Adult Supraventricular Tachycardia, including atrial flutter (2015) — https://www.acc.org/Guidelines/Hubs/Supraventricular-Tachycardia',
        ];

      case 'sustained_ventricular_tachycardia':
        return const <String>[
          'ESC — Guidelines for Ventricular Arrhythmias and Prevention of Sudden Cardiac Death (2022) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/ventricular-arrhythmias-and-the-prevention-of-sudden-cardiac-death/',
          'AHA/ACC/HRS — Guideline for Management of Patients With Ventricular Arrhythmias and Prevention of Sudden Cardiac Death (2017) — https://www.acc.org/Guidelines/Guidelines/2017/10/30/10/45/Ventricular-Arrhythmias-and-the-Prevention-of-Sudden-Cardiac-Death',
          'AHA/ACC/HRS — Ventricular Arrhythmias and Sudden Cardiac Death guideline hub (2017) — https://professional.heart.org/en/science-news/2017-guideline-for-management-of-patients-with-ventricular-arrhythmias-and-the-prevention-of-scd',
        ];

      case 'atrioventricular_block':
        return const <String>[
          'ACC/AHA/HRS — Guideline on Bradycardia and Cardiac Conduction Delay (2018) — https://www.acc.org/Guidelines/Guidelines/2018/11/05/06/18/Bradycardia-and-Cardiac-Conduction-Delay',
          'AHA/ACC/HRS — Evaluation and Management of Bradycardia and Cardiac Conduction Delay (2018) — https://professional.heart.org/en/science-news/2018-guideline-for-the-evaluation-and-management-of-bradycardia-and-cardiac-conduction-delay',
          'ESC — Guidelines on Cardiac Pacing and Cardiac Resynchronization Therapy (2021) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/cardiac-pacing-and-cardiac-resynchronization-therapy/',
        ];

      case 'wolff_parkinson_white_wpw':
        return const <String>[
          'ESC — Guidelines for Supraventricular Tachycardia, including pre-excitation/WPW (2019) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/supraventricular-tachycardia/',
          'ACC/AHA/HRS — Guideline for Adult Supraventricular Tachycardia, including accessory pathways/WPW (2015) — https://www.acc.org/Guidelines/Hubs/Supraventricular-Tachycardia',
          'AHA/ACC/HRS — Supraventricular Tachycardia Guideline hub (2015) — https://professional.heart.org/en/guidelines-statements/2015-accahahrs-guideline-for-the-management-of-adult-patients-withe506',
        ];

      case 'long_qt_syndrome':
        return const <String>[
          'ESC — Guidelines for Ventricular Arrhythmias and Prevention of Sudden Cardiac Death, including Long QT Syndrome (2022) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/ventricular-arrhythmias-and-the-prevention-of-sudden-cardiac-death/',
          'AHA/ACC/HRS — Ventricular Arrhythmias and Sudden Cardiac Death guideline (2017) — https://www.acc.org/Guidelines/Guidelines/2017/10/30/10/45/Ventricular-Arrhythmias-and-the-Prevention-of-Sudden-Cardiac-Death',
          'HRS/EHRA/APHRS — Expert Consensus on Inherited Primary Arrhythmia Syndromes, including LQTS (2013) — https://www.hrsonline.org/resource/2013-hrsehraaphrs-expert-consensus-statement-diagnosis-and-management-patients-inherited-primary/',
        ];

      case 'brugada_syndrome':
        return const <String>[
          'ESC — Guidelines for Ventricular Arrhythmias and Prevention of Sudden Cardiac Death, including Brugada Syndrome (2022) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/ventricular-arrhythmias-and-the-prevention-of-sudden-cardiac-death/',
          'AHA/ACC/HRS — Ventricular Arrhythmias and Sudden Cardiac Death guideline (2017) — https://www.acc.org/Guidelines/Guidelines/2017/10/30/10/45/Ventricular-Arrhythmias-and-the-Prevention-of-Sudden-Cardiac-Death',
          'HRS/EHRA/APHRS — Expert Consensus on Inherited Primary Arrhythmia Syndromes, including Brugada Syndrome (2013) — https://www.hrsonline.org/resource/2013-hrsehraaphrs-expert-consensus-statement-diagnosis-and-management-patients-inherited-primary/',
        ];

      case 'dilated_cardiomyopathy_esc_2023':
        return const <String>[
          'ESC — Guidelines for the Management of Cardiomyopathies, including dilated cardiomyopathy (2023) — https://www.escardio.org/guidelines/clinical-practice-guidelines/all-esc-practice-guidelines/cardiomyopathy/',
          'AHA/ACC/HFSA — Guideline for the Management of Heart Failure (2022) — https://professional.heart.org/en/guidelines-statements/2022-ahaacchfsa-guideline-for-the-management-of-heart-failure-a-report-of-thecir0000000000001063',
          'EHRA/HRS/APHRS/LAHRS — Expert Consensus on Genetic Testing for Cardiac Diseases, including cardiomyopathies (2022) — https://www.hrsonline.org/resource/2022-ehra-hrs-aphrs-lahrs-expert-consensus-statement-on-the-state-of-genetic-testing-for-cardiac-diseases/',
        ];

      case 'takotsubo_syndrome_consensus_2024':
        return const <String>[
          'International Expert Consensus — Takotsubo Syndrome Part 1: Diagnostic and Therapeutic Challenges (2024) — https://pubmed.ncbi.nlm.nih.gov/39417524/',
          'International Expert Consensus — Takotsubo Syndrome Part 2: Specific Entities, Risk Stratification and Challenges After Recovery (2024) — https://pubmed.ncbi.nlm.nih.gov/39417538/',
          'International Expert Consensus — Takotsubo Syndrome Part II: Diagnostic Workup, Outcome and Management (2018) — https://pubmed.ncbi.nlm.nih.gov/29850820/',
        ];

      case 'urinary_tract_infection':
        return const <String>[
          'IDSA — Guideline Update on Complicated Urinary Tract Infections (2025) — https://www.idsociety.org/practice-guideline/complicated-urinary-tract-infections/',
          'EAU — Guidelines on Urological Infections (2026) — https://uroweb.org/guidelines/urological-infections',
          'EAU — Urological Infections: Summary of Changes (2026) — https://uroweb.org/guidelines/urological-infections/summary-of-changes/2026',
        ];

      case 'acute_pancreatitis':
        return const <String>[
          'ACG — American College of Gastroenterology Guidelines: Management of Acute Pancreatitis (2024) — https://doi.org/10.14309/ajg.0000000000002645',
          'PubMed — ACG Management of Acute Pancreatitis guideline record (2024) — https://pubmed.ncbi.nlm.nih.gov/38857482/',
          'PMC — ACG Management of Acute Pancreatitis full text archive (2024) — https://pmc.ncbi.nlm.nih.gov/articles/PMC13221274/',
        ];

      case 'pediatric_pneumonia':
        return const <String>[
          'IDSA/PIDS — Community-Acquired Pneumonia in Infants and Children >3 months (2026)',
        ];

      case 'resuscitation':
        return const <String>[
          'AHA — Guidelines for CPR and Emergency Cardiovascular Care (2025)',
        ];

      case 'pediatric_resuscitation':
        return const <String>[
          'AHA — Pediatric Advanced Life Support, CPR and ECC Guidelines (2025)',
        ];

      case 'pediatric_sepsis':
        return const <String>[
          'Surviving Sepsis Campaign / SCCM — Pediatric sepsis and septic shock guidelines (2026)',
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

  // PLANTAO_EXPLICIT_CORONARY_PHENOTYPE_PRECEDENCE_V1
  static ProtocolModel? _matchExplicitCoronaryPhenotypeProtocol({
    required String query,
    required String responseHeading,
  }) {
    final corpus = '$query $responseHeading';

    final explicitStemiAlias = <String>[
      'iamcest',
      'iamcsst',
      'stemi',
    ].any(corpus.contains);

    final explicitNste = <String>[
      'iamest',
      'iamsst',
      'iamssst',
      'nstemi',
      'scasst',
      'scasest',
      'sin elevacion del st',
      'sin elevacion persistente del st',
      'sin supradesnivel',
      'sem elevacao do st',
      'sem elevacao persistente do st',
      'sem supradesnivel',
      'sem supradesnivelamento',
      'sem supra de st',
      'sin supra de st',
      'sem supra',
      'sin supra',
      'without st elevation',
    ].any(corpus.contains);

    final explicitStElevation = <String>[
      'con elevacion del st',
      'elevacion persistente del st',
      'com elevacao do st',
      'elevacao persistente do st',
      'supradesnivel de st',
      'supradesnivelamento de st',
      'supra de st',
      'st elevation',
    ].any(corpus.contains);

    String? targetId;

    if (explicitNste && !explicitStemiAlias) {
      targetId = 'sindrome_coronariana_sem_st';
    } else if (explicitStemiAlias || explicitStElevation) {
      // M55E_R6_IAM_NEGATED_CONGESTION_PRECEDENCE_V1
      final explicitKillipI = RegExp(r'\bkillip\s+i\b').hasMatch(corpus);
      final negatedCongestion =
          explicitKillipI ||
          <String>[
            'sin edema agudo de pulmon',
            'sin edema pulmonar',
            'sin edema periferico',
            'sin edema',
            'sin congestion',
            'sin estertores',
            'sin crepitantes',
            'sin ingurgitacion yugular',
            'sin signos clinicos de insuficiencia cardiaca',
            'sin insuficiencia cardiaca',
            'sem edema agudo de pulmao',
            'sem edema pulmonar',
            'sem edema periferico',
            'sem edema',
            'sem congestao',
            'sem estertores',
            'sem crepitantes',
            'sem turgencia jugular',
            'sem sinais clinicos de insuficiencia cardiaca',
            'sem insuficiencia cardiaca',
            'sin shock',
            'sem choque',
          ].any(corpus.contains);

      final positiveCongestion =
          !negatedCongestion &&
          <String>[
            'edema agudo de pulmon',
            'edema agudo de pulmao',
            'edema pulmonar cardiogenico',
            'congestion pulmonar',
            'congestao pulmonar',
            'crepitantes',
            'estertores',
            'killip ii',
            'killip iii',
            'killip iv',
            'shock cardiogenico',
            'choque cardiogenico',
          ].any(corpus.contains);

      targetId = positiveCongestion ? 'iam_congestao' : 'iam_supra';
    }

    if (targetId == null) return null;

    for (final protocol in protocolsDatabase) {
      if (protocol.id == targetId) return protocol;
    }
    return null;
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

    final explicitlyComplicated =
        !explicitlyUncomplicated &&
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
      aiText
          .split('\n')
          .firstWhere((line) => line.trim().isNotEmpty, orElse: () => ''),
    );

    final coronaryPhenotypeProtocol = _matchExplicitCoronaryPhenotypeProtocol(
      query: query,
      responseHeading: responseHeading,
    );
    if (coronaryPhenotypeProtocol != null) {
      return coronaryPhenotypeProtocol;
    }

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

      final queryPhraseMatch =
          queryTerms.isNotEmpty &&
          !queryTerms.any(ambiguousProtocolTerms.contains) &&
          (containsTokenSequence(id, query) ||
              containsTokenSequence(title, query));

      final singleQueryIdentity =
          queryTerms.length == 1 &&
          reliableQueryMatches.length == 1 &&
          distinctiveQueryMatches.length == 1;

      final strongQueryIdentity =
          queryPhraseMatch ||
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
        return idTerms.any(
          (idTerm) =>
              idTerm.length >= 3 &&
              !ambiguousProtocolTerms.contains(idTerm) &&
              !weakIdentityTerms.contains(idTerm) &&
              (term.contains(idTerm) || idTerm.contains(term)),
        );
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
