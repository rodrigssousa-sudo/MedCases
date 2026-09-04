import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

String classSlice(String text, String name) {
  final match =
      RegExp(r'class\s+' + RegExp.escape(name) + r'\b').firstMatch(text);
  expect(match, isNotNull, reason: 'Classe ausente: $name');
  final opening = text.indexOf('{', match!.start);
  var depth = 0;
  String? quote;
  var escaped = false;
  var lineComment = false;
  var blockComment = false;
  for (var i = opening; i < text.length; i++) {
    final c = text[i];
    final n = i + 1 < text.length ? text[i + 1] : '';
    if (lineComment) {
      if (c == '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (c == '*' && n == '/') {
        blockComment = false;
        i++;
      }
      continue;
    }
    if (quote != null) {
      if (escaped) {
        escaped = false;
      } else if (c == r'\') {
        escaped = true;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == '/' && n == '/') {
      lineComment = true;
      i++;
      continue;
    }
    if (c == '/' && n == '*') {
      blockComment = true;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return text.substring(match.start, i + 1);
    }
  }
  fail('Classe sem fechamento: $name');
}

String between(String text, String start, String end) {
  final s = text.indexOf(start);
  expect(s, greaterThanOrEqualTo(0), reason: 'Anchor inicial ausente: $start');
  final e = text.indexOf(end, s);
  expect(e, greaterThan(s), reason: 'Anchor final ausente: $end');
  return text.substring(s, e);
}

void main() {
  late String history;
  late String mainSource;
  late String inlineChat;
  setUpAll(() {
    history = source('lib/screens/history_screen.dart');
    mainSource = source('lib/main.dart');
    inlineChat = source('lib/home_v2/components/chat/inline_chat_view.dart');
  });

  test('rota produtiva, footer e baselines R3/R6 permanecem', () {
    expect(RegExp(r'\bHistoryScreen\s*\(').allMatches(mainSource).length, 1);
    expect(
        mainSource, contains('class _FloatingFooter extends StatefulWidget'));
    expect(history, isNot(contains('_FloatingFooter(')));
    for (final marker in <String>[
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_TABROW_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_FLATTAB_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_SCREEN_CANVAS_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R3_HISTORY_CARD_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R6_HISTORYEDITORSTATE_LIGHT',
    ]) {
      expect(history, contains(marker), reason: 'Baseline ausente: $marker');
    }
  });

  test('seletor sexo possui light clínico e mantém valores dark', () {
    final editor = classSlice(history, '_HistoryEditorState');
    final sex = between(editor, 'HISTORY_CLINICAL_V1_D_R14_SEX_SOLID_SEGMENTED',
        "_hcT(widget.p.lang, 'f_weight')");
    expect(sex,
        contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R7_SEX_SELECTOR_LIGHT'));
    expect(sex, contains('isDarkSex'));
    expect(sex, contains('Color(0xFFECF1F3)'));
    expect(sex, contains('Color(0xFFD8E0E7)'));
    expect(sex, contains('Color(0xFF4B5563)'));
    expect(sex, contains('Color(0xFF2D3340)'));
    expect(sex, contains('Color(0xFF374151)'));
  });

  test('privacidade e evolução possuem superfícies light sem remover dark', () {
    final editor = classSlice(history, '_HistoryEditorState');
    final privacy = between(editor, 'HISTORY_CLINICAL_V1_C_R8_PRIVACY_SURFACE',
        '// ── Seção 1: Anamnese');
    expect(
        privacy,
        contains(
            'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R7_PRIVACY_SURFACE_LIGHT'));
    expect(privacy, contains('Color(0xFFECF1F3)'));
    expect(privacy, contains('Color(0xFFD8E0E7)'));
    expect(privacy, contains('Color(0xFF05070A)'));
    expect(privacy, contains('Color(0xFF252930)'));
    expect(privacy, contains('Color(0xFF374151)'));

    final evolution = between(
        editor,
        'HISTORY_CLINICAL_V1_D_R6_EVOLUTION_METHOD_OWNER',
        '// ── Seção 6: Desfecho');
    expect(
        evolution,
        contains(
            'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R7_EVOLUTION_SECTION_LIGHT'));
    expect(evolution, contains('Color(0xFFECF1F3)'));
    expect(evolution, contains('Color(0xFFD8E0E7)'));
    expect(evolution, contains('Color(0xFF05070A)'));
    expect(evolution, contains('Color(0xFF252930)'));
  });

  test('desfecho inativo usa light clínico e preserva ramo dark antigo', () {
    final editor = classSlice(history, '_HistoryEditorState');
    final outcome = editor.substring(editor.indexOf('// ── Seção 6: Desfecho'));
    expect(
        outcome,
        contains(
            'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R7_OUTCOME_SELECTOR_LIGHT'));
    expect(outcome, contains('Color(0xFFECF1F3)'));
    expect(outcome, contains('Color(0xFFD8E0E7)'));
    expect(outcome, contains('Color(0xFF4B5563)'));
    expect(outcome, contains('Colors.white'));
    expect(outcome, contains('kBorder'));
    expect(
        outcome, isNot(contains('color: selected ? colors[i] : Colors.white')));
  });

  test('helpers, lógica clínica, áudio, IA e exportação continuam presentes',
      () {
    for (final owner in <String>[
      '_EditorField',
      '_VitalSignsWidget',
      '_LabStructuredWidget',
      '_EcgStructuredWidget',
      '_OcrExamButton',
      '_EvolutionEditorCard',
      '_MicControlBar',
      '_HistoryPreviewSheet',
      '_HistoryDetailState',
    ]) {
      expect(
          RegExp(r'class\s+' + RegExp.escape(owner) + r'\b')
              .allMatches(history)
              .length,
          1);
    }
    for (final token in <String>[
      'saveHistory(',
      'deleteHistory(',
      '_openOcrPicker',
      'Printing.',
      'RepaintBoundary',
      'TextEditingController',
      'FocusNode',
      'SttHelper',
      'AiService.chat(',
      'dispose(',
      'initState(',
    ]) {
      expect(history, contains(token), reason: 'Contrato ausente: $token');
    }
    expect(inlineChat, contains('class'));
  });
}
