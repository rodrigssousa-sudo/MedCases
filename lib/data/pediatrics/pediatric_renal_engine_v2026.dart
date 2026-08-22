// MEDCASES PEDIATRIA — RENAL FOUNDATION 2026
//
// Current preferred pediatric equation:
// CKiD U25 creatinine equation (NIDDK; Pierce et al., Kidney Int. 2021).
//
// Historical quick estimate retained as an explicitly named alternative:
// 2009 CKiD "bedside" creatinine equation.
//
// This file does not change the existing visible Schwartz UI yet.
// V1-B will migrate/relabel the screen only after technical validation.

import 'dart:math' as math;

import 'pediatric_growth_engine_v2026.dart';

class PediatricRenalEngineV2026 {
  PediatricRenalEngineV2026._();

  static double? ckidU25Creatinine({
    required PediatricBiologicalSex sex,
    required double ageYears,
    required double heightCm,
    required double creatinineMgDl,
  }) {
    if (!ageYears.isFinite ||
        !heightCm.isFinite ||
        !creatinineMgDl.isFinite ||
        ageYears < 1 ||
        ageYears > 25 ||
        heightCm <= 0 ||
        creatinineMgDl <= 0) {
      return null;
    }

    final female = sex == PediatricBiologicalSex.female;
    final double kappa;

    if (ageYears < 12) {
      final base = female ? 36.1 : 39.0;
      kappa = base * math.pow(1.008, ageYears - 12).toDouble();
    } else if (ageYears < 18) {
      final base = female ? 36.1 : 39.0;
      final factor = female ? 1.023 : 1.045;
      kappa = base * math.pow(factor, ageYears - 12).toDouble();
    } else {
      kappa = female ? 41.4 : 50.8;
    }

    final heightM = heightCm / 100;
    return kappa * (heightM / creatinineMgDl);
  }

  static double? ckidBedside2009({
    required double heightCm,
    required double creatinineMgDl,
  }) {
    if (!heightCm.isFinite ||
        !creatinineMgDl.isFinite ||
        heightCm <= 0 ||
        creatinineMgDl <= 0) {
      return null;
    }

    return 0.413 * heightCm / creatinineMgDl;
  }
}
