import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R15 Study direct wrapper does not inject unrelated router keywords', () {
    final source = File('lib/screens/ai_screen.dart').readAsStringSync();

    final start =
        source.indexOf('String _buildStudyContinuationDispatchPrompt({');
    final end = source.indexOf(
      'StudyContinuationResolution _resolveStableStudyContinuationForMessage({',
      start,
    );

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final helper = source.substring(start, end);

    expect(
      helper,
      contains(r'Acción seleccionada por el usuario: $safeLabel'),
    );
    expect(
      helper,
      contains(r'Ação selecionada pelo usuário: $safeLabel'),
    );
    expect(
      helper,
      contains(r'Instrucción clínica de apoyo: $prompt'),
    );
    expect(
      helper,
      contains(r'Instrução clínica de apoio: $prompt'),
    );

    expect(helper, contains('No hagas preguntas de confirmación'));
    expect(helper, contains('Não faça perguntas de confirmação'));
    expect(helper, contains('guard=generic_no_choice_terms'));

    expect(
      helper,
      isNot(contains('No preguntes si el usuario desea dosis')),
    );
    expect(
      helper,
      isNot(contains('Não pergunte se o usuário deseja doses')),
    );
    expect(
      helper,
      isNot(
        contains(
          'dosis, diagnóstico, fisiopatología, tratamiento u otra opción',
        ),
      ),
    );
    expect(
      helper,
      isNot(
        contains(
          'doses, diagnóstico, fisiopatologia, tratamento ou outra opção',
        ),
      ),
    );
  });
}
