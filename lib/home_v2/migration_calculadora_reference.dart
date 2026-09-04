// Build 187: Gray Screen Fix — Web usa HtmlElementView/iframe; iOS/Android mantém WebView nativo.
// dart:io Platform removido — usa kIsWeb para guards de plataforma.
// BUILD 240: OfflineCalculatorCacheService resolve URL local antes de carregar WebView.
// BUILD 283: allowFileAccess + allowFileAccessFromFileURLs via AndroidWebViewController
//            para resolver net::ERR_ACCESS_DENIED ao carregar file:// offline cache.
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
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
  late final String _webUrl;

  @override
  void initState() {
    super.initState();

    final p         = context.read<AppProvider>();
    final lang      = p.lang;
    final langParam = lang == 'es' ? 'es' : 'pt';
    _dark           = p.darkMode;
    // Build 189: initialUrl tem prioridade sobre URL padrão do provider.
    // ExternalToolLinkEngine já injeta lang+tab+q — não sobrescrever.
    _webUrl = widget.initialUrl ?? '$_kBaseUrl?lang=$langParam';

    // Fix#6: escuta mudanças de tema do AppProvider — injeta tema na WebView
    // imediatamente após toggle, sem necessidade de recarregar a página.
    p.addListener(_onProviderChanged);

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
            // Fix#6: injeta tema assim que a página termina de carregar
            _webviewReady = true;
            await _injectTheme();
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
        ))
        // BUILD 240: carrega online primeiro; addPostFrameCallback resolve cache local
        // e redireciona se disponível (evita async em initState).
        ..loadRequest(Uri.parse(_webUrl));

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

      // BUILD 240: resolve URL do cache local de forma assíncrona.
      // Roda no primeiro frame após o widget ser montado para evitar setState
      // em initState(). Se cache válido existir, recarrega com file://.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final localUrl = await OfflineCalculatorCacheService.instance
              .buildLocalUrl(_webUrl);
          if (localUrl != null && mounted) {
            debugPrint('[OFFLINE_CACHE] openSource=local url=$localUrl');
            _controller.loadRequest(Uri.parse(localUrl));
          } else {
            debugPrint('[OFFLINE_CACHE] openSource=online url=$_webUrl');
          }
        } catch (e) {
          debugPrint('[OFFLINE_CACHE] fallbackOnline=true error=$e');
        }
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

  // Fix#6: injeta window.updateMedCasesTheme('dark'|'light') na WebView nativa
  Future<void> _injectTheme() async {
    if (kIsWeb) return;
    final theme = _dark ? 'dark' : 'light';
    try {
      await _controller.runJavaScript(
        "if(typeof window.updateMedCasesTheme==='function'){window.updateMedCasesTheme('$theme');}",
      );
    } catch (e) {
      debugPrint('[CalculadoraScreen][theme] inject error: $e');
    }
  }

  /// Detecta iOS sem usar dart:io Platform (compatível com Flutter Web).
  bool _detectIOS() {
    // defaultTargetPlatform é seguro em todas as plataformas.
    return Theme.of(context).platform == TargetPlatform.iOS;
  }

  @override
  void dispose() {
    // Fix#6: remove listener para evitar memory leak
    if (mounted) {
      context.read<AppProvider>().removeListener(_onProviderChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ── Paleta dark/light ────────────────────────────────────────────────
    // SUPER ORDEM VISUAL 09: barBg/borderCol/textPrimary/textSecondary removidos
    // — o AppBar agora usa gradiente roxo const; só scaffoldBg permanece.
    // Fix#6: _dark agora é mutável — atualizado pelo listener do AppProvider.
    final Color scaffoldBg  = _dark ? const Color(0xFF0F091E) : const Color(0xFFF8F9FA);

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
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3B0764), // roxo profundo
                  Color(0xFF7E22CE), // roxo vibrante (idêntico ao card Home)
                  Color(0xFFA855F7), // roxo claro
                ],
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFF4C1D95), width: 0.5),
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
                    const Text(
                      'CALCULADORA CLÍNICA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    // LEFT: botão de voltar — canPop guard (SUPER ORDEM 313)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          final nav = Navigator.of(context);
                          if (nav.canPop()) nav.pop();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
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
