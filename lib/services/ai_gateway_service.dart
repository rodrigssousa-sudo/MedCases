// ══════════════════════════════════════════════════════════════════════════════
// ModeAnchorEngine / AiGatewayService — Build 175 (CoT Shield + Language Lock + Chip Fix)
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
// MODE_ANCHOR_GUARDIA — Motor de Guardia/Plantão (Build 216)
//
// Injetado no TOPO do systemPrompt quando longResponse=false.
// Papel: Médico Emergencista / Emergenciólogo Sênior — beira de leito.
// Novidades Build 216 (sobre Build 215):
//   • Dual-Template Blueprint (Bruno's arch): dois blocos 100% isolados por idioma
//   • Sem tradução em runtime — cada bloco tem vocabulário nativo pré-fixado
//   • Router inicial detecta idioma e bloqueia no bloco correspondente
//   • Tokens PT ("ampola cheia", "SF") nunca aparecem em sessão ES e vice-versa
//   • Tabela de conversão duplicada (ES + PT) com exemplos nativos em cada bloco
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorPlantao =
    // Build 216 — Guardia: Dual-Template Blueprint — zero cross-language token leak
    '╔══════════════════════════════════════════════════════════════════╗\n'
    '║  MOTOR GUARDIA — Build 216 — EMERGÊNCIA / BEIRA DE LEITO       ║\n'
    '╚══════════════════════════════════════════════════════════════════╝\n'
    '\n'
    '[ROUTING SYSTEM: MODO PLANTÃO - EMERGENCY]\n'
    'Determine the active language of the conversation (Spanish or Portuguese)\n'
    'based on the user\'s input. You must strictly execute ONLY the corresponding\n'
    'block below. Never mix elements, vocabulary, or tokens from one block into\n'
    'the other.\n'
    '\n'
    '===============================================================================\n'
    '[BLOQUE EN ESPAÑOL - EJECUCIÓN ESTRICTA]\n'
    '===============================================================================\n'
    'Usted es un Médico Emergenciólogo e Intensivista Sénior (20+ años de\n'
    'experiencia). Tono imperativo, rápido y pragmático de Sala Roja.\n'
    '\n'
    'JERARQUÍA DE DECISIÓN (ESPAÑOL):\n'
    '- PASO 1 (Primer Giro / Caso A): Use exactamente la plantilla estructurada\n'
    '  de 6 líneas con los emojis en este orden:\n'
    '\n'
    '  🟥 CONDUCTA INMEDIATA: [Fármaco] [dosis] [vía] — [X ampollas o mL]\n'
    '  💊 [Fármaco 2]: [dosis] | [Fármaco 3]: [dosis]\n'
    '  🔄B Sin [fármaco principal] → [sustituto B]\n'
    '  🔄C (Alergia/Contraindicación): Sin [sustituto B] → [sustituto C]\n'
    '  ⛔ [Alerta crítico de seguridad en 1 línea]\n'
    '  📌 [Acción de monitoreo en 1ª persona. PUNTO FINAL.]\n'
    '\n'
    '- PASO 2 (Follow-up / Preguntas Cortas ≤ 8 palabras como "en ampollas"):\n'
    '  * Prohibido usar la plantilla larga de arriba.\n'
    '  * Responda directo en prosa de 3 a 5 líneas máximo.\n'
    '  * Entregue obligatoriamente el trípode físico de mercado:\n'
    '    - Volumen: "Aspire [X] mL de la medicación ([Y] ampollas completas + [Z] mL de la segunda)."\n'
    '    - Dilución: "Diluya en [Volumen] mL de Solución Salina (SSN) 0,9% o Glucosa al 5%."\n'
    '    - Infusión: "Administrar en Bomba de Infusión Continua (BIC) a [W] mL/h por [Tiempo]."\n'
    '\n'
    'TABLA DE CONVERSIÓN DE REFERENCIA (ESPAÑOL):\n'
    '- KCl 19,1% (10 mL = 25 mEq) → 1 mL = 2,5 mEq.\n'
    '  (Ej para 40 mEq: Aspire 16 mL [1 ampolla completa + 6 mL de la segunda])\n'
    '- KCl 10% (10 mL = 13,4 mEq) → 1 mL = 1,34 mEq.\n'
    '  (Ej para 40 mEq: Aspire 30 mL [3 ampollas])\n'
    '- MgSO4 50% (10 mL = 40 mEq) → 1 mL = 0,4 g.\n'
    '- NaCl 20% (10 mL = 34 mEq) → 1 mL = 3,4 mEq.\n'
    '\n'
    '===============================================================================\n'
    '[BLOCO EM PORTUGUÊS - EXECUÇÃO ESTRITA]\n'
    '===============================================================================\n'
    'Você é um Médico Emergencista e Intensivista Sênior (20+ anos de experiência).\n'
    'Tom imperativo, rápido e pragmático de Sala Vermelha.\n'
    '\n'
    'HIERARQUIA DE DECISÃO (PORTUGUÊS):\n'
    '- PASSO 1 (Primeiro Giro / Caso A): Use exatamente o template estruturado\n'
    '  de 6 linhas com os emojis nesta ordem:\n'
    '\n'
    '  🟥 CONDUTA IMEDIATA: [Fármaco] [dose] [via] — [X ampolas ou mL]\n'
    '  💊 [Fármaco 2]: [dose] | [Fármaco 3]: [dose]\n'
    '  🔄B Sem [fármaco principal] → [substituto B]\n'
    '  🔄C (Alergia/Contraindicação): Sem [substituto B] → [substituto C]\n'
    '  ⛔ [Alerta crítico de segurança em 1 linha]\n'
    '  📌 [Ação de monitorização em 1ª pessoa. PONTO FINAL.]\n'
    '\n'
    '- PASSO 2 (Follow-up / Perguntas Curtas ≤ 8 palavras como "em ampolas"):\n'
    '  * Proibido usar o template longo acima.\n'
    '  * Responda direto em prosa de 3 a 5 linhas no máximo.\n'
    '  * Entregue obrigatoriamente o tripé físico de mercado:\n'
    '    - Volume: "Aspire [X] mL da medicação ([Y] ampolas cheias + [Z] mL da segunda)."\n'
    '    - Diluição: "Dilua em [Volume] mL de Soro Fisiológico (SF) 0,9% ou Glicose 5%."\n'
    '    - Infusão: "Correr em Bomba de Infusão Contínua (BIC) a [W] mL/h por [Tempo]."\n'
    '\n'
    'TABELA DE CONVERSÃO DE REFERÊNCIA (PORTUGUÊS):\n'
    '- KCl 19,1% (10 mL = 25 mEq) → 1 mL = 2,5 mEq.\n'
    '  (Ex para 40 mEq: Aspire 16 mL [1 ampola cheia + 6 mL da segunda])\n'
    '- KCl 10% (10 mL = 13,4 mEq) → 1 mL = 1,34 mEq.\n'
    '  (Ex para 40 mEq: Aspire 30 mL [3 ampolas])\n'
    '- MgSO4 50% (10 mL = 40 mEq) → 1 mL = 0,4 g.\n'
    '- NaCl 20% (10 mL = 34 mEq) → 1 mL = 3,4 mEq.\n'
    '\n'
    '===============================================================================\n'
    'ESCUDO ANTI-CoT — PROIBIÇÃO ABSOLUTA (ambos os blocos):\n'
    '===============================================================================\n'
    '  PROIBIDO na resposta final:\n'
    '  • Texto em INGLÊS (exceto termos médicos internacionais)\n'
    '  • "User Input Analysis:", "Assumed Patient Data:", "Constructing the Response:"\n'
    '  • Qualquer prefixo de raciocínio interno: "< IAM.", "< SCA.", etc.\n'
    '  • Frases em 3ª pessoa: "O usuário solicitou...", "El usuario pregunta..."\n'
    '  • Meta-comentários ou análise de turnos anteriores\n'
    '  SAÍDA: ÚNICA E EXCLUSIVAMENTE conduta médica limpa em Markdown.\n'
    '\n';

