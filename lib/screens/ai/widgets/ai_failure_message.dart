import 'package:flutter/material.dart';

/// Presentation only. Never use this classification to authorize a response.
enum AiFailureKind {
  unknown,
  clinicalValidation,
  paywall,
  studyQuota,
  plantaoQuota
}

class AiFailureMessage {
  const AiFailureMessage(this.kind);
  final AiFailureKind kind;

  static AiFailureMessage fromError(String raw) =>
      recognize(raw) ?? const AiFailureMessage(AiFailureKind.unknown);

  /// Recognizes legacy terminal/history payloads before Markdown or clinical
  /// formatting can remove separators. Unknown error callbacks use fromError.
  static AiFailureMessage? recognize(String raw) {
    final compact = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.contains('FREEPLANTAODAILYLIMITREACHED')) {
      return const AiFailureMessage(AiFailureKind.plantaoQuota);
    }
    if (compact.contains('FREEAISTUDYDAILYLIMITREACHED')) {
      return const AiFailureMessage(AiFailureKind.studyQuota);
    }
    if (compact.contains('PAYWALL') ||
        compact.contains('QUOTAEXCEEDED') ||
        compact.contains('INSUFFICIENTQUOTA') ||
        compact.contains('PLANLIMITREACHED')) {
      return const AiFailureMessage(AiFailureKind.paywall);
    }
    if (compact.contains('CLINICALVALIDATION') ||
        compact.contains('CLINICALSAFETYTRANSPORTREJECTED') ||
        compact.contains('PIPELINERESULTREJECTEDAFTERSTART') ||
        raw.startsWith(
            'No hay soporte verificable suficiente para presentar esta respuesta clínica') ||
        raw.startsWith(
            'Não há suporte verificável suficiente para apresentar esta resposta clínica') ||
        raw.startsWith('Resposta indisponível: contexto clínico inválido.') ||
        raw.startsWith('Respuesta interrumpida (validación fallida)') ||
        raw.startsWith('Resposta interrompida (validação falhou)')) {
      return const AiFailureMessage(AiFailureKind.clinicalValidation);
    }
    // Only standalone machine payloads, never uppercase medical prose.
    final bare = raw.trim().replaceAll('\\', '');
    if (RegExp(r'^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+$').hasMatch(bare) ||
        RegExp(r'^[a-z][a-z0-9]*(?:[_-][a-z0-9]+)+$').hasMatch(bare) ||
        RegExp(r'^(?:Exception|StateError|Error|FormatException|SocketException|TimeoutException)[:(]')
            .hasMatch(bare) ||
        (bare.startsWith('ERRO') && bare.contains('API'))) {
      return const AiFailureMessage(AiFailureKind.unknown);
    }
    // Friendly persisted failures are rendered by the same plain-text surface.
    for (final kind in AiFailureKind.values) {
      final candidate = AiFailureMessage(kind);
      if (raw == candidate.text('pt') || raw == candidate.text('es')) {
        return candidate;
      }
    }
    return null;
  }

  String text(String lang) {
    final es = lang.toLowerCase().startsWith('es');
    switch (kind) {
      case AiFailureKind.plantaoQuota:
        return es
            ? 'Límite diario alcanzado\n\nHas alcanzado el límite diario del modo Plantão/Guardia en el plan Free. Puedes intentarlo nuevamente mañana o actualizar tu plan para seguir usando esta función hoy.'
            : 'Limite diário atingido\n\nVocê atingiu o limite diário do modo Plantão/Guardia no plano Free. Você pode tentar novamente amanhã ou atualizar seu plano para continuar usando esta função hoje.';
      case AiFailureKind.studyQuota:
        return es
            ? 'Límite diario alcanzado\n\nHas alcanzado el límite diario del modo Estudio en el plan Free. Puedes intentarlo nuevamente mañana o actualizar tu plan para seguir usando esta función hoy.'
            : 'Limite diário atingido\n\nVocê atingiu o limite diário do modo Estudo no plano Free. Você pode tentar novamente amanhã ou atualizar seu plano para continuar usando esta função hoje.';
      case AiFailureKind.paywall:
        return es
            ? 'Límite del plan alcanzado\n\nHas alcanzado el límite de tu plan para esta función. Revisa las opciones de tu plan para continuar.'
            : 'Limite do plano atingido\n\nVocê atingiu o limite do seu plano para esta função. Confira as opções do seu plano para continuar.';
      case AiFailureKind.clinicalValidation:
        return es
            ? 'Validación clínica\n\nLa respuesta no se mostró porque no cumplió una validación clínica obligatoria. Vuelve a intentar con otra redacción.'
            : 'Validação clínica\n\nA resposta não foi exibida porque não cumpriu uma validação clínica obrigatória. Tente novamente com outra formulação.';
      case AiFailureKind.unknown:
        return es
            ? 'No pudimos completar la solicitud en este momento. Inténtalo nuevamente.'
            : 'Não foi possível concluir a solicitação neste momento. Tente novamente.';
    }
  }
}

/// One request owns one error slot; higher-priority failures replace that slot.
class AiFailureState {
  AiFailureMessage? current;
  AiFailureMessage accept(String raw) {
    final next = AiFailureMessage.fromError(raw);
    if (current == null || next.kind.index > current!.kind.index) {
      current = next;
    }
    return current!;
  }
}

/// No Markdown, clinical formatting, references, or technical error banners.
class AiFailureBubble extends StatelessWidget {
  const AiFailureBubble({super.key, required this.failure, required this.lang});
  final AiFailureMessage failure;
  final String lang;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(failure.text(lang)),
      );
}
