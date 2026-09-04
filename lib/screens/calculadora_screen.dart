import 'dart:async';
import 'dart:convert';

// Build 187: Gray Screen Fix — Web usa HtmlElementView/iframe; iOS/Android mantém WebView nativo.
// dart:io Platform removido — usa kIsWeb para guards de plataforma.
// BUILD 240: OfflineCalculatorCacheService resolve URL local antes de carregar WebView.
// BUILD 283: allowFileAccess + allowFileAccessFromFileURLs via AndroidWebViewController
//            para resolver net::ERR_ACCESS_DENIED ao carregar file:// offline cache.
import 'package:flutter/foundation.dart'
    show ValueNotifier, debugPrint, kIsWeb;
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
      final localUrl =
          await OfflineCalculatorCacheService.instance.buildLocalUrl(_webUrl);

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
      final localUrl =
          await OfflineCalculatorCacheService.instance.buildLocalUrl(_webUrl);
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
        ..setNavigationDelegate(NavigationDelegate(
          onPageStarted: (_) async {
            await _controller.runJavaScript(_kEarlyInjectJs);
          },
          onPageFinished: (_) async {
            await _controller.runJavaScript(_kInjectJs);
            _webviewReady = true;

            // Local iOS: replay route intent without a second native page load.
            await _restoreLocalRouteFromWebUrl();

            // Fix#6: injeta tema assim que a página termina de carregar
            await _injectTheme();
            await _injectPatientContext();
            await _applyInitialDeepLinkBridge();
            await _installFarmacosLandingVisibilityGuard();
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

  /// Detecta iOS sem usar dart:io Platform (compatível com Flutter Web).
  bool _detectIOS() {
    // defaultTargetPlatform é seguro em todas as plataformas.
    return Theme.of(context).platform == TargetPlatform.iOS;
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
