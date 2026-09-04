import '../contracts/plantao_evidence_bundle.dart';
import '../contracts/plantao_request.dart';

enum PlantaoProviderKind { gptPaid, geminiPaid }

class PlantaoProviderAttemptPlan {
  const PlantaoProviderAttemptPlan({
    required this.sequence,
    required this.provider,
    required this.isFallback,
  });

  final int sequence;
  final PlantaoProviderKind provider;
  final bool isFallback;
}

class PlantaoProviderRoutePlan {
  PlantaoProviderRoutePlan({
    required Iterable<PlantaoProviderAttemptPlan> attempts,
  }) : attempts = List<PlantaoProviderAttemptPlan>.unmodifiable(attempts) {
    if (this.attempts.isEmpty) {
      throw ArgumentError.value(attempts, 'attempts', 'must not be empty');
    }
    for (var index = 0; index < this.attempts.length; index++) {
      if (this.attempts[index].sequence != index) {
        throw ArgumentError('provider attempt sequence must be contiguous');
      }
    }
  }

  factory PlantaoProviderRoutePlan.currentPlantaoPaidFirst() {
    return PlantaoProviderRoutePlan(
      attempts: const <PlantaoProviderAttemptPlan>[
        PlantaoProviderAttemptPlan(
          sequence: 0,
          provider: PlantaoProviderKind.gptPaid,
          isFallback: false,
        ),
        PlantaoProviderAttemptPlan(
          sequence: 1,
          provider: PlantaoProviderKind.geminiPaid,
          isFallback: true,
        ),
      ],
    );
  }

  static const bool productiveConnectionEnabled = false;
  final List<PlantaoProviderAttemptPlan> attempts;
}

class PlantaoProviderInvocation {
  const PlantaoProviderInvocation({
    required this.request,
    required this.evidenceBundle,
    required this.systemPrompt,
    required this.userPrompt,
  });

  final PlantaoRequest request;
  final PlantaoEvidenceBundle evidenceBundle;
  final String systemPrompt;
  final String userPrompt;
}

class PlantaoProviderPortEvent {
  const PlantaoProviderPortEvent({
    required this.requestId,
    required this.provider,
    required this.sequence,
    this.textDelta,
    this.isTerminal = false,
  });

  final String requestId;
  final PlantaoProviderKind provider;
  final int sequence;
  final String? textDelta;
  final bool isTerminal;
}
