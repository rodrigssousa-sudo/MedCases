import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES ESTÁTICAS (light mode — valores históricos mantidos para
// compatibilidade com widgets que não recebem contexto)
// ─────────────────────────────────────────────────────────────────────────────
const kDark     = Color(0xFF07110d);
const kGold     = Color(0xFFC5A365);
const kGoldLight = Color(0xFFFFE8A6);
const kGreen    = Color(0xFF075f45);
const kCream    = Color(0xFFF7F8FA);
const kBorder   = Color(0xFFE2E6EA);
const kSurface  = Color(0xFFF0F2F5);

// ─────────────────────────────────────────────────────────────────────────────
// APP COLORS — tokens adaptativos ao modo claro/escuro
// Uso: final c = AppColors.of(context);
//      Container(color: c.cardBg, child: Text('...', style: TextStyle(color: c.textPrimary)))
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  final bool dark;

  const AppColors._(this.dark);

  factory AppColors.of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return AppColors._(brightness == Brightness.dark);
  }

  // ── Fundos ────────────────────────────────────────────────────────────────
  /// Fundo de cards e superfícies elevadas
  Color get cardBg      => dark ? const Color(0xFF1E1E1E) : Colors.white;
  /// Fundo de cards com leve elevação extra
  Color get cardBg2     => dark ? const Color(0xFF252525) : const Color(0xFFF8F9FA);
  /// Fundo de inputs e campos de texto
  Color get inputBg     => dark ? const Color(0xFF1C1C1C) : Colors.white;
  /// Surface geral (fundo de chips, pills)
  Color get surface     => dark ? const Color(0xFF242424) : const Color(0xFFF0F2F5);
  /// Fundo do scaffold (backup — geralmente vem do theme)
  Color get scaffoldBg  => dark ? const Color(0xFF141414) : const Color(0xFFF5F6F8);

  // ── Textos ────────────────────────────────────────────────────────────────
  /// Texto principal — máximo contraste
  Color get textPrimary   => dark ? const Color(0xFFF7F7F7) : const Color(0xFF07110d);
  /// Texto secundário — subtítulos, labels
  Color get textSecondary => dark ? const Color(0xFFCCCCCC) : const Color(0xFF555F58);
  /// Texto terciário — hints, captions
  Color get textHint      => dark ? const Color(0xFF888888) : const Color(0xFF9CA3AF);
  /// Texto desabilitado
  Color get textDisabled  => dark ? const Color(0xFF555555) : const Color(0xFFBBBBBB);

  // ── Bordas ────────────────────────────────────────────────────────────────
  Color get border        => dark ? const Color(0xFF333333) : const Color(0xFFE2E6EA);
  Color get borderStrong  => dark ? const Color(0xFF444444) : const Color(0xFFCDD3D8);

  // ── Verde / brand ─────────────────────────────────────────────────────────
  /// Verde principal — suavizado no dark para menor saturação
  Color get green         => dark ? const Color(0xFF2E8A62) : const Color(0xFF075f45);
  /// Verde claro para backgrounds
  Color get greenBg       => dark ? const Color(0xFF0F2A1E) : const Color(0xFFECFDF5);
  /// Verde para bordas
  Color get greenBorder   => dark ? const Color(0xFF1A4A32) : const Color(0xFFBBF7D0);

  // ── Ouro / gold ───────────────────────────────────────────────────────────
  Color get gold          => dark ? const Color(0xFFD4A96A) : const Color(0xFFC5A365);
  Color get goldLight     => dark ? const Color(0xFFFFE8A6) : const Color(0xFFFFE8A6);
  Color get goldBg        => dark ? const Color(0xFF2A2010) : const Color(0xFFFFFBF0);
  Color get goldBorder    => dark ? const Color(0xFF4A3820) : const Color(0xFFE8D8A0);

  // ── Dark base ─────────────────────────────────────────────────────────────
  /// Cor escura para botões primários — mais clara no dark
  Color get darkBtn       => dark ? const Color(0xFF2A2A2A) : const Color(0xFF07110d);
  /// Cor escura para text (alias contextual)
  Color get darkText      => textPrimary;

  // ── Divisores ────────────────────────────────────────────────────────────
  Color get divider       => dark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E1D2);

  // ── Interações / alertas (não mudam entre modos) ──────────────────────────
  static const Color alertRed       = Color(0xFFCC2222);
  static const Color alertRedBg     = Color(0xFFFFF0F0);
  static const Color alertRedBorder = Color(0xFFFFCCCC);

  // ── Helpers rápidos para withValues sem repetir ───────────────────────────
  Color cardBorder([double opacity = 1.0]) =>
      border.withValues(alpha: opacity);

  Color textWith(double opacity) =>
      textPrimary.withValues(alpha: opacity);
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS COMPARTILHADOS — agora dark-aware via AppColors
// ─────────────────────────────────────────────────────────────────────────────

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  const PremiumCard({super.key, required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 0),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07110d), Color(0xFF123326), Color(0xFF075f45)],
        ),
      ),
      child: child,
    );
  }
}

class StandardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  const StandardCard({super.key, required this.child, this.padding, this.margin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final bool light;
  const SectionTitle({super.key, this.eyebrow, required this.title, this.subtitle, this.light = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (eyebrow != null)
        Text(eyebrow!, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0,
          color: light ? const Color(0xBFFFE8A6) : c.gold,
        )),
      if (eyebrow != null) const SizedBox(height: 4),
      Text(title, style: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.8,
        color: light ? Colors.white : c.textPrimary,
      )),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, height: 1.4,
          color: light ? Colors.white.withValues(alpha: 0.7) : c.textSecondary,
        )),
      ],
    ]);
  }
}

class DataPoint extends StatelessWidget {
  final String label;
  final String? value;
  final String? unit;
  final bool dark;
  const DataPoint({super.key, required this.label, this.value, this.unit, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: dark ? Colors.white.withValues(alpha: 0.1) : c.surface,
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.1) : c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2,
          color: dark ? const Color(0xBFFFE8A6) : c.textHint,
        )),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: Text(value ?? '—', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.5,
            color: dark ? Colors.white : c.textPrimary,
          ))),
          if (unit != null) ...[
            const SizedBox(width: 2),
            Text(unit!, style: TextStyle(fontSize: 10, color: dark ? Colors.white.withValues(alpha: 0.6) : c.textHint)),
          ],
        ]),
      ]),
    );
  }
}

class ClinicalAlertBox extends StatelessWidget {
  final List<String> messages;
  const ClinicalAlertBox({super.key, required this.messages});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (messages.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? const Color(0xFF2A1010) : const Color(0xFFFFF0F0),
        border: Border.all(color: isDark ? const Color(0xFF6B2020) : const Color(0xFFFFCCCC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final m in messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $m', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFFF9090) : const Color(0xFFCC2222),
              height: 1.4)),
          ),
      ]),
    );
  }
}

class InfoBlock extends StatelessWidget {
  final String label;
  final String? text;
  const InfoBlock({super.key, required this.label, this.text});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: c.cardBg2,
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: c.textHint)),
        const SizedBox(height: 6),
        Text(text ?? '—', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.45)),
      ]),
    );
  }
}

class MedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool fullWidth;
  final EdgeInsets? padding;
  const MedButton({super.key, required this.label, this.onTap, this.primary = true, this.fullWidth = false, this.padding});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: primary ? c.darkBtn : c.cardBg,
          border: primary ? null : Border.all(color: c.border),
          boxShadow: primary ? [BoxShadow(color: c.darkBtn.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w900,
          color: primary ? kGoldLight : c.textSecondary,
        ))),
      ),
    );
  }
}

class GoldChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const GoldChip({super.key, required this.label, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? c.darkBtn : c.surface,
          border: Border.all(color: active ? c.darkBtn : c.border),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w900,
          color: active ? kGoldLight : c.textPrimary,
        )),
      ),
    );
  }
}

class MedInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? initialValue;
  final int? maxLines;
  final TextInputAction? textInputAction;
  const MedInput({super.key, this.controller, this.hintText, this.keyboardType, this.onChanged, this.initialValue, this.maxLines = 1, this.textInputAction});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      maxLines: maxLines,
      textInputAction: textInputAction ?? (maxLines == 1 ? TextInputAction.next : TextInputAction.newline),
      enableSuggestions: true,
      autocorrect: true,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: c.textHint, fontWeight: FontWeight.w500),
        filled: true, fillColor: c.inputBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c.gold, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }
}

class ScoreToggle extends StatelessWidget {
  final String label;
  final bool checked;
  final String points;
  final ValueChanged<bool> onChange;
  const ScoreToggle({super.key, required this.label, required this.checked, required this.points, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => onChange(!checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: checked ? c.darkBtn : c.cardBg,
          border: Border.all(color: checked ? c.darkBtn : c.border),
        ),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: checked ? kGoldLight : c.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: checked ? Colors.white.withValues(alpha: 0.15) : c.surface),
            child: Text(points, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: checked ? kGoldLight : c.gold)),
          ),
        ]),
      ),
    );
  }
}
