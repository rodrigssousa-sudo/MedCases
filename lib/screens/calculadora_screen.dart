import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../providers/app_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// URLs por idioma — substituir pelos paths reais da Wix antes de publicar
// ─────────────────────────────────────────────────────────────────────────────
const _kUrlPt = 'https://www.promedcases.com/sua-url-secretablank';
const _kUrlEs = 'https://www.promedcases.com/sua-url-secretablank-es';

// ─────────────────────────────────────────────────────────────────────────────
// JS injetado no onPageFinished — resolve TRÊS problemas do WKWebView/Wix:
//
//  A. viewport-fit=cover  → conteúdo sangra abaixo da Home Bar (sem gap)
//  B. padding-top: env(safe-area-inset-top)  → topo da página NÃO fica
//     escondido atrás do header flutuante (Dynamic Island / notch)
//  C. padding-bottom: env(safe-area-inset-bottom)  → conteúdo rola até a
//     Home Bar sem área morta
//  D. Remove margin horizontal da Wix que desperdiça colunas laterais
// ─────────────────────────────────────────────────────────────────────────────
const _kInjectJs = r"""
(function() {
  // A — viewport-fit=cover
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

  // B — padding-top dinâmico: respeita notch/Dynamic Island SEM esconder
  //     o topo da página atrás do header flutuante do Flutter
  document.body.style.setProperty(
    'padding-top', 'env(safe-area-inset-top)', 'important'
  );

  // C — padding-bottom: Home Bar não cria gap branco/escuro
  document.body.style.setProperty(
    'padding-bottom', 'env(safe-area-inset-bottom)', 'important'
  );

  // D — remove margens horizontais que encurtam o conteúdo Wix
  document.body.style.setProperty('margin',    '0', 'important');
  document.body.style.setProperty('padding-left',  '0');
  document.body.style.setProperty('padding-right', '0');
  document.documentElement.style.setProperty('overflow-x', 'hidden');
  document.documentElement.style.setProperty('height', '100%');
  document.body.style.setProperty('min-height', '100%');
})();
""";

class CalculadoraScreen extends StatefulWidget {
  const CalculadoraScreen({super.key});

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    final lang = context.read<AppProvider>().lang;
    final url  = lang == 'es' ? _kUrlEs : _kUrlPt;

    // ── iOS: WebKitWebViewControllerCreationParams ──────────────────────────
    // Ativa cache nativo do WKWebView (persistido pelo iOS automaticamente).
    // allowsInlineMediaPlayback: true  → vídeos/áudios embutidos nas calcs
    // mediaTypesRequiringUserAction: {} → reprodução automática sem tap
    // O WKWebsiteDataStore padrão (não-efêmero) persiste cookies, localStorage
    // e cache de disco — assets pesados da Wix não são re-baixados em cada abertura.
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
      ..setUserAgent('MedCasesApp/6.1.0')
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          // Injeção CSS/JS logo após o DOM estar pronto:
          // viewport-fit + safe-area paddings + remove margens Wix
          _controller.runJavaScript(_kInjectJs);
        },
      ))
      // loadRequest IMEDIATO — sem delay artificial, sem Timer, sem Future
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    // topPadding = altura do status bar / Dynamic Island (pts, não px)
    // Usado para posicionar o header flutuante sem colidir com o relógio.
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFF0F091E),
      // extendBody → body passa por baixo da Home Bar (sem gap escuro)
      // extendBodyBehindAppBar → body começa em (0,0), não abaixo do AppBar
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── WebView: ocupa CADA PIXEL do display ─────────────────────────
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),

          // ── Header roxo sobreposto — NÃO consome altura do WebView ────────
          // Fica em cima do WebView via Stack.
          // O JS injetado adiciona padding-top = env(safe-area-inset-top) ao
          // body HTML → o conteúdo Wix começa abaixo deste header, nunca fica
          // escondido atrás dele.
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: topPadding + 52, // status bar + 52pt do header visual
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
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
    );
  }
}
