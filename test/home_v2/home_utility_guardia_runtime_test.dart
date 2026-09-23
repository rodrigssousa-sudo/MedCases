import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medcases/home_v2/components/home_v2_modules_view.dart';

void main() {
  for (final dark in [false, true]) {
    for (final isEs in [false, true]) {
      testWidgets('utility SVG geometry and all actions $dark/$isEs',
          (tester) async {
        final calls = <String>[];
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: HomeV2UtilityRow(
          dark: dark,
          isEs: isEs,
          onAssessment: () => calls.add('assessment'),
          onLaboratory: () => calls.add('laboratory'),
          onNotes: () => calls.add('notes'),
          onTimer: () => calls.add('timer'),
        ))));
        await tester.pumpAndSettle();
        final labels = isEs
            ? ['LABORATORIO', 'EVALUACIÓN', 'CREAR RESUMEN', 'TEMPORIZADOR']
            : ['LABORATÓRIO', 'AVALIAÇÃO', 'CRIAR RESUMO', 'TIMER'];
        expect(tester.widgetList<Text>(find.byType(Text)).map((t) => t.data),
            labels);
        final icons =
            tester.widgetList<SvgPicture>(find.byType(SvgPicture)).toList();
        expect(icons.map((i) => (i.bytesLoader as SvgAssetLoader).assetName), [
          'assets/icons/home_v2/ic_laboratorio.svg',
          'assets/icons/home_v2/ic_avaliacao.svg',
          'assets/icons/home_v2/resumo.svg',
          'assets/icons/home_v2/ic_timer.svg',
        ]);
        for (final icon in icons) {
          expect(icon.width, 54);
          expect(icon.height, 54);
          expect(icon.colorFilter, isNull);
        }
        expect(find.byType(Icon), findsNothing);
        for (final label in labels) {
          await tester.tap(find.text(label));
        }
        expect(calls, ['laboratory', 'assessment', 'notes', 'timer']);
        expect(tester.takeException(), isNull);
      });
      testWidgets('Guardia current SVG and child are rendered $dark/$isEs',
          (tester) async {
        var taps = 0;
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: HomeV2GuardiaSurface(
          dark: dark,
          isEs: isEs,
          child: TextButton(
              onPressed: () => taps++, child: const Text('Open patient')),
        ))));
        await tester.pumpAndSettle();
        expect(find.text(isEs ? 'MI GUARDIA' : 'MEU PLANTÃO'), findsOneWidget);
        final icon = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect((icon.bytesLoader as SvgAssetLoader).assetName,
            'assets/icons/home_v2/ic_mi_guardia.svg');
        expect(icon.width, 44);
        expect(icon.height, 44);
        expect(icon.colorFilter, isNull);
        expect(find.byType(Icon), findsNothing);
        await tester.tap(find.text('Open patient'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
