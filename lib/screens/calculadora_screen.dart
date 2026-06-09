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
// JS injetado no onPageFinished:
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

    final lang      = context.read<AppProvider>().lang;
    final langParam = lang == 'es' ? 'es' : 'pt';

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
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _controller.runJavaScript(_kInjectJs),
      ))
      ..loadRequest(Uri.parse('$_kBaseUrl?lang=$langParam'));
  }

  @override
  Widget build(BuildContext context) {
    // Dimensões físicas reais do display — ignora qualquer inset do framework
    final mq         = MediaQuery.of(context);
    final screenSize  = mq.size;
    final topPadding  = mq.padding.top;
    final isEs        = context.read<AppProvider>().lang == 'es';

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

              // ── CAMADA 1 — Rodapé referências (Apple 1.4.1) ────────────────
              // Overlay sobre a WebView, fixo na base, sem subtrair altura dela
              Positioned(
                bottom: 0,
                left:   0,
                right:  0,
                child: _ReferencesFooter(isEs: isEs),
              ),

              // ── CAMADA 2 — Header roxo com gradiente ───────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// RODAPÉ DE REFERÊNCIAS — Apple Guideline 1.4.1
// Overlay fixo na base da Stack — não consome altura do WebView.
// ─────────────────────────────────────────────────────────────────────────────
class _ReferencesFooter extends StatelessWidget {
  final bool isEs;
  const _ReferencesFooter({required this.isEs});

  static const _kSourcesUrl = 'https://www.promedcases.com/fontes-e-referencias';

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 7, 14, 7 + bottomPadding),
      decoration: BoxDecoration(
        // Cor sólida idêntica ao fundo da Wix — layout unificado e selado
        color: const Color(0xFF0F091E),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFFA78BFA)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              isEs
                  ? 'Referencias clínicas y bibliográficas: AHA, ACC, WHO, PubMed'
                  : 'Referências clínicas e bibliográficas: AHA, ACC, WHO, PubMed',
              style: const TextStyle(
                fontSize: 10,
                color:    Color(0xFFB8A8E8),
                height:   1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(_kSourcesUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x664A2D8A)),
                color: const Color(0x1AA78BFA),
              ),
              child: Text(
                isEs ? 'Ver fuentes' : 'Ver fontes',
                style: const TextStyle(
                  fontSize:   10,
                  fontWeight: FontWeight.w600,
                  color:      Color(0xFFA78BFA),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
