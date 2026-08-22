// MEDCASES PEDIATRIA — CLINICAL FOUNDATION 2026
//
// Growth engine based on WHO LMS reference parameters.
// WHO 2006: ages 0–<60 months.
// WHO 2007: ages 60–228 months.
// Weight-for-age WHO 2007: valid through 120 months.
//
// Age supplied as completed years + additional months.
// For WHO 2006 day-based tables, months are converted using
// 365.25 / 12 = 30.4375 days/month and rounded to nearest day,
// matching the WHO Anthro age conversion convention.

import 'dart:math' as math;

import 'who_growth_lms_v2026.dart';

enum PediatricBiologicalSex { male, female }

enum PediatricGrowthIndicator {
  weightForAge,
  heightForAge,
  bmiForAge,
}

enum PediatricGrowthReference {
  whoChildGrowthStandards2006,
  whoGrowthReference2007,
}

class PediatricGrowthAssessmentV2026 {
  final PediatricGrowthIndicator indicator;
  final PediatricGrowthReference reference;
  final PediatricBiologicalSex sex;
  final int ageMonths;
  final double measuredValue;
  final double zScore;
  final double percentile;
  final double p50;
  final String unit;
  final String interpretationPt;
  final String interpretationEs;

  const PediatricGrowthAssessmentV2026({
    required this.indicator,
    required this.reference,
    required this.sex,
    required this.ageMonths,
    required this.measuredValue,
    required this.zScore,
    required this.percentile,
    required this.p50,
    required this.unit,
    required this.interpretationPt,
    required this.interpretationEs,
  });
}

class PediatricGrowthEngineV2026 {
  PediatricGrowthEngineV2026._();

  static const double daysPerMonth = 30.4375;

  static int? totalAgeMonths({
    required int years,
    required int months,
  }) {
    if (years < 0 || months < 0 || months > 11) return null;
    final total = years * 12 + months;
    if (total < 0 || total > 228) return null;
    return total;
  }

  static double? bmi({
    required double weightKg,
    required double heightCm,
  }) {
    if (!weightKg.isFinite ||
        !heightCm.isFinite ||
        weightKg <= 0 ||
        heightCm <= 0) {
      return null;
    }
    final meters = heightCm / 100;
    return weightKg / (meters * meters);
  }

  static PediatricGrowthAssessmentV2026? weightForAge({
    required PediatricBiologicalSex sex,
    required int ageMonths,
    required double weightKg,
  }) {
    if (!weightKg.isFinite || weightKg <= 0) return null;
    final point = _lmsFor(
      indicator: PediatricGrowthIndicator.weightForAge,
      sex: sex,
      ageMonths: ageMonths,
    );
    if (point == null) return null;

    final z = zScoreFromLms(
      measurement: weightKg,
      lms: point.$1,
      restrictedWeightTail: true,
    );

    return _assessment(
      indicator: PediatricGrowthIndicator.weightForAge,
      reference: point.$2,
      sex: sex,
      ageMonths: ageMonths,
      measuredValue: weightKg,
      z: z,
      p50: point.$1.m,
      unit: 'kg',
    );
  }

  static PediatricGrowthAssessmentV2026? heightForAge({
    required PediatricBiologicalSex sex,
    required int ageMonths,
    required double heightCm,
  }) {
    if (!heightCm.isFinite || heightCm <= 0) return null;
    final point = _lmsFor(
      indicator: PediatricGrowthIndicator.heightForAge,
      sex: sex,
      ageMonths: ageMonths,
    );
    if (point == null) return null;

    final z = zScoreFromLms(
      measurement: heightCm,
      lms: point.$1,
      restrictedWeightTail: false,
    );

    return _assessment(
      indicator: PediatricGrowthIndicator.heightForAge,
      reference: point.$2,
      sex: sex,
      ageMonths: ageMonths,
      measuredValue: heightCm,
      z: z,
      p50: point.$1.m,
      unit: 'cm',
    );
  }

