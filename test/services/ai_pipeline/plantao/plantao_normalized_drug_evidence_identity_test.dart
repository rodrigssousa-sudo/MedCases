import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_normalized_drug_evidence_identity.dart';

Map<String, Object?> legacy() => <String, Object?>{
      'id': 'furosemida',
      'name': <String, Object?>{
        'pt': 'Furosemida',
        'es': 'Furosemida',
      },
      'category': 'cardio',
      'keywords': <Object?>['diurético', 'furosemida'],
      'schema': 'premium-v1',
      'sourceModule': 'cardio.js',
      'hasContextVariants': false,
      'contextVariantCount': 0,
      'canonicalOwner': 'cardio.js',
    };

Map<String, Object?> remote() => <String, Object?>{
      'drugId': 'furosemida',
      'name': <String, Object?>{
        'pt': 'Furosemida',
        'es': 'Furosemida',
      },
      'category': 'cardio',
      'keywords': <Object?>['furosemida', 'diurético'],
      'calculatorSchema': 'premium-v1',
      'sourceModule': 'cardio.js',
      'hasContextVariants': false,
      'contextVariantCount': 0,
      'canonicalOwner': 'cardio.js',
    };

void main() {
  test('normalizes legacy and remote index schemas to exact parity', () {
    final legacyIdentity =
        PlantaoNormalizedDrugEvidenceIdentity.fromLegacyIndex(legacy());
    final remoteIdentity =
        PlantaoNormalizedDrugEvidenceIdentity.fromRemoteIndex(remote());

    expect(legacyIdentity, remoteIdentity);
    expect(legacyIdentity.drugId, 'furosemida');
  });

  test('sorts and deduplicates keywords', () {
    final value = remote();
    value['keywords'] = <Object?>[
      'furosemida',
      'diurético',
      'furosemida',
    ];

    final identity =
        PlantaoNormalizedDrugEvidenceIdentity.fromRemoteIndex(value);

    expect(identity.keywords, <String>['diurético', 'furosemida']);
  });

  test('rejects missing canonical identity', () {
    final value = remote()..remove('drugId');

    expect(
      () => PlantaoNormalizedDrugEvidenceIdentity.fromRemoteIndex(value),
      throwsA(isA<FormatException>()),
    );
  });
}
