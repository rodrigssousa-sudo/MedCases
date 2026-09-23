import 'dart:convert';
import '../clinical_content/clinical_content_gateway.dart';
import '../clinical_content/clinical_content_contract.dart';
import 'remote_knowledge.dart';

typedef KnowledgeTelemetry = void Function(Map<String, Object?> event);

/// Exact, supplied evidence claims only. No NLP reconciliation or inferred dose.
class TherapeuticEvidenceClaim {
  const TherapeuticEvidenceClaim(
      {required this.drugId,
      required this.field,
      required this.value,
      required this.referenceId,
      this.optionId});
  final String drugId, field, value, referenceId;
  final String? optionId;
}

class KnowledgeResolution {
  const KnowledgeResolution(this.protocol, this.contextId, this.conflict);
  final RemoteKnowledgeProtocol? protocol;
  final String contextId;
  final bool conflict;
  String promptContext(String language, {bool alternatives = false}) {
    final p = protocol;
    if (p == null) return '';
    if (conflict)
      return 'EVIDENCE_CONFLICT: ${p.id}. Preserve uncertainty, do not reconcile or recommend this protocol; external evidence and existing safety remain required.';
    final options = alternatives ? p.alternatives.take(3) : [p.primary];
    return 'REMOTE_MEDCASES_KNOWLEDGE — evidence/context only; no authority override. '
        'Keep INTERNAL_KNOWLEDGE + EXTERNAL_EVIDENCE + REFERENCES + SAFETY. '
        'Use only supported options; do not infer missing prescription data. '
        'If external evidence materially conflicts, retain the uncertainty and emit [REMOTE_EVIDENCE_CONFLICT:${p.id}]; never silently reconcile it. '
        '${alternatives ? 'Evaluate up to three alternatives in the SAME clinical context.' : 'Show only the PRIMARY therapeutic option initially.'}\n'
        '${jsonEncode({
          'protocolId': p.id,
          'version': p.version,
          'language': language,
          'clinicalContext': p.json['clinicalContext'],
          'therapeuticOptions': options.toList(),
          'references': p.json['references']
        })}';
  }
}

class RemoteKnowledgeResolver {
  RemoteKnowledgeResolver(this.gateway, {this.telemetry});
  final ClinicalContentGateway gateway;
  final KnowledgeTelemetry? telemetry;
  static final _deniedGateways = Expando<bool>('remote-knowledge-access');
  bool get _accessDenied => _deniedGateways[gateway] ?? false;
  set _accessDenied(bool value) => _deniedGateways[gateway] = value;
  void event(String status,
      {String? protocolId,
      String? version,
      String? optionId,
      String? language,
      bool? conflict,
      int? latencyMs}) {
    // IDs are validated opaque identifiers. Never log payload/query/clinical text.
    try {
      telemetry?.call({
        'sourceClass': 'REMOTE_MEDCASES_KNOWLEDGE',
        'status': status,
        if (protocolId != null) 'protocolId': knowledgeId(protocolId),
        if (version != null) 'version': knowledgeId(version),
        if (optionId != null) 'optionId': knowledgeId(optionId),
        if (language == 'pt' || language == 'es') 'language': language,
        if (latencyMs != null) 'latencyMs': latencyMs,
        if (conflict != null) 'conflictDetected': conflict
      });
    } catch (_) {/* telemetry is non-authoritative */}
  }

