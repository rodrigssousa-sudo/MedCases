import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  late String main;
  late String nefro;
  late String cardio;
  late String electro;
  late String hepato;

  setUpAll(() {
    main = read('lib/main.dart');
    nefro = read('lib/screens/nephrology_tools_screen.dart');
    cardio = read('lib/screens/cardio_tools_screen.dart');
    electro = read('lib/screens/electrolytes_tools_screen.dart');
    hepato = read('lib/screens/hepatology_tools_screen.dart');
  });

  test('MainShell hides global footer while Tools physical keyboard is open',
      () {
    expect(main, contains('final toolsKeyboardOpen = _tab == 4 &&'));
    expect(
      main,
      contains('MediaQuery.viewInsetsOf(scaffoldBodyCtx).bottom > 0'),
    );
    expect(main, contains('toolsKeyboardOpen ||'));
    expect(main, contains('labKeyboardOpen;'));
  });

  test('all four tabs collapse footer clearance while keyboard is open', () {
    for (final source in [nefro, cardio, electro, hepato]) {
      expect(
        source,
        contains('if (MediaQuery.viewInsetsOf(context).bottom > 0)'),
      );
      expect(source, contains('return 16.0 + safeBottom;'));
      expect(source, contains('return 114.0 + safeBottom;'));
    }
  });

  test('Nefro and Hepato do not double-resize or double-add viewInsets', () {
    for (final source in [nefro, hepato]) {
      expect(source, contains('resizeToAvoidBottomInset: false,'));
      expect(
        source,
        contains('height: _toolsMainShellFooterBottomInset(context),'),
      );
      expect(
        source,
        isNot(
          contains(
            '_toolsMainShellFooterBottomInset(context) +\n'
            '                          MediaQuery.of(context).viewInsets.bottom',
          ),
        ),
      );
    }
  });

  test('Cardio and Electro no longer add a second keyboard AnimatedPadding',
      () {
    for (final source in [cardio, electro]) {
      expect(
        source,
        isNot(
          contains(
            'final kbBottom = MediaQuery.of(context).viewInsets.bottom;',
          ),
        ),
      );
      expect(
        source,
        isNot(contains('padding: EdgeInsets.only(bottom: kbBottom),')),
      );
    }
  });

  test('canonical keyboard flow and clinical wiring remain intact', () {
    for (final source in [nefro, cardio, electro, hepato]) {
      for (final token in const <String>[
        'Scrollable.ensureVisible(',
        'alignment: 0.24',
        'scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 120)',
        'TextInputAction.next',
        'TextInputAction.done',
        'InternacionFirestoreService.updatePatientLaboratories(',
        'showToolsPatientSelectionSheet(',
      ]) {
        expect(source, contains(token), reason: token);
      }
    }
  });
}
