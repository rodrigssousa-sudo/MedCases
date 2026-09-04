enum DkahhsPregnancyStatus { unknown, notPregnant, pregnant }

enum DkahhsHighRiskStatus { unknown, notHighRisk, highRisk }

enum DkahhsFluidRouteDecision {
  blockedPregnancyUnknown,
  blockedPregnant,
  blockedHighRiskUnknown,
  guardedHighRisk,
  routingPrerequisiteCleared
}

enum DkahhsPotassiumGateDecision {
  blockedMissing,
  blockedInvalidUnit,
  blockedUnverified,
  blockedCurrentnessUnknown,
  blockedStale,
  blockedAtOrBelow3_5,
  prerequisiteCleared
}

enum DkahhsGlucoseDeclineState {
  invalid,
  rising,
  belowSafetyBand,
  upperSafetyBand,
  aboveUpperSafetyBand
}

class DkahhsPotassiumObservation {
  final double? value;
  final String unit;
  final bool verified;
  final bool? isCurrent;
  const DkahhsPotassiumObservation(
      {required this.value,
      required this.unit,
      required this.verified,
      required this.isCurrent});
}

class DkahhsGlucoseSample {
  final double? value;
  final String unit;
  final DateTime? measuredAt;
  final bool verified;
  const DkahhsGlucoseSample(
      {required this.value,
      required this.unit,
      required this.measuredAt,
      required this.verified});
}

class DkahhsGlucoseDeclineAssessment {
  final DkahhsGlucoseDeclineState state;
  final double? rateMgDlPerHour;
  final String reason;
  const DkahhsGlucoseDeclineAssessment(
      {required this.state,
      required this.rateMgDlPerHour,
      required this.reason});
  bool get valid => state != DkahhsGlucoseDeclineState.invalid;
}

class DkahhsRuntimeSafetyContract {
  DkahhsRuntimeSafetyContract._();
  static DkahhsFluidRouteDecision evaluateFluidRoute(
      {required DkahhsPregnancyStatus pregnancyStatus,
      required DkahhsHighRiskStatus highRiskStatus}) {
    if (pregnancyStatus == DkahhsPregnancyStatus.unknown)
      return DkahhsFluidRouteDecision.blockedPregnancyUnknown;
    if (pregnancyStatus == DkahhsPregnancyStatus.pregnant)
      return DkahhsFluidRouteDecision.blockedPregnant;
    if (highRiskStatus == DkahhsHighRiskStatus.unknown)
      return DkahhsFluidRouteDecision.blockedHighRiskUnknown;
    if (highRiskStatus == DkahhsHighRiskStatus.highRisk)
      return DkahhsFluidRouteDecision.guardedHighRisk;
    return DkahhsFluidRouteDecision.routingPrerequisiteCleared;
  }

  static DkahhsPotassiumGateDecision evaluatePotassiumGate(
      DkahhsPotassiumObservation? x) {
    if (x == null || x.value == null)
      return DkahhsPotassiumGateDecision.blockedMissing;
    if (!_kUnit(x.unit)) return DkahhsPotassiumGateDecision.blockedInvalidUnit;
    if (!x.verified) return DkahhsPotassiumGateDecision.blockedUnverified;
    if (x.isCurrent == null)
      return DkahhsPotassiumGateDecision.blockedCurrentnessUnknown;
    if (x.isCurrent == false) return DkahhsPotassiumGateDecision.blockedStale;
    if (x.value! <= 3.5) return DkahhsPotassiumGateDecision.blockedAtOrBelow3_5;
    return DkahhsPotassiumGateDecision.prerequisiteCleared;
  }

  static DkahhsGlucoseDeclineAssessment assessGlucoseDecline(
      {required DkahhsGlucoseSample? previous,
      required DkahhsGlucoseSample? current}) {
    if (previous == null ||
        current == null ||
        previous.value == null ||
        current.value == null ||
        previous.measuredAt == null ||
        current.measuredAt == null)
      return const DkahhsGlucoseDeclineAssessment(
          state: DkahhsGlucoseDeclineState.invalid,
          rateMgDlPerHour: null,
          reason: 'missing_value_or_timestamp');
    if (!previous.verified || !current.verified)
      return const DkahhsGlucoseDeclineAssessment(
          state: DkahhsGlucoseDeclineState.invalid,
          rateMgDlPerHour: null,
          reason: 'unverified_sample');
    if (!_gUnit(previous.unit) || !_gUnit(current.unit))
      return const DkahhsGlucoseDeclineAssessment(
          state: DkahhsGlucoseDeclineState.invalid,
          rateMgDlPerHour: null,
          reason: 'invalid_unit');
    final us =
        current.measuredAt!.difference(previous.measuredAt!).inMicroseconds;
    if (us <= 0)
      return const DkahhsGlucoseDeclineAssessment(
          state: DkahhsGlucoseDeclineState.invalid,
          rateMgDlPerHour: null,
          reason: 'non_positive_elapsed_time');
    final rate = (previous.value! - current.value!) / (us / 3600000000.0);
    if (rate < 0)
      return DkahhsGlucoseDeclineAssessment(
          state: DkahhsGlucoseDeclineState.rising,
          rateMgDlPerHour: rate,
          reason: 'signed_negative_decline');
    if (rate > 120)
      return DkahhsGlucoseDeclineAssessment(
          state: DkahhsGlucoseDeclineState.aboveUpperSafetyBand,
          rateMgDlPerHour: rate,
          reason: 'reassessment_only');
    if (rate >= 90)
      return DkahhsGlucoseDeclineAssessment(
          state: DkahhsGlucoseDeclineState.upperSafetyBand,
          rateMgDlPerHour: rate,
          reason: 'upper_safety_band_not_target');
    return DkahhsGlucoseDeclineAssessment(
        state: DkahhsGlucoseDeclineState.belowSafetyBand,
        rateMgDlPerHour: rate,
        reason: 'below_upper_safety_band');
  }

