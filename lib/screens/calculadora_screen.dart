import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../providers/app_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// URL base — ?lang=pt ou ?lang=es injetado em initState() conforme AppProvider
// ─────────────────────────────────────────────────────────────────────────────
const _kBaseUrl    = 'https://www.medcasescalcu.com';
const _kSourcesUrl = 'https://www.promedcases.com/fontes-e-referencias';

// ─────────────────────────────────────────────────────────────────────────────
// JS PRECOCE — injetado em onPageStarted (antes do DOMContentLoaded)
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

  // ══════════════════════════════════════════════════════════════════════════
  // 🔬 DIAGNÓSTICO VISUAL — bordas no DOM do Wix
  // Verde  = borda do <html>  (documentElement)
  // Magenta = borda do <body>
  // Se você vê verde/magenta na tela → o WKWebView está pintando além do frame
  // Se NÃO vê → a área invisível é Flutter/Scaffold, não o WebView.
  // ══════════════════════════════════════════════════════════════════════════
  document.documentElement.style.border = '3px solid green';
  document.body.style.border            = '3px solid magenta';

})();
""";

// ─────────────────────────────────────────────────────────────────────────────
// TELA DE CALCULADORA — BUILD DE DIAGNÓSTICO
// ─────────────────────────────────────────────────────────────────────────────
class CalculadoraScreen extends StatefulWidget {
  const CalculadoraScreen({super.key});

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  late final WebViewController _controller;
  late final bool _isEs;

  // Estado da barra de fontes nativa Flutter
  bool _sourcesExpanded = false;

  @override
  void initState() {
    super.initState();

    // ── DIAGNÓSTICO: fixes assíncronos REMOVIDOS para raio-x limpo ──────────
    // UniqueKey rebuild e delayed setState retirados neste build.
    // Objetivo: ver exatamente o que cada camada pinta SEM interferência.

    final lang      = context.read<AppProvider>().lang;
    final langParam = lang == 'es' ? 'es' : 'pt';
    _isEs           = lang == 'es';

    final PlatformWebViewControllerCreationParams params;
    if (Platform.isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) MedCasesApp/6.1.0')
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) async {
          await _controller.runJavaScript(_kEarlyInjectJs);
        },
        onPageFinished: (_) async {
          await _controller.runJavaScript(_kInjectJs);
          // ← fixes async REMOVIDOS para diagnóstico limpo
        },
      ))
      ..loadRequest(Uri.parse('$_kBaseUrl?lang=$langParam'));
  }

  Future<void> _openSourcesUrl() async {
    final uri = Uri.parse(_kSourcesUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view       = View.of(context);
    final topPadding = view.viewPadding.top / view.devicePixelRatio;

    const double _kBarCollapsed = 24.0;
    const double _kBarExpanded  = 108.0;
    final double barHeight = _sourcesExpanded ? _kBarExpanded : _kBarCollapsed;

    final String labelBar = _isEs
        ? '\uD83D\uDD3C Ver Fuentes Acad\u00e9micas \u00b7 AHA \u00b7 ACC \u00b7 WHO...'
        : '\uD83D\uDD3C Ver Fontes Acad\u00eamicas \u00b7 AHA \u00b7 ACC \u00b7 WHO...';
    final String labelTitle = _isEs
        ? 'Ver Fuentes Acad\u00e9micas'
        : 'Ver Fontes Acad\u00eamicas';
    final String labelBtn = _isEs
        ? 'Abrir referencias \u2197'
        : 'Abrir refer\u00eancias \u2197';

    // ══════════════════════════════════════════════════════════════════════════
    // 🔬 DIAGNÓSTICO VISUAL — legenda das cores Flutter
    //
    //  🔴 VERMELHO  = Scaffold.backgroundColor
    //                 Se a barra no fundo for VERMELHA → espaço vazio é Flutter,
    //                 não o WebView nem o Wix.
    //
    //  🔵 AZUL (borda 3px) = Container pai do WebView (LayoutBuilder/Positioned)
    //                 Mostra exatamente até onde o Flutter acha que o WebView vai.
    //
    //  🟡 AMARELO   = AnimatedContainer da barra de fontes nativa Flutter
    //                 Confirma posição e altura da barra Flutter.
    //
    //  🟢 VERDE     = borda do <html> injetada via JS no Wix
    //  🟣 MAGENTA   = borda do <body> injetada via JS no Wix
    //                 Se aparecerem na área problemática → é o WebView/DOM.
    //                 Se NÃO aparecerem → é Flutter.
    // ══════════════════════════════════════════════════════════════════════════
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        // 🔴 VERMELHO: se a barra inferior for vermelha, o espaço é do Flutter
        backgroundColor: Colors.red,
        body: SafeArea(
          top:    false,
          bottom: false,
          child: Column(
            children: [

              // ── Header gradiente ──────────────────────────────────────────
              Container(
                height: topPadding + 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A0F2E),
                      Color(0xFF2D1B5A),
                      Color(0xFF4A2D8A),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: topPadding),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text(
                          'CALCULADORA CL\u00cdNICA',
                          style: TextStyle(
                            fontSize:      16,
                            fontWeight:    FontWeight.w800,
                            color:         Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── WebView + barra de fontes nativa ──────────────────────────
              Expanded(
                child: Stack(
                  children: [

                    // 🔵 AZUL: borda no container pai do WebView
                    // Mostra exatamente até onde o Flutter delimita o WebView.
                    Positioned(
                      top:    0,
                      left:   0,
                      right:  0,
                      bottom: _kBarCollapsed,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 3),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SizedBox(
                              width:  constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: WebViewWidget(
                                controller: _controller,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // 🟡 AMARELO: barra de fontes Flutter nativa
                    // Confirma posição e tamanho da barra Flutter.
                    Positioned(
                      left:   0,
                      right:  0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _sourcesExpanded = !_sourcesExpanded),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                          height: barHeight,
                          // 🟡 COR AMARELA para diagnóstico
                          color: Colors.yellow,
                          child: _sourcesExpanded
                              ? _buildExpandedSources(labelTitle, labelBtn)
                              : _buildCollapsedSources(labelBar),
                        ),
                      ),
                    ),

                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  // ── Vista colapsada (24px) ──────────────────────────────────────────────────
  Widget _buildCollapsedSources(String label) {
    return Center(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize:      10,
          color:         Colors.black,  // preto sobre amarelo para legibilidade
          letterSpacing: 0.3,
          height:        1.0,
        ),
      ),
    );
  }

  // ── Vista expandida (108px) ─────────────────────────────────────────────────
  Widget _buildExpandedSources(String title, String btnLabel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('\uD83D\uDCDA', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize:      12,
                fontWeight:    FontWeight.w700,
                color:         Colors.black,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'AHA \u00b7 ACC \u00b7 WHO \u00b7 PubMed \u00b7 UpToDate',
          style: TextStyle(
            fontSize:      9,
            color:         Colors.black54,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            setState(() => _sourcesExpanded = false);
            _openSourcesUrl();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            decoration: BoxDecoration(
              color:        const Color(0x26A78BFA),
              border:       Border.all(color: const Color(0x59A78BFA)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              btnLabel,
              style: const TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
