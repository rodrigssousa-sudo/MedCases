import 'package:flutter/material.dart';

import '../../../models/remote_clinical_response.dart';

class RemoteClinicalActionButton extends StatelessWidget {
  final RemoteClinicalAction action;
  final VoidCallback onPressed;
  final bool secondary;

  const RemoteClinicalActionButton({
    super.key,
    required this.action,
    required this.onPressed,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: secondary
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.52)
            : colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  secondary
                      ? Icons.table_chart_outlined
                      : Icons.arrow_forward_rounded,
                  size: 18,
                  color: secondary
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    action.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: secondary
                          ? colorScheme.onSurface
                          : colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
