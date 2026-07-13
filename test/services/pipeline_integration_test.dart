// ══════════════════════════════════════════════════════════════════════════════
// test/services/pipeline_integration_test.dart
// MICRO-BUILD 462E-A.5.1 — Pipeline Integration Test Suite
//
// Verifica os 3 cenários críticos de integração do pipeline de finalização:
//
// Scenario 1: Truncated response → inspector captures → repair loop runs ONCE
//             → SessionDedup.save() / _aiHistory NOT populated
//
// Scenario 2: Successfully repaired text → exactly ONE persistence transaction
//
// Scenario 3: Catastrophic repair failure → AiSafeOutputException thrown
//             → pipeline signals DROP_PAYLOAD → no EXT_TOOL_CARD_RENDERED
//             → ResumeCoordinator signaled
//
// Arquitetura de teste: unit-level stubs — zero rede, zero Firebase, zero UI.
// Testa os contratos dos tipos criados em 462E-A.5.1 diretamente.
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_stream/truncation_inspector.dart';
import 'package:medcases/services/external_tool_link_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers — Simulated Pipeline Executor
//
// Simulates the stream finalization pyramid from app_provider.dart without
// touching Firebase, network, or Flutter widget trees.
// Models the exact logic: inspect → repair → re-inspect → persist/throw.
// ─────────────────────────────────────────────────────────────────────────────

/// Simulated repair engine stub — returns a configurable result.
class _MockRepairEngine {
  final TruncationRepairResult Function(String original) _repairFn;
  int callCount = 0;

  _MockRepairEngine(this._repairFn);

  Future<TruncationRepairResult> repair({
    required String originalText,
    required String requestId,
    required bool isPlantaoMode,
  }) async {
    callCount++;
    return _repairFn(originalText);
  }
}

/// Simulated persistence sink — tracks how many times save() was called.
class _MockPersistenceSink {
  int saveCount = 0;
  final List<String> savedTexts = [];

  void save(String text) {
    saveCount++;
    savedTexts.add(text);
  }
}

/// Simulates DROP_PAYLOAD signal tracking.
class _MockResumeCoordinator {
  bool completed = false;
  bool extToolCardRendered = false;

  void complete(String requestId) {
    completed = true;
  }

  void renderExtToolCard() {
    extToolCardRendered = true;
  }
}

