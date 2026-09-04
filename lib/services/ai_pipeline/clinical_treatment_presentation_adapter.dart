import '../../models/clinical_treatment_presentation.dart';

/// PHASE3I-J2F2: explicit conservative treatment adapter.
///
/// Converts only headings and lines that explicitly declare a supported
/// therapeutic relationship. It does not infer canonical drug identity,
/// calculate doses, promote first/second line, or reinterpret AI free text.
abstract final class ClinicalTreatmentPresentationAdapter {
  static ClinicalTreatmentPresentation fromExplicitText(String text) {
    final normalizedText =
        text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

    if (normalizedText.isEmpty) {
      return ClinicalTreatmentPresentation();
    }

    final items = <ClinicalTreatmentPresentationItem>[];
    final flags = <ClinicalSafetyFlag>[];
    ClinicalTreatmentRelation? activeRelation;
    ClinicalTreatmentRelation? pendingRelation;
    ClinicalSafetyFlagType? activeFlag;
    bool pendingRequiresPharmacologicBoundary = false;
    int pendingNonTreatmentBoundaries = 0;

    for (final rawLine in normalizedText.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final inline = _inlineHeading(trimmed);
      if (inline != null) {
        activeRelation = inline.relation;
        activeFlag = inline.flag;

        if (inline.content.isNotEmpty) {
          if (activeRelation != null) {
            items.add(
              ClinicalTreatmentPresentationItem(
                text: inline.content,
                relation: activeRelation,
              ),
            );
          } else if (activeFlag != null) {
            flags.add(
              ClinicalSafetyFlag(
                text: inline.content,
                type: activeFlag,
              ),
            );
          }
        }
        continue;
      }

      final heading = _headingFor(trimmed);
      if (heading != null) {
        if (heading.relation != null) {
          pendingRelation = heading.relation;
          pendingRequiresPharmacologicBoundary = _isListItem(trimmed);
          pendingNonTreatmentBoundaries = 0;
          activeRelation = null;
          activeFlag = null;
        } else {
          activeRelation = null;
          activeFlag = heading.flag;
          pendingRelation = null;
          pendingRequiresPharmacologicBoundary = false;
          pendingNonTreatmentBoundaries = 0;
        }
        continue;
      }

      if (_isPharmacologicSectionBoundary(trimmed)) {
        activeRelation = pendingRelation;
        activeFlag = null;
        pendingRelation = null;
        pendingRequiresPharmacologicBoundary = false;
        pendingNonTreatmentBoundaries = 0;
        continue;
      }

      if (_isExplicitSectionBoundary(trimmed)) {
        activeRelation = null;
        activeFlag = null;

        if (pendingRelation != null) {
          pendingRequiresPharmacologicBoundary = true;
          pendingNonTreatmentBoundaries += 1;

          if (pendingNonTreatmentBoundaries > 1) {
            pendingRelation = null;
            pendingRequiresPharmacologicBoundary = false;
            pendingNonTreatmentBoundaries = 0;
          }
        }
        continue;
      }

      final content = _cleanContent(trimmed);
      if (content.isEmpty) continue;

      if (pendingRelation != null && !pendingRequiresPharmacologicBoundary) {
        activeRelation = pendingRelation;
        pendingRelation = null;
        pendingNonTreatmentBoundaries = 0;
      }

      if (activeRelation != null) {
        items.add(
          ClinicalTreatmentPresentationItem(
            text: content,
            relation: activeRelation,
          ),
        );
      } else if (activeFlag != null) {
        flags.add(
          ClinicalSafetyFlag(
            text: content,
            type: activeFlag,
          ),
        );
      }
    }

    return ClinicalTreatmentPresentation(
      items: _deduplicateItems(items),
      safetyFlags: _deduplicateFlags(flags),
    );
  }

