import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compact CMS action bar is content-height only', () {
    final source = File(
      'lib/screens/admin_clinical_guide_editor_screen.dart',
    ).readAsStringSync();

    final start = source.indexOf('if (constraints.maxWidth < 620)');
    expect(start, greaterThanOrEqualTo(0));

    final end = (start + 1800).clamp(0, source.length);
    final compact = source.substring(start, end);

    expect(compact, contains('mainAxisSize: MainAxisSize.min'));
    expect(compact, contains('crossAxisAlignment: CrossAxisAlignment.stretch'));
    expect(compact, contains('draftButton'));
    expect(compact, contains('previewButton'));
    expect(compact, contains('publishButton'));
  });

  test('action bar keeps the three approved actions', () {
    final source = File(
      'lib/screens/admin_clinical_guide_editor_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Salvar rascunho'));
    expect(source, contains('Pré-visualizar'));
    expect(source, contains('Publicar PT + ES'));
  });
}
