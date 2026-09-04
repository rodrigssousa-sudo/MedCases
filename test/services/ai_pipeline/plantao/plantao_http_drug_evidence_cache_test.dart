import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_http_drug_evidence_adapter.dart';

const version = 'clinical-data-v1-cache-test';
const bundleSha =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

http.Response jsonResponse(Object? value) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(value)),
    200,
    headers: const <String, String>{
      'content-type': 'application/json; charset=utf-8',
    },
  );
}

void main() {
  test('manifest, index and document are cached by bundle version', () async {
    final calls = <String, int>{};
    final client = MockClient((request) async {
      calls.update(request.url.path, (value) => value + 1, ifAbsent: () => 1);
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

    final manifest1 = await adapter.loadManifest();
    final manifest2 = await adapter.loadManifest();
    final index1 = await adapter.loadIndex(manifest1);
    final index2 = await adapter.loadIndex(manifest2);
    final document1 = await adapter.loadDocument(
      documentId: 'furosemida',
      manifest: manifest1,
    );
    final document2 = await adapter.loadDocument(
      documentId: 'furosemida',
      manifest: manifest2,
    );

    expect(identical(manifest1, manifest2), isTrue);
    expect(identical(index1, index2), isTrue);
    expect(identical(document1, document2), isTrue);
    expect(calls['/data/manifest.json'], 1);
    expect(calls['/data/drugs_index.json'], 1);
    expect(calls['/data/drugs/furosemida.json'], 1);

    adapter.clearCache();
    await adapter.loadManifest();
    expect(calls['/data/manifest.json'], 2);
  });
}
