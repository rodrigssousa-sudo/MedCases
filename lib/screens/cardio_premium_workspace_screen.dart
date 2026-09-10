import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'cardio_score_detail_screen.dart';

const _mcGreen = Color(0xFF009C3B);
const _darkPage = Color(0xFF171B21);
const _darkSurface = Color(0xFF20252D);
const _darkBorder = Color(0xFF374151);
const _lightPage = Color(0xFFECF0F4);
const _lightSurface = Colors.white;
const _lightBorder = Color(0xFFE2E7EC);

class CardioPremiumWorkspaceScreen extends StatelessWidget {
  const CardioPremiumWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isEs = app.lang == 'es';
    final dark = app.darkMode;
    final bg = dark ? _darkPage : _lightPage;
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _CatalogTopbar(
              dark: dark,
              title: isEs ? 'CARDIOLOGÍA' : 'CARDIOLOGIA',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs
                          ? 'Scores cardiovasculares'
                          : 'Scores cardiovasculares',
                      style: TextStyle(
                        color: text,
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isEs
                          ? 'Seleccione directamente el score que necesita.'
                          : 'Selecione diretamente o score que precisa.',
                      style: TextStyle(
                        color: sub,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(
                      dark: dark,
                      title:
                          isEs ? 'SCA · DOLOR TORÁCICO' : 'SCA · DOR TORÁCICA',
                    ),
                    const SizedBox(height: 8),
                    _ScoreGrid(
                      dark: dark,
                      items: [
                        _ScoreItem(
                          id: CardioScoreId.heart,
                          icon: Icons.favorite_outline_rounded,
                          title: 'HEART',
                          subtitle: isEs ? 'Dolor torácico' : 'Dor torácica',
                          badge: '0–10',
                        ),
                        const _ScoreItem(
                          id: CardioScoreId.timiUaNstemi,
                          icon: Icons.stacked_line_chart_rounded,
                          title: 'TIMI',
                          subtitle: 'UA/NSTEMI',
                          badge: '0–7',
                        ),
                        _ScoreItem(
                          id: CardioScoreId.grace,
                          icon: Icons.monitor_heart_outlined,
                          title: 'GRACE',
                          subtitle: isEs ? 'Admisión' : 'Admissão',
                          badge: '>140',
                        ),
                        _ScoreItem(
                          id: CardioScoreId.killip,
                          icon: Icons.air_rounded,
                          title: 'Killip',
                          subtitle: isEs ? 'IAM · IC' : 'IAM · IC',
                          badge: 'I–IV',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(
                      dark: dark,
                      title: isEs
                          ? 'FA · TROMBOEMBOLIA · SANGRADO'
                          : 'FA · TROMBOEMBOLIA · SANGRAMENTO',
                    ),
                    const SizedBox(height: 8),
                    _ScoreGrid(
                      dark: dark,
                      items: [
                        const _ScoreItem(
                          id: CardioScoreId.cha2Ds2Va,
                          icon: Icons.shield_outlined,
                          title: 'CHA₂DS₂-VA',
                          subtitle: 'ESC 2024',
                          badge: '0–8',
                        ),
                        const _ScoreItem(
                          id: CardioScoreId.cha2Ds2Vasc,
                          icon: Icons.shield_outlined,
                          title: 'CHA₂DS₂-VASc',
                          subtitle: 'Referencia',
                          badge: '0–9',
                        ),
                        const _ScoreItem(
                          id: CardioScoreId.hasBled,
                          icon: Icons.water_drop_outlined,
                          title: 'HAS-BLED',
                          subtitle: 'Sangrado',
                          badge: '0–9',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(
                      dark: dark,
                      title:
                          isEs ? 'ECG · REPOLARIZACIÓN' : 'ECG · REPOLARIZAÇÃO',
                    ),
                    const SizedBox(height: 8),
                    _ScoreGrid(
                      dark: dark,
                      items: [
                        const _ScoreItem(
                          id: CardioScoreId.qtcBazett,
                          icon: Icons.timer_outlined,
                          title: 'QTc Bazett',
                          subtitle: 'QT / √RR',
                          badge: 'ms',
                        ),
                        const _ScoreItem(
                          id: CardioScoreId.qtcFridericia,
                          icon: Icons.timer_outlined,
                          title: 'QTc Fridericia',
                          subtitle: 'QT / RR⅓',
                          badge: 'ms',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(
                      dark: dark,
                      title:
                          isEs ? 'PREVENCIÓN PRIMARIA' : 'PREVENÇÃO PRIMÁRIA',
                    ),
                    const SizedBox(height: 8),
                    _ScoreGrid(
                      dark: dark,
                      items: [
                        _ScoreItem(
                          id: CardioScoreId.prevent,
                          icon: Icons.insights_outlined,
                          title: 'PREVENT-ASCVD',
                          subtitle: isEs
                              ? 'Motor oficial requerido'
                              : 'Motor oficial necessário',
                          badge: '2026',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _CatalogNote(
                      dark: dark,
                      text: isEs
                          ? 'Cada score abre en una pantalla propia. Los datos disponibles del paciente pueden importarse al inicio del formulario.'
                          : 'Cada score abre em uma tela própria. Os dados disponíveis do paciente podem ser importados no início do formulário.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreItem {
  final CardioScoreId id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;

  const _ScoreItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
}

class _CatalogTopbar extends StatelessWidget {
  final bool dark;
  final String title;

  const _CatalogTopbar({
    required this.dark,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final text = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final border = dark ? _darkBorder : _lightBorder;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: border, width: 0.7),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 30,
                  color: text,
                ),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: text,
              fontSize: 16,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final bool dark;
  final String title;

  const _SectionLabel({
    required this.dark,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);

    return Text(
      title,
      style: TextStyle(
        color: color,
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.9,
      ),
    );
  }
}

class _ScoreGrid extends StatelessWidget {
  final bool dark;
  final List<_ScoreItem> items;

  const _ScoreGrid({
    required this.dark,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1.58,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ScoreCatalogCard(
          dark: dark,
          item: item,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CardioScoreDetailScreen(
                  scoreId: item.id,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ScoreCatalogCard extends StatelessWidget {
  final bool dark;
  final _ScoreItem item;
  final VoidCallback onTap;

  const _ScoreCatalogCard({
    required this.dark,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = dark ? _darkSurface : _lightSurface;
    final border = dark ? _darkBorder : _lightBorder;
    final title = dark ? const Color(0xFFF8FAFC) : const Color(0xFF111827);
    final sub = dark ? const Color(0xFFAEB9CC) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('cardio_catalog_${item.id.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 10, 10, 9),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 0.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _mcGreen.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      item.icon,
                      color: _mcGreen,
                      size: 21,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _mcGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      item.badge,
                      style: const TextStyle(
                        color: _mcGreen,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: title,
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: sub,
                  fontSize: 8.8,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogNote extends StatelessWidget {
  final bool dark;
  final String text;

  const _CatalogNote({
    required this.dark,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
