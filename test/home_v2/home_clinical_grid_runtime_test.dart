import 'package:flutter_test/flutter_test.dart';
import 'home_clinical_grid_runtime_harness.dart';

void main() {
  for (final dark in [false, true]) {
    for (final isEs in [false, true]) {
      testWidgets(
          'productive clinical grid preserves geometry/assets/actions $dark/$isEs',
          (tester) => verifyClinicalGrid(tester, dark: dark, isEs: isEs));
    }
  }
}
