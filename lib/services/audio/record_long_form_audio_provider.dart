import 'package:record/record.dart';

import 'clinical_long_form_audio_contract.dart';

final class RecordLongFormAudioProvider implements ClinicalLongFormFileCapture {
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

    await _recorder.start(
      buildRecordConfig(config),
      path: path,
    );
    _active = true;
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

    final path = await _recorder.stop();
    _active = false;
    return path;
  }

  @override
  Future<void> cancelSegment() async {
    _guardNotDisposed();
    if (!_active) {
      return;
    }

    await _recorder.cancel();
    _active = false;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    if (_active) {
      await _recorder.stop();
      _active = false;
    }

    await _recorder.dispose();
    _disposed = true;
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
