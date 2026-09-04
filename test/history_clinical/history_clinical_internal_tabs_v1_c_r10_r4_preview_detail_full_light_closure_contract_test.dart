import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();
String classSlice(String text, String name) {
  final pattern = RegExp('^\\s*class\\s+' + RegExp.escape(name) + r'\b[^\{]*\{',
      multiLine: true);
  final matches = pattern.allMatches(text).toList();
  expect(matches, hasLength(1), reason: name);
  final opening = text.indexOf('{', matches.single.start);
  var depth = 0;
  var quote = '';
  var lineComment = false;
  var blockComment = false;
  var escaped = false;
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
    if (quote.isNotEmpty) {
      if (escaped) {
        escaped = false;
      } else if (c == '\\') {
        escaped = true;
      } else if (c == quote) {
        quote = '';
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
      if (depth == 0) return text.substring(matches.single.start, i + 1);
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

  test('rota, footer e baselines anteriores permanecem', () {
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
      expect(history, contains(marker), reason: marker);
    }
  });

  test('roots e owners descobertos possuem fechamento light contextual', () {
    final owners = <String>[
      '_HistoryPreviewSheet',
      '_HistoryDetailState',
      '_HistoryHeroHeader',
      '_PreviewDocHeader',
      '_PHItem',
      '_PreviewSection',
      '_PreviewItem',
      '_PreviewItemHighlight',
      '_DrugChips',
      '_PngDivider',
      '_PngSection',
      '_PngField',
      '_PngAllergyField',
      '_PngDxSection',
      '_PngEvolution',
      '_PngOutcomeBadge'
    ];
    expect(owners, contains('_HistoryPreviewSheet'));
    expect(owners, contains('_HistoryDetailState'));
    for (final owner in owners) {
      final block = classSlice(history, owner);
      expect(block, contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R10_R4_'),
          reason: owner);
      expect(
          block,
          matches(RegExp(
              r'Theme\.of\([A-Za-z_]\w*\)\.brightness == Brightness\.dark')),
          reason: owner);
      expect(block, contains('isDarkR10 ?'), reason: owner);
    }
  });

  test('paleta light e valores dark coexistem sem remover semântica', () {
    for (final token in <String>[
      'Color(0xFFECF1F3)',
      'Color(0xFFD8E0E7)',
      'Color(0xFF05070A)',
      'Color(0xFF4B5563)'
    ]) {
      expect(history, contains(token), reason: token);
    }
    for (final token in <String>[
      'Color(0xFF1A1D23)',
      'Color(0xFF252930)',
      'Color(0xFF2D3340)',
      'Color(0xFF374151)',
      'Color(0xFFE8F0EC)',
      'Color(0xFF10B981)',
      'Color(0xFF3B82F6)',
      'Color(0xFFEC4899)',
      'Color(0xFFDC2626)',
      'Color(0xFFC5A365)'
    ]) {
      expect(history, contains(token), reason: token);
    }
  });

  test('token clínico ambíguo 0F1116 permanece fora da conversão automática',
      () {
    expect(history, contains('Color(0xFF0F1116)'));
  });

  test('funções clínicas permanecem em contagem idêntica à baseline real', () {
    final protectedCounts = <String, int>{
      'saveHistory(': 1,
      'deleteHistory(': 2,
      'Printing.': 2,
      'RepaintBoundary': 5,
      '_exportPdf': 2,
      '_exportPng': 2,
      '_copy': 2,
      'widget.onBack': 2,
      'widget.onEdit': 4,
      'widget.onDelete': 3,
      'SttHelper': 19,
      'AiService.chat(': 2,
      'FirebaseFirestore': 0,
      'Navigator': 14,
      'Clipboard': 2,
      'TextEditingController': 77,
      'FocusNode': 23,
      '_openOcrPicker': 2
    };
    for (final entry in protectedCounts.entries) {
      final count = RegExp(RegExp.escape(entry.key)).allMatches(history).length;
      expect(count, entry.value, reason: entry.key);
    }
    expect(inlineChat, contains('class'));
  });
}
