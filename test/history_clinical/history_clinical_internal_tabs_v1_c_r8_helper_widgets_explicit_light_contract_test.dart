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

void main() {
  late String history;
  late String mainSource;
  late String inlineChat;
  setUpAll(() {
    history = source('lib/screens/history_screen.dart');
    mainSource = source('lib/main.dart');
    inlineChat = source('lib/home_v2/components/chat/inline_chat_view.dart');
  });

  test('rota e baselines R3 R6 R7 permanecem', () {
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
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R7_SEX_SELECTOR_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R7_PRIVACY_SURFACE_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R7_EVOLUTION_SECTION_LIGHT',
      'HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R7_OUTCOME_SELECTOR_LIGHT',
    ]) {
      expect(history, contains(marker), reason: 'Baseline ausente: $marker');
    }
  });

  test('helpers reais estão presentes e ao menos um recebeu contrato R8', () {
    final targets = <String>[
      '_EditorFieldState',
      '_VitalSignsWidgetState',
      '_LabStructuredWidgetState',
      '_EcgStructuredWidgetState',
      '_EvolutionEditorCardState',
    ];
    var markerCount = 0;
    for (final owner in targets) {
      final block = classSlice(history, owner);
      markerCount += RegExp('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R8_')
          .allMatches(block)
          .length;
    }
    expect(markerCount, greaterThan(0));
    expect(history, contains('Color(0xFFECF1F3)'));
    expect(history, contains('Color(0xFFD8E0E7)'));
    expect(history, contains('Color(0xFF05070A)'));
    expect(history, contains('Color(0xFF4B5563)'));
  });

  test('wrappers, OCR e barra de áudio continuam presentes', () {
    for (final owner in <String>[
      '_EditorField',
      '_VitalSignsWidget',
      '_LabStructuredWidget',
      '_EcgStructuredWidget',
      '_EvolutionEditorCard',
      '_OcrExamButton',
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
      '_openOcrPicker',
      'onTap: onTapSmart',
      'onTap: onTapRelato',
      'onTap: onOrganizarIA',
      'SttHelper',
      'AiService.chat(',
      'Printing.',
      'RepaintBoundary',
      'saveHistory(',
      'deleteHistory(',
      'TextEditingController',
      'FocusNode',
      'dispose(',
      'initState(',
    ]) {
      expect(history, contains(token), reason: 'Contrato ausente: $token');
    }
    expect(inlineChat, contains('class'));
  });

  test('tokens dark e cores semânticas permanecem', () {
    for (final token in <String>[
      'Color(0xFF1A1D23)',
      'Color(0xFF252930)',
      'Color(0xFF2D3340)',
      'Color(0xFF374151)',
      'Color(0xFF10B981)',
      'Color(0xFF3B82F6)',
      'Color(0xFFEC4899)',
    ]) {
      expect(history, contains(token),
          reason: 'Token preservado ausente: $token');
    }
  });
}
