import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'clinical_asr_provider.dart';

final class ClinicalAsrBackpressureException implements Exception {
  const ClinicalAsrBackpressureException({
    required this.bufferedFrames,
    required this.maxBufferedFrames,
  });

  final int bufferedFrames;
  final int maxBufferedFrames;

  @override
  String toString() => 'ClinicalAsrBackpressureException('
      'bufferedFrames: $bufferedFrames, '
      'maxBufferedFrames: $maxBufferedFrames)';
}

/// Ponte ordenada PCM -> ASR.
///
/// Não contém transporte, credenciais, rede ou lógica clínica.
/// Em caso de backlog excessivo, falha explicitamente: nunca descarta áudio
/// silenciosamente e nunca reordena frames.
final class ClinicalAsrStreamCoordinator {
  ClinicalAsrStreamCoordinator({
    required ClinicalAsrProvider provider,
    this.maxBufferedFrames = 50,
  }) : _provider = provider {
    if (maxBufferedFrames < 1 || maxBufferedFrames > 600) {
      throw ArgumentError.value(maxBufferedFrames, 'maxBufferedFrames');
    }
  }

  final ClinicalAsrProvider _provider;
  final int maxBufferedFrames;
  final Queue<Uint8List> _queue = Queue<Uint8List>();

  bool _started = false;
  bool _stopped = false;
  bool _pumping = false;
  Object? _fatalError;
  StackTrace? _fatalStackTrace;
  Completer<void>? _idleCompleter;

  int _acceptedFrames = 0;
  int _sentFrames = 0;
  int _acceptedBytes = 0;
  int _sentBytes = 0;

  int get bufferedFrames => _queue.length;
  int get acceptedFrames => _acceptedFrames;
  int get sentFrames => _sentFrames;
  int get acceptedBytes => _acceptedBytes;
  int get sentBytes => _sentBytes;
  bool get isIdle => !_pumping && _queue.isEmpty;
  bool get hasFatalError => _fatalError != null;

  Future<void> start(ClinicalAsrSessionConfig config) async {
    if (_started) {
      throw const ClinicalAsrException('coordinator_already_started');
    }
    if (_stopped) {
      throw const ClinicalAsrException('coordinator_already_stopped');
    }

    config.validate();
    await _provider.start(config);
    _started = true;
  }

  void enqueueFrame(Uint8List pcm16) {
    _ensureHealthy();

    if (!_started) {
      throw const ClinicalAsrException('coordinator_not_started');
    }
    if (_stopped) {
      throw const ClinicalAsrException('coordinator_stopped');
    }
    if (pcm16.isEmpty) {
      return;
    }
    if (pcm16.length.isOdd) {
      throw ArgumentError.value(
        pcm16.length,
        'pcm16.length',
        'PCM16 byte length must be even.',
      );
    }

    if (_queue.length >= maxBufferedFrames) {
      throw ClinicalAsrBackpressureException(
        bufferedFrames: _queue.length,
        maxBufferedFrames: maxBufferedFrames,
      );
    }

    final owned = Uint8List.fromList(pcm16);
    _queue.addLast(owned);
    _acceptedFrames++;
    _acceptedBytes += owned.length;

    _idleCompleter ??= Completer<void>();
    _schedulePump();
  }

  Future<void> drain() async {
    _ensureHealthy();

    if (isIdle) {
      return;
    }

    final completer = _idleCompleter ??= Completer<void>();
    await completer.future;
    _ensureHealthy();
  }

  Future<void> commit() async {
    _ensureHealthy();
    if (!_started || _stopped) {
      throw const ClinicalAsrException('coordinator_not_active');
    }

    await drain();
    _ensureHealthy();
    await _provider.commit();
  }

  Future<void> stop() async {
    if (_stopped) {
      return;
    }

    _ensureHealthy();

    if (_started) {
      await drain();
      _ensureHealthy();
      await _provider.stop();
    }

    _stopped = true;
  }

  Future<void> dispose() async {
    try {
      if (!_stopped && _started && _fatalError == null) {
        await stop();
      }
    } finally {
      _queue.clear();
      await _provider.dispose();
      _stopped = true;
    }
  }

  void _schedulePump() {
    if (_pumping) {
      return;
    }
    _pumping = true;
    unawaited(_pump());
  }

  Future<void> _pump() async {
    try {
      while (_queue.isNotEmpty) {
        final frame = _queue.removeFirst();
        await _provider.appendPcm(frame);
        _sentFrames++;
        _sentBytes += frame.length;
      }
    } catch (error, stackTrace) {
      _fatalError = error;
      _fatalStackTrace = stackTrace;
      _queue.clear();
    } finally {
      _pumping = false;
      final idle = _idleCompleter;
      _idleCompleter = null;

      if (idle != null && !idle.isCompleted) {
        if (_fatalError != null) {
          idle.completeError(_fatalError!, _fatalStackTrace);
        } else {
          idle.complete();
        }
      }

      if (_queue.isNotEmpty && _fatalError == null) {
        _schedulePump();
      }
    }
  }

  void _ensureHealthy() {
    final error = _fatalError;
    if (error != null) {
      throw ClinicalAsrException('coordinator_provider_failure', error);
    }
  }
}
