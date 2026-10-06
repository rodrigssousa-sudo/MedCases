import 'package:medcases/services/audio/recording_deletion_store.dart';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/screens/study_workspace_screen.dart';
import 'package:medcases/services/study/study_library_service.dart';
import 'package:medcases/services/study/study_visual_result_codec.dart';
import 'package:medcases/services/study/study_artifact_generator.dart';
import 'package:medcases/services/ai_service.dart';
import 'package:medcases/services/ai/safety/clinical_safety_flow.dart';
import 'study_global_validation_regression_test.dart'
    show studyContext, nephroticAnswer;

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
    testWidgets('Study visual and complete labels use the active locale ($es)',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'flutter.medcases.study.educational_notice.v1.accepted': true,
        'medcases.study.educational_notice.v1.accepted': true
      });
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final study = Study(
          id: 'labels',
          sources: [
            StudySource(
                id: 'accepted-synthetic',
                type: StudySourceType.text,
                title: 'Synthetic',
                state: StudySourceState.accepted,
                text: 'Synthetic source.',
                createdAtUtc: DateTime.utc(2026))
          ],
          title: 'Synthetic',
          locale: 'pt-BR',
          createdAtUtc: DateTime.utc(2026),
          artifacts: [
            StudyArtifact(
                sourceIds: const ['accepted-synthetic'],
                id: 'v',
                type: StudyArtifactType.visualSummary,
                title: 'Resumo visual',
                content: jsonEncode({
                  'title': 'Synthetic',
                  'overview': 'Synthetic',
                  'sections': [],
                  'keyPoints': ['Synthetic'],
                  'takeaway': ''
                }),
                createdAtUtc: DateTime.utc(2026)),
            StudyArtifact(
                sourceIds: const ['accepted-synthetic'],
                id: 'f',
                type: StudyArtifactType.fullSummary,
                title: 'Resumo completo',
                content: 'Synthetic educational content.',
                createdAtUtc: DateTime.utc(2026)),
          ]);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StudyWorkspaceScreen(isEs: es, initialStudy: study))));
      await tester.pumpAndSettle();
      expect(find.text(es ? 'PUNTOS CLAVE' : 'PONTOS-CHAVE'), findsOneWidget);
      expect(find.text(es ? 'PONTOS-CHAVE' : 'PUNTOS CLAVE'), findsNothing);
      await tester.ensureVisible(find.text('Completo'));
      await tester.tap(find.text('Completo'));
      await tester.pumpAndSettle();
      expect(
          find.text(es ? 'Resumen completo' : 'Resumo completo'), findsWidgets);
      expect(
          find.text(es ? 'Resumo completo' : 'Resumen completo'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('recorded source displays duration, not citation offset ($es)',
        (tester) async {
      final source = StudySource(
          id: 'recording-synthetic',
          type: StudySourceType.recordedAudio,
          title: 'Synthetic',
          state: StudySourceState.accepted,
          createdAtUtc: DateTime.utc(2026),
          recordingSessionId: 'synthetic',
          audioDurationMs: 238347,
          text: 'Synthetic teaching transcript.',
          refs: const [
            SourceRef(
                sourceId: 'recording-synthetic',
                sourceType: StudySourceType.recordedAudio,
                timestampStartMs: 0)
          ]);
      final restored = (await tester.runAsync(() async {
        await StudyLibraryService.save(Study(
            id: 'synthetic',
            title: 'Synthetic',
            locale: es ? 'es' : 'pt',
            createdAtUtc: DateTime.utc(2026),
            sources: [source]));
        return (await StudyLibraryService.loadAll()).single.sources.single;
      }))!;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StudySourceRow(
                  source: restored,
                  isEs: es,
                  text: Colors.black,
                  sub: Colors.grey,
                  accent: Colors.teal,
                  onRename: null,
                  onAccept: null))));
      expect(find.text('${es ? 'Audio' : 'Áudio'} · 03:58'), findsOneWidget);
      expect(restored.refs.single.timestampStartMs, 0);
      expect(restored.text, source.text);
    });
    testWidgets(
        'legacy refusal offers localized regeneration, not export ($es)',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'medcases.study.educational_notice.v1.accepted': true,
      });
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const refusal =
          'Não há suporte verificável suficiente para apresentar esta resposta clínica com segurança.';
      final study = Study(
          id: 'failed-summary',
          title: 'Synthetic',
          locale: 'pt-BR',
          createdAtUtc: DateTime.utc(2026),
          sources: [
            StudySource(
                id: 'accepted-synthetic',
                type: StudySourceType.text,
                title: 'Synthetic',
                state: StudySourceState.accepted,
                text: 'Synthetic accepted teaching material.',
                createdAtUtc: DateTime.utc(2026)),
          ],
          artifacts: [
            for (final type in [
              StudyArtifactType.visualSummary,
              StudyArtifactType.fullSummary,
            ])
              StudyArtifact(
                  sourceIds: const ['accepted-synthetic'],
                  id: type.name,
                  type: type,
                  title: 'Resumo',
                  content: refusal,
                  createdAtUtc: DateTime.utc(2026)),
          ]);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StudyWorkspaceScreen(isEs: es, initialStudy: study))));
      await tester.pumpAndSettle();
      expect(find.text(refusal), findsNothing);
      expect(find.text(es ? 'Generar' : 'Gerar'), findsOneWidget);
      await tester.ensureVisible(find.text('Completo'));
      await tester.tap(find.text('Completo'));
      await tester.pumpAndSettle();
      expect(find.text(refusal), findsNothing);
      expect(find.text(es ? 'Generar' : 'Gerar'), findsOneWidget);
      final export = find.widgetWithText(TextButton, 'PDF');
      await tester.ensureVisible(export);
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(
          find.text(es
              ? 'Genera al menos un material antes de exportar.'
              : 'Gere pelo menos um material antes de exportar.'),
          findsOneWidget);
      expect(study.artifacts.every((item) => item.content == refusal), isTrue);
      expect(tester.takeException(), isNull);
    });
    test('visual fallback labels follow the selected language ($es)', () {
      final data = StudyVisualResultCodec.decodeVisualSummary(
          'Intro\n\nSynthetic detail',
          isEs: es);
      expect(data.sections.single.title, es ? 'Punto 1' : 'Ponto 1');
    });
    test(
        'full and visual educational summaries survive the Study boundary ($es)',
        () {
      final lang = es ? 'es' : 'pt';
      final context = studyContext(
          es
              ? 'Organiza el material educativo aceptado.'
              : 'Organize o material educacional aceito.',
          lang: lang);
      final flow = ClinicalSafetyFlow(context);
      final text = nephroticAnswer(lang);
      expect(flow.terminal(text).allowed, isFalse);
      expect(flow.present(text), text);
      final visual = jsonEncode({
        'title': es ? 'Síndrome nefrótico' : 'Síndrome nefrótica',
        'overview': es ? 'Material educativo.' : 'Material educacional.',
        'sections': [
          {
            'title': es ? 'Tratamiento' : 'Tratamento',
            'body': es
                ? 'Controlar edema y tratar la causa.'
                : 'Controlar edema e tratar a causa.'
          }
        ],
        'keyPoints': [es ? 'Evaluar función renal.' : 'Avaliar função renal.'],
        'takeaway': ''
      });
      expect(jsonDecode(flow.present(visual)), jsonDecode(visual));
    });
  }
  test(
      'all Study generation stages and title requests bind the active language',
      () {
    for (final file in [
      'study_artifact_generator.dart',
      'study_title_suggestion_service.dart'
    ]) {
      final source = File('lib/services/study/$file').readAsStringSync();
      final requests = source.split('AiService.chat(').skip(1).toList();
      expect(requests, isNotEmpty);
      for (final request in requests) {
        expect(request.split('apiKey:').first,
            contains("appLanguage: isEs ? 'es' : 'pt'"));
      }
    }
  });
  test('saved legacy refusals are not accepted as complete or visual material',
      () {
    for (final text in [
      'Não há suporte verificável suficiente para apresentar esta resposta clínica com segurança.',
      'No hay soporte verificable suficiente para presentar esta respuesta clínica con seguridad.',
    ]) {
      expect(StudyArtifactGenerator.isFailureText(text), isTrue);
      expect(
          () => StudyArtifactGenerator.requireGeneratedContent(
              AiResult(text: text)),
          throwsStateError);
    }
    const content =
        'La fuente describe conceptos educativos y sus limitaciones.';
    expect(
        StudyArtifactGenerator.requireGeneratedContent(
            const AiResult(text: content)),
        content);
    expect(
        () => StudyArtifactGenerator.requireGeneratedContent(
            AiResult.error('unavailable', 'network')),
        throwsStateError);
  });
}
