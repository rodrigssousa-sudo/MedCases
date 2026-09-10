import 'dart:math' as math;

enum ChildAscites { none, mild, moderateSevere }

enum ChildEncephalopathy { none, grade12, grade34 }

class Meld30Result {
  final double rawScore;
  final int score;
  final double bilirubinUsed;
  final double inrUsed;
  final double creatinineUsed;
  final double sodiumUsed;
  final double albuminUsed;

  const Meld30Result({
    required this.rawScore,
    required this.score,
    required this.bilirubinUsed,
    required this.inrUsed,
    required this.creatinineUsed,
    required this.sodiumUsed,
    required this.albuminUsed,
  });
}

class ChildPughResult {
  final int score;
  final String childClass;

  const ChildPughResult({
    required this.score,
    required this.childClass,
  });
}

class LilleResult {
  final double score;
  final int followUpDay;

  const LilleResult({
    required this.score,
    required this.followUpDay,
  });

  bool get nonResponder => score >= 0.45;
}

class HepatoScoreEngine2026 {
  const HepatoScoreEngine2026._();

  /// Official OPTN MELD 3.0 equation.
  /// Policy effective 2025-12-10 in the OPTN Policies effective 2025-12-11.
  static Meld30Result meld30({
    required double bilirubinMgDl,
    required double inr,
    required double creatinineMgDl,
    required double sodiumMmolL,
    required double albuminGDl,
    required bool female,
    bool dialysisCriterionLast7Days = false,
  }) {
    _finitePositive(bilirubinMgDl, 'bilirubinMgDl');
    _finitePositive(inr, 'inr');
    _finitePositive(creatinineMgDl, 'creatinineMgDl');
    _finitePositive(sodiumMmolL, 'sodiumMmolL');
    _finitePositive(albuminGDl, 'albuminGDl');

    final bilirubin = math.max(1.0, bilirubinMgDl);
    final inrUsed = math.max(1.0, inr);
    final creatinine = dialysisCriterionLast7Days
        ? 3.0
        : math.min(3.0, math.max(1.0, creatinineMgDl));
    final sodium = sodiumMmolL.clamp(125.0, 137.0).toDouble();
    final albumin = albuminGDl.clamp(1.5, 3.5).toDouble();

    final raw = 4.56 * math.log(bilirubin) +
        0.82 * (137 - sodium) -
        0.24 * (137 - sodium) * math.log(bilirubin) +
        9.09 * math.log(inrUsed) +
        11.14 * math.log(creatinine) +
        1.85 * (3.5 - albumin) -
        1.83 * (3.5 - albumin) * math.log(creatinine) +
        (female ? 6.33 : 0.0) +
        7.33;

    final rounded = raw.round().clamp(6, 40).toInt();

    return Meld30Result(
      rawScore: raw,
      score: rounded,
      bilirubinUsed: bilirubin,
      inrUsed: inrUsed,
      creatinineUsed: creatinine,
      sodiumUsed: sodium,
      albuminUsed: albumin,
    );
  }

  static ChildPughResult childPugh({
    required double bilirubinMgDl,
    required double albuminGDl,
    required double inr,
    required ChildAscites ascites,
    required ChildEncephalopathy encephalopathy,
  }) {
    _finitePositive(bilirubinMgDl, 'bilirubinMgDl');
    _finitePositive(albuminGDl, 'albuminGDl');
    _finitePositive(inr, 'inr');

    final bilirubinPoints = bilirubinMgDl < 2
        ? 1
        : bilirubinMgDl <= 3
            ? 2
            : 3;
    final albuminPoints = albuminGDl > 3.5
        ? 1
        : albuminGDl >= 2.8
            ? 2
            : 3;
    final inrPoints = inr < 1.7
        ? 1
        : inr <= 2.3
            ? 2
            : 3;
    final ascitesPoints = switch (ascites) {
      ChildAscites.none => 1,
      ChildAscites.mild => 2,
      ChildAscites.moderateSevere => 3,
    };
    final encephalopathyPoints = switch (encephalopathy) {
      ChildEncephalopathy.none => 1,
      ChildEncephalopathy.grade12 => 2,
      ChildEncephalopathy.grade34 => 3,
    };

    final score = bilirubinPoints +
        albuminPoints +
        inrPoints +
        ascitesPoints +
        encephalopathyPoints;
    final childClass = score <= 6
        ? 'A'
        : score <= 9
            ? 'B'
            : 'C';

    return ChildPughResult(score: score, childClass: childClass);
  }

