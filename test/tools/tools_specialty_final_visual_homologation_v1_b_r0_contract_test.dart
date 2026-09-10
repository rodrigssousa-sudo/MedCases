import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('final tools visual contract matches Cardio gold', () {
    final tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    final toolsNormalized = tools.replaceAll(RegExp(r'\s+'), ' ');
    final home = File('lib/screens/home_screen.dart').readAsStringSync();

    final cardio = File('lib/screens/cardio_premium_workspace_screen.dart')
        .readAsStringSync();
    final nephro = File('lib/screens/nephro_premium_workspace_screen.dart')
        .readAsStringSync();
    final hepato = File('lib/screens/hepato_premium_workspace_screen.dart')
        .readAsStringSync();
    final electrolytes =
        File('lib/screens/electrolytes_premium_workspace_screen.dart')
            .readAsStringSync();

    final nephroDetail =
        File('lib/screens/nephro_score_detail_screen.dart').readAsStringSync();
    final hepatoDetail =
        File('lib/screens/hepato_score_detail_screen.dart').readAsStringSync();
    final electrolytesDetail =
        File('lib/screens/electrolytes_score_detail_screen.dart')
            .readAsStringSync();

    for (final workspace in [cardio, nephro, hepato, electrolytes]) {
      expect(workspace, contains('height: 48'));
      expect(workspace, contains('Icons.chevron_left_rounded'));
      expect(workspace, contains('size: 30'));
      expect(workspace, contains('fontSize: 16'));
      expect(workspace, contains('height: 1'));
      expect(workspace, contains('fontWeight: FontWeight.w900'));
      expect(workspace, contains('letterSpacing: 1.4'));
      expect(workspace, contains('crossAxisCount: 2'));
      expect(workspace, contains('crossAxisSpacing: 6'));
      expect(workspace, contains('mainAxisSpacing: 6'));
      expect(workspace, contains('childAspectRatio: 1.58'));
      expect(
          workspace, contains('border: Border.all(color: border, width: 0.7)'));
    }

    for (final detail in [nephroDetail, hepatoDetail, electrolytesDetail]) {
      expect(detail, contains('Icons.chevron_left_rounded'));
      expect(detail, contains('size: 30'));
      expect(detail, contains('fontSize: 16'));
      expect(detail, contains('height: 1'));
      expect(detail, contains('letterSpacing: 1.4'));
    }

    expect(
      tools,
      isNot(contains(
        "final border = selected\n            ? const Color(0xFF009C3B)",
      )),
    );
    expect(
      toolsNormalized,
      contains(
        'final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);',
      ),
    );
    expect(tools, contains('width: 0.7'));

    // Generic Home -> Ferramentas entry must clear stale specialty request.
    expect(
      RegExp(r'toolsScreenTabNotifier\.value\s*=\s*null;')
          .allMatches(home)
          .length,
      greaterThanOrEqualTo(2),
    );

    // Explicit calc/deeplink routing remains alive.
    expect(
      home,
      contains('toolsScreenTabNotifier.value = calcTabMap[calcId] ?? 0;'),
    );
    expect(tools, contains('toolsScreenTabNotifier'));
    expect(tools, contains('_openToolsSpecialtyRoute(context, safeIndex)'));
  });
}
