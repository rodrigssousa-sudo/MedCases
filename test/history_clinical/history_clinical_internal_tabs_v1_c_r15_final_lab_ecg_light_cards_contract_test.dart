import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String classSlice(String source, String name) {
  final start = source.indexOf('class $name');
  expect(start, isNonNegative, reason: '$name ausente');
  final next = source.indexOf('\nclass ', start + 7);
  return source.substring(start, next < 0 ? source.length : next);
}

void main() {
  late String history;
  setUpAll(() =>
      history = File('lib/screens/history_screen.dart').readAsStringSync());

  test('Lab e ECG possuem branches light explícitos e dark preservado', () {
    for (final owner in [
      '_LabStructuredWidgetState',
      '_EcgStructuredWidgetState'
    ]) {
      final block = classSlice(history, owner);
      expect(block, contains('r15ExamDark'));
      expect(block, contains('Colors.white'));
      expect(block, contains('Color(0xFF05070A)'));
      expect(block, contains('Color(0xFF4B5563)'));
      expect(block, contains('Brightness.dark'));
    }
  });

  test('card OCR/IA e fluxos clínicos permanecem', () {
    expect(history, contains('class _OcrExamButton'));
    expect(history, contains('_openOcrPicker'));
    expect(history, contains('TextEditingController'));
    expect(history, contains('RepaintBoundary'));
  });
}
