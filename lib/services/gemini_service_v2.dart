// ══════════════════════════════════════════════════════════════════════════════
// GeminiServiceV2 — Streaming descentralizado por usuário
//
// ARQUITETURA:
//   Sem firebase_ai (incompatível com firebase_core 3.6.0 em produção).
//   Usa a API REST streamGenerateContent do Gemini com Server-Sent Events (SSE).
//   É exatamente o que o firebase_ai SDK faz internamente.
//
// BENEFÍCIOS vs V1:
//   • Streaming token-a-token — UX idêntica ao ChatGPT/Claude
//   • Sem fila serial global — cada chamada é independente
//   • systemInstruction injetada no modelo (blindagem do system prompt)
//   • Retry com backoff exponencial isolado por chamada (não global)
//   • Nenhuma dependência nova — usa apenas http já presente no pubspec
//
// ENDPOINT:
//   POST /v1beta/models/gemini-2.5-flash:streamGenerateContent?alt=sse&key=KEY
//   Retorna chunks SSE: "data: {...}\n\n" — cada chunk é um candidato parcial.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Resultado de chunk de streaming
// ─────────────────────────────────────────────────────────────────────────────
class GeminiChunk {
  /// Texto parcial do chunk (pode ser vazio se for chunk de metadado).
  final String text;

  /// true se este chunk finaliza a resposta (finishReason != null).
  final bool isDone;

  /// Código de erro se a requisição falhou (null = sucesso).
  final String? errorCode;

  const GeminiChunk({
    required this.text,
    this.isDone = false,
    this.errorCode,
  });

  bool get isError => errorCode != null;

  factory GeminiChunk.error(String code) =>
      GeminiChunk(text: '', isDone: true, errorCode: code);

  static const GeminiChunk done =
      GeminiChunk(text: '', isDone: true);
}

// ─────────────────────────────────────────────────────────────────────────────
// GeminiServiceV2
// ─────────────────────────────────────────────────────────────────────────────
class GeminiServiceV2 {
  GeminiServiceV2._(); // utilitário estático — sem instâncias

  // ── Endpoint SSE do Gemini 2.5 Flash ──────────────────────────────────────
  // alt=sse → resposta em Server-Sent Events (stream de chunks JSON)
  static const _baseEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/'
      'gemini-2.5-flash:streamGenerateContent?alt=sse';

  // ── Configurações de retry ─────────────────────────────────────────────────
  // Backoff conservador: o Gemini free tier tem limite de 15 RPM (requests/min).
  // Se o 429 veio, há alta probabilidade de esgotamento real — esperar mais vale.
  // O header Retry-After é preferido quando disponível (respeitando o servidor).
  static const _maxRetries  = 3;
  static const _backoff     = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  // ── Cooldown global pós-429 ───────────────────────────────────────────────
  // Após um 429 definitivo (esgotou retries), bloqueia novas requisições por
  // [_quotaCooldown] para não desperdiçar tokens em requisições condenadas.
  // Reset automático após o cooldown ou quando o usuário trocar de sessão.
  static DateTime? _quotaUntil;
  static const _quotaCooldown = Duration(minutes: 1);

  /// Verifica se há cooldown ativo (pós-quota 429 definitivo).
  static bool get isInQuotaCooldown =>
      _quotaUntil != null && DateTime.now().isBefore(_quotaUntil!);

