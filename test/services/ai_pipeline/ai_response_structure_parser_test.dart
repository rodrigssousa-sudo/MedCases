import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_structured_output.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';
import 'package:medcases/services/plantao_pipeline.dart';

class FakePlantaoParser implements AiPlantaoParserPort {
  int calls = 0;
  String? capturedText;
  PlantaoResponse? result;

  @override
  PlantaoResponse? parse(String text) {
    calls++;
    capturedText = text;
    return result;
  }
}

ClinicalStructuredOutput buildClinicalOutput() {
  return ClinicalStructuredOutput(
    diagnosticoHeuristico: 'Pneumonia',
    condutaImediata: 'Iniciar tratamento.',
    prescricao: const [
      ClinicalPrescriptionItem(
        farmaco: 'Amoxicilina',
        posologia: '500 mg VO 8/8 h',
      ),
    ],
  );
}

void main() {
  group('AiResponseStructureParser', () {
    test(
      'Plantão delega o texto exatamente uma vez',
      () {
        final fake = FakePlantaoParser();

        fake.result = const PlantaoResponse(
          conduta: 'Choque séptico',
          monitorar: 'PAM e diurese',
        );

        final parser = AiResponseStructureParser(
          plantaoParser: fake,
        );

        final outcome = parser.parse(
          text: '🟥 Choque séptico\n'
              '📌 PAM e diurese',
          mode: AiRequestMode.plantao,
        );

        expect(fake.calls, 1);

        expect(
          fake.capturedText,
          '🟥 Choque séptico\n'
          '📌 PAM e diurese',
        );

        expect(outcome.hasPlantaoResponse, isTrue);

        expect(
          outcome.plantaoResponse?.conduta,
          'Choque séptico',
        );
      },
    );

    test(
      'Estudo não aciona o parser do Plantão',
      () {
        final fake = FakePlantaoParser();

        final parser = AiResponseStructureParser(
          plantaoParser: fake,
        );

        final outcome = parser.parse(
          text: 'Explicação acadêmica completa.',
          mode: AiRequestMode.estudo,
        );

        expect(fake.calls, 0);
        expect(outcome.plantaoResponse, isNull);
        expect(outcome.hasPlantaoResponse, isFalse);
      },
    );

    test(
      'structured output tipado preserva identidade',
      () {
        final clinical = buildClinicalOutput();

        const parser = AiResponseStructureParser();

        final outcome = parser.parse(
          text: 'Resposta clínica.',
          mode: AiRequestMode.estudo,
          structuredOutput: clinical,
        );

        expect(
          outcome.clinicalOutput,
          same(clinical),
        );

        expect(
          outcome.structuredOutputStatus,
          AiStructuredOutputStatus.valid,
        );

        expect(
          outcome.structuredOutputErrorCode,
          isNull,
        );
      },
    );

    test(
      'mapa válido usa ClinicalStructuredOutput canônico',
      () {
        const parser = AiResponseStructureParser();

        final outcome = parser.parse(
          text: 'Resposta clínica.',
          mode: AiRequestMode.estudo,
          structuredOutput: {
            'diagnosticoHeuristico': 'Hipoglicemia',
            'condutaImediata': 'Administrar glicose.',
            'prescricao': [
              {
                'farmaco': 'Glicose',
                'posologia': '25 g EV',
              },
            ],
          },
        );

        expect(
          outcome.structuredOutputStatus,
          AiStructuredOutputStatus.valid,
        );

        expect(outcome.hasClinicalOutput, isTrue);

        expect(
          outcome.clinicalOutput?.diagnosticoHeuristico,
          'Hipoglicemia',
        );

        expect(
          outcome.clinicalOutput?.prescricao.single.farmaco,
          'Glicose',
        );
      },
    );

    test(
      'payload não nulo inválido não degrada silenciosamente',
      () {
        const parser = AiResponseStructureParser();

        final outcome = parser.parse(
          text: 'Resposta textual.',
          mode: AiRequestMode.estudo,
          structuredOutput: {
            'diagnosticoHeuristico': 'Diagnóstico',
          },
        );

        expect(outcome.clinicalOutput, isNull);

        expect(
          outcome.structuredOutputStatus,
          AiStructuredOutputStatus.invalid,
        );

        expect(
          outcome.hasInvalidStructuredOutput,
          isTrue,
        );

        expect(
          outcome.structuredOutputErrorCode,
          'clinical_structured_output_invalid_keys',
        );
      },
    );

    test(
      'raiz estruturada de tipo incorreto é inválida',
      () {
        const parser = AiResponseStructureParser();

        final outcome = parser.parse(
          text: 'Resposta.',
          mode: AiRequestMode.plantao,
          structuredOutput: 'json inválido',
        );

        expect(
          outcome.structuredOutputStatus,
          AiStructuredOutputStatus.invalid,
        );

        expect(
          outcome.structuredOutputErrorCode,
          'clinical_structured_output_invalid_root',
        );
      },
    );

    test(
      'structured output ausente permanece explicitamente ausente',
      () {
        const parser = AiResponseStructureParser();

        final outcome = parser.parse(
          text: 'Resposta.',
          mode: AiRequestMode.estudo,
        );

        expect(
          outcome.structuredOutputStatus,
          AiStructuredOutputStatus.absent,
        );

        expect(outcome.clinicalOutput, isNull);
        expect(outcome.hasClinicalOutput, isFalse);
      },
    );

    test(
      'estrutura textual e estruturada podem coexistir',
      () {
        const parser = AiResponseStructureParser();

        final outcome = parser.parse(
          text: '🟥 Pneumonia\n'
              '💊 Amoxicilina 500 mg VO 8/8 h\n'
              '📌 Reavaliar em 48 horas',
          mode: AiRequestMode.plantao,
          structuredOutput: {
            'diagnosticoHeuristico': 'Pneumonia',
            'condutaImediata': 'Iniciar antibiótico.',
            'prescricao': [
              {
                'farmaco': 'Amoxicilina',
                'posologia': '500 mg VO 8/8 h',
              },
            ],
          },
        );

        expect(outcome.hasPlantaoResponse, isTrue);
        expect(outcome.hasClinicalOutput, isTrue);

        expect(
          outcome.plantaoResponse?.conduta,
          'Pneumonia',
        );

        expect(
          outcome.clinicalOutput?.diagnosticoHeuristico,
          'Pneumonia',
        );
      },
    );

    test(
      'parser estrutural nunca modifica o texto',
      () {
        const parser = AiResponseStructureParser();

        const text = '```json\n'
            '{"conduta":"Texto bruto"}\n'
            '```';

        final outcome = parser.parse(
          text: text,
          mode: AiRequestMode.plantao,
        );

        expect(outcome.text, text);
        expect(outcome.plantaoResponse, isNull);
      },
    );
  });
}
