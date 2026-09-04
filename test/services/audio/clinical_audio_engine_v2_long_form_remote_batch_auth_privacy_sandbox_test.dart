import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_auth_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_batch_transcription_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_batch_sandbox_provider.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_transcription_policy.dart';
import 'package:medcases/services/audio/openai_file_transcription_shadow_protocol.dart';

final class _FakeGrantProvider implements ClinicalLongFormBackendGrantProvider {
  _FakeGrantProvider({
    required this.nowUtc,
    this.expired = false,
  });

  final DateTime nowUtc;
  final bool expired;
  int calls = 0;

  @override
  Future<ClinicalLongFormBackendTranscriptionGrant> acquireTranscriptionGrant({
    required String sessionId,
    required String deduplicationKey,
  }) async {
    calls++;

    return ClinicalLongFormBackendTranscriptionGrant(
      sessionId: sessionId,
      scope: ClinicalLongFormBackendTranscriptionGrant.requiredScope,
      accessToken: 'medcases_ephemeral_token_1234567890',
      issuedAtUtc: nowUtc.subtract(const Duration(minutes: 1)),
      expiresAtUtc: expired
          ? nowUtc.subtract(const Duration(seconds: 1))
          : nowUtc.add(const Duration(minutes: 10)),
    );
  }
}

final class _FakeInspector implements ClinicalLongFormLocalAudioInspector {
  _FakeInspector({
    required this.bytes,
  });

  final int bytes;
  int calls = 0;

  @override
  Future<ClinicalLongFormLocalAudioDescriptor> inspect(
    String segmentPath,
  ) async {
    calls++;
    return ClinicalLongFormLocalAudioDescriptor(
      path: segmentPath,
      fileBytes: bytes,
    );
  }
}

final class _FakeGateway
    implements MedCasesLongFormBackendTranscriptionGateway {
  int calls = 0;
  OpenAiFileTranscriptionShadowRequest? lastRequest;
  ClinicalLongFormBackendTranscriptionGrant? lastGrant;

  @override
  Future<MedCasesLongFormBackendTranscriptionResponse> transcribe({
    required OpenAiFileTranscriptionShadowRequest request,
    required ClinicalLongFormBackendTranscriptionGrant grant,
  }) async {
    calls++;
    lastRequest = request;
    lastGrant = grant;

    return const MedCasesLongFormBackendTranscriptionResponse(
      transcript: 'Paciente com dispneia. Ceftriaxona 2 g intravenosa.',
      resultRef: 'backend://transcription/result-001',
    );
  }
}

ClinicalLongFormBatchTranscriptionRequest _request({
  String locale = 'pt-BR',
}) {
  return ClinicalLongFormBatchTranscriptionRequest(
    sessionId: 'remote_sandbox_001',
    locale: locale,
    segmentIndex: 0,
    segmentPath: '/local/audio/segment_00000.m4a',
    deduplicationKey: 'remote_sandbox_001:segment:0',
    previousContext: 'Paciente com insuficiência cardíaca.',
  );
}

ClinicalLongFormRemoteAudioConsent _consent({
  bool accepted = true,
}) {
  return ClinicalLongFormRemoteAudioConsent(
    disclosureVersion: 'remote_audio_sandbox_v1',
    acceptedAtUtc: DateTime.utc(2026, 8, 19, 12),
    remoteTranscriptionAccepted: accepted,
  );
}

