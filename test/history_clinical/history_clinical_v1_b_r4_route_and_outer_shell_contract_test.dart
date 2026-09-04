import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String classSlice(String source, String className) {
  final start = source.indexOf('class $className');
  expect(start, greaterThanOrEqualTo(0), reason: 'Classe ausente: $className');

  final brace = source.indexOf('{', start);
  expect(brace, greaterThanOrEqualTo(0));

  var depth = 0;
  var inString = false;
  var quote = '';
  var escaped = false;

  for (var i = brace; i < source.length; i++) {
    final char = source[i];

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == quote) {
        inString = false;
      }
      continue;
    }

    if (char == "'" || char == '"') {
      inString = true;
      quote = char;
      continue;
    }

    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return source.substring(start, i + 1);
    }
  }

  fail('Fechamento ausente: $className');
}

String markerSlice(String source, String begin, String end) {
  final start = source.indexOf(begin);
  final finish = source.indexOf(end);
  expect(start, greaterThanOrEqualTo(0), reason: 'Marker ausente: $begin');
  expect(finish, greaterThan(start), reason: 'Marker final ausente: $end');
  return source.substring(start, finish + end.length);
}

void main() {
  late String home;
  late String homeV2;
  late String history;
  late String mainSource;
  late String modules;

  setUpAll(() {
    home = File('lib/screens/home_screen.dart').readAsStringSync();
    homeV2 = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
    history = File('lib/screens/history_screen.dart').readAsStringSync();
    mainSource = File('lib/main.dart').readAsStringSync();
    modules = File(
      'lib/home_v2/components/home_v2_modules_view.dart',
    ).readAsStringSync();
  });

  test('bloco visível H. CLÍNICA preserva callback sem Navigator próprio', () {
    final grid = classSlice(modules, 'HomeV2ClinicalGrid');
    expect(grid, contains("label: 'H. CLÍNICA'"));
    expect(grid, contains('onTap: onClinicalHistory'));
  });

  test('wrapper produtivo usa a aba canônica 3 e não abre Pacientes', () {
    final wrapper = classSlice(home, 'HomePatientPediatricsRow');
    final route = markerSlice(
      wrapper,
      'HISTORY_CLINICAL_V1_B_R4_ROUTE_BEGIN',
      'HISTORY_CLINICAL_V1_B_R4_ROUTE_END',
    );

    expect(wrapper, contains('required this.onTabChange'));
    expect(wrapper, contains('final ValueChanged<int> onTabChange;'));
    expect(route, contains('onTabChange(3);'));
    expect(route, isNot(contains('_AdultoShell')));
    expect(route, isNot(contains('Navigator.of')));
  });

  test('HomeScreenV2 injeta o callback real do MainShell', () {
    expect(homeV2, contains('HomePatientPediatricsRow('));
    expect(homeV2, contains('onTabChange: onTabChange,'));
  });

  test('MainShell continua proprietário da HistoryScreen e do footer global',
      () {
    expect(RegExp(r'\bHistoryScreen\s*\(').allMatches(mainSource).length, 1);
    expect(RegExp(r'\bInternacionScreen\s*\(').allMatches(mainSource), isEmpty);

    // Contratos diretos: não tenta parsear a classe gigante _MainShellState.
    // O parser auxiliar simples não foi criado para comentários e strings longas
    // existentes em main.dart.
    expect(mainSource, contains('class _MainShellState'));
    expect(mainSource, contains('Widget _buildMobileShell('));
    expect(
      RegExp(r'return\s+_FloatingFooter\s*\(').hasMatch(mainSource),
      isTrue,
    );
    expect(
      mainSource,
      contains('class _FloatingFooter extends StatefulWidget'),
    );
    expect(mainSource, contains('HistoryScreen.editorActive'));
    expect(mainSource, contains('AiScreen.chatKeyboardOpen'));
    expect(mainSource, contains('MainShell.navScrollingDown'));
    expect(mainSource, contains('_LegalGlassShelf('));

    // HistoryScreen permanece conteúdo puro e não cria uma segunda barra.
    expect(history, isNot(contains('BottomAppBar(')));
    expect(history, isNot(contains('bottomNavigationBar:')));
    expect(history, isNot(contains('_FloatingFooter(')));
  });

  test('topbar clínica é grafite, plana e sem efeitos legados', () {
    final surface = markerSlice(
      history,
      'HISTORY_CLINICAL_V1_B_R4_TOPBAR_BEGIN',
      'HISTORY_CLINICAL_V1_B_R4_TOPBAR_END',
    );

    expect(surface, contains('Color(0xFF1A1D23)'));
    expect(surface, contains('Color(0xFF374151)'));
    expect(surface, isNot(contains('LinearGradient')));
    expect(surface, isNot(contains('BoxShadow')));
  });

  test('faixa de abas é superfície contínua com divisor fino', () {
    final surface = markerSlice(
      history,
      'HISTORY_CLINICAL_V1_B_R4_TAB_SURFACE_BEGIN',
      'HISTORY_CLINICAL_V1_B_R4_TAB_SURFACE_END',
    );

    expect(surface, contains('width: 0.5'));
    expect(surface, isNot(contains('LinearGradient')));
    expect(surface, isNot(contains('BoxShadow')));
  });

  test('lista remove card elevado externo e preserva marcador semântico', () {
    final surface = markerSlice(
      history,
      'HISTORY_CLINICAL_V1_B_R4_LIST_SURFACE_BEGIN',
      'HISTORY_CLINICAL_V1_B_R4_LIST_SURFACE_END',
    );

    expect(surface, contains('Colors.transparent'));
    expect(surface, contains('_cardAccent'));
    expect(surface, contains('width: 0.5'));
    expect(surface, isNot(contains('LinearGradient')));
    expect(surface, isNot(contains('BoxShadow')));
    expect(surface, isNot(contains('borderRadius')));
  });

  test('owners funcionais e ações clínicas permanecem presentes', () {
    for (final token in <String>[
      'class _HistoryScreenState',
      'class _HistoryDetail',
      'class _HistoryEditor',
      'saveHistory(',
      'deleteHistory(',
      'toggleHistoryPublic(',
      '_openOcrPicker',
      '_SmartDictaphoneButton',
    ]) {
      expect(history, contains(token), reason: 'Contrato removido: $token');
    }
  });
}
