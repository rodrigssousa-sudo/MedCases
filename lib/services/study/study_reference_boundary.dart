/// Request-scoped provenance. Provider-authored bibliography is never promoted
/// into this set; only the internal catalog and transport grounding may add it.
class StudyReferenceBoundary {
  StudyReferenceBoundary([Iterable<String> internalRecords = const []])
      : _records = {...internalRecords.where((r) => r.trim().isNotEmpty).take(4)};
  final Set<String> _records;
  List<String> get records => List.unmodifiable(_records);

  String appendTo(String body, String language) => _records.isEmpty || body.trim().isEmpty
      ? body
      : '$body\n\n## ${language.startsWith('es') ? 'Referencias' : 'Referências'}\n\n${_records.map((r) => '- $r').join('\n')}';

  void addGrounding(Iterable<({String title, String url})> sources) {
    for (final source in sources) {
      if (_records.length >= 6) break;
      final uri = Uri.tryParse(source.url);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
          uri.userInfo.isNotEmpty || source.title.trim().isEmpty) continue;
      if (!_records.any((r) => r.contains(source.url))) {
        _records.add('${source.title.trim()} — ${source.url}');
      }
    }
  }

  String present(String text) {
    var inReferences = false;
    final lines = <String>[];
    for (final line in text.split('\n')) {
      final label = line.trim().replaceAll(RegExp(r'[#*_:]'), '').trim();
      if (RegExp(r'^(?:refer[eê]ncias?|referencias?|references?|fontes|fuentes|bibliografia|bibliografía)(?:\s+(?:bibliogr[aá]ficas|consultadas))?$', caseSensitive: false).hasMatch(label)) {
        inReferences = true;
        continue;
      }
      if (inReferences && (RegExp(r'^\s*#{1,6}\s').hasMatch(line) ||
          RegExp(r'^\s*\*\*[^*]+\*\*\s*:?[ ]*$').hasMatch(line))) inReferences = false;
      if (!inReferences) lines.add(line);
    }
    bool known(String identifier) => _records.any((r) => r.contains(identifier));
    var body = lines.join('\n').trimRight();
    body = body.replaceAllMapped(RegExp(r'\[([^\]]+)\]\((https?://[^\s)]+)\)'), (m) => known(m[2]!) ? m[0]! : m[1]!);
    body = body.replaceAllMapped(RegExp(r'https?://[^\s<>]+'), (m) => known(m[0]!.replaceFirst(RegExp(r'[).,;]+$'), '')) ? m[0]! : '');
    body = body.replaceAllMapped(RegExp(r'\b(?:doi:\s*)?10\.\d{4,9}/[^\s<>]+|\bPMID\s*:\s*\d+', caseSensitive: false), (m) => known(m[0]!) ? m[0]! : '');
    // The model's citation numbers have no binding to our request-scoped list.
    // A nonempty catalog cannot authenticate those invented ordinal bindings.
    body = body.replaceAll(RegExp(r'\[(?:\d+(?:\s*[,–-]\s*\d+)*)\](?!\()'), '');
    return body.trim();
  }
}
