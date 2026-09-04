import 'dart:async';

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'plantao_global_clinical_response_gate.dart';

import 'plantao_canonical_phenotype_resolver.dart';

abstract class PlantaoMachineNativeRegistrySource {
  Future<List<Map<String, dynamic>>> loadEnabled(String collection);
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  });
}

// M59_REGISTRY_READ_DIAGNOSTICS_V1
enum PlantaoMachineNativeRegistryReadStatus {
  ok,
  permissionDenied,
  timeout,
  unauthenticated,
  unavailable,
  failedPrecondition,
  otherError,
}

extension PlantaoMachineNativeRegistryReadStatusToken
    on PlantaoMachineNativeRegistryReadStatus {
  String get token {
    switch (this) {
      case PlantaoMachineNativeRegistryReadStatus.ok:
        return 'ok';
      case PlantaoMachineNativeRegistryReadStatus.permissionDenied:
        return 'permission_denied';
      case PlantaoMachineNativeRegistryReadStatus.timeout:
        return 'timeout';
      case PlantaoMachineNativeRegistryReadStatus.unauthenticated:
        return 'unauthenticated';
      case PlantaoMachineNativeRegistryReadStatus.unavailable:
        return 'unavailable';
      case PlantaoMachineNativeRegistryReadStatus.failedPrecondition:
        return 'failed_precondition';
      case PlantaoMachineNativeRegistryReadStatus.otherError:
        return 'other_error';
    }
  }
}

class PlantaoMachineNativeRegistryReadDiagnostic {
  const PlantaoMachineNativeRegistryReadDiagnostic({
    required this.collection,
    required this.operation,
    required this.status,
    required this.rows,
    this.firestoreCode,
  });

  final String collection;
  final String operation;
  final PlantaoMachineNativeRegistryReadStatus status;
  final int rows;
  final String? firestoreCode;

  bool get failed => status != PlantaoMachineNativeRegistryReadStatus.ok;
}

abstract interface class PlantaoMachineNativeRegistryDiagnosticSource {
  PlantaoMachineNativeRegistryReadDiagnostic? diagnosticFor(String collection);
}

