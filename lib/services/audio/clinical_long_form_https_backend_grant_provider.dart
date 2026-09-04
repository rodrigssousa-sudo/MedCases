import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'clinical_long_form_backend_auth_contract.dart';

final class ClinicalLongFormHttpsBackendGrantProvider
    implements ClinicalLongFormBackendGrantProvider {
  ClinicalLongFormHttpsBackendGrantProvider({
    required Uri endpoint,
    required http.Client client,
    required ClinicalLongFormBackendSessionAccessTokenProvider
        sessionAccessTokenProvider,
    DateTime Function()? nowUtc,
  })  : _endpoint = endpoint,
        _client = client,
        _sessionAccessTokenProvider = sessionAccessTokenProvider,
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()) {
    _validateEndpoint(endpoint);
  }

  static const bool productionCutoverEnabled = false;
  static const bool actualHttpsGrantTransportImplemented = true;
  static const bool endpointHardcoded = false;
  static const bool persistentGrantStorageUsed = false;
  static const bool openAiCredentialUsedByClient = false;
  static const int maxResponseBytes = 64 * 1024;
  static const Duration requestTimeout = Duration(seconds: 30);

  final Uri _endpoint;
  final http.Client _client;
  final ClinicalLongFormBackendSessionAccessTokenProvider
      _sessionAccessTokenProvider;
  final DateTime Function() _nowUtc;

  @override
  Future<ClinicalLongFormBackendTranscriptionGrant> acquireTranscriptionGrant({
    required String sessionId,
    required String deduplicationKey,
  }) async {
    _validateIdentity(
      sessionId: sessionId,
      deduplicationKey: deduplicationKey,
    );

    final sessionToken =
        (await _sessionAccessTokenProvider.acquireSessionAccessToken()).trim();

    if (sessionToken.length < 16) {
      throw const ClinicalLongFormBackendGrantProviderException(
        'backend_session_access_token_unavailable',
        retryable: false,
      );
    }

    final request = http.Request('POST', _endpoint)
      ..headers['Authorization'] = 'Bearer $sessionToken'
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json'
      ..body = jsonEncode(<String, Object?>{
        'sessionId': sessionId,
        'deduplicationKey': deduplicationKey,
        'scope': ClinicalLongFormBackendTranscriptionGrant.requiredScope,
      });

    http.StreamedResponse response;

    try {
      response = await _client.send(request).timeout(requestTimeout);
    } on TimeoutException {
      throw const ClinicalLongFormBackendGrantProviderException(
        'backend_grant_timeout',
      );
    } on ClinicalLongFormBackendGrantProviderException {
      rethrow;
    } catch (_) {
      throw const ClinicalLongFormBackendGrantProviderException(
        'backend_grant_network_failure',
      );
    }

    final body = await _readBoundedBody(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClinicalLongFormBackendGrantProviderException(
        'backend_grant_http_${response.statusCode}',
        retryable: _isRetryableStatus(response.statusCode),
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Grant response root invalid.');
      }

      final map = decoded.cast<String, Object?>();

      final responseDedupe = _string(map, 'deduplicationKey');
      if (responseDedupe != deduplicationKey) {
        throw const ClinicalLongFormBackendGrantProviderException(
          'backend_grant_deduplication_mismatch',
          retryable: false,
        );
      }

      final grant = ClinicalLongFormBackendTranscriptionGrant(
        sessionId: _string(map, 'sessionId'),
        scope: _string(map, 'scope'),
        accessToken: _string(map, 'accessToken'),
        issuedAtUtc: DateTime.parse(_string(map, 'issuedAtUtc')).toUtc(),
        expiresAtUtc: DateTime.parse(_string(map, 'expiresAtUtc')).toUtc(),
      );

      if (grant.sessionId != sessionId) {
        throw const ClinicalLongFormBackendGrantProviderException(
          'backend_grant_session_mismatch',
          retryable: false,
        );
      }

      grant.validateAt(_nowUtc());
      return grant;
    } on ClinicalLongFormBackendGrantProviderException {
      rethrow;
    } catch (_) {
      throw const ClinicalLongFormBackendGrantProviderException(
        'backend_grant_response_invalid',
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
        throw const ClinicalLongFormBackendGrantProviderException(
          'backend_grant_response_too_large',
          retryable: false,
        );
      }
      bytes.addAll(chunk);
    }

    try {
      return utf8.decode(bytes);
    } on FormatException {
      throw const ClinicalLongFormBackendGrantProviderException(
        'backend_grant_response_invalid_utf8',
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

  static void _validateIdentity({
    required String sessionId,
    required String deduplicationKey,
  }) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,96}$').hasMatch(sessionId)) {
      throw const ClinicalLongFormBackendGrantProviderException(
        'backend_grant_session_invalid',
        retryable: false,
      );
    }

    if (deduplicationKey.trim().isEmpty || deduplicationKey.length > 240) {
      throw const ClinicalLongFormBackendGrantProviderException(
        'backend_grant_deduplication_invalid',
        retryable: false,
      );
    }
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

  static void _validateEndpoint(Uri endpoint) {
    if (endpoint.scheme != 'https' ||
        endpoint.host.trim().isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.fragment.isNotEmpty) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'Backend grant endpoint must be a clean HTTPS URI.',
      );
    }
  }
}
