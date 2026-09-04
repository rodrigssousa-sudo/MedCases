import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_guide_cms_import_service.dart';

void main() {
  const pneumothoraxBlocks = r'''
{
  "schema_version": "1.0",
  "metadata": {
    "topic_pt": "Pneumotórax",
    "topic_es": "Neumotórax",
    "review_date": "2026-08-28",
    "version": "1.1"
  },
  "pt": {
    "title": "Pneumotórax em adultos",
    "subtitle": "Atualização 2026",
    "summary": "Guia clínica de teste.",
    "references": ["Referência compartilhada"],
    "blocks": [
      {"type": "heading", "level": 1, "text": "Escopo e uso"},
      {"type": "paragraph", "text": "Conteúdo clínico."},
      {
        "type": "table",
        "title": "Categorias",
        "headers": ["Categoria", "Conduta"],
        "rows": [["Primário", "Avaliar estabilidade"]]
      }
    ]
  },
  "es": {
    "title": "Neumotórax en adultos",
    "subtitle": "Actualización 2026",
    "summary": "Guía clínica de prueba.",
    "references": ["Referência compartilhada"],
    "blocks": [
      {"type": "heading", "level": 1, "text": "Alcance y uso"},
      {"type": "paragraph", "text": "Contenido clínico."},
      {
        "type": "table",
        "title": "Categorías",
        "headers": ["Categoría", "Conducta"],
        "rows": [["Primario", "Evaluar estabilidad"]]
      }
    ]
  }
}
''';

  test('accepts canonical CMS using blocks alias in both locales', () {
    final imported =
        ClinicalGuideCmsImportService.parseJson(pneumothoraxBlocks);

    expect(imported.schemaVersion, '1.0');
    expect(imported.year, '2026');
    // Source payload has 3 source items, but the existing importer
    // intentionally expands `table` into native Admin presentation blocks.
    // Validate source-shape preservation separately from rendered block count.
    expect(imported.pt.sourceTypes, ['heading', 'paragraph', 'table']);
    expect(imported.es.sourceTypes, ['heading', 'paragraph', 'table']);
    expect(imported.pt.blocks, hasLength(4));
    expect(imported.es.blocks, hasLength(4));
  });

  test('non-empty sections remains authoritative over blocks', () {
    const source = r'''
{
  "schema_version": "1.0",
  "metadata": {"review_date":"2026-09-02","version":"1.1"},
  "pt": {
    "title":"PT","subtitle":"PT","summary":"PT",
    "references":["Ref."],
    "sections":[{"type":"paragraph","text":"SECTIONS PT"}],
    "blocks":[{"type":"warning","title":"BLOCKS","text":"BLOCKS PT"}]
  },
  "es": {
    "title":"ES","subtitle":"ES","summary":"ES",
    "references":["Ref."],
    "sections":[{"type":"paragraph","text":"SECTIONS ES"}],
    "blocks":[{"type":"warning","title":"BLOCKS","text":"BLOCKS ES"}]
  }
}
''';

    final imported = ClinicalGuideCmsImportService.parseJson(source);

    expect(imported.pt.blocks, hasLength(1));
    expect(imported.es.blocks, hasLength(1));
    expect(imported.pt.sourceTypes.single, 'paragraph');
    expect(imported.es.sourceTypes.single, 'paragraph');
  });

  test('blocks alias still enforces PT ES structural parity', () {
    const source = r'''
{
  "schema_version": "1.0",
  "metadata": {"review_date":"2026-09-02","version":"1.1"},
  "pt": {
    "title":"PT","subtitle":"PT","summary":"PT",
    "references":["Ref."],
    "blocks":[{"type":"paragraph","text":"PT"}]
  },
  "es": {
    "title":"ES","subtitle":"ES","summary":"ES",
    "references":["Ref."],
    "blocks":[{"type":"warning","title":"Alerta","text":"ES"}]
  }
}
''';

    expect(
      () => ClinicalGuideCmsImportService.parseJson(source),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });

  test('invalid blocks type does not bypass sections validation', () {
    const source = r'''
{
  "schema_version": "1.0",
  "metadata": {"review_date":"2026-09-02","version":"1.1"},
  "pt": {
    "title":"PT","subtitle":"PT","summary":"PT",
    "references":["Ref."],
    "blocks":"invalid"
  },
  "es": {
    "title":"ES","subtitle":"ES","summary":"ES",
    "references":["Ref."],
    "blocks":"invalid"
  }
}
''';

    expect(
      () => ClinicalGuideCmsImportService.parseJson(source),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });
}
