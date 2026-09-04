import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy protocol retrieval transports the exact matched models', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(source, contains('List<ProtocolModel>? matchedProtocols'));
    expect('matchedProtocols?.add(p);'.allMatches(source).length, 2);
    expect(source, contains('final qaMatchedProtocols = <ProtocolModel>[];'));
    expect(
      source,
      contains('final matchedProtocolModels = <ProtocolModel>[];'),
    );
    expect(source, contains('qaProtos.isNotEmpty'));
    expect(source, contains('_extProtos.isNotEmpty'));
  });
}
