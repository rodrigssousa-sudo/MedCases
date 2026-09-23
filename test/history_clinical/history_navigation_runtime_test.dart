import 'package:flutter_test/flutter_test.dart';
import 'history_release_runtime_harness.dart';

void main() {
  testWidgets('saved History list retains flat semantic surface',
      verifyHistoryListSurface);
  testWidgets(
      'exam numeric palette retains dark semantics', verifyHistoryExamPalette);
  testWidgets('OCR public entry opens current picker', verifyHistoryOcrPicker);
  testWidgets(
      'numeric keyboard next and done use actual focus', verifyHistoryKeyboard);
  for (final dark in [false, true]) {
    for (final lang in ['pt', 'es']) {
      testWidgets('current equal history tabs $lang dark=$dark',
          (tester) async {
        await verifyHistoryNavigation(tester, dark: dark, language: lang);
      });
    }
  }
}
