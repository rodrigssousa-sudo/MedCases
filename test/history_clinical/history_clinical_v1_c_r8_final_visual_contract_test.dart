import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();
String classBlock(String source, String name) {
  final m = RegExp('^class\\s+${RegExp.escape(name)}\\b', multiLine: true)
      .firstMatch(source);
  if (m == null) throw StateError('Class not found: $name');
  final opening = source.indexOf('{', m.start);
  var depth = 0;
  bool line = false, block = false;
  String? quote;
  for (var i = opening; i < source.length; i++) {
    final ch = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (line) {
      if (ch == '\n') line = false;
      continue;
    }
    if (block) {
      if (ch == '*' && next == '/') {
        block = false;
        i++;
      }
      continue;
    }
    if (quote != null) {
      if (ch == '\\') {
        i++;
        continue;
      }
      if (ch == quote) quote = null;
      continue;
    }
    if (ch == '/' && next == '/') {
      line = true;
      i++;
      continue;
    }
    if (ch == '/' && next == '*') {
      block = true;
      i++;
      continue;
    }
    if (ch == "'" || ch == '"') {
      quote = ch;
      continue;
    }
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(m.start, i + 1);
    }
  }
  throw StateError('Unclosed class: $name');
}

void main() {
  late String history, common, recorder, home, homeV2;
  setUpAll(() {
    history = read('lib/screens/history_screen.dart');
    common = read('lib/widgets/common_widgets.dart');
    recorder = read('lib/screens/clinical_recorder_sheet.dart');
    home = read('lib/screens/home_screen.dart');
    homeV2 = read('lib/home_v2/home_screen_v2.dart');
  });
  test('route and global footer contract remain canonical', () {
    expect(home, contains('onTabChange(3);'));
    expect(homeV2, contains('onTabChange: onTabChange,'));
    expect(history, isNot(contains('bottomNavigationBar:')));
    expect(history, isNot(contains('BottomAppBar(')));
  });
  test('tabs only use green active underline', () {
    final row = classBlock(history, '_HcTabRow');
    final state = classBlock(history, '_HcFlatTabState');
    expect(row, contains('class _HcTabRow extends StatelessWidget'));
    expect(row, isNot(contains('Container(width: 1, height: 14')));
    expect(row, isNot(contains('Color(0xFF00E5FF)')));
    expect(state, contains('Color(0xFF0E8000)'));
    expect(state, contains('left: 12'));
    expect(state, contains('right: 12'));
    expect(state, contains('bottom: 9'));
    expect(state, contains('height: 2'));
  });
  test('search and editor fields use compact default-preserving MedInput', () {
    final med = classBlock(common, 'MedInput');
    final screen = classBlock(history, '_HistoryScreenState');
    final field = classBlock(history, '_EditorFieldState');
    expect(med, contains('this.clinicalCompact = false'));
    expect(med, contains('this.prefixIcon'));
    expect(med, contains('Color(0xFF2D3340)'));
    expect(med, contains('Color(0xFF374151)'));
    expect(med, contains('Color(0xFF0E8000)'));
    expect(screen, contains('controller: _searchCtrl'));
    expect(screen, contains('onChanged: (v) => _searchQuery.value = v'));
    expect(screen, contains('prefixIcon: Icons.search_rounded'));
    expect(field, contains('clinicalCompact: true'));
  });
  test('list has one accent and flat Dx', () {
    final card = classBlock(history, '_HistoryCard');
    expect(card, contains('HISTORY_CLINICAL_V1_C_R8_LIST_SURFACE_BEGIN'));
    expect(card, contains('HISTORY_CLINICAL_V1_C_R8_DX_FLAT'));
    expect(card, isNot(contains('Color(0xFF065F46).withOpacity(0.08)')));
    expect(card, isNot(contains('left: BorderSide(')));
  });
  test('actual +NOVA owner is flat and keeps all three flows', () {
    final option = classBlock(recorder, '_FlowOption');
    expect(option, contains('MEDCASES_HC_CAPTURE_PREMIUM_FLOW_OPTION_V1_B_R0'));
    expect(option, isNot(contains('_kCardDecoration')));
    expect(recorder, contains('onManual();'));
    expect(recorder, contains('RecorderMode.continuous'));
    expect(recorder, contains('RecorderMode.soapBlocks'));
    expect(recorder, contains('onSoapData: onSoapData'));
  });
  test('editor preserves actions and uses canonical graphite green', () {
    final editor = classBlock(history, '_HistoryEditorState');
    expect(editor, contains('onTap: widget.onCancel'));
    expect(editor, contains('onTap: _showPreview'));
    expect(editor, contains('onTap: _save'));
    expect(editor, contains('widget.onSave(updated);'));
    expect(editor, contains('HISTORY_CLINICAL_V1_C_R8_EDITOR_ACTION_ROW'));
    expect(editor, contains('HISTORY_CLINICAL_V1_C_R8_PRIVACY_SURFACE'));
    expect(editor, contains('Color(0xFF0E8000)'));
    expect(editor, contains('Color(0xFF252930)'));
    expect(editor, isNot(contains('Color(0xFFAC2A2A)')));
  });
  test('clinical, OCR, dictation, AI and persistence contracts remain', () {
    for (final token in <String>[
      'saveHistory(',
      'deleteHistory(',
      '_openOcrPicker',
      '_startStt(',
      '_toggleSmartDictaphone',
      '_showOrganizarIASheet',
      'class _HistoryPreviewSheet',
      'class _EvolutionEditorCard'
    ]) {
      expect(history, contains(token), reason: 'Removed contract: $token');
    }
  });
}