class PlantaoFirestoreMachineNativeRegistrySource
    implements
        PlantaoMachineNativeRegistrySource,
        PlantaoMachineNativeRegistryDiagnosticSource {
  PlantaoFirestoreMachineNativeRegistrySource({
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 4),
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final Duration timeout;
  final Map<String, PlantaoMachineNativeRegistryReadDiagnostic>
  _lastDiagnostics = <String, PlantaoMachineNativeRegistryReadDiagnostic>{};

  @override
  PlantaoMachineNativeRegistryReadDiagnostic? diagnosticFor(
    String collection,
  ) => _lastDiagnostics[collection];

  PlantaoMachineNativeRegistryReadStatus _statusForFirebaseCode(String code) {
    switch (code) {
      case 'permission-denied':
        return PlantaoMachineNativeRegistryReadStatus.permissionDenied;
      case 'unauthenticated':
        return PlantaoMachineNativeRegistryReadStatus.unauthenticated;
      case 'unavailable':
        return PlantaoMachineNativeRegistryReadStatus.unavailable;
      case 'failed-precondition':
        return PlantaoMachineNativeRegistryReadStatus.failedPrecondition;
      default:
        return PlantaoMachineNativeRegistryReadStatus.otherError;
    }
  }

  void _recordRead({
    required String collection,
    required String operation,
    required PlantaoMachineNativeRegistryReadStatus status,
    required int rows,
    String? firestoreCode,
  }) {
    final diagnostic = PlantaoMachineNativeRegistryReadDiagnostic(
      collection: collection,
      operation: operation,
      status: status,
      rows: rows,
      firestoreCode: firestoreCode,
    );
    _lastDiagnostics[collection] = diagnostic;

    // Safe runtime observability only: no patient text, query text, row payload,
    // document ids or provider response is interpolated here.
    assert(() {
      debugPrint(
        '[M59_REGISTRY_READ] '
        'operation=$operation '
        'collection=$collection '
        'status=${status.token} '
        'rows=$rows '
        'code=${firestoreCode ?? "none"}',
      );
      return true;
    }());
  }

  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async {
    try {
      final snap = await _db
          .collection(collection)
          .where('enabled', isEqualTo: true)
          .get()
          .timeout(timeout);
      final rows = snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .toList(growable: false);
      _recordRead(
        collection: collection,
        operation: 'loadEnabled',
        status: PlantaoMachineNativeRegistryReadStatus.ok,
        rows: rows.length,
      );
      return rows;
    } on TimeoutException {
      _recordRead(
        collection: collection,
        operation: 'loadEnabled',
        status: PlantaoMachineNativeRegistryReadStatus.timeout,
        rows: 0,
      );
      return const <Map<String, dynamic>>[];
    } on FirebaseException catch (error) {
      _recordRead(
        collection: collection,
        operation: 'loadEnabled',
        status: _statusForFirebaseCode(error.code),
        rows: 0,
        firestoreCode: error.code,
      );
      return const <Map<String, dynamic>>[];
    } catch (_) {
      _recordRead(
        collection: collection,
        operation: 'loadEnabled',
        status: PlantaoMachineNativeRegistryReadStatus.otherError,
        rows: 0,
      );
      return const <Map<String, dynamic>>[];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  }) async {
    try {
      final snap = await _db
          .collection(collection)
          .where(fieldPath, isEqualTo: canonicalKey)
          .get()
          .timeout(timeout);
      final rows = snap.docs
          .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
          .where((row) => row['enabled'] != false)
          .toList(growable: false);
      _recordRead(
        collection: collection,
        operation: 'loadPathology:$fieldPath',
        status: PlantaoMachineNativeRegistryReadStatus.ok,
        rows: rows.length,
      );
      return rows;
    } on TimeoutException {
      _recordRead(
        collection: collection,
        operation: 'loadPathology:$fieldPath',
        status: PlantaoMachineNativeRegistryReadStatus.timeout,
        rows: 0,
      );
      return const <Map<String, dynamic>>[];
    } on FirebaseException catch (error) {
      _recordRead(
        collection: collection,
        operation: 'loadPathology:$fieldPath',
        status: _statusForFirebaseCode(error.code),
        rows: 0,
        firestoreCode: error.code,
      );
      return const <Map<String, dynamic>>[];
    } catch (_) {
      _recordRead(
        collection: collection,
        operation: 'loadPathology:$fieldPath',
        status: PlantaoMachineNativeRegistryReadStatus.otherError,
        rows: 0,
      );
      return const <Map<String, dynamic>>[];
    }
  }
}

// M60_BUNDLED_PHASE24_REGISTRY_SOURCE_V1
class PlantaoBundledPhase24MachineNativeRegistrySource
    implements
        PlantaoMachineNativeRegistrySource,
        PlantaoMachineNativeRegistryDiagnosticSource {
  PlantaoBundledPhase24MachineNativeRegistrySource({
    AssetBundle? bundle,
    this.assetPath =
        'assets/clinical/clinical_registry_phase24_authoritative270.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  Map<String, dynamic>? _snapshot;
  final Map<String, PlantaoMachineNativeRegistryReadDiagnostic>
  _lastDiagnostics = <String, PlantaoMachineNativeRegistryReadDiagnostic>{};

  static const Map<String, String> _collectionKeys = <String, String>{
    'clinical_identity_registry': 'identities',
    'clinical_protocols': 'protocols',
    'clinical_classification_registry': 'classifications',
    'clinical_management_rules': 'managementRules',
    'clinical_action_registry': 'actions',
    'clinical_content_registry': 'content',
  };

  @override
  PlantaoMachineNativeRegistryReadDiagnostic? diagnosticFor(
    String collection,
  ) => _lastDiagnostics[collection];

  Future<Map<String, dynamic>> _loadSnapshot() async {
    final cached = _snapshot;
    if (cached != null) return cached;
    final raw = await _bundle.loadString(assetPath, cache: true);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('phase24_snapshot_root_not_map');
    }
    final snapshot = decoded.cast<String, dynamic>();
    _snapshot = snapshot;
    return snapshot;
  }

  List<Map<String, dynamic>> _rowsFor(
    Map<String, dynamic> snapshot,
    String collection,
  ) {
    final key = _collectionKeys[collection];
    if (key == null) return const <Map<String, dynamic>>[];
    final raw = snapshot[key];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .where((row) => row['enabled'] != false)
        .toList(growable: false);
  }

  Object? _field(Map<String, dynamic> row, String path) {
    Object? current = row;
    for (final part in path.split('.')) {
      if (current is! Map) return null;
      current = current[part];
    }
    return current;
  }

  void _record({
    required String collection,
    required String operation,
    required PlantaoMachineNativeRegistryReadStatus status,
    required int rows,
  }) {
    _lastDiagnostics[collection] = PlantaoMachineNativeRegistryReadDiagnostic(
      collection: collection,
      operation: operation,
      status: status,
      rows: rows,
    );
    assert(() {
      debugPrint(
        '[M60_BUNDLED_REGISTRY_READ] '
        'operation=$operation '
        'collection=$collection '
        'status=${status.token} '
        'rows=$rows',
      );
      return true;
    }());
  }

  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async {
    try {
      final snapshot = await _loadSnapshot();
      final rows = _rowsFor(snapshot, collection);
      _record(
        collection: collection,
        operation: 'bundled:loadEnabled',
        status: PlantaoMachineNativeRegistryReadStatus.ok,
        rows: rows.length,
      );
      return rows;
    } catch (_) {
      _record(
        collection: collection,
        operation: 'bundled:loadEnabled',
        status: PlantaoMachineNativeRegistryReadStatus.otherError,
        rows: 0,
      );
      return const <Map<String, dynamic>>[];
    }
  }

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  }) async {
    try {
      final snapshot = await _loadSnapshot();
      final rows = _rowsFor(snapshot, collection)
          .where((row) => '${_field(row, fieldPath) ?? ''}' == canonicalKey)
          .toList(growable: false);
      _record(
        collection: collection,
        operation: 'bundled:loadPathology:$fieldPath',
        status: PlantaoMachineNativeRegistryReadStatus.ok,
        rows: rows.length,
      );
      return rows;
    } catch (_) {
      _record(
        collection: collection,
        operation: 'bundled:loadPathology:$fieldPath',
        status: PlantaoMachineNativeRegistryReadStatus.otherError,
        rows: 0,
      );
      return const <Map<String, dynamic>>[];
    }
  }
}

