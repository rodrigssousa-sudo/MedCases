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
  final List<ClinicalPrescriptionItem> prescricao;

  ClinicalStructuredOutput({
    required this.diagnosticoHeuristico,
    required this.condutaImediata,
    required List<ClinicalPrescriptionItem> prescricao,
  }) : prescricao = List<ClinicalPrescriptionItem>.unmodifiable(prescricao);

  /// Converte um mapa já validado pelo backend para o modelo tipado.
  ///
  /// Lança [FormatException] quando o payload local não respeita o contrato.
  factory ClinicalStructuredOutput.fromJson(Map<String, dynamic> json) {
    const expectedKeys = <String>{
      'diagnosticoHeuristico',
      'condutaImediata',
      'prescricao',
    };

    if (json.keys.toSet().difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'clinical_structured_output_invalid_keys',
      );
    }

    final diagnostico = json['diagnosticoHeuristico'];
    final conduta = json['condutaImediata'];
    final rawPrescricao = json['prescricao'];

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

    if (rawPrescricao is! List) {
      throw const FormatException(
        'clinical_structured_output_invalid_prescricao',
      );
    }

    final items = <ClinicalPrescriptionItem>[];

    for (var index = 0; index < rawPrescricao.length; index++) {
      final rawItem = rawPrescricao[index];

      if (rawItem is! Map) {
        throw FormatException(
          'clinical_structured_output_invalid_prescricao_item:$index',
        );
      }

      items.add(
        ClinicalPrescriptionItem.fromJson(
          Map<String, dynamic>.from(rawItem),
        ),
      );
    }

    return ClinicalStructuredOutput(
      diagnosticoHeuristico: diagnostico,
      condutaImediata: conduta,
      prescricao: items,
    );
  }

  /// Parser tolerante para fronteiras de rede, cache e migração.
  ///
  /// Retorna null para:
  /// - `structuredOutput: null`;
  /// - tipo inválido;
  /// - campos ausentes;
  /// - conteúdo vazio;
  /// - chaves extras;
  /// - prescrição malformada.
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'diagnosticoHeuristico': diagnosticoHeuristico,
        'condutaImediata': condutaImediata,
        'prescricao':
            prescricao.map((item) => item.toJson()).toList(growable: false),
      };
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
