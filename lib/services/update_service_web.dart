// update_service_web.dart — Implementação Web usando dart:js.
//
// Este arquivo é compilado APENAS na plataforma Web (conditional import).
// iOS/Android usam update_service_stub.dart, que não importa dart:js.
// Resolve o erro "Undefined name 'context'" no compilador nativo (Xcode).

// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Registra `window.onFlutterWebUpdateAvailable` no JS e verifica se já
/// havia um update pendente antes do Dart bootar (`window._mcUpdatePending`).
/// [onUpdate] é chamado quando o SW sinaliza uma nova versão disponível.
void setupUpdateListenerImpl(void Function() onUpdate) {
  try {
    js.context['onFlutterWebUpdateAvailable'] = js.allowInterop(() {
      debugPrint('[UpdateService] Nova versão do SW detectada — update disponível.');
      onUpdate();
    });

    // Race condition: SW pode ter sido detectado antes do Dart bootar.
    final pending = js.context['_mcUpdatePending'];
    if (pending == true) {
      debugPrint('[UpdateService] Update já estava pendente antes do boot — notificando.');
      onUpdate();
    }
  } catch (e) {
    debugPrint('[UpdateService] setupUpdateListenerImpl error: $e');
  }
}

/// Aplica o update: chama `window.medcasesApplyUpdate()` (definido em index.html).
/// Envia `{type: "SKIP_WAITING"}` ao SW em waiting → `controllerchange` → reload.
void applyUpdateImpl() {
  try {
    if (js.context.hasProperty('medcasesApplyUpdate')) {
      js.context.callMethod('medcasesApplyUpdate', []);
    } else {
      // Fallback: reload direto se a função JS não foi encontrada
      js.context.callMethod('eval', ['window.location.reload(true)']);
    }
  } catch (e) {
    debugPrint('[UpdateService] applyUpdateImpl error: $e');
  }
}

/// Verifica se havia um update pendente antes do boot.
/// Retorna `true` se `window._mcUpdatePending === true`.
bool checkPendingUpdateImpl() {
  try {
    return js.context['_mcUpdatePending'] == true;
  } catch (_) {
    return false;
  }
}
