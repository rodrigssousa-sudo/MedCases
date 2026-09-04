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

String extractRetryRegion(String source) {
  const ownerToken = "if (!tryAcquireTerminalOwnership('retry_chunk_isDone'))";

  final owner = source.indexOf(ownerToken);
  final end = source.indexOf('onError: (_) async {', owner);

  if (owner < 0 || end <= owner) {
    throw StateError('Listener de retry não localizado.');
  }

  return source.substring(owner, end);
}

String extractRetrySuccessBranch(String retryRegion) {
  final guardMatch = RegExp(
    r'retryFinalText\s*=\s*_applyPlantaoClinicalRegimenOutputGuard\(',
  ).firstMatch(retryRegion);

  final start = guardMatch?.start ?? -1;

  final paidComment = retryRegion.indexOf('// Retry também veio vazio', start);

  final end = retryRegion.lastIndexOf('} else {', paidComment);

  if (start < 0 || paidComment <= start || end <= start) {
    throw StateError('Ramo de sucesso do retry não localizado.');
  }

  return retryRegion.substring(start, end);
}

void main() {
  late String source;
  late String retryRegion;
  late String successBranch;
  late String persistMethod;

  setUpAll(() {
    source = File('lib/providers/app_provider.dart').readAsStringSync();

    retryRegion = extractRetryRegion(source);

    successBranch = extractRetrySuccessBranch(retryRegion);

    persistMethod = extractBetween(
      source,
      'Future<SessionPersistStatus> persistAiExchangeOnce({',
      'String _generateConversationTitle(',
    );
  });

  group('R18.6P-R1 — Gemini Free retry Firebase persistence', () {
    test('AppProvider continua compilável', () {
      expect(AppProvider, isNotNull);
    });

    test('ramo vencedor possui uma persistência canônica', () {
      final calls = RegExp(
        r'await\s+persistAiExchangeOnce\s*\(',
      ).allMatches(successBranch);

      expect(calls, hasLength(1));

      expect(successBranch, contains('context: activeSessionCtx'));

      expect(successBranch, contains('userInput: input'));

      expect(successBranch, contains('assistantOutput: retryFinalText'));

      expect(successBranch, isNot(contains('batchWriteAiExchange(')));

      expect(successBranch, isNot(contains('saveAiSession(')));
    });

    test('requestId não substitui sessionId', () {
      expect(successBranch, contains('sessionId: activeSessionCtx.sessionId'));

      expect(successBranch, contains(r'requestId=$thisRequestId'));

      expect(successBranch, isNot(contains('sessionId: thisRequestId')));
    });

    test('telemetria de persistência depende de sync', () {
      final persist = successBranch.indexOf('await persistAiExchangeOnce(');

      final guard = successBranch.indexOf(
        'retryPersistStatus is SessionPersistSynced',
      );

      final telemetry = successBranch.indexOf(
        '_freeStreamTxn.emitPersistTelemetry(',
      );

      expect(persist, greaterThanOrEqualTo(0));

      expect(guard, greaterThan(persist));

      expect(telemetry, greaterThan(guard));

      expect(successBranch, contains('route=gemini_free_retry_chunk_isDone'));
    });

    test('ordem do ramo vencedor permanece rígida', () {
      final tokens = <String>[
        'retryFinalText =',
        '_applyPlantaoClinicalRegimenOutputGuard(',
        'assistantOutput: retryFinalText',
        'if (retryFinalText.isNotEmpty &&',
        '_aiHistory',
        'while (_aiHistory.length > 20) '
            '_aiHistory.removeAt(0);',
        'await persistAiExchangeOnce(',
        '_aiStreamActive = false;',
        'wrappedOnDone(retryFinalText, retryClinicalOutput);',
        'ExternalToolLinkEngine.'
            'releaseCanonicalDecision(',
        '_completeAiRequestOnce(thisRequestId)',
      ];

      final positions = tokens.map(successBranch.indexOf).toList();

      expect(positions.every((position) => position >= 0), isTrue);

      for (var index = 1; index < positions.length; index++) {
        expect(positions[index], greaterThan(positions[index - 1]));
      }
    });

    test('ramo vazio continua escalando para paid', () {
      expect(retryRegion, contains('// Retry também veio vazio'));

      final paidFallbackMatch = RegExp(
        r'await\s+tryPaidFallback\s*\(\s*'
        r"'empty_stream_after_retry'\s*,?\s*\)",
      ).firstMatch(retryRegion);

      expect(paidFallbackMatch, isNotNull);

      final successPersist = retryRegion.indexOf(
        'await persistAiExchangeOnce(',
      );

      final paidFallback = paidFallbackMatch?.start ?? -1;

      expect(paidFallback, greaterThan(successPersist));
    });

    test('existem seis costuras produtivas', () {
      final calls = RegExp(
        r'await\s+persistAiExchangeOnce\s*\(',
      ).allMatches(source);

      expect(
        calls,
        hasLength(6),
        reason:
            'GPT SSE, Gemini Free principal e '
            'Gemini Free retry e os dois fallbacks pagos e o caminho crítico pago direto devem persistir.',
      );
    });

    test('método canônico trata falhas antes do upsert', () {
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
  });
}
