import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_asr_provider.dart';
import 'package:medcases/services/audio/clinical_audio_capture_provider.dart';
import 'package:medcases/services/audio/openai_realtime_transcription_shadow_protocol.dart';
import 'package:medcases/services/audio/openai_realtime_transcription_shadow_provider.dart';

final class _RecordingSink implements OpenAiRealtimeShadowSink {
  final List<String> events = <String>[];

  @override
  Future<void> send(String encodedEvent) async {
    events.add(encodedEvent);
  }
}

void main() {
  const format = ClinicalPcmFormat();

  test('session update is PCM24k transcription with context', () {
    const protocol = OpenAiRealtimeTranscriptionProtocol();
    final event = protocol.sessionUpdate(
      ClinicalAsrSessionConfig(
        locale: 'pt-BR',
        format: format,
        vocabularyHints: const <String>[
          'ceftriaxona',
          'troponina',
        ],
        contextHint: 'Consulta clínica médico-paciente.',
      ),
    );

    final session = event['session'] as Map<String, Object?>;
    final audio = session['audio'] as Map<String, Object?>;
    final input = audio['input'] as Map<String, Object?>;
    final pcm = input['format'] as Map<String, Object?>;
    final tx = input['transcription'] as Map<String, Object?>;

    expect(event['type'], 'session.update');
    expect(session['type'], 'transcription');
    expect(pcm['type'], 'audio/pcm');
    expect(pcm['rate'], 24000);
    expect(input['turn_detection'], isNull);
    expect(tx['model'], 'gpt-live-transcribe');
    expect(tx['languages'], <String>['pt']);
    expect(tx['delay'], 'high');
    expect(tx['keywords'], <String>['ceftriaxona', 'troponina']);
    expect(tx['prompt'], 'Consulta clínica médico-paciente.');
    expect(tx.containsKey('language'), isFalse);
  });

  test('append serializes PCM base64 and commit is explicit', () {
    const protocol = OpenAiRealtimeTranscriptionProtocol();
    final pcm = Uint8List.fromList(<int>[1, 0, 2, 0, 3, 0]);

    final append = protocol.append(pcm);
    expect(append['type'], 'input_audio_buffer.append');
    expect(base64Decode(append['audio']! as String), orderedEquals(pcm));
    expect(protocol.commit()['type'], 'input_audio_buffer.commit');
  });

  test('shadow provider creates protocol events without network', () async {
    final sink = _RecordingSink();
    final provider = OpenAiRealtimeTranscriptionShadowProvider(sink: sink);

    await provider.start(
      ClinicalAsrSessionConfig(locale: 'es-ES', format: format),
    );
    await provider.appendPcm(Uint8List.fromList(<int>[1, 0, 2, 0]));
    await provider.commit();

    expect(
      OpenAiRealtimeTranscriptionShadowProvider.remoteTransportImplemented,
      isFalse,
    );
    expect(
      OpenAiRealtimeTranscriptionShadowProvider.remoteAudioEnabled,
      isFalse,
    );
    expect(
      OpenAiRealtimeTranscriptionShadowProvider.apiCredentialsAccepted,
      isFalse,
    );
    expect(provider.appendCount, 1);
    expect(provider.appendBytes, 4);
    expect(provider.commitCount, 1);
    expect(sink.events, hasLength(3));

    await provider.dispose();
  });

  test('delta and completed remain scoped to item id', () async {
    final provider = OpenAiRealtimeTranscriptionShadowProvider();
    await provider.start(
      ClinicalAsrSessionConfig(locale: 'pt-BR', format: format),
    );

    provider.ingestShadowServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'item_003',
        'content_index': 0,
        'delta': 'Cef',
      }),
    );
    provider.ingestShadowServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'item_003',
        'content_index': 0,
        'delta': 'triaxona',
      }),
    );
    provider.ingestShadowServerEvent(
      jsonEncode(<String, Object?>{
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'item_003',
        'content_index': 0,
        'transcript': 'Ceftriaxona 2 gramas.',
      }),
    );

    final item = provider.ledger.single;
    expect(item.itemId, 'item_003');
    expect(item.partialText, 'Ceftriaxona');
    expect(item.finalText, 'Ceftriaxona 2 gramas.');
    expect(item.completed, isTrue);

    await provider.dispose();
  });

  test('out-of-order completion never mixes item ids', () async {
    final provider = OpenAiRealtimeTranscriptionShadowProvider();
    await provider.start(
      ClinicalAsrSessionConfig(locale: 'es-ES', format: format),
    );

    for (final event in <Map<String, Object?>>[
      <String, Object?>{
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'item_A',
        'content_index': 0,
        'delta': 'Primero ',
      },
      <String, Object?>{
        'type': 'conversation.item.input_audio_transcription.delta',
        'item_id': 'item_B',
        'content_index': 0,
        'delta': 'Segundo ',
      },
      <String, Object?>{
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'item_B',
        'content_index': 0,
        'transcript': 'Segundo turno.',
      },
      <String, Object?>{
        'type': 'conversation.item.input_audio_transcription.completed',
        'item_id': 'item_A',
        'content_index': 0,
        'transcript': 'Primero turno.',
      },
    ]) {
      provider.ingestShadowServerEvent(jsonEncode(event));
    }

    final byId = <String, OpenAiRealtimeTranscriptLedgerEntry>{
      for (final item in provider.ledger) item.itemId: item,
    };
    expect(byId['item_A']!.finalText, 'Primero turno.');
    expect(byId['item_B']!.finalText, 'Segundo turno.');

    await provider.dispose();
  });

  test('shadow source exposes no network auth or production cutover', () {
    final combined = <String>[
      File(
        'lib/services/audio/openai_realtime_transcription_shadow_protocol.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/openai_realtime_transcription_shadow_provider.dart',
      ).readAsStringSync(),
    ].join('\n');

    for (final forbidden in <String>[
      'package:http',
      'dart:io',
      'WebSocket',
      'HttpClient',
      'Uri.parse(',
      'Authorization',
      'Bearer ',
      'openAiKey',
      'api.openai.com',
    ]) {
      expect(combined, isNot(contains(forbidden)), reason: forbidden);
    }

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    expect(
      main,
      isNot(contains('OpenAiRealtimeTranscriptionShadowProvider')),
    );
    expect(
      recorder,
      isNot(contains('OpenAiRealtimeTranscriptionShadowProvider')),
    );
  });
}
