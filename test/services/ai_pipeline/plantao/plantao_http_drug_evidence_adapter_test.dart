import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_http_drug_evidence_adapter.dart';

const version = 'clinical-data-v1-test';
const bundleSha =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

http.Response jsonResponse(Object? value, {int statusCode = 200}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(value)),
    statusCode,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}

void main() {
  test(
    'HTTP adapter loads manifest, index and exact document without auth',
    () async {
      final requestedPaths = <String>[];
      final client = MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.headers.containsKey('Authorization'), isFalse);
        if (request.url.path == '/data/manifest.json') {
          return jsonResponse(<String, Object?>{
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
        if (request.url.path == '/data/drugs_index.json') {
          return jsonResponse(<Object?>[
            <String, Object?>{
              'id': 'furosemida',
              'name': <String, Object?>{'pt': 'Furosemida', 'es': 'Furosemida'},
              'category': 'cardio',
              'keywords': <Object?>['furosemida'],
              'schema': 'premium-v1',
              'sourceModule': 'cardio.js',
              'hasContextVariants': false,
              'contextVariantCount': 0,
              'canonicalOwner': 'cardio.js',
            },
          ]);
        }
        if (request.url.path == '/data/drugs/furosemida.json') {
          return jsonResponse(<String, Object?>{
            'id': 'furosemida',
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
          });
        }
        return http.Response('not found', 404);
      });

      final adapter = PlantaoHttpDrugEvidenceAdapter(
        client: client,
        baseUri: Uri.parse('https://example.test/'),
      );
      final manifest = await adapter.loadManifest();
      final index = await adapter.loadIndex(manifest);
      final document = await adapter.loadDocument(
        documentId: index.single.documentId,
        manifest: manifest,
      );

      expect(document.documentId, 'furosemida');
      expect(requestedPaths, const <String>[
        '/data/manifest.json',
        '/data/drugs_index.json',
        '/data/drugs/furosemida.json',
      ]);
    },
  );

  test('unsafe document ID is rejected before HTTP request', () async {
    var calls = 0;
    final adapter = PlantaoHttpDrugEvidenceAdapter(
      client: MockClient((request) async {
        calls += 1;
        return jsonResponse(<String, Object?>{});
      }),
    );
    final manifest = await PlantaoHttpDrugEvidenceAdapter(
      client: MockClient((request) async {
        return jsonResponse(<String, Object?>{
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
      }),
    ).loadManifest();

    await expectLater(
      adapter.loadDocument(documentId: '../furosemida', manifest: manifest),
      throwsA(isA<FormatException>()),
    );
    expect(calls, 0);
  });
}
