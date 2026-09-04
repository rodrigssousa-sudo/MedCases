import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS declares background audio without raising deployment target', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

    expect(info, contains('<key>UIBackgroundModes</key>'));
    expect(info, contains('<string>audio</string>'));
    expect(pbx, contains('IPHONEOS_DEPLOYMENT_TARGET = 16.0;'));
  });

  test('Android declares microphone foreground service on existing floor', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_MICROPHONE'),
    );
    expect(
      manifest,
      contains('android:foregroundServiceType="microphone"'),
    );
    expect(gradle, contains('minSdk = flutter.minSdkVersion'));
  });

  test('Android service is ongoing and microphone typed', () {
    final service = File(
      'android/app/src/main/kotlin/com/medcasespro/med/'
      'MedCasesRecordingForegroundService.kt',
    ).readAsStringSync();

    expect(service, contains('startForeground('));
    expect(
      service,
      contains('ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE'),
    );
    expect(service, contains('.setOngoing(true)'));
    expect(service, contains('START_NOT_STICKY'));
  });

  test('record provider owns foreground guard for start resume stop cancel',
      () {
    final provider = File(
      'lib/services/audio/record_long_form_audio_provider.dart',
    ).readAsStringSync();

    expect(
      provider,
      contains("MethodChannel('medcases/recording_background_guard_v1')"),
    );
    expect(provider, contains('await _beginPlatformBackgroundGuard();'));
    expect(provider, contains('await _endPlatformBackgroundGuard();'));
    expect(provider, contains('if (!Platform.isAndroid)'));
    expect(provider, contains('productionCutoverEnabled = false'));
    expect(provider, contains('remoteUploadEnabled = false'));
  });
}
