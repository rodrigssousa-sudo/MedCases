import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/drug_evidence_detector.dart';

void main() {
  group('DrugEvidenceDetector.detect', () {
    test('detecta amiodarona quando existe contexto farmacológico', () {
      final result = DrugEvidenceDetector.detect(
        'Administrar amiodarona IV em infusão conforme protocolo.',
      );

      expect(result, isNotNull);
      expect(result!.drugKey, 'amiodarona');
    });

    test('detecta fármaco em espanhol', () {
      final result = DrugEvidenceDetector.detect(
        'Indicar dosis de adenosina en bolo IV.',
      );

      expect(result, isNotNull);
      expect(result!.drugKey, 'adenosina');
    });

    test('não retorna evidência sem contexto farmacológico', () {
      final result = DrugEvidenceDetector.detect(
        'O paciente relata uso prévio de amiodarona.',
      );

      expect(result, isNull);
    });

    test('não retorna evidência para contexto sem fármaco conhecido', () {
      final result = DrugEvidenceDetector.detect(
        'Administrar medicamento em dose ajustada.',
      );

      expect(result, isNull);
    });

    test('respeita prioridade determinística da lista', () {
      final result = DrugEvidenceDetector.detect(
        'Administrar adenosina em bolo e considerar amiodarona IV.',
      );

      expect(result, isNotNull);
      expect(result!.drugKey, 'adenosina');
    });
  });
}
