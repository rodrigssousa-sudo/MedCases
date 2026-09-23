import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/clinical_content/clinical_content_gateway.dart';
import 'package:medcases/services/clinical_content/clinical_content_models.dart';
import 'package:medcases/services/plantao_knowledge/remote_knowledge_resolver.dart';
import 'knowledge_fixture.dart';

void main() {
  for (final change in [
    'conflict',
    'revoked',
    'session',
    'uid',
    'authority',
    'unchanged'
  ]) {
    test('copy lookup boundary revalidates $change', () async {
      var uid = 'A', owns = true, conflict = false, authority = true;
      var files = fixtureRelease(syntheticProtocol());
      final gateway = ClinicalContentGateway(
          baseUri: Uri.parse('https://example.invalid/'),
          store: MemoryClinicalSnapshotStore(),
          sessionScope: 'A',
          currentSessionScope: () => uid,
          canReadDomain: (_) => true,
          tokenProvider: () async => 'TEST',
          client: MockClient((r) async =>
              http.Response(jsonEncode(files[r.url.path.substring(1)]), 200)));
      gateway.registerModelValidator(ClinicalContentModels.validate);
      addTearDown(gateway.close);
      final resolver = RemoteKnowledgeResolver(gateway),
          started = Completer<void>(),
          done = Completer<bool>();
      final resolution = await resolver.resolve('TEST_CONTEXT_ID');
      final session = TherapeuticOptionSession(
          resolver: resolver,
          resolution: resolution,
          language: 'pt',
          ownsRequest: () => owns,
          safetyAllows: (_) => authority,
          lookupDrug: (_) {
            started.complete();
            return done.future;
          },
          refreshEvidence: () async => [],
          externalConflictDetected: () => conflict);
      final pending = session.copy('TEST_OPTION_0');
      await started.future;
      if (change == 'conflict') conflict = true;
      if (change == 'session') owns = false;
      if (change == 'uid') uid = 'B';
      if (change == 'authority') authority = false;
      if (change == 'revoked') {
        files = fixtureRelease(syntheticProtocol(), sequence: 2, revoked: true);
        await gateway.sync();
      }
      done.complete(true);
      final text = await pending;
      if (change == 'unchanged') {
        expect(text, isNotNull);
        expect(session.authorizesDelivery('TEST_OPTION_0', text!), isTrue);
        expect(session.authorizesDelivery('TEST_OPTION_1', text), isFalse);
        conflict = true;
        expect(session.authorizesDelivery('TEST_OPTION_0', text), isFalse);
      } else {
        expect(text, isNull);
      }
    });
  }
  test('conflict during evidence refresh prevents resolver/network work',
      () async {
    var conflict = false, reads = 0;
    final files = fixtureRelease(syntheticProtocol());
    final gateway = ClinicalContentGateway(
        baseUri: Uri.parse('https://example.invalid/'),
        store: MemoryClinicalSnapshotStore(),
        sessionScope: 'A',
        currentSessionScope: () => 'A',
        canReadDomain: (_) => true,
        tokenProvider: () async => 'TEST',
        client: MockClient((r) async {
          reads++;
          return http.Response(jsonEncode(files[r.url.path.substring(1)]), 200);
        }));
    gateway.registerModelValidator(ClinicalContentModels.validate);
    addTearDown(gateway.close);
    final resolver = RemoteKnowledgeResolver(gateway),
        resolution = await resolver.resolve('TEST_CONTEXT_ID');
    final before = reads;
    final session = TherapeuticOptionSession(
        resolver: resolver,
        resolution: resolution,
        language: 'es',
        ownsRequest: () => true,
        safetyAllows: (_) => true,
        lookupDrug: (_) async => true,
        refreshEvidence: () async {
          conflict = true;
          return [];
        },
        externalConflictDetected: () => conflict);
    expect(await session.copy('TEST_OPTION_0'), isNull);
    expect(reads, before);
  });
}
