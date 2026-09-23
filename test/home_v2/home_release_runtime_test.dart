import 'package:flutter_test/flutter_test.dart';
import 'home_release_runtime_harness.dart';

void main() {
  for (final dark in [false, true]) {
    for (final language in ['pt', 'es']) {
      testWidgets('real Timer controls and palette $dark/$language',
          (tester) => verifyRealTimer(tester, dark: dark, language: language));
    }
  }
  for (final module in [false, true]) {
    testWidgets('real patient root route through Home module=$module',
        (tester) => verifyRealPatientRoute(tester, module: module));
  }
}
