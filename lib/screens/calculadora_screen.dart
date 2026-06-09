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
// JS DO BOTÃO DE FONTES
//
// REGRAS ESTRITAS:
//  • position: relative  — NUNCA fixed ou absolute
//  • display: block      — elemento de bloco normal no flow do HTML
//  • margin: 40px auto   — centralizado, com respiro antes e depois
//  • width: 90%          — responsivo
//  • Aparece apenas ao rolar até o FIM da página — zero sobreposição
//  • document.body.appendChild() — último elemento do DOM, após todo conteúdo
// ─────────────────────────────────────────────────────────────────────────────
String _buildSourcesButtonJs(bool isEs) {
  final label = isEs
      ? 'Ver Fuentes Acad\u00e9micas'
      : 'Ver Fontes Acad\u00eamicas';
  final sublabel = 'AHA \u00b7 ACC \u00b7 WHO \u00b7 PubMed \u00b7 UpToDate';

  // Usa string concatenation simples para evitar problemas com interpolação Dart
  // dentro de blocos JS com aspas aninhadas.
  return '''
(function() {
  if (document.getElementById('medcases-sources-btn')) return;

  var btn = document.createElement('div');
  btn.id = 'medcases-sources-btn';

  // position: relative — fluxo normal do HTML, NUNCA fixed/absolute/sticky
  // O botão fica literalmente no final do DOM, após todo o conteúdo da Wix.
  // Só aparece quando o médico rola até o fim — 100% da tela útil preservada.
  btn.style.cssText = [
    'display: block',
    'position: relative',
    'width: 90%',
    'margin: 40px auto 48px auto',
    'padding: 14px 20px',
    'background: rgba(167,139,250,0.07)',
    'border: 1px solid rgba(167,139,250,0.22)',
    'border-radius: 12px',
    'text-align: center',
    'cursor: pointer',
    'user-select: none',
    '-webkit-tap-highlight-color: transparent',
    'box-sizing: border-box'
  ].join('; ');

  var iconLine = document.createElement('div');
  iconLine.style.cssText = 'display: flex; align-items: center; justify-content: center; gap: 8px; margin-bottom: 4px';

  var icon = document.createElement('span');
  icon.textContent = '\\uD83D\\uDCDA'; // 📚
  icon.style.fontSize = '15px';

  var title = document.createElement('span');
  title.textContent = '$label';
  title.style.cssText = 'font-size: 13px; font-weight: 700; color: #A78BFA; letter-spacing: 0.2px';

  iconLine.appendChild(icon);
  iconLine.appendChild(title);

  var sub = document.createElement('div');
  sub.textContent = '$sublabel';
  sub.style.cssText = 'font-size: 10px; color: rgba(184,168,232,0.65); letter-spacing: 0.5px; margin-top: 2px';

  btn.appendChild(iconLine);
  btn.appendChild(sub);

  btn.addEventListener('click', function() {
    btn.style.background = 'rgba(167,139,250,0.16)';
    setTimeout(function() { btn.style.background = 'rgba(167,139,250,0.07)'; }, 180);
    if (window.MedCasesChannel) {
      window.MedCasesChannel.postMessage('openSources');
    }
  });

  // Append como ÚLTIMO filho do body — posição natural no flow do documento.
  // Nunca sobrepõe nada; só visível após scroll completo.
  document.body.appendChild(btn);
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
    final mq         = MediaQuery.of(context);
    final screenSize = mq.size;
    final topPadding = mq.padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.transparent,
        child: SizedBox(
          // SizedBox com dimensões físicas reais do display.
          // Impede que a bottom nav bar do shell "roube" altura da WebView.
          width:  screenSize.width,
          height: screenSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [

              // ── CAMADA 0 — WebView ocupa 100% do display físico ─────────
              // Positioned.fill = pixel perfect, sem padding artificial.
              // A WebView tem scroll próprio interno — não há nada sobreposto
              // na base da tela que tire espaço ou bloqueie o conteúdo.
              Positioned.fill(
                child: WebViewWidget(controller: _controller),
              ),

              // ── CAMADA 1 — Header roxo (gradiente) — topo apenas ────────
              // Único overlay autorizado: cobre apenas o topo (status bar + título).
              // Base da tela: completamente livre — 100% para a WebView.
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

              // ── BASE DA TELA: VAZIA ──────────────────────────────────────
              // Nenhum widget, nenhuma barra, nenhum overlay.
              // O médico tem 100% do espaço abaixo do header para a WebView.

            ],
          ),
        ),
      ),
    );
  }
}
