import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_guide_article.dart';
import 'package:medcases/models/guide_model.dart';

void main() {
  test('GuideModel keeps one guide with PT and ES presentation data', () {
    final guide = GuideModel.fromJson(<String, dynamic>{
      'id': 'sepse',
      'title': 'Sepse',
      'description': 'Resumo PT',
      'pdfUrl': '',
      'hasEditorialContent': true,
      'localizations': <String, dynamic>{
        'pt': <String, dynamic>{
          'title': 'Sepse',
          'summary': 'Resumo PT',
          'pdfUrl': 'https://example.com/pt.pdf',
          'bodyBlocks': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'paragraph', 'text': 'Texto PT'},
          ],
        },
        'es': <String, dynamic>{
          'title': 'Sepsis',
          'summary': 'Resumen ES',
          'pdfUrl': 'https://example.com/es.pdf',
          'bodyBlocks': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'paragraph', 'text': 'Texto ES'},
          ],
        },
      },
    });

    expect(guide.localizedTitle(false), 'Sepse');
    expect(guide.localizedTitle(true), 'Sepsis');
    expect(guide.localizedDescription(false), 'Resumo PT');
    expect(guide.localizedDescription(true), 'Resumen ES');
    expect(guide.localizedPdfUrl(false), 'https://example.com/pt.pdf');
    expect(guide.localizedPdfUrl(true), 'https://example.com/es.pdf');
    expect(guide.hasEditorialContent, isTrue);

    final es = guide.localizedCopy(true);
    expect(es.id, guide.id);
    expect(es.title, 'Sepsis');
    expect(es.localizations, isNotEmpty);
  });

  test('ClinicalGuideArticle resolves nested locale without translation', () {
    final article = ClinicalGuideArticle.fromJson(<String, dynamic>{
      'id': 'sepse',
      'title': 'Sepse',
      'summary': 'Resumo PT',
      'bodyBlocks': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'paragraph', 'text': 'Texto PT'},
      ],
      'localizations': <String, dynamic>{
        'pt': <String, dynamic>{
          'title': 'Sepse',
          'summary': 'Resumo PT',
          'bodyBlocks': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'paragraph', 'text': 'Texto PT'},
          ],
        },
        'es': <String, dynamic>{
          'title': 'Sepsis',
          'summary': 'Resumen ES',
          'bodyBlocks': <Map<String, dynamic>>[
            <String, dynamic>{'type': 'paragraph', 'text': 'Texto ES'},
          ],
        },
      },
    });

    final pt = article.forLanguage('pt');
    final es = article.forLanguage('es');

    expect(pt.title, 'Sepse');
    expect(es.title, 'Sepsis');
    expect(pt.bodyBlocks.single.text, 'Texto PT');
    expect(es.bodyBlocks.single.text, 'Texto ES');
  });

  test('Admin exposes approved full-screen bilingual CMS contract', () {
    final source = File(
      'lib/screens/admin_clinical_guide_editor_screen.dart',
    ).readAsStringSync();

    expect(source, contains('class AdminClinicalGuideEditorScreen'));
    expect(source, contains('PT · Português'));
    expect(source, contains('ES · Español'));
    expect(source, contains('1600 × 1200 px'));
    expect(source, contains('aspectRatio: 4 / 3'));
    expect(source, contains('Salvar rascunho'));
    expect(source, contains('Pré-visualizar'));
    expect(source, contains('Publicar PT + ES'));
    expect(
      source,
      contains("allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp']"),
    );
    expect(source, contains("allowedExtensions: const ['pdf']"));

    for (final type in const [
      "'heading'",
      "'paragraph'",
      "'bullets'",
      "'callout'",
      "'warning'",
      "'note'",
    ]) {
      expect(source, contains(type));
    }

    expect(source.toLowerCase(), isNot(contains('traduz')));
  });

  test(
    'Persistence uses one document and keeps PDF optional for native guides',
    () {
      final editorial = File(
        'lib/services/clinical_guides_editorial_service.dart',
      ).readAsStringSync();
      final firestore = File(
        'lib/services/firestore_service.dart',
      ).readAsStringSync();
      final library = File(
        'lib/screens/library_screen.dart',
      ).readAsStringSync();
      final admin = File('lib/screens/admin_screen.dart').readAsStringSync();

      expect(editorial, contains('saveBilingualGuide'));
      expect(editorial, contains("'pt': cleanPt"));
      expect(editorial, contains("'es': cleanEs"));
      expect(editorial, contains("'localizations': localizations"));
      expect(editorial, contains("'searchPrefixes': searchPrefixes"));
      expect(
        editorial,
        contains("'status': published ? 'published' : 'draft'"),
      );

      expect(firestore, contains('(missingPdf && missingEditorial)'));
      expect(
        editorial,
        contains('Guia editorial requer PT e ES completos antes de publicar.'),
      );

      expect(library, contains('.map((guide) => guide.localizedCopy(isEs))'));
      expect(library, contains('guide: article.forLanguage(lang),'));
      expect(admin, contains('AdminClinicalGuideEditorScreen('));
      expect(admin, contains("Text('Novo guia'"));
    },
  );

  test('Homologated public guide geometry markers remain present', () {
    final library = File('lib/screens/library_screen.dart').readAsStringSync();

    expect(
      library,
      contains(
        'final cardWidth = viewportWidth > 720 ? 620.0 : viewportWidth - 6.0;',
      ),
    );
    expect(library, contains('const railHeight = 356.0;'));
    expect(library, contains('MEDCASES_GUIDES_COUNT_HEADER_REMOVED_V1_B_R3'));
    expect(library, contains('GUIDE_SEARCH_EXACT_TITLE_ROW_GUIDE_ONLY'));
  });
}
