import 'dart:math' as math;

enum PlusScoresMb2Id {
  phq9,
  sadPersonsHistorical,
  fraxOfficial,
  findrisc,
  burchWartofsky,
  revisedTraumaScore,
  injurySeverityScore,
  atlsHemorrhagicShock,
  das28,
  sledai2k,
  basdai,
  beighton,
  katzAdl,
  lawtonBrody,
  mmseScoreRecord,
  isthDic2025,
  fourTs,
  plasmic,
  ipssR,
  ipssProstate,
  gleasonIsup,
  bosniak2019,
  snappe2,
  newBallard,
  modifiedBell,
}

class PlusScoresMb2Engine {
  const PlusScoresMb2Engine._();

  static int phq9(List<int> items) {
    if (items.length != 9) {
      throw ArgumentError('PHQ-9 requires exactly 9 items.');
    }
    for (final value in items) {
      if (value < 0 || value > 3) {
        throw ArgumentError.value(value, 'items');
      }
    }
    return items.fold<int>(0, (a, b) => a + b);
  }

  static int sadPersonsHistorical(List<bool> items) {
    if (items.length != 10) {
      throw ArgumentError(
          'SAD PERSONS historical checklist requires 10 items.');
    }
    return items.where((v) => v).length;
  }

  static int findrisc({
    required double ageYears,
    required double bmi,
    required double waistCm,
    required bool female,
    required bool physicalActivity30MinDaily,
    required bool dailyFruitVegetables,
    required bool antihypertensiveMedication,
    required bool priorHighGlucose,
    required int familyHistoryPoints,
  }) {
    if (ageYears < 0 || ageYears > 130 || bmi < 0 || bmi > 100 || waistCm < 0) {
      throw ArgumentError('Invalid FINDRISC numeric input.');
    }
    if (![0, 3, 5].contains(familyHistoryPoints)) {
      throw ArgumentError.value(familyHistoryPoints, 'familyHistoryPoints');
    }

    var score = 0;
    if (ageYears >= 65) {
      score += 4;
    } else if (ageYears >= 55) {
      score += 3;
    } else if (ageYears >= 45) {
      score += 2;
    }

    if (bmi >= 30) {
      score += 3;
    } else if (bmi >= 25) {
      score += 1;
    }

    if (female) {
      if (waistCm >= 88) {
        score += 4;
      } else if (waistCm >= 80) {
        score += 3;
      }
    } else {
      if (waistCm >= 102) {
        score += 4;
      } else if (waistCm >= 94) {
        score += 3;
      }
    }

    if (!physicalActivity30MinDaily) score += 2;
    if (!dailyFruitVegetables) score += 1;
    if (antihypertensiveMedication) score += 2;
    if (priorHighGlucose) score += 5;
    score += familyHistoryPoints;
    return score;
  }

  static int burchWartofsky({
    required double temperatureC,
    required double heartRate,
    required int giHepaticPoints,
    required int cnsPoints,
    required int chfPoints,
    required bool atrialFibrillation,
    required bool precipitatingEvent,
  }) {
    if (temperatureC < 30 ||
        temperatureC > 45 ||
        heartRate < 0 ||
        heartRate > 300) {
      throw ArgumentError('Invalid Burch-Wartofsky vital sign.');
    }
    if (![0, 10, 20].contains(giHepaticPoints) ||
        ![0, 10, 20, 30].contains(cnsPoints) ||
        ![0, 5, 10, 15].contains(chfPoints)) {
      throw ArgumentError('Invalid Burch-Wartofsky component.');
    }

    var temperaturePoints = 0;
    if (temperatureC >= 40.0) {
      temperaturePoints = 30;
    } else if (temperatureC >= 39.4) {
      temperaturePoints = 25;
    } else if (temperatureC >= 38.9) {
      temperaturePoints = 20;
    } else if (temperatureC >= 38.3) {
      temperaturePoints = 15;
    } else if (temperatureC >= 37.8) {
      temperaturePoints = 10;
    } else if (temperatureC >= 37.2) {
      temperaturePoints = 5;
    }

    var heartRatePoints = 0;
    if (heartRate >= 140) {
      heartRatePoints = 25;
    } else if (heartRate >= 130) {
      heartRatePoints = 20;
    } else if (heartRate >= 120) {
      heartRatePoints = 15;
    } else if (heartRate >= 110) {
      heartRatePoints = 10;
    } else if (heartRate >= 90) {
      heartRatePoints = 5;
    }

    return temperaturePoints +
        heartRatePoints +
        giHepaticPoints +
        cnsPoints +
        chfPoints +
        (atrialFibrillation ? 10 : 0) +
        (precipitatingEvent ? 10 : 0);
  }

