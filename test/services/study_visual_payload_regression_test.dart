import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_visual_result_codec.dart';

void main() {
  final source = jsonEncode({
    'title': 'Tema sintético',
    'overview': 'Explicação completa.',
    'sections': [
      {'title': 'Revisão', 'body': 'Conteúdo preservado.'}
    ],
    'keyPoints': ['Ponto completo.'],
    'takeaway': 'Conclusão completa.'
  });
  for (final raw in [
    source,
    '```json\n$source\n```',
    jsonEncode(source),
    'Resultado:\n```json\n$source\n```'
  ]) {
    test('valid wrapped payload decodes ${raw.length}', () {
      final result = StudyVisualResultCodec.decodeVisualSummary(raw);
      expect(result.title, 'Tema sintético');
      expect(result.sections.single.body, 'Conteúdo preservado.');
      expect(result.takeaway, 'Conclusão completa.');
    });
  }
  for (final es in [false, true]) {
    test('truncated JSON is never presented as prose $es', () {
      final result = StudyVisualResultCodec.decodeVisualSummary(
          '{"title":"Tema","overview":"Frase interrompida',
          isEs: es);
      expect(
          result.overview, startsWith(es ? 'No se pudo' : 'Não foi possível'));
      expect(result.overview, isNot(contains('"title"')));
      expect(result.sections, isEmpty);
    });
  }
  test('nested objects are not stringified into clinical text', () {
    final result = StudyVisualResultCodec.decodeVisualSummary(jsonEncode({
      'overview': {'internal': 'debug'},
      'sections': [
        {
          'body': {'raw': 1}
        }
      ]
    }));
    expect(result.overview, isEmpty);
    expect(result.sections, isEmpty);
  });
  test('only complete structured material can be saved as visual output', () {
    expect(StudyVisualResultCodec.isCompleteStructuredSummary(source), isTrue);
    expect(StudyVisualResultCodec.isCompleteStructuredSummary(source.substring(0, source.length - 2)), isFalse);
    expect(StudyVisualResultCodec.isCompleteStructuredSummary('{"title":"Tema"}'), isFalse);
  });
  test('field rejection preserves JSON structure and other visual sections', () {
    final raw = const JsonEncoder.withIndent('  ').convert({
      'title': 'Tema sintético', 'overview': 'Explicação completa.',
      'sections': [
        {'title': 'Restrito', 'body': 'Rejeitar este fragmento.'},
        {'title': 'Preservado', 'body': 'Conteúdo educativo completo.'}
      ]
    });
    final result = StudyVisualResultCodec.validateStructuredText(raw,
        (text) => text.startsWith('Rejeitar') ? '' : text);
    expect(StudyVisualResultCodec.isCompleteStructuredSummary(result), isTrue);
    expect(jsonDecode(result)['sections'][1]['body'], 'Conteúdo educativo completo.');
    expect(result, isNot(contains('Rejeitar')));
  });
  test('structural truncation cannot be repaired by field validation', () {
    expect(() => StudyVisualResultCodec.validateStructuredText(
        '{"title":"Tema",', (value) => value), throwsFormatException);
  });
  test('legacy prose remains available', () {
    final result =
        StudyVisualResultCodec.decodeVisualSummary('Texto educativo completo.');
    expect(result.overview, 'Texto educativo completo.');
  });
}
