class PlantaoIamcestKillipClassificationGuard {
  PlantaoIamcestKillipClassificationGuard._();

  // PLANTAO_IAMCEST_KILLIP_CLASSIFICATION_COMPLETENESS_V1
  // M55D_IAMCEST_DETERMINISTIC_INITIAL_PROJECTOR_V1
  //
  // This remains the single IAMCEST/Killip post-provider owner already wired
  // after the TEP 2026 guard. M55D extends the existing owner instead of
  // introducing a competing classifier or a second presentation pipeline.
  static String materialize({
    required String userInput,
    required String assistantOutput,
    required String languageCode,
    List<String> recentUserTurns = const <String>[],
  }) {
    // M72C_PATHOLOGY_OWNER_BEFORE_PRESENTATION_MUTATION_V1
    final classificationOnly = _classificationOnly(userInput);
    final combinedInitial = _combinedInitialRequest(userInput);
    if (!classificationOnly && !combinedInitial) return assistantOutput;

    final active = _activeIamcest(userInput, recentUserTurns);
    if (active == null) return assistantOutput;

    // IAM-owned output may still normalize its historical local artifacts.
    final cleanOutput = _stripPictographicEmoji(assistantOutput);

    final killip = _killip(active);
    if (killip == null) return cleanOutput;

    final es = languageCode.toLowerCase().startsWith('es');
    if (combinedInitial) {
      return _renderInitial(
        killip: killip,
        es: es,
        activeCase: active,
        providerText: cleanOutput,
      );
    }

    return _renderClassificationTable(
      killip: killip,
      es: es,
      activeCase: active,
    );
  }

  static String? _activeIamcest(String currentInput, List<String> recent) {
    final current = _fold(currentInput);
    if (_iamcest(current)) return current;

    if (!_shortContextContinuation(currentInput)) return null;

    for (final raw in recent.reversed) {
      final q = _fold(raw);
      if (q.isEmpty) continue;
      if (_iamcest(q)) return q;
      if (_shortContextContinuation(raw)) continue;
      return null;
    }
    return null;
  }

  static String? _killip(String q) {
    final negShock = _any(q, const [
      'sin shock',
      'sin choque',
      'sem shock',
      'sem choque',
      'without shock',
      'no shock',
    ]);
    final stablePerfusion = _any(q, const [
      'bien perfundido',
      'bem perfundido',
      'hemodinamicamente estable',
      'hemodinamicamente estavel',
      'hemodynamically stable',
      'perfusao preservada',
      'perfusion preservada',
    ]);
    final negEdema = _any(q, const [
      'sin edema agudo de pulmon',
      'sin edema pulmonar',
      'sin edema periferico',
      'sem edema agudo de pulmao',
      'sem edema pulmonar',
      'sem edema periferico',
      'without pulmonary edema',
      'without peripheral edema',
      'no pulmonary edema',
    ]);
    final negRales = _any(q, const [
      'sin estertores',
      'sin crepitantes',
      'sin rales',
      'auscultacion pulmonar sin estertores',
      'sem estertores',
      'sem crepitantes',
      'ausculta pulmonar sem estertores',
      'without rales',
      'without crackles',
    ]);
    final negJvd = _any(q, const [
      'sin ingurgitacion yugular',
      'sin turgencia yugular',
      'sem ingurgitamento jugular',
      'sem turgencia jugular',
      'without jugular venous distension',
    ]);

    final shock =
        _any(q, const [
          'shock cardiogenico',
          'choque cardiogenico',
          'cardiogenic shock',
          'hipoperfusion',
          'hipoperfusao',
          'hypoperfusion',
        ]) &&
        !negShock;

    final edema =
        _any(q, const [
          'edema agudo de pulmon',
          'edema agudo de pulmao',
          'acute pulmonary edema',
          'edema pulmonar',
          'pulmonary edema',
        ]) &&
        !negEdema;

    final mild =
        _any(q, const [
          'estertores',
          'crepitantes',
          'rales',
          'tercer ruido',
          'terceira bulha',
          's3',
          'ingurgitacion yugular',
          'turgencia yugular',
          'jugular venous distension',
          'congestion pulmonar',
          'congestao pulmonar',
        ]) &&
        !negRales &&
        !negJvd &&
        !_any(q, const [
          'sin congestion pulmonar',
          'sem congestao pulmonar',
          'without congestion',
        ]);

    if (shock) return 'IV';
    if (edema) return 'III';
    if (mild) return 'II';

    final sbp = _sbp(q);
    final objectivelyStable = stablePerfusion || (sbp != null && sbp >= 90);
    final noHeartFailureEvidence = negEdema || negRales || negJvd;
    if (!shock &&
        !edema &&
        !mild &&
        objectivelyStable &&
        noHeartFailureEvidence) {
      return 'I';
    }
    return null;
  }

