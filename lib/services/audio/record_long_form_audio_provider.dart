import 'continuous_aac_file.dart';
import 'package:flutter/foundation.dart';
import 'recording_start_failure.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'clinical_long_form_audio_contract.dart';

final class RecordLongFormAudioProvider implements ClinicalLongFormFileCapture {
  static const MethodChannel _backgroundGuardChannel =
      MethodChannel('medcases/recording_background_guard_v1');

  RecordLongFormAudioProvider({
    AudioRecorder? recorder,
    this.onQuotaReached,
    this.scheduleQuota = Timer.new,
    Future<PermissionStatus> Function()? microphonePermission,
  })  : _microphonePermission =
            microphonePermission ?? (() => Permission.microphone.request()),
        _recorder = recorder ?? AudioRecorder();

  static const bool productionCutoverEnabled = false;
  static const bool productionPersistenceEnabled = false;
  static const bool remoteUploadEnabled = false;

  final Future<PermissionStatus> Function() _microphonePermission;
  final AudioRecorder _recorder;
  final void Function()? onQuotaReached;
  final Timer Function(Duration, void Function()) scheduleQuota;
  Future<void> _quotaReached() async {
    if (!_active || _quotaTransitionPending) return;
    _quotaTransitionPending = true;
    _usageClock?.stop();
    await _recorder.pause();
    if (onQuotaReached != null) {
      onQuotaReached!();
    } else {
      _quotaStoppedPath = await stopSegment();
    }
  }

  // A quota boundary deliberately pauses before the owner rotates files.
  // Do not report that pause as an OS interruption.
  bool _quotaTransitionPending = false;
  bool get segmentBoundaryPending => _quotaTransitionPending;
  String? _quotaStoppedPath;
  int _segmentBudgetMs = 0;
  bool _unlimitedLocalCapture = false;
  Stopwatch? _usageClock;
  Timer? _usageTimer;
  Future<void> _finishUsage(bool success) async {
    // Local capture has no billable reservation. This clock bounds the file.
    _usageTimer?.cancel();
    _usageClock?.stop();
  }

  String notificationLanguage = 'pt';
  Duration? sessionRemaining;
  ContinuousAacFile? _continuousFile;
  StreamSubscription<dynamic>? _audioFrames;
  Completer<void>? _framesDone;
  Object? _frameFailure;
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

