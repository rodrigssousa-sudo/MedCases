import 'package:flutter_test/flutter_test.dart';
import 'architectural_runtime_harness.dart';

void main() {
  for (final dark in [false, true]) {
    for (final embedded in [false, true]) {
      testWidgets(
          'Tools real shell inset Material back embedded=$embedded dark=$dark',
          (t) => verifyToolsShell(t, dark: dark, embedded: embedded));
    }
  }
  for (final accept in [false, true]) {
    testWidgets('Study notice accept=$accept',
        (t) => verifyStudyNotice(t, accept: accept));
  }
  for (final dark in [false, true]) {
    testWidgets('Pediatric actual geometry dark=$dark',
        (t) => verifyPediatricGeometry(t, dark: dark));
  }
  for (final dark in [false, true]) {
    testWidgets('Adaptive productive inputs dark=$dark',
        (t) => verifyAdaptiveScoreInputs(t, dark: dark));
    testWidgets('History semantic outcomes dark=$dark',
        (t) => verifyHistoryOutcomePalette(t, dark: dark));
  }
  testWidgets(
      'Pediatric shell physical inset and callback', verifyPediatricShell);
  testWidgets('Mi Guardia never exposes forbidden pinned calculators',
      verifyGuardiaFilter);
}
