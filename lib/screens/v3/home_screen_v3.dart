import 'package:flutter/material.dart';

import '../../design_system/foundation/med_typography.dart';
import '../../design_system/tokens/med_colors.dart';
import '../../design_system/tokens/med_radius.dart';
import '../../design_system/tokens/med_spacing.dart';

/// Reconstrução visual paralela da Home.
///
/// Esta tela não substitui nem importa a Home legada. A integração ao shell
/// principal deverá ocorrer somente após validação funcional e visual.
class HomeScreenV3 extends StatelessWidget {
  const HomeScreenV3({
    required this.onTabChange,
    required this.onSubTabChange,
    required this.openProtocol,
    required this.onOpenNotes,
    super.key,
    this.onCheckUpdate,
  });

  final ValueChanged<int> onTabChange;
  final ValueChanged<int> onSubTabChange;
  final Function(String) openProtocol;
  final VoidCallback onOpenNotes;
  final VoidCallback? onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color background =
        isDark ? MedColors.darkBackground : MedColors.background;
    final Color surface = isDark ? MedColors.darkSurface : MedColors.surface;
    final Color elevatedSurface =
        isDark ? MedColors.darkSurfaceElevated : MedColors.surfaceElevated;
    final Color border = isDark ? MedColors.darkBorder : MedColors.border;
    final Color primaryText =
        isDark ? MedColors.darkTextPrimary : MedColors.textPrimary;
    final Color secondaryText =
        isDark ? MedColors.darkTextSecondary : MedColors.textSecondary;

