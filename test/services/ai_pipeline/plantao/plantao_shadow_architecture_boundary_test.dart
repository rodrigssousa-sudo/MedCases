import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('shadow adapter has no productive dependencies or execution seam', () {
    final source = File('lib/services/ai_pipeline/plantao/shadow/plantao_request_shadow_adapter.dart').readAsStringSync();
    expect(source, contains('productiveExecutionEnabled = false'));
    expect(source, contains('renderingEnabled = false'));
    expect(source, contains('persistenceEnabled = false'));
    expect(source, isNot(contains('app_provider.dart')));
    expect(source, isNot(contains('firestore')));
    expect(source, isNot(contains('gpt')));
    expect(source, isNot(contains('gemini')));
    expect(source, isNot(contains('.execute(')));
  });
}
