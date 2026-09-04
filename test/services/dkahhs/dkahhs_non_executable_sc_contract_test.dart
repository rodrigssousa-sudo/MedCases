import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_next_action_engine.dart';
import 'package:medcases/services/dkahhs/dkahhs_runtime_safety_contract.dart';
import 'package:medcases/services/external_tool_link_engine.dart';

void main() {
  test('ORR022 SC DKA is non-executable', () {
    expect(
        DkahhsRuntimeSafetyContract.isScAlternativeRequest(
            'alternativa subcutânea na cetoacidose diabética'),
        isTrue);
    expect(
        DkahhsRuntimeSafetyContract.isScAlternativeRequest(
            'insulina SC en DKA leve'),
        isTrue);
    final a = NextActionEngine.build(
        lastUserMessage: 'alternativa SC na DKA leve',
        lastAiResponse: 'informativo',
        isPlantaoMode: true,
        currentLanguage: 'pt');
    expect(a.label, isEmpty);
    expect(a.promptToSend, isEmpty);
    expect(
        ExternalToolLinkEngine.resolveDecision(
            'r2-sc', 'calcular insulina SC para DKA'),
        isNull);
    expect(
        ExternalToolLinkEngine.build(
            lastUserMessage: 'dose SC na cetoacidose',
            lastAiResponse: 'insulina',
            isPlantaoMode: true,
            currentLanguage: 'pt'),
        isNull);
    expect(
        DkahhsRuntimeSafetyContract.isScAlternativeRequest(
            'monitorar cetoacidose diabética'),
        isFalse);
  });
}
