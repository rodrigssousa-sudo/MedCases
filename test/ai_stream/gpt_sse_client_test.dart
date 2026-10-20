import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medcases/services/ai_stream/ai_event.dart';
import 'package:medcases/services/ai_stream/gpt_sse_client.dart';
import 'package:medcases/models/canonical_clinical_snapshot.dart';

final class _FakeStreamingClient extends http.BaseClient {
  final String responseBody;

  bool wasClosed = false;
  http.BaseRequest? capturedRequest;

  _FakeStreamingClient(this.responseBody);

  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest request,
  ) async {
    capturedRequest = request;

    return http.StreamedResponse(
      Stream<List<int>>.value(
        utf8.encode(responseBody),
      ),
      200,
      headers: const <String, String>{
        'content-type': 'text/event-stream; charset=utf-8',
      },
    );
  }

  @override
  void close() {
    wasClosed = true;
    super.close();
  }
}

String _sseEvent(
  String type,
  Map<String, dynamic> data,
) {
  return 'event: $type\n'
      'data: ${jsonEncode(data)}\n\n';
}

void main() {
  group('Plantão canonical boundary (nonclinical transport fixtures)', () {
    for (final lang in ['pt', 'es']) {
      test('legacy generation cannot bypass Plantão contract $lang', () async {
        final client = _FakeStreamingClient(_sseEvent('started', {
          'requestId': 'legacy_$lang',
          'attempt': 2,
          'model': 'gpt-5.6',
          'provider': 'gpt_5_6',
        }));
        final events = await GptSseClient(
          endpointUrl: GptSseClient.kPlantaoEndpoint,
          idToken: 'synthetic-test-token',
          clientFactory: () => client,
        )
            .stream(GptSsePayload(
              userMessage: 'SYNTHETIC NONCLINICAL FIXTURE',
              systemPrompt: '',
              requestId: 'legacy_$lang',
              lang: lang,
            ))
            .toList();
        expect(events.whereType<AiCompleted>(), isEmpty);
        expect(events.whereType<AiTextDelta>(), isEmpty);
        expect(events.whereType<AiFailed>(), hasLength(1));
        expect(client.wasClosed, isTrue);
      });

      test('verified complete reference survives SSE $lang', () async {
        final requestId = 'reference_$lang';
        const pt = 'Texto sintético de transporte; sem aprovação médica real.';
        const es = 'Texto sintético de transporte; sin aprobación médica real.';
        final raw = jsonEncode({
          // Sorted keys make these nonclinical bytes match the shared canonical
          // hash function without introducing another package dependency.
          'es': {'plantao': es},
          'owner': 'synthetic_fixture',
          'pt': {'plantao': pt},
          'references': <dynamic>[],
          'version': 'TEST_ONLY',
        });
        final digest = CanonicalClinicalSnapshot.hash(jsonDecode(raw));
        final sse = _sseEvent('started', {
              'requestId': requestId,
              'attempt': 2,
              'model': 'approved_protocol',
              'provider': 'clinical_catalog',
              'pipeline': 'plantao_canonical_v1',
              'answerContract': CanonicalClinicalSnapshot.version,
              'approvedPayloadSha256': digest,
            }) +
            _sseEvent('approved_protocol', {
              'requestId': requestId,
              'attempt': 2,
              'protocol': {
                'owner': 'synthetic_fixture',
                'version': 'TEST_ONLY',
                'activeVersion': 'SYNTHETIC_ONLY',
                'payloadSha256': digest,
                'approvedClinicalPayloadJson': raw,
                'scope':
                    'UNCHANGED_GENERAL_PROTOCOL_NOT_INDIVIDUAL_PRESCRIPTION',
                'review': {
                  'recordId': 'SYNTHETIC_REVIEW_NOT_REAL',
                  'reviewerId': 'SYNTHETIC_TEST_ONLY',
                  'reviewedAt': '2026-10-14T00:00:00Z',
                  'evidenceSha256': '0' * 64,
                },
              },
            }) +
            _sseEvent('transport_done', {
              'requestId': requestId,
              'attempt': 2,
              'model': 'approved_protocol',
              'provider': 'clinical_catalog',
            });
        final client = _FakeStreamingClient(sse);
        final events = await GptSseClient(
          endpointUrl: GptSseClient.kPlantaoEndpoint,
          idToken: 'synthetic-test-token',
          clientFactory: () => client,
        )
            .stream(GptSsePayload(
              userMessage: 'SYNTHETIC NONCLINICAL FIXTURE',
              systemPrompt: '',
              requestId: requestId,
              lang: lang,
            ))
            .toList();
        expect(events.whereType<AiFailed>(), isEmpty);
        final completed = events.whereType<AiCompleted>().single;
        expect(completed.fullText, contains(lang == 'pt' ? pt : es));
        expect(completed.referenceDocument?.factsHash, digest);
        expect(
            completed.referenceDocument
                ?.approvedProtocolData?['approvedClinicalPayloadJson'],
            raw);
        expect(client.wasClosed, isTrue);
      });
    }
  });
  // Since 6c10a8bd, Plantão accepts only the canonical reference handshake.
  // These legacy provider-generation cases belong to the Study transport.
  group('GptSseClient Study structured transport_done', () {
    test(
      'converte structuredOutput em ClinicalStructuredOutput tipado',
      () async {
        const requestId = 'req_structured_transport';

        final sse = StringBuffer()
          ..write(
            _sseEvent(
              'started',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'model': 'gpt-5.6',
                'provider': 'gpt_5_6',
                'structuredOutputs': true,
              },
            ),
          )
          ..write(
            _sseEvent(
              'text_delta',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'sequence': 1,
                'delta': 'Conduta ',
              },
            ),
          )
          ..write(
            _sseEvent(
              'text_delta',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'sequence': 2,
                'delta': 'clínica.',
              },
            ),
          )
          ..write(
            _sseEvent(
              'transport_done',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'model': 'gpt-5.6',
                'provider': 'gpt_5_6',
                'structuredOutputs': true,
                'inputTokensApprox': 120,
                'outputTokensApprox': 40,
                'structuredOutput': <String, dynamic>{
                  'diagnosticoHeuristico': 'Pneumonia',
                  'condutaImediata': 'Estabilizar e iniciar investigação.',
                  'prescricao': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'farmaco': 'Ceftriaxona',
                      'posologia': '1 g IV a cada 24 horas',
                    },
                  ],
                },
              },
            ),
          );

        final fakeClient = _FakeStreamingClient(
          sse.toString(),
        );

        final client = GptSseClient(
          endpointUrl: 'https://example.test/gpt',
          idToken: 'token-de-teste',
          clientFactory: () => fakeClient,
        );

        final events = await client
            .stream(
              const GptSsePayload(
                userMessage: 'Caso clínico',
                systemPrompt: 'Prompt clínico',
                mode: 'study',
                requestId: requestId,
              ),
            )
            .toList();

        expect(events, hasLength(4));
        expect(events[0], isA<AiStarted>());
        expect(events[1], isA<AiTextDelta>());
        expect(events[2], isA<AiTextDelta>());
        expect(events[3], isA<AiCompleted>());

        final completed = events.last as AiCompleted;

        expect(completed.fullText, 'Conduta clínica.');
        expect(completed.usedProvider, 'gpt_5_6');
        expect(completed.inputTokensApprox, 120);
        expect(completed.outputTokensApprox, 40);

        expect(
          completed.clinicalOutput?.diagnosticoHeuristico,
          'Pneumonia',
        );
        expect(
          completed.clinicalOutput?.condutaImediata,
          'Estabilizar e iniciar investigação.',
        );
        expect(
          completed.clinicalOutput?.prescricao.single.farmaco,
          'Ceftriaxona',
        );
        expect(
          completed.clinicalOutput?.prescricao.single.posologia,
          '1 g IV a cada 24 horas',
        );

        final captured = fakeClient.capturedRequest as http.Request;

        expect(
          captured.headers['Authorization'],
          'Bearer token-de-teste',
        );
        expect(
          captured.headers['Accept'],
          'text/event-stream',
        );
        expect(
          jsonDecode(captured.body)['requestId'],
          requestId,
        );
        expect(fakeClient.wasClosed, isTrue);
      },
    );

    test(
      'falha de forma não recuperável quando structuredOutput não nulo é inválido',
      () async {
        const requestId = 'req_invalid_structured_transport';

        final sse = StringBuffer()
          ..write(
            _sseEvent(
              'started',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'model': 'gpt-5.6',
                'provider': 'gpt_5_6',
                'structuredOutputs': true,
              },
            ),
          )
          ..write(
            _sseEvent(
              'text_delta',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'sequence': 1,
                'delta': 'Texto clínico parcial.',
              },
            ),
          )
          ..write(
            _sseEvent(
              'transport_done',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'model': 'gpt-5.6',
                'provider': 'gpt_5_6',
                'structuredOutputs': true,
                'structuredOutput': <String, dynamic>{
                  'diagnosticoHeuristico': 'Pneumonia',
                  // Campo condutaImediata ausente de forma intencional.
                  'prescricao': <Map<String, dynamic>>[],
                },
              },
            ),
          );

        final fakeClient = _FakeStreamingClient(sse.toString());

        final client = GptSseClient(
          endpointUrl: 'https://example.test/gpt',
          idToken: 'token-de-teste',
          clientFactory: () => fakeClient,
        );

        final events = await client
            .stream(
              const GptSsePayload(
                userMessage: 'Caso clínico',
                systemPrompt: 'Prompt clínico',
                mode: 'study',
                requestId: requestId,
              ),
            )
            .toList();

        expect(events.whereType<AiCompleted>(), isEmpty);
        expect(events.whereType<AiFailed>(), hasLength(1));

        final failure = events.whereType<AiFailed>().single;

        expect(failure.code, 'gpt_sse_invalid_structured_output');
        expect(failure.retryable, isFalse);
        expect(failure.partialText, 'Texto clínico parcial.');
        expect(fakeClient.wasClosed, isTrue);
      },
    );

    test(
      'mantém clinicalOutput null no transport_done legado',
      () async {
        const requestId = 'req_legacy_transport';

        final sse = StringBuffer()
          ..write(
            _sseEvent(
              'started',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'model': 'gpt-4o-mini',
                'provider': 'gpt_4o_mini',
                'structuredOutputs': false,
              },
            ),
          )
          ..write(
            _sseEvent(
              'text_delta',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'sequence': 1,
                'delta': 'Resposta legada',
              },
            ),
          )
          ..write(
            _sseEvent(
              'transport_done',
              const <String, dynamic>{
                'requestId': requestId,
                'attempt': 2,
                'model': 'gpt-4o-mini',
                'provider': 'gpt_4o_mini',
                'structuredOutputs': false,
                'structuredOutput': null,
              },
            ),
          );

        final fakeClient = _FakeStreamingClient(
          sse.toString(),
        );

        final client = GptSseClient(
          endpointUrl: 'https://example.test/gpt',
          idToken: 'token-de-teste',
          clientFactory: () => fakeClient,
        );

        final events = await client
            .stream(
              const GptSsePayload(
                userMessage: 'Pergunta',
                systemPrompt: 'Prompt',
                mode: 'study',
                requestId: requestId,
              ),
            )
            .toList();

        final completed = events.last as AiCompleted;

        expect(completed.fullText, 'Resposta legada');
        expect(completed.usedProvider, 'gpt_4o_mini');
        expect(completed.clinicalOutput, isNull);
        expect(fakeClient.wasClosed, isTrue);
      },
    );
  });
}
