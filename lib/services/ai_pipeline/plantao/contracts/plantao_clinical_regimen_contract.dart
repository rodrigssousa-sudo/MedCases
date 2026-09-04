/// Typed, deterministic therapeutic context for Plantão.
///
/// Scope V1: initial antiplatelet loading in explicitly stated ACS/AMI.
/// This is deliberately separate from drug-evidence shadow infrastructure and
/// from the continuous-infusion numeric validator.
///
/// Evidence basis: 2025 ACC/AHA/ACEP/NAEMSP/SCAI ACS guideline
/// (DOI 10.1161/CIR.0000000000001309). The guideline accepts an aspirin
/// loading range; MedCases policy V1 deliberately selects 300 mg as the
/// canonical presentation for equivalent ACS/AMI scenarios. Clopidogrel is
/// only materialized numerically when the current scenario determines the
/// loading strategy; otherwise its numeric dose is explicitly deferred.
enum PlantaoClinicalRegimenScenario {
  acsUnspecified,
  stemiStrategyUnspecified,
  acsPci,
  nsteAcs,
  stemiFibrinolysisAgeAtMost75,
  stemiFibrinolysisAgeOver75,
  stemiFibrinolysisAgeUnknown,
}

enum PlantaoClinicalRegimenRelation { mandatory, preferred, alternative }

final class PlantaoClinicalRegimenMedication {
  final String drugId;
  final String namePt;
  final String nameEs;
  final num dose;
  final String unit;
  final String route;
  final String instructionPt;
  final String instructionEs;
  final PlantaoClinicalRegimenRelation relation;

  const PlantaoClinicalRegimenMedication({
    required this.drugId,
    required this.namePt,
    required this.nameEs,
    required this.dose,
    required this.unit,
    required this.route,
    required this.instructionPt,
    required this.instructionEs,
    required this.relation,
  });

  String line({required bool isEs}) {
    final name = isEs ? nameEs : namePt;
    final instruction = isEs ? instructionEs : instructionPt;
    return '$name $dose $unit $route — $instruction';
  }
}

final class PlantaoClinicalRegimenContract {
  static const sourceId = 'ACC_AHA_ACS_2025';
  static const sourceDoi = '10.1161/CIR.0000000000001309';
  static const policyVersion = 'MEDCASES_ACS_REGIMEN_V2_2026_08_15';

  final PlantaoClinicalRegimenScenario scenario;
  final List<PlantaoClinicalRegimenMedication> medications;
  final bool deferNumericClopidogrel;
  final bool ageRequiredForClopidogrel;
  final bool exposeClopidogrelDecisionSupport;

  PlantaoClinicalRegimenContract({
    required this.scenario,
    required List<PlantaoClinicalRegimenMedication> medications,
    this.deferNumericClopidogrel = false,
    this.ageRequiredForClopidogrel = false,
    this.exposeClopidogrelDecisionSupport = false,
  }) : medications = List<PlantaoClinicalRegimenMedication>.unmodifiable(
         medications,
       );

