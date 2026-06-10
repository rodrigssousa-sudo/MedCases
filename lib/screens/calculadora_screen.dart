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
// Injeta <style> no <head> ANTES que o Wix tenha chance de aplicar qualquer
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
// JS PRINCIPAL — injetado em onPageFinished (após DOM completo)
//
// REGRAS:
//  • NÃO definir height/min-height no <html> ou <body> — isso corta o scroll
//    em páginas Wix e impede que o conteúdo abaixo do viewport seja acessível.
//  • padding-top: 0 — Flutter header (Positioned top:0) já cobre a status bar.
//  • padding-bottom: 0 — SafeArea(bottom:false) + Expanded entrega altura real.
//  • overscroll-behavior: none — impede bounce do iOS de expor ghost space.
//  • -webkit-overflow-scrolling: auto — desativa momentum scroll rubber-band.
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

  // ── B. CSS global — zera insets, bounce e footers Wix de uma só vez ──────
  var styleId = 'mc-global-reset';
  if (!document.getElementById(styleId)) {
    var style = document.createElement('style');
    style.id = styleId;
    style.textContent = [
      // html: sem padding/margin, sem bounce
      'html {',
      '  padding: 0 !important;',
      '  margin:  0 !important;',
      '  overscroll-behavior: none !important;',
      '  -webkit-overflow-scrolling: auto !important;',
      '}',
      // body: sem padding/margin em nenhuma direção
      //   • padding-top:    0 — Flutter header Positioned já cobre a status bar
      //   • padding-bottom: 0 — SafeArea(bottom:false)+Expanded dá altura real
      'body {',
      '  margin:  0 !important;',
      '  padding: 0 !important;',
      '  padding-top:    0px !important;',
      '  padding-bottom: 0px !important;',
      '  overscroll-behavior-y: none !important;',
      '  -webkit-overflow-scrolling: auto !important;',
      '}',

      // Footer Wix — IDs reais extraídos do HTML live de medcasescalcu.com
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

      // Zera margin/padding-bottom dos containers de página Wix
      '#PAGES_CONTAINER, #masterPage, #site-root, #SITE_PAGES {',
      '  margin-bottom:  0 !important;',
      '  padding-bottom: 0 !important;',
      '}',
    ].join('\n');
    (document.head || document.documentElement).appendChild(style);
  }

  // ── C. Inline imperativo — aplica mesmo se <head> ainda não estiver pronto
  document.body.style.setProperty('margin',                     '0',    'important');
  document.body.style.setProperty('padding-top',                '0px',  'important');
  document.body.style.setProperty('padding-bottom',             '0px',  'important');
  document.body.style.setProperty('overscroll-behavior-y',      'none', 'important');
  document.body.style.setProperty('-webkit-overflow-scrolling', 'auto', 'important');
  document.documentElement.style.setProperty('overscroll-behavior',           'none', 'important');
  document.documentElement.style.setProperty('-webkit-overflow-scrolling',    'auto', 'important');
  document.documentElement.style.removeProperty('height');
  document.body.style.removeProperty('height');
  document.body.style.removeProperty('min-height');
  document.body.style.removeProperty('max-height');
  document.body.style.removeProperty('overflow-y');

  // ── D. Kill imperativo do footer já no DOM ───────────────────────────────
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
// JS DA BARRA RETRÁTIL DE FONTES ACADÊMICAS
//
// DESIGN: barra fixa no rodapé da WebView — ultra-discreta (20px colapsada).
//  • Estado fechado : 20px de altura — apenas uma linha de texto mínima.
//  • Estado aberto  : 120px — exibe título, sublabel e botão de link externo.
//  • Transição CSS suave (0.3s ease) em ambas as direções.
//  • position: fixed bottom:0 — nunca ocupa espaço no flow do conteúdo Wix.
//  • Padding-bottom = 0 — a SafeArea(bottom:false) do Flutter não afeta o DOM;
//    a home bar fica visível atrás da barra porque o WebView é transparente.
// ─────────────────────────────────────────────────────────────────────────────
String _buildSourcesButtonJs(bool isEs) {
  final labelCollapsed = isEs
      ? '\uD83D\uDD3C Ver Fuentes Acad\u00e9micas \u00b7 AHA \u00b7 ACC \u00b7 WHO...'
      : '\uD83D\uDD3C Ver Fontes Acad\u00eamicas \u00b7 AHA \u00b7 ACC \u00b7 WHO...';
  final labelExpanded = isEs
      ? 'Ver Fuentes Acad\u00e9micas'
      : 'Ver Fontes Acad\u00eamicas';
  final sublabel = 'AHA \u00b7 ACC \u00b7 WHO \u00b7 PubMed \u00b7 UpToDate';
  final btnText = isEs ? 'Abrir referencias \u2197' : 'Abrir refer\u00eancias \u2197';

  return '''
(function() {
  if (document.getElementById('mc-sources-bar')) return;

  // ── Barra principal ────────────────────────────────────────────────────────
  var bar = document.createElement('div');
  bar.id = 'mc-sources-bar';
  bar.style.cssText = [
    'position: fixed !important',
    'bottom: 0 !important',
    'left: 0 !important',
    'width: 100% !important',
    'z-index: 999999 !important',
    'box-sizing: border-box',
    'background: rgba(30,20,50,0.95)',
    'border-top: 1px solid rgba(167,139,250,0.28)',
    'overflow: hidden',
    'height: 20px',
    'transition: height 0.3s ease',
    'cursor: pointer',
    'user-select: none',
    '-webkit-tap-highlight-color: transparent'
  ].join('; ');

  // ── Linha colapsada (sempre visível) ──────────────────────────────────────
  var collapsed = document.createElement('div');
  collapsed.id = 'mc-collapsed-line';
  collapsed.style.cssText = [
    'height: 20px',
    'display: flex',
    'align-items: center',
    'justify-content: center',
    'padding: 0 12px'
  ].join('; ');

  var collapsedText = document.createElement('span');
  collapsedText.id = 'mc-collapsed-text';
  collapsedText.textContent = '$labelCollapsed';
  collapsedText.style.cssText = [
    'font-size: 10px',
    'color: rgba(184,168,232,0.70)',
    'letter-spacing: 0.3px',
    'white-space: nowrap',
    'overflow: hidden',
    'text-overflow: ellipsis',
    'max-width: 100%'
  ].join('; ');

  collapsed.appendChild(collapsedText);

  // ── Painel expandido (visível apenas quando aberto) ───────────────────────
  var expanded = document.createElement('div');
  expanded.id = 'mc-expanded-panel';
  expanded.style.cssText = [
    'display: flex',
    'flex-direction: column',
    'align-items: center',
    'justify-content: center',
    'padding: 10px 16px 8px 16px',
    'gap: 6px'
  ].join('; ');

  var titleRow = document.createElement('div');
  titleRow.style.cssText = 'display: flex; align-items: center; gap: 6px';

  var iconSpan = document.createElement('span');
  iconSpan.textContent = '\\uD83D\\uDCDA';
  iconSpan.style.fontSize = '14px';

  var titleSpan = document.createElement('span');
  titleSpan.textContent = '$labelExpanded';
  titleSpan.style.cssText = [
    'font-size: 12px',
    'font-weight: 700',
    'color: #A78BFA',
    'letter-spacing: 0.2px'
  ].join('; ');

  titleRow.appendChild(iconSpan);
  titleRow.appendChild(titleSpan);

  var subSpan = document.createElement('div');
  subSpan.textContent = '$sublabel';
  subSpan.style.cssText = [
    'font-size: 9px',
    'color: rgba(184,168,232,0.60)',
    'letter-spacing: 0.5px'
  ].join('; ');

  var linkBtn = document.createElement('div');
  linkBtn.textContent = '$btnText';
  linkBtn.style.cssText = [
    'margin-top: 4px',
    'padding: 5px 18px',
    'background: rgba(167,139,250,0.15)',
    'border: 1px solid rgba(167,139,250,0.35)',
    'border-radius: 20px',
    'font-size: 11px',
    'font-weight: 600',
    'color: #C4B5FD',
    'cursor: pointer',
    'transition: background 0.15s ease'
  ].join('; ');

  expanded.appendChild(titleRow);
  expanded.appendChild(subSpan);
  expanded.appendChild(linkBtn);

  bar.appendChild(collapsed);
  bar.appendChild(expanded);
  document.body.appendChild(bar);

  // ── Toggle state ───────────────────────────────────────────────────────────
  var isOpen = false;

  function openBar() {
    isOpen = true;
    bar.style.height = '120px';
    collapsedText.textContent = '\\uD83D\\uDD3D $labelExpanded';
  }

  function closeBar() {
    isOpen = false;
    bar.style.height = '20px';
    collapsedText.textContent = '$labelCollapsed';
  }

  bar.addEventListener('click', function(e) {
    e.stopPropagation();
    if (isOpen) { closeBar(); } else { openBar(); }
  });

  // ── Link externo ──────────────────────────────────────────────────────────
  linkBtn.addEventListener('click', function(e) {
    e.stopPropagation();
    if (window.MedCasesChannel) {
      window.MedCasesChannel.postMessage('openSources');
    }
    setTimeout(closeBar, 300);
  });

  // ── Padding-bottom no body — evita que a barra cubra o último item ────────
  document.body.style.setProperty('padding-bottom', '20px', 'important');
})();
''';
}

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
      // O ColoredBox Flutter pai (0xFF0F091E) aparece atrás sem criar barra sólida.
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'MedCasesChannel',
        onMessageReceived: (msg) async {
          if (msg.message == 'openSources') {
            final uri = Uri.parse(_kSourcesUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) async {
          // Injeta CSS de reset ANTES do DOMContentLoaded — Wix não chega a
          // reservar safe-area-inset ou configurar momentum scroll.
          await _controller.runJavaScript(_kEarlyInjectJs);
        },
        onPageFinished: (_) async {
          await _controller.runJavaScript(_kInjectJs);
          await _controller.runJavaScript(_buildSourcesButtonJs(_isEs));
        },
      ))
      ..loadRequest(Uri.parse('$_kBaseUrl?lang=$langParam'));
  }

  @override
  Widget build(BuildContext context) {
    // ── topPadding via FlutterView — imune ao MediaQuery do shell ─────────────
    final view       = View.of(context);
    final topPadding = view.viewPadding.top / view.devicePixelRatio;

    // ── PADRÃO OURO: SafeArea(bottom:false) + Column + Expanded ──────────────
    //
    // Por que este layout elimina a barra escura:
    //
    // 1. SafeArea(top:true, bottom:false):
    //    • top:true  → recua o conteúdo abaixo da status bar do SO.
    //    • bottom:false → NÃO adiciona padding na base — o Expanded empurra
    //      a WebView até a borda física do vidro, incluindo a área da home bar.
    //    • Isso entrega à WKWebView um frame que toca a borda física,
    //      então o adjustedContentInset do iOS fica zerado automaticamente.
    //
    // 2. Column:
    //    • Filho 0: header fixo de (topPadding + 52) px.
    //    • Filho 1: Expanded → WebView ocupa TODO o espaço restante.
    //    • Sem Positioned, sem aritmética de bottomPadding, sem tampas.
    //
    // 3. WebView com Colors.transparent:
    //    • scrollView.backgroundColor = UIColor.clear.
    //    • O Scaffold.backgroundColor (0xFF0F091E) aparece atrás.
    //    • Impossível ver barra escura mesmo se o conteúdo não cobrir o fundo.
    //
    // IMPORTANTE: Não usar tampa Positioned no bottom — isso "encurtava" a
    // WebView visualmente (conteúdo HTML empurrado para cima pelo iOS) gerando
    // a falsa impressão de que a barra persistia.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F091E),
        body: SafeArea(
          top: false,   // gerenciado manualmente abaixo via topPadding
          bottom: false, // ← CRÍTICO: deixa a WebView tocar a borda física
          child: Column(
            children: [

              // ── CAMADA 0 — Header gradiente ──────────────────────────────
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

              // ── CAMADA 1 — WebView: ocupa todo o espaço restante ─────────
              // Expanded → sem bottom fixo, sem cálculo de padding.
              // A WKWebView recebe um frame que vai até a borda física do vidro.
              Expanded(
                child: WebViewWidget(controller: _controller),
              ),

            ],
          ),
        ),
      ),
    );
  }
}
