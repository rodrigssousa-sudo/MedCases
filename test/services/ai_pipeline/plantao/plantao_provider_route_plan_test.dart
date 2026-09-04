import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/ports/plantao_provider_port.dart';

void main() {
  test('Plantão shadow route preserves GPT paid then Gemini paid', () {
    final plan = PlantaoProviderRoutePlan.currentPlantaoPaidFirst();
    expect(
      plan.attempts.map((item) => item.provider).toList(),
      const <PlantaoProviderKind>[
        PlantaoProviderKind.gptPaid,
        PlantaoProviderKind.geminiPaid,
      ],
    );
    expect(plan.attempts.first.isFallback, isFalse);
    expect(plan.attempts.last.isFallback, isTrue);
    expect(PlantaoProviderRoutePlan.productiveConnectionEnabled, isFalse);
    expect(
      PlantaoProviderKind.values.map((item) => item.name),
      isNot(contains('geminiFree')),
    );
  });
}
