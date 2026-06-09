// drug_interaction_service.dart — Detecção de interacciones medicamentosas
// Base de dados embutida (offline, sem API externa)
// Fontes: Goodman & Gilman 14ª ed., Katzung 15ª ed., Micromedex, UpToDate,
//         Lexicomp, Harrison's, FDA Drug Labels, ESC/AHA/IDSA guidelines

// ─────────────────────────────────────────────────────────────────────────────
// ENUMERAÇÕES DO SISTEMA DE INTERAÇÕES
// ─────────────────────────────────────────────────────────────────────────────

/// Severidade da interacción (5 niveles clínicos)
enum InteractionSeverity {
  contraindicated, // CONTRAINDICADA — não utilizar juntos em nenhuma circunstância
  major,           // GRAVE / ALTO RIESGO — riesgo clínico grave, evitar combinación
  moderate,        // MODERADA — monitorar com atención, ajuste de dosis posible
  minor,           // LEVE — relevância clínica baixa, vigilancia simples
  monitorOnly,     // SÓ MONITORIZAR — interacción teórica/leve, vigilancia periódica
}

/// Nivel de evidência científica da interacción
enum EvidenceLevel {
  established,  // Estabelecida — documentada em múltiplos estudos clínicos controlados
  probable,     // Probable — evidência consistente mas limitada ou de estudos menores
  possible,     // Posible — baseada em relatos de caso ou mecanismo farmacológico plausível
  theoretical,  // Teórica — baseada em farmacodinâmica/cinética, sem confirmação clínica direta
}

/// Tipos de riesgo clínico envolvidos na interacción
enum RiskType {
  qtProlongation,        // Prolongamento do intervalo QT / Torsades de Pointes
  hemorrhagic,           // Riesgo hemorrágico / sangrado
  arrhythmia,            // Arritmia cardíaca (não-QT)
  respiratoryDepression, // Depresión respiratoria / apnea
  serotonin,             // Síndrome serotoninérgica
  nephrotoxicity,        // Nefrotoxicidad / lesão renal aguda
  hepatotoxicity,        // Hepatotoxicidad / lesão hepática
  plasmaLevel,           // Alteração de niveles plasmáticos (CYP/P-gp)
  cardiovascular,        // Hipotensión, bradicardia, colapso hemodinâmico
  reducedEfficacy,       // Reducción de eficácia terapéutica
  increasedToxicity,     // Aumento de toxicidad do fármaco
  hypoglycemia,          // Hipoglucemia
  hyperkalemia,          // Hiperpotasemia
  hypokalemia,           // Hipopotasemia
  cns,                   // Depresión del SNC / sedación excesiva
  myopathy,              // Miopatía / rabdomiólisis
  myelosuppression,      // Mielossupresión / citopenia
  infection,             // Riesgo aumentado de infecções
  thrombosis,            // Riesgo tromboembólico
  electrolyte,           // Trastorno electrolítico (hipo/hiperpotasemia, hipomagnesemia, etc.)
  seizure,               // Riesgo convulsivo / rebaixamento do limiar convulsivo
  ototoxicity,           // Ototoxicidad / perda auditiva
  other,                 // Outro riesgo clínico relevante
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE INTERAÇÃO EXPANDIDO
// ─────────────────────────────────────────────────────────────────────────────

/// Resultado completo de uma interacción medicamentosa detectada
class DrugInteraction {
  final String drug1;                // Nome do fármaco 1 (para exibição)
  final String drug2;                // Nome do fármaco 2 (para exibição)
  final InteractionSeverity severity;
  final String mechanism;            // Mecanismo farmacológico (ES — fonte dos dados)
  final String effect;               // Efecto clínico resultante (ES — fonte dos dados)
  final String management;           // Conduta recomendada (ES — fonte dos dados)
  final String clinicalAlert;        // Alerta visual objetivo (ES — fonte dos dados)
  final EvidenceLevel evidenceLevel;
  final Set<RiskType> riskTypes;
  final List<String> references;

  // Campos opcionais em PT — quando fornecidos, sobrepõem a tradução automática
  final String? mechanismPt;
  final String? effectPt;
  final String? managementPt;
  final String? clinicalAlertPt;

  const DrugInteraction({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.mechanism,
    required this.effect,
    required this.management,
    required this.clinicalAlert,
    required this.evidenceLevel,
    required this.riskTypes,
    required this.references,
    this.mechanismPt,
    this.effectPt,
    this.managementPt,
    this.clinicalAlertPt,
  });

  // ── Getters bilíngues ──────────────────────────────────────────────────────
  // Retorna o campo no idioma correto.
  // Prioridade: campo PT explícito → tradução automática → original ES.
  // A tradução automática cobre os padrões mais frequentes da base de dados.

  String clinicalAlertL10n({bool isEs = true}) {
    if (isEs) return _toEs(clinicalAlert);
    if (clinicalAlertPt != null) return clinicalAlertPt!;
    return _translateAlert(clinicalAlert);
  }

  String effectL10n({bool isEs = true}) {
    if (isEs) return _toEs(effect);
    if (effectPt != null) return effectPt!;
    return _translateText(effect);
  }

  String mechanismL10n({bool isEs = true}) {
    if (isEs) return _toEs(mechanism);
    if (mechanismPt != null) return mechanismPt!;
    return _translateText(mechanism);
  }

  String managementL10n({bool isEs = true}) {
    if (isEs) return _toEs(management);
    if (managementPt != null) return managementPt!;
    return _translateText(management);
  }

  // ── Normalizador PT → ES ──────────────────────────────────────────────────
  // Alguns registros da base de dados foram inseridos com texto em PT ou misto.
  // Este método converte os padrões PT mais frequentes para ES antes de exibir,
  // garantindo que usuários com idioma ES vejam texto consistente em espanhol.
  static String _toEs(String s) => s
    // ── Verbos: forma PT → ES ──────────────────────────────────────────────
    .replaceAll('Monitorar ', 'Monitorizar ')
    .replaceAll('monitorar ', 'monitorizar ')
    .replaceAll('Monitorar.', 'Monitorizar.')
    .replaceAll('monitorar.', 'monitorizar.')
    .replaceAll('Monitorar,', 'Monitorizar,')
    .replaceAll('monitorar,', 'monitorizar,')
    .replaceAll('monitorar\n', 'monitorizar\n')
    .replaceAll('Cessar ', 'Suspender ')
    .replaceAll('cessar ', 'suspender ')
    .replaceAll('Cessar.', 'Suspender.')
    .replaceAll('cessar.', 'suspender.')
    .replaceAll('inibem ', 'inhiben ')
    .replaceAll('Inibem ', 'Inhiben ')
    .replaceAll('causam ', 'causan ')
    .replaceAll('Causam ', 'Causan ')
    .replaceAll('reduzem ', 'reducen ')
    .replaceAll('Reduzem ', 'Reducen ')
    .replaceAll('aumentam ', 'aumentan ')
    .replaceAll('Aumentam ', 'Aumentan ')
    .replaceAll('elevam ', 'elevan ')
    .replaceAll('Elevam ', 'Elevan ')
    .replaceAll('formam ', 'forman ')
    .replaceAll('Formam ', 'Forman ')
    .replaceAll('deslocam ', 'desplazan ')
    .replaceAll('Deslocam ', 'Desplazan ')
    .replaceAll('inibem.', 'inhiben.')
    .replaceAll('causam.', 'causan.')
    .replaceAll('reduzem.', 'reducen.')
    .replaceAll('aumentam.', 'aumentan.')
    .replaceAll(' inibe ', ' inhibe ')
    .replaceAll(' Inibe ', ' Inhibe ')
    .replaceAll(' reduz ', ' reduce ')
    .replaceAll(' Reduz ', ' Reduce ')
    .replaceAll(' eleva ', ' eleva ')  // same in ES
    .replaceAll('reduzindo ', 'reduciendo ')
    .replaceAll('Reduzindo ', 'Reduciendo ')
    // ── Substantivos PT → ES ───────────────────────────────────────────────
    .replaceAll('antiagregação', 'antiagregación')
    .replaceAll('Antiagregação', 'Antiagregación')
    .replaceAll('anticoagulação', 'anticoagulación')
    .replaceAll('Anticoagulação', 'Anticoagulación')
    .replaceAll('coagulação', 'coagulación')
    .replaceAll('Coagulação', 'Coagulación')
    .replaceAll('ativação', 'activación')
    .replaceAll('Ativação', 'Activación')
    .replaceAll('inativação', 'inactivación')
    .replaceAll('Inativação', 'Inactivación')
    .replaceAll('inibição', 'inhibición')
    .replaceAll('Inibição', 'Inhibición')
    .replaceAll('quelação', 'quelación')
    .replaceAll('Quelação', 'Quelación')
    .replaceAll('potenciação', 'potenciación')
    .replaceAll('Potenciação', 'Potenciación')
    .replaceAll('hiperestimulação', 'hiperestimulación')
    .replaceAll('Hiperestimulação', 'Hiperestimulación')
    .replaceAll('sangramento', 'sangrado')
    .replaceAll('Sangramento', 'Sangrado')
    .replaceAll('tiazídicos', 'tiazídicos')  // same
    .replaceAll('Tiazídicos', 'Tiazídicos')  // same
    .replaceAll('serotoninérgica', 'serotoninérgica')  // accepted in ES too
    .replaceAll('hiperestimulação', 'hiperestimulación')
    // ── Preposições / artigos PT → ES ──────────────────────────────────────
    .replaceAll(' pelo ', ' por el ')
    .replaceAll(' Pelo ', ' Por el ')
    .replaceAll(' pela ', ' por la ')
    .replaceAll(' Pela ', ' Por la ')
    .replaceAll(' pelo\n', ' por el\n')
    .replaceAll(' pela\n', ' por la\n')
    .replaceAll('(pelo ', '(por el ')
    .replaceAll('(pela ', '(por la ')
    .replaceAll(' após ', ' después de ')
    .replaceAll(' Após ', ' Después de ')
    .replaceAll('após ', 'después de ')
    .replaceAll(' ativamente', ' activamente')
    .replaceAll('ativamente.', 'activamente.')
    .replaceAll('ativamente,', 'activamente,')
    // ── Adjetivos/advérbios PT → ES ────────────────────────────────────────
    .replaceAll('essencial', 'esencial')
    .replaceAll('Essencial', 'Esencial')
    .replaceAll('necessário', 'necesario')
    .replaceAll('Necessário', 'Necesario')
    .replaceAll('disponível', 'disponible')
    .replaceAll('Disponível', 'Disponible')
    .replaceAll('insolúvel', 'insoluble')
    .replaceAll('Insolúvel', 'Insoluble')
    .replaceAll('drásticamente', 'drásticamente')  // same in ES
    // ── Locuções mistas comuns ─────────────────────────────────────────────
    .replaceAll('monitorar em SCA', 'monitorizar en SCA')
    .replaceAll('monitorar em ', 'monitorizar en ')
    .replaceAll('quando clinicamente', 'cuando clínicamente')
    .replaceAll('Quando clinicamente', 'Cuando clínicamente')
    .replaceAll('em compensação', 'en compensación')
    .replaceAll('em SCA', 'en SCA')
    .replaceAll('Combinación usada em', 'Combinación usada en')
    .replaceAll('combinación usada em', 'combinación usada en')
    .replaceAll('complexo insolúvel', 'complejo insoluble')
    .replaceAll('complexo insoluble', 'complejo insoluble')
    .replaceAll('do riesgo', 'del riesgo')
    .replaceAll('do nivel', 'del nivel')
    .replaceAll(' maior', ' mayor')
    .replaceAll('qualquer', 'cualquier')
    .replaceAll('Qualquer', 'Cualquier')
    // ── Preposição ' em ' (PT) → ' en ' (ES) — seguro pois 'em' não existe em ES ──
    .replaceAll(' em ', ' en ')
    .replaceAll(' Em ', ' En ');

  // ── Tradutor automático ES → PT ───────────────────────────────────────────
  // Cobre padrões de alta frequência dos campos clinicalAlert, effect,
  // mechanism e management da base de dados embutida.
  static String _translateAlert(String es) {
    return es
      .replaceAll('Requiere monitorización clínica/laboratorial', 'Requer monitorização clínica/laboratorial')
      .replaceAll('Requiere monitorización clínica', 'Requer monitorização clínica')
      .replaceAll('Requiere monitorización de INR', 'Requer monitorização do INR')
      .replaceAll('Requiere monitorización de potasio sérico', 'Requer monitorização do potássio sérico')
      .replaceAll('Requiere monitorización de K+ sérico', 'Requer monitorização do K+ sérico')
      .replaceAll('Requiere monitorización de nivel sérico', 'Requer monitorização do nível sérico')
      .replaceAll('Requiere monitorización de glucemia', 'Requer monitorização da glicemia')
      .replaceAll('Requiere monitorización de PA y función renal', 'Requer monitorização da PA e função renal')
      .replaceAll('Requiere monitorización de TSH', 'Requer monitorização do TSH')
      .replaceAll('Requiere monitorización renal diaria', 'Requer monitorização renal diária')
      .replaceAll('Requiere monitorización glucémica', 'Requer monitorização glicêmica')
      .replaceAll('Requiere monitorización', 'Requer monitorização')
      .replaceAll('riesgo hemorrágico aditivo', 'risco hemorrágico aditivo')
      .replaceAll('riesgo hemorrágico grave', 'risco hemorrágico grave')
      .replaceAll('riesgo hemorrágico', 'risco hemorrágico')
      .replaceAll('riesgo de miopatía', 'risco de miopatia')
      .replaceAll('riesgo renal', 'risco renal')
      .replaceAll('Elevación marcada del INR', 'Elevação marcada do INR')
      .replaceAll('depresión respiratoria aditiva', 'depressão respiratória aditiva')
      .replaceAll('neurotoxicidad', 'neurotoxicidade')
      .replaceAll('signos de hipoglucemia enmascarados', 'sinais de hipoglicemia mascarados')
      .replaceAll('toxicidad anticolinérgica aditiva', 'toxicidade anticolinérgica aditiva')
      .replaceAll('toxicidad digitálica por aumento de nivel', 'toxicidade digitálica por aumento de nível')
      .replaceAll('limitar simvastatina a 20 mg/día', 'limitar sinvastatina a 20 mg/dia')
      .replaceAll('limitar dosis de estatina', 'limitar dose de estatina')
      .replaceAll('eficacia reducida', 'eficácia reduzida')
      .replaceAll('depleción de volumen', 'depleção de volume')
      .replaceAll('evitar AINEs con heparina', 'evitar AINEs com heparina')
      .replaceAll('analgesia del tramadol puede reducirse', 'analgesia do tramadol pode reduzir-se')
      .replaceAll('reducir insulina al iniciar iSGLT2', 'reduzir insulina ao iniciar iSGLT2')
      .replaceAll('reducir insulina al iniciar arGLP-1', 'reduzir insulina ao iniciar arGLP-1')
      .replaceAll('reducir sulfonilurea al iniciar semaglutida', 'reduzir sulfonilureia ao iniciar semaglutida')
      .replaceAll('Nunca suspender clonidina abruptamente', 'Nunca suspender clonidina abruptamente')
      .replaceAll('Sin interacciones', 'Sem interações')
      .replaceAll('con riesgo', 'com risco')
      .replaceAll('durante el tratamiento', 'durante o tratamento')
      // ── Alertas compostos de alta frequência ──────────────────────────────
      .replaceAll('DOBLE ANTIAGREGACIÓN', 'DUPLA ANTIAGREGAÇÃO')
      .replaceAll('Doble antiagregación', 'Dupla antiagregação')
      .replaceAll('doble antiagregación', 'dupla antiagregação')
      .replaceAll('SANGRADO AUMENTADO', 'SANGRAMENTO AUMENTADO')
      .replaceAll('Sangrado aumentado', 'Sangramento aumentado')
      .replaceAll('Necesaria en SCA/stent', 'Necessária em SCA/stent')
      .replaceAll('necesaria en SCA/stent', 'necessária em SCA/stent')
      .replaceAll('pero monitorar sangrado', 'mas monitorar sangramento')
      .replaceAll('IBP obligatorio', 'IBP obrigatório')
      .replaceAll('ibp obligatorio', 'IBP obrigatório')
      .replaceAll('RIESGO DE', 'RISCO DE')
      .replaceAll('Riesgo de', 'Risco de')
      .replaceAll('riesgo de', 'risco de')
      .replaceAll('puede causar', 'pode causar')
      .replaceAll('GRAVE —', 'GRAVE —')
      .replaceAll('CONTRAIND', 'CONTRAINDICADO')
      .replaceAll('Contraindicado', 'Contraindicado')
      .replaceAll('contraindicado', 'contraindicado')
      .replaceAll('arritmia fatal', 'arritmia fatal');
  }

  static String _translateText(String es) {
    return es
      // ── Verbos comuns ──────────────────────────────────────────────────────
      .replaceAll('Monitorizar', 'Monitorizar')
      .replaceAll('monitorizar', 'monitorizar')
      .replaceAll('Evitar', 'Evitar')
      .replaceAll('evitar', 'evitar')
      .replaceAll('Reducir', 'Reduzir')
      .replaceAll('reducir', 'reduzir')
      .replaceAll('Aumenta', 'Aumenta')
      .replaceAll('aumenta', 'aumenta')
      .replaceAll('Disminuye', 'Diminui')
      .replaceAll('disminuye', 'diminui')
      .replaceAll('Inhibe', 'Inibe')
      .replaceAll('inhibe', 'inibe')
      .replaceAll('Potencia', 'Potencializa')
      .replaceAll('potencia', 'potencializa')
      .replaceAll('Suspender', 'Suspender')
      .replaceAll('suspender', 'suspender')
      .replaceAll('Considerar', 'Considerar')
      .replaceAll('considerar', 'considerar')
      .replaceAll('Ajustar', 'Ajustar')
      .replaceAll('ajustar', 'ajustar')
      .replaceAll('Preferir', 'Preferir')
      .replaceAll('preferir', 'preferir')
      // ── Termos clínicos ────────────────────────────────────────────────────
      .replaceAll('hemorragia', 'hemorragia')
      .replaceAll('hemorrágico', 'hemorrágico')
      .replaceAll('hemorrágica', 'hemorrágica')
      .replaceAll('sangrado', 'sangramento')
      .replaceAll('riesgo', 'risco')
      .replaceAll('nivel sérico', 'nível sérico')
      .replaceAll('niveles séricos', 'níveis séricos')
      .replaceAll('niveles plasmáticos', 'níveis plasmáticos')
      .replaceAll('nivel plasmático', 'nível plasmático')
      .replaceAll('dosis', 'dose')
      .replaceAll('función renal', 'função renal')
      .replaceAll('función hepática', 'função hepática')
      .replaceAll('presión arterial', 'pressão arterial')
      .replaceAll('frecuencia cardíaca', 'frequência cardíaca')
      .replaceAll('intervalo QT', 'intervalo QT')
      .replaceAll('potasio sérico', 'potássio sérico')
      .replaceAll('potasio', 'potássio')
      .replaceAll('magnesio', 'magnésio')
      .replaceAll('calcio', 'cálcio')
      .replaceAll('glucemia', 'glicemia')
      .replaceAll('glucosa', 'glicose')
      .replaceAll('hipoglucemia', 'hipoglicemia')
      .replaceAll('hiperpotasemia', 'hiperpotassemia')
      .replaceAll('hipopotasemia', 'hipopotassemia')
      .replaceAll('hipomagnesemia', 'hipomagnesemia')
      .replaceAll('hipotensión', 'hipotensão')
      .replaceAll('bradicardia', 'bradicardia')
      .replaceAll('taquicardia', 'taquicardia')
      .replaceAll('arritmia', 'arritmia')
      .replaceAll('neurotoxicidad', 'neurotoxicidade')
      .replaceAll('nefrotoxicidad', 'nefrotoxicidade')
      .replaceAll('hepatotoxicidad', 'hepatotoxicidade')
      .replaceAll('miopatía', 'miopatia')
      .replaceAll('rabdomiólisis', 'rabdomiólise')
      .replaceAll('mielodepresión', 'mielossupressão')
      .replaceAll('sedación', 'sedação')
      .replaceAll('toxicidad', 'toxicidade')
      .replaceAll('interacción', 'interação')
      .replaceAll('interacciones', 'interações')
      .replaceAll('combinación', 'combinação')
      .replaceAll('combinaciones', 'combinações')
      .replaceAll('medicación', 'medicação')
      .replaceAll('medicaciones', 'medicações')
      .replaceAll('alternativa', 'alternativa')
      .replaceAll('contraindicado', 'contraindicado')
      .replaceAll('contraindicada', 'contraindicada')
      .replaceAll('indicación', 'indicação')
      .replaceAll('prescripción', 'prescrição')
      .replaceAll('tratamiento', 'tratamento')
      .replaceAll('terapia', 'terapia')
      .replaceAll('vigilancia', 'vigilância')
      .replaceAll('monitoreo', 'monitoramento')
      .replaceAll('monitorización', 'monitorização')
      .replaceAll('seguimiento', 'acompanhamento')
      .replaceAll('evaluación', 'avaliação')
      // ── Farmacocinética ────────────────────────────────────────────────────
      .replaceAll('metabolismo hepático', 'metabolismo hepático')
      .replaceAll('metabolismo', 'metabolismo')
      .replaceAll('absorción', 'absorção')
      .replaceAll('excreción', 'excreção')
      .replaceAll('eliminación', 'eliminação')
      .replaceAll('biodisponibilidad', 'biodisponibilidade')
      .replaceAll('vida media', 'meia-vida')
      .replaceAll('aclaramiento', 'depuração')
      .replaceAll('inhibidor', 'inibidor')
      .replaceAll('inductor', 'indutor')
      .replaceAll('sustrato', 'substrato')
      // ── Conectivos e preposições ───────────────────────────────────────────
      .replaceAll('del INR', 'do INR')
      .replaceAll('del paciente', 'do paciente')
      .replaceAll('del tratamiento', 'do tratamento')
      .replaceAll('de la dosis', 'da dose')
      .replaceAll('de los síntomas', 'dos sintomas')
      .replaceAll('con el', 'com o')
      .replaceAll('con la', 'com a')
      .replaceAll('con los', 'com os')
      .replaceAll('con las', 'com as')
      .replaceAll('durante el', 'durante o')
      .replaceAll('durante la', 'durante a')
      .replaceAll(' al ', ' ao ')
      .replaceAll(' en el ', ' no ')
      .replaceAll(' en la ', ' na ')
      .replaceAll(' en los ', ' nos ')
      .replaceAll('puede ', 'pode ')
      .replaceAll('pueden ', 'podem ')
      .replaceAll('si hay', 'se houver')
      .replaceAll('si el', 'se o')
      .replaceAll('si la', 'se a')
      .replaceAll(' y ', ' e ')
      .replaceAll(' o ', ' ou ')
      .replaceAll('No utilizar', 'Não utilizar')
      .replaceAll('no utilizar', 'não utilizar')
      .replaceAll('No combinar', 'Não combinar')
      .replaceAll('no combinar', 'não combinar')
      .replaceAll('No recomendado', 'Não recomendado')
      .replaceAll('no recomendado', 'não recomendado')
      .replaceAll('Especialmente', 'Especialmente')
      .replaceAll('especialmente', 'especialmente')
      .replaceAll('Principalmente', 'Principalmente')
      .replaceAll('principalmente', 'principalmente')
      .replaceAll('Generalmente', 'Geralmente')
      .replaceAll('generalmente', 'geralmente')
      .replaceAll('generalmente', 'geralmente')
      .replaceAll('grave', 'grave')
      .replaceAll('severo', 'severo')
      .replaceAll('severa', 'severa')
      // ── Abreviações comuns ─────────────────────────────────────────────────
      .replaceAll('EV', 'EV')
      .replaceAll('VO', 'VO')
      .replaceAll('SC', 'SC')
      .replaceAll('IM', 'IM')
      .replaceAll('IV', 'IV')
      .replaceAll('/día', '/dia')
      .replaceAll('/semana', '/semana')
      .replaceAll('/mes', '/mês');
  }

  /// Rótulo curto da severidade
  /// Badge de severidade — bilíngue (padrão: es quando isEs=true)
  String get severityLabel {
    switch (severity) {
      case InteractionSeverity.contraindicated: return 'CONTRAINDICADA';
      case InteractionSeverity.major:           return 'GRAVE';
      case InteractionSeverity.moderate:        return 'MODERADA';
      case InteractionSeverity.minor:           return 'LEVE';
      case InteractionSeverity.monitorOnly:     return 'MONITORAR';
    }
  }

  String severityLabelL10n({bool isEs = true}) {
    switch (severity) {
      case InteractionSeverity.contraindicated: return 'CONTRAINDICADA';
      case InteractionSeverity.major:           return isEs ? 'GRAVE'      : 'GRAVE';
      case InteractionSeverity.moderate:        return isEs ? 'MODERADA'   : 'MODERADA';
      case InteractionSeverity.minor:           return isEs ? 'LEVE'       : 'LEVE';
      case InteractionSeverity.monitorOnly:     return isEs ? 'MONITOREAR' : 'MONITORAR';
    }
  }

  /// Rótulo longo da severidade — bilíngue
  String severityLongLabel({bool isEs = true}) {
    switch (severity) {
      case InteractionSeverity.contraindicated:
        return isEs ? 'CONTRAINDICADA — NO UTILIZAR JUNTOS' : 'CONTRAINDICADA — NO UTILIZAR JUNTOS';
      case InteractionSeverity.major:
        return isEs ? 'GRAVE — ALTO RIESGO'                : 'GRAVE — ALTO RIESGO';
      case InteractionSeverity.moderate:
        return isEs ? 'MODERADA — MONITOREAR'              : 'MODERADA — MONITORAR';
      case InteractionSeverity.minor:
        return isEs ? 'LEVE — VIGILANCIA'                  : 'LEVE — VIGILÂNCIA';
      case InteractionSeverity.monitorOnly:
        return isEs ? 'SOLO MONITORIZAR'                   : 'SÓ MONITORIZAR';
    }
  }

  /// Rótulo do nivel de evidência — bilíngue
  String evidenceLabel({bool isEs = true}) {
    switch (evidenceLevel) {
      case EvidenceLevel.established:  return isEs ? 'ESTABLECIDA'  : 'ESTABELECIDA';
      case EvidenceLevel.probable:     return isEs ? 'PROBABLE'     : 'PROVÁVEL';
      case EvidenceLevel.possible:     return isEs ? 'POSIBLE'      : 'POSSÍVEL';
      case EvidenceLevel.theoretical:  return isEs ? 'TEÓRICA'      : 'TEÓRICA';
    }
  }

  /// Rótulo legível de cada tipo de riesgo — bilíngue
  static String riskTypeLabel(RiskType r, {bool isEs = true}) {
    switch (r) {
      case RiskType.qtProlongation:        return '↑QT';
      case RiskType.hemorrhagic:           return isEs ? 'Hemorrágico'      : 'Hemorrágico';
      case RiskType.arrhythmia:            return isEs ? 'Arritmia'         : 'Arritmia';
      case RiskType.respiratoryDepression: return isEs ? 'Dep. Resp.'       : 'Dep. Resp.';
      case RiskType.serotonin:             return isEs ? 'Serotonina'       : 'Serotonina';
      case RiskType.nephrotoxicity:        return isEs ? 'Nefrotóxico'      : 'Nefrotóxico';
      case RiskType.hepatotoxicity:        return isEs ? 'Hepatotóxico'     : 'Hepatotóxico';
      case RiskType.plasmaLevel:           return isEs ? 'Nivel Plasmático' : 'Nivel Plasmático';
      case RiskType.cardiovascular:        return 'Cardiovascular';
      case RiskType.reducedEfficacy:       return isEs ? 'Eficacia ↓'       : 'Eficácia ↓';
      case RiskType.increasedToxicity:     return isEs ? 'Toxicidad ↑'      : 'Toxicidade ↑';
      case RiskType.hypoglycemia:          return isEs ? 'Hipoglucemia'     : 'Hipoglucemia';
      case RiskType.hyperkalemia:          return isEs ? 'Hiperpotasemia'   : 'Hiperpotasemia';
      case RiskType.hypokalemia:           return isEs ? 'Hipopotasemia'    : 'Hipopotasemia';
      case RiskType.cns:                   return isEs ? 'Depresión SNC'    : 'Depressão SNC';
      case RiskType.myopathy:              return isEs ? 'Miopatía'         : 'Miopatía';
      case RiskType.myelosuppression:      return isEs ? 'Mielosupresión'   : 'Mielossupresión';
      case RiskType.infection:             return isEs ? 'Infección'        : 'Infecção';
      case RiskType.thrombosis:            return isEs ? 'Trombosis'        : 'Trombose';
      case RiskType.electrolyte:           return isEs ? 'Electrolitos'     : 'Electrolitos';
      case RiskType.seizure:               return isEs ? 'Convulsión'       : 'Convulsão';
      case RiskType.ototoxicity:           return isEs ? 'Ototóxico'        : 'Ototóxico';
      case RiskType.other:                 return isEs ? 'Otro'             : 'Outro';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANCO DE INTERAÇÕES (termos normalizados para busca)
// Cada entrada: (id1, id2, severity, mechanism, effect, management,
//                clinicalAlert, evidenceLevel, {riskTypes}, [references])
// ─────────────────────────────────────────────────────────────────────────────
const _kRefGG   = 'Goodman & Gilman 13ª ed.';
const _kRefKatz = 'Katzung 13ª ed.';
const _kRefMdx  = 'Micromedex 2024';
const _kRefUT   = 'UpToDate 2024';
const _kRefLex  = 'Lexicomp 2024';
const _kRefFDA  = 'FDA Drug Label';

typedef _IxEntry = (
  String, String, InteractionSeverity,
  String, String, String,          // mechanism, effect, management
  String,                          // clinicalAlert
  EvidenceLevel,
  Set<RiskType>,
  List<String>,                    // references
);

const _interactionDB = <_IxEntry>[

  // ── AINES / Anticoagulantes ───────────────────────────────────────────────

  ('warfarina', 'aspirina', InteractionSeverity.major,
    'Inhibición plaquetaria aditiva + desplazamiento proteico aumentando INR',
    'Riesgo aumentado de sangrado grave (GI, intracraneal)',
    'Evitar combinación. Si necesario, usar dosis mínima de AAS (≤100 mg/día) con INR ≤2,5 y monitoreo frecuente',
    'ALTO RIESGO DE SANGRADO — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('warfarina', 'ibuprofeno', InteractionSeverity.major,
    'Desplazamiento de la unión proteica e inhibición plaquetaria',
    'Elevación del INR y riesgo de sangrado',
    'Evitar. Preferir paracetamol como analgésico. Monitorar INR si inevitable',
    'ALTO RIESGO DE SANGRADO — Use paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('warfarina', 'naproxeno', InteractionSeverity.major,
    'Desplazamiento de la unión proteica e inhibición plaquetaria',
    'Elevación del INR y riesgo de sangrado',
    'Evitar. Preferir paracetamol como analgésico. Monitorar INR si inevitable',
    'ALTO RIESGO DE SANGRADO — Use paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('warfarina', 'cetorolaco', InteractionSeverity.major,
    'AINE potente con efecto anticoagulante aditivo',
    'Riesgo hemorrágico grave — combinación peligrosa',
    'Contraindicado. Usar analgésico alternativo',
    'ALTO RIESGO HEMORRÁGICO — Contraindicado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefMdx, _kRefFDA]),

  ('warfarina', 'metronidazol', InteractionSeverity.major,
    'Inhibición del CYP2C9 reduce metabolismo de warfarina',
    'Aumento significativo del INR → riesgo de hemorragia',
    'Monitorar INR cada 2–3 días. Reducir dosis de warfarina en ~25–50%',
    'MONITORAR INR — Riesgo de hemorragia por aumento de nivel',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('warfarina', 'fluconazol', InteractionSeverity.major,
    'Inhibición potente del CYP2C9 y CYP3A4',
    'Elevación marcada del INR con riesgo hemorrágico grave',
    'Reducir dosis de warfarina 25–50%. Monitorar INR diariamente los primeros 3–5 días',
    'ALTO RIESGO HEMORRÁGICO — Reducir warfarina y monitorar INR',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefLex]),

  ('warfarina', 'amiodarona', InteractionSeverity.major,
    'Inhibición del CYP2C9 (metabolizador de warfarina S) por amiodarona y sus metabolitos',
    'Elevación progresiva del INR — el efecto puede durar semanas después de suspender amiodarona',
    'Reducir dosis de warfarina 30–50%. Monitorar INR semanalmente. El efecto persiste meses',
    'RIESGO HEMORRÁGICO PROLONGADO — El efecto persiste semanas después de suspender amiodarona',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('warfarina', 'ciprofloxacino', InteractionSeverity.moderate,
    'Inhibición del CYP1A2 y posible reducción de la flora intestinal productora de vitamina K',
    'Elevación del INR',
    'Monitorar INR 2–3 días después del inicio y 2–3 días después del fin del antibiótico',
    'Requiere monitorización de INR durante el tratamiento',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── Estatinas ─────────────────────────────────────────────────────────────

  ('sinvastatina', 'amiodarona', InteractionSeverity.major,
    'Inhibición del CYP3A4 aumenta concentración de simvastatina',
    'Riesgo de miopatía / rabdomiólisis',
    'Dosis máxima de sinvastatina: 20 mg/dia com amiodarona. Preferir rosuvastatina ou pravastatina',
    'RIESGO DE RABDOMIÓLISIS — Limitar simvastatina a 20 mg/día',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('sinvastatina', 'claritromicina', InteractionSeverity.major,
    'Inhibición potente del CYP3A4',
    'Riesgo de rabdomiólisis',
    'Suspender simvastatina durante el curso de claritromicina. Alternativa: azitromicina',
    'RIESGO DE RABDOMIÓLISIS — Suspender simvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('sinvastatina', 'eritromicina', InteractionSeverity.major,
    'Inhibición del CYP3A4',
    'Riesgo de miopatía/rabdomiólisis',
    'Suspender simvastatina durante el curso. Alternativa: azitromicina',
    'RIESGO DE RABDOMIÓLISIS — Suspender simvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),
    // DUPLICATA REMOVIDA: sinvastatina+fluconazol — par detalhado mantido como fluconazol+sinvastatina (linha ~1654)

  ('atorvastatina', 'claritromicina', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 aumenta nivel de atorvastatina',
    'Riesgo aumentado de miopatía',
    'Reducir dosis de atorvastatina. Preferir azitromicina',
    'Requiere monitorización — riesgo de miopatía',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('atorvastatina', 'amiodarona', InteractionSeverity.moderate,
    'Inhibición del CYP3A4',
    'Riesgo de miopatía',
    'Limitar atorvastatina a 40 mg/dia. Monitorar CPK y síntomas musculares',
    'Requiere monitorización clínica — limitar dosis de estatina',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── IECA / ARA-II / Diuréticos ────────────────────────────────────────────

  ('enalapril', 'espironolactona', InteractionSeverity.moderate,
    'Ambos elevan potasio sérico por mecanismos distintos',
    'Hiperpotasemia, especialmente en ERC o insuficiencia cardíaca',
    'Monitorar K+ sérico y función renal semanalmente al inicio; reducir dosis de espironolactona si K+ >5,5 mEq/L',
    'Requiere monitorización de potasio sérico',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),

  ('losartana', 'espironolactona', InteractionSeverity.moderate,
    'Ambos elevan potasio sérico',
    'Hiperpotasemia — más frecuente en IRC/ICF',
    'Monitorar K+ sérico y creatinina regularmente',
    'Requiere monitorización de potasio sérico',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),

  ('enalapril', 'alisquireno', InteractionSeverity.contraindicated,
    'Doble bloqueo del SRAA',
    'Hipotensión grave, hiperpotasemia e insuficiencia renal aguda',
    'Combinación contraindicada por guidelines (ESC 2016, JNC)',
    'NO UTILIZAR — Contraindicado por guías internacionales',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA, _kRefUT]),

  ('losartana', 'alisquireno', InteractionSeverity.contraindicated,
    'Doble bloqueo del SRAA',
    'Hipotensión grave, hiperpotasemia e insuficiencia renal aguda',
    'Combinación contraindicada — evitar em qualquer paciente',
    'NO UTILIZAR — Contraindicado por guías internacionales',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA]),

    // ── IECA + ARA-II (bloqueio duplo do SRAA) ───────────────────────────────

  ('enalapril', 'losartana', InteractionSeverity.contraindicated,
    'Doble bloqueo del SRAA: inhibición simultânea da ECA e do receptor AT1 da angiotensina II — sem benefício adicional, com riesgo multiplicado',
    'Hipotensión sintomática grave, hiperpotasemia potencialmente fatal, insuficiencia renal aguda (estudio ONTARGET)',
    'CONTRAINDICADO — No combinar IECA + ARA-II. Elegir uno de los dos. Excepción restringida: cardiólogo experto en IC refractaria con monitorización intensiva',
    'DOBLE BLOQUEO DEL SRAA — Contraindicado por ESC/AHA. Estudio ONTARGET demostró perjuicio sin beneficio',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT, _kRefFDA]),


  ('enalapril', 'aine', InteractionSeverity.moderate,
    'AINEs reducen síntesis de prostaglandinas vasodilatadoras renales',
    'Reducción del efecto antihipertensivo do IECA; riesgo de IRA',
    'Evitar uso crónico concomitante. Si necesario, monitorar PA y función renal',
    'Requiere monitorización clínica/laboratorial — riesgo renal',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

    // ── Betabloqueadores ──────────────────────────────────────────────────────

  ('metoprolol', 'verapamil', InteractionSeverity.major,
    'Efecto aditivo de ambos en el nodo AV (cronotropismo y dromotropismo negativos)',
    'Bradicardia grave, bloqueo AV completo, hipotensión, ICC',
    'Contraindicado en la mayoría de situaciones. Si inevitable, monitorar con ECG continuo',
    'ALTO RIESGO CARDIOVASCULAR — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('metoprolol', 'diltiazem', InteractionSeverity.major,
    'Efecto aditivo en el nodo sinusal y AV',
    'Bradicardia, bloqueo AV, hipotensión',
    'Evitar combinación. Si necesario, iniciar con dosis muy bajas y monitorar ECG',
    'ALTO RIESGO CARDIOVASCULAR — Monitorar ECG continuamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  ('propranolol', 'verapamil', InteractionSeverity.major,
    'Efecto aditivo no nó AV',
    'Bradicardia grave, bloqueo AV, paro cardíaco (reportes)',
    'Contraindicado — alternativa: usar solo uno de ellos',
    'ALTO RIESGO DE PARO CARDÍACO — Contraindicado',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('metoprolol', 'clonidina', InteractionSeverity.moderate,
    'La retirada abrupta de clonidina con betabloqueador causa hipertensión de rebote grave',
    'Crisis hipertensiva de rebote al suspender clonidina',
    'Nunca suspender clonidina abruptamente; si se suspende, retirar betabloqueador primero',
    'Requiere monitorización — Nunca suspender clonidina abruptamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

    // ── Antiarrítmicos ────────────────────────────────────────────────────────

  ('amiodarona', 'sotalol', InteractionSeverity.contraindicated,
    'Prolongación aditiva del intervalo QT',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita',
    'Contraindicado — nunca combinar antiarrítmicos que prolongan QT',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Riesgo de muerte súbita',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('amiodarona', 'haloperidol', InteractionSeverity.major,
    'Prolongación aditiva del QT',
    'Torsades de Pointes',
    'Evitar. Si necesario, monitorar QTc con ECG regular',
    'ALTO RIESGO DE TORSADES DE POINTES — Monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('amiodarona', 'digoxina', InteractionSeverity.major,
    'Inhibición de la P-glucoproteína aumenta nivel sérico de digoxina',
    'Toxicidad digitálica — náuseas, bradicardia, trastornos visuales',
    'Reducir dosis de digoxina 50%. Monitorar nivel sérico y ECG',
    'ALTO RIESGO DE TOXICIDAD DIGITÁLICA — Reducir dosis de digoxina 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('digoxina', 'furosemida', InteractionSeverity.moderate,
    'Furosemida causa hipopotasemia que potencializa toxicidad de digoxina',
    'Arritmias por toxicidad digitálica facilitadas por hipopotasemia',
    'Monitorar K+ sérico; reponer potasio se <4 mEq/L; dosar digoxina se suspeita de toxicidad',
    'Requiere monitorización de K+ sérico e nivel de digoxina',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  ('digoxina', 'espironolactona', InteractionSeverity.moderate,
    'Espironolactona puede elevar nivel sérico de digoxina (inhibición de la secreción tubular)',
    'Toxicidad digitálica aumentada',
    'Monitorar nivel sérico de digoxina después de introdução de espironolactona',
    'Requiere monitorización de nivel sérico de digoxina',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefMdx, _kRefLex]),

    // ── Antibióticos ──────────────────────────────────────────────────────────

  ('metronidazol', 'alcool', InteractionSeverity.contraindicated,
    'Inhibición de la aldehído deshidrogenasa — reacción tipo disulfiram',
    'Flushing, náuseas, vómitos, cefalea, taquicardia, hipotensión',
    'Contraindicado alcohol durante el uso y por 48h después del fin del metronidazol',
    'NO UTILIZAR — Prohibido alcohol durante y 48h después del metronidazol',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA]),

  ('quinolona', 'antiácido', InteractionSeverity.moderate,
    'Cationes divalentes (Al, Mg, Ca) quelan quinolonas en el TGI',
    'Reducción del 50–90% en la absorción oral de la quinolona',
    'Administrar quinolona 2h antes o 6h después del antiácido/suplemento de calcio/hierro',
    'Requiere intervalo de 2–6h entre administraciones',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  ('ciprofloxacino', 'teofilina', InteractionSeverity.major,
    'Inhibición del CYP1A2 reduce metabolismo de teofilina',
    'Toxicidad por teofilina — náuseas, convulsiones, arritmias',
    'Reducir dosis de teofilina 30–50%. Monitorar nivel sérico de teofilina',
    'ALTO RIESGO DE TOXICIDAD — Monitorar nivel sérico de teofilina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('claritromicina', 'estatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 eleva concentración plasmática de estatinas metabolizadas por esse CYP',
    'Riesgo de miopatía/rabdomiólisis',
    'Suspender estatina durante el curso de claritromicina. Alternativa: azitromicina',
    'RIESGO DE RABDOMIÓLISIS — Suspender estatina durante claritromicina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('rifampicina', 'warfarina', InteractionSeverity.major,
    'Inducción potente del CYP2C9 — aumenta metabolismo de warfarina',
    'Reducción marcada del efecto anticoagulante (INR puede caer >50%)',
    'Monitorar INR diariamente al inicio y al final. Aumentar dosis de warfarina significativamente',
    'ALTO RIESGO DE FALLO ANTICOAGULANTE — Monitorar INR diariamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel, RiskType.thrombosis},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── Psicotrópicos / SNC ───────────────────────────────────────────────────

  ('tramadol', 'isrs', InteractionSeverity.major,
    'Inhibición de la recaptación serotoninérgica sumada',
    'Síndrome serotoninérgica — agitación, hipertermia, mioclonía, taquicardia',
    'Evitar combinación. Si indispensable, iniciar con dosis baja de tramadol y monitorar por 24–48h',
    'ALTO RIESGO DE SÍNDROME SEROTONINÉRGICA — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('tramadol', 'imao', InteractionSeverity.contraindicated,
    'Potenciación serotoninérgica extrema',
    'Síndrome serotoninérgica grave con riesgo de muerte',
    'Contraindicado — esperar 14 días después de suspender IMAO antes de usar tramadol',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Riesgo de muerte',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('tramadol', 'morfina', InteractionSeverity.moderate,
    'Efectos aditivos en el SNC y depresión respiratoria',
    'Sedación excesiva, depresión respiratoria',
    'Usar com cautela. Monitorar nivel de consciencia y función respiratoria',
    'Requiere monitorización clínica — depresión respiratoria aditiva',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefMdx]),

  ('benzodiazepínico', 'opioide', InteractionSeverity.contraindicated,
    'Depresión aditiva del SNC — sinergia respiratoria y sedativa',
    'Depresión respiratoria grave, coma, muerte (alerta FDA/ANVISA)',
    'Evitar combinación. Se essencial (ICU/paliativo), monitorar com oximetria contínua; ter naloxona disponible',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  ('haloperidol', 'carbonato de litio', InteractionSeverity.moderate,
    'Posible potenciación neurotóxica; el litio puede alterar la farmacocinética del haloperidol',
    'Neurotoxicidad aumentada — confusión, temblor, extrapiramidal exacerbado',
    'Monitorar litio sérico, ECG y signos neurológicos',
    'Requiere monitorización clínica/laboratorial — neurotoxicidad',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefMdx, _kRefUT]),

  ('isrs', 'imao', InteractionSeverity.contraindicated,
    'Hiperestimulación serotoninérgica extrema',
    'Síndrome serotoninérgica grave — hiperpirexia, convulsiones, colapso cardiovascular, muerte',
    'Contraindicado. Esperar 14 días después de suspender IMAO (o 5 semanas para fluoxetina) antes de iniciar SSRI',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Síndrome serotoninérgica fatal',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefMdx]),

    // ── Hipoglucemiantes ──────────────────────────────────────────────────────

  ('metformina', 'contraste iodado', InteractionSeverity.major,
    'El contraste yodado puede causar IRA transitoria → acumulación de metformina → acidosis láctica',
    'Acidosis láctica (rara pero grave)',
    'Suspender metformina 48h antes del contraste en pacientes con ERC (TFG <60). Reintroducir tras 48h si la función renal es estable',
    'ALTO RIESGO — Suspender metformina 48h antes del contraste',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('glibenclamida', 'fluconazol', InteractionSeverity.major,
    'Inhibición del CYP2C9 aumenta nivel sérico de glibenclamida',
    'Hipoglucemia grave y prolongada',
    'Evitar. Se necesario, monitorar glucemia intensivamente e reducir dosis de glibenclamida',
    'ALTO RIESGO DE HIPOGLUCEMIA GRAVE — Monitorar glucemia intensivamente',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('insulina', 'betabloqueador', InteractionSeverity.moderate,
    'Los betabloqueadores enmascaran taquicardia y temblor (síntomas adrenérgicos de hipoglucemia)',
    'La hipoglucemia puede pasar desapercibida — solo la sudoración persiste como signo',
    'Preferir betabloqueadores cardiosseletivos. Orientar al paciente. Monitorar glucemia más frecuentemente',
    'Requiere monitorización — signos de hipoglucemia enmascarados',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefKatz]),

    // ── Inmunosupresores ─────────────────────────────────────────────────────

  ('ciclosporina', 'fluconazol', InteractionSeverity.major,
    'Inhibición del CYP3A4 eleva nivel sérico de ciclosporina',
    'Nefrotoxicidad e inmunosupresión excesiva',
    'Reducir dosis de ciclosporina 50% y monitorar nivel sérico diariamente',
    'ALTO RIESGO DE NEFROTOXICIDAD — Monitorar nivel sérico diariamente',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefLex]),

  ('ciclosporina', 'claritromicina', InteractionSeverity.major,
    'Inhibición del CYP3A4 e P-gp',
    'Aumento del nivel sérico de ciclosporina — nefrotoxicidad',
    'Reducir dosis de ciclosporina; monitorar nivel sérico frecuentemente',
    'ALTO RIESGO DE NEFROTOXICIDAD — Monitorar nivel sérico diariamente',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Cardiovascular / Miscellaneous ────────────────────────────────────────

  ('atorvastatina', 'gemfibrozil', InteractionSeverity.major,
    'Inhibición de la glucuronidación de atorvastatina por gemfibrozil',
    'Riesgo significativo de miopatía/rabdomiólisis',
    'Evitar combinación. Si necesario usar fibratos, preferir fenofibrato + estatina',
    'ALTO RIESGO DE RABDOMIÓLISIS — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('sildenafila', 'nitrato', InteractionSeverity.contraindicated,
    'Ambos potencializan vasodilatación vía GMPc',
    'Hipotensión grave, shock cardiovascular, colapso hemodinámico, muerte',
    'Contraindicado absolutamente. Esperar ≥24h después de sildenafil (≥48h para tadalafil) para administrar nitrato',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Hipotensión fatal',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('sildenafila', 'alfa-bloqueador', InteractionSeverity.major,
    'Efecto hipotensor aditivo',
    'Hipotensión sintomática grave — mareo, síncope',
    'Iniciar alfa-bloqueador con dosis baja. Esperar estabilización antes de asociar. Orientar al paciente',
    'ALTO RIESGO DE HIPOTENSIÓN GRAVE — Iniciar com dosis bajas',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA]),

  ('furosemida', 'aminoglicosideo', InteractionSeverity.major,
    'Ototoxicidad aditiva sinérgica',
    'Sordera neurosensorial permanente — riesgo aumentado especialmente en ERC',
    'Evitar combinación. Se necesario, minimizar dosis e duración; monitorar función auditiva',
    'ALTO RIESGO DE SORDERA IRREVERSIBLE — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('furosemida', 'aine', InteractionSeverity.moderate,
    'AINEs inhiben síntesis de prostaglandinas renales vasodilatadoras',
    'Reducción del efecto diurético; riesgo de IRA',
    'Evitar AINEs en pacientes que usan furosemida, especialmente en ICC/ERC',
    'Requiere monitorización clínica/laboratorial — riesgo renal',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

    // DUPLICATA REMOVIDA: fluconazol+quetiapina — par detalhado mantido na seção de fluconazol (linha ~1670)

  ('haloperidol', 'ondansetrona', InteractionSeverity.major,
    'Prolongación aditiva del QT por mecanismos distintos',
    'Torsades de Pointes',
    'Evitar. Monitorar QTc. Si QTc >500ms, suspender uno de los medicamentos',
    'ALTO RIESGO DE TORSADES DE POINTES — Monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefFDA]),

    // ── Heparina / Anticoagulantes ─────────────────────────────────────────────

  ('heparina', 'aspirina', InteractionSeverity.moderate,
    'Efecto antitrombótico/hemostático aditivo',
    'Riesgo aumentado de sangrado (especialmente GI)',
    'Monitorar signos de sangrado. Combinación aceptada en SCA (protocolo AHA/ACC), con precaución',
    'Requiere monitorización clínica — riesgo hemorrágico aditivo',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT]),

  ('heparina', 'aine', InteractionSeverity.moderate,
    'AINEs inhiben función plaquetaria + riesgo de sangrado GI',
    'Riesgo aumentado de hemorragia',
    'Evitar AINEs durante anticoagulación. Preferir paracetamol para analgesia',
    'Requiere monitorización — evitar AINEs con heparina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── Amiodarona — QT e interacciones adicionais ───────────────────────────────

  ('amiodarona', 'azitromicina', InteractionSeverity.major,
    'Prolongación aditiva del intervalo QT por mecanismos distintos',
    'Torsades de Pointes, fibrilación ventricular',
    'Evitar combinación. Se antibiótico essencial, preferir amoxicilina ou doxiciclina. Monitorar QTc',
    'ALTO RIESGO DE TORSADES DE POINTES — Preferir amoxicilina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('amiodarona', 'metoprolol', InteractionSeverity.major,
    'Efecto cronotrópico e dromotrópico negativo aditivo sobre o nó sinusal e AV',
    'Bradicardia grave, bloqueo AV, colapso hemodinámico',
    'Monitorar FC e ECG continuamente. Reducir dosis do betabloqueador. Ter atropina disponible',
    'ALTO RIESGO CARDIOVASCULAR — Monitorar ECG y FC continuamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // ── Warfarina — entradas complementares ───────────────────────────────────

  ('warfarina', 'aine', InteractionSeverity.major,
    'AINEs inibem função plaquetária e causam ulceração GI; deslocamento proteico eleva INR',
    'Riesgo muy alto de sangrado gastrointestinal y úlcera péptica',
    'Evitar combinación. Preferir paracetamol. Si inevitable, usar IBP e monitorar INR frecuentemente',
    'ALTO RIESGO DE SANGRADO GI — Use paracetamol + IBP',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── Clopidogrel ───────────────────────────────────────────────────────────

  ('clopidogrel', 'omeprazol', InteractionSeverity.moderate,
    'Inhibición del CYP2C19 pelo omeprazol reduz conversão do clopidogrel ao metabólito ativo',
    'Reducción del efecto antiagregante — mayor riesgo de eventos isquémicos y trombosis de stent',
    'Preferir pantoprazol (menor inhibición CYP2C19) si IBP necesario. Monitorar eventos cardiovasculares',
    'Requiere sustitución de IBP — preferir pantoprazol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('clopidogrel', 'esomeprazol', InteractionSeverity.moderate,
    'Inhibición del CYP2C19 pelo esomeprazol reduz ativação do clopidogrel',
    'Eficacia antiagregante reducida — riesgo de trombosis de stent',
    'Sustituir por pantoprazol. Reevaluar necesidad del IBP después del período de riesgo',
    'Requiere sustitución de IBP — preferir pantoprazol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefMdx, _kRefFDA]),

    // ── IECA — entradas complementares ────────────────────────────────────────

  ('enalapril', 'sacubitrila', InteractionSeverity.contraindicated,
    'Inhibición simultânea do sistema neprilisina-angiotensina causa acumulación de bradicinina',
    'Angioedema grave y potencialmente fatal — riesgo 3× mayor que IECA solo',
    'Contraindicado. Respetar ventana de período de lavado de 36 horas entre suspender IECA e iniciar sacubitril',
    'NO UTILIZAR — Angioedema fatal; período de lavado 36h obligatorio',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefUT]),

    // ── Lítio ─────────────────────────────────────────────────────────────────

  ('carbonato de litio', 'ibuprofeno', InteractionSeverity.major,
    'AINEs reduzem excreción renal de lítio por inhibición das prostaglandinas renais',
    'Toxicidad lítica rápida — temblor, confusión, convulsiones, arritmias',
    'Evitar AINEs en pacientes con litio. Usar paracetamol. Monitorar litemia si inevitable',
    'ALTO RIESGO DE TOXICIDAD POR LITIO — Use paracetamol',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('carbonato de litio', 'hidroclorotiazida', InteractionSeverity.major,
    'Tiazídicos aumentam reabsorción proximal de sódio e lítio em compensação à perda distal',
    'Toxicidad por litio — confusión, temblor, nefrotoxicidad',
    'Monitorar litemia cada 3–5 días al inicio. Reducir dosis de litio 30–50%',
    'ALTO RIESGO DE TOXICIDAD POR LITIO — Monitorar litemia',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('carbonato de litio', 'enalapril', InteractionSeverity.major,
    'IECAs reduzem aclaramiento renal de lítio por inhibición da angiotensina II',
    'Elevación de los niveles séricos de litio — toxicidad',
    'Monitorar litemia semanalmente las primeras 4 semanas. Reducir dosis de litio según sea necesario',
    'ALTO RIESGO DE TOXICIDAD POR LITIO — Monitorar litemia semanalmente',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── Serotonina — entradas complementares ──────────────────────────────────

  ('isrs', 'linezolida', InteractionSeverity.contraindicated,
    'Linezolida inibe a MAO — hiperestimulação serotoninérgica com SSRI',
    'Síndrome serotoninérgica grave — hipertermia, rigidez, crisis convulsiva, colapso',
    'Contraindicado. Esperar período de lavado adecuado (≥5 semanas para fluoxetina, ≥2 semanas para otros SSRIs)',
    'NO UTILIZAR ESTOS FÁRMACOS JUNTOS — Síndrome serotoninérgica fatal',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('tramadol', 'amitriptilina', InteractionSeverity.major,
    'Reducción del limiar convulsivo + inhibición de la recaptação de serotonina/noradrenalina aditiva',
    'Riesgo aumentado de convulsiones y síndrome serotoninérgica',
    'Evitar combinación. Si necesario, iniciar tramadol en dosis mínima con monitorización neurológica',
    'ALTO RIESGO DE SÍNDROME SEROTONINÉRGICA Y CONVULSIONES',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.cns},
    [_kRefMdx, _kRefUT]),

    // ── Aminoglicosídeos ───────────────────────────────────────────────────────

  ('aminoglicosideo', 'vancomicina', InteractionSeverity.major,
    'Nefrotoxicidad e ototoxicidad sinérgica — ambos lesam túbulos renais proximais e células ciliadas',
    'Insuficiencia renal aguda, sordera irreversible',
    'Evitar combinación si es posible. Si es necesaria, monitorar creatinina diariamente e função auditiva',
    'ALTO RIESGO DE NEFROTOXICIDAD Y SORDERA IRREVERSIBLE',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── Quinolonas — quelação por cátions ─────────────────────────────────────

  ('ciprofloxacino', 'carbonato de calcio', InteractionSeverity.moderate,
    'Cálcio forma complexo insoluble com ciprofloxacino no intestino (quelação)',
    'Reducción de hasta el 50% en la absorción oral de la quinolona',
    'Administrar ciprofloxacino 2h antes o 6h después del calcio/antiácidos/hierro',
    'Requiere intervalo de 2–6h entre administraciones',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  ('ciprofloxacino', 'sulfato ferroso', InteractionSeverity.moderate,
    'Ferro quelata ciprofloxacino no TGI reduzindo drásticamente sua biodisponibilidad',
    'Fracaso terapéutico del antibiótico',
    'Administrar ciprofloxacino 2h antes o 6h después del suplemento de hierro',
    'Requiere intervalo de 2–6h entre administraciones — riesgo de fracaso terapéutica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

    // ── Levotiroxina ──────────────────────────────────────────────────────────

  ('levotiroxina', 'carbonato de calcio', InteractionSeverity.moderate,
    'Cálcio liga-se à levotiroxina no intestino reduzindo sua absorción',
    'Hipotiroidismo por absorción inadecuada — TSH elevado',
    'Intervalo mínimo de 4 horas entre levotiroxina y calcio. Tomar levotiroxina en ayunas',
    'Requiere intervalo de 4h — separar administraciones',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  ('levotiroxina', 'pantoprazol', InteractionSeverity.moderate,
    'Reducción de la acidez gástrica pelos IBPs prejudica dissolução e absorción da levotiroxina',
    'Absorción reducida — hipotiroidismo subclínico',
    'Monitorar TSH a cada 6–8 semanas. Pode ser necesario aumentar dosis de levotiroxina',
    'Requiere monitorización de TSH cada 6–8 semanas',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('levotiroxina', 'antiácido', InteractionSeverity.moderate,
    'Cátions (Al, Mg, Ca) dos antiácidos quelam levotiroxina no TGI',
    'Reducción de la absorción — hipotiroidismo',
    'Administrar levotiroxina 2h antes de antiácidos, IBPs, calcio o hierro',
    'Requiere intervalo de 2h entre administraciones',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

    // ── Benzodiazepínicos — complementar ──────────────────────────────────────

  ('benzodiazepínico', 'alcool', InteractionSeverity.major,
    'Potenciação mútua da depresión del SNC por mecanismos GABA-A aditivos',
    'Sedación severa, depresión respiratoria, coma, muerte',
    'Contraindicado. Orientar al paciente explícitamente sobre la prohibición de alcohol',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — Prohibido alcohol',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefFDA]),

    // ── Anticonvulsivantes ─────────────────────────────────────────────────────

  ('carbamazepina', 'anticonceptivo', InteractionSeverity.major,
    'Inducción enzimática do CYP3A4 acelera metabolismo de estrógenos e progestágenos',
    'Fracaso del anticonceptivo hormonal — embarazo no planificado',
    'Usar método anticonceptivo no hormonal (DIU de cobre, preservativo). Orientar explícitamente a la paciente',
    'ALTO RIESGO DE FALLO CONTRACEPTIVO — Usar método no hormonal',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('valproato', 'lamotrigina', InteractionSeverity.major,
    'Ácido valproico inibe a glucuronidação da lamotrigina, dobrando sua vida media',
    'Toxicidad por lamotrigina — erupción grave, Síndrome de Stevens-Johnson',
    'Reducir dosis de lamotrigina 50% al introducir valproato. Monitorar erupción cutánea',
    'ALTO RIESGO DE SÍNDROME DE STEVENS-JOHNSON — Reducir lamotrigina 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('midazolam', 'claritromicina', InteractionSeverity.major,
    'Inhibición potente del CYP3A4 pela claritromicina prolonga vida media do midazolam',
    'Sedación prolongada y excesiva, depresión respiratoria',
    'Reducir dosis de midazolam 50–75%. Monitorar nivel de consciencia y SpO₂',
    'ALTO RIESGO DE SEDACIÓN PROLONGADA — Reducir dosis de midazolam',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

    // ── Claritromicina + Benzodiazepínicos (CYP3A4) ──────────────────────────

  ('claritromicina', 'benzodiazepínico', InteractionSeverity.major,
    'Claritromicina inibe potentemente o CYP3A4 — principal vía de metabolismo de alprazolam, diazepam, clonazepam e triazolam. Lorazepam é menos afetado (metabolismo por glucuronidação)',
    'Aumento de 2-5x en los niveles plasmáticos de las benzodiazepinas → sedación excesiva y prolongada, compromiso psicomotor, depresión respiratoria, amnesia anterógrada',
    'Preferir azitromicina cuando sea posible (não inibe CYP3A4). Se claritromicina necesaria: reducir dosis do benzodiazepínico em 50%, evitar alprazolam e triazolam, preferir lorazepam. Monitorar nivel de consciencia y SpO₂',
    'SEDACIÓN AUMENTADA — Claritromicina inhibe CYP3A4; reducir BZD 50% o preferir lorazepam',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── Corticosteroides ──────────────────────────────────────────────────────

  ('dexametasona', 'aine', InteractionSeverity.major,
    'Corticosteroide + AINE: inhibición dupla das prostaglandinas protetoras da mucosa gástrica',
    'Riesgo muy elevado de úlcera péptica y hemorragia GI',
    'Contraindicado sem protección gástrica. Prescrever IBP obligatoriamente se combinación necesaria',
    'ALTO RIESGO DE HEMORRAGIA GI — Prescribir IBP obligatoriamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── Hiperpotasemia ────────────────────────────────────────────────────────

  ('espironolactona', 'cloreto de potassio', InteractionSeverity.contraindicated,
    'Espironolactona retém potássio + suplementação adicional = hiperpotasemia aditiva extrema',
    'Hiperpotasemia fatal — paro cardíaco en asistolia',
    'Contraindicado. No suplementar potasio rutinariamente con espironolactona. Monitorar K+ sérico',
    'NO UTILIZAR — Hiperpotasemia fatal; paro cardíaco',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA]),

    // ── Colchicina / Inmunosupresores ────────────────────────────────────────

  ('colchicina', 'claritromicina', InteractionSeverity.contraindicated,
    'Inhibición de la P-gp e CYP3A4 eleva drásticamente os niveles de colchicina',
    'Toxicidad por colchicina — miopatía, neuropatía, pancitopenia, falla de múltiples órganos',
    'Contraindicado en insuficiencia renal o hepática. Reducir dosis de colchicina y monitorar rigurosamente',
    'NO UTILIZAR — Toxicidad por colchicina con riesgo de falla orgánica',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('alopurinol', 'azatioprina', InteractionSeverity.contraindicated,
    'Alopurinol inibe xantina oxidase — enzima que metaboliza azatioprina — causando acumulación tóxico',
    'Mielosupresión grave: leucopenia, trombocitopenia, anemia aplásica',
    'Contraindicado. Si la combinación es inevitable, reducir azatioprina a 25% de la dosis y monitorar hemograma semanalmente',
    'NO UTILIZAR — Mielosupresión grave; riesgo de aplasia medular',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

    // ── Interacciones farmacodinâmicas adicionais ────────────────────────────────

  ('ondansetrona', 'tramadol', InteractionSeverity.moderate,
    'Ondansetrona bloqueia receptores 5-HT₃ utilizados pelo tramadol para analgesia',
    'Reducción significativa del efecto analgésico del tramadol',
    'Evaluar eficacia analgésica. Si necesario, sustituir por otro antiemético o usar analgésico alternativo',
    'Requiere monitorización — analgesia del tramadol puede reducirse',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('insulina', 'dapagliflozina', InteractionSeverity.moderate,
    'Efecto hipoglucemiante aditivo — iSGLT2 potencializa o efecto da insulina',
    'Hipoglucemia grave, especialmente con insulina basal o bolos elevados',
    'Reducir dosis de insulina em 10–20% al iniciar iSGLT2. Monitorar glucemia frecuentemente',
    'Requiere monitorización de glucemia — reducir insulina al iniciar iSGLT2',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefFDA, _kRefUT]),

  ('amitriptilina', 'atropina', InteractionSeverity.moderate,
    'Efectos anticolinérgicos aditivos — bloqueio muscarínico somado',
    'Boca seca intensa, retención urinaria, visión borrosa, confusión, delirio (especialmente en ancianos)',
    'Evitar en ancianos. Si necesario, usar la menor dosis posible y monitorar síntomas anticolinérgicos',
    'Requiere monitorización clínica — toxicidad anticolinérgica aditiva',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefKatz]),

    // ══════════════════════════════════════════════════════════════════════════
    // INTERAÇÕES — MERGE v2 (modelo expandido)
    // ══════════════════════════════════════════════════════════════════════════

    // ── Dronedarona ───────────────────────────────────────────────────────────

  ('dronedarona', 'dabigatrana', InteractionSeverity.major,
    'Dronedarona inibe P-glicoproteína → aumenta absorción e nivel sérico de dabigatrana',
    'Riesgo hemorrágico elevado — aumento de hasta 100% en la exposición a dabigatrán',
    'Reducir dosis de dabigatrana para 75 mg 2x/dia com dronedarona. Monitorar signos de sangrado',
    'ALTO RIESGO DE SANGRADO — Reducir dosis de dabigatrana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('dronedarona', 'sinvastatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 e P-gp pela dronedarona aumenta nivel de sinvastatina',
    'Riesgo de miopatía/rabdomiólisis',
    'Dosis máxima de sinvastatina: 20 mg/dia. Preferir rosuvastatina ou pravastatina',
    'RIESGO DE RABDOMIÓLISIS — Limitar simvastatina a 20 mg/día',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),

  ('dronedarona', 'metoprolol', InteractionSeverity.major,
    'Inhibición del CYP2D6 por dronedarona aumenta nivel de metoprolol + efecto cronotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV, hipotensión',
    'Monitorar FC e ECG. Reducir dosis de metoprolol. Objetivo: FC ≥50 lpm en reposo',
    'ALTO RIESGO CARDIOVASCULAR — Monitorar FC y ECG',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  ('dronedarona', 'digoxina', InteractionSeverity.major,
    'Inhibición de la P-gp aumenta nivel sérico de digoxina',
    'Toxicidad digitálica — náuseas, bradicardia, trastornos de conducción',
    'Reducir dosis de digoxina 50%. Monitorar nivel sérico y ECG regularmente',
    'ALTO RIESGO DE TOXICIDAD DIGITÁLICA — Reducir digoxina 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefMdx, _kRefFDA]),

  ('dronedarona', 'warfarina', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 e posible efecto no CYP2C9 pela dronedarona',
    'Elevación moderada do INR',
    'Monitorar INR semanalmente nas primeiras 2–4 semanas después de introdução. Ajustar dosis de warfarina según sea necesario',
    'Requiere monitorización de INR las primeras 2–4 semanas',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('dronedarona', 'ciclosporina', InteractionSeverity.contraindicated,
    'Inhibición mutua del CYP3A4 y P-gp — exposición de ambos aumenta drásticamente',
    'Toxicidad por ciclosporina (nefrotóxica) e toxicidad cardíaca por dronedarona',
    'Combinación contraindicada. Sustituir por antiarrítmico alternativo',
    'NO UTILIZAR — Toxicidad grave bilateral',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Ivabradina ────────────────────────────────────────────────────────────

  ('ivabradina', 'diltiazem', InteractionSeverity.contraindicated,
    'Diltiazem inhibe CYP3A4 (aumenta nivel de ivabradina) + efecto cronotrópico negativo aditivo en nodo sinusal',
    'Bradicardia grave, bloqueo sinusal, asistolia',
    'Combinación contraindicada. Usar apenas um agente para controle de FC',
    'NO UTILIZAR — Bradicardia grave y asistolia',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  ('ivabradina', 'verapamil', InteractionSeverity.contraindicated,
    'Verapamil inhibe CYP3A4 + efecto bradicardizante sinérgico',
    'Bradicardia grave, síncope, parada sinusal',
    'Contraindicado — no combinar ivabradina com bloqueadores de cálcio não-diidropiridínicos',
    'NO UTILIZAR — Bradicardia grave y paro sinusal',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  ('ivabradina', 'claritromicina', InteractionSeverity.major,
    'Inhibición potente del CYP3A4 pela claritromicina aumenta exposición à ivabradina em ~7×',
    'Bradicardia grave, prolongamento QT, Torsades de Pointes',
    'Contraindicado. Suspender ivabradina durante el curso de claritromicina. Alternativa: azitromicina',
    'ALTO RIESGO CARDIOVASCULAR — Suspender ivabradina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ivabradina', 'fluconazol', InteractionSeverity.major,
    'Inhibición del CYP3A4 pelo fluconazol aumenta significativamente o nivel de ivabradina',
    'Bradicardia excessiva, tontura, fosfenos',
    'Monitorar FC. Reducir dosis de ivabradina si FC <50 lpm. Considerar antifúngico alternativo',
    'ALTO RIESGO DE BRADICARDIA — Monitorar FC',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Ranolazina ────────────────────────────────────────────────────────────

  ('ranolazina', 'claritromicina', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 aumenta ranolazina em >5× + ambos prolongam QTc',
    'Prolongación QTc grave, Torsades de Pointes, arritmia ventricular fatal',
    'Contraindicado. Sustituir por azitromicina ou doxiciclina',
    'NO UTILIZAR — Arritmia ventricular fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ranolazina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inhibe CYP3A4 + ambos prolongan QTc por mecanismos distintos',
    'Prolongación QTc excessivo, Torsades de Pointes',
    'Evitar combinación. Si necesaria, monitorar QTc (ECG seriado). Suspender si QTc >500 ms',
    'ALTO RIESGO DE TORSADES DE POINTES — Monitorar QTc seriado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('ranolazina', 'digoxina', InteractionSeverity.moderate,
    'Ranolazina inhibe P-gp → aumento del nivel sérico de digoxina en ~50%',
    'Toxicidad digitálica — bradiarritmias, náuseas, distúrbios visuais',
    'Reducir dosis de digoxina 50% al iniciar ranolazina. Monitorar nivel sérico',
    'Requiere monitorización — toxicidad digitálica por aumento de nivel',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefMdx, _kRefFDA]),

  ('ranolazina', 'sinvastatina', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 pela ranolazina aumenta exposición à sinvastatina',
    'Riesgo aumentado de miopatía',
    'Limitar sinvastatina a 20 mg/dia com ranolazina. Monitorar CPK y síntomas musculares',
    'Requiere monitorización — limitar simvastatina a 20 mg/día',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),

    // ── Eplerenona ────────────────────────────────────────────────────────────

  ('eplerenona', 'cloreto de potassio', InteractionSeverity.contraindicated,
    'Eplerenona retiene K⁺ (ahorrador de potasio) + suplementación adicional',
    'Hiperpotasemia fatal — paro cardíaco',
    'Contraindicado. No suplementar potasio rutinariamente con eplerenona. Monitorar K⁺ sérico rigurosamente',
    'NO UTILIZAR — Hiperpotasemia fatal; paro cardíaco',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  ('eplerenona', 'enalapril', InteractionSeverity.moderate,
    'Ambos elevan K⁺ por mecanismos distintos — antagonismo aldosterona + inhibición de la angiotensina II',
    'Hiperpotasemia, especialmente en ERC o diabetes',
    'Monitorar K⁺ e creatinina semanalmente no inicio. Reducir/suspender eplerenona si K⁺ >5,5 mEq/L',
    'Requiere monitorización de K+ sérico semanal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),

  ('eplerenona', 'claritromicina', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 pela claritromicina aumenta exposición à eplerenona em >5×',
    'Hiperpotasemia grave e excessiva retenção de potássio',
    'Contraindicado. Sustituir por azitromicina. Esperar 14 días después de claritromicina antes de reiniciar eplerenona',
    'NO UTILIZAR — Hiperpotasemia grave; sustituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Daptomicina ───────────────────────────────────────────────────────────

  ('daptomicina', 'estatina', InteractionSeverity.major,
    'Mecanismo sinérgico de miotoxicidad — ambos lesionan membranas musculares por mecanismos complementarios',
    'Miopatía grave e rabdomiólisis',
    'Suspender estatinas durante uso de daptomicina. Monitorar CPK semanalmente. Reiniciar estatina tras fin del antibiótico',
    'ALTO RIESGO DE RABDOMIÓLISIS — Suspender estatina durante daptomicina',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefMdx, _kRefFDA]),

  ('daptomicina', 'aminoglicosideo', InteractionSeverity.moderate,
    'Posible nefrotoxicidad aditiva — ambos pueden elevar creatinina con uso prolongado',
    'Insuficiencia renal aguda, especialmente en pacientes vulneráveis',
    'Monitorar creatinina y electrolitos diariamente. Minimizar duración y dosis de aminoglucósido',
    'Requiere monitorización renal diaria',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),

    // ── Nirmatrelvir/Ritonavir (Paxlovid) ────────────────────────────────────

  ('ritonavir', 'sinvastatina', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 pelo ritonavir aumenta sinvastatina >10× — rabdomiólisis',
    'Rabdomiólisis grave, insuficiencia renal, coagulación intravascular diseminada',
    'Contraindicado absolutamente. Suspender simvastatina durante uso de Paxlovid',
    'NO UTILIZAR — Rabdomiólisis con CID; riesgo de muerte',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'midazolam', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 pelo ritonavir → nivel de midazolam aumenta dezenas de vezes',
    'Sedación prolongada y grave, depresión respiratoria, coma',
    'Contraindicado. No usar midazolam oral/parenteral con ritonavir',
    'NO UTILIZAR — Sedación grave y coma',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'amiodarona', InteractionSeverity.contraindicated,
    'Inhibición del CYP3A4 e CYP2C8 pelo ritonavir aumenta amiodarona dramaticamente + QT aditivo',
    'Toxicidad por amiodarona (pulmonar, hepática, tireoidiana) e Torsades de Pointes',
    'Contraindicado. Sustituir ritonavir si el paciente usa amiodarona. Paxlovid contraindicado en estas situaciones',
    'NO UTILIZAR — Toxicidad grave por amiodarona y arritmia',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'warfarina', InteractionSeverity.major,
    'Ritonavir es inductor e inhibidor del CYP2C9 (efecto bifásico) — INR puede aumentar o disminuir',
    'Inestabilidad del INR — riesgo de sangrado o trombosis dependiendo de la fase',
    'Monitorar INR cada 1–2 días durante uso de Paxlovid y por 2 semanas después. Ajustar dosis de warfarina',
    'ALTO RIESGO — Monitorar INR diariamente durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'atorvastatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 pelo ritonavir aumenta atorvastatina em ~8×',
    'Riesgo significativo de miopatía/rabdomiólisis',
    'Suspender atorvastatina durante uso de Paxlovid (5 días). Reiniciar al terminar. Alternativa: pravastatina o rosuvastatina en dosis baja',
    'RIESGO DE RABDOMIÓLISIS — Suspender atorvastatina durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ritonavir', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina es inductor potente del CYP3A4 → reduce drásticamente niveles de nirmatrelvir/ritonavir',
    'Fracaso terapéutico de Paxlovid — concentraciones subterapéuticas de nirmatrelvir',
    'Paxlovid contraindicado con carbamazepina. Considerar molnupiravir como alternativa',
    'ALTO RIESGO DE FRACASO TERAPÉUTICO — Paxlovid ineficaz con carbamazepina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  ('ritonavir', 'ranolazina', InteractionSeverity.contraindicated,
    'Inhibición del CYP3A4 pelo ritonavir eleva ranolazina drásticamente + prolongación QTc aditivo',
    'Arritmia ventricular grave, Torsades de Pointes',
    'Contraindicado. Suspender ranolazina durante uso de Paxlovid',
    'NO UTILIZAR — Arritmia ventricular fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

    // ── Semaglutida / Tirzepatida (arGLP-1) ──────────────────────────────────

  ('semaglutida', 'insulina', InteractionSeverity.moderate,
    'Efecto hipoglucemiante aditivo — arGLP-1 potencia acción de la insulina',
    'Hipoglucemia grave, especialmente con insulina basal o prandial en dosis altas',
    'Reducir dosis de insulina em 20–40% al iniciar arGLP-1. Monitorar glucemia. Titular gradualmente',
    'Requiere monitorización — reducir insulina al iniciar arGLP-1',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefFDA, _kRefUT]),

  ('semaglutida', 'sulfonilureia', InteractionSeverity.moderate,
    'Efecto insulinotrópico aditivo con riesgo aumentado de hipoglucemia',
    'Hipoglucemia grave, mareo, sudoración, convulsiones',
    'Reducir dosis da sulfonilureia em 50% al iniciar semaglutida. Monitorar glucemia capilar diariamente',
    'Requiere monitorización — reducir sulfonilurea al iniciar semaglutida',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefFDA, _kRefUT]),

  ('semaglutida', 'levotiroxina', InteractionSeverity.monitorOnly,
    'El retardo del vaciamiento gástrico por semaglutida puede reducir absorción de levotiroxina',
    'Reducción de la absorción de levotiroxina → hipotiroidismo subclínico',
    'Tomar levotiroxina en ayunas, ≥30 min antes de semaglutida si oral (Rybelsus). Monitorar TSH cada 6–8 semanas',
    'Solo monitorizar — monitorar TSH cada 6–8 semanas',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

    // ── Canagliflozina / iSGLT2 ──────────────────────────────────────────────

  ('canagliflozina', 'furosemida', InteractionSeverity.moderate,
    'Efecto natriurético y diurético aditivo — ambos causan depleción de volumen',
    'Hipotensión grave, IRA prerrenal, deshidratación, hipopotasemia',
    'Monitorar PA, función renal y electrolitos. Reducir dosis de furosemida si necesario. Hidratación adecuada',
    'Requiere monitorización clínica/laboratorial — depleción de volumen',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.nephrotoxicity, RiskType.hypokalemia},
    [_kRefGG, _kRefFDA]),

  ('canagliflozina', 'enalapril', InteractionSeverity.moderate,
    'Efecto natriurético de los iSGLT2 asociado a vasodilatación de los IECAs — hipotensión e hiperpotasemia',
    'Hipotensión sintomática, IRA prerrenal, hiperpotasemia',
    'Monitorar PA, K⁺ e función renal nas primeiras 2–4 semanas. Hidratação adecuada',
    'Requiere monitorización de PA y función renal',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia},
    [_kRefGG, _kRefUT]),

  ('canagliflozina', 'rifampicina', InteractionSeverity.moderate,
    'Rifampicina induce UGT y CYP → reducción del 51% en la exposición a canagliflozina',
    'Reducción del efecto hipoglucemiante y nefroprotector',
    'Monitorar controle glicêmico. Pode ser necesario aumentar dosis de canagliflozina ou sustituir por outra classe',
    'Requiere monitorización glucémica — eficacia reducida',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Finerenona ────────────────────────────────────────────────────────────

  ('finerenona', 'claritromicina', InteractionSeverity.contraindicated,
    'Inhibición potente del CYP3A4 pela claritromicina aumenta finerenona em >5×',
    'Hiperpotasemia grave y potencialmente fatal',
    'Contraindicado. Suspender finerenona durante uso de claritromicina. Alternativa: azitromicina',
    'NO UTILIZAR — Hiperpotasemia grave; sustituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('finerenona', 'espironolactona', InteractionSeverity.contraindicated,
    'Antagonismo mineralocorticoide aditivo — doble bloqueo del receptor de aldosterona',
    'Hiperpotasemia grave, paro cardíaco',
    'Contraindicado — no combinar dois ARM. Escolher apenas um deles',
    'NO UTILIZAR — Hiperpotasemia fatal por doble bloqueo de ARM',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  ('finerenona', 'enalapril', InteractionSeverity.moderate,
    'Efecto ahorrador de potasio de finerenona + reducción de excreción de K⁺ por IECA',
    'Hiperpotasemia — riesgo aumentado, especialmente en ERC',
    'Monitorar K⁺ semanalmente las primeras 4 semanas. Suspender si K⁺ >5,5 mEq/L',
    'Requiere monitorización de K+ semanal las primeras 4 semanas',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefFDA, _kRefUT]),

    // ── Tocilizumabe / Baricitinibe ───────────────────────────────────────────

  ('tocilizumabe', 'warfarina', InteractionSeverity.moderate,
    'IL-6 regula expresión de enzimas CYP; al bloquear IL-6, tocilizumab restaura metabolismo de warfarina (reduce INR)',
    'Reducción inesperada del INR cuando tocilizumab es iniciado o escalado',
    'Monitorar INR semanalmente por 4–6 semanas después de inicio do tocilizumabe. Ajustar dosis de varfarina',
    'Requiere monitorização de INR — tocilizumabe pode reduzir INR',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.thrombosis},
    [_kRefMdx, _kRefUT]),

  ('tocilizumabe', 'estatina', InteractionSeverity.moderate,
    'El bloqueo de IL-6 restaura CYP3A4 — estatinas metabolizadas por CYP3A4 tienen metabolismo aumentado',
    'Reducción de los niveles plasmáticos de estatinas — menor efecto hipolipemiante',
    'Monitorar perfil lipídico 4–8 semanas tras inicio. Puede ser necesario aumentar dosis de la estatina',
    'Requiere monitorización del perfil lipídico',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('baricitinibe', 'isrs', InteractionSeverity.monitorOnly,
    'Inhibición del transportador OAT3 por baricitinib puede aumentar levemente concentración de algunos SSRIs',
    'Aumento marginal de la exposición a SSRIs eliminados por vía renal',
    'Monitorar efectos adversos de los SSRIs. La interacción generalmente no requiere ajuste de dosis',
    'Solo monitorizar — ajuste de dosis generalmente no necesario',
    EvidenceLevel.theoretical,
    {RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Vedolizumabe ──────────────────────────────────────────────────────────

  ('vedolizumabe', 'natalizumabe', InteractionSeverity.contraindicated,
    'Ambos son antagonistas de integrinas — inmunomodulación aditiva sistémica e intestinal',
    'Riesgo muy aumentado de infecciones oportunistas y leucoencefalopatía multifocal progresiva (LMP)',
    'Contraindicado — no combinar biológicos anti-integrinas. Período de lavado adecuado entre los agentes',
    'NO UTILIZAR — Riesgo de LMP e infecciones oportunistas graves',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefMdx]),

    // ── Tofacitinibe ──────────────────────────────────────────────────────────

  ('tofacitinibe', 'ciclosporina', InteractionSeverity.contraindicated,
    'Inhibición del CYP3A4 + imunossupresión aditiva potente',
    'Infecciones oportunistas graves, nefrotoxicidad, linfoma',
    'Contraindicado. No combinar JAKi con inmunosupresores biológicos potentes',
    'NO UTILIZAR — Inmunosupresión excesiva con riesgo de linfoma',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.nephrotoxicity},
    [_kRefFDA, _kRefMdx]),

  ('tofacitinibe', 'fluconazol', InteractionSeverity.major,
    'Inhibición del CYP3A4 e CYP2C19 pelo fluconazol aumenta exposición ao tofacitinibe em ~130%',
    'Toxicidad por tofacitinib — infecciones, trombosis, elevación de enzimas hepáticas',
    'Reducir dosis de tofacitinib a 5 mg 1x/día durante uso de fluconazol. Monitorar hemograma y transaminasas',
    'ALTO RIESGO — Reducir dosis de tofacitinib y monitorar hemograma',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('tofacitinibe', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induce CYP3A4 → reducción de ~84% en la exposición a tofacitinib',
    'Fracaso terapéutico — concentraciones subterapéuticas',
    'Evitar combinación. Se necesario, monitorar atividade da enfermedad de base. Considerar alternativa biológica',
    'ALTO RIESGO DE FRACASO TERAPÉUTICO — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Ruxolitinibe ──────────────────────────────────────────────────────────

  ('ruxolitinibe', 'claritromicina', InteractionSeverity.major,
    'Inhibición potente del CYP3A4 → aumento de ~200% na exposición ao ruxolitinibe',
    'Citopenia grave (anemia, trombocitopenia), infecciones oportunistas, toxicidad hepática',
    'Reducir dosis de ruxolitinib 50% durante uso de claritromicina. Monitorar hemograma. Alternativa: azitromicina',
    'ALTO RIESGO DE CITOPENIA GRAVE — Reducir dosis de ruxolitinib 50%',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.infection, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('ruxolitinibe', 'fluconazol', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 aumenta exposición ao ruxolitinibe em ~100%',
    'Citopenia y riesgo de infecciones oportunistas aumentado',
    'Reducir dosis de ruxolitinib 50%. Monitorar hemograma frecuentemente',
    'Requiere monitorización — reducir dosis de ruxolitinib 50%',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Dupilumabe / Biológicos respiratórios ─────────────────────────────────

  ('dupilumabe', 'vacinas vivas', InteractionSeverity.major,
    'La inmunosupresión relativa por dupilumab puede reducir la respuesta inmunológica a vacunas vivas',
    'Riesgo de infección por la cepa vacunal (vacuna viva atenuada)',
    'No administrar vacunas vivas durante uso de dupilumab. Completar vacunación antes de iniciar biológico',
    'ALTO RIESGO — Vacunas vivas contraindicadas durante dupilumab',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefMdx]),

  ('mepolizumabe', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'La reducción de eosinófilos por mepolizumab permite retirada de corticosteroides, pero la retirada abrupta causa insuficiencia adrenal',
    'Insuficiencia adrenal aguda si corticosteroide retirado abruptamente',
    'Retirada LENTA y gradual de corticosteroides sistémicos — nunca retirar abruptamente. Monitorar síntomas de insuficiencia adrenal',
    'Requiere retirada LENTA de corticosteroides — nunca suspensión abrupta',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefUT]),

    // ── Isavuconazol ──────────────────────────────────────────────────────────

  ('isavuconazol', 'rifampicina', InteractionSeverity.contraindicated,
    'Rifampicina induce CYP3A4 potentemente → reducción drástica de los niveles de isavuconazol',
    'Fracaso terapéutico antifúngico — concentraciones subterapéuticas',
    'Contraindicado — la combinación invalida el tratamiento antifúngico',
    'NO UTILIZAR — Fracaso terapéutico antifúngico garantizado',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('isavuconazol', 'ciclosporina', InteractionSeverity.moderate,
    'Inhibición del CYP3A4 pelo isavuconazol aumenta exposición à ciclosporina',
    'Toxicidad por ciclosporina — nefrotoxicidad, neurotoxicidad',
    'Monitorar nivel sérico de ciclosporina. Reducir dosis em 25–50% se necesario. Isavuconazol é inhibidor CYP3A4 mais fraco que voriconazol',
    'Requiere monitorización de nivel sérico de ciclosporina',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  ('isavuconazol', 'warfarina', InteractionSeverity.moderate,
    'Inhibición del CYP2C9 por isavuconazol puede aumentar nivel de warfarina',
    'Elevación del INR e riesgo hemorrágico',
    'Monitorar INR a cada 2–3 dias después de inicio e fin do isavuconazol. Ajustar dosis de warfarina según sea necesario',
    'Requiere monitorización de INR cada 2–3 días',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Eltrombopague ─────────────────────────────────────────────────────────

  ('eltrombopague', 'antiácido', InteractionSeverity.major,
    'Cationes polivalentes (Al, Mg, Ca) de los antiácidos forman quelatos con eltrombopag en el TGI',
    'Reducción de hasta el 70% en la absorción del eltrombopag → fracaso terapéutico',
    'Administrar eltrombopag ≥4 horas antes o ≥2 horas después de antiácidos, suplementos de calcio o hierro',
    'ALTO RIESGO DE FRACASO TERAPÉUTICO — Separar por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),

  ('eltrombopague', 'sulfato ferroso', InteractionSeverity.major,
    'El hierro quela eltrombopag en el intestino — reducción drástica de la absorción',
    'Fracaso terapéutico de la trombocitopoyesis',
    'Separar eltrombopag del hierro al menos 4 horas. Tomar eltrombopag en ayunas',
    'ALTO RIESGO DE FRACASO TERAPÉUTICO — Separar por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),

  ('eltrombopague', 'ciclosporina', InteractionSeverity.moderate,
    'Inhibición del OATP1B1 y CYP1A2 por eltrombopag puede aumentar exposición a ciclosporina',
    'Nefrotoxicidad por aumento del nivel de ciclosporina',
    'Monitorar nivel sérico de ciclosporina. Ajustar dosis según sea necesario',
    'Requiere monitorización de nivel sérico de ciclosporina',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // ── Denosumabe ────────────────────────────────────────────────────────────

  ('denosumabe', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Ambos aumentan riesgo de osteonecrosis mandibular y fracturas atípicas; los corticosteroides causan osteoporosis adicional',
    'Riesgo de osteonecrosis mandibular y fracturas óseas graves',
    'Evaluación odontológica obligatoria antes de iniciar. Garantizar reposición adecuada de Ca²⁺ y vitamina D. Monitorar DMO',
    'Requiere evaluación odontológica antes de iniciar + reposición Ca²⁺/VitD',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefFDA, _kRefUT]),

    // ── Bupropiona ────────────────────────────────────────────────────────────

  ('bupropiona', 'imao', InteractionSeverity.contraindicated,
    'Bupropiona inhibe recaptación de dopamina/noradrenalina + IMAOs inhiben degradación — hiperestimulación adrenérgica y serotoninérgica',
    'Crisis hipertensiva, síndrome serotoninérgica, convulsiones — riesgo de muerte',
    'Contraindicado. Esperar ≥14 días después de suspender IMAO antes de iniciar bupropiona',
    'NO UTILIZAR — Síndrome serotoninérgica e crisis hipertensiva',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  ('bupropiona', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina induce CYP3A4/2B6 → reducción significativa de los niveles de bupropiona',
    'Fracaso antidepresivo y en el programa de cesación tabáquica',
    'Aumentar dosis de bupropiona (monitorar efecto). Evaluar alternativa antidepresiva sin interacción con inductores CYP',
    'ALTO RIESGO DE FRACASO TERAPÉUTICO — Monitorar eficácia da bupropiona',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),

  ('bupropiona', 'tramadol', InteractionSeverity.major,
    'Ambos reducen el umbral convulsivo por mecanismos independientes — sinergia proconvulsivante',
    'Riesgo muy aumentado de convulsiones generalizadas',
    'Evitar combinación. Si necesario, usar dosis mínima de tramadol con monitorización neurológica. Considerar analgésico alternativo',
    'ALTO RIESGO DE CONVULSIONES — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefMdx, _kRefFDA]),

  ('bupropiona', 'isrs', InteractionSeverity.moderate,
    'Bupropiona inhibe CYP2D6 → aumenta exposición a fluoxetina, paroxetina y otros SSRIs metabolizados por ese CYP',
    'Síndrome serotoninérgica leve a moderada, elevación de efectos adversos de los SSRIs',
    'Monitorar signos de exceso serotoninérgico. Considerar reducción de dosis del SSRI si aparecen síntomas',
    'Requiere monitorización — riesgo de síndrome serotoninérgica leve',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── Aripiprazol ───────────────────────────────────────────────────────────

  ('aripiprazol', 'claritromicina', InteractionSeverity.major,
    'Inhibición del CYP3A4 pela claritromicina aumenta exposición ao aripiprazol em ~90%',
    'Toxicidad por aripiprazol — acatisia intensa, hipotensión, sedación, convulsiones (raro)',
    'Reducir dosis de aripiprazol 50% durante uso de claritromicina. Monitorar efectos adversos',
    'ALTO RIESGO — Reducir dosis de aripiprazol 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefFDA, _kRefMdx]),

  ('aripiprazol', 'fluoxetina', InteractionSeverity.moderate,
    'Fluoxetina inhibe CYP2D6 y CYP3A4 → aumento del 100% en la exposición a aripiprazol',
    'Acatisia, sedación excesiva, hipotensión ortostática',
    'Reducir dosis de aripiprazol 50% con fluoxetina. Monitorar efectos extrapiramidales y PA',
    'Requiere monitorización — reducir dosis de aripiprazol 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefFDA, _kRefMdx]),

    // ── Perampanel ────────────────────────────────────────────────────────────

  ('perampanel', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina induce potentemente CYP3A4 → reducción de ~67% en la exposición a perampanel',
    'Fallo antiepiléptico — concentraciones subterapéuticas de perampanel',
    'Triplicar la dosis objetivo de perampanel cuando se usa con carbamazepina. Titular cuidadosamente con monitorización clínica',
    'ALTO RIESGO DE FALLO ANTIEPILÉPTICO — Triplicar dosis de perampanel',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('perampanel', 'alcool', InteractionSeverity.major,
    'Perampanel potencializa depresión del SNC por alcohol; puede aumentar comportamientos agresivos/impulsivos',
    'Sedación grave, comportamiento irracional, agresividad, mayor riesgo de accidentes',
    'Contraindicado uso de álcool com perampanel. Orientar al paciente explicitamente',
    'ALTO RIESGO — Prohibido alcohol con perampanel',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefFDA, _kRefMdx]),

    // ── Rifaximina ────────────────────────────────────────────────────────────

  ('rifaximina', 'anticonceptivo', InteractionSeverity.monitorOnly,
    'Incluso con absorción mínima, puede alterar la flora intestinal que participa en la circulación enterohepática de los anticonceptivos',
    'Reducción teórica (bajo riesgo clínico) de la eficacia anticonceptiva hormonal',
    'Riesgo muy bajo (absorción <1%). Sin embargo, orientar uso de método anticonceptivo de barrera adicional por precaución durante y 7 días después del curso',
    'Solo monitorizar — considerar método contraceptivo de barrera adicional',
    EvidenceLevel.theoretical,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

    // ── Nintedanibe ───────────────────────────────────────────────────────────

  ('nintedanibe', 'warfarina', InteractionSeverity.moderate,
    'Nintedanib inhibe P-gp y CYP3A4; interacción potencial aumentando nivel de warfarina',
    'Elevación del INR e riesgo hemorrágico — intensificado pelo riesgo de sangrado GI do nintedanibe',
    'Monitorar INR semanalmente. Vigilancia reforzada para signos de sangrado GI',
    'Requiere monitorización de INR semanal — riesgo hemorrágico aditivo',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('nintedanibe', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induce P-gp y CYP3A4 → reducción de ~60% en los niveles de nintedanib',
    'Fracaso terapéutico en FPI — progresión de la fibrosis',
    'Evitar combinación. Se tratamiento de TB necesario, avaliar alternativa antifibrótica ou sustitución do antimicrobiano',
    'ALTO RIESGO DE FRACASO TERAPÉUTICO — Evitar rifampicina com nintedanibe',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // ── Fondaparinux ──────────────────────────────────────────────────────────

  ('fondaparinux', 'isrs', InteractionSeverity.moderate,
    'SSRIs inhiben función plaquetaria (reducción de serotonina plaquetaria) + anticoagulación del fondaparinux',
    'Riesgo aumentado de sangrado — especialmente GI',
    'Monitorar signos de sangrado. Considerar IBP para protección gástrica en uso combinado',
    'Requiere monitorización clínica — riesgo hemorrágico aditivo',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefMdx, _kRefUT]),

  ('fondaparinux', 'aine', InteractionSeverity.moderate,
    'AINEs inhiben función plaquetaria y protegen mucosa gástrica — riesgo hemorrágico aditivo',
    'Sangrado GI y en otros sitios',
    'Evitar AINEs con fondaparinux. Usar paracetamol para analgesia. Si AINE necesario, asociar IBP',
    'Requiere monitorización — evitar AINEs; usar paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── Lote 3 — Novas interacciones ─────────────────────────────────────────────

    // Gabapentina

  ('gabapentina', 'morfina', InteractionSeverity.major,
    'Sinergismo farmacodinámico en la depresión del SNC y del centro respiratorio',
    'Depresión respiratoria potencialmente fatal, sedación profunda, apnea',
    'Evitar combinación ou reducir dosiss. Monitorar FR e saturação. Tener naloxona disponible',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  ('gabapentina', 'opioide', InteractionSeverity.major,
    'Sinergismo farmacodinámico — ambos deprimen SNC y centro respiratorio',
    'Depresión respiratoria grave, sedación excesiva, riesgo de muerte',
    'FDA Black Box Warning. Usar la menor dosis eficaz de cada uno. Monitorar SpO2 continuamente',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx, _kRefGG]),

  ('gabapentina', 'benzodiazepínico', InteractionSeverity.major,
    'Depressão aditiva do SNC pela combinación de anticonvulsivante + benzodiazepínico',
    'Sedación excesiva, depresión respiratoria, riesgo de queda',
    'Reducir dosis. Monitorar nivel de consciencia. Evitar en ancianos sin soporte monitorizado',
    'ALTO RIESGO DE SEDAÇÃO E QUEDA — Reducir dosiss e monitorar',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

    // Sertralina + Tramadol

  ('fenobarbital', 'warfarina', InteractionSeverity.major,
    'Fenobarbital induce potentemente CYP2C9 y CYP3A4, acelerando el metabolismo de warfarina',
    'Reducción marcada del INR — fallo anticoagulante y riesgo trombótico',
    'Monitorar INR semanalmente ao iniciar/suspender fenobarbital. Aumentar dosis de warfarina conforme INR',
    'ALTO RIESGO DE FALLO ANTICOAGULANTE — Monitorar INR semanalmente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel, RiskType.thrombosis},
    [_kRefGG, _kRefMdx]),

  ('fenobarbital', 'apixabana', InteractionSeverity.major,
    'Inducción de CYP3A4 y P-gp por fenobarbital reduce niveles plasmáticos de apixabán en ~50%',
    'Anticoagulación subterapéutica — riesgo de tromboembolismo (ACV, TEP, TVP)',
    'Contraindicado pela bula da apixabana. Sustituir anticonvulsivante ou trocar anticoagulante',
    'ALTO RIESGO DE TROMBOEMBOLISMO — Apixabana contraindicada com fenobarbital',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefFDA, _kRefMdx]),

  ('fenobarbital', 'rivaroxabana', InteractionSeverity.major,
    'Inducción de CYP3A4 y P-gp reduce exposición a rivaroxabán significativamente',
    'Pérdida de efecto anticoagulante — riesgo tromboembólico grave',
    'Contraindicado. Evitar combinación. Usar heparina ou warfarina com monitorização rigurosa do INR',
    'ALTO RIESGO DE TROMBOEMBOLISMO — Rivaroxabana contraindicada com fenobarbital',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefFDA, _kRefMdx]),

    // Metformina + Furosemida

  ('metformina', 'furosemida', InteractionSeverity.moderate,
    'Furosemida causa depleción de volumen y reduce aclaramiento renal de metformina; riesgo aumentado de acidosis láctica en contextos de hipovolemia',
    'Acumulación de metformina por reducción de la excreción renal → acidosis láctica (rara pero grave)',
    'Monitorar función renal (creatinina/TFG) al iniciar ou titular furosemida. Suspender metformina se TFG <30 mL/min',
    'Requiere monitorización renal — suspender metformina si TFG <30',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

    // Espironolactona + IECAs

  ('dexmedetomidina', 'metoprolol', InteractionSeverity.moderate,
    'El agonismo alfa-2 central de dexmedetomidina potencia bradicardia e hipotensión de los betabloqueadores',
    'Bradicardia sinusal, hipotensión refractaria — especialmente en hipovolemia',
    'Monitorar FC e PA continuamente em UTI. Reducir dosis de betabloqueador si FC <50 lpm o PA sistólica <90 mmHg',
    'Requiere monitorización hemodinámica continua en UCI',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

  ('dexmedetomidina', 'propofol', InteractionSeverity.moderate,
    'Sedación aditiva del SNC — ambos son agentes de sedación IV',
    'Sedación excesiva, apnea, hipotensión, bradicardia',
    'Reducir dosis de propofol al combinar. Monitorar nivel de sedación (escala RASS), FR y hemodinámica',
    'Requiere monitorización de RASS, FR y hemodinámica',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular, RiskType.cns},
    [_kRefMdx, _kRefUT]),

    // Propofol

  ('propofol', 'opioide', InteractionSeverity.moderate,
    'Sinergismo sedante y depresor respiratorio — especialmente con fentanilo y remifentanilo',
    'Apnea, hipotensión, bradicardia — riesgo aumentado en bolos',
    'Titular cuidadosamente. Tener soporte de vía aérea disponible. Monitorar ETCO2 si posible',
    'Requiere monitorização — riesgo de apnea em bolus',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

    // Fentanila + Benzodiazepínico

  ('fentanila', 'benzodiazepínico', InteractionSeverity.major,
    'Depresión aditiva del SNC — combinación clásica de inducción anestésica con riesgo aumentado',
    'Depresión respiratoria grave, apnea, hipotensión',
    'FDA Black Box Warning para essa combinación em contexto ambulatorial. Em UTI: monitoramento contínuo de SpO2, FR e PA',
    'ALTO RIESGO DE DEPRESIÓN RESPIRATORIA — FDA Black Box Warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefGG]),

    // Esmolol

  ('esmolol', 'verapamil', InteractionSeverity.major,
    'Bloqueo aditivo del nodo AV por betabloqueador IV + bloqueador de calcio — riesgo máximo en vía IV',
    'Asistolia, bloqueo AV completo, colapso hemodinámico',
    'Contraindicado usar IV simultáneamente. Se necesario, espaçar administrações com monitoramento rigoroso de ECG',
    'ALTO RIESGO DE ASISTOLIA — Nunca administrar IV simultáneamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // Milrinona

  ('milrinona', 'furosemida', InteractionSeverity.moderate,
    'Furosemida causa hipovolemia e hipopotasemia, amplificando efectos vasodilatadores de milrinona',
    'Hipotensión grave, arritmias por hipopotasemia (potencializa milrinona)',
    'Reponer K+ antes de iniciar. Monitorar PA, diuresis y electrolitos cada 4–6h',
    'Requiere monitorización de PA y K+ cada 4–6h',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hypokalemia},
    [_kRefMdx, _kRefUT]),

    // Levosimendan

  ('levosimendan', 'nitrato', InteractionSeverity.moderate,
    'Ambos son vasodilatadores — levosimendan abre canales K-ATP vasculares; nitratos liberan NO',
    'Hipotensión grave, especialmente en las primeras horas de infusión de levosimendan',
    'Monitorar PA invasiva. Reducir o suspender nitrato durante infusión de levosimendan. Reponer volumen si necesario',
    'Requiere monitorização de PA invasiva durante infusão',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

    // Naloxona

  ('naloxona', 'opioide', InteractionSeverity.major,
    'Antagonismo competitivo en los receptores mu-opioide — revierte analgesia y sedación',
    'Crisis de abstinencia aguda en dependientes, dolor intenso, agitación, hipertensión, edema pulmonar (raro)',
    'Titular en dosis bajas IV (0,04–0,1 mg) para revertir depresión respiratoria sin precipitar abstinencia. Reevaluar cada 2–3 min',
    'Titular naloxona en dosis bajas — riesgo de abstinencia aguda',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.cns},
    [_kRefGG, _kRefFDA]),

    // Labetalol

  ('labetalol', 'verapamil', InteractionSeverity.major,
    'Bloqueo combinado alfa+beta (labetalol) + bloqueo de canal de calcio — depresión cardíaca aditiva',
    'Bradicardia, hipotensión grave, insuficiencia cardíaca aguda',
    'Evitar combinación. Monitorar ECG, FC e PA. No usar em IC descompensada',
    'ALTO RIESGO CARDIOVASCULAR — Evitar en IC descompensada',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // Aminoglicosídeo + Vancomicina (Lote 3 duplicate — mantido por compatibilidade)
    // (já existe entrada idêntica acima; esta é aceita por _seen deduplication)

    // Fluconazol — CYP2C9/3A4

  ('fluconazol', 'sinvastatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 pelo fluconazol aumenta AUC da sinvastatina em até 14 vezes',
    'Miopatía grave, rabdomiólisis con insuficiencia renal aguda',
    'Suspender simvastatina durante el curso de fluconazol. Reanudar tras 48–72h. Si estatina necesaria, usar pravastatina',
    'RIESGO DE RABDOMIÓLISIS — Suspender simvastatina durante fluconazol',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  ('fluconazol', 'atorvastatina', InteractionSeverity.major,
    'Inhibición del CYP3A4 eleva concentraciones de atorvastatina significativamente',
    'Miopatía, rabdomiólisis, lesão renal aguda',
    'Suspender atorvastatina durante fluconazol. Alternativa: pravastatina o rosuvastatina en dosis reducida',
    'RIESGO DE RABDOMIÓLISIS — Suspender atorvastatina durante fluconazol',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefFDA]),

  ('fluconazol', 'quetiapina', InteractionSeverity.major,
    'Inhibición de CYP3A4 aumenta exposición a quetiapina con prolongación del QTc',
    'Prolongamento do intervalo QT, torsades de pointes, fibrilación ventricular',
    'Evitar. Si inevitable, reducir dosis de quetiapina 50% y monitorar ECG seriado',
    'ALTO RIESGO DE TORSADES DE POINTES — Reducir quetiapina 50%',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

  ('fluconazol', 'fenitoína', InteractionSeverity.major,
    'Fluconazol inhibe CYP2C9 y CYP2C19 — principales metabolizadores de fenitoína',
    'Toxicidad por fenitoína: nistagmo, ataxia, diplopía, convulsiones paradójicas',
    'Monitorar nivel sérico de fenitoína (nivel objetivo: 10–20 mcg/mL). Reducir dosis de fenitoína anticipadamente',
    'ALTO RIESGO DE TOXICIDAD POR FENITOÍNA — Monitorar nivel sérico',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

    // Fenitoína (inductora)

  ('fenitoína', 'warfarina', InteractionSeverity.major,
    'Fenitoína induce CYP2C9 → mayor metabolismo de warfarina; también puede desplazar warfarina de proteínas (efecto bifásico)',
    'Inicialmente: elevación del INR → riesgo hemorrágico. Crónicamente: reducción del INR → riesgo tromboembólico',
    'Monitorar INR intensivamente al iniciar/ajustar/suspender fenitoína. Ajustar dosis de warfarina según curva',
    'ALTO RIESGO — INR instável; monitorar intensivamente ao ajustar fenitoína',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('fenitoína', 'lamotrigina', InteractionSeverity.major,
    'Fenitoína induce UGT y CYP2C19, acelerando glucuronidación de lamotrigina',
    'Reducción del 40–50% en los niveles de lamotrigina → fallo antiepiléptico',
    'Doblar la dosis objetivo de lamotrigina cuando se asocia con fenitoína. Monitorar nivel sérico si disponible',
    'ALTO RIESGO DE FALLO ANTIEPILÉPTICO — Doblar dosis de lamotrigina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // Topiramato

  ('topiramato', 'valproato', InteractionSeverity.moderate,
    'Interacción farmacodinámica y metabólica: topiramato puede reducir niveles de valproato e inhibir beta-oxidación mitocondrial',
    'Encefalopatía hiperamonémica (sin elevación de aminotransferasas), hipotermia',
    'Monitorar amonio sérico en pacientes sintomáticos (confusión, letargia). Suspender topiramato si encefalopatía',
    'Requiere monitorización de amonio sérico — riesgo de encefalopatía',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('topiramato', 'anticonceptivo', InteractionSeverity.moderate,
    'Topiramato induce CYP3A4 en dosis ≥200 mg/día, reduciendo etinilestradiol y progestágeno',
    'Fracaso anticonceptivo — embarazo no planificado',
    'Usar método anticonceptivo no hormonal (DIU de cobre, preservativo). Orientar al paciente explícitamente sobre el riesgo',
    'Requiere método contraceptivo no hormonal — riesgo de fracaso',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

    // Olanzapina

  ('olanzapina', 'benzodiazepínico', InteractionSeverity.major,
    'Depresión aditiva del SNC — riesgo especialmente elevado con formulación IM de olanzapina',
    'Sedación grave, depresión respiratoria, hipotensión — casos de muerte descritos',
    'Contraindicado usar olanzapina IM com benzodiazepínico parenteral (intervalo mínimo 1h). Monitorar SpO2 e PA',
    'ALTO RIESGO DE MUERTE — Contraindicado olanzapina IM + BDZ parenteral',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  ('olanzapina', 'metoprolol', InteractionSeverity.moderate,
    'Olanzapina inhibe CYP2D6, aumentando exposición a metoprolol',
    'Bradicardia, hipotensión ortostática, broncoespasmo en asmáticos',
    'Monitorar FC e PA. Reducir dosis de metoprolol si FC <55 lpm o sintomático',
    'Requiere monitorização de FC e PA — bradicardia por inhibición CYP2D6',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefLex]),

    // Mirtazapina

  ('mirtazapina', 'tramadol', InteractionSeverity.major,
    'Mirtazapina tiene acción serotoninérgica y noradrenérgica; tramadol inhibe recaptación de serotonina',
    'Síndrome serotoninérgica — hipertermia, agitación, clonus, diarrea',
    'Evitar combinación. Se analgesia opioide necesaria, preferir morfina ou fentanila pura',
    'ALTO RIESGO DE SÍNDROME SEROTONINÉRGICA — Preferir morfina',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    [_kRefMdx, _kRefUT]),

  ('mirtazapina', 'imao', InteractionSeverity.contraindicated,
    'Mirtazapina potencializa transmisión serotoninérgica y noradrenérgica; IMAOs bloquean catabolismo de monoaminas',
    'Síndrome serotoninérgica grave potencialmente fatal',
    'ABSOLUTAMENTE CONTRAINDICADO. Intervalo mínimo de 14 días entre IMAO y mirtazapina',
    'NO UTILIZAR — Síndrome serotoninérgica fatal; período de lavado 14 días',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefFDA, _kRefGG]),

    // Clonazepam + Valproato

  ('benzodiazepínico', 'valproato', InteractionSeverity.moderate,
    'Valproato puede aumentar concentraciones de clonazepam por inhibición metabólica; riesgo de ausencia paradójica',
    'Sedación excesiva, ou paradoxalmente: piora do estado de ausência epiléptica',
    'Monitorar respuesta clínica. Evaluar patrón de ausencias en electroencefalograma si empeora',
    'Requiere monitorización clínica — empeoramiento paradójico de ausencias posible',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // Acetazolamida

  ('acetazolamida', 'topiramato', InteractionSeverity.moderate,
    'Ambos inhiben anhidrasa carbónica — efecto aditivo en acidosis metabólica y nefrolitiasis',
    'Acidosis metabólica hiperclorémica grave, nefrolitiasis, encefalopatía (raro)',
    'Evitar combinación. Monitorar gasometría e pH urinário. Garantizar hidratación >2L/día',
    'Requiere monitorización de gasometría — acidosis metabólica aditiva',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefMdx, _kRefGG]),

  ('acetazolamida', 'aspirina', InteractionSeverity.major,
    'AAS en dosis analgésicas compite con acetazolamida por secreción tubular renal, elevando nivel de acetazolamida; también puede inducir acidosis',
    'Toxicidad por acetazolamida: letargia, anorexia, parestesias, acidosis grave',
    'Evitar AAS em dosis altas com acetazolamida. Se analgesia necesaria, usar paracetamol',
    'ALTO RIESGO DE TOXICIDAD — Usar paracetamol en vez de AAS',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.nephrotoxicity},
    [_kRefMdx, _kRefGG]),

    // Clortalidona / Hidroclorotiazida

  ('hidroclorotiazida', 'digoxina', InteractionSeverity.major,
    'La hipopotasemia inducida por tiazídico potencializa toxicidad de digoxina (competencia por bomba Na/K-ATPase)',
    'Toxicidad digitálica: bradiarritmia, BAV, bigeminismo, náuseas, trastornos visuales',
    'Manter K+ sérico >4 mEq/L. Dosar K+ e digoxina regularmente. Suplementar KCl se necesario',
    'ALTO RIESGO DE TOXICIDAD DIGITÁLICA — Mantener K+ >4 mEq/L',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // Verapamil + Digoxina

  ('verapamil', 'digoxina', InteractionSeverity.major,
    'Verapamil inhibe P-gp y reduce aclaramiento renal de digoxina, aumentando nivel sérico en 50–75%',
    'Toxicidad digitálica: BAV, bradicardia grave, náuseas, visión borrosa',
    'Reducir dosis de digoxina 30–50% al iniciar verapamil. Monitorar nivel sérico de digoxina. ECG seriado',
    'ALTO RIESGO DE TOXICIDAD DIGITÁLICA — Reducir digoxina 30–50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

    // Glibenclamida

  ('glibenclamida', 'ciprofloxacino', InteractionSeverity.moderate,
    'Ciprofloxacino inhibe CYP1A2 y puede aumentar secreción de insulina por bloqueo de canales K-ATP pancreáticos',
    'Hipoglucemia — especialmente en ancianos con insuficiencia renal',
    'Monitorar glucemia. Orientar al paciente sobre síntomas de hipoglucemia. Evaluar sustitución del antibiótico',
    'Requiere monitorização de glucemia — hipoglucemia en ancianos',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefMdx, _kRefUT]),

    // Isossorbida + Sildenafila

  ('rocurônio', 'aminoglicosideo', InteractionSeverity.moderate,
    'Aminoglicosídeos inibem a liberação de acetilcolina na junção neuromuscular — potenciación do bloqueio neuromuscular',
    'Prolongación del bloqueo neuromuscular, dificultad de reversión con neostigmina',
    'Monitorar bloqueo neuromuscular con TOF (train-of-four). Tener sugamadex disponible para reversión en bloqueo prolongado',
    'Requiere monitorización con TOF — tener sugamadex disponible',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

    // Tigeciclina

  ('tigeciclina', 'warfarina', InteractionSeverity.moderate,
    'Tigeciclina pode aumentar INR por mecanismo não completamente elucidado (possivelmente inhibición de la flora intestinal produtora de vitamina K)',
    'Elevación del INR com riesgo hemorrágico',
    'Monitorar INR a cada 2–3 dias durante uso de tigeciclina. Ajustar dosis de warfarina según sea necesario',
    'Requiere monitorización de INR cada 2–3 días',
    EvidenceLevel.possible,
    {RiskType.hemorrhagic},
    [_kRefMdx, _kRefFDA]),

    // Ceftolozana + Furosemida

  ('ceftolozana', 'furosemida', InteractionSeverity.monitorOnly,
    'Furosemida puede reducir excreción renal de betalactámicos por competencia tubular',
    'Aumento leve de los niveles plasmáticos de ceftolozana — sin relevancia clínica significativa en la mayoría de los casos',
    'Sin ajuste necesario con función renal normal. Monitorar TFG en pacientes con insuficiencia renal previa',
    'Solo monitorizar — ajuste no necesario con función renal normal',
    EvidenceLevel.theoretical,
    {RiskType.plasmaLevel},
    [_kRefMdx]),

    // Clonixinato de Lisina

  ('clonixinato', 'warfarina', InteractionSeverity.moderate,
    'AINE con inhibición plaquetaria y posible desplazamiento proteico de warfarina',
    'Aumento del INR y riesgo de sangrado',
    'Evitar. Preferir paracetamol como analgésico alternativo. Monitorar INR se uso inevitável',
    'Requiere monitorização de INR — usar paracetamol',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx]),

  ('clonixinato', 'aine', InteractionSeverity.moderate,
    'Riesgo aditivo de toxicidad GI y renal por uso de dos AINEs simultáneamente',
    'Úlcera gástrica, sangrado GI, lesión renal aguda',
    'No asociar dos AINEs. Elegir un único AINE en la menor dosis eficaz por el menor tiempo',
    'Requiere monitorização — evitar uso de dois AINEs simultáneamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ══════════════════════════════════════════════════════════════════════════
    // AUDITORIA COMPLETA — LOTE 4 — pares clinicamente críticos faltantes
    // Fonte: Goodman & Gilman 14ª ed., Micromedex 2024, UpToDate 2024,
    //        Lexicomp 2024, FDA Drug Label, ESC/AHA/SBC Guidelines
    // ══════════════════════════════════════════════════════════════════════════

    // ── 1. ANTICOAGULANTES ORAIS DIRETOS (AOD) ────────────────────────────────

  ('apixabana', 'aspirina', InteractionSeverity.major,
    'Doble inhibición hemostática: apixabán bloquea factor Xa; aspirina inhibe COX-1 plaquetaria',
    'Riesgo hemorrágico aumentado 2-3x — hemorragia GI, intracraneal, retroperitoneal',
    'Evitar combinación crônica salvo indicação específica (ex: FA + SCA recente). Se necesario, IBP obligatorio e dosis mínima de AAS (100 mg)',
    'RIESGO HEMORRÁGICO GRAVE — Evitar combinación crónica sin indicación formal',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),


  ('apixabana', 'aine', InteractionSeverity.major,
    'AINE inhibe COX-1 plaquetaria y prostaglandinas citoprotectoras gástricas; apixabán bloquea factor Xa',
    'Sangrado GI significativo; riesgo de IRA por reducción de prostaglandinas renales',
    'Evitar combinación. Si inevitable: IBP, menor dosi es posible de AINE, monitorar signos de sangrado',
    'RIESGO HEMORRÁGICO + RENAL — Evitar AINEs durante anticoagulación con apixabán',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rivaroxabana', 'aspirina', InteractionSeverity.major,
    'Doble inhibición hemostática: rivaroxabán bloquea factor Xa; aspirina inhibe COX-1 plaquetaria',
    'Riesgo hemorrágico aumentado — hemorragia GI, intracraneal',
    'Evitar combinación crônica salvo indicação específica (SCA + FA). Se necesario, IBP obligatorio',
    'RIESGO HEMORRÁGICO GRAVE — La combinación aumenta el sangrado en 2-3x',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),


  ('rivaroxabana', 'aine', InteractionSeverity.major,
    'AINE inhibe COX-1 plaquetaria; rivaroxabán bloquea factor Xa — efecto aditivo en sangrado GI',
    'Sangrado GI significativo; lesión renal aguda',
    'Evitar combinación. Si inevitable: IBP, menor dosis de AINE, monitorar signos de sangrado',
    'RIESGO HEMORRÁGICO + RENAL — Evitar AINEs durante anticoagulación con rivaroxabán',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('dabigatrana', 'aspirina', InteractionSeverity.major,
    'Doble inhibición hemostática: dabigatrán inhibe trombina; aspirina inhibe COX-1 plaquetaria',
    'Riesgo hemorrágico aumentado — hemorragia GI, intracraneal',
    'Evitar combinación crônica. Se necesario (pós-SCA + FA), usar dosis mínima de AAS + IBP',
    'RIESGO HEMORRÁGICO GRAVE — La combinación aumenta el sangrado significativamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),


  ('dabigatrana', 'aine', InteractionSeverity.major,
    'AINE inhibe COX-1 plaquetaria; dabigatrán inhibe trombina — efecto aditivo en el sangrado',
    'Sangrado GI significativo; posible lesão renal',
    'Evitar combinación. Si inevitable: menor dosis de AINE por menor tempo, IBP, monitoração rigurosa',
    'RIESGO HEMORRÁGICO — Evitar AINEs durante anticoagulación con dabigatrán',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('apixabana', 'clopidogrel', InteractionSeverity.major,
    'Doble antitrombótica: apixabán anticoagulante + clopidogrel antiagregante — sin beneficio aditivo en la mayoría de indicaciones',
    'Riesgo hemorrágico doblado sin beneficio adicional en la mayoría de los pacientes',
    'Evitar terapia triple. Si FA + stent coronario, preferir doble (AOD + un antiagregante) el menor tiempo posible',
    'TRIPLE ANTITROMBÓTICA — Evitar. Riesgo hemorrágico doblado; usar doble terapia cuando sea posible',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefFDA]),


  ('rivaroxabana', 'clopidogrel', InteractionSeverity.major,
    'Doble antitrombótica: rivaroxabán anticoagulante + clopidogrel antiagregante',
    'Riesgo hemorrágico doblado sin beneficio adicional en la mayoría de los pacientes',
    'Evitar terapia triple. Si indicado, usar el menor tiempo posible con IBP obligatorio',
    'TRIPLE ANTITROMBÓTICA — Evitar. Riesgo hemorrágico muy aumentado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefFDA]),


  ('apixabana', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inhibe CYP3A4 y P-gp, principales vías de metabolismo de apixabán',
    'Aumento significativo dos niveles plasmáticos de apixabana — riesgo hemorrágico grave',
    'Evitar combinación. Si inevitable, reducir dosis de apixabana e monitorar signos de sangrado',
    'RIESGO HEMORRÁGICO — Fluconazol eleva niveles de apixabán significativamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT, _kRefLex]),


  ('rivaroxabana', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inhibe CYP3A4 y P-gp, principales vías de metabolismo de rivaroxabán',
    'Aumento significativo dos niveles plasmáticos de rivaroxabana — riesgo hemorrágico grave',
    'Evitar combinación. Si inevitable, monitorar signos de sangrado rigurosamente',
    'RIESGO HEMORRÁGICO — Fluconazol eleva niveles de rivaroxabán significativamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT, _kRefLex]),


  ('apixabana', 'rifampicina', InteractionSeverity.major,
    'Rifampicina es potente inductor de CYP3A4 y P-gp — aumenta metabolismo y eflujo de apixabán',
    'Reducción del 54% en los niveles plasmáticos de apixabán — riesgo de fallo anticoagulante y trombosis',
    'Evitar combinación. Considerar anticoagulante alternativo não dependente de CYP3A4/P-gp',
    'RIESGO DE TROMBOSIS — Rifampicina reduce niveles de apixabán en ~54%',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),


  ('rivaroxabana', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induce CYP3A4 y P-gp — aumenta metabolismo y eflujo de rivaroxabán',
    'Reducción de ~50% en los niveles plasmáticos de rivaroxabán — fallo anticoagulante',
    'Evitar combinación. Considerar anticoagulante alternativo durante uso de rifampicina',
    'RIESGO DE TROMBOSIS — Rifampicina reduce niveles de rivaroxabán en ~50%',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),


  ('dabigatrana', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induce P-gp (principal transportador de eflujo de dabigatrán)',
    'Reducción de ~66% en los niveles plasmáticos de dabigatrán — riesgo de trombosis',
    'Evitar combinación. Considerar anticoagulante alternativo durante uso de rifampicina',
    'RIESGO DE TROMBOSIS — Rifampicina reduce niveles de dabigatrán en ~66%',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

    // ── 2. WARFARINA — pares faltantes ────────────────────────────────────────

  ('warfarina', 'clopidogrel', InteractionSeverity.major,
    'Mecanismos complementarios: warfarina inhibe coagulación; clopidogrel inhibe agregación plaquetaria vía P2Y12',
    'Sangrado GI grave, hemorragia intracraneal — riesgo 3x mayor que monoterapia',
    'Evitar terapia triple (warfarina + AAS + clopidogrel). Si FA + stent: preferir AOD + antiagregante único',
    'TRIPLE ANTITROMBÓTICA — Riesgo hemorrágico muy elevado; reevaluar indicación',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT]),


  ('warfarina', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina es potente inductor del CYP2C9 y CYP3A4 — aumenta metabolismo de warfarina',
    'Reducción significativa do INR — perda do efecto anticoagulante e riesgo de trombosis',
    'Monitorar INR rigurosamente al iniciar ou suspender carbamazepina. Ajustar dosis conforme INR',
    'RIESGO DE TROMBOSIS — Carbamazepina reduce el efecto anticoagulante de warfarina',
    EvidenceLevel.established,
    {RiskType.thrombosis, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('warfarina', 'tramadol', InteractionSeverity.major,
    'Tramadol inhibe CYP2C9 (metabolismo de warfarina S) y puede tener efecto anticoagulante aditivo',
    'Elevación del INR — riesgo de sangrado grave',
    'Monitorar INR próximo al iniciar ou suspender tramadol. Ajustar dosis de warfarina según sea necesario',
    'RIESGO HEMORRÁGICO — Tramadol eleva INR; monitorar warfarina rigurosamente',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('warfarina', 'omeprazol', InteractionSeverity.moderate,
    'Omeprazol inhibe CYP2C19 — puede elevar discretamente los niveles de warfarina S',
    'Elevación moderada del INR en algunos pacientes (polimorfismo CYP2C19)',
    'Monitorar INR al iniciar ou trocar IBP. O efecto é clinicamente relevante apenas em metabolizadores lentos do CYP2C19',
    'Monitorar INR — omeprazol pode elevar discretamente o efecto anticoagulante',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('warfarina', 'sulfametoxazol', InteractionSeverity.major,
    'SMX-TMP inhibe CYP2C9 (metabolizador de warfarina S) y desplaza warfarina de proteínas plasmáticas',
    'Elevación abrupta del INR en 2-3x — riesgo de sangrado grave',
    'Reducir dosis de warfarina 25-50% al iniciar SMX-TMP. Monitorar INR en 3-5 días. Preferir antibiótico alternativo cuando sea posible',
    'RIESGO HEMORRÁGICO GRAVE — SMX-TMP es uno de los mayores potenciadores del efecto de warfarina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── 3. CLOPIDOGREL — pares faltantes ──────────────────────────────────────

  ('clopidogrel', 'aspirina', InteractionSeverity.moderate,
    'Doble antiagregación plaquetaria: clopidogrel vía P2Y12; aspirina vía COX-1 — complementarios en contexto de síndrome coronario agudo y stent',
    'Riesgo hemorrágico aumentado vs. monoterapia (sangrado GI, equimosis); necesario en indicaciones específicas (SCA, stent coronario)',
    'Indicado em SCA e pós-stent coronário por tempo definido (12 meses/6 meses conforme stent). IBP obligatorio. Evitar fora dessas indicações',
    'DOBLE ANTIAGREGACIÓN — Necesaria en SCA/stent, pero monitorar sangrado. IBP obligatorio',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),

    // ── 4. IECA/ARA-II — pares faltantes ──────────────────────────────────────

  ('enalapril', 'cloreto de potassio', InteractionSeverity.major,
    'IECA reduce excreción renal de potasio por inhibición de aldosterona; suplementación de KCl aditiva',
    'Hiperpotasemia grave — riesgo de arritmias ventriculares fatales, paro cardíaco',
    'Monitorar electrolitos rigurosamente. Reducir o suspender suplementación de KCl. Evitar en insuficiencia renal',
    'RIESGO DE HIPERPOTASEMIA GRAVE — IECA + KCl puede causar arritmia fatal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefUT]),


  ('losartana', 'cloreto de potassio', InteractionSeverity.major,
    'ARA-II reduce excreción renal de potasio por bloqueo del receptor AT1; suplementación de KCl aditiva',
    'Hiperpotasemia grave — riesgo de arritmias ventriculares fatales',
    'Monitorar electrolitos rigurosamente. Reducir o suspender suplementación de KCl. Evitar en insuficiencia renal',
    'RIESGO DE HIPERPOTASEMIA GRAVE — ARA-II + KCl puede causar arritmia fatal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefUT]),


  ('enalapril', 'trimetoprima', InteractionSeverity.major,
    'Trimetoprima bloquea secreción tubular de potasio de forma similar a amilorida; IECA ya reduce excreción de K+',
    'Hiperpotasemia grave — especialmente en ancianos, diabéticos e insuficiencia renal',
    'Monitorar potássio sérico 3-5 dias después de inicio de SMX-TMP en pacientes em uso de IECA/ARA-II',
    'RIESGO DE HIPERPOTASEMIA — SMX-TMP + IECA combinación frecuentemente subestimada',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefUT, _kRefMdx]),


  ('losartana', 'aine', InteractionSeverity.moderate,
    'AINEs reducen síntesis de prostaglandinas vasodilatadoras renales e antagonizam efecto do ARA-II',
    'Reducción del efecto antihipertensivo do ARA-II; riesgo de insuficiencia renal aguda',
    'Evitar uso crónico concomitante. Si necesario, monitorar PA y función renal. Preferir paracetamol como analgésico',
    'Requiere monitorización — AINEs reducen efecto antihipertensivo y aumentan riesgo renal',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),


  ('enalapril', 'hidroclorotiazida', InteractionSeverity.minor,
    'Combinación sinérgica antihipertensiva — IECA potencializa efecto diurético y viceversa',
    'Hipotensión de primera dosis, especialmente en pacientes con depleción volémica; hiponatremia e hipopotasemia',
    'Combinación frecuentemente intencional e benéfica (formulações fixas disponibles). Iniciar com dosis bajas e titular. Monitorar PA na 1ª semana e electrolitos a cada 3 meses',
    'Combinación sinérgica — vigilar hipotensión de 1ª dosis y electrolitos',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hypokalemia, RiskType.electrolyte},
    [_kRefGG, _kRefKatz, _kRefUT]),

    // ── 5. ESTATINAS — pares faltantes ────────────────────────────────────────

  ('rosuvastatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inhibe CYP2C9 y puede elevar niveles de rosuvastatina; riesgo farmacodinámico aditivo de miopatía',
    'Miopatía, mialgia, rabdomiólisis — riesgo menor que con gemfibrozil',
    'Monitorar síntomas musculares. Preferir fenofibrato em vez de gemfibrozil quando necesario combinar com estatina. Usar menor dosis de estatina',
    'Monitorar síntomas musculares — riesgo de miopatía com combinación estatina + fibrato',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('sinvastatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inhibe glucuronidación de simvastatina y tiene efecto farmacodinámico aditivo de miopatía',
    'Miopatía, mialgia; menor riesgo de rabdomiólisis vs. gemfibrozil',
    'Monitorar síntomas musculares regularmente. Preferir fenofibrato vs. gemfibrozil. Evitar altas dosis de sinvastatina',
    'Monitorar síntomas musculares — preferir fenofibrato a gemfibrozil se necesario',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('rosuvastatina', 'claritromicina', InteractionSeverity.moderate,
    'Claritromicina inhibe CYP3A4, pero rosuvastatina no es metabolizada por CYP3A4; inhibe OATP1B1 — efecto moderado',
    'Aumento moderado de los niveles de rosuvastatina — riesgo de miopatía',
    'Monitorar síntomas musculares. Reducir dosis de rosuvastatina ou suspender temporariamente durante curso de claritromicina',
    'Monitorar síntomas musculares durante uso de claritromicina com rosuvastatina',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('atorvastatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inibe CYP2C8 e tem efecto farmacodinâmico aditivo; menos interacción que com gemfibrozil',
    'Riesgo de miopatía; menor que com gemfibrozil',
    'Combinación aceitável com monitoramento. Usar menor dosis eficaz de atorvastatina. Monitorar CPK y síntomas musculares',
    'Monitorar síntomas musculares — combinación generalmente tolerada com vigilancia',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefMdx, _kRefFDA]),

    // ── 6. DIGOXINA — pares faltantes ─────────────────────────────────────────

  ('digoxina', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe P-gp intestinal e renal, principal via de eliminación da digoxina',
    'Aumento de 70-100% nos niveles séricos de digoxina — toxicidad digitálica (náusea, bradiarritmias, BAV)',
    'Reducir dosis de digoxina em 50% al iniciar claritromicina. Monitorar nivel sérico de digoxina e ECG. Preferir azitromicina si es posible',
    'TOXICIDAD DIGITÁLICA — Claritromicina dobra niveles de digoxina; ajustar dosis obligatoriamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('digoxina', 'azitromicina', InteractionSeverity.moderate,
    'Azitromicina inibe P-gp intestinal, aumentando absorción de digoxina; menor efecto que claritromicina',
    'Aumento moderado dos niveles séricos de digoxina — riesgo de toxicidad digitálica',
    'Monitorar síntomas de toxicidad digitálica (náusea, bradicardia) durante uso de azitromicina. Considerar nivel sérico',
    'Monitorar toxicidad digitálica — azitromicina pode elevar niveles de digoxina moderadamente',
    EvidenceLevel.probable,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('amiodarona', 'ciprofloxacino', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT por bloqueio de canais de potássio (IKr) — efecto aditivo',
    'Torsades de Pointes, taquicardia ventricular polimórfica, fibrilación ventricular — riesgo de muerte súbita',
    'Evitar combinación. Se necesario, monitorar ECG continuamente. Preferir antibiótico sem efecto QT (amoxicilina, beta-lactâmico)',
    'RIESGO DE TORSADES DE POINTES — Combinación de dois potentes prolongadores de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefFDA]),


  ('amiodarona', 'quetiapina', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT — amiodarona por bloqueio de IKr; quetiapina por bloqueio de canais de Na+/K+',
    'Torsades de Pointes, taquicardia ventricular, morte súbita cardíaca',
    'Evitar combinación. Se necesario, moniorar ECG seriado e electrolitos. Corrija hipopotasemia/hipomagnesemia',
    'RIESGO DE TORSADES DE POINTES — Duplo prolongación de QT com riesgo de muerte súbita',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),


  ('sotalol', 'ciprofloxacino', InteractionSeverity.contraindicated,
    'Ambos prolongam o intervalo QT por bloqueio de canais de potássio (IKr) — efecto aditivo sinérgico',
    'Torsades de Pointes, fibrilación ventricular, morte súbita — riesgo muito elevado',
    'CONTRAINDICADO — No usar ciprofloxacino (ou qualquer quinolona) en pacientes em uso de sotalol. Usar antibiótico alternativo',
    'CONTRAINDICADO — Sotalol + quinolona: riesgo muito alto de torsades de pointes fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefFDA]),


  ('sotalol', 'azitromicina', InteractionSeverity.contraindicated,
    'Ambos prolongam o intervalo QT — sotalol por bloqueio de IKr; azitromicina por mecanismo similar',
    'Torsades de Pointes, taquicardia ventricular polimórfica, morte súbita',
    'CONTRAINDICADO — No usar azitromicina en pacientes em uso de sotalol. Usar amoxicilina ou cefalosporina',
    'CONTRAINDICADO — Sotalol + azitromicina: alto riesgo de torsades de pointes',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefFDA]),


  ('haloperidol', 'ciprofloxacino', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT — haloperidol por bloqueio de IKr; ciprofloxacino por mecanismo similar',
    'Torsades de Pointes, taquicardia ventricular, morte súbita cardíaca',
    'Evitar combinación. Se necesario, monitorar ECG e corrigir electrolitos. Preferir antibiótico sem efecto QT',
    'RIESGO DE TORSADES DE POINTES — Duplo prolongación de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),


  ('quetiapina', 'ciprofloxacino', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT — efecto aditivo',
    'Torsades de Pointes, taquicardia ventricular',
    'Evitar combinación. Monitorar ECG si es inevitable. Corregir hipopotasemia e hipomagnesemia',
    'RIESGO DE TORSADES DE POINTES — Duplo prolongación de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),


  ('quetiapina', 'azitromicina', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT por bloqueio de IKr — efecto aditivo',
    'Torsades de Pointes, taquicardia ventricular',
    'Evitar combinación. Se necesario, monitorar ECG. Preferir amoxicilina ou doxiciclina',
    'RIESGO DE TORSADES DE POINTES — Duplo prolongación de QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),


  ('metadona', 'amiodarona', InteractionSeverity.contraindicated,
    'Ambos prolongam fortemente o intervalo QT — metadona por bloqueio de IKr; amiodarona por múltiplos mecanismos',
    'Torsades de Pointes, fibrilación ventricular, morte súbita — riesgo extremamente alto',
    'CONTRAINDICADO — Não associar. Usar opioide alternativo en pacientes em uso de amiodarona',
    'CONTRAINDICADO — Metadona + amiodarona: riesgo de muerte súbita por arritmia ventricular',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefFDA]),


  ('metadona', 'ciprofloxacino', InteractionSeverity.major,
    'Ciprofloxacino inibe CYP1A2 (metabolismo de la metadona) e prolonga QT — efecto duplo',
    'Elevación dos niveles de metadona + prolongación de QT — Torsades de Pointes, depresión respiratoria',
    'Evitar combinación. Monitorar ECG e sinais de toxicidad por metadona si es inevitable',
    'RISCO DE TORSADES + TOXICIDADE — Ciprofloxacino eleva metadona e ambos prolongam QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── 8. ANTIBIÓTICOS — pares faltantes ─────────────────────────────────────

  ('sulfametoxazol', 'metformina', InteractionSeverity.moderate,
    'Trimetoprima inibe secreção tubular da creatinina — eleva creatinina sérica sem lesão renal real; pode mascarar disfunción renal e levar à manutenção de metformina em dosis excessiva',
    'Elevación falsa de creatinina pode induzir descontinuación inadecuada de metformina ou, ao contrário, mascarar IRA real com acumulación de metformina e acidosis láctica',
    'Monitorar función renal real (cistatina C ou clearance real) durante uso de SMX-TMP en pacientes com metformina',
    'Monitorar función renal — SMX-TMP eleva creatinina sérica independentemente de IRA real',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefUT, _kRefMdx]),


  ('ciprofloxacino', 'metformina', InteractionSeverity.moderate,
    'Ciprofloxacino inibe o transportador OCT2 renal — reduz secreção tubular da metformina',
    'Aumento dos niveles plasmáticos de metformina — riesgo de acidosis láctica',
    'Monitorar función renal durante uso concomitante. Suspender metformina se creatinina elevar ou función renal deteriorar',
    'Monitorar — ciprofloxacino pode elevar niveles de metformina e riesgo de acidosis láctica',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    [_kRefMdx, _kRefUT]),


  ('vancomicina', 'furosemida', InteractionSeverity.major,
    'Furosemida é ototóxica e nefrotóxica; vancomicina também causa nefrotoxicidad — efecto sinérgico',
    'Nefrotoxicidad grave (IRA), ototoxicidad (perda auditiva irreversible)',
    'Monitorar función renal e nivel sérico de vancomicina (AUC/MIC alvo). Evitar furosemida desnecesaria. Manter hidratação adecuada',
    'RIESGO RENAL Y AUDITIVO — Combinación aumenta nefrotoxicidad e ototoxicidad significativamente',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('vancomicina', 'piperacilina-tazobactam', InteractionSeverity.major,
    'Piperacilina-tazobactam aumenta exposición à vancomicina e potencializa nefrotoxicidad por mecanismo não completamente elucidado',
    'Nefrotoxicidad aguda aumentada em 2-3x vs. vancomicina isolada (meta-análises)',
    'Monitorar función renal diariamente. Considerar alternativas (ceftarolina, daptomicina) cuando sea posible. Ajustar dosis de vancomicina por AUC/MIC',
    'NEFROTOXICIDAD AUMENTADA — Pip-tazo + vancomicina: riesgo renal muito elevado',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),


  ('aminoglicosideo', 'cisplatina', InteractionSeverity.major,
    'Ambos são nefrotóxicos e ototóxicos — cisplatina por lesão tubular direta; aminoglicosídeo por acumulación na cóclea e túbulo proximal',
    'Nefrotoxicidad sinérgica grave, ototoxicidad irreversible (surdez)',
    'Evitar combinación si es posible. Se necesario, espaçar administrações, monitorar función renal e audiometría, ajustar dosis por clearance',
    'NEFRO E OTOTOXICIDAD SINÉRGICA — Ambos lesam rins e cóclea; evitar combinación',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── 9. HIPOGLICEMIANTES — pares faltantes ─────────────────────────────────

  ('insulina', 'alcool', InteractionSeverity.major,
    'Álcool inibe gliconeogênese hepática e potencializa o efecto hipoglucemiante da insulina',
    'Hipoglucemia grave prolongada — especialmente noturna; o álcool mascara os sintomas adrenérgicos de hipoglucemia',
    'Alertar al paciente sobre riesgo. Monitorar glucemia. Orientar ingestão de carboidrato junto com bebida alcoólica. Evitar consumo de álcool em jejum',
    'RISCO DE HIPOGLUCEMIA GRAVE — Álcool potencializa insulina e mascara sintomas de hipoglucemia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('metformina', 'alcool', InteractionSeverity.major,
    'Álcool inibe gliconeogênese hepática e aumenta produção de lactato — metformina também inibe gliconeogênese e reduz metabolismo de lactato',
    'Acidosis láctica — especialmente em uso crônico ou ingestão aguda de grande quantidade álcool',
    'Orientar abstinência ou consumo muito moderado. Alertar sobre riesgo de acidosis láctica. Monitorar lactato en pacientes sintomáticos',
    'RISCO DE ACIDOSIS LÁCTICA — Álcool + metformina podem causar acidosis láctica potencialmente fatal',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('sulfonilureia', 'alcool', InteractionSeverity.major,
    'Álcool potencializa efecto hipoglucemiante e inibe gliconeogênese; com algumas sulfonilureias (clorpropamida) causa reacción similar ao dissulfiram',
    'Hipoglucemia grave prolongada; rubor facial, náusea e palpitações (reacción dissulfiram-like com clorpropamida)',
    'Orientar moderação no consumo de álcool. Monitorar glucemia. Evitar jejum prolongado combinado com álcool',
    'RIESGO DE HIPOGLUCEMIA — Álcool potencializa sulfonilureias e pode mascarar sintomas',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('insulina', 'enalapril', InteractionSeverity.moderate,
    'IECAs aumentam sensibilidade à insulina e podem elevar captação periférica de glicose — mecanismo não completamente elucidado',
    'Hipoglucemia — especialmente en diabéticos tipo 1 e pacientes com enfermedad renal',
    'Monitorar glucemia al iniciar IECA en pacientes insulinodependentes. Ajustar dosis de insulina según sea necesario',
    'Monitorar glucemia — IECAs podem aumentar sensibilidade à insulina e riesgo de hipoglucemia',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefMdx, _kRefUT]),


  ('glibenclamida', 'alcool', InteractionSeverity.major,
    'Álcool potencializa efecto hipoglucemiante das sulfonilureias e inibe gliconeogênese hepática',
    'Hipoglucemia grave y prolongada; pode causar reacción dissulfiram-like com rubor, náusea, cefaleia',
    'Orientar evitar álcool em jejum. Monitorar glucemia. Preferir secretagogo com menor riesgo (gliclazida)',
    'RISCO DE HIPOGLUCEMIA GRAVE — Glibenclamida + álcool: hipoglucemia grave e reacción dissulfiram',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── 10. IMUNOSSUPRESSORES — pares faltantes ───────────────────────────────

  ('tacrolimo', 'claritromicina', InteractionSeverity.contraindicated,
    'Claritromicina é potente inhibidora do CYP3A4 — principal enzima de metabolismo del tacrolimo',
    'Elevación de 5-20x nos niveles séricos de tacrolimo — nefrotoxicidad grave, neurotoxicidad, imunossupresión excessiva',
    'CONTRAINDICADO — No usar claritromicina en pacientes com tacrolimo. Usar azitromicina ou amoxicilina. Si inevitable: reduzir tacrolimo drásticamente e monitorar nivel sérico diariamente',
    'CONTRAINDICADO — Claritromicina eleva tacrolimo em 5-20x: nefrotoxicidad e neurotoxicidad graves',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // DUPLICATA REMOVIDA: tacrolimo+fluconazol — par detalhado mantido como fluconazol+tacrolimo (linha ~2541)


  ('tacrolimo', 'rifampicina', InteractionSeverity.contraindicated,
    'Rifampicina induz fortemente CYP3A4 e P-gp — reduz drásticamente os niveles séricos de tacrolimo',
    'Reducción de 80-90% nos niveles de tacrolimo — rechazo agudo do injerto',
    'CONTRAINDICADO — Usar antibiótico alternativo. Se inevitable, aumentar dosis de tacrolimo 3-5x e monitorar nivel sérico diariamente',
    'CONTRAINDICADO — Rifampicina reduz tacrolimo em 80-90%: riesgo de rechazo aguda',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('tacrolimo', 'aine', InteractionSeverity.major,
    'AINEs são nefrotóxicos; tacrolimo já causa nefrotoxicidad — efecto sinérgico na lesão tubular renal',
    'Insuficiencia renal aguda grave — especialmente en pacientes trasplantados',
    'Evitar AINEs en pacientes com tacrolimo. Usar paracetamol como analgésico alternativo. Monitorar función renal si es inevitable',
    'NEFROTOXICIDAD SINÉRGICA — AINEs + tacrolimo: alto riesgo de IRA en pacientes trasplantados',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'aine', InteractionSeverity.major,
    'AINEs reduzem prostaglandinas vasodilatadoras renais; ciclosporina já causa vasoconstrição da arteríola aferente — efecto sinérgico',
    'Insuficiencia renal aguda grave, hipertensão',
    'Evitar AINEs en pacientes com ciclosporina. Usar paracetamol como alternativa. Monitorar función renal e PA',
    'NEFROTOXICIDAD SINÉRGICA — AINEs + ciclosporina: alto riesgo de IRA',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'rifampicina', InteractionSeverity.contraindicated,
    'Rifampicina induz fortemente CYP3A4 e P-gp — metabolismo de la ciclosporina drásticamente aumentado',
    'Reducción de 80-90% nos niveles séricos de ciclosporina — rechazo agudo do injerto',
    'CONTRAINDICADO — Usar antibiótico alternativo. Se inevitable, aumentar dosis de ciclosporina e monitorar nivel sérico diariamente',
    'CONTRAINDICADO — Rifampicina reduz ciclosporina em 80-90%: riesgo de rechazo aguda',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('azatioprina', 'sulfametoxazol', InteractionSeverity.major,
    'SMX-TMP inibe enzimas de metabolismo de la azatioprina e potencializa mielosupresión',
    'Leucopenia grave, pancitopenia — riesgo de infecções oportunistas graves',
    'Monitorar hemograma semanalmente durante uso concomitante. Reducir dosis de azatioprina se leucopenia',
    'MIELOSUPRESIÓN — SMX-TMP + azatioprina: riesgo elevado de leucopenia grave',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.infection},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── 11. ANALGÉSICOS — pares faltantes ────────────────────────────────────

  ('paracetamol', 'alcool', InteractionSeverity.major,
    'Álcool induz CYP2E1 — vía de metabolismo que produz o metabólito hepatotóxico NAPQI; inducción crônica aumenta formação de NAPQI',
    'Hepatotoxicidad grave — insuficiencia hepática fulminante mesmo com dosiss terapéuticas de paracetamol em alcoólicos crônicos',
    'Limitar paracetamol a ≤2 g/dia em usuários crônicos de álcool. Monitorar función hepática. Considerar AINE como alternativa analgésica se función hepática normal',
    'HEPATOTOXICIDAD — Álcool crônico + paracetamol: riesgo de falência hepática mesmo em dosiss terapéuticas',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('tramadol', 'carbamazepina', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e CYP2B6 — aumenta metabolismo del tramadol e reduz seus niveles plasmáticos',
    'Reducción del efecto analgésico do tramadol; posible síndrome de abstinencia em usuários crônicos',
    'Considerar analgésico alternativo. Se necesario manter tramadol, aumentar dosis com cautela e monitorar eficácia analgésica',
    'Reducción del efecto analgésico — carbamazepina reduz niveles de tramadol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── 12. PSICOTRÓPICOS — pares faltantes ──────────────────────────────────

  ('isrs', 'imao reversivel', InteractionSeverity.contraindicated,
    'Inhibición dupla da recaptação e do metabolismo de serotonina — síndrome serotoninérgica',
    'Síndrome serotoninérgica grave: hipertermia, rigidez muscular, mioclonia, alteração do nivel de consciência, instabilidade autonômica',
    'CONTRAINDICADO — Aguardar 14 dias después de suspender IMAO antes de iniciar SSRI; aguardar 5 meias-vidas do SSRI (14 dias para a maioria, 5 semanas para fluoxetina) antes de iniciar IMAO',
    'CONTRAINDICADO — Síndrome serotoninérgica potencialmente fatal; wash-out obligatorio',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefFDA, _kRefUT]),


  ('carbonato de litio', 'aine', InteractionSeverity.major,
    'AINEs inibem síntese de prostaglandinas renais — reduzem excreción renal de lítio, elevando seus niveles séricos',
    'Intoxicación por litio: tremor grosseiro, ataxia, confusão, convulsiones, coma — efecto em 3-5 dias',
    'Evitar AINEs en pacientes com lítio. Usar paracetamol como alternativa analgésica. Se AINE necesario, monitorar lítio sérico em 3-5 dias',
    'INTOXICACIÓN POR LITIO — AINEs elevam lítio sérico em dias; monitorar ou usar paracetamol',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbonato de litio', 'furosemida', InteractionSeverity.major,
    'Furosemida causa depleção de sódio — induz reabsorción tubular compensatória de lítio no túbulo proximal',
    'Elevación dos niveles séricos de lítio — intoxicação: tremor, ataxia, confusão, insuficiencia renal',
    'Monitorar lítio sérico 5-7 dias después de inicio ou aumento de dosis de la furosemida. Ajustar dosis de lítio según sea necesario. Manter hidratação e ingestão de sódio',
    'INTOXICACIÓN POR LITIO — Furosemida eleva lítio sérico; monitorar rigurosamente',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('olanzapina', 'valproato', InteractionSeverity.moderate,
    'Sinergismo farmacológico: ambos têm efecto sedante e podem alterar metabolismo hepático mutualmente',
    'Sedación excesiva, aumento de peso aditivo; casos raros de neutropenia com a combinación',
    'Monitorar sedación, hemograma e peso corporal. Usar dosis mínimas eficazes de ambos',
    'Monitorar sedación, peso e hemograma — sinergismo olanzapina + valproato',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefMdx, _kRefUT]),


  ('carbonato de litio', 'losartana', InteractionSeverity.major,
    'ARA-II reduzem perfusão renal glomerular e excreción de lítio — mecanismo similar ao IECA',
    'Elevación dos niveles séricos de lítio — riesgo de intoxicação: tremor, ataxia, confusão, insuficiencia renal',
    'Monitorar lítio sérico em 5-7 dias al iniciar ARA-II. Ajustar dosis según sea necesario. Manter hidratação',
    'INTOXICACIÓN POR LITIO — ARA-II elevam lítio sérico; monitorar como com IECA',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── 13. ANTIEPILÉPTICOS — pares faltantes ────────────────────────────────

  ('carbamazepina', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 — aumenta metabolismo de la carbamazepina',
    'Reducción dos niveles séricos de carbamazepina — perda do controle de crisis epilépticas',
    'Monitorar nivel sérico de carbamazepina al iniciar rifampicina. Ajustar dosis según sea necesario',
    'RIESGO DE CRISIS — Rifampicina reduz carbamazepina; monitorar niveles séricos',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('fenitoína', 'carbamazepina', InteractionSeverity.moderate,
    'Interacción bidireccional: fenitoína induz CYP3A4 (metabolismo de la carbamazepina); carbamazepina induz CYP2C9 (metabolismo de la fenitoína)',
    'Variação impredecible dos niveles de ambos — tanto aumento quanto diminuição possíveis',
    'Monitorar nivel sérico de ambos os antiepilépticos regularmente. Ajustar dosiss individualmente',
    'Monitorar niveles séricos — interacción bidireccional e impredecible entre fenitoína e carbamazepina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('valproato', 'carbamazepina', InteractionSeverity.moderate,
    'Valproato inibe metabolismo del metabólito ativo da carbamazepina (carbamazepina-10,11-epóxido) — acumulación do metabólito tóxico',
    'Toxicidad por carbamazepina-epóxido: diplopia, ataxia, náusea, tontura — mesmo com nivel sérico de carbamazepina normal',
    'Monitorar síntomas de toxicidad por carbamazepina. Medir nivel do epóxido se disponible. Considerar reducción de carbamazepina',
    'Monitorar toxicidad — valproato acumula metabólito tóxico da carbamazepina mesmo com nivel normal',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── 14. ANTIFÚNGICOS — pares faltantes ───────────────────────────────────

  ('fluconazol', 'midazolam', InteractionSeverity.contraindicated,
    'Fluconazol inibe fortemente CYP3A4 — principal enzima de metabolismo del midazolam',
    'Elevación de 3-5x nos niveles de midazolam — sedación excesiva e prolongada, depresión respiratoria grave',
    'CONTRAINDICADO para midazolam oral. Para midazolam IV em UTI: reducir dosis em 50-75% e monitorar sedación rigurosamente',
    'CONTRAINDICADO via oral — Fluconazol eleva midazolam 3-5x; depresión respiratoria grave',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('fluconazol', 'carbamazepina', InteractionSeverity.moderate,
    'Fluconazol inibe CYP3A4 — eleva niveles séricos de carbamazepina',
    'Toxicidad por carbamazepina: tontura, diplopia, ataxia, hiponatremia',
    'Monitorar nivel sérico de carbamazepina e sintomas de toxicidad al iniciar fluconazol',
    'Monitorar toxicidad — fluconazol eleva carbamazepina por inhibición do CYP3A4',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('fluconazol', 'tacrolimo', InteractionSeverity.contraindicated,
    'Fluconazol inibe CYP3A4 e CYP2C19 — principais enzimas de metabolismo del tacrolimo',
    'Elevación de 3-5x nos niveles séricos de tacrolimo — nefrotoxicidad, neurotoxicidad',
    'CONTRAINDICADO em dosiss plenas — Reduzir tacrolimo drásticamente e monitorar nivel sérico diariamente si es inevitable',
    'CONTRAINDICADO — Fluconazol eleva tacrolimo 3-5x; alto riesgo de nefrotoxicidad',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── 15. CARDIOVASCULAR — pares faltantes ─────────────────────────────────

  ('betabloqueador', 'verapamil', InteractionSeverity.contraindicated,
    'Efecto aditivo en el nodo sinusal y AV: betabloqueador reduz frecuencia e condução; verapamil também — dupla depressão',
    'Bradicardia grave, bloqueo AV completo, asistolia, hipotensión severa, ICC descompensada',
    'CONTRAINDICADO via IV — Para uso oral, apenas sob monitoramento cardíaco rigoroso em situações muito específicas. Evitar na maioria das situações',
    'CONTRAINDICADO IV — Betabloqueador + verapamil IV: riesgo de asistolia e colapso hemodinâmico',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx, _kRefFDA]),


  ('hidroclorotiazida', 'aine', InteractionSeverity.moderate,
    'AINEs antagonizam efecto natriurético dos tiazídicos por inhibición das prostaglandinas renais',
    'Reducción del efecto diurético e anti-hipertensivo; retenção hídrica; posible piora da función renal',
    'Evitar uso crônico concomitante. Monitorar PA e función renal. Preferir paracetamol como analgésico',
    'Monitorar PA e función renal — AINEs reduzem efecto diurético e anti-hipertensivo dos tiazídicos',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT]),

    // NOTA: par furosemida+litio consolidado em carbonato de litio+furosemida (acima, linha ~2467)


  ('digoxina', 'quinolona', InteractionSeverity.moderate,
    'Quinolonas alteram flora intestinal que metaboliza digoxina — em 10% dos pacientes ("metabolizadores por Eggerthella lenta"), quinolonas aumentam absorción de digoxina significativamente',
    'Elevación dos niveles séricos de digoxina em subpopulação específica — toxicidad digitálica',
    'Monitorar nivel sérico de digoxina e sintomas de toxicidad (náusea, bradicardia) al iniciar quinolona',
    'Monitorar nivel de digoxina — quinolonas podem elevar niveles em ~10% dos pacientes',
    EvidenceLevel.probable,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),


  ('clopidogrel', 'morfina', InteractionSeverity.major,
    'Morfina retarda esvaziamento gástrico e absorción de clopidogrel — reduz pico plasmático e concentración máxima',
    'Reducción de 30-50% nos niveles plasmáticos de clopidogrel ativo — inhibición plaquetária subótima durante fase crítica de SCA',
    'Em SCA com morfina: usar ticagrelor ou prasugrel em vez de clopidogrel (não têm essa interacción). Se clopidogrel obligatorio: considerar ticagrelor IV ou cangrelor como ponte',
    'FRACASO ANTIAGREGANTE — Morfina reduz clopidogrel em 30-50%; preferir ticagrelor em SCA',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefUT, _kRefFDA]),

    // ── 16. RESPIRATÓRIO / BRONCODILATADORES ─────────────────────────────────

  ('teofilina', 'eritromicina', InteractionSeverity.major,
    'Eritromicina inibe CYP1A2 e CYP3A4 — principais enzimas de metabolismo de la teofilina',
    'Elevación dos niveles séricos de teofilina — toxicidad: náusea, vômito, taquicardia, convulsiones, arritmias',
    'Reducir dosis de teofilina em 25-50% al iniciar eritromicina. Monitorar nivel sérico de teofilina. Preferir azitromicina (menor interacción)',
    'TOXICIDADE POR TEOFILINA — Eritromicina eleva teofilina; monitorar nivel sérico',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('ritonavir', 'sildenafila', InteractionSeverity.contraindicated,
    'Ritonavir inibe fortemente CYP3A4 — principal vía de metabolismo de la sildenafila',
    'Elevación de 11x nos niveles de sildenafila — hipotensión grave, priapismo, perda visual',
    'CONTRAINDICADO — No usar sildenafila para disfunção erétil en pacientes com ritonavir. Para hipertensão pulmonar: dosis máxima 20 mg/48h com monitoramento rigoroso',
    'CONTRAINDICADO — Ritonavir eleva sildenafila 11x: hipotensión grave e priapismo',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),


  ('ritonavir', 'metadona', InteractionSeverity.major,
    'Ritonavir induz CYP3A4 e CYP2B6 — aumenta metabolismo de la metadona e também prolonga QT',
    'Reducción dos niveles de metadona (síndrome de abstinencia) + riesgo de QT prolongado',
    'Monitorar síntomas de abstinencia al iniciar ritonavir. Ajustar dosis de metadona. Monitorar ECG',
    'RIESGO DE ABSTINENCIA + QT — Ritonavir reduz metadona e ambos prolongam QT',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

    // ── FLUCONAZOL + BENZODIAZEPÍNICOS (par ausente — bug crítico alprazolam+fluconazol) ──

  ('fluconazol', 'benzodiazepínico', InteractionSeverity.major,
    'Fluconazol inibe fortemente CYP3A4 — principal vía de metabolismo de alprazolam, diazepam, clonazepam e lorazepam',
    'Aumento de 2-4x nos niveles plasmáticos de benzodiazepínicos (alprazolam, diazepam, clonazepam). Sedación excesiva, depresión del SNC e riesgo de depresión respiratoria. Lorazepam é menos afetado (metabolismo por glucuronidação).',
    'Monitorar sedación e função respiratória. Reducir dosis do benzodiazepínico em 50% al iniciar fluconazol. Preferir lorazepam cuando sea posible (menos dependente de CYP3A4). Evitar alprazolam e diazepam prolongados com fluconazol sistêmico.',
    'SEDACIÓN AUMENTADA — Fluconazol inibe CYP3A4; reducir dosis do benzodiazepínico em 50%',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),




  ('aspirina', 'aine', InteractionSeverity.major,
    'Competição pelo sítio de ligação da COX-1 plaquetária + inhibición dupla de prostaglandinas protetoras da mucosa gástrica',
    'Antagonismo do efecto cardioprotetor do AAS; riesgo elevado de hemorragia GI',
    'Evitar AINEs não seletivos com AAS. Se analgesia necesaria, preferir paracetamol. Se AINE inevitável, tomar AAS 2h antes e usar IBP',
    'ANTAGONISMO + SANGRADO GI — evitar AINEs com AAS; usar paracetamol',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),


  ('aspirina', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroide reduz protección da mucosa gástrica (diminui prostaglandinas) + AAS inibe COX — efecto duplo lesivo',
    'Riesgo muy elevado de úlcera péptica y hemorragia GI',
    'Associar IBP obligatoriamente. Minimizar dosis e duración do corticosteroide. Monitorar síntomas GI',
    'ALTO RIESGO GI — AAS + corticosteroide: IBP obligatorio',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('aspirina', 'metotrexato', InteractionSeverity.major,
    'AAS reduz excreción renal e tubular do metotrexato por competição',
    'Elevación dos niveles de metotrexato — toxicidad hematológica, mucosites, nefrotoxicidad',
    'Evitar em dosis altas de metotrexato. Em baixas dosiss (artrite), monitorar hemograma e función renal',
    'TOXICIDADE DE METOTREXATO — AAS reduz aclaramiento renal; monitorar',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('aspirina', 'carbonato de litio', InteractionSeverity.moderate,
    'AAS pode interferir levemente na excreción renal de lítio via prostaglandinas renais',
    'Elevación modesta dos niveles séricos de lítio',
    'Monitorar litemia al iniciar ou aumentar dosis de AAS en pacientes com lítio',
    'Monitorar litemia — AAS pode elevar lítio levemente',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG]),


  ('aspirina', 'metformina', InteractionSeverity.minor,
    'AAS pode potencializar levemente o efecto hipoglucemiante da metformina',
    'Hipoglucemia leve em dosis altas de AAS (>3 g/dia)',
    'Sem restrição em dosiss cardioprotetoras (≤100 mg/dia). Monitorar glucemia se dosiss analgésicas elevadas',
    'Dosis altas de AAS podem aumentar efecto hipoglucemiante',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG]),


  ('apixabana', 'heparina', InteractionSeverity.contraindicated,
    'Doble anticoagulación: inhibición fator Xa (apixabana) + inhibición múltipla da cascata (heparina)',
    'Riesgo extremo de hemorragia grave',
    'CONTRAINDICADO em uso concomitante. Usar apenas em transição monitorada (bridging). Nunca usar simultáneamente em dosis plena',
    'CONTRAINDICADO — doble anticoagulación plena: riesgo de hemorragia fatal',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('apixabana', 'warfarina', InteractionSeverity.contraindicated,
    'Doble anticoagulación: inhibición fator Xa + inhibición vitamina K',
    'Riesgo extremo de hemorragia grave',
    'CONTRAINDICADO. Nunca usar juntos. Na transição warfarina → apixabana, suspender warfarina e iniciar apixabana quando INR <2,0',
    'CONTRAINDICADO — doble anticoagulación plena',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefFDA]),


  ('apixabana', 'dabigatrana', InteractionSeverity.contraindicated,
    'Doble anticoagulación com dois mecanismos distintos — riesgo hemorrágico extremo',
    'Hemorragia fatal',
    'CONTRAINDICADO. Nunca usar dois anticoagulantes de ação direta simultáneamente',
    'CONTRAINDICADO — dois anticoagulantes diretos juntos',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('apixabana', 'rivaroxabana', InteractionSeverity.contraindicated,
    'Dois inhibidores do fator Xa — anticoagulação excessiva',
    'Hemorragia grave',
    'CONTRAINDICADO. Nunca combinar dois inhibidores do fator Xa',
    'CONTRAINDICADO — dois inhibidores do fator Xa',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('apixabana', 'fondaparinux', InteractionSeverity.contraindicated,
    'Dois inhibidores do fator Xa por mecanismos distintos — anticoagulação excessiva',
    'Riesgo muito elevado de hemorragia',
    'CONTRAINDICADO em uso concomitante pleno. Evitar sobreposição',
    'CONTRAINDICADO — dupla inhibición fator Xa',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('dabigatrana', 'heparina', InteractionSeverity.contraindicated,
    'Inhibición direta da trombina (dabigatrana) + anticoagulação múltipla (heparina) — doble anticoagulación',
    'Riesgo extremo de hemorragia grave',
    'CONTRAINDICADO em uso simultâneo pleno. Apenas em transições controladas (suspender heparina antes de iniciar dabigatrana)',
    'CONTRAINDICADO — doble anticoagulación plena',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('dabigatrana', 'warfarina', InteractionSeverity.contraindicated,
    'Doble anticoagulación por mecanismos distintos',
    'Riesgo extremo de hemorragia',
    'CONTRAINDICADO. Na transição, iniciar dabigatrana quando INR <2,0 después de suspensión de warfarina',
    'CONTRAINDICADO — doble anticoagulación',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefFDA]),


  ('dabigatrana', 'rivaroxabana', InteractionSeverity.contraindicated,
    'Dois anticoagulantes de ação direta com mecanismos distintos',
    'Hemorragia grave',
    'CONTRAINDICADO. Nunca combinar dois anticoagulantes diretos',
    'CONTRAINDICADO — dois anticoagulantes diretos',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('dabigatrana', 'fondaparinux', InteractionSeverity.contraindicated,
    'Inhibición trombina + inhibición fator Xa — doble anticoagulación',
    'Hemorragia grave',
    'CONTRAINDICADO em uso simultâneo pleno',
    'CONTRAINDICADO — doble anticoagulación',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('dabigatrana', 'clopidogrel', InteractionSeverity.major,
    'Anticoagulação direta (trombina) + antiagregação P2Y12 — sinergia hemorrágica',
    'Aumento significativo do riesgo de sangrado maior',
    'Usar somente quando indicação estabelecida. Usar IBP. Período mínimo de terapia combinada',
    'SANGRADO AUMENTADO — dabigatrana + clopidogrel: usar IBP',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('heparina', 'warfarina', InteractionSeverity.moderate,
    'Doble anticoagulación — usada intencionalmente em transição, mas com riesgo hemorrágico aditivo',
    'Hemorragia se sobreposição prolongada ou INR supraterapéutico',
    'Sobreposição de 5 dias com INR >2,0 por 2 dias consecutivos antes de suspender heparina. Monitorar TTPA e INR',
    'TRANSIÇÃO CONTROLADA — sobreposição 5 dias; suspender heparina quando INR ≥2,0',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('heparina', 'clopidogrel', InteractionSeverity.major,
    'Anticoagulação (heparina) + antiagregação P2Y12 (clopidogrel) — sinergia hemorrágica',
    'Aumento do riesgo de sangrado maior, especialmente em procedimientos invasivos',
    'Combinación usada em SCA — monitorar ativamente. Cessar heparina quando clinicamente posible',
    'SANGRADO AUMENTADO — heparina + clopidogrel: monitorar em SCA',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('heparina', 'rivaroxabana', InteractionSeverity.contraindicated,
    'Dois anticoagulantes com mecanismos distintos — doble anticoagulación',
    'Hemorragia grave',
    'CONTRAINDICADO em uso simultâneo pleno. Apenas em transição controlada',
    'CONTRAINDICADO — doble anticoagulación plena',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('heparina', 'fondaparinux', InteractionSeverity.contraindicated,
    'Dois anticoagulantes com ação anti-Xa — anticoagulação excessiva',
    'Hemorragia grave',
    'CONTRAINDICADO em uso simultâneo',
    'CONTRAINDICADO — dois anticoagulantes anti-Xa',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('rivaroxabana', 'warfarina', InteractionSeverity.contraindicated,
    'Dois anticoagulantes por mecanismos distintos — doble anticoagulación',
    'Hemorragia grave',
    'CONTRAINDICADO. Na transição rivaroxabana → warfarina, manter rivaroxabana até INR ≥2,0',
    'CONTRAINDICADO — doble anticoagulación',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefFDA]),


  ('rivaroxabana', 'fondaparinux', InteractionSeverity.contraindicated,
    'Dois inhibidores do fator Xa — anticoagulação excessiva',
    'Hemorragia grave',
    'CONTRAINDICADO em uso simultâneo',
    'CONTRAINDICADO — dois inhibidores fator Xa',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('fondaparinux', 'warfarina', InteractionSeverity.major,
    'Inhibición fator Xa (fondaparinux) + inhibición vitamina K (warfarina) — anticoagulação aditiva',
    'Hemorragia grave se sobreposição prolongada',
    'Usar somente em transição controlada. Monitorar INR e ajustar fondaparinux conforme protocolo',
    'ANTICOAGULACIÓN ADITIVA — transição controlada somente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('fondaparinux', 'clopidogrel', InteractionSeverity.major,
    'Anticoagulação + antiagregação — sinergia hemorrágica',
    'Aumento do riesgo de sangrado maior',
    'Monitorar ativamente. Usar somente quando indicação estabelecida',
    'SANGRADO AUMENTADO — fondaparinux + clopidogrel',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG]),


  ('clopidogrel', 'aine', InteractionSeverity.major,
    'Antiagregação + lesão mucosa e inhibición plaquetária pelos AINEs',
    'Hemorragia GI aumentada',
    'Evitar AINEs. Usar paracetamol. Se AINE inevitável, associar IBP',
    'SANGRADO GI AUMENTADO — evitar AINEs com clopidogrel',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('clopidogrel', 'fluoxetina', InteractionSeverity.moderate,
    'Fluoxetina inibe CYP2C19 — reduz ativação do clopidogrel',
    'Posible reducción del efecto antiagregante',
    'Preferir sertralina ou escitalopram (menor inhibición de CYP2C19) en pacientes com clopidogrel',
    'REDUCCIÓN ANTIAGREGANTE — preferir sertralina ao usar clopidogrel',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'betabloqueador', InteractionSeverity.major,
    'Efecto aditivo en el nodo sinusal y AV — amiodarona já prolonga período refratário + betabloqueador reduz FC e condução',
    'Bradicardia grave, bloqueo AV de alto grau, asistolia',
    'Monitorar ECG continuamente. Evitar combinación IV simultânea. Se oral, titulación lenta com monitoramento cardíaco',
    'BRADICARDIA GRAVE — amiodarona + betabloqueador: monitorar ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'diltiazem', InteractionSeverity.major,
    'Efecto aditivo no nó AV — amiodarona e diltiazem ambos deprimem condução AV',
    'Bloqueo AV completo, bradicardia grave, hipotensión',
    'Evitar combinación. Se necesario, monitorar ECG continuamente e ter marca-passo disponible',
    'BLOQUEO AV — amiodarona + diltiazem: monitorar ECG rigurosamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'propranolol', InteractionSeverity.major,
    'Amiodarona inibe CYP2D6 → eleva nivel de propranolol + efecto aditivo cronotrópico negativo',
    'Bradicardia grave, bloqueo AV, hipotensión',
    'Reducir dosis de propranolol. Monitorar FC e presión arterial',
    'BRADICARDIA — amiodarona eleva propranolol via CYP2D6',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'ondansetrona', InteractionSeverity.major,
    'Prolongación aditiva del QT — amiodarona (classe III) + ondansetrona (bloqueio canal hERG)',
    'Torsades de Pointes',
    'Evitar combinación. Se uso necesario, monitorar QTc. Sustituir por metoclopramida ou domperidona',
    'PROLONGACIÓN QT — amiodarona + ondansetrona: monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'fenitoína', InteractionSeverity.major,
    'Amiodarona inibe CYP2C9 → eleva nivel de fenitoína; fenitoína induz CYP3A4 → reduz nivel de amiodarona',
    'Toxicidad por fenitoína (nistagmo, ataxia, confusão) e posible reducción de la eficácia da amiodarona',
    'Monitorar nivel sérico de fenitoína. Reducir dosis de fenitoína em 30-50% al iniciar amiodarona',
    'TOXICIDAD DE FENITOÍNA — amiodarona eleva via CYP2C9; monitorar nivel',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'levotiroxina', InteractionSeverity.major,
    'Amiodarona inibe conversão periférica de T4 em T3 e contém 37% de iodo — interfere profundamente na función tiroidiana',
    'Hipotiroidismo ou hipertiroidismo induzido pela amiodarona — ambos com riesgo cardíaco',
    'Monitorar TSH, T4 livre e T3 a cada 6 meses. Ajustar levotiroxina conforme función tiroidiana. Acompanhamento com endocrinologia',
    'DISFUNCIÓN TIROIDIANA — monitorar TSH/T4 a cada 6 meses',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'ciclosporina', InteractionSeverity.major,
    'Amiodarona inibe CYP3A4 e P-gp — aumenta nivel de ciclosporina',
    'Nefrotoxicidad, neurotoxicidad por elevación de ciclosporina',
    'Reducir dosis de ciclosporina. Monitorar nivel sérico e función renal',
    'TOXICIDAD CICLOSPORINA — amiodarona eleva via CYP3A4/P-gp',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('amiodarona', 'metformina', InteractionSeverity.minor,
    'Amiodarona pode alterar levemente a función renal — riesgo de acumulación de metformina',
    'Riesgo teórico de acidosis láctica em disfunción renal',
    'Monitorar función renal periodicamente en pacientes com amiodarona e metformina',
    'Monitorar función renal — amiodarona pode afetar clearance de metformina',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),


  ('betabloqueador', 'diltiazem', InteractionSeverity.major,
    'Efecto aditivo na depressão do nó sinusal e AV — betabloqueador + diltiazem (bloqueador canal Ca não-DHP)',
    'Bradicardia grave, bloqueo AV de 2º/3º grau, hipotensión, ICC descompensada',
    'Contraindicado por via IV simultânea. Oral com monitoramento cardíaco. ECG antes e después de inicio',
    'BRADICARDIA/BLOQUEO AV — evitar combinación IV; monitorar ECG se oral',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('betabloqueador', 'sotalol', InteractionSeverity.major,
    'Sotalol tem propriedades betabloqueadoras + prolongamento QT — efecto aditivo com betabloqueador',
    'Bradicardia, bloqueo AV, prolongamento QT, Torsades de Pointes',
    'Evitar combinación. Se necesario, monitorar ECG e FC continuamente',
    'BRADICARDIA + PROLONGACIÓN QT — evitar betabloqueador + sotalol',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('betabloqueador', 'clonidina', InteractionSeverity.major,
    'Na retirada abrupta de clonidina com betabloqueador em uso, há hipertensão de rebote grave — betabloqueador bloqueia vasodilatação beta-mediada',
    'Crisis hipertensiva grave na retirada de clonidina',
    'Retirar betabloqueador antes de descontinuar clonidina. Nunca suspender clonidina abruptamente',
    'CRISIS HIPERTENSIVA — retirar betabloqueador ANTES de suspender clonidina',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('betabloqueador', 'alfa-bloqueador', InteractionSeverity.moderate,
    'Bloqueio alfa (vasodilatação periférica) + bloqueio beta (impede taquicardia reflexa compensatória)',
    'Hipotensión ortostática grave, síncope — especialmente na primeira dosis',
    'Iniciar alfa-bloqueador com dosis baja. Monitorar PA después de primeira dosis. Orientar al paciente sobre riesgo de síncope',
    'HIPOTENSIÓN ORTOSTÁTICA — iniciar alfa-bloqueador com dosis mínima',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('betabloqueador', 'nitrato', InteractionSeverity.moderate,
    'Vasodilatação pelo nitrato + reducción de la taquicardia reflexa pelo betabloqueador — efecto hemodinâmico aditivo',
    'Hipotensión sinérgica, tontura, síncope',
    'Combinación generalmente benéfica em angina. Titular dosis com monitoramento de PA. Orientar mudança postural lenta',
    'HIPOTENSIÓN ADITIVA — monitorar PA; combinación útil em angina',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG]),


  ('betabloqueador', 'sildenafila', InteractionSeverity.moderate,
    'Sildenafila causa vasodilatação; betabloqueador bloqueia taquicardia reflexa compensatória',
    'Hipotensión sintomática, tontura, síncope',
    'Monitorar PA. Evitar uso próximo ao horário do betabloqueador. Cautela en pacientes com IC',
    'HIPOTENSIÓN — monitorar PA com betabloqueador + sildenafila',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'diltiazem', InteractionSeverity.moderate,
    'Diltiazem inibe P-gp → aumenta nivel de digoxina + efecto aditivo no nó AV',
    'Toxicidad por digoxina e bradicardia',
    'Monitorar nivel sérico de digoxina al iniciar diltiazem. Reducir dosis de digoxina se necesario',
    'TOXICIDADE DIGOXINA — diltiazem eleva via P-gp; monitorar nivel',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'betabloqueador', InteractionSeverity.major,
    'Efecto aditivo no nó AV — digoxina (vagotônico) + betabloqueador (cronotrópico negativo)',
    'Bradicardia grave, bloqueo AV de alto grau',
    'Monitorar FC e ECG. Titular dosis. Evitar combinación em disfunção sinusal',
    'BRADICARDIA/BLOQUEO AV — digoxina + betabloqueador: monitorar ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'metoprolol', InteractionSeverity.major,
    'Efecto aditivo cronotrópico negativo no nó sinusal e AV',
    'Bradicardia grave, bloqueo AV',
    'Monitorar FC e ECG. Manter FC >50 bpm. Titular dosis gradualmente',
    'BRADICARDIA — digoxina + metoprolol: manter FC >50 bpm',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'aine', InteractionSeverity.moderate,
    'AINEs reduzem filtração glomerular → diminuem aclaramiento renal da digoxina',
    'Elevación do nivel sérico de digoxina — toxicidad',
    'Evitar AINEs en pacientes com digoxina. Usar paracetamol. Se AINE necesario, monitorar nivel de digoxina',
    'TOXICIDADE DIGOXINA — AINEs reduzem aclaramiento renal',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),


  ('digoxina', 'carbonato de litio', InteractionSeverity.moderate,
    'Depleção de sódio pelo lítio e alterações renais podem elevar nivel de digoxina',
    'Toxicidad por digoxina',
    'Monitorar nivel sérico de digoxina e ECG quando usar com lítio',
    'Monitorar digoxina — lítio pode elevar nivel sérico',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG]),


  ('diltiazem', 'sinvastatina', InteractionSeverity.major,
    'Diltiazem inibe CYP3A4 — aumenta AUC da sinvastatina em 3-4x',
    'Riesgo elevado de miopatía e rabdomiólisis',
    'Limitar sinvastatina a 10 mg/dia com diltiazem. Preferir pravastatina ou rosuvastatina',
    'RISCO DE RABDOMIÓLISIS — limitar sinvastatina a 10mg/dia',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('diltiazem', 'ciclosporina', InteractionSeverity.major,
    'Diltiazem inibe CYP3A4 → aumenta nivel de ciclosporina em 30-50%',
    'Nefrotoxicidad, neurotoxicidad por hiperciclosporinemia',
    'Monitorar nivel sérico de ciclosporina. Reducir dosis de ciclosporina',
    'TOXICIDAD CICLOSPORINA — diltiazem eleva via CYP3A4',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('diltiazem', 'midazolam', InteractionSeverity.moderate,
    'Diltiazem inibe CYP3A4 — aumenta nivel de midazolam',
    'Sedación excesiva e prolongada',
    'Reducir dosis de midazolam. Monitorar nivel de consciência',
    'SEDACIÓN AUMENTADA — diltiazem eleva midazolam via CYP3A4',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('diltiazem', 'carbamazepina', InteractionSeverity.major,
    'Diltiazem inibe CYP3A4 → eleva carbamazepina; carbamazepina induz CYP3A4 → reduz diltiazem',
    'Toxicidad por carbamazepina (diplopia, ataxia) + reducción de la eficácia do diltiazem',
    'Monitorar nivel de carbamazepina. Considerar alternativa ao diltiazem',
    'TOXICIDADE CARBAMAZEPINA — diltiazem inibe metabolismo; monitorar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),


  ('dronedarona', 'betabloqueador', InteractionSeverity.major,
    'Dronedarona tem leve ação betabloqueadora + efecto aditivo com betabloqueador na depressão do nó AV',
    'Bradicardia grave, bloqueo AV',
    'Monitorar ECG. Iniciar betabloqueador com dosis baja. Manter FC >50 bpm',
    'BRADICARDIA — dronedarona + betabloqueador: monitorar FC e ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('dronedarona', 'diltiazem', InteractionSeverity.major,
    'Dronedarona inibe CYP3A4 e também tem efecto no nó AV; diltiazem inibe CYP3A4 eleva dronedarona + efecto aditivo AV',
    'Bradicardia grave, bloqueo AV, prolongamento QT',
    'Evitar combinación. Se necesario, monitorar ECG continuamente',
    'BLOQUEO AV + BRADICARDIA — evitar dronedarona + diltiazem',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('nitrato', 'alfa-bloqueador', InteractionSeverity.major,
    'Dupla vasodilatação — nitrato (venodilatação) + alfa-bloqueador (vasodilatação arterial)',
    'Hipotensión grave, síncope ortostática',
    'Iniciar alfa-bloqueador com dosis mínima. Monitorar PA. Evitar combinación em hipotensión basal',
    'HIPOTENSIÓN GRAVE — nitrato + alfa-bloqueador: monitorar PA',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),


  ('nitrato', 'alcool', InteractionSeverity.major,
    'Álcool causa vasodilatação + nitrato é vasodilatador — efecto hemodinâmico aditivo',
    'Hipotensión grave, síncope, taquicardia reflexa',
    'Evitar álcool durante uso de nitratos. Orientar al paciente sobre riesgo de síncope',
    'HIPOTENSIÓN — evitar álcool com nitratos',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG]),


  ('sotalol', 'haloperidol', InteractionSeverity.major,
    'Dois prolongadores de QT por bloqueio de canais hERG — efecto aditivo',
    'Torsades de Pointes, fibrilación ventricular',
    'Evitar. Se necesario, monitorar QTc rigurosamente. Medir K+ e Mg2+',
    'TORSADES DE POINTES — sotalol + haloperidol: monitorar QTc',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('sotalol', 'ondansetrona', InteractionSeverity.major,
    'Prolongación aditiva del QT',
    'Torsades de Pointes',
    'Evitar. Preferir metoclopramida como antiemético alternativo',
    'TORSADES DE POINTES — sotalol + ondansetrona: evitar',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('sotalol', 'quetiapina', InteractionSeverity.major,
    'Dois prolongadores de QT — efecto aditivo',
    'Torsades de Pointes, morte súbita',
    'Evitar. Monitorar QTc se combinación inevitável. Suspender se QTc >500ms',
    'TORSADES DE POINTES — evitar sotalol + quetiapina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('sotalol', 'diurético', InteractionSeverity.major,
    'Diuréticos causam hipopotasemia e hipomagnesemia — potencializam o prolongación de QT pelo sotalol',
    'Torsades de Pointes precipitada por trastorno electrolítico',
    'Monitorar K+ e Mg2+ séricos antes e durante uso de sotalol. Corregir hipopotasemia antes de iniciar',
    'TORSADES — corrigir K+ e Mg2+ antes de iniciar sotalol',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.hypokalemia},
    [_kRefGG, _kRefMdx]),


  ('verapamil', 'sinvastatina', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 — aumenta AUC da sinvastatina em 4-5x',
    'Riesgo muito elevado de rabdomiólisis',
    'Limitar sinvastatina a 10 mg/dia. Preferir pravastatina ou rosuvastatina',
    'RISCO DE RABDOMIÓLISIS — limitar sinvastatina a 10mg/dia',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('verapamil', 'ciclosporina', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 e P-gp → eleva nivel de ciclosporina',
    'Nefrotoxicidad por hiperciclosporinemia',
    'Monitorar nivel sérico de ciclosporina. Reducir dosis',
    'TOXICIDAD CICLOSPORINA — verapamil eleva via CYP3A4/P-gp',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('verapamil', 'carbamazepina', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 → eleva carbamazepina; carbamazepina induz CYP3A4 → reduz verapamil',
    'Toxicidad por carbamazepina + reducción de la eficácia do verapamil',
    'Monitorar nivel de carbamazepina. Considerar alternativa',
    'TOXICIDADE CARBAMAZEPINA — verapamil inibe metabolismo',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),


  ('verapamil', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz fortemente CYP3A4 e P-gp → reduz biodisponibilidad oral do verapamil em >90%',
    'Perda completa do efecto do verapamil — angina descontrolada, arritmias',
    'Evitar combinación. Usar antiarrítmico alternativo durante rifampicina',
    'INEFICACIA TOTAL — rifampicina elimina efecto do verapamil; evitar',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('metoprolol', 'fluoxetina', InteractionSeverity.major,
    'Fluoxetina inibe CYP2D6 — aumenta nivel de metoprolol em 4-6x',
    'Bradicardia grave, bloqueo AV, hipotensión',
    'Reducir dosis de metoprolol. Monitorar FC e PA. Preferir sertralina (menor inhibición CYP2D6)',
    'BRADICARDIA — fluoxetina eleva metoprolol 4-6x via CYP2D6',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('ivabradina', 'betabloqueador', InteractionSeverity.major,
    'Ivabradina inibe canal If do nó sinusal + betabloqueador também reduz FC — efecto aditivo cronotrópico negativo',
    'Bradicardia grave sintomática',
    'Monitorar FC. Manter FC >50 bpm. Titular dosis. Combinación pode ser usada com cautela em angina refratária',
    'BRADICARDIA — ivabradina + betabloqueador: manter FC >50 bpm',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('ivabradina', 'metoprolol', InteractionSeverity.major,
    'Dois agentes cronotrópicos negativos — efecto aditivo no nó sinusal',
    'Bradicardia grave',
    'Monitorar FC continuamente. Manter FC >50 bpm. Combinación pode ser útil em IC com FC elevada',
    'BRADICARDIA — ivabradina + metoprolol: monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('esmolol', 'digoxina', InteractionSeverity.major,
    'Efecto aditivo na depressão do nó AV — esmolol (betabloqueador IV) + digoxina',
    'Bradicardia grave, bloqueo AV',
    'Monitorar ECG continuamente. Usar com cautela em procedimientos. Ter atropina disponible',
    'BRADICARDIA/BLOQUEO AV — esmolol + digoxina: monitorar ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('esmolol', 'diltiazem', InteractionSeverity.major,
    'Dupla depressão do nó AV — esmolol (betabloqueador IV) + diltiazem',
    'Bradicardia grave, bloqueo AV completo, hipotensión',
    'CONTRAINDICADO IV simultâneo. Monitorar ECG e PA rigurosamente',
    'CONTRAINDICADO IV — esmolol + diltiazem: asistolia posible',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

    // ── FLUCONAZOL (inhibidor CYP3A4/2C9/2C19) ──────────────────────────────

  ('fluconazol', 'rifampicina', InteractionSeverity.major,
    'Rifampicina é potente inductor de CYP3A4 e CYP2C9, as principais vías de metabolismo del fluconazol. Reduz significativamente os niveles plasmáticos do antifúngico',
    'Reducción de 25-50% na AUC do fluconazol → fracaso terapéutico antifúngica, especialmente crítica em candidemia e meningite criptocócica',
    'Evitar combinación cuando sea posible. Si es indispensable: aumentar dosis del fluconazol (até 800mg/dia monitorando toxicidad) ou sustituir por anfotericina B. Monitorar respuesta clínica e marcadores fúngicos',
    'EFICACIA REDUCIDA — Rifampicina induz CYP; considerar aumentar dosis fluconazol ou trocar antifúngico',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fluconazol', 'fenobarbital', InteractionSeverity.moderate,
    'Fenobarbital induz CYP2C9 e CYP3A4, reduzindo os niveles de fluconazol. Efecto inverso também ocorre: fluconazol inibe CYP2C9, podendo aumentar niveles de fenobarbital',
    'Reducción de la eficacia antifúngica por inducción enzimática. Riesgo de toxicidad por fenobarbital (sedación, ataxia) por inhibición do seu metabolismo',
    'Monitorar respuesta antifúngica e ajustar dosis do fluconazol según sea necesario. Monitorar signos de toxicidad por fenobarbital (sedación excesiva, ataxia)',
    'INTERACCIÓN BIDIRECCIONAL — Monitorar eficácia antifúngica e toxicidad de fenobarbital',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fluconazol', 'eritromicina', InteractionSeverity.moderate,
    'Ambos prolongam o intervalo QT por mecanismos distintos. Eritromicina bloqueia canais IKr (hERG) e fluconazol prolonga o QT por inhibición do CYP3A4 (podendo elevar niveles da própria eritromicina)',
    'Riesgo aditivo/sinérgico de prolongación del QTc e torsades de pointes, especialmente en pacientes com hipopotasemia, hipomagnesemia ou QT basal prolongado',
    'Monitorar ECG (QTc). Corrigir electrolitos antes e durante uso. Evitar en pacientes com QT basal > 450ms. Considerar azitromicina (menor riesgo de QT) si es posible',
    'PROLONGACIÓN QT ADITIVO — Monitorar ECG e electrolitos; evitar se QTc > 450ms',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('fluconazol', 'claritromicina', InteractionSeverity.moderate,
    'Fluconazol inibe CYP3A4, reduzindo o metabolismo de la claritromicina. Ambos prolongam o QTc por mecanismos complementares',
    'Aumento dos niveles de claritromicina → toxicidad gastrointestinal e riesgo aumentado de prolongación QTc. Riesgo aditivo de torsades',
    'Monitorar ECG (QTc), especialmente en ancianos e pacientes com cardiopatia. Corregir hipopotasemia e hipomagnesemia. Considerar alternativa (azitromicina) se QTc > 450ms',
    'PROLONGACIÓN QT + NÍVEIS AUMENTADOS — Monitorar ECG; corrigir electrolitos',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fluconazol', 'ritonavir', InteractionSeverity.moderate,
    'Interacción bidireccional complexa: ritonavir inibe CYP3A4 (pode aumentar fluconazol); fluconazol inibe CYP3A4 (pode aumentar ritonavir). Ambos prolongam QTc',
    'Riesgo de toxicidad mútua por inhibición enzimática bidirecional. Riesgo aumentado de prolongación QTc',
    'Monitorar ECG e parâmetros hepáticos. Em TARV, preferir voriconazol ou anidulafungina quando disponible. Ajustar dosiss com base em monitoramento clínico',
    'INIBIÇÃO BIDIRECIONAL CYP3A4 — Monitorar ECG, hepatotoxicidad e resposta clínica',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── RIFAMPICINA (inductor potente CYP1A2/2C9/2C19/3A4/P-gp) ──────────────

  ('rifampicina', 'estatina', InteractionSeverity.major,
    'Rifampicina induz fortemente CYP3A4 (sinvastatina, atorvastatina, lovastatina) e transportadores OATP1B1/1B3 (rosuvastatina, pravastatina). Reduz drásticamente os niveles plasmáticos de todas as estatinas',
    'Reducción de 80-90% nas concentraciones de sinvastatina e atorvastatina. Riesgo de fallo en el control lipídico e cardiovascular durante tratamiento com rifampicina',
    'Suspender estatinas durante tratamiento com rifampicina cuando sea posible. Se imprescindível: aumentar dosis de la estatina (com cautela pelo efecto rebote al suspender rifampicina). Monitorar perfil lipídico',
    'EFICACIA DRÁSTICAMENTE REDUCIDA — Rifampicina reduz 80-90% dos niveles de estatinas; suspender ou ajustar dosis',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'isrs', InteractionSeverity.major,
    'Rifampicina induz CYP2C19 e CYP2D6, as principais vías de metabolismo de citalopram, escitalopram, sertralina, paroxetina e fluoxetina. Pode reduzir niveles em 50-70%',
    'Reducción significativa dos niveles do ISRS → riesgo de fracaso terapéutica e recurrencia de depressão ou transtorno de ansiedade durante tratamiento antituberculoso',
    'Monitorar respuesta clínica ao ISRS. Pode ser necesario aumentar dosis del antidepresivo. Reavaliar dosis al suspender rifampicina (riesgo de toxicidad por acumulación)',
    'EFICACIA REDUCIDA — Rifampicina induz metabolismo de ISRSs; monitorar e ajustar dosis do antidepresivo',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'metadona', InteractionSeverity.major,
    'Rifampicina é inductor potente de CYP3A4 e CYP2B6, as principais vías de metabolismo de la metadona. Reduz os niveles em 50-80%',
    'Reducción grave dos niveles de metadona → síndrome de abstinencia opiácea grave, riesgo de recaída en pacientes em programa de sustitución opiácea. Inicio rápido (2-5 dias)',
    'Evitar combinación. Si inevitable: aumentar dosis de metadona gradualmente (pode ser necesario dobrar), monitorar diariamente signos de abstinencia. Al suspender rifampicina, reduzir metadona gradualmente para evitar superdosis',
    'ABSTINENCIA OPIOIDE GRAVE — Rifampicina reduz metadona 50-80%; aumentar dosis e monitorar diariamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'opioide', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 e CYP2D6, reduzindo os niveles de morfina, codeína, oxicodona, fentanila e tramadol. A morfina (glucuronidação) é menos afetada que opioides com metabolismo hepático CYP',
    'Reducción de la analgesia → dolor no controlado, riesgo de subdosis em cuidados paliativos e pós-operatório. Ao cessar rifampicina, riesgo de superdosis por acumulación',
    'Monitorar control del dolor e aumentar dosis del opioide según sea necesario. Preferir morfina (metabolismo por glucuronidação, menos afetada). Reducir dosis de opioides al suspender rifampicina',
    'ANALGESIA REDUZIDA — Rifampicina induz CYP; preferir morfina e monitorar control del dolor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'anticonceptivo', InteractionSeverity.major,
    'Rifampicina induz potentemente CYP3A4 e UGT, acelerando o metabolismo de etinilestradiol e progestágenos. Efecto começa em 1-2 semanas e persiste até 4-8 semanas después de a suspensión',
    'Reducción de 50-80% nos niveles hormonais → fracaso contraceptivo (embarazo no planificado), especialmente com anticoncepcionais de baixa dosis',
    'CONTRAINDICADO usar rifampicina com anticoncepción hormonal oral/patch/anel como único método. Usar método de barrera durante o tratamiento e por 4-8 semanas después de. Considerar DIU de cobre como alternativa confiável',
    'FRACASO CONTRACEPTIVO — Rifampicina reduz hormônios em 50-80%; usar método de barrera + adicional',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'benzodiazepínico', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 (principal vía de metabolismo de alprazolam, diazepam, clonazepam, triazolam, midazolam). Reduz os niveles em 50-90%',
    'Reducción grave da eficácia ansiolítica/sedativa → ansiedade não controlada, insônia, posible síndrome de abstinencia em uso crônico',
    'Aumentar dosis del benzodiazepínico conforme resposta clínica. Preferir lorazepam (glucuronidação, menos afetado). Monitorar síntomas de abstinencia e ansiedade',
    'EFICACIA REDUCIDA — Rifampicina induz CYP3A4; preferir lorazepam e monitorar respuesta clínica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'quetiapina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4, a principal vía de metabolismo de la quetiapina. Estudos mostram reducción de até 80% na AUC da quetiapina',
    'Fracaso en el control psiquiátrico (psicose, mania, depressão bipolar) por niveles subterapéuticos de quetiapina',
    'Evitar combinación. Se necesario: aumentar dosis de quetiapina substancialmente (guideline sugere 5-7x a dosis usual). Monitorar respuesta clínica e efectos adversos',
    'EFICACIA REDUCIDA — Rifampicina reduz quetiapina em até 80%; aumento substancial de dosis necesario',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'haloperidol', InteractionSeverity.moderate,
    'Rifampicina induz CYP3A4 e glicuronidação, reduzindo os niveles plasmáticos do haloperidol em 50-70%',
    'Posible fracaso en el control antipsicótico → recurrencia de síntomas psicóticos durante tratamiento antituberculoso',
    'Monitorar respuesta clínica e aumentar dosis del haloperidol se necesario. Avaliar niveles séricos se disponible',
    'EFICACIA REDUCIDA — Monitorar síntomas psicóticos e ajustar dosis de haloperidol',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'olanzapina', InteractionSeverity.moderate,
    'Rifampicina induz CYP1A2 e glicuronidação (principais vias da olanzapina), reduzindo os niveles plasmáticos em 50%',
    'Posible fracaso terapéutico no controle da psicose/mania durante tratamiento antituberculoso',
    'Monitorar respuesta clínica. Pode ser necesario aumentar dosis de olanzapina. Reavaliar al suspender rifampicina',
    'EFICACIA REDUCIDA — Rifampicina induz CYP1A2; monitorar e ajustar dosis de olanzapina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'digoxina', InteractionSeverity.moderate,
    'Rifampicina induz P-gp intestinal e hepática, reduzindo a absorción e aumentando a eliminación de digoxina. Reducción de 30-50% nos niveles',
    'Reducción de la eficacia da digoxina no controle da frecuencia ventricular (FA) e na insuficiencia cardíaca',
    'Monitorar ECG e sinais de descompensação cardíaca. Ajustar dosis de digoxina. Monitorar nivel sérico de digoxina después de inicio e suspensión da rifampicina',
    'EFICACIA REDUCIDA — Rifampicina induz P-gp; monitorar niveles de digoxina e resposta cardíaca',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'amiodarona', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 e CYP2C8, as vías de metabolismo de la amiodarona e seu metabólito ativo (desetilamiodarona). Reduz os niveles de ambos',
    'Perda do controle do ritmo cardíaco (fibrilación auricular, flutter, TV) por niveles subterapéuticos de amiodarona. Riesgo elevado dado o estreito índice terapéutico da amiodarona',
    'Evitar combinación. Si inevitable: monitorar ECG continuamente, ajustar dosis de amiodarona e verificar niveles séricos. Considerar ablação ou cardioversão elétrica como alternativa',
    'PÉRDIDA DE CONTROL DEL RITMO — Rifampicina reduz amiodarona; monitorar ECG e considerar alternativa',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'levotiroxina', InteractionSeverity.moderate,
    'Rifampicina induz enzimas hepáticas que aumentam o metabolismo de T4 e T3 e pode reduzir a absorción intestinal de levotiroxina',
    'Riesgo de hipotiroidismo durante tratamiento com rifampicina en pacientes com hipotiroidismo prévio ou pós-tireoidectomia',
    'Monitorar TSH e T4 livre 4-6 semanas después de inicio da rifampicina. Pode ser necesario aumentar dosis de levotiroxina em 25-50%. Reavaliar al suspender rifampicina',
    'HIPOTIROIDISMO — Rifampicina aumenta metabolismo de T4; monitorar TSH e ajustar dosis',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'fenitoína', InteractionSeverity.moderate,
    'Interacción bidireccional: rifampicina induz CYP2C9 (metabolismo de la fenitoína) → reduz niveles. Concomitantemente, fenitoína também induz CYP, podendo reduzir rifampicina',
    'Riesgo de fallo en ambos fármacos (control convulsivo y antituberculoso). Relación imprevisible: alguns pacientes têm aumento paradoxal de fenitoína por inhibición de CYP2C9',
    'Monitorar nivel sérico de fenitoína (alvo: 10-20 mcg/mL) e resposta clínica. Ajustar dosis según sea necesario. Monitorar eficácia antituberculosa',
    'INTERACCIÓN BIDIRECCIONAL IMPREVISÍVEL — Monitorar nivel sérico de fenitoína e eficácia antituberculosa',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'fenobarbital', InteractionSeverity.moderate,
    'Ambos são inductores enzimáticos potentes (CYP2B6, CYP3A4, CYP2C). Rifampicina pode reduzir os niveles de fenobarbital por inducción de CYP2C9/glicuronidação',
    'Riesgo de ineficacia anticonvulsivante por reducción de los niveles de fenobarbital, con posible recurrencia de crisis',
    'Monitorar nivel sérico de fenobarbital e ajustar dosis según sea necesario. Avaliar controle clínico das crises',
    'EFICACIA REDUCIDA — Monitorar nivel sérico de fenobarbital durante uso de rifampicina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'claritromicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4, a principal vía de metabolismo de la claritromicina. Reduz os niveles de claritromicina em 75-80%',
    'Falha terapéutica da claritromicina (infecções por Mycobacterium avium complex, Helicobacter pylori, pneumonias). Especialmente crítico no contexto de MAC em imunodeprimidos',
    'Evitar la combinación no contexto de infecção por MAC. Para outras indicações, avaliar se azitromicina é uma alternativa (menos afetada). Monitorar respuesta microbiológica e clínica',
    'FRACASO TERAPÉUTICO — Rifampicina reduz claritromicina em 75-80%; usar azitromicina si es posible',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('rifampicina', 'eritromicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4, reduzindo significativamente os niveles de eritromicina. Pode reduzir a AUC em 50-70%',
    'Falha terapéutica por niveles subterapéuticos de eritromicina. Combinación clinicamente irracional na maioria dos cenários',
    'Evitar combinación. Usar azitromicina (menos afetada por inducción de CYP) ou outro antibiótico adecuado ao espectro necesario',
    'FRACASO TERAPÉUTICO — Rifampicina reduz eritromicina; sustituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('rifampicina', 'ritonavir', InteractionSeverity.contraindicated,
    'Rifampicina é inductor potente de CYP3A4/P-gp; ritonavir é inhibidor potente de CYP3A4. A inducción pela rifampicina supera a inhibición del ritonavir, podendo reduzir os niveles de ritonavir em 75% e aumentar paradoxalmente o riesgo de hepatotoxicidad grave',
    'Fracaso virológico (HIV/HCV) por niveles subterapéuticos de ritonavir. Riesgo elevado de hepatotoxicidad grave e síndrome de reconstituição imune. Documentados casos de hepatite fulminante',
    'CONTRAINDICADO. Para TARV durante tuberculose: sustituir por regimes baseados em inhibidores de integrase (dolutegravir 50mg 2x/dia + rifampicina) segundo diretrizes OMS. Nunca combinar rifampicina com IP boosted',
    'CONTRAINDICADO — Fracaso virológico + hepatotoxicidad fatal; usar dolutegravir + rifampicina segundo protocolo OMS',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── CARBAMAZEPINA (inductor CYP3A4/1A2/2C9, inductor P-gp) ──────────────────

  ('carbamazepina', 'isrs', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e CYP2C19, acelerando o metabolismo de citalopram, escitalopram, sertralina e outros ISRSs. Fluoxetina e fluvoxamina inibem CYP3A4/2C19, podendo aumentar carbamazepina e seu metabólito epóxido (tóxico)',
    'Reducción de los niveles do ISRS → fracaso antidepresivo. Fluoxetina/fluvoxamina podem causar toxicidad de carbamazepina (diplopia, ataxia, tontura, náusea) por inhibición do seu metabolismo',
    'Monitorar respuesta ao ISRS e nivel sérico de carbamazepina. Sertralina é a opção mais segura (menor interacción). Evitar fluoxetina e fluvoxamina com carbamazepina',
    'EFICACIA REDUCIDA + RISCO DE TOXICIDADE — Monitorar nivel de carbamazepina e resposta ao ISRS',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'opioide', InteractionSeverity.moderate,
    'Carbamazepina induz CYP3A4 (fentanila, oxicodona, tramadol) e CYP2D6 (codeína, tramadol), reduzindo os niveles e a eficácia analgésica. Tramadol tem riesgo adicional de abaixamento do limiar convulsivo',
    'Reducción de la analgesia por niveles subterapéuticos de opioides. Tramadol especialmente problemático: além de analgesia reducida, o abaixamento do limiar convulsivo pode precipitar crises en epilépticos',
    'Evitar tramadol en pacientes com epilepsia em uso de carbamazepina. Aumentar dosis de opioides según sea necesario. Preferir morfina ou hidromorfona (metabolismo por glucuronidação)',
    'ANALGESIA REDUZIDA — Evitar tramadol; preferir morfina e monitorar control del dolor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.seizure},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'metadona', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e CYP2C8, as principais vías de metabolismo de la metadona, reduzindo os niveles em 50-60%',
    'Síndrome de abstinencia opiácea en pacientes em programa de sustitución → riesgo de recaída. Dor não controlada em uso crônico',
    'Evitar combinación cuando sea posible. Si es necesaria: aumentar dosis de metadona gradualmente, monitorar signos de abstinência. Al suspender carbamazepina, reduzir metadona para prevenir superdosagem',
    'ABSTINENCIA OPIOIDE — Carbamazepina reduz metadona 50-60%; aumentar dosis e monitorar abstinência',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'olanzapina', InteractionSeverity.moderate,
    'Carbamazepina induz CYP1A2 (principal via da olanzapina) e glicuronidação, reduzindo os niveles de olanzapina em 50%',
    'Posible fracaso terapéutico no controle da psicose ou mania bipolar',
    'Monitorar respuesta clínica. Aumentar dosis de olanzapina se necesario (pode ser necesario dobrar). Reavaliar ao modificar dosis de carbamazepina',
    'EFICACIA REDUCIDA — Carbamazepina induz CYP1A2; monitorar e ajustar dosis de olanzapina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'haloperidol', InteractionSeverity.moderate,
    'Carbamazepina induz CYP3A4 e CYP2D6, as principais vías de metabolismo del haloperidol. Pode reduzir os niveles em 50-60%',
    'Reducción de la eficacia antipsicótica → recurrencia de síntomas psicóticos ou maníacos',
    'Monitorar respuesta clínica e aumentar dosis de haloperidol se necesario. Monitorar nivel sérico se disponible',
    'EFICACIA REDUCIDA — Carbamazepina induz CYP; monitorar respuesta clínica e ajustar dosis de haloperidol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'quetiapina', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4, reduzindo os niveles de quetiapina em 80%. É uma das interacciones mais documentadas em psiquiatria',
    'Falha grave no controle da psicose ou transtorno bipolar. Pacientes podem exigir dosiss muito elevadas de quetiapina, com riesgo de toxicidad al suspender carbamazepina',
    'Evitar combinación cuando sea posible. Se necesario: aumentar dosis de quetiapina substancialmente (5-7x a dosis usual). Monitorar respuesta clínica. Alternativas: valproato + quetiapina, ou trocar carbamazepina por lamotrigina',
    'FRACASO TERAPÉUTICO GRAVE — Carbamazepina reduz quetiapina em 80%; considerar trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'digoxina', InteractionSeverity.moderate,
    'Carbamazepina pode induzir P-gp, reduzindo a absorción intestinal e aumentando a eliminación renal de digoxina',
    'Reducción dos niveles de digoxina → perda do controle da frecuencia ventricular em FA ou insuficiencia cardíaca',
    'Monitorar nivel sérico de digoxina e ECG después de inicio ou modificação de carbamazepina. Ajustar dosis según sea necesario',
    'EFICACIA REDUCIDA — Monitorar nivel sérico de digoxina durante uso de carbamazepina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'ciclosporina', InteractionSeverity.major,
    'Carbamazepina induz potentemente CYP3A4, a principal vía de metabolismo de la ciclosporina. Reducción de 50-75% nos niveles do inmunosupresor',
    'Rechazo agudo de transplante por niveles subterapéuticos de ciclosporina. Riesgo alto en pacientes trasplantados de órgão sólido',
    'Evitar combinación en pacientes trasplantados. Sustituir carbamazepina por lamotrigina, levetiracetam ou gabapentina (não inductores). Si inevitable: aumentar dosis de ciclosporina e monitorar nivel sérico (alvo C0 por tipo de transplante)',
    'RECHAZO DE TRASPLANTE — Carbamazepina reduz ciclosporina 50-75%; sustituir antiepilético por não-inductor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'tacrolimo', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e P-gp, reduzindo drásticamente os niveles de tacrolimo (inmunosupresor com índice terapéutico estreitíssimo)',
    'Rechazo agudo de trasplante por niveles subterapéuticos de tacrolimús. Riesgo de pérdida del injerto',
    'Evitar combinación en pacientes trasplantados. Sustituir carbamazepina por antiepilético não-inductor. Si es imposible: monitorar C0 de tacrolimo diariamente até estabilização e ajustar dosis agresivamente',
    'RECHAZO DE TRASPLANTE — Carbamazepina reduz tacrolimo drásticamente; sustituir antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inibe CYP3A4 e CYP2C8, aumentando os niveles de carbamazepina e seu metabólito epóxido (tóxico). Carbamazepina induz CYP3A4, podendo reduzir amiodarona',
    'Toxicidad de carbamazepina (diplopia, ataxia, tontura, náusea, sedación) por inhibición do seu metabolismo pela amiodarona. Riesgo de fracaso antiarrítmica por inducción',
    'Evitar combinación. Monitorar nivel sérico de carbamazepina e sinais de toxicidad. Si se mantiene, ajustar dosiss com base em niveles séricos e ECG',
    'TOXICIDAD DE CARBAMAZEPINA — Amiodarona inibe CYP3A4; monitorar nivel sérico e sinais de toxicidad',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'dabigatrana', InteractionSeverity.major,
    'Carbamazepina induz P-gp, o principal transportador de efflux da dabigatrana, reduzindo a absorción e aumentando a eliminación. Pode reduzir os niveles em 50-70%',
    'Riesgo de trombosis (AVC, TEP, TVP) por anticoagulação insuficiente',
    'Evitar combinación. Sustituir dabigatrana por varfarina (monitorada por INR) ou sustituir carbamazepina por antiepilético não-inductor. No usar dabigatrana como anticoagulante durante uso de carbamazepina',
    'TROMBOSIS — Carbamazepina induz P-gp; no usar dabigatrana; usar varfarina com INR rigoroso',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'apixabana', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e P-gp, ambas as vias de eliminación da apixabana, reduzindo os niveles em 50-60%',
    'Anticoagulação insuficiente → trombosis (AVC, TEP, TVP)',
    'Evitar combinación. Usar varfarina (monitorada por INR) ou sustituir carbamazepina por antiepilético não-inductor (levetiracetam, lamotrigina). A bula da apixabana contraindica uso com inductores potentes de CYP3A4/P-gp',
    'TROMBOSIS — Carbamazepina reduz apixabana 50-60%; usar varfarina ou trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'rivaroxabana', InteractionSeverity.major,
    'Carbamazepina induz CYP3A4 e P-gp, reduzindo os niveles de rivaroxabana em 50-60%',
    'Anticoagulação insuficiente → trombosis. A bula da rivaroxabana contraindica uso combinado com inductores potentes de CYP3A4/P-gp',
    'CONTRAINDICADO por ficha técnica da rivaroxabana. Usar varfarina (monitorada por INR) ou sustituir carbamazepina por antiepilético não-inductor',
    'CONTRAINDICADO — Carbamazepina reduz rivaroxabana 50-60%; usar varfarina ou trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'lamotrigina', InteractionSeverity.major,
    'Carbamazepina induz UGT1A4 e CYP3A4, reduzindo os niveles de lamotrigina em 40-50%. A lamotrigina não afeta os niveles de carbamazepina, mas pode potencializar o metabólito epóxido (tóxico)',
    'Niveles subterapéuticos de lamotrigina → fracaso en el control de crises. Riesgo de toxicidad de carbamazepina epóxido (diplopia, ataxia)',
    'Quando combinados (uso frecuente em epilepsia refratária): dosis de lamotrigina em uso concomitante com carbamazepina são 2x maiores do que em monoterapia. Monitorar signos de toxicidad de carbamazepina epóxido',
    'DOSIS DE LAMOTRIGINA DUPLICADA — Carbamazepina reduz lamotrigina 40-50%; ajustar dosis conforme protocolo',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'topiramato', InteractionSeverity.moderate,
    'Carbamazepina induz CYP3A4, reduzindo os niveles de topiramato em 40-50%. Topiramato pode levemente aumentar os niveles de carbamazepina',
    'Posible falha no control convulsivo por niveles subterapéuticos de topiramato',
    'Monitorar respuesta ao topiramato. Aumentar dosis de topiramato según sea necesario. Usar a maior dosis efetiva dentro das recomendações',
    'EFICACIA REDUCIDA — Carbamazepina reduz topiramato 40-50%; monitorar control de las crisis',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbamazepina', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe potentemente CYP3A4, a principal via de eliminación da carbamazepina. Pode aumentar os niveles de carbamazepina e seu metabólito epóxido em 50-100%',
    'Toxicidade grave de carbamazepina: diplopia, ataxia, tontura, vômitos, confusión mental, hiponatremia. O metabólito epóxido (também tóxico) também se acumula',
    'Evitar combinación. Sustituir claritromicina por azitromicina (não inibe CYP3A4) cuando sea posible. Si inevitable: reducir dosis de carbamazepina em 25-50% e monitorar nivel sérico',
    'TOXICIDAD DE CARBAMAZEPINA — Claritromicina inibe CYP3A4; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('carbamazepina', 'eritromicina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4, aumentando os niveles de carbamazepina e seu metabólito epóxido. Interacción bem documentada em literatura',
    'Toxicidad de carbamazepina: diplopia, ataxia, vômitos, confusão, hiponatremia, arritmias',
    'Evitar combinación. Sustituir eritromicina por azitromicina (segura com carbamazepina). Si se mantiene: monitorar nivel sérico e reducir dosis de carbamazepina',
    'TOXICIDAD DE CARBAMAZEPINA — Eritromicina inibe CYP3A4; sustituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── FENITOÍNA (inductor CYP2C9/2C19/3A4, substrato CYP2C9/2C19) ──────────

  ('fenitoína', 'isrs', InteractionSeverity.major,
    'Fluoxetina e fluvoxamina inibem CYP2C9/2C19, aumentando os niveles de fenitoína. Fenitoína induz CYP3A4/2C19, podendo reduzir niveles de alguns ISRSs. Interacción bidireccional e complexa',
    'Toxicidad de fenitoína (nistagmo, ataxia, diplopia, confusão) com fluoxetina/fluvoxamina. Fracaso antidepresivo com sertralina/escitalopram por inducción',
    'Evitar fluoxetina e fluvoxamina com fenitoína. Sertralina é a opção mais segura. Monitorar nivel sérico de fenitoína (alvo: 10-20 mcg/mL) ao iniciar/suspender ISRS',
    'TOXICIDAD DE FENITOÍNA com fluoxetina/fluvoxamina — evitar; usar sertralina e monitorar nivel sérico',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'digoxina', InteractionSeverity.moderate,
    'Fenitoína induz P-gp e CYP3A4, reduzindo os niveles de digoxina. A própria fenitoína IV pode causar arritmias (bradicardia, bloqueo AV) quando administrada rapidamente',
    'Reducción dos niveles de digoxina → perda do controle da frecuencia ventricular em FA. Riesgo adicional de arritmias com fenitoína IV em bolus rápido',
    'Monitorar nivel sérico de digoxina e ECG. Ajustar dosis de digoxina según sea necesario. Administrar fenitoína IV lentamente (máximo 50mg/min)',
    'EFICACIA REDUCIDA — Monitorar nivel de digoxina; administrar fenitoína IV lentamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'ciclosporina', InteractionSeverity.major,
    'Fenitoína induz CYP3A4, reduzindo os niveles de ciclosporina em 50-75%. Ciclosporina pode ter efecto minor sobre fenitoína',
    'Rechazo agudo de transplante por niveles subterapéuticos de ciclosporina en pacientes trasplantados que necessitam de anticonvulsivante',
    'Evitar combinación en pacientes trasplantados. Sustituir fenitoína por levetiracetam, gabapentina ou lamotrigina (não inductores de CYP3A4). Si es imposible: monitorar C0 de ciclosporina diariamente e ajustar dosis agresivamente',
    'RECHAZO DE TRASPLANTE — Fenitoína reduz ciclosporina 50-75%; sustituir por antiepilético não-inductor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenitoína', 'tacrolimo', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 e P-gp, reduzindo drásticamente os niveles de tacrolimo (inmunosupresor com janela terapéutica estreitíssima)',
    'Rechazo agudo de trasplante por niveles subterapéuticos de tacrolimús. Riesgo de pérdida del injerto',
    'Evitar combinación. Sustituir fenitoína por antiepilético não-inductor en pacientes trasplantados. Si es imposible: monitorar C0 de tacrolimo diariamente e aumentar dosis significativamente',
    'RECHAZO DE TRASPLANTE — Fenitoína reduz tacrolimo drásticamente; sustituir antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenitoína', 'anticonceptivo', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 e UGT, acelerando o metabolismo de etinilestradiol e progestágenos. Pode reduzir os niveles hormonais em 50%',
    'Fracaso contraceptivo com embarazo no planificado em mulheres em uso de anticonceptivo hormonal (oral, patch, anel vaginal)',
    'Usar método de barrera adicional. Preferir anticonceptivo com dosis maior de estrogênio (≥50mcg etinilestradiol) ou DIU de cobre/levonorgestrel (SIU). Informar a la paciente sobre o riesgo',
    'FRACASO CONTRACEPTIVO — Fenitoína reduz hormônios; usar método de barrera adicional ou DIU',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'valproato', InteractionSeverity.major,
    'Interacción bidireccional complexa: valproato desloca fenitoína da albumina (↑ fração livre, mais tóxica) e inibe CYP2C9 (↑ nivel total). Fenitoína induz o metabolismo de valproato (↓ nivel). Relação impredecible',
    'Toxicidad de fenitoína (nivel livre elevado mesmo com nivel total normal/baixo) com ataxia, nistagmo, confusão. Falha do valproato por niveles subterapéuticos',
    'Monitorar nivel livre de fenitoína (não apenas nivel total). Monitorar nivel de valproato e resposta clínica. Considerar alternativas (levetiracetam) para evitar interacción complexa',
    'INTERACCIÓN COMPLEJA — Monitorar nivel LIVRE de fenitoína e nivel de valproato; interacción bidireccional impredecible',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenitoína', 'quetiapina', InteractionSeverity.major,
    'Fenitoína induz CYP3A4, a principal vía de metabolismo de la quetiapina. Pode reduzir os niveles em 80%',
    'Fracaso en el control da psicose ou transtorno bipolar por niveles subterapéuticos de quetiapina',
    'Evitar combinación cuando sea posible. Se necesario: aumentar dosis de quetiapina substancialmente. Monitorar respuesta clínica',
    'EFICACIA REDUCIDA — Fenitoína reduz quetiapina em até 80%; considerar trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e pode inibir parcialmente CYP2C19, reduzindo o metabolismo de la fenitoína. Riesgo de toxicidad por acumulación',
    'Toxicidad de fenitoína: nistagmo, ataxia, diplopia, confusão, encefalopatía',
    'Evitar combinación. Sustituir claritromicina por azitromicina cuando sea posible. Monitorar nivel sérico de fenitoína si se mantiene',
    'TOXICIDAD DE FENITOÍNA — Claritromicina inibe metabolismo; preferir azitromicina',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'eritromicina', InteractionSeverity.moderate,
    'Eritromicina inibe CYP3A4 e pode aumentar os niveles de fenitoína por inhibición do seu metabolismo',
    'Toxicidad de fenitoína: nistagmo, ataxia, diplopia, náusea',
    'Monitorar nivel sérico de fenitoína e sinais de toxicidad. Considerar azitromicina como alternativa',
    'TOXICIDAD DE FENITOÍNA — Monitorar nivel sérico ao usar eritromicina; preferir azitromicina',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('fenitoína', 'ritonavir', InteractionSeverity.major,
    'Interacción bidireccional: ritonavir inibe CYP2C9 (pode aumentar fenitoína) mas também induz CYP2C9 crónicamente (pode reduzir fenitoína). Fenitoína induz CYP3A4, reduzindo ritonavir e ARVs boosted',
    'Fracaso virológico por reducción del ritonavir/ARVs. Toxicidade ou falha da fenitoína por interacción impredecible e bidirecional',
    'Evitar combinación em TARV. Sustituir fenitoína por levetiracetam. Si se mantiene: monitorar carga viral e nivel sérico de fenitoína frecuentemente',
    'FRACASO VIROLÓGICO + INTERACCIÓN IMPREDECIBLE DE FENITOÍNA — Sustituir por levetiracetam em TARV',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenitoína', 'fenobarbital', InteractionSeverity.moderate,
    'Interacción bidireccional: fenobarbital pode induzir CYP2C9 (reduz fenitoína) ou inibir competitivamente (aumenta fenitoína). Efecto final é impredecible e varia entre pacientes',
    'Toxicidade ou falha de fenitoína por interacción bidireccional e variável. Toxicidad de sedación aditiva por ambos os fármacos',
    'Monitorar nivel sérico de fenitoína e resposta clínica. Esta combinación é usada em epilepsia refratária mas requer monitoramento cuidadoso',
    'INTERACCIÓN IMPREDECIBLE — Monitorar nivel sérico de fenitoína e controle clínico das crises',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── FENOBARBITAL (inductor CYP1A2/2C9/2C19/3A4/UGT) ───────────────────────

  ('fenobarbital', 'isrs', InteractionSeverity.moderate,
    'Fenobarbital induz CYP2C19 e CYP3A4, acelerando o metabolismo de vários ISRSs. Riesgo adicional de sedación aditiva (fenobarbital é sedante)',
    'Reducción de los niveles do ISRS → fracaso antidepresivo. Sedación excesiva por efecto aditivo no SNC',
    'Monitorar respuesta ao ISRS. Pode ser necesario aumentar dosis. Evitar atividades de riesgo (dirigir, operar máquinas) pelo efecto sedante combinado',
    'EFICACIA REDUCIDA + SEDAÇÃO — Monitorar respuesta ao antidepresivo e sedación aditiva',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'ciclosporina', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4, reduzindo os niveles de ciclosporina em 40-60%',
    'Rechazo agudo de transplante por anticoagulação insuficiente. Riesgo de pérdida del injerto',
    'Evitar combinación en pacientes trasplantados. Sustituir fenobarbital por levetiracetam ou gabapentina. Si es imposible: monitorar C0 de ciclosporina e ajustar dosis agresivamente',
    'RECHAZO DE TRASPLANTE — Fenobarbital reduz ciclosporina 40-60%; sustituir por antiepilético não-inductor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenobarbital', 'tacrolimo', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4 e P-gp, reduzindo os niveles de tacrolimo significativamente',
    'Rechazo agudo de transplante por niveles subterapéuticos de tacrolimo',
    'Evitar en pacientes trasplantados. Sustituir por antiepilético não-inductor. Monitorar C0 de tacrolimo diariamente si se mantiene',
    'RECHAZO DE TRASPLANTE — Fenobarbital reduz tacrolimo; sustituir antiepilético por não-inductor',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenobarbital', 'anticonceptivo', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4 e UGT, reduzindo os niveles de etinilestradiol e progestágenos. Mesma magnitude que fenitoína e carbamazepina',
    'Fracaso contraceptivo → embarazo no planificado. Riesgo especialmente crítico em mulheres em idade fértil com epilepsia',
    'Usar método de barrera adicional obligatoriamente. Preferir DIU de cobre ou levonorgestrel (não afetados). Considerar sustitución por antiepilético não-inductor (lamotrigina, levetiracetam)',
    'FRACASO CONTRACEPTIVO — Fenobarbital reduz hormônios; usar DIU ou método de barrera adicional',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'valproato', InteractionSeverity.major,
    'Valproato inibe o metabolismo de fenobarbital (CYP2C9 e β-oxidação mitocondrial), aumentando os niveles em 30-60%. Fenobarbital pode induzir o metabolismo del valproato',
    'Toxicidad de fenobarbital: sedación excesiva, ataxia, confusión mental, depresión respiratoria. Falha do valproato por inducción',
    'Monitorar nivel sérico de fenobarbital e sinais de toxicidad al iniciar valproato. Reducir dosis de fenobarbital preventivamente em 25%. Esta combinación é usada em epilepsia mas requer ajuste de dosiss',
    'TOXICIDAD DE FENOBARBITAL — Valproato aumenta nivel de fenobarbital 30-60%; reducir dosis de fenobarbital',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenobarbital', 'lamotrigina', InteractionSeverity.major,
    'Fenobarbital induz UGT1A4 (principal via de glucuronidação da lamotrigina), reduzindo os niveles em 40%',
    'Fracaso en el control de crises por niveles subterapéuticos de lamotrigina',
    'Dosis de lamotrigina em uso com fenobarbital são aproximadamente 2x maiores que em monoterapia. Seguir protocolo de titulación específico para uso com inductores enzimáticos',
    'DOSIS DE LAMOTRIGINA DUPLICADA — Fenobarbital induz UGT; ajustar dosis conforme protocolo com inductores',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('fenobarbital', 'quetiapina', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4, reduzindo os niveles de quetiapina em 70-80%',
    'Fracaso en el control da psicose ou transtorno bipolar por niveles subterapéuticos de quetiapina',
    'Evitar combinación cuando sea posible. Se necesario: aumentar dosis de quetiapina substancialmente (5-7x). Considerar trocar fenobarbital por valproato ou levetiracetam',
    'EFICACIA REDUCIDA — Fenobarbital reduz quetiapina em 70-80%; considerar trocar antiepilético',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'claritromicina', InteractionSeverity.moderate,
    'Claritromicina inibe CYP3A4, podendo aumentar os niveles de fenobarbital. Fenobarbital induz CYP3A4, podendo reduzir claritromicina',
    'Sedación excesiva por acumulación de fenobarbital. Posible falha antibiótica por reducción de claritromicina',
    'Monitorar sedación e nivel de fenobarbital. Considerar azitromicina como alternativa (sem interacción CYP significativa com fenobarbital)',
    'SEDACIÓN AUMENTADA + EFICACIA REDUCIDA — Monitorar sedación; preferir azitromicina',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'eritromicina', InteractionSeverity.moderate,
    'Eritromicina inibe CYP3A4, podendo aumentar os niveles de fenobarbital. Fenobarbital induz CYP3A4, podendo reduzir eritromicina. Sedación aditiva por SNC',
    'Sedación excesiva por acumulación de fenobarbital. Posible falha antibiótica',
    'Monitorar sedación. Preferir azitromicina. Si se mantiene: monitorar nivel sérico de fenobarbital',
    'SEDACIÓN AUMENTADA — Monitorar sedación; preferir azitromicina a eritromicina',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('fenobarbital', 'ritonavir', InteractionSeverity.major,
    'Fenobarbital induz CYP3A4, reduzindo os niveles de ritonavir e ARVs boosted. Riesgo de fracaso virológica em HIV',
    'Fracaso virológico (HIV) por reducción dos niveles de ritonavir/ARVs. Riesgo de resistência viral',
    'Evitar em TARV. Sustituir fenobarbital por levetiracetam ou lamotrigina. Monitorar carga viral e CD4 si se mantiene',
    'FRACASO VIROLÓGICO — Fenobarbital reduz ritonavir/ARVs; sustituir por antiepilético não-inductor em TARV',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── ERITROMICINA (inhibidor moderado CYP3A4, prolonga QTc) ─────────────────

  ('eritromicina', 'warfarina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 e CYP2C9, reduzindo o metabolismo de la varfarina (especialmente da S-varfarina, mais potente). Pode também reduzir a flora intestinal produtora de vitamina K',
    'Aumento do INR → riesgo de sangrado grave (intracraneal, gastrointestinal). Inicio rápido (2-5 dias después de inicio da eritromicina)',
    'Monitorar INR 2-3 dias después de inicio e al suspender eritromicina. Antecipar necessidade reducción de la dosis de varfarina em 20-30%. Considerar azitromicina (menos interacción com varfarina)',
    'SANGRADO — Eritromicina aumenta INR; monitorar INR e reducir dosis de varfarina; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'estatina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4, aumentando os niveles de sinvastatina, atorvastatina e lovastatina. Rosuvastatina e pravastatina são menos afetadas',
    'Riesgo aumentado de miopatía e rabdomiólisis por acumulación de estatinas. Riesgo mais elevado com sinvastatina (maior dependência de CYP3A4)',
    'Evitar eritromicina com sinvastatina (suspender sinvastatina durante curso de eritromicina). Preferir azitromicina. Se eritromicina necesaria: usar rosuvastatina ou pravastatina (menos afetadas por CYP3A4)',
    'RABDOMIÓLISIS — Eritromicina inibe CYP3A4; suspender sinvastatina ou usar azitromicina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('eritromicina', 'digoxina', InteractionSeverity.major,
    'Eritromicina aumenta a biodisponibilidad da digoxina por dois mecanismos: inhibición de P-gp intestinal e eliminación de bactérias intestinais que inativam digoxina (Eggerthella lenta). Afeta ~10% dos pacientes mas pode ser grave',
    'Intoxicación digitálica: náusea, vômitos, bradicardia, bloqueo AV, arritmias ventriculares potencialmente fatais',
    'Monitorar nivel sérico de digoxina e ECG después de inicio de eritromicina. En pacientes com nivel próximo ao terapéutico máximo, reducir dosis de digoxina preventivamente. Considerar azitromicina',
    'INTOXICACIÓN DIGITÁLICA — Eritromicina aumenta digoxina; monitorar nivel sérico e ECG; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'ciclosporina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 e P-gp, aumentando os niveles de ciclosporina em 50-100% en pacientes trasplantados',
    'Nefrotoxicidad grave, hipertensão, hiperpotasemia por acumulación de ciclosporina',
    'Monitorar C0 de ciclosporina a cada 2-3 dias durante uso de eritromicina. Reducir dosis preventivamente em 25-50%. Preferir azitromicina (menor interacción) en pacientes trasplantados',
    'NEFROTOXICIDAD — Eritromicina dobra niveles de ciclosporina; reducir dosis e monitorar C0; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'tacrolimo', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 e P-gp, aumentando os niveles de tacrolimo significativamente (pode duplicar ou triplicar)',
    'Nefrotoxicidad grave e neurotoxicidad por acumulación de tacrolimo. Riesgo de rechazo paradoxal se os niveles forem mal manejados',
    'Monitorar C0 de tacrolimo diariamente al iniciar eritromicina. Reducir dosis de tacrolimo em 30-50% preventivamente. Preferir azitromicina en pacientes trasplantados',
    'NEFROTOXICIDAD GRAVE — Eritromicina triplica tacrolimo; monitorar C0 diariamente; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'isrs', InteractionSeverity.moderate,
    'Eritromicina inibe CYP3A4 e prolonga QTc. Citalopram e escitalopram também prolongam QTc. Fluoxetina inibe CYP2D6/3A4 (interacción bidireccional)',
    'Prolongación QTc aditivo, especialmente com citalopram e escitalopram. Riesgo de torsades de pointes',
    'Evitar eritromicina + citalopram/escitalopram. Monitorar ECG com outros ISRSs. Corrigir electrolitos. Preferir azitromicina (menor riesgo de QT)',
    'PROLONGACIÓN QT — Evitar eritromicina + citalopram/escitalopram; monitorar ECG com outros ISRSs',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('eritromicina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Eritromicina inibe CYP3A4, aumentando os niveles de alprazolam, diazepam, triazolam e midazolam. Lorazepam não é afetado significativamente (glucuronidação)',
    'Sedación excesiva y prolongada, compromiso psicomotor, depresión respiratoria (especialmente com triazolam e midazolam)',
    'Evitar eritromicina com triazolam e midazolam oral (alto riesgo). Preferir lorazepam ou azitromicina. Reducir dosis do benzodiazepínico em 50% se necesario',
    'SEDACIÓN EXCESIVA — Eritromicina inibe CYP3A4; evitar triazolam/midazolam; preferir lorazepam ou azitromicina',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('eritromicina', 'quetiapina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 (metabolismo de quetiapina) e prolonga QTc. Quetiapina também prolonga QTc',
    'Aumento dos niveles de quetiapina → toxicidad (sedación, hipotensión, prolongación QTc). Riesgo aditivo de torsades de pointes',
    'Evitar combinación. Sustituir eritromicina por azitromicina. Monitorar ECG e sinais de toxicidad de quetiapina si se mantiene',
    'QT PROLONGADO + TOXICIDAD DE QUETIAPINA — Sustituir eritromicina por azitromicina; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('eritromicina', 'metadona', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 (metabolismo de metadona) e prolonga QTc. Metadona também prolonga QTc de forma dosis-dependente',
    'Acumulación de metadona → sedación, depresión respiratoria, prolongación QTc grave, torsades de pointes. Riesgo fatal em dosiss elevadas de metadona',
    'Evitar combinación. Sustituir eritromicina por azitromicina. Monitorar ECG (QTc), SpO₂ e sinais de sobredosis de metadona si se mantiene',
    'TORSADES DE POINTES + SUPERDOSAGEM DE METADONA — Sustituir eritromicina por azitromicina; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── RITONAVIR (inhibidor potentíssimo CYP3A4, 2D6, P-gp) ─────────────────

  ('ritonavir', 'estatina', InteractionSeverity.contraindicated,
    'Ritonavir inibe potentemente CYP3A4, a principal vía de metabolismo de sinvastatina, lovastatina e atorvastatina. Pode aumentar os niveles de sinvastatina em mais de 30x',
    'Rabdomiólisis grave por acumulación maciço de estatinas → insuficiencia renal aguda, hiperpotasemia, morte. Um dos raros casos de interacción com riesgo de vida imediato',
    'CONTRAINDICADO: ritonavir + sinvastatina/lovastatina. Usar rosuvastatina (moderadamente afetada — iniciar com 10mg) ou pravastatina (menos afetada por CYP3A4) com monitoramento de CK. Evitar dosis altas de qualquer estatina com ritonavir',
    'CONTRAINDICADO — Ritonavir aumenta sinvastatina >30x; usar pravastatina ou rosuvastatina em dosis baja',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ritonavir', 'quetiapina', InteractionSeverity.contraindicated,
    'Ritonavir inibe potentemente CYP3A4, a principal vía de metabolismo de la quetiapina. Pode aumentar os niveles de quetiapina em 10-20x. Ambos prolongam QTc',
    'Toxicidade grave de quetiapina: sedación profunda, hipotensión grave, prolongación QTc com riesgo de torsades, depresión respiratoria. Casos fatais reportados',
    'CONTRAINDICADO. Sustituir quetiapina por antipsicótico com menor dependência de CYP3A4 (haloperidol, aripiprazol). Consultar infectologista antes de iniciar TARV com ritonavir en pacientes em uso de quetiapina',
    'CONTRAINDICADO — Ritonavir aumenta quetiapina 10-20x; sustituir por haloperidol ou aripiprazol',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.qtProlongation, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ritonavir', 'benzodiazepínico', InteractionSeverity.contraindicated,
    'Ritonavir inibe potentemente CYP3A4, a principal vía de metabolismo de alprazolam, diazepam, triazolam, midazolam e clonazepam. Pode aumentar os niveles em 10-30x. Lorazepam é menos afetado',
    'Sedación profunda e prolongada, depresión respiratoria grave, coma e morte. Triazolam e midazolam oral são as combinações mais perigosas',
    'CONTRAINDICADO: ritonavir + triazolam/midazolam oral (bula). Alprazolam, diazepam, clonazepam: evitar ou usar dosiss muito reducidas com monitoramento. Usar lorazepam (glucuronidação — menos afetado) quando sedación necesaria',
    'CONTRAINDICADO com triazolam/midazolam — Ritonavir aumenta BZDs 10-30x; usar lorazepam se necesario',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ritonavir', 'fentanila', InteractionSeverity.major,
    'Ritonavir inibe CYP3A4, a principal vía de metabolismo de la fentanila. Pode aumentar significativamente os niveles de fentanila e prolonga sua vida media',
    'Sedación intensa, depresión respiratoria e apnea por acumulación de fentanila. Especialmente perigoso em uso crônico (adesivos transdérmicos)',
    'Reducir dosis de fentanila em 50% al iniciar ritonavir. Monitorar frecuencia respiratória, SpO₂ e nivel de sedación. Tener naloxona disponible. Titular dosis lentamente',
    'DEPRESIÓN RESPIRATORIA — Ritonavir aumenta fentanila; reducir dosis 50% e monitorar SpO₂',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ritonavir', 'opioide', InteractionSeverity.major,
    'Ritonavir inibe CYP3A4 e CYP2D6, as principais vías de metabolismo de oxicodona, codeína, tramadol e fentanila. Pode aumentar os niveles em 50-100%. Morfina (glucuronidação) é menos afetada',
    'Sedación excesiva, depresión respiratoria, constipação intensa por acumulación de opioides',
    'Preferir morfina (glucuronidação, menos afetada pelo CYP). Reducir dosis de opioides CYP3A4-dependentes em 30-50%. Monitorar SpO₂ e nivel de sedación. Titular lentamente',
    'DEPRESIÓN RESPIRATORIA — Ritonavir aumenta opioides; preferir morfina e reducir dosiss de CYP3A4-dependentes',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── ENTRE INIBIDORES/INDUTORES CYP ────────────────────────────────────────

  ('claritromicina', 'eritromicina', InteractionSeverity.moderate,
    'Ambos inibem CYP3A4 e prolongam o intervalo QTc. A combinación não tem indicação terapéutica (espectro antibacteriano sobreposto) e potencializa os efectos adversos de ambos',
    'Prolongación QTc aditivo → riesgo aumentado de torsades de pointes. Toxicidade GI aumentada. Combinación sem benefício clínico justificável',
    'Evitar combinación. Usar apenas um dos agentes. Se necesario cobertura mais ampla, combinar com outro antibiótico de classe diferente',
    'SIN BENEFICIO CLÍNICO + QT PROLONGADO — Evitar combinación; mesma classe com efectos adversos aditivos',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('claritromicina', 'ritonavir', InteractionSeverity.major,
    'Ritonavir inibe CYP3A4, aumentando os niveles de claritromicina em 77%. Claritromicina inibe CYP3A4, podendo aumentar ritonavir. Ambos prolongam QTc',
    'Acumulación de claritromicina → toxicidad (distúrbios auditivos, hepatotoxicidad, prolongación QTc). Em insuficiencia renal, riesgo ainda maior',
    'Reducir dosis de claritromicina em 50% se TFG < 60mL/min. Monitorar ECG e función hepática. Azitromicina é a alternativa preferida en pacientes com TARV baseada em ritonavir',
    'QT PROLONGADO + TOXICIDADE — Reduzir claritromicina 50% em IR; monitorar ECG; preferir azitromicina em TARV',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('eritromicina', 'ritonavir', InteractionSeverity.major,
    'Ritonavir inibe CYP3A4, aumentando os niveles de eritromicina. Ambos prolongam QTc de forma dosis-dependente',
    'Acumulación de eritromicina → prolongación QTc grave, torsades de pointes. Toxicidade GI aumentada',
    'Evitar combinación. Sustituir eritromicina por azitromicina (menor interacción e menor riesgo de QT). Si se mantiene: monitorar ECG rigurosamente',
    'TORSADES DE POINTES — Ritonavir aumenta eritromicina; sustituir por azitromicina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'amitriptilina', InteractionSeverity.major,
    'ISRSs (especialmente fluoxetina e paroxetina) inibem CYP2D6, principal vía de metabolismo de la amitriptilina. Aumentam seus niveles em 2-4x. Ambos têm atividade serotoninérgica somada',
    'Toxicidad por amitriptilina: arritmias (QT prolongado, bloqueo AV), hipotensión ortostática, retenção urinária, confusão. Riesgo de síndrome serotoninérgica',
    'Evitar fluoxetina e paroxetina com amitriptilina. Se necesario: sertralina (menor inhibición de CYP2D6) em dosis baja. Monitorar ECG (QTc) e sinais de toxicidad tricíclica',
    'TOXICIDAD DE AMITRIPTILINA + QT PROLONGADO — Evitar fluoxetina/paroxetina; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.serotonin, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'mirtazapina', InteractionSeverity.moderate,
    'Mirtazapina tem mecanismo noradrenérgico/serotoninérgico (antagonismo α2 + 5-HT2/3). A combinación com ISRS é usada terapeuticamente em depressão refratária ("California Rocket"), mas aumenta o riesgo de síndrome serotoninérgica',
    'Riesgo moderado de síndrome serotoninérgica. Sedación aditiva por efecto anti-histamínico da mirtazapina + ISRS',
    'Combinación usada em depressão resistente sob supervisão especializada. Titular lentamente. Monitorar signos de serotonina. Evitar em ambulatório sem suporte psiquiátrico',
    'SÍNDROME SEROTONINÉRGICA MODERADA — Combinación usada em depressão refratária; monitorar signos serotoninérgicos',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'quetiapina', InteractionSeverity.moderate,
    'Quetiapina tem atividade serotoninérgica (antagonismo 5-HT2A). Fluoxetina inibe CYP3A4/2D6, podendo aumentar os niveles de quetiapina. Prolongación QTc aditivo com citalopram/escitalopram',
    'Riesgo de síndrome serotoninérgica leve-moderada. QTc prolongado com citalopram + quetiapina. Sedación aditiva',
    'Monitorar ECG com citalopram/escitalopram + quetiapina. Monitorar signos serotoninérgicos. Reducir dosis de quetiapina se fluoxetina for usada',
    'QT PROLONGADO + SEDAÇÃO — Monitorar ECG (especialmente citalopram + quetiapina) e signos serotoninérgicos',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'haloperidol', InteractionSeverity.moderate,
    'Fluoxetina e paroxetina inibem CYP2D6, a principal vía de metabolismo del haloperidol, aumentando os niveles em 50-100%. Ambos prolongam QTc',
    'Toxicidad de haloperidol: prolongación QTc, sintomas extrapiramidais (acatisia, distonia aguda). Sedación aditiva',
    'Monitorar ECG e signos extrapiramidales. Considerar reducir dosis de haloperidol em 30-50% com fluoxetina/paroxetina. Sertralina tem menor impacto em CYP2D6',
    'QT PROLONGADO + SINTOMAS EXTRAPIRAMIDAIS — Monitorar ECG; reduzir haloperidol com fluoxetina/paroxetina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('isrs', 'olanzapina', InteractionSeverity.minor,
    'Fluoxetina inibe CYP2D6/1A2, podendo aumentar modestamente os niveles de olanzapina. Riesgo serotoninérgico teórico',
    'Aumento modesto da sedación e dos efectos metabólicos (aumento de peso). Síndrome serotoninérgica improbable mas posible',
    'Monitorar sedación e aumento de peso. Combinación usada em depressão bipolar (fluoxetina + olanzapina = "OFC"). Sem ajuste de dosis rotineiro necesario',
    'SEDACIÓN AUMENTADA — Combinación usada em depressão bipolar; monitorar sedación e peso',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── IMAO × outros SNC ─────────────────────────────────────────────────────

  ('imao', 'amitriptilina', InteractionSeverity.contraindicated,
    'IMAOs inibem a degradação de monoaminas; amitriptilina inibe recaptação de serotonina e noradrenalina. Combinación causa acumulación maciço de monoaminas. Período de lavado: 14 dias para IMAO irreversible',
    'Síndrome serotoninérgica grave (agitação, hipertermia, convulsiones, rabdomiólisis) e crisis adrenérgica (hipertensão grave, arritmias). Potencialmente fatal',
    'CONTRAINDICADO. Período de lavado de 14 dias después de suspensión do IMAO antes de iniciar tricíclico. Nunca combinar',
    'CONTRAINDICADO — Síndrome serotoninérgica fatal; período de lavado obligatorio de 14 dias',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('imao', 'opioide', InteractionSeverity.contraindicated,
    'Meperidina e tramadol têm atividade serotoninérgica e são contraindicados. Morfina e fentanila têm menor riesgo serotoninérgico, mas todos os opioides podem causar síndrome excitadora ou depressora com IMAOs',
    'Síndrome excitadora (agitação, convulsiones, hipertermia com meperidina/tramadol) ou síndrome depressora (coma, depresión respiratoria com morfina/fentanila). Ambas potencialmente fatais',
    'CONTRAINDICADO: IMAOs + meperidina ou tramadol (absoluto). Morfina e fentanila: usar com cautela extrema e monitoramento rigoroso si es inevitable. Período de lavado de 14 dias do IMAO antes de opioides',
    'CONTRAINDICADO com meperidina/tramadol — Síndromes excitadora ou depressora; usar morfina apenas com cautela extrema',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('imao', 'benzodiazepínico', InteractionSeverity.moderate,
    'IMAOs podem potencializar os efectos sedantes do SNC dos benzodiazepínicos por mecanismos não totalmente elucidados. Interacción de menor magnitude que outras combinações com IMAO',
    'Sedación excesiva, depresión respiratoria aumentada, hipotensión',
    'Usar com cautela. Reducir dosis do benzodiazepínico. Monitorar nivel de sedación e FR. Evitar durante período de lavado do IMAO',
    'SEDACIÓN AUMENTADA — Usar dosis reducida de benzodiazepínico; monitorar sedación e frecuencia respiratoria',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('imao', 'quetiapina', InteractionSeverity.major,
    'IMAOs podem potencializar os efectos da quetiapina no SNC e cardiovasculares. Riesgo de síndrome serotoninérgica por atividade 5-HT2A da quetiapina',
    'Sedación excesiva, hipotensión grave, riesgo de síndrome serotoninérgica',
    'Evitar combinación. Período de lavado de 14 dias do IMAO. Se necesario antipsicótico durante transição: usar haloperidol com cautela',
    'EVITAR — Hipotensión grave e sedación; período de lavado de 14 dias do IMAO antes de iniciar quetiapina',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('imao', 'haloperidol', InteractionSeverity.moderate,
    'IMAOs podem potencializar os efectos do haloperidol no SNC. Riesgo de hipotensión e sedación aditivos',
    'Hipotensión grave, sedación excesiva, riesgo aumentado de efectos extrapiramidais',
    'Usar com extrema cautela e apenas quando antipsicótico for indispensable durante período de lavado. Monitorar PA e sedación rigurosamente',
    'HIPOTENSÃO + SEDAÇÃO — Usar apenas si es indispensable durante período de lavado; monitorar PA',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'mirtazapina', InteractionSeverity.major,
    'Amitriptilina + mirtazapina: efectos anticolinérgicos, antihistamínicos e sedantes aditivos. Ambas têm atividade serotoninérgica. Riesgo de toxicidad por acumulación',
    'Sedación profunda, confusão, retenção urinária, visão turva, constipação grave, delirio anticolinérgico en ancianos. QTc prolongado',
    'Evitar en ancianos (síndrome anticolinérgica grave). Em adultos jovens: monitorar cognição, função vesical e ECG. Considerar alternativas mais seguras',
    'TOXICIDADE ANTICOLINÉRGICA + SEDAÇÃO GRAVE — Evitar en ancianos; monitorar cognição e ECG',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'quetiapina', InteractionSeverity.major,
    'Ambas prolongam o QTc e têm efectos anticolinérgicos e sedantes significativos. Fluoxetina inibe CYP2D6/3A4, aumentando os niveles de ambas',
    'QTc prolongado com riesgo de torsades de pointes. Sedación excesiva e delirio anticolinérgico, especialmente en ancianos',
    'Monitorar ECG (QTc) antes e durante o tratamiento. Evitar en pacientes com QTc basal > 450ms. Evitar en ancianos. Manter electrolitos normais',
    'QT PROLONGADO GRAVE + DELIRIUM — Monitorar ECG; evitar en ancianos e pacientes com QTc > 450ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Efectos depressores do SNC aditivos. Amitriptilina tem efectos sedantes intrínsecas (anti-H1). Benzodiazepínicos potencializam a sedación',
    'Sedación excesiva, depresión respiratoria (especialmente en ancianos), comprometimento cognitivo, riesgo de quedas',
    'Evitar en ancianos (critérios de Beers). Em adultos: usar dosis mínimas efetivas de ambos. Advertir sobre dirigir e operar máquinas',
    'SEDACIÓN EXCESIVA — Evitar en ancianos; usar dosis mínimas e advertir sobre dirigir',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'haloperidol', InteractionSeverity.major,
    'Ambos prolongam o QTc (haloperidol bloqueia IKr/hERG; amitriptilina prolonga QT por múltiplos mecanismos) e têm efectos anticolinérgicos aditivos',
    'QTc prolongado com riesgo de torsades de pointes. Delirio anticolinérgico, especialmente en ancianos',
    'Monitorar ECG (QTc). Evitar en pacientes com QTc > 450ms ou hipopotasemia/hipomagnesemia. Considerar alternativas com menor impacto no QT',
    'QT PROLONGADO + DELIRIUM ANTICOLINÉRGICO — Monitorar ECG; evitar se QTc > 450ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'olanzapina', InteractionSeverity.moderate,
    'Efectos anticolinérgicos, sedantes e metabólicos aditivos (aumento de peso, hiperglucemia). Ambas prolongam modestamente o QTc',
    'Sedación excesiva, delirio anticolinérgico en ancianos, aumento de peso, intolerância à glicose, QTc prolongado',
    'Evitar en ancianos e pacientes com riesgo metabólico/DM2. Monitorar peso, glucemia e ECG. Preferir alternativas com menor perfil anticolinérgico',
    'TOXICIDADE ANTICOLINÉRGICA + METABÓLICA — Evitar en ancianos; monitorar peso, glucemia e ECG',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('amitriptilina', 'imao reversivel', InteractionSeverity.contraindicated,
    'Mesmo que IMAO irreversible: amitriptilina + moclobemida pode causar síndrome serotoninérgica por atividade serotoninérgica somada',
    'Síndrome serotoninérgica: agitação, mioclonias, hipertermia, convulsiones',
    'CONTRAINDICADO. Período de lavado de 1 dia después de moclobemida; período de lavado de 7 dias después de amitriptilina antes de moclobemida',
    'CONTRAINDICADO — Síndrome serotoninérgica; período de lavado obligatorio mesmo com IMAO reversível',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'amitriptilina', InteractionSeverity.major,
    'Bupropiona inibe CYP2D6, aumentando os niveles de amitriptilina em 2-4x. Ambos abaixam o limiar convulsivo',
    'Toxicidad por amitriptilina (QTc prolongado, efectos anticolinérgicos, arritmias) + riesgo aumentado de convulsiones',
    'Evitar combinación. Se antidepresivo dual necesario: preferir combinación de ISRS + mirtazapina. Monitorar ECG e nivel de amitriptilina si se mantiene',
    'TOXICIDAD DE AMITRIPTILINA + CONVULSIONES — Bupropiona aumenta amitriptilina 2-4x; evitar combinación',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.seizure, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'haloperidol', InteractionSeverity.moderate,
    'Bupropiona inibe CYP2D6, aumentando os niveles de haloperidol. Ambos abaixam o limiar convulsivo',
    'Toxicidad de haloperidol: prolongación QTc, sintomas extrapiramidais. Riesgo aumentado de convulsiones',
    'Monitorar ECG e sintomas extrapiramidais. Considerar reducir dosis de haloperidol. Monitorar signos de toxicidad',
    'QT PROLONGADO + EXTRAPIRAMIDAL — Monitorar ECG e sintomas extrapiramidais; reducir dosis de haloperidol',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.qtProlongation, RiskType.seizure},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'quetiapina', InteractionSeverity.moderate,
    'Bupropiona inibe CYP2D6, podendo aumentar os metabólitos ativos da quetiapina. Ambos abaixam o limiar convulsivo e alteram o limiar convulsivo',
    'Riesgo aumentado de convulsiones. Sedación aditiva',
    'Usar com cautela en pacientes com histórico de convulsiones. Monitorar sedación e limiar convulsivo',
    'CONVULSIONES — Usar com cautela; ambos abaixam limiar convulsivo; evitar en pacientes com epilepsia',
    EvidenceLevel.probable,
    {RiskType.seizure, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'mirtazapina', InteractionSeverity.moderate,
    'Bupropiona (noradrenérgica/dopaminérgica) + mirtazapina (noradrenérgica/serotoninérgica) é combinación usada em depressão refratária. Bupropiona inibe CYP2D6, podendo aumentar metabólitos da mirtazapina',
    'Riesgo moderado de convulsiones (bupropiona abaixa limiar). Insônia paradoxal (bupropiona ativa; mirtazapina sedativa)',
    'Combinación usada em depressão resistente ("rocket fuel"). Titular lentamente. Monitorar limiar convulsivo e efectos opostos na sedación/sono',
    'RISCO DE CONVULSIONES — Combinación usada em depressão refratária; monitorar limiar convulsivo e sono',
    EvidenceLevel.probable,
    {RiskType.seizure},
    [_kRefGG, _kRefMdx]),


  ('bupropiona', 'imao reversivel', InteractionSeverity.contraindicated,
    'Bupropiona inibe recaptação de dopamina e noradrenalina; moclobemida inibe MAO-A. Combinación causa acumulación de monoaminas',
    'Crisis hipertensiva, convulsiones, síndrome adrenérgica grave',
    'CONTRAINDICADO. Período de lavado de 1 dia después de moclobemida antes de iniciar bupropiona',
    'CONTRAINDICADO — Crisis hipertensiva e convulsiones',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('opioide', 'mirtazapina', InteractionSeverity.moderate,
    'Mirtazapina tem efectos sedantes potentes (anti-H1). A combinación com opioides potencializa a depresión del SNC. Riesgo serotoninérgico teórico (mirtazapina ativa 5-HT indireto)',
    'Sedación excesiva, depresión respiratoria aumentada, especialmente em inicio de tratamiento ou com dosiss elevadas',
    'Monitorar sedación e frecuencia respiratoria. Usar dosis mínimas de ambos. Advertir paciente sobre riesgo de quedas e comprometimento cognitivo',
    'SEDAÇÃO + DEPRESIÓN RESPIRATORIA — Monitorar SpO₂ e sedación; usar dosis mínimas de ambos',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('opioide', 'quetiapina', InteractionSeverity.major,
    'Quetiapina tem potentes efectos sedantes e depressores do SNC. A combinación com opioides potencializa a depresión respiratoria. Quetiapina inibe CYP2D6/3A4 variadamente',
    'Sedación profunda, depresión respiratoria grave, hipotensión, riesgo de aspiração e morte. Combinación frecuentemente envolvida em óbitos por superdosagem acidental',
    'Evitar uso concomitante em altas dosiss. Se necesario: usar dosis mínimas de ambos, monitorar SpO₂ e PA. Prescrever naloxona de resgate. Educar al paciente e família',
    'DEPRESIÓN RESPIRATORIA GRAVE — Evitar altas dosiss combinadas; prescrever naloxona; monitorar SpO₂',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('opioide', 'haloperidol', InteractionSeverity.moderate,
    'Haloperidol potencializa os efectos sedantes dos opioides. Usado terapeuticamente em cuidados paliativos (controle de náusea + dor), mas com riesgo de sedación excesiva',
    'Sedación excesiva, hipotensión ortostática, depresión respiratoria em dosiss elevadas de ambos',
    'Em cuidados paliativos: titulación cuidadosa com dosis mínimas. Monitorar nivel de sedación (RASS), PA e FR. Tener naloxona disponible',
    'SEDACIÓN AUMENTADA — Em CP: titular cuidadosamente; monitorar RASS, PA e FR; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('fentanila', 'midazolam', InteractionSeverity.major,
    'Fentanila (depressor respiratório μ-opioide) + midazolam (benzodiazepínico GABA-A) é combinación de alto riesgo para sedación procedural. O efecto sinérgico (não apenas aditivo) pode precipitar apnea mesmo com dosiss que seriam seguras individualmente',
    'Apnea, desaturación grave (SpO₂ < 85%), bradicardia, parada respiratória. Combinación responsável por incidentes graves em sedación procedural e UTI',
    'Usar apenas em ambiente monitorizado com acesso imediato a bolsa-válvula-máscara, oxigênio e flumazenil + naloxona. Titular em dosiss fracionadas. Monitorar SpO₂ e ETCO₂ continuamente',
    'APNEA — Usar apenas em ambiente monitorizado; ter naloxona + flumazenil disponibles; monitorar SpO₂ e ETCO₂',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('tramadol', 'quetiapina', InteractionSeverity.moderate,
    'Quetiapina inibe parcialmente CYP2D6, podendo aumentar os niveles de tramadol. Ambos abaixam o limiar convulsivo e têm efectos sedantes',
    'Convulsiones, sedación excesiva, síndrome serotoninérgica leve',
    'Usar com cautela. Evitar en pacientes com histórico de convulsiones. Monitorar sedación e limiar convulsivo',
    'CONVULSIONES + SEDAÇÃO — Usar com cautela; ambos abaixam limiar convulsivo; evitar em epilépticos',
    EvidenceLevel.probable,
    {RiskType.seizure, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('tramadol', 'haloperidol', InteractionSeverity.moderate,
    'Haloperidol inibe CYP2D6, podendo aumentar os niveles de tramadol e seu metabolito ativo. Ambos abaixam o limiar convulsivo',
    'Convulsiones, sedación excesiva, síndrome serotoninérgica',
    'Usar com cautela. Evitar en pacientes com epilepsia. Para analgesia: preferir morfina com haloperidol',
    'CONVULSIONES — Evitar em epilépticos; preferir morfina para analgesia com haloperidol',
    EvidenceLevel.probable,
    {RiskType.seizure, RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── MIRTAZAPINA × outros ──────────────────────────────────────────────────

  ('mirtazapina', 'quetiapina', InteractionSeverity.moderate,
    'Efectos sedantes aditivos (ambas têm potente atividade anti-H1). Riesgo serotoninérgico teórico. Quetiapina prolonga QTc',
    'Sedación profunda e prolongada, especialmente ao inicio. Riesgo de quedas en ancianos. QTc prolongado',
    'Monitorar sedación, especialmente nas primeiras semanas. Evitar en ancianos com riesgo de quedas. Monitorar ECG',
    'SEDAÇÃO PROFUNDA — Monitorar sedación; evitar en ancianos com riesgo de quedas; monitorar ECG',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('mirtazapina', 'haloperidol', InteractionSeverity.moderate,
    'Efectos sedantes aditivos. Haloperidol prolonga QTc; mirtazapina prolonga QTc modestamente. Combinación usada em alucinações + insônia em cuidados paliativos',
    'Sedación excesiva, prolongación QTc, hipotensión ortostática, riesgo de quedas en ancianos',
    'Monitorar ECG (QTc) e sedación. Usar dosis mínimas. Em CP: titulación cuidadosa com monitoramento',
    'QT PROLONGADO + SEDAÇÃO — Monitorar ECG e sedación; usar dosis mínimas',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('mirtazapina', 'olanzapina', InteractionSeverity.moderate,
    'Efectos sedantes, antihistamínicos e metabólicos aditivos. Ambas aumentam peso e riesgo de síndrome metabólica',
    'Sedación intensa, aumento de peso significativo, resistência à insulina, dislipidemia',
    'Monitorar peso, glucemia, perfil lipídico e presión arterial. Usar dosis mínimas. Evitar en pacientes com obesidade ou DM2',
    'SÍNDROME METABÓLICA + SEDAÇÃO — Monitorar peso, glucemia e lipídios; evitar en pacientes obesos/diabéticos',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),

    // ── QUETIAPINA / HALOPERIDOL / OLANZAPINA × entre si ─────────────────────

  ('quetiapina', 'haloperidol', InteractionSeverity.major,
    'Ambos prolongam o QTc (haloperidol é um dos mais potentes; quetiapina também). Efectos sedantes e extrapiramidais aditivos',
    'QTc prolongado com alto riesgo de torsades de pointes. Sedación excesiva. Somatório de efectos extrapiramidais. Raramente indicado combinar dois antipsicóticos',
    'Evitar combinación. Raramente indicada (exceto transição controlada). Se usada: monitorar ECG rigurosamente, corrigir electrolitos, usar dosis mínimas',
    'QT PROLONGADO GRAVE — Evitar combinación de antipsicóticos; monitorar ECG si es indispensable',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('quetiapina', 'olanzapina', InteractionSeverity.moderate,
    'Ambas têm efectos sedantes, metabólicos e anticolinérgicos aditivos. Raramente indicada a combinación',
    'Sedación excesiva, síndrome metabólica, efectos anticolinérgicos aditivos. Sem benefício clínico adicional sobre monoterapia em dosiss adecuadas',
    'Evitar combinación. Otimizar dosis del antipsicótico único antes de combinar. Se usada: monitorar peso, glucemia, sedación',
    'EFEITOS METABÓLICOS + SEDAÇÃO ADITIVOS — Evitar; otimizar monoterapia antes de combinar antipsicóticos',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('haloperidol', 'olanzapina', InteractionSeverity.moderate,
    'Efectos extrapiramidais aditivos (haloperidol D2 típico; olanzapina atípico). Ambos prolongam QTc. Raramente indicada a combinación',
    'Sintomas extrapiramidais graves (acatisia, distonia), sedación excesiva, QTc prolongado',
    'Evitar combinación de antipsicóticos. Se usada em transição: monitorar síntomas extrapiramidais e ECG',
    'EXTRAPIRAMIDAL + QT PROLONGADO — Evitar; monitorar síntomas EPS e ECG na transição',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),

    // ── CARBONATO DE LÍTIO × SNC (pares ausentes relevantes) ─────────────────

  ('carbonato de litio', 'isrs', InteractionSeverity.major,
    'Lítio tem propriedades serotoninérgicas (aumenta síntese e liberação de 5-HT). ISRSs inibem recaptação de serotonina. Combinación usada em depressão refratária, mas com riesgo serotoninérgico',
    'Síndrome serotoninérgica: tremor, mioclonias, diaforese, hipertermia, agitação, especialmente com fluoxetina (que também inibe CYP2D6 e pode alterar excreción renal de lítio)',
    'Combinación usada em psiquiatria com monitoramento. Titular lentamente. Monitorar nivel sérico de lítio (alvo 0,6-1,0 mEq/L) e signos serotoninérgicos',
    'SÍNDROME SEROTONINÉRGICA — Combinación usada em DR; monitorar nivel sérico de lítio e signos serotoninérgicos',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbonato de litio', 'tramadol', InteractionSeverity.major,
    'Lítio tem propriedades serotoninérgicas + tramadol inibe recaptação de serotonina. Ambos abaixam o limiar convulsivo',
    'Síndrome serotoninérgica e convulsiones por mecanismos aditivos',
    'Evitar combinación. Para analgesia com lítio: preferir paracetamol (cuidado com AINEs — alteram excreción renal de lítio) ou morfina',
    'SÍNDROME SEROTONINÉRGICA + CONVULSIONES — Evitar tramadol com lítio; usar paracetamol ou morfina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.seizure},
    [_kRefGG, _kRefMdx]),


  ('carbonato de litio', 'imao', InteractionSeverity.major,
    'Lítio aumenta síntese de serotonina; IMAOs inibem sua degradação. Interacción com potencial serotoninérgico significativo',
    'Síndrome serotoninérgica, crisis adrenérgica, toxicidad do lítio por interacciones hemodinâmicas',
    'Evitar combinación. Período de lavado de 14 dias do IMAO antes de iniciar lítio. Monitorar nivel sérico de lítio si se mantienes',
    'SÍNDROME SEROTONINÉRGICA — Evitar; período de lavado de 14 dias do IMAO',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('carbonato de litio', 'quetiapina', InteractionSeverity.moderate,
    'Combinación amplamente usada em transtorno bipolar. Quetiapina prolonga QTc; lítio prolonga QTc em toxicidad. Em dosiss terapéuticas: riesgo moderado de sedación aditiva e QTc',
    'Sedación aditiva, prolongación QTc, síndrome neuroléptica maligna raramente descrita com lítio + antipsicótico. Hiponatremia por lítio pode aumentar toxicidad',
    'Monitorar nivel sérico de lítio (0,6-1,0 mEq/L) e ECG regularmente. Manter hidratação adecuada. Monitorar electrolitos e función renal',
    'MONITORAR NÍVEL DE LÍTIO + ECG — Combinación usada em TB; manter hidratação e monitorar electrolitos',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('carbonato de litio', 'olanzapina', InteractionSeverity.moderate,
    'Combinación usada em transtorno bipolar. Efectos metabólicos (aumento de peso, hiperglucemia) aditivos. Olanzapina pode mascarar sinais de toxicidad de lítio',
    'Síndrome metabólica, aumento de peso excessivo, hiperglucemia, SNM raramente descrito',
    'Monitorar peso, glucemia, perfil lipídico e nivel sérico de lítio. Rastrear DM2. Combinación preferida ao haloperidol + lítio',
    'SÍNDROME METABÓLICA — Monitorar peso, glucemia e nivel de lítio; combinación usada em TB',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('aminoglicosideo', 'espironolactona', InteractionSeverity.minor,
    'Espironolactona pode reduzir a excreción renal de aminoglicosídeos ao competir por transportadores tubulares. Riesgo generalmente baixo',
    'Posible acumulación discreto de aminoglicosídeo com maior riesgo de nefrotoxicidad',
    'Monitorar nivel sérico do aminoglicosídeo e función renal regularmente',
    'MONITORAR — Espironolactona pode reduzir excreción renal de aminoglicosídeos; dosar nivel sérico',
    EvidenceLevel.possible,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('aminoglicosideo', 'enalapril', InteractionSeverity.moderate,
    'IECAs reduzem a TFG ao bloquear a angiotensina II (vasoconstritora da arteríola eferente), diminuindo a pressão de filtração. Em situações de hipoperfusão renal, isso pode elevar o nivel de aminoglicosídeos',
    'Riesgo aumentado de nefrotoxicidad e de acumulación de aminoglicosídeos en pacientes com TFG reducida ou hipovolemia',
    'Monitorar función renal e nivel sérico do aminoglicosídeo. Garantir euvolemia antes e durante o tratamiento. Ajustar dosis do aminoglicosídeo conforme TFG',
    'NEFROTOXICIDAD AUMENTADA — Monitorar TFG e nivel sérico; garantir euvolemia',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('aminoglicosideo', 'losartana', InteractionSeverity.moderate,
    'BRAs reduzem a TFG de forma análoga aos IECAs, podendo aumentar o riesgo de acumulación e nefrotoxicidad de aminoglicosídeos',
    'Nefrotoxicidad aumentada en pacientes com TFG reducida ou uso concomitante com outros nefrotóxicos',
    'Monitorar función renal e nivel sérico do aminoglicosídeo. Garantir euvolemia. Ajustar dosis por TFG',
    'NEFROTOXICIDAD AUMENTADA — Monitorar TFG e nivel sérico; garantir euvolemia com BRA',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── VANCOMICINA × nefrotóxicos ────────────────────────────────────────────

  ('vancomicina', 'cisplatina', InteractionSeverity.major,
    'Ambas são nefrotóxicas: cisplatina causa dano tubular por adutos de DNA e estresse oxidativo; vancomicina acumula nos túbulos por endocitose mediada por megalina. Combinación com riesgo sinérgico',
    'IRA grave, especialmente en pacientes oncológicos que já têm comprometimento renal por outros quimioterápicos. Riesgo de toxicidad permanente',
    'Separar administrações por 48-72h cuando sea posible. Hidratação vigorosa com cisplatina. Monitorar AUC de vancomicina. Considerar alternativas (linezolida, daptomicina)',
    'NEFROTOXICIDAD GRAVE — Separar por 48-72h; hidratação vigorosa; AUC-guided vancomicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('vancomicina', 'espironolactona', InteractionSeverity.minor,
    'Espironolactona compete por transportadores tubulares renais, podendo reduzir discretamente a excreción de vancomicina',
    'Posible acumulación discreto de vancomicina com riesgo aumentado de nefrotoxicidad',
    'Monitorar AUC de vancomicina e función renal durante uso concomitante',
    'MONITORAR — Posible acumulación de vancomicina; monitorar AUC e función renal',
    EvidenceLevel.possible,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('vancomicina', 'enalapril', InteractionSeverity.moderate,
    'IECAs reduzem a TFG, diminuindo a eliminación de vancomicina e aumentando o riesgo de acumulación e nefrotoxicidad',
    'Nefrotoxicidad por acumulación de vancomicina, especialmente en pacientes com TFG de base reducida',
    'Monitorar TFG e AUC de vancomicina. Ajustar dosis/intervalo de vancomicina conforme TFG. Garantir euvolemia',
    'NEFROTOXICIDAD AUMENTADA — IECA reduz eliminación de vancomicina; AUC-guided monitoring',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── CISPLATINA × electrolitos e diuréticos ────────────────────────────────

  ('cisplatina', 'furosemida', InteractionSeverity.major,
    'Cisplatina causa depleção de magnésio, potássio e cálcio. Furosemida potencializa a perda renal de electrolitos e pode exacerbar a nefrotoxicidad da cisplatina ao reduzir o volume intravascular',
    'Hipomagnesemia grave (pode causar arritmias, convulsiones, tetania), hipopotasemia, hipocalcemia. Nefrotoxicidad potencializada',
    'Reposição profilática de magnésio (MgSO4 2-4g IV) durante e después de cada ciclo. Monitorar electrolitos (Mg, K, Ca, Na) a cada ciclo. Hidratação vigorosa. Usar furosemida apenas se sobrecarga hídrica comprovada',
    'HIPOMAGNESEMIA GRAVE + NEFROTOXICIDAD — Repor MgSO4 profilático; monitorar electrolitos a cada ciclo',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('cisplatina', 'hidroclorotiazida', InteractionSeverity.major,
    'Hidroclorotiazida exacerba as perdas eletrolíticas causadas pela cisplatina (Mg, K, Na) e pode comprometer a hidratação necesaria para proteger os rins durante a quimioterapia',
    'Hipomagnesemia, hipopotasemia e hiponatremia graves. Aumento da nefrotoxicidad por depleción de volumen',
    'Considerar suspender hidroclorotiazida durante ciclos de cisplatina. Monitorar electrolitos antes, durante e después de cada ciclo. Hidratação vigorosa obrigatória com cisplatina',
    'DISTÚRBIOS ELETROLÍTICOS GRAVES + NEFROTOXICIDAD — Suspender HCTZ durante ciclos; repor electrolitos',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),


  ('cisplatina', 'enalapril', InteractionSeverity.moderate,
    'IECAs reduzem a TFG e a pressão de filtração glomerular; cisplatina já compromete o rim. Combinación aumenta riesgo de IRA. IECAs também reduzem a pressão de filtração glomerular, podendo impedir a eliminación de cisplatina',
    'IRA aditiva. Acumulación de cisplatina por reducción de la TFG → aumento da toxicidad sistêmica',
    'Considerar suspender IECA durante os ciclos de cisplatina. Monitorar creatinina e TFG rigurosamente. Manter hidratação',
    'IRA ADITIVA — Considerar suspender IECA durante ciclos de cisplatina; monitorar TFG',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── FUROSEMIDA × electrolitos e renina-angiotensina ───────────────────────

  ('furosemida', 'hidroclorotiazida', InteractionSeverity.major,
    'Combinación de diuréticos de alça + tiazídico (bloqueio sequencial nefron) tem efecto diurético sinérgico poderoso. Usada terapeuticamente em IC refratária, mas com alto riesgo de desequilíbrio',
    'Depleção grave de volume (hipotensión, pré-renal), hipopotasemia grave (arritmias ventriculares), hiponatremia, hipomagnesemia, alcalose metabólica',
    'Usar apenas sob supervisão especializada em IC refratária. Monitorar ureia, creatinina, electrolitos (K, Mg, Na) e PA diariamente ao iniciar. Reposição de potássio e magnésio obrigatória',
    'DEPLEÇÃO GRAVE DE VOLUME + HIPOCALEMIA — Monitorar electrolitos e PA diariamente; repor K e Mg',
    EvidenceLevel.established,
    {RiskType.electrolyte, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('furosemida', 'espironolactona', InteractionSeverity.moderate,
    'Combinación sinérgica e poupadora de potássio, amplamente usada em IC e cirrose. Furosemida causa hipopotasemia; espironolactona causa hiperpotasemia. O balanço é generalmente favorável, mas pode pender para qualquer lado',
    'Hipopotasemia (furosemida domina) ou hiperpotasemia (espironolactona domina, especialmente em IR). Depleción de volumen se dosiss excessivas. Ginecomastia por espironolactona',
    'Monitorar K, Mg, Na, creatinina e PA regularmente. Ajustar dosiss pelo K sérico. Reduzir espironolactona se K > 5,5 mEq/L. Evitar em TFG < 30mL/min',
    'MONITORAR POTÁSSIO — Hipopotasemia ou hiperpotasemia possíveis; ajustar dosiss pelo K sérico; evitar se TFG < 30',
    EvidenceLevel.established,
    {RiskType.electrolyte, RiskType.hyperkalemia},
    [_kRefGG, _kRefMdx]),


  ('furosemida', 'enalapril', InteractionSeverity.major,
    'IECAs reduzem a angiotensina II (responsável por manter a TFG em estados de hipovolemia). Furosemida causa depleción de volumen. A combinación pode precipitar IRA pré-renal, especialmente al iniciar IECA en pacientes já diuretizados',
    'IRA pré-renal ("first-dosis hypotension"), hipotensión grave na primeira dosis del IECA, hiperpotasemia (IECA retém K), hiponatremia',
    'Reduzir ou suspender furosemida 24-48h antes da primeira dosis del IECA. Iniciar IECA em dosis baja. Monitorar PA, creatinina e K nas primeiras 48h. Reintroduzir furosemida después de estabilização',
    'IRA POR HIPOTENSIÓN — Suspender furosemida 24-48h antes da 1ª dosis del IECA; iniciar IECA em dosis baja',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('furosemida', 'losartana', InteractionSeverity.major,
    'Interacción análoga à furosemida + enalapril. BRAs bloqueiam receptor AT1, reduzindo vasoconstrição eferente. Depleción de volumen por furosemida precipita hipotensión e IRA',
    'IRA pré-renal, hipotensión grave na primeira dosis del BRA, hiperpotasemia',
    'Reduzir furosemida 24-48h antes de iniciar losartana. Começar com dosis baja de losartana. Monitorar PA, creatinina e K nas primeiras 48h',
    'IRA POR HIPOTENSIÓN — Suspender furosemida 24-48h antes da 1ª dosis del BRA; monitorar PA e creatinina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),

    // ── HIDROCLOROTIAZIDA × renina-angiotensina e electrolitos ─────────────────

  ('hidroclorotiazida', 'espironolactona', InteractionSeverity.moderate,
    'Combinación poupadora de potássio usada em hipertensão e IC leve. HCTZ causa hipopotasemia; espironolactona causa hiperpotasemia. O balanço pode ser favorável ou pender para hiperpotasemia em IR',
    'Hiperpotasemia se TFG reducida, especialmente en ancianos diabéticos com nefropatia. Depleción de volumen se dosis altas de ambas',
    'Monitorar K, Na, Mg e creatinina. Reduzir espironolactona se K > 5,5 mEq/L. Evitar em TFG < 30mL/min ou K basal > 5,0 mEq/L',
    'HIPERPOTASEMIA EM IR — Monitorar K e TFG; evitar se K basal > 5,0 ou TFG < 30',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),


  ('hidroclorotiazida', 'losartana', InteractionSeverity.moderate,
    'Análogo ao HCTZ + enalapril. BRA + tiazídico é combinación de primeira linha para hipertensão. Riesgo de hipotensión e hiperpotasemia',
    'Hipotensión de primeira dosis, hiperpotasemia, IRA pré-renal em estados de hipovolemia',
    'Monitorar PA, K e creatinina después de inicio. Reduzir HCTZ se PA muito reducida',
    'HIPOTENSÃO + HIPERPOTASEMIA — Monitorar PA, K e creatinina; reduzir HCTZ se necesario',
    EvidenceLevel.established,
    {RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),


  ('espironolactona', 'carbonato de litio', InteractionSeverity.moderate,
    'Espironolactona pode alterar os niveles de lítio de forma impredecible. Alguns estudos mostram elevación (por retenção de Na com carga de Na baixa), outros reducción',
    'Toxicidad de lítio ou fracaso terapéutico por alteração impredecible dos niveles séricos',
    'Monitorar nivel sérico de lítio al iniciar ou modificar espironolactona. Manter ingestão de sódio estável',
    'NÍVEL DE LÍTIO IMPREVISÍVEL — Monitorar nivel sérico de lítio al iniciar espironolactona',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── CISPLATINA × outros nefrotóxicos/electrolitos ─────────────────────────

  ('cisplatina', 'espironolactona', InteractionSeverity.minor,
    'Espironolactona pode reponer potasio e magnésio perdidos pela cisplatina (efecto protetor parcial). Porém, em IRA induzida por cisplatina, a retenção de K pela espironolactona pode causar hiperpotasemia',
    'Hiperpotasemia em contexto de IRA por cisplatina. Protección parcial contra hipopotasemia/hipomagnesemia em función renal preservada',
    'Monitorar K, Mg e TFG rigurosamente. Suspender espironolactona se K > 5,5 ou em IRA',
    'HIPERPOTASEMIA EM IRA — Monitorar K e TFG; suspender espironolactona se IRA ou K > 5,5',
    EvidenceLevel.possible,
    {RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('metformina', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides sistêmicos causam hiperglucemia por múltiplos mecanismos (resistência à insulina, gliconeogênese hepática, lipólise). A metformina sozinha raramente controla a hiperglucemia induzida por corticoide',
    'Hiperglucemia grave e descontrolada durante corticoterapia, especialmente en diabéticos. Descompensação glicêmica que pode requerer insulina',
    'Aumentar monitorização da glucemia durante corticoterapia (glucemia capilar pré e pós-refeições). Metformina insuficiente em hiperglucemia grave por corticoide — adicionar sulfonilureia ou insulina. Reduzir ajustes al suspender corticoide',
    'HIPERGLICEMIA GRAVE — Corticoide antagoniza metformina; aumentar monitorização e considerar insulina',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('metformina', 'enalapril', InteractionSeverity.minor,
    'IECAs podem melhorar a sensibilidade à insulina e reduzir levemente a glucemia. Em combinación com metformina, riesgo teórico de hipoglucemia leve',
    'Hipoglucemia leve, especialmente en pacientes idosos ou com dieta restrita',
    'Monitorar glucemia. Combinación usada com frecuencia em DM2 + HAS. Ajuste raramente necesario',
    'HIPOGLICEMIA LEVE — Combinación usual; monitorar glucemia especialmente en ancianos',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── INSULINA × corticosteroides e outros ─────────────────────────────────

  ('insulina', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides causam hiperglucemia por resistência à insulina e gliconeogênese aumentada. A necessidade insulina pode aumentar dramaticamente (2-4x) durante corticoterapia intensa, especialmente em altas dosiss (> 40mg prednisona/dia)',
    'Hiperglucemia grave e cetoácidosis diabética en diabéticos tipo 1. Descompensação glicêmica intensa em tipo 2. Hipoglucemia de rebote al suspender corticoide abruptamente',
    'Aumentar dosis de insulina durante corticoterapia (monitorar glucemia capilar 4-6x/dia). Padrão típico: hiperglucemia pós-prandial dominante → preferir insulina prandial ajustada. Reduzir insulina gradualmente al suspender corticoide',
    'HIPERGLICEMIA GRAVE — Corticoide aumenta necessidade insulina 2-4x; monitorar glucemia 4-6x/dia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('insulina', 'isrs', InteractionSeverity.moderate,
    'ISRSs (especialmente fluoxetina) aumentam a sensibilidade à insulina e têm efecto hipoglucemiante modesto. En diabéticos usando insulina, podem aumentar o riesgo de hipoglucemia',
    'Hipoglucemia, especialmente nas primeiras semanas de tratamiento com ISRS',
    'Monitorar glucemia nas primeiras semanas al iniciar ISRS en pacientes usando insulina. Pode ser necesario reducir dosis de insulina',
    'HIPOGLICEMIA — ISRSs aumentam sensibilidade à insulina; monitorar glucemia al iniciar antidepresivo',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('insulina', 'sulfonilureia', InteractionSeverity.major,
    'Efecto hipoglucemiante aditivo e sinérgico: insulina reduz diretamente a glucemia; sulfonilureias estimulam a secreção pancreática de insulina. Combinación com riesgo elevado de hipoglucemia grave',
    'Hipoglucemia grave, prolongada e recorrente. Riesgo especialmente alto en ancianos, IR, desnutrição e uso de sulfoniureias de longa ação (glibenclamida)',
    'Monitorar glucemia frecuentemente. Preferir sulfonilureias de ação curta (gliclazida, glipizida). Evitar glibenclamida en ancianos. Reducir dosiss ao adicionar insulina. Ter glicose oral ou IV disponible',
    'HIPOGLUCEMIA GRAVE — Efecto aditivo; preferir sulfonilureia de ação curta; monitorar glucemia frecuentemente',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── SULFONILUREIA × outros ────────────────────────────────────────────────

  ('sulfonilureia', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides antagonizam completamente o efecto das sulfonilureias ao causar resistência à insulina e aumentar a gliconeogênese. A sulfonilureia torna-se ineficaz durante corticoterapia de médio a alta dosis',
    'Hiperglucemia grave e refratária durante corticoterapia en diabéticos tipo 2. Hipoglucemia grave al suspender corticoide (efecto rebote da sulfonilureia)',
    'Aumentar dosis de la sulfonilureia ou adicionar insulina durante corticoterapia. Monitorar glucemia 4x/dia. Reduzir sulfonilureia gradualmente al suspender corticoide para evitar hipoglucemia de rebote',
    'HIPERGLICEMIA GRAVE — Corticoide antagoniza sulfonilureia; adicionar insulina e monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('sulfonilureia', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP2C9, a principal vía de metabolismo de glibenclamida, glipizida e gliclazida. Pode aumentar os niveles em 2-3x',
    'Hipoglucemia grave y prolongada por acumulación da sulfonilureia. Glibenclamida (vida media longa) tem riesgo especialmente elevado',
    'Evitar combinación com glibenclamida (alto riesgo). Se fluconazol necesario: reducir dosis da sulfonilureia em 50%, monitorar glucemia frecuentemente, ter glicose disponible. Preferir fluconazol de curto curso',
    'HIPOGLUCEMIA GRAVE — Fluconazol aumenta sulfonilureia 2-3x; reducir dosis 50% e monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('sulfonilureia', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e pode inibir parcialmente CYP2C9, aumentando os niveles de glibenclamida e outras sulfonilureias',
    'Hipoglucemia grave por acumulación da sulfonilureia durante o curso de antibioticoterapia',
    'Monitorar glucemia frecuentemente durante curso de claritromicina. Reducir dosis da sulfonilureia se necesario. Preferir azitromicina cuando sea posible',
    'HIPOGLICEMIA — Claritromicina aumenta sulfonilureia; monitorar glucemia; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('sulfonilureia', 'isrs', InteractionSeverity.moderate,
    'ISRSs (fluoxetina especialmente) inibem CYP2C9, podendo aumentar os niveles de sulfonilureias CYP2C9-dependentes. Também têm efecto hipoglucemiante intrínseco',
    'Hipoglucemia por efecto aditivo e por inhibición do metabolismo de la sulfonilureia',
    'Monitorar glucemia nas primeiras semanas al iniciar ISRS. Pode ser necesario reducir dosis da sulfonilureia',
    'HIPOGLICEMIA — ISRSs inibem CYP2C9 e aumentam sensibilidade à insulina; monitorar glucemia',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── GLIBENCLAMIDA (sulfonilureia de longa ação) × outros ─────────────────

  ('glibenclamida', 'betabloqueador', InteractionSeverity.major,
    'Betabloqueadores (especialmente não-seletivos) mascaram sintomas adrenérgicos de hipoglucemia induzida por glibenclamida. Glibenclamida tem vida media de 24h e maior potência hipoglucemiante entre as sulfonilureias',
    'Hipoglucemia silenciosa grave, especialmente en ancianos, IR e jejum. Riesgo elevado de internación por coma hipoglicêmico',
    'Evitar glibenclamida en ancianos + betabloqueador. Preferir sulfonilureias de ação curta (gliclazida). Si se mantiene: preferir betabloqueadores seletivos (metoprolol, bisoprolol) e monitorar glucemia',
    'HIPOGLICEMIA SILENCIOSA GRAVE — Evitar glibenclamida en ancianos; preferir betabloqueadores seletivos e gliclazida',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('glibenclamida', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides antagonizam o efecto de glibenclamida por resistência à insulina. Al suspender o corticoide, o efecto da glibenclamida (já sem antagonismo) causa hipoglucemia grave de rebote',
    'Hiperglucemia grave durante corticoterapia. Hipoglucemia grave de rebote al suspender corticoide, especialmente com glibenclamida de ação prolongada',
    'Evitar glibenclamida durante corticoterapia; preferir insulina para controle. Al suspender corticoide: reduzir hipoglucemiantes gradualmente. Monitorar glucemia 4x/dia',
    'HIPOGLICEMIA DE REBOTE — Al suspender corticoide, riesgo alto de hipoglucemia grave com glibenclamida; preferir insulina',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── CORTICOSTEROIDE SISTÊMICO × outros ────────────────────────────────────

  ('corticosteroide sistemico', 'aine', InteractionSeverity.major,
    'Corticosteroides inibem síntese de prostaglandinas (via lipocortina/PLA2) e prejudicam a integridade da mucosa gástrica. AINEs inibem COX-1, reduzindo prostaglandinas citoprotetoras. Efecto sinérgico na lesão da mucosa GI',
    'Úlcera péptica, hemorragia digestiva alta (riesgo 4-15x maior que com cada fármaco isolado), perfuração. Riesgo especialmente alto en ancianos, história de úlcera e uso de anticoagulantes',
    'Evitar combinación cuando sea posible. Si es necesaria: usar o AINE mais seletivo (COX-2 seletivo ou ibuprofeno em dosis baja) + IBP profilático (omeprazol 20mg/pantoprazol 40mg) obligatorio. Evitar uso prolongado',
    'HEMORRAGIA DIGESTIVA — Riesgo 4-15x maior; usar IBP profilático obligatorio si se mantiene a combinación',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('corticosteroide sistemico', 'warfarina', InteractionSeverity.major,
    'Corticosteroides em altas dosiss têm efecto anticoagulante intrínseco e podem aumentar os efectos da varfarina por múltiplos mecanismos (inducción de CYP com dosis altas paradoxalmente inibindo CYP2C9 em dosis bajas). Relação impredecible',
    'Variação impredecible do INR (aumento ou reducción) com riesgo de sangrado ou trombosis. Em uso concomitante com AINEs: riesgo de sangrado gastrointestinal grave',
    'Monitorar INR frecuentemente ao iniciar, mudar dosis ou suspender corticoide. Evitar combinación tripla com AINE + varfarina + corticoide (riesgo extremamente alto de hemorragia GI)',
    'INR IMPREVISÍVEL — Monitorar INR frecuentemente ao modificar corticoide; evitar tripla combinación com AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('corticosteroide sistemico', 'isrs', InteractionSeverity.moderate,
    'Corticosteroides causam transtornos do humor (psicose, mania, depressão, ansiedade) que podem ser potencializados por ISRSs. Fluoxetina inibe CYP2C9 (metabolismo de alguns corticosteroides)',
    'Psicose por corticoide, mania, insônia grave. Posible elevación dos niveles de corticosteroides com fluoxetina',
    'Monitorar estado mental durante corticoterapia. Usar ISRSs se necesario para sintomas depressivos pós-corticoide (mas aguardar reducción de dosis del corticoide). Preferir sertralina ou escitalopram',
    'TRANSTORNOS DO HUMOR — Monitorar estado mental; ISRS pode ser necesario para depressão pós-corticoide',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('corticosteroide sistemico', 'ciclosporina', InteractionSeverity.major,
    'Corticosteroides inibem CYP3A4 em baixas dosiss e induzem em altas dosiss — efecto impredecible sobre ciclosporina. Ciclosporina inibe o metabolismo de metilprednisolona, aumentando seus niveles',
    'Toxicidad de corticoide (Cushing iatrogênico, hiperglucemia, osteoporose) por aumento de los niveles. Posible falha inmunosupresora se corticoide altera ciclosporina. Efectos inmunosupresores aditivos',
    'Monitorar niveles de ciclosporina e efectos do corticoide. Combinación usada em transplante (padrão), mas com monitoramento rigoroso de función renal, glucemia, PA e peso',
    'TOXICIDADE ADITIVA — Combinación padrão em transplante; monitorar ciclosporina, glucemia, PA e peso',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('corticosteroide sistemico', 'tacrolimo', InteractionSeverity.major,
    'Corticosteroides podem induzir CYP3A4 em altas dosiss, reduzindo tacrolimo; em retirada de corticoide, os niveles de tacrolimo podem elevar-se dramaticamente. Tacrolimo é diabetogênico + corticoide é diabetogênico',
    'Flutuações dos niveles de tacrolimo (rejeição ou toxicidad) ao modificar dosis de corticoide. Hiperglucemia grave (NODAT — Novo-Onset Diabetes After Transplant)',
    'Monitorar C0 de tacrolimo ao modificar dosis de corticoide. Rastrear NODAT com glucemia em jejum e HbA1c. Combinación padrão em transplante com monitoramento rigoroso',
    'FLUTUAÇÕES DE TACROLIMO + DIABETES — Monitorar C0 ao modificar corticoide; rastrear NODAT',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('corticosteroide sistemico', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Corticosteroides sistêmicos em dosiss inmunosupresoras (≥ 20mg/dia de prednisona ou equivalente por ≥ 2 semanas) causam imunossupresión que impede resposta adecuada a vacinas vivas e pode levar à enfermedad vacinal disseminada',
    'Enfermedad vacinal disseminada (varicela, sarampo, febre amarela) com riesgo de muerte. Falha de imunização por resposta imune inadecuada',
    'CONTRAINDICADO vacinas vivas durante corticoterapia inmunosupresora. Aguardar ≥ 4 semanas después de suspensión do corticoide antes de vacinas vivas. Vacinas inativadas podem ser administradas (resposta pode ser subótima)',
    'CONTRAINDICADO — Enfermedad vacinal disseminada; aguardar 4 semanas después de suspensión do corticoide',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('levotiroxina', 'omeprazol', InteractionSeverity.moderate,
    'IBPs reduzem a acidez gástrica, alterando a dissolução e absorción de levotiroxina (que requer pH ácido para absorción ótima)',
    'Hipotiroidismo por absorción reducida de levotiroxina, especialmente com uso prolongado de IBP',
    'Tomar levotiroxina em jejum, separada dos IBPs por pelo menos 30-60 minutos. Monitorar TSH periodicamente en pacientes em uso prolongado de IBP + levotiroxina',
    'HIPOTIROIDISMO — Tomar levotiroxina separada do IBP por 30-60min; monitorar TSH periodicamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('levotiroxina', 'sulfato ferroso', InteractionSeverity.major,
    'Ferro forma complexos insolúveis com levotiroxina no intestino, reduzindo a absorción em 30-50%. Interacción clinicamente relevante e frecuentemente negligenciada',
    'Hipotiroidismo por absorción reducida de levotiroxina, especialmente em gestantes com hipotiroidismo (que usam ferro + levotiroxina)',
    'Separar levotiroxina do sulfato ferroso por pelo menos 4 horas. Tomar levotiroxina em jejum; ferro com as refeições. Monitorar TSH después de inicio de suplementação de ferro',
    'HIPOTIROIDISMO — Separar levotiroxina do ferro por pelo menos 4 horas; monitorar TSH',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('levotiroxina', 'warfarina', InteractionSeverity.major,
    'Levotiroxina aumenta o catabolismo dos fatores de coagulação vitamina K-dependentes e potencializa o efecto anticoagulante da varfarina. O hipotiroidismo reduz o catabolismo, diminuindo o efecto da varfarina',
    'Aumento do INR (toxicidad) ao tratar hipotiroidismo com levotiroxina en pacientes já em uso de varfarina. Reducción del INR (trombosis) em hipotiroidismo não tratado',
    'Monitorar INR frecuentemente (a cada 1-2 semanas) ao iniciar, ajustar dosis ou suspender levotiroxina. Antecipar necessidade reducción de varfarina ao tratar hipotiroidismo',
    'SANGRADO — Levotiroxina aumenta INR; monitorar INR frecuentemente ao ajustar dosis de tireoide',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('levotiroxina', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Corticosteroides em altas dosiss podem suprimir o TSH e aumentar o metabolismo de T4 → T3 reverso (forma inativa). Em hipotiroidismo com adrenal insuficiente simultânea: corticoide deve ser repostos antes da levotiroxina',
    'Crise tirotóxica se levotiroxina iniciada antes de reposição de cortisol em insuficiencia adrenal concomitante. Em corticoterapia longa: hipotiroidismo subclínico por supresión de TSH',
    'Em suspeita de insuficiencia adrenal + hipotiroidismo: iniciar corticoide antes da levotiroxina. Monitorar TSH e T4 livre periodicamente em corticoterapia prolongada',
    'CRISE TIROTÓXICA EM IA — Iniciar corticoide antes da levotiroxina quando há insuficiencia adrenal concomitante',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('semaglutida', 'warfarina', InteractionSeverity.moderate,
    'Semaglutida altera o esvaziamento gástrico, podendo alterar a absorción de varfarina. Melhora do controle glicêmico também pode alterar o metabolismo de varfarina indiretamente',
    'Alteração do INR (aumento ou reducción) al iniciar ou ajustar semaglutida',
    'Monitorar INR nas primeiras 4 semanas al iniciar semaglutida. Ajustar dosis de warfarina según sea necesario',
    'INR ALTERADO — Monitorar INR nas primeiras semanas al iniciar semaglutida',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('semaglutida', 'metformina', InteractionSeverity.minor,
    'Combinación de primeira linha em DM2. Semaglutida pode causar náusea/vômitos (especialmente nas primeiras 8 semanas), que podem ser exacerbados com metformina GI',
    'Náusea e intolerância GI aumentadas, podendo levar à descontinuación. Riesgo de hipoglucemia leve pela somatória do efecto hipoglucemiante de ambos',
    'Titular semaglutida lentamente (0,25mg/semana por 4 semanas, depois 0,5mg). Tomar metformina com refeições para minimizar GI. Monitorar tolerância GI',
    'INTOLERÂNCIA GI — Titular semaglutida lentamente; tomar metformina com refeições; combinación de 1ª linha',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),


  ('semaglutida', 'corticosteroide sistemico', InteractionSeverity.major,
    'Corticosteroides antagonizam o efecto hipoglucemiante da semaglutida por resistência à insulina e gliconeogênese aumentada. O efecto de esvaziamento gástrico lento da semaglutida não protege contra a hiperglucemia induzida por corticoide',
    'Hiperglucemia grave e refratária durante corticoterapia en pacientes com DM2 em uso de semaglutida',
    'Aumentar monitorização da glucemia durante corticoterapia. Semaglutida insuficiente em hiperglucemia grave por corticoide → adicionar insulina. Reduzir ajustes al suspender corticoide',
    'HIPERGLICEMIA GRAVE — Corticoide antagoniza semaglutida; adicionar insulina durante corticoterapia',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx]),

    // ── CICLOSPORINA × outros inmunosupresores ───────────────────────────────

  ('ciclosporina', 'tacrolimo', InteractionSeverity.contraindicated,
    'Ambos são inhibidores de calcineurina com mecanismos sobrepostos e nefrotoxicidad aditiva. A combinación não é clinicamente justificada e representa sobreposição de classe sem benefício adicional',
    'Nefrotoxicidad grave aditiva, hipertensão, hiperpotasemia, neurotoxicidad (tremor, cefaleia, convulsiones). Ausência de benefício inmunosupresor adicional sobre monoterapia',
    'CONTRAINDICADO. Usar apenas um inhibidor de calcineurina por vez. Transição entre os dois deve ser feita com período de lavado e monitoramento de C0',
    'CONTRAINDICADO — Nefrotoxicidad aditiva sem benefício; usar apenas um inhibidor de calcineurina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'azatioprina', InteractionSeverity.major,
    'Ciclosporina inibe TPMT (tiopurina metiltransferase), enzima responsável pela inativação da azatioprina. Pode aumentar os niveles do metabólito ativo (6-TGN) em 3-5x. Combinación usada em transplante mas com riesgo de mielotoxicidad',
    'Mielossupresión grave (leucopenia, trombocitopenia, anemia) por acumulación de metabólitos ativos da azatioprina. Maior riesgo en pacientes com atividade TPMT reducida',
    'Monitorar hemograma semanalmente nas primeiras 4-8 semanas e mensalmente depois. Reducir dosis de azatioprina em 50% quando combinada com ciclosporina. Genotipagem de TPMT recomendada antes de iniciar',
    'MIELOSUPRESIÓN GRAVE — Ciclosporina inibe TPMT; reduzir azatioprina 50% e monitorar hemograma semanalmente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'estatina', InteractionSeverity.major,
    'Ciclosporina inibe OATP1B1/1B3 (transportadores de captação hepática) e CYP3A4, aumentando os niveles de todas as estatinas. Sinvastatina e lovastatina são mais afetadas. A bula da sinvastatina contraindica uso com ciclosporina',
    'Rabdomiólisis grave por acumulación de estatinas en pacientes trasplantados. Incidência de miopatía 2-10x maior com ciclosporina',
    'CONTRAINDICADO: ciclosporina + sinvastatina ou lovastatina. Usar pravastatina (10-20mg max), fluvastatina ou rosuvastatina em dosis reducida. Monitorar CK e síntomas musculares regularmente',
    'RABDOMIÓLISIS — Ciclosporina aumenta estatinas; usar pravastatina ou fluvastatina em dosis reducida; contraindica sinvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'colchicina', InteractionSeverity.contraindicated,
    'Ciclosporina inibe P-gp e CYP3A4, as principais vias de eliminación da colchicina. Pode aumentar os niveles de colchicina em 2-4x. Colchicina já tem janela terapéutica estreita',
    'Toxicidade grave de colchicina: miopatía, neuropatia periférica, pancitopenia, disfunción hepática, IRA, colapso multissistêmico e morte. Casos fatais documentados en pacientes trasplantados',
    'CONTRAINDICADO em IR (TFG < 60mL/min) + ciclosporina. Em IR normal: reducir dosis de colchicina em 50%, limitar a 1 curso curto (3-5 dias), monitorar CK, hemograma e función renal. Preferir corticoide ou AINE para crise de gota',
    'CONTRAINDICADO em IR — Toxicidade fatal; preferir corticoide para gota en pacientes trasplantados com ciclosporina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciclosporina', 'metformina', InteractionSeverity.moderate,
    'Ciclosporina é diabetogênica (causa NODAT) e pode competir com metformina por transportadores OCT2 renais, reduzindo a excreción de metformina. Nefrotoxicidad de ciclosporina pode precipitar acumulación de metformina',
    'Hiperglucemia (NODAT) e acumulación de metformina em disfunción renal por ciclosporina → riesgo de acidosis láctica',
    'Monitorar TFG, glucemia e lactato. Suspender metformina se TFG < 45mL/min ou em deterioração renal. Rastrear NODAT com glucemia em jejum',
    'NODAT + ACIDOSIS LÁCTICA — Monitorar TFG, glucemia e lactato; suspender metformina se TFG < 45',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('ciclosporina', 'vancomicina', InteractionSeverity.major,
    'Ambas são nefrotóxicas: ciclosporina causa vasoconstricção da arteríola aferente; vancomicina acumula nos túbulos. Efecto aditivo/sinérgico en pacientes trasplantados que já têm TFG reducida',
    'IRA grave en pacientes trasplantados, podendo simular ou precipitar rechazo agudo. Acumulación de vancomicina por TFG reducida cria ciclo de toxicidad crescente',
    'Monitorar AUC de vancomicina diariamente. Monitorar C0 de ciclosporina. Manter euvolemia. Considerar alternativas (linezolida, daptomicina) para reduzir exposición à vancomicina',
    'IRA GRAVE EM TRANSPLANTADOS — AUC-guided vancomicina; monitorar C0 de ciclosporina; considerar alternativa antibiótica',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

    // ── TACROLIMO × outros ────────────────────────────────────────────────────

  ('tacrolimo', 'azatioprina', InteractionSeverity.moderate,
    'Tacrolimo pode inibir parcialmente TPMT, aumentando metabólitos ativos de azatioprina (efecto menor que ciclosporina). Imunossupresión aditiva aumenta riesgo infeccioso',
    'Mielossupresión moderada, infecções oportunistas por imunossupresión excessiva',
    'Monitorar hemograma regularmente. Genotipagem de TPMT antes de iniciar. Reduzir azatioprina se leucopenia',
    'MIELOSUPRESIÓN — Monitorar hemograma; genotipagem de TPMT antes de iniciar azatioprina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('tacrolimo', 'estatina', InteractionSeverity.moderate,
    'Tacrolimo inibe modestamente OATP1B1 e CYP3A4, aumentando os niveles de estatinas (efecto menor que ciclosporina). Sinvastatina tem maior riesgo; pravastatina menor',
    'Riesgo aumentado de miopatía/rabdomiólisis en pacientes trasplantados. Menor que com ciclosporina, mas clinicamente relevante',
    'Monitorar CK e síntomas musculares. Usar estatinas em dosiss mais baixas. Evitar sinvastatina em altas dosiss. Pravastatina e fluvastatina são preferíveis',
    'MIOPATIA — Monitorar CK; usar estatinas em dosis bajas; preferir pravastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('tacrolimo', 'vancomicina', InteractionSeverity.major,
    'Análogo à interacción ciclosporina + vancomicina. Ambas são nefrotóxicas com efecto aditivo en pacientes trasplantados',
    'IRA grave en pacientes trasplantados com tacrolimo + vancomicina, especialmente se TFG já comprometida',
    'AUC-guided vancomicina. Monitorar C0 de tacrolimo. Considerar alternativas antibióticas. Manter euvolemia',
    'IRA GRAVE — AUC-guided vancomicina; monitorar C0 de tacrolimo; considerar linezolida ou daptomicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('tacrolimo', 'metformina', InteractionSeverity.moderate,
    'Tacrolimo é diabetogênico (NODAT). Em disfunción renal por tacrolimo, metformina pode acumular com riesgo de acidosis láctica',
    'NODAT (diabetes pós-transplante) e acidosis láctica por acumulación de metformina em TFG reducida',
    'Rastrear NODAT com glucemia em jejum e HbA1c. Monitorar TFG. Suspender metformina se TFG < 45. Preferir insulina para NODAT en pacientes trasplantados',
    'NODAT + ACIDOSIS LÁCTICA — Monitorar TFG; suspender metformina se TFG < 45; preferir insulina para NODAT',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('azatioprina', 'warfarina', InteractionSeverity.major,
    'Azatioprina pode reduzir o efecto anticoagulante da varfarina por mecanismo não totalmente elucidado (posible inducción de enzimas de metabolismo)',
    'Reducción del INR → riesgo de tromboembolismo en pacientes que necessitam de anticoagulação (ex.: válvula cardíaca, FA)',
    'Monitorar INR frecuentemente ao iniciar, ajustar ou suspender azatioprina. Aumentar dosis de varfarina según sea necesario',
    'TROMBOSIS — Azatioprina reduz INR; monitorar INR frecuentemente al iniciar ou suspender',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('azatioprina', 'isrs', InteractionSeverity.minor,
    'Riesgo teórico de mielosupresión aditiva (efectos hematológicos raros dos ISRSs + mielosupresión da azatioprina)',
    'Mielossupresión aumentada, trombocitopenia (ISRSs podem raramente causar trombocitopenia por mecanismo imunológico)',
    'Monitorar hemograma periodicamente. Combinación generalmente bem tolerada, mas monitorar se sinais de mielosupresión',
    'MONITORAR HEMOGRAMA — Riesgo teórico de mielosupresión aditiva com ISRSs',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('azatioprina', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Azatioprina causa imunossupresión por reducción de linfócitos T e B, impedindo resposta imune adecuada a vacinas vivas e podendo causar enfermedad vacinal disseminada',
    'Enfermedad vacinal disseminada (varicela, sarampo, febre amarela) potencialmente fatal. Falha de imunização',
    'CONTRAINDICADO. Atualizar vacinação com vacinas vivas antes de iniciar azatioprina. Aguardar ≥ 3 meses después de suspensión. Vacinas inativadas podem ser usadas (resposta subótima esperada)',
    'CONTRAINDICADO — Enfermedad vacinal disseminada; vacinar com vacinas vivas antes de iniciar azatioprina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── BARICITINIBE / TOFACITINIBE (JAK inhibidores) × outros ────────────────

  ('baricitinibe', 'tofacitinibe', InteractionSeverity.contraindicated,
    'Ambos são inhibidores de JAK com mecanismos de imunossupresión sobrepostos. Combinación sem benefício clínico e com riesgo aumentado de infecções oportunistas graves, tromboembolismo e malignidades',
    'Imunossupresión excessiva → infecções oportunistas graves (TB, herpes zóster disseminado, pneumocistose, citomegalovirose), tromboembolismo venoso, malignidades',
    'CONTRAINDICADO. Usar apenas um inhibidor de JAK por vez. Trocar de um para outro apenas después de período de lavado adecuado',
    'CONTRAINDICADO — Imunossupresión aditiva sem benefício; usar apenas um inhibidor de JAK',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('baricitinibe', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Baricitinibe causa imunossupresión por inhibición de JAK1/2, comprometendo a resposta imune a vacinas vivas e podendo causar enfermedad vacinal disseminada',
    'Enfermedad vacinal disseminada potencialmente fatal. Falha de imunização',
    'CONTRAINDICADO. Atualizar vacinação (incluindo herpes zóster) antes de iniciar baricitinibe. Vacinas inativadas preferidas',
    'CONTRAINDICADO — Vacinas vivas contraindicadas; atualizar vacinação antes de iniciar baricitinibe',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('tofacitinibe', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Análogo ao baricitinibe + vacinas vivas. Tofacitinibe inibe JAK1/3, causando imunossupresión',
    'Enfermedad vacinal disseminada potencialmente fatal',
    'CONTRAINDICADO. Atualizar vacinação antes de iniciar tofacitinibe. Herpes zóster (vacina inativada Shingrix) recomendada antes de iniciar',
    'CONTRAINDICADO — Vacinas vivas contraindicadas; atualizar vacinação antes de iniciar tofacitinibe',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('tofacitinibe', 'isrs', InteractionSeverity.minor,
    'Riesgo análogo ao baricitinibe + ISRS',
    'Neutropenia aumentada en pacientes susceptíveis',
    'Monitorar hemograma periodicamente',
    'MONITORAR HEMOGRAMA — Riesgo teórico de neutropenia aditiva com ISRSs',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('baricitinibe', 'warfarina', InteractionSeverity.moderate,
    'Baricitinibe pode alterar o INR por efecto inflamatório sistêmico (inflamação eleva os fatores de coagulação; ao reduzir inflamação, o IECA pode aumentar o INR). Efecto indireto por controle da artrite',
    'Alteração do INR al iniciar ou ajustar baricitinibe, especialmente en pacientes com AR+FA em uso de varfarina',
    'Monitorar INR nas primeiras 4-8 semanas al iniciar baricitinibe. Ajustar varfarina según sea necesario',
    'INR ALTERADO — Monitorar INR al iniciar baricitinibe en pacientes usando varfarina',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── TOCILIZUMABE × outros ─────────────────────────────────────────────────

  ('tocilizumabe', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Tocilizumabe (anti-IL-6R) causa imunossupresión significativa, comprometendo a resposta a vacinas vivas e podendo causar enfermedad vacinal disseminada',
    'Enfermedad vacinal disseminada. Falha de imunização',
    'CONTRAINDICADO. Atualizar vacinação antes de iniciar tocilizumabe. Vacinas inativadas (influenza, pneumococo, herpes zóster inativada) recomendadas',
    'CONTRAINDICADO — Vacinas vivas contraindicadas; atualizar vacinação antes de iniciar tocilizumabe',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

    // ── NATALIZUMABE × outros ─────────────────────────────────────────────────

  ('natalizumabe', 'tofacitinibe', InteractionSeverity.contraindicated,
    'Natalizumabe (anti-α4-integrina) causa imunossupresión por sequestro de linfócitos. Combinación com tofacitinibe (JAK inhibidor) resulta em imunossupresión excessiva com alto riesgo de infecções oportunistas',
    'Leucoencefalopatía multifocal progressiva (LMP por vírus JC), pneumonia por pneumocystis, infecções oportunistas graves, reativação viral',
    'CONTRAINDICADO. Qualquer combinación de natalizumabe com inmunosupresor potente é de alto riesgo. Período de lavado obligatorio ao trocar',
    'CONTRAINDICADO — LMP e infecções oportunistas fatais; no combinar natalizumabe com inmunosupresores potentes',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('natalizumabe', 'baricitinibe', InteractionSeverity.contraindicated,
    'Análogo ao natalizumabe + tofacitinibe. Imunossupresión excessiva com riesgo de LMP e infecções oportunistas graves',
    'LMP fatal, infecções oportunistas graves',
    'CONTRAINDICADO. No combinar natalizumabe com inhibidores de JAK',
    'CONTRAINDICADO — LMP e infecções oportunistas fatais; no combinar',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('natalizumabe', 'vacinas vivas', InteractionSeverity.contraindicated,
    'Natalizumabe causa imunossupresión profunda (sequestro de linfócitos no sangue, impedindo migração tecidual). Vacinas vivas são contraindicadas',
    'Enfermedad vacinal disseminada. Riesgo de LMP aumentado por qualquer estímulo imune',
    'CONTRAINDICADO. Atualizar vacinação antes de iniciar natalizumabe. Después de suspensión, aguardar ≥ 6 meses (restauração imune demora)',
    'CONTRAINDICADO — Enfermedad vacinal disseminada; atualizar antes de iniciar; aguardar 6 meses después de suspensión',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),

    // ── VEDOLIZUMABE × outros ─────────────────────────────────────────────────

  ('vedolizumabe', 'tofacitinibe', InteractionSeverity.major,
    'Vedolizumabe (anti-α4β7 gut-selective) + tofacitinibe (JAK inhibidor sistêmico): imunossupresión aditiva, especialmente na mucosa intestinal. Riesgo de infecções oportunistas gastrointestinais e sistêmicas',
    'Infecções oportunistas gastrointestinais (CMV colitis, histoplasmose intestinal), infecções sistêmicas. Tromboembolismo venoso (tofacitinibe)',
    'Evitar combinación. Se necesario em DII refratária: supervisão especializada, monitoramento intensivo de infecções. Atualizar vacinações',
    'INFECÇÕES OPORTUNISTAS — Evitar combinación; supervisão especializada em DII refratária',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('vedolizumabe', 'baricitinibe', InteractionSeverity.major,
    'Análogo ao vedolizumabe + tofacitinibe. Imunossupresión aditiva em mucosa intestinal e sistemicamente',
    'Infecções oportunistas intestinais e sistêmicas',
    'Evitar combinación. Se necesario: supervisão especializada, monitoramento de infecções',
    'INFECÇÕES OPORTUNISTAS — Evitar combinación de vedolizumabe com inhibidores de JAK',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('vedolizumabe', 'vacinas vivas', InteractionSeverity.major,
    'Vedolizumabe causa imunossupresión seletiva da mucosa intestinal mas também sistêmica em grau menor. Vacinas vivas orais (poliomielite oral, febre tifóide oral) são especialmente problemáticas',
    'Vacinas vivas orais podem causar infecção disseminada por replicação aumentada do agente vacinal na mucosa intestinal desprotegida/imunocomprometida',
    'Evitar vacinas vivas, especialmente orais. Preferir vacinas inativadas. Consultar guia de vacinação em imunossuprimidos',
    'EVITAR VACINAS VIVAS — Especialmente as orais; usar apenas vacinas inativadas',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('ruxolitinibe', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4, reduzindo os niveles de ruxolitinibe em 70%',
    'Falha terapéutica (mielofibrose, policitemia vera) por niveles subterapéuticos',
    'Evitar combinación. Se necesario: aumentar dosis de ruxolitinibe com monitoramento hematológico',
    'FRACASO TERAPÉUTICO — Rifampicina reduz ruxolitinibe 70%; aumentar dosis com monitoramento',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── MEPOLIZUMABE × outros ─────────────────────────────────────────────────

  ('mepolizumabe', 'vacinas vivas', InteractionSeverity.moderate,
    'Mepolizumabe (anti-IL-5) afeta eosinófilos mas tem menor impacto em linfócitos T e B do que outros biológicos. Vacinas vivas têm riesgo teórico por imunossupresión eosinofílica',
    'Falha de imunização (resposta reducida), riesgo teórico de enfermedad vacinal (menor que com biológicos anti-TNF ou anti-IL-6)',
    'Preferir vacinas inativadas. Consultar especialista antes de vacinas vivas. Riesgo menor que outros biológicos mas não desprezível',
    'MONITORAR — Preferir vacinas inativadas; consultar especialista antes de vacinas vivas',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('ciprofloxacino', 'ciclosporina', InteractionSeverity.major,
    'Ciprofloxacino inibe CYP3A4, aumentando os niveles de ciclosporina. Ambos são nefrotóxicos. Riesgo de toxicidad cumulativa',
    'Nefrotoxicidad grave por acumulación de ciclosporina + efecto nefrotóxico direto do ciprofloxacino (raro mas descrito)',
    'Monitorar C0 de ciclosporina a cada 2-3 dias durante ciprofloxacino. Reducir dosis de ciclosporina se C0 elevado. Considerar alternativa antibiótica',
    'NEFROTOXICIDAD + AUMENTO DE CICLOSPORINA — Monitorar C0 de ciclosporina; considerar alternativa',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('ciprofloxacino', 'isrs', InteractionSeverity.moderate,
    'Ciprofloxacino inibe CYP1A2 (metabolismo de fluvoxamina) e prolonga QTc. Citalopram e escitalopram também prolongam QTc',
    'QTc prolongado aditivo com citalopram/escitalopram. Toxicidad de fluvoxamina por inhibición de CYP1A2',
    'Evitar ciprofloxacino + citalopram/escitalopram. Monitorar ECG. Preferir outro antibiótico en pacientes com ISRS que prolongam QT',
    'QT PROLONGADO — Evitar ciprofloxacino + citalopram/escitalopram; monitorar ECG',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('ciprofloxacino', 'antiácido', InteractionSeverity.major,
    'Cátions divalentes e trivalentes (Mg²⁺, Al³⁺, Ca²⁺, Fe²⁺/³⁺, Zn²⁺) formam complexos insolúveis de quelação com ciprofloxacino no TGI, reduzindo a absorción em 30-75%',
    'Falha terapéutica por niveles subterapéuticos de ciprofloxacino, especialmente em infecções graves',
    'Separar ciprofloxacino de antiácidos, suplementos de ferro, cálcio e zinco por pelo menos 2 horas (ciprofloxacino primeiro) ou 6 horas depois. Nunca coadministrar',
    'FRACASO TERAPÉUTICO — Separar ciprofloxacino de antiácidos/Fe/Ca por 2h antes ou 6h depois; nunca juntos',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ciprofloxacino', 'estatina', InteractionSeverity.moderate,
    'Ciprofloxacino inibe CYP1A2, podendo aumentar os niveles de atorvastatina (metabolizada por CYP3A4/1A2) e rosuvastatina',
    'Riesgo discretamente aumentado de miopatía/rabdomiólisis, especialmente com dosis altas de estatina',
    'Monitorar síntomas musculares. Interacción generalmente clinicamente modesta em cursos curtos de ciprofloxacino. Mais relevante em uso prolongado',
    'MIOPATIA AUMENTADA — Monitorar síntomas musculares em uso prolongado de ciprofloxacino com estatinas',
    EvidenceLevel.probable,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('metronidazol', 'isrs', InteractionSeverity.moderate,
    'Metronidazol inibe CYP2C19 (metabolismo de citalopram, escitalopram, sertralina). Pode aumentar os niveles de ISRSs e potencializar atividade serotoninérgica',
    'Síndrome serotoninérgica leve-moderada, especialmente com citalopram/escitalopram. Prolongación QTc com citalopram',
    'Monitorar signos serotoninérgicos e ECG com citalopram/escitalopram. Preferir tinidazol en pacientes com ISRS cuando sea posible',
    'SÍNDROME SEROTONINÉRGICA + QT — Monitorar signos serotoninérgicos e ECG com citalopram/escitalopram',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('metronidazol', 'ciclosporina', InteractionSeverity.moderate,
    'Metronidazol inibe CYP3A4 e CYP2C9, podendo aumentar os niveles de ciclosporina',
    'Nefrotoxicidad e hepatotoxicidad por acumulación de ciclosporina',
    'Monitorar C0 de ciclosporina e función renal durante curso de metronidazol. Reducir dosis de ciclosporina se C0 elevado',
    'NEFROTOXICIDAD — Monitorar C0 de ciclosporina durante metronidazol',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('metronidazol', 'tacrolimo', InteractionSeverity.moderate,
    'Metronidazol inibe CYP3A4, podendo aumentar os niveles de tacrolimo en pacientes trasplantados',
    'Nefrotoxicidad e neurotoxicidad por acumulación de tacrolimo',
    'Monitorar C0 de tacrolimo diariamente durante curso de metronidazol. Reducir dosis se C0 elevado',
    'NEFROTOXICIDAD — Monitorar C0 de tacrolimo diariamente durante metronidazol',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('trimetoprima', 'losartana', InteractionSeverity.major,
    'Análogo ao trimetoprima + enalapril. BRA retém K + trimetoprima retém K por bloqueio de ENaC → hiperpotasemia grave',
    'Hiperpotasemia grave com riesgo de arritmias fatais',
    'Monitorar K 3-5 dias después de inicio de SMX-TMP en pacientes com BRA. Evitar em IR + BRA + diurético poupador de K',
    'HIPERPOTASEMIA GRAVE — Monitorar K 3-5 dias después de inicio de SMX-TMP em uso de BRA',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('sulfametoxazol', 'fenitoína', InteractionSeverity.major,
    'SMX inibe CYP2C9 (principal via da fenitoína). Trimetoprima pode também inibir CYP2C9 em menor grau',
    'Toxicidad de fenitoína: nistagmo, ataxia, diplopia, confusão por acumulación',
    'Monitorar nivel sérico de fenitoína al iniciar SMX-TMP. Reducir dosis de fenitoína preventivamente. Preferir outro antibiótico cuando sea posible',
    'TOXICIDAD DE FENITOÍNA — SMX-TMP inibe CYP2C9; monitorar nivel sérico de fenitoína',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('sulfametoxazol', 'ciclosporina', InteractionSeverity.major,
    'SMX-TMP inibe CYP3A4 e CYP2C9, aumentando os niveles de ciclosporina. Adicionalmente, ambos são nefrotóxicos',
    'Nefrotoxicidad grave por acumulación de ciclosporina + efecto nefrotóxico do SMX-TMP (cristalúria, nefrite intersticial)',
    'Monitorar C0 de ciclosporina e creatinina diariamente durante SMX-TMP. Manter boa hidratação (previne cristalúria do SMX)',
    'NEFROTOXICIDAD GRAVE — Monitorar C0 de ciclosporina diariamente; manter hidratação adecuada',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('piperacilina-tazobactam', 'aminoglicosideo', InteractionSeverity.moderate,
    'Piperacilinas em altas dosiss podem inativar aminoglicosídeos in vitro por inativação química. Interacción depende concentración e tempo de contato. Significado clínico variável',
    'Posible reducción de la eficácia do aminoglicosídeo por inativação. Riesgo aumentado de nefrotoxicidad por aminoglicosídeo',
    'Não misturar no mesmo frasco/linha. Administrar em horários separados. Dosar nivel sérico do aminoglicosídeo. Monitorar función renal',
    'NÃO MISTURAR — Administrar em linhas separadas; dosar nivel sérico do aminoglicosídeo',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('piperacilina-tazobactam', 'warfarina', InteractionSeverity.moderate,
    'Piperacilina (como outras penicilinas em dosis altas) tem efecto anticoagulante por inhibición da agregação plaquetária (platelet-inhibiting effect). Pode aumentar modestamente o INR por supresión da flora intestinal',
    'Aumento modesto do INR + riesgo de sangrado por efecto antiplaquetário direto da piperacilina em dosis altas',
    'Monitorar INR durante pip/tazo en pacientes com varfarina. Riesgo de sangrado maior em uremia (que também afeta plaquetas)',
    'INR AUMENTADO — Monitorar INR durante pip/tazo en pacientes com varfarina',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('linezolida', 'tramadol', InteractionSeverity.contraindicated,
    'Linezolida inibe MAO; tramadol inibe recaptação de serotonina/noradrenalina. Combinación potencialmente fatal por síndrome serotoninérgica + efecto adrenérgico',
    'Síndrome serotoninérgica grave, crisis adrenérgica, convulsiones',
    'CONTRAINDICADO. Sustituir tramadol por morfina ou fentanila (menor atividade serotoninérgica) durante linezolida',
    'CONTRAINDICADO — Síndrome serotoninérgica grave; sustituir tramadol por morfina durante linezolida',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('linezolida', 'imao', InteractionSeverity.contraindicated,
    'Dupla inhibición de MAO: linezolida inibe MAO não selectivamente + IMAO irreversible ou reversível. Combinación sem indicação clínica e com riesgo de síndrome serotoninérgica/adrenérgica grave',
    'Crise adrenérgica, síndrome serotoninérgica, colapso cardiovascular',
    'CONTRAINDICADO absolutamente. Período de lavado de 14 dias do IMAO antes de linezolida y viceversa',
    'CONTRAINDICADO — Dupla inhibición de MAO; período de lavado de 14 dias',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('linezolida', 'amitriptilina', InteractionSeverity.contraindicated,
    'Linezolida inibe MAO; amitriptilina inibe recaptação de serotonina e noradrenalina. Riesgo de síndrome serotoninérgica análoga ao IMAO + tricíclico',
    'Síndrome serotoninérgica, crisis adrenérgica, arritmias graves',
    'CONTRAINDICADO. Suspender amitriptilina antes de linezolida. Considerar alternativa antibiótica (daptomicina)',
    'CONTRAINDICADO — Síndrome serotoninérgica; suspender amitriptilina antes de linezolida',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('linezolida', 'mirtazapina', InteractionSeverity.contraindicated,
    'Linezolida inibe MAO; mirtazapina aumenta neurotransmissão serotoninérgica/noradrenérgica. Riesgo de síndrome serotoninérgica',
    'Síndrome serotoninérgica',
    'CONTRAINDICADO. Suspender mirtazapina antes de linezolida. Considerar alternativa antibiótica',
    'CONTRAINDICADO — Síndrome serotoninérgica; suspender mirtazapina antes de linezolida',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('linezolida', 'bupropiona', InteractionSeverity.contraindicated,
    'Linezolida inibe MAO; bupropiona inibe recaptação de dopamina e noradrenalina. Riesgo de crisis adrenérgica e convulsiones',
    'Crisis hipertensiva, convulsiones, síndrome adrenérgica',
    'CONTRAINDICADO. Suspender bupropiona antes de linezolida. Considerar alternativa antibiótica',
    'CONTRAINDICADO — Crisis hipertensiva e convulsiones; suspender bupropiona antes de linezolida',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx]),


  ('linezolida', 'warfarina', InteractionSeverity.moderate,
    'Linezolida pode ter leve efecto sobre a coagulação, especialmente em tratamientos prolongados. Inhibición de MAO não diretamente relacionada, mas interacción farmacológica com varfarina posible',
    'Leve aumento do INR em cursos prolongados de linezolida',
    'Monitorar INR em tratamientos prolongados de linezolida. Riesgo generalmente baixo em cursos curtos',
    'MONITORAR INR — Riesgo baixo; monitorar em tratamientos prolongados de linezolida',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

    // ── AZITROMICINA × outros ─────────────────────────────────────────────────

  ('azitromicina', 'warfarina', InteractionSeverity.moderate,
    'Azitromicina tem menor interacción com CYP que eritromicina/claritromicina, mas pode aumentar modestamente o INR por supresión da flora intestinal produtora de vitamina K',
    'Aumento modesto do INR com riesgo de sangrado leve a moderado',
    'Monitorar INR al iniciar e suspender azitromicina. Riesgo generalmente baixo vs eritromicina/claritromicina. Mas monitoramento ainda recomendado',
    'INR AUMENTADO — Monitorar INR com azitromicina; menor riesgo que eritromicina, mas relevante',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('azitromicina', 'haloperidol', InteractionSeverity.moderate,
    'Azitromicina prolonga QTc + haloperidol prolonga QTc por bloqueio de IKr. Riesgo aditivo',
    'QTc prolongado com riesgo de torsades de pointes',
    'Monitorar ECG. Evitar en pacientes com QTc basal > 450ms. Corregir hipopotasemia',
    'QT PROLONGADO — Monitorar ECG com azitromicina + haloperidol; corrigir electrolitos',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('azitromicina', 'metadona', InteractionSeverity.major,
    'Azitromicina prolonga QTc + metadona prolonga QTc dosis-dependentemente. Riesgo aditivo significativo em dosis altas de metadona',
    'QTc prolongado com riesgo de torsades de pointes, especialmente em dosiss elevadas de metadona ou hipopotasemia',
    'Monitorar ECG antes e durante azitromicina en pacientes com metadona em dosis > 100mg/dia. Corrigir electrolitos. Considerar alternativa antibiótica (betalactâmico)',
    'QT PROLONGADO — Monitorar ECG com azitromicina + metadona em dosis altas; corrigir electrolitos',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),

    // ── TIGECICLINA × outros ─────────────────────────────────────────────────

  ('tigeciclina', 'anticonceptivo', InteractionSeverity.moderate,
    'Tigeciclina, como outras tetraciclinas, suprime a flora intestinal que hidrolisa conjugados de estrogênio, podendo reduzir a circulação êntero-hepática de etinilestradiol',
    'Posible reducción de la eficácia contraceptiva hormonal em uso curto',
    'Usar método de barrera adicional durante o curso de tigeciclina e por 7 dias después de. Embora o riesgo seja controverso para tetraciclinas modernas, a prudência recomenda o método de barrera',
    'FRACASO CONTRACEPTIVO — Usar método de barrera adicional durante tigeciclina',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

    // ── ESTATINAS × outros ────────────────────────────────────────────────────

  ('estatina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inibe CYP3A4 e CYP2C8 — vías de metabolismo de sinvastatina, atorvastatina e lovastatina. Pode aumentar os niveles de estatinas em 2-3x. Riesgo mais elevado com sinvastatina em dosiss > 20mg',
    'Miopatía grave e rabdomiólisis. FDA limitou sinvastatina a 20mg/dia com amiodarona',
    'Limitar sinvastatina a 20mg/dia com amiodarona (FDA). Evitar lovastatina. Preferir rosuvastatina ou pravastatina. Monitorar CK e síntomas musculares',
    'RABDOMIÓLISIS — Limitar sinvastatina a 20mg com amiodarona (FDA); preferir pravastatina ou rosuvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('estatina', 'verapamil', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 e P-gp, aumentando os niveles de sinvastatina, lovastatina e atorvastatina. FDA limita sinvastatina a 10mg/dia com verapamil',
    'Miopatía e rabdomiólisis por acumulación de estatinas',
    'Limitar sinvastatina a 10mg/dia com verapamil (FDA). Evitar lovastatina. Preferir pravastatina, rosuvastatina ou fluvastatina. Monitorar CK',
    'RABDOMIÓLISIS — Limitar sinvastatina a 10mg com verapamil (FDA); preferir pravastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('estatina', 'diltiazem', InteractionSeverity.moderate,
    'Diltiazem inibe moderadamente CYP3A4, aumentando os niveles de sinvastatina em 2-4x e atorvastatina em menor grau',
    'Miopatía/rabdomiólisis por acumulación de sinvastatina. FDA limita sinvastatina a 10mg/dia com diltiazem',
    'Limitar sinvastatina a 10mg/dia com diltiazem. Preferir pravastatina ou rosuvastatina. Monitorar CK',
    'RABDOMIÓLISIS — Limitar sinvastatina a 10mg com diltiazem; preferir pravastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('estatina', 'azitromicina', InteractionSeverity.minor,
    'Azitromicina tem mínima inhibición de CYP3A4. Riesgo de miopatía muito baixo em cursos curtos (5 dias). Relevante principalmente com sinvastatina em dosis altas',
    'Riesgo muito baixo de miopatía em tratamientos curtos. Monitoramento generalmente desnecesario',
    'Generalmente seguro em cursos curtos. Monitorar síntomas musculares se sinvastatina em dosis alta (> 40mg). Sem ajuste de dosis necesario',
    'RISCO MÍNIMO — Generalmente seguro; monitorar síntomas musculares se sinvastatina > 40mg',
    EvidenceLevel.possible,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('estatina', 'colchicina', InteractionSeverity.major,
    'Colchicina causa miopatía por inhibición de microtúbulos nas fibras musculares (efecto direto). Estatinas causam miopatía por depleção de ubiquinona. Efecto aditivo/sinérgico',
    'Miopatía grave e rabdomiólisis, especialmente em IR (que também eleva os niveles de colchicina), idosos e en pacientes com dosis altas de estatina',
    'Monitorar CK e síntomas musculares durante uso concomitante. Limitar dosis de colchicina ao mínimo efetivo. Preferir estatinas com menor riesgo (pravastatina, rosuvastatina). Suspender se CK > 5x LSN',
    'RABDOMIÓLISIS — Efecto miopático aditivo; preferir pravastatina; monitorar CK; limitar colchicina ao mínimo',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('estatina', 'fenofibrato', InteractionSeverity.moderate,
    'Fenofibrato inibe CYP2C8 e OATP1B1, podendo aumentar os niveles de estatinas (especialmente cerivastina — retirada do mercado por este motivo). Efecto miopático aditivo independente do mecanismo CYP',
    'Miopatía e rabdomiólisis pelo efecto miopático aditivo de fibratos + estatinas. Menor riesgo que gemfibrozil',
    'Monitorar CK e síntomas musculares. Fenofibrato tem menor riesgo que gemfibrozil com estatinas. Prefira fenofibrato a gemfibrozil quando a combinación for necesaria',
    'MIOPATIA ADITIVA — Fenofibrato mais seguro que gemfibrozil; monitorar CK e síntomas musculares',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),


  ('estatina', 'warfarina', InteractionSeverity.moderate,
    'Estatinas inibem variadamente CYP2C9 (principal via da S-varfarina): fluvastatina e rosuvastatina têm maior inhibición de CYP2C9; pravastatina e atorvastatina têm menor impacto',
    'Aumento modesto do INR al iniciar ou aumentar dosis de estatina, especialmente fluvastatina e rosuvastatina',
    'Monitorar INR al iniciar ou mudar dosis de estatina. Riesgo maior com fluvastatina e rosuvastatina. Ajustar varfarina según sea necesario',
    'INR AUMENTADO — Monitorar INR al iniciar estatina; maior riesgo com fluvastatina e rosuvastatina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('aine', 'isrs', InteractionSeverity.major,
    'ISRSs inibem recaptação de serotonina nas plaquetas, reduzindo a agregação plaquetária. AINEs inibem COX-1 (antiagregação + lesão GI). Efecto antiagregante e lesivo GI aditivo/sinérgico',
    'Hemorragia GI significativa (riesgo 3-15x maior). Metanálises mostram que a combinación AINE + ISRS aumenta riesgo de HDA em 15x em relação a nenhum dos dois',
    'Evitar uso concomitante prolongado. Se necesario: adicionar IBP profilático (omeprazol 20mg ou pantoprazol 40mg). Monitorar signos de sangrado (fezes escuras, anemia)',
    'HEMORRAGIA GI GRAVE — Riesgo 3-15x de HDA; adicionar IBP profilático obligatoriamente si se mantiene a combinación',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('omeprazol', 'metformina', InteractionSeverity.minor,
    'Omeprazol inibe OCT1/OCT2 (transportadores de captação hepática e renal de metformina), podendo aumentar discretamente os niveles plasmáticos de metformina',
    'Aumento discreto dos niveles de metformina. Riesgo mínimo de acidosis láctica em dosiss usuais e función renal normal',
    'Sem ajuste de dosis necesario em función renal normal. Monitorar se TFG reducida. Combinación generalmente segura',
    'RISCO MÍNIMO — Sem ajuste necesario; monitorar se TFG reducida',
    EvidenceLevel.possible,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('pantoprazol', 'metformina', InteractionSeverity.minor,
    'Pantoprazol tem mínima inhibición de OCT1/OCT2 comparado ao omeprazol. Riesgo de interacción com metformina ainda menor',
    'Riesgo muito baixo de aumento dos niveles de metformina',
    'Sem ajuste necesario. Pantoprazol é o IBP preferido en pacientes com clopidogrel e/ou metformina',
    'RISCO MÍNIMO — Pantoprazol é o IBP mais seguro com clopidogrel e metformina',
    EvidenceLevel.possible,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('valproato', 'quetiapina', InteractionSeverity.moderate,
    'Combinación amplamente usada em transtorno bipolar. Valproato pode inibir CYP3A4 modestamente, aumentando os niveles de quetiapina. Sedación aditiva',
    'Sedación excesiva, especialmente ao inicio do tratamiento. QTc prolongado com quetiapina',
    'Monitorar sedación e ECG. Combinación considerada segura em adultos com bipolaridade. Titular lentamente',
    'SEDACIÓN AUMENTADA — Combinación usada em TB; monitorar sedación e ECG; titular lentamente',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('valproato', 'amitriptilina', InteractionSeverity.moderate,
    'Valproato inibe CYP2C9 e CYP2C19, podendo aumentar os niveles de amitriptilina. Ambos têm efectos sedantes e anticolinérgicos',
    'Toxicidad de amitriptilina: QTc prolongado, efectos anticolinérgicos aditivos, sedación excesiva',
    'Monitorar ECG e nivel sérico de amitriptilina. Evitar en ancianos (critérios de Beers). Usar dosis bajas de ambos',
    'QT PROLONGADO + TOXICIDADE ANTICOLINÉRGICA — Monitorar ECG; evitar en ancianos',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('gabapentina', 'tramadol', InteractionSeverity.major,
    'Gabapentina potencializa a depresión del SNC do tramadol. Tramadol abaixa o limiar convulsivo; gabapentina não. Riesgo predominante: sedación e depresión respiratoria',
    'Sedación excesiva, depresión respiratoria. Síndrome serotoninérgica improbable mas riesgo de sedación é real',
    'Usar dosis mínimas de ambos. Monitorar SpO₂. Prescrever naloxona para tramadol',
    'DEPRESIÓN RESPIRATORIA — Usar dosis mínimas; monitorar SpO₂; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefMdx]),


  ('topiramato', 'carbonato de litio', InteractionSeverity.moderate,
    'Topiramato inibe anidrase carbônica, podendo alterar o pH urinário e a excreción renal de lítio. Riesgo de acumulación de lítio ou alteração de seus niveles',
    'Toxicidad de lítio por acumulación ou alteração impredecible dos niveles séricos',
    'Monitorar nivel sérico de lítio al iniciar ou ajustar topiramato. Manter hidratação e ingestão de sódio estáveis',
    'NÍVEL DE LÍTIO ALTERADO — Monitorar nivel sérico de lítio al iniciar topiramato',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('lamotrigina', 'quetiapina', InteractionSeverity.moderate,
    'Quetiapina pode reduzir os niveles de lamotrigina em 50% por mecanismo não completamente elucidado. Combinación usada em bipolaridade mas requer monitoramento',
    'Posible fracaso en el control de crisis epilépticas ou humor por reducción dos niveles de lamotrigina',
    'Monitorar nivel sérico de lamotrigina e resposta clínica. Aumentar dosis de lamotrigina se necesario. Combinación usada em TB tipo I',
    'EFICACIA REDUCIDA — Quetiapina pode reduzir lamotrigina 50%; monitorar nivel sérico e resposta clínica',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

    // ── MISC — pares importantes ainda ausentes ───────────────────────────────

  ('paracetamol', 'warfarina', InteractionSeverity.moderate,
    'Paracetamol em dosiss regulares (≥ 2g/dia por ≥ 3 dias) pode aumentar o INR en pacientes usando varfarina. Mecanismo discutido: posible inhibición de la vitamina K epóxido redutase por metabólitos do paracetamol',
    'Aumento modesto do INR (generalmente 1,5-2x) com dosiss habituais. Raramente sangrado grave. Ainda assim, clinicamente relevante en pacientes idosos ou com INR já elevado',
    'Monitorar INR se uso regular de paracetamol (> 2g/dia por > 3 dias) com varfarina. Não é necesario evitar paracetamol (é o analgésico de escolha com varfarina), mas monitorar. Evitar dosiss > 2g/dia se INR lábil',
    'INR AUMENTADO — Monitorar INR se uso regular de paracetamol > 2g/dia; ainda é o analgésico de escolha',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),


  ('teofilina', 'amiodarona', InteractionSeverity.major,
    'Amiodarona e seu metabólito (desetilamiodarona) inibem CYP1A2, a principal vía de metabolismo de la teofilina. Pode aumentar os niveles em 40-100%',
    'Toxicidad de teofilina: taquicardia, arritmias, náusea, vômitos, convulsiones. Especialmente perigoso dado o estreito índice terapéutico da teofilina',
    'Monitorar nivel sérico de teofilina frecuentemente al iniciar amiodarona. Reducir dosis de teofilina em 30-50% preventivamente. Considerar sustituir teofilina por outro broncodilatador',
    'TOXICIDADE DE TEOFILINA — Amiodarona inibe CYP1A2; reducir dosis 30-50% e monitorar nivel sérico',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('teofilina', 'isrs', InteractionSeverity.moderate,
    'Fluvoxamina inibe potentemente CYP1A2 (principal vía de metabolismo de la teofilina). Pode aumentar os niveles em 3-10x',
    'Toxicidade grave de teofilina: taquicardia, arritmias ventriculares, convulsiones, náusea',
    'CONTRAINDICADO: fluvoxamina + teofilina. Sustituir fluvoxamina por sertralina ou escitalopram (menor inhibición de CYP1A2). Si se mantiene: monitorar nivel sérico e reducir dosis de teofilina em 50-80%',
    'TOXICIDADE DE TEOFILINA — Fluvoxamina inibe CYP1A2 potentemente; sustituir ou reduzir teofilina 50-80%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('teofilina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Teofilina antagoniza os efectos sedantes e anticonvulsivantes dos benzodiazepínicos por antagonismo de adenosina. Reduz a eficácia dos benzodiazepínicos no controle da ansiedade e do status epilepticus',
    'Reducción de la eficacia sedativa e anticonvulsivante dos benzodiazepínicos. Status epilepticus resistente a benzodiazepínicos en pacientes com toxicidad de teofilina',
    'Em intoxicação por teofilina com convulsiones: usar fenitoína ou fenobarbital (mais efetivos que benzodiazepínicos). Aumentar dosis de benzodiazepínico se usado para sedación procedural',
    'EFICACIA REDUCIDA DE BZD — Teofilina antagoniza benzodiazepínicos; na intoxicação por teofilina: preferir fenitoína',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),


  ('ondansetrona', 'isrs', InteractionSeverity.major,
    'Ondansetrona bloqueia receptores 5-HT3 (serotonina). Citalopram e escitalopram também prolongam QTc. Combinación aumenta o riesgo de QT. Paradoxalmente, ondansetrona pode reduzir a atividade ISRSs ao bloquear 5-HT3, mas o riesgo de QT predomina',
    'QTc prolongado com riesgo de torsades de pointes, especialmente com citalopram/escitalopram (que mais prolongam QT entre ISRSs). FDA limitou ondansetrona a 16mg IV por dosis em 2011',
    'Evitar ondansetrona + citalopram ou escitalopram (maior riesgo). Limitar ondansetrona IV a 8mg por dosis. Monitorar ECG. Considerar metoclopramida como alternativa antiemética (mas não en ancianos → extrapiramidal)',
    'QT PROLONGADO — Evitar ondansetrona + citalopram/escitalopram; limitar IV a 8mg; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),


  ('ondansetrona', 'quetiapina', InteractionSeverity.major,
    'Ambos prolongam QTc: ondansetrona por IKr; quetiapina por múltiplos mecanismos. Riesgo aditivo de torsades',
    'QTc prolongado com riesgo de torsades de pointes',
    'Monitorar ECG. Corrigir electrolitos. Evitar en pacientes com QTc > 450ms',
    'QT PROLONGADO — Monitorar ECG com ondansetrona + quetiapina; corrigir electrolitos',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),


  ('colchicina', 'eritromicina', InteractionSeverity.major,
    'Eritromicina inibe CYP3A4 e P-gp, aumentando os niveles de colchicina. Menor magnitude que claritromicina, mas ainda clinicamente perigosa',
    'Toxicidad de colchicina: miopatía, pancitopenia, insuficiencia renal, toxicidad multissistêmica',
    'Evitar combinación. Preferir azitromicina (não inibe CYP3A4 ou P-gp significativamente). Se eritromicina necesaria: dosis única e mínima de colchicina, monitorar CK e hemograma',
    'TOXICIDADE GRAVE — Evitar eritromicina com colchicina; preferir azitromicina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('colchicina', 'verapamil', InteractionSeverity.major,
    'Verapamil inibe P-gp e CYP3A4, as principais vias de eliminación da colchicina. Riesgo de toxicidad análoga à claritromicina + colchicina',
    'Toxicidade grave de colchicina: miopatía, pancitopenia, insuficiencia renal multissistêmica',
    'Evitar combinación. Se colchicina necesaria em paciente com verapamil: dosis única de 0,6mg (sem repetir), monitorar CK e hemograma. Considerar alternativa para gota (prednisona, AINE)',
    'TOXICIDADE FATAL POSSÍVEL — Evitar colchicina com verapamil; usar prednisona ou AINE para gota',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),


  ('ranolazina', 'verapamil', InteractionSeverity.major,
    'Verapamil inibe CYP3A4 e P-gp, aumentando os niveles de ranolazina em 100%. Ambos têm efectos cardiovasculares: bradicardia e prolongamento do PR. Ranolazina prolonga QTc',
    'Acumulación de ranolazina → QTc prolongado, hipotensión. Bradicardia aditiva',
    'Limitar dosis de ranolazina a 500mg 2x/dia com verapamil. Monitorar ECG e PA. Bula da ranolazina recomenda dosis máxima reducida com inhibidores de CYP3A4 moderados',
    'QT PROLONGADO + HIPOTENSIÓN — Limitar ranolazina a 500mg 2x/dia com verapamil; monitorar ECG e PA',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('ranolazina', 'diltiazem', InteractionSeverity.major,
    'Diltiazem inibe CYP3A4 moderadamente, aumentando os niveles de ranolazina em 50-70%. Ambos prolongam o intervalo QT e reduzem PA',
    'Acumulación de ranolazina → QTc prolongado, hipotensión',
    'Limitar dosis de ranolazina a 500mg 2x/dia com diltiazem. Monitorar ECG e PA',
    'QT PROLONGADO + ACÚMULO — Limitar ranolazina a 500mg 2x/dia com diltiazem; monitorar ECG',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('sildenafila', 'amiodarona', InteractionSeverity.major,
    'Amiodarona inibe CYP3A4, podendo aumentar os niveles de sildenafila. Ambos causam vasodilatação e hipotensión. En pacientes com HTP (hipertensão pulmonar) usando ambos: riesgo hemodinâmico',
    'Hipotensión grave por efecto vasodilatador aditivo (PDE5-i + amiodarona). Acumulación de sildenafila por inhibición de CYP3A4',
    'Monitorar PA rigurosamente. Iniciar sildenafila em dosis baja (25mg). Em HTP: supervisão cardiológica especializada',
    'HIPOTENSIÓN GRAVE — Amiodarona inibe CYP3A4; iniciar sildenafila em dosis baja; monitorar PA',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),


  ('propofol', 'benzodiazepínico', InteractionSeverity.major,
    'Propofol (potenciador de GABA-A) e benzodiazepínicos (também GABA-A) têm efecto sinérgico na sedación e depresión respiratoria',
    'Apnea, depresión respiratoria profunda, hipotensión grave. Riesgo especialmente alto en ancianos, DPOC e em bolus rápidos',
    'Usar apenas em ambiente monitorado. Titular lentamente. Ter flumazenil disponible. Monitorar SpO₂ e ETCO₂',
    'APNEA — Usar apenas em ambiente monitorado; ter flumazenil; monitorar SpO₂',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),


  ('levosimendan', 'betabloqueador', InteractionSeverity.moderate,
    'Levosimendan (sensibilizador de cálcio + abre canais de KATP vasculares) causa vasodilatação e melhora contratilidade. Betabloqueadores reduzem a FC e contratilidade. Efecto hemodinâmico parcialmente oposto',
    'Hipotensión e bradicardia por efecto vasodilatador de levosimendan + cronotropismo negativo do betabloqueador',
    'Monitorar PA e FC rigurosamente durante infusão de levosimendan. Reducir dosis do betabloqueador se hipotensión ou bradicardia sintomáticas',
    'HIPOTENSÃO + BRADICARDIA — Monitorar PA e FC durante levosimendan; reduzir betabloqueador se necesario',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('dexmedetomidina', 'betabloqueador', InteractionSeverity.major,
    'Dexmedetomidina (agonista α2 central) causa bradicardia e hipotensión. Betabloqueadores também causam bradicardia. Efecto aditivo na reducción de la FC e PA',
    'Bradicardia grave (FC < 40bpm), bloqueo AV, hipotensión grave, asistolia em bolus rápidos de dexmedetomidina',
    'Monitorar ECG e PA continuamente durante dexmedetomidina. Titular lentamente. Ter atropina disponible. Evitar bolus rápidos de carga',
    'BRADICARDIA GRAVE — Monitorar ECG continuamente; ter atropina disponible; evitar bolus rápidos',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


  ('dexmedetomidina', 'opioide', InteractionSeverity.major,
    'Dexmedetomidina potencializa os efectos analgésicos e sedantes dos opioides por mecanismo agonista α2. Permite reducción de 30-50% na dosis de opioide em UTI (efecto "opioide-sparing"). Riesgo de depresión respiratoria aditiva',
    'Depresión respiratoria aumentada, bradicardia, hipotensión grave em dosiss elevadas de ambos',
    'Usar combinación com reducción de la dosis de opioide (efecto opioide-sparing reconhecido). Monitorar SpO₂, PA e FC continuamente. Tener naloxona disponible',
    'DEPRESIÓN RESPIRATORIA + BRADICARDIA — Reducir dosis de opioide 30-50%; monitorar SpO₂ e PA continuamente',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),


    // ═══════════════════════════════════════════════════════════════
    // BLOCO 10 — pares clinicamente relevantes ausentes entre IDs existentes
    // Categorias: QT, serotonina, inmunosupresores, antiepilépticos,
    //             hemostasia, hiperpotasemia, hipoglucemia, estatinas,
    //             digoxina, IBPs, cardiovascular, lítio, antimicrobianos
    // ═══════════════════════════════════════════════════════════════

  ('amiodarona', 'fluconazol', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT: amiodarona bloqueia canais de potássio (IKr); fluconazol inibe CYP3A4/2C9 elevando niveles de amiodarona',
    'Prolongación aditiva del QTc; riesgo elevado de torsades de pointes e morte súbita cardíaca',
    'Evitar combinación. Se imprescindível, monitorar ECG contínuo, corregir hipopotasemia/hipomagnesemia e reducir dosis de fluconazol',
    'RISCO DE TORSADES — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT, _kRefLex]),

  ('amiodarona', 'claritromicina', InteractionSeverity.major,
    'Claritromicina prolonga QT e inibe CYP3A4, elevando concentraciones de amiodarona; efecto aditivo sobre IKr',
    'Prolongamento marcado do QTc; torsades de pointes e fibrilación ventricular',
    'Contraindicado. Usar azitromicina somente se ECG basal normal e sem alternativa; monitorar ECG',
    'RISCO DE TORSADES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('amiodarona', 'olanzapina', InteractionSeverity.major,
    'Olanzapina bloqueia canais hERG (IKr); somado ao potente efecto de amiodarona, prolonga QTc aditivamente',
    'Prolongación del QTc; riesgo de torsades de pointes e morte súbita',
    'Evitar combinación. Considerar antipsicótico com menor riesgo de QT. Monitorar ECG',
    'RISCO DE TORSADES — Evitar',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('sotalol', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP3A4 elevando nivel de sotalol; sotalol bloqueia IKr prolongando QT',
    'Prolongamento excessivo do QTc; torsades de pointes',
    'Evitar. Monitorar ECG e electrolitos. Preferir antifúngico alternativo',
    'RISCO DE TORSADES — Evitar',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('sotalol', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e prolonga QT por si mesma; efecto aditivo sobre IKr com sotalol',
    'Prolongamento crítico do QTc; torsades de pointes',
    'Contraindicado. Usar antibiótico alternativo sem efecto sobre QT',
    'RISCO DE TORSADES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('sotalol', 'metadona', InteractionSeverity.major,
    'Metadona prolonga QT por bloqueio de IKr; somado ao sotalol, efecto aditivo significativo',
    'Prolongamento grave do QTc; riesgo de torsades de pointes e morte súbita',
    'Contraindicado. Se analgesia com opioide necesaria, usar morfina ou fentanila com monitoração de ECG',
    'RISCO DE TORSADES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('haloperidol', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 elevando nivel de haloperidol e prolonga QT por si mesma; efecto aditivo',
    'Prolongación del QTc; torsades de pointes; aumento de efectos extrapiramidais',
    'Evitar. Monitorar ECG. Usar antibiótico alternativo',
    'RISCO DE TORSADES — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('haloperidol', 'metadona', InteractionSeverity.major,
    'Ambos prolongam QT por bloqueio de IKr; metadona inibe CYP2D6 podendo elevar haloperidol',
    'Prolongamento crítico do QTc; torsades de pointes',
    'Contraindicado. Se necesario antipsicótico, preferir quetiapina com dosis baja e monitoração de ECG',
    'RISCO DE TORSADES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('quetiapina', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 intensamente; quetiapina é metabolizada por CYP3A4 — nivel plasmático aumenta 5-10x',
    'Sedación excesiva, hipotensión ortostática, prolongación del QT',
    'Evitar. Reducir dosis de quetiapina em até 80% se antibiótico imprescindível. Monitorar ECG',
    'NÍVEL DE QUETIAPINA ↑↑↑ — Sedación e QT',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation, RiskType.cns},
    [_kRefMdx, _kRefUT]),

  ('metadona', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP3A4 e CYP2C19, reduzindo metabolismo de la metadona; elevación do nivel plasmático',
    'Sedación excesiva, depresión respiratoria, prolongación del QT',
    'Reducir dosis de metadona em ~25-50%. Monitorar ECG e nivel de consciência',
    'METADONA ↑ — Depresión respiratoria e QT',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation, RiskType.respiratoryDepression},
    [_kRefMdx, _kRefUT]),

  ('sacubitrila', 'losartana', InteractionSeverity.moderate,
    'Sacubitrila já associada a valsartana (sacubitril/valsartan); adicionar outro ARA-II eleva riesgo de hipotensión e hiperpotasemia',
    'Hipotensión sintomática; hiperpotasemia; piora da función renal',
    'No combinar ARA-II adicional com sacubitrila/valsartana; monitorar PA, creatinina e potássio',
    'HIPOTENSÃO e HIPERPOTASEMIA — No combinar ARA-II extra',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.hyperkalemia},
    [_kRefUT, _kRefFDA]),

  ('rivaroxabana', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e P-gp; rivaroxabana é substrato de ambos — nivel plasmático aumenta significativamente',
    'Riesgo hemorrágico aumentado (sangrado GI, intracraneal)',
    'Evitar combinación. Se imprescindível, monitorar signos de sangrado ativamente',
    'RIESGO HEMORRÁGICO ↑ — Evitar',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('apixabana', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe CYP3A4 e P-gp; apixabana é substrato de ambos — exposición plasmática aumentada',
    'Riesgo hemorrágico aumentado',
    'Evitar combinación. Se imprescindível, vigilancia clínica intensa para sinais de sangrado',
    'RIESGO HEMORRÁGICO ↑ — Evitar',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('dabigatrana', 'claritromicina', InteractionSeverity.major,
    'Claritromicina inibe P-gp; dabigatrana é substrato de P-gp — biodisponibilidad e AUC aumentam ~15-20%',
    'Riesgo hemorrágico aumentado',
    'Evitar. Monitorar tempo de trombina ou nivel anti-Xa se alternativa não disponible',
    'RIESGO HEMORRÁGICO ↑ — Evitar',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('dabigatrana', 'fluconazol', InteractionSeverity.moderate,
    'Fluconazol inibe P-gp moderadamente; dabigatrana é substrato de P-gp — leve aumento de exposición',
    'Riesgo de sangrado aumentado de forma moderada',
    'Monitorar signos de sangrado. Evitar en pacientes com alto riesgo hemorrágico',
    'MONITORAR SANGRAMENTO',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('fondaparinux', 'aspirina', InteractionSeverity.moderate,
    'Efecto antitrombótico aditivo: inhibición de fator Xa + inhibición plaquetária por aspirina',
    'Riesgo hemorrágico moderadamente aumentado',
    'Monitorar signos de sangrado, especialmente GI. Usar dosis mínima de AAS',
    'MONITORAR SANGRAMENTO',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT]),

  ('fluoxetina', 'tramadol', InteractionSeverity.major,
    'Tramadol inibe recaptação de serotonina; fluoxetina é ISRS potente — síndrome serotoninérgica por efecto aditivo; fluoxetina inibe CYP2D6 reduzindo conversão de tramadol ao metabólito ativo',
    'Síndrome serotoninérgica (tremor, mioclonia, hipertermia, agitação, confusão)',
    'Evitar combinación. Usar opioide sem efecto serotoninérgico (morfina, fentanila)',
    'SÍNDROME SEROTONINÉRGICA — Evitar',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('fluoxetina', 'metadona', InteractionSeverity.major,
    'Fluoxetina inibe CYP2D6 e CYP3A4 elevando nivel de metadona; ambos prolongam QT; riesgo serotoninérgico aditivo',
    'Toxicidad de metadona: depresión respiratoria, prolongación del QTc, síndrome serotoninérgica',
    'Evitar. Monitorar ECG e nivel de consciência. Considerar opioide alternativo',
    'METADONA ↑ + QT + SEROTONINA — Evitar',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.qtProlongation, RiskType.respiratoryDepression, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('amitriptilina', 'fluoxetina', InteractionSeverity.major,
    'Fluoxetina inibe CYP2D6 intensamente — metabolismo de amitriptilina reducido, nivel aumenta 2-4x; ambos prolongam QT; riesgo serotoninérgico',
    'Toxicidad de antidepresivo tricíclico: arritmias, hipotensión, sedación, convulsiones',
    'Evitar. Se necesario, reducir dosis de amitriptilina em 50-75% e monitorar ECG e nivel plasmático',
    'AMITRIPTILINA ↑↑ + QT + SEROTONINA — Evitar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation, RiskType.serotonin},
    [_kRefMdx, _kRefUT]),

  ('fenobarbital', 'carbamazepina', InteractionSeverity.moderate,
    'Ambos são inductores de CYP3A4 e CYP2C — reducción mútua dos niveles plasmáticos',
    'Nivel de ambos reducido; posible perda de eficácia antiepiléptica',
    'Monitorar niveles séricos e resposta clínica. Ajustar dosiss individualmente',
    'NÍVEIS REDUZIDOS MÚTUOS — Monitorar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('contraste iodado', 'aminoglicosideo', InteractionSeverity.major,
    'Aminoglicosídeos causam nefrotoxicidad; contraste iodado causa nefropatia por contraste — riesgo aditivo de lesão renal aguda',
    'Lesão renal aguda grave; posible necessidade diálise',
    'Evitar contraste en pacientes em uso de aminoglicosídeo. Se imprescindível, hidratar vigorosamente e monitorar creatinina 48-72h',
    'NEFROTÓXICO ADITIVO — Hidratar e monitorar',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),

  ('metotrexato', 'trimetoprima', InteractionSeverity.major,
    'Trimetoprima inibe dihidrofolato redutase; somado a metotrexato (também inibe DHFR), causa depleção grave de folato',
    'Mielossupresión grave (pancitopenia); mucosite; toxicidad hematológica',
    'Evitar combinación. Se necesario, usar ácido folínico (leucovorina) después de metotrexato',
    'MIELOSUPRESIÓN GRAVE — Evitar',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('metotrexato', 'sulfametoxazol', InteractionSeverity.major,
    'Sulfametoxazol inibe DHFR e compete com metotrexato pela excreción tubular renal — nivel de metotrexato aumenta',
    'Mielossupresión grave; mucosite; nefrotoxicidad',
    'Evitar. Usar antibiótico alternativo. Se imprescindível, monitorar hemograma e nivel de metotrexato',
    'MIELOSUPRESIÓN + METOTREXATO ↑ — Evitar',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('eplerenona', 'losartana', InteractionSeverity.major,
    'Eplerenona retém potássio; ARA-II reduz excreción de potássio — hiperpotasemia aditiva',
    'Hiperpotasemia grave; arritmia ventricular',
    'Monitorar K+ e creatinina. Evitar en pacientes com TFG <50 mL/min',
    'HIPERPOTASEMIA GRAVE — Monitorar K+',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefFDA, _kRefUT]),

  ('finerenona', 'losartana', InteractionSeverity.major,
    'Finerenona retém potássio; ARA-II reduz excreción de K+ — hiperpotasemia aditiva',
    'Hiperpotasemia; piora da función renal',
    'Monitorar K+ e función renal. Contraindicado se K+ >5 mEq/L',
    'HIPERPOTASEMIA — Monitorar K+',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    [_kRefFDA, _kRefUT]),

  ('rosuvastatina', 'ciclosporina', InteractionSeverity.major,
    'Ciclosporina inibe OATP1B1 e P-gp; rosuvastatina é substrato de ambos — AUC aumenta ~10x',
    'Miopatía grave; rabdomiólisis',
    'Evitar ou limitar rosuvastatina a 5 mg/dia com ciclosporina. Monitorar CK',
    'RABDOMIÓLISIS — Dosis máx 5 mg/dia',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  ('digoxina', 'fluconazol', InteractionSeverity.moderate,
    'Fluconazol pode inibir P-gp e reduzir aclaramiento renal de digoxina — nivel sérico aumenta moderadamente',
    'Toxicidad digitálica leve a moderada',
    'Monitorar nivel sérico de digoxina e ECG. Reducir dosis se necesario',
    'DIGOXINA ↑ — Monitorar nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('quinolona', 'teofilina', InteractionSeverity.major,
    'Quinolonas (principalmente ciprofloxacino, enoxacino) inibem CYP1A2; teofilina metabolizada por CYP1A2',
    'Toxicidad de la teofilina: convulsiones, arritmias',
    'Monitorar nivel de teofilina. Reducir dosis em 30-50% com ciprofloxacino. Preferir levofloxacino (menor interacción)',
    'TEOFILINA ↑ — Monitorar e reducir dosis',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.seizure},
    [_kRefGG, _kRefMdx]),

  ('dexametasona', 'ciclosporina', InteractionSeverity.moderate,
    'Dexametasona induz CYP3A4; ciclosporina metabolizada por CYP3A4 — nivel reducido; ciclosporina inibe metabolismo de dexametasona',
    'Nivel de ciclosporina reducido (riesgo de rechazo); nivel de dexametasona aumentado',
    'Monitorar nivel sérico de ciclosporina. Ajustar dosiss',
    'CICLOSPORINA ↓ — Monitorar nivel sérico',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('dexametasona', 'warfarina', InteractionSeverity.moderate,
    'Corticosteroides podem inibir ou induzir CYP2C9 (variável); efecto líquido impredecible sobre INR; também inibem trombosis',
    'Variação do INR (aumento ou reducción)',
    'Monitorar INR a cada 3-5 dias durante uso de dexametasona. Ajustar dosis de warfarina según INR',
    'INR VARIÁVEL — Monitorar',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.hemorrhagic},
    [_kRefMdx, _kRefUT]),

  ('dexametasona', 'fenitoína', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 reduzindo nivel de dexametasona; dexametasona induz CYP3A4 reduzindo fenitoína; interacción bidireccional',
    'Eficácia de dexametasona reducida; nivel de fenitoína instável',
    'Aumentar dosis de dexametasona se necesario. Monitorar nivel de fenitoína. Considerar antiepiléptico alternativo',
    'DEXAMETASONA ↓ + FENITOÍNA VARIÁVEL',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('rocurônio', 'dexmedetomidina', InteractionSeverity.minor,
    'Dexmedetomidina pode prolongar levemente o bloqueio neuromuscular por reducción del tônus simpático',
    'Bloqueio neuromuscular levemente prolongado',
    'Monitorar TOF. Ajustar dosis de reversão se necesario',
    'BLOQ. NEUROMUSCULAR PROLONGADO — Monitorar',
    EvidenceLevel.possible,
    {RiskType.respiratoryDepression},
    [_kRefMdx]),

  ('teofilina', 'furosemida', InteractionSeverity.moderate,
    'Furosemida pode aumentar excreción de teofilina em altas dosiss; hipopotasemia pode aumentar toxicidad cardíaca de teofilina',
    'Variação do nivel de teofilina; toxicidad cardíaca facilitada por hipopotasemia',
    'Monitorar nivel de teofilina e K+ sérico. Reponer potasio se necesario',
    'TEOFILINA VARIÁVEL + HIPOCALEMIA — Monitorar',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.hypokalemia},
    [_kRefMdx]),

  ('teofilina', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP1A2; teofilina metabolizada por CYP1A2 — clearance aumenta e nivel cai 50-75%',
    'Perda de eficácia da teofilina; piora do broncoespasmo',
    'Aumentar dosis de teofilina 50-100% ao usar rifampicina. Monitorar nivel sérico',
    'TEOFILINA ↓↓ — Aumentar dosis',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('metotrexato', 'aine', InteractionSeverity.major,
    'AINEs inibem secreção tubular renal de metotrexato e reduzem TFG — retenção de metotrexato',
    'Toxicidad de metotrexato: mielosupresión, mucosite, nefrotoxicidad, hepatotoxicidad',
    'Evitar AINEs com metotrexato em altas dosiss. Em baixas dosiss (artrite), monitorar hemograma e función renal',
    'METOTREXATO ↑ — TOXICIDADE GRAVE',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('bupropiona', 'tamoxifeno', InteractionSeverity.major,
    'Bupropiona inibe CYP2D6; tamoxifeno convertido ao metabólito ativo endoxifeno por CYP2D6 — eficácia reducida',
    'Reducción del efecto antiestrogênico do tamoxifeno; posible falha no tratamiento de câncer de mama',
    'Evitar. Usar antidepresivo que não iniba CYP2D6 (venlafaxina, citalopram, mirtazapina)',
    'TAMOXIFENO ↓ — Falha oncológica',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('fluoxetina', 'tamoxifeno', InteractionSeverity.major,
    'Fluoxetina é inhibidor potente de CYP2D6; tamoxifeno requer CYP2D6 para conversão ao metabólito ativo (endoxifeno)',
    'Reducción de la eficacia do tamoxifeno; riesgo de recurrencia do câncer de mama',
    'Evitar. Preferir antidepresivos com mínima inhibición de CYP2D6: venlafaxina ou citalopram',
    'TAMOXIFENO ↓ — Falha oncológica',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT, _kRefLex]),

  ('ranolazina', 'fluconazol', InteractionSeverity.major,
    'Fluconazol inibe CYP3A4; ranolazina metabolizada por CYP3A4 — exposición aumenta significativamente',
    'Prolongación del QT; toxicidad de ranolazina',
    'Evitar. Monitorar ECG se imprescindível',
    'RANOLAZINA ↑ + QT — Evitar',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.qtProlongation},
    [_kRefMdx, _kRefUT]),

  ('propofol', 'midazolam', InteractionSeverity.major,
    'Ambos são depressores do SNC; efecto sedante e respiratório aditivo',
    'Depresión respiratoria grave; apnea; hipotensión',
    'Reducir dosis de cada agente (interacción sinérgica). Ter suporte ventilatório disponible. Monitorar SpO2',
    'DEPRESIÓN RESPIRATORIA — Reducir dosiss',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

  ('ritonavir', 'colchicina', InteractionSeverity.contraindicated,
    'Ritonavir inibe CYP3A4 e P-gp; colchicina substrato de ambos — nivel aumenta 20-40x',
    'Toxicidade fatal de colchicina: mielossuupressão, miopatía, falência de múltiplos órgãos',
    'Contraindicado em IRC. Dosis única máxima de colchicina 0,6 mg (sem repetição por 3 dias) se TFG normal',
    'CONTRAINDICADO em IRC — Toxicidade fatal',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.myelosuppression, RiskType.myopathy},
    [_kRefFDA, _kRefMdx]),

  ('isavuconazol', 'tacrolimo', InteractionSeverity.major,
    'Isavuconazol inibe CYP3A4 e P-gp; tacrolimo é substrato de ambos — nivel aumenta ~100%',
    'Nefrotoxicidad; neurotoxicidad',
    'Reducir dosis de tacrolimo em 50%. Monitorar nivel sérico a cada 2-3 dias',
    'TACROLIMO ↑↑ — Reducir dosis 50%',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.nephrotoxicity},
    [_kRefMdx, _kRefUT]),

  ('acetazolamida', 'carbonato de litio', InteractionSeverity.moderate,
    'Acetazolamida aumenta excreción renal de lítio (alcalinização da urina); nivel de lítio pode reduzir',
    'Reducción del nivel de lítio; posible perda de eficácia terapéutica',
    'Monitorar nivel de lítio al iniciar ou suspender acetazolamida. Ajustar dosis se necesario',
    'LÍTIO ↓ — Monitorar nivel sérico',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('perampanel', 'valproato', InteractionSeverity.moderate,
    'Valproato pode aumentar nivel de perampanel; perampanel pode reduzir levemente nivel de valproato',
    'Toxicidad de perampanel: tontura, irritabilidade, agressividade',
    'Monitorar signos de toxicidad de perampanel. Ajustar dosis conforme tolerância',
    'PERAMPANEL ↑ — Monitorar toxicidad',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefMdx, _kRefUT]),

  ('tocilizumabe', 'baricitinibe', InteractionSeverity.major,
    'Ambos são inmunosupresores potentes (IL-6i + JAKi); riesgo de imunossupresión excessiva',
    'Infecções oportunistas graves; reativação de tuberculose/herpes; trombosis',
    'Evitar combinación. Monitorar hemograma e sinais de infecção se necesario',
    'IMUNOSSUPRESSÃO EXCESSIVA — Evitar combinación',
    EvidenceLevel.probable,
    {RiskType.infection, RiskType.myelosuppression},
    [_kRefFDA, _kRefUT]),
    // ── BLOCO 10 — Pares intra-categoria ausentes ──────────────────────────────


  ('aine', 'ibuprofeno', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aine', 'naproxeno', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aine', 'cetorolaco', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aspirina', 'ibuprofeno', InteractionSeverity.major,
    'Ibuprofeno compete com aspirina pelo sítio de ligação irreversible na COX-1 plaquetária, bloqueando o acesso da aspirina e anulando seu efecto antiagregante',
    'Perda do efecto cardioprotetor da aspirina. Riesgo hemorrágico GI aditivo por inhibición de prostaglandinas protetoras da mucosa',
    'Administrar aspirina ≥2h antes do ibuprofeno para preservar o efecto antiagregante. Se AINE obligatorio, preferir celecoxibe (não compete com aspirina). Monitorar INR e sintomas GI',
    'ANULA EFEITO ANTIAGREGANTE — Administrar AAS ≥2h antes do ibuprofeno; considerar celecoxibe',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('aspirina', 'naproxeno', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aspirina', 'cetorolaco', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aspirina', 'clonixinato', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('cetorolaco', 'ibuprofeno', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('cetorolaco', 'naproxeno', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('cetorolaco', 'clonixinato', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('ibuprofeno', 'naproxeno', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('clonixinato', 'naproxeno', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('clonixinato', 'ibuprofeno', InteractionSeverity.moderate,
    'Dois inhibidores de COX: inhibición aditiva de prostaglandinas protetoras da mucosa gástrica e vasodilatadoras renais. Sem benefício analgésico adicional comprovado',
    'Riesgo aumentado de sangrado GI, úlcera péptica e lesão renal aguda por efecto aditivo na inhibición de prostaglandinas',
    'EVITAR combinación de dois AINEs. Usar dosis mínima efetiva de um único AINE. Adicionar protetor gástrico (IBP) se uso inevitável. Monitorar función renal e sinais de sangrado GI',
    'EVITAR DOIS AINEs — Riesgo hemorrágico e nefrotóxico aditivo; usar apenas um AINE',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('amiodarona', 'dronedarona', InteractionSeverity.contraindicated,
    'Dronedarona é contraindicada com amiodarona: ambas prolongam QTc por bloqueio de canais IKr. Riesgo de Torsades de Pointes e fibrilación ventricular',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita cardíaca',
    'CONTRAINDICAÇÃO ABSOLUTA. Nunca combinar. Aguardar período de lavado completo de amiodarona (vida media: 40-55 dias) antes de iniciar dronedarona',
    'CONTRAINDICADO ABSOLUTO — Torsades de Pointes; aguardar período de lavado de amiodarona (40-55 dias)',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('amiodarona', 'verapamil', InteractionSeverity.major,
    'Dois antiarrítmicos com mecanismos sobrepostos: prolongamento aditivo do QTc e/ou efecto dromotrópico negativo aditivo',
    'Bradicardia, bloqueo AV, Torsades de Pointes, síncope, morte súbita',
    'Evitar combinación. Se necesario, monitorar ECG continuamente e QTc. Suspender se QTc > 500ms ou FC < 50bpm',
    'ARRITMIA GRAVE — QTc aditivo; monitorar ECG; suspender se QTc > 500ms ou FC < 50bpm',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('amiodarona', 'ivabradina', InteractionSeverity.major,
    'Ivabradina reduz FC por bloqueio dos canais If no nó sinusal. Combinada com antiarrítmico bradicardizante: bradicardia grave aditiva',
    'Bradicardia sintomática grave, bloqueo AV, síncope',
    'Evitar combinación. Si es necesaria, iniciar ivabradina em dosis baja (2,5 mg 2x/dia) e monitorar FC e ECG continuamente',
    'BRADICARDIA GRAVE — Ivabradina + antiarrítmico bradicardizante; monitorar FC continuamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('diltiazem', 'verapamil', InteractionSeverity.contraindicated,
    'Dois BCCs não-diidropiridínicos com efecto dromotrópico e cronotrópico negativo aditivo. Inhibición aditiva do nó AV',
    'Bloqueo AV completo, asistolia, bradicardia extrema, choque cardiogênico',
    'CONTRAINDICAÇÃO ABSOLUTA. Nunca combinar diltiazem e verapamil. Monitorar ECG rigurosamente se exposición inadvertida',
    'CONTRAINDICADO — Bloqueo AV completo e asistolia; nunca combinar diltiazem + verapamil',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('diltiazem', 'sotalol', InteractionSeverity.major,
    'Sotalol prolonga QTc por bloqueio IKr. Combinado com outro antiarrítmico com mesma ação: prolongación QTc aditivo',
    'Torsades de Pointes, fibrilación ventricular, síncope cardíaca',
    'Evitar combinación. Se necesario, monitorar QTc continuamente. QTc > 500ms exige suspensión imediata',
    'TORSADES DE POINTES — QTc aditivo; monitorar ECG; suspender se QTc > 500ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dronedarona', 'sotalol', InteractionSeverity.major,
    'Sotalol prolonga QTc por bloqueio IKr. Combinado com outro antiarrítmico com mesma ação: prolongación QTc aditivo',
    'Torsades de Pointes, fibrilación ventricular, síncope cardíaca',
    'Evitar combinación. Se necesario, monitorar QTc continuamente. QTc > 500ms exige suspensión imediata',
    'TORSADES DE POINTES — QTc aditivo; monitorar ECG; suspender se QTc > 500ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dronedarona', 'verapamil', InteractionSeverity.major,
    'Dois antiarrítmicos com mecanismos sobrepostos: prolongamento aditivo do QTc e/ou efecto dromotrópico negativo aditivo',
    'Bradicardia, bloqueo AV, Torsades de Pointes, síncope, morte súbita',
    'Evitar combinación. Se necesario, monitorar ECG continuamente e QTc. Suspender se QTc > 500ms ou FC < 50bpm',
    'ARRITMIA GRAVE — QTc aditivo; monitorar ECG; suspender se QTc > 500ms ou FC < 50bpm',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dronedarona', 'ivabradina', InteractionSeverity.major,
    'Ivabradina reduz FC por bloqueio dos canais If no nó sinusal. Combinada com antiarrítmico bradicardizante: bradicardia grave aditiva',
    'Bradicardia sintomática grave, bloqueo AV, síncope',
    'Evitar combinación. Si es necesaria, iniciar ivabradina em dosis baja (2,5 mg 2x/dia) e monitorar FC e ECG continuamente',
    'BRADICARDIA GRAVE — Ivabradina + antiarrítmico bradicardizante; monitorar FC continuamente',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('ivabradina', 'sotalol', InteractionSeverity.major,
    'Sotalol prolonga QTc por bloqueio IKr. Combinado com outro antiarrítmico com mesma ação: prolongación QTc aditivo',
    'Torsades de Pointes, fibrilación ventricular, síncope cardíaca',
    'Evitar combinación. Se necesario, monitorar QTc continuamente. QTc > 500ms exige suspensión imediata',
    'TORSADES DE POINTES — QTc aditivo; monitorar ECG; suspender se QTc > 500ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('sotalol', 'verapamil', InteractionSeverity.major,
    'Sotalol prolonga QTc por bloqueio IKr. Combinado com outro antiarrítmico com mesma ação: prolongación QTc aditivo',
    'Torsades de Pointes, fibrilación ventricular, síncope cardíaca',
    'Evitar combinación. Se necesario, monitorar QTc continuamente. QTc > 500ms exige suspensión imediata',
    'TORSADES DE POINTES — QTc aditivo; monitorar ECG; suspender se QTc > 500ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('betabloqueador', 'metoprolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('betabloqueador', 'propranolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('betabloqueador', 'esmolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('betabloqueador', 'labetalol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('esmolol', 'metoprolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('esmolol', 'propranolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('esmolol', 'labetalol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('labetalol', 'metoprolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('labetalol', 'propranolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('metoprolol', 'propranolol', InteractionSeverity.major,
    'Dois betabloqueadores: bloqueio aditivo de receptores β1 com efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV 2º/3º grau, broncoespasmo, hipotensión, choque cardiogênico',
    'EVITAR combinación de dois betabloqueadores. Em transição terapéutica, suspender o primeiro antes de iniciar o segundo. Monitorar FC e ECG',
    'BRADICARDIA + BLOQUEO AV — Dois betabloqueadores; nunca combinar; monitorar FC',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('carbamazepina', 'gabapentina', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fenitoína', 'gabapentina', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fenitoína', 'topiramato', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fenitoína', 'perampanel', InteractionSeverity.major,
    'Fortes inductores de CYP3A4 reduzem exposición ao perampanel em 50-67%, comprometendo eficácia antiepiléptica',
    'Falha terapéutica do perampanel com escape de convulsiones',
    'Dobrar a dosis de perampanel quando combinado com inductor forte. Titulación mais rápida permitida. Monitorar eficácia clínica',
    'PERAMPANEL REDUZIDO 50-67% — Inductores de CYP3A4; dobrar dosis de perampanel',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('fenobarbital', 'topiramato', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fenobarbital', 'perampanel', InteractionSeverity.major,
    'Fortes inductores de CYP3A4 reduzem exposición ao perampanel em 50-67%, comprometendo eficácia antiepiléptica',
    'Falha terapéutica do perampanel com escape de convulsiones',
    'Dobrar a dosis de perampanel quando combinado com inductor forte. Titulación mais rápida permitida. Monitorar eficácia clínica',
    'PERAMPANEL REDUZIDO 50-67% — Inductores de CYP3A4; dobrar dosis de perampanel',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('fenobarbital', 'gabapentina', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('lamotrigina', 'topiramato', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('lamotrigina', 'perampanel', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('perampanel', 'topiramato', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('gabapentina', 'valproato', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('gabapentina', 'lamotrigina', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('gabapentina', 'perampanel', InteractionSeverity.moderate,
    'Combinación de dois antiepilépticos com potencial interacción farmacocinética (inducción/inhibición enzimática) ou farmacodinâmica (sedación aditiva)',
    'Alteração nos niveles séricos de um ou ambos os fármacos, sedación excesiva, tontura, ataxia',
    'Monitorar niveles séricos dos antiepilépticos envolvidos. Ajustar dosiss com base em resposta clínica e nivel sérico. Considerar titulación mais lenta',
    'MONITORAR NÍVEIS SÉRICOS — Antiepilépticos com interacción farmacocinética; ajustar dosiss conforme nivel',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fluoxetina', 'isrs', InteractionSeverity.contraindicated,
    'Dois SSRIs: inhibición aditiva do transportador SERT com acumulación excessivo de serotonina sináptica',
    'Síndrome serotoninérgica, hiperreflexia, mioclonias, agitação, hipertermia',
    'CONTRAINDICADO. Usar apenas um SSRI. Em troca de SSRI, respeitar período de lavado adecuado (5 meias-vidas)',
    'CONTRAINDICADO — Dois SSRIs: síndrome serotoninérgica; usar apenas um SSRI',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fluoxetina', 'mirtazapina', InteractionSeverity.moderate,
    'Dois antidepresivos com mecanismos serotoninérgicos sobrepostos ou interacciones farmacocinéticas via CYP2D6',
    'Síndrome serotoninérgica leve a moderada, sedación excesiva, alteração de niveles séricos',
    'Monitorar signos de síndrome serotoninérgica. Iniciar segundo antidepresivo em dosis baja. Preferir combinações com menor sobreposição serotoninérgica',
    'SÍNDROME SEROTONINÉRGICA — Dois antidepresivos; iniciar em dosis baja; monitorar síntomas',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fluoxetina', 'imao reversivel', InteractionSeverity.contraindicated,
    'IMAO inibe degradação de serotonina/noradrenalina. Antidepresivo adiciona liberação ou inhibición de recaptação: acumulación massivo de serotonina',
    'Síndrome serotoninérgica: agitação, hipertermia, mioclonias, rigidez, convulsiones, colapso cardiovascular, morte',
    'CONTRAINDICAÇÃO ABSOLUTA. Respeitar período de lavado de 14 dias entre IMAO e qualquer antidepresivo (21 dias para fluoxetina). Tratamiento de emergência: ciproheptadina + suporte',
    'CONTRAINDICADO — Síndrome serotoninérgica letal; período de lavado 14 dias (21 dias para fluoxetina)',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('imao', 'imao reversivel', InteractionSeverity.moderate,
    'Dois antidepresivos com mecanismos serotoninérgicos sobrepostos ou interacciones farmacocinéticas via CYP2D6',
    'Síndrome serotoninérgica leve a moderada, sedación excesiva, alteração de niveles séricos',
    'Monitorar signos de síndrome serotoninérgica. Iniciar segundo antidepresivo em dosis baja. Preferir combinações com menor sobreposição serotoninérgica',
    'SÍNDROME SEROTONINÉRGICA — Dois antidepresivos; iniciar em dosis baja; monitorar síntomas',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('imao reversivel', 'mirtazapina', InteractionSeverity.contraindicated,
    'IMAO inibe degradação de serotonina/noradrenalina. Antidepresivo adiciona liberação ou inhibición de recaptação: acumulación massivo de serotonina',
    'Síndrome serotoninérgica: agitação, hipertermia, mioclonias, rigidez, convulsiones, colapso cardiovascular, morte',
    'CONTRAINDICAÇÃO ABSOLUTA. Respeitar período de lavado de 14 dias entre IMAO e qualquer antidepresivo (21 dias para fluoxetina). Tratamiento de emergência: ciproheptadina + suporte',
    'CONTRAINDICADO — Síndrome serotoninérgica letal; período de lavado 14 dias (21 dias para fluoxetina)',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('aripiprazol', 'haloperidol', InteractionSeverity.major,
    'Haloperidol prolonga QTc significativamente. Combinación com outro antipsicótico prolonga QTc de forma aditiva',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita. Sedación excesiva',
    'Monitorar QTc antes e durante o tratamiento. Evitar combinación se QTc > 450ms. Preferir monoterapia. Corrigir electrolitos (K+, Mg2+)',
    'TORSADES DE POINTES — Haloperidol prolonga QTc; monitorar ECG; evitar se QTc > 450ms',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('aripiprazol', 'olanzapina', InteractionSeverity.moderate,
    'Dois antipsicóticos: bloqueio aditivo de receptores D2, histaminérgicos (H1) e muscarínicos. Sedación e efectos extrapiramidais aditivos',
    'Sedación excesiva, síndrome extrapiramidal, prolongación QTc, síndrome neuroléptica maligna (raro)',
    'Preferir monoterapia antipsicótica. Se combinación necesaria (p. ex., estabilização aguda), usar menor dosi es posible e monitorar ECG',
    'SEDAÇÃO + QTc — Dois antipsicóticos; preferir monoterapia; monitorar ECG e sintomas extrapiramidais',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('aripiprazol', 'quetiapina', InteractionSeverity.moderate,
    'Dois antipsicóticos: bloqueio aditivo de receptores D2, histaminérgicos (H1) e muscarínicos. Sedación e efectos extrapiramidais aditivos',
    'Sedación excesiva, síndrome extrapiramidal, prolongación QTc, síndrome neuroléptica maligna (raro)',
    'Preferir monoterapia antipsicótica. Se combinación necesaria (p. ex., estabilização aguda), usar menor dosi es posible e monitorar ECG',
    'SEDAÇÃO + QTc — Dois antipsicóticos; preferir monoterapia; monitorar ECG e sintomas extrapiramidais',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('fentanila', 'morfina', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depresión del SNC e do centro respiratório bulbar de forma aditiva',
    'Depresión respiratoria grave, apnea, sedación profunda, coma, óbito',
    'EVITAR combinación de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fentanila', 'opioide', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depresión del SNC e do centro respiratório bulbar de forma aditiva',
    'Depresión respiratoria grave, apnea, sedación profunda, coma, óbito',
    'EVITAR combinación de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fentanila', 'tramadol', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depresión del SNC e do centro respiratório bulbar de forma aditiva',
    'Depresión respiratoria grave, apnea, sedación profunda, coma, óbito',
    'EVITAR combinación de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fentanila', 'metadona', InteractionSeverity.major,
    'Metadona tem vida media prolongada (24-36h) e prolonga QTc por bloqueio IKr. Combinación com outro opioide: depresión respiratoria e QTc aditivos',
    'Depresión respiratoria grave/fatal, Torsades de Pointes, apnea',
    'EVITAR combinación. Se necesario em cuidados paliativos, monitorar SpO₂ continuamente, ECG (QTc) e ter naloxona disponible. Titular dosis muito lentamente',
    'DEPRESSÃO RESP. + QTc — Metadona com opioide; monitorar SpO₂ e ECG; ter naloxona',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('metadona', 'morfina', InteractionSeverity.major,
    'Metadona tem vida media prolongada (24-36h) e prolonga QTc por bloqueio IKr. Combinación com outro opioide: depresión respiratoria e QTc aditivos',
    'Depresión respiratoria grave/fatal, Torsades de Pointes, apnea',
    'EVITAR combinación. Se necesario em cuidados paliativos, monitorar SpO₂ continuamente, ECG (QTc) e ter naloxona disponible. Titular dosis muito lentamente',
    'DEPRESSÃO RESP. + QTc — Metadona com opioide; monitorar SpO₂ e ECG; ter naloxona',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('metadona', 'opioide', InteractionSeverity.major,
    'Metadona tem vida media prolongada (24-36h) e prolonga QTc por bloqueio IKr. Combinación com outro opioide: depresión respiratoria e QTc aditivos',
    'Depresión respiratoria grave/fatal, Torsades de Pointes, apnea',
    'EVITAR combinación. Se necesario em cuidados paliativos, monitorar SpO₂ continuamente, ECG (QTc) e ter naloxona disponible. Titular dosis muito lentamente',
    'DEPRESSÃO RESP. + QTc — Metadona com opioide; monitorar SpO₂ e ECG; ter naloxona',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('metadona', 'tramadol', InteractionSeverity.major,
    'Metadona tem vida media prolongada (24-36h) e prolonga QTc por bloqueio IKr. Combinación com outro opioide: depresión respiratoria e QTc aditivos',
    'Depresión respiratoria grave/fatal, Torsades de Pointes, apnea',
    'EVITAR combinación. Se necesario em cuidados paliativos, monitorar SpO₂ continuamente, ECG (QTc) e ter naloxona disponible. Titular dosis muito lentamente',
    'DEPRESSÃO RESP. + QTc — Metadona com opioide; monitorar SpO₂ e ECG; ter naloxona',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('morfina', 'opioide', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depresión del SNC e do centro respiratório bulbar de forma aditiva',
    'Depresión respiratoria grave, apnea, sedación profunda, coma, óbito',
    'EVITAR combinación de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('opioide', 'tramadol', InteractionSeverity.major,
    'Dois opioides agonistas de receptor μ: depresión del SNC e do centro respiratório bulbar de forma aditiva',
    'Depresión respiratoria grave, apnea, sedación profunda, coma, óbito',
    'EVITAR combinación de dois opioides plenos sem indicação específica. Se necesario (dor refratária), monitorar SpO₂ e ter naloxona disponible. Titular lentamente',
    'APNEA — Dois opioides agonistas μ; depresión respiratoria grave; ter naloxona disponible',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('benzodiazepínico', 'midazolam', InteractionSeverity.major,
    'Midazolam é um benzodiazepínico: potenciação aditiva do receptor GABA-A com depresión del SNC e respiratório',
    'Sedación excesiva, depresión respiratoria, amnésia prolongada, hipotensión',
    'EVITAR combinación de dois benzodiazepínicos. Se necesario em sedación procedural, reducir dosis de ambos em 50% e monitorar SpO₂. Ter flumazenil disponible',
    'DEPRESSÃO RESP. — Dois benzodiazepínicos; reducir dosiss; monitorar SpO₂; ter flumazenil',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('glibenclamida', 'insulina', InteractionSeverity.moderate,
    'Insulina exógena e sulfonilureias/glibenclamida (estimulantes de secreção endógena de insulina) têm efecto hipoglucemiante aditivo',
    'Hipoglucemia grave y prolongada, especialmente com glibenclamida (vida media longa)',
    'Monitorar glucemia 4x/dia. Reducir dosis da sulfonilureia al iniciar insulina. Considerar sustitución por metformina ou iDPP4 para minimizar hipoglucemia',
    'HIPOGLUCEMIA GRAVE — Insulina + sulfonilureia; glibenclamida tem riesgo maior; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('glibenclamida', 'sulfonilureia', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efecto hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar dosiss conforme resposta. Orientar al paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar dosiss',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('insulina', 'metformina', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efecto hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar dosiss conforme resposta. Orientar al paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar dosiss',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('glibenclamida', 'metformina', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efecto hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar dosiss conforme resposta. Orientar al paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar dosiss',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('canagliflozina', 'insulina', InteractionSeverity.moderate,
    'iSGLT2 promovem glicosúria e reduzem glucemia independentemente. Insulina reduz glucemia por captação periférica. Efecto hipoglucemiante aditivo',
    'Hipoglucemia grave, cetoacidosis diabética euglicêmica (mesmo com glucemia normal)',
    'Reducir dosis de insulina basal em 10-20% al iniciar iSGLT2. Monitorar glucemia. Orientar sobre cetoacidosis euglicêmica: checar cetonas se sintomas mesmo com glucemia normal',
    'HIPOGLICEMIA + CETOACIDOSIS EUGLICÊMICA — Reduzir insulina 10-20%; monitorar cetonas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('canagliflozina', 'sulfonilureia', InteractionSeverity.moderate,
    'Gliflozinas (iSGLT2) causam glicosúria independente de insulina. Sulfonilureias/glibenclamida aumentam secreção de insulina. Efecto hipoglucemiante aditivo',
    'Hipoglucemia moderada a grave. Cetoacidosis diabética euglicêmica (rara com iSGLT2)',
    'Monitorar glucemia frecuentemente. Considerar reducción de la dosis de sulfonilureia em 25-50% ao adicionar iSGLT2. Orientar al paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA — iSGLT2 + sulfonilureia; reducir dosis da sulfonilureia 25-50%; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('canagliflozina', 'glibenclamida', InteractionSeverity.moderate,
    'Gliflozinas (iSGLT2) causam glicosúria independente de insulina. Sulfonilureias/glibenclamida aumentam secreção de insulina. Efecto hipoglucemiante aditivo',
    'Hipoglucemia moderada a grave. Cetoacidosis diabética euglicêmica (rara com iSGLT2)',
    'Monitorar glucemia frecuentemente. Considerar reducción de la dosis de sulfonilureia em 25-50% ao adicionar iSGLT2. Orientar al paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA — iSGLT2 + sulfonilureia; reducir dosis da sulfonilureia 25-50%; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('canagliflozina', 'metformina', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efecto hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar dosiss conforme resposta. Orientar al paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar dosiss',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('dapagliflozina', 'sulfonilureia', InteractionSeverity.moderate,
    'Gliflozinas (iSGLT2) causam glicosúria independente de insulina. Sulfonilureias/glibenclamida aumentam secreção de insulina. Efecto hipoglucemiante aditivo',
    'Hipoglucemia moderada a grave. Cetoacidosis diabética euglicêmica (rara com iSGLT2)',
    'Monitorar glucemia frecuentemente. Considerar reducción de la dosis de sulfonilureia em 25-50% ao adicionar iSGLT2. Orientar al paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA — iSGLT2 + sulfonilureia; reducir dosis da sulfonilureia 25-50%; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('dapagliflozina', 'glibenclamida', InteractionSeverity.moderate,
    'Gliflozinas (iSGLT2) causam glicosúria independente de insulina. Sulfonilureias/glibenclamida aumentam secreção de insulina. Efecto hipoglucemiante aditivo',
    'Hipoglucemia moderada a grave. Cetoacidosis diabética euglicêmica (rara com iSGLT2)',
    'Monitorar glucemia frecuentemente. Considerar reducción de la dosis de sulfonilureia em 25-50% ao adicionar iSGLT2. Orientar al paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA — iSGLT2 + sulfonilureia; reducir dosis da sulfonilureia 25-50%; monitorar glucemia',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('dapagliflozina', 'metformina', InteractionSeverity.minor,
    'Dois antidiabéticos com mecanismos diferentes: potencial efecto hipoglucemiante aditivo ou sinérgico',
    'Hipoglucemia leve a moderada. Desconforto GI aditivo (especialmente metformina + outros)',
    'Monitorar glucemia. Ajustar dosiss conforme resposta. Orientar al paciente sobre sintomas de hipoglucemia',
    'HIPOGLICEMIA LEVE — Monitorar glucemia ao combinar antidiabéticos; ajustar dosiss',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('azatioprina', 'metotrexato', InteractionSeverity.major,
    'Metotrexato e azatioprina têm efectos mielossupressores aditivos. Metotrexato inibe DHFR; azatioprina interfere na síntese de purinas',
    'Mielossupresión grave: pancitopenia, infecções oportunistas, mucosite, hepatotoxicidad aditiva',
    'EVITAR combinación. Se necesario em enfermedades graves, monitorar hemograma semanal, función hepática e renal. Suplementar ácido fólico',
    'MIELOSUPRESIÓN GRAVE — Metotrexato + azatioprina; hemograma semanal; ácido fólico obligatorio',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('azatioprina', 'corticosteroide sistemico', InteractionSeverity.moderate,
    'Dois inmunosupresores: imunossupresión aditiva com riesgo aumentado de infecções oportunistas e malignidades linfoides',
    'Infecções oportunistas graves (CMV, PCP, fungos), linfoma, hepatotoxicidad, nefrotoxicidad',
    'Monitorar hemograma, función hepática e renal mensalmente. Profilaxia anti-infecciosa conforme protocolo (SMX-TMP para PCP). Vacinas inativadas atualizadas',
    'IMUNOSSUPRESSÃO ADITIVA — Monitorar hemograma; profilaxia anti-infecciosa; evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('ciclosporina', 'metotrexato', InteractionSeverity.moderate,
    'Dois inmunosupresores: imunossupresión aditiva com riesgo aumentado de infecções oportunistas e malignidades linfoides',
    'Infecções oportunistas graves (CMV, PCP, fungos), linfoma, hepatotoxicidad, nefrotoxicidad',
    'Monitorar hemograma, función hepática e renal mensalmente. Profilaxia anti-infecciosa conforme protocolo (SMX-TMP para PCP). Vacinas inativadas atualizadas',
    'IMUNOSSUPRESSÃO ADITIVA — Monitorar hemograma; profilaxia anti-infecciosa; evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('corticosteroide sistemico', 'metotrexato', InteractionSeverity.moderate,
    'Dois inmunosupresores: imunossupresión aditiva com riesgo aumentado de infecções oportunistas e malignidades linfoides',
    'Infecções oportunistas graves (CMV, PCP, fungos), linfoma, hepatotoxicidad, nefrotoxicidad',
    'Monitorar hemograma, función hepática e renal mensalmente. Profilaxia anti-infecciosa conforme protocolo (SMX-TMP para PCP). Vacinas inativadas atualizadas',
    'IMUNOSSUPRESSÃO ADITIVA — Monitorar hemograma; profilaxia anti-infecciosa; evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('metotrexato', 'tacrolimo', InteractionSeverity.moderate,
    'Dois inmunosupresores: imunossupresión aditiva com riesgo aumentado de infecções oportunistas e malignidades linfoides',
    'Infecções oportunistas graves (CMV, PCP, fungos), linfoma, hepatotoxicidad, nefrotoxicidad',
    'Monitorar hemograma, función hepática e renal mensalmente. Profilaxia anti-infecciosa conforme protocolo (SMX-TMP para PCP). Vacinas inativadas atualizadas',
    'IMUNOSSUPRESSÃO ADITIVA — Monitorar hemograma; profilaxia anti-infecciosa; evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('acetazolamida', 'furosemida', InteractionSeverity.moderate,
    'Dois diuréticos com mecanismos distintos: efectos diuréticos e natriuréticos aditivos, depleción de volumen aumentada',
    'Hipotensión ortostática, depleción de volumen, IRA pré-renal, distúrbios eletrolíticos',
    'Monitorar PA, función renal e electrolitos regularmente. Iniciar combinación em dosis bajas. Orientar hidratação adecuada',
    'DEPLEÇÃO DE VOLUME — Dois diuréticos; monitorar PA, creatinina e electrolitos',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('acetazolamida', 'hidroclorotiazida', InteractionSeverity.moderate,
    'Dois diuréticos com mecanismos distintos: efectos diuréticos e natriuréticos aditivos, depleción de volumen aumentada',
    'Hipotensión ortostática, depleción de volumen, IRA pré-renal, distúrbios eletrolíticos',
    'Monitorar PA, función renal e electrolitos regularmente. Iniciar combinación em dosis bajas. Orientar hidratação adecuada',
    'DEPLEÇÃO DE VOLUME — Dois diuréticos; monitorar PA, creatinina e electrolitos',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('acetazolamida', 'espironolactona', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efectos opostos no potássio, mas depleción de volumen e hipotensión aditivos',
    'Hipotensión, depleción de volumen, riesgo de IRA. Potassemia impredecible (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular dosis para manter K+ 3,5-5 mEq/L. Monitorar signos de depleción de volumen',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSIÓN — Monitorar K+, creatinina e PA; titular dosis',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('acetazolamida', 'eplerenona', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efectos opostos no potássio, mas depleción de volumen e hipotensión aditivos',
    'Hipotensión, depleción de volumen, riesgo de IRA. Potassemia impredecible (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular dosis para manter K+ 3,5-5 mEq/L. Monitorar signos de depleción de volumen',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSIÓN — Monitorar K+, creatinina e PA; titular dosis',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('acetazolamida', 'finerenona', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efectos opostos no potássio, mas depleción de volumen e hipotensión aditivos',
    'Hipotensión, depleción de volumen, riesgo de IRA. Potassemia impredecible (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular dosis para manter K+ 3,5-5 mEq/L. Monitorar signos de depleción de volumen',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSIÓN — Monitorar K+, creatinina e PA; titular dosis',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('eplerenona', 'espironolactona', InteractionSeverity.major,
    'Dois diuréticos poupadores de potássio: retenção aditiva de K+ por bloqueio de aldosterona/receptores de mineralocorticóide',
    'Hiperpotasemia grave (K+ > 6 mEq/L), arritmias cardíacas, paro cardíaco em asistolia',
    'EVITAR combinación de dois poupadores de K+. Se necesario, monitorar K+ sérico cada 3-7 días. Restrição de K+ na dieta. Suspender se K+ > 5,5 mEq/L',
    'HIPERPOTASEMIA GRAVE — Dois poupadores de K+; monitorar K+ sérico; suspender se K+ > 5,5 mEq/L',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('eplerenona', 'finerenona', InteractionSeverity.major,
    'Dois diuréticos poupadores de potássio: retenção aditiva de K+ por bloqueio de aldosterona/receptores de mineralocorticóide',
    'Hiperpotasemia grave (K+ > 6 mEq/L), arritmias cardíacas, paro cardíaco em asistolia',
    'EVITAR combinación de dois poupadores de K+. Se necesario, monitorar K+ sérico cada 3-7 días. Restrição de K+ na dieta. Suspender se K+ > 5,5 mEq/L',
    'HIPERPOTASEMIA GRAVE — Dois poupadores de K+; monitorar K+ sérico; suspender se K+ > 5,5 mEq/L',
    EvidenceLevel.established,
    {RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('eplerenona', 'furosemida', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efectos opostos no potássio, mas depleción de volumen e hipotensión aditivos',
    'Hipotensión, depleción de volumen, riesgo de IRA. Potassemia impredecible (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular dosis para manter K+ 3,5-5 mEq/L. Monitorar signos de depleción de volumen',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSIÓN — Monitorar K+, creatinina e PA; titular dosis',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('eplerenona', 'hidroclorotiazida', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efectos opostos no potássio, mas depleción de volumen e hipotensión aditivos',
    'Hipotensión, depleción de volumen, riesgo de IRA. Potassemia impredecible (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular dosis para manter K+ 3,5-5 mEq/L. Monitorar signos de depleción de volumen',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSIÓN — Monitorar K+, creatinina e PA; titular dosis',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('finerenona', 'furosemida', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efectos opostos no potássio, mas depleción de volumen e hipotensión aditivos',
    'Hipotensión, depleción de volumen, riesgo de IRA. Potassemia impredecible (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular dosis para manter K+ 3,5-5 mEq/L. Monitorar signos de depleción de volumen',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSIÓN — Monitorar K+, creatinina e PA; titular dosis',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('finerenona', 'hidroclorotiazida', InteractionSeverity.moderate,
    'Diurético poupador de K+ combinado com diurético perdedor de K+: efectos opostos no potássio, mas depleción de volumen e hipotensión aditivos',
    'Hipotensión, depleción de volumen, riesgo de IRA. Potassemia impredecible (normo, hipo ou hiperpotasemia)',
    'Monitorar K+ sérico, función renal e PA regularmente. Titular dosis para manter K+ 3,5-5 mEq/L. Monitorar signos de depleción de volumen',
    'POTASSEMIA IMPREVISÍVEL + HIPOTENSIÓN — Monitorar K+, creatinina e PA; titular dosis',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('atorvastatina', 'sinvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatía por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatía grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efecto, aumentar dosis de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólisis por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('atorvastatina', 'rosuvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatía por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatía grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efecto, aumentar dosis de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólisis por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('atorvastatina', 'estatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatía por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatía grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efecto, aumentar dosis de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólisis por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('estatina', 'sinvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatía por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatía grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efecto, aumentar dosis de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólisis por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('estatina', 'rosuvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatía por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatía grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efecto, aumentar dosis de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólisis por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('rosuvastatina', 'sinvastatina', InteractionSeverity.contraindicated,
    'Duas estatinas: miopatía por inhibición aditiva de HMG-CoA redutase e depleção de coenzima Q10 muscular',
    'Miopatía grave, rabdomiólisis, IRA por mioglobinúria, morte',
    'CONTRAINDICADO. Usar apenas uma estatina. Se necesario potencializar efecto, aumentar dosis de uma estatina ou adicionar ezetimiba',
    'CONTRAINDICADO — Rabdomiólisis por duas estatinas; usar apenas uma; adicionar ezetimiba se necesario',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fenofibrato', 'gemfibrozil', InteractionSeverity.major,
    'Dois fibratos: miopatía por depleção aditiva de coenzima Q10 e interferência na beta-oxidação muscular. Gemfibrozil inibe glicuronidação de outras estatinas e fibratos',
    'Miopatía, rabdomiólisis, elevación de CPK, IRA',
    'EVITAR combinación de dois fibratos. Gemfibrozil tem maior riesgo de rabdomiólisis que fenofibrato. Se necesario control lipídico adicional, adicionar ezetimiba ou niacina',
    'RABDOMIÓLISIS — Dois fibratos; evitar combinación; preferir fenofibrato isolado + ezetimiba',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('esomeprazol', 'omeprazol', InteractionSeverity.moderate,
    'Dois IBPs com mecanismo idêntico (inhibición de H+/K+-ATPase): supresión ácida excessiva sem benefício adicional. Omeprazol/esomeprazol inibem CYP2C19',
    'Supresión ácida excessiva: deficiência de B12, hipomagnesemia, colonização por Clostridium difficile, hipergastrinemia',
    'EVITAR dois IBPs. Usar apenas o IBP mais adecuado para a indicação. Revisar necessidade IBP regularmente (deprescrição cuando sea posible)',
    'EVITAR DOIS IBPs — Supresión ácida excessiva; riesgo de B12, Mg2+ e infecção por C. difficile',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('esomeprazol', 'pantoprazol', InteractionSeverity.moderate,
    'Dois IBPs com mecanismo idêntico (inhibición de H+/K+-ATPase): supresión ácida excessiva sem benefício adicional. Omeprazol/esomeprazol inibem CYP2C19',
    'Supresión ácida excessiva: deficiência de B12, hipomagnesemia, colonização por Clostridium difficile, hipergastrinemia',
    'EVITAR dois IBPs. Usar apenas o IBP mais adecuado para a indicação. Revisar necessidade IBP regularmente (deprescrição cuando sea posible)',
    'EVITAR DOIS IBPs — Supresión ácida excessiva; riesgo de B12, Mg2+ e infecção por C. difficile',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('omeprazol', 'pantoprazol', InteractionSeverity.moderate,
    'Dois IBPs com mecanismo idêntico (inhibición de H+/K+-ATPase): supresión ácida excessiva sem benefício adicional. Omeprazol/esomeprazol inibem CYP2C19',
    'Supresión ácida excessiva: deficiência de B12, hipomagnesemia, colonização por Clostridium difficile, hipergastrinemia',
    'EVITAR dois IBPs. Usar apenas o IBP mais adecuado para a indicação. Revisar necessidade IBP regularmente (deprescrição cuando sea posible)',
    'EVITAR DOIS IBPs — Supresión ácida excessiva; riesgo de B12, Mg2+ e infecção por C. difficile',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('omeprazol', 'sulfato ferroso', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorción. IBP pode reduzir absorción de sulfato ferroso e Ca',
    'Reducción de absorción de ferro, cálcio e antiácidos. Reducción leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h después de o IBP para maximizar absorción',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h después de o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('esomeprazol', 'sulfato ferroso', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorción. IBP pode reduzir absorción de sulfato ferroso e Ca',
    'Reducción de absorción de ferro, cálcio e antiácidos. Reducción leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h después de o IBP para maximizar absorción',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h después de o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('pantoprazol', 'sulfato ferroso', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorción. IBP pode reduzir absorción de sulfato ferroso e Ca',
    'Reducción de absorción de ferro, cálcio e antiácidos. Reducción leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h después de o IBP para maximizar absorción',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h después de o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('antiácido', 'esomeprazol', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorción. IBP pode reduzir absorción de sulfato ferroso e Ca',
    'Reducción de absorción de ferro, cálcio e antiácidos. Reducción leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h después de o IBP para maximizar absorción',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h después de o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('antiácido', 'omeprazol', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorción. IBP pode reduzir absorción de sulfato ferroso e Ca',
    'Reducción de absorción de ferro, cálcio e antiácidos. Reducción leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h después de o IBP para maximizar absorción',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h después de o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('antiácido', 'pantoprazol', InteractionSeverity.minor,
    'IBPs elevam pH gástrico; antiácidos/sulfato ferroso/carbonato de cálcio dependem de ambiente ácido para absorción. IBP pode reduzir absorción de sulfato ferroso e Ca',
    'Reducción de absorción de ferro, cálcio e antiácidos. Reducción leve da eficácia do IBP se tomados junto',
    'Separar a administração por pelo menos 2h. Sulfato ferroso: administrar em jejum, 1h antes ou 2h después de o IBP para maximizar absorción',
    'ABSORÇÃO REDUZIDA — Separar por 2h; sulfato ferroso: 1h antes ou 2h después de o IBP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('antiácido', 'sulfato ferroso', InteractionSeverity.moderate,
    'Antiácidos (cátions Al3+, Mg2+, Ca2+) quelam o ferro ferroso do sulfato ferroso, formando complexos insolúveis não absorvíveis',
    'Absorción de ferro reducida em até 70%, falha no tratamiento de anemia ferropriva',
    'Administrar sulfato ferroso 2h antes ou 4h después de antiácidos. Carbonato de cálcio: separar por pelo menos 2h. Monitorar ferritina e Hb a cada 4-8 semanas',
    'QUELAÇÃO DE FERRO — Antiácido reduce la absorción do ferro em 70%; separar por 2-4h',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('carbonato de calcio', 'sulfato ferroso', InteractionSeverity.moderate,
    'Antiácidos (cátions Al3+, Mg2+, Ca2+) quelam o ferro ferroso do sulfato ferroso, formando complexos insolúveis não absorvíveis',
    'Absorción de ferro reducida em até 70%, falha no tratamiento de anemia ferropriva',
    'Administrar sulfato ferroso 2h antes ou 4h después de antiácidos. Carbonato de cálcio: separar por pelo menos 2h. Monitorar ferritina e Hb a cada 4-8 semanas',
    'QUELAÇÃO DE FERRO — Antiácido reduce la absorción do ferro em 70%; separar por 2-4h',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('anticonceptivo', 'levotiroxina', InteractionSeverity.moderate,
    'Estrogênios (anticonceptivo oral) aumentam globulina ligadora de tiroxina (TBG), reduzindo T4 livre disponible. Maior necessidade levotiroxina',
    'Hipotiroidismo por aumento da ligação proteica da T4: fadiga, aumento de peso, bradicardia',
    'Monitorar TSH 6-8 semanas después de iniciar/suspender anticonceptivo. Aumentar dosis de levotiroxina em 20-30% se necesario',
    'HIPOTIROIDISMO — Estrogênio aumenta TBG; monitorar TSH 6-8 semanas; ajustar dosis de levotiroxina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('anticonceptivo', 'tamoxifeno', InteractionSeverity.major,
    'Tamoxifeno é um antagonista de receptor de estrogênio. Anticonceptivo com estrogênio pode antagonizar o efecto antiestrogênico do tamoxifeno',
    'Reducción de la eficacia do tamoxifeno no tratamiento de câncer de mama receptor hormonal positivo. Riesgo de recidiva tumoral',
    'EVITAR combinación. Usar contracepção não hormonal (DIU de cobre, preservativo) durante tamoxifeno. Discutir com oncologista',
    'ANTAGONISMO FARMACOLÓGICO — Estrogênio antagoniza tamoxifeno; usar contracepção não hormonal',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dexametasona', 'levotiroxina', InteractionSeverity.moderate,
    'Glicocorticóides em altas dosiss inibem conversão periférica de T4 em T3 (inhibición de deiodinase tipo I) e reduzem liberação de TSH',
    'Hipotiroidismo relativo em uso prolongado, alteração nos valores de TSH dificultando ajuste de levotiroxina',
    'Monitorar TSH e T4 livre durante uso de dexametasona. Ajustar dosis de levotiroxina conforme nivel de TSH. Reavaliar al suspender dexametasona',
    'CONVERSÃO T4→T3 REDUZIDA — Dexametasona inibe deiodinase; monitorar TSH; ajustar levotiroxina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('dexametasona', 'tamoxifeno', InteractionSeverity.moderate,
    'Dexametasona induz CYP3A4 e P-glicoproteína, podendo reduzir niveles plasmáticos de tamoxifeno e seu metabólito ativo endoxifeno',
    'Reducción de la eficacia antiestrogênica do tamoxifeno, riesgo de recidiva em câncer de mama',
    'Monitorar respuesta clínica ao tamoxifeno. Se dexametasona em uso prolongado, discutir com oncologista alternativa ao tamoxifeno (inhibidores de aromatase podem ser afetados similarmente)',
    'EFICÁCIA DE TAMOXIFENO REDUZIDA — Dexametasona induz CYP3A4; monitorar respuesta oncológica',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('daptomicina', 'vancomicina', InteractionSeverity.moderate,
    'Dois agentes com atividade contra Gram-positivos: potencial nefrotoxicidad aditiva. Sem sinergismo estabelecido para a maioria das infecções',
    'Nefrotoxicidad aditiva, miopatía por daptomicina potencializada',
    'Monitorar función renal diariamente e CPK semanal (daptomicina). Monitorar nivel sérico de vancomicina (meta: AUC/MIC 400-600). Evitar combinación sem indicação específica',
    'NEFROTOXICIDAD ADITIVA — Monitorar creatinina e CPK; dosar nivel de vancomicina',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('linezolida', 'vancomicina', InteractionSeverity.minor,
    'Linezolida e vancomicina têm cobertura sobreposta para Gram-positivos. Sem interacción farmacocinética significativa, mas trombocitopenia e mielosupresión aditivas com linezolida',
    'Trombocitopenia, anemia, mielosupresión por linezolida. Nefrotoxicidad de vancomicina',
    'Monitorar hemograma 2x/semana (linezolida). Monitorar función renal e nivel de vancomicina. Combinación raramente justificada — revisar cobertura necesaria',
    'MIELOSUPRESIÓN + NEFROTOXICIDAD — Monitorar hemograma e creatinina; revisar indicação da combinación',
    EvidenceLevel.probable,
    {RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('sulfametoxazol', 'trimetoprima', InteractionSeverity.moderate,
    'Sulfametoxazol + trimetoprima (co-trimoxazol): sinergia intencional por bloqueio sequencial da síntese de folato bacteriano. Porém: hiperpotasemia, mielosupresión e nefrotoxicidad aditivas',
    'Hiperpotasemia (trimetoprima bloqueia ENaC renal), mielosupresión, cristalúria (sulfametoxazol), nefrotoxicidad',
    'Combinación intencional terapéutica. Monitorar K+, creatinina e hemograma semanalmente. Hidratação adecuada. Suplementar ácido fólico em uso prolongado. Evitar em IR grave (TFG < 15)',
    'CO-TRIMOXAZOL — Hiperpotasemia + mielosupresión; monitorar K+, creatinina e hemograma',
    EvidenceLevel.established,
    {RiskType.other, RiskType.nephrotoxicity},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('fluconazol', 'isavuconazol', InteractionSeverity.major,
    'Fluconazol e isavuconazol são azólicos que prolongam QTc (isavuconazol: encurta levemente, mas a combinación tem efecto impredecible). Ambos inibem CYP3A4 com potencial interacción. Inhibición aditiva de ergosterol fúngico',
    'Interacción farmacocinética impredecible (ambos inibem CYP3A4 mutuamente), prolongación QTc incerto, toxicidad hepática aditiva',
    'EVITAR combinación de dois azólicos. Usar o mais adecuado para o fungo isolado. Monitorar ECG e función hepática se exposición inevitável',
    'DOIS AZÓLICOS — Interacción CYP3A4 impredecible; hepatotoxicidad aditiva; usar apenas um azólico',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.other},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('azitromicina', 'eritromicina', InteractionSeverity.major,
    'Dois macrolídeos: prolongamento aditivo do QTc por bloqueio de canais IKr. Inhibición de CYP3A4 aditiva (exceto azitromicina)',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita. Interacciones medicamentosas aditivas por inhibición de CYP3A4',
    'EVITAR combinación de dois macrolídeos. Usar o mais adecuado para a indicação clínica. Monitorar QTc se exposición inevitável',
    'TORSADES DE POINTES — Dois macrolídeos prolongam QTc de forma aditiva; usar apenas um',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('azitromicina', 'claritromicina', InteractionSeverity.major,
    'Dois macrolídeos: prolongamento aditivo do QTc por bloqueio de canais IKr. Inhibición de CYP3A4 aditiva (exceto azitromicina)',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita. Interacciones medicamentosas aditivas por inhibición de CYP3A4',
    'EVITAR combinación de dois macrolídeos. Usar o mais adecuado para a indicação clínica. Monitorar QTc se exposición inevitável',
    'TORSADES DE POINTES — Dois macrolídeos prolongam QTc de forma aditiva; usar apenas um',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('dexmedetomidina', 'levosimendan', InteractionSeverity.moderate,
    'Dexmedetomidina (α2-agonista central) causa bradicardia e hipotensión. Combinada com inodilatador (levosimendan/milrinona): hipotensión aditiva e hemodinâmica complexa',
    'Hipotensión grave, bradicardia, necessidade vasopresores',
    'Monitorar PA e FC continuamente em UTI. Titular dexmedetomidina lentamente. Ter noradrenalina disponible para suporte vasopresor',
    'HIPOTENSÃO + BRADICARDIA — Dexmedetomidina + inodilatador; monitorar PA e FC; ter vasopresor disponible',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('dexmedetomidina', 'milrinona', InteractionSeverity.moderate,
    'Dexmedetomidina (α2-agonista central) causa bradicardia e hipotensión. Combinada com inodilatador (levosimendan/milrinona): hipotensión aditiva e hemodinâmica complexa',
    'Hipotensión grave, bradicardia, necessidade vasopresores',
    'Monitorar PA e FC continuamente em UTI. Titular dexmedetomidina lentamente. Ter noradrenalina disponible para suporte vasopresor',
    'HIPOTENSÃO + BRADICARDIA — Dexmedetomidina + inodilatador; monitorar PA e FC; ter vasopresor disponible',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('levosimendan', 'milrinona', InteractionSeverity.moderate,
    'Levosimendan (sensibilizador de cálcio + abertura de KATP) e milrinona (inhibidor de PDE3): ambos causam vasodilatação e aumento do débito cardíaco. Efectos hemodinâmicos aditivos',
    'Hipotensión grave, taquicardia, arritmias ventriculares por efecto inotrópico e vasodilatador excessivo',
    'Monitorar PA, FC e débito cardíaco (Swan-Ganz ou ecocardiograma) continuamente. Reducir dosis de um dos agentes se hipotensión. Reposição volêmica adecuada',
    'HIPOTENSIÓN GRAVE — Dois inodilatadores; monitorar hemodinâmica continuamente; titular dosis',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('levosimendan', 'propofol', InteractionSeverity.moderate,
    'Propofol causa vasodilatação e depressão miocárdica direta. Combinado com inodilatador: hipotensión aditiva por vasodilatação somada e depressão cardíaca',
    'Hipotensión grave, especialmente em bolus de propofol. Depressão cardíaca aditiva',
    'Evitar bolus rápidos de propofol. Usar infusão contínua em dosis baja. Monitorar PA invasiva. Ter vasopresor disponible (noradrenalina)',
    'HIPOTENSIÓN — Propofol + inodilatador; evitar bolus; monitorar PA; ter vasopresor',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('levosimendan', 'rocurônio', InteractionSeverity.minor,
    'Rocurônio (bloqueador neuromuscular adespolarizante) associado a outros agentes de UTI: sem interacción farmacocinética direta, mas contexto de sedoanalgesia complexa',
    'Paralisia muscular prolongada em contexto de sedación profunda. Dificulta evaluación neurológica',
    'Monitorar grau de bloqueio neuromuscular (TOF - train-of-four). Usar sugamadex para reversão rápida se necesario. Manter sedación adecuada durante bloqueio',
    'BLOQUEIO NEUROMUSCULAR — Monitorar TOF; ter sugamadex disponible; manter sedación adecuada',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('milrinona', 'propofol', InteractionSeverity.moderate,
    'Propofol causa vasodilatação e depressão miocárdica direta. Combinado com inodilatador: hipotensión aditiva por vasodilatação somada e depressão cardíaca',
    'Hipotensión grave, especialmente em bolus de propofol. Depressão cardíaca aditiva',
    'Evitar bolus rápidos de propofol. Usar infusão contínua em dosis baja. Monitorar PA invasiva. Ter vasopresor disponible (noradrenalina)',
    'HIPOTENSIÓN — Propofol + inodilatador; evitar bolus; monitorar PA; ter vasopresor',
    EvidenceLevel.probable,
    {RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('milrinona', 'rocurônio', InteractionSeverity.minor,
    'Rocurônio (bloqueador neuromuscular adespolarizante) associado a outros agentes de UTI: sem interacción farmacocinética direta, mas contexto de sedoanalgesia complexa',
    'Paralisia muscular prolongada em contexto de sedación profunda. Dificulta evaluación neurológica',
    'Monitorar grau de bloqueio neuromuscular (TOF - train-of-four). Usar sugamadex para reversão rápida se necesario. Manter sedación adecuada durante bloqueio',
    'BLOQUEIO NEUROMUSCULAR — Monitorar TOF; ter sugamadex disponible; manter sedación adecuada',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('propofol', 'rocurônio', InteractionSeverity.minor,
    'Rocurônio (bloqueador neuromuscular adespolarizante) associado a outros agentes de UTI: sem interacción farmacocinética direta, mas contexto de sedoanalgesia complexa',
    'Paralisia muscular prolongada em contexto de sedación profunda. Dificulta evaluación neurológica',
    'Monitorar grau de bloqueio neuromuscular (TOF - train-of-four). Usar sugamadex para reversão rápida se necesario. Manter sedación adecuada durante bloqueio',
    'BLOQUEIO NEUROMUSCULAR — Monitorar TOF; ter sugamadex disponible; manter sedación adecuada',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression},
    ['Micromedex 2024', 'UpToDate 2024']),


  ('ciprofloxacino', 'quinolona', InteractionSeverity.contraindicated,
    'Ciprofloxacino é uma quinolona fluorada: uso concomitante representa duplicação do mesmo mecanismo de ação (inhibición de DNA-girase/topoisomerase IV)',
    'Toxicidad por quinolona aditiva: QTc prolongado, tendinite/ruptura de tendão, neurotoxicidad, fotossensibilidade',
    'DUPLICAÇÃO: usar apenas uma quinolona. Selecionar a mais adecuada para o patógeno. Sem benefício adicional de duas quinolonas',
    'DUPLICAÇÃO DE QUINOLONA — Ciprofloxacino é quinolona; usar apenas uma; sem benefício adicional',
    EvidenceLevel.established,
    {RiskType.qtProlongation},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),


  ('paracetamol', 'rifampicina', InteractionSeverity.major,
    'Rifampicina é potente inductor de CYP2E1 e CYP3A4, aumentando conversão de paracetamol em seu metabólito hepatotóxico NAPQI. Depleção de glutationa hepática',
    'Hepatotoxicidad grave por paracetamol em dosiss que seriam normalmente seguras. Riesgo especialmente alto em dosiss >2g/dia',
    'Limitar paracetamol a ≤1,5 g/dia durante rifampicina. Monitorar función hepática mensalmente. Preferir analgésico alternativo (tramadol em baixa dosis, dipirona)',
    'HEPATOTOXICIDAD — Rifampicina induz CYP2E1; limitar paracetamol a ≤1,5g/dia; monitorar TGO/TGP',
    EvidenceLevel.established,
    {RiskType.other},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),


  ('colchicina', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 e P-glicoproteína (P-gp), reduzindo absorción e aumentando eliminación de colchicina. Niveles de colchicina reducidos em 50-70%',
    'Falha terapéutica da colchicina (crise de gota não controlada, falha na profilaxia de pericardite)',
    'Aumentar dosis de colchicina com cautela ao usar rifampicina. Monitorar respuesta clínica. Considerar corticoide ou AINE como alternativa para crise de gota',
    'COLCHICINA REDUZIDA 50-70% — Rifampicina induz P-gp e CYP3A4; aumentar dosis ou usar alternativa',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),


  // ── LOTE 5 — 159 pares novos ───────────────────────────────────────────────

  // ── 1. AINEs específicos × Anticoagulantes ───────────────────────────────

  ('warfarina', 'aine', InteractionSeverity.major,
    'Deslocamento da ligação proteica + inhibición plaquetária + irritação mucosa gástrica',
    'Elevación del INR y riesgo de sangrado GI grave',
    'Evitar AINEs com warfarina. Usar paracetamol como alternativa. Se imprescindível, usar por ≤3 dias com monitoramento de INR',
    'ALTO RIESGO — AINEs elevam INR e causam sangrado GI',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('apixabana', 'aine', InteractionSeverity.major,
    'Inhibición plaquetária aditiva ao efecto anticoagulante do fator Xa; irritação mucosa',
    'Riesgo aumentado de sangrado GI e sistêmico',
    'Evitar combinación. Si inevitable, usar AINE por período mínimo e monitorar signos de sangrado',
    'RIESGO HEMORRÁGICO — AINEs potencializam apixabana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Micromedex 2024', 'UpToDate 2024', 'ESC 2021']),

  ('rivaroxabana', 'aine', InteractionSeverity.major,
    'Inhibición plaquetária aditiva + efecto anti-Xa somado à lesão mucosa pelos AINEs',
    'Riesgo aumentado de sangrado GI grave',
    'Evitar combinación. Se necesario uso pontual, proteger mucosa com IBP e monitorar sangrado',
    'RIESGO HEMORRÁGICO — AINEs potencializam rivaroxabana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('dabigatrana', 'aine', InteractionSeverity.major,
    'Inhibición plaquetária aditiva ao bloqueio direto da trombina; lesão gástrica pelos AINEs',
    'Riesgo aumentado de sangrado GI, especialmente com dabigatrana (maior incidência GI)',
    'Evitar. Dabigatrana já tem maior riesgo GI basal; AINEs agravam significativamente',
    'RIESGO HEMORRÁGICO GI ELEVADO — Combinación perigosa com dabigatrana',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Micromedex 2024', 'UpToDate 2024', 'RE-LY Trial']),

  ('heparina', 'aine', InteractionSeverity.major,
    'Inhibición plaquetária pelos AINEs soma-se ao efecto anticoagulante da heparina',
    'Riesgo hemorrágico aumentado, especialmente sangrado GI',
    'Evitar combinación. Usar paracetamol como analgésico alternativo durante anticoagulação com heparina',
    'RIESGO HEMORRÁGICO — AINEs potencializam heparina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  // ── 2. Ticagrelor × Anticoagulantes ──────────────────────────────────────

  ('apixabana', 'ticagrelor', InteractionSeverity.major,
    'Dupla inhibición: anticoagulação por fator Xa + inhibición plaquetária P2Y12; sem antídoto específico para combinación',
    'Riesgo hemorrágico grave; triplamente aumentado se aspirina associada',
    'Usar apenas em indicação absolutamente necesaria (ex: SCA + FA + stent recente). Associar IBP. Checar guidelines',
    'TRIPLA ANTITROMBÓTICA — Riesgo hemorrágico muito elevado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['ESC 2023', 'Micromedex 2024', 'UpToDate 2024']),

  ('rivaroxabana', 'ticagrelor', InteractionSeverity.major,
    'Inhibición plaquetária P2Y12 + anticoagulação oral direta; rivaroxabana inibe CYP3A4/P-gp, podendo elevar niveles de ticagrelor',
    'Riesgo hemorrágico muito elevado; ticagrelor pode ter nivel aumentado',
    'Combinación aceitável apenas em contexto específico (SCA + FA). Duración mínima, com IBP obligatorio',
    'ALTO RIESGO HEMORRÁGICO — Ticagrelor pode ter nivel elevado por rivaroxabana',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['ESC 2023', 'UpToDate 2024']),

  ('dabigatrana', 'ticagrelor', InteractionSeverity.major,
    'Ticagrelor inibe P-gp, elevando os niveles plasmáticos de dabigatrana em ~30%',
    'Riesgo hemorrágico aumentado por dupla ação antitrombótica + elevación do nivel de dabigatrana',
    'Evitar ou usar dosis reducida de dabigatrana (110 mg 2x/dia). Monitorar signos de sangrado rigurosamente',
    'NÍVEL DE DABIGATRANA AUMENTADO 30% — Ticagrelor inibe P-gp',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'ESC 2023']),

  ('warfarina', 'ticagrelor', InteractionSeverity.major,
    'Inhibición plaquetária P2Y12 + anticoagulação com warfarina; sem impacto relevante no INR, mas riesgo hemorrágico aditivo',
    'Riesgo hemorrágico grave pela combinación anticoagulante + antiagregante',
    'Usar apenas com indicação formal. Manter INR 2,0–2,5. Associar IBP. Monitorar signos de sangrado',
    'RIESGO HEMORRÁGICO GRAVE — Combinación anticoagulante + antiagregante',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['ESC 2023', 'AHA 2023', 'Micromedex 2024']),

  ('heparina', 'ticagrelor', InteractionSeverity.major,
    'Inhibición plaquetária P2Y12 + anticoagulação parenteral; riesgo hemorrágico aditivo',
    'Riesgo de sangrado aumentado no contexto de SCA/internación',
    'Combinación comum em SCA; manter vigilancia de sangrado; reverter heparina se necesario',
    'RIESGO HEMORRÁGICO — Combinación frecuente em SCA; vigiar sangrado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['ESC 2023', 'Micromedex 2024']),

  // ── 3. Dabigatrana × Verapamil / Diltiazem / Amiodarona ──────────────────

  ('dabigatrana', 'verapamil', InteractionSeverity.major,
    'Verapamil inibe fortemente a P-glicoproteína, principal via de eliminación da dabigatrana, elevando seus niveles em 50–180%',
    'Aumento significativo dos niveles de dabigatrana → riesgo hemorrágico grave',
    'Reducir dosis de dabigatrana para 110 mg 2x/dia. Monitorar signos de sangrado. Evitar em insuficiencia renal',
    'NÍVEL DE DABIGATRANA AUMENTADO 50–180% — Reducir dosis para 110 mg',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'EMA SmPC Pradaxa']),

  ('dabigatrana', 'diltiazem', InteractionSeverity.moderate,
    'Diltiazem inibe parcialmente a P-gp, elevando os niveles de dabigatrana em ~20–40%',
    'Moderado aumento dos niveles de dabigatrana com potencial hemorrágico',
    'Monitorar signos de sangrado. Considerar reducción de dosis en pacientes com riesgo aumentado ou insuficiencia renal',
    'NÍVEL DABIGATRANA +20–40% — Diltiazem inibe P-gp parcialmente',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('dabigatrana', 'amiodarona', InteractionSeverity.major,
    'Amiodarona e seu metabólito DEA inibem P-gp, elevando os niveles de dabigatrana em 12–60%; asociación de arritmia de base',
    'Elevación dos niveles de dabigatrana com riesgo hemorrágico, especialmente en ancianos com FA',
    'Monitorar sangrado rigurosamente. Considerar reducción de dosis para 110 mg 2x/dia. Avaliar función renal periodicamente',
    'NÍVEL DABIGATRANA ELEVADO — Amiodarona inibe P-gp; monitorar em FA',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'ESC 2020']),

  // ── 4. Rivaroxabana × Amiodarona ─────────────────────────────────────────

  ('rivaroxabana', 'amiodarona', InteractionSeverity.moderate,
    'Amiodarona inibe CYP3A4 e P-gp, vías de metabolismo de la rivaroxabana, elevando seus niveles plasmáticos em ~10–40%',
    'Aumento moderado dos niveles de rivaroxabana com posible riesgo hemorrágico',
    'Monitorar signos de sangrado. Avaliar función renal (rivaroxabana é eliminada parcialmente por via renal)',
    'NÍVEL RIVAROXABANA ELEVADO — Amiodarona inibe CYP3A4/P-gp',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  // ── 5. Prolongación del QT (domperidona, metoclopramida, levosulpirida, clorpromazina, risperidona) ──

  ('amiodarona', 'domperidona', InteractionSeverity.contraindicated,
    'Ambos prolongam o intervalo QT por bloqueio de canais hERG/IKr; riesgo de somação',
    'Torsades de Pointes e morte súbita cardíaca',
    'Contraindicado. Sustituir domperidona por outra antiemética (ex: metoclopramida com cautela, ondansetrona)',
    'CONTRAINDICADO — QT aditivo: riesgo de Torsades de Pointes fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'ANSM 2012', 'EMA 2014']),

  ('sotalol', 'domperidona', InteractionSeverity.contraindicated,
    'Ambos prolongam o QT por bloqueio de IKr; sotalol prolonga QT dosis-dependente',
    'Torsades de Pointes e fibrilación ventricular',
    'Contraindicado. Evitar combinación',
    'CONTRAINDICADO — QT aditivo com sotalol',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('haloperidol', 'domperidona', InteractionSeverity.major,
    'Ambos bloqueiam receptores D2 e prolongam QT; efecto aditivo no prolongamento',
    'Riesgo de Torsades de Pointes e arritmias ventriculares graves',
    'Evitar combinación. Se necesario, monitorar ECG e potássio sérico',
    'RISCO DE TORSADES — QT aditivo: haloperidol + domperidona',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('quetiapina', 'domperidona', InteractionSeverity.major,
    'Ambos prolongam QT por bloqueio de canais hERG',
    'Riesgo aumentado de Torsades de Pointes',
    'Evitar combinación. Monitorar ECG se uso necesario',
    'RISCO DE TORSADES — QT aditivo: quetiapina + domperidona',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('amiodarona', 'metoclopramida', InteractionSeverity.major,
    'Metoclopramida prolonga QT moderadamente; amiodarona prolonga significativamente; efecto aditivo',
    'Riesgo aumentado de Torsades de Pointes e arritmias ventriculares',
    'Evitar. Se necesario como antiemético, preferir ondansetrona (com cautela) ou dexametasona',
    'RISCO DE TORSADES — QT aditivo: amiodarona + metoclopramida',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('amiodarona', 'levosulpirida', InteractionSeverity.major,
    'Levosulpirida bloqueia receptores D2 e prolonga QT; amiodarona prolonga significativamente; efecto aditivo',
    'Riesgo de Torsades de Pointes',
    'Evitar combinación. Usar alternativa para DRGE/gastroparesia',
    'RISCO DE TORSADES — QT aditivo: amiodarona + levosulpirida',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('haloperidol', 'metoclopramida', InteractionSeverity.major,
    'Ambos bloqueiam D2 e prolongam QT; riesgo aditivo extrapiramidal e de Torsade',
    'Riesgo de Torsades de Pointes e sintomas extrapiramidais graves',
    'Evitar. Se antiemético necesario, usar ondansetrona. Monitorar ECG e electrolitos',
    'RISCO DE TORSADE + EXTRAPIRAMIDAL — Haloperidol + metoclopramida',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('amiodarona', 'clorpromazina', InteractionSeverity.contraindicated,
    'Ambos prolongam QT significativamente por bloqueio hERG; clorpromazina é antipsicótico típico de alta potência QT',
    'Torsades de Pointes e morte súbita cardíaca',
    'Contraindicado. Sustituir clorpromazina por antipsicótico com menor riesgo QT',
    'CONTRAINDICADO — QT aditivo: riesgo de Torsade fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('sotalol', 'clorpromazina', InteractionSeverity.contraindicated,
    'Ambos prolongam QT por bloqueio de IKr; efecto aditivo grave',
    'Torsades de Pointes e fibrilación ventricular',
    'Contraindicado. Sustituir antipsicótico por opção com menor riesgo QT',
    'CONTRAINDICADO — QT aditivo: sotalol + clorpromazina',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('amiodarona', 'risperidona', InteractionSeverity.major,
    'Risperidona prolonga QT de forma dosis-dependente; amiodarona prolonga significativamente; efecto aditivo',
    'Riesgo de Torsades de Pointes e arritmias ventriculares',
    'Evitar combinación. Monitorar ECG e electrolitos. Corregir hipopotasemia/hipomagnesemia',
    'RISCO DE TORSADES — QT aditivo: amiodarona + risperidona',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('sotalol', 'risperidona', InteractionSeverity.major,
    'Ambos prolongam QT; sotalol de forma dosis-dependente; risperidona em dosis altas',
    'Riesgo de Torsades de Pointes',
    'Evitar. Monitorar ECG e electrolitos se uso inevitável',
    'RISCO DE TORSADES — QT aditivo: sotalol + risperidona',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  // ── 6. Síndrome Serotoninérgica — duloxetina, venlafaxina, petidina ──────

  ('isrs', 'duloxetina', InteractionSeverity.major,
    'Duloxetina é IRSN; combinación com ISRS produz inhibición serotoninérgica aditiva',
    'Síndrome serotoninérgica: agitação, hipertermia, tremor, rigidez, instabilidade autonômica',
    'Evitar combinación. Se necesario trocar, respeitar período de lavado de 14 dias entre medicamentos',
    'SÍNDROME SEROTONINÉRGICA — No combinar ISRS com duloxetina',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('imao', 'duloxetina', InteractionSeverity.contraindicated,
    'IMAO + duloxetina (IRSN): acumulación massivo de serotonina por inhibición da MAO + inhibición de la recaptação',
    'Síndrome serotoninérgica grave, hipercrisis hipertensiva e riesgo de muerte',
    'Contraindicado. Período de lavado de 14 dias después de IMAO antes de iniciar duloxetina; 5 dias después de duloxetina antes de IMAO',
    'CONTRAINDICADO — Crise serotoninérgica e hipercrisis hipertensiva fatal',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cardiovascular},
    ['FDA Label', 'Micromedex 2024']),

  ('imao', 'venlafaxina', InteractionSeverity.contraindicated,
    'IMAO + venlafaxina (IRSN): inhibición de la MAO + inhibición de la recaptação de serotonina e noradrenalina',
    'Síndrome serotoninérgica grave con riesgo de muerte',
    'Contraindicado. Período de lavado de 14 dias después de IMAO; 7 dias después de venlafaxina antes de IMAO',
    'CONTRAINDICADO — Síndrome serotoninérgica fatal',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['FDA Label', 'Micromedex 2024', 'UpToDate 2024']),

  ('tramadol', 'duloxetina', InteractionSeverity.major,
    'Tramadol tem atividade serotoninérgica intrínseca; duloxetina é IRSN — efecto aditivo serotoninérgico',
    'Síndrome serotoninérgica e riesgo convulsivo aumentado',
    'Evitar. Se dor moderada-intensa, usar opioide sem ação serotoninérgica (ex: morfina, oxicodona)',
    'SÍNDROME SEROTONINÉRGICA — Tramadol + duloxetina',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.seizure},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('tramadol', 'venlafaxina', InteractionSeverity.major,
    'Tramadol + venlafaxina: ação serotoninérgica aditiva; tramadol também inibe recaptação de monoaminas',
    'Síndrome serotoninérgica e convulsiones',
    'Evitar combinación. Usar alternativa analgésica sem ação serotoninérgica',
    'SÍNDROME SEROTONINÉRGICA — Tramadol + venlafaxina',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.seizure},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('opioide', 'petidina', InteractionSeverity.major,
    'Petidina (meperidina) tem ação serotoninérgica intrínseca; combinación com outros opioides e serotoninérgicos amplifica o riesgo',
    'Síndrome serotoninérgica e depresión respiratoria aditiva',
    'Evitar petidina en pacientes usando serotoninérgicos. Preferir morfina ou fentanila',
    'SÍNDROME SEROTONINÉRGICA + DEPRESIÓN RESPIRATORIA — Evitar petidina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.respiratoryDepression},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('isrs', 'petidina', InteractionSeverity.contraindicated,
    'Petidina inibe recaptação de serotonina; ISRS adiciona inhibición serotoninérgica; riesgo muito elevado',
    'Síndrome serotoninérgica grave, convulsiones e óbito',
    'Contraindicado. Usar morfina ou fentanila como alternativa en pacientes com ISRS',
    'CONTRAINDICADO — Síndrome serotoninérgica grave: ISRS + petidina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.seizure},
    ['Micromedex 2024', 'UpToDate 2024', 'FDA Label']),

  ('imao', 'petidina', InteractionSeverity.contraindicated,
    'Petidina + IMAO: síndrome serotoninérgica clássica e hipercrisis hipertensiva',
    'Síndrome serotoninérgica grave con riesgo de muerte',
    'Contraindicado absolutamente. Usar morfina como alternativa com cautela',
    'CONTRAINDICADO — Síndrome serotoninérgica fatal clássica',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cardiovascular},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'FDA Label']),

  // ── 7. Depresión respiratoria ─────────────────────────────────────────────

  ('benzodiazepínico', 'opioide', InteractionSeverity.major,
    'Depressão aditiva do SNC e do centro respiratório; benzodiazepínico potencializa receptores GABA enquanto opioide age em receptores μ',
    'Depresión respiratoria grave, apnea e riesgo de óbito',
    'Evitar combinación cuando sea posible. Se necesario, usar dosis mínimas, monitorar oximetria e ter naloxona disponible',
    'DEPRESIÓN RESPIRATORIA FATAL — FDA black box warning',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Black Box Warning 2016', 'Micromedex 2024', 'UpToDate 2024']),

  ('benzodiazepínico', 'morfina', InteractionSeverity.major,
    'Benzodiazepínico potencializa efecto depressor respiratório da morfina via GABA + receptores μ',
    'Depresión respiratoria grave e apnea',
    'Usar dosis mínimas. Monitorar oximetria. Naloxona disponible. Evitar en pacientes sem monitoramento',
    'DEPRESIÓN RESPIRATORIA GRAVE — Benzodiazepínico + morfina',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Black Box Warning', 'Micromedex 2024']),

  ('benzodiazepínico', 'fentanila', InteractionSeverity.major,
    'Combinación sinérgica na depresión del SNC; fentanila tem janela terapéutica estreita',
    'Depresión respiratoria grave, apnea e parada cardiorrespiratória',
    'Monitoração rigurosa em UTI/cirurgia. Naloxona disponible. Titular dosis cuidadosamente',
    'DEPRESIÓN RESPIRATORIA GRAVE — Benzodiazepínico + fentanila',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Black Box Warning', 'Micromedex 2024']),

  ('benzodiazepínico', 'tramadol', InteractionSeverity.major,
    'Depressão aditiva do SNC; tramadol também reduz limiar convulsivo',
    'Depresión respiratoria e paradoxalmente convulsiones em alguns pacientes',
    'Evitar. Se necesario, usar dosis mínimas com monitoramento',
    'DEPRESIÓN RESPIRATORIA + RISCO DE CONVULSÃO — Benzodiazepínico + tramadol',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression, RiskType.seizure},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('gabapentina', 'opioide', InteractionSeverity.major,
    'Pregabalina/gabapentina potencializam depresión del SNC e respiratória dos opioides por mecanismo sinérgico no canal de cálcio α2δ',
    'Depresión respiratoria grave, especialmente com dosis altas ou en ancianos',
    'FDA emitiu aviso. Usar dosis mínimas, monitorar oximetria. Evitar em DPOC e apnea do sono',
    'DEPRESIÓN RESPIRATORIA — FDA warning: gabapentinoides + opioides',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Drug Safety Communication 2019', 'Micromedex 2024', 'UpToDate 2024']),

  ('gabapentina', 'morfina', InteractionSeverity.major,
    'Gabapentina aumenta biodisponibilidad da morfina e potencializa depresión respiratoria',
    'Depresión respiratoria grave com riesgo de óbito',
    'Usar com cautela. Dosis mínimas. Monitorar oximetria continuamente',
    'DEPRESIÓN RESPIRATORIA GRAVE — Gabapentina + morfina',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Drug Safety Communication 2019', 'Micromedex 2024']),

  ('gabapentina', 'benzodiazepínico', InteractionSeverity.major,
    'Tripla depresión del SNC: gabapentinóide + benzodiazepínico, frecuentemente com opioide associado',
    'Depresión respiratoria e sedación excesiva',
    'Evitar tripla combinación. Se necesario, monitorar oximetria e reducir dosiss',
    'DEPRESIÓN RESPIRATORIA — Gabapentina + benzodiazepínico (alto riesgo)',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA 2019', 'Micromedex 2024']),

  ('benzodiazepínico', 'zolpidem', InteractionSeverity.major,
    'Depressão aditiva do SNC; ambos atuam em receptores GABA-A',
    'Sedación excesiva, depresión respiratoria, quedas e amnésia',
    'Evitar combinación. Se necesario em contexto hospitalar, monitorar continuamente',
    'DEPRESIÓN DEL SNC GRAVE — Benzodiazepínico + zolpidem',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('opioide', 'zolpidem', InteractionSeverity.major,
    'Zolpidem + opioide: depressão sinérgica do SNC e respiratória',
    'Depresión respiratoria, sedación excesiva e óbito',
    'Evitar combinación. Si inevitable, usar dosis mínimas com monitoramento',
    'DEPRESIÓN RESPIRATORIA — Zolpidem + opioide',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    ['FDA Black Box Warning', 'Micromedex 2024']),

  // ── 8. Hiperpotasemia — IECAs/ARAs × Poupadores de K ───────────────────────

  ('enalapril', 'espironolactona', InteractionSeverity.major,
    'IECA reduz angiotensina II → reduz aldosterona → retém K; espironolactona antagoniza aldosterona diretamente; efecto aditivo hipercalêmico',
    'Hiperpotasemia grave (K+ >6,5 mEq/L), arritmias e paro cardíaco',
    'Monitorar potássio sérico e creatinina. Iniciar espironolactona em dosis baja (25 mg/dia). Evitar suplementação de K+',
    'HIPERPOTASEMIA GRAVE — IECA + espironolactona; monitorar K+ e creatinina',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    ['RALES Trial', 'Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('losartana', 'espironolactona', InteractionSeverity.major,
    'ARA II reduz aldosterona → retém K; espironolactona antagoniza aldosterona; efecto hipercalêmico aditivo',
    'Hiperpotasemia grave com riesgo de arritmia e paro cardíaco',
    'Monitorar K+ e función renal regularmente. Dosis inicial baixa de espironolactona. Evitar K+ suplementar',
    'HIPERPOTASEMIA GRAVE — ARA II + espironolactona; monitorar K+',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('sacubitrila', 'espironolactona', InteractionSeverity.major,
    'Sacubitril/valsartana bloqueia receptores AT1 (como ARA II) → reduz aldosterona; espironolactona adiciona antagonismo de aldosterona',
    'Hiperpotasemia grave, especialmente em insuficiencia renal',
    'Monitorar K+ a cada 1–4 semanas inicialmente. Dosis baja de espironolactona (25 mg). Evitar em K+ >5,0 mEq/L',
    'HIPERPOTASEMIA — Sacubitril/valsartana + espironolactona; monitorar K+',
    EvidenceLevel.probable,
    {RiskType.hyperkalemia},
    ['PARADIGM-HF', 'Micromedex 2024', 'ESC HF Guidelines 2021']),

  ('enalapril', 'eplerenona', InteractionSeverity.major,
    'IECA + eplerenona (poupador de K seletivo): efecto hipercalêmico aditivo por reducción de aldosterona e bloqueio do receptor',
    'Hiperpotasemia grave com riesgo de arritmias',
    'Monitorar K+ e función renal. Eplerenona contraindicada se clearance <30 mL/min',
    'HIPERPOTASEMIA — IECA + eplerenona; monitorar K+ e TFG',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    ['EPHESUS Trial', 'Micromedex 2024']),

  ('losartana', 'eplerenona', InteractionSeverity.major,
    'ARA II + eplerenona: duplo bloqueio do eixo renina-angiotensina-aldosterona → hiperpotasemia',
    'Hiperpotasemia grave com riesgo de paro cardíaco',
    'Monitorar K+ frecuentemente. Contraindicado se K+ >5,0 mEq/L ou TFG <30 mL/min',
    'HIPERPOTASEMIA — ARA II + eplerenona; monitorar K+',
    EvidenceLevel.established,
    {RiskType.hyperkalemia},
    ['Micromedex 2024', 'UpToDate 2024']),

  // ── 9. Lítio × Vários ─────────────────────────────────────────────────────

  ('carbonato de litio', 'enalapril', InteractionSeverity.major,
    'IECAs reduzem filtração glomerular e excreción de lítio pelo rim → acumulación de lítio',
    'Toxicidad por lítio: tremor, ataxia, confusão, convulsiones, arritmias',
    'Monitorar lítio semanalmente nas primeiras 4 semanas. Reducir dosis de lítio em 25–50%. Hidratar adecuadamente',
    'TOXICIDADE DE LÍTIO — IECA reduz excreción renal de lítio',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'Goodman & Gilman']),

  ('carbonato de litio', 'losartana', InteractionSeverity.major,
    'ARA II reduz filtração glomerular → reduz excreción renal de lítio → acumulación',
    'Toxicidad por lítio',
    'Monitorar lítio regularmente. Ajustar dosis. Hidratação adecuada',
    'TOXICIDADE DE LÍTIO — ARA II reduz excreción renal de lítio',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'hidroclorotiazida', InteractionSeverity.major,
    'Tiazídicos reduzem a excreción renal de lítio ao aumentar reabsorción tubular (lítio e Na+ competem no túbulo)',
    'Toxicidade grave por lítio',
    'Reducir dosis de lítio em 30–50%. Monitorar lítio semanalmente. Preferir furosemida se diurético necesario (menor efecto)',
    'TOXICIDADE DE LÍTIO — Tiazídico retém lítio; reducir dosis',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'aine', InteractionSeverity.major,
    'AINEs inibem prostaglandinas renais → reduzem TFG → diminuem excreción de lítio em 25–60%',
    'Toxicidad por lítio com sintomas neurológicos graves',
    'Evitar AINEs en pacientes em uso de lítio. Usar paracetamol como analgésico. Se AINE necesario, monitorar lítio',
    'TOXICIDADE DE LÍTIO — AINEs reduzem excreción renal em 25–60%',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'metronidazol', InteractionSeverity.major,
    'Metronidazol reduz excreción renal de lítio por mecanismo não totalmente elucidado',
    'Toxicidad por lítio',
    'Monitorar lítio durante e después de o tratamiento com metronidazol. Ajustar dosis se necesario',
    'TOXICIDADE DE LÍTIO — Metronidazol reduz excreción renal',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'haloperidol', InteractionSeverity.major,
    'Combinación histórica associada a encefalopatía irreversible; haloperidol pode mascarar sintomas precoces de toxicidad por lítio',
    'Encefalopatía tóxica, dano neurológico permanente',
    'Usar com extrema cautela. Manter lítio na faixa baixa do terapéutico. Monitorar signos neurológicos',
    'ENCEFALOPATIA TÓXICA — Haloperidol + lítio: combinación de alto riesgo',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.cns},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('carbonato de litio', 'carbonato de calcio', InteractionSeverity.moderate,
    'Carbonato de cálcio pode aumentar reabsorción renal de lítio em algumas situações, além de reduzir absorción GI',
    'Variação nos niveles plasmáticos de lítio',
    'Administrar lítio separado de antiácidos. Monitorar lítio sérico',
    'NÍVEL DE LÍTIO VARIÁVEL — Separar administração de cálcio/antiácidos',
    EvidenceLevel.possible,
    {RiskType.plasmaLevel},
    ['Micromedex 2024']),

  ('carbonato de litio', 'furosemida', InteractionSeverity.moderate,
    'Furosemida aumenta excreción de sódio → pode elevar ou reduzir excreción de lítio dependendo da hidratação',
    'Toxicidad de lítio se depleção de sódio; hipolítio se boa hidratação',
    'Monitorar lítio sérico. Manter hidratação adecuada. Ajustar dosis según sea necesario',
    'LÍTIO VARIÁVEL — Furosemida altera excreción dependendo da hidratação',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  // ── 10. Fenitoína × Anticoagulantes ──────────────────────────────────────

  ('fenitoína', 'warfarina', InteractionSeverity.major,
    'Inducción del CYP2C9 (reduz warfarina) inicialmente; depois competição pelo CYP2C9 pode elevar warfarina — efecto bifásico e impredecible',
    'Instabilidade do INR: inicialmente reducción (riesgo trombótico) e depois posible elevación (riesgo hemorrágico)',
    'Monitorar INR frecuentemente ao iniciar/suspender fenitoína. Ajustar dosis de warfarina conforme resposta',
    'INR IMPREVISÍVEL — Fenitoína tem efecto bifásico sobre warfarina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('fenitoína', 'apixabana', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 e P-gp, reduzindo os niveles de apixabana em ~50%',
    'Falha terapéutica da apixabana → riesgo trombótico e tromboembólico',
    'Evitar combinación. Se necesario, considerar anticoagulante alternativo não metabolizado por CYP3A4/P-gp',
    'APIXABANA REDUZIDA 50% — Fenitoína induz CYP3A4/P-gp',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'FDA Label Eliquis']),

  ('fenitoína', 'rivaroxabana', InteractionSeverity.major,
    'Fenitoína induz CYP3A4 e P-gp, reduzindo os niveles de rivaroxabana significativamente',
    'Falha terapéutica da rivaroxabana → riesgo de trombosis',
    'Evitar combinación. Usar anticoagulante não afetado por inductores enzimáticos',
    'RIVAROXABANA REDUZIDA — Fenitoína induz CYP3A4/P-gp',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024', 'FDA Label Xarelto']),

  // ── 11. Betabloqueadores × BCC não-DHP / Digoxina ─────────────────────────

  ('metoprolol', 'verapamil', InteractionSeverity.major,
    'Ambos deprimem o nó sinusal e AV por mecanismos diferentes (β-bloqueio + bloqueio de canal de cálcio); efecto cronotrópico e dromotrópico negativo aditivo',
    'Bradicardia grave, bloqueo AV, hipotensión e insuficiencia cardíaca aguda',
    'Contraindicado en pacientes com disfunção ventricular. Monitorar ECG e FC. Evitar especialmente verapamil IV en pacientes com betabloqueador oral',
    'BRADICARDIA/BLOQUEO AV — Betabloqueador + verapamil: combinación perigosa',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('metoprolol', 'diltiazem', InteractionSeverity.major,
    'Ambos têm efecto cronotrópico e dromotrópico negativo; diltiazem também inibe CYP2D6, elevando niveles de metoprolol',
    'Bradicardia grave, bloqueo AV de alto grau, hipotensión',
    'Usar com cautela. Monitorar ECG e FC. Reducir dosis de metoprolol se necesario. Evitar em bradiarritmias',
    'BRADICARDIA/BLOQUEO AV — Metoprolol + diltiazem; nivel de metoprolol elevado',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('metoprolol', 'digoxina', InteractionSeverity.major,
    'Betabloqueador + digoxina: ambos deprimem o nó AV; efecto dromotrópico negativo aditivo',
    'Bradicardia grave e bloqueo AV',
    'Monitorar ECG e FC. Ajustar dosiss. Útil em FA para controle de ritmo, mas titular cuidadosamente',
    'BRADICARDIA/BLOQUEO AV — Betabloqueador + digoxina',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024', 'ESC 2020']),

  ('propranolol', 'verapamil', InteractionSeverity.major,
    'Ambos deprimem nó sinusal e AV; propranolol bloqueia receptores β1/β2; verapamil bloqueia canal de cálcio no nó AV',
    'Bradicardia grave, bloqueo AV completo e colapso hemodinâmico',
    'Contraindicado en pacientes com disfunção ventricular. Monitorar ECG rigurosamente',
    'BRADICARDIA/COLAPSO — Propranolol + verapamil: contraindicado em disfunção ventricular',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('propranolol', 'diltiazem', InteractionSeverity.major,
    'Efecto dromotrópico negativo aditivo; diltiazem pode elevar nivel de propranolol',
    'Bradicardia e bloqueo AV',
    'Monitorar ECG e FC. Usar dosis bajas com cautela',
    'BRADICARDIA — Propranolol + diltiazem: efecto dromotrópico aditivo',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Micromedex 2024']),

  // ── 12. Empagliflozina × Antidiabéticos ──────────────────────────────────

  ('dapagliflozina', 'insulina', InteractionSeverity.moderate,
    'SGLT2i reduz a glucemia; insulina também reduz glucemia — riesgo de hipoglucemia aditiva, especialmente se dosis de insulina não ajustada',
    'Hipoglucemia, cetoacidosis euglicêmica (rara mas grave)',
    'Reducir dosis de insulina em 20–30% al iniciar SGLT2i. Monitorar glucemia. Alertar sobre cetoacidosis euglicêmica',
    'HIPOGLICEMIA + CETOACIDOSIS EUGLICÊMICA — SGLT2i + insulina; ajustar dosis',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    ['EMPA-REG OUTCOME', 'ADA 2024', 'Micromedex 2024']),

  ('dapagliflozina', 'sulfonilureia', InteractionSeverity.moderate,
    'SGLT2i + sulfonilureia: ambos reduzem glucemia por mecanismos diferentes; riesgo aditivo de hipoglucemia',
    'Hipoglucemia, especialmente se jejum ou exercício',
    'Reducir dosis de sulfonilureia al iniciar SGLT2i. Monitorar glucemia regularmente',
    'HIPOGLICEMIA — SGLT2i + sulfonilureia; reducir dosis de sulfonilureia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    ['ADA 2024', 'Micromedex 2024']),

  ('dapagliflozina', 'metformina', InteractionSeverity.moderate,
    'Ambos reduzem glucemia; SGLT2i causa diurese osmótica podendo precipitar acidosis láctica em situações de riesgo',
    'Acidosis láctica em situações específicas (desidratação, cirurgia, contraste)',
    'Suspender SGLT2i antes de contraste iodado ou cirurgia de grande porte. Monitorar hidratação',
    'ACIDOSIS LÁCTICA — SGLT2i + metformina: suspender antes de contraste/cirurgia',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    ['ADA 2024', 'Micromedex 2024']),

  // ── 13. Dexametasona × Antidiabéticos ────────────────────────────────────

  ('dexametasona', 'insulina', InteractionSeverity.moderate,
    'Corticosteroides induzem resistência insulínica e gliconeogênese hepática → hiperglucemia',
    'Hiperglucemia grave, descompensação diabética',
    'Aumentar dosis de insulina durante corticoterapia. Monitorar glucemia frecuentemente (a cada 4–6h se hospitalizado)',
    'HIPERGLICEMIA — Corticoide induz resistência insulínica; ajustar insulina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['ADA 2024', 'Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('dexametasona', 'metformina', InteractionSeverity.moderate,
    'Corticosteroides reduzem eficácia da metformina por inducción de hiperglucemia persistente',
    'Perda de controle glicêmico durante corticoterapia',
    'Monitorar glucemia. Adicionar insulina se necesario durante o tratamiento com corticoide',
    'CONTROLE GLICÊMICO PERDIDO — Corticoide reduz eficácia de antidiabéticos orais',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['ADA 2024', 'Micromedex 2024']),

  ('dexametasona', 'sulfonilureia', InteractionSeverity.moderate,
    'Corticosteroides antagonizam o efecto hipoglucemiante das sulfonilureias por resistência insulínica',
    'Hiperglucemia e perda do controle glicêmico',
    'Aumentar frecuencia de monitoramento glicêmico. Pode ser necesario adicionar insulina',
    'HIPERGLICEMIA — Corticoide antagoniza sulfonilureia',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['ADA 2024', 'Micromedex 2024']),

  // ── 14. Quelação — levotiroxina, ciprofloxacino, doxiciclina, eltrombopague × cálcio/ferro ──

  ('levotiroxina', 'sulfato ferroso', InteractionSeverity.major,
    'Ferro forma complexo insoluble com levotiroxina no trato GI, reduzindo sua absorción em 30–50%',
    'Hipotiroidismo por fracaso terapéutico da levotiroxina',
    'Administrar levotiroxina 4 horas antes ou después de o ferro. Monitorar TSH después de mudança',
    'QUELAÇÃO — Separar levotiroxina e ferro por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('levotiroxina', 'carbonato de calcio', InteractionSeverity.major,
    'Cálcio reduce la absorción de levotiroxina em 20–40% por formação de complexo insoluble no GI',
    'Hipotiroidismo por reducción de la absorción de levotiroxina',
    'Administrar levotiroxina 4 horas antes ou después de o cálcio. Monitorar TSH',
    'QUELAÇÃO — Separar levotiroxina e cálcio por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('ciprofloxacino', 'sulfato ferroso', InteractionSeverity.major,
    'Ferro forma quelato com ciprofloxacino no GI, reduzindo absorción em 50–90%',
    'Falha terapéutica do ciprofloxacino → riesgo de infecção não tratada',
    'Administrar ciprofloxacino 2 horas antes ou 6 horas después de ferro/antiácidos',
    'QUELAÇÃO — Separar ciprofloxacino e ferro por ≥2 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('ciprofloxacino', 'carbonato de calcio', InteractionSeverity.major,
    'Cálcio (antiácido/suplemento) quelata ciprofloxacino no GI, reduzindo absorción em 30–50%',
    'Falha terapéutica de ciprofloxacino',
    'Administrar ciprofloxacino 2 horas antes ou 6 horas después de cálcio/antiácidos',
    'QUELAÇÃO — Separar ciprofloxacino e cálcio por ≥2 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('eltrombopague', 'sulfato ferroso', InteractionSeverity.major,
    'Eltrombopague tem alta afinidade por metais polivalentes; ferro reduz sua absorción em até 70%',
    'Falha terapéutica do eltrombopague → trombocitopenia persistente',
    'Administrar eltrombopague 4 horas antes ou después de ferro, cálcio, alumínio, magnésio',
    'QUELAÇÃO — Separar eltrombopague e ferro por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['FDA Label Promacta', 'Micromedex 2024']),

  ('eltrombopague', 'carbonato de calcio', InteractionSeverity.major,
    'Cálcio quelata eltrombopague no GI, reduzindo absorción significativamente',
    'Falha terapéutica → trombocitopenia',
    'Separar eltrombopague e cálcio por ≥4 horas',
    'QUELAÇÃO — Separar eltrombopague e cálcio por ≥4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['FDA Label Promacta', 'Micromedex 2024']),

  // ── 15. Salbutamol / Fenoterol × Teofilina / Furosemida ──────────────────

  ('salbutamol', 'teofilina', InteractionSeverity.major,
    'Ambos são broncodilatadores; teofilina tem janela terapéutica estreita; salbutamol pode aumentar toxicidad de teofilina via reducción de K+',
    'Taquicardia, arritmias, hipopotasemia e toxicidad por teofilina',
    'Monitorar FC, K+ sérico e nivel de teofilina. Evitar dosis altas de salbutamol',
    'TAQUICARDIA E HIPOCALEMIA — Salbutamol + teofilina',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.hypokalemia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024']),

  ('salbutamol', 'furosemida', InteractionSeverity.moderate,
    'Ambos causam hipopotasemia; salbutamol por redistribuição intracelular de K+ (β2); furosemida por perda urinária',
    'Hipopotasemia grave, arritmias cardíacas',
    'Monitorar K+ sérico. Reponer potasio se necesario. Evitar altas dosis de salbutamol nebulizado',
    'HIPOCALEMIA ADITIVA — Salbutamol + furosemida; monitorar K+',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    ['Micromedex 2024', 'UpToDate 2024']),

  // ── 16. Ritonavir/Paxlovid × AODs / Dronedarona ──────────────────────────

  ('ritonavir', 'apixabana', InteractionSeverity.major,
    'Ritonavir inibe potentemente CYP3A4 e P-gp, elevando os niveles de apixabana em 2–3 vezes',
    'Riesgo hemorrágico grave por superdosis de apixabana',
    'Evitar combinación. Se anticoagulação necesaria durante Paxlovid, sustituir por heparina de baixo peso molecular',
    'NÍVEL APIXABANA 2–3× ELEVADO — Ritonavir inibe CYP3A4/P-gp; usar HBPM',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['FDA Label Paxlovid 2021', 'Micromedex 2024', 'UpToDate 2024']),

  ('ritonavir', 'rivaroxabana', InteractionSeverity.contraindicated,
    'Ritonavir inibe CYP3A4 e P-gp elevando os niveles de rivaroxabana em 2,5–3,5 vezes',
    'Riesgo hemorrágico grave e riesgo de muerte',
    'Contraindicado. Sustituir por HBPM durante curso de Paxlovid (5 dias)',
    'CONTRAINDICADO — Rivaroxabana 2,5–3,5× elevada por ritonavir',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['FDA Label Paxlovid 2021', 'Micromedex 2024']),

  ('ritonavir', 'dabigatrana', InteractionSeverity.major,
    'Ritonavir inibe P-gp, principal via de eliminación da dabigatrana, elevando seus niveles em ~50%',
    'Riesgo hemorrágico aumentado',
    'Evitar. Sustituir dabigatrana por HBPM durante Paxlovid',
    'NÍVEL DABIGATRANA ELEVADO — Ritonavir inibe P-gp',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    ['FDA Label Paxlovid 2021', 'Micromedex 2024']),

  ('ritonavir', 'dronedarona', InteractionSeverity.contraindicated,
    'Ritonavir inibe CYP3A4; dronedarona é substrato exclusivo de CYP3A4 — elevación de nivel >10 vezes',
    'Prolongación del QT grave, Torsades de Pointes e riesgo de muerte',
    'Contraindicado. Sustituir dronedarona por amiodarona ou outro antiarrítmico durante Paxlovid',
    'CONTRAINDICADO — Dronedarona >10× elevada por ritonavir: riesgo de muerte',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia, RiskType.plasmaLevel},
    ['FDA Label Paxlovid', 'Micromedex 2024', 'ESC 2020']),

  // ── 17. Interacciones especiais ──────────────────────────────────────────────

  ('anticonceptivo', 'rifampicina', InteractionSeverity.major,
    'Rifampicina induz CYP3A4 e glicuronoconjugação, reduzindo drásticamente os niveles de etinilestradiol e progestágenos em 40–70%',
    'Fracaso contraceptivo com embarazo no planificado',
    'Usar método contraceptivo adicional (preservativo) durante e por 4 semanas después de rifampicina. Considerar LARC',
    'FRACASO CONTRACEPTIVO — Rifampicina reduz nivel do anticonceptivo 40–70%',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'WHO MEC 2015']),

  ('anticonceptivo', 'acido tranexamico', InteractionSeverity.major,
    'Ácido tranexâmico inibe fibrinólise; anticoncepcionais orais aumentam estado pró-trombótico — efecto tromboembólico aditivo',
    'Riesgo aumentado de tromboembolismo venoso e arterial',
    'Evitar uso combinado, especialmente en pacientes com outros fatores de riesgo tromboembólico',
    'RISCO TROMBOEMBÓLICO — Anticonceptivo + ácido tranexâmico',
    EvidenceLevel.probable,
    {RiskType.thrombosis},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('azitromicina', 'amiodarona', InteractionSeverity.contraindicated,
    'Ambos prolongam o QT por bloqueio hERG; azitromicina prolonga QT moderadamente, amiodarona prolonga significativamente — efecto aditivo grave',
    'Torsades de Pointes e morte súbita cardíaca',
    'Contraindicado. Sustituir azitromicina por amoxicilina ou doxiciclina. Monitorar ECG se uso inevitável',
    'CONTRAINDICADO — QT aditivo: azitromicina + amiodarona = riesgo de Torsade fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['FDA 2013', 'CredibleMeds 2024', 'Micromedex 2024']),

  ('metformina', 'contraste iodado', InteractionSeverity.major,
    'Contraste iodado pode causar nefropatia aguda → reduz excreción renal de metformina → acumulación → acidosis láctica',
    'Acidosis láctica grave com riesgo de muerte',
    'Suspender metformina 48h antes do contraste. Reiniciar apenas después de confirmar función renal estável (48h después de)',
    'ACIDOSIS LÁCTICA — Suspender metformina 48h antes do contraste iodado',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.increasedToxicity},
    ['ACR Manual on Contrast Media 2023', 'Micromedex 2024', 'UpToDate 2024']),

  ('glibenclamida', 'sulfametoxazol', InteractionSeverity.major,
    'Sulfametoxazol-trimetoprima inibe CYP2C9 (metabolismo de la glibenclamida) + possui ação hipoglucemiante própria (estrutura semelhante a sulfonilureias)',
    'Hipoglucemia grave, prolongada e potencialmente fatal',
    'Evitar combinación. Se antibiótico necesario, sustituir por alternativa sem ação hipoglucemiante. Monitorar glucemia rigurosamente',
    'HIPOGLUCEMIA GRAVE — SMX-TMP + glibenclamida: dupla ação hipoglucemiante',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    ['Goodman & Gilman 14ª ed.', 'Micromedex 2024', 'UpToDate 2024']),

  ('clopidogrel', 'omeprazol', InteractionSeverity.major,
    'Omeprazol inibe CYP2C19, enzima necesaria para conversão do clopidogrel em seu metabólito ativo, reduzindo atividade antiagregante em 45%',
    'Reducción de la eficacia do clopidogrel → riesgo de trombosis de stent e eventos cardiovasculares',
    'Preferir pantoprazol ou rabeprazol (menor inhibición de CYP2C19). Evitar omeprazol/esomeprazol en pacientes em uso de clopidogrel',
    'CLOPIDOGREL 45% MENOS EFICAZ — Omeprazol inibe CYP2C19; usar pantoprazol',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['FDA 2010', 'AHA 2010', 'Micromedex 2024', 'UpToDate 2024']),

  ('metotrexato', 'omeprazol', InteractionSeverity.major,
    'Omeprazol (IBP) reduz excreción renal de metotrexato ao inibir transportadores tubulares (OAT1/OAT3), elevando seus niveles plasmáticos',
    'Toxicidad por metotrexato: mielosupresión, mucosites, hepatotoxicidad',
    'Evitar IBPs en pacientes com metotrexato em dosis altas. Se necesario, suspender IBP 48h antes e después de dosis de metotrexato',
    'TOXICIDADE DE METOTREXATO — IBP reduz excreción renal de MTX',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.hepatotoxicity, RiskType.plasmaLevel},
    ['Micromedex 2024', 'UpToDate 2024']),

  ('heparina', 'alteplase', InteractionSeverity.major,
    'Ambos aumentam riesgo hemorrágico; alteplase dissolve coágulos e heparina inibe coagulação — efecto antitrombótico máximo com alto riesgo de sangrado grave',
    'Hemorragia grave, incluindo sangrado intracraneal',
    'Suspender heparina IV durante infusão de alteplase em AVC isquêmico. Retomar apenas después de 24h e TC sem hemorragia',
    'RIESGO HEMORRÁGICO GRAVE — Suspender heparina durante trombolítico',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    ['AHA/ASA Stroke Guidelines 2023', 'Micromedex 2024']),

  ('hidroxicloroquina', 'azitromicina', InteractionSeverity.major,
    'Ambos prolongam QT por bloqueio de canais hERG; combinación foi amplamente estudada durante COVID-19 com alto riesgo confirmado',
    'Prolongación del QT grave, Torsades de Pointes e morte súbita',
    'Evitar combinación. Se anti-infeccioso necesario em paciente com hidroxicloroquina, preferir amoxicilina ou doxiciclina',
    'RISCO DE TORSADES — Hidroxicloroquina + azitromicina: combinación de alto riesgo',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['FDA Safety Alert 2020', 'CredibleMeds 2024', 'Micromedex 2024']),

  ('hidroxicloroquina', 'amiodarona', InteractionSeverity.contraindicated,
    'Ambos prolongam QT de forma significativa; hidroxicloroquina é QT prolongador estabelecido; amiodarona idem — riesgo máximo de somação',
    'Torsades de Pointes e morte súbita',
    'Contraindicado. Sustituir hidroxicloroquina por outro antirreumático ou amiodarona por outro antiarrítmico',
    'CONTRAINDICADO — QT aditivo máximo: hidroxicloroquina + amiodarona',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    ['CredibleMeds 2024', 'Micromedex 2024']),

  // ── LOTE 7 — Interacciones críticas: novos fármacos Lote 6 ──────────────────
  // Dextrometorfano, Pseudoefedrina, Montelukast, Cetirizina

  // ── 7.1 DEXTROMETORFANO ──────────────────────────────────────────────────

  ('dextrometorfano', 'isrs', InteractionSeverity.contraindicated,
    'Dextrometorfano é agonista fraco de receptores serotoninérgicos e inibe recaptação de serotonina; ISRSs potencializam massivamente a atividade serotoninérgica central — riesgo máximo de síndrome serotoninérgica',
    'Síndrome serotoninérgica: agitação, hipertermia, tremores, mioclonias, diarreia, taquicardia, diaforese, rigidez muscular — pode evoluir para rabdomiólisis, CID e óbito',
    'CONTRAINDICADO. Evitar qualquer antitussivo com dextrometorfano en pacientes em uso de ISRSs (fluoxetina, sertralina, paroxetina, escitalopram, fluvoxamina). Sustituir por antitussivo não serotoninérgico (ex: levodropropizina, butamirato)',
    'CONTRAINDICADO — Síndrome serotoninérgica: dextrometorfano + ISRS',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['FDA Drug Safety 2010', 'CredibleMeds 2024', 'Micromedex 2024', 'Serotonin Syndrome: Recognition and Treatment — AAFP 2017']),

  ('dextrometorfano', 'imao', InteractionSeverity.contraindicated,
    'IMAOs inibem degradação de serotonina e monoaminas; dextrometorfano inibe recaptação de serotonina e é agonista sigma-1 — combinación resulta em acumulación massivo de serotonina no SNC',
    'Síndrome serotoninérgica grave/fulminante: hipertermia >41°C, hipertensão, convulsiones, coma — riesgo de muerte',
    'CONTRAINDICADO de forma absoluta. Aguardar período de lavado completo do IMAO (≥14 dias para irreversíveis fenelzina/tranilcipromina; ≥24h para moclobemida) antes de qualquer antitussivo com dextrometorfano',
    'CONTRAINDICADO ABSOLUTO — Síndrome serotoninérgica fatal: dextrometorfano + IMAO',
    EvidenceLevel.established,
    {RiskType.serotonin},
    ['FDA Drug Safety 2010', 'CredibleMeds 2024', 'Sternbach 1991 — Serotonin Syndrome', 'Boyer & Shannon NEJM 2005']),

  ('dextrometorfano', 'tramadol', InteractionSeverity.contraindicated,
    'Tramadol inibe recaptação de serotonina e noradrenalina, é agonista µ fraco e metabolizado pelo CYP2D6 (mesmo que dextrometorfano) — duplo mecanismo serotoninérgico + competição CYP2D6 eleva niveles de ambos',
    'Síndrome serotoninérgica; aumento de niveles plasmáticos de tramadol e dextrometorfano por inhibición competitiva do CYP2D6',
    'Contraindicado. Sustituir antitussivo por levodropropizina ou butamirato en pacientes usando tramadol',
    'CONTRAINDICADO — Síndrome serotoninérgica + competição CYP2D6: dextrometorfano + tramadol',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.plasmaLevel},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('dextrometorfano', 'duloxetina', InteractionSeverity.contraindicated,
    'Duloxetina é ISRN e inhibidor potente do CYP2D6 — eleva marcadamente os niveles de dextrometorfano (substrato CYP2D6) e potencializa atividade serotoninérgica',
    'Síndrome serotoninérgica; aumento de 3–8× nos niveles plasmáticos de dextrometorfano por inhibición do CYP2D6',
    'Contraindicado. Usar antitussivo não serotoninérgico e não metabolizado pelo CYP2D6 (levodropropizina, butamirato)',
    'CONTRAINDICADO — Síndrome serotoninérgica + inhibición CYP2D6: dextrometorfano + duloxetina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    ['FDA Drug Safety 2010', 'Micromedex 2024', 'CredibleMeds 2024']),

  ('dextrometorfano', 'amiodarona', InteractionSeverity.major,
    'Amiodarona é inhibidor potente do CYP2D6 — aumenta significativamente a biodisponibilidad oral do dextrometorfano (substrato CYP2D6); pode elevar concentraciones 4–10×',
    'Toxicidade pelo dextrometorfano: vertigem, sedación excesiva, ataxia, nistagmo, disforia, efectos alucinatórios em dosiss terapéuticas',
    'Evitar combinación. Se necesario, usar dosis mínima de dextrometorfano e monitorar signos de toxicidad. Preferir antitussivos não dependentes do CYP2D6',
    'CUIDADO — Toxicidad por dextrometorfano: inhibición CYP2D6 pela amiodarona',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'CYP2D6 Inhibitor Interactions — FDA']),

  ('dextrometorfano', 'fluoxetina', InteractionSeverity.contraindicated,
    'Fluoxetina é inhibidor potente do CYP2D6 e ISRS — bloqueia o metabolismo del dextrometorfano (substrato CYP2D6) e soma atividade serotoninérgica — duplo mecanismo de toxicidad',
    'Síndrome serotoninérgica; elevación drástica dos niveles de dextrometorfano (↑5–10×) com riesgo de toxicidad SNC',
    'Contraindicado. Período de lavado de fluoxetina exige ≥5 semanas (vida media longa). Sustituir antitussivo por levodropropizina ou butamirato',
    'CONTRAINDICADO — Síndrome serotoninérgica + inhibición CYP2D6 severa: dextrometorfano + fluoxetina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    ['FDA Drug Safety 2010', 'CredibleMeds 2024', 'Micromedex 2024']),

  ('dextrometorfano', 'paroxetina', InteractionSeverity.contraindicated,
    'Paroxetina é o inhibidor mais potente do CYP2D6 entre os ISRSs — eleva os niveles de dextrometorfano em até 9× e soma atividade serotoninérgica',
    'Síndrome serotoninérgica grave; toxicidad pelo dextrometorfano com efectos dissociativos e alucinatórios',
    'Contraindicado. Sustituir antitussivo por levodropropizina ou butamirato',
    'CONTRAINDICADO — CYP2D6 + serotonina: dextrometorfano + paroxetina',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.plasmaLevel},
    ['FDA Drug Safety 2010', 'CredibleMeds 2024']),

  ('dextrometorfano', 'codeina', InteractionSeverity.moderate,
    'Dextrometorfano e codeína competem pelo CYP2D6 para metabolização; em metabolizadores lentos pode haver acumulación de ambos; riesgo adicional de depresión respiratoria em combinações com opioides',
    'Sedación excesiva, depresión respiratoria em polimorfismos CYP2D6; efecto antitussivo duplicado sem benefício adicional',
    'Evitar uso concomitante. Não há benefício clínico em combinar dois antitussivos. Escolher apenas um',
    'EVITAR — Depresión respiratoria aditiva + competição CYP2D6: dextrometorfano + codeína',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression, RiskType.plasmaLevel},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  // ── 7.2 PSEUDOEFEDRINA ──────────────────────────────────────────────────

  ('pseudoefedrina', 'imao', InteractionSeverity.contraindicated,
    'IMAOs inibem a MAO-A e MAO-B responsáveis pela degradação de catecolaminas; pseudoefedrina libera noradrenalina e adrenalina nas terminações simpáticas — acumulación massivo de catecolaminas causa crisis adrenérgica',
    'Crisis hipertensiva grave (PA sistólica >220 mmHg), encefalopatía hipertensiva, AVC hemorrágico, infarto agudo do miocárdio, morte',
    'CONTRAINDICADO de forma absoluta. Aguardar ≥14 dias después de suspensión de IMAO irreversible (fenelzina, tranilcipromina) e ≥24h después de moclobemida antes de usar pseudoefedrina ou qualquer descongestionante simpatomimético',
    'CONTRAINDICADO ABSOLUTO — Crisis hipertensiva fatal: pseudoefedrina + IMAO',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    ['FDA Drug Safety', 'CredibleMeds 2024', 'Micromedex 2024', 'Gillman PK 2005 — MAOIs and sympathomimetics']),

  ('pseudoefedrina', 'betabloqueador', InteractionSeverity.moderate,
    'Pseudoefedrina ativa receptores α-adrenérgicos (vasoconstrição) e β-adrenérgicos (taquicardia, broncodilatação); betabloqueadores bloqueiam receptores β — efecto α fica desimpedido, resultando em vasoconstrição sem taquicardia reflexa (resposta β bloqueada) — pode elevar PA',
    'Hipertensão paradoxal; bradicardia reflexa mediada por barorreceptores (sem compensação β); broncoespasmo em betabloqueadores não seletivos (propranolol, atenolol, carvedilol) — riesgo aumentado em asmáticos/DPOC',
    'Evitar uso concomitante. Se necesario: preferir betabloqueadores β1-seletivos (metoprolol, bisoprolol), monitorar PA e FC. Evitar en pacientes com asma/DPOC se betabloqueador não for seletivo',
    'CUIDADO — Hipertensão paradoxal + broncoespasmo potencial: pseudoefedrina + betabloqueador',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024', 'Drugs.com Interactions 2024']),

  ('pseudoefedrina', 'metoprolol', InteractionSeverity.moderate,
    'Metoprolol bloqueia selectivamente receptores β1-adrenérgicos cardíacos; pseudoefedrina ativa tanto β quanto α; a seletividade β1 do metoprolol reduz parcialmente o antagonismo — efecto vasoconstritor α permanece',
    'Elevación da PA (efecto α desimpedido); reducción de la taquicardia reflexa esperada; menor riesgo de broncoespasmo que com betabloqueadores não seletivos',
    'Monitorar PA e FC durante uso concomitante. Preferir descongestionante alternativo cuando sea posible. Evitar em crises hipertensivas não controladas',
    'ATENÇÃO — Elevación de PA: pseudoefedrina + metoprolol',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('pseudoefedrina', 'enalapril', InteractionSeverity.moderate,
    'Pseudoefedrina eleva a PA por vasoconstrição α-adrenérgica; IECAs como enalapril são anti-hipertensivos — antagonismo farmacológico direto na regulação pressórica',
    'Reducción de la eficacia anti-hipertensiva do enalapril; elevación transitória da PA; riesgo aumentado em hipertensos',
    'Evitar uso prolongado de descongestionantes simpatomimíticos em hipertensos. Usar apenas por ≤3 dias, monitorar PA diariamente. Preferir lavagem nasal salina ou corticoide nasal tópico como alternativas',
    'ATENÇÃO — Antagonismo anti-hipertensivo: pseudoefedrina + enalapril',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024', 'JNC 8 Guidelines']),

  ('pseudoefedrina', 'losartana', InteractionSeverity.moderate,
    'Pseudoefedrina eleva PA por ativação adrenérgica; losartana bloqueia receptor AT1 da angiotensina II — antagonismo no controle pressórico',
    'Atenuação do efecto antihipertensivo da losartana; elevación da PA especialmente em picos de absorción da pseudoefedrina',
    'Evitar uso em hipertensos não controlados. Limitar a ≤3 dias de uso e monitorar PA. Preferir alternativas não sistêmicas para congestão nasal',
    'ATENÇÃO — Atenuação de anti-hipertensivo: pseudoefedrina + losartana',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'Drugs.com 2024']),

  ('pseudoefedrina', 'digoxina', InteractionSeverity.major,
    'Pseudoefedrina aumenta a automaticidade do nó sinusal e sensibiliza o miocárdio à estimulação adrenérgica; digoxina inibe Na+/K+-ATPase e aumenta tônus vagal — combinación favorece arritmias',
    'Arritmias cardíacas (taquicardia supraventricular, fibrilación auricular, extrassístoles ventriculares) en pacientes digitalizados',
    'Evitar uso concomitante. Se necesario, monitorar ECG e niveles de digoxina. Usar descongestionante alternativo (spray nasal salino, corticoide intranasal)',
    'CUIDADO — Arritmias cardíacas: pseudoefedrina + digoxina',
    EvidenceLevel.probable,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('pseudoefedrina', 'amitriptilina', InteractionSeverity.major,
    'Antidepresivos tricíclicos bloqueiam o transportador de noradrenalina (NET) e bloqueiam receptores α1-adrenérgicos — inibem o mecanismo de ação da pseudoefedrina mas também aumentam a suscetibilidade cardiovascular a arritmias',
    'Hipertensão paradoxal; taquicardia; arritmias; potenciación de efectos adversos cardiovasculares de ambos os fármacos',
    'Evitar combinación. Tricíclicos + simpaticomiméticos são combinación clássica de riesgo cardiovascular. Usar descongestionante tópico nasal como alternativa',
    'CUIDADO — Arritmias e hipertensão: pseudoefedrina + amitriptilina',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  // ── 7.3 MONTELUKAST ─────────────────────────────────────────────────────

  ('montelukast', 'rifampicina', InteractionSeverity.major,
    'Rifampicina é inductor potente do CYP3A4 e CYP2C8/2C9 — acelera o metabolismo del montelukast (substrato CYP3A4/2C8), reduzindo sua biodisponibilidad oral',
    'Reducción de 40–60% nos niveles plasmáticos de montelukast; fracaso terapéutico no controle da asma ou rinite alérgica; riesgo de exacerbação broncospástica por perda de efecto antiinflamatório',
    'Monitorar eficácia clínica do montelukast durante uso de rifampicina. Considerar aumento de dosis ou sustitución por corticoide inalatório como principal terapia anti-inflamatória enquanto rifampicina estiver em uso',
    'ALTO RIESGO DE FRACASO TERAPÉUTICO — Inducción CYP: montelukast + rifampicina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['FDA Drug Label Montelukast 2024', 'Micromedex 2024', 'CredibleMeds 2024']),

  ('montelukast', 'fenitoina', InteractionSeverity.moderate,
    'Fenitoína é inductor moderado/forte do CYP3A4 e CYP2C8 — aumenta o clearance do montelukast e reduz seus niveles plasmáticos em 40–50%',
    'Reducción de la eficacia do montelukast; posible piora do controle da asma ou rinite; perda de protección contra broncospasmo induzido por exercício',
    'Monitorar controle da asma clinicamente (frecuencia de broncodilatadores de resgate, sintomas noturnos). Considerar corticoide inalatório como terapia principal. Se montelukast for mantido, avaliar aumento de dosis',
    'ATENÇÃO — Reducción de eficácia: montelukast + fenitoína',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['Micromedex 2024', 'CredibleMeds 2024', 'Drug Interactions in Epilepsy — Lancet Neurology 2022']),

  ('montelukast', 'carbamazepina', InteractionSeverity.moderate,
    'Carbamazepina é inductor potente do CYP3A4 e moderado do CYP2C8 — reduz significativamente os niveles plasmáticos de montelukast por aumento do clearance hepático',
    'Reducción de la eficacia antiinflamatória e broncodilatadora indireta do montelukast; posible fracaso en el control de asma alérgica e rinite',
    'Monitorar controle da asma en pacientes epilépticos usando carbamazepina + montelukast. Considerar corticoide inalatório como alternativa mais robusta',
    'ATENÇÃO — Inducción CYP3A4: montelukast + carbamazepina',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('montelukast', 'fluconazol', InteractionSeverity.moderate,
    'Fluconazol inibe CYP2C9 e CYP3A4 — pode aumentar os niveles plasmáticos de montelukast por reducción del clearance',
    'Aumento dos niveles de montelukast com potencial aumento de reacciones adversas neuropsiquiátricas (ansiedade, distúrbios do sono, comportamento)',
    'Monitorar síntomas neuropsiquiátricos durante uso concomitante. Suspender montelukast se surgirem alterações de comportamento ou humor',
    'ATENÇÃO — Aumento de montelukast: montelukast + fluconazol',
    EvidenceLevel.possible,
    {RiskType.plasmaLevel},
    ['Micromedex 2024']),

  ('montelukast', 'gemfibrozila', InteractionSeverity.moderate,
    'Gemfibrozila inibe potentemente o CYP2C8 — principal enzima responsável pelo metabolismo del montelukast; pode elevar seus niveles plasmáticos em 4–5×',
    'Aumento significativo nos niveles de montelukast; riesgo amplificado de efectos adversos neuropsiquiátricos (insônia, agitação, depressão, pensamentos suicidas)',
    'Evitar combinación sempre que posible. Si es necesaria, monitorar de perto sintomas neuropsiquiátricos. Considerar alternativa a gemfibrozila (fenofibrato tem menor inhibición del CYP2C8)',
    'CUIDADO — Toxicidade neuropsiquiátrica: montelukast + gemfibrozila',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['FDA Drug Label Montelukast 2024', 'Micromedex 2024', 'CredibleMeds 2024']),

  // ── 7.4 CETIRIZINA ──────────────────────────────────────────────────────

  ('cetirizina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Cetirizina, apesar de ser anti-histamínico de 2ª geração com menor penetração no SNC que os de 1ª geração, pode causar sedación especialmente em dosis altas ou en ancianos; benzodiazepínicos são depressores do SNC — somação de efectos sedantes',
    'Sedación excesiva; comprometimento psicomotor; riesgo de quedas (especialmente en ancianos); sonolência diurna; déficit cognitivo agudo',
    'Usar com cautela. Preferir cetirizina à noite. Reducir dosis de benzodiazepínico se sedación for excessiva. Evitar en ancianos (critérios de Beers). Alertar al paciente sobre não dirigir ou operar máquinas',
    'CUIDADO — Sedación aditiva: cetirizina + benzodiazepínico',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['Beers Criteria AGS 2023', 'Micromedex 2024', 'CredibleMeds 2024']),

  ('cetirizina', 'opioide', InteractionSeverity.moderate,
    'Cetirizina tem propriedades anticolinérgicas leves e sedativas — some com efectos sedantes e depressores respiratórios dos opioides',
    'Sedación excesiva; depresión respiratoria potencializada; constipação aumentada (efectos anticolinérgicos aditivos); riesgo de retenção urinária',
    'Monitorar estado de consciência e padrão respiratório. Preferir anti-histamínico com menor ação sedativa ou anticolinérgica. Atención redobrada en ancianos e pacientes com DPOC/apnea do sono',
    'ATENÇÃO — Depresión del SNC aditiva: cetirizina + opioide',
    EvidenceLevel.probable,
    {RiskType.respiratoryDepression},
    ['Micromedex 2024', 'CredibleMeds 2024']),

  ('cetirizina', 'ritonavir', InteractionSeverity.moderate,
    'Ritonavir é inhibidor do CYP3A4 e inhibidor da glicoproteína-P — pode elevar os niveles plasmáticos de cetirizina, que é parcialmente eliminada pelo rim mas também tem transporte dependente de P-gp',
    'Elevación dos niveles de cetirizina com posible aumento de sedación e efectos anticolinérgicos; prolongamento do efecto',
    'Monitorar sedación excesiva. Reducir dosis de cetirizina se necesario (considerar 5 mg ao invés de 10 mg). Preferir fexofenadina como alternativa (menor interacción com P-gp)',
    'ATENÇÃO — Elevación de cetirizina: cetirizina + ritonavir',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel},
    ['Micromedex 2024', 'FDA Drug Interaction Studies']),

  ('cetirizina', 'teofilina', InteractionSeverity.minor,
    'Teofilina pode reduzir ligeiramente o clearance da cetirizina — mecanismo não completamente elucidado, possivelmente via inhibición competitiva de transporte renal',
    'Aumento leve de ~16% na AUC da cetirizina; riesgo clínico mínimo, mas pode ampliar sedación em dosis altas',
    'Monitorar sedación en pacientes com asma ou DPOC usando teofilina + cetirizina. Relevância clínica baixa em dosiss padrão',
    'MONITORAR — Leve elevación de cetirizina: cetirizina + teofilina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    ['FDA Drug Label Cetirizina', 'Micromedex 2024']),

  ('cetirizina', 'alcool', InteractionSeverity.moderate,
    'Álcool etílico é depressor do SNC; cetirizina tem efecto sedante variável (maior em dosis altas, idosos e metabolizadores lentos) — somação dos efectos depressores centrais',
    'Sedación acentuada; comprometimento da coordenação motora; lentificação dos reflexos; riesgo de acidentes de trânsito; tontura',
    'Evitar consumo de álcool durante uso de cetirizina. Alertar especialmente pacientes que dirigem ou operam máquinas. Preferir cetirizina ao deitar para minimizar impacto diurno',
    'CUIDADO — Sedación aditiva: cetirizina + álcool',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    ['FDA Drug Label Cetirizina 2024', 'Micromedex 2024']),

  // ── 7.5 FENILEFRINA ─────────────────────────────────────────────────────

  ('fenilefrina', 'imao', InteractionSeverity.contraindicated,
    'Fenilefrina é agonista α1-adrenérgico direto; IMAOs bloqueiam degradação de catecolaminas — potenciación extrema do efecto vasopresor da fenilefrina',
    'Crisis hipertensiva grave; encefalopatía hipertensiva; AVC; infarto agudo do miocárdio',
    'CONTRAINDICADO. Aguardar período de lavado completo de IMAO (≥14 dias para irreversíveis; ≥24h para moclobemida)',
    'CONTRAINDICADO ABSOLUTO — Crisis hipertensiva: fenilefrina + IMAO',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    ['FDA Drug Safety', 'Micromedex 2024', 'CredibleMeds 2024']),

  ('fenilefrina', 'betabloqueador', InteractionSeverity.moderate,
    'Betabloqueadores bloqueiam a vasodilatação β2-mediada — efecto vasoconstritor α1 da fenilefrina fica desimpedido, podendo causar elevación pressórica e bradicardia reflexa',
    'Hipertensão paradoxal; bradicardia reflexa; aumento da pós-carga cardíaca',
    'Evitar combinación em hipertensos e cardiopatas. Se necesario, monitorar PA e FC durante uso',
    'CUIDADO — Hipertensão paradoxal: fenilefrina + betabloqueador',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    ['Micromedex 2024', 'CredibleMeds 2024']),


  // ── Dislipidemia: Fibratos e Resinas ─────────────────────────────────────────

  ('gemfibrozil', 'pravastatina', InteractionSeverity.major,
    'Inhibición de la glicuronidação da estatina pelo gemfibrozil, aumentando drásticamente os niveles plasmáticos',
    'Riesgo altíssimo de miopatía grave e rabdomiólisis fatal',
    'Evitar la combinación. Se fibrato for essencial, o fenofibrato é preferível e mais seguro com estatinas',
    'ALTO RIESGO DE RABDOMIÓLISIS — Contraindicado',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('gemfibrozil', 'repaglinida', InteractionSeverity.contraindicated,
    'Inhibición potente do CYP2C8 e OATP1B1 pelo gemfibrozil',
    'Aumento de até 8 vezes na concentración de repaglinida, causando hipoglucemia severa e prolongada',
    'Combinación contraindicada.',
    'HIPOGLUCEMIA GRAVE — Contraindicado',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.hypoglycemia},
    [_kRefMdx, _kRefFDA]),

  ('colestiramina', 'warfarina', InteractionSeverity.moderate,
    'Ligação da resina à varfarina no lúmen intestinal',
    'Reducción de la absorción da varfarina, diminuindo o INR e elevando o riesgo trombótico',
    'Administrar varfarina pelo menos 1 hora antes ou 4 a 6 horas después de a colestiramina',
    'MONITORAR INR — Riesgo de fracaso terapéutica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

  ('colestiramina', 'levotiroxina', InteractionSeverity.major,
    'Sequestro da levotiroxina no trato gastrointestinal formando complexo insoluble',
    'Falha no tratamiento do hipotiroidismo (elevación do TSH)',
    'Separar a administração por pelo menos 4 a 6 horas',
    'FALHA DE ABSORÇÃO — Espaçar dosiss rigurosamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  // ── Hepatite C: Antivirais de Ação Direta ─────────────────────────────────────

  ('sofosbuvir', 'amiodarona', InteractionSeverity.contraindicated,
    'Mecanismo desconhecido, possivelmente disfunção acentuada do nó sinusal miocárdico',
    'Bradicardia sintomática grave, bloqueio cardíaco fatal ou necessidade marcapasso',
    'Combinación totalmente contraindicada. Si inevitable, monitoramento cardíaco contínuo hospitalar por 48h',
    'BRADICARDIA FATAL — Contraindicado',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefFDA, _kRefMdx, _kRefUT]),

  ('ledipasvir', 'omeprazol', InteractionSeverity.major,
    'O ledipasvir necessita de ambiente ácido no estômago para ser absorvido. Os IBP anulam essa acidez',
    'Fracaso virológico no tratamiento da Hepatite C por subdosagem de ledipasvir',
    'Evitar IBP. Se necesario, administrar simultáneamente com estômago vazio usando dosis máx de omeprazol 20mg',
    'FRACASO TERAPÉUTICO — Absorción comprometida',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  ('velpatasvir', 'carbamazepina', InteractionSeverity.major,
    'Inducción potente da P-glicoproteína (P-gp) e CYP450 pela carbamazepina',
    'Reducción drástica nos niveles de velpatasvir, levando à perda de eficácia antiviral',
    'Evitar o uso concomitante de inductores fortes durante o tratamiento da Hepatite C',
    'PERDA DE EFICÁCIA ANTIVIRAL — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx]),

  // ── Psiquiatria: Antipsicóticos Atípicos ──────────────────────────────────────

  ('clozapina', 'carbamazepina', InteractionSeverity.contraindicated,
    'Efecto aditivo/sinérgico na toxicidad da medula óssea',
    'Aumento dramático no riesgo de agranulocitose e aplasia medular fatal',
    'Combinación absolutamente contraindicada. Escolher outro estabilizador do humor (ex: Valproato)',
    'AGRANULOCITOSE FATAL — Contraindicado',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('ziprasidona', 'amiodarona', InteractionSeverity.contraindicated,
    'Sinergismo na inhibición dos canais de potássio retificadores miocárdicos (hERG)',
    'Prolongação extrema do intervalo QT e riesgo de Torsades de Pointes',
    'Contraindicado o uso conjunto com outros fármacos que prolongam o QT de forma conhecida',
    'RIESGO DE TORSADES DE POINTES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  ('cariprazina', 'cetoconazol', InteractionSeverity.moderate,
    'Inhibición potente del CYP3A4 pelo cetoconazol',
    'Aumento significativo das concentraciones de cariprazina e seus metabólitos ativos (DDCAR)',
    'Reducir la dosis de cariprazina à metade e monitorar acatisia e parkinsonismo',
    'RISCO EXTRAPIRAMIDAL — Reducir dosis',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('lurasidona', 'diltiazem', InteractionSeverity.major,
    'Inhibición moderada a forte do CYP3A4 pelo diltiazem',
    'Elevación aguda da lurasidona, aumentando sedación, acatisia e hipotensión',
    'A dosis de lurasidona não deve exceder 40 mg/dia quando coadministrada com diltiazem',
    'AJUSTE DE DOSIS NECESSÁRIO — Riesgo de toxicidad',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefUT]),

  // ── Demência / Alzheimer ──────────────────────────────────────────────────────

  ('donepezila', 'butilescopolamina', InteractionSeverity.major,
    'Antagonismo farmacodinâmico direto (Colinérgico vs Anticolinérgico)',
    'Anulação da eficácia do tratamiento para Alzheimer (piora cognitiva) e exacerbação anticolinérgica periférica',
    'Evitar o uso de anticolinérgicos sistêmicos en pacientes com demência tratada farmacologicamente',
    'ANTAGONISMO TERAPÊUTICO — Piora do Alzheimer',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.cns},
    [_kRefGG, _kRefMdx]),

  ('donepezila', 'difenidramina', InteractionSeverity.major,
    'A difenidramina possui altíssima carga anticolinérgica (anti-M1 central)',
    'Anulação completa do efecto do inhibidor da acetilcolinesterase e inducción de delirio agudo no idoso',
    'Contraindicado. Usar anti-histamínicos de 2ª geração (ex: Bilastina, Fexofenadina)',
    'DELIRIUM E CONFUSÃO — Evitar anti-H1 de 1ª geração',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.cns},
    [_kRefMdx, _kRefUT]),

  ('memantina', 'acetazolamida', InteractionSeverity.moderate,
    'A alcalinização urinária induzida pela acetazolamida diminui o aclaramiento renal da memantina',
    'Acumulación de memantina sérica, levando a confusión mental, tontura e psicose paradoxal',
    'Monitorar función cognitiva de perto ou evitar la combinación',
    'TOXICIDADE NEUROLÓGICA — Riesgo de acumulación sistêmico',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('donepezila', 'timolol', InteractionSeverity.major,
    'Sinergia cronotrópica negativa: aumento do tônus colinérgico central/periférico + bloqueio beta-adrenérgico sistémico',
    'Bradicardia sinusal sintomática grave, bloqueios auriculoventriculares e síncope recorrente no idoso',
    'Monitorar o pulso regularmente. Ensinar o paciente a ocluir o ponto lacrimal ao instilar o colírio para evitar absorción',
    'BRADICARDIA E SÍNCOPE — Sinergia Cardiodepressora',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

  // ── Hemostáticos ──────────────────────────────────────────────────────────────

  ('desmopressina', 'furosemida', InteractionSeverity.major,
    'Efectos aditivos sobre a alteração do volume e concentración do sódio plasmático (retenção de água livre + depleção de sódio)',
    'Hiponatremia dilucional aguda e grave, provocando edema cerebral, obnubilação e convulsiones',
    'Evitar o uso de diuréticos potentes en pacientes que recebem desmopressina. Controlar o sódio sérico a cada 24h',
    'HIPONATREMIA DILUCIONAL GRAVE — Riesgo de Convulsiones',
    EvidenceLevel.established,
    {RiskType.electrolyte, RiskType.seizure},
    [_kRefMdx, _kRefGG]),

  ('acido tranexamico', 'anticonceptivo', InteractionSeverity.moderate,
    'Sinergia pró-trombótica: inhibición de la fibrinólise pelo ácido tranexâmico somada ao estado pró-coagulante dos estrogênios',
    'Riesgo aumentado de tromboembolismo venoso (TVP, TEP) e arterial',
    'Usar com cautela. Evitar combinación en pacientes com histórico ou fatores de riesgo para trombosis',
    'RISCO TROMBÓTICO ADITIVO — Precaución en pacientes de riesgo',
    EvidenceLevel.probable,
    {RiskType.thrombosis},
    [_kRefMdx, _kRefUT]),

  ('vitamina k1', 'varfarina', InteractionSeverity.major,
    'Antagonismo farmacodinâmico direto: a vitamina K1 é o substrato que a varfarina bloqueia na síntese de fatores de coagulação',
    'Reversão do efecto anticoagulante e queda do INR, aumentando riesgo trombótico',
    'Monitorar INR rigurosamente. Uso terapéutico intencional para reverter superdosagem de varfarina',
    'REVERSÃO DO ANTICOAGULANTE — Monitorizar INR',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.thrombosis},
    [_kRefGG, _kRefFDA]),

  // ── Psoríase / Dermatologia ───────────────────────────────────────────────────

  ('acitretina', 'metotrexato', InteractionSeverity.major,
    'Ambos fármacos são intensamente hepatotóxicos; competência na excreción e metabolismo',
    'Hepatite tóxica aguda, elevación fulminante de transaminases e riesgo de cirrose a longo prazo',
    'Asociación frecuentemente evitada. Se usada, exige hepatograma a cada 2-4 semanas',
    'HEPATOTOXICIDAD GRAVE ADITIVA — Evitar si es posible',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity},
    [_kRefGG, _kRefUT]),

  ('acitretina', 'doxiciclina', InteractionSeverity.contraindicated,
    'Sinergia neurotóxica idiopática entre retinoides sistémicos (vitamina A) e tetraciclinas',
    'Riesgo crítico de Hipertensão Intracraniana Benigna (Pseudotumor Cerebri), causando cefaleia severa, edema de papila e cegueira permanente',
    'Contraindicado. Nunca associar retinoides orais com antibióticos da classe das tetraciclinas',
    'CEGUEIRA POR HIC — Contraindicado com Tetraciclinas',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefFDA, _kRefMdx]),

  ('acitretina', 'alcool', InteractionSeverity.contraindicated,
    'O álcool converte a acitretina de volta a etretinato, metabólito com vida media extremamente longa (120 dias) e altamente teratogênico',
    'Riesgo de teratogenicidade prolongada por até 2 anos después de a suspensión do medicamento',
    'Consumo de álcool absolutamente contraindicado durante e por 2 meses después de o tratamiento',
    'TERATOGENICIDADE PROLONGADA — Álcool absolutamente prohibido',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefFDA, _kRefGG]),

  ('finasterida', 'inhibidores cyp3a4', InteractionSeverity.minor,
    'A finasterida é metabolizada principalmente pelo CYP3A4',
    'Posible aumento modesto dos niveles de finasterida com inhibidores potentes (cetoconazol, itraconazol)',
    'Sem ajuste de dosis necesario para a maioria dos pacientes; monitorar efectos adversos',
    'INTERAÇÃO LEVE — Monitorar efectos adversos',
    EvidenceLevel.theoretical,
    {RiskType.plasmaLevel},
    [_kRefMdx]),

  // ── Vitaminas e Suplementos ───────────────────────────────────────────────────

  ('vitamina d', 'tiazidico', InteractionSeverity.moderate,
    'Os tiazídicos reduzem a excreción renal de cálcio e a vitamina D aumenta a absorción intestinal de cálcio',
    'Hipercalcemia, especialmente en pacientes com hiperparatireoidismo ou sarcoidosis',
    'Monitorar calcemia periodicamente en pacientes usando vitamina D e tiazídicos crónicamente',
    'HIPERCALCEMIA — Monitorar cálcio sérico',
    EvidenceLevel.established,
    {RiskType.electrolyte, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('vitamina d', 'orlistate', InteractionSeverity.moderate,
    'O orlistate inibe a absorción de gordura e vitaminas lipossolúveis no intestino',
    'Reducción de la absorción de vitamina D, agravando deficiências en pacientes obesos',
    'Suplementar vitamina D em dosiss adecuadas e separar a administração do orlistate',
    'ABSORÇÃO REDUZIDA — Suplementação ajustada',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),

  ('vitamina c', 'varfarina', InteractionSeverity.minor,
    'Altas dosis de vitamina C (>1g/dia) podem interferir com o metabolismo de la varfarina',
    'Posible alteração do INR (reducción ou aumento dependendo da dosis)',
    'Monitorar INR se paciente usar suplementação de vitamina C em dosis altas',
    'MONITORAR INR — Altas dosis de vitamina C',
    EvidenceLevel.possible,
    {RiskType.hemorrhagic},
    [_kRefMdx]),

  ('vitamina c', 'deferasirox', InteractionSeverity.moderate,
    'A vitamina C aumenta a biodisponibilidad do ferro e pode alterar a farmacocinética do quelante',
    'Potencial excesso de quelação e toxicidad por deferasirox se iron stores forem baixos',
    'Evitar suplementação simultânea de vitamina C em altas dosiss com quelantes de ferro',
    'INTERAÇÃO COM QUELANTE DE FERRO — Evitar altas dosiss',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefMdx]),

  ('acido folico', 'metotrexato', InteractionSeverity.moderate,
    'O ácido fólico é o substrato que o metotrexato antagoniza ao inibir a diidrofolato redutase',
    'Suplementação com ácido fólico pode atenuar a toxicidad do metotrexato sin embargo pode reduzir ligeiramente sua eficácia',
    'Uso intencional e supervisionado: suplementar com 1-5 mg/dia de ácido fólico para reduzir efectos adversos do MTX em dosis bajas reumatológicas',
    'ANTAGONISMO FOLATO — Uso supervisionado para reduzir toxicidad',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  ('acido folico', 'sulfassalazina', InteractionSeverity.moderate,
    'A sulfassalazina inibe a absorción intestinal do ácido fólico e compete pelas enzimas do metabolismo del folato',
    'Deficiência de folato e aumento del riesgo de anemia megaloblástica ou macrocitose',
    'Aumentar a dosis de suplementação de ácido fólico (ex. 1 a 5 mg/dia) e espaçar as tomadas da sulfassalazina',
    'DÉFICIT DE ÁCIDO FÓLICO — Requer suplementação maior',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.increasedToxicity},
    [_kRefMdx]),

  ('magnesio', 'antibiotico tetraciclinico', InteractionSeverity.major,
    'Formação de quelatos insolúveis entre o magnésio e as tetraciclinas no trato gastrointestinal',
    'Reducción drástica na absorción das tetraciclinas (doxiciclina, tetraciclina), levando a falha antibiótica',
    'Espaçar a administração em pelo menos 2 horas. Preferir administrar o antibiótico 1h antes do suplemento',
    'FALHA ANTIBIÓTICA POR QUELAÇÃO — Espaçar dosiss',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('magnesio', 'fluoroquinolona', InteractionSeverity.major,
    'Formação de quelatos entre cátions divalentes (Mg2+) e fluoroquinolonas no lúmen intestinal',
    'Reducción de até 50% na biodisponibilidad da fluoroquinolona, causando falha antibiótica',
    'Administrar a fluoroquinolona pelo menos 2 horas antes ou 6 horas después de o suplemento de magnésio',
    'FALHA ANTIBIÓTICA (QUELAÇÃO) — Espaçar dosiss obligatoriamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('zinco', 'antibiotico tetraciclinico', InteractionSeverity.major,
    'Quelação do zinco com tetraciclinas no trato gastrointestinal',
    'Reducción significativa na absorción de ambos: do antibiótico e do zinco',
    'Espaçar em pelo menos 2 horas. Tomar o antibiótico antes do suplemento',
    'QUELAÇÃO MÚTUA — Espaçar dosiss 2h',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('zinco', 'fluoroquinolona', InteractionSeverity.moderate,
    'Formação de quelatos insolúveis entre zinco e fluoroquinolonas',
    'Reducción de la biodisponibilidad da fluoroquinolona e do zinco simultáneamente',
    'Administrar a fluoroquinolona pelo menos 2 horas antes do suplemento de zinco',
    'ABSORÇÃO REDUZIDA — Espaçar dosiss',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('cianocobalamina', 'metformina', InteractionSeverity.moderate,
    'A metformina reduce la absorción de vitamina B12 ao interferir no receptor cálcio-dependente ileal',
    'Deficiência subclínica ou clínica de vitamina B12 a longo prazo, riesgo de neuropatia megaloblástica',
    'Monitorar os niveles séricos de B12 anualmente en pacientes sob terapia crônica com metformina',
    'DÉFICIT CRÓNICO DE B12 — Monitoramento anual',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefUT, _kRefMdx]),

  ('cianocobalamina', 'omeprazol', InteractionSeverity.moderate,
    'A supresión profunda e prolongada do ácido gástrico impede a dissociação da vitamina B12 de suas proteínas dietéticas',
    'Deficiência subclínica ou clínica de vitamina B12 a longo prazo, riesgo de neuropatia megaloblástica',
    'Monitorar os niveles séricos de B12 anualmente en pacientes sob terapia crônica com IBP',
    'DÉFICIT CRÓNICO DE B12 — Monitoramento anual com IBP',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefUT, _kRefMdx]),

  ('tiamina', 'alcool', InteractionSeverity.major,
    'O álcool crônico inibe a absorción intestinal, diminui o estoque hepático e aumenta a excreción urinária de tiamina',
    'Deficiência grave de tiamina com riesgo de Encefalopatía de Wernicke e Síndrome de Korsakoff',
    'Reposição intravenosa urgente de tiamina (300 mg IV/IM) antes de qualquer infusão de glicose em alcoolistas',
    'ENCEFALOPATIA DE WERNICKE — Reposição IV urgente',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  ('piridoxina', 'levodopa', InteractionSeverity.major,
    'A piridoxina aumenta o metabolismo periférico da levodopa pela DOPA descarboxilase antes de atingir o SNC',
    'Reducción significativa da eficácia terapéutica da levodopa para o Parkinson',
    'Evitar suplementação de piridoxina en pacientes usando levodopa sem inhibidor de descarboxilase (benserazida ou carbidopa)',
    'PERDA DE EFICÁCIA DO ANTIPARKINSONIANO — Usar com carbidopa',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('piridoxina', 'isoniazida', InteractionSeverity.major,
    'A isoniazida inibe o metabolismo de la piridoxina e sua conversão à forma ativa (piridoxal-5-fosfato)',
    'Neuropatia periférica por deficiência funcional de piridoxina, especialmente em desnutridos e diabéticos',
    'Suplementar piridoxina 25-50 mg/dia em todos os pacientes em uso de isoniazida',
    'NEUROPATIA PERIFÉRICA — Suplementar piridoxina obligatoriamente',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // ── Anemias ───────────────────────────────────────────────────────────────────

  ('sulfato ferroso', 'omeprazol', InteractionSeverity.moderate,
    'Os IBP elevam o pH gástrico, reduzindo a solubilização do ferro ferroso',
    'Reducción na absorción do sulfato ferroso, dificultando a correção da anemia ferropriva',
    'Administrar o ferro em jejum si es posible, ou separar do IBP. Monitorar hemograma e ferritina',
    'ABSORÇÃO REDUZIDA — Monitorar respuesta hematológica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('sulfato ferroso', 'ciprofloxacino', InteractionSeverity.major,
    'Formação de quelatos insolúveis entre o ferro e as fluoroquinolonas no lúmen intestinal',
    'Falha do antibiótico fluoroquinolona por absorción insuficiente',
    'Administrar a fluoroquinolona pelo menos 2 horas antes ou 6 horas después de o sulfato ferroso',
    'FALHA ANTIBIÓTICA — Espaçar dosiss obligatoriamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('sulfato ferroso', 'levotiroxina', InteractionSeverity.major,
    'O ferro forma complexo insoluble com a levotiroxina no trato gastrointestinal',
    'Reducción de la absorción da levotiroxina e elevación do TSH, levando ao hipotiroidismo descontrolado',
    'Separar as administrações em pelo menos 4 horas',
    'HIPOTIROIDISMO DESCOMPENSADO — Espaçar 4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('ferro iv', 'epoetina', InteractionSeverity.moderate,
    'A eritropoetina estimula a eritropoese, aumentando a demanda por ferro. A oferta de ferro IV potencializa a resposta',
    'Quando o ferro IV é administrado sem eritropoetina adecuada, pode haver acumulación de ferro livre (toxicidad oxidativa)',
    'Monitorar ferritina e saturação de transferrina. Titular a dosis de ferro IV conforme resposta hematológica',
    'MONITORAR ESTOQUE DE FERRO — Evitar sobrecarga',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefUT, _kRefMdx]),

  ('epoetina', 'varfarina', InteractionSeverity.moderate,
    'O aumento do hematócrito e da viscosidade sanguínea induzido pela eritropoetina pode alterar o estado tromboembólico',
    'Aumento do riesgo trombótico e posible necessidade ajuste da dosis de varfarina',
    'Monitorar INR e sinais de tromboembolismo en pacientes anticoagulados iniciando eritropoetina',
    'RISCO TROMBÓTICO E ALTERAÇÃO DO INR — Monitorar',
    EvidenceLevel.probable,
    {RiskType.thrombosis, RiskType.hemorrhagic},
    [_kRefMdx]),

  ('epoetina', 'ciclosporina', InteractionSeverity.moderate,
    'A eritropoetina eleva o hematócrito e pode aumentar a viscosidade, alterando a farmacocinética da ciclosporina',
    'Alteração dos niveles de ciclosporina e aumento da presión arterial, podendo comprometer o injerto renal',
    'Monitorar presión arterial e niveles de ciclosporina al iniciar ou ajustar la dosis de eritropoetina',
    'HIPERTENSÃO E ALTERAÇÃO DE CICLOSPORINA — Monitorar',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  // ── Fígado e Pâncreas ─────────────────────────────────────────────────────────

  ('acido ursodesoxicolico', 'ciclosporina', InteractionSeverity.moderate,
    'O ácido ursodesoxicólico pode aumentar a absorción da ciclosporina ao alterar a composição da bile intestinal',
    'Elevación dos niveles de ciclosporina, com potencial nefrotoxicidad e imunossupresión excessiva',
    'Monitorar os niveles séricos de ciclosporina al iniciar o ácido ursodesoxicólico',
    'NÍVEL DE CICLOSPORINA AUMENTADO — Monitorar concentraciones',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.nephrotoxicity},
    [_kRefMdx]),

  ('acido ursodesoxicolico', 'colestiramina', InteractionSeverity.major,
    'A colestiramina sequestra o ácido ursodesoxicólico no intestino, impedindo sua absorción',
    'Falha terapéutica no tratamiento da colangite biliar primária ou litíase biliar',
    'Administrar o ácido ursodesoxicólico pelo menos 2 horas antes ou 4 horas después de a colestiramina',
    'ABSORÇÃO ANULADA — Espaçar dosiss obligatoriamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('lactulose', 'antibiotico', InteractionSeverity.moderate,
    'Antibióticos sistêmicos alteram a flora intestinal necesaria para a fermentação da lactulose',
    'Reducción de la eficacia da lactulose no controle da encefalopatía hepática ao eliminar as bactérias que a metabolizam',
    'Monitorar o grau de encefalopatía e considerar ajuste da dosis de lactulose durante cursos de antibióticos',
    'EFICACIA REDUCIDA — Monitorar encefalopatía',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('pancrelipase', 'acarbosa', InteractionSeverity.major,
    'A acarbosa é um inhibidor direto das enzimas alfa-glicosidases e da amilase pancreática',
    'Anulação total do efecto terapéutico da pancrelipase (especificamente a fração amilase), piorando a esteatorrea e desnutrição',
    'Evitar la combinación. Pacientes com insuficiência pancreática exócrina não devem ser tratados com acarbosa',
    'ANULAÇÃO ENZIMÁTICA TOTAL — Evitar uso concomitante',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('pancrelipase', 'bicarbonato', InteractionSeverity.moderate,
    'A alcalinização do ambiente gástrico-duodenal pode inativar as enzimas pancreáticas antes de atingirem o intestino delgado',
    'Reducción de la eficacia da reposição enzimática, com persistência de má absorción e esteatorrea',
    'Usar formulações entéricas de enzimas pancreáticas (revestimento gastrorresistente) e evitar antiácidos potentes próximos às refeições',
    'INATIVAÇÃO ENZIMÁTICA — Preferir cápsulas gastrorresistentes',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefMdx]),

  // ── Respiratório Avançado ─────────────────────────────────────────────────────

  ('omalizumabe', 'vacinas vivas', InteractionSeverity.major,
    'O omalizumabe suprime a resposta imune mediada por IgE e pode atenuar a resposta a vacinas vivas',
    'Riesgo de infecção ativa pela cepa vacinal e resposta imune atenuada',
    'Evitar vacinas vivas atenuadas durante o tratamiento com omalizumabe. Preferir vacinas inativadas',
    'RISCO DE INFECÇÃO VACINAL — Evitar vacinas vivas',
    EvidenceLevel.probable,
    {RiskType.infection},
    [_kRefFDA, _kRefUT]),

  ('omalizumabe', 'dupilumabe', InteractionSeverity.major,
    'Combinación de dois biológicos com supresión imune em vias diferentes (anti-IgE + anti-IL-4/IL-13)',
    'Imunossupresión excessiva com riesgo de infecções oportunistas sem benefício adicional comprovado',
    'Combinación de dois biológicos sistêmicos absolutamente contraindicada',
    'IMUNOSSUPRESSÃO EXCESSIVA — Contraindicado',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.increasedToxicity},
    [_kRefFDA, _kRefUT]),

  // ── Alergias ──────────────────────────────────────────────────────────────────

  ('cetirizina', 'alcool', InteractionSeverity.moderate,
    'Potenciação da sedación central pelo álcool em combinación com anti-histamínicos de 2ª geração',
    'Sedación aumentada, comprometimento da atención e habilidades psicomotoras',
    'Evitar o consumo de álcool durante o uso de cetirizina, especialmente se for dirigir ou operar máquinas',
    'SEDACIÓN AUMENTADA — Evitar álcool',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefMdx]),

  ('difenidramina', 'benzodiazepínico', InteractionSeverity.major,
    'Sinergia na depressão do Sistema Nervioso Central e sedación excesiva',
    'Sedación profunda, comprometimento cognitivo grave, depresión respiratoria e riesgo de queda en ancianos',
    'Evitar la combinación. A difenidramina está na lista de medicamentos de alto riesgo para idosos (Critérios de Beers)',
    'DEPRESSÃO SNC SEVERA — Evitar en ancianos (Critérios de Beers)',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),

  ('difenidramina', 'opioide', InteractionSeverity.major,
    'Depressão farmacodinâmica aditiva do SNC e do centro respiratório bulbar',
    'Sedación profunda, letargia prolongada e riesgo iminente de parada respiratória',
    'Evitar a asociación. Usar anti-histamínicos de 2ª geração (fexofenadina, loratadina) como alternativas seguras',
    'DEPRESIÓN RESPIRATORIA SEVERA — Evitar combinación',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefMdx, _kRefGG]),

  ('difenidramina', 'imao', InteractionSeverity.contraindicated,
    'Os IMAOs inibem o metabolismo hepático da difenidramina, potencializando seus efectos anticolinérgicos e sedantes',
    'Toxicidade anticolinérgica grave: taquicardia, delirio, hipertermia, retenção urinária e posible psicose',
    'Contraindicado. Aguardar período de lavado completo do IMAO antes de usar difenidramina',
    'TOXICIDADE ANTICOLINÉRGICA GRAVE — Contraindicado com IMAO',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('fexofenadina', 'cetoconazol', InteractionSeverity.moderate,
    'O cetoconazol inibe o transportador P-glicoproteína e aumenta a biodisponibilidad da fexofenadina',
    'Aumento dos niveles plasmáticos de fexofenadina, com potencial prolongamento do intervalo QT',
    'Monitorar ECG en pacientes com fatores de riesgo cardíaco. Generalmente bem tolerado na prática',
    'AUMENTO DE NÍVEIS — Monitorar QT en pacientes de riesgo',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.qtProlongation},
    [_kRefMdx, _kRefFDA]),

  ('fexofenadina', 'eritromicina', InteractionSeverity.moderate,
    'A eritromicina inibe a P-glicoproteína e o transportador OATP, aumentando a biodisponibilidad da fexofenadina',
    'Aumento de até 2 vezes nos niveles plasmáticos de fexofenadina',
    'Generalmente bem tolerado, mas monitorar en pacientes com fatores de riesgo para prolongación del QT',
    'AUMENTO DE BIODISPONIBILIDADE — Monitorar en pacientes de riesgo cardíaco',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx]),

  // ── Alzheimer ─────────────────────────────────────────────────────────────────

  ('donepezila', 'amiodarona', InteractionSeverity.major,
    'Sinergia bradicardizante: inhibidor da colinesterase aumenta o tônus vagal somado ao efecto cronotrópico negativo da amiodarona',
    'Bradicardia sinusal severa, bloqueo AV de 2º/3º grau e síncope recorrente',
    'Monitorar ECG e frecuencia cardíaca. Considerar alternativas terapéuticas',
    'BRADICARDIA SEVERA — Monitorar ECG',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

  ('donepezila', 'succinilcolina', InteractionSeverity.major,
    'Os inhibidores da colinesterase reduzem a hidrólise da succinilcolina, prolongando seu efecto neuromuscular',
    'Bloqueio neuromuscular prolongado e apnea pós-operatória inesperada',
    'Alertar o anestesiologista sobre o uso de inhibidores de colinesterase antes de procedimientos cirúrgicos',
    'APNEA PÓS-OPERATÓRIA — Alertar equipe de anestesia',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('memantina', 'amantadina', InteractionSeverity.major,
    'Ambos são antagonistas dos receptores NMDA de glutamato; efecto aditivo/sinérgico',
    'Toxicidad por excesso de bloqueio NMDA: alucinações, agitação, mioclonias e psicose aguda',
    'Evitar la combinación. Se necesario para Parkinson + demência, usar dosis mínimas com monitoramento rigoroso',
    'PSICOSE E ALUCINAÇÕES — Evitar bloqueio NMDA duplo',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('memantina', 'ketamina', InteractionSeverity.major,
    'Antagonismo NMDA duplo: a cetamina e a memantina bloqueiam o mesmo receptor',
    'Potenciação dos efectos dissociativos e psicodislépticos, riesgo de psicose e excitação paradoxal',
    'Usar a cetamina com extrema cautela en pacientes usando memantina. Reducir la dosis de cetamina e monitorar o estado mental',
    'POTENCIAÇÃO DISSOCIATIVA — Riesgo de psicose aguda',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // ── Psicose e Mania ───────────────────────────────────────────────────────────

  ('carbonato de litio', 'aine', InteractionSeverity.major,
    'Os AINEs inibem as prostaglandinas renais, reduzindo a filtração glomerular e aclaramiento renal do lítio',
    'Acumulación de lítio com toxicidad aguda (tremor grosseiro, ataxia, confusão, convulsiones)',
    'Monitorar niveles séricos de lítio al iniciar ou suspender AINEs. Preferir paracetamol como analgésico',
    'TOXICIDADE POR LÍTIO — Monitorar nivel sérico rigurosamente',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.seizure},
    [_kRefGG, _kRefMdx]),

  ('quetiapina', 'carbamazepina', InteractionSeverity.major,
    'A carbamazepina é inductor potente do CYP3A4, principal via metabólica da quetiapina',
    'Reducción de até 87% nos niveles plasmáticos de quetiapina, causando fracaso terapéutico psiquiátrica',
    'Evitar la combinación ou aumentar significativamente a dosis de quetiapina sob monitoramento clínico rigoroso',
    'FALHA ANTIPSICÓTICA — Inducción CYP3A4 pela carbamazepina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx, _kRefUT]),

  ('haloperidol', 'carbamazepina', InteractionSeverity.moderate,
    'A carbamazepina induz o metabolismo hepático do haloperidol pelo CYP3A4',
    'Reducción significativa dos niveles plasmáticos de haloperidol, com riesgo de recaída psicótica',
    'Monitorar respuesta clínica e considerar aumento da dosis de haloperidol durante o uso concomitante',
    'REDUÇÃO DOS NÍVEIS — Monitorar respuesta psiquiátrica',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('haloperidol', 'rifampicina', InteractionSeverity.major,
    'A rifampicina é um inductor enzimático potente do CYP3A4 e CYP2D6, vías de metabolismo del haloperidol',
    'Queda drástica nos niveles de haloperidol, com perda do controle dos síntomas psicóticos',
    'Evitar a asociación ou aumentar a dosis de haloperidol com monitoramento clínico intensivo',
    'PERDA DE CONTROLE PSICÓTICO — Inducción enzimática grave',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('haloperidol', 'mefloquina', InteractionSeverity.major,
    'Ambos prolongam o intervalo QT de forma independente e aditiva',
    'Riesgo aumentado de Torsades de Pointes e morte súbita cardíaca',
    'Contraindicado. Escolher outro antipsicótico com menor riesgo de prolongación del QT',
    'TORSADES DE POINTES — Contraindicado',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefMdx, _kRefUT]),

  // ── Anestesia ─────────────────────────────────────────────────────────────────

  ('cetamina', 'benzodiazepínico', InteractionSeverity.moderate,
    'Os benzodiazepínicos potencializam a sedación e podem prolongar a recuperação anestésica da cetamina',
    'Sedación prolongada e riesgo de depresión respiratoria no período pós-operatório imediato',
    'Reducir la dosis de cetamina quando usada em combinación com benzodiazepínicos. Monitorar recuperação',
    'SEDAÇÃO PROLONGADA — Reducir dosis de cetamina',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),

  ('cetamina', 'teofilina', InteractionSeverity.major,
    'Interacción farmacodinâmica: ambos podem reduzir o limiar convulsivo por mecanismos diferentes',
    'Riesgo aumentado de convulsiones intraoperatórias ou no período de recuperação anestésica',
    'Evitar la combinación en pacientes asmáticos usando teofilina que necessitem de cetamina como anestésico',
    'RISCO DE CONVULSIONES — Evitar combinación',
    EvidenceLevel.probable,
    {RiskType.seizure, RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('cetamina', 'lítio', InteractionSeverity.moderate,
    'O lítio pode prolongar a duración do bloqueio neuromuscular e potenciar os efectos anestésicos da cetamina',
    'Recuperação anestésica prolongada e posible potenciação dos efectos dissociativos',
    'Monitorar cuidadosamente a recuperação en pacientes com lítio submetidos à anestesia com cetamina',
    'RECUPERAÇÃO ANESTÉSICA PROLONGADA — Monitorar',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefMdx, _kRefUT]),

  // ── Tireoide ──────────────────────────────────────────────────────────────────

  ('propiltiouracil', 'varfarina', InteractionSeverity.major,
    'O hipotiroidismo induzido pelo propiltiouracil altera o metabolismo dos fatores de coagulação e pode potencializar o efecto da varfarina',
    'Riesgo aumentado de sangrado com elevación del INR conforme o paciente torna-se eutireóideo',
    'Monitorar INR frecuentemente durante o inicio e ajuste da dosis de propiltiouracil',
    'ELEVAÇÃO DO INR — Monitorar rigurosamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('propiltiouracil', 'metformina', InteractionSeverity.minor,
    'O hipotiroidismo pode reduzir o aclaramiento renal da metformina e alterar o metabolismo de la glicose',
    'Posible alteração no controle glicêmico e riesgo leve de acumulación de metformina',
    'Monitorar a glucemia e función renal durante o ajuste da dosis de propiltiouracil',
    'MONITORAR GLICEMIA — Interacción indireta via función tiroidiana',
    EvidenceLevel.possible,
    {RiskType.other},
    [_kRefMdx]),

  ('propiltiouracil', 'digoxina', InteractionSeverity.moderate,
    'O hipotiroidismo altera o volume de distribuição e o clearance da digoxina',
    'Aumento dos niveles séricos de digoxina com riesgo de toxicidad digitálica (bradiarritmias, náuseas)',
    'Monitorar niveles de digoxina ao ajustar la dosis de propiltiouracil durante o tratamiento do hipertiroidismo',
    'TOXICIDAD DIGITÁLICA — Monitorar digoxinemia',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  // ── Diuréticos ────────────────────────────────────────────────────────────────

  ('espironolactona', 'acido acetilsalicilico', InteractionSeverity.moderate,
    'O ácido acetilsalicílico em altas dosiss pode antagonizar o efecto natriurético da espironolactona por inhibición das prostaglandinas renais',
    'Reducción de la eficacia diurética da espironolactona, podendo agravar edema e insuficiencia cardíaca',
    'Evitar aspirina em dosis altas en pacientes com insuficiencia cardíaca usando espironolactona. Dosis bajas (100mg) são generalmente seguras',
    'EFICÁCIA DIURÉTICA REDUZIDA — Evitar AAS em altas dosiss',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  ('espironolactona', 'trimetoprima', InteractionSeverity.major,
    'A trimetoprima bloqueia os canais epiteliais de sódio no néfron distal, semelhante à amilorida, causando retenção de potássio',
    'Hiperpotasemia grave, especialmente en ancianos, pacientes com IRC ou em uso de outros poupadores de potássio',
    'Monitorar potássio sérico al iniciar a trimetoprima en pacientes usando espironolactona',
    'HIPERPOTASEMIA GRAVE — Monitorar potássio sérico',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),

  ('espironolactona', 'heparina', InteractionSeverity.moderate,
    'A heparina inibe a síntese de aldosterona nas adrenais, potencializando o efecto antialdosterônico da espironolactona',
    'Hiperpotasemia significativa, especialmente en pacientes com insuficiencia renal',
    'Monitorar potássio sérico frecuentemente en pacientes anticoagulados com heparina usando espironolactona',
    'HIPERPOTASEMIA ADITIVA — Monitorar electrolitos',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.electrolyte},
    [_kRefGG, _kRefMdx]),

  // ── EII: Enfermedad Inflamatória Intestinal ──────────────────────────────────────

  ('mesalazina', 'varfarina', InteractionSeverity.moderate,
    'A mesalazina pode potenciar o efecto anticoagulante da varfarina por mecanismo não completamente elucidado',
    'Elevación del INR y riesgo de sangrado, incluindo hemorragia gastrointestinal',
    'Monitorar INR regularmente al iniciar ou alterar a dosis de mesalazina en pacientes anticoagulados',
    'MONITORAR INR — Riesgo de sangrado GI',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefMdx, _kRefUT]),

  ('mesalazina', 'mercaptopurina', InteractionSeverity.major,
    'A mesalazina inibe a tiopurina metiltransferase (TPMT), enzima responsável pela inativação da mercaptopurina',
    'Acumulación de metabólitos tóxicos da mercaptopurina, causando mielosupresión grave',
    'Monitorar hemograma completo com atención. Reducir la dosis de mercaptopurina se necesario',
    'MIELOSUPRESIÓN GRAVE — Monitorar hemograma',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  ('sulfassalazina', 'digoxina', InteractionSeverity.moderate,
    'A sulfassalazina pode reduzir a absorción da digoxina por mecanismos gastrointestinais',
    'Reducción dos niveles séricos de digoxina, com posible perda do efecto terapéutico',
    'Monitorar niveles de digoxina al iniciar ou suspender sulfassalazina',
    'NÍVEL DE DIGOXINA REDUZIDO — Monitorar',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefMdx]),

  ('sulfassalazina', 'metotrexato', InteractionSeverity.moderate,
    'Ambos podem causar supresión da medula óssea e hepatotoxicidad, além de competição pela excreción renal',
    'Riesgo aumentado de leucopenia, trombocitopenia e hepatotoxicidad aditiva',
    'Monitorar hemograma e enzimas hepáticas regularmente. A combinación é usada em reumatologia sob supervisão',
    'TOXICIDADE HEMATOLÓGICA E HEPÁTICA ADITIVA — Monitorar',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx]),

  ('budesonida', 'cetoconazol', InteractionSeverity.major,
    'O cetoconazol inibe o CYP3A4, a principal vía de metabolismo de la budesonida',
    'Aumento significativo dos niveles sistêmicos de budesonida, com riesgo de supresión do eixo hipotálamo-hipófise-adrenal',
    'Evitar la combinación. Se necesario, reducir la dosis de budesonida e monitorar signos de hipercortisolismo',
    'EFEITO SISTÊMICO DO CORTICOIDE — Evitar inhibidores potentes de CYP3A4',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('budesonida', 'ritonavir', InteractionSeverity.major,
    'O ritonavir é inhibidor extremamente potente do CYP3A4, bloqueando quase completamente o metabolismo de primeira passagem da budesonida',
    'Síndrome de Cushing iatrogênica com supresión adrenal grave e insuficiencia adrenal ao suspender',
    'Combinación contraindicada. Usar alternativas que não dependam do CYP3A4 ou ajustar para dosis mínimas com monitoramento',
    'CUSHING IATROGÊNICO — Contraindicado com ritonavir',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefFDA, _kRefMdx]),

  // ── Biológicos: Imunobiológicos ───────────────────────────────────────────────

  ('ustekinumabe', 'vacinas vivas', InteractionSeverity.major,
    'O ustekinumabe suprime a resposta imune via bloqueio de IL-12/23, podendo impedir resposta protetora à vacina',
    'Riesgo de infecção ativa pela cepa vacinal e resposta imune inadecuada',
    'Evitar vacinas vivas durante o tratamiento. Completar vacinação antes de iniciar o ustekinumabe',
    'RISCO DE INFECÇÃO VACINAL — Evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefUT]),

  ('ustekinumabe', 'tofacitinibe', InteractionSeverity.contraindicated,
    'Imunossupresión sinérgica por bloqueio de IL-12/23 e inhibición de JAK',
    'Riesgo inaceitável de infecções oportunistas letais sem benefício clínico adicional comprovado',
    'Nunca combinar dois imunobiológicos ou biológico + inhibidor de JAK',
    'IMUNOSSUPRESSÃO LETAL — Absolutamente contraindicado',
    EvidenceLevel.established,
    {RiskType.infection, RiskType.increasedToxicity},
    [_kRefFDA, _kRefUT]),

  ('secuquinumabe', 'vacinas vivas', InteractionSeverity.major,
    'Bloqueio de IL-17A pelo secuquinumabe compromete a imunidade inata antifúngica e antiviral',
    'Riesgo de enfermedad ativa por cepa vacinal e candidosis mucocutânea recorrente',
    'Evitar vacinas vivas. Rastrear candidosis oral durante o tratamiento',
    'RISCO INFECCIOSO — Evitar vacinas vivas e monitorar candidosis',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefMdx]),

  ('secuquinumabe', 'infliximabe', InteractionSeverity.contraindicated,
    'Dupla imunossupresión biológica sistêmica: bloqueio de IL-17 + bloqueio de TNF-alfa',
    'Riesgo extremo de infecções oportunistas, sepse, tuberculose ativa e vasculite',
    'Absolutamente contraindicado combinar dois biológicos sistêmicos',
    'IMUNOSSUPRESSÃO FATAL — Contraindicado',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG]),

  ('ixequizumabe', 'vacinas vivas', InteractionSeverity.major,
    'O bloqueio de IL-17A pelo ixequizumabe compromete a resposta imune adaptativa contra patógenos atenuados',
    'Riesgo de infecção ativa pela cepa vacinal e resposta vacinal inadecuada',
    'Evitar vacinas vivas durante o tratamiento com ixequizumabe',
    'RISCO DE INFECÇÃO VACINAL — Evitar vacinas vivas',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA]),

  ('risanquizumabe', 'vacinas vivas', InteractionSeverity.major,
    'O risanquizumabe bloqueia a subunidade p19 da IL-23, afetando a imunidade celular adaptativa',
    'Riesgo de infecção ativa por cepas vacinais vivas',
    'Evitar vacinas vivas atenuadas durante todo o período de tratamiento',
    'RISCO INFECCIOSO VACINAL — Contraindicado com vacinas vivas',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA]),

  // ── Deslipidemias: Inhibidores de PCSK9 e Ezetimiba ───────────────────────────

  ('evolocumabe', 'estatina', InteractionSeverity.minor,
    'Os inhibidores de PCSK9 são usados como adjuvantes às estatinas para reducción del LDL',
    'Quando combinados, podem ocorrer miopatías em casos raros, embora o riesgo seja menor que com fibratos',
    'Monitorar CK e síntomas musculares. A combinación é a base do tratamiento de hipercolesterolemia grave',
    'MONITORAR MIALGIAS — Combinación generalmente segura e intencional',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefUT]),

  ('alirocumabe', 'estatina', InteractionSeverity.minor,
    'Os inhibidores de PCSK9 potencializam a reducción de LDL das estatinas de forma aditiva',
    'A combinación é generalmente segura, sin embargo pode ocorrer miopatía em casos raros',
    'Monitorar síntomas musculares e CK. A combinación é padrão de tratamiento para dislipidemia refratária',
    'MONITORAR MIALGIAS — Combinación usualmente segura',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefUT]),

  ('ezetimiba', 'ciclosporina', InteractionSeverity.major,
    'A ciclosporina inibe o transportador OATP1B1, aumentando drásticamente os niveles plasmáticos de ezetimiba e seu metabólito ativo',
    'Aumento de até 3 a 4 vezes na exposición à ezetimiba, com riesgo de efectos adversos aumentados',
    'Monitorar lipídios e enzimas hepáticas. Evitar dosis altas de ezetimiba en pacientes trasplantados',
    'AUMENTO DE EXPOSIÇÃO À EZETIMIBA — Monitorar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefMdx, _kRefFDA]),

  ('ezetimiba', 'colestiramina', InteractionSeverity.moderate,
    'A colestiramina pode reduzir a absorción da ezetimiba ao sequestrar o fármaco no intestino',
    'Reducción de la eficacia hipolipemiante da ezetimiba',
    'Administrar a ezetimiba pelo menos 2 horas antes ou 4 horas después de a colestiramina',
    'ABSORÇÃO REDUZIDA — Espaçar dosiss',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefMdx]),

  ('acido nicotinico', 'estatina', InteractionSeverity.moderate,
    'A combinación de ácido nicotínico com estatinas aumenta o riesgo de miopatía',
    'Riesgo de miopatía e rabdomiólisis, especialmente com sinvastatina em dosis altas',
    'Monitorar CK e síntomas musculares. Evitar niacina em dosis altas com estatinas em dosiss máximas',
    'RISCO DE MIOPATIA — Monitorar CK',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefGG, _kRefMdx]),

  ('acido nicotinico', 'antidiabetico', InteractionSeverity.moderate,
    'A niacina em altas dosiss causa resistência insulínica e hiperglucemia',
    'Perda do controle glicêmico en pacientes diabéticos, podendo requerer ajuste da medicação',
    'Monitorar glucemia al iniciar niacina em dosis altas en pacientes diabéticos',
    'HIPERGLICEMIA — Monitorar controle glicêmico',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),

  // ── INTERACCIONES NUEVAS ─────────────────────────────────────────────────

  // 1. Metformina + Contraste Iodado → Acidosis Láctica
  ('metformina', 'contraste iodado',
    InteractionSeverity.major,
    'El contraste iodado puede causar insuficiencia renal aguda transitoria; la metformina se acumula cuando el aclaramiento renal cae, con riesgo de acidosis láctica por bloqueo de la cadena respiratoria mitocondrial',
    'Acidosis láctica potencialmente fatal (mortalidad ~50%): náuseas, vómitos, dolor abdominal, hiperventilación, confusión, colapso hemodinámico',
    'Suspender metformina 48 h antes del procedimiento con contraste IV; reiniciar solo tras confirmar función renal normal (creatinina ≤ basal). En urgencias: hidratación vigorosa y monitoreo de lactato',
    'ACIDOSIS LÁCTICA — Suspender metformina 48 h antes del contraste IV',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // 2. Sertralina + Tramadol → Síndrome Serotoninérgico
  ('sertralina', 'tramadol',
    InteractionSeverity.major,
    'La sertralina inhibe la recaptación de serotonina (ISRS) y el tramadol actúa como inhibidor de la recaptación de serotonina/noradrenalina además de agonista opioide débil; la combinación produce hiperserotonemia por acumulación sinérgica de 5-HT sináptica',
    'Síndrome serotoninérgico: agitación, mioclonus, hiperreflexia, hipertermia, taquicardia, diaforesis, rigidez muscular; en casos graves: rabdomiólisis, CID, insuficiencia renal y muerte',
    'Evitar la combinación siempre que sea posible; si es imprescindible, usar la dosis mínima de tramadol con vigilancia estrecha. En síndrome serotoninérgico: suspender ambos fármacos, ciproheptadina 4–8 mg VO/SNG, soporte hemodinámico, benzodiacepinas para agitación y mioclonus',
    'SÍNDROME SEROTONINÉRGICO — Combinación de alto riesgo con tramadol',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefLex]),

  // 3. Digoxina + Amiodarona → Toxicidad Digitálica
  ('digoxina', 'amiodarona',
    InteractionSeverity.major,
    'La amiodarona inhibe la glucoproteína-P y la CYP3A4, reduciendo la eliminación renal y hepática de digoxina; el nivel plasmático de digoxina aumenta 70–100% en los primeros 7–14 días',
    'Toxicidad digitálica: náuseas, vómitos, visión con halos amarillo-verdosos, bradicardia, bloqueos AV de alto grado, arritmias ventriculares (TV bidireccional), trastornos del potasio',
    'Reducir la dosis de digoxina a la mitad al iniciar amiodarona; monitorear niveles de digoxina (objetivo 0,5–0,9 ng/mL) al 3.°, 7.° y 14.° día; ajustar según niveles y función renal; vigilar potasio sérico (hipopotasemia potencia toxicidad)',
    'TOXICIDAD DIGITÁLICA — Reducir dosis de digoxina 50% al agregar amiodarona',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefKatz, _kRefMdx, _kRefUT]),

  // ═══════════════════════════════════════════════════════════════════════════
  // LOTE 300 INTERACCIONES — Fármacos nuevos × base existente
  // Fuentes: UpToDate 2024, Goodman & Gilman 14ª, Micromedex 2024, IDSA
  // ═══════════════════════════════════════════════════════════════════════════

  // ── SECCIÓN 1: Paxlovid (Nirmatrelvir+Ritonavir) ─────────────────────────

  // 1
  ('paxlovid', 'opioide',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe potentemente CYP3A4, bloqueando el metabolismo de opioides como oxicodona, hidromorfona y tapentadol; la exposición plasmática al opioide aumenta hasta 10 veces',
    'Sobredosis opioide: depresión respiratoria fatal, coma, miosis puntiforme, hipotensión severa',
    'Contraindicado. Suspender el opioide antes de iniciar Paxlovid o cambiar a fármaco no metabolizado por CYP3A4 (ej. morfina, hidromorfona parche)',
    'SOBREDOSIS OPIOIDE — Depresión respiratoria fatal con opioides + Paxlovid',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns, RiskType.plasmaLevel},
    [_kRefUT, _kRefMdx, _kRefFDA]),

  // 2
  ('paxlovid', 'lurasidona',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe CYP3A4 — única vía de metabolismo de la lurasidona — elevando sus niveles plasmáticos de forma masiva e incontrolable',
    'Toxicidad neurológica grave, arritmias ventriculares por prolongación del QT, sedación profunda e hipotensión crítica',
    'Contraindicación absoluta. Suspender lurasidona antes de iniciar Paxlovid. Cambiar temporalmente a quetiapina a dosis reducida bajo monitoreo cardiológico',
    'CONTRAINDICADO — Riesgo de arritmia y toxicidad neurológica grave con lurasidona',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // 3
  ('paxlovid', 'pimavanserina',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe CYP3A4, la principal vía de eliminación de pimavanserina; la acumulación del antipsicótico prolonga el intervalo QTc de forma crítica',
    'Arritmias ventriculares letales: Torsades de Pointes, fibrilación ventricular y muerte súbita cardíaca',
    'Contraindicado de forma absoluta. No coadministrar bajo ninguna circunstancia',
    'CONTRAINDICADO — Riesgo de muerte por Torsades de Pointes',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  // 4
  ('paxlovid', 'sinvastatina',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe extremadamente CYP3A4 y OATP1B1; la simvastatina es un sustrato con margen terapéutico estrecho → niveles séricos aumentan >30 veces',
    'Rabdomiólisis fulminante: mioglobinuria, insuficiencia renal aguda, hiperpotasemia fatal',
    'Contraindicado. Suspender simvastatina/lovastatina en cuanto se inicia Paxlovid. Reanudar 2 días después de finalizar el tratamiento antiviral',
    'CONTRAINDICADO — Rabdomiólisis inminente con simvastatina + Paxlovid',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // 5
  ('paxlovid', 'midazolam',
    InteractionSeverity.contraindicated,
    'Ritonavir bloquea el metabolismo de primer paso del midazolam oral por CYP3A4; el AUC del midazolam oral aumenta >400 veces',
    'Sedación profunda prolongada, apnea, coma e insuficiencia respiratoria fatal',
    'Contraindicado con midazolam oral/sublingual. El midazolam IV puede usarse con cautela extrema en UCI bajo ventilación mecánica y monitoreo continuo',
    'CONTRAINDICADO — Apnea por midazolam oral con Paxlovid',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  // 6
  ('paxlovid', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe CYP3A4 y P-gp, reduciendo el aclaramiento de amiodarona y su metabolito activo DEA; acumulación a niveles tóxicos con vida media >40 días',
    'Arritmias letales por toxicidad por amiodarona: TV polimórfica, FV, bradiarritmias graves, toxicidad pulmonar y hepática acelerada',
    'Contraindicación absoluta documentada en la ficha técnica de Paxlovid. No coadministrar bajo ninguna circunstancia',
    'CONTRAINDICADO — Riesgo de muerte por acumulación de amiodarona',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx, _kRefUT]),

  // 7
  ('paxlovid', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina es el inductor más potente de CYP3A4 y P-gp; reduce los niveles de nirmatrelvir/ritonavir >90%, anulando por completo la actividad antiviral',
    'Fracaso terapéutico total del tratamiento COVID-19, riesgo de selección de variantes resistentes',
    'Contraindicación absoluta. Suspender rifampicina antes de iniciar Paxlovid. Considerar regímenes alternativos antituberculosos sin rifampicina durante el tratamiento antiviral',
    'CONTRAINDICADO — Rifampicina anula eficacia de Paxlovid completamente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 8
  ('paxlovid', 'carbamazepina',
    InteractionSeverity.contraindicated,
    'Carbamazepina induce fuertemente CYP3A4 (y se autoiduce) reduciendo los niveles de nirmatrelvir/ritonavir por debajo del umbral terapéutico',
    'Fracaso antiviral: los niveles de nirmatrelvir caen hasta un 87% con carbamazepina',
    'Contraindicado. Cambiar temporalmente el anticonvulsivo a levetiracetam o lamotrigina durante el tratamiento con Paxlovid',
    'CONTRAINDICADO — Carbamazepina elimina eficacia de Paxlovid',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefMdx]),

  // 9
  ('paxlovid', 'ranolazina',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe CYP3A4 y P-gp, duplicando o triplicando los niveles de ranolazina con riesgo de Torsades de Pointes',
    'Prolongación crítica del QT, taquicardia ventricular polimórfica y muerte súbita',
    'Contraindicado según ficha técnica de Paxlovid. Suspender ranolazina durante el tratamiento antiviral',
    'CONTRAINDICADO — Arritmia ventricular fatal por ranolazina acumulada',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA]),

  // 10
  ('paxlovid', 'ergotamina',
    InteractionSeverity.contraindicated,
    'Ritonavir inhibe el metabolismo de la ergotamina por CYP3A4; la acumulación del alcaloide produce vasoconstricción arterial periférica extrema',
    'Ergotismo agudo: isquemia de extremidades, gangrena digital, angina mesentérica, accidente cerebrovascular por vasoespasmo',
    'Contraindicado. Suspender ergotamina antes de Paxlovid. Para cefalea usar gepantes o triptanes (con monitoreo)',
    'CONTRAINDICADO — Ergotismo agudo con riesgo de gangrena isquémica',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.other},
    [_kRefFDA, _kRefMdx]),

  // 11
  ('paxlovid', 'tramadol',
    InteractionSeverity.major,
    'Ritonavir puede aumentar la exposición al tramadol vía CYP3A4; además, la inhibición de CYP2D6 puede reducir la conversión a M1 pero aumentar el tramadol parental con riesgo convulsivo y serotoninérgico',
    'Convulsiones, síndrome serotoninérgico, toxicidad opioide aumentada',
    'Evitar si es posible. Si es inevitable, usar dosis mínima de tramadol con monitoreo neurológico estricto durante los 5 días de Paxlovid',
    'ALTO RIESGO — Convulsiones y toxicidad serotoninérgica con tramadol',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.seizure, RiskType.cns},
    [_kRefUT, _kRefMdx]),

  // 12
  ('paxlovid', 'atorvastatina',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4 y OATP1B1; los niveles de atorvastatina aumentan hasta 9 veces',
    'Miopatía grave, elevación marcada de CPK, riesgo de rabdomiólisis subclínica',
    'Suspender atorvastatina durante los 5 días de Paxlovid y por 2 días adicionales. Reanudar con CPK de control. Si el paciente no puede suspenderla, usar dosis mínima (10 mg) con monitoreo clínico diario',
    'SUSPENDER ESTATINA — Atorvastatina durante tratamiento con Paxlovid',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 13
  ('paxlovid', 'warfarina',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP2C9 (metabolismo de la S-warfarina) y CYP3A4 (R-warfarina); efecto neto impredecible sobre el INR — puede aumentar o disminuir',
    'Elevación del INR con riesgo de hemorragia mayor o, paradójicamente, descenso con riesgo trombótico',
    'Medir INR antes de iniciar, al día 2–3 y al finalizar Paxlovid. Ajustar dosis de warfarina según resultados. Informar al paciente sobre signos de sangrado y trombosis',
    'MONITOREO DIARIO DE INR — Interacción imprevisible con warfarina',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // 14
  ('paxlovid', 'rivaroxabana',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4 y P-gp, ambas vías principales de eliminación de rivaroxabán; el AUC del anticoagulante puede aumentar hasta un 160%',
    'Sangrado mayor: hemorragia intracraneal, gastrointestinal masiva, hematomas musculares extensos',
    'Evitar la combinación si el riesgo hemorrágico del paciente es alto. Si es inevitable, reducir dosis de rivaroxabán o cambiar temporalmente a heparina de bajo peso molecular durante los 5 días de Paxlovid',
    'ALTO RIESGO DE SANGRADO — Rivaroxabán acumulado con Paxlovid',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 15
  ('paxlovid', 'ticagrelor',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4, la principal vía de metabolismo del ticagrelor; los niveles plasmáticos aumentan marcadamente',
    'Hemorragia mayor espontánea: epistaxis, equimosis masivas, sangrado gastrointestinal alto',
    'Considerar suspensión temporal del ticagrelor durante Paxlovid si el riesgo hemorrágico supera el trombótico. Alternativa: clopidogrel (no afectado por CYP3A4 para su metabolismo). Monitorizar signos de sangrado activamente',
    'HEMORRAGIA MAYOR — Ticagrelor acumulado con Paxlovid',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 16
  ('paxlovid', 'diltiazem',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4; el diltiazem es sustrato e inhibidor moderado de CYP3A4 → acumulación bidireccional de ambos fármacos con efectos sobre el nódulo AV',
    'Bradicardia sinusal severa, bloqueo AV de 2.°-3.° grado, hipotensión profunda',
    'Monitoreo electrocardiográfico y de PA durante los 5 días de Paxlovid. Reducir dosis de diltiazem al 50%. Considerar pausa del diltiazem si clínicamente posible',
    'BRADICARDIA GRAVE — Reducir dosis de diltiazem durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefUT]),

  // 17
  ('paxlovid', 'quetiapina',
    InteractionSeverity.major,
    'Ritonavir inhibe CYP3A4, única vía de metabolismo de la quetiapina; los niveles aumentan hasta 6 veces',
    'Sedación extrema, hipotensión ortostática severa con síncope, prolongación del QT',
    'Reducir dosis de quetiapina al mínimo terapéutico (25-50 mg) durante los 5 días de Paxlovid. Monitorizar ECG y presión arterial. Reanudar dosis habitual al finalizar el antiviral',
    'SEDACIÓN EXTREMA — Reducir quetiapina durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.cardiovascular, RiskType.qtProlongation},
    [_kRefFDA, _kRefUT]),

  // 18
  ('paxlovid', 'isrs',
    InteractionSeverity.major,
    'Ritonavir puede inhibir CYP2D6 y CYP3A4 dependiendo del ISRS específico (fluoxetina, paroxetina, sertralina, escitalopram); posible elevación de niveles de serotonina plasmática',
    'Síndrome serotoninérgico, náuseas, mareos, palpitaciones; monitorizar QT con escitalopram',
    'Monitorear estrechamente durante los 5 días. Para escitalopram: realizar ECG al día 2. Informar al paciente sobre signos de síndrome serotoninérgico',
    'MONITOREO ESTRECHO — ISRS + Paxlovid: riesgo serotoninérgico y QT',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.qtProlongation},
    [_kRefUT, _kRefMdx]),

  // 19
  ('paxlovid', 'fluticasona',
    InteractionSeverity.major,
    'Ritonavir inhibe intensamente CYP3A4; la fluticasona inhalada normalmente tiene biodisponibilidad sistémica <1%, pero la inhibición metabólica aumenta esta exposición hasta 50 veces',
    'Síndrome de Cushing iatrogénico, supresión del eje hipotálamo-hipófiso-adrenal (HHA), insuficiencia adrenal secundaria al suspender el corticoide',
    'Considerar cambiar temporalmente a beclometasona (menor interacción con CYP3A4). Si no es posible, informar al paciente sobre síntomas de supresión adrenal. No suspender abruptamente tras el tratamiento',
    'SÍNDROME DE CUSHING — Fluticasona acumulada con Paxlovid: monitorear',
    EvidenceLevel.established,
    {RiskType.other, RiskType.increasedToxicity},
    [_kRefFDA, _kRefUT]),

  // 20
  ('paxlovid', 'digoxina',
    InteractionSeverity.major,
    'Ritonavir inhibe la P-glucoproteína intestinal y renal, reduciendo la eliminación de digoxina; los niveles séricos aumentan 25-75%',
    'Toxicidad digitálica: náuseas, bradicardia, bloqueo AV, arritmias ventriculares, visión en halos',
    'Medir niveles de digoxina antes de iniciar Paxlovid y al día 3. Reducir dosis de digoxina empíricamente al 50-75%. Monitorear ECG y electrolitos (K+)',
    'TOXICIDAD DIGITÁLICA — Medir digoxinemia antes y durante Paxlovid',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // ── SECCIÓN 2: Antipsicóticos nuevos (Lurasidona, Asenapina, etc.) ─────────

  // 21
  ('lurasidona', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe potentemente CYP3A4, única vía metabólica de la lurasidona; los niveles aumentan hasta 9 veces',
    'Toxicidad neurológica grave, sedación profunda, hipotensión severa, prolongación del QT',
    'Contraindicado según ficha técnica de lurasidona. Usar azitromicina (no inhibe CYP3A4 significativamente) como alternativa antibiótica',
    'CONTRAINDICADO — Lurasidona + Claritromicina: toxicidad neurológica grave',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel, RiskType.cns},
    [_kRefFDA, _kRefMdx]),

  // 22
  ('lurasidona', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina, carbamazepina, fenitoína y fenobarbital inducen fuertemente CYP3A4; los niveles de lurasidona se reducen hasta un 80%',
    'Fracaso terapéutico total: recaída psicótica o maníaca por niveles subterapéuticos del antipsicótico',
    'Contraindicado según ficha técnica. Cambiar a antipsicótico no dependiente de CYP3A4 (haloperidol, risperidona) durante el uso del inductor',
    'FRACASO TERAPÉUTICO — Inductores enzimáticos anulan efecto de lurasidona',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 23
  ('lurasidona', 'fluconazol',
    InteractionSeverity.contraindicated,
    'Fluconazol (inhibidor moderado de CYP3A4 y potente de CYP2C19) duplica los niveles plasmáticos de lurasidona de forma sostenida',
    'Sedación excesiva, hipotensión ortostática, prolongación del QTc con riesgo de arritmia',
    'Contraindicado. Cambiar a itraconazol tópico u otro antifúngico sin efecto sobre CYP3A4',
    'CONTRAINDICADO — Fluconazol duplica niveles de lurasidona',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation},
    [_kRefFDA]),

  // 24
  ('lurasidona', 'metoclopramida',
    InteractionSeverity.major,
    'Ambos fármacos antagonizan receptores dopaminérgicos D2 de forma aditiva; la suma del bloqueo dopaminérgico central supera el umbral de toxicidad extrapiramidal',
    'Distonías agudas dolorosas (crisis oculogira, tortícolis), acatisia intensa, parkinsonismo farmacológico',
    'Evitar la combinación. Si se necesita antiemético, preferir ondansetrona o domperidona (actúa periféricamente). Si ya ocurrió distonía: difenhidramina 25-50 mg IV',
    'DISTONÍA AGUDA — Bloqueo dopaminérgico aditivo con metoclopramida',
    EvidenceLevel.established,
    {RiskType.other, RiskType.increasedToxicity},
    [_kRefGG, _kRefUT]),

  // 25
  ('clozapina', 'ciprofloxacino',
    InteractionSeverity.contraindicated,
    'Ciprofloxacino inhibe fuertemente CYP1A2, principal vía de metabolismo de la clozapina; los niveles plasmáticos pueden aumentar 3-5 veces en 24-48 horas',
    'Toxicidad por clozapina: convulsiones tónico-clónicas generalizadas, colapso circulatorio, agranulocitosis acelerada, hipertermia',
    'Contraindicado. Usar antibiótico alternativo: amoxicilina-clavulánico, piperacilina-tazobactam, trimetoprim (sin sulfametoxazol en clozapina). Si se debe usar ciprofloxacino: reducir clozapina al 33% y medir niveles diariamente',
    'CONTRAINDICADO — Ciprofloxacino eleva clozapina: riesgo de convulsiones',
    EvidenceLevel.established,
    {RiskType.seizure, RiskType.plasmaLevel, RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 26
  ('clozapina', 'benzodiazepínico',
    InteractionSeverity.major,
    'La clozapina produce sedación, hipotensión y depresión respiratoria; las benzodiazepinas suman efectos depresores del SNC de forma sinérgica y no aditiva',
    'Colapso cardiorrespiratorio (especialmente en primeras dosis de clozapina): hipotensión severa, apnea, bradicardia, paro respiratorio',
    'Evitar la coadministración al inicio de clozapina. Si es imprescindible: usar dosis mínima de BZD (lorazepam 0.5 mg máx), con equipo de reanimación disponible y monitoreo continuo de O2 y PA por 4 horas tras la dosis',
    'COLAPSO CARDIORRESPIRATORIO — Evitar benzodiacepinas con clozapina al inicio',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cardiovascular, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefLex]),

  // 27
  ('clozapina', 'haloperidol',
    InteractionSeverity.major,
    'Ambos antipsicóticos tienen propiedades que aumentan el riesgo del Síndrome Neuroléptico Maligno; la combinación potencia el bloqueo dopaminérgico nigroestriatal y el estrés hipotalámico',
    'Síndrome Neuroléptico Maligno: hipertermia >40°C, rigidez muscular generalizada, inestabilidad autonómica, alteración de conciencia, rabdomiólisis, CPK >10.000 U/L',
    'Evitar la politerapia antipsicótica. Si es necesaria la clozapina + otro antipsicótico, preferir aripiprazol (menor bloqueo D2 puro). Informar sobre síntomas del SNM. Monitorear temperatura, CPK y función renal',
    'SÍNDROME NEUROLÉPTICO MALIGNO — Evitar combinación clozapina + haloperidol',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.other},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 28
  ('ziprasidona', 'amiodarona',
    InteractionSeverity.major,
    'Ziprasidona prolonga el QTc de forma dependiente de dosis; la amiodarona prolonga el QT por bloqueo de canales hERR/KCNH2; efecto aditivo crítico',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita cardíaca',
    'Evitar la combinación. Cambiar ziprasidona a haloperidol o risperidona si el paciente requiere amiodarona crónicamente. Si no es posible: ECG antes de iniciar, QTc basal <450 ms, monitoreo ECG cada 48 h',
    'TORSADES DE POINTES — Combinación arritmogénica crítica ziprasidona + amiodarona',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 29
  ('ziprasidona', 'ondansetrona',
    InteractionSeverity.major,
    'Ambos fármacos prolongan el intervalo QTc: ziprasidona bloquea canales de potasio hERG y ondansetrona inhibe canales iKr de forma aditiva',
    'Prolongación del QTc con riesgo de Torsades de Pointes, especialmente en presencia de hipopotasemia o hipomagnesemia',
    'Monitorear ECG antes y durante la combinación. Corregir electrolitos (K+ objetivo >4.0 mEq/L, Mg2+ >2.0 mg/dL). Considerar metoclopramida como antiemético alternativo',
    'PROLONGACIÓN QT — Monitoreo ECG obligatorio con ziprasidona + ondansetrona',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefMdx, _kRefUT]),

  // 30
  ('quetiapina', 'claritromicina',
    InteractionSeverity.major,
    'Claritromicina inhibe CYP3A4; los niveles de quetiapina aumentan 4-6 veces con riesgo de toxicidad severa',
    'Sedación extrema, hipotensión ortostática, prolongación del QT, síncope',
    'Evitar la combinación. Usar azitromicina (menor interacción). Si es inevitable: reducir quetiapina al 25% de la dosis habitual y monitorear ECG y PA',
    'SEDACIÓN + QT — Claritromicina eleva quetiapina 4-6 veces',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.qtProlongation, RiskType.cardiovascular},
    [_kRefMdx, _kRefUT]),

  // ── SECCIÓN 3: Nuevos antidiabéticos (iSGLT2 y arGLP-1) ─────────────────

  // 31
  ('canagliflozina', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina induce fuertemente UGT1A9 y UGT2B4 (glucuronidación), principales vías de eliminación de la canagliflozina; los niveles plasmáticos caen hasta un 51%',
    'Fracaso terapéutico en el control glucémico, pérdida del efecto nefroprotector y cardioprotector del iSGLT2',
    'Aumentar dosis de canagliflozina a 300 mg/día (dosis máxima) durante el uso de rifampicina, o cambiar a otro antidiabético. Monitorear glucemia estrechamente',
    'FRACASO GLUCÉMICO — Rifampicina reduce canagliflozina a niveles subterapéuticos',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 32
  ('dapagliflozina', 'furosemida',
    InteractionSeverity.major,
    'Los iSGLT2 producen diuresis osmótica activa (glucosuria) y los diuréticos de asa producen natriuresis e hipopotasemia; la acción diurética es aditiva y sinérgica en la depleción de volumen',
    'Deshidratación severa, hipotensión ortostática con síncope, insuficiencia renal prerrenal aguda, hipopotasemia que puede precipitar arritmias',
    'Iniciar iSGLT2 con dosis reducida en pacientes con furosemida >40 mg/día. Instruir al paciente para beber líquidos abundantes, medir PA postural y suspender el iSGLT2 ante náuseas o vómitos. Controlar electrolitos al inicio y a las 2 semanas',
    'DESHIDRATACIÓN SEVERA — Potenciación diurética iSGLT2 + furosemida',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.nephrotoxicity, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 33
  ('dapagliflozina', 'enalapril',
    InteractionSeverity.major,
    'Los iSGLT2 reducen la precarga renal (diuresis osmótica) y los IECAs dilatan la arteriola eferente; la combinación puede comprometer agudamente la TFG, especialmente al inicio',
    'Caída aguda de la TFG (hipoperfusión glomerular): insuficiencia renal aguda funcional, hiperpotasemia',
    'Monitorear creatinina sérica y potasio a los 7 y 14 días del inicio de la combinación. Instruir al paciente para suspender el iSGLT2 ante episodios febriles, diarrea o reducción drástica de ingesta hídrica (riesgo de cetoacidosis euglicémica)',
    'INSUFICIENCIA RENAL AGUDA — Monitorear TFG y K+ al combinar iSGLT2 + IECA',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.hyperkalemia},
    [_kRefUT, _kRefGG]),

  // 34
  ('dapagliflozina', 'insulina',
    InteractionSeverity.major,
    'Los iSGLT2 potencian el efecto hipoglucemiante de la insulina al aumentar la glucosuria y reducir la glucemia en 1-2 mmol/L adicionales; la glucemia basal en la que ocurre hipoglucemia se anticipa',
    'Hipoglucemia grave, especialmente nocturna; riesgo de cetoacidosis euglicémica (glucemia normal pero cetonas elevadas)',
    'Reducir la dosis de insulina basal un 20% al iniciar el iSGLT2. Instruir al paciente sobre el riesgo de cetoacidosis euglicémica: medir cetonas si hay síntomas aunque la glucemia sea normal. Suspender el iSGLT2 24-48 h antes de cirugía electiva',
    'HIPOGLICEMIA Y CETOACIDOSIS — Reducir insulina 20% al iniciar iSGLT2',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.other},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 35
  ('dapagliflozina', 'glibenclamida',
    InteractionSeverity.major,
    'La combinación de iSGLT2 (que reduce glucemia ~1-2 mmol/L) con secretagogos de insulina (sulfonilureas) que liberan insulina de forma glucosa-independiente produce hipoglucemia sinérgica',
    'Hipoglucemia grave, especialmente postprandial tardía y nocturna; riesgo aumentado en pacientes >65 años o con IRC',
    'Reducir dosis de la sulfonilurea al 50% al iniciar el iSGLT2. Instruir al paciente para reconocer hipoglucemia. Monitorear glucemia en ayunas durante las primeras 2 semanas. Considerar cambiar la sulfonilurea a inhibidor de DPP-4',
    'HIPOGLUCEMIA GRAVE — Reducir sulfonilurea 50% al agregar iSGLT2',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 36
  ('liraglutida', 'insulina',
    InteractionSeverity.major,
    'Los arGLP-1 estimulan la secreción de insulina de forma glucosa-dependiente y ralentizan el vaciamiento gástrico; la combinación con insulina basal tiene riesgo de hipoglucemia, aunque la interacción es glucose-dependiente',
    'Hipoglucemia grave principalmente nocturna; pérdida de peso marcada con liraglutida puede requerir ajustes continuos de insulina',
    'Reducir insulina basal 20% al iniciar el arGLP-1. Monitorear glucemia en ayunas diariamente las primeras 4 semanas. Ajustar dosis progresivamente según respuesta glucémica real',
    'HIPOGLICEMIA — Reducir insulina basal al iniciar arGLP-1 (liraglutida, semaglutida)',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 37
  ('liraglutida', 'warfarina',
    InteractionSeverity.major,
    'El retraso del vaciamiento gástrico inducido por los arGLP-1 altera la absorción de warfarina (pico de Cmax y Tmax retrasados); los cambios en el INR son impredecibles',
    'Riesgo de hemorragia mayor por elevación inesperada del INR o de trombosis por descenso del INR',
    'Medir INR a los 3-5 días del inicio del arGLP-1 y tras cada cambio de dosis. Instruir al paciente sobre signos de sangrado (heces oscuras, equimosis inexplicables)',
    'MONITOREO INR — Aripiprazol GLP-1 altera absorción de warfarina',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefMdx]),

  // 38
  ('liraglutida', 'glibenclamida',
    InteractionSeverity.major,
    'Los arGLP-1 aumentan la sensibilidad insulínica y potencian la secreción de insulina; las sulfonilureas liberan insulina de forma fija e independiente de la glucosa',
    'Hipoglucemia grave y prolongada; el riesgo es mayor en pacientes con IRC, ancianos o con ingesta irregular',
    'Reducir dosis de sulfonilurea al 50% al agregar el arGLP-1. Preferir gliclazida MR (menor duración de hipoglucemia) sobre glibenclamida. Monitorear glucemia 2 h post-desayuno',
    'HIPOGLICEMIA — Reducir sulfonilurea 50% al agregar arGLP-1',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefUT]),

  // ── SECCIÓN 4: Triptanes, gepantes y monoclonales para cefaleas ───────────

  // 39
  ('sumatriptano', 'isrs',
    InteractionSeverity.major,
    'Ambos potencian la neurotransmisión serotoninérgica central: los ISRS/IRSN inhiben la recaptación de 5-HT; los triptanes activan receptores 5-HT1B/1D presinápticos y pueden aumentar la liberación de serotonina en el rafe dorsal',
    'Síndrome serotoninérgico moderado-severo: agitación, mioclonus, hiperreflexia, hipertermia, diaforesis, taquicardia; en casos graves: rabdomiólisis y CID',
    'La FDA emitió advertencia en 2010 pero evidencia actual sugiere que el riesgo es bajo con uso esporádico de triptanes a dosis habituales. Informar sobre síntomas de síndrome serotoninérgico. Evitar uso repetido frecuente de triptanes en pacientes con ISRS',
    'SÍNDROME SEROTONINÉRGICO — Triptanes + ISRS/IRSN: informar al paciente',
    EvidenceLevel.possible,
    {RiskType.serotonin},
    [_kRefFDA, _kRefUT, _kRefGG]),

  // 40
  ('sumatriptano', 'linezolida',
    InteractionSeverity.contraindicated,
    'Linezolida es un inhibidor reversible de la MAO (IMAO); bloquea la degradación de serotonina en la hendidura sináptica; los triptanes activan receptores 5-HT1 y pueden aumentar la liberación de 5-HT',
    'Síndrome serotoninérgico grave: hipertermia maligna, rigidez muscular, crisis hipertensiva, convulsiones, coma y muerte',
    'Contraindicado. No usar triptanes dentro de las 24 horas de linezolida. Para el tratamiento de la migraña aguda, considerar AINEs + antieméticos o paracetamol',
    'CONTRAINDICADO — Triptanes + Linezolida: síndrome serotoninérgico grave',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefFDA, _kRefMdx]),

  // 41
  ('eletriptano', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe intensamente CYP3A4, principal vía de metabolismo del eletriptán; los niveles plasmáticos aumentan hasta 5 veces',
    'Vasoespasmo coronario, opresión torácica severa, angina, isquemia miocárdica transitoria por activación de receptores 5-HT1B vasculares',
    'Contraindicado según ficha técnica del eletriptán. No usar eletriptán en las 72 horas siguientes a claritromicina. Usar sumatriptán (no metabolizado por CYP3A4) como alternativa',
    'CONTRAINDICADO — Eletriptán + Claritromicina: vasoespasmo coronario',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA]),

  // 42
  ('rimegepant', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe fuertemente CYP3A4, principal vía de metabolismo del rimegepant; el AUC del gepante aumenta más de 3 veces',
    'Toxicidad sistémica del gepante: nauseas severas, estreñimiento, elevación de transaminasas, efectos vasculares inesperados',
    'Contraindicado según ficha técnica de Nurtec (rimegepant). No usar otra dosis de rimegepant en las 48 h siguientes. Usar AINE o sumatriptán como alternativa',
    'CONTRAINDICADO — Rimegepant + Claritromicina: toxicidad del gepante triplicada',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefFDA]),

  // 43
  ('sumatriptano', 'tramadol',
    InteractionSeverity.contraindicated,
    'El tramadol inhibe la recaptación de serotonina y noradrenalina (mecanismo ISRN) y actúa como opioide débil; los triptanes activan receptores 5-HT1B/D; la combinación produce hiperserotonemia sinérgica',
    'Síndrome serotoninérgico grave: convulsiones, rigidez muscular, hipertermia >41°C, inestabilidad autonómica',
    'Contraindicado. Usar alternativas para la cefalea (AINEs, paracetamol, naproxeno). Si ya se administraron ambos y aparecen síntomas: ciproheptadina 4-8 mg y soporte intensivo',
    'CONTRAINDICADO — Triptanes + tramadol: síndrome serotoninérgico grave',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.seizure},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 44
  ('lasmiditano', 'benzodiazepínico',
    InteractionSeverity.major,
    'El lasmiditan actúa sobre receptores 5-HT1F y produce sedación y mareos significativos como efectos secundarios directos; las benzodiazepinas deprimen el SNC de forma sinérgica',
    'Somnolencia severa incapacitante, deterioro psicomotriz peligroso para la conducción de vehículos',
    'Evitar conducir durante al menos 8 horas después de la dosis de lasmiditan. Informar al paciente de la suma de sedación con BZD. Considerar sumatriptán o rimegepant como alternativas si el paciente toma BZD de forma crónica',
    'SEDACIÓN SEVERA — No conducir 8h tras lasmiditan; potenciado por BZD',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefFDA, _kRefUT]),

  // 45
  ('lasmiditano', 'propranolol',
    InteractionSeverity.major,
    'Propranolol reduce la eliminación de lasmiditan, aumentando sus niveles plasmáticos un 19%; la bradicardia basal por el betabloqueador se suma al efecto vagotónico del lasmiditan',
    'Bradicardia sinusal severa, mareo significativo, riesgo de síncope reflejo',
    'Reducir dosis de lasmiditan a 50 mg (dosis más baja disponible) en pacientes que toman propranolol. Monitorizar la frecuencia cardíaca tras la dosis',
    'BRADICARDIA — Reducir lasmiditan a 50 mg con propranolol',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA]),

  // 46
  ('rimegepant', 'fluconazol',
    InteractionSeverity.major,
    'Fluconazol inhibe CYP3A4 de forma moderada y CYP2C19 potentemente; aumenta el AUC del rimegepant hasta un 40-60%',
    'Aumento de efectos adversos del gepante: náuseas, estreñimiento, fatiga',
    'Reducir a la mitad la frecuencia de dosis de rimegepant. No usar más de una vez cada 96 horas con fluconazol. Considerar AINE o triptán alternativo',
    'TOXICIDAD AUMENTADA — Fluconazol eleva rimegepant 40-60%',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 47
  ('atogepant', 'claritromicina',
    InteractionSeverity.major,
    'Claritromicina inhibe CYP3A4; el atogepant es sustrato de CYP3A4 con moderada extracción hepática; los niveles aumentan aproximadamente 2-3 veces',
    'Toxicidad del gepante: náuseas, elevación de enzimas hepáticas, estreñimiento severo',
    'Reducir dosis de atogepant a 10 mg (dosis mínima) al usar claritromicina. Evitar la combinación si es posible. Usar eritromicina tópica o amoxicilina si se necesita antibiótico',
    'REDUCIR DOSIS — Atogepant a 10 mg con claritromicina',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.increasedToxicity},
    [_kRefFDA]),

  // ── SECCIÓN 5: EII y biológicos ──────────────────────────────────────────

  // 48
  ('upadacitinibe', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe fuertemente CYP3A4, la principal vía metabólica del upadacitinib; los niveles plasmáticos pueden triplicarse',
    'Toxicidad hematológica del inhibidor de JAK: neutropenia grave, linfopenia, anemia, trombocitopenia; riesgo de infecciones oportunistas mortales',
    'Contraindicado durante el tratamiento con upadacitinib (Rinvoq). Usar amoxicilina o azitromicina como alternativa antibiótica',
    'CONTRAINDICADO — Claritromicina triplica upadacitinib: toxicidad hematológica',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.infection, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 49
  ('upadacitinibe', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina es inductor potente de CYP3A4; reduce los niveles de upadacitinib en aproximadamente un 60%, eliminando su eficacia en EII',
    'Fracaso terapéutico: reactivación de la EII (colitis ulcerosa o enfermedad de Crohn)',
    'Contraindicado según ficha técnica. Cambiar el antibiótico o el esquema de tratamiento para EII. Si se debe usar rifampicina, suspender el inhibidor de JAK y monitorear la actividad de la enfermedad',
    'FRACASO TERAPÉUTICO — Rifampicina elimina eficacia de upadacitinib',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA]),

  // 50
  ('ozanimodo', 'linezolida',
    InteractionSeverity.contraindicated,
    'El ozanimod produce un metabolito activo mayor (CC112273) que inhibe la MAO-B y levemente la MAO-A; la linezolida también inhibe la MAO; la combinación puede producir crisis hipertensivas graves',
    'Crisis hipertensiva severa, accidente cerebrovascular isquémico, síndrome serotoninérgico',
    'Contraindicado según ficha técnica de Zeposia (ozanimod). Suspender ozanimod al menos 3 días antes de iniciar linezolida',
    'CONTRAINDICADO — Ozanimod + Linezolida: crisis hipertensiva y síndrome serotoninérgico',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.serotonin},
    [_kRefFDA]),

  // 51
  ('ozanimodo', 'metoprolol',
    InteractionSeverity.major,
    'Los moduladores de S1P (ozanimod, etrasimod) producen bradicardia significativa al inicio por secuestro de linfocitos en ganglios linfáticos y efecto directo sobre el nódulo SA; los betabloqueadores suman efecto cronotrópico negativo',
    'Bradicardia severa (<40 lpm), bloqueo AV de 2.°-3.° grado, síncope, shock cardiogénico',
    'Realizar ECG antes de iniciar el modulador S1P. Monitorear FC y ECG durante las primeras 6 horas de la primera dosis. Considerar el ingreso hospitalario para la primera dosis en pacientes con betabloqueadores. Si la FC <40 lpm: suspender el modulador S1P',
    'BRADICARDIA GRAVE — Monitoreo ECG 6h en primera dosis de ozanimod + betabloqueador',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefUT]),

  // 52
  ('ozanimodo', 'amitriptilina',
    InteractionSeverity.contraindicated,
    'El metabolito activo del ozanimod inhibe MAO-B; la amitriptilina es un TCA con propiedades adrenérgicas e inhibidor débil de la MAO; la combinación puede producir síndrome serotoninérgico y crisis hipertensivas',
    'Crisis hipertensiva, síndrome serotoninérgico, arritmias por activación adrenérgica',
    'Contraindicado. Cambiar a un antidepresivo sin actividad sobre la MAO (ISRS con precaución, o mirtazapina)',
    'CONTRAINDICADO — Ozanimod + Amitriptilina: crisis hipertensiva',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.serotonin},
    [_kRefFDA]),

  // 53
  ('sulfassalazina', 'warfarina',
    InteractionSeverity.major,
    'La sulfasalazina puede desplazar a la warfarina de su unión a la albúmina plasmática (90-99% unida a proteínas) y alterar la síntesis de vitamina K por la flora intestinal',
    'Elevación del INR con riesgo de hemorragia mayor; efecto más pronunciado en las primeras 2 semanas',
    'Medir INR antes de iniciar sulfasalazina y a los 7 y 14 días del inicio. Ajustar dosis de warfarina según resultados. Informar al paciente sobre signos de sangrado',
    'MONITOREO INR — Sulfasalazina desplaza warfarina: riesgo hemorrágico',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  // 54
  ('sulfassalazina', 'sulfametoxazol',
    InteractionSeverity.contraindicated,
    'Duplicación de estructura sulfonamídica: ambas son derivados de sulfonamidas. Suma de toxicidad hematológica (inhibición de folato) y dermatológica',
    'Aplasia medular grave, agranulocitosis, síndrome de Stevens-Johnson, necrólisis epidérmica tóxica',
    'Contraindicado. Usar trimetoprima sola o nitrofurantoína como alternativa antibiótica en el contexto de la EII',
    'CONTRAINDICADO — Doble sulfonamida: aplasia medular y Stevens-Johnson',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.other},
    [_kRefGG, _kRefMdx]),

  // ── SECCIÓN 6: Dislipidemia, hemostáticos, Alzheimer ─────────────────────

  // 55
  ('gemfibrozil', 'sinvastatina',
    InteractionSeverity.contraindicated,
    'Gemfibrozilo inhibe la glucuronidación (UGT1A1/UGT1A3) de las estatinas y CYP2C8; los niveles de simvastatina y lovastatina aumentan hasta 4-5 veces sin posibilidad de compensación metabólica',
    'Rabdomiólisis masiva y fulminante: mioglobinuria marrón oscura, insuficiencia renal anúrica, hiperpotasemia fatal por liberación masiva de potasio intramuscular',
    'Contraindicado absolutamente (FDA). Si el paciente necesita un fibrato con estatina, usar fenofibrato + estatina (interacción significativamente menor). El bezafibrato también es más seguro que gemfibrozilo con estatinas',
    'CONTRAINDICADO FDA — Rabdomiólisis fatal: Gemfibrozilo + Simvastatina/Lovastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefFDA, _kRefGG, _kRefMdx, _kRefUT]),

  // 56
  ('gemfibrozil', 'atorvastatina',
    InteractionSeverity.major,
    'Gemfibrozilo inhibe la glucuronidación y OATP1B1; los niveles de atorvastatina aumentan 1.8 veces; menor que simvastatina pero clínicamente relevante',
    'Miopatía, elevación de CPK, riesgo de rabdomiólisis especialmente en pacientes con IRC o hipotiroidismo',
    'Evitar si es posible. Si la combinación es necesaria: usar dosis mínima de atorvastatina (10 mg), monitorear CPK mensualmente. Instruir al paciente para reportar dolor muscular o debilidad',
    'MIOPATÍA — Monitorear CPK mensual con gemfibrozilo + atorvastatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  // 57
  ('acido bempedoico', 'sinvastatina',
    InteractionSeverity.contraindicated,
    'El ácido bempedoico inhibe el transportador OAT2 y comparte vías de excreción con simvastatina y lovastatina; los niveles de estas estatinas aumentan hasta un 60-70%',
    'Miopatía severa, rabdomiólisis, insuficiencia renal aguda',
    'Contraindicado superar 20 mg de simvastatina y 20 mg de lovastatina durante el uso de ácido bempedoico. Cambiar preferiblemente a rosuvastatina (no afectada significativamente por bempedoico)',
    'CONTRAINDICADO >20mg — Ácido bempedoico eleva simvastatina: rabdomiólisis',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA]),

  // 58
  ('acido bempedoico', 'alopurinol',
    InteractionSeverity.major,
    'El ácido bempedoico inhibe el transportador OAT1/OAT3 renal, reduciendo la excreción de ácido úrico; los niveles de urato sérico aumentan 1.5-2 mg/dL sobre la línea basal',
    'Hiperuricemia sintomática, crisis aguda de gota articular (tofácea), nefrolitiasis úrica',
    'Monitorear ácido úrico sérico al inicio y a los 3 meses. Ajustar dosis de alopurinol según niveles de urato objetivo (<6 mg/dL). Instruir al paciente sobre síntomas de gota',
    'HIPERURICEMIA — Bempedoico + diuréticos tiazídicos: crisis de gota',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefUT]),

  // 59
  ('icosapento de etilo', 'warfarina',
    InteractionSeverity.major,
    'El EPA puro (icosapento) inhibe la función plaquetaria (inhibición de TXA2) y puede afectar la síntesis de factores de coagulación dependientes de vitamina K de forma secundaria; efecto anticoagulante aditivo sin alterar necesariamente el INR estándar',
    'Hemorragia mayor espontánea: sangrado gastrointestinal, hemorragia intracraneal, hematomas musculares extensos con INR dentro del rango terapéutico',
    'Monitorear signos de sangrado activamente. El INR puede no reflejar el riesgo hemorrágico real. En pacientes anticoagulados que inician Vascepa: considerar revisión del balance riesgo-beneficio. Control en 4 semanas',
    'SANGRADO MAYOR — Icosapento de etilo potencia anticoagulación sin alterar INR',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 60
  ('icosapento de etilo', 'ticagrelor',
    InteractionSeverity.major,
    'Ambos tienen efectos antiagregantes plaquetarios; el icosapento inhibe la síntesis de TXA2 (similar al AAS) y el ticagrelor bloquea el receptor P2Y12; la acción antiagregante es aditiva',
    'Sangrado gastrointestinal oculto, hemorragia subaguda en sitios de punción, epistaxis frecuente',
    'Monitorear signos de sangrado gastrointestinal (heces oscuras, epigastralgia). En procedimientos invasivos planificados: suspender icosapento 5-7 días antes',
    'SANGRADO AUMENTADO — Doble antiagregación con icosapento + ticagrelor',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefUT, _kRefGG]),

  // 61 — Donepezilo + anticolinérgicos
  ('donepezilo', 'atropina',
    InteractionSeverity.contraindicated,
    'Los inhibidores de la acetilcolinesterasa (donepezilo, rivastigmina, galantamina) aumentan la actividad colinérgica central y periférica; los anticolinérgicos (atropina, escopolamina, hioscina) la antagonizan de forma directa y completa',
    'Anulación total del efecto terapéutico del fármaco pro-Alzheimer, desencadenamiento de delirio hiperactivo por efecto anticolinérgico central predominante',
    'Contraindicado. Los anticolinérgicos están en la lista de Beers (medicamentos inapropiados en ancianos). Sustituir atropina/escopolamina por fármacos sin carga anticolinérgica para el control de secreciones o espasmo',
    'CONTRAINDICADO — Anticolinérgicos anulan inhibidores de colinesterasa en Alzheimer',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.cns},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 62 — Donepezilo + metoprolol
  ('donepezilo', 'metoprolol',
    InteractionSeverity.major,
    'Los inhibidores de la colinesterasa aumentan el tono vagal cardíaco vía estimulación parasimpática directa del nódulo SA; los betabloqueadores suprimen la respuesta simpática contrarreguladora; la suma produce bloqueo cronotrópico aditivo severo',
    'Bradicardia sinusal extrema (<40 lpm), síncope, bloqueo SA o AV, colapso hemodinámico',
    'Monitorear frecuencia cardíaca semanalmente al inicio de la combinación. Si FC <50 lpm en reposo: considerar reducir dosis de betabloqueador o cambiar a donepezilo en dosis nocturna (menor impacto vagotónico diurno). ECG basal obligatorio',
    'BRADICARDIA GRAVE — Monitorear FC semanal con inhibidor colinesterasa + betabloqueador',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 63 — Donepezilo + claritromicina
  ('donepezilo', 'claritromicina',
    InteractionSeverity.major,
    'Claritromicina inhibe CYP3A4, una de las vías de metabolismo del donepezilo; los niveles plasmáticos del pro-colinérgico aumentan un 40-50%; la galantamina comparte una interacción similar',
    'Crisis colinérgica periférica: diarrea severa, vómitos, broncospasmo, bradicardia extrema, hipersecreción glandular, calambres musculares',
    'Monitorear signos de toxicidad colinérgica durante el tratamiento con claritromicina. Usar azitromicina como alternativa antibiótica de primera elección en pacientes con Alzheimer tratados con inhibidores de colinesterasa',
    'CRISIS COLINÉRGICA — Claritromicina eleva donepezilo: bradicardia y diarrea',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.other},
    [_kRefUT, _kRefMdx]),

  // 64 — Memantina + acetazolamida
  ('memantina', 'acetazolamida',
    InteractionSeverity.major,
    'La memantina es eliminada principalmente por el riñón de forma dependiente del pH urinario; la alcalinización de la orina por acetazolamida o bicarbonato reduce dramáticamente la excreción renal de memantina hasta en un 80%',
    'Toxicidad por memantina: agitación psicomotriz severa, alucinaciones, confusión, psicosis aguda, marcha inestable, convulsiones',
    'Evitar la coadministración. Si el paciente requiere acetazolamida (glaucoma, epilepsia), considerar dosis menores de memantina y monitoreo neuropsiquiátrico estricto',
    'TOXICIDAD POR MEMANTINA — Acetazolamida alcaliniza orina: acumulación 80%',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 65 — Sofosbuvir + amiodarona
  ('sofosbuvir', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Mecanismo no completamente elucidado; posiblemente la inhibición de la actividad del canal If por el sofosbuvir o por efecto directo sobre el sistema de conducción potenciado por la amiodarona produce bradicardia sinusal progresiva fatal',
    'Bradicardia sinusal letal, bloqueo AV completo de instauración rápida, asistolia, muerte súbita cardíaca (casos reportados en FDA MedWatch 2015)',
    'Contraindicación absoluta según ficha técnica de Sovaldi/Harvoni. Si el paciente requiere amiodarona, hospitalizar y monitorear el ritmo cardíaco durante 48 horas de inicio del antiviral. Considerar cambio de amiodarona a otro antiarrítmico',
    'CONTRAINDICADO — Muerte súbita cardíaca: Sofosbuvir + Amiodarona (FDA Black Box)',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefFDA, _kRefMdx, _kRefUT]),

  // 66 — Sofosbuvir/Ledipasvir + carbamazepina
  ('sofosbuvir', 'carbamazepina',
    InteractionSeverity.contraindicated,
    'Carbamazepina, fenitoína y fenobarbital inducen P-gp y CYP3A4, reduciendo la absorción y aumentando el metabolismo del sofosbuvir y sus metabolitos; los niveles caen hasta un 72%',
    'Fracaso terapéutico del tratamiento de hepatitis C: niveles subterapéuticos con riesgo de selección de variantes resistentes pan-genotípicas',
    'Contraindicado. Cambiar el anticonvulsivo a levetiracetam, lamotrigina o lacosamida (sin inducción significativa) durante el tratamiento de la hepatitis C',
    'CONTRAINDICADO — Anticonvulsivantes inductores eliminan eficacia del antiviral HCV',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 67 — Ledipasvir + omeprazol
  ('ledipasvir', 'omeprazol',
    InteractionSeverity.major,
    'Ledipasvir y velpatasvir requieren acidez gástrica para disolverse y absorberse adecuadamente; los IBPs elevan el pH gástrico >5, reduciendo la solubilidad y la absorción del antiviral hasta un 40-50%',
    'Reducción de la concentración plasmática del antiviral y riesgo de niveles subterapéuticos que comprometen la cura sostenida de la hepatitis C (RVS12)',
    'Si es inevitable el IBP: usar omeprazol 20 mg máximo y tomar junto con el antiviral en ayunas (el pH post-deglución es más ácido inmediatamente). Si la supresión ácida es indispensable, usar famotidina 40 mg (12h después del antiviral)',
    'REDUCCIÓN EFICACIA HCV — Tomar ledipasvir/velpatasvir junto con IBP en ayunas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT, _kRefMdx]),

  // 68 — Daptomicina + estatinas
  ('daptomicina', 'atorvastatina',
    InteractionSeverity.contraindicated,
    'La daptomicina causa miotoxicidad directa por inserción en las membranas de las células musculares; las estatinas causan miotoxicidad por depleción de CoQ10 y alteración de la cadena respiratoria mitocondrial; la toxicidad muscular es aditiva y sinérgica',
    'Rabdomiólisis severa, CPK >10.000 U/L, insuficiencia renal aguda por mioglobinuria, hiperpotasemia potencialmente fatal',
    'Suspender TODA estatina al inicio de daptomicina y medir CPK basalmente. Controlar CPK cada 48 horas durante el tratamiento. Reanudar la estatina solo 7 días después de completar la daptomicina y con CPK documentada en descenso',
    'CONTRAINDICADO — Suspender estatina al iniciar daptomicina: rabdomiólisis',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefFDA]),

  // 69 — Amicacina + furosemida
  ('aminoglicosideo', 'furosemida',
    InteractionSeverity.contraindicated,
    'Los aminoglucósidos son ototóxicos por destrucción de células ciliadas del órgano de Corti (especialmente alta frecuencia); los diuréticos de asa (furosemida, ácido etacrínico) son co-ototóxicos por edema endolinfático y daño estrial vascular; el efecto combinado es explosivo e irreversible',
    'Sordera bilateral permanente irreversible de instauración rápida (horas-días), anacusia, vértigo vestibular severo con trastorno del equilibrio crónico',
    'Evitar la combinación siempre que sea clínicamente posible. Si es imprescindible: usar la dosis mínima efectiva de ambos, monitoreo audiológico cada 48 h, niveles valle de aminoglucósido <1 mcg/mL, hidratación adecuada. En sepsis por Pseudomonas sin alternativa: decisión individualizada con consentimiento informado',
    'CONTRAINDICADO — Sordera irreversible: Aminoglucósido + Furosemida',
    EvidenceLevel.established,
    {RiskType.ototoxicity, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 70 — Amicacina + vancomicina
  ('aminoglicosideo', 'vancomicina',
    InteractionSeverity.major,
    'Ambos antibióticos tienen nefrotoxicidad tubular directa; la vancomicina daña las células del túbulo proximal y distal; los aminoglucósidos dañan las células del túbulo proximal por estrés oxidativo; el daño renal es aditivo con sinergia tóxica',
    'Insuficiencia renal aguda oligúrica, necesidad de terapia de reemplazo renal, prolongación del efecto de ambos antibióticos por acumulación',
    'Monitorear creatinina sérica cada 24-48 horas. Medir niveles valle de vancomicina (objetivo 15-20 mcg/mL con AUC/CMI 400-600) y nivel máximo de aminoglucósido. Ajustar intervalos según TFG calculada. Hidratación forzada IV y evitar NSAIDs o contraste simultáneos',
    'NEFROTOXICIDAD ADITIVA — Monitoreo diario creatinina + niveles con amicacina + vancomicina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 71 — Bedaquilina + rifampicina
  ('bedaquilina', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina induce potentemente CYP3A4, la principal enzima de metabolismo de bedaquilina; la exposición sistémica cae más de un 50% con ciclos estándar de rifampicina',
    'Fracaso terapéutico del esquema contra TBC-MDR, selección de mutantes resistentes a bedaquilina, amplificación de resistencia a XDR-TB',
    'Contraindicado absolutamente según ficha técnica. En TBC-MDR que requiere bedaquilina, usar esquemas sin rifampicina. La rifabutina es una alternativa con menor inducción de CYP3A4 y puede usarse bajo monitoreo estrecho',
    'CONTRAINDICADO — Rifampicina elimina eficacia de bedaquilina en TBC-MDR',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 72 — Bedaquilina + amiodarona
  ('bedaquilina', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Bedaquilina prolonga el QTc de forma dependiente de dosis (hasta +11 ms con 400 mg); la amiodarona prolonga el QTc de forma marcada (+60-100 ms); la combinación produce una prolongación aditiva que supera el umbral crítico de seguridad',
    'Torsades de Pointes, fibrilación ventricular, muerte súbita cardíaca durante el tratamiento de TBC-MDR',
    'Contraindicado. Si el paciente requiere amiodarona para una arritmia grave, elegir un esquema alternativo sin bedaquilina para la TBC-MDR (por ejemplo, con linezolida, moxifloxacino a dosis controlada, con ECG frecuente)',
    'CONTRAINDICADO — Bedaquilina + Amiodarona: Torsades de Pointes fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  // 73 — Isoniazida + carbamazepina
  ('isoniazida', 'carbamazepina',
    InteractionSeverity.major,
    'La isoniazida inhibe CYP2C9 y CYP3A4 de forma significativa; bloquea el metabolismo de la carbamazepina a su metabolito activo CBZ-E, elevando los niveles del fármaco parental; la carbamazepina, a su vez, puede inducir el metabolismo de la isoniazida',
    'Toxicidad por carbamazepina: ataxia, diplopia, nistagmo, mareos severos, somnolencia extrema, náuseas; en casos graves: hiponatremia y convulsiones por la carbamazepina misma',
    'Medir niveles de carbamazepina antes de iniciar isoniazida y a los 5-7 días. Reducir la dosis de carbamazepina un 25-50% al iniciar el antituberculoso. Medir hepatograma (ambos son hepatotóxicos)',
    'TOXICIDAD CBZ — Isoniazida eleva carbamazepina: ataxia y diplopia',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 74 — Isoniazida + paracetamol
  ('isoniazida', 'paracetamol',
    InteractionSeverity.contraindicated,
    'La isoniazida induce fuertemente CYP2E1, la enzima responsable de generar el metabolito hepatotóxico del paracetamol (N-acetil-p-benzoquinoneimina, NAPQI); con dosis terapéuticas de paracetamol, la cantidad de NAPQI formada puede superar la capacidad de conjugación glutatión hepático',
    'Hepatitis fulminante por paracetamol: elevación masiva de transaminasas >5000 U/L, coagulopatía, encefalopatía hepática y muerte; riesgo particularmente alto en alcohólicos, desnutridos o con reserva hepática reducida',
    'Contraindicado el uso regular de paracetamol >1 g/día en pacientes con isoniazida. Si es imprescindible un analgésico: usar ibuprofeno (sin esta interacción, pero con riesgo GI). Monitorizar transaminasas mensualmente durante el tratamiento con isoniazida',
    'CONTRAINDICADO — Hepatitis fulminante: isoniazida + paracetamol induce metabolito tóxico',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefFDA]),

  // 75 — Praziquantel + rifampicina
  ('praziquantel', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina induce CYP3A4 y CYP2C19 de forma extrema; los niveles plasmáticos del praziquantel se reducen hasta un 85%, con un AUC cercano a cero tras una sola dosis de rifampicina',
    'Fracaso terapéutico total del tratamiento antiparasitario: persistencia de teniasis, esquistosomiasis o neurocisticercosis activa con riesgo de progresión',
    'Contraindicado de forma absoluta. Suspender rifampicina mínimo 4 semanas antes del tratamiento con praziquantel. Si el paciente no puede suspender rifampicina, considerar albendazol o ivermectina según el parásito a tratar',
    'CONTRAINDICADO — Rifampicina elimina praziquantel al 85%: fracaso antiparasitario total',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  // 76 — Nitroimidazoles + alcohol
  ('metronidazol', 'etanol',
    InteractionSeverity.contraindicated,
    'Los nitroimidazoles (metronidazol, secnidazol, tinidazol, ornidazol) inhiben la aldehído deshidrogenasa (ALDH), bloqueando la oxidación del acetaldehído; el acetaldehído se acumula a niveles tóxicos en sangre y tejidos produciendo una reacción disulfiram-like',
    'Reacción tipo disulfiram severa: náuseas violentas, vómitos repetitivos, enrojecimiento facial (flushing), taquicardia, hipotensión, diaforesis profusa, cefalea pulsátil y disnea; en casos graves: angina, arritmias, colapso hemodinámico',
    'Contraindicado el consumo de alcohol durante el tratamiento y hasta 72 horas después de la última dosis (algunos expertos recomiendan 5 días). Incluir instrucción verbal y escrita en la prescripción. El alcohol en preparaciones farmacéuticas (jarabes, colutorios) también debe evitarse',
    'CONTRAINDICADO — Reacción tipo disulfiram severa: nitroimidazoles + alcohol',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.other},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // 77 — Nitroimidazoles + warfarina
  ('metronidazol', 'warfarina',
    InteractionSeverity.major,
    'El metronidazol inhibe CYP2C9 (principal vía de metabolismo de la S-warfarina, el isómero 3-5 veces más potente); la inhibición reduce el aclaramiento de la warfarina, elevando el INR de forma rápida y marcada',
    'Hemorragia mayor: sangrado gastrointestinal masivo, hemorragia intracraneal, hematurias macroscópicas; el INR puede duplicarse en 2-3 días',
    'Reducir la dosis de warfarina un 25-50% al iniciar el nitroimidazol. Medir INR antes de iniciar, al día 3, al día 7 y a los 3 días de finalizar el antibiótico. Informar al paciente sobre signos de sangrado',
    'HEMORRAGIA MAYOR — Reducir warfarina 25-50% con nitroimidazoles: INR duplicado',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // ── SECCIÓN 7: Cardiovascular, EPOC, ginecología ─────────────────────────

  // 78 — LABA + propranolol
  ('indacaterol', 'propranolol',
    InteractionSeverity.contraindicated,
    'El propranolol es un betabloqueador no selectivo que antagoniza directamente los receptores beta-2 bronquiales; esta acción contrarresta el efecto broncodilatador de todos los LABA (indacaterol, olodaterol, salmeterol, formoterol, vilanterol)',
    'Broncoespasmo severo con insuficiencia respiratoria aguda, hipoxemia severa, asma fatal o exacerbación grave de EPOC',
    'Contraindicado en cualquier paciente con asma o EPOC que recibe un LABA. Si el paciente requiere un betabloqueador cardiovascular: usar un cardioselectivo (metoprolol, bisoprolol) a la dosis mínima efectiva con monitoreo de la función pulmonar (FEV1)',
    'CONTRAINDICADO — Broncoespasmo fatal: LABA + Propranolol (betabloqueador no selectivo)',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.other},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // 79 — LABA + furosemida (hipopotasemia)
  ('indacaterol', 'furosemida',
    InteractionSeverity.major,
    'Los agonistas beta-2 (LABA) estimulan la Na+/K+-ATPase, promoviendo la entrada de potasio al interior celular (hipopotasemia extracorporal); los diuréticos de asa causan hipopotasemia por pérdida renal; el efecto combinado puede llevar a hipopotasemia severa de forma rápida',
    'Hipopotasemia severa (<3.0 mEq/L): debilidad muscular, calambres, arritmias ventriculares, prolongación del QT, parálisis hipocalémica',
    'Monitorear potasio sérico al inicio y semanalmente. Objetivo K+ >3.5 mEq/L. Considerar suplementación con cloruro de potasio 40-80 mEq/día si el paciente usa dosis altas de LABA + furosemida. ECG de control si K+ <3.5',
    'HIPOCALEMIA GRAVE — Monitorear K+ semanal con LABA + diurético de asa',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.arrhythmia, RiskType.electrolyte},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 80 — LAMA + amitriptilina
  ('glicopirronio', 'amitriptilina',
    InteractionSeverity.major,
    'Los LAMA (glicopirronio, umeclidinio, aclidinio) bloquean receptores muscarínicos M1-M3; la amitriptilina tiene potente efecto antimuscarínico central y periférico; la suma de actividades anticolinérgicas produce toxicidad sistémica en pacientes añosos',
    'Retención urinaria aguda (especialmente en hiperplasia prostática), glaucoma de ángulo cerrado, íleo paralítico, taquicardia sinusal, confusión mental, delirio anticolinérgico',
    'Evitar la combinación en pacientes con HBP, glaucoma de ángulo estrecho o demencia. Si es inevitable, monitorear la diuresis, la presión intraocular y el estado cognitivo. Considerar cambiar amitriptilina a un antidepresivo sin carga anticolinérgica (sertralina, mirtazapina)',
    'SÍNDROME ANTICOLINÉRGICO — LAMA + Amitriptilina: retención urinaria y delirio',
    EvidenceLevel.established,
    {RiskType.other, RiskType.cns},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 81 — Roflumilast + rifampicina
  ('roflumilast', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina, carbamazepina, fenitoína y fenobarbital inducen CYP3A4 y CYP1A2, las enzimas responsables del metabolismo de roflumilast y su metabolito activo N-óxido; la exposición total cae hasta un 58-79%',
    'Pérdida del efecto antiinflamatorio del roflumilast: incremento en la frecuencia de exacerbaciones de EPOC severa con bronquitis crónica',
    'Contraindicado según ficha técnica del roflumilast (Daxas/Daliresp). Cambiar el anticonvulsivo o antibiótico por opciones sin inducción enzimática. Si la rifampicina es indispensable: suspender roflumilast y adoptar medidas alternativas de control de la inflamación en EPOC',
    'FRACASO TERAPÉUTICO EPOC — Inductores eliminan eficacia de roflumilast',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 82 — Roflumilast + claritromicina
  ('roflumilast', 'claritromicina',
    InteractionSeverity.major,
    'Claritromicina inhibe CYP3A4 y CYP1A2; el AUC del roflumilast y su metabolito activo aumentan hasta un 100% con inhibidores potentes',
    'Aumento marcado de efectos adversos: diarrea severa, náuseas, pérdida de peso extrema, insomnio, cefaleas, aumento del riesgo de depresión y pensamientos suicidas',
    'Monitorear los efectos secundarios de roflumilast de forma estrecha durante el tratamiento con claritromicina. Considerar suspensión temporal del roflumilast durante el curso de antibiótico',
    'TOXICIDAD AUMENTADA — Claritromicina duplica roflumilast: diarrea y efectos GI',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 83 — Drospirenona + espironolactona
  ('drospirenona', 'espironolactona',
    InteractionSeverity.contraindicated,
    'La drospirenona tiene actividad antimineralocorticoide equivalente a 25 mg de espironolactona; la adición de espironolactona adicional produce bloqueo aldosterónico doble y extremo',
    'Hiperpotasemia severa potencialmente fatal (K+ >6.5 mEq/L): debilidad muscular progresiva, parálisis ascendente, arritmias ventriculares, paro cardíaco',
    'Contraindicado. Si el paciente requiere tratamiento antiandrogénico junto con AO con drospirenona: elegir AO con otra progestina (levonorgestrel) y espironolactona, o usar drospirenona sola. Monitorizar K+ en toda mujer con drospirenona + cualquier ahorrador de potasio',
    'CONTRAINDICADO — Hiperpotasemia fatal: Drospirenona + Espironolactona',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA]),

  // 84 — Ácido mefenámico + enoxaparina
  ('aine', 'enoxaparina',
    InteractionSeverity.contraindicated,
    'Los AINEs (ácido mefenámico, tolfenámico, ibuprofeno, naproxeno, etc.) inhiben la función plaquetaria (antiagregación por COX-1) y dañan la mucosa gástrica (úlcera/hemorragia); las heparinas bloquean la coagulación; el efecto combinado sobre la hemostasia es multiplicador',
    'Hemorragia gastrointestinal masiva activa con sangrado incoagulable, hematomas musculares extensos, sangrado retroperitoneal grave',
    'Contraindicado. Si el paciente requiere analgesia con HBPM: usar paracetamol (sin efecto antiagregante). En caso de uso urgente de AINE con anticoagulación: gastroprotección obligatoria con omeprazol 40 mg y reducción máxima del tiempo de exposición al AINE',
    'CONTRAINDICADO — Hemorragia masiva: AINEs + Heparina/HBPM',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx, _kRefFDA]),

  // 85 — Ácido mefenámico + metotrexato
  ('aine', 'metotrexato',
    InteractionSeverity.major,
    'Los AINEs y salicilatos compiten por la secreción tubular renal activa del metotrexato por el transportador OAT1/OAT3; la reducción del aclaramiento renal eleva los niveles de metotrexato hasta 3-4 veces',
    'Toxicidad severa por metotrexato: mucositis oral grave, mielodepresión profunda (pancitopenia), hepatotoxicidad, neumonitis intersticial; el riesgo es mayor en pacientes con IRC o deshidratados',
    'Contraindicado con metotrexato en dosis oncológicas. Con metotrexato en dosis bajas para artritis/psoriasis: evitar AINEs o usar paracetamol. Si es inevitable: hidratación IV abundante, reducir dosis de metotrexato y medir niveles a las 48 h',
    'TOXICIDAD METOTREXATO — AINEs bloquean excreción renal: pancitopenia',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 86 — Dienogest + rifampicina
  ('dienogest', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina, carbamazepina, fenitoína y fenobarbital inducen fuertemente CYP3A4, reduciendo los niveles séricos del dienogest hasta en un 83%; la progesterona micronizada es igualmente afectada',
    'Fracaso del tratamiento de la endometriosis: reinicio del dolor pélvico crónico, sangrado uterino anormal y progresión de las lesiones endometriósicas',
    'Contraindicado para el uso concomitante según ficha técnica. Si el anticonvulsivo es indispensable, cambiar el tratamiento hormonal a un análogo de GnRH (goserelina, leuprolida) que no es afectado por CYP3A4. Agregar método de barrera adicional si se usa como contracepción',
    'FRACASO TERAPÉUTICO — Inductores reducen dienogest 83%: endometriosis reactiva',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 87 — Goserelina + escitalopram
  ('goserelina', 'isrs',
    InteractionSeverity.major,
    'Los análogos de GnRH (goserelina, leuprolida) producen hipogonadismo agudo que prolonga el intervalo QTc de forma secundaria a la deprivación androgénica/estrogénica; el escitalopram también prolonga el QTc de manera dosis-dependiente',
    'Prolongación del QTc con riesgo de Torsades de Pointes, especialmente en presencia de hipokalemia o el uso concomitante de otros fármacos que prolongan el QT',
    'Realizar ECG basal antes de iniciar el análogo de GnRH en pacientes con escitalopram. Monitorear QTc cada 3 meses. Si QTc >500 ms: considerar cambio de escitalopram a sertralina (menor efecto sobre QT). Corregir hipopotasemia',
    'PROLONGACIÓN QT — ECG cada 3 meses con análogos GnRH + escitalopram',
    EvidenceLevel.probable,
    {RiskType.qtProlongation},
    [_kRefUT, _kRefMdx]),

  // ── SECCIÓN 8: Nuevos termMap entries y cruces adicionales ───────────────

  // 88 — Ganciclovir + imipenem
  ('ganciclovir', 'imipenem',
    InteractionSeverity.major,
    'Ambos fármacos tienen actividad convulsígena independiente: el imipenem reduce el umbral convulsivo por bloqueo de receptores GABA-A, y el ganciclovir puede producir neurotoxicidad directa; la combinación tiene efecto aditivo o sinérgico sobre el SNC',
    'Convulsiones generalizadas tónico-clónicas, especialmente en pacientes con disfunción renal (mayor acumulación de ambos) o daño neurológico previo',
    'Evitar la combinación siempre que sea posible. Si ambos son indispensables: reducir dosis según TFG, monitoreo neurológico continuo, considerar profilaxis anticonvulsiva con valproato o levetiracetam',
    'CONVULSIONES — Imipenem + Ganciclovir: toxicidad aditiva del SNC',
    EvidenceLevel.established,
    {RiskType.seizure, RiskType.cns},
    [_kRefGG, _kRefMdx]),

  // 89 — Ganciclovir + cotrimoxazol
  ('ganciclovir', 'metronidazol',
    InteractionSeverity.major,
    'El ganciclovir causa mielodepresión significativa (neutropenia, trombocitopenia); el trimetoprim-sulfametoxazol también inhibe la síntesis de folato con toxicidad hematológica; la suma produce aplasia de la médula ósea más profunda',
    'Neutropenia severa (<500/mm³), trombocitopenia grave, anemia aplásica, riesgo de infecciones bacterianas oportunistas fatales',
    'Monitorear hemograma completo 2 veces por semana durante la combinación. Si neutrófilos <500/mm³: suspender uno de los fármacos (preferentemente el cotrimoxazol si hay alternativa). Considerar filgrastim (G-CSF) para recuperar neutrófilos',
    'APLASIA MEDULAR — Monitorear hemograma 2×/semana con ganciclovir + cotrimoxazol',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 90 — Caspofungina + rifampicina
  ('caspofungina', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina induce el aclaramiento hepático de la caspofungina por mecanismos complejos de transporte (no CYP450); el AUC de caspofungina cae hasta un 30% durante el tratamiento concomitante con rifampicina',
    'Niveles subterapéuticos de caspofungina con riesgo de fracaso en el tratamiento de candidemia o aspergilosis invasiva',
    'Según ficha técnica: usar dosis aumentada de caspofungina (70 mg/día en lugar de 50 mg/día en adultos) durante el tratamiento con rifampicina. Monitorear la respuesta clínica y microbiológica de forma estricta',
    'AUMENTAR DOSIS — Caspofungina a 70 mg/día durante el tratamiento con rifampicina',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefUT]),

  // 91 — Ozanimod + diltiazem
  ('ozanimodo', 'diltiazem',
    InteractionSeverity.major,
    'Los moduladores de S1P (ozanimod, etrasimod) producen bradicardia significativa al inicio del tratamiento por efecto directo sobre el nódulo SA; el diltiazem tiene efecto cronotrópico e inotrópico negativo aditivo',
    'Bradicardia extrema (<40 lpm), bloqueo AV de 2.°-3.° grado, hipotensión severa, síncope',
    'Mismo protocolo que con betabloqueadores: ECG basal, monitoreo de FC durante las primeras 6 horas de la primera dosis del modulador S1P. Reducir dosis de diltiazem a la mínima efectiva antes de iniciar ozanimod',
    'BRADICARDIA GRAVE — ECG obligatorio en primera dosis de ozanimod con diltiazem',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA]),

  // 92 — Espironolactona + ARA-II (candesartana, olmesartana)
  ('espironolactona', 'losartana',
    InteractionSeverity.major,
    'Ambos fármacos retienen potasio: la espironolactona bloquea el receptor mineralocorticoide (aldosterona) y los ARA-II reducen la síntesis de aldosterona; la hiperpotasemia es el resultado de la suma de ambos efectos',
    'Hiperpotasemia severa (K+ >5.5-6.5 mEq/L): debilidad muscular, parálisis, arritmias ventriculares letales, paro cardíaco; riesgo especialmente alto en pacientes con IRC o diabetes',
    'Monitorizar K+ y creatinina sérica a los 7 y 14 días del inicio de la combinación, luego mensualmente. Objetivo K+ <5.0 mEq/L. Advertir sobre alimentos ricos en potasio (plátano, naranja). Ajustar dosis de espironolactona según K+',
    'HIPERPOTASEMIA GRAVE — Monitorear K+ semanal con espironolactona + ARA-II',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 93 — Infliximab/biológicos + vacunas vivas
  ('adalimumabe', 'vacuna',
    InteractionSeverity.contraindicated,
    'Los anticuerpos monoclonales anti-TNF (infliximab, adalimumab, golimumab) y otros biológicos (ustekinumab, risankizumab, ozanimod) producen inmunosupresión profunda que impide la respuesta protectora contra los patógenos vacunales vivos atenuados',
    'Infección diseminada potencialmente fatal por el organismo vacunal: tuberculosis miliar por BCG, varicela diseminada, sarampión progresivo, fiebre amarilla generalizada',
    'Contraindicado de forma absoluta durante la terapia biológica. Las vacunas vivas deben administrarse al menos 4 semanas antes de iniciar el biológico. Después de suspender el biológico: esperar 3-6 meses (dependiendo de la vida media) antes de administrar vacunas vivas. Vacunas inactivadas son seguras durante la terapia',
    'CONTRAINDICADO — Vacunas vivas en biológicos: infección diseminada mortal',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefFDA]),

  // 94 — Volanesorsen + warfarina
  ('volanesorsen', 'warfarina',
    InteractionSeverity.major,
    'El volanesorsen (oligonucleótido antisentido) causa trombocitopenia en hasta el 77% de los pacientes; con plaquetas <50.000/mm³, el riesgo de sangrado espontáneo se multiplica de forma exponencial cuando se combina con anticoagulación oral',
    'Hemorragia espontánea severa: sangrado gastrointestinal masivo, hemorragia intracraneal, sangrado retroperitoneal; equimosis extensas con plaquetopenia profunda',
    'Contraindicado con anticoagulantes orales en pacientes con plaquetas <100.000/mm³. Recuento de plaquetas quincenal durante la terapia con volanesorsen. Si plaquetas <50.000: suspender volanesorsen. Si plaquetas <25.000: hospitalización inmediata y suspensión de la anticoagulación',
    'HEMORRAGIA SEVERA — Controlar plaquetas quincenal con volanesorsen + anticoagulantes',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.myelosuppression},
    [_kRefFDA, _kRefUT]),

  // 95 — Evolocumab/alirocumab + estatinas (sinergismo beneficioso documentado)
  ('evolocumab', 'atorvastatina',
    InteractionSeverity.moderate,
    'Las estatinas inhiben HMG-CoA reductasa, reduciendo la síntesis de colesterol intracelular; esto aumenta la expresión de receptores LDL y eleva la expresión de PCSK9; los anticuerpos anti-PCSK9 (evolocumab, alirocumab) bloquean este feedback negativo, potenciando el aclaramiento de LDL',
    'No hay toxicidad; la interacción es farmacodinámica positiva beneficiosa: la adición del iPCSK9 a la estatina reduce el LDL un 60% adicional sobre la estatina sola',
    'No requiere ajuste de dosis. Es la combinación sinérgica esperada y deseada para la reducción máxima de LDL en pacientes de alto riesgo cardiovascular. El tratamiento de base con estatina potencia la eficacia del iPCSK9',
    'SINERGISMO BENEFICIOSO — Estatina + iPCSK9: reducción LDL óptima en alto riesgo CV',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 96 — Roxadustat + estatinas (OATP1B1)
  ('roxadustat', 'atorvastatina',
    InteractionSeverity.major,
    'El roxadustat (y otros inhibidores de HIF-PH) inhiben el transportador OATP1B1/BCRP, aumentando la biodisponibilidad sistémica de las estatinas que son sustratos de este transportador (rosuvastatina especialmente, atorvastatina)',
    'Miopatía y elevación de CPK; riesgo de rabdomiólisis en pacientes con IRC grave o que usan dosis altas de estatinas',
    'Monitorear CPK antes de iniciar el inhibidor de HIF-PH y a los 30 días. Reducir la dosis de rosuvastatina a la mitad en combinación con roxadustat. Usar dosis menores de atorvastatina (10-20 mg máx)',
    'MIOPATÍA — Roxadustat eleva estatinas vía OATP1B1: monitorear CPK',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefUT]),

  // 97 — Hierro IV + hierro oral
  ('hierro sacarato', 'ferritina',
    InteractionSeverity.major,
    'El hierro endovenoso satura los depósitos y eleva los niveles de hepcidina hepática de forma aguda; la hepcidina bloquea el transportador ferroportina intestinal, inhibiendo completamente la absorción intestinal del hierro oral hasta por 24-48 horas',
    'Reducción marcada de la absorción del hierro oral suplementario, resultando en tratamiento ineficaz de la anemia ferropénica si se dan simultáneamente',
    'No administrar hierro oral dentro de las 24-48 horas del hierro IV. Instruir al paciente que si recibe hierro IV en infusión, suspenda el hierro oral ese día y el siguiente. La suplementación oral puede reanudarse a las 48 horas de la infusión IV',
    'INEFICACIA — No dar hierro oral en las 48h del hierro IV: hepcidina bloquea absorción',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 98 — Mizolastina + claritromicina
  ('mizolastina', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina inhibe CYP3A4, la única vía de metabolismo de la mizolastina; los niveles plasmáticos de la mizolastina aumentan de forma sustancial con riesgo de toxicidad cardíaca',
    'Prolongación del intervalo QTc, Torsades de Pointes, arritmias ventriculares graves y muerte súbita cardíaca',
    'Contraindicado según ficha técnica de Mizollen (mizolastina). Sustituir por un antihistamínico sin efecto QT: cetirizina, loratadina o fexofenadina (metabolismo hepático diferente)',
    'CONTRAINDICADO — Mizolastina + Claritromicina: Torsades de Pointes',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefMdx]),

  // 99 — Ciclesonida/mometasona + itraconazol
  ('mometasona', 'fluconazol',
    InteractionSeverity.major,
    'Los antifúngicos azólicos potentes (itraconazol, ketoconazol) inhiben intensamente CYP3A4; aunque los corticoides inhalados tienen baja biodisponibilidad sistémica normalmente, su metabolismo CYP3A4 se bloquea con azólicos potentes, aumentando la absorción sistémica significativamente',
    'Síndrome de Cushing iatrogénico: cara de luna llena, distribución central de grasa, estrías violáceas, hipertensión, hiperglucemia; supresión del eje HHA con riesgo de insuficiencia adrenal al suspender el corticoide',
    'Evitar la combinación con itraconazol/ketoconazol sistémicos. Con fluconazol a dosis estándar: monitorear signos de Cushing. Considerar beclometasona dipropionato (metabolismo pulmonar diferente, menor interacción) como alternativa de corticoide inhalado',
    'SÍNDROME DE CUSHING — Azoles sistémicos elevan corticoides inhalados: supresión adrenal',
    EvidenceLevel.established,
    {RiskType.other, RiskType.increasedToxicity},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 100 — Rosuvastatina + roxadustat (BCRP)
  ('rosuvastatina', 'roxadustat',
    InteractionSeverity.major,
    'Roxadustat inhibe los transportadores OATP1B1 y BCRP; la rosuvastatina es el sustrato más sensible de ambos transportadores; el AUC de la rosuvastatina puede aumentar hasta un 130% con roxadustat',
    'Miopatía grave, elevación marcada de CPK, riesgo de rabdomiólisis especialmente en pacientes con IRC (que ya tienen mayor riesgo de miopatía)',
    'Reducir la dosis de rosuvastatina al 50% (máx 10 mg/día) en pacientes que inician roxadustat. Medir CPK basalmente y a los 30 días. Si CPK >5× LSN: suspender la rosuvastatina. Monitoreo clínico de dolor muscular y debilidad',
    'MIOPATÍA — Reducir rosuvastatina 50% con roxadustat (inhibición OATP1B1/BCRP)',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA]),

  // ── Termmap IDs adicionais para detecção ─────────────────────────────────

  // 101 — Dapagliflozina + espironolactona
  ('dapagliflozina', 'espironolactona',
    InteractionSeverity.major,
    'Os iSGLT2 causam diurese osmótica e natriurese; a espironolactona causa retenção de potássio e perda de sódio; a depleção de sódio cumulativa pode precipitar hipovolemia severa, especialmente en ancianos',
    'Hipotensión ortostática, insuficiencia renal aguda por hipoperfusão, hiperpotasemia se houver IRC subjacente',
    'Monitorar PA postural, creatinina e K+ nas semanas 1, 2 e 4. Instruir o paciente a hidratar-se adecuadamente',
    'HIPOVOLEMIA — Monitorar PA e K+ ao combinar iSGLT2 + espironolactona',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefUT, _kRefGG]),

  // 102 — Metformina + ciprofloxacino
  ('metformina', 'ciprofloxacino',
    InteractionSeverity.major,
    'As quinolonas podem causar tanto hipoglucemia (estimulação de secreção insulínica) quanto hiperglucemia (inhibición de la secreção); en diabéticos com metformina o efecto líquido é impredecible',
    'Hipoglucemia ou hiperglucemia inesperada e potencialmente grave, especialmente en ancianos',
    'Monitorar glucemia diariamente durante o tratamiento com quinolonas. Orientar al paciente sobre sintomas de hipoglucemia',
    'GLICEMIA INSTÁVEL — Monitorar glucemia com quinolonas + antidiabéticos',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.other},
    [_kRefGG, _kRefMdx]),

  // 103 — Rifampicina + warfarina
  ('rifampicina', 'warfarina',
    InteractionSeverity.major,
    'Rifampicina é o inductor mais potente do CYP2C9 (metabolismo de la S-varfarina); o AUC da varfarina pode cair até 90% em 1 semana de rifampicina',
    'Trombose ou embolia por nivel subterapéutico de anticoagulação; al suspender rifampicina, riesgo de hemorragia por acumulación rápida de varfarina',
    'Aumentar dosis de varfarina em até 5-10 vezes al iniciar rifampicina, com controle diário de INR. Al suspender rifampicina: reduzir warfarina inmediatamente e monitorar INR a cada 2-3 dias por 2 semanas',
    'FALHA ANTICOAGULAÇÃO — Rifampicina reduz varfarina 90%: INR diário obligatorio',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 104 — Valproato + carbamazepina
  ('valproato', 'carbamazepina',
    InteractionSeverity.major,
    'Interacción bidireccional complexa: o valproato inibe o metabolismo del metabólito ativo da carbamazepina (CBZ-10,11-epóxido) e a carbamazepina induz o metabolismo del valproato; resultados clínicos imprevisíveis',
    'Toxicidad por CBZ-epóxido (ataxia, diplopia, sonolência) com niveles normais de carbamazepina; fracaso terapéutico do valproato por reducción de los niveles',
    'Monitorar niveles de ambos e do epóxido da carbamazepina. Ajustar dosiss segundo resposta clínica e EEG. Preferir levetiracetam como terceiro antiepiléptico para evitar interacciones complexas',
    'TOXICIDADE CBZ + FALHA VPA — Monitorar niveles de ambos na combinación',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 105 — Lítio + diuréticos tiazídicos
  ('carbonato de litio', 'espironolactona',
    InteractionSeverity.major,
    'Os diuréticos tiazídicos e análogos (hidroclorotiazida, indapamida) reduzem a excreción renal de lítio por depleção de sódio que aumenta a reabsorción tubular de lítio; os niveles séricos de lítio aumentam 25-40%',
    'Toxicidad por lítio: tremor grosseiro, ataxia, confusão, convulsiones, insuficiencia renal, coma; janela terapéutica estreita (0.6-1.2 mEq/L)',
    'Monitorar lítio sérico 5-7 dias después de inicio do diurético e después de qualquer mudança de dosis. Reducir dosis de lítio empiricamente 25% al iniciar tiazídico. Manter hidratação adecuada e evitar dieta hiposódica',
    'TOXICIDADE LÍTIO — Tiazídicos elevam lítio 25-40%: dosagem sérica obrigatória',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 106 — Alopurinol + azatioprina
  ('alopurinol', 'azatioprina',
    InteractionSeverity.contraindicated,
    'O alopurinol inibe a xantina oxidase, principal enzima de inativação da 6-mercaptopurina (metabólito ativo da azatioprina); os niveles da 6-MP aumentam 4-5 vezes com toxicidad hematológica severa',
    'Mielossupresión grave: neutropenia profunda (<200/mm³), aplasia medular, pancitopenia fatal, infecções oportunistas',
    'Contraindicado. Se o paciente necessita de alopurinol com azatioprina: reduzir azatioprina para 25% da dosis e monitorar hemograma semanal. Alternativa: febuxostat para hiperuricemia (menor interacción, mas ainda requer precaución)',
    'CONTRAINDICADO — Alopurinol eleva azatioprina 4-5×: aplasia medular',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx, _kRefUT, _kRefFDA]),

  // 107 — Colchicina + claritromicina
  ('colchicina', 'claritromicina',
    InteractionSeverity.contraindicated,
    'A claritromicina inibe CYP3A4 e P-gp, ambas vias de eliminación da colchicina; os niveles plasmáticos aumentam 3-4 vezes com riesgo de toxicidad grave em dosiss normais',
    'Toxicidad por colchicina: diarreia severa, náuseas, dor abdominal, miopatía, neuropatia periférica, mielosupresión, insuficiência orgânica múltipla e morte',
    'Contraindicado en pacientes com IRC (colchicina já acumulada). En pacientes com función renal normal: reduzir colchicina a dosis mínima única (0.6 mg uma vez) e evitar dosiss repetidas durante o antibiótico. Informar sobre sintomas de toxicidad',
    'CONTRAINDICADO — Colchicina + Claritromicina: toxicidad múltipla de órgãos',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefMdx, _kRefUT]),

  // 108 — Ciclosporina + fluconazol
  ('ciclosporina', 'fluconazol',
    InteractionSeverity.major,
    'O fluconazol inibe CYP3A4, principal vía de metabolismo de la ciclosporina; os niveles de ciclosporina aumentam 50-200% dependendo da dosis de fluconazol',
    'Nefrotoxicidad por ciclosporina: elevación de creatinina, hipertensão arterial, hiperpotasemia; rechazo agudo se os niveles forem insuficientes al suspender o azol',
    'Reducir dosis de ciclosporina em 50% al iniciar fluconazol e monitorar nivel de ciclosporina diariamente. Objetivo: manter a mesma concentración mínima (trough) alvo. Al suspender fluconazol: aumentar ciclosporina gradualmente com monitoração',
    'NEFROTOXICIDAD — Fluconazol eleva ciclosporina 50-200%: monitorar nivel diário',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 109 — Sildenafila + nitratos
  ('sildenafila', 'nitrato',
    InteractionSeverity.contraindicated,
    'Ambos vasodilatam via óxido nítrico/GMPc: os nitratos aumentam o GMPc e a sildenafila inibe a PDE-5 que o degrada; o efecto vasodilatador é exponencialmente potenciado',
    'Hipotensión severa refratária: colapso hemodinâmico, síncope, isquemia miocárdica por hipoperfusão coronária, AVC isquêmico',
    'Contraindicação absoluta. Intervalo mínimo: 24 h después de sildenafila/vardenafila; 48 h después de tadalafila (vida media longa) antes de qualquer nitrato. Em emergência com síndrome coronária aguda: evitar nitratos; usar morfina + beta-bloqueador',
    'CONTRAINDICADO — Hipotensión fatal: Sildenafila + Nitratos',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  // 110 — Sacubitrila + IECA
  ('sacubitrila', 'enalapril',
    InteractionSeverity.contraindicated,
    'Sacubitrila inibe a neprilisina, reduzindo a degradação dos peptídeos natriuréticos e da bradicinina; os IECAs também aumentam a bradicinina por inibir a ECA; a combinación leva a acumulación de bradicinina com riesgo de angioedema grave',
    'Angioedema de língua, laringe e faringe com riesgo de asfixia; o riesgo é maior nas primeiras semanas de uso',
    'Contraindicado. Intervalo obligatorio de 36 horas entre a última dosis del IECA e a primeira dosis del sacubitril/valsartana (Entresto). Monitorar signos de angioedema nas primeiras 4 semanas de uso',
    'CONTRAINDICADO — Angioedema fatal: iniciar Entresto somente 36h después de o último IECA',
    EvidenceLevel.established,
    {RiskType.other, RiskType.respiratoryDepression},
    [_kRefFDA, _kRefGG, _kRefUT]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 4 RECUPERADO — LABA/LAMA, Roflumilast, Biológicos+Vacinas,
  // Hemostáticos, Ginecologia avançada, Miscelânea (111–130)
  // ═══════════════════════════════════════════════════════════════

  // 111 — Indacaterol (LABA) + Propranolol
  ('indacaterol', 'propranolol',
    InteractionSeverity.contraindicated,
    'Propranolol (beta-bloqueador não seletivo) antagoniza competitivamente os receptores beta-2 nos brônquios, bloqueando o efecto broncodilatador do indacaterol e podendo precipitar broncoespasmo grave en pacientes com asma/DPOC',
    'Broncoespasmo paradoxal, fracaso terapéutico do broncodilatador, crise asmática refratária com riesgo de insuficiência respiratória',
    'Contraindicado em asma. Em DPOC com indicação absoluta de beta-bloqueador (pós-IAM), usar cardioselective (bisoprolol, metoprolol) com monitoramento rigoroso da função pulmonar',
    'CONTRAINDICADO em asma — Beta-bloqueador não seletivo anula efecto do LABA',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefUT]),

  // 112 — Indacaterol (LABA) + Furosemida
  ('indacaterol', 'furosemida',
    InteractionSeverity.moderate,
    'LABAs estimulam a bomba Na-K-ATPase via AMPc, promovendo entrada de potássio nas células (hipopotasemia intracelu­lar); furosemida causa perdas renais de potássio; a combinación pode precipitar hipopotasemia acentuada e prolongación del QT',
    'Hipopotasemia sintomática (fraqueza, cãibras), arritmias cardíacas incluindo torsades de pointes, potenciación da toxicidad digitálica',
    'Monitorar potássio sérico regularmente. Suplementação de potássio se K+ < 3,5 mEq/L. Considerar potássio sérico basal antes de iniciar LABA en pacientes em uso de diuréticos de alça',
    'Monitorar potássio — LABA + furosemida: riesgo de hipopotasemia e QT longo',
    EvidenceLevel.probable,
    {RiskType.hypokalemia, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),

  // 113 — Tiotrópio (LAMA) + Amitriptilina
  ('tiotropio', 'amitriptilina',
    InteractionSeverity.moderate,
    'Efecto anticolinérgico aditivo: tiotrópio bloqueia receptores muscarínicos M1-M3 nas vias aéreas; amitriptilina tem potente atividade anticolinérgica sistêmica; a combinación soma efectos antimuscarínicos periféricos e centrais',
    'Retenção urinária, constipação intestinal grave, taquicardia, boca seca intensa, visão turva, confusión mental (especialmente en ancianos), glaucoma de ângulo fechado',
    'Usar com cautela. Preferir antidepresivos com menor perfil anticolinérgico (ISRS, venlafaxina, mirtazapina). Monitorar síntomas anticolinérgicos. Evitar em homens com HPB e en ancianos frágeis',
    'Efecto anticolinérgico aditivo — LAMA + Amitriptilina: riesgo en ancianos',
    EvidenceLevel.probable,
    {RiskType.other, RiskType.cns},
    [_kRefGG, _kRefKatz]),

  // 114 — Roflumilast + Teofilina
  ('roflumilast', 'teofilina',
    InteractionSeverity.moderate,
    'Roflumilast inibe a PDE-4, aumentando AMPc nas células inflamatórias e musculares lisas; a teofilina inibe múltiplos isotipos de PDE (1, 3, 4, 5); a inhibición aditiva da PDE-4 pode potenciar efectos adversos gastrointestinais e neurológicos',
    'Náuseas, vômitos, cefaleia, insônia, taquicardia, irritabilidade, possíveis convulsiones em dosiss elevadas de teofilina',
    'Monitorar nivel sérico de teofilina (alvo 5–15 mcg/mL). Iniciar roflumilast na dosis de 250 mcg/dia por 4 semanas antes de titular para 500 mcg/dia. Avaliar tolerabilidade gastrointestinal',
    'Inhibición PDE aditiva — Roflumilast + Teofilina: monitorar tolerabilidade',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.cns},
    [_kRefGG, _kRefUT]),

  // 115 — Roflumilast + Enoxaparina
  ('roflumilast', 'enoxaparina',
    InteractionSeverity.minor,
    'Roflumilast pode reduzir a função plaquetária via aumento de AMPc (efecto anti-agregante), somando-se ao efecto anticoagulante da enoxaparina; o riesgo hemorrágico adicional é baixo mas presente',
    'Leve aumento do riesgo de sangrado, especialmente em sítios de injeção de enoxaparina ou procedimientos invasivos',
    'Monitoramento padrão do anti-Xa se clinicamente indicado. Sem ajuste de dosis rotineiro necesario. Alertar sobre sinais de sangrado incomum',
    'Riesgo hemorrágico leve — Roflumilast + Enoxaparina: monitorar sangrado',
    EvidenceLevel.theoretical,
    {RiskType.hemorrhagic},
    [_kRefGG]),

  // 116 — Adalimumabe (biológico anti-TNF) + Vacinas vivas atenuadas
  ('adalimumabe', 'vacina_viva',
    InteractionSeverity.contraindicated,
    'Adalimumabe suprime profundamente a resposta imune mediada por TNF-alfa e linfócitos T; vacinas vivas contêm patógenos atenuados que se replicam para gerar imunidade; em imunossupresión, esses patógenos podem causar enfermedad disseminada',
    'Enfermedad disseminada pela cepa vacinal: BCGite sistêmica, varicela disseminada, poliomielite vacinal, sarampo grave; riesgo de óbito',
    'Contraindicado usar vacinas vivas durante terapia com adalimumabe ou dentro de 3 meses después de a suspensión. Vacinas inativadas (gripe inativada, pneumocócica, meningocócica) são permitidas e recomendadas. Vacinar ANTES de iniciar o biológico',
    'CONTRAINDICADO — Biológico anti-TNF + vacinas vivas: riesgo de enfermedad vacinal grave',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 117 — Ustekinumabe (anti-IL12/23) + Vacinas vivas atenuadas
  ('ustekinumabe', 'vacina_viva',
    InteractionSeverity.contraindicated,
    'Ustekinumabe bloqueia a subunidade p40 compartilhada de IL-12 e IL-23, comprometendo a imunidade mediada por células Th1 e Th17; essencial para o controle de infecções intracelulares e pelo vacinal atenuado',
    'Infecção disseminada pela cepa vacinal com riesgo de insuficiência orgânica e óbito; BCGite disseminada em caso de BCG inadvertido',
    'Contraindicado. Completar calendário vacinal com vacinas vivas pelo menos 4 semanas antes do inicio do ustekinumabe. Aguardar 15 semanas después de última dosis antes de aplicar vacinas vivas',
    'CONTRAINDICADO — Ustekinumabe + vacinas vivas: imunossupresión grave',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG]),

  // 118 — Drospirenona + Espironolactona
  ('drospirenona', 'espironolactona',
    InteractionSeverity.major,
    'Drospirenona tem atividade antiandrogênica e antimineralocorticoide análoga à espironolactona (derivada da 17-espironolactona); ambas bloqueiam receptores mineralocorticoides, causando retenção de potássio e natriurese; efecto hipercalêmico aditivo',
    'Hiperpotasemia grave (K+ > 6 mEq/L): bradicardia, fraqueza muscular, paro cardíaco; hipotensión por natriurese excessiva',
    'Contraindicar combinación de rotina. Se necesario por indicação específica, monitorar K+ sérico dentro de 1 semana e depois mensalmente. Riesgo especialmente elevado em diabéticas, renais crônicas e usuárias de IECAs/ARA-II',
    'Hiperpotasemia grave — Drospirenona + Espironolactona: efecto antimineralocorticoide aditivo',
    EvidenceLevel.probable,
    {RiskType.hyperkalemia, RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

  // 119 — Dienogest + AIES/Corticoides (inductores enzimáticos)
  ('dienogest', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina é potente inductor do CYP3A4, principal enzima responsável pelo metabolismo del dienogest; a inducción enzimática reduz drásticamente os niveles plasmáticos do progestogênio, comprometendo a eficácia anticonceptivo e terapéutica na endometriose',
    'Fracaso contraceptivo com embarazo no planificado; recurrencia de dor pélvica e lesões de endometriose por concentraciones subterapéuticas de dienogest',
    'Usar método contraceptivo não hormonal (preservativo, DIU de cobre) durante o tratamiento com rifampicina e por 28 dias después de a suspensión. Para endometriose, discutir opção terapéutica alternativa',
    'FRACASO CONTRACEPTIVO — Dienogest + Rifampicina: inducción CYP3A4 elimina eficácia',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 120 — Dienogest + Fluconazol (inhibidor CYP3A4)
  ('dienogest', 'fluconazol',
    InteractionSeverity.moderate,
    'Fluconazol inibe moderadamente o CYP3A4 e CYP2C19, reduzindo o metabolismo del dienogest; os niveles plasmáticos de dienogest podem aumentar 1,5–2x, potencializando efectos androgênicos/estrogênicos e adversos',
    'Spotting, mastalgia, cefaleia, mudanças de humor; raramente trombosis venosa en pacientes com fatores de riesgo',
    'Monitorar efectos secundarios durante tratamiento antifúngico prolongado (> 7 dias). Interacción clinicamente relevante principalmente em ciclos longos de fluconazol',
    'Niveles aumentados de dienogest — Fluconazol inibe metabolismo CYP3A4',
    EvidenceLevel.theoretical,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // 121 — Goserelina + Antidiabéticos (hipoglucemiantes)
  ('goserelina', 'insulina',
    InteractionSeverity.moderate,
    'Análogos de GnRH como goserelina causam supresión androgênica (privação hormonal) que induz resistência à insulina, intolerância à glicose e síndrome metabólica; pacientes em terapia de privação androgênica têm riesgo aumentado de diabetes e de controle glicêmico difícil',
    'Hiperglucemia, piora do controle do diabetes mellitus preexistente, necessidade ajuste de dosiss de antidiabéticos, riesgo de cetoacidosis diabética em diabetes tipo 1',
    'Monitorar glucemia em jejum e HbA1c a cada 3 meses durante terapia com goserelina. Ajustar dosiss de antidiabéticos según sea necesario. Orientar sobre dieta e exercício para minimizar impacto metabólico',
    'Resistência à insulina — Análogos GnRH (goserelina) aumentam riesgo de hiperglucemia',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

  // 122 — Ganciclovir + Micofenolato de Mofetila
  ('ganciclovir', 'micofenolato',
    InteractionSeverity.major,
    'Ambos competem pelo mesmo transportador renal tubular (proteína de transporte de nucleosídeos); micofenolato inibe a inosina monofosfato desidrogenase (IMPDH) reduzindo proliferação de linfócitos; ganciclovir pode reduzir o aclaramiento renal de micofenolato aumentando sua toxicidad; mielosupresión aditiva profunda',
    'Leucopenia grave, neutropenia, anemia, trombocitopenia; riesgo aumentado de infecções oportunistas e episódios hemorrágicos; potencial toxicidad renal aditiva',
    'Monitorar hemograma completo semanalmente nas primeiras 8 semanas, depois mensalmente. Ajustar dosis de micofenolato se leucopenia grave (< 1.000/mm³). Considerar profilaxia antifúngica e antibacteriana',
    'Mielossupresión aditiva grave — Ganciclovir + Micofenolato: monitorar hemograma',
    EvidenceLevel.probable,
    {RiskType.myelosuppression, RiskType.infection},
    [_kRefGG, _kRefUT]),

  // 123 — Caspofungina + Tacrolimus
  ('caspofungina', 'tacrolimus',
    InteractionSeverity.moderate,
    'Caspofungina induz o CYP3A4 e pode reduzir os niveles de tacrolimus em 20–25%; tacrolimus tem janela terapéutica muito estreita e variabilidade inter e intraindividual alta; a queda de niveles pode precipitar rejeição de órgão trasplantado',
    'Rechazo agudo de órgão trasplantado (rim, fígado, coração) por concentraciones subterapéuticas de tacrolimus; riesgo de pérdida del injerto',
    'Monitorar tacrolimus por cromatografia (objetivo terapéutico baseado no órgão trasplantado e fase pós-transplante). Ajustar dosis de tacrolimus durante e después de caspofungina. Aumentar frecuencia de monitoramento de C0 para diária nas primeiras 2 semanas',
    'Reducción de tacrolimus — Caspofungina induz CYP3A4: riesgo de rechazo',
    EvidenceLevel.probable,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 124 — Caspofungina + Rifampicina
  ('caspofungina', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina é potente inductor de transportadores hepáticos (OATP1B1/B3) e pode reduzir a exposición sistêmica à caspofungina em até 35% pelo aumento de sua eliminación e distribuição; mecanismo não totalmente elucidado (caspofungina não é metabolizada pelo CYP450)',
    'Falha terapéutica da caspofungina com progresión de infecção fúngica invasiva (candidemia, aspergilose); mortalidade aumentada en pacientes imunocomprometidos',
    'Quando combinación for necesaria, aumentar dosis de caspofungina para 70 mg/dia (em vez de 50 mg/dia de manutenção). Monitorar respuesta clínica, microbiológica e marcadores de infecção (galactomanana, beta-D-glucana)',
    'Reducción de caspofungina — Rifampicina: aumentar dosis para 70 mg/dia',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA, _kRefUT]),

  // 125 — Ozanimod + Diltiazem
  ('ozanimod', 'diltiazem',
    InteractionSeverity.major,
    'Ozanimod causa bradicardia e bloqueo AV pela modulação dos receptores S1P1/5 no nódulo AV, reduzindo a frecuencia cardíaca em média 8–12 bpm; diltiazem é bloqueador dos canais de cálcio com efecto cronotrópico negativo; efecto sinérgico no nódulo sinoatrial e AV',
    'Bradicardia grave (FC < 40 bpm), bloqueo AV de 2º e 3º grau, síncope, pausa sinusal, hipotensión; riesgo de parada cardiorrespiratória',
    'Contraindicação relativa. Si es indispensable, realizar ECG antes de iniciar ozanimod e no dia 1, 2 e 4 de uso. Monitorar durante 6 horas después de a primeira dosis. Considerar betabloqueador seletivo alternativo ao diltiazem se necesario antiarrítmico',
    'Bradicardia grave — Ozanimod + Diltiazem: efecto cronotrópico negativo aditivo',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  // 126 — Espironolactona + Candesartana (ARA-II)
  ('espironolactona', 'candesartana',
    InteractionSeverity.major,
    'Espironolactona bloqueia os receptores de aldosterona, promovendo retenção de potássio; candesartana (ARA-II) reduz a produção de aldosterona e aumenta o potássio sérico via bloqueio dos receptores AT1 da angiotensina II; hiperpotasemia sinérgica',
    'Hiperpotasemia grave (K+ > 6 mEq/L): arritmias letais (fibrilación ventricular, asistolia), fraqueza muscular progressiva, parestesias, paro cardíaco',
    'Monitorar K+ e creatinina dentro de 1–2 semanas después de inicio da combinación e depois mensalmente. Alvo K+ < 5,0 mEq/L. Riesgo especialmente alto en pacientes com IRC, diabetes e idosos. Esta combinación é frecuentemente necesaria em ICC com disfunción renal — titular cautelosamente',
    'Hiperpotasemia grave — Espironolactona + ARA-II: monitorar K+ semanalmente',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.cardiovascular},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 127 — Evolocumabe (iPCSK9) + Sinvastatina
  ('evolocumabe', 'sinvastatina',
    InteractionSeverity.minor,
    'Evolocumabe não possui interacciones farmacocinéticas significativas com sinvastatina (via subcutânea, sem metabolismo CYP hepático relevante); a combinación é intencional e recomendada nas diretrizes para pacientes de alto riesgo cardiovascular que não atingem LDL-alvo com estatina máxima tolerada',
    'Potencial aditivo de reducción de LDL (60–70% adicional com evolocumabe sobre estatina); reacciones no local de injeção; raramente mialgias',
    'Combinación segura e recomendada. Medir LDL 4–8 semanas después de inicio do evolocumabe para confirmar resposta. Continuar estatina na dosis máxima tolerada',
    'Combinación segura e recomendada — Evolocumabe + Estatina: LDL-alvo mais alcançável',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 128 — Volanesorsen + Anticoagulantes
  ('volanesorsen', 'varfarina',
    InteractionSeverity.moderate,
    'Volanesorsen (oligonucleotídeo antisense anti-APO-C3) pode causar trombocitopenia grave como efecto adverso de classe dos oligonucleotídeos antisense; en pacientes anticoagulados com varfarina, a plaquetopenia aumenta sinergicamente o riesgo hemorrágico',
    'Sangrado grave por trombocitopenia (< 50.000/mm³) associada a anticoagulação: hemorragia intracraniana, sangrado gastrointestinal maciço, hemoperitônio',
    'Contraindicado se plaquetas < 140.000/mm³ antes de iniciar volanesorsen. Monitorar contagem plaquetária a cada 2 semanas durante os primeiros 3 meses. Suspender volanesorsen se plaquetas < 75.000/mm³. Ajustar dosis de varfarina e monitorar INR mais frecuentemente',
    'Trombocitopenia + anticoagulação — Volanesorsen: riesgo hemorrágico grave',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.myelosuppression},
    [_kRefFDA, _kRefGG]),

  // 129 — Roxadustate (inhibidor HIF-PH) + Varfarina
  ('roxadustate', 'varfarina',
    InteractionSeverity.major,
    'Roxadustate inibe o CYP2C9 e a enzima HIF prolil-hidroxilase; como a varfarina é metabolizada principalmente pelo CYP2C9 (S-varfarina, mais potente), a inhibición aumenta significativamente os niveles de S-varfarina e o efecto anticoagulante; INR pode aumentar 30–40%',
    'Sangrado grave por supracoagulação: hemorragia intracraniana, digestiva maciça, retroperitoneal; INR suprateapêutico (> 4)',
    'Monitorar INR com maior frecuencia al iniciar ou suspender roxadustate (a cada 3 dias na primeira semana, depois semanalmente por 4 semanas). Ajustar dosis de varfarina com base no INR. Considerar anticoagulante não warfarínico (DOAC) en pacientes renais crônicos com TFG adecuado',
    'INR aumentado 30–40% — Roxadustate inibe CYP2C9: ajustar varfarina urgente',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 130 — Ferro Sacarato IV + Cefalosporinas (quelação)
  ('ferro_sacarato', 'ceftriaxona',
    InteractionSeverity.minor,
    'O ferro intravenoso não apresenta interacción farmacocinética clinicamente significativa com cefalosporinas; no entanto, ferro dextrano pode formar complexos com algumas drogas se infundido simultáneamente no mesmo acesso venoso',
    'Formação de precipitado ou complexo insoluble se misturado no mesmo equipo IV; potencial reducción de la atividade antibiótica',
    'Não infundir ferro IV simultáneamente no mesmo acesso que antibióticos. Usar via IV separada ou flush com SF 0,9% entre infusões. Ferro sacarato e gluconato de ferro têm menor riesgo que dextrano',
    'Não misturar na mesma via — Ferro IV + Antibióticos: usar vias separadas',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 6 — Procinéticos, Antieméticos, Antifúngicos avançados,
  // Antituberculosos avançados, Miscelânea (131–160)
  // ═══════════════════════════════════════════════════════════════

  // 131 — Metoclopramida + ISRS (Serotonina)
  ('metoclopramida', 'fluoxetina',
    InteractionSeverity.major,
    'Metoclopramida antagoniza receptores D2 e tem efecto agonista serotoninérgico (5-HT4); ISRS inibem a recaptação de serotonina; a combinación pode precipitar síndrome serotoninérgica, especialmente em dosiss elevadas ou uso prolongado; metoclopramida também inibe o CYP2D6 que metaboliza fluoxetina',
    'Síndrome serotoninérgica: tremor, agitação, confusão, hiperreflexia, mioclonias, sudorese, taquicardia, hipertermia; casos graves com rabdomiólisis e insuficiência de múltiplos órgãos',
    'Evitar uso concomitante prolongado. Se necesario para náuseas agudas, limitar a dosiss únicas e curtos períodos. Preferir ondansetrona (antagonista 5-HT3) para náuseas en pacientes em ISRS. Monitorar signos de toxicidad serotoninérgica',
    'Síndrome serotoninérgica — Metoclopramida + ISRS: preferir ondansetrona',
    EvidenceLevel.probable,
    {RiskType.serotonin, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 132 — Metoclopramida + Antipsicóticos (efecto extrapiramidal)
  ('metoclopramida', 'haloperidol',
    InteractionSeverity.major,
    'Ambos bloqueiam receptores D2 dopaminérgicos no sistema nigroestriatal e mesolímbico; a combinación causa bloqueio dopaminérgico aditivo no estriado, aumentando drásticamente o riesgo de reacciones extrapiramidais agudas',
    'Distonia aguda (torcicolo, crise oculogírica, trismo), acatisia, parkinsonismo farmacológico agudo; raramente síndrome neuroléptica maligna com hipertermia e rigidez',
    'Contraindicar combinación de rotina. Se antiemético for necesario em paciente em antipsicótico, preferir ondansetrona. Se ocorrer distonia aguda, administrar biperideno 5 mg IM ou difenidramina IV',
    'Extrapiramidal grave — Metoclopramida + Antipsicótico: antagonismo D2 aditivo',
    EvidenceLevel.established,
    {RiskType.cns},
    [_kRefGG, _kRefKatz]),

  // 133 — Domperidona + Amiodarona (QT)
  ('domperidona', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Domperidona bloqueia canais hERG (IKr) de forma dosis-dependente, prolongando o intervalo QT; amiodarona também prolonga o QTc por múltiplos mecanismos (bloqueio IKr, IKs, INa); a combinación causa prolongamento aditivo do QT com alto riesgo de torsades de pointes',
    'Torsades de pointes (TV polimórfica), fibrilación ventricular, morte súbita cardíaca; QTc > 500 ms',
    'Contraindicado. Amiodarona consta como fármaco contraindicado com domperidona nas bulas europeias. Usar metoclopramida (com cautela) ou ondansetrona como alternativas. Monitorar ECG se combinación inadvertida ocorrer',
    'CONTRAINDICADO — Domperidona + Amiodarona: QT longo fatal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA, _kRefUT]),

  // 134 — Domperidona + Claritromicina (QT + inhibición CYP)
  ('domperidona', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina é potente inhibidor do CYP3A4, principal vía de metabolismo de la domperidona; a inhibición aumenta a exposición sistêmica à domperidona em 3–4x; claritromicina também prolonga o QT por bloqueio hERG; efecto duplo (farmacocinético + farmacodinâmico) no prolongación del QT',
    'QTc > 500 ms, torsades de pointes, fibrilación ventricular, morte súbita; riesgo especialmente elevado en ancianos, hipocalêmicos e com cardiopatia de base',
    'Combinación formalmente contraindicada pelas agências regulatórias. Usar alternativa para náuseas (ondansetrona, metoclopramida em dosis única). Usar azitromicina ou doxiciclina em vez de claritromicina si es posible',
    'CONTRAINDICADO — Domperidona + Claritromicina: QT fatal + inhibición CYP3A4',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 135 — Ondansetrona + Tramadol (5-HT3 + serotonina)
  ('ondansetron', 'tramadol',
    InteractionSeverity.moderate,
    'Ondansetrona antagoniza receptores 5-HT3 que são parcialmente responsáveis pela analgesia do tramadol; além de reduzir a analgesia, o tramadol inibe a recaptação de serotonina e o bloqueio 5-HT3 pela ondansetrona pode paradoxalmente aumentar a atividade serotoninérgica em outros receptores (5-HT1A, 5-HT2); efecto complexo no equilíbrio serotoninérgico',
    'Reducción de la eficacia analgésica do tramadol (necessidade dosiss maiores); síndrome serotoninérgica paradoxal em dosis altas; prolongación del QT (ambos prolongam o QTc)',
    'Usar com cautela e monitorar eficácia analgésica. Considerar alternativas analgésicas en pacientes em ondansetrona. Preferir granisetron ou palonosetrona (menor interacción) como antieméticos alternativos. Monitorar ECG se QTc basal elevado',
    'Reducción de la analgesia + riesgo QT — Ondansetrona + Tramadol: interacción dual',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.qtProlongation, RiskType.serotonin},
    [_kRefGG, _kRefMdx]),

  // 136 — Prucaloprida + Antifúngicos azólicos (CYP3A4)
  ('prucalopride', 'ketoconazol',
    InteractionSeverity.moderate,
    'Prucaloprida é agonista seletivo 5-HT4 metabolizada parcialmente pelo CYP3A4 e excretada principalmente pelos rins; cetoconazol, como potente inhibidor do CYP3A4, pode aumentar a exposición sistêmica à prucaloprida em ~40%; efecto clinicamente moderado dado o papel menor do CYP3A4 na eliminación total',
    'Diarreia, cólicas abdominais, cefaleia, palpitações por concentraciones aumentadas de prucaloprida',
    'Monitorar efectos gastrointestinais durante uso concomitante. Iniciar com dosis menor de prucaloprida (1 mg/dia) em vez de 2 mg/dia se necesario. Azóis tópicos ou fluconazol em dosis única têm menor impacto',
    'Exposición aumentada de prucaloprida — Azóis inibem CYP3A4: reducir dosis',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // 137 — Voriconazol + Sirolimus (inhibición CYP extrema)
  ('voriconazol', 'sirolimus',
    InteractionSeverity.contraindicated,
    'Voriconazol é potentíssimo inhibidor do CYP3A4 e CYP2C19; sirolimus (rapamicina) é substrato exclusivo do CYP3A4 com janela terapéutica extremamente estreita; a inhibición causa aumento de 10–11x nos niveles de sirolimus, uma das interacciones de maior magnitude clínica descrita',
    'Toxicidade grave de sirolimus: pneumonite intersticial, trombocitopenia, anemia, hipertrigliceridemia, insuficiencia renal aguda, infecções oportunistas, cicatrização prejudicada',
    'Combinación contraindicada pelas bulas. Se antifúngico azólico for indispensable em trasplantado em sirolimus, suspender o sirolimus e trocar por tacrolimus (menor interacción) ou anfotericina B lipossomal como antifúngico alternativo',
    'CONTRAINDICADO — Voriconazol + Sirolimus: 10x aumento de sirolimus = toxicidad letal',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.nephrotoxicity, RiskType.myelosuppression},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 138 — Voriconazol + Varfarina
  ('voriconazol', 'varfarina',
    InteractionSeverity.major,
    'Voriconazol inibe intensamente o CYP2C9 (e CYP3A4 e CYP2C19); o CYP2C9 é responsável pela metabolização da S-varfarina (forma farmacologicamente mais potente); a inhibición aumenta os niveles de S-varfarina em 2–3x, amplificando o efecto anticoagulante dramaticamente',
    'Sangrado grave e potencialmente fatal: hemorragia intracraniana, gastrointestinal maciça, retroperitoneal; INR pode dobrar ou triplicar dentro de 48–72 horas do inicio do voriconazol',
    'Monitorar INR a cada 2–3 dias durante co-administração. Reducir dosis de varfarina em 30–50% al iniciar voriconazol. Al suspender voriconazol, reajustar varfarina com monitoramento diário por 1 semana. Considerar heparina como ponte se INR instável',
    'INR dobra/triplica — Voriconazol + Varfarina: monitorar INR a cada 2 dias',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT, _kRefMdx]),

  // 139 — Posaconazol + Ciclosporina
  ('posaconazol', 'ciclosporina',
    InteractionSeverity.major,
    'Posaconazol inibe o CYP3A4 e a P-glicoproteína (P-gp); ciclosporina é substrato de ambos; a inhibición aumenta os niveles de ciclosporina em 1,5–2x; ciclosporina tem janela terapéutica estreita com nefrotoxicidad e neurotoxicidad dependentes de concentración',
    'Nefrotoxicidad por ciclosporina (creatinina elevada, oligúria, síndrome hemolítico-urêmica); neurotoxicidad (tremor, encefalopatía, convulsiones); hepatotoxicidad por acumulación',
    'Monitorar niveles de ciclosporina (C0) dentro de 2–3 dias después de inicio do posaconazol. Reducir dosis de ciclosporina em ~25% preventivamente. Manter monitoramento diário de función renal nas primeiras 2 semanas',
    'Nefrotoxicidad de ciclosporina — Posaconazol aumenta niveles 1,5–2x',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 140 — Anfotericina B + Aminoglicosídeos (nefrotoxicidad)
  ('anfotericina', 'gentamicina',
    InteractionSeverity.major,
    'Anfotericina B causa nefrotoxicidad por alteração da permeabilidade membranas celulares tubulares renais, reducción del fluxo sanguíneo renal e hipopotasemia/hipomagnesemia induzida; aminoglicosídeos causam nefrotoxicidad por acumulación no córtex renal com dano tubular proximal; efecto nefrotóxico sinérgico',
    'Insuficiencia renal aguda grave, oligúria, hipopotasemia, hipomagnesemia, necrose tubular aguda; pode ser necesaria terapia renal substitutiva',
    'Evitar combinación sempre que posible. Si es indispensable em infecção grave, monitorar creatinina, K+ e Mg++ diariamente. Assegurar hidratação adecuada (200–500 mL SF antes de cada dosis de anfotericina). Usar anfotericina B lipossomal (menor nefrotoxicidad que convencional). Monitorar nivel de aminoglicosídeo',
    'Nefrotoxicidad sinérgica grave — Anfotericina + Aminoglicosídeo: monitorar renal diário',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 141 — Rifampicina + Fluconazol (antagonismo + inducción)
  ('rifampicina', 'fluconazol',
    InteractionSeverity.major,
    'Rifampicina é potente inductor do CYP2C9 e CYP3A4, principais enzimas de metabolismo del fluconazol; a inducción reduz os niveles de fluconazol em 22–25%, comprometendo a eficácia antifúngica; paradoxalmente, fluconazol inibe o CYP2C9 que metaboliza compostos do próprio regime antituberculoso',
    'Falha terapéutica do fluconazol com progresión de infecção fúngica; interacciones complexas com outros fármacos antifúngicos e antibióticos do regime TB',
    'Considerar aumentar dosis de fluconazol para 800 mg/dia (padrão habitual 400 mg/dia) em infecções graves. Monitorar respuesta clínica e microbiológica semanal. Para criptococose em TB: posaconazol IV pode ser alternativa com menor inducción',
    'Fracaso antifúngico — Rifampicina reduz fluconazol 25%: aumentar dosis para 800 mg',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 142 — Isoniazida + Fenitoína (inhibición CYP2C9)
  ('isoniazida', 'fenitoina',
    InteractionSeverity.major,
    'Isoniazida é inhibidor do CYP2C9 (via inhibición del citocromo P450 hepático); fenitoína é substrato primário do CYP2C9 com janela terapéutica estreita; a inhibición pode aumentar os niveles de fenitoína em 2–5x, gerando toxicidad grave; acetiladores lentos de isoniazida têm maior riesgo',
    'Toxicidad por fenitoína: nistagmo, ataxia, diplopia, confusión mental, sonolência, convulsiones paradoxais por toxicidad; encefalopatía em casos graves',
    'Monitorar nivel sérico de fenitoína (alvo 10–20 mcg/mL) na primeira semana después de inicio da isoniazida e depois mensalmente. Reducir dosis de fenitoína em ~25% preventivamente. Dosagem frecuente en pacientes acetiladores lentos (índice étnico: africanos, asiáticos têm maior proporção)',
    'Toxicidad de fenitoína — Isoniazida inibe CYP2C9: monitorar nivel semanalmente',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 143 — Etambutol + Hidróxido de Alumínio (absorción)
  ('etambutol', 'hidróxido_alumínio',
    InteractionSeverity.moderate,
    'Antácidos contendo alumínio formam complexos de quelação com o etambutol no trato gastrointestinal, reduzindo sua absorción oral em 10–28%; o alumínio se liga ao etambutol formando quelatos não absorvíveis; a biodisponibilidad reducida pode comprometer a eficácia antituberculosa',
    'Concentraciones subterapéuticas de etambutol com riesgo de fracaso terapéutica no tratamiento da tuberculose; maior riesgo de resistência a etambutol',
    'Administrar etambutol pelo menos 4 horas antes ou 2 horas después de os antiácidos contendo alumínio ou magnésio. Orientar al paciente sobre o intervalo necesario. Horários fixos ajudam na adesão',
    'Reducción de absorción do etambutol — Separar 4 horas de antiácidos com alumínio',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 144 — Pirazinamida + Alopurinol
  ('pirazinamida', 'alopurinol',
    InteractionSeverity.moderate,
    'Pirazinamida reduz a excreción renal de ácido úrico ao inibir a uricase tubular, causando hiperuricemia e precipitando crises de gota; alopurinol inibe a xantina oxidase, reduzindo a síntese de ácido úrico; os dois mecanismos se opõem mas a interacción é complexa: pirazinamida pode superar o efecto do alopurinol em dosiss terapéuticas de TB',
    'Persistência de hiperuricemia e crises gotosas apesar do uso de alopurinol; necessidade dosiss maiores de uricostático; raramente gota poliarticular grave',
    'Aumentar dosis de alopurinol se necesario (até 600–800 mg/dia). Monitorar ácido úrico sérico mensalmente durante regime com pirazinamida. Em crises de gota, usar colchicina (cautela com interacciones) ou corticoide oral de curta duración',
    'Hiperuricemia resistente — Pirazinamida supera efecto do alopurinol: monitorar uricemia',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefMdx]),

  // 145 — Bedaquilina + Moxifloxacino (QT aditivo)
  ('bedaquilina', 'moxifloxacino',
    InteractionSeverity.major,
    'Bedaquilina bloqueia a ATP sintase da micobactéria e prolonga o QT por mecanismo não totalmente elucidado (não é hERG); moxifloxacino prolonga o QT por bloqueio dos canais hERG (IKr) de forma dosis-dependente; a combinación prolonga o QTc de forma aditiva, com riesgo substancial de torsades de pointes en pacientes com TB-MR',
    'Prolongación del QTc > 500 ms, torsades de pointes, fibrilación ventricular, morte súbita; riesgo elevado em desnutridos, hipocalêmicos e com cardiopatia de base (comuns em TB-MR)',
    'ECG obligatorio antes, ao 2 e 12 semanas, e mensalmente. Se QTc > 480 ms, revisar electrolitos e todos os fármacos que prolongam QT. Se QTc > 500 ms, suspender bedaquilina. Manter K+ > 4 mEq/L e Mg++ > 0,8 mEq/L durante toda a terapia',
    'QT longo grave — Bedaquilina + Moxifloxacino: ECG obligatorio quinzenal',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 146 — Delamanida + Claritromicina (QT + inhibición CYP)
  ('delamanida', 'claritromicina',
    InteractionSeverity.major,
    'Delamanida (nitroimidazol para TB-MR) prolonga o QT por bloqueio dos canais IKr; claritromicina prolonga o QT e inibe o CYP3A4, responsável pelo metabolismo del metabólito ativo da delamanida; o resultado é aumento da exposición ao metabólito ativo e maior prolongación del QT',
    'QTc > 500 ms, torsades de pointes, morte súbita en pacientes com TB-MR; interacción de alto riesgo en pacientes já com comprometimento metabólico',
    'Evitar combinación. Se necesario antibiótico para TB-MR com infecção bacteriana sobreposta, considerar azitromicina (menor riesgo de QT que claritromicina, sem inhibición CYP3A4). Monitorar ECG semanalmente se combinación inevitável',
    'QT fatal — Delamanida + Claritromicina: prolongamento QT aditivo + inhibición metabólica',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  // 147 — Linezolida + Triptofano/Suplementos (serotonina)
  ('linezolida', 'triptofano',
    InteractionSeverity.major,
    'Linezolida é inhibidor fraco mas clinicamente relevante da MAO-A; o triptofano (aminoácido precursor da serotonina) aumenta a disponibilidade serotonina; a inhibición de la MAO-A reduz a degradação da serotonina endógena e da proveniente do triptofano, podendo precipitar síndrome serotoninérgica',
    'Síndrome serotoninérgica: tremor, agitação, diarreia, hiperreflexia, mioclonia, hipertermia; casos graves com colapso hemodinâmico',
    'Evitar suplementos de triptofano e alimentos ricos em tiramina durante linezolida. Orientar al paciente sobre restrições dietéticas (queijos maturados, vinho tinto, embutidos). Monitorar signos de toxicidad serotoninérgica',
    'Síndrome serotoninérgica — Linezolida (IMAO) + Triptofano: restringir dieta',
    EvidenceLevel.probable,
    {RiskType.serotonin},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 148 — Ceftolozano/Tazobactam + Piperacilina/Tazobactam (redundância)
  ('ceftolozane', 'piperacilina',
    InteractionSeverity.minor,
    'Ceftolozano/tazobactam e piperacilina/tazobactam não têm interacción farmacocinética ou farmacodinâmica sinérgica clinicamente relevante; ambos contêm tazobactam (inhibidor de betalactamases), sendo a combinación desnecesaria e potencialmente geradora de resistência ao tazobactam por saturação',
    'Sem toxicidad adicional esperada; uso redundante de tazobactam sem benefício clínico comprovado; riesgo teórico de seleção de resistência',
    'No combinar de rotina. Cada um tem espectro específico: ceftolozano é dirigido a Pseudomonas MDR; piperacilina cobre Gram-negativos sensíveis. Selecionar o mais adecuado ao perfil de sensibilidade e evitar uso simultâneo',
    'Redundância de tazobactam — No combinar ceftolozano + pip-tazo: espectro sobrepostos',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),

  // 149 — Fosfomicina + Metotrexato
  ('fosfomicina', 'metotrexato',
    InteractionSeverity.moderate,
    'Fosfomicina pode reduzir a excreción renal tubular do metotrexato por competição pelo mesmo transportador (OAT1/OAT3); como o metotrexato tem janela terapéutica estreita e é excretado principalmente pelos rins, qualquer reducción no clearance aumenta o riesgo de toxicidad grave',
    'Mucosita oral grave, pancitopenia, insuficiencia renal aguda, hepatotoxicidad por acumulación de metotrexato; riesgo especialmente alto em dosis altas de metotrexato para oncologia',
    'Monitorar nivel de metotrexato nas dosiss oncológicas. Para dosiss reumatológicas baixas (7,5–25 mg/semana), o riesgo é menor mas manter vigilancia. Assegurar hidratação adecuada e alcalinização urinária. Evitar fosfomicina IV en pacientes com metotrexato em dosis alta',
    'Acumulación de metotrexato — Fosfomicina pode reduzir aclaramiento renal: monitorar nivel',
    EvidenceLevel.theoretical,
    {RiskType.nephrotoxicity, RiskType.myelosuppression},
    [_kRefGG]),

  // 150 — Daptomicina + HMG-CoA Redutase (rabdomiólisis aditiva)
  ('daptomicina', 'rosuvastatina',
    InteractionSeverity.major,
    'Daptomicina causa miotoxicidad por inserção nas membranas celulares dos miócitos, com riesgo de miopatía e rabdomiólisis; estatinas inibem a síntese do CoQ10 e do colesterol de membrana, aumentando a vulnerabilidade muscular à lesão; a combinación tem efecto miotóxico sinérgico, com maior riesgo para rosuvastatina (maior potência)',
    'Miopatía grave, rabdomiólisis com CK > 10x o limite superior, mioglobinúria, insuficiencia renal aguda por nefropatia pigmentar',
    'Suspender estatina enquanto durar o tratamiento com daptomicina (generalmente 4–6 semanas). Monitorar CK no inicio, semanalmente durante a daptomicina e 1 semana después de a suspensión. Se CK > 5x LSN: suspender daptomicina. Manter hidratação adecuada',
    'Rabdomiólisis aditiva — Suspender estatina durante tratamiento com daptomicina',
    EvidenceLevel.established,
    {RiskType.myopathy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 151 — Meropeném + Ácido Valpróico (reducción de valproato)
  ('meropenem', 'valproato',
    InteractionSeverity.major,
    'Carbapenêmicos (imipeném, meropeném, ertapeném) reduzem os niveles de valproato em 40–90% por mecanismo multifatorial: inhibición de la absorción intestinal, aumento da eliminación renal do valproato-glucuronídeo (que é convertido de volta ao valproato) e possivelmente inhibición hepática da conversão do metabólito ao valproato ativo',
    'Perda do controle de crisis epilépticas com niveles subterapéuticos de valproato; crises tônico-clônicas generalizadas; estado de mal epiléptico em casos graves',
    'Contraindicar combinación si es posible. Se carbapenêmico for indispensable em epiléptico controlado com valproato, planejar terapia antiepiléptica alternativa inmediatamente (levetiracetam, lacosamida). Monitorar nivel de valproato a cada 24–48 horas. A interacción inicia em 24 horas e pode persistir por dias después de a suspensión do carbapenêmico',
    'CONTRAINDICADO em epilépticos — Meropeném reduz valproato até 90%: crisis epilépticas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.seizure},
    [_kRefGG, _kRefKatz, _kRefMdx, _kRefUT]),

  // 152 — Colistina + Polimixina B (nefrotoxicidad aditiva)
  ('colistina', 'polimixina_b',
    InteractionSeverity.contraindicated,
    'Colistina (polimixina E) e polimixina B são antibióticos do mesmo grupo (polimixinas) com mecanismo de ação e toxicidad idênticos: ruptura da membrana celular bacteriana por interacción com lipopolissacarídeos; ambas causam nefrotoxicidad dosis-dependente e neurotoxicidad; a combinación não tem benefício adicional e duplica o riesgo tóxico',
    'Nefrotoxicidad grave com insuficiencia renal aguda (incidência de 50–60% com monoterapia, maior com combinación); neurotoxicidad com parestesias, ataxia, bloqueio neuromuscular',
    'Nunca combinar duas polimixinas. Selecionar uma para uso baseado em disponibilidade e vias de administração (colistina IV e inalatória; polimixina B IV). Ajustar dosis renal rigurosamente. Monitorar creatinina e urina diariamente',
    'CONTRAINDICADO — Duas polimixinas: nefrotoxicidad e neurotoxicidad duplicadas',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA]),

  // 153 — Linezolida + Metformina
  ('linezolida', 'metformina',
    InteractionSeverity.moderate,
    'Linezolida inibe fracamente a MAO mitocondrial; metformina actua nas mitocôndrias inibindo o complexo I da cadeia respiratória; a combinación pode potenciar o riesgo de acidosis láctica por comprometimento adicional do metabolismo mitocondrial e acumulación de lactato; mecanismo hipotético mas com casos clínicos descritos',
    'Acidosis láctica (pH < 7,35, lactato > 5 mmol/L): náuseas, dor abdominal, fraqueza muscular, taquipneia, hipotensión; mortalidade 30–50% em casos graves',
    'Monitorar lactato sérico se combinación necesaria en pacientes com fatores de riesgo (insuficiencia renal, hepática, etilismo). Considerar suspender metformina durante cursos prolongados de linezolida (> 10 dias). Não há necessidade suspensión preventiva em todos os casos',
    'Acidosis láctica potencial — Linezolida + Metformina: monitorar lactato em fatores de riesgo',
    EvidenceLevel.possible,
    {RiskType.other, RiskType.hepatotoxicity},
    [_kRefGG, _kRefMdx]),

  // 154 — Vancomicina + Piperacilina-Tazobactam (nefrotoxicidad)
  ('vancomicina', 'piperacilina',
    InteractionSeverity.major,
    'Estudos farmacoepidemiológicos e metanálises demonstraram que a combinación de vancomicina com piperacilina/tazobactam aumenta o riesgo de lesão renal aguda (LRA) em 2–3x em comparação com vancomicina com outros beta-lactâmicos; o mecanismo exato é debatido: posible inhibición del transportador OAT por tazobactam aumentando a concentración intratubular de vancomicina',
    'Insuficiencia renal aguda (creatinina > 0,5 mg/dL acima do basal ou aumento > 50%); oligúria; necessidade terapia renal substitutiva em casos graves; a LRA ocorre em média no dia 4–6 de combinación',
    'Si es posible, preferir cefepima ou meropeném como partner de vancomicina em sepse grave. Se pip-tazo for necesario, monitorar creatinina diariamente. Usar vancomicina AUC-guided (meta AUC/MIC 400–600) em vez de monitoramento de vale tradicional. Hidratação adecuada',
    'Nefrotoxicidad 3x maior — Vancomicina + Pip-Tazo: preferir cefepima como partner',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 155 — Budesonida inalatória + Itraconazol (corticoide sistêmico)
  ('budesonida', 'itraconazol',
    InteractionSeverity.major,
    'Itraconazol inibe potentemente o CYP3A4 no intestino e fígado; budesonida inalatória passa pelo efecto de primeira passagem, e a porção deglutida (30–40%) sofre extenso metabolismo CYP3A4 intestinal; com a inhibición, os niveles sistêmicos de budesonida podem aumentar 4–6x, causando efectos sistêmicos do corticoide',
    'Síndrome de Cushing iatrogênica: aumento de peso, face em lua, estrias, hiperglucemia, hipertensão, osteoporose acelerada, supresión do eixo HPA com insuficiencia adrenal al suspender o corticoide',
    'Evitar itraconazol en pacientes em budesonida inalatória de alta dosis. Se necesario antifúngico sistêmico, preferir anfotericina B IV (sem interacción CYP) ou ajustar para menor dosis de budesonida. Monitorar signos de Cushing e função adrenal',
    'Síndrome de Cushing — Itraconazol + Budesonida inalatória: niveles 4–6x maiores',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 156 — Dexametasona + Ciclosporina (efecto bidirecional)
  ('dexametasona', 'ciclosporina',
    InteractionSeverity.major,
    'Interacción bidireccional: dexametasona induz o CYP3A4 reduzindo os niveles de ciclosporina (riesgo de rechazo); por outro lado, a ciclosporina inibe o CYP3A4 podendo aumentar os niveles sistêmicos de dexametasona; o resultado líquido depende das dosiss relativas e da duración do uso',
    'Rechazo agudo de transplante por queda nos niveles de ciclosporina; ou efectos cushingoides exacerbados por acumulación de dexametasona; imunossupresión excessiva',
    'Monitorar nivel de ciclosporina (C0) rigurosamente durante uso concomitante de dexametasona. Ajustar dosis de ciclosporina conforme. Después de suspensión da dexametasona, re-monitorar ciclosporina pois os niveles podem aumentar',
    'Interacción bidireccional — Dexametasona + Ciclosporina: monitorar C0 em ambas as direções',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 157 — Prednisona + Antiácidos (absorción)
  ('prednisona', 'hidróxido_alumínio',
    InteractionSeverity.minor,
    'Antiácidos contendo alumínio e magnésio podem reduzir ligeiramente a absorción oral de corticoides, formando complexos que retardam a dissolução do comprimido; o efecto é pequeno e clinicamente relevante apenas com uso crônico e altas dosiss',
    'Leve reducción na biodisponibilidad do corticoide; raramente impacto clínico significativo em dosiss terapéuticas habituais',
    'Separar a administração do corticoide dos antiácidos em pelo menos 2 horas. Em uso crônico de corticoide em dosis altas, preferir inhibidor de bomba de prótons (protección gástrica) em vez de antiácido com alumínio',
    'Absorción leve reducida — Prednisona + Antiácidos: separar 2 horas',
    EvidenceLevel.possible,
    {RiskType.reducedEfficacy},
    [_kRefGG]),

  // 158 — Hidrocortisona IV + Ampicilina (inativação Y-site)
  ('hidrocortisona', 'ampicilina',
    InteractionSeverity.minor,
    'Hidrocortisona e ampicilina são fisicamente incompatíveis quando misturadas na mesma solução ou Y-site em concentraciones elevadas: a alcalinidade da ampicilina pode acelerar a degradação da hidrocortisona; a mistura pode causar turvação e formação de precipitado',
    'Reducción na eficácia de ambos os fármacos por degradação química; obstrução de cateteres IV por precipitado',
    'Não misturar na mesma bolsa de infusão. Se usar Y-site simultâneo, verificar compatibilidade farmacêutica para as concentraciones específicas. Preferencialmente, administrar em vias separadas',
    'Incompatibilidade física — Hidrocortisona IV + Ampicilina: usar vias separadas',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),

  // 159 — Mometasona intranasal + Cetoconazol oral
  ('mometasona', 'cetoconazol',
    InteractionSeverity.moderate,
    'Cetoconazol sistêmico inibe intensamente o CYP3A4; mometasona, mesmo por via intranasal, tem metabolismo de primeira passagem CYP3A4 para a porção absorvida sistemicamente; os niveles sistêmicos de mometasona podem aumentar, causando efectos corticosteroidais sistêmicos',
    'Supresión adrenal, síndrome de Cushing, hiperglucemia, osteoporose acelerada; riesgo maior em crianças e usuários de dosis altas de mometasona intranasal',
    'Evitar cetoconazol oral sistêmico em usuários de mometasona. Usar fluconazol tópico ou anfotericina B tópica para candidíase oral/esofágica. Se antifúngico sistêmico for necesario, escolher terbinafina (sem interacción CYP3A4) para infecções cutâneas',
    'Supresión adrenal — Cetoconazol sistêmico + Mometasona: evitar combinación',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  // 160 — Mizolastina + Amiodarona (QT)
  ('mizolastina', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Mizolastina (anti-histamínico H1 de segunda geração) prolonga o intervalo QT por bloqueio dos canais hERG (IKr), de forma semelhante à terfenadina (precursor que causou mortes por arritmia); amiodarona prolonga agresivamente o QT por múltiplos mecanismos; combinación com riesgo de torsades de pointes muito elevado',
    'QTc > 500 ms, torsades de pointes, fibrilación ventricular, morte súbita; casos fatais documentados com anti-histamínicos que prolongam QT associados a antiarrítmicos classe III',
    'Contraindicado. Anti-histamínicos seguros en pacientes com amiodarona: cetirizina, loratadina, fexofenadina (sem efecto no QT). Evitar todos os anti-histamínicos com riesgo de QT (mizolastina, astemizol, terfenadina)',
    'CONTRAINDICADO — Mizolastina + Amiodarona: QT fatal (mesma classe da terfenadina)',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA, _kRefUT]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 7 — Cardiovascular avançado, Insuficiencia cardíaca,
  // Ginecologia avançada, Neurologia (161–190)
  // ═══════════════════════════════════════════════════════════════

  // 161 — Ivabradina + Diltiazem (bradicardia sinérgica)
  ('ivabradina', 'diltiazem',
    InteractionSeverity.contraindicated,
    'Ivabradina reduz a frecuencia cardíaca por bloqueio seletivo dos canais If no nódulo sinusal (HCN4); diltiazem é inhibidor dos canais de cálcio com efecto cronotrópico negativo significativo e, adicionalmente, inibe o CYP3A4 responsável pelo metabolismo de la ivabradina, aumentando sua exposición em 2–3x; duplo mecanismo de bradicardia (farmacodinâmico + farmacocinético)',
    'Bradicardia sintomática grave (FC < 40 bpm), bloqueo AV, síncope, hipotensión grave; riesgo de parada cardiorrespiratória',
    'Contraindicado. Diuréticos ou hidralazina como alternativas para manejo da ICC se necesario. Se beta-bloqueador e ivabradina forem usados, monitorar FC rigurosamente. Nunca combinar ivabradina com diltiazem ou verapamil',
    'CONTRAINDICADO — Ivabradina + Diltiazem: bradicardia grave (PK + PD)',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 162 — Ivabradina + Claritromicina (inhibición CYP3A4 severa)
  ('ivabradina', 'claritromicina',
    InteractionSeverity.contraindicated,
    'Claritromicina é potente inhibidor do CYP3A4 e aumenta a exposición à ivabradina em até 7x; com concentraciones tão elevadas de ivabradina, o riesgo de bradicardia grave e bloqueo AV é muito alto; a interacción é de alta magnitude clínica',
    'Bradicardia grave, bloqueo AV de 2º e 3º grau, síncope, hipotensión, riesgo de muerte',
    'Contraindicado. Usar azitromicina como alternativa antibiótica (sem inhibición CYP3A4 significativa). Se claritromicina for indispensable (ex: Helicobacter, MAC em HIV), suspender temporariamente a ivabradina',
    'CONTRAINDICADO — Ivabradina + Claritromicina: niveles 7x maiores, bradicardia fatal',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefFDA, _kRefGG]),

  // 163 — Dronedarona + Dabigatrana (P-gp inhibición)
  ('dronedarona', 'dabigatrana',
    InteractionSeverity.major,
    'Dronedarona é potente inhibidor da P-glicoproteína (P-gp) e do CYP3A4; dabigatrana é substrato exclusivo da P-gp (não é metabolizada pelo CYP450); a inhibición de la P-gp pelo dronedarona aumenta a exposición à dabigatrana em 70–100%, duplicando o riesgo hemorrágico',
    'Sangrado grave: hemorragia intracraniana, gastrointestinal, retroperitoneal; riesgo especialmente elevado en pacientes com insuficiencia renal (dabigatrana é excretada principalmente pelos rins)',
    'Se necesario anticoagulante com dronedarona, preferir warfarina com monitoramento de INR ou rivaroxabana (menor interacción com P-gp). Se dabigatrana for mantida, reducir dosis para 110 mg 2x/dia e evitar en pacientes com TFG < 50 mL/min',
    'Sangrado grave — Dronedarona dobra exposición à dabigatrana via P-gp',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 164 — Dronedarona + Sinvastatina (rabdomiólisis)
  ('dronedarona', 'sinvastatina',
    InteractionSeverity.major,
    'Dronedarona inibe o CYP3A4 e a P-gp; sinvastatina é extensamente metabolizada pelo CYP3A4 e tem elevada extração de primeira passagem; a inhibición aumenta os niveles de sinvastatina ativa em 2–4x, aumentando o riesgo de miopatía',
    'Miopatía, rabdomiólisis, CK > 10x LSN, mioglobinúria, insuficiencia renal aguda',
    'Limitar dosis de sinvastatina a 10 mg/dia se dronedarona for indispensable. Preferir atorvastatina (menor riesgo) em dosis ajustada ou pravastatina/rosuvastatina (não metabolizadas pelo CYP3A4). Monitorar CK se mialgias',
    'Rabdomiólisis — Dronedarona aumenta sinvastatina: limitar a 10 mg/dia ou trocar estatina',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 165 — Ranolazina + Metformina
  ('ranolazina', 'metformina',
    InteractionSeverity.moderate,
    'Ranolazina inibe o transportador renal OCT2 (cátion orgânico 2) e a P-gp, reduzindo a excreción tubular da metformina; os niveles plasmáticos de metformina podem aumentar em 30–40%; en pacientes com fatores de riesgo para acidosis láctica (IRC, insuficiencia cardíaca), o aumento de metformina é clinicamente relevante',
    'Acidosis láctica por acumulación de metformina: náuseas, dor abdominal, fraqueza, taquipneia, colapso hemodinâmico; mortalidade 30–50%',
    'Monitorar función renal e sintomas de acidosis láctica. Dosis máxima de metformina com ranolazina: 1.700 mg/dia (em vez de 2.550 mg/dia). Contraindicada a combinación en pacientes com TFG < 45 mL/min',
    'Acumulación de metformina — Ranolazina inibe OCT2: limitar dosis de metformina',
    EvidenceLevel.probable,
    {RiskType.other, RiskType.plasmaLevel},
    [_kRefGG, _kRefFDA]),

  // 166 — Vernakalant + Antiarrítmicos classe I/III
  ('vernakalant', 'flecainida',
    InteractionSeverity.contraindicated,
    'Vernakalant (antiarrítmico de ação predominantemente atrial para cardioversão de FA) tem efectos eletrofisiológicos aditivos com outros antiarrítmicos classe I (bloqueio de canais de Na) e classe III (bloqueio de canais de K); a combinación pode causar disfunção do nódulo sinusal, bloqueo AV grave e prolongamento excessivo do QRS e QT',
    'Bradiarritmias graves, bloqueo AV completo, pausa sinusal, TV/FV; hipotensión por disfunção miocárdica aguda',
    'Contraindicado. Aguardar 4 horas después de última dosis de classe I antes de vernakalant IV. No usar vernakalant en pacientes em amiodarona, sotalol ou outros classe III. Monitorar ECG e PA continuamente durante administração de vernakalant',
    'CONTRAINDICADO — Vernakalant + Classe I ou III: arritmias e bloqueo AV grave',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 167 — Telmisartana + Lítio
  ('telmisartana', 'litio',
    InteractionSeverity.major,
    'ARA-II (telmisartana, losartana, etc.) reduzem a excreción renal de sódio; como o lítio é reabsorvido junto ao sódio no túbulo proximal, a retenção de sódio pelos ARA-II paradoxalmente aumenta a reabsorción de lítio, elevando seus niveles séricos em 20–35%; mecanismo similar ao dos IECA e diuréticos',
    'Toxicidad por lítio: tremor grosseiro, ataxia, confusión mental, letargia, convulsiones, insuficiencia renal aguda, coma; litemia > 1,5 mEq/L = toxicidad moderada; > 2 mEq/L = toxicidad grave',
    'Monitorar litemia dentro de 1 semana después de inicio ou mudança de dosis del ARA-II, depois mensalmente. Reducir dosis de lítio em 25% preventivamente. Assegurar hidratação adecuada. Pacientes em dieta hipossódica têm riesgo maior',
    'Toxicidad de lítio — ARA-II (telmisartana) aumenta litemia 20–35%: monitorar',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 168 — Aliskiren + IECA + ARA-II (bloqueio SRAA duplo)
  ('aliskiren', 'enalapril',
    InteractionSeverity.contraindicated,
    'Aliskiren (inhibidor direto de renina) combinado com IECA ou ARA-II cria bloqueio duplo do sistema renina-angiotensina-aldosterona (SRAA); estudos (ALTITUDE, ONTARGET) demonstraram que o duplo bloqueio do SRAA aumenta o riesgo de hipotensión grave, hiperpotasemia e insuficiencia renal sem benefício cardiovascular adicional',
    'Hipotensión grave (síncope), insuficiencia renal aguda, hiperpotasemia grave (K+ > 6 mEq/L); maior riesgo en diabéticos com nefropatia e pacientes com ICC',
    'Contraindicado especialmente en diabéticos (ALTITUDE trial: interrompido por dano). Evitar em qualquer paciente. Se necesario maximizar bloqueio de SRAA, usar IECA + espironolactona (apenas com monitoramento) mas nunca IECA + ARA-II + aliskiren',
    'CONTRAINDICADO — Aliskiren + IECA: duplo bloqueio SRAA = hipotensión e IRA',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.hyperkalemia, RiskType.nephrotoxicity},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 169 — Clonidina + Beta-Bloqueador (rebound hipertensivo)
  ('clonidina', 'atenolol',
    InteractionSeverity.major,
    'Clonidina é agonista alfa-2 adrenérgico central que reduz a descarga simpática; al suspender abruptamente a clonidina, ocorre hipertensão de rebote por aumento súbito do tônus simpático; beta-bloqueadores, ao bloquear os receptores beta e deixar os alfa-adrenérgicos desimpedidos, potencializam a vasoconstrição periférica durante o rebound, exacerbando a hipertensão',
    'Crisis hipertensiva grave (PA > 180/120 mmHg) ao descontinuar abruptamente a clonidina; riesgo de AVC, IAM, encefalopatía hipertensiva; efecto especialmente perigoso na síndrome de retirada',
    'Nunca suspender clonidina abruptamente, especialmente se em uso de beta-bloqueador. Retirar gradualmente a lo largo de 7–10 días. Em caso de rebound, não tratar com beta-bloqueador IV (piora). Usar nitroprussiato, labetalol ou clonidina IV para controle da crise',
    'Crisis hipertensiva de rebound — Nunca suspender clonidina abruptamente com beta-bloqueador',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefKatz]),

  // 170 — Hidralazina + Dinitrato de Isossorbida (hipotensión)
  ('hidralazina', 'isossorbida',
    InteractionSeverity.moderate,
    'Combinación deliberada para ICC en pacientes intolerantes a IECA/ARA-II (A-HeFT trial); hidralazina causa vasodilatação arterial (reduz pós-carga) e isossorbida causa vasodilatação venosa (reduz pré-carga); a combinación pode causar hipotensión ortostática significativa, especialmente no inicio do tratamiento',
    'Hipotensión ortostática sintomática (tontura, síncope), taquicardia reflexa, cefaleia intensa por vasodilatação; a taquicardia pode precipitar eventos isquêmicos',
    'Iniciar com dosis bajas e titular lentamente. Orientar al paciente a mudar de posição gradualmente. Monitorar PA antes de cada dosis nas primeiras semanas. Cefaleia pode melhorar después de 2–4 semanas de uso contínuo',
    'Hipotensión ortostática — Hidralazina + Isossorbida: iniciar dosis baja e titular lentamente',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

  // 171 — Digoxina + Amiodarona (toxicidad digitálica)
  ('digoxina', 'amiodarona',
    InteractionSeverity.major,
    'Amiodarona inibe a P-gp e reduz o aclaramiento renal e extra-renal da digoxina; os niveles de digoxina aumentam 70–100% (quase dobram) dentro de 1–4 semanas do inicio da amiodarona; além do aumento farmacocinético, amiodarona tem efecto cronótropo negativo aditivo ao da digoxina no nódulo AV',
    'Toxicidad digitálica: náuseas, vômitos, xantopsia, bradicardia grave, bloqueo AV, bigeminismo, TV bidirecional; digoxinemia > 2 ng/mL confirma toxicidad',
    'Reducir dosis de digoxina em 50% al iniciar amiodarona. Monitorar digoxinemia (alvo 0,5–1,0 ng/mL) después de 7 dias e depois mensalmente. Monitorar ECG (PR, FC). Em toxicidad grave: anticorpo antidigoxina (Digibind)',
    'Toxicidad digitálica — Amiodarona dobra digoxina: reducir dosis 50% inmediatamente',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.arrhythmia},
    [_kRefGG, _kRefKatz, _kRefMdx, _kRefUT]),

  // 172 — Sitagliptina + Insulina Glargina (hipoglucemia)
  ('sitagliptina', 'insulina_glargina',
    InteractionSeverity.moderate,
    'Inhibidores de DPP-4 (sitagliptina) potencializam o efecto da insulina ao aumentar os niveles de GLP-1 e GIP endógenos, que estimulam a secreção de insulina glucose-dependente; em combinación com insulina basal, há riesgo de hipoglucemia por efecto aditivo nas células beta e posible sensibilização à ação insulínica',
    'Hipoglucemia: sudorese, tremor, taquicardia, confusão, convulsiones; o riesgo é maior al iniciar ou aumentar dosis de sitagliptina en pacientes já em insulina',
    'Considerar reducción de 10–20% na dosis de insulina basal al iniciar sitagliptina. Orientar monitoramento de glucemia capilar mais frecuente nas primeiras 2–4 semanas. Educar al paciente sobre reconhecimento e tratamiento de hipoglucemia',
    'Hipoglucemia — Sitagliptina + Insulina: reduzir insulina 10–20% al iniciar DPP-4i',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefUT]),

  // 173 — Exenatida + Acetaminofeno/Paracetamol (absorción)
  ('exenatida', 'paracetamol',
    InteractionSeverity.moderate,
    'Agonistas do receptor GLP-1 (exenatida, liraglutida) retardam o esvaziamento gástrico de forma dosis-dependente; o paracetamol tem absorción primariamente duodenal e gástrica precoce; o retardo do esvaziamento gástrico pelo arGLP-1 atrasa o pico plasmático do paracetamol (Tmax aumenta de ~0,75h para ~2–3h) sem alterar a ASC total',
    'Retardo na analgesia: inicio da ação mais lento do paracetamol, podendo ser inadecuado em dor aguda; dosiss repetidas de paracetamol podem se acumular se o paciente tomar dosiss seguintes sem aguardar o intervalo adecuado',
    'Administrar paracetamol pelo menos 1 hora antes da injeção de arGLP-1 para analgesia rápida. Em dor crônica ou pós-operatória, monitorar eficácia e considerar intervalos maiores entre dosiss. AINEs podem ser alternativa (sem esta interacción)',
    'Analgesia retardada — arGLP-1 retarda absorción do paracetamol: tomar 1h antes da injeção',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  // 174 — Empagliflozina + Torasemida (hipovolemia)
  ('empagliflozina', 'torasemida',
    InteractionSeverity.moderate,
    'iSGLT2 causam glicosúria osmótica com perda de água e sódio (efecto diurético osmótico); diuréticos de alça (torasemida, furosemida) causam perda adicional de sódio, potássio e água; a combinación tem efecto diurético sinérgico com riesgo de depleción de volumen grave',
    'Hipotensión (especialmente ortostática), desidratação, insuficiencia renal pré-renal (creatinina elevada), hipopotasemia, quedas en ancianos; en pacientes com ICC, o riesgo de depleção excessiva pode ser desejável mas requer monitoramento',
    'Monitorar PA e función renal ao inicio da combinación. Reducir dosis do diurético de alça em 25–50% se PA < 90/60 mmHg ou sinais de desidratação. Orientar ingestão hídrica adecuada e reconhecimento de sintomas de hipovolemia',
    'Hipovolemia sinérgica — iSGLT2 + Diurético de alça: monitorar PA e función renal',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT]),

  // 175 — Canagliflozina + Fenitoína (CYP3A4 + UGT1A9)
  ('canagliflozina', 'fenitoina',
    InteractionSeverity.moderate,
    'Fenitoína induz múltiplas enzimas hepáticas incluindo UGT1A9, via de glucuronidação dos iSGLT2; a inducción de la UGT1A9 pode aumentar o metabolismo de la canagliflozina em 20–30%, reduzindo seus niveles plasmáticos e eficácia',
    'Reducción de la eficacia hipoglucemiante da canagliflozina; piora do controle glicêmico com HbA1c acima do esperado; fracaso terapéutico do iSGLT2',
    'Monitorar HbA1c e glucemia em jejum al iniciar ou aumentar dosis de fenitoína. Pode ser necesario aumentar dosis de canagliflozina para 300 mg/dia ou adicionar outro agente hipoglucemiante',
    'Eficácia reducida — Fenitoína (inductor UGT1A9) reduz canagliflozina: monitorar glucemia',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // 176 — Levodopa + Metoclopramida (antagonismo)
  ('levodopa', 'metoclopramida',
    InteractionSeverity.contraindicated,
    'Metoclopramida bloqueia receptores D2 dopaminérgicos no SNC e na periferia; a levodopa age via conversão a dopamina nos neurônios dopaminérgicos nigroestriatais; o bloqueio D2 pela metoclopramida antagoniza diretamente o efecto terapéutico da levodopa, piorando o parkinsonismo; também pode precipitar reacciones extrapiramidais agudas',
    'Piora grave do parkinsonismo (rigidez, tremor, acinesia), crises de distonia aguda, potencial síndrome neuroléptica maligna en pacientes com enfermedad de Parkinson',
    'Contraindicado em parkinsonismo. Usar domperidona como alternativa antiemética (age perifericamente, sem penetrar SNC significativamente). Para gastroparesia em parkinsonismo, domperidona 10 mg 3x/dia antes das refeições',
    'CONTRAINDICADO — Metoclopramida + Levodopa: piora grave do parkinsonismo',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 177 — Pramipexol + Metoclopramida
  ('pramipexol', 'metoclopramida',
    InteractionSeverity.contraindicated,
    'Pramipexol é agonista D2/D3 dopaminérgico usado no parkinsonismo e síndrome das pernas inquietas; metoclopramida antagoniza D2, bloqueando diretamente o mecanismo de ação do pramipexol e revertendo o controle dos sintomas parkinsonianos e da síndrome das pernas inquietas',
    'Recurrencia de parkinsonismo, síndrome das pernas inquietas refratária, potencial exacerbação com reacciones extrapiramidais agudas por antagonismo D2 somado',
    'Contraindicado. Mesma orientação que levodopa + metoclopramida. Domperidona é a alternativa antiemética segura no parkinsonismo',
    'CONTRAINDICADO — Metoclopramida antagoniza pramipexol: piora do parkinsonismo',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 178 — Donepezilo + Succinilcolina (bloqueio neuromuscular)
  ('donepezilo', 'succinilcolina',
    InteractionSeverity.major,
    'Donepezilo inibe a acetilcolinesterase, aumentando os niveles de acetilcolina na fenda neuromuscular; a succinilcolina (bloqueador neuromuscular despolarizante) é hidrolisada pela pseudocolinesterase plasmática; com os inhibidores de colinesterase, a atividade da pseudocolinesterase pode ser reducida, retardando a hidrólise da succinilcolina e prolongando o bloqueio neuromuscular',
    'Bloqueio neuromuscular prolongado com apnea pós-anestésica; necessidade ventilação mecânica prolongada; paralisia muscular persistente',
    'Alertar o anestesiologista sobre o uso de donepezilo (e outros inhibidores de colinesterase: rivastigmina, galantamina). Planejar monitoramento de bloqueio neuromuscular com neuroestimulador. Considerar uso de bloqueador não despolarizante (rocurônio) como alternativa à succinilcolina',
    'Apnea pós-anestésica — Donepezilo prolonga ação da succinilcolina: alertar anestesia',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefKatz, _kRefUT]),

  // 179 — Memantina + Amantadina
  ('memantina', 'amantadina',
    InteractionSeverity.major,
    'Memantina é antagonista não competitivo de receptores NMDA; amantadina também é antagonista de receptores NMDA, além de ter propriedades dopaminérgicas; a combinación potencializa o bloqueio NMDA de forma sinérgica, com riesgo de toxicidad central (efectos psicotomiméticos e convulsiones)',
    'Confusión mental, alucinações, agitação, tontura, convulsiones; síndrome de abstinencia glutamatérgica com abstinência abrupta de ambos',
    'Evitar combinación. Se amantadina for necesaria (influenza ou parkinsonismo avançado), considerar suspender temporariamente a memantina ou usar donepezilo como alternativa para demência',
    'Toxicidade central — Memantina + Amantadina: bloqueio NMDA duplo aditivo',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG, _kRefUT]),

  // 180 — Rivastigmina + Betanecol (colinérgico aditivo)
  ('rivastigmina', 'betanecol',
    InteractionSeverity.major,
    'Rivastigmina inibe as colinesterases, aumentando acetilcolina; betanecol é agonista muscarínico direto; a combinación gera estimulação colinérgica periférica e central excessiva com riesgo de síndrome colinérgica grave',
    'Síndrome colinérgica: bradicardia grave, hipotensión, sialorréia, broncoespasmo, cólicas intestinais, diarreia, sudorese profusa, miose, fraqueza muscular, convulsiones',
    'Evitar combinación. Se betanecol for indispensable (retenção urinária neurogênica), suspender rivastigmina temporariamente com orientação neurológica. Atropina como antídoto se toxicidad grave',
    'Síndrome colinérgica grave — Rivastigmina + Betanecol: estimulação muscarínica excessiva',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.respiratoryDepression},
    [_kRefGG]),

  // 181 — Lecanemabe + Anticoagulantes (hemorragia cerebral)
  ('lecanemabe', 'varfarina',
    InteractionSeverity.major,
    'Lecanemabe (anticorpo monoclonal anti-beta-amiloide para Alzheimer) causa como efecto adverso característico ARIA (anormalidades de imagem relacionadas a amiloide): ARIA-E (edema/efusão) e ARIA-H (hemossiderose/microhemorragias); anticoagulantes sistêmicos aumentam o riesgo de sangrado intracraneal quando ARIA-H ocorre, transformando microhemorragias em macroemorragias com sequelas neurológicas graves',
    'Hemorragia intracraniana sintomática, macroemorragia em áreas de ARIA-H preexistente; edema cerebral; óbito por hemorragia cerebral en pacientes anticoagulados',
    'Contraindicação relativa — alta cautela. Realizar RNM de triagem antes de iniciar lecanemabe. Anticoagulação sistêmica é fator de riesgo independente para ARIA sintomática. Discutir benefício/riesgo individualmente com cada paciente. Monitorar RNM a cada 3 meses durante o primeiro ano. Se ARIA-H detectado, suspender lecanemabe e anticoagulante',
    'Hemorragia cerebral — Lecanemabe + Anticoagulantes: ARIA-H com riesgo de macro-hemorragia',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.cns},
    [_kRefFDA, _kRefGG]),

  // 182 — Dutasterida + CYP3A4 inhibidores (ex: Verapamil)
  ('dutasterida', 'verapamil',
    InteractionSeverity.moderate,
    'Dutasterida é metabolizada pelo CYP3A4 (e em menor grau CYP3A5); verapamil é inhibidor moderado do CYP3A4 e pode reduzir o metabolismo de la dutasterida, aumentando seus niveles em 30–50%; como dutasterida inibe a 5-alfa-redutase, concentraciones maiores intensificam a supresión da DHT',
    'Efectos feminilizantes exacerbados: disfunção sexual, ginecomastia, diminuição da libido; teratogenicidade potencial (DHT fetal crítica para desenvolvimento masculino)',
    'Monitorar síntomas de hiperdutasteridemia. Em parceiras em idade fértil, reforçar uso de preservativo (dutasterida excretada no sêmen). Alternativa: finasterida (metabolismo diferente) ou alfuzosina para HPB',
    'Efectos da dutasterida amplificados — Verapamil inibe CYP3A4: monitorar efectos adversos',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // 183 — Anastrozol + Tamoxifeno (antagonismo)
  ('anastrozol', 'tamoxifeno',
    InteractionSeverity.major,
    'Tamoxifeno é modulador seletivo do receptor de estrogênio (SERM) com efecto agonista parcial; anastrozol é inhibidor de aromatase; estudos ATAC e ABCSG demonstraram que a combinación simultânea não oferece benefício adicional em relação à monoterapia e que o tamoxifeno pode reduzir os niveles de anastrozol em 27% por mecanismo farmacocinético (inducción enzimática)',
    'Reducción dos niveles plasmáticos de anastrozol com posible comprometimento da supresión estrogênica; a combinación não reduz a recurrencia do câncer de mama além da monoterapia e pode aumentar eventos adversos',
    'No usar concomitantemente em adjuvância do câncer de mama. Usar sequencialmente (ex: tamoxifeno por 2–3 anos, depois anastrozol por 2–3 anos) conforme protocolos (MA.17). Cada monoterapia tem perfil de efectos adversos específico',
    'Interacción antagonista — Anastrozol + Tamoxifeno simultâneos: sem benefício adicional',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 184 — Letrozol + Inductores CYP (tamoxifeno como inductor)
  ('letrozol', 'carbamazepina',
    InteractionSeverity.moderate,
    'Letrozol é metabolizado pelo CYP2A6 e CYP3A4; carbamazepina induz o CYP3A4, podendo reduzir a AUC do letrozol em 20–35%; a supresión estrogênica pode ser comprometida com concentraciones subterapéuticas de letrozol',
    'Falha terapéutica do letrozol com riesgo de recurrencia de câncer de mama ou endométrio dependente de estrogênio',
    'Monitorar estradiol sérico como proxy da supresión estrogênica en pacientes em uso de inductores enzimáticos. Considerar alternativa antiepiléptica (levetiracetam, lamotrigina) sem inducción CYP3A4. Aumentar dosis de letrozol pode não ser posible por efectos adversos',
    'Falha terapéutica — Carbamazepina reduz letrozol: considerar antiepiléptico sem inducción',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 185 — Medroxiprogesterona + Rifampicina
  ('medroxiprogesterona', 'rifampicina',
    InteractionSeverity.major,
    'Rifampicina induz potentemente o CYP3A4 e CYP2C19, principais enzimas de metabolismo de la medroxiprogesterona; mesmo a formulação injetável depot (ACM-D) sofre impacto: a depuração da medroxiprogesterona é acelerada, podendo reduzir a duración do efecto contraceptivo de 12 para 8–10 semanas',
    'Fracaso contraceptivo com embarazo no planificado; concentraciones subterapéuticas antes do período habitual de reinjeção',
    'Reduzir o intervalo de aplicação do ACM-D de 13 para 10 semanas durante uso de rifampicina. Adicionar método de barrera (preservativo). Después de suspensión da rifampicina, aguardar 28 dias antes de retornar ao intervalo normal de 13 semanas',
    'FRACASO CONTRACEPTIVO — Rifampicina acelera metabolismo de la medroxiprogesterona depot',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 186 — Leflunomida + Rifampicina (toxicidad de teriflunomida)
  ('leflunomida', 'rifampicina',
    InteractionSeverity.major,
    'Leflunomida é pró-farmaco convertido ao metabólito ativo teriflunomida (inhibidor de diidroorotato desidrogenase); rifampicina induz o CYP1A2 e CYP2C19, e pode aumentar o metabolismo de la teriflunomida, reduzindo seus niveles e a eficácia inmunosupresora; paradoxalmente, a inducción hepática pela rifampicina pode aumentar os niveles de alguns metabólitos tóxicos',
    'Falha do controle da artrite reumatoide por subexpossição à teriflunomida; raramente toxicidad hepática por acumulación de metabólitos',
    'Monitorar respuesta clínica (articulações, PCR, VHS) durante e después de rifampicina. Monitorar ALT/AST mensalmente. Esta combinación é generalmente necesaria em tuberculose en pacientes com AR — planejar cuidadosamente',
    'Falha inmunosupresora — Rifampicina altera metabolismo de leflunomida: monitorar AR',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.hepatotoxicity},
    [_kRefGG, _kRefUT]),

  // 187 — Colchicina + Verapamil (toxicidad por P-gp + CYP3A4)
  ('colchicina', 'verapamil',
    InteractionSeverity.major,
    'Verapamil é inhibidor do CYP3A4 e da P-glicoproteína; colchicina é substrato de ambos com janela terapéutica estreita e índice terapéutico baixo; a inhibición simultânea de CYP3A4 e P-gp aumenta a exposición sistêmica à colchicina em 2–3x; toxicidad grave pode ocorrer mesmo em dosiss habituais',
    'Toxicidade grave de colchicina: miopatía com rabdomiólisis, pancitopenia, neuropatia periférica, falência de múltiplos órgãos; mortalidade elevada na toxicidad grave',
    'Reducir dosis de colchicina para metade em usuários de verapamil (dosis máxima: 0,6 mg/dia em vez de 1,2 mg/dia). Monitorar CK e hemograma. En pacientes com IRC, a combinación é especialmente perigosa e pode ser contraindicada',
    'Toxicidad de colchicina — Verapamil inibe CYP3A4 e P-gp: reducir dosis 50%',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.myelosuppression},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 188 — Febuxostate + Azatioprina (toxicidad fatal)
  ('febuxostate', 'azatioprina',
    InteractionSeverity.contraindicated,
    'Azatioprina é convertida a 6-mercaptopurina (6-MP), que é metabolizada pela xantina oxidase a metabólitos inativos; febuxostate inibe potentemente a xantina oxidase (de forma não competitiva e irreversible), bloqueando a inativação da 6-MP; os niveles de 6-MP aumentam drásticamente com toxicidad hematopoiética grave; mecanismo idêntico ao da interacción alopurinol/azatioprina mas com inhibición ainda mais completa',
    'Pancitopenia grave, aplasia medular, infecções oportunistas fatais, hepatotoxicidad; mortalidade documentada',
    'Contraindicado. En pacientes com gota em azatioprina, usar estratégias alternativas de reducción del urato: uricosuricos (benzobromarona, probenecida) ou modificação de dosis de azatioprina com acompanhamento hematológico. Se febuxostate for indispensable, suspender azatioprina e sustituir por outro inmunosupresor',
    'CONTRAINDICADO — Febuxostate + Azatioprina: aplasia medular e óbito (como alopurinol)',
    EvidenceLevel.established,
    {RiskType.myelosuppression, RiskType.hepatotoxicity},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 189 — Sulfassalazina + Digoxina (reducción de absorción)
  ('sulfassalazina', 'digoxina',
    InteractionSeverity.moderate,
    'Sulfassalazina pode reduzir a absorción intestinal da digoxina em até 25% por mecanismo não completamente esclarecido, possivelmente por interferência na motilidade intestinal ou por complexação no lúmen; a digoxina tem janela terapéutica estreita e qualquer reducción de nivel pode comprometer a resposta clínica',
    'Reducción dos niveles séricos de digoxina com fracaso en el control da frecuencia cardíaca em fibrilación auricular ou reducción de la contratilidade na ICC',
    'Monitorar digoxinemia después de inicio da sulfassalazina. Pode ser necesario aumentar a dosis de digoxina em 15–25%. Usar comprimido de liberação lenta (Lanoxicaps) que tem menor interacción. Manter intervalo de 2 horas entre as medicações',
    'Absorción reducida de digoxina — Sulfassalazina: monitorar digoxinemia ao iniciar',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  // 190 — Hidroxicloroquina + Amiodarona (QT + arritmias)
  ('hidroxicloroquina', 'amiodarona',
    InteractionSeverity.major,
    'Hidroxicloroquina prolonga o QT por bloqueio de canais hERG (IKr); amiodarona prolonga o QT por múltiplos mecanismos; ambos têm vida media longa (HCQ: 40–50 dias; amiodarona: 40–55 dias) tornando o efecto cumulativo persistente; combinación frecuente em lúpus com FA ou arritmias',
    'Prolongación del QTc > 500 ms, torsades de pointes, fibrilación ventricular, morte súbita; toxicidad acumulativa por vida media muito longa de ambos',
    'Monitorar ECG antes de iniciar e mensalmente. Manter K+ > 4 mEq/L e Mg++ > 0,8 mEq/L. Se QTc > 480 ms, reducir dosis de HCQ. Se QTc > 500 ms, suspender HCQ e reavaliar esquema. Monitorar visão (HCQ) e tireoide e pulmão (amiodarona) separadamente',
    'QT longo grave — Hidroxicloroquina + Amiodarona: vida media longa amplifica riesgo',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.arrhythmia},
    [_kRefGG, _kRefUT]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 8 — Aminoglicosídeos avançados, Laxantes, Anemias,
  // iPCSK9, Hepatite B/C, Antivirais (191–220)
  // ═══════════════════════════════════════════════════════════════

  // 191 — Tobramicina + Cisplatina (ototoxicidad sinérgica)
  ('tobramicina', 'cisplatina',
    InteractionSeverity.major,
    'Tobramicina e cisplatina causam ototoxicidad por mecanismos diferentes mas sinérgicos: tobramicina acumula na cóclea causando lesão das células ciliadas externas via radicais livres; cisplatina causa dano ao estria vascular e células de suporte; a combinación tem efecto aditivo ou sinérgico na perda auditiva permanente',
    'Perda auditiva neurossensorial permanente, especialmente em frecuencias altas (4.000–8.000 Hz); tinitus; perda de frecuencias da fala em exposición prolongada; irreversible',
    'Evitar combinación. Si es indispensable, realizar audiometría basal e a cada ciclo de cisplatina. Monitorar tinnitus e sintomas de perda auditiva. Usar amikacina como alternativa aminoglicosídeo (menor ototoxicidad cumulativa). Considerar N-acetilcisteína como protetor coclear (evidência limitada)',
    'Ototoxicidad irreversible — Tobramicina + Cisplatina: audiometría obrigatória',
    EvidenceLevel.established,
    {RiskType.ototoxicity},
    [_kRefGG, _kRefUT, _kRefMdx]),

  // 192 — Amikacina + Polimixina B (nefrotoxicidad máxima)
  ('amikacina', 'polimixina_b',
    InteractionSeverity.major,
    'Amikacina e polimixina B causam nefrotoxicidad por mecanismos aditivos: amikacina acumula no córtex renal causando lesão dos túbulos proximais; polimixina B liga-se a fosfolipídios de membrana das células tubulares causando ruptura; a combinación é de extrema necessidade em infecções por gram-negativos MDR mas com nefrotoxicidad cumulativa muito elevada',
    'Insuficiencia renal aguda grave, oligúria, necrose tubular aguda; incidência de LRA de 70–80% com a combinación; frecuentemente necessita diálise',
    'Monitorar creatinina diariamente. Dosar amikacina (nivel de vale < 5 mcg/mL, pico 20–30 mcg/mL). Dosagem única diária de amikacina reduz nefrotoxicidad. Hidratação agressiva (200 mL/h SF 0,9% durante a infusão de polimixina). Suspender inmediatamente se creatinina dobrar em 48 horas',
    'Nefrotoxicidad máxima — Amikacina + Polimixina B: monitorar renal diário rigoroso',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefUT]),

  // 193 — Gentamicina + Relaxantes musculares (bloqueio neuromuscular)
  ('gentamicina', 'vecurônio',
    InteractionSeverity.major,
    'Aminoglicosídeos inibem a liberação de acetilcolina na junção neuromuscular por bloqueio dos canais de cálcio pré-sinápticos e competição com cálcio; bloqueadores neuromusculares não despolarizantes (vecurônio, pancurônio, rocurônio) bloqueiam receptores nicotínicos pós-sinápticos; a combinación causa potenciação do bloqueio neuromuscular com prolongamento significativo da paralisia',
    'Paralisia muscular prolongada pós-operatória, apnea, necessidade ventilação mecânica por tempo indefinido; riesgo maior en pacientes com miastenia gravis ou hipocalcemia',
    'Alertar anestesiologista sobre uso de gentamicina en pacientes cirúrgicos. Monitorar bloqueio neuromuscular com estimulador de nervo periférico. Usar anticolinesterásico (neostigmina) para reversão. Evitar aminoglicosídeos em período peri-operatório si es posible',
    'Paralisia prolongada — Gentamicina potencializa bloqueadores neuromusculares: alertar anestesia',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression},
    [_kRefGG, _kRefKatz]),

  // 194 — Polietilenoglicol (PEG) + Fármacos de janela estreita oral
  ('polietilenoglicol', 'ciclosporina',
    InteractionSeverity.moderate,
    'Soluções de polietilenoglicol (PEG) para preparo intestinal aumentam intensamente a motilidade intestinal e o trânsito gastrointestinal; fármacos administrados oralmente com baixa absorción intestinal ou que requerem contato prolongado com a mucosa podem ter sua absorción reducida drásticamente; ciclosporina, varfarina, carbamazepina e outros fármacos de janela estreita são especialmente vulneráveis',
    'Absorción drásticamente reducida durante o preparo intestinal; niveles subterapéuticos de ciclosporina com riesgo de rechazo de transplante; INR instável com varfarina; crisis convulsivas por queda de nivel de antiepilépticos',
    'Suspender fármacos de janela estreita oral por 24 horas antes e retomar 2 horas después de o fin do preparo intestinal. Para ciclosporina: dosar C0 e C2 después de o procedimiento. Para varfarina: monitorar INR. Para antiepilépticos: monitorar nivel',
    'Absorción prejudicada — Laxante PEG + Fármacos de janela estreita: suspender 24h antes',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 195 — Bisacodil + Laxantes estimulantes + Diuréticos (hipopotasemia)
  ('bisacodil', 'furosemida',
    InteractionSeverity.moderate,
    'Bisacodil e outros laxantes estimulantes (sena, picossulfato) causam perda de potássio através da mucosa intestinal por aumento da secreção colônica; furosemida causa perda renal de potássio; a combinación tem efecto hipocalêmico aditivo, especialmente em uso crônico de laxantes (abuso em transtornos alimentares, idosos)',
    'Hipopotasemia sintomática (K+ < 3,0 mEq/L): fraqueza muscular, cãibras, arritmias, miopatía; posible toxicidad digitálica en pacientes em digoxina; prolongación del QT',
    'Monitorar K+ sérico mensalmente em uso crônico de laxante + diurético. Suplementar potássio se K+ < 3,5 mEq/L. Preferir laxantes osmóticos (lactulose, PEG) ao invés de estimulantes para uso crônico. Uso crônico de laxantes estimulantes deve ser investigado (transtorno alimentar, síndrome do intestino preguiçoso)',
    'Hipopotasemia aditiva — Laxante estimulante + Furosemida: monitorar K+ mensalmente',
    EvidenceLevel.probable,
    {RiskType.hypokalemia, RiskType.arrhythmia},
    [_kRefGG, _kRefMdx]),

  // 196 — Lactulose + Antibióticos (reducción del efecto na encefalopatía)
  ('lactulose', 'rifaximina',
    InteractionSeverity.minor,
    'Lactulose age como acidificante colônico (converte amônia em NH4+, não absorvível) e laxante osmótico, reduzindo a produção e absorción de amônia na encefalopatía hepática; rifaximina reduz as bactérias produtoras de amônia no cólon; a combinación é sinérgica e recomendada em encefalopatía hepática crônica — não há interacción adversa',
    'A combinación é benéfica e não causa efecto adverso relevante; rifaximina não é absorvida sistemicamente (< 0,4%), portanto sem interacción farmacocinética',
    'Combinación segura e sinérgica para encefalopatía hepática. Monitorar consistência das fezes com lactulose (alvo 2–3 evacuações/dia moles). A rifaximina pode ser adicionada à lactulose em casos de resposta insuficiente',
    'Combinación benéfica — Lactulose + Rifaximina: sinergia na encefalopatía hepática',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefUT]),

  // 197 — Sevelâmer + Quinolonas (quelação de absorción)
  ('sevelâmer', 'ciprofloxacino',
    InteractionSeverity.moderate,
    'Sevelâmer (quelante de fósforo) pode ligar-se ao ciprofloxacino no trato gastrointestinal por interacción eletrostática (sevelâmer é policatiônico, ciprofloxacino é anfotérico); a quelação pode reduzir a absorción do antibiótico; mecanismo similar ao dos antiácidos com alumínio/magnésio e das quinolonas',
    'Reducción das concentraciones plasmáticas de ciprofloxacino podendo comprometer eficácia antibiótica, especialmente em infecções graves (bacteremia, osteomielite, infecção do trato urinário por Pseudomonas)',
    'Administrar ciprofloxacino pelo menos 2 horas antes ou 6 horas después de o sevelâmer. En pacientes em hemodiálise onde o controle do fósforo é essencial, ajustar horários de forma a garantir os intervalos necesarios',
    'Absorción reducida — Ciprofloxacino + Sevelâmer: separar 6 horas para eficácia máxima',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefMdx]),

  // 198 — Eritropoetina (EPO) + Ciclosporina (hipertensão)
  ('eritropoetina', 'ciclosporina',
    InteractionSeverity.moderate,
    'Eritropoetina aumenta a viscosidade sanguínea pela elevación do hematócrito e tem efecto vasoconstritor direto; ciclosporina causa vasoconstrição endotelina-mediada e hipertensão; ambos aumentam resistência vascular periférica; o hematócrito elevado pela EPO pode aumentar a toxicidad nefrológica e cardiovascular da ciclosporina; a ciclosporina pode reduzir a resposta à EPO por toxicidad medular leve',
    'Hipertensão arterial grave resistente ao tratamiento (encefalopatía hipertensiva, crisis hipertensiva); trombosis de acesso vascular (fístula ou cateter) por hiperviscosidade; posible reducción de la resposta à EPO',
    'Monitorar PA rigurosamente (alvo < 130/80 mmHg). Titular EPO para hematócrito 30–36% (não > 36%) en pacientes trasplantados. Monitorar nivel de ciclosporina. Considerar anti-hipertensivos como bloqueadores de canal de cálcio (diltiazem — mas cautela com ciclosporina)',
    'Hipertensão grave — Eritropoetina + Ciclosporina: hiperviscosidade + vasoconstrição',
    EvidenceLevel.probable,
    {RiskType.cardiovascular, RiskType.thrombosis},
    [_kRefGG, _kRefUT]),

  // 199 — Darbepoetina + Ferro IV (resposta eritropoética)
  ('darbepoetina', 'ferro_sacarato',
    InteractionSeverity.minor,
    'Darbepoetina (eritropoetina de ação prolongada) requer disponibilidade adecuada de ferro para que a eritropoese seja eficiente; a administração concomitante de ferro IV melhora a resposta eritropoética por fornecer substrato para a síntese de hemoglobina; esta é uma combinación terapéutica benéfica e recomendada em anemia da DRC',
    'Sem toxicidad adicional; a combinación é terapéutica e reduz a dosi es necesaria de darbepoetina; reacciones de hipersensibilidade ao ferro IV (raras) independem da darbepoetina',
    'Combinación recomendada e sinérgica. Monitorar ferritina (alvo 200–500 ng/mL) e saturação de transferrina (alvo 20–50%). Suspender ferro IV se ferritina > 800 ng/mL. Administrar em dias diferentes para facilitar monitoramento de reacciones',
    'Sinergia terapéutica — Darbepoetina + Ferro IV: combinación benéfica e recomendada',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefFDA]),

  // 200 — Roxadustate + Estatinas (CYP2C9 e OATP)
  ('roxadustate', 'rosuvastatina',
    InteractionSeverity.moderate,
    'Roxadustate inibe o transportador hepático OATP1B1/B3, responsável pela captação hepatocelular da rosuvastatina; a inhibición del OATP aumenta os niveles sistêmicos de rosuvastatina em 2–3x; además, roxadustate inibe o CYP2C9, afetando o metabolismo de outros fármacos co-prescritos em IRC',
    'Miopatía por acumulación de rosuvastatina: mialgia, CK elevada, rabdomiólisis; riesgo maior en pacientes com IRC avançada (já com riesgo aumentado de miopatía por uremia)',
    'Reducir dosis de rosuvastatina em 50% al iniciar roxadustate. Iniciar com 5 mg/dia e avaliar CK mensalmente. Considerar pravastatina (não é substrato OATP1B1) como alternativa com menor interacción',
    'Miopatía — Roxadustate inibe OATP: rosuvastatina 2–3x maior, reducir dosis 50%',
    EvidenceLevel.probable,
    {RiskType.myopathy, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 201 — Sofosbuvir + Amiodarona (bradicardia fatal)
  ('sofosbuvir', 'amiodarona',
    InteractionSeverity.contraindicated,
    'Combinación de sofosbuvir com amiodarona causa bradicardia grave, bloqueo AV e paro cardíaco por mecanismo não completamente elucidado — provavelmente relacionado à ação do sofosbuvir nos canais cardíacos de sódio e ao efecto cronotrópico negativo da amiodarona; vários casos fatais foram reportados ao FDA',
    'Bradicardia sintomática (FC < 40 bpm), pausa sinusal, bloqueo AV de grau elevado, asistolia, morte; alguns casos ocorreram en pacientes que haviam descontinuado amiodarona meses antes (vida media longa de 40–55 dias)',
    'Contraindicado. Aguardar pelo menos 4 meses después de a última dosis de amiodarona antes de iniciar regimes contendo sofosbuvir. Se monitoramento for necesario em combinación inadvertida: ECG contínuo em ambiente hospitalar por 48 horas. Usar alternativa (regimes sem sofosbuvir) se disponible',
    'CONTRAINDICADO — Sofosbuvir + Amiodarona: bradicardia fatal documentada, aguardar 4 meses',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 202 — Ledipasvir + Antiácidos IBP (absorción)
  ('ledipasvir', 'omeprazol',
    InteractionSeverity.major,
    'Ledipasvir requer pH ácido gástrico para dissolução e absorción adecuadas; omeprazol e outros IBP aumentam o pH gástrico para 4–6, reduzindo a solubilidade e absorción do ledipasvir em ~15–35%; o efecto é dosis-dependente: omeprazol 20 mg reduz AUC em 14%, dosiss maiores causam reduções maiores',
    'Reducción das concentraciones plasmáticas de ledipasvir podendo comprometer a eficácia antiviral, especialmente en pacientes com hepatite C genótipo 1 sem cirrose (que já têm menores reservas à fracaso terapéutico)',
    'Evitar IBP em dosiss acima de 20 mg/dia com ledipasvir. Se IBP for indispensable: usar a menor dosi es posible (omeprazol 20 mg/dia), administrar ledipasvir/sofosbuvir com alimento (aumenta absorción 40%), e si es posible tomar IBP à noite e ledipasvir de manhã em jejum',
    'Absorción reducida — Omeprazol >20mg reduz ledipasvir: usar dosis mínima de IBP',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 203 — Glecaprevir/Pibrentasvir + Atazanavir (Paxlovid-like)
  ('glecaprevir', 'atazanavir',
    InteractionSeverity.major,
    'Atazanavir é inhibidor potente do CYP3A4 e da P-gp; glecaprevir é substrato de ambos; a inhibición aumenta os niveles de glecaprevir em 5–7x; pibrentasvir também é afetado; os antivirais para HIV com inhibición de CYP3A4/P-gp são contraindicados com regimes contendo inhibidores de NS3/NS5A',
    'Toxicidade grave dos DAAs por supraexposición: hepatotoxicidad, elevación de ALT/AST, icterícia, insuficiencia hepática aguda',
    'Contraindicado. Aguardar troca ou suspensión do antiviral para HIV antes de iniciar glecaprevir/pibrentasvir. Em coinfectados HIV/HCV, escolher combinación compatível: sofosbuvir/velpatasvir com TARV baseada em raltegravir ou dolutegravir (sem inhibición CYP3A4)',
    'CONTRAINDICADO — Glecaprevir + Atazanavir: 5–7x de exposición ao DAA, hepatotoxicidad',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 204 — Sofosbuvir/Velpatasvir + Rifampicina
  ('velpatasvir', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Rifampicina é potente inductor do CYP3A4, P-gp e UGT1A1, as principais vias de eliminación do velpatasvir (e sofosbuvir); a inducción reduz a AUC do velpatasvir em 82% e a do sofosbuvir em 72%; com concentraciones tão reducidas, não é posible obter a supresión viral necesaria para cura da hepatite C',
    'Fracaso virológico com concentraciones subterapéuticas de ambos os DAAs; riesgo de seleção de resistência com impacto em regimes futuros de retratamiento',
    'Contraindicado. Tratamiento da hepatite C deve ser adiado até a conclusão da rifampicina. Se coinfecção TB/HCV necessitar tratamiento simultâneo, usar rifabutina (inductor menos potente) ou regimes com sofosbuvir + ledipasvir com ajuste de dosis; consultar especialista em infectologia',
    'CONTRAINDICADO — Rifampicina reduz DAAs >80%: fracaso virológico certa e resistência',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 205 — Entecavir + Metformina (transportador OCT1)
  ('entecavir', 'metformina',
    InteractionSeverity.moderate,
    'Entecavir e metformina compartilham o transportador renal OCT2 e o transportador hepático OCT1 para captação celular; competição pelos mesmos transportadores pode aumentar os niveles plasmáticos de metformina por reducción del transporte tubular de secreção',
    'Leve a moderado aumento de metformina podendo precipitar acidosis láctica en pacientes com IRC subjacente (frecuente na hepatite B com cirrose)',
    'Monitorar función renal e sintomas de acidosis láctica. En pacientes com cirrose por hepatite B com reducción de TFG (< 45 mL/min), evitar combinación ou usar dosis reducida de metformina. Alternativa: usar ISRS2 ou sulfonilurea de curta ação',
    'Riesgo de acidosis láctica — Entecavir compete com metformina no transportador OCT: monitorar',
    EvidenceLevel.theoretical,
    {RiskType.other},
    [_kRefGG]),

  // 206 — Tenofovir (TDF) + Antivirais nefrotóxicos
  ('tenofovir', 'cidofovir',
    InteractionSeverity.contraindicated,
    'Tenofovir alafenamida (TAF) e tenofovir disoproxil fumarato (TDF) causam nefrotoxicidad tubular; cidofovir é altamente nefrotóxico por acumulación nas células tubulares proximais; ambos lesam as células tubulares proximais (toxicidad em S1 e S2 do túbulo proximal), causando síndrome de Fanconi; a combinación multiplica o riesgo',
    'Síndrome de Fanconi por lesão tubular: hipouricemia, hipofosfatemia, proteinúria tubular, glicosúria normoglicêmica, acidosis metabólica hiperclorêmica; insuficiencia renal aguda grave',
    'Contraindicado. Cidofovir requer probenecida IV + hidratação pré-infusão; ainda assim, evitar combinación com tenofovir. Usar ganciclovir ou foscarnet como alternativa para CMV en pacientes em tenofovir',
    'CONTRAINDICADO — Tenofovir + Cidofovir: síndrome de Fanconi e IRA grave',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefFDA]),

  // 207 — Abacavir + Ribavirina (anemia hemolítica)
  ('abacavir', 'ribavirina',
    InteractionSeverity.major,
    'Ribavirina é análogo de nucleosídeo que pode ser fosforilado intracelularmente; os tri-fosfatos de ribavirina competem com os de abacavir (carbovir-TP) pelos transportadores de nucleosídeos e pela incorporação à cadeia de DNA viral; además, a ribavirina causa anemia hemolítica dosis-dependente, potencializando o riesgo em coinfecção HIV/HCV tratada com abacavir',
    'Anemia hemolítica grave (Hb < 8 g/dL), reticulocitose, hiperbilirrubinemia; fracaso virológico da TARV por reducción de la eficácia do abacavir pela competição com ribavirina',
    'Evitar combinación em coinfecção HIV/HCV. Preferir tenofovir-based TARV en pacientes em tratamiento de HCV com ribavirina. Monitorar hemograma quinzenalmente. Reducir dosis de ribavirina ou transfundir se Hb < 8 g/dL',
    'Anemia grave — Ribavirina + Abacavir: hemólise e reducción de la eficácia antiviral',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 208 — Lamivudina + Sorbitol (absorción oral)
  ('lamivudina', 'sorbitol',
    InteractionSeverity.moderate,
    'Sorbitol (adoçante e excipiente de xaropes e suspensões) reduz significativamente a absorción oral da lamivudina em solução oral; mecanismo: aceleração do trânsito intestinal pelo efecto osmótico do sorbitol; coadministração de 3,2 g de sorbitol reduziu a AUC da lamivudina oral em 20%; dosiss maiores de sorbitol podem ter impacto maior',
    'Reducción das concentraciones de lamivudina com riesgo de concentraciones subterapéuticas e posible fracaso virológico no tratamiento de HIV ou hepatite B',
    'Usar formulação em comprimidos (não xarope) de lamivudina sempre que posible. Se solução oral for necesaria (pediatria, disfagia), verificar se outros xaropes/medicamentos contêm sorbitol. Administrar lamivudina separada dos medicamentos com sorbitol',
    'Absorción reducida — Sorbitol reduz lamivudina oral 20%: preferir comprimidos',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // 209 — Alirocumabe (iPCSK9) + Varfarina
  ('alirocumabe', 'varfarina',
    InteractionSeverity.minor,
    'Alirocumabe (anticorpo monoclonal) não é metabolizado pelo CYP450 e não possui interacciones farmacocinéticas clinicamente significativas com a varfarina; a combinación é frecuente en pacientes de alto riesgo cardiovascular com FA ou trombosis em anticoagulação; o riesgo cardiovascular reducido pelo alirocumabe pode, indiretamente, melhorar a estabilidade do INR ao reduzir a inflamação sistêmica',
    'Sem interacción farmacológica direta; reacciones no local de injeção do alirocumabe não interferem com o INR; raras reacciones alérgicas generalizadas podem causar instabilidade hemodinâmica',
    'Sem necessidade ajuste de dosis. Combinación segura e clinicamente relevante. Continuar monitoramento habitual do INR. Verificar e tratar fatores que interferem no INR independentemente do alirocumabe',
    'Combinación segura — Alirocumabe + Varfarina: sem interacción clinicamente relevante',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 210 — Inclisirán (siRNA anti-PCSK9) + Estatinas
  ('inclisiran', 'atorvastatina',
    InteractionSeverity.minor,
    'Inclisirán é um siRNA (RNA de interferência pequeno) que inibe a síntese hepática de PCSK9; não possui interacciones farmacocinéticas com estatinas (não metabolizado pelo CYP450, injetável SC); a combinación resulta em reducción adicional de LDL de 50–55% sobre a estatina, sendo altamente benéfica e recomendada',
    'Sem toxicidad adicional farmacológica; reacciones no local de injeção (eritema, dor) são os únicos eventos adversos específicos do inclisirán; mialgias das estatinas não são potencializadas pelo inclisirán',
    'Combinación recomendada e altamente eficaz. Dosar LDL-C 3 meses después de cada injeção de inclisirán para confirmar resposta. Continuar a estatina em dosis máxima tolerada',
    'Combinación recomendada — Inclisirán + Estatina: sinergia no controle do LDL-C',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 211 — Finerenona + Itraconazol (CYP3A4 severa)
  ('finerenona', 'itraconazol',
    InteractionSeverity.contraindicated,
    'Finerenona (antagonista seletivo de mineralocorticoides não esteroidal) é metabolizada predominantemente pelo CYP3A4; itraconazol é potente inhibidor do CYP3A4; a inhibición aumenta a AUC da finerenona em ~12x, causando exposición extremamente elevada',
    'Hiperpotasemia grave (K+ > 6 mEq/L), hipotensión grave, arritmias cardíacas por hiperpotasemia; a exposición aumentada em 12x é extremamente perigosa',
    'Contraindicado. Usar azóis de menor potência inibitória (fluconazol — cautela, apenas dosis única) ou anfotericina tópica. Monitorar K+ e PA urgente se a combinación ocorrer inadvertidamente',
    'CONTRAINDICADO — Itraconazol + Finerenona: exposición 12x maior = hiperpotasemia fatal',
    EvidenceLevel.established,
    {RiskType.hyperkalemia, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 212 — Finerenona + IECA + iSGLT2 (hiperpotasemia tripla)
  ('finerenona', 'enalapril',
    InteractionSeverity.major,
    'Finerenona bloqueia receptores de mineralocorticoides retendo potássio; IECAs reduzem a aldosterona (aumentando K+); iSGLT2 têm efecto natriurético e podem aumentar levemente o potássio por mecanismo renal; a triple therapy tem efecto hipercalêmico aditivo significativo, especialmente em diabetes com DRC (indicação principal de finerenona)',
    'Hiperpotasemia grave (K+ > 6 mEq/L) com riesgo de arritmias letais; a combinación de 3 fármacos que aumentam o potássio en pacientes com DRC (TFG < 60) é de alto riesgo',
    'Monitorar K+ después de 4 semanas do inicio de finerenona com IECA e iSGLT2. Alvo K+ < 5,0 mEq/L antes de iniciar finerenona. Não iniciar se K+ > 5,0 mEq/L. Dieta hipossódica e hipopotássica. Patiromer como quelante de potássio se necesario para permitir o uso da triple therapy',
    'Hiperpotasemia tripla — Finerenona + IECA + iSGLT2: monitorar K+ em DRC/Diabetes',
    EvidenceLevel.probable,
    {RiskType.hyperkalemia},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 213 — Mavacamten + Verapamil (disfunção sistólica sinérgica)
  ('mavacamten', 'verapamil',
    InteractionSeverity.major,
    'Mavacamten é inhibidor seletivo de miosina cardíaca, reduzindo a contratilidade miocárdica para tratar obstrução na miocardiopatia hipertrófica obstrutiva (MHCO); verapamil reduz a contratilidade (efecto inotrópico negativo) e a frecuencia cardíaca; a combinación causa reducción sinérgica da função sistólica com riesgo de descompensação cardíaca grave',
    'Descompensação de insuficiencia cardíaca aguda, reducción grave da fração de ejeção (FE < 50%), edema pulmonar agudo; hipotensión, síncope',
    'Contraindicado com mavacamten. Verapamil é frecuentemente usado na MHCO como alternativa ao beta-bloqueador — sustituir por beta-bloqueador cardioselective (metoprolol, bisoprolol) al iniciar mavacamten. Monitorar ecocardiograma a cada 4–6 semanas',
    'Disfunção cardíaca grave — Mavacamten + Verapamil: inotrópico negativo sinérgico',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 214 — Sacubitrila/Valsartana + Diuréticos (hipovolemia)
  ('sacubitrila', 'hidroclorotiazida',
    InteractionSeverity.moderate,
    'Sacubitrila/valsartana inibe a neprilisina e o receptor AT1, causando natriurese e vasodilatação (reducción de pré e pós-carga); tiazídicos e diuréticos de alça adicionam efecto natriurético e diurético; a combinación pode causar depleción de volumen excessiva, especialmente al iniciar sacubitrila en pacientes já em diuréticos de alça',
    'Hipotensión sintomática, tontura, síncope, insuficiencia renal pré-renal, hipopotasemia',
    'Reducir dosis de diurético de alça em 25–50% antes de iniciar sacubitrila/valsartana. Monitorar PA, función renal e electrolitos nas primeiras 2–4 semanas. Titular sacubitrila lentamente. A diurese é, em parte, desejável na ICC com congestão',
    'Hipovolemia — Sacubitrila/Valsartana + Diuréticos: reduzir diurético al iniciar Entresto',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.electrolyte},
    [_kRefGG, _kRefFDA, _kRefUT]),

  // 215 — Empagliflozina + Acetazolamida (cetoacidosis)
  ('empagliflozina', 'acetazolamida',
    InteractionSeverity.major,
    'iSGLT2 promovem glicosúria e podem causar cetoacidosis diabética euglicêmica (CAD-E) por aumento da cetogênese; acetazolamida inibe a anidrase carbônica, causando acidosis metabólica hiperclorêmica (tipo 2); a combinación de dois mecanismos de acidosis metabólica pode precipitar acidosis grave',
    'Cetoacidosis diabética euglicêmica grave, acidosis metabólica mista (lática + cetótica + hiperclorêmica); confusión mental, taquipneia, vômitos, colapso hemodinâmico',
    'Evitar combinación. Se acetazolamida for necesaria (glaucoma, altitude), suspender iSGLT2 48–72 horas antes. Monitorar cetonas urinárias/sanguíneas e pH. Dieta pobre em carboidratos é fator de riesgo adicional para CAD-E',
    'CAD euglicêmica — iSGLT2 + Acetazolamida: duas acidosiss metabólicas simultâneas',
    EvidenceLevel.probable,
    {RiskType.other},
    [_kRefGG, _kRefFDA]),

  // 216 — Ozempic (semaglutida) + Antiepilépticos (absorción oral)
  ('semaglutida', 'lamotrigina',
    InteractionSeverity.moderate,
    'Semaglutida oral (Rybelsus) requer pH gástrico ácido e absorción muito específica (tomada em jejum, 30 min antes de qualquer alimento/bebida); qualquer fármaco que aumente o pH gástrico ou a motilidade pode reduzir sua absorción; lamotrigina oral tem absorción duodenal e o retardo do esvaziamento gástrico pela semaglutida SC pode reduzir a absorción de lamotrigina',
    'Para semaglutida oral: falha do efecto hipoglucemiante por absorción inadecuada; para semaglutida SC: retardo na absorción da lamotrigina com pico mais lento e posible reducción del nivel no estado de equilíbrio (< 15% para a maioria dos antiepilépticos)',
    'Para semaglutida oral: tomar sempre em jejum, 30 min antes de qualquer outro medicamento. Para semaglutida SC: monitorar nivel de lamotrigina se houver perda de control de crisis. A interacción é generalmente de magnitude pequena',
    'Absorción leve reducida — Semaglutida + Antiepilépticos orais: tomar lamotrigina después de 30 min',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // 217 — Tirzepatida + Contraceptivos orais (absorción)
  ('tirzepatida', 'etinilestradiol',
    InteractionSeverity.moderate,
    'Tirzepatida (agonista dual GIP/GLP-1) retarda significativamente o esvaziamento gástrico; contraceptivos orais combinados têm absorción intestinal que pode ser prejudicada pelo retardo gástrico; o estudo SURPASS-4 demonstrou reducción del Cmax do etinilestradiol em 33% e da noretindrona em 13% quando administrados 30 min después de tirzepatida',
    'Posible reducción de la concentración máxima de esteroides sexuais com riesgo de fracaso contraceptiva, especialmente nas primeiras semanas de uso de tirzepatida quando o efecto no esvaziamento gástrico é mais pronunciado',
    'Para as primeiras 4 semanas de tirzepatida e después de cada aumento de dosis: usar método contraceptivo adicional (preservativo). Administrar contraceptivo oral com 30 min de antecedência à refeição e separado da tirzepatida. A interacción é mais pronunciada durante as primeiras 4 semanas',
    'Fracaso contraceptivo potencial — Tirzepatida retarda absorción de COC: usar preservativo nas 4 primeiras semanas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 218 — Naltrexona + Opioides (bloqueio e precipitação de abstinência)
  ('naltrexona', 'morfina',
    InteractionSeverity.contraindicated,
    'Naltrexona é antagonista puro de receptores opioides (mu, kappa, delta) com alta afinidade e longa duración de ação; en pacientes dependentes de opioides, a naltrexona precipita síndrome de abstinencia aguda grave; mesmo en pacientes não-dependentes, bloqueia completamente o efecto analgésico dos opioides',
    'Síndrome de abstinencia precipitada em dependentes: diaforese, tremor, ansiedade extrema, vômitos, mialgias, hipertensão, taquicardia, posible colapso; bloqueio analgésico completo em situações de dor aguda',
    'Contraindicado en pacientes com dependência de opioides (aguardar 7–10 dias de abstinência completa antes de iniciar naltrexona). Em emergências analgésicas com paciente em naltrexona: opioides em dosiss extremamente altas podem superar o bloqueio com riesgo de depresión respiratoria; preferir analgesia regional ou AINEs',
    'CONTRAINDICADO em dependentes — Naltrexona + Opioides: abstinência precipitada ou sem analgesia',
    EvidenceLevel.established,
    {RiskType.other, RiskType.cns},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 219 — Buprenorfina + Benzodiazepínicos (depresión respiratoria)
  ('buprenorfina', 'diazepam',
    InteractionSeverity.major,
    'Buprenorfina é agonista parcial de receptores mu-opioides e antagonista kappa; benzodiazepínicos potencializam a depresión del SNC via receptores GABA-A; a combinación causa depresión respiratoria sinérgica, especialmente em dosiss elevadas de BZD e en pacientes não tolerantes a opioides; cases fatais documentados, especialmente por via IV de buprenorfina com BZD injetável',
    'Depresión respiratoria grave, hipóxia, coma, morte; o riesgo é maior com benzodiazepínicos de alta potência (flunitrazepam, triazolam) ou IV',
    'Usar com extrema cautela. A combinación é às vezes necesaria em manejo da dor (buprenorfina + BZD ansiolítico). Preferir BZD de menor potência e menor dosis. Orientar al paciente sobre proibição de automedicação adicional de BZD. Naloxona reverte parcialmente a buprenorfina (agonismo parcial é difícil de reverter)',
    'Morte respiratória — Buprenorfina + Benzodiazepínico: depresión respiratoria sinérgica',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 220 — Metadona + Fluconazol (QT + CYP3A4/CYP2C19)
  ('metadona', 'fluconazol',
    InteractionSeverity.major,
    'Metadona prolonga o QT por bloqueio de canais hERG (IKr); fluconazol inibe o CYP3A4 e CYP2C19, principais enzimas de metabolismo de la metadona, aumentando seus niveles em 35–50%; combinación de aumento das concentraciones (PK) + efecto direto no QT (PD) da metadona resulta em riesgo substancial de torsades de pointes',
    'QTc > 500 ms, torsades de pointes, fibrilación ventricular, morte súbita; o riesgo é maior nos primeiros dias de fluconazol (antes da nova steady-state da metadona)',
    'Monitorar ECG antes e 3–5 dias después de inicio do fluconazol. Reducir dosis de metadona em 15–20% preventivamente. Preferir nistatina tópica ou fluconazol em dosis única (menor impacto no QT) para candidíase oral. Em candidíase sistêmica: micafungina ou anidulafungina como alternativas sistêmicas sem interacción CYP',
    'QT grave + niveles de metadona aumentados — Fluconazol + Metadona: monitorar ECG urgente',
    EvidenceLevel.established,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT, _kRefFDA]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 9 — Psiquiatria avançada, Neurologia, Respiratório (221–250)
  // ═══════════════════════════════════════════════════════════════

  // 221 — Clozapina + Ácido Valpróico (sedación + convulsiones paradoxais)
  ('clozapina', 'valproato',
    InteractionSeverity.moderate,
    'A combinación de clozapina com valproato é paradoxalmente arriscada: ambos têm ação GABAérgica e sedativa aditiva; valproato pode inibir o CYP2D6 e a glucuronidação, aumentando os niveles de clozapina em 15–40%; además, altas dosis de clozapina diminuem o limiar convulsivo e valproato pode ter efecto protetor parcial mas insuficiente; casos de convulsiones com a combinación são reportados',
    'Sedación excesiva, depresión respiratoria, convulsiones paradoxais em dosis altas de clozapina (> 600 mg/dia); prolongación del QT pela soma dos efectos; hipotensión ortostática grave',
    'Monitorar nivel de clozapina (alvo 350–600 ng/mL) al iniciar valproato. Monitorar ECG. En pacientes em riesgo de convulsiones por clozapina (dosis altas, perda rápida de peso, hiponatremia), usar lamotrigina ou levetiracetam em vez de valproato como anticonvulsivante adjunto',
    'Sedación e convulsiones paradoxais — Clozapina + Valproato: monitorar nivel de clozapina',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.seizure},
    [_kRefGG, _kRefUT]),

  // 222 — Aripiprazol + CYP2D6 inhibidores (bupropiona)
  ('aripiprazol', 'bupropiona',
    InteractionSeverity.moderate,
    'Bupropiona é inhibidor potente do CYP2D6; aripiprazol é metabolizado principalmente pelo CYP2D6 (e CYP3A4); a inhibición del CYP2D6 pela bupropiona aumenta os niveles de aripiprazol em 2–3x, aumentando o riesgo de efectos adversos; bupropiona per se também tem propriedades dopaminérgicas/noradrenérgicas que podem interagir com aripiprazol dopaminérgico',
    'Toxicidad por aripiprazol: acatisia intensa, insônia, ansiedade, taquicardia, tontura; posible piora de síntomas psicóticos por estimulação dopaminérgica excessiva',
    'Monitorar efectos adversos de aripiprazol al iniciar bupropiona. Reducir dosis de aripiprazol em 50% (ex: de 15 mg para 10 mg/dia) se combinación for necesaria. Al suspender bupropiona, restaurar dosis original de aripiprazol monitorando eficácia',
    'Toxicidad de aripiprazol — Bupropiona inibe CYP2D6: reducir dosis de aripiprazol 50%',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 223 — Olanzapina + Tabaco (inducción CYP1A2)
  ('olanzapina', 'tabaco',
    InteractionSeverity.moderate,
    'O tabaco contém hidrocarbonetos policíclicos aromáticos (HPA) que são potentes inductores do CYP1A2 (não a nicotina em si); olanzapina é metabolizada principalmente pelo CYP1A2; fumantes têm niveles de olanzapina 30–50% menores que não-fumantes pela inducción enzimática; ao cessar o tabagismo (hospitalizações, internações psiquiátricas), os niveles de olanzapina aumentam rapidamente',
    'Em fumantes: niveles subterapéuticos com necessidade dosiss maiores; ao parar de fumar (internación): aumento abrupto de niveles com toxicidad (sedación, aumento de peso, síndrome metabólica); o riesgo é inverso — ao cessar, os niveles sobem',
    'Informar paciente e equipe sobre esta interacción ao hospitalizar fumantes. Monitorar nivel de olanzapina durante internación (pode precisar reducir dosis 25–30% ao parar de fumar). Ao retornar ao fumo después de internación: restaurar dosis mais alta anterior com monitoramento de eficácia',
    'Nivel de olanzapina 30–50% menor em fumantes — Ao cessar tabagismo: reducir dosis urgente',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.cns},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 224 — Paliperidona + Carbamazepina (CYP3A4 + P-gp inducción)
  ('paliperidona', 'carbamazepina',
    InteractionSeverity.major,
    'Carbamazepina induz o CYP3A4 e a P-gp (glicoproteína-P); paliperidona é substrato da P-gp e parcialmente do CYP3A4; a inducción de la P-gp pela carbamazepina reduz os niveles de paliperidona em 37% (estudo de bula); a carbamazepina também reduz os niveles de outras antipsicóticos metabolizados pelo CYP',
    'Concentraciones subterapéuticas de paliperidona com riesgo de recaída psicótica, descompensação de esquizofrenia, hospitalización psiquiátrica',
    'Evitar combinación si es posible. Se antiepiléptico for necesario em esquizofrenia, preferir lamotrigina, levetiracetam ou ácido valpróico (menor interacción com paliperidona). Se a combinación for indispensable, pode ser necesario aumentar dosis de paliperidona e monitorar nivel sérico',
    'Falha antipsicótica — Carbamazepina reduz paliperidona 37%: trocar antiepiléptico',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefFDA]),

  // 225 — Quetiapina + Fenitoína (CYP3A4 inducción)
  ('quetiapina', 'fenitoina',
    InteractionSeverity.major,
    'Fenitoína induz o CYP3A4, principal vía de metabolismo de la quetiapina; a inducción reduz os niveles de quetiapina em 80% (5x de reducción na AUC), tornando a dosis habitual totalmente ineficaz; fenitoína é um dos mais potentes inductores do CYP3A4 conhecidos',
    'Falha terapéutica quase certa da quetiapina com recaída psicótica ou maníaca grave; necessidade dosiss extremamente altas (5x acima do habitual) para manter eficácia',
    'Contraindicação relativa — evitar. Sustituir fenitoína por levetiracetam ou lamotrigina. Se a combinación for indispensable, dosis de quetiapina de 1.500–2.000 mg/dia podem ser necesarias (monitoramento clínico rigoroso). Al suspender fenitoína: reduzir quetiapina inmediatamente para evitar toxicidad',
    'FRACASO TERAPÉUTICO — Fenitoína reduz quetiapina 80%: trocar antiepiléptico urgente',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT]),

  // 226 — Lítio + Carbamazepina (toxicidad do SNC)
  ('litio', 'carbamazepina',
    InteractionSeverity.major,
    'A combinación de lítio com carbamazepina pode causar toxicidad neurológica sinérgica mesmo com concentraciones séricas de ambos dentro dos limites terapéuticos; carbamazepina pode aumentar a excreción de sódio, aumentando indiretamente os niveles de lítio; ambos têm mecanismos complexos de ação no SNC que se sobrepõem em populações de canais iônicos',
    'Síndrome neurotóxica: tremor, ataxia, nistagmo, confusión mental, sintomas cerebelares, convulsiones; o efecto pode ocorrer com litemias aparentemente normais (1,0–1,2 mEq/L)',
    'Monitorar clinicamente e com litemia e nivel de carbamazepina. Manter litemia no limite inferior do terapéutico (0,6–0,8 mEq/L) quando em combinación. Hidratação adecuada. Monitorar sódio sérico',
    'Toxicidade neurológica sinérgica — Lítio + Carbamazepina: mesmo com niveles normais',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.seizure},
    [_kRefGG, _kRefKatz]),

  // 227 — Lamotrigina + Anticoncepcionais orais (inducción UGT)
  ('lamotrigina', 'etinilestradiol',
    InteractionSeverity.major,
    'Anticoncepcionais orais contendo etinilestradiol induzem a glucuronidação (UGT1A4) da lamotrigina, aumentando seu metabolismo e reduzindo seus niveles em 40–60%; inversamente, al suspender o anticonceptivo (semana de pausa dos pílulas combinadas ou ao descontinuar), os niveles de lamotrigina sobem abruptamente em 40–60%, causando toxicidad',
    'Durante o uso do COC: concentraciones subterapéuticas de lamotrigina com riesgo de crisis convulsivas; durante a semana de pausa da pílula: pico tóxico de lamotrigina (diplopia, ataxia, tontura, vômitos); al suspender COC definitivamente: toxicidad de lamotrigina',
    'Monitorar nivel de lamotrigina ao iniciar/suspender COC. Pode ser necesario aumentar dosis de lamotrigina em 50% al iniciar COC. Reducir la dosis al suspender COC. Durante semana de pausa: informar paciente sobre possíveis efectos; considerar pílulas sem pausa (uso contínuo)',
    'Crisis epilépticas e toxicidad bidirecional — COC + Lamotrigina: monitorar nivel ao iniciar/suspender',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.seizure},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 228 — Levetiracetam + Metronidazol
  ('levetiracetam', 'metronidazol',
    InteractionSeverity.moderate,
    'Metronidazol pode potencializar os efectos neurológicos do levetiracetam; ambos têm propriedades neuromodulatórias; metronidazol pode causar encefalopatía, especialmente em uso prolongado ou en pacientes com insuficiencia hepática; a combinación soma efectos neurológicos adversos',
    'Confusión mental, sonolência excessiva, ataxia, psicose; encefalopatía por metronidazol pode ser confundida com ajuste inadecuado do levetiracetam',
    'Monitorar cuidadosamente signos neurológicos durante combinación. Limitar uso de metronidazol a cursos curtos (< 14 dias). Em encefalites ou infecções de SNC, monitorar EEG e nivel de levetiracetam se piora neurológica',
    'Toxicidade neurológica aditiva — Levetiracetam + Metronidazol: monitorar estado mental',
    EvidenceLevel.possible,
    {RiskType.cns},
    [_kRefGG]),

  // 229 — Duloxetina + Tamoxifeno (inhibición CYP2D6)
  ('duloxetina', 'tamoxifeno',
    InteractionSeverity.major,
    'Duloxetina é inhibidor moderado a potente do CYP2D6; tamoxifeno requer ativação pelo CYP2D6 ao seu metabólito ativo endoxifeno (4–10x mais potente que o tamoxifeno original); a inhibición del CYP2D6 pela duloxetina reduz os niveles de endoxifeno em 50–70%, comprometendo a eficácia antiestrogênica do tamoxifeno no câncer de mama',
    'Reducción de la eficacia do tamoxifeno no câncer de mama dependente de estrogênio; aumento del riesgo de recurrencia do câncer de mama en pacientes em uso concomitante de ISRS/IRSNa fortes inhibidores do CYP2D6',
    'Evitar duloxetina (e outros fortes inhibidores de CYP2D6: paroxetina, fluoxetina, bupropiona) en pacientes em tamoxifeno. Usar antidepresivos/ansiolíticos com menor inhibición de CYP2D6 para sintomas menopausais e depressão: venlafaxina, escitalopram, citalopram, mirtazapina',
    'Recurrencia de câncer de mama — Duloxetina inibe CYP2D6: endoxifeno reducido 50–70%',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 230 — Venlafaxina + Tramadol (síndrome serotoninérgica)
  ('venlafaxina', 'tramadol',
    InteractionSeverity.major,
    'Venlafaxina é inhibidor da recaptação de serotonina e noradrenalina (IRSNA); tramadol inibe a recaptação de serotonina e noradrenalina além de atuar em receptores mu-opioides; a combinación potencia a atividade serotoninérgica sinapticamente com riesgo de síndrome serotoninérgica, especialmente em dosis altas ou em metabolizadores lentos do CYP2D6 (que acumulam tramadol)',
    'Síndrome serotoninérgica: tremor fino, agitação, diarreia, hiperreflexia, mioclonias, diaforese, hipertermia, taquicardia; pode progredir para convulsiones, rabdomiólisis e insuficiência de múltiplos órgãos',
    'Usar com cautela. Preferir opioides sem atividade serotoninérgica (morfina, oxicodona, hidromorfona) en pacientes em venlafaxina. Se tramadol for necesario, usar dosis mínima por período curto com monitoramento de sintomas serotoninérgicos. Criptoimidazol como antídoto parcial se toxicidad grave',
    'Síndrome serotoninérgica — Venlafaxina + Tramadol: preferir morfina como opioide',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cns},
    [_kRefGG, _kRefMdx, _kRefUT]),

  // 231 — Sertralina + Piroxicam/AINE (sangrado GI)
  ('sertralina', 'piroxicam',
    InteractionSeverity.major,
    'ISRS reduzem a função plaquetária ao depletar as reservas de serotonina das plaquetas (que dependem do transportador SERT para captação de serotonina e armazenamento nos grânulos densos); AINEs inibem a COX-1 plaquetária, reduzindo a síntese de tromboxano A2; ambos prejudicam a hemostasia primária por mecanismos diferentes; efecto sinérgico no riesgo hemorrágico gastrointestinal',
    'Sangramento gastrointestinal superior (úlcera, erosão gástrica, gastrite hemorrágica); riesgo aumentado de 7–15x em comparação com uso isolado de AINE; hemorragia digestiva alta potencialmente grave',
    'Preferir paracetamol para dor en pacientes em ISRS. Se AINE for necesario, usar protección gástrica com IBP (omeprazol 20 mg/dia). Considerar ISRS com menor atividade antiplaquetária (citalopram). Monitorar fezes e HB em uso crônico',
    'Sangrado GI 7–15x maior — ISRS + AINE: usar IBP obligatorio se combinación necesaria',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 232 — Mirtazapina + Álcool (sedación extrema)
  ('mirtazapina', 'alcool',
    InteractionSeverity.major,
    'Mirtazapina tem potente efecto sedante via antagonismo dos receptores H1-histaminérgicos e alfa-2 adrenérgicos; o álcool potencializa a depresión del SNC de forma sinérgica; a combinación causa sedación extrema desproporcional ao consumo de álcool; mirtazapina nas dosiss mais baixas (7,5–15 mg) é mais sedativa que em dosis altas',
    'Sedación extrema com comprometimento psicomotor grave, depresión respiratoria em dosiss elevadas de álcool, hipotensión, amnésia anterógrada; riesgo de acidentes automobilísticos e quedas',
    'Orientar abstinência alcoólica durante tratamiento com mirtazapina. Se o paciente beber, não operar veículos ou máquinas. Contra-indicação relativa em alcoólatras ativos. Monitorar función hepática (mirtazapina tem metabolismo hepático)',
    'Sedación extrema — Mirtazapina + Álcool: depresión del SNC sinérgica, evitar dirigir',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefMdx]),

  // 233 — Quetiapina + Succo de toranja/Grapefruit (CYP3A4 intestinal)
  ('quetiapina', 'grapefruit',
    InteractionSeverity.major,
    'O suco de toranja contém furanocumarinas (bergamotina, 6,7-diidroxibergamotina) que inibem irreversivelmente o CYP3A4 intestinal; quetiapina tem extensa metabolização de primeira passagem pelo CYP3A4 intestinal; o suco de toranja pode aumentar a biodisponibilidad da quetiapina em 50–100%, dobrando os niveles plasmáticos com um único copo de 200 mL',
    'Hipotensión ortostática grave, sedación extrema, prolongación del QT por supraexposición à quetiapina; riesgo de síncope e torsades de pointes',
    'Orientar evitar suco de toranja e frutas cítricas tipo grapefruit durante tratamiento com quetiapina (e outros antipsicóticos e BZD metabolizados pelo CYP3A4). Laranja comum é segura. Suco de laranja-bahia/pomelo também tem riesgo',
    'Niveles dobram — Suco de toranja + Quetiapina: inhibición CYP3A4 intestinal, hipotensión e QT',
    EvidenceLevel.established,
    {RiskType.plasmaLevel, RiskType.qtProlongation},
    [_kRefGG, _kRefMdx]),

  // 234 — Dupilumabe (biológico anti-IL4/13) + Vacinas vivas
  ('dupilumabe', 'vacina_viva',
    InteractionSeverity.moderate,
    'Dupilumabe bloqueia o receptor da IL-4 e IL-13, comprometendo a imunidade do tipo Th2; diferentemente dos inmunosupresores clássicos e anti-TNF, o dupilumabe não compromete significativamente a imunidade celular Th1 e a resposta a vacinas vivas; o riesgo é teórico e menor que com biológicos anti-TNF, mas ainda presente',
    'Riesgo teórico de enfermedad disseminada pela cepa vacinal em imunocompromissão Th2 grave; na prática, menos casos reportados que com anti-TNF',
    'Precaución — não contraindicação absoluta. Vacinar preferencialmente antes de iniciar dupilumabe. Se necesario vacinar durante o tratamiento, discutir com especialista. Vacinas inativadas são seguras e recomendadas (influenza, pneumocócica)',
    'Precaución — Dupilumabe + vacinas vivas: menor riesgo que anti-TNF, mas preferir vacinar antes',
    EvidenceLevel.possible,
    {RiskType.infection},
    [_kRefFDA, _kRefGG]),

  // 235 — Mepolizumabe (anti-IL5) + Corticoides (retirada)
  ('mepolizumabe', 'prednisona',
    InteractionSeverity.moderate,
    'Mepolizumabe (anticorpo anti-IL-5) reduz a inflamação eosinofílica na asma grave, podendo permitir a reducción gradual dos corticoides orais; al iniciar mepolizumabe en pacientes com asma grave corticoidedependente, há possibilidade reduzir e eventualmente suspender os corticoides; a retirada rápida de corticoides pode desmascarar insuficiencia adrenal por supresión prévia do eixo HPA',
    'Insuficiencia adrenal aguda durante a retirada de corticoides: fadiga intensa, hipotensión, hipoglucemia, hiponatremia, colapso hemodinâmico; síndrome de Churg-Strauss (vasculite eosinofílica) ao reduzir corticoides em alguns pacientes com eosinofilia grave',
    'Reducción dos corticoides deve ser lenta e gradual (10% da dosis a cada 4 semanas) después de inicio do mepolizumabe. Monitorar eosinófilos e função adrenal (cortisol basal). Reconhecer sinais de insuficiencia adrenal. Considerar teste de estimulação com ACTH antes de suspender corticoide',
    'Insuficiencia adrenal — Retirada de corticoide al iniciar mepolizumabe: fazer gradualmente',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 236 — Omalizumabe (anti-IgE) + Beta-agonistas
  ('omalizumabe', 'indacaterol',
    InteractionSeverity.minor,
    'Omalizumabe (anti-IgE) não tem interacciones farmacocinéticas com LABAs; a combinación é terapéutica e frecuente em asma grave não controlada; omalizumabe reduz a resposta inflamatória mediada por IgE enquanto o LABA causa broncodilatação direta; a combinación é tanto segura quanto clinicamente benéfica e recomendada pelas diretrizes de asma',
    'Sem efecto adverso adicional farmacológico relevante; reacciones locais à injeção de omalizumabe (eritema, edema) independem do LABA',
    'Combinación segura e recomendada nas diretrizes GINA para asma grave. Monitorar eosinófilos, IgE sérica e função pulmonar para avaliar resposta ao omalizumabe. Manter LABA para controle sintomático',
    'Combinación segura e recomendada — Omalizumabe + LABA: sinergia na asma grave',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefGG, _kRefFDA]),

  // 237 — Tezepelumabe (anti-TSLP) + Corticoides inalatórios
  ('tezepelumabe', 'budesonida',
    InteractionSeverity.minor,
    'Tezepelumabe (anticorpo anti-TSLP) não possui interacciones farmacocinéticas com corticoides inalatórios; a combinación é a base do tratamiento da asma grave eosinofílica ou do tipo 2 e é a combinación padrão nos estudos (NAVIGATOR trial); tezepelumabe reduz exacerbações e permite reducción de la dosis de corticoide inalatório em muitos pacientes',
    'Sem toxicidad adicional pela combinación; a reducción progressiva do corticoide inalatório ao longo do tempo com tezepelumabe é desejável mas deve ser gradual',
    'Combinación terapéutica recomendada. Después de 6–12 meses de boa resposta ao tezepelumabe, considerar reduzir gradualmente o corticoide inalatório para a menor dosis eficaz. Monitorar eosinófilos e FeNO como biomarcadores de resposta',
    'Combinación terapéutica — Tezepelumabe + Corticoide inalatório: permite reducción del CI',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 238 — Aclidínio (LAMA) + Anticolinérgicos sistêmicos (somação)
  ('aclidinio', 'solifenacina',
    InteractionSeverity.moderate,
    'Aclidínio é LAMA (antagonista muscarínico de ação prolongada) para DPOC com ação predominantemente pulmonar (alta afinidade por M3); solifenacina é anticolinérgico para bexiga hiperativa com ação periférica sistêmica; ambos bloqueiam receptores muscarínicos M2/M3 causando efectos anticolinérgicos sistêmicos somados quando usados simultáneamente',
    'Retenção urinária (especialmente em HPB), constipação intestinal grave, taquicardia, boca seca intensa, visão turva, confusión mental (idosos), glaucoma de ângulo fechado; "carga anticolinérgica" elevada com riesgo de síndromes anticolinérgicas',
    'Avaliar necessidade clínica de ambos. En ancianos, usar escala de carga anticolinérgica. Preferir LAMA para DPOC e terapias alternativas para bexiga hiperativa (fisioterapia pélvica, betanecol, mirabegron que é beta-3 agonista sem anticolinérgio)',
    'Carga anticolinérgica elevada — LAMA + Anticolinérgico sistêmico: riesgo en ancianos',
    EvidenceLevel.probable,
    {RiskType.other, RiskType.cns},
    [_kRefGG, _kRefKatz]),

  // 239 — Sildenafila (HAP) + Riociguate (hipertensão pulmonar)
  ('sildenafila', 'riociguate',
    InteractionSeverity.contraindicated,
    'Sildenafila inibe a PDE-5, aumentando o GMPc e causando vasodilatação pulmonar; riociguate estimula diretamente a guanilato ciclase solúvel, também aumentando o GMPc; ambos aumentam o GMPc por mecanismos diferentes (complementares) mas o efecto vasodilatador combinado é extremamente potente, causando hipotensión grave que não responde ao tratamiento convencional',
    'Hipotensión grave e refratária (PA < 60/40 mmHg), síncope, colapso hemodinâmico, morte; a interacción foi motivo de contraindicação formal pela FDA e EMA',
    'Contraindicado. Aguardar 24 horas después de suspensión de sildenafila antes de iniciar riociguate (y viceversa). Em hipertensão arterial pulmonar refratária, escolher um mecanismo por vez. No combinar qualquer inhibidor de PDE-5 com riociguate',
    'CONTRAINDICADO — Sildenafila + Riociguate: hipotensión fatal por GMPc excessivo',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 240 — Pirfenidona + Fluvoxamina (CYP1A2 inhibición)
  ('pirfenidona', 'fluvoxamina',
    InteractionSeverity.major,
    'Pirfenidona (antifibrótico para fibrose pulmonar idiopática) é metabolizada principalmente pelo CYP1A2; fluvoxamina é potente inhibidor do CYP1A2; a inhibición aumenta os niveles plasmáticos de pirfenidona em ~4x, causando exposición muito elevada',
    'Toxicidade grave da pirfenidona: náuseas, vômitos, anorexia, fotossensibilidade grave, hepatotoxicidad, tontura; os efectos adversos são dosis-dependentes e muito frecuentes com niveles 4x maiores',
    'Contraindicado com fluvoxamina. Usar antidepresivos sem inhibición CYP1A2 (escitalopram, sertralina, mirtazapina). Também evitar ciprofloxacino, mexiletina e enoxacino em usuários de pirfenidona. O tabagismo induz CYP1A2 e reduz a eficácia da pirfenidona',
    'Toxicidade grave de pirfenidona — Fluvoxamina inibe CYP1A2: 4x de exposición',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 241 — Nintedanibe + Rifampicina (CYP3A4 e P-gp)
  ('nintedanibe', 'rifampicina',
    InteractionSeverity.major,
    'Nintedanibe (inhibidor de tirosina quinase para FPI) é substrato do CYP3A4 e da P-gp; rifampicina induz ambos; a coadministração reduz a AUC do nintedanibe em 50% e o Cmax em 60%; com concentraciones tão reducidas, a eficácia antifibrótica é comprometida',
    'Falha terapéutica do nintedanibe com progresión da fibrose pulmonar; deterioração da função pulmonar (CVF, DLCO) por concentraciones subterapéuticas',
    'Evitar combinación. Se antituberculoso for necesario (coinfecção TB/FPI), considerar sustitución do nintedanibe durante o tratamiento de TB, retomando después de. Monitorar CVF a cada 3 meses. Não há alternativa com dosis ajustada validada',
    'Falha antifibrótica — Rifampicina reduz nintedanibe 50%: progresión da FPI',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 242 — Bosentana + Ciclosporina (inhibición e inducción mútua)
  ('bosentana', 'ciclosporina',
    InteractionSeverity.contraindicated,
    'Bosentana (antagonista de receptor de endotelina para HAP) induz o CYP3A4 e CYP2C9, reduzindo os niveles de ciclosporina em 50%; simultáneamente, ciclosporina inibe o transportador de captação hepática (OATP1B1/B3) de bosentana, aumentando os niveles de bosentana em 30x; o efecto líquido é toxicidad grave de bosentana com hepatotoxicidad e falha do inmunosupresor',
    'Hepatotoxicidad grave por acumulación de bosentana (30x de aumento); rejeição de órgão trasplantado por queda dos niveles de ciclosporina; insuficiencia hepática aguda',
    'Contraindicado. En pacientes trasplantados com HAP, usar riociguate ou prostanoides (epoprostenol, iloprost) que não têm esta interacción crítica. Macitentan tem menor interacción com ciclosporina que bosentana',
    'CONTRAINDICADO — Bosentana + Ciclosporina: 30x de bosentana = hepatotoxicidad + rejeição',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 243 — Iloprost inalatório + Anti-hipertensivos
  ('iloprost', 'amlodipina',
    InteractionSeverity.moderate,
    'Iloprost (prostaciclina sintética) causa vasodilatação pulmonar e sistêmica; bloqueadores de canal de cálcio (amlodipina, nifedipina) também causam vasodilatação sistêmica; a combinación pode resultar em hipotensión sistêmica excessiva que limita o uso do iloprost ou cause síncope',
    'Hipotensión sistêmica sintomática (PA < 90/60 mmHg), tontura, síncope, presíncope; a hipotensión sistêmica limita a titulación das dosiss terapéuticas do iloprost',
    'Monitorar PA antes e después de cada inalação de iloprost. Medir pressão em posição sentada e de pé (hipotensión ortostática). Pode ser necesario reducir dosis de amlodipina ou sustituir por hidralazina específica para reducción de pós-carga sem hipotensión sistêmica',
    'Hipotensión sistêmica — Iloprost + Bloqueadores de canal de cálcio: monitorar PA',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefUT]),

  // 244 — Selexipague + Fluconazol (CYP2C8)
  ('selexipague', 'fluconazol',
    InteractionSeverity.major,
    'Selexipague (agonista do receptor IP da prostaciclina) é hidrolisada ao metabólito ativo MRE-269 pelo CES1 e metabolizado pelo CYP2C8; fluconazol inibe o CYP2C8 (além de CYP3A4 e CYP2C19); a inhibición del CYP2C8 aumenta os niveles do metabólito ativo da selexipague em 1,7–2x',
    'Toxicidad del selexipague: cefaleia grave, dor mandibular, eritema, diarreia, hipotensión; riesgo aumentado de eventos vasculares periféricos por vasodilatação excessiva',
    'Monitorar síntomas de toxicidad al iniciar fluconazol. Reducir dosis de selexipague se necesario. Em infecção fúngica, usar equinocandinas (micafungina, anidulafungina) como alternativa sem interacción CYP2C8. Fluconazol em dosis única para candidíase oral tem menor impacto',
    'Toxicidad de selexipague — Fluconazol inibe CYP2C8: cefaleia e hipotensión',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 245 — Ciclesonida + Itraconazol (corticoide sistêmico)
  ('ciclesonida', 'itraconazol',
    InteractionSeverity.major,
    'Ciclesonida é pró-farmaco ativado pela esterase pulmonar ao des-ciclesonida ativo; a fração pulmonar ativa tem baixa absorción sistêmica; sin embargo, itraconazol (potente inhibidor CYP3A4) pode aumentar significativamente a fração sistêmica disponible da ciclesonida e de seu metabólito ativo, causando efectos corticosteroidais sistêmicos similares ao visto com budesonida',
    'Síndrome de Cushing iatrogênica com supresión adrenal; hiperglucemia, osteoporose acelerada, aumento de peso',
    'Evitar itraconazol en pacientes em ciclesonida em dosis altas. Usar anfotericina tópica ou nistatina oral para candidíase. Monitorar cortisol matinal e sinais de Cushing se combinación inevitável',
    'Cushing iatrogênico — Itraconazol + Ciclesonida: inhibición CYP3A4 sistêmica',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // 246 — Montelucaste + Fluconazol (CYP2C9)
  ('montelucaste', 'fluconazol',
    InteractionSeverity.moderate,
    'Montelucaste é metabolizado pelo CYP2C9 (e CYP3A4 e CYP2C8); fluconazol é inhibidor dos CYP2C9 e CYP3A4; a inhibición pode aumentar os niveles de montelucaste em 30–50%; como montelucaste tem ampla margem de segurança, o impacto clínico é generalmente leve a moderado',
    'Cefaleia mais frecuente, náuseas, distúrbios do sono, ansiedade, pesadelos (efectos neuropsiquiátricos do montelucaste são dosis-dependentes)',
    'Monitorar efectos neuropsiquiátricos durante fluconazol (ansiedade, pesadelos, comportamento anormal). A interacción raramente requer ajuste de dosis. Usar menor dosis de montelucaste se efectos adversos se tornam problemáticos',
    'Efectos neuropsiquiátricos aumentados — Fluconazol + Montelucaste: monitorar humor e sono',
    EvidenceLevel.probable,
    {RiskType.cns},
    [_kRefGG]),

  // 247 — Teofilina + Enoxacino/Ciprofloxacino (inhibición CYP1A2)
  ('teofilina', 'enoxacino',
    InteractionSeverity.contraindicated,
    'Enoxacino é um dos mais potentes inhibidores conhecidos do CYP1A2; ciprofloxacino é inhibidor moderado do CYP1A2; teofilina é substrato primário do CYP1A2 com janela terapéutica muito estreita (10–20 mcg/mL); enoxacino aumenta os niveles de teofilina em 4–8x; ciprofloxacino aumenta em 1,5–2x',
    'Toxicidade grave por teofilina: convulsiones, arritmias ventriculares, taquicardia grave, náuseas, vômitos, hipotensión; convulsiones de teofilina são refratárias a tratamiento padrão',
    'Enoxacino: contraindicado com teofilina. Ciprofloxacino: monitorar nivel de teofilina e reducir dosis em 30–50% al iniciar ciprofloxacino. Preferir levofloxacino ou azitromicina como alternativas antibióticas (menor inhibición CYP1A2)',
    'CONTRAINDICADO (enoxacino) / Monitorar (ciprofloxacino) — Quinolonas + Teofilina: convulsiones',
    EvidenceLevel.established,
    {RiskType.seizure, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 248 — Aminofilina + Erva de São João (Hypericum)
  ('aminofilina', 'hypericum',
    InteractionSeverity.major,
    'Erva de São João (Hypericum perforatum) contém hiperforina, potente inductor do CYP3A4, CYP2C9 e da P-gp; aminofilina (pró-farmaco da teofilina) é metabolizada principalmente pelo CYP1A2, mas a erva também pode induzir CYP1A2; además, hipericina (outro componente) pode ter efecto direto na teofilina; a inducción enzimática reduz os niveles de teofilina comprometendo o tratamiento de asma e DPOC',
    'Concentraciones subterapéuticas de teofilina com perda do controle de asma ou DPOC; crises de broncoespasmo por eficácia reducida do broncodilatador',
    'Orientar sobre uso de fitoterápicos. Suspender erva de São João al iniciar aminofilina. Monitorar nivel de teofilina al iniciar e al suspender o fitoterápico. A inducción persiste por 2 semanas después de suspensión da erva',
    'Falha terapéutica de teofilina — Erva de São João induz CYP: monitorar nivel',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 249 — Ivacaftor (CFTR modulador) + Rifampicina
  ('ivacaftor', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Ivacaftor (modulador CFTR para fibrose cística) é extensamente metabolizado pelo CYP3A4; rifampicina é potente inductor do CYP3A4; a coadministração reduz a AUC do ivacaftor em 89% e de seu metabólito ativo M1 em 75%; com concentraciones tão drásticamente reducidas, não há benefício terapéutico e o custo do medicamento (muito elevado) é desperdiçado',
    'Perda completa do benefício terapéutico do ivacaftor na fibrose cística; riesgo de deterioração da função pulmonar e piora da qualidade vida',
    'Contraindicado. Na impossibilidade evitar a rifampicina, usar rifabutina (inductor menos potente, reduz ivacaftor ~36% — ainda problemático mas manejável com ajuste). Consultar equipe de fibrose cística antes de qualquer mudança. Ivacaftor é extremamente caro: garantir que não seja desperdiçado',
    'CONTRAINDICADO — Rifampicina reduz ivacaftor 89%: perda total da eficácia terapéutica',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 250 — Elexacaftor/Tezacaftor/Ivacaftor + Itraconazol
  ('elexacaftor', 'itraconazol',
    InteractionSeverity.major,
    'A triple terapia CFTR (elexacaftor+tezacaftor+ivacaftor, Trikafta) contém substrato do CYP3A4; itraconazol é potente inhibidor do CYP3A4; a inhibición aumenta significativamente a exposición aos componentes da triple therapy; a bula recomenda reducción de la dosis para administração em dias alternados com inhibidores potentes de CYP3A4',
    'Toxicidad por supraexposición: dor de cabeça, fadiga, tontura, transaminases elevadas, exacerbações respiratórias; hepatotoxicidad por acumulación de elexacaftor',
    'Reducir la dosis de Trikafta para um comprimido em dias alternados quando em uso de itraconazol ou outros inhibidores potentes de CYP3A4. Monitorar función hepática (AST/ALT) mensalmente. Usar antifúngicos alternativos cuando sea posible',
    'Toxicidad de Trikafta — Itraconazol exige reducción para uso em dias alternados',
    EvidenceLevel.established,
    {RiskType.hepatotoxicity, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 10 — Oncologia, Inmunosupresores, Reumatologia,
  // Geriatria, Miscelânea final (251–280)
  // ═══════════════════════════════════════════════════════════════

  // 251 — Imatinibe + Rifampicina (CYP3A4 inducción)
  ('imatinibe', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Imatinibe (inhibidor de BCR-ABL/c-KIT para LMC e GIST) é extensamente metabolizado pelo CYP3A4; rifampicina é o mais potente inductor do CYP3A4 disponible clinicamente; a coadministração reduz a AUC do imatinibe em 70–74%; com concentraciones tão reducidas, não há resposta citogenética ou molecular suficiente para controle da leucemia',
    'Falha citogenética e molecular com progresión de LMC e GIST; riesgo de crise blástica por exposición subterapéutica ao imatinibe; impacto clínico documentado em estudos retrospectivos',
    'Contraindicado. Trocar rifampicina por rifabutina (reduz imatinibe ~36%, ainda problemático) ou explorar alternativas não inductoras. Se rifampicina for indispensable (TB + LMC), discutir com hematologista: dobrar dosis del imatinibe pode não ser suficiente e pode ser tóxico. Dasatinibe ou nilotinibe têm menor interacción com CYP3A4',
    'CONTRAINDICADO — Rifampicina reduz imatinibe 74%: progresión da leucemia',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 252 — Erlotinibe + IBP (absorción pH-dependente)
  ('erlotinibe', 'omeprazol',
    InteractionSeverity.major,
    'Erlotinibe (EGFR-TKI) tem solubilidade altamente dependente do pH: solubilidade cai 100x quando pH sobe de 2 para 7; IBP aumentam o pH gástrico para 4–6, reduzindo drásticamente a absorción do erlotinibe; estudos demonstraram reducción de 46% na AUC com omeprazol; antiácidos reduzem AUC em 33% se tomados separados por 2 horas',
    'Falha terapéutica do erlotinibe com progresión do câncer de pulmão EGFR-mutado; riesgo de resistência secundária por exposición subterapéutica',
    'Evitar IBP com erlotinibe sempre que posible. Usar antiácido (carbonato de cálcio, hidróxido de alumínio) tomado 2 horas después de erlotinibe se protección gástrica necesaria. Se IBP for indispensable, investigar alternativa (gefitinibe tem menor interacción; osimertinibe não tem interacción significativa com IBP)',
    'Falha terapéutica oncológica — IBP reduz erlotinibe 46%: trocar para osimertinibe si es posible',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 253 — Ponatinibe + Claritromicina (QT + CYP3A4)
  ('ponatinibe', 'claritromicina',
    InteractionSeverity.major,
    'Ponatinibe (inhibidor de BCR-ABL T315I para LMC resistente) prolonga o QT e é metabolizado pelo CYP3A4; claritromicina inibe o CYP3A4 e também prolonga o QT; dupla interacción: aumento das concentraciones de ponatinibe e efecto aditivo no QT',
    'QTc > 500 ms, torsades de pointes, morte súbita; toxicidads de ponatinibe amplificadas (trombosis arterial, pancreatite, hepatotoxicidad)',
    'Evitar claritromicina com ponatinibe. Usar azitromicina como alternativa (menor inhibición CYP3A4 e menor efecto no QT). Monitorar ECG semanalmente se combinación necesaria',
    'QT grave + toxicidad oncológica — Claritromicina + Ponatinibe: azitromicina como alternativa',
    EvidenceLevel.probable,
    {RiskType.qtProlongation, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 254 — Capecitabina + Varfarina (CYP2C9 inhibición)
  ('capecitabina', 'varfarina',
    InteractionSeverity.major,
    'Capecitabina é convertida a 5-fluorouracil (5-FU) no tumor; o 5-FU inibe o CYP2C9, principal enzima de metabolismo de la S-varfarina (mais potente); o INR pode aumentar dramaticamente al iniciar ou después de cada ciclo de capecitabina; a interacción é frecuentemente subestimada por oncologistas e pode causar sangrados fatais',
    'Sangrado grave: hemorragia intracraniana, gastrointestinal maciça; INR pode dobrar ou triplicar dentro de 7–14 dias do inicio da capecitabina; mortalidade documentada',
    'Monitorar INR a cada 3–5 dias no primeiro ciclo de capecitabina e depois semanalmente durante os ciclos subsequentes. Reducir dosis de varfarina em 30–50% preventivamente. Considerar DOAC como alternativa à varfarina en pacientes com câncer (menor necessidade monitoramento)',
    'INR dobra/triplica — Capecitabina inibe CYP2C9: monitorar INR a cada 3 dias no ciclo 1',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 255 — Tamoxifeno + Anastrozol (interacción já descrita, variação)
  ('tamoxifeno', 'fluoxetina',
    InteractionSeverity.major,
    'Fluoxetina é inhibidor potente do CYP2D6; tamoxifeno requer ativação pelo CYP2D6 ao endoxifeno (metabólito ativo); a inhibición pelo CYP2D6 pela fluoxetina reduz os niveles de endoxifeno em 50–75%, comprometendo a eficácia antiestrogênica no câncer de mama; paroxetina tem efecto ainda maior (71–75% de reducción)',
    'Aumento del riesgo de recurrencia do câncer de mama HR+; fracaso terapéutico do tamoxifeno na adjuvância e metástase',
    'Sustituir fluoxetina e paroxetina por antidepresivos com menor inhibición de CYP2D6: escitalopram, venlafaxina, mirtazapina, desvenlafaxina. Esta interacción pode ter impacto na sobrevida global em mulheres com câncer de mama',
    'Recurrencia de câncer de mama — Fluoxetina inibe CYP2D6: trocar por escitalopram',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG, _kRefMdx]),

  // 256 — Tacrolimus + Sirolimus (toxicidad renal sinérgica)
  ('tacrolimus', 'sirolimus',
    InteractionSeverity.major,
    'Tacrolimus e sirolimus são ambos inhibidores de calcineurina/mTOR com nefrotoxicidad independente; tacrolimus causa nefrotoxicidad por vasoconstrição aferente e lesão tubular; sirolimus potencializa a nefrotoxicidad do tacrolimus possivelmente por inhibición da regeneração tubular e amplificação da isquemia; estudos em transplante renal mostraram maior incidência de rechazo agudo e DGF com a combinación',
    'Nefrotoxicidad grave: insuficiencia renal aguda, DGF (delayed graft function), pérdida del injerto a longo prazo; hiperlipidemia e mielosupresión adicionais do sirolimus',
    'Monitorar creatinina, nivel de tacrolimus (C0) e sirolimus (C0) rigurosamente. Considerar sustitución: micofenolato de mofetila tem menor nefrotoxicidad que sirolimus como adjuvante ao tacrolimus em transplante renal. Manter sirolimusC0 < 8 ng/mL e tacrolimus < 8 ng/mL quando em combinación',
    'Nefrotoxicidad sinérgica — Tacrolimus + Sirolimus: monitorar C0 de ambos e creatinina',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.plasmaLevel},
    [_kRefGG, _kRefUT, _kRefFDA]),

  // 257 — Micofenolato + Colestiramina (absorción)
  ('micofenolato', 'colestiramina',
    InteractionSeverity.major,
    'Colestiramina (resina quelante de ácidos biliares) liga-se ao micofenolato de mofetila (MMF) e ao seu metabólito ativo ácido micofenólico (MPA) no trato gastrointestinal, interrompendo a circulação êntero-hepática do MPA; esta circulação é responsável por ~10–40% da exposición total ao MPA; a quelação pode reduzir drásticamente os niveles de MPA',
    'Concentraciones subterapéuticas de MPA com riesgo de rechazo aguda en pacientes trasplantados; reversão do efecto inmunosupresor',
    'Contraindicado de rotina. Se colestiramina for necesaria (hipercolesterolemia em trasplantado), administrar pelo menos 4 horas separadas do MMF. Dosar MPA (C0 e C2) después de inicio da colestiramina. Colestipol tem menor interacción que colestiramina',
    'Rejeição de transplante — Colestiramina inibe absorción de micofenolato: separar 4 horas',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 258 — Azatioprina + Alopurinol (mielosupresión fatal)
  ('azatioprina', 'alopurinol',
    InteractionSeverity.contraindicated,
    'Azatioprina é convertida a 6-mercaptopurina (6-MP), que é metabolizada pela xantina oxidase (XO) a metabólitos inativos; alopurinol inibe a XO de forma competitiva e irreversible; a inhibición bloqueia a inativação da 6-MP, cujos metabólitos ativos (tioguanina) acumulam na medula óssea causando aplasia; esta interacción causou mortes e é amplamente documentada nas bulas',
    'Aplasia medular grave com pancitopenia profunda: leucopenia < 1.000/mm³, infecções oportunistas fatais, sepse; anemia e trombocitopenia graves; mortalidade até 50% se não reconhecida precocemente',
    'Contraindicado. Se ambos forem necesarios (gota em paciente imunossuprimido com artrite/DII): reduzir azatioprina para 25% da dosis e monitorar hemograma semanalmente. Preferir febuxostate NÃO — também contraindicado. Usar uricosúrico (probenecida) ou modificar dieta. Se azatioprina for indispensable, suspender alopurinol',
    'CONTRAINDICADO — Alopurinol + Azatioprina: aplasia medular com óbito (bula vermelho)',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefFDA, _kRefGG, _kRefKatz, _kRefUT]),

  // 259 — Ciclofosfamida + Alopurinol (mielosupresión)
  ('ciclofosfamida', 'alopurinol',
    InteractionSeverity.moderate,
    'Ciclofosfamida é metabolizada pelo CYP2B6 a metabólitos ativos alquilantes; alopurinol pode inibir o CYP2B6 reduzindo a ativação da ciclofosfamida mas paradoxalmente estudos mostram que o alopurinol aumenta a mielosupresión da ciclofosfamida por mecanismo não completamente elucidado; o alopurinol é usado preventivamente para hiperuricemia em quimioterapia',
    'Mielossupresión mais pronunciada com neutropenia e trombocitopenia; infecções bacterianas e fúngicas graves; necessidade ajuste de dosis de quimioterapia',
    'Usar com cautela. O alopurinol é frecuentemente necesario para prevenir síndrome de lise tumoral em quimioterapia; monitorar hemograma mais frecuentemente. Considerar rasburicase como alternativa para síndrome de lise tumoral (não tem esta interacción)',
    'Mielossupresión aumentada — Alopurinol + Ciclofosfamida: monitorar hemograma intensivo',
    EvidenceLevel.probable,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefMdx]),

  // 260 — Metotrexato + Doxiciclina
  ('metotrexato', 'doxiciclina',
    InteractionSeverity.moderate,
    'Tetraciclinas (doxiciclina, tetraciclina) competem com o metotrexato pelos transportadores OAT1/OAT3 e OATP para excreción renal tubular; a competição pode aumentar os niveles plasmáticos de metotrexato em 30–50%; o metotrexato também tem circulação êntero-hepática que pode ser afetada pela alteração da flora intestinal pela doxiciclina',
    'Toxicidad de metotrexato: mucosita oral grave, pancitopenia, hepatotoxicidad; insuficiencia renal aguda em dosis altas (oncológicas)',
    'Monitorar leucometria e creatinina al iniciar antibiótico em paciente em metotrexato. Nas dosiss reumatológicas baixas (< 25 mg/semana), o riesgo é moderado mas real. Em dosiss oncológicas altas: dosar nivel de metotrexato. Preferir azitromicina ou cefalosporina como alternativa antibiótica',
    'Toxicidad de metotrexato — Doxiciclina compete no transporte renal: monitorar hemograma',
    EvidenceLevel.probable,
    {RiskType.myelosuppression, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

  // 261 — Tocilizumabe + Sinvastatina (normalização de CRP e metabolismo)
  ('tocilizumabe', 'sinvastatina',
    InteractionSeverity.moderate,
    'Inflamação sistêmica suprime o CYP3A4 e CYP2C9 via interleucinas (especialmente IL-6); al iniciar tocilizumabe (anti-IL-6R), a IL-6 sistêmica cai drásticamente, restaurando a atividade normal do CYP3A4; a sinvastatina (substrato CYP3A4) que era metabolizada mais lentamente durante inflamação ativa agora é metabolizada mais rapidamente, resultando em queda dos seus niveles; efecto paradoxal',
    'Queda inesperada dos niveles de sinvastatina com posible reducción de la eficácia na protección cardiovascular durante o inicio do tratamiento; o efecto é oposto ao esperado em terapias com anti-inflamatórios',
    'Monitorar LDL-C 4–8 semanas después de inicio do tocilizumabe. En pacientes com alto riesgo cardiovascular, pode ser necesario aumentar a dosis de sinvastatina ou trocar para outra estatina. Este efecto é temporário — a nova steady-state estabiliza em 4–8 semanas',
    'Queda paradoxal de estatina — Tocilizumabe restaura CYP3A4: monitorar LDL-C ao iniciar',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefFDA]),

  // 262 — Baricitinibe + Rifampicina (JAK inhibidor)
  ('baricitinibe', 'rifampicina',
    InteractionSeverity.major,
    'Baricitinibe (JAK1/2 inhibidor para artrite reumatoide) é metabolizado principalmente pelo CYP3A4; rifampicina induz o CYP3A4 reduzindo a AUC do baricitinibe em 60%; com concentraciones tão reducidas, a inhibición de JAK1/2 é insuficiente para controle da inflamação articular',
    'Falha terapéutica com progresión da artrite reumatoide; sinovite recorrente, dano articular; necessidade corticoides de resgate',
    'Evitar rifampicina com baricitinibe. Se tratamiento para TB for necesario em paciente com AR em baricitinibe, suspender baricitinibe e usar biológico alternativo (adalimumabe) que tem menor interacción com rifampicina. Retomar baricitinibe después de o fin da TB',
    'Falha terapéutica de baricitinibe — Rifampicina reduz 60%: suspender durante TB e usar biológico',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 263 — Upadacitinibe + Rifampicina (já coberto mas confirmação)
  ('upadacitinibe', 'carbamazepina',
    InteractionSeverity.major,
    'Upadacitinibe (JAK1 inhibidor seletivo) é metabolizado pelo CYP3A4; carbamazepina é inductor moderado a potente do CYP3A4; a inducción pode reduzir os niveles de upadacitinibe em 30–45%, comprometendo a eficácia terapéutica',
    'Controle insuficiente da AR ou espondilite anquilosante com dor articular persistente, falha de remissão; necessidade dosis de resgate',
    'Sustituir carbamazepina por antiepiléptico sem inducción CYP3A4 (levetiracetam, lamotrigina) sempre que posible. Se carbamazepina for indispensable, monitorar atividade da enfermedad (DAS28, CRP). Aumento de dosis de upadacitinibe pode ser necesario e está dentro das possibilidades da bula',
    'Falha terapéutica — Carbamazepina reduz upadacitinibe: trocar antiepiléptico',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 264 — Certolizumabe + Vacinas vivas (contraindicação)
  ('certolizumabe', 'vacina_viva',
    InteractionSeverity.contraindicated,
    'Certolizumabe pegol (anti-TNF PEGilado) neutraliza o TNF-alfa, prejudicando a imunidade celular mediada por Th1 necesaria para controle de infecções; vacinas vivas contêm patógenos atenuados que requerem a imunidade Th1 intacta para contenção; em imunossupresión anti-TNF, esses patógenos podem causar enfermedad grave disseminada',
    'Enfermedad disseminada pela cepa vacinal: BCGite, varicela grave, febre amarela visceral, sarampo fatal; óbito documentado en pacientes em anti-TNF vacinados com vacinas vivas',
    'Contraindicado. Completar todas as vacinas vivas pelo menos 4 semanas antes de iniciar certolizumabe. Aguardar pelo menos 3 meses después de a última dosis antes de administrar vacinas vivas. Vacinas inativadas são seguras e recomendadas',
    'CONTRAINDICADO — Certolizumabe + Vacinas vivas: enfermedad vacinal disseminada e óbito',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 265 — Secuquinumabe (anti-IL17) + Vacinas vivas
  ('secuquinumabe', 'vacina_viva',
    InteractionSeverity.contraindicated,
    'Secuquinumabe (anti-IL-17A para psoríase, espondiloartrite) suprime a imunidade Th17, essencial para defesa contra fungos (Candida) e algumas bactérias extracelulares; vacinas vivas requerem imunidade celular preservada; o riesgo específico de Candida disseminada é aumentado com anti-IL17',
    'Candidemia disseminada después de vacinação com vacinas vivas em imunocomprometidos; outras infecções graves por patógenos da cepa vacinal',
    'Contraindicado. Vacinar com vacinas vivas pelo menos 4 semanas antes de iniciar secuquinumabe. Aguardar 3–6 meses después de a última dosis antes de vacinas vivas. Riesgo adicional de candidíase mucocutânea durante o tratamiento (não relacionado às vacinas)',
    'CONTRAINDICADO — Secuquinumabe + vacinas vivas: supresión Th17 e infecção fúngica',
    EvidenceLevel.established,
    {RiskType.infection},
    [_kRefFDA, _kRefGG]),

  // 266 — Prednisolona + Diuréticos (hipopotasemia + hiperglucemia)
  ('prednisolona', 'clortalidona',
    InteractionSeverity.moderate,
    'Corticoides causam retenção de sódio e perda de potássio (efecto mineralocorticoide), hiperglucemia (efecto diabetogênico) e dislipidemia; diuréticos tiazídicos (clortalidona) também causam hipopotasemia e hiperglucemia (reduzem a secreção de insulina); os dois mecanismos são aditivos na hipopotasemia e hiperglucemia',
    'Hipopotasemia grave (K+ < 3 mEq/L): arritmias, fraqueza muscular, paro cardíaco; hiperglucemia (DM esteroidal) requerendo inicio de hipoglucemiante',
    'Monitorar K+ e glucemia semanalmente ao inicio da combinación. Suplementar K+ se K+ < 3,5 mEq/L. Monitorar HbA1c a cada 3 meses em uso crônico. Reducir dosis de tiazídico ou sustituir por poupador de potássio (espironolactona) se hipopotasemia persistente',
    'Hipopotasemia + hiperglucemia aditivas — Corticoide + Tiazídico: monitorar K+ e glucemia',
    EvidenceLevel.established,
    {RiskType.hypokalemia, RiskType.hypoglycemia},
    [_kRefGG, _kRefKatz]),

  // 267 — Colchicina + Inhibidores de P-gp (ciclosporina)
  ('colchicina', 'ciclosporina',
    InteractionSeverity.major,
    'Ciclosporina inibe tanto o CYP3A4 quanto a P-glicoproteína; colchicina é substrato de ambos com janela terapéutica estreita; a inhibición dupla pode aumentar os niveles de colchicina em 2,5–4x; colchicina tem toxicidad grave dosis-dependente; esta combinación é a causa mais documentada de colchicinemia tóxica en pacientes trasplantados com gota',
    'Toxicidade grave de colchicina: miopatía com rabdomiólisis, neuropatia periférica, pancitopenia, disfunção de múltiplos órgãos; mortalidade documentada en pacientes trasplantados com gota tratados com colchicina em dosis habitual',
    'Dosis máxima de colchicina com ciclosporina: 0,5 mg/dia (metade da dosis usual mínima para profilaxia). Para gota aguda: 0,6 mg dosis única (não repetir por pelo menos 3 dias). Monitorar CK, hemograma e función renal. En pacientes trasplantados com gota, considerar corticoide oral de curta duración (5 dias) como alternativa mais segura',
    'Toxicidade fatal de colchicina — Ciclosporina inibe CYP3A4 + P-gp: 0,5 mg/dia máximo',
    EvidenceLevel.established,
    {RiskType.myopathy, RiskType.myelosuppression},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 268 — Piroxicam + Metotrexato (toxicidad renal + hematológica)
  ('piroxicam', 'metotrexato',
    InteractionSeverity.major,
    'AINEs (especialmente naproxeno, piroxicam, indometacina) reduzem o aclaramiento renal do metotrexato por inhibición das prostaglandinas renais e competição com o transporte tubular (OAT); o metotrexato acumula nos compartimentos intra e extracelulares causando toxicidad grave; a combinación é aceita em dosiss reumatológicas (< 25 mg/semana) com cautela mas é de alto riesgo em dosiss oncológicas',
    'Mucosita oral ulcerativa grave, neutropenia profunda, insuficiencia renal aguda, hepatotoxicidad; óbito documentado em dosiss oncológicas',
    'Evitar AINEs nas 24–48 horas antes e después de as dosis de metotrexato (especialmente em dosiss oncológicas). Em dosiss reumatológicas (< 25 mg/semana), monitorar creatinina e hemograma mensalmente. Paracetamol é alternativa analgésica segura. Preferir celecoxibe (menor efecto na prostaglandina renal) se AINE for necesario',
    'Toxicidade fatal de metotrexato — AINEs reduzem aclaramiento renal: evitar nas 48h do MTX',
    EvidenceLevel.established,
    {RiskType.nephrotoxicity, RiskType.myelosuppression},
    [_kRefGG, _kRefKatz, _kRefMdx]),

  // 269 — Zoledrônico + Aminoglicosídeos (hipocalcemia profunda)
  ('zoledronico', 'gentamicina',
    InteractionSeverity.major,
    'Bisfosfonatos IV (zoledronato, pamidronato) inibem a reabsorción óssea de osteoclastos, reduzindo o cálcio sérico; aminoglicosídeos podem potencializar a hipocalcemia por mecanismo incerto (posible efecto direto na reabsorción tubular de cálcio e magnésio); además, aminoglicosídeos causam hipomagnesemia, que impede a correção da hipocalcemia (o paratormônio requer magnésio para agir)',
    'Hipocalcemia grave sintomática: tetania, convulsiones, broncoespasmo, prolongación del QT; impossibilidade correção da hipocalcemia enquanto hipomagnesemia persistir',
    'Monitorar cálcio, magnésio e fósforo diariamente durante a combinación. Repor magnésio IV antes de tentar corrigir a hipocalcemia. Suplementar cálcio IV se cálcio total < 7,5 mg/dL sintomático. Considerar adiar a infusão de zoledronato se aminoglicosídeo for indispensable',
    'Hipocalcemia profunda + hipomagnesemia — Zoledronato + Aminoglicosídeo: repor Mg++ primeiro',
    EvidenceLevel.probable,
    {RiskType.electrolyte, RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

  // 270 — Denosumabe + Corticoides (hipocalcemia + osteofragilidade)
  ('denosumabe', 'prednisona',
    InteractionSeverity.moderate,
    'Denosumabe (anti-RANK-L) inibe a diferenciação de osteoclastos, reduzindo a reabsorción óssea e liberação de cálcio; corticoides reduzem a absorción intestinal de cálcio (anti-vitamina D), diminuem a reabsorción renal e aumentam a reabsorción óssea; embora os mecanismos sejam opostos na reabsorción óssea, o cálcio sérico pode cair com a combinación; a protección óssea do denosumabe é necesaria justamente em usuários crônicos de corticoide',
    'Hipocalcemia moderada a grave, especialmente en pacientes com hipoparatireoidismo subclínico ou insuficiência de vitamina D; maior riesgo nas primeiras semanas después de a injeção de denosumabe',
    'Suplementar cálcio (1.500 mg/dia) e vitamina D3 (800 UI/dia ou mais) antes e durante denosumabe + corticoide. Monitorar calcemia e vitamina D 25-OH no inicio e a cada 6 meses. Considerar calcitriol en pacientes com hipoparatireoidismo',
    'Hipocalcemia — Denosumabe + Corticoide: suplementar Ca++ e vitamina D obligatoriamente',
    EvidenceLevel.established,
    {RiskType.electrolyte},
    [_kRefFDA, _kRefGG]),

  // 271 — Rosiglitazona + Nitrato (hipotensión)
  ('rosiglitazona', 'mononitrato',
    InteractionSeverity.moderate,
    'Rosiglitazona (glitazona/TZD) causa retenção de líquidos e leve expansão de volume, sin embargo também tem efecto vasodilatador por reducción de la resistência vascular periférica; nitratos causam vasodilatação venosa e arterial; a combinación pode causar hipotensión excessiva por vasodilatação sinérgica, especialmente en ancianos ou pacientes já com ICC',
    'Hipotensión ortostática, tontura, síncope; edema pulmonar ou periférico exacerbado pela retenção hídrica da rosiglitazona em ICC',
    'Monitorar PA (especialmente ortostática) ao usar combinación. Rosiglitazona é contraindicada em ICC classes III e IV (retenção hídrica). Preferir iSGLT2 para protección cardiovascular en diabéticos com DAC (sem efecto de retenção hídrica)',
    'Hipotensión e edema — Rosiglitazona + Nitratos: monitorar PA, preferir iSGLT2 em DAC',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    [_kRefGG]),

  // 272 — Pioglitazona + Gemfibrozil (CYP2C8 inhibición)
  ('pioglitazona', 'gemfibrozil',
    InteractionSeverity.major,
    'Pioglitazona é metabolizada pelo CYP2C8; gemfibrozil é um dos mais potentes inhibidores do CYP2C8 disponibles; a inhibición aumenta a AUC da pioglitazona em 3–4x; com concentraciones tão elevadas, todos os efectos adversos de pioglitazona são amplificados: retenção hídrica, edema, riesgo de ICC e bexiga (después de uso crônico)',
    'Edema grave com insuficiencia cardíaca descompensada; hipoglucemia mais pronunciada; riesgo aumentado de câncer de bexiga com exposición cumulativa elevada',
    'Contraindicação relativa. Preferir fenofibrato (não inibe CYP2C8) para hipertrigliceridemia en pacientes em pioglitazona. Se gemfibrozil for necesario, monitorar PA, peso, função cardíaca e glucemia. Considerar iSGLT2 como alternativa à pioglitazona',
    'Toxicidad de pioglitazona 4x maior — Gemfibrozil inibe CYP2C8: usar fenofibrato',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG]),

  // 273 — Insulina detemir + Álcool (hipoglucemia noturna)
  ('insulina_detemir', 'alcool',
    InteractionSeverity.major,
    'O álcool inibe a gliconeogênese hepática, reduzindo a produção endógena de glicose; a insulina detemir (basal) mantém ação contínua por 16–24 horas; a combinación causa hipoglucemia prolongada noturna sem que o fígado possa compensar; a hipoglucemia alcoólica é especialmente perigosa pois o paciente pode não reconhê-la (similitude sintomas com embriaguez) e não ter acompanhante',
    'Hipoglucemia grave noturna: tontura, sudorese, convulsiones, coma hipoglicêmico; o álcool pode mascarar os sinais de hipoglucemia e impedir o reconhecimento e tratamiento oportuno',
    'Orientar fortemente sobre o riesgo de hipoglucemia noturna com álcool. Se o paciente beber, deve consumir carboidratos antes de dormir e monitorar glucemia capilar. Limitar consumo alcoólico. Em episódio de hipoglucemia alcoólica: glicose IV (não glucagon oral, que depende da gliconeogênese hepática)',
    'Hipoglucemia noturna grave — Álcool + Insulina basal: consumir CHO antes de dormir se beber',
    EvidenceLevel.established,
    {RiskType.hypoglycemia},
    [_kRefGG, _kRefKatz]),

  // 274 — Sulfoniluréia + Fluconazol (hipoglucemia por inhibición CYP2C9)
  ('glibenclamida', 'fluconazol',
    InteractionSeverity.major,
    'Sulfoniluréias de segunda geração (glibenclamida, glipizida) são metabolizadas pelo CYP2C9; fluconazol é potente inhibidor do CYP2C9; a inhibición aumenta os niveles plasmáticos das sulfoniluréias em 50–100%, prolongando e potencializando a ação hipoglucemiante; o riesgo é especialmente alto en ancianos e en pacientes com IRC',
    'Hipoglucemia grave y prolongada (> 24 horas pois a glibenclamida é de longa duración); convulsiones hipoglicêmicas, coma, dano neurológico irreversible; idosos têm maior riesgo por menor resposta adrenérgica à hipoglucemia',
    'Monitorar glucemia capilar a cada 4–6 horas durante fluconazol em usuário de sulfoniluréia. Reducir dosis de sulfoniluréia em 25–50%. Hospitalizar se glucemia < 60 mg/dL e difícil controle. Preferir fluconazol em dosis única (150 mg) para candidíase vaginal (menor impacto)',
    'Hipoglucemia prolongada grave — Fluconazol dobra sulfoniluréia: monitorar glucemia de 4/4h',
    EvidenceLevel.established,
    {RiskType.hypoglycemia, RiskType.plasmaLevel},
    [_kRefGG, _kRefKatz, _kRefUT]),

  // 275 — Acarbose + Digoxina (absorción reducida)
  ('acarbose', 'digoxina',
    InteractionSeverity.moderate,
    'Acarbose (inhibidor de alfa-glicosidase) retarda a digestão e absorción de carboidratos no intestino delgado; pode alterar a motilidade intestinal e a flora microbiana; estudos mostraram reducción de 20–35% na AUC da digoxina quando administrada concomitantemente com acarbose por posible quelação ou alteração da absorción intestinal',
    'Reducción dos niveles séricos de digoxina com fracaso en el control da frecuencia em FA ou reducción de la contratilidade em ICC',
    'Monitorar digoxinemia al iniciar acarbose. Pode ser necesario aumentar a dosis de digoxina em 15–25%. Administrar digoxina 30 min antes da acarbose (antes das refeições) para minimizar a interacción',
    'Absorción reducida de digoxina — Acarbose: monitorar digoxinemia e tomar digoxina 30 min antes',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy, RiskType.plasmaLevel},
    [_kRefGG, _kRefMdx]),

  // 276 — Canagliflozina + Diuréticos + Betabloqueadores (hipoglucemia mascarada)
  ('canagliflozina', 'propranolol',
    InteractionSeverity.moderate,
    'Propranolol (betabloqueador não seletivo) mascara os sintomas adrenérgicos de hipoglucemia (taquicardia, tremor, diaforese) por bloqueio de receptores beta-adrenérgicos; a sudorese é preservada (mediada por colinérgicos); em combinación com iSGLT2 que podem raramente causar hipoglucemia euglicêmica, a ausência de sintomas pode retardar o diagnóstico e tratamiento',
    'Hipoglucemia não reconhecida com coma hipoglicêmico; episódios de hipoglucemia assintomáticos especialmente durante exercício ou jejum',
    'Monitorar glucemia com maior frecuencia em usuários de propranolol. Educar sobre sintomas não adrenérgicos de hipoglucemia (palor, sudorese, confusão). Preferir betabloqueador cardioselective (bisoprolol, metoprolol) que preserva maior resposta adrenérgica. iSGLT2 raramente causam hipoglucemia isoladamente, mas o riesgo aumenta com insulina ou sulfoniluréia associada',
    'Hipoglucemia mascarada — Betabloqueador não seletivo + iSGLT2: monitorar glucemia',
    EvidenceLevel.probable,
    {RiskType.hypoglycemia},
    [_kRefGG]),

  // 277 — Ritonavir + Morfina (glucuronidação)
  ('ritonavir', 'morfina',
    InteractionSeverity.moderate,
    'Ritonavir induz a UGT2B7, principal enzima de glucuronidação da morfina; a morfina é inativada principalmente pela glucuronidação a morfina-6-glucuronídeo (ativo) e morfina-3-glucuronídeo (inativo); a inducción de la UGT2B7 pode aumentar o metabolismo de la morfina, reduzindo seus niveles plasmáticos em 20–55% e reduzindo a analgesia; o metabólito ativo M6G também é afetado',
    'Analgesia insuficiente, dolor no controlado, abstinência opioide em dependentes em TARV; necessidade dosiss maiores de morfina',
    'Monitorar nivel de dor en pacientes em morfina que iniciam TARV com ritonavir. Pode ser necesario aumentar a dosis de morfina em 20–40%. Considerar alternativas analgésicas (hidromorfona — menor interacción; oxicodona — metabolizada pelo CYP3A4 inibido por ritonavir, portanto niveles aumentam)',
    'Analgesia reducida — Ritonavir induz glucuronidação da morfina: aumentar dosis em 20–40%',
    EvidenceLevel.probable,
    {RiskType.reducedEfficacy},
    [_kRefGG, _kRefUT]),

  // 278 — Linezolida + Pseudoefedrina/Efedrina (crisis hipertensiva)
  ('linezolida', 'pseudoefedrina',
    InteractionSeverity.major,
    'Linezolida inibe a MAO-A; pseudoefedrina (simpatomimético de ação indireta) libera noradrenalina armazenada nas vesículas neurais; com a MAO-A inibida, a noradrenalina liberada não é degradada, causando acumulación e tempestade adrenérgica; mecanismo idêntico à crise de queijo com IMAOs tradicionais',
    'Crisis hipertensiva grave (PA > 180/120 mmHg), cefaleia em trovão, AVC hemorrágico, infarto do miocárdio; taquicardia grave',
    'Contraindicado. Descongestionantes nasais (oximetazolina, xilometazolina tópicos) podem ser alternativas mais seguras pois têm baixa absorción sistêmica. Evitar todos os simpaticomiméticos orais (efedrina, fenilefrina oral) durante linezolida. Restrição dietética de tiramina também se aplica',
    'Crisis hipertensiva — Linezolida (IMAO) + Pseudoefedrina: evitar todos os simpaticomiméticos',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 279 — Tranilcipromina (IMAO irreversible) + Triptanos
  ('tranilcipromina', 'sumatriptano',
    InteractionSeverity.contraindicated,
    'Tranilcipromina é IMAO irreversible (inhibidor de MAO-A e MAO-B); sumatriptano e outros triptanos são agonistas de receptores 5-HT1B/D; o metabolismo dos triptanos requer MAO-A; com a MAO-A inibida, os niveles de triptanos aumentam drásticamente (2–3x) e o riesgo de síndrome serotoninérgica é muito alto; además, vasoconstrição coronariana pelo triptano associada à hipertensão do IMAO pode causar IAM',
    'Síndrome serotoninérgica grave, crisis hipertensiva, vasoespasmo coronariano com IAM; mortalidade documentada',
    'Contraindicado. Aguardar pelo menos 14 dias después de suspensión de tranilcipromina antes de usar qualquer triptano (período necesario para síntese de nova MAO-A). Em enxaqueca durante tratamiento com IMAO: usar AINEs, paracetamol, metoclopramida (sem ISRS) para as crises',
    'CONTRAINDICADO — IMAO + Triptano: aguardar 14 dias después de IMAO antes de usar triptano',
    EvidenceLevel.established,
    {RiskType.serotonin, RiskType.cardiovascular},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 280 — Fenelzina (IMAO) + Meperidina (serotonina letal)
  ('fenelzina', 'meperidina',
    InteractionSeverity.contraindicated,
    'Fenelzina é IMAO irreversible não seletivo (MAO-A e MAO-B); meperidina (petidina) inibe a recaptação de serotonina de forma mais potente que outros opioides; com a MAO-A inibida, a serotonina não é degradada e o bloqueio adicional de recaptação pela meperidina causa acumulación sináptico maciço de serotonina; síndrome serotoninérgica severa com alta mortalidade',
    'Síndrome serotoninérgica potencialmente fatal: tremor, hiperreflexia, hipertermia grave (> 42°C), colapso cardiovascular, morte; casos fatais bem documentados na literatura',
    'Contraindicado absolutamente. Aguardar 14 dias después de suspensión de IMAO antes de usar meperidina. Usar morfina, hidromorfona ou fentanil como analgésicos alternativos (menor atividade serotoninérgica). Em cirurgia de emergência, informar anestesiologista sobre o uso de IMAO',
    'CONTRAINDICADO — IMAO + Meperidina: síndrome serotoninérgica fatal documentada',
    EvidenceLevel.established,
    {RiskType.serotonin},
    [_kRefFDA, _kRefGG, _kRefUT, _kRefMdx]),


  // ═══════════════════════════════════════════════════════════════
  // BLOCK 11 — Interacciones finais clínicas de alta relevância (281–300)
  // ═══════════════════════════════════════════════════════════════

  // 281 — Fentanil + Midazolam + Propofol (tríade anestésica)
  ('fentanil', 'midazolam',
    InteractionSeverity.major,
    'A combinación de fentanil (opioide), midazolam (BZD) e propofol (anestésico geral) cria depresión respiratoria sinérgica extrema via três mecanismos diferentes: fentanil deprime o centro respiratório via receptores mu; midazolam potencializa GABA-A reduzindo o drive respiratório; propofol suprime o SNC globalmente; a combinación é essencial em anestesia mas com riesgo de apnea súbita em sedações não controladas',
    'Apnea, hipóxia grave, colapso cardiovascular, morte; o fentanil potencia a sedación do midazolam em 4–8x',
    'Fora do contexto anestésico controlado: monitoração rigurosa de SpO2, FR e nivel de consciência. Ter naloxona e flumazenil disponibles. Titulación lenta e sequencial. Apenas profissionais treinados em via aérea devem administrar esta combinación',
    'Apnea — Fentanil + Midazolam + Propofol: somente com monitorização anestésica',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.cns},
    [_kRefGG, _kRefKatz]),

  // 282 — Rocurônio + Sugammadex (reversão farmacológica)
  ('rocurônio', 'sugammadex',
    InteractionSeverity.minor,
    'Sugammadex é uma ciclodextrina que encapsula selectivamente o rocurônio (e vecurônio), revertendo farmacologicamente o bloqueio neuromuscular; não é uma interacción adversa — é o uso terapéutico intencional do sugammadex como antídoto específico do rocurônio; a interacción física entre as duas moléculas é altamente seletiva e desejável',
    'Sem efecto adverso pela interacción molecular; em raros casos, sugammadex pode causar bradicardia transitória ou reacción alérgica; o rocurônio não tem efectos adicionais después de encapsulamento',
    'Combinación intencional e terapéutica. Verificar dosis adecuada de sugammadex (16 mg/kg para reversão imediata em intubação difícil; 4 mg/kg para bloqueio moderado; 2 mg/kg para bloqueio superficial). Monitorar recuperação neuromuscular com TOF ratio > 0,9',
    'Reversão farmacológica intencional — Sugammadex encapsula rocurônio: antídoto específico',
    EvidenceLevel.established,
    {RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 283 — Ketamina + IMAOs (crise simpaticomimética)
  ('cetamina', 'tranilcipromina',
    InteractionSeverity.contraindicated,
    'Cetamina (anestésico dissociativo) inibe a recaptação de noradrenalina, dopamina e serotonina além de bloquear receptores NMDA; com a MAO-A inibida por tranilcipromina ou fenelzina, a noradrenalina e serotonina acumulam causando crisis hipertensiva grave e síndrome serotoninérgica; riesgo extremo em anestesia de emergência en pacientes não identificados como usuários de IMAO',
    'Crisis hipertensiva grave (PA > 200/120 mmHg), AVC hemorrágico, infarto do miocárdio, síndrome serotoninérgica grave com hipertermia; mortalidade alta',
    'Contraindicado. Informar anestesiologista sobre uso atual ou recente de IMAO. Aguardar 14 dias después de IMAO antes de cetamina eletiva. Em emergência: usar propofol ou etomidato como inducción alternativa. Se cetamina inadvertida: labetalol IV + ciproheptadina para crisis hipertensiva e serotonina',
    'CONTRAINDICADO — IMAO + Cetamina: crisis hipertensiva + serotonina em emergência anestésica',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.serotonin},
    [_kRefGG, _kRefFDA]),

  // 284 — Dexmedetomidina + Beta-bloqueadores (bradicardia profunda)
  ('dexmedetomidina', 'esmolol',
    InteractionSeverity.major,
    'Dexmedetomidina é agonista alfa-2 adrenérgico central que reduz o tônus simpático, causando bradicardia e hipotensión; esmolol e outros beta-bloqueadores causam bradicardia por bloqueio de receptores beta-1; a combinación causa bradicardia sinérgica profunda por dupla inhibición de la estimulação cardíaca simpática',
    'Bradicardia grave (FC < 40 bpm), asistolia temporária, hipotensión refractaria; bloqueo AV; colapso hemodinâmico en pacientes com baixa reserva cardíaca',
    'Monitorar FC e PA continuamente em UTI/sedación. Ter atropina 0,5 mg IV disponible para bradicardia sintomática. Reducir dosis de um dos agentes se FC < 50 bpm. Evitar en pacientes com disfunção sinusal prévia',
    'Bradicardia profunda — Dexmedetomidina + Beta-bloqueador: ter atropina disponible',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.arrhythmia},
    [_kRefGG, _kRefFDA]),

  // 285 — Propofol + Antibióticos lipofílicos (síndrome do propofol)
  ('propofol', 'linezolida',
    InteractionSeverity.moderate,
    'O propofol é formulado como emulsão lipídica (óleo de soja 10%); em infusão prolongada em altas dosiss (> 5 mg/kg/h por > 48h), pode causar síndrome de infusão de propofol (PRIS) com acidosis láctica, rabdomiólisis e colapso cardiovascular; linezolida pode potencializar a toxicidad mitocondrial (inibe a síntese proteica mitocondrial) amplificando os efectos da PRIS; a interacción é farmacodinâmica',
    'Síndrome de infusão de propofol amplificada: acidosis metabólica grave, rabdomiólisis, insuficiencia cardíaca, colapso hemodinâmico; mortalidade 33–85% em PRIS grave',
    'Monitorar triglicerídeos (alvo < 400 mg/dL), CK, lactato e ECG em infusão prolongada de propofol. Se linezolida for necesaria por > 7 dias, considerar alternativa sedativa (dexmedetomidina, midazolam). Interromper propofol se CK > 5x LSN ou acidosis láctica sem causa identificável',
    'PRIS amplificada — Propofol prolongado + Linezolida: monitorar triglicerídeos, CK e lactato',
    EvidenceLevel.possible,
    {RiskType.myopathy, RiskType.other},
    [_kRefGG]),

  // 286 — Atenolol + Verapamil (bloqueo AV completo)
  ('atenolol', 'verapamil',
    InteractionSeverity.contraindicated,
    'Atenolol e outros beta-bloqueadores inibem os efectos cronotrópico e dromotrópico da estimulação adrenérgica no nódulo sinoatrial e AV; verapamil é bloqueador de canal de cálcio com efectos cronotrópico e dromotrópico negativos potentes no nódulo AV; a combinación causa bloqueo AV sinérgico com riesgo de bloqueio completo e asistolia',
    'Bloqueo AV de 3º grau, asistolia, bradicardia extrema (FC < 30 bpm), colapso hemodinâmico, morte; o riesgo é máximo com administração intravenosa de qualquer um dos dois',
    'Contraindicação clínica bem estabelecida. Nunca administrar verapamil IV en pacientes em beta-bloqueador oral. Para taquiarritmias supraventriculares: adenosina é alternativa segura. Para controle de frecuencia a longo prazo em FA: digoxina tem menor interacción com verapamil',
    'CONTRAINDICADO — Atenolol + Verapamil IV: bloqueo AV completo e asistolia',
    EvidenceLevel.established,
    {RiskType.arrhythmia, RiskType.cardiovascular},
    [_kRefGG, _kRefKatz, _kRefFDA]),

  // 287 — Haloperidol + Lítio (neurotoxicidad)
  ('haloperidol', 'litio',
    InteractionSeverity.major,
    'Haloperidol e lítio têm mecanismos distintos mas podem causar neurotoxicidad sinérgica; o lítio pode potencializar a toxicidad do haloperidol no SNC; estudos retrospectivos relataram encefalopatía, parkinsonismo irreversible e discinesias tardias com a combinación; haloperidol reduz a aclaramiento renal de sódio, podendo indiretamente aumentar a litemia; a combinación clássica (Cohen encephalopathy) foi amplamente documentada nos anos 1970',
    'Encefalopatía com confusión mental, febre, parkinsonismo grave, discinesias tardias possivelmente irreversíveis; litemia pode aumentar inadvertidamente com haloperidol',
    'Usar com cautela e monitorar litemia de perto (a cada 3–5 dias no inicio). Preferir antipsicóticos atípicos (olanzapina, quetiapina) com menor riesgo de neurotoxicidad em combinación com lítio. Evitar haloperidol em dosis altas com lítio. Hidratação adecuada',
    'Neurotoxicidad grave — Haloperidol + Lítio: monitorar litemia e signos neurológicos',
    EvidenceLevel.probable,
    {RiskType.cns, RiskType.plasmaLevel},
    [_kRefGG, _kRefKatz]),

  // 288 — Dissulfiram + Álcool (reacción aversiva intencional)
  ('dissulfiram', 'alcool',
    InteractionSeverity.contraindicated,
    'Dissulfiram inibe a aldeído desidrogenase (ALDH), bloqueando o metabolismo del acetaldeído (metabólito do álcool); a inhibición causa acumulación de acetaldeído com reacción sistêmica grave; esta é uma interacción terapéutica intencional para dissuasão do consumo alcoólico, mas pode ser fatal em dosis elevada de álcool',
    'Reacción dissulfiram-álcool: rubor facial, cefaleia pulsátil, náuseas, vômitos, taquicardia, hipotensión, dispneia; em dosis altas de álcool: colapso cardiovascular, IAM, convulsiones, coma, morte',
    'Combinación intencional terapéutica para alcoolismo. Educação intensiva do paciente é essencial. Monitorar consumo alcoólico inadvertido (molhos, vinagre, remédios com álcool). Ter suporte cardiovascular disponible se reacción grave. Suspender dissulfiram pelo menos 2 semanas antes de cirurgia eletiva',
    'REAÇÃO GRAVE — Dissulfiram + Álcool: acumulación de acetaldeído intencional, educar paciente',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.other},
    [_kRefFDA, _kRefGG]),

  // 289 — Aciclovir + Tenofovir (nefrotoxicidad tubular)
  ('aciclovir', 'tenofovir',
    InteractionSeverity.moderate,
    'Aciclovir e tenofovir são análogos de nucleosídeos que competem pelo mesmo transportador renal OAT1 para excreción tubular ativa; a competição pode reduzir o clearance de ambos os fármacos, aumentando seus niveles plasmáticos; tenofovir já causa nefrotoxicidad tubular proximal; aciclovir pode precipitar na urina causando nefrotoxicidad tubular obstrutiva',
    'Nefrotoxicidad aditiva com riesgo de insuficiencia renal aguda; cristalúria por aciclovir potencializada pela competição transportadora; síndrome de Fanconi por acumulación de tenofovir',
    'Garantir hidratação adecuada (> 2 L/dia) durante co-administração de aciclovir IV. Monitorar creatinina, fósforo e urina (proteinúria, cilindros) semanalmente. Preferir valaciclovir oral (menor concentración urinária) cuando sea posible en pacientes em tenofovir',
    'Nefrotoxicidad tubular — Aciclovir + Tenofovir: hidratação ≥2L/dia obligatorio',
    EvidenceLevel.probable,
    {RiskType.nephrotoxicity},
    [_kRefGG, _kRefMdx]),

  // 290 — Oseltamivir + Probenecida (aumento de exposición)
  ('oseltamivir', 'probenecida',
    InteractionSeverity.moderate,
    'Probenecida inibe os transportadores renais OAT1/OAT3 para excreción tubular de ácidos orgânicos; oseltamivir ativo (GS4071) é excretado via OAT1/OAT3; probenecida reduz o aclaramiento renal do oseltamivir ativo em ~50%, dobrando sua AUC; embora possa ser usado terapeuticamente em tratamientos de baixa disponibilidade, aumenta o riesgo de toxicidad',
    'Náuseas, vômitos, cefaleia mais frecuentes por supraexposición ao oseltamivir ativo; raramente neuropsiquiátrico (agitação, alucinações) em concentraciones elevadas',
    'A combinación pode ser usada intencionalmente para "stretching" de dosis de oseltamivir em emergências de saúde pública. Na clínica habitual, monitorar efectos adversos. Ajustar dosis de oseltamivir para metade (75 mg dosis única ao invés de 75 mg 2x/dia) se probenecida for necesaria por outra indicação',
    'Dobra exposición ao oseltamivir — Probenecida inibe excreción renal: monitorar efectos adversos',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefFDA, _kRefGG]),

  // 291 — Ganciclovir IV + Zidovudina (AZT) — mielosupresión
  ('ganciclovir', 'zidovudina',
    InteractionSeverity.major,
    'Ganciclovir (antiviral para CMV) inibe a síntese de DNA viral por competição com dGTP, causando mielosupresión dosis-dependente; zidovudina (AZT) causa mielosupresión por inhibición da timidina quinase e toxicidad mitocondrial; a combinación causa mielosupresión sinérgica grave; en pacientes HIV+ com retinite por CMV (situação clínica típica), a combinación era frecuentemente limitante antes dos antirretrovirais modernos',
    'Anemia grave (Hb < 8 g/dL), neutropenia profunda (< 500/mm³), trombocitopenia; infecções oportunistas por mielosupresión; transfusões repetidas de hemácias',
    'Sustituir AZT por tenofovir ou abacavir (menos mielossupressores) se ganciclovir IV for necesario. Monitorar hemograma completo duas vezes por semana. Usar valganciclovir oral cuando sea posible (mielosupresión similar, mas administração mais cômoda). G-CSF pode ser usado para neutropenia grave',
    'Mielossupresión grave — Ganciclovir + Zidovudina (AZT): trocar AZT por tenofovir',
    EvidenceLevel.established,
    {RiskType.myelosuppression},
    [_kRefGG, _kRefFDA, _kRefUT]),

  // 292 — Didanosina + Allopurinol
  ('didanosina', 'alopurinol',
    InteractionSeverity.contraindicated,
    'Didanosina (DDI, análogo de nucleosídeo para HIV) é metabolizada pela xantina oxidase (XO) a hipoxantina; alopurinol inibe a XO, bloqueando o metabolismo de la didanosina; os niveles de didanosina aumentam em 4x, causando toxicidad grave pelo acumulación do fármaco ativo e de seus metabólitos na mitocôndria',
    'Neuropatia periférica grave por toxicidad mitocondrial (dor queimante nos pés), pancreatite grave, acidosis láctica, esteatose hepática; toxicidad dosis-dependente amplificada em 4x',
    'Contraindicado. Didanosina está em desuso (substituída por tenofovir, abacavir), mas ainda pode ser usada em países de renda baixa. Se alopurinol for necesario em paciente em DDI, sustituir a DDI. Nunca aumentar dosis de alopurinol em paciente em DDI',
    'CONTRAINDICADO — Alopurinol + Didanosina: 4x de exposición = neuropatia e pancreatite',
    EvidenceLevel.established,
    {RiskType.increasedToxicity, RiskType.hepatotoxicity},
    [_kRefFDA, _kRefGG]),

  // 293 — Maraviroque + Potentes inhibidores de CYP3A4
  ('maraviroque', 'cetoconazol',
    InteractionSeverity.major,
    'Maraviroque (antagonista de CCR5 para HIV) é substrato do CYP3A4; cetoconazol e outros potentes inhibidores do CYP3A4 aumentam a AUC do maraviroque em 3–5x; com concentraciones tão elevadas, o riesgo de hipotensión ortostática (efecto adverso principal do maraviroque) é substancialmente maior',
    'Hipotensión ortostática grave, síncope, quedas; tontura e lipotimia; na maioria dos casos a toxicidad é hemodinâmica',
    'Reducir dosis de maraviroque para 150 mg 2x/dia (em vez de 300 mg 2x/dia) quando em uso de inhibidores potentes de CYP3A4 (cetoconazol, itraconazol, indinavir, saquinavir, lopinavir/r). Monitorar PA ortostática. A bula da Celsentri especifica estas combinações e ajustes de dosis',
    'Hipotensión grave — Cetoconazol + Maraviroque: reducir dosis para 150 mg 2x/dia',
    EvidenceLevel.established,
    {RiskType.cardiovascular, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 294 — Dolutegravir + Metformina (aumento de exposición)
  ('dolutegravir', 'metformina',
    InteractionSeverity.moderate,
    'Dolutegravir inibe o transportador renal OCT2 e MATE1/MATE2-K, responsáveis pela excreción tubular da metformina; estudos farmacocinéticos demonstraram que dolutegravir aumenta a AUC da metformina em 79% (quase dobra); en pacientes com IRC, o acumulación de metformina é clinicamente relevante para acidosis láctica',
    'Acidosis láctica por acumulación de metformina: náuseas, dor abdominal, dispneia, choque; pH < 7,35, lactato > 5 mmol/L; mortalidade 30–50%',
    'Limitar dosis de metformina a 1.000 mg/dia quando em uso de dolutegravir. Monitorar lactato e función renal a cada 3–6 meses. En pacientes com TFG < 45 mL/min, contraindicar a combinación. Considerar iSGLT2 ou DPP-4i como alternativas com menor riesgo de acidosis láctica',
    'Acidosis láctica — Dolutegravir dobra exposición à metformina: dosis máxima 1.000 mg/dia',
    EvidenceLevel.established,
    {RiskType.other, RiskType.plasmaLevel},
    [_kRefFDA, _kRefGG]),

  // 295 — Bictegravir + Margetuximabe (interacciones protocolares)
  ('bictegravir', 'rifampicina',
    InteractionSeverity.contraindicated,
    'Bictegravir (integrase strand transfer inhibitor, parte do Biktarvy) é substrato do CYP3A4 e P-gp; rifampicina induz ambos potentemente; a coadministração reduz a AUC do bictegravir em ~75%, resultando em concentraciones subterapéuticas do antirretroviral e riesgo de fracaso virológica e resistência',
    'Fracaso virológico com rebote de carga viral HIV; seleção de mutações de resistência ao integrase (resistência cruzada a raltegravir, elvitegravir); progresión para AIDS',
    'Contraindicado. Usar rifabutina em vez de rifampicina para tuberculose en pacientes em bictegravir (rifabutina tem menor inducción CYP3A4); requer ajuste de dosis do regime. Consultar infectologista experiente em TARV para manejo da coinfecção TB/HIV',
    'CONTRAINDICADO — Rifampicina reduz bictegravir 75%: fracaso virológico e resistência ao HIV',
    EvidenceLevel.established,
    {RiskType.reducedEfficacy},
    [_kRefFDA, _kRefGG]),

  // 296 — Naloxona + Buprenorfina (reversão parcial)
  ('naloxona', 'buprenorfina',
    InteractionSeverity.major,
    'Naloxona é antagonista puro de receptores opioides com alta afinidade; buprenorfina é agonista parcial com afinidade muito alta para receptores mu (maior que a naloxona em baixas dosiss); en pacientes em buprenorfina para dependência de opioides, a naloxona pode deslocar a buprenorfina parcialmente, precipitando abstinência moderada; em sobredosis de buprenorfina, dosis altas de naloxona são necesarias para reversão',
    'Síndrome de abstinencia precipitada (moderada, não severa como com opioides plenos); reducción insuficiente da depresión respiratoria em sobredosis por buprenorfina em altas dosiss se naloxona em dosiss padrão',
    'Em emergência de sobredosis de buprenorfina: usar naloxona em infusão contínua (não em bolus único) pois a buprenorfina tem vida media muito longa (24–72h). Iniciar naloxona 2 mg IV, titular até melhora da respiração. En pacientes em tratamiento com buprenorfina: evitar naloxona exceto em emergência vital',
    'Reversão parcial e abstinência — Naloxona + Buprenorfina: infusão contínua, não bolus único',
    EvidenceLevel.established,
    {RiskType.respiratoryDepression, RiskType.other},
    [_kRefFDA, _kRefGG, _kRefUT]),

  // 297 — Flumazenil + Benzodiazepínicos de longa ação (rebote de sedación)
  ('flumazenil', 'diazepam',
    InteractionSeverity.moderate,
    'Flumazenil antagoniza competitivamente e reversivelmente os receptores GABA-A benzodiazepínicos; sua vida media é muito curta (40–80 minutos) comparada à de benzodiazepínicos de longa ação (diazepam: 20–100h; clobazam: 18–42h); después de a eliminación do flumazenil, o efecto sedante do BZD de longa duración retorna (ressedación)',
    'Ressedación después de 1–2 horas com retorno da depresión respiratoria e confusión mental; riesgo de convulsiones de abstinência ao antagonizar BZD em paciente dependente',
    'Monitorar por pelo menos 2 horas después de reversão com flumazenil en pacientes com BZD de longa ação. Considerar segunda dosis ou infusão de flumazenil. Não dispensar o paciente después de flumazenil sem período de observação. Em dependentes de BZD: usar flumazenil com cautela (convulsiones de abstinência)',
    'Ressedación — Flumazenil de vida media curta vs diazepam de longa ação: observar 2 horas',
    EvidenceLevel.established,
    {RiskType.cns, RiskType.respiratoryDepression},
    [_kRefGG, _kRefKatz]),

  // 298 — Vitamina K + Varfarina (antagonismo intencional)
  ('vitamina_k', 'varfarina',
    InteractionSeverity.major,
    'Vitamina K é co-fator essencial para a carboxilação dos fatores de coagulação II, VII, IX e X; varfarina inibe a vitamina K epóxido redutase (VKOR), bloqueando a regeneração da vitamina K ativa; ao administrar vitamina K exógena, reverte-se o efecto anticoagulante da varfarina por repleção do cofator; a interacción é farmacológica e dosis-dependente',
    'Reducción del INR com posible tromboembolismo em paciente com FA, prótese valvar ou TVP/EP se vitamina K em excesso; em supracoagulação (INR > 9): vitamina K intencional para correção',
    'Uso intencional para reverter supracoagulação ou sangrado. Para INR > 9 sem sangrado: vitamina K 2,5 mg VO. Para sangrado grave: vitamina K 10 mg IV + CCP (concentrado de complexo protrombínico) ou PFC. Alimentos ricos em vitamina K (espinafre, brócolis) afetam o INR crónicamente — dieta consistente',
    'Antagonismo intencional — Vitamina K reverte varfarina: dosis ajustada ao grau de supracoagulação',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis},
    [_kRefGG, _kRefKatz, _kRefMdx, _kRefUT]),

  // 299 — Protamina + Heparina (neutralização dosis-dependente)
  ('protamina', 'heparina',
    InteractionSeverity.major,
    'Protamina (proteína catiônica de esperma de salmão) neutraliza a heparina ao formar um complexo iônico estável com heparina (aniônica) tornando-a farmacologicamente inativa; a interacción é intencional e dosis-dependente (1 mg de protamina neutraliza 100 UI de heparina); excesso de protamina (dosis > 1,5 mg/100 UI heparina) causa paradoxalmente efecto anticoagulante e toxicidad cardiovascular',
    'Em dosis correta: neutralização do efecto anticoagulante da heparina com posible trombosis se desnecesaria; excesso de protamina: hipotensión grave, bradicardia, efecto anticoagulante paradoxal, vasoconstrição pulmonar; anafilaxia à protamina (especialmente em alérgicos a peixe)',
    'Calcular dosis de protamina com base na dosis de heparina administrada e no tempo desde a última dosis (heparina tem vida media de 1–2h). Injeção lenta IV (máximo 5 mg/min) para minimizar toxicidad cardiovascular. Testar para alergia antes do uso eletivo. Ter epinefrina e corticoide disponibles',
    'Neutralização dosis-dependente — Protamina + Heparina: calcular dosis exata para evitar excesso',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis},
    [_kRefGG, _kRefFDA]),

  // ══════════════════════════════════════════════════════════════════════════
  // LOTE 2 — NOVOS FÁRMACOS: ANTIBIÓTICOS / TUBERCULOSTÁTICOS / ANTIFÚNGICOS
  //           ANESTESIA / BNM / CARDIOVASCULAR / ANTICOAGULAÇÃO
  // ══════════════════════════════════════════════════════════════════════════

  // ── ANTIBIÓTICOS ──────────────────────────────────────────────────────────

  // Oxacilina
  ('oxacilina', 'warfarina',
    InteractionSeverity.moderate,
    'Oxacilina (penicilina isoxazolil) pode inibir parcialmente o metabolismo da varfarina por via CYP2C9 e, além disso, alterações na flora intestinal reduzem a síntese de vitamina K bacteriana, potenciando o efeito anticoagulante',
    'Aumento do INR com risco de sangramento; equimoses, hematúria, sangramento GI',
    'Monitorar INR 2–3x/semana durante terapia com oxacilina. Ajustar dose de varfarina conforme INR. Educar paciente sobre sinais de sangramento',
    'Oxacilina potencia varfarina — Monitorar INR',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

  ('oxacilina', 'metotrexato',
    InteractionSeverity.major,
    'As penicilinas, incluindo oxacilina, competem com o metotrexato pela secreção tubular renal via transportadores OAT (organic anion transporters), reduzindo a eliminação renal do metotrexato e elevando sua concentração plasmática a níveis tóxicos',
    'Toxicidade grave pelo metotrexato: mielossupressão (pancitopenia), mucosite severa, nefrotoxicidade aguda; potencialmente fatal',
    'Evitar combinação com metotrexato em doses moderadas/altas. Se necessário, monitorar níveis séricos de metotrexato e leucovorin rescue. Ajustar intervalo de doses',
    'Oxacilina + Metotrexato — Risco de toxicidade grave pelo MTX',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  // Cefazolina
  ('cefazolina', 'warfarina',
    InteractionSeverity.moderate,
    'Cefazolina, como outras cefalosporinas, altera a flora intestinal reduzindo síntese de vitamina K bacteriana; cefalosporinas com cadeia N-methylthiotetrazole (não é o caso da cefazolina) têm maior risco, mas qualquer cefalosporina pode potenciar varfarina',
    'Aumento do INR; risco de sangramento clínico',
    'Monitorar INR durante uso de cefazolina, especialmente em profilaxia cirúrgica prolongada. Ajustar dose de varfarina',
    'Cefazolina + Varfarina — Monitorar INR',
    EvidenceLevel.probable,
    {RiskType.hemorrhagic},
    [_kRefGG]),

  // Teicoplanina
  ('teicoplanina', 'gentamicina',
    InteractionSeverity.major,
    'Teicoplanina (glicopeptídeo) e aminoglicosídeos (gentamicina) têm mecanismos distintos de nefrotoxicidade que se somam: teicoplanina interfere na permeabilidade do túbulo proximal e aminoglicosídeos acumulam-se nas células do córtex renal causando necrose tubular; a combinação eleva significativamente o risco de IRA',
    'Nefrotoxicidade aguda — elevação de creatinina e ureia, oligúria, IRA; ototoxicidade cumulativa (zumbido, perda auditiva)',
    'Monitorar creatinina sérica e débito urinário diariamente. Níveis séricos de gentamicina (pico e vale). Reservar para casos sem alternativa; preferir monoterapia quando possível',
    'Teicoplanina + Aminoglicosídeo — Nefrotoxicidade aditiva grave',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('teicoplanina', 'vancomicina',
    InteractionSeverity.moderate,
    'Ambos são glicopeptídeos com mecanismos de ação e perfis de toxicidade sobreponíveis; uso concomitante é raro clinicamente, mas exposição sequencial próxima potencia nefro e ototoxicidade',
    'Nefrotoxicidade e ototoxicidade aditivas; elevação de creatinina, zumbido, perda auditiva',
    'Evitar uso simultâneo. Ao trocar vancomicina por teicoplanina, monitorar função renal por pelo menos 5 dias após a troca',
    'Teicoplanina + Vancomicina — Toxicidade renal/auditiva aditiva',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  ('teicoplanina', 'furosemida',
    InteractionSeverity.moderate,
    'Furosemida potencia a nefrotoxicidade e ototoxicidade da teicoplanina por dois mecanismos: redução do fluxo renal com aumento das concentrações de teicoplanina nos túbulos e toxicidade coclear direta dos diuréticos de alça',
    'Nefrotoxicidade aumentada; ototoxicidade — surdez permanente em casos graves',
    'Monitorar função renal e audição. Preferir intervalos maiores entre doses ou reduzir dose de teicoplanina em pacientes usando furosemida em altas doses',
    'Teicoplanina + Furosemida — Ototoxicidade e nefrotoxicidade aumentadas',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // Minociclina
  ('minociclina', 'isotretinoina',
    InteractionSeverity.contraindicated,
    'Ambos os fármacos, independentemente, aumentam a pressão intracraniana (pseudotumor cerebral); a combinação é sinérgica nesse efeito — isotretinoína interfere no transporte de ácido retinoico no plexo coroide e minociclina tem mecanismo incerto mas bem documentado de hipertensão intracraniana benigna',
    'Hipertensão intracraniana grave (pseudotumor cerebral): cefaleia intensa, papiledema, déficit visual permanente, diplopia; risco de perda de visão irreversível',
    'CONTRAINDICADO. Não utilizar em combinação. Se for necessário tratar acne em paciente usando isotretinoína, usar alternativa não-tetraciclínica',
    'Minociclina + Isotretinoína — CONTRAINDICADO: Hipertensão intracraniana',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('minociclina', 'warfarina',
    InteractionSeverity.moderate,
    'Minociclina, como outras tetraciclinas, altera a flora intestinal reduzindo síntese bacteriana de vitamina K; adicionalmente inibe CYP2C9 contribuindo para elevação do INR',
    'Aumento do INR e risco de sangramento',
    'Monitorar INR frequentemente durante uso de minociclina. Reduzir dose de varfarina se necessário',
    'Minociclina + Varfarina — Monitorar INR',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

  ('minociclina', 'anticoncepcional_oral',
    InteractionSeverity.moderate,
    'Tetraciclinas podem reduzir a eficácia dos contraceptivos orais combinados por alteração da flora intestinal que participa do ciclo enterohepático dos estrogênios; evidência controversa mas clinicamente reconhecida',
    'Falha contraceptiva potencial; gestação não planejada',
    'Recomendar método contraceptivo de barreira adicional durante o tratamento e por 7 dias após término',
    'Minociclina + Contraceptivo oral — Possível falha contraceptiva',
    EvidenceLevel.possible,
    {RiskType.plasmaLevel},
    [_kRefGG]),

  // Estreptomicina
  ('estreptomicina', 'furosemida',
    InteractionSeverity.major,
    'Estreptomicina (aminoglicosídeo) causa ototoxicidade ao acumular-se no endolinfa da cóclea e do labirinto; furosemida aumenta a concentração intracoclear de aminoglicosídeos por alterar a composição iônica da endolinfa e inibir o transportador Na-K-2Cl',
    'Surdez permanente bilateral, perda do equilíbrio vestibular; risco de sordera irreversível especialmente em pacientes com DRC',
    'Evitar combinação. Se imprescindível, reduzir ao mínimo a dose de furosemida, monitorar função auditiva com audiometria e avaliar alternativas ao diurético',
    'Estreptomicina + Furosemida — Risco de surdez permanente',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  ('estreptomicina', 'cisplatina',
    InteractionSeverity.major,
    'Cisplatina e aminoglicosídeos têm ototoxicidade e nefrotoxicidade aditivas; cisplatina danifica células ciliadas externas da cóclea e células do túbulo proximal renal; aminoglicosídeos potenciam ambos os efeitos',
    'Surdez permanente; IRA grave; neuropatia periférica cumulativa',
    'Evitar combinação. Se obrigatório: monitorar audiometria antes e durante tratamento, creatinina séria, débito urinário. Espaçar ao máximo as administrações',
    'Estreptomicina + Cisplatina — Ototoxicidade e nefrotoxicidade graves',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // ── TUBERCULOSTÁTICOS ─────────────────────────────────────────────────────

  // Rifampicina (amplia interações já existentes)
  ('rifampicina', 'isoniazida',
    InteractionSeverity.moderate,
    'A combinação rifampicina + isoniazida é padrão no tratamento de tuberculose (esquema RIPES), porém ambos os fármacos são hepatotóxicos por mecanismos distintos: rifampicina induz o CYP2E1 que converte isoniazida em metabólitos hepatotóxicos (acetilhidrazina, hidrazina), elevando o risco de hepatite medicamentosa',
    'Hepatotoxicidade — elevação de transaminases em 10–20% dos pacientes; hepatite clínica fulminante em 0,1–1%; icterícia, coagulopatia',
    'Monitorar ALT/AST mensalmente nos primeiros 3 meses. Suspender ambos se ALT > 3x LSN com sintomas ou > 5x LSN assintomático. Reiniciar sequencialmente após normalização',
    'Rifampicina + Isoniazida — Monitorar função hepática mensal (hepatite medicamentosa)',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('rifampicina', 'halotano',
    InteractionSeverity.major,
    'Rifampicina induz fortemente o CYP2E1, que metaboliza halotano a trifluoracetil cloreto — metabólito altamente reativo que se liga covalentemente a proteínas hepáticas formando neoantigênios e desencadeando hepatite autoimune; a indução enzimática multiplica a produção deste metabólito tóxico',
    'Hepatite fulminante por halotano — necrose hepática maciça, insuficiência hepática aguda, potencialmente fatal',
    'CONTRAINDICADO. Evitar halotano em pacientes em uso ou que usaram rifampicina recentemente. Usar anestésicos alternativos (sevoflurano, isoflurano) com precaução',
    'Rifampicina + Halotano — EVITAR: hepatite fulminante por indução CYP2E1',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  ('rifampicina', 'contraceptivo_oral',
    InteractionSeverity.major,
    'Rifampicina é o indutor do CYP3A4 e CYP2C9 mais potente clinicamente relevante; induz também UGT e P-glicoproteína; reduz os níveis plasmáticos de etinilestradiol em até 70% e de progestinas em 50–90%, eliminando a eficácia contraceptiva',
    'Falha contraceptiva com gestação não planejada; documentado em múltiplos estudos e relatos de caso',
    'CONTRAINDICADO como único método contraceptivo. Usar método de barreira + método hormonal não oral (DIU de cobre, implante) durante o tratamento e por 2 meses após término',
    'Rifampicina + Contraceptivo oral — Falha contraceptiva: usar método alternativo',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  // Isoniazida (amplia interações)
  ('isoniazida', 'fenitoina',
    InteractionSeverity.major,
    'Isoniazida inibe fortemente o CYP2C9, principal enzima do metabolismo da fenitoína, elevando os níveis plasmáticos de fenitoína em 50–300%; o efeito é mais pronunciado em acetiladores lentos de isoniazida (50% da população caucasiana)',
    'Toxicidade pela fenitoína: nistagmo, ataxia, disartria, confusão mental, crise convulsiva paradoxal por toxicidade',
    'Monitorar níveis séricos de fenitoína semanalmente no início da associação. Reduzir dose de fenitoína em 30–50%. Alertar paciente sobre sinais de toxicidade neurológica',
    'Isoniazida + Fenitoína — Toxicidade fenitoína por inibição CYP2C9',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('isoniazida', 'alcool',
    InteractionSeverity.major,
    'Álcool etílico induz o CYP2E1, mesma via metabólica que aumenta a produção de metabólitos hepatotóxicos da isoniazida (acetilhidrazina, hidrazina); adicionalmente ambos causam hepatotoxicidade direta independente',
    'Hepatotoxicidade grave — elevação de transaminases, hepatite medicamentosa, insuficiência hepática; risco de neuropatia periférica amplificado',
    'Contraindicar consumo de álcool durante tratamento com isoniazida. Avaliar função hepática antes e mensalmente durante tratamento',
    'Isoniazida + Álcool — Hepatotoxicidade grave amplificada',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // Pirazinamida (amplia interações)
  ('pirazinamida', 'alopurinol',
    InteractionSeverity.moderate,
    'Pirazinamida inibe a excreção renal de ácido úrico pelos transportadores URAT1 e OAT nos túbulos proximais, causando hiperuricemia; alopurinol inibe a xantina oxidase que produz ácido úrico; a combinação pode ter efeitos imprevisíveis e a pirazinamida pode reduzir a eficácia do alopurinol',
    'Hiperuricemia persistente, crise de gota aguda, artralgia; monitoramento adequado necessário',
    'Monitorar uricemia semanalmente. Aumentar ingestão hídrica. Alopurinol tem eficácia reduzida contra hiperuricemia induzida por pirazinamida; preferir colchicina para profilaxia de crise de gota',
    'Pirazinamida + Alopurinol — Hiperuricemia por mecanismos distintos',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // Etambutol (amplia interações)
  ('etambutol', 'antiácido',
    InteractionSeverity.moderate,
    'Antiácidos contendo hidróxido de alumínio reduzem significativamente a absorção gastrointestinal do etambutol (redução de Cmax em até 25–30%) por formação de quelatos insolúveis no trato GI',
    'Redução dos níveis séricos de etambutol com possível falha terapêutica no tratamento da tuberculose; risco de resistência',
    'Administrar etambutol pelo menos 2 horas antes ou 4 horas após antiácidos. Orientar paciente sobre horário adequado',
    'Etambutol + Antiácido — Redução da absorção: espaçar 2–4 horas',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG]),

  // ── ANTIVIRAIS CMV ────────────────────────────────────────────────────────

  // Valganciclovir (amplia interações do ganciclovir já existentes)
  ('valganciclovir', 'zidovudina',
    InteractionSeverity.major,
    'Valganciclovir (pró-fármaco do ganciclovir) e zidovudina (AZT) causam mielossupressão independentemente; ambos inibem a DNA polimerase mitocondrial e a hematopoiese medular; a combinação é sinérgica na supressão medular',
    'Anemia grave, neutropenia profunda (infecções oportunistas), trombocitopenia; potencialmente fatal em imunossuprimidos',
    'Monitorar hemograma semanalmente. Considerar redução de dose de zidovudina ou trocar para outro ITRN (tenofovir, abacavir). Usar fatores de crescimento (G-CSF) se necessário',
    'Valganciclovir + Zidovudina — Mielossupressão aditiva grave',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('valganciclovir', 'mofetila_micofenolato',
    InteractionSeverity.moderate,
    'Valganciclovir e micofenolato de mofetila (MMF) competem pelos mesmos transportadores renais (MRP2, BCRP) para excreção; a combinação comum em transplantados aumenta a exposição sistêmica de ambos os fármacos',
    'Toxicidade hematológica aumentada — anemia, neutropenia; toxicidade GI pelo MMF amplificada',
    'Monitorar hemograma 2x/semana em transplantados recebendo ambos. Considerar redução de doses. Avaliar alternativas antivirais',
    'Valganciclovir + Micofenolato — Mielossupressão e toxicidade GI aumentadas',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  ('valganciclovir', 'imipenem',
    InteractionSeverity.major,
    'A associação de ganciclovir/valganciclovir com imipenem-cilastatina foi associada a crises convulsivas generalizadas em pacientes imunossuprimidos; o mecanismo exato é desconhecido mas envolve possível efeito sinérgico no limiar convulsivo',
    'Convulsões generalizadas; risco aumentado especialmente em pacientes com DRC (acúmulo de ambos) ou lesões cerebrais prévias',
    'EVITAR combinação. Substituir imipenem por meropenem (menor risco convulsivo) ou doripenem quando possível',
    'Valganciclovir + Imipenem — Risco de convulsões: substituir imipenem',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  // ── ANTIFÚNGICOS ──────────────────────────────────────────────────────────

  // Micafungina (interações não existentes)
  ('micafungina', 'ciclosporina',
    InteractionSeverity.moderate,
    'Micafungina inibe o CYP3A4 e a P-glicoproteína de forma moderada; ciclosporina é substrato de ambos; a combinação pode elevar os níveis de ciclosporina em 20–40%, variável entre pacientes',
    'Toxicidade pela ciclosporina: nefrotoxicidade, hipertensão, neurotoxicidade, hiperglicemia',
    'Monitorar níveis de ciclosporina e função renal com maior frequência durante uso de micafungina. Ajustar dose de ciclosporina conforme necessário',
    'Micafungina + Ciclosporina — Monitorar níveis de ciclosporina',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  ('micafungina', 'sirolimus',
    InteractionSeverity.moderate,
    'Micafungina inibe o metabolismo do sirolimus mediado por CYP3A4 e P-gp, elevando a AUC do sirolimus em cerca de 20%; sirolimus tem janela terapêutica estreita',
    'Toxicidade pelo sirolimus: pneumonite intersticial, hiperlipidemia, trombocitopenia, nefrotoxicidade, cicatrização prejudicada',
    'Monitorar níveis séricos de sirolimus frequentemente. Reduzir dose de sirolimus em 20% ao iniciar micafungina',
    'Micafungina + Sirolimus — Elevar monitoramento de níveis de sirolimus',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefFDA]),

  // Terbinafina
  ('terbinafina', 'warfarina',
    InteractionSeverity.moderate,
    'Terbinafina inibe moderadamente o CYP2C9, principal enzima do catabolismo da S-varfarina (enantiômero mais potente); a inibição eleva os níveis de varfarina e o INR',
    'Sangramento clínico por INR supratherapêutico; equimoses, hematúria, hemorragia GI',
    'Monitorar INR semanalmente no início do tratamento com terbinafina. Ajustar dose de varfarina conforme INR',
    'Terbinafina + Varfarina — Monitorar INR (inibição CYP2C9)',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefMdx]),

  ('terbinafina', 'antidepressivo_triciclico',
    InteractionSeverity.major,
    'Terbinafina é inibidor potente e irreversível do CYP2D6; antidepressivos tricíclicos (amitriptilina, nortriptilina, imipramina) são metabolizados principalmente pelo CYP2D6; a inibição irreversível eleva drasticamente os níveis plasmáticos dos tricíclicos',
    'Toxicidade pelos tricíclicos: arritmias graves (prolongamento QT, TdP), convulsões, hipotensão ortostática grave, síndrome anticolinérgica severa',
    'Evitar combinação. Se necessário, reduzir dose do tricíclico em 50% e monitorar ECG e níveis séricos. Efeito persiste por semanas após suspensão da terbinafina (inibição irreversível)',
    'Terbinafina + Tricíclico — Toxicidade tricíclica grave por inibição irreversível CYP2D6',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  ('terbinafina', 'cafeina',
    InteractionSeverity.moderate,
    'Terbinafina inibe o CYP1A2, responsável pelo metabolismo da cafeína; a concentração de cafeína pode triplicar elevando seus efeitos',
    'Taquicardia, insônia, tremores, ansiedade, hipertensão; sintomas de intoxicação cafeínica',
    'Orientar redução do consumo de cafeína (café, chá, energéticos) durante tratamento. Vigilância em pacientes cardíacos',
    'Terbinafina + Cafeína — Reduzir consumo de cafeína',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // Voriconazol (amplia interações já existentes)
  ('voriconazol', 'sirolimus',
    InteractionSeverity.contraindicated,
    'Voriconazol inibe fortemente CYP3A4, CYP2C9 e CYP2C19; sirolimus é substrato altamente dependente do CYP3A4 e P-gp; a combinação eleva a AUC do sirolimus em mais de 11 vezes (1100% de aumento)',
    'Toxicidade grave pelo sirolimus: pneumonite intersticial fatal, nefrotoxicidade grave, trombocitopenia, cicatrização prejudicada, sepse por imunossupressão excessiva',
    'CONTRAINDICADO pela bula. Substituir sirolimus por tacrolimus ou ciclosporina (com monitoramento de nível) durante tratamento com voriconazol',
    'Voriconazol + Sirolimus — CONTRAINDICADO: exposição 11x aumentada',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('voriconazol', 'estatina',
    InteractionSeverity.major,
    'Voriconazol inibe o CYP3A4 que metaboliza lovastatina e sinvastatina (e em menor grau atorvastatina); a inibição potente do CYP3A4 eleva os níveis das estatinas dependentes desta via em 5–10x, aumentando drasticamente o risco de rabdomiólise',
    'Miopatia grave, rabdomiólise — dor e fraqueza muscular intensa, mioglobinúria (urina escura), IRA, hipercalemia; risco de arritmia e parada cardíaca',
    'Suspender ou reduzir fortemente a dose de estatinas CYP3A4-dependentes durante voriconazol. Preferir rosuvastatina (metabolismo independente de CYP3A4) com dose mínima',
    'Voriconazol + Estatina CYP3A4 — Risco de rabdomiólise: suspender ou reduzir estatina',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  ('voriconazol', 'metadona',
    InteractionSeverity.contraindicated,
    'Voriconazol inibe CYP3A4 e CYP2C19 que metabolizam a metadona (especialmente R-metadona); além disso ambos prolongam o QT; a combinação eleva os níveis de metadona em 2–3x e tem duplo mecanismo de arritmogenicidade',
    'Torsade de Pointes, fibrilação ventricular, morte súbita; depressão respiratória grave por superdose de metadona',
    'CONTRAINDICADO. Substituir voriconazol por equinocandina ou anfotericina B lipossomial. Se impossível, reduzir dose de metadona em 50% e monitorar ECG (QTc)',
    'Voriconazol + Metadona — CONTRAINDICADO: QT + toxicidade por metadona',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  // Itraconazol (amplia interações já existentes)
  ('itraconazol', 'sinvastatina',
    InteractionSeverity.contraindicated,
    'Itraconazol é inibidor potente de CYP3A4; sinvastatina é quase exclusivamente metabolizada por CYP3A4 — a inibição eleva a AUC da sinvastatina em mais de 10x, com pico de concentração 13x maior',
    'Rabdomiólise grave — fraqueza muscular severa, mioglobinúria, IRA, hipercalemia; risco de parada cardíaca',
    'CONTRAINDICADO pela bula. Suspender sinvastatina durante tratamento com itraconazol. Alternativa: rosuvastatina em dose baixa (não metabolizada por CYP3A4)',
    'Itraconazol + Sinvastatina — CONTRAINDICADO: rabdomiólise (AUC 10x)',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  ('itraconazol', 'midazolam',
    InteractionSeverity.contraindicated,
    'Itraconazol inibe intensamente o CYP3A4 intestinal e hepático; midazolam oral é quase completamente metabolizado pelo CYP3A4 intestinal na primeira passagem — a inibição eleva a AUC do midazolam oral em 5–15x',
    'Sedação profunda e prolongada, depressão respiratória, apneia, coma; risco de morte por depressão respiratória',
    'Midazolam ORAL: CONTRAINDICADO. Midazolam IV: usar com extrema cautela, dose reduzida em 75%, monitoração em UTI. Considerar lorazepam (alternativa com menor interação)',
    'Itraconazol + Midazolam oral — CONTRAINDICADO: sedação fatal',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  // ── ANESTESIA — INALATÓRIOS ───────────────────────────────────────────────

  // Sevoflurano
  ('sevoflurano', 'qt_prolongadores',
    InteractionSeverity.major,
    'Sevoflurano prolonga o intervalo QTc por bloqueio de canais de potássio IKr (hERG); associado a outros fármacos que prolongam QT (antiarrítmicos classe III, haloperidol, macrolídeos, quinolonas, metadona) o risco de Torsade de Pointes é multiplicado',
    'Torsade de Pointes (TdP), fibrilação ventricular, morte súbita perioperatória',
    'Revisar todos os medicamentos QT-prolongadores antes da anestesia. Monitorar ECG contínuo. Corrigir hipocalemia e hipomagnesemia antes da indução. Considerar anestesia total intravenosa (TIVA) em pacientes de alto risco',
    'Sevoflurano + Prolongadores QT — Monitorar QTc, risco de TdP',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA]),

  ('sevoflurano', 'epinefrina',
    InteractionSeverity.major,
    'Halogenados (sevoflurano, isoflurano) sensibilizam o miocárdio às catecolaminas por alterar a sensibilidade dos canais de Ca²⁺; adrenalina infiltrada localmente pode desencadear arritmias ventriculares graves especialmente em doses > 10 mcg/kg',
    'Taquicardia ventricular, fibrilação ventricular, paro cardíaco intraoperatório',
    'Limitar epinefrina infiltrada a < 10 mcg/kg (adultos: < 100 mcg por infiltração) durante anestesia com halogenados. Monitorar ECG contínuo. Evitar injeção intravascular acidental',
    'Sevoflurano + Adrenalina infiltrada — Limite ≤10 mcg/kg para evitar arritmia',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  // Isoflurano
  ('isoflurano', 'epinefrina',
    InteractionSeverity.major,
    'Isoflurano, como todos os halogenados, sensibiliza o miocárdio às catecolaminas; o limiar arritmogênico da adrenalina é reduzido durante anestesia com isoflurano (menor sensibilização que halotano, porém clinicamente relevante)',
    'Arritmias ventriculares: extrassístoles ventriculares frequentes, TV, FV',
    'Limitar epinefrina a doses seguras (< 10 mcg/kg). Monitorar ECG. Preferir noradrenalina se vasopressor necessário',
    'Isoflurano + Adrenalina — Sensibilização miocárdica: limitar dose',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG]),

  ('isoflurano', 'bloqueadores_neuromusculares',
    InteractionSeverity.moderate,
    'Isoflurano potencia o bloqueio neuromuscular não despolarizante por estabilização da membrana pós-sináptica e redução da sensibilidade do receptor à acetilcolina; a duração e profundidade do bloqueio são aumentadas em 30–50% com halogenados',
    'Bloqueio neuromuscular residual prolongado no pós-operatório; fraqueza muscular, hipoventilação, risco de reintubação',
    'Reduzir dose dos BNM não despolarizantes em 30% durante anestesia com isoflurano. Monitorar neuromuscular com TOF. Aguardar reversão completa (TOF ratio > 0,9) antes de extubação',
    'Isoflurano + BNM — Potencia bloqueio: reduzir dose BNM em 30%',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // Halotano (histórico, mas importante para reconhecer)
  ('halotano', 'succinilcolina',
    InteractionSeverity.contraindicated,
    'Combinação clássica de desencadeamento de Hipertermia Maligna em pacientes geneticamente suscetíveis (mutação RYR1/CACNA1S); halotano e succinilcolina são os dois gatilhos mais potentes; juntos aumentam drasticamente o risco',
    'Hipertermia Maligna: rigidez muscular generalizada, hipertermia de alta gravidade (> 40°C), rabdomiólise fulminante, acidose metabólica e respiratória grave, IRA, CID, óbito',
    'CONTRAINDICADO em pacientes com história pessoal ou familiar de HM ou susceptibilidade documentada. Ter dantroleno disponível (2,5 mg/kg inicial IV). Protocolo de emergência de HM. Anestesia TIVA como alternativa',
    'Halotano + Succinilcolina — Gatilhos clássicos de Hipertermia Maligna',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('halotano', 'adrenalina',
    InteractionSeverity.contraindicated,
    'Halotano sensibiliza intensamente o miocárdio às catecolaminas (muito mais que isoflurano/sevoflurano); adrenalina em qualquer dose pode desencadear arritmias ventriculares fatais durante anestesia com halotano',
    'Fibrilação ventricular e paro cardíaco; arritmias ventriculares malignas refratárias',
    'CONTRAINDICADO uso concomitante. Evitar adrenalina infiltrada, em epinefrina com anestésico local, ou vasopressores adrenérgicos durante halotano. Halotano não é mais usado em adultos modernamente por este e outros motivos',
    'Halotano + Adrenalina — CONTRAINDICADO: FV e paro cardíaco',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA]),

  // Tiopental
  ('tiopental', 'opioides',
    InteractionSeverity.major,
    'Tiopental (barbitúrico) e opioides (morfina, fentanil, sufentanil) têm efeitos sinérgicos sobre o SNC: tiopental potencia a depressão respiratória central dos opioides por mecanismos distintos e complementares (barbitúrico via GABA-A + opioide via receptores μ)',
    'Apneia, depressão respiratória grave, bradipneia, hipóxia, hipercapnia, rebaixamento de consciência prolongado',
    'Reduzir dose de tiopental em 30–50% quando combinado com opioides. Monitorar SpO2 e capnografia continuamente. Ter naloxona disponível',
    'Tiopental + Opioides — Apneia por depressão respiratória sinérgica',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('tiopental', 'cetamina',
    InteractionSeverity.moderate,
    'Tiopental reduz os efeitos dissociativos e estimulantes cardiovasculares da cetamina (cetamina normalmente eleva PA e FC); a combinação pode resultar em hipotensão por supressão do efeito simpaticomimético da cetamina pelo tiopental',
    'Hipotensão arterial, bradicardia, depressão miocárdica; colapso cardiovascular em pacientes hipovolêmicos',
    'Monitorar PA e FC continuamente. Reduzir doses de ambos. Preferir combinação propofol + cetamina (menor risco CV) em pacientes estáveis',
    'Tiopental + Cetamina — Hipotensão por antagonismo cardiovascular',
    EvidenceLevel.probable,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // ── ANESTESIA — LOCAIS ────────────────────────────────────────────────────

  // Bupivacaína
  ('bupivacaina', 'antiarritmicos',
    InteractionSeverity.major,
    'Bupivacaína bloqueia canais de sódio de forma mais intensa e persistente que outros anestésicos locais (bloqueio "fast-in, slow-out"); antiarrítmicos classe I (lidocaína, flecainida, propafenona) também bloqueiam canais de sódio — o bloqueio combinado pode ser fatal em caso de absorção sistêmica de bupivacaína',
    'Cardiotoxicidade grave — bloqueio AV completo, depressão miocárdica grave, TV, FV, paro cardíaco refratário à ressuscitação padrão',
    'Evitar combinação com antiarrítmicos classe I. Em LAST (toxicidade sistêmica de anestésico local) por bupivacaína, usar emulsão lipídica 20% IV imediatamente como antídoto',
    'Bupivacaína + Antiarrítmico Classe I — Cardiotoxicidade sinérgica: ter emulsão lipídica 20% disponível',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('bupivacaina', 'betabloqueador',
    InteractionSeverity.moderate,
    'Betabloqueadores (propranolol, metoprolol) inibem o CYP1A2 e reduzem o metabolismo da bupivacaína; adicionalmente, a cardiotoxicidade de uma sobredose de bupivacaína é mais difícil de tratar em paciente betabloqueado (o coração "bloqueado" não responde a adrenalina)',
    'Concentração plasmática elevada de bupivacaína; em LAST: paro cardíaco mais resistente à ressuscitação',
    'Usar doses mínimas eficazes de bupivacaína. Em paciente betabloqueado, ter emulsão lipídica 20% e glucagon preparados para emergência de LAST',
    'Bupivacaína + Betabloqueador — Toxicidade aumentada e ressuscitação dificultada',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    [_kRefGG]),

  // Prilocaína
  ('prilocaina', 'metemoglobina_indutores',
    InteractionSeverity.major,
    'Prilocaína é metabolizada a o-toluidina, que oxida a hemoglobina a meta-hemoglobina (Fe²⁺ → Fe³⁺), incapaz de transportar O2; outros fármacos que causam meta-hemoglobinemia (nitroprussiato, dapsona, sulfonamidas, nitratos) têm efeito aditivo',
    'Meta-hemoglobinemia grave — cianose refratária a O2 suplementar, dispneia, confusão, coma, morte',
    'Evitar combinação com outros indutores de meta-hemoglobinemia. Em meta-hemoglobinemia grave (> 30%): azul de metileno 1–2 mg/kg IV (antídoto); disponibilizar O2 100%',
    'Prilocaína + Indutores de MetHb — Meta-hemoglobinemia grave: azul de metileno',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('prilocaina', 'sulfonamidas',
    InteractionSeverity.major,
    'Sulfonamidas (sulfametoxazol, dapsona) são indutoras de meta-hemoglobinemia por oxidação da hemoglobina; prilocaína via o-toluidina tem o mesmo mecanismo; a combinação é sinérgica',
    'Meta-hemoglobinemia clínica grave; cianose, dispneia, SpO2 falsamente elevada (co-oximetria necessária)',
    'EVITAR combinação. Usar lidocaína ou outro anestésico local em pacientes usando sulfonamidas',
    'Prilocaína + Sulfonamidas — Meta-hemoglobinemia aditiva: EVITAR',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // Ropivacaína
  ('ropivacaina', 'fluvoxamina',
    InteractionSeverity.major,
    'Ropivacaína é metabolizada principalmente pelo CYP1A2; fluvoxamina (ISRS) é um dos inibidores mais potentes do CYP1A2; a inibição pode elevar a exposição à ropivacaína em 3–7x em infusões contínuas epidurais',
    'Toxicidade sistêmica de ropivacaína — parestesias, convulsões, arritmias, colapso CV em infusões prolongadas',
    'Evitar infusão epidural contínua de ropivacaína em pacientes usando fluvoxamina. Preferir bupivacaína em dose única. Monitorar sinais de toxicidade sistêmica',
    'Ropivacaína + Fluvoxamina — Toxicidade aumentada por inibição CYP1A2',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // ── BNM — BLOQUEADORES NEUROMUSCULARES ───────────────────────────────────

  // Cisatracúrio
  ('cisatracurio', 'aminoglicosideos',
    InteractionSeverity.moderate,
    'Aminoglicosídeos (gentamicina, tobramicina) potenciam o bloqueio neuromuscular não despolarizante por inibição pré-sináptica da liberação de acetilcolina e antagonismo competitivo nos receptores nicotínicos; cisatracúrio tem durações de ação prolongadas com aminoglicosídeos',
    'Bloqueio neuromuscular residual prolongado; fraqueza, hipoventilação, dependência de ventilação mecânica prolongada',
    'Reduzir dose de cisatracúrio em 20–30% em pacientes usando aminoglicosídeos. Monitorar TOF (train-of-four). Ter sugamadex disponível (embora não reverta cisatracúrio — usar neostigmina)',
    'Cisatracúrio + Aminoglicosídeo — Bloqueio NM prolongado: monitorar TOF',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('cisatracurio', 'halogenados',
    InteractionSeverity.moderate,
    'Anestésicos inalatórios halogenados (sevoflurano, isoflurano) potenciam o bloqueio neuromuscular de todos os BNM não despolarizantes, incluindo cisatracúrio, por estabilização da membrana pós-sináptica e redução da sensibilidade do receptor nicotínico',
    'Bloqueio residual pós-operatório; fraqueza e hipoventilação na SRPA',
    'Reduzir dose de cisatracúrio em 30% durante anestesia inalatória. Monitorar TOF. Garantir TOF ratio > 0,9 antes de extubação',
    'Cisatracúrio + Halogenados — Potencia bloqueio: reduzir dose 30%',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // Atracúrio
  ('atracurio', 'aminoglicosideos',
    InteractionSeverity.moderate,
    'Aminoglicosídeos potenciam o bloqueio de atracúrio por mecanismos pré e pós-sinápticos; o atracúrio libera histamina (diferente do cisatracúrio) e os aminoglicosídeos podem potenciar essa liberação levando a hipotensão adicional',
    'Bloqueio NM prolongado; broncoespasmo e hipotensão por liberação de histamina amplificados',
    'Monitorar TOF, PA e SpO2. Preferir cisatracúrio em pacientes hemodinamicamente instáveis (não libera histamina). Ter anti-histamínico disponível',
    'Atracúrio + Aminoglicosídeo — Bloqueio prolongado + risco de hipotensão histaminérgica',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // Pancurônio
  ('pancuronio', 'aminoglicosideos',
    InteractionSeverity.moderate,
    'Aminoglicosídeos potenciam o bloqueio de pancurônio; pancurônio tem longa duração de ação intrínseca e em pacientes com DRC (clearance renal reduzido) o bloqueio pode durar horas',
    'Bloqueio neuromuscular prolongado, paralisia residual, apneia pós-operatória',
    'Evitar pancurônio em insuficiência renal. Monitorar TOF rigorosamente. Ter neostigmina + atropina preparados para reversão',
    'Pancurônio + Aminoglicosídeo — Bloqueio NM prolongado (especialmente em DRC)',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  ('pancuronio', 'halogenados',
    InteractionSeverity.moderate,
    'Halogenados potenciam pancurônio de forma significativa (longa duração + potenciação = risco de curarização residual muito elevado); pancurônio causa taquicardia reflexa que pode ser amplificada pela simpaticomimésia relativa induzida pelos halogenados',
    'Bloqueio residual grave; taquicardia intraoperatória; paralisia pós-operatória prolongada',
    'Monitorar TOF obrigatoriamente. Reduzir dose de pancurônio em 30–40% durante anestesia inalatória. Reverter com neostigmina ao fim da cirurgia',
    'Pancurônio + Halogenados — Bloqueio residual grave: monitorar TOF obrigatório',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  // Neostigmina
  ('neostigmina', 'succinilcolina',
    InteractionSeverity.contraindicated,
    'Neostigmina inibe a acetilcolinesterase, a enzima que também hidrolisa a succinilcolina (além da butirilcolinesterase); ao inibir a acetilcolinesterase, neostigmina prolonga e intensifica dramaticamente o bloqueio despolarizante da succinilcolina — o oposto de reverter',
    'Bloqueio neuromuscular despolarizante profundo e prolongado, paralisia muscular prolongada, apneia, insuficiência respiratória',
    'CONTRAINDICADO. Neostigmina é antagonista dos BNM não despolarizantes, mas POTENCIA a succinilcolina. Nunca usar neostigmina para tentar reverter bloqueio da succinilcolina',
    'Neostigmina + Succinilcolina — CONTRAINDICADO: aprofunda bloqueio despolarizante',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('neostigmina', 'betabloqueador',
    InteractionSeverity.moderate,
    'Neostigmina causa bradicardia pronunciada por aumento da acetilcolina no nó sinusal (efeito muscarínico); betabloqueadores bloqueiam a taquicardia compensatória simpática e potenciam a bradicardia parasssimpática',
    'Bradicardia grave, bloqueio AV, assistolia; especialmente perigoso sem atropina prévia',
    'Sempre pré-tratar com atropina 0,6–1,2 mg IV antes ou junto com neostigmina. Monitorar ECG contínuo. Ter atropina e adrenalina à disposição',
    'Neostigmina + Betabloqueador — Bradicardia grave: pré-tratar com atropina',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefMdx]),

  // Piridostigmina
  ('piridostigmina', 'succinilcolina',
    InteractionSeverity.contraindicated,
    'Piridostigmina inibe a acetilcolinesterase e a butirilcolinesterase (enzima que metaboliza succinilcolina); ao inibir a butirilcolinesterase, prolonga drasticamente o bloqueio despolarizante da succinilcolina de minutos para horas',
    'Bloqueio despolarizante prolongado — paralisia muscular persistente, apneia, necessidade de ventilação mecânica prolongada',
    'CONTRAINDICADO. Pacientes com Miastenia Gravis em uso de piridostigmina têm risco extremo com succinilcolina; usar rocurônio + sugamadex para ISR nesse grupo',
    'Piridostigmina + Succinilcolina — CONTRAINDICADO: paralisia prolongada',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  // Dantroleno
  ('dantroleno', 'bloqueador_canal_calcio',
    InteractionSeverity.contraindicated,
    'Dantroleno inibe o receptor rianodina (RYR1) reduzindo a liberação de Ca²⁺ do retículo sarcoplasmático; antagonistas do cálcio (verapamil, diltiazem) bloqueiam canais de cálcio tipo L na membrana celular; a combinação causa hipercalemia grave e colapso cardiovascular por depressão sinérgica da função miocárdica e condução',
    'Hipercalemia grave — potencialmente fatal; colapso cardiovascular: hipotensão profunda, bloqueio AV, depressão miocárdica severa',
    'CONTRAINDICADO uso concomitante durante crise de HM. Tratar arritmias com amiodarona ou lidocaína (não verapamil). Corrigir hipercalemia com bicarbonato, gluconato de cálcio e insulina/glicose',
    'Dantroleno + Bloqueador de Canal de Cálcio — CONTRAINDICADO: hipercalemia e colapso CV',
    EvidenceLevel.established,
    {RiskType.cardiovascular},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('dantroleno', 'sevoflurano',
    InteractionSeverity.major,
    'Sevoflurano, como todos os halogenados, é um gatilho de Hipertermia Maligna em pacientes susceptíveis; dantroleno é o tratamento — a coadministração indica que a HM já está em curso; a questão clínica é garantir dose suficiente de dantroleno para superar o gatilho ainda em ação',
    'Hipertermia Maligna em evolução — rigidez, hipertermia, rabdomiólise, acidose, CID, óbito',
    'SUSPENDER SEVOFLURANO IMEDIATAMENTE. Dantroleno 2,5 mg/kg IV a cada 5 min até cessar rigidez (máx 10 mg/kg). Trocar para TIVA (propofol). Resfriar paciente ativamente. Bicarbonato, furosemida, insulina/glicose para complicações metabólicas',
    'Dantroleno é o ANTÍDOTO do sevoflurano em HM — suspender halogenado imediatamente',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  // Sugamadex
  ('sugamadex', 'rocurônio',
    InteractionSeverity.moderate,
    'Sugamadex encapsula especificamente rocurônio e vecurônio em sua cavidade hidrofóbica formando complexo 1:1 inativo; a interação é intencional e terapêutica; doses incorretas (insuficientes) podem resultar em reversão incompleta com rebloqueio',
    'Reversão incompleta com bloqueio NM residual se dose inadequada; raramente: reação anafilática ao sugamadex',
    'Dose adequada conforme profundidade do bloqueio: bloqueio leve (TOF ratio 0,2): 2 mg/kg; bloqueio moderado (TOF 1–2): 2 mg/kg; bloqueio profundo (0 respostas TOF): 4 mg/kg; reversão imediata pós-succinilcolina: 16 mg/kg. Monitorar TOF após reversão. Risco de rebloqueio se dose insuficiente',
    'Sugamadex reverte rocurônio/vecurônio — Dose conforme profundidade do bloqueio',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA]),

  ('sugamadex', 'contraceptivo_oral_progestina',
    InteractionSeverity.moderate,
    'Sugamadex pode ligar-se a progestinas (progesterona, levonorgestrel) com baixa afinidade, reduzindo temporariamente sua biodisponibilidade; o efeito é equivalente a uma dose omitida do contraceptivo',
    'Potencial redução da eficácia contraceptiva nas 7 dias após uso de sugamadex',
    'Orientar paciente a usar método contraceptivo de barreira adicional por 7 dias após uso de sugamadex. Incluir na nota anestésica',
    'Sugamadex + Contraceptivo com Progestina — Método barreira por 7 dias',
    EvidenceLevel.established,
    {RiskType.plasmaLevel},
    [_kRefGG, _kRefFDA]),

  // ── CARDIOVASCULAR / ANTICOAGULAÇÃO ──────────────────────────────────────

  // Argatrobana
  ('argatrobana', 'warfarina',
    InteractionSeverity.major,
    'Argatrobana (inibidor direto da trombina) eleva artificialmente o INR quando medido em pacientes em transição para varfarina; o INR combinado não reflete apenas a atividade da varfarina mas também o efeito antitrombínico da argatrobana, podendo superestimar a anticoagulação pela varfarina em até 2–4x',
    'Superestimação do INR levando a interrupção prematura da argatrobana com risco de trombose (HIT); ou manutenção excessiva resultando em sangramento',
    'Protocolo específico para transição: suspender argatrobana quando INR combinado > 4; checar INR isolado 4–6h após suspensão. Alvo INR de varfarina ≥ 2 em pelo menos 2 medições sem argatrobana',
    'Argatrobana + Varfarina — Protocolo especial de transição (INR superestimado)',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('argatrobana', 'heparina',
    InteractionSeverity.major,
    'Argatrobana é usada para substituir heparina em pacientes com HIT (trombocitopenia induzida por heparina); o uso simultâneo de ambas é desnecessário e aumenta dramaticamente o risco de sangramento por anticoagulação dupla',
    'Hemorragia grave — sangramento interno, hemorragia intracraniana, hematoma retroperitoneal',
    'SUBSTITUIR heparina por argatrobana, não associar. Aguardar washout de heparina antes de iniciar argatrobana. Monitorar TTPa a cada 2–4h nas primeiras 24h',
    'Argatrobana substitui heparina em HIT — Não usar simultaneamente',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefFDA]),

  ('argatrobana', 'trombolítico',
    InteractionSeverity.contraindicated,
    'Argatrobana (anticoagulante) associado a trombolíticos (alteplase, estreptoquinase) resulta em anticoagulação excessiva com dissolução ativa de coágulos — risco de hemorragia catastrófica',
    'Hemorragia intracraniana, hemorragia retroperitoneal, sangramento GI maciço, potencialmente fatal',
    'CONTRAINDICADO uso simultâneo. Se trombolítico necessário, suspender argatrobana. Monitorar rigorosamente após decisão de trombolítico',
    'Argatrobana + Trombolítico — CONTRAINDICADO: hemorragia catastrófica',
    EvidenceLevel.established,
    {RiskType.hemorrhagic},
    [_kRefGG, _kRefFDA]),

  // Minoxidil
  ('minoxidil', 'anti_hipertensivo',
    InteractionSeverity.major,
    'Minoxidil oral causa vasodilatação arterial potente com redução reflexa da PA; combinado com outros anti-hipertensivos (diuréticos, betabloqueadores, IECA, BRA, antagonistas de cálcio) o efeito hipotensor é aditivo e pode ser extremo; minoxidil quase sempre requer betabloqueador associado para controlar taquicardia reflexa',
    'Hipotensão grave ortostática e de repouso, síncope, pré-síncope; taquicardia reflexa intensa se sem betabloqueador',
    'Iniciar minoxidil sempre com betabloqueador para controlar taquicardia. Titular doses lentamente. Monitorar PA sentada, em pé e deitado nas primeiras semanas',
    'Minoxidil + Anti-hipertensivos — Hipotensão aditiva grave: betabloqueador obrigatório',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefMdx]),

  ('minoxidil', 'guanetidina',
    InteractionSeverity.contraindicated,
    'Ambos causam hipotensão ortostática grave por mecanismos complementares: minoxidil por vasodilatação direta e guanetidina por depleção de noradrenalina nos terminais simpáticos; sem reserva simpática para compensar a vasodilatação do minoxidil',
    'Hipotensão ortostática severa com síncope; risco de quedas, fraturas, eventos cerebrovasculares',
    'CONTRAINDICADO. Substituir guanetidina por outro agente antes de iniciar minoxidil',
    'Minoxidil + Guanetidina — CONTRAINDICADO: hipotensão ortostática grave',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG]),

  // Terazosina
  ('terazosina', 'sildenafil',
    InteractionSeverity.contraindicated,
    'Terazosina (alfa1-bloqueador) e inibidores de PDE5 (sildenafil, tadalafil, vardenafil) ambos causam vasodilatação; a combinação produz hipotensão aditiva grave, especialmente na primeira dose ou após atividade sexual',
    'Hipotensão grave, síncope, colapso cardiovascular; risco de infarto do miocárdio em pacientes com DAC',
    'CONTRAINDICADO sildenafil com terazosina. Se PDE5i necessário, substituir terazosina por tansulosina (mais seletiva para próstata, menor hipotensão sistêmica). Se mantida terazosina, usar tadalafil 5 mg/dia com intervalo mínimo de 4h',
    'Terazosina + Sildenafil — CONTRAINDICADO: hipotensão grave e síncope',
    EvidenceLevel.established,
    {RiskType.increasedToxicity},
    [_kRefGG, _kRefFDA, _kRefMdx]),

  ('terazosina', 'verapamil',
    InteractionSeverity.major,
    'Terazosina (alfa1-bloqueador) e verapamil (bloqueador de canal de cálcio não-diidropiridínico) têm efeitos hipotensores e cronotrópicos negativos que se somam; verapamil também inibe CYP3A4 que metaboliza terazosina',
    'Hipotensão grave, bradicardia, bloqueio AV, síncope',
    'Iniciar terazosina com dose muito reduzida (1 mg) em pacientes usando verapamil. Monitorar PA e FC diariamente na primeira semana',
    'Terazosina + Verapamil — Hipotensão e bradicardia aditivas graves',
    EvidenceLevel.probable,
    {RiskType.cardiovascular},
    [_kRefGG]),

  // 300 — Idarucizumabe (anticorpo) + Dabigatrana (reversão)
  ('idarucizumabe', 'dabigatrana',
    InteractionSeverity.major,
    'Idarucizumabe (Praxbind) é um anticorpo monoclonal fragmento Fab que se liga à dabigatrana com afinidade 350x maior que a trombina, revertendo completamente seu efecto anticoagulante em minutos; a interacción é intencional e terapéutica; a reversão é imediata e dura pelo menos 24 horas; después de a reversão, a dabigatrana livre no plasma é eliminada mas reservatórios teciduais podem liberar dabigatrana com rebote do efecto anticoagulante',
    'Ausência de efecto después de administração: posible se dabigatranemia muito alta (sobredosis) ou fatores interferentes; rebote anticoagulante em 12–24h por redistribuição do compartimento tecidual; trombosis por reversão excessiva en pacientes com alto riesgo trombótico',
    'Dosis padrão: 5 g IV (2 frascos de 2,5 g) em infusão rápida ou bolus. Monitorar TT (tempo de trombina) ou TCE (teste de coagulação por ecarina) para confirmar reversão. Se rebote suspeito: segunda dosis de idarucizumabe. Reiniciar anticoagulação assim que posible después de hemostasia cirúrgica ou controle do sangrado',
    'Reversão de emergência — Idarucizumabe reverte dabigatrana: monitorar rebote em 12–24h',
    EvidenceLevel.established,
    {RiskType.hemorrhagic, RiskType.thrombosis},
    [_kRefFDA, _kRefGG, _kRefUT]),


];


const _termMap = <String, String>{
  // Anticoagulantes
'warfarina': 'warfarina', 'varfarina': 'warfarina', 'coumadin': 'warfarina',
'marevan': 'warfarina', 'warfarin': 'warfarina',
'heparina': 'heparina', 'enoxaparina': 'heparina', 'clexane': 'heparina',
'alisquireno': 'alisquireno', 'rasilez': 'alisquireno',

  // Antiagregantes
'aspirina': 'aspirina', 'aas': 'aspirina', 'ácido acetilsalicílico': 'aspirina',
'acido acetilsalicilico': 'aspirina', 'aspirin': 'aspirina',

  // AINEs
'ibuprofeno': 'ibuprofeno', 'advil': 'ibuprofeno', 'ibuprofen': 'ibuprofeno',
'naproxeno': 'naproxeno', 'naprosyn': 'naproxeno', 'naproxen': 'naproxeno',
'cetorolaco': 'cetorolaco', 'ketorolac': 'cetorolaco', 'toradol': 'cetorolaco',
'diclofenaco': 'aine', 'voltaren': 'aine', 'aine': 'aine', 'nsaid': 'aine',
'nimesulida': 'aine', 'meloxicam': 'aine', 'piroxicam': 'aine',
'indometacina': 'aine', 'celecoxib': 'aine', 'etoricoxib': 'aine',

  // Estatinas
'sinvastatina': 'sinvastatina', 'zocor': 'sinvastatina', 'simvastatina': 'sinvastatina',
'atorvastatina': 'atorvastatina', 'lipitor': 'atorvastatina', 'atorvastatin': 'atorvastatina',
'estatina': 'estatina',
'gemfibrozil': 'gemfibrozil', 'lopid': 'gemfibrozil',

  // Anti-hipertensivos
'enalapril': 'enalapril', 'renitec': 'enalapril', 'vasotec': 'enalapril',
'ramipril': 'enalapril', 'captopril': 'enalapril', 'lisinopril': 'enalapril',
'ieca': 'enalapril', 'perindopril': 'enalapril',
'losartana': 'losartana', 'cozaar': 'losartana', 'valsartana': 'losartana',
'olmesartana': 'losartana', 'ara-ii': 'losartana', 'irbesartana': 'losartana',
'telmisartana': 'losartana', 'micardis': 'losartana', 'candesartana': 'losartana',
'atacand': 'losartana', 'azilsartana': 'losartana', 'eprosartana': 'losartana',
'losartan': 'losartana', 'valsartan': 'losartana', 'olmesartan': 'losartana',
'irbesartan': 'losartana', 'telmisartan': 'losartana', 'candesartan': 'losartana',
'ara2': 'losartana', 'sartana': 'losartana', 'sartan': 'losartana',
'espironolactona': 'espironolactona', 'aldactone': 'espironolactona',
'furosemida': 'furosemida', 'lasix': 'furosemida',
'clonidina': 'clonidina', 'atensina': 'clonidina',

  // Betabloqueadores
'metoprolol': 'metoprolol', 'seloken': 'metoprolol', 'lopressor': 'metoprolol',
'atenolol': 'metoprolol', 'propranolol': 'propranolol', 'inderal': 'propranolol',
'carvedilol': 'metoprolol', 'bisoprolol': 'metoprolol', 'betabloqueador': 'metoprolol',

  // Bloqueadores dos canais de cálcio
'verapamil': 'verapamil', 'isoptin': 'verapamil',
'diltiazem': 'diltiazem', 'cardizem': 'diltiazem',

  // Antiarrítmicos
'amiodarona': 'amiodarona', 'cordarone': 'amiodarona',
'sotalol': 'sotalol', 'betapace': 'sotalol',
'digoxina': 'digoxina', 'lanoxin': 'digoxina',

  // Antibióticos
'metronidazol': 'metronidazol', 'flagyl': 'metronidazol',
'ciprofloxacino': 'ciprofloxacino', 'cipro': 'ciprofloxacino', 'ciprofloxacin': 'ciprofloxacino',
'levofloxacino': 'quinolona', 'levofloxacin': 'quinolona', 'quinolona': 'quinolona',
'claritromicina': 'claritromicina', 'klaricid': 'claritromicina', 'clarithromycin': 'claritromicina',
'eritromicina': 'eritromicina', 'erythromycin': 'eritromicina',
'azitromicina': 'azitromicina', 'zithromax': 'azitromicina',
'rifampicina': 'rifampicina', 'rifampin': 'rifampicina',
'gentamicina': 'aminoglicosideo', 'amicacina': 'aminoglicosideo', 'tobramicina': 'aminoglicosideo',
'aminoglicosídeo': 'aminoglicosideo',

  // Antifúngicos
'fluconazol': 'fluconazol', 'diflucan': 'fluconazol',

  // Antiepilépticos
'fenitoína': 'fenitoína', 'fenitoin': 'fenitoína',
'carbamazepina': 'carbamazepina', 'tegretol': 'carbamazepina',
'acido valproico': 'valproato', 'ácido valpróico': 'valproato',
'ácido valproico': 'valproato', 'valproico': 'valproato',
'valproato': 'valproato', 'depakote': 'valproato', 'depakene': 'valproato',
'divalproex': 'valproato', 'epival': 'valproato', 'stavzor': 'valproato',
'lamotrigina': 'lamotrigina', 'lamictal': 'lamotrigina',

  // Psicotrópicos
'tramadol': 'tramadol', 'tramal': 'tramadol',
'morfina': 'morfina', 'meperidina': 'opioide', 'codeína': 'opioide',
'fentanila': 'fentanila', 'oxicodona': 'opioide', 'opioide': 'opioide',
'benzodiazepínico': 'benzodiazepínico', 'diazepam': 'benzodiazepínico',
'lorazepam': 'benzodiazepínico', 'alprazolam': 'benzodiazepínico',
'clonazepam': 'benzodiazepínico', 'rivotril': 'benzodiazepínico',
'bromazepam': 'benzodiazepínico', 'lexotan': 'benzodiazepínico',
'nitrazepam': 'benzodiazepínico', 'triazolam': 'benzodiazepínico',
  // midazolam tem IDs diretos no banco → ID canônico próprio (NÃO benzodiazepínico)
'midazolam': 'midazolam', 'dormicum': 'midazolam', 'versed': 'midazolam',
'haloperidol': 'haloperidol', 'haldol': 'haloperidol',
'quetiapina': 'quetiapina', 'seroquel': 'quetiapina',
'ssri': 'isrs', 'isrs': 'isrs',
'fluoxetina': 'fluoxetina', 'prozac': 'fluoxetina', 'sertralina': 'isrs', 'zoloft': 'isrs',
'escitalopram': 'isrs', 'lexapro': 'isrs', 'paroxetina': 'isrs', 'paxil': 'isrs',
'citalopram': 'isrs', 'celexa': 'isrs', 'fluvoxamina': 'isrs', 'luvox': 'isrs',
'venlafaxina': 'isrs', 'effexor': 'isrs',
'imao': 'imao', 'fenelzina': 'imao', 'tranilcipromina': 'imao',
'linezolida': 'linezolida', 'linezolid': 'linezolida', 'zyvox': 'linezolida',
'amitriptilina': 'amitriptilina', 'laroxyl': 'amitriptilina', 'tryptanol': 'amitriptilina',
'atropina': 'atropina',
'litio': 'carbonato de litio', 'lítio': 'carbonato de litio',
'carbonato de litio': 'carbonato de litio',

  // Hipoglucemiantes
'metformina': 'metformina', 'glifage': 'metformina', 'glucoformin': 'metformina',
'glibenclamida': 'glibenclamida', 'daonil': 'glibenclamida',
'insulina': 'insulina',
'dapagliflozina': 'dapagliflozina', 'forxiga': 'dapagliflozina',
'empagliflozina': 'dapagliflozina', 'jardiance': 'dapagliflozina',
'contraste': 'contraste iodado', 'contraste iodado': 'contraste iodado',

  // Inmunosupresores / Gota
'ciclosporina': 'ciclosporina', 'neoral': 'ciclosporina', 'sandimmun': 'ciclosporina',
'alopurinol': 'alopurinol', 'zyloric': 'alopurinol',
'azatioprina': 'azatioprina', 'imuran': 'azatioprina',
'colchicina': 'colchicina', 'colchis': 'colchicina',

  // Cardiovascular misc.
'sildenafila': 'sildenafila', 'viagra': 'sildenafila', 'sildenafil': 'sildenafila',
'tadalafila': 'sildenafila', 'cialis': 'sildenafila',
'nitrato': 'nitrato', 'nitroglicerina': 'nitrato', 'isossorbida': 'nitrato',
'mononitrato': 'nitrato', 'dinitrato': 'nitrato',
'sacubitrila': 'sacubitrila', 'sacubitril': 'sacubitrila', 'entresto': 'sacubitrila',
'alfa-bloqueador': 'alfa-bloqueador', 'doxazosina': 'alfa-bloqueador',
'tansulosina': 'alfa-bloqueador', 'prazosina': 'alfa-bloqueador',
'teofilina': 'teofilina', 'aminofilina': 'teofilina',
'ondansetrona': 'ondansetrona', 'zofran': 'ondansetrona',
'clopidogrel': 'clopidogrel', 'plavix': 'clopidogrel',

  // Tireóide
'levotiroxina': 'levotiroxina', 'synthroid': 'levotiroxina', 'puran': 'levotiroxina',
'euthyrox': 'levotiroxina',

  // Suplementos / Quelantes
'carbonato de calcio': 'carbonato de calcio', 'cálcio': 'carbonato de calcio',
'calcio': 'carbonato de calcio', 'calcium': 'carbonato de calcio',
'sulfato ferroso': 'sulfato ferroso', 'ferro': 'sulfato ferroso',
'cloreto de potassio': 'cloreto de potassio', 'kcl': 'cloreto de potassio',
'potassio': 'cloreto de potassio',

  // Corticosteroides
'dexametasona': 'dexametasona', 'decadron': 'dexametasona',
'prednisona': 'dexametasona', 'prednisolona': 'dexametasona',
'hidrocortisona': 'dexametasona',

  // Diuréticos
'hidroclorotiazida': 'hidroclorotiazida', 'hctz': 'hidroclorotiazida',
'clortalidona': 'hidroclorotiazida',

  // Anticoncepcionais
'anticonceptivo': 'anticonceptivo', 'anticoncepcional': 'anticonceptivo',
'pilula': 'anticonceptivo', 'pílula': 'anticonceptivo',
'etinilestradiol': 'anticonceptivo', 'levonorgestrel': 'anticonceptivo',

  // Vancomicina
'vancomicina': 'vancomicina', 'vancocin': 'vancomicina',

  // Outros
'antiácido': 'antiácido', 'hidróxido': 'antiácido',
'omeprazol': 'omeprazol', 'losec': 'omeprazol',
'pantoprazol': 'pantoprazol', 'pantozol': 'pantoprazol', 'tecta': 'pantoprazol',
'esomeprazol': 'esomeprazol', 'nexium': 'esomeprazol',
'álcool': 'alcool', 'alcool': 'alcool', 'bebida': 'alcool',
'gemfibrozila': 'gemfibrozil',

  // ── NOVOS — Merge v2 ───────────────────────────────────────────────────────

  // Antiarrítmicos novos
'dronedarona': 'dronedarona', 'multaq': 'dronedarona',
'ivabradina': 'ivabradina', 'procoralan': 'ivabradina', 'corlanor': 'ivabradina',
'ranolazina': 'ranolazina', 'ranexa': 'ranolazina',

  // Anti-hipertensivos novos
'eplerenona': 'eplerenona', 'inspra': 'eplerenona',
'candesartán': 'losartana',
'riociguate': 'riociguate', 'adempas': 'riociguate',

  // Anticoagulantes / antídotos
'fondaparinux': 'fondaparinux', 'arixtra': 'fondaparinux',
'andexanet': 'andexanet alfa', 'ondexxya': 'andexanet alfa', 'andexanet alfa': 'andexanet alfa',
'idarucizumabe': 'idarucizumabe', 'praxbind': 'idarucizumabe',

  // Antibióticos novos
'daptomicina': 'daptomicina', 'cubicin': 'daptomicina',
'ceftarolina': 'ceftarolina', 'zinforo': 'ceftarolina', 'teflaro': 'ceftarolina',
'tedizolida': 'tedizolida', 'sivextro': 'tedizolida',
'cefiderocol': 'cefiderocol', 'fetcroja': 'cefiderocol',
'sulfametoxazol trimetoprima iv': 'sulfametoxazol_tmp_iv',
'smx-tmp iv': 'sulfametoxazol_tmp_iv', 'bactrim iv': 'sulfametoxazol_tmp_iv',

  // Antivirais COVID-19
'nirmatrelvir': 'ritonavir', 'paxlovid': 'ritonavir',
'nirmatrelvir ritonavir': 'ritonavir',
'ritonavir': 'ritonavir', 'norvir': 'ritonavir',
'molnupiravir': 'molnupiravir', 'lagevrio': 'molnupiravir',

  // Antifúngicos novos
'isavuconazol': 'isavuconazol', 'cresemba': 'isavuconazol',
'isavuconazonium': 'isavuconazol',

  // Antiepilépticos novos
'perampanel': 'perampanel', 'fycompa': 'perampanel',
'brivaracetam': 'brivaracetam', 'briviact': 'brivaracetam',

  // Antipsicóticos novos
'aripiprazol': 'aripiprazol', 'abilify': 'aripiprazol', 'aripiprazole': 'aripiprazol',

  // Antidepresivos / TDAH
'bupropiona': 'bupropiona', 'wellbutrin': 'bupropiona', 'zyban': 'bupropiona',
'bupropion': 'bupropiona',
'lisdexanfetamina': 'lisdexanfetamina', 'vyvanse': 'lisdexanfetamina',

  // Hipoglucemiantes / Obesidade novos
'semaglutida': 'semaglutida', 'ozempic': 'semaglutida', 'wegovy': 'semaglutida',
'rybelsus': 'semaglutida', 'semaglutide': 'semaglutida',
'tirzepatida': 'tirzepatida', 'mounjaro': 'tirzepatida', 'zepbound': 'tirzepatida',
'tirzepatide': 'tirzepatida',
'dulaglutida': 'semaglutida', 'trulicity': 'semaglutida', 'dulaglutide': 'semaglutida',
'canagliflozina': 'canagliflozina', 'invokana': 'canagliflozina',
'finerenona': 'finerenona', 'kerendia': 'finerenona',
'sulfonilureia': 'sulfonilureia', 'glipizida': 'sulfonilureia',
'glimepirida': 'sulfonilureia', 'gliclazida': 'sulfonilureia',

  // Antiosteoporose
'denosumabe': 'denosumabe', 'prolia': 'denosumabe', 'xgeva': 'denosumabe',
'denosumab': 'denosumabe',

  // DII / Reumatologia
'vedolizumabe': 'vedolizumabe', 'entyvio': 'vedolizumabe', 'vedolizumab': 'vedolizumabe',
'natalizumabe': 'natalizumabe', 'tysabri': 'natalizumabe',
'tofacitinibe': 'tofacitinibe', 'xeljanz': 'tofacitinibe', 'tofacitinib': 'tofacitinibe',

  // Gastro
'rifaximina': 'rifaximina', 'xifaxan': 'rifaximina', 'rifaximin': 'rifaximina',

  // Respiratório / Biológicos
'dupilumabe': 'dupilumabe', 'dupixent': 'dupilumabe', 'dupilumab': 'dupilumabe',
'mepolizumabe': 'mepolizumabe', 'nucala': 'mepolizumabe', 'mepolizumab': 'mepolizumabe',
'nintedanibe': 'nintedanibe', 'ofev': 'nintedanibe', 'nintedanib': 'nintedanibe',
'corticosteroide sistemico': 'corticosteroide sistemico',
'prednisona sistemica': 'corticosteroide sistemico',
'prednisolona sistemica': 'corticosteroide sistemico',

  // Hematologia
'ruxolitinibe': 'ruxolitinibe', 'jakafi': 'ruxolitinibe', 'jakavi': 'ruxolitinibe',
'ruxolitinib': 'ruxolitinibe',
'eltrombopague': 'eltrombopague', 'revolade': 'eltrombopague', 'promacta': 'eltrombopague',
'eltrombopag': 'eltrombopague',

  // Biológicos / Imunológicos
'tocilizumabe': 'tocilizumabe', 'actemra': 'tocilizumabe', 'tocilizumab': 'tocilizumabe',
'baricitinibe': 'baricitinibe', 'olumiant': 'baricitinibe', 'baricitinib': 'baricitinibe',
'belimumabe': 'belimumabe', 'benlysta': 'belimumabe', 'belimumab': 'belimumabe',

  // Vacinas (genérico para interacciones com inmunosupresores)
'vacinas vivas': 'vacinas vivas', 'vacina viva': 'vacinas vivas',
'mmr': 'vacinas vivas', 'febre amarela': 'vacinas vivas',
'varicela vacina': 'vacinas vivas', 'bcg': 'vacinas vivas',

  // ── Lote 3 — novos fármacos ───────────────────────────────────────────────

  // Cardiovascular — estatinas (novos aliases; atorvastatina/lipitor já existem acima)
'torvacard': 'atorvastatina',

  // Cardiovascular — diuréticos (clortalidona/hidroclorotiazida/hctz já existem acima)
'clortalidone': 'hidroclorotiazida', 'hidrodiuril': 'hidroclorotiazida',

  // Cardiovascular — anti-hipertensivos (clonidina/atensina/isossorbida/nitrato já existem)
'clonidine': 'clonidina',
'monoísordil': 'nitrato', 'isordil': 'nitrato',
'dinitrato de isossorbida': 'nitrato', 'mononitrato de isossorbida': 'nitrato',
'labetalol': 'labetalol', 'trandate': 'labetalol',

  // Cardiovascular — bloqueadores de canal de cálcio (verapamil/isoptin/diltiazem/cardizem já existem)
'verapamilo': 'verapamil', 'balcor': 'diltiazem',

  // Cardiovascular — inotrópicos/vasoativos
'levosimendan': 'levosimendan', 'simdax': 'levosimendan',
'milrinona': 'milrinona', 'primacor': 'milrinona',
'esmolol': 'esmolol', 'brevibloc': 'esmolol',
'nitroprussiato': 'nitroprussiato', 'nipride': 'nitroprussiato',
'nitroprussiato de sódio': 'nitroprussiato',

  // Neurologia / Antiepilépticos (fenitoína/fenitoin/lamotrigina/lamictal já existem acima)
'gabapentina': 'gabapentina', 'neurontin': 'gabapentina', 'gabapentin': 'gabapentina',
'gabatina': 'gabapentina', 'gabaneurin': 'gabapentina',
'fenobarbital': 'fenobarbital', 'gardenal': 'fenobarbital', 'phenobarbital': 'fenobarbital',
'hidantal': 'fenitoína', 'phenytoin': 'fenitoína', 'dilantin': 'fenitoína',
'lamotrigine': 'lamotrigina',
'topiramato': 'topiramato', 'topamax': 'topiramato', 'topiramate': 'topiramato',
'acetazolamida': 'acetazolamida', 'diamox': 'acetazolamida', 'acetazolamide': 'acetazolamida',

  // Psiquiatria / Antidepresivos (sertralina já mapeada como ssri acima)
'sertraline': 'isrs', 'serenata': 'isrs', 'venlafaxine': 'isrs',
'paroxetine': 'isrs', 'fluvoxamine': 'isrs', 'citaloprame': 'isrs',
'mirtazapina': 'mirtazapina', 'remeron': 'mirtazapina', 'mirtazapine': 'mirtazapina',
'zolvera': 'mirtazapina',

  // Psiquiatria / Antipsicóticos
'olanzapina': 'olanzapina', 'zyprexa': 'olanzapina', 'olanzapine': 'olanzapina',
'zydis': 'olanzapina',

  // Psiquiatria / Ansiolíticos (clonazepam e rivotril já mapeados acima)
'zolpidem': 'benzodiazepínico', 'stilnox': 'benzodiazepínico', 'zolpidem tartarato': 'benzodiazepínico',

  // Anestesia / UTI (fentanila já mapeada como opioide acima)
'propofol': 'propofol', 'diprivan': 'propofol',
'fentanil': 'opioide', 'duragesic': 'opioide',
'dexmedetomidina': 'dexmedetomidina', 'precedex': 'dexmedetomidina', 'dexmedetomidine': 'dexmedetomidina',
'rocurônio': 'rocurônio', 'esmeron': 'rocurônio', 'rocuronium': 'rocurônio',
'naloxona': 'naloxona', 'narcan': 'naloxona', 'naloxone': 'naloxona',
'lidocaína': 'lidocaína', 'xylocaine': 'lidocaína', 'xylestesin': 'lidocaína',
'lidocaine': 'lidocaína',

  // Infectologia (amicacina já mapeada como aminoglicosideo acima)
'tigeciclina': 'tigeciclina', 'tygacil': 'tigeciclina', 'tigecycline': 'tigeciclina',
'fosfomicina': 'fosfomicina', 'monurol': 'fosfomicina', 'fosfocin': 'fosfomicina',
'fosfomycin': 'fosfomicina',
'valaciclovir': 'valaciclovir', 'valtrex': 'valaciclovir', 'valacyclovir': 'valaciclovir',
'amikin': 'aminoglicosideo', 'amikacin': 'aminoglicosideo',
'ceftolozana': 'ceftolozana', 'zerbaxa': 'ceftolozana',
'ceftolozana tazobactam': 'ceftolozana', 'ceftolozane': 'ceftolozana',

  // Antifúngicos (fluconazol/diflucan já mapeados acima)
'fluconazole': 'fluconazol', 'zoltec': 'fluconazol',

  // Endocrinologia / Hipoglucemiantes (glibenclamida/daonil já mapeados acima)
'glyburide': 'glibenclamida', 'diabeta': 'glibenclamida',

  // Gastroenterologia
'racecadotril': 'racecadotril', 'tiorfan': 'racecadotril', 'hidrasec': 'racecadotril',
'levosulpirida': 'levosulpirida', 'levopraid': 'levosulpirida',
'simeticona': 'simeticona', 'luftal': 'simeticona', 'mylicon': 'simeticona',
'dimeticona': 'simeticona',

  // Hematologia / Vitaminas
'etamsilato': 'etamsilato', 'dicynone': 'etamsilato', 'etamsylate': 'etamsilato',
'tiamina': 'tiamina', 'vitamina b1': 'tiamina', 'benerva': 'tiamina',
'thiamine': 'tiamina',
'piridoxina': 'piridoxina', 'vitamina b6': 'piridoxina', 'pyridoxine': 'piridoxina',

  // Respiratório / Mucolíticos
'ambroxol': 'ambroxol', 'mucosolvan': 'ambroxol', 'ambroxol hcl': 'ambroxol',
'acebrofilina': 'acebrofilina', 'bronchoton': 'acebrofilina',
'salbutamol': 'salbutamol', 'ventolin': 'salbutamol', 'albuterol': 'salbutamol',
'aerolin': 'salbutamol', 'salbutamol gotas': 'salbutamol',

  // Dermatologia / Tópicos
'sulfadiazina de prata': 'sulfadiazina de prata', 'silverex': 'sulfadiazina de prata',
'sulfadiazina': 'sulfadiazina de prata',
'mupirocina': 'mupirocina', 'bactroban': 'mupirocina', 'mupirocin': 'mupirocina',
'permetrina': 'permetrina', 'keltrina': 'permetrina', 'permethrin': 'permetrina',
'clobetasol': 'clobetasol', 'temovate': 'clobetasol', 'clobetasol propionato': 'clobetasol',
'fexofenadina': 'fexofenadina', 'allegra': 'fexofenadina', 'fexofenadine': 'fexofenadina',

  // Analgesia
'clonixinato': 'clonixinato', 'dorilax': 'clonixinato', 'clonixin': 'clonixinato',
'clonixinato de lisina': 'clonixinato',

  // Nefrologia
'kayexalate': 'kayexalate', 'poliestireno sulfonato': 'kayexalate',
'resina de troca iônica': 'kayexalate', 'sorcal': 'kayexalate',

  // ── Auditoria Lote 4 — aliases novos ──────────────────────────────────────

  // AOD — anticoagulantes orais diretos
'apixabana': 'apixabana', 'eliquis': 'apixabana', 'apixaban': 'apixabana',
'rivaroxabana': 'rivaroxabana', 'xarelto': 'rivaroxabana', 'rivaroxaban': 'rivaroxabana',
'dabigatrana': 'dabigatrana', 'pradaxa': 'dabigatrana', 'dabigatran': 'dabigatrana',
'edoxabana': 'apixabana', 'lixiana': 'apixabana', 'edoxaban': 'apixabana',
'aod': 'apixabana', 'noac': 'apixabana', 'doac': 'apixabana',

  // Inmunosupresores — tacrolimo / FK506
'tacrolimo': 'tacrolimo', 'prograf': 'tacrolimo', 'tacrolimus': 'tacrolimo',
'fk506': 'tacrolimo', 'advagraf': 'tacrolimo', 'envarsus': 'tacrolimo',

  // Opioides — metadona
'metadona': 'metadona', 'methadone': 'metadona', 'metadon': 'metadona',
'dolophine': 'metadona',

  // Antibióticos — sulfametoxazol-trimetoprima
'sulfametoxazol': 'sulfametoxazol', 'smx-tmp': 'sulfametoxazol',
'sulfametoxazol trimetoprima': 'sulfametoxazol', 'trimetoprima': 'sulfametoxazol',
'cotrimoxazol': 'sulfametoxazol', 'bactrim': 'sulfametoxazol',
'septra': 'sulfametoxazol', 'trimethoprim': 'sulfametoxazol',
'tmp-smx': 'sulfametoxazol', 'smz-tmp': 'sulfametoxazol',

  // Analgésicos — paracetamol / acetaminofeno
'paracetamol': 'paracetamol', 'acetaminofeno': 'paracetamol', 'tylenol': 'paracetamol',
'acetaminophen': 'paracetamol', 'acetaminofen': 'paracetamol',
'dipirona': 'paracetamol', 'novalgina': 'paracetamol', 'metamizol': 'paracetamol',

  // Antibióticos — piperacilina-tazobactam
'piperacilina_tazobactam': 'piperacilina-tazobactam',
'piperacilina-tazobactam': 'piperacilina-tazobactam',
'piperacilina tazobactam': 'piperacilina-tazobactam',
'pip-tazo': 'piperacilina-tazobactam', 'tazocin': 'piperacilina-tazobactam',
'zosyn': 'piperacilina-tazobactam', 'tazobac': 'piperacilina-tazobactam',

  // Quimioterapia — cisplatina
'cisplatina': 'cisplatina', 'cisplatin': 'cisplatina', 'platinol': 'cisplatina',

  // Estatinas — rosuvastatina
'rosuvastatina': 'rosuvastatina', 'rosuvastatin': 'rosuvastatina',
'vivacor': 'rosuvastatina', 'rosuvas': 'rosuvastatina', 'crestor': 'rosuvastatina', 'ezallor': 'rosuvastatina',

  // Fibratos
'fenofibrato': 'fenofibrato', 'tricor': 'fenofibrato', 'lipanthyl': 'fenofibrato',
'fenofibrate': 'fenofibrato', 'triglide': 'fenofibrato',

  // IMAO reversível (moclobemida)
'imao_reversivel': 'imao reversivel', 'imao reversivel': 'imao reversivel',
'moclobemida': 'imao reversivel', 'aurorix': 'imao reversivel',
'moclobemide': 'imao reversivel', 'inhibidor mao reversivel': 'imao reversivel',
'rima': 'imao reversivel',

  // Lítio — aliases adicionais (ID canônico: 'carbonato de litio')
'li': 'carbonato de litio', 'lithium': 'carbonato de litio',
'quilonorm': 'carbonato de litio', 'carbolithium': 'carbonato de litio',
'litiocar': 'carbonato de litio',

  // (valproato e betabloqueador já mapeados acima — sem duplicatas)

  // ── Lote 6 — Mucolíticos, Antitussivos e Gripe ────────────────────────────

  // Mucolíticos
'bromhexina': 'bromhexina', 'bisolvon': 'bromhexina', 'bromhexine': 'bromhexina',
'carbocisteina': 'carbocisteina', 'carbocisteína': 'carbocisteina',
'mucosol': 'carbocisteina', 'rhinathiol': 'carbocisteina',
'guaifenesina': 'guaifenesina', 'guaifenesin': 'guaifenesina',
'robitussin': 'guaifenesina', 'guaiacolato': 'guaifenesina',

  // Antitussivos
'dextrometorfano': 'dextrometorfano', 'dextromethorphan': 'dextrometorfano',
'dxm': 'dextrometorfano', 'robitussin dm': 'dextrometorfano',
'levodropropizina': 'levodropropizina', 'antuss': 'levodropropizina',
'cloperastina': 'cloperastina', 'seki': 'cloperastina', 'cloperastine': 'cloperastina',
'butamirato': 'butamirato', 'sinecod': 'butamirato', 'butamirate': 'butamirato',

  // Descongestionantes
'pseudoefedrina': 'pseudoefedrina', 'sudafed': 'pseudoefedrina',
'pseudoephedrine': 'pseudoefedrina', 'afrinol': 'pseudoefedrina',
'fenilefrina': 'fenilefrina', 'sudafed pe': 'fenilefrina',
'phenylephrine': 'fenilefrina', 'neo-synephrine': 'fenilefrina',

  // Anti-histamínicos
'cetirizina': 'cetirizina', 'zyrtec': 'cetirizina', 'cetirizine': 'cetirizina',
'reactine': 'cetirizina', 'cetizine': 'cetirizina',

  // Antiviral gripe
'zanamivir': 'zanamivir', 'relenza': 'zanamivir', 'zanamivir inalado': 'zanamivir',

  // Antagonista leucotrienos
'montelukast': 'montelukast', 'singulair': 'montelukast', 'montelukaste': 'montelukast',
'airon': 'montelukast',

  // ── Lote 5 — aliases para os 159 novos pares ──────────────────────────────

  // Antiagregantes — ticagrelor
'ticagrelor': 'ticagrelor', 'brilinta': 'ticagrelor', 'brilique': 'ticagrelor',

  // Antieméticos — domperidona
'domperidona': 'domperidona', 'motilium': 'domperidona', 'domperidone': 'domperidona',

  // Antipsicóticos — clorpromazina, risperidona
'clorpromazina': 'clorpromazina', 'amplictil': 'clorpromazina', 'thorazine': 'clorpromazina',
'chlorpromazine': 'clorpromazina',
'risperidona': 'risperidona', 'risperdal': 'risperidona', 'risperidone': 'risperidona',

  // Antidepresivos — duloxetina
'duloxetina': 'duloxetina', 'cymbalta': 'duloxetina', 'duloxetine': 'duloxetina',
'ariclaim': 'duloxetina',

  // Opioides — petidina / meperidina
  // ('meperidina' já mapeada como 'opioide' acima — não duplicar)
'petidina': 'petidina', 'meperidine': 'petidina',
'demerol': 'petidina', 'pethidine': 'petidina',

  // Hematologia — ácido tranexâmico, alteplase
'acido tranexamico': 'acido tranexamico', 'ácido tranexâmico': 'acido tranexamico',
'tranexamico': 'acido tranexamico', 'tranexamic acid': 'acido tranexamico',
'transamin': 'acido tranexamico', 'hemoblock': 'acido tranexamico',
'alteplase': 'alteplase', 'actilyse': 'alteplase', 'activase': 'alteplase',
'rt-pa': 'alteplase', 'rtpa': 'alteplase', 'tpa': 'alteplase',

  // Antirreumáticos / Antimaláricos — hidroxicloroquina
'hidroxicloroquina': 'hidroxicloroquina', 'hydroxychloroquine': 'hidroxicloroquina',
'plaquinol': 'hidroxicloroquina', 'reuquinol': 'hidroxicloroquina',
'plaquenil': 'hidroxicloroquina',

  // Inmunosupresores / Oncológicos — metotrexato
'metotrexato': 'metotrexato', 'methotrexate': 'metotrexato', 'mtx': 'metotrexato',
'methofar': 'metotrexato', 'ledertrexate': 'metotrexato',

  // ── Lotes 7–10 — aliases realmente novos (sem duplicatas com lotes anteriores) ──

  // Dextrometorfano — aliases extras novos
'vick 44': 'dextrometorfano', 'vick44': 'dextrometorfano',
'neotoss': 'dextrometorfano', 'trimedal': 'dextrometorfano',

  // Pseudoefedrina — aliases extras novos
'actifed': 'pseudoefedrina', 'resfenol': 'pseudoefedrina',
'rhinosoro': 'pseudoefedrina',

  // Álcool — aliases extras novos
'bebida alcoolica': 'alcool',

  // Gemfibrozila — aliases extras novos
'jezil': 'gemfibrozila',

  // Amitriptilina — aliases extras novos
'amitriptyline': 'amitriptilina', 'amytril': 'amitriptilina',
'adepril': 'amitriptilina',

  // Propafenona (novo — Lote 8)
'propafenona': 'propafenona', 'propafenone': 'propafenona',
'rytmonorm': 'propafenona', 'ritmonorm': 'propafenona',

  // Flecainida (novo — Lote 8)
'flecainida': 'flecainida', 'flecainide': 'flecainida',
'tambocor': 'flecainida',

  // Dobutamina (novo — Lote 8)
'dobutamina': 'dobutamina', 'dobutamine': 'dobutamina',
'dobutrex': 'dobutamina',

  // Adenosina (novo — Lote 8)
'adenosina': 'adenosina', 'adenosine': 'adenosina',
'adenocor': 'adenosina', 'adenocard': 'adenosina',

  // Ácido valproico — aliases extras novos
'valpakine': 'acido valproico', 'valproic acid': 'acido valproico',
'valproato de sodio': 'acido valproico', 'valproato de sódio': 'acido valproico',

  // Levetiracetam (novo — Lote 9)
'levetiracetam': 'levetiracetam', 'levetiracetame': 'levetiracetam',
'keppra': 'levetiracetam', 'spritam': 'levetiracetam',

  // Levodopa + Carbidopa (novo — Lote 9)
'levodopa': 'levodopa carbidopa', 'carbidopa': 'levodopa carbidopa',
'levodopa carbidopa': 'levodopa carbidopa', 'sinemet': 'levodopa carbidopa',
'prolopa': 'levodopa carbidopa', 'stalevo': 'levodopa carbidopa',

  // Pramipexol (novo — Lote 9)
'pramipexol': 'pramipexol', 'pramipexole': 'pramipexol',
'mirapex': 'pramipexol', 'sifrol': 'pramipexol',

  // Leflunomida (novo — Lote 10)
'leflunomida': 'leflunomida', 'leflunomide': 'leflunomida',
'arava': 'leflunomida', 'leflunomida sanofi': 'leflunomida',

  // Adalimumabe (novo — Lote 10)
'adalimumabe': 'adalimumabe', 'adalimumab': 'adalimumabe',
'humira': 'adalimumabe', 'adalimumabe pfizer': 'adalimumabe',
'hyrimoz': 'adalimumabe', 'hadlima': 'adalimumabe',

  // Etanercepte (novo — Lote 10)
'etanercepte': 'etanercepte', 'etanercept': 'etanercepte',
'enbrel': 'etanercepte', 'benepali': 'etanercepte',
  // ═══════════════════════════════════════════════════════════════
  // NOVOS TERMOS — IDs canônicos para todas as 300 novas interacciones
  // ═══════════════════════════════════════════════════════════════

  // Paxlovid / antivirais COVID
  'ritonavir_boost': 'paxlovid',

  // Antipsicóticos novos
'lurasidona': 'lurasidona', 'latuda': 'lurasidona',
'pimavanserina': 'pimavanserina', 'nuplazid': 'pimavanserina',
'asenapina': 'asenapina', 'sycrest': 'asenapina',
'paliperidona': 'paliperidona', 'invega': 'paliperidona',

  // Antidiabéticos novos
'liraglutida': 'liraglutida', 'victoza': 'liraglutida',
'exenatida': 'exenatida', 'byetta': 'exenatida',
'sitagliptina': 'sitagliptina', 'januvia': 'sitagliptina',

  // Triptanos / enxaqueca
'sumatriptano': 'sumatriptano', 'imigran': 'sumatriptano',
'eletriptano': 'eletriptano', 'relpax': 'eletriptano',
'rimegepant': 'rimegepant', 'nurtec': 'rimegepant',
'atogepant': 'atogepant', 'qulipta': 'atogepant',
'lasmiditano': 'lasmiditano', 'reyvow': 'lasmiditano',

  // EII / biológicos
'ozanimod': 'ozanimod', 'zeposia': 'ozanimod',
'upadacitinibe': 'upadacitinibe', 'rinvoq': 'upadacitinibe',
'ustekinumabe': 'ustekinumabe', 'stelara': 'ustekinumabe',
'certolizumabe': 'certolizumabe', 'cimzia': 'certolizumabe',
'secuquinumabe': 'secuquinumabe', 'cosentyx': 'secuquinumabe',

  // Dislipidemia
'bempedoico': 'bempedoico', 'nexletol': 'bempedoico',
'icosapento': 'icosapento', 'vascepa': 'icosapento',
'evolocumabe': 'evolocumabe', 'repatha': 'evolocumabe',
'alirocumabe': 'alirocumabe', 'praluent': 'alirocumabe',
'inclisiran': 'inclisiran', 'leqvio': 'inclisiran',
'volanesorsen': 'volanesorsen', 'waylivra': 'volanesorsen',

  // Alzheimer / neurologia
'donepezilo': 'donepezilo', 'aricept': 'donepezilo',
'memantina': 'memantina', 'ebixa': 'memantina',
'rivastigmina': 'rivastigmina', 'exelon': 'rivastigmina',
'lecanemabe': 'lecanemabe', 'leqembi': 'lecanemabe',

  // Asma / DPOC / HAP
'indacaterol': 'indacaterol', 'onbrez': 'indacaterol',
'tiotropio': 'tiotropio', 'spiriva': 'tiotropio',
'aclidinio': 'aclidinio', 'genuair': 'aclidinio',
'roflumilast': 'roflumilast', 'daxas': 'roflumilast',
'omalizumabe': 'omalizumabe', 'xolair': 'omalizumabe',
'tezepelumabe': 'tezepelumabe', 'tezspire': 'tezepelumabe',
'ivacaftor': 'ivacaftor', 'kalydeco': 'ivacaftor',
'elexacaftor': 'elexacaftor', 'trikafta': 'elexacaftor',
'bosentana': 'bosentana', 'tracleer': 'bosentana',
'iloprost': 'iloprost', 'ventavis': 'iloprost',
'selexipague': 'selexipague', 'uptravi': 'selexipague',
'macitentan': 'macitentan', 'opsumit': 'macitentan',
'pirfenidona': 'pirfenidona', 'esbriet': 'pirfenidona',

  // Hepatite C / antivirais
'sofosbuvir': 'sofosbuvir', 'sovaldi': 'sofosbuvir',
'ledipasvir': 'ledipasvir', 'harvoni': 'ledipasvir',
'velpatasvir': 'velpatasvir', 'epclusa': 'velpatasvir',
'glecaprevir': 'glecaprevir', 'maviret': 'glecaprevir',
'entecavir': 'entecavir', 'baraclude': 'entecavir',

  // HIV / antivirais
'maraviroque': 'maraviroque', 'selzentry': 'maraviroque',
'dolutegravir': 'dolutegravir', 'tivicay': 'dolutegravir',
'bictegravir': 'bictegravir', 'biktarvy': 'bictegravir',
'didanosina': 'didanosina', 'ddi': 'didanosina',
'zidovudina': 'zidovudina', 'azt': 'zidovudina', 'retrovir': 'zidovudina',
'abacavir': 'abacavir', 'ziagen': 'abacavir',
'lamivudina': 'lamivudina', '3tc': 'lamivudina', 'epivir': 'lamivudina',
'tenofovir': 'tenofovir', 'viread': 'tenofovir', 'taf': 'tenofovir', 'tdf': 'tenofovir',

  // Antibióticos novos
'colistina': 'colistina', 'polymyxin_e': 'colistina',
'polimixina_b': 'polimixina_b', 'polymyxin_b': 'polimixina_b',
  'tobi': 'tobramicina',
'amikacina': 'amikacina',

  // Antituberculosos novos
'bedaquilina': 'bedaquilina', 'sirturo': 'bedaquilina',
'delamanida': 'delamanida', 'deltyba': 'delamanida',
'pirazinamida': 'pirazinamida', 'pyrazinamide': 'pirazinamida',
'etambutol': 'etambutol', 'myambutol': 'etambutol',

  // Antifúngicos
'voriconazol': 'voriconazol', 'vfend': 'voriconazol',
'posaconazol': 'posaconazol', 'noxafil': 'posaconazol',
'caspofungina': 'caspofungina', 'cancidas': 'caspofungina',
'anfotericina': 'anfotericina', 'fungizone': 'anfotericina',

  // Anemias / hematopoese
'roxadustate': 'roxadustate', 'evrenzo': 'roxadustate',
'ferro_sacarato': 'ferro_sacarato', 'venofer': 'ferro_sacarato',
'darbepoetina': 'darbepoetina', 'aranesp': 'darbepoetina',
'eritropoetina': 'eritropoetina', 'epo': 'eritropoetina', 'eprex': 'eritropoetina',

  // Ginecologia / hormonais
'drospirenona': 'drospirenona', 'yasmin': 'drospirenona',
'dienogest': 'dienogest', 'visanne': 'dienogest',
'goserelina': 'goserelina', 'zoladex': 'goserelina',
'medroxiprogesterona': 'medroxiprogesterona', 'depo-provera': 'medroxiprogesterona',
'anastrozol': 'anastrozol', 'arimidex': 'anastrozol',
'letrozol': 'letrozol', 'femara': 'letrozol',

  // Cardiovascular / novas moléculas
'vernakalant': 'vernakalant', 'brinavess': 'vernakalant',
'mavacamten': 'mavacamten', 'camzyos': 'mavacamten',
'aliskiren': 'aliskiren',
  'catapres': 'clonidina',
'hidralazina': 'hidralazina', 'apresoline': 'hidralazina',
  'isoket': 'isossorbida',

  // Oncologia / TKIs
'imatinibe': 'imatinibe', 'glivec': 'imatinibe',
'erlotinibe': 'erlotinibe', 'tarceva': 'erlotinibe',
'ponatinibe': 'ponatinibe', 'iclusig': 'ponatinibe',
'capecitabina': 'capecitabina', 'xeloda': 'capecitabina',
'micofenolato': 'micofenolato', 'cellcept': 'micofenolato',
'sirolimus': 'sirolimus', 'rapamicina': 'sirolimus', 'rapamune': 'sirolimus',

  // Anestesia / emergência
'cetamina': 'cetamina', 'ketamina': 'cetamina', 'ketalar': 'cetamina',
  'durogesic': 'fentanil',
'sugammadex': 'sugammadex', 'bridion': 'sugammadex',
'protamina': 'protamina', 'protamine': 'protamina',
'flumazenil': 'flumazenil', 'lanexat': 'flumazenil',
'naltrexona': 'naltrexona', 'revia': 'naltrexona',
'buprenorfina': 'buprenorfina', 'subutex': 'buprenorfina', 'suboxone': 'buprenorfina',
'vitamina_k': 'vitamina_k', 'fitomenadiona': 'vitamina_k',
'dissulfiram': 'dissulfiram', 'antabuse': 'dissulfiram',
  'physeptone': 'metadona',

  // Procinéticos / antieméticos
'prucalopride': 'prucalopride', 'resolor': 'prucalopride',
'ondansetron': 'ondansetron',

  // Inmunosupresores

  // Vacinas / imunologia
'vacina_viva': 'vacina_viva', 'varicela_vacina': 'vacina_viva',

  // Miscelânea
'sorbitol': 'sorbitol',
'grapefruit': 'grapefruit', 'toranja': 'grapefruit', 'suco_grapefruit': 'grapefruit',
'hypericum': 'hypericum', 'erva_sao_joao': 'hypericum', 'hipericao': 'hypericum',
  'etanol': 'alcool',
'tabaco': 'tabaco', 'cigarro': 'tabaco',
  'parnate': 'tranilcipromina',
  'nardil': 'fenelzina',
'triptofano': 'triptofano',
'sevelâmer': 'sevelâmer', 'renagel': 'sevelâmer',
'polietilenoglicol': 'polietilenoglicol', 'peg': 'polietilenoglicol', 'movicol': 'polietilenoglicol',
'bisacodil': 'bisacodil', 'dulcolax': 'bisacodil',
'lactulose': 'lactulose', 'lactulax': 'lactulose',
'zoledronico': 'zoledronico', 'zometa': 'zoledronico', 'aclasta': 'zoledronico',
'acarbose': 'acarbose', 'glucobay': 'acarbose',
'rosiglitazona': 'rosiglitazona', 'avandia': 'rosiglitazona',
'pioglitazona': 'pioglitazona', 'actos': 'pioglitazona',
  'glibenclamide': 'glibenclamida',
'ganciclovir': 'ganciclovir', 'cymevene': 'ganciclovir',
'cidofovir': 'cidofovir', 'vistide': 'cidofovir',
'aciclovir': 'aciclovir', 'zovirax': 'aciclovir',
'oseltamivir': 'oseltamivir', 'tamiflu': 'oseltamivir',
'ribavirina': 'ribavirina', 'copegus': 'ribavirina',
'probenecida': 'probenecida', 'benemid': 'probenecida',
'meropenem': 'meropenem', 'meronem': 'meropenem',
'vecurônio': 'vecurônio', 'vecuronium': 'vecurônio',
'succinilcolina': 'succinilcolina', 'succinylcholine': 'succinilcolina',
'insulina_glargina': 'insulina_glargina', 'lantus': 'insulina_glargina',
'insulina_detemir': 'insulina_detemir', 'levemir': 'insulina_detemir',
  'aminophylline': 'aminofilina',
'ciclesonida': 'ciclesonida', 'alvesco': 'ciclesonida',
'montelucaste': 'montelucaste',
'enoxacino': 'enoxacino',

};

// ─────────────────────────────────────────────────────────────────────────────
// SERVIÇO PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────
class DrugInteractionService {

  /// Total de pares de interacciones na base de dados embutida.
  static int get totalInteractions => _interactionDB.length;

  /// Retorna todos os nomes de fármacos conhecidos (chaves do _termMap),
  /// ordenados alfabeticamente — usado para autocomplete na UI.
  static List<String> getAllDrugNames() {
    final names = _termMap.keys.toList()..sort();
    return names;
  }

  /// Extrai termos reconhecidos de um texto livre — exposto para uso na UI.
  static List<String> extractTerms(String text) => _extractTerms(text);

  /// Extrai termos de medicamentos a partir de um texto livre.
  /// Remove pontuação, divide por separadores comuns e normaliza.
  static List<String> _extractTerms(String text) {
    final lower = text.toLowerCase()
        .replaceAll(RegExp(r'[\d]+\s*(mg|mcg|ml|ui|g|%)'), '') // remove dosiss
        .replaceAll(RegExp(r'[,;/\n\r\t+&]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final words = lower.split(' ');
    final terms = <String>{};

    for (int i = 0; i < words.length; i++) {
      final w = words[i].trim();
      if (w.length < 3) continue;

      // Palavra simples
      if (_termMap.containsKey(w)) terms.add(_termMap[w]!);

      // Bigrama (duas palavras)
      if (i + 1 < words.length) {
        final bigram = '$w ${words[i+1]}';
        if (_termMap.containsKey(bigram)) terms.add(_termMap[bigram]!);
      }

      // Trigrama (três palavras)
      if (i + 2 < words.length) {
        final trigram = '$w ${words[i+1]} ${words[i+2]}';
        if (_termMap.containsKey(trigram)) terms.add(_termMap[trigram]!);
      }
    }

    return terms.toList();
  }

  /// Verifica interacciones entre uma lista de IDs de fármacos (drugsDatabase)
  /// e um texto livre de medicamentos do paciente.
  ///
  /// [selectedDrugNames] — lista de nomes dos fármacos selecionados no app
  /// [patientMedicationsText] — campo livre de medicamentos em uso do paciente
  ///
  /// Retorna lista de interacciones ordenadas por severidade.
  static List<DrugInteraction> checkInteractions({
    required List<String> selectedDrugNames,
    required String patientMedicationsText,
  }) {
    // Extrair termos de AMBAS as fontes
    final patientTerms = _extractTerms(patientMedicationsText);
    final selectedTerms = selectedDrugNames
        .expand((name) => _extractTerms(name))
        .toSet()
        .toList();

    // Unir todos os termos para checar interacciones internas (entre selecionados)
    final allTerms = {...patientTerms, ...selectedTerms}.toList();

    final results = <DrugInteraction>[];
    final seen = <String>{};

    for (final entry in _interactionDB) {
      final id1 = entry.$1;
      final id2 = entry.$2;

      // Verifica se AMBOS os termos estão presentes (em qualquer combinación de fontes)
      final has1 = allTerms.any((t) => t == id1 || _termMap[t] == id1);
      final has2 = allTerms.any((t) => t == id2 || _termMap[t] == id2);

      // Para interacciones com medicamentos DO PACIENTE: precisa de pelo menos um selecionado
      final hasSelected1 = selectedTerms.any((t) => t == id1 || _termMap[t] == id1);
      final hasSelected2 = selectedTerms.any((t) => t == id2 || _termMap[t] == id2);

      if (has1 && has2 && (hasSelected1 || hasSelected2)) {
        final key = [id1, id2]..sort();
        final keyStr = key.join('|');
        if (!seen.contains(keyStr)) {
          seen.add(keyStr);
          results.add(DrugInteraction(
            drug1: _displayName(id1, selectedDrugNames, patientMedicationsText),
            drug2: _displayName(id2, selectedDrugNames, patientMedicationsText),
            severity: entry.$3,
            mechanism: entry.$4,
            effect: entry.$5,
            management: entry.$6,
            clinicalAlert: entry.$7,
            evidenceLevel: entry.$8,
            riskTypes: entry.$9,
            references: entry.$10,
          ));
        }
      }
    }

    // Ordena por severidade (mais grave primeiro)
    results.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return results;
  }

  /// Verifica interacciones apenas entre os fármacos selecionados no app (sem texto livre)
  static List<DrugInteraction> checkSelectedOnly(List<String> drugNames) {
    return checkInteractions(selectedDrugNames: drugNames, patientMedicationsText: '');
  }

  /// Tenta retornar um nome mais legível para exibição
  static String _displayName(String id, List<String> selectedNames, String patientText) {
    // Verifica se algum nome selecionado tem esse ID
    for (final name in selectedNames) {
      final terms = _extractTerms(name);
      if (terms.contains(id)) return name.split('/').first.trim();
    }
    // Tenta encontrar no texto do paciente
    final words = patientText.toLowerCase().split(RegExp(r'[\s,;/]+'));
    for (final w in words) {
      if (_termMap[w] == id) {
        return '${w[0].toUpperCase()}${w.substring(1)}';
      }
    }
    // Fallback: capitalizar o próprio ID
    return '${id[0].toUpperCase()}${id.substring(1)}';
  }
}