  String toPromptBlock({required String languageCode}) {
    final isEs = languageCode == 'es';
    final b = StringBuffer()
      ..writeln('[MEDCASES_CLINICAL_REGIMEN_V1]')
      ..writeln(
        isEs
            ? 'AUTORIDAD TERAPEUTICA TIPADA — SCA/IAM.'
            : 'AUTORIDADE TERAPEUTICA TIPADA — SCA/IAM.',
      )
      ..writeln('POLICY=$policyVersion')
      ..writeln('SOURCE=$sourceId DOI=$sourceDoi')
      ..writeln('SCENARIO=${scenario.name}')
      ..writeln(
        isEs
            ? 'REGLA DE CONFLICTO: este bloque prevalece sobre dosis numericas '
                  'conflictivas del RAG/contexto local para el mismo escenario.'
            : 'REGRA DE CONFLITO: este bloco prevalece sobre doses numericas '
                  'conflitantes do RAG/contexto local para o mesmo cenario.',
      )
      ..writeln(
        isEs
            ? 'AAS_CANONICA=300 mg VO masticable como carga si no existe una '
                  'contraindicacion explicita. Para el mismo escenario no '
                  'sustituir por otro valor de carga.'
            : 'AAS_CANONICA=300 mg VO mastigavel como carga se nao houver '
                  'contraindicacao explicita. Para o mesmo cenario nao '
                  'substituir por outro valor de carga.',
      )
      ..writeln(
        isEs
            ? 'SEGURIDAD: una contraindicacion explicita del caso prevalece '
                  'sobre la materializacion del farmaco; no inventarla ni '
                  'ignorarla.'
            : 'SEGURANCA: contraindicao explicita do caso prevalece sobre a '
                  'materializacao do farmaco; nao inventar nem ignorar.',
      );

    for (final medication in medications) {
      b.writeln(
        'MED=${medication.relation.name}:${medication.line(isEs: isEs)}',
      );
    }

    if (exposeClopidogrelDecisionSupport) {
      b.writeln(
        isEs
            ? 'CLOPIDOGREL_DECISION_SUPPORT=Si clopidogrel es el P2Y12 elegido: '
                  'sin fibrinolisis, carga de 300 o 600 mg por via oral segun '
                  'la estrategia; con fibrinolisis, 300 mg si edad <=75 anos y '
                  '75 mg inicial sin carga si >75 anos.'
            : 'CLOPIDOGREL_DECISION_SUPPORT=Se clopidogrel for o P2Y12 escolhido: '
                  'sem fibrinolise, carga de 300 ou 600 mg por via oral conforme '
                  'a estrategia; com fibrinolise, 300 mg se idade <=75 anos e '
                  '75 mg inicial sem carga se >75 anos.',
      );
    } else if (deferNumericClopidogrel) {
      b.writeln(
        isEs
            ? 'CLOPIDOGREL_NUMERICO=DEFERIDO. No emitir una carga numerica de '
                  'clopidogrel hasta que la estrategia clinica/reperfusiva '
                  'determine el esquema.'
            : 'CLOPIDOGREL_NUMERICO=DEFERIDO. Nao emitir carga numerica de '
                  'clopidogrel ate que a estrategia clinica/reperfusiva '
                  'determine o esquema.',
      );
    }

    if (ageRequiredForClopidogrel) {
      b.writeln(
        isEs
            ? 'MODIFICADOR_FALTANTE=edad. En fibrinolisis la edad cambia la '
                  'carga de clopidogrel; no inferirla.'
            : 'MODIFICADOR_FALTANTE=idade. Na fibrinolise a idade muda a '
                  'carga de clopidogrel; nao inferi-la.',
      );
    }

    b
      ..writeln(
        isEs
            ? 'NO INFERIR estrategia de reperfusion, edad, contraindicaciones '
                  'ni hallazgos no informados.'
            : 'NAO INFERIR estrategia de reperfusao, idade, contraindicacoes '
                  'ou achados nao informados.',
      )
      ..writeln('[END_MEDCASES_CLINICAL_REGIMEN_V1]')
      ..writeln();

    return b.toString();
  }
}

abstract final class PlantaoClinicalRegimenResolver {
  static const _aspirin = PlantaoClinicalRegimenMedication(
    drugId: 'aspirin',
    namePt: 'AAS',
    nameEs: 'AAS',
    dose: 300,
    unit: 'mg',
    route: 'VO',
    instructionPt: 'carga canonica MedCases; mastigar se possivel',
    instructionEs: 'carga canonica MedCases; masticar si es posible',
    relation: PlantaoClinicalRegimenRelation.mandatory,
  );

  static const _atorvastatin80 = PlantaoClinicalRegimenMedication(
    drugId: 'atorvastatin',
    namePt: 'Atorvastatina',
    nameEs: 'Atorvastatina',
    dose: 80,
    unit: 'mg',
    route: 'VO',
    instructionPt: 'estatina de alta intensidade; escolha canonica MedCases',
    instructionEs: 'estatina de alta intensidad; eleccion canonica MedCases',
    relation: PlantaoClinicalRegimenRelation.mandatory,
  );

