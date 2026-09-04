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
  final matches = RegExp(
    '^\\s*class\\s+${RegExp.escape(name)}\\b[^\\{]*\\{',
    multiLine: true,
  ).allMatches(source).toList();
  expect(matches.length, 1, reason: 'owner duplicado/ausente: $name');
  final opening = source.indexOf('{', matches.single.start);
  final closing = findMatching(source, opening, '{', '}');
  return source.substring(matches.single.start, closing + 1);
}

void main() {
  late String history;
  late String hero;
  late String compact;
  late String badge;

  setUpAll(() {
    history = read('lib/screens/history_screen.dart');
    hero = classBlock(history, '_HistoryHeroHeader');
    compact = classBlock(history, '_HistoryHeroHeaderCompact');
    badge = classBlock(history, '_PatientBadge');
  });

  test('título da aba fica realmente centralizado', () {
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R23_R2_ORDERED_TOPBAR'),
    );
    expect(hero, contains('Stack('));
    expect(hero, contains('alignment: Alignment.center'));
    expect(hero, contains("_hcT(lang, 'tab_title').toUpperCase()"));
    expect(hero, contains('textAlign: TextAlign.center'));
    expect(hero, contains('Alignment.centerLeft'));
    expect(hero, contains('Alignment.centerRight'));
  });

  test('motivo da consulta recebe hierarquia própria', () {
    expect(hero, contains('MOTIVO DA CONSULTA'));
    expect(hero, contains('MOTIVO DE CONSULTA'));
    expect(hero, contains('history.displayTitle'));
    expect(hero, contains('fontSize: MedTypography.internalTitleSize'));
  });

  test('paciente idade e sexo usam linha limpa com barras', () {
    expect(hero, contains('history.patientInitials'));
    expect(hero, contains('history.patientAge'));
    expect(hero, contains('history.patientSex'));
    expect(hero, contains('patientSummary'));
    expect(hero, contains("'/'"));
    expect(hero, contains("_hcT(lang, 'years')"));
    expect(hero.split('_PatientBadge(').length - 1, 3);
  });

  test('helper do paciente é texto puro sem card pill ou ícone', () {
    expect(
      history,
      contains(
        'HISTORY_CLINICAL_V1_D_R23_R2_PATIENT_BADGE_FLAT_TEXT',
      ),
    );
    expect(badge, contains('ValueKey<IconData>(icon)'));
    expect(badge, contains('Text('));
    expect(badge, isNot(contains('BoxDecoration')));
    expect(badge, isNot(contains('borderRadius')));
    expect(badge, isNot(contains('Container(')));
    expect(badge, isNot(contains('Icon(')));
  });

  test('sexo masculino é azul e feminino é rosa', () {
    expect(hero, contains('Color(0xFF93C5FD)'));
    expect(hero, contains('Color(0xFFF9A8D4)'));
    expect(hero, contains("normalizedSex.contains('masc')"));
    expect(hero, contains("normalizedSex.contains('fem')"));
    expect(hero, contains("normalizedSex.contains('mujer')"));
    expect(hero, contains("normalizedSex.contains('mulher')"));
  });

  test('autor publicação categoria e tags saem da topbar', () {
    expect(hero, isNot(contains('history.authorName')));
    expect(hero, isNot(contains('history.uploadedAt')));
    expect(hero, isNot(contains('history.category')));
    expect(hero, isNot(contains('history.tags')));
  });

  test('voltar editar readOnly e responsividade permanecem', () {
    expect(hero, contains('onPressed: onBack'));
    expect(hero, contains('onPressed: onEdit'));
    expect(hero, contains('!readOnly && onEdit != null'));
    expect(compact, contains('_HistoryHeroHeader('));
    expect(compact, contains('readOnly: readOnly'));
  });

  test('R22-R4 permanece intacta', () {
    for (final token in <String>[
      'HISTORY_CLINICAL_V1_D_R22_R4_REAL_PDF_DARK',
      'HISTORY_CLINICAL_V1_D_R22_R4_REAL_PNG_DARK',
      'HISTORY_CLINICAL_V1_D_R22_R4_PREMIUM_COMPACT_ACTIONS',
      'HISTORY_CLINICAL_V1_D_R22_R4_PNGALLERGYFIELD_DARK',
      'Printing.',
      'RepaintBoundary',
      '_downloadBytes',
      '_copy',
    ]) {
      expect(history, contains(token), reason: 'contrato removido: $token');
    }
  });
}