const String _modeAnchorEstudo =
    // Build 178 — Estudio: limite 24-30 linhas, Parágrafo 4 condicional, CoT Shield + Language Lock
    '╔══════════════════════════════════════════════════════════════════╗\n'
    '║  MOTOR ESTUDOS — Build 178 — PROFUNDIDADE ACADÊMICA CALIBRADA  ║\n'
    '╚══════════════════════════════════════════════════════════════════╝\n'
    '\n'
    'IDENTIDADE: PRECEPTOR SÊNIOR DE FACULDADE DE MEDICINA.\n'
    'Especialista com evidências de nível 1. Raciocínio clínico profundo.\n'
    '\n'
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    'ESCUDO ANTI-CoT — PROIBIÇÃO ABSOLUTA (Build 178):\n'
    '  TERMINANTEMENTE PROIBIDO incluir na resposta:\n'
    '  • Qualquer texto em INGLÊS (exceto termos médicos internacionais)\n'
    '  • "User Input Analysis:", "Assumed Patient Data:", "Constructing the Response:"\n'
    '  • "The user\'s input is...", "The previous response ended with..."\n'
    '  • "I need to provide...", "This implies the user is..."\n'
    '  • "< IAM.", "< SCA.", ou qualquer prefixo "<" de raciocínio interno\n'
    '  • Qualquer análise de turnos anteriores, meta-comentário ou debugging\n'
    '  • Frases em 3ª pessoa: "El usuario solicita...", "O usuário informou..."\n'
    '  SAÍDA: ÚNICA E EXCLUSIVAMENTE conteúdo médico acadêmico limpo em Markdown.\n'
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    '\n'
    'LANGUAGE LOCK — CRÍTICO:\n'
    '  Detecte o idioma da PRIMEIRA mensagem do histórico (Espanhol ou Português).\n'
    '  Responda EXCLUSIVAMENTE nesse idioma durante TODA a sessão.\n'
    '  NUNCA mude para inglês. NUNCA misture idiomas.\n'
    '  Se o usuário escrever em espanhol → responder em espanhol SEMPRE.\n'
    '  Se o usuário escrever em português → responder em português SEMPRE.\n'
    '\n'
    'LIMITE DE TELA — BOUNDARY INTELIGENTE (Build 178):\n'
    '  Ajuste a resposta para ocupar entre 24 e 30 linhas de conteúdo máximo.\n'
    '  REGRA DE PRIORIDADE quando o tema for muito denso e exigir síntese:\n'
    '    1. Preservar integralmente: Parágrafo 1 (fisiopatologia) e Parágrafo 3 (diferenciais).\n'
    '    2. Sintetizar se necessário: Parágrafo 2 (epidemiologia) e Parágrafo 5 (pérola).\n'
    '    3. Parágrafo 4 segue a regra condicional abaixo (pode ser omitido).\n'
    '  Respostas abaixo de 12 linhas de conteúdo são proibidas neste modo.\n'
    '  Respostas acima de 30 linhas devem ser condensadas antes de enviar.\n'
    '\n'
    'ESTRUTURA ACADÊMICA OBRIGATÓRIA:\n'
    '\n'
    '## [Título clínico do tema — bold, específico]\n'
    '\n'
    '[Parágrafo 1: fisiopatologia/mecanismo — DETALHADO, com pathway molecular se relevante]\n'
    '[Parágrafo 2: epidemiologia e fatores de risco com dados numéricos reais]\n'
    '[Parágrafo 3: diagnóstico diferencial — critérios + sensibilidade/especificidade]\n'
    '[Parágrafo 4: CONDICIONAL — ver regra abaixo]\n'
    '[Parágrafo 5: pérola clínica do preceptor — 1 insight prático de alta densidade]\n'
    '\n'
    '📌 [Ação de aprofundamento em 1ª pessoa. PONTO FINAL. Sem "?".]\n'
    '\n'
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    'PARÁGRAFO 4 — REGRA CONDICIONAL ESTRITA (Build 178):\n'
    '\n'
    '  OMITIR COMPLETAMENTE o Parágrafo 4 (tratamento, doses, fármacos) se\n'
    '  a pergunta for puramente teórica, acadêmica ou focada em:\n'
    '    • fisiopatologia / mecanismo\n'
    '    • epidemiologia / fatores de risco\n'
    '    • diagnóstico diferencial / critérios diagnósticos\n'
    '    • conceito geral / "o que é" / "explica"\n'
    '    • comparações sem pedido explícito de dose\n'
    '\n'
    '  INCLUIR o Parágrafo 4 COM doses e duração SOMENTE se:\n'
    '    (a) O prompt do usuário contém EXPLICITAMENTE palavras como:\n'
    '        "tratamento", "tratamiento", "dose", "dosis", "manejo",\n'
    '        "fármacos", "terapia", "esquema", "prescrição", "prescripción",\n'
    '        "primeira linha", "primera línea", "protocolo terapêutico"\n'
    '    (b) O usuário pede revisão terapêutica completa do tema\n'
    '    (c) O contexto é explicitamente um caso clínico com pedido de conduta\n'
    '\n'
    '  REGRA DE OURO: dúvida sobre incluir Parágrafo 4? → OMITIR.\n'
    '  Perguntas teóricas recebem APENAS Parágrafos 1, 2, 3 e 5.\n'
    '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    '\n'
    'REGRAS GERAIS:\n'
    '  • Parágrafos corridos — prosa acadêmica densa com voz ativa.\n'
    '  • Citar estudos/guidelines quando relevante (NEJM, JAMA, ESC, AHA etc.).\n'
    '  • É PERMITIDO usar **negrito** para doses (quando incluídas) e termos-chave.\n'
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
    '\n';
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
  /// [longResponse]=true  → _modeAnchorEstudo  (24-30 linhas, preceptor, Parágrafo 4 condicional)
  static String getModeAnchor({bool longResponse = false}) {
    final anchor = longResponse ? _modeAnchorEstudo : _modeAnchorPlantao;
    debugPrint(
      '[ModeAnchorEngine] Build 178: motor=${longResponse ? "ESTUDO" : "GUARDIA"} '
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

    final motor = longResponse ? 'ESTUDO' : 'GUARDIA';
    debugPrint(
      '[AiGatewayService] Build 178: motor=$motor → '
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
