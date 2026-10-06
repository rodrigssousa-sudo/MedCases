import 'dart:convert';
import 'dart:io';
import 'package:medcases/data/protocols_database.dart';
import 'package:medcases/services/clinical_catalog/clinical_catalog_repository.dart';

void main(List<String> args) {
  if (args.length != 1) throw ArgumentError('OUTPUT required');
  final rows = protocolsDatabase
      .map((p) => {
            'id': p.id,
            'canonicalFamilyId': p.canonicalFamilyId,
            'canonicalProtocolId': p.canonicalProtocolId,
            'titleLocales': p.title.keys.toList(),
            'definitionLocales': p.definition?.keys.toList(),
            'actionLocales': p.actions.keys.toList(),
            'referenceLocales': p.references?.keys.toList(),
            'definitionHash': clinicalHash(p.definition),
            'actionsHash': clinicalHash(p.actions),
            'referencesHash': clinicalHash(p.references),
            'approvalStatus': 'NOT_PROVEN_PER_OWNER_MODE_LOCALE',
          })
      .toList();
  File(args.single).writeAsStringSync(jsonEncode(rows));
  stdout.writeln('LOCAL_COMPILED_OWNERS=${rows.length}');
}
