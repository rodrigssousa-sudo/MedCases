import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/widgets/canonical_drug_document_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final dir = Platform.environment['MEDCASES_PREVIEW_FONT_DIR'];
    if (dir == null) return;
    for (final entry in {
      'Preview': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf'
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(ByteData.sublistView(
            await File('$dir/${entry.value}').readAsBytes())));
      await loader.load();
    }
  });
  const document = <String, Object?>{
    'id': 'fixture',
    'pt': {
      'name': 'Documento canônico',
      'dose': 'TEXTO DE DOSE ORIGINAL',
      'preparation': 'PREPARO ORIGINAL',
      'alerts': ['ALERTA ORIGINAL'],
      'renalDose': 'RENAL ORIGINAL',
      'hepaticDose': 'HEPATICO ORIGINAL',
      'interactions': 'INTERACAO ORIGINAL',
      'references': ['REFERENCIA ORIGINAL']
    },
    'es': {'name': 'Documento canónico', 'dose': 'DOSIS ORIGINAL'}
  };
  for (final dark in [false, true]) {
    testWidgets('canonical renderer ordered, responsive and no raw map ($dark)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final preview = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: preview,
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  fontFamily: 'Preview',
                  brightness: dark ? Brightness.dark : Brightness.light),
              home: Scaffold(
                  body: SingleChildScrollView(
                      child: CanonicalDrugDocumentView(
                          document: document, language: 'pt'))))));
      expect(find.text('Documento canônico'), findsOneWidget);
      expect(find.text('TEXTO DE DOSE ORIGINAL'), findsOneWidget);
      expect(find.text('ALERTA ORIGINAL'), findsOneWidget);
      final tiles =
          tester.widgetList<ExpansionTile>(find.byType(ExpansionTile)).toList();
      expect(tiles.map((t) => (t.title as Text).data).toList(), [
        'Posologia',
        'Preparo e administração',
        'Alertas e monitoramento',
        'Ajuste renal',
        'Ajuste hepático',
        'Interações',
        'Referências'
      ]);
      expect(find.textContaining('canonicalDrugId'), findsNothing);
      expect(find.textContaining('"dose"'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await (preview.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
                '.dart_tool/global_local_blocker_closure/drug-ui-${dark ? 'dark' : 'light'}.png')
            .writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
  testWidgets('missing locale never borrows clinical translation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: CanonicalDrugDocumentView(document: document, language: 'en')));
    expect(find.text('TEXTO DE DOSE ORIGINAL'), findsNothing);
  });
}
