import 'dart:async';

import 'package:flutter/material.dart';

/// Continuação pedagógica linear do Modo Estudo.
///
/// STUDY-PREMIUM-V1-B-R6: este widget conhece SOMENTE o rótulo humano visível.
class StudyContinuationButton extends StatefulWidget {
  final String label;
  final bool dark;
  final VoidCallback onTap;

  const StudyContinuationButton({
    super.key,
    required this.label,
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

  static bool _isEmojiRune(int rune) {
    return (rune >= 0x1F000 && rune <= 0x1FAFF) ||
        (rune >= 0x2600 && rune <= 0x27BF) ||
        rune == 0xFE0F ||
        rune == 0x200D ||
        rune == 0x20E3;
  }

  static String _cleanLabel(String value) {
    return String.fromCharCodes(
      value.runes.where((rune) => !_isEmojiRune(rune)),
    ).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _handleTap() {
    if (_tapLocked) return;
    setState(() => _tapLocked = true);
    widget.onTap();
    _unlockTimer?.cancel();
    _unlockTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _tapLocked = false);
    });
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _cleanLabel(widget.label);
    if (label.isEmpty) return const SizedBox.shrink();

    final background =
        widget.dark ? const Color(0xFF1A1D23) : const Color(0xFFF8FAFC);
    final border =
        widget.dark ? const Color(0xFF374151) : const Color(0xFFD6DEE8);
    final textColor =
        widget.dark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937);
    final arrowColor =
        widget.dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _tapLocked ? null : _handleTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedOpacity(
              opacity: _tapLocked ? 0.62 : 1,
              duration: const Duration(milliseconds: 120),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border, width: 0.8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.0,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        size: 18, color: arrowColor),
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
