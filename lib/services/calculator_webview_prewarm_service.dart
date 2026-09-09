import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'offline_calculator_cache_service.dart';

/// MEDCASES_CALCULADORA_PREWARM_CONSUME_EXISTING_SERVICE_V1_B_R0
///
/// Existing single prewarm owner, now consumable by CalculadoraScreen.
/// The visible screen still performs its canonical initial-open navigation on
/// the claimed controller, preserving all route/theme/patient/R6 behavior.
class CalculatorWebViewPrewarmLease {
  const CalculatorWebViewPrewarmLease({
    required this.controller,
    required this.ready,
    required this.source,
  });

  final WebViewController controller;
  final bool ready;
  final String source;
}

class CalculatorWebViewPrewarmService {
  CalculatorWebViewPrewarmService._();

  static final CalculatorWebViewPrewarmService instance =
      CalculatorWebViewPrewarmService._();

  WebViewController? _warmController;
  bool _warmReady = false;
  bool _running = false;
  int _generation = 0;
  String? _warmLang;
  bool? _warmDark;
  String? _warmSource;

  bool get isWarm => _warmController != null;
  bool get isReady => _warmController != null && _warmReady;

  Future<void> prewarm({String lang = 'es', bool dark = true}) async {
    if (kIsWeb || _running || _warmController != null) return;

    final generation = ++_generation;
    _running = true;

    try {
      // MainShell already invokes prewarm after the first Flutter frame.
      // 350 ms keeps app boot responsive while removing the old 4.5 s delay.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (generation != _generation) return;

      final theme = dark ? 'dark' : 'light';
      final onlineShape =
          'https://www.medcasescalcu.com?lang=$lang&theme=$theme&_mc_prewarm=1';
      final isIOSPlatform = defaultTargetPlatform == TargetPlatform.iOS;

      // Preserve the current calculator source contract:
      // iOS = online-only; Android = local cache first, online fallback.
      final String? localUrl = isIOSPlatform
          ? null
          : await OfflineCalculatorCacheService.instance
              .buildLocalUrl(onlineShape);
      if (generation != _generation) return;

      final targetUrl = localUrl ?? onlineShape;
      final source = localUrl == null ? 'online' : 'local';

      final PlatformWebViewControllerCreationParams params;
      if (isIOSPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        params = const PlatformWebViewControllerCreationParams();
      }

      late final WebViewController controller;
      controller = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) MedCasesApp/6.1.0',
        )
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (generation != _generation) return;
              if (!identical(_warmController, controller)) return;
              _warmReady = true;
              debugPrint(
                '[CALCULATOR_PREWARM] ready=true source=$source lang=$lang theme=$theme',
              );
            },
            onWebResourceError: (error) {
              if (generation != _generation) return;
              debugPrint(
                '[CALCULATOR_PREWARM] resource_error=true code=${error.errorCode} desc=${error.description}',
              );
            },
          ),
        );

      if (!isIOSPlatform) {
        final platform = controller.platform;
        if (platform is AndroidWebViewController) {
          platform.setAllowFileAccess(true);
        }
      }

      if (generation != _generation) return;

      // Publish before navigation starts. If the user taps during loading, the
      // visible screen claims this exact controller instead of creating another.
      _warmController = controller;
      _warmReady = false;
      _warmLang = lang;
      _warmDark = dark;
      _warmSource = source;

      debugPrint(
        '[CALCULATOR_PREWARM] start=true source=$source lang=$lang theme=$theme',
      );
      await controller.loadRequest(Uri.parse(targetUrl));
    } catch (e) {
      if (generation == _generation) {
        _clearOwnedController();
      }
      debugPrint('[CALCULATOR_PREWARM] error=$e');
    } finally {
      if (generation == _generation) {
        _running = false;
      }
    }
  }

  CalculatorWebViewPrewarmLease? takeWarmController({
    required String lang,
    required bool dark,
  }) {
    if (kIsWeb) return null;

    final controller = _warmController;
    if (controller == null) {
      // Cancel an in-flight delayed prewarm before cold fallback construction.
      invalidate();
      return null;
    }

    if (_warmLang != lang || _warmDark != dark) {
      debugPrint(
        '[CALCULATOR_PREWARM] claim=false reason=signature_mismatch warmLang=$_warmLang requestedLang=$lang warmDark=$_warmDark requestedDark=$dark',
      );
      invalidate();
      return null;
    }

    final lease = CalculatorWebViewPrewarmLease(
      controller: controller,
      ready: _warmReady,
      source: _warmSource ?? 'unknown',
    );

    // Transfer ownership exclusively to CalculadoraScreen.
    _generation += 1;
    _running = false;
    _clearOwnedController();

    debugPrint(
      '[CALCULATOR_PREWARM] claim=true ready=${lease.ready} source=${lease.source}',
    );
    return lease;
  }

  void invalidate() {
    _generation += 1;
    _running = false;
    _clearOwnedController();
  }

  void _clearOwnedController() {
    _warmController = null;
    _warmReady = false;
    _warmLang = null;
    _warmDark = null;
    _warmSource = null;
  }
}
