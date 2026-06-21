// ══════════════════════════════════════════════════════════════════════════════
// ModeAnchorEngine / AiGatewayService — Build 157.2 (Structural Template Anchors)
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
//   Motor Plantão (longResponse=false):
//     → Injeta MODE_ANCHOR_PLANTAO no topo do systemPrompt
//     → Limite rígido: ≤14 linhas | Médico de Emergência direto
//     → 🟥 CONDUTA IMEDIATA + 💊 DOSES + 🔄 ALTERNATIVAS + 📌 gancho 1ª pessoa
//     → Inteligência de infraestrutura: alternativas se fármaco indisponível
//
//   Motor Estudos (longResponse=true):
//     → Injeta MODE_ANCHOR_ESTUDO no topo do systemPrompt
//     → Limite expandido: ≤24 linhas | Preceptor de Faculdade de Medicina
//     → Memória ativa: PROIBIDO repetir conteúdo do histórico
//     → Gancho de continuação em 1ª pessoa do usuário (ativa botão de sugestão)
//     → RAG Override Rule: reformata conteúdo estático em voz de preceptor
//
// INTERFACE PÚBLICA (zero breaking changes vs Build 155.2):
//   AiGatewayService.sendStream(...)       → shim de compatibilidade
//   ModeAnchorEngine.injectModeAnchor(...) → injeção direta de âncora
//   kAiGatewayBaseUrl                      → string vazia (legado)
//
// FLUXO DE DADOS Build 156:
//   app_provider.sendAiMessage()
//     → AiService.buildClinicalSystemPrompt()   [monta prompt base]
//     → AiGatewayService.sendStream()            [shim]
//       → ModeAnchorEngine.injectModeAnchor()   [injeta âncora de modo]
//       → GeminiServiceV2.sendStream()           [SSE direto para Google]
//         → generativelanguage.googleapis.com   [API Google — chave do app]
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'gemini_service_v2.dart';

// ── Import condicional — mantido apenas para compilação sem erros ─────────────
// Os arquivos _io e _web (implementações SSE para o gateway Node) não são
// mais chamados no fluxo principal (Build 156). GeminiServiceV2 usa seu
// próprio pipeline SSE interno. A importação permanece para evitar erros
// de compilação caso haja referências indiretas.
import 'ai_gateway_service_io.dart'
    if (dart.library.js_interop) 'ai_gateway_service_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constante de legado — mantida para zero breaking changes
// Build 156: VAZIO — não há servidor gateway.
// ─────────────────────────────────────────────────────────────────────────────
const String kAiGatewayBaseUrl = '';

// ─────────────────────────────────────────────────────────────────────────────
// MODE_ANCHOR_PLANTAO — Motor de Plantão (Build 157)
//
// Injetado no TOPO do systemPrompt quando longResponse=false.
// Papel: Médico de Emergência direto e rápido.
// Novidades Build 157:
//   • Inteligência de infraestrutura hospitalar — alternativas quando falta insumo
//   • Fix de botão: sugestões em PRIMEIRA PESSOA do usuário (não pergunta da IA)
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorPlantao =
    // Build 170 — Plantão: 14-16 linhas máximo, foco cirúrgico
    '╔══════════════════════════════════════════════════════════════════╗\n'
    '║  MOTOR PLANTÃO — Build 170 — TEMPLATE ESTRUTURAL OBRIGATÓRIO    ║\n'
    '╚══════════════════════════════════════════════════════════════════╝\n'
    '\n'
    'IDENTIDADE: MÉDICO DE EMERGÊNCIA — conduta imediata, sem rodeios.\n'
    '\n'
    'LIMITE RÍGIDO: máximo 14 a 16 linhas no total. Contar incluindo linhas em branco.\n'
    'Qualquer conteúdo além da 16ª linha deve ser eliminado antes de responder.\n'
    '\n'
    'TEMPLATE DE SAÍDA — COPIE ESTA ESTRUTURA EXATA:\n'
    '\n'
    '🟥 CONDUTA IMEDIATA: [Fármaco principal] [dose] [via]\n'
    '💊 [Fármaco 2]: [dose] [via] | [Fármaco 3]: [dose] [via]\n'
    '🔄 ALTERNATIVAS: Sem [fármaco] → [substituto] [dose] [via]\n'
    '⛔ [Alerta crítico de segurança em 1 linha]\n'
    '📌 [Ação de continuação em 1ª pessoa. PONTO FINAL obrigatório.]\n'
    '\n'
    'REGRAS DE PREENCHIMENTO DO TEMPLATE:\n'
    '  • 🟥 — SEMPRE primeira linha. Fármaco + dose + via. Sem preâmbulo.\n'
    '  • 💊 — Doses adicionais em linha única telegráfica.\n'
    '  • 🔄 — SEMPRE presente. "Sem X → Y dose via" por linha.\n'
    '  • ⛔ — Somente se há contraindicação crítica real. Máx 1 linha.\n'
    '  • 📌 — ÚLTIMA linha OBRIGATÓRIA. Frase em 1ª pessoa. PONTO FINAL.\n'
    '         NUNCA terminar com interrogação. NUNCA omitir esta linha.\n'
    '\n'
    'EXEMPLOS DE FECHAMENTO 📌 ACEITOS:\n'
    '  📌 Mostrar alternativas de fármacos se não houver este no hospital.\n'
    '  📌 Detalhar a dose para crianças neste caso.\n'
    '  📌 Sim, quero ver a titulação desses fármacos.\n'
    '  📌 Quero ver o manejo de longo prazo desta condição.\n'
    '\n'
    'FECHAMENTOS 📌 PROIBIDOS:\n'
    '  ✗ Qualquer linha com "?" no final\n'
    '  ✗ "📌 ¿Desea ver más opciones?"\n'
    '  ✗ "📌 Quer saber mais sobre este fármaco?"\n'
    '  ✗ "📌 Deseja que eu explique?"\n'
    '\n'
    'ANTI-ENCICLOPÉDIA: zero parágrafos, zero fisiopatologia, zero definições.\n'
    'Cada linha = dado clínico puro: fármaco + dose + via. Máx 16 linhas TOTAL.\n'
    '\n';
