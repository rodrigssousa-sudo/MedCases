import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_generated_drug_evidence_readonly_adapter.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_versioned_remote_drug_evidence_json_loader.dart';

const bundleId = 'clinical-data-v1-test';
const bundleSha =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, Object?> currentJson({
  String? manifestPath,
  int typedRegimenCount = 0,
}) {
  return <String, Object?>{
    'schemaVersion': 'medcases-ai-drug-data-current-v1',
    'bundleId': bundleId,
    'bundleVersion': bundleId,
    'bundleSha256': bundleSha,
    'manifestPath': manifestPath ?? 'bundles/$bundleId/manifest.json',
    'indexPath': 'bundles/$bundleId/index.json',
    'drugPathTemplate': 'bundles/$bundleId/drugs/{id}.json',
    'drugCount': 1,
    'typedRegimenCount': typedRegimenCount,
    'deterministicDosingPublishableCount': 0,
    'textToRegimenInferenceUsed': false,
  };
}

void main() {
  test('resolves current pointer and immutable bundle paths', () async {
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.path);
      return switch (request.url.path) {
        '/data/ai-drug-data/current.json' => http.Response(
            jsonEncode(currentJson()),
            200,
          ),
        '/data/ai-drug-data/bundles/$bundleId/manifest.json' =>
          http.Response('{"source":{},"projection":{}}', 200),
        '/data/ai-drug-data/bundles/$bundleId/index.json' =>
          http.Response('[]', 200),
        '/data/ai-drug-data/bundles/$bundleId/drugs/furosemida.json' =>
          http.Response('{"drugId":"furosemida"}', 200),
        _ => http.Response('not found', 404),
      };
    });

    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
      baseUri: Uri.parse(
        'https://medcasescalcu.com/data/ai-drug-data/',
      ),
    );

    await loader.loadJsonText('manifest.json');
    await loader.loadJsonText('index.json');
    await loader.loadJsonText('drugs/furosemida.json');

    expect(
      requested,
      <String>[
        '/data/ai-drug-data/current.json',
        '/data/ai-drug-data/bundles/$bundleId/manifest.json',
        '/data/ai-drug-data/bundles/$bundleId/index.json',
        '/data/ai-drug-data/bundles/$bundleId/drugs/furosemida.json',
      ],
    );
  });

  test('rejects current pointer that escapes immutable bundle', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(
          currentJson(manifestPath: '../manifest.json'),
        ),
        200,
      );
    });
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
    );

    await expectLater(
      loader.loadJsonText('manifest.json'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects current pointer that enables typed regimen', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode(currentJson(typedRegimenCount: 1)),
        200,
      );
    });
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
    );

    await expectLater(
      loader.loadJsonText('manifest.json'),
      throwsA(isA<FormatException>()),
    );
  });

  test('integrates with generated read-only adapter', () async {
    final client = MockClient((request) async {
      return switch (request.url.path) {
        '/data/ai-drug-data/current.json' => http.Response(
            jsonEncode(currentJson()),
            200,
          ),
        '/data/ai-drug-data/bundles/$bundleId/manifest.json' => http.Response(
            jsonEncode(<String, Object?>{
              'source': <String, Object?>{
                'bundleVersion': bundleId,
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
            200,
          ),
        '/data/ai-drug-data/bundles/$bundleId/index.json' => http.Response(
            jsonEncode(<Object?>[
              <String, Object?>{
                'drugId': 'furosemida',
                'name': <String, Object?>{
                  'pt': 'Furosemida',
                  'es': 'Furosemida',
                },
                'category': 'cardio',
                'keywords': <Object?>['furosemida'],
                'calculatorSchema': 'premium-v1',
                'sourceModule': 'cardio.js',
                'hasContextVariants': false,
                'contextVariantCount': 0,
                'canonicalOwner': 'cardio.js',
              },
            ]),
            200,
          ),
        '/data/ai-drug-data/bundles/$bundleId/drugs/furosemida.json' =>
          http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, Object?>{
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
                    'dataVersion': bundleId,
                    'clinicalContentSha256': bundleSha,
                    'source': 'medcases-calculadora',
                    'schema': 'premium-v1',
                    'sourceModule': 'cardio.js',
                    'pt': <String, Object?>{'dose': '20–40 mg'},
                    'es': <String, Object?>{'dose': '20–40 mg'},
                  },
                },
              }),
            ),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          ),
        _ => http.Response('not found', 404),
      };
    });

    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
    );
    final adapter = PlantaoGeneratedDrugEvidenceReadOnlyAdapter(
      loadJsonText: loader.loadJsonText,
    );

    final manifest = await adapter.loadManifest();
    final index = await adapter.loadIndex(manifest);
    final document = await adapter.loadDocument(
      documentId: index.single.documentId,
      manifest: manifest,
    );

    expect(document.documentId, 'furosemida');
    expect(document.supportsMedicationMaterialization, isFalse);
  });
}
