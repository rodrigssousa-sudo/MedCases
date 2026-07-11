// app_resume_coordinator.dart — MedCases Pro
// BUILD 241 — Background / Resume Loading Fix
//
// ═══════════════════════════════════════════════════════════════════════════
// PROBLEMA RAIZ
// ═══════════════════════════════════════════════════════════════════════════
//
// Quando o app vai para background (iOS/Android) ou a aba do browser fica
// oculta (Web), os seguintes problemas ocorrem:
//
// 1. TIMERS THROTTLED (Web/iOS):
//    • Browsers suspendem/reduzem timers em abas inativas.
//    • Flutter Timers internos (watchdog 45s, timeout global 30s) podem
//      "congelar" — o Timer dispara muito depois do tempo real.
//    • Resultado: o usuário volta e o app ainda está "esperando".
//
// 2. AI REQUEST SEM DEADLINE REAL:
//    • O globalTimeout de 30s no sendAiMessage usa Timer — sujeito a throttle.
//    • Ao voltar do background com Timer atrasado, o request pode estar
//      "morto" na rede mas o Flutter ainda pensa que está dentro do prazo.
//    • Resultado: spinner infinito.
//
// 3. BOOTSTRAP CONGELADO (Web):
//    • Se o usuário muda de aba DURANTE o bootstrap inicial (Firebase init,
//      restoreSession, setUser), _TimedSplash permanece com _bootDone=false
//      e _minTimeDone=false — ambos dependem de Timers/Futures que podem
//      ser throttled.
//    • Resultado: splash congelada ao voltar para a aba.
//
// 4. _WebMainShellGate FROZEN:
//    • setUser() chama Firestore REST. Se o browser suspendeu a aba durante
//      a chamada, a Promise resolve muito depois.
//    • Com timeout 3s (Timer), o Timer pode disparar fora do tempo real.
//    • Resultado: SplashScreen estática ao voltar.
//
// ═══════════════════════════════════════════════════════════════════════════
// SOLUÇÃO
// ═══════════════════════════════════════════════════════════════════════════
//
// AppResumeCoordinator é um singleton que:
//   1. Registra timestamps reais (DateTime.now()) para cada operação crítica.
//   2. Ao resumed/visibilitychange, verifica ELAPSED real com DateTime.now().
//   3. Para IA: se elapsed > 30s → encerra com safe-card imediatamente.
//   4. Para bootstrap: se elapsed > kBootstrapTimeoutMs → força conclusão.
//   5. Para qualquer loading: se elapsed > kLoadingWatchdogMs → libera UI.
//
// Não depende de Timer para medir tempo — usa DateTime.now() sempre.
// Timer apenas agenda a verificação periódica (pode atrasar, tudo bem —
// a verificação real usa timestamps).
//
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/widgets.dart' show ValueNotifier;

// ─────────────────────────────────────────────────────────────────────────────
// Constantes
// ─────────────────────────────────────────────────────────────────────────────

/// Orçamento máximo para o request de IA no modo Plantão (curto, urgência real).
/// BUILD 320: 30s mantido para Plantão — casos curtos não devem esperar 90s.
const _kAiDeadlinePlantaoMs = 30000;

/// Orçamento máximo para o request de IA no modo Estudo (payload 7000+ tokens).
/// BUILD 320: 90s — Casos clínicos complexos via Paid Proxy Gemini podem levar
/// 60-75s (inferência longa + cold-start da Cloud Function). O valor anterior de
/// 30s causava falso positivo de timeout no RESUME_COORDINATOR quando o payload
/// excedia 7000 tokens, disparando onTimeout enquanto a resposta ainda estava
/// em voo — resultando em race condition com DiagnosticsProperty<void>.
const _kAiDeadlineEstudoMs = 90000;

/// Orçamento máximo para bootstrap inicial (Firebase + auth + setUser).
const _kBootstrapDeadlineMs = 20000;

/// Orçamento máximo para qualquer loading genérico (fallback).
const _kLoadingWatchdogMs = 30000;

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de operação registrada
// ─────────────────────────────────────────────────────────────────────────────

enum _OpType { aiRequest, bootstrap, loading }

enum ResumeAction { continueOp, timeoutOp, ignore }

class _PendingOp {
  final String id;
  final _OpType type;
  final DateTime startedAt;
  final int deadlineMs;
  final void Function() onTimeout;

