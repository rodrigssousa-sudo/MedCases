// ══════════════════════════════════════════════════════════════════════════════
// ai_engine_service.dart — Gateway Facade (BUILD 458-AI-SERVER-DECOUPLING)
//
// RESPONSABILIDADE:
//   Único ponto de entrada para o motor de IA do MedCases Pro.
//   Isola a montagem de payload e o transporte HTTP da camada de UI (AiScreen /
//   home_screen / app_provider), preparando o código para a migração server-side
//   planejada na PART 2 (Firebase Cloud Functions).
//
// ARQUITETURA ATUAL (PART 1 — client-side):
//   AiEngineService.dispatch(AiEnginePayload)
//     → AiGatewayService.sendStream(...)        [shim → GeminiServiceV2]
//       → Google Gemini API (SSE)
//
// ARQUITETURA ALVO (PART 2 — server-side):
//   AiEngineService.dispatch(AiEnginePayload)
//     → FirebaseFunctions.instance.httpsCallable('atenderConsultaIA').call(...)
//       → Cloud Function Server (Gemini seguro, sem chave exposta no cliente)
//
// Para migrar para PART 2: altere apenas a flag [kUseCloudFunctions] para true
// e implemente [_dispatchViaCloudFunction]. Zero mudanças na UI ou no AppProvider.
//
// PAYLOAD LIMPO:
//   AiEnginePayload contém APENAS os dados semânticos da consulta:
//     • userMessage  — pergunta clínica digitada pelo médico
//     • uid          — UID do médico autenticado (para billing e audit server-side)
//     • isEs         — flag de idioma (true = Español, false = PT-BR)
//     • systemPrompt — prompt montado pelo AiService / PromptModules
//     • apiKey       — chave Gemini atual (ignorada quando kUseCloudFunctions=true)
//     • history      — turnos anteriores do chat [{role, content}]
//     • longResponse — false=Motor Plantão | true=Motor Estudos
//     • useGrounding — Google Search Grounding ativado
//
// NÃO FAZ:
//   • Montar prompts (→ AiService.buildClinicalSystemPrompt + PromptModules.build)
//   • Renderizar UI (→ ai_screen.dart)
//   • Gerenciar estado (→ app_provider.dart)
//   • Definir thresholds de RAG (→ ai_service.dart)
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'gemini_service_v2.dart';  // GeminiChunk
import 'ai_gateway_service.dart'; // AiGatewayService.sendStream

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE FLAG — Part 1 vs Part 2
// ─────────────────────────────────────────────────────────────────────────────
/// Quando false (Part 1): despacha via AiGatewayService → GeminiServiceV2 (client-side).
/// Quando true  (Part 2): despacha via FirebaseFunctions.httpsCallable (server-side).
/// Alterar apenas esta constante para migrar toda a árvore de chat sem tocar na UI.
const bool kUseCloudFunctions = false;

// ─────────────────────────────────────────────────────────────────────────────
// AiEnginePayload — dados limpos da consulta clínica
// ─────────────────────────────────────────────────────────────────────────────
/// Payload imutável entregue ao [AiEngineService.dispatch].
///
/// Contém SOMENTE os dados necessários para qualquer backend (local ou Cloud Function).
/// Não contém lógica de prompt, thresholds de RAG ou dependências de UI.
class AiEnginePayload {
  /// Pergunta clínica digitada pelo médico (texto limpo, sem prefixos de sistema).
  final String userMessage;

  /// UID do médico autenticado via Firebase Auth.
  /// Usado pelo servidor para billing, audit trail e personalização.
  final String uid;

  /// Idioma soberano do app: false = PT-BR | true = Español.
  /// Determina o idioma da resposta — independente do idioma da query.
  final bool isEs;

  /// System prompt completo montado pelo AiService + PromptModules.
  /// No Part 2, este campo pode ser omitido (montagem migra para o servidor).
  final String systemPrompt;

  /// Chave Gemini carregada do Firestore.
  /// Ignorada quando [kUseCloudFunctions] = true (autenticação via ID Token).
  final String apiKey;

