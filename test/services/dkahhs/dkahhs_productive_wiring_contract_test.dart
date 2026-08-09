import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('productive wiring and protected consumers', () {
    final a = File('lib/providers/app_provider.dart').readAsStringSync();
    final n =
        File('lib/services/ai_next_action_engine.dart').readAsStringSync();
    final e =
        File('lib/services/external_tool_link_engine.dart').readAsStringSync();
    expect(a, contains('evaluateFluidRoute('));
    expect(a, contains('evaluatePotassiumGate('));
    expect(a, contains('assessGlucoseDecline('));
    expect(n, contains('isScAlternativeRequest(lastUserMessage)'));
    expect(e, contains('isScAlternativeRequest(userInput)'));
    expect(e, contains('isScAlternativeRequest(lastUserMessage)'));
    for (final p in [
      'lib/screens/ai/widgets/action_buttons_row.dart',
      'lib/screens/ai_screen.dart',
      'lib/screens/protocols_screen.dart',
      'lib/screens/internacion/services/internacion_firestore_service.dart'
    ]) {
      expect(File(p).readAsStringSync(),
          isNot(contains('dkahhs_runtime_safety_contract.dart')),
          reason: p);
    }
  });
}
