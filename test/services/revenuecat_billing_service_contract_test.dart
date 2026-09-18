import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RevenueCat client is store layer, server remains entitlement authority',
      () {
    final billing =
        File('lib/services/revenuecat_billing_service.dart').readAsStringSync();
    final sheet =
        File('lib/screens/revenuecat_purchase_sheet.dart').readAsStringSync();
    expect(billing.contains("entitlementIdentifier = 'medcases_pro_premium'"),
        isTrue);
    expect(billing.contains("offeringIdentifier = 'default'"), isTrue);
    expect(billing.contains(r"r'$rc_monthly'"), isTrue);
    expect(billing.contains(r"r'$rc_annual'"), isTrue);
    expect(billing.contains('..appUserID = uid'), isTrue);
    expect(billing.contains('Purchases.restorePurchases()'), isTrue);
    expect(billing.contains('adoptTrustedSession'), isFalse);
    expect(sheet.contains('refreshAuthoritativeTier(force: true)'), isTrue);
  });
}
