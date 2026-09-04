import 'dart:io';
import 'package:test/test.dart';

void main() {
  final file = File('lib/screens/history_screen.dart').readAsStringSync();

  test('mic control bar has light expanded palette locals', () {
    expect(file.contains('micLightPrimaryText'), isTrue);
    expect(file.contains('micLightFieldSurface'), isTrue);
  });

  test('lab and ecg have light clinical input surface', () {
    expect(file.contains('lightClinicalInputSurface'), isTrue);
  });
}
