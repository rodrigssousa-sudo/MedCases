import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync();

void main() {
  late String history;
  late String recorder;

  setUpAll(() {
    history = read('lib/screens/history_screen.dart');
    recorder = read('lib/screens/clinical_recorder_sheet.dart');
  });

  test('editor manual possui shell light sem remover contratos anteriores', () {
    expect(
      history,
      contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R11_R2_MANUAL_LIGHT_SHELL'),
    );
    expect(history, contains('manualShellBackground'));
    expect(history, contains('const Color(0xFFECF1F3)'));
    expect(history, contains('const Color(0xFFD8E0E7)'));
    expect(history, contains('const Color(0xFF05070A)'));
    expect(history, contains('onTap: widget.onCancel'));
    expect(history, contains('onTap: _showPreview'));
    expect(history, contains('onTap: _save'));
  });

  test('gravador SOAP possui shell light e mantém fluxo de áudio', () {
    expect(
      recorder,
      contains('HISTORY_CLINICAL_INTERNAL_TABS_V1_C_R11_R2_SOAP_LIGHT_SHELL'),
    );
    expect(recorder, contains('soapShellBackground'));
    expect(
      RegExp(r'\bsoapShellPrimary\b').allMatches(recorder).length,
      greaterThanOrEqualTo(2),
    );
    expect(recorder, isNot(contains('soapShellSecondary')));
    expect(recorder, contains('foregroundColor: soapShellPrimary'));
    expect(recorder, contains('soapShellDivider'));
    expect(recorder, contains('_currentBlock'));
    expect(recorder, contains('_finishRecording'));
    expect(recorder, contains('ClinicalRecorderService'));
    expect(recorder, contains('RecorderMode.soapBlocks'));
    expect(recorder, contains('onSoapData'));
  });

  test('dark e cores semânticas permanecem', () {
    expect(history, contains('Color(0xFF1A1D23)'));
    expect(recorder, contains('Color(0xFF1A1D23)'));
    expect(history, contains('Color(0xFF10B981)'));
    expect(recorder, contains('Color(0xFF10B981)'));
    expect(recorder, contains('Color(0xFFEF4444)'));
  });
}
