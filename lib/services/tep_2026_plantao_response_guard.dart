class Tep2026PlantaoResolution {
  const Tep2026PlantaoResolution({
    required this.category,
    required this.respiratoryModifier,
    this.rvLvRatio,
  });

  final String category;
  final bool respiratoryModifier;
  final double? rvLvRatio;

  String get label => '$category${respiratoryModifier ? 'R' : ''}';
}

class Tep2026PlantaoResponseGuard {
  // M55C_TEP_ZERO_EMOJI_OUTPUT_V1
  Tep2026PlantaoResponseGuard._();

  static String materialize({
    required String userInput,
    required String assistantOutput,
    required String languageCode,
    List<String> recentUserTurns = const <String>[],
  }) {
    // M54_TEP_ES_ENTRY_CANONICAL_ALIAS_V1
    // Canonical synonym normalization only; certainty and objective facts are preserved.
    userInput = userInput.replaceAll(
      RegExp(r'\bembolia\s+pulmonar\b', caseSensitive: false),
      'tromboembolismo pulmonar',
    );

    final isEs = languageCode.toLowerCase().startsWith('es');
    final classificationOnly = _isClassificationOnlyRequest(userInput);

    var resolution = resolve(userInput);

    // TEP_2026_PLANTAO_FOLLOWUP_CLASSIFICATION_INTENT_V1
    //
    // Follow-up curto ("qual a classificação?", "qué categoría?") não repete
    // sinais vitais/VD/biomarcadores. Nessa situação, resolver EXCLUSIVAMENTE
    // a partir de turnos anteriores do USUÁRIO. Nunca aceitar categoria escrita
    // pela IA anterior como fonte clínica de verdade.
    if (resolution == null && classificationOnly) {
      for (final turn in recentUserTurns.reversed) {
        resolution = resolve(turn);
        if (resolution != null) break;
      }
    }

    if (resolution == null) return assistantOutput;

    if (classificationOnly) {
      return _renderClassificationOnly(resolution, isEs: isEs);
    }

    return _render(resolution, isEs: isEs);
  }

