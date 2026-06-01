// error_state_widget.dart — Task 11: Tratamento de Conexão e Empty States
// Apple Guideline 2.1: "Apps must be complete and finished before submission"
//
// Widgets exportados:
//   • ErrorStateWidget       — tela de erro genérica com botão "Tentar novamente"
//   • NetworkErrorWidget     — variante específica para falha de rede/IA
//   • EmptyStateWidget       — tela vazia com ícone e mensagem
//   • NetworkAwareBuilder    — wrapper que detecta erro e exibe ErrorStateWidget
//   • MedFutureBuilder       — FutureBuilder pré-configurado com loading + error + empty
//   • MedStreamBuilder       — StreamBuilder pré-configurado com loading + error + empty

import 'package:flutter/material.dart';

// ── Constantes visuais ─────────────────────────────────────────────────────────
const Color _kGreen = Color(0xFF0D7A55);
const Color _kRed   = Color(0xFFCC3333);
const Color _kBlue  = Color(0xFF1E88E5);

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR STATE WIDGET
// Uso genérico: qualquer tela que pode falhar (IA, Firestore, REST, etc.)
//
// Exemplo:
//   if (_hasError) {
//     return ErrorStateWidget(
//       onRetry: _reload,
//       message: 'Não foi possível carregar os protocolos.',
//     );
//   }
// ═══════════════════════════════════════════════════════════════════════════════
class ErrorStateWidget extends StatelessWidget {
  /// Mensagem descritiva do erro (bilíngue — passe a string já traduzida).
  final String? message;

  /// Texto do botão de retry. Default: "Tentar novamente"
  final String? retryLabel;

  /// Callback do botão retry. Se null, botão não é exibido.
  final VoidCallback? onRetry;

  /// Tipo do erro — altera ícone e cor do container.
  final ErrorStateType type;

  /// Exibe detalhes técnicos do erro (útil em debug).
  final String? technicalDetail;

  /// Idioma: 'pt' ou 'es'
  final String lang;

  const ErrorStateWidget({
    super.key,
    this.message,
    this.retryLabel,
    this.onRetry,
    this.type = ErrorStateType.generic,
    this.technicalDetail,
    this.lang = 'pt',
  });

