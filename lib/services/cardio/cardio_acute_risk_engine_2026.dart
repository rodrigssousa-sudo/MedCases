// MedCases Pro — Cardio Acute Risk Engine 2026
//
// Scope separation:
// - HEART: chest-pain risk tool; use inside structured hs-cTn clinical pathways.
// - TIMI UA/NSTEMI: ischemic event risk in suspected/confirmed NSTE-ACS.
// - GRACE: original admission point score; current ESC ACS 2023 still uses
//   GRACE >140 as a high-risk feature. Do NOT infer GRACE 2.0 probabilities
//   from this point total. GRACE 2.0 probabilities remain a separate model.
// - Killip: clinical prognostic classification in acute MI; not diagnostic.
//
// Guideline context current at MedCases audit 2026-09-09:
// ACC/AHA/ACEP/NAEMSP/SCAI ACS 2025;
// ESC ACS 2023;
// AHA/ACC Chest Pain 2021 + ACC ED Chest Pain ECDP 2022;
// GRACE 2.0 official calculator current.

class CardioAcuteGuidelineMatrix2026 {
  static const acsUs = 'ACC/AHA/ACEP/NAEMSP/SCAI ACS 2025';
  static const acsEsc = 'ESC Acute Coronary Syndromes 2023';
  static const chestPain =
      'AHA/ACC Chest Pain 2021 + ACC ED Chest Pain ECDP 2022';
  static const grace2 = 'GRACE 2.0 official calculator';

  const CardioAcuteGuidelineMatrix2026._();
}

class HeartScoreInput {
  final int historyPoints; // 0 slightly, 1 moderately, 2 highly suspicious
  final int ecgPoints; // 0 normal, 1 nonspecific, 2 significant ST depression
  final int ageYears;
  final int riskFactorCount;
  final bool knownAtheroscleroticDisease;
  final int troponinPoints; // 0 <=ULN, 1 >1–3x ULN, 2 >3x ULN

  const HeartScoreInput({
    required this.historyPoints,
    required this.ecgPoints,
    required this.ageYears,
    required this.riskFactorCount,
    required this.knownAtheroscleroticDisease,
    required this.troponinPoints,
  });
}

class HeartScoreResult {
  final int score;
  final String bandPt;
  final String bandEs;

  const HeartScoreResult(this.score, this.bandPt, this.bandEs);
}

class TimiUaNstemiInput {
  final bool age65OrMore;
  final bool threeOrMoreCadRiskFactors;
  final bool knownCadStenosis50OrMore;
  final bool aspirinWithin7Days;
  final bool twoOrMoreAnginaEpisodes24h;
  final bool stDeviation;
  final bool elevatedCardiacMarkers;

  const TimiUaNstemiInput({
    required this.age65OrMore,
    required this.threeOrMoreCadRiskFactors,
    required this.knownCadStenosis50OrMore,
    required this.aspirinWithin7Days,
    required this.twoOrMoreAnginaEpisodes24h,
    required this.stDeviation,
    required this.elevatedCardiacMarkers,
  });
}

class TimiUaNstemiResult {
  final int score;
  final String bandPt;
  final String bandEs;

  const TimiUaNstemiResult(this.score, this.bandPt, this.bandEs);
}

class GraceAdmissionInput {
  final int ageYears;
  final int heartRateBpm;
  final int systolicBpMmHg;
  final double creatinineMgDl;
  final int killipClass; // I=1 ... IV=4
  final bool cardiacArrestAtAdmission;
  final bool stSegmentDeviation;
  final bool elevatedCardiacMarkers;

  const GraceAdmissionInput({
    required this.ageYears,
    required this.heartRateBpm,
    required this.systolicBpMmHg,
    required this.creatinineMgDl,
    required this.killipClass,
    required this.cardiacArrestAtAdmission,
    required this.stSegmentDeviation,
    required this.elevatedCardiacMarkers,
  });
}

class GraceAdmissionResult {
  final int points;
  final String bandPt;
  final String bandEs;
  final bool escHighRiskAbove140;

  const GraceAdmissionResult({
    required this.points,
    required this.bandPt,
    required this.bandEs,
    required this.escHighRiskAbove140,
  });
}

class KillipResult {
  final int killipClass;
  final String labelPt;
  final String labelEs;
  final String meaningPt;
  final String meaningEs;

  const KillipResult({
    required this.killipClass,
    required this.labelPt,
    required this.labelEs,
    required this.meaningPt,
    required this.meaningEs,
  });
}

class CardioAcuteRiskEngine2026 {
  const CardioAcuteRiskEngine2026._();

  static HeartScoreResult heart(HeartScoreInput input) {
    _assertRange(input.historyPoints, 0, 2, 'HEART history');
    _assertRange(input.ecgPoints, 0, 2, 'HEART ECG');
    _assertRange(input.troponinPoints, 0, 2, 'HEART troponin');
    if (input.ageYears < 0 || input.ageYears > 120) {
      throw ArgumentError.value(input.ageYears, 'ageYears');
    }
    if (input.riskFactorCount < 0 || input.riskFactorCount > 20) {
      throw ArgumentError.value(input.riskFactorCount, 'riskFactorCount');
    }

    final agePoints = input.ageYears < 45
        ? 0
        : input.ageYears < 65
            ? 1
            : 2;
    final riskPoints =
        input.knownAtheroscleroticDisease || input.riskFactorCount >= 3
            ? 2
            : input.riskFactorCount >= 1
                ? 1
                : 0;

    final total = input.historyPoints +
        input.ecgPoints +
        agePoints +
        riskPoints +
        input.troponinPoints;

    if (total <= 3) {
      return HeartScoreResult(total, 'Baixo', 'Bajo');
    }
    if (total <= 6) {
      return HeartScoreResult(total, 'Intermediário', 'Intermedio');
    }
    return HeartScoreResult(total, 'Alto', 'Alto');
  }

