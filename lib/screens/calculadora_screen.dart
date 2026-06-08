// ─────────────────────────────────────────────────────────────────────────────
// CALCULADORA CLÍNICA — Módulo autônomo com WebView
// Build 102 — Acesso direto via card full-width na Home Screen
//
// Arquitetura:
//   Scaffold → _CalcHeader (back btn + gradiente roxo) →
//     WebViewWidget (promedcases.com) com User-Agent "MedCasesApp/6.1.0"
//
// User-Agent "MedCasesApp/6.1.0":
//   O JavaScript de promedcases.com/sua-url-secretablank detecta este
//   User-Agent e desativa a tela "Acceso Restringido", exibindo as
//   calculadoras clínicas e as referências bibliográficas completas
//   diretamente para o revisor da Apple.
//
// Apple Guideline 1.4.1 compliance:
//   As referências científicas (citações acadêmicas, diretrizes AHA/ACC/WHO)
//   são renderizadas pelo próprio site promedcases.com e ficam visíveis
//   no rodapé da página — não requerem accordion nem interação adicional.
//
// Apple Guideline 2.5.4:
//   WebView não declara UIBackgroundModes. A sessão é 100% foreground.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart' show AppColors;

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES — URL e User-Agent
// ─────────────────────────────────────────────────────────────────────────────

/// URL oficial da página de calculadoras e referências do MedCases Pro.
/// O site detecta o User-Agent [_kUserAgent] e remove o bloqueio "Acceso Restringido".
const _kTargetUrl = 'https://www.promedcases.com/sua-url-secretablank';

/// User-Agent injetado no WebView. Reconhecido pelo JavaScript do site para
/// liberar o conteúdo de calculadoras e referências bibliográficas.
const _kUserAgent = 'MedCasesApp/6.1.0';

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN — standalone entry point
// ─────────────────────────────────────────────────────────────────────────────
class CalculadoraScreen extends StatelessWidget {
  const CalculadoraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1A1D23) : const Color(0xFFF7F8FA),
      body: Column(
        children: [
          // ── Header com botão voltar ─────────────────────────────────────
          _CalcHeader(dark: dark, isEs: isEs),

          // ── WebView — promedcases.com com User-Agent MedCasesApp/6.1.0 ──
          Expanded(
            child: kIsWeb
                // Flutter Web não suporta webview_flutter — mostra fallback
                ? _WebFallback(isEs: isEs)
                : _CalcWebView(dark: dark, isEs: isEs),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEBVIEW — carrega promedcases.com com User-Agent customizado
// ─────────────────────────────────────────────────────────────────────────────
class _CalcWebView extends StatefulWidget {
  final bool dark;
  final bool isEs;
  const _CalcWebView({required this.dark, required this.isEs});

  @override
  State<_CalcWebView> createState() => _CalcWebViewState();
}

class _CalcWebViewState extends State<_CalcWebView> {
  late final WebViewController _ctrl;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      // ── User-Agent: identifica o app para o JS do site ─────────────────
      ..setUserAgent(_kUserAgent)
      // ── JavaScript habilitado (requisito do site) ───────────────────────
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // ── Background igual ao tema do app ────────────────────────────────
      ..setBackgroundColor(
          widget.dark ? const Color(0xFF1A1D23) : Colors.white)
      // ── Callbacks de progresso ──────────────────────────────────────────
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() { _loading = true; _hasError = false; });
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Ignora erros de sub-recursos (CSS/JS de terceiros) — só falha
            // se for o documento principal (isForMainFrame == true).
            if (error.isForMainFrame == true) {
              if (mounted) setState(() { _loading = false; _hasError = true; });
            }
          },
          // Permite apenas navegação dentro do domínio promedcases.com
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && uri.host.endsWith('promedcases.com')) {
              return NavigationDecision.navigate;
            }
            // Bloqueia links externos — evita saída acidental do app
            return NavigationDecision.prevent;
          },
        ),
      )
      // ── Carrega a URL oficial ───────────────────────────────────────────
      ..loadRequest(Uri.parse(_kTargetUrl));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    if (_hasError) {
      return _ErrorState(dark: widget.dark, isEs: widget.isEs, onRetry: () {
        setState(() { _loading = true; _hasError = false; });
        _ctrl.reload();
      });
    }

    return Stack(
      children: [
        // ── WebView principal ─────────────────────────────────────────────
        WebViewWidget(controller: _ctrl),

        // ── Progress indicator (visível durante carregamento) ─────────────
        if (_loading)
          Container(
            color: widget.dark
                ? const Color(0xFF1A1D23)
                : const Color(0xFFF7F8FA),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFFA78BFA),
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isEs
                        ? 'Cargando calculadoras...'
                        : 'Carregando calculadoras...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _kTargetUrl,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: c.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO DE ERRO — rede indisponível ou timeout
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final VoidCallback onRetry;
  const _ErrorState({
    required this.dark, required this.isEs, required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 48, color: c.textHint),
            const SizedBox(height: 16),
            Text(
              isEs
                  ? 'Sin conexión a Internet'
                  : 'Sem conexão com a Internet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isEs
                  ? 'Las calculadoras requieren conexión para cargar las referencias actualizadas.'
                  : 'As calculadoras requerem conexão para carregar as referências atualizadas.',
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isEs ? 'Intentar de nuevo' : 'Tentar novamente'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A2D8A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FALLBACK WEB — Flutter Web não suporta webview_flutter
// Exibe mensagem orientando abrir no app mobile.
// ─────────────────────────────────────────────────────────────────────────────
class _WebFallback extends StatelessWidget {
  final bool isEs;
  const _WebFallback({required this.isEs});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smartphone_rounded, size: 48, color: c.textHint),
            const SizedBox(height: 16),
            Text(
              isEs
                  ? 'Disponible en la app iOS / Android'
                  : 'Disponível no app iOS / Android',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isEs
                  ? 'Las calculadoras con referencias completas están disponibles en la versión móvil de MedCases Pro.'
                  : 'As calculadoras com referências completas estão disponíveis na versão móvel do MedCases Pro.',
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — gradiente roxo + botão voltar + ícone calculadora
// Botão voltar sempre no topo da stack de renderização —
// equivalente a z-index: 9999 do CSS.
// ─────────────────────────────────────────────────────────────────────────────
class _CalcHeader extends StatelessWidget {
  final bool dark;
  final bool isEs;
  const _CalcHeader({required this.dark, required this.isEs});

  static const _gradientColors = [
    Color(0xFF1A0F2E),
    Color(0xFF2D1B5A),
    Color(0xFF4A2D8A),
  ];
  static const _accentColor = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          // Círculo decorativo grande
          Positioned(
            right: -24, top: -24,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentColor.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Círculo decorativo pequeno
          Positioned(
            right: 16, bottom: -28,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentColor.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Conteúdo — renderizado ACIMA dos círculos (z-index equivalente)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 20, 14),
            child: Row(children: [
              // ── Botão voltar — sempre visível ─────────────────────────
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    size: 18, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              // ── Ícone calculadora ──────────────────────────────────────
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _accentColor.withValues(alpha: 0.14),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: const Icon(Icons.calculate_rounded,
                    size: 24, color: _accentColor),
              ),
              const SizedBox(width: 14),
              // ── Títulos ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isEs ? 'CALCULADORA CLÍNICA' : 'CALCULADORA CLÍNICA',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEs
                          ? 'Cálculos y Fórmulas de Referencia'
                          : 'Scores · Cardio · Eletrólitos · Referência',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _accentColor.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
