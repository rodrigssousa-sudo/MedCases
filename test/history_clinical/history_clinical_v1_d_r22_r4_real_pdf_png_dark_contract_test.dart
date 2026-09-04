import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();
int findMatching(String source, int opening, String left, String right) {
  var depth = 0;
  var lineComment = false;
  var blockComment = false;
  String? quote;
  for (var i = opening; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (lineComment) {
      if (char == '\n') lineComment = false;
      continue;
    }
    if (blockComment) {
      if (char == '*' && next == '/') {
        blockComment = false;
        i++;
      }
      continue;
    }
    if (quote != null) {
      if (char == '\\') {
        i++;
        continue;
      }
      if (char == quote) quote = null;
      continue;
    }
    if (char == '/' && next == '/') {
      lineComment = true;
      i++;
      continue;
    }
    if (char == '/' && next == '*') {
      blockComment = true;
      i++;
      continue;
    }
    if (char == "'" || char == '"') {
      quote = char;
      continue;
    }
    if (char == left) depth++;
    if (char == right) {
      depth--;
      if (depth == 0) return i;
    }
  }
  throw StateError('span não fechado');
}

String classBlock(String source, String name) {
  final matches = RegExp('^\\s*class\\s+${RegExp.escape(name)}\\b[^\\{]*\\{',
          multiLine: true)
      .allMatches(source)
      .toList();
  expect(matches.length, 1, reason: 'owner duplicado/ausente: $name');
  final opening = source.indexOf('{', matches.single.start);
  final closing = findMatching(source, opening, '{', '}');
  return source.substring(matches.single.start, closing + 1);
}

String methodBlock(String source, String className, String methodName) {
  final owner = classBlock(source, className);
  for (final match
      in RegExp('\\b${RegExp.escape(methodName)}\\s*\\(').allMatches(owner)) {
    final paren = owner.indexOf('(', match.start);
    final closeParen = findMatching(owner, paren, '(', ')');
    var cursor = closeParen + 1;
    while (cursor < owner.length && RegExp(r'\s').hasMatch(owner[cursor]))
      cursor++;
    if (owner.startsWith('async', cursor)) {
      cursor += 5;
      while (cursor < owner.length && RegExp(r'\s').hasMatch(owner[cursor]))
        cursor++;
    }
    if (cursor < owner.length && owner[cursor] == '{') {
      final close = findMatching(owner, cursor, '{', '}');
      final lineStart = owner.lastIndexOf('\n', match.start) + 1;
      return owner.substring(lineStart, close + 1);
    }
  }
  throw StateError('método ausente: $className.$methodName');
}

void main() {
  late String history;
  late String pdf;
  late String build;
  late String pngSection;
  late String pngField;
  late String pngAllergy;
  setUpAll(() {
    history = read('lib/screens/history_screen.dart');
    pdf = methodBlock(history, '_HistoryDetailState', '_exportPdf');
    build = methodBlock(history, '_HistoryDetailState', 'build');
    pngSection = classBlock(history, '_PngSection');
    pngField = classBlock(history, '_PngField');
    pngAllergy = classBlock(history, '_PngAllergyField');
  });
  test('PDF real usa superfície dark e tipografia clara', () {
    expect(pdf, contains('HISTORY_CLINICAL_V1_D_R22_R4_REAL_PDF_DARK'));
    expect(pdf, contains('HISTORY_CLINICAL_V1_D_R22_R4_PDF_CURRENT_STANDARD'));
    expect(pdf, contains('background: #1A1D23 !important'));
    expect(pdf, contains('color: #E8F0EC !important'));
    expect(pdf, contains('border-bottom: 1px solid #374151'));
  });
  test('logo do PDF é M+ dourado sem quadrado verde', () {
    expect(pdf, contains('<span class="logo-badge">M+</span>'));
    expect(pdf, contains('background: transparent !important'));
    expect(pdf, contains('color: #C5A365 !important'));
    expect(pdf, contains('border-radius: 0 !important'));
  });
  test('canvas real de PNG não possui documento branco', () {
    expect(build, contains('HISTORY_CLINICAL_V1_D_R22_R4_REAL_PNG_DARK'));
    expect(build, contains('color: const Color(0xFF1A1D23)'));
    final printStart =
        build.indexOf('HISTORY_CLINICAL_V1_D_R22_R4_REAL_PNG_DARK');
    final actionsStart =
        build.indexOf('HISTORY_CLINICAL_V1_D_R22_R4_PREMIUM_COMPACT_ACTIONS');
    expect(printStart, greaterThanOrEqualTo(0));
    expect(actionsStart, greaterThan(printStart));
    final canvas = build.substring(printStart, actionsStart);
    expect(canvas, isNot(contains('color: Colors.white,')));
    expect(canvas, isNot(contains('0xFF0F2D1C')));
    expect(canvas, contains("'M+'"));
    expect(canvas, contains('Color(0xFFC5A365)'));
  });
  test('helpers PNG seguem hierarquia atual', () {
    expect(history, contains('HISTORY_CLINICAL_V1_D_R22_R4_PNGSECTION_DARK'));
    expect(pngSection, contains('fontSize: 10.5'));
    expect(pngSection, contains('fontWeight: FontWeight.w700'));
    expect(pngSection, contains('Color(0xFFE8F0EC)'));
    expect(pngField, contains('fontSize: 9'));
    expect(pngField, contains('large ? 16 : 13'));
  });
  test('alerta de alergia fica dark e mantém vermelho semântico', () {
    expect(
      history,
      contains(
        'HISTORY_CLINICAL_V1_D_R22_R4_PNGALLERGYFIELD_DARK',
      ),
    );
    expect(pngAllergy, contains('Color(0xFF252930)'));
    expect(pngAllergy, contains('Color(0xFFE8F0EC)'));
    expect(pngAllergy, contains('Color(0xFFDC2626)'));
    expect(pngAllergy, isNot(contains('0xFFFFF5F5')));
    expect(pngAllergy, isNot(contains('0xFF991B1B')));
  });
  test('Copiar HC PDF e Imagem ficam compactos e delicados', () {
    final start =
        build.indexOf('HISTORY_CLINICAL_V1_D_R22_R4_PREMIUM_COMPACT_ACTIONS');
    expect(start, greaterThanOrEqualTo(0));
    final actions = build.substring(start);
    expect(actions, contains('color: Colors.transparent'));
    expect(actions, contains('BorderRadius.circular(8)'));
    expect(actions, contains('width: 0.65'));
    expect(actions, isNot(contains('BoxShadow')));
    expect(actions, isNot(contains('LinearGradient')));
  });
  test('contratos funcionais permanecem', () {
    for (final token in <String>[
      'Printing.',
      'RepaintBoundary',
      '_printKey',
      '_safeFilename',
      '_downloadBytes',
      '_copy',
      'widget.onBack',
      'widget.onEdit',
      'widget.onDelete',
      'class _HistoryPreviewSheet',
      'HISTORY_CLINICAL_V1_D_R20_EVOLUTION_FLAT',
      'saveHistory(',
      'deleteHistory(',
      '_openOcrPicker',
      '_toggleSmartDictaphone',
      '_showOrganizarIASheet'
    ]) {
      expect(history, contains(token), reason: 'contrato removido: $token');
    }
  });
}
