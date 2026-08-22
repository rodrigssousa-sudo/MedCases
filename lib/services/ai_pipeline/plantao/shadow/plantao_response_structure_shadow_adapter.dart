import '../../../../models/clinical_structured_output.dart';
import '../../ai_response_structure_parser.dart';
import '../contracts/plantao_request.dart';
import '../contracts/plantao_response_structure.dart';
import '../contracts/plantao_section.dart';

class PlantaoResponseStructureShadowOutcome {
  PlantaoResponseStructureShadowOutcome({
    required this.structure,
    required this.usedPlantaoParser,
    required this.usedClinicalOutput,
    required this.deferredMedicationCount,
    required Iterable<PlantaoSection> missingRequestedSections,
  }) : missingRequestedSections =
           List<PlantaoSection>.unmodifiable(missingRequestedSections);

  final PlantaoResponseStructure structure;
  final bool usedPlantaoParser;
  final bool usedClinicalOutput;
  final int deferredMedicationCount;
  final List<PlantaoSection> missingRequestedSections;

  bool get hasSections => structure.sections.isNotEmpty;
}

/// Converts only already-typed parser output into the Phase 3 structure.
/// It does not parse doses and deliberately leaves medications empty until the
/// deterministic validation phase can attach document IDs and validated fields.
abstract final class PlantaoResponseStructureShadowAdapter {
  static PlantaoResponseStructureShadowOutcome build({
    required PlantaoRequest request,
    required AiResponseStructureOutcome parsed,
    ClinicalStructuredOutput? clinicalOutput,
  }) {
    final buckets = <PlantaoSection, List<String>>{};

    void add(PlantaoSection section, String? value, {String prefix = ''}) {
      final normalized = value?.trim() ?? '';
      if (normalized.isEmpty) return;
      final content = prefix.isEmpty ? normalized : '$prefix$normalized';
      final target = buckets.putIfAbsent(section, () => <String>[]);
      if (!target.contains(content)) target.add(content);
    }

    final plantao = parsed.plantaoResponse;
    if (plantao != null) {
      add(PlantaoSection.summary, plantao.conduta);
      add(PlantaoSection.firstLine, plantao.primeiraLinha);
      add(
        PlantaoSection.fullTreatment,
        plantao.alternativa,
        prefix: 'Alternativa: ',
      );
      add(
        PlantaoSection.immediateActions,
        plantao.evitar,
        prefix: 'Evitar: ',
      );
      add(PlantaoSection.monitoring, plantao.monitorar);
      add(PlantaoSection.worseningCriteria, plantao.alerta);
      add(PlantaoSection.responseCriteria, plantao.metas);
      add(PlantaoSection.evolution, plantao.proxPasso);
    }

    final clinical = clinicalOutput ?? parsed.clinicalOutput;
    if (clinical != null) {
      add(PlantaoSection.summary, clinical.diagnosticoHeuristico);
      add(PlantaoSection.immediateActions, clinical.condutaImediata);
      for (final item in clinical.condutaImediataItens) {
        add(PlantaoSection.immediateActions, item);
      }
      for (final item in clinical.primeiraLinha) {
        add(
          PlantaoSection.firstLine,
          '${item.farmaco} ${item.posologia}',
        );
      }
      for (final item in clinical.segundaLinha) {
        add(
          PlantaoSection.secondLine,
          '${item.farmaco} ${item.posologia}',
        );
      }
      for (final item in clinical.prescricao) {
        add(
          PlantaoSection.fullTreatment,
          '${item.farmaco} ${item.posologia}',
        );
      }
      for (final item in clinical.pontosChave) {
        add(PlantaoSection.responseCriteria, item);
      }
      for (final item in clinical.hardStops) {
        add(PlantaoSection.worseningCriteria, item);
      }
    }

    final treatmentText = <String>{
      ...?buckets[PlantaoSection.firstLine],
      ...?buckets[PlantaoSection.secondLine],
      ...?buckets[PlantaoSection.fullTreatment],
    }.join('\n');
    if (treatmentText.isNotEmpty) {
      add(PlantaoSection.dosageClarification, treatmentText);
    }

    final requested = request.requestedSections.toSet();
    bool isAllowed(PlantaoSection section) {
      if (requested.isEmpty) return true;
      return requested.contains(section);
    }

    final entries = buckets.entries
        .where((entry) => isAllowed(entry.key))
        .toList()
      ..sort((a, b) => a.key.index.compareTo(b.key.index));

    final sections = entries
        .map(
          (entry) => PlantaoResponseSection(
            section: entry.key,
            content: entry.value.join('\n'),
          ),
        )
        .toList(growable: false);

    final produced = sections.map((item) => item.section).toSet();
    final missing = requested.difference(produced).toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return PlantaoResponseStructureShadowOutcome(
      structure: PlantaoResponseStructure(
        sections: sections,
        medications: const [],
      ),
      usedPlantaoParser: plantao != null,
      usedClinicalOutput: clinical != null,
      deferredMedicationCount: clinical?.prescricao.length ?? 0,
      missingRequestedSections: missing,
    );
  }
}
