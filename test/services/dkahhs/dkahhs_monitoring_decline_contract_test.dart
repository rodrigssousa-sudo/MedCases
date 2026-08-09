import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/dkahhs/dkahhs_runtime_safety_contract.dart';

void main() {
  DkahhsGlucoseDeclineAssessment a(double? p, double? c, Duration d,
      {String unit = 'mg/dL', bool verified = true}) {
    final t = DateTime.utc(2026, 8, 9);
    return DkahhsRuntimeSafetyContract.assessGlucoseDecline(
        previous: DkahhsGlucoseSample(
            value: p, unit: unit, measuredAt: t, verified: verified),
        current: DkahhsGlucoseSample(
            value: c, unit: unit, measuredAt: t.add(d), verified: verified));
  }

  test('ORR017 actual timestamps and safety band', () {
    expect(a(600, 555, const Duration(minutes: 30)).rateMgDlPerHour,
        closeTo(90, 1e-9));
    expect(a(600, 510, const Duration(minutes: 45)).state,
        DkahhsGlucoseDeclineState.upperSafetyBand);
    final fast = a(600, 500, const Duration(minutes: 45));
    expect(fast.state, DkahhsGlucoseDeclineState.aboveUpperSafetyBand);
    expect(
        DkahhsRuntimeSafetyContract.glucoseDeclineMessage(fast, spanish: false),
        contains('SEM alteração automática'));
    final rising = a(600, 620, const Duration(minutes: 30));
    expect(rising.rateMgDlPerHour, closeTo(-40, 1e-9));
    expect(rising.state, DkahhsGlucoseDeclineState.rising);
    expect(a(600, 550, Duration.zero).state, DkahhsGlucoseDeclineState.invalid);
    expect(a(600, 550, const Duration(minutes: -1)).state,
        DkahhsGlucoseDeclineState.invalid);
    expect(a(600, 550, const Duration(hours: 1), unit: 'mmol/L').state,
        DkahhsGlucoseDeclineState.invalid);
    expect(a(null, 550, const Duration(hours: 1)).state,
        DkahhsGlucoseDeclineState.invalid);
    expect(a(600, 550, const Duration(hours: 1), verified: false).state,
        DkahhsGlucoseDeclineState.invalid);
  });
}
