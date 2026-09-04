import '../../../plantao_pipeline.dart';
import 'plantao_query_shape.dart';
import 'plantao_response_contract.dart';
import 'plantao_response_shadow_resolver.dart';

/// Fonte da decisão canônica shadow.
///
/// V1-B-R0 possui regras adjudicadas somente em shadow:
/// - `isolatedDrug` limpo -> `farmacoIsolado`;
/// - 16 assinaturas `clinicalTask` auditadas -> 15 modelos clínicos.
enum PlantaoCanonicalRouteDecisionSource {
  typedIsolatedDrug,
  typedClinicalTaskManifest,
  typedClinicalTopicOnlyManifest,
  typedSemanticFamilyManifest,
  unadjudicated,
}

/// Motivos para a decisão permanecer fail-closed.
enum PlantaoCanonicalRouteConflictReason {
  queryShapeNotAdjudicated,
  isolatedDrugMissingDrugEvidence,
  isolatedDrugHasExplicitClinicalContext,
  isolatedDrugHasExplicitTask,
  isolatedDrugHasPharmacologicInformationTask,
}

/// Primeira decisão canônica tipada do Plantão.
///
/// Shadow-only:
/// - não participa do gateway produtivo;
/// - não altera mandate;
/// - não altera provider;
/// - não altera renderer;
/// - não altera persistência;
/// - não faz cutover;
/// - o runtime legado é apenas observado, nunca usado como autoridade
///   para escolher o modelo canônico.
class PlantaoCanonicalRouteDecision {
  final PlantaoQueryShapeDecision queryShapeDecision;

  /// Modelo canônico selecionado. Null para toda forma ainda não adjudicada.
  final PlantaoResponseModelId? responseModelId;

  /// Contrato correspondente ao modelo selecionado.
  final PlantaoResponseContract? contract;

  final PlantaoCanonicalRouteDecisionSource decisionSource;

  /// Motivos fail-closed. Vazio somente quando existe uma decisão canônica.
  final Set<PlantaoCanonicalRouteConflictReason> conflictReasons;

  /// Observação do runtime legado para auditoria de divergência.
  ///
  /// Não participa da decisão canônica e pode ser null se o observer legado
  /// não conseguir produzir uma observação.
  final PlantaoShadowRouteResolution? legacyObservation;

  const PlantaoCanonicalRouteDecision({
    required this.queryShapeDecision,
    required this.responseModelId,
    required this.contract,
    required this.decisionSource,
    required this.conflictReasons,
    required this.legacyObservation,
  });

  bool get hasCanonicalDecision => responseModelId != null;
}

/// Autoridade canônica futura — ainda completamente shadow-only.
///
/// Regra V1-B-R0:
///
/// ```text
/// queryShape == isolatedDrug
/// AND recognizedDrugEntity == true
/// AND recognizedExplicitClinicalContext == false
/// AND hasExplicitTaskIntent == false
/// AND pharmacologicInformationTasks.isEmpty
/// -> farmacoIsolado
/// ```
///
/// Qualquer outra forma permanece `null`.
abstract final class PlantaoCanonicalRouteResolver {
  /// Manifesto shadow adjudicado após 32 probes positivos,
  /// 40 negative controls PT/ES e 0 colisões de generalização.
  static const Map<String, PlantaoResponseModelId> _clinicalTaskManifest =
      <String, PlantaoResponseModelId>{
    // S01
    'interpretacao~farmacologia~CONSULTA CLÍNICA~NONE~laboratoryCalculation~false~false':
        PlantaoResponseModelId.alteracaoLaboratorialCalculoClinico,
    // S02
    'conduta~arritmia~ARRITMIA~NONE~NONE~false~true':
        PlantaoResponseModelId.arritmia,
    // S03
    'conduta~neurologia~AVC ISQUÊMICO~NONE~NONE~false~true':
        PlantaoResponseModelId.avc,
    // S04
    'conduta~cardiovascular~TEP~NONE~NONE~false~true':
        PlantaoResponseModelId.casoClinicoEmergencia,
    // S05
    'conduta~choque~CHOQUE~NONE~shock~false~true':
        PlantaoResponseModelId.choque,
    // S06
    'monitorizacao~cardiovascular~CRISE HIPERTENSIVA~NONE~NONE~false~true':
        PlantaoResponseModelId.criseHipertensiva,
    // S07
    'conduta~eletrolitos~DISTÚRBIO ELETROLÍTICO~NONE~NONE~false~true':
        PlantaoResponseModelId.disturbioEletrolitico,
    // S08
    'diagnostico~cardiovascular~IAM~NONE~NONE~false~true':
        PlantaoResponseModelId.dorToracicaAguda,
    // S09
    'geral~arritmia~AMIODARONA~adverseEffects~NONE~true~false':
        PlantaoResponseModelId.efeitosAdversosMedicamentosos,
    // S10
    'interpretacao~farmacologia~CONSULTA CLÍNICA~NONE~gasometryAcidBase~false~false':
        PlantaoResponseModelId.gasometriaAcidoBase,
    // S11
    'infusao~choque~NORADRENALINA~NONE~NONE~true~false':
        PlantaoResponseModelId.infusaoTitulacaoDesmame,
    // S12
    'infusao~choque~NORADRENALINA~NONE~shock~true~true':
        PlantaoResponseModelId.infusaoTitulacaoDesmame,
    // S13
    'conduta~renal~INJÚRIA RENAL AGUDA~NONE~NONE~false~true':
        PlantaoResponseModelId.lesaoRenalAguda,
    // S14
    'conduta~choque~CHOQUE~NONE~sepsis~false~true':
        PlantaoResponseModelId.sepseChoqueSeptico,
    // S15
    'conduta~farmacologia~CONSULTA CLÍNICA~NONE~trauma~false~false':
        PlantaoResponseModelId.trauma,
    // S16
    'monitorizacao~ventilacao~VENTILAÇÃO MECÂNICA~NONE~NONE~false~true':
        PlantaoResponseModelId.viaAereaVentilacaoMecanica,
  };

