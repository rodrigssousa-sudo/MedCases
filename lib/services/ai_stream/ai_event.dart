import '../../models/clinical_structured_output.dart';

// ══════════════════════════════════════════════════════════════════════════════
// lib/services/ai_stream/ai_event.dart
// BUILD 462B-REDIRECIONADA — Anti-Frankenstein Typed Event Contract
//
// CONTRATO ANTI-FRANKENSTEIN:
//   • Arquivo-fonte único para todos os eventos do barramento de IA
//   • Cada evento carrega: requestId, attempt, timestamp (ISO-8601)
//   • AiTextDelta carrega: delta bruto + sequence (1-based para GPT attempt=2)
//   • Identidade de um fragmento: requestId + attempt + sequence
//   • Proibido concatenar texto de attempt=1 (Gemini) com attempt=2 (GPT)
//
// CICLO DE VIDA — request bem-sucedido:
//   AiStarted → AiTextDelta* → AiSources? → AiCompleted
//
// CICLO DE VIDA — fallback GPT:
//   AiProviderSwitched → [AiStreamReset?] → AiStarted(attempt=2)
//   → AiTextDelta(sequence=1..N, attempt=2) → AiCompleted(attempt=2)
//
// CICLO DE VIDA — falha:
//   AiStarted? → AiFailed
//
// REGRA DE DESCARTE DE FRAGMENTOS (parser/listener):
//   • requestId diferente do atual → descartar
//   • attempt anterior ao corrente → descartar
//   • sequence duplicada ou inferior à última aceita → descartar
//   • JSON inválido num evento SSE completo → AiFailed (não continuar silenciosamente)
// ══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
/// Evento base imutável do barramento de IA MedCases.
///
/// Todos os eventos carregam:
///   • [requestId] — ID único do request, gerado pelo ProviderRouterService
///   • [attempt]   — 1 = Gemini Free, 2 = GPT fallback, 3 = Gemini Paid
///   • [timestamp] — ISO-8601 UTC do momento de criação do evento
///
/// Subclasses são todas `final` — nunca mutadas após criação.
/// ──────────────────────────────────────────────────────────────────────────
sealed class AiEvent {
  /// ID único do request (ex: 'req_1720123456789').
  final String requestId;

  /// Número de tentativa:
  ///   1 = Gemini Free (primário)
  ///   2 = GPT-4o Mini (fallback Layer 2)
  ///   3 = Gemini Paid (fallback Layer 3)
  final int attempt;

  /// Timestamp ISO-8601 UTC do momento de criação.
  final String timestamp;

  const AiEvent({
    required this.requestId,
    required this.attempt,
    required this.timestamp,
  });

  /// Factory helper para timestamp atual em ISO-8601.
  static String nowIso() => DateTime.now().toUtc().toIso8601String();
}

// ─────────────────────────────────────────────────────────────────────────────
/// Emitido IMEDIATAMENTE quando a conexão com o backend é estabelecida.
/// Carrega metadados do servidor: requestId, modelo, provedor, attempt.
///
/// A UI usa este evento para:
///   • Iniciar o skeleton screen (pulsing bars)
///   • Registrar qual provedor respondeu (telemetria / debug)
///   • Saber o attempt atual para aceitar apenas deltas compatíveis
// ─────────────────────────────────────────────────────────────────────────────
final class AiStarted extends AiEvent {
  /// Identificador do modelo em uso (ex: 'gemini-2.5-flash', 'gpt-4o-mini').
  final String model;

  /// Provedor ativo: 'gemini_free' | 'gpt_4o_mini' | 'gemini_paid'.
  final String provider;

  /// Timestamp Unix (ms) — para métricas de TTFT (Time-To-First-Token).
  final int startedAtMs;

  const AiStarted({
    required super.requestId,
    required super.attempt,
    required super.timestamp,
    required this.model,
    required this.provider,
    int? startedAtMs,
  }) : startedAtMs = startedAtMs ?? 0;