  static const _ticagrelor = PlantaoClinicalRegimenMedication(
    drugId: 'ticagrelor',
    namePt: 'Ticagrelor',
    nameEs: 'Ticagrelor',
    dose: 180,
    unit: 'mg',
    route: 'VO',
    instructionPt: 'carga preferida quando clinicamente apropriado',
    instructionEs: 'carga preferida cuando sea clinicamente apropiado',
    relation: PlantaoClinicalRegimenRelation.preferred,
  );

  static const _clopidogrel600 = PlantaoClinicalRegimenMedication(
    drugId: 'clopidogrel',
    namePt: 'Clopidogrel',
    nameEs: 'Clopidogrel',
    dose: 600,
    unit: 'mg',
    route: 'VO',
    instructionPt: 'carga alternativa em PCI se P2Y12 potente nao for adequado',
    instructionEs:
        'carga alternativa en PCI si un P2Y12 potente no es adecuado',
    relation: PlantaoClinicalRegimenRelation.alternative,
  );

  static const _clopidogrel300Fibrinolysis = PlantaoClinicalRegimenMedication(
    drugId: 'clopidogrel',
    namePt: 'Clopidogrel',
    nameEs: 'Clopidogrel',
    dose: 300,
    unit: 'mg',
    route: 'VO',
    instructionPt: 'carga com fibrinolise quando idade <=75 anos',
    instructionEs: 'carga con fibrinolisis cuando edad <=75 anos',
    relation: PlantaoClinicalRegimenRelation.mandatory,
  );

  static const _clopidogrel75OlderFibrinolysis =
      PlantaoClinicalRegimenMedication(
        drugId: 'clopidogrel',
        namePt: 'Clopidogrel',
        nameEs: 'Clopidogrel',
        dose: 75,
        unit: 'mg',
        route: 'VO',
        instructionPt:
            'dose inicial sem carga com fibrinolise quando idade >75 anos',
        instructionEs:
            'dosis inicial sin carga con fibrinolisis cuando edad >75 anos',
        relation: PlantaoClinicalRegimenRelation.mandatory,
      );

  static PlantaoClinicalRegimenContract? resolve({
    required String query,
    String? patientAge,
  }) {
    final q = _fold(query);
    if (q.isEmpty || _isTheoretical(q)) return null;
    if (!_hasExplicitAcsDiagnosis(q)) return null;
    if (_isOnlySuspected(q)) return null;

    final fibrinolysis = _containsAny(q, const <String>[
      'fibrinol',
      'trombol',
      'tenecteplase',
      'alteplase',
    ]);
    final pci = _containsAny(q, const <String>[
      ' pci ',
      ' icp ',
      'angioplast',
      'cateterismo',
      'hemodinamica',
      'stent',
    ]);
    final stemi = _containsAny(q, const <String>[
      ' stemi ',
      'iamcsst',
      'iamcest',
      'iam com supra',
      'iam con supra',
      'supradesnivel',
      'elevacao do st',
      'elevacion del st',
    ]);
    final nste = _containsAny(q, const <String>[
      ' nstemi ',
      'scassst',
      'scasest',
      'iam sem supra',
      'iam sin supra',
      'sem elevacao do st',
      'sin elevacion del st',
    ]);

    // Conflicting reperfusion strategies fail closed: aspirin remains canonical,
    // but the P2Y12 numeric decision is deferred rather than guessed.
    if (fibrinolysis && pci) {
      return _deferred(PlantaoClinicalRegimenScenario.stemiStrategyUnspecified);
    }

    if (fibrinolysis) {
      final age = _parseAge(patientAge);
      if (age == null) {
        return PlantaoClinicalRegimenContract(
          scenario: PlantaoClinicalRegimenScenario.stemiFibrinolysisAgeUnknown,
          medications: const <PlantaoClinicalRegimenMedication>[
            _aspirin,
            _atorvastatin80,
          ],
          deferNumericClopidogrel: true,
          ageRequiredForClopidogrel: true,
        );
      }
      if (age <= 75) {
        return PlantaoClinicalRegimenContract(
          scenario: PlantaoClinicalRegimenScenario.stemiFibrinolysisAgeAtMost75,
          medications: const <PlantaoClinicalRegimenMedication>[
            _aspirin,
            _atorvastatin80,
            _clopidogrel300Fibrinolysis,
          ],
        );
      }
      return PlantaoClinicalRegimenContract(
        scenario: PlantaoClinicalRegimenScenario.stemiFibrinolysisAgeOver75,
        medications: const <PlantaoClinicalRegimenMedication>[
          _aspirin,
          _atorvastatin80,
          _clopidogrel75OlderFibrinolysis,
        ],
      );
    }

    if (pci) {
      return PlantaoClinicalRegimenContract(
        scenario: PlantaoClinicalRegimenScenario.acsPci,
        medications: const <PlantaoClinicalRegimenMedication>[
          _aspirin,
          _atorvastatin80,
          _ticagrelor,
          _clopidogrel600,
        ],
      );
    }

    if (nste) {
      return PlantaoClinicalRegimenContract(
        scenario: PlantaoClinicalRegimenScenario.nsteAcs,
        medications: const <PlantaoClinicalRegimenMedication>[
          _aspirin,
          _atorvastatin80,
          _ticagrelor,
        ],
        deferNumericClopidogrel: true,
      );
    }

    if (stemi) {
      return _deferred(PlantaoClinicalRegimenScenario.stemiStrategyUnspecified);
    }

    return PlantaoClinicalRegimenContract(
      scenario: PlantaoClinicalRegimenScenario.acsUnspecified,
      medications: const <PlantaoClinicalRegimenMedication>[
        _aspirin,
        _atorvastatin80,
      ],
      deferNumericClopidogrel: true,
      exposeClopidogrelDecisionSupport: true,
    );
  }

