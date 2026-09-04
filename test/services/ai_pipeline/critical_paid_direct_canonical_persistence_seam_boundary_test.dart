import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart' show AppProvider;

String extractBetween(
  String source,
  String startToken,
  String endToken,
) {
  final start = source.indexOf(
    startToken,
  );

  final end = source.indexOf(
    endToken,
    start,
  );

  if (start < 0 || end <= start) {
    throw StateError(
      'Bloco não localizado: '
      '$startToken → $endToken',
    );
  }

  return source.substring(
    start,
    end,
  );
}

String extractValidCriticalBranch(
  String criticalRegion,
) {
  const guardToken = 'if (!_isFallbackText(paidText)) {';

  final guard = criticalRegion.indexOf(
    guardToken,
  );

  final branchElse = criticalRegion.indexOf(
    '} else if (kDebugMode) {',
    guard,
  );

  if (guard < 0 || branchElse <= guard) {
    throw StateError(
      'Ramo crítico válido não localizado.',
    );
  }

  return criticalRegion.substring(
    guard,
    branchElse,
  );
}

String extractCall(
  String source,
  String token,
) {
  final start = source.indexOf(
    token,
  );

  if (start < 0) {
    throw StateError(
      'Chamada não localizada: $token',
    );
  }

  final opening = source.indexOf(
    '(',
    start,
  );

  var depth = 0;

  for (var index = opening; index < source.length; index++) {
    final char = source[index];

    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;

      if (depth == 0) {
        return source.substring(
          start,
          index + 1,
        );
      }
    }
  }

  throw StateError(
    'Chamada sem fechamento: $token',
  );
}

