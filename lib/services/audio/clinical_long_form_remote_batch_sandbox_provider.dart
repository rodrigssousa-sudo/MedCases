import 'clinical_long_form_backend_auth_contract.dart';
import 'clinical_long_form_batch_transcription_provider.dart';
import 'clinical_long_form_remote_transcription_policy.dart';
import 'openai_file_transcription_shadow_protocol.dart';

final class ClinicalLongFormRemoteBatchSandboxProvider
    implements ClinicalLongFormBatchTranscriptionProvider {
  ClinicalLongFormRemoteBatchSandboxProvider({
    required ClinicalLongFormRemoteAudioConsent consent,
    required ClinicalLongFormBackendGrantProvider grantProvider,
    required MedCasesLongFormBackendTranscriptionGateway gateway,
    required ClinicalLongFormLocalAudioInspector audioInspector,
    required List<String> medicalKeywords,
    DateTime Function()? nowUtc,
  })  : _consent = consent,
        _grantProvider = grantProvider,
        _gateway = gateway,
        _audioInspector = audioInspector,
        _medicalKeywords = List<String>.unmodifiable(medicalKeywords),
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()) {
    _consent.validate();

    if (!ClinicalLongFormBackendAuthPolicy
        .backendMediatedAuthenticationRequired) {
      throw StateError('Backend-mediated auth must remain required.');
    }

    if (ClinicalLongFormRemoteTranscriptionPolicy
        .currentProductionDisclosureCompatible) {
      throw StateError(
        'Sandbox assumes current production disclosure is incompatible.',
      );
    }
  }

  static const bool productionCutoverEnabled = false;
  static const bool actualNetworkTransportImplemented = false;
  static const bool actualAudioUploadImplemented = false;
  static const bool cloudAudioPersistenceEnabled = false;
  static const bool openAiCredentialPresentInFlutter = false;

  final ClinicalLongFormRemoteAudioConsent _consent;
  final ClinicalLongFormBackendGrantProvider _grantProvider;
  final MedCasesLongFormBackendTranscriptionGateway _gateway;
  final ClinicalLongFormLocalAudioInspector _audioInspector;
  final List<String> _medicalKeywords;
  final DateTime Function() _nowUtc;

  @override
  String get providerId => 'medcases_remote_batch_sandbox_gpt_transcribe';

  @override
  Future<ClinicalLongFormBatchTranscriptionResult> transcribeSegment(
    ClinicalLongFormBatchTranscriptionRequest request,
  ) async {
    _consent.validate();
    request.validate();

    final descriptor = await _audioInspector.inspect(request.segmentPath);

    if (descriptor.path != request.segmentPath) {
      throw const ClinicalLongFormBatchTranscriptionException(
        'local_audio_descriptor_path_mismatch',
        retryable: false,
      );
    }

    try {
      ClinicalLongFormRemoteTranscriptionPolicy.validateSegment(
        segmentPath: descriptor.path,
        fileBytes: descriptor.fileBytes,
      );
    } on Object {
      throw const ClinicalLongFormBatchTranscriptionException(
        'remote_audio_segment_policy_rejected',
        retryable: false,
      );
    }

    ClinicalLongFormBackendTranscriptionGrant grant;

    try {
      grant = await _grantProvider.acquireTranscriptionGrant(
        sessionId: request.sessionId,
        deduplicationKey: request.deduplicationKey,
      );
    } on ClinicalLongFormBackendGrantProviderException catch (error) {
      throw ClinicalLongFormBatchTranscriptionException(
        error.code,
        retryable: error.retryable,
      );
    }

    if (grant.sessionId != request.sessionId) {
      throw const ClinicalLongFormBatchTranscriptionException(
        'backend_grant_session_mismatch',
        retryable: false,
      );
    }

    try {
      grant.validateAt(_nowUtc());
    } on Object {
      throw const ClinicalLongFormBatchTranscriptionException(
        'backend_grant_invalid_or_expired',
      );
    }

    final language =
        ClinicalLongFormRemoteTranscriptionPolicy.iso639LanguageFromLocale(
            request.locale);

    final promptParts = <String>[
      'Transcrição médica em $language.',
      'Preservar nomes de fármacos, doses, números e unidades.',
      if (request.previousContext != null &&
          request.previousContext!.trim().isNotEmpty)
        'Contexto anterior: ${request.previousContext!.trim()}',
    ];

    final protocolRequest = OpenAiFileTranscriptionShadowRequest(
      segmentPath: descriptor.path,
      fileBytes: descriptor.fileBytes,
      deduplicationKey: request.deduplicationKey,
      language: language,
      prompt: promptParts.join(' '),
      keywords: _medicalKeywords,
    );

    try {
      final response = await _gateway.transcribe(
        request: protocolRequest,
        grant: grant,
      );

      response.validate();

      return ClinicalLongFormBatchTranscriptionResult(
        segmentIndex: request.segmentIndex,
        deduplicationKey: request.deduplicationKey,
        transcript: response.transcript,
        resultRef: response.resultRef,
      );
    } on MedCasesLongFormBackendException catch (error) {
      throw ClinicalLongFormBatchTranscriptionException(
        error.code,
        retryable: error.retryable,
      );
    } on ClinicalLongFormBatchTranscriptionException {
      rethrow;
    } catch (_) {
      throw const ClinicalLongFormBatchTranscriptionException(
        'backend_transcription_unexpected_failure',
      );
    }
  }

  @override
  Future<void> dispose() async {}
}
