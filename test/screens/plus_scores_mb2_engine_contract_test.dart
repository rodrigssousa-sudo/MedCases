import 'package:flutter_test/flutter_test.dart';
import '../../lib/screens/plus_scores_mb2_engine.dart';

void main() {
  group('PlusScores MB2 engine contracts', () {
    test('catalog exactly 25', () {
      expect(PlusScoresMb2Id.values.length, 25);
    });

    test('PHQ-9 max', () {
      expect(PlusScoresMb2Engine.phq9(List<int>.filled(9, 3)), 27);
    });

    test('SAD PERSONS historical checklist only sums items', () {
      expect(
        PlusScoresMb2Engine.sadPersonsHistorical([
          true,
          false,
          true,
          false,
          true,
          false,
          true,
          false,
          true,
          false,
        ]),
        5,
      );
    });

    test('FINDRISC max vector', () {
      expect(
        PlusScoresMb2Engine.findrisc(
          ageYears: 70,
          bmi: 32,
          waistCm: 110,
          female: false,
          physicalActivity30MinDaily: false,
          dailyFruitVegetables: false,
          antihypertensiveMedication: true,
          priorHighGlucose: true,
          familyHistoryPoints: 5,
        ),
        26,
      );
    });

    test('Burch-Wartofsky severe vector', () {
      expect(
        PlusScoresMb2Engine.burchWartofsky(
          temperatureC: 40,
          heartRate: 145,
          giHepaticPoints: 20,
          cnsPoints: 30,
          chfPoints: 15,
          atrialFibrillation: true,
          precipitatingEvent: true,
        ),
        140,
      );
    });

    test('RTS normal physiology approaches maximum', () {
      final r = PlusScoresMb2Engine.revisedTraumaScore(
        gcs: 15,
        systolicBp: 120,
        respiratoryRate: 16,
      );
      expect(r.gcsCode, 4);
      expect(r.sbpCode, 4);
      expect(r.rrCode, 4);
      expect(r.weighted, closeTo(7.8408, 0.0001));
    });

    test('ISS and AIS 6 override', () {
      expect(
        PlusScoresMb2Engine.injurySeverityScore(
          topAisRegion1: 4,
          topAisRegion2: 3,
          topAisRegion3: 2,
        ),
        29,
      );
      expect(
        PlusScoresMb2Engine.injurySeverityScore(
          topAisRegion1: 6,
          topAisRegion2: 1,
          topAisRegion3: 1,
        ),
        75,
      );
    });

    test('ATLS hemorrhagic shock classes', () {
      expect(PlusScoresMb2Engine.atlsHemorrhagicShockClass(10), 1);
      expect(PlusScoresMb2Engine.atlsHemorrhagicShockClass(20), 2);
      expect(PlusScoresMb2Engine.atlsHemorrhagicShockClass(35), 3);
      expect(PlusScoresMb2Engine.atlsHemorrhagicShockClass(45), 4);
    });

    test('DAS28 ESR and CRP are finite', () {
      final esr = PlusScoresMb2Engine.das28Esr(
        tenderJointCount28: 10,
        swollenJointCount28: 5,
        esrMmH: 30,
        patientGlobalMm: 50,
      );
      final crp = PlusScoresMb2Engine.das28Crp(
        tenderJointCount28: 10,
        swollenJointCount28: 5,
        crpMgL: 10,
        patientGlobalMm: 50,
      );
      expect(esr.isFinite, isTrue);
      expect(crp.isFinite, isTrue);
    });

    test('SLEDAI-2K weighted maximum vector', () {
      expect(
        PlusScoresMb2Engine.sledai2k(
          weight8: List<bool>.filled(8, true),
          weight4: List<bool>.filled(6, true),
          weight2: List<bool>.filled(7, true),
          weight1: List<bool>.filled(3, true),
        ),
        105,
      );
    });

    test('BASDAI formula', () {
      expect(
        PlusScoresMb2Engine.basdai([4, 4, 4, 4, 4, 4]),
        closeTo(4, 0.0001),
      );
    });

    test('Beighton', () {
      expect(PlusScoresMb2Engine.beighton(List<bool>.filled(9, true)), 9);
    });

    test('Katz ADL', () {
      expect(PlusScoresMb2Engine.katzAdl(List<bool>.filled(6, true)), 6);
    });

    test('Lawton-Brody', () {
      expect(PlusScoresMb2Engine.lawtonBrody(List<bool>.filled(8, true)), 8);
    });

    test('MMSE record only validates total', () {
      expect(PlusScoresMb2Engine.mmseRecord(27), 27);
    });

    test('ISTH overt DIC 2025 max vector', () {
      expect(
        PlusScoresMb2Engine.isthDic2025(
          plateletsX109L: 40,
          dDimerTimesUln: 8,
          ptProlongationSeconds: 7,
          fibrinogenMgDl: 90,
        ),
        8,
      );
    });

    test('4Ts max', () {
      expect(
        PlusScoresMb2Engine.fourTs(
          thrombocytopenia: 2,
          timing: 2,
          thrombosis: 2,
          otherCauses: 2,
        ),
        8,
      );
    });

    test('PLASMIC max', () {
      expect(
        PlusScoresMb2Engine.plasmic(
          plateletsX109L: 20,
          hemolysis: true,
          noActiveCancer: true,
          noSolidOrganOrStemCellTransplant: true,
          mcvFl: 85,
          inr: 1.2,
          creatinineMgDl: 1.5,
        ),
        7,
      );
    });

    test('IPSS-R representative vector', () {
      final score = PlusScoresMb2Engine.ipssR(
        cytogeneticPoints: 2,
        boneMarrowBlastsPercent: 6,
        hemoglobinGDl: 9,
        plateletsX109L: 70,
        ancX109L: 0.7,
      );
      expect(score, 6.0);
    });

    test('IPSS prostate max symptoms', () {
      final r = PlusScoresMb2Engine.ipssProstate(
        sevenSymptoms: List<int>.filled(7, 5),
        qualityOfLife: 6,
      );
      expect(r.total, 35);
      expect(r.qualityOfLife, 6);
    });

    test('Gleason ISUP conversion', () {
      expect(
        PlusScoresMb2Engine.gleasonIsup(
          primaryPattern: 3,
          secondaryPattern: 4,
        ).gradeGroup,
        2,
      );
      expect(
        PlusScoresMb2Engine.gleasonIsup(
          primaryPattern: 4,
          secondaryPattern: 3,
        ).gradeGroup,
        3,
      );
      expect(
        PlusScoresMb2Engine.gleasonIsup(
          primaryPattern: 5,
          secondaryPattern: 5,
        ).gradeGroup,
        5,
      );
    });

    test('Bosniak v2019 priority', () {
      expect(
        PlusScoresMb2Engine.bosniak2019(
          enhancingNodule: true,
          irregularEnhancingWallOrSepta: true,
          thickEnhancingWallOrSepta4MmOrMore: true,
          minimallyThickenedEnhancingWallOrSepta3Mm: true,
          enhancingSeptaCount: 8,
          simpleThinWallFluidMass: false,
          heterogeneousT1HyperintenseNonenhancingMri: false,
        ),
        'IV',
      );
    });

    test('SNAPPE-II max-vector components', () {
      final score = PlusScoresMb2Engine.snappe2(
        meanArterialPressure: 15,
        lowestTemperatureC: 34,
        pao2Fio2RatioUsingFio2Percent: 0.2,
        lowestPh: 7.0,
        multipleSeizures: true,
        urineMlKgH: 0.05,
        apgar5Minutes: 5,
        birthWeightG: 700,
        smallForGestationalAgeBelow3rdPercentile: true,
      );
      expect(score, 162);
    });

    test('New Ballard conversion endpoints', () {
      expect(PlusScoresMb2Engine.newBallardCompletedWeeks(-10), 20);
      expect(PlusScoresMb2Engine.newBallardCompletedWeeks(50), 44);
    });

    test('Modified Bell hierarchy', () {
      expect(
        PlusScoresMb2Engine.modifiedBell(
          grossRectalBlood: true,
          pneumatosisIntestinalis: true,
          portalVenousGasOrAscites: true,
          mildMetabolicAcidosisOrThrombocytopenia: true,
          severeSystemicDeterioration: true,
          pneumoperitoneum: true,
        ),
        'IIIB',
      );
    });
  });
}
