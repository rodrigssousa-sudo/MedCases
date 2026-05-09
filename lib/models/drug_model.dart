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

  static String icon(String group) {
    switch (group) {
      case cardiovascular:  return '❤️';
      case criticos:        return '🏥';
      case analgesicos:     return '💊';
      case antibioticos:    return '🦠';
      case infecto:         return '🔬';
      case anticoagulantes: return '🩸';
      case respiratorio:    return '🫁';
      case neurologia:      return '🧠';
      case gastro:          return '🫀';
      case endocrino:       return '⚗️';
      case hemato:          return '💉';
      case varios:          return '🧪';
      default:              return '💊';
    }
  }
}