void main() {
  late String providerSource;
  late String routerSource;
  late String criticalRegion;
  late String validBranch;
  late String gptSsePersistCall;

  setUpAll(() {
    providerSource = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();

    routerSource = File(
      'lib/services/ai_smart_router.dart',
    ).readAsStringSync();

    criticalRegion = extractBetween(
      providerSource,
      "if (effectivePriority == 'critical') {",
      '// ── BUILD 323',
    );

    validBranch = extractValidCriticalBranch(
      criticalRegion,
    );

    gptSsePersistCall = extractCall(
      providerSource,
      'final persistStatus = '
      'await persistAiExchangeOnce(',
    );
  });

  group(
    'R18.6S-R2 — critical paid direct persistence',
    () {
      test(
        'AppProvider continua compilável',
        () {
          expect(
            AppProvider,
            isNotNull,
          );
        },
      );

      test(
        'rota crítica possui uma persistência canônica',
        () {
          final calls = RegExp(
            r'await\s+persistAiExchangeOnce\s*\(',
          ).allMatches(
            criticalRegion,
          );

          expect(
            calls,
            hasLength(1),
          );

          expect(
            validBranch,
            contains(
              'context: activeSessionCtx',
            ),
          );

          expect(
            validBranch,
            contains(
              'userInput: input',
            ),
          );

          expect(
            validBranch,
            contains(
              'assistantOutput: paidText',
            ),
          );

          expect(
            validBranch,
            contains(
              'route=gemini_paid_critical_direct',
            ),
          );
        },
      );

      test(
        'vazio e fallback são guardas independentes',
        () {
          expect(
            providerSource,
            contains(
              'if (text.isEmpty) return false;',
            ),
          );

          expect(
            routerSource,
            contains(
              'if (response.isEmpty)',
            ),
          );

          expect(
            routerSource,
            contains(
              'text: response',
            ),
          );

          final fallbackGuard = validBranch.indexOf(
            'if (!_isFallbackText(paidText)) {',
          );

          final emptyGuard = validBranch.indexOf(
            'if (paidText.isNotEmpty)',
          );

          final persistence = validBranch.indexOf(
            'await persistAiExchangeOnce(',
          );

          expect(
            fallbackGuard,
            greaterThanOrEqualTo(0),
          );

          expect(
            emptyGuard,
            greaterThan(fallbackGuard),
          );

          expect(
            persistence,
            greaterThan(emptyGuard),
          );
        },
      );

      test(
        'ordem terminal vencedora permanece rígida',
        () {
          final sanitize = criticalRegion.indexOf(
            'final paidSanitized = '
            'AiSmartRouter.sanitizeAndCheck(',
          );

          final paidText = criticalRegion.indexOf(
            'final paidText = paidSanitized.text;',
            sanitize,
          );

          final fallbackGuard = criticalRegion.indexOf(
            'if (!_isFallbackText(paidText)) {',
            paidText,
          );

          final history = criticalRegion.indexOf(
            '_aiHistory',
            fallbackGuard,
          );

          final trim = criticalRegion.indexOf(
            'while (_aiHistory.length > 20) '
            '_aiHistory.removeAt(0);',
            history,
          );

          final emptyGuard = criticalRegion.indexOf(
            'if (paidText.isNotEmpty)',
            trim,
          );

          final persistence = criticalRegion.indexOf(
            'await persistAiExchangeOnce(',
            emptyGuard,
          );

          final branchElse = criticalRegion.indexOf(
            '} else if (kDebugMode) {',
            persistence,
          );

          final blocked = criticalRegion.indexOf(
            'critical_paid_fallback_blocked',
            branchElse,
          );

          final wrapped = criticalRegion.indexOf(
            'wrappedOnDone(paidText)',
            blocked,
          );

          final release = criticalRegion.indexOf(
            'ExternalToolLinkEngine.'
            'releaseCanonicalDecision(',
            wrapped,
          );

          final complete = criticalRegion.indexOf(
            '_completeAiRequestOnce('
            'thisRequestId);',
            release,
          );

          final positions = <int>[
            sanitize,
            paidText,
            fallbackGuard,
            history,
            trim,
            emptyGuard,
            persistence,
            branchElse,
            blocked,
            wrapped,
            release,
            complete,
          ];

          expect(
            positions.every(
              (position) => position >= 0,
            ),
            isTrue,
          );

          for (var index = 1; index < positions.length; index++) {
            expect(
              positions[index],
              greaterThan(
                positions[index - 1],
              ),
            );
          }
        },
      );

      test(
        'telemetria depende de sincronização',
        () {
          final persistence = validBranch.indexOf(
            'await persistAiExchangeOnce(',
          );

          final synced = validBranch.indexOf(
            'criticalPaidPersistStatus '
            'is SessionPersistSynced',
          );

          final telemetry = validBranch.indexOf(
            '_freeStreamTxn.emitPersistTelemetry(',
          );

          expect(
            persistence,
            greaterThanOrEqualTo(0),
          );

          expect(
            synced,
            greaterThan(persistence),
          );

          expect(
            telemetry,
            greaterThan(synced),
          );

          expect(
            validBranch,
            contains(
              'sessionId: '
              'activeSessionCtx.sessionId',
            ),
          );

          expect(
            validBranch,
            isNot(
              contains(
                'sessionId: thisRequestId',
              ),
            ),
          );
        },
      );

      test(
        'timeout preserva safe-card e complete sem persistir',
        () {
          final timeoutStart = criticalRegion.indexOf(
            'criticalTimeoutTimer = Timer',
          );

          final providerCall = criticalRegion.indexOf(
            'ProviderRouterService.callPaidProxy(',
            timeoutStart,
          );

          expect(
            timeoutStart,
            greaterThanOrEqualTo(0),
          );

          expect(
            providerCall,
            greaterThan(timeoutStart),
          );

          final timeoutRegion = criticalRegion.substring(
            timeoutStart,
            providerCall,
          );

          expect(
            timeoutRegion,
            contains(
              'wrappedOnDone('
              '_timeoutSafeCard(_lang))',
            ),
          );

          expect(
            timeoutRegion,
            contains(
              '_completeAiRequestOnce('
              'thisRequestId);',
            ),
          );

          expect(
            timeoutRegion,
            isNot(
              contains(
                'releaseCanonicalDecision(',
              ),
            ),
          );

          expect(
            timeoutRegion,
            isNot(
              contains(
                'persistAiExchangeOnce(',
              ),
            ),
          );
        },
      );

      test(
        'ramo fallback não persiste',
        () {
          final branchElse = criticalRegion.indexOf(
            '} else if (kDebugMode) {',
            criticalRegion.indexOf(
              'if (!_isFallbackText(paidText)) {',
            ),
          );

          final wrapped = criticalRegion.indexOf(
            'wrappedOnDone(paidText)',
            branchElse,
          );

          expect(
            branchElse,
            greaterThanOrEqualTo(0),
          );

          expect(
            wrapped,
            greaterThan(branchElse),
          );

          final blockedRegion = criticalRegion.substring(
            branchElse,
            wrapped,
          );

          expect(
            blockedRegion,
            contains(
              'critical_paid_fallback_blocked',
            ),
          );

          expect(
            blockedRegion,
            isNot(
              contains(
                'persistAiExchangeOnce(',
              ),
            ),
          );
        },
      );

      test(
        'falha crítica não persiste',
        () {
          final failureStart = criticalRegion.indexOf(
            '[AI_PROVIDER] critical_paid_failed',
          );

          expect(
            failureStart,
            greaterThanOrEqualTo(0),
          );

          final failureRegion = criticalRegion.substring(
            failureStart,
          );

          expect(
            failureRegion,
            contains(
              'wrappedOnDone('
              '_timeoutSafeCard(_lang))',
            ),
          );

          expect(
            failureRegion,
            isNot(
              contains(
                'persistAiExchangeOnce(',
              ),
            ),
          );
        },
      );

      test(
        'rota crítica é independente',
        () {
          expect(
            criticalRegion,
            isNot(
              contains(
                'tryPaidFallback(',
              ),
            ),
          );

          expect(
            RegExp(
              r'ProviderRouterService'
              r'\.callPaidProxy\s*\(',
            ).allMatches(
              criticalRegion,
            ),
            hasLength(1),
          );

          expect(
            criticalRegion,
            isNot(
              contains(
                'ProviderRouterService.callGptProxy(',
              ),
            ),
          );
        },
      );

      test(
        'existem seis costuras produtivas',
        () {
          final calls = RegExp(
            r'await\s+persistAiExchangeOnce\s*\(',
          ).allMatches(
            providerSource,
          );

          expect(
            calls,
            hasLength(6),
          );

          final activeContexts = RegExp(
            r'context:\s+activeSessionCtx',
          ).allMatches(
            providerSource,
          );

          expect(
            activeContexts,
            hasLength(5),
          );

          expect(
            gptSsePersistCall,
            contains(
              'context: sessionCtx',
            ),
          );
        },
      );

      test(
        'rota crítica não acessa Firestore diretamente',
        () {
          expect(
            validBranch,
            isNot(
              contains(
                'batchWriteAiExchange(',
              ),
            ),
          );

          expect(
            validBranch,
            isNot(
              contains(
                'saveAiSession(',
              ),
            ),
          );
        },
      );
    },
  );
}
