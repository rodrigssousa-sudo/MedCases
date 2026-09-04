import 'dart:async';
import 'dart:typed_data';

import 'clinical_asr_provider.dart';
import 'clinical_asr_stream_coordinator.dart';
import 'clinical_audio_capture_provider.dart';
import 'clinical_medical_vocabulary.dart';
import 'clinical_transcript_reconciler.dart';
import 'clinical_transcription_accuracy_eval.dart';
import 'openai_realtime_transcription_shadow_provider.dart';
import 'openai_realtime_transcription_shadow_protocol.dart';

/// End-to-end SHADOW pipeline.
///
/// Esta classe existe exclusivamente para provar a integração entre as camadas
/// da Audio Engine V2 sem rede e sem alterar o gravador produtivo.
final class ClinicalAudioShadowSessionPipeline {
  ClinicalAudioShadowSessionPipeline({
    required OpenAiRealtimeTranscriptionShadowProvider provider,
    int maxBufferedFrames = 50,
  })  : _provider = provider,
        _coordinator = ClinicalAsrStreamCoordinator(
          provider: provider,
          maxBufferedFrames: maxBufferedFrames,
        );

  static const bool productionCutoverEnabled = false;
  static const bool remoteTransportEnabled = false;
  static const bool realAudioEnabled = false;
  static const bool audioPersistenceEnabled = false;

  final OpenAiRealtimeTranscriptionShadowProvider _provider;
  final ClinicalAsrStreamCoordinator _coordinator;
  final ClinicalTranscriptReconciler _reconciler =
      ClinicalTranscriptReconciler();
  final ClinicalTranscriptionAccuracyEvaluator _evaluator =
      const ClinicalTranscriptionAccuracyEvaluator();

  final Map<String, String> _partialByKey = <String, String>{};

  StreamSubscription<OpenAiRealtimeTranscriptObservation>?
      _observationSubscription;

  bool _started = false;
  bool _disposed = false;
  int _reconcileSequence = 0;
  String? _locale;

  String get canonicalTranscript => _reconciler.canonicalText;

  List<ClinicalTranscriptSegment> get segments => _reconciler.segments;

  int get acceptedFrames => _coordinator.acceptedFrames;
  int get sentFrames => _coordinator.sentFrames;
  int get acceptedBytes => _coordinator.acceptedBytes;
  int get sentBytes => _coordinator.sentBytes;

  Future<void> start({
    required String locale,
    String? contextHint,
    Iterable<String> extraMedicalHints = const <String>[],
  }) async {
    _guardNotDisposed();
    if (_started) {
      throw StateError('Shadow session already started.');
    }

    _locale = locale;
    _reconciler.reset();
    _partialByKey.clear();
    _reconcileSequence = 0;

    _observationSubscription = _provider.observations.listen(
      _ingestObservation,
    );

    final config = ClinicalAsrSessionConfig(
      locale: locale,
      format: const ClinicalPcmFormat(),
      vocabularyHints: ClinicalMedicalVocabulary.buildHints(
        locale: locale,
        extraHints: extraMedicalHints,
      ),
      contextHint: contextHint,
      policy: ClinicalAsrSessionPolicy.localOnly,
    );

    try {
      await _coordinator.start(config);
      _started = true;
    } catch (_) {
      await _observationSubscription?.cancel();
      _observationSubscription = null;
      rethrow;
    }
  }

  void enqueueSyntheticPcm(Uint8List pcm16) {
    _guardStarted();
    _coordinator.enqueueFrame(pcm16);
  }

  Future<void> commitPcm() async {
    _guardStarted();
    await _coordinator.commit();
  }

  void ingestSimulatedServerEvent(String encodedEvent) {
    _guardStarted();
    _provider.ingestShadowServerEvent(encodedEvent);
  }

  ClinicalTranscriptionAccuracyResult evaluate({
    required String id,
    required String reference,
    Iterable<String> medicalTerms = const <String>[],
    Iterable<String> units = const <String>[],
    Iterable<String> criticalPhrases = const <String>[],
  }) {
    _guardStarted();

    return _evaluator.evaluate(
      ClinicalTranscriptionEvalCase(
        id: id,
        locale: _locale!,
        reference: reference,
        hypothesis: canonicalTranscript,
        medicalTerms: List<String>.unmodifiable(medicalTerms),
        units: List<String>.unmodifiable(units),
        criticalPhrases: List<String>.unmodifiable(criticalPhrases),
      ),
    );
  }

  Future<void> stop() async {
    if (!_started || _disposed) {
      return;
    }

    await _coordinator.stop();
    _started = false;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }

    await _observationSubscription?.cancel();
    _observationSubscription = null;
    await _coordinator.dispose();

    _partialByKey.clear();
    _disposed = true;
    _started = false;
  }

  void _ingestObservation(
    OpenAiRealtimeTranscriptObservation observation,
  ) {
    final sequence = ++_reconcileSequence;

    if (observation.kind == OpenAiRealtimeTranscriptObservationKind.delta) {
      final cumulative =
          (_partialByKey[observation.key] ?? '') + observation.text;
      _partialByKey[observation.key] = cumulative;

      _reconciler.ingest(
        ClinicalTranscriptUpdate(
          kind: ClinicalTranscriptUpdateKind.partial,
          sequence: sequence,
          itemId: observation.itemId,
          contentIndex: observation.contentIndex,
          text: cumulative,
        ),
      );
      return;
    }

    _partialByKey.remove(observation.key);

    _reconciler.ingest(
      ClinicalTranscriptUpdate(
        kind: ClinicalTranscriptUpdateKind.finalResult,
        sequence: sequence,
        itemId: observation.itemId,
        contentIndex: observation.contentIndex,
        text: observation.text,
      ),
    );
  }

  void _guardNotDisposed() {
    if (_disposed) {
      throw StateError('Shadow session disposed.');
    }
  }

  void _guardStarted() {
    _guardNotDisposed();
    if (!_started) {
      throw StateError('Shadow session not started.');
    }
  }
}
