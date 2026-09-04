import '../ai_stream/truncation_inspector.dart';
import 'ai_request_contract.dart';
import 'ai_response_result.dart';

/// Fronteira reutilizável para a inspeção estrutural existente.
abstract class AiTruncationInspectorPort {
  TruncationCheckResult inspect(String text);
}

/// Adaptador para o [TruncationInspector] já existente no projeto.
///
/// Nenhuma heurística é reproduzida nesta camada.
class ExistingTruncationInspectorPort implements AiTruncationInspectorPort {
  const ExistingTruncationInspectorPort();

  @override
  TruncationCheckResult inspect(String text) {
    return TruncationInspector.inspect(text);
  }
}

/// Fronteira do motor de reparo existente.
abstract class AiTruncationRepairPort {
  Future<TruncationRepairResult> repair({
    required String originalText,
    required String requestId,
    required bool isPlantaoMode,
    required String appLanguage,
  });
}

/// Assinatura compatível com `AiService.repairTruncated`.
typedef AiTruncationRepairRunner = Future<TruncationRepairResult> Function({
  required String originalText,
  required String requestId,
  required bool isPlantaoMode,
  required String appLanguage,
});

/// Adaptador neutro para o motor de reparo.
///
/// A camada não importa [AiService]. A composição produtiva poderá fornecer
/// `AiService.repairTruncated` sem criar dependência circular.
class DelegatingAiTruncationRepairPort implements AiTruncationRepairPort {
  final AiTruncationRepairRunner runner;

  const DelegatingAiTruncationRepairPort({
    required this.runner,
  });

  @override
  Future<TruncationRepairResult> repair({
    required String originalText,
    required String requestId,
    required bool isPlantaoMode,
    required String appLanguage,
  }) {
    return runner(
      originalText: originalText,
      requestId: requestId,
      isPlantaoMode: isPlantaoMode,
      appLanguage: appLanguage,
    );
  }
}

/// Snapshot imutável do tratamento de truncamento.
class AiTruncationRepairOutcome {
  final String requestId;
  final String text;
  final TruncationCheckResult inspection;
  final AiRepairStatus repairStatus;
  final bool repairAttempted;
  final bool isValid;
  final String? failureReason;

  const AiTruncationRepairOutcome({
    required this.requestId,
    required this.text,
    required this.inspection,
    required this.repairStatus,
    required this.repairAttempted,
    required this.isValid,
    this.failureReason,
  });

  bool get isTruncated => inspection.isTruncated;

  bool get wasRepaired => repairStatus == AiRepairStatus.repaired;
}

/// Coordena inspeção e reparo sem duplicar as implementações existentes.
///
/// Política preservada do AppProvider:
///
/// - Plantão: qualquer truncamento detectado pode disparar reparo;
/// - Estudo: somente truncamento de alta confiança dispara reparo;
/// - `MAX_TOKENS`: evidência objetiva de truncamento de alta confiança;
/// - cada requestId é processado no máximo uma vez enquanto estiver retido.
class AiTruncationRepairCoordinator {
  final AiTruncationInspectorPort inspector;
  final AiTruncationRepairPort repairPort;

  final Map<String, Future<AiTruncationRepairOutcome>> _operationsByRequest =
      <String, Future<AiTruncationRepairOutcome>>{};

  AiTruncationRepairCoordinator({
    AiTruncationInspectorPort? inspector,
    required this.repairPort,
  }) : inspector = inspector ?? const ExistingTruncationInspectorPort();

  bool containsRequest(String requestId) {
    return _operationsByRequest.containsKey(requestId);
  }

  int get retainedRequestCount => _operationsByRequest.length;

  Future<AiTruncationRepairOutcome> process({
    required String originalText,
    required String requestId,
    required AiRequestMode mode,
    required AiRequestLocale locale,
    String? providerFinishReason,
  }) {
    final normalizedRequestId = requestId.trim();

    if (normalizedRequestId.isEmpty) {
      throw ArgumentError.value(
        requestId,
        'requestId',
        'requestId não pode ser vazio.',
      );
    }

    return _operationsByRequest.putIfAbsent(
      normalizedRequestId,
      () => _processOnce(
        originalText: originalText,
        requestId: normalizedRequestId,
        mode: mode,
        locale: locale,
        providerFinishReason: providerFinishReason,
      ),
    );
  }

