import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('ActionButtonsRow transports typed continuation metadata', () {
    final source = File('lib/screens/ai/widgets/action_buttons_row.dart').readAsStringSync();
    expect(source, contains('PlantaoContinuationType continuationType'));
    expect(source, contains('List<PlantaoSection> requestedSections'));
    expect(source, contains(': action.continuationType'));
    expect(source, contains(': action.requestedSections'));
  });
}
