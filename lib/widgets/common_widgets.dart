import 'package:flutter/material.dart';
import '../services/drug_interaction_service.dart';
import '../models/drug_model.dart';

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
  static final List<String> _termNames = DrugInteractionService.getAllDrugNames();

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
    widget.controller.selection =
        TextSelection.collapsed(offset: name.length);
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
              hintStyle: TextStyle(color: c.textHint, fontWeight: FontWeight.w500),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 10, right: 6),
                child: Icon(Icons.medication_rounded, size: 17, color: c.textHint),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        widget.controller.clear();
                        widget.onChanged?.call('');
                        _removeOverlay();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Icon(Icons.close_rounded, size: 16, color: c.textHint),
                      ),
                    )
                  : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
      color: dark ? const Color(0xFF242424) : Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.20),
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
              color: dark
                  ? const Color(0xFF333333)
                  : const Color(0xFFF0F0F0),
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
                          ? const Color(0xFFCCCCCC)
                          : const Color(0xFF1A1A1A),
                    ),
                    children: [
                      if (idx > 0)
                        TextSpan(text: name.substring(0, idx)),
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
                          ? const Color(0xFF888888)
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
                  child: Row(children: [
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
                          : const Color(0xFFCCCCCC),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
