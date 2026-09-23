import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/home_v2_palette.dart';
import 'common/home_v2_press_surface.dart';

const Color _kHomeProductiveIconGreen = Color(0xFF10B981);

/// Views exclusivamente visuais da Home V2.
///
/// Não possuem navegação, persistência, Firestore, timers ou lógica clínica.

// HOME_MOBILE_LAYOUT_V2_M1_BEGIN
enum HomeV2ClinicalGridSection {
  all,
  toolsHistory,
  patientPediatrics,
}

class HomeV2GuideSimulationRow extends StatelessWidget {
  const HomeV2GuideSimulationRow({
    required this.dark,
    required this.isEs,
    required this.onGuide,
    required this.onSimulation,
    super.key,
  });

  final bool dark;
  final bool isEs;
  final VoidCallback onGuide;
  final VoidCallback onSimulation;

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);
    return _HomeV2MobilePairSurface(
      palette: palette,
      left: _HomeV2MobilePairButton(
        palette: palette,
        label: isEs ? 'GUÍA CLÍNICA' : 'GUIA CLÍNICO',
        svgAsset: 'assets/icons/home_v2/ic_guia_clinica.svg',
        iconColor: _kHomeProductiveIconGreen,
        onTap: onGuide,
      ),
      right: _HomeV2MobilePairButton(
        palette: palette,
        label: isEs ? 'SIMULACIÓN' : 'SIMULAÇÃO',
        svgAsset: 'assets/icons/home_v2/ic_simulacao.svg',
        iconColor: _kHomeProductiveIconGreen,
        onTap: onSimulation,
      ),
    );
  }
}

class _HomeV2MobilePairSurface extends StatelessWidget {
  const _HomeV2MobilePairSurface({
    required this.palette,
    required this.left,
    required this.right,
  });

