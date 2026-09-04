import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_drug_evidence_parity_shadow_comparator.dart';

const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

PlantaoDrugEvidenceManifest manifest({int drugCount = 1}) {
  return PlantaoDrugEvidenceManifest(
    version: 'v1',
    contentSha256: sha,
    identitySchema: 'clinical-source-content-v1',
    drugCount: drugCount,
    interactionCount: 0,
    collisionCount: 0,
    exportErrors: 0,
    endpoints: const <String, String>{
      'manifest': '/data/manifest.json',
      'drugsIndex': '/data/drugs-index.json',
      'drugById': '/data/drugs/{id}.json',
    },
  );
}

PlantaoDrugEvidenceIndexEntry entry(String id) {
  return PlantaoDrugEvidenceIndexEntry.fromJson(<String, Object?>{
    'id': id,
    'name': <String, Object?>{'pt': 'Furosemida', 'es': 'Furosemida'},
    'category': 'cardio',
    'keywords': <Object?>['furosemida'],
    'schema': 'premium-v1',
    'sourceModule': 'cardio.js',
    'hasContextVariants': false,
    'contextVariantCount': 0,
    'canonicalOwner': 'cardio.js',
  });
}

PlantaoCanonicalDrugEvidenceDocument document(String id) {
  return PlantaoCanonicalDrugEvidenceDocument.fromJson(
    <String, Object?>{
      'id': id,
      'name': <String, Object?>{'pt': 'Furosemida', 'es': 'Furosemida'},
      'category': 'cardio',
      'keywords': <Object?>['furosemida'],
      'dataVersion': 'v1',
      'clinicalContentSha256': sha,
      'source': 'medcases-calculadora',
      'schema': 'premium-v1',
      'sourceModule': 'cardio.js',
      'pt': <String, Object?>{'dose': '20–40 mg'},
      'es': <String, Object?>{'dose': '20–40 mg'},
    },
    manifest: manifest(),
  );
}

void main() {
  const comparator = PlantaoDrugEvidenceParityShadowComparator();

  test('reports exact parity for equivalent sources', () {
    final snapshot = comparator.compare(
      legacyManifest: manifest(),
      remoteManifest: manifest(),
      legacyIndex: <PlantaoDrugEvidenceIndexEntry>[entry('furosemida')],
      remoteIndex: <PlantaoDrugEvidenceIndexEntry>[entry('furosemida')],
      legacyDocuments: <String, PlantaoCanonicalDrugEvidenceDocument>{
        'furosemida': document('furosemida'),
      },
      remoteDocuments: <String, PlantaoCanonicalDrugEvidenceDocument>{
        'furosemida': document('furosemida'),
      },
    );

    expect(snapshot.isExactParity, isTrue);
    expect(snapshot.differences, isEmpty);
  });

  test('reports missing index identity', () {
    final snapshot = comparator.compare(
      legacyManifest: manifest(),
      remoteManifest: manifest(drugCount: 0),
      legacyIndex: <PlantaoDrugEvidenceIndexEntry>[entry('furosemida')],
      remoteIndex: const <PlantaoDrugEvidenceIndexEntry>[],
      legacyDocuments: const <String, PlantaoCanonicalDrugEvidenceDocument>{},
      remoteDocuments: const <String, PlantaoCanonicalDrugEvidenceDocument>{},
    );

    expect(snapshot.isExactParity, isFalse);
    expect(
      snapshot.differences.any(
        (difference) =>
            difference.scope == 'index:furosemida' &&
            difference.field == 'presence',
      ),
      isTrue,
    );
  });

  test('reports canonical document difference', () {
    final changed = PlantaoCanonicalDrugEvidenceDocument.fromJson(
      <String, Object?>{
        ...document('furosemida').raw,
        'category': 'changed',
      },
      manifest: manifest(),
    );

    final snapshot = comparator.compare(
      legacyManifest: manifest(),
      remoteManifest: manifest(),
      legacyIndex: <PlantaoDrugEvidenceIndexEntry>[entry('furosemida')],
      remoteIndex: <PlantaoDrugEvidenceIndexEntry>[entry('furosemida')],
      legacyDocuments: <String, PlantaoCanonicalDrugEvidenceDocument>{
        'furosemida': document('furosemida'),
      },
      remoteDocuments: <String, PlantaoCanonicalDrugEvidenceDocument>{
        'furosemida': changed,
      },
    );

    expect(
      snapshot.differences.any(
        (difference) =>
            difference.scope == 'document:furosemida' &&
            difference.field == 'canonicalRawEvidence',
      ),
      isTrue,
    );
  });
}