void main() {
  test('current production disclosure blocks remote production cutover', () {
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .currentProductionDisclosureCompatible,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy
          .remoteAudioTransmissionEnabledInProduction,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteTranscriptionPolicy.cloudAudioPersistenceAllowed,
      isFalse,
    );
    expect(
      ClinicalLongFormBackendAuthPolicy.openAiApiKeyInFlutterAllowed,
      isFalse,
    );
  });

  test('remote consent is mandatory before provider construction', () {
    expect(
      () => ClinicalLongFormRemoteBatchSandboxProvider(
        consent: _consent(accepted: false),
        grantProvider: _FakeGrantProvider(
          nowUtc: DateTime.utc(2026, 8, 19, 12),
        ),
        gateway: _FakeGateway(),
        audioInspector: _FakeInspector(bytes: 2400000),
        medicalKeywords: const <String>['ceftriaxona'],
      ),
      throwsStateError,
    );
  });

  test('sandbox uses gpt-transcribe M4A PT context and backend grant',
      () async {
    final now = DateTime.utc(2026, 8, 19, 12);
    final grantProvider = _FakeGrantProvider(nowUtc: now);
    final inspector = _FakeInspector(bytes: 2400000);
    final gateway = _FakeGateway();

    final provider = ClinicalLongFormRemoteBatchSandboxProvider(
      consent: _consent(),
      grantProvider: grantProvider,
      gateway: gateway,
      audioInspector: inspector,
      medicalKeywords: const <String>[
        'ceftriaxona',
        'insuficiência cardíaca',
        'fração de ejeção',
      ],
      nowUtc: () => now,
    );

    final result = await provider.transcribeSegment(_request());

    expect(result.segmentIndex, 0);
    expect(result.transcript, contains('Ceftriaxona 2 g'));
    expect(result.resultRef, startsWith('backend://'));

    expect(grantProvider.calls, 1);
    expect(inspector.calls, 1);
    expect(gateway.calls, 1);

    final protocol = gateway.lastRequest!;
    expect(
      protocol.model,
      ClinicalLongFormRemoteTranscriptionPolicy.fileTranscriptionModel,
    );
    expect(protocol.model, 'gpt-transcribe');
    expect(protocol.segmentPath, endsWith('.m4a'));
    expect(protocol.language, 'pt');
    expect(protocol.fileBytes, 2400000);
    expect(protocol.keywords, contains('ceftriaxona'));
    expect(protocol.prompt, contains('Contexto anterior:'));
    expect(protocol.prompt, contains('doses, números e unidades'));
    expect(
      protocol.deduplicationKey,
      'remote_sandbox_001:segment:0',
    );

    expect(
      gateway.lastGrant!.scope,
      ClinicalLongFormBackendTranscriptionGrant.requiredScope,
    );
    expect(
      gateway.lastGrant!.redactedDescription,
      contains('[REDACTED]'),
    );
    expect(
      gateway.lastGrant!.redactedDescription,
      isNot(contains('medcases_ephemeral_token_1234567890')),
    );

    await provider.dispose();
  });

  test('ES locale is normalized to ISO-639-1 es', () async {
    final now = DateTime.utc(2026, 8, 19, 12);
    final gateway = _FakeGateway();

    final provider = ClinicalLongFormRemoteBatchSandboxProvider(
      consent: _consent(),
      grantProvider: _FakeGrantProvider(nowUtc: now),
      gateway: gateway,
      audioInspector: _FakeInspector(bytes: 2400000),
      medicalKeywords: const <String>['ceftriaxona'],
      nowUtc: () => now,
    );

    await provider.transcribeSegment(
      _request(locale: 'es-AR'),
    );

    expect(gateway.lastRequest!.language, 'es');
    await provider.dispose();
  });

  test('expired backend grant blocks gateway before transmission', () async {
    final now = DateTime.utc(2026, 8, 19, 12);
    final gateway = _FakeGateway();

    final provider = ClinicalLongFormRemoteBatchSandboxProvider(
      consent: _consent(),
      grantProvider: _FakeGrantProvider(
        nowUtc: now,
        expired: true,
      ),
      gateway: gateway,
      audioInspector: _FakeInspector(bytes: 2400000),
      medicalKeywords: const <String>[],
      nowUtc: () => now,
    );

    await expectLater(
      () => provider.transcribeSegment(_request()),
      throwsA(
        isA<ClinicalLongFormBatchTranscriptionException>(),
      ),
    );

    expect(gateway.calls, 0);
    await provider.dispose();
  });

  test('file larger than 25 MB is rejected before auth and gateway', () async {
    final now = DateTime.utc(2026, 8, 19, 12);
    final grants = _FakeGrantProvider(nowUtc: now);
    final gateway = _FakeGateway();

    final provider = ClinicalLongFormRemoteBatchSandboxProvider(
      consent: _consent(),
      grantProvider: grants,
      gateway: gateway,
      audioInspector: _FakeInspector(
        bytes: ClinicalLongFormRemoteTranscriptionPolicy.maxFileBytes + 1,
      ),
      medicalKeywords: const <String>[],
      nowUtc: () => now,
    );

    await expectLater(
      () => provider.transcribeSegment(_request()),
      throwsA(
        isA<ClinicalLongFormBatchTranscriptionException>(),
      ),
    );

    expect(grants.calls, 0);
    expect(gateway.calls, 0);
    await provider.dispose();
  });

  test('backend grant has no serialization surface for credential storage', () {
    final source = File(
      'lib/services/audio/'
      'clinical_long_form_backend_auth_contract.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('toJson')));
    expect(source, isNot(contains('fromJson')));
    expect(
      source,
      contains('persistentGrantStorageAllowed = false'),
    );
    expect(
      source,
      contains('openAiApiKeyInFlutterAllowed = false'),
    );
    expect(
      source,
      contains('backendMediatedAuthenticationRequired = true'),
    );
  });

  test('remote sandbox contains no real network or direct OpenAI credential',
      () {
    final source = <String>[
      File(
        'lib/services/audio/'
        'clinical_long_form_remote_transcription_policy.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_backend_auth_contract.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'openai_file_transcription_shadow_protocol.dart',
      ).readAsStringSync(),
      File(
        'lib/services/audio/'
        'clinical_long_form_remote_batch_sandbox_provider.dart',
      ).readAsStringSync(),
    ].join('\n');

    for (final forbidden in <String>[
      'package:http',
      'dart:io',
      'WebSocket',
      'HttpClient',
      'api.openai.com',
      'OPENAI_API_KEY',
      'Authorization:',
      'Firebase',
      'writeAsString',
      'writeAsBytes',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }

    expect(
      source,
      contains('actualNetworkTransportImplemented = false'),
    );
    expect(
      source,
      contains('actualAudioUploadImplemented = false'),
    );
    expect(
      source,
      contains('productionCutoverEnabled = false'),
    );
    expect(
      source,
      contains('cloudAudioPersistenceEnabled = false'),
    );

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormRemoteBatchSandboxProvider')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormRemoteBatchSandboxProvider')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormRemoteBatchSandboxProvider')),
    );
  });
}