  /// Quanto tempo falta para o cooldown terminar (null se não há cooldown).
  static Duration? get quotaCooldownRemaining {
    if (_quotaUntil == null) return null;
    final remaining = _quotaUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Reseta o cooldown manualmente (ex: usuário trocou de chave API).
  static void resetQuotaCooldown() => _quotaUntil = null;

  // ══════════════════════════════════════════════════════════════════════════
  // sendStream — Streaming token-a-token via SSE
  //
  // Parâmetros:
  //   apiKey        : Gemini API key (mesma já usada pelo GeminiService V1)
  //   userMessage   : mensagem do usuário
  //   systemPrompt  : injetado como systemInstruction no modelo (blindagem total)
  //   history       : histórico de conversa [{role, content}, ...]
  //
  // Retorna:
  //   Stream<GeminiChunk> — cada evento é um chunk de texto ou sinalização de fim.
  //   O chamador (AppProvider) acumula os chunks num StringBuffer e notifica a UI.
  //
  // Erros:
  //   Chunks com isError=true e errorCode preenchido.
  //   Retry automático em 429 com backoff — transparente para o chamador.
  // ══════════════════════════════════════════════════════════════════════════
  static Stream<GeminiChunk> sendStream({
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
  }) {
    // Usa StreamController para poder fazer retry assíncrono dentro do stream.
    final controller = StreamController<GeminiChunk>();

    // ── Verifica cooldown global pós-429 ─────────────────────────────────────
    // Se há um 429 recente definitivo, não tenta novamente — falha imediata.
    if (isInQuotaCooldown) {
      final remaining = quotaCooldownRemaining;
      debugPrint('[GeminiV2] quota cooldown ativo — ${remaining?.inSeconds}s restantes');
      controller
        ..add(GeminiChunk.error('quota'))
        ..close();
      return controller.stream;
    }

    // Executa em background — não bloqueia o caller
    _executeWithRetry(
      controller: controller,
      apiKey: apiKey,
      userMessage: userMessage,
      systemPrompt: systemPrompt,
      history: history,
      useGrounding: useGrounding,
      attempt: 0,
    );

    return controller.stream;
  }

  // ── Execução com retry recursivo ──────────────────────────────────────────
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
      // Erro inesperado não capturado internamente
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('unexpected'))
          ..close();
      }
    }
  }

  // ── Requisição SSE com parsing de chunks ──────────────────────────────────
  static Future<void> _streamRequest({
    required StreamController<GeminiChunk> controller,
    required String apiKey,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
    required int attempt,
  }) async {
    final url = Uri.parse('$_baseEndpoint&key=$apiKey');

    // ── Monta corpo da requisição ─────────────────────────────────────────────
    // systemInstruction → blindagem total: o system prompt é injetado
    // diretamente no modelo, não como mensagem de usuário. Garante que
    // o contexto RAG e as diretrizes educacionais nunca vazem para o histórico.
    final contents = <Map<String, dynamic>>[];
    for (final msg in history) {
      final role = msg['role'] == 'assistant' ? 'model' : 'user';
      contents.add({
        'role': role,
        'parts': [
          {'text': msg['content'] ?? ''}
        ]
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ]
    });

    final body = <String, dynamic>{
      // ── systemInstruction: injeção direta no modelo ───────────────────────
      // Equivalente a Content.system(systemPrompt) do firebase_ai SDK.
      // Desta forma o system prompt nunca aparece no histórico de conversa,
      // é interpretado pelo modelo como instrução de nível de sistema.
      'system_instruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'maxOutputTokens': 2200,
        'temperature': 0.4,
        'topP': 0.95,
        'topK': 40,
        // thinkingBudget: 0 — desativa thinking tokens do Gemini 2.5 Flash.
        // Sem isso, o modelo gasta tokens de "raciocínio" antes de responder,
        // consumindo quota rapidamente e causando 429 em poucas consultas.
        'thinkingConfig': {'thinkingBudget': 0},
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT',        'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH',       'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_NONE'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_NONE'},
      ],
    };

    // Google Search Grounding — Gemini busca na web quando necessário
    if (useGrounding) {
      body['tools'] = [
        {'google_search': {}}
      ];
    }

    final bodyJson = jsonEncode(body);

    // ── Faz a requisição HTTP com stream de resposta ───────────────────────
    late http.StreamedResponse response;
    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = bodyJson;

      response = await request.send().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      if (controller.isClosed) return;
      controller
        ..add(GeminiChunk.error('timeout'))
        ..close();
      return;
    } catch (e) {
      if (controller.isClosed) return;
      controller
        ..add(GeminiChunk.error('network'))
        ..close();
      return;
    }

    // ── Trata erros HTTP antes de ler o stream ────────────────────────────
    if (response.statusCode == 429) {
      // Rate limit — retry com backoff se ainda há tentativas disponíveis
      if (attempt < _maxRetries) {
        // Respeita o header Retry-After se o servidor o enviar
        Duration wait = _backoff[attempt];
        final retryAfterHeader = response.headers['retry-after'] ??
            response.headers['x-ratelimit-reset-requests'];
        if (retryAfterHeader != null) {
          final retrySeconds = int.tryParse(retryAfterHeader);
          if (retrySeconds != null && retrySeconds > 0) {
            // Usa o valor do servidor, mas limita a 60s para não bloquear demais
            wait = Duration(seconds: retrySeconds.clamp(2, 60));
          }
        }
        debugPrint(
            '[GeminiV2] 429 — retry ${attempt + 1}/$_maxRetries em ${wait.inSeconds}s');
        await Future.delayed(wait);
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
      // Esgotou retries — ativa cooldown global para evitar spam
      _quotaUntil = DateTime.now().add(_quotaCooldown);
      debugPrint('[GeminiV2] 429 definitivo — cooldown de ${_quotaCooldown.inSeconds}s ativado');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('quota'))
          ..close();
      }
      return;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint('[GeminiV2] ${response.statusCode}: API key inválida');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('api_key_invalid'))
          ..close();
      }
      return;
    }

    if (response.statusCode != 200) {
      debugPrint('[GeminiV2] HTTP ${response.statusCode}');
      if (!controller.isClosed) {
        controller
          ..add(GeminiChunk.error('http_${response.statusCode}'))
          ..close();
      }
      return;
    }

    // ── Lê stream SSE byte a byte ─────────────────────────────────────────
    // O Gemini retorna chunks no formato:
    //   data: {"candidates":[{"content":{"parts":[{"text":"..."}]},...}]}\n\n
    //
    // Usamos um buffer de linha para montar o JSON completo de cada evento.
    final lineBuffer = StringBuffer();
    bool hadContent = false;

    try {
      await for (final bytes in response.stream) {
        if (controller.isClosed) break;

        final chunk = utf8.decode(bytes, allowMalformed: true);

        // Processa cada caractere — monta linhas completas
        for (final char in chunk.split('')) {
          if (char == '\n') {
            final line = lineBuffer.toString().trim();
            lineBuffer.clear();

            if (line.startsWith('data: ')) {
              final jsonStr = line.substring(6).trim();
              if (jsonStr == '[DONE]' || jsonStr.isEmpty) continue;

              try {
                final data = jsonDecode(jsonStr) as Map<String, dynamic>;
                final text = _extractText(data);
                final finishReason = _extractFinishReason(data);

                if (text.isNotEmpty) {
                  hadContent = true;
                  if (!controller.isClosed) {
                    controller.add(GeminiChunk(
                      text: text,
                      isDone: finishReason != null,
                    ));
                  }
                }

                // finishReason presente → resposta completa
                if (finishReason != null) {
                  debugPrint('[GeminiV2] finishReason=$finishReason');
                  if (finishReason == 'SAFETY' || finishReason == 'RECITATION') {
                    // Tenta sem grounding se ainda estava com grounding
                    if (useGrounding && !controller.isClosed) {
                      controller.add(GeminiChunk(text: '', isDone: false));
                      // Refaz sem grounding
                      return _streamRequest(
                        controller: controller,
                        apiKey: apiKey,
                        userMessage: userMessage,
                        systemPrompt: systemPrompt,
                        history: history,
                        useGrounding: false,
                        attempt: attempt,
                      );
                    }
                  }
                }
              } catch (e) {
                // JSON mal-formado no chunk — ignora e continua
                debugPrint('[GeminiV2] parse error em chunk: $e');
              }
            }
          } else {
            lineBuffer.write(char);
          }
        }
      }
    } catch (e) {
      debugPrint('[GeminiV2] erro no stream: $e');
      if (!hadContent && !controller.isClosed) {
        controller.add(GeminiChunk.error('stream_error'));
      }
    }

    // Fecha o controller ao terminar o stream
    if (!controller.isClosed) {
      controller
        ..add(GeminiChunk.done)
        ..close();
    }
  }

  // ── Extrai texto dos candidates do chunk JSON ──────────────────────────────
  static String _extractText(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';

      final candidate = candidates[0] as Map<String, dynamic>;
      final parts = candidate['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';

      // Filtra: apenas parts de texto (não thought, functionCall, etc.)
      final buffer = StringBuffer();
      for (final part in parts) {
        final p = part as Map<String, dynamic>;
        if (p['thought'] == true) continue;
        if (p.containsKey('functionCall')) continue;
        if (p.containsKey('executableCode')) continue;
        if (p.containsKey('codeExecutionResult')) continue;
        final text = p['text'] as String?;
        if (text != null && text.isNotEmpty) buffer.write(text);
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  // ── Extrai finishReason do chunk JSON ─────────────────────────────────────
  static String? _extractFinishReason(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final candidate = candidates[0] as Map<String, dynamic>;
      final reason = candidate['finishReason'] as String?;
      // STOP = conclusão normal; outros = especiais (SAFETY, MAX_TOKENS, etc.)
      if (reason == null || reason == 'FINISH_REASON_UNSPECIFIED') return null;
      return reason;
    } catch (_) {
      return null;
    }
  }

  // ── Mapeia errorCode para mensagem amigável bilíngue ──────────────────────
  static String errorMessage(String code, String lang) {
    final isEs = lang == 'es';
    // Para quota: inclui tempo restante do cooldown se disponível
    final cooldownSecs = quotaCooldownRemaining?.inSeconds;
    final cooldownHint = cooldownSecs != null && cooldownSecs > 0
        ? (isEs ? ' (~${cooldownSecs}s)' : ' (~${cooldownSecs}s)')
        : '';

    return switch (code) {
      'quota' => isEs
          ? 'Límite de consultas alcanzado$cooldownHint. Intenta de nuevo en un momento. ⚕ Apoyo educacional.'
          : 'Limite de consultas atingido$cooldownHint. Tente novamente em instantes. ⚕ Apoio educacional.',
      'api_key_invalid' => isEs
          ? 'No se pudo conectar al asistente. Verifica la configuración de la API. ⚕ Apoyo educacional.'
          : 'Não foi possível conectar ao assistente. Verifique a configuração da API. ⚕ Apoio educacional.',
      'timeout' => isEs
          ? 'La consulta tardó demasiado. Verifica tu conexión e intenta nuevamente. ⚕ Apoyo educacional.'
          : 'A consulta demorou muito. Verifique sua conexão e tente novamente. ⚕ Apoio educacional.',
      'network' => isEs
          ? 'Sin conexión a internet. Verifica la red e intenta nuevamente. ⚕ Apoyo educacional.'
          : 'Sem conexão com a internet. Verifique a rede e tente novamente. ⚕ Apoio educacional.',
      _ => isEs
          ? 'No pude procesar esa consulta. ¿Puedes reformularla? ⚕ Apoyo educacional.'
          : 'Não consegui processar essa consulta. Pode reformulá-la? ⚕ Apoio educacional.',
    };
  }
}
