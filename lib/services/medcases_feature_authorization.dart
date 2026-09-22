import 'entitlement_service.dart';

/// Caller labels are audit metadata, never a source of permissions.
enum FeatureEntryPoint {
  homeSearch,
  globalSearch,
  drugsScreen,
  showDrugDetail,
  favorites,
  recents,
  directNavigator,
  namedRoute,
  deeplink,
  restoredNavigation,
  aiAction,
  studyAction,
  plantaoAction,
  calculator,
  offlineRestoredScreen,
}

class FeatureTarget {
  const FeatureTarget.capability(this.capability) : canonicalDrugId = null;
  const FeatureTarget.drug(String id)
      : canonicalDrugId = id,
        capability = null;
  final String? canonicalDrugId;
  final MedCasesCapability? capability;

  /// Search text is discovery, not a canonical identity. The resource owner
  /// separately authorizes any resulting document or pharmacological action.
  factory FeatureTarget.calculator(String? url) {
    final uri = Uri.tryParse(url ?? '');
    final tab = uri?.queryParameters['tab'];
    final id = uri?.queryParameters['drugId'];
    if (tab == 'infusao' || tab == 'infusion') {
      return const FeatureTarget.capability(
          MedCasesCapability.drugsAdvancedInfusion);
    }
    if (tab == 'dose' || tab == 'dose_by_weight') {
      return const FeatureTarget.capability(MedCasesCapability.drugsWeightDose);
    }
    if (tab == 'renal_adjustment') {
      return const FeatureTarget.capability(
          MedCasesCapability.drugsRenalAdjustment);
    }
    if (id != null) return FeatureTarget.drug(id);
    return const FeatureTarget.capability(
        MedCasesCapability.generalCalculators);
  }
}

/// Single feature boundary. Billing, Free60 and expiration remain owned solely
/// by EntitlementService. This facade cannot grant any clinical authority.
class MedCasesFeatureAuthorization {
  MedCasesFeatureAuthorization(this.entitlement);
  final EntitlementService entitlement;
  static final instance =
      MedCasesFeatureAuthorization(EntitlementService.instance);
  bool allows(FeatureTarget target) {
    final id = target.canonicalDrugId;
    if (id != null) {
      return RegExp(r'^[a-z0-9_]+$').hasMatch(id) &&
          entitlement.canAccessDrug(id);
    }
    return target.capability != null && entitlement.can(target.capability!);
  }

  Future<bool> authorize(
    FeatureTarget target, {
    required FeatureEntryPoint entrypoint,
    Future<void> Function()? presentPaywall,
  }) async {
    await entitlement.refreshAuthoritativeTier();
    final owner = entitlement.current.resolvedUid;
    if (!allows(target)) {
      if (presentPaywall == null) return false;
      await presentPaywall();
    }
    return owner == entitlement.current.resolvedUid && allows(target);
  }

  Future<T?> execute<T>(
    FeatureTarget target, {
    required FeatureEntryPoint entrypoint,
    required Future<T> Function() action,
    Future<void> Function()? presentPaywall,
  }) async {
    if (!await authorize(target,
        entrypoint: entrypoint, presentPaywall: presentPaywall)) return null;
    if (!allows(target)) return null;
    final owner = entitlement.current.resolvedUid;
    final value = await action();
    if (owner != entitlement.current.resolvedUid || !allows(target))
      return null;
    return value;
  }
}
