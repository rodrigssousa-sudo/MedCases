import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String runtime;
  late String session;

  setUpAll(() {
    runtime = File('lib/screens/notes_audio_local_runtime_screen_io.dart')
        .readAsStringSync();
    session =
        File('lib/services/audio/clinical_long_form_recording_session.dart')
            .readAsStringSync();
  });

  test('recorded Study runtime uses app-support durable storage', () {
    final start = runtime.indexOf(
      'class _NotesAudioLongFormLocalRuntimeScreenState',
    );
    expect(start, greaterThanOrEqualTo(0));

    final owner = runtime.substring(start);

    expect(owner, contains('getApplicationSupportDirectory()'));
    expect(owner, isNot(contains('getTemporaryDirectory()')));
    expect(owner, contains('FileClinicalLongFormDurableStore'));
    expect(owner, contains('saveManifest'));
    expect(owner, contains('medcases_study_recorded_audio_state'));
  });

  test('stop requested during five-minute rotation is latched', () {
    final ownerStart = runtime.indexOf(
      'class _NotesAudioLongFormLocalRuntimeScreenState',
    );
    final owner = runtime.substring(ownerStart);

    expect(owner, contains('bool _rotationInFlight = false;'));
    expect(owner, contains('bool _stopRequested = false;'));
    expect(
      owner,
      contains('shouldStopAfterCurrentSegment: () => _stopRequested'),
    );
    expect(
      owner,
      contains(
          'if (_busy || _rotationInFlight) {\n      _stopRequested = true;'),
    );

    final rotateStart = session.indexOf('Future<void> rotate({');
    final rotateEnd = session.indexOf('Future<void> stop(', rotateStart);
    expect(rotateStart, greaterThanOrEqualTo(0));
    expect(rotateEnd, greaterThan(rotateStart));

    final rotate = session.substring(rotateStart, rotateEnd);
    expect(
      rotate,
      contains('bool Function()? shouldStopAfterCurrentSegment'),
    );

    final complete = rotate.indexOf('_completeCurrentSegment();');
    final latch = rotate.indexOf('shouldStopAfterCurrentSegment?.call()');
    final reopen = rotate.indexOf('await _startSegment(nextSegmentPath, now);');

    expect(complete, greaterThanOrEqualTo(0));
    expect(latch, greaterThan(complete));
    expect(reopen, greaterThan(latch));
  });

  test('final handoff is not suppressed by manifest persistence failure', () {
    final ownerStart = runtime.indexOf(
      'class _NotesAudioLongFormLocalRuntimeScreenState',
    );
    final owner = runtime.substring(ownerStart);
    final stopStart = owner.indexOf('Future<void> _stop() async');
    final buildStart = owner.indexOf(
      '@override\n  Widget build(BuildContext context)',
      stopStart,
    );

    expect(stopStart, greaterThanOrEqualTo(0));
    expect(buildStart, greaterThan(stopStart));

    final stop = owner.substring(stopStart, buildStart);
    expect(stop, contains('Object? persistenceError;'));
    expect(stop, contains('await _persistManifest(manifest);'));
    expect(stop, contains('widget.onCompleted?.call('));

    final persistence = stop.indexOf('await _persistManifest(manifest);');
    final handoff = stop.indexOf('widget.onCompleted?.call(');
    expect(handoff, greaterThan(persistence));
  });

  test('this patch does not flip native/remote production cutover flags', () {
    final provider =
        File('lib/services/audio/record_long_form_audio_provider.dart')
            .readAsStringSync();

    expect(
      provider,
      contains('static const bool productionCutoverEnabled = false;'),
    );
    expect(
      provider,
      contains('static const bool productionPersistenceEnabled = false;'),
    );
    expect(
      provider,
      contains('static const bool remoteUploadEnabled = false;'),
    );
  });
}
