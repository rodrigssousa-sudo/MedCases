import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/gemini_service_v2.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';

String event({String? text, String? reason}) => 'data: ${jsonEncode({
          'candidates': [
            {
              if (text != null)
                'content': {
                  'parts': [
                    {'text': text}
                  ]
                },
              if (reason != null) 'finishReason': reason,
            }
          ]
        })}\n\n';

Future<List<GeminiChunk>> decode(String wire, {bool byteByByte = false}) {
  final bytes = utf8.encode(wire);
  return GeminiServiceV2.decodeResponseForTesting(Stream.fromIterable(
    byteByByte ? bytes.map((byte) => [byte]) : [bytes],
  )).toList();
}

void main() {
  test('grounding provenance survives metadata-only and terminal packets', () async {
    final ground = {'groundingChunks': [
      {'web': {'title': 'Source from transport', 'uri': 'https://example.org/source'}},
      null, {'web': 'malformed'},
    ]};
    final metadata = 'data: ${jsonEncode({'candidates': [{'groundingMetadata': ground}]})}\n\n';
    final chunks = await decode(event(text: 'Texto educativo.') + metadata + event(reason: 'STOP'), byteByByte: true);
    expect(chunks.map((c) => c.text).join(), 'Texto educativo.');
    expect(chunks.expand((c) => c.groundedSources), hasLength(1));
    expect(chunks.last.finishReason, 'STOP');
  });

  test('malformed grounding metadata does not erase a valid clinical delta', () async {
    final wire = 'data: ${jsonEncode({'candidates': [{'groundingMetadata': 'invalid', 'content': {'parts':[{'text':'Texto educativo.'}]}, 'finishReason':'STOP'}]})}\n\n';
    final chunks = await decode(wire);
    expect(chunks.single.text, 'Texto educativo.');
    expect(chunks.single.finishReason, 'STOP');
    expect(chunks.single.groundedSources, isEmpty);
  });

  for (final reason in ['STOP', 'MAX_TOKENS', 'SAFETY', 'RECITATION']) {
    test('terminal metadata after text is delivered exactly once: $reason',
        () async {
      final chunks = await decode(
          event(text: 'Contenido sintético.\n\n` Solic') +
              event(reason: reason));
      expect(
          chunks.map((c) => c.text).join(), 'Contenido sintético.\n\n` Solic');
      expect(chunks.where((c) => c.isDone), hasLength(1));
      expect(chunks.singleWhere((c) => c.isDone).finishReason, reason);
    });
  }

  test('UTF8 split across network bytes preserves Spanish and Portuguese',
      () async {
    const text = 'Síndrome — avaliação, ação e información.';
    final chunks =
        await decode(event(text: text, reason: 'STOP'), byteByByte: true);
    expect(chunks.map((c) => c.text).join(), text);
  });

  test('last terminal event without newline is not discarded', () async {
    final chunks = await decode(event(text: 'Contenido sintético.') +
        event(reason: 'STOP').trimRight());
    expect(chunks.where((c) => c.isDone), hasLength(1));
    expect(chunks.last.finishReason, 'STOP');
  });

  test('EOF with partial text carries interruption evidence for repair',
      () async {
    final chunks = await decode(event(text: 'Contenido sintético.\n\nSolic'));
    expect(chunks.last.finishReason, 'INCOMPLETE_STREAM');
    expect(chunks.where((c) => c.isDone), hasLength(1));
  });

  test('explicit terminal closes promptly without waiting for socket EOF',
      () async {
    final bytes = StreamController<List<int>>();
    final result =
        GeminiServiceV2.decodeResponseForTesting(bytes.stream).toList();
    bytes.add(utf8.encode(event(text: 'Texto sintético.', reason: 'STOP')));
    final chunks = await result.timeout(const Duration(seconds: 2));
    expect(chunks.single.finishReason, 'STOP');
    await bytes.close();
  });

  test(
      'duplicate terminals and trailing text cannot mutate a completed response',
      () async {
    final chunks = await decode(
        event(text: 'Texto sintético.', reason: 'STOP') +
            event(reason: 'STOP') +
            event(text: 'Duplicado.'));
    expect(chunks, hasLength(1));
    expect(chunks.single.text, 'Texto sintético.');
  });

  test('empty stream keeps the existing empty retry signal', () async {
    final chunks = await decode('');
    expect(chunks.single.isDone, isTrue);
    expect(chunks.single.finishReason, isNull);
    expect(chunks.single.text, isEmpty);
  });

  for (final reason in ['MAX_TOKENS', 'INCOMPLETE_STREAM']) {
    test('$reason reaches real Study finalization repair', () async {
      const partial = 'Contenido sintético.\n\nSolic';
      const complete = '${partial}itar información adicional.';
      final chunks = await decode(event(text: partial) +
          (reason == 'INCOMPLETE_STREAM' ? '' : event(reason: reason)));
      var repairs = 0;
      final coordinator = AiTruncationRepairCoordinator(
        repairPort: DelegatingAiTruncationRepairPort(runner: ({
          required originalText,
          required requestId,
          required isPlantaoMode,
          required appLanguage,
        }) async {
          repairs++;
          expect(originalText, partial);
          expect(isPlantaoMode, isFalse);
          return TruncationRepairResult.repaired(complete);
        }),
      );
      final outcome = await coordinator.process(
        originalText: chunks.map((c) => c.text).join(),
        requestId: 'synthetic-study',
        mode: AiRequestMode.estudo,
        locale: AiRequestLocale.es,
        providerFinishReason:
            chunks.where((c) => c.isDone).firstOrNull?.finishReason,
      );
      expect(repairs, 1);
      expect(outcome.text, complete);
      expect(outcome.wasRepaired, isTrue);
      final second = await coordinator.process(
        originalText: partial,
        requestId: 'synthetic-study',
        mode: AiRequestMode.estudo,
        locale: AiRequestLocale.es,
        providerFinishReason: reason,
      );
      expect(second.text, complete);
      expect(repairs, 1,
          reason: 'terminal handling must not duplicate recovery');
    });
  }
}
