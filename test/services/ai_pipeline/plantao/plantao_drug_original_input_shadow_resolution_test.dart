import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/ports/plantao_drug_evidence_port.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_shadow_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_original_input_identity_extractor.dart';

const version = 'clinical-data-v1-test';
const bundleSha =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

class CountingPort implements PlantaoDrugEvidencePort {
  int manifestLoads = 0;
  int indexLoads = 0;
  int documentLoads = 0;

  @override
  Future<PlantaoDrugEvidenceManifest> loadManifest() async {
    manifestLoads += 1;
    return PlantaoDrugEvidenceManifest.fromJson(<String, Object?>{
      'version': version,
      'contentSha256': bundleSha,
      'identitySchema': 'clinical-source-content-v1',
      'drugCount': 2,
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
    indexLoads += 1;
    return <PlantaoDrugEvidenceIndexEntry>[
      for (final id in <String>['furosemida', 'espironolactona'])
        PlantaoDrugEvidenceIndexEntry(
          documentId: id,
          names: <String, String>{
            'pt': id == 'furosemida' ? 'Furosemida' : 'Espironolactona',
            'es': id == 'furosemida' ? 'Furosemida' : 'Espironolactona',
          },
          category: 'cardio',
          keywords: <String>[id],
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
      'name': <String, Object?>{
        'pt': documentId == 'furosemida' ? 'Furosemida' : 'Espironolactona',
        'es': documentId == 'furosemida' ? 'Furosemida' : 'Espironolactona',
      },
      'keywords': <Object?>[documentId],
      'dataVersion': version,
      'clinicalContentSha256': bundleSha,
      'source': 'medcases-calculadora',
      'schema': 'premium-v1',
      'sourceModule': 'cardio.js',
      'pt': <String, Object?>{'dose': 'texto clínico não tipado'},
      'es': <String, Object?>{'dose': 'texto clínico no tipado'},
    }, manifest: manifest);
  }
}

void main() {
  test('intent none performs no canonical network-port work', () async {
    final port = CountingPort();
    final adapter = PlantaoDrugEvidenceShadowAdapter(port: port);

    final snapshot = await adapter.retrieveOriginalUserInput(
      originalUserInput: 'Paciente usa furosemida. Analise o caso.',
      languageCode: 'pt',
      intent: PlantaoDrugOriginalInputIntent.none,
    );

    expect(snapshot.status, PlantaoDrugEvidenceShadowStatus.notEvaluated);
    expect(port.manifestLoads, 0);
    expect(port.indexLoads, 0);
    expect(port.documentLoads, 0);
  });

  test(
    'explicit dosage query retrieves canonical evidence from original input',
    () async {
      final port = CountingPort();
      final adapter = PlantaoDrugEvidenceShadowAdapter(port: port);

      final snapshot = await adapter.retrieveOriginalUserInput(
        originalUserInput: 'Qual a dose da furosemida?',
        languageCode: 'pt',
        intent: PlantaoDrugOriginalInputIntent.dosage,
      );

      expect(snapshot.status, PlantaoDrugEvidenceShadowStatus.complete);
      expect(snapshot.candidates.single.documentId, 'furosemida');
      expect(snapshot.documents.single.documentId, 'furosemida');
      expect(
        snapshot.documents.single.supportsMedicationMaterialization,
        isFalse,
      );
    },
  );

  test('interaction query retrieves exactly two canonical documents', () async {
    final port = CountingPort();
    final adapter = PlantaoDrugEvidenceShadowAdapter(port: port);

    final snapshot = await adapter.retrieveOriginalUserInput(
      originalUserInput: 'Existe interação entre furosemida e espironolactona?',
      languageCode: 'pt',
      intent: PlantaoDrugOriginalInputIntent.interaction,
    );

    expect(snapshot.status, PlantaoDrugEvidenceShadowStatus.complete);
    expect(snapshot.candidates, hasLength(2));
    expect(snapshot.documents, hasLength(2));
  });
}
