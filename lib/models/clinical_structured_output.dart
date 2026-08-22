import 'clinical_treatment_presentation.dart';

/// Payload clínico estruturado validado pelo backend MedCases.
///
/// Espelha exatamente `structuredOutput` do contrato SSE:
/// {
///   "diagnosticoHeuristico": "...",
///   "condutaImediata": "...",
///   "prescricao": [
///     {"farmaco": "...", "posologia": "..."}
///   ]
/// }
///
/// O envelope completo pode enviar `structuredOutput: null`. Nesse caso,
/// [ClinicalStructuredOutput.tryFromJson] retorna null.
final class ClinicalStructuredOutput {
  final String diagnosticoHeuristico;
  final String condutaImediata;

  /// Lista agregada legada para payloads anteriores e respostas sem prioridade.
  final List<ClinicalPrescriptionItem> prescricao;

  final List<String> condutaImediataItens;
  final List<ClinicalPrescriptionItem> primeiraLinha;
  final List<ClinicalPrescriptionItem> segundaLinha;
  final List<String> pontosChave;
  final List<String> hardStops;

  /// PHASE3I-J2F3: productive DTO treatment presentation binding.
  final ClinicalTreatmentPresentation treatmentPresentation;

  ClinicalStructuredOutput({
    required this.diagnosticoHeuristico,
    required this.condutaImediata,
    required List<ClinicalPrescriptionItem> prescricao,
    List<String> condutaImediataItens = const <String>[],
    List<ClinicalPrescriptionItem> primeiraLinha =
        const <ClinicalPrescriptionItem>[],
    List<ClinicalPrescriptionItem> segundaLinha =
        const <ClinicalPrescriptionItem>[],
    List<String> pontosChave = const <String>[],
    List<String> hardStops = const <String>[],
    ClinicalTreatmentPresentation? treatmentPresentation,
  })  : prescricao = List<ClinicalPrescriptionItem>.unmodifiable(prescricao),
        condutaImediataItens = List<String>.unmodifiable(condutaImediataItens),
        primeiraLinha =
            List<ClinicalPrescriptionItem>.unmodifiable(primeiraLinha),
        segundaLinha =
            List<ClinicalPrescriptionItem>.unmodifiable(segundaLinha),
        pontosChave = List<String>.unmodifiable(pontosChave),
        hardStops = List<String>.unmodifiable(hardStops),
        treatmentPresentation =
            treatmentPresentation ?? ClinicalTreatmentPresentation();

  /// As três chaves históricas continuam obrigatórias.
  /// As cinco seções novas são opcionais para preservar payloads antigos.
  factory ClinicalStructuredOutput.fromJson(Map<String, dynamic> json) {
    const requiredKeys = <String>{
      'diagnosticoHeuristico',
      'condutaImediata',
      'prescricao',
    };
    const optionalKeys = <String>{
      'condutaImediataItens',
      'primeiraLinha',
      'segundaLinha',
      'pontosChave',
      'hardStops',
      'treatmentPresentation',
    };
    const allowedKeys = <String>{
      ...requiredKeys,
      ...optionalKeys,
    };

    final actualKeys = json.keys.toSet();

    if (actualKeys.difference(allowedKeys).isNotEmpty ||
        requiredKeys.difference(actualKeys).isNotEmpty) {
      throw const FormatException(
        'clinical_structured_output_invalid_keys',
      );
    }

    final diagnostico = json['diagnosticoHeuristico'];
    final conduta = json['condutaImediata'];

    if (diagnostico is! String || diagnostico.trim().isEmpty) {
      throw const FormatException(
        'clinical_structured_output_invalid_diagnostico',
      );
    }

    if (conduta is! String || conduta.trim().isEmpty) {
      throw const FormatException(
        'clinical_structured_output_invalid_conduta',
      );
    }

    return ClinicalStructuredOutput(
      diagnosticoHeuristico: diagnostico,
      condutaImediata: conduta,
      prescricao: _parsePrescriptionList(
        json['prescricao'],
        field: 'prescricao',
        isRequired: true,
      ),
      condutaImediataItens: _parseStringList(
        json['condutaImediataItens'],
        field: 'condutaImediataItens',
      ),
      primeiraLinha: _parsePrescriptionList(
        json['primeiraLinha'],
        field: 'primeiraLinha',
      ),
      segundaLinha: _parsePrescriptionList(
        json['segundaLinha'],
        field: 'segundaLinha',
      ),
      pontosChave: _parseStringList(
        json['pontosChave'],
        field: 'pontosChave',
      ),
      hardStops: _parseStringList(
        json['hardStops'],
        field: 'hardStops',
      ),
      treatmentPresentation: _parseTreatmentPresentation(
        json['treatmentPresentation'],
      ),
    );
  }

