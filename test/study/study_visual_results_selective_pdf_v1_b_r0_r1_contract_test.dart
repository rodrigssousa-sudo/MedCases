import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_pdf_export_service.dart';
import 'package:medcases/services/study/study_visual_result_codec.dart';

void main() {
  test('visual summary enum and codec are functional', () {
    expect(StudyArtifactType.values, contains(StudyArtifactType.visualSummary));

    final data = StudyVisualResultCodec.decodeVisualSummary('''
{
  "title": "Pancreatite aguda",
  "overview": "Inflamação pancreática aguda.",
  "sections": [
    {"title": "Diagnóstico", "body": "Usa critérios clínicos e laboratoriais."},
    {"title": "Tratamento", "body": "O manejo depende da gravidade."}
  ],
  "keyPoints": ["Dor epigástrica", "Avaliar gravidade"],
  "takeaway": "Confirmar diagnóstico e estratificar risco."
}
''');

    expect(data.title, 'Pancreatite aguda');
    expect(data.sections.length, 2);
    expect(data.keyPoints.length, 2);
    expect(data.takeaway, isNotEmpty);
  });

  test('mind map codec produces hierarchy', () {
    final nodes = StudyVisualResultCodec.decodeMindMap(
      '# Tema\n- Diagnóstico\n  - Critério A\n- Tratamento',
    );

    expect(nodes, isNotEmpty);
    expect(nodes.first.depth, 0);
    expect(nodes.any((item) => item.depth > 0), isTrue);

    final clean = StudyVisualResultCodec.stripMarkdown(
      '# Título\n- Item\n1. Outro\n**Negrito**',
    );
    expect(clean, isNot(contains('# ')));
    expect(clean, isNot(contains('**')));
    expect(clean, contains('Título'));
    expect(clean, contains('Item'));
    expect(clean, contains('Outro'));
  });

  test('selective PDF builds selected visual outputs', () async {
    final study = Study(
      id: 'study_test',
      title: 'Estudo teste',
      locale: 'pt-BR',
      createdAtUtc: DateTime.utc(2026, 8, 23),
      artifacts: <StudyArtifact>[
        StudyArtifact(
          id: 'visual',
          type: StudyArtifactType.visualSummary,
          title: 'Resumo visual',
          content:
              '{"title":"Tema","overview":"Visão geral.","sections":[{"title":"A","body":"B"}],"keyPoints":["C"],"takeaway":"D"}',
          createdAtUtc: DateTime.utc(2026, 8, 23),
          sourceIds: const <String>[],
        ),
        StudyArtifact(
          id: 'map',
          type: StudyArtifactType.mindMap,
          title: 'Mapa mental',
          content: '# Tema\n- Ramo\n  - Subramo',
          createdAtUtc: DateTime.utc(2026, 8, 23),
          sourceIds: const <String>[],
        ),
        StudyArtifact(
          id: 'full',
          type: StudyArtifactType.fullSummary,
          title: 'Resumo completo',
          content: 'Texto completo.',
          createdAtUtc: DateTime.utc(2026, 8, 23),
          sourceIds: const <String>[],
        ),
      ],
    );

    final Uint8List pdf = await StudyPdfExportService.buildSelected(
      study,
      isEs: false,
      artifactTypes: <StudyArtifactType>{
        StudyArtifactType.visualSummary,
        StudyArtifactType.mindMap,
      },
    );

    expect(pdf.length, greaterThan(800));
  });
}
