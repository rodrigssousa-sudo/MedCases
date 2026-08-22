import 'plantao_drug_relation.dart';
import 'plantao_section.dart';

class PlantaoResponseSection {
  const PlantaoResponseSection({required this.section, required this.content});

  final PlantaoSection section;
  final String content;

  Map<String, Object?> toJson() {
    return <String, Object?>{'section': section.name, 'content': content};
  }

  factory PlantaoResponseSection.fromJson(Map<String, Object?> json) {
    return PlantaoResponseSection(
      section: plantaoSectionFromWire(json['section'] as String),
      content: json['content'] as String,
    );
  }
}

class PlantaoResponseStructure {
  PlantaoResponseStructure({
    required Iterable<PlantaoResponseSection> sections,
    required Iterable<PlantaoMedicationItem> medications,
  }) : sections = List<PlantaoResponseSection>.unmodifiable(sections),
       medications = List<PlantaoMedicationItem>.unmodifiable(medications);

  final List<PlantaoResponseSection> sections;
  final List<PlantaoMedicationItem> medications;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'sections': sections
          .map((PlantaoResponseSection item) => item.toJson())
          .toList(growable: false),
      'medications': medications
          .map((PlantaoMedicationItem item) => item.toJson())
          .toList(growable: false),
    };
  }

  factory PlantaoResponseStructure.fromJson(Map<String, Object?> json) {
    final Object? rawSections = json['sections'];
    final Object? rawMedications = json['medications'];

    if (rawSections is! List<Object?> || rawMedications is! List<Object?>) {
      throw const FormatException('sections and medications must be lists');
    }

    return PlantaoResponseStructure(
      sections: rawSections.map(
        (Object? item) => PlantaoResponseSection.fromJson(_objectMap(item)),
      ),
      medications: rawMedications.map(
        (Object? item) => PlantaoMedicationItem.fromJson(_objectMap(item)),
      ),
    );
  }
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected an object map');
  }
  return value.map(
    (Object? key, Object? item) =>
        MapEntry<String, Object?>(key as String, item),
  );
}
