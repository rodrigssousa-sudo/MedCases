// update_service_web.dart — Implementação Web usando dart:js / dart:js_interop.
//
// Este arquivo é compilado APENAS na plataforma Web (conditional import).
// iOS/Android usam update_service_stub.dart, que não importa dart:js.
// Resolve o erro "Undefined name 'context'" no compilador nativo (Xcode).

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

/// Registra `window.onFlutterWebUpdateAvailable` no JS e verifica se já
/// havia um update pendente antes do Dart bootar (`window._mcUpdatePending`).
/// [onUpdate] é chamado quando o SW sinaliza uma nova versão disponível.
///
/// BUILD 281: no mobile web (viewport < 768px), o Dart NÃO exibe o _UpdateBanner
/// Flutter — o toast HTML nativo (#pwa-update-toast) já cobre essa função.
/// Ativar o banner Flutter em mobile causava duplo botão "ATUALIZAR" e
/// sobrepunha a floating bottom nav, degradando a UX.
/// O JS em index.html já garante que _mcUpdatePending=false no mobile antes
/// desta função ser chamada — esta guard é uma camada de defesa adicional.
void setupUpdateListenerImpl(void Function() onUpdate) {
  try {
    // BUILD 281: guard mobile — só ativa o banner Flutter em desktop (≥768px).
    // No mobile, o toast HTML (#pwa-update-toast) já cobre a notificação de SW.
    // Registramos o callback mesmo no mobile para evitar erros de undefined
    // no JS, mas o onUpdate() não é chamado na verificação de pending.
    final viewportWidth = _getViewportWidth();
    final isMobileWeb = viewportWidth < 768;

    // [CC1] L30: allowInterop removed — parameterless closure wrapped with .toJS
    js.context['onFlutterWebUpdateAvailable'] = (() {
      // No mobile, não notifica o Dart — o JS já exibiu o toast HTML
      if (isMobileWeb) {
        debugPrint('[UpdateService] Mobile web — notificação de SW bloqueada (toast HTML ativo).');
        return;
      }
      debugPrint('[UpdateService] Nova versão do SW detectada — update disponível (desktop).');
      onUpdate();
    }).toJS;

    // Race condition: SW pode ter sido detectado antes do Dart bootar.
    // BUILD 281: no mobile, _mcUpdatePending foi zerado pelo JS após 8s
    // (auto-dismiss do toast), então esta verificação é segura.
    final pending = js.context['_mcUpdatePending'];
    if (pending == true && !isMobileWeb) {
      debugPrint('[UpdateService] Update já estava pendente antes do boot — notificando (desktop).');
      onUpdate();
    } else if (pending == true && isMobileWeb) {
      debugPrint('[UpdateService] Update pendente detectado no mobile — toast HTML já visível, sem banner Flutter.');
    }
  } catch (e) {
    debugPrint('[UpdateService] setupUpdateListenerImpl error: $e');
  }
}

/// Retorna a largura do viewport em pixels lógicos.
/// Usado para distinguir mobile (<768px) de desktop (≥768px) — mesmo
/// breakpoint que o Flutter usa em MedBreakpoints.
int _getViewportWidth() {
  try {
    final w = js.context['innerWidth'];
    if (w != null) return (w as num).toInt();
  } catch (_) {}
  return 1024; // fallback conservador: assume desktop se não conseguir ler
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
