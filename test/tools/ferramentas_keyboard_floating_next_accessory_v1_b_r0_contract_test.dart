import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  late List<String> sources;

  setUpAll(() {
    sources = [
      read('lib/screens/nephrology_tools_screen.dart'),
      read('lib/screens/cardio_tools_screen.dart'),
      read('lib/screens/electrolytes_tools_screen.dart'),
      read('lib/screens/hepatology_tools_screen.dart'),
    ];
  });

  test('four tabs use compact floating keyboard accessory instead of band', () {
    for (final source in sources) {
      expect(
        source,
        contains(
          'MEDCASES_FERRAMENTAS_KEYBOARD_FLOATING_NEXT_ACCESSORY_V1_B_R0',
        ),
      );
      expect(source, contains('right: 12,'));
      expect(source, contains('bottom: keyboardHeight + 8,'));
      expect(source, contains('height: 40,'));
      expect(source, contains('BoxConstraints(minWidth: 104)'));
      expect(source, contains('BorderRadius.circular(20)'));
      expect(
        source,
        isNot(
          contains(
            'left: 0,\n'
            '          right: 0,\n'
            '          bottom: keyboardHeight,',
          ),
        ),
      );
    }
  });

  test('floating accessory follows inverse light dark contrast', () {
    for (final source in sources) {
      expect(
        source,
        contains(
          'isDark ? Colors.white : const Color(0xFF1A1D23)',
        ),
      );
      expect(
        source,
        contains(
          'isDark ? const Color(0xFF111318) : Colors.white',
        ),
      );
    }
  });

  test('next action is localized PT and ES and last action remains OK', () {
    for (final source in sources) {
      expect(
        source,
        contains(
          "Localizations.localeOf(currentHost).languageCode == 'es'",
        ),
      );
      expect(
        source,
        contains(
          "last ? 'OK' : (isEs ? 'SIGUIENTE' : 'PRÓXIMO')",
        ),
      );
    }
  });

  test('keyboard navigation and viewport correction remain intact', () {
    for (final source in sources) {
      for (final token in const <String>[
        'Scrollable.ensureVisible(',
        'alignment: 0.24',
        'scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120)',
        'TextInputAction.next',
        'TextInputAction.done',
        'return 16.0 + safeBottom;',
        'return 114.0 + safeBottom;',
        'InternacionFirestoreService.updatePatientLaboratories(',
        'showToolsPatientSelectionSheet(',
      ]) {
        expect(source, contains(token), reason: token);
      }
    }
  });
}
