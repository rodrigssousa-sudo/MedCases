import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/entitlement_service.dart';

void main() {
  group('R25A single-owner entitlement contract', () {
    final free = EntitlementService.snapshotForTier(EntitlementTier.free);
    final premium = EntitlementService.snapshotForTier(EntitlementTier.premium);

    test('Premium is a strict superset of Free', () {
      expect(
        premium.capabilities.containsAll(free.capabilities),
        isTrue,
      );
      expect(
        premium.capabilities.length,
        greaterThan(free.capabilities.length),
      );
    });

    test('Free keeps full guides and scores', () {
      expect(free.can(MedCasesCapability.guidesFull), isTrue);
      expect(free.can(MedCasesCapability.scoresFull), isTrue);
    });

    test('Free keeps essential drugs but not premium pharmacology', () {
      expect(free.can(MedCasesCapability.drugsEssentialLibrary), isTrue);
      expect(free.can(MedCasesCapability.drugsFullLibrary), isFalse);
      expect(free.can(MedCasesCapability.drugsWeightDose), isFalse);
      expect(free.can(MedCasesCapability.drugsRenalAdjustment), isFalse);
      expect(free.limits.drugLibraryItems, 400);
    });

    test('Premium unlocks all pharmacology capabilities', () {
      expect(premium.can(MedCasesCapability.drugsFullLibrary), isTrue);
      expect(premium.can(MedCasesCapability.drugsWeightDose), isTrue);
      expect(premium.can(MedCasesCapability.drugsRenalAdjustment), isTrue);
      expect(premium.limits.drugLibraryItems, isNull);
    });

    test('Free AI limits are canonical', () {
      expect(free.limits.aiStudyQueriesPerDay, 5);
      expect(free.limits.plantaoQueriesPerDay, 1);
    });

    test('Free audio, transcription and history limits are canonical', () {
      expect(free.limits.audioRecordingMinutesPerMonth, 15);
      expect(free.limits.transcriptionMinutesPerMonth, 30);
      expect(free.limits.clinicalHistoriesPerMonth, 3);
    });

    test('Premium expands audio/transcription and removes history cap', () {
      expect(premium.limits.audioRecordingMinutesPerMonth, 240);
      expect(premium.limits.transcriptionMinutesPerMonth, 90);
      expect(premium.limits.clinicalHistoriesPerMonth, isNull);
      expect(premium.can(MedCasesCapability.audioLongForm), isTrue);
      expect(premium.can(MedCasesCapability.transcriptionExpanded), isTrue);
    });

    test('Free cannot use long-form Premium audio capabilities', () {
      expect(free.can(MedCasesCapability.audioBasic), isTrue);
      expect(free.can(MedCasesCapability.transcriptionBasic), isTrue);
      expect(free.can(MedCasesCapability.audioLongForm), isFalse);
      expect(free.can(MedCasesCapability.transcriptionExpanded), isFalse);
    });
  });
}