  /// Manifesto shadow para os dois `clinicalTopicOnly` cuja generalização
  /// PT/ES foi auditada após reconciliação semântica:
  /// - M09 intoxicação exógena;
  /// - M14 parada cardiorrespiratória.
  ///
  /// Qualquer outra assinatura `clinicalTopicOnly` permanece fail-closed.
  static const Map<String, PlantaoResponseModelId> _clinicalTopicOnlyManifest =
      <String, PlantaoResponseModelId>{
    'geral~toxicologia~INTOXICAÇÃO~NONE~NONE~false~true':
        PlantaoResponseModelId.intoxicacaoExogena,
    'geral~pcr~PCR~NONE~NONE~false~true':
        PlantaoResponseModelId.paradaCardiorrespiratoria,
  };

  /// Manifesto tipado das quatro famílias que eram semanticamente ambíguas.
  ///
  /// A chave usa apenas proveniência nova e ortogonal; os guards clínicos
  /// abaixo impedem que contextos mais específicos sejam sequestrados.
  static const Map<String, PlantaoResponseModelId> _semanticFamilyManifest =
      <String, PlantaoResponseModelId>{
    'antibioticotherapy~NONE': PlantaoResponseModelId.antibioticoterapia,
    'clinicalSummary~NONE': PlantaoResponseModelId.consultaClinicaGeral,
    'NONE~acuteDyspnea': PlantaoResponseModelId.dispneiaAguda,
    'NONE~hemorrhage': PlantaoResponseModelId.hemorragia,
  };

  static String _semanticFamilySignature(
    PlantaoQueryShapeDecision shapeDecision,
  ) {
    final infoTasks = shapeDecision.clinicalInformationTasks
        .map((e) => e.name)
        .toList()
      ..sort();
    final topicDomains =
        shapeDecision.clinicalTopicDomains.map((e) => e.name).toList()..sort();

    return <String>[
      infoTasks.isEmpty ? 'NONE' : infoTasks.join(','),
      topicDomains.isEmpty ? 'NONE' : topicDomains.join(','),
    ].join('~');
  }

