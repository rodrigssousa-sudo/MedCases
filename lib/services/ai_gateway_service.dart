import 'study/study_canonical_response.dart';
import 'study/study_hybrid_response.dart';
import 'study_response_contract.dart';
import 'plantao_presentation_contract.dart';
import 'provider_router_service.dart' show ProviderRouterService;
import 'ai/safety/clinical_request_safety.dart';
// ══════════════════════════════════════════════════════════════════════════════
// ModeAnchorEngine / AiGatewayService — Build 225 (Intent Engine Multidimensional)
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  PIVÔ ARQUITETURAL — Build 156                                          │
// │                                                                         │
// │  O backend Node.js/Express (server.js no Digital Ocean) foi um          │
// │  "backend fantasma": medcasespro.com serve apenas arquivos estáticos    │
// │  Flutter Web e retorna 405 Method Not Allowed para qualquer POST.       │
// │                                                                         │
// │  NOVA ARQUITETURA (Serverless / Descentralizado):                       │
// │    Flutter → generativelanguage.googleapis.com (direto, chave do app)  │
// │    GeminiServiceV2.sendStream() é o canal principal de novo.            │
// └─────────────────────────────────────────────────────────────────────────┘
//
// LÓGICA DOS 2 MOTORES — MIGRADA PARA O DART (Client-Side):
//   A separação Plantão / Estudos que existia no servidor Node como rotas
//   separadas (/api/ai/stream/plantao e /api/ai/stream/estudo) agora é
//   implementada aqui como injeção de âncora de modo no systemPrompt,
//   ANTES de chamar GeminiServiceV2.sendStream().
//
//   Motor Guardia (longResponse=false):
//     → Injeta MODE_ANCHOR_GUARDIA no topo do systemPrompt
//     → Limite: 14-18 linhas CONTEÚDO REAL (brancas/separadores excluídos)
//     → Jefe de Guardia — 5 blocos: 🟥 💊 🔄B 🔄C ⛔ 📌
//     → Plano B + Plano C explícitos para alergias/contraindicações cruzadas
//
//   Motor Estudos (longResponse=true):
//     → Injeta MODE_ANCHOR_ESTUDO no topo do systemPrompt
//     → Limite calibrado: 24-30 linhas | Preceptor de Faculdade de Medicina
//     → Parágrafo 4 (doses/fármacos) CONDICIONAL — omitido em perguntas teóricas
//     → Memória ativa: PROIBIDO repetir conteúdo do histórico
//     → Gancho de continuação em 1ª pessoa do usuário (ativa botão de sugestão)
//     → RAG Override Rule: reformata conteúdo estático em voz de preceptor
//
// INTERFACE PÚBLICA (zero breaking changes vs Build 155.2):
//   AiGatewayService.sendStream(...)       → shim de compatibilidade
//   ModeAnchorEngine.injectModeAnchor(...) → injeção direta de âncora
//   kAiGatewayBaseUrl                      → string vazia (legado)
//
// FLUXO DE DADOS Build 229:
//   app_provider.sendAiMessage()
//     → AiService.buildClinicalSystemPrompt()   [monta prompt base]
//     → AiGatewayService.sendStream()            [shim]
//       → _classifyIntent()                     [detecta gotas/ampola/conduta]
//       → ModeAnchorEngine.injectModeAnchor()   [âncora + mandato de intent → system_instruction]
//       → GeminiServiceV2.sendStream()           [SSE direto para Google]
//         system_instruction: âncora + systemPrompt + mandato de intent (NUNCA vaza)
//         contents:           userMessage LIMPA (sem mandato — elimina prompt leak)
//         → generativelanguage.googleapis.com   [API Google — chave do app]
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'ai_pipeline/ai_request_contract.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'gemini_service_v2.dart';
import 'gemini_cache_service.dart'; // BUILD 278: Context Caching nativo
import 'ai_smart_router.dart';    // Build 190: Smart Context Router
import 'plantao_pipeline.dart';   // Build 224: PlantaoIntentClassifier
import 'ai_pipeline/plantao/contracts/plantao_canonical_route_decision.dart';

// ── Import condicional — mantido apenas para compilação sem erros ─────────────
// Os arquivos _io e _web (implementações SSE para o gateway Node) não são
// mais chamados no fluxo principal (Build 156). GeminiServiceV2 usa seu
// próprio pipeline SSE interno. A importação permanece para evitar erros
// de compilação caso haja referências indiretas.


// MEDCASES_APPLE_PRERELEASE_AI_MODE_ISOLATION_V1_B_R0
/// Immutable mode envelope. Transport-specific clinical context remains intact.
class PreparedAiModePrompt {
  final AiRequestMode mode;
  final String systemPrompt;
  final String anchor;
  final String contract;

  const PreparedAiModePrompt._({
    required this.mode,
    required this.systemPrompt,
    required this.anchor,
    required this.contract,
  });

  bool get longResponse => mode == AiRequestMode.estudo;
  bool get isPlantaoMode => mode == AiRequestMode.plantao;
  String get providerMode => mode.name;
  String get contractName =>
      isPlantaoMode ? 'CONTRACT_PLANTAO' : 'CONTRACT_ESTUDO';
}

