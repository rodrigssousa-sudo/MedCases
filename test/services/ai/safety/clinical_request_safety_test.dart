import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/safety/clinical_request_safety.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/plantao_global_clinical_response_gate.dart';

ClinicalRequestContext request({
  String query = 'Consulta educacional',
  AiRequestMode mode = AiRequestMode.estudo,
  ClinicalEvidenceBundle? evidence,
  ClinicalSafetyMemory? memory,
  String uid = 'owner-a',
  String sessionId = 'session-a',
  bool newPatient = false,
}) =>
    ClinicalRequestContext(
      requestId: 'request-a',
      sessionId: sessionId,
      uid: uid,
      mode: mode,
      language: 'pt',
      userQuery: query,
      memory: (memory ?? ClinicalSafetyMemory()).capture(
        uid: uid,
        sessionId: sessionId,
        userQuery: query,
        newPatient: newPatient,
      ),
      evidence: evidence ?? ClinicalEvidenceBundle(),
      createdAt: DateTime(2026, 9, 21),
    );

void main() {
  group('Snapshot and memory (isolated module)', () {
    test('facts cannot be mutated through the input map or snapshot', () {
      final map = {'weightKg': '20'};
      final facts = ClinicalFacts(values: map);
      map['weightKg'] = '80';
      expect(facts.weightKg, 20);
      expect(() => facts.values['weightKg'] = '90', throwsUnsupportedError);
    });
    test('evidence collection is copied and immutable', () {
      final items = <ClinicalEvidenceItem>[];
      final bundle = ClinicalEvidenceBundle(items: items);
      items.add(const ClinicalEvidenceItem(
          id: 'id', version: 'v1', claim: 'claim', reviewDate: null));
      expect(bundle.items, isEmpty);
      expect(() => bundle.items.clear(), throwsUnsupportedError);
    });
    test('all patient fields remain unknown when not supplied', () {
      final r = request();
      expect([
        r.patientAge,
        r.sex,
        r.weightKg,
        r.renalFunction,
        r.pregnancy,
        r.allergies,
        r.currentMedications
      ], everyElement(isNull));
      expect(r.answerability, Answerability.answerWithLimitations);
    });
    test('facts come only from explicit supplied fields', () {
      final r = request(
          query:
              'idade: 40; peso: 70,5 kg; sexo: feminino; eGFR: 75 ml/min; pregnant: false; alergias: substância X; medicamentos atuais: medicamento Y; fc: 80; lactato: 2');
      expect(r.patientAge, 40);
      expect(r.weightKg, 70.5);
      expect(r.sex, 'female');
      expect(r.renalFunction, 75);
      expect(r.pregnancy, isFalse);
      expect(r.allergies, 'substância x');
      expect(r.memory.relevantVitals['fc'], '80.0');
      expect(r.memory.relevantLabs['lactato'], '2.0');
    });
    test('new patient clears memory without mutating prior request', () {
      final memory = ClinicalSafetyMemory();
      final a = request(memory: memory, query: 'peso: 20 kg');
      final b = request(memory: memory, newPatient: true);
      expect(b.weightKg, isNull);
      expect(a.weightKg, 20);
    });
    test('user switch clears memory', () {
      final memory = ClinicalSafetyMemory();
      request(memory: memory, query: 'peso: 20 kg');
      final b = request(memory: memory, uid: 'owner-b');
      expect(b.knownFacts.values, isEmpty);
    });
    test('session switch clears memory', () {
      final memory = ClinicalSafetyMemory();
      request(memory: memory, query: 'peso: 20 kg');
      expect(request(memory: memory, sessionId: 'session-b').weightKg, isNull);
    });
    test('reset clears session memory', () {
      final memory = ClinicalSafetyMemory();
      request(memory: memory, query: 'peso: 20 kg');
      memory.reset();
      expect(request(memory: memory).weightKg, isNull);
    });
    test('conflicting facts become unresolved, never silently overwritten', () {
      final memory = ClinicalSafetyMemory();
      request(memory: memory, query: 'peso: 20 kg');
      final b = request(memory: memory, query: 'peso: 50 kg');
      expect(b.weightKg, isNull);
      expect(b.memory.unresolvedQuestions, contains('weightKg'));
      expect(b.answerability, Answerability.abstain);
    });
  });

  group('Answerability', () {
    test('missing pediatric weight blocks generation', () {
      final r = request(query: 'Dose pediátrica');
      expect(r.answerability, Answerability.askForMissingData);
      expect(r.unknownCriticalFacts, contains('weightKg'));
      expect(r.mayGenerate, isFalse);
    });
    test('missing renal function blocks renal dose adjustment', () {
      final r = request(query: 'Ajuste de dose renal');
      expect(r.answerability, Answerability.askForMissingData);
      expect(r.unknownCriticalFacts, contains('renalFunction'));
    });
    test('missing concentration blocks infusion', () {
      final r = request(query: 'Cálculo de infusão em mL/h');
      expect(r.unknownCriticalFacts, contains('concentration'));
      expect(r.mayGenerate, isFalse);
    });
    test('supplied weight removes missing-data gate but is not dose authority',
        () {
      final r = request(query: 'Dose pediátrica; peso: 20 kg');
      expect(r.unknownCriticalFacts, isEmpty);
      expect(r.answerability, Answerability.answerWithLimitations);
      final result = ClinicalSafetyPass.evaluate(
          context: r,
          output: 'Administrar medicamento X 5 mg',
          outputMode: r.mode);
      expect(result.gates[SafetyGate.medicationEvidence],
          SafetyVerdict.failClosed);
    });
  });

  group('Dimensional arithmetic, no clinical recommendations', () {
    test('mg to mcg and back', () {
      expect(
          ClinicalArithmetic.convertMass(2.5, MassUnit.mg, MassUnit.mcg), 2500);
      expect(
          ClinicalArithmetic.convertMass(2500, MassUnit.mcg, MassUnit.mg), 2.5);
      expect(ClinicalArithmetic.convertMass(1, MassUnit.g, MassUnit.mg), 1000);
    });
    test('weight-based total and dose per administration', () {
      expect(ClinicalArithmetic.totalDose(perKg: 2, weightKg: 10), 20);
      expect(
          ClinicalArithmetic.perAdministration(total: 20, administrations: 4),
          5);
    });
    test('infusion uses concentration and minute-hour conversion', () {
      expect(
          ClinicalArithmetic.infusionMlHour(
              mcgKgMinute: 1, weightKg: 10, mcgMl: 20),
          30);
      expect(ClinicalArithmetic.concentration(mass: 100, volumeMl: 20), 5);
    });
    test('zero, negatives, nonfinite and overflow are rejected', () {
      for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
        expect(() => ClinicalArithmetic.totalDose(perKg: 1, weightKg: invalid),
            throwsFormatException);
        expect(
            () => ClinicalArithmetic.concentration(mass: 1, volumeMl: invalid),
            throwsFormatException);
      }
      expect(() => ClinicalArithmetic.totalDose(perKg: 1e308, weightKg: 1e308),
          throwsFormatException);
    });
    test('decimals do not interpret ambiguous separators', () {
      expect(ClinicalArithmetic.decimal('0,5'), 0.5);
      expect(ClinicalArithmetic.decimal('0.5'), 0.5);
      for (final value in ['1,000.2', 'NaN', 'Infinity', '1e3', '-2', '0']) {
        expect(() => ClinicalArithmetic.decimal(value), throwsFormatException);
      }
    });
  });

  group('Evidence and final pass (not yet connected to productive finalizer)',
      () {
    test('unsupported critical claim fails closed with explicit uncertainty',
        () {
      final r = request();
      final result = ClinicalSafetyPass.evaluate(
          context: r, output: 'Realizar ação X', outputMode: r.mode);
      expect(result.allowed, isFalse);
      expect(
          result.claims.single.certainty, ClinicalCertainty.insufficientData);
      expect(result.claims.single.evidenceId, isNull);
      expect(result.gates[SafetyGate.unsupportedCriticalClaims],
          SafetyVerdict.failClosed);
    });
    test(
        'exact supported claim retains source ID, version, fidelity and freshness',
        () {
      final r = request(
          evidence: ClinicalEvidenceBundle(items: [
        ClinicalEvidenceItem(
            id: 'source-a',
            version: 'version-a',
            claim: 'Realizar ação X',
            reviewDate: DateTime(2026))
      ]));
      final result = ClinicalSafetyPass.evaluate(
          context: r, output: 'Realizar ação X', outputMode: r.mode);
      expect(result.allowed, isTrue);
      expect(result.claims.single.evidenceId, 'source-a');
      expect(result.claims.single.evidenceVersion, 'version-a');
      expect(result.claims.single.fidelity, EvidenceFidelity.exact);
      expect(
          result.claims.single.freshness, EvidenceFreshness.reviewDateProvided);
    });
    test('prose protocol is not authorized structured medication evidence', () {
      final r = request(
          evidence: ClinicalEvidenceBundle.fromMachinePack(
              const PlantaoGlobalClinicalContextPack(
                  authoritative: true,
                  pathologyKey: 'a',
                  protocolKey: 'b',
                  guidelineVersion: 'v1',
                  clinicalReviewDate: '2026-01-01',
                  requiredActions: ['Administrar medicamento X 5 mg'])));
      final result = ClinicalSafetyPass.evaluate(
          context: r,
          output: 'Administrar medicamento X 5 mg',
          outputMode: r.mode);
      expect(result.gates[SafetyGate.medicationEvidence],
          SafetyVerdict.failClosed);
    });
    test(
        'conditional and prohibited instructions are not evidence of a positive action',
        () {
      final bundle = ClinicalEvidenceBundle.fromMachinePack(
          const PlantaoGlobalClinicalContextPack(
              authoritative: true,
              pathologyKey: 'a',
              protocolKey: 'b',
              guidelineVersion: 'v1',
              conditionalActions: ['Realizar ação X se Y'],
              prohibitedActions: ['Realizar ação Z']));
      expect(bundle.items, isEmpty);
    });
    test('absent or future review date cannot verify critical claim', () {
      for (final date in [null, DateTime(2030)]) {
        final r = request(
            evidence: ClinicalEvidenceBundle(items: [
          ClinicalEvidenceItem(
              id: 'a',
              version: 'v1',
              claim: 'Realizar ação X',
              reviewDate: date)
        ]));
        expect(
            ClinicalSafetyPass.evaluate(
                    context: r, output: 'Realizar ação X', outputMode: r.mode)
                .allowed,
            isFalse);
      }
    });
    test('conflicting weight or invented patient fact fails closed', () {
      final r = request(query: 'peso: 20 kg');
      for (final output in ['peso: 30 kg', 'sexo: masculino']) {
        final result = ClinicalSafetyPass.evaluate(
            context: r, output: output, outputMode: r.mode);
        expect(result.gates[SafetyGate.contradictionCheck],
            SafetyVerdict.failClosed);
        expect(result.contradictions, greaterThan(0));
      }
    });
    test('unsupported numerical prescription cannot be silently approved', () {
      final r = request();
      final result = ClinicalSafetyPass.evaluate(
          context: r, output: 'Administrar 4 mg/kg/min', outputMode: r.mode);
      expect(result.numericChecks, 1);
      expect(
          result.gates[SafetyGate.numericValidation], SafetyVerdict.failClosed);
    });
    for (final mode in AiRequestMode.values) {
      test('$mode snapshot preserves mode and rejects opposite terminal', () {
        final r = request(mode: mode);
        expect(() => r.requireTransport(mode: mode.name, language: 'pt'),
            returnsNormally);
        final opposite = mode == AiRequestMode.estudo
            ? AiRequestMode.plantao
            : AiRequestMode.estudo;
        expect(() => r.requireTransport(mode: opposite.name, language: 'pt'),
            throwsStateError);
        final result = ClinicalSafetyPass.evaluate(
            context: r, output: 'Texto', outputMode: opposite);
        expect(result.gates[SafetyGate.modeMatch], SafetyVerdict.failClosed);
      });
    }
    test(
        'telemetry contains counts and mode, not patient text or raw identifiers',
        () {
      final r = request(query: 'peso: 20 kg; alergias: SEGREDO');
      final log = ClinicalSafetyPass.evaluate(
              context: r, output: 'Texto', outputMode: r.mode)
          .telemetry(r);
      expect(log, contains('[AI_SAFETY]'));
      for (final value in [
        'SEGREDO',
        'peso:',
        'request-a',
        'owner-a',
        'session-a'
      ]) {
        expect(log, isNot(contains(value)));
      }
    });
  });
}
