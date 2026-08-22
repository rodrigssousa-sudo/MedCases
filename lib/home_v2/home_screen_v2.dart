// ============================================================================
// MEDCASES PRO
// HOME V2 — ÁRVORE VISUAL OFICIAL
// ============================================================================
//
// Este arquivo é o único proprietário da composição, do scroll e do layout
// estrutural da nova Home.
//
// IA, histórico, persistência, timer, notificações, navegação clínica e demais
// motores continuam pertencendo às implementações canônicas já auditadas.
// ============================================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../screens/home_screen.dart';
import 'components/chat/inline_chat.dart';
import 'components/common/home_v2_press_surface.dart';
import 'components/home_v2_modules_view.dart';

import 'theme/home_v2_palette.dart';

class HomeScreenV2 extends StatelessWidget {
  const HomeScreenV2({
    required this.onTabChange,
    required this.onSubTabChange,
    required this.openProtocol,
    required this.onOpenNotes,
    required this.onOpenClinicalGuide,
    required this.onOpenSimulation,
    required this.onOpenVaccine,
    super.key,
    this.onCheckUpdate,
  });

  final ValueChanged<int> onTabChange;
  final ValueChanged<int> onSubTabChange;
  final Function(String) openProtocol;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenClinicalGuide;
  final VoidCallback onOpenSimulation;
  final VoidCallback onOpenVaccine;
  final VoidCallback? onCheckUpdate;

  @override
  Widget build(BuildContext context) {
    final dark = context.select<AppProvider, bool>(
      (AppProvider provider) => provider.darkMode,
    );
    final isEs = context.select<AppProvider, bool>(
      (AppProvider provider) => provider.lang == 'es',
    );

    final mediaQuery = MediaQuery.of(context);
    final viewportWidth = mediaQuery.size.width;
    final systemTopInset = mediaQuery.padding.top;
    final systemBottomInset = mediaQuery.padding.bottom;

    // Status bar/Dynamic Island + topbar de 48 px + respiro oficial de 6 px.
    // O padding pertence ao scroll: o estado inicial permanece protegido,
    // enquanto o conteúdo pode passar atrás do vidro durante a rolagem.
    // MEDCASES_WEB_HOME_40_TOPBAR_TO_INLINE_AI_GAP_5PX_V1_B_R0
    // Web já possui topbar real externa de 48 px; não duplicar compensação.
    // Native preserva exatamente o contrato anterior com status bar + topbar.
    final double topContentPadding = kIsWeb ? 5.0 : systemTopInset + 54.0;
    final bottomContentPadding = kIsWeb ? 32.0 : systemBottomInset + 152.0;
    const horizontalPadding = 0.0;
    final contentMaxWidth = viewportWidth >= 600 ? 860.0 : double.infinity;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: ColoredBox(
        color: HomeV2SurfaceTokens.pageBackground(dark),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: SingleChildScrollView(
              key: const PageStorageKey<String>('home-v2-scroll'),
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topContentPadding,
                horizontalPadding,
                bottomContentPadding,
              ),
              child: _HomeV2VisualShell(
                dark,
                isEs,
                onOpenClinicalGuide,
                onOpenSimulation,
                InlineChat(dark: dark, isEs: isEs, onNavigateToAi: onTabChange),
                HomeCalculatorDrugsCard(
                  dark: dark,
                  isEs: isEs,
                  onOpenVaccine: onOpenVaccine,
                  embedded: true,
                ),
                HomePatientPediatricsRow(
                  dark: dark,
                  isEs: isEs,
                  openProtocol: openProtocol,
                  onTabChange: onTabChange,
                  embedded: true,
                  section: HomeV2ClinicalGridSection.toolsHistory,
                ),
                HomeLibraryHistoryRow(
                  dark: dark,
                  isEs: isEs,
                  onTabChange: onTabChange,
                ),
                HomeAssessmentNotesTimerCard(
                  dark: dark,
                  isEs: isEs,
                  openProtocol: openProtocol,
                  onOpenNotes: onOpenNotes,
                  onCheckUpdate: onCheckUpdate,
                  betweenRows: HomePatientPediatricsRow(
                    dark: dark,
                    isEs: isEs,
                    openProtocol: openProtocol,
                    onTabChange: onTabChange,
                    embedded: true,
                    section: HomeV2ClinicalGridSection.patientPediatrics,
                  ),

                  onTabChange: onTabChange,
                ),
                HomeMiGuardiaSection(
                  dark: dark,
                  isEs: isEs,
                  onTabChange: onTabChange,
                  openProtocol: openProtocol,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeV2VisualShell extends StatelessWidget {
  const _HomeV2VisualShell(
    this.dark,
    this.isEs,
    this.onOpenClinicalGuide,
    this.onOpenSimulation,
    this.chat,
    this.primaryClinicalModule,
    this.patientPediatricsModule,
    this.libraryHistoryModule,
    this.utilityModule,
    this.guardiaModule,
  );

  final bool dark;
  final bool isEs;
  final VoidCallback onOpenClinicalGuide;
  final VoidCallback onOpenSimulation;
  final Widget chat;
  final Widget primaryClinicalModule;
  final Widget patientPediatricsModule;
  final Widget libraryHistoryModule;
  final Widget utilityModule;
  final Widget guardiaModule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chat,
        const SizedBox(height: 5),
        HomeV2GuideSimulationRow(
          dark: dark,
          isEs: isEs,
          onGuide: onOpenClinicalGuide,
          onSimulation: onOpenSimulation,
        ),
        SizedBox(
          height: 0.55,
          child: ColoredBox(color: HomeV2Palette.resolve(dark).border),
        ),
        _HomeV2ClinicalCluster(
          dark,
          primaryClinicalModule,
          patientPediatricsModule,
          libraryHistoryModule,
        ),
        SizedBox(
          height: 0.55,
          child: ColoredBox(color: HomeV2Palette.resolve(dark).border),
        ),
        _HomeV2UtilityCluster(utilityModule, guardiaModule),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _HomeV2ClinicalCluster extends StatelessWidget {
  const _HomeV2ClinicalCluster(
    this.dark,
    this.primaryModule,
    this.patientModule,
    this.libraryModule,
  );

  final bool dark;
  final Widget primaryModule;
  final Widget patientModule;

  /// Ponte invisível temporária.
  ///
  /// Será removida na limpeza final, após a homologação completa das rotas.
  final Widget libraryModule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [primaryModule, patientModule, libraryModule],
    );
  }
}

class _HomeV2UtilityCluster extends StatelessWidget {
  const _HomeV2UtilityCluster(this.utilityModule, this.guardiaModule);

  final Widget utilityModule;
  final Widget guardiaModule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [utilityModule, const SizedBox(height: 5), guardiaModule],
    );
  }
}
