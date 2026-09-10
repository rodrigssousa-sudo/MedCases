import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import 'nephro_score_detail_screen.dart';

const _green = Color(0xFF009C3B);
const _darkPage = Color(0xFF171B21);
const _darkSurface = Color(0xFF20252D);
const _darkBorder = Color(0xFF374151);
const _lightPage = Color(0xFFECF0F4);
const _lightSurface = Colors.white;
const _lightBorder = Color(0xFFE2E7EC);

class NephroPremiumWorkspaceScreen extends StatelessWidget {
  const NephroPremiumWorkspaceScreen({super.key});

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
              title: isEs ? 'NEFROLOGÍA' : 'NEFROLOGIA',
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 38),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Scores renales' : 'Scores renais',
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
                          ? 'Seleccione directamente la herramienta que necesita.'
                          : 'Selecione diretamente a ferramenta que precisa.',
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
                          isEs ? 'FUNCIÓN RENAL · ERC' : 'FUNÇÃO RENAL · DRC',
                    ),
                    const SizedBox(height: 8),
                    _ScoreGrid(
                      dark: dark,
                      items: [
                        const _ScoreItem(
                          id: NephroScoreId.ckdEpi2021,
                          icon: Icons.science_outlined,
                          title: 'CKD-EPI 2021',
                          subtitle: 'eGFR',
                          badge: '2021',
                        ),
                        const _ScoreItem(
                          id: NephroScoreId.ckdGa,
                          icon: Icons.grid_view_rounded,
                          title: 'KDIGO G/A',
                          subtitle: 'G1–G5 · A1–A3',
                          badge: '2024',
                        ),
                        const _ScoreItem(
                          id: NephroScoreId.cockcroftGault,
                          icon: Icons.medication_outlined,
                          title: 'Cockcroft-Gault',
                          subtitle: 'CrCl · dose',
                          badge: 'mL/min',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(
                      dark: dark,
                      title:
                          isEs ? 'RIESGO DE PROGRESIÓN' : 'RISCO DE PROGRESSÃO',
                    ),
                    const SizedBox(height: 8),
                    _ScoreGrid(
                      dark: dark,
                      items: [
                        const _ScoreItem(
                          id: NephroScoreId.kfre4,
                          icon: Icons.insights_outlined,
                          title: 'KFRE 4 variables',
                          subtitle: '2 y 5 años',
                          badge: 'KDIGO',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(
                      dark: dark,
                      title: isEs ? 'LESIÓN RENAL AGUDA' : 'LESÃO RENAL AGUDA',
                    ),
                    const SizedBox(height: 8),
                    _ScoreGrid(
                      dark: dark,
                      items: [
                        const _ScoreItem(
                          id: NephroScoreId.kdigoAki,
                          icon: Icons.monitor_heart_outlined,
                          title: 'KDIGO AKI',
                          subtitle: 'Creatinina · diurese',
                          badge: '0–3',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _SectionLabel(
                      dark: dark,
                      title: isEs ? 'ÍNDICES URINARIOS' : 'ÍNDICES URINÁRIOS',
                    ),
                    const SizedBox(height: 8),
                    _ScoreGrid(
                      dark: dark,
                      items: [
                        const _ScoreItem(
                          id: NephroScoreId.fena,
                          icon: Icons.water_drop_outlined,
                          title: 'FENa',
                          subtitle: 'Na · creatinina',
                          badge: '%',
                        ),
                        const _ScoreItem(
                          id: NephroScoreId.feUrea,
                          icon: Icons.opacity_rounded,
                          title: 'FEUrea',
                          subtitle: 'Urea · creatinina',
                          badge: '%',
                        ),
                      ],
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
  final NephroScoreId id;
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                builder: (_) => NephroScoreDetailScreen(
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
        key: ValueKey<String>('nephro_catalog_${item.id.name}'),
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
                      color: _green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      item.icon,
                      color: _green,
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
                      color: _green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      item.badge,
                      style: const TextStyle(
                        color: _green,
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
