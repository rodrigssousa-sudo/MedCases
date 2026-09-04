import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  group('PlantaoLocalClinicalOutputAdapter', () {
    test(
      'deriva somente fármacos e doses literais da resposta observada',
      () {
        const text = '''
🟥 CONSULTA CLÍNICA
📖 Resumo:
- Manejo de hiperglucemia aguda.
🔑 Pontos-chave:
- Evaluar cetonas y estado volémico.
- **Insulina regular 0.1 U/kg IV** bolo.
- Infusión **insulina 0.1 U/kg/h IV**.
⚠️ Alerta clínico: - No iniciar insulina si K+ < 3.3 mEq/L.
📌 Próximo: - Glucosa capilar horaria, electrolitos.
''';

        final output =
            PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

        expect(output, isNotNull);
        expect(output?.diagnosticoHeuristico, 'Hiperglucemia aguda');
        expect(output?.prescricao, hasLength(2));

        expect(output?.prescricao[0].farmaco, 'Insulina regular');
        expect(output?.prescricao[0].posologia, '0.1 U/kg IV bolo');

        expect(output?.prescricao[1].farmaco, 'Insulina');
        expect(output?.prescricao[1].posologia, '0.1 U/kg/h IV');
      },
    );

    test(
      'ignora glicemia, eletrólitos e monitorização sem contexto de fármaco',
      () {
        const text = '''
🟥 CONTROLE GLICÊMICO
- Glicemia 340 mg/dL.
- Potássio 3,4 mEq/L.
- Monitorar glicemia capilar a cada hora.
''';

        final output =
            PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

        expect(output, isNull);
      },
    );

    test(
      'aceita tratamento literal em português com dose e via',
      () {
        const text = '''
🟥 HIPERGLICEMIA AGUDA
- Administrar insulina regular 0,1 U/kg EV.
📌 Próximo: Reavaliar glicemia.
''';

        final output =
            PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

        expect(output, isNotNull);
        expect(output?.prescricao, hasLength(1));
        expect(output?.prescricao.single.farmaco, 'Insulina regular');
        expect(output?.prescricao.single.posologia, '0,1 U/kg EV');
      },
    );

    test(
      'não produz estrutura sem âncora válida do Guardia',
      () {
        const text = 'Insulina regular 0,1 U/kg EV.';

        final output =
            PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

        expect(output, isNull);
      },
    );

    test(
      'deduplica a mesma prescrição literal',
      () {
        const text = '''
🟥 HIPERGLICEMIA AGUDA
- **Insulina regular 0,1 U/kg EV**.
- **Insulina regular 0,1 U/kg EV**.
''';

        final output =
            PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

        expect(output, isNotNull);
        expect(output?.prescricao, hasLength(1));
      },
    );
  });
}
