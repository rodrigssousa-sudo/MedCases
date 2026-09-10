import 'dart:math' as math;

enum KfreCalibration { northAmerica, nonNorthAmerica }

class CkdGaResult {
  final String gCategory;
  final String aCategory;

  const CkdGaResult({
    required this.gCategory,
    required this.aCategory,
  });

  String get combined => '$gCategory$aCategory';
}

class KfreResult {
  final double risk2YearPercent;
  final double risk5YearPercent;
  final KfreCalibration calibration;

  const KfreResult({
    required this.risk2YearPercent,
    required this.risk5YearPercent,
    required this.calibration,
  });
}

class AkiResult {
  final int stage;
  final int creatinineStage;
  final int urineStage;

  const AkiResult({
    required this.stage,
    required this.creatinineStage,
    required this.urineStage,
  });
}

class NephroScoreEngine2026 {
  const NephroScoreEngine2026._();

  /// NIDDK / CKD-EPI 2021 creatinine equation, adults, no race coefficient.
  static double ckdEpi2021Creatinine({
    required int ageYears,
    required bool female,
    required double serumCreatinineMgDl,
  }) {
    if (ageYears < 18 || ageYears > 120) {
      throw ArgumentError.value(ageYears, 'ageYears');
    }
    if (serumCreatinineMgDl <= 0 || serumCreatinineMgDl > 30) {
      throw ArgumentError.value(
        serumCreatinineMgDl,
        'serumCreatinineMgDl',
      );
    }

    final kappa = female ? 0.7 : 0.9;
    final alpha = female ? -0.241 : -0.302;
    final ratio = serumCreatinineMgDl / kappa;

    return 142 *
        math.pow(math.min(ratio, 1.0), alpha) *
        math.pow(math.max(ratio, 1.0), -1.200) *
        math.pow(0.9938, ageYears) *
        (female ? 1.012 : 1.0);
  }

  static CkdGaResult ckdGa({
    required double egfrMlMin173,
    required double acrMgG,
  }) {
    if (egfrMlMin173 < 0 || egfrMlMin173 > 250) {
      throw ArgumentError.value(egfrMlMin173, 'egfrMlMin173');
    }
    if (acrMgG < 0 || acrMgG > 100000) {
      throw ArgumentError.value(acrMgG, 'acrMgG');
    }

    final g = switch (egfrMlMin173) {
      >= 90 => 'G1',
      >= 60 => 'G2',
      >= 45 => 'G3a',
      >= 30 => 'G3b',
      >= 15 => 'G4',
      _ => 'G5',
    };

    final a = switch (acrMgG) {
      < 30 => 'A1',
      <= 300 => 'A2',
      _ => 'A3',
    };

    return CkdGaResult(gCategory: g, aCategory: a);
  }

  /// Tangri 4-variable KFRE.
  /// ACR in mg/g; validated adult CKD population, primarily eGFR <60.
  /// North America baseline survival: 0.9750 / 0.9240.
  /// Non-North America recalibration: 0.9832 / 0.9365.
  static KfreResult kfre4({
    required int ageYears,
    required bool male,
    required double egfrMlMin173,
    required double acrMgG,
    required KfreCalibration calibration,
  }) {
    if (ageYears < 18 || ageYears > 100) {
      throw ArgumentError.value(ageYears, 'ageYears');
    }
    if (egfrMlMin173 <= 0 || egfrMlMin173 >= 60) {
      throw ArgumentError.value(
        egfrMlMin173,
        'egfrMlMin173',
        'KFRE 4-variable is intended for CKD with eGFR <60',
      );
    }
    if (acrMgG <= 0 || acrMgG > 100000) {
      throw ArgumentError.value(acrMgG, 'acrMgG');
    }

    final lp = -0.2201 * (ageYears / 10 - 7.036) +
        0.2467 * ((male ? 1.0 : 0.0) - 0.5642) -
        0.5567 * (egfrMlMin173 / 5 - 7.222) +
        0.4510 * (math.log(acrMgG) - 5.137);

    final s02 = calibration == KfreCalibration.northAmerica ? 0.9750 : 0.9832;
    final s05 = calibration == KfreCalibration.northAmerica ? 0.9240 : 0.9365;

    final relativeHazard = math.exp(lp);
    final risk2 = (1 - math.pow(s02, relativeHazard)) * 100;
    final risk5 = (1 - math.pow(s05, relativeHazard)) * 100;

    return KfreResult(
      risk2YearPercent: risk2.clamp(0, 100).toDouble(),
      risk5YearPercent: risk5.clamp(0, 100).toDouble(),
      calibration: calibration,
    );
  }

