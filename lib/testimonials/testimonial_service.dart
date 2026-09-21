import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../firebase_options.dart';
import '../services/auth_service.dart';

class TestimonialRecord {
  const TestimonialRecord(this.id, this.data, this.revision);
  final String id;
  final Map<String, dynamic> data;
  final String revision;
  String text(String key) => data[key] as String? ?? '';
  bool get featured => data['featured'] == true;
}

/// Uses the existing end-user Firebase ID token, never Admin SDK credentials.
/// The REST transport also works with the app's REST-only web login session.
class TestimonialService {
  TestimonialService(
      {http.Client? client,
      Future<String> Function()? token,
      String? projectId})
      : _client = client ?? http.Client(),
        _token = token ?? _sessionToken,
        _project =
            projectId ?? DefaultFirebaseOptions.currentPlatform.projectId;
  final http.Client _client;
  final Future<String> Function() _token;
  final String _project;
  String get _documents => 'projects/$_project/databases/(default)/documents';
  String get _base => 'https://firestore.googleapis.com/v1/$_documents';
  static Future<String> _sessionToken() async => kIsWeb
      ? await AuthService.getAdminToken()
      : (await AuthService.currentUser?.getIdToken()) ?? '';

  static Map<String, dynamic> _encode(Map<String, dynamic> data) =>
      data.map((k, v) => MapEntry(
          k,
          v is bool
              ? {'booleanValue': v}
              : k.endsWith('At')
                  ? {'timestampValue': v}
                  : {'stringValue': v}));
  static TestimonialRecord _decode(Map<String, dynamic> doc) {
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    return TestimonialRecord(
        (doc['name'] as String).split('/').last,
        fields.map((k, v) => MapEntry(k, (v as Map).values.first)),
        doc['updateTime'] as String? ?? '');
  }

  Future<Map<String, String>> _headers({bool public = false}) async {
    final token = public ? '' : await _token();
    if (!public && token.isEmpty) throw StateError('session-expired');
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token'
    };
  }

  void _check(http.Response response) {
    if (response.statusCode >= 400) {
      // Do not surface tokens, profile data, or raw backend responses in UI/logs.
      throw StateError('testimonials-http-${response.statusCode}');
    }
  }

  Future<TestimonialRecord?> mine(String uid) async {
    final r = await _client
        .get(
            Uri.parse(
                '$_base/testimonial_submissions/${Uri.encodeComponent(uid)}'),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 404) return null;
    _check(r);
    return _decode(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<TestimonialRecord>> _query(String collection,
      {bool public = false, String? status}) async {
    final query = <String, dynamic>{
      'from': [
        {'collectionId': collection}
      ],
      'limit': 100,
      if (status != null)
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'status'},
            'op': 'EQUAL',
            'value': {'stringValue': status}
          }
        }
    };
    final r = await _client
        .post(Uri.parse('$_base:runQuery'),
            headers: await _headers(public: public),
            body: jsonEncode({'structuredQuery': query}))
        .timeout(const Duration(seconds: 15));
    _check(r);
    return (jsonDecode(r.body) as List)
        .where((e) => e['document'] != null)
        .map((e) => _decode(e['document'] as Map<String, dynamic>))
        .toList();
  }

  Future<List<TestimonialRecord>> published() async {
    final rows = await _query('testimonial_public', public: true);
    rows.sort((a, b) => a.featured == b.featured
        ? b.text('updatedAt').compareTo(a.text('updatedAt'))
        : a.featured
            ? -1
            : 1);
    return rows;
  }

  Future<List<TestimonialRecord>> moderation(String status) =>
      _query('testimonial_submissions', status: status);

  Future<void> _commit(List<Map<String, dynamic>> writes) async {
    final r = await _client
        .post(Uri.parse('$_base:commit'),
            headers: await _headers(), body: jsonEncode({'writes': writes}))
        .timeout(const Duration(seconds: 15));
    _check(r);
  }

  Map<String, dynamic> _write(
          String collection, String id, Map<String, dynamic> fields,
          {TestimonialRecord? existing,
          bool create = false,
          bool timestamp = true}) =>
      {
        'update': {
          'name': '$_documents/$collection/$id',
          'fields': _encode(fields)
        },
        if (create || existing != null)
          'currentDocument': existing != null
              ? {'updateTime': existing.revision}
              : {'exists': false},
        if (timestamp)
          'updateTransforms': [
            {'fieldPath': 'updatedAt', 'setToServerValue': 'REQUEST_TIME'},
            if (create)
              {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'},
          ],
      };
  Map<String, dynamic> _delete(String collection, String id) =>
      {'delete': '$_documents/$collection/$id'};

  Future<void> submit(
      {required String uid,
      required String name,
      required String profession,
      required String text,
      required String photo,
      required bool consent,
      TestimonialRecord? existing}) async {
    if (!consent ||
        name.trim().isEmpty ||
        name.trim().length > 80 ||
        profession.trim().isEmpty ||
        profession.trim().length > 80 ||
        text.trim().length < 10 ||
        text.trim().length > 1000 ||
        photo.length > 180000) {
      throw ArgumentError('invalid-testimonial');
    }
    final data = <String, dynamic>{
      'uid': uid,
      'displayName': name.trim(),
      'profession': profession.trim(),
      'text': text.trim(),
      'photo': photo,
      'consent': true,
      'consentVersion': 'public-testimonial-v1',
      'status': 'pending',
      'featured': false,
      if (existing != null) 'createdAt': existing.text('createdAt')
    };
    await _commit([
      _write('testimonial_submissions', uid, data,
          existing: existing, create: existing == null),
      _delete('testimonial_public', uid),
    ]);
  }

  Future<void> moderate(TestimonialRecord row,
      {required bool approved, bool featured = false}) async {
    final data = {
      ...row.data,
      'status': approved ? 'approved' : 'rejected',
      'featured': approved && featured
    };
    final publicData = <String, dynamic>{
      for (final key in ['displayName', 'profession', 'text', 'photo'])
        key: row.data[key],
      'featured': approved && featured
    };
    await _commit([
      _write('testimonial_submissions', row.id, data, existing: row),
      if (approved)
        _write('testimonial_public', row.id, publicData)
      else
        _delete('testimonial_public', row.id),
    ]);
  }

  /// Atomic removal withdraws public consent and deletes the private submission.
  Future<void> remove(TestimonialRecord row) => _commit([
        {
          ..._delete('testimonial_submissions', row.id),
          'currentDocument': {'updateTime': row.revision}
        },
        _delete('testimonial_public', row.id),
      ]);
  void dispose() => _client.close();
}