  static ({
    ClinicalTreatmentRelation? relation,
    ClinicalSafetyFlagType? flag,
    String content,
  })? _inlineHeading(String line) {
    final prepared = line
        .replaceAll(RegExp(r'[*_`#]+'), '')
        .replaceFirst(
          RegExp(r'^[📖🔑📌⚠️🟥🔴💊🔄⛔🚨\-\*•\s]+'),
          '',
        )
        .trim();

    final match = RegExp(
      r'^([^:]{2,80})\s*:\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(prepared);

    if (match == null) return null;

    final heading = _classifyHeading(match.group(1) ?? '');
    if (heading == null) return null;

    return (
      relation: heading.relation,
      flag: heading.flag,
      content: _cleanContent(match.group(2) ?? ''),
    );
  }

  static ({
    ClinicalTreatmentRelation? relation,
    ClinicalSafetyFlagType? flag,
  })? _headingFor(String line) {
    return _classifyHeading(
      line
          .replaceAll(RegExp(r'[*_`#]+'), '')
          .replaceFirst(
            RegExp(r'^[📖🔑📌⚠️🟥🔴💊🔄⛔🚨\-\*•\s]+'),
            '',
          )
          .replaceAll(RegExp(r':\s*$'), '')
          .trim(),
    );
  }

  static ({
    ClinicalTreatmentRelation? relation,
    ClinicalSafetyFlagType? flag,
  })? _classifyHeading(String heading) {
    final value = _normalize(heading);

    if (_matches(value, const <String>[
      'tratamento concomitante',
      'terapia concomitante',
      'tratamento combinado',
      'terapia combinada',
      'tratamento inicial combinado',
      'tratamiento concomitante',
      'terapia concomitante',
      'tratamiento combinado',
      'terapia combinada',
      'tratamiento inicial combinado',
    ])) {
      return (
        relation: ClinicalTreatmentRelation.concomitant,
        flag: null,
      );
    }

    if (_matches(value, const <String>[
      'alternativa',
      'alternativas',
      'alternativa terapeutica',
      'alternativas terapeuticas',
      'opcao alternativa',
      'opcoes alternativas',
      'opcion alternativa',
      'opciones alternativas',
    ])) {
      return (
        relation: ClinicalTreatmentRelation.alternative,
        flag: null,
      );
    }

    if (_matches(value, const <String>[
      'uso condicional',
      'tratamento condicional',
      'medida condicional',
      'medidas condicionais',
      'si esta indicado',
      'si esta indicada',
      'uso condicionado',
      'tratamiento condicional',
      'medida condicional',
      'medidas condicionales',
    ])) {
      return (
        relation: ClinicalTreatmentRelation.conditional,
        flag: null,
      );
    }

    if (_matches(value, const <String>[
      'terapia adjuvante',
      'tratamento adjuvante',
      'medida adjuvante',
      'medidas adjuvantes',
      'terapia coadjuvante',
      'tratamiento adyuvante',
      'terapia adyuvante',
      'medida adyuvante',
      'medidas adyuvantes',
    ])) {
      return (
        relation: ClinicalTreatmentRelation.adjunct,
        flag: null,
      );
    }

    if (_matches(value, const <String>[
      'resgate',
      'terapia de resgate',
      'tratamento de resgate',
      'se refratario',
      'se refrataria',
      'rescate',
      'terapia de rescate',
      'tratamiento de rescate',
      'si es refractario',
      'si es refractaria',
    ])) {
      return (
        relation: ClinicalTreatmentRelation.rescue,
        flag: null,
      );
    }

    if (_matches(value, const <String>[
      'proxima etapa',
      'etapa seguinte',
      'passo seguinte',
      'sequencia terapeutica',
      'etapas sequenciais',
      'siguiente etapa',
      'proximo paso',
      'secuencia terapeutica',
      'pasos secuenciales',
    ])) {
      return (
        relation: ClinicalTreatmentRelation.sequenceStep,
        flag: null,
      );
    }

    if (_matches(value, const <String>[
      'contraindicado',
      'contraindicada',
      'contraindicados',
      'contraindicadas',
      'nao usar',
      'no usar',
      'evitar',
      'contraindicaciones',
      'contraindicacoes',
    ])) {
      return (
        relation: ClinicalTreatmentRelation.contraindicated,
        flag: null,
      );
    }

    if (_matches(value, const <String>[
      'alerta',
      'alerta clinico',
      'alertas',
      'alertas clinicos',
    ])) {
      return (
        relation: null,
        flag: ClinicalSafetyFlagType.alert,
      );
    }

    if (_matches(value, const <String>[
      'hard stop',
      'hard stops',
    ])) {
      return (
        relation: null,
        flag: ClinicalSafetyFlagType.hardStop,
      );
    }

    return null;
  }

  static bool _isListItem(String line) {
    return RegExp(r'^(?:[-•]\s+|\*\s+)').hasMatch(line.trim());
  }

  static bool _isPharmacologicSectionBoundary(String line) {
    if (_isListItem(line)) return false;

    final prepared = line
        .trim()
        .replaceAll(RegExp(r'[*_`#]+'), '')
        .replaceFirst(
          RegExp(r'^[📖🔑📌⚠️🟥🔴💊🔄⛔🚨\s]+'),
          '',
        )
        .replaceAll(RegExp(r':\s*$'), '')
        .trim();

    final value = _normalize(prepared);
    return value == 'tratamento farmacologico' ||
        value == 'tratamiento farmacologico' ||
        value == 'prescricao' ||
        value == 'prescripcion';
  }

  static bool _isExplicitSectionBoundary(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (RegExp(r'^(?:[-•]\s+|\*\s+)').hasMatch(trimmed)) {
      return false;
    }

    final prepared = trimmed
        .replaceAll(RegExp(r'[*_`#]+'), '')
        .replaceFirst(
          RegExp(r'^[📖🔑📌⚠️🟥🔴💊🔄⛔🚨\s]+'),
          '',
        )
        .trim();

    if (prepared.isEmpty || prepared.length > 100) return false;
    return prepared.endsWith(':');
  }

  static bool _matches(String value, List<String> headings) {
    return headings.contains(value);
  }

  static String _cleanContent(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'^[\-\*•]+\s*'), '')
        .replaceAll(RegExp(r'[*_`]+'), '')
        .trim();
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<ClinicalTreatmentPresentationItem> _deduplicateItems(
    List<ClinicalTreatmentPresentationItem> source,
  ) {
    final seen = <String>{};
    final result = <ClinicalTreatmentPresentationItem>[];

    for (final item in source) {
      final identity = '${item.relation.name}|${_normalize(item.text)}';
      if (!seen.add(identity)) continue;
      result.add(item);
    }

    return List<ClinicalTreatmentPresentationItem>.unmodifiable(result);
  }

  static List<ClinicalSafetyFlag> _deduplicateFlags(
    List<ClinicalSafetyFlag> source,
  ) {
    final seen = <String>{};
    final result = <ClinicalSafetyFlag>[];

    for (final flag in source) {
      final identity = '${flag.type.name}|${_normalize(flag.text)}';
      if (!seen.add(identity)) continue;
      result.add(flag);
    }

    return List<ClinicalSafetyFlag>.unmodifiable(result);
  }
}
