import 'package:flutter_test/flutter_test.dart';
import 'pediatric_navigation_runtime_harness.dart';

void main() {
  for (final dark in [false, true]) {
    for (final es in [false, true]) {
      testWidgets(
          'pediatric navigation and PEWS existing option callbacks dark=$dark es=$es',
          (tester) => verifyPediatricNavigation(tester, dark: dark, isEs: es));
    }
  }
}
