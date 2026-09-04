import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart' show AppProvider;

String extractBetween(String source, String startToken, String endToken) {
  final start = source.indexOf(startToken);
  final end = source.indexOf(endToken, start);

  if (start < 0 || end <= start) {
    throw StateError('Bloco não localizado: $startToken → $endToken');
  }

  return source.substring(start, end);
}

String extractGeminiFreeTerminal(String source) {
  const persistToken = 'final freePersistStatus = await persistAiExchangeOnce(';

  final persist = source.indexOf(persistToken);

  if (persist < 0) {
    throw StateError('Persistência Gemini Free não localizada.');
  }

  final start = source.lastIndexOf(
    'if (chunk.isDone && !chunk.isError) {',
    persist,
  );

  final end = source.indexOf('onError: (e) async {', persist);

  if (start < 0 || end <= persist) {
    throw StateError('Terminal Gemini Free não delimitado.');
  }

  return source.substring(start, end);
}

void main() {
  late String source;
  late String freeTerminal;
  late String persistMethod;
  late String upsertHelper;

  setUpAll(() {
    source = File('lib/providers/app_provider.dart').readAsStringSync();

    freeTerminal = extractGeminiFreeTerminal(source);

    persistMethod = extractBetween(
      source,
      'Future<SessionPersistStatus> persistAiExchangeOnce({',
      'String _generateConversationTitle(',
    );

    upsertHelper = extractBetween(
      source,
      'void _upsertLocalSessionIndex({',
      'void _mergeIntoSummaries(',
    );
  });

  group('R18.6N-R5 — Gemini Free Firebase persistence', () {
    test('AppProvider continua compilável', () {
      expect(AppProvider, isNotNull);
    });

    test('terminal possui uma única persistência canônica', () {
      final calls = RegExp(
        r'await\s+persistAiExchangeOnce\s*\(',
      ).allMatches(freeTerminal);

      expect(calls, hasLength(1));

      expect(freeTerminal, contains('context: activeSessionCtx'));

      expect(freeTerminal, contains('userInput: input'));

      expect(freeTerminal, contains('assistantOutput: finalText'));

      expect(freeTerminal, isNot(contains('batchWriteAiExchange(')));

      expect(freeTerminal, isNot(contains('saveAiSession(')));
    });

    test('requestId não substitui o sessionId canônico', () {
      expect(freeTerminal, contains('sessionId: activeSessionCtx.sessionId'));

      expect(freeTerminal, contains(r'requestId=$thisRequestId'));

      expect(
        freeTerminal,
        isNot(
          contains(
            '_freeStreamTxn.emitPersistTelemetry('
            'sessionId: thisRequestId);',
          ),
        ),
      );
    });

    test('assistantPersisted só é marcado após sync', () {
      final persist = freeTerminal.indexOf('await persistAiExchangeOnce(');

      final guard = freeTerminal.indexOf(
        'freePersistStatus is SessionPersistSynced',
      );

      final telemetry = freeTerminal.indexOf(
        '_freeStreamTxn.emitPersistTelemetry(',
      );

      expect(persist, greaterThanOrEqualTo(0));
      expect(guard, greaterThan(persist));
      expect(telemetry, greaterThan(guard));

      expect(freeTerminal, contains('route=gemini_free_chunk_isDone'));

      expect(
        freeTerminal,
        contains(r'status=${freePersistStatus.runtimeType}'),
      );
    });

    test('ordem terminal permanece rígida', () {
      final tokens = <String>[
        'final finalText = '
            '_applyPlantaoClinicalRegimenOutputGuard(',
        'assistantOutput: sanitized?.text ?? barrierText',
        '_aiHistory',
        'await persistAiExchangeOnce(',
        'final resolvedLink = '
            'ExternalToolLinkEngine.build(',
        'wrappedOnDone(freeUiText, freeClinicalOutput)',
        'ExternalToolLinkEngine.'
            'releaseCanonicalDecision(',
        '_completeAiRequestOnce(thisRequestId)',
      ];

      final positions = tokens.map(freeTerminal.indexOf).toList();

      expect(positions.every((position) => position >= 0), isTrue);

      for (var index = 1; index < positions.length; index++) {
        expect(positions[index], greaterThan(positions[index - 1]));
      }
    });

    test('seis rotas vencedoras persistem nesta fase', () {
      final calls = RegExp(
        r'await\s+persistAiExchangeOnce\s*\(',
      ).allMatches(source);

      expect(calls, hasLength(6));
    });

    test('método canônico trata falhas antes do read model', () {
      final batch = persistMethod.indexOf(
        'FirestoreService.batchWriteAiExchange(',
      );

      final permissionDenied = persistMethod.indexOf(
        'if (batchResult.permissionDenied)',
      );

      final failed = persistMethod.indexOf('if (!batchResult.ok)');

      final upsert = persistMethod.indexOf('_upsertLocalSessionIndex(');

      final synced = persistMethod.indexOf(
        'return const SessionPersistSynced();',
      );

      expect(batch, greaterThanOrEqualTo(0));
      expect(permissionDenied, greaterThan(batch));
      expect(failed, greaterThan(permissionDenied));
      expect(upsert, greaterThan(failed));
      expect(synced, greaterThan(upsert));
    });

    test('upsert atualiza summaries e notifica listeners', () {
      expect(upsertHelper, contains('_localAiSessionIndex'));

      expect(upsertHelper, contains('final summary = AiSessionSummary('));

      expect(upsertHelper, contains('_mergeIntoSummaries([summary])'));

      expect(upsertHelper, contains('notifyListeners()'));

      final indexMutation = upsertHelper.indexOf('_localAiSessionIndex');

      final summary = upsertHelper.indexOf('final summary = AiSessionSummary(');

      final merge = upsertHelper.indexOf('_mergeIntoSummaries([summary])');

      final notify = upsertHelper.indexOf('notifyListeners()');

      expect(indexMutation, greaterThanOrEqualTo(0));

      expect(summary, greaterThan(indexMutation));

      expect(merge, greaterThan(summary));

      expect(notify, greaterThan(merge));
    });
  });
}
