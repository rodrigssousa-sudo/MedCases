import '../models/clinical_structured_output.dart';

final class AiHydratedExchange {
  const AiHydratedExchange({
    required this.requestId,
    required this.userMessageId,
    required this.assistantMessageId,
    required this.userInput,
    required this.userDisplayText,
    required this.assistantText,
    required this.clinicalOutput,
  });

  final String requestId;
  final String userMessageId;
  final String assistantMessageId;
  final String userInput;
  final String? userDisplayText;
  final String assistantText;
  final ClinicalStructuredOutput? clinicalOutput;
}

abstract final class AiSessionExchangeHydrator {
  static List<AiHydratedExchange> hydrate({
    required String sessionId,
    required List<Map<String, dynamic>> exchanges,
  }) {
    final normalizedSessionId = sessionId.trim();
    final hydrated = <AiHydratedExchange>[];
    final seenRequestIds = <String>{};

    for (var index = 0; index < exchanges.length; index++) {
      final exchange = exchanges[index];
      final requestId =
          (exchange['requestId']?.toString() ?? '').trim();

      if (requestId.isNotEmpty && !seenRequestIds.add(requestId)) {
        continue;
      }

      final identity = requestId.isNotEmpty ? requestId : 'legacy_$index';
      final userInput = exchange['userInput']?.toString() ?? '';
      final userDisplayCandidate =
          (exchange['userDisplayText']?.toString() ?? '').trim();

      final providerOutput = exchange['assistantOutput']?.toString() ?? '';
      final presentation =
          (exchange['assistantPresentation']?.toString() ?? '').trim();
      final assistantText =
          presentation.isNotEmpty ? presentation : providerOutput;

      // Only a reconciled presentation may revive its structured metadata.
      // Old provider-stage records remain text-only and therefore fail closed.
      final clinicalOutput = presentation.isNotEmpty
          ? ClinicalStructuredOutput.tryFromJson(exchange['clinicalOutput'])
          : null;

      final idPrefix = 'ai_session:$normalizedSessionId:$identity';

      hydrated.add(
        AiHydratedExchange(
          requestId: requestId,
          userMessageId: '$idPrefix:user',
          assistantMessageId: '$idPrefix:assistant',
          userInput: userInput,
          userDisplayText:
              userDisplayCandidate.isEmpty ? null : userDisplayCandidate,
          assistantText: assistantText,
          clinicalOutput: clinicalOutput,
        ),
      );
    }

    return List<AiHydratedExchange>.unmodifiable(hydrated);
  }
}
