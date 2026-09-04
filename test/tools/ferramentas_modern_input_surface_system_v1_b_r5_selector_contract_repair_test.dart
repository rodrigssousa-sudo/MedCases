import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String classBlock(String source, String name) {
  final token = 'class $name';
  final start = source.indexOf(token);
  expect(start, greaterThanOrEqualTo(0), reason: name);
  final next = source.indexOf('\nclass ', start + token.length);
  return next < 0 ? source.substring(start) : source.substring(start, next);
}

void main() {
  final cardio =
      File('lib/screens/cardio_tools_screen.dart').readAsStringSync();

  group('Ferramentas V1-B-R5 selector contract repair', () {
    test('R2 modern input system remains active', () {
      expect(cardio, contains('final bg = dark ? _kBg : Colors.white;'));
      expect(
        cardio,
        contains(
          'final fill = dark ? const Color(0xFF20252D) '
          ': const Color(0xFFF7F9FB);',
        ),
      );
      expect(cardio, contains('EdgeInsets.fromLTRB(12, 6, 12, 6)'));
      expect(cardio, contains('Icon(_fieldIcon, size: 17, color: activeIcon)'));
      expect(cardio, contains('widthFactor: 0.72'));
    });

    test('sex selector restores homologated light semantic colors', () {
      final sex = classBlock(cardio, '_SexToggle');
      expect(sex, contains('Color(0xFFEFF6FF)'));
      expect(sex, contains('Color(0xFF1D4ED8)'));
      expect(sex, contains('Color(0xFFFDF2F8)'));
      expect(sex, contains('Color(0xFFBE185D)'));
      expect(
        sex,
        contains('color: isDk ? const Color(0xFF2D3340) : Colors.white'),
      );
    });

    test('sex selector restores homologated dark semantic colors', () {
      final sex = classBlock(cardio, '_SexToggle');
      expect(sex, contains('Color(0xFF3B82F6)'));
      expect(sex, contains('Color(0xFFEC4899)'));
      expect(sex, contains('Color(0xFF374151)'));
    });

    test('risk selector remains untouched', () {
      final risk = classBlock(cardio, '_ToggleRow');
      expect(risk, contains('Color(0xFFECFDF5)'));
      expect(risk, contains('Color(0xFF047857)'));
      expect(risk, contains('onTap: () => item.onChanged(!item.value)'));
    });
  });
}
