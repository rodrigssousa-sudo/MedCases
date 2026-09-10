import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/nephro/nephro_score_engine_2026.dart';

void main() {
  test('CKD-EPI 2021 matches known reference example behavior', () {
    final egfr = NephroScoreEngine2026.ckdEpi2021Creatinine(
      ageYears: 60,
      female: false,
      serumCreatinineMgDl: 1.0,
    );
    expect(egfr, greaterThan(80));
    expect(egfr, lessThan(100));
  });

  test('KDIGO G/A categories are deterministic', () {
    expect(
      NephroScoreEngine2026.ckdGa(egfrMlMin173: 92, acrMgG: 10).combined,
      'G1A1',
    );
    expect(
      NephroScoreEngine2026.ckdGa(egfrMlMin173: 50, acrMgG: 100).combined,
      'G3aA2',
    );
    expect(
      NephroScoreEngine2026.ckdGa(egfrMlMin173: 12, acrMgG: 500).combined,
      'G5A3',
    );
  });

  test('KFRE 4-variable returns sensible 2y and 5y ordering', () {
    final r = NephroScoreEngine2026.kfre4(
      ageYears: 55,
      male: true,
      egfrMlMin173: 30,
      acrMgG: 300,
      calibration: KfreCalibration.northAmerica,
    );
    expect(r.risk2YearPercent, closeTo(9.6, 0.6));
    expect(r.risk5YearPercent, closeTo(27.0, 1.0));
    expect(r.risk5YearPercent, greaterThan(r.risk2YearPercent));
  });

  test('KDIGO AKI uses worst of creatinine and urine criteria', () {
    final r = NephroScoreEngine2026.kdigoAki(
      baselineCreatinineMgDl: 1,
      currentCreatinineMgDl: 1.6,
      creatinineRiseAtLeast03Within48h: true,
      urineMlKgH: 0.2,
      urineDurationHours: 24,
    );
    expect(r.creatinineStage, 1);
    expect(r.urineStage, 3);
    expect(r.stage, 3);
  });

  test('FENa and FEUrea are deterministic', () {
    final fena = NephroScoreEngine2026.fenaPercent(
      urineSodium: 20,
      plasmaSodium: 140,
      urineCreatinine: 100,
      plasmaCreatinine: 2,
    );
    expect(fena, closeTo(0.2857, 0.001));

    final feu = NephroScoreEngine2026.feUreaPercent(
      urineUrea: 300,
      plasmaUrea: 80,
      urineCreatinine: 100,
      plasmaCreatinine: 2,
    );
    expect(feu, closeTo(7.5, 0.01));
  });
}
