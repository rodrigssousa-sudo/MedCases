import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum RevenueCatPlan { monthly, annual }

class RevenueCatBillingException implements Exception {
  const RevenueCatBillingException(this.code);
  final String code;
  @override
  String toString() => 'RevenueCatBillingException($code)';
}

class RevenueCatCatalog {
  const RevenueCatCatalog(
      {required this.monthlyPrice, required this.annualPrice});
  final String monthlyPrice;
  final String annualPrice;
}

class RevenueCatPurchaseOutcome {
  const RevenueCatPurchaseOutcome(
      {required this.cancelled, required this.storeEntitlementActive});
  final bool cancelled;
  final bool storeEntitlementActive;
}

class RevenueCatBillingService {
  RevenueCatBillingService._();
  static final RevenueCatBillingService instance = RevenueCatBillingService._();

  static const entitlementIdentifier = 'medcases_pro_premium';
  static const offeringIdentifier = 'default';
  static const monthlyPackageIdentifier = r'$rc_monthly';
  static const annualPackageIdentifier = r'$rc_annual';

  // Public SDK keys. Never place RevenueCat Secret API keys in the client.
  static const _applePublicSdkKey = 'appl_BhPlakoQItDPCjxqvzjZZwNHFiA';
  static const _googlePublicSdkKey = 'goog_ZHSMuRwvJKtScPTiNSRKUzVePji';

  bool _configured = false;
  String? _configuredUid;

  bool get isStoreSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  String _platformKey() {
    if (defaultTargetPlatform == TargetPlatform.iOS) return _applePublicSdkKey;
    if (defaultTargetPlatform == TargetPlatform.android)
      return _googlePublicSdkKey;
    throw const RevenueCatBillingException('STORE_PLATFORM_UNSUPPORTED');
  }

  Future<void> ensureConfiguredForCurrentUser() async {
    if (!isStoreSupported) {
      throw const RevenueCatBillingException('STORE_PLATFORM_UNSUPPORTED');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid.trim().isEmpty) {
      throw const RevenueCatBillingException('FIREBASE_AUTH_REQUIRED');
    }
    final uid = user.uid.trim();
    if (!_configured) {
      final config = PurchasesConfiguration(_platformKey())..appUserID = uid;
      await Purchases.configure(config);
      _configured = true;
      _configuredUid = uid;
      return;
    }
    if (_configuredUid != uid) {
      await Purchases.logIn(uid);
      _configuredUid = uid;
    }
  }

  Future<Offering> _offering() async {
    await ensureConfiguredForCurrentUser();
    final offerings = await Purchases.getOfferings();
    final offering =
        offerings.getOffering(offeringIdentifier) ?? offerings.current;
    if (offering == null) {
      throw const RevenueCatBillingException('DEFAULT_OFFERING_UNAVAILABLE');
    }
    return offering;
  }

  Package _package(Offering offering, RevenueCatPlan plan) {
    final expected = plan == RevenueCatPlan.monthly
        ? monthlyPackageIdentifier
        : annualPackageIdentifier;
    for (final package in offering.availablePackages) {
      if (package.identifier == expected) return package;
    }
    throw RevenueCatBillingException(
      plan == RevenueCatPlan.monthly
          ? 'MONTHLY_PACKAGE_UNAVAILABLE'
          : 'ANNUAL_PACKAGE_UNAVAILABLE',
    );
  }

  Future<RevenueCatCatalog> loadCatalog() async {
    final offering = await _offering();
    final monthly = _package(offering, RevenueCatPlan.monthly);
    final annual = _package(offering, RevenueCatPlan.annual);
    return RevenueCatCatalog(
      monthlyPrice: monthly.storeProduct.priceString,
      annualPrice: annual.storeProduct.priceString,
    );
  }

  Future<RevenueCatPurchaseOutcome> purchase(RevenueCatPlan plan) async {
    try {
      final offering = await _offering();
      final package = _package(offering, plan);
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return RevenueCatPurchaseOutcome(
        cancelled: false,
        storeEntitlementActive: result.customerInfo.entitlements.active
            .containsKey(entitlementIdentifier),
      );
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return const RevenueCatPurchaseOutcome(
          cancelled: true,
          storeEntitlementActive: false,
        );
      }
      throw RevenueCatBillingException('PURCHASE_${code.name.toUpperCase()}');
    }
  }

  Future<RevenueCatPurchaseOutcome> restorePurchases() async {
    try {
      await ensureConfiguredForCurrentUser();
      final info = await Purchases.restorePurchases();
      return RevenueCatPurchaseOutcome(
        cancelled: false,
        storeEntitlementActive:
            info.entitlements.active.containsKey(entitlementIdentifier),
      );
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      throw RevenueCatBillingException('RESTORE_${code.name.toUpperCase()}');
    }
  }
}
