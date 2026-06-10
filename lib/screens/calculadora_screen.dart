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
  // ── Viewport: viewport-fit=cover para tela cheia no iOS ──────────────────
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

  // ── Body: apenas margens e overflow — SEM height nem min-height ──────────
  // Definir height:100% no body/html corta o scroll em páginas Wix:
  // o conteúdo abaixo do viewport fica inacessível e o botão de fontes
  // nunca aparece. Deixar o body crescer naturalmente com o conteúdo.
  document.body.style.setProperty('padding-top',    'env(safe-area-inset-top)', 'important');
  document.body.style.setProperty('padding-bottom', '0px',                      'important');
  document.body.style.setProperty('margin',         '0',                        'important');
  document.body.style.setProperty('padding-left',   '0');
  document.body.style.setProperty('padding-right',  '0');
  document.documentElement.style.setProperty('overflow-x', 'hidden');

  // Remove height fixo que a Wix às vezes injeta e que impede scroll
  document.documentElement.style.removeProperty('height');
  document.body.style.removeProperty('height');
  document.body.style.removeProperty('min-height');
  document.body.style.removeProperty('max-height');
  document.body.style.removeProperty('overflow');
  document.body.style.removeProperty('overflow-y');
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
    // ── topPadding: lido do MediaQuery ANTES de remover insets ───────────────
    // Precisamos do valor real da status bar para posicionar o header.
    final topPadding = MediaQuery.of(context).padding.top;

    // ── ESTRATÉGIA TELA-CHEIA ────────────────────────────────────────────────
    // O shell pai (bottom nav + SafeArea) injeta padding.bottom no MediaQuery
    // E reduz o espaço disponível para este widget — criando a faixa escura.
    //
    // Solução em 3 camadas:
    //  1. MediaQuery.removePadding(removeBottom: true) → zera o inset inferior
    //     que o shell/SafeArea impõe, dando ao Stack toda a altura disponível.
    //  2. Scaffold(extendBody: true, resizeToAvoidBottomInset: false) →
    //     estica o body por baixo de qualquer barra de sistema.
    //  3. SizedBox.expand() → o Stack preenche TODO o espaço concedido.
    //
    // O JS injetado na WebView já cuida do env(safe-area-inset-bottom) do iOS,
    // portanto NÃO precisamos que o Flutter proteja o rodapé aqui.
    return MediaQuery.removePadding(
      context:      context,
      removeBottom: true,   // remove inset inferior → WebView sangra até a borda
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          // extendBody: true  → body escorre por baixo de BottomNavigationBar
          // extendBodyBehindAppBar: true → sem AppBar nativa, mas boa prática
          // resizeToAvoidBottomInset: false → teclado não desloca o layout
          backgroundColor:              const Color(0xFF0F091E),
          extendBody:                   true,
          extendBodyBehindAppBar:        true,
          resizeToAvoidBottomInset:      false,
          body: SizedBox.expand(
            // SizedBox.expand preenche TODA a área concedida pelo Scaffold
            // após o removePadding — sem deixar nenhum espaço residual.
            child: Stack(
              clipBehavior: Clip.none,
              children: [

                // ── CAMADA 0 — WebView preenche tela inteira ──────────────
                // Positioned.fill + SizedBox.expand = pixel perfect até a
                // borda física inferior do vidro, sem faixa escura.
                Positioned.fill(
                  child: WebViewWidget(controller: _controller),
                ),

                // ── CAMADA 1 — Header roxo (gradiente) — topo apenas ──────
                // Único overlay Flutter: status bar + título.
                // Todo o resto da tela pertence à WebView.
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

                // ── BASE DA TELA: VAZIA ────────────────────────────────────
                // Zero widgets Flutter abaixo do header.
                // A barra retrátil de fontes vive no DOM JS (position:fixed).

              ],
            ),
          ),
        ),
      ),
    );
  }
}
