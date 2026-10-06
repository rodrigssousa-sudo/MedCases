import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medcases/models/canonical_clinical_snapshot.dart';
import 'package:medcases/services/ai_stream/gpt_sse_client.dart';
import 'package:medcases/services/ai_stream/ai_event.dart';
import 'package:medcases/services/ai/plantao_canonical_request.dart';

Map<String, dynamic> fixture() {
  final clinical = [
    {'type': 'title', 'id': 'synthetic'},
    {
      'type': 'section',
      'id': 'reference_doses',
      'facts': [
        {
          'id': 'dose',
          'action': 'explain',
          'polarity': 'affirmative',
          'conceptCodes': ['synthetic_agent'],
          'conditionCodes': [],
          'template': '{{drug}} {{amount}}',
          'slots': [
            {
              'id': 'drug',
              'kind': 'clinical_concept',
              'value': 'synthetic_agent'
            },
            {'id': 'amount', 'kind': 'quantity', 'value': '42 mg IV'},
          ]
        }
      ]
    },
  ];
  return {
    'version': CanonicalClinicalSnapshot.version,
    'clinical': clinical,
    'factsHash': CanonicalClinicalSnapshot.hash(clinical),
    'sources': [],
    'presentation': [
      {
        'labels': {'pt': 'Exemplo sintético', 'es': 'Ejemplo sintético'}
      },
      {
        'facts': [
          {
            'id': 'dose',
            'labels': {
              'drug': {'pt': 'Agente fictício:', 'es': 'Agente ficticio:'}
            }
          }
        ]
      },
    ]
  };
}

class Transport extends http.BaseClient {
  final Stream<List<int>> bytes;
  final int status;
  http.BaseRequest? request;
  Transport(this.bytes, {this.status = 200});
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) async {
    request = r;
    return http.StreamedResponse(bytes, status,
        headers: {'content-type': 'text/event-stream'});
  }

  @override
  void close() {}
}

List<int> event(String name, Map<String, dynamic> data) =>
    utf8.encode('event: $name\ndata: ${jsonEncode({
          'requestId': 'test',
          'attempt': 2,
          ...data
        })}\n\n');