  /// Histórico de turnos anteriores [{role: 'user'|'model', content: '...'}].
  final List<Map<String, String>> history;

  /// false = Motor Plantão (rápido, executivo) | true = Motor Estudos (denso).
  final bool longResponse;

  /// Ativa Google Search Grounding para respostas baseadas em evidências recentes.
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
  Map<String, dynamic> toCloudFunctionMap() => {
    'userMessage':  userMessage,
    'uid':          uid,
    'isEs':         isEs,
    'systemPrompt': systemPrompt,
    'history':      history,
    'longResponse': longResponse,
    'useGrounding': useGrounding,
    // apiKey NÃO incluído: server-side usa chave segura própria
  };

  @override
  String toString() =>
      'AiEnginePayload(uid=${uid.substring(0, uid.length.clamp(0, 8))}... '
      'isEs=$isEs longResponse=$longResponse '
      'historyLen=${history.length} msgLen=${userMessage.length})';
}

// ─────────────────────────────────────────────────────────────────────────────
// AiEngineService — único ponto de despacho
// ─────────────────────────────────────────────────────────────────────────────
class AiEngineService {
  AiEngineService._(); // utilitário 100% estático

  /// Despacha uma consulta clínica e retorna um Stream de [GeminiChunk].
  ///
  /// Em PART 1 ([kUseCloudFunctions] = false): delega para [AiGatewayService.sendStream].
  /// Em PART 2 ([kUseCloudFunctions] = true):  delega para [_dispatchViaCloudFunction].
  ///
  /// Os callers (app_provider, ai_screen, home_screen) não precisam saber qual
  /// caminho está ativo — apenas consomem o Stream<GeminiChunk> resultante.
  static Stream<GeminiChunk> dispatch(AiEnginePayload payload) {
    if (kDebugMode) {
      debugPrint('[AiEngineService] dispatch → '
          '${kUseCloudFunctions ? "CloudFunction" : "GeminiDirect"} | $payload');
    }

    return kUseCloudFunctions
        ? _dispatchViaCloudFunction(payload)
        : _dispatchViaGeminiDirect(payload);
  }

  // ── PART 1: Despacho direto via GeminiServiceV2 (client-side) ─────────────
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

  // ── PART 2: Despacho via Firebase Cloud Function (server-side) ─────────────
  // TODO (Part 2): descomentar e importar 'package:cloud_functions/cloud_functions.dart'
  //
  // static Stream<GeminiChunk> _dispatchViaCloudFunction(AiEnginePayload payload) async* {
  //   try {
  //     final callable = FirebaseFunctions.instance.httpsCallable(
  //       'atenderConsultaIA',
  //       options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
  //     );
  //     final result = await callable.call(payload.toCloudFunctionMap());
  //     final text = result.data['text'] as String? ?? '';
  //     if (text.isNotEmpty) {
  //       yield GeminiChunk(text: text, isDone: false);
  //     }
  //     yield GeminiChunk.done;
  //   } on FirebaseFunctionsException catch (e) {
  //     debugPrint('[AiEngineService] CloudFunction error: ${e.code} ${e.message}');
  //     yield GeminiChunk.error(e.code);
  //   } catch (e) {
  //     debugPrint('[AiEngineService] CloudFunction unknown error: $e');
  //     yield GeminiChunk.error('unknown');
  //   }
  // }
  //
  // Stub para Part 1 — nunca chamado enquanto kUseCloudFunctions = false.
  static Stream<GeminiChunk> _dispatchViaCloudFunction(AiEnginePayload payload) async* {
    debugPrint('[AiEngineService] _dispatchViaCloudFunction chamado com '
        'kUseCloudFunctions=true — implemente a integração Firebase Functions na PART 2.');
    yield GeminiChunk.error('cloud_functions_not_implemented');
  }

  // ── Helpers de conveniência ────────────────────────────────────────────────

  /// Constrói um [AiEnginePayload] a partir dos parâmetros usados no app_provider.
  /// Facilita a migração: callers atuais passam os mesmos argumentos, apenas
  /// encapsulados no payload imutável.
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
