import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
    test(
      'usa composição vertical, SVGs e divisores oficiais',
      () {
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

        final shortcut = isolateClass(
          modulesSource,
          '_ClinicalShortcut',
          nextClass: '_ModuleIcon',
        );

        expect(
          grid,
          contains('height: 68'),
          reason: 'Cada linha clínica deve possuir altura exata de 68 px.',
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

        expect(
          grid,
          contains('_ClinicalVerticalDivider()'),
          reason: 'A grade deve usar divisores verticais próprios.',
        );

        expect(
          grid,
          contains('_ClinicalHorizontalDivider()'),
          reason: 'A grade deve usar divisor horizontal próprio.',
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

        expect(
          grid,
          contains('iconSize: 31'),
          reason: 'Paciente, Ferramentas e História devem usar SVG 31 px.',
        );

        expect(
          grid,
          contains('iconSize: 30'),
          reason: 'Pediatria deve usar ícone oficial de 30 px.',
        );

        expect(
          shortcut,
          contains('mainAxisAlignment: MainAxisAlignment.center'),
          reason: 'O conteúdo clínico deve permanecer centralizado.',
        );

        expect(
          shortcut,
          contains('crossAxisAlignment: CrossAxisAlignment.center'),
          reason: 'O atalho deve possuir composição vertical centralizada.',
        );

        expect(
          shortcut,
          isNot(contains('final String subtitle;')),
          reason: 'Os atalhos clínicos não devem possuir subtítulos.',
        );

        expect(
          shortcut,
          isNot(contains('required this.subtitle')),
          reason: 'O construtor não deve exigir subtítulo.',
        );

        expect(
          shortcut,
          contains('SvgPicture.asset('),
          reason: 'Os atalhos devem renderizar SVGs oficiais.',
        );

        expect(
          shortcut,
          contains('fontSize: 11'),
          reason: 'Os títulos clínicos devem usar 11 px.',
        );

        expect(
          modulesSource,
          contains('class _ClinicalVerticalDivider extends StatelessWidget'),
          reason: 'O divisor vertical oficial deve existir.',
        );

        expect(
          modulesSource,
          matches(
            RegExp(
              r'class _ClinicalVerticalDivider extends StatelessWidget'
              r'.*?width:\s*1,'
              r'.*?height:\s*68,'
              r'.*?width:\s*0\.55,'
              r'.*?height:\s*42,',
              dotAll: true,
            ),
          ),
          reason: 'O divisor vertical deve usar 1×68 e traço 0.55×42.',
        );

        expect(
          modulesSource,
          contains(
            'class _ClinicalHorizontalDivider extends StatelessWidget',
          ),
          reason: 'O divisor horizontal oficial deve existir.',
        );

        expect(
          modulesSource,
          matches(
            RegExp(
              r'class _ClinicalHorizontalDivider extends StatelessWidget'
              r'.*?horizontal:\s*24'
              r'.*?height:\s*0\.55',
              dotAll: true,
            ),
          ),
          reason:
              'O divisor horizontal deve possuir margem 24 e espessura 0.55.',
        );

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
