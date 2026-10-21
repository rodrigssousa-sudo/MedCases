import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:medcases/screens/ai/widgets/guardia_clinical_response_view.dart';

void main() {
  for (final entry in {
    'pt': 'Resposta interrompida (validação falhou). Tente novamente.',
    'es': 'Respuesta interrumpida (validación fallida). Intenta nuevamente.',
  }.entries) {
    testWidgets('failed response appears once without success controls ${entry.key}',
        (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        GuardiaClinicalResponseView(
          rawText: '${entry.value} ⚕', dark: true,
          languageCode: entry.key, onCopy: () {}, onTts: () {},
          ttsReady: true,
        ),
      )));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(MarkdownBody), findsNothing);
    });
  }
}
