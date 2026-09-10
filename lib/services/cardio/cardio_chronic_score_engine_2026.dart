import 'dart:math' as math;

class Cha2ScoreResult {
  final int score;
  final String bandPt;
  final String bandEs;

  const Cha2ScoreResult({
    required this.score,
    required this.bandPt,
    required this.bandEs,
  });
}

class HasBledResult {
  final int score;
  final bool hypertensionPoint;
  final bool agePoint;
  final String bandPt;
  final String bandEs;

  const HasBledResult({
    required this.score,
    required this.hypertensionPoint,
    required this.agePoint,
    required this.bandPt,
    required this.bandEs,
  });
}

class QtcResult {
  final double milliseconds;
  final String bandPt;
  final String bandEs;

  const QtcResult({
    required this.milliseconds,
    required this.bandPt,
    required this.bandEs,
  });
}

class CardioChronicScoreEngine2026 {
  const CardioChronicScoreEngine2026._();

  static Cha2ScoreResult cha2Ds2Va({
    required int ageYears,
    required bool heartFailure,
    required bool hypertension,
    required bool diabetes,
    required bool priorStrokeTiaTe,
    required bool vascularDisease,
  }) {
    _validateAge(ageYears);

    var score = 0;
    if (heartFailure) score += 1;
    if (hypertension) score += 1;
    if (ageYears >= 75) {
      score += 2;
    } else if (ageYears >= 65) {
      score += 1;
    }
    if (diabetes) score += 1;
    if (priorStrokeTiaTe) score += 2;
    if (vascularDisease) score += 1;

    return Cha2ScoreResult(
      score: score,
      bandPt: score == 0
          ? '0'
          : score == 1
              ? '1'
              : '≥2',
      bandEs: score == 0
          ? '0'
          : score == 1
              ? '1'
              : '≥2',
    );
  }

  static Cha2ScoreResult cha2Ds2Vasc({
    required int ageYears,
    required bool femaleSex,
    required bool heartFailure,
    required bool hypertension,
    required bool diabetes,
    required bool priorStrokeTiaTe,
    required bool vascularDisease,
  }) {
    final va = cha2Ds2Va(
      ageYears: ageYears,
      heartFailure: heartFailure,
      hypertension: hypertension,
      diabetes: diabetes,
      priorStrokeTiaTe: priorStrokeTiaTe,
      vascularDisease: vascularDisease,
    );
    final score = va.score + (femaleSex ? 1 : 0);

    return Cha2ScoreResult(
      score: score,
      bandPt: '$score',
      bandEs: '$score',
    );
  }

  static HasBledResult hasBled({
    required int ageYears,
    required double systolicBpMmHg,
    required bool abnormalRenalFunction,
    required bool abnormalLiverFunction,
    required bool priorStroke,
    required bool bleedingHistoryOrPredisposition,
    required bool labileInr,
    required bool bleedingRiskDrugs,
    required bool highAlcoholUse,
  }) {
    _validateAge(ageYears);
    if (systolicBpMmHg <= 0 || systolicBpMmHg > 350) {
      throw ArgumentError.value(
        systolicBpMmHg,
        'systolicBpMmHg',
        'expected >0 and <=350',
      );
    }

    final hypertensionPoint = systolicBpMmHg > 160;
    final agePoint = ageYears > 65;

    final score = <bool>[
      hypertensionPoint,
      abnormalRenalFunction,
      abnormalLiverFunction,
      priorStroke,
      bleedingHistoryOrPredisposition,
      labileInr,
      agePoint,
      bleedingRiskDrugs,
      highAlcoholUse,
    ].where((value) => value).length;

    final high = score >= 3;
    return HasBledResult(
      score: score,
      hypertensionPoint: hypertensionPoint,
      agePoint: agePoint,
      bandPt: high ? 'Risco elevado' : 'Risco não elevado pelo limiar ≥3',
      bandEs: high ? 'Riesgo elevado' : 'Riesgo no elevado por umbral ≥3',
    );
  }

  static QtcResult bazett({
    required double qtMs,
    required double heartRateBpm,
    required bool femaleSex,
  }) {
    final rr = _rrSeconds(heartRateBpm);
    final qtc = qtMs / math.sqrt(rr);
    return _qtcResult(qtc, femaleSex);
  }

  static QtcResult fridericia({
    required double qtMs,
    required double heartRateBpm,
    required bool femaleSex,
  }) {
    final rr = _rrSeconds(heartRateBpm);
    final qtc = qtMs / math.pow(rr, 1 / 3);
    return _qtcResult(qtc, femaleSex);
  }

  static double _rrSeconds(double heartRateBpm) {
    if (heartRateBpm <= 0 || heartRateBpm > 300) {
      throw ArgumentError.value(
        heartRateBpm,
        'heartRateBpm',
        'expected >0 and <=300',
      );
    }
    return 60 / heartRateBpm;
  }

  static QtcResult _qtcResult(double qtc, bool femaleSex) {
    final practicalUpper = femaleSex ? 460.0 : 450.0;

    String pt;
    String es;
    if (qtc >= 500) {
      pt = '≥500 ms · risco aumentado de TdP';
      es = '≥500 ms · riesgo aumentado de TdP';
    } else if (qtc >= 480) {
      pt = '≥480 ms · prolongamento relevante';
      es = '≥480 ms · prolongación relevante';
    } else if (qtc > practicalUpper) {
      pt = 'Acima do limite prático por sexo';
      es = 'Por encima del límite práctico por sexo';
    } else {
      pt = 'Dentro do limite prático por sexo';
      es = 'Dentro del límite práctico por sexo';
    }

    return QtcResult(
      milliseconds: qtc,
      bandPt: pt,
      bandEs: es,
    );
  }

  static void _validateAge(int ageYears) {
    if (ageYears < 0 || ageYears > 120) {
      throw ArgumentError.value(ageYears, 'ageYears');
    }
  }
}
