import 'package:firebase_auth/firebase_auth.dart';
import '../services/calculator_mcc1_bridge_service.dart';
import '../services/entitlement_service.dart';
import 'dart:convert';
import 'dart:async';
// calcu_web.dart — Implementação Web da calculadora embutida.
// Compilado APENAS no target Web (dart2js / wasm).
// iOS/Android usam calcu_stub.dart via conditional import em calculadora_screen.dart.
//
// Estratégia:
//   • Registra um iframe HTML via ui_web.platformViewRegistry (uma única vez por URL).
//   • Expõe buildCalculadoraWebView() que retorna um HtmlElementView com 100% w/h.
//   • O iframe é configurado sem borda, com allow="fullscreen".
//   • Loading overlay e mensagem de erro amigável gerenciados pelo StatefulWidget.

// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../screens/upgrade_screen.dart';

/// Sufixo único por URL — evita re-registro do mesmo viewType se o widget
/// for reconstruído com a mesma URL (platformViewRegistry lança se re-registrar).
final _registered = <String>{};
final _frames = <String, html.IFrameElement>{};

/// Constrói o widget iframe embutido para Flutter Web.
/// [url] — URL completa a carregar (ex.: https://www.medcasescalcu.com?lang=pt)
/// [dark] — usado para paleta do loader / mensagem de erro.
Widget buildCalculadoraWebView(String url, bool dark) {
  // viewType único por URL para evitar colisões
  final String viewType = 'medcases-calcu-iframe-${url.hashCode.abs()}';

  if (!_registered.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final frame = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'block'
        ..allow = 'fullscreen'
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute('loading', 'lazy');
      _frames[viewType] = frame;
      return frame;
    });
    _registered.add(viewType);
  }

  return _CalcuWebFrame(viewType: viewType, url: url, dark: dark);
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget interno com loader + fallback de erro
// ─────────────────────────────────────────────────────────────────────────────
class _CalcuWebFrame extends StatefulWidget {
  final String viewType;
  final String url;
  final bool dark;

  const _CalcuWebFrame({
    required this.viewType,
    required this.url,
    required this.dark,
  });

  @override
  State<_CalcuWebFrame> createState() => _CalcuWebFrameState();
}

class _CalcuWebFrameState extends State<_CalcuWebFrame> {
  // MEDCASES_PREMIUM_WEB_PARENT_BRIDGE_V1_B_R4
  static const Set<String> _premiumAllowedOrigins = <String>{
    'https://medcasescalcu.com',
    'https://www.medcasescalcu.com',
  };

  StreamSubscription<html.MessageEvent>? _premiumBridgeSubscription;
  StreamSubscription<User?>? _authSubscription;
  int _sessionEpoch = 0;
  bool _sendingSession = false;
  void _revokeFrame() {
    _sessionEpoch++;
    _frames[widget.viewType]?.contentWindow?.postMessage(
        jsonEncode({'type': 'medcases:session-revoke'}),
        Uri.parse(widget.url).origin);
  }

  Future<void> _sendSession() async {
    if (_sendingSession || !mounted) return;
    final owner = FirebaseAuth.instance.currentUser?.uid;
    if (owner == null) {
      _revokeFrame();
      return;
    }
    _sendingSession = true;
    final epoch = _sessionEpoch;
    var retryForNewOwner = false;
    try {
      final session = await const CalculatorMcc1BridgeService().issueSession();
      if (!mounted) return;
      if (epoch != _sessionEpoch ||
          owner != FirebaseAuth.instance.currentUser?.uid) {
        retryForNewOwner = true;
        return;
      }
      _frames[widget.viewType]?.contentWindow?.postMessage(
          jsonEncode({'type': 'medcases:session', 'token': session.token}),
          Uri.parse(widget.url).origin);
    } catch (_) {
      if (epoch != _sessionEpoch) {
        retryForNewOwner = true;
      } else {
        _revokeFrame();
      }
    } finally {
      _sendingSession = false;
      if (retryForNewOwner && mounted) unawaited(_sendSession());
    }
  }

  void _entitlementChanged() {
    _revokeFrame();
    unawaited(_sendSession());
  }

  void _handlePremiumBridgeMessage(html.MessageEvent event) {
    if (!_premiumAllowedOrigins.contains(event.origin) ||
        event.source != _frames[widget.viewType]?.contentWindow) return;

    final raw = event.data;
    if (raw is! String || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      if (decoded['type'] == 'medcases:session-request') {
        unawaited(_sendSession());
        return;
      }
      if (decoded['type']?.toString() != 'medcases:premium-upgrade') return;

      final requested =
          decoded['lang']?.toString().trim().toLowerCase() ?? 'es';
      final lang = requested == 'pt' ? 'pt' : 'es';

      if (!mounted) return;
      showUpgradeScreen(context, lang: lang);
    } catch (_) {
      // Unrelated or malformed cross-window messages are ignored.
    }
  }

  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _premiumBridgeSubscription =
        html.window.onMessage.listen(_handlePremiumBridgeMessage);
    EntitlementService.instance.addListener(_entitlementChanged);
    _authSubscription = FirebaseAuth.instance
        .authStateChanges()
        .listen((_) => _entitlementChanged());
    // Simula tempo de carregamento — o iframe não expõe onLoad via HtmlElementView.
    // Após 4s consideramos carregado (comportamento conservador).
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _revokeFrame();
    EntitlementService.instance.removeListener(_entitlementChanged);
    _authSubscription?.cancel();
    _premiumBridgeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color loaderBg =
        widget.dark ? const Color(0xFF0F091E) : const Color(0xFFF8F9FA);
    final Color loaderFg = const Color(0xFFA78BFA);
    final Color errorText =
        widget.dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Stack(
      children: [
        // ── iframe 100% w/h ──────────────────────────────────────────────
        Positioned.fill(
          child: HtmlElementView(viewType: widget.viewType),
        ),

        // ── Loader overlay ───────────────────────────────────────────────
        if (_loading)
          Positioned.fill(
            child: Container(
              color: loaderBg,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: loaderFg,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Carregando calculadora...',
                      style: TextStyle(
                        fontSize: 13,
                        color: loaderFg,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Erro amigável (caso _hasError seja setado externamente) ──────
        if (_hasError)
          Positioned.fill(
            child: Container(
              color: loaderBg,
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.signal_wifi_off_rounded,
                        size: 40, color: loaderFg),
                    const SizedBox(height: 12),
                    Text(
                      'Não foi possível carregar a calculadora.\nVerifique sua conexão e tente novamente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: errorText),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() {
                        _hasError = false;
                        _loading = true;
                        Future.delayed(const Duration(milliseconds: 3500), () {
                          if (mounted) setState(() => _loading = false);
                        });
                      }),
                      child: Text(
                        'Tentar novamente',
                        style: TextStyle(
                            color: loaderFg, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
