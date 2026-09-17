enum PlusScoresMb1Id {
  years,
  nihss,
  sofa,
  qsofa,
  curb65,
  alvarado,
  bisap,
  hinchey,
  silvermanAndersen,
  westley,
  pediatricAppendicitis,
  lrinec,
  mcIsaac,
  dukeIscvid2023,
  caprini2013,
  rcri,
  bishop,
  hellpTennessee,
  ecog,
  mascc,
  ottawaAnkleFoot,
  ottawaKnee,
  nexus,
  canadianCSpine,
  gustiloAnderson,
  mess,
}

class PlusScoresMb1Engine {
  const PlusScoresMb1Engine._();

  static ({int criteria, double cutoffNgMlFeu, bool ruleOut}) years(
      {required bool dvtSigns,
      required bool hemoptysis,
      required bool peMostLikely,
      required double dDimerNgMlFeu}) {
    if (dDimerNgMlFeu < 0) throw ArgumentError('d-dimer');
    final n =
        (dvtSigns ? 1 : 0) + (hemoptysis ? 1 : 0) + (peMostLikely ? 1 : 0);
    final c = n == 0 ? 1000.0 : 500.0;
    return (criteria: n, cutoffNgMlFeu: c, ruleOut: dDimerNgMlFeu < c);
  }

  static int nihss(List<int> x) {
    if (x.length != 15) throw ArgumentError('NIHSS=15 subitems');
    final s = x.fold(0, (a, b) => a + b);
    if (x.any((v) => v < 0 || v > 4) || s > 42) throw ArgumentError('NIHSS');
    return s;
  }

  static int sofa(List<int> x) {
    if (x.length != 6 || x.any((v) => v < 0 || v > 4))
      throw ArgumentError('SOFA');
    return x.fold(0, (a, b) => a + b);
  }

  static int qsofa(
          {required double systolicBp,
          required double respiratoryRate,
          required bool alteredMentalStatus}) =>
      (systolicBp <= 100 ? 1 : 0) +
      (respiratoryRate >= 22 ? 1 : 0) +
      (alteredMentalStatus ? 1 : 0);
  static int curb65(
          {required bool confusion,
          required double ureaMmolL,
          required double respiratoryRate,
          required double systolicBp,
          required double diastolicBp,
          required double ageYears}) =>
      (confusion ? 1 : 0) +
      (ureaMmolL > 7 ? 1 : 0) +
      (respiratoryRate >= 30 ? 1 : 0) +
      ((systolicBp < 90 || diastolicBp <= 60) ? 1 : 0) +
      (ageYears >= 65 ? 1 : 0);
  static int alvarado(
          {required bool migration,
          required bool anorexia,
          required bool nauseaVomiting,
          required bool rlqTenderness,
          required bool rebound,
          required bool fever,
          required bool leukocytosis,
          required bool leftShift}) =>
      (migration ? 1 : 0) +
      (anorexia ? 1 : 0) +
      (nauseaVomiting ? 1 : 0) +
      (rlqTenderness ? 2 : 0) +
      (rebound ? 1 : 0) +
      (fever ? 1 : 0) +
      (leukocytosis ? 2 : 0) +
      (leftShift ? 1 : 0);
  static int bisap(
          {required double bunMgDl,
          required int gcs,
          required bool sirsAtLeast2,
          required double ageYears,
          required bool pleuralEffusion}) =>
      (bunMgDl > 25 ? 1 : 0) +
      (gcs < 15 ? 1 : 0) +
      (sirsAtLeast2 ? 1 : 0) +
      (ageYears > 60 ? 1 : 0) +
      (pleuralEffusion ? 1 : 0);
  static int hincheyStage(int s) {
    if (s < 1 || s > 4) throw ArgumentError('Hinchey');
    return s;
  }

  static int silvermanAndersen(List<int> x) {
    if (x.length != 5 || x.any((v) => v < 0 || v > 2))
      throw ArgumentError('Silverman');
    return x.fold(0, (a, b) => a + b);
  }

