// meu_plantao_dashboard.dart
// Feature 2 — Dashboard "Meu Plantão"
//
// Uso na HomeScreen:
//   MeuPlantaoDashboard(
//     onOpenDrug: (drug) => showDrugDetailSheet(context, drug),
//     onOpenCalc: (calcId) => _navigateToCalc(calcId),
//     onManageTap: () => _openPlantaoManageSheet(context),
//   )
//
// Arquitetura:
//   • Consome AppProvider diretamente via context.watch
//   • Sem estado próprio — reativo ao provider
//   • Empty state com Card tracejado animado
//   • Cards de fármacos com scroll horizontal
//   • Cards de calculadoras com scroll horizontal
//   • Botão de "Gerenciar" abre sheet de adição/remoção
//   • Totalmente dark-aware via AppColors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/drug_model.dart';
import '../widgets/common_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE ATALHO DE CALCULADORA
// ─────────────────────────────────────────────────────────────────────────────

class CalcShortcut {
  final String id;
  final String labelPt;
  final String labelEs;
  final IconData icon;
  final Color color;

  const CalcShortcut({
    required this.id,
    required this.labelPt,
    required this.labelEs,
    required this.icon,
    required this.color,
  });

  String label(bool isEs) => isEs ? labelEs : labelPt;
}

/// Catálogo de calculadoras disponíveis para fixar no plantão.
/// Os IDs correspondem aos tabs da ToolsScreen (índices 0–7).
const List<CalcShortcut> kAvailableCalcs = [
  CalcShortcut(
    id: 'calc_biometria',
    labelPt: 'Biometria',
    labelEs: 'Biometría',
    icon: Icons.monitor_weight_outlined,
    color: Color(0xFF3B82F6),
  ),
  CalcShortcut(
    id: 'calc_scores',
    labelPt: 'Scores',
    labelEs: 'Scores',
    icon: Icons.bar_chart_rounded,
    color: Color(0xFF8B5CF6),
  ),
  CalcShortcut(
    id: 'calc_cardio',
    labelPt: 'Cardio',
    labelEs: 'Cardio',
    icon: Icons.favorite_outline_rounded,
    color: Color(0xFFEF4444),
  ),
  CalcShortcut(
    id: 'calc_eletrólitos',
    labelPt: 'Eletrólitos',
    labelEs: 'Electrolitos',
    icon: Icons.science_outlined,
    color: Color(0xFFF59E0B),
  ),
  CalcShortcut(
    id: 'calc_infusao',
    labelPt: 'Infusão EV',
    labelEs: 'Infusión EV',
    icon: Icons.water_drop_outlined,
    color: Color(0xFF06B6D4),
  ),
  CalcShortcut(
    id: 'calc_referencia',
    labelPt: 'Referência',
    labelEs: 'Referencia',
    icon: Icons.menu_book_outlined,
    color: Color(0xFF10B981),
  ),
  CalcShortcut(
    id: 'calc_prescricoes',
    labelPt: 'Prescrições',
    labelEs: 'Prescripciones',
    icon: Icons.receipt_long_outlined,
    color: Color(0xFFC5A365),
  ),
  CalcShortcut(
    id: 'calc_pediatria',
    labelPt: 'Pediatria',
    labelEs: 'Pediatría',
    icon: Icons.child_care_outlined,
    color: Color(0xFFEC4899),
  ),
];

