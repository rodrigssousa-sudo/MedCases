import 'package:flutter_test/flutter_test.dart';
import '../../lib/screens/plus_scores_mb1_engine.dart';

void main() {
  group('PlusScores MB1 engine contracts', () {
    test('catalog exactly 26', () => expect(PlusScoresMb1Id.values.length, 26));
    test('YEARS', () {
      final r = PlusScoresMb1Engine.years(
          dvtSigns: false,
          hemoptysis: false,
          peMostLikely: false,
          dDimerNgMlFeu: 999);
      expect(r.criteria, 0);
      expect(r.cutoffNgMlFeu, 1000);
      expect(r.ruleOut, isTrue);
    });
    test('NIHSS',
        () => expect(PlusScoresMb1Engine.nihss(List<int>.filled(15, 0)), 0));
    test(
        'SOFA', () => expect(PlusScoresMb1Engine.sofa([1, 2, 3, 4, 0, 1]), 11));
    test(
        'qSOFA',
        () => expect(
            PlusScoresMb1Engine.qsofa(
                systolicBp: 95, respiratoryRate: 18, alteredMentalStatus: true),
            2));
    test(
        'CURB65',
        () => expect(
            PlusScoresMb1Engine.curb65(
                confusion: true,
                ureaMmolL: 8,
                respiratoryRate: 30,
                systolicBp: 89,
                diastolicBp: 70,
                ageYears: 64),
            4));
    test(
        'Alvarado',
        () => expect(
            PlusScoresMb1Engine.alvarado(
                migration: true,
                anorexia: true,
                nauseaVomiting: true,
                rlqTenderness: true,
                rebound: true,
                fever: true,
                leukocytosis: true,
                leftShift: true),
            10));
    test(
        'BISAP',
        () => expect(
            PlusScoresMb1Engine.bisap(
                bunMgDl: 26,
                gcs: 14,
                sirsAtLeast2: true,
                ageYears: 61,
                pleuralEffusion: true),
            5));
    test('Hinchey', () => expect(PlusScoresMb1Engine.hincheyStage(4), 4));
    test(
        'Silverman',
        () =>
            expect(PlusScoresMb1Engine.silvermanAndersen([2, 2, 2, 2, 2]), 10));
    test(
        'Westley',
        () => expect(
            PlusScoresMb1Engine.westley(
                stridor: 2,
                retractions: 3,
                airEntry: 2,
                cyanosis: 5,
                consciousness: 5),
            17));
    test(
        'PAS',
        () => expect(
            PlusScoresMb1Engine.pediatricAppendicitis(
                coughPercussionHopTenderness: true,
                anorexia: true,
                fever: true,
                nauseaVomiting: true,
                rlqTenderness: true,
                migration: true,
                leukocytosis: true,
                neutrophilia: true),
            10));
    test(
        'LRINEC',
        () => expect(
            PlusScoresMb1Engine.lrinec(
                crpMgL: 150,
                wbcK: 26,
                hemoglobinGDl: 10,
                sodiumMmolL: 134,
                creatinineMgDl: 1.7,
                glucoseMgDl: 181),
            13));
    test(
        'McIsaac',
        () => expect(
            PlusScoresMb1Engine.mcIsaac(
                feverOver38: true,
                absentCough: true,
                tenderAnteriorCervicalNodes: true,
                tonsillarExudateOrSwelling: true,
                ageBandPoints: 1),
            5));
    test(
        'Duke ISCVID',
        () => expect(
            PlusScoresMb1Engine.dukeIscvid2023(
                majorMicrobiology: true,
                majorImaging: true,
                majorSurgical: false,
                minorPredisposition: false,
                minorFever: false,
                minorVascular: false,
                minorImmunologic: false,
                minorMicrobiology: false,
                minorImaging: false,
                minorPhysicalExam: false),
            'definite'));
    test('Caprini',
        () => expect(PlusScoresMb1Engine.caprini2013([5, 3, 2, 1]), 11));
    test(
        'RCRI',
        () => expect(
            PlusScoresMb1Engine.rcri(
                highRiskSurgery: true,
                ischemicHeartDisease: true,
                heartFailure: true,
                cerebrovascularDisease: true,
                insulinTherapy: true,
                creatinineOver2: true),
            6));
    test(
        'Bishop',
        () => expect(
            PlusScoresMb1Engine.bishop(
                dilationPoints: 3,
                effacementPoints: 3,
                consistencyPoints: 2,
                positionPoints: 2,
                stationPoints: 3),
            13));
    test(
        'HELLP',
        () => expect(
            PlusScoresMb1Engine.hellpTennessee(
                ldhUL: 600,
                astUL: 70,
                plateletsPerMm3: 99999,
                indirectBilirubinMgDl: 1.2,
                schistocytesOrHemolysisEvidence: false),
            isTrue));
    test('ECOG', () => expect(PlusScoresMb1Engine.ecog(4), 4));
    test(
        'MASCC',
        () => expect(
            PlusScoresMb1Engine.mascc(
                burdenPoints: 5,
                noHypotension: true,
                noCopd: true,
                solidTumorOrHemeNoPriorFungal: true,
                noDehydration: true,
                outpatientOnset: true,
                ageUnder60: true),
            26));
    test('Ottawa ankle/foot', () {
      final r = PlusScoresMb1Engine.ottawaAnkleFoot(
          malleolarZonePain: true,
          midfootZonePain: false,
          posteriorLateralMalleolusTenderness: true,
          posteriorMedialMalleolusTenderness: false,
          fifthMetatarsalTenderness: false,
          navicularTenderness: false,
          unableFourSteps: false);
      expect(r.ankleImaging, isTrue);
      expect(r.footImaging, isFalse);
    });
    test(
        'Ottawa knee',
        () => expect(
            PlusScoresMb1Engine.ottawaKnee(
                age55OrOlder: true,
                isolatedPatellarTenderness: false,
                fibularHeadTenderness: false,
                unableFlex90: false,
                unableFourSteps: false),
            isTrue));
    test(
        'NEXUS',
        () => expect(
            PlusScoresMb1Engine.nexusLowRisk(
                midlineTenderness: false,
                focalNeurologicDeficit: false,
                alteredAlertness: false,
                intoxication: false,
                distractingInjury: false),
            isTrue));
    test(
        'Canadian C-Spine',
        () => expect(
            PlusScoresMb1Engine.canadianCSpineNeedsImaging(
                applicableAlertStable: true,
                age65OrOlder: true,
                dangerousMechanism: false,
                extremityParesthesias: false,
                simpleRearEnd: true,
                sittingInEd: true,
                ambulatoryAnyTime: true,
                delayedNeckPain: false,
                noMidlineTenderness: true,
                canRotate45BothWays: true),
            isTrue));
    test('Gustilo', () => expect(PlusScoresMb1Engine.gustiloAnderson(5), 5));
    test(
        'MESS',
        () => expect(
            PlusScoresMb1Engine.mess(
                skeletalSoftTissuePoints: 4,
                limbIschemiaPoints: 3,
                ischemiaOver6Hours: true,
                shockPoints: 2,
                agePoints: 2),
            14));
  });
}