  static double cockcroftGault({
    required int ageYears,
    required bool female,
    required double weightKg,
    required double serumCreatinineMgDl,
  }) {
    if (ageYears < 18 || ageYears > 120) {
      throw ArgumentError.value(ageYears, 'ageYears');
    }
    if (weightKg <= 0 || weightKg > 500) {
      throw ArgumentError.value(weightKg, 'weightKg');
    }
    if (serumCreatinineMgDl <= 0 || serumCreatinineMgDl > 30) {
      throw ArgumentError.value(
        serumCreatinineMgDl,
        'serumCreatinineMgDl',
      );
    }

    final base = ((140 - ageYears) * weightKg) / (72 * serumCreatinineMgDl);
    return base * (female ? 0.85 : 1.0);
  }

  /// KDIGO AKI 2012 final guideline.
  /// 2026 AKI/AKD content is public-review draft and is not treated as final.
  static AkiResult kdigoAki({
    required double baselineCreatinineMgDl,
    required double currentCreatinineMgDl,
    required bool creatinineRiseAtLeast03Within48h,
    double? urineMlKgH,
    double? urineDurationHours,
    double? anuriaHours,
    bool kidneyReplacementTherapy = false,
  }) {
    if (baselineCreatinineMgDl <= 0 || currentCreatinineMgDl <= 0) {
      throw ArgumentError('Creatinine must be >0');
    }

    final ratio = currentCreatinineMgDl / baselineCreatinineMgDl;

    var crStage = 0;
    if (kidneyReplacementTherapy ||
        ratio >= 3 ||
        currentCreatinineMgDl >= 4.0) {
      crStage = 3;
    } else if (ratio >= 2) {
      crStage = 2;
    } else if (ratio >= 1.5 || creatinineRiseAtLeast03Within48h) {
      crStage = 1;
    }

    var urineStage = 0;
    if (anuriaHours != null && anuriaHours >= 12) {
      urineStage = 3;
    } else if (urineMlKgH != null && urineDurationHours != null) {
      if (urineMlKgH < 0.3 && urineDurationHours >= 24) {
        urineStage = 3;
      } else if (urineMlKgH < 0.5 && urineDurationHours >= 12) {
        urineStage = 2;
      } else if (urineMlKgH < 0.5 && urineDurationHours >= 6) {
        urineStage = 1;
      }
    }

    final stage = math.max(crStage, urineStage);
    return AkiResult(
      stage: stage,
      creatinineStage: crStage,
      urineStage: urineStage,
    );
  }

  static double fenaPercent({
    required double urineSodium,
    required double plasmaSodium,
    required double urineCreatinine,
    required double plasmaCreatinine,
  }) {
    _positive(urineSodium, 'urineSodium');
    _positive(plasmaSodium, 'plasmaSodium');
    _positive(urineCreatinine, 'urineCreatinine');
    _positive(plasmaCreatinine, 'plasmaCreatinine');

    return 100 *
        (urineSodium * plasmaCreatinine) /
        (plasmaSodium * urineCreatinine);
  }

  static double feUreaPercent({
    required double urineUrea,
    required double plasmaUrea,
    required double urineCreatinine,
    required double plasmaCreatinine,
  }) {
    _positive(urineUrea, 'urineUrea');
    _positive(plasmaUrea, 'plasmaUrea');
    _positive(urineCreatinine, 'urineCreatinine');
    _positive(plasmaCreatinine, 'plasmaCreatinine');

    return 100 *
        (urineUrea * plasmaCreatinine) /
        (plasmaUrea * urineCreatinine);
  }

  static void _positive(double value, String name) {
    if (value <= 0) throw ArgumentError.value(value, name);
  }
}