  static PlantaoResponseModelId? _resolveSemanticFamilyManifest(
    PlantaoQueryAnalysis analysis,
    PlantaoQueryShapeDecision shapeDecision,
  ) {
    if (shapeDecision.recognizedDrugEntity) return null;
    if (shapeDecision.pharmacologicInformationTasks.isNotEmpty) return null;

    final infoTasks = shapeDecision.clinicalInformationTasks;
    final topicDomains = shapeDecision.clinicalTopicDomains;

    // M07 — antibioticoterapia: sepse explícita permanece domínio próprio.
    if (infoTasks.length == 1 &&
        infoTasks.contains(PlantaoClinicalInformationTask.antibioticotherapy)) {
      if (topicDomains.isNotEmpty) return null;
      if (analysis.recognizedSepsisDomain ||
          analysis.clinicalContext == PlantaoContext.sepse) {
        return null;
      }
      return _semanticFamilyManifest[_semanticFamilySignature(shapeDecision)];
    }

    // M21 — resumo clínico geral: somente quando nenhum contexto clínico
    // específico já reconhecido compete com a consulta geral.
    if (infoTasks.length == 1 &&
        infoTasks.contains(PlantaoClinicalInformationTask.clinicalSummary)) {
      if (topicDomains.isNotEmpty) return null;
      if (shapeDecision.recognizedExplicitClinicalContext) return null;
      if (shapeDecision.clinicalTaskDomains.isNotEmpty) return null;
      return _semanticFamilyManifest[_semanticFamilySignature(shapeDecision)];
    }

    // M13 — dispneia aguda: não sequestra TEP/IAM/PCR/sepse/choque.
    if (infoTasks.isEmpty &&
        topicDomains.length == 1 &&
        topicDomains.contains(PlantaoClinicalTopicDomainSignal.acuteDyspnea)) {
      const allowedContexts = <PlantaoContext>{
        PlantaoContext.farmacologia,
        PlantaoContext.geral,
        PlantaoContext.viaAerea,
        PlantaoContext.ventilacao,
      };
      if (!allowedContexts.contains(analysis.clinicalContext)) return null;
      if (analysis.recognizedSepsisDomain ||
          analysis.recognizedShockDomain ||
          analysis.recognizedTraumaDomain) {
        return null;
      }
      return _semanticFamilyManifest[_semanticFamilySignature(shapeDecision)];
    }

    // M18 — hemorragia: choque hemorrágico continua sendo hemorragia, mas
    // trauma explícito preserva precedência traumática.
    if (infoTasks.isEmpty &&
        topicDomains.length == 1 &&
        topicDomains.contains(PlantaoClinicalTopicDomainSignal.hemorrhage)) {
      const allowedContexts = <PlantaoContext>{
        PlantaoContext.farmacologia,
        PlantaoContext.geral,
        PlantaoContext.choque,
      };
      if (!allowedContexts.contains(analysis.clinicalContext)) return null;
      if (analysis.recognizedTraumaDomain) return null;
      return _semanticFamilyManifest[_semanticFamilySignature(shapeDecision)];
    }

    return null;
  }

  static String _clinicalTaskSignature(
    PlantaoQueryAnalysis analysis,
    PlantaoQueryShapeDecision shapeDecision,
  ) {
    final pharmacologicTasks = shapeDecision.pharmacologicInformationTasks
        .map((e) => e.name)
        .toList()
      ..sort();
    final domains =
        shapeDecision.clinicalTaskDomains.map((e) => e.name).toList()..sort();

    return <String>[
      analysis.primaryIntent.name,
      analysis.clinicalContext.name,
      analysis.clinicalTopic,
      pharmacologicTasks.isEmpty ? 'NONE' : pharmacologicTasks.join(','),
      domains.isEmpty ? 'NONE' : domains.join(','),
      shapeDecision.recognizedDrugEntity.toString(),
      shapeDecision.recognizedExplicitClinicalContext.toString(),
    ].join('~');
  }

  static PlantaoResponseModelId? _resolveClinicalTaskManifest(
    PlantaoQueryAnalysis analysis,
    PlantaoQueryShapeDecision shapeDecision,
  ) {
    if (shapeDecision.shape != PlantaoQueryShape.clinicalTask) return null;
    return _clinicalTaskManifest[
        _clinicalTaskSignature(analysis, shapeDecision)];
  }

  static PlantaoResponseModelId? _resolveClinicalTopicOnlyManifest(
    PlantaoQueryAnalysis analysis,
    PlantaoQueryShapeDecision shapeDecision,
  ) {
    if (shapeDecision.shape != PlantaoQueryShape.clinicalTopicOnly) return null;
    return _clinicalTopicOnlyManifest[
        _clinicalTaskSignature(analysis, shapeDecision)];
  }