class PlantaoFailoverMachineNativeRegistrySource
    implements
        PlantaoMachineNativeRegistrySource,
        PlantaoMachineNativeRegistryDiagnosticSource {
  PlantaoFailoverMachineNativeRegistrySource({
    PlantaoMachineNativeRegistrySource? primary,
    PlantaoMachineNativeRegistrySource? fallback,
  }) : _primary = primary ?? PlantaoFirestoreMachineNativeRegistrySource(),
       _fallback =
           fallback ?? PlantaoBundledPhase24MachineNativeRegistrySource();

  final PlantaoMachineNativeRegistrySource _primary;
  final PlantaoMachineNativeRegistrySource _fallback;
  final Map<String, PlantaoMachineNativeRegistryReadDiagnostic>
  _lastDiagnostics = <String, PlantaoMachineNativeRegistryReadDiagnostic>{};

  PlantaoMachineNativeRegistryReadDiagnostic? _diagnostic(
    PlantaoMachineNativeRegistrySource source,
    String collection,
  ) {
    if (source is PlantaoMachineNativeRegistryDiagnosticSource) {
      final typed = source as PlantaoMachineNativeRegistryDiagnosticSource;
      return typed.diagnosticFor(collection);
    }
    return null;
  }

  @override
  PlantaoMachineNativeRegistryReadDiagnostic? diagnosticFor(
    String collection,
  ) => _lastDiagnostics[collection];

  void _recordSuccessOrFailure(
    String collection,
    PlantaoMachineNativeRegistryReadDiagnostic? diagnostic, {
    required String operation,
    required int rows,
  }) {
    _lastDiagnostics[collection] =
        diagnostic ??
        PlantaoMachineNativeRegistryReadDiagnostic(
          collection: collection,
          operation: operation,
          status: PlantaoMachineNativeRegistryReadStatus.ok,
          rows: rows,
        );
  }

  void _logFailover({
    required String collection,
    required String operation,
    required PlantaoMachineNativeRegistryReadDiagnostic primaryDiagnostic,
    required PlantaoMachineNativeRegistryReadDiagnostic? fallbackDiagnostic,
    required int rows,
  }) {
    assert(() {
      debugPrint(
        '[M60_REGISTRY_FAILOVER] '
        'operation=$operation '
        'collection=$collection '
        'primary_status=${primaryDiagnostic.status.token} '
        'fallback_status=${fallbackDiagnostic?.status.token ?? "unknown"} '
        'rows=$rows',
      );
      return true;
    }());
  }

  @override
  Future<List<Map<String, dynamic>>> loadEnabled(String collection) async {
    final primaryRows = await _primary.loadEnabled(collection);
    final primaryDiagnostic = _diagnostic(_primary, collection);
    if (primaryDiagnostic?.failed != true) {
      _recordSuccessOrFailure(
        collection,
        primaryDiagnostic,
        operation: 'primary:loadEnabled',
        rows: primaryRows.length,
      );
      return primaryRows;
    }

    final fallbackRows = await _fallback.loadEnabled(collection);
    final fallbackDiagnostic = _diagnostic(_fallback, collection);
    _recordSuccessOrFailure(
      collection,
      fallbackDiagnostic,
      operation: 'fallback:loadEnabled',
      rows: fallbackRows.length,
    );
    _logFailover(
      collection: collection,
      operation: 'loadEnabled',
      primaryDiagnostic: primaryDiagnostic!,
      fallbackDiagnostic: fallbackDiagnostic,
      rows: fallbackRows.length,
    );
    return fallbackRows;
  }

  @override
  Future<List<Map<String, dynamic>>> loadPathology(
    String collection,
    String canonicalKey, {
    String fieldPath = 'canonicalPathologyKey',
  }) async {
    final primaryRows = await _primary.loadPathology(
      collection,
      canonicalKey,
      fieldPath: fieldPath,
    );
    final primaryDiagnostic = _diagnostic(_primary, collection);
    if (primaryDiagnostic?.failed != true) {
      _recordSuccessOrFailure(
        collection,
        primaryDiagnostic,
        operation: 'primary:loadPathology:$fieldPath',
        rows: primaryRows.length,
      );
      return primaryRows;
    }

    final fallbackRows = await _fallback.loadPathology(
      collection,
      canonicalKey,
      fieldPath: fieldPath,
    );
    final fallbackDiagnostic = _diagnostic(_fallback, collection);
    _recordSuccessOrFailure(
      collection,
      fallbackDiagnostic,
      operation: 'fallback:loadPathology:$fieldPath',
      rows: fallbackRows.length,
    );
    _logFailover(
      collection: collection,
      operation: 'loadPathology:$fieldPath',
      primaryDiagnostic: primaryDiagnostic!,
      fallbackDiagnostic: fallbackDiagnostic,
      rows: fallbackRows.length,
    );
    return fallbackRows;
  }
}

