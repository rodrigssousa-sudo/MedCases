import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  late String history;
  late String common;
  late String recorder;
  late String home;
  late String homeV2;

  setUpAll(() {
    history = read('lib/screens/history_screen.dart');
    common = read('lib/widgets/common_widgets.dart');
    recorder = read('lib/screens/clinical_recorder_sheet.dart');
    home = read('lib/screens/home_screen.dart');
    homeV2 = read('lib/home_v2/home_screen_v2.dart');
  });

  test('route and persistence owners remain untouched', () {
    expect(home, contains('onTabChange(3);'));
    expect(homeV2, contains('onTabChange: onTabChange,'));
    expect(history, contains('saveHistory('));
    expect(history, contains('deleteHistory('));
  });

  test('sex selector is one solid segmented surface', () {
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R14_SEX_SOLID_SEGMENTED'),
    );
    expect(history, contains('activeColor: const Color(0xFF3B82F6)'));
    expect(history, contains('activeColor: const Color(0xFFEC4899)'));
    expect(history, isNot(contains('withOpacity(0.22)')));
  });

  test('keyboard overscroll is reduced and content has breathing', () {
    expect(
      history,
      contains('ScrollViewKeyboardDismissBehavior.onDrag'),
    );
    expect(
      RegExp(
        r'MediaQuery\.viewInsetsOf\(context\)\.bottom\s*>\s*0'
        r'\s*\?\s*22\s*:\s*18',
      ).hasMatch(history),
      isTrue,
    );
    expect(
      RegExp(
        r'MediaQuery\.of\(context\)\.viewInsets\.bottom'
        r'\s*\+\s*88',
      ).hasMatch(common),
      isTrue,
    );
    expect(
      common,
      contains('scrollPadding: EdgeInsets.only('),
    );
    expect(
      common,
      isNot(
        contains(
          'MediaQuery.of(context).viewInsets.bottom + 140',
        ),
      ),
    );
  });

  test('vital BorderSide matcher accepts compact and formatted Dart', () {
    final matcher = RegExp(
      r'const\s+BorderSide\s*\(\s*'
      r'color\s*:\s*Color\(0xFF6B7280\)\s*,\s*'
      r'width\s*:\s*1\.0\s*,?\s*\)',
      multiLine: true,
    );

    expect(
      matcher.hasMatch(
        'const BorderSide(color: Color(0xFF6B7280), width: 1.0)',
      ),
      isTrue,
    );
    expect(
      matcher.hasMatch(
        'const BorderSide(\n'
        '  color: Color(0xFF6B7280),\n'
        '  width: 1.0,\n'
        ')',
      ),
      isTrue,
    );
  });

  test('vital signs are cardless and neutral', () {
    expect(history, contains('cardBg.withOpacity(0)'));
    expect(
      history,
      contains('MediaQuery.of(context).viewInsets.bottom + 88'),
    );
    expect(
      RegExp(
        r'const\s+BorderSide\s*\(\s*'
        r'color\s*:\s*Color\(0xFF6B7280\)\s*,\s*'
        r'width\s*:\s*1\.0\s*,?\s*\)',
        multiLine: true,
      ).hasMatch(history),
      isTrue,
    );
  });

  test('color rewrite never corrupts Colors.white opacity tokens', () {
    for (final suffix in <String>['24', '30', '38', '54', '60', '70']) {
      expect(
        history,
        isNot(
          contains('const Color(0xFF252930)$suffix'),
        ),
      );
    }
    expect(history, isNot(contains('const const')));
  });

  test('lab and ECG no longer use dominant light strips', () {
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R14_LAB_DARK'),
    );
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R14_ECG_DARK'),
    );
    expect(history, contains('fillColor: const Color(0xFF2D3340)'));
  });

  test('AI controls use Medcases Intelligent visual family', () {
    expect(history, contains('const Color(0xFF14213D)'));
    expect(history, contains('const Color(0xFF172A46)'));
    expect(history, contains('const Color(0xFF147D64)'));
    expect(history, contains('const Color(0xFF10B981)'));
  });

  test('numeric keyboard hides dictation and exposes next and OK', () {
    expect(history, contains('numericKeyboardMode'));
    expect(history, contains('focusedWidget is EditableText'));
    expect(history, contains('focusedWidget.keyboardType'));
    expect(history, contains("'Próximo'"));
    expect(history, contains("'OK'"));
    expect(
      history,
      contains('onTap: () => FocusScope.of(context).nextFocus()'),
    );
    expect(history, contains('FocusScope.of(context).unfocus()'));
  });

  test('clinical OCR dictation and recorder contracts remain', () {
    for (final token in <String>[
      '_openOcrPicker',
      '_toggleSmartDictaphone',
      '_showOrganizarIASheet',
      'onTap: onTapSmart',
      'onTap: onTapRelato',
      'onTap: onOrganizarIA',
      'class _HistoryPreviewSheet',
    ]) {
      expect(history, contains(token), reason: token);
    }

    expect(recorder, contains('RecorderMode.continuous'));
    expect(recorder, contains('RecorderMode.soapBlocks'));
    expect(recorder, contains('onManual();'));
  });
}
