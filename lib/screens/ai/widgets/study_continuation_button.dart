import 'dart:async';

import 'package:flutter/material.dart';

/// Continuação pedagógica linear do Modo Estudo.
///
/// A pergunta vem de NEXT_ACTION_PROMPT, permanece fora do Markdown e é
/// enviada automaticamente ao toque. Não utiliza a identidade visual azul
/// dos botões de ação clínica.
class StudyContinuationButton extends StatefulWidget {
  final String question;
  final bool dark;
  final VoidCallback onTap;

  const StudyContinuationButton({
    super.key,
    required this.question,
    required this.dark,
    required this.onTap,
  });

  @override
  State<StudyContinuationButton> createState() =>
      _StudyContinuationButtonState();
}

class _StudyContinuationButtonState extends State<StudyContinuationButton> {
  Timer? _unlockTimer;
  bool _tapLocked = false;

  void _handleTap() {
    if (_tapLocked) return;

    setState(() {
      _tapLocked = true;
    });

    widget.onTap();

    _unlockTimer?.cancel();
    _unlockTimer = Timer(
      const Duration(milliseconds: 600),
      () {
        if (!mounted) return;

        setState(() {
          _tapLocked = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question
        .replaceFirst(
          RegExp(r'^\s*📌\s*'),
          '',
        )
        .trim();

    if (question.isEmpty) {
      return const SizedBox.shrink();
    }

    final background =
        widget.dark ? const Color(0xFF1A1D23) : const Color(0xFFF8FAFC);

    final border =
        widget.dark ? const Color(0xFF374151) : const Color(0xFFD6DEE8);

    final textColor =
        widget.dark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937);

    final arrowColor =
        widget.dark ? const Color(0xFF34D399) : const Color(0xFF0F8F6A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        12,
        10,
        12,
        0,
      ),
      child: Semantics(
        button: true,
        label: question,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _tapLocked ? null : _handleTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedOpacity(
              opacity: _tapLocked ? 0.62 : 1,
              duration: const Duration(
                milliseconds: 120,
              ),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 48,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: border,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: arrowColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
