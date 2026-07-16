import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';

void main() {
  group('ClinicalStructuredOutput', () {
    const validJson = <String, dynamic>{
      'diagnosticoHeuristico': 'Pneumonia adquirida na comunidade',
      'condutaImediata': 'Avaliar estabilidade e iniciar suporte.',
      'prescricao': <Map<String, dynamic>>[
        <String, dynamic>{
          'farmaco': 'Ceftriaxona',
          'posologia': '1–2 g IV a cada 24 horas',
        },
      ],
    };

    test('parseia o schema exato do backend', () {
      final output = ClinicalStructuredOutput.fromJson(validJson);

      expect(
        output.diagnosticoHeuristico,
        'Pneumonia adquirida na comunidade',
      );
      expect(
        output.condutaImediata,
        'Avaliar estabilidade e iniciar suporte.',
      );
      expect(output.prescricao, hasLength(1));
      expect(output.prescricao.single.farmaco, 'Ceftriaxona');
      expect(
        output.prescricao.single.posologia,
        '1–2 g IV a cada 24 horas',
      );
    });

    test('serialização preserva o contrato original', () {
      final output = ClinicalStructuredOutput.fromJson(validJson);

      expect(output.toJson(), equals(validJson));
    });

    test('aceita prescrição vazia', () {
      final output = ClinicalStructuredOutput.fromJson(
        const <String, dynamic>{
          'diagnosticoHeuristico': 'Hipótese clínica',
          'condutaImediata': 'Reavaliar e investigar.',
          'prescricao': <dynamic>[],
        },
      );

      expect(output.prescricao, isEmpty);
    });

    test('tryFromJson retorna null para structuredOutput null', () {
      expect(
        ClinicalStructuredOutput.tryFromJson(null),
        isNull,
      );
    });

    test('tryFromJson rejeita campo obrigatório vazio', () {
      expect(
        ClinicalStructuredOutput.tryFromJson(
          const <String, dynamic>{
            'diagnosticoHeuristico': '',
            'condutaImediata': 'Conduta',
            'prescricao': <dynamic>[],
          },
        ),
        isNull,
      );
    });

    test('tryFromJson rejeita chaves extras', () {
      expect(
        ClinicalStructuredOutput.tryFromJson(
          const <String, dynamic>{
            'diagnosticoHeuristico': 'Diagnóstico',
            'condutaImediata': 'Conduta',
            'prescricao': <dynamic>[],
            'campoInesperado': true,
          },
        ),
        isNull,
      );
    });

    test('tryFromJson rejeita item de prescrição inválido', () {
      expect(
        ClinicalStructuredOutput.tryFromJson(
          const <String, dynamic>{
            'diagnosticoHeuristico': 'Diagnóstico',
            'condutaImediata': 'Conduta',
            'prescricao': <Map<String, dynamic>>[
              <String, dynamic>{
                'farmaco': 'Dipirona',
              },
            ],
          },
        ),
        isNull,
      );
    });

    test('lista de prescrição é imutável', () {
      final output = ClinicalStructuredOutput.fromJson(validJson);

      expect(
        () => output.prescricao.add(
          const ClinicalPrescriptionItem(
            farmaco: 'Outro',
            posologia: 'Outra',
          ),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
