import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_pdf_export_service.dart';

String read(String path) => File(path).readAsStringSync();

String between(String source, String start, String end, String label) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: '$label start');
  expect(b, greaterThan(a), reason: '$label end');
  return source.substring(a, b);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('full summary generation is didactic rather than continuous wall prose',
      () {
    final generator = read('lib/services/study/study_artifact_generator.dart');

    expect(generator, contains('MEDCASES_STUDY_FULL_SUMMARY_DIDACTIC_V2'));
    expect(generator, contains('RESUMO COMPLETO — CONTRATO DIDÁTICO'));
    expect(generator, contains('BLOCOS TEMÁTICOS'));
    expect(generator, contains('2 a 4 frases'));
    expect(generator, contains('45 a 90 palavras'));
    expect(generator, contains('UMA LINHA EM BRANCO'));
    expect(generator, contains('Bullets são permitidos APENAS'));
    expect(generator, contains('Não use tabela no resumo completo'));
    expect(
      generator,
      isNot(
        contains(
          'Produza um resumo completo e aprofundado em prosa acadêmica contínua.',
        ),
      ),
    );
    expect(
      generator,
      isNot(
        contains(
          'Produce un resumen completo y profundo en prosa académica continua.',
        ),
      ),
    );
  });

  test('comparison-table generation is criterion-first, narrow and concise',
      () {
    final generator = read('lib/services/study/study_artifact_generator.dart');

    expect(generator, contains('MEDCASES_STUDY_COMPARISON_TABLE_DIDACTIC_V2'));
    expect(generator, contains('TABELA COMPARATIVA — CONTRATO DIDÁTICO'));
    expect(generator, contains('1ª coluna = CRITÉRIO'));
    expect(generator, contains('mais de 4 entidades'));
    expect(generator, contains('DIVIDA em'));
    expect(
      generator,
      contains('Cada célula deve conter uma informação direta e curta'),
    );
    expect(generator, contains('não force tabela'));
  });

  test('PDF uses shorter semantic paragraph chunks while preserving 14pt body',
      () {
    final pdf = read('lib/services/study/study_pdf_export_service.dart');
    final chunks = between(
      pdf,
      'static List<String> _editorialParagraphChunks(String value)',
      'static List<pw.Widget> _premiumParagraphWidgets',
      'paragraph chunks',
    );
    final body = between(
      pdf,
      'static List<pw.Widget> _premiumParagraphWidgets(String value)',
      'static pw.Widget _premiumBullet',
      'body',
    );

    expect(pdf, contains('MEDCASES_STUDY_PDF_DIDACTIC_PARAGRAPH_RHYTHM_V2'));
    expect(chunks, contains('const targetCharacters = 320'));
    expect(chunks, contains('const maximumCharacters = 440'));
    expect(body, contains('fontSize: 14'));
    expect(body, contains('lineSpacing: 4.6'));
    expect(body, contains('pw.SizedBox(height: 10.5)'));
  });

  test('comparison-table PDF has criterion hierarchy and A4-safe typography',
      () {
    final pdf = read('lib/services/study/study_pdf_export_service.dart');
    final table = between(
      pdf,
      'static List<pw.Widget> _markdownTableWidgets(List<String> rawLines)',
      'static pw.Widget _questionAnswerBlock',
      'table',
    );

    expect(pdf, contains('MEDCASES_STUDY_PDF_COMPARISON_TABLE_PREMIUM_V2'));
    expect(table, contains('pw.TableCellVerticalAlignment.middle'));
    expect(table, contains('0: const pw.FlexColumnWidth(1.45)'));
    expect(table, contains('fontWeight: cellIndex == 0'));
    expect(table, contains('pw.EdgeInsets.fromLTRB(8, 7, 8, 7)'));
    expect(table, contains('fontSize: 9.4'));
    expect(table, contains('fontSize: 9'));
    expect(table, contains('lineSpacing: 2.2'));
  });

  test(
    'runtime PDF still saves didactic prose and a five-column comparison table',
    () async {
      final now = DateTime.utc(2026, 9, 2);
      final artifacts = <StudyArtifact>[
        StudyArtifact(
          id: 'full',
          type: StudyArtifactType.fullSummary,
          title: 'Resumo completo',
          content: '''
FISIOPATOLOGIA
A primeira ideia acadêmica é explicada em poucas frases, com progressão lógica e sem transformar o conteúdo em uma parede de texto. O objetivo deste bloco é comprovar a renderização editorial com separação temática real.

DIAGNÓSTICO
A segunda ideia permanece em outro parágrafo, preservando números, critérios e relações relevantes. Critérios naturalmente enumeráveis podem aparecer em bullets curtos quando isso melhora a revisão.

- Critério A com informação objetiva.
- Critério B com informação objetiva.
- Critério C com informação objetiva.
''',
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
        StudyArtifact(
          id: 'table',
          type: StudyArtifactType.comparisonTable,
          title: 'Tabela comparativa',
          content: '''
| Critério | Entidade A | Entidade B | Entidade C | Entidade D |
| --- | --- | --- | --- | --- |
| Início | Rápido | Gradual | Súbito | Variável |
| Duração | Curta | Longa | Intermediária | Variável |
| Marcador | A1 | B1 | C1 | D1 |
| Conduta | Estratégia A | Estratégia B | Estratégia C | Estratégia D |
''',
          createdAtUtc: now,
          sourceIds: const <String>[],
        ),
      ];

      final study = Study(
        id: 'study_didactic_pdf_v2',
        title: 'Comparação didática',
        locale: 'pt-BR',
        createdAtUtc: now,
        artifacts: artifacts,
      );

      final bytes = await StudyPdfExportService.buildSelected(
        study,
        isEs: false,
        artifactTypes: artifacts.map((item) => item.type).toSet(),
      );

      expect(bytes.length, greaterThan(5000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
