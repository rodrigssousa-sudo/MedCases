import 'dart:async';
import 'dart:typed_data';

import 'clinical_asr_provider.dart';
import 'openai_realtime_transcription_shadow_protocol.dart';

abstract interface class OpenAiRealtimeShadowSink {
  Future<void> send(String encodedEvent);
}

final class OpenAiRealtimeDiscardingShadowSink
    implements OpenAiRealtimeShadowSink {
  int _eventCount = 0;
  int _encodedCharacterCount = 0;

  int get eventCount => _eventCount;
  int get encodedCharacterCount => _encodedCharacterCount;

  @override
  Future<void> send(String encodedEvent) async {
    _eventCount++;
    _encodedCharacterCount += encodedEvent.length;
  }
}

final class OpenAiRealtimeTranscriptLedgerEntry {
  const OpenAiRealtimeTranscriptLedgerEntry({
    required this.itemId,
    required this.contentIndex,
    required this.firstReceiveSequence,
    required this.partialText,
    required this.finalText,
    required this.completed,
  });

  final String itemId;
  final int contentIndex;
  final int firstReceiveSequence;
  final String partialText;
  final String? finalText;
  final bool completed;
}

final class OpenAiRealtimeTranscriptionShadowProvider
    implements ClinicalAsrProvider {
  OpenAiRealtimeTranscriptionShadowProvider({
    OpenAiRealtimeTranscriptionProtocol protocol =
        const OpenAiRealtimeTranscriptionProtocol(),
    OpenAiRealtimeShadowSink? sink,
  })  : _protocol = protocol,
        _sink = sink ?? OpenAiRealtimeDiscardingShadowSink();

  static const bool productionCutoverEnabled = false;
  static const bool remoteTransportImplemented = false;
  static const bool remoteAudioEnabled = false;
  static const bool apiCredentialsAccepted = false;

  final OpenAiRealtimeTranscriptionProtocol _protocol;
  final OpenAiRealtimeShadowSink _sink;

  final StreamController<ClinicalAsrEvent> _events =
      StreamController<ClinicalAsrEvent>.broadcast(sync: true);

  final StreamController<OpenAiRealtimeTranscriptObservation> _observations =
      StreamController<OpenAiRealtimeTranscriptObservation>.broadcast(
    sync: true,
  );

  final Map<String, _MutableLedgerEntry> _ledger =
      <String, _MutableLedgerEntry>{};

  bool _started = false;
  bool _stopped = false;
  bool _disposed = false;
  int _genericSequence = 0;
  int _receiveSequence = 0;
  int _appendCount = 0;
  int _appendBytes = 0;
  int _commitCount = 0;

  @override
  String get providerId => 'openai_realtime_transcription_shadow_v1';

  @override
  Stream<ClinicalAsrEvent> get events => _events.stream;

  Stream<OpenAiRealtimeTranscriptObservation> get observations =>
      _observations.stream;

  int get appendCount => _appendCount;
  int get appendBytes => _appendBytes;
  int get commitCount => _commitCount;

  List<OpenAiRealtimeTranscriptLedgerEntry> get ledger {
    final entries = _ledger.values.map((entry) => entry.freeze()).toList();
    entries.sort(
      (a, b) => a.firstReceiveSequence.compareTo(
        b.firstReceiveSequence,
      ),
    );
    return List<OpenAiRealtimeTranscriptLedgerEntry>.unmodifiable(entries);
  }

  @override
  Future<void> start(ClinicalAsrSessionConfig config) async {
    _guardNotDisposed();
    if (_started) {
      throw const ClinicalAsrException('shadow_already_started');
    }
    if (_stopped) {
      throw const ClinicalAsrException('shadow_already_stopped');
    }

    await _sink.send(
      _protocol.encode(_protocol.sessionUpdate(config)),
    );

    _started = true;
    _emit(
      ClinicalAsrEvent.ready(sequence: _nextSequence()),
    );
  }

  @override
  Future<void> appendPcm(Uint8List pcm16) async {
    _guardActive();
    await _sink.send(
      _protocol.encode(_protocol.append(pcm16)),
    );
    _appendCount++;
    _appendBytes += pcm16.length;
  }

  @override
  Future<void> commit() async {
    _guardActive();
    await _sink.send(
      _protocol.encode(_protocol.commit()),
    );
    _commitCount++;
  }

  @override
  Future<void> stop() async {
    _guardNotDisposed();
    if (_stopped) {
      return;
    }
    _stopped = true;
    _emit(
      ClinicalAsrEvent.closed(sequence: _nextSequence()),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    if (!_stopped) {
      await stop();
    }
    _disposed = true;
    await _events.close();
    await _observations.close();
    _ledger.clear();
  }

  void ingestShadowServerEvent(String encodedEvent) {
    _guardActive();

    final observation = _protocol.decodeTranscript(
      encodedEvent,
      receiveSequence: ++_receiveSequence,
    );
    if (observation == null) {
      return;
    }

    _observations.add(observation);

    final entry = _ledger.putIfAbsent(
      observation.key,
      () => _MutableLedgerEntry(
        itemId: observation.itemId,
        contentIndex: observation.contentIndex,
        firstReceiveSequence: observation.receiveSequence,
      ),
    );

    if (observation.kind == OpenAiRealtimeTranscriptObservationKind.delta) {
      entry.partialText += observation.text;
      _emit(
        ClinicalAsrEvent.partial(
          sequence: _nextSequence(),
          text: entry.partialText,
        ),
      );
      return;
    }

    entry
      ..finalText = observation.text
      ..completed = true;

    _emit(
      ClinicalAsrEvent.finalResult(
        sequence: _nextSequence(),
        text: observation.text,
      ),
    );
  }

  int _nextSequence() => ++_genericSequence;

  void _emit(ClinicalAsrEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  void _guardNotDisposed() {
    if (_disposed) {
      throw const ClinicalAsrException('shadow_disposed');
    }
  }

  void _guardActive() {
    _guardNotDisposed();
    if (!_started || _stopped) {
      throw const ClinicalAsrException('shadow_not_active');
    }
  }
}

final class _MutableLedgerEntry {
  _MutableLedgerEntry({
    required this.itemId,
    required this.contentIndex,
    required this.firstReceiveSequence,
  });

  final String itemId;
  final int contentIndex;
  final int firstReceiveSequence;
  String partialText = '';
  String? finalText;
  bool completed = false;

  OpenAiRealtimeTranscriptLedgerEntry freeze() =>
      OpenAiRealtimeTranscriptLedgerEntry(
        itemId: itemId,
        contentIndex: contentIndex,
        firstReceiveSequence: firstReceiveSequence,
        partialText: partialText,
        finalText: finalText,
        completed: completed,
      );
}
