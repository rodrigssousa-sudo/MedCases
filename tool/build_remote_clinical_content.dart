import 'dart:convert';
import 'dart:io';
import 'package:medcases/services/clinical_content/clinical_content_contract.dart';
import 'package:medcases/services/clinical_content/clinical_content_release_builder.dart';

/// Creates local, derived publication files. Never uploads or deploys.
/// Input items must already carry their exact source identity/hash/status.
void main(List<String> args) {
  if (args.length != 2) {
    throw ArgumentError(
        'Usage: dart run tool/build_remote_clinical_content.dart reviewed-input.json empty-output-directory');
  }
  final input = contentObject(jsonDecode(File(args[0]).readAsStringSync()));
  final output = Directory(args[1]);
  requireContent(
      !output.existsSync() || output.listSync().isEmpty, 'OUTPUT_NOT_EMPTY');
  final domains = contentObject(input['domains'])
      .map((k, v) => MapEntry(k, (v as List).map(contentObject).toList()));
  final files = ClinicalContentReleaseBuilder.build(
      domains: domains,
      sequence: input['sequence'] as int,
      contentVersion: input['contentVersion'] as String,
      generatedAt: DateTime.parse(input['generatedAt'] as String),
      publicationStatus: input['publicationStatus'] as String? ?? 'DRAFT',
      minimumAppSchema: input['minimumAppSchema'] as int? ?? 1);
  for (final entry in files.entries) {
    final file = File('${output.path}/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(entry.value));
  }
  stdout.writeln(jsonEncode({
    'state': files['manifest.json']!['publicationStatus'],
    'domains': domains.map((k, v) => MapEntry(k, v.length)),
    'files': files.length,
    'deployed': false
  }));
}
