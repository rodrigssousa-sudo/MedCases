import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Plantão preserva identidade de patologia/síndrome explícita em ES/PT',
      () {
    final source = File('lib/services/ai_service.dart').readAsStringSync();

    expect(source, contains('IDENTIDAD TEMATICA EXPLICITA'));
    expect(
      source,
      contains('No la sustituyas silenciosamente por otra patologia parecida'),
    );
    expect(source, contains('IDENTIDADE TEMATICA EXPLICITA'));
    expect(
      source,
      contains('Nao a substitua silenciosamente por outra patologia parecida'),
    );

    expect(
      source,
      contains(
        'Sintoma/cuadro inespecifico: "🟥 DOLOR TORACICO — DIFERENCIALES PRIORITARIOS"',
      ),
    );
    expect(
      source,
      contains(
        'Sintoma/quadro inespecifico: "🟥 DOR TORACICA — DIFERENCIAIS PRIORITARIOS"',
      ),
    );
  });
}
