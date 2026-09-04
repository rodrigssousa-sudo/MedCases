import 'dart:async';

import 'ai_response_result.dart';

typedef AiTerminalCleanup = void Function();

enum AiTerminalCommitOutcome {
  accepted,
  alreadyCompleted,
  identityMismatch,
}

/// Registro imutável do único terminal aceito para uma execução.
class AiTerminalCommit {
  final AiResponseResult result;
  final String source;
  final DateTime committedAt;

  const AiTerminalCommit({
    required this.result,
    required this.source,
    required this.committedAt,
  });
}

/// Proprietário único da competição entre sinais terminais.
///
/// O coordenador:
/// - aceita somente um [AiResponseResult];
/// - valida requestId e sessionId;
/// - executa limpezas registradas exatamente uma vez;
/// - expõe um Future resolvido somente pelo terminal vencedor;
/// - rejeita callbacks tardios sem alterar o resultado vencedor.
class AiTerminalCoordinator {
  final String requestId;
  final String sessionId;
  final DateTime Function() _clock;

  final Completer<AiTerminalCommit> _terminalCompleter =
      Completer<AiTerminalCommit>();

  final List<AiTerminalCleanup> _cleanups = <AiTerminalCleanup>[];

  AiTerminalCommit? _commit;
  bool _cleanupsExecuted = false;

  AiTerminalCoordinator({
    required this.requestId,
    required this.sessionId,
    DateTime Function()? clock,
  })  : assert(requestId != ''),
        assert(sessionId != ''),
        _clock = clock ?? DateTime.now;

  bool get isCompleted => _commit != null;

  AiTerminalCommit? get commit => _commit;

  AiResponseResult? get result => _commit?.result;

  String? get acceptedSource => _commit?.source;

  Future<AiTerminalCommit> get terminalFuture => _terminalCompleter.future;

  /// Registra uma limpeza associada à execução.
  ///
  /// Antes do terminal, a limpeza fica pendente. Depois do terminal,
  /// ela é executada imediatamente. Cada callback registrado é
  /// executado no máximo uma vez.
  void registerCleanup(
    AiTerminalCleanup cleanup,
  ) {
    if (_cleanupsExecuted) {
      _invokeCleanupSafely(cleanup);
      return;
    }

    _cleanups.add(cleanup);
  }

  AiTerminalCommitOutcome tryCommit({
    required AiResponseResult result,
    required String source,
  }) {
    if (result.requestId != requestId || result.sessionId != sessionId) {
      return AiTerminalCommitOutcome.identityMismatch;
    }

    if (_commit != null) {
      return AiTerminalCommitOutcome.alreadyCompleted;
    }

    final normalizedSource = source.trim().isEmpty ? 'unknown' : source.trim();

    final acceptedCommit = AiTerminalCommit(
      result: result,
      source: normalizedSource,
      committedAt: _clock(),
    );

    _commit = acceptedCommit;

    _executeCleanupsOnce();

    if (!_terminalCompleter.isCompleted) {
      _terminalCompleter.complete(
        acceptedCommit,
      );
    }

    return AiTerminalCommitOutcome.accepted;
  }

  void _executeCleanupsOnce() {
    if (_cleanupsExecuted) return;

    _cleanupsExecuted = true;

    final pending = List<AiTerminalCleanup>.from(
      _cleanups,
    );

    _cleanups.clear();

    for (final cleanup in pending) {
      _invokeCleanupSafely(cleanup);
    }
  }

  void _invokeCleanupSafely(
    AiTerminalCleanup cleanup,
  ) {
    try {
      cleanup();
    } catch (_) {
      // Uma limpeza defeituosa não pode impedir o fechamento
      // terminal nem bloquear as demais limpezas.
    }
  }
}
