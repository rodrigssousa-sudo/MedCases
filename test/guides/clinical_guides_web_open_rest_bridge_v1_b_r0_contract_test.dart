import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web guide open uses authenticated REST while native keeps SDK path', () {
    final service =
        File('lib/services/clinical_guides_editorial_service.dart')
            .readAsStringSync();
    final library =
        File('lib/screens/library_screen.dart').readAsStringSync();
    final reader =
        File('lib/screens/clinical_guide_article_screen.dart').readAsStringSync();

    expect(
      service,
      contains('MEDCASES_WEB_GUIAS_OPEN_RELEASE_REST_BRIDGE_V1_B_R0'),
    );
    expect(service, contains('if (kIsWeb)'));
    expect(service, contains('return _loadByIdRestWeb(id);'));
    expect(service, contains('AuthService.getAdminToken()'));
    expect(service, contains("'Authorization': 'Bearer \$token'"));
    expect(service, contains('/documents/clinical_guides/\$encodedId'));
    expect(service, contains('_decodeFirestoreRestValue'));
    expect(service, contains('_collection.doc(id).get()'));

    // Existing click -> editorial reader wiring is intentionally untouched.
    expect(
      library,
      contains('ClinicalGuidesEditorialService.loadById(g.id)'),
    );
    expect(
      library,
      contains('article != null && article.hasEditorialBody'),
    );
    expect(library, contains('ClinicalGuideArticleScreen('));
    expect(library, contains('onOpen: _openGuide,'));

    // The reader itself has no web/mobile platform block.
    expect(reader, contains('class ClinicalGuideArticleScreen'));
    expect(reader, isNot(contains('if (!kIsWeb)')));
    expect(reader, isNot(contains('if (kIsWeb) return')));
  });
}
