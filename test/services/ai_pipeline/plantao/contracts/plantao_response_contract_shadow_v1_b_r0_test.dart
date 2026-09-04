import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart';

bool containsEmojiOrPictograph(String input) {
  for (final rune in input.runes) {
    if ((rune >= 0x1F000 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        (rune >= 0xFE00 && rune <= 0xFE0F) ||
        rune == 0x200D ||
        rune == 0x20E3) {
      return true;
    }
  }
  return false;
}

void main() {
  group('Plantao typed response contract shadow V1-B-R0', () {
    test('registry has exactly 22 semantic models', () {
      expect(PlantaoResponseContractRegistry.contracts, hasLength(22));
      expect(PlantaoResponseModelId.values, hasLength(22));
    });

    test('legacy matrix bridge is complete and one-to-one', () {
      final numbers = PlantaoResponseContractRegistry.contracts
          .map((c) => c.legacyMatrixNumber)
          .toList();

      expect(numbers.toSet(), hasLength(22));
      expect(numbers.toSet(),
          equals(Set<int>.from(List.generate(22, (i) => i + 1))));

      for (var matrix = 1; matrix <= 22; matrix++) {
        expect(
          PlantaoResponseContractRegistry.byLegacyMatrix(matrix)
              .legacyMatrixNumber,
          matrix,
        );
      }
    });

    test('semantic ids and wire names are unique', () {
      final ids =
          PlantaoResponseContractRegistry.contracts.map((c) => c.id).toList();
      final wireNames = ids.map((id) => id.wireName).toList();

      expect(ids.toSet(), hasLength(22));
      expect(wireNames.toSet(), hasLength(22));

      for (final wireName in wireNames) {
        expect(wireName, matches(RegExp(r'^[a-z0-9_]+$')));
        expect(wireName, isNot(startsWith('matrix')));
      }
    });

    test('every contract has title and ordered sections in PT and ES', () {
      for (final contract in PlantaoResponseContractRegistry.contracts) {
        expect(contract.titleTemplate.pt.trim(), isNotEmpty);
        expect(contract.titleTemplate.es.trim(), isNotEmpty);
        expect(contract.sections, isNotEmpty);

        final keys = contract.sections.map((s) => s.key).toList();
        expect(keys.toSet().length, keys.length);

        for (final section in contract.sections) {
          expect(section.key, matches(RegExp(r'^[a-z0-9_]+$')));
          expect(section.label.pt.trim(), isNotEmpty);
          expect(section.label.es.trim(), isNotEmpty);
        }
      }
    });

    test('language changes labels, never model identity', () {
      for (final contract in PlantaoResponseContractRegistry.contracts) {
        final sameById = PlantaoResponseContractRegistry.byId(contract.id);

        expect(sameById.id, contract.id);
        expect(
          sameById.titleTemplate.forLanguage('pt'),
          contract.titleTemplate.pt,
        );
        expect(
          sameById.titleTemplate.forLanguage('es'),
          contract.titleTemplate.es,
        );
      }
    });

    test('canonical contract contains no emoji or pictographic decoration', () {
      for (final contract in PlantaoResponseContractRegistry.contracts) {
        expect(containsEmojiOrPictograph(contract.id.wireName), isFalse);
        expect(containsEmojiOrPictograph(contract.titleTemplate.pt), isFalse);
        expect(containsEmojiOrPictograph(contract.titleTemplate.es), isFalse);

        for (final section in contract.sections) {
          expect(containsEmojiOrPictograph(section.key), isFalse);
          expect(containsEmojiOrPictograph(section.label.pt), isFalse);
          expect(containsEmojiOrPictograph(section.label.es), isFalse);
        }
      }

      final source = File(
        'lib/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart',
      ).readAsStringSync();

      expect(containsEmojiOrPictograph(source), isFalse);
    });

    test('shadow foundation does not expose matrix names as canonical ids', () {
      for (final contract in PlantaoResponseContractRegistry.contracts) {
        expect(contract.id.wireName, isNot(contains('matriz')));
        expect(contract.id.wireName, isNot(contains('matrix')));
      }
    });
  });
}