  static bool isScAlternativeRequest(String text) {
    final n = _fold(text);
    final d = RegExp(r'(^|\W)(cad|dka|hhs|ehh)(\W|$)').hasMatch(n) ||
        n.contains('cetoacid') ||
        n.contains('estado hiperosmolar');
    final sc = RegExp(r'(^|\W)sc(\W|$)').hasMatch(n) ||
        n.contains('subcut') ||
        n.contains('via sc');
    return d && sc;
  }

  static String fluidRouteMessage(DkahhsFluidRouteDecision d,
      {required bool spanish}) {
    if (d == DkahhsFluidRouteDecision.routingPrerequisiteCleared)
      return spanish
          ? 'RUTEO DE FLUIDOS: no gestante + no alto riesgo confirmados → libera solo este prerrequisito; NO autoriza tratamiento.'
          : 'ROTEAMENTO DE FLUIDOS: não gestante + não alto risco confirmados → libera somente este pré-requisito; NÃO autoriza tratamento.';
    if (d == DkahhsFluidRouteDecision.guardedHighRisk)
      return spanish
          ? 'RUTEO DE FLUIDOS: alto riesgo confirmado → flujo protegido separado; no vía estándar automática.'
          : 'ROTEAMENTO DE FLUIDOS: alto risco confirmado → fluxo protegido separado; sem via padrão automática.';
    return spanish
        ? 'RUTEO DE FLUIDOS BLOQUEADO: embarazo/riesgo no permite selección automática de la vía estándar.'
        : 'ROTEAMENTO DE FLUIDOS BLOQUEADO: gravidez/risco não permite seleção automática da via padrão.';
  }

  static String potassiumGateMessage(DkahhsPotassiumGateDecision d,
      {required bool spanish}) {
    if (d == DkahhsPotassiumGateDecision.prerequisiteCleared)
      return spanish
          ? 'POTASIO: K+ actual y confirmado >3,5 mmol/L → libera solo el prerrequisito; NO inicia ni define dosis de insulina.'
          : 'POTÁSSIO: K+ atual e confirmado >3,5 mmol/L → libera somente o pré-requisito; NÃO inicia nem define dose de insulina.';
    return spanish
        ? 'HARD STOP POTASIO: K+ ausente/no verificado/no actual/desactualizado/≤3,5 o unidad inválida → prerrequisito bloqueado.'
        : 'HARD STOP POTÁSSIO: K+ ausente/não verificado/não atual/desatualizado/≤3,5 ou unidade inválida → pré-requisito bloqueado.';
  }

  static String glucoseDeclineMessage(DkahhsGlucoseDeclineAssessment a,
      {required bool spanish}) {
    if (!a.valid)
      return spanish
          ? 'MONITOREO GLUCÉMICO: inválido sin valores verificados mg/dL + timestamps reales y tiempo positivo.'
          : 'MONITORAMENTO GLICÊMICO: inválido sem valores verificados em mg/dL + timestamps reais e tempo positivo.';
    final r = a.rateMgDlPerHour!.toStringAsFixed(1);
    if (a.state == DkahhsGlucoseDeclineState.aboveUpperSafetyBand)
      return spanish
          ? 'MONITOREO: $r mg/dL/h >120 → reevaluar; NO cambio automático de insulina/fluidos.'
          : 'MONITORAMENTO: $r mg/dL/h >120 → reavaliar; SEM alteração automática de insulina/fluidos.';
    return spanish
        ? 'MONITOREO: descenso firmado $r mg/dL/h; 90–120 es banda superior de seguridad, NO objetivo.'
        : 'MONITORAMENTO: queda assinada $r mg/dL/h; 90–120 é faixa superior de segurança, NÃO meta.';
  }

  static bool _kUnit(String u) {
    final x = _fold(u).replaceAll(' ', '');
    return x == 'mmol/l' || x == 'meq/l';
  }

  static bool _gUnit(String u) => _fold(u).replaceAll(' ', '') == 'mg/dl';
  static String _fold(String v) {
    var x = v.toLowerCase();
    const m = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n'
    };
    m.forEach((a, b) => x = x.replaceAll(a, b));
    return x;
  }
}