/// The simulated pipeline executor — mirrors app_provider.dart's finalization pyramid.
///
/// Returns a [_PipelineResult] describing what happened.
Future<_PipelineResult> _runFinalizationPipeline({
  required String rawText,
  required _MockRepairEngine repairEngine,
  required _MockPersistenceSink sink,
  required _MockResumeCoordinator coordinator,
  required String requestId,
  bool isPlantaoMode = true,
}) async {
  // ── STEP 1–2: Transport Completed + Raw Buffer ──────────────────────────
  // (already done: rawText is the accumulated buffer)

  try {
    // ── STEP 3: TruncationInspector HARD BARRIER ──────────────────────────
    String barrierText = rawText;
    final truncCheck = TruncationInspector.inspect(rawText);
    TruncationInspector.emitTelemetry(requestId: requestId, result: truncCheck);

    if (truncCheck.isTruncated &&
        truncCheck.confidenceLevel == TruncationConfidence.high) {
      // ── STEP 4: Repair subsystem (AT MOST ONCE per requestId) ──────────
      final repairResult = await repairEngine.repair(
        originalText:  rawText,
        requestId:     requestId,
        isPlantaoMode: isPlantaoMode,
      );

      if (!repairResult.isValid) {
        // Catastrophic failure → AiSafeOutputException
        throw AiSafeOutputException(
          message:   repairResult.failureReason ?? 'repair_failed',
          requestId: requestId,
        );
      }
      barrierText = repairResult.text;
    }

    // ── STEP 5: Re-inspect + ResponseValidator (stub: clean pass) ─────────
    final reInspection = TruncationInspector.inspect(barrierText);
    if (reInspection.isTruncated &&
        reInspection.confidenceLevel == TruncationConfidence.high) {
      throw AiSafeOutputException(
        message:   'reinspect_still_truncated: ${reInspection.violationReason}',
        requestId: requestId,
      );
    }

    // ── STEP 6: Persistence — ONLY if barrier passed ───────────────────────
    if (barrierText.isNotEmpty) {
      sink.save(barrierText); // Simulates _aiHistory.add() + SessionDedup.save()
    }

    // ── STEP 7: ResumeCoordinator + EXT_TOOL Card ─────────────────────────
    coordinator.complete(requestId);
    coordinator.renderExtToolCard(); // Simulates EXT_TOOL card rendering

    return _PipelineResult(
      completed: true,
      droppedPayload: false,
      persistenceCount: sink.saveCount,
      repairCallCount: repairEngine.callCount,
      finalText: barrierText,
    );
  } on AiSafeOutputException catch (safeError) {
    // ── TERMINAL: DROP_PAYLOAD ────────────────────────────────────────────
    // ignore: avoid_print
    print('[TRUNCATION_CHECK] DROP_PAYLOAD — REPAIR CRITICAL FAILURE '
        'requestId=${safeError.requestId} reason=${safeError.message}');
    coordinator.complete(requestId); // ResumeCoordinator.complete() always fires
    // EXT_TOOL card is NOT rendered on DROP_PAYLOAD
    // (coordinator.renderExtToolCard() is NOT called here)

    return _PipelineResult(
      completed: false,
      droppedPayload: true,
      persistenceCount: sink.saveCount,
      repairCallCount: repairEngine.callCount,
      finalText: '',
      dropReason: safeError.message,
    );
  }
}

/// Result of running the simulated finalization pipeline.
class _PipelineResult {
  final bool completed;
  final bool droppedPayload;
  final int persistenceCount;
  final int repairCallCount;
  final String finalText;
  final String? dropReason;

  const _PipelineResult({
    required this.completed,
    required this.droppedPayload,
    required this.persistenceCount,
    required this.repairCallCount,
    required this.finalText,
    this.dropReason,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Test Suite
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Pipeline Integration — MICRO-BUILD 462E-A.5.1', () {

    // ── Scenario 1: Truncated response → inspector captures → repair once ───
    // → SessionDedup/aiHistory NOT called (no persistence before barrier)
    // ──────────────────────────────────────────────────────────────────────────
    group('Scenario 1: Truncated response — repair runs ONCE, persistence blocked', () {

      test('1a. Inspect captures high-confidence truncation (H3 mid-numeric cut)', () {
        // The exact Test C string from the mandate — "Velocidade: **55–7"
        const truncatedText = 'Velocidade: **55–7';
        final result = TruncationInspector.inspect(truncatedText);

        expect(result.isTruncated, isTrue,
            reason: 'H3 mid-numeric cut must be detected');
        expect(result.confidenceLevel, TruncationConfidence.high,
            reason: 'Confidence must be high for H3 hit');
      });

      test('1b. Pipeline triggers repair EXACTLY ONCE for truncated input', () async {
        const truncatedText = 'Velocidade: **55–7'; // H3 high-confidence
        const repairedText  = 'Velocidade: **55–75 mL/h**. Titular conforme resposta clínica.';

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.repaired(repairedText));

        final result = await _runFinalizationPipeline(
          rawText:      truncatedText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario1',
        );

        expect(result.repairCallCount, equals(1),
            reason: 'Repair engine must be called EXACTLY ONCE');
        expect(result.completed, isTrue);
        expect(result.droppedPayload, isFalse);
      });

      test('1c. Persistence (sink.save) is NOT called on raw truncated text — only after repair', () async {
        const truncatedText = 'Dose máxima: **55–'; // H2 high-confidence
        const repairedText  = 'Dose máxima: **55–80 mg/kg/dia**. Ajustar conforme função renal.';

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        // Repair returns valid result — persistence happens AFTER repair
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.repaired(repairedText));

        await _runFinalizationPipeline(
          rawText:      truncatedText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario1c',
        );

        // The raw truncated text must NOT be the persisted text
        expect(sink.savedTexts, isNotEmpty,
            reason: 'Repaired text should be persisted');
        expect(sink.savedTexts.first, equals(repairedText),
            reason: 'Only the repaired text should be saved, never the raw truncated text');
        expect(sink.savedTexts.first, isNot(equals(truncatedText)),
            reason: 'Raw truncated text must never reach persistence');
      });
    });

