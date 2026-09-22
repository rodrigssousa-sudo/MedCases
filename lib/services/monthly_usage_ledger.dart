import 'server_usage_authority.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'entitlement_service.dart';

enum UsageKind { recording, transcription }

/// One UID/month ledger; reservations prevent concurrent overspend. Amounts are
/// exact milliseconds, not rounded billable minutes. No clinical/user text.
class MonthlyUsageLedger {
  MonthlyUsageLedger(
      {required this.uid,
      required this.now,
      required this.limits,
      required this.preferences,
      this.authority});
  final UsageAuthority? authority;
  final String? Function() uid;
  final DateTime Function() now;
  final EntitlementLimits Function() limits;
  final Future<SharedPreferences> Function() preferences;
  static Future<void> _queue = Future.value();
  static final instance = MonthlyUsageLedger(
      uid: () => FirebaseAuth.instance.currentUser?.uid,
      now: DateTime.now,
      limits: () => EntitlementService.instance.current.limits,
      preferences: SharedPreferences.getInstance,
      authority: ServerUsageAuthority());
  static int _counter = 0;
  static String operationId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  Future<T> _serialized<T>(Future<T> Function() action) {
    final op = _queue.then((_) => action());
    _queue = op.then<void>((_) {}).catchError((Object _) {});
    return op;
  }

