import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/gemini_service_v2.dart';
import 'package:medcases/services/study/study_hybrid_response.dart';
import 'study_canonical_snapshot_test.dart' show records;

String prose(String s) => jsonEncode({'type': 'prose', 'text': s});
void main() {
  test('normal array delimiter is not an incomplete clinical block', () {
    final d = StudyHybridDecoder('pt');
    d.add('[${prose('Texto completo.')}, {"type":"end"}\n]');
    final delivery = d.close(normal: true);
    expect(delivery.committed, 1);
    expect(delivery.discardedIncomplete, 0);
  });
  test('hybrid reserves educational output after reasoning', () {
    expect(StudyHybridResponse.thinkingBudget, greaterThan(0));
    expect(StudyHybridResponse.maxOutputTokens - StudyHybridResponse.thinkingBudget,
        greaterThanOrEqualTo(8192));
  });
  test('native array commits children before terminal and discards failed tail', () async {
    final events = await StudyHybridResponse.stream(Stream.fromIterable([
      GeminiChunk(text: '[${prose('Explicação completa.')},${jsonEncode(records()[1])},'),
      const GeminiChunk(text: '{"type":"fact","clinical":'),
      GeminiChunk.error('http_504'),
    ]), language: 'pt').toList();
    expect(events.first.studyDelivery!.blocks.length, 2);
    expect(events.last.studyDelivery!.text, events.first.studyDelivery!.text);
    expect(events.last.studyDelivery!.interrupted, true);
  });
  test('native schema uses prose or existing strict numeric record schema', () {
    final schema = StudyHybridResponse.generationConfig['responseJsonSchema'] as Map;
    final choices = schema['items']['anyOf'] as List;
    expect(choices.length, 3);
    expect(choices[1]['properties']['type']['enum'], ['fact']);
    expect(choices[0]['properties']['type']['enum'], ['prose']);
    expect(choices[1]['required'], contains('clinical'));
  });
  test('bound final atom is complete without sentence punctuation', () {
    final r = records()[1];
    (r['clinical']['items'] as List).removeLast();
    (r['localization'] as Map).remove('f_one_end');
    final d = StudyHybridDecoder('pt');
    expect(d.add('${jsonEncode(r)}\n'), contains('2.5–5 mg/kg'));
    expect(d.delivery.blocks.single.numericBindingValid, true);
    expect(d.delivery.blocks.single.blockComplete, true);
  });
  test('unbound numeric prose cannot use typed-atom completeness', () {
    final d = StudyHybridDecoder('pt');
    expect(d.add('${prose('Exemplo: 2.5 mg/kg')}\n'), isEmpty);
    expect(d.delivery.blocks, isEmpty);
  });
  test('empty normal stream cannot report successful educational delivery',
      () async {
    final events = await StudyHybridResponse.stream(
            Stream.value(const GeminiChunk(
                text: '{"type":"end"}\n', isDone: true, finishReason: 'STOP')),
            language: 'pt')
        .toList();
    expect(events.last.isError, true);
    expect(events.last.studyDelivery!.terminal, StudyStreamState.stop);
    expect(events.last.studyDelivery!.blocks, isEmpty);
  });

  test('pretty printed fact commits only when fully framed', () {
    final d = StudyHybridDecoder('pt');
    final wire = const JsonEncoder.withIndent('  ').convert(records()[1]);
    expect(d.add(wire), isEmpty);
    expect(d.delivery.committed, 0);
    expect(d.add('\n'), contains('2.5–5 mg/kg'));
    expect(d.delivery.committed, 1);
  });
  test('unknown discriminator never becomes clinical output', () {
    final d = StudyHybridDecoder('pt');
    final r = records()[1];
    r['type'] = 'type';
    expect(d.add('${jsonEncode(r)}\n'), isEmpty);
    expect(d.diagnostics.single['reasonCode'], 'unsupported_record_type');
  });

  test('attestation counters, states and structural completeness', () {
    final d = StudyHybridDecoder('pt');
    for (final text in [
      '**Texto incompleto.',
      '# Título',
      '- ',
      'Texto (incompleto.',
      'Dose 20 mg.',
      'Tomar duas vezes ao dia.',
      'Administrar cinco miligramas.',
      'Administrar insulina cinco unidades.'
    ]) {
      expect(d.add('${prose(text)}\n'), isEmpty);
    }
    expect(d.add('${prose('Uma explicação completa.')}\n'), isNotEmpty);
    expect(d.delivery.received, 9);
    expect(d.delivery.attested, 1);
    expect(d.delivery.committed, 1);
    expect(d.delivery.blocks.single.state, StudyBlockState.committed);
    expect(d.delivery.blocks.single.blockComplete, true);
    expect(
        d.blockStates.values
            .where((s) => s == StudyBlockState.committed)
            .length,
        1);
    d.add('{"type":');
    expect(d.bufferedState, StudyBlockState.buffering);
    final closed = d.close(normal: false, terminal: StudyStreamState.timeout);
    expect(closed.terminal, StudyStreamState.timeout);
    expect(closed.discardedIncomplete, greaterThan(0));
    expect(closed.blocks.single.blockSanitized, true);
  });
  for (final error in ['timeout', 'http_504', 'stream_error']) {
    test('$error retains exact committed block objects and never flushes tail',
        () async {
      final events = await StudyHybridResponse.stream(
              Stream.fromIterable([
                GeminiChunk(
                    text:
                        '${prose('Explicação completa.')}\n${jsonEncode(records()[1])}\n'),
                GeminiChunk(text: prose('Cauda não commitada.')),
                GeminiChunk.error(error)
              ]),
              language: 'pt')
          .toList();
      final first = events.first.studyDelivery!,
          last = events.last.studyDelivery!;
      expect(first.blocks.length, 2);
      expect(last.blocks.length, 2);
      expect(identical(first.blocks[0], last.blocks[0]), true);
      expect(identical(first.blocks[1], last.blocks[1]), true);
      expect(last.blocks[1].numericBinding, isNotNull);
      expect(last.text, first.text);
      expect(last.text, isNot(contains('Cauda')));
      expect(last.interrupted, true);
      expect(last.complete, false);
      expect(last.canContinue, true);
      expect(() => last.blocks.clear(), throwsUnsupportedError);
    });
  }
  test('normal completion does not recreate previously committed blocks',
      () async {
    final events = await StudyHybridResponse.stream(
            Stream.fromIterable([
              GeminiChunk(text: '${prose('Explicação completa.')}\n'),
              const GeminiChunk(
                  text: '{"type":"end"}', isDone: true, finishReason: 'STOP')
            ]),
            language: 'pt')
        .toList();
    expect(events.last.studyDelivery!.complete, true);
    expect(events.last.studyDelivery!.text, events.first.studyDelivery!.text);
    expect(
        identical(events.first.studyDelivery!.blocks.single,
            events.last.studyDelivery!.blocks.single),
        true);
  });
  test('stream exception keeps only committed prefix', () async {
    Stream<GeminiChunk> source() async* {
      yield GeminiChunk(text: '${prose('Texto seguro.')}\n{"type":');
      throw TimeoutException('test');
    }

    final events =
        await StudyHybridResponse.stream(source(), language: 'es').toList();
    expect(events.last.studyDelivery!.text, 'Texto seguro.\n\n');
    expect(events.last.studyDelivery!.interrupted, true);
  });
  test('closing blocks future deltas and cannot add error tail', () {
    final d = StudyHybridDecoder('pt');
    d.add('${prose('Texto seguro.')}\n');
    d.close(normal: false);
    expect(d.add('${prose('Texto tardio.')}\n'), isEmpty);
    expect(d.delivery.blocks.length, 1);
  });
  test('numeric record incomplete at timeout never commits', () async {
    final wire = jsonEncode(records()[1]);
    final events = await StudyHybridResponse.stream(
            Stream.fromIterable([
              GeminiChunk(
                  text:
                      '${prose('Texto seguro.')}\n${wire.substring(0, wire.length - 2)}'),
              GeminiChunk.error('timeout')
            ]),
            language: 'pt')
        .toList();
    expect(events.last.studyDelivery!.blocks.length, 1);
    expect(events.last.studyDelivery!.text, isNot(contains('mg/kg')));
  });
}
