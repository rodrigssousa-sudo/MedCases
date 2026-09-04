import 'dart:async';

import 'package:flutter/material.dart';

/// Compact linear continuation surface for Plantão.
/// Productive prompt/clinical logic intentionally stay outside this widget.
class PlantaoContinuationButton extends StatefulWidget {
  final String label;
  final Color accentColor;
  final bool dark;
  final VoidCallback onTap;

  const PlantaoContinuationButton({
    super.key,
    required this.label,
    required this.accentColor,
    required this.dark,
    required this.onTap,
  });

  @override
  State<PlantaoContinuationButton> createState() =>
      _PlantaoContinuationButtonState();
}

class _PlantaoContinuationButtonState extends State<PlantaoContinuationButton> {
  Timer? _unlockTimer;
  bool _tapLocked = false;

  static String _cleanLabel(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();

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

    final background = widget.dark
        ? const Color(0xFF1A1D23)
        : const Color(0xFFF8FAFC);
    final border = widget.dark
        ? const Color(0xFF374151)
        : const Color(0xFFD6DEE8);
    final textColor = widget.dark
        ? const Color(0xFFE5E7EB)
        : const Color(0xFF1F2937);

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
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
                        maxLines: 1,
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
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: widget.accentColor,
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
