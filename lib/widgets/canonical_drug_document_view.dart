import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Presentation only: no secondary clinical values, locale fallback or calculators.
class CanonicalDrugDocumentView extends StatelessWidget {
  const CanonicalDrugDocumentView(
      {super.key, required this.document, required this.language});
  final Map<String, Object?> document;
  final String language;
  static const groups = <(String, String, List<String>)>[
    (
      'Apresentação',
      'Presentación',
      ['presentation', 'presentations', 'commercialNames']
    ),
    ('Posologia', 'Posología', ['dose', 'doseKg', 'indicationDosing']),
    (
      'Preparo e administração',
      'Preparación y administración',
      ['preparation', 'administration', 'infusionProtocol']
    ),
    (
      'Alertas e monitoramento',
      'Alertas y monitorización',
      [
        'alerts',
        'safetyFlags',
        'contraindications',
        'monitoring',
        'monitoramento',
        'therapeuticMonitoring',
        'therapeuticTargets',
        'neurotoxicityWarning',
        'qtRisk',
        'extravasationProtocol',
        'prescriptionErrors',
        'risksByPatient',
        'overdose',
        'hemodynamicRules',
        'electrolyteSafety',
        'sickDayRules'
      ]
    ),
    ('Ajuste renal', 'Ajuste renal', ['renalDose', 'renalReplacementTherapy']),
    ('Ajuste hepático', 'Ajuste hepático', ['hepaticDose']),
    (
      'Populações especiais',
      'Poblaciones especiales',
      ['specialPopulations', 'pediatricDose', 'pregnancy', 'lactation']
    ),
    ('Interações', 'Interacciones', ['interactions', 'combinationRule']),
    (
      'Efeitos adversos',
      'Efectos adversos',
      [
        'commonAdverseEffects',
        'dangerousAdverseEffects',
        'adverseEffects',
        'efeitosAdversos'
      ]
    ),
    (
      'Farmacologia',
      'Farmacología',
      [
        'indications',
        'indicacoes',
        'mechanism',
        'pharmacodynamics',
        'pharmacokinetics',
        'pharmacology',
        'clinicalPearls',
        'patientEducation',
        'guidelineRecommendations'
      ]
    ),
    ('Referências', 'Referencias', ['references', 'ref', 'refs']),
  ];
  // UI labels only; all clinical values remain verbatim from the locale document.
  static const labels = <String, (String, String)>{
    "standard": ("Padrão", "Estándar"),
    "severe": ("Grave", "Grave"),
    "maxDose": ("Dose máxima", "Dosis máxima"),
    "standardEV": ("Via intravenosa", "Vía intravenosa"),
    "standardVO": ("Via oral", "Vía oral"),
    "adulto": ("Adultos", "Adultos"),
    "adultoEVKg": (
      "Adultos — intravenoso por peso",
      "Adultos — intravenoso por peso"
    ),
    "adultoEV_kg": (
      "Adultos — intravenoso por peso",
      "Adultos — intravenoso por peso"
    ),
    "adultoEstendida": (
      "Adultos — esquema estendido",
      "Adultos — pauta extendida"
    ),
    "pediatric": ("Pediatria", "Pediatría"),
    "pediatrica": ("Pediatria", "Pediatría"),
    "neonato": ("Neonatos", "Neonatos"),
    "doseMaxima": ("Dose máxima", "Dosis máxima"),
    "padrao": ("Padrão", "Estándar"),
    "grave": ("Grave", "Grave"),
    "alta": ("Alta", "Alta"),
    "esquema3Dias": ("Esquema de 3 dias", "Pauta de 3 días"),
    "esquema5Dias": ("Esquema de 5 dias", "Pauta de 5 días"),
    "monitoring": ("Monitoramento", "Monitorización"),
    "management": ("Conduta", "Conducta"),
    "contraindications": ("Contraindicações", "Contraindicaciones"),
    "required": ("Necessário", "Necesario"),
    "target": ("Alvo", "Objetivo"),
    "risk": ("Risco", "Riesgo"),
    "symptoms": ("Sintomas", "Síntomas"),
    "signs": ("Sinais", "Signos"),
    "notes": ("Notas", "Notas"),
    "obs": ("Observações", "Observaciones"),
    "warning": ("Alerta", "Alerta"),
    "prophylaxis": ("Profilaxia", "Profilaxis"),
    "profilaxia": ("Profilaxia", "Profilaxis"),
    "profilaxiaPediatrica": ("Profilaxia pediátrica", "Profilaxis pediátrica"),
    "synergy": ("Sinergia", "Sinergia"),
    "endocardite": ("Endocardite", "Endocarditis"),
    "meningite": ("Meningite", "Meningitis"),
    "meningitis": ("Meningite", "Meningitis"),
    "helicobacter": ("Helicobacter", "Helicobacter"),
    "mac": ("MAC", "MAC"),
    "tuberculosis": ("Tuberculose", "Tuberculosis"),
    "uti": ("UTI", "UTI"),
    "cvvh": ("CVVH", "CVVH"),
    "dialysePeritoneal": ("Diálise peritoneal", "Diálisis peritoneal"),
    "removido": ("Remoção", "Eliminación"),
    "holdIf": ("Condições para suspensão", "Condiciones de suspensión"),
    "systolicBPBelow": (
      "Pressão sistólica inferior a",
      "Presión sistólica inferior a"
    ),
    "severeDehydration": ("Desidratação grave", "Deshidratación grave"),
    "activeKetoacidosis": ("Cetoacidose ativa", "Cetoacidosis activa"),
    "severeAcuteIllness": ("Doença aguda grave", "Enfermedad aguda grave"),
    "perioperativeFasting": ("Jejum perioperatório", "Ayuno perioperatorio"),
    "potassiumRisk": (
      "Risco relacionado ao potássio",
      "Riesgo relacionado con potasio"
    ),
    "magnesiumRisk": (
      "Risco relacionado ao magnésio",
      "Riesgo relacionado con magnesio"
    ),
    "sodiumRisk": (
      "Risco relacionado ao sódio",
      "Riesgo relacionado con sodio"
    ),
  };
  String _label(Object? key) {
    final label = labels[key];
    return label == null
        ? key.toString()
        : (language == 'es' ? label.$2 : label.$1);
  }