  _PendingOp({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.deadlineMs,
    required this.onTimeout,
  });

  bool get isExpired =>
      DateTime.now().difference(startedAt).inMilliseconds >= deadlineMs;

  int get elapsedMs =>
      DateTime.now().difference(startedAt).inMilliseconds;
}

// ─────────────────────────────────────────────────────────────────────────────
// AppResumeCoordinator
// ─────────────────────────────────────────────────────────────────────────────

/// Duração máxima de background antes do Context Timeout (ORDEM 53 M3).
/// BUILD 432: ampliado de 5 min → 30 min para evitar hard-reset destrutivo
/// em pausas normais de plantão (troca de turno, refeição, discussão de caso).
/// O médico raramente retorna a um paciente diferente em menos de 30 minutos;
/// resetar em 5 min gerava "amnésia" de contexto e alucinações semânticas
/// (ex: confundir fórmulas de nutrição enteral com fórmulas magistrais).
const Duration kContextTimeoutDuration = Duration(minutes: 30);

class AppResumeCoordinator {
  AppResumeCoordinator._();
  static final AppResumeCoordinator instance = AppResumeCoordinator._();

  // Mapa de operações em andamento: id → PendingOp
  final Map<String, _PendingOp> _pending = {};

  // Timestamp da última vez que o app foi para background
  DateTime? _backgroundAt;

  // ── ORDEM 53 M2: Auto-Save Signal ─────────────────────────────────────────
  /// Incrementado toda vez que o app vai para background.
  /// AiScreen escuta este notifier para salvar a sessão silenciosamente.
  /// ValueNotifier(int) incrementável — evita colapso de múltiplos sinais iguais.
  final backgroundSaveSignal = ValueNotifier<int>(0);

  // ── ORDEM 53 M3: Context Timeout Signal ───────────────────────────────────
  /// Incrementado quando o app retorna do background após ≥ 5 minutos.
  /// AiScreen escuta este notifier e executa hard reset de sessão clínica.
  final contextTimeoutSignal = ValueNotifier<int>(0);

  // ── API pública ─────────────────────────────────────────────────────────────

  /// Registra início de um request de IA.
  /// [requestId] deve ser o mesmo usado em sendAiMessage/_activeRequestId.
  /// [onTimeout] é chamado se, ao retornar do background, o prazo já venceu.
  /// [isEstudoMode] BUILD 320: quando true, usa deadline de 90s em vez de 30s.
  ///   Modo Estudo processa payloads de 7000+ tokens via Paid Proxy — a janela
  ///   de 30s causava falso positivo de timeout em casos clínicos complexos.
  void registerAiRequest({
    required String requestId,
    required void Function() onTimeout,
    bool isEstudoMode = false, // BUILD 320: elasticidade de deadline por modo
  }) {
    final deadline = isEstudoMode ? _kAiDeadlineEstudoMs : _kAiDeadlinePlantaoMs;
    _pending[requestId] = _PendingOp(
      id:         requestId,
      type:       _OpType.aiRequest,
      startedAt:  DateTime.now(),
      deadlineMs: deadline,
      onTimeout:  onTimeout,
    );
    debugPrint('[RESUME_COORDINATOR] registered ai_request id=$requestId '
        'deadline=${deadline}ms isEstudoMode=$isEstudoMode');
  }

  /// Remove operação de IA ao completar (sucesso ou timeout interno).
  void completeAiRequest(String requestId) {
    if (_pending.remove(requestId) != null) {
      debugPrint('[RESUME_COORDINATOR] completed ai_request id=$requestId');
    }
  }

  /// Registra início de bootstrap.
  void registerBootstrap({required void Function() onTimeout}) {
    const id = '_bootstrap_';
    _pending[id] = _PendingOp(
      id:         id,
      type:       _OpType.bootstrap,
      startedAt:  DateTime.now(),
      deadlineMs: _kBootstrapDeadlineMs,
      onTimeout:  onTimeout,
    );
    debugPrint('[RESUME_COORDINATOR] registered bootstrap '
        'deadline=${_kBootstrapDeadlineMs}ms');
  }

  /// Remove bootstrap ao completar.
  void completeBootstrap() {
    if (_pending.remove('_bootstrap_') != null) {
      debugPrint('[RESUME_COORDINATOR] completed bootstrap');
    }
  }

