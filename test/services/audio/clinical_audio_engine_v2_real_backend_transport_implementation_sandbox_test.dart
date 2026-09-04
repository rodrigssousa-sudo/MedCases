import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medcases/services/audio/clinical_long_form_backend_auth_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_backend_proxy_server_contract.dart';
import 'package:medcases/services/audio/clinical_long_form_https_backend_proxy_transport.dart';
import 'package:medcases/services/audio/clinical_long_form_pre_cutover_gate.dart';
import 'package:medcases/services/audio/file_clinical_long_form_local_audio_inspector.dart';

final class _CapturingClient extends http.BaseClient {
  _CapturingClient({
    required this.statusCode,
    required this.responseBody,
  });

  final int statusCode;
  final String responseBody;

  int calls = 0;
  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest request,
  ) async {
    calls++;
    lastRequest = request;

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(responseBody)),
      statusCode,
      headers: const <String, String>{
        'content-type': 'application/json',
      },
    );
  }
}

ClinicalLongFormBackendTranscriptionGrant _grant({
  String sessionId = 'real_transport_001',
}) {
  final now = DateTime.now().toUtc();

  return ClinicalLongFormBackendTranscriptionGrant(
    sessionId: sessionId,
    scope: ClinicalLongFormBackendTranscriptionGrant.requiredScope,
    accessToken: 'medcases_backend_grant_1234567890',
    issuedAtUtc: now.subtract(const Duration(minutes: 1)),
    expiresAtUtc: now.add(const Duration(minutes: 10)),
  );
}

ClinicalLongFormBackendProxyRequest _request({
  required String path,
  required int bytes,
  String sessionId = 'real_transport_001',
}) {
  return ClinicalLongFormBackendProxyRequest(
    sessionId: sessionId,
    segmentPath: path,
    contentLengthBytes: bytes,
    contentType: 'audio/mp4',
    idempotencyKey: '$sessionId:segment:0',
    model: 'gpt-transcribe',
    language: 'pt',
    prompt: 'Preservar nomes de fármacos, doses, números e unidades.',
    keywords: const <String>[
      'ceftriaxona',
      'insuficiência cardíaca',
    ],
  );
}

String _successResponse({
  String key = 'real_transport_001:segment:0',
}) {
  final received = DateTime.utc(2026, 8, 19, 13);
  final completed = received.add(const Duration(seconds: 4));
  final deleted = completed.add(const Duration(seconds: 1));

  return jsonEncode(<String, Object?>{
    'idempotencyKey': key,
    'transcript': 'Ceftriaxona 2 g intravenosa.',
    'resultRef': 'backend://real-sandbox/result-001',
    'noRetentionAttestation': <String, Object?>{
      'schemaVersion': 'medcases.long_form_backend_no_retention.v1',
      'idempotencyKey': key,
      'requestReceivedAtUtc': received.toIso8601String(),
      'upstreamCompletedAtUtc': completed.toIso8601String(),
      'temporaryAudioDeletedAtUtc': deleted.toIso8601String(),
      'temporaryAudioDeleted': true,
      'persistedAudioBytes': 0,
      'sensitivePayloadLogged': false,
      'attestationToken': 'signed_real_sandbox_attestation_1234567890',
    },
  });
}

