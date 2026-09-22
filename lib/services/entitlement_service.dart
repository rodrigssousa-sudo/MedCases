// MEDCASES_R25A_ENTITLEMENT_SINGLE_OWNER_FINAL_V1_B_R0
//
// Single sovereign owner for client entitlement decisions.
// Premium is never inferred from a client flag. Tier comes from the already
// server-derived signed calculator session. Failure/staleness always closes to Free.
//
// Canonical product contract:
// FREE
// - full guides
// - full scores
// - essential drug library (Free60) through signed MCC1 surface
// - no weight dose
// - no renal premium tool
// - Study AI: 5/day
// - Plantao: 1/day
// - audio: 15 min/month
// - transcription: 30 min/month
// - clinical histories: 3/month
//
// PREMIUM
// - strict superset of Free
// - full drugs
// - weight dose
// - renal adjustment
// - expanded AI / Plantao
// - long recording: 240 min/month
// - expanded transcription: 90 min/month
// - clinical history without Free monthly cap

import 'dart:async';
import 'offline_entitlement_lease.dart';

import 'free_drug_catalog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calculator_mcc1_bridge_service.dart';

enum EntitlementTier { free, premium }

enum MedCasesCapability {
  home,
  protocolsFull,
  generalCalculators,
  search,
  safetyWarnings,
  publicReferences,
  guidesFull,
  scoresFull,
  drugsEssentialLibrary,
  drugsFullLibrary,
  drugsWeightDose,
  drugsRenalAdjustment,
  drugsHepaticAdjustment,
  drugsAdvancedPreparation,
  drugsAdvancedInfusion,
  drugsPediatricResources,
  fullPlantao,
  extendedStudyAi,
  unlimitedClinicalHistory,
  fullOfflinePharma,
  aiStudy,
  aiPlantao,
  audioBasic,
  audioLongForm,
  transcriptionBasic,
  transcriptionExpanded,
  clinicalHistory,
}

class EntitlementLimits {
  final int? drugLibraryItems;
  final int? aiStudyQueriesPerDay;
  final int? plantaoQueriesPerDay;
  final int? audioRecordingMinutesPerMonth;
  final int? transcriptionMinutesPerMonth;
  final int? clinicalHistoriesPerMonth;

  const EntitlementLimits({
    required this.drugLibraryItems,
    required this.aiStudyQueriesPerDay,
    required this.plantaoQueriesPerDay,
    required this.audioRecordingMinutesPerMonth,
    required this.transcriptionMinutesPerMonth,
    required this.clinicalHistoriesPerMonth,
  });

  static final free = EntitlementLimits(
    drugLibraryItems: freeDrugCanonicalIds.length,
    aiStudyQueriesPerDay: 5,
    plantaoQueriesPerDay: 1,
    audioRecordingMinutesPerMonth: 15,
    transcriptionMinutesPerMonth: 30,
    clinicalHistoriesPerMonth: 3,
  );

  static const premium = EntitlementLimits(
    drugLibraryItems: null,
    aiStudyQueriesPerDay: null,
    plantaoQueriesPerDay: null,
    audioRecordingMinutesPerMonth: 240,
    transcriptionMinutesPerMonth: 90,
    clinicalHistoriesPerMonth: null,
  );
}

class EntitlementSnapshot {
  final EntitlementTier tier;
  final Set<MedCasesCapability> capabilities;
  final EntitlementLimits limits;
  final String source;
  final String? resolvedUid;
  final DateTime resolvedAtUtc;

  const EntitlementSnapshot({
    required this.tier,
    required this.capabilities,
    required this.limits,
    required this.source,
    required this.resolvedUid,
    required this.resolvedAtUtc,
  });

  bool can(MedCasesCapability capability) => capabilities.contains(capability);
}

class EntitlementDecision {
  final bool allowed;
  final String code;
  final int? remaining;

  const EntitlementDecision._({
    required this.allowed,
    required this.code,
    this.remaining,
  });

  const EntitlementDecision.allow({int? remaining})
      : this._(
          allowed: true,
          code: 'ENTITLEMENT_ALLOWED',
          remaining: remaining,
        );

