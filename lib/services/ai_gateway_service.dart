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
// MODE_ANCHOR_GUARDIA — Motor de Guardia/Plantão (Build 220)
//
// Injetado no TOPO do systemPrompt quando longResponse=false.
// Papel: Médico Emergencista Sênior — beira de leito.
// Novidades Build 220 (sobre Build 219):
//   • Root cause fix: Prompt Overlap Conflict — systemPrompt base ordena
//     cabeçalhos "TRATAMENTO FARMACOLÓGICO" / "ALERTA CRÍTICO" + bullet points
//     que anulavam o template de 5 emojis e geravam enciclopédias nas gotas
//   • [SOBERANIA ESTRUTURAL ABSOLUTA] no início: IGNORE cabeçalhos textuais e
//     estruturas de tópicos vindas de qualquer outra parte do systemPrompt
//   • Caso A: adicionado "cabeçalhos textuais ou marcadores de bolinha (*)"
//     à lista de proibições explícitas
//   • Caso B: "sem cabeçalhos ou bolinhas de tópicos" reforçado
//   • [MONOPÓLIO DE SAÍDA FINAL] ao final: override total de qualquer lógica externa
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorPlantao =
    // Build 220 — Guardia: sovereignty clauses — override systemPrompt base layout
    '[MANDATO CRÍTICO: MODO PLANTÃO - EMERGÊNCIA BILÍNGUE]\n'
    'Você é um Médico Emergencista Sênior (20+ anos de experiência). Responda\n'
    'com autoridade máxima, rapidez e pragmatismo de Sala Vermelha.\n'
    '\n'
    '[SOBERANIA ESTRUTURAL ABSOLUTA - OVERRIDE TOTAL]\n'
    '- IGNORE COMPLETAMENTE qualquer instrução de layout, cabeçalhos textuais\n'
    '  (como "TRATAMENTO FARMACOLÓGICO", "ALERTA CRÍTICO") ou estruturas de\n'
    '  tópicos/bullet points vindas de outras partes do prompt ou do sistema.\n'
    '- Este bloco de formato abaixo tem soberania absoluta sobre qualquer\n'
    '  outra regra do sistema.\n'
    '\n'
    'DIRETRIZ DE IDIOMA (MANDATÓRIA):\n'
    'Detecte o idioma do input (Espanhol ou Português). Responda 100% no mesmo\n'
    'idioma do usuário. Proibido misturar tokens (Zero Portunhol). Use as equivalências:\n'
    '- Se ES: "Solución Salina", "ampolla completa", "de la segunda",\n'
    '  "administrar en BIC", "Cloruro de Potasio", "Glucosa", "Bicarbonato de Sodio".\n'
    '- Se PT: "Soro Fisiológico", "ampola cheia", "da segunda",\n'
    '  "correr em BIC", "Cloreto de Potássio", "Glicose", "Bicarbonato de Sódio".\n'
    '\n'
    'HIERARQUIA DE FORMATO DE SAÍDA OBRIGATÓRIA:\n'
    '\n'
    '1. PRIMEIRO GIRO (Caso A - Primeira pergunta sobre o tema):\n'
    'Sua resposta DEVE conter exatamente estas 6 linhas e os emojis nesta ordem.\n'
    'É TERMINANTEMENTE PROIBIDO criar prosa, introduções, cabeçalhos textuais\n'
    'ou marcadores de bolinha (*):\n'
    '🟥 CONDUTA IMEDIATA: [Fármaco e Dose principal]\n'
    '💊 [Fármaco 2] | [Fármaco 3]\n'
    '🔄B Sem o principal → [Substituto B]\n'
    '🔄C Contraindicação → [Substituto C / Suporte]\n'
    '⛔ [Alerta crítico de segurança em 1 linha — omitir se não houver]\n'
    '📌 [Ação de monitorização em 1ª pessoa terminada em PONTO FINAL.]\n'
    '\n'
    '2. PERGUNTAS CURTAS DE DILUIÇÃO / AMPOLAS (Caso B):\n'
    'Responda direto no formato de tripé, sem cabeçalhos ou bolinhas de\n'
    'tópicos (3 a 5 linhas):\n'
    '- Volume: Aspire X mL da medicação (Y ampolas).\n'
    '- Diluição: Dilua em X mL de [Soro Fisiológico ou Solución Salina].\n'
    '- Infusão: Administrar a X mL/h por Y horas.\n'
    '\n'
    '3. SE A PERGUNTA FOR EXCLUSIVAMENTE CÁLCULO DE GOTAS OU GOTEJAMENTO:\n'
    'É TERMINANTEMENTE PROIBIDO escrever explicações, introduções,\n'
    'contextualizações ou parágrafos de texto.\n'
    '(Ex: Proibido "Para calcular...", "En este caso...", "Sustituyendo...")\n'
    'Sua saída deve conter ÚNICA e EXCLUSIVAMENTE as duas linhas abaixo:\n'
    'Fórmula: (Volumen total mL / Tiempo en minutos) * Factor de goteo\n'
    'Resultado: <font color="red">**[X] gotas/min**</font>\n'
    '\n'
    'TABELA DE CONVERSÃO DE MERCADO:\n'
    '- KCl 19,1% (10 mL = 25 mEq) → 1 mL = 2,5 mEq. (Ex: 40 mEq = 16 mL [1 ampola + 6 mL])\n'
    '- KCl 10%   (10 mL = 13,4 mEq) → 1 mL = 1,34 mEq. (Ex: 40 mEq = 30 mL [3 ampolas])\n'
    '- MgSO4 50% (10 mL = 40 mEq) → 1 mL = 0,4 g.\n'
    '- NaCl 20%  (10 mL = 34 mEq) → 1 mL = 3,4 mEq.\n'
    '\n'
    '[MONOPÓLIO DE SAÍDA FINAL]\n'
    'Ignore qualquer outra lógica de saída externa ao sistema. Produza única\n'
    'e exclusivamente o Markdown/HTML determinado nesta âncora.\n'
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

  /// Build 222: Arquitetura Sanduíche para Modo Plantão.
  /// - Topo: âncora (contrato de formato + idioma)
  /// - Meio: systemPrompt do AiService (contexto RAG clínico)
  /// - Final: reforço mandatório lido por último antes de responder
  ///   → explora Viés de Recência do Gemini para sobrescrever cabeçalhos
  ///     textuais e bullet points injetados pelo systemPrompt base.
  /// Modo Estudo: sem sanduíche — âncora + systemPrompt direto (sem reforço).
  static String injectModeAnchor(
    String systemPrompt, {
    bool longResponse = false,
  }) {
    final anchor = getModeAnchor(longResponse: longResponse);

    // Modo Estudo: resposta longa, sem restrição de template de emergência.
    if (longResponse) {
      return '$anchor\n\n$systemPrompt';
    }

    // Modo Plantão: Sanduíche — reforço final explora Viés de Recência.
    return '$anchor\n\n'
        '[INÍCIO DO CONTEXTO CLÍNICO DO APLICATIVO]\n'
        '$systemPrompt\n\n'
        '[REFORÇO MANDATÓRIO DE FORMATO DE SAÍDA - LEIA ISTO POR ÚLTIMO]\n'
        'Você está TERMINANTEMENTE PROIBIDO de usar os cabeçalhos '
        '"TRATAMENTO FARMACOLÓGICO" ou "ALERTA CRÍTICO" e de usar listas '
        'de marcadores com bolinhas (*).\n'
        'Gere sua resposta baseando-se unicamente nas seguintes regras de fechamento:\n'
        '- SE FOR O PRIMEIRO GIRO: Escreva estritamente o template de 6 linhas '
        'com os emojis 🟥, 💊, 🔄B, 🔄C, ⛔, 📌 sem nenhuma linha de introdução ou prosa.\n'
        '- SE FOR CÁLCULO DE GOTAS/GOTEJAMENTO: Ignore o contexto de prosa acima. '
        'Escreva ÚNICA e EXCLUSIVAMENTE duas linhas na tela:\n'
        '  Fórmula: (Volumen total mL / Tiempo en minutos) * Factor de goteo\n'
        '  Resultado: <font color="red">**[X] gotas/min**</font>';
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
  /// Build 222: Sanduíche (âncora + RAG + reforço final) + grounding=false no Modo Plantão.
  /// Modo Plantão: useGrounding forçado false — elimina latência 14s e "EVIDÊNCIA CIENTÍFICA".
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

    // Build 222: Modo Plantão força useGrounding=false obrigatoriamente.
    // Google Search Grounding adiciona ~14s de latência e polui a Sala Vermelha
    // com dados externos da web (colapsável "EVIDÊNCIA CIENTÍFICA").
    // Modo Estudo mantém o valor recebido (grounding pode ser útil para estudos).
    final effectiveGrounding = longResponse ? useGrounding : false;

    // Build 221/222: Sanduíche — âncora topo + systemPrompt + reforço final.
    final finalSystemPrompt = ModeAnchorEngine.injectModeAnchor(
      systemPrompt,
      longResponse: longResponse,
    );

    final motor = longResponse ? 'ESTUDO' : 'GUARDIA';
    debugPrint(
      '[AiGatewayService] Build 222: motor=$motor | '
      'grounding=$effectiveGrounding | '
      'prompt=${finalSystemPrompt.length} chars',
    );

    // Delega para GeminiServiceV2 — string monolítica única (sem modeAnchor separado)
    return GeminiServiceV2.sendStream(
      apiKey:       apiKey,
      userMessage:  userMessage,
      systemPrompt: finalSystemPrompt,   // sanduíche: âncora + RAG + reforço
      history:      history,
      useGrounding: effectiveGrounding,  // Build 222: false fixo no Modo Plantão
      // Build 221: modeAnchor removido — já está dentro de finalSystemPrompt
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