  static String _renderInitial({
    required String killip,
    required bool es,
    required String activeCase,
    required String providerText,
  }) {
    final antiPlatelet = _providerLine(providerText, const [
      'aas',
      'aspirina',
      'aspirin',
      'ticagrelor',
      'prasugrel',
      'clopidogrel',
    ]);
    final anticoag = _providerLine(providerText, const [
      'anticoagul',
      'hnf',
      'heparina',
      'heparin',
      'enoxaparin',
      'enoxaparina',
      'fondaparinux',
      'bivalirudina',
      'bivalirudin',
    ]);

    final antiPlateletLine = antiPlatelet == null
        ? (es
              ? 'Antiagregación: AAS + inhibidor P2Y12 según estrategia de reperfusión, contraindicaciones y contexto clínico.'
              : 'Antiagregação: AAS + inibidor P2Y12 conforme estratégia de reperfusão, contraindicações e contexto clínico.')
        : (_fold(antiPlatelet).contains('antiagreg')
              ? antiPlatelet
              : (es
                    ? 'Antiagregación: $antiPlatelet'
                    : 'Antiagregação: $antiPlatelet'));
    final anticoagLine =
        anticoag ??
        (es
            ? 'Anticoagulación parenteral según la estrategia de reperfusión, el anticoagulante elegido y las contraindicaciones.'
            : 'Anticoagulação parenteral conforme a estratégia de reperfusão, o anticoagulante escolhido e as contraindicações.');

    final table = _classificationTableBody(
      killip: killip,
      es: es,
      activeCase: activeCase,
    );

    if (es) {
      return 'IAMCEST (Infarto Agudo de Miocardio con Elevación del Segmento ST)\n\n'
          'Conducta inmediata:\n'
          '- Activar estrategia de reperfusión inmediata. La ICP primaria es la estrategia preferida cuando puede realizarse oportunamente; si no es posible dentro del tiempo recomendado y no hay contraindicaciones, valorar fibrinólisis y traslado para estrategia farmacoinvasiva.\n'
          '- Monitorización continua con ECG, SpO₂ y presión arterial; acceso venoso y vigilancia de deterioro hemodinámico.\n'
          '- Oxígeno solo si existe hipoxemia, por ejemplo SpO₂ <90%, dificultad respiratoria relevante u otra indicación clínica.\n\n'
          'Tratamiento farmacológico:\n'
          '- $antiPlateletLine\n'
          '- $anticoagLine\n\n'
          '$table\n\n'
          'Puntos clave:\n'
          '- Killip es una clasificación clínica clásica I–IV para insuficiencia cardíaca en el contexto del IAM, descrita originalmente por Killip y Kimball en 1967.\n'
          '- En un IAMCEST establecido, la estrategia de reperfusión es un eje central del manejo inicial.\n\n'
          'Red flags:\n'
          '- Hipotensión, hipoperfusión o shock cardiogénico.\n'
          '- Edema agudo de pulmón o insuficiencia cardíaca en progresión.\n'
          '- Arritmia ventricular, dolor/isquemia persistente o deterioro clínico.';
    }

    return 'IAMCSST (Infarto Agudo do Miocárdio com Elevação do Segmento ST)\n\n'
        'Conduta imediata:\n'
        '- Ativar estratégia de reperfusão imediata. A ICP primária é a estratégia preferida quando pode ser realizada oportunamente; se isso não for possível dentro do tempo recomendado e não houver contraindicações, considerar fibrinólise e transferência para estratégia farmacoinvasiva.\n'
        '- Monitorização contínua com ECG, SpO₂ e pressão arterial; acesso venoso e vigilância de deterioração hemodinâmica.\n'
        '- Oxigênio somente se houver hipoxemia, por exemplo SpO₂ <90%, desconforto respiratório relevante ou outra indicação clínica.\n\n'
        'Tratamento farmacológico:\n'
        '- $antiPlateletLine\n'
        '- $anticoagLine\n\n'
        '$table\n\n'
        'Pontos-chave:\n'
        '- Killip é uma classificação clínica clássica I–IV para insuficiência cardíaca no contexto do IAM, descrita originalmente por Killip e Kimball em 1967.\n'
        '- Em um IAMCSST estabelecido, a estratégia de reperfusão é um eixo central do manejo inicial.\n\n'
        'Red flags:\n'
        '- Hipotensão, hipoperfusão ou choque cardiogênico.\n'
        '- Edema agudo de pulmão ou insuficiência cardíaca em progressão.\n'
        '- Arritmia ventricular, dor/isquemia persistente ou deterioração clínica.';
  }

