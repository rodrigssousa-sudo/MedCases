class ProtocolModel {
  final String id;
  final Map<String, String> title;
  final Map<String, String> severity;
  final Map<String, String> recognize;
  final Map<String, dynamic> actions;
  final Map<String, String> avoid;
  final List<String> drugs;

  const ProtocolModel({
    required this.id,
    required this.title,
    required this.severity,
    required this.recognize,
    required this.actions,
    required this.avoid,
    required this.drugs,
  });

  String getField(Map<String, String> field, String lang) {
    return field[lang] ?? field['pt'] ?? field['es'] ?? '';
  }

  List<String> getActions(String lang) {
    final list = actions[lang] ?? actions['pt'] ?? [];
    if (list is List) return list.cast<String>();
    return [];
  }
}
