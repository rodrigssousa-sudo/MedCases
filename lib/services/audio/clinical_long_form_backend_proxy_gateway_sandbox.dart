import 'dart:async';

import 'clinical_long_form_backend_auth_contract.dart';
import 'clinical_long_form_backend_no_retention_attestation.dart';
import 'clinical_long_form_backend_proxy_server_contract.dart';
import 'openai_file_transcription_shadow_protocol.dart';

/// Sandbox adapter from the existing gateway boundary to the explicit
/// App <-> MedCases backend server contract.
///
/// No network implementation lives here.
final class ClinicalLongFormBackendProxyGatewaySandbox
    implements MedCasesLongFormBackendTranscriptionGateway {
  ClinicalLongFormBackendProxyGatewaySandbox({
    required ClinicalLongFormBackendProxyTransport transport,
    required ClinicalLongFormBackendNoRetentionAttestationVerifier
        attestationVerifier,
  })  : _transport = transport,
        _attestationVerifier = attestationVerifier;

  static const bool productionCutoverEnabled = false;
  static const bool actualHttpTransportImplemented = false;
  static const bool actualAudioUploadImplemented = false;
  static const bool responseAcceptedWithoutRetentionProof = false;

  final ClinicalLongFormBackendProxyTransport _transport;
  final ClinicalLongFormBackendNoRetentionAttestationVerifier
      _attestationVerifier;

  @override
  Future<MedCasesLongFormBackendTranscriptionResponse> transcribe({
    required OpenAiFileTranscriptionShadowRequest request,
    required ClinicalLongFormBackendTranscriptionGrant grant,
  }) async {
    request.validate();
    grant.validateAt(DateTime.now().toUtc());

    final proxyRequest = ClinicalLongFormBackendProxyRequest(
      sessionId: grant.sessionId,
      segmentPath: request.segmentPath,
      contentLengthBytes: request.fileBytes,
      contentType: 'audio/mp4',
      idempotencyKey: request.deduplicationKey,
      model: request.model,
      language: request.language,
      prompt: request.prompt,
      keywords: request.keywords,
    );

    ClinicalLongFormBackendProxyResponse response;

    try {
      response = await _transport
          .transcribe(
            request: proxyRequest,
            grant: grant,
          )
          .timeout(proxyRequest.timeout);
    } on TimeoutException {
      throw const MedCasesLongFormBackendException(
        'backend_proxy_timeout',
      );
    } on ClinicalLongFormBackendProxyException catch (error) {
      throw MedCasesLongFormBackendException(
        error.code,
        retryable: error.retryable,
      );
    } catch (_) {
      throw const MedCasesLongFormBackendException(
        'backend_proxy_unexpected_failure',
      );
    }

    response.validate();

    if (response.idempotencyKey != proxyRequest.idempotencyKey) {
      throw const MedCasesLongFormBackendException(
        'backend_proxy_idempotency_mismatch',
        retryable: false,
      );
    }

    final attestation = response.noRetentionAttestation;

    final verified = await _attestationVerifier.verify(
      attestation,
    );

    if (!verified) {
      throw const MedCasesLongFormBackendException(
        'backend_no_retention_attestation_invalid',
        retryable: false,
      );
    }

    if (!attestation.temporaryAudioDeleted ||
        attestation.persistedAudioBytes != 0 ||
        attestation.sensitivePayloadLogged) {
      throw const MedCasesLongFormBackendException(
        'backend_no_retention_contract_failed',
        retryable: false,
      );
    }

    return MedCasesLongFormBackendTranscriptionResponse(
      transcript: response.transcript,
      resultRef: response.resultRef,
    );
  }
}
