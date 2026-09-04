import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';
import 'package:medcases/services/ai_pipeline/plantao/plantao_explicit_named_topic_semantic_guard.dart';

void main() {
  group('Pleural closure V1-B-R0', () {
    test('derrame pleural receives BTS pleural guideline references', () {
      final result = ClinicalReferenceResolver.resolve(
        userText: 'derrame pleural',
        aiText: '🟥 DERRAME PLEURAL\n🚨 Conducta inmediata:',
        lang: 'es',
      );

      final text = result.lines.join(' ');
      expect(
        result.sourceType,
        'specialty_fallback_pleural_effusion_bts_2023',
      );
      expect(text, contains('BTS'));
      expect(text, contains('Guideline for Pleural Disease'));
      expect(text, contains('Clinical Statement on Pleural Procedures'));
      expect(text, contains('2023'));
      expect(text, isNot(contains("Harrison's")));
      expect(text, isNot(contains('KDIGO')));
    });

    test('empiema and parapneumonic effusion use pleural-specific authority', () {
      const expectedSourceTypes = <String, String>{
        'empiema pleural': 'specialty_fallback_pleural_empyema_bts_2023',
        'derrame parapneumónico': 'specialty_fallback_pleural_empyema_bts_2023',
        'pleural infection': 'specialty_fallback_pleural_empyema_bts_2023',
      };
      for (final entry in expectedSourceTypes.entries) {
        final result = ClinicalReferenceResolver.resolve(
          userText: entry.key,
          aiText: '🟥 ENFERMEDAD PLEURAL',
          lang: 'es',
        );

        expect(result.sourceType, entry.value, reason: entry.key);
        expect(result.lines.join(' '), contains('BTS'), reason: entry.key);
        expect(
          result.lines.join(' '),
          isNot(contains('KDIGO')),
          reason: entry.key,
        );
      }
    });

    test('pleural paracentesis is normalized to thoracentesis in Spanish', () {
      const raw = '🟥 DERRAME PLEURAL\n'
          '🚨 Conducta inmediata:\n'
          '• Evaluar la necesidad de ecografía torácica para guiar paracentesis\n'
          '🔑 Puntos clave:\n'
          '• analizar líquido pleural\n';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'derrame pleural',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, contains('guiar toracocentesis'));
      expect(out.toLowerCase(), isNot(contains('paracentesis')));
    });

    test('pleural paracentesis is normalized to thoracentesis in Portuguese',
        () {
      const raw = '🟥 DERRAME PLEURAL\n'
          '🚨 Conduta imediata:\n'
          '• Avaliar ultrassom torácico para guiar paracentese\n'
          '🔑 Pontos-chave:\n'
          '• analisar líquido pleural\n';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'derrame pleural',
        assistantOutput: raw,
        languageCode: 'pt',
      );

      expect(out, contains('guiar toracocentese'));
      expect(out.toLowerCase(), isNot(contains('paracentese')));
    });

    test('abdominal paracentesis is not changed outside pleural context', () {
      const raw = '🟥 ASCITIS\n'
          '🚨 Conducta inmediata:\n'
          '• Realizar paracentesis diagnóstica\n';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'ascitis',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, raw);
    });

    test('unresolved dose-route placeholder is removed, not guessed', () {
      const raw = '🟥 DERRAME PLEURAL\n'
          '🚨 Conducta inmediata:\n'
          '• Realizar ecografía torácica\n'
          '💊 Tratamiento farmacológico:\n'
          '• Diurético + dosis según cuadro clínico + vía — si hay sospecha de insuficiencia cardíaca\n'
          '🔑 Puntos clave:\n'
          '• Determinar la etiología del derrame pleural\n';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'derrame pleural',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, isNot(contains('+ dosis según cuadro clínico + vía')));
      expect(out, isNot(contains('💊 Tratamiento farmacológico:')));
      expect(out, contains('Determinar la etiología'));
      expect(out, isNot(contains('40 mg')));
      expect(out, isNot(contains('20 mg')));
    });

    test('valid medication content is preserved', () {
      const raw = '🟥 PATOLOGÍA CLÍNICA\n'
          '💊 Tratamiento farmacológico:\n'
          '• Fármaco válido 10 mg VO\n'
          '🔑 Puntos clave:\n'
          '• reevaluar\n';

      final out = PlantaoExplicitNamedTopicSemanticGuard.materialize(
        userInput: 'patología clínica',
        assistantOutput: raw,
        languageCode: 'es',
      );

      expect(out, raw);
    });
  });
}
