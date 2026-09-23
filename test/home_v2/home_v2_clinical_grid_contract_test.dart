import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'home_clinical_grid_runtime_harness.dart';

String isolateClass(
  String source,
  String className, {
  String? nextClass,
}) {
  final marker = 'class $className ';
  final start = source.indexOf(marker);

  if (start < 0) {
    throw StateError('Classe $className não localizada.');
  }

  final end = nextClass == null
      ? source.indexOf('\nclass ', start + marker.length)
      : source.indexOf('\nclass $nextClass ', start + marker.length);

  return end < 0 ? source.substring(start) : source.substring(start, end);
}

void main() {
  group('Home V2 — grade clínica 2×2', () {
    testWidgets(
      'usa composição vertical, SVGs e geometria produtiva atual',
      (tester) async {
        await verifyClinicalGrid(tester, dark: false, isEs: false);
        final root = Directory.current;

        final modulesFile = File(
          '${root.path}/lib/home_v2/components/home_v2_modules_view.dart',
        );

        final homeFile = File(
          '${root.path}/lib/screens/home_screen.dart',
        );

        expect(modulesFile.existsSync(), isTrue);
        expect(homeFile.existsSync(), isTrue);

        final modulesSource = modulesFile.readAsStringSync();
        final homeSource = homeFile.readAsStringSync();

        final grid = isolateClass(
          modulesSource,
          'HomeV2ClinicalGrid',
          nextClass: 'HomeV2UtilityRow',
        );

        expect(
          grid,
          isNot(contains('GridView.count(')),
          reason: 'A grade fiel não deve usar GridView com gaps artificiais.',
        );

        expect(
          grid,
          isNot(contains('mainAxisSpacing: 1')),
          reason: 'O divisor horizontal substitui o gap do GridView.',
        );

        expect(
          grid,
          isNot(contains('crossAxisSpacing: 1')),
          reason: 'Os divisores verticais substituem o gap do GridView.',
        );

        for (final asset in const [
          'assets/icons/home_v2/ic_paciente.svg',
          'assets/icons/home_v2/ic_pediatria.svg',
          'assets/icons/home_v2/ic_ferramentas.svg',
          'assets/icons/home_v2/ic_historia.svg',
        ]) {
          expect(
            grid,
            contains(asset),
            reason: 'Asset oficial ausente: $asset',
          );
        }

        for (final callback in const [
          'onTap: onPatient',
          'onTap: onPediatrics',
          'onTap: onTools',
          'onTap: onClinicalHistory',
        ]) {
          expect(
            grid,
            contains(callback),
            reason: 'Callback funcional ausente: $callback',
          );
        }

        expect(
          homeSource,
          contains('class HomePatientPediatricsRow extends StatelessWidget'),
          reason: 'O adapter público deve permanecer existente.',
        );

        expect(
          homeSource,
          contains('return HomeV2ClinicalGrid('),
          reason: 'O adapter deve continuar delegando à view visual.',
        );
      },
    );
  });
}
