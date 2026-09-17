import 'dart:io';

import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'clinical_long_form_audio_contract.dart';

final class RecordLongFormAudioProvider implements ClinicalLongFormFileCapture {
  static const MethodChannel _backgroundGuardChannel =
      MethodChannel('medcases/recording_background_guard_v1');

  RecordLongFormAudioProvider({
    AudioRecorder? recorder,
  }) : _recorder = recorder ?? AudioRecorder();

  static const bool productionCutoverEnabled = false;
  static const bool productionPersistenceEnabled = false;
  static const bool remoteUploadEnabled = false;

  final AudioRecorder _recorder;

  bool _active = false;
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

    if (_active) {
      throw StateError('Long-form segment already active.');
    }
    if (!path.toLowerCase().endsWith('.m4a')) {
      throw ArgumentError.value(path, 'path');
    }

    final supported = await isAacLcSupported();
    if (!supported) {
      throw StateError('AAC-LC is not supported on this platform.');
    }

    await _prepareIosAudioSession();
    await _beginPlatformBackgroundGuard();
    try {
      await _recorder.start(
        buildRecordConfig(config),
        path: path,
      );
      _active = true;
    } catch (_) {
      await _releaseIosAudioSession();
      await _endPlatformBackgroundGuard();
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    _guardActive();
    await _recorder.pause();
  }

  @override
  Future<void> resume() async {
    _guardActive();
    await _recorder.resume();
  }

  @override
  Future<String?> stopSegment() async {
    _guardNotDisposed();
    if (!_active) {
      return null;
    }

    try {
      return await _recorder.stop();
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
