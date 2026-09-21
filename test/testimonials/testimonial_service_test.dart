import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/testimonials/testimonial_service.dart';

void main() {
  test('public feed never sends an identity token; no denied response becomes empty success', () async {
    var tokenRead = false;
    final service = TestimonialService(projectId: 'demo-test', token: () async { tokenRead = true; return 'secret'; },
      client: MockClient((req) async { expect(req.headers.containsKey('Authorization'), false); return http.Response('[]', 200); }));
    expect(await service.published(), isEmpty); expect(tokenRead, false);
    final denied = TestimonialService(projectId:'demo-test', token:() async => 'user-token',
      client: MockClient((_) async => http.Response('{}', 403)));
    await expectLater(denied.mine('owner'), throwsStateError);
  });
  test('submission uses user token, pending status, server times and atomic unpublish', () async {
    final service = TestimonialService(projectId: 'demo-test', token: () async => 'user-token',
      client: MockClient((req) async {
        expect(req.headers['Authorization'], 'Bearer user-token');
        final writes = jsonDecode(req.body)['writes'] as List;
        expect(writes, hasLength(2));
        final f = writes[0]['update']['fields'];
        expect(f['status'], {'stringValue':'pending'}); expect(f['featured'], {'booleanValue':false});
        expect(f.containsKey('email'), false); expect(writes[0]['currentDocument'], {'exists':false});
        expect(writes[0]['updateTransforms'], hasLength(2));
        expect(writes[1]['delete'], endsWith('/testimonial_public/owner'));
        return http.Response('{}', 200);
      }));
    await service.submit(uid:'owner', name:'Name', profession:'Doctor', text:'An actual experience.', photo:'', consent:true);
  });
  test('no write without explicit consent or authenticated session', () async {
    var called = false;
    final service = TestimonialService(projectId:'demo-test', token:() async => '',
      client: MockClient((_) async { called = true; return http.Response('{}',200); }));
    await expectLater(service.submit(uid:'owner', name:'Name', profession:'Doctor', text:'An experience.', photo:'', consent:false), throwsArgumentError);
    await expectLater(service.submit(uid:'owner', name:'Name', profession:'Doctor', text:'An experience.', photo:'', consent:true), throwsStateError);
    expect(called, false);
  });
  test('moderation preserves author content and rejects concurrent changes via updateTime', () async {
    const row = TestimonialRecord('owner', {'uid':'owner','displayName':'Name','profession':'Doctor','text':'An experience.',
      'photo':'','status':'pending','consent':true,'consentVersion':'public-testimonial-v1','featured':false,
      'createdAt':'2026-09-20T00:00:00Z','updatedAt':'2026-09-20T00:00:00Z'}, '2026-09-20T00:00:00Z');
    final service = TestimonialService(projectId:'demo-test',token:() async=>'user-token',client:MockClient((req) async {
      final writes = jsonDecode(req.body)['writes'];
      expect(writes[0]['currentDocument']['updateTime'], row.revision);
      expect(writes[1]['update']['fields'].keys.toSet(), {'displayName','profession','text','photo','featured'});
      expect(writes[1]['update']['fields']['text']['stringValue'], row.text('text'));
      return http.Response('{}', 409);
    }));
    await expectLater(service.moderate(row, approved:true), throwsStateError);
  });
}