class PlantaoMachineNativePrefetchResult {
  const PlantaoMachineNativePrefetchResult({
    required this.contextPack,
    required this.providerPromptBlock,
    required this.reason,
    this.canonicalPathologyKey,
    this.protocolKey,
    // M73B_TYPED_RICH_PHASES_PREFETCH_RESULT_V1
    this.monitoring = const <String>[],
    this.reassessment = const <String>[],
    this.escalationCriteria = const <String>[],
  });

  final PlantaoGlobalClinicalContextPack? contextPack;
  final String providerPromptBlock;
  final String reason;
  final String? canonicalPathologyKey;
  final String? protocolKey;

  /// Typed machine-authored phases for final completeness.
  final List<String> monitoring;
  final List<String> reassessment;
  final List<String> escalationCriteria;

  bool get authoritative => contextPack?.hasMachineNativeAuthority == true;

  bool get registryReadFailed => reason.startsWith('registry_read_failed:');

  static const empty = PlantaoMachineNativePrefetchResult(
    contextPack: null,
    providerPromptBlock: '',
    reason: 'no_match',
  );
}

// M71D_RUNTIME_CANONICAL_ATTESTATION_V1
//
// This token is not clinical authority. It proves only that canonical Plantao
// prefetch completed immediately before dispatch and binds the exact provider
// input and language to that execution. The private constructor prevents
// arbitrary product callers from fabricating the token.
class PlantaoCanonicalRuntimeAttestation {
  PlantaoCanonicalRuntimeAttestation._({
    required String providerInput,
    required String language,
    required int issuedAtEpochMs,
    required this.prefetchReason,
    required this.authoritative,
    required this.canonicalPathologyKey,
  })  : _providerInput = providerInput,
        _language = language.trim().toLowerCase(),
        _issuedAtEpochMs = issuedAtEpochMs;

  final String _providerInput;
  final String _language;
  final int _issuedAtEpochMs;
  final String prefetchReason;
  final bool authoritative;
  final String? canonicalPathologyKey;

  bool _consumed = false;

  bool consumeForProviderInput(
    String providerInput, {
    required String language,
    DateTime? now,
  }) {
    if (_consumed) return false;

    final currentEpochMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final ageMs = currentEpochMs - _issuedAtEpochMs;
    final inputMatches = providerInput == _providerInput;
    final languageMatches = language.trim().toLowerCase() == _language;
    final fresh = ageMs >= 0 && ageMs <= 30000;

    if (!inputMatches || !languageMatches || !fresh) return false;

    _consumed = true;
    return true;
  }
}

class PlantaoMachineNativeAttestedPrefetch {
  PlantaoMachineNativeAttestedPrefetch._({
    required this.result,
    required this.providerInput,
    required this.attestation,
  });

  final PlantaoMachineNativePrefetchResult result;
  final String providerInput;
  final PlantaoCanonicalRuntimeAttestation attestation;
}

class PlantaoMachineNativeContextPrefetch {
  PlantaoMachineNativeContextPrefetch({
    PlantaoMachineNativeRegistrySource? source,
    this.cacheTtl = const Duration(minutes: 10),
  }) : _source = source ?? PlantaoFailoverMachineNativeRegistrySource();

  static final instance = PlantaoMachineNativeContextPrefetch();

