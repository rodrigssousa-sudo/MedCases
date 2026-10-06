import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/services/transcription_quota.dart';
import 'package:medcases/services/server_usage_authority.dart';

class Authority implements TranscriptionBalanceAuthority {
  String tier = 'free';
  int used = 900000;
  int reserved = 0;
  int reads = 0;
  @override
  Future<Map<String, dynamic>> balance(String owner) async {
    reads++;
    final allowance = tier == 'free' ? 900000 : 5400000;
    return {
      'month': '2026-09',
      'tier': tier,
      'allowanceMs': allowance,
      'usedMs': used,
      'reservedMs': reserved,
      'remainingMs': allowance - used - reserved
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Authority authority;
  late TranscriptionQuotaService service;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authority = Authority();
    service = TranscriptionQuotaService(
        uid: () => 'owner',
        authority: authority,
        preferences: SharedPreferences.getInstance);
  });
  test(
      'Free automatic exhaustion persists guard across rebuild/restart/dismissal',
      () async {
    var calls = 0;
    Future<void> show() async {
      calls++;
    }

    for (var i = 0; i < 3; i++)
      await service.exhausted(
          sessionId: 'same',
          audioPersisted: true,
          explicitAttempt: false,
          present: show);
    service = TranscriptionQuotaService(
        uid: () => 'owner',
        authority: authority,
        preferences: SharedPreferences.getInstance);
    await service.exhausted(
        sessionId: 'same',
        audioPersisted: true,
        explicitAttempt: false,
        present: show);
    expect(calls, 1);
    await service.exhausted(
        sessionId: 'same',
        audioPersisted: true,
        explicitAttempt: true,
        present: show);
    expect(calls, 2);
  });
  test('never present before audio persisted or upsell Premium', () async {
    var calls = 0;
    await service.exhausted(
        sessionId: 's',
        audioPersisted: false,
        explicitAttempt: false,
        present: () async {
          calls++;
        });
    authority.tier = 'premium';
    authority.used = 5400000;
    await service.exhausted(
        sessionId: 's',
        audioPersisted: true,
        explicitAttempt: true,
        present: () async {
          calls++;
        });
    expect(calls, 0);
  });
  test('upgrade re-queries authority rather than granting full premium',
      () async {
    final result = await service.exhausted(
        sessionId: 'original',
        audioPersisted: true,
        explicitAttempt: true,
        present: () async {
          authority.tier = 'premium';
          authority.used = 1200000;
        });
    expect(result.remainingMs, 70 * 60000);
    expect(authority.reads, 2);
  });
  test('cumulative balance survives new session and language UI independent',
      () async {
    authority.used = 6 * 60000;
    expect((await service.refresh()).remainingMs, 9 * 60000);
    expect((await service.refresh()).remainingMs, 9 * 60000);
    authority.tier = 'premium';
    authority.used = 20 * 60000;
    expect((await service.refresh()).remainingMs, 70 * 60000);
  });
  test('malformed balance fails closed', () {
    expect(
        () => TranscriptionQuota.parse('owner', {
              'month': '2026-09',
              'tier': 'free',
              'allowanceMs': 900000,
              'usedMs': 60000,
              'reservedMs': 60000,
              'remainingMs': 900000
            }),
        throwsStateError);
  });
}
