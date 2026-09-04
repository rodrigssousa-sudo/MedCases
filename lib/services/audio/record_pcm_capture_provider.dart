import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'clinical_audio_capture_provider.dart';
import 'clinical_pcm16_chunk_framer.dart';

/// Captura PCM experimental baseada no package `record`.
///
/// IMPORTANTE — V1_B_R0:
/// - PRODUCTION_CUTOVER = NO
/// - REMOTE_TRANSCRIPTION = NO
/// - AUDIO_UPLOAD = NO
/// - speech_to_text produtivo permanece owner da transcrição atual.
///
/// O formato canônico inicial é PCM16 mono, 24 kHz, frames de 100 ms.
/// O framing é feito novamente em Dart porque limites de eventos do stream
/// nativo não são considerados fronteiras temporais contratuais.
final class RecordPcmCaptureProvider implements ClinicalAudioCaptureProvider {
  RecordPcmCaptureProvider({
    ClinicalPcmFormat format = const ClinicalPcmFormat(),
    AudioRecorder? recorder,
  })  : _format = format,
        _recorder = recorder ?? AudioRecorder() {
    _format.validate();
  }

  static const bool productionCutoverEnabled = false;
  static const bool remoteTranscriptionEnabled = false;
  static const bool audioUploadEnabled = false;

  final ClinicalPcmFormat _format;
  final AudioRecorder _recorder;

  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast(sync: true);

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Uint8List>? _rawSubscription;
  StreamController<Uint8List>? _framedController;
  ClinicalPcm16ChunkFramer? _framer;

  ClinicalAudioCaptureState _state = ClinicalAudioCaptureState.idle;
  bool _disposed = false;

  @override
  String get providerId => 'record_pcm16_experimental_v1';

  @override
  ClinicalPcmFormat get format => _format;

  @override
  ClinicalAudioCaptureState get state => _state;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<bool> hasPermission() async {
    _guardNotDisposed();
    try {
      return await _recorder.hasPermission();
    } catch (error) {
      throw ClinicalAudioCaptureException('permission_check_failed', error);
    }
  }

  @override
  Future<Stream<Uint8List>> start() async {
    _guardNotDisposed();

    if (_state == ClinicalAudioCaptureState.recording ||
        _state == ClinicalAudioCaptureState.paused) {
      throw const ClinicalAudioCaptureException('already_started');
    }

    final allowed = await hasPermission();
    if (!allowed) {
      throw const ClinicalAudioCaptureException('permission_denied');
    }

    await _cancelRuntimeSubscriptions();

    _framer = ClinicalPcm16ChunkFramer(_format);
    final output = StreamController<Uint8List>.broadcast(sync: true);
    _framedController = output;

    try {
      final raw = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _format.sampleRate,
          numChannels: _format.channels,
          streamBufferSize: _format.bytesPerChunk,

          // Baseline deliberadamente sem DSP solicitado pelo app.
          // A/B de ganho/eco/ruído será uma build separada, porque processar
          // agressivamente a fala pode também apagar fonemas/termos clínicos.
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );

      _rawSubscription = raw.listen(
        (bytes) {
          final framer = _framer;
          final controller = _framedController;
          if (framer == null || controller == null || controller.isClosed) {
            return;
          }
          for (final frame in framer.add(bytes)) {
            controller.add(frame);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          final controller = _framedController;
          if (controller != null && !controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          _flushAndCloseOutput();
        },
      );

      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen(
        (amplitude) {
          if (_amplitudeController.isClosed) {
            return;
          }
          _amplitudeController.add(_normalizeDbfs(amplitude.current));
        },
        onError: (_) {
          // Falha de metering não interrompe captura PCM.
        },
      );

      _state = ClinicalAudioCaptureState.recording;
      return output.stream;
    } catch (error) {
      await _cancelRuntimeSubscriptions();
      _framer?.reset();
      _framer = null;
      if (!output.isClosed) {
        await output.close();
      }
      _framedController = null;
      _state = ClinicalAudioCaptureState.stopped;
      throw ClinicalAudioCaptureException('start_failed', error);
    }
  }

  @override
  Future<void> pause() async {
    _guardNotDisposed();
    if (_state != ClinicalAudioCaptureState.recording) {
      return;
    }
    try {
      await _recorder.pause();
      _state = ClinicalAudioCaptureState.paused;
    } catch (error) {
      throw ClinicalAudioCaptureException('pause_failed', error);
    }
  }

  @override
  Future<void> resume() async {
    _guardNotDisposed();
    if (_state != ClinicalAudioCaptureState.paused) {
      return;
    }
    try {
      await _recorder.resume();
      _state = ClinicalAudioCaptureState.recording;
    } catch (error) {
      throw ClinicalAudioCaptureException('resume_failed', error);
    }
  }

  @override
  Future<void> stop() async {
    _guardNotDisposed();
    if (_state == ClinicalAudioCaptureState.idle ||
        _state == ClinicalAudioCaptureState.stopped) {
      return;
    }

    try {
      await _recorder.stop();
    } catch (error) {
      throw ClinicalAudioCaptureException('stop_failed', error);
    } finally {
      _state = ClinicalAudioCaptureState.stopped;
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      // O stream nativo deve emitir onDone após stop(). Se algum backend não
      // o fizer, a futura build de runtime adicionará watchdog sem alterar
      // o contrato desta fundação.
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    if (_state == ClinicalAudioCaptureState.recording ||
        _state == ClinicalAudioCaptureState.paused) {
      try {
        await _recorder.stop();
      } catch (_) {
        // Dispose precisa ser idempotente.
      }
    }

    await _cancelRuntimeSubscriptions();
    await _flushAndCloseOutput();
    await _recorder.dispose();
    await _amplitudeController.close();

    _framer = null;
    _disposed = true;
    _state = ClinicalAudioCaptureState.disposed;
  }

  Future<void> _cancelRuntimeSubscriptions() async {
    await _rawSubscription?.cancel();
    _rawSubscription = null;

    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
  }

  Future<void> _flushAndCloseOutput() async {
    final controller = _framedController;
    if (controller == null || controller.isClosed) {
      return;
    }

    final tail = _framer?.flush();
    if (tail != null && tail.isNotEmpty) {
      controller.add(tail);
    }

    await controller.close();
    _framedController = null;
  }

  void _guardNotDisposed() {
    if (_disposed) {
      throw const ClinicalAudioCaptureException('disposed');
    }
  }

  static double _normalizeDbfs(double dbfs) {
    // dBFS <= 0; -60 dBFS é tratado como piso visual/telemetria.
    return ((dbfs + 60.0) / 60.0).clamp(0.0, 1.0).toDouble();
  }
}
