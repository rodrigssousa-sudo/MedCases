import '../../../plantao_pipeline.dart';

/// Forma semântica da pergunta antes da escolha do response model.
///
/// Shadow-only nesta fase. Não altera o roteamento produtivo.
/// Tarefa farmacológica informacional explicitamente reconhecida.
///
/// Shadow-only: não seleciona response model.
enum PlantaoPharmacologicInformationTask {
  adverseEffects,
  medicationSafety,
}

/// Tarefas clínicas informacionais não farmacológicas específicas.
///
/// Shadow-only. Usadas como proveniência para separar famílias semânticas.
enum PlantaoClinicalInformationTask {
  antibioticotherapy,
  clinicalSummary,
}

/// Domínios clínicos de tópico que podem existir sem intenção verbal explícita.
///
/// Shadow-only. Não alteram o mandate legado.
enum PlantaoClinicalTopicDomainSignal {
  acuteDyspnea,
  hemorrhage,
}

/// Domínio semântico adicional de uma `clinicalTask`.
///
/// Shadow-only. Estes sinais existem para desambiguar response contracts;
/// não selecionam modelo por conta própria.
enum PlantaoClinicalTaskDomainSignal {
  gasometryAcidBase,
  laboratoryCalculation,
  sepsis,
  shock,
  trauma,
}

enum PlantaoQueryShape {
  /// Nome de fármaco reconhecido, sem tarefa explícita nem contexto explícito.
  isolatedDrug,

  /// Doença/síndrome/contexto clínico reconhecido sem tarefa explícita.
  clinicalTopicOnly,

  /// O usuário explicitou uma tarefa: dose, manejo, diagnóstico, cálculo
  /// ou tarefa farmacológica informacional tipada.
  clinicalTask,

  /// Fármaco reconhecido dentro de um contexto clínico explicitamente informado,
  /// porém sem tarefa explícita.
  drugWithinClinicalContext,

  /// Sinais insuficientes ou não adjudicados.
  ambiguous,
}

/// Resultado tipado observacional do query shape.
class PlantaoQueryShapeDecision {
  final PlantaoQueryShape shape;
  final bool recognizedDrugEntity;
  final bool recognizedExplicitClinicalContext;
  final bool hasExplicitTaskIntent;

  final Set<PlantaoPharmacologicInformationTask> pharmacologicInformationTasks;

  /// Tarefas clínicas informacionais tipadas, independentes do legado.
  final Set<PlantaoClinicalInformationTask> clinicalInformationTasks;

  /// Domínios semânticos de tópico para famílias antes ambíguas.
  final Set<PlantaoClinicalTopicDomainSignal> clinicalTopicDomains;

  /// Evidência de domínio para `clinicalTask`, independente do legado.

  final Set<PlantaoClinicalTaskDomainSignal> clinicalTaskDomains;
  final PlantaoIntent primaryIntent;
  final String clinicalTopic;

  const PlantaoQueryShapeDecision({
    required this.shape,
    required this.recognizedDrugEntity,
    required this.recognizedExplicitClinicalContext,
    required this.hasExplicitTaskIntent,
    this.pharmacologicInformationTasks = const {},
    this.clinicalInformationTasks = const {},
    this.clinicalTopicDomains = const {},
    this.clinicalTaskDomains = const {},
    required this.primaryIntent,
    required this.clinicalTopic,
  });
}

/// Resolve apenas a forma da pergunta.
///
/// Não escolhe `PlantaoResponseModelId`, não modifica matrizes e não participa
/// do mandate legado. É uma fundação para o futuro roteador canônico.
abstract final class PlantaoQueryShapeResolver {
  static const Set<PlantaoIntent> _explicitTaskIntents = {
    PlantaoIntent.conduta,
    PlantaoIntent.dose,
    PlantaoIntent.infusao,
    PlantaoIntent.diluicao,
    PlantaoIntent.monitorizacao,
    PlantaoIntent.contraindicacao,
    PlantaoIntent.diagnostico,
    PlantaoIntent.interpretacao,
    PlantaoIntent.calculo,
    PlantaoIntent.interacao,
    PlantaoIntent.procedimento,
  };

