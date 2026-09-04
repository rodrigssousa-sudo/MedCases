import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart' show AppProvider;

String extractBetween(
  String source,
  String startToken,
  String endToken,
) {
  final start = source.indexOf(startToken);
  final end = source.indexOf(endToken, start);

  if (start < 0 || end <= start) {
    throw StateError(
      'Bloco não localizado: $startToken → $endToken',
    );
  }

  return source.substring(start, end);
}

String extractCall(
  String source,
  String token,
) {
  final start = source.indexOf(token);

  if (start < 0) {
    throw StateError(
      'Chamada não localizada: $token',
    );
  }

  final opening = start + token.lastIndexOf('(');
  var depth = 0;

  for (var index = opening; index < source.length; index++) {
    final char = source[index];

    if (char == '(') {
      depth++;
    } else if (char == ')') {
      depth--;

      if (depth == 0) {
        var end = index + 1;

        while (end < source.length &&
            (source[end] == ' ' || source[end] == '\t')) {
          end++;
        }

        if (end < source.length && source[end] == ';') {
          end++;
        }

        return source.substring(
          start,
          end,
        );
      }
    }
  }

  throw StateError(
    'Chamada sem fechamento: $token',
  );
}

String extractSuccessBranch(
  String region, {
  required String textVariable,
  required String blockedLabel,
}) {
  final label = region.indexOf(
    blockedLabel,
  );

  final start = region.lastIndexOf(
    'if (!_isFallbackText($textVariable)) {',
    label,
  );

  final wrapped = region.indexOf(
    'wrappedOnDone($textVariable)',
    label,
  );

  final complete = region.indexOf(
    '_completeAiRequestOnce(thisRequestId);',
    wrapped,
  );

  if (label < 0 || start < 0 || wrapped <= label || complete <= wrapped) {
    throw StateError(
      'Ramo pago não localizado: $textVariable',
    );
  }

  return region.substring(
    start,
    complete + '_completeAiRequestOnce(thisRequestId);'.length,
  );
}

