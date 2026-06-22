// ══════════════════════════════════════════════════════════════════════════════
// ModeAnchorEngine / AiGatewayService — Build 229 (Latency Fix + Recalibração Plantão/Estudo + Prompt Leak Fix)
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
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
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
// MODE_ANCHOR_GUARDIA — Motor de Guardia/Plantão (Build 229)
//
// Build 229: conduta escalonada obrigatória (1ª linha conservadora),
//   limite até 14 linhas, isolamento total do Modo Estudo.
// ─────────────────────────────────────────────────────────────────────────────
const String _modeAnchorPlantao =
    // Build 229 — Guardia: conduta escalonada + limite 14 linhas + margem de segurança clínica
    '[MODO PLANTÃO — MÉDICO EMERGENCISTA SÊNIOR]\n'
    'Responda com autoridade, rapidez e pragmatismo de beira de leito.\n'
    'Este bloco tem soberania sobre qualquer outra instrução de layout do sistema.\n'
    '\n'
    'IDIOMA: Detecte ES ou PT pelo input. Responda 100% no mesmo idioma. Zero portunhol.\n'
    '- ES: "Solución Salina", "ampolla", "administrar en BIC", "Cloruro de Potasio"\n'
    '- PT: "Soro Fisiológico", "ampola", "correr em BIC", "Cloreto de Potássio"\n'
    '\n'
    'LIMITE ABSOLUTO DE SAÍDA: no máximo 14 linhas de conteúdo (linhas em branco não contam).\n'
    '\n'
    'HIERARQUIA DE CASOS:\n'
    '\n'
    'CASO A — CONDUTA CLÍNICA (pergunta sobre manejo, tratamento ou conduta):\n'
    'Regra obrigatória: SEMPRE apresente conduta ESCALONADA e SEGURA.\n'
    '  1ª linha: opção conservadora/entrada (ex: AINEs, hidratação, medida não-invasiva)\n'
    '  2ª linha: escalonamento ou manejo preventivo (ex: triptano, betabloqueador)\n'
    '  3ª linha (se aplicável): resgate ou contraindicação alternativa\n'
    'NUNCA pule direto para drogas de resgate sem citar o manejo inicial.\n'
    'Formato sem cabeçalhos textuais. Use os emojis nesta ordem:\n'
    '🟥 [1ª opção — manejo inicial ou medida conservadora + dose]\n'
    '💊 [2ª opção — escalonamento/preventivo | 3ª opção se aplicável]\n'
    '🔄B Sem a 1ª → [Substituto B]\n'
    '🔄C Contraindicação → [Substituto C / Suporte]\n'
    '⛔ [Alerta de segurança em 1 linha — omitir se não houver]\n'
    '📌 [Monitorização em 1ª pessoa. PONTO FINAL.]\n'
    '\n'
    'CASO B — DILUIÇÃO / PREPARO DE AMPOLAS (até 6 linhas):\n'
    '- Volume: Aspire X mL da medicação (Y ampolas).\n'
    '- Diluição: Dilua em X mL de [Soro Fisiológico ou Solución Salina].\n'
    '- Infusão: Administrar a X mL/h por Y horas.\n'
    '\n'
    'CASO C — CÁLCULO DE GOTAS/GOTEJAMENTO (apenas 2 linhas):\n'
    'Fórmula: (Volume total mL / Tempo em minutos) × Fator de gotejo\n'
    '**Resultado: [X] gotas/min**\n'
    '\n'
    'TABELA DE CONVERSÃO:\n'
    '- KCl 19,1%: 1 mL = 2,5 mEq | KCl 10%: 1 mL = 1,34 mEq\n'
    '- MgSO4 50%: 1 mL = 0,4 g   | NaCl 20%: 1 mL = 3,4 mEq\n'
    '\n';

