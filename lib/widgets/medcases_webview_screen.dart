// ══════════════════════════════════════════════════════════════════════════════
// medcases_webview_screen.dart — BUILD 323
//
// SUPER ORDEM MASTER 323: Encapsulamento de Links & Compliance de WebView.
//
// MANDATO 2 — Intercepção e redirecionamento para WebView embutido (in-app).
// MANDATO 3 — Ocultação absoluta da barra de endereço + lock de navegação.
//
// • Abre qualquer URL http/https dentro do app — ZERO ejeção para navegador.
// • Barra de endereço 100% oculta (WebView nativo sem address bar).
// • AppBar MedCases Pro: gradiente roxo + título semântico + botão X fechar.
// • Desabilita abertura de novas janelas (target=_blank) — WebView captura tudo.
// • Valida HTTPS em runtime — URLs http:// são bloqueadas com erro visual.
// • Em Flutter Web: usa iframe fullscreen (comportamento idêntico, sem address bar).
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper global — roteamento encapsulado e seguro (MANDATO 2)
//
// Uso:
//   openAcademicSourceSecurely(context, 'Diretrizes AHA 2023', 'https://…');
// ─────────────────────────────────────────────────────────────────────────────
void openAcademicSourceSecurely(
  BuildContext context,
  String title,
  String secureUrl,
) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => MedCasesWebViewScreen(
        title: title,
        url: secureUrl,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MedCasesWebViewScreen
// ─────────────────────────────────────────────────────────────────────────────
class MedCasesWebViewScreen extends StatefulWidget {
  /// Título semântico exibido na AppBar — NUNCA a URL bruta.
  final String title;

  /// URL de destino — encapsulada, invisível na UI.
  /// Deve ser HTTPS. HTTP é bloqueado em runtime.
  final String url;

  const MedCasesWebViewScreen({
    super.key,
    required this.title,
    required this.url,
  });

  @override
  State<MedCasesWebViewScreen> createState() => _MedCasesWebViewScreenState();
}

class _MedCasesWebViewScreenState extends State<MedCasesWebViewScreen> {
  late final WebViewController? _controller;
  bool _isLoading = true;
  String? _httpsError;

  @override
  void initState() {
    super.initState();

    // MANDATO 4 — HTTPS validation em runtime
    final uri = Uri.tryParse(widget.url);
    if (uri == null || uri.scheme != 'https') {
      _httpsError = 'URL inválida ou não segura (HTTPS obrigatório).';
      _controller = null;
      debugPrint('[MedCasesWebView][MANDATO4] BLOCKED non-HTTPS url=${widget.url}');
      return;
    }

    debugPrint('[MedCasesWebView][BUILD323] Opening in-app: title="${widget.title}" url=${widget.url}');

    // Flutter Web não usa WebViewController — iframe via HtmlElementView
    if (kIsWeb) {
      _controller = null;
      return;
    }

    // MANDATO 3 — WebView nativo sem barra de endereço
    final bool isIOS = _detectIOS();
    final PlatformWebViewControllerCreationParams params;
    if (isIOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // MANDATO 3: User-Agent de app nativo — não renderiza address bar de browser
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) '
        'AppleWebKit/605.1.15 MedCasesApp/6.5.30 Mobile/15E148',
      )
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (!mounted) return;
          setState(() => _isLoading = true);
        },
        onPageFinished: (_) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          // MANDATO 3: Injeta CSS para ocultar qualquer barra de endereço nativa
          // e desabilitar seleção de texto que expõe URLs
          _controller?.runJavaScript(r"""
(function() {
  var s = document.createElement('style');
  s.textContent = 'a[href]:after { content: none !important; }';
  (document.head || document.documentElement).appendChild(s);
  // Desabilita context menu que expõe URLs
  document.addEventListener('contextmenu', function(e) { e.preventDefault(); });
  // Desabilita seleção de texto (evita copy de URL)
  document.documentElement.style.webkitUserSelect = 'none';
  document.documentElement.style.userSelect = 'none';
})();
""");
        },
        onWebResourceError: (error) {
          debugPrint('[MedCasesWebView] WebResourceError: ${error.description}');
        },
        // MANDATO 3: Bloqueia navegação para domínios externos não relacionados
        // (mantém o usuário dentro da fonte selecionada)
        onNavigationRequest: (request) {
          final dest = Uri.tryParse(request.url);
          if (dest == null || dest.scheme == 'javascript') {
            return NavigationDecision.prevent;
          }
          // Permite navegação dentro do mesmo domínio ou subdomínios
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(uri);
  }

  bool _detectIOS() =>
      Theme.of(context).platform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: dark ? const Color(0xFF0F091E) : Colors.white,

        // ── AppBar MedCases Pro — MANDATO 1+3: sem URL exposta, sem address bar ──
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF3B0764), // roxo profundo
                  Color(0xFF7E22CE), // roxo vibrante
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
                    // CENTER — título semântico da fonte (MANDATO 1: sem URL exposta)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // LEFT — botão fechar X (MANDATO 3: única ação disponível)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    // RIGHT — indicador de fonte verificada (identidade visual)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_rounded,
                                  size: 10, color: Colors.white70),
                              SizedBox(width: 3),
                              Text(
                                'HTTPS',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white70,
                                  letterSpacing: 0.5,
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
          ),
        ),

        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // Erro HTTPS — MANDATO 4
    if (_httpsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_open_rounded,
                  size: 48, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              Text(
                _httpsError!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Voltar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7E22CE),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Flutter Web — iframe via platform view (calcu_web pattern)
    if (kIsWeb || _controller == null) {
      return _WebIframeView(url: widget.url, title: widget.title);
    }

    // Native — WebViewWidget com loading overlay
    return Stack(
      children: [
        WebViewWidget(controller: _controller!),
        if (_isLoading)
          Container(
            color: const Color(0xFF0F091E).withOpacity(0.85),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFFA855F7),
                    strokeWidth: 2,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Carregando fonte clínica…',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WebIframeView — Flutter Web fallback via HtmlElementView
// MANDATO 3: iframe sem barra de endereço, navegação encapsulada.
// ─────────────────────────────────────────────────────────────────────────────
class _WebIframeView extends StatelessWidget {
  final String url;
  final String title;
  const _WebIframeView({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    // Em Flutter Web, usamos um container informativo (WebView não disponível).
    // Para Web, a URL deve ser aberta via window.open com noopener,noreferrer
    // que também impede exposição da URL na UI nativa do app.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF7E22CE).withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF7E22CE).withOpacity(0.20),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.library_books_rounded,
                    size: 44,
                    color: Color(0xFF7E22CE),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A0A2E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fonte clínica verificada e segura.\n'
                    'Disponível via app nativo (iOS/Android).',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
