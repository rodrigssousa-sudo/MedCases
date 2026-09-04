class RemoteClinicalAction {
  final String actionKey;
  final String kind;
  final String actionType;
  final String label;
  final String prompt;
  final String contentRef;
  final Map<String, dynamic> payload;
  final String sourceVersion;

  const RemoteClinicalAction({
    required this.actionKey,
    required this.kind,
    required this.actionType,
    required this.label,
    required this.prompt,
    required this.contentRef,
    required this.payload,
    required this.sourceVersion,
  });

  factory RemoteClinicalAction.fromJson(Map<String, dynamic> json) {
    return RemoteClinicalAction(
      actionKey: _string(json['actionKey']),
      kind: _string(json['kind']),
      actionType: _string(json['actionType']),
      label: _string(json['label']),
      prompt: _string(json['prompt']),
      contentRef: _string(json['contentRef']),
      payload: _map(json['payload']),
      sourceVersion: _string(json['sourceVersion']),
    );
  }

  bool get isRenderable => label.trim().isNotEmpty;
}

class RemoteClinicalClassification {
  final String key;
  final String label;
  final String mode;
  final bool resolved;
  final String categoryKey;
  final String categoryLabel;
  final num? score;
  final List<String> missingFacts;
  final String sourceVersion;

  const RemoteClinicalClassification({
    required this.key,
    required this.label,
    required this.mode,
    required this.resolved,
    required this.categoryKey,
    required this.categoryLabel,
    required this.score,
    required this.missingFacts,
    required this.sourceVersion,
  });

  factory RemoteClinicalClassification.fromJson(Map<String, dynamic> json) {
    return RemoteClinicalClassification(
      key: _string(json['key']),
      label: _string(json['label']),
      mode: _string(json['mode']),
      resolved: json['resolved'] == true,
      categoryKey: _string(json['categoryKey']),
      categoryLabel: _string(json['categoryLabel']),
      score: json['score'] is num ? json['score'] as num : null,
      missingFacts: _stringList(json['missingFacts']),
      sourceVersion: _string(json['sourceVersion']),
    );
  }
}

class RemoteClinicalResponse {
  final String schemaVersion;
  final String status;
  final String language;
  final String text;
  final String pathologyKey;
  final String pathologyLabel;
  final String protocolKey;
  final RemoteClinicalClassification classification;
  final RemoteClinicalAction? primaryAction;
  final RemoteClinicalAction? classificationAction;
  final String revealMode;
  final bool immutableAfterCommit;
  final bool allowVisibleTextMutation;

  const RemoteClinicalResponse({
    required this.schemaVersion,
    required this.status,
    required this.language,
    required this.text,
    required this.pathologyKey,
    required this.pathologyLabel,
    required this.protocolKey,
    required this.classification,
    required this.primaryAction,
    required this.classificationAction,
    required this.revealMode,
    required this.immutableAfterCommit,
    required this.allowVisibleTextMutation,
  });

  factory RemoteClinicalResponse.fromJson(Map<String, dynamic> json) {
    final clinicalContext = _map(json['clinicalContext']);
    final classification = _map(clinicalContext['classification']);
    final actions = _map(json['actions']);
    final presentation = _map(json['presentation']);

    final primaryJson = _nullableMap(actions['primary']);
    final classificationJson = _nullableMap(actions['classification']);

    return RemoteClinicalResponse(
      schemaVersion: _string(json['schemaVersion']),
      status: _string(json['status']),
      language: _string(json['language']),
      text: _string(json['text']),
      pathologyKey: _string(clinicalContext['pathologyKey']),
      pathologyLabel: _string(clinicalContext['pathologyLabel']),
      protocolKey: _string(clinicalContext['protocolKey']),
      classification: RemoteClinicalClassification.fromJson(classification),
      primaryAction: primaryJson == null
          ? null
          : RemoteClinicalAction.fromJson(primaryJson),
      classificationAction: classificationJson == null
          ? null
          : RemoteClinicalAction.fromJson(classificationJson),
      revealMode: _string(presentation['revealMode']),
      immutableAfterCommit: presentation['immutableAfterCommit'] == true,
      allowVisibleTextMutation:
          presentation['allowVisibleTextMutation'] == true,
    );
  }

  bool get isReady => status == 'ready' && text.trim().isNotEmpty;

  bool get isWaitingForFacts => status == 'waiting_for_facts';

  bool get supportsImmutableLocalReveal =>
      revealMode == 'local_progressive_after_commit' &&
      immutableAfterCommit &&
      !allowVisibleTextMutation;
}

String _string(Object? value) => value == null ? '' : value.toString();

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.unmodifiable(value);
  }
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, child) => MapEntry(key.toString(), child)),
    );
  }
  return const <String, dynamic>{};
}

Map<String, dynamic>? _nullableMap(Object? value) {
  if (value == null) return null;
  final mapped = _map(value);
  return mapped.isEmpty ? null : mapped;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(
    value.map((item) => item.toString()).where((item) => item.isNotEmpty),
  );
}
