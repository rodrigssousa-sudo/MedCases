import 'dart:async';
import 'dart:convert';

// Build 187: Gray Screen Fix — Web usa HtmlElementView/iframe; iOS/Android mantém WebView nativo.
// dart:io Platform removido — usa kIsWeb para guards de plataforma.
// BUILD 240: OfflineCalculatorCacheService resolve URL local antes de carregar WebView.
// BUILD 283: allowFileAccess + allowFileAccessFromFileURLs via AndroidWebViewController
//            para resolver net::ERR_ACCESS_DENIED ao carregar file:// offline cache.
import 'package:flutter/foundation.dart'
    show ValueNotifier, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../providers/app_provider.dart';
import '../services/offline_calculator_cache_service.dart';
// Conditional import: calcu_web.dart (Web) vs calcu_stub.dart (iOS/Android).
// Em iOS/Android buildCalculadoraWebView() é stub — o WebViewWidget é usado diretamente.
import '../platform/calcu_stub.dart'
    if (dart.library.html) '../platform/calcu_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// URL base — ?lang=pt ou ?lang=es injetado em initState() conforme AppProvider
// ─────────────────────────────────────────────────────────────────────────────
const _kBaseUrl = 'https://www.medcasescalcu.com';

// ─────────────────────────────────────────────────────────────────────────────
// JS PRECOCE — injetado em onPageStarted (antes do DOMContentLoaded)
//
// Injeta <style> ANTES que o Wix tenha chance de aplicar qualquer
// env(safe-area-inset-*) ou configurar momentum scroll.
// ─────────────────────────────────────────────────────────────────────────────
const _kEarlyInjectJs = r"""
(function() {
  if (document.getElementById('mc-early-reset')) return;
  var s = document.createElement('style');
  s.id = 'mc-early-reset';
  s.textContent = [
    'html, body {',
    '  margin: 0 !important;',
    '  padding: 0 !important;',
    '  overscroll-behavior: none !important;',
    '  -webkit-overflow-scrolling: auto !important;',
    '}',
    ':root {',
    '  --sat: 0px !important;',
    '  --sab: 0px !important;',
    '}'
  ].join('');
  (document.head || document.documentElement).appendChild(s);
})();
""";

// ─────────────────────────────────────────────────────────────────────────────
// JS PRINCIPAL — injetado em onPageFinished
//
// REGRAS:
//  • NÃO definir height/min-height no <html> ou <body>.
//  • padding: 0 em tudo — SafeArea(bottom:false)+Expanded entrega frame real.
//  • overscroll-behavior: none — impede bounce de expor ghost space.
//  • NENHUMA injeção de barra/botão de fontes — movida para widget Flutter.
// ─────────────────────────────────────────────────────────────────────────────
const _kInjectJs = r"""
(function() {

  // ── A. Viewport: viewport-fit=cover ──────────────────────────────────────
  var meta = document.querySelector('meta[name="viewport"]');
  if (meta) {
    var c = meta.getAttribute('content') || '';
    if (!c.includes('viewport-fit')) {
      meta.setAttribute('content', c + ', viewport-fit=cover');
    }
  } else {
    var m = document.createElement('meta');
    m.name    = 'viewport';
    m.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
    document.head.appendChild(m);
  }

  // ── B. CSS global — zera insets, bounce e footers Wix ────────────────────
  var styleId = 'mc-global-reset';
  if (!document.getElementById(styleId)) {
    var style = document.createElement('style');
    style.id = styleId;
    style.textContent = [
      'html {',
      '  padding: 0 !important;',
      '  margin:  0 !important;',
      '  overscroll-behavior: none !important;',
      '  -webkit-overflow-scrolling: auto !important;',
      '}',
      'body {',
      '  margin:         0 !important;',
      '  padding:        0 !important;',
      '  padding-top:    0px !important;',
      '  padding-bottom: 0px !important;',
      '  overscroll-behavior-y: none !important;',
      '  -webkit-overflow-scrolling: auto !important;',
      '}',
      '#comp-kbgakxmn,',
      '#comp-kbgakxmn_r_comp-kbgakgyt,',
      '#comp-kbgakxmn_r_comp-mdr13kdg,',
      '#comp-kbgakxmn_r_comp-mdr17w8k,',
      '#SCROLL_TO_BOTTOM,',
      '#SCROLL_TO_TOP,',
      'footer,',
      '.wixui-footer,',
      '[class*="wixui-footer"],',
      '#SITE_FOOTER, #SITE_FOOTER_WRAPPER,',
      '#WIX_ADS, #wix-ads, .wix-ads {',
      '  display:        none    !important;',
      '  height:         0       !important;',
      '  min-height:     0       !important;',
      '  max-height:     0       !important;',
      '  overflow:       hidden  !important;',
      '  visibility:     hidden  !important;',
      '  opacity:        0       !important;',
      '  pointer-events: none    !important;',
      '  margin:         0       !important;',
      '  padding:        0       !important;',
      '}',
      '#PAGES_CONTAINER, #masterPage, #site-root, #SITE_PAGES {',
      '  margin-bottom:  0 !important;',
      '  padding-bottom: 0 !important;',
      '}',
    ].join('\n');
    (document.head || document.documentElement).appendChild(style);
  }

  // ── C. Inline imperativo ─────────────────────────────────────────────────
  document.body.style.setProperty('margin',                     '0',    'important');
  document.body.style.setProperty('padding-top',                '0px',  'important');
  document.body.style.setProperty('padding-bottom',             '0px',  'important');
  document.body.style.setProperty('overscroll-behavior-y',      'none', 'important');
  document.body.style.setProperty('-webkit-overflow-scrolling', 'auto', 'important');
  document.documentElement.style.setProperty('overscroll-behavior',        'none', 'important');
  document.documentElement.style.setProperty('-webkit-overflow-scrolling', 'auto', 'important');
  document.documentElement.style.removeProperty('height');
  document.body.style.removeProperty('height');
  document.body.style.removeProperty('min-height');
  document.body.style.removeProperty('max-height');
  document.body.style.removeProperty('overflow-y');

  // ── D. Kill imperativo do footer ─────────────────────────────────────────
  var KILL_IDS = [
    'comp-kbgakxmn', 'comp-kbgakxmn_r_comp-kbgakgyt',
    'SCROLL_TO_BOTTOM', 'SCROLL_TO_TOP',
    'SITE_FOOTER', 'SITE_FOOTER_WRAPPER', 'WIX_ADS', 'wix-ads',
  ];
  function killFooter() {
    KILL_IDS.forEach(function(id) {
      var el = document.getElementById(id);
      if (el) {
        el.style.setProperty('display',  'none',   'important');
        el.style.setProperty('height',   '0',      'important');
        el.style.setProperty('overflow', 'hidden', 'important');
        el.style.setProperty('margin',   '0',      'important');
        el.style.setProperty('padding',  '0',      'important');
      }
    });
    document.querySelectorAll('footer, .wixui-footer').forEach(function(el) {
      el.style.setProperty('display', 'none', 'important');
      el.style.setProperty('height',  '0',    'important');
    });
  }
  killFooter();

  // ── E. MutationObserver — re-aplica no SPA Wix ──────────────────────────
  var _obs = new MutationObserver(function(mutations) {
    if (mutations.some(function(m) { return m.addedNodes.length > 0; })) {
      killFooter();
    }
  });
  _obs.observe(document.documentElement, { childList: true, subtree: true });
  setTimeout(function() { _obs.disconnect(); killFooter(); }, 10000);

})();
""";

// ─────────────────────────────────────────────────────────────────────────────
// TELA DE CALCULADORA
// ─────────────────────────────────────────────────────────────────────────────
class CalculadoraScreen extends StatefulWidget {
  // Build 189: parâmetro opcional — quando fornecido (via ExternalToolButton),
  // abre diretamente na URL específica (tab, q, drug1/drug2 pré-preenchidos).
  // Quando null, comportamento padrão: homepage da calculadora com lang do provider.
  final String? initialUrl;

  const CalculadoraScreen({super.key, this.initialUrl});

  // MEDCASES_OFFLINE_MINIMAL_CACHE_REFRESH_V1_R2
  static final ValueNotifier<int> cacheRefreshGeneration =
      ValueNotifier<int>(0);
  static int _webViewCacheClearedGeneration = 0;

  static void requestCacheRefresh() {
    cacheRefreshGeneration.value += 1;
  }

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  // Native WebView controller — inicializado apenas em iOS/Android (!kIsWeb)
  late final WebViewController _controller;
  // Fix#6: dark mode agora mutável — reativo a toggleDarkMode() em runtime
  bool _dark = false;
  // Fix#6: flag que indica se a WebView já terminou de carregar (page finished)
  bool _webviewReady = false;
  // Build 187: URL da calculadora — compartilhada entre Web (iframe) e native (WebView)
  // Build 189: pode ser sobrescrita por initialUrl (ExternalToolButton deep link)
  late String _webUrl;

  // MEDCASES_PATIENT_CONTEXT_SESSION_BRIDGE_V1_B_R0_R1
  // Snapshot efêmero por abertura da calculadora.
  // Nunca envia patientId, nome, prontuário, e-mail ou medicações.
  late final Map<String, String> _calculatorPatientPayload;
  bool _calculatorExitInProgress = false;

