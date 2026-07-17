import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_service.dart';

void main() {
  group('AiService repair merge — clinical token integrity', () {
    test('rejoins numeric token split across provider boundary: 18 + 0 = 180',
        () {
      final merged = AiService.deduplicateTokenOverlapForTesting(
        '- **Ticagrelor 18',
        '0 mg VO** (carga).',
      );

      expect(
        merged,
        '- **Ticagrelor 180 mg VO** (carga).',
      );
      expect(merged, isNot(contains('18 0 mg')));
    });

    test('preserves normal separation between complete clinical fragments', () {
      final merged = AiService.deduplicateTokenOverlapForTesting(
        '- AAS 300 mg VO.',
        '- Ticagrelor 180 mg VO.',
      );

      expect(
        merged,
        '- AAS 300 mg VO. - Ticagrelor 180 mg VO.',
      );
    });

    test('removes an exact repeated suffix-prefix overlap', () {
      final merged = AiService.deduplicateTokenOverlapForTesting(
        'Administrar ticagrelor 180 mg',
        '180 mg VO em dose de ataque.',
      );

      expect(
        merged,
        'Administrar ticagrelor 180 mg VO em dose de ataque.',
      );
    });
  });
}
