// ══════════════════════════════════════════════════════════════════════════════
// clinical_thread_manager.dart — Clinical Thread & Context Manager (Build 249)
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
  newThread,      // novo caso / tema diferente → limpar histórico
}

class ClinicalThreadStatus {
  final ThreadAction action;
  final String reason;      // para log
  final String topic;       // tópico ativo (novo ou mantido)
  final bool fromButton;    // veio de botão clínico

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
  int    _turnCount = 0;
  int    _lastActivityMs = 0;

  // Última pergunta do usuário que INICIOU o thread ativo
  String _threadStartQuery = '';

  // Máximo de turnos de histórico a enviar em modo continuation
  // ORDEM 19: reduzido para 2 pares (= 4 entradas) — payload enxuto, máxima velocidade.
  // Lógica: 1 par anterior (user+assistant) + query atual = contexto mínimo eficaz.
  // Evita avalanche de tokens redundantes sem perder continuidade do turno imediato.
  static const int kMaxContinuationTurns = 2; // 2 pares user/assistant = 4 entradas

  // Timeout de inatividade: 10 minutos sem mensagem → novo thread automaticamente
  static const int kThreadTimeoutMs = 10 * 60 * 1000;

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

  // ── Keywords de novo caso — qualquer uma dessas em query longa → new thread ─
  // Sintomas sistêmicos sem relação farmacológica = novo caso clínico
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
    'gastroenterite', 'gastroenteritis', 'gastrenterite',
    'pneumonia', 'meningite', 'meningitis',
    'infarto', 'iam ', ' iam', 'tep ', ' tep',
    'avc ', ' avc', 'acidente vascular',
    'sepse', 'sepsis', 'choque',
    'anafilaxia', 'anafilaxia', 'anafilaxis',
    'intoxicação', 'intoxicacion',
  ];

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
    'psa', 'psa.',  // pancreatite aguda severa
    'hemorragia digestiva', 'hdab', 'hdai',
    // Obstétrico
    'eclampsia', 'preeclampsia',
    'hellp',
  };

  // ── Fármacos de alta especificidade (detectar mudança de fármaco-alvo) ─────
  static const _kHighSpecificityDrugs = <String>[
    'amiodarona', 'amiodarone',
    'vancomicina', 'vancomycin',
    'noradrenalina', 'norepinefrina',
    'heparina', 'heparin',
    'insulina', 'insulin',
    'warfarina', 'varfarina',
    'metformina', 'metformin',
    'prednisona', 'prednisolona',
    'furosemida', 'furosemide',
    'metoprolol', 'propranolol',
    'enalapril', 'captopril', 'losartana',
    'ceftriaxona', 'meropenem', 'piperacilina',
    'midazolam', 'propofol', 'fentanil',
    'ketamina', 'etomidato',
    'succinilcolina', 'rocurônio',
    'adrenalina', 'epinefrina',
    'dopamina', 'dobutamina',
    'nitroprussiato', 'nitroglicerina',
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
    if (_activeTopic.isNotEmpty &&
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
        debugPrint('[THREAD_MANAGER] mode=${isPlantaoMode ? "plantao" : "estudo"} '
            'action=continue_thread reason=button_action '
            'topic=$_activeTopic turnCount=$_turnCount');
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
      final activeDrugShort  = _detectPrimaryDrug(_activeTopic.toLowerCase());
      // Fármaco diferente do ativo → switch, mesmo query curta
      return currentDrugShort != null &&
             activeDrugShort  != null &&
             currentDrugShort != activeDrugShort;
    })();

    if (isIsolatedNewCase || shortQueryDrugSwitch) {
      final oldTopic = _activeTopic;
      _startNewThread(q, now);
      debugPrint('[THREAD_MANAGER] mode=${isPlantaoMode ? "plantao" : "estudo"} '
          'action=new_thread '
          'reason=${isIsolatedNewCase ? "isolated_new_case_term" : "short_drug_switch"} '
          'oldTopic=$oldTopic newTopic=$_activeTopic '
          'query="$q"');
      return ClinicalThreadStatus(
        action: ThreadAction.newThread,
        reason: isIsolatedNewCase ? 'isolated_new_case_term' : 'short_drug_switch',
        topic: _activeTopic,
      );
    }

    // ── Query muito curta / follow-up phrase → continuation ───────────────
    final isFollowUpPhrase = _kFollowUpPhrases.any((p) => q == p || q.startsWith('$p ') || q.endsWith(' $p'));
    final isTooShort = wordCount <= 3;

    if (isTooShort || isFollowUpPhrase) {
      _turnCount++;
      _lastActivityMs = now;
      if (kDebugMode) {
        debugPrint('[THREAD_MANAGER] mode=${isPlantaoMode ? "plantao" : "estudo"} '
            'action=continue_thread reason=${isFollowUpPhrase ? "followup_phrase" : "short_query"} '
            'topic=$_activeTopic turnCount=$_turnCount');
      }
      return ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: isFollowUpPhrase ? 'followup_phrase' : 'short_query',
        topic: _activeTopic,
      );
    }

    // ── Detecta mudança forte de tópico ───────────────────────────────────
    final hasNewCaseSignal = _kNewCaseSignals.any((s) => q.contains(s));

    // Detecta fármaco novo diferente do thread ativo
    final currentDrug = _detectPrimaryDrug(q);
    final activeDrug  = _detectPrimaryDrug(_activeTopic.toLowerCase());
    final hasDrugSwitch = currentDrug != null &&
        activeDrug != null &&
        currentDrug != activeDrug;

    // Verifica overlap temático com o thread ativo
    final topicOverlap = _topicsOverlap(_activeTopic, q);

    if (hasNewCaseSignal || hasDrugSwitch || !topicOverlap) {
      final oldTopic = _activeTopic;
      final newTopicSignature = _extractTopicSignature(currentUserText);
      _startNewThread(q, now);

      if (kDebugMode) {
        debugPrint('[THREAD_MANAGER] mode=${isPlantaoMode ? "plantao" : "estudo"} '
            'action=new_thread '
            'reason=${hasNewCaseSignal ? "new_case_signal" : (hasDrugSwitch ? "drug_switch" : "no_topic_overlap")} '
            'oldTopic=$oldTopic newTopic=$_activeTopic');
      }
      return ClinicalThreadStatus(
        action: ThreadAction.newThread,
        reason: hasNewCaseSignal
            ? 'new_case_signal'
            : (hasDrugSwitch ? 'drug_switch' : 'no_topic_overlap'),
        topic: _activeTopic,
      );
    }

    // ── Mesmo tópico → continuation ───────────────────────────────────────
    _turnCount++;
    _lastActivityMs = now;
    if (kDebugMode) {
      debugPrint('[THREAD_MANAGER] mode=${isPlantaoMode ? "plantao" : "estudo"} '
          'action=continue_thread reason=same_topic '
          'topic=$_activeTopic turnCount=$_turnCount');
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
  static List<Map<String, String>> buildThreadHistory({
    required List<Map<String, String>> fullHistory,
    required ClinicalThreadStatus status,
    required bool isPlantaoMode,
  }) {
    if (!isPlantaoMode) {
      // Modo Estudo: não interfere — usa history completo sanitizado
      final sent = fullHistory.length;
      if (kDebugMode) {
        debugPrint('[HISTORY_SANITIZER] mode=estudo strategy=full sent=$sent');
      }
      return fullHistory;
    }

    if (!status.isContinuation) {
      // Novo thread → histórico vazio
      if (kDebugMode) {
        debugPrint('[HISTORY_SANITIZER] mode=plantao strategy=empty '
            'sent=0 removed=${fullHistory.length} '
            'reason=${status.reason}');
      }
      return <Map<String, String>>[];
    }

    // Continuation → mínimo: últimos kMaxContinuationTurns pares
    // Cada par = 1 user + 1 assistant = 2 entradas
    final maxEntries = kMaxContinuationTurns * 2;
    final limited = fullHistory.length > maxEntries
        ? fullHistory.sublist(fullHistory.length - maxEntries)
        : fullHistory;

    if (kDebugMode) {
      debugPrint('[HISTORY_SANITIZER] mode=plantao strategy=thread_minimal '
          'sent=${limited.length} '
          'topic=${status.topic} '
          'reason=${status.reason}');
    }
    return limited;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // reset() — limpa estado do thread (chamado ao limpar chat ou logout)
  // ─────────────────────────────────────────────────────────────────────────
  void reset() {
    _activeTopic = '';
    _activeThreadId = '';
    _turnCount = 0;
    _lastActivityMs = 0;
    _threadStartQuery = '';
  }

  // ── Getters públicos ──────────────────────────────────────────────────────
  String get activeTopic => _activeTopic;
  String get activeThreadId => _activeThreadId;
  int    get turnCount => _turnCount;
  bool   get hasActiveThread => _activeTopic.isNotEmpty;

  // ── Helpers privados ──────────────────────────────────────────────────────

  void _startNewThread(String query, int nowMs) {
    _activeTopic = _extractTopicSignature(query);
    _activeThreadId = '${nowMs}_${_activeTopic.hashCode.abs()}';
    _turnCount = 1;
    _lastActivityMs = nowMs;
    _threadStartQuery = query;
  }

  /// Extrai assinatura temática (3 palavras-chave relevantes)
  String _extractTopicSignature(String query) {
    // PT-BR + ES stopwords (unique per language to avoid const-set duplicate error)
    final stopwords = <String>{
      // PT-BR
      'de', 'da', 'do', 'e', 'em', 'o', 'a', 'os', 'as', 'um', 'uma',
      'para', 'com', 'no', 'na', 'por', 'que', 'se', 'como', 'qual',
      // ES (deduplicar vs PT)
      'el', 'la', 'los', 'las', 'un', 'una', 'en', 'y', 'es', 'del',
      'con', 'cual',
    };
    final words = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !stopwords.contains(w))
        .take(4)
        .toList();
    return words.join('_');
  }

  /// Verifica overlap temático entre thread ativo e nova query
  bool _topicsOverlap(String activeTopic, String newQuery) {
    if (activeTopic.isEmpty) return false;
    final topicWords = Set<String>.from(activeTopic.split('_'));
    final queryWords = newQuery
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toSet();
    // Overlap direto de palavras-chave
    if (topicWords.intersection(queryWords).isNotEmpty) return true;
    // Verifica se alguma palavra do tópico aparece como substring na query
    for (final tw in topicWords) {
      if (tw.length > 4 && newQuery.toLowerCase().contains(tw)) return true;
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
    debugPrint('[THREAD_AUDIT] foundExisting=true '
        'components=ClinicalSessionMemory,_aiHistory,_sanitizedHistory,'
        'resetIfTopicChanged,_expandedQuery,ExternalToolLinkEngine,'
        'PlantaoIntentEngine,NextActionEngine');
    debugPrint('[THREAD_AUDIT] new_component=ClinicalThreadManager '
        'build=249 '
        'strategy=plantao:empty_on_new_thread,continuation:thread_minimal(3pairs) '
        'estudo:full_history_unchanged');
  }
}
