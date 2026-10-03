import '../models/protocol_model.dart';
import 'new_pathology_approved_hashes.dart';
import 'protocols_database.dart';

/// Complete context only for the human-approved expansion; legacy retrieval stays intact.
String? approvedNewPathologyContext(
  String query,
  String language, {
  required String Function(String) normalize,
  List<ProtocolModel>? matchedProtocols,
}) {
  final folded = normalize(query);
  ProtocolModel? selected;
  var best = 0;
  var ambiguous = false;
  for (final protocol in protocolsDatabase) {
    if (!newPathologyApprovedHashes.containsKey(protocol.id)) continue;
    final names = <String>{
      protocol.id.replaceAll('_', ' '),
      ...protocol.title.values,
      for (final title in protocol.title.values) ...title.split(' / '),
    };
    for (final name in names) {
      final alias = normalize(name).trim();
      if (alias.length < 4) continue;
      final pattern =
          RegExp('(?:^|[^a-z0-9])${RegExp.escape(alias)}(?:\$|[^a-z0-9])');
      if (!pattern.hasMatch(folded)) continue;
      if (alias.length > best) {
        selected = protocol;
        best = alias.length;
        ambiguous = false;
      } else if (alias.length == best && selected?.id != protocol.id) {
        ambiguous = true;
      }
    }
  }
  if (selected == null || ambiguous) return null;
  matchedProtocols?.add(selected);
  final locale = language == 'es' ? 'es' : 'pt';
  return <String>[
    'owner=${selected.id}',
    'clinicalVersion=${newPathologyG02Versions[selected.id] ?? 'NEW-JIT-2026-10-02-v1.0'}',
    'clinicalReviewDate=${newPathologyG02Versions.containsKey(selected.id) ? '2026-10-03' : '2026-10-02'}',
    'approvedClinicalPayloadSha256=${newPathologyApprovedHashes[selected.id]}',
    locale == 'es'
        ? 'TIEMPO CLÍNICO: escribir horas, días, semanas, meses y minutos por extenso. No usar h, d, min, mo ni c/. No convertir semana en mes ni frecuencia en duración. Mantener los valores y las condiciones verificados; no inventar un intervalo ausente.'
        : 'TEMPO CLÍNICO: escrever horas, dias, semanas, meses e minutos por extenso. Não usar h, d, min, mo nem c/. Não converter semana em mês nem frequência em duração. Manter os valores e as condições verificados; não inventar intervalo ausente.',
    selected.getField(selected.title, locale),
    ...selected.getActions(locale),
    ...selected.getList(selected.references, locale),
  ].join('\n\n');
}
