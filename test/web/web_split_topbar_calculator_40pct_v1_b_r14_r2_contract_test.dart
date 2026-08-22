import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final home = File('lib/screens/home_screen.dart').readAsStringSync();
  final wa = File('lib/screens/ai/widgets/wa_header.dart').readAsStringSync();
  test('40/60 AI persists', () {
    expect(main, contains('showPersistentAiSplit = width >= 1024'));
    expect(main, contains('flex: 40'));
    expect(main, contains('flex: 60'));
    expect(main, contains('_staticScreens[2]'));
  });
  test('left web workspace nested navigator', () {
    expect(main, contains('key: ValueKey<int>(leftPaneIndex)'));
    expect(main, contains('_WebWorkspaceBrandBar(dark: dark)'));
  });
  test('same exact 48px black topbar pattern', () {
    expect(main, contains('class _WebWorkspaceBrandBar'));
    expect(main, contains('color: Color(0xFF0C0E12)'));
    expect(main, contains('height: 48'));
    expect(wa, contains('color: Color(0xFF0C0E12)'));
    expect(wa, contains('height: 48'));
  });
  test('brands centered and AI sides preserved', () {
    expect(main, contains("text: 'MEDCASES'"));
    expect(main, contains("text: ' PRO'"));
    expect(wa, contains('alignment: Alignment.centerLeft'));
    expect(wa, contains('alignment: Alignment.centerRight'));
    expect(wa, contains("text: 'MEDCASES'"));
    expect(wa, contains("text: ' IA'"));
  });
  test('R14-R1 calculator root route becomes platform scoped', () {
    expect(home, contains('rootNavigator: !kIsWeb'));
    expect(
      RegExp(
        r'Navigator\.of\(context,\s*rootNavigator:\s*true\)[\s\S]{0,500}CalculadoraScreen\(',
      ).hasMatch(home),
      isFalse,
    );
  });
  test('R14-R2 RichText parents are not illegally const', () {
    final homeHeader = main.substring(
      main.indexOf('class _WebWorkspaceBrandBar'),
    );
    expect(homeHeader, isNot(contains('child: const Stack(')));
    expect(
      wa,
      isNot(contains('const IgnorePointer(\n            child: RichText(')),
    );
  });

  test('AI callbacks preserved', () {
    for (final token in <String>[
      'onTap: onHistory',
      'onTap: onNewChat',
      'onTap: onSettings',
      'historyCount > 0',
      'isConnected',
    ]) {
      expect(wa, contains(token), reason: token);
    }
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
