import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/streaming_text_drain.dart';

void main() {
  group('StreamingTextDrain', () {
    test('não drena conteúdo quando o buffer está vazio', () {
      expect(StreamingTextDrain.graphemesPerTick(0), 0);
      expect(StreamingTextDrain.take(''), (visible: '', remainder: ''));
    });

    test('mantém cadência delicada para backlog curto', () {
      expect(StreamingTextDrain.graphemesPerTick(1), 1);
      expect(StreamingTextDrain.graphemesPerTick(6), 1);
      expect(StreamingTextDrain.graphemesPerTick(7), 2);
    });

    test('acelera progressivamente quando o backlog cresce', () {
      expect(StreamingTextDrain.graphemesPerTick(18), 2);
      expect(StreamingTextDrain.graphemesPerTick(48), 4);
      expect(StreamingTextDrain.graphemesPerTick(96), 8);
      expect(StreamingTextDrain.graphemesPerTick(192), 16);
      expect(StreamingTextDrain.graphemesPerTick(500), 32);
    });

    test('preserva emoji composto como um único grafema', () {
      final result = StreamingTextDrain.take('👨‍⚕️abc');

      expect(result.visible, '👨‍⚕️');
      expect(result.remainder, 'abc');
    });

    test('preserva caractere com acento combinante', () {
      final result = StreamingTextDrain.take('a\u0301bc');

      expect(result.visible, 'a\u0301');
      expect(result.remainder, 'bc');
    });

    test('não perde nem duplica texto ao fatiar repetidamente', () {
      const original = '🩺 Conduta: hidratação, avaliação e reavaliação.';
      var pending = original;
      var rebuilt = '';

      while (pending.isNotEmpty) {
        final result = StreamingTextDrain.take(pending);
        expect(result.visible, isNotEmpty);
        rebuilt += result.visible;
        pending = result.remainder;
      }

      expect(rebuilt, original);
    });
  });

  group('revealTowards — cadência visual limitada', () {
    test('revealTowards limita rajadas a oito grafemas', () {
      final target = List.filled(80, 'a').join();

      final next = StreamingTextDrain.revealTowards(
        current: '',
        target: target,
        maxPerTick: 8,
      );

      expect(next.length, 8);
      expect(target.startsWith(next), isTrue);
    });

    test('revealTowards preserva emoji composto', () {
      final next = StreamingTextDrain.revealTowards(
        current: '',
        target: '👨‍⚕️abc',
        maxPerTick: 1,
      );

      expect(next, '👨‍⚕️');
    });

    test('revealTowards preserva acento combinante', () {
      final next = StreamingTextDrain.revealTowards(
        current: '',
        target: 'a\u0301bc',
        maxPerTick: 1,
      );

      expect(next, 'a\u0301');
    });

    test('revealTowards converge sem perda ou duplicação', () {
      const target = 'Hiponatremia: avaliação e tratamento seguro.';

      var visible = '';
      var guard = 0;

      while (visible != target && guard < 1000) {
        visible = StreamingTextDrain.revealTowards(
          current: visible,
          target: target,
          maxPerTick: 4,
        );

        guard++;
      }

      expect(visible, target);
      expect(guard, lessThan(1000));
    });

    test('correção retroativa converge ao snapshot definitivo', () {
      final next = StreamingTextDrain.revealTowards(
        current: 'abc',
        target: 'abd',
        maxPerTick: 1,
      );

      expect(next, 'abd');
    });
  });
}
