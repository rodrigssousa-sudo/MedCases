import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const canonical = '0xFF0D6B57';

  final targets = <String, List<String>>{
    'lib/screens/ai_screen.dart': <String>[
      '0xFF00E5FF',
      '0xFF008CA4',
    ],
    'lib/screens/vaccines_screen.dart': <String>[
      '0xFF00C781',
      '0xFF059669',
    ],
    'lib/screens/study_history_screen.dart': <String>['0xFF10B981'],
    'lib/screens/study_workspace_screen.dart': <String>['0xFF10B981'],
    'lib/screens/clinical_guide_article_screen.dart': <String>['0xFF10B981'],
    'lib/screens/laboratory_screen.dart': <String>['0xFF10B981'],
    'lib/screens/cardio_tools_screen.dart': <String>[
      '0xFF00E5FF',
      '0xFF10B981',
    ],
    'lib/screens/electrolytes_tools_screen.dart': <String>[
      '0xFF00E5FF',
      '0xFF10B981',
    ],
    'lib/screens/nephrology_tools_screen.dart': <String>[
      '0xFF00E5FF',
      '0xFF10B981',
    ],
    'lib/screens/hepatology_tools_screen.dart': <String>[
      '0xFF00E5FF',
      '0xFF10B981',
    ],
  };

  test('Batch 1 high-confidence productive owners use canonical accent', () {
    for (final entry in targets.entries) {
      final source = File(entry.key).readAsStringSync();

      expect(
        source,
        contains(canonical),
        reason: '${entry.key} canonical accent',
      );

      for (final stale in entry.value) {
        expect(
          source,
          isNot(contains(stale)),
          reason: '${entry.key} stale $stale',
        );
      }
    }
  });

  test('AI scroll affordance no longer exposes cyan/teal second brand', () {
    final source = File('lib/screens/ai_screen.dart').readAsStringSync();

    expect(
      source,
      contains('MEDCASES_PRODUCTIVE_SECOND_BRAND_B1_V2_R1_AI'),
    );
    expect(source, isNot(contains('0xFF00E5FF')));
    expect(source, isNot(contains('0xFF008CA4')));
  });

  test('vaccines keeps one green identity across light and dark', () {
    final source = File('lib/screens/vaccines_screen.dart').readAsStringSync();

    expect(
      source,
      contains('MEDCASES_PRODUCTIVE_SECOND_BRAND_B1_V2_R1_VACCINES'),
    );
    expect(source, isNot(contains('0xFF00C781')));
    expect(source, isNot(contains('0xFF059669')));
    expect(
      RegExp(r'0xFF0D6B57').allMatches(source).length,
      greaterThanOrEqualTo(12),
    );
  });

  test('Study workspace and history preserve destructive semantics', () {
    final history =
        File('lib/screens/study_history_screen.dart').readAsStringSync();
    final workspace =
        File('lib/screens/study_workspace_screen.dart').readAsStringSync();

    expect(history, contains('0xFFDC2626'));
    expect(workspace, contains('0xFFDC2626'));
    expect(history, isNot(contains('0xFF10B981')));
    expect(workspace, isNot(contains('0xFF10B981')));
  });

  test('specialty tools preserve amber red blue and purple semantics', () {
    final cardio =
        File('lib/screens/cardio_tools_screen.dart').readAsStringSync();
    final electro =
        File('lib/screens/electrolytes_tools_screen.dart').readAsStringSync();
    final nephro =
        File('lib/screens/nephrology_tools_screen.dart').readAsStringSync();
    final hepato =
        File('lib/screens/hepatology_tools_screen.dart').readAsStringSync();

    for (final source in <String>[cardio, electro, nephro, hepato]) {
      expect(source, contains('0xFFF59E0B'));
      expect(source, contains('0xFFEF4444'));
    }

    expect(cardio, contains('0xFF8B5CF6'));
    expect(electro, contains('0xFF3B82F6'));
    expect(nephro, contains('0xFF7C3AED'));
  });

  test(
      'semantic-heavy screens preserve required semantics as later batches advance',
      () {
    final history = File('lib/screens/history_screen.dart').readAsStringSync();
    final tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    final drugs = File('lib/screens/drugs_screen.dart').readAsStringSync();
    final protocols =
        File('lib/screens/protocols_screen.dart').readAsStringSync();
    final recorder =
        File('lib/screens/clinical_recorder_sheet.dart').readAsStringSync();
    final home = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(history, contains('0xFF10B981'));
    expect(tools, contains('0xFF10B981'));
    expect(drugs, contains('0xFFFFE8A6'));
    expect(protocols, contains('0xFFC5A365'));
    expect(recorder, contains('0xFF10B981'));
    // Batch 3A canonicalized the remaining Home cyan/teal second-brand identity.
    // The Batch 1 regression now protects the evolved current-tree contract:
    // canonical brand accent present, cyan absent, premium/semantic purple preserved.
    expect(home, contains('0xFF0D6B57'));
    expect(home, isNot(contains('0xFF00E5FF')));
    expect(home, contains('0xFF7C3AED'));
  });

  test('migration reference remains untouched by productive Batch 1', () {
    final migration = File('lib/home_v2/migration_home_screen_reference.dart')
        .readAsStringSync();

    expect(migration, contains('0xFF00E5FF'));
    expect(migration, contains('0xFF008CA4'));
    expect(migration, contains('0xFF10B981'));
  });
}