CalcShortcut? calcById(String id) {
  try {
    return kAvailableCalcs.firstWhere((c) => c.id == id);
  } catch (_) {
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class MeuPlantaoDashboard extends StatelessWidget {
  final void Function(DrugModel drug) onOpenDrug;
  final void Function(String calcId) onOpenCalc;
  final void Function() onManageTap;

  const MeuPlantaoDashboard({
    super.key,
    required this.onOpenDrug,
    required this.onOpenCalc,
    required this.onManageTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final c = AppColors.of(context);
    final isEs = p.lang == 'es';
    final hasDrugs = p.pinnedDrugs.isNotEmpty;
    final hasCalcs = p.pinnedCalcIds.isNotEmpty;
    final isEmpty = !hasDrugs && !hasCalcs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho da seção ─────────────────────────────────────────────
        _PlantaoHeader(isEs: isEs, colors: c, onManageTap: onManageTap),
        const SizedBox(height: 14),

        // ── Conteúdo: Empty State ou listas de pins ─────────────────────────
        if (isEmpty)
          _EmptyState(isEs: isEs, colors: c, onTap: onManageTap)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fármacos fixados
              if (hasDrugs) ...[
                _SectionLabel(
                  icon: Icons.medication_outlined,
                  label: isEs ? 'FÁRMACOS' : 'FÁRMACOS',
                  colors: c,
                ),
                const SizedBox(height: 8),
                _PinnedDrugsRow(
                  drugs: p.pinnedDrugs,
                  isEs: isEs,
                  colors: c,
                  onTap: onOpenDrug,
                  onUnpin: (drug) {
                    HapticFeedback.mediumImpact();
                    p.unpinDrug(drug.id);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Calculadoras fixadas
              if (hasCalcs) ...[
                _SectionLabel(
                  icon: Icons.calculate_outlined,
                  label: isEs ? 'CALCULADORAS' : 'CALCULADORAS',
                  colors: c,
                ),
                const SizedBox(height: 8),
                _PinnedCalcsRow(
                  calcIds: p.pinnedCalcIds,
                  isEs: isEs,
                  colors: c,
                  onTap: onOpenCalc,
                  onUnpin: (id) {
                    HapticFeedback.mediumImpact();
                    p.unpinCalc(id);
                  },
                ),
              ],
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CABEÇALHO DA SEÇÃO
// ─────────────────────────────────────────────────────────────────────────────

class _PlantaoHeader extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final VoidCallback onManageTap;

  const _PlantaoHeader({
    required this.isEs,
    required this.colors,
    required this.onManageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Ícone com gradiente verde
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF075f45),
                const Color(0xFF0F8A62),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF075f45).withValues(alpha: 0.30),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_hospital_outlined,
            size: 16,
            color: kGoldLight,
          ),
        ),
        const SizedBox(width: 10),

        // Título
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEs ? 'MI GUARDIA' : 'MEU PLANTÃO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: colors.gold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isEs
                    ? 'Accesos rápidos personalizados'
                    : 'Acessos rápidos personalizados',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // Botão gerenciar
        GestureDetector(
          onTap: onManageTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: colors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.green.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 13, color: colors.green),
                const SizedBox(width: 4),
                Text(
                  isEs ? 'Gestionar' : 'Gerenciar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.green,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE — card tracejado com "+"
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;

  const _EmptyState({
    required this.isEs,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => CustomPaint(
          painter: _DashedBorderPainter(
            color: c.green.withValues(alpha: _pulseAnim.value * 0.4),
            radius: 16,
            dashWidth: 6,
            dashSpace: 5,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: c.green.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícone "+"
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.green.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c.green.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 24,
                    color: c.green,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.isEs
                      ? 'Personaliza tu guardia'
                      : 'Personalize seu plantão',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isEs
                      ? 'Fija aquí tus fármacos y calculadoras más usados para acceso inmediato.'
                      : 'Fixe aqui seus fármacos e calculadoras mais usados para acesso imediato.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.green,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.isEs ? 'Comenzar →' : 'Começar →',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER — borda tracejada animada
// ─────────────────────────────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final metrics = path.computeMetrics().toList();
    for (final metric in metrics) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final next =
            distance + (draw ? dashWidth : dashSpace);
        if (draw) {
          canvas.drawPath(
            metric.extractPath(distance, next.clamp(0, metric.length)),
            paint,
          );
        }
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// LABEL DE SEÇÃO
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors colors;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: colors.textHint),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: colors.textHint,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROW DE FÁRMACOS FIXADOS (scroll horizontal)
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedDrugsRow extends StatelessWidget {
  final List<DrugModel> drugs;
  final bool isEs;
  final AppColors colors;
  final void Function(DrugModel) onTap;
  final void Function(DrugModel) onUnpin;

  const _PinnedDrugsRow({
    required this.drugs,
    required this.isEs,
    required this.colors,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: drugs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _DrugPinnedCard(
          drug: drugs[i],
          isEs: isEs,
          colors: colors,
          onTap: () => onTap(drugs[i]),
          onUnpin: () => onUnpin(drugs[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE FÁRMACO FIXADO
// ─────────────────────────────────────────────────────────────────────────────

class _DrugPinnedCard extends StatefulWidget {
  final DrugModel drug;
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const _DrugPinnedCard({
    required this.drug,
    required this.isEs,
    required this.colors,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  State<_DrugPinnedCard> createState() => _DrugPinnedCardState();
}

class _DrugPinnedCardState extends State<_DrugPinnedCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _showUnpin = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final drug = widget.drug;
    final route = drug.route.toUpperCase();
    final className =
        (drug.className[widget.isEs ? 'es' : 'pt'] ?? drug.className['es'] ?? '');
    // Abreviação da classe (max 14 chars)
    final classShort = className.length > 14
        ? '${className.substring(0, 13)}…'
        : className;

    return GestureDetector(
      onTap: () {
        if (_showUnpin) {
          setState(() => _showUnpin = false);
          return;
        }
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        setState(() => _showUnpin = !_showUnpin);
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 130,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _showUnpin
                ? AppColors.alertRedBg
                : c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showUnpin
                  ? AppColors.alertRedBorder
                  : c.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: c.dark ? 0.25 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _showUnpin
              ? _UnpinOverlay(
                  isEs: widget.isEs,
                  colors: c,
                  onConfirm: widget.onUnpin,
                  onCancel: () => setState(() => _showUnpin = false),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge de rota
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        route.length > 8 ? route.substring(0, 8) : route,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: c.green,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Nome do fármaco
                    Text(
                      drug.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Classe farmacológica
                    Text(
                      classShort,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: c.textHint,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY DE DESAFIXAR
// ─────────────────────────────────────────────────────────────────────────────

class _UnpinOverlay extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _UnpinOverlay({
    required this.isEs,
    required this.colors,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.push_pin_outlined,
            size: 20, color: AppColors.alertRed),
        const SizedBox(height: 6),
        Text(
          isEs ? 'Desfijar?' : 'Desafixar?',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.alertRed,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: onCancel,
              child: Text(
                isEs ? 'No' : 'Não',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: onConfirm,
              child: const Text(
                'OK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.alertRed,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROW DE CALCULADORAS FIXADAS
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedCalcsRow extends StatelessWidget {
  final List<String> calcIds;
  final bool isEs;
  final AppColors colors;
  final void Function(String) onTap;
  final void Function(String) onUnpin;

  const _PinnedCalcsRow({
    required this.calcIds,
    required this.isEs,
    required this.colors,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: calcIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final shortcut = calcById(calcIds[i]);
          if (shortcut == null) return const SizedBox.shrink();
          return _CalcPinnedCard(
            shortcut: shortcut,
            isEs: isEs,
            colors: colors,
            onTap: () => onTap(shortcut.id),
            onUnpin: () => onUnpin(shortcut.id),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE CALCULADORA FIXADA
// ─────────────────────────────────────────────────────────────────────────────

class _CalcPinnedCard extends StatefulWidget {
  final CalcShortcut shortcut;
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const _CalcPinnedCard({
    required this.shortcut,
    required this.isEs,
    required this.colors,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  State<_CalcPinnedCard> createState() => _CalcPinnedCardState();
}

class _CalcPinnedCardState extends State<_CalcPinnedCard> {
  bool _pressed = false;
  bool _showUnpin = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final s = widget.shortcut;

    return GestureDetector(
      onTap: () {
        if (_showUnpin) {
          setState(() => _showUnpin = false);
          return;
        }
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        setState(() => _showUnpin = !_showUnpin);
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 110,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _showUnpin
                ? AppColors.alertRedBg
                : c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showUnpin ? AppColors.alertRedBorder : c.border,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: c.dark ? 0.25 : 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _showUnpin
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.remove_circle_outline,
                        size: 18, color: AppColors.alertRed),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: widget.onUnpin,
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.alertRed,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Ícone colorido
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(s.icon, size: 16, color: s.color),
                    ),

                    // Label
                    Text(
                      s.label(widget.isEs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET DE GERENCIAMENTO — abre via showModalBottomSheet
// ─────────────────────────────────────────────────────────────────────────────

/// Abre o bottom sheet de gerenciamento do plantão.
/// Chamar de qualquer tela que receba [BuildContext].
void showPlantaoManageSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PlantaoManageSheet(),
  );
}

class _PlantaoManageSheet extends StatefulWidget {
  const _PlantaoManageSheet();

  @override
  State<_PlantaoManageSheet> createState() => _PlantaoManageSheetState();
}

class _PlantaoManageSheetState extends State<_PlantaoManageSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final c = AppColors.of(context);
    final isEs = p.lang == 'es';
    final screenH = MediaQuery.of(context).size.height;

    // ── Altura fixa do sheet (88% da tela) ───────────────────────────────────
    // Usamos SizedBox com altura explícita em vez de DraggableScrollableSheet
    // para evitar o conflito de Expanded + scroll infinito que causava o
    // "BOTTOM OVERFLOWED BY 99870 PIXELS".
    return SizedBox(
      height: screenH * 0.88,
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Título ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.push_pin_outlined, size: 20, color: c.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEs ? 'Gestionar Mi Guardia' : 'Gerenciar Meu Plantão',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: c.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isEs
                    ? 'Toca para fijar/desfijar. Límites: ${AppProvider.kMaxPinnedDrugsPublic} fármacos, ${AppProvider.kMaxPinnedCalcsPublic} calculadoras.'
                    : 'Toque para fixar/desafixar. Limites: ${AppProvider.kMaxPinnedDrugsPublic} fármacos, ${AppProvider.kMaxPinnedCalcsPublic} calculadoras.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── TabBar (não-scrollable, fill) ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  // tabAlignment: fill só é válido com isScrollable: false (padrão)
                  // Não definir isScrollable → padrão false → fill é válido
                  labelColor: Colors.white,
                  unselectedLabelColor: c.textSecondary,
                  indicator: BoxDecoration(
                    color: c.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(3),
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800),
                  tabs: [
                    Tab(text: isEs ? 'Fármacos' : 'Fármacos'),
                    Tab(text: isEs ? 'Calculadoras' : 'Calculadoras'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Busca (só aba fármacos) ──────────────────────────────────────
            AnimatedBuilder(
              animation: _tabCtrl,
              builder: (_, __) {
                if (_tabCtrl.index != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 14, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: isEs ? 'Buscar fármaco…' : 'Buscar fármaco…',
                      hintStyle: TextStyle(fontSize: 13, color: c.textHint),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: c.textHint, size: 18),
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                );
              },
            ),

            // ── Conteúdo das abas (Expanded para preencher o restante) ───────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Aba fármacos — ListView próprio com scroll independente
                  _DrugSelectorList(
                    searchQuery: _searchCtrl.text,
                    p: p,
                    c: c,
                    isEs: isEs,
                  ),
                  // Aba calculadoras
                  _CalcSelectorList(
                    p: p,
                    c: c,
                    isEs: isEs,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA DE SELEÇÃO DE FÁRMACOS (dentro do sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _DrugSelectorList extends StatelessWidget {
  final String searchQuery;
  final AppProvider p;
  final AppColors c;
  final bool isEs;

  const _DrugSelectorList({
    required this.searchQuery,
    required this.p,
    required this.c,
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    final q = searchQuery.toLowerCase().trim();
    final drugs = q.isEmpty
        ? p.drugsDB
        : p.drugsDB.where((d) {
            return d.name.toLowerCase().contains(q) ||
                (d.className[isEs ? 'es' : 'pt'] ?? '')
                    .toLowerCase()
                    .contains(q) ||
                d.group.toLowerCase().contains(q);
          }).toList();

    if (drugs.isEmpty) {
      return Center(
        child: Text(
          isEs ? 'Sin resultados' : 'Sem resultados',
          style: TextStyle(color: c.textHint, fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: drugs.length,
      itemBuilder: (_, i) {
        final drug = drugs[i];
        final isPinned = p.isDrugPinned(drug.id);
        final limitReached =
            p.pinnedDrugIds.length >= AppProvider.kMaxPinnedDrugsPublic;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              final result = p.togglePinDrug(drug.id);
              if (result == PinResult.limitReached) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEs
                      ? 'Límite de ${AppProvider.kMaxPinnedDrugsPublic} fármacos alcanzado.'
                      : 'Limite de ${AppProvider.kMaxPinnedDrugsPublic} fármacos atingido.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isPinned
                    ? c.green.withValues(alpha: 0.08)
                    : c.cardBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPinned
                      ? c.green.withValues(alpha: 0.35)
                      : c.border,
                  width: isPinned ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drug.name,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          drug.className[isEs ? 'es' : 'pt'] ??
                              drug.className['es'] ??
                              '',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: c.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge de limite
                  if (!isPinned && limitReached)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEs ? 'Lleno' : 'Cheio',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: c.textHint),
                      ),
                    ),

                  const SizedBox(width: 8),

                  // Ícone pin
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isPinned
                          ? c.green
                          : c.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 14,
                      color: isPinned ? Colors.white : c.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA DE SELEÇÃO DE CALCULADORAS (dentro do sheet)
// ─────────────────────────────────────────────────────────────────────────────

class _CalcSelectorList extends StatelessWidget {
  final AppProvider p;
  final AppColors c;
  final bool isEs;

  const _CalcSelectorList({
    required this.p,
    required this.c,
    required this.isEs,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: kAvailableCalcs.length,
      itemBuilder: (_, i) {
        final shortcut = kAvailableCalcs[i];
        final isPinned = p.isCalcPinned(shortcut.id);
        final limitReached =
            p.pinnedCalcIds.length >= AppProvider.kMaxPinnedCalcsPublic;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              final result = p.togglePinCalc(shortcut.id);
              if (result == PinResult.limitReached) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEs
                      ? 'Límite de ${AppProvider.kMaxPinnedCalcsPublic} calculadoras alcanzado.'
                      : 'Limite de ${AppProvider.kMaxPinnedCalcsPublic} calculadoras atingido.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isPinned
                    ? shortcut.color.withValues(alpha: 0.07)
                    : c.cardBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isPinned
                      ? shortcut.color.withValues(alpha: 0.35)
                      : c.border,
                  width: isPinned ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: shortcut.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(shortcut.icon,
                        size: 20, color: shortcut.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      shortcut.label(isEs),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),

                  if (!isPinned && limitReached)
                    Text(
                      isEs ? 'Lleno' : 'Cheio',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: c.textHint),
                    ),

                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isPinned ? shortcut.color : c.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      size: 14,
                      color: isPinned ? Colors.white : c.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
