import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final main = File('lib/main.dart').readAsStringSync();
  final wa = File('lib/screens/ai/widgets/wa_header.dart').readAsStringSync();
  final home = File('lib/screens/home_screen.dart').readAsStringSync();

  test('R15 keeps the R14 40/60 shell and calculator confinement', () {
    expect(main, contains('flex: 40'));
    expect(main, contains('flex: 60'));
    expect(main, contains('key: ValueKey<int>(leftPaneIndex)'));
    expect(main, contains('_staticScreens[2]'));
    expect(home, contains('rootNavigator: !kIsWeb'));
  });

  test('R15 Home web topbar is a real full-width 48px canonical surface', () {
    final start = main.indexOf('class _WebWorkspaceBrandBar');
    expect(start, greaterThanOrEqualTo(0));

    final owner = main.substring(start);

    expect(owner, contains('width: double.infinity'));
    expect(owner, contains('height: 48'));
    expect(owner, contains('ImageFilter.blur(sigmaX: 14, sigmaY: 14)'));
    expect(owner, contains('const Color(0xFF252930).withOpacity(0.70)'));
    expect(owner, contains('Colors.white.withOpacity(0.70)'));
    expect(owner, contains('const Color(0xFF374151)'));
    expect(owner, contains('const Color(0xFFE2E7EC)'));
    expect(owner, contains('width: 0.7'));
    expect(owner, contains("text: 'MEDCASES'"));
    expect(owner, contains("text: ' PRO'"));
  });

  test('R15 AI web topbar shares the canonical Home/mobile surface', () {
    expect(wa, contains('width: double.infinity'));
    expect(wa, contains('height: 48'));
    expect(wa, contains('ImageFilter.blur(sigmaX: 14, sigmaY: 14)'));
    expect(wa, contains('const Color(0xFF252930).withOpacity(0.70)'));
    expect(wa, contains('Colors.white.withOpacity(0.70)'));
    expect(wa, contains('const Color(0xFF374151)'));
    expect(wa, contains('const Color(0xFFE2E7EC)'));
    expect(wa, contains('width: 0.7'));
    expect(wa, contains("text: 'MEDCASES'"));
    expect(wa, contains("text: ' IA'"));
  });

  test('R15-R2 keeps glass transparency as an explicit mandatory contract', () {
    final homeStart = main.indexOf('class _WebWorkspaceBrandBar');
    expect(homeStart, greaterThanOrEqualTo(0));
    final homeOwner = main.substring(homeStart);

    for (final owner in <String>[homeOwner, wa]) {
      expect(owner, contains('const Color(0xFF252930).withOpacity(0.70)'));
      expect(owner, contains('Colors.white.withOpacity(0.70)'));
      expect(owner, contains('ImageFilter.blur(sigmaX: 14, sigmaY: 14)'));
      expect(owner, contains('ClipRect('));
      expect(owner, contains('BackdropFilter('));
      expect(owner, contains('width: double.infinity'));
      expect(owner, contains('height: 48'));
    }

    // R15-R2: #0C0E12 may legitimately exist as text/badge foreground.
    // The topbar surface itself must be owned by `color: glass`.
    expect(homeOwner, contains('color: glass,'));

    final waHeaderStart = wa.indexOf('class WaHeader');
    expect(waHeaderStart, greaterThanOrEqualTo(0));
    final waHeaderOwner = wa.substring(waHeaderStart);
    expect(waHeaderOwner, contains('color: glass,'));

    final legacySolidSurface = RegExp(
      r'decoration\s*:\s*(?:const\s+)?BoxDecoration\s*\('
      r'[\s\S]{0,220}?color\s*:\s*(?:const\s+)?Color\(0xFF0C0E12\)',
    );
    expect(legacySolidSurface.hasMatch(homeOwner), isFalse);
    expect(legacySolidSurface.hasMatch(waHeaderOwner), isFalse);
  });

  test('R15-R2 web terminal auth states release TimedSplash', () {
    final start = main.indexOf(
      'Widget _buildWebAuthGate(BuildContext context)',
    );
    expect(start, greaterThanOrEqualTo(0));
    final end = main.indexOf(
      '\n  @override\n  Widget build(BuildContext context)',
      start,
    );
    expect(end, greaterThan(start));
    final gate = main.substring(start, end);

    expect(gate, contains('return _wrapAuth(const PreLoginPreview());'));
    expect(gate, contains('return _wrapAuth(_BlockedScreen(user: user));'));
    expect(gate, contains('return _wrapAuth(_PendingScreen(user: user));'));
    expect(
      RegExp(r'_signalSplashReady\(context\);').allMatches(gate).length,
      3,
    );

    // Approved users keep the already-homologated owner.
    expect(gate, contains('_onUserResolved(user);'));
    expect(gate, contains('return _WebMainShellGate(user: user);'));
  });

  test('R15-R2 preserves non-circular TimedSplash handoff contract', () {
    expect(main, contains('bool get _ready => _minTimeDone && _bootDone;'));
    expect(main, contains('if (_authResolved && !_handoffScheduled)'));
    expect(
      main,
      contains('Future<void> _releaseSplashAfterContentPaint() async'),
    );
    expect(main, contains('static const _kWatchdogMs = 20000;'));
  });

  test('R15 hamburger opens the real MainShell drawer', () {
    expect(main, contains('endDrawer: _AppDrawer(p: p)'));
    expect(wa, contains('Scaffold.maybeOf(context)?.openEndDrawer()'));

    expect(
      RegExp(
        r"tooltip:\s*(?:lang\s*==[\s\S]{0,100})?'Menu'"
        r"[\s\S]{0,160}onTap:\s*onSettings",
      ).hasMatch(wa),
      isFalse,
    );
  });

  test('R15 keeps M+ as the AI settings owner', () {
    expect(
      RegExp(r"tooltip:\s*'M\+'[\s\S]{0,120}onTap:\s*onSettings").hasMatch(wa),
      isTrue,
    );
  });

  test('R15 preserves AI actions and back affordance', () {
    for (final token in <String>[
      'onTap: onHistory',
      'onTap: onNewChat',
      'onTap: onSettings',
      'Navigator.maybePop(context)',
      'historyCount > 0',
      'modeConfirmed',
      'onModeTap',
      'isPartner',
      'onAmbassador',
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
