import 'package:medcases/services/study/study_artifact_generator.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_pdf_export_service.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_visual_result_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('generator preserves complete prefixed fenced visual envelope', () {
    final raw = 'Resultado:\n```json\n${jsonEncode({
          "title": "Resumo",
          "overview": "Texto completo."
        })}\n```';
    final content = StudyArtifactGenerator.prepareVisualContent(raw);
    expect(StudyVisualResultCodec.decodeVisualSummary(content).title, 'Resumo');
    expect(content, raw);
  });
  test('generator rejects truncated visual envelope', () {
    expect(
        () => StudyArtifactGenerator.prepareVisualContent(
            'Resultado:\n```json\n{"title":"Resumo"'),
        throwsStateError);
  });
  test('valid overview does not require optional blocks', () {
    expect(
        StudyVisualResultCodec.isCompleteStructuredSummary(jsonEncode({
          'title': 'Síndrome de Cushing',
          'overview': 'Material fictício de revisão.'
        })),
        isTrue);
  });
  test('one valid section is enough without overview', () {
    expect(
        StudyVisualResultCodec.isCompleteStructuredSummary(jsonEncode({
          'title': 'Síndrome de Cushing',
          'sections': [
            {'title': 'Conceito', 'body': 'Explicação completa.'}
          ]
        })),
        isTrue);
  });
  test('safe unfenced envelope is decoded without exposing wrapper', () {
    final raw = 'Resultado:\n${jsonEncode({
          'title': 'Síndrome de Cushing',
          'overview': 'Explicação completa.'
        })}\nFim do JSON.';
    expect(StudyVisualResultCodec.decodeVisualSummary(raw).title,
        'Síndrome de Cushing');
  });
  test('all valid sections and key points retain numbers', () {
    final raw = jsonEncode({
      'title': 'Revisão',
      'overview': 'Exemplo sintético.',
      'sections': List.generate(
          12, (i) => {'title': 'Item $i', 'body': 'Valor ${i + 1} mg.'}),
      'keyPoints': List.generate(14, (i) => 'Intervalo ${i + 1} h.'),
      'takeaway': ''
    });
    final data = StudyVisualResultCodec.decodeVisualSummary(raw);
    expect(data.sections.length, 12);
    expect(data.keyPoints.length, 14);
  });
  test(
      'safe suffix and missing malformed optional block do not reject valid body',
      () {
    final raw = '${jsonEncode({
          'title': 'Cushing',
          'overview': 'Texto completo.',
          'keyPoints': null
        })}\nFim do JSON.';
    expect(StudyVisualResultCodec.isCompleteStructuredSummary(raw), isTrue);
    expect(StudyVisualResultCodec.decodeVisualSummary(raw).overview,
        'Texto completo.');
  });
  for (final raw in [
    'Resultado: {broken',
    '{"title":"Cushing",',
    'Resultado: {"title":"Cushing"} {"debug":1}',
    'stacktrace: {"title":"Cushing","overview":"Texto."}'
  ]) {
    test('invalid payload is never rendered: ${raw.length}', () {
      expect(StudyVisualResultCodec.isCompleteStructuredSummary(raw), isFalse);
      final rendered =
          StudyVisualResultCodec.decodeVisualSummary(raw, isEs: true);
      expect(rendered.overview, isNot(contains('{')));
      expect(rendered.overview, isNot(contains('stacktrace')));
    });
  }

  test('long semantic visual blocks export without overflow', () async {
    final raw = jsonEncode({
      'title': 'Síndrome de Cushing',
      'overview': 'Revisão sintética.',
      'sections': List.generate(
          12,
          (i) => {
                'title': 'Seção $i',
                'body': List.filled(
                        12, 'Texto educativo sintético com uma ideia completa.')
                    .join(' ')
              }),
      'keyPoints': ['Exemplo sintético: 5 mg, 24 h, 2–4 mL.']
    });
    final now = DateTime.utc(2026);
    final study = Study(
        id: 'pdf',
        title: 'Cushing',
        locale: 'pt',
        createdAtUtc: now,
        artifacts: [
          StudyArtifact(
              id: 'visual-pdf',
              type: StudyArtifactType.visualSummary,
              title: 'Visual',
              content: raw,
              createdAtUtc: now,
              sourceIds: ['synthetic'])
        ]);
    final bytes = await StudyPdfExportService.buildSelected(study,
        isEs: false, artifactTypes: {StudyArtifactType.visualSummary});
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
