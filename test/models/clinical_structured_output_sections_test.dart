import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';

void main() {
  group('ClinicalStructuredOutput sections contract', () {
    final aspirin = ClinicalPrescriptionItem(
      farmaco: 'AAS',
      posologia: '300 mg VO',
    );

    test('mantém construtor e JSON legados', () {
      final output = ClinicalStructuredOutput(
        diagnosticoHeuristico: 'SCA com supra de ST',
        condutaImediata: 'ECG e monitorização',
        prescricao: <ClinicalPrescriptionItem>[aspirin],
      );

      expect(output.condutaImediataItens, isEmpty);
      expect(output.primeiraLinha, isEmpty);
      expect(output.segundaLinha, isEmpty);
      expect(output.pontosChave, isEmpty);
      expect(output.hardStops, isEmpty);

      expect(
        output.toJson().keys.toSet(),
        <String>{
          'diagnosticoHeuristico',
          'condutaImediata',
          'prescricao',
        },
      );
    });

    test('aceita e serializa as cinco seções explícitas', () {
      final output = ClinicalStructuredOutput(
        diagnosticoHeuristico: 'SCA com supra de ST',
        condutaImediata: 'ECG e monitorização',
        prescricao: <ClinicalPrescriptionItem>[aspirin],
        condutaImediataItens: const <String>[
          'ECG em menos de 10 minutos',
          'Monitorização contínua',
        ],
        primeiraLinha: <ClinicalPrescriptionItem>[aspirin],
        segundaLinha: <ClinicalPrescriptionItem>[
          ClinicalPrescriptionItem(
            farmaco: 'Ticagrelor',
            posologia: '180 mg VO',
          ),
        ],
        pontosChave: const <String>[
          'Reperfusão imediata quando indicada',
        ],
        hardStops: const <String>[
          'Não usar nitrato em hipotensão',
        ],
      );

      final restored = ClinicalStructuredOutput.fromJson(output.toJson());

      expect(restored.condutaImediataItens, hasLength(2));
      expect(restored.primeiraLinha.single.farmaco, 'AAS');
      expect(restored.segundaLinha.single.farmaco, 'Ticagrelor');
      expect(restored.pontosChave, hasLength(1));
      expect(restored.hardStops, hasLength(1));
    });

    test('continua aceitando payload JSON legado', () {
      final restored = ClinicalStructuredOutput.fromJson(
        <String, dynamic>{
          'diagnosticoHeuristico': 'Hiperglicemia',
          'condutaImediata': 'Avaliar cetonas',
          'prescricao': <Map<String, String>>[
            <String, String>{
              'farmaco': 'Insulina regular',
              'posologia': '0,1 U/kg EV',
            },
          ],
        },
      );

      expect(restored.prescricao, hasLength(1));
      expect(restored.primeiraLinha, isEmpty);
      expect(restored.pontosChave, isEmpty);
    });

    test('rejeita chave desconhecida', () {
      final restored = ClinicalStructuredOutput.tryFromJson(
        <String, dynamic>{
          'diagnosticoHeuristico': 'Hiperglicemia',
          'condutaImediata': 'Avaliar cetonas',
          'prescricao': <Object>[],
          'campoInventado': <Object>[],
        },
      );

      expect(restored, isNull);
    });

    test('rejeita item vazio em pontos-chave', () {
      final restored = ClinicalStructuredOutput.tryFromJson(
        <String, dynamic>{
          'diagnosticoHeuristico': 'Hiperglicemia',
          'condutaImediata': 'Avaliar cetonas',
          'prescricao': <Object>[],
          'pontosChave': <String>[''],
        },
      );

      expect(restored, isNull);
    });

    test('listas expostas são imutáveis', () {
      final output = ClinicalStructuredOutput(
        diagnosticoHeuristico: 'Hiperglicemia',
        condutaImediata: 'Avaliar cetonas',
        prescricao: <ClinicalPrescriptionItem>[aspirin],
        pontosChave: const <String>['Monitorar potássio'],
      );

      expect(
        () => output.pontosChave.add('Outro'),
        throwsUnsupportedError,
      );
      expect(
        () => output.primeiraLinha.add(aspirin),
        throwsUnsupportedError,
      );
    });
  });
}
