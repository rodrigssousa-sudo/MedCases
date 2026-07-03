// ═══════════════════════════════════════════════════════════════════════════════
// FirebaseRuntimeGuard — BUILD 299
//
// CAUSA RAIZ DO BUG SAFARI (descoberta no BUILD 299):
//   O próprio getter `Firebase.apps` lança NullError no Safari/WebKit quando o
//   Firebase Web SDK falha na inicialização ou quando o interop JS está em estado
//   nulo (ITP, modo privado, IndexedDB bloqueado, redirect OAuth em voo).
//   Stack confirmado nos logs:
//     get$apps → Firebase_apps → _buildHomeSafe() →
//     [BUILD297][HomeScreen][FATAL_BUILD_ERROR] error=Null check operator
//
//   Portanto, qualquer código que chame `Firebase.apps.isEmpty` ou
//   `Firebase.apps.isNotEmpty` diretamente é PERIGOSO no Safari.
//
// SOLUÇÃO:
//   Centralizar TODO acesso a Firebase.apps neste helper, envolvendo-o em
//   try/catch. Nenhum outro arquivo do projeto pode chamar Firebase.apps
//   diretamente — apenas importar e usar FirebaseRuntimeGuard.isReady,
//   isUnavailable ou safeApps.
//
// REGRA DE USO:
//   ❌ PROIBIDO em qualquer outro arquivo:
//       Firebase.apps.isEmpty
//       Firebase.apps.isNotEmpty
//       Firebase.apps (qualquer forma)
//
//   ✅ CORRETO:
//       FirebaseRuntimeGuard.isUnavailable   → substitui Firebase.apps.isEmpty
//       FirebaseRuntimeGuard.isReady         → substitui Firebase.apps.isNotEmpty
//       FirebaseRuntimeGuard.safeApps        → substitui Firebase.apps (leitura)
//
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class FirebaseRuntimeGuard {
  // Construtor privado — classe utilitária estática, sem instância.
  FirebaseRuntimeGuard._();

  // ── isReady ─────────────────────────────────────────────────────────────────
  /// Retorna `true` se o Firebase SDK está inicializado e operacional.
  ///
  /// Equivale a `Firebase.apps.isNotEmpty`, mas protegido por try/catch contra
  /// o NullError que ocorre no Safari/WebKit quando o interop JS está em estado
  /// nulo (ITP, modo privado, redirect OAuth em voo, IndexedDB bloqueado).
  ///
  /// SEMPRE usar este getter em vez de `Firebase.apps.isNotEmpty` diretamente.
  static bool get isReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (e) {
      debugPrint('[BUILD299][FirebaseRuntimeGuard] Firebase.apps threw: $e');
      return false;
    }
  }

  // ── isUnavailable ────────────────────────────────────────────────────────────
  /// Retorna `true` se o Firebase SDK NÃO está disponível.
  ///
  /// Equivale a `Firebase.apps.isEmpty`, mas seguro contra NullError no Safari.
  ///
  /// Uso típico nos guards:
  /// ```dart
  /// if (kIsWeb && FirebaseRuntimeGuard.isUnavailable) {
  ///   return const SizedBox.shrink();
  /// }
  /// ```
  static bool get isUnavailable => !isReady;

  // ── safeApps ─────────────────────────────────────────────────────────────────
  /// Retorna a lista de apps Firebase inicializados, ou lista vazia em caso
  /// de qualquer erro de runtime (NullError, StateError, JS interop failure).
  ///
  /// Substitui `Firebase.apps` quando acesso à lista é necessário (ex: main.dart
  /// para guard de dupla inicialização).
  static List<FirebaseApp> get safeApps {
    try {
      return Firebase.apps;
    } catch (e) {
      debugPrint('[BUILD299][FirebaseRuntimeGuard] safeApps fallback empty: $e');
      return const [];
    }
  }
}
