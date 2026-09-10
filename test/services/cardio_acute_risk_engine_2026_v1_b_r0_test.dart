import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/cardio/cardio_acute_risk_engine_2026.dart';

void main() {
  test('HEART boundaries: 0 and 10', () {
    final low = CardioAcuteRiskEngine2026.heart(
      const HeartScoreInput(
        historyPoints: 0,
        ecgPoints: 0,
        ageYears: 30,
        riskFactorCount: 0,
        knownAtheroscleroticDisease: false,
        troponinPoints: 0,
      ),
    );
    final high = CardioAcuteRiskEngine2026.heart(
      const HeartScoreInput(
        historyPoints: 2,
        ecgPoints: 2,
        ageYears: 70,
        riskFactorCount: 3,
        knownAtheroscleroticDisease: true,
        troponinPoints: 2,
      ),
    );
    expect(low.score, 0);
    expect(low.bandPt, 'Baixo');
    expect(high.score, 10);
    expect(high.bandPt, 'Alto');
  });

  test('TIMI UA/NSTEMI boundaries: 0 and 7', () {
    final low = CardioAcuteRiskEngine2026.timiUaNstemi(
      const TimiUaNstemiInput(
        age65OrMore: false,
        threeOrMoreCadRiskFactors: false,
        knownCadStenosis50OrMore: false,
        aspirinWithin7Days: false,
        twoOrMoreAnginaEpisodes24h: false,
        stDeviation: false,
        elevatedCardiacMarkers: false,
      ),
    );
    final high = CardioAcuteRiskEngine2026.timiUaNstemi(
      const TimiUaNstemiInput(
        age65OrMore: true,
        threeOrMoreCadRiskFactors: true,
        knownCadStenosis50OrMore: true,
        aspirinWithin7Days: true,
        twoOrMoreAnginaEpisodes24h: true,
        stDeviation: true,
        elevatedCardiacMarkers: true,
      ),
    );
    expect(low.score, 0);
    expect(high.score, 7);
    expect(high.bandEs, 'Rango 5–7');
  });

  test('GRACE original point table low example', () {
    final result = CardioAcuteRiskEngine2026.graceAdmission(
      const GraceAdmissionInput(
        ageYears: 40,
        heartRateBpm: 60,
        systolicBpMmHg: 130,
        creatinineMgDl: 1.0,
        killipClass: 1,
        cardiacArrestAtAdmission: false,
        stSegmentDeviation: false,
        elevatedCardiacMarkers: false,
      ),
    );
    // age 25 + HR 3 + SBP 34 + Cr 7 = 69.
    expect(result.points, 69);
    expect(result.bandPt, 'Baixo');
    expect(result.escHighRiskAbove140, isFalse);
  });

  test('GRACE >140 current ESC high-risk threshold', () {
    final result = CardioAcuteRiskEngine2026.graceAdmission(
      const GraceAdmissionInput(
        ageYears: 80,
        heartRateBpm: 150,
        systolicBpMmHg: 90,
        creatinineMgDl: 2.5,
        killipClass: 3,
        cardiacArrestAtAdmission: true,
        stSegmentDeviation: true,
        elevatedCardiacMarkers: true,
      ),
    );
    // 91 + 38 + 53 + 21 + 39 + 39 + 28 + 14 = 323.
    expect(result.points, 323);
    expect(result.escHighRiskAbove140, isTrue);
    expect(result.bandEs, 'Alto');
  });

  test('GRACE point-table boundaries are deterministic', () {
    expect(
      CardioAcuteRiskEngine2026.graceAdmission(
        const GraceAdmissionInput(
          ageYears: 90,
          heartRateBpm: 200,
          systolicBpMmHg: 200,
          creatinineMgDl: 4,
          killipClass: 4,
          cardiacArrestAtAdmission: false,
          stSegmentDeviation: false,
          elevatedCardiacMarkers: false,
        ),
      ).points,
      100 + 46 + 0 + 28 + 59,
    );
  });

  test('Killip I–IV semantics are distinct', () {
    expect(CardioAcuteRiskEngine2026.killip(1).labelPt, 'Killip I');
    expect(
      CardioAcuteRiskEngine2026.killip(3).meaningEs,
      contains('Edema'),
    );
    expect(
      CardioAcuteRiskEngine2026.killip(4).meaningPt,
      contains('Choque'),
    );
  });

  test('guideline matrix pins current MedCases audit context', () {
    expect(CardioAcuteGuidelineMatrix2026.acsUs, contains('2025'));
    expect(CardioAcuteGuidelineMatrix2026.acsEsc, contains('2023'));
    expect(CardioAcuteGuidelineMatrix2026.chestPain, contains('2022'));
    expect(CardioAcuteGuidelineMatrix2026.grace2, contains('GRACE 2.0'));
  });
}
