import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('R13 MedInput dependency closure exposes canonical History parameters', () {
    final common = File('lib/widgets/common_widgets.dart').readAsStringSync();

    expect(common, contains('class MedInput extends StatelessWidget'));
    expect(common, contains('final bool clinicalCompact;'));
    expect(common, contains('final IconData? prefixIcon;'));
    expect(common, contains('this.clinicalCompact = false'));
    expect(common, contains('this.prefixIcon'));
    expect(common, contains('HISTORY_CLINICAL_V1_C_R8_COMMON_MEDINPUT'));
    expect(common, contains('MediaQuery.of(context).viewInsets.bottom + 88'));
  });

  test('R13 pediatric clinical foundation dependency files are published', () {
    for (final path in <String>[
      'lib/data/pediatrics/pediatric_growth_engine_v2026.dart',
      'lib/data/pediatrics/pediatric_pews_engine_v2026.dart',
      'lib/data/pediatrics/pediatric_reference_registry_v2026.dart',
      'lib/data/pediatrics/pediatric_renal_engine_v2026.dart',
      'lib/data/pediatrics/who_growth_lms_v2026.dart',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });

  test('R13 Tools remains bound to canonical pediatric engine imports', () {
    final tools = File('lib/screens/tools_screen.dart').readAsStringSync();

    for (final token in <String>[
      "../data/pediatrics/pediatric_growth_engine_v2026.dart",
      "../data/pediatrics/pediatric_pews_engine_v2026.dart",
      "../data/pediatrics/pediatric_reference_registry_v2026.dart",
      "../data/pediatrics/pediatric_renal_engine_v2026.dart",
      'PediatricGrowthEngineV2026',
      'PediatricRenalEngineV2026',
      'BrightonPewsEngineV2026',
      'PediatricReferenceRegistryV2026',
    ]) {
      expect(tools, contains(token), reason: token);
    }
  });

  test('R13 keeps audio production cutover closed', () {
    final consent = File(
      'lib/services/audio/clinical_long_form_remote_audio_consent_store.dart',
    ).readAsStringSync();
    final policy = File(
      'lib/services/audio/clinical_long_form_remote_transcription_policy.dart',
    ).readAsStringSync();

    expect(consent, contains('productionCallsiteWired = false'));
    expect(policy, contains('realPatientAudioAllowed = false'));
  });
}
