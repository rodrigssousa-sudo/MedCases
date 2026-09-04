import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/well_formed_utf16.dart';

void main() {
  group('WellFormedUtf16 V1-B-R0', () {
    test('ordinary clinical text stays byte-semantically identical', () {
      const input = 'Dose, diluição, classificação e monitorização.';
      expect(WellFormedUtf16.normalize(input), input);
      expect(WellFormedUtf16.isWellFormed(input), isTrue);
    });

    test('valid supplementary scalar is preserved', () {
      final input = 'A${String.fromCharCode(0x1F6A8)}B';
      expect(WellFormedUtf16.normalize(input), input);
      expect(WellFormedUtf16.isWellFormed(input), isTrue);
    });

    test('orphan high surrogate is replaced', () {
      final malformed = String.fromCharCodes(<int>[0x41, 0xD800, 0x42]);
      final normalized = WellFormedUtf16.normalize(malformed);
      expect(normalized, 'A\uFFFDB');
      expect(WellFormedUtf16.isWellFormed(normalized), isTrue);
    });

    test('orphan low surrogate is replaced', () {
      final malformed = String.fromCharCodes(<int>[0x41, 0xDC00, 0x42]);
      final normalized = WellFormedUtf16.normalize(malformed);
      expect(normalized, 'A\uFFFDB');
      expect(WellFormedUtf16.isWellFormed(normalized), isTrue);
    });

    test('truncate never splits an emoji surrogate pair', () {
      final input = 'AB${String.fromCharCode(0x1F6A8)}CD';
      expect(WellFormedUtf16.truncate(input, 3), 'AB🚨');
      expect(
        WellFormedUtf16.truncate(input, 3, appendEllipsis: true),
        'AB🚨…',
      );
    });
  });
}
