import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read() => File('lib/screens/history_screen.dart').readAsStringSync();

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
  late String source;
  late String state;
  late String row;
  late String flat;
  late String flatState;

  setUpAll(() {
    source = read();
    state = between(
      source,
      'class _HistoryScreenState extends State<HistoryScreen>',
      'class _HcTopbarBg',
      '_HistoryScreenState',
    );
    row = between(
      source,
      'class _HcTabRow extends StatelessWidget',
      'class _HcFlatTab extends StatefulWidget',
      '_HcTabRow',
    );
    flat = between(
      source,
      'class _HcFlatTab extends StatefulWidget',
      'class _HcFlatTabState extends State<_HcFlatTab>',
      '_HcFlatTab',
    );
    flatState = between(
      source,
      'class _HcFlatTabState extends State<_HcFlatTab>',
      'class _HistoryCard extends StatelessWidget',
      '_HcFlatTabState',
    );
  });

  group('Historia Clinica canonical three-subtab navigation', () {
    test('48px topbar reserve and fixed 40px subnav remain', () {
      expect(source, contains('MEDCASES_H_CLINICA_HOME_TOPBAR_V1_B_R0'));
      expect(state, contains('const SizedBox(height: 48)'));
      expect(row, contains('height: 40'));
      expect(row, contains('width: 0.7'));
      expect(row, contains('height: 20'));
    });

    test('MIS HCs PUBLICAS and +NUEVA are three equal real tabs', () {
      expect(RegExp(r'\bExpanded\(').allMatches(row).length, 3);
      expect(RegExp(r'\b_HcFlatTab\(').allMatches(row).length, 3);

      expect(row, contains("label: lang == 'es' ? 'MIS HCs' : 'MINHAS'"));
      expect(row, contains("label: 'PÚBLICAS'"));
      expect(row, contains("label: lang == 'es' ? '+ NUEVA' : '+ NOVA'"));

      expect(row, contains('index: 0'));
      expect(row, contains('index: 1'));
      expect(row, contains('index: 2'));
      expect(row, contains('onTap: onNew'));
    });

    test('shared flat-tab owner retains current active visual grammar', () {
      expect(flat, contains('final VoidCallback? onTap;'));
      expect(flat, contains('this.onTap,'));

      expect(
          flatState, contains('duration: const Duration(milliseconds: 160)'));
      expect(flatState, contains('height: 40'));
      expect(flatState, contains('fontSize: 12'));
      expect(flatState, contains('left: 12'));
      expect(flatState, contains('right: 12'));
      expect(flatState, contains('bottom: 9'));
      expect(flatState, contains('height: 2'));
      expect(
        flatState,
        contains(
          'onTap: widget.onTap ?? () => widget.tabCtrl.animateTo(widget.index),',
        ),
      );
    });

    test('controller and TabBarView own exactly three internal pages', () {
      expect(state, contains('length: 3'));
      expect(state, contains('initialIndex: 2'));
      expect(state, contains('mineTab,'));
      expect(state, contains('communityTab,'));
      expect(state, contains('newHistoryTab,'));
    });
  });
}
