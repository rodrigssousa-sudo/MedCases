import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/ai_finalization_transaction.dart';
import 'package:medcases/services/ai_pipeline/ai_response_finalization_processor.dart';
import 'package:medcases/services/ai_pipeline/ai_truncation_repair_coordinator.dart';
import 'package:medcases/services/ai/safety/clinical_request_safety.dart';
import 'package:medcases/services/ai/safety/clinical_safety_flow.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/screens/ai/widgets/ai_failure_message.dart';
import 'package:medcases/services/study_response_contract.dart';

ClinicalRequestContext studyContext(String query,
        {String lang = 'pt', bool Function()? owns}) =>
    ClinicalRequestContext(
        requestId: 'synthetic-request',
        sessionId: 'synthetic-session',
        uid: 'fixture',
        mode: AiRequestMode.estudo,
        language: lang,
        userQuery: query,
        memory: ClinicalSafetyMemory().capture(
            uid: 'fixture', sessionId: 'synthetic-session', userQuery: query),
        evidence: ClinicalEvidenceBundle(),
        createdAt: DateTime(2026, 9, 27),
        ownsRequest: owns);

// Synthetic educational output, never a patient prescription.
String nephroticAnswer(String lang) => lang == 'es'
    ? """# Síndrome nefrótico

## Definición
Proteinuria importante, hipoalbuminemia y edema caracterizan el síndrome.

## Fisiopatología
La lesión de la barrera glomerular aumenta la pérdida urinaria de proteínas.

## Causas
Las causas pueden ser primarias o secundarias a enfermedades sistémicas.

## Manifestaciones clínicas
El edema y la orina espumosa orientan la evaluación.

## Diagnóstico
Cuantificar la proteinuria y evaluar función renal, albúmina y perfil lipídico.
La proteinuria superior a 3,5 g/24 h es un criterio habitual en adultos.

## Tratamiento
Se recomienda tratar la causa y controlar edema, presión arterial y complicaciones.
La inmunosupresión depende de la etiología; no es universal.

## Monitorización
Realizar seguimiento de función renal, electrolitos, edema y respuesta al tratamiento.

## Puntos clave
La causa del síndrome determina el tratamiento específico."""
    : """# Síndrome nefrótico

## Definição
Proteinúria importante, hipoalbuminemia e edema caracterizam a síndrome.

## Fisiopatologia
A lesão da barreira glomerular aumenta a perda urinária de proteínas.

## Causas
As causas podem ser primárias ou secundárias a doenças sistêmicas.

## Manifestações clínicas
Edema e urina espumosa orientam a avaliação.

## Diagnóstico
Quantificar a proteinúria e avaliar função renal, albumina e perfil lipídico.
A proteinúria superior a 3,5 g/24 h é um critério habitual em adultos.

## Tratamento
Recomenda-se tratar a causa e controlar edema, pressão arterial e complicações.
A imunossupressão depende da etiologia; não é universal.

## Monitorização
Realizar seguimento da função renal, eletrólitos, edema e resposta ao tratamento.

## Pontos-chave
A causa da síndrome determina o tratamento específico.""";

Future<String> finalizeStudyFixture(String text, String lang) async {
  final outcome = await AiResponseFinalizationProcessor(
          truncationCoordinator: AiTruncationRepairCoordinator(
              repairPort: DelegatingAiTruncationRepairPort(
                  runner: (
                          {required originalText,
                          required requestId,
                          required isPlantaoMode,
                          required appLanguage}) async =>
                      throw StateError('Complete fixture must not repair'))))
      .process(
          snapshot: FinalOutputSnapshot(
              rawOutput: text,
              sessionId: 'fixture',
              parentRequestId: 'fixture',
              frozenAt: DateTime(2026)),
          mode: AiRequestMode.estudo,
          locale: lang == 'es' ? AiRequestLocale.es : AiRequestLocale.pt,
          provider: 'synthetic',
          attempt: 1,
          providerFinishReason: 'STOP');
  expectSync(outcome.isReady, isTrue);
  return outcome.result!.displayText;
}

