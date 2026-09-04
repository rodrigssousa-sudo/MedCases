import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'study_google_ai_server_auth_code_gate_v1.dart';

typedef StudyPhysicalCanaryFirebaseIdTokenProvider = Future<String?> Function();

typedef StudyPhysicalCanaryServerAuthCodeProvider = Future<String?> Function({
  required String webClientId,
  required List<String> scopes,
});

typedef StudyPhysicalCanaryHttpPostJson
    = Future<StudyGoogleAiPhysicalCanaryHttpResponse> Function({
  required Uri url,
  required String firebaseIdToken,
  required String armToken,
  required Map<String, Object?> body,
});

class StudyGoogleAiPhysicalCanaryHttpResponse {
  const StudyGoogleAiPhysicalCanaryHttpResponse({
    required this.statusCode,
    required this.json,
  });

  final int statusCode;
  final Map<String, Object?> json;
}

class StudyGoogleAiPhysicalCanaryResult {
  const StudyGoogleAiPhysicalCanaryResult({
    required this.completed,
    required this.safeReason,
    required this.validatedProjectId,
    required this.discoveredProjectIds,
    this.selectionId,
    this.selectionExpiresAtMs,
  });

  final bool completed;
  final String safeReason;
  final String? validatedProjectId;
  final List<String> discoveredProjectIds;
  final String? selectionId;
  final int? selectionExpiresAtMs;

  bool get selectionRequired =>
      selectionId != null && discoveredProjectIds.length > 1;
}

class StudyGoogleAiOAuthPhysicalCanaryClientV1 {
  const StudyGoogleAiOAuthPhysicalCanaryClientV1._();

  static const String version =
      'medcases_study_google_ai_oauth_physical_canary_client_v1';

  static const bool enabled = bool.fromEnvironment(
    'MEDCASES_STUDY_OAUTH_PHYSICAL_CANARY_ENABLED',
    defaultValue: false,
  );

  static const String _canaryUrl = String.fromEnvironment(
    'MEDCASES_STUDY_OAUTH_PHYSICAL_CANARY_URL',
    defaultValue: '',
  );

  static const String _canaryArmToken = String.fromEnvironment(
    'MEDCASES_STUDY_OAUTH_PHYSICAL_CANARY_ARM',
    defaultValue: '',
  );

  static const List<String> requiredScopes = <String>[
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/generative-language.retriever',
  ];

  static bool get configurationReady =>
      enabled &&
      _canaryUrl.startsWith('https://') &&
      _canaryArmToken.length == 64;

  static Future<StudyGoogleAiPhysicalCanaryResult> run({
    String? requestedProjectId,
    StudyPhysicalCanaryFirebaseIdTokenProvider? firebaseIdTokenProvider,
    StudyPhysicalCanaryServerAuthCodeProvider? serverAuthCodeProvider,
    StudyPhysicalCanaryHttpPostJson? httpPostJson,
  }) async {
    if (!enabled) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'physical_canary_client_disabled',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    if (!configurationReady) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'physical_canary_client_configuration_missing',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }
    final initialProjectHint = requestedProjectId?.trim() ?? '';
    if (initialProjectHint.isNotEmpty) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason:
            'initial_oauth_project_hint_forbidden_use_selection_continuation',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    final tokenProvider = firebaseIdTokenProvider ?? _currentFirebaseIdToken;
    final codeProvider = serverAuthCodeProvider ?? _acquireServerAuthCode;
    final postJson = httpPostJson ?? _postJson;

    final firebaseIdToken = await tokenProvider();
    if (firebaseIdToken == null || firebaseIdToken.trim().isEmpty) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'firebase_user_or_id_token_missing',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    final issue = await postJson(
      url: Uri.parse(_canaryUrl),
      firebaseIdToken: firebaseIdToken,
      armToken: _canaryArmToken,
      body: const <String, Object?>{
        'action': 'issue',
      },
    );

