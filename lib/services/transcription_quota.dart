import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'server_usage_authority.dart';

class TranscriptionQuota {
  const TranscriptionQuota(
      {required this.owner,
      required this.period,
      required this.premium,
      required this.allowanceMs,
      required this.usedMs,
      required this.reservedMs,
      required this.remainingMs,
      this.rangeSupported = false});
  final String owner, period;
  final bool premium, rangeSupported;
  final int allowanceMs, usedMs, reservedMs, remainingMs;
  String get remainingTime {
    final seconds = (remainingMs / 1000).ceil();
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  factory TranscriptionQuota.parse(String owner, Map<String, dynamic> data) {
    final values = ['allowanceMs', 'usedMs', 'reservedMs', 'remainingMs'];
    if (values.any((key) => data[key] is! int || data[key] < 0) ||
        !['free', 'premium'].contains(data['tier']) ||
        data['month'] is! String ||
        !RegExp(r'^\d{4}-\d{2}$').hasMatch(data['month'])) {
      throw StateError('INVALID_QUOTA_BALANCE');
    }
    final expected = (data['allowanceMs'] as int) -
        (data['usedMs'] as int) -
        (data['reservedMs'] as int);
    if (data['remainingMs'] != (expected < 0 ? 0 : expected)) {
      throw StateError('INVALID_QUOTA_BALANCE');
    }
    return TranscriptionQuota(
        owner: owner,
        period: data['month'],
        premium: data['tier'] == 'premium',
        allowanceMs: data['allowanceMs'],
        usedMs: data['usedMs'],
        reservedMs: data['reservedMs'],
        remainingMs: data['remainingMs'],
        rangeSupported: data['transcriptionRangeV1'] == true);
  }
}

class TranscriptionQuotaService {
  TranscriptionQuotaService(
      {required this.uid, required this.authority, required this.preferences});
  final String? Function() uid;
  final TranscriptionBalanceAuthority authority;
  final Future<SharedPreferences> Function() preferences;
  static final instance = TranscriptionQuotaService(
      uid: () => FirebaseAuth.instance.currentUser?.uid,
      authority: ServerUsageAuthority(),
      preferences: SharedPreferences.getInstance);
  Future<TranscriptionQuota> refresh() async {
    final owner = uid();
    if (owner == null) throw StateError('USAGE_AUTH_REQUIRED');
    final data = await authority.balance(owner);
    if (uid() != owner) throw StateError('USAGE_USER_CHANGED');
    return TranscriptionQuota.parse(owner, data);
  }

  Future<void> requireEligibility(
      {Map<String, String> reservationHeaders = const {}}) async {
    final owner = uid();
    if (owner == null) throw StateError('USAGE_AUTH_REQUIRED');
    final gate = authority;
    if (gate is! TranscriptionEligibilityAuthority)
      throw StateError('ELIGIBILITY_UNAVAILABLE');
    await (gate as TranscriptionEligibilityAuthority)
        .eligibility(owner, reservationHeaders: reservationHeaders);
    if (uid() != owner) throw StateError('USAGE_USER_CHANGED');
  }

  Future<void> _presenting = Future.value();

  /// Persist before opening the existing modal. Rebuild/resume cannot reopen it.
  /// Explicit retry is a separate user action, still serialized with presentation.
  Future<TranscriptionQuota> exhausted(
      {required String sessionId,
      required bool audioPersisted,
      required bool explicitAttempt,
      required Future<void> Function() present}) {
    final result = _presenting.then((_) async {
      var balance = await refresh();
      if (!audioPersisted || balance.premium || balance.remainingMs > 0)
        return balance;
      final key = 'transcription.paywall.v1.' +
          base64Url.encode(utf8.encode(balance.owner)) +
          '.' +
          balance.period +
          '.' +
          sessionId;
      final prefs = await preferences();
      if (uid() != balance.owner) throw StateError('USAGE_USER_CHANGED');
      if (!explicitAttempt && prefs.getBool(key) == true) return balance;
      if (!await prefs.setBool(key, true))
        throw StateError('QUOTA_EVENT_WRITE_FAILED');
      await present();
      // Do not grant 90 minutes locally after a purchase or dismissal.
      return refresh();
    });
    _presenting = result.then<void>((_) {}).catchError((Object _) {});
    return result;
  }
}
