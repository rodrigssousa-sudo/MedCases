import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_explicit_named_topic_semantic_guard.dart';

void main() {
  group('PlantaoExplicitNamedTopicSemanticGuard', () {
    test('coledocolitiasis removes accidental differential framing', () {
      const raw = '''
🟥 COLECISTOLITIASIS — DIFERENCIALES PRIORITARIOS
🚨 Evaluación inicial:
• evaluar estabilidad y síntomas gastrointestinales
🔑 Puntos clave:
• Posibilidad 1: cólico biliar
• Posibilidad 2: colecistitis aguda
• Posibilidad 3: pancreatitis
🚩 RED FLAGS:
• ictericia, fiebre alta o sepsis
📌 ecografía abdominal como evaluación inicial
''';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'COLEDUCOLITIASIS',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, startsWith('🟥 COLEDUCOLITIASIS'));
      expect(out, contains('🚨 Conducta inmediata:'));
      expect(out, isNot(contains('DIFERENCIALES PRIORITARIOS')));
      expect(out, isNot(contains('Posibilidad 1:')));
      expect(out, isNot(contains('Posibilidad 2:')));
      expect(out, isNot(contains('Posibilidad 3:')));
      expect(out, contains('RED FLAGS'));
      expect(out, contains('ecografía abdominal'));
    });

    test('named syndrome also receives direct-route protection', () {
      const raw = '''
🟥 CUADRO BILIAR — DIFERENCIALES PRIORITARIOS
🚨 Evaluación inicial:
• evaluar estabilidad
🔑 Puntos clave:
• Posibilidad 1: obstrucción biliar
• Posibilidad 2: pancreatitis
📌 completar evaluación
''';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'síndrome coledociano',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, startsWith('🟥 SÍNDROME COLEDOCIANO'));
      expect(out, isNot(contains('Posibilidad 1:')));
      expect(out, isNot(contains('DIFERENCIALES PRIORITARIOS')));
    });

    test('manejo de named pathology is direct route', () {
      const raw = '''
🟥 NEUMOTÓRAX — DIFERENCIALES PRIORITARIOS
🚨 Evaluación inicial:
• evaluar estabilidad respiratoria
🔑 Puntos clave:
• Posibilidad 1: neumotórax simple
• Posibilidad 2: hemotórax
📌 reevaluar
''';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'manejo de neumotórax abierto',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, startsWith('🟥 NEUMOTÓRAX ABIERTO'));
      expect(out, isNot(contains('Posibilidad 1:')));
    });

    test('symptom-only query preserves differential byte-equivalent', () {
      const raw = '''
🟥 DOLOR ABDOMINAL — DIFERENCIALES PRIORITARIOS
🚨 Evaluación inicial:
• evaluar estabilidad
🔑 Puntos clave:
• Posibilidad 1: colecistitis
• Posibilidad 2: pancreatitis
''';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'dolor abdominal',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, raw);
    });

    test('explicit differential request is preserved byte-equivalent', () {
      const raw = '''
🟥 COLEDOCOLITIASIS — DIFERENCIALES PRIORITARIOS
🔑 Puntos clave:
• Posibilidad 1: estenosis biliar
• Posibilidad 2: tumor periampular
''';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'diagnóstico diferencial de coledocolitiasis',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, raw);
    });

    test('correct IAM remains byte-equivalent', () {
      const raw = '''
🟥 INFARTO AGUDO DE MIOCARDIO
🚨 Conducta inmediata:
• realizar ECG
💊 Tratamiento farmacológico:
• AAS según contrato clínico vigente
🔑 Puntos clave:
• evaluar reperfusión
🚩 RED FLAGS:
• shock
📌 reevaluar
''';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'IAM',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, raw);
    });

    test('PT named pathology removes accidental possibilidades', () {
      const raw = '''
🟥 COLECISTITE — DIFERENCIAIS PRIORITARIOS
🚨 Avaliacao inicial:
• avaliar estabilidade
🔑 Pontos-chave:
• Possibilidade 1: colica biliar
• Possibilidade 2: pancreatite
🚩 RED FLAGS:
• sepse
📌 reavaliar
''';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'coledocolitíase',
        assistantOutput: raw,
        languageCode: 'pt',
      );

      expect(out, startsWith('🟥 COLEDOCOLITÍASE'));
      expect(out, contains('🚨 Conduta imediata:'));
      expect(out, isNot(contains('Possibilidade 1:')));
      expect(out, isNot(contains('DIFERENCIAIS PRIORITARIOS')));
    });
  });
}
