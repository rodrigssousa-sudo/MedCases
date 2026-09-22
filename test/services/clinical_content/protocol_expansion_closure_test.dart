import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medcases/services/clinical_content/clinical_content_gateway.dart';
import 'clinical_content_foundation_test.dart' as fixtures;
import 'package:medcases/services/clinical_content/clinical_content_models.dart';
import 'package:medcases/services/clinical_content/clinical_content_contract.dart';

Map<String, dynamic> technicalProtocol(String id) {
  final doc = fixtures.item(id);
  doc['payload'] = {
    'id': id,
    for (final key in ['title', 'severity', 'recognize', 'avoid'])
      key: {'pt': 'SYNTHETIC_SCHEMA_ONLY', 'es': 'SYNTHETIC_SCHEMA_ONLY'},
    'actions': {'pt': <String>[], 'es': <String>[]},
    'drugs': <String>[],
  };
  doc['contentHash'] = itemContentHash(doc);
  return doc;
}

void main() {
  test('technical protocol IDs grow 270 to 271 to 670 using delta only',
      () async {
    // Schema-only fixtures: no medical recommendations or doses.
    var rows = List.generate(270, (i) => technicalProtocol('${i + 1}'));
    var server = fixtures.release({'protocols': rows});
    final gateway = ClinicalContentGateway(
      baseUri: Uri.parse('https://fixture.invalid/v1/'),
      store: MemoryClinicalSnapshotStore(),
      sessionScope: 'fixture',
      currentSessionScope: () => 'fixture',
      canReadDomain: (_) => true,
      tokenProvider: () async => 'fixture-token',
      client: MockClient((request) async => http.Response(
          jsonEncode(server[request.url.path.substring('/v1/'.length)]), 200)),
    );
    gateway.registerModelValidator(ClinicalContentModels.validate);
    addTearDown(gateway.close);
    expect((await gateway.sync()).downloadedItems, 270);
    rows = [...rows, technicalProtocol('271')];
    server = fixtures.release({'protocols': rows}, sequence: 2);
    final one = await gateway.sync();
    expect(one.activated, isTrue);
    expect(one.downloadedItems, 1);
    expect(ProtocolResolver(gateway).lookup('271')?.canonicalId, '271');
    rows = [
      ...rows,
      ...List.generate(399, (i) => technicalProtocol('${i + 272}'))
    ];
    server = fixtures.release({'protocols': rows}, sequence: 3);
    final expansion = await gateway.sync();
    expect(expansion.activated, isTrue);
    expect(expansion.downloadedItems, 399);
    expect(gateway.activeItems('protocols').length, 670);
    expect(
        gateway
            .activeItems('protocols')
            .map(ClinicalContentModels.protocol)
            .length,
        670);
    expect(ProtocolResolver(gateway).lookup('670')?.canonicalId, '670');
  });
}