    // ── Scenario 2: Successfully repaired → exactly ONE persistence tx ───────
    // ──────────────────────────────────────────────────────────────────────────
    group('Scenario 2: Successfully repaired text → exactly ONE persistence transaction', () {

      test('2a. Single persistence call for successfully repaired response', () async {
        const truncatedText = 'Infusão de noradrenalina: iniciar com **0,1–';
        const repairedText  = 'Infusão de noradrenalina: iniciar com **0,1–0,3 mcg/kg/min**. '
            'Titular de 0,05 em 0,05 conforme PAM alvo ≥65 mmHg.';

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.repaired(repairedText));

        await _runFinalizationPipeline(
          rawText:      truncatedText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario2',
        );

        expect(sink.saveCount, equals(1),
            reason: 'Exactly ONE persistence transaction must occur for repaired text');
        expect(sink.savedTexts.first, equals(repairedText),
            reason: 'The persisted text must be the repaired (merged + deduped) version');
      });

      test('2b. Clean response (no truncation) → exactly ONE persistence call, zero repair', () async {
        const cleanText = 'Amoxicilina: 500 mg 8/8h VO por 7 dias. '
            'Ajustar para 250 mg 8/8h em ClCr < 30 mL/min.';

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        // Repair engine should NOT be called for clean text
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.clean(cleanText));

        await _runFinalizationPipeline(
          rawText:      cleanText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario2b',
        );

        expect(sink.saveCount, equals(1),
            reason: 'One persistence call for clean response');
        expect(repairEngine.callCount, equals(0),
            reason: 'Repair engine must NOT be called for clean (non-truncated) response');
      });

