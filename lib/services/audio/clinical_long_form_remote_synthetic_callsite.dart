import 'package:http/http.dart' as http;

import 'clinical_long_form_backend_auth_contract.dart';
import 'clinical_long_form_backend_proxy_gateway_sandbox.dart';
import 'clinical_long_form_batch_transcription_provider.dart';
import 'clinical_long_form_ed25519_no_retention_attestation_verifier.dart';
import 'clinical_long_form_https_backend_grant_provider.dart';
import 'clinical_long_form_https_backend_proxy_transport.dart';
import 'clinical_long_form_remote_audio_consent_store.dart';
import 'clinical_long_form_remote_batch_sandbox_provider.dart';
import 'file_clinical_long_form_local_audio_inspector.dart';

/// Pre-production assembly of the certified remote transcription chain.
///
/// This owner deliberately accepts synthetic validation sessions only.
/// It proves that the Flutter-side components can be assembled against the
/// production-capable MedCases backend contract without activating patient
/// audio, recorder UI, History UI, or production cutover.
final class ClinicalLongFormRemoteSyntheticCallsite {
  ClinicalLongFormRemoteSyntheticCallsite._({
    required ClinicalLongFormRemoteBatchSandboxProvider provider,
  }) : _provider = provider;

  static const bool syntheticWiringCertified = true;
  static const bool productionCallsiteWired = false;
  static const bool productionRemoteAudioEnabled = false;
  static const bool realPatientAudioEnabled = false;
  static const bool productionCutoverEnabled = false;
  static const bool directOpenAiCredentialInFlutter = false;

  static const String requiredSyntheticSessionPrefix = 'synthetic_';

  final ClinicalLongFormRemoteBatchSandboxProvider _provider;

  static Future<ClinicalLongFormRemoteSyntheticCallsite> create({
    required Uri backendBaseUri,
    required http.Client client,
    required ClinicalLongFormBackendSessionAccessTokenProvider
        sessionAccessTokenProvider,
    required Map<String, List<int>> trustedAttestationPublicKeysById,
    required List<String> medicalKeywords,
    ClinicalLongFormRemoteAudioConsentStore consentStore =
        const ClinicalLongFormRemoteAudioConsentStore(),
  }) async {
    _validateBackendBaseUri(backendBaseUri);

    if (trustedAttestationPublicKeysById.isEmpty) {
      throw ArgumentError.value(
        trustedAttestationPublicKeysById,
        'trustedAttestationPublicKeysById',
        'At least one backend attestation public key is required.',
      );
    }

    final consent = await consentStore.activeConsentOrNull();
    if (consent == null) {
      throw StateError('remote_audio_consent_required');
    }
    consent.validate();

    final grantProvider = ClinicalLongFormHttpsBackendGrantProvider(
      endpoint: _resolve(
        backendBaseUri,
        '/api/ai/audio/grant',
      ),
      client: client,
      sessionAccessTokenProvider: sessionAccessTokenProvider,
    );

    final transport = ClinicalLongFormHttpsBackendProxyTransport(
      endpoint: _resolve(
        backendBaseUri,
        '/api/ai/audio/transcriptions',
      ),
      client: client,
    );

    final verifier = ClinicalLongFormEd25519NoRetentionAttestationVerifier(
      trustedPublicKeysById: trustedAttestationPublicKeysById,
    );

    final gateway = ClinicalLongFormBackendProxyGatewaySandbox(
      transport: transport,
      attestationVerifier: verifier,
    );

    final provider = ClinicalLongFormRemoteBatchSandboxProvider(
      consent: consent,
      grantProvider: grantProvider,
      gateway: gateway,
      audioInspector: const FileClinicalLongFormLocalAudioInspector(),
      medicalKeywords: medicalKeywords,
    );

    return ClinicalLongFormRemoteSyntheticCallsite._(
      provider: provider,
    );
  }

  Future<ClinicalLongFormBatchTranscriptionResult> transcribeSyntheticSegment(
    ClinicalLongFormBatchTranscriptionRequest request, {
    required bool syntheticAudioConfirmed,
  }) {
    if (!syntheticAudioConfirmed) {
      throw StateError('synthetic_audio_confirmation_required');
    }

    if (!request.sessionId.startsWith(requiredSyntheticSessionPrefix)) {
      throw StateError('real_or_unclassified_audio_forbidden');
    }

    request.validate();
    return _provider.transcribeSegment(request);
  }

  static Uri _resolve(Uri base, String path) {
    final normalized = base.replace(
      path: '/',
      query: null,
      fragment: null,
    );
    final resolved = normalized.resolve(path);
    if (resolved.scheme != 'https' ||
        resolved.host != base.host ||
        resolved.userInfo.isNotEmpty ||
        resolved.query.isNotEmpty ||
        resolved.fragment.isNotEmpty) {
      throw StateError('backend_endpoint_resolution_invalid');
    }
    return resolved;
  }

  static void _validateBackendBaseUri(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.host.trim().isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw ArgumentError.value(
        uri,
        'backendBaseUri',
        'MedCases backend base URI must be clean HTTPS.',
      );
    }
  }
}
