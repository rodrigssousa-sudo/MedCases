class ClinicalIdentityTransportEnvelope {
  ClinicalIdentityTransportEnvelope._();

  static final RegExp _activeProtocolTag = RegExp(
    r'^\s*PROTOCOLO_CLINICO_(?:ATIVO|ACTIVO)\s*:\s*(.+?)\s*$',
    caseSensitive: false,
    multiLine: true,
  );

  static Map<String, dynamic> fromStructuredSystemPrompt(
    String? systemPrompt,
  ) {
    if (systemPrompt == null || systemPrompt.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    final aliases = _activeProtocolTag
        .allMatches(systemPrompt)
        .map((match) => match.group(1)?.trim())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet();

    // Fail closed:
    // - no explicit structured protocol marker -> no identity payload;
    // - more than one different protocol marker -> ambiguous -> no identity.
    if (aliases.length != 1) {
      return const <String, dynamic>{};
    }

    return <String, dynamic>{
      'clinicalIdentityAlias': aliases.single,
    };
  }
}