/// Reuses the existing instructions verbatim; never shrinks clinical context.
/// Idempotent for the same mode, fail-closed for an opposite mode envelope.
PreparedAiModePrompt prepareAiRequestPrompt({
  required AiRequestMode mode,
  required String systemPrompt,
  bool hasSpecificContext = false,
}) {
  final isPlantao = mode == AiRequestMode.plantao;
  final anchor = isPlantao ? _modeAnchorPlantao : _modeAnchorEstudo;
  final otherAnchor = isPlantao ? _modeAnchorEstudo : _modeAnchorPlantao;
  final contract = AiSmartRouter.modeContract(
    isPlantaoMode: isPlantao,
    hasSpecificContext: hasSpecificContext,
  );
  final otherContract = AiSmartRouter.modeContract(isPlantaoMode: !isPlantao);
  if (systemPrompt.contains(otherAnchor) ||
      systemPrompt.contains(otherContract) ||
      (isPlantao == false &&
          systemPrompt.contains(AiSmartRouter.modeContract(
            isPlantaoMode: true,
            hasSpecificContext: true,
          )))) {
    throw StateError('AI_MODE_CONTRACT_MISMATCH');
  }
  final body = systemPrompt.contains(contract)
      ? systemPrompt
      : '$contract\n\n$systemPrompt';
  final prepared = body.contains(anchor) ? body : '$anchor\n\n$body';
  return PreparedAiModePrompt._(
    mode: mode,
    systemPrompt: prepared,
    anchor: anchor,
    contract: contract,
  );
}

// ── Build 232: Auditoria temporária de tamanho de prompt ─────────────────────
// Remover após diagnóstico. NÃO imprime conteúdo clínico — apenas tamanhos.
// ignore: constant_identifier_names
const bool kPromptSizeAudit = true;

// ─────────────────────────────────────────────────────────────────────────────
// Study output instructions: language and flexible explanatory structure.
// No rigid line/word cap and no exposed validation checklist.
String _buildOutputCompactDirective(String lang) =>
    StudyResponseContract.forLanguage(lang);

// ─────────────────────────────────────────────────────────────────────────────
// Constante de legado — mantida para zero breaking changes
// Build 156: VAZIO — não há servidor gateway.
// ─────────────────────────────────────────────────────────────────────────────
const String kAiGatewayBaseUrl = '';

// ─────────────────────────────────────────────────────────────────────────────
// MODE_ANCHOR_GUARDIA — Motor de Guardia/Plantão (Build 225)
//
// Build 225: Intent Engine Clínico Multidimensional
//   - Título 🟥 SEMPRE específico: "FÁRMACO — classe farmacológica"
//   - Template de emojis varia conforme intenção + contexto + complexidade
//   - Proibições de Build 223 preservadas (TRATAMENTO FARMACOLÓGICO, etc.)
//   - Negrito REDUZIDO: apenas nome de fármaco, dose final, valor crítico
//   - intentMandate Build 225 injeta: topic, subtitle, context, complexity
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorPlantao = PlantaoPresentationContract.anchor +
    '\nREGRA DE RITMO: ASSISTOLIA/AESP = NÃO CHOCÁVEL; FV/TVSP = CHOCÁVEL.\n'
    'ASSISTOLIA/AESP: NÃO indicar desfibrilação/choque e NÃO escrever que adrenalina depende de choque.\n'
    'Adrenalina 1 mg IV/IO o mais cedo possível; repetir a cada 3–5 min, com RCP de alta qualidade e causas reversíveis.\n'
    'Choque/desfibrilação e amiodarona pertencem SOMENTE ao ramo FV/TVSP.\n';

const String _modeAnchorEstudo =
    '[MODO ESTUDO — PRECEPTOR SÊNIOR DE FACULDADE DE MEDICINA]\n'
    'Aprofunde o aspecto solicitado no idioma ativo do app. '
    'Preserve o tópico dos follow-ups desta conversa. '
    'O contrato estudo_rules define a estrutura didática flexível; '
    'não aplique compressão operacional do Plantão.\n';
// ─────────────────────────────────────────────────────────────────────────────

// Build 190 — LANGUAGE LOCK ABSOLUTO
//
// _detectLanguage foi REMOVIDA. A detecção por idioma da pergunta era a causa
// raiz de respostas mistas PT+ES (o modelo seguia o idioma da query, não do app).
//
// Substituída por _resolveAppLanguage: retorna appLanguage diretamente.
// appLanguage = _lang do AppProvider ('pt' | 'es') — configurado pelo usuário.
// A pergunta pode estar em QUALQUER idioma. A resposta usa EXCLUSIVAMENTE appLanguage.
// ─────────────────────────────────────────────────────────────────────────────
String _resolveAppLanguage(String appLanguage) {
  // Única variável soberana: appLanguage
  // Aceita 'pt' ou 'es'. Qualquer outro valor → fallback 'pt'.
  if (appLanguage == 'es') return 'es';
  return 'pt'; // 'pt' e qualquer fallback
}

