import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String src;
  setUpAll(() => src = File('lib/screens/history_screen.dart').readAsStringSync());

  test('expanded Ditado e IA and action row use adaptive mic palette', () {
    expect(src.contains("'Ditado e IA'"), isTrue);
    expect(src.contains('color: micPrimary,'), isTrue);
    expect(src.contains('color: active ? const Color(0xFF10B981) : micSecondary,'), isTrue);
    expect(src.contains(': micSecondary,'), isTrue);
    expect(src.contains('color: busy ? const Color(0xFF8FD5B8) : micMuted,'), isTrue);
  });

  test('Lab and ECG labels values hints and neutral borders are adaptive', () {
    expect(src.contains("? const Color(0xFFE8F0EC)\n                : const Color(0xFF4B5563)"), isTrue);
    expect(src.contains("? const Color(0xFFE8F0EC)\n                  : const Color(0xFF05070A)"), isTrue);
    expect(src.contains("? Colors.white30\n                    : const Color(0xFF6B7280)"), isTrue);
    expect(src.contains("? const Color(0xFF374151)\n                      : const Color(0xFFD8E0E7)"), isTrue);
  });

  test('functional callbacks and clinical input flows remain present', () {
    for (final token in <String>[
      'onTapSmart', 'onTapRelato', 'onOrganizarIA', 'onToggleExpand',
      'onPrevField', 'onNextField', '_sync', '_DecimalInputFormatter',
      'FilteringTextInputFormatter.digitsOnly',
    ]) {
      expect(src.contains(token), isTrue, reason: token);
    }
  });
}