  static const identities = 'clinical_identity_registry';
  static const protocols = 'clinical_protocols';
  static const classifications = 'clinical_classification_registry';
  static const management = 'clinical_management_rules';
  static const actions = 'clinical_action_registry';
  static const content = 'clinical_content_registry';

  final PlantaoMachineNativeRegistrySource _source;
  final Duration cacheTtl;
  List<Map<String, dynamic>>? _identityCache;
  DateTime? _identityAt;
  final Map<String, _CachedPack> _packs = <String, _CachedPack>{};

  PlantaoMachineNativeRegistryReadDiagnostic? _diagnostic(String collection) {
    final source = _source;
    if (source is PlantaoMachineNativeRegistryDiagnosticSource) {
      final diagnosticSource =
          source as PlantaoMachineNativeRegistryDiagnosticSource;
      return diagnosticSource.diagnosticFor(collection);
    }
    return null;
  }

  PlantaoMachineNativePrefetchResult _readFailure({
    required String collection,
    required PlantaoMachineNativeRegistryReadDiagnostic diagnostic,
    String? canonicalPathologyKey,
  }) {
    return PlantaoMachineNativePrefetchResult(
      contextPack: null,
      providerPromptBlock: '',
      canonicalPathologyKey: canonicalPathologyKey,
      protocolKey: null,
      reason: 'registry_read_failed:${diagnostic.status.token}:$collection',
    );
  }

  Future<PlantaoMachineNativeAttestedPrefetch> prefetchAttested({
    required String userText,
    required String language,
  }) async {
    final result = await prefetch(
      userText: userText,
      language: language,
    );
    final providerInput =
        result.authoritative && result.providerPromptBlock.trim().isNotEmpty
            ? '$userText\n\n${result.providerPromptBlock}'
            : userText;
    final attestation = PlantaoCanonicalRuntimeAttestation._(
      providerInput: providerInput,
      language: language,
      issuedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      prefetchReason: result.reason,
      authoritative: result.authoritative,
      canonicalPathologyKey: result.canonicalPathologyKey,
    );
    return PlantaoMachineNativeAttestedPrefetch._(
      result: result,
      providerInput: providerInput,
      attestation: attestation,
    );
  }

