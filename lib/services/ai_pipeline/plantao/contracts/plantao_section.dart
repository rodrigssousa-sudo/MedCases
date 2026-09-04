enum PlantaoSection {
  summary,
  immediateActions,
  exams,
  monitoring,
  evolution,
  responseCriteria,
  worseningCriteria,
  fullTreatment,
  firstLine,
  secondLine,
  completeMatrixReplay,
  differentialDiagnosis,
  dosageClarification,
  disposition,
  references,
}

PlantaoSection plantaoSectionFromWire(String value) {
  return PlantaoSection.values.firstWhere(
    (PlantaoSection item) => item.name == value,
    orElse: () => throw FormatException('Unknown PlantaoSection: $value'),
  );
}
