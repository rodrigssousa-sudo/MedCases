enum AiRequestMode {
  plantao,
  estudo,
}

enum AiRequestLocale {
  pt,
  es,
}

enum AiSourceSurface {
  aiScreen,
  home,
  ambassador,
  secondOpinion,
  other,
}

class AiHistoryEntry {
  final String role;
  final String text;

  const AiHistoryEntry({
    required this.role,
    required this.text,
  });
}

class AiRequestContract {
  final String requestId;
  final String sessionId;
  final String input;
  final AiRequestMode mode;
  final AiRequestLocale locale;
  final List<AiHistoryEntry> history;
  final String? intent;
  final AiSourceSurface sourceSurface;
  final Map<String, Object?> metadata;

  AiRequestContract({
    required this.requestId,
    required this.sessionId,
    required this.input,
    required this.mode,
    required this.locale,
    required this.sourceSurface,
    List<AiHistoryEntry> history = const <AiHistoryEntry>[],
    this.intent,
    Map<String, Object?> metadata = const <String, Object?>{},
  })  : assert(requestId != ''),
        assert(sessionId != ''),
        assert(input != ''),
        history = List<AiHistoryEntry>.unmodifiable(history),
        metadata = Map<String, Object?>.unmodifiable(metadata);

  bool get longResponse => mode == AiRequestMode.estudo;
}
