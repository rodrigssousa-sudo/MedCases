// ══════════════════════════════════════════════════════════════════════════════
// AiGatewayService — Build 155 (Dois Motores Independentes)
// Cliente SSE para o MedCases AI Gateway (servidor Node.js/Express)
//
// ARQUITETURA (Build 155):
//   Modo Plantão → POST /api/ai/stream/plantao → Motor Plantão exclusivo
//   Modo Estudos → POST /api/ai/stream/estudo  → Motor Estudos exclusivo
//
//   O campo `longResponse` NÃO é mais enviado no payload JSON.
//   O motor é determinado pela URL da rota — não pelo payload do cliente.
//   Isso elimina conflitos de regras e bugs de validação de payload.
//
// ROTAS DO SERVIDOR (Build 155):
//   POST /api/ai/stream/plantao → PROMPT_MODO_PLANTAO + MODE_ANCHOR_PLANTAO
//                                  LINE BUDGET ≤14 linhas, TRAVA DE FALLBACK
//   POST /api/ai/stream/estudo  → PROMPT_MODO_ESTUDO  + MODE_ANCHOR_ESTUDO
//                                  LINE BUDGET ≤24 linhas, ACRONYM RULE
//   POST /api/ai/stream         → alias legado (retrocompat. builds <155)
//
// VANTAGENS vs. rota única com longResponse:
//   • Modo determinado server-side pela URL — impossível de divergir
//   • Payload mais limpo: sem campo booleano de controle de modo
//   • Logs do servidor identificam o motor pelo endpoint, não pelo payload
//   • Dois motores completamente isolados sem risco de contaminação
//
// PROTOCOLO SSE DO SERVIDOR:
//   Eventos recebidos:
//     data: {"text":"fragmento"}\n\n   → chunk de texto
//     data: {"done":true}\n\n         → stream concluído
//     data: {"error":"código"}\n\n    → falha com código
//     : ping\n\n                       → heartbeat (ignorado)
//
// INTERFACE DE SAÍDA:
//   Stream<GeminiChunk> — mesma interface do GeminiServiceV2 para que o
//   AppProvider possa usar os dois backends de forma transparente.
//
// CONFIGURAÇÃO:
//   AiGatewayService.configure(baseUrl: 'https://seu-servidor.ondigitalocean.app')
//   AiGatewayService.isConfigured → true se baseUrl foi definida
//
// ANTI-BUFFERING (Build 146):
//   Importação condicional por plataforma:
//     • IO  (iOS/Android/desktop): ai_gateway_service_io.dart
//         → usa package:http com http.Client.send() streaming — dart:io lê
//           o socket TCP de forma incremental, sem buffering extra.
//     • Web (Flutter Web / dart2js): ai_gateway_service_web.dart
//         → usa dart:js_interop + window.fetch() nativo com ReadableStream,
//           bypassando o BrowserClient do http.dart e eliminando o
//           micro-batching do Dart VM na Web.
//   A função runSseStreamPlatform() é o ponto de entrada de cada arquivo.
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'gemini_service_v2.dart' show GeminiChunk;

// ── Importação condicional por plataforma (Build 146) ────────────────────────
// Na Web: ai_gateway_service_web.dart (dart:js_interop + fetch nativo)
// Nas demais plataformas: ai_gateway_service_io.dart (http.Client streaming)
import 'ai_gateway_service_io.dart'
    if (dart.library.js_interop) 'ai_gateway_service_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constante de produção — URL do servidor Digital Ocean App Platform
//
// Build 155.2: URL hardcoded aqui para garantir que o gateway seja sempre
// usado, independentemente de qualquer chamada a configure(). O servidor
// em produção roda em https://medcasespro.com/api/* via reverse-proxy,
// ou no endpoint direto do Digital Ocean App Platform abaixo.
// Para alterar o endpoint basta mudar esta constante e recompilar.
// ─────────────────────────────────────────────────────────────────────────────
const String kAiGatewayBaseUrl = 'https://medcasespro.com';
// ↑ URL oficial de produção — domínio principal do Digital Ocean (sem barra no final).

// ─────────────────────────────────────────────────────────────────────────────
// AiGatewayService
// ─────────────────────────────────────────────────────────────────────────────
class AiGatewayService {
  AiGatewayService._(); // classe estática — sem instâncias

  // ── Configuração ───────────────────────────────────────────────────────────

  /// URL base do servidor AI Gateway.
  /// Build 155.2: inicializado com kAiGatewayBaseUrl — sempre configurado.
  /// Pode ser sobrescrito via [configure()] em runtime (ex: testes / staging).
  static String _baseUrl = kAiGatewayBaseUrl;

  /// Build 155.2: removido forceGateway — o gateway é SEMPRE o canal primário.
  /// Mantido como getter constante true para retrocompatibilidade de código
  /// que ainda referencia a propriedade (sem quebrar a compilação).
  static bool get forceGateway => true;
  // ignore: avoid_setters_without_getters
  static set forceGateway(bool _) {} // no-op — gateway sempre ativo

  /// Permite sobrescrever a URL em runtime (staging, testes).
  /// [baseUrl] deve incluir protocolo e host, sem barra no final.
  static void configure({required String baseUrl}) {
    _baseUrl = baseUrl.trimRight().replaceAll(RegExp(r'/$'), '');
    debugPrint('[AiGatewayService] URL sobrescrita → $_baseUrl');
  }

  /// Build 155.2: sempre true — URL hardcoded garante que o gateway
  /// nunca fique não-configurado.
  static bool get isConfigured => _baseUrl.isNotEmpty;

