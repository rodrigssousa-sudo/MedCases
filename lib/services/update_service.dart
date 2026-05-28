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
/// Compatibilidade:
///   • Web: usa `dart:js` (mesmo padrão de ls_web.dart).
///   • iOS/Android: todas as operações são no-ops seguros.
///
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
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
  static void setupUpdateListener() {
    if (!kIsWeb) return;
    try {
      // Registra a callback global que o JS invocará quando um novo SW for detectado.
      js.context['onFlutterWebUpdateAvailable'] = js.allowInterop(() {
        debugPrint('[UpdateService] Nova versão do SW detectada — update disponível.');
        swUpdateAvailable.value = true;
      });

      // Se o SW já foi detectado antes do Dart bootar (race condition),
      // a flag _mcUpdatePending estará `true` — notifica imediatamente.
      final pending = js.context['_mcUpdatePending'];
      if (pending == true) {
        debugPrint('[UpdateService] Update já estava pendente antes do boot — notificando.');
        swUpdateAvailable.value = true;
      }
    } catch (e) {
      debugPrint('[UpdateService] setupUpdateListener error: $e');
    }
  }

  /// Aplica o update: chama `window.medcasesApplyUpdate()` definido em index.html.
  /// Isso envia `{type: "SKIP_WAITING"}` ao SW em waiting e, após
  /// `controllerchange` disparar, recarrega a página com cache limpo.
  static void applyUpdate() {
    if (!kIsWeb) return;
    try {
      if (js.context.hasProperty('medcasesApplyUpdate')) {
        js.context.callMethod('medcasesApplyUpdate', []);
      } else {
        // Fallback: reload direto se a função não foi encontrada
        js.context.callMethod('eval', ['window.location.reload(true)']);
      }
    } catch (e) {
      debugPrint('[UpdateService] applyUpdate error: $e');
    }
  }

  /// Dispensa o banner sem aplicar o update.
  /// O usuário verá o banner novamente na próxima detecção de SW.
  static void dismissUpdate() {
    swUpdateAvailable.value = false;
  }
}