  Future<PlantaoMachineNativePrefetchResult> prefetch({
    required String userText,
    required String language,
  }) async {
    if (userText.trim().isEmpty)
      return PlantaoMachineNativePrefetchResult.empty;

    // M59_PHYSICAL_REGISTRY_READ_PLANE_V1
    final phenotype = PlantaoCanonicalPhenotypeResolver.resolve(userText);
    final identityRows = await _identities();
    final identityBulkDiagnostic = _diagnostic(identities);

    // M58_CANONICAL_PHENOTYPE_IDENTITY_BRIDGE
    // Explicit registry identity remains first. The phenotype bridge is used
    // only when that path cannot establish a unique canonical identity.
    var identity = _matchIdentity(userText, identityRows);
    var resolvedViaPhenotype = false;
    var resolvedViaPhenotypeReadFallback = false;

    if (identity == null && phenotype != null && identityRows.isNotEmpty) {
      identity = _matchCanonicalIdentity(
        phenotype.canonicalPathologyKey,
        identityRows,
      );
      resolvedViaPhenotype = identity != null;
    }

    // If bulk identity resolution cannot prove the phenotype identity, attempt
    // one narrow canonical point-read. This also distinguishes a readable but
    // unexpectedly empty bulk query from a real canonical document miss.
    if (identity == null && phenotype != null) {
      final directRows = await _source.loadPathology(
        identities,
        phenotype.canonicalPathologyKey,
        fieldPath: 'canonicalKey',
      );
      final directDiagnostic = _diagnostic(identities);
      if (directDiagnostic?.failed == true) {
        return _readFailure(
          collection: identities,
          diagnostic: directDiagnostic!,
          canonicalPathologyKey: phenotype.canonicalPathologyKey,
        );
      }
      identity = _matchCanonicalIdentity(
        phenotype.canonicalPathologyKey,
        directRows,
      );
      resolvedViaPhenotype = identity != null;
      resolvedViaPhenotypeReadFallback = identity != null;
      if (identity == null) {
        return PlantaoMachineNativePrefetchResult(
          contextPack: null,
          providerPromptBlock: '',
          canonicalPathologyKey: phenotype.canonicalPathologyKey,
          reason: 'identity_canonical_point_read_not_unique',
        );
      }
    }

    if (identity == null) {
      if (identityBulkDiagnostic?.failed == true) {
        return _readFailure(
          collection: identities,
          diagnostic: identityBulkDiagnostic!,
          canonicalPathologyKey: phenotype?.canonicalPathologyKey,
        );
      }
      if (identityRows.isEmpty &&
          identityBulkDiagnostic?.status ==
              PlantaoMachineNativeRegistryReadStatus.ok) {
        return PlantaoMachineNativePrefetchResult(
          contextPack: null,
          providerPromptBlock: '',
          canonicalPathologyKey: phenotype?.canonicalPathologyKey,
          reason: 'identity_registry_empty',
        );
      }
      return PlantaoMachineNativePrefetchResult(
        contextPack: null,
        providerPromptBlock: '',
        canonicalPathologyKey: phenotype?.canonicalPathologyKey,
        reason: 'identity_not_resolved_or_ambiguous',
      );
    }
    final key = _s(identity['canonicalKey']).isNotEmpty
        ? _s(identity['canonicalKey'])
        : _s(identity['canonicalPathologyKey']);
    if (key.isEmpty) return PlantaoMachineNativePrefetchResult.empty;

    final now = DateTime.now();
    final locale = _locale(language);
    final cacheKey = '$key|$locale';
    final cached = _packs[cacheKey];
    if (cached != null && now.difference(cached.at) <= cacheTtl) {
      return cached.result;
    }

    final rows = await Future.wait<List<Map<String, dynamic>>>([
      _source.loadPathology(protocols, key),
      _source.loadPathology(classifications, key),
      _source.loadPathology(management, key),
      _source.loadPathology(
        actions,
        key,
        fieldPath: 'match.canonicalPathologyKey',
      ),
      _source.loadPathology(content, key),
    ]);
    for (final collection in <String>[
      protocols,
      classifications,
      management,
      actions,
      content,
    ]) {
      final diagnostic = _diagnostic(collection);
      if (diagnostic?.failed == true) {
        return _readFailure(
          collection: collection,
          diagnostic: diagnostic!,
          canonicalPathologyKey: key,
        );
      }
    }
    final protocol = _top(rows[0]);
    final rule = _top(rows[2]);
    final protocolKey = _first(<Object?>[
      protocol?['protocolKey'],
      rule?['protocolKey'],
    ]);
    final guidelineVersion = _first(<Object?>[
      rule?['guidelineVersion'],
      protocol?['guidelineVersion'],
      rule?['version'],
      protocol?['version'],
    ]);
    final reviewDate = _first(<Object?>[
      rule?['clinicalReviewDate'],
      protocol?['clinicalReviewDate'],
      rule?['reviewedAt'],
      protocol?['reviewedAt'],
    ]);
    final required = _merge(rule, const <String>[
      'requiredActions',
      'initialActions',
      'definitiveActions',
    ], locale);
    final prohibited = _merge(rule, const <String>[
      'contraindicatedActions',
      'prohibitedActions',
    ], locale);
    final conditional = _merge(rule, const <String>[
      'conditionalActions',
    ], locale);
    final requiredFacts = _list(rule?['requiredFacts']);
    final monitoring = _merge(rule, const <String>['monitoring'], locale);
    final reassessment = _merge(rule, const <String>['reassessment'], locale);
    final escalation = _merge(rule, const <String>[
      'escalationCriteria',
    ], locale);
    final classDeps = <String>{
      ..._list(rule?['classificationDependencies']),
      for (final r in rows[1])
        if (_s(r['classificationKey']).isNotEmpty) _s(r['classificationKey']),
    }.toList(growable: false);
    final scoreDeps = <String>{
      ..._list(rule?['scoreDependencies']),
      for (final r in rows[1])
        if (_s(r['mode']).toLowerCase() == 'score' &&
            _s(r['classificationKey']).isNotEmpty)
          _s(r['classificationKey']),
    }.toList(growable: false);
    // M56C_R5_EXPLICIT_MANAGEMENT_AUTHORITY
    final explicitMachineAuthority =
        rule != null &&
        rule['enabled'] != false &&
        rule['managementReady'] == true &&
        _s(rule['provenancePolicy']) ==
            'AUTHORITATIVE_CURRENT_OR_FAIL_CLOSED' &&
        _s(rule['resolutionPolicy']) ==
            'authoritative_current_machine_management';
    final legacyFixtureAuthority =
        rule != null &&
        rule['managementReady'] == null &&
        (required.isNotEmpty ||
            prohibited.isNotEmpty ||
            conditional.isNotEmpty);
    final authoritative =
        protocolKey.isNotEmpty &&
        guidelineVersion.isNotEmpty &&
        (explicitMachineAuthority || legacyFixtureAuthority);

    final pack = PlantaoGlobalClinicalContextPack(
      pathologyKey: key,
      protocolKey: protocolKey,
      guidelineVersion: guidelineVersion,
      clinicalReviewDate: reviewDate,
      requiredActions: required,
      prohibitedActions: prohibited,
      conditionalActions: conditional,
      classificationDependencies: classDeps,
      scoreDependencies: scoreDeps,
      authoritative: authoritative,
    );
    final prompt = authoritative
        ? _prompt(
            language,
            pack,
            rows[1].length,
            rows[3].length,
            rows[4].length,
            requiredFacts: requiredFacts,
            monitoring: monitoring,
            reassessment: reassessment,
            escalation: escalation,
          )
        : '';
    final result = PlantaoMachineNativePrefetchResult(
      contextPack: pack,
      providerPromptBlock: prompt,
      monitoring: monitoring,
      reassessment: reassessment,
      escalationCriteria: escalation,
      canonicalPathologyKey: key,
      protocolKey: protocolKey.isEmpty ? null : protocolKey,
      reason: authoritative
          ? (resolvedViaPhenotypeReadFallback
                ? 'authoritative_pack_ready_via_phenotype_read_fallback'
                : (resolvedViaPhenotype
                      ? 'authoritative_pack_ready_via_phenotype'
                      : 'authoritative_pack_ready'))
          : (resolvedViaPhenotypeReadFallback
                ? 'pack_incomplete_via_phenotype_read_fallback'
                : (resolvedViaPhenotype
                      ? 'pack_incomplete_via_phenotype'
                      : 'pack_incomplete')),
    );
    _packs[cacheKey] = _CachedPack(now, result);
    return result;
  }