  static TimiUaNstemiResult timiUaNstemi(TimiUaNstemiInput input) {
    final values = <bool>[
      input.age65OrMore,
      input.threeOrMoreCadRiskFactors,
      input.knownCadStenosis50OrMore,
      input.aspirinWithin7Days,
      input.twoOrMoreAnginaEpisodes24h,
      input.stDeviation,
      input.elevatedCardiacMarkers,
    ];
    final total = values.where((value) => value).length;
    if (total <= 2) {
      return TimiUaNstemiResult(total, 'Faixa 0–2', 'Rango 0–2');
    }
    if (total <= 4) {
      return TimiUaNstemiResult(total, 'Faixa 3–4', 'Rango 3–4');
    }
    return TimiUaNstemiResult(total, 'Faixa 5–7', 'Rango 5–7');
  }

  static GraceAdmissionResult graceAdmission(GraceAdmissionInput input) {
    if (input.ageYears < 0 || input.ageYears > 120) {
      throw ArgumentError.value(input.ageYears, 'ageYears');
    }
    if (input.heartRateBpm <= 0 || input.heartRateBpm > 350) {
      throw ArgumentError.value(input.heartRateBpm, 'heartRateBpm');
    }
    if (input.systolicBpMmHg <= 0 || input.systolicBpMmHg > 350) {
      throw ArgumentError.value(input.systolicBpMmHg, 'systolicBpMmHg');
    }
    if (input.creatinineMgDl < 0 || input.creatinineMgDl > 20) {
      throw ArgumentError.value(input.creatinineMgDl, 'creatinineMgDl');
    }
    _assertRange(input.killipClass, 1, 4, 'Killip class');

    var points = 0;
    points += _graceAge(input.ageYears);
    points += _graceHeartRate(input.heartRateBpm);
    points += _graceSbp(input.systolicBpMmHg);
    points += _graceCreatinine(input.creatinineMgDl);
    points += <int>[0, 20, 39, 59][input.killipClass - 1];
    if (input.cardiacArrestAtAdmission) points += 39;
    if (input.stSegmentDeviation) points += 28;
    if (input.elevatedCardiacMarkers) points += 14;

    if (points <= 108) {
      return GraceAdmissionResult(
        points: points,
        bandPt: 'Baixo',
        bandEs: 'Bajo',
        escHighRiskAbove140: false,
      );
    }
    if (points <= 140) {
      return GraceAdmissionResult(
        points: points,
        bandPt: 'Intermediário',
        bandEs: 'Intermedio',
        escHighRiskAbove140: false,
      );
    }
    return GraceAdmissionResult(
      points: points,
      bandPt: 'Alto',
      bandEs: 'Alto',
      escHighRiskAbove140: true,
    );
  }

  static KillipResult killip(int value) {
    _assertRange(value, 1, 4, 'Killip class');
    switch (value) {
      case 1:
        return const KillipResult(
          killipClass: 1,
          labelPt: 'Killip I',
          labelEs: 'Killip I',
          meaningPt: 'Sem sinais clínicos de insuficiência cardíaca.',
          meaningEs: 'Sin signos clínicos de insuficiencia cardíaca.',
        );
      case 2:
        return const KillipResult(
          killipClass: 2,
          labelPt: 'Killip II',
          labelEs: 'Killip II',
          meaningPt: 'Estertores/congestão, turgência jugular ou B3.',
          meaningEs: 'Estertores/congestión, ingurgitación yugular o S3.',
        );
      case 3:
        return const KillipResult(
          killipClass: 3,
          labelPt: 'Killip III',
          labelEs: 'Killip III',
          meaningPt: 'Edema agudo de pulmão.',
          meaningEs: 'Edema agudo de pulmón.',
        );
      default:
        return const KillipResult(
          killipClass: 4,
          labelPt: 'Killip IV',
          labelEs: 'Killip IV',
          meaningPt: 'Choque cardiogênico.',
          meaningEs: 'Shock cardiogénico.',
        );
    }
  }

  static int _graceAge(int age) {
    if (age < 30) return 0;
    if (age < 40) return 8;
    if (age < 50) return 25;
    if (age < 60) return 41;
    if (age < 70) return 58;
    if (age < 80) return 75;
    if (age < 90) return 91;
    return 100;
  }

  static int _graceHeartRate(int hr) {
    if (hr < 50) return 0;
    if (hr < 70) return 3;
    if (hr < 90) return 9;
    if (hr < 110) return 15;
    if (hr < 150) return 24;
    if (hr < 200) return 38;
    return 46;
  }

  static int _graceSbp(int sbp) {
    if (sbp < 80) return 58;
    if (sbp < 100) return 53;
    if (sbp < 120) return 43;
    if (sbp < 140) return 34;
    if (sbp < 160) return 24;
    if (sbp < 200) return 10;
    return 0;
  }

  static int _graceCreatinine(double creatinine) {
    if (creatinine < 0.4) return 1;
    if (creatinine < 0.8) return 4;
    if (creatinine < 1.2) return 7;
    if (creatinine < 1.6) return 10;
    if (creatinine < 2.0) return 13;
    if (creatinine < 4.0) return 21;
    return 28;
  }

  static void _assertRange(int value, int min, int max, String name) {
    if (value < min || value > max) {
      throw ArgumentError.value(value, name, 'expected $min..$max');
    }
  }
}
