import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_context_chunker.dart';

void main() {
  test('chunker covers a source larger than old 120k ceiling', () {
    final payload = List<String>.generate(
      9000,
      (i) => 'linha_$i dose ${i % 10} mg sem omissão.',
    ).join('\n');

    final accepted = StudySource(
      id: 'source_long',
      type: StudySourceType.text,
      title: 'Fonte longa',
      state: StudySourceState.review,
      createdAtUtc: DateTime.utc(2026, 8, 25),
      text: payload,
    ).transition(StudySourceState.accepted);

    final study = Study(
      id: 'study_long',
      title: 'Long input',
      locale: 'pt-BR',
      createdAtUtc: DateTime.utc(2026, 8, 25),
      sources: <StudySource>[accepted],
    );

    final chunks = StudyContextChunker.build(
      study: study,
      isEs: false,
      maxCharacters: 20000,
    );

    expect(chunks.length, greaterThan(2));
    expect(chunks.every((c) => c.value.length <= 20000), isTrue);

    final all = chunks.map((c) => c.value).join('\n');
    expect(all, contains('linha_0 dose 0 mg'));
    expect(all, contains('linha_4500 dose 0 mg'));
    expect(all, contains('linha_8999 dose 9 mg'));
  });

  test('legacy buildContext refuses overflow instead of truncating', () {
    final payload = List<String>.filled(2000, 'abcdef').join();
    final accepted = StudySource(
      id: 's1',
      type: StudySourceType.text,
      title: 'T',
      state: StudySourceState.review,
      createdAtUtc: DateTime.utc(2026, 8, 25),
      text: payload,
    ).transition(StudySourceState.accepted);

    final study = Study(
      id: 'study',
      title: 'T',
      locale: 'pt-BR',
      createdAtUtc: DateTime.utc(2026, 8, 25),
      sources: <StudySource>[accepted],
    );

    expect(
      () => study.buildContext(isEs: false, maxCharacters: 8000),
      throwsStateError,
    );
  });
}