const String _modeAnchorEstudo =
    // Build 170 — Estudio: SEM limite de linhas, profundidade acadêmica total
    '╔══════════════════════════════════════════════════════════════════╗\n'
    '║  MOTOR ESTUDOS — Build 170 — PROFUNDIDADE ACADÊMICA TOTAL       ║\n'
    '╚══════════════════════════════════════════════════════════════════╝\n'
    '\n'
    'IDENTIDADE: PRECEPTOR SÊNIOR DE FACULDADE DE MEDICINA.\n'
    'Especialista com evidências de nível 1. Raciocínio clínico profundo.\n'
    '\n'
    'SEM LIMITE DE LINHAS — responda com a profundidade que o tema exige.\n'
    'Respostas curtas são proibidas neste modo. Desenvolva completamente.\n'
    '\n'
    'ESTRUTURA ACADÊMICA OBRIGATÓRIA:\n'
    '\n'
    '## [Título clínico do tema — bold, específico]\n'
    '\n'
    '[Parágrafo 1: fisiopatologia/mecanismo — DETALHADO, com pathway molecular se relevante]\n'
    '[Parágrafo 2: epidemiologia e fatores de risco com dados numéricos reais]\n'
    '[Parágrafo 3: diagnóstico diferencial — critérios + sensibilidade/especificidade]\n'
    '[Parágrafo 4: tratamento baseado em evidências — doses, duração, nível de evidência]\n'
    '[Parágrafo 5: pérola clínica do preceptor — 1 insight prático de alta densidade]\n'
    '\n'
    '📌 [Ação de aprofundamento em 1ª pessoa. PONTO FINAL. Sem "?".]\n'
    '\n'
    'REGRAS:\n'
    '  • Parágrafos corridos — prosa acadêmica densa com voz ativa.\n'
    '  • Citar estudos/guidelines quando relevante (NEJM, JAMA, ESC, AHA etc.).\n'
    '  • É PERMITIDO usar **negrito** para doses e termos-chave.\n'
    '  • É PERMITIDO usar listas quando a clareza clínica exige.\n'
    '  • 📌 — ÚLTIMA linha OBRIGATÓRIA. Frase em 1ª pessoa. PONTO FINAL.\n'
    '         NUNCA terminar com "?". NUNCA omitir esta linha.\n'
    '\n'
    'EXEMPLOS DE FECHAMENTO 📌 ACEITOS:\n'
    '  📌 Quero aprofundar a farmacologia dos betabloqueadores neste caso.\n'
    '  📌 Continuar para o manejo pós-IAM e prevenção secundária.\n'
    '  📌 Quero ver a comparação entre esses dois fármacos com evidências.\n'
    '  📌 Detalhar as indicações de intervenção cirúrgica neste cenário.\n'
    '\n'
    'FECHAMENTOS 📌 PROIBIDOS:\n'
    '  ✗ Qualquer linha com "?" no final\n'
    '  ✗ "📌 ¿Desea continuar?" — frases interrogativas\n'
    '  ✗ "📌 Quer que eu explique?" — convite vago\n'
    '\n'
    'MEMÓRIA ATIVA — ANTI-REPETIÇÃO:\n'
    '  Analise o histórico completo. Jamais repita conteúdo já explicado.\n'
    '  Continue do ponto exato onde parou, como preceptor que lembra tudo.\n'
    '\n'
    'RAG OVERRIDE: reformate conteúdo de guias em voz de preceptor.\n'
    'Transforme listas secas em raciocínio clínico narrativo e embasado.\n'
    '\n';// ─────────────────────────────────────────────────────────────────────────────
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
  /// [longResponse]=false → _modeAnchorPlantao (≤14 linhas, médico emergência)
  /// [longResponse]=true  → _modeAnchorEstudo  (≤24 linhas, preceptor)
  static String getModeAnchor({bool longResponse = false}) {
    final anchor = longResponse ? _modeAnchorEstudo : _modeAnchorPlantao;
    debugPrint(
      '[ModeAnchorEngine] Build 157.2: motor=${longResponse ? "ESTUDO" : "PLANTÃO"} '
      'âncora obtida (${anchor.length} chars) — enviada como PART 0 do system_instruction',
    );
    return anchor;
  }

  /// Compatibilidade reversa — Build 157.1: retorna apenas o systemPrompt
  /// sem concatenar a âncora (a âncora vai como part separado via GeminiServiceV2).
  /// @deprecated Use getModeAnchor() + GeminiServiceV2.sendStream(modeAnchor: ...)
  static String injectModeAnchor(
    String systemPrompt, {
    bool longResponse = false,
  }) {
    // Build 157.1: a âncora NÃO é mais concatenada aqui —
    // é passada como modeAnchor para GeminiServiceV2.sendStream()
    // para garantir prioridade máxima sobre _systemPromptPrefix.
    return systemPrompt; // retorna prompt sem âncora concatenada
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
  /// Build 157: delega para ModeAnchorEngine + GeminiServiceV2.sendStream().
  /// A âncora de modo é injetada internamente no [systemPrompt].
  ///
  /// [userMessage]  — pergunta clínica do usuário
  /// [systemPrompt] — prompt base montado pelo AiService (sem âncora)
  /// [apiKey]       — chave Gemini do app, carregada do Firestore pelo admin.
  ///                   Nunca é inserida manualmente pelo médico — fluxo invisível.
  /// [history]      — histórico de turnos [{role, content}]
  /// [useGrounding] — repassado ao GeminiServiceV2 (Google Search Grounding)
  /// [longResponse] — false=Motor Plantão / true=Motor Estudos
  static Stream<GeminiChunk> sendStream({
    required String userMessage,
    required String systemPrompt,
    required String apiKey,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
    bool longResponse = false,
  }) {
    // Chave vazia: passa o erro para o GeminiServiceV2 que já tem
    // handler robusto — sem mensagem visível ao médico.
    // O app_provider já tentou todas as formas de recuperação automática
    // antes de chegar aqui (Firestore → SharedPrefs → localStorage).
    if (apiKey.isEmpty) {
      debugPrint('[AiGatewayService] chave ausente após tentativas de recuperação → api_key_invalid');
      return Stream.value(GeminiChunk.error('api_key_invalid'));
    }

    // Build 157.1: obtém âncora de modo como string separada
    // A âncora NÃO é mais concatenada ao systemPrompt —
    // é passada como 'modeAnchor' para GeminiServiceV2 que a
    // coloca como PART 0 (prioridade máxima) em system_instruction.
    final anchor = ModeAnchorEngine.getModeAnchor(longResponse: longResponse);

    final motor = longResponse ? 'ESTUDO' : 'PLANTÃO';
    debugPrint(
      '[AiGatewayService] Build 157.2: motor=$motor → '
      'GeminiServiceV2.sendStream() direto | âncora como PART 0 (${anchor.length} chars)',
    );

    // Delega para GeminiServiceV2 — SSE direto para Google
    // modeAnchor é injetado como PRIMEIRA parte de system_instruction.parts[]
    return GeminiServiceV2.sendStream(
      apiKey:       apiKey,
      userMessage:  userMessage,
      systemPrompt: systemPrompt,  // prompt base sem âncora concatenada
      history:      history,
      useGrounding: useGrounding,
      modeAnchor:   anchor,        // âncora como PART 0 — prioridade máxima
    );
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
