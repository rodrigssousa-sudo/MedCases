/// UpdateService — Auto-Update / Cache Eviction para Flutter Web.
///
/// Mecanismo:
///   1. O Service Worker (pwa-sw.js) detecta novo SW em estado `waiting`.
///   2. O JS em index.html chama `showUpdateToast(sw)` que seta
///      `window._mcUpdatePending = true` e chama `window.onFlutterWebUpdateAvailable()`.
///   3. [setupUpdateListener] registra `window.onFlutterWebUpdateAvailable` antes
///      do Flutter terminar o boot (chamado no initState do _MainShellState).
///   4. Quando a função JS é chamada, [swUpdateAvailable] é setado para `true`.
///   5. A UI escuta [swUpdateAvailable] e exibe o banner de atualização.
///   6. Ao clicar em "Atualizar Agora", [applyUpdate] chama
///      `window.medcasesApplyUpdate()` que envia `SKIP_WAITING` ao SW e
///      aguarda `controllerchange` → `window.location.reload()`.
///
/// Isolamento de plataforma:
///   • Web (dart.library.js)  → update_service_web.dart  (usa dart:js)
///   • iOS / Android / Desktop → update_service_stub.dart (no-ops, sem dart:js)
///
/// Isso resolve "Error: Undefined name 'context'" no compilador nativo (Xcode/NDK)
/// causado pelo import direto de dart:js — idêntico ao padrão de ls_web.dart.

// Import condicional: update_service_web.dart (Web, usa dart:js)
//                 ou update_service_stub.dart  (iOS/Android, no-op, sem dart:js).
// Isola dart:js do compilador nativo — resolve "Undefined name 'context'" no Xcode.
import 'update_service_stub.dart'
    if (dart.library.js) 'update_service_web.dart';

import 'package:flutter/foundation.dart';

class UpdateService {
  UpdateService._();

  /// `true` quando há uma nova versão do Service Worker pronta para ativar.
  /// Widgets escutam com [ValueListenableBuilder] ou [addListener].
  static final ValueNotifier<bool> swUpdateAvailable = ValueNotifier<bool>(false);

  /// Registra `window.onFlutterWebUpdateAvailable` no JS e verifica se já
  /// havia um update pendente antes do Dart bootar (`window._mcUpdatePending`).
  ///
  /// Deve ser chamado UMA vez no `initState` do widget raiz (MainShell).
  /// iOS/Android: no-op seguro — dart:js nunca é carregado.
  static void setupUpdateListener() {
    if (!kIsWeb) return;
    // Delega para update_service_web.dart (Web) ou update_service_stub.dart (nativo).
    // O compilador iOS/Android nunca vê o corpo de update_service_web.dart.
    setupUpdateListenerImpl(() {
      swUpdateAvailable.value = true;
    });
  }

  /// Aplica o update: chama `window.medcasesApplyUpdate()` definido em index.html.
  /// Isso envia `{type: "SKIP_WAITING"}` ao SW em waiting e, após
  /// `controllerchange` disparar, recarrega a página com cache limpo.
  /// iOS/Android: no-op seguro.
  static void applyUpdate() {
    if (!kIsWeb) return;
    applyUpdateImpl();
  }

  /// Dispensa o banner sem aplicar o update.
  /// O usuário verá o banner novamente na próxima detecção de SW.
  static void dismissUpdate() {
    swUpdateAvailable.value = false;
  }
}
