// ls_web.dart — Implementação Web usando dart:js.
// Chama window.mcLsGet / mcLsSet / mcLsRemove definidas no index.html
// ANTES do Firebase/SES lockdown — imunes a CSP e proxies congelados.
//
// Este arquivo é compilado APENAS na plataforma Web (conditional import).
// iOS/Android usam ls_stub.dart, que não importa dart:js.

// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Grava [value] no localStorage via window.mcLsSet.
void webLsSet(String key, String value) {
  try {
    js.context.callMethod('mcLsSet', [key, value]);
  } catch (_) {}
}

/// Lê o valor de [key] via window.mcLsGet. Retorna null se ausente ou erro.
String? webLsGet(String key) {
  try {
    final result = js.context.callMethod('mcLsGet', [key]);
    if (result == null || result.toString() == 'null') return null;
    return result.toString();
  } catch (_) {
    return null;
  }
}

/// Remove a chave [key] via window.mcLsRemove.
void webLsRemove(String key) {
  try {
    js.context.callMethod('mcLsRemove', [key]);
  } catch (_) {}
}

/// Lê do sessionStorage via window.mcSsGet (fallback Safari ITP).
String? webSsGet(String key) {
  try {
    final result = js.context.callMethod('mcSsGet', [key]);
    if (result == null || result.toString() == 'null') return null;
    return result.toString();
  } catch (_) {
    return null;
  }
}

/// Grava no sessionStorage via window.mcSsSet.
void webSsSet(String key, String value) {
  try {
    js.context.callMethod('mcSsSet', [key, value]);
  } catch (_) {}
}

/// Remove do sessionStorage via window.mcSsRemove.
void webSsRemove(String key) {
  try {
    js.context.callMethod('mcSsRemove', [key]);
  } catch (_) {}
}

/// Abre o modal GSI definido no index.html chamando window.medcasesShowGSIModal().
/// Verifica a existência da função antes de chamar para evitar erros silenciosos.
void webCallGSIModal() {
  try {
    if (js.context.hasProperty('medcasesShowGSIModal')) {
      js.context.callMethod('medcasesShowGSIModal', []);
    } else {
      // ignore: avoid_print
      print('[ls_web] medcasesShowGSIModal não encontrada no window');
    }
  } catch (_) {}
}
