import 'dart:io';
import 'dart:async';
import '../monthly_usage_ledger.dart';
import '../entitlement_service.dart';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'clinical_long_form_audio_contract.dart';

final class RecordLongFormAudioProvider implements ClinicalLongFormFileCapture {
  static const MethodChannel _backgroundGuardChannel =
      MethodChannel('medcases/recording_background_guard_v1');

  RecordLongFormAudioProvider({
    AudioRecorder? recorder,
    this.onQuotaReached,
    MonthlyUsageLedger? usageLedger,
    Future<void> Function()? refreshEntitlement,
  })  : _recorder = recorder ?? AudioRecorder(),
        _ledger = usageLedger ?? MonthlyUsageLedger.instance,
        _refreshEntitlement = refreshEntitlement ??
            (() async {
              await EntitlementService.instance.refreshAuthoritativeTier();
            });

  static const bool productionCutoverEnabled = false;
  static const bool productionPersistenceEnabled = false;
  static const bool remoteUploadEnabled = false;

  final AudioRecorder _recorder;
  final MonthlyUsageLedger _ledger;
  final Future<void> Function() _refreshEntitlement;
  final void Function()? onQuotaReached;
  Future<void> _quotaReached() async {
    if (!_active) return;
    _usageClock?.stop();
    await _recorder.pause();
    if (onQuotaReached != null) {
      onQuotaReached!();
    } else {
      _quotaStoppedPath = await stopSegment();
    }
  }

  String? _quotaStoppedPath;
  UsageReservation? _usage;
  Stopwatch? _usageClock;
  Timer? _usageTimer;
  Future<void> _finishUsage(bool success) async {
    final usage = _usage;
    _usage = null;
    _usageTimer?.cancel();
    final ms = _usageClock?.elapsedMilliseconds ?? 0;
    _usageClock?.stop();
    if (usage != null)
      await usage.finish(
          actualMs: ms.clamp(0, usage.maximumMs), success: success);
  }

  bool _active = false;
  bool _starting = false;
  Future<String?>? _stopFlight;
  bool _disposed = false;
  bool _iosAudioSessionPrepared = false;
  bool _androidBackgroundGuardActive = false;

