import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/safety/clinical_patient_quantity.dart';
import 'package:medcases/services/ai/safety/clinical_query_scope.dart';
import 'package:medcases/services/ai/safety/clinical_request_safety.dart';
import 'package:medcases/services/ai/safety/clinical_sections.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/clinical_thread_manager.dart';

ClinicalRequestContext turn(ClinicalSafetyMemory memory, String query,
        {String lang = 'es',
        AiRequestMode mode = AiRequestMode.plantao,
        bool newPatient = false}) =>
    ClinicalRequestContext(
        requestId: 'qa',
        sessionId: 'same-chat',
        uid: 'synthetic',
        mode: mode,
        language: lang,
        userQuery: query,
        memory: memory.capture(
            uid: 'synthetic',
            sessionId: 'same-chat',
            userQuery: query,
            newPatient: newPatient),
        evidence: ClinicalEvidenceBundle(),
        createdAt: DateTime(2026, 10, 2));

void main() {
  for (final query in [
    'Dosis de alteplasa para un peso de noventa kilogramos',
    'Dose de medicamento para um peso de noventa quilogramas',
    '¿Cuál sería la dosis para 90 kg?',
    'Qual a dose para 90 kg?',
    'peso de 90 kg',
    'pesa 90 kilogramos',
  ]) {
    test('explicit weight normalized: $query', () {
      expect(ClinicalFacts.fromUserText(query).weightKg, 90);
      if (query.toLowerCase().contains('dos')) {
        expect(ClinicalQueryScopePolicy.classify(query),
            ClinicalQueryScope.calculationOrIndividualization);
      }
    });
  }
  test('unknown number words are not guessed', () {
    expect(ClinicalPatientQuantity.hasWeight('peso de muitos quilogramas'),
        isFalse);
  });
  test('negated and hypothetical weights stay unknown', () {
    expect(ClinicalFacts.fromUserText('no pesa 90 kg').weightKg, isNull);
    expect(ClinicalFacts.fromUserText('si pesa noventa kilogramos').weightKg,
        isNull);
  });
  for (final lang in ['pt', 'es']) {
    test('$lang missing only indication and next turn retains weight/drug', () {
      final memory = ClinicalSafetyMemory();
      final first = turn(
          memory,
          lang == 'es'
              ? 'Dosis de medicamento para 90 kg'
              : 'Dose de medicamento para 90 kg',
          lang: lang);
      expect(first.unknownCriticalFacts, ['indication']);
      expect(first.safeMessage, contains('90 kg'));
      expect(first.safeMessage, contains('medicamento'));
      expect(first.mayGenerate, isFalse);
      final second = turn(memory, 'indicación sintética', lang: lang);
      expect(second.weightKg, 90);
      expect(second.knownFacts.values['indication'], 'indicación sintética');
      final third = turn(memory,
          lang == 'es' ? '¿Y la dosis para 90 kg?' : 'E a dose para 90 kg?',
          lang: lang);
      expect(third.unknownCriticalFacts, isEmpty);
      expect(third.unsupportedWeightCalculationMessage, contains('90 kg'));
      expect(third.unsupportedWeightCalculationMessage, isNot(contains('mg')));
    });
    test(
        '$lang prior user indication reused and explicit scenario weight changes',
        () {
      final memory = ClinicalSafetyMemory();
      turn(
          memory,
          lang == 'es'
              ? 'Explícame el uso de medicamento en indicación sintética.'
              : 'Explique o uso de medicamento em indicação sintética.',
          lang: lang);
      final dose = turn(
          memory,
          lang == 'es'
              ? '¿Cuál sería la dosis para 90 kg?'
              : 'Qual a dose para 90 kg?',
          lang: lang);
      expect(dose.unknownCriticalFacts, isEmpty);
      expect(dose.knownFacts.values['indication'], contains('sint'));
      final changed = turn(
          memory, lang == 'es' ? '¿y para 80 kg?' : 'e para 80 kg?',
          lang: lang);
      expect(changed.weightKg, 80);
      expect(changed.knownFacts.rejected, isEmpty);
      final fresh =
          turn(memory, 'nuevo paciente', newPatient: true, lang: lang);
      expect(fresh.knownFacts.values, isEmpty);
    });
  }
  test('pending indication does not consume a new question or topic command', () {
    final memory = ClinicalSafetyMemory();
    turn(memory, 'Dosis de medicamento para 90 kg');
    expect(memory.acceptsIndicationReply('¿y la dosis?'), isFalse);
    expect(memory.acceptsIndicationReply('Explícame asma'), isFalse);
    expect(memory.acceptsIndicationReply('nuevo paciente'), isFalse);
    expect(memory.acceptsIndicationReply('ACV isquémico'), isTrue);
    expect(turn(memory, 'Continúa.').knownFacts.values['indication'], isNull);
  });
  test('restoration uses canonical user turns, never assistant assertions', () {
    final memory = ClinicalSafetyMemory();
    final restored = memory.capture(uid: 'synthetic', sessionId: 'restored',
      priorUserTurns: ['Explícame el uso de medicamento en indicación sintética.', 'Dosis para 90 kg'],
      userQuery: 'Continúa.');
    expect(restored.confirmedFacts.weightKg, 90);
    expect(restored.confirmedFacts.values['medicationContext'], 'medicamento');
    expect(restored.confirmedFacts.values['indication'], contains('sintética'));
    final fresh = memory.capture(uid: 'synthetic', sessionId: 'fresh', newPatient: true,
      priorUserTurns: ['peso 90 kg'], userQuery: 'nuevo paciente');
    expect(fresh.confirmedFacts.values, isEmpty);
  });
  test('conflicting measurements do not become scenario corrections', () {
    final memory = ClinicalSafetyMemory();
    turn(memory, 'peso 90 kg');
    expect(turn(memory, 'peso 80 kg').answerability, Answerability.abstain);
  });
  for (final follow in [
    'Continúa.',
    'continuar',
    'seguí',
    '¿y la dosis?',
    '¿y para 90 kg?',
    'de ella',
    'eso'
  ]) {
    test('referential followup preserves thread: $follow', () {
      final manager = ClinicalThreadManager();
      manager.evaluate(
          currentUserText: 'Explícame el uso de alteplasa en ACV isquémico.',
          isPlantaoMode: false);
      final id = manager.activeThreadId;
      final status =
          manager.evaluate(currentUserText: follow, isPlantaoMode: true);
      expect(status.isContinuation, isTrue);
      expect(manager.activeThreadId, id);
    });
  }
  for (final mode in [true, false]) {
    for (final boundary in ['nuevo paciente', 'nuevo tema: asma']) {
      test('explicit boundary resets regardless of mode: $mode $boundary', () {
        final manager = ClinicalThreadManager();
        manager.evaluate(currentUserText: 'tema clínico sintético', isPlantaoMode: mode);
        final old = manager.activeThreadId;
        final status = manager.evaluate(currentUserText: boundary, isPlantaoMode: mode);
        expect(status.action, ThreadAction.newThread);
        expect(manager.activeThreadId, isNot(old));
      });
    }
  }
  test('new conversation reset clears thread', () {
    final manager = ClinicalThreadManager();
    manager.evaluate(currentUserText: 'asma', isPlantaoMode: true);
    manager.reset();
    expect(manager.hasActiveThread, isFalse);
  });
  test('provider transport contains prior safe response across modes', () {
    final manager = ClinicalThreadManager();
    manager.evaluate(
        currentUserText: 'tema clínico sintético', isPlantaoMode: false);
    final status =
        manager.evaluate(currentUserText: 'Continúa.', isPlantaoMode: true);
    final history = ClinicalThreadManager.buildThreadHistory(fullHistory: [
      {'role': 'user', 'content': 'tema clínico sintético'},
      {'role': 'assistant', 'content': 'Explicación validada.'}
    ], status: status, isPlantaoMode: true);
    expect(history.last['content'], 'Explicación validada.');
  });
  test('empty sections removed without dropping body or parent sections', () {
    final cleaned = ClinicalSections.withoutEmptyHeadings(
        '# Tema\n\n## Vacío\n\n## Padre\n### Subvacío\n### Completo\nTexto válido.\n## Cola');
    expect(cleaned, isNot(contains('Vacío')));
    expect(cleaned, isNot(contains('Subvacío')));
    expect(cleaned, isNot(contains('Cola')));
    expect(cleaned, contains('## Padre'));
    expect(cleaned, contains('Texto válido.'));
  });
  test(
      'existing deterministic arithmetic rejects nonfinite and mismatched weight',
      () {
    expect(ClinicalArithmetic.totalDose(perKg: 2, weightKg: 90), 180);
    expect(
        () =>
            ClinicalArithmetic.totalDose(perKg: double.infinity, weightKg: 90),
        throwsFormatException);
    expect(
        ClinicalArithmetic.validateClinicalEquations('2 mg/kg × 80 kg = 160 mg',
            ClinicalFacts(values: {'weightKg': '90'})),
        false);
  });
}
