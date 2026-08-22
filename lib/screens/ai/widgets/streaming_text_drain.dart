import 'package:characters/characters.dart';

/// Fatia o buffer de streaming por grafemas Unicode completos.
///
/// A quantidade drenada cresce conforme o backlog para manter baixa latência,
/// sem despejar o texto inteiro em um único frame.
final class StreamingTextDrain {
  const StreamingTextDrain._();

  static int graphemesPerTick(int backlog) {
    if (backlog <= 0) return 0;
    if (backlog <= 6) return 1;
    if (backlog <= 18) return 2;
    if (backlog <= 48) return 4;
    if (backlog <= 96) return 8;
    if (backlog <= 192) return 16;
    return 32;
  }

  /// Avança o prefixo visível em direção ao snapshot acumulado mais recente.
  ///
  /// Nunca revela mais de [maxPerTick] grafemas em uma chamada.
  static String revealTowards({
    required String current,
    required String target,
    int maxPerTick = 8,
  }) {
    if (target.isEmpty || target == current) {
      return target;
    }

    if (!target.startsWith(current)) {
      return target;
    }

    final targetGraphemes = target.characters;
    final currentCount = current.characters.length;
    final targetCount = targetGraphemes.length;

    if (currentCount >= targetCount) {
      return target;
    }

    final backlog = targetCount - currentCount;
    final adaptive = graphemesPerTick(backlog);
    final safeLimit = maxPerTick < 1 ? 1 : maxPerTick;
    final step =
        adaptive > safeLimit ? safeLimit : adaptive;
    final nextCount = currentCount + step;

    return targetGraphemes
        .take(nextCount)
        .toString();
  }

  static ({String visible, String remainder}) take(String pending) {
    if (pending.isEmpty) {
      return (visible: '', remainder: '');
    }

    final graphemes = pending.characters;
    final takeCount = graphemesPerTick(graphemes.length);

    return (
      visible: graphemes.take(takeCount).toString(),
      remainder: graphemes.skip(takeCount).toString(),
    );
  }
}
