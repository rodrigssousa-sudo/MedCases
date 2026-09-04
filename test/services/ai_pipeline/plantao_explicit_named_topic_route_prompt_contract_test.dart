import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('named pathology/syndrome has sovereign direct route in ES/PT', () {
    final source = File('lib/services/ai_service.dart').readAsStringSync();

    for (final token in <String>[
      'PATOLOGIA/SINDROME NOMBRADO = RUTA DIRECTA OBLIGATORIA',
      'PROHIBIDO usar DIFERENCIALES PRIORITARIOS o Posibilidad 1/2/3',
      'Un sindrome NOMBRADO por el usuario es una entidad clinica explicita',
      'RUTA DIFERENCIAL: sintoma o cuadro inespecifico sin diagnostico confirmado',
      'RUTA DIRECTA: patologia o sindrome explicitamente nombrado por el usuario',
      'PATOLOGIA/SINDROME NOMEADO = ROTA DIRETA OBRIGATORIA',
      'PROIBIDO usar DIFERENCIAIS PRIORITARIOS ou Possibilidade 1/2/3',
      'Uma síndrome NOMEADA pelo usuário é entidade clínica explícita',
      'ROTA DIFERENCIAL: sintoma ou quadro inespecifico sem diagnostico confirmado',
      'ROTA DIRETA: patologia ou sindrome explicitamente nomeado pelo usuario',
    ]) {
      expect(source, contains(token), reason: token);
    }

    expect(
      source,
      isNot(
        contains(
          'RUTA DIFERENCIAL: sintoma/sindrome/cuadro inespecifico sin diagnostico confirmado',
        ),
      ),
    );
    expect(
      source,
      isNot(
        contains(
          'ROTA DIFERENCIAL: sintoma/sindrome/quadro inespecifico sem diagnostico confirmado',
        ),
      ),
    );
  });
}