  static int westley(
      {required int stridor,
      required int retractions,
      required int airEntry,
      required int cyanosis,
      required int consciousness}) {
    if (![0, 1, 2].contains(stridor) ||
        ![0, 1, 2, 3].contains(retractions) ||
        ![0, 1, 2].contains(airEntry) ||
        ![0, 4, 5].contains(cyanosis) ||
        ![0, 5].contains(consciousness)) throw ArgumentError('Westley');
    return stridor + retractions + airEntry + cyanosis + consciousness;
  }

  static int pediatricAppendicitis(
          {required bool coughPercussionHopTenderness,
          required bool anorexia,
          required bool fever,
          required bool nauseaVomiting,
          required bool rlqTenderness,
          required bool migration,
          required bool leukocytosis,
          required bool neutrophilia}) =>
      (coughPercussionHopTenderness ? 2 : 0) +
      (anorexia ? 1 : 0) +
      (fever ? 1 : 0) +
      (nauseaVomiting ? 1 : 0) +
      (rlqTenderness ? 2 : 0) +
      (migration ? 1 : 0) +
      (leukocytosis ? 1 : 0) +
      (neutrophilia ? 1 : 0);
  static int lrinec(
      {required double crpMgL,
      required double wbcK,
      required double hemoglobinGDl,
      required double sodiumMmolL,
      required double creatinineMgDl,
      required double glucoseMgDl}) {
    var s = 0;
    if (crpMgL >= 150) s += 4;
    if (wbcK > 25) {
      s += 2;
    } else if (wbcK >= 15) {
      s += 1;
    }
    if (hemoglobinGDl < 11) {
      s += 2;
    } else if (hemoglobinGDl <= 13.5) {
      s += 1;
    }
    if (sodiumMmolL < 135) s += 2;
    if (creatinineMgDl > 1.6) s += 2;
    if (glucoseMgDl > 180) s += 1;
    return s;
  }

  static int mcIsaac(
          {required bool feverOver38,
          required bool absentCough,
          required bool tenderAnteriorCervicalNodes,
          required bool tonsillarExudateOrSwelling,
          required int ageBandPoints}) =>
      (feverOver38 ? 1 : 0) +
      (absentCough ? 1 : 0) +
      (tenderAnteriorCervicalNodes ? 1 : 0) +
      (tonsillarExudateOrSwelling ? 1 : 0) +
      ageBandPoints;
  static String dukeIscvid2023(
      {required bool majorMicrobiology,
      required bool majorImaging,
      required bool majorSurgical,
      required bool minorPredisposition,
      required bool minorFever,
      required bool minorVascular,
      required bool minorImmunologic,
      required bool minorMicrobiology,
      required bool minorImaging,
      required bool minorPhysicalExam}) {
    final M = (majorMicrobiology ? 1 : 0) +
        (majorImaging ? 1 : 0) +
        (majorSurgical ? 1 : 0);
    final m = (minorPredisposition ? 1 : 0) +
        (minorFever ? 1 : 0) +
        (minorVascular ? 1 : 0) +
        (minorImmunologic ? 1 : 0) +
        (minorMicrobiology ? 1 : 0) +
        (minorImaging ? 1 : 0) +
        (minorPhysicalExam ? 1 : 0);
    if (M >= 2 || (M == 1 && m >= 3) || m >= 5) return 'definite';
    if ((M == 1 && m >= 1) || m >= 3) return 'possible';
    return 'rejected';
  }

  static int caprini2013(List<int> x) {
    if (x.any((v) => ![1, 2, 3, 5].contains(v))) throw ArgumentError('Caprini');
    return x.fold(0, (a, b) => a + b);
  }

