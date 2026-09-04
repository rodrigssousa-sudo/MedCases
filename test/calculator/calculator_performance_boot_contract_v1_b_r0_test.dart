import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String mainSource;
  late String provider;
  late String calculator;
  late String cache;
  late String prewarm;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    provider = File('lib/providers/app_provider.dart').readAsStringSync();
    calculator = File('lib/screens/calculadora_screen.dart').readAsStringSync();
    cache = File(
      'lib/services/offline_calculator_cache_service.dart',
    ).readAsStringSync();
    prewarm = File(
      'lib/services/calculator_webview_prewarm_service.dart',
    ).readAsStringSync();
  });

  group('calculator performance boot contract V1', () {
    test('new installs render ES + dark before async preferences settle', () {
      expect(provider, contains("String _lang = 'es';"));
      expect(provider, contains('bool _darkMode = true;'));
      expect(provider, contains('bool _offlineMode = false;'));
      expect(provider, contains('true = sem rede, usa só cache local'));
    });

    test(
      'offline readiness is automatic and checks three local-time slots',
      () {
        for (final token in const <String>[
          'offlineReadyByDefault = true',
          'calculator_cache_last_successful_slot_v1',
          'now.hour ~/ 8',
          'DateTime(now.year, now.month, now.day, 8)',
          'DateTime(now.year, now.month, now.day, 16)',
          '_scheduleNextSyncBoundary()',
          'onAppResumed()',
          'SharedPreferences.getInstance()',
        ]) {
          expect(cache, contains(token), reason: token);
        }

        expect(
          mainSource,
          contains('OfflineCalculatorCacheService.instance.onAppResumed();'),
        );
      },
    );

    test('prewarm is a real native WebView load but local-only', () {
      for (final token in const <String>[
        'class CalculatorWebViewPrewarmService',
        'WebViewController()',
        'await controller.loadRequest(Uri.parse(localUrl));',
        'buildLocalUrl(',
        'Duration(milliseconds: 4500)',
        'Duration(seconds: 7)',
      ]) {
        expect(prewarm, contains(token), reason: token);
      }

      expect(prewarm, isNot(contains('loadRequest(Uri.parse(onlineShape))')));
      expect(
        mainSource,
        contains('CalculatorWebViewPrewarmService.instance.prewarm('),
      );
    });

    test('calculator preserves deeplinks, theme and patient bridge', () {
      for (final token in const <String>[
        'widget.initialUrl ??',
        'buildLocalUrl(_webUrl)',
        '_withCalculatorTheme(',
        '_injectTheme()',
        '_injectPatientContext()',
      ]) {
        expect(calculator, contains(token), reason: token);
      }
    });

    test('local-first survives and a real online fallback remains', () {
      expect(calculator, isNot(contains('..loadRequest(Uri.parse(_webUrl));')));

      final hasDirectFallback = calculator.contains(
        '_controller.loadRequest(Uri.parse(_webUrl))',
      );
      final hasCoalescedFallback =
          calculator.contains('localUrl ?? _webUrl') &&
          calculator.contains('_controller.loadRequest(Uri.parse(targetUrl))');
      final hasFileErrorFallback =
          (calculator.contains('file→online fallback') ||
              calculator.contains('file->online fallback') ||
              calculator.contains('fallbackOnline=true')) &&
          calculator.contains('_controller.loadRequest(Uri.parse(_webUrl))');

      expect(
        hasDirectFallback || hasCoalescedFallback || hasFileErrorFallback,
        isTrue,
        reason:
            'local-first must retain at least one executable online fallback path',
      );
    });

    test('scheduler does not mutate clinical or remote control planes', () {
      for (final forbidden in const <String>[
        'FirebaseFirestore',
        'RemoteConfig',
        'AiService',
        'PlantaoPipeline',
        'GuardiaClinicalResponseView',
      ]) {
        expect(cache, isNot(contains(forbidden)), reason: forbidden);
        expect(prewarm, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  });
}
