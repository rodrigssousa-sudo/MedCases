import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/study_clinical_snapshot.dart';

/// Metadata-only assertion used by canonical finalization/release gates.
/// Safety exemptions must name a canonical quantity ID and a nonempty reason.
class StudyQuantityRetention {
  static String _normalize(String value) => value
      .replaceAll('**', '')
      .replaceAll(RegExp(r'(?<=\d),(?=\d)'), '.')
      .replaceAll('–', '-')
      .replaceAll('−', '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();

  static Map<String, Object?> audit(
      StudyClinicalSnapshot snapshot, String output,
      {Map<String, String> safetyRemovalReasons = const {}}) {
    final expected = <String, int>{};
    for (final q in snapshot.quantities) {
      if (safetyRemovalReasons[q.id]?.trim().isNotEmpty == true) continue;
      final key = _normalize(q.value);
      expected.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
    final normalized = _normalize(output);
    final missing = <String>[];
    for (final entry in expected.entries) {
      // Numeric boundaries stop 5 matching 500 or an embedded scientific symbol.
      final atom = entry.key.split(' ').map(RegExp.escape).join(r'\s*');
      final count =
          RegExp('(?<![0-9.,])$atom(?![0-9])').allMatches(normalized).length;
      for (var i = count; i < entry.value; i++) {
        missing.add(sha256
            .convert(utf8.encode(entry.key.replaceAll(' ', '')))
            .toString());
      }
    }
    return {
      'reasonCode': missing.isEmpty
          ? 'CANONICAL_QUANTITIES_PRESERVED'
          : 'UNEXPLAINED_CANONICAL_QUANTITY_LOSS',
      'expectedQuantityCount': expected.values.fold<int>(0, (a, b) => a + b),
      'missingQuantityCount': missing.length,
      'missingQuantityHashes': missing
    };
  }

  static void requirePreserved(StudyClinicalSnapshot snapshot, String output,
      {Map<String, String> safetyRemovalReasons = const {}}) {
    final result =
        audit(snapshot, output, safetyRemovalReasons: safetyRemovalReasons);
    if (result['missingQuantityCount'] != 0) {
      throw StateError('UNEXPLAINED_CANONICAL_QUANTITY_LOSS');
    }
  }
}
