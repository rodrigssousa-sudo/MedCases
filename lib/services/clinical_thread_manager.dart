// ══════════════════════════════════════════════════════════════════════════════
// clinical_thread_manager.dart — Clinical Thread & Context Manager
// BUILD 249 (origin) → BUILD 304 PURIF-1 (production seal)
//
// PROBLEMA RESOLVIDO:
//   Context contamination / cross-case poisoning — _aiHistory acumulava turnos
//   de casos diferentes (ex: amiodarona + enalapril) e contaminava resposta
//   de casos novos (ex: náuseas/vômitos/diarreia).
//   ExternalToolLinkEngine detectava q=amiodarona em contexto de gastroenterite.
//
// RESPONSABILIDADES:
//   1. ClinicalThreadManager — rastreia thread ativo (tópico + turno + threadId)
//   2. isContinuationOfCurrentThread() — detecta se é follow-up ou novo caso
//   3. buildHistoryStrategy() — decide quantos turnos de history enviar ao Gemini
//   4. Integrado ao fluxo em app_provider.dart (sendAiMessage + buildAIAnswer)
//
// REGRAS DE CONTEXTO (Modo Plantão):
//   isContinuation=true  → enviar últimas 1-3 interações do thread atual
//   isContinuation=false → enviar histórico VAZIO, iniciar novo thread
//
// LOG:
//   [THREAD_MANAGER] mode=plantao action=new_thread reason=topic_shift
//                    oldTopic=amiodarona newTopic=gastroenterite
//   [THREAD_MANAGER] mode=plantao action=continue_thread reason=button_action
//                    topic=TEP turnCount=2
//   [THREAD_AUDIT] foundExisting=true components=ClinicalSessionMemory,_aiHistory
//   [HISTORY_SANITIZER] mode=plantao strategy=empty sent=0 removed=N
//   [HISTORY_SANITIZER] mode=plantao strategy=thread_minimal sent=2 topic=TEP
//   [EXT_TOOL_CONTEXT] source=current_only q=diarreia
//   [EXT_TOOL_CONTEXT] blocked_stale_tool old=amiodarona reason=not_in_current_context
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

// ─────────────────────────────────────────────────────────────────────────────
// ClinicalThreadStatus — resultado da detecção de continuidade
// ─────────────────────────────────────────────────────────────────────────────
enum ThreadAction {
  continueThread, // follow-up do caso ativo → enviar histórico mínimo
  newThread, // novo caso / tema diferente → limpar histórico
}

class ClinicalThreadStatus {
  final ThreadAction action;
  final String reason; // para log
  final String topic; // tópico ativo (novo ou mantido)
  final bool fromButton; // veio de botão clínico

  const ClinicalThreadStatus({
    required this.action,
    required this.reason,
    required this.topic,
    this.fromButton = false,
  });

  bool get isContinuation => action == ThreadAction.continueThread;
}

// ─────────────────────────────────────────────────────────────────────────────
// ClinicalThreadManager — rastreador de thread clínico ativo
//
// 100% LOCAL — RAM-only — Zero rede — Zero IA
// ─────────────────────────────────────────────────────────────────────────────
class ClinicalThreadManager {
  // ── Estado do thread ativo ─────────────────────────────────────────────────
  String _activeTopic = '';
  String _activeThreadId = '';
  int _turnCount = 0;
  int _lastActivityMs = 0;

  // Última pergunta do usuário que INICIOU o thread ativo
  String _threadStartQuery = '';

  // Máximo de turnos de histórico a enviar em modo continuation
  // ORDEM 19: reduzido para 2 pares (= 4 entradas) — payload enxuto, máxima velocidade.
  // Lógica: 1 par anterior (user+assistant) + query atual = contexto mínimo eficaz.
  // Evita avalanche de tokens redundantes sem perder continuidade do turno imediato.
  static const int kMaxContinuationTurns =
      2; // 2 pares user/assistant = 4 entradas

  // Timeout de inatividade: 10 minutos sem mensagem → novo thread automaticamente (Plantão)
  static const int kThreadTimeoutMs = 10 * 60 * 1000;

  // BUILD 304 [G3]: TTL de inatividade para Modo Estudo.
  // Se o médico ficar mais de 6h sem interagir, o histórico de transporte da
  // sessão de Estudo é descartado — evita continuidade pedagógica incoerente
  // (médico esqueceu o contexto; nova sessão começa limpa).
  // O histórico LOCAL no dispositivo é PRESERVADO para exibição visual.
  // Study transport memory is bounded by 30 exchanges, not TTL-cleared inside an active chat.

  // BUILD 304 [G1]: Janela micro-deslizante para Modo Estudo.
  // Médicos em Estudo realizam no máximo 4-5 interações por tema.
  // Enviar histórico completo (10+ turnos) é desperdício crítico de tokens.
  // Máx 4 turnos (2 pares user+assistant = 4 entradas) no payload da API.
  // O histórico completo permanece intacto no dispositivo para exibição.
  static const int kMaxStudyTurns = 30; // 30 pares = 60 entradas

  // ── Frases que sempre indicam follow-up (nunca iniciam novo thread) ────────
  static const _kFollowUpPhrases = <String>{
    // PT-BR — respostas a pergunta interativa
    'sim', 'não', 'nao', 'ok', 'certo', 'entendido', 'confirma', 'confirmo',
    // PT-BR — continuação explícita
    'dose', 'a dose', 'qual a dose', 'qual dose', 'e a dose',
    'monitorar', 'monitorização', 'monitorizacao',
    'contraindicação', 'contraindicacao', 'contraindicações',
    'alternativa', 'alternativas',
    'diluição', 'diluicao', 'como dilui', 'como diluir',
    'infusão', 'como infundir',
    'e agora', 'o que fazer', 'próximo passo', 'proximo passo',
    'detalhar', 'mais detalhes', 'pode detalhar', 'me explica',
    'conduta', 'condutas', 'e a conduta', 'qual a conduta',
    'interação', 'interacao',
    'como funciona', 'mecanismo',
    // ES (only entries NOT already in PT-BR above)
    'sí', 'si',
    'dosis', 'la dosis', 'cuál es la dosis',
    'monitorizar', 'monitoreo',
    'contraindicación',
    'dilución', 'infusión',
    'qué hacer', 'siguiente paso', 'próximo paso',
    'detallar', 'más detalles', 'explica',
    'interacción',
  };