void main() {
  for (final lang in ['pt', 'es']) {
    test(
        'Study nephrotic valid provider output survives all presentation passes $lang',
        () {
      final context = studyContext('Síndrome nefrótico', lang: lang);
      final flow = ClinicalSafetyFlow(context);
      final raw = nephroticAnswer(lang);
      expect(context.mayGenerate, isTrue);
      expect(context.evidence.items, isEmpty);
      // Strict prescription authority is intentionally distinct from educational presentation.
      expect(flow.terminal(raw).allowed, isFalse);
      var answer = StudyResponseContract.project(raw).clinicalAnswer;
      for (var pass = 0; pass < 4; pass++) {
        answer = flow.present(answer);
      }
      expect(answer, raw);
      expect(AiFailureMessage.recognize(answer), isNull);
      expect(ClinicalSafetyFlow.qualityLint(answer), answer);
    });
    test(
        'Study general treatment and dose questions need no individual data $lang',
        () {
      for (final query in lang == 'es'
          ? [
              'Metformina: dosis',
              'IAM: tratamiento y dosis',
              'Sepse',
              'Asma',
              'Síndrome nefrítico',
              'Explique dosis pediátricas de referencia'
            ]
          : [
              'Metformina: doses',
              'IAM: tratamento e doses',
              'Sepse',
              'Asma',
              'Síndrome nefrítica',
              'Explique doses pediátricas de referência'
            ]) {
        final c = studyContext(query, lang: lang);
        expect(c.mayGenerate, isTrue, reason: query);
        expect(c.isGeneralEducationalQuery, isTrue, reason: query);
      }
    });
    test('Study safe explanation survives mixed unsafe fragment $lang', () {
      final flow =
          ClinicalSafetyFlow(studyContext('Síndrome nefrótico', lang: lang));
      final safe = nephroticAnswer(lang);
      for (final unsafe in [
        'Administrar medicamento desconhecido 999 mg VO.',
        'Dose padrão de referência: 1 mg = 1000 g.',
        'Dose calculada para este paciente: 999 mg VO.',
        'peso: 80 kg'
      ]) {
        final result = flow.present('$safe\n\n$unsafe');
        expect(result, contains(safe));
        expect(result, isNot(contains(unsafe)));
        expect(AiFailureMessage.recognize(result), isNull);
      }
    });
  }
  for (final lang in ['pt', 'es']) {
    final treatment = lang == 'es'
        ? {
            'Síndrome nefrótico':
                'Se recomienda tratar la causa y controlar edema y función renal.',
            'Síndrome nefrítico':
                'Se recomienda evaluar hematuria, presión arterial y función renal.',
            'Sepse':
                'Se recomienda el reconocimiento temprano, el control del foco y la reevaluación hemodinámica.',
            'IAM':
                'Se recomienda la evaluación urgente, el ECG y la valoración de reperfusión según la presentación.',
            'Asma':
                'Se recomienda evaluar síntomas, función pulmonar y técnica inhalatoria.',
            'Metformina':
                'Metformina 500 mg VO con comidas como dosis de referencia; la pauta individual depende de la formulación y del contexto.',
            'Anemia': 'Se recomienda clasificar la anemia y tratar su causa.',
            'AVC':
                'Se recomienda distinguir el mecanismo mediante evaluación urgente e imagen cerebral.',
          }
        : {
            'Síndrome nefrótico':
                'Recomenda-se tratar a causa e controlar edema e função renal.',
            'Síndrome nefrítico':
                'Recomenda-se avaliar hematúria, pressão arterial e função renal.',
            'Sepse':
                'Recomenda-se o reconhecimento precoce, controle do foco e reavaliação hemodinâmica.',
            'IAM':
                'Recomenda-se avaliação urgente, ECG e avaliação de reperfusão conforme a apresentação.',
            'Asma':
                'Recomenda-se avaliar sintomas, função pulmonar e técnica inalatória.',
            'Metformina':
                'Metformina 500 mg VO com refeições como dose de referência; a posologia individual depende da formulação e do contexto.',
            'Anemia': 'Recomenda-se classificar a anemia e tratar sua causa.',
            'AVC':
                'Recomenda-se distinguir o mecanismo por avaliação urgente e imagem cerebral.',
          };
    for (final row in treatment.entries) {
      test(
          'Study matrix provider safety finalizer presentation ${row.key} $lang',
          () async {
        final flow = ClinicalSafetyFlow(studyContext(row.key, lang: lang));
        final raw = row.key == 'Síndrome nefrótico'
            ? nephroticAnswer(lang)
            : '# ${row.key}\n\n## ${lang == 'es' ? 'Tratamiento' : 'Tratamento'}\n\n${row.value}';
        expect(flow.context.mayGenerate, isTrue);
        final safe = flow.present(raw);
        final finalized = await finalizeStudyFixture(safe, lang);
        final callback = flow.present(finalized);
        final visible = ClinicalSafetyFlow.qualityLint(
            StudyResponseContract.normalizePresentation(callback));
        expect(visible, raw);
        expect(flow.acceptsStudyPresentation(visible), isTrue);
        expect(AiFailureMessage.recognize(visible), isNull);
        expect(visible, isNot(contains('Language:')));
        if (row.key == 'Síndrome nefrótico') {
          final record = {
            'language': lang,
            'provider_chars': raw.length,
            'post_safety_chars': safe.length,
            'callback_chars': callback.length,
            'ui_chars': visible.length,
            'safe_content_retention': visible.length / raw.length
          };
          print('STUDY_RETENTION=${jsonEncode(record)}');
        }
      });
    }
  }
  test(
      'all Study output owners use granular presentation; UI lint is text-only',
      () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final start =
        source.indexOf('String _applyPlantaoClinicalRegimenOutputGuard(');
    final guard = source.substring(start,
        source.indexOf('if (longResponse || assistantOutput.isEmpty)', start));
    expect(
        guard,
        contains(
            'ClinicalSafetyFlow(clinicalContext).present(assistantOutput)'));
    expect(guard, isNot(contains('return clinicalContext.safeMessage')));
    expect(source, isNot(contains('longResponse && !rawSafety.allowed')));
    final lintStart = source.indexOf('String guardAiClinicalPresentation(');
    final lint = source.substring(
        lintStart, source.indexOf('// ── BUILD 249', lintStart));
    expect(lint, contains('ClinicalSafetyFlow.qualityLint(text)'));
    expect(lint, isNot(contains('.present(')));
    expect(source, contains('acceptsStudyPresentation(safeAssistantOutput)'));
  });
  test(
      'Study terminal guard retains every valid general section and reference dose',
      () {
    final f = ClinicalSafetyFlow(studyContext('Metformina: doses'));
    const s =
        '# Metformina\n\n## Doses de referência\n\nMetformina 500 mg VO com refeições.\n\n## Monitorização\n\nRecomenda-se acompanhar a função renal.';
    expect(f.present(s), s);
  });
  test(
      'Study fragment guard preserves completed safe preview after unsafe fragment',
      () {
    final f = ClinicalSafetyFlow(studyContext('Síndrome nefrótico'));
    const safe = 'A barreira glomerular participa do mecanismo.';
    expect(f.preview('$safe\n\nAdministrar 999 mg.\n\n'), safe);
  });
  test('Study never promotes unsafe headings or invented patient facts', () {
    final flow = ClinicalSafetyFlow(studyContext('Síndrome nefrótico'));
    for (final unsafe in [
      '## Administrar 999 mg.',
      '## peso: 80 kg',
      'Administrar medicamento inventado.',
      '1 mg = 1 mcg.'
    ]) {
      final text = flow.present('Explicação educacional.\n\n$unsafe');
      expect(text, contains('Explicação educacional.'));
      expect(text, isNot(contains(unsafe)));
    }
    final allergy = ClinicalSafetyFlow(
        studyContext('Para meu paciente; alergias: penicilina'));
    expect(allergy.present('Explicação geral.\n\nalergias: nenhuma'),
        'Explicação geral.');
  });
  test(
      'Study pregnancy and hepatic personalization retain missing-context gates',
      () {
    for (final query in [
      'Calcule dose para gestante',
      'ajuste Child-Pugh C',
      'Calcule dose renal para este paciente'
    ]) {
      final c = studyContext(query);
      expect(c.mayGenerate, isFalse, reason: query);
      expect(c.unknownCriticalFacts, isNotEmpty, reason: query);
    }
  });
  test('Study individualization, ownership and mode guards remain active', () {
    for (final q in [
      'Calcule dose pediátrica para 22 kg',
      'Ajuste de dose renal',
      'Calcule la dosis exacta para este paciente',
      'Cálculo de infusão em mL/h'
    ]) {
      final c = studyContext(q);
      expect(c.mayGenerate, isFalse, reason: q);
      expect(() => c.requireTransport(mode: 'estudo', language: 'pt'),
          throwsStateError);
      expect(
          ClinicalSafetyFlow(c).present('Administrar 999 mg.'), c.safeMessage);
    }
    final stale = studyContext('Síndrome nefrótico', owns: () => false);
    expect(ClinicalSafetyFlow(stale).preview('Explicação.\n\n'), isNull);
    expect(ClinicalSafetyFlow(stale).present('Explicação.'), stale.safeMessage);
    final c = studyContext('Síndrome nefrótico');
    expect(
        ClinicalSafetyFlow(c)
            .present('Explicação.', mode: AiRequestMode.plantao),
        c.safeMessage);
  });
}