  static String _renderClassificationTable({
    required String killip,
    required bool es,
    required String activeCase,
  }) {
    final table = _classificationTableBody(
      killip: killip,
      es: es,
      activeCase: activeCase,
    );
    return es ? 'CLASIFICACIÓN\n\n$table' : 'CLASSIFICAÇÃO\n\n$table';
  }

  static String _classificationTableBody({
    required String killip,
    required bool es,
    required String activeCase,
  }) {
    final meaning = switch (killip) {
      'I' =>
        es
            ? 'Sin signos clínicos de insuficiencia cardíaca.'
            : 'Sem sinais clínicos de insuficiência cardíaca.',
      'II' =>
        es
            ? 'Insuficiencia cardíaca leve-moderada, por ejemplo estertores, S3 o congestión venosa.'
            : 'Insuficiência cardíaca leve-moderada, por exemplo estertores, B3 ou congestão venosa.',
      'III' => es ? 'Edema agudo de pulmón.' : 'Edema agudo de pulmão.',
      'IV' =>
        es
            ? 'Shock cardiogénico o hipoperfusión.'
            : 'Choque cardiogênico ou hipoperfusão.',
      _ => '',
    };
    final reason = switch (killip) {
      'I' =>
        es
            ? 'Está bien perfundido/hemodinámicamente estable y los datos aportados niegan congestión clínica relevante.'
            : 'Está bem perfundido/hemodinamicamente estável e os dados informados negam congestão clínica relevante.',
      'II' =>
        es
            ? 'Los datos aportados muestran signos de congestión cardíaca leve-moderada.'
            : 'Os dados informados mostram sinais de congestão cardíaca leve-moderada.',
      'III' =>
        es
            ? 'El caso aporta edema agudo de pulmón.'
            : 'O caso informa edema agudo de pulmão.',
      'IV' =>
        es
            ? 'El caso aporta shock/hipoperfusión.'
            : 'O caso informa choque/hipoperfusão.',
      _ => '',
    };
    final troponin = _any(activeCase, const [
      'troponina elevada',
      'troponina positiva',
      'troponin elevated',
      'elevated troponin',
    ]);

    if (es) {
      final rows = <String>[
        '| Diagnóstico | **IAMCEST** |',
        '| ECG | Elevación persistente del segmento ST |',
        if (troponin) '| Troponina | Elevada |',
        '| Killip | **Clase $killip** |',
        '| Sistema | Killip-Kimball |',
        '| Origen / estado | Clasificación clínica clásica descrita en 1967; sigue vigente como herramienta de estratificación clínica. |',
        '| Significado | $meaning |',
        '| Aplicación al caso | $reason |',
      ];
      return '| Criterio / clasificación | Resultado en este paciente |\n'
          '| --- | --- |\n'
          '${rows.join('\n')}';
    }

    final rows = <String>[
      '| Diagnóstico | **IAMCSST** |',
      '| ECG | Elevação persistente do segmento ST |',
      if (troponin) '| Troponina | Elevada |',
      '| Killip | **Classe $killip** |',
      '| Sistema | Killip-Kimball |',
      '| Origem / status | Classificação clínica clássica descrita em 1967; segue vigente como ferramenta de estratificação clínica. |',
      '| Significado | $meaning |',
      '| Aplicação ao caso | $reason |',
    ];
    return '| Critério / classificação | Resultado neste paciente |\n'
        '| --- | --- |\n'
        '${rows.join('\n')}';
  }