  // ── Follow-ups clínicos contextuais com dados novos ───────────────────────
  //
  // Reconhece mensagens que acrescentam dados ao caso ativo sem repetir a
  // patologia: peso/ajuste renal, história dirigida, sinais vitais,
  // laboratório e imagem. Uma introdução explícita de novo paciente/caso não
  // é convertida em continuação.
  static bool isContextualClinicalFollowUp(String text) {
    var q = text.trim().toLowerCase();
    if (q.isEmpty) return false;
    q = q.replaceFirst(RegExp(r'^[¿¡\s]+'), '');

    // PT/ES: dobra acentos apenas para classificação lexical. O texto original
    // continua intacto no histórico e no payload enviado ao provider.
    final qFolded = q
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
    final lexicalTokens = RegExp(r'[a-z0-9]+')
        .allMatches(qFolded)
        .map((match) => match.group(0)!)
        .toList(growable: false);

    final explicitNewCase = <String>[
      'novo caso',
      'nova paciente',
      'novo paciente',
      'outro paciente',
      'outra paciente',
      'mudar de caso',
      'trocar de caso',
      'nuevo caso',
      'nuevo paciente',
      'nueva paciente',
      'otro paciente',
      'otra paciente',
      'cambiar de caso',
    ].any(qFolded.contains);
    if (explicitNewCase) return false;

    // PLANTAO_DEPENDENT_MANAGEMENT_FOLLOWUP_V1
    //
    // Perguntas de manejo que dependem do paciente ativo frequentemente nao
    // repetem a patologia: "¿Y qué tratamiento farmacológico completo
    // indicarías ahora?". Elas devem carregar o caso atual. A decisao final
    // continua protegida pelas fronteiras canonicas: novo paciente/caso,
    // patologia explicitamente diferente e troca inequivoca de farmaco.
    final hasManagementTerm = <String>[
      'tratamiento',
      'tratamento',
      'manejo',
      'conducta',
      'conduta',
      'prescripcion',
      'prescricao',
      'medicacion',
      'medicacao',
    ].any(qFolded.contains);

    final hasDependentManagementCue =
        qFolded.startsWith('y ') ||
        qFolded.startsWith('e ') ||
        qFolded.contains(' ahora') ||
        qFolded.endsWith('ahora') ||
        qFolded.contains(' agora') ||
        qFolded.endsWith('agora') ||
        qFolded.contains('indicarias') ||
        qFolded.contains('indicaria') ||
        qFolded.contains('harias') ||
        qFolded.contains('haria') ||
        qFolded.contains('farias') ||
        qFolded.contains('faria') ||
        qFolded.contains('completo') ||
        qFolded == 'tratamiento' ||
        qFolded == 'tratamiento farmacologico' ||
        qFolded == 'tratamento' ||
        qFolded == 'tratamento farmacologico' ||
        qFolded == 'manejo' ||
        qFolded == 'conducta' ||
        qFolded == 'conduta';

    if (hasManagementTerm && hasDependentManagementCue) {
      return true;
    }

    // PLANTAO_DEPENDENT_CLINICAL_FOLLOWUP_AND_CASE_ANCHOR_V1
    //
    // Follow-up clinico dependente nao e sinonimo de "classificacao".
    // Perguntas curtas como "por que essa categoria?", "precisa internar?",
    // "y trombolisis?" ou "en este paciente..." dependem do caso ativo.
    //
    // Fail-closed:
    // - explicitNewCase continua tendo precedencia e ja retornou false acima;
    // - frases exatas dependentes sao aceitas;
    // - expansao semantica so ocorre quando existe referencia deitica explicita
    //   ao caso anterior (este/ese/essa/eso/isso etc.).
    final dependentClinicalQuery = qFolded
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
        .replaceAll('ñ', 'n')
        .replaceFirst(RegExp(r'^[^a-z0-9]+'), '')
        .replaceFirst(RegExp(r'[^a-z0-9]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const dependentClinicalFollowUps = <String>{
      // Classificacao / categoria / risco — PT
      'classificacao',
      'a classificacao',
      'e a classificacao',
      'qual a classificacao',
      'qual e a classificacao',
      'e qual a classificacao',
      'e qual e a classificacao',
      'categoria',
      'a categoria',
      'e a categoria',
      'qual a categoria',
      'qual e a categoria',
      'e qual a categoria',
      'e qual e a categoria',
      'qual o risco',
      'e qual o risco',
      'por que corresponde a essa categoria',
      'por que corresponde a esta categoria',
      'porque corresponde a essa categoria',
      'porque corresponde a esta categoria',
      'por que e essa categoria',
      'por que essa categoria',

      // Conduta dependente — PT
      'precisa internar',
      'precisa internacao',
      'necessita internacao',
      'requer internacao',
      'e trombolise',
      'trombolise',
      'e reperfusao',
      'reperfusao',
      'e a anticoagulacao',
      'e anticoagulacao',
      'o que fazer com a anticoagulacao',
      'e o manejo ambulatorial',
      'manejo ambulatorial',
      'pode ter alta',
      'pode receber alta',

      // Clasificacion / categoria / riesgo — ES
      'clasificacion',
      'la clasificacion',
      'y la clasificacion',
      'cual es la clasificacion',
      'y cual es la clasificacion',
      'que clasificacion',
      'la categoria',
      'y la categoria',
      'cual es la categoria',
      'y cual es la categoria',
      'que categoria',
      'que riesgo',
      'cual es el riesgo',
      'y cual es el riesgo',
      'por que corresponde a esa categoria',
      'porque corresponde a esa categoria',
      'por que es esa categoria',
      'por que esa categoria',

      // Conducta dependiente — ES
      'necesita internacion',
      'requiere internacion',
      'necesita hospitalizacion',
      'requiere hospitalizacion',
      'y trombolisis',
      'trombolisis',
      'y reperfusion',
      'reperfusion',
      'y que harias con la anticoagulacion',
      'que harias con la anticoagulacion',
      'y anticoagulacion',
      'anticoagulacion',
      'y manejo ambulatorio',
      'manejo ambulatorio',
      'puede darse de alta',
      'puede tener alta',

      // EN fallback
      'classification',
      'what is the classification',
      'what is the category',
      'why this category',
      'does this patient need admission',
      'and thrombolysis',
      'and anticoagulation',
      'e o tratamento',
      'qual o tratamento',
      'qual e o tratamento',
      'e a conduta',
      'qual a conduta',
      'qual e a conduta',
      'e o manejo',
      'qual o manejo',
      'qual e o manejo',
      'e os exames',
      'quais exames',
      'e o diagnostico',
      'qual o diagnostico',
      'e o prognostico',
      'qual o prognostico',
      'y el tratamiento',
      'cual es el tratamiento',
      'y la conducta',
      'cual es la conducta',
      'y el manejo',
      'cual es el manejo',
      'y los estudios',
      'que estudios',
      'y el diagnostico',
      'cual es el diagnostico',
      'y el pronostico',
      'cual es el pronostico',
      'and treatment',
      'what is the treatment',
      'and management',
      'what is the management',
    };
    final dependentWordCount = dependentClinicalQuery
        .split(' ')
        .where((w) => w.isNotEmpty)
        .length;

    final hasExplicitBackwardReference = RegExp(
      r'\b(este paciente|ese paciente|esta paciente|'
      r'neste paciente|nesse paciente|essa categoria|esta categoria|'
      r'esa categoria|esta categoria|essa classificacao|esta classificacao|'
      r'esa clasificacion|esta clasificacion|isso|eso|this patient|that category)\b',
    ).hasMatch(dependentClinicalQuery);

    final hasDependentIntent = RegExp(
      r'\b(classific|clasific|categoria|category|risco|riesgo|risk|'
      r'intern|hospital|alta|ambulator|trombol|reperfus|anticoag|'
      r'conduta|conducta|manejo|management|tratamento|tratamiento|treatment)\w*',
    ).hasMatch(dependentClinicalQuery);

    final isDependentClinicalFollowUp =
        dependentClinicalFollowUps.contains(dependentClinicalQuery) ||
        (dependentWordCount <= 16 &&
            hasExplicitBackwardReference &&
            hasDependentIntent);

    final hasWeight = RegExp(
      r'(^|[^a-z0-9])\d+(?:[.,]\d+)?\s*kg([^a-z0-9]|$)',
    ).hasMatch(qFolded);
    final hasCalculationVerb = lexicalTokens.any(
      (token) =>
          token.startsWith('calcul') &&
          token != 'calculadora' &&
          token != 'calculadoras',
    );
    final hasCalculationCue =
        hasCalculationVerb ||
        <String>[
          'dose',
          'doses',
          'dosis',
          'dosagem',
          'dosificacion',
        ].any(qFolded.contains);
    final isWeightCarryForward =
        hasWeight &&
        (hasCalculationCue ||
            qFolded.startsWith('e para ') ||
            qFolded.startsWith('y para ') ||
            qFolded.startsWith('para '));

    final hasRenalMarker = <String>[
      'creatinina',
      'clcr',
      'clearance',
      'funcao renal',
      'funcion renal',
      'depuracao',
      'depuracion',
    ].any(qFolded.contains);
    final hasAdjustmentCue = lexicalTokens.any(
      (token) =>
          token.startsWith('ajust') ||
          token.startsWith('adapt') ||
          token.startsWith('corrig') ||
          token.startsWith('correg'),
    );

    final hasVitalOrExamMarker = <String>[
      'pressao arterial',
      'presion arterial',
      'spo2',
      'saturacao',
      'saturacion',
      'temperatura',
      'leucoc',
      'neutrofil',
      'plaquet',
      'hemoglob',
      'hematoc',
      'pcr elevada',
      'crp ',
      'tropon',
      'lactato',
      'gasometr',
      'ureia',
      'urea',
      'sodio',
      'potassio',
      'potasio',
      'ecg',
      'eletrocard',
      'electrocard',
      'usg',
      'ultrass',
      'ecograf',
      'tomografia',
      'ressonancia',
      'resonancia',
      'raio x',
      'rayos x',
      'imagem',
      'imagen',
      'inconclus',
    ].any(qFolded.contains);

    final hasObjectiveNumber = RegExp(
      r'\b\d+(?:[.,]\d+)?\s*(?:c|mmhg|bpm|x10|mil|mg/dl|mmol|meq|%)\b',
    ).hasMatch(qFolded);

    return isDependentClinicalFollowUp ||
        isWeightCarryForward ||
        (hasRenalMarker && hasAdjustmentCue) ||
        _isRichClinicalNarrativeFollowUp(qFolded) ||
        hasVitalOrExamMarker ||
        hasObjectiveNumber;
  }

  static bool _isRichClinicalNarrativeFollowUp(String foldedText) {
    final markers = <RegExp>[
      RegExp(r'\b(?:comecou|iniciou|inicio|desde)\b'),
      RegExp(r'\bha\s+\d+(?:[.,]\d+)?\s*(?:h|hora|horas|dia|dias)\b'),
      RegExp(r'\b(?:migrou|irradiou|piorou|melhorou|evoluiu)\b'),
      RegExp(r'\b(?:refere|relata|nega|presenta)\b'),
      RegExp(r'\b(?:sem|sin)\s+sintomas?\b'),
      RegExp(r'\b(?:febre|fiebre|nausea|nauseas|vomito|vomitos)\b'),
    ];

    var hits = 0;
    for (final marker in markers) {
      if (marker.hasMatch(foldedText)) hits++;
      if (hits >= 2) return true;
    }
    return false;
  }

  // ── Keywords de novo caso — qualquer uma dessas em query longa → new thread ─
  // Sintomas sistêmicos sem relação farmacológica = novo caso clínico.
  //
  // BUILD 305 [C2]: Tokens frágeis com espaçamento manual ('iam ', ' iam',
  // 'tep ', ' tep', 'avc ', ' avc') REMOVIDOS.
  // PROBLEMA: pontuação grudada ("IAM, conduta" → "iam , conduta" após
  // lowercase) não casava com 'iam ' (espaço após vírgula truncado).
  // SOLUÇÃO: tokens limpos sem padding. A query é normalizada antes de .any()
  // via q.contains(s) — o split de pontuação em evaluate() já usa
  // replaceAll(RegExp(r'[^\w\s]'), ' '), logo 'iam' casa corretamente.
  // Cobertura completa mantida via _kIsolatedNewCaseTerms (Set exato).

  // PLANTAO_GLOBAL_CONTEXT_SEMANTIC_SWITCH_V1
  //
  // Canonicaliza aliases clinicos apenas para decidir continuidade do thread.
  // A pergunta visivel e o texto enviado ao modelo permanecem inalterados.
  static String _canonicalizePlantaoTopicAliases(String input) {
    var q = input
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
        .replaceAll('ñ', 'n')
        .replaceAll('_', ' ');

    q = q
        .replaceAll(
          RegExp(r'\b(?:dbt|dm1|dm2|t1dm|t2dm)\b'),
          ' diabetes ',
        )
        .replaceAll(RegExp(r'\bdiabetes\s+mellitus\b'), ' diabetes ')
        .replaceAll(
          RegExp(
            r'\b(?:iam|iamcest|iamcsst|iamssst|iamsest|stemi|nstemi)\b',
          ),
          ' infarto miocardio ',
        )
        .replaceAll(RegExp(r'\btep\b'), ' tromboembolismo pulmonar ')
        .replaceAll(RegExp(r'\b(?:dpoc|copd)\b'), ' epoc ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return q;
  }

static const _kNewCaseSignals = <String>[
    // Sintomas gastrointestinais / gerais
    'náusea', 'nausea', 'vômito', 'vomito', 'diarreia', 'diarrea',
    'dor abdominal', 'abdome', 'abdomen', 'dor de barriga',
    'febre', 'fiebre', 'calafrio', 'escalofrio',
    'dispneia', 'disnea', 'falta de ar', 'falta de aire',
    'dor no peito', 'dolor de pecho', 'dor precordial',
    'cefaleia', 'cefalea', 'dor de cabeça', 'dolor de cabeza',
    'tontura', 'mareo', 'vertigem', 'vértigo',
    'fraqueza', 'debilidad', 'cansaço',
    'tosse', 'tos', 'expectoração',
    'sangramento', 'sangramiento', 'hemorragia',
    'perda de consciência', 'pérdida de conciencia',
    'confusão', 'confusion', 'desorientação',
    'edema', 'inchaço', 'hinchazón',
    // Padrões de novo caso ("paciente com", "paciente de")
    'paciente com', 'paciente de', 'paciente apresenta',
    'paciente con', 'paciente presenta',
    'homem de', 'mulher de', 'hombre de', 'mujer de',
    'anos com', 'años con', 'anos de', 'años de',
    // Diagnósticos completamente diferentes
    // BUILD 305 [C2]: tokens limpos — sem padding de espaço ('iam ', ' iam',
    // 'tep ', ' tep', 'avc ', ' avc' removidos; cobertura mantida pelos
    // termos base + _kIsolatedNewCaseTerms que faz match exato por palavra).
    'gastroenterite', 'gastroenteritis', 'gastrenterite',
    'pneumonia', 'meningite', 'meningitis',
    'infarto', 'iam', 'tep', 'avc', 'acidente vascular',
    'sepse', 'sepsis', 'choque',
    'anafilaxia', 'anafilaxis',
    'intoxicação', 'intoxicacion',

    'dbt',
    'dm1',
    'dm2',
    't1dm',
    't2dm',
    'diabetes',];

  // ── ORDEM 33 — MANDATO 2: Termos clínicos isolados que SEMPRE iniciam novo thread ─
  //
  // DIAGNÓSTICO DO BUG "HISTÓRICO FANTASMA":
  //   Quando o médico digita "ICC" (1 palavra, 3 chars):
  //     wordCount=1 ≤ 3 → isTooShort=true → continueThread → history da Sertralina
  //     vaza para o novo contexto de ICC → resposta mista / contaminação cruzada.
  //
  // SOLUÇÃO — PRE-CHECK DE ISOLAMENTO:
  //   Antes de aplicar a regra isTooShort, verificar se a query é um termo
  //   clínico ISOLADO de nova patologia (acrônimo ou nome de doença sem qualquer
  //   palavra de follow-up). Se sim → newThread MESMO sendo curta.
  //   Critério: query normalizada (sem pontuação) é exatamente um desses termos.
  //
  // COBERTURA: acrônimos PT-BR + ES + nomes por extensão comuns em Plantão.
  static const _kIsolatedNewCaseTerms = <String>{
    // Cardiovascular
    'icc', 'icc.', 'iam', 'iam.', 'sca', 'sca.',
    'fa', 'fa.', 'flutter', 'tep', 'tep.',
    'tvp', 'tvp.',
    'dissecção', 'diseccion',
    'tam', 'bloqueio', 'bradicardia', 'taquicardia', 'fibrilação',
    'fibrilacion', 'cardioversão',
    // Neurológico
    'avc', 'avc.', 'acv', 'acv.', 'ave', 'tia', 'tia.',
    'meningite', 'meningitis', 'encefalite', 'encefalitis',
    'crise', 'convulsão', 'convulsion', 'epilepsia',
    // Respiratório
    'dpoc', 'dpoc.', 'epoc', 'asma', 'asthma', 'beca',
    'ards', 'srag', 'pcp',
    'pneumotórax', 'pneumotorax', 'derrame', 'efusão',
    // Renal / metabólico
    'ira', 'ira.', 'lra', 'lra.', 'irc', 'drc',
    'cad', 'cad.', 'hhns', 'hhs',
    'hipoglicemia', 'hiperglicemia',
    'hiponatremia', 'hipernatremia',
    'hipocalemia', 'hipercalemia', 'hipercalcemia',
    // Infecção / imunológico
    'sepse', 'sepsis', 'sirs', 'choque', 'shock',
    'anafilaxia', 'anafilaxis',
    'endocardite', 'endocarditis',
    // Trauma / emergência
    'politrauma', 'tcce', 'tce', 'queimadura', 'quemadura',
    'afogamento', 'ahogamiento',
    'hemorragia', 'hemotórax', 'hemotorax',
    // Digestivo / hepático
    'cirrosis', 'cirrose',
    'psa', 'psa.', // pancreatite aguda severa
    'hemorragia digestiva', 'hdab', 'hdai',
    // Obstétrico
    'eclampsia', 'preeclampsia',
    'hellp',
  };

  // Sinais demográficos são úteis para detectar um caso novo em perguntas
  // completas, mas não devem apagar o thread quando aparecem dentro de um pedido
  // contextual como "calcule para um paciente de 18 kg".
  static const _kDemographicNewCaseSignals = <String>{
    'paciente com',
    'paciente de',
    'paciente apresenta',
    'paciente con',
    'paciente presenta',
    'homem de',
    'mulher de',
    'hombre de',
    'mujer de',
    'anos com',
    'años con',
    'anos de',
    'años de',
  };

  // ── Fármacos de alta especificidade (detectar mudança de fármaco-alvo) ─────
  static const _kHighSpecificityDrugs = <String>[
    'amiodarona',
    'amiodarone',
    'vancomicina',
    'vancomycin',
    'noradrenalina',
    'norepinefrina',
    'heparina',
    'heparin',
    'insulina',
    'insulin',
    'warfarina',
    'varfarina',
    'metformina',
    'metformin',
    'prednisona',
    'prednisolona',
    'furosemida',
    'furosemide',
    'metoprolol',
    'propranolol',
    'enalapril',
    'captopril',
    'losartana',
    'ceftriaxona',
    'meropenem',
    'piperacilina',
    'midazolam',
    'propofol',
    'fentanil',
    'ketamina',
    'etomidato',
    'succinilcolina',
    'rocurônio',
    'adrenalina',
    'epinefrina',
    'dopamina',
    'dobutamina',
    'nitroprussiato',
    'nitroglicerina',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // evaluate() — avalia a nova query e retorna ClinicalThreadStatus
  //
  // Chamado em sendAiMessage() e buildAIAnswer() ANTES de montar o histórico.
  // ─────────────────────────────────────────────────────────────────────────
  ClinicalThreadStatus evaluate({
    required String currentUserText,
    required bool isPlantaoMode,
    bool cameFromButton = false,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final q = currentUserText.trim().toLowerCase();
    final wordCount = q.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    // ── Timeout de inatividade → novo thread ───────────────────────────────
    if (isPlantaoMode &&
        _activeTopic.isNotEmpty &&
        _lastActivityMs > 0 &&
        (now - _lastActivityMs) > kThreadTimeoutMs) {
      final oldTopic = _activeTopic;
      _startNewThread(q, now);
      return ClinicalThreadStatus(
        action: ThreadAction.newThread,
        reason: 'inactivity_timeout',
        topic: _activeTopic,
      );
    }

    // ── Thread vazio → inicia ──────────────────────────────────────────────
    if (_activeTopic.isEmpty) {
      _startNewThread(q, now);
      return ClinicalThreadStatus(
        action: ThreadAction.newThread,
        reason: 'first_message',
        topic: _activeTopic,
      );
    }

    // ── Veio de botão clínico → sempre continuation ───────────────────────
    if (cameFromButton) {
      _turnCount++;
      _lastActivityMs = now;
      if (kDebugMode) {
        debugPrint(
          '[THREAD_MANAGER] mode=${isPlantaoMode ? "plantao" : "estudo"} '
          'action=continue_thread reason=button_action '
          'topic=$_activeTopic turnCount=$_turnCount',
        );
      }
      return ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: 'button_action',
        topic: _activeTopic,
        fromButton: true,
      );
    }

    // ── ORDEM 33 — MANDATO 2: Termo clínico isolado de nova patologia ────────
    // PRE-CHECK síncrono antes de qualquer regra de follow-up.
    //
    // BUG ALVO: "ICC" → wordCount=1 ≤ 3 → isTooShort=true → continueThread →
    // history da Sertralina vaza para contexto de ICC → resposta mista.
    //
    // LÓGICA: se a query normalizada (trim + lowercase + sem pontuação) for
    // EXATAMENTE um dos termos em _kIsolatedNewCaseTerms, ela é uma nova patologia
    // isolada — independente de ser curta — e DEVE iniciar novo thread.
    // Isso toma precedência sobre isTooShort e followUpPhrase.
    //
    // Também detecta termos de 1-2 palavras com fármaco diferente do ativo
    // (ex: "Sertralina" quando thread ativo era "ICC").
    final qNorm = q.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final isIsolatedNewCase = _kIsolatedNewCaseTerms.contains(qNorm);

    // Também detecta: query curta que contém OUTRO fármaco de alta especificidade
    // diferente do fármaco ativo no thread (ex: thread=sertralina, query="ICC").
    // Não se aplica: nenhum fármaco detectado → só isIsolatedNewCase decide.
    final shortQueryDrugSwitch = (() {
      if (!isPlantaoMode) return false;
      final currentDrugShort = _detectPrimaryDrug(qNorm);
      final activeDrugShort = _detectPrimaryDrug(_activeTopic.toLowerCase());
      // Fármaco diferente do ativo → switch, mesmo query curta
      return currentDrugShort != null &&
          activeDrugShort != null &&
          currentDrugShort != activeDrugShort;
    })();

    // R20 — repetir a MESMA patologia isolada no Modo Estudo não muda de tema.
    // Corrige a sequência física: "Explicarme asma" -> "asma".
    final incomingStudyTopic = !isPlantaoMode ? _extractTopicSignature(q) : '';
    final sameStudyIsolatedTopic =
        !isPlantaoMode &&
        isIsolatedNewCase &&
        incomingStudyTopic.isNotEmpty &&
        incomingStudyTopic == _activeTopic;

    if (sameStudyIsolatedTopic) {
      _turnCount++;
      _lastActivityMs = now;
      if (kDebugMode) {
        debugPrint(
          '[R20][THREAD_MANAGER] mode=estudo '
          'action=continue_thread reason=study_same_topic_isolated_term '
          'topic=$_activeTopic turnCount=$_turnCount',
        );
      }
      return ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: 'study_same_topic_isolated_term',
        topic: _activeTopic,
      );
    }

    if (isIsolatedNewCase || shortQueryDrugSwitch) {
      final oldTopic = _activeTopic;
      _startNewThread(q, now);
      debugPrint(
        '[THREAD_MANAGER] mode=${isPlantaoMode ? "plantao" : "estudo"} '
        'action=new_thread '
        'reason=${isIsolatedNewCase ? "isolated_new_case_term" : "short_drug_switch"} '
        'oldTopic=$oldTopic newTopic=$_activeTopic '
        'query="$q"',
      );
      return ClinicalThreadStatus(
        action: ThreadAction.newThread,
        reason: isIsolatedNewCase
            ? 'isolated_new_case_term'
            : 'short_drug_switch',
        topic: _activeTopic,
      );
    }

    // ── Query muito curta / follow-up phrase → continuation ───────────────
    final isFollowUpPhrase = _kFollowUpPhrases.any(
      (p) => q == p || q.startsWith('$p ') || q.endsWith(' $p'),
    );
    final isTooShort = wordCount <= 3;
    final shortContextualFollowUp = isContextualClinicalFollowUp(
      currentUserText,
    );
    final shortFolded = q
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
    final shortTokens = RegExp(
      r'[a-z0-9]+',
    ).allMatches(shortFolded).map((match) => match.group(0)!).toSet();
    final shortStrongCardiacAlias = const <String>{
      'iamcsst',
      'iamcest',
      'iamssst',
      'iamsest',
      'stemi',
      'nstemi',
    }.any(shortTokens.contains);
    final shortThreadStartFolded = _threadStartQuery
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
    final shortCardiacCompatible =
        shortStrongCardiacAlias &&
        <String>[
          'torac',
          'peito',
          'precord',
          'angin',
          'coronar',
          'cardiac',
          'iam',
          'sca',
        ].any(shortThreadStartFolded.contains);
    final shortQueryClinicalSwitch =
        isPlantaoMode &&
        isTooShort &&
        !isFollowUpPhrase &&
        !shortContextualFollowUp &&
        (shortStrongCardiacAlias ||
            _kNewCaseSignals.any((signal) {
              final foldedSignal = signal
                  .replaceAll('á', 'a')
                  .replaceAll('é', 'e')
                  .replaceAll('í', 'i')
                  .replaceAll('ó', 'o')
                  .replaceAll('ú', 'u')
                  .replaceAll('ü', 'u')
                  .replaceAll('ç', 'c');
              if (foldedSignal.contains(' ')) {
                return shortFolded.contains(foldedSignal);
              }
              return shortTokens.contains(foldedSignal);
            })) &&
        !_topicsOverlap(_activeTopic, q) &&
        !shortCardiacCompatible;

    if (shortQueryClinicalSwitch) {
      final oldTopic = _activeTopic;
      _startNewThread(q, now);
      if (kDebugMode) {
        debugPrint(
          '[THREAD_MANAGER] mode=plantao '
          'action=new_thread reason=short_clinical_switch '
          'oldTopic=$oldTopic newTopic=$_activeTopic',
        );
      }
      return ClinicalThreadStatus(
        action: ThreadAction.newThread,
        reason: 'short_clinical_switch',
        topic: _activeTopic,
      );
    }

    if (isTooShort || isFollowUpPhrase) {
      _turnCount++;
      _lastActivityMs = now;
      if (kDebugMode) {
        debugPrint(
          '[THREAD_MANAGER] mode=${isPlantaoMode ? "plantao" : "estudo"} '
          'action=continue_thread reason=${isFollowUpPhrase ? "followup_phrase" : "short_query"} '
          'topic=$_activeTopic turnCount=$_turnCount',
        );
      }
      return ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: isFollowUpPhrase ? 'followup_phrase' : 'short_query',
        topic: _activeTopic,
      );
    }

    // ── BUILD 300: MODO ESTUDO — memória 100% linear, sem HARD RESET por tópico ──
    // No Modo Estudo (!isPlantaoMode) o estudo clínico expande e ramifica
    // naturalmente. "Asma → broncodilatador → efeitos adversos" é continuação
    // legítima mesmo sem overlap de palavras-chave. Nunca aplicar newThread por
    // no_topic_overlap / new_case_signal / drug_switch no Modo Estudo.
    // first_message e inactivity_timeout permanecem ativos em ambos os modos.
    if (!isPlantaoMode) {
      _turnCount++;
      _lastActivityMs = now;
      if (kDebugMode) {
        debugPrint(
          '[BUILD300][THREAD_MANAGER] mode=estudo '
          'action=continue_thread reason=study_mode_memory_preserved '
          'topic=$_activeTopic turnCount=$_turnCount',
        );
      }
      return ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: 'study_mode_memory_preserved',
        topic: _activeTopic,
      );
    }

    // ── Detecta mudança forte de tópico (APENAS Modo Plantão) ─────────────
    // BUILD 305 [C2]: matching seguro por palavra inteira para tokens curtos.
    // q já foi normalizado (lowercase, trim). Tokens com espaço (multi-palavra)
    // usam contains direto. Tokens sem espaço ≤ 4 chars usam RegExp \b para
    // evitar falso positivo: 'iam' em "vitamina", 'avc' em "travca", etc.
    // Tokens > 4 chars: contains é seguro (colisão léxica negligenciável).
    final qNormSig = ' $q '; // padding para word-boundary simplificado
    bool matchesNewCaseSignal(String signal) {
      if (signal == 'iam' &&
          RegExp(
            r'(^|[^a-z0-9])(?:iamcsst|iamcest|iamssst|iamsest|stemi|nstemi)([^a-z0-9]|$)',
          ).hasMatch(q)) {
        return true;
      }
      if (signal.contains(' ')) return q.contains(signal);
      if (signal.length <= 4) return qNormSig.contains(' $signal ');
      return q.contains(signal);
    }

    final hasNewCaseSignal = _kNewCaseSignals.any(matchesNewCaseSignal);
    final hasStrongNewCaseSignal = _kNewCaseSignals.any(
      (signal) =>
          !_kDemographicNewCaseSignals.contains(signal) &&
          matchesNewCaseSignal(signal),
    );

    // Detecta fármaco novo diferente do thread ativo
    final currentDrug = _detectPrimaryDrug(q);
    final activeDrug = _detectPrimaryDrug(_activeTopic.toLowerCase());
    final hasDrugSwitch =
        currentDrug != null && activeDrug != null && currentDrug != activeDrug;

    // Verifica overlap temático com o thread ativo
    final topicOverlap = _topicsOverlap(_activeTopic, q);
    final isContextualFollowUp = isContextualClinicalFollowUp(currentUserText);
    final foldedCurrent = q
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
    final richNarrativeFollowUp = _isRichClinicalNarrativeFollowUp(
      foldedCurrent,
    );
    final hasAcuteCoronaryAlias = RegExp(
      r'(^|[^a-z0-9])(?:iamcsst|iamcest|iamssst|iamsest|stemi|nstemi)([^a-z0-9]|$)',
    ).hasMatch(foldedCurrent);
    final threadStartFolded = _threadStartQuery
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
    final compatibleAcuteCoronaryProgression =
        hasAcuteCoronaryAlias &&
        <String>[
          'torac',
          'peito',
          'precord',
          'angin',
          'coronar',
          'cardiac',
          'iam',
          'sca',
        ].any(threadStartFolded.contains);

    // PLANTAO_EXPLICIT_CASE_BOUNDARY_PRECEDENCE_V1
    //
    // Fronteiras explícitas de caso/paciente são absolutas e precisam ser
    // avaliadas antes de qualquer continuação por progressão diagnóstica
    // compatível (ex.: IAMCEST -> IAMCEST em outro paciente).
    final explicitCaseBoundaryEarly = <String>[
      'novo caso',
      'nova paciente',
      'novo paciente',
      'outro paciente',
      'outra paciente',
      'mudar de caso',
      'trocar de caso',
      'nuevo caso',
      'nuevo paciente',
      'nueva paciente',
      'otro paciente',
      'otra paciente',
      'cambiar de caso',
      'new case',
      'new patient',
      'another patient',
    ].any(q.contains);

    if (explicitCaseBoundaryEarly) {
      final oldTopic = _activeTopic;
      _startNewThread(q, now);

      if (kDebugMode) {
        debugPrint('[THREAD_MANAGER] mode=plantao '
            'action=new_thread '
            'reason=new_case_signal '
            'oldTopic=$oldTopic newTopic=$_activeTopic');
      }

      return ClinicalThreadStatus(
        action: ThreadAction.newThread,
        reason: 'new_case_signal',
        topic: _activeTopic,
      );
    }

    // Uma confirmação de IAM/STEMI pode ser a progressão natural de uma queixa
    // torácica já ativa. Nesse caso preservamos o contexto; em qualquer tópico
    // incompatível (por exemplo, fossa ilíaca) o alias forte continua abaixo
    // para a regra canônica de newThread.
    if (isPlantaoMode && compatibleAcuteCoronaryProgression && !hasDrugSwitch) {
      _turnCount++;
      _lastActivityMs = now;
      if (kDebugMode) {
        debugPrint(
          '[THREAD_MANAGER] mode=plantao '
          'action=continue_thread reason=compatible_diagnostic_progression '
          'topic=$_activeTopic turnCount=$_turnCount',
        );
      }
      return ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: 'compatible_diagnostic_progression',
        topic: _activeTopic,
      );
    }

