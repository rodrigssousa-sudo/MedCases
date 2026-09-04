import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

String between(
  String source,
  String start,
  String end,
  String label,
) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: '$label start');
  expect(b, greaterThan(a), reason: '$label end');
  return source.substring(a, b);
}

void main() {
  late String history;
  late String mainSource;
  late String state;
  late String row;
  late String flat;
  late String flatState;
  late String workspace;
  late String flowCard;
  late String startNew;
  late String request;

  setUpAll(() {
    history = read('lib/screens/history_screen.dart');
    mainSource = read('lib/main.dart');

    state = between(
      history,
      'class _HistoryScreenState extends State<HistoryScreen>',
      'class _HcTopbarBg',
      '_HistoryScreenState',
    );
    row = between(
      history,
      'class _HcTabRow extends StatelessWidget',
      'class _HcFlatTab extends StatefulWidget',
      '_HcTabRow',
    );
    flat = between(
      history,
      'class _HcFlatTab extends StatefulWidget',
      'class _HcFlatTabState extends State<_HcFlatTab>',
      '_HcFlatTab',
    );
    flatState = between(
      history,
      'class _HcFlatTabState extends State<_HcFlatTab>',
      'class _HistoryCard extends StatelessWidget',
      '_HcFlatTabState',
    );
    workspace = between(
      history,
      'class _NewHistoryWorkspace extends StatelessWidget',
      'class _NewHistoryFlowCard extends StatelessWidget',
      '_NewHistoryWorkspace',
    );
    flowCard = between(
      history,
      'class _NewHistoryFlowCard extends StatelessWidget',
      '// LAYER 1 — Plano de fundo da topbar História Clínica',
      '_NewHistoryFlowCard',
    );
    startNew = between(
      state,
      'void _startNewHistory(AppProvider p, String lang)',
      'void _startBlankHistory',
      '_startNewHistory',
    );
    request = between(
      state,
      'void _onNewWorkspaceRequest()',
      'void _onTabChange()',
      '_onNewWorkspaceRequest',
    );
  });

  test('Historia Clinica opens directly on real +NUEVA/+NOVA third subtab', () {
    expect(
        state, contains('MEDCASES_HC_INLINE_NOVA_SUBTAB_V1_B_R0_CONTROLLER'));
    expect(state, contains('length: 3'));
    expect(state, contains('initialIndex: 2'));

    expect(
      mainSource,
      contains('MEDCASES_HC_DIRECT_NOVA_ENTRY_V1_B_R0_MAIN_TAB'),
    );
    expect(mainSource, contains('HistoryScreen.requestNewWorkspace();'));

    expect(
      request,
      contains('MEDCASES_HC_INLINE_NOVA_SUBTAB_V1_B_R0_ENTRY'),
    );
    expect(request, contains('_tabCtrl.animateTo(2);'));
    expect(request, isNot(contains('_startNewHistory(')));
    expect(request, isNot(contains('Navigator.')));
  });

  test('three subnav segments are visually the same real tab component', () {
    expect(RegExp(r'\b_HcFlatTab\(').allMatches(row).length, 3);
    expect(row, contains("label: lang == 'es' ? 'MIS HCs' : 'MINHAS'"));
    expect(row, contains("label: 'PÚBLICAS'"));
    expect(row, contains("label: lang == 'es' ? '+ NUEVA' : '+ NOVA'"));
    expect(row, contains('index: 2'));
    expect(row, contains('onTap: onNew'));

    expect(flat, contains('final VoidCallback? onTap;'));
    expect(flat, contains('this.onTap,'));
    expect(
      flatState,
      contains(
        'onTap: widget.onTap ?? () => widget.tabCtrl.animateTo(widget.index),',
      ),
    );
  });

  test('+NUEVA content is inline and no duplicate page/topbar survives', () {
    expect(workspace, contains('MEDCASES_HC_INLINE_NOVA_SUBTAB_V1_B_R0'));
    expect(workspace, contains('return ColoredBox('));
    expect(workspace, contains('ListView('));

    for (final stale in <String>[
      'Scaffold(',
      'NUEVA HISTORIA CLÍNICA',
      'NOVA HISTÓRIA CLÍNICA',
      'arrow_back_ios_new_rounded',
      'Navigator.of(context).pop()',
    ]) {
      expect(workspace, isNot(contains(stale)), reason: stale);
    }

    expect(startNew, contains('_tabCtrl.animateTo(2);'));
    expect(startNew, isNot(contains('Navigator.of(context).push')));
  });

  test(
      '+NUEVA hides irrelevant search controls and owns third TabBarView child',
      () {
    expect(
      state,
      contains('MEDCASES_HC_INLINE_NOVA_SEARCH_HIDE_V1_B_R0'),
    );
    expect(state, contains('if (_tabCtrl.index != 2) ...['));
    expect(state, contains('final newHistoryTab = _NewHistoryWorkspace('));
    expect(state, contains('mineTab,'));
    expect(state, contains('communityTab,'));
    expect(state, contains('newHistoryTab,'));
    expect(state, isNot(contains('children: [mineTab, communityTab]')));
  });

  test('inline creation area keeps exactly the three productive engines', () {
    expect(
      RegExp(r'\b_NewHistoryFlowCard\(').allMatches(workspace).length,
      3,
    );

    for (final token in <String>[
      'ClinicalRecorderSheet.openContinuousRecorder(',
      'onTap: _openManual',
      'ClinicalRecorderSheet.openSoapBlocksRecorder(',
      'Icons.mic_rounded',
      'Icons.edit_note_rounded',
      'Icons.view_agenda_outlined',
    ]) {
      expect(workspace, contains(token), reason: token);
    }

    expect(flowCard, contains("'IA'"));
    expect(flowCard, contains('width: 40'));
    expect(flowCard, contains('height: 40'));
    expect(flowCard, contains('fontSize: 14.5'));
    expect(flowCard, isNot(contains('BoxShadow(')));
    expect(flowCard, isNot(contains('LinearGradient(')));
  });
}
