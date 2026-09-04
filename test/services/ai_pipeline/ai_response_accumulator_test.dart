import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_response_accumulator.dart';

void main() {
  group('AiResponseAccumulator', () {
    test(
      'concatena deltas brutos em ordem',
      () {
        final accumulator = AiResponseAccumulator();

        final first = accumulator.acceptDelta(
          'Con',
          attempt: 1,
        );

        final second = accumulator.acceptDelta(
          'duta',
          attempt: 1,
        );

        expect(first.accepted, isTrue);
        expect(first.delta, 'Con');
        expect(first.accumulatedText, 'Con');

        expect(second.accepted, isTrue);
        expect(second.delta, 'duta');
        expect(
          second.accumulatedText,
          'Conduta',
        );

        expect(accumulator.text, 'Conduta');
        expect(
          accumulator.acceptedUpdateCount,
          2,
        );
      },
    );

    test(
      'extrai somente o sufixo de snapshot crescente',
      () {
        final accumulator = AiResponseAccumulator();

        final first = accumulator.acceptSnapshot(
          'Con',
          attempt: 1,
        );

        final second = accumulator.acceptSnapshot(
          'Conduta',
          attempt: 1,
        );

        expect(first.delta, 'Con');
        expect(
          first.replacesAccumulatedText,
          isFalse,
        );

        expect(second.delta, 'duta');
        expect(
          second.accumulatedText,
          'Conduta',
        );
        expect(
          second.replacesAccumulatedText,
          isFalse,
        );
      },
    );

    test(
      'marca snapshot não monotônico como substituição',
      () {
        final accumulator = AiResponseAccumulator();

        accumulator.acceptSnapshot(
          'Resposta inicial',
          attempt: 1,
        );

        final replacement = accumulator.acceptSnapshot(
          'Texto substituto',
          attempt: 1,
        );

        expect(replacement.accepted, isTrue);
        expect(
          replacement.delta,
          'Texto substituto',
        );
        expect(
          replacement.accumulatedText,
          'Texto substituto',
        );
        expect(
          replacement.replacesAccumulatedText,
          isTrue,
        );
        expect(
          accumulator.text,
          'Texto substituto',
        );
      },
    );

    test(
      'suprime snapshot exatamente duplicado',
      () {
        final accumulator = AiResponseAccumulator();

        accumulator.acceptSnapshot(
          'Mesmo texto',
          attempt: 1,
        );

        final duplicate = accumulator.acceptSnapshot(
          'Mesmo texto',
          attempt: 1,
        );

        expect(duplicate.accepted, isFalse);
        expect(
          duplicate.disposition,
          AiAccumulationDisposition.duplicate,
        );
        expect(duplicate.delta, '');
        expect(
          duplicate.accumulatedText,
          'Mesmo texto',
        );
        expect(
          accumulator.acceptedUpdateCount,
          1,
        );
      },
    );

    test(
      'ignora delta e snapshot de attempt divergente',
      () {
        final accumulator = AiResponseAccumulator(
          expectedAttempt: 2,
        );

        final staleDelta = accumulator.acceptDelta(
          'Delta antigo',
          attempt: 1,
        );

        final staleSnapshot = accumulator.acceptSnapshot(
          'Snapshot antigo',
          attempt: 3,
        );

        expect(
          staleDelta.disposition,
          AiAccumulationDisposition.staleAttempt,
        );
        expect(
          staleSnapshot.disposition,
          AiAccumulationDisposition.staleAttempt,
        );
        expect(accumulator.text, isEmpty);
        expect(
          accumulator.acceptedUpdateCount,
          0,
        );
      },
    );

    test(
      'ignora conteúdo vazio sem alterar estado',
      () {
        final accumulator = AiResponseAccumulator();

        final emptyDelta = accumulator.acceptDelta(
          '',
          attempt: 1,
        );

        final emptySnapshot = accumulator.acceptSnapshot(
          '',
          attempt: 1,
        );

        expect(
          emptyDelta.disposition,
          AiAccumulationDisposition.empty,
        );
        expect(
          emptySnapshot.disposition,
          AiAccumulationDisposition.empty,
        );
        expect(accumulator.text, isEmpty);
      },
    );

    test(
      'seal bloqueia todas as atualizações posteriores',
      () {
        final accumulator = AiResponseAccumulator();

        accumulator.acceptDelta(
          'Resposta final',
          attempt: 1,
        );

        expect(accumulator.seal(), isTrue);
        expect(accumulator.seal(), isFalse);
        expect(accumulator.isSealed, isTrue);

        final lateDelta = accumulator.acceptDelta(
          ' tardia',
          attempt: 1,
        );

        final lateSnapshot = accumulator.acceptSnapshot(
          'Snapshot tardio',
          attempt: 1,
        );

        expect(
          lateDelta.disposition,
          AiAccumulationDisposition.sealed,
        );
        expect(
          lateSnapshot.disposition,
          AiAccumulationDisposition.sealed,
        );
        expect(
          accumulator.text,
          'Resposta final',
        );
        expect(
          accumulator.acceptedUpdateCount,
          1,
        );
      },
    );

    test(
      'mantém isolamento entre tentativas',
      () {
        final attemptOne = AiResponseAccumulator(
          expectedAttempt: 1,
        );

        final attemptTwo = AiResponseAccumulator(
          expectedAttempt: 2,
        );

        attemptOne.acceptDelta(
          'Resposta A',
          attempt: 1,
        );

        attemptTwo.acceptDelta(
          'Resposta B',
          attempt: 2,
        );

        expect(attemptOne.text, 'Resposta A');
        expect(attemptTwo.text, 'Resposta B');

        expect(
          attemptOne
              .acceptDelta(
                ' inválida',
                attempt: 2,
              )
              .disposition,
          AiAccumulationDisposition.staleAttempt,
        );

        expect(
          attemptTwo
              .acceptDelta(
                ' inválida',
                attempt: 1,
              )
              .disposition,
          AiAccumulationDisposition.staleAttempt,
        );
      },
    );
  });
}
