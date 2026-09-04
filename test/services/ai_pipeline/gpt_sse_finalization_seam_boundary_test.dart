import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String extractGptCompletedBlock(
  String source,
) {
  final start = source.indexOf(
    'case AiCompleted e:',
  );

  final end = source.indexOf(
    'case AiFailed e:',
    start,
  );

  if (start < 0 || end < 0 || end <= start) {
    throw StateError(
      'Bloco GPT SSE AiCompleted não localizado.',
    );
  }

  return source.substring(
    start,
    end,
  );
}

void main() {
  group(
    'GPT SSE canonical finalization seam',
    () {
      late String providerSource;
      late String completedBlock;
      late String processorSource;

      setUpAll(() {
        providerSource = File(
          'lib/providers/app_provider.dart',
        ).readAsStringSync();

        completedBlock = extractGptCompletedBlock(
          providerSource,
        );

        processorSource = File(
          'lib/services/ai_pipeline/'
          'ai_response_finalization_processor.dart',
        ).readAsStringSync();
      });

      test(
        'AppProvider importa o barrel uma vez',
        () {
          expect(
            RegExp(
              r"import\s+'../services/"
              r"ai_pipeline/"
              r"ai_pipeline_contracts\.dart';",
            ).allMatches(providerSource).length,
            1,
          );
        },
      );

      test(
        'GPT SSE possui um call site produtivo',
        () {
          expect(
            RegExp(
              r'AiResponseFinalizationProcessor'
              r'\s*\.\s*'
              r'withExistingImplementations'
              r'\s*\(\s*\)',
            ).allMatches(completedBlock).length,
            1,
          );

          expect(
            RegExp(
              r'responseProcessor'
              r'\s*\.\s*process\s*\(',
            ).allMatches(completedBlock).length,
            1,
          );
        },
      );

      test(
        'snapshot usa identidade canônica',
        () {
          expect(
            completedBlock,
            contains(
              'snapshot: FinalOutputSnapshot(',
            ),
          );

          expect(
            completedBlock,
            contains(
              'rawOutput: qaRawText',
            ),
          );

          expect(
            completedBlock,
            contains(
              'sessionId: '
              'activeSessionCtx.sessionId',
            ),
          );

          expect(
            completedBlock,
            contains(
              'parentRequestId: '
              'thisRequestId',
            ),
          );

          expect(
            completedBlock,
            contains(
              'frozenAt: '
              'DateTime.now().toUtc()',
            ),
          );
        },
      );

      test(
        'modo idioma e transporte são encaminhados',
        () {
          expect(
            completedBlock,
            contains(
              'AiRequestMode.estudo',
            ),
          );

          expect(
            completedBlock,
            contains(
              'AiRequestMode.plantao',
            ),
          );

          expect(
            completedBlock,
            contains(
              'AiRequestLocale.es',
            ),
          );

          expect(
            completedBlock,
            contains(
              'AiRequestLocale.pt',
            ),
          );

          expect(
            completedBlock,
            contains(
              'provider: e.usedProvider',
            ),
          );

          expect(
            completedBlock,
            contains(
              'attempt: e.attempt',
            ),
          );

          expect(
            completedBlock,
            contains(
              'structuredOutput: '
              'e.clinicalOutput',
            ),
          );
        },
      );

      test(
        'operações equivalentes legadas foram removidas',
        () {
          expect(
            completedBlock,
            isNot(
              contains(
                'final qaTruncCheck',
              ),
            ),
          );

          expect(
            completedBlock,
            isNot(
              contains(
                'TruncationInspector'
                '.inspect(qaRawText)',
              ),
            ),
          );

          expect(
            completedBlock,
            isNot(
              contains(
                'final qaRepairResult',
              ),
            ),
          );

          expect(
            completedBlock,
            isNot(
              contains(
                'AiService'
                '.repairTruncated(',
              ),
            ),
          );

          expect(
            completedBlock,
            isNot(
              contains(
                'final qaSanitized',
              ),
            ),
          );

          expect(
            completedBlock,
            isNot(
              contains(
                'AiSmartRouter'
                '.sanitizeAndCheck(',
              ),
            ),
          );
        },
      );

      test(
        'telemetria usa inspeção do processador',
        () {
          expect(
            completedBlock,
            contains(
              'finalizationOutcome'
              '.truncation?.inspection',
            ),
          );

          expect(
            completedBlock,
            contains(
              'TruncationInspector'
              '.emitTelemetry(',
            ),
          );
        },
      );

      test(
        'falha bloqueia a mutação de histórico e o finalizador',
        () {
          final readinessIndex = completedBlock.indexOf(
            '!finalizationOutcome.isReady',
          );

          final throwIndex = completedBlock.indexOf(
            'throw AiSafeOutputException(',
            readinessIndex,
          );

          final historyMutationIndex = completedBlock.indexOf(
            "'content': qaFinalText",
            throwIndex,
          );

          final finalizerIndex = completedBlock.indexOf(
            '_finalizeGptSuccessfulRequest(',
            historyMutationIndex,
          );

          expect(
            readinessIndex,
            greaterThanOrEqualTo(0),
          );

          expect(
            throwIndex,
            greaterThan(readinessIndex),
          );

          expect(
            historyMutationIndex,
            greaterThan(throwIndex),
          );

          expect(
            finalizerIndex,
            greaterThan(historyMutationIndex),
          );
        },
      );

      test(
        'stale guard permanece após texto canônico',
        () {
          final finalTextIndex = completedBlock.indexOf(
            'final qaFinalText',
          );

          final staleIndex = completedBlock.indexOf(
            'POST_SANITIZE_STALE',
            finalTextIndex,
          );

          expect(
            finalTextIndex,
            greaterThanOrEqualTo(0),
          );

          expect(
            staleIndex,
            greaterThan(finalTextIndex),
          );
        },
      );

      test(
        'histórico permanece antes do finalizador A-F',
        () {
          final historyMutationIndex = completedBlock.indexOf(
            "'content': qaFinalText",
          );

          final finalizerIndex = completedBlock.indexOf(
            '_finalizeGptSuccessfulRequest(',
            historyMutationIndex,
          );

          expect(
            historyMutationIndex,
            greaterThanOrEqualTo(0),
          );

          expect(
            finalizerIndex,
            greaterThan(historyMutationIndex),
          );
        },
      );

      test(
        'structured output validado segue ao A-F',
        () {
          expect(
            completedBlock,
            contains(
              'clinicalOutput: '
              'finalizationOutcome'
              '.structure?.clinicalOutput',
            ),
          );

          expect(
            completedBlock,
            isNot(
              contains(
                'clinicalOutput: '
                'e.clinicalOutput,',
              ),
            ),
          );
        },
      );

      test(
        'release interno ocorre uma vez em finally',
        () {
          final catchIndex = completedBlock.indexOf(
            'on AiSafeOutputException catch',
          );

          final finallyIndex = completedBlock.indexOf(
            '} finally {',
            catchIndex,
          );

          final releaseIndex = completedBlock.indexOf(
            'responseProcessor'
            '.release(thisRequestId)',
            finallyIndex,
          );

          expect(
            catchIndex,
            greaterThanOrEqualTo(0),
          );

          expect(
            finallyIndex,
            greaterThan(catchIndex),
          );

          expect(
            releaseIndex,
            greaterThan(finallyIndex),
          );

          expect(
            RegExp(
              r'responseProcessor'
              r'\s*\.\s*release'
              r'\s*\(\s*thisRequestId\s*\)',
            ).allMatches(completedBlock).length,
            1,
          );
        },
      );

      test(
        'etapas A-F permanecem externas',
        () {
          expect(
            providerSource,
            contains(
              'ClinicalNumericValidator'
              '.validate(',
            ),
          );

          expect(
            providerSource,
            contains(
              'persistAiExchangeOnce(',
            ),
          );

          expect(
            providerSource,
            contains(
              'ExternalToolLinkEngine'
              '.build(',
            ),
          );

          expect(
            providerSource,
            contains(
              'wrappedOnDone(safeOutput',
            ),
          );

          expect(
            processorSource,
            isNot(
              contains(
                'ClinicalNumericValidator'
                '.validate(',
              ),
            ),
          );

          expect(
            processorSource,
            isNot(
              contains(
                'persistAiExchangeOnce(',
              ),
            ),
          );

          expect(
            processorSource,
            isNot(
              contains(
                'ExternalToolLinkEngine'
                '.build(',
              ),
            ),
          );

          expect(
            processorSource,
            isNot(
              contains(
                'wrappedOnDone(',
              ),
            ),
          );
        },
      );

      test(
        'outras rotas continuam legadas',
        () {
          expect(
            'TruncationInspector.inspect('.allMatches(providerSource).length,
            greaterThan(0),
          );

          expect(
            'AiService.repairTruncated('.allMatches(providerSource).length,
            greaterThan(0),
          );

          expect(
            'AiSmartRouter.sanitizeAndCheck('.allMatches(providerSource).length,
            greaterThan(0),
          );
        },
      );
    },
  );
}
