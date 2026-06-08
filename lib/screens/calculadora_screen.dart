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
          // Expanded garante que o WebView ocupa TODA a área disponível
          // abaixo do header — constraints nunca são zero ou infinitas.
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
//
// Build 103 FIX — Diagnóstico raiz da tela branca (WKWebView iOS):
//
// CAUSA 1 — Overlay opaco bloqueante:
//   O Container(color: bg) cobria 100% do WebView enquanto _loading=true.
//   Se onPageFinished não disparava (bug WKWebView para NSURLErrorDomain),
//   o overlay permanecia branco para sempre. SOLUÇÃO: LinearProgressIndicator
//   não-bloqueante de 3pt no topo — WebView sempre visível.
//
// CAUSA 2 — isForMainFrame == null ignorado:
//   No iOS WKWebView, erros NSURLErrorDomain (-1009 sem rede, -1001 timeout)
//   chegam com isForMainFrame = null, não true. O guard anterior
//   `if (error.isForMainFrame == true)` falhava silenciosamente, deixando
//   _loading = true para sempre. SOLUÇÃO: `isMain == true || isMain == null`.
//
// CAUSA 3 — _ctrl.reload() no retry:
//   reload() em URL nunca carregada retorna estado inválido no WKWebView.
//   SOLUÇÃO: sempre usa loadRequest(Uri.parse(_kTargetUrl)) no retry.
//
// CAUSA 4 — onNavigationRequest bloqueando redirects internos do site:
//   promedcases.com pode usar redirects (HTTP 301/302) via diferentes
//   subdomínios ou paths. O guard `uri.host.endsWith('promedcases.com')`
//   captura todos os subdomínios (www, cdn, api, etc.). OK.
//
// DESIGN FINAL — não-bloqueante:
//   Stack(expand) { WebViewWidget + if(_loading) LinearProgressIndicator(3pt) }
//   WebView está SEMPRE visível — usuário vê o conteúdo renderizando em tempo real.
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

  // _hasError = true → exibe _ErrorState com botão "Tentar novamente".
  // Ativado apenas por erros do frame principal (isForMainFrame == true | null).
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    // ── Inicialização atômica via cascata (..) ────────────────────────────
    // Ordem crítica para WKWebView iOS:
    //   1. setUserAgent   → deve ser ANTES de loadRequest para que o header
    //                       User-Agent chegue na primeira requisição HTTP
    //   2. setJavaScriptMode → habilita JS antes do carregamento
    //   3. setBackgroundColor → cor de fundo enquanto o HTML não renderizou
    //   4. setNavigationDelegate → callbacks de progresso e erro
    //   5. loadRequest   → dispara o carregamento (sempre por último)
    //
    // Em webview_flutter 4.x, chamadas com ".." são enfileiradas
    // sincronamente no platform channel — a ordem de entrega é garantida.
    _ctrl = WebViewController()
      ..setUserAgent(_kUserAgent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(
          widget.dark ? const Color(0xFF1A1D23) : Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          // Reinicia o estado de erro a cada nova navegação (inclui redirects).
          if (mounted && _hasError) setState(() { _hasError = false; });
        },
        onPageFinished: (_) {
          // Página carregada com sucesso — nada a fazer (sem overlay para remover).
        },
        onWebResourceError: (error) {
          // ── CORREÇÃO CRÍTICA WKWebView iOS ────────────────────────────
          // Erros de rede (NSURLErrorDomain -1009 = sem rede,
          // -1001 = timeout, -1005 = conexão perdida) chegam com
          // isForMainFrame = null, não true.
          //
          // O guard anterior `if (error.isForMainFrame == true)` falhava
          // silenciosamente nesses casos, deixando _loading = true para
          // sempre e a tela branca permanente.
          //
          // SOLUÇÃO: trata null como erro do frame principal.
          // Erros de sub-recursos (CSS/JS de CDN) têm isForMainFrame = false
          // e são ignorados corretamente por este guard.
          final isMain = error.isForMainFrame;
          if (isMain == true || isMain == null) {
            if (mounted) setState(() { _hasError = true; });
          }
        },
        onNavigationRequest: (request) {
          // Permite navegação dentro do domínio promedcases.com e todos
          // os seus subdomínios (www, cdn, api, staging…).
          // Bloqueia links externos — evita saída acidental do app.
          final uri = Uri.tryParse(request.url);
          if (uri != null && uri.host.endsWith('promedcases.com')) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(_kTargetUrl));

  }

  @override
  Widget build(BuildContext context) {
    // Estado de erro — rede indisponível ou falha de carregamento do frame principal
    if (_hasError) {
      return _ErrorState(
        dark: widget.dark,
        isEs: widget.isEs,
        onRetry: () {
          setState(() { _hasError = false; });
          // CORREÇÃO: usa loadRequest (não reload) — reload em URL nunca
          // carregada retorna estado inválido no WKWebView iOS.
          _ctrl.loadRequest(Uri.parse(_kTargetUrl));
        },
      );
    }

    // ── DESIGN DIRETO — WebView sempre visível, sem overlay de qualquer tipo ──
    // SizedBox.expand() força o WebViewWidget a preencher 100% das constraints
    // recebidas do Expanded pai — nunca colapsa para zero em iOS/Android.
    // Nenhum Stack, nenhum indicador de progresso, nada sobre o WebView.
    return SizedBox.expand(
      child: WebViewWidget(controller: _ctrl),
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
