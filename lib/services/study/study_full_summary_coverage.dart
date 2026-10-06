/// Delivery quality for the complete source-based summary only.
/// This cannot authorize content or bypass clinical safety. It rejects only
/// obvious under-delivery, without requiring filler or a word-count target.
final class StudyFullSummaryCoverage {
  const StudyFullSummaryCoverage._();

  static int words(String content) => RegExp(r'\S+').allMatches(content).length;

  static bool isSufficient({
    required int sourceCharacters,
    required String content,
  }) =>
      content.trim().isNotEmpty &&
      (sourceCharacters < 8000 || words(content) >= 300);

  static bool needsReview({
    required int sourceCharacters,
    required String content,
  }) =>
      !isSufficient(sourceCharacters: sourceCharacters, content: content);
}
