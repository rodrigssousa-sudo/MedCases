import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/study/study_full_summary_coverage.dart';

void main() {
  for (final locale in ['pt', 'es']) {
    test('16 minute source with 54 word draft needs coverage review $locale',
        () {
      final draft = List.filled(54, 'concept').join(' ');
      expect(
          StudyFullSummaryCoverage.needsReview(
              sourceCharacters: 17808, content: draft),
          true);
      expect(
          StudyFullSummaryCoverage.isSufficient(
              sourceCharacters: 17808, content: draft),
          false);
    });
    test('completed coverage is accepted without another review $locale', () {
      final complete = List.filled(676, 'concept').join(' ');
      expect(
          StudyFullSummaryCoverage.isSufficient(
              sourceCharacters: 17808, content: complete),
          true);
      expect(
          StudyFullSummaryCoverage.needsReview(
              sourceCharacters: 17808, content: complete),
          false);
    });
  }
  test('short source does not require invented padding', () {
    expect(
        StudyFullSummaryCoverage.isSufficient(
            sourceCharacters: 467, content: 'A concise explanation.'),
        true);
  });
  test('empty output is never accepted', () {
    expect(
        StudyFullSummaryCoverage.isSufficient(
            sourceCharacters: 467, content: ' '),
        false);
  });
  test('no 18000 character cliff', () {
    for (final size in [8000, 17808, 17999, 18000, 18001]) {
      expect(
          StudyFullSummaryCoverage.needsReview(
              sourceCharacters: size, content: 'Short draft.'),
          true);
    }
  });
}