  static List<ClinicalPrescriptionItem> _parsePrescriptionList(
    Object? raw, {
    required String field,
    bool isRequired = false,
  }) {
    if (raw == null && !isRequired) {
      return const <ClinicalPrescriptionItem>[];
    }

    if (raw is! List) {
      throw FormatException(
        'clinical_structured_output_invalid_$field',
      );
    }

    final items = <ClinicalPrescriptionItem>[];

    for (var index = 0; index < raw.length; index++) {
      final rawItem = raw[index];

      if (rawItem is! Map) {
        throw FormatException(
          'clinical_structured_output_invalid_${field}_item:$index',
        );
      }

      items.add(
        ClinicalPrescriptionItem.fromJson(
          Map<String, dynamic>.from(rawItem),
        ),
      );
    }

    return items;
  }

  static List<String> _parseStringList(
    Object? raw, {
    required String field,
  }) {
    if (raw == null) return const <String>[];

    if (raw is! List) {
      throw FormatException(
        'clinical_structured_output_invalid_$field',
      );
    }

    final items = <String>[];

    for (var index = 0; index < raw.length; index++) {
      final rawItem = raw[index];

      if (rawItem is! String || rawItem.trim().isEmpty) {
        throw FormatException(
          'clinical_structured_output_invalid_${field}_item:$index',
        );
      }

      items.add(rawItem.trim());
    }

    return items;
  }

  static ClinicalTreatmentPresentation _parseTreatmentPresentation(
    Object? raw,
  ) {
    if (raw == null) return ClinicalTreatmentPresentation();
    if (raw is! Map) {
      throw const FormatException(
        'clinical_structured_output_invalid_treatment_presentation',
      );
    }
    return ClinicalTreatmentPresentation.fromJson(
      Map<String, Object?>.from(raw),
    );
  }

  static ClinicalStructuredOutput? tryFromJson(Object? raw) {
    if (raw == null || raw is! Map) return null;

    try {
      return ClinicalStructuredOutput.fromJson(
        Map<String, dynamic>.from(raw),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'diagnosticoHeuristico': diagnosticoHeuristico,
      'condutaImediata': condutaImediata,
      'prescricao':
          prescricao.map((item) => item.toJson()).toList(growable: false),
    };

    if (condutaImediataItens.isNotEmpty) {
      json['condutaImediataItens'] =
          condutaImediataItens.toList(growable: false);
    }
    if (primeiraLinha.isNotEmpty) {
      json['primeiraLinha'] =
          primeiraLinha.map((item) => item.toJson()).toList(growable: false);
    }
    if (segundaLinha.isNotEmpty) {
      json['segundaLinha'] =
          segundaLinha.map((item) => item.toJson()).toList(growable: false);
    }
    if (pontosChave.isNotEmpty) {
      json['pontosChave'] = pontosChave.toList(growable: false);
    }
    if (hardStops.isNotEmpty) {
      json['hardStops'] = hardStops.toList(growable: false);
    }
    if (!treatmentPresentation.isEmpty) {
      json['treatmentPresentation'] = treatmentPresentation.toJson();
    }

    return json;
  }
}

/// Item individual da prescrição estruturada.
final class ClinicalPrescriptionItem {
  final String farmaco;
  final String posologia;

  const ClinicalPrescriptionItem({
    required this.farmaco,
    required this.posologia,
  });

  factory ClinicalPrescriptionItem.fromJson(
    Map<String, dynamic> json,
  ) {
    const expectedKeys = <String>{
      'farmaco',
      'posologia',
    };

    if (json.keys.toSet().difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'clinical_prescription_item_invalid_keys',
      );
    }

    final farmaco = json['farmaco'];
    final posologia = json['posologia'];

    if (farmaco is! String || farmaco.trim().isEmpty) {
      throw const FormatException(
        'clinical_prescription_item_invalid_farmaco',
      );
    }

    if (posologia is! String || posologia.trim().isEmpty) {
      throw const FormatException(
        'clinical_prescription_item_invalid_posologia',
      );
    }

    return ClinicalPrescriptionItem(
      farmaco: farmaco,
      posologia: posologia,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'farmaco': farmaco,
        'posologia': posologia,
      };
}
