import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/app_provider.dart';

// URL por idioma — substituir pelos caminhos reais da Wix antes de publicar
const _kUrlPt = 'https://www.promedcases.com/sua-url-secretablank';
const _kUrlEs = 'https://www.promedcases.com/sua-url-secretablank-es';

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
    // Lê o idioma ANTES de criar o controller — initState ainda tem acesso
    // ao context para context.read (sem listen, sem rebuild).
    final lang = context.read<AppProvider>().lang;
    final url  = lang == 'es' ? _kUrlEs : _kUrlPt;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('MedCasesApp/6.1.0')
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fundo escuro — elimina o branco do Scaffold que vaza nas bordas
      // e no overscroll do WKWebView no iPhone físico.
      backgroundColor: const Color(0xFF0F091E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D1B5A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'CALCULADORA CLÍNICA',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.4,
          ),
        ),
        flexibleSpace: Container(
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
        ),
      ),
      // WebView sangra até a borda física do display — sem SafeArea, sem padding
      body: WebViewWidget(controller: _controller),
    );
  }
}
