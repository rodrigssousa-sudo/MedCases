import 'dart:async';

typedef PlantaoShadowFailureSink = void Function(
  Object error,
  StackTrace stackTrace,
);

class PlantaoShadowExecutionIsolator {
  const PlantaoShadowExecutionIsolator();

  static const bool shadowOnly = true;
  static const bool productiveAwaitEnabled = false;
  static const bool productiveMutationEnabled = false;
  static const bool persistenceEnabled = false;

  void launch(
    Future<void> Function() work, {
    PlantaoShadowFailureSink? onFailure,
  }) {
    unawaited(
      Future<void>.sync(work).catchError(
        (Object error, StackTrace stackTrace) {
          onFailure?.call(error, stackTrace);
        },
      ),
    );
  }
}
