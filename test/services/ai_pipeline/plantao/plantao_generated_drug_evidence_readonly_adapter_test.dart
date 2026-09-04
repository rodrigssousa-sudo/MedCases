import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_generated_drug_evidence_readonly_adapter.dart';

const version = 'clinical-data-v1-test';
const bundleSha =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

String encode(Object? value) => jsonEncode(value);

Map<String, String> validFiles() {
  return <String, String>{
    'manifest.json': encode(<String, Object?>{
      'source': <String, Object?>{
        'bundleVersion': version,
        'bundleSha256': bundleSha,
        'identitySchema': 'clinical-source-content-v1',
        'drugCount': 1,
        'interactionCount': 0,
        'collisionCount': 0,
        'exportErrors': 0,
      },
      'projection': <String, Object?>{
        'typedRegimenCount': 0,
        'deterministicDosingPublishableCount': 0,
        'textToRegimenInferenceUsed': false,
      },
    }),
    'index.json': encode(<Object?>[
      <String, Object?>{
        'drugId': 'furosemida',
        'name': <String, Object?>{'pt': 'Furosemida', 'es': 'Furosemida'},
        'category': 'cardio',
        'keywords': <Object?>['furosemida'],
        'calculatorSchema': 'premium-v1',
        'sourceModule': 'cardio.js',
        'hasContextVariants': false,
        'contextVariantCount': 0,
        'canonicalOwner': 'cardio.js',
      },
    ]),
    'drugs/furosemida.json': encode(<String, Object?>{
      'drugId': 'furosemida',
      'typedRegimens': <Object?>[],
      'typedRegimenInferenceUsed': false,
      'publishableForDeterministicDosing': false,
      'sourceEvidence': <String, Object?>{
        'calculatorDocument': <String, Object?>{
          'id': 'furosemida',
          'category': 'cardio',
          'name': <String, Object?>{
            'pt': 'Furosemida',
            'es': 'Furosemida',
          },
          'keywords': <Object?>['furosemida'],
          'dataVersion': version,
          'clinicalContentSha256': bundleSha,
          'source': 'medcases-calculadora',
          'schema': 'premium-v1',
          'sourceModule': 'cardio.js',
          'pt': <String, Object?>{'dose': '20–40 mg'},
          'es': <String, Object?>{'dose': '20–40 mg'},
        },
      },
    }),
  };
}

void main() {
  test('loads generated envelope and returns canonical source document',
      () async {
    final files = validFiles();
    final requested = <String>[];
    final adapter = PlantaoGeneratedDrugEvidenceReadOnlyAdapter(
      loadJsonText: (path) async {
        requested.add(path);
        return files[path]!;
      },
    );

    final manifest = await adapter.loadManifest();
    final index = await adapter.loadIndex(manifest);
    final document = await adapter.loadDocument(
      documentId: index.single.documentId,
      manifest: manifest,
    );

    expect(document.documentId, 'furosemida');
    expect(document.raw.containsKey('aiRegimens'), isFalse);
    expect(document.supportsMedicationMaterialization, isFalse);
    expect(requested, <String>[
      'manifest.json',
      'index.json',
      'drugs/furosemida.json',
    ]);
  });

  test('rejects unsafe drug ID before loader access', () async {
    final files = validFiles();
    var calls = 0;
    final adapter = PlantaoGeneratedDrugEvidenceReadOnlyAdapter(
      loadJsonText: (path) async {
        calls += 1;
        return files[path]!;
      },
    );
    final manifest = await adapter.loadManifest();
    calls = 0;

    await expectLater(
      adapter.loadDocument(documentId: '../furosemida', manifest: manifest),
      throwsA(isA<FormatException>()),
    );
    expect(calls, 0);
  });

  test('rejects generated document with inferred typed regimen', () async {
    final files = validFiles();
    final invalid =
        jsonDecode(files['drugs/furosemida.json']!) as Map<String, Object?>;
    invalid['typedRegimenInferenceUsed'] = true;
    files['drugs/furosemida.json'] = encode(invalid);

    final adapter = PlantaoGeneratedDrugEvidenceReadOnlyAdapter(
      loadJsonText: (path) async => files[path]!,
    );
    final manifest = await adapter.loadManifest();

    await expectLater(
      adapter.loadDocument(documentId: 'furosemida', manifest: manifest),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects manifest that enables deterministic dosing', () async {
    final files = validFiles();
    final manifest =
        jsonDecode(files['manifest.json']!) as Map<String, Object?>;
    final projection = manifest['projection']! as Map<String, Object?>;
    projection['deterministicDosingPublishableCount'] = 1;
    files['manifest.json'] = encode(manifest);

    final adapter = PlantaoGeneratedDrugEvidenceReadOnlyAdapter(
      loadJsonText: (path) async => files[path]!,
    );

    await expectLater(adapter.loadManifest(), throwsA(isA<FormatException>()));
  });
}
