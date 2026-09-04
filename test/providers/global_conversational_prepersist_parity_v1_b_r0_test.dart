import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String source;

  setUpAll(() {
    source = File('lib/providers/app_provider.dart').readAsStringSync();
  });

  group('Global conversational Build 2 pre-persist parity', () {
    test('all six productive persistence seams converge on one owner', () {
      final calls = RegExp(r'await\s+persistAiExchangeOnce\s*\(')
          .allMatches(source)
          .length;
      expect(calls, 6);
      expect(source, contains('GLOBAL_CONTEXT_BUILD2_PREPERSIST_PARITY_V1'));
      expect(source, contains('_plantaoPersistenceEligibilityByRequest'));
    });

    test('central persistence owner applies machine gate before idempotency ownership', () {
      final start = source.indexOf(
        'Future<SessionPersistStatus> persistAiExchangeOnce({',
      );
      final end = source.indexOf(
        '// M74B_POST_FINAL_PRESENTATION_RECONCILIATION_V1',
        start,
      );
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final block = source.substring(start, end);

      final gate = block.indexOf('final persistenceGate =');
      final eligible = block.indexOf('final persistenceEligible =');
      final blocked = block.indexOf(
        "return const SessionPersistSkipped('critical_machine_gate');",
      );
      final ownership = block.indexOf(
        '_persistedExchangeIds.add(context.requestId);',
      );
      final firestore = block.indexOf('FirestoreService.batchWriteAiExchange(');

      expect(gate, isNonNegative);
      expect(eligible, greaterThan(gate));
      expect(blocked, greaterThan(eligible));
      expect(ownership, greaterThan(blocked));
      expect(firestore, greaterThan(ownership));
    });

    test('blocked direct route rolls back the just-appended history pair', () {
      expect(source, contains('_removeRejectedAiHistoryTail('));
      expect(source, contains('_aiHistory.removeRange(userIndex, _aiHistory.length);'));
      expect(source, contains('historyTailRemoved=\$historyTailRemoved'));
      expect(source, contains('owner=gpt_happy_path_finalizer'));
      expect(source, contains('owner=persistAiExchangeOnce'));
    });

    test('gate is registered for both buffered and legacy routes', () {
      final publicRegistration = source.indexOf(
        '_plantaoPersistenceEligibilityByRequest[phase3kResolvedRequestId!]',
      );
      final legacyRegistration = source.indexOf(
        '_plantaoPersistenceEligibilityByRequest[thisRequestId]',
      );
      expect(publicRegistration, isNonNegative);
      expect(legacyRegistration, greaterThan(publicRegistration));
    });

    test('gate lifetime ends at canonical request completion', () {
      final start = source.indexOf('void _completeAiRequestOnce(String requestId)');
      final end = source.indexOf(
        '// ── MICRO-BUILD 462E-A.5.3.7.3.2.5 [PILLAR 1]',
        start,
      );
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final block = source.substring(start, end);
      expect(
        block,
        contains('_plantaoPersistenceEligibilityByRequest.remove(requestId);'),
      );
    });

    test('Build 1 and R8 contracts remain intact', () {
      expect(source, isNot(contains('_sessionMemory.resetIfTopicChanged(input)')));
      expect(source, contains('_expandedQuery(input, forceContext: true)'));
      expect(source, contains('M77_R8_PRE_PERSIST_MACHINE_GATE_V1'));
      expect(source, contains('M77_R8_CANONICAL_AUTHORITY_SPECIALTY_GUARD_LOCK_V1'));
      expect(source, contains('M77_CLINICAL_NEW_THREAD_SESSION_ROTATION_V1'));
      expect(source, contains('utf16SafeProviderText'));
    });
  });
}
