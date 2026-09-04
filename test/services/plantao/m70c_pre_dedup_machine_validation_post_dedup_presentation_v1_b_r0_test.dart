import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';
import 'package:medcases/services/plantao_machine_native_context_prefetch.dart';

const _physicalLikeRawEs = '''
ANAFILAXIA

Conducta inmediata:
- Administrar adrenalina IM 0,01 mg/kg de la solución 1 mg/mL en la cara anterolateral del muslo; máximo 0,5 mg en el adulto.
- Evaluar de inmediato vía aérea, ventilación y circulación; administrar oxígeno y soporte ventilatorio según necesidad.
- Obtener acceso IV y usar cristaloide isotónico rápidamente si hay hipotensión/shock.

Tratamiento farmacológico:
- Adrenalina IM 0,01 mg/kg de la solución 1 mg/mL; máximo 0,5 mg en el adulto; repetir si la respuesta clínica es inadecuada.

Monitorización y reevaluación:
- Observar hasta la resolución completa.
- Reevaluar la respuesta clínica después de cada intervención.

Red flags/escalamiento:
- Escalar ante shock, obstrucción de vía aérea, hipoxemia o refractariedad.
''';

String _between(String text, String start, String end) {
  final a = text.indexOf(start);
  expect(a, greaterThanOrEqualTo(0));
  final b = text.indexOf(end, a + start.length);
  expect(b, greaterThan(a));
  return text.substring(a, b);
}

PlantaoGlobalClinicalContextPack _genericPack({
  List<String> required = const <String>[],
  List<String> prohibited = const <String>[],
}) {
  return PlantaoGlobalClinicalContextPack(
    pathologyKey: 'fixture',
    protocolKey: 'fixture_protocol',
    authoritative: true,
    requiredActions: required,
    prohibitedActions: prohibited,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M70C validate complete evidence before M70B presentation dedup', () {
    test(
      'bundled physical anaphylaxis pack passes safety while visible dose is deduped',
      () async {
        final prefetch = PlantaoMachineNativeContextPrefetch(
          source: PlantaoBundledPhase24MachineNativeRegistrySource(),
          cacheTtl: Duration.zero,
        );
        final resolved = await prefetch.prefetch(
          userText: 'anafilaxia',
          language: 'es',
        );

        expect(resolved.authoritative, isTrue);
        final pack = resolved.contextPack!;
        expect(pack.requiredActions, isNotEmpty);

        final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
          userText:
              'Paciente con anafilaxia después de medicación, con urticaria, disnea e hipotensión. ¿Cuál es el diagnóstico y la conducta inmediata?',
          rawText: _physicalLikeRawEs,
          language: 'es',
          contextPack: pack,
        );

        expect(
          result.issues.where(
            (issue) => issue.code == 'required_action_missing',
          ),
          isEmpty,
        );
        expect(result.hasCriticalIssue, isFalse);
        expect(result.machineAuthorityEvaluated, isTrue);

        final immediate = _between(
          result.finalText,
          'Conducta inmediata',
          'Tratamiento farmacológico',
        );
        final treatment = _between(
          result.finalText,
          'Tratamiento farmacológico',
          'Monitorización y reevaluación',
        );

        expect(immediate, contains('Administrar adrenalina IM'));
        // Non-regimen safety detail must survive the visible dedup.
        expect(immediate, contains('cara anterolateral del muslo'));
        expect(immediate, isNot(contains('0,01 mg/kg')));
        expect(immediate, isNot(contains('1 mg/mL')));
        expect(immediate, isNot(contains('máximo 0,5 mg')));

        expect(treatment, contains('0,01 mg/kg'));
        expect(treatment, contains('1 mg/mL'));
        expect(treatment, contains('máximo 0,5 mg'));
      },
    );

    test('a truly missing required action still fails closed', () {
      final pack = _genericPack(
        required: const <String>[
          'Evaluar vía aérea, ventilación y circulación.',
        ],
      );

      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'fixture',
        rawText: '''
SÍNDROME CLÍNICO

Conducta inmediata:
- Administrar MedicamentoAlfa IV.

Tratamiento farmacológico:
- MedicamentoAlfa IV 10 mg/kg.
''',
        language: 'es',
        contextPack: pack,
      );

      expect(
        result.issues.any((issue) => issue.code == 'required_action_missing'),
        isTrue,
      );
      expect(result.hasCriticalIssue, isTrue);
    });

    test('prohibited-action enforcement remains strict', () {
      final pack = _genericPack(
        prohibited: const <String>[
          'Administrar MedicamentoAlfa IV en bolo rápido.',
        ],
      );

      final result = PlantaoGlobalClinicalResponseGate.finalizeForPresentation(
        userText: 'fixture',
        rawText: '''
SÍNDROME CLÍNICO

Conducta inmediata:
- Administrar MedicamentoAlfa IV en bolo rápido.

Tratamiento farmacológico:
- MedicamentoAlfa IV 10 mg/kg.
''',
        language: 'es',
        contextPack: pack,
      );

      expect(
        result.issues.any((issue) => issue.code == 'prohibited_action_present'),
        isTrue,
      );
      expect(result.hasCriticalIssue, isTrue);
    });

    test(
      'source wiring keeps validation evidence and visible text separate',
      () {
        final text = File(
          'lib/services/plantao_global_clinical_response_gate.dart',
        ).readAsStringSync();

        expect(
          text,
          contains(
            'M70C_PRE_DEDUP_MACHINE_VALIDATION_POST_DEDUP_PRESENTATION_V1',
          ),
        );
        expect(
          RegExp(
            r'_validateAgainstMachinePack\(\s*canonicalProjected\s*,',
            multiLine: true,
          ).hasMatch(text),
          isTrue,
        );
        expect(text, contains('_m70bDeduplicateDetailedRegimenAcrossSections'));
      },
    );
  });
}
