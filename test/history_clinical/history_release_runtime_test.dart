import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/history_screen.dart';
import 'history_release_runtime_harness.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [390.0, 800.0]) {
      testWidgets('saved technical fields remain readable at $width dark=$dark',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final errorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details, forceReport: true);
          errorHandler!(details);
        };
        addTearDown(() => FlutterError.onError = errorHandler);
        final provider =
            await mountHistoryRuntime(tester, dark: dark, saved: true);
        final original = provider.myHistories.single.toJson();
        await tester.tap(find.text('MINHAS'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CAMPO_TESTE <&>'));
        await tester.pumpAndSettle();
        for (final value in [
          'CAMPO_TESTE <&>',
          'CAMPO_TESTE_ALERGIA',
          'CAMPO_TESTE_HIPOTESE'
        ]) {
          expect(find.text(value), findsWidgets);
        }
        expect(find.text('⚠ ALÉRGICOS'), findsOneWidget);
        final hint = find
            .text('PDF abre janela de impressão  •  PNG salva imagem da HC');
        await tester.ensureVisible(hint);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(hint);
        expect(bounds.left, greaterThanOrEqualTo(0));
        expect(bounds.right, lessThanOrEqualTo(width));
        expect(bounds.height, greaterThan(0));
        expect(find.byType(RepaintBoundary), findsWidgets);
        expect(find.text('Copiar HC'), findsOneWidget);
        expect(provider.myHistories.single.toJson(), original);
        {
          final exception = tester.takeException();
          if (exception is FlutterError) {
            debugPrint(exception.toStringDeep());
          }
          expect(exception, isNull);
        }
        // Use the real detail-to-editor callback without a save or remote write.
        await tester.tap(find.byIcon(Icons.edit_rounded).last);
        await tester.pumpAndSettle();
        expect(HistoryScreen.editorActive.value, isTrue);
        expect(
            tester
                .widgetList<TextField>(find.byType(TextField))
                .any((field) => field.controller?.text == 'CAMPO_TESTE'),
            isTrue);
        await tester.tap(find.text('Ver'));
        await tester.pumpAndSettle();
        expect(find.text('PRÉ-VISUALIZAÇÃO'), findsOneWidget);
        for (final value in [
          'CAMPO_TESTE <&>',
          'CAMPO_TESTE_ALERGIA',
          'CAMPO_TESTE_HIPOTESE'
        ]) {
          expect(find.text(value), findsWidgets);
        }
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        expect(provider.myHistories.single.toJson(), original);
        {
          final exception = tester.takeException();
          if (exception is FlutterError) {
            debugPrint(exception.toStringDeep());
          }
          expect(exception, isNull);
        }
      });
    }
  }
}
