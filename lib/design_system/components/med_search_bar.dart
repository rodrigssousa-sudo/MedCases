import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_animation.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';

/// Barra de busca oficial do MedCases Next.
class MedSearchBar extends StatefulWidget {
  const MedSearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'Buscar',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.enabled = true,
    this.autofocus = false,
    this.showClearButton = true,
    this.semanticLabel,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool enabled;
  final bool autofocus;
  final bool showClearButton;
  final String? semanticLabel;

  @override
  State<MedSearchBar> createState() => _MedSearchBarState();
}

class _MedSearchBarState extends State<MedSearchBar> {
  late final TextEditingController _internalController;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _internalController = TextEditingController();
    _controller = widget.controller ?? _internalController;
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant MedSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller == widget.controller) {
      return;
    }

    _controller.removeListener(_handleControllerChanged);
    _controller = widget.controller ?? _internalController;
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _internalController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clear() {
    if (!widget.enabled) {
      return;
    }

    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool hasText = _controller.text.isNotEmpty;
    final Color foreground =
        isDark ? MedColors.darkTextPrimary : MedColors.textPrimary;
    final Color secondary =
        isDark ? MedColors.darkTextMuted : MedColors.textMuted;
    final Color background = widget.enabled
        ? isDark
            ? MedColors.darkSurfaceSecondary
            : MedColors.surfaceSecondary
        : isDark
            ? MedColors.darkSurface
            : MedColors.surfaceSecondary;
    final Color border = isDark ? MedColors.darkBorder : MedColors.border;

    return Semantics(
      textField: true,
      enabled: widget.enabled,
      label: widget.semanticLabel ?? widget.hint,
      child: AnimatedContainer(
        duration: MedAnimation.fade,
        curve: MedAnimation.standard,
        decoration: BoxDecoration(
          color: background,
          borderRadius: MedRadius.pill,
          border: Border.all(
            color: border,
          ),
        ),
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.search,
          style: MedTypography.bodyMedium.copyWith(
            color: foreground,
          ),
          cursorColor: foreground,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: MedTypography.bodyMedium.copyWith(
              color: secondary,
            ),
            prefixIcon: Icon(
              MedIcons.search,
              size: MedIcons.medium,
              color: secondary,
            ),
            suffixIcon: widget.showClearButton && hasText
                ? IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: _clear,
                    icon: Icon(
                      MedIcons.close,
                      size: MedIcons.medium,
                      color: secondary,
                    ),
                  )
                : null,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MedSpacing.lg,
              vertical: MedSpacing.md,
            ),
          ),
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
        ),
      ),
    );
  }
}
