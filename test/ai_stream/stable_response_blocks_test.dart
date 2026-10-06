import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_stream/stable_response_blocks.dart';

void main() {
  test('final changed anchor retains complete final snapshot, not stale partial', () {
    final s = StableResponseBlocks();
    s.accept('## Tema\n**Resumo** seguro.\n');
    const finalText = '## Tema\nResumo seguro.\nTratamento de referência.\nMonitorização.';
    final result = s.accept(finalText, complete: true);
    expect(result, contains('Tratamento de referência.'));
    expect(result, contains('Monitorização.'));
    expect(result, isNot(contains('**Resumo**')));
    expect(s.accept(finalText, complete: true), result);
  });
  test('partial rewrite still cannot replace committed blocks', () {
    final s = StableResponseBlocks();
    final initial = s.accept('Primeiro.\n');
    expect(s.accept('Outro prefixo.\n'), initial);
  });
  test('same paragraph extension preserves prior blocks and appends once', () {
    final s = StableResponseBlocks();
    s.accept('Primeira frase. ', complete: true);
    final first = s.blocks.first;
    s.accept('Primeira frase. Segunda frase.', complete: true);
    s.accept('Primeira frase. Segunda frase.', complete: true);
    expect(s.blocks, [first, 'Segunda frase.']);
  });
  test('table is committed only as a complete block', () {
    final s = StableResponseBlocks();
    s.accept('## Tema\n| A | B |\n');
    expect(s.blocks.length, 1);
    s.accept('## Tema\n| A | B |\n|---|---|\n| 1 | 2 |\n');
    expect(s.blocks.length, 1);
    s.accept('## Tema\n| A | B |\n|---|---|\n| 1 | 2 |\nFim.\n');
    expect(s.blocks.length, 3);
    expect(s.blocks[1], contains('|---|---|'));
  });

  test('partial commit replay and final preserve order and identity', () {
    final s = StableResponseBlocks();
    expect(s.accept('## Tema\nPrimeiro'), '## Tema');
    s.accept('## Tema\nPrimeiro bloco.\n');
    final before = s.blocks;
    s.accept('## Tema\nPrimeiro bloco.\nSegundo bloco.\n');
    expect(s.blocks.take(before.length), before);
    s.accept('## Tema\nPrimeiro bloco.\nSegundo bloco.\n', complete: true);
    expect(s.blocks.length, 3);
  });
  test(
      'late context and final reordered prefix cannot replace committed blocks',
      () {
    final s = StableResponseBlocks();
    s.accept('Primeiro.\nSegundo.\n');
    final before = s.blocks;
    s.accept('Contexto tardio.\nSegundo.\nPrimeiro.\n', complete: true);
    expect(s.blocks, before);
  });
  test('incomplete tail waits and completion emits it once', () {
    final s = StableResponseBlocks();
    s.accept('Primeiro.\nÚltimo');
    expect(s.blocks.length, 1);
    s.accept('Primeiro.\nÚltimo', complete: true);
    s.accept('Primeiro.\nÚltimo', complete: true);
    expect(s.blocks.length, 2);
  });
}