  String _month() {
    final n = now().toUtc();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  int _limit(UsageKind kind) =>
      (kind == UsageKind.recording
          ? limits().audioRecordingMinutesPerMonth!
          : limits().transcriptionMinutesPerMonth!) *
      60000;
  Future<UsageReservation> begin(
          {required String operationId,
          required Set<UsageKind> kinds,
          required int maximumMs,
          bool allowPartial = false}) =>
      _serialized(() async {
        final owner = uid();
        if (owner == null || owner.isEmpty)
          throw StateError('USAGE_AUTH_REQUIRED');
        if (operationId.isEmpty || maximumMs <= 0 || kinds.isEmpty)
          throw ArgumentError('INVALID_USAGE');
        final key =
            'usage.v1.${base64Url.encode(utf8.encode(owner))}.${_month()}';
        final prefs = await preferences();
        await prefs.reload();
        if (uid() != owner) throw StateError('USAGE_USER_CHANGED');
        if (authority != null) await _reconcile(prefs, owner);
        final data = _read(prefs, key);
        final prior = data[operationId] as Map?;
        if (prior != null &&
            !(prior['state'] == 'completed' && prior['amount'] == 0))
          throw StateError('USAGE_OPERATION_ALREADY_RESERVED_OR_COMPLETED');
        var attempt = MonthlyUsageLedger.operationId();
        Map<String, dynamic>? receipt;
        var grant = maximumMs;
        for (final kind in authority == null ? kinds : <UsageKind>{}) {
          var used = 0;
          for (final raw in data.values) {
            final op = raw as Map;
            if ((op['kinds'] as List).contains(kind.name))
              used += (op['amount'] as int);
          }
          final remaining = _limit(kind) - used;
          if (remaining < grant) grant = remaining;
        }
        if (grant <= 0 || (!allowPartial && grant < maximumMs))
          throw StateError('MONTHLY_USAGE_LIMIT');
        if (authority != null) {
          receipt = await authority!.reserve(owner, {
            'operationId': operationId,
            'kinds': kinds.map((k) => k.name).toList(),
            'maximumMs': maximumMs,
            'allowPartial': allowPartial,
          });
          if (uid() != owner) throw StateError('USAGE_USER_CHANGED');
          grant = receipt['maximumMs'] as int;
          attempt = receipt['attempt'] as String;
        }
        data[operationId] = {
          if (receipt != null) 'server': receipt,
          'kinds': kinds.map((k) => k.name).toList(),
          'amount': grant,
          'state': 'reserved',
          'attempt': attempt
        };
        if (!await prefs.setString(key, jsonEncode(data)))
          throw StateError('USAGE_WRITE_FAILED');
        return UsageReservation._(this, key, operationId, owner, grant,
            Set.unmodifiable(kinds), attempt, receipt);
      });
  Map<String, dynamic> _read(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return {};
    final data = jsonDecode(raw) as Map<String, dynamic>;
    for (final value in data.values) {
      final op = value as Map;
      if (op['amount'] is! int ||
          op['amount'] < 0 ||
          op['kinds'] is! List ||
          (op['kinds'] as List).isEmpty ||
          (op['kinds'] as List)
              .any((k) => !UsageKind.values.any((v) => v.name == k)) ||
          !['reserved', 'completed'].contains(op['state']))
        throw const FormatException('CORRUPT_USAGE');
    }
    return data;
  }

  Future<void> _finish(
          UsageReservation reservation, int actualMs, bool success) =>
      _serialized(() async {
        if (actualMs < 0 || actualMs > reservation.maximumMs)
          throw ArgumentError('USAGE_OUT_OF_BOUNDS');
        final prefs = await preferences();
        await prefs.reload();
        final data = _read(prefs, reservation.key);
        final op = data[reservation.id] as Map?;
        if (op == null) throw StateError('USAGE_RESERVATION_MISSING');
        if (op['attempt'] != reservation.attempt || op['state'] == 'completed')
          return; // Duplicate callback never charges twice.
        if (authority != null) {
          final receipt = op['server'] as Map?;
          if (receipt == null) throw StateError('SERVER_RESERVATION_REQUIRED');
          op['pendingFinish'] = {
            'id': receipt['id'],
            'attempt': receipt['attempt'],
            'actualMs': actualMs,
            'success': success
          };
        }
        op['amount'] = success ? actualMs : 0;
        op['state'] = 'completed';
        if (!await prefs.setString(reservation.key, jsonEncode(data)))
          throw StateError('USAGE_WRITE_FAILED');
        // Persist completion before network: valid recordings can finish offline.
        // A later operation or explicit reconciliation retries the same attempt.
        if (uid() == reservation.owner)
          await _reconcile(prefs, reservation.owner);
      });
  Future<void> reconcile() => _serialized(() async {
        final owner = uid();
        if (owner != null) await _reconcile(await preferences(), owner);
      });
  Future<void> _reconcile(SharedPreferences prefs, String owner) async {
    if (authority == null || uid() != owner) return;
    final prefix = 'usage.v1.${base64Url.encode(utf8.encode(owner))}.';
    for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
      final data = _read(prefs, key);
      for (final raw in data.values) {
        final op = raw as Map;
        final pending = op['pendingFinish'];
        if (pending is! Map) continue;
        try {
          await authority!.finish(owner, Map<String, dynamic>.from(pending));
          if (uid() != owner) return;
          op.remove('pendingFinish');
          if (!await prefs.setString(key, jsonEncode(data))) return;
        } catch (_) {
          return;
        } // Retain durable pending settlement, never refund locally to server.
      }
    }
  }
}

class UsageReservation {
  UsageReservation._(this._ledger, this.key, this.id, this.owner,
      this.maximumMs, this.kinds, this.attempt, this._server);
  final Map<String, dynamic>? _server;
  Map<String, String> get serverHeaders => _server == null
      ? const {}
      : {
          'X-MedCases-Usage-Reservation': _server['id'] as String,
          'X-MedCases-Usage-Attempt': _server['attempt'] as String,
        };
  final MonthlyUsageLedger _ledger;
  final String key, id, owner, attempt;
  final int maximumMs;
  final Set<UsageKind> kinds;
  bool _finished = false;
  bool authorizes(UsageKind kind) =>
      !_finished && owner == _ledger.uid() && kinds.contains(kind);
  Future<void> finish({required int actualMs, required bool success}) async {
    await _ledger._finish(this, actualMs, success);
    _finished = true;
  }
}
