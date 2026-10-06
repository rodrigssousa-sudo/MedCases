import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'provider_gateway_http.dart' show gatewayBase;
import 'audio/transcription_diagnostics.dart';

abstract interface class TranscriptionEligibilityAuthority {
  Future<void> eligibility(String owner,
      {Map<String, String> reservationHeaders = const {}});
}

abstract interface class TranscriptionBalanceAuthority {
  Future<Map<String, dynamic>> balance(String owner);
}

abstract interface class UsageAuthority {
  Future<Map<String, dynamic>> reserve(
      String owner, Map<String, dynamic> request);
  Future<void> finish(String owner, Map<String, dynamic> request);
}

class ServerUsageAuthority
    implements
        UsageAuthority,
        TranscriptionBalanceAuthority,
        TranscriptionEligibilityAuthority {
  ServerUsageAuthority(
      {http.Client? client,
      String? Function()? uid,
      Future<String?> Function()? token})
      : _client = client ?? http.Client(),
        _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid),
        _token = token ??
            (() async => FirebaseAuth.instance.currentUser?.getIdToken());
  final http.Client _client;
  final String? Function() _uid;
  final Future<String?> Function() _token;
  Future<Map<String, dynamic>> _call(
      String owner, String action, Map<String, dynamic> request,
      {Map<String, String> reservationHeaders = const {}}) async {
    if (owner != _uid()) throw StateError('USAGE_USER_CHANGED');
    final token = await _token();
    if (token == null || token.isEmpty || owner != _uid())
      throw StateError('USAGE_AUTH_REQUIRED');
    final response = await _client
        .post(Uri.parse('$gatewayBase/api/usage/$action'),
            headers: {
              ...reservationHeaders,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(request))
        .timeout(const Duration(seconds: 20));
    if (owner != _uid()) throw StateError('USAGE_USER_CHANGED');
    if (response.statusCode == 429) {
      const codes = {
        'TRANSCRIPTION_LIMIT_REACHED',
        'RECORDING_LIMIT_REACHED',
        'RATE_LIMITED',
        'CONCURRENT_RESERVATION_LIMIT',
        'MONTHLY_USAGE_LIMIT',
        'TECHNICAL_RECORDING_LIMIT'
      };
      String code = 'RATE_LIMITED';
      try {
        final body = jsonDecode(response.body);
        final value = body is Map ? body['code'] ?? body['error'] : null;
        if (codes.contains(value)) code = value as String;
      } catch (_) {/* A proxy 429 is not evidence of quota exhaustion. */}
      throw StateError(code);
    }
    if (response.statusCode != 200) {
      Map<String, dynamic> error = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) error = decoded;
      } catch (_) {}
      final code = safeTranscriptionServerCode(error['code']);
      if (code != null)
        throw TranscriptionFailure(code,
            retryable: code != TranscriptionFailure.providerBlockedCode &&
                error['retryable'] != false);
      throw StateError('USAGE_CONNECTION_REQUIRED');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>)
      throw StateError('INVALID_USAGE_RESPONSE');
    return data;
  }

  @override
  Future<Map<String, dynamic>> balance(String owner) =>
      _call(owner, 'balance', const {});

  @override
  Future<void> eligibility(String owner,
      {Map<String, String> reservationHeaders = const {}}) async {
    final data = await _call(owner, 'eligibility', const {},
        reservationHeaders: reservationHeaders);
    if (data['eligible'] != true)
      throw StateError('INVALID_ELIGIBILITY_RESPONSE');
  }

  @override
  Future<Map<String, dynamic>> reserve(
      String owner, Map<String, dynamic> request) async {
    if ((request['kinds'] as List?)?.contains('transcription') == true) {
      await eligibility(owner);
    }
    final data = await _call(owner, 'reserve', request);
    if (data['state'] != 'reserved' ||
        data['id'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['id'] as String) ||
        data['attempt'] is! String ||
        (data['attempt'] as String).isEmpty ||
        data['maximumMs'] is! int ||
        data['maximumMs'] <= 0 ||
        data['maximumMs'] > request['maximumMs'])
      throw StateError('INVALID_USAGE_RESERVATION');
    return data;
  }

  @override
  Future<void> finish(String owner, Map<String, dynamic> request) async {
    final response = await _call(owner, 'finish', request);
    if (response['state'] != 'completed')
      throw StateError('INVALID_USAGE_RESULT');
  }
}