  // M55E_R8_PROVIDER_ORDERING_ARTIFACT_SANITIZER_V1
  static String _stripProviderOrderingArtifacts(String value) {
    var line = value.trim();
    final leadingMarker = RegExp(r'^\s*(?:[-*•]|\d+[.)])\s*');

    while (leadingMarker.hasMatch(line)) {
      final next = line.replaceFirst(leadingMarker, '').trimLeft();
      if (next == line) break;
      line = next;
    }

    final inlineOrdinal = RegExp(
      r'^(Antiagregación|Antiagregacao|Antiagregação|Anticoagulación|Anticoagulacao|Anticoagulação)\s*:\s*\d+[.)]?\s*',
      caseSensitive: false,
    ).firstMatch(line);
    if (inlineOrdinal != null) {
      final label = inlineOrdinal.group(1)!;
      line = '$label: ${line.substring(inlineOrdinal.end).trimLeft()}';
    }

    return line.trim();
  }

  static String? _providerLine(String text, List<String> terms) {
    for (final raw in text.split('\n')) {
      final folded = _fold(raw);
      if (!terms.any(folded.contains)) continue;

      var line = _stripProviderOrderingArtifacts(raw.replaceAll('**', ''));
      if (line.isEmpty) continue;

      line = _stripPictographicEmoji(line);
      line = _stripProviderOrderingArtifacts(line);
      if (line.isNotEmpty) return line;
    }
    return null;
  }

  static bool _classificationOnly(String input) {
    final q = _fold(input).trim();
    if (q.isEmpty || q.length > 360) return false;
    final asks = _any(q, const [
      'clasificacion',
      'classificacao',
      'classification',
      'categoria',
      'category',
      'estratificacion',
      'estratificacao',
      'stratification',
      'gravedad',
      'gravidade',
      'severity',
      'killip',
    ]);
    if (!asks) return false;
    final management = _any(q, const [
      'tratamiento',
      'tratamento',
      'treatment',
      'manejo',
      'management',
      'conducta',
      'conduta',
      'farmacologico',
      'reperfus',
    ]);
    return !management;
  }

  static bool _combinedInitialRequest(String input) {
    final q = _fold(input);
    final asksClassification = _any(q, const [
      'clasificacion',
      'classificacao',
      'classification',
      'killip',
      'categoria',
      'category',
      'gravedad',
      'gravidade',
    ]);
    final asksManagement = _any(q, const [
      'conducta',
      'conduta',
      'manejo',
      'management',
      'tratamiento',
      'tratamento',
      'treatment',
      'farmacologico',
      'reperfus',
      'inicial',
      'immediate',
      'imediata',
    ]);
    final asksDiagnosis = _any(q, const [
      'diagnostico',
      'diagnosis',
      'diagnóstico',
    ]);
    return asksClassification &&
        asksManagement &&
        (asksDiagnosis || q.length > 180);
  }