  static PediatricGrowthAssessmentV2026? bmiForAge({
    required PediatricBiologicalSex sex,
    required int ageMonths,
    required double weightKg,
    required double heightCm,
  }) {
    final bmiValue = bmi(weightKg: weightKg, heightCm: heightCm);
    if (bmiValue == null) return null;

    final point = _lmsFor(
      indicator: PediatricGrowthIndicator.bmiForAge,
      sex: sex,
      ageMonths: ageMonths,
    );
    if (point == null) return null;

    final z = zScoreFromLms(
      measurement: bmiValue,
      lms: point.$1,
      restrictedWeightTail: true,
    );

    return _assessment(
      indicator: PediatricGrowthIndicator.bmiForAge,
      reference: point.$2,
      sex: sex,
      ageMonths: ageMonths,
      measuredValue: bmiValue,
      z: z,
      p50: point.$1.m,
      unit: 'kg/m²',
    );
  }

  static double referenceValueAtZ({
    required WhoLmsPoint lms,
    required double z,
  }) {
    if (lms.l.abs() < 1e-12) {
      return lms.m * math.exp(lms.s * z);
    }
    final base = 1 + lms.l * lms.s * z;
    if (base <= 0) return double.nan;
    return lms.m * math.pow(base, 1 / lms.l).toDouble();
  }

  static double zScoreFromLms({
    required double measurement,
    required WhoLmsPoint lms,
    required bool restrictedWeightTail,
  }) {
    if (!measurement.isFinite || measurement <= 0) return double.nan;

    final raw = lms.l.abs() < 1e-12
        ? math.log(measurement / lms.m) / lms.s
        : (math.pow(measurement / lms.m, lms.l).toDouble() - 1) /
            (lms.l * lms.s);

    if (!restrictedWeightTail || (raw >= -3 && raw <= 3)) {
      return raw;
    }

    if (raw > 3) {
      final value2 = referenceValueAtZ(lms: lms, z: 2);
      final value3 = referenceValueAtZ(lms: lms, z: 3);
      final sd23 = value3 - value2;
      if (sd23 <= 0 || !sd23.isFinite) return raw;
      return 3 + (measurement - value3) / sd23;
    }

    final valueNeg2 = referenceValueAtZ(lms: lms, z: -2);
    final valueNeg3 = referenceValueAtZ(lms: lms, z: -3);
    final sd23 = valueNeg2 - valueNeg3;
    if (sd23 <= 0 || !sd23.isFinite) return raw;
    return -3 + (measurement - valueNeg3) / sd23;
  }