  static PlantaoQueryShapeDecision resolve(PlantaoQueryAnalysis analysis) {
    final pharmacologicInformationTasks = <PlantaoPharmacologicInformationTask>{
      if (analysis.recognizedAdverseEffectTask)
        PlantaoPharmacologicInformationTask.adverseEffects,
      if (analysis.recognizedMedicationSafetyTask)
        PlantaoPharmacologicInformationTask.medicationSafety,
    };

    final clinicalInformationTasks = <PlantaoClinicalInformationTask>{
      if (analysis.recognizedAntibioticotherapyTask)
        PlantaoClinicalInformationTask.antibioticotherapy,
      if (analysis.recognizedClinicalSummaryTask)
        PlantaoClinicalInformationTask.clinicalSummary,
    };

    final clinicalTopicDomains = <PlantaoClinicalTopicDomainSignal>{
      if (analysis.recognizedAcuteDyspneaDomain)
        PlantaoClinicalTopicDomainSignal.acuteDyspnea,
      if (analysis.recognizedHemorrhageDomain)
        PlantaoClinicalTopicDomainSignal.hemorrhage,
    };

    final clinicalTaskDomains = <PlantaoClinicalTaskDomainSignal>{
      if (analysis.recognizedGasometryAcidBaseDomain)
        PlantaoClinicalTaskDomainSignal.gasometryAcidBase,
      if (analysis.recognizedLaboratoryCalculationDomain)
        PlantaoClinicalTaskDomainSignal.laboratoryCalculation,
      if (analysis.recognizedSepsisDomain)
        PlantaoClinicalTaskDomainSignal.sepsis,
      if (analysis.recognizedShockDomain) PlantaoClinicalTaskDomainSignal.shock,
      if (analysis.recognizedTraumaDomain)
        PlantaoClinicalTaskDomainSignal.trauma,
    };

    final hasExplicitTask =
        _explicitTaskIntents.contains(analysis.primaryIntent) ||
            pharmacologicInformationTasks.isNotEmpty ||
            clinicalInformationTasks.isNotEmpty;
    final hasDrug = analysis.recognizedDrugEntity;
    final hasExplicitContext = analysis.recognizedExplicitClinicalContext;

    final PlantaoQueryShape shape;

    if (hasExplicitTask) {
      shape = PlantaoQueryShape.clinicalTask;
    } else if (hasDrug && hasExplicitContext) {
      shape = PlantaoQueryShape.drugWithinClinicalContext;
    } else if (hasDrug) {
      shape = PlantaoQueryShape.isolatedDrug;
    } else if ((hasExplicitContext &&
            analysis.clinicalTopic.isNotEmpty &&
            analysis.clinicalTopic != 'CONSULTA CLÍNICA') ||
        clinicalTopicDomains.isNotEmpty) {
      shape = PlantaoQueryShape.clinicalTopicOnly;
    } else {
      shape = PlantaoQueryShape.ambiguous;
    }

    return PlantaoQueryShapeDecision(
      shape: shape,
      recognizedDrugEntity: hasDrug,
      recognizedExplicitClinicalContext: hasExplicitContext,
      hasExplicitTaskIntent: hasExplicitTask,
      pharmacologicInformationTasks:
          Set.unmodifiable(pharmacologicInformationTasks),
      clinicalInformationTasks: Set.unmodifiable(clinicalInformationTasks),
      clinicalTopicDomains: Set.unmodifiable(clinicalTopicDomains),
      clinicalTaskDomains: Set.unmodifiable(clinicalTaskDomains),
      primaryIntent: analysis.primaryIntent,
      clinicalTopic: analysis.clinicalTopic,
    );
  }

  static PlantaoQueryShapeDecision resolveUserMessage(String userMessage) {
    return resolve(PlantaoIntentEngine.analyze(userMessage));
  }
}
