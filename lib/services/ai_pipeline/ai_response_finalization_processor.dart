import '../ai/ai_finalization_transaction.dart';
import '../ai_service.dart';
import 'ai_request_contract.dart';
import 'ai_response_result.dart';
import 'ai_response_sanitizer.dart';
import 'ai_response_structure_parser.dart';
import 'ai_truncation_repair_coordinator.dart';

enum AiResponseFinalizationStatus {
  ready,
  repairFailed,
  sanitizationFailed,
  structuredOutputInvalid,
}

/// Resultado imutável do processamento de um snapshot já congelado.
///
/// Esta estrutura mantém as evidências intermediárias sem atribuir ao
/// processador responsabilidades de persistência, UI ou propriedade terminal.
class AiResponseFinalizationOutcome {
  final AiResponseFinalizationStatus status;

  final FinalOutputSnapshot snapshot;

  final AiTruncationRepairOutcome? truncation;
  final AiResponseSanitizationOutcome? sanitization;
  final AiResponseStructureOutcome? structure;

  final AiResponseResult? result;

  final String? failureCode;
  final String? failureReason;

  const AiResponseFinalizationOutcome({
    required this.status,
    required this.snapshot,
    required this.truncation,
    required this.sanitization,
    required this.structure,
    required this.result,
    this.failureCode,
    this.failureReason,
  });

  bool get isReady =>
      status == AiResponseFinalizationStatus.ready && result != null;
}

/// Processa somente conteúdo terminal já congelado.
///
/// Ordem:
///
/// 1. truncamento e eventual reparo;
/// 2. sanitização;
/// 3. interpretação estrutural;
/// 4. construção de [AiResponseResult].
///
/// Fora do escopo:
///
/// - competir por propriedade terminal;
/// - controlar a fila de streaming;
/// - persistir no Firestore;
/// - resolver ferramentas;
/// - emitir callbacks para a UI;
/// - alterar Markdown ou estética;
/// - executar roteamento ou fallback de provedores.
class AiResponseFinalizationProcessor {
  final AiTruncationRepairCoordinator truncationCoordinator;

  final AiResponseSanitizer sanitizer;
  final AiResponseStructureParser structureParser;

  AiResponseFinalizationProcessor({
    required this.truncationCoordinator,
    this.sanitizer = const AiResponseSanitizer(),
    this.structureParser = const AiResponseStructureParser(),
  });

  factory AiResponseFinalizationProcessor.withExistingImplementations() {
    return AiResponseFinalizationProcessor(
      truncationCoordinator: AiTruncationRepairCoordinator(
        repairPort: DelegatingAiTruncationRepairPort(
          runner: AiService.repairTruncated,
        ),
      ),
    );
  }

  Future<AiResponseFinalizationOutcome> process({
    required FinalOutputSnapshot snapshot,
    required AiRequestMode mode,
    required AiRequestLocale locale,
    required String provider,
    required int attempt,
    String? providerFinishReason,
    Object? structuredOutput,
    AiTerminalCause terminalCause = AiTerminalCause.completed,
    bool isPartial = false,
    bool isFallback = false,
  }) async {
    if (attempt < 1) {
      throw ArgumentError.value(
        attempt,
        'attempt',
        'attempt deve ser maior que zero.',
      );
    }

    final truncation = await truncationCoordinator.process(
      originalText: snapshot.rawOutput,
      requestId: snapshot.parentRequestId,
      mode: mode,
      locale: locale,
      providerFinishReason: providerFinishReason,
    );

    if (!truncation.isValid) {
      return AiResponseFinalizationOutcome(
        status: AiResponseFinalizationStatus.repairFailed,
        snapshot: snapshot,
        truncation: truncation,
        sanitization: null,
        structure: null,
        result: null,
        failureCode: 'truncation_repair_failed',
        failureReason: truncation.failureReason ?? 'repair_failed',
      );
    }

    final sanitization = sanitizer.sanitize(
      text: truncation.text,
      mode: mode,
      locale: locale,
    );

    if (!sanitization.isRecoverable || sanitization.isEmpty) {
      return AiResponseFinalizationOutcome(
        status: AiResponseFinalizationStatus.sanitizationFailed,
        snapshot: snapshot,
        truncation: truncation,
        sanitization: sanitization,
        structure: null,
        result: null,
        failureCode: 'response_sanitization_failed',
        failureReason: sanitization.isEmpty
            ? 'empty_after_sanitization'
            : 'unrecoverable_sanitization',
      );
    }

    final structure = structureParser.parse(
      text: sanitization.text,
      mode: mode,
      structuredOutput: structuredOutput,
    );

    if (structure.hasInvalidStructuredOutput) {
      return AiResponseFinalizationOutcome(
        status: AiResponseFinalizationStatus.structuredOutputInvalid,
        snapshot: snapshot,
        truncation: truncation,
        sanitization: sanitization,
        structure: structure,
        result: null,
        failureCode: 'structured_output_invalid',
        failureReason:
            structure.structuredOutputErrorCode ?? 'structured_output_invalid',
      );
    }

    final normalizedProvider = provider.trim();

    final result = AiResponseResult(
      requestId: snapshot.parentRequestId,
      sessionId: snapshot.sessionId,
      finalText: sanitization.text,
      displayText: sanitization.text,
      provider: normalizedProvider.isEmpty ? null : normalizedProvider,
      attempt: attempt,
      terminalCause: terminalCause,
      isPartial: isPartial,
      isFallback: isFallback,
      repairStatus: truncation.repairStatus,
      structuredOutput: structure.clinicalOutput,
      persistenceStatus: AiPersistenceStatus.notAttempted,
    );

    return AiResponseFinalizationOutcome(
      status: AiResponseFinalizationStatus.ready,
      snapshot: snapshot,
      truncation: truncation,
      sanitization: sanitization,
      structure: structure,
      result: result,
    );
  }

  bool release(String requestId) {
    return truncationCoordinator.release(
      requestId,
    );
  }
}