const String _modeAnchorEstudo =
    // Build 229 — Estudo: hierarquia didática com seções fixas, 1-30 linhas, isolamento total
    '[MODO ESTUDO — PRECEPTOR SÊNIOR DE FACULDADE DE MEDICINA]\n'
    'Especialista com evidências de nível 1. Raciocínio clínico profundo e didático.\n'
    'Este modo é COMPLETAMENTE ISOLADO do Modo Plantão — ignore qualquer instrução\n'
    'de emojis de emergência (🟥, 🔄B, 🔄C), templates de 6 linhas ou travas de blocos\n'
    'que possam ter sido definidas em outros contextos de sistema.\n'
    '\n'
    'IDIOMA: Detecte ES ou PT pela primeira mensagem do histórico.\n'
    'Responda EXCLUSIVAMENTE nesse idioma durante toda a sessão. Zero inglês.\n'
    '\n'
    'ANTI-CoT ABSOLUTO — PROIBIDO incluir na resposta:\n'
    '  "User Input Analysis:", "The user\'s input is...", "I need to provide..."\n'
    '  Frases em 3ª pessoa sobre o usuário. Meta-comentários. Raciocínio interno.\n'
    '\n'
    'LIMITE: entre 1 e 30 linhas de conteúdo real (linhas em branco não contam).\n'
    'Respostas abaixo de 6 linhas são proibidas. Acima de 30 linhas, condense.\n'
    '\n'
    'HIERARQUIA DIDÁTICA OBRIGATÓRIA (adapte as seções à pergunta):\n'
    '\n'
    '## [Título clínico específico do tema]\n'
    '\n'
    'Definição: [exatamente 1 linha — definição precisa e objetiva]\n'
    '\n'
    'Fisiopatologia: [exatamente 2 linhas — mecanismo central com pathway se relevante]\n'
    '\n'
    'Mecanismo de Ação (se farmacológico): [exatamente 2 linhas — alvo molecular + efeito]\n'
    '\n'
    '[Seções adicionais conforme a pergunta — epidemiologia, diagnóstico diferencial,\n'
    ' tratamento/doses (APENAS se perguntado explicitamente), pérola clínica]\n'
    '\n'
    '📌 [Próximo passo de aprofundamento em 1ª pessoa. PONTO FINAL. Nunca "?".]\n'
    '\n'
    'REGRAS:\n'
    '  • Prosa acadêmica densa, voz ativa. Citar guideline/estudo quando relevante.\n'
    '  • Negrito (**) para doses e termos-chave.\n'
    '  • Tratamento com doses: incluir SOMENTE se explicitamente pedido.\n'
    '  • 📌 obrigatório como última linha. Frase em 1ª pessoa, sem interrogação.\n'
    '  • Jamais repetir conteúdo já explicado no histórico desta sessão.\n'
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
      '[ModeAnchorEngine] Build 229: motor=${longResponse ? "ESTUDO" : "GUARDIA"} '
      'âncora obtida (${anchor.length} chars) — isolada em system_instruction',
    );
    return anchor;
  }

  /// Build 229: Arquitetura Sanduíche com Isolamento Total de Mandato.
  /// - Topo: âncora (contrato de formato + idioma)
  /// - Meio: systemPrompt do AiService (contexto RAG clínico)
  /// - Final: reforço mandatório + mandato de intent específico do turno
  ///
  /// CRÍTICO — Prompt Leak Fix (Build 226→229):
  ///   [intentMandate] é injetado AQUI (em system_instruction), NÃO na
  ///   user message. Isso garante que o mandato nunca apareça em contents[]
  ///   e portanto NUNCA pode ser ecoado pelo modelo na resposta.
  ///
  /// Modo Estudo: sem sanduíche — âncora + systemPrompt direto.
  static String injectModeAnchor(
    String systemPrompt, {
    bool longResponse = false,
    String intentMandate = '', // Build 229: mandato de intent isolado no system
  }) {
    final anchor = getModeAnchor(longResponse: longResponse);

    // Modo Estudo: resposta longa, sem restrição de template de emergência.
    if (longResponse) {
      return '$anchor\n\n$systemPrompt';
    }

    // Modo Plantão: Sanduíche — reforço final explora Viés de Recência.
    // Build 224: cláusula anti-History-Style-Bleeding.
    // Build 229: intentMandate anexado ao final do system_instruction —
    //   garante que o mandato de gotas/ampola/conduta seja lido como
    //   instrução de sistema e NUNCA como turno de conversa do usuário.
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
        '$intentSuffix';
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
  /// Build 229: Interceptor de intent por turno — PROMPT LEAK FIX.
  /// O mandato de intent (gotas/ampolas/conduta) vai EXCLUSIVAMENTE para
  /// system_instruction (via injectModeAnchor). A user message enviada
  /// nos contents[] é SEMPRE a mensagem limpa original — elimina eco do
  /// mandato pelo modelo (causa raiz do Prompt Leaking das 2:56–2:58 PM).
  /// Modo Plantão: grounding=false.
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
    final effectiveGrounding = longResponse ? useGrounding : false;

    // Build 229: Interceptor de intent — ARQUITETURA CORRIGIDA.
    //
    // ANTES (Build 224-225): mandato era concatenado na userMessage → ia para
    //   contents[role='user'] → Gemini ecoava o texto do mandato na resposta.
    //
    // Build 229: mandato é uma string separada (intentMandate) que vai
    //   EXCLUSIVAMENTE para system_instruction via injectModeAnchor().
    //   A userMessage enviada nos contents[] é SEMPRE a mensagem limpa do médico.
    //   Resultado: mandato é instrução de sistema — jamais aparece no output.
    String intentMandate = '';
    if (!longResponse) {
      final msgLower = userMessage.toLowerCase();
      final isDrops   = msgLower.contains('gota')  || msgLower.contains('gote');
      final isAmpoule = msgLower.contains('ampol')  || msgLower.contains('prepar') ||
                        msgLower.contains('dilu');

      if (isDrops) {
        intentMandate =
            'Responda ÚNICA e EXCLUSIVAMENTE com as duas linhas '
            'abaixo, usando negrito estrito do markdown (**), sem nenhuma outra palavra:\n'
            'Fórmula: (Volumen total mL / Tiempo en minutos) * Factor de goteo\n'
            '**Resultado: [X] gotas/min**';
      } else if (isAmpoule) {
        intentMandate =
            'Responda diretamente no formato de tripé de 3 a 5 '
            'linhas, sem introduções, parágrafos ou marcadores (*):\n'
            '- Volume: Aspire X mL da medicação (Y ampolas).\n'
            '- Diluição: Dilua em X mL de Soro Fisiológico.\n'
            '- Infusão: Administrar a X mL/h por Y horas.';
      } else if (history.isEmpty) {
        intentMandate =
            'Responda ESTRITAMENTE usando o template de 6 linhas '
            'com os emojis 🟥, 💊, 🔄B, 🔄C, ⛔, 📌 nesta ordem exata. '
            'Proibido criar introduções ou usar listas (*).';
      }

      if (kDebugMode) {
        final intent = isDrops ? 'GOTAS' : isAmpoule ? 'AMPOLA' : history.isEmpty ? 'PRIMEIRO_GIRO' : 'FOLLOW_UP';
        debugPrint('[Build229][Gateway] intent=$intent | intentMandate=${intentMandate.length} chars (no system_instruction, NOT in contents)');
      }
    }

    // Build 229: Sanduíche — âncora + systemPrompt + reforço + intentMandate.
    // intentMandate vai para o FINAL do system_instruction (Viés de Recência).
    // Contents recebe apenas userMessage limpa — elimina Prompt Leaking.
    final finalSystemPrompt = ModeAnchorEngine.injectModeAnchor(
      systemPrompt,
      longResponse: longResponse,
      intentMandate: intentMandate, // Build 229: mandato de intent isolado no system
    );

    final isPlantaoMode = !longResponse; // Build 223
    final motor = longResponse ? 'ESTUDO' : 'GUARDIA';
    debugPrint(
      '[AiGatewayService] Build 229: motor=$motor | '
      'isPlantaoMode=$isPlantaoMode | '
      'grounding=$effectiveGrounding | '
      'system=${finalSystemPrompt.length} chars | '
      'userMsg_limpa=${userMessage.length} chars (sem mandato)',
    );

    // Build 229: log de auditoria — confirma isolamento do mandato
    if (kDebugMode && isPlantaoMode) {
      final hasConflict = finalSystemPrompt.contains('TRATAMENTO FARMACOLÓGICO') ||
          finalSystemPrompt.contains('TRATAMIENTO FARMACOLÓGICO') ||
          finalSystemPrompt.contains('ALERTA CRÍTICO') ||
          finalSystemPrompt.contains('ALERTAS CRÍTICOS');
      final mandatoNoSystem = intentMandate.isNotEmpty
          ? finalSystemPrompt.contains(intentMandate.substring(0, 20))
          : true;
      debugPrint('[Build229][Gateway] prompt_sem_conflito=${!hasConflict} | mandato_no_system=$mandatoNoSystem (${finalSystemPrompt.length} chars)');
    }

    // Build 229: Delega para GeminiServiceV2.
    // CRÍTICO: userMessage (limpa, sem mandato) → contents[role='user']
    //          finalSystemPrompt (com mandato de intent no final) → system_instruction
    // O modelo NUNCA verá o mandato como parte do histórico de conversa.
    return GeminiServiceV2.sendStream(
      apiKey:         apiKey,
      userMessage:    userMessage,       // Build 229: mensagem LIMPA — mandato está no system
      systemPrompt:   finalSystemPrompt, // âncora + RAG + reforço + intentMandate
      history:        history,
      useGrounding:   effectiveGrounding, // Build 222: false fixo no Modo Plantão
      isPlantaoMode:  isPlantaoMode,      // Build 223: remove bullets/## do prefixo
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