  static Tep2026PlantaoResolution? resolve(String userInput) {
    final q = _fold(userInput);
    if (!_isConfirmedPulmonaryEmbolism(q)) return null;

    final spo2 = _numberAfter(
      q,
      RegExp(r'\bspo2\s*(?:=|:)?\s*(\d+(?:[.,]\d+)?)\s*%?'),
    );
    final respiratoryRate = _numberAfter(
      q,
      RegExp(r'\b(?:fr|rr)\s*(?:=|:)?\s*(\d+(?:[.,]\d+)?)'),
    );
    final oxygenFlow = _numberAfter(
      q,
      RegExp(r'(\d+(?:[.,]\d+)?)\s*l\s*/?\s*min'),
    );
    // Objective facts are consumed only when explicitly provided by the user.
    final m54HeartRate = _numberAfter(
      q,
      RegExp(r'\b(?:fc|hr)\s*(?:=|:)?\s*(\d+(?:[.,]\d+)?)'),
    );
    // M54_TEP_ES_VDVI_DE_OBJECTIVE_GRAMMAR_V1
    final m54RvLvRatio = _numberAfter(
      q,
      RegExp(
        r'\b(?:vd\s*/\s*vi|rv\s*/\s*lv)\s*'
        r'(?:(?:=|:)\s*|(?:de|of)\s*)?'
        r'(\d+(?:[.,]\d+)?)',
      ),
    );
    final systolic = _numberAfter(
      q,
      RegExp(r'\b(?:pas|pa)\s*(?:=|:)?\s*(\d{2,3})(?:\s*/|\s*mmhg)'),
    );
    final lactate = _numberAfter(
      q,
      RegExp(r'\b(?:lactato|lactate)\s*(?:=|:)?\s*(\d+(?:[.,]\d+)?)'),
    );
    final urine = _numberAfter(
      q,
      RegExp(
        r'\b(?:diurese|diuresis|urine output)\s*(?:=|:)?\s*'
        r'(\d+(?:[.,]\d+)?)\s*ml\s*/?\s*kg\s*/?\s*h',
      ),
    );
    final cardiacIndex = _numberAfter(
      q,
      RegExp(
        r'\b(?:indice cardiaco|cardiac index)\s*(?:=|:)?\s*'
        r'(\d+(?:[.,]\d+)?)',
      ),
    );
    final map = _numberAfter(
      q,
      RegExp(r'\b(?:pam|map)\s*(?:=|:)?\s*(\d+(?:[.,]\d+)?)'),
    );

    final refractoryCardiogenicShock = _hasAny(q, const [
      'choque cardiogenico refratario',
      'shock cardiogenico refractario',
      'refractory cardiogenic shock',
    ]);
    final arrestMention = _hasAny(q, const [
      'parada cardiaca',
      'paro cardiaco',
      'cardiac arrest',
      'aesp',
      'atividade eletrica sem pulso',
      'actividad electrica sin pulso',
    ]);
    final arrestNegated = _hasAny(q, const [
      'sem parada cardiaca',
      'sin parada cardiaca',
      'sem paro cardiaco',
      'sin paro cardiaco',
      'no cardiac arrest',
      'sem aesp',
      'sin aesp',
    ]);
    final e2 = refractoryCardiogenicShock || (arrestMention && !arrestNegated);
    if (e2) {
      return Tep2026PlantaoResolution(
        category: 'E2',
        respiratoryModifier: _eRespiratoryModifier(q),
      );
    }

    final cardiogenicShock = _hasAny(q, const [
      'choque cardiogenico',
      'shock cardiogenico',
      'cardiogenic shock',
    ]);
    final persistentHypotension = _hasAny(q, const [
      'hipotensao persistente',
      'hipotension persistente',
      'hipotensao recorrente',
      'hipotension recurrente',
      'mantem pas',
      'mantiene pas',
      'persistent hypotension',
      'recurrent hypotension',
    ]);
    if (cardiogenicShock &&
        (persistentHypotension || (systolic != null && systolic < 90))) {
      return Tep2026PlantaoResolution(
        category: 'E1',
        respiratoryModifier: _eRespiratoryModifier(q),
      );
    }

    final transientHypotension = _hasAny(q, const [
      'hipotensao transitoria',
      'hipotension transitoria',
      'transient hypotension',
    ]);
    if (transientHypotension) {
      return Tep2026PlantaoResolution(
        category: 'D1',
        respiratoryModifier: _dRespiratoryModifier(q, oxygenFlow),
      );
    }

    final objectiveHypoperfusion =
        (lactate != null && lactate > 2.0) ||
        (urine != null && urine < 0.5) ||
        (cardiacIndex != null && cardiacIndex < 2.2) ||
        (map != null && map < 60) ||
        _hasAny(q, const [
          'lesao renal aguda',
          'lesion renal aguda',
          'acute kidney injury',
          'oliguria',
          'oliguria',
          'alteracao do estado mental',
          'alteracion del estado mental',
          'altered mental status',
          'com sinais de hipoperfusao',
          'con signos de hipoperfusion',
          'hipoperfusao presente',
          'hipoperfusion presente',
        ]);

    if (objectiveHypoperfusion) {
      return Tep2026PlantaoResolution(
        category: 'D2',
        respiratoryModifier: _dRespiratoryModifier(q, oxygenFlow),
      );
    }

    final spesi = _numberAfter(
      q,
      RegExp(r'\bspesi\s*(?:=|:)?\s*(\d+(?:[.,]\d+)?)'),
    );
    final pesi = _numberAfter(
      q,
      RegExp(r'\bpesi\s*(?:=|:)?\s*(\d+(?:[.,]\d+)?)'),
    );
    final bova = _numberAfter(
      q,
      RegExp(r'\bbova\s*(?:=|:)?\s*(\d+(?:[.,]\d+)?)'),
    );

    final lowSeverity =
        (spesi != null && spesi == 0) ||
        (pesi != null && pesi <= 85) ||
        (bova != null && bova <= 4) ||
        _hasAny(q, const ['spesi baixo', 'spesi bajo', 'low spesi']);

    final elevatedSeverity =
        (spesi != null && spesi >= 1) ||
        (pesi != null && pesi > 85) ||
        (bova != null && bova > 4) ||
        _hasAny(q, const [
          'spesi elevado',
          'spesi elevada',
          'spesi alto',
          'elevated spesi',
        ]) ||
        (m54HeartRate != null && m54HeartRate >= 110) ||
        (spo2 != null && spo2 < 90) ||
        (systolic != null && systolic < 100);

    final rvNormal = _hasAny(q, const [
      'sem disfuncao de vd',
      'sin disfuncion de vd',
      'sem disfuncao do ventriculo direito',
      'sin disfuncion del ventriculo derecho',
      'vd normal',
      'ventriculo direito normal',
      'ventriculo derecho normal',
      'rv normal',
    ]);

    final rvAbnormal =
        !rvNormal &&
        _hasAny(q, const [
          'disfuncao de vd',
          'disfuncion de vd',
          'disfuncao do ventriculo direito',
          'disfuncion del ventriculo derecho',
          'dilatacao de vd',
          'dilatacion de vd',
          'dilatacao/disfuncao do ventriculo direito',
          'dilatacion/disfuncion del ventriculo derecho',
          'vd anormal',
          'rv dysfunction',
          'right ventricular dysfunction',
        ]);
    final m54EffectiveRvAbnormal =
        rvAbnormal || (!rvNormal && m54RvLvRatio != null && m54RvLvRatio > 1.0);

    final troponinNormal = _hasAny(q, const [
      'troponina normal',
      'troponina normal',
      'troponin normal',
    ]);
    final bnpNormal = _hasAny(q, const [
      'bnp normal',
      'nt-probnp normal',
      'nt probnp normal',
    ]);
    final biomarkersNormal =
        _hasAny(q, const [
          'troponina e bnp normais',
          'troponina e bnp normales',
          'troponina y bnp normales',
          'troponin and bnp normal',
        ]) ||
        (troponinNormal && bnpNormal);

    final biomarkersAbnormal =
        _hasAny(q, const [
          'troponina elevada',
          'troponina elevado',
          'troponina positiva',
          'troponin elevated',
          'bnp elevado',
          'bnp elevada',
          'nt-probnp elevado',
          'nt-probnp elevada',
          'nt probnp elevado',
          'nt probnp elevada',
          'bnp elevated',
        ]) ||
        // M54_TEP_TROPONIN_COPULA_OBJECTIVE_GRAMMAR_V1
        RegExp(
          r'\btroponina\s+(?:esta\s+)?(?:elevada|elevado|positiva|alta|alto)\b',
        ).hasMatch(q);

    if (elevatedSeverity) {
      String? category;
      if (m54EffectiveRvAbnormal && biomarkersAbnormal) {
        category = 'C3';
      } else if ((m54EffectiveRvAbnormal && biomarkersNormal) ||
          (rvNormal && biomarkersAbnormal)) {
        category = 'C2';
      } else if (rvNormal && biomarkersNormal) {
        category = 'C1';
      }

      if (category == null) return null;

      return Tep2026PlantaoResolution(
        category: category,
        respiratoryModifier: _cRespiratoryModifier(q, spo2, respiratoryRate),
        rvLvRatio: category == 'C3' ? m54RvLvRatio : null,
      );
    }

    if (lowSeverity) {
      final subsegmental =
          _hasAny(q, const [
            'subsegmentar',
            'subsegmentario',
            'subsegmental',
          ]) &&
          !_hasAny(q, const [
            'nao subsegmentar',
            'no subsegmentario',
            'non-subsegmental',
          ]);

      if (subsegmental) {
        return const Tep2026PlantaoResolution(
          category: 'B1',
          respiratoryModifier: false,
        );
      }

      final nonSubsegmental = _hasAny(q, const [
        'nao subsegmentar',
        'no subsegmentario',
        'non-subsegmental',
        'segmentar',
        'segmentario',
        'segmental',
        'lobar',
        'proximal',
      ]);

      if (nonSubsegmental) {
        return const Tep2026PlantaoResolution(
          category: 'B2',
          respiratoryModifier: false,
        );
      }
    }

    if (_hasAny(q, const ['incidental']) &&
        _hasAny(q, const ['assintomatico', 'asintomatico', 'asymptomatic'])) {
      return const Tep2026PlantaoResolution(
        category: 'A',
        respiratoryModifier: false,
      );
    }

    return null;
  }

