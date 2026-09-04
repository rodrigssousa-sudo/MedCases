import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/ports/plantao_drug_evidence_port.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_request_observer.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_shadow_adapter.dart';

const version = 'clinical-data-v1-observer-test';
const bundleSha =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

class CountingDrugPort implements PlantaoDrugEvidencePort {
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
    indexLoads += 1;
    return <PlantaoDrugEvidenceIndexEntry>[
      PlantaoDrugEvidenceIndexEntry(
        documentId: 'furosemida',
        names: const <String, String>{'pt': 'Furosemida', 'es': 'Furosemida'},
        category: 'cardio',
        keywords: const <String>['furosemida', 'lasix'],
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
      'keywords': <Object?>['furosemida', 'lasix'],
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
  test('non-pharmacology request performs no evidence-port work', () async {
    final port = CountingDrugPort();
    final observer = PlantaoDrugEvidenceRequestObserver(
      adapter: PlantaoDrugEvidenceShadowAdapter(port: port),
    );

    final snapshot = await observer.observe(
      originalUserInput:
          'Paciente com dispneia progressiva e edema de membros inferiores',
      languageCode: 'pt',
      legacyQueryIntent: 'caso_clinico',
      legacyDirectQuery: false,
    );

    expect(snapshot.status, PlantaoDrugEvidenceShadowStatus.notEvaluated);
    expect(port.manifestLoads, 0);
    expect(port.indexLoads, 0);
    expect(port.documentLoads, 0);
  });

  test(
    'direct canonical name retrieves evidence from the original input',
    () async {
      final port = CountingDrugPort();
      final observer = PlantaoDrugEvidenceRequestObserver(
        adapter: PlantaoDrugEvidenceShadowAdapter(port: port),
      );

      final snapshot = await observer.observe(
        originalUserInput: 'furosemida',
        languageCode: 'pt',
        legacyQueryIntent: 'geral',
        legacyDirectQuery: false,
      );

      expect(snapshot.status, PlantaoDrugEvidenceShadowStatus.complete);
      expect(snapshot.candidates.single.documentId, 'furosemida');
      expect(snapshot.documents.single.documentId, 'furosemida');
      expect(port.manifestLoads, greaterThanOrEqualTo(1));
      expect(port.documentLoads, 1);
    },
  );

  test(
    'observer never materializes medication from raw clinical text',
    () async {
      final port = CountingDrugPort();
      final observer = PlantaoDrugEvidenceRequestObserver(
        adapter: PlantaoDrugEvidenceShadowAdapter(port: port),
      );

      final snapshot = await observer.observe(
        originalUserInput: 'Qual a dose da furosemida?',
        languageCode: 'pt',
        legacyQueryIntent: 'farmaco',
        legacyDirectQuery: true,
      );

      expect(
        snapshot.documents.single.supportsMedicationMaterialization,
        isFalse,
      );
      expect(snapshot.reasons, contains(contains('typed_regimen_unavailable')));
    },
  );
}
