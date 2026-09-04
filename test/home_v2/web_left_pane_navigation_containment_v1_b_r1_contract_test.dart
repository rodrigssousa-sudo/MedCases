import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop Web 40 percent workspace owns isolated Navigator', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(
      main,
      contains('MEDCASES_WEB_40_60_LEFT_PANE_NAV_CONTAINMENT_V1_B_R1'),
    );
    expect(main, contains('final bool showPersistentAiSplit = width >= 1024;'));
    expect(main, contains('flex: 40'));
    expect(main, contains("key: ValueKey<String>('web-left-pane-\$leftPaneIndex')"));
    expect(main, contains('child: Navigator('));
    expect(main, contains('builder: (_) => _staticScreens[leftPaneIndex]'));

    // The right pane must remain the same persistent AiScreen owner.
    expect(main, contains('flex: 60'));
    expect(
      main,
      contains('child: _staticScreens[2], // AiScreen — sempre ativo no split'),
    );
  });

  test('Web Home routes cannot explicitly escape to root Navigator', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(
      RegExp(r'rootNavigator\s*:\s*true').hasMatch(home),
      isFalse,
    );
    expect(
      RegExp(r'useRootNavigator\s*:\s*true').hasMatch(home),
      isFalse,
    );
    expect(home, contains('rootNavigator: !kIsWeb'));
  });

  test('History dialogs use left Navigator on Web and root on native', () {
    final history = File('lib/screens/history_screen.dart').readAsStringSync();
    final calls =
        RegExp(r'\bshowDialog(?:<[^>]+>)?\s*\(').allMatches(history).toList();

    expect(calls, isNotEmpty);

    for (final call in calls) {
      final end = (call.start + 520).clamp(0, history.length).toInt();
      final window = history.substring(call.start, end);
      expect(
        window,
        contains('useRootNavigator: !kIsWeb'),
        reason: 'showDialog at offset ${call.start} is not Web-contained',
      );
    }
  });

  test('native semantics are preserved by kIsWeb guards', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    // On iOS/Android kIsWeb=false, therefore !kIsWeb=true, matching the
    // pre-patch rootNavigator:true behavior.
    expect(home, contains('rootNavigator: !kIsWeb'));
    expect(history, contains('useRootNavigator: !kIsWeb'));
  });
}
