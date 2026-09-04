import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../lib/services/study/study_google_ai_oauth_physical_canary_client_v1.dart';
import '../../../lib/services/study/study_google_ai_server_auth_code_gate_v1.dart';

String _methodBlock(String source, String start, String end) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: 'METHOD_START_MISSING:$start');
  expect(b, greaterThan(a), reason: 'METHOD_END_MISSING:$end');
  return source.substring(a, b);
}

void main() {
  test('source contract keeps phase-2 selection free of Google OAuth fields',
      () {
    final client = File(
      'lib/services/study/study_google_ai_oauth_physical_canary_client_v1.dart',
    ).readAsStringSync();
    final app =
        File('lib/study_oauth_physical_canary_app_v1.dart').readAsStringSync();

    expect(client, contains('final String? selectionId;'));
    expect(client, contains('final int? selectionExpiresAtMs;'));
    expect(client, contains('bool get selectionRequired'));
    expect(
      client,
      contains(
        'initial_oauth_project_hint_forbidden_use_selection_continuation',
      ),
    );
    expect(
      client,
      contains("nestedValidatedProject['projectId']"),
    );

    final continuation = _methodBlock(
      client,
      'continueProjectSelection({',
      'static StudyGoogleAiPhysicalCanaryResult _parseExchange(',
    );

    expect(continuation, contains("'action': 'exchange'"));
    expect(continuation, contains("'selectionId': opaqueSelectionId"));
    expect(
      continuation,
      contains("'requestedProjectId': selectedProjectId"),
    );

    for (final forbidden in <String>[
      '_acquireServerAuthCode',
      'serverAuthCodeProvider',
      'GoogleSignIn',
      "'action': 'issue'",
      "'challengeId'",
      "'state'",
      "'nonce'",
      "'serverAuthorizationCode'",
    ]) {
      expect(
        continuation,
        isNot(contains(forbidden)),
        reason: 'PHASE2_FORBIDDEN_TOKEN:$forbidden',
      );
    }

    expect(
      app,
      contains('StudyGoogleAiOAuthPhysicalCanaryClientV1.run();'),
    );
    expect(app, contains('.continueProjectSelection('));
    expect(app, contains('Continuar sem novo OAuth'));
    expect(app, contains('_oauthAttempted = true;'));
    expect(app, isNot(contains('execute novamente')));
    expect(app, isNot(contains('Executar com projeto selecionado')));
    expect(
      app,
      isNot(contains('requestedProjectId: _selectedProjectId')),
    );

    // ignore: avoid_print
    print('DART_PHASE2_SOURCE_NO_GOOGLE_OAUTH=PASS');
    // ignore: avoid_print
    print('DART_APP_SECOND_OAUTH_PATH_REMOVED=PASS');
  });

  test('phase-2 continuation posts selection only with injected transport',
      () async {
    var firebaseCalls = 0;
    var httpCalls = 0;

    final result =
        await StudyGoogleAiOAuthPhysicalCanaryClientV1.continueProjectSelection(
      selectionId: 'opaque-selection-id',
      requestedProjectId: 'project-b',
      firebaseIdTokenProvider: () async {
        firebaseCalls += 1;
        return 'firebase-test-token';
      },
      httpPostJson: ({
        required Uri url,
        required String firebaseIdToken,
        required String armToken,
        required Map<String, Object?> body,
      }) async {
        httpCalls += 1;
        expect(url.toString(), 'https://example.invalid/canary');
        expect(firebaseIdToken, 'firebase-test-token');
        expect(armToken, hasLength(64));
        expect(
          body,
          <String, Object?>{
            'action': 'exchange',
            'selectionId': 'opaque-selection-id',
            'requestedProjectId': 'project-b',
          },
        );

        return const StudyGoogleAiPhysicalCanaryHttpResponse(
          statusCode: 200,
          json: <String, Object?>{
            'result': <String, Object?>{
              'accepted': true,
              'safeReason': 'physical_canary_ready_path_completed',
              'validatedProject': <String, Object?>{
                'projectId': 'project-b',
              },
            },
          },
        );
      },
    );

    expect(firebaseCalls, 1);
    expect(httpCalls, 1);
    expect(result.completed, isTrue);
    expect(result.validatedProjectId, 'project-b');
    expect(result.selectionId, isNull);

    // ignore: avoid_print
    print('DART_PHASE2_FIREBASE_CALLS=1');
    // ignore: avoid_print
    print('DART_PHASE2_HTTP_CALLS=1');
    // ignore: avoid_print
    print('DART_PHASE2_GOOGLE_OAUTH_CALLS=0');
  });

  test('phase-1 multi-project response captures opaque pending selection',
      () async {
    var httpCalls = 0;
    var codeCalls = 0;

    final result = await StudyGoogleAiOAuthPhysicalCanaryClientV1.run(
      firebaseIdTokenProvider: () async => 'firebase-test-token',
      serverAuthCodeProvider: ({
        required String webClientId,
        required List<String> scopes,
      }) async {
        codeCalls += 1;
        expect(
          webClientId,
          StudyGoogleAiServerAuthCodeGateV1.serverClientId,
        );
        return 'auth-code-test-only';
      },
      httpPostJson: ({
        required Uri url,
        required String firebaseIdToken,
        required String armToken,
        required Map<String, Object?> body,
      }) async {
        httpCalls += 1;
        if (httpCalls == 1) {
          expect(body, <String, Object?>{'action': 'issue'});
          return StudyGoogleAiPhysicalCanaryHttpResponse(
            statusCode: 200,
            json: <String, Object?>{
              'challengeId': 'challenge',
              'state': 'state',
              'nonce': 'nonce',
              'oauth': <String, Object?>{
                'webClientId': StudyGoogleAiServerAuthCodeGateV1.serverClientId,
                'scopes':
                    StudyGoogleAiOAuthPhysicalCanaryClientV1.requiredScopes,
              },
            },
          );
        }

        expect(body['action'], 'exchange');
        expect(body['requestedProjectId'], isNull);
        expect(body['selectionId'], isNull);

        return const StudyGoogleAiPhysicalCanaryHttpResponse(
          statusCode: 409,
          json: <String, Object?>{
            'result': <String, Object?>{
              'accepted': false,
              'selectionRequired': true,
              'selectionId': 'opaque-selection-id',
              'selectionExpiresAtMs': 123456789,
              'safeReason':
                  'server_discovered_multiple_projects_pending_selection',
              'discoveredProjects': <Object?>[
                <String, Object?>{'projectId': 'project-a'},
                <String, Object?>{'projectId': 'project-b'},
              ],
            },
          },
        );
      },
    );

    expect(httpCalls, 2);
    expect(codeCalls, 1);
    expect(result.completed, isFalse);
    expect(result.selectionRequired, isTrue);
    expect(result.selectionId, 'opaque-selection-id');
    expect(result.selectionExpiresAtMs, 123456789);
    expect(result.discoveredProjectIds, <String>['project-a', 'project-b']);

    // ignore: avoid_print
    print('DART_PHASE1_PENDING_SELECTION_CAPTURE=PASS');
    // ignore: avoid_print
    print('REAL_GOOGLE_OAUTH_CALLS=0');
    // ignore: avoid_print
    print('REAL_GEMINI_API_CALLS=0');
    // ignore: avoid_print
    print(
      'RESULT=PASS_STUDY_OAUTH_TWO_PHASE_SELECTION_CONTINUATION_CONTRACT',
    );
  });
}
