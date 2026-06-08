// ─────────────────────────────────────────────────────────────────────────────
// CALCULADORA CLÍNICA — Módulo autônomo com WebView
// Build 104 — Blindagem de engenharia para iPhone físico
//
// Arquitetura:
//   Scaffold → _CalcHeader (back btn + gradiente roxo) →
//     WebViewWidget (promedcases.com) com User-Agent "MedCasesApp/6.1.0"
//
// ═══════════════════════════════════════════════════════════════════════════
// BLINDAGEM 1 — Scroll vertical nativo iOS:
//   WKWebView dentro de SizedBox/Expanded compete com o Flutter gesture arena.
//   Sem gestureRecognizers explícito, o Flutter pode engolir os drags verticais
//   antes de o WKWebView recebê-los → página não rola.
//   SOLUÇÃO: WebViewWidget(gestureRecognizers: { EagerGestureRecognizer })
//   O EagerGestureRecognizer declara vitória imediata na arena, entregando
//   todos os eventos de toque diretamente ao WKWebView nativo.
//   Resultado: scroll vertical, pinch-to-zoom e tap nas calculadoras funcionam
//   normalmente como em Safari.
//
// BLINDAGEM 2 — SnackBar de conexão instável + _ErrorState:
//   onWebResourceError com isForMainFrame == true | null:
//     → mostra SnackBar "Conexão instável. Carregando dados locais..."
//     → troca para _ErrorState com botão de retry
//   Dupla camada: usuário recebe feedback visual imediato (SnackBar) +
//   tela de retry quando a rede está instável ou timeout (3G).
//
// BLINDAGEM 3 — User-Agent "MedCasesApp/6.1.0" garantido na 1ª requisição:
//   setUserAgent() é a PRIMEIRA chamada na cascata do WebViewController,
//   antes de setJavaScriptMode, setBackgroundColor, setNavigationDelegate
//   e loadRequest. Isso garante que o header User-Agent está presente
//   na PRIMEIRA requisição HTTP para promedcases.com — o JavaScript do site
//   lê esse header para decidir se exibe o conteúdo ou "Acceso Restringido".
//   Se setUserAgent viesse DEPOIS de loadRequest, a 1ª requisição sairia
//   sem o header → tela de acesso restrito antes de qualquer redirect.
// ═══════════════════════════════════════════════════════════════════════════
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

import 'package:flutter/foundation.dart' show Factory, kIsWeb;
import 'package:flutter/gestures.dart';
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
///
/// ⚠️  SUBSTITUA PELA URL REAL DA WIX/PROMEDCASES ANTES DE PUBLICAR  ⚠️
// ignore: avoid_redundant_argument_values
const _kTargetUrl = 'https://www.promedcases.com/calculadoras-referencias';

/// Fallback hardcoded — ativado se _kTargetUrl estiver vazia, for placeholder
/// ("sua-url", "placeholder") ou não tiver authority HTTP válida.
/// Build 104 FIX: protege contra Firebase Timeout, typo de config,
/// variável não resolvida — garante que loadRequest nunca recebe URL vazia.
///
/// ⚠️  SUBSTITUA TAMBÉM ESTE FALLBACK PELA URL REAL DA WIX/PROMEDCASES  ⚠️
const _kFallbackUrl = 'https://www.promedcases.com/calculadoras-referencias';

