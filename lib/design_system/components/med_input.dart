import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_radius.dart';
import '../tokens/med_spacing.dart';

/// Estados visuais explícitos do [MedInput].
enum MedInputState {
  normal,
  success,
  warning,
  error,
}

/// Campo base reutilizável do MedCases Next.
///
/// Este componente centraliza aparência, semântica, estados, validação,
/// formatação e comportamento dos campos da nova arquitetura.
class MedInput extends StatelessWidget {
  const MedInput({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixPressed,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.state = MedInputState.normal,
    this.semanticLabel,
  }) : assert(
          controller == null || initialValue == null,
          'controller e initialValue não podem ser utilizados juntos.',
        );

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixPressed;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final MedInputState state;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor =
        isDark ? MedColors.darkTextPrimary : MedColors.textPrimary;
    final Color hintColor =
        isDark ? MedColors.darkTextMuted : MedColors.placeholder;
    final Color iconColor =
        isDark ? MedColors.darkTextSecondary : MedColors.textSecondary;
    final Color fillColor = _resolveFillColor(isDark);
    final Color borderColor = _resolveBorderColor(isDark);
    final String? effectiveErrorText =
        state == MedInputState.error ? errorText : null;

    final InputDecoration decoration = InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: effectiveErrorText == null ? helperText : null,
      errorText: effectiveErrorText,
      filled: true,
      fillColor: fillColor,
      counterStyle: MedTypography.caption.copyWith(
        color: hintColor,
      ),
      labelStyle: MedTypography.label.copyWith(
        color: iconColor,
      ),
      floatingLabelStyle: MedTypography.label.copyWith(
        color: borderColor,
      ),
      hintStyle: MedTypography.bodyMedium.copyWith(
        color: hintColor,
      ),
      helperStyle: MedTypography.caption.copyWith(
        color: iconColor,
      ),
      errorStyle: MedTypography.caption.copyWith(
        color: MedColors.error,
      ),
      prefixIcon: prefixIcon == null
          ? null
          : Icon(
              prefixIcon,
              color: iconColor,
            ),
      suffixIcon: suffixIcon == null
          ? null
          : IconButton(
              onPressed: enabled ? onSuffixPressed : null,
              tooltip: semanticLabel,
              icon: Icon(
                suffixIcon,
                color: iconColor,
              ),
            ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MedSpacing.lg,
        vertical: MedSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: MedRadius.medium,
        borderSide: BorderSide(
          color: borderColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: MedRadius.medium,
        borderSide: BorderSide(
          color: borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: MedRadius.medium,
        borderSide: BorderSide(
          color: borderColor,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: MedRadius.medium,
        borderSide: BorderSide(
          color: isDark ? MedColors.darkBorder : MedColors.border,
        ),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: MedRadius.medium,
        borderSide: BorderSide(
          color: MedColors.error,
        ),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: MedRadius.medium,
        borderSide: BorderSide(
          color: MedColors.error,
          width: 1.5,
        ),
      ),
    );

    final Widget field = TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      decoration: decoration,
      style: MedTypography.bodyMedium.copyWith(
        color: textColor,
      ),
      cursorColor: borderColor,
      enabled: enabled,
      readOnly: readOnly,
      obscureText: obscureText,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      maxLines: obscureText ? 1 : maxLines,
      minLines: obscureText ? 1 : minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
    );

    return Semantics(
      textField: true,
      enabled: enabled,
      readOnly: readOnly,
      label: semanticLabel ?? label ?? hint,
      child: field,
    );
  }

  Color _resolveFillColor(bool isDark) {
    if (!enabled) {
      return isDark ? MedColors.darkSurface : MedColors.surfaceSecondary;
    }

    return isDark ? MedColors.darkSurfaceSecondary : MedColors.surface;
  }

  Color _resolveBorderColor(bool isDark) {
    switch (state) {
      case MedInputState.normal:
        return isDark ? MedColors.darkBorder : MedColors.border;
      case MedInputState.success:
        return MedColors.success;
      case MedInputState.warning:
        return MedColors.warning;
      case MedInputState.error:
        return MedColors.error;
    }
  }
}
