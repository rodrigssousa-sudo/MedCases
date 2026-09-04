import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_session_exchange_hydrator.dart';

void main() {
  group('M74B canonical post-final persistence hydration parity', () {
    test('presentation overlay wins and reconciled DTO restores', () {
      final hydrated = AiSessionExchangeHydrator.hydrate(
        sessionId: 'session-1',
        exchanges: <Map<String, dynamic>>[
          <String, dynamic>{
            'requestId': 'request-1',
            'userInput': 'Caso clínico',
            'assistantOutput': 'provider-stage',
            'assistantPresentation': 'final-visible',
            'clinicalOutput': <String, dynamic>{
              'diagnosticoHeuristico': 'Anafilaxia',
              'condutaImediata': 'Adrenalina IM',
              'prescricao': <Object>[],
            },
          },
        ],
      );

      expect(hydrated, hasLength(1));
      expect(hydrated.single.assistantText, 'final-visible');
      expect(hydrated.single.clinicalOutput, isNotNull);
      expect(
        hydrated.single.clinicalOutput?.diagnosticoHeuristico,
        'Anafilaxia',
      );
      expect(
        hydrated.single.assistantMessageId,
        'ai_session:session-1:request-1:assistant',
      );
    });

    test('old exchange falls back to provider output without trusting DTO', () {
      final hydrated = AiSessionExchangeHydrator.hydrate(
        sessionId: 'session-old',
        exchanges: <Map<String, dynamic>>[
          <String, dynamic>{
            'requestId': 'request-old',
            'assistantOutput': 'old-provider-output',
            'clinicalOutput': <String, dynamic>{
              'diagnosticoHeuristico': 'stale',
              'condutaImediata': 'stale',
              'prescricao': <Object>[],
            },
          },
        ],
      );

      expect(hydrated.single.assistantText, 'old-provider-output');
      expect(hydrated.single.clinicalOutput, isNull);
    });

    test('duplicate non-empty requestId projects once', () {
      final hydrated = AiSessionExchangeHydrator.hydrate(
        sessionId: 'session-dedup',
        exchanges: <Map<String, dynamic>>[
          <String, dynamic>{
            'requestId': 'same-request',
            'assistantPresentation': 'first',
          },
          <String, dynamic>{
            'requestId': 'same-request',
            'assistantPresentation': 'duplicate',
          },
        ],
      );

      expect(hydrated, hasLength(1));
      expect(hydrated.single.assistantText, 'first');
    });

    test('old entries without requestId remain distinct', () {
      final hydrated = AiSessionExchangeHydrator.hydrate(
        sessionId: 'session-no-id',
        exchanges: <Map<String, dynamic>>[
          <String, dynamic>{'assistantOutput': 'same'},
          <String, dynamic>{'assistantOutput': 'same'},
        ],
      );

      expect(hydrated, hasLength(2));
      expect(
        hydrated.map((item) => item.assistantMessageId).toSet(),
        hasLength(2),
      );
    });

    test('same exchange hydrates to stable message IDs', () {
      final exchange = <Map<String, dynamic>>[
        <String, dynamic>{
          'requestId': 'stable-request',
          'userInput': 'u',
          'assistantPresentation': 'a',
        },
      ];

      final first = AiSessionExchangeHydrator.hydrate(
        sessionId: 'stable-session',
        exchanges: exchange,
      ).single;
      final second = AiSessionExchangeHydrator.hydrate(
        sessionId: 'stable-session',
        exchanges: exchange,
      ).single;

      expect(first.userMessageId, second.userMessageId);
      expect(first.assistantMessageId, second.assistantMessageId);
    });

    test('Firestore reconciliation is additive and counter-free', () {
      final source =
          File('lib/services/firestore_service.dart').readAsStringSync();

      final start = source.indexOf(
        'reconcileAiExchangeFinalPresentation({',
      );
      final end = source.indexOf(
        'loadAiSessionExchangesTyped(String uid, String sessionId)',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final owner = source.substring(start, end);
      expect(owner, contains('batch.update(exchangeRef, exchangeData);'));
      expect(owner, contains("'assistantPresentation'"));
      expect(owner, contains("'presentationSchemaVersion': 1"));
      expect(owner, isNot(contains("'assistantOutput':")));
      expect(owner, isNot(contains('FieldValue.increment(')));
      expect(owner, isNot(contains('batchWriteAiExchange(')));
    });

    test('AppProvider reconcile is class-level after persist and before title', () {
      final source = File('lib/providers/app_provider.dart').readAsStringSync();

      final persist = source.indexOf(
        'Future<SessionPersistStatus> persistAiExchangeOnce({',
      );
      final start = source.indexOf(
        'Future<bool> reconcileAiExchangeFinalPresentation({',
        persist,
      );
      final end = source.indexOf(
        'String _generateConversationTitle(',
        start,
      );

      expect(persist, greaterThanOrEqualTo(0));
      expect(start, greaterThan(persist));
      expect(end, greaterThan(start));

      final owner = source.substring(start, end);
      expect(owner, contains('_currentConversationSessionId'));
      expect(owner, contains('_persistedExchangeIds.contains'));
      expect(
        owner,
        contains('FirestoreService.reconcileAiExchangeFinalPresentation('),
      );
      expect(owner, isNot(contains('persistAiExchangeOnce(')));
      expect(owner, isNot(contains('sendAiMessage(')));

      final persistOwner = source.substring(persist, start);
      expect(persistOwner, contains('return const SessionPersistSynced();'));
      expect(persistOwner, contains('return SessionPersistFailed(e);'));
    });

    test('AiScreen text reconcile is after M73B and safe final commit', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      final start = source.indexOf('onDone: (finalText)');
      final end = source.indexOf(
        'onStructuredDone: (finalText, clinicalOutput)',
        start,
      );

      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));

      final owner = source.substring(start, end);
      final m73b = owner.indexOf(
        'M73B_TYPED_RICH_PHASES_FINAL_COMPLETENESS_RUNTIME_V1',
      );
      final commit =
          owner.indexOf('committedAiMessageText = safeFinalText;');
      final reconcile = owner.indexOf(
        'M74B_POST_FINAL_PRESENTATION_RECONCILIATION_V1',
      );

      expect(m73b, greaterThanOrEqualTo(0));
      expect(commit, greaterThan(m73b));
      expect(reconcile, greaterThan(commit));
      expect(owner, contains('finalAssistantText: m74bCommittedText'));
    });

    test('structured reconcile is after successful DTO attach', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      final start = source.indexOf(
        'onStructuredDone: (finalText, clinicalOutput)',
      );
      expect(start, greaterThanOrEqualTo(0));

      final owner = source.substring(start);
      final attach = owner.indexOf('clinicalOutput: clinicalOutput,');
      final reconcile = owner.indexOf(
        'M74B_STRUCTURED_PRESENTATION_RECONCILIATION_V1',
      );

      expect(attach, greaterThanOrEqualTo(0));
      expect(reconcile, greaterThan(attach));
      expect(
        owner,
        contains('clinicalOutputJson: clinicalOutput.toJson()'),
      );
    });

    test('canonicalV2/localMemory shared restore uses deterministic helper', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();

      final restoreOwner = source.indexOf('void _restoreFromSummary(');
      final canonicalCase = source.indexOf(
        'case AiSessionSource.canonicalV2:',
        restoreOwner,
      );
      final localCase = source.indexOf(
        'case AiSessionSource.localMemory:',
        canonicalCase,
      );
      final loader = source.indexOf(
        'loadAiSessionExchangesTyped(',
        localCase,
      );
      final hydrate = source.indexOf(
        'AiSessionExchangeHydrator.hydrate(',
        loader,
      );
      final adopt = source.indexOf(
        '_adoptRestoredSessionIdentity(summary, p);',
        hydrate,
      );

      expect(restoreOwner, greaterThanOrEqualTo(0));
      expect(canonicalCase, greaterThan(restoreOwner));
      expect(localCase, greaterThan(canonicalCase));
      expect(loader, greaterThan(localCase));
      expect(hydrate, greaterThan(loader));
      expect(adopt, greaterThan(hydrate));

      final sharedBranch = source.substring(canonicalCase, adopt);
      expect(
        sharedBranch,
        contains('case AiSessionSource.localMemory:'),
      );
      expect(
        sharedBranch,
        contains('AiSessionExchangeHydrator.hydrate('),
      );
      expect(sharedBranch, contains('_ChatMsg.withId('));
      expect(
        sharedBranch,
        contains('clinicalOutput: exchange.clinicalOutput'),
      );
      expect(sharedBranch, isNot(contains("ex['assistantOutput']")));
    });

    test('canonical Plantao wiring cardinality remains one', () {
      final source = File('lib/screens/ai_screen.dart').readAsStringSync();
      expect(
        RegExp(
          RegExp.escape('canonicalPlantaoWiring: true'),
        ).allMatches(source).length,
        1,
      );
    });
  });
}
