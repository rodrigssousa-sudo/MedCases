// ══════════════════════════════════════════════════════════════════════════════
// GeminiServiceV2 — Build 105 — Motor de IA BYOA blindado para produção
//
// ARQUITETURA v5.0 — Quatro camadas de blindagem estrutural + Design System:
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
// │  CAMADA 2 — JANELA DESLIZANTE DE HISTÓRICO (Context Classifier) B105    │
// │                                                                         │
// │  Antes de cada stream, _classifyContext() faz uma chamada leve          │
// │  (não-streaming) enviando:                                              │
// │    • Última resposta da IA (truncada a 300 chars)                       │
// │    • Nova pergunta do usuário                                           │
// │  Instrução: responda APENAS 'MÉDICO' ou 'NOVO'.                         │
// │    'MÉDICO' → mesmo caso/medicamento → últimas 5 trocas (10 entradas)  │
// │    'NOVO'   → assunto diferente      → histórico vazio (clean slate)    │
// │  Timeout 8s, fallback conservador 'MÉDICO'. Custo: ~60 tokens/chamada. │
// └─────────────────────────────────────────────────────────────────────────┘
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  CAMADA 3 — CONFIGURAÇÃO REST BLINDADA + PREFIXO DE FERRO v5 (B105)     │
// │                                                                         │
// │  • system_instruction isolado do histórico (Content.system equivalente) │
// │  • _systemPromptPrefix v6 injetado ANTES de qualquer instrução AiService│
// │    BLOCO 0: IDIOMA PT-BR/ES + ANTI-LEAK de metadados                   │
// │    BLOCO 1: PERSONA Urgência + Anti-CoT + CONCISÃO MÁXIMA (Build 108)  │
// │    BLOCO 1B: CONTRATO DE UI — tokens 🟥 ⛔ 📌 📚 para cards Flutter    │
// │    BLOCO 2: Anatomia Bupropión bilíngue (FARMACO MODE)                 │
// │    BLOCO 3: MATRIZ DE ACRÔNIMOS (IAM/AVC/TEP/PCR/ICC/IRA/FA)          │
// │  • Janela de histórico: 5 pares (era 3) — suporta diálogos longos      │
// │  • maxOutputTokens: 3200  → ceiling preservado (respostas completas)    │
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
  // PREFIXO DE FERRO v5 — CAMADA 3  (Build 105)
  //
  // NOVIDADES v5 vs v4:
  //   • BLOCO 0: reforço explícito PT-BR/ES — sem inglês na resposta clínica
  //   • BLOCO 1: mantido + BLOCO 1B NOVO — Contrato de UI (parser de cards)
  //              tokens 🟥 ⛔ 📌 📚 mapeados para elementos nativos Flutter
  //   • BLOCO 2: mantido (anatomia Bupropión bilíngue)
  //   • BLOCO 3 NOVO: Matriz de Acrônimos Críticos de Plantão
  //              IAM/AVC/TEP/PCR/FA/ICC/IRA sempre lidos como emergências médicas
  //
  // Defesas sobrepostas (inalteradas da v4):
  //   [A] thinkingConfig omitido no stream → flash-lite não vaza CoT
  //   [B] Este prefixo → instrução textual direta ao modelo
  //   [C] _extractText() + _looksLikeInternalReasoning() → 7 filtros JSON
  // ══════════════════════════════════════════════════════════════════════════
  static const _systemPromptPrefix =

      // ── BLOCO 0 — IDIOMA DINÂMICO + ANTI-LEAK (v6 — Build 108) ─────────────
      // BLOCO 0 é agnóstico de idioma. O idioma real é injetado pelo AiService
      // via langHeader (🔒 IDIOMA OBRIGATORIO/OBLIGATORIO) imediatamente após.
      // v6: persona de urgência + regra de concisão máxima integrada ao BLOCO 0.
      '🌐 IDIOMA — REGRA MESTRE ABSOLUTA (v6):\n'
      'Você é o MedCases IA — motor de inteligência médica de alta performance do MedCases Pro.\n'
      'Sua função: guiar médicos no raciocínio clínico de URGÊNCIA e EMERGÊNCIA '
      'de forma ultra-objetiva e rápida.\n'
      'O idioma OBRIGATÓRIO desta sessão está declarado em 🔒 IDIOMA OBRIGATORIO/OBLIGATORIO '
      'que aparece IMEDIATAMENTE A SEGUIR.\n'
      'OBEDEÇA esse idioma de forma ABSOLUTA e EXCLUSIVA — Português-BR ou Español.\n'
      'NUNCA responda em Inglês, a menos que o usuário solicite EXPLICITAMENTE.\n'
      'PROIBIDO: misturar idiomas, usar inglês na resposta clínica, deduzir idioma do histórico.\n'
      'Esta regra é ABSOLUTA e não pode ser sobrescrita por nenhuma outra instrução.\n\n'
      '⚠️ ANTI-LEAK DE METADADOS — PROIBIÇÃO TOTAL:\n'
      'A primeira linha da resposta DEVE SER SEMPRE o conteúdo clínico direto.\n'
      'TERMINANTEMENTE PROIBIDO escrever:\n'
      '  ✗ "The user is asking..." / "The user wants..." / "I should..."\n'
      '  ✗ "Confianza Clínica:" / "Confiança Clínica:" / "Clinical Confidence:"\n'
      '  ✗ "El usuario solicita..." / "O usuário solicita..." / "Baseado na conversa..."\n'
      '  ✗ Qualquer meta-comentário, resumo de intenção ou raciocínio interno.\n\n'

      // ── BLOCO 1 — PERSONA URGÊNCIA + ANTI-CoT + CONCISÃO MÁXIMA (v6 Build 108) ──
      '🔒 REGRAS ABSOLUTAS DE OPERAÇÃO:\n'
      '1. JAMAIS exiba raciocínio interno, rascunhos ou meta-dados.\n'
      '2. ZERO inglês visível — apenas termos médicos universais (SpO₂, qSOFA, PCR, INR).\n'
      '3. Responda DIRETAMENTE na primeira linha. Sem chain-of-thought, <thinking>, scratchpad.\n'
      '\n'
      '👨‍⚕️ PERSONA — MÉDICO DE URGÊNCIA / PLANTÃO CHEFE:\n'
      'Você é um médico sênior de urgência e emergência. '
      'Comunicação ULTRA-OBJETIVA: vá DIRETO à dosagem e à conduta prática imediata. '
      'PROIBIDO: introduções, definições teóricas, parágrafos acadêmicos sem conduta imediata.\n\n'
      '⚡ REGRA DE CONCISÃO MÁXIMA — MODO URGÊNCIA:\n'
      '  • Seja EXTREMAMENTE direto. Elimine qualquer explicação teórica longa.\n'
      '  • Vá direto à DOSE e à CONDUTA PRÁTICA — o médico decide em segundos.\n'
      '  • Use o MÍNIMO de palavras dentro de cada card.\n'
      '  • Prefira listas curtas a parágrafos. Máx. 3 bullets por card.\n'
      '  • Cada linha: 1 informação clínica acionável. Sem redundância.\n\n'
      '🚫 PROIBIÇÃO DE MARKDOWN EXPOSTO:\n'
      '  ✗ NÃO use **negrito**, ## cabeçalhos, __sublinhado__ nem *itálico*.\n'
      'PERMITIDO: bullets simples (- item), MAIÚSCULAS para ênfase, (>) para alertas.\n\n'

      // ── BLOCO 1B — CONTRATO DE UI / DESIGN SYSTEM DE CARDS (Build 105) ─────
      // CRÍTICO: O app Flutter usa um parser que converte esses tokens em
      // elementos visuais nativos (cards coloridos). Respeitar RIGOROSAMENTE.
      '🎨 CONTRATO DE FORMATAÇÃO — DESIGN SYSTEM DO APP (PARSER COMPATIBILITY):\n'
      'O aplicativo converte os tokens abaixo em cards visuais nativos.\n'
      'USE OBRIGATORIAMENTE estes marcadores para estruturar condutas médicas:\n'
      '\n'
      '  🟥 CARD VERMELHO — Conduta Principal / Prescrição Medicamentosa:\n'
      '     Formato: 🟥 NOME-DO-FÁRMACO EM MAIÚSCULO — dose via frequência\n'
      '     Exemplo: 🟥 AMOXICILINA — 500 mg VO 8/8h por 7 dias\n'
      '     Exemplo: 🟥 LEVODOPA + CARBIDOPA — 100/25 mg VO 3x/dia\n'
      '     Use para: medicamento de 1ª escolha, dose de ataque, protocolo principal.\n'
      '\n'
      '  ⛔ CARD LARANJA — Alertas / Contraindicações / Interações:\n'
      '     Formato: ⛔ Texto do alerta clínico relevante\n'
      '     Exemplo: ⛔ Contraindicado em insuficiência renal grave (ClCr < 15)\n'
      '     Use para: contraindicações absolutas, alertas de segurança, interações graves.\n'
      '\n'
      '  📌 CARD AZUL — Próximo Passo / Refinamento Diagnóstico:\n'
      '     Formato: 📌 Texto da pergunta ou direcionamento clínico\n'
      '     Exemplo: 📌 Quer ajuste por peso/renal ou titulação progressiva?\n'
      '     Use para: perguntas de refinamento, próxima conduta, decisão compartilhada.\n'
      '\n'
      '  📚 RODAPÉ DE EVIDÊNCIA — Linha final de cada resposta:\n'
      '     Formato: 📚 Guideline1 · Guideline2 · PubMed · Harrison\n'
      '     Exemplo: 📚 Harrison · PubMed · Guidelines de Emergência · SBC 2023\n'
      '     OBRIGATÓRIO: finalizar TODA resposta com esta linha de referências.\n'
      '\n'
      'REGRA DE SAUDAÇÃO: Se o histórico já contiver mensagens anteriores,\n'
      'NÃO repita "Bom dia", "Olá", "Claro", "Com prazer" — vá direto ao conteúdo clínico.\n\n'

      // ── BLOCO 2 — ANATOMIA BUPROPIÓN v5 BILÍNGUE (FARMACO MODE COMPLETO) ──
      '🏗️ ANATOMIA — MODO FARMACO COMPLETO (modelo Bupropión):\n'
      'Ativa SOMENTE em FARMACO MODE COMPLETO. Adaptar títulos ao idioma.\n'
      '\n'
      '  § 1 — DEFINICIÓN / DEFINIÇÃO\n'
      '    1 parágrafo curto (máx. 3 linhas). Mecanismo em MAIÚSCULAS.\n'
      '\n'
      '  § 2 — INDICACIONES Y DOSIS / INDICAÇÕES E DOSES\n'
      '    Bullets curtos com indicação + DOSE: [valor] [via] [frequência]. Máx. 5.\n'
      '\n'
      '  § 3 — ALERTA DE SEGURANÇA (somente se risco real de vida)\n'
      '    > 🔴 ALERTA CRÍTICO: [contraindicação absoluta ou efeito fatal]\n'
      '\n'
      '  § 4 — OUTROS PONTOS\n'
      '    Máx. 4 bullets: efeitos adversos relevantes, interações, monitoramento.\n'
      '\n'
      '  § 5 — RODAPÉ DE EVIDÊNCIA\n'
      '    📚 Referências base: Harrison · PubMed · [guideline relevante]\n\n'

      // ── BLOCO 3 — MATRIZ DE ACRÔNIMOS CRÍTICOS DE PLANTÃO (Build 105) ──────
      // Garante que siglas ambíguas em contexto de urgência/emergência sejam
      // SEMPRE interpretadas sob a ótica médica — nunca como TI/corporativo.
      '🚨 MATRIZ DE ACRÔNIMOS CRÍTICOS — INTERPRETAÇÃO OBRIGATÓRIA:\n'
      'Toda sigla abaixo, quando mencionada sem contexto adicional, deve ser\n'
      'interpretada IMEDIATAMENTE como emergência/urgência médica:\n'
      '\n'
      '  IAM  → INFARTO AGUDO DO MIOCÁRDIO     (Risco: 🔴 VERMELHO — Emergência)\n'
      '         NUNCA: "Identity and Access Management" ou qualquer sigla de TI.\n'
      '  AVC  → ACIDENTE VASCULAR CEREBRAL      (Risco: 🔴 VERMELHO — Emergência)\n'
      '  AVE  → ACIDENTE VASCULAR ENCEFÁLICO    (Risco: 🔴 VERMELHO — Emergência)\n'
      '  TEP  → TROMBOEMBOLISMO PULMONAR         (Risco: 🔴 VERMELHO — Emergência)\n'
      '  TEPA → TROMBOEMBOLISMO PULMONAR AGUDO   (Risco: 🔴 VERMELHO — Emergência)\n'
      '  PCR  → PARADA CARDIORRESPIRATÓRIA       (Risco: 🔴 VERMELHO — Emergência)\n'
      '         NUNCA: "Polymerase Chain Reaction" em contexto clínico de emergência.\n'
      '  ICC  → INSUFICIÊNCIA CARDÍACA CONGESTIVA (Risco: 🟠 LARANJA — Urgência)\n'
      '  IRA  → INSUFICIÊNCIA RENAL AGUDA        (Risco: 🟠 LARANJA — Urgência)\n'
      '  FA   → FIBRILAÇÃO ATRIAL                (Risco: 🟠 LARANJA — Urgência)\n'
      '  SCA  → SÍNDROME CORONÁRIA AGUDA         (Risco: 🔴 VERMELHO — Emergência)\n'
      '  SEPSE → SEPSE / CHOQUE SÉPTICO          (Risco: 🔴 VERMELHO — Emergência)\n'
      '\n'
      'PROIBIDO ABSOLUTO: interpretar siglas médicas como termos de tecnologia,\n'
      'negócios ou segurança digital. Qualquer sigla ambígua neste contexto → MÉDICO.\n\n';

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

    // ── Passo 1: Janela de histórico ─────────────────────────────────────────
    // Build 110: BYPASS do _classifyContext — o classificador era o ponto de
    // falha da memória. Ele podia retornar 'NOVO' para follow-ups legítimos
    // ('Mais detalhes', 'E a dose?') e descartar o histórico inteiro.
    // Solução: sempre passa o histórico janelado. O Gemini com o system prompt
    // já tem contexto suficiente para distinguir continuidade de novo tema.
    // O _classifyContext ainda existe para uso futuro mas não bloqueia mais o histórico.
    final windowedHistory = _buildContextWindow(history, 'MÉDICO');
    _log('[GeminiV2] histórico → ${windowedHistory.length ~/ 2} troca(s) no payload (classifier bypass Build 110)');

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
  // _buildContextWindow — Janela deslizante de histórico (CAMADA 2)  Build 105
  //
  // Controla quantas trocas anteriores são enviadas no payload da API.
  //
  // 'MÉDICO' (mesmo caso / follow-up):
  //   → Retorna as últimas 5 trocas = max 10 entradas.
  //   → Build 105: aumentado de 3→5 pares para suportar diálogos longos
  //     sem perder o fio da meada clínica após o 4º turno.
  //   → Uma troca = 1 user + 1 model. 5 trocas ≈ 2.000 tokens de contexto.
  //
  // 'NOVO' (assunto diferente — classificador confirmou mudança de tema):
  //   → Build 105: retorna lista vazia APENAS quando history.length >= 2
  //     (já há pelo menos 1 troca completa). Se history.length < 2, o
  //     classifier raramente tem contexto suficiente para ser confiável
  //     → nesse caso retorna lista vazia igualmente (primeira mensagem).
  //   → Previne "contaminação cruzada" de dados clínicos entre casos.
  //
  // IMPORTANTE: este método NÃO modifica o histórico original no AppProvider.
  // Retorna uma CÓPIA calibrada para o payload da requisição atual.
  // ══════════════════════════════════════════════════════════════════════════
  static List<Map<String, String>> _buildContextWindow(
    List<Map<String, String>> history,
    String contextLabel,
  ) {
    if (contextLabel == 'NOVO') {
      // Assunto novo confirmado pelo classificador — clean slate para evitar
      // mistura de dados clínicos entre casos distintos (segurança do paciente).
      _log('[GeminiV2] NOVO: histórico descartado para este payload (${history.length} entradas)');
      return [];
    }

    // Mesmo assunto — Build 105: janela ampliada para 5 pares (era 3)
    // Suporta diálogos de acompanhamento sem perda de memória conversacional.
    const maxPairs = 5;
    const maxEntries = maxPairs * 2; // 10 entradas = 5 user + 5 model

    if (history.length <= maxEntries) {
      _log('[GeminiV2] MÉDICO: histórico completo (${history.length} entradas)');
      return List.of(history); // já dentro do limite — usa tudo sem truncar
    }

    // Pega as [maxEntries] entradas mais recentes
    final window = history.sublist(history.length - maxEntries);
    _log(
      '[GeminiV2] MÉDICO: janela deslizante ${history.length} → ${window.length} entradas (últimos $maxPairs turnos)',
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
      // Classifica o tipo de erro de rede para melhor feedback ao usuário.
      // SocketException → perda total de conectividade (Wi-Fi/4G desconectado)
      // Outros → falha de conexão genérica
      final errStr = e.toString().toLowerCase();
      final isSocket = errStr.contains('socketexception') ||
          errStr.contains('connection refused') ||
          errStr.contains('no address associated') ||
          errStr.contains('network is unreachable') ||
          errStr.contains('connection reset') ||
          errStr.contains('broken pipe') ||
          errStr.contains('os error');
      _log('[GeminiV2] erro de rede${isSocket ? " (SocketException)" : ""}: $e');
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
  // _looksLikeInternalReasoning — CAMADA 1b v5.3 (Build 97)
  //
  // Build 97 — adicionado: detecção de tool_code/google_search leaks.
  // Quando o Google Search Grounding está ativo, o modelo Gemini pode vazar
  // blocos de chamada de ferramenta como texto plain em vez de functionCall part.
  // Exemplo de vazamento documentado no screenshot IMG_2909.jpg:
  //   "tool_code\nprint(google_search.search(queries=[\"manejo y tratamiento..."
  // Este bloco é puramente interno e jamais deve ser exibido ao médico.
  //
  // NOTA IMPORTANTE: Este filtro age sobre CADA CHUNK individual do stream SSE.
  // Se o cabeçalho vier num chunk separado (o que acontece frequentemente),
  // ele é descartado antes de entrar no buffer acumulado. A _cleanAiText()
  // (CAMADA 2) pega o residual caso o padrão esteja num chunk misto.
  static bool _looksLikeInternalReasoning(String text) {
    final lower = text.toLowerCase();

    // ── Build 97: tool_code / google_search leak detector ──────────────────
    // Captura blocos de chamada de ferramenta vazados como texto plain.
    // Padrões inequívocos — nunca aparecem em texto clínico legítimo.
    if (lower.contains('tool_code')) return true;
    if (lower.contains('google_search')) return true;
    if (lower.contains('print(google')) return true;
    if (lower.contains('print(perplexity')) return true;
    if (lower.contains('perplexity_search')) return true;
    if (lower.contains('search_query')) return true;
    if (lower.contains('queries=[')) return true;
    if (lower.contains('```tool_code')) return true;
    if (lower.contains('```python')) return true;
    if (lower.contains('```json\n{')) return true;

    // ── Padrões longos e inequívocos de CoT (calibração v5.1) ──────────────
    if (lower.contains('the user is asking')) return true;
    if (lower.contains('the user wants')) return true;
    if (lower.contains('<thinking>')) return true;
    if (lower.contains('[análise_interna]')) return true;
    if (lower.contains('[revisão_interna]')) return true;
    if (lower.contains('scratchpad')) return true;

    // Build 96 — catch-all bilíngue "Confian[za|ça] Clínica" v6.0
    // Padrão ampliado: captura QUALQUER variação que contenha "confian" + "cl"
    // — sem dois-pontos, com markdown, com pipe, uppercase, etc.
    if (lower.contains('confianza cl') ||
        lower.contains('confiança cl') ||
        lower.contains('confianza:') ||
        lower.contains('confiança:') ||
        lower.contains('clinical confidence') ||
        lower.contains('nivel de confianza') ||
        lower.contains('nível de confiança') ||
        lower.contains('nivel de confiança') ||
        lower.contains('nível de confianza')) {
      return true;
    }
    // Regex catch-all: qualquer chunk que contenha "confian" seguido de
    // espaços/pontuação/markdown e depois "cl" (clínica/clinica)
    if (RegExp(r'confian[zç]a', caseSensitive: false).hasMatch(lower)) {
      return true;
    }

    // ── Build 100: padrões de CoT adicionais capturados em produção ──────────
    // Variantes não cobertas pela regex anterior — encontradas em TestFlight
    if (lower.contains('el usuario ha indicado')) return true;
    if (lower.contains('el usuario ha proporcionado')) return true;
    if (lower.contains('el usuario ha solicitado')) return true;
    if (lower.contains('o usuário informou')) return true;
    if (lower.contains('o usuário forneceu')) return true;
    if (lower.contains('o usuário indicou')) return true;
    if (lower.contains('a consulta é sobre')) return true;
    if (lower.contains('la consulta es sobre')) return true;
    if (lower.contains('según lo solicitado')) return true;
    if (lower.contains('conforme solicitado')) return true;
    if (lower.contains('para responder a esta')) return true;
    if (lower.contains('para responder esta')) return true;
    if (lower.contains('vou responder')) return true;
    if (lower.contains('voy a responder')) return true;
    if (lower.contains('la pregunta del usuario')) return true;
    if (lower.contains('a pergunta do usuário')) return true;
    if (lower.contains('a pergunta do usuario')) return true;

    // Padrão meta-comentário: "El usuario solicita/proporciona/pregunta..."
    // como sentença de abertura (primeiros 120 chars do chunk)
    final head = lower.length > 120 ? lower.substring(0, 120) : lower;
    if (RegExp(
      r'^\s*(?:el\s+usuario\s+(?:solicita|proporciona|pregunta|pide|quiere|busca|ha\s+(?:pedido|indicado|proporcionado|solicitado))'
      r'|o\s+usu[aá]rio\s+(?:solicita|fornece|pergunta|pede|quer|busca|indicou|informou|forneceu)'
      r'|the\s+user\s+(?:is\s+asking|asks|wants|requests|provides|has\s+indicated|has\s+asked)'
      r'|baseado\s+(?:no|na)\s+(?:contexto|conversa)'
      r'|basado\s+en\s+(?:el\s+contexto|la\s+conversaci)'
      r'|vou\s+(?:responder|elaborar|fornecer|apresentar|descrever)'
      r'|voy\s+a\s+(?:responder|elaborar|proporcionar|presentar|describir))',
      caseSensitive: false,
    ).hasMatch(head)) {
      return true;
    }

    return false;
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
          ? '🚨 Conexión Requerida\n\n'
              'La consulta tardó demasiado — posible señal débil en el hospital.\n\n'
              'El resto de tus herramientas sigue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interacciones — motor offline activo\n'
              '• 🧮 Calculadoras — sin necesidad de red\n\n'
              'Verifica tu señal y vuelve a intentarlo.'
          : '🚨 Conexão Necessária\n\n'
              'A consulta demorou muito — possível sinal fraco no hospital.\n\n'
              'O restante das suas ferramentas segue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interações — motor offline ativo\n'
              '• 🧮 Calculadoras — sem necessidade de rede\n\n'
              'Verifique seu sinal e tente novamente.',
      'network' => isEs
          ? '🚨 Conexión Requerida\n\n'
              'La IA de MedCases requiere conexión a internet para procesar '
              'análisis cognitivos avanzados.\n\n'
              'El resto de tus herramientas sigue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interacciones — motor offline activo\n'
              '• 🧮 Calculadoras — sin necesidad de red\n\n'
              'Verifica tu señal y vuelve a intentarlo.'
          : '🚨 Conexão Necessária\n\n'
              'A IA do MedCases requer conexão com a internet para processar '
              'análises cognitivas avançadas.\n\n'
              'O restante das suas ferramentas segue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interações — motor offline ativo\n'
              '• 🧮 Calculadoras — sem necessidade de rede\n\n'
              'Verifique seu sinal e tente novamente.',
      // stream_error = SSE caiu no meio → tratado como falha de rede
      'stream_error' => isEs
          ? '🚨 Conexión Requerida\n\n'
              'La conexión con el servidor de IA se interrumpió.\n\n'
              'El resto de tus herramientas sigue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interacciones — motor offline activo\n'
              '• 🧮 Calculadoras — sin necesidad de red\n\n'
              'Verifica tu señal y vuelve a intentarlo.'
          : '🚨 Conexão Necessária\n\n'
              'A conexão com o servidor de IA foi interrompida.\n\n'
              'O restante das suas ferramentas segue operando 100% offline:\n'
              '• 💊 Fármacos — base completa embarcada\n'
              '• ⚠️ Interações — motor offline ativo\n'
              '• 🧮 Calculadoras — sem necessidade de rede\n\n'
              'Verifique seu sinal e tente novamente.',
      _ => isEs
          ? 'No pude procesar esa consulta. '
              '¿Puedes reformularla? ⚕ Apoyo educacional.'
          : 'Não consegui processar essa consulta. '
              'Pode reformulá-la? ⚕ Apoio educacional.',
    };
  }
}
