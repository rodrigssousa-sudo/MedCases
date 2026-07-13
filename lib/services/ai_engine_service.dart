// ══════════════════════════════════════════════════════════════════════════════
// ai_engine_service.dart — Gateway Facade (BUILD 459-AI-SERVER-DECOUPLING Part 2)
//
// RESPONSABILIDADE:
//   Único ponto de entrada para o motor de IA do MedCases Pro.
//   Isola a montagem de payload e o transporte da camada de UI (AiScreen /
//   home_screen / app_provider), permitindo troca de backend sem tocar na UI.
//
// ARQUITETURA PART 1 (client-side, kUseCloudFunctions=false):
//   AiEngineService.dispatch(AiEnginePayload)
//     → AiGatewayService.sendStream(...)        [shim → GeminiServiceV2]
//       → Google Gemini API (SSE, chave no cliente)
//
// ARQUITETURA PART 2 (server-side, kUseCloudFunctions=true):
//   AiEngineService.dispatch(AiEnginePayload)
//     → FirebaseFunctions.instance.httpsCallable('atenderConsultaIA').call(...)
//       → Cloud Function (Node.js 22, us-central1)
//         → Google Gemini API (chave segura no servidor — NUNCA exposta)
//     ← texto completo retornado em JSON único { text, model, durationMs }
//     ← Flutter simula streaming word-by-word via Stream<GeminiChunk>
//
// STREAMING SIMULADO (Part 2):
//   onCall v2 não suporta SSE nativo — retorna JSON único.
//   _dispatchViaCloudFunction() fragmenta o texto em chunks de ~25 chars e
//   os emite com delay de 18ms, preservando o efeito de digitação nas UIs
//   (AiScreen, HomeScreen) e mantendo a SelectionArea 100% funcional.
//
// MIGRAÇÃO COMPLETA:
//   Alterar apenas [kUseCloudFunctions] de false → true após deploy da CF.
//   Zero mudanças em ai_screen.dart, home_screen.dart ou app_provider.dart.
//
// PAYLOAD LIMPO:
//   AiEnginePayload contém APENAS dados semânticos da consulta:
//     • userMessage  — pergunta clínica digitada pelo médico
//     • uid          — UID autenticado (audit e validação server-side)
//     • isEs         — idioma soberano (true=Español, false=PT-BR)
//     • systemPrompt — prompt montado por AiService + PromptModules
//     • apiKey       — chave Gemini (ignorada quando kUseCloudFunctions=true)
//     • history      — turnos anteriores do chat [{role, content}]
//     • longResponse — false=Motor Plantão | true=Motor Estudos
//     • useGrounding — Google Search Grounding (client-side only na Part 1)
//
// NÃO FAZ:
//   • Montar prompts (→ AiService.buildClinicalSystemPrompt + PromptModules.build)
//   • Renderizar UI (→ ai_screen.dart)
//   • Gerenciar estado (→ app_provider.dart)
//   • Definir thresholds de RAG (→ ai_service.dart)
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:cloud_functions/cloud_functions.dart';
import 'gemini_service_v2.dart';  // GeminiChunk
import 'ai_gateway_service.dart'; // AiGatewayService.sendStream

// BUILD 462B: Re-export do contrato Anti-Frankenstein unificado.
// Importar ai_engine_service.dart já expõe todos os tipos do barramento.
export 'ai_stream/ai_event.dart';

// ══════════════════════════════════════════════════════════════════════════════
// BUILD 462-STREAMING-CORE — AiEvent: Contrato de Eventos Tipados
//
// Hierarquia de eventos imutáveis que trafegam no barramento Stream<AiEvent>.
// Substitui o uso de strings brutas ou snapshots acumulados entre camadas.
//
// Ciclo de vida de um request bem-sucedido:
//   AiStarted → AiTextDelta (N vezes) → AiSources? → AiCompleted
//
// Ciclo de vida de um request com erro:
//   AiStarted? → AiError
//
// Uso:
//   stream.listen((event) => switch (event) {
//     AiStarted  e => ...,
//     AiTextDelta e => ...,
//     AiToolResult e => ...,
//     AiSources   e => ...,
//     AiCompleted e => ...,
//     AiError     e => ...,
//   });
// ══════════════════════════════════════════════════════════════════════════════

