import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/dkahhs/dkahhs_runtime_safety_contract.dart';

void main() {
  test('ORR001 fluid router fail-closed', () {
    DkahhsFluidRouteDecision r(
            DkahhsPregnancyStatus p, DkahhsHighRiskStatus h) =>
        DkahhsRuntimeSafetyContract.evaluateFluidRoute(
            pregnancyStatus: p, highRiskStatus: h);
    expect(r(DkahhsPregnancyStatus.unknown, DkahhsHighRiskStatus.notHighRisk),
        DkahhsFluidRouteDecision.blockedPregnancyUnknown);
    expect(r(DkahhsPregnancyStatus.pregnant, DkahhsHighRiskStatus.notHighRisk),
        DkahhsFluidRouteDecision.blockedPregnant);
    expect(r(DkahhsPregnancyStatus.notPregnant, DkahhsHighRiskStatus.unknown),
        DkahhsFluidRouteDecision.blockedHighRiskUnknown);
    expect(r(DkahhsPregnancyStatus.notPregnant, DkahhsHighRiskStatus.highRisk),
        DkahhsFluidRouteDecision.guardedHighRisk);
    final ok =
        r(DkahhsPregnancyStatus.notPregnant, DkahhsHighRiskStatus.notHighRisk);
    expect(ok, DkahhsFluidRouteDecision.routingPrerequisiteCleared);
    expect(DkahhsRuntimeSafetyContract.fluidRouteMessage(ok, spanish: false),
        contains('NÃO autoriza tratamento'));
  });
  test('ORR003 exact potassium boundary', () {
    DkahhsPotassiumGateDecision g(double? v,
            {bool verified = true,
            bool? current = true,
            String unit = 'mmol/L'}) =>
        DkahhsRuntimeSafetyContract.evaluatePotassiumGate(
            DkahhsPotassiumObservation(
                value: v, unit: unit, verified: verified, isCurrent: current));
    expect(DkahhsRuntimeSafetyContract.evaluatePotassiumGate(null),
        DkahhsPotassiumGateDecision.blockedMissing);
    expect(
        g(4, verified: false), DkahhsPotassiumGateDecision.blockedUnverified);
    expect(g(4, current: null),
        DkahhsPotassiumGateDecision.blockedCurrentnessUnknown);
    expect(g(4, current: false), DkahhsPotassiumGateDecision.blockedStale);
    expect(g(4, unit: 'mg/dL'), DkahhsPotassiumGateDecision.blockedInvalidUnit);
    expect(g(3.49), DkahhsPotassiumGateDecision.blockedAtOrBelow3_5);
    expect(g(3.50), DkahhsPotassiumGateDecision.blockedAtOrBelow3_5);
    final ok = g(3.51);
    expect(ok, DkahhsPotassiumGateDecision.prerequisiteCleared);
    expect(DkahhsRuntimeSafetyContract.potassiumGateMessage(ok, spanish: false),
        contains('NÃO inicia'));
  });
}
