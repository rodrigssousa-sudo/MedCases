// ══════════════════════════════════════════════════════════════════════════════
// GeminiServiceV2 — Build 93 — Motor de IA BYOA blindado para produção
//
// ARQUITETURA v4 — Quatro camadas de blindagem estrutural:
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CAMADA 1 — FILTRAGEM NATIVA DE STREAM (anti-vazamento de pensamento)   │
// │                                                                         │
// │  _extractText() inspeciona CADA part do SSE chunk e descarta            │
// │  categoricamente qualquer bloco identificado como raciocínio interno:   │
// │    • thought == true          → Chain-of-Thought explícito do Gemini    │
// │    • 'thoughtSignature' key   → Assinatura criptográfica de CoT         │
// │    • 'functionCall' key       → Chamada interna de ferramenta           │
// │    • 'executableCode' key     → Código executável gerado internamente   │
// │    • 'codeExecutionResult'    → Resultado de execução interna           │
// │    • 'inlineData' key         → Dados binários (imagens, etc.)          │
// │  Apenas parts com chave 'text' (String, não-vazia) chegam à UI.         │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CAMADA 2 — JANELA DESLIZANTE DE HISTÓRICO (Context Classifier)         │
// │                                                                         │
// │  Antes de cada stream, _classifyContext() faz uma chamada leve          │
// │  (não-streaming) enviando:                                              │
// │    • Última resposta da IA (truncada a 300 chars)                       │
// │    • Nova pergunta do usuário                                           │
// │  Instrução: responda APENAS 'MÉDICO' ou 'NOVO'.                         │
// │    'MÉDICO' → mesmo caso/medicamento → últimas 3 trocas (6 entradas)   │
// │    'NOVO'   → assunto diferente      → histórico vazio (clean slate)    │
// │  Timeout 8s, fallback conservador 'MÉDICO'. Custo: ~60 tokens/chamada. │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CAMADA 3 — CONFIGURAÇÃO REST BLINDADA + PREFIXO DE FERRO v3            │
// │                                                                         │
// │  • system_instruction isolado do histórico (Content.system equivalente) │
// │  • _systemPromptPrefix v3 injetado ANTES de qualquer instrução AiService│
// │    → proíbe raciocínio visível, inglês intermediário, metadados         │
// │  • maxOutputTokens: 3200  → respostas clínicas completas sem corte      │
// │  • thinkingConfig omitido → flash-lite rejeita a chave no stream (400)  │
// │    anti-CoT via _systemPromptPrefix BLOCOS 0/1 + _extractText() 7 filtros│
// │  • temperature: 0.4       → consistência clínica calibrada              │
// │  • Retry com backoff 5s/15s/30s + cooldown global pós-429              │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CAMADA 4 — RAG CROSS-CHECK ANTI-ALUCINAÇÃO (implementado em AiService) │
// │                                                                         │
// │  • _ragCrossCheckEs/Pt: módulo 10 do systemPrompt (seção 15 de 19)      │
// │    → 4 passos: comparação query-RAG, classificação A/B/C,              │
// │      isolamento de dados de paciente, verificação final pré-envio       │
// │  • Regras K+L em safetyRules: Verdade Absoluta Restrita + Proibição    │
// │    de Alucinação Clínica                                                │
// │  • ragAnchor 9 regras: revisor crítico, proibição de invenção,         │
// │    isolamento de dados de paciente entre sessões                        │
// │  • selfCheck item 13: RAG cross-check obrigatório pré-resposta (5 subs) │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ENDPOINTS:
//   STREAM : POST /v1beta/models/gemini-2.5-flash-lite:streamGenerateContent
//            ?alt=sse&key=KEY
//            Chunks SSE formato: "data: {...}\n\n"
//   SYNC   : POST /v1beta/models/gemini-2.5-flash-lite:generateContent?key=KEY
//            Context Classifier — resposta mínima ('MÉDICO'/'NOVO')
//
// FLUXO PRINCIPAL:
//   sendStream() → [quota check] → _runPipeline()
//     → _classifyContext() [sync, 8s timeout]
//     → _buildContextWindow() [max 3 pares ou vazio]
//     → _executeWithRetry() [max 3 tentativas]
//       → _streamRequest() [SSE blindado]
//         → _extractText() [filtro CoT, 6 condições]
//         → controller.add(GeminiChunk) [apenas texto limpo para UI]
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// GeminiChunk — unidade de dado do stream
// ─────────────────────────────────────────────────────────────────────────────
class GeminiChunk {
  /// Fragmento de texto do streaming (pode ser vazio em chunks de metadado).
  final String text;

  /// true → este chunk sinaliza o fim da resposta (finishReason detectado
  /// ou stream encerrado normalmente).
  final bool isDone;

  /// Código de erro se a requisição falhou (null = sucesso normal).
  /// Códigos possíveis: 'quota', 'api_key_invalid', 'timeout', 'network',
  /// 'stream_error', 'http_XXX', 'unexpected'.
  final String? errorCode;

  const GeminiChunk({
    required this.text,
    this.isDone = false,
    this.errorCode,
  });

  /// true → o stream terminou com falha.
  bool get isError => errorCode != null;

  /// Cria um chunk de erro com isDone implícito.
  factory GeminiChunk.error(String code) =>
      GeminiChunk(text: '', isDone: true, errorCode: code);