  static ({int gcsCode, int sbpCode, int rrCode, double weighted})
      revisedTraumaScore({
    required int gcs,
    required double systolicBp,
    required double respiratoryRate,
  }) {
    if (gcs < 3 || gcs > 15 || systolicBp < 0 || respiratoryRate < 0) {
      throw ArgumentError('Invalid RTS input.');
    }

    final gcsCode = gcs >= 13
        ? 4
        : gcs >= 9
            ? 3
            : gcs >= 6
                ? 2
                : gcs >= 4
                    ? 1
                    : 0;

    final sbpCode = systolicBp > 89
        ? 4
        : systolicBp >= 76
            ? 3
            : systolicBp >= 50
                ? 2
                : systolicBp >= 1
                    ? 1
                    : 0;

    final rrCode = respiratoryRate >= 10 && respiratoryRate <= 29
        ? 4
        : respiratoryRate > 29
            ? 3
            : respiratoryRate >= 6
                ? 2
                : respiratoryRate >= 1
                    ? 1
                    : 0;

    final weighted = 0.9368 * gcsCode + 0.7326 * sbpCode + 0.2908 * rrCode;
    return (
      gcsCode: gcsCode,
      sbpCode: sbpCode,
      rrCode: rrCode,
      weighted: weighted
    );
  }

  static int injurySeverityScore({
    required int topAisRegion1,
    required int topAisRegion2,
    required int topAisRegion3,
  }) {
    final values = [topAisRegion1, topAisRegion2, topAisRegion3];
    for (final value in values) {
      if (value < 0 || value > 6) {
        throw ArgumentError.value(value, 'AIS');
      }
    }
    if (values.contains(6)) return 75;
    values.sort((a, b) => b.compareTo(a));
    return values.take(3).fold<int>(0, (sum, v) => sum + v * v);
  }

  static int atlsHemorrhagicShockClass(double estimatedBloodLossPercent) {
    if (estimatedBloodLossPercent < 0 || estimatedBloodLossPercent > 100) {
      throw ArgumentError.value(
          estimatedBloodLossPercent, 'estimatedBloodLossPercent');
    }
    if (estimatedBloodLossPercent < 15) return 1;
    if (estimatedBloodLossPercent <= 30) return 2;
    if (estimatedBloodLossPercent <= 40) return 3;
    return 4;
  }

  static double das28Esr({
    required int tenderJointCount28,
    required int swollenJointCount28,
    required double esrMmH,
    required double patientGlobalMm,
  }) {
    if (tenderJointCount28 < 0 ||
        tenderJointCount28 > 28 ||
        swollenJointCount28 < 0 ||
        swollenJointCount28 > 28 ||
        esrMmH <= 0 ||
        patientGlobalMm < 0 ||
        patientGlobalMm > 100) {
      throw ArgumentError('Invalid DAS28-ESR input.');
    }
    return 0.56 * math.sqrt(tenderJointCount28) +
        0.28 * math.sqrt(swollenJointCount28) +
        0.70 * math.log(esrMmH) +
        0.014 * patientGlobalMm;
  }

