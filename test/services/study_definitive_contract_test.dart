import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/safety/clinical_dose_scope.dart';
import 'package:medcases/services/ai/safety/clinical_safety_flow.dart';
import 'package:medcases/services/ai/safety/clinical_request_safety.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/study/study_reference_boundary.dart';
import 'package:medcases/services/clinical_thread_manager.dart';
import 'package:medcases/services/study_response_contract.dart';
import 'package:medcases/screens/ai/widgets/clinical_reference_resolver.dart';
import 'study_global_validation_regression_test.dart' show studyContext;

void main() {
  test('Study educational adjustments do not become individual prescriptions', () {
    for (final query in [
      'Explique os princípios de ajuste renal quando eGFR 22.',
      'Explique el ajuste renal cuando eGFR 22.',
      'Compare doses pediátricas de referência em crianças de 18 kg e 30 kg.',
      'Compare dosis pediátricas de referencia en niños de 18 kg y 30 kg.',
    ]) {
      final context = studyContext(query);
      expect(context.isGeneralEducationalQuery, isTrue, reason: query);
      expect(context.mayGenerate, isTrue, reason: query);
      const explanation = 'O ajuste depende do medicamento e de sua eliminação renal.';
      expect(ClinicalSafetyFlow(context).present(explanation), explanation);
    }
  });

  test('Study exact requests still require pertinent missing data', () {
    for (final query in [
      'calcule para este paciente',
      'ajuste para eGFR 22',
      'dose para criança de 18 kg',
      'dose exata para este caso',
      'ajuste Child-Pugh C',
      'calcula para este paciente',
      'dosis exacta para este caso',
    ]) {
      final context = studyContext(query);
      expect(context.answerability, Answerability.askForMissingData, reason: query);
      expect(context.safeMessage, isNot(contains('Não há suporte verificável')));
    }
  });

  test('Mixed request teaches the safe part and defers only the exact calculation', () {
    final context = studyContext('Explique a sepse e calcule a dose para este paciente');
    expect(context.answerability, Answerability.answerWithLimitations);
    expect(context.unknownCriticalFacts, contains('medicationContext'));
    final flow = ClinicalSafetyFlow(context);
    const safe = '# Sepse\n\nA disfunção orgânica decorre de resposta desregulada à infecção.';
    final answer = flow.present('$safe\n\nDose calculada para este paciente: 999 mg VO.');
    expect(answer, contains(safe));
    expect(answer, contains(context.safeMessage));
    expect(answer, isNot(contains('999 mg')));
    expect(flow.present(answer), answer);
  });

  test('Study preserves educational epidemiology and general monitoring', () {
    final context = studyContext('Estudo geral: sepse');
    for (final fragment in [
      'A idade de 65 anos é um exemplo de estratificação populacional, não um dado do paciente.',
      'Realizar reavaliação em 24 horas, conforme a evolução clínica.',
      'A classificação tem 3 estágios.',
    ]) {
      expect(ClinicalSafetyFlow(context).present(fragment), fragment);
    }
  });

  test('Study validates the complete decimal, not its trailing zero', () {
    for (final quantity in ['1.0 mg', '1,0 mg', '0.10 mg', '10-20 mg']) {
      expect(ClinicalDoseScope.hasInvalidReferenceValue(quantity), false, reason: quantity);
    }
    for (final quantity in ['0 mg', '0.00 mg', '-2 mg', '1-0 mg']) {
      expect(ClinicalDoseScope.hasInvalidReferenceValue(quantity), true, reason: quantity);
    }
  });

  test('Study fragment rejection does not erase the educational explanation', () {
    final context = studyContext('Metformina');
    const safe = '# Metformina\n\n## Mecanismo\nA redução da produção hepática de glicose contribui para seu efeito.';
    for (final unsafe in [
      'Dose calculada para este paciente: 999 mg VO.',
      'Administrar medicamento inventado 999 mg VO.',
      'Dose de referência: 1 mg = 1000 g.',
    ]) {
      expect(ClinicalSafetyFlow(context).present('$safe\n\n$unsafe'), safe);
    }
  });

  test('Plantão keeps its current scope classification', () {
    const query = 'Explique o ajuste renal quando eGFR 22.';
    final context = ClinicalRequestContext(
      requestId: 'fixture', sessionId: 'fixture', uid: 'fixture',
      mode: AiRequestMode.plantao, language: 'pt', userQuery: query,
      memory: ClinicalSafetyMemory().capture(uid: 'fixture', sessionId: 'fixture', userQuery: query),
      evidence: ClinicalEvidenceBundle(), createdAt: DateTime(2026),
    );
    expect(context.isGeneralEducationalQuery, isFalse);
  });

  test('Unverified bibliography is removed without replacing educational content', () {
    final boundary = StudyReferenceBoundary();
    const answer = '# Tema\n\n## Diagnóstico\nA avaliação considera o contexto clínico.';
    const forged = '\n\n## Referências\nAutor inventado (2099). DOI: 10.9999/fake\nhttps://invalid.example/fake';
    expect(boundary.present(answer + forged), answer);
    expect(boundary.present('$answer [fonte](https://invalid.example/fake) [17]'), '$answer fonte');
    expect(boundary.records, isEmpty);
  });

  test('reference boundary preserves clinical sections after a bibliography', () {
    final boundary = StudyReferenceBoundary(['Existing source']);
    const body = '# Tema\n\nExplicação.\n\n';
    const tail = '**Monitorização**\n\nAcompanhar a evolução clínica.';
    final actual = boundary.present('${body}## Referências\nFonte sem comprovação.\n\n$tail');
    expect(actual, '$body$tail');
    expect(boundary.present('Explicação [17]'), 'Explicação');
  });

  test('Only transport grounding or existing records can supply a reference', () {
    final boundary = StudyReferenceBoundary(['Existing catalog record']);
    boundary.addGrounding([
      (title: 'Verified transport source', url: 'https://example.org/source'),
      (title: 'Invalid', url: 'javascript:alert(1)'),
      (title: 'Credentials', url: 'https://name:secret@example.org'),
    ]);
    expect(boundary.records, hasLength(2));
    const body = '# Tema\n\nExplicação.';
    for (final lang in ['pt', 'es']) {
      final rendered = boundary.appendTo(body, lang);
      expect(boundary.present(rendered), body);
      expect(boundary.appendTo(boundary.present(rendered), lang), rendered);
    }
  });

  test('Study references have no generic or output-inferred fallback', () {
    expect(ClinicalReferenceResolver.resolveStudy(userText: 'Compare técnicas de memorização'), isNull);
    final pt = ClinicalReferenceResolver.resolveStudy(userText: 'Metformina: doses');
    final es = ClinicalReferenceResolver.resolveStudy(userText: 'Metformina: dosis');
    expect(pt, isNotNull);
    expect(pt!.lines, es!.lines);
    expect(pt.sourceType, startsWith('study_internal_'));
    expect(StudyResponseContract.referencePolicy, contains('não bloqueie'));
  });

  test('Study mechanism followup and mode change retain thread and history', () {
    final manager = ClinicalThreadManager();
    manager.evaluate(currentUserText: 'Metformina', isPlantaoMode: false);
    final original = manager.activeThreadId;
    final followup = manager.evaluate(currentUserText: 'Agora aprofunde o mecanismo mitocondrial.', isPlantaoMode: false);
    expect(followup.isContinuation, true);
    expect(manager.activeThreadId, original);
    final plantao = manager.evaluate(currentUserText: 'E qual a conduta resumida sobre ela?', isPlantaoMode: true);
    expect(plantao.isContinuation, true);
    expect(manager.activeThreadId, original);
    final history = ClinicalThreadManager.buildThreadHistory(
        fullHistory: [{'role':'user', 'content':'Metformina'}, {'role':'assistant', 'content':'Explicação educativa.'}],
        status: plantao, isPlantaoMode: true);
    expect(history.first['content'], 'Metformina');
    expect(history, hasLength(2));
  });
}
