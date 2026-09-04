import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppProvider captures original-input drug evidence asynchronously', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(source, contains("plantao_drug_evidence_request_observer.dart"));
    expect(
      source,
      contains(
        'PlantaoDrugEvidenceShadowSnapshot? '
        'get lastPlantaoDrugEvidenceShadow',
      ),
    );
    expect(source, contains('_capturePlantaoDrugEvidenceShadow('));
    expect(source, contains('originalUserInput: input'));
    expect(source, contains('languageCode: _lang'));
    expect(source, isNot(contains('request.languageCode')));
    expect(source, contains('unawaited(() async'));
    expect(
      source,
      contains('_lastPlantaoShadowRequest?.requestId != request.requestId'),
    );
  });

  test('productive prompt and drug summaries remain unchanged', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();

    expect(source, contains('matchedDrugSummaries: const []'));
    expect(source, contains('proprietaryDrugContext: null'));
    expect(source, isNot(contains('matchedDrugSummaries: drug')));
    expect(source, isNot(contains('proprietaryDrugContext: drug')));
    expect(source, isNot(contains('await _capturePlantaoDrugEvidenceShadow')));
  });

  test('capture uses the original input and existing intent owners only', () {
    final source = File('lib/providers/app_provider.dart').readAsStringSync();
    final start = source.indexOf('void _capturePlantaoDrugEvidenceShadow');
    final end = source.indexOf(
      'Future<void> _capturePlantaoFinalizationShadow',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final captureMethod = source.substring(start, end);

    expect(captureMethod, contains('_classifyIntent(originalUserInput)'));
    expect(captureMethod, contains('_isDirectQuery(originalUserInput)'));
    expect(captureMethod, isNot(contains('lastAiResponse')));
    expect(captureMethod, isNot(contains('generatedText')));
    expect(captureMethod, isNot(contains('finalText')));
  });
}
