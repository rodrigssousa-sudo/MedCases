import 'history_release_runtime_harness.dart';
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
    detailCard = classBlock(history, '_PngSection');
    sectionBlock = classBlock(history, '_PngField');
    allergy = classBlock(history, '_PngAllergyField');
    diagnosis = classBlock(history, '_PngDxSection');
    outcome = classBlock(history, '_PngOutcomeBadge');
    drugs = classBlock(history, '_DrugChips');
    evolution = classBlock(history, '_PngEvolution');
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

  testWidgets('topbar mostra voltar título paciente e editar', (tester) async {
    // The saved detail now renders the same canonical PNG document widgets.
    await verifyHistoryPngCanvas(tester);
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R21_SAVED_DETAIL_TOPBAR'),
    );
    expect(hero, contains('SafeArea('));
    expect(hero, contains('Icons.arrow_back_ios_new_rounded'));
    expect(hero, contains('onPressed: onBack'));
    expect(hero, contains('history.displayTitle'));
    expect(hero, contains("_hcT(lang, 'tab_title')"));
    expect(hero, contains('patientSummary'));
    expect(hero, contains('onPressed: onEdit'));
    expect(compact, contains('_HistoryHeroHeader('));
  });

  testWidgets('topbar e metadados não usam visual legado', (tester) async {
    // The saved detail now renders the same canonical PNG document widgets.
    await verifyHistoryPngCanvas(tester);
    expect(hero, isNot(contains('LinearGradient')));
    expect(hero, isNot(contains('BoxShadow')));
    expect(hero, isNot(contains('medical_information_rounded')));
    expect(badge, isNot(contains('BoxDecoration')));
    expect(badge, isNot(contains('borderRadius')));
    expect(badge, contains('color: accent'));
  });

  testWidgets('seções principais usam superfície contínua e texto claro', (tester) async {
    // The saved detail now renders the same canonical PNG document widgets.
    await verifyHistoryPngCanvas(tester);
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R21_R3_DETAIL_CARD_CONTINUOUS'),
    );
    expect(detailCard, isNot(contains('Colors.white')));
    expect(detailCard, isNot(contains('BoxShadow')));
    expect(detailCard, contains('_PngDivider()'));
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R21_R3_SECTION_BLOCK_FLAT'),
    );
    expect(sectionBlock, isNot(contains('BoxDecoration')));
    expect(sectionBlock, contains('Color(0xFFE8F0EC)'));
  });

  testWidgets('alergia diagnóstico e desfecho ficam dark sem perder semântica', (tester) async {
    // The saved detail now renders the same canonical PNG document widgets.
    await verifyHistoryPngCanvas(tester);
    expect(allergy, contains('Color(0xFF252930)'));
    expect(allergy, contains('Color(0xFFDC2626'));
    expect(allergy, isNot(contains('BoxShadow')));
    expect(
      history,
      contains('HISTORY_CLINICAL_V1_D_R21_R3_DX_DARK_SEMANTIC'),
    );
    expect(diagnosis, contains('Color(0xFF252930)'));
    expect(diagnosis, contains('final_.isNotEmpty'));
    expect(diagnosis, contains('working.isNotEmpty'));
    expect(diagnosis, isNot(contains('BoxShadow')));
    expect(outcome, contains('Color(0xFF252930)'));
    expect(outcome, contains('labels[outcome] ?? outcome'));
  });

  testWidgets('fármacos e evolução salva preservam dados e recebem dark', (tester) async {
    // The saved detail now renders the same canonical PNG document widgets.
    await verifyHistoryPngCanvas(tester);
    expect(drugs, contains('p.drugsDB'));
    expect(drugs, contains('firstOrNull'));
    expect(drugs, contains('drug?.name ?? id'));
    expect(drugs, contains('Color(0xFF252930)'));
    expect(find.text('CAMPO_TESTE_EVOLUCAO'), findsOneWidget);
    expect(build, contains('history.evolutions.map'));
    expect(build, contains('DateTime.tryParse'));
    expect(build, contains('text: e.text'));
    expect(build, contains('p.lang'));
    expect(evolution, contains('Color(0xFFE8F0EC)'));
  });

  testWidgets('ações inferiores permanecem dark', (tester) async {
    // The saved detail now renders the same canonical PNG document widgets.
    await verifyHistoryPngCanvas(tester);
    final start = build.indexOf('onTap: _copy');
    expect(start, greaterThanOrEqualTo(0));
    final actions = build.substring(start);
    expect(actions, contains('color: Colors.transparent'));
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
