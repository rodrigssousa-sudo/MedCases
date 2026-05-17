// Stub para plataformas não-web (mobile, desktop).
// Todas as funções são no-op — nunca são chamadas em produção graças ao
// guard `if (!kIsWeb) return;` em SttHelper.

void startSttImpl({
  required String locale,
  required void Function(String text) onResult,
  required void Function(String error) onError,
  required void Function() onEnd,
}) {
  // no-op
}

void stopSttImpl() {
  // no-op
}
