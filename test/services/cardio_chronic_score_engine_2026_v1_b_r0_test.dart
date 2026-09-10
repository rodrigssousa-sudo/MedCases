import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/cardio/cardio_chronic_score_engine_2026.dart';

void main() {
  test('CHA2DS2-VA ranges from 0 to 8', () {
    final low = CardioChronicScoreEngine2026.cha2Ds2Va(
      ageYears: 40,
      heartFailure: false,
      hypertension: false,
      diabetes: false,
      priorStrokeTiaTe: false,
      vascularDisease: false,
    );
    expect(low.score, 0);

    final high = CardioChronicScoreEngine2026.cha2Ds2Va(
      ageYears: 80,
      heartFailure: true,
      hypertension: true,
      diabetes: true,
      priorStrokeTiaTe: true,
      vascularDisease: true,
    );
    expect(high.score, 8);
  });

  test('CHA2DS2-VASc adds female sex point in parallel model', () {
    final male = CardioChronicScoreEngine2026.cha2Ds2Vasc(
      ageYears: 40,
      femaleSex: false,
      heartFailure: false,
      hypertension: false,
      diabetes: false,
      priorStrokeTiaTe: false,
      vascularDisease: false,
    );
    final female = CardioChronicScoreEngine2026.cha2Ds2Vasc(
      ageYears: 40,
      femaleSex: true,
      heartFailure: false,
      hypertension: false,
      diabetes: false,
      priorStrokeTiaTe: false,
      vascularDisease: false,
    );
    expect(male.score, 0);
    expect(female.score, 1);
  });

  test('HAS-BLED supports full nine-point structure', () {
    final result = CardioChronicScoreEngine2026.hasBled(
      ageYears: 70,
      systolicBpMmHg: 170,
      abnormalRenalFunction: true,
      abnormalLiverFunction: true,
      priorStroke: true,
      bleedingHistoryOrPredisposition: true,
      labileInr: true,
      bleedingRiskDrugs: true,
      highAlcoholUse: true,
    );

    expect(result.score, 9);
    expect(result.hypertensionPoint, isTrue);
    expect(result.agePoint, isTrue);
  });

  test('QTc Bazett and Fridericia are deterministic', () {
    final bazett = CardioChronicScoreEngine2026.bazett(
      qtMs: 400,
      heartRateBpm: 60,
      femaleSex: false,
    );
    final fridericia = CardioChronicScoreEngine2026.fridericia(
      qtMs: 400,
      heartRateBpm: 60,
      femaleSex: false,
    );

    expect(bazett.milliseconds.round(), 400);
    expect(fridericia.milliseconds.round(), 400);
  });
}
