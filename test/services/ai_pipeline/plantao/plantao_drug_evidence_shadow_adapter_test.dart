import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/ports/plantao_drug_evidence_port.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_shadow_adapter.dart';

const version = 'clinical-data-v1-test';
const bundleSha =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

class FakeDrugEvidencePort implements PlantaoDrugEvidencePort {
  int documentLoads = 0;

  @override
  Future<PlantaoDrugEvidenceManifest> loadManifest() async {
    return PlantaoDrugEvidenceManifest.fromJson(<String, Object?>{
      'version': version,
      'contentSha256': bundleSha,
      'identitySchema': 'clinical-source-content-v1',
      'drugCount': 1,
      'interactionCount': 0,
      'collisionCount': 0,
      'exportErrors': 0,
      'endpoints': <String, Object?>{
        'manifest': '/data/manifest.json',
        'drugsIndex': '/data/drugs_index.json',
        'drugById': '/data/drugs/{id}.json',
      },
    });
  }

  @override
  Future<List<PlantaoDrugEvidenceIndexEntry>> loadIndex(
    PlantaoDrugEvidenceManifest manifest,
  ) async {
    return <PlantaoDrugEvidenceIndexEntry>[
      PlantaoDrugEvidenceIndexEntry(
        documentId: 'furosemida',
        names: const <String, String>{'pt': 'Furosemida', 'es': 'Furosemida'},
        category: 'cardio',
        keywords: const <String>['furosemida'],
        schema: PlantaoCanonicalDrugSchema.premiumV1,
        sourceModule: 'cardio.js',
        hasContextVariants: false,
        contextVariantCount: 0,
        canonicalOwner: 'cardio.js',
      ),
    ];
  }

  @override
  Future<PlantaoCanonicalDrugEvidenceDocument> loadDocument({
    required String documentId,
    required PlantaoDrugEvidenceManifest manifest,
  }) async {
    documentLoads += 1;
    return PlantaoCanonicalDrugEvidenceDocument.fromJson(<String, Object?>{
      'id': documentId,
      'category': 'cardio',
      'name': <String, Object?>{'pt': 'Furosemida', 'es': 'Furosemida'},
      'keywords': <Object?>['furosemida'],
      'dataVersion': version,
      'clinicalContentSha256': bundleSha,
      'source': 'medcases-calculadora',
      'schema': 'premium-v1',
      'sourceModule': 'cardio.js',
      'pt': <String, Object?>{'dose': '20–40 mg VO'},
      'es': <String, Object?>{'dose': '20–40 mg VO'},
    }, manifest: manifest);
  }
}

void main() {
  test(
    'typed identity term retrieves canonical raw evidence in shadow',
    () async {
      final port = FakeDrugEvidencePort();
      final adapter = PlantaoDrugEvidenceShadowAdapter(port: port);
      final snapshot = await adapter.retrieveTypedTerms(
        terms: const <String>['furosemida'],
        languageCode: 'pt',
      );

      expect(snapshot.status, PlantaoDrugEvidenceShadowStatus.complete);
      expect(snapshot.candidates.single.documentId, 'furosemida');
      expect(snapshot.documents.single.documentId, 'furosemida');
      expect(
        snapshot.documents.single.supportsMedicationMaterialization,
        isFalse,
      );
      expect(
        snapshot.reasons.any(
          (reason) => reason.contains('typed_regimen_unavailable'),
        ),
        isTrue,
      );
      expect(port.documentLoads, 1);
    },
  );

  test('free sentence is not parsed and does not load a document', () async {
    final port = FakeDrugEvidencePort();
    final adapter = PlantaoDrugEvidenceShadowAdapter(port: port);
    final snapshot = await adapter.retrieveTypedTerms(
      terms: const <String>['qual a dose de furosemida'],
      languageCode: 'pt',
    );

    expect(snapshot.status, PlantaoDrugEvidenceShadowStatus.empty);
    expect(snapshot.documents, isEmpty);
    expect(port.documentLoads, 0);
  });

  test('empty typed terms do not perform retrieval', () async {
    final port = FakeDrugEvidencePort();
    final adapter = PlantaoDrugEvidenceShadowAdapter(port: port);
    final snapshot = await adapter.retrieveTypedTerms(
      terms: const <String>[],
      languageCode: 'pt',
    );

    expect(snapshot.status, PlantaoDrugEvidenceShadowStatus.notEvaluated);
    expect(snapshot.manifest, isNull);
    expect(port.documentLoads, 0);
  });
}
