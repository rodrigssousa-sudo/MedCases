import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final files = <String, String>{
    'nefro':
        File('lib/screens/nephrology_tools_screen.dart').readAsStringSync(),
    'cardio': File('lib/screens/cardio_tools_screen.dart').readAsStringSync(),
    'electro':
        File('lib/screens/electrolytes_tools_screen.dart').readAsStringSync(),
    'hepato':
        File('lib/screens/hepatology_tools_screen.dart').readAsStringSync(),
  };

  group('Ferramentas modern input surface system V1-B-R2', () {
    test('all four tabs use white light page and wider CTA', () {
      for (final e in files.entries) {
        expect(e.value, contains('final bg = dark ? _kBg : Colors.white;'),
            reason: e.key);
        expect(e.value, contains('widthFactor: 0.72'), reason: e.key);
      }
    });

    test('all four tabs use subtle modern field surfaces', () {
      for (final e in files.entries) {
        expect(e.value, contains('const Color(0xFF20252D)'), reason: e.key);
        expect(e.value, contains('const Color(0xFFF7F9FB)'), reason: e.key);
        expect(e.value, contains('const Color(0xFF2A3039)'), reason: e.key);
      }
    });

    test('field geometry is compact and focus architecture stays wired', () {
      for (final e in files.entries) {
        expect(e.value,
            contains('EdgeInsets.symmetric(horizontal: 12, vertical: 6)'),
            reason: e.key);
        expect(e.value, contains('BorderRadius.circular(10)'), reason: e.key);
        expect(e.value, contains("node.hasFocus ? const Color(0xFF0D6B57)"),
            reason: e.key);
      }
    });

    test('clinical and persistence functions remain present', () {
      for (final e in files.entries) {
        for (final token in <String>[
          'void _calculate',
          'void _autofillFromSession',
          'InternacionFirestoreService.updatePatientLaboratories(',
          'showToolsPatientSelectionSheet(',
        ]) {
          expect(e.value, contains(token), reason: '${e.key}:$token');
        }
      }
    });
  });
}