  static double das28Crp({
    required int tenderJointCount28,
    required int swollenJointCount28,
    required double crpMgL,
    required double patientGlobalMm,
  }) {
    if (tenderJointCount28 < 0 ||
        tenderJointCount28 > 28 ||
        swollenJointCount28 < 0 ||
        swollenJointCount28 > 28 ||
        crpMgL < 0 ||
        patientGlobalMm < 0 ||
        patientGlobalMm > 100) {
      throw ArgumentError('Invalid DAS28-CRP input.');
    }
    return 0.56 * math.sqrt(tenderJointCount28) +
        0.28 * math.sqrt(swollenJointCount28) +
        0.36 * math.log(crpMgL + 1) +
        0.014 * patientGlobalMm +
        0.96;
  }

  static int sledai2k({
    required List<bool> weight8,
    required List<bool> weight4,
    required List<bool> weight2,
    required List<bool> weight1,
  }) {
    if (weight8.length != 8 ||
        weight4.length != 6 ||
        weight2.length != 7 ||
        weight1.length != 3) {
      throw ArgumentError('Invalid SLEDAI-2K descriptor vector.');
    }
    return weight8.where((v) => v).length * 8 +
        weight4.where((v) => v).length * 4 +
        weight2.where((v) => v).length * 2 +
        weight1.where((v) => v).length;
  }

  static double basdai(List<double> items) {
    if (items.length != 6) throw ArgumentError('BASDAI requires 6 items.');
    for (final value in items) {
      if (value < 0 || value > 10) throw ArgumentError.value(value, 'items');
    }
    return (items[0] +
            items[1] +
            items[2] +
            items[3] +
            (items[4] + items[5]) / 2) /
        5;
  }

  static int beighton(List<bool> nineManeuvers) {
    if (nineManeuvers.length != 9)
      throw ArgumentError('Beighton requires 9 binary maneuvers.');
    return nineManeuvers.where((v) => v).length;
  }

  static int katzAdl(List<bool> independentDomains) {
    if (independentDomains.length != 6)
      throw ArgumentError('Katz ADL requires 6 domains.');
    return independentDomains.where((v) => v).length;
  }

  static int lawtonBrody(List<bool> independentDomains) {
    if (independentDomains.length != 8)
      throw ArgumentError('Lawton-Brody requires 8 domains.');
    return independentDomains.where((v) => v).length;
  }

  static int mmseRecord(int authorizedScore) {
    if (authorizedScore < 0 || authorizedScore > 30) {
      throw ArgumentError.value(authorizedScore, 'authorizedScore');
    }
    return authorizedScore;
  }

  static int isthDic2025({
    required double plateletsX109L,
    required double dDimerTimesUln,
    required double ptProlongationSeconds,
    required double fibrinogenMgDl,
  }) {
    if (plateletsX109L < 0 ||
        dDimerTimesUln < 0 ||
        ptProlongationSeconds < 0 ||
        fibrinogenMgDl < 0) {
      throw ArgumentError('Invalid ISTH DIC 2025 input.');
    }
    var score = 0;
    if (plateletsX109L < 50) {
      score += 2;
    } else if (plateletsX109L < 100) {
      score += 1;
    }
    if (dDimerTimesUln > 7) {
      score += 3;
    } else if (dDimerTimesUln > 3) {
      score += 2;
    }
    if (ptProlongationSeconds >= 6) {
      score += 2;
    } else if (ptProlongationSeconds >= 3) {
      score += 1;
    }
    if (fibrinogenMgDl < 100) score += 1;
    return score;
  }

  static int fourTs({
    required int thrombocytopenia,
    required int timing,
    required int thrombosis,
    required int otherCauses,
  }) {
    final values = [thrombocytopenia, timing, thrombosis, otherCauses];
    for (final value in values) {
      if (value < 0 || value > 2)
        throw ArgumentError.value(value, '4Ts component');
    }
    return values.fold<int>(0, (a, b) => a + b);
  }

