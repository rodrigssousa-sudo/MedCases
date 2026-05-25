import 'package:flutter/material.dart';

class DrugModel {
  final String id;
  final String name;
  final String group;          // Categoría principal (ES nativo)
  final Map<String, String> className;
  final Map<String, String> category;
  final String route;
  final String doseType;
  final Map<String, String>? fixedDose;
  final Map<String, String>? frequency;
  final double? mgKg;
  final double? mcgKgMinStart;
  final double? mcgKgMinMax;
  final Map<String, String>? renalAlert;
  final Map<String, String>? elderlyAlert;
  final Map<String, String>? mechanism;
  final Map<String, String>? warning;
  final Map<String, dynamic>? adverse;
  /// Interações medicamentosas agrupadas por severidade.
  /// Chaves esperadas: 'graves', 'moderadas', 'leves'.
  /// Valores: lista de IDs de fármacos (String).
  final Map<String, List<String>>? interactions;

  const DrugModel({
    required this.id,
    required this.name,
    required this.group,
    required this.className,
    required this.category,
    required this.route,
    required this.doseType,
    this.fixedDose,
    this.frequency,
    this.mgKg,
    this.mcgKgMinStart,
    this.mcgKgMinMax,
    this.renalAlert,
    this.elderlyAlert,
    this.mechanism,
    this.warning,
    this.adverse,
    this.interactions,
  });

  String getField(Map<String, String>? field, String lang) {
    if (field == null) return '';
    return field[lang] ?? field['es'] ?? field['pt'] ?? '';
  }

  List<String> getAdverse(String lang) {
    if (adverse == null) return [];
    final list = adverse![lang] ?? adverse!['es'] ?? adverse!['pt'] ?? [];
    if (list is List) return list.cast<String>();
    return [];
  }
}

// Categorías principales del sistema
class DrugGroup {
  static const String analgesicos        = 'Analgésicos y Antipiréticos';
  static const String cardiovascular     = 'Cardiovascular y HTA';
  static const String antibioticos       = 'Antibióticos';
  static const String anticoagulantes    = 'Anticoagulantes y Hemostasia';
  static const String respiratorio       = 'Respiratorio';
  static const String neurologia         = 'Neurología y Psiquiatría';
  static const String gastro             = 'Gastroenterología';
  static const String endocrino          = 'Endocrinología y Metabolismo';
  static const String infecto            = 'Infectología (Antifúngicos / Antivirales / TBC)';
  static const String criticos           = 'UCI – Críticos y Sedoanalgesia';
  static const String hemato             = 'Hematología y Vitaminas';
  static const String varios             = 'Varios / Antídotos / Otros';

  static const List<String> all = [
    cardiovascular,
    criticos,
    analgesicos,
    antibioticos,
    infecto,
    anticoagulantes,
    respiratorio,
    neurologia,
    gastro,
    endocrino,
    hemato,
    varios,
  ];

  // Retorna IconData para uso com Icon() widget — sem emoji
  static IconData iconData(String group) {
    switch (group) {
      case cardiovascular:  return Icons.favorite_outline_rounded;
      case criticos:        return Icons.monitor_heart_outlined;
      case analgesicos:     return Icons.medical_services_outlined;
      case antibioticos:    return Icons.biotech_outlined;
      case infecto:         return Icons.science_outlined;
      case anticoagulantes: return Icons.water_drop_outlined;
      case respiratorio:    return Icons.air_rounded;
      case neurologia:      return Icons.psychology_outlined;
      case gastro:          return Icons.local_hospital_outlined;
      case endocrino:       return Icons.balance_outlined;
      case hemato:          return Icons.bloodtype_outlined;
      case varios:          return Icons.category_outlined;
      default:              return Icons.medication_outlined;
    }
  }

  // Mantido para compatibilidade legada — retorna string vazia (sem emoji)
  static String icon(String group) => '';