/// Evento base imutável do barramento de IA.
/// Todas as subclasses são `final` — nunca mutadas após criação.
sealed class AiEvent {
  const AiEvent();
}

// ─────────────────────────────────────────────────────────────────────────────
/// Emitido IMEDIATAMENTE quando a conexão com o backend é estabelecida.
/// Carrega metadados reais do servidor — requestId, modelo ativo e provedor.
///
/// A UI usa este evento para:
///   • Exibir skeleton screens durante o round-trip inicial (antes do 1º delta)
///   • Registrar qual modelo/provedor respondeu (telemetria, debug)
// ─────────────────────────────────────────────────────────────────────────────
final class AiStarted extends AiEvent {
  /// ID único do request gerado pelo ProviderRouterService.
  final String requestId;

  /// Identificador do modelo em uso (ex: 'gemini-2.5-flash', 'gpt-4o-mini').
  /// Preenchido com 'gemini-direct' na Part 1 (client-side SSE).
  final String model;

  /// Provedor ativo: 'gemini_free' | 'gemini_paid' | 'gpt_4o_mini' | 'cloud_function'.
  final String provider;

  /// Timestamp Unix (ms) de quando o evento foi criado — para métricas de TTFT.
  final int startedAtMs;

  const AiStarted({
    required this.requestId,
    required this.model,
    required this.provider,
    int? startedAtMs,
  }) : startedAtMs = startedAtMs ?? 0;
}

// ─────────────────────────────────────────────────────────────────────────────
/// Fragmento bruto de texto chegando do modelo — o "delta" do SSE.
///
/// NUNCA contém o texto acumulado — apenas o fragmento novo desde o delta
/// anterior. O acumulador é responsabilidade exclusiva do listener (UI/provider).
///
/// A UI usa este evento para:
///   • Empurrar o delta para o networkBuffer (StringBuffer local, zero setState)
///   • O Timer.periodic(40ms) extrai do buffer e atualiza o visibleTextNotifier
// ─────────────────────────────────────────────────────────────────────────────
final class AiTextDelta extends AiEvent {
  /// Fragmento bruto de texto — pode ser de 1 char a ~60 chars por SSE chunk.
  final String delta;

  /// Número de sequência monotonicamente crescente (0-based).
  /// Permite ao listener detectar gaps ou re-ordenação (não esperados mas possíveis).
  final int sequence;

