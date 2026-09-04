// MEDCASES PEDIATRIA — BRIGHTON PEWS
// Clinical source reconciliation: 2026-08-10.
//
// Algorithm:
// Monaghan A. Detecting and managing deterioration in children.
// Paediatr Nurs. 2005;17(1):32-35.
// DOI: 10.7748/paed2005.02.17.1.32.c964
//
// Criteria reproduced/validated in:
// Duraisamy R, et al. Validation of Brighton pediatric early warning
// score for predicting clinical deterioration in the emergency department.
// Indian J Child Health. 2021;8(6):211-215.
// DOI: 10.32677/IJCH.2021.v08.i06.003
//
// This engine is an early-warning aid. Escalation thresholds must be
// interpreted with the local institutional response protocol and clinical
// judgement.

class BrightonPewsResultV2026 {
  final int total;
  final String interpretationPt;
  final String interpretationEs;

  const BrightonPewsResultV2026({
    required this.total,
    required this.interpretationPt,
    required this.interpretationEs,
  });
}

class BrightonPewsEngineV2026 {
  BrightonPewsEngineV2026._();

  static BrightonPewsResultV2026 calculate({
    required int behavior,
    required int cardiovascular,
    required int respiratory,
    required bool quarterHourlyNebulizer,
    required bool persistentPostOpVomiting,
  }) {
    for (final value in [behavior, cardiovascular, respiratory]) {
      if (value < 0 || value > 3) {
        throw ArgumentError.value(
          value,
          'PEWS component',
          'must be between 0 and 3',
        );
      }
    }

    final total = behavior +
        cardiovascular +
        respiratory +
        (quarterHourlyNebulizer ? 2 : 0) +
        (persistentPostOpVomiting ? 2 : 0);

    final (pt, es) = _interpretation(total);
    return BrightonPewsResultV2026(
      total: total,
      interpretationPt: pt,
      interpretationEs: es,
    );
  }

  static (String, String) _interpretation(int score) {
    if (score <= 1) {
      return (
        'Baixa pontuação isolada — manter avaliação clínica e tendência.',
        'Puntuación aislada baja — mantener evaluación clínica y tendencia.',
      );
    }
    if (score <= 3) {
      return (
        'PEWS elevado — reavaliar e intensificar monitorização conforme protocolo local.',
        'PEWS elevado — reevaluar e intensificar monitorización según protocolo local.',
      );
    }
    return (
      'PEWS ≥4 — alto risco de deterioração; avaliação clínica urgente e protocolo local de escalada.',
      'PEWS ≥4 — alto riesgo de deterioro; evaluación clínica urgente y protocolo local de escalada.',
    );
  }
}
