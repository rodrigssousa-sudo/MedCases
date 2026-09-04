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

String methodBlock(String source, String className, String methodName) {
  final owner = classBlock(source, className);
  for (final match
      in RegExp('\\b${RegExp.escape(methodName)}\\s*\\(').allMatches(owner)) {
    final paren = owner.indexOf('(', match.start);
    final closeParen = findMatching(owner, paren, '(', ')');
    var cursor = closeParen + 1;
    while (cursor < owner.length && RegExp(r'\s').hasMatch(owner[cursor])) {
      cursor++;
    }
    if (owner.startsWith('async', cursor)) {
      cursor += 5;
      while (cursor < owner.length && RegExp(r'\s').hasMatch(owner[cursor])) {
        cursor++;
      }
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
  late String state;
  late String build;
  late String hero;
  late String compact;
  late String badge;
  late String detailCard;
  late String sectionBlock;
  late String allergy;
  late String diagnosis;
  late String outcome;
  late String drugs;
  late String evolution;

  setUpAll(() {
    history = read('lib/screens/history_screen.dart');
    state = classBlock(history, '_HistoryDetailState');
    build = methodBlock(history, '_HistoryDetailState', 'build');
    hero = classBlock(history, '_HistoryHeroHeader');
    compact = classBlock(history, '_HistoryHeroHeaderCompact');
    badge = classBlock(history, '_PatientBadge');
    detailCard = classBlock(history, '_DetailCard');
    sectionBlock = classBlock(history, '_SectionBlock');
    allergy = classBlock(history, '_AllergyBanner');
    diagnosis = classBlock(history, '_DxBanner');
    outcome = classBlock(history, '_OutcomeBadge');
    drugs = classBlock(history, '_DrugChips');
    evolution = classBlock(history, '_EvolutionSection');
  });

  test('história salva aberta recebe raiz grafite', () {
    expect(history, contains('HISTORY_CLINICAL_V1_D_R21_SAVED_DETAIL'));
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R21_R3_DIRECT_VISUAL_OWNERS'),
    );
    expect(build, contains('ColoredBox('));
    expect(build, contains('Color(0xFF1A1D23)'));
  });

  test('topbar mostra voltar título paciente e editar', () {
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R21_SAVED_DETAIL_TOPBAR'),
    );
    expect(hero, contains('SafeArea('));
    expect(hero, contains('Icons.arrow_back_ios_new_rounded'));
    expect(hero, contains('onPressed: onBack'));
    expect(hero, contains('history.displayTitle'));
    expect(hero, contains("_hcT(lang, 'tab_title')"));
    expect(hero, contains('patientItems'));
    expect(hero, contains('onPressed: onEdit'));
    expect(compact, contains('_HistoryHeroHeader('));
  });

  test('topbar e metadados não usam visual legado', () {
    expect(hero, isNot(contains('LinearGradient')));
    expect(hero, isNot(contains('BoxShadow')));
    expect(hero, isNot(contains('medical_information_rounded')));
    expect(badge, isNot(contains('BoxDecoration')));
    expect(badge, isNot(contains('borderRadius')));
    expect(badge, contains('ColoredBox(color: accent)'));
  });

  test('seções principais usam superfície contínua e texto claro', () {
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R21_R3_DETAIL_CARD_CONTINUOUS'),
    );
    expect(detailCard, isNot(contains('Colors.white')));
    expect(detailCard, isNot(contains('BoxShadow')));
    expect(detailCard, contains('Color(0xFF374151)'));
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R21_R3_SECTION_BLOCK_FLAT'),
    );
    expect(sectionBlock, isNot(contains('BoxDecoration')));
    expect(sectionBlock, contains('Color(0xFFE8F0EC)'));
  });

  test('alergia diagnóstico e desfecho ficam dark sem perder semântica', () {
    expect(allergy, contains('Color(0xFF252930)'));
    expect(allergy, contains('Color(0xFFEF4444)'));
    expect(allergy, isNot(contains('BoxShadow')));
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R21_R3_DX_DARK_SEMANTIC'),
    );
    expect(diagnosis, contains('final bgColor = const Color(0xFF252930)'));
    expect(diagnosis, contains('dx_final_label'));
    expect(diagnosis, contains('dx_working_label'));
    expect(diagnosis, isNot(contains('BoxShadow')));
    expect(outcome, contains('Color(0xFF252930)'));
    expect(outcome, contains('outcome_title'));
  });

  test('fármacos e evolução salva preservam dados e recebem dark', () {
    expect(drugs, contains('p.drugsDB'));
    expect(drugs, contains('firstOrNull'));
    expect(drugs, contains('drug?.name ?? id'));
    expect(drugs, contains('Color(0xFF252930)'));
    expect(evolution, contains('evolutions.map'));
    expect(evolution, contains('DateTime.tryParse'));
    expect(evolution, contains('e.text'));
    expect(evolution, contains('context.read<AppProvider>().lang'));
    expect(evolution, contains('Color(0xFFE8F0EC)'));
  });

  test('ações inferiores permanecem dark', () {
    final start = build.indexOf('onTap: _copy');
    expect(start, greaterThanOrEqualTo(0));
    final actions = build.substring(start);
    expect(actions, contains('Color(0xFF252930)'));
    expect(actions, contains('Color(0xFF374151)'));
    expect(actions, isNot(contains('BoxShadow')));
    expect(actions, isNot(contains('LinearGradient')));
  });

  test('exportações callbacks e módulos homologados permanecem', () {
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
    ]) {
      expect(state, contains(token), reason: 'contrato removido: $token');
    }

    for (final token in <String>[
      'HISTORY_CLINICAL_V1_D_R20_EVOLUTION_FLAT',
      'class _HistoryEditor',
      'class _HistoryPreviewSheet',
      'saveHistory(',
      'deleteHistory(',
      '_openOcrPicker',
      '_toggleSmartDictaphone',
      '_showOrganizarIASheet',
    ]) {
      expect(history, contains(token), reason: 'módulo removido: $token');
    }
  });
}
