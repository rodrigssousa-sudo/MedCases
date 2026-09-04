import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Plantao diagnostic uncertainty uses 2-3 possibilities without false certainty', () {
    final ai = File('lib/services/ai_service.dart').readAsStringSync();
    final adapter = File(
      'lib/services/ai_pipeline/plantao_local_clinical_output_adapter.dart',
    ).readAsStringSync();
    final contract = File(
      'lib/services/ai_pipeline/plantao/contracts/plantao_response_contract.dart',
    ).readAsStringSync();
    final guardia = File(
      'lib/screens/ai/widgets/guardia_clinical_response_view.dart',
    ).readAsStringSync();

    expect(ai, isNot(contains('MAX 2 hipotesis visibles')));
    expect(ai, isNot(contains('MAX 2 hipoteses visiveis')));
    expect(ai, isNot(contains('PROHIBIDO listar 3 o mas')));
    expect(ai, isNot(contains('PROIBIDO listar 3 ou mais')));

    expect(ai, contains('2-3 POSIBILIDADES CLINICAS PRIORITARIAS'));
    expect(ai, contains('2-3 POSSIBILIDADES CLINICAS PRIORITARIAS'));
    expect(ai, contains('Posibilidad 1:'));
    expect(ai, contains('Posibilidad 2:'));
    expect(ai, contains('Posibilidad 3:'));
    expect(ai, contains('Possibilidade 1:'));
    expect(ai, contains('Possibilidade 2:'));
    expect(ai, contains('Possibilidade 3:'));

    expect(
      ai,
      contains(
        'en RUTA DIFERENCIAL omite por completo Tratamiento farmacologico',
      ),
    );
    expect(
      ai,
      contains(
        'na ROTA DIFERENCIAL omita por completo Tratamento farmacologico',
      ),
    );

    expect(adapter, contains('_isDifferentialPresentation(markedDiagnosis)'));
    expect(
      adapter,
      contains("normalized.contains('diferenciales prioritarios')"),
    );
    expect(
      adapter,
      contains("normalized.contains('diferenciais prioritarios')"),
    );

    expect(
      contract,
      contains("es: 'DOLOR TORÁCICO — ORIENTACIÓN CLÍNICA'"),
    );
    expect(
      contract,
      contains("pt: 'DOR TORÁCICA — ORIENTAÇÃO CLÍNICA'"),
    );
    expect(
      contract,
      contains("'Posibilidades clínicas prioritarias'"),
    );

    expect(
      guardia,
      contains("'Posibilidades clínicas prioritarias'"),
    );
    expect(
      guardia,
      contains("'Possibilidades clínicas prioritárias'"),
    );
    expect(guardia, isNot(contains("'Hipótesis principal'")));
    expect(
      guardia,
      contains('final allowMedicationPresentation ='),
    );
    expect(
      guardia,
      contains("'Conducta inmediata'"),
    );
    expect(
      guardia,
      contains("'Conduta imediata'"),
    );
    expect(
      guardia,
      contains("ValueKey('guardia_next_step_section')"),
    );
    expect(
      guardia,
      contains('final hasUserCertaintyContext = userNorm.isNotEmpty;'),
    );
    expect(
      guardia,
      contains('!hasUserCertaintyContext ||'),
    );
  });
}
