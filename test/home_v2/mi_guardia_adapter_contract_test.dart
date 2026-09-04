import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final legacyHomeSource =
      File('lib/screens/home_screen.dart').readAsStringSync();
  final homeV2Source =
      File('lib/home_v2/home_screen_v2.dart').readAsStringSync();

  group('Adaptador canônico Mi Guardia', () {
    test('HomeScreen oferece slot opcional com fallback canônico', () {
      expect(
        legacyHomeSource,
        contains('final Widget? miGuardiaSection;'),
      );
      expect(
        legacyHomeSource,
        contains('this.miGuardiaSection,'),
      );
      expect(
        legacyHomeSource,
        contains('widget.miGuardiaSection ??'),
      );
      expect(
        legacyHomeSource,
        contains('HomeMiGuardiaSection('),
      );
    });

    test('fachada pública continua delegando ao dashboard real', () {
      expect(
        legacyHomeSource,
        contains('class HomeMiGuardiaSection extends StatelessWidget'),
      );
      expect(
        legacyHomeSource,
        contains('return _HomeMiGuardiaSection('),
      );
      expect(
        legacyHomeSource,
        contains('child: MeuPlantaoDashboard('),
      );
      expect(
        legacyHomeSource,
        isNot(contains('class HomeMiGuardiaController')),
      );
      expect(
        legacyHomeSource,
        isNot(contains('class HomeMiGuardiaRepository')),
      );
    });

    test('guard de Firebase permanece antes da montagem do dashboard', () {
      final adapterStart = legacyHomeSource.indexOf(
        'class HomeMiGuardiaSection extends StatelessWidget',
      );
      final privateStart = legacyHomeSource.indexOf(
        'class _HomeMiGuardiaSection extends StatelessWidget',
      );

      expect(adapterStart, greaterThanOrEqualTo(0));
      expect(privateStart, greaterThan(adapterStart));

      final adapterSource =
          legacyHomeSource.substring(adapterStart, privateStart);

      expect(
        adapterSource,
        contains('FirebaseRuntimeGuard.isUnavailable'),
      );
      expect(
        adapterSource,
        contains('return const SizedBox.shrink();'),
      );
    });

    test('atalhos continuam usando índices oficiais do ToolsScreen', () {
      expect(
        legacyHomeSource,
        contains("'calc_cardio': 1"),
      );
      expect(
        legacyHomeSource,
        contains("'calc_nefrologia': 0"),
      );
      expect(
        legacyHomeSource,
        contains("'calc_hepatologia': 3"),
      );
      expect(
        legacyHomeSource,
        contains(
          'toolsScreenTabNotifier.value = calcTabMap[calcId] ?? 0',
        ),
      );
      expect(
        legacyHomeSource,
        contains('onTabChange(4);'),
      );
    });

    test('fármacos e gerenciamento preservam callbacks reais', () {
      expect(
        legacyHomeSource,
        contains(
          'onOpenDrug: (drug) => showDrugDetailSheet(context, drug)',
        ),
      );
      expect(
        legacyHomeSource,
        contains(
          'onManageTap: () => showPlantaoManageSheet(context)',
        ),
      );
    });

    test('internação preserva PacienteSession e root navigator', () {
      expect(
        legacyHomeSource,
        contains('Navigator.of(context, rootNavigator: true).push('),
      );
      expect(
        legacyHomeSource,
        contains('HomeScreen.slideRoute('),
      );
      expect(
        legacyHomeSource,
        contains('initialSession: session'),
      );
    });

    test('Home V2 monta diretamente a fachada canônica', () {
      expect(
        RegExp(
          r'\bHomeMiGuardiaSection\s*\(',
        ).allMatches(homeV2Source).length,
        1,
      );
      expect(
        homeV2Source,
        isNot(contains('miGuardiaSection:')),
      );
      expect(
        homeV2Source,
        contains('onTabChange: onTabChange'),
      );
      expect(
        homeV2Source,
        contains('openProtocol: openProtocol'),
      );

      expect(
        homeV2Source,
        isNot(contains('MeuPlantaoDashboard(')),
      );
      expect(
        homeV2Source,
        isNot(contains('Firestore')),
      );
      expect(
        homeV2Source,
        isNot(contains('toolsScreenTabNotifier')),
      );
      expect(
        homeV2Source,
        isNot(contains('showPlantaoManageSheet')),
      );
      expect(
        homeV2Source,
        isNot(contains('PacienteSession')),
      );
    });

    test('arquivo de referência não entra na composição oficial', () {
      expect(
        homeV2Source,
        isNot(
          contains(
            "migration_blocks/_HomeMiGuardiaSection.dart",
          ),
        ),
      );
    });

    test('desktop oculto não é reativado por este micro-build', () {
      expect(
        legacyHomeSource,
        contains('/*\n                    Consumer<AppProvider>('),
      );
      expect(
        legacyHomeSource,
        contains('                    */'),
      );
    });
  });
}
