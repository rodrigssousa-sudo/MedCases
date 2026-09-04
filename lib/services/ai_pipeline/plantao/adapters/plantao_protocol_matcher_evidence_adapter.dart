import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../models/protocol_model.dart';
import '../contracts/plantao_evidence_bundle.dart';

/// Materializes the protocol models already selected by the productive matcher
/// as canonical Plantao evidence items.
///
/// This adapter does not retrieve, rank, match, reorder, or reinterpret
/// protocols. It is intentionally disconnected from AppProvider and AiService.
final class PlantaoProtocolMatcherEvidenceAdapter {
  const PlantaoProtocolMatcherEvidenceAdapter._();

  static const String evidenceKind = 'protocol';
  static const int boundedExcerptMaxRunes = 556;
  static const List<String> supportedLocales = <String>['pt', 'es'];

  static PlantaoEvidenceItem toEvidenceItem({
    required ProtocolModel protocol,
    required String locale,
  }) {
    final canonicalProjection = _canonicalProtocolProjection(protocol);
    final contentHash = sha256
        .convert(utf8.encode(canonicalProjection))
        .toString();
    final boundedExcerpt = _buildBoundedExcerpt(
      protocol: protocol,
      locale: locale,
    );

    return PlantaoEvidenceItem(
      kind: evidenceKind,
      sourceId: protocol.id,
      sourceVersion: contentHash,
      documentId: protocol.id,
      contentHash: contentHash,
      boundedExcerpt: boundedExcerpt,
    );
  }

  static List<PlantaoEvidenceItem> toEvidenceItems({
    required Iterable<ProtocolModel> protocols,
    required String locale,
  }) {
    return List<PlantaoEvidenceItem>.unmodifiable(
      protocols.map(
        (protocol) => toEvidenceItem(
          protocol: protocol,
          locale: locale,
        ),
      ),
    );
  }

  static String _buildBoundedExcerpt({
    required ProtocolModel protocol,
    required String locale,
  }) {
    final requestedLocale = _normalizeLocale(locale);
    final title = _localizedText(protocol.title, requestedLocale);
    final clinicalUnit = <Object?>[
      protocol.definition,
      protocol.recognize,
      protocol.actions,
      protocol.redFlags,
      protocol.objectives,
      protocol.pearls,
    ]
        .map((value) => _localizedText(value, requestedLocale))
        .firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );

    final projection = PlantaoEvidenceBundle.normalizeCanonicalText(
      clinicalUnit.isEmpty ? title : '$title — $clinicalUnit',
    );

    if (projection.runes.length <= boundedExcerptMaxRunes) {
      return projection;
    }

    return String.fromCharCodes(
      projection.runes.take(boundedExcerptMaxRunes),
    ).trimRight();
  }

  static String _localizedText(Object? value, String locale) {
    if (value == null) {
      return '';
    }

    if (value is String) {
      return PlantaoEvidenceBundle.normalizeCanonicalText(value);
    }

    if (value is Map) {
      final normalizedEntries = value.entries
          .map(
            (entry) => MapEntry<String, Object?>(
              entry.key.toString().toLowerCase(),
              entry.value,
            ),
          )
          .toList(growable: false);
      final byKey = <String, Object?>{
        for (final entry in normalizedEntries) entry.key: entry.value,
      };

      for (final candidate in <String>[locale, 'pt', 'es']) {
        if (!byKey.containsKey(candidate)) {
          continue;
        }
        final localized = _flattenText(byKey[candidate]);
        if (localized.isNotEmpty) {
          return localized;
        }
      }

      final orderedEntries = normalizedEntries.toList(growable: false)
        ..sort((left, right) => left.key.compareTo(right.key));
      for (final entry in orderedEntries) {
        final localized = _flattenText(entry.value);
        if (localized.isNotEmpty) {
          return localized;
        }
      }
      return '';
    }

    return _flattenText(value);
  }

  static String _flattenText(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return PlantaoEvidenceBundle.normalizeCanonicalText(value);
    }
    if (value is Iterable) {
      return PlantaoEvidenceBundle.normalizeCanonicalText(
        value
            .map(_flattenText)
            .where((part) => part.isNotEmpty)
            .join(' · '),
      );
    }
    if (value is Map) {
      final entries = value.entries.toList(growable: false)
        ..sort(
          (left, right) =>
              left.key.toString().compareTo(right.key.toString()),
        );
      return PlantaoEvidenceBundle.normalizeCanonicalText(
        entries
            .map((entry) => _flattenText(entry.value))
            .where((part) => part.isNotEmpty)
            .join(' · '),
      );
    }
    return PlantaoEvidenceBundle.normalizeCanonicalText(value.toString());
  }

  static String _canonicalProtocolProjection(ProtocolModel protocol) {
    return _canonicalValue(<String, Object?>{
      'id': protocol.id,
      'title': protocol.title,
      'severity': protocol.severity,
      'recognize': protocol.recognize,
      'actions': protocol.actions,
      'avoid': protocol.avoid,
      'drugs': protocol.drugs,
      'definition': protocol.definition,
      'classification': protocol.classification,
      'severityCriteria': protocol.severityCriteria,
      'physiopathology': protocol.physiopathology,
      'redFlags': protocol.redFlags,
      'differentialDiagnosis': protocol.differentialDiagnosis,
      'exams': protocol.exams,
      'objectives': protocol.objectives,
      'drugsFirstLine': protocol.drugsFirstLine,
      'drugsSecondLine': protocol.drugsSecondLine,
      'drugsConditional': protocol.drugsConditional,
      'drugsContraindicated': protocol.drugsContraindicated,
      'scenarios': protocol.scenarios,
      'monitoring': protocol.monitoring,
      'complications': protocol.complications,
      'doNotDo': protocol.doNotDo,
      'pearls': protocol.pearls,
      'references': protocol.references,
    });
  }

  static String _canonicalValue(Object? value) {
    if (value == null) {
      return 'null';
    }
    if (value is String) {
      return jsonEncode(
        PlantaoEvidenceBundle.normalizeCanonicalText(value),
      );
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    if (value is Iterable) {
      return '[${value.map(_canonicalValue).join(',')}]';
    }
    if (value is Map) {
      final entries = value.entries
          .map(
            (entry) => MapEntry<String, Object?>(
              PlantaoEvidenceBundle.normalizeCanonicalText(
                entry.key.toString(),
              ),
              entry.value,
            ),
          )
          .toList(growable: false)
        ..sort((left, right) => left.key.compareTo(right.key));
      return '{${entries.map((entry) {
        return '${jsonEncode(entry.key)}:${_canonicalValue(entry.value)}';
      }).join(',')}}';
    }
    return jsonEncode(
      PlantaoEvidenceBundle.normalizeCanonicalText(value.toString()),
    );
  }

  static String _normalizeLocale(String locale) {
    final normalized = locale.trim().toLowerCase().replaceAll('_', '-');
    final language = normalized.split('-').first;
    if (supportedLocales.contains(language)) {
      return language;
    }
    return 'pt';
  }
}
