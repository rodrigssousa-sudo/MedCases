import 'ai_request_contract.dart';

/// Immutable ownership and mode for an accepted or queued UI action.
/// Uses AiScreen's existing generation; it does not own another epoch.
class AiUiRequestSnapshot {
  final AiRequestMode mode;
  final int generation;
  final String? sessionIdentity;
  final String? uid;

  const AiUiRequestSnapshot({
    required this.mode,
    required this.generation,
    required this.sessionIdentity,
    required this.uid,
  });

  bool get longResponse => mode == AiRequestMode.estudo;
  bool get isPlantaoMode => mode == AiRequestMode.plantao;

  bool isCurrent({
    required int generation,
    required String? sessionIdentity,
    required String? uid,
  }) =>
      this.generation == generation &&
      this.sessionIdentity == sessionIdentity &&
      this.uid == uid;
}

/// A Home/deeplink action carries its own mode, never residual UI state.
class AiPendingQuery {
  final String query;
  final AiRequestMode mode;
  final Object identity = Object();

  AiPendingQuery({required this.query, required this.mode});
}