  final HomeV2Palette palette;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: HomeV2PressSurface(
              palette: palette,
              child: SizedBox(
                height: 104,
                child: left,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Expanded(
            child: HomeV2PressSurface(
              palette: palette,
              child: SizedBox(
                height: 104,
                child: right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeV2MobilePairButton extends StatelessWidget {
  const _HomeV2MobilePairButton({
    required this.palette,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.svgAsset,

  });

  final HomeV2Palette palette;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  final String? svgAsset;
  final IconData? icon = null;

  @override
  Widget build(BuildContext context) {
    final Widget glyph = svgAsset != null
        ? SvgPicture.asset(
            svgAsset!,
            width: 54,
            height: 54,
          )
        : Icon(
            icon ?? Icons.circle_outlined,
            size: 54,
            color: iconColor,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              glyph,
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// HOME_MOBILE_LAYOUT_V2_M1_HELPERS_END
class HomeV2PrimaryClinicalCard extends StatelessWidget {
  const HomeV2PrimaryClinicalCard({
    required this.dark,
    required this.isEs,
    required this.onTap,
    required this.onVaccine,
    this.embedded = false,
    super.key,
  });

  final bool dark;
  final bool isEs;
  final VoidCallback onTap;
  final VoidCallback onVaccine;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);
    return _HomeV2MobilePairSurface(
      palette: palette,
      left: _HomeV2MobilePairButton(
        palette: palette,
        label: 'FÁRMACOS',
        svgAsset: 'assets/icons/home_v2/ic_farmacos.svg',
        iconColor: _kHomeProductiveIconGreen,
        onTap: onTap,
      ),
      right: _HomeV2MobilePairButton(
        palette: palette,
        label: isEs ? 'VACUNA' : 'VACINA',
        svgAsset: 'assets/icons/home_v2/ic_vacina.svg',
        iconColor: _kHomeProductiveIconGreen,
        onTap: onVaccine,
      ),
    );
  }
}

class HomeV2ClinicalGrid extends StatelessWidget {
  const HomeV2ClinicalGrid({
    required this.dark,
    required this.isEs,
    required this.onPatient,
    required this.onPediatrics,
    required this.onTools,
    required this.onClinicalHistory,
    this.embedded = false,
    this.section = HomeV2ClinicalGridSection.all,
    super.key,
  });

  final bool dark;
  final bool isEs;
  final VoidCallback onPatient;
  final VoidCallback onPediatrics;
  final VoidCallback onTools;
  final VoidCallback onClinicalHistory;
  final bool embedded;
  final HomeV2ClinicalGridSection section;

  Widget _toolsHistory(HomeV2Palette palette) {
    return _HomeV2MobilePairSurface(
      palette: palette,
      left: _HomeV2MobilePairButton(
        palette: palette,
        label: '+SCORES',
        svgAsset: 'assets/icons/home_v2/ic_ferramentas.svg',
        iconColor: _kHomeProductiveIconGreen,
        onTap: onTools,
      ),
      right: _HomeV2MobilePairButton(
        palette: palette,
        label: 'H. CLÍNICA',
        svgAsset: 'assets/icons/home_v2/ic_historia.svg',
        iconColor: _kHomeProductiveIconGreen,
        onTap: onClinicalHistory,
      ),
    );
  }

  Widget _patientPediatrics(HomeV2Palette palette) {
    return _HomeV2MobilePairSurface(
      palette: palette,
      left: _HomeV2MobilePairButton(
        palette: palette,
        label: 'PACIENTES',
        svgAsset: 'assets/icons/home_v2/ic_paciente.svg',
        iconColor: _kHomeProductiveIconGreen,
        onTap: onPatient,
      ),
      right: _HomeV2MobilePairButton(
        palette: palette,
        label: isEs ? 'PEDIATRÍA' : 'PEDIATRIA',
        svgAsset: 'assets/icons/home_v2/ic_pediatria.svg',
        iconColor: _kHomeProductiveIconGreen,
        onTap: onPediatrics,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);
    switch (section) {
      case HomeV2ClinicalGridSection.toolsHistory:
        return _toolsHistory(palette);
      case HomeV2ClinicalGridSection.patientPediatrics:
        return _patientPediatrics(palette);
      case HomeV2ClinicalGridSection.all:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolsHistory(palette),
            const SizedBox(height: 3),
            _patientPediatrics(palette),
          ],
        );
    }
  }
}

/// Superfície visual única do cluster clínico oficial.
///
/// Não recebe callbacks, não possui navegação e não contém lógica clínica.
/// Os filhos continuam sendo os adaptadores canônicos existentes.
class HomeV2ClinicalSurface extends StatelessWidget {
  const HomeV2ClinicalSurface({
    required this.dark,
    required this.primary,
    required this.grid,
    super.key,
  });

  final bool dark;
  final Widget primary;
  final Widget grid;

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);

    return HomeV2PressSurface(
      palette: palette,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          const SizedBox(height: 3),
          grid,
        ],
      ),
    );
  }
}

/// Linha visual de Avaliação, Notas e Timer.
///
/// Os callbacks e o proprietário canônico do timer permanecem externos.
class HomeV2UtilityRow extends StatelessWidget {
  const HomeV2UtilityRow({
    required this.dark,
    required this.isEs,
    required this.onAssessment,
    required this.onLaboratory,
    required this.onNotes,
    required this.onTimer,
    this.betweenRows,
    super.key,
  });

  final bool dark;
  final bool isEs;
  final VoidCallback onAssessment;
  final VoidCallback onLaboratory;
  final VoidCallback onNotes;
  final VoidCallback onTimer;
  final Widget? betweenRows;

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HomeV2MobilePairSurface(
          palette: palette,
          left: _HomeV2MobilePairButton(
            palette: palette,
            label: isEs ? 'LABORATORIO' : 'LABORATÓRIO',
            svgAsset: 'assets/icons/home_v2/ic_laboratorio.svg',
            iconColor: _kHomeProductiveIconGreen,
            onTap: onLaboratory,
          ),
          right: _HomeV2MobilePairButton(
            palette: palette,
            label: isEs ? 'EVALUACIÓN' : 'AVALIAÇÃO',
            svgAsset: 'assets/icons/home_v2/ic_avaliacao.svg',
            iconColor: _kHomeProductiveIconGreen,
            onTap: onAssessment,
          ),
        ),
        if (betweenRows != null) betweenRows!,
        _HomeV2MobilePairSurface(
          palette: palette,
          left: _HomeV2MobilePairButton(
            palette: palette,
            label: isEs ? 'CREAR RESUMEN' : 'CRIAR RESUMO',
            svgAsset: 'assets/icons/home_v2/resumo.svg',
            iconColor: _kHomeProductiveIconGreen,
            onTap: onNotes,
          ),
          right: _HomeV2MobilePairButton(
            palette: palette,
            label: isEs ? 'TEMPORIZADOR' : 'TIMER',
            svgAsset: 'assets/icons/home_v2/ic_timer.svg',
            iconColor: _kHomeProductiveIconGreen,
            onTap: onTimer,
          ),
        ),
      ],
    );
  }
}





class HomeV2GuardiaSurface extends StatelessWidget {
  const HomeV2GuardiaSurface({
    required this.dark,
    required this.isEs,
    required this.child,
    super.key,
  });

  final bool dark;
  final bool isEs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = HomeV2Palette.resolve(dark);

    return HomeV2PressSurface(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              14,
              12,
              14,
              7,
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/home_v2/ic_mi_guardia.svg',
                  width: 44,
                  height: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEs ? 'MI GUARDIA' : 'MEU PLANTÃO',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(width: 76),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
