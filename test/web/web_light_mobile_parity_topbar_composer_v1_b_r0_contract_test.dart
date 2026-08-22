import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String main;
  late String composer;
  late String home;

  setUpAll(() {
    main = File('lib/main.dart').readAsStringSync();
    composer = File(
      'lib/screens/ai/widgets/prompt_composer.dart',
    ).readAsStringSync();
    home = File('lib/home_v2/home_screen_v2.dart').readAsStringSync();
  });

  test('Home 40 Light glass is composited on canonical mobile substrate', () {
    final start = main.indexOf('class _WebWorkspaceBrandBar');
    expect(start, greaterThanOrEqualTo(0));
    final owner = main.substring(start);
    for (final token in <String>[
      'MEDCASES_WEB_LIGHT_MOBILE_PARITY_SUBSTRATE_V1_B_R0',
      'dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3)',
      'color: substrate,',
      'Colors.white.withOpacity(0.70)',
      'const Color(0xFF252930).withOpacity(0.70)',
      'ImageFilter.blur(sigmaX: 14, sigmaY: 14)',
      'height: 48',
      'width: 0.7',
    ]) {
      expect(owner, contains(token), reason: token);
    }
  });

  test('AI Light composer consumes Home V2 mobile palette', () {
    for (final token in <String>[
      'MEDCASES_WEB_LIGHT_MOBILE_PARITY_COMPOSER_V1_B_R0',
      'final composerSurface = palette.surfaceSoft;',
      'final composerText = palette.textPrimary;',
      'final composerSecondary = palette.textSecondary;',
      'widget.hasFocus ? palette.borderActive : palette.border;',
      'color: composerSurface,',
      'color: composerBorder,',
      'color: locked ? disabledColor : composerText,',
      'color: locked ? disabledColor : composerSecondary,',
    ]) {
      expect(composer, contains(token), reason: token);
    }
    expect(
      composer,
      isNot(contains('dark ? palette.surfaceSoft : const Color(0xFF59636E)')),
    );
  });

  test('composer geometry and behavior owners remain present', () {
    for (final token in <String>[
      'filled: true,',
      'fillColor: Colors.transparent,',
      'BorderRadius.circular(24)',
      'minHeight: 50',
      'minLines: 1',
      'maxLines: 6',
      'AnimatedCrossFade(',
      'widget.onSend()',
      'widget.onVoice',
      'widget.onCancel',
      'widget.isConnected',
    ]) {
      expect(composer, contains(token), reason: token);
    }
  });

  test('previous 5px Home release remains intact', () {
    expect(home, contains('kIsWeb ? 5.0 : systemTopInset + 54.0'));
    expect(
      home,
      contains('MEDCASES_WEB_HOME_40_TOPBAR_TO_INLINE_AI_GAP_5PX_V1_B_R0'),
    );
  });
}
