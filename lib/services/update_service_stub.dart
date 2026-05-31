// update_service_stub.dart — No-ops para iOS / Android / Desktop.
//
// Este arquivo é selecionado pelo import condicional em update_service.dart
// quando dart.library.js NÃO está disponível (compilador nativo: Xcode / NDK).
// NUNCA importa dart:js — resolve o erro "Undefined name 'context'" no iOS.

/// Registra o listener de update do Service Worker.
/// iOS/Android: no-op — Service Workers não existem em plataformas nativas.
void setupUpdateListenerImpl(void Function() onUpdate) {}

/// Aplica o update chamando window.medcasesApplyUpdate().
/// iOS/Android: no-op.
void applyUpdateImpl() {}

/// Verifica se há um update pendente antes do boot (window._mcUpdatePending).
/// iOS/Android: retorna sempre false.
bool checkPendingUpdateImpl() => false;
