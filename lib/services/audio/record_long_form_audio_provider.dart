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

    await _beginPlatformBackgroundGuard();
    try {
      await _recorder.start(
        buildRecordConfig(config),
        path: path,
      );
      _active = true;
    } catch (_) {
      await _endPlatformBackgroundGuard();
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    _guardActive();
    await _recorder.pause();
    await _endPlatformBackgroundGuard();
  }

  @override
  Future<void> resume() async {
    _guardActive();
    await _beginPlatformBackgroundGuard();
    try {
      await _recorder.resume();
    } catch (_) {
      await _endPlatformBackgroundGuard();
      rethrow;
    }
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
      await _endPlatformBackgroundGuard();
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
      await _endPlatformBackgroundGuard();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    if (_active) {
      try {
        await _recorder.stop();
      } finally {
        _active = false;
        await _endPlatformBackgroundGuard();
      }
    } else {
      await _endPlatformBackgroundGuard();
    }

    await _recorder.dispose();
    _disposed = true;
  }

  Future<void> _beginPlatformBackgroundGuard() async {
    if (!Platform.isAndroid) {
      return;
    }

    final started = await _backgroundGuardChannel.invokeMethod<bool>('begin');
    if (started != true) {
      throw StateError('android_recording_background_guard_unavailable');
    }
  }

  Future<void> _endPlatformBackgroundGuard() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _backgroundGuardChannel.invokeMethod<bool>('end');
    } on MissingPluginException {
      if (_active) {
        rethrow;
      }
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
