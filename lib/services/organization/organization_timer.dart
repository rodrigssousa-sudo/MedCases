import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Clock ticks only repaint. The persisted deadline owns elapsed time.
enum OrganizationTimerStatus { idle, running, paused, finished }

class OrganizationTimerState {
  const OrganizationTimerState(
      {required this.timerId,
      required this.durationSeconds,
      required this.status,
      this.startedAt,
      this.targetEndTime,
      this.pausedAt,
      this.remainingWhenPaused = 0});
  final String timerId;
  final int durationSeconds;
  final OrganizationTimerStatus status;
  final DateTime? startedAt, targetEndTime, pausedAt;
  final int remainingWhenPaused;
  int remaining(DateTime now) => switch (status) {
        OrganizationTimerStatus.running =>
          ((targetEndTime!.difference(now).inMilliseconds / 1000).ceil())
              .clamp(0, durationSeconds),
        OrganizationTimerStatus.paused => remainingWhenPaused,
        OrganizationTimerStatus.idle => durationSeconds,
        OrganizationTimerStatus.finished => 0,
      };
  Map<String, dynamic> toJson() => {
        'timerId': timerId,
        'durationSeconds': durationSeconds,
        'status': status.name,
        'startedAt': startedAt?.toUtc().toIso8601String(),
        'targetEndTime': targetEndTime?.toUtc().toIso8601String(),
        'pausedAt': pausedAt?.toUtc().toIso8601String(),
        'remainingWhenPaused': remainingWhenPaused
      };
  static OrganizationTimerState fromJson(Map<String, dynamic> j) {
    DateTime? date(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    final state = OrganizationTimerState(
        timerId: j['timerId'] as String,
        durationSeconds: j['durationSeconds'] as int,
        status: OrganizationTimerStatus.values.byName(j['status'] as String),
        startedAt: date('startedAt'),
        targetEndTime: date('targetEndTime'),
        pausedAt: date('pausedAt'),
        remainingWhenPaused: j['remainingWhenPaused'] as int);
    if (state.durationSeconds <= 0 ||
        state.remainingWhenPaused < 0 ||
        state.remainingWhenPaused > state.durationSeconds ||
        (state.status == OrganizationTimerStatus.running &&
            state.targetEndTime == null)) {
      throw const FormatException('INVALID_TIMER_STATE');
    }
    return state;
  }
}

abstract interface class OrganizationTimerStore {
  Future<OrganizationTimerState?> read();
  Future<void> write(OrganizationTimerState? state);
}

class PreferencesTimerStore implements OrganizationTimerStore {
  static const key = 'organization_timer_r1';
  @override
  Future<OrganizationTimerState?> read() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    if (raw == null) return null;
    return OrganizationTimerState.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  @override
  Future<void> write(OrganizationTimerState? state) async {
    final prefs = await SharedPreferences.getInstance();
    final ok = state == null
        ? await prefs.remove(key)
        : await prefs.setString(key, jsonEncode(state.toJson()));
    if (!ok) throw StateError('TIMER_PERSISTENCE_FAILED');
  }
}

abstract interface class OrganizationTimerAlerts {
  Future<void> schedule(OrganizationTimerState state);
  Future<void> cancel();
  Future<void> present(OrganizationTimerState state);
}

class OrganizationTimerController extends ChangeNotifier {
  OrganizationTimerController(
      {required this.store, required this.alerts, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;
  final OrganizationTimerStore store;
  final OrganizationTimerAlerts alerts;
  final DateTime Function() clock;
  OrganizationTimerState? state;
  bool _busy = false;
  bool get busy => _busy;
  // Serialize gestures to prevent a delayed schedule from resurrecting a canceled timer.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _save(OrganizationTimerState? next) async {
    await store.write(next);
    state = next;
    notifyListeners();
  }

  Future<void> restore() => _run(() async {
        state = await store.read();
        await _reconcile();
      });
  Future<void> reconcile() => _run(_reconcile);
  Future<void> _reconcile() async {
    final current = state;
    if (current == null) {
      await alerts.cancel();
      return;
    }
    if (current.status == OrganizationTimerStatus.running &&
        current.remaining(clock()) == 0) {
      await _save(OrganizationTimerState(
          timerId: current.timerId,
          durationSeconds: current.durationSeconds,
          status: OrganizationTimerStatus.finished,
          startedAt: current.startedAt,
          targetEndTime: current.targetEndTime));
      // Keep the delivered final alert; only active presentation is ended.
      await alerts.present(state!);
    } else if (current.status == OrganizationTimerStatus.running) {
      await alerts.schedule(current);
      await alerts.present(current);
    } else {
      await alerts.cancel();
      await alerts.present(current);
    }
  }

  Future<void> start(int seconds) => _run(() async {
        if (seconds <= 0) throw ArgumentError.value(seconds);
        await alerts.cancel();
        final now = clock();
        await _save(OrganizationTimerState(
            timerId: now.microsecondsSinceEpoch.toString(),
            durationSeconds: seconds,
            status: OrganizationTimerStatus.running,
            startedAt: now,
            targetEndTime: now.add(Duration(seconds: seconds))));
        await alerts.schedule(state!);
        await alerts.present(state!);
      });
  Future<void> pause() => _run(() async {
        final current = state;
        if (current == null ||
            current.status != OrganizationTimerStatus.running) {
          return;
        }
        if (current.remaining(clock()) == 0) {
          await _reconcile();
          return;
        }
        await _save(OrganizationTimerState(
            timerId: current.timerId,
            durationSeconds: current.durationSeconds,
            status: OrganizationTimerStatus.paused,
            startedAt: current.startedAt,
            targetEndTime: current.targetEndTime,
            pausedAt: clock(),
            remainingWhenPaused: current.remaining(clock())));
        await alerts.cancel();
        await alerts.present(state!);
      });
  Future<void> resume() => _run(() async {
        final current = state;
        if (current == null ||
            current.status != OrganizationTimerStatus.paused) {
          return;
        }
        await _save(OrganizationTimerState(
            timerId: current.timerId,
            durationSeconds: current.durationSeconds,
            status: OrganizationTimerStatus.running,
            startedAt: current.startedAt,
            targetEndTime:
                clock().add(Duration(seconds: current.remainingWhenPaused))));
        await alerts.schedule(state!);
        await alerts.present(state!);
      });
  Future<void> reset() => _run(() async {
        final current = state;
        if (current == null) return;
        await _save(OrganizationTimerState(
            timerId: current.timerId,
            durationSeconds: current.durationSeconds,
            status: OrganizationTimerStatus.idle));
        await alerts.cancel();
        await alerts.present(state!);
      });
  Future<void> cancel() => _run(() async {
        await _save(null);
        await alerts.cancel();
      });
}
