import 'plantao_section.dart';

enum PlantaoContinuationType {
  initial,
  examsEvolution,
  treatmentExpansion,
  differentialDiagnosis,
  dosageClarification,
  monitoring,
  prognosisDisposition,
  freeFollowUp,
}

PlantaoContinuationType plantaoContinuationTypeFromWire(String value) {
  return PlantaoContinuationType.values.firstWhere(
    (PlantaoContinuationType item) => item.name == value,
    orElse: () =>
        throw FormatException('Unknown PlantaoContinuationType: $value'),
  );
}

const Set<PlantaoSection> plantaoExamsEvolutionAllowedSections =
    <PlantaoSection>{
      PlantaoSection.exams,
      PlantaoSection.monitoring,
      PlantaoSection.evolution,
      PlantaoSection.responseCriteria,
      PlantaoSection.worseningCriteria,
    };

const Set<PlantaoSection> plantaoExamsEvolutionForbiddenSections =
    <PlantaoSection>{
      PlantaoSection.fullTreatment,
      PlantaoSection.firstLine,
      PlantaoSection.secondLine,
      PlantaoSection.completeMatrixReplay,
    };

extension PlantaoContinuationTypeRules on PlantaoContinuationType {
  bool allowsSection(PlantaoSection section) {
    if (this != PlantaoContinuationType.examsEvolution) {
      return true;
    }
    return plantaoExamsEvolutionAllowedSections.contains(section);
  }

  bool get requiresFocusedSections =>
      this == PlantaoContinuationType.examsEvolution;
}
