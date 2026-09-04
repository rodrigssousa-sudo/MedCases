import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';

void main() {
  group('Plantao Markdown table EOF truncation V1-B-R0', () {
    test('complete AHA ACC table ending in pipe is clean', () {
      const output = '''
| Categoría | Criterios | Conducta recomendada |
| --- | --- | --- |
| A | TEP confirmado de bajo riesgo | Anticoagulación y seguimiento |
| B | Riesgo intermedio | Monitorización y anticoagulación |
| C | Deterioro clínico | Reevaluación urgente y PERT |
''';

      final result = TruncationInspector.inspect(output);

      expect(result.isTruncated, isFalse);
      expect(result.confidenceLevel, TruncationConfidence.low);
      expect(result.violationReason, isNull);
    });

    test('escaped pipe inside cell keeps table complete', () {
      const output = r'''
| Categoría | Criterio |
| --- | --- |
| B | VD anormal \| biomarcador positivo |
''';

      expect(TruncationInspector.inspect(output).isTruncated, isFalse);
    });

    test('incomplete final row remains H4 truncated', () {
      const output = '''
| Categoría | Criterios | Conducta |
| --- | --- | --- |
| B | VD anormal |
''';

      final result = TruncationInspector.inspect(output);

      expect(result.isTruncated, isTrue);
      expect(
        result.violationReason,
        equals('abrupt_non_punctuation_termination'),
      );
    });

    test('plain prose ending in pipe is not treated as a table', () {
      final result = TruncationInspector.inspect('Conducta pendiente |');

      expect(result.isTruncated, isTrue);
      expect(
        result.violationReason,
        equals('abrupt_non_punctuation_termination'),
      );
    });

    test('unfinished numeric range in table remains fail closed', () {
      const output = '''
| Fármaco | Dosis |
| --- | --- |
| Noradrenalina | 0,05– |
''';

      expect(TruncationInspector.inspect(output).isTruncated, isTrue);
    });

    test('ordinary punctuated prose remains clean', () {
      const output =
          'Anticoagulación indicada según riesgo hemorrágico y contexto clínico.';

      expect(TruncationInspector.inspect(output).isTruncated, isFalse);
    });
  });
}
