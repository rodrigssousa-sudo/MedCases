import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Nefrologia uses F2D flat catalog architecture', () {
    final tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    final workspace = File('lib/screens/nephro_premium_workspace_screen.dart')
        .readAsStringSync();
    final detail =
        File('lib/screens/nephro_score_detail_screen.dart').readAsStringSync();

    expect(tools, contains('NephroPremiumWorkspaceScreen'));
    expect(workspace, contains('FUNCIÓN RENAL · ERC'));
    expect(workspace, contains('RIESGO DE PROGRESIÓN'));
    expect(workspace, contains('LESIÓN RENAL AGUDA'));
    expect(workspace, contains('ÍNDICES URINARIOS'));

    for (final score in [
      'CKD-EPI 2021',
      'KDIGO G/A',
      'Cockcroft-Gault',
      'KFRE 4 variables',
      'KDIGO AKI',
      'FENa',
      'FEUrea',
    ]) {
      expect(workspace, contains(score));
    }

    expect(detail, contains("title: _isEs ? 'NEFROLOGÍA' : 'NEFROLOGIA'"));
    expect(detail, contains('const SizedBox(height: 1)'));
    expect(detail, contains("Key('nephro_import_patient')"));
    expect(detail, contains("Key('nephro_result')"));
    expect(detail, contains("buildQueryStringForSpecialty('nefro', lang)"));
    expect(detail, contains('modulo=nefrologia'));
  });
}
