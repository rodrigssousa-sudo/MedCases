import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const ownerPath = 'lib/screens/legal_screen.dart';

  String owner() => File(ownerPath).readAsStringSync();

  String consentStateBlock(String source) {
    final start = source.indexOf(
      'class _ConsentModalState extends State<ConsentModal> {',
    );
    final end = source.indexOf(
      '// ── Checkbox de consentimento individual',
      start,
    );
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    return source.substring(start, end);
  }

  String consentCheckBlock(String source) {
    final start = source.indexOf(
      'class _ConsentCheck extends StatelessWidget {',
    );
    expect(start, greaterThanOrEqualTo(0));
    return source.substring(start);
  }

  group('MEDCASES_CONSENT_FLAT_DIRECT_SURFACE_V1_B_R0_R1', () {
    test('uses canonical MedCases consent palette', () {
      final state = consentStateBlock(owner());

      expect(state, contains('static const _kDark = Color(0xFF1A1D23);'));
      expect(state, contains('static const _kAccent = Color(0xFF0D6B57);'));
      expect(state, contains('static const _kLink = Color(0xFF0D6B57);'));
      expect(state, contains('static const _kDivider = Color(0xFF374151);'));

      expect(state, isNot(contains('Color(0xFF07110d)')));
      expect(state, isNot(contains('Color(0xFF075f45)')));
      expect(state, isNot(contains('Color(0xFFD4A96A)')));
    });

    test('consent options are flat rows with thin dividers', () {
      final source = owner();
      final state = consentStateBlock(source);
      final check = consentCheckBlock(source);

      expect(state, contains('Widget divider() => const Divider('));
      expect(RegExp(r'\bdivider\(\),').allMatches(state).length, 3);

      expect(
        check,
        contains(
          'child: Padding(\n'
          '        padding: const EdgeInsets.symmetric(',
        ),
      );

      expect(RegExp(r'AnimatedContainer\(').allMatches(check).length, 1);
      expect(check, isNot(contains('_kGreen.withOpacity(0.12)')));
      expect(check, isNot(contains('Colors.white.withOpacity(0.04)')));
      expect(check, isNot(contains('BorderRadius.circular(12)')));
    });

    test('header is flat and no decorative icon circle remains', () {
      final state = consentStateBlock(owner());

      expect(
        state,
        contains(
          'const Icon(\n'
          '                  Icons.verified_user_rounded,',
        ),
      );
      expect(state, isNot(contains('shape: BoxShape.circle')));
      expect(state, isNot(contains('_kGreen.withOpacity(0.15)')));
    });

    test('legal copy links and acceptance logic stay intact', () {
      final source = owner();

      const requiredLiterals = <String>[
        'Li e aceito os ',
        'He leído y acepto los ',
        'Termos de Uso',
        'Términos de Uso',
        'Li e compreendi a ',
        'He leído y entendido la ',
        'Política de Privacidade',
        'Política de Privacidad',
        'Consinto com o tratamento dos meus dados conforme a LGPD',
        'Consiento el tratamiento de mis datos conforme a la ley de protección de datos',
        'Declaro que sou profissional de saúde habilitado',
        'Declaro que soy profesional de la salud habilitado',
        'ver Aviso Médico',
        'Marque todos os itens',
        'Marque todos los elementos',
      ];

      for (final literal in requiredLiterals) {
        expect(source, contains(literal), reason: literal);
      }

      expect(
        source,
        contains('bool get _allChecked => _c1 && _c2 && _c3 && _c4;'),
      );
      expect(
        source,
        contains('await ConsentGate.saveConsent(lang: widget.lang);'),
      );
      expect(source, contains('widget.onAccepted();'));
      expect(
        source,
        contains('showLegalSheet(context, LegalType.terms, widget.lang)'),
      );
      expect(
        source,
        contains('showLegalSheet(context, LegalType.privacy, widget.lang)'),
      );
      expect(source, contains('context, LegalType.disclaimer, widget.lang'));
    });

    test('CTA is a flat FilledButton rather than decorated container', () {
      final state = consentStateBlock(owner());

      expect(state, contains('child: FilledButton('));
      expect(state, contains('backgroundColor: _kAccent,'));
      expect(
        state,
        contains('disabledBackgroundColor: const Color(0xFF252930),'),
      );
      expect(state, contains('elevation: 0,'));
      expect(state, contains('shadowColor: Colors.transparent,'));
      expect(
        state,
        isNot(
          contains(
            'AnimatedContainer(\n'
            '              duration: const Duration(milliseconds: 200)',
          ),
        ),
      );
    });
  });
}
