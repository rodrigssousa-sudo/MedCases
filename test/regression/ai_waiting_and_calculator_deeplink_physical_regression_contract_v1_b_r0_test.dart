import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String region(String source, String start, String end) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a);
  expect(a, greaterThanOrEqualTo(0));
  expect(b, greaterThan(a));
  return source.substring(a, b);
}

void main() {
  late String ai;
  late String calc;
  setUpAll(() {
    ai = File('lib/screens/ai_screen.dart').readAsStringSync();
    calc = File('lib/screens/calculadora_screen.dart').readAsStringSync();
  });

  test('AI generation stages avoid unbounded stretch', () {
    final stages = region(
      ai,
      'class _AiClinicalGenerationStages extends StatefulWidget',
      'class _AiResponseIdentityHeader extends StatelessWidget',
    );
    expect(stages, isNot(contains('CrossAxisAlignment.stretch')));
    expect(stages, contains('CrossAxisAlignment.start'));
    expect(stages, contains('height: 128'));
    expect(
      stages,
      contains("ValueKey('ai-clinical-generation-activity-rail')"),
    );
    expect(stages, contains('Construindo sua resposta'));
    expect(stages, contains('Construyendo tu respuesta'));
  });

  test('AI thinking branch still owns generation widget', () {
    expect(ai, contains('if (_thinking && i == _messages.length)'));
    expect(ai, contains('_AiClinicalGenerationStages('));
  });

  test('calculator calls existing public router after page finish', () {
    expect(calc, contains('Future<void> _applyInitialDeepLinkBridge() async'));
    expect(calc, contains('await _applyInitialDeepLinkBridge();'));
    expect(calc, contains("final tab = (params['tab'] ?? '').trim();"));
    expect(calc, contains('window.MedCasesRouter.go(tab, opts || {})'));
    expect(calc, contains('attempts <= 24'));
  });

  test('canonical deeplink fields remain supported', () {
    for (final token in const ["'lang'", "'q'", "'drug1'", "'drug2'"]) {
      expect(calc, contains(token));
    }
  });

  test('local-first, theme and patient contracts remain intact', () {
    expect(calc, isNot(contains('..loadRequest(Uri.parse(_webUrl));')));
    expect(calc, contains('buildLocalUrl(_webUrl)'));
    expect(calc, contains('widget.initialUrl ??'));
    expect(calc, contains('await _injectTheme();'));
    expect(calc, contains('await _injectPatientContext();'));
  });

  test('deeplink fallback is page-finish driven, not one-shot state', () {
    expect(calc, isNot(contains('_initialDeepLinkBridgeApplied')));
    expect(calc, contains('await _applyInitialDeepLinkBridge();'));
    expect(calc, contains('window.MedCasesRouter.go(tab, opts || {})'));
  });
}
