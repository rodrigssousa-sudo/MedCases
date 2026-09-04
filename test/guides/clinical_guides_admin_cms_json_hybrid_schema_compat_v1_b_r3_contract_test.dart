import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_guide_cms_import_service.dart';

void main() {
  const tceHybrid = r'''
{
  "schema_version": "1.0",
  "version": "1.1",
  "status": "APROVADO_PARA_GERACAO_DE_PDF",
  "human_approved": true,
  "human_approval_note": "Aprovado explicitamente pelo usuário em 2026-08-31 para geração de PDF PT/ES.",
  "pt": {
    "title": "Traumatismo Craniano Pediátrico (TCE)",
    "subtitle": "Como aplicar PECARN com segurança.",
    "summary": "Guia clínico pediátrico de teste.",
    "sections": [
      {"type": "heading", "text": "Escopo, objetivo e mensagem-chave"},
      {"type": "bullets", "title": "Conduta", "items": ["ABCDE", "Aplicar PECARN"]}
    ]
  },
  "es": {
    "title": "Traumatismo craneoencefálico pediátrico (TCE)",
    "subtitle": "Cómo aplicar PECARN con seguridad.",
    "summary": "Guía clínica pediátrica de prueba.",
    "sections": [
      {"type": "heading", "text": "Alcance, objetivo y mensaje clave"},
      {"type": "bullets", "title": "Conducta", "items": ["ABCDE", "Aplicar PECARN"]}
    ]
  },
  "references": [
    {
      "organization_or_authors": "Kuppermann N et al.",
      "title": "Identification of children at very low risk of clinically-important brain injuries after head trauma",
      "publication": "Lancet",
      "year": 2009,
      "doi": "10.1016/S0140-6736(09)61534-2",
      "url": "https://pubmed.ncbi.nlm.nih.gov/19758692/"
    }
  ]
}
''';

  const invalidHybridWrongVersion = r'''
{
  "schema_version": "1.0",
  "version": "2.0",
  "pt": {
    "title": "PT",
    "subtitle": "PT",
    "summary": "PT",
    "sections": [{"type": "paragraph", "text": "PT"}],
    "references": ["Ref."]
  },
  "es": {
    "title": "ES",
    "subtitle": "ES",
    "summary": "ES",
    "sections": [{"type": "paragraph", "text": "ES"}],
    "references": ["Ref."]
  }
}
''';

  const invalidExplicitSchema = r'''
{
  "schema_version": "2.0",
  "version": "1.1",
  "pt": {},
  "es": {}
}
''';

  test('accepts TCE-style hybrid editorial V1 envelope', () {
    final imported = ClinicalGuideCmsImportService.parseJson(tceHybrid);

    expect(imported.schemaVersion, '1.0');
    expect(imported.version, 1);
    expect(imported.year, '2026');
    expect(imported.topicPt, 'Traumatismo Craniano Pediátrico (TCE)');
    expect(
      imported.topicEs,
      'Traumatismo craneoencefálico pediátrico (TCE)',
    );
    expect(imported.pt.references, hasLength(1));
    expect(imported.es.references, imported.pt.references);
    expect(imported.pt.references.single, contains('Kuppermann N et al.'));
  });

  test('does not treat non-V1 root version as editorial V1', () {
    expect(
      () => ClinicalGuideCmsImportService.parseJson(invalidHybridWrongVersion),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });

  test('explicit schema 2.0 remains blocked', () {
    expect(
      () => ClinicalGuideCmsImportService.parseJson(invalidExplicitSchema),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });
}
