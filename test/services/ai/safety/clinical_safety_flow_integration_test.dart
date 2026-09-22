import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/safety/clinical_request_safety.dart';
import 'package:medcases/services/ai/safety/clinical_safety_flow.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_clinical_regimen_contract.dart';
import 'package:medcases/services/ai_stream/gpt_sse_client.dart';
import 'package:medcases/services/ai_gateway_service.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/provider_router_service.dart';

ClinicalRequestContext capture(String query,
    {AiRequestMode mode = AiRequestMode.estudo,
    ClinicalSafetyMemory? memory,
    String uid = 'a',
    String session = 's',
    bool newPatient = false,
    bool Function()? ownsRequest}) {
  final snapshot = (memory ?? ClinicalSafetyMemory()).capture(
      uid: uid, sessionId: session, userQuery: query, newPatient: newPatient);
  return ClinicalRequestContext(
      requestId: 'r',
      sessionId: session,
      uid: uid,
      mode: mode,
      language: 'pt',
      userQuery: query,
      memory: snapshot,
      evidence: ClinicalEvidenceBundle.forRequest(
          query: query, facts: snapshot.confirmedFacts, language: 'pt'),
      createdAt: DateTime(2026, 9, 21),
      ownsRequest: ownsRequest);
}

void main() {
  group('Productive ClinicalSafetyFlow', () {
    for (final text in [
      'A fisiopatologia envolve mecanismos celulares e resposta inflamatória.',
      'O mecanismo de ação depende da ligação ao receptor e da concentração plasmática.',
      'A classificação IV é uma categoria descritiva do sistema discutido.',
      'O diagnóstico diferencial organiza hipóteses; não confirma um diagnóstico individual.',
      'A epidemiologia descreve a distribuição dos eventos na população.',
    ]) {
      test('A/O: Study explanatory content is not falsely blocked: $text', () {
        final flow = ClinicalSafetyFlow(
            capture('Explique o conceito e mecanismo de ação'));
        final terminal = flow.terminal(text);
        expect(terminal.allowed, isTrue);
        expect(terminal.gates[SafetyGate.medicationEvidence],
            SafetyVerdict.notApplicable);
        expect(flow.present(text), text);
        expect(flow.preview('$text\n\nEm desenvolvimento'), text);
      });
    }
    test('B/D: unknown operational medication is blocked in BOTH modes', () {
      for (final mode in AiRequestMode.values) {
        final flow = ClinicalSafetyFlow(
            capture('Qual a dose do medicamento não cadastrado?', mode: mode));
        expect(
            flow
                .terminal('Administrar medicamento desconhecido 5 mg VO')
                .allowed,
            isFalse);
        expect(
            flow.preview('Administrar medicamento desconhecido 5 mg VO.\n\n'),
            isNull);
        expect(flow.present('Administrar medicamento desconhecido 5 mg VO'),
            flow.context.safeMessage);
      }
    });
    test(
        'C: existing productive typed ACS regimen passes with its exact authority',
        () {
      const query =
          'IAM confirmado com angioplastia; idade: 60; peso: 70 kg; alergias: nenhuma';
      final flow =
          ClinicalSafetyFlow(capture(query, mode: AiRequestMode.plantao));
      final existing = PlantaoClinicalRegimenResolver.resolve(
          query: query, patientAge: '60')!;
      final authorizedLine = existing.medications.first.line(isEs: false);
      expect(flow.context.evidence.items, isNotEmpty);
      final result = flow.terminal(authorizedLine);
      expect(result.allowed, isTrue);
      expect(result.gates[SafetyGate.medicationEvidence], SafetyVerdict.pass);
      expect(result.gates[SafetyGate.numericValidation], SafetyVerdict.pass);
      expect(result.claims.single.evidenceVersion,
          PlantaoClinicalRegimenContract.policyVersion);
      expect(result.claims.single.evidenceId,
          startsWith(PlantaoClinicalRegimenContract.sourceId));
    });
    test(
        'medication authority requires adult context and explicit allergy status',
        () {
      for (final query in [
        'IAM confirmado',
        'IAM confirmado; idade: 60',
        'IAM confirmado; idade: 60; alergias: AAS',
        'IAM confirmado; idade: 12; alergias: nenhuma'
      ]) {
        final context = capture(query, mode: AiRequestMode.plantao);
        expect(context.evidence.items, isEmpty, reason: query);
        expect(
            ClinicalSafetyFlow(context)
                .terminal('Administrar medicamento 5 mg')
                .allowed,
            isFalse);
      }
    });
    test('zero concentration and contradictory age cannot generate', () {
      expect(capture('Calcular infusão: 5 mg/0 ml').answerability,
          Answerability.abstain);
      expect(capture('idade: 60; paciente de 40 anos').answerability,
          Answerability.abstain);
    });
    test('U/min cannot escape the academic terminal medication guard', () {
      final flow = ClinicalSafetyFlow(capture('Explique o mecanismo'));
      expect(flow.terminal('Substância desconhecida 1 U/min').allowed, isFalse);
    });
    test('secondary AiService entry point applies answerability before network',
        () async {
      final result = await AiService.chat(
          apiKey: '',
          userMessage: 'Dose pediátrica',
          systemPrompt: '',
          isPlantaoMode: false);
      expect(result.text, contains('peso'));
      expect(result.isError, isFalse);
    });

    test('existing authority cannot approve changed units or numeric dose', () {
      const query =
          'IAM confirmado com angioplastia; idade: 60; alergias: nenhuma';
      final flow =
          ClinicalSafetyFlow(capture(query, mode: AiRequestMode.plantao));
      final line = flow.context.evidence.items.first.claim;
      expect(
          flow.terminal(line.replaceFirst(' mg ', ' mcg ')).allowed, isFalse);
      expect(flow.terminal('$line e repetir a cada hora').allowed, isFalse);
    });
    for (final entry in {
      'Dose pediátrica': 'weightKg',
      'Ajuste de dose renal': 'renalFunction',
      'Cálculo de infusão em mL/h': 'concentration'
    }.entries) {
      test('E/F/G: ${entry.key} blocks before transport', () {
        final context = capture(entry.key, mode: AiRequestMode.plantao);
        expect(context.answerability, Answerability.askForMissingData);
        expect(context.unknownCriticalFacts, contains(entry.value));
        expect(() => context.requireTransport(mode: 'plantao', language: 'pt'),
            throwsStateError);
        expect(
            ClinicalSafetyFlow(context)
                .terminal('Texto')
                .gates[SafetyGate.criticalDataComplete],
            SafetyVerdict.failClosed);
      });
    }
    test(
        'typed equation checks validate dimensions but never grant drug authority',
        () {
      final flow =
          ClinicalSafetyFlow(capture('peso: 10 kg; concentração: 20 mcg/ml'));
      for (final expression in [
        '2 mg/kg × 10 kg = 20 mg',
        '20 mg / 4 tomadas = 5 mg',
        '100 mg / 20 ml = 5 mg/ml',
        '1 mcg/kg/min × 10 kg / 20 mcg/ml = 30 ml/h'
      ]) {
        final result = flow.terminal(expression);
        expect(result.gates[SafetyGate.numericValidation], SafetyVerdict.pass,
            reason: expression);
        expect(result.gates[SafetyGate.medicationEvidence],
            SafetyVerdict.failClosed);
        expect(result.allowed, isFalse);
      }
      for (final expression in [
        '2 mg/kg × 10 kg = 200 mg',
        '2 mg/kg × 20 kg = 40 mg',
        '20 mg / 0 tomadas = 5 mg',
        '1 mcg/kg/min × 10 kg / 20 mcg/ml = 3 ml/h'
      ]) {
        expect(flow.terminal(expression).gates[SafetyGate.numericValidation],
            SafetyVerdict.failClosed,
            reason: expression);
      }
    });

    test('H: mg/mcg incompatible equation fails the terminal numeric gate', () {
      final flow =
          ClinicalSafetyFlow(capture('Explique conversão de unidades'));
      expect(flow.terminal('1 mg = 1 mcg').gates[SafetyGate.numericValidation],
          SafetyVerdict.failClosed);
      expect(flow.terminal('1 mg = 1000 mcg').allowed, isTrue);
    });
    test('L/M: session memory resets without mutating an older snapshot', () {
      final memory = ClinicalSafetyMemory();
      final a = capture('peso: 20 kg', memory: memory);
      final b = capture('Novo caso', memory: memory, newPatient: true);
      expect(b.weightKg, isNull);
      expect(a.weightKg, 20);
      capture('peso: 30 kg', memory: memory);
      expect(capture('Consulta', uid: 'b', memory: memory).weightKg, isNull);
      memory.reset();
      expect(capture('Consulta', uid: 'b', memory: memory).knownFacts.values,
          isEmpty);
    });
    test('N: contradictory or inferred patient facts fail terminal check', () {
      final flow = ClinicalSafetyFlow(capture('peso: 20 kg; achados: febre'));
      for (final text in [
        'peso: 80 kg',
        'sexo: masculino',
        'Sem febre.',
        'Não pesa 20 kg.'
      ]) {
        expect(flow.terminal(text).gates[SafetyGate.contradictionCheck],
            SafetyVerdict.failClosed,
            reason: text);
      }
    });
    test('structured-only prescription cannot bypass text checks', () {
      final flow = ClinicalSafetyFlow(capture('Explique o mecanismo'));
      final result = flow.terminal('Explicação geral.',
          structuredClaims: ['Medicamento inventado 5 mg']);
      expect(result.allowed, isFalse);
    });
    test('unversioned or shadow evidence cannot silently become drug authority',
        () {
      final context = capture('Dose de substância sem contrato');
      expect(context.evidence.items, isEmpty);
      expect(
          ClinicalSafetyFlow(context)
              .terminal('Administrar substância 5 mg')
              .allowed,
          isFalse);
      final adapter = File(
              'lib/services/ai_pipeline/plantao/adapters/plantao_generated_drug_evidence_readonly_adapter.dart')
          .readAsStringSync();
      expect(adapter, contains('productiveConnectionEnabled = false'));
      expect(adapter, contains('medicationMaterializationEnabled = false'));
    });
    test('operational chunk is withheld even after a safe academic paragraph',
        () {
      final flow = ClinicalSafetyFlow(capture('Explique o mecanismo'));
      expect(flow.preview('O receptor participa da resposta.\n\n'), isNotNull);
      expect(
          flow.preview(
              'O receptor participa da resposta.\n\nAdministrar 5 mg.\n\n'),
          isNull);
      expect(
          flow
              .terminal(
                  'O receptor participa da resposta.\n\nAdministrar 5 mg.')
              .allowed,
          isFalse);
    });
    test(
        'new request cannot mutate mode or language of captured transport context',
        () {
      final context = capture('Explique o mecanismo');
      final payload = GptSsePayload(
          userMessage: 'Query',
          systemPrompt: '',
          clinicalContext: context,
          mode: context.mode.name,
          lang: context.language);
      expect(identical(payload.clinicalContext, context), isTrue);
      expect(payload.toJson().containsKey('clinicalContext'), isFalse);
      expect(() => context.requireTransport(mode: 'plantao', language: 'pt'),
          throwsStateError);
    });
  });

  group('Real transport entry points, blocked before network', () {
    test(
        'I/J/K: retries, paid fallbacks and repair recheck same owner snapshot',
        () async {
      var checks = 0;
      final context = capture('Explique o mecanismo', ownsRequest: () {
        checks++;
        return false;
      });
      for (var attempt = 0; attempt < 2; attempt++) {
        expect(
            () => AiGatewayService.sendStream(
                clinicalContext: context,
                userMessage: 'Query',
                systemPrompt: '',
                apiKey: '',
                longResponse: true),
            throwsStateError);
      }
      await expectLater(
          ProviderRouterService.callGptProxy(
              clinicalContext: context,
              userMessage: 'Query',
              systemPrompt: '',
              mode: 'estudo'),
          throwsStateError);
      await expectLater(
          ProviderRouterService.callPaidProxy(
              clinicalContext: context,
              userMessage: 'Query',
              systemPrompt: '',
              mode: 'estudo'),
          throwsStateError);
      await expectLater(
          ProviderRouterService.callGptProxyStream(
                  clinicalContext: context,
                  userMessage: 'Query',
                  systemPrompt: '',
                  mode: 'estudo')
              .toList(),
          throwsStateError);
      await expectLater(
          AiService.repairTruncated(
              clinicalContext: context,
              originalText: 'Texto',
              requestId: 'r',
              isPlantaoMode: false),
          throwsStateError);
      expect(checks, 6);
    });
  });

  test(
      'production wiring covers every route and both UI/persistence boundaries',
      () {
    final provider = File('lib/providers/app_provider.dart').readAsStringSync();
    final start = provider.indexOf('Future<bool> _sendAiMessageLegacyCore(');
    final core = provider.substring(
        start, provider.indexOf('Future<String> buildAIAnswer(', start));
    for (final name in [
      'ProviderRouterService.callPaidProxy',
      'ProviderRouterService.callGptProxy',
      'ProviderRouterService.callGptProxyStream',
      'AiGatewayService.sendStream',
      'AiService.repairTruncated'
    ]) {
      final calls = RegExp(
              RegExp.escape(name) + r'\(\s*clinicalContext:\s*safetyContext,')
          .allMatches(core);
      final actual = RegExp(RegExp.escape(name) + r'\(').allMatches(core).where(
          (m) => !core
              .substring(core.lastIndexOf('\n', m.start) + 1, m.start)
              .trimLeft()
              .startsWith('//'));
      expect(calls.length, actual.length, reason: name);
      expect(calls, isNotEmpty);
    }
    final repairStart =
        provider.indexOf('Future<String> _enforcePlantaoQuestionsExactTen(');
    final repair = provider.substring(
        repairStart,
        provider.indexOf(
            'String _applyPlantaoClinicalRegimenOutputGuard(', repairStart));
    expect(repair, contains('clinicalContext: clinicalContext'));
    expect(repair, contains('clinicalContext.ownsRequest?.call() == false'));
    expect(repair.indexOf('clinicalContext.ownsRequest?.call()'),
        lessThan(repair.indexOf('await ProviderRouterService.callGptProxy')));
    expect(core, contains('clinicalContext: snapshot'));
    expect(core, contains('ClinicalSafetyFlow(snapshot).preview(accumulated)'));
    expect(core, contains('ClinicalSafetyFlow(snapshot).terminal(guardedText'));
    expect(provider,
        contains("SessionPersistSkipped('clinical_safety_rejected')"));
    expect(provider,
        contains("SessionPersistSkipped('clinical_safety_post_transform')"));
    final ui = File('lib/screens/ai_screen.dart').readAsStringSync();
    expect(ui, contains('safeFinalText = p.guardAiClinicalPresentation('));
    final memory =
        File('lib/services/clinical_session_memory.dart').readAsStringSync();
    expect(memory, contains('safety.reset();'));
  });
}
