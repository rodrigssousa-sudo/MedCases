import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/clinical_content/clinical_content_gateway.dart';
import 'package:medcases/services/clinical_content/clinical_content_contract.dart';
import 'package:medcases/services/clinical_content/clinical_content_models.dart';
import 'package:medcases/services/plantao_knowledge/remote_knowledge.dart';
import 'package:medcases/services/plantao_knowledge/remote_knowledge_resolver.dart';
import 'knowledge_fixture.dart';

void main() {
  test('same canonical PT/ES object and immutable clinical hash', () {
    final p = syntheticProtocol();
    final parsed = RemoteKnowledgeProtocol.parse(p);
    expect(parsed.options.length, 3);
    expect(() => parsed.json['version'] = 'changed', throwsUnsupportedError);
    p['metadata'] = {'technical': 'not clinical'};
    expect(RemoteKnowledgeProtocol.parse(p).hash, parsed.hash);
  });
  final invalid = <String, void Function(Map<String, dynamic>)>{
    'missing ES': (p) => (p['title'] as Map).remove('es'),
    'not approved': (p) => p['clinicalReview']['approved'] = false,
    'DRAFT': (p) => p['publication']['status'] = 'DRAFT',
    'REVOKED': (p) => p['publication']['status'] = 'REVOKED',
    'SUPERSEDED': (p) => p['publication']['status'] = 'SUPERSEDED',
    'unsupported schema': (p) => p['schemaVersion'] = 2,
    'missing reference': (p) =>
        p['therapeuticOptions'][1]['references'] = ['INVENTED'],
    'authority override': (p) => p['metadata']['doseAuthority'] = true,
    'duplicate option': (p) =>
        p['therapeuticOptions'][1]['optionId'] = 'TEST_OPTION_0',
  };
  for (final e in invalid.entries)
    test(e.key, () {
      final p = syntheticProtocol();
      e.value(p);
      p['clinicalContentSha256'] = clinicalKnowledgeHash(p);
      expect(() => RemoteKnowledgeProtocol.parse(p),
          throwsA(isA<ContentFailure>()));
    });
  for (final field in ['dose', 'route', 'frequency', 'preparation', 'drugName'])
    test('clinical mutation invalidates hash: $field', () {
      final p = syntheticProtocol();
      p['therapeuticOptions'][0]['drugs'][0]
          [field] = {'pt': 'CHANGED', 'es': 'CHANGED'};
      expect(() => RemoteKnowledgeProtocol.parse(p),
          throwsA(isA<ContentFailure>()));
    });
  for (final lang in ['pt', 'es'])
    test('deterministic isolated practical copy $lang', () {
      final p = RemoteKnowledgeProtocol.parse(syntheticProtocol());
      final a = PracticalPrescriptionFormatter.format(p.primary, lang)!;
      final b =
          PracticalPrescriptionFormatter.format(p.alternatives.first, lang)!;
      expect(
          a,
          contains(
              lang == 'pt' ? 'PRESCRIÇÃO PRÁTICA' : 'PRESCRIPCIÓN PRÁCTICA'));
      expect(a, contains('TEST_VALUE_0 TEST_UNIT'));
      expect(a, isNot(b));
      for (final excluded in [
        'TEST_REFERENCE',
        'TEST_WARNING',
        'TEST_CONSIDER',
        'TEST_VALUE_1',
        'https://'
      ]) expect(a, isNot(contains(excluded)));
    });
  for (final field in ['dose', 'presentation', 'route', 'frequency'])
    test('missing copy field fails closed: $field', () {
      final p = syntheticProtocol();
      p['therapeuticOptions'][0]['drugs'][0].remove(field);
      expect(
          PracticalPrescriptionFormatter.format(
              p['therapeuticOptions'][0], 'pt'),
          isNull);
    });
  test('treatment kinds enforce their minimum prescription fields', () {
    final p = syntheticProtocol();
    final o = p['therapeuticOptions'][0] as Map<String, dynamic>;
    o['prescriptionKind'] = 'scheduled';
    expect(PracticalPrescriptionFormatter.format(o, 'pt'), isNull);
    o['drugs'][0]['duration'] = bilingual('TEST_DURATION');
    expect(PracticalPrescriptionFormatter.format(o, 'pt'),
        contains('TEST_DURATION'));
    o['prescriptionKind'] = 'continuous_infusion';
    expect(PracticalPrescriptionFormatter.format(o, 'es'), isNull);
    o['drugs'][0]['diluent'] = bilingual('TEST_DILUENT');
    o['drugs'][0]['diluentVolumeMl'] = 1;
    o['drugs'][0]['infusionMinutes'] = 1;
    expect(PracticalPrescriptionFormatter.format(o, 'es'),
        contains('TEST_DILUENT'));
    o['drugs'][0].remove('preparation');
    expect(PracticalPrescriptionFormatter.format(o, 'es'), isNull);
  });
  test('complex adjustments are not silently omitted', () {
    final p = syntheticProtocol();
    p['therapeuticOptions'][0]['drugs'][0]
        ['loadingDose'] = {'value': 'TEST', 'unit': 'TEST'};
    expect(
        PracticalPrescriptionFormatter.format(p['therapeuticOptions'][0], 'pt'),
        isNull);
  });
  group('real gateway snapshots and request boundary', () {
    late Map<String, Map<String, dynamic>> files;
    late ClinicalContentGateway gateway;
    late RemoteKnowledgeResolver resolver;
    late MemoryClinicalSnapshotStore store;
    var uid = 'A';
    var offline = false;
    var delay = false;
    var unauthorized = false;
    final events = <Map<String, Object?>>[];
    setUp(() {
      uid = 'A';
      offline = false;
      delay = false;
      unauthorized = false;
      files = fixtureRelease(syntheticProtocol());
      store = MemoryClinicalSnapshotStore();
      gateway = ClinicalContentGateway(
          baseUri: Uri.parse('https://example.invalid/'),
          store: store,
          sessionScope: 'A',
          currentSessionScope: () => uid,
          canReadDomain: (_) => true,
          tokenProvider: () async => 'TEST_TOKEN',
          timeout: const Duration(milliseconds: 30),
          client: MockClient((r) async {
            if (offline) throw Exception('offline');
            if (unauthorized) return http.Response('{}', 403);
            if (delay)
              await Future<void>.delayed(const Duration(milliseconds: 60));
            final data = files[r.url.path.substring(1)];
            return http.Response(jsonEncode(data), data == null ? 404 : 200);
          }));
      gateway.registerModelValidator(ClinicalContentModels.validate);
      events.clear();
      resolver = RemoteKnowledgeResolver(gateway, telemetry: events.add);
    });
    tearDown(() => gateway.close());
    test(
        'valid remote lookup exact context only and primary prompt excludes alternatives',
        () async {
      final result = await resolver.resolve('TEST_CONTEXT_ID');
      expect(result.protocol, isNotNull);
      expect(result.promptContext('pt'), contains('EXTERNAL_EVIDENCE'));
      expect(result.promptContext('pt'), isNot(contains('TEST_OPTION_1')));
      expect(result.promptContext('pt', alternatives: true),
          contains('TEST_OPTION_2'));
      expect((await resolver.resolve('test_context_id')).protocol, isNull);
    });
    test('offline and timeout retain LKG', () async {
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNotNull);
      offline = true;
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNotNull);
      offline = false;
      delay = true;
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNotNull);
    });
    test(
        'server denial prevents offline reuse until successful reauthorization',
        () async {
      final r = await resolver.resolve('TEST_CONTEXT_ID');
      unauthorized = true;
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNull);
      offline = true;
      resolver = RemoteKnowledgeResolver(gateway, telemetry: events.add);
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNull);
      expect(resolver.isCurrent(r.protocol!), isFalse);
      unauthorized = false;
      offline = false;
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNotNull);
    });
    test('explicit provider conflict can deny but never authorize an option',
        () async {
      final r = await resolver.resolve('TEST_CONTEXT_ID');
      final session = TherapeuticOptionSession(
          resolver: resolver,
          resolution: r,
          language: 'pt',
          ownsRequest: () => true,
          safetyAllows: (_) => true,
          lookupDrug: (_) async => true,
          refreshEvidence: () async => [],
          externalConflictDetected: () => true);
      expect(await session.copy('TEST_OPTION_0'), isNull);
      expect(await session.options(alternatives: true), isEmpty);
      expect(
          events.any((e) => e['status'] == 'REMOTE_CONTENT_REVIEW_RECOMMENDED'),
          isTrue);
    });
    test('no cache and timeout fall back', () async {
      delay = true;
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNull);
    });
    test('bad hash update retains LKG', () async {
      await resolver.resolve('TEST_CONTEXT_ID');
      final p = syntheticProtocol();
      p['clinicalContext'] = bilingual('MUTATION');
      files = fixtureRelease(p, sequence: 2);
      expect(
          (await resolver.resolve('TEST_CONTEXT_ID')).protocol!.version, 'v1');
      expect(gateway.activeVersion, 'v1');
    });
    test('revocation invalidates captured option, cache and copy', () async {
      final r = await resolver.resolve('TEST_CONTEXT_ID');
      files = fixtureRelease(syntheticProtocol(), sequence: 2, revoked: true);
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNull);
      expect(resolver.isCurrent(r.protocol!), isFalse);
      offline = true;
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNull);
    });
    test('UID change cannot read or copy previous snapshot', () async {
      final r = await resolver.resolve('TEST_CONTEXT_ID');
      uid = 'B';
      expect(resolver.isCurrent(r.protocol!), isFalse);
      expect((await resolver.resolve('TEST_CONTEXT_ID')).protocol, isNull);
    });
    test('evidence divergence is exposed and queues technical review',
        () async {
      final r = await resolver.resolve('TEST_CONTEXT_ID', externalClaims: [
        const TherapeuticEvidenceClaim(
            drugId: 'test_drug_0',
            field: 'dose',
            value: 'DIFFERENT',
            referenceId: 'EXTERNAL_TEST_REFERENCE')
      ]);
      expect(r.conflict, isTrue);
      expect(r.promptContext('pt'), contains('EVIDENCE_CONFLICT'));
      expect(
          events.any((e) => e['status'] == 'REMOTE_CONTENT_REVIEW_RECOMMENDED'),
          isTrue);
      expect(jsonEncode(events), isNot(contains('DIFFERENT')));
    });
    test('publication never bypasses productive safety callback', () async {
      final r = await resolver.resolve('TEST_CONTEXT_ID');
      var safety = false;
      var owner = true;
      var reads = 0;
      final session = TherapeuticOptionSession(
          resolver: resolver,
          resolution: r,
          language: 'pt',
          ownsRequest: () => owner,
          safetyAllows: (_) => safety,
          lookupDrug: (_) async {
            reads++;
            return true;
          },
          refreshEvidence: () async => []);
      expect(await session.copy('TEST_OPTION_0'), isNull);
      safety = true;
      expect(await session.copy('TEST_OPTION_0'), contains('TEST_VALUE_0'));
      expect((await session.options(alternatives: true)).length, 2);
      expect(reads, greaterThan(0));
      owner = false;
      expect(await session.copy('TEST_OPTION_0'), isNull);
    });
    test('unknown canonical drug cannot copy; IDs never inferred', () async {
      final r = await resolver.resolve('TEST_CONTEXT_ID');
      final session = TherapeuticOptionSession(
          resolver: resolver,
          resolution: r,
          language: 'es',
          ownsRequest: () => true,
          safetyAllows: (_) => true,
          lookupDrug: (_) async => false,
          refreshEvidence: () async => []);
      expect(await session.copy('TEST_OPTION_0'), isNull);
      expect(await session.copy('test option 0'), isNull);
    });
  });
}
