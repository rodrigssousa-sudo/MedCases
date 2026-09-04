import 'dart:convert';
import 'dart:typed_data';

import 'clinical_asr_provider.dart';

enum OpenAiRealtimeTranscriptionDelay {
  minimal,
  low,
  medium,
  high,
  xhigh,
}

final class OpenAiRealtimeTranscriptionProtocol {
  const OpenAiRealtimeTranscriptionProtocol({
    this.model = 'gpt-live-transcribe',
    this.delay = OpenAiRealtimeTranscriptionDelay.high,
  });

  final String model;
  final OpenAiRealtimeTranscriptionDelay delay;

  Map<String, Object?> sessionUpdate(ClinicalAsrSessionConfig config) {
    config.validate();

    if (config.format.sampleRate != 24000 ||
        config.format.channels != 1 ||
        config.format.bitsPerSample != 16) {
      throw const ClinicalAsrException(
        'openai_realtime_requires_pcm16_24khz_mono',
      );
    }

    final transcription = <String, Object?>{
      'model': model,
      'languages': <String>[_languageCode(config.locale)],
      'delay': delay.name,
    };

    final prompt = config.contextHint?.trim();
    if (prompt != null && prompt.isNotEmpty) {
      transcription['prompt'] = prompt;
    }

    if (config.vocabularyHints.isNotEmpty) {
      transcription['keywords'] =
          config.vocabularyHints.map(_validateKeyword).toList(growable: false);
    }

    return <String, Object?>{
      'type': 'session.update',
      'session': <String, Object?>{
        'type': 'transcription',
        'audio': <String, Object?>{
          'input': <String, Object?>{
            'format': <String, Object?>{
              'type': 'audio/pcm',
              'rate': 24000,
            },
            'transcription': transcription,
            'turn_detection': null,
          },
        },
      },
    };
  }

  Map<String, Object?> append(Uint8List pcm16) {
    if (pcm16.isEmpty || pcm16.length.isOdd) {
      throw ArgumentError.value(pcm16.length, 'pcm16.length');
    }

    return <String, Object?>{
      'type': 'input_audio_buffer.append',
      'audio': base64Encode(pcm16),
    };
  }

  Map<String, Object?> commit() => const <String, Object?>{
        'type': 'input_audio_buffer.commit',
      };

  String encode(Map<String, Object?> event) => jsonEncode(event);

  OpenAiRealtimeTranscriptObservation? decodeTranscript(
    String encoded, {
    required int receiveSequence,
  }) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final type = decoded['type'];
    if (type == 'conversation.item.input_audio_transcription.delta') {
      return OpenAiRealtimeTranscriptObservation.delta(
        receiveSequence: receiveSequence,
        itemId: _requiredString(decoded, 'item_id'),
        contentIndex: _contentIndex(decoded),
        text: _requiredString(decoded, 'delta'),
      );
    }

    if (type == 'conversation.item.input_audio_transcription.completed') {
      return OpenAiRealtimeTranscriptObservation.completed(
        receiveSequence: receiveSequence,
        itemId: _requiredString(decoded, 'item_id'),
        contentIndex: _contentIndex(decoded),
        text: _requiredString(decoded, 'transcript'),
      );
    }

    return null;
  }

  static String _languageCode(String locale) {
    final normalized = locale.trim().toLowerCase().replaceAll('_', '-');
    final language = normalized.split('-').first;
    if (!RegExp(r'^[a-z]{2,3}$').hasMatch(language)) {
      throw ArgumentError.value(locale, 'locale');
    }
    return language;
  }

  static String _validateKeyword(String raw) {
    final keyword = raw.trim();
    if (keyword.isEmpty ||
        keyword.contains('<') ||
        keyword.contains('>') ||
        keyword.contains('\n') ||
        keyword.contains('\r')) {
      throw ArgumentError.value(raw, 'vocabularyHints');
    }
    return keyword;
  }

  static String _requiredString(
    Map<String, dynamic> event,
    String key,
  ) {
    final value = event[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing/invalid $key');
    }
    return value;
  }

  static int _contentIndex(Map<String, dynamic> event) {
    final value = event['content_index'];
    return value is int && value >= 0 ? value : 0;
  }
}

enum OpenAiRealtimeTranscriptObservationKind {
  delta,
  completed,
}

final class OpenAiRealtimeTranscriptObservation {
  const OpenAiRealtimeTranscriptObservation._({
    required this.kind,
    required this.receiveSequence,
    required this.itemId,
    required this.contentIndex,
    required this.text,
  });

  factory OpenAiRealtimeTranscriptObservation.delta({
    required int receiveSequence,
    required String itemId,
    required int contentIndex,
    required String text,
  }) =>
      OpenAiRealtimeTranscriptObservation._(
        kind: OpenAiRealtimeTranscriptObservationKind.delta,
        receiveSequence: receiveSequence,
        itemId: itemId,
        contentIndex: contentIndex,
        text: text,
      );

  factory OpenAiRealtimeTranscriptObservation.completed({
    required int receiveSequence,
    required String itemId,
    required int contentIndex,
    required String text,
  }) =>
      OpenAiRealtimeTranscriptObservation._(
        kind: OpenAiRealtimeTranscriptObservationKind.completed,
        receiveSequence: receiveSequence,
        itemId: itemId,
        contentIndex: contentIndex,
        text: text,
      );

  final OpenAiRealtimeTranscriptObservationKind kind;
  final int receiveSequence;
  final String itemId;
  final int contentIndex;
  final String text;

  String get key => '$itemId:$contentIndex';
}