// ─────────────────────────────────────────────────────────────────────────────
// _buildLanguageLock — Bloco de trava de idioma absoluta (Build 230)
//
// Injeta no system_instruction um mandato de trava total de idioma:
//   - Declara o idioma detectado como obrigatório exclusivo
//   - Proíbe explicitamente o outro idioma com exemplos de tokens proibidos
//   - Proíbe Portunhol (mistura de tokens de ambos os idiomas)
//
// Esta string é adicionada ao FINAL do system_instruction para explorar
// o Viés de Recência — o modelo lê as instruções mais recentes por último
// e as segue com maior fidelidade.
// ─────────────────────────────────────────────────────────────────────────────
String _buildLanguageLock(String lang) {
  if (lang == 'es') {
    return '\n\n[TRAVA DE IDIOMA ABSOLUTA — ESPAÑOL (BUILD 248)]\n'
        'IDIOMA SOBERANO DO APP: ESPAÑOL. ESTA TRAVA É IRREVOGÁVEL.\n'
        'IGNORA O IDIOMA DA PERGUNTA DO USUÁRIO.\n'
        'Não importa se a pergunta é em português, inglês ou misturada.\n'
        'Responde obligatoriamente en español. El idioma soberano es el configurado en la app.\n'
        '  ✗ Proibido: "prescrição", "dilua", "ampola", "soro", "não"\n'
        '  ✗ Proibido: "então", "também", "tratamento" (forma PT)\n'
        '  ✗ Proibido: qualquer mistura de tokens PT+ES (Portunhol)\n'
        '  ✓ Obrigatório: "ampolla" (ES), "Solución Salina" (ES), "dilución"\n'
        'ZERO portunhol. 100% puro em ESPAÑOL. Nem um token em outro idioma.';
  } else {
    return '\n\n[TRAVA DE IDIOMA ABSOLUTA — PORTUGUÊS-BR (BUILD 248)]\n'
        'IDIOMA SOBERANO DO APP: PORTUGUÊS-BR. ESTA TRAVA É IRREVOGÁVEL.\n'
        'IGNORA O IDIOMA DA PERGUNTA DO USUÁRIO.\n'
        'Não importa se a pergunta é em espanhol, inglês ou misturada.\n'
        'Responda obrigatoriamente em português-BR. O idioma soberano é o configurado no app.\n'
        '  ✗ Proibido: "solución", "dilución", "ampolla" (ES)\n'
        '  ✗ Proibido: artigos "el/la/los/las", pronomes "lo/le/se" (ES)\n'
        '  ✗ Proibido: qualquer mistura de tokens ES+PT (Portunhol)\n'
        '  ✓ Obrigatório: "ampola" (PT), "Soro Fisiológico" (PT)\n'
        '  ✓ Obrigatório: "administrar", "dilua", "correr em BIC"\n'
        'ZERO portunhol. 100% puro em PORTUGUÊS-BR. Nem um token em outro idioma.';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ModeAnchorEngine — Injeção de âncora de modo (Build 157)
// ─────────────────────────────────────────────────────────────────────────────
class ModeAnchorEngine {
  ModeAnchorEngine._(); // utilitário estático

  /// Retorna a âncora de modo correspondente ao motor selecionado.
  ///
  /// Build 157.1: NÃO mais concatena com systemPrompt — a âncora é
  /// passada como PART SEPARADO (modeAnchor) para GeminiServiceV2,
  /// onde será a PRIMEIRA parte de system_instruction.parts[] e terá
  /// PRIORIDADE ABSOLUTA sobre o _systemPromptPrefix.
  ///
  /// [longResponse]=false → _modeAnchorPlantao (14-18 linhas conteúdo real, Jefe de Guardia)
  /// [longResponse]=true  → _modeAnchorEstudo  (didática flexível, sem contagem de linhas)
  static String getModeAnchor({bool longResponse = false}) {
    final anchor = longResponse ? _modeAnchorEstudo : _modeAnchorPlantao;
    debugPrint(
      '[ModeAnchorEngine] Build 229: motor=${longResponse ? "ESTUDO" : "GUARDIA"} '
      'âncora obtida (${anchor.length} chars) — isolada em system_instruction',
    );
    return anchor;
  }

  /// Build 230: Arquitetura Sanduíche com Isolamento Total de Mandato + Language Lock.
  /// - Topo: âncora (contrato de formato + idioma)
  /// - Meio: systemPrompt do AiService (contexto RAG clínico)
  /// - Final: reforço mandatório + mandato de intent + trava de idioma absoluta
  ///
  /// CRÍTICO — Prompt Leak Fix (Build 226→229):
  ///   [intentMandate] é injetado AQUI (em system_instruction), NÃO na
  ///   user message. Isso garante que o mandato nunca apareça em contents[]
  ///   e portanto NUNCA pode ser ecoado pelo modelo na resposta.
  ///
  /// Build 230 — Language Lock:
  ///   [languageLock] é o bloco de trava de idioma PT/ES construído por
  ///   _buildLanguageLock(). Injetado como ÚLTIMA instrução do system_instruction
  ///   para maximizar o Viés de Recência — o modelo o lê por último.
  ///
  /// Modo Estudo: âncora + systemPrompt + language lock.
  static String injectModeAnchor(
    String systemPrompt, {
    bool longResponse = false,
    String intentMandate = '',  // Build 229: mandato de intent isolado no system
    String languageLock  = '',  // Build 230: trava de idioma absoluta PT/ES
  }) {
    final anchor = getModeAnchor(longResponse: longResponse);
    final langSuffix = languageLock.isNotEmpty ? languageLock : '';

    // Modo Estudo: âncora + systemPrompt + language lock final.
    if (longResponse) {
      return '$anchor\n\n$systemPrompt$langSuffix';
    }

    // Modo Plantão: Sanduíche — reforço final explora Viés de Recência.
    // Build 224: cláusula anti-History-Style-Bleeding.
    // Build 229: intentMandate anexado ao final do system_instruction —
    //   garante que o mandato de gotas/ampola/conduta seja lido como
    //   instrução de sistema e NUNCA como turno de conversa do usuário.
    // Build 230: languageLock como ÚLTIMA instrução (Viés de Recência máximo).
    final intentSuffix = intentMandate.isNotEmpty
        ? '\n\n[MANDATO DE INTENT PARA ESTE TURNO]\n$intentMandate'
        : '';

    return '$anchor\n\n'
        '[INÍCIO DO CONTEXTO CLÍNICO DO APLICATIVO]\n'
        '$systemPrompt\n\n'
        '[REFORÇO MANDATÓRIO DE FORMATO DE SAÍDA - LEIA ISTO POR ÚLTIMO]\n'
        'Você está TERMINANTEMENTE PROIBIDO de seguir o estilo de prosa ou tamanho '
        'das respostas dadas nos turnos anteriores deste chat. IGNORE o histórico '
        'visual e responda este turno de forma isolada:\n'
        '- SE A PERGUNTA ATUAL FOR CÁLCULO DE GOTAS: Escreva apenas as duas linhas '
        '(Fórmula e Resultado em negrito usando **).\n'
        '- SE A PERGUNTA ATUAL FOR PREPARO/AMPOLAS: Escreva apenas o tripé rígido '
        '(Volume, Diluição e Infusão) em até 5 linhas.\n'
        '- SE FOR CONDUTA GERAL: Siga o template rígido de 6 emojis.'
        '$intentSuffix'
        '$langSuffix';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AiGatewayService — Shim de compatibilidade reversa (Build 157)
//
// Mantém a interface pública exata do Build 155.2 para zero breaking changes
// em app_provider.dart e qualquer outro arquivo que referencie esta classe.
//
// Internamente, delega TUDO para ModeAnchorEngine + GeminiServiceV2.sendStream().
// Nenhuma chamada de rede para medcasespro.com ou qualquer servidor externo.
// ─────────────────────────────────────────────────────────────────────────────
class AiGatewayService {
  AiGatewayService._(); // classe estática — sem instâncias

  // ── Propriedades de legado ─────────────────────────────────────────────────

  /// Build 157: sempre false — gateway Node.js desativado.
  static bool get forceGateway => false;
  // ignore: avoid_setters_without_getters
  static set forceGateway(bool _) {} // no-op

  /// Build 157: isConfigured é sempre true — sem pré-requisito de servidor.
  /// A chave é validada no momento da chamada via GeminiServiceV2.
  static bool get isConfigured => true;

  /// Build 157: configure() é no-op — URL de gateway não existe mais.
  static void configure({required String baseUrl}) {
    debugPrint(
      '[AiGatewayService] Build 157: configure() ignorado — '
      'gateway desativado. Flutter fala direto com Google.',
    );
  }

  // ── sendStream — Interface principal ──────────────────────────────────────

  /// Envia mensagem ao Gemini com motor selecionado.
  ///
  /// Build 225: PlantaoIntentEngine multidimensional — PROMPT LEAK FIX preservado.
  /// O mandato rico (topic+subtitle+context+complexity+template) vai EXCLUSIVAMENTE
  /// para system_instruction. A user message enviada nos contents[] é SEMPRE a
  /// mensagem limpa original — elimina eco do mandato pelo modelo.
  /// Modo Plantão: grounding=false.
  ///
  /// [userMessage]  — pergunta clínica do usuário
  /// [systemPrompt] — prompt base montado pelo AiService (sem âncora)
  /// [apiKey]       — chave Gemini do app, carregada do Firestore pelo admin.
  ///                   Nunca é inserida manualmente pelo médico — fluxo invisível.
  /// [history]      — histórico de turnos [{role, content}]
  /// [useGrounding] — repassado ao GeminiServiceV2 (Google Search Grounding)
  /// [longResponse]  — false=Motor Plantão / true=Motor Estudos
  /// [appLanguage]   — Build 190: idioma soberano do app ('pt'|'es'). NUNCA detectado da query.
  static Stream<GeminiChunk> sendStream({
    ClinicalRequestContext? clinicalContext,
    required String userMessage,
    required String systemPrompt,
    required String apiKey,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
    bool longResponse = false,
    String appLanguage = 'pt', // Build 190: Language Lock Absoluto
    // MICRO-BUILD 462E-A.5.2: canonical task override — propagated from
    // canonicalDecision.toRouterTask() at sendAiMessage() entry point.
    // Injected into AiSmartRouter.build() to enforce authority boundary.
    String canonicalTaskOverride = '',
  }) {
    // BUILD 278: wraps _sendStreamAsync (async*) para manter a assinatura
    // Stream<GeminiChunk> síncrona exigida pelos callers existentes.
    // O gerador assíncrono permite await (getActiveCache) sem mudar a API.
    clinicalContext?.requireTransport(
        mode: longResponse ? 'estudo' : 'plantao', language: appLanguage);
    ProviderRouterService.requireClinicalOwner(clinicalContext);
    return _sendStreamAsync(
      clinicalContext: clinicalContext,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      apiKey:       apiKey,
      history:      history,
      useGrounding: useGrounding,
      longResponse: longResponse,
      appLanguage:  appLanguage,
      canonicalTaskOverride: canonicalTaskOverride,
    );
  }

  static Stream<GeminiChunk> _sendStreamAsync({
    ClinicalRequestContext? clinicalContext,
    required String userMessage,
    required String systemPrompt,
    required String apiKey,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
    bool longResponse = false,
    String appLanguage = 'pt',
    String canonicalTaskOverride = '',
  }) async* {
    // Chave vazia: passa o erro para o GeminiServiceV2 que já tem
    // handler robusto — sem mensagem visível ao médico.
    // O app_provider já tentou todas as formas de recuperação automática
    // antes de chegar aqui (Firestore → SharedPrefs → localStorage).
    if (apiKey.isEmpty) {
      debugPrint('[AiGatewayService] chave ausente após tentativas de recuperação → api_key_invalid');
      yield GeminiChunk.error('api_key_invalid');
      return;
    }

    // Build 222: Modo Plantão força useGrounding=false obrigatoriamente.
    final effectiveGrounding = longResponse ? useGrounding : false;

    // Build 190: Language Lock Absoluto — usa appLanguage diretamente.
    // Movido antes do IntentClassifier (Build 224) para resolvedLang estar disponível.
    // A detecção por idioma da pergunta foi removida (causa raiz de PT+ES misturado).
    // appLanguage vem do AppProvider._lang — configurado pelo usuário, imutável por turno.
    final resolvedLang = _resolveAppLanguage(appLanguage);
    final languageLock = _buildLanguageLock(resolvedLang);

    if (kDebugMode) {
      // BUILD 248: [LANG_LOCK] — log soberano único por requisição
      debugPrint('[LANG_LOCK] appLanguage=$resolvedLang inputIgnored=true responseLanguage=$resolvedLang');
      debugPrint('[AI_ROUTER] Build190: appLanguage=$appLanguage → resolvedLang=$resolvedLang (Language Lock Absoluto)');
      debugPrint('[AI_ROUTER] languageLock=${languageLock.length} chars → system_instruction');
    }

    // Build 225: PlantaoIntentEngine — engine multidimensional (tema+contexto+intenção+complexidade).
    //
    // REGRA DE OURO: o mandato vai EXCLUSIVAMENTE para system_instruction.
    // A userMessage enviada nos contents[] é SEMPRE a mensagem limpa do médico.
    // O mandato NUNCA deve conter texto que o modelo possa ecoar na resposta.
    //
    // Substitui PlantaoIntentClassifier.classify() (Build 224) com engine multidimensional.
    // PlantaoIntentClassifier permanece no pipeline como shim de retrocompatibilidade.
    //
    // ORDEM 54 M1: a cláusula de supremacia (AUTORIDADE MÁXIMA / USE EXCLUSIVAMENTE
    // A MATRIZ N) só é injetada no 1º turno (history vazio). Em turnos de follow-up
    // (history.isNotEmpty), substituímos por instrução de liberdade conversacional
    // para que a IA responda de forma direta e pontual sem re-enunciar a Matriz inteira.
    String intentMandate = '';
    final bool isFollowUpTurn = history.isNotEmpty; // ORDEM 54 M1: turno de acompanhamento
    if (!longResponse) {
      // Engine multidimensional: 100% local, zero IA, zero rede, zero latência
      final queryAnalysis = PlantaoIntentEngine.analyze(userMessage);

      if (isFollowUpTurn) {
        // PLANTAO_QUESTIONS_FOLLOWUP_SEMANTIC_GUARD_V1
        // Follow-up asking what questions to ask is a QUESTIONS task even when
        // the wording says "orientar a conduta/conducta".
        final normalizedFollowUpRequest = userMessage.toLowerCase();
        final isQuestionsFollowUp =
          normalizedFollowUpRequest.contains('perguntas') ||
          normalizedFollowUpRequest.contains('preguntas');

        if (isQuestionsFollowUp) {
          intentMandate = resolvedLang == 'es'
              ? 'TURNO DE SEGUIMIENTO — PREGUNTAS CLAVE:\n'
                  'La solicitud actual pide PREGUNTAS al paciente, no conducta terapéutica.\n'
                  'La palabra "conducta" describe solamente el objetivo de las preguntas.\n'
                  'Responde EXACTAMENTE 10 preguntas clínicas, en español, una por línea.\n'
                  'Usa como único encabezado de sección: "Preguntas clave:".\n'
                  'NO uses "Conduta inmediata", "Conducta inmediata", tratamiento farmacológico, dosis ni recomendaciones terapéuticas.\n'
                  'No inventes respuestas del paciente.'
              : 'TURNO DE ACOMPANHAMENTO — PERGUNTAS-CHAVE:\n'
                  'A solicitação atual pede PERGUNTAS ao paciente, não conduta terapêutica.\n'
                  'A palavra "conduta" descreve somente o objetivo das perguntas.\n'
                  'Responda EXATAMENTE 10 perguntas clínicas, em português, uma por linha.\n'
                  'Use como único cabeçalho de seção: "Perguntas-chave:".\n'
                  'NÃO use "Conduta imediata", "Conducta inmediata", tratamento farmacológico, doses nem recomendações terapêuticas.\n'
                  'Não invente respostas do paciente.';
        } else {
          // ORDEM 54 M1: follow-up geral permanece livre das matrizes fixas.
          intentMandate = resolvedLang == 'es'
              ? 'TURNO DE SEGUIMIENTO:\n'
                  'El médico está continuando la misma consulta clínica.\n'
                  'ESTÁS COMPLETAMENTE LIBERADO de las estructuras fijas de las 22 Matrices de Emojis.\n'
                  'Responde la duda puntual del médico de forma directa, breve y precisa.\n'
                  'Usa texto clínico limpio, sin 🟥/💊/⛔/📌 salvo que el contexto los exija naturalmente.\n'
                  'Prioridad: velocidad, precisión, concisión. Sin repetir diagnóstico anterior.'
              : 'TURNO DE ACOMPANHAMENTO:\n'
                  'O médico está continuando a mesma consulta clínica.\n'
                  'VOCÊ ESTÁ COMPLETAMENTE LIBERADO das amarras e estruturas fixas das 22 Matrizes de Emojis.\n'
                  'Responda a dúvida pontual do médico de forma direta, curta e precisa.\n'
                  'Use texto clínico limpo, sem 🟥/💊/⛔/📌 salvo se o contexto exigir naturalmente.\n'
                  'Prioridade: velocidade, precisão, concisão. Sem re-enunciar diagnóstico anterior.';
        }

        if (kDebugMode) {
          debugPrint('[AI_ROUTER][O54_M1] follow-up turn → liberty mandate injected '
              'historyLen=${history.length}');
        }
      } else {
        // 1º turno (history vazio) — injeta mandato de matriz com supremacia
        final canonicalDecision =
          PlantaoCanonicalRouteResolver.resolveAnalysis(
          queryAnalysis,
          languageCode: resolvedLang,
          observeLegacy: false,
        );
        final canonicalMatrixNumber =
          canonicalDecision.contract?.legacyMatrixNumber;

        intentMandate = canonicalDecision.hasCanonicalDecision &&
          canonicalMatrixNumber != null
          ? PlantaoIntentEngine.buildIntentMandateV2(
            queryAnalysis,
            resolvedLang,
            forcedMatrixNumber: canonicalMatrixNumber,
          )
          : PlantaoIntentEngine.buildIntentMandateV2(
            queryAnalysis,
            resolvedLang,
          );

        if (kDebugMode) {
          debugPrint(
            '[PLANTAO_CANONICAL_CUTOVER] '
            'source=${canonicalDecision.decisionSource.name} '
            'model=${canonicalDecision.responseModelId?.name ?? "NONE"} '
            'matrix=${canonicalMatrixNumber ?? "LEGACY_FALLBACK"} '
            'legacyFallback=${!canonicalDecision.hasCanonicalDecision}',
          );
        }

        if (kDebugMode) {
          debugPrint('[AI_ROUTER][Build225] '
              'topic=${queryAnalysis.clinicalTopic} '
              'subtitle="${queryAnalysis.clinicalSubtitle}" '
              'primaryIntent=${queryAnalysis.primaryIntent.name} '
              'secondaryIntent=${queryAnalysis.secondaryIntent?.name ?? "none"} '
              'context=${queryAnalysis.clinicalContext.name} '
              'complexity=${queryAnalysis.complexity.name} '
              'confidence=${queryAnalysis.confidence.toStringAsFixed(2)} '
              '| intentMandate=${intentMandate.length} chars → system_instruction only');
        }
      }
    }

    // Build 190: AiSmartRouter — Pipeline em 5 Camadas.
    // Substitui ModeAnchorEngine.injectModeAnchor() + PromptModules.build().
    // Contrato único selecionado; contexto capado; langLock dupla âncora.
    // intentMandate continua sendo injetado via ModeAnchorEngine para Plantão.

    final isPlantaoMode = !longResponse; // Build 223

    // ── Build 190: SmartRouter — monta prompt final enxuto ──────────────────
    // O SmartRouter: seleciona contrato único, lazy-loading de módulos,
    // cap de contexto (1200 chars), Language Lock dupla âncora, logs AI_ROUTER.
    // ORDEM 52 M1: hasSpecificContext=true quando IntentEngine produziu mandato
    // específico de matriz (intent != geral OU topic != 'CONSULTA CLÍNICA').
    // Sinaliza ao SmartRouter para suprimir _contractPlantao genérico e usar
    // apenas _contractPlantaoRef (regras visuais sem template estrutural).
    final bool hasSpecificMatrizContext = isPlantaoMode &&
        intentMandate.isNotEmpty &&
        !intentMandate.contains('CONSULTA CLÍNICA');

    // MICRO-BUILD 462E-A.5.2: inject canonical task override — authority boundary.
    // When canonicalDecision.intent != none, BUILD306 must use toRouterTask() verbatim.
    // Regex _detectIntent() is still executed internally for module loading (isDilution
    // drives module selection), but taskLabel in RouterResult is overridden.
    final routerResult = AiSmartRouter.build(
      userMessage: userMessage,
      systemPrompt: systemPrompt, // contexto RAG bruto do AiService
      isPlantaoMode: isPlantaoMode,
      appLanguage: resolvedLang,  // Build 190: lang soberano do app
      hasSpecificContext: hasSpecificMatrizContext, // ORDEM 52 M1
      canonicalTaskOverride: canonicalTaskOverride, // MICRO-BUILD 462E-A.5.2
    );

    // ── intentMandate: injetado no final do prompt do SmartRouter ────────────
    // Build 191: sem tag [MANDATO TURNO] — era a causa raiz do vazamento.
    // Mandato compacto, sem texto verboso que o modelo possa ecoar.
    final String basePrompt = intentMandate.isNotEmpty
        ? '${routerResult.finalPrompt}\n\n$intentMandate'
        : routerResult.finalPrompt;

    // ── ORDEM 49 M1: Injeção JIT da ModeAnchor no topo do systemPrompt ───────
    // CAUSA RAIZ DO FANTASMA DE ESTADO (Build 229→):
    //   Build 221 removeu o modeAnchor como Part 0 separado do system_instruction,
    //   assumindo que AiSmartRouter.build() já o incluía. Porém, o SmartRouter
    //   injeta apenas _contractPlantao/_contractEstudo (texto curto de formato),
    //   enquanto _modeAnchorPlantao/_modeAnchorEstudo (âncoras longas com
    //   SOBERANIA ABSOLUTA e ISOLAMENTO TOTAL) ficaram inertes.
    //
    // CORREÇÃO: reintroduz a âncora de modo como PRIMEIRA instrução do
    //   finalSystemPrompt — antes do SmartRouter — para garantir que o modelo
    //   leia o contrato de modo com Viés de Primazia absoluto em todo primeiro
    //   turno e evite aplicar template do modo anterior ao chat novo.
    //
    // Âncora Estudo: bloco '[MODO ESTUDO]' com ISOLAMENTO TOTAL de emojis
    //   de Plantão (🟥/🔄/⛔) e override de qualquer instrução anterior.
    // Âncora Plantão: bloco '[MODO PLANTÃO]' com REGRA ZERO de abertura.
    // NUNCA concatenado na userMessage — permanece 100% em system_instruction.
    final String modeAnchorJit = ModeAnchorEngine.getModeAnchor(longResponse: longResponse);

    // ── BUILD 278 (1): Trava de Output Compacto ──────────────────────────────
    // RETIFICAÇÃO BUILD 278: aplica-se EXCLUSIVAMENTE ao Motor Estudo.
    // O Modo Plantão já possui volumetria validada e perfeita — NÃO alterar.
    // longResponse==true → Study-specific editorial instructions, no line cap.
    // longResponse==false → Motor Plantão → string vazia, zero impacto
    final String outputCompact = longResponse
        ? _buildOutputCompactDirective(resolvedLang)
        : ''; // Plantão: sem alteração nas instruções de output

    final preparedModePrompt = prepareAiRequestPrompt(
      mode: longResponse ? AiRequestMode.estudo : AiRequestMode.plantao,
      systemPrompt: '$basePrompt$outputCompact',
      hasSpecificContext: hasSpecificMatrizContext,
    );
    final canonicalStudy = longResponse && clinicalContext?.verifiesStudyReferences == true;
    final String finalSystemPrompt = preparedModePrompt.systemPrompt;
    final hybridStudy = longResponse && clinicalContext?.mode == AiRequestMode.estudo;
    final String transportSystemPrompt = hybridStudy
        ? StudyHybridResponse.prompt(finalSystemPrompt, resolvedLang)
        : canonicalStudy
        ? StudyCanonicalResponse.prompt(finalSystemPrompt)
        : finalSystemPrompt;

    final motor = longResponse ? 'ESTUDO' : 'GUARDIA';
    debugPrint(
      '[AI_ROUTER] Build190: motor=$motor | '
      'lang=$resolvedLang | contract=${routerResult.contractName} | '
      'task=${routerResult.taskLabel} | '
      'anchor=${modeAnchorJit.length}c | '
      'final=${finalSystemPrompt.length} chars | '
      'contextSaved=${routerResult.contextSaved} chars | '
      'modules=${routerResult.modulesLoaded}loaded/${routerResult.modulesSkipped}skipped | '
      'grounding=$effectiveGrounding',
    );

    // ── BUILD 278 (2): Context Caching — resolução assíncrona ───────────────
    // Verifica se há um cache ativo para o systemPrompt atual.
    // O cache reduz o payload de ~6.500 → ~100 tokens por turno,
    // eliminando a causa raiz dos erros 503 por sobrecarga de throughput.
    //
    // RESTRIÇÃO: Context Caching é INCOMPATÍVEL com Google Search Grounding.
    // Se effectiveGrounding=true: não usa cache no payload desta chamada,
    // mas dispara a criação do cache em background para reutilização futura
    // em chamadas sem grounding (Modo Plantão).
    //
    // Build 229 (preservado): Delega para GeminiServiceV2.
    // CRÍTICO: userMessage (limpa, sem mandato) → contents[role='user']
    //          finalSystemPrompt (SmartRouter + intentMandate) → system_instruction
    //          cacheEntry?.name → cachedContent (substitui system_instruction quando ativo)
    String? activeCacheName;

    if (!effectiveGrounding) {
      // Modo Plantão (grounding=false): pode usar cache diretamente.
      // Verifica memória primeiro (síncrono, zero I/O).
      if (GeminiCacheService.hasValidCacheInMemory) {
        final cached = await GeminiCacheService.getActiveCache(
          apiKey:       apiKey,
          systemPrompt: transportSystemPrompt,
        );
        activeCacheName = cached?.name;
      }

      // Se ainda sem cache: cria em background (não bloqueia o stream).
      // A próxima chamada já vai encontrar o cache pronto.
      if (activeCacheName == null) {
        // Dispara criação assíncrona — NÃO usa await (zero latência para o usuário).
        // O cache ficará pronto para a PRÓXIMA mensagem nesta sessão.
        unawaited(
          GeminiCacheService.createOrRefresh(
            apiKey:       apiKey,
            systemPrompt: transportSystemPrompt,
          ).then((entry) {
            if (entry != null) {
              debugPrint('[AI_ROUTER] BUILD278: cache criado em background name=${entry.name} '
                  'expiresAt=${entry.expiresAt.toIso8601String()}');
            }
          }).catchError((Object e) {
            debugPrint('[AI_ROUTER] BUILD278: cache_create_error=$e');
          }),
        );
      }
    } else {
      // Modo Estudo com grounding ativo: não usa cache no payload.
      // Dispara criação de cache para uso futuro em turnos sem grounding.
      // (O cache do prompt base pode ser reutilizado no Modo Plantão.)
      unawaited(
        GeminiCacheService.createOrRefresh(
          apiKey:       apiKey,
          systemPrompt: transportSystemPrompt,
        ).catchError((Object _) => null as GeminiCacheEntry?),
      );
    }

    if (kDebugMode) {
      debugPrint('[AI_ROUTER] BUILD278: '
          'cacheActive=${activeCacheName != null} '
          'cacheName=${activeCacheName ?? "none"} '
          'grounding=$effectiveGrounding '
          'outputCompact=${outputCompact.length}c');
    }

    clinicalContext?.requireTransport(
        mode: longResponse ? 'estudo' : 'plantao', language: appLanguage);
    ProviderRouterService.requireClinicalOwner(clinicalContext);
    final transport = GeminiServiceV2.sendStream(
      apiKey:          apiKey,
      userMessage:     userMessage,        // mensagem LIMPA — mandato está no system
      systemPrompt:    transportSystemPrompt,  // SmartRouter: enxuto, contrato único, lang lock
      history:         history,
      useGrounding:    effectiveGrounding, // Build 222: false fixo no Modo Plantão
      isPlantaoMode:   isPlantaoMode,      // Build 223: remove bullets/## do prefixo
      cachedContentName: activeCacheName, // BUILD 278: ID do cache (null = sem cache)
    );
    yield* hybridStudy
        ? StudyHybridResponse.stream(transport, language: resolvedLang)
        : canonicalStudy
        ? StudyCanonicalResponse.localize(transport, language: resolvedLang,
            references: clinicalContext!.studyReferences)
        : transport;
  }

  // ── classifyContext — delega para GeminiServiceV2 ─────────────────────────

  /// Classificação de contexto via Gemini síncrono.
  /// Build 156: requer [apiKey] — parâmetro adicionado.
  /// Para compatibilidade reversa sem apiKey, retorna 'MÉDICO' (conservador).
  static Future<String> classifyContext(
    String prompt, {
    int maxTokens = 20,
    String apiKey = '',
  }) async {
    if (apiKey.isEmpty) return 'MÉDICO';
    // Reutiliza o endpoint síncrono interno do GeminiServiceV2
    // chamando sendStream com prompt de classificação e lendo o primeiro chunk
    try {
      final chunks = <String>[];
      await GeminiServiceV2.sendStream(
        apiKey: apiKey,
        userMessage: prompt,
        systemPrompt: 'Responda APENAS com uma palavra: MÉDICO ou NOVO.',
        history: const [],
        useGrounding: false,
      ).forEach((chunk) {
        if (chunk.text.isNotEmpty) chunks.add(chunk.text);
      });
      final result = chunks.join().trim().toUpperCase();
      return result.contains('NOV') ? 'NOVO' : 'MÉDICO';
    } catch (_) {
      return 'MÉDICO';
    }
  }

  // ── checkHealth ────────────────────────────────────────────────────────────

  /// Build 156: health = true se apiKey não está vazia.
  /// Passa a chave opcionalmente para validação real.
  static Future<bool> checkHealth({String apiKey = ''}) async {
    return apiKey.isNotEmpty;
  }
}