  static bool _isConfirmedPulmonaryEmbolism(String q) {
    // M54_TEP_2026_EXACT_PHYSICAL_CASE_C3R_V6
    final m54NegatedConfirmation = RegExp(
      r'\b(?:no|nao|sem|sin)\s+(?:esta\s+)?(?:confirmado|confirmada|confirmed)\b',
    ).hasMatch(q);
    final m54DirectConfirmation =
        !m54NegatedConfirmation &&
        (RegExp(
              r'\b(?:tep|tromboembolismo pulmonar|embolia pulmonar|pulmonary embolism)\b.{0,48}\b(?:confirmado|confirmada|confirmed)\b',
            ).hasMatch(q) ||
            RegExp(r'\bconfirmed\b.{0,32}\bpulmonary embolism\b').hasMatch(q));
    final pe = _hasAny(q, const [
      'tep',
      'tromboembolismo pulmonar',
      'embolia pulmonar',
      'pulmonary embolism',
    ]);
    final confirmed = _hasAny(q, const [
      'tep agudo confirmado',
      'tep confirmado',
      'tromboembolismo pulmonar confirmado',
      'embolia pulmonar confirmada',
      'pulmonary embolism confirmed',
      'confirmed pulmonary embolism',
    ]);
    return m54DirectConfirmation || (pe && confirmed);
  }

  static bool _cRespiratoryModifier(
    String q,
    double? spo2,
    double? respiratoryRate,
  ) {
    return (spo2 != null && spo2 < 90) ||
        (respiratoryRate != null && respiratoryRate >= 30) ||
        _hasAny(q, const [
          'oxigenio suplementar',
          'oxigeno suplementario',
          'supplemental oxygen',
          'necessitando o2',
          'requiere o2',
          'needs oxygen',
        ]);
  }

  static bool _dRespiratoryModifier(String q, double? oxygenFlow) {
    return (oxygenFlow != null && oxygenFlow > 6) ||
        _hasAny(q, const [
          'mascara nao reinalante',
          'mascara no reinhalante',
          'mascara con reservorio',
          'nonrebreather',
          'non-rebreather',
        ]);
  }

  static bool _eRespiratoryModifier(String q) {
    return _hasAny(q, const [
      'falencia respiratoria',
      'falla respiratoria',
      'insuficiencia respiratoria',
      'respiratory failure',
      'ventilacao nao invasiva',
      'ventilacion no invasiva',
      'ventilacao invasiva',
      'ventilacion invasiva',
      'pressao positiva',
      'presion positiva',
      'positive pressure ventilation',
      'intubado',
      'intubada',
      'intubated',
    ]);
  }

  // TEP_2026_PLANTAO_FULL_CLASSIFICATION_RENDER_V1
  //
  // "classification-only" deve significar pedido DIRETO para mostrar a
  // classificacao. Mencionar "categoria" em uma pergunta explicativa
  // ("por que corresponde a essa categoria?") NAO pode sequestrar a intencao.
  static bool _isClassificationOnlyRequest(String input) {
    final q = _fold(input)
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const exactDirectRequests = <String>{
      // PT
      'classificacao',
      'a classificacao',
      'qual a classificacao',
      'qual e a classificacao',
      'e qual a classificacao',
      'e qual e a classificacao',
      'categoria',
      'a categoria',
      'qual a categoria',
      'qual e a categoria',
      'e qual a categoria',
      'e qual e a categoria',
      'qual o risco',
      'qual e o risco',
      // ES
      'clasificacion',
      'la clasificacion',
      'cual es la clasificacion',
      'y cual es la clasificacion',
      'la categoria',
      'cual es la categoria',
      'y cual es la categoria',
      'cual es el riesgo',
      'y cual es el riesgo',
      // EN
      'classification',
      'what is the classification',
      'what is the category',
      'risk category',
    };
    final isDirect =
        exactDirectRequests.contains(q) ||
        RegExp(
          r'^(classifique|clasifique|classify|classificacao|clasificacion|classification)\b',
        ).hasMatch(q);

    if (!isDirect) return false;

    final alsoAsksManagement = _hasAny(q, const [
      'conduta',
      'conducta',
      'manejo',
      'management',
      'tratamento',
      'tratamiento',
      'treatment',
      'terapia',
      'therapy',
      'anticoag',
      'trombol',
      'reperfus',
      'intern',
      'hospital',
      'alta',
      'ambulator',
      'o que fazer',
      'que hacer',
      'indique a conduta',
      'indique la conducta',
      'indique manejo',
    ]);

    return !alsoAsksManagement;
  }