  static PlantaoClinicalRegimenContract _deferred(
    PlantaoClinicalRegimenScenario scenario,
  ) {
    return PlantaoClinicalRegimenContract(
      scenario: scenario,
      medications: const <PlantaoClinicalRegimenMedication>[
        _aspirin,
        _atorvastatin80,
      ],
      deferNumericClopidogrel: true,
    );
  }

  static bool _hasExplicitAcsDiagnosis(String q) {
    if (q.trim() == 'iam' || q.trim() == 'sca' || q.trim() == 'infarto') {
      return true;
    }
    return _containsAny(q, const <String>[
      ' iam ',
      ' sca ',
      ' stemi ',
      ' nstemi ',
      'iamcsst',
      'iamcest',
      'scassst',
      'scasest',
      'infarto agudo do miocardio',
      'infarto agudo de miocardio',
      'infarto de miocardio',
      'myocardial infarction',
      'sindrome coronariana aguda',
      'sindrome coronaria aguda',
      'acute coronary syndrome',
    ]);
  }

  static bool _isOnlySuspected(String q) {
    final suspected = _containsAny(q, const <String>[
      'suspeita',
      'suspeito',
      'sospecha',
      'sospech',
      'suspected',
      'possivel',
      'posible',
      'possible',
    ]);
    final confirmed = _containsAny(q, const <String>[
      'confirmado',
      'confirmada',
      'confirmed',
      'diagnostico de',
      'diagnostico confirmado',
    ]);
    return suspected && !confirmed;
  }

  static bool _isTheoretical(String q) {
    return _containsAny(q, const <String>[
      'o que e ',
      'que e ',
      'que es ',
      'what is ',
      'definicao',
      'definicion',
      'conceito',
      'concepto',
      'fisiopatologia',
      'fisiopatologia',
      'classificacao',
      'clasificacion',
    ]);
  }

  static int? _parseAge(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final match = RegExp(r'\d{1,3}').firstMatch(raw);
    if (match == null) return null;
    final age = int.tryParse(match.group(0)!);
    if (age == null || age < 0 || age > 120) return null;
    return age;
  }

  static bool _containsAny(String q, List<String> tokens) {
    return tokens.any(q.contains);
  }

  static String _fold(String input) {
    var value = input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
    value = value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    return ' $value ';
  }
}
