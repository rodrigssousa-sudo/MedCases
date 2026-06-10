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
      // Colors.transparent → scrollView.backgroundColor = UIColor.clear
      // Scaffold.backgroundColor(0xFF0F091E) aparece atrás, sem layer sólido.
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) async {
          await _controller.runJavaScript(_kEarlyInjectJs);
        },
        onPageFinished: (_) async {
          await _controller.runJavaScript(_kInjectJs);
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

    // ── BARRA DE FONTES — dimensões ──────────────────────────────────────────
    // Collapsed: 24px — linha única de texto pequeno flutuando ao centro.
    // Expanded : 108px — título, sublabel e botão de abertura.
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

    // ── LAYOUT ────────────────────────────────────────────────────────────────
    //
    // Column[
    //   header (topPadding + 52px),
    //   Expanded > Stack[
    //     Positioned.fill(bottom: 24) → WebView  ← não fica atrás da barra
    //     Positioned(bottom:0)        → barra Flutter nativa (24–108px)
    //   ]
    // ]
    //
    // • SafeArea(bottom:false): sem padding automático do SO na base.
    // • Expanded: WebView + barra recebem TODO o espaço restante do Column.
    // • WebView termina exatamente onde a barra começa — sem sobreposição.
    // • Barra é um widget Flutter puro: zero JS, zero DOM, zero CSS.
    // • Scaffold.backgroundColor cobre qualquer pixel não pintado pelo WebView.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F091E),
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

                    // WebView termina ACIMA da barra — sem sobreposição
                    Positioned(
                      top:    0,
                      left:   0,
                      right:  0,
                      bottom: _kBarCollapsed, // reserva 24px permanentes para a barra
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SizedBox(
                            width:  constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: WebViewWidget(controller: _controller),
                          );
                        },
                      ),
                    ),

                    // ── Barra de fontes Flutter nativa ────────────────────
                    // Zero JS. Zero DOM. Zero CSS.
                    // Widget Flutter puro — animado com AnimatedContainer.
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
                          decoration: BoxDecoration(
                            // Fundo ligeiramente mais claro que o Scaffold (0xFF0F091E)
                            // para criar separação sutil sem quebrar a unidade do tema.
                            color: const Color(0xFF1A1035),
                            border: const Border(
                              top: BorderSide(
                                color: Color(0x33A78BFA), // violeta 20% opacidade
                                width: 1,
                              ),
                            ),
                          ),
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
          color:         Color(0xB3B8A8E8), // violeta claro 70% opacidade
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
        // Título
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
                color:         Color(0xFFA78BFA),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Sublabel
        const Text(
          'AHA \u00b7 ACC \u00b7 WHO \u00b7 PubMed \u00b7 UpToDate',
          style: TextStyle(
            fontSize:      9,
            color:         Color(0x99B8A8E8), // violeta claro 60% opacidade
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        // Botão de abertura
        GestureDetector(
          onTap: () {
            setState(() => _sourcesExpanded = false);
            _openSourcesUrl();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            decoration: BoxDecoration(
              color:        const Color(0x26A78BFA), // violeta 15% opacidade
              border:       Border.all(color: const Color(0x59A78BFA)), // 35% opacidade
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              btnLabel,
              style: const TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w600,
                color:      Color(0xFFC4B5FD),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