  static double fib4({
    required int ageYears,
    required double astUL,
    required double altUL,
    required double platelets10e9L,
  }) {
    if (ageYears <= 0 || ageYears > 120) {
      throw ArgumentError.value(ageYears, 'ageYears');
    }
    _finitePositive(astUL, 'astUL');
    _finitePositive(altUL, 'altUL');
    _finitePositive(platelets10e9L, 'platelets10e9L');

    return (ageYears * astUL) / (platelets10e9L * math.sqrt(altUL));
  }

  static double maddreyDiscriminantFunction({
    required double patientPtSeconds,
    required double controlPtSeconds,
    required double bilirubinMgDl,
  }) {
    _finitePositive(patientPtSeconds, 'patientPtSeconds');
    _finitePositive(controlPtSeconds, 'controlPtSeconds');
    _finitePositive(bilirubinMgDl, 'bilirubinMgDl');

    return 4.6 * (patientPtSeconds - controlPtSeconds) + bilirubinMgDl;
  }

  /// Original Lille model uses day-7 bilirubin change.
  /// Day-4 use is a later validated adaptation and should be labeled as such.
  static LilleResult lille({
    required int ageYears,
    required double albuminDay0GDl,
    required double bilirubinDay0MgDl,
    required double bilirubinFollowUpMgDl,
    required double creatinineMgDl,
    required double prothrombinTimeSeconds,
    required int followUpDay,
  }) {
    if (ageYears <= 0 || ageYears > 120) {
      throw ArgumentError.value(ageYears, 'ageYears');
    }
    if (followUpDay != 4 && followUpDay != 7) {
      throw ArgumentError.value(followUpDay, 'followUpDay');
    }
    _finitePositive(albuminDay0GDl, 'albuminDay0GDl');
    _finitePositive(bilirubinDay0MgDl, 'bilirubinDay0MgDl');
    _finitePositive(bilirubinFollowUpMgDl, 'bilirubinFollowUpMgDl');
    _finitePositive(creatinineMgDl, 'creatinineMgDl');
    _finitePositive(prothrombinTimeSeconds, 'prothrombinTimeSeconds');

    const mgDlToMicromolL = 17.1;
    final albuminGL = albuminDay0GDl * 10.0;
    final bilirubinDay0Umol = bilirubinDay0MgDl * mgDlToMicromolL;
    final bilirubinFollowUpUmol = bilirubinFollowUpMgDl * mgDlToMicromolL;
    final evolutionUmol = bilirubinDay0Umol - bilirubinFollowUpUmol;
    final renalInsufficiency = creatinineMgDl > 1.3 ? 1.0 : 0.0;

    final r = 3.19 -
        0.101 * ageYears +
        0.147 * albuminGL +
        0.0165 * evolutionUmol -
        0.206 * renalInsufficiency -
        0.0065 * bilirubinDay0Umol -
        0.0096 * prothrombinTimeSeconds;

    final expNegativeR = math.exp(-r);
    final score = expNegativeR / (1 + expNegativeR);

    return LilleResult(
      score: score.clamp(0.0, 1.0).toDouble(),
      followUpDay: followUpDay,
    );
  }

  static void _finitePositive(double value, String name) {
    if (!value.isFinite || value <= 0) {
      throw ArgumentError.value(value, name);
    }
  }
}
