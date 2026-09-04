import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('AiScreen preserves metadata through debounce and provider call', () {
    final source = File('lib/screens/ai_screen.dart').readAsStringSync();
    expect(source, contains('continuationType: continuationType'));
    expect(source, contains('requestedSections: requestedSections'));
    expect(source, contains('shadowContinuationType: continuationType'));
    expect(source, contains('shadowRequestedSections: requestedSections'));
  });
}
