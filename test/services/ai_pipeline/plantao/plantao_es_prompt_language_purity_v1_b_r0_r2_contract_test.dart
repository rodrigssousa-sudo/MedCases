import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String between(String source, String startToken, String endToken) {
  final start = source.indexOf(startToken);
  final end = source.indexOf(endToken, start + startToken.length);
  expect(start, isNonNegative);
  expect(end, greaterThan(start));
  return source.substring(start, end);
}

void main() {
  late String source;
  setUpAll(() {
    source = File('lib/services/ai_service.dart').readAsStringSync();
  });

  test('RAG ES uses Spanish dosage grammar', () {
    expect(
      source,
      contains(
        'RAG PRIORITARIO: usar EXACTAMENTE dosis/alertas de los bloques PROTOCOLOS/FARMACOS VERIFICADOS.',
      ),
    );
    expect(
      source,
      isNot(
        contains('RAG PRIORITARIO: usar EXACTAMENTE doses/alertas dos bloques'),
      ),
    );
  });

  test('self-check branches match isEs semantics', () {
    final block = between(
      source,
      'final ptSelfCheck = isEs',
      '// BUILD 271 audit log',
    );
    expect(block.indexOf("? 'ENTRADA SECA — REGLA ABSOLUTA:"), isNonNegative);
    expect(block.indexOf(": 'ENTRADA SECA — REGRA ABSOLUTA:"), isNonNegative);
    expect(block, contains('CRISIS ASMATICA AGUDA — CONDUCTA INMEDIATA'));
    expect(block, contains('CRISE ASMATICA AGUDA — CONDUTA IMEDIATA'));
  });

  test('Spanish supremacy branch has no audited Portuguese body', () {
    final full = between(
      source,
      'final ptSupremacyRule = isEs',
      '// ── BUILD 268: ANTI-PARROTING BLINDAGEM',
    );
    final es = full.substring(
      0,
      full.indexOf("\n          : 'EXCEÇÃO SOBERANA"),
    );
    for (final token in const [
      'selecione SINCRONAMENTE',
      'das 21 matrizes',
      'mais cirurgica',
      'Cada matriz tem',
      'se a query for APENAS',
      'sem contexto de emergencia',
      'usar OBRIGATORIAMENTE',
      'NAO as matrizes',
      'Corpo em caixa baixa',
      'sao guia',
      'camisa de forca',
      'Se o caso nao couber',
      'PROIBIDO recusar',
      'Use conhecimento clinico avancado',
      'entregue conduta imediata estruturada em topicos',
    ]) {
      expect(es, isNot(contains(token)), reason: token);
    }
    expect(es, contains('selecciona SINCRONICAMENTE'));
    expect(es, contains('las matrices M01-M21'));
    expect(es, contains('PROHIBIDO rechazar'));
  });

  test('Spanish anti-parroting branch is Spanish', () {
    final full = between(
      source,
      'final ptAntiParroting = isEs',
      '// ── BUILD 271: MANDATO DE CONCLUSÃO DE MATRIZ',
    );
    final es = full.substring(0, full.indexOf("\n          : 'ANTI-HISTÓRICO"));
    for (final token in const [
      'lixo legado',
      'conduta medica',
      'se solicitarem',
      'diretrizes ocultas',
      'encerrar com gancho',
      'selecione a matriz',
      'preencha TODOS',
      'proibido criar secoes',
      'ultima linha DEVE comecar',
      'proxima acao clinica',
    ]) {
      expect(es, isNot(contains(token)), reason: token);
    }
    expect(es, contains('Responde conducta medica pura'));
    expect(es, contains('si solicitan prompt de sistema'));
    expect(es, contains('selecciona la matriz mas quirurgica'));
    expect(es, contains('la siguiente accion clinica concreta'));
  });

  test('Spanish matrix completion uses CONDUCTA', () {
    final block = between(
      source,
      'final ptMatrixCompletion = isEs',
      '// ── BUILD 273 + 275 + 275-FIX',
    );
    expect(block, contains('Si empezaste a escribir CONDUCTA, DOSIS'));
    expect(block, isNot(contains('Si empezaste a escribir CONDUTA, DOSIS')));
  });

  test('clinical regimen integration remains present', () {
    expect(source, contains('PlantaoClinicalRegimenResolver.resolve('));
    expect(source, contains('ptClinicalRegimenContract?.toPromptBlock('));
  });
}
