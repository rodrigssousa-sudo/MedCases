import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_guide_cms_import_service.dart';

void main() {
  const legacyEditorialCms = r'''
{
  "version": "1.0",
  "status": "APROVADO_PARA_GERACAO_DE_PDF",
  "human_approved": true,
  "human_approval_note": "Aprovado explicitamente pelo usuário em 2026-08-31 para geração de PDF PT/ES.",
  "pt": {
    "title": "Traumatismo Craniano Pediátrico (TCE)",
    "subtitle": "Como aplicar PECARN com segurança.",
    "summary": "Guia clínico pediátrico de teste.",
    "sections": [
      {
        "id": "escopo",
        "type": "heading",
        "level": 1,
        "text": "Escopo, objetivo e mensagem-chave"
      },
      {
        "id": "conduta",
        "type": "bullets",
        "title": "Conduta",
        "items": ["ABCDE", "Reavaliar"]
      }
    ]
  },
  "es": {
    "title": "Traumatismo Craneal Pediátrico (TCE)",
    "subtitle": "Cómo aplicar PECARN con seguridad.",
    "summary": "Guía clínica pediátrica de prueba.",
    "sections": [
      {
        "id": "escopo",
        "type": "heading",
        "level": 1,
        "text": "Alcance, objetivo y mensaje clave"
      },
      {
        "id": "conduta",
        "type": "bullets",
        "title": "Conducta",
        "items": ["ABCDE", "Reevaluar"]
      }
    ]
  },
  "references": [
    {
      "organization_or_authors": "Kuppermann N et al.",
      "title": "PECARN pediatric head trauma study",
      "publication": "Lancet",
      "year": 2009,
      "doi": "10.1016/test",
      "url": "https://example.com/pecarn"
    }
  ]
}
''';

  const legacyWithoutApprovalDate = r'''
{
  "version": "1",
  "pt": {
    "title": "Guia PT",
    "subtitle": "Subtítulo PT",
    "summary": "Resumo PT",
    "sections": [
      {"type": "paragraph", "text": "Conteúdo PT"}
    ],
    "references": ["Referência compartilhada."]
  },
  "es": {
    "title": "Guía ES",
    "subtitle": "Subtítulo ES",
    "summary": "Resumen ES",
    "sections": [
      {"type": "paragraph", "text": "Contenido ES"}
    ],
    "references": ["Referência compartilhada."]
  }
}
''';

  const malformedCanonicalMetadata = r'''
{
  "schema_version": "1.0",
  "metadata": "not-an-object",
  "pt": {},
  "es": {}
}
''';

  const unsupportedSchema = r'''
{
  "schema_version": "2.0",
  "metadata": {},
  "pt": {},
  "es": {}
}
''';

  test('accepts approved editorial CMS V1 without schema_version or metadata',
      () {
    final imported =
        ClinicalGuideCmsImportService.parseJson(legacyEditorialCms);

    expect(imported.schemaVersion, '1.0');
    expect(imported.version, 1);
    expect(imported.year, '2026');
    expect(imported.topicPt, 'Traumatismo Craniano Pediátrico (TCE)');
    expect(imported.topicEs, 'Traumatismo Craneal Pediátrico (TCE)');
    expect(imported.pt.blocks, isNotEmpty);
    expect(imported.es.blocks, isNotEmpty);
    expect(imported.pt.references, hasLength(1));
    expect(imported.es.references, imported.pt.references);
    expect(imported.pt.references.single, contains('Kuppermann N et al.'));
  });

  test('legacy V1 without explicit date remains importable for admin review',
      () {
    final imported =
        ClinicalGuideCmsImportService.parseJson(legacyWithoutApprovalDate);

    expect(imported.schemaVersion, '1.0');
    expect(imported.version, 1);
    expect(imported.year, isEmpty);
    expect(imported.pt.references, imported.es.references);
  });

  test('malformed canonical metadata still blocks', () {
    expect(
      () => ClinicalGuideCmsImportService.parseJson(
        malformedCanonicalMetadata,
      ),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });

  test('unsupported explicit canonical schema still blocks', () {
    expect(
      () => ClinicalGuideCmsImportService.parseJson(unsupportedSchema),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });
}
