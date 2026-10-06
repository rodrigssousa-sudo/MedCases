import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/recording_live_activity.dart';

void main() {
  test('capture heartbeat, pause, resume and terminal state are serialized',
      () async {
    final events = <Map<String, Object>>[];
    final activity = RecordingLiveActivity(send: (v) async {
      events.add(v);
    });
    final t = DateTime.utc(2026, 10, 3);
    Future<void> update(String state, int second) => activity.update(
        id: 'qa',
        owner: 'owner',
        status: state,
        elapsedMs: second * 1000,
        isEs: true,
        now: t.add(Duration(seconds: second)));
    await update('recording', 0);
    await update('recording', 1);
    await update('recording', 30);
    await update('paused', 31);
    await update('recording', 32);
    await update('ended', 33);
    expect(events.map((e) => e['status']),
        ['recording', 'recording', 'paused', 'recording', 'ended']);
    expect(
        events.every(
            (e) => !e.containsKey('transcript') && !e.containsKey('path')),
        isTrue);
  });
  test('native failure cannot fail capture; next observation retries',
      () async {
    var calls = 0;
    final activity = RecordingLiveActivity(send: (_) async {
      if (++calls == 1) throw StateError('disabled');
    });
    for (var i = 0; i < 2; i++) {
      await activity.update(
          id: 'qa',
          owner: 'owner',
          status: 'recording',
          elapsedMs: 0,
          isEs: false,
          now: DateTime.utc(2026));
    }
    expect(calls, 2);
  });
  test('owner change is delivered immediately for native identity validation',
      () async {
    final events = <Map<String, Object>>[];
    final activity = RecordingLiveActivity(send: (v) async {
      events.add(v);
    });
    for (final owner in ['first', '']) {
      await activity.update(
          id: owner.isEmpty ? '' : 'qa',
          owner: owner,
          status: owner.isEmpty ? 'ended' : 'recording',
          elapsedMs: 0,
          isEs: false,
          now: DateTime.utc(2026));
    }
    expect(events.last['status'], 'ended');
    expect(events.last['owner'], '');
  });
}
