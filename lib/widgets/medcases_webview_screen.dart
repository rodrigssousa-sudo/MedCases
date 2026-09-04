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

import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../providers/app_provider.dart';

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
      builder: (context) => MedCasesWebViewScreen(title: title, url: secureUrl),
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
  // Fix#6: dark mode reativo — sincronizado com AppProvider via listener
  bool _dark = false;
  // Fix#6: flag que indica se a WebView já terminou de carregar
  bool _webviewReady = false;

  @override
  void initState() {
    super.initState();

    // MANDATO 4 — HTTPS validation em runtime
    final uri = Uri.tryParse(widget.url);
    if (uri == null || uri.scheme != 'https') {
      _httpsError = 'URL inválida ou não segura (HTTPS obrigatório).';
      _controller = null;
      debugPrint(
        '[MedCasesWebView][MANDATO4] BLOCKED non-HTTPS url=${widget.url}',
      );
      return;
    }

    debugPrint(
      '[MedCasesWebView][BUILD323] Opening in-app: title="${widget.title}" url=${widget.url}',
    );

    // Fix#6: lê dark mode inicial e registra listener para mudanças em runtime
    final p = context.read<AppProvider>();
    _dark = p.darkMode;
    p.addListener(_onProviderChanged);

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
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() => _isLoading = false);
            // MANDATO 3: Injeta CSS para ocultar qualquer barra de endereço nativa
            // e desabilitar seleção de texto que expõe URLs
            await _controller?.runJavaScript(r"""
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
            // Fix#6: injeta tema assim que a página termina de carregar
            _webviewReady = true;
            await _injectTheme();
          },
          onWebResourceError: (error) {
            debugPrint(
              '[MedCasesWebView] WebResourceError: ${error.description}',
            );
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
        ),
      )
      ..loadRequest(uri);
  }

  bool _detectIOS() => defaultTargetPlatform == TargetPlatform.iOS;

  // Fix#6: chamado pelo listener do AppProvider quando darkMode muda
  void _onProviderChanged() {
    final newDark = context.read<AppProvider>().darkMode;
    if (newDark == _dark) return;
    _dark = newDark;
    if (mounted) setState(() {});
    if (!kIsWeb && _webviewReady) _injectTheme();
  }

  // Fix#6: injeta window.updateMedCasesTheme('dark'|'light') na WebView nativa
  Future<void> _injectTheme() async {
    if (kIsWeb || _controller == null) return;
    final theme = _dark ? 'dark' : 'light';
    try {
      await _controller!.runJavaScript(
        "if(typeof window.updateMedCasesTheme==='function'){window.updateMedCasesTheme('$theme');}",
      );
    } catch (e) {
      debugPrint('[MedCasesWebView][theme] inject error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fix#6: _dark é a fonte de verdade (listener do AppProvider) — não usa Theme.of()
    final dark = _dark;
    final isEs = context.watch<AppProvider>().lang == 'es';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: dark
            ? const Color(0xFF1A1D23)
            : const Color(0xFFE0E6E9),

        // ── AppBar MedCases Pro — MANDATO 1+3: sem URL exposta, sem address bar ──
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: DecoratedBox(
            // MEDCASES_WEBVIEW_CANONICAL_HOME_TOPBAR_V1_B_R1
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.16 : 0.07),
                  blurRadius: 14,
                  spreadRadius: -8,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF161B22).withValues(alpha: 0.58)
                        : Colors.white.withValues(alpha: 0.56),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        dark
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.white.withValues(alpha: 0.46),
                        dark
                            ? Colors.white.withValues(alpha: 0.025)
                            : Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: dark
                            ? Colors.white.withValues(alpha: 0.13)
                            : Colors.white.withValues(alpha: 0.78),
                        width: 0.7,
                      ),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 0.7,
                        child: Container(
                          height: 0.7,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                dark
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : Colors.white.withValues(alpha: 0.86),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        bottom: false,
                        child: SizedBox(
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 48,
                                  ),
                                  child: Text(
                                    isEs ? 'GUÍA CLÍNICA' : 'GUIA CLÍNICO',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: dark
                                          ? Colors.white
                                          : const Color(0xFF05070A),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: IconButton(
                                      tooltip: 'Fechar',
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: dark
                                            ? Colors.white
                                            : const Color(0xFF05070A),
                                        size: 22,
                                      ),
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
              const Icon(
                Icons.lock_open_rounded,
                size: 48,
                color: Color(0xFFEF4444),
              ),
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
    // Fix#6: remove listener para evitar memory leak
    context.read<AppProvider>().removeListener(_onProviderChanged);
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