  /// Sinalização de conclusão sem texto adicional.
  static const GeminiChunk done = GeminiChunk(text: '', isDone: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// GeminiServiceV2 — serviço estático (BYOA, sem instâncias)
// ─────────────────────────────────────────────────────────────────────────────
class GeminiServiceV2 {
  GeminiServiceV2._(); // construtor privado — utilitário 100% estático

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVACIDADE CLÍNICA — LOGS CONDICIONAIS
  //
  // Em produção (release), respostas clínicas e dados do paciente NÃO devem
  // aparecer nos consoles de crash-reporting ou ferramentas de observabilidade.
  // _debugGemini=false em kReleaseMode silencia todos os logs do serviço.
  //
  // Durante desenvolvimento (debug/profile), os logs ficam visíveis normalmente.
  // ══════════════════════════════════════════════════════════════════════════

  /// true apenas em debug/profile — nunca em release build.
  static const bool _debugGemini = kDebugMode;

  /// Centraliza todos os logs do serviço — no-op em produção.
  static void _log(String message) {
    if (_debugGemini) debugPrint(message);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ENDPOINTS E MODELO
  // ══════════════════════════════════════════════════════════════════════════

  /// Modelo base — flash-lite tem quota free-tier muito maior que o flash-pro.
  /// Free tier: ~1.500 RPM, 1.000.000 TPM (vs. 10 RPM do gemini-2.5-flash).
  static const _modelId = 'gemini-2.5-flash-lite';

  /// Endpoint SSE de streaming (usado na resposta principal ao usuário).
  static const _endpointStream =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_modelId:streamGenerateContent?alt=sse';

  /// Endpoint síncrono (usado APENAS pelo Context Classifier — leve e rápido).
  static const _endpointSync =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_modelId:generateContent';

  // ══════════════════════════════════════════════════════════════════════════
  // CONTROLE DE QUOTA E RETRY
  // ══════════════════════════════════════════════════════════════════════════

  /// Número máximo de tentativas após erro 429.
  static const _maxRetries = 3;

  /// Backoff progressivo entre tentativas (attempt 0→5s, 1→15s, 2→30s).
  static const _retryBackoff = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  /// Janela de cooldown após 429 definitivo (esgotou todas as tentativas).
  /// Bloqueia requisições por 60s para não desperdiçar tokens em requests
  /// condenados quando a quota está realmente esgotada.
  static const _quotaCooldown = Duration(minutes: 1);

  /// Timestamp de expiração do cooldown (null = sem cooldown ativo).
  static DateTime? _quotaUntil;

  /// true → cooldown ativo, não deve enviar requisições.
  static bool get isInQuotaCooldown =>
      _quotaUntil != null && DateTime.now().isBefore(_quotaUntil!);

  /// Tempo restante de cooldown (null se não há cooldown ou já expirou).
  static Duration? get quotaCooldownRemaining {
    if (_quotaUntil == null) return null;
    final remaining = _quotaUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Reseta o cooldown manualmente (ex: usuário configurou nova chave API).
  static void resetQuotaCooldown() => _quotaUntil = null;

  // ══════════════════════════════════════════════════════════════════════════
  // PREFIXO DE FERRO v3 — CAMADA 3
  // (anti-CoT visível + idioma espelho ES/PT + anatomia Bupropión bilíngue)
  //
  // Injetado como PRIMEIRA coisa que o modelo lê, antes de qualquer instrução
  // do AiService. Três defesas sobrepostas:
  //
  //   [A] thinkingConfig omitido no stream (flash-lite rejeita a chave)
  //       → thinkingConfig mantido APENAS no classifier sync (_classifyContext)
  //   [B] Este prefixo     → proíbe o comportamento via instrução de texto
  //   [C] _extractText() + _looksLikeInternalReasoning() → 7 filtros no JSON
  //
  // NOVIDADES v3 (Build 93 bilíngue — idioma espelho ES/PT):
  //   • REGRA ESPELHO ES/PT — substituiu a regra rígida de espanhol único.
  //     O modelo detecta o idioma da última pergunta e responde ESTRITAMENTE
  //     nesse idioma. Mistura ES+PT na mesma resposta é terminantemente proibida.
  //   • BLOCO 0 atualizado — TRAVA ANTI-LEAK mantida + REGRA DE IDIOMA ESPELHO
  //     com lista explícita de proibições (mistura, idioma diferente, inglês).
  //     REGRA DE REITERAÇÃO DIRETA expandida: "idioma detectado" em vez de fixo.
  //   • BLOCO 1 atualizado — Regra 3 refatorada: "primeira linha no idioma
  //     detectado da pergunta (espanhol ou português)" — sem referência a fixo.
  //   • BLOCO 2 atualizado — ANATOMIA BUPROPIÓN com títulos bilíngues explícitos
  //     em cada §: ES/PT lado a lado, adaptação dinâmica obrigatória.
  // ══════════════════════════════════════════════════════════════════════════
  static const _systemPromptPrefix =

      // ── BLOCO 0 — TRAVA DE IDIOMA ESPELHO E ANTI-LEAK ─────────────────────
      // Lido PRIMEIRO pelo modelo. Define a regra de idioma bilateral e cobre
      // os vazamentos de raciocínio interno observados em produção.
      '⚠️ ALERTA DE REJEIÇÃO CRÍTICO — MÁXIMA PRIORIDADE ABSOLUTA:\n'
      'Sob NENHUMA circunstância utilize frases de transição de raciocínio '
      'interno visíveis ao usuário. As seguintes expressões são '
      'TERMINANTEMENTE PROIBIDAS na chave "text" da resposta:\n'
      '  ✗ "The user is asking..."\n'
      '  ✗ "The user wants..."\n'
      '  ✗ "I should reiterate..."\n'
      '  ✗ "I need to clarify..."\n'
      '  ✗ "Let me explain..."\n'
      '  ✗ "To summarize what was asked..."\n'
      '  ✗ Qualquer frase que resuma a intenção do usuário\n'
      '  ✗ Qualquer frase que descreva o que a IA "vai fazer" antes de fazer\n'
      'É TERMINANTEMENTE PROIBIDO gerar qualquer texto de análise interna, '
      'resumo de intenção ou meta-comentário dentro da mensagem final.\n\n'
      '🌐 REGRA DE IDIOMA ESPELHO — FERRO ABSOLUTO:\n'
      'Identifique o idioma da ÚLTIMA pergunta do usuário.\n'
      '  • Se o usuário perguntar em ESPANHOL → responda ESTRITAMENTE em Espanhol.\n'
      '  • Se o usuário perguntar em PORTUGUÊS → responda ESTRITAMENTE em Português.\n'
      'É TERMINANTEMENTE PROIBIDO:\n'
      '  ✗ Misturar Espanhol e Português na MESMA resposta\n'
      '  ✗ Responder em idioma diferente da pergunta do usuário\n'
      '  ✗ Usar inglês como idioma de resposta ao usuário\n'
      'REGRA DE REITERAÇÃO DIRETA: se o usuário pedir para reiterar, detalhar '
      'ou repetir algo → responder DIRETAMENTE na primeira linha no idioma '
      'detectado da pergunta (espanhol ou português), sem prefácio, sem '
      'anúncio do que vai fazer. A resposta começa imediatamente com o '
      'conteúdo clínico.\n\n'

      // ── BLOCO 1 — REGRAS ABSOLUTAS DE ANTI-CoT E FLUXO CLÍNICO ───────────
      '🔒 REGRA ABSOLUTA — LER ANTES DE QUALQUER INSTRUÇÃO:\n'
      '1. JAMAIS exiba raciocínio interno, rascunhos, modos de operação, '
      'metadados ou qualquer processo de pensamento na resposta ao usuário.\n'
      '2. PROIBIDO usar inglês como idioma intermediário ou para "pensar em '
      'voz alta". Zero caracteres em inglês visíveis ao usuário — exceto '
      'termos médicos internacionais universalmente reconhecidos (SpO₂, qSOFA, '
      'SOFA, CURB-65, PCR, INR, RNI, etc.).\n'
      '3. Responda DIRETAMENTE na primeira linha no idioma detectado da '
      'pergunta (espanhol ou português). O usuário vê APENAS a resposta '
      'clínica limpa. Nenhum processo interno é visível.\n'
      '4. Se detectar qualquer bloco de chain-of-thought, <thinking>, '
      '[REVISÃO_INTERNA], [ANÁLISE_INTERNA], scratchpad ou raciocínio '
      '→ ELIMINAR completamente antes de formular a resposta.\n\n'

      // ── BLOCO 2 — ANATOMIA BUPROPIÓN BILÍNGUE (FARMACO MODE COMPLETO) ─────
      // Padronização baseada no modelo de resposta aprovado em testes.
      // Ativa SOMENTE em MODO FARMACO / FARMACO MODE COMPLETO.
      // Não altera QUICK, CONVERSATIONAL, CLINICAL nem TEACH.
      // Os títulos dos §§ se adaptam DINAMICAMENTE ao idioma detectado.
      '🏗️ ANATOMIA OBRIGATÓRIA — MODO FARMACO COMPLETO (modelo Bupropión):\n'
      'Quando o modo ativo for FARMACO MODE COMPLETO, estruturar SEMPRE:\n'
      'Adaptar os títulos dos parágrafos dinamicamente ao idioma da pergunta.\n'
      '\n'
      '  § 1 — DEFINICIÓN / DEFINIÇÃO (1 parágrafo introdutório)\n'
      '    ES: título "Definición" · PT: título "Definição"\n'
      '    Introdução curta e conceitual: mecanismo de ação em **negrito**, '
      'classe farmacológica, alvo molecular ou receptor. Máx. 3-4 linhas.\n'
      '\n'
      '  § 2 — INDICACIONES Y DOSIS / INDICAÇÕES E DOSES\n'
      '    ES: iniciar com "Se utiliza principalmente para:"\n'
      '    PT: iniciar com "Utilizado principalmente para:"\n'
      '    Seguido de bullet points (* ) com indicação + dosagem em **negrito**.\n'
      '    Incluir via de administração e frequência em cada bullet.\n'
      '\n'
      '  § 3 — ⛔ BLOCO DE ALERTA (se existirem contraindicações graves)\n'
      '    Gerar OBRIGATORIAMENTE quando há contraindicação absoluta, efeito '
      'adverso crítico ou risco de vida. Formato exato:\n'
      '    > ⛔ **Está CONTRAINDICADO en:** [motivo] (ES)\n'
      '    > ⛔ **Está CONTRAINDICADO em:** [motivo] (PT)\n'
      '    Usar bloco de citação markdown (>) para que o app renderize '
      'visualmente destacado. Nunca omitir se existir risco real.\n'
      '\n'
      '  § 4 — OTROS PUNTOS / OUTROS PONTOS\n'
      '    ES: iniciar com "Otros puntos a considerar:"\n'
      '    PT: iniciar com "Outros pontos a considerar:"\n'
      '    Bullet points com efeitos colaterais comuns, monitoramento, '
      'interações farmacológicas relevantes e observações de plantão.\n'
      '\n'
      '  § 5 — RODAPÉ DE EVIDÊNCIA (sempre a última linha)\n'
      '    ES — formato EXATO (itálico, separado por linha em branco acima):\n'
      '    *📚 Referencias base: Harrison · PubMed · [guideline aplicável]. '
      'Valide clínicamente.*\n'
      '    PT — formato EXATO (itálico, separado por linha em branco acima):\n'
      '    *📚 Referências base: Harrison · PubMed · [guideline aplicável]. '
      'Valide clinicamente.*\n\n';

  // ══════════════════════════════════════════════════════════════════════════
  // sendStream — API PÚBLICA
  //
  // Streaming token-a-token via SSE com janela deslizante de histórico.
  //
  // Parâmetros:
  //   apiKey       → Gemini API key do usuário (BYOA)
  //   userMessage  → pergunta atual do usuário
  //   systemPrompt → prompt de sistema montado pelo AiService (19 seções)
  //   history      → histórico completo [{role: 'user'/'assistant', content}]
  //   useGrounding → ativar Google Search Grounding (padrão: true)
  //
  // Retorna:
  //   Stream<GeminiChunk> — cada evento é texto parcial ou sinalização.
  //   O AppProvider acumula os chunks num StringBuffer e atualiza a UI.
  //
  // Fluxo interno:
  //   1. Verifica cooldown global pós-429
  //   2. _runPipeline: classify → window → stream
  //
  // Compatibilidade: mesma assinatura da versão anterior — nenhum caller
  // precisa ser modificado.
  // ══════════════════════════════════════════════════════════════════════════
  static Stream<GeminiChunk> sendStream({
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
  }) {
    final controller = StreamController<GeminiChunk>();

    // ── Guarda de quota: rejeita imediatamente se cooldown ativo ─────────────
    if (isInQuotaCooldown) {
      final remaining = quotaCooldownRemaining;
      _log(
        '[GeminiV2] quota cooldown ativo — ${remaining?.inSeconds ?? 0}s restantes',
      );
      controller
        ..add(GeminiChunk.error('quota'))
        ..close();
      return controller.stream;
    }

    // ── Pipeline assíncrono (não bloqueia o thread UI) ────────────────────────
    _runPipeline(
      controller: controller,
      apiKey: apiKey,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      history: history,
      useGrounding: useGrounding,
    );

    return controller.stream;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _runPipeline — Orquestrador do pipeline assíncrono
  //
  // Passo 1: Context Classifier — determina se a nova pergunta continua
  //          o caso anterior ('MÉDICO') ou inicia assunto novo ('NOVO').
  //
  // Passo 2: _buildContextWindow — constrói o histórico calibrado:
  //          'MÉDICO' → últimas 3 trocas (6 entradas, ~1.200 tokens)
  //          'NOVO'   → lista vazia (só a pergunta atual, ~50 tokens)
  //
  // Passo 3: _executeWithRetry — stream SSE com retry automático.
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _runPipeline({
    required StreamController<GeminiChunk> controller,
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
  }) async {
    if (controller.isClosed) return;

    // ── Passo 1: Classificação de contexto ───────────────────────────────────
    List<Map<String, String>> windowedHistory;

    if (history.isEmpty) {
      // Primeira mensagem da sessão — sem histórico, sem necessidade de classify
      windowedHistory = [];
      _log('[GeminiV2] primeira pergunta — histórico vazio');
    } else {
      final contextLabel = await _classifyContext(
        apiKey: apiKey,
        history: history,
        userMessage: userMessage,
      );
      windowedHistory = _buildContextWindow(history, contextLabel);
      _log(
        '[GeminiV2] context=$contextLabel → '
        '${windowedHistory.length ~/ 2} troca(s) no payload',
      );
    }

    // ── Passo 2: Stream com histórico calibrado ───────────────────────────────
    try {
      await _executeWithRetry(
        controller: controller,
        apiKey: apiKey,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: windowedHistory,
        useGrounding: useGrounding,
        attempt: 0,
      );
    } catch (e) {
      _log('[GeminiV2] _runPipeline erro inesperado: $e');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('unexpected'))
          ..close();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _classifyContext — Context Classifier (CAMADA 2)
  //
  // Chamada síncrona ultra-leve à API (não-streaming, generateContent).
  // Envia APENAS:
  //   • Última resposta da IA (truncada a 300 chars para economizar tokens)
  //   • Nova pergunta do usuário
  //
  // A instrução do sistema temporária ordena: responda UMA palavra.
  //   'MÉDICO' = mesma consulta/caso/medicamento/tema clínico anterior
  //   'NOVO'   = mudou de assunto, novo caso, nova dúvida não relacionada
  //
  // Custo típico: ~60-80 tokens. Timeout agressivo: 8 segundos.
  // Fallback em qualquer falha: 'MÉDICO' (conservador — mantém contexto).
  //
  // Por que não usar o histórico completo para classificar?
  //   Para não gastar tokens do classifier com histórico longo. O par
  //   (última IA + nova query) é suficiente para determinar continuidade.
  // ══════════════════════════════════════════════════════════════════════════
  static Future<String> _classifyContext({
    required String apiKey,
    required List<Map<String, String>> history,
    required String userMessage,
  }) async {
    // Busca a última resposta da IA no histórico (percorre de trás para frente)
    String lastAiResponse = '';
    for (int i = history.length - 1; i >= 0; i--) {
      if (history[i]['role'] == 'assistant') {
        lastAiResponse = history[i]['content'] ?? '';
        break;
      }
    }

    // Sem resposta prévia da IA → não há contexto para comparar
    if (lastAiResponse.isEmpty) {
      _log('[GeminiV2] classifier: sem resposta IA prévia → MÉDICO');
      return 'MÉDICO';
    }

    // Trunca para 300 chars — suficiente para capturar o tema sem gastar tokens
    final truncatedAi = lastAiResponse.length > 300
        ? '${lastAiResponse.substring(0, 300)}...'
        : lastAiResponse;

    // Instrução temporária em inglês — eficiente para classificação binária
    const classifierSystemPrompt =
        'You are a medical conversation context classifier. '
        'Your ONLY job is to determine if the new user question continues the same '
        'clinical topic as the previous AI response, or starts a completely new topic. '
        'Reply with EXACTLY one word — no punctuation, no explanation:\n'
        '"MÉDICO" — if the new question follows up on the same clinical case, '
        'medication, diagnosis, exam, or any aspect of the previous response.\n'
        '"NOVO" — if the user changed subject, started a new case, asked about '
        'something completely unrelated, or explicitly said they want a new topic.';

    final requestBody = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': classifierSystemPrompt}
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': 'Previous AI response (truncated to 300 chars):\n'
                  '"$truncatedAi"\n\n'
                  'New user question:\n'
                  '"$userMessage"\n\n'
                  'Same clinical topic? Reply MÉDICO or NOVO.',
            }
          ],
        }
      ],
      'generationConfig': {
        'maxOutputTokens': 10,   // Uma palavra — 10 tokens é mais que suficiente
        'temperature': 0.0,      // Determinístico — queremos uma classificação estável
        'topK': 1,               // Greedy decoding — token mais provável apenas
        'thinkingConfig': {'thinkingBudget': 0}, // Zero CoT — velocidade máxima
      },
    });

    final url = Uri.parse('$_endpointSync?key=$apiKey');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
  _log(
          '[GeminiV2] classifier HTTP ${response.statusCode} → fallback MÉDICO',
        );
        return 'MÉDICO';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawText = _extractTextFromSync(data).trim().toUpperCase();
      _log('[GeminiV2] classifier resposta raw: "$rawText"');

      // Sanitiza: remove tudo que não seja letra maiúscula ou acentuada.
      // Previne que "MÉDICO." / "NOVO!" / "MÉDICO\n" quebrem a avaliação.
      final normalized =
          rawText.replaceAll(RegExp(r'[^A-ZÁÉÍÓÚÃÕÇ]'), '').toUpperCase();
      _log('[GeminiV2] classifier normalizado: "$normalized"');

      // Aceita variações naturais: NUEVO, NEW, CHANGE → NOVO
      // Qualquer outra resposta (incluindo silêncio ou erro) → MÉDICO (conservador)
      if (normalized.contains('NOV') ||
          normalized.contains('NEW') ||
          normalized.contains('CHAN') ||
          normalized.contains('DIFF')) {
        return 'NOVO';
      }
      return 'MÉDICO';
    } on TimeoutException {
      _log('[GeminiV2] classifier timeout (8s) → fallback MÉDICO');
      return 'MÉDICO';
    } catch (e) {
      _log('[GeminiV2] classifier erro: $e → fallback MÉDICO');
      return 'MÉDICO';
    }
  }

  // ── Extrai texto de resposta síncrona (generateContent, não SSE) ──────────
  // Aplica o mesmo filtro de CoT para garantir que o classificador
  // não retorne texto de pensamento interno acidentalmente.
  static String _extractTextFromSync(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';
      final candidate = candidates[0] as Map<String, dynamic>;
      final parts = candidate['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';

      final buffer = StringBuffer();
      for (final rawPart in parts) {
        final part = rawPart as Map<String, dynamic>;
        // Filtra CoT mesmo no classifier
        if (part['thought'] == true) continue;
        if (part.containsKey('thoughtSignature')) continue;
        final text = part['text'] as String?;
        if (text != null && text.isNotEmpty) buffer.write(text);
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _buildContextWindow — Janela deslizante de histórico (CAMADA 2)
  //
  // Controla quantas trocas anteriores são enviadas no payload da API.
  // O objetivo é proteger a quota TPM do plano gratuito sem perder
  // a continuidade clínica necessária para um diálogo coerente.
  //
  // 'MÉDICO' (mesmo caso):
  //   → Retorna as últimas 3 trocas completas = max 6 entradas do histórico.
  //   → Uma troca = 1 user + 1 model. 3 trocas ≈ 1.200 tokens de contexto.
  //   → Clínica: suficiente para manter coerência num diálogo sobre um caso.
  //
  // 'NOVO' (assunto diferente):
  //   → Retorna lista vazia — nenhum contexto anterior enviado.
  //   → O payload final terá apenas a nova pergunta do usuário.
  //   → Previne "contaminação cruzada" de dados clínicos entre casos.
  //
  // IMPORTANTE: este método NÃO modifica o histórico original no AppProvider.
  // Ele retorna uma CÓPIA calibrada para o payload da requisição atual.
  // ══════════════════════════════════════════════════════════════════════════
  static List<Map<String, String>> _buildContextWindow(
    List<Map<String, String>> history,
    String contextLabel,
  ) {
    if (contextLabel == 'NOVO') {
      // Assunto novo — clean slate, sem risco de misturar dados de pacientes
      _log('[GeminiV2] NOVO: histórico limpo para este payload');
      return [];
    }

    // Mesmo assunto — limita a 3 trocas (6 entradas) para proteger TPM
    const maxPairs = 3;
    const maxEntries = maxPairs * 2; // 6 entradas = 3 user + 3 model

    if (history.length <= maxEntries) {
      return List.of(history); // já dentro do limite — usa tudo sem truncar
    }

    // Pega as [maxEntries] entradas mais recentes
    final window = history.sublist(history.length - maxEntries);
    _log(
      '[GeminiV2] _buildContextWindow: ${history.length} → ${window.length} entradas',
    );
    return window;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _executeWithRetry — Wrapper de retry recursivo para o stream
  //
  // Delega para _streamRequest. Se ocorrer exceção não tratada internamente,
  // captura e emite GeminiChunk.error('unexpected').
  //
  // O retry de 429 é tratado DENTRO de _streamRequest (não aqui), porque
  // a resposta HTTP (statusCode 429) só é conhecida após a requisição.
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _executeWithRetry({
    required StreamController<GeminiChunk> controller,
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
    required int attempt,
  }) async {
    if (controller.isClosed) return;

    try {
      await _streamRequest(
        controller: controller,
        apiKey: apiKey,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
        history: history,
        useGrounding: useGrounding,
        attempt: attempt,
      );
    } catch (e) {
      _log('[GeminiV2] _executeWithRetry: exceção inesperada: $e');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('unexpected'))
          ..close();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _streamRequest — Requisição SSE blindada (CAMADAS 1, 3 e 4)
  //
  // MONTAGEM DO PAYLOAD:
  //   system_instruction → prefixo de ferro + systemPrompt do AiService
  //                        Injetado isolado (não faz parte do histórico)
  //                        Equivalente a Content.system() do SDK Firebase AI
  //
  //   contents           → histórico janelado + nova mensagem do usuário
  //                        [{role:'user'/'model', parts:[{text:'...'}]}]
  //
  //   generationConfig   → maxOutputTokens:3200, temp:0.4 (thinkingConfig omitido)
  //
  //   safetySettings     → BLOCK_NONE em todas as categorias (conteúdo médico
  //                        frequentemente é bloqueado por filtros genéricos)
  //
  // PARSING SSE:
  //   Lê o stream de bytes, monta linhas, parseia JSON de "data: {...}"
  //   _extractText() → CAMADA 1: filtra 6 tipos de parts não-textuais
  //   Apenas texto puro do usuário chega ao controller (e portanto à UI)
  //
  // TRATAMENTO DE ERROS:
  //   429 → retry com backoff progressivo (5s/15s/30s) até _maxRetries
  //         Se esgotou retries → cooldown global de 60s
  //   401/403 → api_key_invalid (sem retry — chave inválida não muda)
  //   SAFETY/RECITATION finishReason → tenta sem grounding; se já sem → done
  //   MAX_TOKENS finishReason → resposta parcial entregue, emite done
  //   Timeout HTTP → GeminiChunk.error('timeout')
  //   Exceção de rede → GeminiChunk.error('network')
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> _streamRequest({
    required StreamController<GeminiChunk> controller,
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
    required int attempt,
  }) async {
    final url = Uri.parse('$_endpointStream&key=$apiKey');

    // ── CAMADA 3: Injeta prefixo de ferro ANTES do systemPrompt ──────────────
    // O modelo lê _systemPromptPrefix antes de qualquer instrução do AiService.
    // Garante proibição de CoT visível mesmo sem thinkingBudget funcionar.
    final blindedSystemPrompt = '$_systemPromptPrefix$systemPrompt';

    // ── Monta contents: histórico janelado (já calibrado) + nova mensagem ─────
    // Mapeamento de roles: AppProvider usa 'assistant', Gemini API usa 'model'
    final contents = <Map<String, dynamic>>[];
    for (final entry in history) {
      final role = entry['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': entry['content'] ?? ''}
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    // ── Corpo da requisição blindado ──────────────────────────────────────────
    final body = <String, dynamic>{
      // system_instruction — isolado do histórico, lido pelo modelo como
      // instrução de sistema (não como turno de conversa). Esta é a forma
      // correta de injetar system prompts na API REST do Gemini.
      'system_instruction': {
        'parts': [
          {'text': blindedSystemPrompt}
        ],
      },
      'contents': contents,
      'generationConfig': {
        // maxOutputTokens: 3200
        //   Previne corte abrupto de texto no meio do streaming.
        //   3200 tokens ≈ 12.800 chars → suporta MODO FARMACO completo
        //   (prompt de 19 seções + RAG injetado + resposta clínica longa).
        //   Build 93: aumentado de 2048→3200 após análise de truncamentos.
        'maxOutputTokens': 3200,

        // temperature: 0.4 — equilíbrio entre precisão clínica e fluência.
        // Valores > 0.6 aumentam risco de alucinação em contexto médico.
        'temperature': 0.4,
        'topP': 0.95,
        'topK': 40,

        // thinkingConfig REMOVIDO intencionalmente do payload do stream.
        //
        // gemini-2.5-flash-lite rejeita esta chave no endpoint streamGenerateContent
        // com erro 400 "Unknown field" — o modelo lite não suporta controle de
        // thinkingBudget via generationConfig no stream.
        //
        // A proteção anti-CoT é mantida por duas camadas redundantes:
        //   [B] _systemPromptPrefix BLOCO 0/1 → instrução direta ao modelo
        //   [C] _extractText() + _looksLikeInternalReasoning() → filtros no JSON
        //
        // O thinkingConfig permanece APENAS no classifier (_classifyContext),
        // onde o modelo sync aceita a chave e a velocidade é crítica (~60 tokens).
      },

      // safetySettings — BLOCK_NONE em todas as categorias.
      // Necessário para conteúdo médico: filtros genéricos bloqueiam
      // discussões de overdose, automutilação, etc., que são legítimas
      // em contexto clínico educacional.
      'safetySettings': [
        {
          'category': 'HARM_CATEGORY_HARASSMENT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_HATE_SPEECH',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
          'threshold': 'BLOCK_NONE',
        },
        {
          'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
          'threshold': 'BLOCK_NONE',
        },
      ],
    };

    // Google Search Grounding — ativa busca na web para informações atuais.
    // Desativado automaticamente em retry de SAFETY/RECITATION.
    if (useGrounding) {
      body['tools'] = [
        {'google_search': {}}
      ];
    }

    // ── Envia requisição HTTP com stream de resposta ──────────────────────────
    late http.StreamedResponse response;
    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);

      response = await request.send().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      _log('[GeminiV2] timeout na conexão HTTP (60s)');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('timeout'))
          ..close();
      }
      return;
    } catch (e) {
      _log('[GeminiV2] erro de rede: $e');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('network'))
          ..close();
      }
      return;
    }

    // ── Tratamento de erros HTTP (antes de ler o stream) ─────────────────────

    if (response.statusCode == 429) {
      if (attempt < _maxRetries) {
        // Calcula tempo de espera — respeita header Retry-After se disponível
        Duration waitTime = _retryBackoff[attempt];
        final retryAfter = response.headers['retry-after'] ??
            response.headers['x-ratelimit-reset-requests'];
        if (retryAfter != null) {
          final retrySeconds = int.tryParse(retryAfter);
          if (retrySeconds != null && retrySeconds > 0) {
            waitTime = Duration(seconds: retrySeconds.clamp(2, 60));
          }
        }
  _log(
          '[GeminiV2] 429 rate limit — retry ${attempt + 1}/$_maxRetries '
          'em ${waitTime.inSeconds}s',
        );
        await Future.delayed(waitTime);
        if (controller.isClosed) return;
        return _streamRequest(
          controller: controller,
          apiKey: apiKey,
          userMessage: userMessage,
          systemPrompt: systemPrompt,
          history: history,
          useGrounding: useGrounding,
          attempt: attempt + 1,
        );
      }
      // Esgotou todas as tentativas → cooldown global
      _quotaUntil = DateTime.now().add(_quotaCooldown);
      _log(
        '[GeminiV2] 429 definitivo — cooldown de ${_quotaCooldown.inMinutes}min ativado',
      );
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('quota'))
          ..close();
      }
      return;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      _log('[GeminiV2] ${response.statusCode}: chave API inválida/sem permissão');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('api_key_invalid'))
          ..close();
      }
      return;
    }

    if (response.statusCode != 200) {
      _log('[GeminiV2] HTTP inesperado: ${response.statusCode}');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('http_${response.statusCode}'))
          ..close();
      }
      return;
    }

    // ══════════════════════════════════════════════════════════════════════════
    // LEITURA DO STREAM SSE (CAMADA 1 — filtragem de CoT em tempo real)
    //
    // Formato Gemini SSE:
    //   data: {"candidates":[{"content":{"parts":[{"text":"..."}]},...}]}\n\n
    //
    // Cada linha "data: {...}" é um evento JSON independente.
    // Eventos "[DONE]" ou vazios são ignorados.
    //
    // _extractText() é chamado em CADA evento — filtra 6 tipos de parts
    // não-textuais antes de qualquer char chegar ao StringBuffer da UI.
    //
    // finishReason tratamento:
    //   STOP        → conclusão normal — emite done
    //   MAX_TOKENS  → corte por limite de tokens — emite done (parcial OK)
    //   SAFETY      → filtro de segurança — retry sem grounding
    //   RECITATION  → repetição detectada — retry sem grounding
    //   outros      → trata como STOP
    // ══════════════════════════════════════════════════════════════════════════
    final lineBuffer = StringBuffer();
    bool hadContent = false;
    bool finishEmitted = false; // guarda anti-done-duplo

    try {
      await for (final bytes in response.stream) {
        if (controller.isClosed) break;

        final rawChunk = utf8.decode(bytes, allowMalformed: true);

        // Processa char a char — monta linhas completas terminadas em \n
        for (final char in rawChunk.split('')) {
          if (char == '\n') {
            final line = lineBuffer.toString().trim();
            lineBuffer.clear();

            // Ignora linhas que não sejam eventos SSE
            if (!line.startsWith('data: ')) continue;
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

            try {
              final eventData = jsonDecode(jsonStr) as Map<String, dynamic>;

              // ── CAMADA 1: Filtro rigoroso de CoT ──────────────────────────
              // _extractText() descarta qualquer part com thought/CoT/metadata.
              // Zero caracteres de raciocínio interno chegam ao controller.
              final textFragment = _extractText(eventData);
              final finishReason = _extractFinishReason(eventData);

              // ── SAFETY/RECITATION guard: não emite isDone=true se vai fazer retry
              final shouldRetryWithoutGrounding =
                  (finishReason == 'SAFETY' || finishReason == 'RECITATION') &&
                  useGrounding;

              if (textFragment.isNotEmpty) {
                hadContent = true;
                if (!controller.isClosed) {
                  controller.add(GeminiChunk(
                    text: textFragment,
                    // isDone só é true se há finishReason E não haverá retry.
                    // Sem esse guard, a UI recebe isDone antes do retry ser
                    // executado, quebrando a sincronia do streaming.
                    isDone: finishReason != null && !shouldRetryWithoutGrounding,
                  ));
                }
              } else if (finishReason != null &&
                  !hadContent &&
                  !shouldRetryWithoutGrounding) {
                // Chunk vazio com finishReason sem retry pendente
                // (ex: SAFETY sem texto gerado, já na segunda tentativa)
                if (!controller.isClosed) {
                  controller.add(const GeminiChunk(text: '', isDone: true));
                }
              }

              // ── Tratamento de finishReason ────────────────────────────────
              if (finishReason != null) {
          _log(
                  '[GeminiV2] finishReason=$finishReason '
                  '(conteúdo: ${hadContent ? 'sim' : 'nenhum'})',
                );

                switch (finishReason) {
                  case 'STOP':
                    // Conclusão normal — done já foi emitido acima se havia texto
                    finishEmitted = true;

                  case 'MAX_TOKENS':
                    // Limite de tokens atingido — resposta parcial entregue.
                    // maxOutputTokens=3200 previne isso na maioria dos casos.
                    // Quando ocorre, a resposta parcial é válida e útil.
              _log(
                      '[GeminiV2] MAX_TOKENS: resposta parcial entregue '
                      '(aumentar maxOutputTokens se recorrente)',
                    );
                    finishEmitted = true;

                  case 'SAFETY':
                  case 'RECITATION':
                    // Filtro de segurança ou detecção de recitação.
                    // Primeira tentativa: retry sem grounding (que pode
                    // trazer conteúdo que aciona o filtro).
                    if (useGrounding && !controller.isClosed) {
                _log(
                        '[GeminiV2] $finishReason: retry sem grounding',
                      );
                      return _streamRequest(
                        controller: controller,
                        apiKey: apiKey,
                        userMessage: userMessage,
                        systemPrompt: systemPrompt,
                        history: history,
                        useGrounding: false, // desativa grounding no retry
                        attempt: attempt,
                      );
                    }
                    // Já estava sem grounding — encerra sem retry adicional
                    finishEmitted = true;

                  default:
                    // finishReasons desconhecidos tratados como STOP
                    finishEmitted = true;
                }
              }
            } catch (parseError) {
              // JSON mal-formado em chunk — ignora e continua processando
        _log('[GeminiV2] parse error em evento SSE: $parseError');
            }
          } else {
            lineBuffer.write(char);
          }
        }
      }
    } catch (streamError) {
      _log('[GeminiV2] erro durante leitura do stream: $streamError');
      if (!hadContent && !controller.isClosed) {
        controller.add(GeminiChunk.error('stream_error'));
      }
    }

    // ── Fecha o controller ao terminar o stream ───────────────────────────────
    // Emite GeminiChunk.done apenas se finishReason não foi detectado no stream
    // (ex: stream encerrou abruptamente sem enviar finishReason).
    // Guarda anti-duplicata garante que AppProvider sempre receba o sinal final.
    if (!controller.isClosed) {
      if (!finishEmitted) {
        // Stream encerrado sem finishReason explícito — trata como done normal
        controller.add(GeminiChunk.done);
      }
      controller.close();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _extractText — CAMADA 1: Filtro rigoroso de CoT por evento SSE
  //
  // REGRA CENTRAL: extrair EXCLUSIVAMENTE candidates[0].content.parts[N].text
  //               onde o part NÃO seja pensamento interno do modelo.
  //
  // CONDITIONS DE DESCARTE (6 filtros cumulativos):
  //
  //   1. thought == true
  //      → Part explicitamente marcado como cadeia de pensamento (CoT).
  //        Gemini 2.5 pode gerar esses mesmo sem thinkingConfig no payload
  //        (comportamento de fallback interno do modelo). JAMAIS chega à UI.
  //
  //   2. containsKey('thoughtSignature')
  //      → Assinatura criptográfica que identifica bloco de pensamento.
  //        Aparece em conjunto com thought:true ou isoladamente.
  //
  //   3. containsKey('functionCall')
  //      → Chamada interna a ferramenta (Google Search, code interpreter).
  //        Metadado de uso interno — não é texto para o usuário.
  //
  //   4. containsKey('executableCode')
  //      → Código executável gerado internamente pelo modelo.
  //        Não deve ser exibido como resposta ao usuário.
  //
  //   5. containsKey('codeExecutionResult')
  //      → Resultado de execução de código interno.
  //        Metadado de processamento, não conteúdo de resposta.
  //
  //   6. containsKey('inlineData')
  //      → Dados binários inline (imagens, áudio, etc.).
  //        Não é texto — não processável como string.
  //
  // CONDIÇÃO DE ACEITE:
  //   Part tem chave 'text' (String, não-vazia) E não tem nenhuma das 6 acima.
  //   → Concatenado no buffer e retornado para o controller.
  //
  // Esta função é a ÚLTIMA linha de defesa. Mesmo que _systemPromptPrefix
  // seja contornado por comportamento inesperado do modelo, nenhum char
  // de CoT ou raciocínio interno chega à UI graças aos 7 filtros aqui.
  // ══════════════════════════════════════════════════════════════════════════
  static String _extractText(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';

      final candidate = candidates[0] as Map<String, dynamic>;
      final parts = candidate['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';

      final buffer = StringBuffer();

      for (final rawPart in parts) {
        final part = rawPart as Map<String, dynamic>;

        // ── 6 filtros de descarte (ordem importa: thought primeiro) ──────
        if (part['thought'] == true) continue;           // [1] CoT explícito
        if (part.containsKey('thoughtSignature')) continue; // [2] assinatura CoT
        if (part.containsKey('functionCall')) continue;     // [3] tool call
        if (part.containsKey('executableCode')) continue;   // [4] código interno
        if (part.containsKey('codeExecutionResult')) continue; // [5] resultado exec
        if (part.containsKey('inlineData')) continue;       // [6] binário inline

        // ── Aceita apenas texto puro ─────────────────────────────────────
        final text = part['text'] as String?;
        if (text != null && text.isNotEmpty) {
          // ── CAMADA 1b: Heurística anti-vazamento dentro da chave 'text' ──
          // Defesa de último recurso: mesmo que o modelo injete raciocínio
          // interno como texto comum (bypassando thought=true e o prefixo),
          // descartamos o part inteiro se contiver padrões de CoT reconhecidos.
          if (_looksLikeInternalReasoning(text)) continue;
          buffer.write(text);
        }
      }

      return buffer.toString();
    } catch (_) {
      // Exceção no parsing → retorna string vazia (seguro para o stream)
      return '';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // _looksLikeInternalReasoning — CAMADA 1b: Heurística anti-CoT no texto
  //
  // Detecta padrões de raciocínio interno que podem vazar dentro da chave
  // 'text' mesmo após _systemPromptPrefix BLOCOS 0/1 e os 6 filtros JSON.
  // Chamado por _extractText() para cada part aceito pelos 6 filtros JSON.
  //
  // CALIBRAÇÃO v5.1 (Build 93) — falso-positivo crítico corrigido:
  //   'i should' e 'i need to' removidos. Eram substrings ambíguas que
  //   apareciam em citações de diretrizes médicas legítimas, ex:
  //     "potassium levels above 6.5 mEq/L — i need to start treatment"
  //     "guidelines suggest i should consider calcium gluconate first"
  //   Causavam corte abrupto do stream no meio de respostas clínicas válidas.
  //   A proteção dessas frases é suficientemente coberta pelo BLOCO 0 do
  //   _systemPromptPrefix (instrução direta ao modelo, camada B).
  //
  // Padrões mantidos — longos, explícitos e inequívocos:
  //   • 'the user is asking' / 'the user wants' → meta-comentário de intent
  //   • '<thinking>'                            → tag XML de CoT explícita
  //   • '[análise_interna]' / '[revisão_interna]' → tags bracket de CoT
  //   • 'scratchpad'                            → rascunho interno explícito
  //
  // Retorna true → part descartado (não chega à UI).
  // Retorna false → part seguro para exibição.
  // ══════════════════════════════════════════════════════════════════════════
  static bool _looksLikeInternalReasoning(String text) {
    final lower = text.toLowerCase();
    return lower.contains('the user is asking') ||
        lower.contains('the user wants') ||
        lower.contains('<thinking>') ||
        lower.contains('[análise_interna]') ||
        lower.contains('[revisão_interna]') ||
        lower.contains('scratchpad');
  }

  // ── Extrai finishReason do evento SSE ─────────────────────────────────────
  // Retorna null para FINISH_REASON_UNSPECIFIED (chunk intermediário)
  // ou quando não há candidates válidos.
  static String? _extractFinishReason(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final candidate = candidates[0] as Map<String, dynamic>;
      final reason = candidate['finishReason'] as String?;
      // FINISH_REASON_UNSPECIFIED = chunk intermediário, não é conclusão
      if (reason == null || reason == 'FINISH_REASON_UNSPECIFIED') return null;
      return reason;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // errorMessage — Mensagens de erro bilíngues (ES/PT) para a UI
  //
  // Chamado pelo AppProvider quando o stream termina com errorCode != null.
  // Inclui hint de cooldown quando relevante (quota error com tempo restante).
  // ══════════════════════════════════════════════════════════════════════════
  static String errorMessage(String code, String lang) {
    final isEs = lang == 'es';
    final cooldownSecs = quotaCooldownRemaining?.inSeconds;
    final cooldownHint =
        (cooldownSecs != null && cooldownSecs > 0) ? ' (~${cooldownSecs}s)' : '';

    return switch (code) {
      'quota' => isEs
          ? 'Límite de consultas alcanzado$cooldownHint. '
              'Intenta de nuevo en un momento. ⚕ Apoyo educacional.'
          : 'Limite de consultas atingido$cooldownHint. '
              'Tente novamente em instantes. ⚕ Apoio educacional.',
      'api_key_invalid' => isEs
          ? 'No se pudo conectar al asistente. '
              'Verifica la configuración de la API. ⚕ Apoyo educacional.'
          : 'Não foi possível conectar ao assistente. '
              'Verifique a configuração da API. ⚕ Apoio educacional.',
      'timeout' => isEs
          ? 'La consulta tardó demasiado. '
              'Verifica tu conexión e intenta nuevamente. ⚕ Apoyo educacional.'
          : 'A consulta demorou muito. '
              'Verifique sua conexão e tente novamente. ⚕ Apoio educacional.',
      'network' => isEs
          ? 'Sin conexión a internet. '
              'Verifica la red e intenta nuevamente. ⚕ Apoyo educacional.'
          : 'Sem conexão com a internet. '
              'Verifique a rede e tente novamente. ⚕ Apoio educacional.',
      _ => isEs
          ? 'No pude procesar esa consulta. '
              '¿Puedes reformularla? ⚕ Apoyo educacional.'
          : 'Não consegui processar essa consulta. '
              'Pode reformulá-la? ⚕ Apoio educacional.',
    };
  }
}
