import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_asr_provider.dart';
import 'package:medcases/services/audio/clinical_asr_stream_coordinator.dart';
import 'package:medcases/services/audio/clinical_audio_capture_provider.dart';
import 'package:medcases/services/audio/clinical_medical_vocabulary.dart';

final class _FakeAsrProvider implements ClinicalAsrProvider {
  final StreamController<ClinicalAsrEvent> _events =
      StreamController<ClinicalAsrEvent>.broadcast();

  final List<List<int>> received = <List<int>>[];
  final List<String> lifecycle = <String>[];
  Completer<void>? blockFirstAppend;

  @override
  String get providerId => 'fake_asr';

  @override
  Stream<ClinicalAsrEvent> get events => _events.stream;

  @override
  Future<void> start(ClinicalAsrSessionConfig config) async {
    lifecycle.add('start:${config.locale}');
  }

  @override
  Future<void> appendPcm(Uint8List pcm16) async {
    final blocker = blockFirstAppend;
    if (blocker != null && received.isEmpty) {
      await blocker.future;
    }
    received.add(List<int>.from(pcm16));
  }

  @override
  Future<void> commit() async {
    lifecycle.add('commit');
  }

  @override
  Future<void> stop() async {
    lifecycle.add('stop');
  }

  @override
  Future<void> dispose() async {
    lifecycle.add('dispose');
    await _events.close();
  }
}

void main() {
  const format = ClinicalPcmFormat();

  test('ASR policy is local-only by default', () {
    final config = ClinicalAsrSessionConfig(
      locale: 'pt-BR',
      format: format,
    );

    expect(config.policy.allowRemoteAudio, isFalse);
    expect(config.policy.allowAudioPersistence, isFalse);
  });

  test('medical vocabulary is locale aware, deduplicated and bounded', () {
    final hints = ClinicalMedicalVocabulary.buildHints(
      locale: 'es-ES',
      extraHints: const <String>[
        'ceftriaxona',
        'Troponina',
        'ceftriaxona',
        'dímero D',
      ],
      maxHints: 20,
    );

    expect(hints.length, lessThanOrEqualTo(20));
    expect(hints.first, 'ceftriaxona');
    expect(hints, contains('dímero D'));

    final normalized = hints.map((value) => value.toLowerCase()).toSet();
    expect(normalized.length, hints.length);
  });

  test('coordinator preserves PCM ordering and drains before commit', () async {
    final provider = _FakeAsrProvider();
    final coordinator = ClinicalAsrStreamCoordinator(provider: provider);

    await coordinator.start(
      ClinicalAsrSessionConfig(locale: 'pt-BR', format: format),
    );

    coordinator.enqueueFrame(Uint8List.fromList(<int>[1, 0, 2, 0]));
    coordinator.enqueueFrame(Uint8List.fromList(<int>[3, 0, 4, 0]));
    coordinator.enqueueFrame(Uint8List.fromList(<int>[5, 0, 6, 0]));

    await coordinator.commit();

    expect(
      provider.received,
      <List<int>>[
        <int>[1, 0, 2, 0],
        <int>[3, 0, 4, 0],
        <int>[5, 0, 6, 0],
      ],
    );
    expect(coordinator.acceptedFrames, 3);
    expect(coordinator.sentFrames, 3);
    expect(coordinator.acceptedBytes, 12);
    expect(coordinator.sentBytes, 12);
    expect(provider.lifecycle, <String>['start:pt-BR', 'commit']);

    await coordinator.dispose();
  });

  test('backpressure fails explicitly instead of dropping PCM', () async {
    final provider = _FakeAsrProvider()..blockFirstAppend = Completer<void>();

    final coordinator = ClinicalAsrStreamCoordinator(
      provider: provider,
      maxBufferedFrames: 2,
    );

    await coordinator.start(
      ClinicalAsrSessionConfig(locale: 'es-ES', format: format),
    );

    coordinator.enqueueFrame(Uint8List.fromList(<int>[1, 0]));
    await Future<void>.delayed(Duration.zero);
    coordinator.enqueueFrame(Uint8List.fromList(<int>[2, 0]));
    coordinator.enqueueFrame(Uint8List.fromList(<int>[3, 0]));

    expect(
      () => coordinator.enqueueFrame(Uint8List.fromList(<int>[4, 0])),
      throwsA(isA<ClinicalAsrBackpressureException>()),
    );

    provider.blockFirstAppend!.complete();
    await coordinator.drain();

    expect(coordinator.acceptedFrames, 3);
    expect(coordinator.sentFrames, 3);

    await coordinator.dispose();
  });

  test(
      'ASR foundation contains no network implementation or production cutover',
      () {
    final files = <String>[
      'lib/services/audio/clinical_asr_provider.dart',
      'lib/services/audio/clinical_asr_stream_coordinator.dart',
      'lib/services/audio/clinical_medical_vocabulary.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      for (final forbidden in <String>[
        'package:http',
        'WebSocket',
        'Uri.parse(',
        'api.openai.com',
        'generativelanguage.googleapis.com',
        'Authorization',
        'Bearer ',
        'Firebase',
      ]) {
        expect(source, isNot(contains(forbidden)),
            reason: '$path :: $forbidden');
      }
    }

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();

    expect(main, isNot(contains('clinical_asr_provider.dart')));
    expect(main, isNot(contains('ClinicalAsrStreamCoordinator')));
    expect(recorder, isNot(contains('ClinicalAsrProvider')));
    expect(recorder, isNot(contains('ClinicalAsrStreamCoordinator')));
  });
}
