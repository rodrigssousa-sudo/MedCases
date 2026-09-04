import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/ai_pipeline/plantao/adapters/plantao_versioned_remote_drug_evidence_json_loader.dart';
import 'package:medcases/services/ai_pipeline/plantao/shadow/plantao_remote_drug_evidence_runtime_observer.dart';

Map<String, Object?> currentJson(String id) => {
      'schemaVersion': 'medcases-ai-drug-data-current-v1',
      'bundleId': id,
      'bundleVersion': id,
      'bundleSha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'publicationPath': 'bundles/$id/publication.json',
      'manifestPath': 'bundles/$id/manifest.json',
      'indexPath': 'bundles/$id/index.json',
      'drugPathTemplate': 'bundles/$id/drugs/{id}.json',
      'drugCount': 838,
      'typedRegimenCount': 0,
      'deterministicDosingPublishableCount': 0,
      'textToRegimenInferenceUsed': false,
    };
http.Response jr(Object? v, {int statusCode = 200}) =>
    http.Response.bytes(utf8.encode(jsonEncode(v)), statusCode);

void main() {
  test('TTL reuses then refreshes pointer', () async {
    var now = DateTime.utc(2026, 7, 28, 12);
    var fetches = 0;
    const a = 'clinical-data-v1-test-ai-1111111111111111',
        b = 'clinical-data-v1-test-ai-2222222222222222';
    final observer = PlantaoRemoteDrugEvidenceRuntimeObserver();
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      observer: observer,
      currentPointerTtl: const Duration(minutes: 5),
      now: () => now,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/current.json')) {
          fetches++;
          return jr(currentJson(fetches == 1 ? a : b));
        }
        return jr({'path': r.url.path});
      }),
    );
    expect(await loader.loadJsonText('manifest.json'), contains(a));
    now = now.add(const Duration(minutes: 4));
    await loader.loadJsonText('index.json');
    expect(fetches, 1);
    expect(observer.snapshot.currentPointerCacheHitCount, 1);
    now = now.add(const Duration(minutes: 2));
    expect(await loader.loadJsonText('manifest.json'), contains(b));
    expect(fetches, 2);
    expect(observer.snapshot.currentPointerExpiredCount, 1);
  });

  test('concurrent refresh is single-flight', () async {
    var now = DateTime.utc(2026, 7, 28, 12);
    var fetches = 0;
    final gate = Completer<void>();
    const id = 'clinical-data-v1-test-ai-3333333333333333';
    final observer = PlantaoRemoteDrugEvidenceRuntimeObserver();
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      observer: observer,
      currentPointerTtl: const Duration(minutes: 1),
      now: () => now,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/current.json')) {
          fetches++;
          if (fetches == 2) await gate.future;
          return jr(currentJson(id));
        }
        return jr({});
      }),
    );
    await loader.loadJsonText('manifest.json');
    now = now.add(const Duration(minutes: 2));
    final f1 = loader.loadJsonText('manifest.json');
    final f2 = loader.loadJsonText('index.json');
    await Future<void>.delayed(Duration.zero);
    expect(fetches, 2);
    gate.complete();
    await Future.wait([f1, f2]);
    expect(observer.snapshot.currentPointerCoalescedRequestCount,
        greaterThanOrEqualTo(1));
  });

  test('stale immutable pointer contains network failure', () async {
    var now = DateTime.utc(2026, 7, 28, 12);
    var fail = false;
    const id = 'clinical-data-v1-test-ai-4444444444444444';
    final observer = PlantaoRemoteDrugEvidenceRuntimeObserver();
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
      observer: observer,
      currentPointerTtl: const Duration(minutes: 1),
      now: () => now,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/current.json')) {
          return fail ? jr({}, statusCode: 503) : jr(currentJson(id));
        }
        return jr({'bundle': id});
      }),
    );
    await loader.loadJsonText('manifest.json');
    now = now.add(const Duration(minutes: 2));
    fail = true;
    expect(await loader.loadJsonText('index.json'), contains(id));
    expect(observer.snapshot.currentPointerStaleFallbackCount, 1);
    await expectLater(loader.refreshCurrentPointer(allowStaleOnFailure: false),
        throwsA(isA<StateError>()));
  });

  test('lifecycle invalidation forces pointer network fetch', () async {
    var fetches = 0;
    const id = 'clinical-data-v1-test-ai-5555555555555555';
    final loader = PlantaoVersionedRemoteDrugEvidenceJsonLoader(
        client: MockClient((r) async {
      if (r.url.path.endsWith('/current.json')) {
        fetches++;
        return jr(currentJson(id));
      }
      return jr({});
    }));
    await loader.loadJsonText('manifest.json');
    loader.invalidateCurrentPointerForLifecycle();
    await loader.loadJsonText('index.json');
    expect(fetches, 2);
  });
}
