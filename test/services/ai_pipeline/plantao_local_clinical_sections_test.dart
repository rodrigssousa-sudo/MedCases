import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao_local_clinical_output_adapter.dart';

void main() {
  group('PlantaoLocalClinicalOutputAdapter section mapping', () {
    test('mapeia somente seções explicitamente rotuladas', () {
      const text = '''
🟥 SCA COM SUPRA DE ST
🚨 Conducta inmediata:
- ECG en menos de 10 minutos.
- Monitorización continua.
💊 Tratamiento farmacológico:
1ª línea:
- **AAS 300 mg VO** masticar.
- **Clopidogrel 300-600 mg VO**.
2ª línea:
- **Ticagrelor 180 mg VO**.
🔑 Puntos clave:
- Reperfusión inmediata cuando indicada.
⛔ HARD STOP:
- No usar nitratos si hipotensión.
''';

      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

      expect(output, isNotNull);
      expect(output?.condutaImediataItens, hasLength(2));
      expect(output?.primeiraLinha, hasLength(2));
      expect(output?.segundaLinha, hasLength(1));
      expect(output?.pontosChave, hasLength(1));
      expect(output?.hardStops, hasLength(1));
      expect(output?.prescricao, hasLength(3));
      expect(output?.primeiraLinha.first.farmaco, 'AAS');
      expect(output?.segundaLinha.single.farmaco, 'Ticagrelor');
    });

    test('não inventa prioridade para prescrições sem rótulo', () {
      const text = '''
🟥 HIPERTRIGLICERIDEMIA SEVERA
🔑 Puntos clave:
- **Fenofibrato 145 mg VO** diario.
- **Omega-3 4 g VO** diario.
''';

      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

      expect(output, isNotNull);
      expect(output?.prescricao, hasLength(2));
      expect(output?.primeiraLinha, isEmpty);
      expect(output?.segundaLinha, isEmpty);
    });

    test('não transforma próximo passo em ponto-chave', () {
      const text = '''
🟥 HIPERGLICEMIA
💊 Tratamiento farmacológico:
1ª línea:
- **Insulina regular 0,1 U/kg EV**.
📌 Siguiente paso:
- Solicitar electrolitos.
''';

      final output = PlantaoLocalClinicalOutputAdapter.fromValidatedText(text);

      expect(output, isNotNull);
      expect(output?.primeiraLinha, hasLength(1));
      expect(output?.pontosChave, isEmpty);
      expect(output?.hardStops, isEmpty);
    });
  });
}
