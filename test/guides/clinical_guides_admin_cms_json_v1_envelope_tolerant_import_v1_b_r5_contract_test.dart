import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_guide_cms_import_service.dart';

void main() {
  const localePt = r'''
    "pt": {
      "title": "Guia PT",
      "subtitle": "Sub PT",
      "summary": "Resumo PT",
      "sections": [
        {"type": "heading", "text": "Tema"},
        {"type": "paragraph", "text": "Conduta segura."}
      ],
      "references": ["Referência 1"]
    }
  ''';

  const localeEs = r'''
    "es": {
      "title": "Guía ES",
      "subtitle": "Sub ES",
      "summary": "Resumen ES",
      "sections": [
        {"type": "heading", "text": "Tema"},
        {"type": "paragraph", "text": "Conducta segura."}
      ],
      "references": ["Referência 1"]
    }
  ''';

  test('accepts minimal PT ES CMS with no schema metadata or version', () {
    final source = '{$localePt,$localeEs}';
    final imported = ClinicalGuideCmsImportService.parseJson(source);

    expect(imported.schemaVersion, '1.0');
    expect(imported.version, 1);
    expect(imported.year, isEmpty);
    expect(imported.pt.blocks, hasLength(2));
    expect(imported.es.blocks, hasLength(2));
  });

  test('accepts metadata object without schema_version', () {
    final source = '{"metadata":{"version":"1.1","review_date":"2026-09-02"},'
        '$localePt,$localeEs}';
    final imported = ClinicalGuideCmsImportService.parseJson(source);

    expect(imported.schemaVersion, '1.0');
    expect(imported.version, 1);
    expect(imported.year, '2026');
  });

  test('accepts schema 1.0 with no metadata and no root version', () {
    final source = '{"schema_version":"1.0",$localePt,$localeEs}';
    final imported = ClinicalGuideCmsImportService.parseJson(source);

    expect(imported.schemaVersion, '1.0');
    expect(imported.version, 1);
    expect(imported.year, isEmpty);
  });

  test('explicit schema 2.0 remains blocked', () {
    final source = '{"schema_version":"2.0",$localePt,$localeEs}';
    expect(
      () => ClinicalGuideCmsImportService.parseJson(source),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });

  test('metadata with invalid type remains blocked', () {
    final source = '{"schema_version":"1.0","metadata":"invalid",'
        '$localePt,$localeEs}';
    expect(
      () => ClinicalGuideCmsImportService.parseJson(source),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });

  test('root editorial version 2 remains blocked without metadata', () {
    final source = '{"version":"2.0",$localePt,$localeEs}';
    expect(
      () => ClinicalGuideCmsImportService.parseJson(source),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });
}