  static bool hasContent(Object? value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is List) return value.any(hasContent);
    if (value is Map) return value.values.any(hasContent);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final raw = document[language];
    if (raw is! Map) return const SizedBox.shrink();
    final locale = Map<String, Object?>.from(raw);
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((locale['name'] ?? '').toString(),
                style: theme.textTheme.headlineSmall),
            for (final key in ['class', 'pharmacologicClass'])
              if (hasContent(locale[key]))
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(locale[key].toString(),
                        style: theme.textTheme.bodyMedium)),
          ])),
      for (final group in groups)
        if (group.$3.any((key) => hasContent(locale[key])))
          Card(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded:
                    group.$3.contains('dose') || group.$3.contains('alerts'),
                title: Text(language == 'es' ? group.$2 : group.$1,
                    style: theme.textTheme.titleMedium),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedAlignment: Alignment.centerLeft,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final key in group.$3)
                    if (hasContent(locale[key]))
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _value(context, locale[key]))
                ],
              )),
    ]);
  }

  Widget _value(BuildContext context, Object? value) {
    if (value is List)
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final item in value)
          if (hasContent(item))
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _value(context, item)),
      ]);
    if (value is Map) {
      // Language-keyed source values are selected, never translated or merged.
      if (value.containsKey('pt') || value.containsKey('es'))
        return _value(context, value[language]);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in value.entries)
          if (hasContent(e.value))
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.key != 'items' && e.key != 'title')
                        Text(_label(e.key),
                            style: Theme.of(context).textTheme.labelLarge),
                      _value(context, e.value),
                    ])),
      ]);
    }
    if (!hasContent(value)) return const SizedBox.shrink();
    return MarkdownBody(
        data: value is bool
            ? (value
                ? (language == 'es' ? 'Sí' : 'Sim')
                : (language == 'es' ? 'No' : 'Não'))
            : value.toString(),
        selectable: true,
        shrinkWrap: true);
  }
}