    return ColoredBox(
      color: background,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 900;
          final double horizontalPadding = wide ? MedSpacing.xl : MedSpacing.lg;
          final double maxContentWidth = wide ? 1180 : 720;

          return SingleChildScrollView(
            key: const Key('home-v3-scroll'),
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              MedSpacing.lg,
              horizontalPadding,
              MedSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _HomeV3Header(
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      surface: surface,
                      border: border,
                    ),
                    const SizedBox(height: MedSpacing.lg),
                    _HomeV3AiEntry(
                      surface: elevatedSurface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      onTap: () => onTabChange(2),
                    ),
                    const SizedBox(height: MedSpacing.lg),
                    _HomeV3PrimaryActions(
                      wide: wide,
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      onOpenCalculator: () => onTabChange(4),
                      onOpenDrugs: () => onSubTabChange(0),
                    ),
                    const SizedBox(height: MedSpacing.lg),
                    _HomeV3NavigationGrid(
                      wide: wide,
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      onOpenPatient: () => openProtocol('adulto'),
                      onOpenPediatrics: () => onSubTabChange(1),
                      onOpenLibrary: () => onTabChange(5),
                      onOpenHistory: () => onTabChange(3),
                    ),
                    const SizedBox(height: MedSpacing.lg),
                    _HomeV3QuickActions(
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      onOpenNotes: onOpenNotes,
                      onCheckUpdate: onCheckUpdate,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HomeV3Header extends StatelessWidget {
  const _HomeV3Header({
    required this.primaryText,
    required this.secondaryText,
    required this.surface,
    required this.border,
  });

  final Color primaryText;
  final Color secondaryText;
  final Color surface;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsets.all(MedSpacing.xl),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: MedRadius.xLarge,
          border: Border.all(color: border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MedColors.primary,
                borderRadius: MedRadius.large,
              ),
              child: Text(
                'M+',
                style: MedTypography.titleMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: MedSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'MedCases Pro',
                    key: const Key('home-v3-title'),
                    style: MedTypography.titleLarge.copyWith(
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: MedSpacing.xs),
                  Text(
                    'Apoio clínico, estudo e decisões em um só lugar.',
                    style: MedTypography.bodyMedium.copyWith(
                      color: secondaryText,
                    ),
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

class _HomeV3AiEntry extends StatelessWidget {
  const _HomeV3AiEntry({
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
  });

  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Abrir inteligência artificial',
      child: Material(
        color: surface,
        borderRadius: MedRadius.xLarge,
        child: InkWell(
          key: const Key('home-v3-ai'),
          borderRadius: MedRadius.xLarge,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(MedSpacing.xl),
            decoration: BoxDecoration(
              borderRadius: MedRadius.xLarge,
              border: Border.all(color: border),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: MedColors.primary,
                  size: 28,
                ),
                const SizedBox(width: MedSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Inteligência Artificial',
                        style: MedTypography.titleMedium.copyWith(
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: MedSpacing.xs),
                      Text(
                        'Inicie uma consulta ou continue na tela completa.',
                        style: MedTypography.bodySmall.copyWith(
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MedSpacing.sm),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: secondaryText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeV3PrimaryActions extends StatelessWidget {
  const _HomeV3PrimaryActions({
    required this.wide,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.onOpenCalculator,
    required this.onOpenDrugs,
  });

  final bool wide;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onOpenCalculator;
  final VoidCallback onOpenDrugs;

  @override
  Widget build(BuildContext context) {
    final Widget calculator = _HomeV3ActionCard(
      actionKey: const Key('home-v3-calculator'),
      icon: Icons.calculate_rounded,
      title: 'Calculadoras',
      subtitle: 'Scores, doses e ferramentas clínicas',
      surface: surface,
      border: border,
      primaryText: primaryText,
      secondaryText: secondaryText,
      onTap: onOpenCalculator,
    );

    final Widget drugs = _HomeV3ActionCard(
      actionKey: const Key('home-v3-drugs'),
      icon: Icons.medication_rounded,
      title: 'Fármacos',
      subtitle: 'Biblioteca e consulta rápida',
      surface: surface,
      border: border,
      primaryText: primaryText,
      secondaryText: secondaryText,
      onTap: onOpenDrugs,
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: calculator),
          const SizedBox(width: MedSpacing.md),
          Expanded(child: drugs),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        calculator,
        const SizedBox(height: MedSpacing.md),
        drugs,
      ],
    );
  }
}

class _HomeV3NavigationGrid extends StatelessWidget {
  const _HomeV3NavigationGrid({
    required this.wide,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.onOpenPatient,
    required this.onOpenPediatrics,
    required this.onOpenLibrary,
    required this.onOpenHistory,
  });

  final bool wide;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onOpenPatient;
  final VoidCallback onOpenPediatrics;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final List<_HomeV3NavigationData> items = <_HomeV3NavigationData>[
      _HomeV3NavigationData(
        key: const Key('home-v3-patient'),
        icon: Icons.person_rounded,
        title: 'Paciente',
        subtitle: 'Casos e acompanhamento clínico',
        onTap: onOpenPatient,
      ),
      _HomeV3NavigationData(
        key: const Key('home-v3-pediatrics'),
        icon: Icons.child_care_rounded,
        title: 'Pediatria',
        subtitle: 'Conteúdo pediátrico',
        onTap: onOpenPediatrics,
      ),
      _HomeV3NavigationData(
        key: const Key('home-v3-library'),
        icon: Icons.menu_book_rounded,
        title: 'Biblioteca',
        subtitle: 'Referências clínicas',
        onTap: onOpenLibrary,
      ),
      _HomeV3NavigationData(
        key: const Key('home-v3-history'),
        icon: Icons.assignment_ind_rounded,
        title: 'H. Clínica',
        subtitle: 'Histórico do paciente',
        onTap: onOpenHistory,
      ),
    ];

    return GridView.builder(
      key: const Key('home-v3-navigation-grid'),
      shrinkWrap: true,
      primary: false,
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 4 : 2,
        crossAxisSpacing: MedSpacing.md,
        mainAxisSpacing: MedSpacing.md,
        childAspectRatio: wide ? 1.15 : 1.05,
      ),
      itemBuilder: (BuildContext context, int index) {
        final _HomeV3NavigationData item = items[index];

        return _HomeV3ActionCard(
          actionKey: item.key,
          icon: item.icon,
          title: item.title,
          subtitle: item.subtitle,
          surface: surface,
          border: border,
          primaryText: primaryText,
          secondaryText: secondaryText,
          onTap: item.onTap,
        );
      },
    );
  }
}

class _HomeV3QuickActions extends StatelessWidget {
  const _HomeV3QuickActions({
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.onOpenNotes,
    required this.onCheckUpdate,
  });

  final Color surface;
  final Color border;
  final Color primaryText;
  final VoidCallback onOpenNotes;
  final VoidCallback? onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MedSpacing.sm),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: MedRadius.large,
        border: Border.all(color: border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextButton.icon(
              key: const Key('home-v3-notes'),
              onPressed: onOpenNotes,
              icon: const Icon(Icons.note_alt_rounded),
              label: const Text('Notas'),
              style: TextButton.styleFrom(
                foregroundColor: primaryText,
              ),
            ),
          ),
          if (onCheckUpdate != null) ...<Widget>[
            Container(
              width: 1,
              height: 28,
              color: border,
            ),
            Expanded(
              child: TextButton.icon(
                key: const Key('home-v3-update'),
                onPressed: onCheckUpdate,
                icon: const Icon(Icons.system_update_rounded),
                label: const Text('Atualização'),
                style: TextButton.styleFrom(
                  foregroundColor: primaryText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeV3ActionCard extends StatelessWidget {
  const _HomeV3ActionCard({
    required this.actionKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: surface,
        borderRadius: MedRadius.large,
        child: InkWell(
          key: actionKey,
          borderRadius: MedRadius.large,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 112),
            padding: const EdgeInsets.all(MedSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: MedRadius.large,
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  icon,
                  color: MedColors.primary,
                  size: 26,
                ),
                const SizedBox(height: MedSpacing.lg),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MedTypography.titleMedium.copyWith(
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: MedSpacing.xs),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MedTypography.bodySmall.copyWith(
                    color: secondaryText,
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

class _HomeV3NavigationData {
  const _HomeV3NavigationData({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key key;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}
