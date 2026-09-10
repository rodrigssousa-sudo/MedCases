enum WinterStatus {
  expectedCompensation,
  concomitantRespiratoryAlkalosis,
  concomitantRespiratoryAcidosis,
}

class OsmolalityResult {
  final double totalCalculated;
  final double effectiveTonicity;

  const OsmolalityResult({
    required this.totalCalculated,
    required this.effectiveTonicity,
  });
}

class AnionGapResult {
  final double anionGap;
  final double albuminCorrectedAnionGap;

  const AnionGapResult({
    required this.anionGap,
    required this.albuminCorrectedAnionGap,
  });
}

class DeltaRatioResult {
  final bool applicable;
  final double? ratio;

  const DeltaRatioResult._({
    required this.applicable,
    required this.ratio,
  });

  const DeltaRatioResult.notApplicable()
      : this._(applicable: false, ratio: null);

  const DeltaRatioResult.value(double value)
      : this._(applicable: true, ratio: value);
}

class WinterResult {
  final double expectedPco2;
  final double lowerBound;
  final double upperBound;
  final WinterStatus status;

  const WinterResult({
    required this.expectedPco2,
    required this.lowerBound,
    required this.upperBound,
    required this.status,
  });
}

class ElectrolytesScoreEngine2026 {
  const ElectrolytesScoreEngine2026._();

  /// Hyperglycemia correction used in the 2024 international consensus:
  /// +1.6 mmol/L Na for each 100 mg/dL glucose above 100 mg/dL.
  static double correctedSodiumForHyperglycemia({
    required double measuredSodiumMmolL,
    required double glucoseMgDl,
  }) {
    _finitePositive(measuredSodiumMmolL, 'measuredSodiumMmolL');
    _finiteNonNegative(glucoseMgDl, 'glucoseMgDl');

    final glucoseExcess = glucoseMgDl > 100 ? glucoseMgDl - 100 : 0.0;
    return measuredSodiumMmolL + 1.6 * (glucoseExcess / 100.0);
  }

  /// Total calculated osmolality:
  /// 2*Na + glucose/18 + BUN/2.8.
  /// Effective osmolality/tonicity excludes urea:
  /// 2*Na + glucose/18.
  static OsmolalityResult calculatedOsmolalityAndTonicity({
    required double sodiumMmolL,
    required double glucoseMgDl,
    required double bunMgDl,
  }) {
    _finitePositive(sodiumMmolL, 'sodiumMmolL');
    _finiteNonNegative(glucoseMgDl, 'glucoseMgDl');
    _finiteNonNegative(bunMgDl, 'bunMgDl');

    final tonicity = 2.0 * sodiumMmolL + glucoseMgDl / 18.0;
    final total = tonicity + bunMgDl / 2.8;
    return OsmolalityResult(
      totalCalculated: total,
      effectiveTonicity: tonicity,
    );
  }

  static AnionGapResult anionGapWithAlbuminCorrection({
    required double sodiumMmolL,
    required double chlorideMmolL,
    required double bicarbonateMmolL,
    required double albuminGDl,
  }) {
    _finitePositive(sodiumMmolL, 'sodiumMmolL');
    _finiteNonNegative(chlorideMmolL, 'chlorideMmolL');
    _finiteNonNegative(bicarbonateMmolL, 'bicarbonateMmolL');
    _finitePositive(albuminGDl, 'albuminGDl');

    final ag = sodiumMmolL - chlorideMmolL - bicarbonateMmolL;
    final corrected = ag + 2.5 * (4.0 - albuminGDl);

    return AnionGapResult(
      anionGap: ag,
      albuminCorrectedAnionGap: corrected,
    );
  }

  /// Delta ratio with conventional reference values:
  /// (corrected AG - 12) / (24 - HCO3).
  /// Report only when HCO3 <24 and corrected AG >12.
  static DeltaRatioResult deltaRatio({
    required double albuminCorrectedAnionGap,
    required double bicarbonateMmolL,
  }) {
    if (!albuminCorrectedAnionGap.isFinite) {
      throw ArgumentError.value(
        albuminCorrectedAnionGap,
        'albuminCorrectedAnionGap',
      );
    }
    _finiteNonNegative(bicarbonateMmolL, 'bicarbonateMmolL');

    if (bicarbonateMmolL >= 24 || albuminCorrectedAnionGap <= 12) {
      return const DeltaRatioResult.notApplicable();
    }

    return DeltaRatioResult.value(
      (albuminCorrectedAnionGap - 12.0) / (24.0 - bicarbonateMmolL),
    );
  }

  /// Winter's expected respiratory compensation in metabolic acidosis:
  /// expected PaCO2 = 1.5*HCO3 + 8 ±2 mmHg.
  static WinterResult winterCompensation({
    required double bicarbonateMmolL,
    required double measuredPco2MmHg,
  }) {
    _finitePositive(bicarbonateMmolL, 'bicarbonateMmolL');
    _finitePositive(measuredPco2MmHg, 'measuredPco2MmHg');

    final expected = 1.5 * bicarbonateMmolL + 8.0;
    final lower = expected - 2.0;
    final upper = expected + 2.0;

    final status = measuredPco2MmHg < lower
        ? WinterStatus.concomitantRespiratoryAlkalosis
        : measuredPco2MmHg > upper
            ? WinterStatus.concomitantRespiratoryAcidosis
            : WinterStatus.expectedCompensation;

    return WinterResult(
      expectedPco2: expected,
      lowerBound: lower,
      upperBound: upper,
      status: status,
    );
  }

  /// Widely used albumin adjustment for total calcium:
  /// corrected Ca = measured total Ca + 0.8*(4 - albumin), mg/dL.
  /// This is only an estimate; ionized calcium is preferred when protein
  /// binding is unreliable, especially critical illness/major pH shifts.
  static double albuminCorrectedCalcium({
    required double totalCalciumMgDl,
    required double albuminGDl,
  }) {
    _finitePositive(totalCalciumMgDl, 'totalCalciumMgDl');
    _finitePositive(albuminGDl, 'albuminGDl');

    return totalCalciumMgDl + 0.8 * (4.0 - albuminGDl);
  }

  static void _finitePositive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name);
    }
  }

  static void _finiteNonNegative(double value, String name) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(value, name);
    }
  }
}