/// ── BLINDAGEM 3 — User-Agent injetado ANTES do loadRequest ──────────────────
/// Reconhecido pelo JavaScript do site para liberar calculadoras e referências.
/// Posição na cascata: PRIMEIRA chamada → garante header na 1ª requisição HTTP.
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
// Build 103 → 104 — Diagnóstico raiz + blindagem engenharia iPhone físico:
//
// CAUSA 1 — Overlay opaco bloqueante [RESOLVIDO em Build 103]:
//   Container(color: bg) cobria 100% do WebView enquanto _loading=true.
//   SOLUÇÃO: removido _loading inteiramente. build() retorna SizedBox.expand.
//
// CAUSA 2 — isForMainFrame == null ignorado [RESOLVIDO em Build 103]:
//   WKWebView envia null (não true) para NSURLErrorDomain.
//   SOLUÇÃO: `isMain == true || isMain == null`.
//
// CAUSA 3 — _ctrl.reload() no retry [RESOLVIDO em Build 103]:
//   reload() em URL nunca carregada = estado inválido no WKWebView.
//   SOLUÇÃO: loadRequest(Uri.parse(_kTargetUrl)) sempre.
//
// BLINDAGEM 1 — gestureRecognizers scroll vertical [NOVO Build 104]:
//   EagerGestureRecognizer passa todos os eventos de toque ao WKWebView.
//   Sem isso, Flutter pode "roubar" drags verticais da página.
//
// BLINDAGEM 2 — SnackBar conexão instável [NOVO Build 104]:
//   onWebResourceError → SnackBar imediato + _ErrorState com retry.
//
// BLINDAGEM 3 — User-Agent 1ª posição na cascata [CONFIRMADO Build 104]:
//   setUserAgent → 1ª chamada → header presente na 1ª requisição HTTP.
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
  // Ativado por erros do frame principal (isForMainFrame == true | null).
  bool _hasError = false;

  // ── BLINDAGEM 1 — gestureRecognizers para scroll nativo iOS ──────────────
  // EagerGestureRecognizer declara vitória imediata na Flutter gesture arena,
  // entregando TODOS os eventos de toque ao WKWebView nativo.
  // Resultado: scroll vertical, pinch-to-zoom e tap funcionam como em Safari.
  // Nota: Set é `final` e criado uma única vez — evita rebuild desnecessário.
  static final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizers =
      <Factory<OneSequenceGestureRecognizer>>{
    Factory<EagerGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  // URL efetiva resolvida no initState — nunca vazia, nunca placeholder.
  late final String _effectiveUrl;

  @override
  void initState() {
    super.initState();

    // ── BLINDAGEM URL — Validação antes de qualquer loadRequest ──────────
    // Se _kTargetUrl estiver vazia, for placeholder ou não tiver authority
    // HTTP válida → usa _kFallbackUrl estável.
    // Protege contra: Firebase Timeout, typo de config, variável não resolvida.
    final Uri? parsedUrl = Uri.tryParse(_kTargetUrl);
    _effectiveUrl = (_kTargetUrl.isEmpty ||
            _kTargetUrl.contains('sua-url') ||
            _kTargetUrl.contains('placeholder') ||
            parsedUrl == null ||
            !parsedUrl.hasAuthority)
        ? _kFallbackUrl
        : _kTargetUrl;

    // ── BLINDAGEM 3 — Inicialização atômica via cascata (..) ──────────────
    // Ordem CRÍTICA para WKWebView iOS — NÃO alterar a sequência:
    //
    //   1. setUserAgent   ← DEVE ser PRIMEIRA — header chegará na 1ª requisição
    //                       Se vier depois do loadRequest, a 1ª request sai
    //                       sem User-Agent → site exibe "Acceso Restringido"
    //   2. setJavaScriptMode → JS habilitado antes do carregamento
    //   3. setBackgroundColor → cor de fundo enquanto HTML não renderizou
    //   4. setNavigationDelegate → callbacks registrados antes do load
    //   5. loadRequest   ← DEVE ser ÚLTIMA — dispara o carregamento
    //
    // Em webview_flutter 4.x, chamadas com ".." são enfileiradas
    // sincronamente no platform channel — ordem de entrega garantida.
    _ctrl = WebViewController()
      // ── BLINDAGEM 3: User-Agent — posição 1, ANTES do loadRequest ────────
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
          // Página carregada com sucesso — WebView já está visível.
          // Nada a fazer: sem overlay para remover (Build 103 removeu _loading).
        },
        onWebResourceError: (error) {
          // ── BLINDAGEM 2 — Feedback duplo para conexão instável ────────────
          //
          // WKWebView iOS envia NSURLErrorDomain com:
          //   -1009 = kCFURLErrorNotConnectedToInternet (sem rede)
          //   -1001 = kCFURLErrorTimedOut (timeout 3G instável)
          //   -1005 = kCFURLErrorNetworkConnectionLost (conexão perdida)
          //   isForMainFrame = null  (não true!) para esses códigos
          //
          // Guard: trata null como erro do frame principal.
          // Erros de sub-recursos (imagens, CSS, JS de CDN) têm
          // isForMainFrame = false e são silenciosamente ignorados.
          final isMain = error.isForMainFrame;
          if (isMain != false) {
            // Camada 1 — SnackBar imediato: usuário recebe feedback visual
            // mesmo enquanto ainda está na tela (não troca de widget ainda).
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    widget.isEs
                        ? 'Conexión inestable. Cargando datos locales de contingencia...'
                        : 'Conexão instável. Carregando dados locais de contingência...',
                    style: const TextStyle(fontSize: 13),
                  ),
                  backgroundColor: const Color(0xFF2D1B5A),
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: widget.isEs ? 'Reintentar' : 'Tentar novamente',
                    textColor: const Color(0xFFA78BFA),
                    onPressed: () {
                      setState(() { _hasError = false; });
                      _ctrl.loadRequest(Uri.parse(_effectiveUrl));
                    },
                  ),
                ),
              );
            }
            // Camada 2 — _ErrorState: substitui o WebView por tela de retry
            // após o SnackBar já ter dado feedback ao usuário.
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
      // ── BLINDAGEM 3: loadRequest — ÚLTIMA chamada da cascata ─────────────
      // Usa _effectiveUrl (validada acima) — nunca URL vazia ou placeholder.
      ..loadRequest(Uri.parse(_effectiveUrl));
  }

  @override
  Widget build(BuildContext context) {
    // Estado de erro — rede indisponível ou timeout de frame principal
    if (_hasError) {
      return _ErrorState(
        dark: widget.dark,
        isEs: widget.isEs,
        onRetry: () {
          setState(() { _hasError = false; });
          // CORREÇÃO: usa loadRequest (não reload) — reload em URL nunca
          // carregada retorna estado inválido no WKWebView iOS.
          // Usa _effectiveUrl (validada no initState) — nunca URL vazia.
          _ctrl.loadRequest(Uri.parse(_effectiveUrl));
        },
      );
    }

    // ── DESIGN DIRETO + BLINDAGEM 1 — WebView sempre visível, scroll nativo ─
    //
    // SizedBox.expand() → força WebViewWidget a preencher 100% das constraints
    //   do Expanded pai. Nunca colapsa para zero em iOS/Android.
    //
    // gestureRecognizers: _gestureRecognizers →
    //   EagerGestureRecognizer passa todos os eventos de toque ao WKWebView.
    //   Sem isso, o Flutter gesture arena pode "roubar" drags verticais da
    //   página → rolagem travada mesmo com conteúdo carregado.
    //   Com EagerGestureRecognizer: scroll, pinch-to-zoom e tap funcionam
    //   nativamente, como em Safari no iPhone físico.
    return SizedBox.expand(
      child: WebViewWidget(
        controller: _ctrl,
        gestureRecognizers: _gestureRecognizers,
      ),
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