void main() {
  late String source;
  late String fallbackRegion;
  late String gptBranch;
  late String geminiBranch;
  late String criticalRegion;
  late String gptSsePersistCall;

  setUpAll(() {
    source = File(
      'lib/providers/app_provider.dart',
    ).readAsStringSync();

    fallbackRegion = extractBetween(
      source,
      'Future<bool> tryPaidFallback(String reason) async {',
      '// ── BUILD 245: Caminho crítico',
    );

    gptBranch = extractSuccessBranch(
      fallbackRegion,
      textVariable: 'gptText',
      blockedLabel: '[HISTORY_SANITIZER] '
          'gpt_layer2_blocked '
          'reason=isFallbackText',
    );

    geminiBranch = extractSuccessBranch(
      fallbackRegion,
      textVariable: 'paidText',
      blockedLabel: '[HISTORY_SANITIZER] '
          'paid_fallback_blocked '
          'reason=isFallbackText',
    );

    criticalRegion = extractBetween(
      source,
      "if (effectivePriority == 'critical') {",
      '// ── BUILD 323',
    );

    gptSsePersistCall = extractCall(
      source,
      'final persistStatus = '
      'await persistAiExchangeOnce(',
    );
  });

  group(
    'R18.6Q-R2 — paid fallback Firebase persistence',
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
        'GPT SSE preserva sessionCtx',
        () {
          expect(
            gptSsePersistCall,
            contains(
              'context: sessionCtx',
            ),
          );

          expect(
            gptSsePersistCall,
            contains(
              'assistantOutput: safeOutput',
            ),
          );

          expect(
            gptSsePersistCall,
            isNot(
              contains(
                'context: activeSessionCtx',
              ),
            ),
          );
        },
      );

      test(
        'GPT pago persiste somente texto válido',
        () {
          expect(
            gptBranch,
            contains(
              'if (gptText.isNotEmpty)',
            ),
          );

          expect(
            gptBranch,
            contains(
              'context: activeSessionCtx',
            ),
          );

          expect(
            gptBranch,
            contains(
              'userInput: input',
            ),
          );

          expect(
            gptBranch,
            contains(
              'assistantOutput: gptText',
            ),
          );

          expect(
            gptBranch,
            contains(
              'route=gpt_paid_fallback_layer2',
            ),
          );

          expect(
            RegExp(
              r'await\s+persistAiExchangeOnce\s*\(',
            ).allMatches(gptBranch),
            hasLength(1),
          );
        },
      );

      test(
        'Gemini pago persiste somente texto válido',
        () {
          expect(
            geminiBranch,
            contains(
              'if (paidText.isNotEmpty)',
            ),
          );

          expect(
            geminiBranch,
            contains(
              'context: activeSessionCtx',
            ),
          );

          expect(
            geminiBranch,
            contains(
              'userInput: input',
            ),
          );

          expect(
            geminiBranch,
            contains(
              'assistantOutput: paidText',
            ),
          );

          expect(
            geminiBranch,
            contains(
              'route=gemini_paid_fallback_layer3',
            ),
          );

          expect(
            RegExp(
              r'await\s+persistAiExchangeOnce\s*\(',
            ).allMatches(geminiBranch),
            hasLength(1),
          );
        },
      );

      test(
        'telemetria paga depende de SessionPersistSynced',
        () {
          for (final branch in <String>[
            gptBranch,
            geminiBranch,
          ]) {
            final persist = branch.indexOf(
              'await persistAiExchangeOnce(',
            );

            final synced = branch.indexOf(
              'is SessionPersistSynced',
            );

            final telemetry = branch.indexOf(
              '_freeStreamTxn.emitPersistTelemetry(',
            );

            expect(
              persist,
              greaterThanOrEqualTo(0),
            );

            expect(
              synced,
              greaterThan(persist),
            );

            expect(
              telemetry,
              greaterThan(synced),
            );

            expect(
              branch,
              contains(
                'sessionId: '
                'activeSessionCtx.sessionId',
              ),
            );

            expect(
              branch,
              isNot(
                contains(
                  'sessionId: thisRequestId',
                ),
              ),
            );
          }
        },
      );

      test(
        'ordem dos vencedores pagos permanece rígida',
        () {
          final branches = <String, String>{
            'gptText': gptBranch,
            'paidText': geminiBranch,
          };

          for (final entry in branches.entries) {
            final textVariable = entry.key;
            final branch = entry.value;

            final tokens = <String>[
              '_aiHistory',
              'while (_aiHistory.length > 20) '
                  '_aiHistory.removeAt(0);',
              'await persistAiExchangeOnce(',
              'wrappedOnDone($textVariable)',
              'ExternalToolLinkEngine.'
                  'releaseCanonicalDecision(',
              '_completeAiRequestOnce('
                  'thisRequestId);',
            ];

            final positions = tokens.map(branch.indexOf).toList();

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
          }
        },
      );

      test(
        'GPT pago continua antes de Gemini pago',
        () {
          final gpt = fallbackRegion.indexOf(
            'ProviderRouterService.callGptProxy(',
          );

          final gemini = fallbackRegion.indexOf(
            'ProviderRouterService.callPaidProxy(',
          );

          expect(
            gpt,
            greaterThanOrEqualTo(0),
          );

          expect(
            gemini,
            greaterThan(gpt),
          );

          expect(
            RegExp(
              r'ProviderRouterService'
              r'\.callGptProxy\s*\(',
            ).allMatches(fallbackRegion),
            hasLength(1),
          );

          expect(
            RegExp(
              r'ProviderRouterService'
              r'\.callPaidProxy\s*\(',
            ).allMatches(fallbackRegion),
            hasLength(1),
          );
        },
      );

      test(
        'falha conjunta não é persistida',
        () {
          final failureStart = fallbackRegion.indexOf(
            '[AI_PROVIDER] both_failed',
          );

          expect(
            failureStart,
            greaterThanOrEqualTo(0),
          );

          final failureRegion = fallbackRegion.substring(
            failureStart,
          );

          expect(
            failureRegion,
            isNot(
              contains(
                'await persistAiExchangeOnce(',
              ),
            ),
          );

          expect(
            failureRegion,
            contains(
              'wrappedOnError(instabilityMsg)',
            ),
          );
        },
      );

      test(
        'caminho crítico direto persiste somente texto sanitizado válido',
        () {
          expect(
            criticalRegion,
            contains(
              'ProviderRouterService.callPaidProxy(',
            ),
          );

          expect(
            criticalRegion,
            contains(
              'if (!_isFallbackText(paidText)) {',
            ),
          );

          expect(
            criticalRegion,
            contains(
              'if (paidText.isNotEmpty)',
            ),
          );

          expect(
            criticalRegion,
            contains(
              'await persistAiExchangeOnce(',
            ),
          );

          expect(
            criticalRegion,
            contains(
              'context: activeSessionCtx',
            ),
          );

          expect(
            criticalRegion,
            contains(
              'assistantOutput: paidText',
            ),
          );

          expect(
            criticalRegion,
            contains(
              'route=gemini_paid_critical_direct',
            ),
          );

          expect(
            criticalRegion,
            contains(
              'critical_paid_fallback_blocked',
            ),
          );
        },
      );

      test(
        'contextos refletem seis rotas canônicas',
        () {
          final activeContexts = RegExp(
            r'context:\s+activeSessionCtx',
          ).allMatches(source);

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
        'existem seis costuras produtivas',
        () {
          final calls = RegExp(
            r'await\s+persistAiExchangeOnce\s*\(',
          ).allMatches(
            source,
          );

          expect(
            calls,
            hasLength(6),
          );
        },
      );

      test(
        'rotas pagas não acessam Firestore diretamente',
        () {
          for (final branch in <String>[
            gptBranch,
            geminiBranch,
          ]) {
            expect(
              branch,
              isNot(
                contains(
                  'batchWriteAiExchange(',
                ),
              ),
            );

            expect(
              branch,
              isNot(
                contains(
                  'saveAiSession(',
                ),
              ),
            );
          }
        },
      );
    },
  );
}
