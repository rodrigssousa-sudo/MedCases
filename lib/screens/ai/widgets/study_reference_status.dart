import '../../../services/clinical_catalog/clinical_catalog_platform.dart';
import '../../../services/study/study_reference_lookup.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'clinical_reference_resolver.dart';

/// Reference-only retry: never invokes a clinical generation or changes its body.
class StudyReferenceStatus extends StatefulWidget {
  const StudyReferenceStatus({super.key, required this.query, required this.lang});
  final String query, lang;
  @override
  State<StudyReferenceStatus> createState() => _StudyReferenceStatusState();
}
class _StudyReferenceStatusState extends State<StudyReferenceStatus> {
  List<String> _records = const [];
  bool _busy = false;
  Future<void> _retry() async {
    if (_busy) return;
    setState(() => _busy = true);
    final catalog = await SharedClinicalCatalog.instance.acquire();
    var records = catalog.isBundled
        ? (ClinicalReferenceResolver.resolveStudy(userText: widget.query)?.lines ?? const <String>[])
        : catalog.references(widget.query, 'study', widget.lang);
    if (records.isEmpty) {
      final sources = await StudyReferenceLookup.resolve(widget.query);
      records = sources.map((s) => '${s.title} — ${s.url}').toList();
    }
    if (mounted) setState(() { _records = records; _busy = false; });
  }
  @override
  Widget build(BuildContext context) {
    final es = widget.lang.startsWith('es');
    return Material(type: MaterialType.transparency, child: ExpansionTile(
      key: const ValueKey('study-dynamic-references'),
      title: Text(es ? 'Referencias' : 'Referências'),
      children: [
        if (_records.isEmpty) TextButton(
          onPressed: _busy ? null : _retry,
          child: Text(es ? 'Referencias en actualización. Reintentar.' : 'Referências em atualização. Tentar novamente.')),
        for (final record in _records) ListTile(title: Text(record), onTap: () {
          final match = RegExp(r'https://[^\s]+').firstMatch(record);
          if (match != null) launchUrl(Uri.parse(match.group(0)!), mode: LaunchMode.externalApplication);
        }),
      ],
    ));
  }
}
