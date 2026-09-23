import 'package:flutter_test/flutter_test.dart';
import 'tools_hub_runtime_harness.dart';

void main() {
  for (final dark in [false, true]) {
    for (final es in [false, true]) {
      testWidgets('specialty hub colors geometry and routes dark=$dark es=$es',
          (tester) => verifyToolsHub(tester, dark: dark, isEs: es));
    }
  }
}
