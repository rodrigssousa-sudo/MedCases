import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('Plantão fallback declares explicit treatment and exams metadata', () {
    final source = File('lib/services/ai_next_action_engine.dart').readAsStringSync();
    expect(source, contains("label: es ? 'Conductas y dosis' : 'Condutas e dosagens'"));
    expect(source, contains('continuationType: PlantaoContinuationType.treatmentExpansion'));
    expect(source, contains("label: es ? 'Estudios y evolución' : 'Exames e evolução'"));
    expect(source, contains('continuationType: PlantaoContinuationType.examsEvolution'));
    expect(source, contains('PlantaoSection.responseCriteria'));
    expect(source, contains('PlantaoSection.worseningCriteria'));
  });
}
