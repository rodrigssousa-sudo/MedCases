import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/server_usage_authority.dart';
import 'package:medcases/services/monthly_usage_ledger.dart';
import 'package:medcases/services/entitlement_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'productive ledger requires server reservation, mirrors grant, and reconciles same attempt after restart',
      () async {
    String? uid = 'A';
    var offline = false;
    var finished = 0;
    var reserved = 0;
    final authority = ServerUsageAuthority(
        uid: () => uid,
        token: () async => 'firebase-token',
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer firebase-token');
          final body = jsonDecode(request.body) as Map;
          expect(body.containsKey('uid'), false);
          if (offline) throw Exception('network');
          if (request.url.path.endsWith('/reserve')) {
            reserved++;
            return http.Response(
                jsonEncode({
                  'id': 'a' * 64,
                  'attempt': 'server-attempt',
                  'maximumMs': 1000,
                  'state': 'reserved',
                  'month': '2026-09'
                }),
                200);
          }
          expect(body['attempt'], 'server-attempt');
          expect(body['actualMs'], 500);
          finished++;
          return http.Response('{"state":"completed","chargedMs":500}', 200);
        }));
    MonthlyUsageLedger ledger() => MonthlyUsageLedger(
        uid: () => uid,
        now: () => DateTime.utc(2026, 9, 21),
        limits: () => EntitlementLimits.free,
        preferences: SharedPreferences.getInstance,
        authority: authority);
    offline = true;
    await expectLater(
        ledger().begin(
            operationId: 'unavailable',
            kinds: {UsageKind.recording},
            maximumMs: 2000,
            allowPartial: true),
        throwsException);
    expect(reserved, 0);
    offline = false;
    final reservation = await ledger().begin(
        operationId: 'record',
        kinds: {UsageKind.recording},
        maximumMs: 2000,
        allowPartial: true);
    expect(reservation.maximumMs, 1000);
    expect(reservation.authorizes(UsageKind.recording), true);
    offline = true;
    await reservation.finish(actualMs: 500, success: true);
    expect(finished, 0);
    uid = 'B';
    expect(reservation.authorizes(UsageKind.recording), false);
    offline = false;
    await ledger().reconcile();
    expect(finished, 0);
    uid = 'A';
    await ledger().reconcile();
    expect(finished, 1);
    await reservation.finish(actualMs: 500, success: true);
    await ledger().reconcile();
    expect(finished, 1);
  });
  test('server quota denial overrides available local preferences', () async {
    final authority = ServerUsageAuthority(
        uid: () => 'A',
        token: () async => 'token',
        client: MockClient((_) async => http.Response('{}', 429)));
    final ledger = MonthlyUsageLedger(
        uid: () => 'A',
        now: DateTime.now,
        limits: () => EntitlementLimits.premium,
        preferences: SharedPreferences.getInstance,
        authority: authority);
    await expectLater(
        ledger.begin(
            operationId: 'x', kinds: {UsageKind.transcription}, maximumMs: 1),
        throwsStateError);
  });
}
