import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/calculator_mcc1_bridge_service.dart';

void main() {
  group('CalculatorMcc1BridgeService.parseIssuedSession', () {
    test('accepts production issuer response shape', () {
      final session = CalculatorMcc1BridgeService.parseIssuedSession(
        statusCode: 200,
        body: '''
{
  "ok": true,
  "accessToken": "mcc1.payload.signature",
  "tier": "premium",
  "capabilities": ["scores", "drug_catalog_full"],
  "expiresAtUtc": "2099-09-14T22:30:00.000Z",
  "entitlementSource": "server_plan"
}
''',
      );

      expect(session.token, 'mcc1.payload.signature');
      expect(session.tier, 'premium');
      expect(session.capabilities, contains('drug_catalog_full'));
      expect(session.expiresAtUtc, DateTime.utc(2099, 9, 14, 22, 30));
      expect(session.entitlementSource, 'server_plan');
    });

    test('rejects non-MCC1 token material', () {
      expect(
        () => CalculatorMcc1BridgeService.parseIssuedSession(
          statusCode: 200,
          body: '''
{
  "accessToken": "not-a-calculator-session",
  "tier": "free",
  "capabilities": [],
  "expiresAtUtc": "2099-09-14T22:30:00.000Z"
}
''',
        ),
        throwsA(isA<CalculatorMcc1BridgeException>()),
      );
    });

    test('rejects non-200 issuer response without exposing body', () {
      expect(
        () => CalculatorMcc1BridgeService.parseIssuedSession(
          statusCode: 401,
          body: '{"error":"unauthorized"}',
        ),
        throwsA(
          isA<CalculatorMcc1BridgeException>().having(
            (e) => e.code,
            'code',
            'ISSUER_HTTP_401',
          ),
        ),
      );
    });
  });
}
