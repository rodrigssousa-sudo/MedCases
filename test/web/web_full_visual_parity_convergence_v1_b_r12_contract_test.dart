import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web wide shell is 40/60 with fixed AI and no sidebar callsite', () {
    final main = File('lib/main.dart').readAsStringSync();

    expect(
      main,
      contains(
        'final bool useWideShell = kIsWeb ? width >= 1024 : width >= 768;',
      ),
    );
    expect(main, contains('showPersistentAiSplit = width >= 1024'));
    expect(main, contains('flex: 40'));
    expect(main, contains('flex: 60'));
    expect(main, contains('_staticScreens[leftPaneIndex]'));
    expect(main, contains('_staticScreens[2]'));
    expect(main, contains('class _DesktopSidebar'));
    expect(main, contains('if (!kIsWeb) SafeArea('));
  });

  test('web bootstrap splash uses M+ premium and canonical copy', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('icons/splash_mplus_premium.png'));
    expect(html, contains('id="loading-sub">IA Clínica de bolso</div>'));
    expect(
      File('web/icons/splash_mplus_premium.png').existsSync(),
      isTrue,
    );
  });

  test('Flutter premium splash assets are published', () {
    expect(
      File('assets/icon/splash_mplus_premium.png').existsSync(),
      isTrue,
    );
    expect(
      File('assets/icon/splash_native_transparent.png').existsSync(),
      isTrue,
    );
  });

  test('audio production cutover remains closed', () {
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
