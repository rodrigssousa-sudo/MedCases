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

  // Timeout de inatividade: 10 minutos sem mensagem → novo thread automaticamente (Plantão)
  static const int kThreadTimeoutMs = 10 * 60 * 1000;

  // BUILD 304 [G3]: TTL de inatividade para Modo Estudo.
  // Se o médico ficar mais de 6h sem interagir, o histórico de transporte da
  // sessão de Estudo é descartado — evita continuidade pedagógica incoerente
  // (médico esqueceu o contexto; nova sessão começa limpa).
  // O histórico LOCAL no dispositivo é PRESERVADO para exibição visual.
  static const int kStudySessionTtlMs = 6 * 60 * 60 * 1000; // 6 horas

  // BUILD 304 [G1]: Janela micro-deslizante para Modo Estudo.
  // Médicos em Estudo realizam no máximo 4-5 interações por tema.
  // Enviar histórico completo (10+ turnos) é desperdício crítico de tokens.
  // Máx 4 turnos (2 pares user+assistant = 4 entradas) no payload da API.
  // O histórico completo permanece intacto no dispositivo para exibição.
  static const int kMaxStudyTurns = 2; // 2 pares = 4 entradas

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
        debugPrint('[BUILD300][THREAD_MANAGER] mode=estudo '
            'action=continue_thread reason=study_mode_memory_preserved '
            'topic=$_activeTopic turnCount=$_turnCount');
      }
      return ClinicalThreadStatus(
        action: ThreadAction.continueThread,
        reason: 'study_mode_memory_preserved',
        topic: _activeTopic,
      );
    }

    // ── Detecta mudança forte de tópico (APENAS Modo Plantão) ─────────────
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
        debugPrint('[THREAD_MANAGER] mode=plantao '
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
  // BUILD 304 [G3]: timestamp da última mensagem de Estudo (RAM-only).
  // Rastreia inatividade para aplicar TTL de 6h no histórico de transporte.
  static int _lastStudyActivityMs = 0;

  // BUILD 304 [G1b]: taskLabel da última mensagem (Plantão ou Estudo).
  // Usado para detectar mudança de intent e disparar reset silencioso.
  static String _lastTaskLabel = '';

  static List<Map<String, String>> buildThreadHistory({
    required List<Map<String, String>> fullHistory,
    required ClinicalThreadStatus status,
    required bool isPlantaoMode,
    String currentTaskLabel = '', // BUILD 304 [G1b]: label do intent atual
  }) {
    if (!isPlantaoMode) {
      // ── BUILD 304 [G3]: TTL de 6h para Modo Estudo ────────────────────────
      // Se o médico ficou inativo por mais de 6h, descarta o histórico de
      // transporte — nova sessão começa limpa sem contaminação de contexto antigo.
      // O histórico LOCAL permanece intacto para exibição visual.
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // ── PURIF-3b BUILD 304: Defesa contra clock-drift (web/Safari) ───────
      // Abas em suspensão profunda podem sofrer skew de relógio: ao acordar,
      // DateTime.now() pode retornar um valor ligeiramente MENOR que o registrado
      // em _lastStudyActivityMs (delta negativo). Isso nunca expiraria o TTL.
      // Tratamento: se delta < 0 (clock retroativo detectado), resetamos o
      // baseline silenciosamente — a sessão reinicia sem quebra de runtime.
      final rawDelta = _lastStudyActivityMs > 0 ? nowMs - _lastStudyActivityMs : 0;
      if (rawDelta < 0) {
        // Clock retroativo: realinha baseline sem descartar histórico.
        _lastStudyActivityMs = nowMs;
        debugPrint('[BUILD304][CLOCK_DRIFT] delta_negativo=$rawDelta ms '
            '— baseline realinhado silenciosamente (web tab wakeup)');
      }
      final studyInactiveMs = rawDelta < 0 ? 0 : rawDelta;
      final studySessionExpired = studyInactiveMs > kStudySessionTtlMs;

      if (studySessionExpired && fullHistory.isNotEmpty) {
        _lastStudyActivityMs = nowMs;
        _lastTaskLabel = currentTaskLabel;
        debugPrint('[BUILD304][STUDY_TTL] session_expired inactiveMs=$studyInactiveMs '
            'ttlMs=$kStudySessionTtlMs → transport_history_cleared '
            'localHistory=${fullHistory.length} preserved');
        return <Map<String, String>>[];
      }

      // ── BUILD 304 [G1b]: Reset silencioso por mudança de intent ───────────
      // Se o taskLabel mudou (ex: 'geral' → 'dose'), o médico trocou de assunto.
      // Descarta histórico de transporte — novo tema começa com contexto limpo.
      final intentChanged = _lastTaskLabel.isNotEmpty &&
          currentTaskLabel.isNotEmpty &&
          currentTaskLabel != _lastTaskLabel;

      if (intentChanged && fullHistory.isNotEmpty) {
        _lastStudyActivityMs = nowMs;
        _lastTaskLabel = currentTaskLabel;
        debugPrint('[BUILD304][INTENT_RESET] taskLabel changed: '
            '$_lastTaskLabel → $currentTaskLabel '
            '→ transport_history_cleared (local preserved)');
        return <Map<String, String>>[];
      }

      // ── BUILD 304 [G1]: Janela micro-deslizante — Modo Estudo ─────────────
      // Retém apenas as últimas kMaxStudyTurns trocas (4 entradas).
      // Elimina desperdício de tokens em threads longos de Estudo.
      // Histórico local no dispositivo NÃO é modificado.
      _lastStudyActivityMs = nowMs;
      _lastTaskLabel = currentTaskLabel;

      final maxEntries = kMaxStudyTurns * 2;
      final limited = fullHistory.length > maxEntries
          ? fullHistory.sublist(fullHistory.length - maxEntries)
          : fullHistory;

      if (kDebugMode) {
        debugPrint('[BUILD304][HISTORY_SANITIZER] mode=estudo '
            'strategy=micro_window_4turns '
            'sent=${limited.length}/${fullHistory.length} '
            'ttlOk=true intentLabel=$currentTaskLabel');
      }
      return limited;
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
  // resetStaticState() — BUILD 304 PURIF-1: limpa campos estáticos de sessão.
  //
  // PROBLEMA RESOLVIDO — GAP DE HOT-RESTART / TROCA DE CONTA:
  //   _lastStudyActivityMs e _lastTaskLabel são static — sobrevivem ao dispose()
  //   do AppProvider e ao logout. Num hot-restart ou troca de conta sem reinício
  //   completo do processo, esses valores ficam "fantasmas" da sessão anterior:
  //   • _lastTaskLabel stale → intent-reset falso positivo na primeira mensagem
  //   • _lastStudyActivityMs stale → TTL de 6h calculado incorretamente
  //
  // SOLUÇÃO: chamar resetStaticState() JUNTO com reset() em todo ponto de logout
  // ou limpeza de conversa, garantindo que a próxima sessão sempre comece do zero.
  // ─────────────────────────────────────────────────────────────────────────
  static void resetStaticState() {
    _lastStudyActivityMs = 0;
    _lastTaskLabel = '';
    debugPrint('[BUILD304][STATIC_RESET] _lastStudyActivityMs=0 _lastTaskLabel="" '
        '— static session state cleared (logout/new-conversation/hot-restart)');
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
      debugPrint('[THREAD_MANAGER] primeFromHistory: topic=$_activeTopic '
          'turnCount=$_turnCount restoredPairs=$pairCount '
          '— blindado contra first_message reset');
    }
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
