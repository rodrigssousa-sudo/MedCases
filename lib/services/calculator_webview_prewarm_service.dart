import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'offline_calculator_cache_service.dart';

/// CALCULATOR_PERF_V1
///
/// Warms the native WebView engine and parses the already-cached calculator
/// off the critical UI path. It never downloads the calculator itself and
/// never falls back to an online page; the cache service owns networking.
class CalculatorWebViewPrewarmService {
  CalculatorWebViewPrewarmService._();

  static final CalculatorWebViewPrewarmService instance =
      CalculatorWebViewPrewarmService._();

  WebViewController? _warmController;
  bool _running = false;

  bool get isWarm => _warmController != null;

  Future<void> prewarm({String lang = 'es', bool dark = true}) async {
    if (kIsWeb || _running || _warmController != null) return;

    _running = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 4500));

      for (var attempt = 0; attempt < 4; attempt++) {
        final theme = dark ? 'dark' : 'light';
        final onlineShape =
            'https://www.medcasescalcu.com?lang=$lang&theme=$theme'
            '&_mc_prewarm=1';

        final localUrl = await OfflineCalculatorCacheService.instance
            .buildLocalUrl(onlineShape);

        if (localUrl != null) {
          final controller = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.transparent);

          await controller.loadRequest(Uri.parse(localUrl));

          _warmController = controller;
          debugPrint(
            '[CALCULATOR_PREWARM] ready=true source=local attempt=$attempt',
          );
          return;
        }

        if (attempt < 3) {
          await Future<void>.delayed(const Duration(seconds: 7));
        }
      }

      debugPrint('[CALCULATOR_PREWARM] ready=false reason=no_local_cache');
    } catch (e) {
      debugPrint('[CALCULATOR_PREWARM] error=$e');
    } finally {
      _running = false;
    }
  }

  void invalidate() {
    _warmController = null;
  }
}
