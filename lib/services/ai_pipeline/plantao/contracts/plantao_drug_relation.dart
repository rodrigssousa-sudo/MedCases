enum PlantaoDrugRelationType {
  concomitant,
  alternative,
  conditional,
  firstLine,
  secondLine,
  adjunct,
  rescue,
  contraindicated,
  sequenceStep,
}

enum PlantaoDrugValidationStatus { unvalidated, validated, repaired, blocked }

class PlantaoMedicationItem {
  const PlantaoMedicationItem({
    required this.drugDocumentId,
    required this.drugName,
    required this.relation,
    required this.indication,
    required this.dose,
    required this.unit,
    required this.route,
    required this.frequency,
    required this.evidenceVersion,
    required this.validationStatus,
  });

  final String drugDocumentId;
  final String drugName;
  final PlantaoDrugRelationType relation;
  final String indication;
  final num dose;
  final String unit;
  final String route;
  final String frequency;
  final String evidenceVersion;
  final PlantaoDrugValidationStatus validationStatus;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'drugDocumentId': drugDocumentId,
      'drugName': drugName,
      'relation': relation.name,
      'indication': indication,
      'dose': dose,
      'unit': unit,
      'route': route,
      'frequency': frequency,
      'evidenceVersion': evidenceVersion,
      'validationStatus': validationStatus.name,
    };
  }

  factory PlantaoMedicationItem.fromJson(Map<String, Object?> json) {
    return PlantaoMedicationItem(
      drugDocumentId: json['drugDocumentId'] as String,
      drugName: json['drugName'] as String,
      relation: PlantaoDrugRelationType.values.firstWhere(
        (PlantaoDrugRelationType item) => item.name == json['relation'],
        orElse: () => throw FormatException(
          'Unknown PlantaoDrugRelationType: ${json['relation']}',
        ),
      ),
      indication: json['indication'] as String,
      dose: json['dose'] as num,
      unit: json['unit'] as String,
      route: json['route'] as String,
      frequency: json['frequency'] as String,
      evidenceVersion: json['evidenceVersion'] as String,
      validationStatus: PlantaoDrugValidationStatus.values.firstWhere(
        (PlantaoDrugValidationStatus item) =>
            item.name == json['validationStatus'],
        orElse: () => throw FormatException(
          'Unknown PlantaoDrugValidationStatus: '
          '${json['validationStatus']}',
        ),
      ),
    );
  }
}