  static RecordConfig buildRecordConfig(
    ClinicalLongFormRecordingConfig config,
  ) {
    config.validate();

    return RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: config.requestedBitRateBps,
      sampleRate: config.requestedSampleRateHz,
      numChannels: config.channels,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false,
    );
  }

  Future<bool> isAacLcSupported() =>
      _recorder.isEncoderSupported(AudioEncoder.aacLc);

  /// Read-only microphone level for the long-form recorder visual layer.
  ///
  /// This does not start, stop, pause, resume, rotate, persist, upload, or
  /// otherwise mutate the recording state.
  Future<double> currentAmplitudeDbfs() async {
    _guardNotDisposed();
    if (!_active) {
      return -160.0;
    }
    final amplitude = await _recorder.getAmplitude();
    return amplitude.current;
  }

  @override
  Future<void> startSegment({
    required String path,
    required ClinicalLongFormRecordingConfig config,
  }) async {
    _guardNotDisposed();

    if (_active || _starting) {
      throw StateError('Long-form segment already active.');
    }
    if (!path.toLowerCase().endsWith('.m4a')) {
      throw ArgumentError.value(path, 'path');
    }

    _starting = true;
    try {
      final supported = await isAacLcSupported();
      if (!supported) {
        throw StateError('AAC-LC is not supported on this platform.');
      }

      await _refreshEntitlement();
      _usage = await _ledger.begin(
          operationId: MonthlyUsageLedger.operationId(),
          kinds: {UsageKind.recording},
          maximumMs: config.segmentDuration.inMilliseconds,
          allowPartial: true);
      try {
        await _prepareIosAudioSession();
        await _beginPlatformBackgroundGuard();
        await _recorder.start(
          buildRecordConfig(config),
          path: path,
        );
        _active = true;
        _usageClock = Stopwatch()..start();
        _usageTimer = Timer(Duration(milliseconds: _usage!.maximumMs), () {
          unawaited(_quotaReached());
        });
      } catch (_) {
        await _finishUsage(false);
        await _releaseIosAudioSession();
        await _endPlatformBackgroundGuard();
        rethrow;
      }
    } finally {
      _starting = false;
    }
  }

  @override
  Future<void> pause() async {
    _guardActive();
    await _recorder.pause();
    _usageClock?.stop();
    _usageTimer?.cancel();
  }

  @override
  Future<void> resume() async {
    _guardActive();
    await _recorder.resume();
    _usageClock?.start();
    if (_usage != null)
      _usageTimer = Timer(
          Duration(
              milliseconds:
                  (_usage!.maximumMs - (_usageClock?.elapsedMilliseconds ?? 0))
                      .clamp(0, _usage!.maximumMs)), () {
        unawaited(_quotaReached());
      });
  }

  @override
  Future<String?> stopSegment() {
    return _stopFlight ??=
        _stopSegment().whenComplete(() => _stopFlight = null);
  }

  Future<String?> _stopSegment() async {
    _guardNotDisposed();
    if (!_active) {
      final path = _quotaStoppedPath;
      _quotaStoppedPath = null;
      return path;
    }

    try {
      final path = await _recorder.stop();
      await _finishUsage(path != null);
      return path;
    } catch (_) {
      await _finishUsage(false);
      rethrow;
    } finally {
      _active = false;
    }
  }

  @override
  Future<void> cancelSegment() async {
    _guardNotDisposed();
    if (!_active) {
      return;
    }

    try {
      await _recorder.cancel();
    } finally {
      await _finishUsage(false);
      _active = false;
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    try {
      if (_active) {
        try {
          await _recorder.stop();
        } finally {
          _active = false;
        }
      }
    } finally {
      await _releaseIosAudioSession();
      await _endPlatformBackgroundGuard();
      await _recorder.dispose();
      await _finishUsage(false);
      _disposed = true;
    }
  }

  Future<void> _prepareIosAudioSession() async {
    if (!Platform.isIOS || _iosAudioSessionPrepared) {
      return;
    }

    final ios = _recorder.ios;
    if (ios == null) {
      throw StateError('ios_record_audio_session_unavailable');
    }

    await ios.manageAudioSession(false);
    try {
      await ios.setAudioSessionCategory(
        category: IosAudioCategory.playAndRecord,
        options: const <IosAudioCategoryOptions>[
          IosAudioCategoryOptions.mixWithOthers,
          IosAudioCategoryOptions.defaultToSpeaker,
          IosAudioCategoryOptions.allowBluetooth,
          IosAudioCategoryOptions.allowBluetoothA2DP,
        ],
      );
      await ios.setAudioSessionActive(true);
      _iosAudioSessionPrepared = true;
    } catch (_) {
      try {
        await ios.setAudioSessionActive(false);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _releaseIosAudioSession() async {
    if (!Platform.isIOS || !_iosAudioSessionPrepared) {
      return;
    }

    final ios = _recorder.ios;
    _iosAudioSessionPrepared = false;

    if (ios == null) {
      return;
    }

    try {
      await ios.setAudioSessionActive(false);
    } catch (_) {
      // Best-effort teardown. Recorder disposal follows immediately.
    }
  }

  Future<void> _beginPlatformBackgroundGuard() async {
    if (!Platform.isAndroid || _androidBackgroundGuardActive) {
      return;
    }

    final started = await _backgroundGuardChannel.invokeMethod<bool>('begin');
    if (started != true) {
      throw StateError('android_recording_background_guard_unavailable');
    }
    _androidBackgroundGuardActive = true;
  }

  Future<void> _endPlatformBackgroundGuard() async {
    if (!Platform.isAndroid || !_androidBackgroundGuardActive) {
      return;
    }

    try {
      await _backgroundGuardChannel.invokeMethod<bool>('end');
    } on MissingPluginException {
      if (_active) {
        rethrow;
      }
    } finally {
      _androidBackgroundGuardActive = false;
    }
  }

  void _guardNotDisposed() {
    if (_disposed) {
      throw StateError('Long-form provider disposed.');
    }
  }

  void _guardActive() {
    _guardNotDisposed();
    if (!_active) {
      throw StateError('No active long-form segment.');
    }
  }
}
