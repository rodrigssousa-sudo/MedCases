import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/ai_finalization_transaction.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';

void main() {
  group(
    'AiResponseFinalizationProcessor boundary',
    () {
      late String source;

      setUpAll(() {
        source = File(
          'lib/services/ai_pipeline/'
          'ai_response_finalization_processor.dart',
        ).readAsStringSync();
      });

      test(
        'reutiliza FinalOutputSnapshot existente',
        () {
          final frozen = FinalOutputSnapshot(
            rawOutput: 'Texto congelado.',
            sessionId: 'session-boundary',
            parentRequestId: 'request-boundary',
            frozenAt: DateTime.utc(
              2026,
              7,
              22,
            ),
          );

          expect(
            frozen.rawOutput,
            'Texto congelado.',
          );

          expect(
            source,
            contains(
              'required FinalOutputSnapshot snapshot',
            ),
          );
        },
      );

      test(
        'não declara outra máquina de estados',
        () {
          expect(
            source,
            isNot(
              contains(
                'class AiFinalizationTransaction',
              ),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'class FinalOutputSnapshot',
              ),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'class SerialEventQueue',
              ),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'class TerminalSignal',
              ),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'Completer<TerminalSignal>',
              ),
            ),
          );
        },
      );

      test(
        'não assume propriedade terminal',
        () {
          expect(
            source,
            isNot(
              contains(
                'tryAcquireOwnership',
              ),
            ),
          );

          expect(
            source,
            isNot(
              contains('signalTerminal('),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'completeCoordinatorAtomically',
              ),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'tryMarkCoordinatorCompleted',
              ),
            ),
          );
        },
      );

      test(
        'não acessa AppProvider, UI ou FirestoreService',
        () {
          expect(
            source,
            isNot(
              contains('AppProvider'),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'FirestoreService',
              ),
            ),
          );

          expect(
            source,
            isNot(contains('Widget')),
          );

          expect(
            source,
            isNot(contains('AiScreen')),
          );

          expect(
            source,
            isNot(
              contains('HomeScreen'),
            ),
          );

          expect(
            source,
            isNot(contains('AiBubble')),
          );

          expect(
            source,
            isNot(
              contains('Markdown('),
            ),
          );
        },
      );

      test(
        'não persiste nem emite callbacks',
        () {
          expect(
            source,
            isNot(
              contains(
                'persistAiExchangeOnce',
              ),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'wrappedOnDone',
              ),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'onStructuredDone',
              ),
            ),
          );

          expect(
            source,
            isNot(
              contains(
                'ExternalToolLinkEngine.build',
              ),
            ),
          );
        },
      );

      test(
        'compõe somente módulos existentes',
        () {
          expect(
            source,
            contains(
              'AiTruncationRepairCoordinator',
            ),
          );

          expect(
            source,
            contains(
              'AiResponseSanitizer',
            ),
          );

          expect(
            source,
            contains(
              'AiResponseStructureParser',
            ),
          );

          expect(
            source,
            contains(
              'AiResponseResult',
            ),
          );

          expect(
            source,
            contains(
              'AiService.repairTruncated',
            ),
          );
        },
      );

      test(
        'factory não executa rede durante construção',
        () {
          final processor =
              AiResponseFinalizationProcessor.withExistingImplementations();

          expect(processor, isNotNull);

          expect(
            processor.truncationCoordinator.retainedRequestCount,
            0,
          );
        },
      );
    },
  );
}
