import 'package:medcases/services/audio/recording_deletion_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medcases/screens/study_workspace_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/models/study_workspace_model.dart';
import 'package:medcases/services/study/study_artifact_access.dart';
import 'package:medcases/services/entitlement_service.dart';
import 'package:medcases/services/medcases_feature_authorization.dart';
import 'package:medcases/services/calculator_mcc1_bridge_service.dart';

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
  testWidgets('format selector locks only paid formats and reacts to Premium',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'medcases.study.educational_notice.v1.accepted': true});
    RecordingDeletionStore.ownerOverride = () => 'qa';
    addTearDown(() => RecordingDeletionStore.ownerOverride = null);
    var tier = 'free';
    final now = DateTime.utc(2026, 10, 3);
    final owner = EntitlementService.forTesting(
        uid: () => 'qa',
        clock: () => now,
        sessionLoader: (_) async => CalculatorMcc1Session(
            token: 'fixture',
            tier: tier,
            capabilities: const [],
            expiresAtUtc: now.add(const Duration(minutes: 5)),
            entitlementSource: 'fixture'));
    await owner.refreshAuthoritativeTier();
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final study = Study(
        id: 'fixture',
        ownerUid: 'qa',
        title: 'Teste',
        sources: [
          StudySource(
              id: 'source',
              type: StudySourceType.text,
              title: 'Fixture',
              text: 'Material sintético.',
              state: StudySourceState.accepted,
              createdAtUtc: now)
        ],
        locale: 'pt',
        createdAtUtc: now);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StudyWorkspaceScreen(
                isEs: false,
                initialStudy: study,
                authorization: MedCasesFeatureAuthorization(owner)))));
    await tester.pumpAndSettle();
    DropdownButton<StudyArtifactType> selector() =>
        tester.widget<DropdownButton<StudyArtifactType>>(find
            .byWidgetPredicate((w) => w is DropdownButton<StudyArtifactType>));
    expect(
        selector()
            .items!
            .where((item) => (item.child as Row)
                .children
                .any((w) => w is Icon && w.icon == Icons.lock_outline))
            .length,
        7);
    tier = 'premium';
    await owner.refreshAuthoritativeTier(force: true);
    await tester.pump();
    expect(
        selector().items!.where((item) => (item.child as Row)
            .children
            .any((w) => w is Icon && w.icon == Icons.lock_outline)),
        isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    owner.dispose();
  });

  for (final tier in ['free', 'premium']) {
    test('all artifact formats use canonical $tier access', () async {
      final now = DateTime.utc(2026, 10, 3);
      final owner = EntitlementService.forTesting(
          uid: () => 'qa',
          clock: () => now,
          sessionLoader: (_) async => CalculatorMcc1Session(
              token: 'fixture',
              tier: tier,
              capabilities: const [],
              expiresAtUtc: now.add(const Duration(minutes: 5)),
              entitlementSource: 'fixture'));
      await owner.refreshAuthoritativeTier();
      for (final type in StudyArtifactType.values) {
        expect(
            StudyArtifactAccess.allows(
                type, MedCasesFeatureAuthorization(owner)),
            tier == 'premium' ||
                type == StudyArtifactType.fullSummary ||
                type == StudyArtifactType.keyPoints,
            reason: type.name);
      }
      owner.dispose();
    });
  }
}