  // ── Rótulo bilíngue do grupo ───────────────────────────────────────────────
  // Grupos usam ES como idioma-base nos dados.
  // Este método retorna a tradução PT quando isEs=false.
  static String label(String group, {bool isEs = true}) {
    if (isEs) return group;
    const Map<String, String> groupPt = {
      'Cardiovascular y HTA':                              'Cardiovascular e HAS',
      'UCI – Críticos y Sedoanalgesia':                    'UTI – Críticos e Sedoanalgesia',
      'Analgésicos y Antipiréticos':                       'Analgésicos e Antipiréticos',
      'Antibióticos':                                      'Antibióticos',
      'Infectología (Antifúngicos / Antivirales / TBC)':   'Infectologia (Antifúngicos / Antivirais / TBC)',
      'Anticoagulantes y Hemostasia':                      'Anticoagulantes e Hemostasia',
      'Respiratorio':                                      'Respiratório',
      'Neurología y Psiquiatría':                          'Neurologia e Psiquiatria',
      'Gastroenterología':                                 'Gastroenterologia',
      'Endocrinología y Metabolismo':                      'Endocrinologia e Metabolismo',
      'Hematología y Vitaminas':                           'Hematologia e Vitaminas',
      'Varios / Antídotos / Otros':                        'Vários / Antídotos / Outros',
      // Grupos secundários também presentes nos dados
      'Cardiologia':                                       'Cardiologia',
      'Neurologia':                                        'Neurologia',
      'Reumatologia':                                      'Reumatologia',
      'Imunológicos':                                      'Imunológicos',
      'Imunossupressores':                                 'Imunossupressores',
      'Imunobiológicos / Anti-TNF':                        'Imunobiológicos / Anti-TNF',
      'Corticosteroides':                                  'Corticosteroides',
      'Diuréticos':                                        'Diuréticos',
      'Dislipidemias':                                     'Dislipidemias',
      'Hematológicos':                                     'Hematológicos',
      'Hemoderivados':                                     'Hemoderivados',
      'Antiepilépticos EV':                                'Antiepilépticos EV',
      'Anti-hipertensivos EV / Vasodilatadores':           'Anti-hipertensivos EV / Vasodilatadores',
      'Anti-hipertensivos EV / Bloqueadores de canal de Ca': 'Anti-hipertensivos EV / Bloqueadores de canal de Ca',
      'Anti-hipertensivos EV / Dopaminérgicos':            'Anti-hipertensivos EV / Dopaminérgicos',
      'Betabloqueadores EV':                               'Betabloqueadores EV',
      'Betabloqueadores EV / Anti-hipertensivos':          'Betabloqueadores EV / Anti-hipertensivos',
      'Antifibrinolíticos':                                'Antifibrinolíticos',
      'Antifúngicos':                                      'Antifúngicos',
      'Antiparasitários':                                  'Antiparasitários',
      'Antídotos / Miorrelaxantes':                        'Antídotos / Miorrelaxantes',
      'Antídotos / Reversion ACOD':                        'Antídotos / Reversão ACOD',
      'Antialérgicos / Angioedema':                        'Antialérgicos / Angioedema',
      'Anestesia General':                                 'Anestesia Geral',
      'Alzheimer y Demencias':                             'Alzheimer e Demências',
      'Glándula Tiroides':                                 'Glândula Tireoide',
      'Hígado / Páncreas / Vías Biliares':                 'Fígado / Pâncreas / Vias Biliares',
      'Gastroprocinéticos / Opioides':                     'Gastroprocinéticos / Opioides',
      'Inflamación Intestinal (EII)':                      'Inflamação Intestinal (DII)',
      'Tocolíticos / Obstetrícia':                         'Tocolíticos / Obstetrícia',
      'Tratamiento de Anemias':                            'Tratamento das Anemias',
      'Hemorragias / Coagulación':                         'Hemorragias / Coagulação',
      'Vitaminas y Suplementos':                           'Vitaminas e Suplementos',
      'Prurito y Alergias':                                'Prurido e Alergias',
      'Psoriasis y Caída de Pelo':                         'Psoríase e Queda de Cabelo',
      'Psicosis / Manía / Bipolaridad':                    'Psicose / Mania / Bipolaridade',
      'Vasoconstritores / Hepatologia':                    'Vasoconstritores / Hepatologia',
      'Respiratorio Avanzado':                             'Respiratório Avançado',
    };
    return groupPt[group] ?? group;
  }
}
