import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_versioned_remote_drug_evidence_json_loader.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_remote_drug_evidence_runtime_observer.dart';

const bundleId = 'clinical-data-v1-test-ai-0123456789abcdef';
const bundleSha =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Map<String, Object?> currentJson({
  int typedRegimenCount = 0,
  String? manifestPath,
}) {
  return <String, Object?>{
    'schemaVersion': 'medcases-ai-drug-data-current-v1',
    'bundleId': bundleId,
    'bundleVersion': bundleId,
    'bundleSha256': bundleSha,
    'publicationPath': 'bundles/$bundleId/publication.json',
    'manifestPath': manifestPath ?? 'bundles/$bundleId/manifest.json',
    'indexPath': 'bundles/$bundleId/index.json',
    'drugPathTemplate': 'bundles/$bundleId/drugs/{id}.json',
    'drugCount': 838,
    'typedRegimenCount': typedRegimenCount,
    'deterministicDosingPublishableCount': 0,
    'textToRegimenInferenceUsed': false,
  };
}

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
  test('records success, latency and current pointer cache hits', () async {
    final observer = PlantaoRemoteDrugEvidenceRuntimeObserver();
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.path);
      return switch (request.url.path) {
        '/data/ai-drug-data/current.json' => jsonResponse(currentJson()),
        '/data/ai-drug-data/bundles/$bundleId/manifest.json' =>
          jsonResponse(<String, Object?>{'manifest': true}),
        '/data/ai-drug-data/bundles/$bundleId/index.json' =>
          jsonResponse(<Object?>[]),
        _ => jsonResponse(<String, Object?>{}, statusCode: 404),
      };
    });
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
      observer: observer,
      baseUri: Uri.parse(
        'https://medcasescalcu.com/data/ai-drug-data/',
      ),
    );

    await loader.loadJsonText('manifest.json');
    await loader.loadJsonText('index.json');

    final snapshot = observer.snapshot;
    expect(snapshot.logicalRequestCount, 2);
    expect(snapshot.logicalSuccessCount, 2);
    expect(snapshot.logicalFailureCount, 0);
    expect(snapshot.httpRequestCount, 3);
    expect(snapshot.httpSuccessCount, 3);
    expect(snapshot.httpFailureCount, 0);
    expect(snapshot.currentPointerNetworkFetchCount, 1);
    expect(snapshot.currentPointerCacheHitCount, 1);
    expect(snapshot.logicalSuccessRate, 1);
    expect(snapshot.httpSuccessRate, 1);
    expect(
      requested.where(
        (path) => path == '/data/ai-drug-data/current.json',
      ),
      hasLength(1),
    );
  });

  test('records 404 without retaining clinical payload', () async {
    final observer = PlantaoRemoteDrugEvidenceRuntimeObserver();
    final client = MockClient((request) async {
      if (request.url.path == '/data/ai-drug-data/current.json') {
        return jsonResponse(currentJson());
      }
      return jsonResponse(<String, Object?>{}, statusCode: 404);
    });
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
      observer: observer,
    );

    await expectLater(
      loader.loadJsonText('manifest.json'),
      throwsA(isA<StateError>()),
    );

    final snapshot = observer.snapshot;
    expect(snapshot.logicalFailureCount, 1);
    expect(snapshot.httpFailureCount, 1);
    expect(
      snapshot.failuresOf(
        PlantaoRemoteDrugEvidenceFailureKind.httpNotFound,
      ),
      2,
    );
    expect(snapshot.toJson().toString(), isNot(contains('manifest.json')));
  });

  test('records timeout and remains resettable', () async {
    final observer = PlantaoRemoteDrugEvidenceRuntimeObserver();
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return jsonResponse(currentJson());
    });
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
      observer: observer,
      requestTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      loader.loadJsonText('manifest.json'),
      throwsA(isA<TimeoutException>()),
    );

    expect(observer.snapshot.logicalFailureCount, 1);
    expect(observer.snapshot.httpFailureCount, 1);
    expect(
      observer.snapshot.failuresOf(
        PlantaoRemoteDrugEvidenceFailureKind.timeout,
      ),
      2,
    );

    observer.reset();
    expect(observer.snapshot.logicalRequestCount, 0);
    expect(observer.snapshot.failureCounts, isEmpty);
  });

  test('records invalid bundle contract', () async {
    final observer = PlantaoRemoteDrugEvidenceRuntimeObserver();
    final client = MockClient((request) async {
      return jsonResponse(currentJson(typedRegimenCount: 1));
    });
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
      observer: observer,
    );

    await expectLater(
      loader.loadJsonText('manifest.json'),
      throwsA(isA<FormatException>()),
    );

    expect(
      observer.snapshot.failuresOf(
        PlantaoRemoteDrugEvidenceFailureKind.invalidContract,
      ),
      1,
    );
    expect(observer.snapshot.logicalFailureCount, 1);
    expect(observer.snapshot.httpSuccessCount, 1);
  });

  test('clearCache forces a new current pointer network fetch', () async {
    final observer = PlantaoRemoteDrugEvidenceRuntimeObserver();
    final client = MockClient((request) async {
      return switch (request.url.path) {
        '/data/ai-drug-data/current.json' => jsonResponse(currentJson()),
        '/data/ai-drug-data/bundles/$bundleId/manifest.json' =>
          jsonResponse(<String, Object?>{}),
        '/data/ai-drug-data/bundles/$bundleId/index.json' =>
          jsonResponse(<Object?>[]),
        _ => jsonResponse(<String, Object?>{}, statusCode: 404),
      };
    });
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
      observer: observer,
    );

    await loader.loadJsonText('manifest.json');
    loader.clearCache();
    await loader.loadJsonText('index.json');

    expect(observer.snapshot.currentPointerNetworkFetchCount, 2);
    expect(observer.snapshot.currentPointerCacheHitCount, 0);
  });

  test('rejects unsafe request and records containment class', () async {
    final observer = PlantaoRemoteDrugEvidenceRuntimeObserver();
    final client = MockClient((request) async {
      return jsonResponse(currentJson());
    });
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      client: client,
      observer: observer,
    );

    await expectLater(
      loader.loadJsonText('../secret.json'),
      throwsA(isA<FormatException>()),
    );

    expect(
      observer.snapshot.failuresOf(
        PlantaoRemoteDrugEvidenceFailureKind.unsafeRequest,
      ),
      1,
    );
  });
}