  static int plasmic({
    required double plateletsX109L,
    required bool hemolysis,
    required bool noActiveCancer,
    required bool noSolidOrganOrStemCellTransplant,
    required double mcvFl,
    required double inr,
    required double creatinineMgDl,
  }) {
    if (plateletsX109L < 0 || mcvFl < 0 || inr < 0 || creatinineMgDl < 0) {
      throw ArgumentError('Invalid PLASMIC input.');
    }
    return (plateletsX109L < 30 ? 1 : 0) +
        (hemolysis ? 1 : 0) +
        (noActiveCancer ? 1 : 0) +
        (noSolidOrganOrStemCellTransplant ? 1 : 0) +
        (mcvFl < 90 ? 1 : 0) +
        (inr < 1.5 ? 1 : 0) +
        (creatinineMgDl < 2.0 ? 1 : 0);
  }

  static double ipssR({
    required int cytogeneticPoints,
    required double boneMarrowBlastsPercent,
    required double hemoglobinGDl,
    required double plateletsX109L,
    required double ancX109L,
  }) {
    if (cytogeneticPoints < 0 ||
        cytogeneticPoints > 4 ||
        boneMarrowBlastsPercent < 0 ||
        boneMarrowBlastsPercent > 100 ||
        hemoglobinGDl < 0 ||
        plateletsX109L < 0 ||
        ancX109L < 0) {
      throw ArgumentError('Invalid IPSS-R input.');
    }
    var score = cytogeneticPoints.toDouble();
    if (boneMarrowBlastsPercent > 10) {
      score += 3;
    } else if (boneMarrowBlastsPercent >= 5) {
      score += 2;
    } else if (boneMarrowBlastsPercent > 2) {
      score += 1;
    }
    if (hemoglobinGDl < 8) {
      score += 1.5;
    } else if (hemoglobinGDl < 10) {
      score += 1;
    }
    if (plateletsX109L < 50) {
      score += 1;
    } else if (plateletsX109L < 100) {
      score += 0.5;
    }
    if (ancX109L < 0.8) score += 0.5;
    return score;
  }

  static ({int total, int qualityOfLife}) ipssProstate({
    required List<int> sevenSymptoms,
    required int qualityOfLife,
  }) {
    if (sevenSymptoms.length != 7)
      throw ArgumentError('IPSS requires 7 symptom items.');
    for (final value in sevenSymptoms) {
      if (value < 0 || value > 5)
        throw ArgumentError.value(value, 'sevenSymptoms');
    }
    if (qualityOfLife < 0 || qualityOfLife > 6)
      throw ArgumentError.value(qualityOfLife, 'qualityOfLife');
    return (
      total: sevenSymptoms.fold<int>(0, (a, b) => a + b),
      qualityOfLife: qualityOfLife,
    );
  }

  static ({int gleason, int gradeGroup}) gleasonIsup({
    required int primaryPattern,
    required int secondaryPattern,
  }) {
    if (primaryPattern < 3 ||
        primaryPattern > 5 ||
        secondaryPattern < 3 ||
        secondaryPattern > 5) {
      throw ArgumentError(
          'Gleason patterns must be pathology-assigned patterns 3–5.');
    }
    final sum = primaryPattern + secondaryPattern;
    int group;
    if (sum <= 6) {
      group = 1;
    } else if (primaryPattern == 3 && secondaryPattern == 4) {
      group = 2;
    } else if (primaryPattern == 4 && secondaryPattern == 3) {
      group = 3;
    } else if (sum == 8) {
      group = 4;
    } else {
      group = 5;
    }
    return (gleason: sum, gradeGroup: group);
  }

