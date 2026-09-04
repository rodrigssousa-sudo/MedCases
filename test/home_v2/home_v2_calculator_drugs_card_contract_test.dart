import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String isolateClass(String source, String className) {
  final marker = 'class $className ';

  final start = source.indexOf(marker);

  if (start < 0) {
    throw StateError('Classe $className não localizada.');
  }

  final nextClass = source.indexOf('\nclass ', start + marker.length);

  return nextClass < 0
      ? source.substring(start)
      : source.substring(start, nextClass);
}

void main() {
  group('Home V2 — card Fármacos & Calculadoras', () {
    test(
      'usa o SVG oficial sem card interno decorado',
      () {
        final root = Directory.current;

        final modulesFile = File(
          '${root.path}/lib/home_v2/components/home_v2_modules_view.dart',
        );

        final homeFile = File(
          '${root.path}/lib/screens/home_screen.dart',
        );

        final homeV2File = File(
          '${root.path}/lib/home_v2/home_screen_v2.dart',
        );

        expect(modulesFile.existsSync(), isTrue);
        expect(homeFile.existsSync(), isTrue);
        expect(homeV2File.existsSync(), isTrue);

        final modulesSource = modulesFile.readAsStringSync();
        final homeSource = homeFile.readAsStringSync();
        final homeV2Source = homeV2File.readAsStringSync();

        final card = isolateClass(
          modulesSource,
          'HomeV2PrimaryClinicalCard',
        );

        expect(
          card,
          contains('height: 75'),
          reason: 'O card principal deve possuir altura exata de 75 px.',
        );

        expect(
          card,
          contains('assets/icons/home_v2/ic_farmacos.svg'),
          reason: 'O card deve usar o SVG oficial de fármacos.',
        );

        expect(
          card,
          contains('SvgPicture.asset'),
          reason: 'O SVG deve ser renderizado por SvgPicture.asset.',
        );

        expect(
          card,
          contains('width: 46'),
          reason: 'A área do ícone deve possuir 46 px de largura.',
        );

        expect(
          card,
          contains('height: 46'),
          reason: 'A área do ícone deve possuir 46 px de altura.',
        );

        expect(
          card,
          contains('width: 36'),
          reason: 'O SVG deve possuir largura de 36 px.',
        );

        expect(
          card,
          contains('height: 36'),
          reason: 'O SVG deve possuir altura de 36 px.',
        );

        expect(
          card,
          matches(
            RegExp(
              r'SizedBox\(\s*'
              r'width:\s*46,\s*'
              r'height:\s*46,\s*'
              r'child:\s*Center\(\s*'
              r'child:\s*SvgPicture\.asset\(',
              dotAll: true,
            ),
          ),
          reason:
              'O SVG deve permanecer centralizado em uma área transparente.',
        );

        expect(
          card,
          isNot(
            matches(
              RegExp(
                r'Container\(\s*'
                r'width:\s*46,\s*'
                r'height:\s*46,\s*'
                r'[\s\S]*?'
                r'SvgPicture\.asset\(',
              ),
            ),
          ),
          reason:
              'O ícone não pode permanecer dentro de um Container decorado.',
        );

        final iconStart = card.indexOf(
          "SizedBox(\n"
          "                  width: 46,",
        );

        final iconEnd = card.indexOf(
          'const SizedBox(width: 12)',
          iconStart,
        );

        expect(iconStart, greaterThanOrEqualTo(0));
        expect(iconEnd, greaterThan(iconStart));

        final iconRegion = card.substring(
          iconStart,
          iconEnd,
        );

        expect(
          iconRegion,
          isNot(contains('decoration:')),
          reason: 'A região exclusiva do ícone não deve possuir decoração.',
        );

        expect(
          iconRegion,
          isNot(contains('palette.surfaceStrong')),
          reason: 'A região do ícone não deve possuir fundo surfaceStrong.',
        );

        expect(
          iconRegion,
          isNot(contains('Border.all')),
          reason: 'A região do ícone não deve possuir borda.',
        );

        expect(
          iconRegion,
          isNot(contains('BorderRadius.circular')),
          reason: 'A região do ícone não deve possuir cantos de card.',
        );

        expect(
          card,
          contains("'FÁRMACOS & CALCULADORAS'"),
          reason: 'O título oficial deve permanecer visível.',
        );

        expect(
          card,
          isNot(contains("'Acesso rápido e disponível offline'")),
          reason: 'O subtítulo português deve ser removido.',
        );

        expect(
          card,
          isNot(contains("'Acceso rápido y disponible offline'")),
          reason: 'O subtítulo espanhol deve ser removido.',
        );

        expect(
          card,
          contains('fontSize: 14'),
          reason: 'O título deve usar 14 px.',
        );

        expect(
          card,
          contains('letterSpacing: 0.2'),
          reason: 'O título deve usar letter spacing 0.2.',
        );

        expect(
          card,
          contains('Icons.chevron_right_rounded'),
          reason: 'O chevron oficial deve existir.',
        );

        expect(
          card,
          matches(
            RegExp(
              r'Icons\.chevron_right_rounded,\s*'
              r'size:\s*21,',
              dotAll: true,
            ),
          ),
          reason: 'O chevron deve possuir tamanho 21.',
        );

        expect(
          card,
          contains('onTap: onTap'),
          reason: 'A view deve continuar recebendo callback externo.',
        );

        expect(
          card,
          isNot(contains('Icons.medication_outlined')),
          reason: 'O ícone Material provisório deve ser removido.',
        );

        expect(
          homeSource,
          contains('class HomeCalculatorDrugsCard extends StatelessWidget'),
          reason: 'O adapter público deve permanecer canônico.',
        );

        expect(
          homeSource,
          contains('HomeV2PrimaryClinicalCard('),
          reason: 'O adapter real deve continuar usando a view pura.',
        );

        expect(
          homeSource,
          contains('const CalculadoraScreen()'),
          reason: 'O callback deve continuar abrindo CalculadoraScreen.',
        );

        expect(
          homeV2Source,
          contains('HomeCalculatorDrugsCard('),
          reason: 'O card deve permanecer montado na Home V2.',
        );
      },
    );
  });
}
