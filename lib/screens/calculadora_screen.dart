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
// JS BASE — viewport + margens
//
// REGRAS:
//  • NÃO definir height/min-height no <html> ou <body> — isso corta o scroll
//    em páginas Wix e impede que o conteúdo abaixo do viewport seja acessível.
//  • padding-top garante que o conteúdo não fique escondido atrás do header.
//  • padding-bottom usa safe-area para não cortar conteúdo na home bar do iPhone.
//  • overflow-x: hidden evita scroll lateral indesejado.
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

  // ── B. Body/HTML: zera margens e remove height fixo ──────────────────────
  document.body.style.setProperty('padding-top',    'env(safe-area-inset-top)', 'important');
  document.body.style.setProperty('padding-bottom', '0px',                      'important');
  document.body.style.setProperty('margin',         '0',                        'important');
  document.body.style.setProperty('padding-left',   '0');
  document.body.style.setProperty('padding-right',  '0');
  document.documentElement.style.setProperty('overflow-x', 'hidden');
  document.documentElement.style.removeProperty('height');
  document.body.style.removeProperty('height');
  document.body.style.removeProperty('min-height');
  document.body.style.removeProperty('max-height');
  document.body.style.removeProperty('overflow');
  document.body.style.removeProperty('overflow-y');

  // ── C. Remove footer e barra Wix ─────────────────────────────────────────
  // IDs e classes conhecidos que o Wix injeta como rodapé/barra inferior.
  // Cada seletor é tentado; se não existir ainda, o MutationObserver abaixo
  // re-aplicará quando o Wix terminar de renderizar via React/JavaScript.
  var WIX_FOOTER_SELECTORS = [
    '#SITE_FOOTER',           // footer principal do Wix
    '#SITE_FOOTER_WRAPPER',   // wrapper do footer
    '#WIX_ADS',               // barra de anúncio "made with Wix"
    '#wix-ads',               // variante minúscula
    '.wix-ads',               // classe alternativa
    '[data-testid="wix-ads"]',
    '[id^="WIX_ADS"]',
    'footer',                 // tag <footer> genérica que o Wix usa
    '.site-footer',
    '.footer-wrapper',
    '[class*="footer"]',      // qualquer classe com "footer"
    '[id*="footer"]',         // qualquer id com "footer"
    '#SCROLL_TO_TOP',         // botão "scroll to top" do Wix
    '.scrollToTop',
    '[data-testid="scrollToTop"]',
  ];

  function hideWixJunk() {
    WIX_FOOTER_SELECTORS.forEach(function(sel) {
      try {
        document.querySelectorAll(sel).forEach(function(el) {
          el.style.setProperty('display',    'none',  'important');
          el.style.setProperty('height',     '0px',   'important');
          el.style.setProperty('min-height', '0px',   'important');
          el.style.setProperty('max-height', '0px',   'important');
          el.style.setProperty('overflow',   'hidden','important');
          el.style.setProperty('visibility', 'hidden','important');
          el.style.setProperty('margin',     '0',     'important');
          el.style.setProperty('padding',    '0',     'important');
          el.style.setProperty('opacity',    '0',     'important');
          el.style.setProperty('pointer-events', 'none', 'important');
        });
      } catch(e) {}
    });

    // Também zera qualquer margin-bottom residual do container de páginas
    var pageContainers = [
      '#PAGES_CONTAINER',
      '#masterPage',
      '#site-root',
      '[data-mesh-id="PAGES_CONTAINERinlineContent"]',
    ];
    pageContainers.forEach(function(sel) {
      try {
        document.querySelectorAll(sel).forEach(function(el) {
          el.style.setProperty('margin-bottom',  '0', 'important');
          el.style.setProperty('padding-bottom', '0', 'important');
        });
      } catch(e) {}
    });
  }

  // Executar imediatamente (para elementos já no DOM)
  hideWixJunk();

  // ── D. MutationObserver — re-aplica quando Wix re-renderizar ─────────────
  // O Wix é um SPA: elementos são inseridos dinamicamente após o DOMContentLoaded.
  // O observer garante que qualquer footer injetado depois também seja removido.
  var _mcObserver = new MutationObserver(function(mutations) {
    var shouldRun = false;
    mutations.forEach(function(m) {
      if (m.addedNodes.length > 0) shouldRun = true;
    });
    if (shouldRun) hideWixJunk();
  });

  _mcObserver.observe(document.body || document.documentElement, {
    childList: true,
    subtree:   true,
  });

  // Para após 8 segundos — Wix termina de renderizar bem antes disso
  setTimeout(function() {
    _mcObserver.disconnect();
    // Última passagem garantida
    hideWixJunk();
  }, 8000);

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
//  • Padding-bottom = env(safe-area-inset-bottom) — respeita home bar do iPhone.
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
    '-webkit-tap-highlight-color: transparent',
    'padding-bottom: env(safe-area-inset-bottom)'
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
    if (isOpen) {
      closeBar();
    } else {
      openBar();
    }
  });

  // ── Link externo — não fecha a barra, apenas abre fontes ──────────────────
  linkBtn.addEventListener('click', function(e) {
    e.stopPropagation();
    if (window.MedCasesChannel) {
      window.MedCasesChannel.postMessage('openSources');
    }
    // Fechar após abrir o link
    setTimeout(closeBar, 300);
  });

  // ── Padding dinâmico no body para o conteúdo não ficar atrás da barra ─────
  // A barra fixa de 20px poderia esconder o último item da página.
  // Adicionamos 20px de padding-bottom ao body para compensar.
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
      // Fundo escuro no primeiro frame — elimina flash branco durante carga
      ..setBackgroundColor(const Color(0xFF0F091E))
      // Canal JS → Flutter: intercepta clique no botão de fontes acadêmicas
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
        onPageFinished: (_) async {
          // Passo 1: corrige viewport e remove height fixo que trava o scroll
          await _controller.runJavaScript(_kInjectJs);
          // Passo 2: injeta botão discreto no final do DOM (flow natural)
          await _controller.runJavaScript(_buildSourcesButtonJs(_isEs));
        },
      ))
      ..loadRequest(Uri.parse('$_kBaseUrl?lang=$langParam'));
  }

  @override
  Widget build(BuildContext context) {
    // ── topPadding via FlutterView — imune a qualquer MediaQuery pai ──────────
    // View.of(context).viewPadding.top = altura real da status bar em px físicos.
    // Dividir pelo dpr converte para logical pixels sem depender do MediaQuery
    // que o shell/SafeArea pode ter alterado.
    final view       = View.of(context);
    final topPadding = view.viewPadding.top / view.devicePixelRatio;

    // ── Tela cheia garantida pelo rootNavigator ───────────────────────────────
    // Esta tela é aberta com Navigator.of(context, rootNavigator: true), então
    // ocupa o display completo acima do shell — sem restrição de bottom nav.
    // SizedBox.expand + Positioned.fill = WebView preenche 100% sem aritmética.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        // Fundo escuro em toda a área — elimina qualquer flash ou borda visível.
        color: const Color(0xFF0F091E),
        child: SizedBox.expand(
          child: Stack(
            children: [

              // ── CAMADA 0 — WebView: ocupa tudo abaixo do header ───────────
              // top = altura do header (status bar + barra de título).
              // bottom = 0 → sangra até a borda física do vidro.
              Positioned(
                top:    topPadding + 52,
                left:   0,
                right:  0,
                bottom: 0,
                child:  WebViewWidget(controller: _controller),
              ),

              // ── CAMADA 1 — Header gradiente (status bar + título) ─────────
              // Único overlay Flutter — cobre apenas o topo.
              Positioned(
                top:   0,
                left:  0,
                right: 0,
                child: Container(
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
              ),

            ],
          ),
        ),
      ),
    );
  }
}