  // ── Endpoints de streaming SSE (Build 155 — dois motores independentes) ──

  /// Motor Plantão: flashcard ≤14 linhas, TRAVA DE FALLBACK.
  /// Usa EXCLUSIVAMENTE PROMPT_MODO_PLANTAO + MODE_ANCHOR_PLANTAO server-side.
  static String get _streamUrlPlantao => '$_baseUrl/api/ai/stream/plantao';

  /// Motor Estudos: revisão ≤24 linhas, ACRONYM RULE.
  /// Usa EXCLUSIVAMENTE PROMPT_MODO_ESTUDO + MODE_ANCHOR_ESTUDO server-side.
  static String get _streamUrlEstudo  => '$_baseUrl/api/ai/stream/estudo';

  /// Chave dinâmica de URL por modo — ponto central de chaveamento.
  /// [longResponse] false → /stream/plantao | true → /stream/estudo
  static String _streamUrlFor(bool longResponse) =>
      longResponse ? _streamUrlEstudo : _streamUrlPlantao;

  /// Endpoint síncrono (Context Classifier).
  static String get _syncUrl => '$_baseUrl/api/ai/sync';

  // ── Stream SSE principal ────────────────────────────────────────────────────

  /// Envia uma mensagem ao servidor e retorna um [Stream<GeminiChunk>].
  ///
  /// [userMessage]  — pergunta clínica do usuário
  /// [systemPrompt] — prompt de sistema montado pelo AiService
  /// [history]      — histórico de turnos [{role, content}]
  /// [useGrounding] — ativar Google Search no servidor (padrão: true)
  /// [longResponse] — chave de motor (Build 155):
  ///                    false (padrão) → bate em /api/ai/stream/plantao
  ///                    true           → bate em /api/ai/stream/estudo
  ///
  ///   IMPORTANTE: `longResponse` NÃO é mais enviado no payload JSON.
  ///   O motor é selecionado pela URL da rota — determinístico server-side.
  ///   O servidor nunca lê esse campo das rotas dedicadas (Build 155).
  static Stream<GeminiChunk> sendStream({
    required String userMessage,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
    bool useGrounding = true,
    bool longResponse = false,
  }) {
    if (!isConfigured) {
      return Stream.value(GeminiChunk.error('gateway_not_configured'));
    }

    final controller = StreamController<GeminiChunk>();
    _runSseStream(
      controller:   controller,
      userMessage:  userMessage,
      systemPrompt: systemPrompt,
      history:      history,
      useGrounding: useGrounding,
      longResponse: longResponse,  // usado apenas para escolher a URL da rota
    );
    return controller.stream;
  }

  // ── Pipeline interno — delega à implementação de plataforma (Build 146) ─────

  static Future<void> _runSseStream({
    required StreamController<GeminiChunk> controller,
    required String userMessage,
    required String systemPrompt,
    required List<Map<String, String>> history,
    required bool useGrounding,
    bool longResponse = false,
  }) async {
    if (controller.isClosed) return;

    // Build 155: URL chaveada pela rota — motor determinístico server-side
    final targetUrl = _streamUrlFor(longResponse);
    final motor     = longResponse ? 'ESTUDO' : 'PLANTÃO';
    final requestId = 'gw_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('[AiGatewayService][$requestId] motor=$motor → $targetUrl');

    // Build 155: `longResponse` NÃO enviado no payload.
    // O motor é determinado pela URL da rota — não pelo payload JSON.
    // Isso elimina o vetor de conflito onde o campo booleano poderia
    // divergir do comportamento esperado server-side.
    final payload = jsonEncode({
      'userMessage':  userMessage,
      'systemPrompt': systemPrompt,
      'history':      history,
      'useGrounding': useGrounding,
      // longResponse omitido intencionalmente — motor selecionado pela URL
    });

    // Delega à função runSseStreamPlatform() do arquivo de plataforma
    // selecionado em compile-time pela importação condicional:
    //   • Web → ai_gateway_service_web.dart (fetch nativo via dart:js_interop)
    //   • IO  → ai_gateway_service_io.dart  (http.Client streaming)
    await runSseStreamPlatform(
      controller: controller,
      streamUrl:  targetUrl,   // ← URL dinâmica por motor (Build 155)
      payload:    payload,
      requestId:  requestId,
    );
  }

  // ── Context Classifier síncrono (opcional) ─────────────────────────────────

  /// Chama o endpoint síncrono do servidor para classificar contexto.
  /// Retorna 'MÉDICO' ou 'NOVO', com fallback conservador 'MÉDICO'.
  ///
  /// [prompt] — prompt completo (system + pergunta do usuário)
  /// [maxTokens] — limite de tokens da resposta (padrão: 20)
  static Future<String> classifyContext(String prompt, {int maxTokens = 20}) async {
    if (!isConfigured) return 'MÉDICO';

    try {
      final response = await http.post(
        Uri.parse(_syncUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userMessage': prompt,
          'systemPrompt': 'Responda apenas MÉDICO ou NOVO.',
          'maxTokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return 'MÉDICO';

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = (data['text'] ?? '').toString().trim().toUpperCase();
      return text.contains('NOVO') ? 'NOVO' : 'MÉDICO';
    } catch (_) {
      return 'MÉDICO'; // fallback conservador
    }
  }

  // ── Health check ────────────────────────────────────────────────────────────

  /// Verifica se o servidor está online.
  /// Retorna true se o endpoint /health retornar status 200.
  static Future<bool> checkHealth() async {
    if (!isConfigured) return false;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