  String _normalizeCalculatorSex(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == 'f' || v.startsWith('fem')) return 'F';
    if (v == 'm' || v.startsWith('mas')) return 'M';
    return '';
  }

  bool _hasAnyQueryAlias(
    Map<String, String> params,
    List<String> aliases,
  ) {
    return aliases.any(
      (key) => (params[key] ?? '').trim().isNotEmpty,
    );
  }

  String _withPatientContext(
    String rawUrl,
    AppProvider provider,
  ) {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null) return rawUrl;

    final params = <String, String>{...parsed.queryParameters};
    final patient = provider.patient;

    void addIfMissing(
      String canonical,
      List<String> aliases,
      String rawValue,
    ) {
      final value = rawValue.trim();
      if (value.isEmpty) return;
      if (_hasAnyQueryAlias(params, aliases)) return;
      params[canonical] = value;
    }

    // Precedência absoluta: payload explícito do deeplink > AppProvider.
    addIfMissing('idade', const ['idade', 'age', 'edad'], patient.age);
    addIfMissing('peso', const ['peso', 'weight'], patient.weight);
    addIfMissing('altura', const ['altura', 'height'], patient.height);
    addIfMissing(
      'creatinina',
      const ['creatinina', 'creatinine', 'cr'],
      patient.creatinine,
    );

    final calculatedClcr = provider.clcr ?? '';
    addIfMissing('clcr', const ['clcr', 'clearance'], calculatedClcr);

    final hasBasePatient = patient.age.trim().isNotEmpty ||
        patient.weight.trim().isNotEmpty ||
        patient.height.trim().isNotEmpty ||
        patient.creatinine.trim().isNotEmpty ||
        calculatedClcr.trim().isNotEmpty;

    // Evita enviar o sexo default do provider quando não há paciente clínico.
    if (hasBasePatient &&
        !_hasAnyQueryAlias(params, const ['sexo', 'sex', 'gender'])) {
      final sex = _normalizeCalculatorSex(patient.sex);
      if (sex.isNotEmpty) params['sexo'] = sex;
    }

    return parsed.replace(queryParameters: params).toString();
  }

  Map<String, String> _patientPayloadFromUrl(String rawUrl) {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null) return <String, String>{};

    const aliases = <String, String>{
      'age': 'idade',
      'edad': 'idade',
      'sex': 'sexo',
      'gender': 'sexo',
      'weight': 'peso',
      'height': 'altura',
      'cr': 'creatinina',
      'creatinine': 'creatinina',
      'egfr': 'tfg',
      'gestante': 'pregnant',
      'embarazo': 'pregnant',
      'hemodialise': 'hemodialysis',
      'dialysis': 'hemodialysis',
    };

    const accepted = <String>{
      'lang', 'idioma', 'modulo',
      'peso', 'altura', 'idade', 'creatinina', 'clcr', 'sexo',
      'tfg', 'pregnant', 'hemodialysis',
      'ph', 'pco2', 'hco3', 'be', 'na', 'cl', 'gluc', 'ca', 'bun', 'alb',
      'pas', 'col', 'qt', 'fc',
      'bili', 'inr', 'ast', 'alt', 'plat',
      'k', 'mg', 'kdigo', 'child_pugh', 'chads_vasc', 'has_bled', 'ascvd',
    };

    final payload = <String, String>{};
    for (final entry in parsed.queryParameters.entries) {
      final canonical = aliases[entry.key] ?? entry.key;
      final value = entry.value.trim();
      if (accepted.contains(canonical) && value.isNotEmpty) {
        payload.putIfAbsent(canonical, () => value);
      }
    }
    return payload;
  }


  // MEDCASES_CALCULATOR_THEME_SYNC_V2_B_R0
  String _withCalculatorTheme(String rawUrl, String theme) {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null) return rawUrl;
    final params = <String, String>{
      ...parsed.queryParameters,
      'theme': theme,
    };
    return parsed.replace(queryParameters: params).toString();
  }

  // MEDCASES_OFFLINE_MINIMAL_CACHE_REFRESH_V1_R2
  String _withCacheRefreshToken(String rawUrl, int generation) {
    if (generation <= 0) return rawUrl;
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null) return rawUrl;
    final params = <String, String>{
      ...parsed.queryParameters,
      '_mc_refresh': generation.toString(),
    };
    return parsed.replace(queryParameters: params).toString();
  }

  Future<void> _clearNativeWebViewCacheIfNeeded(int generation) async {
    if (kIsWeb ||
        generation <= CalculadoraScreen._webViewCacheClearedGeneration) {
      return;
    }
    await _controller.clearCache();
    CalculadoraScreen._webViewCacheClearedGeneration = generation;
  }

  // MEDCASES_FARMACOS_WEBVIEW_CACHE_FIRST_SINGLE_NAV_IOS_READ_ACCESS_V1_B_R0
  //
  // One tap = one navigation:
  //   cache ready -> local immediately
  //   cache absent -> online immediately
  //
  // iOS WKWebView must load the local file with an explicit read-access
  // directory so sibling css/js/data files can be read by the page.
  Future<void> _loadCalculatorTarget(
    String targetUrl, {
    required String reason,
  }) async {
    final targetUri = Uri.tryParse(targetUrl);

    if (!kIsWeb &&
        _detectIOS() &&
        targetUri != null &&
        targetUri.scheme == 'file') {
      final platform = _controller.platform;

      if (platform is WebKitWebViewController) {
        final fileOnlyUri = targetUri.replace(
          query: null,
          fragment: null,
        );
        final localPath = fileOnlyUri.toFilePath();
        final slash = localPath.lastIndexOf('/');
        final readAccessPath =
            slash > 0 ? localPath.substring(0, slash) : localPath;

        debugPrint(
          '[CalculadoraWebView][CACHE_FIRST] '
          'source=local platform=ios reason=$reason '
          'readAccessPath=$readAccessPath '
          'absoluteFilePath=$localPath '
          'routeQuery=${targetUri.query}',
        );

        await platform.loadFileWithParams(
          WebKitLoadFileParams(
            absoluteFilePath: localPath,
            readAccessPath: readAccessPath,
          ),
        );
        return;
      }
    }

    debugPrint(
      '[CalculadoraWebView][CACHE_FIRST] '
      'source=${targetUri?.scheme == "file" ? "local" : "online"} '
      'platform=${_detectIOS() ? "ios" : "android"} '
      'reason=$reason url=$targetUrl',
    );

    await _controller.loadRequest(Uri.parse(targetUrl));
  }

  // MEDCASES_FARMACOS_WEBVIEW_CACHE_FIRST_SINGLE_NAV_IOS_READ_ACCESS_V1_B_R1
  Future<void> _restoreLocalRouteFromWebUrl() async {
    if (kIsWeb || !_detectIOS()) return;

    final currentUrl = await _controller.currentUrl();
    final currentUri = Uri.tryParse(currentUrl ?? '');
    if (currentUri == null || currentUri.scheme != 'file') return;

    final sourceUri = Uri.tryParse(_webUrl);
    if (sourceUri == null || sourceUri.queryParameters.isEmpty) return;

    final params = sourceUri.queryParameters;
    final routePayload = <String, String>{
      if ((params['lang'] ?? '').isNotEmpty) 'lang': params['lang']!,
      if ((params['tab'] ?? '').isNotEmpty) 'tab': params['tab']!,
      if ((params['q'] ?? '').isNotEmpty) 'q': params['q']!,
      if ((params['drug1'] ?? '').isNotEmpty) 'drug1': params['drug1']!,
      if ((params['drug2'] ?? '').isNotEmpty) 'drug2': params['drug2']!,
      if ((params['modulo'] ?? '').isNotEmpty) 'modulo': params['modulo']!,
    };

    final routeJson = jsonEncode(routePayload);
    final queryJson = jsonEncode(sourceUri.query);

    debugPrint(
      '[CalculadoraWebView][CACHE_FIRST] '
      'restoreLocalRoute=true query=${sourceUri.query}',
    );

    try {
      await _controller.runJavaScript(
        r"""
(function(payload, queryString) {
  try {
    if (queryString) {
      var nextUrl =
        window.location.pathname +
        '?' +
        queryString +
        (window.location.hash || '');

      if (window.location.search !== '?' + queryString) {
        history.replaceState(null, '', nextUrl);
      }
    }

    var attempts = 0;

    function applyRoute() {
      var routed = false;

      if (payload.lang &&
          window.MedCasesRouter &&
          typeof window.MedCasesRouter.setLang === 'function') {
        window.MedCasesRouter.setLang(payload.lang);
      }

      if (payload.tab &&
          window.MedCasesRouter &&
          typeof window.MedCasesRouter.go === 'function') {
        window.MedCasesRouter.go(payload.tab, {
          lang: payload.lang || '',
          q: payload.q || '',
          drug1: payload.drug1 || '',
          drug2: payload.drug2 || ''
        });
        routed = true;
      }

      if (payload.modulo &&
          window.ClinicalSupportRouter &&
          typeof window.ClinicalSupportRouter.open === 'function') {
        window.ClinicalSupportRouter.open(payload.modulo);
        routed = true;
      }

      if (routed || attempts >= 30) return;
      attempts += 1;
      setTimeout(applyRoute, 50);
    }

    applyRoute();
  } catch (e) {
    console.warn('[FlutterCacheFirstRoute] restore failed', e);
  }
})(ROUTE_PAYLOAD_JSON, ROUTE_QUERY_JSON);
"""
            .replaceFirst('ROUTE_PAYLOAD_JSON', routeJson)
            .replaceFirst('ROUTE_QUERY_JSON', queryJson),
      );
    } catch (e) {
      debugPrint(
        '[CalculadoraWebView][CACHE_FIRST] '
        'restoreLocalRouteError=$e',
      );
    }
  }

  Future<void> _loadPreferredCalculatorSource({
    required String reason,
  }) async {
    if (!mounted) return;

    try {
      // MEDCASES_IOS_CALCULADORA_GLOBAL_TABS_ONLINE_ONLY_COUNTERFACTUAL_V1_B_R0
      // Causal proof only: on native iOS, bypass the app-managed file://
      // calculator cache without deleting or mutating that offline cache.
      final bypassLocalCalculatorCacheForIOS = !kIsWeb && _detectIOS();
      final String? localUrl = bypassLocalCalculatorCacheForIOS
          ? null
          : await OfflineCalculatorCacheService.instance.buildLocalUrl(_webUrl);

      debugPrint(
        '[CalculadoraWebView][GLOBAL_TABS_COUNTERFACTUAL] '
        'reason=$reason '
        'platform=${_detectIOS() ? "ios" : "other"} '
        'bypassLocal=$bypassLocalCalculatorCacheForIOS '
        'selected=${localUrl == null ? "online" : "local"}',
      );

      if (!mounted) return;

      final targetUrl = localUrl ?? _webUrl;
      _webviewReady = false;

      await _loadCalculatorTarget(
        targetUrl,
        reason: reason,
      );
    } catch (e) {
      debugPrint(
        '[CalculadoraWebView][CACHE_FIRST] '
        'resolveFailed=true reason=$reason error=$e fallback=$_webUrl',
      );

      if (!mounted) return;

      _webviewReady = false;

      await _loadCalculatorTarget(
        _webUrl,
        reason: '$reason-online-fallback',
      );
    }
  }

  void _onCalculatorCacheRefreshRequested() {
    if (!mounted) return;
    unawaited(_reloadAfterExternalCacheRefresh());
  }

  Future<void> _reloadAfterExternalCacheRefresh() async {
    if (!mounted) return;
    final generation = CalculadoraScreen.cacheRefreshGeneration.value;

    if (kIsWeb) {
      final refreshed = _withCacheRefreshToken(_webUrl, generation);
      if (!mounted) return;
      setState(() => _webUrl = refreshed);
      return;
    }

    try {
      await _clearNativeWebViewCacheIfNeeded(generation);

      // MEDCASES_IOS_CALCULADORA_GLOBAL_TABS_ONLINE_ONLY_COUNTERFACTUAL_V1_B_R0
      // Keep the counterfactual valid even if an external calculator refresh
      // occurs during the same physical iOS test session.
      final bypassLocalCalculatorCacheForIOS = !kIsWeb && _detectIOS();
      final String? localUrl = bypassLocalCalculatorCacheForIOS
          ? null
          : await OfflineCalculatorCacheService.instance.buildLocalUrl(_webUrl);

      debugPrint(
        '[CalculadoraWebView][GLOBAL_TABS_COUNTERFACTUAL] '
        'reason=cache-refresh '
        'platform=${_detectIOS() ? "ios" : "other"} '
        'bypassLocal=$bypassLocalCalculatorCacheForIOS '
        'selected=${localUrl == null ? "online" : "local"}',
      );

      final targetUrl =
          _withCacheRefreshToken(localUrl ?? _webUrl, generation);
      if (!mounted) return;
      _webviewReady = false;
      await _loadCalculatorTarget(
        targetUrl,
        reason: 'cache-refresh',
      );
    } catch (e) {
      debugPrint('[CalculadoraScreen][cache-refresh] reload error: $e');
      if (!mounted) return;
      final fallback = _withCacheRefreshToken(_webUrl, generation);
      _webviewReady = false;
      await _loadCalculatorTarget(
        fallback,
        reason: 'cache-refresh-online-fallback',
      );
    }
  }


  @override
  void initState() {
    super.initState();

    final p         = context.read<AppProvider>();
    final lang      = p.lang;
    final langParam = lang == 'es' ? 'es' : 'pt';
    _dark           = p.darkMode;
    // Build 189: initialUrl tem prioridade sobre URL padrão do provider.
    // ExternalToolLinkEngine já injeta lang+tab+q — não sobrescrever.
    final themeParam = _dark ? 'dark' : 'light';
    final initialWebUrl = _withCalculatorTheme(
      widget.initialUrl ?? '$_kBaseUrl?lang=$langParam',
      themeParam,
    );
    _webUrl = _withCacheRefreshToken(
      initialWebUrl,
      CalculadoraScreen.cacheRefreshGeneration.value,
    );
    _webUrl = _withPatientContext(_webUrl, p);
    _calculatorPatientPayload = _patientPayloadFromUrl(_webUrl);

    // Fix#6: escuta mudanças de tema do AppProvider — injeta tema na WebView
    // imediatamente após toggle, sem necessidade de recarregar a página.
    p.addListener(_onProviderChanged);
    CalculadoraScreen.cacheRefreshGeneration
        .addListener(_onCalculatorCacheRefreshRequested);

    // Build 187: Web não tem suporte a WebViewWidget — usa iframe (calcu_web.dart).
    // iOS/Android continuam com WebViewController nativo.
    if (!kIsWeb) {
      // ignore: avoid_web_libraries_in_flutter — guard kIsWeb garante que este
      // bloco nunca compila para Web; dart:io Platform OK aqui.
      final bool isIOSPlatform = _detectIOS();
      final PlatformWebViewControllerCreationParams params;
      if (isIOSPlatform) {
        // ── iOS (WKWebView) ───────────────────────────────────────────────
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        // ── Android (WebView) — params base (file access configurado abaixo) ──
        params = const PlatformWebViewControllerCreationParams();
      }

      _controller = WebViewController.fromPlatformCreationParams(params)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(
            'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) MedCasesApp/6.1.0')
        // Colors.transparent → scrollView.backgroundColor = UIColor.clear
        // Scaffold.backgroundColor(0xFF0F091E) aparece atrás, sem layer sólido.
        ..setBackgroundColor(Colors.transparent)
        // MEDCASES_IOS_CALCULADORA_WKWEBVIEW_DOM_PROJECTION_DIAGNOSTIC_V1_B_R2
        ..addJavaScriptChannel(
          'MCCalcDiag',
          onMessageReceived: (message) {
            debugPrint(
              '[CalculadoraWebView][WK_DOM_DIAG] ${message.message}',
            );
          },
        )
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) async {
            // MEDCASES_IOS_CALCULADORA_GLOBAL_TABS_FLUTTER_INJECTION_BYPASS_COUNTERFACTUAL_V1_B_R0
            // Causal proof only: production page runs without Flutter-injected
            // CSS/JS on iOS. Non-iOS behavior remains unchanged.
            final bypassFlutterPageInjectionForIOS = !kIsWeb && _detectIOS();

            if (bypassFlutterPageInjectionForIOS) {
              debugPrint(
                '[CalculadoraWebView][GLOBAL_TABS_INJECTION_COUNTERFACTUAL] '
                'phase=page-started platform=ios bypass=true',
              );
            } else {
              await _controller.runJavaScript(_kEarlyInjectJs);
            }
          },
          onPageFinished: (_) async {
            final bypassFlutterPageInjectionForIOS = !kIsWeb && _detectIOS();

            if (bypassFlutterPageInjectionForIOS) {
              _webviewReady = true;
              debugPrint(
                '[CalculadoraWebView][GLOBAL_TABS_INJECTION_COUNTERFACTUAL] '
                'phase=page-finished platform=ios bypass=true '
                'skipped=main-reset,route-replay,theme,patient,deeplink,farmacos-guard',
              );

              // MEDCASES_IOS_CALCULADORA_FALSE_KEYBOARD_OPEN_PROJECTION_COUNTERFACTUAL_V1_B_R0
              // Causal proof for embedded iOS WKWebView false keyboard state.
              await _controller.runJavaScript(r'''
(function () {
  'use strict';
  if (window.__MC_FALSE_KEYBOARD_OPEN_CF_BOUND) return;
  window.__MC_FALSE_KEYBOARD_OPEN_CF_BOUND = true;

  function editable(el) {
    if (!el) return false;
    var tag = String(el.tagName || '').toUpperCase();
    return tag === 'INPUT' || tag === 'TEXTAREA' ||
           tag === 'SELECT' || el.isContentEditable === true;
  }

  function viewportNotShrunk() {
    if (!window.visualViewport) return true;
    return Math.abs(window.visualViewport.height - window.innerHeight) < 2;
  }

  function normalizeFalseKeyboard(reason) {
    var body = document.body;
    if (!body || !body.classList.contains('keyboard-open')) return;
    if (editable(document.activeElement)) return;
    if (!viewportNotShrunk()) return;

    try {
      if (window._mobileKeyboard &&
          typeof window._mobileKeyboard.forceClose === 'function') {
        window._mobileKeyboard.forceClose();
      }
    } catch (_) {}

    body.classList.remove('keyboard-open');
    var sc = document.getElementById('scroll-content');
    if (sc) sc.style.removeProperty('padding-bottom');
    document.documentElement.style.removeProperty('--keyboard-safe-bottom');

    try {
      MCCalcDiag.postMessage(JSON.stringify({
        e:'false-kb-normalized',
        r:reason,
        vv:window.visualViewport ? window.visualViewport.height : null,
        ih:window.innerHeight,
        ae:document.activeElement ? document.activeElement.tagName : null
      }));
    } catch (_) {}
  }

  var observer = new MutationObserver(function () {
    normalizeFalseKeyboard('body-class-mutation');
  });
  if (document.body) {
    observer.observe(document.body, {attributes:true, attributeFilter:['class']});
  }

  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', function () {
      normalizeFalseKeyboard('visual-viewport-resize');
    }, {passive:true});
    window.visualViewport.addEventListener('scroll', function () {
      normalizeFalseKeyboard('visual-viewport-scroll');
    }, {passive:true});
  }

  document.addEventListener('click', function () {
    setTimeout(function () { normalizeFalseKeyboard('post-click'); }, 0);
    setTimeout(function () { normalizeFalseKeyboard('post-click-120'); }, 120);
    setTimeout(function () { normalizeFalseKeyboard('post-click-400'); }, 400);
  }, false);

  normalizeFalseKeyboard('install');
})();
''');

              debugPrint(
                '[CalculadoraWebView][FALSE_KEYBOARD_COUNTERFACTUAL] '
                'installed=true platform=ios',
              );

              // MEDCASES_IOS_FARMACOS_TOPBARLESS_SWIPE_DOWN_CLOSE_PHYSICAL_V1_B_R0
              await _controller.runJavaScript(r'''
(function () {
  'use strict';
  if (window.__MC_FARMACOS_TOPBARLESS_SWIPE_BOUND) return;
  window.__MC_FARMACOS_TOPBARLESS_SWIPE_BOUND = true;

  var STYLE_ID='mc-farmacos-topbarless-swipe-style-v1';
  var ACTIVE='mc-farmacos-topbarless-active';

  function ensureStyle(){
    if(document.getElementById(STYLE_ID))return;
    var st=document.createElement('style');
    st.id=STYLE_ID;
    st.textContent=`
      body.${ACTIVE} #calculator-overlay-header{
        display:none!important;
        visibility:hidden!important;
        height:0!important;
        min-height:0!important;
        max-height:0!important;
        padding:0!important;
        margin:0!important;
        border:0!important;
        overflow:hidden!important;
        pointer-events:none!important;
      }
      body.${ACTIVE} #hub-card-farmacos.mc-overlay-projected-card{
        top:0!important;
        height:100dvh!important;
        min-height:100dvh!important;
        max-height:100dvh!important;
      }
      body.${ACTIVE} #hub-card-farmacos.mc-overlay-projected-card > .hub-card-body{
        top:0!important;
        max-height:100dvh!important;
      }
      body.${ACTIVE} #fd-modal.open > .fd-header{
        display:none!important;
        visibility:hidden!important;
        height:0!important;
        min-height:0!important;
        max-height:0!important;
        padding:0!important;
        margin:0!important;
        border:0!important;
        overflow:hidden!important;
        pointer-events:none!important;
      }
    `;
    document.head.appendChild(st);
  }

  function farmCard(){
    return document.getElementById('hub-card-farmacos');
  }
  function detail(){
    return document.getElementById('fd-modal');
  }
  function farmProjected(){
    var c=farmCard();
    return !!(c && c.classList.contains('mc-overlay-projected-card') &&
      c.classList.contains('is-open'));
  }
  function detailOpen(){
    var d=detail();
    return !!(d && d.classList.contains('open'));
  }
  function reconcile(){
    ensureStyle();
    var active=farmProjected() || detailOpen();
    if(document.body){
      document.body.classList.toggle(ACTIVE,active);
    }
  }

  function editable(el){
    if(!el)return false;
    var t=String(el.tagName||'').toUpperCase();
    return t==='INPUT'||t==='TEXTAREA'||t==='SELECT'||el.isContentEditable===true;
  }

  function scrollTopFor(mode){
    var nodes=mode==='detail'
      ? [
          document.getElementById('fd-body'),
          document.querySelector('#fd-modal.open .fd-body'),
          document.querySelector('#fd-modal.open [data-fd-scroll]')
        ]
      : [
          document.getElementById('hub-body-farmacos'),
          document.getElementById('scroll-content'),
          farmCard()
        ];
    var top=0;
    for(var i=0;i<nodes.length;i++){
      var n=nodes[i];
      if(!n)continue;
      top=Math.max(top,Number(n.scrollTop||0));
    }
    return top;
  }

  function closeDetail(){
    var d=detail();
    if(!d)return false;
    var btn=d.querySelector('.fd-close,#fd-close,[data-fd-close],button[aria-label*=Fechar],button[aria-label*=Cerrar],button[aria-label*=Close]');
    if(btn && typeof btn.click==='function'){btn.click();return true;}
    return false;
  }

  function closeFarmacos(){
    var btn=document.getElementById('calculator-overlay-close');
    if(btn && typeof btn.click==='function'){btn.click();return true;}
    if(window.__MC_OVERLAY_PROJECTION_V1 &&
       typeof window.__MC_OVERLAY_PROJECTION_V1.close==='function'){
      window.__MC_OVERLAY_PROJECTION_V1.close();
      return true;
    }
    return false;
  }

  var gesture=null;
  document.addEventListener('touchstart',function(e){
    if(!e.touches || e.touches.length!==1)return;
    var mode=farmProjected() && !detailOpen() ? 'farmacos' : null;
    if(!mode)return;
    if(editable(e.target) || editable(document.activeElement))return;
    if(scrollTopFor(mode)>2)return;
    var t=e.touches[0];
    gesture={mode:mode,x:t.clientX,y:t.clientY,lastX:t.clientX,lastY:t.clientY,ts:Date.now()};
  },{passive:true});

  document.addEventListener('touchmove',function(e){
    if(!gesture || !e.touches || e.touches.length!==1)return;
    var t=e.touches[0];
    gesture.lastX=t.clientX;
    gesture.lastY=t.clientY;
  },{passive:true});

  document.addEventListener('touchend',function(){
    if(!gesture)return;
    var g=gesture; gesture=null;
    var dy=g.lastY-g.y;
    var dx=Math.abs(g.lastX-g.x);
    var dt=Date.now()-g.ts;
    var minDy=Math.max(180,Math.min(220,window.innerHeight*0.24));
    if(dy<minDy || dx>dy*0.55 || dt<320 || dt>2200)return;
    if(scrollTopFor(g.mode)>2)return;
    var mode=g.mode;
    setTimeout(function(){
      var closed=mode==='detail'?closeDetail():closeFarmacos();
      try{
        MCCalcDiag.postMessage(JSON.stringify({
          e:'farmacos-swipe-close-natural',mode:mode,dy:Math.round(dy),dt:dt,closed:closed
        }));
      }catch(_){}
      setTimeout(reconcile,0);
      setTimeout(reconcile,180);
    },220);
  },{passive:true});

  document.addEventListener('touchcancel',function(){gesture=null;},{passive:true});
  document.addEventListener('click',function(){
    setTimeout(reconcile,0);
    setTimeout(reconcile,160);
  },false);

  var mo=new MutationObserver(function(){reconcile();});
  var c=farmCard(); if(c)mo.observe(c,{attributes:true,attributeFilter:['class']});
  var d=detail(); if(d)mo.observe(d,{attributes:true,attributeFilter:['class']});

  ensureStyle();
  reconcile();
})();
''');

              debugPrint(
                '[CalculadoraWebView][FARMACOS_TOPBARLESS_SWIPE] '
                'installed=true platform=ios',
              );

              // MEDCASES_IOS_FARMACOS_REAL_KEYBOARD_SAFE_VIEWPORT_V1_B_R0
              await _controller.runJavaScript(r'''
(function () {
  'use strict';
  if (window.__MC_FARMACOS_REAL_KEYBOARD_SAFE_BOUND) return;
  window.__MC_FARMACOS_REAL_KEYBOARD_SAFE_BOUND = true;

  var ACTIVE='mc-farmacos-topbarless-active';
  var STYLE_ID='mc-farmacos-real-keyboard-safe-v1';
  var closedVV = window.visualViewport ? window.visualViewport.height : window.innerHeight;
  var originalScrollIntoView = Element.prototype.scrollIntoView;

  function editable(el){
    if(!el)return false;
    var t=String(el.tagName||'').toUpperCase();
    return t==='INPUT'||t==='TEXTAREA'||t==='SELECT'||el.isContentEditable===true;
  }

  function farmActive(){
    return !!(document.body && document.body.classList.contains(ACTIVE));
  }

  function insideFarmacos(el){
    if(!el || !el.closest)return false;
    return !!(el.closest('#hub-card-farmacos') || el.closest('#fd-modal'));
  }

  function isFarmSearch(el){
    if(!el)return false;
    return el.id==='hm-drug-search' ||
           el.id==='farmacos-search-input' ||
           !!(el.matches && el.matches('[data-farmacos-v2-search-wrapper] input'));
  }

  function ensureStyle(){
    if(document.getElementById(STYLE_ID))return;
    var st=document.createElement('style');
    st.id=STYLE_ID;
    st.textContent=`
      body.${ACTIVE}.keyboard-open #hub-card-farmacos.mc-overlay-projected-card{
        height:var(--mc-farmacos-visible-vh,100dvh)!important;
        min-height:var(--mc-farmacos-visible-vh,100dvh)!important;
        max-height:var(--mc-farmacos-visible-vh,100dvh)!important;
        overflow:hidden!important;
      }
      body.${ACTIVE}.keyboard-open #hub-card-farmacos.mc-overlay-projected-card > #hub-body-farmacos{
        height:var(--mc-farmacos-visible-vh,100dvh)!important;
        min-height:0!important;
        max-height:var(--mc-farmacos-visible-vh,100dvh)!important;
        overflow-y:auto!important;
        overflow-x:hidden!important;
        -webkit-overflow-scrolling:touch!important;
        padding-bottom:calc(16px + env(safe-area-inset-bottom,0px))!important;
        box-sizing:border-box!important;
      }
    `;
    document.head.appendChild(st);
  }

  Element.prototype.scrollIntoView=function(){
    if(farmActive() && editable(this) && insideFarmacos(this) && !isFarmSearch(this)){
      try{
        if(window.MCCalcDiag){
          MCCalcDiag.postMessage(JSON.stringify({e:'farmacos-scrollintoview-blocked',id:this.id||null}));
        }
      }catch(_){}
      return;
    }
    return originalScrollIntoView.apply(this,arguments);
  };

  function setClosedBaseline(){
    if(!window.visualViewport)return;
    var ae=document.activeElement;
    if(editable(ae) && insideFarmacos(ae))return;
    var h=window.visualViewport.height;
    if(h>closedVV)closedVV=h;
  }

  function correct(reason){
    ensureStyle();
    if(!farmActive())return;
    var ae=document.activeElement;
    if(isFarmSearch(ae)){
      try{if(document.body)document.body.classList.remove('keyboard-open')}catch(_){}
      document.documentElement.style.removeProperty('--mc-farmacos-visible-vh');
      document.documentElement.style.removeProperty('--keyboard-safe-bottom');
      return;
    }

    if(!editable(ae) || !insideFarmacos(ae)){
      setClosedBaseline();
      document.documentElement.style.removeProperty('--mc-farmacos-visible-vh');
      return;
    }

    var vv=window.visualViewport;
    if(!vv)return;
    var visible=Math.max(180,Math.floor(vv.height));
    var shrink=Math.max(0,Math.round(closedVV-vv.height));

    document.documentElement.style.setProperty('--mc-farmacos-visible-vh',visible+'px');
    document.documentElement.style.setProperty('--keyboard-safe-bottom','0px');

    var sc=document.getElementById('scroll-content');
    if(sc)sc.style.paddingBottom='0px';

    if(isFarmSearch(ae)){
      var hb=document.getElementById('hub-body-farmacos');
      if(hb)hb.scrollTop=0;
    }

    try{
      if(window.MCCalcDiag){
        MCCalcDiag.postMessage(JSON.stringify({
          e:'farmacos-real-kb-safe',r:reason,vv:Math.round(vv.height),
          base:Math.round(closedVV),shrink:shrink,id:ae.id||null
        }));
      }
    }catch(_){}
  }

  document.addEventListener('focusin',function(e){
    if(!editable(e.target) || !insideFarmacos(e.target) || isFarmSearch(e.target))return;
    setTimeout(function(){correct('focus-0');},0);
    setTimeout(function(){correct('focus-120');},120);
    setTimeout(function(){correct('focus-320');},320);
    setTimeout(function(){correct('focus-520');},520);
  },true);

  document.addEventListener('focusout',function(){
    setTimeout(function(){
      setClosedBaseline();
      if(!editable(document.activeElement)){
        document.documentElement.style.removeProperty('--mc-farmacos-visible-vh');
      }
    },320);
  },true);

  if(window.visualViewport){
    window.visualViewport.addEventListener('resize',function(){
      setTimeout(function(){correct('vv-resize');},90);
    },{passive:true});
    window.visualViewport.addEventListener('scroll',function(){
      setTimeout(function(){correct('vv-scroll');},40);
    },{passive:true});
  }

  ensureStyle();
  setClosedBaseline();


  /* MEDCASES iOS Fármacos physical correction R1:
     - strong owner for remaining projected/detail topbars
     - collapse hidden-header projection seam to 1px
     - real keyboard follows visualViewport without legacy keyboard-open layout
     - native Flutter topbar is intentionally untouched
  */
  (function(){
    'use strict';
    var CORR_BUILD='MEDCASES_IOS_FARMACOS_TOPBAR_GAP_REAL_KEYBOARD_PHYSICAL_CORRECTION_V1_B_R1';
    if(window.__MC_FARMACOS_TOPBAR_GAP_REAL_KEYBOARD_PHYSICAL_CORRECTION_V1_B_R1)return;
    window.__MC_FARMACOS_TOPBAR_GAP_REAL_KEYBOARD_PHYSICAL_CORRECTION_V1_B_R1=true;

    var ROOT=document.documentElement;
    var BODY=document.body;
    var ACTIVE_CLASS='mc-farmacos-physical-r1-active';
    var STYLE_ID='mc-farmacos-physical-r1-style';
    var timers=[];

    function card(){return document.getElementById('hub-card-farmacos')}
    function detail(){return document.getElementById('fd-modal')}
    function overlay(){return document.getElementById('calculator-overlay-container')}
    function hubBody(){return document.getElementById('hub-body-farmacos')}
    function scrollContent(){return document.getElementById('scroll-content')}

    function farmOpen(){
      var c=card(), d=detail();
      return !!(
        (c&&c.classList.contains('mc-overlay-projected-card')&&c.classList.contains('is-open')) ||
        (d&&d.classList.contains('open'))
      );
    }

    function farmEditable(el){
      if(!el||!el.matches||!el.matches('input,textarea,select,[contenteditable="true"]'))return false;
      try{
        return !!(
          el.closest('#hub-card-farmacos.mc-overlay-projected-card') ||
          el.closest('#fd-modal.open')
        );
      }catch(_){return false}
    }

    function rootSearchFocused(){
      var el=document.activeElement;
      if(!farmEditable(el))return false;
      try{
        return el.id==='hm-drug-search' ||
          el.matches('[data-mc-farm-browser-r6-search-input="true"]') ||
          !!el.closest('[data-mc-farm-browser-r6-search-shell="true"],.hm-search-wrap');
      }catch(_){return false}
    }

    function ensureStyle(){
      if(document.getElementById(STYLE_ID))return;
      var s=document.createElement('style');
      s.id=STYLE_ID;
      s.textContent=[
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #calculator-overlay-container[data-mc-owner="NO_REPARENT_PROJECTION_V1"] #calculator-overlay-header,',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #calculator-overlay-container[data-mc-owner="NO_REPARENT_PROJECTION_V1"].mc-farmacos-app-subpage-active #calculator-overlay-header{',
        'display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;',
        'height:0!important;min-height:0!important;max-height:0!important;padding:0!important;margin:0!important;border:0!important;overflow:hidden!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #fd-modal-overlay #fd-modal.open > .fd-header,',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #fd-modal-overlay #fd-modal.open .fd-header{',
        'display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;',
        'height:0!important;min-height:0!important;max-height:0!important;padding:0!important;margin:0!important;border:0!important;overflow:hidden!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #page-home #hub-card-farmacos.mc-overlay-projected-card{',
        '--mc-overlay-projection-top:calc(var(--mc-farm-r1-vv-top,0px) + 1px)!important;',
        'top:calc(var(--mc-farm-r1-vv-top,0px) + 1px)!important;bottom:auto!important;',
        'height:calc(var(--mc-farm-r1-vv-height,100vh) - 1px)!important;',
        'min-height:0!important;max-height:calc(var(--mc-farm-r1-vv-height,100vh) - 1px)!important;',
        'margin-top:0!important;transform:none!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #page-home #hub-card-farmacos.mc-overlay-projected-card > .hub-card-trigger{',
        'display:none!important;height:0!important;min-height:0!important;max-height:0!important;padding:0!important;margin:0!important;border:0!important;overflow:hidden!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #page-home #hub-card-farmacos.mc-overlay-projected-card > #hub-body-farmacos{',
        'top:0!important;margin-top:0!important;padding-top:0!important;',
        'height:100%!important;min-height:0!important;max-height:100%!important;',
        'overflow-y:auto!important;overflow-x:hidden!important;-webkit-overflow-scrolling:touch!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #page-home #hub-card-farmacos.mc-overlay-projected-card > #hub-body-farmacos > .hub-card-inner{',
        'margin-top:0!important;padding-top:1px!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #page-home #hub-card-farmacos.mc-overlay-projected-card #farmacos-v2-shell{',
        'margin-top:0!important;padding-top:0!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #page-home #hub-card-farmacos.mc-overlay-projected-card [data-mc-farm-browser-r6-search-shell="true"],',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #page-home #hub-card-farmacos.mc-overlay-projected-card .hm-search-wrap{',
        'margin-top:1px!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #fd-modal-overlay #fd-modal.open{',
        'margin-top:0!important;padding-top:0!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.calc-overlay-open #fd-modal-overlay #fd-modal.open #fd-body{',
        'margin-top:0!important;padding-top:1px!important;',
        '}',
        'html body.'+ACTIVE_CLASS+'.keyboard-open #scroll-content{',
        'padding-bottom:0!important;',
        '}'
      ].join('');
      (document.head||ROOT).appendChild(s);
    }

    function setViewportVars(){
      var vv=window.visualViewport;
      var top=vv?Math.max(0,Number(vv.offsetTop)||0):0;
      var h=vv?Number(vv.height)||window.innerHeight:window.innerHeight;
      h=Math.max(120,h||0);
      ROOT.style.setProperty('--mc-farm-r1-vv-top',top+'px');
      ROOT.style.setProperty('--mc-farm-r1-vv-height',h+'px');
      ROOT.style.setProperty('--keyboard-safe-bottom','0px','important');
    }

    function neutralizeLegacyKeyboard(){
      var ae=document.activeElement;
      if(!farmEditable(ae))return;
      try{
        if(BODY.classList.contains('keyboard-open') && window._mobileKeyboard &&
           typeof window._mobileKeyboard.forceClose==='function'){
          window._mobileKeyboard.forceClose();
        }
      }catch(_){}
      BODY.classList.remove('keyboard-open');
      ROOT.style.setProperty('--keyboard-safe-bottom','0px','important');
      var sc=scrollContent();
      if(sc)sc.style.setProperty('padding-bottom','0px','important');
    }

    function resetRootSearchPan(){
      if(!rootSearchFocused())return;
      try{window.scrollTo(0,0)}catch(_){}
      try{ROOT.scrollTop=0}catch(_){}
      try{BODY.scrollTop=0}catch(_){}
      var sc=scrollContent(), hb=hubBody();
      try{if(sc)sc.scrollTop=0}catch(_){}
      try{if(hb)hb.scrollTop=0}catch(_){}
    }

    function apply(){
      if(rootSearchFocused()){
        try{BODY.classList.remove('keyboard-open')}catch(_){}
        ROOT.style.removeProperty('--mc-farm-r1-vv-top');
        ROOT.style.removeProperty('--mc-farm-r1-vv-height');
        ROOT.style.removeProperty('--keyboard-safe-bottom');
        var sc0=scrollContent();
        if(sc0){
          try{sc0.style.removeProperty('padding-bottom')}catch(_){}
        }
        return;
      }
      ensureStyle();
      var open=farmOpen();
      BODY.classList.toggle(ACTIVE_CLASS,open);
      if(!open)return;
      setViewportVars();
      neutralizeLegacyKeyboard();
      resetRootSearchPan();
    }

    function schedule(){
      timers.forEach(function(id){clearTimeout(id)});
      timers=[];

      if(rootSearchFocused()){
        apply();
        return;
      }

      apply();
      [40,100,180,300,500].forEach(function(ms){
        timers.push(setTimeout(apply,ms));
      });
    }

    document.addEventListener('focusin',function(e){
      if(farmEditable(e.target))schedule();
    },true);
    document.addEventListener('focusout',function(e){
      if(farmEditable(e.target))setTimeout(schedule,90);
    },true);

    if(window.visualViewport){
      window.visualViewport.addEventListener('resize',schedule,{passive:true});
      window.visualViewport.addEventListener('scroll',schedule,{passive:true});
    }
    window.addEventListener('resize',schedule,{passive:true});

    [BODY,overlay(),card(),detail()].filter(Boolean).forEach(function(node){
      try{
        new MutationObserver(schedule).observe(node,{attributes:true,attributeFilter:['class','style']});
      }catch(_){}
    });

    schedule();
    console.info('['+CORR_BUILD+'] installed');
  })();
})();
''');

              debugPrint(
                '[CalculadoraWebView][FARMACOS_REAL_KEYBOARD_SAFE] '
                'installed=true platform=ios',
              );

              // MEDCASES_IOS_FARMACOS_DETAIL_TOPBAR_NATURAL_SWIPE_TAP_FLASH_CLOSURE_V1_B_R2
              await _controller.runJavaScript(r'''
(function(){
  'use strict';
  if(window.__MC_FARMACOS_R2_SESSION_BOUND)return;
  window.__MC_FARMACOS_R2_SESSION_BOUND=true;
  // R12-R1: legacy R2 detail owner superseded by canonical MCD R8.
  return;

  var SESSION='mc-farmacos-r2-session';
  var STYLE_ID='mc-farmacos-r2-session-style';
  var farmSession=false;
  var sessionCloseTimer=0;

  function overlay(){ return document.getElementById('calculator-overlay-container'); }
  function header(){ return document.getElementById('calculator-overlay-header'); }
  function card(){ return document.getElementById('hub-card-farmacos'); }
  function detail(){ return document.getElementById('fd-modal'); }
  function projectedRoot(){
    var c=card();
    return !!(c && c.classList.contains('mc-overlay-projected-card') && c.classList.contains('is-open'));
  }
  function overlayOpen(){
    var o=overlay();
    return !!(o && o.classList.contains('is-active'));
  }

  function ensureStyle(){
    if(document.getElementById(STYLE_ID))return;
    var s=document.createElement('style');
    s.id=STYLE_ID;
    s.textContent=`
      html body.${SESSION} #calculator-overlay-container[data-mc-owner="NO_REPARENT_PROJECTION_V1"] #calculator-overlay-header{
        display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;
        position:fixed!important;top:0!important;height:0!important;min-height:0!important;max-height:0!important;
        padding:0!important;margin:0!important;border:0!important;overflow:hidden!important;
      }
      html body.${SESSION} #fd-modal.open > .fd-header,
      html body.${SESSION} #fd-modal.open .fd-header,
      html body.${SESSION} #fd-modal-overlay .fd-header,
      html body.${SESSION} #fd-modal-header,
      html body.${SESSION} [data-fd-header]{
        display:none!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important;
        height:0!important;min-height:0!important;max-height:0!important;padding:0!important;margin:0!important;
        border:0!important;overflow:hidden!important;
      }
      html body.${SESSION} #page-home #hub-card-farmacos.mc-overlay-projected-card{
        top:1px!important;--mc-overlay-projection-top:1px!important;margin-top:0!important;transform:none!important;
      }
      html body.${SESSION} #page-home #hub-card-farmacos.mc-overlay-projected-card > #hub-body-farmacos,
      html body.${SESSION} #page-home #hub-card-farmacos.mc-overlay-projected-card > #hub-body-farmacos > .hub-card-inner,
      html body.${SESSION} #page-home #hub-card-farmacos.mc-overlay-projected-card #farmacos-v2-shell{margin-top:0!important;}
      html body.${SESSION} #page-home #hub-card-farmacos.mc-overlay-projected-card > #hub-body-farmacos > .hub-card-inner{padding-top:1px!important;}
      html body.${SESSION} #fd-modal.open{top:1px!important;margin-top:0!important;padding-top:0!important;}
      html body.${SESSION} #fd-modal.open #fd-body{margin-top:0!important;padding-top:1px!important;}
      html body.${SESSION} #fd-modal,
      html body.${SESSION} #fd-modal *,
      html body.${SESSION} #hub-card-farmacos,
      html body.${SESSION} #hub-card-farmacos *{-webkit-tap-highlight-color:rgba(0,0,0,0)!important;}
    `;
    (document.head||document.documentElement).appendChild(s);
  }

  function hardHideWebTopbars(){
    if(!farmSession)return;
    var nodes=[
      header(),
      document.querySelector('#fd-modal.open > .fd-header'),
      document.querySelector('#fd-modal.open .fd-header'),
      document.getElementById('fd-modal-header'),
      document.querySelector('[data-fd-header]')
    ].filter(Boolean);
    nodes.forEach(function(n){
      try{
        n.style.setProperty('display','none','important');
        n.style.setProperty('visibility','hidden','important');
        n.style.setProperty('opacity','0','important');
        n.style.setProperty('pointer-events','none','important');
        n.style.setProperty('height','0','important');
        n.style.setProperty('min-height','0','important');
        n.style.setProperty('max-height','0','important');
        n.style.setProperty('padding','0','important');
        n.style.setProperty('margin','0','important');
        n.style.setProperty('border','0','important');
        n.style.setProperty('overflow','hidden','important');
      }catch(_){}
    });
  }

  function syncSession(reason){
    ensureStyle();
    if(projectedRoot()){
      farmSession=true;
      if(sessionCloseTimer){clearTimeout(sessionCloseTimer);sessionCloseTimer=0;}
    }
    if(farmSession && !overlayOpen()){
      if(!sessionCloseTimer){
        sessionCloseTimer=setTimeout(function(){
          if(!overlayOpen() && !projectedRoot()){
            farmSession=false;
            if(document.body)document.body.classList.remove(SESSION);
          }
          sessionCloseTimer=0;
        },180);
      }
    } else if(farmSession && sessionCloseTimer){
      clearTimeout(sessionCloseTimer);sessionCloseTimer=0;
    }
    if(document.body)document.body.classList.toggle(SESSION,farmSession);
    if(farmSession){
      hardHideWebTopbars();
      setTimeout(hardHideWebTopbars,0);
      setTimeout(hardHideWebTopbars,80);
      setTimeout(hardHideWebTopbars,180);
      setTimeout(hardHideWebTopbars,360);
    }
  }

  document.addEventListener('click',function(){syncSession('click');},true);
  document.addEventListener('focusin',function(){syncSession('focusin');},true);
  document.addEventListener('focusout',function(){setTimeout(function(){syncSession('focusout');},40);},true);

  [document.body,overlay(),card(),detail()].filter(Boolean).forEach(function(n){
    try{
      new MutationObserver(function(){syncSession('mutation');})
        .observe(n,{attributes:true,childList:true,subtree:false,attributeFilter:['class','style']});
    }catch(_){}
  });

  ensureStyle();
  syncSession('install');
})();
''');

              debugPrint(
                '[CalculadoraWebView][FARMACOS_R2_SESSION] '
                'installed=true platform=ios',
              );

              // MEDCASES_IOS_FARMACOS_FINAL_DETAIL_TOPBAR_SMOOTH_SHEET_V1_B_R3
              await _controller.runJavaScript(r'''
(function() {
  'use strict';
  if (window.__MC_FARMACOS_R3_SMOOTH_BOUND) return;
  window.__MC_FARMACOS_R3_SMOOTH_BOUND = true;
  // R12-R1: legacy R3 fd-modal owner superseded by canonical MCD R8.
  return;

  var ACTIVE = 'mc-farmacos-r3-active';
  var STYLE_ID = 'mc-farmacos-r3-smooth-style';
  var gesture = null;
  var guardRaf = 0;

  function card() {
    return document.getElementById('hub-card-farmacos');
  }

  function detail() {
    return document.getElementById('fd-modal');
  }

  function farmProjected() {
    var c = card();
    return !!(c &&
      c.classList.contains('mc-overlay-projected-card') &&
      c.classList.contains('is-open'));
  }

  function detailOpen() {
    var d = detail();
    return !!(d && d.classList.contains('open'));
  }

  function reconcileActive() {
    var active = farmProjected() || detailOpen();
    if (document.body) document.body.classList.toggle(ACTIVE, active);
    return active;
  }

  function ensureStyle() {
    if (document.getElementById(STYLE_ID)) return;
    var st = document.createElement('style');
    st.id = STYLE_ID;
    st.textContent = `
      @keyframes mcFarmDrugOpenR3 {
        from { opacity:.72; transform:translate3d(0,18px,0); }
        to   { opacity:1; transform:translate3d(0,0,0); }
      }

      html body.${ACTIVE} #calculator-overlay-header,
      html body.${ACTIVE} #calculator-overlay-container #calculator-overlay-header,
      html body.${ACTIVE} #fd-modal.open > .fd-header,
      html body.${ACTIVE} #fd-modal.open .fd-header,
      html body.${ACTIVE} #fd-modal-header,
      html body.${ACTIVE} [data-fd-header] {
        display:none!important;
        visibility:hidden!important;
        opacity:0!important;
        pointer-events:none!important;
        height:0!important;
        min-height:0!important;
        max-height:0!important;
        padding:0!important;
        margin:0!important;
        border:0!important;
        overflow:hidden!important;
      }

      html body.${ACTIVE} #hub-card-farmacos.mc-overlay-projected-card {
        top:1px!important;
        margin-top:0!important;
        --mc-overlay-projection-top:1px!important;
      }

      html body.${ACTIVE} #fd-modal.open {
        top:1px!important;
        margin-top:0!important;
        padding-top:0!important;
        animation:mcFarmDrugOpenR3 280ms cubic-bezier(.22,.72,.22,1) both;
        transform-origin:50% 0%;
        will-change:transform,opacity;
      }

      html body.${ACTIVE} #fd-modal.open #fd-body {
        margin-top:0!important;
        padding-top:1px!important;
      }

      html body.${ACTIVE} #fd-modal,
      html body.${ACTIVE} #fd-modal *,
      html body.${ACTIVE} #hub-card-farmacos,
      html body.${ACTIVE} #hub-card-farmacos * {
        -webkit-tap-highlight-color:rgba(0,0,0,0)!important;
      }
    `;
    (document.head || document.documentElement).appendChild(st);
  }

  function hardHideTopbars() {
    if (!reconcileActive()) return;

    [
      '#calculator-overlay-header',
      '#fd-modal.open > .fd-header',
      '#fd-modal.open .fd-header',
      '#fd-modal-header',
      '[data-fd-header]'
    ].forEach(function(sel) {
      document.querySelectorAll(sel).forEach(function(n) {
        try {
          n.style.setProperty('display','none','important');
          n.style.setProperty('visibility','hidden','important');
          n.style.setProperty('opacity','0','important');
          n.style.setProperty('pointer-events','none','important');
          n.style.setProperty('height','0','important');
          n.style.setProperty('min-height','0','important');
          n.style.setProperty('max-height','0','important');
          n.style.setProperty('padding','0','important');
          n.style.setProperty('margin','0','important');
          n.style.setProperty('border','0','important');
          n.style.setProperty('overflow','hidden','important');
        } catch (_) {}
      });
    });
  }

  function guardLoop() {
    hardHideTopbars();
    if (reconcileActive()) {
      guardRaf = requestAnimationFrame(guardLoop);
    } else {
      guardRaf = 0;
    }
  }

  function ensureGuard() {
    if (!guardRaf && reconcileActive()) {
      guardRaf = requestAnimationFrame(guardLoop);
    }
  }

  function editable(el) {
    if (!el) return false;
    var tag = String(el.tagName || '').toUpperCase();
    return tag === 'INPUT' || tag === 'TEXTAREA' ||
           tag === 'SELECT' || el.isContentEditable === true;
  }

  function detailScrollTop() {
    var top = 0;
    [
      document.getElementById('fd-body'),
      document.querySelector('#fd-modal.open .fd-body'),
      document.querySelector('#fd-modal.open [data-fd-scroll]')
    ].filter(Boolean).forEach(function(n) {
      top = Math.max(top, Number(n.scrollTop || 0));
    });
    return top;
  }

  function resetDetailVisual(d) {
    if (!d) return;
    d.style.removeProperty('transition');
    d.style.removeProperty('transform');
    d.style.removeProperty('opacity');
    d.style.removeProperty('will-change');
  }

  function closeDetail() {
    var d = detail();
    if (!d) return false;

    var btn = d.querySelector(
      '.fd-close,#fd-close,[data-fd-close],' +
      'button[aria-label*=Fechar],button[aria-label*=Cerrar],button[aria-label*=Close]'
    );

    if (btn && typeof btn.click === 'function') {
      btn.click();
      return true;
    }
    return false;
  }

  document.addEventListener('touchstart', function(e) {
    var canonicalMcd = document.getElementById('mc-drug-detail-page-v21');
    if (canonicalMcd && String(canonicalMcd.dataset.open || '') === 'true') return;
    if (!detailOpen()) return;
    if (!e.touches || e.touches.length !== 1) return;
    if (editable(e.target) || editable(document.activeElement)) return;
    if (detailScrollTop() > 2) return;

    var t = e.touches[0];
    gesture = {
      x:t.clientX,
      y:t.clientY,
      lastX:t.clientX,
      lastY:t.clientY,
      ts:Date.now()
    };

    var d = detail();
    if (d) {
      d.style.setProperty('animation','none','important');
      d.style.setProperty('transition','none','important');
      d.style.setProperty('will-change','transform,opacity','important');
    }
  }, {passive:true, capture:true});

  document.addEventListener('touchmove', function(e) {
    if (!gesture || !e.touches || e.touches.length !== 1) return;

    var t = e.touches[0];
    gesture.lastX = t.clientX;
    gesture.lastY = t.clientY;

    var dy = Math.max(0, t.clientY - gesture.y);
    var dx = Math.abs(t.clientX - gesture.x);

    if (dx > Math.max(24, dy * .8)) return;

    var d = detail();
    if (!d) return;

    var tracked = Math.min(dy, window.innerHeight * .46);
    var opacity = Math.max(.80, 1 - tracked / Math.max(1,window.innerHeight) * .38);

    d.style.setProperty(
      'transform',
      'translate3d(0,' + tracked + 'px,0)',
      'important'
    );
    d.style.setProperty('opacity', String(opacity), 'important');
  }, {passive:true, capture:true});

  document.addEventListener('touchend', function() {
    if (!gesture) return;

    var g = gesture;
    gesture = null;

    var dy = Math.max(0, g.lastY - g.y);
    var dx = Math.abs(g.lastX - g.x);
    var dt = Date.now() - g.ts;
    var threshold = Math.max(150, Math.min(210, window.innerHeight * .22));
    var commit = dy >= threshold &&
                 dx <= dy * .62 &&
                 dt >= 260 &&
                 dt <= 2400;

    var d = detail();
    if (!d) return;

    if (!commit) {
      d.style.setProperty(
        'transition',
        'transform 180ms cubic-bezier(.22,.72,.22,1), opacity 160ms ease-out',
        'important'
      );
      d.style.setProperty('transform','translate3d(0,0,0)','important');
      d.style.setProperty('opacity','1','important');

      setTimeout(function() {
        resetDetailVisual(d);
      }, 210);
      return;
    }

    d.style.setProperty(
      'transition',
      'transform 240ms cubic-bezier(.22,.72,.22,1), opacity 220ms ease-out',
      'important'
    );
    d.style.setProperty('transform','translate3d(0,100vh,0)','important');
    d.style.setProperty('opacity','.88','important');

    setTimeout(function() {
      closeDetail();
      resetDetailVisual(d);
      reconcileActive();
      hardHideTopbars();
    }, 240);
  }, {passive:true, capture:true});

  document.addEventListener('touchcancel', function() {
    var d = detail();
    gesture = null;
    if (!d) return;

    d.style.setProperty(
      'transition',
      'transform 180ms cubic-bezier(.22,.72,.22,1), opacity 160ms ease-out',
      'important'
    );
    d.style.setProperty('transform','translate3d(0,0,0)','important');
    d.style.setProperty('opacity','1','important');

    setTimeout(function() {
      resetDetailVisual(d);
    }, 210);
  }, {passive:true, capture:true});

  document.addEventListener('click', function() {
    setTimeout(function() {
      reconcileActive();
      hardHideTopbars();
      ensureGuard();
    }, 0);
    setTimeout(function() {
      reconcileActive();
      hardHideTopbars();
      ensureGuard();
    }, 100);
  }, true);

  try {
    new MutationObserver(function() {
      reconcileActive();
      hardHideTopbars();
      ensureGuard();
    }).observe(document.body || document.documentElement, {
      subtree:true,
      childList:true,
      attributes:true,
      attributeFilter:['class','style']
    });
  } catch (_) {}

  ensureStyle();
  reconcileActive();
  hardHideTopbars();
  ensureGuard();
})();
''');

              debugPrint(
                '[CalculadoraWebView][FARMACOS_R3_SMOOTH_SHEET] '
                'installed=true platform=ios',
              );

              // MEDCASES_IOS_FARMACOS_CANONICAL_MCD_TOPBARLESS_SMOOTH_DETAIL_V1_B_R8
              await _controller.runJavaScript(r'''
(function() {
  'use strict';
  if (window.__MC_MCD_TOPBARLESS_SMOOTH_R8_BOUND) return;
  window.__MC_MCD_TOPBARLESS_SMOOTH_R8_BOUND = true;

  var PAGE_ID = 'mc-drug-detail-page-v21';
  var STYLE_ID = 'mc-mcd-topbarless-smooth-r8-style';
  var gesture = null;
  var pageObserver = null;
  var creationObserver = null;

  function page() {
    return document.getElementById(PAGE_ID);
  }

  function isOpen(p) {
    p = p || page();
    return !!(p && String(p.dataset.open || '') === 'true');
  }

  function editable(el) {
    if (!el) return false;
    var tag = String(el.tagName || '').toUpperCase();
    return tag === 'INPUT' || tag === 'TEXTAREA' ||
           tag === 'SELECT' || el.isContentEditable === true;
  }

  function ensureStyle() {
    if (document.getElementById(STYLE_ID)) return;

    var st = document.createElement('style');
    st.id = STYLE_ID;
    st.textContent = `
      @keyframes mcMcdOpenR8 {
        from { opacity:.70; transform:translate3d(0,18px,0); }
        to { opacity:1; transform:translate3d(0,0,0); }
      }

      html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"] {
        grid-template-rows:minmax(0,1fr)!important;
      }

      html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"] > .mcd-top {
        display:none!important;
        visibility:hidden!important;
        opacity:0!important;
        pointer-events:none!important;
        width:0!important;
        min-width:0!important;
        max-width:0!important;
        height:0!important;
        min-height:0!important;
        max-height:0!important;
        margin:0!important;
        padding:0!important;
        border:0!important;
        overflow:hidden!important;
      }

      html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"] > .mcd-scroll {
        grid-row:1!important;
        margin:0!important;
        padding-top:0!important;
        top:0!important;
      }

      html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"] .mcd-shell {
        margin-top:0!important;
        padding-top:1px!important;
      }

      html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"] {
        animation:mcMcdOpenR8 280ms cubic-bezier(.22,.72,.22,1) both;
        transform-origin:50% 0%;
        will-change:transform,opacity;
      }

      html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"],
      html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"] * {
        -webkit-tap-highlight-color:rgba(0,0,0,0)!important;
      }
    `;
    (document.head || document.documentElement).appendChild(st);
  }

  function hardApply(p) {
    p = p || page();
    if (!p || !isOpen(p)) return;

    try {
      p.style.setProperty('grid-template-rows','minmax(0,1fr)','important');

      var top = p.querySelector(':scope > .mcd-top');
      if (top) {
        top.style.setProperty('display','none','important');
        top.style.setProperty('visibility','hidden','important');
        top.style.setProperty('opacity','0','important');
        top.style.setProperty('pointer-events','none','important');
        top.style.setProperty('height','0','important');
        top.style.setProperty('min-height','0','important');
        top.style.setProperty('max-height','0','important');
        top.style.setProperty('margin','0','important');
        top.style.setProperty('padding','0','important');
        top.style.setProperty('border','0','important');
        top.style.setProperty('overflow','hidden','important');
      }

      var scroll = p.querySelector(':scope > .mcd-scroll');
      if (scroll) {
        scroll.style.setProperty('grid-row','1','important');
        scroll.style.setProperty('margin','0','important');
        scroll.style.setProperty('padding-top','0','important');
        scroll.style.setProperty('top','0','important');
      }

      var shell = p.querySelector('.mcd-shell');
      if (shell) {
        shell.style.setProperty('margin-top','0','important');
        shell.style.setProperty('padding-top','1px','important');
      }
    } catch (_) {}
  }

  function bindPage(p) {
    if (!p || p.__mcMcdR8Observed) return;
    p.__mcMcdR8Observed = true;

    try {
      pageObserver = new MutationObserver(function() {
        if (isOpen(p)) {
          ensureStyle();
          hardApply(p);
        } else {
          gesture = null;
          resetVisual(p);
        }
      });

      pageObserver.observe(p, {
        attributes:true,
        attributeFilter:['data-open','class'],
        childList:true,
        subtree:false
      });
    } catch (_) {}

    hardApply(p);
  }

  function ensurePage() {
    ensureStyle();
    var p = page();
    if (p) {
      bindPage(p);
      hardApply(p);
      if (creationObserver) {
        try { creationObserver.disconnect(); } catch (_) {}
        creationObserver = null;
      }
      return p;
    }

    if (!creationObserver) {
      try {
        creationObserver = new MutationObserver(function() {
          var found = page();
          if (found) {
            bindPage(found);
            hardApply(found);
            try { creationObserver.disconnect(); } catch (_) {}
            creationObserver = null;
          }
        });

        creationObserver.observe(
          document.body || document.documentElement,
          {childList:true, subtree:true}
        );
      } catch (_) {}
    }

    return null;
  }

  function detailScrollTop(p) {
    if (!p) return 0;
    var sc = p.querySelector(':scope > .mcd-scroll');
    return Number(sc && sc.scrollTop || 0);
  }

  function resetVisual(p) {
    if (!p) return;
    p.style.removeProperty('transition');
    p.style.removeProperty('transform');
    p.style.removeProperty('opacity');
    p.style.removeProperty('will-change');
    p.style.removeProperty('animation');
  }

  function closeCanonical(p) {
    if (!p) return false;
    var btn = p.querySelector('.mcd-close') || p.querySelector('.mcd-back');
    if (btn && typeof btn.click === 'function') {
      btn.click();
      return true;
    }
    return false;
  }

  document.addEventListener('touchstart', function(e) {
    var p = page();
    if (!isOpen(p)) return;
    if (!e.touches || e.touches.length !== 1) return;
    if (editable(e.target) || editable(document.activeElement)) return;
    if (detailScrollTop(p) > 2) return;

    var t = e.touches[0];
    gesture = {
      x:t.clientX,
      y:t.clientY,
      lastX:t.clientX,
      lastY:t.clientY,
      ts:Date.now()
    };

    p.style.setProperty('animation','none','important');
    p.style.setProperty('transition','none','important');
    p.style.setProperty('will-change','transform,opacity','important');
  }, {passive:true, capture:true});

  document.addEventListener('touchmove', function(e) {
    if (!gesture || !e.touches || e.touches.length !== 1) return;

    var p = page();
    if (!isOpen(p)) {
      gesture = null;
      return;
    }

    var t = e.touches[0];
    gesture.lastX = t.clientX;
    gesture.lastY = t.clientY;

    var dy = Math.max(0, t.clientY - gesture.y);
    var dx = Math.abs(t.clientX - gesture.x);
    if (dx > Math.max(24, dy * .80)) return;

    var tracked = Math.min(dy, window.innerHeight * .48);
    var opacity = Math.max(
      .80,
      1 - tracked / Math.max(1,window.innerHeight) * .38
    );

    p.style.setProperty(
      'transform',
      'translate3d(0,' + tracked + 'px,0)',
      'important'
    );
    p.style.setProperty('opacity',String(opacity),'important');
  }, {passive:true, capture:true});

  document.addEventListener('touchend', function() {
    if (!gesture) return;

    var g = gesture;
    gesture = null;

    var p = page();
    if (!isOpen(p)) return;

    var dy = Math.max(0, g.lastY - g.y);
    var dx = Math.abs(g.lastX - g.x);
    var dt = Date.now() - g.ts;
    var threshold = Math.max(150, Math.min(210, window.innerHeight * .22));

    var commit =
      dy >= threshold &&
      dx <= dy * .62 &&
      dt >= 260 &&
      dt <= 2400;

    if (!commit) {
      p.style.setProperty(
        'transition',
        'transform 180ms cubic-bezier(.22,.72,.22,1), opacity 160ms ease-out',
        'important'
      );
      p.style.setProperty('transform','translate3d(0,0,0)','important');
      p.style.setProperty('opacity','1','important');

      setTimeout(function() {
        resetVisual(p);
        hardApply(p);
      }, 210);
      return;
    }

    p.style.setProperty(
      'transition',
      'transform 240ms cubic-bezier(.22,.72,.22,1), opacity 220ms ease-out',
      'important'
    );
    p.style.setProperty('transform','translate3d(0,100vh,0)','important');
    p.style.setProperty('opacity','.88','important');

    setTimeout(function() {
      closeCanonical(p);
      resetVisual(p);
    }, 240);
  }, {passive:true, capture:true});

  document.addEventListener('touchcancel', function() {
    var p = page();
    gesture = null;
    if (!isOpen(p)) return;

    p.style.setProperty(
      'transition',
      'transform 180ms cubic-bezier(.22,.72,.22,1), opacity 160ms ease-out',
      'important'
    );
    p.style.setProperty('transform','translate3d(0,0,0)','important');
    p.style.setProperty('opacity','1','important');

    setTimeout(function() {
      resetVisual(p);
      hardApply(p);
    }, 210);
  }, {passive:true, capture:true});

  document.addEventListener('click', function() {
    setTimeout(function() {
      var p = ensurePage();
      if (isOpen(p)) hardApply(p);
    }, 0);

    setTimeout(function() {
      var p = ensurePage();
      if (isOpen(p)) hardApply(p);
    }, 80);

    setTimeout(function() {
      var p = ensurePage();
      if (isOpen(p)) hardApply(p);
    }, 180);
  }, true);

  ensurePage();
})();
''');

              debugPrint(
                '[CalculadoraWebView][FARMACOS_MCD_R8] '
                'topbarless=true smoothDetail=true platform=ios',
              );

              // MEDCASES_IOS_FARMACOS_NAME_RIGHT_X_ONE_CLICK_CLOSE_V1_B_R9
              await _controller.runJavaScript(r'''
(function(){
'use strict';
if(window.__MC_MCD_NAME_RIGHT_CLOSE_R9_BOUND)return;
window.__MC_MCD_NAME_RIGHT_CLOSE_R9_BOUND=true;

var PAGE_ID='mc-drug-detail-page-v21';
var STYLE_ID='mc-mcd-name-right-close-r9-style';
var boundName=null,pageObserver=null,creationObserver=null;

function page(){return document.getElementById(PAGE_ID);}
function isOpen(p){p=p||page();return !!(p&&String(p.dataset.open||'')==='true');}
function closeButton(p){p=p||page();return p?p.querySelector(':scope > .mcd-top .mcd-close'):null;}
function nameNode(p){p=p||page();return p?p.querySelector('.mcd-id .mcd-name'):null;}

function ensureStyle(){
  if(document.getElementById(STYLE_ID))return;
  var st=document.createElement('style');
  st.id=STYLE_ID;
  st.textContent=`
html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"] .mcd-id .mcd-name{
  position:relative!important;
  box-sizing:border-box!important;
  width:100%!important;
  padding-right:42px!important;
}
html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"] .mcd-id .mcd-name::after{
  content:"×";
  position:absolute;
  right:0;
  top:50%;
  transform:translateY(-50%);
  width:32px;
  height:32px;
  display:flex;
  align-items:center;
  justify-content:center;
  box-sizing:border-box;
  border:0;
  border-radius:7px;
  background:transparent;
  color:var(--mcd-text,#F3F4F6);
  opacity:.88;
  font:500 29px/1 -apple-system,BlinkMacSystemFont,"SF Pro Display","Helvetica Neue",Arial,sans-serif;
  cursor:pointer;
  pointer-events:auto;
  -webkit-user-select:none;
  user-select:none;
  -webkit-touch-callout:none;
  -webkit-tap-highlight-color:rgba(0,0,0,0);
  touch-action:manipulation;
}
html body > #${PAGE_ID}#${PAGE_ID}[data-open="true"] .mcd-id .mcd-name:active::after{
  opacity:.58;
}`;
  (document.head||document.documentElement).appendChild(st);
}

function hitRightClose(ev,name){
  if(!ev||!name)return false;
  var r=name.getBoundingClientRect();
  var x=Number(ev.clientX),y=Number(ev.clientY);
  if(!Number.isFinite(x)||!Number.isFinite(y))return false;
  var localX=x-r.left,localY=y-r.top;
  return localX>=Math.max(0,r.width-36)&&localX<=r.width&&localY>=0&&localY<=r.height;
}

function onNameClick(ev){
  var p=page(),name=ev.currentTarget;
  if(!isOpen(p)||!hitRightClose(ev,name))return;
  ev.preventDefault();
  ev.stopPropagation();

  var close=closeButton(p);
  if(close&&typeof close.click==='function'){
    close.click();
  }
}

function bindName(p){
  if(!isOpen(p))return;
  var name=nameNode(p);
  if(!name)return;

  if(boundName===name&&name.__mcNameRightCloseR9Bound)return;

  if(boundName&&boundName.__mcNameRightCloseR9Bound){
    try{boundName.removeEventListener('click',onNameClick,true);}catch(_){}
  }

  boundName=name;
  name.__mcNameRightCloseR9Bound=true;
  name.addEventListener('click',onNameClick,true);
}

function apply(){
  ensureStyle();
  var p=page();
  if(p&&isOpen(p))bindName(p);
}

function observePage(p){
  if(!p||p.__mcNameRightCloseR9Observed)return;
  p.__mcNameRightCloseR9Observed=true;

  try{
    pageObserver=new MutationObserver(function(){apply();});
    pageObserver.observe(p,{
      attributes:true,
      attributeFilter:['data-open'],
      childList:true,
      subtree:true
    });
  }catch(_){}
}

function ensurePage(){
  ensureStyle();
  var p=page();

  if(p){
    observePage(p);
    apply();

    if(creationObserver){
      try{creationObserver.disconnect();}catch(_){}
      creationObserver=null;
    }
    return;
  }

  if(!creationObserver){
    try{
      creationObserver=new MutationObserver(function(){
        var found=page();
        if(!found)return;

        observePage(found);
        apply();

        try{creationObserver.disconnect();}catch(_){}
        creationObserver=null;
      });

      creationObserver.observe(
        document.body||document.documentElement,
        {childList:true,subtree:true}
      );
    }catch(_){}
  }
}

document.addEventListener('click',function(){
  setTimeout(apply,0);
  setTimeout(apply,80);
  setTimeout(apply,180);
},true);

ensurePage();
})();
''');

              debugPrint(
                '[CalculadoraWebView][FARMACOS_R9] '
                'nameRightClose=true oneClick=true platform=ios',
              );

              // MEDCASES_IOS_FARMACOS_ROOT_SEARCH_NATIVE_KEYBOARD_ISOLATION_V1_B_R15_R1
              await _controller.runJavaScript(r'''
(function(){
  'use strict';
  if(window.__MC_FARMACOS_ROOT_SEARCH_NATIVE_KB_R15_R1_BOUND)return;
  window.__MC_FARMACOS_ROOT_SEARCH_NATIVE_KB_R15_R1_BOUND=true;

  var raf=0;
  var INPUT_IDS=['hm-drug-search','farmacos-search-input'];

  function inputNode(){
    for(var i=0;i<INPUT_IDS.length;i++){
      var el=document.getElementById(INPUT_IDS[i]);
      if(el&&el.isConnected)return el;
    }
    return null;
  }

  function reconcile(){
    raf=0;

    var input=inputNode();
    if(!input)return;

    var q=String(input.value||'').trim();
    var shell=document.getElementById('farmacos-v2-shell');
    var r6Host=document.querySelector(
      '[data-mc-farm-browser-r6-results-host="true"]'
    );

    if(!r6Host)return;

    var canonicalResultsActive=!!(
      shell &&
      shell.getAttribute('data-mc-fnav-results-active')==='true'
    );

    if(canonicalResultsActive || !q){
      r6Host.removeAttribute('data-active');
      return;
    }

    r6Host.setAttribute('data-active','true');
  }

  function schedule(){
    if(raf)return;
    raf=requestAnimationFrame(reconcile);
  }

  document.addEventListener('input',function(ev){
    var t=ev.target;
    if(!t||INPUT_IDS.indexOf(t.id)===-1)return;

    // R15-R1: canonical HTML oninput owns hmFilterDrugs.
    // This bridge only clears stale custom keyboard geometry and reconciles
    // the existing results host; it never calls the search engine.
    if(t.id==='hm-drug-search'){
      try{if(document.body)document.body.classList.remove('keyboard-open')}catch(_){}
      try{
        document.documentElement.style.removeProperty('--mc-farmacos-visible-vh');
        document.documentElement.style.removeProperty('--mc-farm-r1-vv-top');
        document.documentElement.style.removeProperty('--mc-farm-r1-vv-height');
        document.documentElement.style.removeProperty('--keyboard-safe-bottom');
      }catch(_){}
    }

    schedule();
  },true);

  document.addEventListener('click',function(ev){
    var t=ev.target;
    if(!t||!t.closest)return;
    if(
      t.closest('#hub-card-farmacos') ||
      t.closest('#farmacos-v2-shell') ||
      t.closest('#mc-drug-detail-page-v21')
    ){
      schedule();
    }
  },true);

  schedule();
})();
''');

              debugPrint(
                '[CalculadoraWebView][FARMACOS_R15_R1] '
                'rootSearchNativeKeyboard=true canonicalInlineSearch=true platform=ios',
              );

              // MEDCASES_IOS_FARMACOS_DETAIL_TOPBAR_PHYSICAL_OWNER_PROBE_V1_B_R4
              await _controller.runJavaScript(r'''
(function() {
  'use strict';
  if (window.__MC_FARMACOS_TOPBAR_OWNER_PROBE_BOUND) return;
  window.__MC_FARMACOS_TOPBAR_OWNER_PROBE_BOUND = true;

  // MEDCASES_IOS_CALCULADORA_WKCONTENT_PRESSURE_DIAGNOSTIC_EXTERMINATION_V1_B_R16
  // Obsolete forensic owner: do not install layout/text probes or click timers.
  return;

  function slim(el) {
    if (!el) return null;
    var r = el.getBoundingClientRect();
    var s = getComputedStyle(el);
    return {
      tag: el.tagName || null,
      id: el.id || null,
      cls: typeof el.className === 'string' ? el.className : null,
      txt: String(el.innerText || el.textContent || '').trim().slice(0,120),
      x: Math.round(r.x), y: Math.round(r.y),
      w: Math.round(r.width), h: Math.round(r.height),
      d: s.display, v: s.visibility, o: s.opacity,
      p: s.position, z: s.zIndex
    };
  }

  function chain(el) {
    var out = [], n = el, guard = 0;
    while (n && guard < 7) {
      out.push(slim(n));
      n = n.parentElement;
      guard++;
    }
    return out;
  }

  function sample(reason) {
    try {
      var xs = [
        Math.max(8, Math.round(innerWidth * .08)),
        Math.round(innerWidth * .50),
        Math.min(innerWidth - 8, Math.round(innerWidth * .92))
      ];
      var ys = [8,20,32,44,56,68,80,96,112];
      var hits = [];

      ys.forEach(function(y) {
        xs.forEach(function(x) {
          hits.push({
            x:x, y:y,
            els:document.elementsFromPoint(x,y).slice(0,6).map(slim)
          });
        });
      });

      var center = document.elementFromPoint(Math.round(innerWidth/2),44);

      MCCalcDiag.postMessage(JSON.stringify({
        e:'farmacos-topbar-owner-probe',
        r:reason,
        vw:innerWidth,
        vh:innerHeight,
        body:document.body ? document.body.className : null,
        centerChain:chain(center),
        named:{
          overlay:slim(document.getElementById('calculator-overlay-container')),
          overlayHeader:slim(document.getElementById('calculator-overlay-header')),
          overlayTitle:slim(document.getElementById('calculator-overlay-title')),
          overlayBack:slim(document.getElementById('calculator-overlay-back')),
          overlayClose:slim(document.getElementById('calculator-overlay-close')),
          fdModal:slim(document.getElementById('fd-modal')),
          fdHeader:slim(document.querySelector('#fd-modal .fd-header')),
          fdModalHeader:slim(document.getElementById('fd-modal-header'))
        },
        hits:hits
      }));
    } catch (err) {
      try {
        MCCalcDiag.postMessage(JSON.stringify({
          e:'farmacos-topbar-owner-probe-error',
          m:String(err && err.message || err)
        }));
      } catch (_) {}
    }
  }

  document.addEventListener('click', function() {
    setTimeout(function(){ sample('click-0'); },0);
    setTimeout(function(){ sample('click-120'); },120);
    setTimeout(function(){ sample('click-400'); },400);
    setTimeout(function(){ sample('click-1000'); },1000);
  }, true);

  setTimeout(function(){ sample('install-300'); },300);
})();
''');

              debugPrint(
                '[CalculadoraWebView][FARMACOS_TOPBAR_OWNER_PROBE] '
                'installed=true platform=ios',
              );

              // MEDCASES_IOS_CALCULADORA_WKWEBVIEW_DOM_PROJECTION_DIAGNOSTIC_V1_B_R2
              // Runtime telemetry only: no class/style/router mutation.
              await _controller.runJavaScript(r'''
(function () {
  'use strict';

  if (window.__MC_WK_DOM_DIAG_BOUND) {
    try {
      MCCalcDiag.postMessage(JSON.stringify({
        event: 'diag-already-bound',
        href: location.href,
        ts: Date.now()
      }));
    } catch (_) {}
    return;
  }

  window.__MC_WK_DOM_DIAG_BOUND = true;

  // R16: obsolete full-DOM snapshot producer disabled.
  // Preserve MCCalcDiag channel for lightweight functional telemetry only.
  return;

  function rect(el) {
    if (!el) return null;
    var r = el.getBoundingClientRect();
    return {
      x: r.x, y: r.y, w: r.width, h: r.height,
      top: r.top, right: r.right, bottom: r.bottom, left: r.left
    };
  }

  function style(el) {
    if (!el) return null;
    var s = getComputedStyle(el);
    return {
      display: s.display,
      visibility: s.visibility,
      opacity: s.opacity,
      position: s.position,
      overflow: s.overflow,
      overflowX: s.overflowX,
      overflowY: s.overflowY,
      height: s.height,
      maxHeight: s.maxHeight,
      minHeight: s.minHeight,
      contentVisibility: s.contentVisibility || null,
      pointerEvents: s.pointerEvents,
      zIndex: s.zIndex
    };
  }

  function nodeInfo(el) {
    if (!el) return null;
    return {
      tag: el.tagName || null,
      id: el.id || null,
      className: typeof el.className === 'string' ? el.className : null,
      rect: rect(el),
      style: style(el),
      childCount: el.children ? el.children.length : null,
      textLen: (el.innerText || '').length,
      htmlLen: (el.innerHTML || '').length
    };
  }

  function snapshot(eventName, cardId, delayMs) {
    var overlay = document.getElementById('calculator-overlay-container');
    var card = cardId ? document.getElementById(cardId) : null;
    var projected = document.querySelector('.mc-overlay-projected-card');
    var open = document.querySelector('.hub-card.is-open');
    var body = card ? card.querySelector('.hub-card-body') : null;
    var inner = body ? body.querySelector('.hub-card-inner') : null;
    var farmShell = document.getElementById('farmacos-v2-shell');
    var legacyFarm = document.getElementById('page-farmacos');
    var center = null;

    try {
      center = nodeInfo(
        document.elementFromPoint(
          Math.max(0, Math.floor(innerWidth / 2)),
          Math.max(0, Math.floor(innerHeight / 2))
        )
      );
    } catch (_) {}

    var payload = {
      event: eventName,
      delayMs: delayMs,
      ts: Date.now(),
      href: location.href,
      readyState: document.readyState,
      ua: navigator.userAgent,
      viewport: {
        innerWidth: innerWidth,
        innerHeight: innerHeight,
        dpr: devicePixelRatio
      },
      bodyClass: document.body ? document.body.className : null,
      bodyStyle: style(document.body),
      documentElementStyle: style(document.documentElement),
      overlay: nodeInfo(overlay),
      card: nodeInfo(card),
      cardOpen: !!(card && card.classList.contains('is-open')),
      projected: nodeInfo(projected),
      projectedId: projected ? projected.id : null,
      openCard: nodeInfo(open),
      openCardId: open ? open.id : null,
      hubBody: nodeInfo(body),
      hubInner: nodeInfo(inner),
      farmShell: nodeInfo(farmShell),
      legacyFarm: nodeInfo(legacyFarm),
      activeElement: nodeInfo(document.activeElement),
      centerElement: center
    };

    // MEDCASES_IOS_CALCULADORA_WKWEBVIEW_DOM_PROJECTION_DIAGNOSTIC_V1_B_R3
    // Compact packet to stay below Flutter debugPrint truncation.
    function pack(el) {
      if (!el) return null;
      var r = el.getBoundingClientRect();
      var s = getComputedStyle(el);
      return [
        el.id || null,
        typeof el.className === 'string' ? el.className : null,
        Math.round(r.x * 10) / 10,
        Math.round(r.y * 10) / 10,
        Math.round(r.width * 10) / 10,
        Math.round(r.height * 10) / 10,
        s.display,
        s.visibility,
        s.opacity,
        s.height,
        el.children ? el.children.length : null,
        (el.innerText || '').length
      ];
    }

    var compact = {
      e: eventName,
      d: delayMs,
      bc: document.body ? document.body.className : null,
      vv: window.visualViewport
        ? [
            Math.round(window.visualViewport.width * 10) / 10,
            Math.round(window.visualViewport.height * 10) / 10,
            Math.round(window.visualViewport.offsetTop * 10) / 10
          ]
        : null,
      ov: pack(overlay),
      oo: overlay ? overlay.getAttribute('data-mc-owner') : null,
      ca: pack(card),
      co: !!(card && card.classList.contains('is-open')),
      hb: pack(body),
      hi: pack(inner),
      pr: pack(projected),
      pi: projected ? projected.id : null,
      oc: open ? open.id : null,
      fs: pack(farmShell),
      lf: pack(legacyFarm),
      ae: document.activeElement
        ? [
            document.activeElement.tagName || null,
            document.activeElement.id || null,
            typeof document.activeElement.className === 'string'
              ? document.activeElement.className
              : null
          ]
        : null,
      ce: center
        ? [center.tag, center.id, center.className]
        : null
    };

    try {
      MCCalcDiag.postMessage(JSON.stringify(compact));
    } catch (_) {}
  }

  window.addEventListener('error', function (event) {
    try {
      MCCalcDiag.postMessage(JSON.stringify({
        event: 'window-error',
        message: String(event.message || ''),
        source: String(event.filename || ''),
        line: event.lineno || null,
        column: event.colno || null,
        ts: Date.now()
      }));
    } catch (_) {}
  });

  window.addEventListener('unhandledrejection', function (event) {
    try {
      var reason = event.reason;
      MCCalcDiag.postMessage(JSON.stringify({
        e: 'rej',
        n: reason && reason.name ? String(reason.name) : null,
        m: reason && reason.message
          ? String(reason.message)
          : String(reason || ''),
        s: reason && reason.stack
          ? String(reason.stack).slice(0, 700)
          : null,
        ts: Date.now()
      }));
    } catch (_) {}
  });

  snapshot('diag-installed', null, 0);

  document.addEventListener('click', function (event) {
    var target = event && event.target;
    var trigger = target && target.closest
      ? target.closest('.hub-card-trigger')
      : null;

    if (!trigger) return;

    var card = trigger.closest('.hub-card');
    if (!card || !card.id) return;

    [0, 80, 300, 1000, 3000].forEach(function (delayMs) {
      setTimeout(function () {
        snapshot('hub-click-sample', card.id, delayMs);
      }, delayMs);
    });
  }, false);
})();
''');
            } else {
              await _controller.runJavaScript(_kInjectJs);
              _webviewReady = true;

              // Local iOS: replay route intent without a second native page load.
              await _restoreLocalRouteFromWebUrl();

              // Fix#6: injeta tema assim que a página termina de carregar
              await _injectTheme();
              await _injectPatientContext();
              await _applyInitialDeepLinkBridge();
              await _installFarmacosLandingVisibilityGuard();
            }
          },
          onWebResourceError: (WebResourceError error) {
            // BUILD 283: loga erros de WebView no Logcat com código e URL exatos.
            // `adb logcat | grep CalculadoraWebView` para monitorar em produção.
            debugPrint(
              '[CalculadoraWebView][ERR] '
              'code=${error.errorCode} '
              'type=${error.errorType?.name ?? "?"} '
              'desc="${error.description}" '
              'url="${error.url ?? "n/a"}"',
            );
            // Se file:// falhar com ACCESS_DENIED, faz fallback para online.
            // Isso garante que o usuário vê a calculadora mesmo sem cache local.
            if ((error.description.contains('ERR_ACCESS_DENIED') ||
                    error.description.contains('ERR_FILE_NOT_FOUND') ||
                    error.errorCode == -13 ) && // -13 = ERR_ACCESS_DENIED no Chromium
                mounted) {
              debugPrint('[CalculadoraWebView] file→online fallback ativado url=$_webUrl');
              _controller.loadRequest(Uri.parse(_webUrl));
            }
          },
        ));

      // BUILD 283: allowFileAccess — Android WebView bloqueia file:// por padrão
      // em API ≥ 30 (Android 11+). A API correta é AndroidWebViewController.setAllowFileAccess()
      // chamada APÓS a criação do WebViewController.
      //
      // net::ERR_ACCESS_DENIED (errorCode -13 no Chromium) ocorre quando:
      //   - allowFileAccess = false (padrão Android API 30+) → WebView nega file:// URIs
      //     para arquivos em ApplicationSupportDirectory (fora dos assets do APK)
      //
      // SEGURANÇA: allowUniversalAccessFromFileURLs NÃO é habilitado (default=false).
      // Isso impede que file:// faça requests cross-origin para http/https externos.
      // Apenas arquivos locais do app (ApplicationSupport/calculator_cache/) são acessíveis.
      if (!isIOSPlatform) {
        final platform = _controller.platform;
        if (platform is AndroidWebViewController) {
          platform.setAllowFileAccess(true);
          debugPrint('[CalculadoraWebView][BUILD283] AndroidWebView.setAllowFileAccess(true) — file:// desbloqueado');
        }
      }

      // CACHE-FIRST: no online-first and no online->local reload.
      // The WebView mounts immediately, then a single source is selected:
      // valid local cache first; online only when no usable cache exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          _loadPreferredCalculatorSource(reason: 'initial-open'),
        );
      });
    }
  }

  // Fix#6: chamado pelo listener do AppProvider quando darkMode muda
  void _onProviderChanged() {
    final newDark = context.read<AppProvider>().darkMode;
    if (newDark == _dark) return; // sem mudança
    _dark = newDark;
    if (mounted) setState(() {});
    // Injeta tema na WebView se já estiver pronta
    if (!kIsWeb && _webviewReady) _injectTheme();
  }

  // MEDCASES_FARMACOS_LANDING_VISIBLE_SHELL_GUARD_V1_B_R0
  // Visual-only recovery for Fármacos landing; detail modal remains untouched.
  Future<void> _installFarmacosLandingVisibilityGuard() async {
    if (kIsWeb || !_webviewReady) return;

    final parsed = Uri.tryParse(_webUrl);
    if (parsed == null) return;

    final tab = (parsed.queryParameters['tab'] ?? '').trim().toLowerCase();

    if (tab != 'farmacos') {
      try {
        await _controller.runJavaScript(
          "document.body && document.body.removeAttribute('data-mc-flutter-farmacos-landing');",
        );
      } catch (_) {}
      return;
    }

    try {
      await _controller.runJavaScript(
        r"""
(function() {
  try {
    var body = document.body;
    if (!body) return;

    body.setAttribute('data-mc-flutter-farmacos-landing', 'true');

    var styleId = 'mc-flutter-farmacos-landing-visible-shell-guard-v1-b-r0';
    var style = document.getElementById(styleId);

    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      style.textContent = `
body[data-mc-flutter-farmacos-landing="true"]:not(:has(#fd-modal.open)) #farmacos-v2-shell {
  display:block!important;
  visibility:visible!important;
  opacity:1!important;
  pointer-events:auto!important;
  height:auto!important;
  min-height:120px!important;
  max-height:none!important;
  overflow:visible!important;
}
body[data-mc-flutter-farmacos-landing="true"]:not(:has(#fd-modal.open)) #farmacos-v2-shell .farmacos-v2-tabs,
body[data-mc-flutter-farmacos-landing="true"]:not(:has(#fd-modal.open)) #farmacos-v2-shell [data-farmacos-v2-search-wrapper],
body[data-mc-flutter-farmacos-landing="true"]:not(:has(#fd-modal.open)) #farmacos-v2-shell .hm-search-wrap {
  visibility:visible!important;
  opacity:1!important;
  pointer-events:auto!important;
}
body[data-mc-flutter-farmacos-landing="true"]:not(:has(#fd-modal.open)) #farmacos-v2-shell [data-farmacos-panel].is-active {
  display:block!important;
  visibility:visible!important;
  opacity:1!important;
  pointer-events:auto!important;
  height:auto!important;
  max-height:none!important;
  overflow:visible!important;
}
body[data-mc-flutter-farmacos-landing="true"]:not(:has(#fd-modal.open)) #farmacos-v2-shell :is(
  [data-mc-farm-canonical-drug],
  .mc-fnav-drug-row,
  #hm-drug-list .hm-drug-item,
  .farmacos-v2-context-row,
  .farmacos-v2-group-row
) {
  visibility:visible!important;
  opacity:1!important;
}
body[data-mc-flutter-farmacos-landing="true"]:not(:has(#fd-modal.open)) #farmacos-v2-shell :is(
  .hm-drug-name,
  .mc-fnav-drug-name,
  .farmacos-v2-row-title,
  .mc-farm-render-only-title
) {
  visibility:visible!important;
  opacity:1!important;
  color:var(--farm-v2-text,#F8FAFC)!important;
  -webkit-text-fill-color:var(--farm-v2-text,#F8FAFC)!important;
}
`;
      document.head.appendChild(style);
    }

    var shell = document.getElementById('farmacos-v2-shell');
    var rows = shell ? shell.querySelectorAll('[data-mc-farm-canonical-drug],.mc-fnav-drug-row,#hm-drug-list .hm-drug-item,.farmacos-v2-context-row,.farmacos-v2-group-row').length : 0;

    console.log('[FlutterFarmacosLandingGuard] installed=true shell=' + !!shell + ' rows=' + rows + ' detailOpen=' + !!document.querySelector('#fd-modal.open'));
  } catch (e) {
    console.warn('[FlutterFarmacosLandingGuard] install failed', e);
  }
})();
""",
      );

      debugPrint(
        '[CalculadoraWebView][FARMACOS_LANDING] visibilityGuardInstalled=true tab=farmacos',
      );
    } catch (e) {
      debugPrint(
        '[CalculadoraWebView][FARMACOS_LANDING] visibilityGuardError=$e',
      );
    }
  }

  // MEDCASES_CALCULATOR_THEME_BRIDGE_V1_B_R0
  // Receiver produtivo da calculadora: window.MedCasesBridge.setTheme('dark'|'light').
  // Mantém fallback para updateMedCasesTheme durante compatibilidade retroativa.
  // PHYSICAL_DEEPLINK_BRIDGE_V1
  Future<void> _applyInitialDeepLinkBridge() async {
    if (kIsWeb || !_webviewReady) return;

    final parsed = Uri.tryParse(_webUrl);
    if (parsed == null) return;

    final params = parsed.queryParameters;
    final tab = (params['tab'] ?? '').trim();
    if (tab.isEmpty) return;

    final options = <String, String>{};
    for (final key in const <String>['lang', 'q', 'drug1', 'drug2']) {
      final value = (params[key] ?? '').trim();
      if (value.isNotEmpty) options[key] = value;
    }

    final tabJson = jsonEncode(tab);
    final optionsJson = jsonEncode(options);

    try {
      await _controller.runJavaScript(
        """
(function(tab, opts) {
  var attempts = 0;
  function route() {
    if (window.MedCasesRouter &&
        typeof window.MedCasesRouter.go === 'function') {
      window.MedCasesRouter.go(tab, opts || {});
      return;
    }
    attempts += 1;
    if (attempts <= 24) setTimeout(route, 100);
  }
  route();
})($tabJson, $optionsJson);
""",
      );
      debugPrint('[CALCULATOR_DEEPLINK_BRIDGE] applied=true tab=$tab');
    } catch (e) {
      debugPrint('[CALCULATOR_DEEPLINK_BRIDGE] error=$e');
    }
  }

  Future<void> _injectTheme() async {
    if (kIsWeb) return;
    final theme = _dark ? 'dark' : 'light';
    try {
      await _controller.runJavaScript(
        """
(function(theme) {
  var attempts = 0;

  function syncThemeDom() {
    var isLight = theme === 'light';
    var root = document.documentElement;
    var body = document.body;

    if (root) {
      root.classList.toggle('light-mode', isLight);
      root.classList.toggle('theme-light', isLight);
      root.setAttribute('data-theme', theme);
      root.setAttribute('data-current-theme', theme);
      root.style.colorScheme = theme;
    }

    if (body) {
      body.classList.toggle('light-mode', isLight);
      body.classList.toggle('theme-light', isLight);
      body.setAttribute('data-theme', theme);
      body.setAttribute('data-current-theme', theme);
    }
  }

  function applyTheme() {
    // MEDCASES_CALCULATOR_THEME_SYNC_V2_B_R0
    syncThemeDom();

    if (window.MedCasesBridge &&
        typeof window.MedCasesBridge.setTheme === 'function') {
      window.MedCasesBridge.setTheme(theme);
      syncThemeDom();
      return;
    }
    if (typeof window.updateMedCasesTheme === 'function') {
      window.updateMedCasesTheme(theme);
      syncThemeDom();
      return;
    }
    if (attempts < 12) {
      attempts += 1;
      setTimeout(applyTheme, 100);
    }
  }

  applyTheme();
})('$theme');
""",
      );
    } catch (e) {
      debugPrint('[CalculadoraScreen][theme] inject error: $e');
    }
  }


  Future<void> _injectPatientContext() async {
    if (kIsWeb || _calculatorPatientPayload.isEmpty) return;

    final payloadJson = jsonEncode(_calculatorPatientPayload);
    try {
      await _controller.runJavaScript(
        r"""
(function(payload) {
  var attempts = 0;
  function apply() {
    if (window.MedCasesPatientSession &&
        typeof window.MedCasesPatientSession.hydrate === 'function') {
      window.MedCasesPatientSession.hydrate(payload, 'flutter-onPageFinished');
      return;
    }
    if (attempts < 30) {
      attempts += 1;
      setTimeout(apply, 100);
    }
  }
  apply();
})(PAYLOAD_JSON);
""".replaceFirst('PAYLOAD_JSON', payloadJson),
      );
    } catch (e) {
      debugPrint('[CalculadoraScreen][patient-context] inject error: $e');
    }
  }

  Future<void> _clearCalculatorSession() async {
    if (kIsWeb) return;
    try {
      await _controller.runJavaScript(
        r"""
(function() {
  if (window.MedCasesPatientSession &&
      typeof window.MedCasesPatientSession.clear === 'function') {
    window.MedCasesPatientSession.clear('flutter-exit');
    return;
  }
  try { localStorage.removeItem('medcases_hm_patient_v1'); } catch (_) {}
  try { localStorage.removeItem('pacienteAtual'); } catch (_) {}
  try { sessionStorage.removeItem('medcases_hm_patient_v1'); } catch (_) {}
  try { sessionStorage.removeItem('pacienteAtual'); } catch (_) {}
  window.hmPatientState = {};
  window.patientData = {};
})();
""",
      );
    } catch (e) {
      debugPrint('[CalculadoraScreen][patient-context] clear error: $e');
    }
  }

  Future<void> _exitCalculator() async {
    if (_calculatorExitInProgress) return;
    _calculatorExitInProgress = true;

    await _clearCalculatorSession();

    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
      return;
    }
    _calculatorExitInProgress = false;
  }

  /// Detecta iOS sem depender de InheritedWidget durante initState().
  // MEDCASES_IOS_CALCULADORA_INITSTATE_INHERITED_THEME_FIX_V1_B_R7
  bool _detectIOS() {
    // Seguro em initState(): não consulta Theme.of(context).
    return defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    // MEDCASES_PATIENT_CONTEXT_SESSION_BRIDGE_V1_B_R0_R1: best-effort em gesto/back do SO.
    if (!kIsWeb) unawaited(_clearCalculatorSession());
    // Fix#6: remove listener para evitar memory leak
    if (mounted) {
      context.read<AppProvider>().removeListener(_onProviderChanged);
    }
    CalculadoraScreen.cacheRefreshGeneration
        .removeListener(_onCalculatorCacheRefreshRequested);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Paleta dark/light ────────────────────────────────────────────────
    // SUPER ORDEM VISUAL 09: barBg/borderCol/textPrimary/textSecondary removidos
    // — o AppBar agora usa gradiente roxo const; só scaffoldBg permanece.
    // Fix#6: _dark agora é mutável — atualizado pelo listener do AppProvider.
    final Color scaffoldBg  = _dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: scaffoldBg,

        // ── SUPER ORDEM VISUAL 09: AppBar Cupertino/Linear ────────────────
        // M1: Stack Left-Center-Right. Subtítulo "MedCases Pro" destruído.
        // M2: Gradiente roxo #3B0764→#7E22CE→#A855F7 (idêntico ao card Home).
        // Direita: logotipo M+ dourado (app_icon.png, height 28).
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
      // MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R8
            // MEDCASES_FARMACOS_WEBVIEW_TOPBAR_V1_B_R0
            decoration: Theme.of(context).brightness == Brightness.dark
                ? const BoxDecoration(
                    color: Color(0xFF1A1D23),
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFF2D3340),
                        width: 0.5,
                      ),
                    ),
                  )
                : const BoxDecoration(
                    color: Color(0xFFECF1F3),
                    border: Border(
                      bottom: BorderSide(
                        color: Color(0xFFD8E0E7),
                        width: 0.5,
                      ),
                    ),
                  ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // CENTER: título isolado e absolutamente centrado
                    Text(
                      'FÁRMACOS',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark ? (Colors.white) : const Color(0xFF05070A),
                        letterSpacing: 0.4,
                      ),
                    ),
                    // LEFT: botão de voltar — canPop guard (SUPER ORDEM 313)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          unawaited(_exitCalculator());
                        },
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Theme.of(context).brightness == Brightness.dark ? (Colors.white) : const Color(0xFF05070A),
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    // RIGHT: M+ dourado pulsante — ADENDO Build 309
                    // _CalcMplusPulse: loop 0.4↔1.0 opacity, 1500ms
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: const _CalcMplusPulse(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── SUPER ORDEM VISUAL 09 M3: Barra de navegação inferior ───────────
        // Permite ao usuário navegar de volta para o shell sem se sentir preso.
        // Usa Navigator.maybePop() — retorna ao MainShell preservando o tab ativo.
        // SUPER ORDEM MASTER CALC: bottomNavigationBar removido.
        // Floating Dock agora está no Body Stack (glassmorphism idêntico ao MainShell).

        // BUILD 317 M3: FloatingDock + SourcesBar removidos.
        // WebView ocupa o viewport completo — zero anteparos inferiores.
        body: kIsWeb
            ? buildCalculadoraWebView(_webUrl, _dark)
            : WebViewWidget(controller: _controller),
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// SUPER ORDEM MASTER CALC ADENDO: _CalcMplusPulse
// M+ dourado pulsante no TopBar da Calculadora.
// Loop suave 0.4 ↔ 1.0 opacidade em 1.5s — idêntico ao _MplusPulse da IA.
// ─────────────────────────────────────────────────────────────────────────────
class _CalcMplusPulse extends StatefulWidget {
  const _CalcMplusPulse();
  @override
  State<_CalcMplusPulse> createState() => _CalcMplusPulseState();
}

class _CalcMplusPulseState extends State<_CalcMplusPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (!mounted) return;
        if (status == AnimationStatus.completed) _ctrl.reverse();
        if (status == AnimationStatus.dismissed) _ctrl.forward();
      });
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: const Text(
          'M+',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFFD4AF37),
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}
