import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../providers/app_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// URL base — ?lang=pt ou ?lang=es é injetado em initState() conforme AppProvider
// ─────────────────────────────────────────────────────────────────────────────
const _kBaseUrl = 'https://www.medcasescalcu.com';

// ─────────────────────────────────────────────────────────────────────────────
// URL de fontes acadêmicas — abre no browser externo
// ─────────────────────────────────────────────────────────────────────────────
const _kSourcesUrl = 'https://www.promedcases.com/fontes-e-referencias';

// ─────────────────────────────────────────────────────────────────────────────
// JS base injetado no onPageFinished:
//  A. viewport-fit=cover → conteúdo sangra abaixo da Home Bar
//  B. padding-top: env(safe-area-inset-top) → não fica atrás do header
//  C. padding-bottom: env(safe-area-inset-bottom) → sem gap na base
//  D. Remove margens horizontais desnecessárias da Wix
// ─────────────────────────────────────────────────────────────────────────────
const _kInjectJs = r"""
(function() {
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
  document.body.style.setProperty('padding-top',    'env(safe-area-inset-top)',    'important');
  document.body.style.setProperty('padding-bottom', 'env(safe-area-inset-bottom)', 'important');
  document.body.style.setProperty('margin',         '0',                            'important');
  document.body.style.setProperty('padding-left',   '0');
  document.body.style.setProperty('padding-right',  '0');
  document.documentElement.style.setProperty('overflow-x', 'hidden');
  document.documentElement.style.setProperty('height', '100%');
  document.body.style.setProperty('min-height', '100%');
})();
""";

// ─────────────────────────────────────────────────────────────────────────────
// JS que injeta o botão "Ver Fuentes Académicas" no FINAL do scroll da página.
// Substitui a barra fixa inferior — aparece somente ao rolar até o fim,
// liberando 100% do espaço útil de leitura.
// O botão chama window.MedCasesOpenSources() que o Flutter intercepta via
// JavascriptChannel para abrir a URL no browser externo (sem dart:io).
// ─────────────────────────────────────────────────────────────────────────────
String _buildSourcesButtonJs(bool isEs) {
  final label = isEs
      ? 'Ver Fuentes Académicas'
      : 'Ver Fontes Acadêmicas';
  final sublabel = isEs
      ? 'AHA · ACC · WHO · PubMed · UpToDate'
      : 'AHA · ACC · WHO · PubMed · UpToDate';

  return """
(function() {
  if (document.getElementById('medcases-sources-btn')) return;

  var btn = document.createElement('div');
  btn.id = 'medcases-sources-btn';
  btn.style.cssText = [
    'display:flex',
    'flex-direction:column',
    'align-items:center',
    'justify-content:center',
    'gap:6px',
    'margin:32px 20px 40px 20px',
    'padding:14px 20px',
    'background:rgba(167,139,250,0.08)',
    'border:1px solid rgba(167,139,250,0.25)',
    'border-radius:12px',
    'cursor:pointer',
    'user-select:none',
    '-webkit-tap-highlight-color:transparent',
  ].join(';');

  var iconRow = document.createElement('div');
  iconRow.style.cssText = 'display:flex;align-items:center;gap:8px';

  var icon = document.createElement('span');
  icon.textContent = '📚';
  icon.style.fontSize = '16px';

  var title = document.createElement('span');
  title.textContent = '$label';
  title.style.cssText = [
    'font-size:13px',
    'font-weight:700',
    'color:#A78BFA',
    'letter-spacing:0.2px',
  ].join(';');

  iconRow.appendChild(icon);
  iconRow.appendChild(title);

  var sub = document.createElement('span');
  sub.textContent = '$sublabel';
  sub.style.cssText = [
    'font-size:10px',
    'color:rgba(184,168,232,0.7)',
    'letter-spacing:0.5px',
  ].join(';');

  btn.appendChild(iconRow);
  btn.appendChild(sub);

  btn.addEventListener('click', function() {
    btn.style.background = 'rgba(167,139,250,0.18)';
    setTimeout(function() {
      btn.style.background = 'rgba(167,139,250,0.08)';
    }, 200);
    if (window.MedCasesChannel) {
      window.MedCasesChannel.postMessage('openSources');
    }
  });

  document.body.appendChild(btn);
})();
""";
}

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
      ..setUserAgent('Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) MedCasesApp/6.1.0')
      // Fundo escuro desde o primeiro frame — elimina flash branco enquanto a Wix carrega
      ..setBackgroundColor(const Color(0xFF0F091E))
      // Canal JS → Flutter: intercepta clique no botão de fontes
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
          // 1. Aplica viewport/padding fixes
          await _controller.runJavaScript(_kInjectJs);
          // 2. Injeta botão de fontes no final do scroll
          await _controller.runJavaScript(_buildSourcesButtonJs(_isEs));
        },
      ))
      ..loadRequest(Uri.parse('$_kBaseUrl?lang=$langParam'));
  }

  @override
  Widget build(BuildContext context) {
    // Dimensões físicas reais do display — ignora qualquer inset do framework
    final mq         = MediaQuery.of(context);
    final screenSize  = mq.size;
    final topPadding  = mq.padding.top;

    // AnnotatedRegion: status bar icons brancos sem AppBar nativo
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: Colors.transparent, // transparente: sem fundo sólido que vaze para fora da Stack
        child: SizedBox(
          // Força o SizedBox a ter exatamente as dimensões do display físico.
          // Isso evita que a bottom nav bar do app "roube" altura da Stack.
          width:  screenSize.width,
          height: screenSize.height,
          child: Stack(
            // clipBehavior none: widgets Positioned podem sair dos bounds sem serem cortados
            clipBehavior: Clip.none,
            children: [

              // ── CAMADA 0 — WebView: 100% do display físico ─────────────────
              // Positioned.fill dentro de SizedBox(screenSize) = pixel perfeito
              Positioned.fill(
                child: WebViewWidget(controller: _controller),
              ),

              // ── CAMADA 1 — Header roxo com gradiente ───────────────────────
              // Overlay sobre a WebView, fixo no topo, sem subtrair altura dela
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
                            'CALCULADORA CLÍNICA',
                            style: TextStyle(
                              fontSize:     16,
                              fontWeight:   FontWeight.w800,
                              color:        Colors.white,
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
