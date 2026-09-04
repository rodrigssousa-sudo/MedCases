import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/data/pediatrics/pediatric_pews_engine_v2026.dart';

void main() {
  test('Brighton PEWS engine includes original +2 modifiers', () {
    final base = BrightonPewsEngineV2026.calculate(
      behavior: 1,
      cardiovascular: 2,
      respiratory: 3,
      quarterHourlyNebulizer: false,
      persistentPostOpVomiting: false,
    );
    expect(base.total, 6);

    final withExtras = BrightonPewsEngineV2026.calculate(
      behavior: 1,
      cardiovascular: 2,
      respiratory: 3,
      quarterHourlyNebulizer: true,
      persistentPostOpVomiting: true,
    );
    expect(withExtras.total, 10);
  });

  test('Pediatrics UI 2026 contract is bound to new clinical foundation', () {
    final tools = File('lib/screens/tools_screen.dart').readAsStringSync();
    final home = File('lib/screens/home_screen.dart').readAsStringSync();

    expect(
      tools,
      contains('MEDCASES_PEDS_2026_UI_RECOVERY_GROWTH_V1_B_R3'),
    );
    expect(tools, contains("'CRECIMIENTO'"));
    expect(tools, contains("'CRESCIMENTO'"));
    expect(tools, contains("'FUNÇÃO RENAL'"));
    expect(tools, contains('PediatricGrowthEngineV2026'));
    expect(tools, contains('PediatricRenalEngineV2026'));
    expect(tools, contains('BrightonPewsEngineV2026'));
    expect(tools, contains('PEDIATRIC_LAB_REFERENCE_REMOVED_V1_B_R3'));
    expect(
      tools,
      contains('MEDCASES_PEDS_2026_TAB_CONTAINER_RUNTIME_FIX_V1_B_R4'),
    );
    expect(
      tools,
      contains('MEDCASES_PEDS_2026_DEVICE_VISUAL_FIX_V1_B_R5'),
    );
    expect(
      tools,
      contains('MEDCASES_PEDS_2026_KEYBOARD_DISMISS_V1_B_R6_R1'),
    );
    expect(
      tools,
      contains('MEDCASES_PEDS_2026_REMOVE_DUPLICATE_NAV_V1_B_R7_R1'),
    );

    final biometryStart = tools.indexOf(
      'Widget _buildBiometria(bool isEs, AppColors c)',
    );
    final growthStart = tools.indexOf(
      'Widget _buildGrowth(bool isEs, AppColors c)',
      biometryStart,
    );
    expect(biometryStart, greaterThanOrEqualTo(0));
    expect(growthStart, greaterThan(biometryStart));

    final biometrySource = tools.substring(biometryStart, growthStart);
    expect(
      biometrySource,
      isNot(contains('_section = _growthSection')),
    );
    expect(
      biometrySource,
      isNot(contains('_section = _renalSection')),
    );
    expect(
      biometrySource,
      isNot(contains('_section = _pewsSection')),
    );
    expect(
      tools,
      contains('onPointerDown: (_)'),
    );
    expect(
      tools,
      contains('FocusManager.instance.primaryFocus?.unfocus()'),
    );
    expect(
      RegExp(
        r'keyboardDismissBehavior:\s*ScrollViewKeyboardDismissBehavior\.onDrag',
      ).hasMatch(tools),
      isTrue,
    );
    expect(
      home,
      contains('MEDCASES_PEDS_2026_DEVICE_VISUAL_FIX_V1_B_R5'),
    );

    final tabStart = tools.indexOf('class _PediatTabRow');
    final tabEnd = tools.indexOf(
      '// ══════════════════════════════════════════════════════════════════\n//  TAB 8 — PEDIATRIA',
      tabStart,
    );
    expect(tabStart, greaterThanOrEqualTo(0));
    expect(tabEnd, greaterThan(tabStart));
    final tabSource = tools.substring(tabStart, tabEnd);

    expect(
      tabSource,
      isNot(
        contains(
          'return Container(\n      color: dark ? const Color(0xFF1A1D23)',
        ),
      ),
    );
    expect(
      tabSource,
      contains(
        'color: surface',
      ),
    );
    expect(
      tabSource,
      isNot(contains('constraints: const BoxConstraints(minWidth: 92)')),
    );

    expect(tools, isNot(contains('_PedRefPremiumView')));
    expect(tools, isNot(contains('_kPedLabCategories')));
    expect(tools, isNot(contains('Peso Ideal (P50 OMS)')));
    expect(tools,
        isNot(contains("['BIOMETRIA', 'SCHWARTZ', 'PEWS', 'REFERÊNCIA']")));

    expect(
      home,
      contains('MEDCASES_PEDS_2026_UI_RECOVERY_GROWTH_V1_B_R3'),
    );
    expect(home, contains('Color(0xFFECF1F3)'));
    expect(home, contains('Color(0xFF252930)'));

    final shellStart = home.indexOf('class _PediatricsShell');
    final adultStart = home.indexOf('// ADULTO SHELL', shellStart);
    expect(shellStart, greaterThanOrEqualTo(0));
    expect(adultStart, greaterThan(shellStart));
    final shell = home.substring(shellStart, adultStart);
    expect(shell, isNot(contains('LinearGradient')));
    expect(shell, isNot(contains('BoxShadow')));
    expect(shell, isNot(contains('extendBodyBehindAppBar: true')));
    expect(shell, isNot(contains('SizedBox(height: 56)')));
    expect(shell, contains('const Expanded(child: PediatricsTabContent())'));
  });
}
