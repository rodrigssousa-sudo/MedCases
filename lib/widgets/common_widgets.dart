import 'package:flutter/material.dart';

const kDark = Color(0xFF07110d);
const kGold = Color(0xFFC5A365);
const kGoldLight = Color(0xFFFFE8A6);
const kGreen = Color(0xFF075f45);
const kCream = Color(0xFFFFFDF8);
const kBorder = Color(0xFFE8E1D2);
const kSurface = Color(0xFFFBF7EE);

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
          colors: [kDark, Color(0xFF123326), kGreen],
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (eyebrow != null)
        Text(eyebrow!, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0,
          color: light ? const Color(0xBFFFE8A6) : kGold,
        )),
      if (eyebrow != null) const SizedBox(height: 4),
      Text(title, style: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.8,
        color: light ? Colors.white : kDark,
      )),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, height: 1.4,
          color: light ? Colors.white.withValues(alpha: 0.7) : Colors.grey[600],
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: dark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF8F8F8),
        border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEEEEEE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2,
          color: dark ? const Color(0xBFFFE8A6) : Colors.grey[500],
        )),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: Text(value ?? '—', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.5,
            color: dark ? Colors.white : kDark,
          ))),
          if (unit != null) ...[
            const SizedBox(width: 2),
            Text(unit!, style: TextStyle(fontSize: 10, color: dark ? Colors.white.withValues(alpha: 0.6) : Colors.grey[500])),
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
    if (messages.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFFFF0F0),
        border: Border.all(color: const Color(0xFFFFCCCC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final m in messages)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $m', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFCC2222), height: 1.4)),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF8F8F8),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Color(0xFF888888))),
        const SizedBox(height: 6),
        Text(text ?? '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333), height: 1.45)),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: primary ? kDark : Colors.white,
          border: primary ? null : Border.all(color: kBorder),
          boxShadow: primary ? [BoxShadow(color: kDark.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w900,
          color: primary ? kGoldLight : const Color(0xFF555555),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: active ? kDark : kSurface,
          border: Border.all(color: active ? kDark : kBorder),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w900,
          color: active ? kGoldLight : kDark,
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
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      maxLines: maxLines,
      textInputAction: textInputAction ?? (maxLines == 1 ? TextInputAction.next : TextInputAction.newline),
      enableSuggestions: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      autocorrect: false,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kDark),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kGold, width: 1.5)),
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
    return GestureDetector(
      onTap: () => onChange(!checked),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: checked ? kDark : Colors.white,
          border: Border.all(color: checked ? kDark : kBorder),
        ),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: checked ? kGoldLight : kDark))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: checked ? Colors.white.withValues(alpha: 0.15) : kSurface),
            child: Text(points, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: checked ? kGoldLight : kGold)),
          ),
        ]),
      ),
    );
  }
}
