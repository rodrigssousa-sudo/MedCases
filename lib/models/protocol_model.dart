/// ProtocolModel — modelo clínico estruturado MedCases Pro
/// Versão 2.0 — suporta 18 seções clínicas completas
/// Retrocompatível: todos os campos novos são opcionais (nullable)
class ProtocolModel {
  // ── Campos originais (obrigatórios) ─────────────────────────────────────
  final String id;

  // ── Identidade canônica de governança (opcional / retrocompatível) ─────
  /// Família canônica estável; não substitui o ID legado.
  final String? canonicalFamilyId;

  /// Identificador canônico da variante; não substitui o ID legado.
  final String? canonicalProtocolId;
  final Map<String, String> title;
  final Map<String, String> severity;      // nível geral: Crítico / Alto / Moderado
  final Map<String, String> recognize;     // apresentação clínica (legado v1.0; default vazio em v2.0)
  final Map<String, dynamic> actions;      // lista de ações imediatas
  final Map<String, String> avoid;         // o que evitar (texto livre)
  final List<String> drugs;               // IDs de fármacos relacionados (legado)

  // ── Campos novos — estrutura clínica completa ────────────────────────────
  /// 1. Definição concisa da síndrome/condição
  final Map<String, String>? definition;

  /// 2. Classificação por gravidade/subtipos (texto estruturado ou lista)
  final Map<String, dynamic>? classification;

  /// 3. Critérios objetivos de gravidade (scores, valores)
  final Map<String, dynamic>? severityCriteria;

  /// 4. Fisiopatologia resumida
  final Map<String, String>? physiopathology;

  /// 5. Red flags — sinais de alarme imediato
  final Map<String, List<String>>? redFlags;

  /// 6. Diagnóstico diferencial
  final Map<String, List<String>>? differentialDiagnosis;

  /// 7. Exames essenciais com justificativa
  final Map<String, List<String>>? exams;

  /// 8. Objetivos terapêuticos mensuráveis
  final Map<String, List<String>>? objectives;

  /// 9. Fármacos de 1ª linha com dose e contexto
  final Map<String, List<String>>? drugsFirstLine;

  /// 10. Fármacos de 2ª linha / alternativos
  final Map<String, List<String>>? drugsSecondLine;

  /// 11. Fármacos condicionais (uso em cenários específicos)
  final Map<String, List<String>>? drugsConditional;

  /// 12. Fármacos contraindicados com motivo
  final Map<String, List<String>>? drugsContraindicated;

  /// 13. Cenários especiais (populações, comorbidades)
  final Map<String, List<String>>? scenarios;

  /// 14. Monitorização — parâmetros e frequência
  final Map<String, List<String>>? monitoring;

  /// 15. Complicações possíveis
  final Map<String, List<String>>? complications;

  /// 16. O que NÃO fazer (erros comuns)
  final Map<String, List<String>>? doNotDo;

  /// 17. Pérolas clínicas
  final Map<String, List<String>>? pearls;

  /// 18. Referências e diretrizes
  final Map<String, List<String>>? references;

  const ProtocolModel({
    required this.id,
    this.canonicalFamilyId,
    this.canonicalProtocolId,
    required this.title,
    required this.severity,
    this.recognize = const {},   // legado v1.0 — v2.0 usa definition
    required this.actions,
    required this.avoid,
    required this.drugs,
    // Novos campos — todos opcionais
    this.definition,
    this.classification,
    this.severityCriteria,
    this.physiopathology,
    this.redFlags,
    this.differentialDiagnosis,
    this.exams,
    this.objectives,
    this.drugsFirstLine,
    this.drugsSecondLine,
    this.drugsConditional,
    this.drugsContraindicated,
    this.scenarios,
    this.monitoring,
    this.complications,
    this.doNotDo,
    this.pearls,
    this.references,
  });

  // ── Helpers ──────────────────────────────────────────────────────────────
  String getField(Map<String, String> field, String lang) {
    return field[lang] ?? field['pt'] ?? field['es'] ?? '';
  }

  List<String> getActions(String lang) {
    final list = actions[lang] ?? actions['pt'] ?? [];
    if (list is List) return list.cast<String>();
    return [];
  }

  List<String> getList(Map<String, List<String>>? field, String lang) {
    if (field == null) return [];
    return field[lang] ?? field['pt'] ?? field['es'] ?? [];
  }

  String getString(Map<String, String>? field, String lang) {
    if (field == null) return '';
    return field[lang] ?? field['pt'] ?? field['es'] ?? '';
  }

  dynamic getDynamic(Map<String, dynamic>? field, String lang) {
    if (field == null) return null;
    return field[lang] ?? field['pt'] ?? field['es'];
  }

  /// Indica se o protocolo tem estrutura clínica completa (v2.0)
  bool get hasRichContent =>
      definition != null ||
      redFlags != null ||
      drugsFirstLine != null ||
      objectives != null ||
      monitoring != null;
}
