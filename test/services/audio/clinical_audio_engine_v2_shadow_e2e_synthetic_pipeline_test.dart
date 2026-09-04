import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_audio_capture_provider.dart';
import 'package:medcases/services/audio/clinical_audio_shadow_session_pipeline.dart';
import 'package:medcases/services/audio/openai_realtime_transcription_shadow_provider.dart';

final class _RecordingShadowSink implements OpenAiRealtimeShadowSink {
  final List<String> events = <String>[];

  @override
  Future<void> send(String encodedEvent) async {
    events.add(encodedEvent);
  }
}

Uint8List _syntheticPcmFrame(int seed) {
  const format = ClinicalPcmFormat();
  return Uint8List.fromList(
    List<int>.generate(
      format.bytesPerChunk,
      (index) => (index + seed) & 0xff,
    ),
  );
}

void main() {
  test('PT synthetic PCM traverses full shadow pipeline to clinical score',
      () async {
    final sink = _RecordingShadowSink();
    final provider = OpenAiRealtimeTranscriptionShadowProvider(sink: sink);
    final pipeline = ClinicalAudioShadowSessionPipeline(provider: provider);

    await pipeline.start(
      locale: 'pt-BR',
      contextHint: 'Consulta clínica médico-paciente.',
      extraMedicalHints: const <String>[
        'ceftriaxona',
        'creatinina',
      ],
    );

    for (var i = 0; i < 12; i++) {
      pipeline.enqueueSyntheticPcm(_syntheticPcmFrame(i));
    }
    await pipeline.commitPcm();

    expect(pipeline.acceptedFrames, 12);
    expect(pipeline.sentFrames, 12);
    expect(pipeline.acceptedBytes, 12 * 4800);
    expect(pipeline.sentBytes, 12 * 4800);
    expect(provider.appendCount, 12);
    expect(provider.commitCount, 1);
    expect(sink.events, hasLength(14));

    pipeline.ingestSimulatedServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'pt_A',
        'content_index': 0,
        'delta': 'Paciente com dispneia. ',
      }),
    );
    pipeline.ingestSimulatedServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'pt_A',
        'content_index': 0,
        'delta': 'Ceftriaxona 2 g intravenosa.',
      }),
    );
    pipeline.ingestSimulatedServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'pt_B',
        'content_index': 0,
        'delta': 'Saturação 92%. Creatinina 1,8 mg/dL.',
      }),
    );

    // B termina antes de A.
    pipeline.ingestSimulatedServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'pt_B',
        'content_index': 0,
        'transcript': 'Saturação 92%. Creatinina 1,8 mg/dL.',
      }),
    );
    pipeline.ingestSimulatedServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'pt_A',
        'content_index': 0,
        'transcript': 'Paciente com dispneia. Ceftriaxona 2 g intravenosa.',
      }),
    );

    expect(
      pipeline.canonicalTranscript,
      'Paciente com dispneia. Ceftriaxona 2 g intravenosa. '
      'Saturação 92%. Creatinina 1,8 mg/dL.',
    );

    final score = pipeline.evaluate(
      id: 'pt_e2e_perfect',
      reference: 'Paciente com dispneia. Ceftriaxona 2 g intravenosa. '
          'Saturação 92%. Creatinina 1,8 mg/dL.',
      medicalTerms: const <String>[
        'dispneia',
        'ceftriaxona',
        'saturação',
        'creatinina',
      ],
      units: const <String>['g', 'mg/dl'],
      criticalPhrases: const <String>[
        'ceftriaxona 2 g',
        'creatinina 1,8 mg/dl',
      ],
    );

    expect(score.wordErrorRate, 0);
    expect(score.medicalTermRecall, 1);
    expect(score.numberRecall, 1);
    expect(score.unitRecall, 1);
    expect(score.criticalPhraseRecall, 1);
    expect(score.weightedClinicalScore, 1);
    expect(score.passesStrictClinicalGate, isTrue);

    await pipeline.dispose();
  });

  test('ES shadow pipeline detects dangerous dose and decimal errors',
      () async {
    final provider = OpenAiRealtimeTranscriptionShadowProvider();
    final pipeline = ClinicalAudioShadowSessionPipeline(provider: provider);

    await pipeline.start(
      locale: 'es-ES',
      extraMedicalHints: const <String>[
        'ceftriaxona',
        'troponina',
      ],
    );

    for (var i = 0; i < 4; i++) {
      pipeline.enqueueSyntheticPcm(_syntheticPcmFrame(i + 20));
    }
    await pipeline.commitPcm();

    pipeline.ingestSimulatedServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'es_A',
        'content_index': 0,
        'transcript': 'Administrar ceftriaxona 2 mg intravenosa. '
            'Saturación 92%. Troponina 0,8 ng/mL.',
      }),
    );

    final score = pipeline.evaluate(
      id: 'es_e2e_unsafe',
      reference: 'Administrar ceftriaxona 2 g intravenosa. '
          'Saturación 92%. Troponina 0,08 ng/mL.',
      medicalTerms: const <String>[
        'ceftriaxona',
        'saturación',
        'troponina',
      ],
      units: const <String>['g', 'ng/ml'],
      criticalPhrases: const <String>[
        'ceftriaxona 2 g',
        'troponina 0,08 ng/ml',
      ],
    );

    expect(score.medicalTermRecall, 1);
    expect(score.numberRecall, lessThan(1));
    expect(score.unitRecall, lessThan(1));
    expect(score.criticalPhraseRecall, 0);
    expect(score.weightedClinicalScore, lessThan(0.95));
    expect(score.passesStrictClinicalGate, isFalse);

    await pipeline.dispose();
  });

  test('partial deltas become cumulative before reconciler', () async {
    final provider = OpenAiRealtimeTranscriptionShadowProvider();
    final pipeline = ClinicalAudioShadowSessionPipeline(provider: provider);

    await pipeline.start(locale: 'pt-BR');

    pipeline.ingestSimulatedServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'item_1',
        'content_index': 0,
        'delta': 'Cef',
      }),
    );
    pipeline.ingestSimulatedServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'item_1',
        'content_index': 0,
        'delta': 'triaxona',
      }),
    );

    expect(pipeline.canonicalTranscript, 'Ceftriaxona');

    pipeline.ingestSimulatedServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'item_1',
        'content_index': 0,
        'transcript': 'Ceftriaxona 2 g.',
      }),
    );

    expect(pipeline.canonicalTranscript, 'Ceftriaxona 2 g.');

    await pipeline.dispose();
  });

  test('session update carries PT/ES medical context into shadow protocol',
      () async {
    final sink = _RecordingShadowSink();
    final provider = OpenAiRealtimeTranscriptionShadowProvider(sink: sink);
    final pipeline = ClinicalAudioShadowSessionPipeline(provider: provider);

    await pipeline.start(
      locale: 'pt-BR',
      extraMedicalHints: const <String>['dímero D'],
    );

    final session = jsonDecode(sink.events.first) as Map<String, dynamic>;
    final sessionBody = session['session'] as Map<String, dynamic>;
    final audio = sessionBody['audio'] as Map<String, dynamic>;
    final input = audio['input'] as Map<String, dynamic>;
    final tx = input['transcription'] as Map<String, dynamic>;
    final keywords = List<String>.from(tx['keywords'] as List<dynamic>);

    expect(tx['languages'], <String>['pt']);
    expect(keywords, contains('dímero D'));
    expect(keywords, contains('ceftriaxona'));

    await pipeline.dispose();
  });

  test('pipeline remains shadow-only and absent from production owners', () {
    final source = File(
      'lib/services/audio/clinical_audio_shadow_session_pipeline.dart',
    ).readAsStringSync();

    for (final forbidden in <String>[
      'package:http',
      'dart:io',
      'WebSocket',
      'HttpClient',
      'Uri.parse(',
      'Authorization',
      'Bearer ',
      'api.openai.com',
      'Firebase',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('static const bool productionCutoverEnabled = false'),
    );
    expect(
      source,
      contains('static const bool remoteTransportEnabled = false'),
    );
    expect(
      source,
      contains('static const bool realAudioEnabled = false'),
    );
    expect(
      source,
      contains('static const bool audioPersistenceEnabled = false'),
    );

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalAudioShadowSessionPipeline')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalAudioShadowSessionPipeline')),
    );
  });
}