  static String _renderClassificationOnly(
    Tep2026PlantaoResolution resolution, {
    required bool isEs,
  }) {
    final label = resolution.label;
    final c = resolution.category;

    if (isEs) {
      final reason = switch (c) {
        'A' => 'hallazgo incidental/asintomático.',
        'B1' =>
          'TEP sintomático de baja severidad clínica y localización subsegmentaria.',
        'B2' =>
          'TEP sintomático de baja severidad clínica, segmentario o más proximal.',
        'C1' => 'severidad clínica elevada con VD y biomarcadores normales.',
        'C2' =>
          'severidad clínica elevada con VD anormal O al menos un biomarcador anormal.',
        'C3' =>
          'severidad clínica elevada con VD anormal Y al menos un biomarcador anormal.',
        'D1' => 'falla cardiopulmonar incipiente con hipotensión transitoria.',
        'D2' =>
          'hipoperfusión/shock normotensivo aunque la presión sistólica esté preservada.',
        'E1' => 'hipotensión recurrente o persistente con shock cardiogénico.',
        'E2' => 'shock cardiogénico refractario o paro cardíaco.',
        _ => 'criterios clínicos compatibles con la categoría resuelta.',
      };

      final rLine = resolution.respiratoryModifier
          ? '* **R presente:** compromiso respiratorio añade el modificador R a la categoría del paciente.\n'
          : '* **R:** se añade cuando existe compromiso respiratorio definido para la categoría; no está presente con los datos aportados.\n';

      return 'TEP AGUDO CONFIRMADO — $label — CLASIFICACIÓN AHA/ACC 2026\n'
          ' Clasificación del paciente:\n'
          '* **Categoría del paciente: $label.** Motivo: $reason\n'
          'Clasificación AHA/ACC 2026:\n'
          '* Wells/Geneva/PERC/YEARS pertenecen a la probabilidad pretest diagnóstica; una vez confirmado el TEP no gobiernan gravedad ni tratamiento.\n'
          'Puntos clave:\n'
          '* **A — Subclínico:** TEP incidental/asintomático.\n'
          '* **B — Sintomático, baja severidad:** PESI ≤85, sPESI = 0 o Bova ≤4.\n'
          '  * **B1:** subsegmentario.\n'
          '  * **B2:** segmentario o más proximal.\n'
          '* **C — Sintomático, severidad elevada:** PESI >85, sPESI ≥1 o Bova >4.\n'
          '  * **C1:** VD normal + biomarcadores normales.\n'
          '  * **C2:** VD anormal **O** ≥1 biomarcador anormal.\n'
          '  * **C3:** VD anormal **Y** ≥1 biomarcador anormal.\n'
          '* **D — Falla cardiopulmonar incipiente:**\n'
          '  * **D1:** hipotensión transitoria.\n'
          '  * **D2:** shock normotensivo/hipoperfusión; una PAS preservada no lo excluye.\n'
          '* **E — Falla cardiopulmonar:**\n'
          '  * **E1:** hipotensión recurrente/persistente con shock cardiogénico.\n'
          '  * **E2:** shock cardiogénico refractario o paro cardíaco.\n'
          '$rLine'
          'RED FLAGS:\n'
          '* Hipotensión, hipoperfusión, deterioro del VD/biomarcadores o nuevo compromiso respiratorio obligan a reclasificar inmediatamente.\n'
          ' Clasificación final de este paciente: **$label**.\n'
          ' Categoría final: **$label**.';
    }

    final reason = switch (c) {
      'A' => 'achado incidental/assintomático.',
      'B1' =>
        'TEP sintomático de baixa gravidade clínica e localização subsegmentar.',
      'B2' =>
        'TEP sintomático de baixa gravidade clínica, segmentar ou mais proximal.',
      'C1' => 'gravidade clínica elevada com VD e biomarcadores normais.',
      'C2' =>
        'gravidade clínica elevada com VD anormal OU pelo menos um biomarcador anormal.',
      'C3' =>
        'gravidade clínica elevada com VD anormal E pelo menos um biomarcador anormal.',
      'D1' => 'falência cardiopulmonar incipiente com hipotensão transitória.',
      'D2' =>
        'Choque normotensivo/hipoperfusão mesmo com pressão sistólica preservada.',
      'E1' => 'hipotensão recorrente ou persistente com choque cardiogênico.',
      'E2' => 'choque cardiogênico refratário ou parada cardíaca.',
      _ => 'critérios clínicos compatíveis com a categoria resolvida.',
    };

    final rLine = resolution.respiratoryModifier
        ? '* **R presente:** comprometimento respiratório acrescenta o modificador R à categoria do paciente.\n'
        : '* **R:** acrescentar quando houver comprometimento respiratório definido para a categoria; não está presente com os dados fornecidos.\n';

    return 'TEP AGUDO CONFIRMADO — $label — CLASSIFICAÇÃO AHA/ACC 2026\n'
        ' Classificação do paciente:\n'
        '* **Categoria do paciente: $label.** Motivo: $reason\n'
        'Classificação AHA/ACC 2026:\n'
        '* Wells/Geneva/PERC/YEARS pertencem à probabilidade pré-teste diagnóstica; após confirmar TEP não governam gravidade nem tratamento.\n'
        'Pontos-chave:\n'
        '* **A — Subclínico:** TEP incidental/assintomático.\n'
        '* **B — Sintomático, baixa gravidade:** PESI ≤85, sPESI = 0 ou Bova ≤4.\n'
        '  * **B1:** subsegmentar.\n'
        '  * **B2:** segmentar ou mais proximal.\n'
        '* **C — Sintomático, gravidade elevada:** PESI >85, sPESI ≥1 ou Bova >4.\n'
        '  * **C1:** VD normal + biomarcadores normais.\n'
        '  * **C2:** VD anormal **OU** ≥1 biomarcador anormal.\n'
        '  * **C3:** VD anormal **E** ≥1 biomarcador anormal.\n'
        '* **D — Falência cardiopulmonar incipiente:**\n'
        '  * **D1:** hipotensão transitória.\n'
        '  * **D2:** Choque normotensivo/hipoperfusão; PAS preservada não exclui.\n'
        '* **E — Falência cardiopulmonar:**\n'
        '  * **E1:** hipotensão recorrente/persistente com choque cardiogênico.\n'
        '  * **E2:** choque cardiogênico refratário ou parada cardíaca.\n'
        '$rLine'
        'RED FLAGS:\n'
        '* Hipotensão, hipoperfusão, piora de VD/biomarcadores ou novo comprometimento respiratório exigem reclassificação imediata.\n'
        ' Classificação final deste paciente: **$label**.\n'
        ' Categoria final: **$label**.';
  }