  factory AiStarted.now({
    required String requestId,
    required int attempt,
    required String model,
    required String provider,
  }) =>
      AiStarted(
        requestId: requestId,
        attempt: attempt,
        timestamp: AiEvent.nowIso(),
        model: model,
        provider: provider,
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
/// Fragmento bruto de texto chegando do modelo — o "delta" do SSE.
///
/// NUNCA contém o texto acumulado — apenas o fragmento novo.
/// O acumulador é responsabilidade exclusiva do listener.
///
/// Identidade de um fragmento: requestId + attempt + sequence
///   Para GPT fallback: attempt=2, sequence começa em 1.
///
/// A UI usa este evento para:
///   • Empurrar [delta] para o networkBuffer (StringBuffer, zero setState)
///   • O Timer.periodic(40ms) drena o buffer e atualiza o visibleText
// ─────────────────────────────────────────────────────────────────────────────
final class AiTextDelta extends AiEvent {
  /// Fragmento bruto de texto. Pode ter de 1 char a ~100 chars.
  final String delta;

  /// Número de sequência monotonicamente crescente.
  ///   Gemini attempt=1: começa em 0 (legado)
  ///   GPT    attempt=2: começa em 1 (conforme contrato 462B)
  final int sequence;

  const AiTextDelta({
    required super.requestId,
    required super.attempt,
    required super.timestamp,
    required this.delta,
    required this.sequence,
  });

  factory AiTextDelta.now({
    required String requestId,
    required int attempt,
    required String delta,
    required int sequence,
  }) =>
      AiTextDelta(
        requestId: requestId,
        attempt: attempt,
        timestamp: AiEvent.nowIso(),
        delta: delta,
        sequence: sequence,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
/// Sinaliza que o provedor ativo mudou durante o fluxo.
/// Emitido ANTES de qualquer evento do novo attempt.
///
/// Ordem obrigatória quando há parcial descartável (< 80 chars acumulados):
///   AiProviderSwitched → AiStreamReset → AiStarted(attempt=N)
///
/// Ordem quando não há texto prévio:
///   AiProviderSwitched → AiStarted(attempt=N)
///
/// NUNCA concatenar texto produzido por diferentes providers.
// ─────────────────────────────────────────────────────────────────────────────
final class AiProviderSwitched extends AiEvent {
  /// Provider que falhou (ex: 'gemini_free').
  final String fromProvider;

  /// Provider que assumiu (ex: 'gpt_4o_mini').
  final String toProvider;

  /// Motivo do switch (ex: 'quota', 'timeout', 'http_503').
  final String reason;

  const AiProviderSwitched({
    required super.requestId,
    required super.attempt,
    required super.timestamp,
    required this.fromProvider,
    required this.toProvider,
    required this.reason,
  });

  factory AiProviderSwitched.now({
    required String requestId,
    required int attempt,
    required String fromProvider,
    required String toProvider,
    required String reason,
  }) =>
      AiProviderSwitched(
        requestId: requestId,
        attempt: attempt,
        timestamp: AiEvent.nowIso(),
        fromProvider: fromProvider,
        toProvider: toProvider,
        reason: reason,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
/// Instrui o listener a limpar o estado visual do attempt anterior.
///
/// Limpa EXCLUSIVAMENTE:
///   • networkBuffer
///   • visibleTextNotifier
///   • sequência visual do attempt anterior
///   • Markdown pendente
///   • estados streaming e finalizing anteriores
///
/// NÃO limpa:
///   • Pergunta do usuário
///   • requestId
///   • Memória clínica
///   • Contexto / histórico válido anterior
///
/// Emitido somente quando o parcial acumulado é descartável (< 80 chars).
/// Se parcial ≥ 80 chars e houve truncamento: produz AiFailed, não AiStreamReset.
// ─────────────────────────────────────────────────────────────────────────────
final class AiStreamReset extends AiEvent {
  /// Motivo do reset (ex: 'provider_switch_no_partial', 'quota_fallback').
  final String reason;

  const AiStreamReset({
    required super.requestId,
    required super.attempt,
    required super.timestamp,
    required this.reason,
  });

  factory AiStreamReset.now({
    required String requestId,
    required int attempt,
    required String reason,
  }) =>
      AiStreamReset(
        requestId: requestId,
        attempt: attempt,
        timestamp: AiEvent.nowIso(),
        reason: reason,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
/// Resultado de uma ferramenta ou chamada de função (Google Search, RAG, etc.).
/// Preparado para extensões futuras — atualmente não emitido no SSE Gemini,
/// mas a estrutura garante que o barramento suporta o contrato futuro sem
/// quebrar os listeners existentes.
// ─────────────────────────────────────────────────────────────────────────────
final class AiToolResult extends AiEvent {
  /// Nome da ferramenta invocada (ex: 'google_search', 'rag_lookup').
  final String toolName;

  /// Dados retornados pela ferramenta em formato livre.
  final Map<String, dynamic> data;

  const AiToolResult({
    required super.requestId,
    required super.attempt,
    required super.timestamp,
    required this.toolName,
    required this.data,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
/// Metadados bibliográficos das fontes usadas na resposta.
/// Emitido ANTES de AiCompleted quando o grounding (Google Search) está ativo.
// ─────────────────────────────────────────────────────────────────────────────
final class AiSources extends AiEvent {
  /// Lista de fontes bibliográficas.
  /// Cada item: {'title': String, 'url': String, 'snippet': String?}
  final List<Map<String, String>> sources;

  const AiSources({
    required super.requestId,
    required super.attempt,
    required super.timestamp,
    required this.sources,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
/// Evento final de conclusão — sinaliza que o stream terminou com sucesso.
///
/// IMPORTANTE: AiCompleted é emitido pelo AppProvider DEPOIS de:
///   último delta → acumulador completo → validação do requestId
///   → sanitizeAndCheck() → finalText aprovado → persistência válida
///
/// O Markdown final só pode receber o texto sanitizado.
/// Apenas UM AiCompleted é emitido por request (apenas um attempt pode concluir).
// ─────────────────────────────────────────────────────────────────────────────
final class AiCompleted extends AiEvent {
  /// Texto final completo e definitivo (acumulação de todos os AiTextDelta.delta),
  /// JÁ sanitizado pelo sanitizeAndCheck(). Source-of-truth para persistência.
  final String fullText;

  /// Número total de tokens de entrada estimados.
  final int inputTokensApprox;

  /// Número total de tokens de saída estimados.
  final int outputTokensApprox;

  /// Duração total do request em ms (do AiStarted ao AiCompleted).
  final int durationMs;

  /// Provedor que efetivamente respondeu.
  final String usedProvider;

  /// Resultado clínico estruturado validado pelo backend.
  ///
  /// Null no caminho legado ou quando a resposta não possui estrutura aplicável.
  final ClinicalStructuredOutput? clinicalOutput;

  const AiCompleted({
    required super.requestId,
    required super.attempt,
    required super.timestamp,
    required this.fullText,
    this.inputTokensApprox = 0,
    this.outputTokensApprox = 0,
    this.durationMs = 0,
    this.usedProvider = '',
    this.clinicalOutput,
  });

  factory AiCompleted.now({
    required String requestId,
    required int attempt,
    required String fullText,
    required String usedProvider,
    int inputTokensApprox = 0,
    int outputTokensApprox = 0,
    int durationMs = 0,
    ClinicalStructuredOutput? clinicalOutput,
  }) =>
      AiCompleted(
        requestId: requestId,
        attempt: attempt,
        timestamp: AiEvent.nowIso(),
        fullText: fullText,
        inputTokensApprox: inputTokensApprox,
        outputTokensApprox: outputTokensApprox,
        durationMs: durationMs,
        usedProvider: usedProvider,
        clinicalOutput: clinicalOutput,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
/// Evento de falha — encerra o stream com falha identificada.
///
/// Contém [partialText] quando a falha ocorreu após receber texto parcial ≥ 80 chars.
/// Nesse caso a UI exibe o aviso clínico de resposta interrompida.
///
/// REGRAS de resposta parcial interrompida (≥ 80 chars):
///   • Não persistir no Firestore
///   • Não inserir no _aiHistory válido
///   • Não ativar ações clínicas
///   • Exibir aviso: "⚠️ Resposta interrompida antes da validação final..."
///
/// EOF sem transport_done: Flutter cria AiFailed localmente com partialText.
// ─────────────────────────────────────────────────────────────────────────────
final class AiFailed extends AiEvent {
  /// Código canônico do erro:
  ///   'quota', 'timeout', 'network', 'http_503', 'api_key_invalid',
  ///   'cf_unauthenticated', 'cf_timeout', 'cf_internal',
  ///   'eof_no_transport_done', 'json_parse_error', etc.
  final String code;

  /// Mensagem humano-legível (para debug/logs — não exposta na UI).
  final String message;

  /// Se true, o AppProvider pode tentar o próximo provedor da cadeia de fallback.
  final bool retryable;

  /// Texto parcial acumulado antes da falha.
  /// Presente quando a falha ocorreu após ≥ 80 chars acumulados.
  /// null quando não há parcial significativo.
  final String? partialText;

  const AiFailed({
    required super.requestId,
    required super.attempt,
    required super.timestamp,
    required this.code,
    required this.message,
    required this.retryable,
    this.partialText,
  });

  factory AiFailed.now({
    required String requestId,
    required int attempt,
    required String code,
    required String message,
    required bool retryable,
    String? partialText,
  }) =>
      AiFailed(
        requestId: requestId,
        attempt: attempt,
        timestamp: AiEvent.nowIso(),
        code: code,
        message: message,
        retryable: retryable,
        partialText: partialText,
      );

  /// Limite de caracteres acumulados acima do qual o parcial é "significativo"
  /// (não pode ser resetado silenciosamente nem concatenado com outro provider).
  static const int kSignificantPartialThreshold = 80;

  /// Retorna true se [partialText] ultrapassa o limiar clínico.
  bool get hasSignificantPartial =>
      partialText != null &&
      partialText!.length >= kSignificantPartialThreshold;
}
