import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/electrolytes/electrolytes_score_engine_2026.dart';

void main() {
  test('corrected sodium uses 1.6 per 100 mg/dL above 100', () {
    final r = ElectrolytesScoreEngine2026.correctedSodiumForHyperglycemia(
      measuredSodiumMmolL: 130,
      glucoseMgDl: 500,
    );
    expect(r, closeTo(136.4, 1e-12));
  });

  test('calculated osmolality and effective tonicity are exact', () {
    final r = ElectrolytesScoreEngine2026.calculatedOsmolalityAndTonicity(
      sodiumMmolL: 140,
      glucoseMgDl: 90,
      bunMgDl: 14,
    );
    expect(r.effectiveTonicity, closeTo(285, 1e-12));
    expect(r.totalCalculated, closeTo(290, 1e-12));
  });

  test('anion gap and albumin correction are exact', () {
    final r = ElectrolytesScoreEngine2026.anionGapWithAlbuminCorrection(
      sodiumMmolL: 140,
      chlorideMmolL: 104,
      bicarbonateMmolL: 20,
      albuminGDl: 2,
    );
    expect(r.anionGap, closeTo(16, 1e-12));
    expect(r.albuminCorrectedAnionGap, closeTo(21, 1e-12));
  });

  test('delta ratio exact arithmetic and applicability guard', () {
    final r = ElectrolytesScoreEngine2026.deltaRatio(
      albuminCorrectedAnionGap: 21,
      bicarbonateMmolL: 20,
    );
    expect(r.applicable, isTrue);
    expect(r.ratio, closeTo(2.25, 1e-12));

    final no = ElectrolytesScoreEngine2026.deltaRatio(
      albuminCorrectedAnionGap: 12,
      bicarbonateMmolL: 24,
    );
    expect(no.applicable, isFalse);
    expect(no.ratio, isNull);
  });

  test('Winter expected compensation and respiratory disorder detection', () {
    final r = ElectrolytesScoreEngine2026.winterCompensation(
      bicarbonateMmolL: 12,
      measuredPco2MmHg: 30,
    );
    expect(r.expectedPco2, closeTo(26, 1e-12));
    expect(r.lowerBound, closeTo(24, 1e-12));
    expect(r.upperBound, closeTo(28, 1e-12));
    expect(
      r.status,
      WinterStatus.concomitantRespiratoryAcidosis,
    );
  });

  test('albumin corrected calcium exact arithmetic', () {
    final r = ElectrolytesScoreEngine2026.albuminCorrectedCalcium(
      totalCalciumMgDl: 7.8,
      albuminGDl: 2,
    );
    expect(r, closeTo(9.4, 1e-12));
  });
}
