import '../../../plantao_pipeline.dart';
import 'plantao_response_contract.dart';

/// Origem estrutural observada no runtime legado.
enum PlantaoShadowStructuralSignal {
  legacyMatrix,
  isolatedDrugSpecialTemplate,
}

/// Resultado observacional do roteamento Plantão.
///
/// Shadow-only:
/// - não altera a decisão do runtime atual;
/// - não participa da construção do prompt;
/// - não participa do renderer;
/// - preserva separadamente as autoridades estruturais observadas;
/// - só expõe um candidato canônico quando não existe conflito estrutural.
class PlantaoShadowRouteResolution {
  /// Matriz apontada pela cláusula final de supremacia do runtime.
  final int legacyMatrixNumber;

  /// Modelo correspondente exclusivamente ao ponteiro da matriz legada.
  final PlantaoResponseModelId legacyMatrixModelId;

  /// Modelo indicado pelo template especial, quando presente.
  final PlantaoResponseModelId? specialTemplateModelId;

  /// Candidato canônico único.
  ///
  /// É null enquanto duas autoridades estruturais observadas apontarem
  /// para modelos diferentes.
  final PlantaoResponseModelId? responseModelId;

  /// Contrato canônico do candidato único. Null em conflito.
  final PlantaoResponseContract? contract;

  /// Verdadeiro quando matriz e template especial apontam para modelos distintos.
  final bool hasStructuralConflict;

  /// Sinais estruturais observados neste turno.
  final Set<PlantaoShadowStructuralSignal> signals;

  const PlantaoShadowRouteResolution({
    required this.legacyMatrixNumber,
    required this.legacyMatrixModelId,
    required this.specialTemplateModelId,
    required this.responseModelId,
    required this.contract,
    required this.hasStructuralConflict,
    required this.signals,
  });
}

/// Adaptador temporário entre o roteamento produtivo atual e o registry novo.
///
/// Esta classe NÃO decide ainda o roteamento canônico definitivo.
/// Ela mede as autoridades estruturais reais do mandato legado.
abstract final class PlantaoResponseShadowResolver {
  static final RegExp _legacyMatrixPattern = RegExp(
    r'USE EXCLUSIVAMENTE A MATRIZ\s+(\d+)',
    caseSensitive: false,
  );

  static const String _isolatedDrugTemplateMarker = 'TEMPLATE FARMACOLÓGICO';

  static PlantaoShadowRouteResolution resolveAnalysis(
    PlantaoQueryAnalysis analysis, {
    String languageCode = 'pt',
  }) {
    final legacyMandate = PlantaoIntentEngine.buildIntentMandateV2(
      analysis,
      languageCode,
    );

    final legacyMatrixNumber = _observedLegacyMatrixNumber(legacyMandate);
    final legacyMatrixContract =
        PlantaoResponseContractRegistry.byLegacyMatrix(legacyMatrixNumber);

    final hasIsolatedDrugSpecialTemplate =
        legacyMandate.contains(_isolatedDrugTemplateMarker);

    final specialTemplateContract = hasIsolatedDrugSpecialTemplate
        ? PlantaoResponseContractRegistry.byId(
            PlantaoResponseModelId.farmacoIsolado,
          )
        : null;

    final hasStructuralConflict = specialTemplateContract != null &&
        specialTemplateContract.id != legacyMatrixContract.id;

    final canonicalCandidate = hasStructuralConflict
        ? null
        : (specialTemplateContract ?? legacyMatrixContract);

    return PlantaoShadowRouteResolution(
      legacyMatrixNumber: legacyMatrixNumber,
      legacyMatrixModelId: legacyMatrixContract.id,
      specialTemplateModelId: specialTemplateContract?.id,
      responseModelId: canonicalCandidate?.id,
      contract: canonicalCandidate,
      hasStructuralConflict: hasStructuralConflict,
      signals: {
        PlantaoShadowStructuralSignal.legacyMatrix,
        if (hasIsolatedDrugSpecialTemplate)
          PlantaoShadowStructuralSignal.isolatedDrugSpecialTemplate,
      },
    );
  }

  static PlantaoShadowRouteResolution resolveUserMessage(
    String userMessage, {
    String languageCode = 'pt',
  }) {
    final analysis = PlantaoIntentEngine.analyze(userMessage);
    return resolveAnalysis(
      analysis,
      languageCode: languageCode,
    );
  }

  static int _observedLegacyMatrixNumber(String legacyMandate) {
    final match = _legacyMatrixPattern.firstMatch(legacyMandate);
    final parsed = int.tryParse(match?.group(1) ?? '');

    if (parsed != null && parsed >= 1 && parsed <= 22) {
      return parsed;
    }

    throw StateError(
      'Mandato legado sem ponteiro de matriz observável entre 1 e 22.',
    );
  }
}
