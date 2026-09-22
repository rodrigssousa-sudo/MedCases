// MEDCASES_PREMIUM_R7_2_ACCESS_TOKEN_CONTRACT_WEBVIEW_MCC1_BRIDGE_TRANSACTIONAL_V1_B_R0
//
// Native MedCases -> MCC1 issuer client.
//
// Security invariants:
// - Firebase UID authority stays in FirebaseAuth / server-side token verification.
// - No Premium flag is accepted from the WebView.
// - MCC1 is short-lived and is never persisted to disk or browser storage.
// - The raw MCC1 token is never logged.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class CalculatorMcc1Session {
  const CalculatorMcc1Session({
    this.offlineEntitlement,
    required this.token,
    required this.tier,
    required this.capabilities,
    required this.expiresAtUtc,
    required this.entitlementSource,
  });

  final String? offlineEntitlement;
  final String token;
  final String tier;
  final List<String> capabilities;
  final DateTime expiresAtUtc;
  final String entitlementSource;
}

class CalculatorMcc1BridgeException implements Exception {
  const CalculatorMcc1BridgeException(this.code);

  final String code;

  @override
  String toString() => 'CalculatorMcc1BridgeException($code)';
}

class CalculatorMcc1BridgeService {
  const CalculatorMcc1BridgeService();

  static final Uri _issuerUri = Uri.parse(
    'https://medcasespro.com/api/calculator/session',
  );

  static const Duration _timeout = Duration(seconds: 15);

  Future<CalculatorMcc1Session> issueSession({
    bool forceFirebaseRefresh = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const CalculatorMcc1BridgeException(
        'FIREBASE_AUTHENTICATED_USER_REQUIRED',
      );
    }

    var idToken = (await user.getIdToken(forceFirebaseRefresh) ?? '').trim();
    if (idToken.isEmpty) {
      throw const CalculatorMcc1BridgeException(
        'FIREBASE_ID_TOKEN_EMPTY',
      );
    }

    var response = await _postIssuer(idToken);

    // One bounded retry with a forced Firebase refresh if the issuer rejects
    // the first identity token. No unbounded retry loop is permitted.
    if (response.statusCode == 401 && !forceFirebaseRefresh) {
      idToken = (await user.getIdToken(true) ?? '').trim();
      if (idToken.isEmpty) {
        throw const CalculatorMcc1BridgeException(
          'FIREBASE_REFRESHED_ID_TOKEN_EMPTY',
        );
      }
      response = await _postIssuer(idToken);
    }

    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw const CalculatorMcc1BridgeException('ISSUER_USER_CHANGED');
    }
    return parseIssuedSession(
      statusCode: response.statusCode,
      body: response.body,
    );
  }

  Future<http.Response> _postIssuer(String idToken) {
    return http
        .post(
          _issuerUri,
          headers: <String, String>{
            'Authorization': 'Bearer $idToken',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: '{}',
        )
        .timeout(_timeout);
  }

  static CalculatorMcc1Session parseIssuedSession({
    required int statusCode,
    required String body,
  }) {
    if (statusCode != 200) {
      throw CalculatorMcc1BridgeException('ISSUER_HTTP_$statusCode');
    }

    Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const CalculatorMcc1BridgeException(
        'ISSUER_RESPONSE_NOT_JSON',
      );
    }

    if (decoded is! Map) {
      throw const CalculatorMcc1BridgeException(
        'ISSUER_RESPONSE_NOT_OBJECT',
      );
    }

    final map = Map<String, dynamic>.from(decoded);

    final token = (map['accessToken'] ?? '').toString().trim();
    if (!token.startsWith('mcc1.') || token.length < 16) {
      throw const CalculatorMcc1BridgeException(
        'ISSUER_MCC1_TOKEN_INVALID',
      );
    }

    final tier = (map['tier'] ?? '').toString().trim().toLowerCase();
    if (tier != 'free' && tier != 'premium') {
      throw const CalculatorMcc1BridgeException(
        'ISSUER_TIER_INVALID',
      );
    }

    final rawCapabilities = map['capabilities'];
    if (rawCapabilities is! List) {
      throw const CalculatorMcc1BridgeException(
        'ISSUER_CAPABILITIES_INVALID',
      );
    }
    final capabilities = rawCapabilities
        .map((dynamic value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final expiresAtText = (map['expiresAtUtc'] ?? '').toString().trim();
    final expiresAtUtc = DateTime.tryParse(expiresAtText)?.toUtc();
    if (expiresAtUtc == null) {
      throw const CalculatorMcc1BridgeException(
        'ISSUER_EXPIRY_INVALID',
      );
    }
    if (!expiresAtUtc.isAfter(DateTime.now().toUtc())) {
      throw const CalculatorMcc1BridgeException(
        'ISSUER_SESSION_ALREADY_EXPIRED',
      );
    }

    final entitlementSource =
        (map['entitlementSource'] ?? '').toString().trim();

    return CalculatorMcc1Session(
      offlineEntitlement: map['offlineEntitlement'] is String
          ? map['offlineEntitlement'] as String
          : null,
      token: token,
      tier: tier,
      capabilities: List<String>.unmodifiable(capabilities),
      expiresAtUtc: expiresAtUtc,
      entitlementSource: entitlementSource,
    );
  }
}
