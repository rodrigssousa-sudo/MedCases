import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hepatologia uses flat catalog and dedicated score architecture', () {
    final tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    final workspace = File('lib/screens/hepato_premium_workspace_screen.dart')
        .readAsStringSync();
    final detail =
        File('lib/screens/hepato_score_detail_screen.dart').readAsStringSync();
    final engine = File('lib/services/hepato/hepato_score_engine_2026.dart')
        .readAsStringSync();

    expect(tools, contains('HepatoPremiumWorkspaceScreen'));
    expect(tools, contains('if (index == 3)'));
    expect(workspace, contains('MELD 3.0'));
    expect(workspace, contains('Child-Pugh'));
    expect(workspace, contains('FIB-4'));
    expect(workspace, contains('Maddrey mDF'));
    expect(workspace, contains('Lille'));
    expect(workspace, isNot(contains('ExpansionTile')));
    expect(detail, contains("Key('hepato_import_patient')"));
    expect(detail, contains("Key('hepato_result')"));
    expect(detail, contains("buildQueryStringForSpecialty('hepato', lang)"));
    expect(detail, contains('modulo=hepatologia'));
    expect(detail, contains('const SizedBox(height: 1)'));
    expect(engine, contains('4.56 * math.log(bilirubin)'));
    expect(engine, contains('6.33'));
    expect(engine, contains('0.0165 * evolutionUmol'));
    expect(engine, contains('score >= 0.45'));
  });
}
