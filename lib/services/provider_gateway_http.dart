import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as transport;
export 'package:http/http.dart'
    hide Client, Request, get, post, put, patch, delete, head;

/// Compatibility transport for provider wire formats. Private credentials never
/// cross the client boundary; the existing MedCases server owns them.
const gatewayBase = String.fromEnvironment('MEDCASES_AI_GATEWAY_BASE_URL',
    defaultValue: 'https://medcases-scw37.ondigitalocean.app');

class Client extends transport.BaseClient {
  Client(
      {transport.Client? transportClient,
      Map<String, String> defaultHeaders = const {},
      Future<String?> Function()? token,
      String? Function()? uid})
      : _defaultHeaders = Map.unmodifiable(defaultHeaders),
        _inner = transportClient ?? transport.Client(),
        _token = token ??
            (() =>
                FirebaseAuth.instance.currentUser?.getIdToken() ??
                Future.value(null)),
        _uid = uid ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final Map<String, String> _defaultHeaders;
  final transport.Client _inner;
  final Future<String?> Function() _token;
  final String? Function() _uid;
  @override
  Future<transport.StreamedResponse> send(transport.BaseRequest request) async {
    final base = Uri.parse(gatewayBase);
    final uri =
        request.url.hasScheme ? request.url : base.resolveUri(request.url);
    final provider = uri.host == 'generativelanguage.googleapis.com';
    final gateway =
        uri.origin == base.origin && uri.path.startsWith('/api/ai/provider/');
    if (!provider && !gateway) return _inner.send(request);
    final owner = _uid();
    final token = await _token();
    if (owner == null || owner != _uid() || token == null || token.isEmpty) {
      throw StateError('PROVIDER_AUTH_REQUIRED');
    }
    final query = Map<String, String>.from(uri.queryParameters)..remove('key');
    final target = provider
        ? base.replace(
            path: '/api/ai/provider${uri.path}',
            queryParameters: query.isEmpty ? null : query)
        : uri;
    final proxy = transport.StreamedRequest(request.method, target);
    proxy.headers.addAll(request.headers);
    proxy.headers.addAll(_defaultHeaders);
    proxy.headers.removeWhere((key, _) => [
          'authorization',
          'x-goog-api-key',
          'host'
        ].contains(key.toLowerCase()));
    proxy.headers['Authorization'] = 'Bearer $token';
    proxy.contentLength = request.contentLength;
    final response = _inner.send(proxy);
    final upload =
        proxy.sink.addStream(request.finalize()).whenComplete(proxy.sink.close);
    final completed = await Future.wait<Object?>([
      response,
      upload.then<Object?>((_) => null),
    ]);
    final result = completed.first as transport.StreamedResponse;
    if (owner != _uid()) {
      await result.stream.drain<void>();
      throw StateError('PROVIDER_USER_CHANGED');
    }
    return transport.StreamedResponse(
      _ownedBody(result.stream, owner),
      result.statusCode,
      headers: result.headers,
      request: request,
      contentLength: result.contentLength,
      reasonPhrase: result.reasonPhrase,
      isRedirect: result.isRedirect,
      persistentConnection: result.persistentConnection,
    );
  }

  Stream<List<int>> _ownedBody(Stream<List<int>> body, String owner) async* {
    await for (final chunk in body) {
      if (_uid() != owner) throw StateError('PROVIDER_USER_CHANGED');
      yield chunk;
    }
  }

  @override
  void close() => _inner.close();
}

class Request extends transport.Request {
  Request(super.method, super.url);
  @override
  Future<transport.StreamedResponse> send() async {
    final client = Client();
    try {
      final response = await client.send(this);
      return transport.StreamedResponse(
          _body(response, client), response.statusCode,
          headers: response.headers,
          request: this,
          reasonPhrase: response.reasonPhrase);
    } catch (_) {
      client.close();
      rethrow;
    }
  }
}

Stream<List<int>> _body(
    transport.StreamedResponse response, Client client) async* {
  try {
    yield* response.stream;
  } finally {
    client.close();
  }
}

// Top-level operations close their HTTP transport once the response is consumed.
Future<transport.Response> _call(String method, Uri url,
    {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
  final client = Client();
  try {
    final request = transport.Request(method, url);
    if (headers != null) request.headers.addAll(headers);
    if (encoding != null) request.encoding = encoding;
    if (body is String)
      request.body = body;
    else if (body is List<int>)
      request.bodyBytes = body;
    else if (body is Map<String, String>) request.bodyFields = body;
    return await transport.Response.fromStream(await client.send(request));
  } finally {
    client.close();
  }
}

Future<transport.Response> post(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _call('POST', url, headers: headers, body: body, encoding: encoding);
Future<transport.Response> get(Uri url, {Map<String, String>? headers}) =>
    _call('GET', url, headers: headers);
Future<transport.Response> delete(Uri url,
        {Map<String, String>? headers, Object? body, Encoding? encoding}) =>
    _call('DELETE', url, headers: headers, body: body, encoding: encoding);
