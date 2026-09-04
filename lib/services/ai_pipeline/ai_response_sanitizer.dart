import '../ai_smart_router.dart';
import 'ai_request_contract.dart';

/// Resultado imutável da sanitização textual.
///
/// Os indicadores refletem exatamente o resultado produzido pelo
/// [AiSmartRouter.sanitizeAndCheck]. Nenhuma nova regra de remoção é criada
/// nesta camada.
class AiResponseSanitizationOutcome {
  final String originalText;
  final String text;

  final AiRequestMode mode;
  final AiRequestLocale locale;

  final bool hadMetaLeak;
  final bool hadSevereLeak;
  final bool isRecoverable;

  const AiResponseSanitizationOutcome({
    required this.originalText,
    required this.text,
    required this.mode,
    required this.locale,
    required this.hadMetaLeak,
    required this.hadSevereLeak,
    required this.isRecoverable,
  });

  bool get changed => originalText != text;

  bool get isEmpty => text.isEmpty;

  bool get isNotEmpty => text.isNotEmpty;
}

/// Fronteira canônica da sanitização de respostas.
abstract class AiResponseSanitizerPort {
  AiResponseSanitizationOutcome sanitize({
    required String text,
    required AiRequestMode mode,
    required AiRequestLocale locale,
  });
}

/// Assinatura compatível com [AiSmartRouter.sanitizeAndCheck].
typedef AiSmartRouterSanitizeRunner = SanitizeResult Function(
  String response, {
  bool isPlantaoMode,
  String appLanguage,
});

/// Adaptador para o sanitizador já existente.
///
/// Esta classe não contém regex, regras de idioma, regras clínicas,
/// filtros de meta-leak ou qualquer lógica paralela.
class ExistingAiSmartRouterSanitizerPort implements AiResponseSanitizerPort {
  final AiSmartRouterSanitizeRunner? runner;

  const ExistingAiSmartRouterSanitizerPort({
    this.runner,
  });

  @override
  AiResponseSanitizationOutcome sanitize({
    required String text,
    required AiRequestMode mode,
    required AiRequestLocale locale,
  }) {
    final activeRunner = runner ?? AiSmartRouter.sanitizeAndCheck;

    final result = activeRunner(
      text,
      isPlantaoMode: mode == AiRequestMode.plantao,
      appLanguage: _languageCode(locale),
    );

    return AiResponseSanitizationOutcome(
      originalText: text,
      text: result.text,
      mode: mode,
      locale: locale,
      hadMetaLeak: result.hadMetaLeak,
      hadSevereLeak: result.hadSevereLeak,
      isRecoverable: result.isRecoverable,
    );
  }
}

/// Proprietário público da sanitização textual no novo pipeline.
///
/// Nesta etapa, somente delega à implementação existente. A classe ainda não é
/// utilizada pelas rotas produtivas, porque o AppProvider continua executando
/// sua sanitização internamente durante a migração.
class AiResponseSanitizer {
  final AiResponseSanitizerPort port;

  const AiResponseSanitizer({
    this.port = const ExistingAiSmartRouterSanitizerPort(),
  });

  AiResponseSanitizationOutcome sanitize({
    required String text,
    required AiRequestMode mode,
    required AiRequestLocale locale,
  }) {
    return port.sanitize(
      text: text,
      mode: mode,
      locale: locale,
    );
  }
}

String _languageCode(AiRequestLocale locale) {
  switch (locale) {
    case AiRequestLocale.pt:
      return 'pt';
    case AiRequestLocale.es:
      return 'es';
  }
}
