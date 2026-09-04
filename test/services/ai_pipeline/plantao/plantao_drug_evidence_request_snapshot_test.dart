import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/ports/plantao_drug_evidence_port.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_request_observer.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_shadow_adapter.dart';

const version = 'clinical-data-v1-request-snapshot-test';
const bundleSha =
    '1111111111111111111111111111111111111111111111111111111111111111';

class SingleDrugPort implements PlantaoDrugEvidencePort {
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
      'pt': <String, Object?>{'dose': '20–40 mg'},
      'es': <String, Object?>{'dose': '20–40 mg'},
    }, manifest: manifest);
  }
}

void main() {
  test('request snapshot binds evidence to the original request ID', () async {
    final observer = PlantaoDrugEvidenceRequestObserver(
      adapter: PlantaoDrugEvidenceShadowAdapter(port: SingleDrugPort()),
    );

    final snapshot = await observer.observeRequest(
      requestId: 'req-drug-1',
      originalUserInput: 'Qual a dose da furosemida?',
      languageCode: 'pt',
      legacyQueryIntent: 'farmaco',
      legacyDirectQuery: true,
    );

    expect(snapshot.requestId, 'req-drug-1');
    expect(snapshot.status, PlantaoDrugEvidenceRequestStatus.ready);
    expect(snapshot.evidence.documents.single.documentId, 'furosemida');
    expect(snapshot.hasCanonicalEvidence, isTrue);
    expect(
      PlantaoDrugEvidenceRequestSnapshot.originalUserInputPersisted,
      isFalse,
    );
  });

  test(
    'empty request ID fails closed without storing original input',
    () async {
      final observer = PlantaoDrugEvidenceRequestObserver(
        adapter: PlantaoDrugEvidenceShadowAdapter(port: SingleDrugPort()),
      );

      final snapshot = await observer.observeRequest(
        requestId: '   ',
        originalUserInput: 'furosemida',
        languageCode: 'pt',
        legacyQueryIntent: 'farmaco',
        legacyDirectQuery: true,
      );

      expect(snapshot.status, PlantaoDrugEvidenceRequestStatus.failed);
      expect(snapshot.requestId, isEmpty);
      expect(snapshot.reasons, contains('drug_evidence_request_id_empty'));
    },
  );
}
