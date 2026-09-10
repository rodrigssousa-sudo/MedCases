import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/hepato/hepato_score_engine_2026.dart';

void main() {
  test('MELD 3.0 matches official formula reference vector', () {
    final r = HepatoScoreEngine2026.meld30(
      bilirubinMgDl: 3,
      inr: 1.8,
      creatinineMgDl: 1.2,
      sodiumMmolL: 132,
      albuminGDl: 2.8,
      female: false,
    );
    expect(r.rawScore, closeTo(23.5568263023, 1e-8));
    expect(r.score, 24);
  });

  test('MELD 3.0 applies OPTN bounds and dialysis creatinine rule', () {
    final r = HepatoScoreEngine2026.meld30(
      bilirubinMgDl: 0.5,
      inr: 0.8,
      creatinineMgDl: 0.7,
      sodiumMmolL: 145,
      albuminGDl: 4.2,
      female: false,
      dialysisCriterionLast7Days: true,
    );
    expect(r.bilirubinUsed, 1);
    expect(r.inrUsed, 1);
    expect(r.creatinineUsed, 3);
    expect(r.sodiumUsed, 137);
    expect(r.albuminUsed, 3.5);
    expect(r.score, inInclusiveRange(6, 40));
  });

  test('Child-Pugh classification is deterministic', () {
    final r = HepatoScoreEngine2026.childPugh(
      bilirubinMgDl: 3.5,
      albuminGDl: 2.6,
      inr: 2.4,
      ascites: ChildAscites.mild,
      encephalopathy: ChildEncephalopathy.grade12,
    );
    expect(r.score, 13);
    expect(r.childClass, 'C');
  });

  test('FIB-4 exact arithmetic', () {
    final r = HepatoScoreEngine2026.fib4(
      ageYears: 50,
      astUL: 80,
      altUL: 60,
      platelets10e9L: 150,
    );
    expect(r, closeTo(3.4426518633, 1e-9));
  });

  test('Maddrey mDF exact arithmetic', () {
    final r = HepatoScoreEngine2026.maddreyDiscriminantFunction(
      patientPtSeconds: 20,
      controlPtSeconds: 12,
      bilirubinMgDl: 3,
    );
    expect(r, closeTo(39.8, 1e-12));
  });

  test('Lille day 7 reference vector is deterministic', () {
    final r = HepatoScoreEngine2026.lille(
      ageYears: 50,
      albuminDay0GDl: 3.0,
      bilirubinDay0MgDl: 300 / 17.1,
      bilirubinFollowUpMgDl: 200 / 17.1,
      creatinineMgDl: 1.0,
      prothrombinTimeSeconds: 20,
      followUpDay: 7,
    );
    expect(r.score, closeTo(0.11324651826, 1e-9));
    expect(r.nonResponder, isFalse);
  });

  test('Lille identifies nonresponse above 0.45', () {
    final r = HepatoScoreEngine2026.lille(
      ageYears: 50,
      albuminDay0GDl: 3.0,
      bilirubinDay0MgDl: 300 / 17.1,
      bilirubinFollowUpMgDl: 350 / 17.1,
      creatinineMgDl: 1.0,
      prothrombinTimeSeconds: 20,
      followUpDay: 7,
    );
    expect(r.score, greaterThanOrEqualTo(0.45));
    expect(r.nonResponder, isTrue);
  });
}
