import '../contracts/plantao_drug_relation.dart';
import '../contracts/plantao_evidence_bundle.dart';

enum PlantaoDeterministicValidationStatus {
  notEvaluated,
  validated,
  incompleteEvidence,
  blocked,
}

class PlantaoMedicationCandidate {
  const PlantaoMedicationCandidate({
    required this.drugName,
    required this.relation,
    required this.indication,
    required this.dose,
    required this.unit,
    required this.route,
    required this.frequency,
  });

  final String drugName;
  final PlantaoDrugRelationType relation;
  final String indication;
  final num dose;
  final String unit;
  final String route;
  final String frequency;
}

class PlantaoDeterministicValidationOutcome {
  PlantaoDeterministicValidationOutcome({
    required this.status,
    required Iterable<PlantaoMedicationItem> medications,
    required Iterable<String> reasons,
    required Iterable<String> matchedDrugDocumentIds,
  })  : medications = List<PlantaoMedicationItem>.unmodifiable(medications),
        reasons = List<String>.unmodifiable(reasons),
        matchedDrugDocumentIds =
            List<String>.unmodifiable(matchedDrugDocumentIds);

  final PlantaoDeterministicValidationStatus status;
  final List<PlantaoMedicationItem> medications;
  final List<String> reasons;
  final List<String> matchedDrugDocumentIds;

  bool get validatedDose =>
      status == PlantaoDeterministicValidationStatus.validated &&
      medications.isNotEmpty;
}

abstract final class PlantaoDeterministicDrugValidator {
  static PlantaoDeterministicValidationOutcome validate({
    required Iterable<PlantaoMedicationCandidate> candidates,
    required PlantaoEvidenceBundle evidenceBundle,
  }) {
    final candidateList =
        List<PlantaoMedicationCandidate>.unmodifiable(candidates);
    if (candidateList.isEmpty) {
      return PlantaoDeterministicValidationOutcome(
        status: PlantaoDeterministicValidationStatus.notEvaluated,
        medications: const <PlantaoMedicationItem>[],
        reasons: const <String>['typed_medication_candidates_absent'],
        matchedDrugDocumentIds: const <String>[],
      );
    }

    if (!evidenceBundle.hasDeterministicDrugEvidence) {
      return PlantaoDeterministicValidationOutcome(
        status: PlantaoDeterministicValidationStatus.incompleteEvidence,
        medications: const <PlantaoMedicationItem>[],
        reasons: const <String>['deterministic_drug_evidence_absent'],
        matchedDrugDocumentIds: const <String>[],
      );
    }

    final validated = <PlantaoMedicationItem>[];
    final matchedDocumentIds = <String>[];
    final failures = <String>[];

    for (final candidate in candidateList) {
      final namedDocuments = evidenceBundle.drugDocuments
          .where(
            (document) =>
                _normalize(document.drugName) ==
                _normalize(candidate.drugName),
          )
          .toList(growable: false);

      if (namedDocuments.isEmpty) {
        failures.add('drug_document_missing:${candidate.drugName}');
        continue;
      }

      PlantaoDrugEvidenceDocument? exact;
      for (final document in namedDocuments) {
        if (_sameDose(candidate.dose, document.dose) &&
            _normalize(candidate.unit) == _normalize(document.unit) &&
            _normalize(candidate.route) == _normalize(document.route) &&
            _normalize(candidate.frequency) ==
                _normalize(document.frequency)) {
          exact = document;
          break;
        }
      }

      if (exact == null) {
        failures.add('dose_route_frequency_mismatch:${candidate.drugName}');
        continue;
      }

      validated.add(
        PlantaoMedicationItem(
          drugDocumentId: exact.documentId,
          drugName: exact.drugName,
          relation: candidate.relation,
          indication: candidate.indication,
          dose: exact.dose,
          unit: exact.unit,
          route: exact.route,
          frequency: exact.frequency,
          evidenceVersion: exact.version,
          validationStatus: PlantaoDrugValidationStatus.validated,
        ),
      );
      matchedDocumentIds.add(exact.documentId);
    }

    if (failures.isNotEmpty) {
      return PlantaoDeterministicValidationOutcome(
        status: PlantaoDeterministicValidationStatus.blocked,
        medications: const <PlantaoMedicationItem>[],
        reasons: failures,
        matchedDrugDocumentIds: matchedDocumentIds,
      );
    }

    return PlantaoDeterministicValidationOutcome(
      status: PlantaoDeterministicValidationStatus.validated,
      medications: validated,
      reasons: const <String>['all_medication_fields_match_evidence'],
      matchedDrugDocumentIds: matchedDocumentIds,
    );
  }

  static bool _sameDose(num candidate, num evidence) {
    return (candidate.toDouble() - evidence.toDouble()).abs() <= 0.000000001;
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('\t', ' ')
        .replaceAll('  ', ' ')
        .replaceAll('  ', ' ');
  }
}
