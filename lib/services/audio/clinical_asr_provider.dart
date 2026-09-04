import 'dart:typed_data';

import 'clinical_audio_capture_provider.dart';

enum ClinicalAsrEventKind {
  ready,
  partial,
  finalResult,
  error,
  closed,
}

final class ClinicalAsrEvent {
  const ClinicalAsrEvent._({
    required this.kind,
    required this.sequence,
    this.text,
    this.errorCode,
  });

  factory ClinicalAsrEvent.ready({required int sequence}) => ClinicalAsrEvent._(
        kind: ClinicalAsrEventKind.ready,
        sequence: sequence,
      );

  factory ClinicalAsrEvent.partial({
    required int sequence,
    required String text,
  }) =>
      ClinicalAsrEvent._(
        kind: ClinicalAsrEventKind.partial,
        sequence: sequence,
        text: text,
      );

  factory ClinicalAsrEvent.finalResult({
    required int sequence,
    required String text,
  }) =>
      ClinicalAsrEvent._(
        kind: ClinicalAsrEventKind.finalResult,
        sequence: sequence,
        text: text,
      );

  factory ClinicalAsrEvent.error({
    required int sequence,
    required String errorCode,
  }) =>
      ClinicalAsrEvent._(
        kind: ClinicalAsrEventKind.error,
        sequence: sequence,
        errorCode: errorCode,
      );

  factory ClinicalAsrEvent.closed({required int sequence}) =>
      ClinicalAsrEvent._(
        kind: ClinicalAsrEventKind.closed,
        sequence: sequence,
      );

  final ClinicalAsrEventKind kind;
  final int sequence;
  final String? text;
  final String? errorCode;
}

final class ClinicalAsrSessionPolicy {
  const ClinicalAsrSessionPolicy({
    this.allowRemoteAudio = false,
    this.allowAudioPersistence = false,
  });

  final bool allowRemoteAudio;
  final bool allowAudioPersistence;

  static const ClinicalAsrSessionPolicy localOnly = ClinicalAsrSessionPolicy();
}

final class ClinicalAsrSessionConfig {
  ClinicalAsrSessionConfig({
    required this.locale,
    required this.format,
    Iterable<String> vocabularyHints = const <String>[],
    this.contextHint,
    this.policy = ClinicalAsrSessionPolicy.localOnly,
  }) : vocabularyHints = List<String>.unmodifiable(
          vocabularyHints.map((value) => value.trim()).where(
                (value) => value.isNotEmpty,
              ),
        ) {
    validate();
  }

  final String locale;
  final ClinicalPcmFormat format;
  final List<String> vocabularyHints;
  final String? contextHint;
  final ClinicalAsrSessionPolicy policy;

  void validate() {
    format.validate();

    if (locale.trim().isEmpty) {
      throw ArgumentError.value(locale, 'locale');
    }
    if (vocabularyHints.length > 128) {
      throw ArgumentError.value(
        vocabularyHints.length,
        'vocabularyHints.length',
        'Maximum 128 hints per ASR session.',
      );
    }

    final normalized = <String>{};
    for (final hint in vocabularyHints) {
      if (hint.length > 80) {
        throw ArgumentError.value(
          hint,
          'vocabularyHints',
          'Each hint must contain at most 80 characters.',
        );
      }
      final key = hint.toLowerCase();
      if (!normalized.add(key)) {
        throw ArgumentError.value(
          hint,
          'vocabularyHints',
          'Duplicate hints are not allowed.',
        );
      }
    }

    final context = contextHint?.trim();
    if (context != null && context.length > 1200) {
      throw ArgumentError.value(
        context.length,
        'contextHint.length',
        'Maximum 1200 characters.',
      );
    }
  }
}

final class ClinicalAsrException implements Exception {
  const ClinicalAsrException(this.code, [this.cause]);

  final String code;
  final Object? cause;

  @override
  String toString() => 'ClinicalAsrException(code: $code, cause: $cause)';
}

abstract interface class ClinicalAsrProvider {
  String get providerId;

  Stream<ClinicalAsrEvent> get events;

  Future<void> start(ClinicalAsrSessionConfig config);

  Future<void> appendPcm(Uint8List pcm16);

  Future<void> commit();

  Future<void> stop();

  Future<void> dispose();
}
