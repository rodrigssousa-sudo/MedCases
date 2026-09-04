enum AiAccumulationDisposition {
  accepted,
  duplicate,
  empty,
  staleAttempt,
  sealed,
}

/// Resultado imutável de uma tentativa de acumulação.
class AiAccumulationUpdate {
  final AiAccumulationDisposition disposition;

  /// Conteúdo incremental desta atualização.
  ///
  /// Em uma substituição de snapshot, contém o novo snapshot completo.
  final String delta;

  /// Snapshot canônico após processar a atualização.
  final String accumulatedText;

  /// Indica que o novo snapshot não continuava o conteúdo anterior.
  final bool replacesAccumulatedText;

  final int attempt;

  const AiAccumulationUpdate({
    required this.disposition,
    required this.delta,
    required this.accumulatedText,
    required this.replacesAccumulatedText,
    required this.attempt,
  });

  bool get accepted => disposition == AiAccumulationDisposition.accepted;
}

/// Proprietário canônico da montagem textual de uma resposta.
///
/// Suporta duas fontes:
/// - deltas brutos de transporte;
/// - snapshots acumulados entregues por callbacks legados.
///
/// O acumulador também bloqueia tentativas incorretas e qualquer conteúdo
/// recebido depois de [seal].
class AiResponseAccumulator {
  final int expectedAttempt;

  String _text = '';
  bool _sealed = false;
  int _acceptedUpdateCount = 0;

  AiResponseAccumulator({
    this.expectedAttempt = 1,
  }) : assert(expectedAttempt > 0);

  String get text => _text;

  bool get isEmpty => _text.isEmpty;

  bool get isNotEmpty => _text.isNotEmpty;

  bool get isSealed => _sealed;

  int get acceptedUpdateCount => _acceptedUpdateCount;

  /// Acrescenta um fragmento bruto ao texto canônico.
  AiAccumulationUpdate acceptDelta(
    String delta, {
    required int attempt,
  }) {
    final rejection = _validateInput(
      value: delta,
      attempt: attempt,
    );

    if (rejection != null) {
      return rejection;
    }

    _text += delta;
    _acceptedUpdateCount++;

    return AiAccumulationUpdate(
      disposition: AiAccumulationDisposition.accepted,
      delta: delta,
      accumulatedText: _text,
      replacesAccumulatedText: false,
      attempt: attempt,
    );
  }

  /// Processa um snapshot acumulado completo.
  ///
  /// Se o snapshot continuar o texto atual, somente o sufixo novo será
  /// retornado em [AiAccumulationUpdate.delta]. Quando não continuar,
  /// o snapshot será tratado como substituição explícita.
  AiAccumulationUpdate acceptSnapshot(
    String snapshot, {
    required int attempt,
  }) {
    if (_sealed) {
      return _ignored(
        AiAccumulationDisposition.sealed,
        attempt,
      );
    }

    if (attempt != expectedAttempt) {
      return _ignored(
        AiAccumulationDisposition.staleAttempt,
        attempt,
      );
    }

    if (snapshot.isEmpty) {
      return _ignored(
        AiAccumulationDisposition.empty,
        attempt,
      );
    }

    if (snapshot == _text) {
      return _ignored(
        AiAccumulationDisposition.duplicate,
        attempt,
      );
    }

    final continuesPrevious = snapshot.startsWith(_text);

    final delta =
        continuesPrevious ? snapshot.substring(_text.length) : snapshot;

    _text = snapshot;
    _acceptedUpdateCount++;

    return AiAccumulationUpdate(
      disposition: AiAccumulationDisposition.accepted,
      delta: delta,
      accumulatedText: _text,
      replacesAccumulatedText: !continuesPrevious,
      attempt: attempt,
    );
  }

  /// Impede qualquer mutação posterior.
  ///
  /// Retorna `true` somente na primeira chamada.
  bool seal() {
    if (_sealed) return false;

    _sealed = true;
    return true;
  }

  AiAccumulationUpdate? _validateInput({
    required String value,
    required int attempt,
  }) {
    if (_sealed) {
      return _ignored(
        AiAccumulationDisposition.sealed,
        attempt,
      );
    }

    if (attempt != expectedAttempt) {
      return _ignored(
        AiAccumulationDisposition.staleAttempt,
        attempt,
      );
    }

    if (value.isEmpty) {
      return _ignored(
        AiAccumulationDisposition.empty,
        attempt,
      );
    }

    return null;
  }

  AiAccumulationUpdate _ignored(
    AiAccumulationDisposition disposition,
    int attempt,
  ) {
    return AiAccumulationUpdate(
      disposition: disposition,
      delta: '',
      accumulatedText: _text,
      replacesAccumulatedText: false,
      attempt: attempt,
    );
  }
}
