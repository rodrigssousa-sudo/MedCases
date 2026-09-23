import 'package:flutter/material.dart';
import '../../../services/plantao_knowledge/remote_knowledge.dart';
import '../../../services/plantao_knowledge/remote_knowledge_resolver.dart';

class TherapeuticOptionsView extends StatelessWidget {
  const TherapeuticOptionsView(
      {super.key,
      required this.session,
      required this.options,
      required this.onCopy,
      required this.onAlternatives});
  final TherapeuticOptionSession session;
  final List<Map<String, dynamic>> options;
  final VoidCallback onAlternatives;
  final Future<void> Function(String optionId) onCopy;
  bool get es => session.language == 'es';
  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
      stream: session.resolver.gateway.changes,
      builder: (_, __) => _content(context));

  Widget _content(BuildContext context) {
    if (!session.current) return const SizedBox.shrink();
    final protocol = session.resolution.protocol!;
    Widget option(Map<String, dynamic> o, {required bool primary}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(knowledgeText(o['label'], session.language),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(knowledgeText(o['indication'], session.language)),
          if (o['type'] == 'ALTERNATIVE')
            Text(knowledgeText(o['whenToConsider'], session.language)),
          Text(
              PracticalPrescriptionFormatter.format(o, session.language) ?? ''),
          // References and safety stay on screen, never in the clipboard projection.
          for (final d in o['drugs'] as List)
            for (final field in ['contraindications', 'warnings'])
              if (d[field] != null)
                Text(knowledgeText(d[field], session.language)),
          for (final ref in protocol.json['references'] as List)
            if ((o['references'] as List).contains(ref['referenceId']) ||
                (o['drugs'] as List).any((d) =>
                    (d['references'] as List).contains(ref['referenceId'])))
              Text(
                  '${knowledgeText(ref['title'], session.language)} — ${ref['url']}'),
          if (!primary)
            TextButton(
                key: ValueKey('copy_${o['optionId']}'),
                onPressed: () => onCopy(o['optionId'] as String),
                child: const Text('COPIAR')),
          const SizedBox(height: 8),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(es ? 'TRATAMIENTO' : 'TRATAMENTO',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      for (var i = 0; i < options.length; i++)
        option(options[i], primary: i == 0),
      if (options.singleOrNull?['type'] == 'PRIMARY' &&
          protocol.alternatives.isNotEmpty)
        TextButton(
            key: const ValueKey('other_therapeutic_options'),
            onPressed: onAlternatives,
            child: Text(es
                ? 'Ver otras opciones terapéuticas'
                : 'Ver outras opções terapêuticas')),
    ]);
  }
}
