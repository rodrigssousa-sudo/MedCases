import 'package:medcases/services/audio/recording_deletion_store.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/screens/study_workspace_screen.dart';
import 'package:medcases/services/study/study_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  setUpAll(() async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'registerIdTokenListener',
      'registerAuthStateListener'
    ]) {
      final channel = 'test.auth.$name';
      messenger.setMockMessageHandler(
          'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.$name',
          (_) async => const StandardMessageCodec().encodeMessage([channel]));
      messenger.setMockMethodCallHandler(
          MethodChannel(channel), (_) async => null);
    }
    await Firebase.initializeApp();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RecordingDeletionStore.ownerOverride = () => 'test';
  });
  tearDown(() => RecordingDeletionStore.ownerOverride = null);

  for (final es in [false, true]) {
    testWidgets('Cushing visual renders typed text and reloads $es',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final overview = es
          ? 'Revisión educativa del síndrome.'
          : 'Revisão educativa da síndrome.';
      final section = es ? 'Diagnóstico' : 'Diagnóstico';
      final study = Study(
          id: 'cushing',
          ownerUid: 'test',
          title: 'Cushing',
          locale: es ? 'es' : 'pt',
          createdAtUtc: DateTime.utc(2026),
          sources: [
            StudySource(
                id: 'source',
                type: StudySourceType.text,
                title: 'Fonte fictícia',
                text: 'Material fictício.',
                state: StudySourceState.accepted,
                createdAtUtc: DateTime.utc(2026))
          ],
          artifacts: [
            StudyArtifact(
                id: 'visual',
                type: StudyArtifactType.visualSummary,
                title: 'Visual',
                content: jsonEncode({
                  'title': 'Síndrome de Cushing',
                  'overview': overview,
                  'sections': [
                    {
                      'title': section,
                      'body': 'Exemplo sintético: 5 mg, 24 h, 2–4 mL.'
                    }
                  ]
                }),
                createdAtUtc: DateTime.utc(2026),
                sourceIds: ['source'])
          ]);
      final reloaded = await tester.runAsync(() async {
        await StudyLibraryService.save(study);
        return (await StudyLibraryService.loadAll()).single;
      });
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StudyWorkspaceScreen(isEs: es, initialStudy: reloaded))));
      await tester.pumpAndSettle();
      expect(find.text('Síndrome de Cushing'), findsOneWidget);
      expect(find.text(overview), findsOneWidget);
      expect(find.text(section), findsOneWidget);
      expect(
          find.text('Exemplo sintético: 5 mg, 24 h, 2–4 mL.'), findsOneWidget);
      expect(find.textContaining('"overview"'), findsNothing);
      expect(find.textContaining('"sections"'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
