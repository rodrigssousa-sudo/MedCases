import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String mainSource;
  late String notes;
  late String patientImport;
  late String internacion;
  late String copilot;
  late String revision;
  late String soapPlan;
  late String soapSubjetivo;
  late String soapEvaluacion;
  late String soapSection;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
    notes = File('lib/screens/notes_screen.dart').readAsStringSync();
    patientImport =
        File('lib/screens/tools_patient_import.dart').readAsStringSync();
    internacion = File('lib/screens/internacion/internacion_screen.dart')
        .readAsStringSync();
    copilot = File(
      'lib/screens/internacion/components/copilot_button.dart',
    ).readAsStringSync();
    revision = File(
      'lib/screens/internacion/components/revision_sheet.dart',
    ).readAsStringSync();
    soapPlan = File(
      'lib/screens/internacion/components/soap/soap_plan.dart',
    ).readAsStringSync();
    soapSubjetivo = File(
      'lib/screens/internacion/components/soap/soap_subjetivo.dart',
    ).readAsStringSync();
    soapEvaluacion = File(
      'lib/screens/internacion/components/soap/soap_evaluacion.dart',
    ).readAsStringSync();
    soapSection = File(
      'lib/screens/internacion/components/soap/soap_section.dart',
    ).readAsStringSync();
  });

  test('Main light brand/focus/navigation generic green is canonical', () {
    expect(mainSource, contains('secondary: Color(0xFF0D6B57),'));
    expect(
      mainSource,
      contains(
        "iconColor: const Color(0xFF0D6B57),\n          title: isEs ? 'Nueva Consulta' : 'Nova Consulta',",
      ),
    );

    // Semantic update-dialog green remains; NotesAudioWorkspace brand advanced in Batch 5F.
    expect(
      mainSource,
      contains('static const _kGreen = Color(0xFF10B981);'),
    );
    expect(
      mainSource,
      contains(
        'final text = dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);',
      ),
    );
  });

  test('Notes generic surfaces canonicalize but loading state stays green', () {
    expect(
      notes,
      contains(
          'CircularProgressIndicator(\n                      color: Color(0xFF10B981), strokeWidth: 2)'),
    );
    expect(
      notes,
      contains('backgroundColor: const Color(0xFF0D6B57)'),
    );
    expect(notes, contains('Color(0xFF0D6B57).withOpacity(0.35)'));
  });

  test('Patient Import local generic accent is canonical', () {
    expect(patientImport, contains('const accent = Color(0xFF0D6B57);'));
    expect(
      patientImport,
      contains('const _kAccentBrand = Color(0xFF0D6B57);'),
    );
  });

  test('Internacion copy UI canonicalizes without flattening taxonomy', () {
    expect(
      internacion,
      contains('iconColor: const Color(0xFF0D6B57),'),
    );
    expect(
      internacion,
      contains('badgeColor: const Color(0xFF0D6B57),'),
    );

    // Fármacos taxonomy is intentionally green.
    expect(
      internacion,
      contains(
        "addSection('Fármacos', Icons.medication_rounded, const Color(0xFF059669));",
      ),
    );

    // Primary mixed control remains pending token split.
    expect(
      internacion,
      contains('const Color(0xFF10B981).withOpacity(0.72)'),
    );
  });

  test('Copilot and revision generic gradients use canonical accent', () {
    expect(copilot, isNot(contains('Color(0xFF059669), Color(0xFF047857)')));
    expect(
      copilot,
      contains('Color(0xFF0D6B57), Color(0xFF0D6B57)'),
    );
    expect(revision, isNot(contains('Color(0xFF059669), Color(0xFF047857)')));
    expect(
      revision,
      contains('Color(0xFF0D6B57), Color(0xFF0D6B57)'),
    );
  });

  test('SOAP generic controls canonicalize while clinical outcomes stay', () {
    expect(
      soapPlan,
      contains('Icons.add_rounded, size: 12.5, color: Color(0xFF0D6B57)'),
    );

    expect(
      RegExp(r'const accent = Color\(0xFF0D6B57\);')
          .allMatches(soapSubjetivo)
          .length,
      2,
    );
    expect(
      soapSubjetivo,
      contains('if (v <= 3) return const Color(0xFF10B981);'),
    );

    expect(
      soapEvaluacion,
      contains('Icons.add_rounded, size: 18, color: Color(0xFF0D6B57)'),
    );
    expect(
      soapEvaluacion,
      contains('Color(0xFF10B981),'),
    );

    expect(
      soapSection,
      contains('badgeColor: const Color(0xFF0D6B57),'),
    );
  });
}