void main() {
  test('real local audio inspector reads regular M4A metadata', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_real_transport_inspector_',
    );

    try {
      final file = File(
        '${root.path}${Platform.pathSeparator}segment_00000.m4a',
      );
      await file.writeAsBytes(
        List<int>.generate(128, (index) => index % 255),
        flush: true,
      );

      const inspector = FileClinicalLongFormLocalAudioInspector();
      final descriptor = await inspector.inspect(file.path);

      expect(descriptor.path, file.path);
      expect(descriptor.fileBytes, 128);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('transport rejects non-HTTPS endpoint at construction', () {
    expect(
      () => ClinicalLongFormHttpsBackendProxyTransport(
        endpoint: Uri.parse(
          'http://sandbox.medcases.invalid/v1/transcribe',
        ),
        client: _CapturingClient(
          statusCode: 200,
          responseBody: '{}',
        ),
      ),
      throwsArgumentError,
    );
  });

  test('real transport builds multipart request and parses server contract',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_real_transport_happy_',
    );

    try {
      final file = File(
        '${root.path}${Platform.pathSeparator}segment_00000.m4a',
      );
      await file.writeAsBytes(
        List<int>.filled(256, 7),
        flush: true,
      );

      final client = _CapturingClient(
        statusCode: 200,
        responseBody: _successResponse(),
      );

      final transport = ClinicalLongFormHttpsBackendProxyTransport(
        endpoint: Uri.parse(
          'https://sandbox.medcases.invalid/v1/audio/transcriptions',
        ),
        client: client,
      );

      final response = await transport.transcribe(
        request: _request(
          path: file.path,
          bytes: await file.length(),
        ),
        grant: _grant(),
      );

      expect(response.transcript, 'Ceftriaxona 2 g intravenosa.');
      expect(
        response.resultRef,
        'backend://real-sandbox/result-001',
      );
      expect(
        response.noRetentionAttestation.persistedAudioBytes,
        0,
      );
      expect(
        response.noRetentionAttestation.temporaryAudioDeleted,
        isTrue,
      );

      expect(client.calls, 1);
      expect(client.lastRequest, isA<http.MultipartRequest>());

      final multipart = client.lastRequest! as http.MultipartRequest;

      expect(multipart.method, 'POST');
      expect(multipart.url.scheme, 'https');
      expect(
        multipart.url.host,
        'sandbox.medcases.invalid',
      );
      expect(
        multipart.headers['X-MedCases-Idempotency-Key'],
        'real_transport_001:segment:0',
      );
      expect(
        multipart.headers['X-MedCases-Audio-Retention'],
        'transient-delete',
      );
      expect(
        multipart.headers['Authorization'],
        startsWith('Bearer medcases_backend_grant_'),
      );

      expect(multipart.fields['sessionId'], 'real_transport_001');
      expect(
        multipart.fields['idempotencyKey'],
        'real_transport_001:segment:0',
      );
      expect(multipart.fields['model'], 'gpt-transcribe');
      expect(multipart.fields['language'], 'pt');
      expect(multipart.fields['contentType'], 'audio/mp4');
      expect(multipart.files, hasLength(1));
      expect(multipart.files.single.field, 'audio');
      expect(
        multipart.files.single.filename,
        'segment_00000.m4a',
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('file size mutation is rejected before HTTP send', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_real_transport_size_',
    );

    try {
      final file = File(
        '${root.path}${Platform.pathSeparator}segment_00000.m4a',
      );
      await file.writeAsBytes(
        List<int>.filled(32, 1),
        flush: true,
      );

      final client = _CapturingClient(
        statusCode: 200,
        responseBody: _successResponse(),
      );

      final transport = ClinicalLongFormHttpsBackendProxyTransport(
        endpoint: Uri.parse(
          'https://sandbox.medcases.invalid/v1/audio/transcriptions',
        ),
        client: client,
      );

      await expectLater(
        () => transport.transcribe(
          request: _request(
            path: file.path,
            bytes: 31,
          ),
          grant: _grant(),
        ),
        throwsA(
          isA<ClinicalLongFormBackendProxyException>().having(
            (error) => error.retryable,
            'retryable',
            isFalse,
          ),
        ),
      );

      expect(client.calls, 0);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('HTTP status retry classification is deterministic', () async {
    final root = await Directory.systemTemp.createTemp(
      'medcases_real_transport_status_',
    );

    try {
      final file = File(
        '${root.path}${Platform.pathSeparator}segment_00000.m4a',
      );
      await file.writeAsBytes(
        List<int>.filled(16, 2),
        flush: true,
      );

      Future<ClinicalLongFormBackendProxyException> run(int status) async {
        final transport = ClinicalLongFormHttpsBackendProxyTransport(
          endpoint: Uri.parse(
            'https://sandbox.medcases.invalid/v1/audio/transcriptions',
          ),
          client: _CapturingClient(
            statusCode: status,
            responseBody: '{"error":"synthetic"}',
          ),
        );

        try {
          await transport.transcribe(
            request: _request(
              path: file.path,
              bytes: await file.length(),
            ),
            grant: _grant(),
          );
        } on ClinicalLongFormBackendProxyException catch (error) {
          return error;
        }

        throw StateError('Expected backend transport exception.');
      }

      expect((await run(503)).retryable, isTrue);
      expect((await run(429)).retryable, isTrue);
      expect((await run(401)).retryable, isFalse);
      expect((await run(413)).retryable, isFalse);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('pre-cutover gate records transport implemented but not certified', () {
    const gate = ClinicalLongFormPreCutoverGate();
    final assessment = gate.evaluate(
      ClinicalLongFormPreCutoverEvidence.currentCertifiedFoundation(),
    );

    expect(
      assessment.blockers,
      isNot(contains(
        ClinicalLongFormPreCutoverRequirement.realBackendTransportImplemented,
      )),
    );
    expect(
      assessment.blockers,
      isNot(
        contains(
          ClinicalLongFormPreCutoverRequirement
              .realBackendTransportSandboxCertified,
        ),
      ),
    );
    expect(assessment.eligible, isTrue);
  });

  test('real transport remains sandbox-only and unwired from production', () {
    final transportSource = File(
      'lib/services/audio/'
      'clinical_long_form_https_backend_proxy_transport.dart',
    ).readAsStringSync();

    expect(
      transportSource,
      contains('actualHttpTransportImplemented = true'),
    );
    expect(
      transportSource,
      contains('actualMultipartAudioUploadImplemented = true'),
    );
    expect(
      transportSource,
      contains('endpointHardcoded = false'),
    );
    expect(
      transportSource,
      contains('openAiCredentialUsedByClient = false'),
    );
    expect(
      transportSource,
      contains('productionCutoverEnabled = false'),
    );

    for (final forbidden in <String>[
      'api.openai.com',
      'OPENAI_API_KEY',
      'sk-',
      'https://api.',
    ]) {
      expect(
        transportSource,
        isNot(contains(forbidden)),
        reason: forbidden,
      );
    }

    final main = File('lib/main.dart').readAsStringSync();
    final recorder =
        File('lib/services/clinical_recorder_service.dart').readAsStringSync();
    final history = File('lib/screens/history_screen.dart').readAsStringSync();

    expect(
      main,
      isNot(contains('ClinicalLongFormHttpsBackendProxyTransport')),
    );
    expect(
      recorder,
      isNot(contains('ClinicalLongFormHttpsBackendProxyTransport')),
    );
    expect(
      history,
      isNot(contains('ClinicalLongFormHttpsBackendProxyTransport')),
    );
  });
}