  const AiTextDelta({
    required this.delta,
    required this.sequence,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
/// Resultado de uma ferramenta ou chamada de função (Google Search, RAG, etc.).
///
/// Preparado para extensões futuras (tool_use, function_calling).
/// Atualmente não emitido no fluxo SSE do Gemini (filtrado por _extractText),
/// mas a estrutura garante que o barramento suporta o contrato futuro sem
/// quebrar os listeners existentes.
// ─────────────────────────────────────────────────────────────────────────────
final class AiToolResult extends AiEvent {
  /// Nome da ferramenta invocada (ex: 'google_search', 'rag_lookup').
  final String toolName;

  /// Dados retornados pela ferramenta em formato livre.
  final Map<String, dynamic> data;

  const AiToolResult({
    required this.toolName,
    required this.data,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
/// Metadados bibliográficos das fontes usadas na resposta.
/// Emitido ANTES de AiCompleted quando o grounding (Google Search) está ativo.
///
/// A UI usa este evento para:
///   • Renderizar a seção "Fontes" / "Fuentes" abaixo da resposta
// ─────────────────────────────────────────────────────────────────────────────
final class AiSources extends AiEvent {
  /// Lista de fontes bibliográficas estruturadas.
  /// Cada item: {'title': String, 'url': String, 'snippet': String?}
  final List<Map<String, String>> sources;

  const AiSources({required this.sources});
}

// ─────────────────────────────────────────────────────────────────────────────
/// Evento final de conclusão — sinaliza que o stream terminou com sucesso.
/// Carrega o payload estruturado de fechamento para telemetria e persistência.
///
/// A UI usa este evento para:
///   • Disparar a substituição única SelectableText → MarkdownBody
///   • Persistir o turno no _aiHistory e no Firestore
///   • Desativar o skeleton/cursor e liberar o campo de texto
// ─────────────────────────────────────────────────────────────────────────────
final class AiCompleted extends AiEvent {
  /// Texto final completo e definitivo (acumulação de todos os AiTextDelta.delta).
  /// É o source-of-truth para persistência em _aiHistory e Firestore.
  final String fullText;

  /// Número total de tokens de entrada estimados (para telemetria/billing).
  final int inputTokensApprox;

  /// Número total de tokens de saída estimados.
  final int outputTokensApprox;

  /// Duração total do request em milissegundos (do AiStarted ao AiCompleted).
  final int durationMs;

  /// Provedor que efetivamente respondeu (pode diferir do AiStarted.provider
  /// se houve fallback durante o stream).
  final String usedProvider;

  const AiCompleted({
    required this.fullText,
    this.inputTokensApprox = 0,
    this.outputTokensApprox = 0,
    this.durationMs = 0,
    this.usedProvider = '',
  });
}

// ─────────────────────────────────────────────────────────────────────────────
/// Evento de erro — encerra o stream com falha identificada.
/// Nunca emitido simultaneamente com AiCompleted no mesmo request.
///
/// A UI usa este evento para:
///   • Exibir o card nativo de erro com botão de retry
///   • Escalar para o próximo provedor da cadeia de fallback (layers 2 e 3)
// ─────────────────────────────────────────────────────────────────────────────
final class AiError extends AiEvent {
  /// Código canônico do erro — compatível com os errorCode do GeminiChunk:
  ///   'quota', 'timeout', 'network', 'http_503', 'api_key_invalid',
  ///   'cf_unauthenticated', 'cf_timeout', 'cf_internal', etc.
  final String errorCode;

  /// Mensagem humano-legível (opcional — para debug/logs).
  final String? message;

  const AiError({
    required this.errorCode,
    this.message,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de conversão: GeminiChunk → AiEvent
//
// Permitem a migração incremental: o transporte legado (GeminiChunk) continua
// funcionando enquanto o barramento de eventos tipados é adotado gradualmente.
// ─────────────────────────────────────────────────────────────────────────────

/// Converte um [Stream<GeminiChunk>] para [Stream<AiEvent>].
///
/// Mapeamento:
///   GeminiChunk.isError → AiError(errorCode)
///   GeminiChunk.isDone  → AiCompleted(fullText: accumulated)
///   chunk.text.isNotEmpty → AiTextDelta(delta, sequence)
///
/// NOTA: O acumulador é gerenciado internamente para produzir o fullText do
/// AiCompleted. Listeners de AiTextDelta devem acumular localmente.
Stream<AiEvent> geminiChunkStreamToAiEvents(
  Stream<GeminiChunk> chunkStream, {
  String requestId = '',
  String model = 'gemini-direct',
  String provider = 'gemini_free',
}) async* {
  final startMs = DateTime.now().millisecondsSinceEpoch;

  yield AiStarted(
    requestId:   requestId,
    model:       model,
    provider:    provider,
    startedAtMs: startMs,
  );

  int sequence = 0;
  final accumulator = StringBuffer();

  await for (final chunk in chunkStream) {
    if (chunk.isError) {
      yield AiError(
        errorCode: chunk.errorCode ?? 'unknown',
        message:   'GeminiChunk error: ${chunk.errorCode}',
      );
      return;
    }

    if (chunk.text.isNotEmpty) {
      accumulator.write(chunk.text);
      yield AiTextDelta(delta: chunk.text, sequence: sequence++);
    }

    if (chunk.isDone) {
      yield AiCompleted(
        fullText:     accumulator.toString(),
        durationMs:   DateTime.now().millisecondsSinceEpoch - startMs,
        usedProvider: provider,
      );
      return;
    }
  }

  // Stream fechou sem AiCompleted — emite conclusão com o texto acumulado
  if (accumulator.isNotEmpty) {
    yield AiCompleted(
      fullText:     accumulator.toString(),
      durationMs:   DateTime.now().millisecondsSinceEpoch - startMs,
      usedProvider: provider,
    );
  }
}

/// Converte um [PaidProxyResult] (Future) em [Stream<AiEvent>] com deltas
/// simulados — compatível com o barramento tipado.
///
/// Usado pelos fallbacks Layer 2 (GPT) e Layer 3 (Paid Proxy) para que a UI
/// receba a mesma sequência AiStarted→AiTextDelta→AiCompleted independente
/// de qual provedor respondeu.
Stream<AiEvent> paidProxyResultToAiEvents(
  Future<dynamic> proxyFuture, {
  required String requestId,
  required String provider,
  int chunkSize = 30,
  Duration chunkDelay = const Duration(milliseconds: 18),
}) async* {
  final startMs = DateTime.now().millisecondsSinceEpoch;

  yield AiStarted(
    requestId:   requestId,
    model:       provider,
    provider:    provider,
    startedAtMs: startMs,
  );

  dynamic result;
  try {
    result = await proxyFuture;
  } catch (e) {
    yield AiError(errorCode: 'proxy_exception', message: e.toString());
    return;
  }

  // Extrai text e errorCode via duck-typing (compatível com PaidProxyResult)
  final text      = (result?.text as String?) ?? '';
  final success   = (result?.success as bool?) ?? false;
  final errorCode = (result?.errorCode as String?) ?? 'unknown';

  if (!success || text.isEmpty) {
    yield AiError(errorCode: errorCode.isNotEmpty ? errorCode : 'empty_response');
    return;
  }

  // Streaming simulado: fragmenta em chunks para efeito de digitação
  int offset   = 0;
  int sequence = 0;
  while (offset < text.length) {
    final end   = (offset + chunkSize).clamp(0, text.length);
    final delta = text.substring(offset, end);
    yield AiTextDelta(delta: delta, sequence: sequence++);
    offset = end;
    if (offset < text.length) await Future<void>.delayed(chunkDelay);
  }

  yield AiCompleted(
    fullText:     text,
    durationMs:   DateTime.now().millisecondsSinceEpoch - startMs,
    usedProvider: provider,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE FLAG — Part 1 (client-side) vs Part 2 (server-side)
// ─────────────────────────────────────────────────────────────────────────────
/// Quando false (Part 1 — atual):
///   Despacha via [AiGatewayService.sendStream] → GeminiServiceV2 → Gemini API.
///   A chave Gemini reside no cliente (comportamento anterior).
///
/// Quando true (Part 2 — ativar após deploy da CF):
///   Despacha via [FirebaseFunctions.httpsCallable('atenderConsultaIA')].
///   A chave Gemini reside EXCLUSIVAMENTE no servidor Firebase Secret.
///   Streaming simulado word-by-word preserva o efeito visual de digitação.
///
/// Para migrar: altere APENAS esta constante. Zero impacto na UI.
const bool kUseCloudFunctions = false;

// ─────────────────────────────────────────────────────────────────────────────
// Configuração de streaming simulado (Part 2)
// ─────────────────────────────────────────────────────────────────────────────
/// Tamanho de cada chunk de texto emitido no streaming simulado (Part 2).
/// Valor de ~25 chars equivale a ~4-5 palavras por chunk — efeito de digitação
/// fluido sem overhead de micro-yields.
const int _kChunkSize = 25;

/// Delay entre chunks no streaming simulado (Part 2).
/// 18ms → ~55 chunks/s → textos de 900 chars entregues em ~650ms de animação.
const Duration _kChunkDelay = Duration(milliseconds: 18);

// ─────────────────────────────────────────────────────────────────────────────
// AiEnginePayload — dados limpos da consulta clínica
// ─────────────────────────────────────────────────────────────────────────────
/// Payload imutável entregue ao [AiEngineService.dispatch].
///
/// Contém SOMENTE os dados necessários para qualquer backend (local ou CF).
/// Não contém lógica de prompt, thresholds de RAG ou dependências de UI.
class AiEnginePayload {
  /// Pergunta clínica digitada pelo médico (texto limpo, sem prefixos de sistema).
  final String userMessage;

  /// UID do médico autenticado via Firebase Auth.
  /// Usado pelo servidor para validação, audit trail e billing.
  final String uid;

  /// Idioma soberano do app: false = PT-BR | true = Español.
  /// Determina o idioma da resposta — independente do idioma da query.
  final bool isEs;

  /// System prompt completo montado pelo AiService + PromptModules.
  /// No futuro, pode ser omitido (montagem migra para o servidor).
  final String systemPrompt;

  /// Chave Gemini carregada do Firestore.
  /// Ignorada quando [kUseCloudFunctions] = true (CF usa secret próprio).
  final String apiKey;

  /// Histórico de turnos anteriores [{role: 'user'|'model', content: '...'}].
  final List<Map<String, String>> history;

  /// false = Motor Plantão (rápido, executivo) | true = Motor Estudos (denso).
  final bool longResponse;

  /// Ativa Google Search Grounding para respostas baseadas em evidências recentes.
  /// Aplicado apenas na Part 1 (client-side). Part 2: não implementado na CF v1.
  final bool useGrounding;

  const AiEnginePayload({
    required this.userMessage,
    required this.uid,
    required this.isEs,
    required this.systemPrompt,
    required this.apiKey,
    this.history      = const [],
    this.longResponse = false,
    this.useGrounding = true,
  });

  /// Converte para Map para envio à Cloud Function (Part 2).
  /// Exclui [apiKey] — servidor usa chave segura própria via Firebase Secret.
  Map<String, dynamic> toCloudFunctionMap() => {
    'userMessage':  userMessage,
    'uid':          uid,
    'isEs':         isEs,
    'systemPrompt': systemPrompt,
    'history':      history,
    'longResponse': longResponse,
    'useGrounding': useGrounding,
    // apiKey NÃO incluído: CF usa GEMINI_AI_KEY do Firebase Secret
  };

  @override
  String toString() =>
      'AiEnginePayload('
      'uid=${uid.length > 8 ? uid.substring(0, 8) : uid}... '
      'isEs=$isEs longResponse=$longResponse '
      'historyLen=${history.length} msgLen=${userMessage.length})';
}

// ─────────────────────────────────────────────────────────────────────────────
// AiEngineService — único ponto de despacho
// ─────────────────────────────────────────────────────────────────────────────
class AiEngineService {
  AiEngineService._(); // utilitário 100% estático

  // ── Instância Firebase Functions (Part 2) ──────────────────────────────────
  // Inicializada lazily — sem custo se kUseCloudFunctions=false.
  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  // ── Nome da Cloud Function alvo ────────────────────────────────────────────
  static const String _kFunctionName = 'atenderConsultaIA';

  // ── Timeout da chamada CF (client-side) ───────────────────────────────────
  // Deve ser > timeout server-side (90s) para cobrir latência de rede.
  static const Duration _kCallTimeout = Duration(seconds: 100);

  // ─────────────────────────────────────────────────────────────────────────
  // dispatch() — roteador central
  // ─────────────────────────────────────────────────────────────────────────
  /// Despacha uma consulta clínica e retorna um [Stream<GeminiChunk>].
  ///
  /// Em PART 1 ([kUseCloudFunctions]=false): → [AiGatewayService.sendStream] (SSE real).
  /// Em PART 2 ([kUseCloudFunctions]=true):  → [_dispatchViaCloudFunction] (streaming simulado).
  ///
  /// Callers (app_provider, ai_screen, home_screen) consomem apenas o Stream —
  /// o backend ativo é invisível para a UI. SelectionArea permanece funcional em ambas.
  static Stream<GeminiChunk> dispatch(AiEnginePayload payload) {
    if (kDebugMode) {
      debugPrint('[AiEngineService] dispatch → '
          '${kUseCloudFunctions ? "☁️ CloudFunction(${"_kFunctionName"})" : "⚡ GeminiDirect"} '
          '| $payload');
    }

    return kUseCloudFunctions
        ? _dispatchViaCloudFunction(payload)
        : _dispatchViaGeminiDirect(payload);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PART 1 — Despacho direto via GeminiServiceV2 (client-side, SSE real)
  // ─────────────────────────────────────────────────────────────────────────
  static Stream<GeminiChunk> _dispatchViaGeminiDirect(AiEnginePayload payload) {
    return AiGatewayService.sendStream(
      userMessage:  payload.userMessage,
      systemPrompt: payload.systemPrompt,
      apiKey:       payload.apiKey,
      history:      payload.history,
      useGrounding: payload.useGrounding,
      longResponse: payload.longResponse,
      appLanguage:  payload.isEs ? 'es' : 'pt',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PART 2 — Despacho via Firebase Cloud Function (server-side)
  // ─────────────────────────────────────────────────────────────────────────
  /// Chama [atenderConsultaIA] via onCall v2 e simula streaming word-by-word.
  ///
  /// ARQUITETURA DE STREAMING SIMULADO:
  ///   onCall v2 retorna JSON único (não SSE). Para preservar o efeito visual
  ///   de digitação nas UIs (AiScreen + HomeScreen + SelectionArea), o texto
  ///   completo é fragmentado em chunks de [_kChunkSize] chars, emitidos com
  ///   delay de [_kChunkDelay] entre cada um. O comportamento da UI é idêntico
  ///   ao streaming real da Part 1 — apenas a latência inicial muda (espera CF
  ///   em vez de primeiro token SSE).
  ///
  /// TRATAMENTO DE ERROS (FirebaseFunctionsException.code → errorCode):
  ///   unauthenticated   → 'cf_unauthenticated'
  ///   permission-denied → 'cf_permission_denied'
  ///   invalid-argument  → 'cf_invalid_argument'
  ///   deadline-exceeded → 'cf_timeout'
  ///   unavailable       → 'cf_unavailable'
  ///   internal / *      → 'cf_internal'
  ///
  /// SelectionArea: permanece 100% funcional — o texto acumulado via chunks
  /// simulados é selecionável da mesma forma que o streaming SSE real.
  static Stream<GeminiChunk> _dispatchViaCloudFunction(
      AiEnginePayload payload) async* {
    if (kDebugMode) {
      debugPrint('[AiEngineService] ☁️ _dispatchViaCloudFunction → '
          '$_kFunctionName | uid=${payload.uid.length > 8 ? payload.uid.substring(0, 8) : payload.uid}...');
    }

    // ── 1. Chamada à Cloud Function ──────────────────────────────────────
    HttpsCallableResult<dynamic> result;
    try {
      final callable = _functions.httpsCallable(
        _kFunctionName,
        options: HttpsCallableOptions(
          timeout: _kCallTimeout,
          // limitedUseAppCheckToken: false — App Check não obrigatório nesta CF
        ),
      );

      result = await callable.call(payload.toCloudFunctionMap());

    } on FirebaseFunctionsException catch (e) {
      // Erros semânticos da CF (unauthenticated, permission-denied, etc.)
      final errorCode = _mapCfErrorCode(e.code);
      if (kDebugMode) {
        debugPrint('[AiEngineService] ☁️ FirebaseFunctionsException '
            'code=${e.code} message=${e.message} → chunk error=$errorCode');
      }
      yield GeminiChunk.error(errorCode);
      return;

    } catch (e) {
      // Erros de rede, timeout do SDK, ou erros inesperados
      if (kDebugMode) {
        debugPrint('[AiEngineService] ☁️ Erro inesperado na CF: $e');
      }
      yield GeminiChunk.error('cf_network_error');
      return;
    }

    // ── 2. Extrai texto da resposta ───────────────────────────────────────
    final data = result.data;
    final text = (data is Map && data['text'] is String)
        ? (data['text'] as String)
        : '';

    if (kDebugMode) {
      final model      = (data is Map ? data['model']      : null) ?? '?';
      final durationMs = (data is Map ? data['durationMs'] : null) ?? '?';
      debugPrint('[AiEngineService] ☁️ CF respondeu: '
          'model=$model durationMs=${durationMs}ms textLen=${text.length}');
    }

    if (text.isEmpty) {
      if (kDebugMode) {
        debugPrint('[AiEngineService] ☁️ CF retornou texto vazio — emitindo erro.');
      }
      yield GeminiChunk.error('cf_empty_response');
      return;
    }

    // ── 3. Streaming simulado word-by-word ────────────────────────────────
    // Fragmenta o texto completo em chunks de _kChunkSize chars e os emite
    // com delay de _kChunkDelay, simulando o efeito SSE da Part 1.
    // A UI (AiScreen + HomeScreen) acumula os chunks identicamente ao SSE real.
    int offset = 0;
    while (offset < text.length) {
      final end   = (offset + _kChunkSize).clamp(0, text.length);
      final chunk = text.substring(offset, end);
      yield GeminiChunk(text: chunk, isDone: false);
      offset = end;
      if (offset < text.length) {
        await Future<void>.delayed(_kChunkDelay);
      }
    }

    // ── 4. Chunk final — sinaliza conclusão ───────────────────────────────
    yield GeminiChunk.done;

    if (kDebugMode) {
      debugPrint('[AiEngineService] ☁️ Streaming simulado concluído: '
          '${text.length} chars emitidos em ${(text.length / _kChunkSize).ceil()} chunks.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // _mapCfErrorCode — traduz FirebaseFunctionsException.code → errorCode Dart
  // ─────────────────────────────────────────────────────────────────────────
  /// Mapeia o código semântico da CF (string do Firebase) para o errorCode
  /// do [GeminiChunk.error], usado pelas UIs para exibir mensagens amigáveis.
  static String _mapCfErrorCode(String code) {
    switch (code) {
      case 'unauthenticated':
        return 'cf_unauthenticated';
      case 'permission-denied':
        return 'cf_permission_denied';
      case 'invalid-argument':
        return 'cf_invalid_argument';
      case 'deadline-exceeded':
        return 'cf_timeout';
      case 'unavailable':
        return 'cf_unavailable';
      case 'not-found':
        return 'cf_not_found';
      case 'resource-exhausted':
        return 'cf_quota';
      default:
        return 'cf_internal';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers de conveniência
  // ─────────────────────────────────────────────────────────────────────────

  /// Constrói um [AiEnginePayload] a partir dos parâmetros individuais.
  /// Facilita a migração: callers existentes passam os mesmos argumentos,
  /// apenas encapsulados no payload imutável.
  static AiEnginePayload buildPayload({
    required String userMessage,
    required String uid,
    required bool isEs,
    required String systemPrompt,
    required String apiKey,
    List<Map<String, String>> history = const [],
    bool longResponse = false,
    bool useGrounding = true,
  }) {
    return AiEnginePayload(
      userMessage:  userMessage,
      uid:          uid,
      isEs:         isEs,
      systemPrompt: systemPrompt,
      apiKey:       apiKey,
      history:      history,
      longResponse: longResponse,
      useGrounding: useGrounding,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // dispatchAsEvents() — barramento de eventos tipados (BUILD 462)
  // ─────────────────────────────────────────────────────────────────────────
  /// Despacha um payload e retorna um [Stream<AiEvent>] tipado.
  ///
  /// Emite a sequência:
  ///   [AiStarted] → [AiTextDelta]* → [AiSources]? → [AiCompleted]
  /// ou em caso de falha:
  ///   [AiStarted] → [AiError]
  ///
  /// Internamente converte o [Stream<GeminiChunk>] legado para o barramento
  /// tipado via [geminiChunkStreamToAiEvents] — zero duplicação de lógica de
  /// transporte. Permite migração incremental: callers novos usam AiEvent,
  /// callers legados continuam com [dispatch] + GeminiChunk.
  static Stream<AiEvent> dispatchAsEvents(
    AiEnginePayload payload, {
    String requestId = '',
  }) {
    final chunkStream = dispatch(payload);
    return geminiChunkStreamToAiEvents(
      chunkStream,
      requestId: requestId.isNotEmpty
          ? requestId
          : 'req_${DateTime.now().millisecondsSinceEpoch}',
      model:    kUseCloudFunctions ? 'cloud_function' : 'gemini-direct',
      provider: kUseCloudFunctions ? 'cloud_function' : 'gemini_free',
    );
  }

  /// Atalho: dispatch a partir de parâmetros individuais sem instanciar o payload.
  /// Equivalente a [buildPayload] + [dispatch] em uma única chamada.
  static Stream<GeminiChunk> send({
    required String userMessage,
    required String uid,
    required bool isEs,
    required String systemPrompt,
    required String apiKey,
    List<Map<String, String>> history = const [],
    bool longResponse = false,
    bool useGrounding = true,
  }) {
    return dispatch(buildPayload(
      userMessage:  userMessage,
      uid:          uid,
      isEs:         isEs,
      systemPrompt: systemPrompt,
      apiKey:       apiKey,
      history:      history,
      longResponse: longResponse,
      useGrounding: useGrounding,
    ));
  }
}
