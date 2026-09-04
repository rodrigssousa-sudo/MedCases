/// Generic Unicode-scalar boundary for provider, UI and persistence text.
///
/// Dart strings may contain orphan UTF-16 surrogate code units. Flutter's
/// native paragraph builder rejects malformed strings. This utility replaces
/// orphan surrogates with U+FFFD and truncates by Unicode scalar values.
class WellFormedUtf16 {
  const WellFormedUtf16._();

  static String normalize(String input) {
    if (input.isEmpty) return input;

    final units = input.codeUnits;
    final out = StringBuffer();
    var i = 0;

    while (i < units.length) {
      final unit = units[i];

      if (unit >= 0xD800 && unit <= 0xDBFF) {
        if (i + 1 < units.length) {
          final low = units[i + 1];
          if (low >= 0xDC00 && low <= 0xDFFF) {
            final scalar =
                0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
            out.writeCharCode(scalar);
            i += 2;
            continue;
          }
        }
        out.writeCharCode(0xFFFD);
        i++;
        continue;
      }

      if (unit >= 0xDC00 && unit <= 0xDFFF) {
        out.writeCharCode(0xFFFD);
        i++;
        continue;
      }

      out.writeCharCode(unit);
      i++;
    }

    return out.toString();
  }

  static String truncate(
    String input,
    int maxScalars, {
    bool appendEllipsis = false,
  }) {
    if (maxScalars < 0) {
      throw ArgumentError.value(maxScalars, 'maxScalars');
    }

    final safe = normalize(input);
    final scalars = safe.runes.toList(growable: false);
    if (scalars.length <= maxScalars) return safe;

    final cut = String.fromCharCodes(scalars.take(maxScalars));
    return appendEllipsis ? '$cut…' : cut;
  }

  static bool isWellFormed(String input) => normalize(input) == input;
}