  /// Registra um loading genérico (ex: setUser, restoreSession).
  void registerLoading(String id, {required void Function() onTimeout}) {
    _pending[id] = _PendingOp(
      id:         id,
      type:       _OpType.loading,
      startedAt:  DateTime.now(),
      deadlineMs: _kLoadingWatchdogMs,
      onTimeout:  onTimeout,
    );
    debugPrint('[RESUME_COORDINATOR] registered loading id=$id '
        'deadline=${_kLoadingWatchdogMs}ms');
  }

  /// Remove loading ao completar.
  void completeLoading(String id) {
    _pending.remove(id);
  }

  // ── Lifecycle hooks ─────────────────────────────────────────────────────────

  /// Chamado quando app/aba vai para background.
  /// ORDEM 53 M2: dispara backgroundSaveSignal para auto-save silencioso.
  void onBackground() {
    _backgroundAt = DateTime.now();
    debugPrint('[LIFECYCLE] state=background pending=${_pending.length} ops');

    // ORDEM 53 M2: notifica AiScreen para salvar sessão antes de o OS
    // poder matar o processo. Incremento garante que cada background é um
    // evento único mesmo que o valor anterior fosse idêntico.
    backgroundSaveSignal.value = backgroundSaveSignal.value + 1;
    if (kDebugMode) {
      debugPrint('[ORDEM53_M2] backgroundSaveSignal disparado '
          'signal=${backgroundSaveSignal.value}');
    }
  }

  /// Chamado quando app/aba volta para foreground.
  /// Verifica cada operação pendente pelo elapsed real.
  /// ORDEM 53 M3: se background ≥ 5 min → dispara contextTimeoutSignal.
  void onForeground() {
    final bgAt = _backgroundAt;
    final bgMs = bgAt != null
        ? DateTime.now().difference(bgAt).inMilliseconds
        : 0;
    debugPrint('[LIFECYCLE] state=foreground backgroundDurationMs=$bgMs '
        'pending=${_pending.length}');

    // ORDEM 53 M3: Context Timeout — verifica se background excedeu 5 minutos
    if (bgAt != null) {
      final elapsed = DateTime.now().difference(bgAt);
      if (elapsed >= kContextTimeoutDuration) {
        debugPrint('[ORDEM53_M3] Context Timeout: elapsed=${elapsed.inSeconds}s '
            '≥ ${kContextTimeoutDuration.inSeconds}s — disparando contextTimeoutSignal');
        contextTimeoutSignal.value = contextTimeoutSignal.value + 1;
      }
    }

    _backgroundAt = null;

    if (_pending.isEmpty) return;

    debugPrint('[RESUME_COORDINATOR] checking ${_pending.length} pending operations');

    // Snapshot das chaves para evitar concurrent modification
    final keys = List<String>.from(_pending.keys);
    for (final key in keys) {
      final op = _pending[key];
      if (op == null) continue;

      final elapsed = op.elapsedMs;
      debugPrint('[RESUME_COORDINATOR] op=${op.type.name} id=${op.id} '
          'elapsedMs=$elapsed deadlineMs=${op.deadlineMs} '
          'expired=${op.isExpired}');

      if (op.isExpired) {
        debugPrint('[BACKGROUND_SAFE] operation=${op.type.name} id=${op.id} '
            'status=timeout elapsedMs=$elapsed → invoking onTimeout');
        _pending.remove(key);
        try {
          op.onTimeout();
        } catch (e) {
          debugPrint('[RESUME_COORDINATOR] onTimeout threw: $e');
        }
      }
      // If not expired, the existing timers/futures will complete normally
    }
  }

  /// Remove todas as operações — chamado no logout.
  void clear() {
    _pending.clear();
    _backgroundAt = null;
    // ORDEM 53: reset dos sinais ao fazer logout — evita disparo espúrio
    // na próxima sessão de outro usuário no mesmo dispositivo.
    backgroundSaveSignal.value = 0;
    contextTimeoutSignal.value = 0;
    debugPrint('[RESUME_COORDINATOR] cleared all pending ops + lifecycle signals');
  }

  /// Número de operações pendentes (para diagnóstico).
  int get pendingCount => _pending.length;
}
