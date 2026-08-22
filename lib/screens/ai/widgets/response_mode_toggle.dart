import 'package:flutter/material.dart';

class ResponseModeToggle extends StatelessWidget {
  final bool value;
  final bool dark;
  final String lang;
  final ValueChanged<bool> onChanged;

  const ResponseModeToggle({
    super.key,
    required this.value,
    required this.dark,
    required this.lang,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = lang == 'es';

    final labelStudy =
        isEs ? 'ESTUDIO' : 'ESTUDOS';

    final labelGuard =
        isEs ? 'GUARDIA' : 'PLANTÃO';

    final textColor = dark
        ? Colors.white
        : const Color(0xFF4B5563);

    final dividerColor =
        textColor.withValues(alpha: 0.38);

    Widget option({
      required String label,
      required bool optionValue,
    }) {
      final isCurrent = value == optionValue;

      return Semantics(
        button: true,
        selected: isCurrent,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(optionValue),
          child: SizedBox(
            width: 78,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12.2,
                      height: 1.0,
                      fontWeight: isCurrent
                          ? FontWeight.w800
                          : FontWeight.w600,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 5),
                  AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 180,
                    ),
                    curve: Curves.easeOutCubic,
                    width: isCurrent ? 44 : 0,
                    height: 2,
                    decoration: BoxDecoration(
                      color: textColor,
                      borderRadius:
                          BorderRadius.circular(999),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 6,
      ),
      child: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(
              label: labelStudy,
              optionValue: true,
            ),
            Container(
              width: 1,
              height: 18,
              color: dividerColor,
            ),
            option(
              label: labelGuard,
              optionValue: false,
            ),
          ],
        ),
      ),
    );
  }
}
