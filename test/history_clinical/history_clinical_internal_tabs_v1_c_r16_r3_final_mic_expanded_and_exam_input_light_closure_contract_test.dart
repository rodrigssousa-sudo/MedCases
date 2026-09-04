import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/screens/history_screen.dart').readAsStringSync();

  test('MicControlBar title consumes approved adaptive primary token', () {
    expect(source.contains('HISTORY_CLINICAL_V1_C_R16_R3_MIC_EXPANDED_LIGHT_FINAL'), isTrue);
    expect(source.contains('Ditado e IA'), isTrue);
    expect(source.contains('color: micPrimary'), isTrue);
  });

  test('Lab and ECG neutral-dark field surfaces gain inline light branch', () {
    expect(source.contains('HISTORY_CLINICAL_V1_C_R16_R3_EXAM_INPUTS_LIGHT_FINAL _LabStructuredWidgetState'), isTrue);
    expect(source.contains('HISTORY_CLINICAL_V1_C_R16_R3_EXAM_INPUTS_LIGHT_FINAL _EcgStructuredWidgetState'), isTrue);
    expect(source.contains('Theme.of(context).brightness == Brightness.dark'), isTrue);
    expect(source.contains('const Color(0xFFF8FAFC)'), isTrue);
  });

  test('failed R16 local identifiers are absent', () {
    expect(source.contains('micLightPrimaryText'), isFalse);
    expect(source.contains('lightClinicalInputSurface'), isFalse);
  });
}
