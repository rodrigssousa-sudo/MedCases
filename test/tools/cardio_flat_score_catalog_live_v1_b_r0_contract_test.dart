import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F2D canonical navigation contract', () {
    final workspace = File('lib/screens/cardio_premium_workspace_screen.dart')
        .readAsStringSync();
    final detail =
        File('lib/screens/cardio_score_detail_screen.dart').readAsStringSync();

    expect(workspace, contains('CardioScoreDetailScreen('));
    expect(workspace, contains('SCA · DOLOR TORÁCICO'));
    expect(workspace, contains('FA · TROMBOEMBOLIA · SANGRADO'));
    expect(workspace, contains('ECG · REPOLARIZACIÓN'));

    expect(detail, contains('const SizedBox(height: 1)'));
    expect(detail, contains('Importar datos del paciente'));
    expect(detail, contains("Key('cardio_score_result')"));
    expect(detail, contains('USO Y LIMITACIONES'));
    expect(detail, contains('REFERENCIA'));
  });
}
