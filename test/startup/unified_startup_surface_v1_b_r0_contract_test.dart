import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MEDCASES_UNIFIED_STARTUP_SURFACE_IOS_ANDROID_V1_B_R0', () {
    test('Flutter Splash 2 visual owner is preserved', () {
      final main = File('lib/main.dart').readAsStringSync();

      expect(main, contains('class _SplashScreen extends StatefulWidget'));
      expect(main, contains("backgroundColor: const Color(0xFF0F1116)"));
      expect(main, contains("'assets/icon/splash_mplus_premium.png'"));
      expect(main, contains("'MedCases Pro'"));
      expect(main, contains("'IA Clínica de bolso'"));
      expect(main, contains('class _SplashLoadingIndicator'));
      expect(main, contains('CircularProgressIndicator('));

      // Premium M+ entry is the approved Flutter Splash 2 motion.
      expect(
        main,
        contains('duration: const Duration(milliseconds: 1450)'),
      );
      expect(main, contains('Tween<double>(begin: 0.82, end: 1.0)'));
      expect(
        main,
        contains(
            "Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)"),
      );

      // Native surface is removed only after Flutter has painted a frame.
      expect(
        main,
        contains('MEDCASES_SPLASH_NATIVE_TO_FLUTTER_VISUAL_READY_HANDOFF_V1_B_R0'),
      );
      expect(
        main,
        contains('WidgetsBinding.instance.addPostFrameCallback'),
      );
      expect(main, contains('FlutterNativeSplash.remove();'));
    });

    test('flutter_native_splash remains blank dark native stage', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();

      expect(pubspec, contains('flutter_native_splash:'));
      expect(pubspec, contains('color: "#0F1116"'));
      expect(
        pubspec,
        contains('image: assets/icon/splash_native_transparent.png'),
      );
      expect(pubspec, contains('android_12:'));
      expect(
        pubspec,
        contains('icon_background_color: "#0F1116"'),
      );
    });

    test('iOS launch fallback is the canonical dark background', () {
      final storyboard = File(
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
      ).readAsStringSync();

      expect(
        storyboard,
        contains(
          '<color key="backgroundColor" '
          'red="0.0588235294" '
          'green="0.0666666667" '
          'blue="0.0862745098" '
          'alpha="1" colorSpace="custom" customColorSpace="sRGB"/>',
        ),
      );
      expect(storyboard, contains('image="LaunchBackground"'));
      expect(storyboard, contains('image="LaunchImage"'));
    });

    test('Android normal windows cannot flash system light background', () {
      const files = <String>[
        'android/app/src/main/res/values/styles.xml',
        'android/app/src/main/res/values-night/styles.xml',
        'android/app/src/main/res/values-v31/styles.xml',
        'android/app/src/main/res/values-night-v31/styles.xml',
      ];

      for (final path in files) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains(
            '<item name="android:windowBackground">#0F1116</item>',
          ),
          reason: path,
        );
        expect(
          source,
          isNot(contains(
            '<item name="android:windowBackground">'
            '?android:colorBackground</item>',
          )),
          reason: path,
        );
      }
    });
  });
}