  const EntitlementDecision.deny(String code)
      : this._(
          allowed: false,
          code: code,
          remaining: 0,
        );
}

class EntitlementService extends ChangeNotifier {
  EntitlementService._()
      : _uidReader = _firebaseUid,
        _clock = DateTime.now,
        _sessionLoader = ((force) => const CalculatorMcc1BridgeService()
            .issueSession(forceFirebaseRefresh: force));

  @visibleForTesting
  EntitlementService.forTesting({
    required String? Function() uid,
    required DateTime Function() clock,
    required Future<CalculatorMcc1Session> Function(bool force) sessionLoader,
    OfflineEntitlementLease? offlineLease,
  })  : _uidReader = uid,
        _clock = clock,
        _sessionLoader = sessionLoader {
    if (offlineLease != null) _offline = offlineLease;
  }

  late OfflineEntitlementLease _offline = OfflineEntitlementLease(
      publicKey:
          const String.fromEnvironment('MEDCASES_ENTITLEMENT_PUBLIC_KEY'),
      uid: _uidReader,
      now: _clock);
  final String? Function() _uidReader;
  final DateTime Function() _clock;
  final Future<CalculatorMcc1Session> Function(bool force) _sessionLoader;
  Future<EntitlementSnapshot>? _inFlight;
  String? _inFlightUid;
  int _generation = 0;
  DateTime? _validUntil;
  Timer? _expiryTimer;

