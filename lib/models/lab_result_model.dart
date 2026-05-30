// ── lib/models/lab_result_model.dart ─────────────────────────────────────────
// Modelo central para resultados de exames laboratoriais extraídos por OCR/IA.
// Imutável por padrão — use copyWith() para derivar versões modificadas.
// ─────────────────────────────────────────────────────────────────────────────

/// Classificação clínica do resultado em relação ao valor de referência.
enum LabStatus {
  /// Abaixo do limite inferior de referência.
  low,

  /// Dentro da faixa de referência.
  normal,

  /// Acima do limite superior de referência.
  high,

  /// Fora dos limiares de segurança clínica — requer atenção imediata.
  critical,
}

/// Representa um único parâmetro laboratorial extraído de laudo ou imagem.
class LabResult {
  /// Chave normalizada em inglês snake_case (ex: 'sodium', 'potassium').
  /// Usada internamente para cálculos — independe do idioma do usuário.
  final String examKey;

  /// Nome legível no idioma ativo do app (PT: 'Sódio', ES: 'Sodio').
  final String examName;

  /// Valor numérico extraído e convertido para a unidade canônica.
  final double value;

  /// Unidade de medida após conversão (ex: 'mg/dL', 'mEq/L', 'mmol/L').
  final String unit;

  /// Faixa de referência textual do laboratório (opcional, ex: '135–145').
  final String? referenceRange;

  /// Classificação clínica calculada após normalização e conversão.
  final LabStatus status;

  /// Grau de confiança da extração OCR/IA (0.0–1.0).
  /// < 0.70 → campo forçado vazio, exige inserção manual.
  /// 0.70–0.85 → destaque amarelo de revisão.
  /// >= 0.85 → aceito sem destaque.
  final double confidence;

  /// Trecho original capturado no laudo (para auditoria e debug).
  final String originalText;

  const LabResult({
    required this.examKey,
    required this.examName,
    required this.value,
    required this.unit,
    this.referenceRange,
    required this.status,
    required this.confidence,
    required this.originalText,
  });

  // ── Deserialização ────────────────────────────────────────────────────────

  factory LabResult.fromJson(Map<String, dynamic> json) {
    return LabResult(
      examKey:        json['examKey']        as String? ?? '',
      examName:       json['examName']       as String? ?? '',
      value:          _toDouble(json['value']),
      unit:           json['unit']           as String? ?? '',
      referenceRange: json['referenceRange'] as String?,
      status:         _statusFromString(json['status']),
      confidence:     _toDouble(json['confidence']),
      originalText:   json['originalText']   as String? ?? '',
    );
  }

  // ── Serialização ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'examKey':        examKey,
    'examName':       examName,
    'value':          value,
    'unit':           unit,
    'referenceRange': referenceRange,
    'status':         status.name,
    'confidence':     confidence,
    'originalText':   originalText,
  };

  // ── Cópia com campos substituídos ─────────────────────────────────────────

  LabResult copyWith({
    String?    examKey,
    String?    examName,
    double?    value,
    String?    unit,
    String?    referenceRange,
    LabStatus? status,
    double?    confidence,
    String?    originalText,
  }) {
    return LabResult(
      examKey:        examKey        ?? this.examKey,
      examName:       examName       ?? this.examName,
      value:          value          ?? this.value,
      unit:           unit           ?? this.unit,
      referenceRange: referenceRange ?? this.referenceRange,
      status:         status         ?? this.status,
      confidence:     confidence     ?? this.confidence,
      originalText:   originalText   ?? this.originalText,
    );
  }

  // ── Helpers privados ──────────────────────────────────────────────────────

  /// Converte qualquer tipo numérico ou string (com vírgula decimal) para double.
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0.0;
  }

  /// Deserializa o status a partir de uma string (tolerante a maiúsculas).
  static LabStatus _statusFromString(dynamic v) {
    switch (v?.toString().toLowerCase()) {
      case 'low':      return LabStatus.low;
      case 'high':     return LabStatus.high;
      case 'critical': return LabStatus.critical;
      default:         return LabStatus.normal;
    }
  }

  @override
  String toString() =>
      'LabResult(key=$examKey, name=$examName, value=$value $unit, '
      'status=${status.name}, conf=${confidence.toStringAsFixed(2)})';
}