  Stream<bool> get captureActiveChanges => _recorder
      .onStateChanged()
      .where((_) => !_quotaTransitionPending)
      .map((s) => s == RecordState.record);
  Future<bool> isCaptureRunning() async =>
      _quotaTransitionPending ||
      (await _recorder.isRecording() && !await _recorder.isPaused());

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
      throw const RecordingStartFailure(
          'RECORDER_ALREADY_ACTIVE', 'recorder_availability');
    }
    if (!path.toLowerCase().endsWith(config.continuous ? '.aac' : '.m4a')) {
      throw ArgumentError.value(path, 'path');
    }

    _starting = true;
    try {
      final permission = await _microphonePermission();
      debugPrint('MIC_PERMISSION_STATE=${permission.name}');
      if (!permission.isGranted) {
        throw RecordingStartFailure(
            permission.isRestricted
                ? 'MIC_PERMISSION_RESTRICTED'
                : 'MIC_PERMISSION_DENIED',
            'microphone_permission');
      }
      final supported = await isAacLcSupported();
      if (!supported) {
        throw const RecordingStartFailure(
            'RECORDER_INITIALIZATION_FAILED', 'encoder_availability');
      }

      _unlimitedLocalCapture = config.unlimitedLocalCapture;
      final captureLimit = config.continuous
          ? config.maxDuration.inMilliseconds
          : config.segmentDuration.inMilliseconds;
      _segmentBudgetMs = sessionRemaining == null
          ? captureLimit
          : sessionRemaining!.inMilliseconds.clamp(0, captureLimit);
      if (!_unlimitedLocalCapture && _segmentBudgetMs <= 0) {
        throw const RecordingStartFailure(
            'TECHNICAL_RECORDING_LIMIT', 'technical_limit');
      }
      try {
        try {
          await _prepareIosAudioSession();
          debugPrint('AUDIO_SESSION_STATE=PREPARED');
        } catch (_) {
          throw const RecordingStartFailure(
              'AUDIO_SESSION_ACTIVATION_FAILED', 'audio_session');
        }
        await _beginPlatformBackgroundGuard();
        if (config.continuous) {
          _continuousFile = ContinuousAacFile(path, append: config.append);
          _frameFailure = null;
          _framesDone = Completer<void>();
          final frames = await _recorder.startStream(buildRecordConfig(config));
          _audioFrames = frames.listen((bytes) {
            if (_frameFailure != null) return;
            try {
              _continuousFile!.add(bytes);
            } catch (error) {
              _frameFailure = error;
              unawaited(_recorder.pause().catchError((_) {}));
            }
          }, onError: (Object error) {
            _frameFailure = error;
            unawaited(_recorder.pause().catchError((_) {}));
          }, onDone: () {
            if (!_framesDone!.isCompleted) _framesDone!.complete();
          });
        } else {
          await _recorder.start(buildRecordConfig(config), path: path);
        }
        _active = true;
        _usageClock = Stopwatch()..start();
        if (!_unlimitedLocalCapture)
          _usageTimer =
              scheduleQuota(Duration(milliseconds: _segmentBudgetMs), () {
            unawaited(_quotaReached());
          });
      } catch (_) {
        // Stop the producer before draining/closing a partially started stream.
        if (_continuousFile != null) {
          try {
            await _recorder.stop();
          } catch (_) {}
        }
        await _closeContinuousFile();
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
    await _notifyCaptureState(true);
  }

  /// Refresh the paused encoder timer from the same policy as the UI timer.
  void updateRemainingCaptureBudget(Duration remaining) {
    if (remaining <= Duration.zero)
      throw StateError('TECHNICAL_RECORDING_LIMIT');
    _segmentBudgetMs =
        (_usageClock?.elapsedMilliseconds ?? 0) + remaining.inMilliseconds;
  }

  @override
  Future<void> resume() async {
    _guardActive();
    await _recorder.resume();
    _usageClock?.start();
    await _notifyCaptureState(false);
    if (!_unlimitedLocalCapture && _segmentBudgetMs > 0)
      _usageTimer = scheduleQuota(
          Duration(
              milliseconds:
                  (_segmentBudgetMs - (_usageClock?.elapsedMilliseconds ?? 0))
                      .clamp(0, _segmentBudgetMs)), () {
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
      final nativePath = await _recorder.stop();
      final path = _continuousFile?.path ?? nativePath;
      await _closeContinuousFile();
      if (_frameFailure != null)
        throw StateError('RECORDING_FILE_WRITE_FAILED');
      await _finishUsage(path != null);
      return path;
    } catch (_) {
      await _finishUsage(false);
      rethrow;
    } finally {
      _active = false;
    }
  }

  Future<void> _closeContinuousFile() async {
    if (_continuousFile == null) return;
    // record.stop closes its stream; drain queued frames before closing disk.
    if (_audioFrames != null) {
      try {
        await _framesDone?.future.timeout(const Duration(seconds: 5));
      } catch (_) {
        _frameFailure ??= StateError('RECORDING_STREAM_DRAIN_FAILED');
      }
      await _audioFrames?.cancel();
      _audioFrames = null;
    }
    try {
      _continuousFile!.close();
    } catch (error) {
      _frameFailure ??= error;
    }
    _continuousFile = null;
  }

  @override
  Future<void> cancelSegment() async {
    _guardNotDisposed();
    if (!_active) {
      return;
    }

    try {
      await _recorder.cancel();
      await _closeContinuousFile();
    } finally {
      await _finishUsage(false);
      _active = false;
    }
  }

  @override
  Future<void> dispose({bool preservePlatformSession = false}) async {
    if (_disposed) {
      return;
    }

    try {
      if (_active) {
        try {
          await _recorder.stop();
          await _closeContinuousFile();
        } finally {
          _active = false;
        }
      }
    } finally {
      if (!preservePlatformSession) {
        await _releaseIosAudioSession();
        await _endPlatformBackgroundGuard();
      }
      await _recorder.dispose();
      await _finishUsage(false);
      _disposed = true;
    }
  }

  /// Transfers an already active native guard between immutable file segments.
  /// No microphone instance is transferred and no permission is newly granted.
  void takePlatformSessionFrom(RecordLongFormAudioProvider previous) {
    _iosAudioSessionPrepared = previous._iosAudioSessionPrepared;
    _androidBackgroundGuardActive = previous._androidBackgroundGuardActive;
    previous._iosAudioSessionPrepared = false;
    previous._androidBackgroundGuardActive = false;
  }

  Future<void> releaseRetainedPlatformSession() async {
    await _releaseIosAudioSession();
    await _endPlatformBackgroundGuard();
  }

  Future<void> _prepareIosAudioSession() async {
    if (!Platform.isIOS) {
      return;
    }

    final ios = _recorder.ios;
    if (ios == null) {
      throw StateError('ios_record_audio_session_unavailable');
    }

    await ios.manageAudioSession(false);
    if (_iosAudioSessionPrepared) return;
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
      await const MethodChannel('medcases/recording_events_v1')
          .invokeMethod<bool>('prepareSession');
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

  Future<void> _notifyCaptureState(bool paused) async {
    if (!Platform.isAndroid || !_androidBackgroundGuardActive) return;
    try {
      await _backgroundGuardChannel.invokeMethod<bool>(
          'status', {'language': notificationLanguage, 'paused': paused});
    } catch (_) {/* Capture is independent of notification refresh. */}
  }

  Future<void> _beginPlatformBackgroundGuard() async {
    if (!Platform.isAndroid || _androidBackgroundGuardActive) {
      return;
    }

    final started = await _backgroundGuardChannel
        .invokeMethod<bool>('begin', {'language': notificationLanguage});
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