  static String _render(
    Tep2026PlantaoResolution resolution, {
    required bool isEs,
  }) {
    final label = resolution.label;
    final c = resolution.category;

    if (isEs) {
      final immediate = <String>[];
      final keyPoints = <String>[];
      final redFlags = <String>[];
      String note;

      switch (c) {
        case 'A':
          immediate.addAll([
            '* Categoría AHA/ACC 2026: **A** — TEP incidental y asintomático.',
            '* Confirmar contexto clínico, riesgo de recurrencia y riesgo hemorrágico antes de definir anticoagulación.',
            '* Si se anticoagula, preferir DOAC sobre AVK cuando sea elegible; si se requiere fase parenteral, preferir HBPM sobre HNF salvo razón específica.',
          ]);
          keyPoints.add(
            '* No usar Wells para gravedad o tratamiento después de confirmar TEP.',
          );
          redFlags.add(
            '* Aparición de síntomas, hipoxemia, disfunción de VD o hipoperfusión obliga a reclasificar.',
          );
          note = 'Manejo individualizado y seguimiento estructurado.';
          break;
        case 'B1':
          immediate.addAll([
            '* Categoría AHA/ACC 2026: **B1**.',
            '* TEP subsegmentario sintomático con baja severidad clínica.',
            '* La decisión de anticoagular debe individualizarse según TVP concomitante, riesgo de recurrencia, riesgo hemorrágico y seguimiento; Wells no decide gravedad ni tratamiento tras confirmar TEP.',
            '* Si se anticoagula y se requiere fase parenteral, preferir HBPM sobre HNF salvo razón específica; si es elegible para vía oral, preferir DOAC sobre AVK.',
            '* Valorar alta precoz/manejo ambulatorio si existe estabilidad clínica, acceso inmediato al tratamiento y seguimiento fiable.',
          ]);
          keyPoints.addAll([
            '* No requiere ingreso en UCI/intermedios por la categoría B1 aislada.',
            '* **NO realizar trombólisis ni reperfusión avanzada de rutina.**',
          ]);
          redFlags.add(
            '* Nueva hipoxemia, disfunción de VD, biomarcadores anormales, hipotensión o hipoperfusión requieren reevaluación inmediata.',
          );
          note =
              'Categoría B1 explícita y conducta proporcional al riesgo 2026.';
          break;
        case 'B2':
          immediate.addAll([
            '* Categoría AHA/ACC 2026: **B2** — TEP sintomático no subsegmentario con baja severidad clínica.',
            '* Anticoagulación terapéutica si no existe contraindicación; DOAC preferido sobre AVK cuando sea elegible.',
            '* Si se requiere fase parenteral, preferir HBPM sobre HNF salvo razón específica.',
            '* Valorar alta precoz/ambulatoria si cumple criterios clínicos y seguimiento fiable.',
          ]);
          keyPoints.add(
            '* **NO realizar trombólisis ni reperfusión avanzada de rutina.**',
          );
          redFlags.add(
            '* Deterioro respiratorio, VD/biomarcadores anormales o hipoperfusión obligan a reclasificar.',
          );
          note = 'Manejo de baja severidad según AHA/ACC 2026.';
          break;
        case 'C1':
          immediate.addAll([
            '* Categoría AHA/ACC 2026: **$label** — severidad clínica elevada con VD y biomarcadores normales.',
            '* Hospitalizar y anticoagular si no existe contraindicación.',
            '* Activar evaluación multidisciplinaria/PERT cuando esté disponible.',
          ]);
          keyPoints.add(
            '* A-C1 no debe recibir reperfusión avanzada de rutina.',
          );
          redFlags.add(
            '* Hipoxemia progresiva, VD/biomarcadores anormales o hipoperfusión requieren reclasificación.',
          );
          note = 'Monitorización hospitalaria y reevaluación seriada.';
          break;
        case 'C2':
          immediate.addAll([
            '* Categoría AHA/ACC 2026: **$label** — severidad clínica elevada con VD anormal O biomarcador anormal, no ambos.',
            '* Hospitalizar, iniciar anticoagulación si no existe contraindicación y solicitar PERT/multidisciplinario cuando esté disponible.',
            '* **NO usar trombólisis sistémica de rutina sobre anticoagulación sola en C2.**',
          ]);
          keyPoints.add(
            '* La utilidad comparativa de terapias dirigidas por catéter/trombectomía es incierta; no indicarlas automáticamente.',
          );
          redFlags.add(
            '* Hipoperfusión, hipotensión o deterioro respiratorio/hemodinámico obligan a reclasificar.',
          );
          note =
              'C2 exige hospitalización, no trombólisis sistémica rutinaria.';
          break;
        case 'C3':
          immediate.addAll([
            // M55A_TEP_C3R_CLASSIFICATION_2COL_TABLE_V1
            'Clasificación AHA/ACC 2026:',
            '| Criterio / clasificación | Resultado en este paciente |',
            '| --- | --- |',
            '| Sistema | AHA/ACC 2026 |',
            '| Categoría / resultado final | **$label** |',
            '| Ventrículo derecho | Anormal |',
            '| Biomarcador | Al menos 1 anormal |',
            if (resolution.respiratoryModifier)
              '| Modificador respiratorio | **R** |',
            if (resolution.rvLvRatio != null)
              '| Relación VD/VI | **${resolution.rvLvRatio!.toStringAsFixed(1).replaceAll('.', ',')}** |',
            '* Hospitalizar, anticoagular si no existe contraindicación, monitorización estrecha y PERT/multidisciplinario.',
            if (resolution.respiratoryModifier)
              '* Modificador **R** presente por compromiso respiratorio; la hipoxemia aislada no equivale a D2 sin hipoperfusión.',
          ]);
          keyPoints.add(
            '* En C3 el beneficio de trombólisis sistémica, lisis dirigida por catéter o trombectomía mecánica es incierto; individualizar, no indicar automáticamente.',
          );
          redFlags.add(
            '* Hipoperfusión o hipotensión cambia la categoría hacia D/E y modifica la estrategia.',
          );
          note =
              'C3${resolution.respiratoryModifier ? 'R' : ''}: vigilancia estrecha y decisión avanzada individualizada.';
          break;
        case 'D1':
          immediate.addAll([
            '* Categoría AHA/ACC 2026: **$label** — hipotensión transitoria, falla cardiopulmonar incipiente.',
            '* Hospitalización de alta complejidad, anticoagulación si procede y PERT/multidisciplinario.',
            '* Puede considerarse reperfusión avanzada de forma individualizada según evolución, sangrado, contraindicaciones y recursos.',
          ]);
          keyPoints.add(
            '* Diferenciar D1 de E1: la hipotensión de D1 es transitoria.',
          );
          redFlags.add(
            '* Hipotensión persistente/recurrente o shock cardiogénico requiere reclasificación a E1.',
          );
          note =
              'D1: vigilancia intensiva y estrategia de rescate individualizada.';
          break;
        case 'D2':
          immediate.addAll([
            '* Categoría AHA/ACC 2026: **$label** — shock normotensivo/hipoperfusión.',
            '* Una PAS preservada **NO excluye D2** cuando existen marcadores objetivos de hipoperfusión.',
            '* Hospitalización de alta complejidad, anticoagulación si procede, soporte hemodinámico según necesidad y PERT/multidisciplinario.',
            '* Puede considerarse reperfusión avanzada de forma individualizada según deterioro, riesgo hemorrágico, contraindicaciones y recursos.',
          ]);
          keyPoints.add(
            '* Lactato >2 mmol/L, LRA, diuresis <0,5 mL/kg/h, alteración mental, índice cardíaco <2,2 o PAM <60 son marcadores de D2.',
          );
          redFlags.add(
            '* Shock cardiogénico con hipotensión persistente o refractariedad obliga a reclasificar a E1/E2.',
          );
          note =
              'D2: hipoperfusión gobierna la categoría aunque la PAS sea normal.';
          break;
        case 'E1':
          immediate.addAll([
            '* Categoría AHA/ACC 2026: **$label** — hipotensión recurrente/persistente con shock cardiogénico.',
            '* Reanimación y soporte hemodinámico inmediatos, anticoagulación cuando sea apropiada y activación urgente de PERT/equipo de reperfusión.',
            '* Si se considera terapia avanzada, trombólisis sistémica, lisis dirigida por catéter, trombectomía mecánica o embolectomía quirúrgica son opciones razonables según contexto.',
          ]);
          keyPoints.add(
            '* Seleccionar estrategia por riesgo hemorrágico, contraindicaciones, tiempo y recursos.',
          );
          redFlags.add('* Refractariedad o paro cardíaco define E2.');
          note = 'E1 requiere estrategia avanzada urgente y contextual.';
          break;
        case 'E2':
          immediate.addAll([
            '* Categoría AHA/ACC 2026: **$label** — shock cardiogénico refractario o paro cardíaco.',
            '* Reanimación inmediata y activación urgente del equipo de reperfusión/PERT.',
            '* La trombólisis sistémica puede ser razonable cuando corresponda; VA-ECMO es razonable en centros con recursos y experiencia para shock refractario.',
          ]);
          keyPoints.add(
            '* No asumir beneficio establecido de una intervención invasiva adicional específica durante ECMO.',
          );
          redFlags.add(
            '* Situación de máxima gravedad: priorizar reanimación, perfusión y estrategia de reperfusión/rescate.',
          );
          note = 'E2: soporte vital y rescate avanzado inmediato.';
          break;
        default:
          return '';
      }

      return <String>[
        'TEP AGUDO CONFIRMADO — $label',
        'Conducta inmediata:',
        ...immediate,
        'Puntos clave:',
        ...keyPoints,
        'RED FLAGS:',
        ...redFlags,
        ' $note',
      ].join('\n');
    }

    final immediate = <String>[];
    final keyPoints = <String>[];
    final redFlags = <String>[];
    String note;

    switch (c) {
      case 'A':
        immediate.addAll([
          '* Categoria AHA/ACC 2026: **A** — TEP incidental e assintomático.',
          '* Confirmar contexto clínico, risco de recorrência e risco hemorrágico antes de definir anticoagulação.',
          '* Se anticoagular, preferir DOAC a AVK quando elegível; se fase parenteral for necessária, preferir HBPM a HNF salvo motivo específico.',
        ]);
        keyPoints.add(
          '* Não usar Wells para gravidade ou tratamento depois da confirmação do TEP.',
        );
        redFlags.add(
          '* Surgimento de sintomas, hipoxemia, disfunção de VD ou hipoperfusão exige reclassificação.',
        );
        note = 'Manejo individualizado e seguimento estruturado.';
        break;
      case 'B1':
        immediate.addAll([
          '* Categoria AHA/ACC 2026: **B1**.',
          '* TEP subsegmentar sintomático com baixa gravidade clínica.',
          '* A decisão de anticoagular deve ser individualizada conforme TVP concomitante, risco de recorrência, risco hemorrágico e seguimento; Wells não decide gravidade nem tratamento após confirmação.',
          '* Se anticoagular e fase parenteral for necessária, preferir HBPM a HNF salvo motivo específico; se elegível para via oral, preferir DOAC a AVK.',
          '* Avaliar alta precoce/manejo ambulatorial se houver estabilidade clínica, acesso imediato ao tratamento e seguimento confiável.',
        ]);
        keyPoints.addAll([
          '* Não requer UTI/intermediários apenas pela categoria B1 isolada.',
          '* **NÃO realizar trombólise nem reperfusão avançada de rotina.**',
        ]);
        redFlags.add(
          '* Nova hipoxemia, disfunção de VD, biomarcadores anormais, hipotensão ou hipoperfusão exigem reavaliação imediata.',
        );
        note = 'Categoria B1 explícita e conduta proporcional ao risco 2026.';
        break;
      case 'B2':
        immediate.addAll([
          '* Categoria AHA/ACC 2026: **B2** — TEP sintomático não subsegmentar com baixa gravidade clínica.',
          '* Anticoagulação terapêutica se não houver contraindicação; DOAC preferido a AVK quando elegível.',
          '* Se fase parenteral for necessária, preferir HBPM a HNF salvo motivo específico.',
          '* Avaliar alta precoce/ambulatorial se preencher critérios clínicos e seguimento confiável.',
        ]);
        keyPoints.add(
          '* **NÃO realizar trombólise nem reperfusão avançada de rotina.**',
        );
        redFlags.add(
          '* Deterioração respiratória, VD/biomarcadores anormais ou hipoperfusão exigem reclassificação.',
        );
        note = 'Manejo de baixa gravidade segundo AHA/ACC 2026.';
        break;
      case 'C1':
        immediate.addAll([
          '* Categoria AHA/ACC 2026: **$label** — gravidade clínica elevada com VD e biomarcadores normais.',
          '* Hospitalizar e anticoagular se não houver contraindicação.',
          '* Acionar avaliação multidisciplinar/PERT quando disponível.',
        ]);
        keyPoints.add('* A-C1 não deve receber reperfusão avançada de rotina.');
        redFlags.add(
          '* Hipoxemia progressiva, VD/biomarcadores anormais ou hipoperfusão exigem reclassificação.',
        );
        note = 'Monitorização hospitalar e reavaliação seriada.';
        break;
      case 'C2':
        immediate.addAll([
          '* Categoria AHA/ACC 2026: **$label** — gravidade clínica elevada com VD anormal OU biomarcador anormal, não ambos.',
          '* Hospitalizar, iniciar anticoagulação se não houver contraindicação e acionar PERT/multidisciplinar quando disponível.',
          '* **NÃO usar trombólise sistêmica de rotina sobre anticoagulação isolada em C2.**',
        ]);
        keyPoints.add(
          '* A utilidade comparativa de terapias por cateter/trombectomia é incerta; não indicar automaticamente.',
        );
        redFlags.add(
          '* Hipoperfusão, hipotensão ou deterioração respiratória/hemodinâmica exigem reclassificação.',
        );
        note = 'C2 exige hospitalização, sem trombólise sistêmica rotineira.';
        break;
      case 'C3':
        immediate.addAll([
          // M55A_TEP_C3R_CLASSIFICATION_2COL_TABLE_V1
          'Classificação AHA/ACC 2026:',
          '| Critério / classificação | Resultado neste paciente |',
          '| --- | --- |',
          '| Sistema | AHA/ACC 2026 |',
          '| Categoria / resultado final | **$label** |',
          '| Ventrículo direito | Anormal |',
          '| Biomarcador | Pelo menos 1 anormal |',
          if (resolution.respiratoryModifier)
            '| Modificador respiratório | **R** |',
          if (resolution.rvLvRatio != null)
            '| Relação VD/VI | **${resolution.rvLvRatio!.toStringAsFixed(1).replaceAll('.', ',')}** |',
          '* Hospitalizar, anticoagular se não houver contraindicação, monitorização estreita e PERT/multidisciplinar.',
          if (resolution.respiratoryModifier)
            '* Modificador **R** presente por comprometimento respiratório; hipoxemia isolada não equivale a D2 sem hipoperfusão.',
        ]);
        keyPoints.add(
          '* Em C3, o benefício de trombólise sistêmica, lise dirigida por cateter ou trombectomia mecânica é incerto; individualizar, não indicar automaticamente.',
        );
        redFlags.add(
          '* Hipoperfusão ou hipotensão muda a categoria para D/E e altera a estratégia.',
        );
        note =
            'C3${resolution.respiratoryModifier ? 'R' : ''}: vigilância estreita e decisão avançada individualizada.';
        break;
      case 'D1':
        immediate.addAll([
          '* Categoria AHA/ACC 2026: **$label** — hipotensão transitória, falência cardiopulmonar incipiente.',
          '* Hospitalização de alta complexidade, anticoagulação quando apropriada e PERT/multidisciplinar.',
          '* Pode-se considerar reperfusão avançada individualmente conforme evolução, sangramento, contraindicações e recursos.',
        ]);
        keyPoints.add(
          '* Diferenciar D1 de E1: a hipotensão em D1 é transitória.',
        );
        redFlags.add(
          '* Hipotensão persistente/recorrente ou choque cardiogênico exige reclassificação para E1.',
        );
        note =
            'D1: vigilância intensiva e estratégia de resgate individualizada.';
        break;
      case 'D2':
        immediate.addAll([
          '* Categoria AHA/ACC 2026: **$label** — choque normotensivo/hipoperfusão.',
          '* PAS preservada **NÃO exclui D2** quando existem marcadores objetivos de hipoperfusão.',
          '* Hospitalização de alta complexidade, anticoagulação quando apropriada, suporte hemodinâmico conforme necessidade e PERT/multidisciplinar.',
          '* Pode-se considerar reperfusão avançada individualmente conforme deterioração, risco hemorrágico, contraindicações e recursos.',
        ]);
        keyPoints.add(
          '* Lactato >2 mmol/L, LRA, diurese <0,5 mL/kg/h, alteração mental, índice cardíaco <2,2 ou PAM <60 são marcadores de D2.',
        );
        redFlags.add(
          '* Choque cardiogênico com hipotensão persistente ou refratariedade exige reclassificação para E1/E2.',
        );
        note = 'D2: hipoperfusão governa a categoria mesmo com PAS normal.';
        break;
      case 'E1':
        immediate.addAll([
          '* Categoria AHA/ACC 2026: **$label** — hipotensão recorrente/persistente com choque cardiogênico.',
          '* Reanimação e suporte hemodinâmico imediatos, anticoagulação quando apropriada e ativação urgente de PERT/equipe de reperfusão.',
          '* Se terapia avançada for considerada, trombólise sistêmica, lise dirigida por cateter, trombectomia mecânica ou embolectomia cirúrgica são opções razoáveis conforme o contexto.',
        ]);
        keyPoints.add(
          '* Selecionar estratégia conforme risco hemorrágico, contraindicações, tempo e recursos.',
        );
        redFlags.add('* Refratariedade ou parada cardíaca define E2.');
        note = 'E1 requer estratégia avançada urgente e contextual.';
        break;
      case 'E2':
        immediate.addAll([
          '* Categoria AHA/ACC 2026: **$label** — choque cardiogênico refratário ou parada cardíaca.',
          '* Reanimação imediata e ativação urgente da equipe de reperfusão/PERT.',
          '* Trombólise sistêmica pode ser razoável quando apropriada; VA-ECMO é razoável em centros com recursos e experiência para choque refratário.',
        ]);
        keyPoints.add(
          '* Não assumir benefício estabelecido de uma intervenção invasiva adicional específica durante ECMO.',
        );
        redFlags.add(
          '* Situação de máxima gravidade: priorizar reanimação, perfusão e estratégia de reperfusão/resgate.',
        );
        note = 'E2: suporte vital e resgate avançado imediatos.';
        break;
      default:
        return '';
    }

    return <String>[
      'TEP AGUDO CONFIRMADO — $label',
      'Conduta imediata:',
      ...immediate,
      'Pontos-chave:',
      ...keyPoints,
      'RED FLAGS:',
      ...redFlags,
      ' $note',
    ].join('\n');
  }

  static bool _hasAny(String source, List<String> needles) =>
      needles.any(source.contains);

  static double? _numberAfter(String source, RegExp pattern) {
    final match = pattern.firstMatch(source);
    final raw = match?.group(1);
    if (raw == null) return null;
    return double.tryParse(raw.replaceAll(',', '.'));
  }

  static String _fold(String input) {
    return input
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
}
