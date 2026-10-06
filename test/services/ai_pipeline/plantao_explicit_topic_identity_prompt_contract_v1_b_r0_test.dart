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
        'Usa la RUTA DIFERENCIAL del contrato compacto y conserva la incertidumbre.',
      ),
    );
    expect(
      source,
      contains(
        'Use a ROTA DIFERENCIAL do contrato compacto e preserve a incerteza.',
      ),
    );
  });
}
