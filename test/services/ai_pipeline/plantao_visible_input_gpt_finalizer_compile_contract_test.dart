import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/providers/app_provider.dart';

void main() {
  test('AppProvider compiles with the visible-input GPT finalizer contract',
      () {
    final route = AppProvider.resolveEffectiveAiPriorityForRouting(
      isPlantaoMode: true,
      geminiConnected: false,
      aiPriority: 'critical',
      forcePaidCanary: false,
    );

    expect(route, 'critical');
  });
}
