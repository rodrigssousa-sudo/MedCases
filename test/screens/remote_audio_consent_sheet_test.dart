import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/remote_audio_consent_sheet.dart';
import 'package:medcases/services/audio/clinical_long_form_remote_audio_consent_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = ClinicalLongFormRemoteAudioConsentStore();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget harness({
    required String language,
    ValueChanged<bool>? onResult,
  }) {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final accepted =
                    await ClinicalLongFormRemoteAudioConsentUi.showIfNeeded(
                  context,
                  language: language,
                  store: store,
                );
                onResult?.call(accepted);
              },
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
    );
  }

  test('UI foundation is certified but production callsite stays unwired', () {
    expect(ClinicalLongFormRemoteAudioConsentUi.uiFoundationCertified, isTrue);
    expect(
      ClinicalLongFormRemoteAudioConsentUi.productionCallsiteWired,
      isFalse,
    );
    expect(
      ClinicalLongFormRemoteAudioConsentUi.productionRemoteAudioEnabled,
      isFalse,
    );
  });

  testWidgets(
      'PT consent is explicit default-off and persisted after acceptance',
      (tester) async {
    bool? result;

    await tester.pumpWidget(
      harness(language: 'pt', onResult: (value) => result = value),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Transcrição remota de áudio'), findsOneWidget);
    expect(
      find.textContaining(
        'Compreendo e autorizo a transcrição remota de áudio',
      ),
      findsOneWidget,
    );

    final acceptButtonFinder = find.widgetWithText(
      FilledButton,
      'Concordar e continuar',
    );
    expect(acceptButtonFinder, findsOneWidget);

    var acceptButton = tester.widget<FilledButton>(acceptButtonFinder);
    expect(acceptButton.onPressed, isNull);
    expect(await store.hasActiveConsent(), isFalse);

    await tester.tap(
      find.textContaining(
        'Compreendo e autorizo a transcrição remota de áudio',
      ),
    );
    await tester.pump();

    acceptButton = tester.widget<FilledButton>(acceptButtonFinder);
    expect(acceptButton.onPressed, isNotNull);

    await tester.tap(acceptButtonFinder);
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(await store.hasActiveConsent(), isTrue);

    final audit = await store.auditInfo();
    expect(audit['accepted'], 'true');
    expect(audit['language'], 'pt');
    expect(
      audit['disclosureVersion'],
      ClinicalLongFormRemoteAudioConsentStore.disclosureVersion,
    );
  });

  testWidgets('ES decline does not create consent', (tester) async {
    bool? result;

    await tester.pumpWidget(
      harness(language: 'es', onResult: (value) => result = value),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Transcripción remota de audio'), findsOneWidget);
    expect(find.text('Ahora no'), findsOneWidget);
    expect(find.text('Aceptar y continuar'), findsOneWidget);

    await tester.tap(find.text('Ahora no'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(await store.hasActiveConsent(), isFalse);

    final audit = await store.auditInfo();
    expect(audit['accepted'], 'false');
    expect(audit['acceptedAt'], isNull);
  });

  testWidgets('existing active consent bypasses sheet', (tester) async {
    await store.accept(
      language: 'pt',
      acceptedAtUtc: DateTime.utc(2026, 8, 20, 16),
    );

    bool? result;
    await tester.pumpWidget(
      harness(language: 'pt', onResult: (value) => result = value),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.text('Transcrição remota de áudio'), findsNothing);
  });

  testWidgets('revoked consent requires a new explicit acceptance',
      (tester) async {
    await store.accept(language: 'es');
    await store.revoke();

    await tester.pumpWidget(harness(language: 'es'));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Transcripción remota de audio'), findsOneWidget);
    expect(await store.hasActiveConsent(), isFalse);
  });
}
