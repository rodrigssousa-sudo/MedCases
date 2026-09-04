import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai/ai_finalization_transaction.dart';

final class _FakeTimestamp {
  const _FakeTimestamp(this.value);

  final DateTime value;

  DateTime toDate() => value;
}

final class _FakeSecondsTimestamp {
  const _FakeSecondsTimestamp(this.seconds);

  final int seconds;
}

Map<String, dynamic> canonicalMap({
  required Object? updatedAt,
  Object? createdAt,
}) {
  return <String, dynamic>{
    'sessionId': 'session_1770000000000',
    'uid': 'user-1',
    'title': 'Consulta canônica',
    'mode': 'plantao',
    'locale': 'pt',
    'updatedAt': updatedAt,
    if (createdAt != null) 'createdAt': createdAt,
  };
}

Map<String, dynamic> legacyMap({
  Object? updatedAt,
  Object? savedAt,
  Object? createdAt,
}) {
  return <String, dynamic>{
    'id': 'legacy-1',
    'uid': 'user-1',
    'summary': 'Consulta legacy',
    'mode': 'plantao',
    'lang': 'pt',
    if (updatedAt != null) 'updatedAt': updatedAt,
    if (savedAt != null) 'savedAt': savedAt,
    if (createdAt != null) 'createdAt': createdAt,
    'messages': <Map<String, dynamic>>[],
  };
}

void main() {
  group(
    'R18.6W-R4B-R1 — timestamp normalization',
    () {
      test(
        'canonical interpreta String ISO-8601',
        () {
          const iso = '2026-07-23T14:35:27.000Z';

          final summary = AiSessionSummary.fromCanonicalJson(
            canonicalMap(
              updatedAt: iso,
            ),
          );

          expect(
            summary.updatedAt,
            DateTime.parse(iso).millisecondsSinceEpoch,
          );

          expect(
            summary.source,
            AiSessionSource.canonicalV2,
          );
        },
      );

      test(
        'legacy interpreta String ISO-8601',
        () {
          const iso = '2025-11-02T09:10:11.000Z';

          final summary = AiSessionSummary.fromLegacyJson(
            legacyMap(
              updatedAt: iso,
            ),
          );

          expect(
            summary.updatedAt,
            DateTime.parse(iso).millisecondsSinceEpoch,
          );

          expect(
            summary.source,
            AiSessionSource.legacyInline,
          );
        },
      );

      test(
        'epoch em milissegundos é preservado',
        () {
          const epochMilliseconds = 1770000000123;

          final summary = AiSessionSummary.fromCanonicalJson(
            canonicalMap(
              updatedAt: epochMilliseconds,
            ),
          );

          expect(
            summary.updatedAt,
            epochMilliseconds,
          );
        },
      );

      test(
        'epoch em segundos é convertido para milissegundos',
        () {
          const epochSeconds = 1770000000;

          final summary = AiSessionSummary.fromCanonicalJson(
            canonicalMap(
              updatedAt: epochSeconds,
            ),
          );

          expect(
            summary.updatedAt,
            epochSeconds * 1000,
          );
        },
      );

      test(
        'DateTime é convertido para milissegundos',
        () {
          final date = DateTime.utc(
            2026,
            7,
            23,
            12,
            45,
          );

          final summary = AiSessionSummary.fromCanonicalJson(
            canonicalMap(
              updatedAt: date,
            ),
          );

          expect(
            summary.updatedAt,
            date.millisecondsSinceEpoch,
          );
        },
      );

      test(
        'objeto com toDate é interpretado',
        () {
          final date = DateTime.utc(
            2024,
            4,
            5,
            6,
            7,
            8,
          );

          final summary = AiSessionSummary.fromCanonicalJson(
            canonicalMap(
              updatedAt: _FakeTimestamp(date),
            ),
          );

          expect(
            summary.updatedAt,
            date.millisecondsSinceEpoch,
          );
        },
      );

      test(
        'objeto com seconds é interpretado',
        () {
          const seconds = 1760000000;

          final summary = AiSessionSummary.fromCanonicalJson(
            canonicalMap(
              updatedAt: _FakeSecondsTimestamp(seconds),
            ),
          );

          expect(
            summary.updatedAt,
            seconds * 1000,
          );
        },
      );

      test(
        'canonical usa createdAt quando updatedAt é inválido',
        () {
          const createdAt = '2023-08-14T15:16:17.000Z';

          final summary = AiSessionSummary.fromCanonicalJson(
            canonicalMap(
              updatedAt: 'invalid-date',
              createdAt: createdAt,
            ),
          );

          expect(
            summary.updatedAt,
            DateTime.parse(createdAt).millisecondsSinceEpoch,
          );
        },
      );

      test(
        'legacy usa savedAt quando updatedAt está ausente',
        () {
          const savedAt = '2022-02-03T04:05:06.000Z';

          final summary = AiSessionSummary.fromLegacyJson(
            legacyMap(
              savedAt: savedAt,
            ),
          );

          expect(
            summary.updatedAt,
            DateTime.parse(savedAt).millisecondsSinceEpoch,
          );
        },
      );

      test(
        'localMemory interpreta updatedAt ISO',
        () {
          const iso = '2026-01-01T00:00:00.000Z';

          final summary = AiSessionSummary.fromLocalMap(
            <String, dynamic>{
              'sessionId': 'local-1',
              'uid': 'user-1',
              'title': 'Local',
              'mode': 'plantao',
              'locale': 'pt',
              'updatedAt': iso,
            },
          );

          expect(
            summary.updatedAt,
            DateTime.parse(iso).millisecondsSinceEpoch,
          );

          expect(
            summary.source,
            AiSessionSource.localMemory,
          );
        },
      );

      test(
        'valor totalmente inválido nunca produz epoch zero',
        () {
          final before = DateTime.now().millisecondsSinceEpoch;

          final summary = AiSessionSummary.fromCanonicalJson(
            canonicalMap(
              updatedAt: 'not-a-timestamp',
            ),
          );

          final after = DateTime.now().millisecondsSinceEpoch;

          expect(
            summary.updatedAt,
            inInclusiveRange(
              before,
              after,
            ),
          );

          expect(
            summary.updatedAt,
            isNot(0),
          );
        },
      );
    },
  );
}
