// stt_helper_stub.dart — Stub de compilação.
// Nunca é chamado em produção — serve apenas para satisfazer o compilador
// quando nenhuma das condições do conditional import for verdadeira.

Future<void> startSttImpl({
  required String locale,
  required void Function(String text) onResult,
  required void Function(String error) onError,
  required void Function() onEnd,
}) async {
  // no-op
}

Future<void> stopSttImpl() async {
  // no-op
}