    // Resultados objetivos não precisam repetir o tópico. Narrativa clínica só
    // vence um sinal sintomático de novo caso quando contém múltiplos marcadores
    // de evolução/associação; isso evita transformar uma nova queixa isolada em
    // continuação por acidente.
    if (isContextualFollowUp &&
        !hasDrugSwitch &&
        (!hasStrongNewCaseSignal || topicOverlap || richNarrativeFollowUp)) {
      _turnCount++;
      _lastActivityMs = now;
      if (kDebugMode) {
        debugPrint(
          '[THREAD_MANAGER] mode=plantao '
          'action=continue_thread reason=contextual_clinical_followup '
          'topic=$_activeTopic turnCount=$_turnCount',
        );
      }
      return ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: 'contextual_clinical_followup',
        topic: _activeTopic,
      );
    }

    // PLANTAO_GLOBAL_SAME_TOPIC_SIGNAL_PRECEDENCE_V1
    //
    // Mencionar uma patologia/alias conhecido nao significa automaticamente
    // "novo caso". O overlap semantico do tema ativo vence o sinal generico.
    // Fronteiras explicitas de caso/paciente continuam absolutas.
    final explicitCaseBoundary = <String>[
      'novo caso',
      'nova paciente',
      'novo paciente',
      'outro paciente',
      'outra paciente',
      'mudar de caso',
      'trocar de caso',
      'nuevo caso',
      'nuevo paciente',
      'nueva paciente',
      'otro paciente',
      'otra paciente',
      'cambiar de caso',
      'new case',
      'new patient',
      'another patient',
    ].any(q.contains);

    final shouldStartNewThread =
        explicitCaseBoundary || hasDrugSwitch || !topicOverlap;

    if (shouldStartNewThread) {
      final oldTopic = _activeTopic;
      _startNewThread(q, now);

      final newThreadReason = explicitCaseBoundary ||
              (hasNewCaseSignal && !topicOverlap)
          ? 'new_case_signal'
          : (hasDrugSwitch ? 'drug_switch' : 'no_topic_overlap');

      if (kDebugMode) {
        debugPrint('[THREAD_MANAGER] mode=plantao '
            'action=new_thread '
            'reason=$newThreadReason '
            'oldTopic=$oldTopic newTopic=$_activeTopic');
      }
      return ClinicalThreadStatus(
        action: ThreadAction.newThread,
        reason: newThreadReason,
        topic: _activeTopic,
      );
    }

    // ── Mesmo tópico → continuation ───────────────────────────────────────
    _turnCount++;
    _lastActivityMs = now;
    if (kDebugMode) {
      debugPrint(
        '[THREAD_MANAGER] mode=${isPlantaoMode ? "plantao" : "estudo"} '
        'action=continue_thread reason=same_topic '
        'topic=$_activeTopic turnCount=$_turnCount',
      );
    }
    return ClinicalThreadStatus(
      action: ThreadAction.continueThread,
      reason: 'same_topic',
      topic: _activeTopic,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // buildThreadHistory() — constrói lista de histórico para enviar ao Gemini
  //
  // isContinuation=true  → últimas kMaxContinuationTurns pares (máx 6 entradas)
  // isContinuation=false → lista vazia (contexto limpo)
  // ─────────────────────────────────────────────────────────────────────────

  // BUILD 307 [AMNESIA_COOLDOWN]: fármaco-alvo primário da última mensagem.
  // Preserva histórico de transporte quando o médico muda de intent mas
  // mantém o mesmo fármaco-alvo (ex: "dose" → "mecanismo" da amiodarona).
  static String _lastDrugTarget = '';

  static List<Map<String, String>> buildThreadHistory({
    required List<Map<String, String>> fullHistory,
    required ClinicalThreadStatus status,
    required bool isPlantaoMode,
    String currentTaskLabel = '', // BUILD 304 [G1b]: label do intent atual
  }) {
    if (!isPlantaoMode) {
      // BUILD STUDY-30TURN: same active Study chat keeps verbatim transport
      // memory across task/subtask changes. The UI/local history stays intact;
      // provider transport is bounded to the last 30 exchanges (60 entries).
      _lastDrugTarget = _extractDrugFromHistory(fullHistory) ?? _lastDrugTarget;

      final maxEntries = kMaxStudyTurns * 2;
      final limited = fullHistory.length > maxEntries
          ? fullHistory.sublist(fullHistory.length - maxEntries)
          : List<Map<String, String>>.from(fullHistory);

      if (kDebugMode) {
        debugPrint(
          '[STUDY_30TURN][HISTORY_SANITIZER] mode=estudo '
          'strategy=verbatim_30_exchanges '
          'sent=${limited.length}/${fullHistory.length} '
          'taskLabel=$currentTaskLabel',
        );
      }
      return limited;
    }

    if (!status.isContinuation) {
      // Novo thread → histórico vazio
      if (kDebugMode) {
        debugPrint(
          '[HISTORY_SANITIZER] mode=plantao strategy=empty '
          'sent=0 removed=${fullHistory.length} '
          'reason=${status.reason}',
        );
      }
      return <Map<String, String>>[];
    }

    // PLANTAO_DEPENDENT_CLINICAL_FOLLOWUP_AND_CASE_ANCHOR_V1
    //
    // Continuation: manter a ancora do caso (primeiro par user+assistant)
    // + os kMaxContinuationTurns pares mais recentes.
    //
    // Motivo: somente "ultimos pares" perde o caso-base depois de varias
    // perguntas curtas ("por que?", "internacao?", "trombolise?" etc.).
    // A ancora preserva os dados clinicos originais sem reabrir cross-case:
    // newThread continua limpando todo o historico antes deste bloco.
    final maxRecentEntries = kMaxContinuationTurns * 2;
    final recent = fullHistory.length > maxRecentEntries
        ? fullHistory.sublist(fullHistory.length - maxRecentEntries)
        : List<Map<String, String>>.from(fullHistory);

    final anchor = <Map<String, String>>[];
    for (final entry in fullHistory) {
      final role = entry['role'];
      if (anchor.isEmpty && role == 'user') {
        anchor.add(entry);
        continue;
      }
      if (anchor.length == 1 && role == 'assistant') {
        anchor.add(entry);
        break;
      }
    }

    final anchored = <Map<String, String>>[];
    final seen = <String>{};

    void addUnique(Map<String, String> entry) {
      final key = '${entry['role']}\u0000${entry['content']}';
      if (seen.add(key)) anchored.add(entry);
    }

    for (final entry in anchor) {
      addUnique(entry);
    }
    for (final entry in recent) {
      addUnique(entry);
    }

    if (kDebugMode) {
      debugPrint(
        '[HISTORY_SANITIZER] mode=plantao '
        'strategy=case_anchor_plus_recent '
        'sent=${anchored.length} '
        'anchor=${anchor.length} recent=${recent.length} '
        'topic=${status.topic} '
        'reason=${status.reason}',
      );
    }
    return anchored;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // reset() — limpa estado de instância do thread (chamado ao limpar chat
  // ou logout). Pare resetar os campos estáticos de sessão (BUILD 304),
  // chame também resetStaticState().
  // ─────────────────────────────────────────────────────────────────────────
  void reset() {
    _activeTopic = '';
    _activeThreadId = '';
    _turnCount = 0;
    _lastActivityMs = 0;
    _threadStartQuery = '';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // resetStaticState() — Study/Plantao lifecycle cleanup.
  //
  // R9: TTL/taskLabel transport-reset state was removed. The remaining
  // static helper is _lastDrugTarget, cleared on logout/new conversation.
  // ─────────────────────────────────────────────────────────────────────────
  static void resetStaticState() {
    _lastDrugTarget = ''; // BUILD 307 [AMNESIA_COOLDOWN]: reset junto com label
    debugPrint(
      '[STUDY_30TURN][STATIC_RESET] _lastDrugTarget="" '
      '— static session state cleared (logout/new-conversation/hot-restart)',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _extractDrugFromHistory() — BUILD 307 [AMNESIA_COOLDOWN]
  //
  // Escaneia a mensagem de usuário mais recente no histórico em busca do
  // fármaco-alvo primário (mesmo conjunto _kHighSpecificityDrugs usado em
  // _detectPrimaryDrug). Retorna o primeiro match encontrado ou null.
  //
  // Usado exclusivamente em buildThreadHistory() para implementar o cooldown:
  // se o fármaco-alvo persiste após mudança de intent, o wipe é suprimido.
  // ─────────────────────────────────────────────────────────────────────────
  static String? _extractDrugFromHistory(List<Map<String, String>> history) {
    // Varre do fim para o início, busca a última mensagem do usuário
    final lastUser = history.lastWhere(
      (m) => (m['role'] ?? '') == 'user',
      orElse: () => const {},
    );
    final content = (lastUser['content'] ?? '').toLowerCase();
    if (content.isEmpty) return null;
    for (final drug in _kHighSpecificityDrugs) {
      if (content.contains(drug)) return drug;
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // primeFromHistory() — ORDEM 53 M1: reidrata thread a partir do histórico
  // restaurado (ex: retorno do background, restore de sessão do DB).
  //
  // PROBLEMA RAIZ DA AMNÉSIA:
  //   rebuildAiHistoryFromMessages() restaura _aiHistory (turnos de API), mas
  //   _threadManager permanece com _activeTopic='' (RAM-only, não persiste).
  //   A próxima mensagem do usuário cai em `_activeTopic.isEmpty → first_message`
  //   → ThreadAction.newThread → _aiHistory.clear() → contexto restaurado destruído.
  //
  // SOLUÇÃO: extrair a assinatura temática do último par user/assistant restaurado
  // e injetar em _activeTopic/_lastActivityMs para que evaluate() classifique
  // a próxima mensagem como continueThread (ou topic_shift real, se mudar de tema).
  //
  // [messages] — lista idêntica à passada em rebuildAiHistoryFromMessages()
  //              formato: [{role:'user', content:'...'}, {role:'assistant', content:'...'}]
  // ─────────────────────────────────────────────────────────────────────────
  void primeFromHistory(List<Map<String, String>> messages) {
    // Encontra a última mensagem do usuário no histórico restaurado
    final userMsgs = messages
        .where((m) => (m['role'] ?? '') == 'user')
        .toList();
    if (userMsgs.isEmpty) return; // sem contexto — mantém estado atual

    final lastUserText = userMsgs.last['content'] ?? '';
    if (lastUserText.isEmpty) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Conta pares user/assistant como turnCount aproximado
    final pairCount = userMsgs.length;

    // Reidrata o thread com o tópico extraído da última pergunta do usuário
    _activeTopic = _extractTopicSignature(lastUserText);
    _activeThreadId = '${nowMs}_restored_${_activeTopic.hashCode.abs()}';
    _turnCount = pairCount;
    // Marca _lastActivityMs como agora — evita inactivity_timeout imediato.
    // O Context Timeout de 5 min (O53 M3) aplica-se na camada de AppProvider,
    // não aqui — este timestamp previne apenas o timeout de 10min do ThreadManager.
    _lastActivityMs = nowMs;
    _threadStartQuery = lastUserText;

    if (kDebugMode) {
      debugPrint(
        '[THREAD_MANAGER] primeFromHistory: topic=$_activeTopic '
        'turnCount=$_turnCount restoredPairs=$pairCount '
        '— blindado contra first_message reset',
      );
    }
  }

  // ── Getters públicos ──────────────────────────────────────────────────────
  String get activeTopic => _activeTopic;
  String get activeThreadId => _activeThreadId;
  int get turnCount => _turnCount;
  bool get hasActiveThread => _activeTopic.isNotEmpty;

  // ── Helpers privados ──────────────────────────────────────────────────────

  void _startNewThread(String query, int nowMs) {
    _activeTopic = _extractTopicSignature(query);
    _activeThreadId = '${nowMs}_${_activeTopic.hashCode.abs()}';
    _turnCount = 1;
    _lastActivityMs = nowMs;
    _threadStartQuery = query;
  }

  // ── BUILD 305 [C1]: Stopwords PT-BR+ES — compartilhadas por _extract e _overlap ─
  // Extraída para const estático para evitar alocação por chamada e garantir
  // consistência na filtragem entre os dois métodos de análise temática.
  static const _kStopwords = <String>{
    // PT-BR
    'de', 'da', 'do', 'e', 'em', 'o', 'a', 'os', 'as', 'um', 'uma',
    'para', 'com', 'no', 'na', 'por', 'que', 'se', 'como', 'qual',
    'dos', 'das', 'mais', 'mas', 'seu', 'sua', 'este', 'esta',
    // ES (sem duplicatas do PT)
    'el', 'la', 'los', 'las', 'un', 'una', 'en', 'y', 'es', 'del',
    'con', 'cual', 'sus',
  };

  /// Extrai assinatura temática — BUILD 305 [C1]: take(4) → take(6).
  ///
  /// PROBLEMA ORIGINAL: take(4) capturava poucas palavras em queries longas.
  /// Inversão sintática simples ("IC com congestão" vs "congestão no paciente
  /// com IC") produzia assinaturas sem palavras em comum → falso newThread.
  ///
  /// SOLUÇÃO: take(6) amplia a janela de captura, aumentando a probabilidade
  /// de sobreposição de palavras-chave clínicas em reformulações naturais.
  // R20 — a intenção pedagógica não faz parte do nome do tema clínico.
  static String _foldStudyPedagogicalText(String value) {
    return value
        .trim()
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
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _stripStudyPedagogicalLead(String value) {
    var folded = _foldStudyPedagogicalText(value);
    if (folded.isEmpty) return '';

    // Wrapper de esclarecimento do R20 nunca pode virar identidade clínica.
    if (folded.startsWith('modo estudio aclaracion minima') ||
        folded.startsWith('modo estudo esclarecimento minimo')) {
      return '';
    }

    folded = folded
        .replaceFirst(
          RegExp(
            r'^(?:por favor\s+)?(?:'
            r'explicame|explicarme|explica me|explica|'
            r'me explica|me explique|pode me explicar|poderia me explicar|'
            r'puede explicarme|puedes explicarme|'
            r'fale sobre|hablame|cuentame|'
            r'quero entender|quiero entender|ensiname|ensename'
            r')(?:\s+(?:sobre|de|del|da|do|el|la|o|a))?(?:\s+|$)',
          ),
          '',
        )
        .trim();

    return folded;
  }

  String _extractTopicSignature(String query) {
    final canonicalQuery = _stripStudyPedagogicalLead(query);
    if (canonicalQuery.isEmpty) return '';

    final words = canonicalQuery
        .split(RegExp(r'\s+'))
        // M77_CLINICAL_TOPIC_GENERIC_PATIENT_TOKEN_FILTER_V1
        .where(
          (w) =>
              w.length > 3 &&
              !_kStopwords.contains(w) &&
              !const <String>{
                'paciente',
                'pacientes',
                'patient',
                'patients',
                // M77_SHORT_PROMPT_GENERIC_TASK_TOKEN_FILTER_V1
                'conduta',
                'conducta',
                'imediata',
                'imediato',
                'inmediata',
                'inmediato',
                'immediate',
                'management',
              }.contains(w),
        )
        .take(6)
        .toList();

    return words.join('_');
  }

  /// Verifica overlap temático — BUILD 305 [C1]: varredura bidirecional em 3 camadas.
  ///
  /// PROBLEMA ORIGINAL: apenas Set.intersection falhava em inversões sintáticas
  /// e morfologia flexionada (ex: "congestão" vs "congestionamento").
  ///
  /// SOLUÇÃO EM 3 CAMADAS:
  ///   Camada 1 — Set.intersection (O(n), rápido): sobreposição direta de tokens.
  ///   Camada 2 — Varredura direta: token do tópico ativo contido na nova query
  ///              (substring). Captura morfologia, siglas expandidas.
  ///   Camada 3 — Varredura reversa [NOVO]: token longo da nova query contido
  ///              no tópico ativo. Impede amnésia por inversão de ordem das
  ///              palavras ("congestão pulmonar" ↔ "congestao_pulmonar_ic").
  bool _topicsOverlap(String activeTopic, String newQuery) {
    activeTopic = _canonicalizePlantaoTopicAliases(activeTopic);
    newQuery = _canonicalizePlantaoTopicAliases(newQuery);

    if (activeTopic.isEmpty) return false;
    final topicWords = Set<String>.from(activeTopic.split('_'));
    final qLower = newQuery.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ');
    final queryWords = qLower
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !_kStopwords.contains(w))
        .toSet();

    // Camada 1: interseção direta de conjuntos
    if (topicWords.intersection(queryWords).isNotEmpty) return true;

    // Camada 2: palavra do tópico contida na query (substring) — morfologia
    for (final tw in topicWords) {
      if (tw.length > 4 && qLower.contains(tw)) return true;
    }

    // Camada 3 [BUILD 305 C1]: palavra longa da query contida no tópico ativo
    // Resolve inversões sintáticas: "congestão pulmonar" ↔ "congestao_pulmonar_ic"
    final topicFlat = activeTopic.replaceAll('_', ' ');
    for (final qw in queryWords) {
      if (qw.length > 4 && topicFlat.contains(qw)) return true;
    }

    return false;
  }

  /// Detecta fármaco primário na query
  String? _detectPrimaryDrug(String text) {
    for (final drug in _kHighSpecificityDrugs) {
      if (text.contains(drug)) return drug;
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ClinicalThreadAudit — helper para log de auditoria na inicialização
// ─────────────────────────────────────────────────────────────────────────────
class ClinicalThreadAudit {
  ClinicalThreadAudit._();

  /// Loga os componentes de contexto existentes encontrados no app.
  /// Chamado uma vez na inicialização do AppProvider.
  static void logFoundComponents() {
    if (!kDebugMode) return;
    debugPrint(
      '[THREAD_AUDIT] foundExisting=true '
      'components=ClinicalSessionMemory,_aiHistory,_sanitizedHistory,'
      'resetIfTopicChanged,_expandedQuery,ExternalToolLinkEngine,'
      'PlantaoIntentEngine,NextActionEngine',
    );
    debugPrint(
      '[THREAD_AUDIT] new_component=ClinicalThreadManager '
      'build=249 '
      'strategy=plantao:empty_on_new_thread,continuation:case_anchor_plus_recent(2pairs) '
      'estudo:full_history_unchanged',
    );
  }
}
