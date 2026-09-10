import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Electrolytes uses flat catalog and dedicated calculator architecture',
      () {
    final tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    final workspace = File(
      'lib/screens/electrolytes_premium_workspace_screen.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/screens/electrolytes_score_detail_screen.dart',
    ).readAsStringSync();
    final engine = File(
      'lib/services/electrolytes/electrolytes_score_engine_2026.dart',
    ).readAsStringSync();

    expect(tools, contains('ElectrolytesPremiumWorkspaceScreen'));
    expect(tools, contains('if (index == 2)'));
    expect(workspace, contains('Sódio corrigido'));
    expect(workspace, contains('Osmolalidade e tonicidade'));
    expect(workspace, contains('Ânion gap corrigido'));
    expect(workspace, contains('Delta ratio'));
    expect(workspace, contains('Compensação de Winter'));
    expect(workspace, contains('Cálcio corrigido'));
    expect(workspace, isNot(contains('ExpansionTile')));
    expect(detail, contains("Key('electrolytes_import_patient')"));
    expect(detail, contains("Key('electrolytes_result')"));
    expect(
      detail,
      contains("buildQueryStringForSpecialty('eletrolitos', lang)"),
    );
    expect(detail, contains('modulo=eletrolitos'));
    expect(detail, contains('const SizedBox(height: 1)'));
    expect(engine, contains('1.6 * (glucoseExcess / 100.0)'));
    expect(engine, contains('glucoseMgDl / 18.0'));
    expect(engine, contains('bunMgDl / 2.8'));
    expect(engine, contains('2.5 * (4.0 - albuminGDl)'));
    expect(engine, contains('1.5 * bicarbonateMmolL + 8.0'));
    expect(engine, contains('0.8 * (4.0 - albuminGDl)'));
  });
}