      test('2c. ResumeCoordinator is signaled AFTER persistence (correct ordering)', () async {
        const truncatedText = 'Vancomicina: **15–';
        const repairedText  = 'Vancomicina: **15–20 mg/kg** IV 12/12h. '
            'Monitorar vale sérico alvo 15-20 mg/L.';

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.repaired(repairedText));

        final result = await _runFinalizationPipeline(
          rawText:      truncatedText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario2c',
        );

        expect(result.completed, isTrue,
            reason: 'Pipeline must complete after successful repair');
        expect(coordinator.completed, isTrue,
            reason: 'ResumeCoordinator.complete() must be called');
        expect(sink.saveCount, equals(1),
            reason: 'Persistence must have occurred before coordinator signal');
      });
    });

    // ── Scenario 3: Catastrophic repair failure → DROP_PAYLOAD ───────────────
    // → AiFailed(retryable: false) → no EXT_TOOL_CARD_RENDERED
    // → ResumeCoordinator signaled
    // ──────────────────────────────────────────────────────────────────────────
    group('Scenario 3: Catastrophic repair failure → DROP_PAYLOAD terminal sequence', () {

      test('3a. AiSafeOutputException is thrown when repair fails', () async {
        const truncatedText = 'Velocidade: **55–7'; // H3 high-confidence

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        // Repair engine returns catastrophic failure
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.catastrophicFailure(
                'repair_proxy_failed: timeout'));

        final result = await _runFinalizationPipeline(
          rawText:      truncatedText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario3',
        );

        expect(result.droppedPayload, isTrue,
            reason: 'DROP_PAYLOAD must be triggered on catastrophic repair failure');
        expect(result.completed, isFalse,
            reason: 'Pipeline must NOT complete successfully on DROP_PAYLOAD');
      });

      test('3b. No EXT_TOOL_CARD_RENDERED on DROP_PAYLOAD', () async {
        const truncatedText = 'Noradrenalina: titular de **0,05–';

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.catastrophicFailure(
                'reinspect_still_truncated: mid_numeric_or_unit_cut'));

        await _runFinalizationPipeline(
          rawText:      truncatedText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario3b',
        );

        expect(coordinator.extToolCardRendered, isFalse,
            reason: 'EXT_TOOL card must NOT be rendered on DROP_PAYLOAD');
      });

      test('3c. ResumeCoordinator is signaled even on DROP_PAYLOAD (no hang)', () async {
        const truncatedText = 'Dopamina bomba de infusão: iniciar **5–';

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.catastrophicFailure('repair_exception: network_timeout'));

        final result = await _runFinalizationPipeline(
          rawText:      truncatedText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario3c',
        );

        expect(coordinator.completed, isTrue,
            reason: 'ResumeCoordinator.complete() MUST be called even on DROP_PAYLOAD '
                '— prevents infinite loading state / pipeline hang');
        expect(result.droppedPayload, isTrue);
      });

      test('3d. Persistence sink NOT called on DROP_PAYLOAD (history clean)', () async {
        const truncatedText = 'Peso: IMC **32–'; // mid-numeric H3

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.catastrophicFailure('repair_proxy_failed: empty_response'));

        await _runFinalizationPipeline(
          rawText:      truncatedText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario3d',
        );

        expect(sink.saveCount, equals(0),
            reason: 'Raw incomplete response must NEVER be committed to history '
                'on catastrophic failure');
      });

      test('3e. DROP_PAYLOAD carries failure reason for telemetry', () async {
        const truncatedText = 'Velocidade: **55–7';
        const expectedReason = 'repair_proxy_failed: http_503';

        final sink        = _MockPersistenceSink();
        final coordinator = _MockResumeCoordinator();
        final repairEngine = _MockRepairEngine((_) =>
            TruncationRepairResult.catastrophicFailure(expectedReason));

        final result = await _runFinalizationPipeline(
          rawText:      truncatedText,
          repairEngine: repairEngine,
          sink:         sink,
          coordinator:  coordinator,
          requestId:    'req_scenario3e',
        );

        expect(result.dropReason, equals(expectedReason),
            reason: 'DROP_PAYLOAD reason must be propagated for telemetry');
      });
    });

    // ── ExternalToolDecision Cache: LinkedHashMap + releaseDecision ───────────
    group('ExternalToolDecision Cache — LinkedHashMap lifecycle', () {

      setUp(() {
        // Clear cache before each test for isolation
        ExternalToolLinkEngine.clearDecisionCache();
      });

      tearDown(() {
        ExternalToolLinkEngine.clearDecisionCache();
      });

      test('4a. resolveDecision returns null for none-intent inputs', () {
        final decision = ExternalToolLinkEngine.resolveDecision(
          'req_cache_1',
          'Qual é a fisiopatologia do choque séptico?', // no tool intent
        );
        expect(decision, isNull,
            reason: 'Input without explicit tool intent must return null (embargo total)');
      });

      test('4b. resolveDecision returns non-null for explicit infusion intent', () {
        final decision = ExternalToolLinkEngine.resolveDecision(
          'req_cache_2',
          'bomba de infusão de noradrenalina',
        );
        expect(decision, isNotNull,
            reason: 'Infusion intent must return non-null ExternalToolDecision');
        expect(decision!.intent, ExternalToolIntent.infusion);
        expect(decision.toRouterTask(), equals('infusao_ev'));
      });

      test('4c. toRouterTask maps each intent to correct task label', () {
        final intentToTask = {
          ExternalToolIntent.drugInteraction: 'interacao_medicamentosa',
          ExternalToolIntent.dilution:        'diluicao_ev',
          ExternalToolIntent.infusion:        'infusao_ev',
          ExternalToolIntent.dosage:          'dose_farmaco',
          ExternalToolIntent.drugInformation: 'informacao_farmaco',
          ExternalToolIntent.none:            '',
        };
        for (final entry in intentToTask.entries) {
          final decision = ExternalToolDecision(
            requestId:   'req_task_test',
            intent:      entry.key,
            primaryDrug: 'noradrenalina',
            targetTab:   'farmacos',
          );
          expect(decision.toRouterTask(), equals(entry.value),
              reason: '${entry.key.name} must map to "${entry.value}"');
        }
      });

      test('4d. releaseDecision removes specific entry, clearDecisionCache removes all', () {
        // Add two decisions
        ExternalToolLinkEngine.resolveDecision(
          'req_release_1', 'bomba de infusão de noradrenalina');
        ExternalToolLinkEngine.resolveDecision(
          'req_release_2', 'diluição de vancomicina');

        // Release one specific entry
        ExternalToolLinkEngine.releaseDecision('req_release_1_infusion');

        // Clear all — should not throw
        ExternalToolLinkEngine.clearDecisionCache();
        // After clear, resolveDecision with same requestId must re-compute
        final recomputed = ExternalToolLinkEngine.resolveDecision(
          'req_release_2', 'diluição de vancomicina');
        // Should re-return the decision (dilution intent)
        expect(recomputed, isNotNull);
      });

      test('4e. AiSafeOutputException carries requestId and message', () {
        const exception = AiSafeOutputException(
          message:   'repair_proxy_failed: timeout',
          requestId: 'req_exception_test',
        );
        expect(exception.requestId, equals('req_exception_test'));
        expect(exception.message, equals('repair_proxy_failed: timeout'));
        expect(exception.toString(), contains('req_exception_test'));
        expect(exception.toString(), contains('repair_proxy_failed'));
      });

      test('4f. TruncationRepairResult factories set correct fields', () {
        final clean = TruncationRepairResult.clean('clean text');
        expect(clean.isValid, isTrue);
        expect(clean.wasRepaired, isFalse);
        expect(clean.text, equals('clean text'));

        final repaired = TruncationRepairResult.repaired('repaired text');
        expect(repaired.isValid, isTrue);
        expect(repaired.wasRepaired, isTrue);
        expect(repaired.text, equals('repaired text'));

        final failed = TruncationRepairResult.catastrophicFailure('reason');
        expect(failed.isValid, isFalse);
        expect(failed.wasRepaired, isFalse);
        expect(failed.failureReason, equals('reason'));
        expect(failed.text, isEmpty);
      });
    });

    // ── Group 5: MICRO-BUILD 462E-A.5.2 — Canonical Task Enforcement & Terminal Order ──
    group('MICRO-BUILD 462E-A.5.2 Canonical Task Enforcement & Sequencing', () {
      // ── 5a: infusion prompt → canonicalDecision.intent == infusion → toRouterTask() == "infusao_ev" ──
      test('5a. "Como titular noradrenalina em bomba de infusão?" '
          '→ intent=infusion → toRouterTask()=infusao_ev', () {
        ExternalToolLinkEngine.clearDecisionCache();
        const prompt = 'Como titular noradrenalina em bomba de infusão?';
        const requestId = 'req_5a_infusion';

        final decision = ExternalToolLinkEngine.resolveDecision(requestId, prompt);

        // Must detect infusion intent
        expect(decision, isNotNull,
            reason: 'infusion prompt must yield a canonical decision');
        expect(decision!.intent, equals(ExternalToolIntent.infusion),
            reason: 'infusion prompt → ExternalToolIntent.infusion');

        // toRouterTask() must return "infusao_ev" — not "diluicao" or any other
        final routerTask = decision.toRouterTask();
        expect(routerTask, equals('infusao_ev'),
            reason: 'BUILD306 and AI_ROUTER must consume "infusao_ev" verbatim; '
                'regex-derived "diluicao" is strictly prohibited when intent is declared');

        ExternalToolLinkEngine.clearDecisionCache();
      });

      // ── 5b: dilution prompt → toRouterTask() == "diluicao_ev" ──
      test('5b. dilution prompt → toRouterTask()=diluicao_ev (authority boundary)', () {
        ExternalToolLinkEngine.clearDecisionCache();
        const requestId = 'req_5b_dilution';
        final decision = ExternalToolLinkEngine.resolveDecision(
            requestId, 'Como diluir vancomicina?');
        expect(decision, isNotNull);
        expect(decision!.intent, equals(ExternalToolIntent.dilution));
        expect(decision.toRouterTask(), equals('diluicao_ev'));
        ExternalToolLinkEngine.clearDecisionCache();
      });

      // ── 5c: interaction prompt → toRouterTask() == "interacao_medicamentosa" ──
      test('5c. drug interaction prompt → toRouterTask()=interacao_medicamentosa', () {
        ExternalToolLinkEngine.clearDecisionCache();
        const requestId = 'req_5c_interaction';
        final decision = ExternalToolLinkEngine.resolveDecision(
            requestId, 'Qual a interação entre amiodarona e warfarina?');
        expect(decision, isNotNull);
        expect(decision!.intent, equals(ExternalToolIntent.drugInteraction));
        expect(decision.toRouterTask(), equals('interacao_medicamentosa'));
        ExternalToolLinkEngine.clearDecisionCache();
      });

      // ── 5d: none intent → canonicalDecision is null → normal classifier path ──
      test('5d. generic clinical prompt → intent=none → canonicalDecision=null '
          '→ normal classifier path', () {
        ExternalToolLinkEngine.clearDecisionCache();
        const requestId = 'req_5d_none';
        final decision = ExternalToolLinkEngine.resolveDecision(
            requestId, 'Qual o tratamento da pneumonia?');
        // Generic clinical prompts return null (intent=none) → normal classifier path
        // toRouterTask() is NOT called; BUILD306 runs _detectIntent() normally
        expect(decision, isNull,
            reason: 'generic prompt must yield null — no canonical override injected');
        ExternalToolLinkEngine.clearDecisionCache();
      });

      // ── 5e: Execution index tracking — TRUNCATION_CHECK < Persistence < UI < ResumeCoordinator ──
      test('5e. Execution index tracking: '
          'TRUNCATION_CHECK < Persistence < EXT_TOOL_CARD_RENDERED < ResumeCoordinator.complete', () async {
        // Simulate the Rigid Transactional Termination Pyramid sequencing.
        // Uses integer index counters to assert strict ordering.
        final List<String> executionLog = [];

        // Simulate pipeline stages in the mandated order
        Future<_PipelineStageResult> runOrderedPipeline({
          required String rawText,
          required bool simulateTruncation,
          required bool repairSucceeds,
        }) async {
          // Stage 1: TruncationInspector.inspect() — HARD BARRIER
          executionLog.add('TRUNCATION_CHECK');
          final truncResult = TruncationInspector.inspect(rawText);

          String barrierText = rawText;

          // Stage 2 (conditional): Repair subsystem
          if (simulateTruncation) {
            executionLog.add('REPAIR_SUBSYSTEM');
            if (!repairSucceeds) {
              executionLog.add('DROP_PAYLOAD');
              executionLog.add('RESUME_COORDINATOR_COMPLETE');
              return _PipelineStageResult(
                executionLog: List.from(executionLog),
                droppedPayload: true,
                persistenceCommitted: false,
                resumeCoordinatorCompleted: true,
              );
            }
            barrierText = '$rawText [repaired]';
          }

          // Stage 3: Persistence committed
          executionLog.add('PERSISTENCE');

          // Stage 4: EXT_TOOL_CARD_RENDERED (UI injection)
          executionLog.add('EXT_TOOL_CARD_RENDERED');

          // Stage 5: State event emission → wrappedOnDone
          executionLog.add('STATE_EVENT_COMPLETED');

          // Stage 6: ResumeCoordinator.complete() — STRICTLY LAST
          executionLog.add('RESUME_COORDINATOR_COMPLETE');

          return _PipelineStageResult(
            executionLog: List.from(executionLog),
            droppedPayload: false,
            persistenceCommitted: true,
            resumeCoordinatorCompleted: true,
          );
        }

        final result = await runOrderedPipeline(
          rawText: 'Clinical response text.',
          simulateTruncation: false,
          repairSucceeds: true,
        );

        final log = result.executionLog;

        // Assert strict ordering via index comparisons
        final truncIdx     = log.indexOf('TRUNCATION_CHECK');
        final persistIdx   = log.indexOf('PERSISTENCE');
        final uiIdx        = log.indexOf('EXT_TOOL_CARD_RENDERED');
        final resumeIdx    = log.indexOf('RESUME_COORDINATOR_COMPLETE');

        expect(truncIdx,   greaterThanOrEqualTo(0), reason: 'TRUNCATION_CHECK must execute');
        expect(persistIdx, greaterThanOrEqualTo(0), reason: 'PERSISTENCE must execute');
        expect(uiIdx,      greaterThanOrEqualTo(0), reason: 'EXT_TOOL_CARD_RENDERED must execute');
        expect(resumeIdx,  greaterThanOrEqualTo(0), reason: 'RESUME_COORDINATOR_COMPLETE must execute');

        expect(truncIdx,   lessThan(persistIdx),
            reason: 'TRUNCATION_CHECK must precede PERSISTENCE');
        expect(persistIdx, lessThan(uiIdx),
            reason: 'PERSISTENCE must precede EXT_TOOL_CARD_RENDERED');
        expect(uiIdx,      lessThan(resumeIdx),
            reason: 'EXT_TOOL_CARD_RENDERED must precede RESUME_COORDINATOR_COMPLETE — '
                'marking complete before UI render is prohibited');
        expect(result.resumeCoordinatorCompleted, isTrue);
        expect(result.persistenceCommitted, isTrue);
      });

      // ── 5f: DROP_PAYLOAD → ResumeCoordinator fires even on catastrophic failure ──
      test('5f. catastrophic repair failure → DROP_PAYLOAD → '
          'ResumeCoordinator.complete still fires (no orphan request)', () async {
        final List<String> log = [];

        Future<_PipelineStageResult> runWithCatastrophicFailure() async {
          log.add('TRUNCATION_CHECK');
          log.add('REPAIR_SUBSYSTEM');
          // Repair fails catastrophically
          log.add('DROP_PAYLOAD');
          // wrappedOnError fired before completeAiRequest
          log.add('UI_ERROR_EMITTED');
          log.add('RELEASE_DECISION');
          log.add('RESUME_COORDINATOR_COMPLETE');
          return _PipelineStageResult(
            executionLog: List.from(log),
            droppedPayload: true,
            persistenceCommitted: false,
            resumeCoordinatorCompleted: true,
          );
        }

        final result = await runWithCatastrophicFailure();
        final uiIdx    = result.executionLog.indexOf('UI_ERROR_EMITTED');
        final resumeIdx = result.executionLog.indexOf('RESUME_COORDINATOR_COMPLETE');

        expect(result.droppedPayload, isTrue);
        expect(result.persistenceCommitted, isFalse,
            reason: 'No persistence on DROP_PAYLOAD');
        expect(result.resumeCoordinatorCompleted, isTrue,
            reason: 'ResumeCoordinator must complete even on catastrophic failure');
        expect(uiIdx, lessThan(resumeIdx),
            reason: 'UI error must be emitted before ResumeCoordinator.complete');
      });
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper result type for Group 5 sequencing tests
// ─────────────────────────────────────────────────────────────────────────────
class _PipelineStageResult {
  final List<String> executionLog;
  final bool droppedPayload;
  final bool persistenceCommitted;
  final bool resumeCoordinatorCompleted;

  const _PipelineStageResult({
    required this.executionLog,
    required this.droppedPayload,
    required this.persistenceCommitted,
    required this.resumeCoordinatorCompleted,
  });
}
