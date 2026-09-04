import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS owns system background URLSession transfer', () {
    final source = File('ios/Runner/AppDelegate.swift').readAsStringSync();

    for (final marker in <String>[
      'medcases/study_background_transcription_v1',
      'URLSessionConfiguration.background(withIdentifier:',
      'sessionSendsLaunchEvents = true',
      'waitsForConnectivity = true',
      'httpMaximumConnectionsPerHost = 2',
      'handleEventsForBackgroundURLSession',
      'uploadTask(',
    ]) {
      expect(source, contains(marker), reason: marker);
    }
  });

  test('Android 24+ owns foreground data-sync transcription', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final service = File(
      'android/app/src/main/kotlin/com/medcasespro/med/'
      'MedCasesStudyBackgroundTranscriptionService.kt',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_DATA_SYNC'),
    );
    expect(manifest, contains('android:foregroundServiceType="dataSync"'));
    expect(service, contains('FOREGROUND_SERVICE_TYPE_DATA_SYNC'));
    expect(service, contains('START_REDELIVER_INTENT'));
    expect(service, contains('uploadWithRetry('));
  });

  test('Dart uses capability probe with safe foreground fallback', () {
    final source = File(
      'lib/services/study/study_background_transcription_coordinator.dart',
    ).readAsStringSync();

    for (final marker in <String>[
      '/api/ai/study/background-transcription/capabilities',
      '/api/ai/study/background-transcription/jobs',
      "MethodChannel('medcases/study_background_transcription_v1')",
      'foreground fallback',
      'FirebaseAuth.instance.currentUser',
      'awaitTranscript',
      'cleanup()',
    ]) {
      expect(source, contains(marker), reason: marker);
    }
  });

  test('both imported and recorded segmented flows are wired', () {
    final imported = File(
      'lib/services/study/study_imported_audio_pipeline_io.dart',
    ).readAsStringSync();
    final recorded =
        File('lib/screens/study_workspace_screen.dart').readAsStringSync();

    expect(
      imported,
      contains('StudyBackgroundTranscriptionCoordinator.tryStart'),
    );
    expect(imported, contains('backgroundSession: backgroundSession'));
    expect(
      recorded,
      contains('StudyBackgroundTranscriptionCoordinator.tryStart'),
    );
    expect(recorded, contains('backgroundSession.awaitTranscript'));
  });
}
