import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../home_v2/theme/home_v2_palette.dart';

/// Compositor multiplataforma do prompt clínico.
///
/// Preserva bloqueio de autenticação, STT, cancelamento de streaming,
/// Enter para envio, Shift/Ctrl+Enter para nova linha e foco pós-conexão.
class _PromptAudioWave extends StatelessWidget {
  final double level; // 0.0–1.0 normalizado
  final Color activeColor; // cor das barras ativas
  const _PromptAudioWave({required this.level, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    // 5 fatores de altura distintos — cria perfil de onda orgânica
    const factors = [0.55, 0.80, 1.00, 0.80, 0.55];
    const maxH = 22.0; // altura máxima de cada barra em px
    const minH = 2.5; // altura mínima (ponto estático em silêncio)

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(factors.length, (i) {
        final targetH = level < 0.03
            ? minH
            : (minH + (maxH - minH) * level * factors[i]).clamp(minH, maxH);
        return Padding(
          padding: EdgeInsets.only(right: i < factors.length - 1 ? 3.0 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            width: 2.0,
            height: targetH,
            decoration: BoxDecoration(
              color: level < 0.03
                  ? activeColor.withOpacity(0.35)
                  : activeColor.withOpacity(0.85),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }),
    );
  }
}

class PromptComposer extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final bool dark;
  final bool hasFocus;
  final bool thinking;
  final VoidCallback onSend;

  /// BUILD 327+: cancelar stream ativo — exibido no lugar do send quando thinking=true.
  /// Ao tocar: aborta a stream, reseta _isStreaming/_thinking, devolve foco ao campo.
  final VoidCallback? onCancel;
  final VoidCallback onVoice;
  final bool sttListening;
  final double sttSoundLevel;
  final String hint;
  final String lang;
  // ADENDO SEGURANÇA: Factor 1 — isConnected desativa campo + botão + Enter
  // false = usuário sem sessão de IA real → teclado bloqueado, seta cinza, nenhum envio
  final bool isConnected;
  // UX INTERCEPT: quando locked=true, qualquer toque no campo abre modal de conexão
  // null = comportamento anterior (nenhuma ação no toque do campo bloqueado)
  final VoidCallback? onConnectTap;
  const PromptComposer({
    required this.ctrl,
    required this.focusNode,
    required this.dark,
    required this.hasFocus,
    required this.thinking,
    required this.onSend,
    required this.onVoice,
    required this.sttListening,
    required this.sttSoundLevel,
    required this.hint,
    required this.lang,
    this.isConnected = true, // default true para não quebrar call sites legados
    this.onConnectTap, // dispara modal de conexão quando campo está bloqueado
    this.onCancel, // BUILD 327+: abort stream ativo
  });

  @override
  State<PromptComposer> createState() => _PromptComposerState();
}

class _PromptComposerState extends State<PromptComposer> {
  @override
  void didUpdateWidget(PromptComposer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isConnected && widget.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final isEs = widget.lang == 'es';
    final isListening = widget.sttListening;
    final level = widget.sttSoundLevel;
    final locked = !widget.isConnected;
    final palette = HomeV2Palette.resolve(dark);

    // MEDCASES_AI_LIGHT_COMPOSER_UNIFIED_SURFACE_V1_B_R0
    // Light: uma superfície grafite contínua; campo interno transparente.
    // Dark: mantém os mesmos tokens canônicos anteriores.
    final composerSurface =
        dark ? palette.surfaceSoft : const Color(0xFF59636E);
    final composerText = dark ? palette.textPrimary : Colors.white;
    final composerSecondary = dark
        ? palette.textSecondary
        : Colors.white.withValues(alpha: 0.78);
    final composerBorder = dark
        ? (widget.hasFocus ? palette.borderActive : palette.border)
        : (widget.hasFocus ? palette.accent : const Color(0xFF59636E));

    final disabledColor =
        (dark ? palette.textSecondary : Colors.white).withValues(
      alpha: 0.42,
    );

    final micColor =
        isListening ? const Color(0xFFEF4444) : composerSecondary;

    final waveColor =
        isListening ? const Color(0xFFEF4444) : composerSecondary;

    final micTip = isListening
        ? (isEs ? 'Detener dictado' : 'Parar ditado')
        : (isEs ? 'Dictar mensaje' : 'Ditar mensagem');

    final sendTip = widget.thinking
        ? (isEs ? 'Detener respuesta' : 'Parar resposta')
        : (isEs ? 'Enviar mensaje' : 'Enviar mensagem');

    final statusText = isListening
        ? (isEs ? 'Escuchando…' : 'Ouvindo…')
        : (isEs
            ? 'Micrófono listo. Toca para dictar.'
            : 'Microfone pronto. Toque para ditar.');

    final visualHint =
        isEs ? 'Escribe una duda clínica...' : 'Escreva uma dúvida clínica...';

    Widget microphoneButton({
      bool stopMode = false,
    }) {
      return Tooltip(
        message: micTip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: locked ? null : widget.onVoice,
            borderRadius: BorderRadius.circular(9),
            overlayColor: palette.pressedOverlay,
            splashFactory: NoSplash.splashFactory,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: Icon(
                  stopMode
                      ? Icons.mic_off_outlined
                      : (isListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded),
                  size: stopMode ? 17 : 20,
                  color: locked ? disabledColor : micColor,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget sendButton() {
      final VoidCallback? callback =
          locked ? null : (widget.thinking ? widget.onCancel : widget.onSend);

      final color = locked
          ? disabledColor
          : (widget.thinking ? const Color(0xFFEF4444) : palette.accent);

      return Tooltip(
        message: sendTip,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: callback,
                customBorder: const CircleBorder(),
                overlayColor: palette.pressedOverlay,
                splashFactory: NoSplash.splashFactory,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -1.4),
                      child: Icon(
                        widget.thinking
                            ? Icons.stop_rounded
                            : Icons.arrow_upward_rounded,
                        size: widget.thinking ? 17 : 21,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget normalComposer() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          microphoneButton(),
          Expanded(
            child: Focus(
              onKeyEvent: (node, event) {
                if (locked) {
                  return KeyEventResult.ignored;
                }

                if (event is! KeyDownEvent) {
                  return KeyEventResult.ignored;
                }

                if (event.logicalKey != LogicalKeyboardKey.enter) {
                  return KeyEventResult.ignored;
                }

                if (HardwareKeyboard.instance.isShiftPressed ||
                    HardwareKeyboard.instance.isControlPressed) {
                  return KeyEventResult.ignored;
                }

                if (!widget.thinking) {
                  widget.onSend();
                }

                return KeyEventResult.handled;
              },
              child: TextField(
                controller: widget.ctrl,
                focusNode: widget.focusNode,
                enabled: !locked,
                readOnly: locked,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                autofillHints: const [],
                enableSuggestions: true,
                autocorrect: true,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) {
                  if (locked) {
                    FocusScope.of(context).unfocus();
                    return;
                  }

                  if (!widget.thinking) {
                    widget.onSend();
                  }
                },
                style: TextStyle(
                  color: locked ? disabledColor : composerText,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  hintText: locked
                      ? (isEs
                          ? 'Conecta la IA para escribir'
                          : 'Conecte a IA para escrever')
                      : visualHint,
                  hintStyle: TextStyle(
                    color: locked ? disabledColor : composerSecondary,
                    fontSize: 13.5,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          sendButton(),
        ],
      );
    }

    Widget listeningComposer() {
      return SizedBox(
        height: 48,
        child: Row(
          children: [
            microphoneButton(
              stopMode: true,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PromptAudioWave(
                    level: level,
                    activeColor: waveColor,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: composerSecondary,
                      fontSize: 12.5,
                      height: 1.3,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: locked ? widget.onConnectTap : null,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          2.5,
          16,
          12,
        ),
        child: Material(
          color: composerSurface,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 50,
            ),
            padding: const EdgeInsets.fromLTRB(
              11,
              3,
              3,
              3,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: composerBorder,
                width: 0.6,
              ),
            ),
            child: AnimatedCrossFade(
              duration: const Duration(
                milliseconds: 180,
              ),
              crossFadeState: isListening
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: normalComposer(),
              secondChild: listeningComposer(),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner de erro de IA — aparece abaixo do header quando IA retorna erro
// Cobre tanto erros de chave OpenAI quanto token Gemini expirado
// ─────────────────────────────────────────────────────────────────────────────
