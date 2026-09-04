import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/data/pediatrics/pediatric_growth_engine_v2026.dart';
import 'package:medcases/data/pediatrics/pediatric_renal_engine_v2026.dart';
import 'package:medcases/data/pediatrics/pediatric_reference_registry_v2026.dart';
import 'package:medcases/data/pediatrics/who_growth_lms_v2026.dart';

void main() {
  group('WHO growth foundation 2026', () {
    test('WHO 2006 male birth sentinels match official LMS snapshot', () {
      final weight = WhoGrowthLmsV2026.who2006WeightAgeAt(sex: 1, age: 0);
      final length = WhoGrowthLmsV2026.who2006LengthHeightAgeAt(sex: 1, age: 0);
      final bmi = WhoGrowthLmsV2026.who2006BmiAgeAt(sex: 1, age: 0);

      expect(weight, isNotNull);
      expect(length, isNotNull);
      expect(bmi, isNotNull);

      expect(weight!.m, closeTo(3.3464, 0.00001));
      expect(length!.m, closeTo(49.8842, 0.00001));
      expect(bmi!.m, closeTo(13.4069, 0.00001));
    });

    test('WHO 2007 BMI male age 108 months matches official LMS', () {
      final lms = WhoGrowthLmsV2026.who2007BmiAgeAt(
        sex: 1,
        age: 108,
      );

      expect(lms, isNotNull);
      expect(lms!.l, closeTo(-1.6318, 0.00001));
      expect(lms.m, closeTo(16.0490, 0.00001));
      expect(lms.s, closeTo(0.10038, 0.000001));

      final z = PediatricGrowthEngineV2026.zScoreFromLms(
        measurement: 19,
        lms: lms,
        restrictedWeightTail: true,
      );
      expect(z, closeTo(1.47, 0.02));
    });

    test('WHO 2007 restricted LMS tails reproduce published examples', () {
      final age132 = WhoGrowthLmsV2026.who2007BmiAgeAt(sex: 1, age: 132)!;
      final zHigh = PediatricGrowthEngineV2026.zScoreFromLms(
        measurement: 30,
        lms: age132,
        restrictedWeightTail: true,
      );
      expect(zHigh, closeTo(3.35, 0.03));

      final age192 = WhoGrowthLmsV2026.who2007BmiAgeAt(sex: 1, age: 192)!;
      final zLow = PediatricGrowthEngineV2026.zScoreFromLms(
        measurement: 14,
        lms: age192,
        restrictedWeightTail: true,
      );
      expect(zLow, closeTo(-3.80, 0.03));
    });

    test('WHO reference switches at 60 months', () {
      final a59 = PediatricGrowthEngineV2026.bmiForAge(
        sex: PediatricBiologicalSex.male,
        ageMonths: 59,
        weightKg: 18,
        heightCm: 108,
      );
      final a60 = PediatricGrowthEngineV2026.bmiForAge(
        sex: PediatricBiologicalSex.male,
        ageMonths: 60,
        weightKg: 18,
        heightCm: 108,
      );

      expect(
        a59!.reference,
        PediatricGrowthReference.whoChildGrowthStandards2006,
      );
      expect(
        a60!.reference,
        PediatricGrowthReference.whoGrowthReference2007,
      );
    });

    test('weight-for-age 2007 stops after 120 months', () {
      expect(
        PediatricGrowthEngineV2026.weightForAge(
          sex: PediatricBiologicalSex.female,
          ageMonths: 120,
          weightKg: 30,
        ),
        isNotNull,
      );
      expect(
        PediatricGrowthEngineV2026.weightForAge(
          sex: PediatricBiologicalSex.female,
          ageMonths: 121,
          weightKg: 30,
        ),
        isNull,
      );
    });

    test('percentile conversion is stable', () {
      expect(
        PediatricGrowthEngineV2026.percentileFromZ(0),
        closeTo(50, 0.001),
      );
      expect(
        PediatricGrowthEngineV2026.percentileFromZ(1.96),
        closeTo(97.5, 0.02),
      );
      expect(
        PediatricGrowthEngineV2026.percentileFromZ(-1.96),
        closeTo(2.5, 0.02),
      );
    });
  });

  group('Pediatric renal foundation 2026', () {
    test('CKiD U25 male age 10 example is deterministic', () {
      final egfr = PediatricRenalEngineV2026.ckidU25Creatinine(
        sex: PediatricBiologicalSex.male,
        ageYears: 10,
        heightCm: 140,
        creatinineMgDl: 0.7,
      );

      expect(egfr, closeTo(76.7668, 0.001));
    });

    test('CKiD U25 is sex-dependent', () {
      final male = PediatricRenalEngineV2026.ckidU25Creatinine(
        sex: PediatricBiologicalSex.male,
        ageYears: 10,
        heightCm: 140,
        creatinineMgDl: 0.7,
      );
      final female = PediatricRenalEngineV2026.ckidU25Creatinine(
        sex: PediatricBiologicalSex.female,
        ageYears: 10,
        heightCm: 140,
        creatinineMgDl: 0.7,
      );

      expect(male, isNotNull);
      expect(female, isNotNull);
      expect(male, isNot(equals(female)));
      expect(female, closeTo(71.0585, 0.001));
    });

    test('2009 CKiD bedside equation remains explicit alternative', () {
      final egfr = PediatricRenalEngineV2026.ckidBedside2009(
        heightCm: 140,
        creatinineMgDl: 0.7,
      );

      expect(egfr, closeTo(82.6, 0.001));
    });
  });

  test('reference registry distinguishes source year and reconciled PEWS', () {
    expect(PediatricReferenceRegistryV2026.reviewDate, '2026-08-10');
    expect(
      PediatricReferenceRegistryV2026.pals2025.sourceVersion,
      '2025',
    );
    expect(
      PediatricReferenceRegistryV2026.brightonPews.status,
      'VALIDATED_SCORE_SOURCE_RECONCILED_2026',
    );
    expect(
      PediatricReferenceRegistryV2026.brightonPewsValidation2021.status,
      'VALIDATION_STUDY',
    );
  });
}
