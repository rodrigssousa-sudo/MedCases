import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as raw;
import 'package:http/testing.dart';
import 'package:medcases/services/provider_gateway_http.dart' as gateway;

void main() {
  test(
      'provider wire payload goes only to authenticated MedCases origin, no provider key',
      () async {
    raw.Request? captured;
    final client = gateway.Client(
        uid: () => 'A',
        token: () async => 'firebase-test-token',
        transportClient: MockClient((r) async {
          captured = r;
          return raw.Response('{"ok":true}', 200);
        }));
    final request = raw.Request(
        'POST',
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=obsolete-value'))
      ..body = '{"contents":[]}'
      ..headers['x-goog-api-key'] = 'obsolete-value';
    final result = await raw.Response.fromStream(await client.send(request));
    expect(result.statusCode, 200);
    expect(captured!.url.host, Uri.parse(gateway.gatewayBase).host);
    expect(captured!.url.queryParameters.containsKey('key'), false);
    expect(captured!.headers.containsKey('x-goog-api-key'), false);
    expect(captured!.headers['Authorization'], 'Bearer firebase-test-token');
    expect(captured!.body, '{"contents":[]}');
    client.close();
  });
  test('UID switch during token acquisition dispatches no provider request',
      () async {
    var uid = 'A';
    var calls = 0;
    final client = gateway.Client(
        uid: () => uid,
        token: () async {
          uid = 'B';
          return 'token';
        },
        transportClient: MockClient((r) async {
          calls++;
          return raw.Response('', 200);
        }));
    await expectLater(
        client.send(raw.Request(
            'POST',
            Uri.parse(
                'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'))),
        throwsStateError);
    expect(calls, 0);
    client.close();
  });
  test('UID switch while streaming rejects subsequent bytes', () async {
    var uid = 'A';
    final body = StreamController<List<int>>();
    final client = gateway.Client(
        uid: () => uid,
        token: () async => 'token',
        transportClient: MockClient.streaming((request, stream) async {
          await stream.drain<void>();
          return raw.StreamedResponse(body.stream, 200);
        }));
    final response = await client.send(raw.Request(
        'POST',
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent')));
    final received = <List<int>>[];
    final done = Completer<void>();
    response.stream.listen(received.add, onError: (Object error) {
      expect(error, isA<StateError>());
      done.complete();
    });
    body.add([1]);
    await Future<void>.delayed(Duration.zero);
    uid = 'B';
    body.add([2]);
    await done.future;
    expect(received, [
      [1]
    ]);
    await body.close();
    client.close();
  });
}
