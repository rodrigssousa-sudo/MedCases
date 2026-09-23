import 'package:flutter_test/flutter_test.dart';
import 'home_composition_runtime_harness.dart';

void main() {
  testWidgets('current Home composition retains both clinical groups and route',
      verifyHomeComposition);
}
