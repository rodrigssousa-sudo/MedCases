import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/chat_message.dart';
import 'package:medcases/services/ai/ai_finalization_transaction.dart';
import 'package:medcases/services/ai_gateway_service.dart';
import 'package:medcases/services/ai_pipeline/ai_request_contract.dart';
import 'package:medcases/services/ai_pipeline/ai_ui_request_snapshot.dart';
import 'package:medcases/services/ai_smart_router.dart';

String section(String text, String start, String end) {
  final from = text.indexOf(start);
  expect(from, greaterThanOrEqualTo(0));
  final until = text.indexOf(end, from + start.length);
  expect(until, greaterThan(from));
  return text.substring(from, until);
}

void main() {
  for (final mode in AiRequestMode.values) {
    final study = mode == AiRequestMode.estudo;
    final otherMode = study ? AiRequestMode.plantao : AiRequestMode.estudo;

    test('$mode envelope preserves context, mode, contract and one anchor', () {
      const clinicalContext = 'CONTEXT_SENTINEL_UNCHANGED';
      final prepared = prepareAiRequestPrompt(
        mode: mode,
        systemPrompt: clinicalContext,
      );
      expect(prepared.mode, mode);
      expect(prepared.longResponse, study);
      expect(prepared.isPlantaoMode, !study);
      expect(prepared.providerMode, mode.name);
      expect(prepared.contractName,
          study ? 'CONTRACT_ESTUDO' : 'CONTRACT_PLANTAO');
      expect(
          prepared.anchor, ModeAnchorEngine.getModeAnchor(longResponse: study));
      expect(prepared.systemPrompt, contains(clinicalContext));
      expect(prepared.systemPrompt.split(prepared.anchor).length - 1, 1);
      expect(prepared.systemPrompt.split(prepared.contract).length - 1, 1);
      final repeated = prepareAiRequestPrompt(
          mode: mode, systemPrompt: prepared.systemPrompt);
      expect(repeated.systemPrompt, prepared.systemPrompt);
      expect(
          () => prepareAiRequestPrompt(
              mode: otherMode, systemPrompt: prepared.systemPrompt),
          throwsStateError);
    });

    test('$mode gateway contract already embedded is not duplicated', () {
      final router = AiSmartRouter.build(
        userMessage: 'Definição',
        systemPrompt: 'CONTEXT',
        isPlantaoMode: !study,
        appLanguage: 'pt',
        hasSpecificContext: !study,
      );
      final prepared = prepareAiRequestPrompt(
        mode: mode,
        systemPrompt: router.finalPrompt,
        hasSpecificContext: !study,
      );
      expect(prepared.contractName, router.contractName);
      expect(prepared.systemPrompt.split(prepared.anchor).length - 1, 1);
      expect(prepared.systemPrompt.split(prepared.contract).length - 1, 1);
    });

    test('$mode UI change cannot reinterpret an in-flight terminal', () async {
      var uiMode = mode;
      final request = AiUiRequestSnapshot(
          mode: uiMode,
          generation: 7,
          sessionIdentity: 'session',
          uid: 'owner');
      final terminal = Completer<String>();
      final committed = terminal.future.then(
          (text) => ChatMessage(role: 'ai', text: text, mode: request.mode));
      uiMode = otherMode;
      terminal.complete('ANSWER_SENTINEL');
      final message = await committed;
      expect(uiMode, otherMode);
      expect(request.longResponse, study);
      expect(request.isPlantaoMode, !study);
      expect(message.mode, mode);
      expect(message.copyWith(text: 'UPDATED').mode, mode);
      final finalizer = ActiveAiSessionContext(
        uid: 'owner',
        sessionId: 'session',
        requestId: 'request',
        mode: request.mode.name,
        locale: 'pt',
        createdAt: DateTime(2026),
      );
      expect(finalizer.mode, mode.name);
    });

    for (final transition in ['restore', 'new chat', 'manual mode', 'logout']) {
      test('$mode $transition invalidates queued and in-flight ownership', () {
        final request = AiUiRequestSnapshot(
            mode: mode, generation: 4, sessionIdentity: 'old', uid: 'owner');
        expect(
            request.isCurrent(
                generation: 4, sessionIdentity: 'old', uid: 'owner'),
            isTrue);
        expect(
            request.isCurrent(
                generation: 5, sessionIdentity: 'old', uid: 'owner'),
            isFalse);
        expect(
            request.isCurrent(
                generation: 4, sessionIdentity: 'new', uid: 'owner'),
            isFalse);
        expect(
            request.isCurrent(generation: 4, sessionIdentity: 'old', uid: null),
            isFalse);
        expect(request.mode, mode);
      });
    }

    test('$mode pending action carries explicit identity and mode', () {
      final action = AiPendingQuery(query: 'QUERY', mode: mode);
      final second = AiPendingQuery(query: 'QUERY', mode: mode);
      expect(action.mode, mode);
      expect(action.query, 'QUERY');
      expect(identical(action.identity, second.identity), isFalse);
    });
  }

  final ui = File('lib/screens/ai_screen.dart').readAsStringSync();
  final provider = File('lib/providers/app_provider.dart').readAsStringSync();
  final gateway =
      File('lib/services/ai_gateway_service.dart').readAsStringSync();
  final repair = File('lib/services/ai_service.dart').readAsStringSync();

  test('productive dispatch gates mode and snapshots before any await/queue',
      () {
    final send = section(ui, 'Future<void> _send(', 'void _copyMsg(');
    expect(send, contains('if (!mounted || !_modeConfirmed) return;'));
    expect(RegExp(r'\b_longResponse\b').allMatches(send).length, 1);
    expect(send.indexOf('final requestMode'),
        lessThan(send.indexOf('_queueStudySend(')));
    expect(send, contains('queuedRequest: queuedSnapshot'));
    expect(send, contains('longResponse: requestLongResponse'));
    expect(
        send,
        contains(
            'requestStillCurrent: () => _ownsUiRequest(requestSnapshot, p)'));
    expect(send, contains('if (!_ownsUiRequest(requestSnapshot, p)) return;'));
    expect(send, contains('String safeFinalText = requestLongResponse'));
    expect(
        send,
        contains(
            'if (_ownsUiRequest(requestSnapshot, p)) _sendGuard = false;'));
  });

  test('restores and mode switches invalidate before changing mode/messages',
      () {
    final restore = section(
        ui, 'void _restoreFromSummary(', '/// Desce para o fundo do chat.');
    expect(restore.indexOf('_invalidateAiUiRequest(p)'),
        lessThan(restore.indexOf('_longResponse = restoredMode')));
    final manual =
        section(ui, 'void _commitResponseMode(', 'void _injectGreeting(');
    expect(manual.indexOf('_invalidateAiUiRequest(p)'),
        lessThan(manual.indexOf('_longResponse = newValue')));
    final history =
        section(ui, 'void _onPendingHistory()', '// ── ORDEM 53 M2');
    expect(history.indexOf('_invalidateAiUiRequest(owner)'),
        lessThan(history.indexOf('addPostFrameCallback')));
    expect(history, contains('historyGeneration != _aiUiRequestGeneration'));
  });

  test(
      'Home pending actions declare Study and delayed actions retain ownership',
      () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    expect(RegExp(r'AiPendingQuery\(').allMatches(home).length, 3);
    expect(RegExp(r'mode: AiRequestMode.estudo').allMatches(home).length, 3);
    final pending = section(
        ui, 'void _consumePendingQuery()', 'bool _isOpeningHomeGreeting');
    expect(pending, contains('_startNewChat();'));
    expect(pending, contains('pending.mode'));
    expect(pending, contains('_ownsUiRequest(request, p)'));
    expect(pending, contains('queuedRequest: request'));
    final debounce = section(ui, 'void _sendDebounced(', '// PHASE3I-J2D1');
    expect(debounce, contains('queuedRequest: request'));
    expect(debounce, contains('_ownsUiRequest(request, p)'));
  });

  test('Gemini Free and empty retry wrap raw context once for captured mode',
      () {
    expect(gateway,
        contains('final preparedModePrompt = prepareAiRequestPrompt('));
    expect(
        gateway,
        contains(
            'final String finalSystemPrompt = preparedModePrompt.systemPrompt'));
    for (final start in [
      'final stream = AiGatewayService.sendStream(',
      'final retryStream = AiGatewayService.sendStream('
    ]) {
      final call = section(provider, start, ');');
      expect(call, contains('systemPrompt: baseSystemPrompt'));
      expect(call, contains('longResponse: longResponse'));
      expect(call, contains('isPlantaoMode: !longResponse'));
    }
  });

  test('GPT SSE and Paid fallback share one captured mode envelope', () {
    final qa =
        section(provider, 'final qaModePrompt =', '// CONTINUA: fluxo normal');
    expect(qa, contains('systemPrompt: qaBaseSystemPrompt'));
    expect(qa, contains('mode: requestMode'));
    expect(RegExp(r'mode: qaModePrompt.providerMode').allMatches(qa).length, 2);
    expect(RegExp(r'systemPrompt: qaSystemPrompt').allMatches(qa).length, 2);
  });

  test('GPT fallback, Gemini Paid and paid direct use matching mode/prompt',
      () {
    final normal = section(provider, 'final preparedModePrompt =',
        'Future<String> buildAIAnswer(');
    expect(normal, contains('systemPrompt: baseSystemPrompt'));
    expect(normal, contains('mode: requestMode'));
    expect(
        RegExp(r'mode: preparedModePrompt.providerMode')
            .allMatches(normal)
            .length,
        3);
    expect(RegExp(r'systemPrompt: systemPrompt').allMatches(normal).length, 3);
    expect(normal, contains("tryPaidFallback('global_timeout_free')"));
    expect(normal, contains("tryPaidFallback('retry_stream_error')"));
    expect(normal, isNot(contains('buildAIAnswer(input')));
  });

  test('truncation repair shares captured mode/contract for GPT and Paid', () {
    final body = section(
        repair,
        'static Future<TruncationRepairResult> repairTruncated(',
        'static String _deduplicateTokenOverlap');
    expect(body, contains('final repairModePrompt = prepareAiRequestPrompt('));
    expect(body, contains('mode: requestMode'));
    expect(
        RegExp(r'systemPrompt: repairSystemPrompt').allMatches(body).length, 2);
    expect(RegExp(r'mode: repairMode,').allMatches(body).length, 2);
  });

  test('UI renderer and continuation use message provenance', () {
    expect(
        ui, matches(RegExp(r'final messageLongResponse =\s*msg.mode == null')));
    expect(ui, contains('studyMode: messageLongResponse'));
    expect('sourceMode: msg.mode'.allMatches(ui).length, 3);
    expect(ui, contains('mode: requestMode'));
  });

  test(
      'provider session mode boundary precedes correlation and preserves restores',
      () {
    final send = section(provider, 'Future<bool> sendAiMessage(',
        'Future<bool> _sendAiMessageLegacyCore(');
    expect(send.indexOf('_prepareAiConversationMode('),
        lessThan(send.indexOf('// Phase3K-C5A-R3C: method-scope')));
    final boundary = section(provider, 'void _prepareAiConversationMode(',
        '/// MICRO-BUILD 462E-A.5.3.7.3.2.5.2');
    expect(
        boundary,
        contains(
            '_currentConversationMode != null && _currentConversationMode != mode'));
    expect(boundary, contains('resetAiSessionFull();'));
    expect(boundary, contains('_currentConversationMode = mode;'));
    final restore =
        section(provider, 'void adoptRestoredAiConversation(', 'debugPrint(');
    expect(restore, contains('_currentConversationMode = mode;'));
    final pending =
        section(ui, 'void _onPendingHistory()', '// ── ORDEM 53 M2');
    expect(pending.indexOf('p.resetAiSessionFull();'),
        lessThan(pending.indexOf('p.rebuildAiHistoryFromMessages(')));
  });

  test('legacy is explicit Plantao only and has no productive caller', () {
    final legacy = section(provider, 'Future<String> buildAIAnswer(',
        'Future<String> _buildAIAnswerImpl(');
    expect(legacy, contains('required AiRequestMode mode'));
    expect(legacy, contains("throw StateError('LEGACY_AI_PLANTAO_ONLY')"));
    expect(legacy.indexOf('mode != AiRequestMode.plantao'),
        lessThan(legacy.indexOf('_aiAnswerInProgress')));
    final productive = section(provider, 'Future<bool> sendAiMessage(',
        'Future<String> buildAIAnswer(');
    expect(productive, isNot(contains('await buildAIAnswer(')));
    expect(productive, isNot(contains('await _buildAIAnswerImpl(')));
  });
}
