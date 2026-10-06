import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/ai_smart_router.dart';
import 'package:medcases/services/study_response_contract.dart';
import 'package:medcases/services/ai_gateway_service.dart';
import 'package:medcases/services/ai/ai_finalization_transaction.dart';
import 'package:medcases/services/ai_pipeline/ai_response_finalization_processor.dart';
import 'package:medcases/services/ai_pipeline/ai_truncation_repair_coordinator.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';
import 'package:medcases/services/clinical_thread_manager.dart';
import 'study_internal_leak_regression_test.dart' show studyLeakFixture;

class _NoRepair implements AiTruncationRepairPort {
  @override
  Future<TruncationRepairResult> repair(
          {required String originalText,
          required String requestId,
          required bool isPlantaoMode,
          required String appLanguage}) async =>
      throw StateError('unexpected repair');
}

void main() {
  test('every transport boundary hides internal notes, including late leakage',
      () {
    final safe = '# Síndrome nefrótico\n\n## Concepto\n\n'
        '${List.filled(30, 'Contenido didáctico sintético completo.\n\n').join()}';
    final raw = '$safe$studyLeakFixture';
    var previous = '';
    for (var i = 0; i <= raw.length; i++) {
      final projected =
          StudyResponseContract.project(raw.substring(0, i), complete: false);
      expect(projected.clinicalAnswer, startsWith(previous.trimRight()),
          reason: 'boundary $i');
      expect(projected.clinicalAnswer,
          isNot(matches(r"Line 17|Let's|constraints|Language:|Checked|Anti-")));
      previous = projected.clinicalAnswer;
    }
    final finalText = StudyResponseContract.project(raw).clinicalAnswer;
    expect(finalText, startsWith(previous.trimRight()));
    expect(finalText, contains('Resumen sintético completo.'));
    expect(finalText, startsWith(safe));
  });

  test('clinical explanations, anti markers, doses and references remain exact',
      () {
    const safe = '# Síndrome nefrótico\n\n## Raciocínio clínico\n\n'
        'Explicação: anti-GBM e anti-Xa são termos clínicos.\n\n'
        '### Agente sintético\n\n- Dosis estándar de referencia: **5 mg VO c/24 h**.\n\n'
        '## Monitorización\n\nSeguimiento sintético.\n\n'
        '## Referencias\n\nReferencia sintética [A], sin enlace inventado.';
    expect(StudyResponseContract.project(safe).clinicalAnswer, safe);
    expect(StudyResponseContract.normalizePresentation(safe), safe);
    expect(
        StudyResponseContract.project('Anti-GBM').clinicalAnswer, 'Anti-GBM');
  });

  test('tagged notes and diagnostics are not mixed with the final answer', () {
    const raw = '<analysis>internal draft</analysis>\n'
        'Parser diagnostics:\nparser-specific details\n'
        'Final answer: # Tema\n\nRespuesta completa.\n\n'
        '<internal_notes>unclosed note';
    final output = StudyResponseContract.project(raw);
    expect(output.clinicalAnswer, '# Tema\n\nRespuesta completa.');
    expect(output.reasonCodes,
        containsAll(['INTERNAL_TAG', 'INTERNAL_DIAGNOSTIC_BLOCK']));
    expect(StudyResponseContract.project(output.clinicalAnswer).clinicalAnswer,
        output.clinicalAnswer);
  });

  test('empty/internal-only response cannot be considered a clinical answer',
      () async {
    final processor = AiResponseFinalizationProcessor(
        truncationCoordinator:
            AiTruncationRepairCoordinator(repairPort: _NoRepair()));
    final result = await processor.process(
        snapshot: FinalOutputSnapshot(
            rawOutput:
                "Let's review constraints:\nLanguage: Spanish -> Checked.\nAnti-",
            sessionId: 'study',
            parentRequestId: 'empty',
            frozenAt: DateTime(2026)),
        mode: AiRequestMode.estudo,
        locale: AiRequestLocale.es,
        provider: 'gemini_free',
        attempt: 1);
    expect(result.isReady, isFalse);
    expect(result.result, isNull);
  });

  for (final locale in AiRequestLocale.values) {
    test('Study finalizer separates diagnostics before repair ${locale.name}',
        () async {
      final processor = AiResponseFinalizationProcessor(
          truncationCoordinator:
              AiTruncationRepairCoordinator(repairPort: _NoRepair()));
      final result = await processor.process(
          snapshot: FinalOutputSnapshot(
              rawOutput:
                  '$studyLeakFixture\n\nInternal validation:\nLanguage: Spanish -> Checked.\nAnti-',
              sessionId: 'study',
              parentRequestId: locale.name,
              frozenAt: DateTime(2026)),
          mode: AiRequestMode.estudo,
          locale: locale,
          provider: 'gemini_free',
          attempt: 1,
          providerFinishReason: 'STOP');
      expect(result.isReady, isTrue);
      expect(result.result!.finalText, contains('Resumen sintético completo.'));
      expect(result.result!.finalText, isNot(contains('Internal validation')));
      expect(result.result!.displayText, result.result!.finalText);
      expect(result.snapshot.rawOutput, contains('Internal validation'));
      expect(result.truncation!.repairAttempted, isFalse);
    });
  }

  for (final lang in ['pt', 'es']) {
    test(
        'Study prompt has flexible didactic sections and no line-count mandate $lang',
        () {
      final prompt = prepareAiRequestPrompt(
              mode: AiRequestMode.estudo,
              systemPrompt: StudyResponseContract.forLanguage(lang))
          .systemPrompt;
      expect(prompt, contains('OUTPUT ONLY THE USER-FACING STUDY ANSWER'));
      expect(prompt, contains('fisiopatologia'));
      expect(prompt, contains('resumo'));
      expect(
          prompt,
          isNot(matches(
              r'CONTAGEM MATEMÁTICA|EXATAMENTE [12] linh|📌 OBRIGATÓRIO')));
      expect(prompt, isNot(contains('plantao_rules')));
    });
  }

  test(
      'Study follow-up and Study to Plantao retain topic and available history',
      () {
    final manager = ClinicalThreadManager();
    manager.evaluate(
        currentUserText: 'Explique metformina.', isPlantaoMode: false);
    final threadId = manager.activeThreadId;
    final followup = manager.evaluate(
        currentUserText: 'Agora aprofunde o mecanismo mitocondrial.',
        isPlantaoMode: false);
    expect(followup.isContinuation, isTrue);
    expect(manager.activeThreadId, threadId);
    final switched = manager.evaluate(
        currentUserText: 'Agora me dê só a conduta prática.',
        isPlantaoMode: true);
    expect(switched.isContinuation, isTrue);
    expect(manager.activeThreadId, threadId);
    final history = ClinicalThreadManager.buildThreadHistory(fullHistory: [
      {'role': 'user', 'content': 'Explique metformina.'},
      {'role': 'assistant', 'content': 'Explicação sintética.'},
    ], status: switched, isPlantaoMode: true);
    expect(history.length, 2);
    expect(history.first['content'], 'Explique metformina.');
  });
  test('mode transition never absorbs an explicit new case or topic', () {
    for (final query in [
      'Agora me dê só a conduta prática de asma.',
      'Novo paciente com pneumonia.',
      'Agora mude de tema: fale sobre asma.'
    ]) {
      final manager = ClinicalThreadManager();
      manager.evaluate(
          currentUserText: 'Explique metformina.', isPlantaoMode: false);
      final result =
          manager.evaluate(currentUserText: query, isPlantaoMode: true);
      expect(result.isContinuation, isFalse, reason: query);
    }
  });
  test(
      'Study acronym/dose query never injects operational Plantao lazy modules',
      () {
    for (final query in ['IAM', 'Metformina dosis', 'Explique a diluição']) {
      final prompt = AiSmartRouter.build(
              userMessage: query,
              systemPrompt: '',
              isPlantaoMode: false,
              appLanguage: 'es')
          .finalPrompt;
      expect(prompt, isNot(contains('resposta imediata em formato Plantão')));
      expect(prompt, isNot(contains('<instructions id="dose">')));
      expect(prompt, isNot(contains('<instructions id="diluicao">')));
    }
  });

  for (final lang in ['pt', 'es']) {
    test(
        'Study system prompt keeps referential follow-ups and hides validation $lang',
        () {
      final prompt = AiService.buildClinicalSystemPrompt(
          lang: lang,
          matchedProtocolSummaries: [],
          matchedDrugSummaries: [],
          userQuery: 'Agora aprofunde o mecanismo mitocondrial.',
          isPlantaoMode: false,
          isFirstMessage: false);
      expect(prompt, isNot(contains('Amnesia total')));
      expect(prompt, isNot(contains('Revisão interna silenciosa')));
      expect(
          prompt,
          contains(lang == 'es'
              ? 'Un seguimiento puede omitir'
              : 'Um follow-up pode omitir'));
    });
  }
  test('continuation metadata stays available to resolver but never renders',
      () {
    const text = '# Tema\n\nRespuesta sintética completa.\n\n'
        '[NEXT_ACTION_LABEL: Profundizar mecanismo]\n'
        '[NEXT_ACTION_PROMPT: Explica el mecanismo.]';
    expect(StudyResponseContract.project(text).clinicalAnswer,
        contains('NEXT_ACTION_LABEL'));
    for (var i = 0; i <= text.length; i++) {
      final visible = StudyResponseContract.normalizePresentation(
          text.substring(0, i),
          complete: false);
      expect(visible, isNot(contains('NEXT_ACTION')));
    }
    final finalText = StudyResponseContract.normalizePresentation(text);
    expect(finalText, contains('Respuesta sintética completa.'));
    expect(finalText, isNot(contains('NEXT_ACTION')));
  });
}
