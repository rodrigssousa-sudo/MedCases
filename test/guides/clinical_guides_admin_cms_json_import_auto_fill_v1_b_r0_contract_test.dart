import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/clinical_guide_cms_import_service.dart';

void main() {
  const sample = r"""
{
  "schema_version": "1.0",
  "metadata": {
    "topic_pt": "Sepse e choque séptico",
    "topic_es": "Sepsis y shock séptico",
    "specialty_pt": "Medicina de Emergência e Terapia Intensiva",
    "review_date": "2026-08-26",
    "version": "1.0"
  },
  "pt": {
    "title": "Sepse e choque séptico em adultos",
    "subtitle": "Reconhecimento e tratamento",
    "summary": "Resumo PT",
    "sections": [
      {
        "type": "heading",
        "text": "Definição"
      },
      {
        "type": "table",
        "title": "Conceitos operacionais",
        "headers": ["Condição", "Definição prática"],
        "rows": [
          ["Sepse", "Disfunção orgânica."],
          ["Choque séptico", "Vasopressor e lactato."]
        ]
      },
      {
        "type": "algorithm",
        "title": "Primeiras decisões",
        "steps": ["Reconhecer", "Tratar"]
      },
      {
        "type": "warning",
        "title": "EMERGÊNCIA",
        "text": "Iniciar tratamento."
      }
    ],
    "references": [
      {
        "organization_or_authors": "Autor A",
        "title": "Guideline X",
        "publication": "Journal",
        "year": 2026,
        "doi": "10.0000/test",
        "url": "https://example.com/x"
      }
    ]
  },
  "es": {
    "title": "Sepsis y shock séptico en adultos",
    "subtitle": "Reconocimiento y tratamiento",
    "summary": "Resumen ES",
    "sections": [
      {
        "type": "heading",
        "text": "Definición"
      },
      {
        "type": "table",
        "title": "Conceptos operativos",
        "headers": ["Condición", "Definición práctica"],
        "rows": [
          ["Sepsis", "Disfunción orgánica."],
          ["Shock séptico", "Vasopresor y lactato."]
        ]
      },
      {
        "type": "algorithm",
        "title": "Primeras decisiones",
        "steps": ["Reconocer", "Tratar"]
      },
      {
        "type": "warning",
        "title": "EMERGENCIA",
        "text": "Iniciar tratamiento."
      }
    ],
    "references": [
      {
        "organization_or_authors": "Autor A",
        "title": "Guideline X",
        "publication": "Journal",
        "year": 2026,
        "doi": "10.0000/test",
        "url": "https://example.com/x"
      }
    ]
  },
  "source_audit": {
    "should_not_enter_form": true
  },
  "gates": {
    "human_approved": true
  }
}
""";

  test('parses canonical PT ES package and converts table algorithm', () {
    final imported = ClinicalGuideCmsImportService.parseJson(sample);

    expect(imported.schemaVersion, '1.0');
    expect(imported.year, '2026');
    expect(imported.version, 1);

    expect(imported.pt.title, 'Sepse e choque séptico em adultos');
    expect(imported.es.title, 'Sepsis y shock séptico en adultos');

    expect(imported.pt.sourceTypes, [
      'heading',
      'table',
      'algorithm',
      'warning',
    ]);
    expect(imported.es.sourceTypes, imported.pt.sourceTypes);

    expect(imported.pt.tableConversions, 1);
    expect(imported.pt.algorithmConversions, 1);
    expect(imported.es.tableConversions, 1);
    expect(imported.es.algorithmConversions, 1);

    expect(imported.pt.blocks.map((b) => b.type), [
      'heading',
      'heading',
      'bullets',
      'heading',
      'bullets',
      'warning',
    ]);

    expect(imported.pt.blocks[2].text, contains('Sepse — Disfunção orgânica.'));
    expect(imported.pt.blocks[4].text, 'Reconhecer\nTratar');

    expect(imported.pt.references.length, 1);
    expect(imported.pt.references, imported.es.references);
    expect(imported.pt.references.single, contains('DOI: 10.0000/test.'));
    expect(imported.pt.references.single, contains('https://example.com/x'));
  });

  test('blocks divergent PT ES section structure', () {
    final divergent = sample.replaceFirst(
      '"type": "warning",\n        "title": "EMERGENCIA"',
      '"type": "note",\n        "title": "EMERGENCIA"',
    );

    expect(
      () => ClinicalGuideCmsImportService.parseJson(divergent),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });

  test('blocks unsupported schema before applying data', () {
    final invalid = sample.replaceFirst(
      '"schema_version": "1.0"',
      '"schema_version": "2.0"',
    );

    expect(
      () => ClinicalGuideCmsImportService.parseJson(invalid),
      throwsA(isA<ClinicalGuideCmsImportException>()),
    );
  });

  test(
    'editor exposes validated CMS JSON import without touching PDF flow',
    () {
      final source = File(
        'lib/screens/admin_clinical_guide_editor_screen.dart',
      ).readAsStringSync();

      expect(source, contains('Importar CMS JSON'));
      expect(source, contains('ClinicalGuideCmsImportService.parseBytes'));
      expect(source, contains("allowedExtensions: const ['json']"));
      expect(source, contains('_applyImportedLocale(_pt, imported.pt)'));
      expect(source, contains('_applyImportedLocale(_es, imported.es)'));
      expect(source, contains('MedCases Clinical Editorial'));

      expect(source, contains("allowedExtensions: const ['pdf']"));
      expect(source, contains('PDF PT opcional'));
      expect(source, contains('PDF ES opcional'));

      expect(source, contains('mainAxisSize: MainAxisSize.min'));
    },
  );
}
