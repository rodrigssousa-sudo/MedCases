import 'package:flutter/material.dart';

import '../foundation/med_typography.dart';
import '../tokens/med_colors.dart';
import '../tokens/med_icons.dart';

/// Tamanhos oficiais do [MedAvatar].
enum MedAvatarSize {
  small,
  medium,
  large,
  xLarge,
}

/// Avatar reutilizável oficial do MedCases Next.
///
/// Prioridade de conteúdo:
/// 1. imagem;
/// 2. iniciais;
/// 3. ícone padrão.
class MedAvatar extends StatelessWidget {
  const MedAvatar({
    super.key,
    this.imageProvider,
    this.initials,
    this.icon,
    this.size = MedAvatarSize.medium,
    this.backgroundColor,
    this.foregroundColor,
    this.semanticLabel,
  });

  final ImageProvider<Object>? imageProvider;
  final String? initials;
  final IconData? icon;
  final MedAvatarSize size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final _MedAvatarMetrics metrics = _resolveMetrics();
    final Color resolvedBackground = backgroundColor ??
        (isDark ? MedColors.darkSurfaceSecondary : MedColors.surfaceSecondary);
    final Color resolvedForeground = foregroundColor ??
        (isDark ? MedColors.darkTextPrimary : MedColors.textPrimary);

    return Semantics(
      image: imageProvider != null,
      label: semanticLabel,
      child: CircleAvatar(
        radius: metrics.diameter / 2,
        backgroundColor: resolvedBackground,
        foregroundImage: imageProvider,
        child: imageProvider == null
            ? _buildFallback(
                metrics: metrics,
                foreground: resolvedForeground,
              )
            : null,
      ),
    );
  }

  Widget _buildFallback({
    required _MedAvatarMetrics metrics,
    required Color foreground,
  }) {
    final String normalizedInitials = _normalizedInitials;

    if (normalizedInitials.isNotEmpty) {
      return Text(
        normalizedInitials,
        maxLines: 1,
        style: MedTypography.label.copyWith(
          color: foreground,
          fontSize: metrics.fontSize,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Icon(
      icon ?? MedIcons.person,
      size: metrics.iconSize,
      color: foreground,
    );
  }

  String get _normalizedInitials {
    final String source = initials?.trim() ?? '';

    if (source.isEmpty) {
      return '';
    }

    final List<String> parts =
        source.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) {
      return '';
    }

    if (parts.length == 1) {
      final String value = parts.first;
      return value.length == 1
          ? value.toUpperCase()
          : value.substring(0, 2).toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  _MedAvatarMetrics _resolveMetrics() {
    switch (size) {
      case MedAvatarSize.small:
        return const _MedAvatarMetrics(
          diameter: 32,
          iconSize: MedIcons.small,
          fontSize: 11,
        );
      case MedAvatarSize.medium:
        return const _MedAvatarMetrics(
          diameter: 40,
          iconSize: MedIcons.medium,
          fontSize: 13,
        );
      case MedAvatarSize.large:
        return const _MedAvatarMetrics(
          diameter: 56,
          iconSize: MedIcons.large,
          fontSize: 16,
        );
      case MedAvatarSize.xLarge:
        return const _MedAvatarMetrics(
          diameter: 72,
          iconSize: MedIcons.xLarge,
          fontSize: 20,
        );
    }
  }
}

class _MedAvatarMetrics {
  const _MedAvatarMetrics({
    required this.diameter,
    required this.iconSize,
    required this.fontSize,
  });

  final double diameter;
  final double iconSize;
  final double fontSize;
}
