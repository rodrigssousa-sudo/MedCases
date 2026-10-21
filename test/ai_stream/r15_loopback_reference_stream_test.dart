// Real loopback HTTP bytes through the production SSE client/parser.
// Synthetic documents/auth only; never connects to the production endpoint.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:medcases/models/canonical_clinical_snapshot.dart';
import 'package:medcases/models/plantao_presentation_contract.dart';
import 'package:medcases/services/ai_stream/ai_event.dart';
import 'package:medcases/services/ai_stream/gpt_sse_client.dart';
import '../fixtures/r15_ux_fixtures.dart';
import '../fixtures/r15_drug_reference_snapshots.dart';

class _LoopbackOnly extends http.BaseClient {
  _LoopbackOnly(this.local);
  final Uri local;
  final io = IOClient(HttpClient());
  @override
  Future<http.StreamedResponse> send(http.BaseRequest source) async {
    if (local.host != '127.0.0.1') throw StateError('loopback_only');
    final r = http.Request(source.method, local)
      ..headers.addAll(source.headers)
      ..bodyBytes = await source.finalize().toBytes();
    return io.send(r);
  }

  @override
  void close() => io.close();
}

String event(String type, Map<String, dynamic> data) =>
    'event: $type\ndata: ${jsonEncode(data)}\n\n';
void main() {
  for (final locale in ['pt', 'es']) {
    for (final type in ['protocol', 'drug']) {
      for (final complete in [true, false]) {
        test(
            'HTTP SSE $type $locale complete=$complete; one request, no provisional FULL',
            () async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          var requests = 0;
          const requestId = 'LOOPBACK_TECHNICAL_ONLY';
          final protocol = r15ProtocolFixture(locale);
          final raw = r15DrugReferenceSnapshots[locale]!;
          final hash = type == 'drug'
              ? PlantaoPresentationContract.textHash(raw)
              : protocol['payloadSha256'];
          final model =
              type == 'drug' ? 'canonical_drug_reference' : 'approved_protocol';
          final provider =
              type == 'drug' ? 'canonical_drug_catalog' : 'clinical_catalog';
          final fixture = type == 'drug'
              ? CanonicalClinicalSnapshot.fromDrugReference(raw, hash)
              : CanonicalClinicalSnapshot.fromApprovedProtocol(protocol, hash);
          final body = event('started', {
                'requestId': requestId,
                'attempt': 2,
                'model': model,
                'provider': provider,
                'pipeline': 'plantao_canonical_v1',
                'answerContract': CanonicalClinicalSnapshot.version,
                if (type == 'drug')
                  'referencePayloadSha256': hash
                else
                  'approvedPayloadSha256': hash
              }) +
              event(type == 'drug' ? 'drug_reference' : 'approved_protocol', {
                'requestId': requestId,
                'attempt': 2,
                if (type == 'drug')
                  'documentJson': raw
                else
                  'protocol': protocol
              }) +
              (complete
                  ? event('transport_done', {
                      'requestId': requestId,
                      'attempt': 2,
                      'model': model,
                      'provider': provider
                    })
                  : '');
          final listener = server.listen((r) async {
            requests++;
            await r.drain<void>();
            r.response.headers.contentType =
                ContentType('text', 'event-stream', charset: 'utf-8');
            // Split within UTF-8/multibyte data to exercise actual incremental decoding.
            final bytes = utf8.encode(body);
            for (var i = 0; i < bytes.length; i += 97) {
              r.response.add(bytes.sublist(i, (i + 97).clamp(0, bytes.length)));
            }
            await r.response.close();
          });
          addTearDown(listener.cancel);
          final events = await GptSseClient(
                  endpointUrl: GptSseClient.kPlantaoEndpoint,
                  idToken: 'SYNTHETIC_LOOPBACK_ONLY',
                  clientFactory: () => _LoopbackOnly(
                      Uri.parse('http://127.0.0.1:${server.port}/sse')))
              .stream(GptSsePayload(
                  userMessage: 'TECHNICAL_FIXTURE',
                  systemPrompt: '',
                  requestId: requestId,
                  lang: locale))
              .toList();
          expect(requests, 1);
          expect(events.whereType<AiTextDelta>(), isEmpty);
          if (complete) {
            expect(events.whereType<AiFailed>(), isEmpty);
            final done = events.whereType<AiCompleted>().single;
            expect(done.fullText, fixture.blocks(locale).join());
            expect(done.referenceDocument?.factsHash, hash);
          } else {
            expect(events.whereType<AiCompleted>(), isEmpty);
            expect(events.whereType<AiFailed>(), hasLength(1));
          }
        });
      }
    }
  }
}
