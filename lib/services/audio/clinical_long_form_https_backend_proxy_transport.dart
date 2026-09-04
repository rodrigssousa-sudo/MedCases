import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'clinical_long_form_backend_auth_contract.dart';
import 'clinical_long_form_backend_no_retention_attestation.dart';
import 'clinical_long_form_backend_proxy_server_contract.dart';

final class ClinicalLongFormHttpsBackendProxyTransport
    implements ClinicalLongFormBackendProxyTransport {
  ClinicalLongFormHttpsBackendProxyTransport({
    required Uri endpoint,
    required http.Client client,
  })  : _endpoint = endpoint,
        _client = client {
    _validateEndpoint(endpoint);
  }

  static const bool productionCutoverEnabled = false;
  static const bool actualHttpTransportImplemented = true;
  static const bool actualMultipartAudioUploadImplemented = true;
  static const bool endpointHardcoded = false;
  static const bool openAiCredentialUsedByClient = false;
  static const int maxResponseBytes = 2 * 1024 * 1024;

  final Uri _endpoint;
  final http.Client _client;

  @override
  Future<ClinicalLongFormBackendProxyResponse> transcribe({
    required ClinicalLongFormBackendProxyRequest request,
    required ClinicalLongFormBackendTranscriptionGrant grant,
  }) async {
    request.validate();
    grant.validateAt(DateTime.now().toUtc());

    if (grant.sessionId != request.sessionId) {
      throw const ClinicalLongFormBackendProxyException(
        'backend_grant_session_mismatch',
        retryable: false,
      );
    }

    await _validateLocalFile(request);

    final multipart = http.MultipartRequest('POST', _endpoint)
      ..headers['Authorization'] = 'Bearer ${grant.accessToken}'
      ..headers['X-MedCases-Idempotency-Key'] = request.idempotencyKey
      ..headers['X-MedCases-Audio-Retention'] = 'transient-delete'
      ..fields['sessionId'] = request.sessionId
      ..fields['idempotencyKey'] = request.idempotencyKey
      ..fields['model'] = request.model
      ..fields['language'] = request.language
      ..fields['prompt'] = request.prompt
      ..fields['keywordsJson'] = jsonEncode(request.keywords)
      ..fields['contentType'] = request.contentType
      ..fields['contentLengthBytes'] = request.contentLengthBytes.toString();

    multipart.files.add(
      await http.MultipartFile.fromPath(
        'audio',
        request.segmentPath,
      ),
    );

    http.StreamedResponse response;

    try {
      response = await _client.send(multipart).timeout(request.timeout);
    } on ClinicalLongFormBackendProxyException {
      rethrow;
    } catch (_) {
      throw const ClinicalLongFormBackendProxyException(
        'backend_transport_network_failure',
      );
    }

    final body = await _readBoundedBody(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClinicalLongFormBackendProxyException(
        'backend_http_${response.statusCode}',
        retryable: _isRetryableStatus(response.statusCode),
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Response root must be object.');
      }

      final map = decoded.cast<String, Object?>();
      final attestationRaw = map['noRetentionAttestation'];
      if (attestationRaw is! Map<String, dynamic>) {
        throw const FormatException(
          'Missing no-retention attestation.',
        );
      }

      final attestationMap = attestationRaw.cast<String, Object?>();

      final attestation = ClinicalLongFormBackendNoRetentionAttestation(
        schemaVersion: _string(
          attestationMap,
          'schemaVersion',
        ),
        idempotencyKey: _string(
          attestationMap,
          'idempotencyKey',
        ),
        requestReceivedAtUtc: DateTime.parse(
          _string(attestationMap, 'requestReceivedAtUtc'),
        ).toUtc(),
        upstreamCompletedAtUtc: DateTime.parse(
          _string(attestationMap, 'upstreamCompletedAtUtc'),
        ).toUtc(),
        temporaryAudioDeletedAtUtc: DateTime.parse(
          _string(attestationMap, 'temporaryAudioDeletedAtUtc'),
        ).toUtc(),
        temporaryAudioDeleted: _bool(
          attestationMap,
          'temporaryAudioDeleted',
        ),
        persistedAudioBytes: _int(
          attestationMap,
          'persistedAudioBytes',
        ),
        sensitivePayloadLogged: _bool(
          attestationMap,
          'sensitivePayloadLogged',
        ),
        attestationToken: _string(
          attestationMap,
          'attestationToken',
        ),
      );

      return ClinicalLongFormBackendProxyResponse(
        idempotencyKey: _string(map, 'idempotencyKey'),
        transcript: _string(map, 'transcript'),
        resultRef: _string(map, 'resultRef'),
        noRetentionAttestation: attestation,
      );
    } on ClinicalLongFormBackendProxyException {
      rethrow;
    } catch (_) {
      throw const ClinicalLongFormBackendProxyException(
        'backend_response_invalid',
        retryable: false,
      );
    }
  }

  Future<void> _validateLocalFile(
    ClinicalLongFormBackendProxyRequest request,
  ) async {
    final type = await FileSystemEntity.type(
      request.segmentPath,
      followLinks: false,
    );

    if (type == FileSystemEntityType.link) {
      throw const ClinicalLongFormBackendProxyException(
        'backend_audio_symlink_forbidden',
        retryable: false,
      );
    }

    if (type != FileSystemEntityType.file) {
      throw const ClinicalLongFormBackendProxyException(
        'backend_audio_file_missing',
        retryable: false,
      );
    }

    final actualBytes = await File(request.segmentPath).length();

    if (actualBytes != request.contentLengthBytes) {
      throw const ClinicalLongFormBackendProxyException(
        'backend_audio_size_changed',
        retryable: false,
      );
    }
  }

  Future<String> _readBoundedBody(
    http.StreamedResponse response,
  ) async {
    final bytes = <int>[];

    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const ClinicalLongFormBackendProxyException(
          'backend_response_too_large',
          retryable: false,
        );
      }
      bytes.addAll(chunk);
    }

    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const ClinicalLongFormBackendProxyException(
        'backend_response_invalid_utf8',
        retryable: false,
      );
    }
  }

  static bool _isRetryableStatus(int statusCode) {
    return statusCode == 408 ||
        statusCode == 425 ||
        statusCode == 429 ||
        statusCode >= 500;
  }

  static String _string(
    Map<String, Object?> map,
    String key,
  ) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $key.');
    }
    return value;
  }

  static bool _bool(
    Map<String, Object?> map,
    String key,
  ) {
    final value = map[key];
    if (value is! bool) {
      throw FormatException('Invalid $key.');
    }
    return value;
  }

  static int _int(
    Map<String, Object?> map,
    String key,
  ) {
    final value = map[key];
    if (value is! int) {
      throw FormatException('Invalid $key.');
    }
    return value;
  }

  static void _validateEndpoint(Uri endpoint) {
    if (endpoint.scheme != 'https' ||
        endpoint.host.trim().isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.fragment.isNotEmpty) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'Sandbox backend endpoint must be a clean HTTPS URI.',
      );
    }
  }
}
