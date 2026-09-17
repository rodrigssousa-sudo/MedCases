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
// - essential drug library (400) through signed MCC1 surface
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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'calculator_mcc1_bridge_service.dart';

enum EntitlementTier { free, premium }

enum MedCasesCapability {
  guidesFull,
  scoresFull,
  drugsEssentialLibrary,
  drugsFullLibrary,
  drugsWeightDose,
  drugsRenalAdjustment,
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

  static const free = EntitlementLimits(
    drugLibraryItems: 400,
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
  EntitlementService._();

  static final EntitlementService instance = EntitlementService._();

  static const Duration _trustedSnapshotTtl = Duration(minutes: 5);

  static const Set<MedCasesCapability> _freeCapabilities = {
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
    MedCasesCapability.audioLongForm,
    MedCasesCapability.transcriptionExpanded,
  };

  EntitlementSnapshot _trusted = _freeSnapshot(
    source: 'client_fail_closed_default',
    uid: null,
    resolvedAtUtc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  bool _resolving = false;

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

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  bool get isResolvedForCurrentUser {
    final uid = _currentUid;
    if (uid == null || uid.isEmpty) return false;
    if (_trusted.resolvedUid != uid) return false;
    if (_trusted.source == 'client_fail_closed_default') return false;

    final age = DateTime.now().toUtc().difference(_trusted.resolvedAtUtc);
    return age >= Duration.zero && age <= _trustedSnapshotTtl;
  }

  EntitlementSnapshot get current {
    final uid = _currentUid;
    if (!isResolvedForCurrentUser) {
      return _freeSnapshot(
        source:
            uid == null ? 'unauthenticated_free' : 'stale_or_unresolved_free',
        uid: uid,
        resolvedAtUtc: DateTime.now().toUtc(),
      );
    }
    return _trusted;
  }

  bool get isPremium => current.tier == EntitlementTier.premium;

  bool can(MedCasesCapability capability) => current.can(capability);

  Future<EntitlementSnapshot> refreshAuthoritativeTier({
    bool force = false,
  }) async {
    if (!force && isResolvedForCurrentUser) return current;

    if (_resolving) return current;

    final uid = _currentUid;
    if (uid == null || uid.isEmpty) {
      _trusted = _freeSnapshot(
        source: 'unauthenticated_free',
        uid: null,
        resolvedAtUtc: DateTime.now().toUtc(),
      );
      notifyListeners();
      return current;
    }

    _resolving = true;
    notifyListeners();

    try {
      final session = await const CalculatorMcc1BridgeService().issueSession(
        forceFirebaseRefresh: force,
      );

      adoptTrustedSession(
        tier: session.tier,
        entitlementSource: session.entitlementSource,
      );
    } catch (error) {
      _trusted = _freeSnapshot(
        source: 'authoritative_resolution_failed_free',
        uid: uid,
        resolvedAtUtc: DateTime.now().toUtc(),
      );

      if (kDebugMode) {
        debugPrint(
          '[EntitlementService] resolution_failed '
          'type=${error.runtimeType} tier=free',
        );
      }
    } finally {
      _resolving = false;
      notifyListeners();
    }

    return current;
  }

  void adoptTrustedSession({
    required String tier,
    required String entitlementSource,
  }) {
    final uid = _currentUid;
    final normalizedTier = tier.trim().toLowerCase();
    final resolvedTier = normalizedTier == 'premium'
        ? EntitlementTier.premium
        : EntitlementTier.free;

    _trusted = EntitlementSnapshot(
      tier: resolvedTier,
      capabilities: resolvedTier == EntitlementTier.premium
          ? Set.unmodifiable(_premiumCapabilities)
          : Set.unmodifiable(_freeCapabilities),
      limits: resolvedTier == EntitlementTier.premium
          ? EntitlementLimits.premium
          : EntitlementLimits.free,
      source: entitlementSource.trim().isEmpty
          ? 'signed_calculator_session'
          : entitlementSource.trim(),
      resolvedUid: uid,
      resolvedAtUtc: DateTime.now().toUtc(),
    );

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
    final now = DateTime.now().toUtc();
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
    final now = DateTime.now().toUtc();
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

  void resetToFree() {
    _trusted = _freeSnapshot(
      source: 'explicit_free_reset',
      uid: _currentUid,
      resolvedAtUtc: DateTime.now().toUtc(),
    );
    notifyListeners();
  }
}
