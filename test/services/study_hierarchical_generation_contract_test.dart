import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('artifact generator uses hierarchical context owner', () {
    final source = File(
      'lib/services/study/study_artifact_generator.dart',
    ).readAsStringSync();
    final model =
        File('lib/models/study_workspace_model.dart').readAsStringSync();

    expect(source, contains('StudyContextChunker.build('));
    expect(source, contains('_buildHierarchicalContext('));
    expect(source, contains('study_hierarchical_map_failed'));
    expect(source, contains('study_hierarchical_reduce_failed'));
    expect(
      source,
      isNot(contains('final context = study.buildContext(isEs: isEs);')),
    );
    expect(model, isNot(contains('substring(0, maxCharacters)')));
    expect(model, contains('study_context_requires_hierarchical_generation'));
  });
}
