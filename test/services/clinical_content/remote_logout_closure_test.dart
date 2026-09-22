import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/providers/app_provider.dart';
import 'package:medcases/services/clinical_content/clinical_content_gateway.dart';
import 'clinical_content_foundation_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('logout closes configured gateway and removes session-owned platform',
      () async {
    SharedPreferences.setMockInitialValues({});
    final server = fixtures.release({
      'references': [fixtures.item('reference1')]
    });
    final gateway = ClinicalContentGateway(
      baseUri: Uri.parse('https://fixture.invalid/v1/'),
      store: MemoryClinicalSnapshotStore(),
      sessionScope: 'A',
      currentSessionScope: () => 'A',
      canReadDomain: (_) => true,
      tokenProvider: () async => 'test',
      client: MockClient((r) async =>
          http.Response(jsonEncode(server[r.url.path.substring(4)]), 200)),
    );
    final provider = AppProvider();
    provider.configureRemoteClinicalContent(gateway);
    expect(
        (await provider.synchronizeRemoteClinicalContent()).activated, isTrue);
    expect(gateway.lookup('references', 'reference1'), isNotNull);
    provider.clearUser();
    expect(provider.remoteClinicalContent, isNull);
    expect(gateway.lookup('references', 'reference1'), isNull);
    expect((await gateway.sync()).activated, isFalse);
  });
}
