import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/clinical_guide_article.dart';

void main() {
  group('Clinical guides editorial foundation', () {
    test('reads new editorial fields', () {
      final guide = ClinicalGuideArticle.fromJson(
        <String, dynamic>{
          'id': 'sepsis-2026',
          'slug': 'sepsis-adulto',
          'language': 'es',
          'specialty': 'Emergencias',
          'title': 'Sepsis',
          'subtitle': 'Reconocimiento y manejo inicial',
          'heroImageUrl': 'https://example.com/sepsis.jpg',
          'summary': 'Resumen clínico.',
          'bodyBlocks': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'heading',
              'text': 'Diagnóstico',
            },
            <String, dynamic>{
              'type': 'bullets',
              'items': <String>['Punto A', 'Punto B'],
            },
          ],
          'references': <String>['Guideline 2026'],
          'status': 'published',
          'isPublished': true,
          'version': 3,
        },
      );

      expect(guide.slug, 'sepsis-adulto');
      expect(guide.language, 'es');
      expect(guide.specialty, 'Emergencias');
      expect(guide.bodyBlocks, hasLength(2));
      expect(guide.references, <String>['Guideline 2026']);
      expect(guide.version, 3);
      expect(guide.hasEditorialBody, isTrue);
    });

    test('keeps legacy PDF guide backward compatible', () {
      final guide = ClinicalGuideArticle.fromJson(
        <String, dynamic>{
          'id': 'legacy',
          'title': 'Guia legado',
          'description': 'Descrição antiga',
          'category': 'Cardiologia',
          'coverUrl': 'https://example.com/cover.jpg',
          'pdfUrl': 'https://example.com/guide.pdf',
          'authors': 'MedCases',
          'year': '2025',
          'isPublished': true,
        },
      );

      expect(guide.title, 'Guia legado');
      expect(guide.summary, 'Descrição antiga');
      expect(guide.specialty, 'Cardiologia');
      expect(guide.heroImageUrl, 'https://example.com/cover.jpg');
      expect(guide.pdfUrl, 'https://example.com/guide.pdf');
      expect(guide.hasEditorialBody, isFalse);
      expect(guide.isPublished, isTrue);
    });

    test('supports content fallback and string references', () {
      final guide = ClinicalGuideArticle.fromJson(
        <String, dynamic>{
          'title': 'Fallback',
          'content': 'Texto clínico remoto',
          'references': 'Ref 1\nRef 2',
        },
      );

      expect(guide.bodyBlocks, hasLength(1));
      expect(guide.bodyBlocks.single.text, 'Texto clínico remoto');
      expect(guide.references, <String>['Ref 1', 'Ref 2']);
    });
  });
}