void main() {
  test('missing canonical snapshot cannot attest completion', () async {
    final transport = Transport(Stream.fromIterable([
      event('started', {'answerContract': CanonicalClinicalSnapshot.version}),
      event('text_delta',
          {'sequence': 1, 'delta': 'Synthetic complete sentence.'}),
      event('transport_done', {}),
    ]));
    final c = GptSseClient(
        endpointUrl: 'https://example.test',
        idToken: 'synthetic',
        clientFactory: () => transport);
    final events = await c
        .stream(GptSsePayload(
            userMessage: 'Synthetic',
            systemPrompt: '',
            lang: 'es',
            requestId: 'test',
            answerContract: CanonicalClinicalSnapshot.version))
        .toList();
    expect(events.whereType<AiCompleted>(), isEmpty);
    expect(events.whereType<AiFailed>(), isNotEmpty);
  });
  test('ordinary completion has no canonical attestation', () {
    expect(
        AiCompleted.now(
                requestId: 'test',
                attempt: 2,
                fullText: 'Synthetic',
                usedProvider: 'test')
            .canonicalSnapshotValidated,
        isFalse);
  });
  test('canonical numbers, slots, order and references are one representation',
      () {
    final json = fixture(), s = CanonicalClinicalSnapshot.fromJson(json);
    for (final lang in ['pt', 'es'])
      expect(s.blocks(lang).join(), contains('42 mg IV'));
    (json['clinical'] as List)[1]['facts'][0]['slots'][1]['value'] = '99 mg';
    expect(s.blocks('pt').join(), contains('42 mg IV'));
    expect(
        () => CanonicalClinicalSnapshot.fromJson(json), throwsFormatException);
  });
  test('missing or reordered localization cannot silently drop a fact', () {
    final json = fixture();
    (json['presentation'] as List)[1]['facts'][0]['id'] = 'different';
    expect(
        () => CanonicalClinicalSnapshot.fromJson(json), throwsFormatException);
  });
  test('semantic identity is shared only for recognized equivalent contexts',
      () {
    final c = CanonicalConversationCache();
    String key(String q,
            {String uid = 'one',
            String prompt = 'fixed',
            Object history = const []}) =>
        c.key(uid: uid, prompt: prompt, query: q, history: history);
    expect(key('Encefalopatia hepática: tratamento e doses'),
        key('Encefalopatía hepática: tratamiento y dosis'));
    expect(key('Metformina'), isNot(key('Metformina para paciente de 25 kg')));
    expect(key('Metformina'),
        isNot(key('Metformina', prompt: 'changed knowledge')));
    expect(
        key('Metformina'),
        isNot(key('Metformina', history: [
          {'role': 'user', 'content': 'allergy'}
        ])));
    final k = key('Metformina');
    c.put(k, 'server', CanonicalClinicalSnapshot.fromJson(fixture()),
        'gpt-5.6-luna', 'openai');
    key('Metformina', uid: 'two');
    expect(c.get(k), isNull);
  });
  test(
      'production request compiler has adaptive structure and no legacy authorities',
      () {
    final p = PlantaoCanonicalRequest.compile(
        query: 'Metformina', context: {'patient': {}, 'sources': []});
    expect(p, contains('GENERAL_EDUCATIONAL_QUERY'));
    expect(p, contains('RESPONSE_DENSITY=BEDSIDE'));
    for (final marker in [
      'M58_MACHINE_NATIVE',
      'RESPUESTA COMPLETADA',
      'RED FLAGS',
      'ORDEM OBRIGATÓRIA'
    ]) expect(p, isNot(contains(marker)));
    expect(
        PlantaoCanonicalRequest.compile(
            query: 'Calcule para este paciente de 22 kg', context: {}),
        contains('CALCULATION_QUERY'));
  });
  test(
      'knowledge keeps source facts and provenance once and freezes dependencies',
      () {
    final context = <String, Object?>{
      'patient': {'weight': 'supplied'},
      'drugEvidence': {
        'manifest': {'version': 'synthetic_v1'},
        'documents': [
          {
            'id': 'synthetic_agent',
            'dataVersion': 'synthetic_v1',
            'clinicalContentSha256': 'synthetic_hash',
            'sourceModule': 'synthetic_catalog',
            'pt': {'dose': '42 mg IV', 'monitoring': 'Verificar resposta.'},
            'es': {'dose': '42 mg IV', 'monitoring': 'Verificar respuesta.'},
          }
        ]
      }
    };
    final before = jsonEncode(context);
    final pt = PlantaoCanonicalRequest.compile(
        query: 'Encefalopatia hepática: tratamento e doses', context: context);
    final es = PlantaoCanonicalRequest.compile(
        query: 'Encefalopatía hepática: tratamiento y dosis', context: context);
    expect(pt, es);
    expect(jsonEncode(context), before);
    expect('42 mg IV'.allMatches(pt).length, 1);
    expect(pt, contains('synthetic_catalog'));
    expect(pt, contains('Verificar resposta.'));
    final changed = Map<String, Object?>.from(context)
      ..['patient'] = {'weight': 'different'};
    expect(
        PlantaoCanonicalRequest.compile(query: 'Metformina', context: changed),
        isNot(PlantaoCanonicalRequest.compile(
            query: 'Metformina', context: context)));
  });
  test(
      'real SSE parser emits a styled block before completion and stores only complete snapshot',
      () async {
    final wire = StreamController<List<int>>();
    final transport = Transport(wire.stream);
    final cache = CanonicalConversationCache();
    final key =
        cache.key(uid: 'qa', prompt: '', query: 'Metformina', history: []);
    final client = GptSseClient(
        endpointUrl: 'https://example.test',
        idToken: 'synthetic',
        clientFactory: () => transport,
        canonicalCache: cache,
        canonicalCacheKey: key);
    final received = <AiEvent>[];
    final completion = Completer<void>();
    client
        .stream(const GptSsePayload(
            userMessage: 'Metformina',
            systemPrompt: '',
            requestId: 'test',
            answerContract: CanonicalClinicalSnapshot.version))
        .listen(received.add, onDone: completion.complete);
    final snapshot = CanonicalClinicalSnapshot.fromJson(fixture());
    wire.add(event('started', {
      'model': 'gpt-5.6-luna',
      'provider': 'openai',
      'pipeline': 'plantao_canonical_v1',
      'answerContract': CanonicalClinicalSnapshot.version
    }));
    final blocks = snapshot.blocks('pt');
    for (var i = 0; i < blocks.length; i++)
      wire.add(event('text_delta', {'sequence': i + 1, 'delta': blocks[i]}));
    await Future<void>.delayed(Duration.zero);
    expect(received.whereType<AiTextDelta>().map((e) => e.delta).join(),
        blocks.join());
    expect(received.whereType<AiCompleted>(), isEmpty);
    expect(cache.get(key), isNull);
    wire.add(event('canonical_snapshot',
        {'snapshot': fixture(), 'reuseKey': 'server-key'}));
    wire.add(event('transport_done', {}));
    await wire.close();
    await completion.future;
    expect(received.whereType<AiFailed>(), isEmpty);
    expect(received.whereType<AiCompleted>().single.fullText, blocks.join());
    expect(received.whereType<AiCompleted>().single.canonicalSnapshotValidated,
        isTrue);
    expect(cache.get(key)!.snapshot.factsHash, snapshot.factsHash);
  });
  test(
      'session reuse still requires a fresh server auth response; 10 executions share facts',
      () async {
    final cache = CanonicalConversationCache();
    final key =
        cache.key(uid: 'qa', prompt: '', query: 'Metformina', history: []);
    final s = CanonicalClinicalSnapshot.fromJson(fixture());
    cache.put(key, 'server-key', s, 'gpt-5.6-luna', 'openai');
    for (var i = 0; i < 10; i++) {
      final t = Transport(Stream.fromIterable([
        event('canonical_reuse', {
          'reuseKey': 'server-key',
          'answerContract': CanonicalClinicalSnapshot.version
        }),
        event('transport_done', {})
      ]));
      final c = GptSseClient(
          endpointUrl: 'https://example.test',
          idToken: 'synthetic',
          clientFactory: () => t,
          canonicalCache: cache,
          canonicalCacheKey: key);
      final es = i.isOdd;
      final events = await c
          .stream(GptSsePayload(
              userMessage: 'Metformina',
              systemPrompt: '',
              lang: es ? 'es' : 'pt',
              requestId: 'test',
              answerContract: CanonicalClinicalSnapshot.version,
              canonicalReuseKey: 'server-key'))
          .toList();
      expect(t.request, isNotNull);
      expect(events.whereType<AiFailed>(), isEmpty);
      expect(events.whereType<AiCompleted>().single.canonicalSnapshotValidated,
          isTrue);
      expect(events.whereType<AiCompleted>().single.fullText,
          s.blocks(es ? 'es' : 'pt').join());
    }
    final denied = GptSseClient(
        endpointUrl: 'https://example.test',
        idToken: 'synthetic',
        canonicalCache: cache,
        canonicalCacheKey: key,
        clientFactory: () => Transport(const Stream.empty(), status: 403));
    final result = await denied
        .stream(const GptSsePayload(
            userMessage: 'Metformina',
            systemPrompt: '',
            answerContract: CanonicalClinicalSnapshot.version,
            canonicalReuseKey: 'server-key'))
        .toList();
    expect(result.whereType<AiTextDelta>(), isEmpty);
    expect(result.whereType<AiFailed>(), isNotEmpty);
  });
}
