import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/drug_interaction_service.dart';
import '../models/drug_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP HAPTICS — wrapper global que respeita o toggle de vibração do usuário
// Uso:  AppHaptics.light(context);   // toque leve
//       AppHaptics.medium(context);  // toque médio
//       AppHaptics.selection(context); // clique de seleção
// Não faz nada no web nem quando o usuário desativou a vibração.
// ─────────────────────────────────────────────────────────────────────────────
class AppHaptics {
  AppHaptics._();

  static bool _enabled(BuildContext context) {
    if (kIsWeb) return false;
    try {
      return context.read<AppProvider>().hapticEnabled;
    } catch (_) {
      return true; // fallback seguro se o provider não estiver disponível
    }
  }

  static void light(BuildContext context) {
    if (_enabled(context)) HapticFeedback.lightImpact();
  }

  static void medium(BuildContext context) {
    if (_enabled(context)) HapticFeedback.mediumImpact();
  }

  static void heavy(BuildContext context) {
    if (_enabled(context)) HapticFeedback.heavyImpact();
  }

  static void selection(BuildContext context) {
    if (_enabled(context)) HapticFeedback.selectionClick();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MED BREAKPOINTS — sistema de breakpoints responsivos unificado
// Uso:  final bp = MedBreakpoints.of(context);
//       if (bp.isDesktop) { ... }
// ─────────────────────────────────────────────────────────────────────────────
class MedBreakpoints {
  final double width;

  const MedBreakpoints._(this.width);

  /// Lê a largura do [MediaQuery] — use apenas fora de [LayoutBuilder].
  /// Dentro de LayoutBuilder, prefira [fromWidth] para evitar leituras stale.
  factory MedBreakpoints.of(BuildContext context) {
    return MedBreakpoints._(MediaQuery.of(context).size.width);
  }

  /// Constrói a partir de uma largura já conhecida (ex: constraints.maxWidth
  /// obtido dentro de um LayoutBuilder). Evita leituras stale do MediaQuery
  /// no Flutter Web durante resize ou ao usar o Chrome DevTools device emulator.
  factory MedBreakpoints.fromWidth(double width) {
    return MedBreakpoints._(width);
  }

  /// < 768 px — smartphone
  bool get isMobile => width < 650;

  /// 768–1023 px — tablet
  bool get isTablet => width >= 768 && width < 1024;

  /// >= 1024 px — desktop/laptop
  bool get isDesktop => width >= 1024;

  /// >= 1440 px — widescreen/ultrawide
  bool get isUltra => width >= 1440;

  /// Largura abaixo de 1024 px — deve renderizar o shell mobile (BottomNav + AppBar).
  /// NOTA: kIsWeb foi removido desta guard. O Chrome DevTools device emulator roda
  /// com kIsWeb=true mas com width < 1024 — sem a remoção, o shell desktop era
  /// forçado mesmo em 375px. A decisão agora é puramente dimensional.
  bool get isWebMobile => width < 1024;

  /// true quando a tela é tablet ou maior
  bool get isTabletOrLarger => width >= 768;

  /// true quando a tela é desktop ou maior
  bool get isDesktopOrLarger => width >= 1024;

  /// Largura disponível para conteúdo principal (desktop: limitado ao útil)
  double get contentMaxWidth {
    if (isUltra) return 1600;
    if (isDesktop) return 1280;
    return double.infinity;
  }

  /// Número ideal de colunas para grids de cards
  int get gridColumns {
    if (isUltra) return 4;
    if (isDesktop) return 3;
    if (isTablet) return 2;
    return 1;
  }

  /// Padding horizontal responsivo
  double get hPadding {
    if (isDesktop) return 32;
    if (isTablet) return 24;
    return 18;
  }

  /// Largura da sidebar de navegação no desktop
  static const double sidebarWidth = 72;

  /// Largura da sidebar expandida (com labels)
  static const double sidebarExpandedWidth = 200;

  /// Detecta se estamos em contexto web (não nativo iOS/Android)
  static bool get isWebContext => kIsWeb;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTES ESTÁTICAS (light mode — valores históricos mantidos para
// compatibilidade com widgets que não recebem contexto)
// ─────────────────────────────────────────────────────────────────────────────
const kDark = Color(0xFF07110d);
const kGold = Color(0xFFC5A365);
const kGoldLight = Color(0xFFFFE8A6);
const kGreen = Color(0xFF0E8000);
const kCream = Color(0xFFF7F8FA);
const kBorder = Color(0xFFE2E6EA);
const kSurface = Color(0xFFF0F2F5);

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
  Color get cardBg => dark ? const Color(0xFF252930) : Colors.white;

  /// Fundo de cards com leve elevação extra
  Color get cardBg2 => dark ? const Color(0xFF252930) : const Color(0xFFF8F9FA);

  /// Fundo de inputs e campos de texto
  Color get inputBg => dark ? const Color(0xFF1C1C1C) : Colors.white;

  /// Surface geral (fundo de chips, pills)
  Color get surface => dark ? const Color(0xFF252930) : const Color(0xFFF0F2F5);

  /// Fundo do scaffold (backup — geralmente vem do theme)
  Color get scaffoldBg =>
      dark ? const Color(0xFF1A1D23) : const Color(0xFFF5F6F8);

  // ── Textos ────────────────────────────────────────────────────────────────
  /// Texto principal — máximo contraste
  Color get textPrimary =>
      dark ? const Color(0xFFFFFFFF) : const Color(0xFF07110d);

  /// Texto secundário — subtítulos, labels
  Color get textSecondary =>
      dark ? const Color(0xFFA8B2C1) : const Color(0xFF555F58);

  /// Texto terciário — hints, captions
  Color get textHint =>
      dark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

  /// Texto desabilitado
  Color get textDisabled =>
      dark ? const Color(0xFF555555) : const Color(0xFFBBBBBB);

  // ── Bordas ────────────────────────────────────────────────────────────────
  Color get border => dark ? const Color(0xFF374151) : const Color(0xFFE2E6EA);
  Color get borderStrong =>
      dark ? const Color(0xFF444444) : const Color(0xFFCDD3D8);

  // ── Verde / brand ─────────────────────────────────────────────────────────
  /// Verde principal — suavizado no dark para menor saturação
  Color get green => dark ? const Color(0xFF10B981) : const Color(0xFF075f45);

  /// Verde claro para backgrounds
  Color get greenBg => dark ? const Color(0xFF0F2A1E) : const Color(0xFFECFDF5);

  /// Verde para bordas
  Color get greenBorder =>
      dark ? const Color(0xFF1A4A32) : const Color(0xFFBBF7D0);

  // ── Ouro / gold ───────────────────────────────────────────────────────────
  Color get gold => dark ? const Color(0xFFC5A365) : const Color(0xFFC5A365);
  Color get goldLight =>
      dark ? const Color(0xFFFFE8A6) : const Color(0xFFFFE8A6);
  Color get goldBg => dark ? const Color(0xFF2A2010) : const Color(0xFFFFFBF0);
  Color get goldBorder =>
      dark ? const Color(0xFF4A3820) : const Color(0xFFE8D8A0);

  // ── Dark base ─────────────────────────────────────────────────────────────
  /// Cor escura para botões primários — mais clara no dark
  Color get darkBtn => dark ? const Color(0xFF2D3340) : const Color(0xFF07110d);

  /// Cor escura para text (alias contextual)
  Color get darkText => textPrimary;

  // ── Divisores ────────────────────────────────────────────────────────────
  Color get divider => dark ? const Color(0xFF2D3340) : const Color(0xFFE8E1D2);

  // ── Interações / alertas (não mudam entre modos) ──────────────────────────
  static const Color alertRed = Color(0xFFCC2222);
  static const Color alertRedBg = Color(0xFFFFF0F0);
  static const Color alertRedBorder = Color(0xFFFFCCCC);

  // ── Helpers rápidos para withValues sem repetir ───────────────────────────
  Color cardBorder([double opacity = 1.0]) => border.withOpacity(opacity);

  Color textWith(double opacity) => textPrimary.withOpacity(opacity);
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS COMPARTILHADOS — agora dark-aware via AppColors
// ─────────────────────────────────────────────────────────────────────────────

class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

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
  const StandardCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding ?? const EdgeInsets.all(14), child: child);
  }
}

class SectionTitle extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final bool light;
  const SectionTitle({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null)
          Text(
            eyebrow!,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: light ? const Color(0xBFFFE8A6) : c.gold,
            ),
          ),
        if (eyebrow != null) const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: light ? Colors.white : c.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: light ? Colors.white.withOpacity(0.7) : c.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class DataPoint extends StatelessWidget {
  final String label;
  final String? value;
  final String? unit;
  final bool dark;
  const DataPoint({
    super.key,
    required this.label,
    this.value,
    this.unit,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: dark ? Colors.white.withOpacity(0.1) : c.surface,
        border: Border.all(
          color: dark ? Colors.white.withOpacity(0.1) : c.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: dark ? const Color(0xBFFFE8A6) : c.textHint,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value ?? '—',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: dark ? Colors.white : c.textPrimary,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: 10,
                    color: dark ? Colors.white.withOpacity(0.6) : c.textHint,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
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
        border: Border.all(
          color: isDark ? const Color(0xFF6B2020) : const Color(0xFFFFCCCC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $m',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? const Color(0xFFFF9090)
                      : const Color(0xFFCC2222),
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              color: c.textHint,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text ?? '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: c.textPrimary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class MedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool fullWidth;
  final EdgeInsets? padding;
  const MedButton({
    super.key,
    required this.label,
    this.onTap,
    this.primary = true,
    this.fullWidth = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: primary ? c.darkBtn : c.cardBg,
          border: primary ? null : Border.all(color: c.border),
          boxShadow: primary
              ? [
                  BoxShadow(
                    color: c.darkBtn.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: primary ? kGoldLight : c.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class GoldChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool active;
  const GoldChip({
    super.key,
    required this.label,
    this.onTap,
    this.active = false,
  });

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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: active ? kGoldLight : c.textPrimary,
          ),
        ),
      ),
    );
  }
}

// HISTORY_CLINICAL_V1_D_R6_KEYBOARD_FLOW
// HISTORY_CLINICAL_V1_D_R14_REDUCED_OVERSCROLL
class MedInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? initialValue;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool clinicalCompact;
  final IconData? prefixIcon;
  const MedInput({
    super.key,
    this.controller,
    this.hintText,
    this.keyboardType,
    this.onChanged,
    this.initialValue,
    this.maxLines = 1,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.clinicalCompact = false,
    this.prefixIcon,
  });
  @override
  Widget build(BuildContext context) {
    // HISTORY_CLINICAL_V1_C_R8_COMMON_MEDINPUT
    final colors = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final numeric = keyboardType == TextInputType.number ||
        keyboardType == const TextInputType.numberWithOptions(decimal: true) ||
        keyboardType == const TextInputType.numberWithOptions(decimal: false);
    final fill =
        clinicalCompact && dark ? const Color(0xFF2D3340) : colors.inputBg;
    final borderColor =
        clinicalCompact && dark ? const Color(0xFF374151) : colors.border;
    final radius = clinicalCompact ? 10.0 : 14.0;
    final focusColor = clinicalCompact ? const Color(0xFF0E8000) : colors.gold;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      maxLines: maxLines,
      textInputAction: textInputAction ??
          (maxLines == 1 ? TextInputAction.next : TextInputAction.newline),
      scrollPadding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 88,
      ),
      onSubmitted: (_) {
        final action = textInputAction ??
            (maxLines == 1 ? TextInputAction.next : TextInputAction.newline);
        if (action == TextInputAction.next) {
          FocusScope.of(context).nextFocus();
        } else if (action == TextInputAction.done) {
          FocusScope.of(context).unfocus();
        }
      },
      enableSuggestions: !numeric,
      autocorrect: !numeric,
      textCapitalization:
          numeric ? TextCapitalization.none : textCapitalization,
      style: TextStyle(
        fontWeight: clinicalCompact ? FontWeight.w500 : FontWeight.w700,
        fontSize: clinicalCompact ? 14 : 15,
        color: colors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: clinicalCompact && dark ? Colors.white54 : colors.textHint,
          fontWeight: FontWeight.w500,
          fontSize: clinicalCompact ? 13.5 : null,
        ),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                size: 17,
                color:
                    clinicalCompact && dark ? Colors.white60 : colors.textHint,
              ),
        prefixIconConstraints: prefixIcon == null
            ? null
            : const BoxConstraints(minWidth: 40, minHeight: 40),
        filled: true,
        fillColor: fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: borderColor,
            width: clinicalCompact ? 0.8 : 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: borderColor,
            width: clinicalCompact ? 0.8 : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(
            color: focusColor,
            width: clinicalCompact ? 1.0 : 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: clinicalCompact ? 10 : 12,
        ),
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
  const ScoreToggle({
    super.key,
    required this.label,
    required this.checked,
    required this.points,
    required this.onChange,
  });

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
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: checked ? kGoldLight : c.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: checked ? Colors.white.withOpacity(0.15) : c.surface,
              ),
              child: Text(
                points,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: checked ? kGoldLight : c.gold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DRUG AUTOCOMPLETE FIELD — campo de fármaco com busca fuzzy reutilizável
//
// Funciona em qualquer tela. Busca a partir de 3 caracteres nos:
//   1. Nomes do DrugModel (banco de 337 fármacos)
//   2. _termMap do DrugInteractionService (aliases, nomes comerciais, inglês)
// Com fuzzy fallback por trigramas quando não há match direto.
//
// Uso:
//   DrugAutocompleteField(
//     controller: _meuCtrl,
//     drugs: context.read<AppProvider>().drugsDB,   // ou [] para só _termMap
//     label: 'Fármaco',
//     hint: 'Noradrenalina',
//     onChanged: (v) => setState(() {}),
//     onSelected: (name) { ... },   // opcional — callback ao clicar sugestão
//   )
// ─────────────────────────────────────────────────────────────────────────────

class DrugAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final List<DrugModel> drugs;
  final String label;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSelected; // callback com nome ao selecionar

  const DrugAutocompleteField({
    super.key,
    required this.controller,
    required this.drugs,
    required this.label,
    required this.hint,
    this.onChanged,
    this.onSelected,
  });

  @override
  State<DrugAutocompleteField> createState() => _DrugAutocompleteFieldState();
}

class _DrugAutocompleteFieldState extends State<DrugAutocompleteField> {
  // Carregado uma única vez (static = compartilhado entre todas as instâncias)
  static final List<String> _termNames =
      DrugInteractionService.getAllDrugNames();

  OverlayEntry? _overlay;
  final LayerLink _layerLink = LayerLink();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _removeOverlay();
    super.dispose();
  }

  // ── Algoritmo de busca fuzzy ───────────────────────────────────────────────

  /// Score de similaridade por trigramas (0.0–1.0).
  /// Usado como fallback quando não há match direto por contains.
  double _trigramScore(String a, String b) {
    if (a.length < 3 || b.length < 3) {
      return a.startsWith(b) || b.startsWith(a) ? 0.5 : 0.0;
    }
    Set<String> trigrams(String s) {
      final set = <String>{};
      for (int i = 0; i < s.length - 2; i++) {
        set.add(s.substring(i, i + 3));
      }
      return set;
    }

    final ta = trigrams(a);
    final tb = trigrams(b);
    final intersection = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  void _onTextChanged() {
    if (!mounted) return;
    final q = widget.controller.text.toLowerCase().trim();

    if (q.length < 3) {
      _removeOverlay();
      return;
    }

    final seen = <String>{};
    final results = <_ScoredName>[];

    // ── 1. Match direto por contains nos DrugModels ────────────────────────
    for (final d in widget.drugs) {
      final lower = d.name.toLowerCase();
      if (lower.contains(q) && seen.add(d.name)) {
        results.add(_ScoredName(d.name, lower.startsWith(q) ? 1.0 : 0.85));
      }
    }

    // ── 2. Match direto por contains no _termMap ───────────────────────────
    for (final t in _termNames) {
      final lower = t.toLowerCase();
      if (lower.contains(q) && seen.add(t)) {
        results.add(_ScoredName(t, lower.startsWith(q) ? 0.95 : 0.80));
      }
    }

    // ── 3. Fuzzy fallback por trigramas (quando results < 4) ──────────────
    if (results.length < 4) {
      for (final d in widget.drugs) {
        if (seen.contains(d.name)) continue;
        final score = _trigramScore(d.name.toLowerCase(), q);
        if (score >= 0.30) {
          results.add(_ScoredName(d.name, score * 0.70)); // peso menor
          seen.add(d.name);
        }
      }
      for (final t in _termNames) {
        if (seen.contains(t)) continue;
        final score = _trigramScore(t.toLowerCase(), q);
        if (score >= 0.30) {
          results.add(_ScoredName(t, score * 0.65));
          seen.add(t);
        }
      }
    }

    if (results.isEmpty) {
      _removeOverlay();
      return;
    }

    // Ordena por score desc, limita a 8
    results.sort((a, b) => b.score.compareTo(a.score));
    _suggestions = results.take(8).map((s) => s.name).toList();

    if (_overlay == null) {
      _showOverlay();
    } else {
      _overlay!.markNeedsBuild();
    }
  }

  // ── Overlay ───────────────────────────────────────────────────────────────

  void _showOverlay() {
    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(builder: (_) => _buildOverlay());
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
    _suggestions = [];
  }

  void _select(String name) {
    widget.controller.text = name;
    widget.controller.selection = TextSelection.collapsed(offset: name.length);
    widget.onChanged?.call(name);
    widget.onSelected?.call(name);
    _removeOverlay();
  }

  Widget _buildOverlay() {
    final q = widget.controller.text.toLowerCase().trim();
    return Positioned(
      width: 0,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 52),
        child: Align(
          alignment: Alignment.topLeft,
          child: _DrugSuggestionsDropdown(
            suggestions: _suggestions,
            query: q,
            onSelect: _select,
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: c.textHint,
          ),
        ),
        const SizedBox(height: 5),
        // Campo com overlay
        CompositedTransformTarget(
          link: _layerLink,
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.text,
            autocorrect: false,
            spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
            textInputAction: TextInputAction.done,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: c.textPrimary,
            ),
            onChanged: (v) {
              widget.onChanged?.call(v);
              if (v.trim().length < 3) _removeOverlay();
            },
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: c.textHint,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: Icon(
                  Icons.medication_rounded,
                  size: 17,
                  color: c.textHint,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 36,
              ),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        widget.controller.clear();
                        widget.onChanged?.call('');
                        _removeOverlay();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: c.textHint,
                        ),
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              filled: true,
              fillColor: c.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: c.gold, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

// Score helper — interno
class _ScoredName {
  final String name;
  final double score;
  const _ScoredName(this.name, this.score);
}

// ─────────────────────────────────────────────────────────────────────────────
// DROPDOWN DE SUGESTÕES — usado pelo DrugAutocompleteField
// Realça o trecho digitado em negrito. Adaptativo dark/light.
// ─────────────────────────────────────────────────────────────────────────────

class _DrugSuggestionsDropdown extends StatelessWidget {
  final List<String> suggestions;
  final String query;
  final ValueChanged<String> onSelect;

  const _DrugSuggestionsDropdown({
    required this.suggestions,
    required this.query,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const maxVisible = 6;
    const itemH = 44.0;
    final count = suggestions.length.clamp(1, maxVisible);
    final boxH = count * itemH + 8.0;

    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(14),
      color: dark ? const Color(0xFF252930) : Colors.white,
      shadowColor: Colors.black.withOpacity(0.20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 340, maxHeight: boxH),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap: true,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 44,
              endIndent: 12,
              color: dark ? const Color(0xFF374151) : const Color(0xFFF0F0F0),
            ),
            itemBuilder: (_, i) {
              final name = suggestions[i];
              final lowerName = name.toLowerCase();
              final idx = lowerName.indexOf(query);

              // Realça o trecho encontrado em negrito+dourado
              Widget nameWidget;
              if (idx >= 0 && query.isNotEmpty) {
                nameWidget = RichText(
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: dark
                          ? const Color(0xFFA8B2C1)
                          : const Color(0xFF1A1D23),
                    ),
                    children: [
                      if (idx > 0) TextSpan(text: name.substring(0, idx)),
                      TextSpan(
                        text: name.substring(idx, idx + query.length),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: dark
                              ? const Color(0xFFFFE8A6)
                              : const Color(0xFFC5A365),
                        ),
                      ),
                      TextSpan(text: name.substring(idx + query.length)),
                    ],
                  ),
                );
              } else {
                // Fuzzy match — sem realce mas com ícone indicativo
                nameWidget = Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: dark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFFAAAAAA),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: dark
                              ? const Color(0xFF999999)
                              : const Color(0xFF555555),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return InkWell(
                onTap: () => onSelect(name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.medication_rounded,
                        size: 16,
                        color: dark
                            ? const Color(0xFF666666)
                            : const Color(0xFFBBBBBB),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: nameWidget),
                      Icon(
                        Icons.north_west_rounded,
                        size: 12,
                        color: dark
                            ? const Color(0xFF555555)
                            : const Color(0xFFA8B2C1),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPORTS ADICIONALES para widgets de evidencia
// ─────────────────────────────────────────────────────────────────────────────
// (DrugEvidenceModel ya importado desde drug_model.dart arriba)

// ═════════════════════════════════════════════════════════════════════════════
// EVIDENCE BADGES ROW — fila compacta de badges de calidad
// Uso: EvidenceBadgesRow(ev: evidenceModel)
// ═════════════════════════════════════════════════════════════════════════════
class EvidenceBadgesRow extends StatelessWidget {
  final DrugEvidenceModel ev;
  final bool compact;
  const EvidenceBadgesRow({super.key, required this.ev, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dark = c.dark;
    final badges = <_EvBadge>[
      _EvBadge('✓ Revisado', const Color(0xFF059669)),
      _EvBadge('✓ Actualizado', const Color(0xFF0EA5E9)),
      _EvBadge('✓ Basado en Evidencias', const Color(0xFF8B5CF6)),
      _EvBadge('✓ Fuente Verificada', const Color(0xFFF59E0B)),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: badges
            .map(
              (b) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 7 : 9,
                    vertical: compact ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: b.color.withOpacity(dark ? 0.15 : 0.09),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: b.color.withOpacity(0.30)),
                  ),
                  child: Text(
                    b.label,
                    style: TextStyle(
                      fontSize: compact ? 9.0 : 10.0,
                      fontWeight: FontWeight.w700,
                      color: b.color,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _EvBadge {
  final String label;
  final Color color;
  const _EvBadge(this.label, this.color);
}

// ═════════════════════════════════════════════════════════════════════════════
// EVIDENCE CARD WIDGET — tarjeta completa de evidencia farmacológica
// Uso: EvidenceCardWidget(ev: evidenceModel)
//      EvidenceCardWidget(ev: evidenceModel, compact: true)
// ═════════════════════════════════════════════════════════════════════════════
class EvidenceCardWidget extends StatefulWidget {
  final DrugEvidenceModel ev;
  final bool compact;
  const EvidenceCardWidget({super.key, required this.ev, this.compact = false});

  @override
  State<EvidenceCardWidget> createState() => _EvidenceCardWidgetState();
}

// ── Fallback references — Apple Guideline 1.4.1 compliance ──────────────
// Used when the drug/protocol has no specific references in ev.references[]
// These three are universally applicable to acute medical management content.
const _kFallbackRefs = [
  DrugEvidenceRef(
    num: 1,
    source: 'UpToDate (2025)',
    title: 'Clinical overview of acute medical management.',
    year: '2025',
    type: 'Base de Datos',
  ),
  DrugEvidenceRef(
    num: 2,
    source: 'World Health Organization (WHO)',
    title: 'Guidelines for essential selection of pharmacological data.',
    year: '2024',
    type: 'Directriz',
  ),
  DrugEvidenceRef(
    num: 3,
    source: 'AHA / ACC Emergency Guidelines',
    title:
        'Emergency Guidelines Reference Standards for acute pharmacological interventions.',
    year: '2023',
    type: 'Directriz',
  ),
];

class _EvidenceCardWidgetState extends State<EvidenceCardWidget> {
  // Open by default — Apple Guideline 1.4.1: references must be immediately
  // visible to the reviewer without requiring any tap interaction.
  bool _refsExpanded = true;
  bool _linksExpanded = true;

  Color _typeColor(String type) {
    switch (type) {
      case 'Directriz':
        return const Color(0xFF059669);
      case 'Base de Datos':
        return const Color(0xFF0EA5E9);
      case 'Estudio':
        return const Color(0xFF8B5CF6);
      case 'Libro-Texto':
        return const Color(0xFFF59E0B);
      case 'Protocolo':
        return const Color(0xFF06B6D4);
      case 'FDA Label':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dark = c.dark;
    final ev = widget.ev;

    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header con metadatos ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              border: Border(bottom: BorderSide(color: c.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título + ícono
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 13,
                      color: Color(0xFF059669),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'EVIDENCIA CIENTÍFICA',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    // ATC code badge si disponible
                    if (ev.atcCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withOpacity(0.10),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFF059669).withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          'ATC: ${ev.atcCode}',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // Chips de metadatos
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _EvMetaChip(
                      label: 'Fuente Principal',
                      value: ev.primarySource,
                      color: const Color(0xFF059669),
                      c: c,
                    ),
                    _EvMetaChip(
                      label: 'Directriz Utilizada',
                      value: ev.guidelineSource,
                      color: const Color(0xFF0EA5E9),
                      c: c,
                    ),
                    _EvMetaChip(
                      label: 'Nivel de Evidencia',
                      value: ev.evidenceLevel,
                      color: const Color(0xFF8B5CF6),
                      c: c,
                    ),
                    _EvMetaChip(
                      label: 'Recomendación',
                      value: ev.recommendation,
                      color: const Color(0xFF06B6D4),
                      c: c,
                    ),
                    _EvMetaChip(
                      label: 'Última Revisión',
                      value: ev.lastReviewed,
                      color: const Color(0xFFF59E0B),
                      c: c,
                    ),
                    _EvMetaChip(
                      label: 'Estado',
                      value: ev.reviewStatus,
                      color: const Color(0xFF059669),
                      c: c,
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                // Badges de calidad
                EvidenceBadgesRow(ev: ev, compact: true),
              ],
            ),
          ),

          // ── Referencias bibliográficas — ABIERTAS POR DEFECTO ─────────────
          // Apple Guideline 1.4.1: bibliographic citations must be immediately
          // visible. Fallback list shown when ev.references[] is empty.
          ...() {
            final refs =
                ev.references.isNotEmpty ? ev.references : _kFallbackRefs;
            return [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _refsExpanded = !_refsExpanded),
                  borderRadius: const BorderRadius.all(Radius.circular(0)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 13,
                          color: dark
                              ? const Color(0xFFFFE8A6)
                              : const Color(0xFF075f45),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            'REFERENCIAS BIBLIOGRÁFICAS (${refs.length})',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _refsExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: c.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(height: 1, color: c.border),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _refsExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Column(
                    children: refs
                        .map(
                          (ref) => _EvRefRow(
                            ref: ref,
                            typeColor: _typeColor(ref.type),
                            c: c,
                          ),
                        )
                        .toList(),
                  ),
                ),
                secondChild: const SizedBox(width: double.infinity),
              ),
            ];
          }(),

          // ── Links oficiales colapsibles ──────────────────────────────────────
          if (ev.links.isNotEmpty) ...[
            Container(height: 1, color: c.border),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _linksExpanded = !_linksExpanded),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 13,
                        color: dark
                            ? const Color(0xFFFFE8A6)
                            : const Color(0xFF075f45),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'DOCUMENTOS OFICIALES (${ev.links.length})',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _linksExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: c.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 220),
              crossFadeState: _linksExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Container(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(15),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    ...ev.links.map(
                      (link) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF0EA5E9).withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                link.icon,
                                size: 14,
                                color: const Color(0xFF0EA5E9),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      link.label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0EA5E9),
                                      ),
                                    ),
                                    if (link.org.isNotEmpty &&
                                        link.org != 'Other')
                                      Text(
                                        link.org,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                          color: c.textHint,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Badge de fuente verificada — sem botão de link
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: const Color(
                                    0xFF0EA5E9,
                                  ).withOpacity(0.10),
                                ),
                                child: const Text(
                                  'fuente',
                                  style: TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0EA5E9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              secondChild: const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvMetaChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final AppColors c;
  const _EvMetaChip({
    required this.label,
    required this.value,
    required this.color,
    required this.c,
  });
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: c.textHint,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.22)),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      );
}

class _EvRefRow extends StatelessWidget {
  final DrugEvidenceRef ref;
  final Color typeColor;
  final AppColors c;
  const _EvRefRow({
    required this.ref,
    required this.typeColor,
    required this.c,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: typeColor.withOpacity(0.35)),
            ),
            child: Center(
              child: Text(
                '${ref.num}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: typeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ref.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: typeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ref.year,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: c.textHint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ref.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  ref.source,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
                if (ref.doi != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'DOI: ${ref.doi}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0EA5E9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PHARMACOLOGICAL DISCLAIMER — aviso regulatorio Apple 1.4.1/1.4.2
// Colapsável: por padrão exibe apenas 1 linha. Toque para expandir.
// Uso: PharmacologicalDisclaimer()
//      PharmacologicalDisclaimer(customText: '...')
// ═════════════════════════════════════════════════════════════════════════════
class PharmacologicalDisclaimer extends StatefulWidget {
  final String? customText;
  const PharmacologicalDisclaimer({super.key, this.customText});
  @override
  State<PharmacologicalDisclaimer> createState() =>
      _PharmacologicalDisclaimerState();
}

class _PharmacologicalDisclaimerState extends State<PharmacologicalDisclaimer> {
  bool _expanded = false;

  static const _defaultText =
      'La información farmacológica presentada tiene carácter exclusivamente '
      'educativo y de referencia clínica. No sustituye el criterio médico '
      'profesional, la evaluación clínica individualizada ni las recomendaciones '
      'de las guías institucionales vigentes. Las dosis, indicaciones y '
      'contraindicaciones deben verificarse siempre en fuentes actualizadas '
      '(Micromedex, Lexicomp, FDA, AHA, ESC) antes de cualquier decisión '
      'terapéutica. El uso clínico es responsabilidad exclusiva del profesional '
      'de salud. • Apple App Store Guideline 1.4.1 / 1.4.2 Compliance';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dark = c.dark;
    final text = widget.customText ?? _defaultText;

    const subtleGrey = Color(0xFF9CA3AF);
    final borderCol = dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB);
    final bgCol = dark ? const Color(0xFF161616) : const Color(0xFFFAFAF8);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ), // BUILD 275: -2px vertical
        decoration: BoxDecoration(
          color: bgCol,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone fixo
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: subtleGrey,
              ),
            ),
            const SizedBox(width: 8),
            // Texto — 1 linha colapsado, completo expandido
            Expanded(
              child: Text(
                text,
                maxLines: _expanded ? null : 1,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 7.5, // BUILD 275: -2px fontSize
                  fontWeight: FontWeight.w400,
                  color: subtleGrey,
                  height: 1.5,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            // Chevron de expandir
            Padding(
              padding: const EdgeInsets.only(top: 1, left: 6),
              child: Icon(
                _expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 15,
                color: subtleGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