    if (issue.statusCode != 200) {
      return StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: _safeReason(issue.json, 'canary_issue_failed'),
        validatedProjectId: null,
        discoveredProjectIds: const <String>[],
      );
    }

    final challengeId = _cleanString(issue.json['challengeId']);
    final state = _cleanString(issue.json['state']);
    final nonce = _cleanString(issue.json['nonce']);

    final oauth = issue.json['oauth'];
    if (oauth is! Map) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'canary_issue_oauth_contract_missing',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    final serverWebClientId = _cleanString(oauth['webClientId']);
    final serverScopes = _stringList(oauth['scopes']);

    if (challengeId.isEmpty ||
        state.isEmpty ||
        nonce.isEmpty ||
        serverWebClientId != StudyGoogleAiServerAuthCodeGateV1.serverClientId ||
        !_sameScopes(serverScopes, requiredScopes)) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'canary_issue_contract_validation_failed',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    final serverAuthorizationCode = await codeProvider(
      webClientId: serverWebClientId,
      scopes: requiredScopes,
    );

    if (serverAuthorizationCode == null ||
        serverAuthorizationCode.trim().isEmpty) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'google_server_auth_code_missing',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    final exchangeBody = <String, Object?>{
      'action': 'exchange',
      'challengeId': challengeId,
      'state': state,
      'nonce': nonce,
      'serverAuthorizationCode': serverAuthorizationCode,
    };

    final selected = requestedProjectId?.trim() ?? '';
    if (selected.isNotEmpty) {
      exchangeBody['requestedProjectId'] = selected;
    }

    final exchange = await postJson(
      url: Uri.parse(_canaryUrl),
      firebaseIdToken: firebaseIdToken,
      armToken: _canaryArmToken,
      body: exchangeBody,
    );

    return _parseExchange(exchange);
  }

  static Future<StudyGoogleAiPhysicalCanaryResult> continueProjectSelection({
    required String selectionId,
    required String requestedProjectId,
    StudyPhysicalCanaryFirebaseIdTokenProvider? firebaseIdTokenProvider,
    StudyPhysicalCanaryHttpPostJson? httpPostJson,
  }) async {
    if (!enabled) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'physical_canary_client_disabled',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    if (!configurationReady) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'physical_canary_client_configuration_missing',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    final opaqueSelectionId = selectionId.trim();
    final selectedProjectId = requestedProjectId.trim();
    if (opaqueSelectionId.isEmpty || selectedProjectId.isEmpty) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'pending_selection_input_missing',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    final tokenProvider = firebaseIdTokenProvider ?? _currentFirebaseIdToken;
    final postJson = httpPostJson ?? _postJson;

    final firebaseIdToken = await tokenProvider();
    if (firebaseIdToken == null || firebaseIdToken.trim().isEmpty) {
      return const StudyGoogleAiPhysicalCanaryResult(
        completed: false,
        safeReason: 'firebase_user_or_id_token_missing',
        validatedProjectId: null,
        discoveredProjectIds: <String>[],
      );
    }

    final exchange = await postJson(
      url: Uri.parse(_canaryUrl),
      firebaseIdToken: firebaseIdToken,
      armToken: _canaryArmToken,
      body: <String, Object?>{
        'action': 'exchange',
        'selectionId': opaqueSelectionId,
        'requestedProjectId': selectedProjectId,
      },
    );

    return _parseExchange(exchange);
  }

  static StudyGoogleAiPhysicalCanaryResult _parseExchange(
    StudyGoogleAiPhysicalCanaryHttpResponse exchange,
  ) {
    final result = exchange.json['result'];
    final resultMap = result is Map
        ? result.cast<String, Object?>()
        : const <String, Object?>{};

    final accepted = resultMap['accepted'] == true;
    final nestedValidatedProject = resultMap['validatedProject'];
    final validatedProjectId =
        _nullableCleanString(resultMap['validatedProjectId']) ??
            (nestedValidatedProject is Map
                ? _nullableCleanString(nestedValidatedProject['projectId'])
                : null);
    final discoveredProjectIds =
        _extractProjectIds(resultMap['discoveredProjects']);
    final selectionId = _nullableCleanString(resultMap['selectionId']);
    final selectionExpiresAtMs =
        _nullableInt(resultMap['selectionExpiresAtMs']);

    return StudyGoogleAiPhysicalCanaryResult(
      completed: exchange.statusCode == 200 && accepted,
      safeReason: accepted
          ? 'physical_canary_completed'
          : _safeReason(
              resultMap.isNotEmpty ? resultMap : exchange.json,
              'physical_canary_exchange_failed',
            ),
      validatedProjectId: validatedProjectId,
      discoveredProjectIds: discoveredProjectIds,
      selectionId: selectionId,
      selectionExpiresAtMs: selectionExpiresAtMs,
    );
  }

  static Future<String?> _currentFirebaseIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }
    return user.getIdToken(true);
  }

  static Future<String?> _acquireServerAuthCode({
    required String webClientId,
    required List<String> scopes,
  }) async {
    const iosClientId = String.fromEnvironment(
      'MEDCASES_STUDY_OAUTH_PHYSICAL_CANARY_IOS_CLIENT_ID',
    );
    if (iosClientId.trim().isEmpty) {
      return null;
    }

    final googleSignIn = GoogleSignIn(
      scopes: scopes,
      clientId: iosClientId,
      serverClientId: webClientId,
      forceCodeForRefreshToken: true,
    );

    // Physical canary must not use lightweight/silent authentication here.
    // A cached account may not include a server auth code on iOS.
    // Clear only the local GoogleSignIn session, then require the
    // user-initiated interactive sign-in from the canary button.
    await googleSignIn.signOut();
    final GoogleSignInAccount? account = await googleSignIn.signIn();

    return account?.serverAuthCode;
  }

  static Future<StudyGoogleAiPhysicalCanaryHttpResponse> _postJson({
    required Uri url,
    required String firebaseIdToken,
    required String armToken,
    required Map<String, Object?> body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $firebaseIdToken',
      );
      request.headers.set(
        'x-medcases-canary-arm',
        armToken,
      );
      request.write(jsonEncode(body));

      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();

      Map<String, Object?> json = const <String, Object?>{};
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          json = decoded.cast<String, Object?>();
        }
      }

      return StudyGoogleAiPhysicalCanaryHttpResponse(
        statusCode: response.statusCode,
        json: json,
      );
    } finally {
      client.close(force: true);
    }
  }

  static String _cleanString(Object? value) =>
      value is String ? value.trim() : '';

  static String? _nullableCleanString(Object? value) {
    final cleaned = _cleanString(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  static int? _nullableInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(_cleanString(value));
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static bool _sameScopes(
    List<String> left,
    List<String> right,
  ) {
    final a = left.toSet();
    final b = right.toSet();
    return a.length == b.length && a.containsAll(b);
  }

  static List<String> _extractProjectIds(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    final ids = <String>[];
    for (final item in value) {
      if (item is Map) {
        final id = _cleanString(item['projectId']);
        if (id.isNotEmpty) {
          ids.add(id);
        }
      }
    }
    return List<String>.unmodifiable(ids);
  }

  static String _safeReason(
    Map<String, Object?> json,
    String fallback,
  ) {
    final fromResult = _cleanString(json['safeReason']);
    return fromResult.isEmpty ? fallback : fromResult;
  }
}
