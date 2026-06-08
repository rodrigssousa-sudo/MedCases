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
const _kBaseUrl = 'https://www.promedcases.com/sua-url-secretablank';

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
    final topPadding = MediaQuery.of(context).padding.top;
    final isEs       = context.read<AppProvider>().lang == 'es';

    // AnnotatedRegion força a cor da status bar sem usar AppBar nativo.
    // SizedBox.expand garante que o Material preenche 100% do espaço
    // alocado pelo Navigator — sem nenhum padding automático do Scaffold.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // ícones da status bar em branco
      child: Material(
        color: const Color(0xFF0F091E), // fundo 100% escuro, sem gaps
        child: Stack(
          children: [

            // ── WebView: ocupa CADA PIXEL do display ───────────────────────
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),

            // ── Rodapé referências — Apple 1.4.1 — overlay fixo na base ───
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _ReferencesFooter(isEs: isEs),
            ),

            // ── Header roxo — overlay fixo no topo ─────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: Container(
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
      decoration: const BoxDecoration(
        color: Color(0xF01A0F2E),
        border: Border(
          top: BorderSide(color: Color(0x334A2D8A), width: 0.5),
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
                color: Color(0xFFB8A8E8),
                height: 1.3,
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
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFA78BFA),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
