import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/internacion/services/'
    'internacion_firestore_service.dart';

String _methodSlice(String source, String marker) {
  final markerIndex = source.indexOf(marker);
  expect(markerIndex, greaterThanOrEqualTo(0), reason: marker);
  final signatureOpen = source.indexOf('(', markerIndex);
  expect(signatureOpen, greaterThanOrEqualTo(0), reason: marker);

  var parenDepth = 0;
  var signatureClose = -1;
  for (var index = signatureOpen; index < source.length; index++) {
    if (source[index] == '(') parenDepth++;
    if (source[index] == ')') {
      parenDepth--;
      if (parenDepth == 0) {
        signatureClose = index;
        break;
      }
    }
  }
  expect(signatureClose, greaterThan(signatureOpen), reason: marker);

  final opening = source.indexOf('{', signatureClose);
  expect(opening, greaterThan(signatureClose), reason: marker);
  var depth = 0;
  for (var index = opening; index < source.length; index++) {
    if (source[index] == '{') depth++;
    if (source[index] == '}') {
      depth--;
      if (depth == 0) return source.substring(markerIndex, index + 1);
    }
  }
  fail('Método não fechado: $marker');
}

void main() {
  group('V1-K-R2-R3 — mesma fonte visual real', () {
    test('Pacientes e Ferramentas consomem sessionsStream(uid)', () {
      final patients = File(
        'lib/screens/internacion/internacion_screen.dart',
      ).readAsStringSync();
      final tools = File(
        'lib/screens/tools_patient_import.dart',
      ).readAsStringSync();

      final patientsOwner = _methodSlice(patients, 'void _initSessions()');
      final toolsOwner = _methodSlice(tools, 'Future<void> _loadSessions()');

      expect(
        patientsOwner,
        contains('InternacionFirestoreService.sessionsStream(uid)'),
      );
      expect(
        toolsOwner,
        contains('InternacionFirestoreService.sessionsStream(uid)'),
      );
    });

    test('Ferramentas não usa loadAllSessions nem projeção paralela', () {
      final source = File(
        'lib/screens/tools_patient_import.dart',
      ).readAsStringSync();
      final owner = _methodSlice(source, 'Future<void> _loadSessions()');

      expect(
        RegExp(
          r'InternacionFirestoreService\s*\.\s*loadAllSessions\s*\(',
        ).hasMatch(owner),
        isFalse,
      );
      expect(source, isNot(contains('canonicalToolsPatients')));
      expect(owner, contains('_sessions = patientsSessions;'));
      expect(owner, contains('.firstWhere('));
    });
  });

  group('R1 writeback seguro preservado', () {
    test('exige importado, nome e chave idêntica', () {
      expect(
        InternacionFirestoreService.canWriteToolsResults(
          hasImportedPatient: true,
          patientName: 'Ana',
          importedPatientKey: 'patient-001',
          patientKey: 'patient-001',
        ),
        isTrue,
      );
      expect(
        InternacionFirestoreService.canWriteToolsResults(
          hasImportedPatient: true,
          patientName: 'Ana',
          importedPatientKey: 'patient-001',
          patientKey: 'patient-999',
        ),
        isFalse,
      );
      expect(
        InternacionFirestoreService.canWriteToolsResults(
          hasImportedPatient: false,
          patientName: 'Ana',
          importedPatientKey: 'patient-001',
          patientKey: 'patient-001',
        ),
        isFalse,
      );
    });

    test('atualiza documento existente sem set/add/delete', () {
      final source = File(
        'lib/screens/internacion/services/'
        'internacion_firestore_service.dart',
      ).readAsStringSync();
      final owner = _methodSlice(
        source,
        'static Future<void> updatePatientLaboratories',
      );

      expect(owner, contains('required PacienteSession? importedSession'));
      expect(owner, contains('canWriteToolsResults('));
      expect(owner, contains('.doc(patientKey.trim()).update(payload)'));
      expect(owner, isNot(contains('.set(')));
      expect(owner, isNot(contains('.add(')));
      expect(owner, isNot(contains('.delete(')));
    });

    test('quatro ferramentas entregam activeImportedSession', () {
      const paths = <String>[
        'lib/screens/hepatology_tools_screen.dart',
        'lib/screens/nephrology_tools_screen.dart',
        'lib/screens/cardio_tools_screen.dart',
        'lib/screens/electrolytes_tools_screen.dart',
      ];
      for (final path in paths) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains(
            'importedSession: '
            'context.read<AppProvider>().activeImportedSession',
          ),
          reason: path,
        );
      }
    });
  });

  test('nenhum owner R2-R3 apaga registros desconhecidos', () {
    final paths = <String>[
      'lib/screens/tools_patient_import.dart',
      'lib/screens/internacion/services/'
          'internacion_firestore_service.dart',
    ];
    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('[V1-K-R2-R3].delete(')), reason: path);
      expect(source, isNot(contains('[V1-K-R2-R3] softDelete(')), reason: path);
    }
  });
}