  static int rcri(
          {required bool highRiskSurgery,
          required bool ischemicHeartDisease,
          required bool heartFailure,
          required bool cerebrovascularDisease,
          required bool insulinTherapy,
          required bool creatinineOver2}) =>
      (highRiskSurgery ? 1 : 0) +
      (ischemicHeartDisease ? 1 : 0) +
      (heartFailure ? 1 : 0) +
      (cerebrovascularDisease ? 1 : 0) +
      (insulinTherapy ? 1 : 0) +
      (creatinineOver2 ? 1 : 0);
  static int bishop(
          {required int dilationPoints,
          required int effacementPoints,
          required int consistencyPoints,
          required int positionPoints,
          required int stationPoints}) =>
      dilationPoints +
      effacementPoints +
      consistencyPoints +
      positionPoints +
      stationPoints;
  static bool hellpTennessee(
          {required double ldhUL,
          required double astUL,
          required double plateletsPerMm3,
          required double indirectBilirubinMgDl,
          required bool schistocytesOrHemolysisEvidence}) =>
      (ldhUL >= 600 ||
          indirectBilirubinMgDl >= 1.2 ||
          schistocytesOrHemolysisEvidence) &&
      astUL >= 70 &&
      plateletsPerMm3 < 100000;
  static int ecog(int g) {
    if (g < 0 || g > 5) throw ArgumentError('ECOG');
    return g;
  }

  static int mascc(
          {required int burdenPoints,
          required bool noHypotension,
          required bool noCopd,
          required bool solidTumorOrHemeNoPriorFungal,
          required bool noDehydration,
          required bool outpatientOnset,
          required bool ageUnder60}) =>
      burdenPoints +
      (noHypotension ? 5 : 0) +
      (noCopd ? 4 : 0) +
      (solidTumorOrHemeNoPriorFungal ? 4 : 0) +
      (noDehydration ? 3 : 0) +
      (outpatientOnset ? 3 : 0) +
      (ageUnder60 ? 2 : 0);
  static ({bool ankleImaging, bool footImaging}) ottawaAnkleFoot(
          {required bool malleolarZonePain,
          required bool midfootZonePain,
          required bool posteriorLateralMalleolusTenderness,
          required bool posteriorMedialMalleolusTenderness,
          required bool fifthMetatarsalTenderness,
          required bool navicularTenderness,
          required bool unableFourSteps}) =>
      (
        ankleImaging: malleolarZonePain &&
            (posteriorLateralMalleolusTenderness ||
                posteriorMedialMalleolusTenderness ||
                unableFourSteps),
        footImaging: midfootZonePain &&
            (fifthMetatarsalTenderness ||
                navicularTenderness ||
                unableFourSteps)
      );
  static bool ottawaKnee(
          {required bool age55OrOlder,
          required bool isolatedPatellarTenderness,
          required bool fibularHeadTenderness,
          required bool unableFlex90,
          required bool unableFourSteps}) =>
      age55OrOlder ||
      isolatedPatellarTenderness ||
      fibularHeadTenderness ||
      unableFlex90 ||
      unableFourSteps;
  static bool nexusLowRisk(
          {required bool midlineTenderness,
          required bool focalNeurologicDeficit,
          required bool alteredAlertness,
          required bool intoxication,
          required bool distractingInjury}) =>
      !midlineTenderness &&
      !focalNeurologicDeficit &&
      !alteredAlertness &&
      !intoxication &&
      !distractingInjury;
  static bool canadianCSpineNeedsImaging(
      {required bool applicableAlertStable,
      required bool age65OrOlder,
      required bool dangerousMechanism,
      required bool extremityParesthesias,
      required bool simpleRearEnd,
      required bool sittingInEd,
      required bool ambulatoryAnyTime,
      required bool delayedNeckPain,
      required bool noMidlineTenderness,
      required bool canRotate45BothWays}) {
    if (!applicableAlertStable) return true;
    if (age65OrOlder || dangerousMechanism || extremityParesthesias)
      return true;
    final low = simpleRearEnd ||
        sittingInEd ||
        ambulatoryAnyTime ||
        delayedNeckPain ||
        noMidlineTenderness;
    if (!low) return true;
    return !canRotate45BothWays;
  }

  static int gustiloAnderson(int g) {
    if (g < 1 || g > 5) throw ArgumentError('Gustilo');
    return g;
  }

  static int mess(
          {required int skeletalSoftTissuePoints,
          required int limbIschemiaPoints,
          required bool ischemiaOver6Hours,
          required int shockPoints,
          required int agePoints}) =>
      skeletalSoftTissuePoints +
      limbIschemiaPoints * (ischemiaOver6Hours ? 2 : 1) +
      shockPoints +
      agePoints;
}
