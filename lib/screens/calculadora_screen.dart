import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/app_provider.dart';

// URLs por idioma — substituir pelos caminhos reais da Wix antes de publicar
const _kUrlPt = 'https://www.promedcases.com/sua-url-secretablank';
const _kUrlEs = 'https://www.promedcases.com/sua-url-secretablank-es';

// JS injetado após onPageFinished:
// 1. Força viewport-fit=cover via meta tag (caso a Wix não envie)
// 2. Remove qualquer padding/margin do body que limite a altura
// 3. Define --safe-area-bottom para que o conteúdo Wix respeite a Home Bar
//    sem deixar espaço morto — o próprio site rola até lá embaixo.
const _kViewportJs = r"""
(function() {
  // 1 — viewport-fit=cover: permite que o conteúdo sangre abaixo da Home Bar
  var meta = document.querySelector('meta[name="viewport"]');
  if (meta) {
    var c = meta.getAttribute('content') || '';
    if (!c.includes('viewport-fit')) {
      meta.setAttribute('content', c + ', viewport-fit=cover');
    }
  } else {
    var m = document.createElement('meta');
    m.name = 'viewport';
    m.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
    document.head.appendChild(m);
  }

  // 2 — Remove padding/margin do body que cria área morta na base
  document.documentElement.style.setProperty('height', '100%');
  document.body.style.setProperty('min-height', '100%');
  document.body.style.setProperty('margin', '0');
  document.body.style.setProperty('padding-bottom', 'env(safe-area-inset-bottom)');

  // 3 — Remove barreiras de overflow que encurtam a página
  document.documentElement.style.setProperty('overflow-x', 'hidden');
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

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('MedCasesApp/6.1.0')
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          // Injeta viewport-fit=cover + remove área morta inferior
          _controller.runJavaScript(_kViewportJs);
        },
      ))
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    // Altura do status bar — para o header sobreposto não colidir com o relógio
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      // extendBody + extendBodyBehindAppBar → body vai de (0,0) até a borda
      // física inferior do display, passando por baixo da Home Bar do iOS.
      // O WebView ocupa cada pixel do vidro.
      backgroundColor: const Color(0xFF0F091E),
      extendBody: true,
      extendBodyBehindAppBar: true,

      // Sem AppBar nativo — ele consome altura do body e cria o espaço morto.
      // O header roxo fica sobreposto via Stack, transparente para o layout.
      body: Stack(
        children: [
          // ── WebView: ocupa 100% do Scaffold (edge-to-edge) ──────────────
          const Positioned.fill(
            child: SizedBox.expand(),
          ),
          Positioned.fill(
            child: WebViewWidget(controller: _controller),
          ),

          // ── Header roxo sobreposto — não consome altura do WebView ───────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              // Status bar + 52pt do header visual
              height: topPadding + 52,
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
                    // Botão voltar
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // Título
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
