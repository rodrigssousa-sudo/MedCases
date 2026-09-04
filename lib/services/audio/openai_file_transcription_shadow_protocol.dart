import 'clinical_long_form_backend_auth_contract.dart';
import 'clinical_long_form_remote_transcription_policy.dart';

final class ClinicalLongFormLocalAudioDescriptor {
  const ClinicalLongFormLocalAudioDescriptor({
    required this.path,
    required this.fileBytes,
  });

  final String path;
  final int fileBytes;
}

abstract interface class ClinicalLongFormLocalAudioInspector {
  Future<ClinicalLongFormLocalAudioDescriptor> inspect(
    String segmentPath,
  );
}

final class OpenAiFileTranscriptionShadowRequest {
  OpenAiFileTranscriptionShadowRequest({
    required this.segmentPath,
    required this.fileBytes,
    required this.deduplicationKey,
    required this.language,
    required this.prompt,
    required List<String> keywords,
    this.model =
        ClinicalLongFormRemoteTranscriptionPolicy.fileTranscriptionModel,
  }) : keywords = List<String>.unmodifiable(keywords) {
    validate();
  }

  final String segmentPath;
  final int fileBytes;
  final String deduplicationKey;
  final String model;
  final String language;
  final String prompt;
  final List<String> keywords;

  void validate() {
    ClinicalLongFormRemoteTranscriptionPolicy.validateSegment(
      segmentPath: segmentPath,
      fileBytes: fileBytes,
    );

    if (model !=
        ClinicalLongFormRemoteTranscriptionPolicy.fileTranscriptionModel) {
      throw StateError('Unexpected file transcription model.');
    }

    if (deduplicationKey.trim().isEmpty || deduplicationKey.length > 240) {
      throw ArgumentError.value(
        deduplicationKey,
        'deduplicationKey',
      );
    }

    if (language != 'pt' && language != 'es') {
      throw ArgumentError.value(language, 'language');
    }

    if (prompt.length > 4000) {
      throw ArgumentError.value(prompt.length, 'prompt.length');
    }

    if (keywords.length > 120) {
      throw ArgumentError.value(keywords.length, 'keywords.length');
    }

    for (final keyword in keywords) {
      if (keyword.trim().isEmpty || keyword.length > 120) {
        throw ArgumentError.value(keyword, 'keyword');
      }
    }
  }
}

final class MedCasesLongFormBackendTranscriptionResponse {
  const MedCasesLongFormBackendTranscriptionResponse({
    required this.transcript,
    required this.resultRef,
  });

  final String transcript;
  final String resultRef;

  void validate() {
    if (transcript.trim().isEmpty) {
      throw StateError('Backend returned empty transcription.');
    }
    if (resultRef.trim().isEmpty || resultRef.length > 240) {
      throw StateError('Backend returned invalid opaque resultRef.');
    }
  }
}

final class MedCasesLongFormBackendException implements Exception {
  const MedCasesLongFormBackendException(
    this.code, {
    this.retryable = true,
  });

  final String code;
  final bool retryable;

  @override
  String toString() => 'MedCasesLongFormBackendException('
      'code: $code, retryable: $retryable)';
}

/// Network boundary abstraction.
///
/// A future backend implementation will own the actual HTTPS request.
/// The Flutter sandbox provider never receives or stores an OpenAI key.
abstract interface class MedCasesLongFormBackendTranscriptionGateway {
  Future<MedCasesLongFormBackendTranscriptionResponse> transcribe({
    required OpenAiFileTranscriptionShadowRequest request,
    required ClinicalLongFormBackendTranscriptionGrant grant,
  });
}
