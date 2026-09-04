import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_canonical_drug_evidence.dart';

const version = 'clinical-data-v1-test';
const bundleSha =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

PlantaoDrugEvidenceManifest manifest() {
  return PlantaoDrugEvidenceManifest.fromJson(<String, Object?>{
    'version': version,
    'contentSha256': bundleSha,
    'identitySchema': 'clinical-source-content-v1',
    'drugCount': 2,
    'interactionCount': 10,
    'collisionCount': 1,
    'exportErrors': 0,
    'endpoints': <String, Object?>{
      'manifest': '/data/manifest.json',
      'drugsIndex': '/data/drugs_index.json',
      'drugById': '/data/drugs/{id}.json',
    },
  });
}

void main() {
  test('manifest preserves version, bundle SHA and endpoints', () {
    final value = manifest();
    expect(value.version, version);
    expect(value.contentSha256, bundleSha);
    expect(value.documentEndpointTemplate, contains('{id}'));
  });

  test('premium raw document is rich but not dosage-materializable', () {
    final document = PlantaoCanonicalDrugEvidenceDocument.fromJson(
      <String, Object?>{
        'id': 'furosemida',
        'category': 'cardio',
        'name': <String, Object?>{'pt': 'Furosemida', 'es': 'Furosemida'},
        'keywords': <Object?>['furosemida'],
        'dataVersion': version,
        'clinicalContentSha256': bundleSha,
        'source': 'medcases-calculadora',
        'schema': 'premium-v1',
        'sourceModule': 'cardio.js',
        'pt': <String, Object?>{
          'dose': <String, Object?>{'adultoPadrao': '20–40 mg VO'},
          'presentation': <Object?>['Comprimido 40 mg'],
          'alerts': <Object?>['Monitorar eletrólitos'],
        },
        'es': <String, Object?>{
          'dose': <String, Object?>{'adultoPadrao': '20–40 mg VO'},
          'presentation': <Object?>['Comprimido 40 mg'],
          'alerts': <Object?>['Monitorizar electrolitos'],
        },
      },
      manifest: manifest(),
    );

    expect(document.completeness, PlantaoDrugEvidenceCompleteness.richClinical);
    expect(document.supportsMedicationMaterialization, isFalse);
    expect(document.hasTypedRegimens, isFalse);
  });

  test('explicit typed regimen is the only materialization gate', () {
    final document = PlantaoCanonicalDrugEvidenceDocument.fromJson(
      <String, Object?>{
        'id': 'teste',
        'category': 'teste',
        'name': <String, Object?>{'pt': 'Teste', 'es': 'Prueba'},
        'keywords': <Object?>['teste'],
        'dataVersion': version,
        'clinicalContentSha256': bundleSha,
        'source': 'medcases-calculadora',
        'schema': 'premium-v1',
        'sourceModule': 'teste.js',
        'pt': <String, Object?>{'dose': '10 mg'},
        'es': <String, Object?>{'dose': '10 mg'},
        'aiRegimens': <Object?>[
          <String, Object?>{
            'dose': 10,
            'unit': 'mg',
            'route': 'VO',
            'frequency': '1x/dia',
          },
        ],
      },
      manifest: manifest(),
    );

    expect(document.hasTypedRegimens, isTrue);
    expect(document.supportsMedicationMaterialization, isTrue);
  });
}