  static String bosniak2019({
    required bool enhancingNodule,
    required bool irregularEnhancingWallOrSepta,
    required bool thickEnhancingWallOrSepta4MmOrMore,
    required bool minimallyThickenedEnhancingWallOrSepta3Mm,
    required int enhancingSeptaCount,
    required bool simpleThinWallFluidMass,
    required bool heterogeneousT1HyperintenseNonenhancingMri,
  }) {
    if (enhancingSeptaCount < 0 || enhancingSeptaCount > 30) {
      throw ArgumentError.value(enhancingSeptaCount, 'enhancingSeptaCount');
    }
    if (enhancingNodule) return 'IV';
    if (irregularEnhancingWallOrSepta || thickEnhancingWallOrSepta4MmOrMore)
      return 'III';
    if (minimallyThickenedEnhancingWallOrSepta3Mm ||
        enhancingSeptaCount >= 4 ||
        heterogeneousT1HyperintenseNonenhancingMri) {
      return 'IIF';
    }
    if (simpleThinWallFluidMass && enhancingSeptaCount == 0) return 'I';
    return 'II';
  }

  static int snappe2({
    required double meanArterialPressure,
    required double lowestTemperatureC,
    required double pao2Fio2RatioUsingFio2Percent,
    required double lowestPh,
    required bool multipleSeizures,
    required double urineMlKgH,
    required int apgar5Minutes,
    required double birthWeightG,
    required bool smallForGestationalAgeBelow3rdPercentile,
  }) {
    if (meanArterialPressure < 0 ||
        lowestTemperatureC < 20 ||
        lowestTemperatureC > 45 ||
        pao2Fio2RatioUsingFio2Percent < 0 ||
        lowestPh < 5 ||
        lowestPh > 8 ||
        urineMlKgH < 0 ||
        apgar5Minutes < 0 ||
        apgar5Minutes > 10 ||
        birthWeightG < 0) {
      throw ArgumentError('Invalid SNAPPE-II input.');
    }
    var score = 0;
    if (meanArterialPressure < 20) {
      score += 19;
    } else if (meanArterialPressure < 30) {
      score += 9;
    }
    if (lowestTemperatureC < 35.0) {
      score += 15;
    } else if (lowestTemperatureC <= 35.6) {
      score += 8;
    }
    if (pao2Fio2RatioUsingFio2Percent < 0.3) {
      score += 28;
    } else if (pao2Fio2RatioUsingFio2Percent < 1.0) {
      score += 16;
    } else if (pao2Fio2RatioUsingFio2Percent < 2.5) {
      score += 5;
    }
    if (lowestPh < 7.1) {
      score += 16;
    } else if (lowestPh < 7.2) {
      score += 7;
    }
    if (multipleSeizures) score += 19;
    if (urineMlKgH < 0.1) {
      score += 18;
    } else if (urineMlKgH < 1.0) {
      score += 5;
    }
    if (apgar5Minutes < 7) score += 18;
    if (birthWeightG < 750) {
      score += 17;
    } else if (birthWeightG < 1000) {
      score += 10;
    }
    if (smallForGestationalAgeBelow3rdPercentile) score += 12;
    return score;
  }

  static int newBallardCompletedWeeks(int totalScore) {
    if (totalScore < -10 || totalScore > 50) {
      throw ArgumentError.value(totalScore, 'totalScore');
    }
    return (24.0 + 0.4 * totalScore).floor();
  }

  static String modifiedBell({
    required bool grossRectalBlood,
    required bool pneumatosisIntestinalis,
    required bool portalVenousGasOrAscites,
    required bool mildMetabolicAcidosisOrThrombocytopenia,
    required bool severeSystemicDeterioration,
    required bool pneumoperitoneum,
  }) {
    if (pneumoperitoneum) return 'IIIB';
    if (severeSystemicDeterioration) return 'IIIA';
    if (pneumatosisIntestinalis &&
        (portalVenousGasOrAscites || mildMetabolicAcidosisOrThrombocytopenia)) {
      return 'IIB';
    }
    if (pneumatosisIntestinalis) return 'IIA';
    if (grossRectalBlood) return 'IB';
    return 'IA';
  }
}