  static bool _iamcest(String q) {
    if (_any(q, const ['iamcest', 'iamcsst', 'stemi', 'scacest'])) return true;
    final mi =
        _any(q, const [
          'infarto agudo de miocardio',
          'infarto agudo do miocardio',
          'acute myocardial infarction',
        ]) ||
        RegExp(r'\biam\b').hasMatch(q);
    final ste = _any(q, const [
      'elevacion persistente del st',
      'elevacion del st',
      'elevacion del segmento st',
      'st elevado',
      'elevacao persistente do st',
      'elevacao do st',
      'elevacao do segmento st',
      'supradesnivel de st',
      'supradesnivelamento de st',
      'st elevation',
    ]);
    final nste = _any(q, const [
      'sin elevacion del st',
      'sin elevacion del segmento st',
      'sem elevacao do st',
      'sem elevacao do segmento st',
      'without st elevation',
      'non st elevation',
      'nstemi',
      'iamssst',
      'iamest',
    ]);
    return mi && ste && !nste;
  }

  // M72C_GENERIC_CONTEXT_BOUNDARY_V1
  static bool _shortContextContinuation(String input) {
    final q = _fold(input).trim();
    if (q.isEmpty || q.length > 220) return false;

    final explicitClassificationTable =
        _any(q, const ['tabla', 'tabela', 'table']) &&
        _any(q, const [
          'clasificacion',
          'classificacao',
          'classification',
          'killip',
          'categoria',
          'category',
          'gravedad',
          'gravidade',
          'severity',
        ]);

    final explicitCaseEvidence =
        _any(q, const [
          'paciente con',
          'paciente com',
          'patient with',
          'nuevo caso',
          'novo caso',
          'new case',
          'nuevo paciente',
          'novo paciente',
          'new patient',
          'ecg',
          'spo2',
          'presion arterial',
          'pressao arterial',
          'frecuencia cardiaca',
          'frequencia cardiaca',
        ]) ||
        RegExp(r'\b\d{1,3}\s*(?:anos|años|years)\b').hasMatch(q);

    if (explicitClassificationTable && !explicitCaseEvidence) return true;

    final topicBearing = _any(q, const [
      'paciente',
      'patient',
      'varon',
      'hombre',
      'mujer',
      'homem',
      'mulher',
      'anos',
      'años',
      'years',
      'ecg',
      'spo2',
      'presion arterial',
      'pressao arterial',
      'frecuencia cardiaca',
      'frequencia cardiaca',
    ]);
    if (topicBearing) return false;

    return _any(q, const [
      'clasificacion',
      'classificacao',
      'classification',
      'killip',
      'tratamiento',
      'tratamento',
      'treatment',
      'manejo',
      'management',
      'conducta',
      'conduta',
      'destino',
      'disposicion',
      'disposition',
      'ingreso',
      'internacion',
      'internacao',
      'alta',
      'uci',
      'uti',
      'estudios',
      'exames',
      'examenes',
      'monitorizacion',
      'monitorizacao',
      'evolucion',
      'evolucao',
      'reevaluacion',
      'reavaliacao',
      'respuesta',
      'resposta',
    ]);
  }

  static double? _sbp(String q) {
    final m = RegExp(
      r'\b(?:pa|pas|presion arterial|pressao arterial)\s*(?:=|:)?\s*(\d{2,3})\s*/',
    ).firstMatch(q);
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  // M55D_ZERO_EMOJI_FINAL_COMMIT_GUARD_V1
  static String _stripPictographicEmoji(String value) {
    final out = StringBuffer();
    for (final cp in value.runes) {
      final pictographic =
          (cp >= 0x1F000 && cp <= 0x1FAFF) ||
          (cp >= 0x2600 && cp <= 0x27BF) ||
          cp == 0xFE0F ||
          cp == 0x200D;
      if (!pictographic) out.writeCharCode(cp);
    }
    return out
        .toString()
        .replaceAll(RegExp(r'^[ \t]+', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  static bool _any(String v, List<String> terms) => terms.any(v.contains);

  static String _fold(String v) => v
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ì', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ò', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');
}
