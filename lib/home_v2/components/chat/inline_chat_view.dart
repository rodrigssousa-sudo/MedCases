import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../theme/home_v2_palette.dart';
import '../common/home_v2_press_surface.dart';

Color _homeAccent(HomeV2Palette palette) {
  return identical(palette, HomeV2Palette.dark)
      ? const Color(0xFF00E59B)
      : palette.accent;
}

class HomeInlineChatV2View extends StatelessWidget {
  const HomeInlineChatV2View({
    required this.dark,
    required this.isEs,
    required this.userName,
    required this.messages,
    required this.streaming,
    required this.thinking,
    required this.expanded,
    required this.hasExpandableContent,
    required this.controller,
    required this.focusNode,
    required this.scrollController,
    required this.onSend,
    required this.onVoice,
    required this.sttListening,
    required this.onHistory,
    required this.onNewChat,
    required this.onToggleExpanded,
    required this.onCopyAnswer,
    required this.onContinueInAi,
    super.key,
  });

  final bool dark;
  final bool isEs;
  final String userName;
  final List<Map<String, dynamic>> messages;
  final String streaming;
  final bool thinking;
  final bool expanded;
  final bool hasExpandableContent;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final VoidCallback onVoice;
  final bool sttListening;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onCopyAnswer;
  final VoidCallback onContinueInAi;

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);

    final validMessages = messages.where((message) {
      final text = message['text']?.toString().trim() ?? '';
      return text.isNotEmpty && text != 'AUTH_REQUIRED';
    }).toList(growable: false);

    final visibleMessages = expanded || validMessages.length <= 4
        ? validMessages
        : validMessages.sublist(validMessages.length - 4);

    var latestCompletedAiIndex = -1;

    for (var index = 0; index < visibleMessages.length; index++) {
      final message = visibleMessages[index];

      if (message['role'] == 'ai' && message['isError'] != true) {
        latestCompletedAiIndex = index;
      }
    }

    final completedAiCount = validMessages.where((message) {
      return message['role'] == 'ai' && message['isError'] != true;
    }).length;

    // A resposta ativa mantém o mesmo índice lógico antes e depois
    // de ser consolidada no histórico.
    final activeAiKeyIndex = thinking ? completedAiCount : completedAiCount - 1;

    final hasConversation =
        visibleMessages.isNotEmpty || streaming.trim().isNotEmpty || thinking;

    return HomeV2PressSurface(
      palette: palette,
      backgroundColor:
          hasConversation ? palette.surfaceActive : palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InlineChatHeader(
            palette: palette,
            isEs: isEs,
            expanded: expanded,
            hasExpandableContent: hasExpandableContent,
            onHistory: onHistory,
            onNewChat: onNewChat,
            onToggleExpanded: onToggleExpanded,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasConversation) ...[
                  _InlineConversationGreeting(
                    palette: palette,
                    isEs: isEs,
                    userName: userName,
                  ),
                  const SizedBox(height: 16),
                  for (var index = 0; index < visibleMessages.length; index++)
                    _InlineMessage(
                      key: !thinking &&
                              index == latestCompletedAiIndex &&
                              visibleMessages[index]['role'] == 'ai'
                          ? ValueKey<String>(
                              'home-inline-active-ai-$activeAiKeyIndex',
                            )
                          : ValueKey<String>(
                              'home-inline-message-$index',
                            ),
                      text: visibleMessages[index]['text']?.toString() ?? '',
                      isUser: visibleMessages[index]['role'] == 'user',
                      isError: visibleMessages[index]['isError'] == true,
                      isStreaming: false,
                      showActions: !thinking && index == latestCompletedAiIndex,
                      palette: palette,
                      isEs: isEs,
                      onCopyAnswer: onCopyAnswer,
                      onContinueInAi: onContinueInAi,
                    ),
                  if (thinking && streaming.trim().isNotEmpty)
                    _InlineMessage(
                      key: ValueKey<String>(
                        'home-inline-active-ai-$activeAiKeyIndex',
                      ),
                      text: streaming,
                      isUser: false,
                      isError: false,
                      isStreaming: true,
                      showActions: false,
                      palette: palette,
                      isEs: isEs,
                      onCopyAnswer: onCopyAnswer,
                      onContinueInAi: onContinueInAi,
                    ),
                  if (thinking && streaming.trim().isEmpty)
                    _InlineThinking(
                      palette: palette,
                      isEs: isEs,
                    ),
                ] else
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 142,
                    ),
                    child: Center(
                      child: _InlineEmptyGreeting(
                        palette: palette,
                        isEs: isEs,
                        userName: userName,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: _InlineComposer(
                    palette: palette,
                    isEs: isEs,
                    controller: controller,
                    focusNode: focusNode,
                    thinking: thinking,
                    onSend: onSend,
                    onVoice: onVoice,
                    sttListening: sttListening,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineChatHeader extends StatelessWidget {
  const _InlineChatHeader({
    required this.palette,
    required this.isEs,
    required this.expanded,
    required this.hasExpandableContent,
    required this.onHistory,
    required this.onNewChat,
    required this.onToggleExpanded,
  });

  final HomeV2Palette palette;
  final bool isEs;
  final bool expanded;
  final bool hasExpandableContent;
  final VoidCallback onHistory;
  final VoidCallback onNewChat;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: hasExpandableContent ? onToggleExpanded : null,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 11, 6),
              decoration: BoxDecoration(
                color: palette.surfaceStrong,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: palette.border,
                  width: 0.6,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    'assets/icons/home_v2/ic_ia.svg',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.65,
                      ),
                      children: [
                        TextSpan(
                          text: 'MedCases ',
                          style: TextStyle(
                            color: palette.textPrimary,
                          ),
                        ),
                        TextSpan(
                          text: 'IA',
                          style: TextStyle(
                            color: _homeAccent(palette),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _HeaderAction(
            icon: Icons.add_rounded,
            tooltip: isEs ? 'Nuevo chat' : 'Novo chat',
            palette: palette,
            onTap: onNewChat,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final HomeV2Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          overlayColor: palette.pressedOverlay,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              icon,
              size: 17,
              color: palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineEmptyGreeting extends StatelessWidget {
  const _InlineEmptyGreeting({
    required this.palette,
    required this.isEs,
    required this.userName,
  });

  final HomeV2Palette palette;
  final bool isEs;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _InlineGreetingLine(
            palette: palette,
            isEs: isEs,
            userName: userName,
            fontSize: 22,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 7),
          Text(
            isEs
                ? 'Describe el caso o la duda clínica.'
                : 'Descreva o caso ou a dúvida clínica.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineConversationGreeting extends StatelessWidget {
  const _InlineConversationGreeting({
    required this.palette,
    required this.isEs,
    required this.userName,
  });

  final HomeV2Palette palette;
  final bool isEs;
  final String userName;

  @override
  Widget build(BuildContext context) {
    return _InlineGreetingLine(
      palette: palette,
      isEs: isEs,
      userName: userName,
      fontSize: 14,
      textAlign: TextAlign.left,
    );
  }
}

class _InlineGreetingLine extends StatelessWidget {
  const _InlineGreetingLine({
    required this.palette,
    required this.isEs,
    required this.userName,
    required this.fontSize,
    required this.textAlign,
  });

  final HomeV2Palette palette;
  final bool isEs;
  final String userName;
  final double fontSize;
  final TextAlign textAlign;

  String _greetingForCurrentHour() {
    final hour = DateTime.now().hour;

    if (hour < 6) {
      return isEs ? 'Buena madrugada' : 'Boa madrugada';
    }

    if (hour < 12) {
      return isEs ? 'Buen día' : 'Bom dia';
    }

    if (hour < 18) {
      return isEs ? 'Buenas tardes' : 'Boa tarde';
    }

    return isEs ? 'Buenas noches' : 'Boa noite';
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greetingForCurrentHour();
    final normalizedName = userName.trim();

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          height: 1.15,
          fontWeight: FontWeight.w800,
        ),
        children: [
          TextSpan(
            text: greeting,
            style: TextStyle(
              color: _homeAccent(palette),
            ),
          ),
          if (normalizedName.isNotEmpty)
            TextSpan(
              text: ', $normalizedName',
              style: TextStyle(
                color: palette.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.text,
    required this.isUser,
    required this.isError,
    required this.isStreaming,
    required this.showActions,
    required this.palette,
    required this.isEs,
    required this.onCopyAnswer,
    required this.onContinueInAi,
    super.key,
  });

  final String text;
  final bool isUser;
  final bool isError;
  final bool isStreaming;
  final bool showActions;
  final HomeV2Palette palette;
  final bool isEs;
  final ValueChanged<String> onCopyAnswer;
  final VoidCallback onContinueInAi;

  @override
  Widget build(BuildContext context) {
    if (isUser) {
      return _InlineQuestion(
        text: text,
        palette: palette,
        isEs: isEs,
      );
    }

    return _InlineAnswer(
      text: text,
      palette: palette,
      isEs: isEs,
      isError: isError,
      isStreaming: isStreaming,
      showActions: showActions,
      onCopyAnswer: onCopyAnswer,
      onContinueInAi: onContinueInAi,
    );
  }
}

class _InlineQuestion extends StatelessWidget {
  const _InlineQuestion({
    required this.text,
    required this.palette,
    required this.isEs,
  });

  final String text;
  final HomeV2Palette palette;
  final bool isEs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 20,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: _homeAccent(palette),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'PREGUNTA' : 'PERGUNTA',
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 10.2,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.25,
                    ),
                  ),
                  const SizedBox(height: 7),
                  SelectableText(
                    text,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13.6,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineAnswer extends StatelessWidget {
  const _InlineAnswer({
    required this.text,
    required this.palette,
    required this.isEs,
    required this.isError,
    required this.isStreaming,
    required this.showActions,
    required this.onCopyAnswer,
    required this.onContinueInAi,
  });

  final String text;
  final HomeV2Palette palette;
  final bool isEs;
  final bool isError;
  final bool isStreaming;
  final bool showActions;
  final ValueChanged<String> onCopyAnswer;
  final VoidCallback onContinueInAi;

  @override
  Widget build(BuildContext context) {
    final title = isStreaming
        ? (isEs ? 'GENERANDO RESPUESTA' : 'GERANDO RESPOSTA')
        : (isEs ? 'RESPUESTA COMPLETADA' : 'RESPOSTA CONCLUÍDA');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        5,
        0,
        5,
        showActions ? 14 : 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              isError
                  ? Icon(
                      Icons.error_outline_rounded,
                      color: _homeAccent(palette),
                      size: 16,
                    )
                  : SvgPicture.asset(
                      'assets/icons/home_v2/ic_ia.svg',
                      width: 18,
                      height: 18,
                      fit: BoxFit.contain,
                    ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 10.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),

          // O mesmo MarkdownBody permanece montado durante a revelação e após
          // a conclusão. Não existe mais troca SelectableText → MarkdownBody.
          MarkdownBody(
            data: text,
            // O gesto vertical pertence ao scroll da Home V2.
            // A cópia integral continua disponível pelo botão Copiar.
            selectable: false,
            softLineBreak: true,
            styleSheet: MarkdownStyleSheet(
              p: TextStyle(
                color: isError ? _homeAccent(palette) : palette.textPrimary,
                fontSize: 13.5,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
              h1: TextStyle(
                color: palette.textPrimary,
                fontSize: 14.2,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
              h2: TextStyle(
                color: palette.textPrimary,
                fontSize: 13.9,
                height: 1.4,
                fontWeight: FontWeight.w800,
              ),
              h3: TextStyle(
                color: palette.textPrimary,
                fontSize: 13.6,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
              listBullet: TextStyle(
                color: palette.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
              strong: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              em: TextStyle(
                color: palette.textPrimary,
                fontStyle: FontStyle.italic,
              ),
              blockSpacing: 12,
              listIndent: 20,
              blockquotePadding: const EdgeInsets.fromLTRB(11, 7, 10, 7),
              blockquoteDecoration: BoxDecoration(
                color: palette.surfaceStrong,
                border: Border(
                  left: BorderSide(
                    color: _homeAccent(palette),
                    width: 2,
                  ),
                ),
              ),
              code: TextStyle(
                color: palette.textPrimary,
                fontSize: 12.3,
                height: 1.4,
                backgroundColor: palette.surfaceStrong,
              ),
              codeblockPadding: const EdgeInsets.all(10),
              codeblockDecoration: BoxDecoration(
                color: palette.surfaceStrong,
                borderRadius: BorderRadius.circular(5),
              ),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: palette.dividerStrong,
                    width: 0.6,
                  ),
                ),
              ),
            ),
          ),
          if (showActions) ...[
            const SizedBox(height: 16),
            Divider(
              height: 1,
              thickness: 0.6,
              color: palette.dividerStrong,
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                _InlineAnswerAction(
                  label: 'Copiar',
                  icon: Icons.copy_all_outlined,
                  palette: palette,
                  onTap: () => onCopyAnswer(text),
                ),
                _InlineAnswerAction(
                  label: isEs ? 'Continuar en IA' : 'Continuar na IA',
                  icon: Icons.arrow_forward_rounded,
                  palette: palette,
                  accent: true,
                  onTap: onContinueInAi,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineAnswerAction extends StatelessWidget {
  const _InlineAnswerAction({
    required this.label,
    required this.icon,
    required this.palette,
    required this.onTap,
    this.accent = false,
  });

  final String label;
  final IconData icon;
  final HomeV2Palette palette;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? _homeAccent(palette) : palette.textSecondary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        overlayColor: palette.pressedOverlay,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineThinking extends StatelessWidget {
  const _InlineThinking({
    required this.palette,
    required this.isEs,
  });

  final HomeV2Palette palette;
  final bool isEs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/home_v2/ic_ia.svg',
                width: 18,
                height: 18,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 8),
              Text(
                isEs ? 'GENERANDO RESPUESTA' : 'GERANDO RESPOSTA',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 10.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 52,
            child: LinearProgressIndicator(
              minHeight: 2,
              borderRadius: BorderRadius.circular(4),
              color: _homeAccent(palette),
              backgroundColor: palette.surfaceStrong,
            ),
          ),
        ],
      ),
    );
  }
}

Color _homeComposerUnifiedFill(
  HomeV2Palette palette,
) {
  return identical(palette, HomeV2Palette.dark)
      ? palette.surfaceSoft
      : palette.surfaceStrong;
}

class _InlineComposer extends StatelessWidget {
  const _InlineComposer({
    required this.palette,
    required this.isEs,
    required this.controller,
    required this.focusNode,
    required this.thinking,
    required this.onSend,
    required this.onVoice,
    required this.sttListening,
  });

  final HomeV2Palette palette;
  final bool isEs;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool thinking;
  final VoidCallback onSend;
  final VoidCallback onVoice;
  final bool sttListening;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _homeComposerUnifiedFill(palette),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: 50,
        ),
        padding: const EdgeInsets.fromLTRB(11, 3, 3, 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: palette.border,
            width: 0.6,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Tooltip(
              message: sttListening
                  ? (isEs ? 'Detener dictado' : 'Parar ditado')
                  : (isEs ? 'Dictar mensaje' : 'Ditar mensagem'),
              child: Material(
                color: sttListening
                    ? const Color(
                        0xFFEF4444,
                      ).withValues(
                        alpha: 0.12,
                      )
                    : Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: thinking ? null : onVoice,
                  customBorder: const CircleBorder(),
                  overlayColor: palette.pressedOverlay,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      sttListening
                          ? Icons.stop_rounded
                          : Icons.mic_none_rounded,
                      size: 20,
                      color: sttListening
                          ? const Color(
                              0xFFEF4444,
                            )
                          : palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !thinking,
                minLines: 1,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  if (!thinking) {
                    onSend();
                  }
                },
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 14,
                  height: 1.4,
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
                    vertical: 9,
                  ),
                  hintText: isEs
                      ? 'Escribe una duda clínica...'
                      : 'Digite uma dúvida clínica...',
                  hintStyle: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: thinking ? null : onSend,
                customBorder: const CircleBorder(),
                overlayColor: palette.pressedOverlay,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    size: 19,
                    color:
                        thinking ? palette.textSecondary : _homeAccent(palette),
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
