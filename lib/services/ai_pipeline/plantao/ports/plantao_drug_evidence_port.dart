import '../contracts/plantao_canonical_drug_evidence.dart';

abstract class PlantaoDrugEvidencePort {
  static const bool productiveConnectionEnabled = false;
  static const bool providerGroundingEnabled = false;
  static const bool promptMutationEnabled = false;
  static const bool renderingEnabled = false;
  static const bool persistenceEnabled = false;

  Future<PlantaoDrugEvidenceManifest> loadManifest();

  Future<List<PlantaoDrugEvidenceIndexEntry>> loadIndex(
    PlantaoDrugEvidenceManifest manifest,
  );

  Future<PlantaoCanonicalDrugEvidenceDocument> loadDocument({
    required String documentId,
    required PlantaoDrugEvidenceManifest manifest,
  });
}
