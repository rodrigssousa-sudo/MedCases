import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  // BUILD 334: _keyboardListenerNode removido — KeyboardListener substituído por
  // Focus.onKeyEvent que retorna KeyEventResult.handled para consumir Enter sem \n.

  @override
  void didUpdateWidget(PromptComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // AUTO-FOCUS: quando IA conecta (false→true), libera teclado imediatamente
    // O médico não precisa tocar de novo no campo — fluxo contínuo pós-conexão
    if (!oldWidget.isConnected && widget.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = widget.dark;
    final bool isEs = widget.lang == 'es';
    final bool isListening = widget.sttListening;
    final double level = widget.sttSoundLevel;
    // ADENDO SEGURANÇA Factor 1: campo completamente bloqueado quando desconectado
    final bool locked = !widget.isConnected;

    // ── Cores do campo de texto — cápsula unificada Build 158.2
    final textCol = dark ? Colors.white : const Color(0xFF1A1D23);
    final hintCol = dark ? Colors.white30 : Colors.black38;

    // ── Cor do microfone
    final micCol = isListening
        ? const Color(0xFFEF4444)
        : (dark ? Colors.white60 : Colors.black45);

    // ── Cor das barras de onda
    final waveColor = isListening
        ? const Color(0xFFEF4444)
        : (dark ? Colors.white54 : Colors.black38);

    // ── Tooltip do microfone — bilíngue
    final micTip = isListening
        ? (isEs ? 'Detener dictado' : 'Parar ditado')
        : (isEs ? 'Dictar mensaje' : 'Ditar mensagem');

    // ── Texto de status STT — bilíngue, peso leve, sutil
    final statusText = isListening
        ? (isEs ? 'Escuchando…' : 'Ouvindo…')
        : (isEs
            ? 'Micrófono listo. Toca para dictar.'
            : 'Microfone pronto. Toque para ditar.');

    // ── Build 158.2: Cápsula unificada — mic + campo + envio em UMA pílula ──
    // Design baseado no mockup image_84dcca: BorderRadius.circular(30),
    // fundo escuro translúcido, sem bordas internas, sem caixas separadas.
    // O mic, TextField e seta vivem juntos na mesma Row interna da pílula.
    //
    // UX INTERCEPT: GestureDetector externo captura toque em TODA a pílula quando
    // locked=true — dispara onConnectTap (modal de conexão) antes que qualquer
    // widget filho (TextField disabled) absorva o evento.
    // HitTestBehavior.translucent: toque passa por áreas transparentes da pílula.
    return GestureDetector(
      onTap: locked ? widget.onConnectTap : null,
      behavior: HitTestBehavior.translucent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            16, 2.5, 16, 12), // SUPER ORDEM 11: bottom:12 clearance
        // PERF-FIX: ClipRRect com borderRadius const + RepaintBoundary
        // isolam o BackdropFilter do Impeller — o motor não precisa
        // recalcular o shape do clipper a cada rebuild do painel STT.
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(30)),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 14, sigmaY: 14), // ORDEM VISUAL 02: fosco limpo
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  // ORDEM VISUAL 02: grafite escuro / off-white lêtoso
                  color: dark
                      ? const Color(0xFF16181D).withOpacity(0.75)
                      : const Color(0xFFF9FAFB).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: widget.hasFocus
                        ? const Color(0xFF00E5FF).withOpacity(0.55)
                        : (dark
                            ? const Color(0xFF374151).withOpacity(0.45)
                            : const Color(0xFFD1D6DC).withOpacity(0.60)),
                    width: widget.hasFocus
                        ? 1.2
                        : 0.5, // ORDEM VISUAL 02: borda 0.5px em repouso
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4), // ORDEM VISUAL 02: slim
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Painel STT — onda de áudio ou campo de texto ─────────
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState: isListening
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,

                      // ── Estado normal: mic + TextField + send dentro da pílula
                      firstChild: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Botão microfone — sem container separado, ícone direto
                          Tooltip(
                            message: micTip,
                            child: GestureDetector(
                              onTap: widget.onVoice,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(right: 8, left: 2),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isListening
                                        ? const Color(0xFFEF4444)
                                            .withOpacity(0.15)
                                        : Colors.transparent,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isListening
                                          ? Icons.mic_rounded
                                          : Icons.mic_none_rounded,
                                      size: 20,
                                      color: micCol,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // ADENDO SEGURANÇA Factor 1: TextField bloqueado quando desconectado
                          // readOnly=true impede abertura do teclado físico
                          // enabled=false desativa interação completa com o campo
                          //
                          // BUILD 334 — Enter=send (WhatsApp/ChatGPT style):
                          // Focus.onKeyEvent retorna KeyEventResult.handled para consumir
                          // o evento de Enter sem Shift/Ctrl, impedindo inserção do \n e
                          // disparando onSend() imediatamente. Funciona em Web + desktop.
                          // Shift+Enter: KeyEventResult.ignored → TextField insere \n normalmente.
                          Expanded(
                            child: Focus(
                              onKeyEvent: (node, event) {
                                // Factor 1: bloqueio absoluto se desconectado
                                if (locked) return KeyEventResult.ignored;
                                // Apenas KeyDown — ignora KeyUp/KeyRepeat para evitar duplo disparo
                                if (event is! KeyDownEvent)
                                  return KeyEventResult.ignored;
                                if (event.logicalKey !=
                                    LogicalKeyboardKey.enter) {
                                  return KeyEventResult.ignored;
                                }
                                // Shift+Enter ou Ctrl+Enter → quebra de linha normal
                                if (HardwareKeyboard.instance.isShiftPressed ||
                                    HardwareKeyboard
                                        .instance.isControlPressed) {
                                  return KeyEventResult.ignored;
                                }
                                // Enter limpo + não pensando → envia e consome o evento
                                if (!widget.thinking) {
                                  widget.onSend();
                                }
                                // Retorna handled para impedir o \n no TextField
                                return KeyEventResult.handled;
                              },
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxHeight: 140),
                                child: TextField(
                                  controller: widget.ctrl,
                                  focusNode: widget.focusNode,
                                  // BUILD 332 Fix 4: multiline UX (WhatsApp/ChatGPT style)
                                  maxLines: null,
                                  minLines: 1,
                                  textInputAction: TextInputAction.newline,
                                  keyboardType: TextInputType.multiline,
                                  autofillHints: const [],
                                  enableSuggestions: true,
                                  autocorrect: true,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  // ADENDO SEGURANÇA Factor 1: campo desativado quando não conectado
                                  enabled: !locked, // impede interação total
                                  readOnly:
                                      locked, // dupla redundância — teclado não sobe
                                  // ── BUILD 303 SECURITY PATCH: onSubmitted LOCKED ──────────────────
                                  // TextInputAction.send pode disparar onSubmitted em teclados mobile
                                  // mesmo com enabled:false em algumas implementações de plataforma.
                                  // Interceptamos AQUI com verificação explícita de locked e de auth
                                  // — zero confiança: se bloqueado, fecha teclado e retorna imediato.
                                  // BUILD 334: em Web/desktop, Enter já é interceptado pelo Focus
                                  // acima — onSubmitted serve de fallback para teclados mobile que
                                  // ignoram o Focus.onKeyEvent e disparam via IME action button.
                                  onSubmitted: (value) {
                                    if (locked) {
                                      // Bloqueio absoluto: fecha teclado e NÃO propaga nada
                                      FocusScope.of(context).unfocus();
                                      return;
                                    }
                                    if (!widget.thinking) {
                                      widget.onSend();
                                    }
                                  },
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: locked
                                        ? (dark
                                            ? Colors.white24
                                            : Colors.black26)
                                        : textCol,
                                    height: 1.5,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: locked
                                        ? (isEs
                                            ? 'Conecta la IA para escribir'
                                            : 'Conecte a IA para escrever')
                                        : widget.hint,
                                    hintStyle: TextStyle(
                                      fontSize: 14,
                                      color: locked
                                          ? (dark
                                              ? Colors.white24
                                              : Colors.black26)
                                          : hintCol,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ), // ConstrainedBox maxHeight:140
                            ),
                          ),

                          const SizedBox(width: 6),

                          // BUILD 327+: ABORT STREAM button replaces send while thinking.
                          // — thinking=true  → vermelho-subtil com ícone ✕ (aborta stream)
                          // — thinking=false → ciano sólido com seta ↑  (envia mensagem)
                          // — locked=true    → cinza desativado (desconectado)
                          GestureDetector(
                            onTap: locked
                                ? null
                                : (widget.thinking
                                    ? widget.onCancel
                                    : widget.onSend),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: locked
                                    ? (dark ? Colors.white12 : Colors.black12)
                                    : (widget.thinking
                                        // Abort: vermelho escuro sutil (não alarme)
                                        ? const Color(0xFF7B2020)
                                            .withOpacity(0.85)
                                        : const Color(0xFF008CA4)),
                                // Borda vermelha subtil apenas no estado de abort
                                border: (!locked && widget.thinking)
                                    ? Border.all(
                                        color: const Color(0xFFEF4444)
                                            .withOpacity(0.45),
                                        width: 1.2,
                                      )
                                    : null,
                              ),
                              child: Center(
                                child: widget.thinking
                                    ? const Icon(
                                        Icons.stop_rounded,
                                        color: Colors.white,
                                        size: 17,
                                      )
                                    : Icon(
                                        Icons.arrow_upward_rounded,
                                        color: locked
                                            ? Colors.white38
                                            : Colors.white,
                                        size: 19,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Estado STT ativo: onda de áudio centralizada ────────
                      secondChild: SizedBox(
                        height: 48,
                        child: Row(
                          children: [
                            // Botão parar ditado
                            Tooltip(
                              message: micTip,
                              child: GestureDetector(
                                onTap: widget.onVoice,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36,
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFEF4444)
                                        .withOpacity(0.12),
                                    border: Border.all(
                                      color: const Color(0xFFEF4444)
                                          .withOpacity(0.50),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.mic_off_outlined,
                                      size: 17,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Onda de áudio + texto de status
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Onda animada
                                  _PromptAudioWave(
                                    level: level,
                                    activeColor: waveColor,
                                  ),
                                  const SizedBox(height: 5),
                                  // Texto de status — leve, sutil, bilíngue
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                      color: dark
                                          ? Colors.white.withOpacity(0.50)
                                          : Colors.black.withOpacity(0.45),
                                      height: 1.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ), // RepaintBoundary
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner de erro de IA — aparece abaixo do header quando IA retorna erro
// Cobre tanto erros de chave OpenAI quanto token Gemini expirado
// ─────────────────────────────────────────────────────────────────────────────
