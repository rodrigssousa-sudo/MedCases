import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String readGenerator() =>
    File('lib/services/study/study_artifact_generator.dart').readAsStringSync();

String between(String source, String start, String end, String label) {
  final a = source.indexOf(start);
  final b = source.indexOf(end, a + start.length);
  expect(a, greaterThanOrEqualTo(0), reason: '$label start');
  expect(b, greaterThan(a), reason: '$label end');
  return source.substring(a, b);
}

void main() {
  late String source;
  late String maxTokens;
  late String lengthDirective;
  late String hierarchy;

  setUpAll(() {
    source = readGenerator();
    lengthDirective = between(source, 'static String _lengthDirective(',
        'static int _maxTokens(', '_lengthDirective');
    maxTokens = between(source, 'static int _maxTokens(',
        'static String _cleanResult(', '_maxTokens');
    hierarchy = between(
        source,
        'static Future<String> _buildHierarchicalContext(',
        'static int _joinedLength(',
        '_buildHierarchicalContext');
  });

  test('full summary is the longest adaptive Study product', () {
    expect(source, contains('MEDCASES_STUDY_ADAPTIVE_SUMMARY_DEPTH_V1'));
    expect(source, contains('_sourceCharacterCount(study)'));
    for (final token in <String>[
      'return 6500;',
      'return 8000;',
      'return 10000;',
      'return 12000;'
    ]) {
      expect(maxTokens, contains(token), reason: token);
    }
    expect(
        maxTokens,
        isNot(contains(
            'case StudyArtifactType.fullSummary:\n        return 5200;')));
  });

  test('artifact depth decreases from full to exam to visual', () {
    for (final token in <String>[
      'return 4800;',
      'return 5400;',
      'return 6200;',
      'case StudyArtifactType.visualSummary:',
      'return 3200;'
    ]) {
      expect(maxTokens, contains(token), reason: token);
    }
    expect(lengthDirective, contains('produto MAIS COMPLETO'));
    expect(lengthDirective, contains('produto INTERMEDIÁRIO'));
    expect(lengthDirective, contains('produto MAIS CURTO e escaneável'));
  });

  test('long classes preserve coverage without wall prose', () {
    for (final token in <String>[
      '1.400 a 2.400 palavras',
      '2.200 a 3.400 palavras',
      '3.200 a 4.500 palavras',
      '4.500 a 6.000 palavras',
      'NÃO comprima uma aula longa em poucas páginas',
      'Reduza repetição e ruído, NÃO cobertura acadêmica',
      'Mantenha parágrafos curtos'
    ]) {
      expect(lengthDirective, contains(token), reason: token);
    }
    expect(source, contains('MEDCASES_STUDY_FULL_SUMMARY_DIDACTIC_V2'));
  });

  test('full summary hierarchical context preserves more detail', () {
    expect(hierarchy,
        contains('final contextCeiling = isFullSummary ? 120000 : 90000;'));
    expect(hierarchy,
        contains('final mapTokenBudget = isFullSummary ? 5600 : 4200;'));
    expect(hierarchy,
        contains('final reduceTokenBudget = isFullSummary ? 7000 : 5000;'));
    expect(hierarchy, contains('maxTokens: mapTokenBudget'));
    expect(hierarchy, contains('maxTokens: reduceTokenBudget'));
  });

  test('comparison-table didactic V2 remains untouched', () {
    expect(source, contains('MEDCASES_STUDY_COMPARISON_TABLE_DIDACTIC_V2'));
    expect(
        source,
        contains(
            'Crie tabela comparativa Markdown didática, com critério na primeira coluna'));
  });
}