  /// Libera o resultado retido após o terminal da requisição.
  bool release(String requestId) {
    return _operationsByRequest.remove(
          requestId.trim(),
        ) !=
        null;
  }

  Future<AiTruncationRepairOutcome> _processOnce({
    required String originalText,
    required String requestId,
    required AiRequestMode mode,
    required AiRequestLocale locale,
    required String? providerFinishReason,
  }) async {
    final inspection = providerFinishReason == 'MAX_TOKENS'
        ? const TruncationCheckResult(
            isTruncated: true,
            confidenceLevel: TruncationConfidence.high,
            violationReason: 'provider_finish_reason_max_tokens',
          )
        : inspector.inspect(originalText);

    final isPlantaoMode = mode == AiRequestMode.plantao;

    final closedPlantaoStructureGuard = isPlantaoMode &&
        providerFinishReason != 'MAX_TOKENS' &&
        inspection.violationReason == 'abrupt_non_punctuation_termination' &&
        _hasClosedPlantaoStructure(originalText);

    final shouldRepair = inspection.isTruncated &&
        !closedPlantaoStructureGuard &&
        (isPlantaoMode ||
            inspection.confidenceLevel == TruncationConfidence.high);

    if (!inspection.isTruncated) {
      return AiTruncationRepairOutcome(
        requestId: requestId,
        text: originalText,
        inspection: inspection,
        repairStatus: AiRepairStatus.notNeeded,
        repairAttempted: false,
        isValid: true,
      );
    }

    if (!shouldRepair) {
      return AiTruncationRepairOutcome(
        requestId: requestId,
        text: originalText,
        inspection: inspection,
        repairStatus: AiRepairStatus.notAttempted,
        repairAttempted: false,
        isValid: true,
      );
    }

    final repairResult = await repairPort.repair(
      originalText: originalText,
      requestId: requestId,
      isPlantaoMode: isPlantaoMode,
      appLanguage: _languageCode(locale),
    );

    if (!repairResult.isValid) {
      return AiTruncationRepairOutcome(
        requestId: requestId,
        text: '',
        inspection: inspection.withRepair(
          retried: true,
          fixed: false,
        ),
        repairStatus: AiRepairStatus.failed,
        repairAttempted: true,
        isValid: false,
        failureReason: repairResult.failureReason ?? 'repair_failed',
      );
    }

    return AiTruncationRepairOutcome(
      requestId: requestId,
      text: repairResult.text,
      inspection: inspection.withRepair(
        retried: true,
        fixed: repairResult.wasRepaired,
      ),
      repairStatus: repairResult.wasRepaired
          ? AiRepairStatus.repaired
          : AiRepairStatus.notNeeded,
      repairAttempted: true,
      isValid: true,
    );
  }
}

bool _hasClosedPlantaoStructure(String text) {
  final normalized = text
      .replaceAll(RegExp(r'[*_`#]+'), '')
      .replaceAll(RegExp(r'[🟥🔴💊⚠️⛔🚨📌🔑\s]+'), ' ')
      .trim()
      .toLowerCase();

  final hasTreatmentHeading =
      normalized.contains('tratamento inicial combinado') ||
          normalized.contains('tratamiento inicial combinado');

  final hasPharmacologicSection =
      normalized.contains('tratamento farmacológico:') ||
          normalized.contains('tratamiento farmacológico:');

  final hasAlertSection = normalized.contains('alerta clínico:') ||
      normalized.contains('alerta clinico:');

  final hasHardStopSection = normalized.contains('hard stop:');

  final hardStopIndex = normalized.lastIndexOf('hard stop:');
  final hardStopHasContent = hardStopIndex >= 0 &&
      normalized
          .substring(hardStopIndex + 'hard stop:'.length)
          .trim()
          .isNotEmpty;

  return hasTreatmentHeading &&
      hasPharmacologicSection &&
      hasAlertSection &&
      hasHardStopSection &&
      hardStopHasContent;
}

String _languageCode(AiRequestLocale locale) {
  switch (locale) {
    case AiRequestLocale.pt:
      return 'pt';
    case AiRequestLocale.es:
      return 'es';
  }
}