  Future<List<Map<String, dynamic>>> _identities() async {
    final now = DateTime.now();
    if (_identityCache != null &&
        _identityAt != null &&
        now.difference(_identityAt!) <= cacheTtl) {
      return _identityCache!;
    }
    final rows = await _source.loadEnabled(identities);
    final diagnostic = _diagnostic(identities);
    if (diagnostic?.failed == true) {
      _identityCache = null;
      _identityAt = null;
      return rows;
    }
    _identityCache = rows;
    _identityAt = now;
    return rows;
  }

  static Map<String, dynamic>? _matchCanonicalIdentity(
    String canonicalPathologyKey,
    List<Map<String, dynamic>> rows,
  ) {
    final matches = rows
        .where((row) {
          final key = _s(row['canonicalKey']).isNotEmpty
              ? _s(row['canonicalKey'])
              : _s(row['canonicalPathologyKey']);
          return key == canonicalPathologyKey;
        })
        .toList(growable: false);
    return matches.length == 1 ? matches.single : null;
  }

  static Map<String, dynamic>? _matchIdentity(
    String query,
    List<Map<String, dynamic>> rows,
  ) {
    final q = _fold(query);
    final matches = <_Match>[];
    for (final row in rows) {
      final key = _s(row['canonicalKey']).isNotEmpty
          ? _s(row['canonicalKey'])
          : _s(row['canonicalPathologyKey']);
      if (key.isEmpty) continue;
      final aliases = <String>{key.replaceAll('_', ' ')};
      for (final e in row.entries) {
        final k = e.key.toLowerCase();
        if (k.contains('alias') ||
            k.contains('label') ||
            k.contains('title') ||
            k == 'name') {
          aliases.addAll(_list(e.value));
        }
      }
      var best = 0;
      for (final alias in aliases) {
        final a = _fold(alias).trim();
        if (a.length >= 3 && _bounded(q, a) && a.length > best) best = a.length;
      }
      if (best > 0) matches.add(_Match(row, best));
    }
    if (matches.isEmpty) return null;
    matches.sort((a, b) => b.score.compareTo(a.score));
    if (matches.length > 1 && matches[0].score == matches[1].score) {
      final a = _s(matches[0].row['canonicalKey']);
      final b = _s(matches[1].row['canonicalKey']);
      if (a != b) return null;
    }
    return matches.first.row;
  }

  static Map<String, dynamic>? _top(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return null;
    final copy = List<Map<String, dynamic>>.of(rows)
      ..sort((a, b) => _i(b['priority']).compareTo(_i(a['priority'])));
    return copy.first;
  }

  // M56C_R5_BILINGUAL_MANAGEMENT_SCHEMA_BRIDGE
  // Canonical authored actions are {key, pt, es}. Use only the active locale.
  // Top-level current-authority fields win over payload compatibility fields.
  static List<String> _merge(
    Map<String, dynamic>? row,
    List<String> keys,
    String locale,
  ) {
    if (row == null) return const <String>[];
    final out = <String>{};
    for (final key in keys) {
      final topLevel = row[key];
      final payload = row['payload'];
      final fallback = payload is Map ? payload[key] : null;
      final value = _hasClinicalValue(topLevel) ? topLevel : fallback;
      out.addAll(_clinical(value, locale));
    }
    return out.take(24).toList(growable: false);
  }