  @override
  Widget build(BuildContext context) {
    final dark    = Theme.of(context).brightness == Brightness.dark;
    final isEs    = lang == 'es';
    final config  = _ErrorConfig.from(type, isEs);
    final bg      = dark ? const Color(0xFF0B1510) : const Color(0xFFF5F7F5);
    final cardBg  = dark ? const Color(0xFF111B14) : Colors.white;

    return Container(
      color: bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícone em container arredondado
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: config.color.withValues(alpha: dark ? 0.15 : 0.09),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: config.color.withValues(alpha: 0.22),
                    width: 1.5,
                  ),
                ),
                child: Icon(config.icon, size: 38, color: config.color),
              ),
              const SizedBox(height: 20),

              // Título
              Text(
                config.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : const Color(0xFF0F1C14),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Mensagem
              Text(
                message ?? config.defaultMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.55,
                  color: dark ? Colors.white60 : const Color(0xFF556655),
                ),
              ),

              // Detalhe técnico (apenas em debug ou se fornecido)
              if (technicalDetail != null && technicalDetail!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: dark
                            ? Colors.white12
                            : const Color(0xFFE0E0E0)),
                  ),
                  child: Text(
                    technicalDetail!,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: dark ? Colors.white38 : Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Botão retry
              if (onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    retryLabel ??
                        (isEs ? 'Intentar de nuevo' : 'Tentar novamente'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: config.color,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tipos de erro ──────────────────────────────────────────────────────────────
enum ErrorStateType {
  generic,   // erro genérico
  network,   // sem conexão / timeout
  ai,        // falha da IA (Gemini/OpenAI)
  server,    // erro HTTP 5xx
  empty,     // sem dados (não é erro, mas estado vazio)
  auth,      // sessão expirada / não autenticado
}

class _ErrorConfig {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   defaultMessage;

  const _ErrorConfig({
    required this.icon,
    required this.color,
    required this.title,
    required this.defaultMessage,
  });

  factory _ErrorConfig.from(ErrorStateType type, bool isEs) {
    switch (type) {
      case ErrorStateType.network:
        return _ErrorConfig(
          icon: Icons.wifi_off_rounded,
          color: _kBlue,
          title: isEs ? 'Sin conexión' : 'Sem conexão',
          defaultMessage: isEs
              ? 'Verifica tu conexión a internet e intenta de nuevo.'
              : 'Verifique sua conexão com a internet e tente novamente.',
        );
      case ErrorStateType.ai:
        return _ErrorConfig(
          icon: Icons.psychology_outlined,
          color: _kGreen,
          title: isEs ? 'IA temporalmente no disponible' : 'IA temporariamente indisponível',
          defaultMessage: isEs
              ? 'El servicio de IA está momentáneamente fuera de línea. '
                'Tus datos clínicos están seguros. Intenta en unos instantes.'
              : 'O serviço de IA está momentaneamente fora do ar. '
                'Seus dados clínicos estão seguros. Tente em instantes.',
        );
      case ErrorStateType.server:
        return _ErrorConfig(
          icon: Icons.cloud_off_rounded,
          color: _kRed,
          title: isEs ? 'Error del servidor' : 'Erro no servidor',
          defaultMessage: isEs
              ? 'El servidor está respondiendo con error. Intenta de nuevo en algunos minutos.'
              : 'O servidor está respondendo com erro. Tente novamente em alguns minutos.',
        );
      case ErrorStateType.auth:
        return _ErrorConfig(
          icon: Icons.lock_outline_rounded,
          color: Colors.orange,
          title: isEs ? 'Sesión expirada' : 'Sessão expirada',
          defaultMessage: isEs
              ? 'Tu sesión expiró por seguridad. Inicia sesión nuevamente.'
              : 'Sua sessão expirou por segurança. Faça login novamente.',
        );
      case ErrorStateType.empty:
        return _ErrorConfig(
          icon: Icons.inbox_outlined,
          color: _kGreen,
          title: isEs ? 'Nada por aquí' : 'Nada por aqui',
          defaultMessage: isEs
              ? 'No hay datos para mostrar todavía.'
              : 'Não há dados para exibir ainda.',
        );
      case ErrorStateType.generic:
      return _ErrorConfig(
          icon: Icons.error_outline_rounded,
          color: _kRed,
          title: isEs ? 'Algo salió mal' : 'Algo deu errado',
          defaultMessage: isEs
              ? 'Ocurrió un error inesperado. Intenta de nuevo.'
              : 'Ocorreu um erro inesperado. Tente novamente.',
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK ERROR WIDGET
// Variante otimizada para erros de rede na tela de IA e protocolos.
// Inclui dicas de troubleshooting específicas para apps médicos em plantão
// (ex: rede hospitalar com firewall).
// ═══════════════════════════════════════════════════════════════════════════════
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String lang;
  final bool isAiError; // true = erro da IA; false = erro de rede genérico

  const NetworkErrorWidget({
    super.key,
    this.onRetry,
    this.lang = 'pt',
    this.isAiError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final dark = Theme.of(context).brightness == Brightness.dark;

    final tips = isEs ? [
      '• Verifica que el Wi-Fi o datos móviles estén activos',
      '• Redes hospitalarias pueden bloquear conexiones externas',
      '• Intenta desactivar y activar el modo avión',
    ] : [
      '• Verifique se o Wi-Fi ou dados móveis estão ativos',
      '• Redes hospitalares podem bloquear conexões externas',
      '• Tente desativar e reativar o modo avião',
    ];

    return ErrorStateWidget(
      lang: lang,
      type: isAiError ? ErrorStateType.ai : ErrorStateType.network,
      onRetry: onRetry,
      message: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEs
                ? 'No se pudo conectar al servicio.'
                : 'Não foi possível conectar ao serviço.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: dark ? Colors.white60 : const Color(0xFF556655),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF0F4F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  tip,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: dark ? Colors.white54 : const Color(0xFF445544),
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ) as String?,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EMPTY STATE WIDGET
// Para listas vazias (histórico, anotações, etc.) — evita telas brancas.
//
// Exemplo:
//   if (items.isEmpty) {
//     return EmptyStateWidget(
//       icon: Icons.history_rounded,
//       title: 'Sem histórico ainda',
//       subtitle: 'Suas consultas com a IA aparecerão aqui.',
//       lang: lang,
//     );
//   }
// ═══════════════════════════════════════════════════════════════════════════════
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  subtitle;
  final String   lang;
  final Widget?  action;      // botão de ação opcional
  final Color?   iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.lang = 'pt',
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark  = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? _kGreen;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: dark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 34, color: color),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : const Color(0xFF0F1C14),
                letterSpacing: -0.2,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: dark ? Colors.white54 : const Color(0xFF778877),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MED FUTURE BUILDER
// FutureBuilder pré-configurado com:
//   • Loading: spinner verde centralizado
//   • Error:   ErrorStateWidget com retry
//   • Empty:   EmptyStateWidget
//   • Data:    builder personalizado
//
// Exemplo:
//   MedFutureBuilder<List<Protocol>>(
//     future: _loadProtocols(),
//     onRetry: _loadProtocols,
//     lang: p.lang,
//     emptyCheck: (data) => data.isEmpty,
//     emptyIcon: Icons.list_alt_rounded,
//     emptyTitle: 'Nenhum protocolo disponível',
//     builder: (ctx, data) => _ProtocolList(data),
//   );
// ═══════════════════════════════════════════════════════════════════════════════
class MedFutureBuilder<T> extends StatefulWidget {
  final Future<T> Function() futureFactory;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback? onRetry;
  final String lang;
  final bool Function(T)? emptyCheck;
  final IconData? emptyIcon;
  final String? emptyTitle;
  final String? emptySubtitle;
  final ErrorStateType errorType;
  final String? loadingMessage;

  const MedFutureBuilder({
    super.key,
    required this.futureFactory,
    required this.builder,
    this.onRetry,
    this.lang = 'pt',
    this.emptyCheck,
    this.emptyIcon,
    this.emptyTitle,
    this.emptySubtitle,
    this.errorType = ErrorStateType.network,
    this.loadingMessage,
  });

  @override
  State<MedFutureBuilder<T>> createState() => _MedFutureBuilderState<T>();
}

class _MedFutureBuilderState<T> extends State<MedFutureBuilder<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.futureFactory();
  }

  void _retry() {
    setState(() => _future = widget.futureFactory());
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<T>(
      future: _future,
      builder: (ctx, snap) {
        // ── Loading ──────────────────────────────────────────────────────
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36, height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _kGreen.withValues(alpha: dark ? 0.85 : 1.0),
                  ),
                ),
                if (widget.loadingMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    widget.loadingMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.white54 : const Color(0xFF778877),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // ── Erro ─────────────────────────────────────────────────────────
        if (snap.hasError) {
          final errMsg = snap.error?.toString() ?? '';
          final isNetwork = errMsg.toLowerCase().contains('socket') ||
              errMsg.toLowerCase().contains('network') ||
              errMsg.toLowerCase().contains('connection') ||
              errMsg.toLowerCase().contains('timeout') ||
              errMsg.toLowerCase().contains('unreachable');

          return ErrorStateWidget(
            lang: widget.lang,
            type: isNetwork ? ErrorStateType.network : widget.errorType,
            onRetry: _retry,
          );
        }

        // ── Sem dados ─────────────────────────────────────────────────────
        if (snap.hasData && widget.emptyCheck != null) {
          if (widget.emptyCheck!(snap.data as T)) {
            return EmptyStateWidget(
              icon: widget.emptyIcon ?? Icons.inbox_outlined,
              title: widget.emptyTitle ??
                  (widget.lang == 'es' ? 'Sin datos' : 'Sem dados'),
              subtitle: widget.emptySubtitle,
              lang: widget.lang,
            );
          }
        }

        // ── Dados ─────────────────────────────────────────────────────────
        if (snap.hasData) {
          return widget.builder(ctx, snap.data as T);
        }

        return const SizedBox.shrink();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MED STREAM BUILDER
// StreamBuilder pré-configurado com os mesmos estados que MedFutureBuilder.
//
// Exemplo (lista de protocolos em tempo real):
//   MedStreamBuilder<List<Protocol>>(
//     stream: protocolService.watchAll(),
//     lang: p.lang,
//     emptyCheck: (data) => data.isEmpty,
//     emptyIcon: Icons.list_alt_rounded,
//     emptyTitle: 'Nenhum protocolo disponível',
//     builder: (ctx, data) => _ProtocolList(data),
//   );
// ═══════════════════════════════════════════════════════════════════════════════
class MedStreamBuilder<T> extends StatelessWidget {
  final Stream<T>    stream;
  final Widget Function(BuildContext, T) builder;
  final String       lang;
  final bool Function(T)? emptyCheck;
  final IconData?    emptyIcon;
  final String?      emptyTitle;
  final String?      emptySubtitle;
  final ErrorStateType errorType;
  final T?           initialData;

  const MedStreamBuilder({
    super.key,
    required this.stream,
    required this.builder,
    this.lang = 'pt',
    this.emptyCheck,
    this.emptyIcon,
    this.emptyTitle,
    this.emptySubtitle,
    this.errorType = ErrorStateType.network,
    this.initialData,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return Center(
            child: SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _kGreen.withValues(alpha: dark ? 0.85 : 1.0),
              ),
            ),
          );
        }

        if (snap.hasError) {
          return ErrorStateWidget(lang: lang, type: errorType);
        }

        if (snap.hasData && emptyCheck != null) {
          if (emptyCheck!(snap.data as T)) {
            return EmptyStateWidget(
              icon: emptyIcon ?? Icons.inbox_outlined,
              title: emptyTitle ?? (lang == 'es' ? 'Sin datos' : 'Sem dados'),
              subtitle: emptySubtitle,
              lang: lang,
            );
          }
        }

        if (snap.hasData) {
          return builder(ctx, snap.data as T);
        }

        return const SizedBox.shrink();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NETWORK AWARE BUILDER
// Envolve qualquer widget e substitui por ErrorStateWidget se _hasError for true.
// Útil para wrapping de seções específicas sem refatorar toda a tela.
//
// Exemplo (wrapping de uma seção da tela de IA):
//   NetworkAwareBuilder(
//     hasError: _aiError,
//     isLoading: _loading,
//     lang: p.lang,
//     errorType: ErrorStateType.ai,
//     onRetry: _sendMessage,
//     child: _ChatArea(),
//   );
// ═══════════════════════════════════════════════════════════════════════════════
class NetworkAwareBuilder extends StatelessWidget {
  final bool     hasError;
  final bool     isLoading;
  final Widget   child;
  final String   lang;
  final ErrorStateType errorType;
  final VoidCallback?  onRetry;
  final String?        errorMessage;
  final Widget?        loadingWidget;

  const NetworkAwareBuilder({
    super.key,
    required this.hasError,
    required this.child,
    this.isLoading   = false,
    this.lang        = 'pt',
    this.errorType   = ErrorStateType.network,
    this.onRetry,
    this.errorMessage,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return loadingWidget ??
          Center(
            child: SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _kGreen.withValues(alpha: dark ? 0.85 : 1.0),
              ),
            ),
          );
    }

    if (hasError) {
      return ErrorStateWidget(
        lang: lang,
        type: errorType,
        message: errorMessage,
        onRetry: onRetry,
      );
    }

    return child;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INLINE CONNECTION BANNER
// Banner compacto exibido NO TOPO de uma tela quando há problema de conectividade,
// sem substituir toda a tela. Ideal para a tela de IA durante uma conversa ativa.
//
// Exemplo:
//   Column(children: [
//     if (_networkError) InlineConnectionBanner(lang: p.lang, onRetry: _retry),
//     Expanded(child: _ChatList()),
//   ]);
// ═══════════════════════════════════════════════════════════════════════════════
class InlineConnectionBanner extends StatelessWidget {
  final String       lang;
  final VoidCallback? onRetry;
  final String?      message;
  final bool         isAiError;

  const InlineConnectionBanner({
    super.key,
    this.lang      = 'pt',
    this.onRetry,
    this.message,
    this.isAiError = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = isAiError ? _kGreen : _kBlue;
    final icon  = isAiError
        ? Icons.psychology_outlined
        : Icons.wifi_off_rounded;

    final defaultMsg = isAiError
        ? (isEs ? 'IA no disponible. Verifica tu conexión.' : 'IA indisponível. Verifique sua conexão.')
        : (isEs ? 'Sin conexión a internet.' : 'Sem conexão com a internet.');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.15 : 0.08),
        border: Border(
          bottom: BorderSide(
            color: color.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message ?? defaultMsg,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: dark
                  ? color.withValues(alpha: 0.9)
                  : color,
            ),
          ),
        ),
        if (onRetry != null)
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: color.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(
                isEs ? 'Reintentar' : 'Tentar novamente',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