  static double percentileFromZ(double z) {
    if (!z.isFinite) return double.nan;
    final x = z.abs();
    final t = 1 / (1 + 0.2316419 * x);
    final density = 0.3989422804014327 * math.exp(-0.5 * x * x);
    final tail = density *
        t *
        (0.319381530 +
            t *
                (-0.356563782 +
                    t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
    final cdfPositive = 1 - tail;
    final cdf = z >= 0 ? cdfPositive : 1 - cdfPositive;
    return (cdf * 100).clamp(0.0, 100.0).toDouble();
  }

  static double? referenceValueForIndicatorAtZ({
    required PediatricGrowthIndicator indicator,
    required PediatricBiologicalSex sex,
    required int ageMonths,
    required double z,
  }) {
    final point = _lmsFor(
      indicator: indicator,
      sex: sex,
      ageMonths: ageMonths,
    );
    if (point == null) return null;
    final value = referenceValueAtZ(lms: point.$1, z: z);
    return value.isFinite ? value : null;
  }

  static (WhoLmsPoint, PediatricGrowthReference)? _lmsFor({
    required PediatricGrowthIndicator indicator,
    required PediatricBiologicalSex sex,
    required int ageMonths,
  }) {
    if (ageMonths < 0 || ageMonths > 228) return null;
    final sexCode = sex == PediatricBiologicalSex.male ? 1 : 2;

    if (ageMonths < 60) {
      final ageDays = (ageMonths * daysPerMonth).round();
      final WhoLmsPoint? lms;
      switch (indicator) {
        case PediatricGrowthIndicator.weightForAge:
          lms = WhoGrowthLmsV2026.who2006WeightAgeAt(
            sex: sexCode,
            age: ageDays,
          );
        case PediatricGrowthIndicator.heightForAge:
          lms = WhoGrowthLmsV2026.who2006LengthHeightAgeAt(
            sex: sexCode,
            age: ageDays,
          );
        case PediatricGrowthIndicator.bmiForAge:
          lms = WhoGrowthLmsV2026.who2006BmiAgeAt(
            sex: sexCode,
            age: ageDays,
          );
      }
      if (lms == null) return null;
      return (lms, PediatricGrowthReference.whoChildGrowthStandards2006);
    }

    final WhoLmsPoint? lms;
    switch (indicator) {
      case PediatricGrowthIndicator.weightForAge:
        if (ageMonths > 120) return null;
        lms = WhoGrowthLmsV2026.who2007WeightAgeAt(
          sex: sexCode,
          age: ageMonths,
        );
      case PediatricGrowthIndicator.heightForAge:
        lms = WhoGrowthLmsV2026.who2007HeightAgeAt(
          sex: sexCode,
          age: ageMonths,
        );
      case PediatricGrowthIndicator.bmiForAge:
        lms = WhoGrowthLmsV2026.who2007BmiAgeAt(
          sex: sexCode,
          age: ageMonths,
        );
    }
    if (lms == null) return null;
    return (lms, PediatricGrowthReference.whoGrowthReference2007);
  }

  static PediatricGrowthAssessmentV2026 _assessment({
    required PediatricGrowthIndicator indicator,
    required PediatricGrowthReference reference,
    required PediatricBiologicalSex sex,
    required int ageMonths,
    required double measuredValue,
    required double z,
    required double p50,
    required String unit,
  }) {
    final interpretation = _interpretation(
      indicator: indicator,
      ageMonths: ageMonths,
      z: z,
    );

    return PediatricGrowthAssessmentV2026(
      indicator: indicator,
      reference: reference,
      sex: sex,
      ageMonths: ageMonths,
      measuredValue: measuredValue,
      zScore: z,
      percentile: percentileFromZ(z),
      p50: p50,
      unit: unit,
      interpretationPt: interpretation.$1,
      interpretationEs: interpretation.$2,
    );
  }

  static (String, String) _interpretation({
    required PediatricGrowthIndicator indicator,
    required int ageMonths,
    required double z,
  }) {
    if (!z.isFinite) return ('Indeterminado', 'Indeterminado');

    switch (indicator) {
      case PediatricGrowthIndicator.heightForAge:
        if (z < -3)
          return ('Baixa estatura grave (<−3 DP)', 'Talla baja grave (<−3 DE)');
        if (z < -2) return ('Baixa estatura (<−2 DP)', 'Talla baja (<−2 DE)');
        if (z > 3) return ('Estatura >+3 DP', 'Talla >+3 DE');
        return (
          'Faixa esperada para altura/idade',
          'Rango esperado para talla/edad'
        );

      case PediatricGrowthIndicator.weightForAge:
        if (z < -3)
          return (
            'Peso/idade muito baixo (<−3 DP)',
            'Peso/edad muy bajo (<−3 DE)'
          );
        if (z < -2)
          return ('Peso/idade baixo (<−2 DP)', 'Peso/edad bajo (<−2 DE)');
        if (z > 2) return ('Peso/idade >+2 DP', 'Peso/edad >+2 DE');
        return (
          'Faixa esperada para peso/idade',
          'Rango esperado para peso/edad'
        );

      case PediatricGrowthIndicator.bmiForAge:
        if (ageMonths >= 60) {
          if (z < -3)
            return ('Magreza acentuada (<−3 DP)', 'Delgadez severa (<−3 DE)');
          if (z < -2) return ('Magreza (<−2 DP)', 'Delgadez (<−2 DE)');
          if (z > 2) return ('Obesidade (>+2 DP)', 'Obesidad (>+2 DE)');
          if (z > 1) return ('Sobrepeso (>+1 DP)', 'Sobrepeso (>+1 DE)');
          return (
            'Faixa esperada para IMC/idade',
            'Rango esperado para IMC/edad'
          );
        }

        if (z < -3)
          return (
            'IMC/idade muito baixo (<−3 DP)',
            'IMC/edad muy bajo (<−3 DE)'
          );
        if (z < -2)
          return ('IMC/idade baixo (<−2 DP)', 'IMC/edad bajo (<−2 DE)');
        if (z > 3) return ('Obesidade (>+3 DP)', 'Obesidad (>+3 DE)');
        if (z > 2) return ('Sobrepeso (>+2 DP)', 'Sobrepeso (>+2 DE)');
        return (
          'Faixa esperada para IMC/idade',
          'Rango esperado para IMC/edad'
        );
    }
  }
}