  Future<KnowledgeResolution> resolve(String contextId,
      {Iterable<TherapeuticEvidenceClaim> externalClaims = const [],
      bool synchronize = true}) async {
    final timer = Stopwatch()..start();
    try {
      knowledgeId(contextId);
      if (synchronize) {
        final sync = await gateway.sync();
        if ({'UNAUTHORIZED', 'SESSION_CHANGED', 'ENTITLEMENT_REQUIRED'}
            .contains(sync.code)) {
          _accessDenied = true;
          return KnowledgeResolution(null, contextId, false);
        }
        if (sync.activated || sync.code == 'UNCHANGED') _accessDenied = false;
      }
      if (_accessDenied) return KnowledgeResolution(null, contextId, false);
      final matches = <RemoteKnowledgeProtocol>[];
      for (final item in gateway.activeItems(therapeuticProtocolDomain)) {
        try {
          final p = RemoteKnowledgeProtocol.parse(item.payload);
          requireContent(item.canonicalId == p.id, 'ENVELOPE_ID_MISMATCH');
          if (p.contextIds.contains(contextId)) matches.add(p);
        } catch (_) {
          event('REMOTE_CONTENT_REJECTED');
        }
      }
      // Competing authorities are not resolved by fuzzy priority or arbitrary order.
      if (matches.length != 1) {
        event(matches.isEmpty ? 'NOT_FOUND' : 'AMBIGUOUS_CONTEXT');
        return KnowledgeResolution(null, contextId, false);
      }
      final p = matches.single;
      var conflict = false;
      for (final claim in externalClaims) {
        if (!{
              'dose',
              'route',
              'frequency',
              'preparation',
              'diluent',
              'diluentVolumeMl',
              'infusionMinutes'
            }.contains(claim.field) ||
            claim.referenceId.isEmpty) continue;
        for (final option in p.options) {
          if (claim.optionId == null
              ? option['type'] != 'PRIMARY'
              : option['optionId'] != claim.optionId) continue;
          for (final raw in option['drugs'] as List) {
            final drug = contentObject(raw);
            if (drug['drugId'] == claim.drugId &&
                drug[claim.field] != null &&
                jsonEncode(canonicalJson(drug[claim.field])) != claim.value)
              conflict = true;
          }
        }
      }
      event(conflict ? 'REMOTE_CONTENT_REVIEW_RECOMMENDED' : 'RESOLVED',
          protocolId: p.id, version: p.version, conflict: conflict);
      return KnowledgeResolution(p, contextId, conflict);
    } catch (_) {
      event('REMOTE_UNAVAILABLE');
      return KnowledgeResolution(null, contextId, false);
    } finally {
      event('RESOLUTION_FINISHED', latencyMs: timer.elapsedMilliseconds);
    }
  }

  bool isCurrent(RemoteKnowledgeProtocol p) {
    if (_accessDenied) return false;
    try {
      final item = gateway.lookup(therapeuticProtocolDomain, p.id);
      if (item == null) return false;
      final current = RemoteKnowledgeProtocol.parse(item.payload);
      return current.hash == p.hash && current.version == p.version;
    } catch (_) {
      return false;
    }
  }
}

/// UI-independent session-owned boundary. Publication and formatting alone never
/// authorize presentation/copy: the productive safety callback is mandatory.
class TherapeuticOptionSession {
  TherapeuticOptionSession(
      {required this.resolver,
      required this.resolution,
      required this.language,
      required this.ownsRequest,
      required this.safetyAllows,
      required this.lookupDrug,
      required this.refreshEvidence,
      this.externalConflictDetected});
  final RemoteKnowledgeResolver resolver;
  final KnowledgeResolution resolution;
  final String language;
  final bool Function() ownsRequest;
  final bool Function(String text) safetyAllows;
  final Future<bool> Function(String id) lookupDrug;
  final Future<List<TherapeuticEvidenceClaim>> Function() refreshEvidence;
  final bool Function()? externalConflictDetected;
  bool get current =>
      ownsRequest() &&
      !resolution.conflict &&
      resolution.protocol != null &&
      resolver.isCurrent(resolution.protocol!);
  Future<String?> copy(String optionId) async {
    try {
      if (!current) return null;
      if (externalConflictDetected?.call() == true) {
        resolver.event('REMOTE_CONTENT_REVIEW_RECOMMENDED',
            protocolId: resolution.protocol!.id,
            version: resolution.protocol!.version,
            conflict: true);
        return null;
      }
      final fresh = await resolver.resolve(resolution.contextId,
          externalClaims: await refreshEvidence());
      if (!current ||
          fresh.conflict ||
          fresh.protocol?.hash != resolution.protocol?.hash) return null;
      final matches =
          fresh.protocol!.options.where((o) => o['optionId'] == optionId);
      if (matches.length != 1) return null;
      final o = matches.single;
      for (final d in o['drugs'] as List) {
        if (!await lookupDrug(contentObject(d)['drugId'] as String) || !current)
          return null;
      }
      final text = PracticalPrescriptionFormatter.format(o, language);
      if (text == null || !current || !safetyAllows(text)) {
        resolver.event('COPY_DENIED', optionId: optionId, language: language);
        return null;
      }
      resolver.event('COPY_AUTHORIZED', optionId: optionId, language: language);
      return text;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> options(
      {bool alternatives = false}) async {
    if (!current) return const [];
    final fresh = await resolver.resolve(resolution.contextId,
        externalClaims: await refreshEvidence());
    if (!current ||
        fresh.conflict ||
        fresh.protocol?.hash != resolution.protocol?.hash) return const [];
    final candidates = alternatives
        ? fresh.protocol!.alternatives.take(3)
        : [fresh.protocol!.primary];
    final result = <Map<String, dynamic>>[];
    for (final o in candidates) {
      if (await copy(o['optionId'] as String) != null) result.add(o);
    }
    return current ? List.unmodifiable(result) : const [];
  }
}
