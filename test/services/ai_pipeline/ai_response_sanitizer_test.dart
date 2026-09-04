import 'package:flutter_test/flutter_test.dart';
import 'package:medcases/services/ai_pipeline/ai_pipeline_contracts.dart';
import 'package:medcases/services/ai_smart_router.dart';

class FakeSanitizerPort implements AiResponseSanitizerPort {
  int calls = 0;

  String? capturedText;
  AiRequestMode? capturedMode;
  AiRequestLocale? capturedLocale;

  AiResponseSanitizationOutcome? result;

  @override
  AiResponseSanitizationOutcome sanitize({
    required String text,
    required AiRequestMode mode,
    required AiRequestLocale locale,
  }) {
    calls++;

    capturedText = text;
    capturedMode = mode;
    capturedLocale = locale;

    return result ??
        AiResponseSanitizationOutcome(
          originalText: text,
          text: text,
          mode: mode,
          locale: locale,
          hadMetaLeak: false,
          hadSevereLeak: false,
          isRecoverable: text.isNotEmpty,
        );
  }
}

void main() {
  group('AiResponseSanitizer', () {
    test(
      'delega texto, modo e idioma exatamente uma vez',
      () {
        final port = FakeSanitizerPort();

        final sanitizer = AiResponseSanitizer(
          port: port,
        );

        final outcome = sanitizer.sanitize(
          text: 'Conduta clínica.',
          mode: AiRequestMode.plantao,
          locale: AiRequestLocale.pt,
        );

        expect(port.calls, 1);
        expect(
          port.capturedText,
          'Conduta clínica.',
        );
        expect(
          port.capturedMode,
          AiRequestMode.plantao,
        );
        expect(
          port.capturedLocale,
          AiRequestLocale.pt,
        );

        expect(
          outcome.text,
          'Conduta clínica.',
        );
      },
    );

    test(
      'texto limpo permanece inalterado',
      () {
        const sanitizer = AiResponseSanitizer();

        final outcome = sanitizer.sanitize(
          text: '## Pneumonia\n'
              'Conduta clínica concluída.',
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.pt,
        );

        expect(
          outcome.text,
          '## Pneumonia\n'
          'Conduta clínica concluída.',
        );

        expect(outcome.changed, isFalse);
        expect(outcome.hadMetaLeak, isFalse);
        expect(outcome.hadSevereLeak, isFalse);
        expect(outcome.isRecoverable, isTrue);
        expect(outcome.isNotEmpty, isTrue);
      },
    );

    test(
      'preserva o contrato para texto vazio',
      () {
        const sanitizer = AiResponseSanitizer();

        final outcome = sanitizer.sanitize(
          text: '',
          mode: AiRequestMode.plantao,
          locale: AiRequestLocale.es,
        );

        expect(outcome.originalText, isEmpty);
        expect(outcome.text, isEmpty);
        expect(outcome.isEmpty, isTrue);
        expect(outcome.changed, isFalse);
        expect(outcome.hadMetaLeak, isFalse);
        expect(outcome.hadSevereLeak, isFalse);
        expect(outcome.isRecoverable, isFalse);
      },
    );

    test(
      'remove marcador técnico suportado e preserva conteúdo clínico',
      () {
        const sanitizer = AiResponseSanitizer();

        final outcome = sanitizer.sanitize(
          text: '[SYSTEM] instrução interna do modelo\n'
              'Conduta clínica segura.',
          mode: AiRequestMode.plantao,
          locale: AiRequestLocale.pt,
        );

        expect(outcome.hadMetaLeak, isTrue);
        expect(outcome.changed, isTrue);
        expect(outcome.isRecoverable, isTrue);

        expect(
          outcome.text,
          isNot(contains('[SYSTEM]')),
        );

        expect(
          outcome.text,
          isNot(
            contains('instrução interna do modelo'),
          ),
        );

        expect(
          outcome.text,
          contains('Conduta clínica segura.'),
        );
      },
    );

    test(
      'resultado expõe sem perda todos os indicadores existentes',
      () {
        final port = FakeSanitizerPort();

        port.result = const AiResponseSanitizationOutcome(
          originalText: 'Texto bruto',
          text: 'Texto limpo',
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.es,
          hadMetaLeak: true,
          hadSevereLeak: true,
          isRecoverable: true,
        );

        final sanitizer = AiResponseSanitizer(
          port: port,
        );

        final outcome = sanitizer.sanitize(
          text: 'Texto bruto',
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.es,
        );

        expect(outcome.originalText, 'Texto bruto');
        expect(outcome.text, 'Texto limpo');
        expect(outcome.changed, isTrue);
        expect(outcome.hadMetaLeak, isTrue);
        expect(outcome.hadSevereLeak, isTrue);
        expect(outcome.isRecoverable, isTrue);
        expect(
          outcome.mode,
          AiRequestMode.estudo,
        );
        expect(
          outcome.locale,
          AiRequestLocale.es,
        );
      },
    );

    test(
      'mesma entrada produz resultado determinístico',
      () {
        const sanitizer = AiResponseSanitizer();

        const text = '[PROMPT] conteúdo técnico interno\n'
            'Respuesta clínica segura.';

        final first = sanitizer.sanitize(
          text: text,
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.es,
        );

        final second = sanitizer.sanitize(
          text: text,
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.es,
        );

        expect(second.text, first.text);
        expect(
          second.hadMetaLeak,
          first.hadMetaLeak,
        );
        expect(
          second.hadSevereLeak,
          first.hadSevereLeak,
        );
        expect(
          second.isRecoverable,
          first.isRecoverable,
        );

        expect(first.hadMetaLeak, isTrue);

        expect(
          first.text,
          'Respuesta clínica segura.',
        );
      },
    );

    test(
      'não atribui ao sanitizador remoções fora do contrato',
      () {
        const sanitizer = AiResponseSanitizer();

        const text =
            '<thinking>conteúdo não reconhecido pelo contrato atual</thinking>\n'
            'Conduta clínica.';

        final outcome = sanitizer.sanitize(
          text: text,
          mode: AiRequestMode.plantao,
          locale: AiRequestLocale.pt,
        );

        expect(outcome.hadMetaLeak, isFalse);
        expect(outcome.changed, isFalse);
        expect(outcome.text, text);
      },
    );

    test(
      'porta existente encaminha Plantão e português',
      () {
        bool? capturedPlantao;
        String? capturedLanguage;
        String? capturedText;

        final port = ExistingAiSmartRouterSanitizerPort(
          runner: (
            response, {
            bool isPlantaoMode = false,
            String appLanguage = 'pt',
          }) {
            capturedText = response;
            capturedPlantao = isPlantaoMode;
            capturedLanguage = appLanguage;

            return const SanitizeResult(
              text: 'Texto sanitizado.',
              hadMetaLeak: true,
              hadSevereLeak: false,
              isRecoverable: true,
            );
          },
        );

        final outcome = port.sanitize(
          text: 'Texto bruto.',
          mode: AiRequestMode.plantao,
          locale: AiRequestLocale.pt,
        );

        expect(capturedText, 'Texto bruto.');
        expect(capturedPlantao, isTrue);
        expect(capturedLanguage, 'pt');
        expect(outcome.text, 'Texto sanitizado.');
        expect(outcome.hadMetaLeak, isTrue);
        expect(outcome.isRecoverable, isTrue);
      },
    );

    test(
      'porta existente encaminha Estudo e espanhol',
      () {
        bool? capturedPlantao;
        String? capturedLanguage;

        final port = ExistingAiSmartRouterSanitizerPort(
          runner: (
            response, {
            bool isPlantaoMode = false,
            String appLanguage = 'pt',
          }) {
            capturedPlantao = isPlantaoMode;
            capturedLanguage = appLanguage;

            return SanitizeResult(
              text: response,
              hadMetaLeak: false,
              hadSevereLeak: false,
              isRecoverable: response.isNotEmpty,
            );
          },
        );

        port.sanitize(
          text: 'Respuesta.',
          mode: AiRequestMode.estudo,
          locale: AiRequestLocale.es,
        );

        expect(capturedPlantao, isFalse);
        expect(capturedLanguage, 'es');
      },
    );
  });
}
