// ls_stub.dart — Implementação vazia para plataformas nativas (iOS / Android).
// No iOS/Android não existe localStorage; as chamadas são no-ops silenciosas.
// A camada que chama estas funções já usa SharedPreferences como canal real.

/// Grava [value] no localStorage com chave [key].
/// Plataformas nativas: no-op.
void webLsSet(String key, String value) {}

/// Lê o valor de [key] no localStorage. Retorna null se ausente.
/// Plataformas nativas: sempre retorna null.
String? webLsGet(String key) => null;

/// Remove a chave [key] do localStorage.
/// Plataformas nativas: no-op.
void webLsRemove(String key) {}

/// Abre o modal GSI definido no index.html (window.medcasesShowGSIModal).
/// Plataformas nativas: no-op (não existe modal HTML nem JS nessas plataformas).
void webCallGSIModal() {}