  static PlantaoCanonicalRouteDecision resolveAnalysis(
    PlantaoQueryAnalysis analysis, {
    String languageCode = 'pt',
    bool observeLegacy = true,
  }) {
    final shapeDecision = PlantaoQueryShapeResolver.resolve(analysis);
    final legacyObservation = observeLegacy
        ? _observeLegacy(
            analysis,
            languageCode: languageCode,
          )
        : null;

    final semanticFamilyResponseModelId =
        _resolveSemanticFamilyManifest(analysis, shapeDecision);

    if (semanticFamilyResponseModelId != null) {
      final contract =
          PlantaoResponseContractRegistry.byId(semanticFamilyResponseModelId);
      return PlantaoCanonicalRouteDecision(
        queryShapeDecision: shapeDecision,
        responseModelId: semanticFamilyResponseModelId,
        contract: contract,
        decisionSource:
            PlantaoCanonicalRouteDecisionSource.typedSemanticFamilyManifest,
        conflictReasons: const {},
        legacyObservation: legacyObservation,
      );
    }

    if (shapeDecision.shape == PlantaoQueryShape.isolatedDrug) {
      final reasons = <PlantaoCanonicalRouteConflictReason>{
        if (!shapeDecision.recognizedDrugEntity)
          PlantaoCanonicalRouteConflictReason.isolatedDrugMissingDrugEvidence,
        if (shapeDecision.recognizedExplicitClinicalContext)
          PlantaoCanonicalRouteConflictReason
              .isolatedDrugHasExplicitClinicalContext,
        if (shapeDecision.hasExplicitTaskIntent)
          PlantaoCanonicalRouteConflictReason.isolatedDrugHasExplicitTask,
        if (shapeDecision.pharmacologicInformationTasks.isNotEmpty)
          PlantaoCanonicalRouteConflictReason
              .isolatedDrugHasPharmacologicInformationTask,
      };

      if (reasons.isEmpty) {
        final contract = PlantaoResponseContractRegistry.byId(
          PlantaoResponseModelId.farmacoIsolado,
        );

        return PlantaoCanonicalRouteDecision(
          queryShapeDecision: shapeDecision,
          responseModelId: contract.id,
          contract: contract,
          decisionSource: PlantaoCanonicalRouteDecisionSource.typedIsolatedDrug,
          conflictReasons: const {},
          legacyObservation: legacyObservation,
        );
      }

      return PlantaoCanonicalRouteDecision(
        queryShapeDecision: shapeDecision,
        responseModelId: null,
        contract: null,
        decisionSource: PlantaoCanonicalRouteDecisionSource.unadjudicated,
        conflictReasons: Set.unmodifiable(reasons),
        legacyObservation: legacyObservation,
      );
    }

    if (shapeDecision.shape == PlantaoQueryShape.clinicalTask) {
      final responseModelId = _resolveClinicalTaskManifest(
        analysis,
        shapeDecision,
      );

      if (responseModelId != null) {
        final contract = PlantaoResponseContractRegistry.byId(responseModelId);
        return PlantaoCanonicalRouteDecision(
          queryShapeDecision: shapeDecision,
          responseModelId: responseModelId,
          contract: contract,
          decisionSource:
              PlantaoCanonicalRouteDecisionSource.typedClinicalTaskManifest,
          conflictReasons: const {},
          legacyObservation: legacyObservation,
        );
      }
    }

    if (shapeDecision.shape == PlantaoQueryShape.clinicalTopicOnly) {
      final responseModelId = _resolveClinicalTopicOnlyManifest(
        analysis,
        shapeDecision,
      );

      if (responseModelId != null) {
        final contract = PlantaoResponseContractRegistry.byId(responseModelId);
        return PlantaoCanonicalRouteDecision(
          queryShapeDecision: shapeDecision,
          responseModelId: responseModelId,
          contract: contract,
          decisionSource: PlantaoCanonicalRouteDecisionSource
              .typedClinicalTopicOnlyManifest,
          conflictReasons: const {},
          legacyObservation: legacyObservation,
        );
      }
    }

    return PlantaoCanonicalRouteDecision(
      queryShapeDecision: shapeDecision,
      responseModelId: null,
      contract: null,
      decisionSource: PlantaoCanonicalRouteDecisionSource.unadjudicated,
      conflictReasons: const {
        PlantaoCanonicalRouteConflictReason.queryShapeNotAdjudicated,
      },
      legacyObservation: legacyObservation,
    );
  }

  static PlantaoCanonicalRouteDecision resolveUserMessage(
    String userMessage, {
    String languageCode = 'pt',
  }) {
    final analysis = PlantaoIntentEngine.analyze(userMessage);

    return resolveAnalysis(
      analysis,
      languageCode: languageCode,
    );
  }

  static PlantaoShadowRouteResolution? _observeLegacy(
    PlantaoQueryAnalysis analysis, {
    required String languageCode,
  }) {
    try {
      return PlantaoResponseShadowResolver.resolveAnalysis(
        analysis,
        languageCode: languageCode,
      );
    } catch (_) {
      return null;
    }
  }
}
