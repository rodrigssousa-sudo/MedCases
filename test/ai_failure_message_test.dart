import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/screens/ai/widgets/ai_failure_message.dart';

void main() {
  const quotaVariants = [
    'FREE_PLANTAO_DAILY_LIMIT_REACHED',
    r'FREE\_PLANTAO\_DAILY\_LIMIT\_REACHED',
    'FREEPLANTAODAILYLIMITREACHED',
    'free-plantao-daily-limit-reached',
    'CLINICAL_VALIDATION_FAILED: FREE_PLANTAO_DAILY_LIMIT_REACHED',
  ];
  for (final lang in ['pt', 'es']) {
    for (final raw in quotaVariants) {
      testWidgets('$lang quota never displays $raw', (tester) async {
        final failure = AiFailureMessage.fromError(raw);
        expect(failure.kind, AiFailureKind.plantaoQuota);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
          body: AiFailureBubble(failure: failure, lang: lang),
        )));
        expect(find.text(failure.text(lang)), findsOneWidget);
        expect(find.textContaining('FREE'), findsNothing);
        expect(find.textContaining('CLINICAL'), findsNothing);
        expect(
            find.textContaining(lang == 'es'
                ? 'Límite diario alcanzado'
                : 'Limite diário atingido'),
            findsOneWidget);
        expect(find.textContaining(lang == 'es' ? 'mañana' : 'amanhã'),
            findsOneWidget);
      });
    }
    for (final raw in [
      'CLINICAL_VALIDATION_FAILED',
      'PIPELINE_RESULT_REJECTED_AFTER_START',
      'Resposta interrompida (validação falhou). Tente novamente. ⚕',
      'No hay soporte verificable suficiente para presentar esta respuesta clínica con seguridad.'
    ]) {
      testWidgets('$lang clinical validation: $raw', (tester) async {
        final failure = AiFailureMessage.fromError(raw);
        expect(failure.kind, AiFailureKind.clinicalValidation);
        await tester.pumpWidget(
            MaterialApp(home: AiFailureBubble(failure: failure, lang: lang)));
        expect(
            find.textContaining(
                lang == 'es' ? 'Validación clínica' : 'Validação clínica'),
            findsOneWidget);
        expect(find.textContaining(raw), findsNothing);
      });
    }
    testWidgets('$lang unknown exception uses safe fallback only',
        (tester) async {
      const raw = 'Exception: upstream HTTP 500 at internal.service/private';
      final failure = AiFailureMessage.fromError(raw);
      await tester.pumpWidget(
          MaterialApp(home: AiFailureBubble(failure: failure, lang: lang)));
      expect(
          find.text(lang == 'es'
              ? 'No pudimos completar la solicitud en este momento. Inténtalo nuevamente.'
              : 'Não foi possível concluir a solicitação neste momento. Tente novamente.'),
          findsOneWidget);
      expect(find.textContaining('HTTP'), findsNothing);
      expect(find.textContaining('internal.service'), findsNothing);
    });
    testWidgets('$lang simultaneous errors keep one highest-priority state',
        (tester) async {
      for (final order in [
        [
          'arbitrary technical detail',
          'CLINICAL_VALIDATION_FAILED',
          quotaVariants.first
        ],
        [
          quotaVariants.first,
          'CLINICAL_VALIDATION_FAILED',
          'arbitrary technical detail'
        ],
      ]) {
        final state = AiFailureState();
        for (final raw in order) {
          await tester.pumpWidget(MaterialApp(
              home: AiFailureBubble(failure: state.accept(raw), lang: lang)));
          expect(find.byType(AiFailureBubble), findsOneWidget);
        }
        expect(state.current!.kind, AiFailureKind.plantaoQuota);
        expect(
            find.textContaining(
                lang == 'es' ? 'Validación clínica' : 'Validação clínica'),
            findsNothing);
      }
    });
  }
  test('paywall, study, unknown slugs, legacy history and normal content', () {
    expect(AiFailureMessage.fromError('PAYWALL_REQUIRED').kind,
        AiFailureKind.paywall);
    expect(AiFailureMessage.fromError('FREE_AI_STUDY_DAILY_LIMIT_REACHED').kind,
        AiFailureKind.studyQuota);
    for (final raw in ['INTERNAL_SERVICE_BROKEN', 'unknown-service-failure']) {
      expect(AiFailureMessage.recognize(raw)!.kind, AiFailureKind.unknown);
    }
    for (final kind in AiFailureKind.values) {
      for (final lang in ['pt', 'es']) {
        expect(
            AiFailureMessage.recognize(AiFailureMessage(kind).text(lang))!.kind,
            kind);
      }
    }
    for (final text in [
      'Paciente com dor abdominal.',
      'Dados necessários: peso em kg.',
      'INFARTO AGUDO DO MIOCÁRDIO'
    ]) {
      expect(AiFailureMessage.recognize(text), isNull);
    }
  });
  test(
      'screen routes terminal errors, exceptions and restored history through safe presentation',
      () {
    final source = File('lib/screens/ai_screen.dart').readAsStringSync();
    expect(source, contains('presentFailure(errorMsg)'));
    expect(source, contains('presentFailure(e.toString())'));
    expect(source, contains('presentFailure(finalText)'));
    expect(source, contains('presentFailure(safeFinalText)'));
    expect(source, contains('AiFailureMessage.recognize(msg.text)'));
    expect(source, isNot(contains('text: errorMsg')));
    final presenter = source.substring(
        source.indexOf('    void presentFailure('),
        source.indexOf('    void armTerminalGapIndicator()'));
    expect(
        presenter, contains('_messages[streamingMsgIdx] = _ChatMsg.withId('));
    expect(presenter, contains('streamingMsgIdx = _messages.length'));
    expect(presenter, contains('_aiError = false'));
    expect(presenter, contains('_networkError = false'));
    expect(presenter, contains("debugPrint('[AI_PRESENTATION_ERROR] \$raw')"));
  });
}