  static bool _hasClinicalValue(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  static Iterable<String> _clinical(Object? value, String locale) sync* {
    if (value is String) {
      final text = value.trim();
      if (text.isNotEmpty) yield _cut(text, 360);
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        yield* _clinical(item, locale);
      }
      return;
    }
    if (value is Map) {
      if (value.containsKey(locale)) {
        yield* _clinical(value[locale], locale);
        return;
      }
      final fallbackLocale = locale == 'es' ? 'pt' : 'es';
      if (value.containsKey(fallbackLocale)) {
        yield* _clinical(value[fallbackLocale], locale);
        return;
      }
      for (final key in const <String>[
        'action',
        'instruction',
        'text',
        'label',
        'summary',
        'name',
      ]) {
        if (value.containsKey(key)) {
          yield* _clinical(value[key], locale);
        }
      }
    }
  }

  static List<String> _list(Object? value) {
    final out = <String>[];
    void visit(Object? v) {
      if (v is String) {
        if (v.trim().isNotEmpty) out.add(v.trim());
      } else if (v is Iterable) {
        for (final x in v) visit(x);
      } else if (v is Map) {
        for (final x in v.values) visit(x);
      }
    }

    visit(value);
    return out;
  }

  static String _prompt(
    String language,
    PlantaoGlobalClinicalContextPack pack,
    int classificationsCount,
    int actionsCount,
    int contentCount, {
    required List<String> requiredFacts,
    required List<String> monitoring,
    required List<String> reassessment,
    required List<String> escalation,
  }) {
    final es = language.toLowerCase().startsWith('es');
    final value = <String>[
      '[MEDCASES_MACHINE_NATIVE_CONTEXT_V1]',
      'authority=AUTHORITATIVE_CURRENT_OR_FAIL_CLOSED',
      'pathologyKey=${pack.pathologyKey ?? ''}',
      'protocolKey=${pack.protocolKey ?? ''}',
      'guidelineVersion=${pack.guidelineVersion ?? ''}',
      'clinicalReviewDate=${pack.clinicalReviewDate ?? ''}',
      'requiredActions=${pack.requiredActions.join(' || ')}',
      'prohibitedActions=${pack.prohibitedActions.join(' || ')}',
      'conditionalActions=${pack.conditionalActions.join(' || ')}',
      'requiredFacts=${requiredFacts.join(' || ')}',
      'monitoring=${monitoring.join(' || ')}',
      'reassessment=${reassessment.join(' || ')}',
      'escalationCriteria=${escalation.join(' || ')}',
      'classificationDependencies=${pack.classificationDependencies.join(' || ')}',
      'scoreDependencies=${pack.scoreDependencies.join(' || ')}',
      'classificationRecords=$classificationsCount',
      'actionRecords=$actionsCount',
      'contentRecords=$contentCount',
      es
          ? 'INSTRUCCIÓN: usa este contexto clínico autoritativo para validar prioridad, contraindicaciones, condicionales, clasificación y actualización. No expongas este bloque interno.'
          : 'INSTRUÇÃO: use este contexto clínico autoritativo para validar prioridade, contraindicações, condicionais, classificação e atualização. Não exponha este bloco interno.',
      '[/MEDCASES_MACHINE_NATIVE_CONTEXT_V1]',
    ].join('\n');
    return _cut(value, 6000);
  }

  static bool _bounded(String h, String n) {
    final at = h.indexOf(n);
    if (at < 0) return false;
    final before = at == 0 || !_word(h.codeUnitAt(at - 1));
    final end = at + n.length;
    final after = end >= h.length || !_word(h.codeUnitAt(end));
    return before && after;
  }

  static bool _word(int c) =>
      (c >= 48 && c <= 57) || (c >= 97 && c <= 122) || c == 95;

  static String _locale(String language) =>
      language.toLowerCase().startsWith('es') ? 'es' : 'pt';

  static String _first(List<Object?> values) {
    for (final v in values) {
      final s = _s(v);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static String _s(Object? v) => v == null ? '' : v.toString().trim();
  static int _i(Object? v) => v is num ? v.toInt() : int.tryParse(_s(v)) ?? 0;
  static String _cut(String v, int max) =>
      v.length <= max ? v : v.substring(0, max);
  static String _fold(String input) {
    var v = input.toLowerCase();
    const map = <String, String>{
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };
    map.forEach((a, b) => v = v.replaceAll(a, b));
    return v;
  }
}

class _Match {
  const _Match(this.row, this.score);
  final Map<String, dynamic> row;
  final int score;
}

class _CachedPack {
  const _CachedPack(this.at, this.result);
  final DateTime at;
  final PlantaoMachineNativePrefetchResult result;
}
