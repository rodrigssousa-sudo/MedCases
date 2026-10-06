import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Presentation only: never starts capture, reserves quota, or sends audio.
class RecordingLiveActivity {
  RecordingLiveActivity({Future<void> Function(Map<String, Object>)? send})
      : _send = send ?? _native;
  final Future<void> Function(Map<String, Object>) _send;
  static Future<void> _native(Map<String, Object> state) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    await const MethodChannel('medcases/organization_v1')
        .invokeMethod<void>('recordingActivity', state);
  }

  Future<void> _queue = Future.value();
  String? _key;
  DateTime? _last;
  Future<void> update(
      {required String id,
      required String owner,
      required String status,
      required int elapsedMs,
      required bool isEs,
      required DateTime now}) {
    final key = '$owner/$id/$status/$isEs';
    if (_key == key &&
        (status != 'recording' ||
            (_last != null && now.difference(_last!).inSeconds < 30))) {
      return _queue;
    }
    _key = key;
    _last = now;
    final state = <String, Object>{
      'id': id,
      'owner': owner,
      'status': status,
      'elapsedMs': elapsedMs < 0 ? 0 : elapsedMs,
      'isEs': isEs,
      'sampleTimeMs': now.millisecondsSinceEpoch
    };
    _queue = _queue.then((_) => _send(state)).catchError((Object _) {
      // Native presentation failures cannot affect the recording state machine.
      if (_key == key) {
        _key = null;
        _last = null;
      }
    });
    return _queue;
  }
}