  static String? _firebaseUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    } // Before Firebase initialization: fail closed.
  }

  static final EntitlementService instance = EntitlementService._();

  static const Duration _trustedSnapshotTtl = Duration(minutes: 5);

  static const Set<MedCasesCapability> _freeCapabilities = {
    MedCasesCapability.home,
    MedCasesCapability.protocolsFull,
    MedCasesCapability.generalCalculators,
    MedCasesCapability.search,
    MedCasesCapability.safetyWarnings,
    MedCasesCapability.publicReferences,
    MedCasesCapability.guidesFull,
    MedCasesCapability.scoresFull,
    MedCasesCapability.drugsEssentialLibrary,
    MedCasesCapability.aiStudy,
    MedCasesCapability.aiPlantao,
    MedCasesCapability.audioBasic,
    MedCasesCapability.transcriptionBasic,
    MedCasesCapability.clinicalHistory,
  };

  static const Set<MedCasesCapability> _premiumCapabilities = {
    ..._freeCapabilities,
    MedCasesCapability.drugsFullLibrary,
    MedCasesCapability.drugsWeightDose,
    MedCasesCapability.drugsRenalAdjustment,
    MedCasesCapability.drugsHepaticAdjustment,
    MedCasesCapability.drugsAdvancedPreparation,
    MedCasesCapability.drugsAdvancedInfusion,
    MedCasesCapability.drugsPediatricResources,
    MedCasesCapability.fullPlantao,
    MedCasesCapability.extendedStudyAi,
    MedCasesCapability.unlimitedClinicalHistory,
    MedCasesCapability.fullOfflinePharma,
    MedCasesCapability.audioLongForm,
    MedCasesCapability.transcriptionExpanded,
  };

  EntitlementSnapshot _trusted = _freeSnapshot(
    source: 'client_fail_closed_default',
    uid: null,
    resolvedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  static EntitlementSnapshot _freeSnapshot({
    required String source,
    required String? uid,
    required DateTime resolvedAtUtc,
  }) {
    return EntitlementSnapshot(
      tier: EntitlementTier.free,
      capabilities: Set.unmodifiable(_freeCapabilities),
      limits: EntitlementLimits.free,
      source: source,
      resolvedUid: uid,
      resolvedAtUtc: resolvedAtUtc,
    );
  }

  static EntitlementSnapshot snapshotForTier(
    EntitlementTier tier, {
    String source = 'contract_test',
  }) {
    return EntitlementSnapshot(
      tier: tier,
      capabilities: tier == EntitlementTier.premium
          ? Set.unmodifiable(_premiumCapabilities)
          : Set.unmodifiable(_freeCapabilities),
      limits: tier == EntitlementTier.premium
          ? EntitlementLimits.premium
          : EntitlementLimits.free,
      source: source,
      resolvedUid: 'contract_test_uid',
      resolvedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  String? get _currentUid => _uidReader();

  bool get isResolvedForCurrentUser {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) return false;
    if (_trusted.resolvedUid != uid) return false;
    if (_trusted.source == 'client_fail_closed_default') return false;

    final now = _clock().toUtc();
    final age = now.difference(_trusted.resolvedAtUtc);
    return age >= Duration.zero &&
        age < _trustedSnapshotTtl &&
        _validUntil != null &&
        now.isBefore(_validUntil!);
  }

  EntitlementSnapshot get current {
    final uid = _currentUid;
    if (!isResolvedForCurrentUser) {
      return _freeSnapshot(
        source:
            uid == null ? 'unauthenticated_free' : 'stale_or_unresolved_free',
        uid: uid,
        resolvedAtUtc: _clock().toUtc(),
      );
    }
    return _trusted;
  }

  bool get isPremium => current.tier == EntitlementTier.premium;

  bool can(MedCasesCapability capability) => current.can(capability);

  /// Access policy only. Clinical authorities must be checked separately.
  Future<bool> restoreOfflineEntitlement() async {
    final generation = _generation;
    final uid = _currentUid;
    final data = await _offline.restore();
    if (data == null || uid != _currentUid || generation != _generation)
      return false;
    final expires = DateTime.fromMillisecondsSinceEpoch(
        (data['exp'] as int) * 1000,
        isUtc: true);
    adoptTrustedSession(
        session: CalculatorMcc1Session(
            token: '',
            tier: data['tier'] as String,
            capabilities: const [],
            expiresAtUtc: expires,
            entitlementSource: 'verified_offline_lease'),
        expectedUid: uid!);
    return isPremium;
  }

  bool canUse(MedCasesCapability capability) => can(capability);
  bool showsPremiumLock(MedCasesCapability capability) => !canUse(capability);
  bool canAccessDrug(String canonicalId) =>
      canonicalId.isNotEmpty &&
      (freeDrugCanonicalIds.contains(canonicalId) ||
          canUse(MedCasesCapability.drugsFullLibrary));

  Future<EntitlementSnapshot> refreshAuthoritativeTier({bool force = false}) {
    if (!force && isResolvedForCurrentUser) return Future.value(current);
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      resetToFree();
      return Future.value(current);
    }
    if (_inFlight != null && _inFlightUid == uid) return _inFlight!;
    final generation = ++_generation;
    _inFlightUid = uid;
    final future = _resolve(uid, generation, force);
    _inFlight = future;
    return future;
  }

  Future<EntitlementSnapshot> _resolve(
      String uid, int generation, bool force) async {
    try {
      final session = await _sessionLoader(force);
      if (generation != _generation || _currentUid != uid) return current;
      adoptTrustedSession(session: session, expectedUid: uid);
    } catch (error) {
      if (generation == _generation && _currentUid == uid) {
        // An in-memory, UID-bound, unexpired signed result remains usable
        // during a network failure. Never extend its validity on failure.
        final networkFailure =
            error is TimeoutException || error is http.ClientException;
        if (networkFailure && !isResolvedForCurrentUser) {
          await restoreOfflineEntitlement();
          if (generation != _generation || uid != _currentUid) return current;
        }
        if (!networkFailure || !isResolvedForCurrentUser) {
          if (!networkFailure) unawaited(_offline.clear());
          _trusted = _freeSnapshot(
              source: 'authoritative_resolution_failed_free',
              uid: uid,
              resolvedAtUtc: _clock().toUtc());
          _validUntil = null;
        }
        if (kDebugMode)
          debugPrint(
              '[EntitlementService] resolution_failed type=${error.runtimeType}');
      }
    } finally {
      if (generation == _generation) {
        _inFlight = null;
        _inFlightUid = null;
        notifyListeners();
      }
    }
    return current;
  }

  /// Only the authenticated issuer flow may call this; never RevenueCat UI or JS.
  void adoptTrustedSession(
      {required CalculatorMcc1Session session, required String expectedUid}) {
    final now = _clock().toUtc();
    if (expectedUid.isEmpty ||
        _currentUid != expectedUid ||
        !session.expiresAtUtc.isAfter(now)) return;
    final resolvedTier = session.tier == 'premium'
        ? EntitlementTier.premium
        : EntitlementTier.free;
    final ttlEnd = now.add(_trustedSnapshotTtl);
    _validUntil =
        session.expiresAtUtc.isBefore(ttlEnd) ? session.expiresAtUtc : ttlEnd;
    _trusted = EntitlementSnapshot(
      tier: resolvedTier,
      capabilities: Set.unmodifiable(resolvedTier == EntitlementTier.premium
          ? _premiumCapabilities
          : _freeCapabilities),
      limits: resolvedTier == EntitlementTier.premium
          ? EntitlementLimits.premium
          : EntitlementLimits.free,
      source: session.entitlementSource.isEmpty
          ? 'signed_calculator_session'
          : session.entitlementSource,
      resolvedUid: expectedUid,
      resolvedAtUtc: now,
    );
    if (session.entitlementSource != 'verified_offline_lease') {
      unawaited(
          _offline.save(session.offlineEntitlement).catchError((Object _) {}));
    }
    _expiryTimer?.cancel();
    _expiryTimer = Timer(_validUntil!.difference(now), notifyListeners);
    notifyListeners();
  }

  Future<EntitlementDecision> consumeAiAllowance({
    required bool isPlantao,
  }) async {
    await refreshAuthoritativeTier();

    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      return const EntitlementDecision.deny('ENTITLEMENT_AUTH_REQUIRED');
    }

    if (isPremium) {
      return const EntitlementDecision.allow();
    }

    final prefs = await SharedPreferences.getInstance();
    if (_currentUid != uid) {
      return const EntitlementDecision.deny('ENTITLEMENT_USER_CHANGED');
    }
    final now = _clock().toUtc();
    final day = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final limit = isPlantao
        ? EntitlementLimits.free.plantaoQueriesPerDay!
        : EntitlementLimits.free.aiStudyQueriesPerDay!;

    final prefix = isPlantao
        ? 'r25a_entitlement_plantao_day'
        : 'r25a_entitlement_ai_study_day';

    final key = '${prefix}_${uid}_$day';
    final used = prefs.getInt(key) ?? 0;

    if (used >= limit) {
      return EntitlementDecision.deny(
        isPlantao
            ? 'FREE_PLANTAO_DAILY_LIMIT_REACHED'
            : 'FREE_AI_STUDY_DAILY_LIMIT_REACHED',
      );
    }

    final next = used + 1;
    await prefs.setInt(key, next);

    return EntitlementDecision.allow(remaining: limit - next);
  }

  Future<EntitlementDecision> consumeClinicalHistoryCreationAllowance() async {
    await refreshAuthoritativeTier();

    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      return const EntitlementDecision.deny('ENTITLEMENT_AUTH_REQUIRED');
    }

    if (isPremium) {
      return const EntitlementDecision.allow();
    }

    final prefs = await SharedPreferences.getInstance();
    if (_currentUid != uid) {
      return const EntitlementDecision.deny('ENTITLEMENT_USER_CHANGED');
    }
    final now = _clock().toUtc();
    final month = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';

    final key = 'r25a_entitlement_history_month_${uid}_$month';
    final limit = EntitlementLimits.free.clinicalHistoriesPerMonth!;
    final used = prefs.getInt(key) ?? 0;

    if (used >= limit) {
      return const EntitlementDecision.deny(
        'FREE_CLINICAL_HISTORY_MONTHLY_LIMIT_REACHED',
      );
    }

    final next = used + 1;
    await prefs.setInt(key, next);

    return EntitlementDecision.allow(remaining: limit - next);
  }

  @override
  void dispose() {
    _generation++;
    _expiryTimer?.cancel();
    super.dispose();
  }

  void resetToFree() {
    unawaited(_offline.clear().catchError((Object _) {}));
    _generation++;
    _inFlight = null;
    _inFlightUid = null;
    _validUntil = null;
    _expiryTimer?.cancel();
    _trusted = _freeSnapshot(
      source: 'explicit_free_reset',
      uid: _currentUid,
      resolvedAtUtc: _clock().toUtc(),
    );
    notifyListeners();
  }
}
