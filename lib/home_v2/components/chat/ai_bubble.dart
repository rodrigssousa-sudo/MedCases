// ============================================================================
// MEDCASES PRO
// HOME V2
// AI BUBBLE
// ============================================================================

import 'package:flutter/material.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'chat_theme.dart';

class AiBubble extends StatelessWidget {
  final String text;

  final bool isError;

  final bool isStreaming;

  final VoidCallback? onExpand;

  const AiBubble({
    super.key,
    required this.text,
    this.isError = false,
    this.isStreaming = false,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final Color background =
        isError ? ChatTheme.errorBubble : ChatTheme.aiBubble;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: ChatTheme.avatar,
          height: ChatTheme.avatar,
          decoration: BoxDecoration(
            color: ChatTheme.primary.withOpacity(.08),
            shape: BoxShape.circle,
          ),
          child: SvgPicture.asset(
            'assets/icons/home_v2/ic_ia.svg',
            width: 22,
            height: 22,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(
                ChatTheme.radius,
              ),
              border: Border.all(
                color: ChatTheme.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: ChatTheme.text,
                  ),
                ),
                if (onExpand != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onExpand,
                      child: const Text(
                        "Ver resposta completa",
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
