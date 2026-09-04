import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Empty terminal defer contract', () {
    late String source;

    setUpAll(() {
      source = File('lib/providers/app_provider.dart').readAsStringSync();
    });

    int uniqueIndex(String fragment) {
      final first = source.indexOf(fragment);

      expect(
        first,
        greaterThanOrEqualTo(0),
        reason: 'Fragmento obrigatório ausente: $fragment',
      );

      expect(
        source.indexOf(fragment, first + fragment.length),
        equals(-1),
        reason: 'Fragmento deveria aparecer uma única vez: $fragment',
      );

      return first;
    }

    test(
      'terminal vazio inicial é adiado antes do ownership',
      () {
        final guard = uniqueIndex(
          '[EMPTY_TERMINAL_DEFER] source=chunk_isDone',
        );

        final ownership = uniqueIndex(
          "if (!tryAcquireTerminalOwnership('chunk_isDone')) return;",
        );

        expect(guard, lessThan(ownership));

        final localContract = source.substring(guard, ownership);

        expect(
          localContract,
          contains('action=wait_stream_onDone'),
        );

        expect(
          source.substring(
            source.lastIndexOf(
              'if (chunk.isDone && !chunk.isError)',
              guard,
            ),
            ownership,
          ),
          contains('accumulator.toString().trim().isEmpty'),
        );

        expect(
          source,
          contains(
            "tryAcquireTerminalOwnership('stream_onDone')",
          ),
        );
      },
    );

    test(
      'terminal vazio do retry é adiado antes do ownership',
      () {
        final guard = uniqueIndex(
          'source=retry_chunk_isDone',
        );

        final ownership = uniqueIndex(
          "if (!tryAcquireTerminalOwnership('retry_chunk_isDone'))",
        );

        expect(guard, lessThan(ownership));

        final localContract = source.substring(guard, ownership);

        expect(
          localContract,
          contains('action=wait_retry_onDone'),
        );

        expect(
          source.substring(
            source.lastIndexOf(
              'if (chunk.isDone && !chunk.isError)',
              guard,
            ),
            ownership,
          ),
          contains('accumulator.toString().trim().isEmpty'),
        );
      },
    );

    test(
      'retry_onDone mantém a escalada para fallback pago',
      () {
        expect(
          source,
          contains(
            "tryAcquireTerminalOwnership('retry_onDone')",
          ),
        );

        expect(
          source,
          contains(
            "tryPaidFallback('empty_retry_onDone')",
          ),
        );
      },
    );

    test(
      'respostas com conteúdo mantêm os finalizadores existentes',
      () {
        expect(
          source,
          contains(
            "tryAcquireTerminalOwnership('chunk_isDone')",
          ),
        );

        expect(
          source,
          contains(
            "tryAcquireTerminalOwnership('retry_chunk_isDone')",
          ),
        );

        expect(
          source,
          contains(
            'final rawText = accumulator.toString().trim();',
          ),
        );

        expect(
          source,
          contains(
            'final retryText = accumulator.toString().trim();',
          ),
        );
      },
    );
  });
}
