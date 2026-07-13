import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User; // BUILD 309 S3 / BUILD 463-A.1
import 'package:flutter/foundation.dart';
// BUILD 326: sub-providers especializados
import 'ui_provider.dart';
import 'ai_chat_provider.dart';
// Import condicional: ls_web.dart (Web, usa dart:js) ou ls_stub.dart (iOS/Android, no-op).
// Isola dart:js do compilador nativo — resolve "Undefined name 'context'" no Xcode.
import '../services/ls_stub.dart'
    if (dart.library.js) '../services/ls_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/drug_model.dart';
import '../models/protocol_model.dart';
import '../models/clinical_case_model.dart';
import '../models/clinical_history_model.dart';
import '../models/user_model.dart';
import '../data/protocols_database.dart';
import '../data/cases_database.dart';
import '../services/firestore_service.dart';
import '../services/drug_interaction_service.dart';
import '../services/ai_service.dart';
import '../services/clinical_session_memory.dart';
import '../services/clinical_thread_manager.dart'; // BUILD 249: cross-case contamination fix
import '../services/gemini_service.dart';
import '../services/gemini_service_v2.dart';
import '../services/ai_gateway_service.dart';
import '../services/ai_smart_router.dart'; // Build 191: sanitizeResponse
import '../services/provider_router_service.dart'; // Build 226: Gemini Paid Fallback
import '../services/app_resume_coordinator.dart';   // BUILD 241: background/resume safety
import '../services/ai_stream/ai_event.dart';       // BUILD 462E-A: Anti-Frankenstein event bus
import '../services/ai_stream/gpt_sse_client.dart'; // BUILD 462E-A: per-request SSE client ref
import '../services/auth_service.dart';             // BUILD 462E-A: Web token refresh (getAdminToken)
import '../services/firebase_runtime_guard.dart';   // BUILD 463-A.1: SafeApps guard for auth boot-lock
import '../services/external_tool_link_engine.dart'; // MICRO-BUILD 462E-A.5.1: canonicalDecision routing
import '../services/ai_stream/truncation_inspector.dart'; // MICRO-BUILD 462E-A.5.1: TruncationInspector barrier
// Build 180: Sync Mi Guardia ↔ Adulto via Firestore dual-write
import '../screens/internacion/services/internacion_firestore_service.dart';
import '../screens/internacion/components/patient_accordion.dart' show PacienteInternacaoData;
import '../screens/internacion/services/internacion_persistence.dart' show PacienteSession;

// ── Resultado das operações de Pin no "Meu Plantão" ───────────────────────────
enum PinResult {
  success,        // item fixado com sucesso
  unpinned,       // item desafixado
  alreadyPinned,  // item já estava fixado (noop)
  limitReached,   // limite de itens atingido (sem replaceOldest)
}

// ── BUILD 462E-A.3: QA Gate evaluation result — pure, unit-testable ──────────
// Usado por AppProvider.evaluateQaGate() e test/services/qa_access_gate_test.dart
enum _QaGateResult {
  featureDisabled,  // kForceGptFallbackForQa=false → gate inativo
  firebaseUserNull, // FirebaseAuth.currentUser == null → não autenticado
  authorizedTester, // UID no allowlist OU isAdmin/isMaster=true → bypass permitido
  unauthorizedUser, // autenticado mas fora do allowlist e sem role → bypass negado
}

// ── BUILD 463-A.1: Authentication State Machine ───────────────────────────────
// SSOT para o estado de autenticação dual-identity (Firebase SDK + REST token).
// Elimina a race hazard onde FirestoreService reportava 'authed=true' via
// hasCachedToken enquanto FirebaseAuth.instance.currentUser == null.
//
// Transições permitidas:
//   authPending → authReady    : UID Firebase confirmado E UID local coincide
//   authPending → authRequired : Firebase pronto, nenhum usuário autenticado
//   authPending → authMismatch : UID Firebase diverge do UID local esperado
//   authPending → authFailed   : Exceção não-recuperável durante inicialização
//   authReady   → authPending  : início de ciclo de logout/login
enum AppAuthBarrierState {
  authPending,   // estado inicial — aguardando resolução do Firebase SDK
  authReady,     // Firebase UID confirmado E coincide com UID local
  authMismatch,  // UID Firebase diverge do UID local → SecuritySyndicationException
  authRequired,  // Firebase pronto, sem usuário autenticado
  authFailed,    // falha não-recuperável durante boot
}

// ── BUILD 463-A.1: Non-recoverable identity mismatch exception ───────────────
// Lançada quando FirebaseAuth.instance.currentUser?.uid != expectedAppUid após
// inicialização. Dispara wipe completo de SharedPreferences + cache de decisões.
class SecuritySyndicationException implements Exception {
  final String expectedUid;
  final String actualUid;
  final String reason;

  const SecuritySyndicationException({
    required this.expectedUid,
    required this.actualUid,
    required this.reason,
  });

  @override
  String toString() =>
      'SecuritySyndicationException: expectedUid=$expectedUid '
      'actualUid=$actualUid reason=$reason';
}

// ── Paciente salvo no Plantão/Guardia ─────────────────────────────────────────
class PlantaoPatient {
  final String id;          // UUID local
  final String name;        // Nome do paciente
  final String room;        // Leito / Quarto (ex: "204-A")
  final String diagnosis;   // Diagnóstico principal
  final String treatment;   // Tratamento em uso
  final String notes;       // Notas livres adicionais
  final DateTime savedAt;

  PlantaoPatient({
    required this.id,
    required this.name,
    required this.room,
    required this.diagnosis,
    required this.treatment,
    required this.notes,
    required this.savedAt,
  });

  PlantaoPatient copyWith({
    String? name,
    String? room,
    String? diagnosis,
    String? treatment,
    String? notes,
  }) => PlantaoPatient(
    id: id,
    name: name ?? this.name,
    room: room ?? this.room,
    diagnosis: diagnosis ?? this.diagnosis,
    treatment: treatment ?? this.treatment,
    notes: notes ?? this.notes,
    savedAt: savedAt,
  );

  // serialização simples separada por §
  String toRaw() =>
      '$id§${_esc(name)}§${_esc(room)}§${_esc(diagnosis)}§${_esc(treatment)}§${_esc(notes)}§${savedAt.millisecondsSinceEpoch}';

  static PlantaoPatient? fromRaw(String raw) {
    try {
      final p = raw.split('§');
      if (p.length < 7) return null;
      return PlantaoPatient(
        id: p[0],
        name: _unesc(p[1]),
        room: _unesc(p[2]),
        diagnosis: _unesc(p[3]),
        treatment: _unesc(p[4]),
        notes: _unesc(p[5]),
        savedAt: DateTime.fromMillisecondsSinceEpoch(int.tryParse(p[6]) ?? 0),
      );
    } catch (_) {
      return null;
    }
  }

  static String _esc(String s)   => s.replaceAll('§', '¶').replaceAll('\n', '↵');
  static String _unesc(String s) => s.replaceAll('¶', '§').replaceAll('↵', '\n');
}

class DoseInfo {
  final String main;
  final String detail;
  final List<String> alerts;
  DoseInfo({required this.main, required this.detail, required this.alerts});
}

class PatientData {
  String patientId;
  String age;
  String sex;
  String weight;
  String height;
  String creatinine;
  String medications; // medicamentos em uso atual
  PatientData({
    this.patientId = '',
    this.age = '',
    this.sex = 'M',
    this.weight = '',
    this.height = '',
    this.creatinine = '',
    this.medications = '',
  });
}

class HemoData {
  String sbp, dbp, na, cl, hco3, glucose;
  HemoData({
    this.sbp = '120', this.dbp = '80',
    this.na = '140', this.cl = '104',
    this.hco3 = '24', this.glucose = '100',
  });
}

class AppProvider extends ChangeNotifier {
  // ── BUILD 326: Sub-providers especializados ───────────────────────────────
  // Expõos como campos públicos para que main.dart possa registrá-los
  // no MultiProvider e as telas possam consumir diretamente via
  // context.watch<UiProvider>() ou context.select<AiChatProvider, T>().
  //
  // AppProvider mantém fachada completa — todos os getters legados
  // continuam funcionando como proxies. Zero mudanças nos call sites.
  final UiProvider    uiProvider     = UiProvider();
  final AiChatProvider aiChatProvider = AiChatProvider();

  // SUPER ORDEM MASTER 315: ValueNotifier para restaurar aba pós-OAuth redirect.
  // connectGemini() salva o índice em localStorage antes do reload.
  // checkGeminiSession() dispara o notifier em runtime (não em initState).
  // MainShell ouve o notifier via addListener — responde a qualquer momento.
  // -1 = inativo; >= 0 = índice da aba a restaurar (consome e reseta para -1).
  static final postOAuthTabNotifier = ValueNotifier<int>(-1);

  // SUPER ORDEM MASTER 14 M3: flag legada — mantida como no-op para não quebrar
  // builds anteriores que possam referenciar o símbolo. Ignorada pelo MainShell.
  @Deprecated('Use postOAuthTabNotifier. Removido no Build 315.')
  static bool postOAuthAiTab = false;

  // ── Idioma padrão baseado no locale do sistema operacional ────────────────
  /// Retorna 'pt' para português (pt, pt_BR) e 'es' para qualquer outro idioma.
  /// Usado apenas quando o usuário nunca escolheu um idioma explicitamente.
  static String _systemLang() {
    final locale = ui.PlatformDispatcher.instance.locale;
    return locale.languageCode == 'pt' ? 'pt' : 'es';
  }

  // ── Estado Firebase ───────────────────────────────────────────────────────
  UserModel? _currentUser;
  bool _firebaseReady = false;

  // ── BUILD 463-A.1: Auth Barrier State Machine ─────────────────────────────
  // SSOT para o estado de autenticação dual-identity.
  // Inicializa como authPending — transiciona em setUser() / clearUser().
  AppAuthBarrierState _currentAuthBarrierState = AppAuthBarrierState.authPending;

  // ── Estado local ──────────────────────────────────────────────────────────
  String _lang = _systemLang();
  bool _darkMode = true; // DARK-FIRST: inicializa sempre em modo escuro
  bool _hapticEnabled = true; // feedback tátil — ligado por padrão

  PatientData _patient = PatientData();
  HemoData _hemo = HemoData();

  List<String> _selectedDrugIds = [];
  String _activeDrugId = '';

  List<ClinicalCaseModel> _customCases = [];
  Set<String> _favDrugs = {};
  Set<String> _favProtocols = {};
  Set<String> _favPrescriptions = {};
  Set<String> _favCases = {};

  // ── Estado — Meu Plantão (itens fixados) ──────────────────────────────────
  // Listas ordenadas: o primeiro item é o mais recente.
  // Limite: 5 fármacos, 3 calculadoras.
  // Persistência: SharedPreferences com prefixo por uid (sem Firestore —
  // preferência puramente local do dispositivo, não precisa de sync cross-device).
  static const int _kMaxPinnedDrugs = 5;
  static const int _kMaxPinnedCalcs = 3;
  List<String> _pinnedDrugIds = [];   // IDs de DrugModel
  List<String> _pinnedCalcIds = [];   // IDs de atalho de calculadora

  // ── Estado — Pacientes do Plantão ─────────────────────────────────────────
  List<PlantaoPatient> _plantaoPatients = [];

  // ── BUILD 427: Tools Input Cache (RAM-only, volátil por sessão) ───────────
  // Persiste os valores dos inputs das 4 telas de ferramentas enquanto o médico
  // navega entre abas. Desmontagem de uma tela salva aqui; remontagem oferece
  // restauração via pop-up discreto. Sem persistência em disco — limpa ao fechar.
  //
  // Chaves canônicas (snake_case neutro, compartilhadas pelas 4 telas):
  //   'edad'       — idade do paciente (string inteiro)
  //   'sodio'      — sódio sérico mg/dL ou mEq/L
  //   'creatinina' — creatinina sérica mg/dL
  //   'bilirrubina'— bilirrubina total mg/dL
  //   'inr'        — RNI / INR
  //   'albumina'   — albumina g/dL
  //   'ast'        — AST U/L
  //   'alt'        — ALT U/L
  //   'plaquetas'  — plaquetas ×10³/µL
  //   'peso'       — peso corporal kg
  //   'sexo'       — 'M' ou 'F'
  // BUILD 430 PASSO 2: campos expandidos para cobrir todas as 4 calculadoras.
  //   Cardio   : 'pas', 'colesterol', 'qtms', 'fc'
  //   Electrolytes: 'cloro', 'hco3', 'glicose', 'calcio', 'bun'
  //   Nephrology: já coberta por 'creatinina', 'sodio', 'edad', 'peso', 'sexo'
  //   Hepatology: já coberta por todos os campos originais
  final Map<String, String> toolsInputCache = {
    // Demográficos
    'edad':        '',
    'sexo':        '',
    'peso':        '',
    // Eletrólitos / Nefrologia
    'sodio':       '',
    'cloro':       '',
    'hco3':        '',
    'glicose':     '',
    'calcio':      '',
    'bun':         '',
    'creatinina':  '',
    // Hepatologia
    'bilirrubina': '',
    'inr':         '',
    'albumina':    '',
    'ast':         '',
    'alt':         '',
    'plaquetas':   '',
    // Cardio
    'pas':         '',
    'colesterol':  '',
    'qtms':        '',
    'fc':          '',
  };

  /// Retorna true se o cache contém pelo menos um campo clínico relevante preenchido.
  // BUILD 430 PASSO 2: inclui todos os campos expandidos na checagem de dados.
  bool get toolsCacheHasData {
    const keys = [
      'edad', 'creatinina', 'bilirrubina', 'inr', 'albumina',
      'ast', 'alt', 'plaquetas', 'sodio', 'cloro', 'hco3',
      'glicose', 'calcio', 'bun', 'pas', 'colesterol',
    ];
    return keys.any((k) => (toolsInputCache[k] ?? '').trim().isNotEmpty);
  }

  /// Salva um conjunto de valores no cache. Não notifica ouvintes (apenas RAM).
  void saveToolsCache(Map<String, String> values) {
    values.forEach((k, v) {
      if (toolsInputCache.containsKey(k)) toolsInputCache[k] = v;
    });
  }

  /// Limpa todos os campos do cache.
  void clearToolsCache() {
    for (final k in toolsInputCache.keys) {
      toolsInputCache[k] = '';
    }
  }

  // ── BUILD 428: Active Imported Patient Pointer ────────────────────────────
  // Rastreia qual paciente foi importado pelo médico nas ferramentas de cálculo.
  // Permite o sync bilateral: ao calcular, o resultado é gravado de volta no
  // Firestore do paciente selecionado. Limpa ao fechar o app (RAM-only).
  //
  // activeImportedSession: sessão completa selecionada no modal (nome, cama, etc.)
  // activeImportedPatientKey: chave canônica Firestore (sessionKey) do doc
  PacienteSession? activeImportedSession;
  String?         activeImportedPatientKey;

  /// Registra o paciente ativo importado pelas ferramentas.
  /// Chamado no momento da seleção no modal showToolsPatientSelectionSheet.
  void setActiveImportedPatient(PacienteSession session) {
    activeImportedSession   = session;
    activeImportedPatientKey = session.sessionKey;
    // Não notifica ouvintes — é um ponteiro interno, não causa re-build de UI
  }

  /// Remove o ponteiro de paciente ativo (ex: ao trocar de paciente ou descartar).
  void clearActiveImportedPatient() {
    activeImportedSession    = null;
    activeImportedPatientKey = null;
  }

  // ── Estado — Histórias Clínicas ───────────────────────────────────────────
  List<ClinicalHistoryModel> _myHistories = [];
  List<ClinicalHistoryModel> _publicHistories = [];
  bool _isLoadingPublic = false;
  String _publicLoadError = '';

  // SYNC-FIX: Stream reativo para histórias do usuário no mobile.
  // Garante que dados criados na Web aparecem imediatamente no iOS
  // sem necessidade de reiniciar o app ou fazer pull-to-refresh.
  StreamSubscription<List<ClinicalHistoryModel>>? _historiesStreamSub;

  String get publicLoadError => _publicLoadError;

  // ── Rastreamento de uso ────────────────────────────────────────────────────
  Timer? _usageTimer;
  int _sessionSeconds = 0;    // segundos acumulados nesta sessão (flush a cada 60s)
  bool _usagePaused = false;  // true quando app está em background

  // ── Estado — IA Clínica ──────────────────────────────────────────────────
  String _openAiKey = '';
  bool _aiKeyLoading = false; // true enquanto busca chave no Firestore
  // Histórico de conversa para contexto multi-turn (máx 10 pares)
  final List<Map<String, String>> _aiHistory = [];

  // ── HOTFIX BUILD 247D — HistorySanitizer ─────────────────────────────────
  //
  // Impede context poisoning / parroting: mensagens de fallback, safe-card,
  // timeout e erro técnico NÃO são enviadas ao Gemini como contexto.
  // Elas continuam visíveis na UI local, mas são excluídas do histórico da API.
  //
  // Padrões de fallback / safe-card / erro que envenenam o contexto:
  static bool _isFallbackText(String text) {
    if (text.isEmpty) return false;
    final t = text;
    // Safe-card de timeout (marcadores canônicos de AppProvider)
    if (t.contains('TEMPO LIMITE ATINGIDO'))       return true;
    if (t.contains('TIEMPO LÍMITE ALCANZADO'))      return true;
    if (t.contains('TEMPO LÍMITE ALCANZADO'))       return true;
    // BUILD 267: _clinicalFallback EXTINTO — strings abaixo nunca mais geradas.
    // Mantidas APENAS como guard legado para históricos antigos em cache.
    if (t.contains('REVISANDO RESPOSTA'))           return true;
    if (t.contains('RESPOSTA EM AJUSTE'))           return true;
    if (t.contains('resposta continha dados inconsistentes')) return true;
    if (t.contains('respuesta contenía datos inconsistentes')) return true;
    if (t.contains('bloqueada por segurança'))      return true;
    if (t.contains('bloqueada por seguridad'))      return true;
    if (t.contains('estamos ajustando'))            return true;
    if (t.contains('instabilidade temporária'))     return true;
    if (t.contains('inestabilidad temporal'))       return true;
    if (t.contains('Tente novamente em alguns segundos')) return true;
    if (t.contains('Intenta nuevamente en algunos segundos')) return true;
    return false;
  }

  /// Retorna _aiHistory filtrado — sem mensagens de fallback/safe-card.
  /// Usado como camada de segurança ao passar contexto ao Gemini.
  /// Belt-and-suspenders: mesmo que algum push tenha escapado, o read é limpo.
  List<Map<String, String>> get _sanitizedHistory {
    final before = _aiHistory.length;
    final filtered = _aiHistory.where((m) {
      final role    = m['role']    ?? '';
      final content = m['content'] ?? '';
      // Só filtra mensagens da IA (assistant) — mensagens do usuário sempre entram
      if (role != 'assistant') return true;
      return !_isFallbackText(content);
    }).toList();
    final removed = before - filtered.length;
    if (kDebugMode && removed > 0) {
      debugPrint('[HISTORY_SANITIZER] removedFallbackMessages=$removed finalHistoryMessages=${filtered.length}');
    }
    return filtered;
  }

  // ── Fix 3: Memória clínica estruturada da sessão ──────────────────────────
  // Instância única por sessão de chat — reseta automaticamente ao mudar de tema.
  // Não persiste entre sessões (RAM only, by design).
  final ClinicalSessionMemory _sessionMemory = ClinicalSessionMemory();

  // ── BUILD 249: ClinicalThreadManager — anti-cross-case contamination ──────
  // Rastreia thread clínico ativo. Decide se nova query é follow-up do caso
  // atual ou início de novo caso. Em Modo Plantão:
  //   isContinuation=true  → envia contexto mínimo (últimos 3 pares)
  //   isContinuation=false → limpa _aiHistory, envia histórico VAZIO
  // Em Modo Estudo: não interfere, usa história completa sanitizada.
  final ClinicalThreadManager _threadManager = ClinicalThreadManager();

  // ── PRIORIDADE 3 — globalLanguageLock() ───────────────────────────────────
  // Bloqueia o idioma da IA na primeira mensagem da sessão.
  // Se o usuário iniciou em ES → toda a sessão responde em ES (vice-versa PT).
  // Build 190 — LANGUAGE LOCK ABSOLUTO:
  // _sessionLockedLang mantido apenas por compatibilidade de interface.
  // A única variável soberana é _lang (idioma configurado pelo usuário no app).
  // A pergunta pode estar em QUALQUER idioma — a resposta SEMPRE usa _lang.
  String? _sessionLockedLang;

  /// Build 190 — Language Lock Absoluto.
  /// Retorna SEMPRE _lang (idioma do app). A detecção por idioma da pergunta
  /// foi removida por ser a causa raiz de respostas mistas PT+ES.
  /// A pergunta pode estar em qualquer idioma. A resposta usa exclusivamente o
  /// idioma configurado pelo usuário (appLanguage = _lang: 'pt' | 'es').
  String _resolveSessionLang(String input) {
    // Build 190 / BUILD 248: _lang é soberano. Nunca detectamos idioma da pergunta.
    // _sessionLockedLang agora apenas espelha _lang para compatibilidade.
    // O idioma da resposta é EXCLUSIVAMENTE o idioma configurado no app (_lang).
    _sessionLockedLang = _lang;
    if (kDebugMode) {
      debugPrint('[LANG_LOCK] appLanguage=$_lang inputIgnored=true responseLanguage=$_lang');
    }
    return _lang;
  }

  // ── Estado — Gemini OAuth (paralelo ao OpenAI, nunca interfere) ───────────
  bool _geminiConnected = false;   // true quando conta Google autorizada
  bool _geminiLoading   = false;   // true durante signIn/signOut
  String _geminiEmail   = '';      // e-mail exibido na UI
  static const _geminiRetryCooldown = Duration(minutes: 2);
  DateTime? _geminiRetryAfter;
  Future<void>? _geminiSessionCheckInFlight;
  bool _geminiApiKeyUnavailable = false;

  // BUILD 290: Future que representa a execução em-voo de _syncFromFirestore().
  // checkGeminiSession() faz `await _firestoreSyncFuture` — zero polling, zero
  // delay artificial. Se o sync terminar em 80ms, o boot segue em 80ms.
  // Resetado para null no logout para que a próxima sessão crie um novo Future.
  Future<void>? _firestoreSyncFuture;
  // BUILD 291: uid do sync em-voo — guard de idempotência para evitar duplo sync.
  // Se setUser() for chamado duas vezes para o mesmo uid (stream re-emit, rebuild),
  // o segundo _syncFromFirestore() retorna o Future já em voo em vez de iniciar novo.
  String? _firestoreSyncUid;

  // BUILD 293: flag de sessão — o SecurityWipe só deve rodar UMA vez por login.
  // Sem esta flag, o wipe apaga a chave → rebuild do stream → setUser() re-chamado
  // → checkGeminiSession() → wipe novamente → loop infinito no Safari/Web.
  // Resetado para false em clearUser() para que o próximo login possa wipear.
  bool _apiKeyWipedThisSession = false;

  // ── Estado — Modo Offline ──────────────────────────────────────────────────
  bool _offlineMode      = false;  // true = sem rede, usa só cache local
  bool _offlineCaching   = false;  // true durante o processo de cache
  double _offlineProgress = 0.0;   // 0.0 → 1.0 durante caching
  DateTime? _offlineCachedAt;      // quando foi feito o último cache

  // ── Getters públicos ──────────────────────────────────────────────────────
  UserModel? get currentUser => _currentUser;
  bool get firebaseReady => _firebaseReady;
  // BUILD 463-A.1: expõe estado da barreira de auth para FirestoreService e UI.
  AppAuthBarrierState get authBarrierState => _currentAuthBarrierState;
  bool get loggedIn => _currentUser != null && _currentUser!.isApproved;
  bool get isPending => _currentUser != null && _currentUser!.isPending;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isSupervisor => _currentUser?.isSupervisor ?? false;
  bool get isMaster => _currentUser?.isMaster ?? false;
  bool get canModerateContent => (_currentUser?.isAdmin ?? false) || (_currentUser?.isSupervisor ?? false);
  String get userName => _currentUser?.displayName ?? '';
  String get userEmail => _currentUser?.email ?? '';
  // BUILD 326: proxies para UiProvider — zero breaking changes nos call sites.
  String get lang          => uiProvider.lang;
  bool   get darkMode      => uiProvider.darkMode;
  bool   get hapticEnabled => uiProvider.hapticEnabled;
  /// BUILD 249: expõe tópico ativo do thread clínico para EXT_TOOL guard
  String get activeThreadTopic => _threadManager.activeTopic;
  PatientData get patient => _patient;
  HemoData get hemo => _hemo;
  String get activeDrugId => _activeDrugId;
  List<String> get selectedDrugIds => _selectedDrugIds;
  Set<String> get favDrugs => _favDrugs;
  Set<String> get favProtocols => _favProtocols;
  Set<String> get favPrescriptions => _favPrescriptions;
  Set<String> get favCases => _favCases;

  // ── Getters — Meu Plantão ─────────────────────────────────────────────────
  /// Limite público de fármacos fixáveis (usado pela UI para exibir texto de limite).
  static int get kMaxPinnedDrugsPublic => _kMaxPinnedDrugs;
  /// Limite público de calculadoras fixáveis (usado pela UI para exibir texto de limite).
  static int get kMaxPinnedCalcsPublic => _kMaxPinnedCalcs;

  List<String> get pinnedDrugIds => List.unmodifiable(_pinnedDrugIds);
  List<String> get pinnedCalcIds => List.unmodifiable(_pinnedCalcIds);
  List<PlantaoPatient> get plantaoPatients => List.unmodifiable(_plantaoPatients);

  /// Fármacos fixados resolvidos (DrugModel). Filtra IDs inválidos silenciosamente.
  List<DrugModel> get pinnedDrugs {
    final result = <DrugModel>[];
    for (final id in _pinnedDrugIds) {
      try {
        result.add(drugsDB.firstWhere((d) => d.id == id));
      } catch (_) {}
    }
    return result;
  }

  bool isDrugPinned(String id) => _pinnedDrugIds.contains(id);
  bool isCalcPinned(String id) => _pinnedCalcIds.contains(id);
  List<ClinicalCaseModel> get customCases => _customCases;

  // ── Getters — Histórias Clínicas ─────────────────────────────────────────
  List<ClinicalHistoryModel> get myHistories => _myHistories;
  List<ClinicalHistoryModel> get publicHistories => _publicHistories;
  bool get isLoadingPublic => _isLoadingPublic;

  // ── Getters — IA ─────────────────────────────────────────────────────────
  String get openAiKey => _openAiKey;
  // Build 156.2: hasAiKey inclui a chave Gemini do app (carregada do Firestore
  // pelo admin) — não depende mais apenas de _openAiKey (chave OpenAI legada).
  bool get hasAiKey => _openAiKey.isNotEmpty || GeminiService.hasApiKey;
  bool get aiKeyLoading => _aiKeyLoading;

  // ── Getters — Gemini OAuth ────────────────────────────────────────────────
  bool get geminiConnected => _geminiConnected;
  bool get geminiLoading   => _geminiLoading;
  String get geminiEmail   => _geminiEmail;
  /// true quando qualquer IA real está disponível (chave Gemini do app OU OpenAI legada OU sessão OAuth Gemini)
  /// Build 156.2: inclui GeminiService.hasApiKey — chave do app carregada silenciosamente
  /// do Firestore após o login do médico via Google Sign-In / Firebase Auth.
  /// O médico nunca configura nada manualmente — fluxo 100% automático e invisível.
  bool get hasAnyAi => GeminiService.hasApiKey || _openAiKey.isNotEmpty || _geminiConnected;

  // ── BUILD 326: aiStreaming proxy → AiChatProvider ─────────────────────────
  /// Indica se há streaming ativo. Proxy para AiChatProvider.aiStreaming.
  /// A ai_screen usa context.select<AiChatProvider, bool>(p => p.aiStreaming)
  /// para rebuild cirúrgico. Este getter mantém compatibilidade legada.
  bool get aiStreaming => _aiStreamActive;

  // ── Getters — Modo Offline ────────────────────────────────────────────────
  bool   get offlineMode      => _offlineMode;
  bool   get offlineCaching   => _offlineCaching;
  double get offlineProgress  => _offlineProgress;
  DateTime? get offlineCachedAt => _offlineCachedAt;

  // ── Cache imutável (calculado uma vez no primeiro acesso) ────────────────
  // BUILD 325: drugsDB retorna lista vazia — banco de fármacos migrado para WebView.
  List<DrugModel> get drugsDB => const [];
  List<ProtocolModel> get protocolsDB => protocolsDatabase;
  List<ClinicalCaseModel> get casesDB => casesDatabase;

  DrugModel? get activeDrug => null;

  List<DrugModel> get selectedDrugs => const [];

  // ── Login com usuário do Firebase ─────────────────────────────────────────
  Future<void> setUser(UserModel user) async {
    // ── BUILD 463-A.1: Auth Convergence Boot-Lock ─────────────────────────
    // SECTOR 2: Inserir trava de boot no ponto de entrada do ciclo de auth.
    // Garante que o Firebase SDK confirmou o estado de identidade antes de
    // qualquer operação Firestore ou escrita de preferências de usuário.
    _currentAuthBarrierState = AppAuthBarrierState.authPending;

    final bool restTokenPresent = AuthService.hasCachedToken;
    final bool geminiOAuthPresent = _geminiConnected || (kIsWeb && (
      (_webGetLS('gemini_google_email') ?? '').isNotEmpty
    ));
    final String expectedUid = user.uid;
    User? fbSdkUser;

    try {
      // ── Telemetria [AUTH_CONVERGENCE][START] ───────────────────────────
      debugPrint('[AUTH_CONVERGENCE][START] '
          'expectedUid=$expectedUid '
          'firebaseUid=${FirebaseAuth.instance.currentUser?.uid ?? 'null'} '
          'restTokenPresent=$restTokenPresent '
          'geminiOAuthPresent=$geminiOAuthPresent');

      // ── Await latch: aguarda o Firebase SDK emitir seu primeiro estado ──
      // Se Firebase não está pronto (Safari modo privado), pula a latch
      // silenciosamente para não travar o boot.
      if (FirebaseRuntimeGuard.isReady) {
        debugPrint('[AUTH_CONVERGENCE][WAITING_FOR_SDK]');
        try {
          fbSdkUser = await FirebaseAuth.instance
              .authStateChanges()
              .first
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
        } catch (e) {
          debugPrint('[AUTH_CONVERGENCE][WAITING_FOR_SDK] timeout/error: $e — continuando com currentUser');
          fbSdkUser = FirebaseAuth.instance.currentUser;
        }
      } else {
        fbSdkUser = null;
      }

      // ── Hydration: SDK null mas REST token presente → tenta custom token ─
      // (apenas em plataformas onde Firebase está disponível)
      if (fbSdkUser == null && restTokenPresent && FirebaseRuntimeGuard.isReady) {
        debugPrint('[AUTH_CONVERGENCE][WAITING_FOR_SDK] '
            'fbUser=null restToken=present — aguardando propagação SDK...');
        // Aguarda até 3s pelo stream emitir o usuário (pode demorar se o
        // token REST ainda está sendo trocado pelo SDK internamente).
        try {
          fbSdkUser = await FirebaseAuth.instance
              .authStateChanges()
              .where((u) => u != null)
              .first
              .timeout(const Duration(seconds: 3), onTimeout: () => null);
        } catch (_) {
          fbSdkUser = FirebaseAuth.instance.currentUser;
        }
      }

      // ── Security Wipe Trap: UID mismatch → falha controlada ─────────────
      final String fbUid = fbSdkUser?.uid ?? '';
      final bool uidsMatch = fbUid.isEmpty || fbUid == expectedUid;

      if (!uidsMatch) {
        // [SECURITY_GATE] SHIELD DISPATCHED → IDENTITY MISMATCH DETECTED
        debugPrint('[SECURITY_GATE] SHIELD DISPATCHED -> IDENTITY MISMATCH DETECTED. '
            'expectedUid=$expectedUid firebaseUid=$fbUid');
        debugPrint('[AUTH_CONVERGENCE][FAILED] reason=uid_mismatch '
            'expectedUid=$expectedUid firebaseUid=$fbUid');
        _currentAuthBarrierState = AppAuthBarrierState.authMismatch;
        // Wipe completo de estado local
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        if (kIsWeb) {
          try {
            _webRemoveLS('medcases_gak');
            _webRemoveLS('gemini_google_email');
            _webRemoveLS('medcases_gsi_pending');
          } catch (_) {}
        }
        // Purge LinkedHashMap de decisões — evita que dados do user anterior
        // contaminem o próximo usuário.
        ExternalToolLinkEngine.releaseByRequestId(expectedUid);
        throw SecuritySyndicationException(
          expectedUid: expectedUid,
          actualUid: fbUid,
          reason: 'uid_mismatch_at_setUser',
        );
      }

      // ── Transição para authReady ─────────────────────────────────────────
      _currentAuthBarrierState = AppAuthBarrierState.authReady;
      debugPrint('[AUTH_CONVERGENCE][READY] '
          'firebaseUid=${fbUid.isEmpty ? expectedUid : fbUid} '
          'uidsMatch=true');

    } catch (e) {
      if (e is SecuritySyndicationException) rethrow;
      // Falha inesperada durante boot-lock — falha aberta (não bloqueia app)
      debugPrint('[AUTH_CONVERGENCE][FAILED] reason=firebase_user_null '
          'error=$e — continuando com authReady (degraded mode)');
      _currentAuthBarrierState = AppAuthBarrierState.authReady;
    }

    _currentUser = user;
    _lang = user.lang;
    _darkMode = user.darkMode;
    _firebaseReady = true;

    // 1️⃣ Carrega cache local IMEDIATAMENTE — app responde sem esperar rede
    await _loadFromLocal(uid: user.uid);

    // 2️⃣ Carrega chaves do Firestore com AWAIT — timeout reduzido para 2s.
    //    GeminiService.initFromStorage() já foi chamado em _bootInBackground()
    //    então a chave local já está disponível; Firestore apenas atualiza.
    //    Timeout 2s: resposta rápida em redes OK; fallback para cache local.
    await _loadAiKeyFromFirestore(user.uid).timeout(
      const Duration(seconds: 2),
      onTimeout: () { _aiKeyLoading = false; },
    );

    // 3️⃣ Sincroniza Firestore em background — não bloqueia a UI.
    // BUILD 290: guarda o Future para que checkGeminiSession() possa fazer
    // await determinístico sem polling ou delay artificial.
    // BUILD 291: idempotência — se já existe sync em voo para este uid, reutiliza
    // o Future existente em vez de disparar segundo sync concorrente.
    // Cenário: _WebMainShellGate chama setUser() e o stream de auth re-emite
    // o mesmo uid durante o boot — sem este guard, _syncFromFirestore roda 2x.
    if (_firestoreSyncFuture == null || _firestoreSyncUid != user.uid) {
      _firestoreSyncUid    = user.uid;
      _firestoreSyncFuture = _syncFromFirestore(user.uid);
    } else {
      debugPrint('[BUILD291][SYNC_DEDUP] sync já em voo para uid=${user.uid} — reutilizando Future existente');
    }

    // 4️⃣ Carrega histórias públicas AQUI — token já está cacheado neste ponto.
    loadPublicHistories();

    // 5️⃣ Restaura sessão Gemini em background — silencioso, não bloqueia UI
    // Safari ITP: verifica também sessionStorage (imune ao ITP no redirect)
    final _hasPendingOAuth = kIsWeb && (
      _webGetLS('medcases_gsi_pending') == 'true' ||
      _webSsGet('medcases_gsi_pending') == 'true'
    );
    Future.delayed(
      _hasPendingOAuth
          ? const Duration(seconds: 1)  // dá tempo ao fetch tokeninfo JS completar
          : Duration.zero,
      checkGeminiSession,
    );

    // 6️⃣ Inicia contador de tempo de uso
    _startUsageTimer(user.uid);

    // 7️⃣ Registra acesso — incrementa loginCount e atualiza lastSeenAt no Firestore
    // Silencioso: falha não bloqueia o app
    FirestoreService.incrementLoginCount(user.uid);
  }

  // ── Timer de uso ──────────────────────────────────────────────────────────
  // Conta tempo de tela REAL: inicia ao abrir o app, pausa no background,
  // retoma ao trazer o app de volta. Grava no Firestore a cada 60s.
  // Não depende de cliques, pesquisas ou digitação — mede presença na tela.
  void _startUsageTimer(String uid) {
    _usageTimer?.cancel();
    _sessionSeconds = 0;
    _usagePaused = false;
    _usageTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_usagePaused) return; // app em background — não conta
      _sessionSeconds++;
      // Flush a cada 60 segundos → 1 escrita no Firestore por minuto de uso
      if (_sessionSeconds % 60 == 0) {
        FirestoreService.incrementUsage(uid, 60);
      }
    });
  }

  /// Pausa o timer quando o app vai para background (não cancela — mantém estado).
  /// Chamado pelo MainShell via didChangeAppLifecycleState(paused/hidden/inactive)
  /// ou pelo visibilitychange handler (Web).
  /// [fromVisibility]: true quando chamado via visibilitychange handler
  ///   (coordinator.onBackground já foi chamado pelo handler diretamente).
  void pauseUsageTimer({bool fromVisibility = false}) {
    if (_usageTimer == null || _usagePaused) return;
    _usagePaused = true;
    // Flush imediato dos segundos acumulados antes de pausar
    final uid = _currentUser?.uid;
    if (uid != null) {
      final residual = _sessionSeconds % 60;
      if (residual > 0) FirestoreService.incrementUsage(uid, residual);
      _sessionSeconds = (_sessionSeconds ~/ 60) * 60; // zera o residual
    }
    debugPrint('[UsageTimer] pausado — app em background');
    // BUILD 241: notifica coordinator que app foi para background.
    // Não chama se já foi chamado pelo visibilitychange handler.
    if (!fromVisibility) {
      AppResumeCoordinator.instance.onBackground();
    }
  }

  /// Retoma o timer quando o app volta ao foreground.
  /// Chamado pelo MainShell via didChangeAppLifecycleState(resumed)
  /// ou pelo visibilitychange handler (Web).
  /// [fromVisibility]: true quando chamado via visibilitychange handler
  ///   (coordinator.onForeground já foi chamado pelo handler diretamente).
  void resumeUsageTimer({bool fromVisibility = false}) {
    if (_usageTimer == null) {
      // Timer não existe ainda — pode ter sido cancelado; reinicia
      final uid = _currentUser?.uid;
      if (uid != null) _startUsageTimer(uid);
    } else if (_usagePaused) {
      _usagePaused = false;
      debugPrint('[UsageTimer] retomado — app em foreground');
    }
    // BUILD 241: verifica operações pendentes com base em tempo real.
    // Não chama onForeground() se já foi chamado pelo visibilitychange handler.
    if (!fromVisibility) {
      AppResumeCoordinator.instance.onForeground();
    }
  }

  void _stopUsageTimer() {
    final uid = _currentUser?.uid;
    if (uid != null && _sessionSeconds > 0) {
      // Grava os segundos residuais que ainda não foram enviados
      final residual = _sessionSeconds % 60;
      if (residual > 0) FirestoreService.incrementUsage(uid, residual);
    }
    _usageTimer?.cancel();
    _usageTimer = null;
    _sessionSeconds = 0;
    _usagePaused = false;
  }

  void clearUser() {
    _stopUsageTimer();
    _cancelHistoriesStream(); // SYNC-FIX: cancela stream reativo ao fazer logout
    AppResumeCoordinator.instance.clear(); // BUILD 241: clear pending ops on logout
    _currentUser = null;
    _firebaseReady = false;
    // BUILD 463-A.1: reset barrier — próximo login inicia de authPending.
    _currentAuthBarrierState = AppAuthBarrierState.authPending;
    _favDrugs = {};
    _favProtocols = {};
    _favPrescriptions = {};
    _favCases = {};
    _customCases = [];
    _myHistories = [];
    _publicHistories = [];
    _selectedDrugIds = [];
    _activeDrugId = '';
    _patient = PatientData();
    _hemo = HemoData();
    // Limpa chave, histórico de IA e estado Gemini ao fazer logout
    _openAiKey = '';
    _aiHistory.clear();
    _sessionMemory.reset();                  // BUILD 326.1: limpa memória clínica (diag, meds, labs) — evita leak entre contas
    _threadManager.reset();                  // BUILD 249: reset thread clínico ao fazer logout
    ClinicalThreadManager.resetStaticState(); // BUILD 304 PURIF-1: limpa _lastTaskLabel/_lastStudyActivityMs
    _geminiConnected = false;
    _geminiEmail = '';
    _geminiRetryAfter = null;
    _geminiSessionCheckInFlight = null;
    _geminiApiKeyUnavailable = false;
    // BUILD 290/291: reseta Future e uid de sync — próxima sessão cria um novo.
    _firestoreSyncFuture = null;
    _firestoreSyncUid    = null;
    // BUILD 293: reseta flag de wipe — próximo login pode wipear novamente.
    _apiKeyWipedThisSession = false;
    // Limpa plantão (recarregado ao próximo login)
    _pinnedDrugIds = [];
    _pinnedCalcIds = [];
    _plantaoPatients = [];
    // BUILD 326: limpa sub-providers no logout.
    aiChatProvider.clearOnLogout();
    notifyListeners();
  }

  void setFirebaseReady() {
    _firebaseReady = true;
    notifyListeners();
  }

  // ── Chave OpenAI — prioridade: app global → usuário individual → cache local
  //
  // Hierarquia:
  //  1. app_config/global.openAiKey  → chave do app (admin configura, todos usam)
  //  2. users/{uid}/prefs/settings.openAiKey → chave individual (legado / admin)
  //  3. SharedPreferences local → fallback offline
  Future<void> _loadAiKeyFromFirestore(String uid) async {
    try {
      // Carrega OpenAI Key e Gemini API Key em paralelo — mais rápido
      // CRÍTICO: geminiApiKey NUNCA tem return prematuro — deve sempre ser carregada
      final results = await Future.wait([
        FirestoreService.loadAppAiKey(),
        FirestoreService.loadGeminiApiKey(),
      ]);

      final appKey    = results[0];
      final geminiKey = results[1];

      // ── OpenAI Key ──────────────────────────────────────────────────────────
      if (appKey.isNotEmpty) {
        _openAiKey = appKey;
        final p = await SharedPreferences.getInstance();
        await p.setString(_k('openAiKey', uid), appKey);
      } else {
        // Fallback: chave individual do usuário (legado)
        final userKey = await FirestoreService.loadAiKey(uid);
        if (userKey.isNotEmpty) {
          _openAiKey = userKey;
          final p = await SharedPreferences.getInstance();
          await p.setString(_k('openAiKey', uid), userKey);
        }
      }

      // ── Gemini Free Key — injeta no GeminiService + cacheia localmente ──────
      // Fonte: app_config/global.apiKey (lido por todos os usuários aprovados)
      // NÃO é a GEMINI_PAID_API_KEY — essa fica só no Firebase Secret server-side.
      if (geminiKey.isNotEmpty) {
        GeminiService.setGeminiApiKey(geminiKey, source: GeminiKeySource.appConfig); // BUILD 294: marca como appConfig — SecurityWipe nunca apaga
        debugPrint('[AI_FREE_PROVIDER] source=app_config/global ready=true (login load)');
      } else {
        // Firestore retornou vazio — tenta SharedPreferences/localStorage
        if (!GeminiService.hasApiKey) {
          await GeminiService.initFromStorage();
        }
        if (GeminiService.hasApiKey) {
          debugPrint('[AI_FREE_PROVIDER] source=localStorage/SharedPrefs ready=true (login load)');
        } else {
          debugPrint('[AI_FREE_PROVIDER] source=none ready=false — app_config/global vazio e sem cache local');
          debugPrint('[AppProvider] Gemini API Key não encontrada em nenhuma fonte');
        }
      }

      _aiKeyLoading = false;
      notifyListeners();
    } catch (_) {
      // Sem rede: tenta cache local para OpenAI
      try {
        final p = await SharedPreferences.getInstance();
        _openAiKey = p.getString(_k('openAiKey', uid)) ?? '';
      } catch (_) {}
      // Restaura Gemini Key do SharedPrefs/localStorage se Firestore falhou
      if (!GeminiService.hasApiKey) {
        await GeminiService.initFromStorage();
        if (GeminiService.hasApiKey) {
          debugPrint('[AppProvider] Gemini Key restaurada do SharedPrefs (rede falhou) ✓');
        }
      }
      _aiKeyLoading = false;
      notifyListeners();
    }
  }

  // ── Sincronização background com Firestore ────────────────────────────────
  // Chamado APÓS _loadFromLocal — atualiza silenciosamente quando há rede.
  // MERGE STRATEGY: une Firestore + local para nunca perder favoritos.
  // Se Firestore retorna vazio mas local tem dados, o resultado final = local.
  Future<void> _syncFromFirestore(String uid) async {
    // BUILD 290: SYNC_TRACE — instrumentação científica para isolar
    // short-circuits e silent exceptions. Cada await tem marcador próprio.
    debugPrint('[SYNC_TRACE][START] Iniciando sincronismo para o uid: $uid');
    try {
      // Snapshot dos favoritos locais ANTES do fetch (para merge correto)
      final localDrugs    = Set<String>.from(_favDrugs);
      final localProtos   = Set<String>.from(_favProtocols);
      final localPrescs   = Set<String>.from(_favPrescriptions);
      final localCases    = Set<String>.from(_favCases);

      debugPrint('[SYNC_TRACE][STEP1] Carregando favoritos do Firestore...');
      final results = await Future.wait([
        FirestoreService.loadFavDrugs(uid),
        FirestoreService.loadFavProtocols(uid),
        FirestoreService.loadFavPrescriptions(uid),
        FirestoreService.loadFavCases(uid),
      ]);
      debugPrint('[SYNC_TRACE][STEP1_OK] Favoritos carregados: '
          'drugs=${results[0].length} protos=${results[1].length} '
          'prescs=${results[2].length} cases=${results[3].length}');

      // Merge: une Firestore + local — nunca descarta favoritos locais
      _favDrugs         = results[0]..addAll(localDrugs);
      _favProtocols     = results[1]..addAll(localProtos);
      _favPrescriptions = results[2]..addAll(localPrescs);
      _favCases         = results[3]..addAll(localCases);

      debugPrint('[SYNC_TRACE][STEP2] Carregando casos customizados...');
      _customCases      = await FirestoreService.loadCases(uid);
      debugPrint('[SYNC_TRACE][STEP2_OK] Casos carregados: ${_customCases.length}');

      notifyListeners();

      debugPrint('[SYNC_TRACE][STEP3] Persistindo cache local...');
      await _saveLocal();
      debugPrint('[SYNC_TRACE][STEP3_OK] Cache local salvo.');

      // Re-salva no Firestore se o merge adicionou itens que estavam só no local
      if (_favDrugs.length > results[0].length)
        FirestoreService.saveFavDrugs(uid, _favDrugs).catchError((_) {});
      if (_favProtocols.length > results[1].length)
        FirestoreService.saveFavProtocols(uid, _favProtocols).catchError((_) {});
      if (_favPrescriptions.length > results[2].length)
        FirestoreService.saveFavPrescriptions(uid, _favPrescriptions).catchError((_) {});
      if (_favCases.length > results[3].length)
        FirestoreService.saveFavCases(uid, _favCases).catchError((_) {});

      debugPrint('[SYNC_TRACE][STEP4] Disparando sync de histórias e recentes (background)...');
      _syncHistoriesFromFirestore(uid);
      _syncRecentsFromFirestore(uid);
      debugPrint('[SYNC_TRACE][SUCCESS] Sincronismo concluído com sucesso.');
    } catch (e, stack) {
      // BUILD 290: catch explícito com stack trace — elimina silent exceptions
      // que causavam diagnósticos inconclusivos.
      debugPrint('[SYNC_TRACE][FATAL_ERROR] Falha no sincronismo: $e\n$stack');
    }
    // BUILD 290: este ponto é atingido SEMPRE (sucesso ou falha).
    // _firestoreSyncFuture se resolve aqui — checkGeminiSession() retorna
    // do await imediatamente, sem polling, sem delay artificial.
    debugPrint('[SYNC_TRACE][FUTURE_RESOLVED] Future resolvido para uid=$uid '
        '— isAdmin=$isAdmin isMaster=$isMaster');
  }

  Future<void> _syncRecentsFromFirestore(String uid) async {
    try {
      final remote = await FirestoreService.loadRecents(uid);
      if (remote.isEmpty) return;
      // Mescla: une remote + local (sem duplicatas)
      final prefs = await SharedPreferences.getInstance();
      final local = prefs.getStringList(_recentKey(uid)) ?? [];
      final merged = <String>[];
      final seen = <String>{};
      for (final item in [...remote, ...local]) {
        final key = item.split('|').take(2).join('|');
        if (seen.add(key)) merged.add(item);
      }
      final final20 = merged.take(20).toList();
      await prefs.setStringList(_recentKey(uid), final20);
      // Se local tinha itens que o remote não tinha, re-salva no Firestore
      if (final20.length > remote.length) {
        FirestoreService.saveRecents(uid, final20).catchError((_) {});
      }
    } catch (_) {}
  }

  Future<void> _syncHistoriesFromFirestore(String uid) async {
    try {
      final histories = await FirestoreService.loadHistories(uid);
      _myHistories = histories;
      notifyListeners();
      // Persiste histórias no cache local
      await _saveHistoriesLocal(uid);
    } catch (_) {}
  }

  // ── Cache local (SharedPreferences) ──────────────────────────────────────
  // Prefixo por uid garante que usuários diferentes não compartilhem cache
  String _k(String key, String? uid) => uid != null ? '${uid}_$key' : key;

  Future<void> loadPrefs() async {
    await _loadFromLocal();
    await _loadOfflineState();
  }

  Future<void> _loadFromLocal({String? uid}) async {
    try {
      final p = await SharedPreferences.getInstance();

      // Preferências globais (independentes de usuário)
      // BUILD 310 DIRETRIZ 0: cold-start sem idioma salvo → 'es' obrigatório.
      // Se o usuário nunca abriu o app antes, SharedPreferences não tem 'lang';
      // nesse caso impomos Espanhol como idioma soberano de partida.
      final savedLang = p.getString('lang');
      if (savedLang == null) {
        _lang = 'es';
        await p.setString('lang', 'es');
      } else {
        _lang = savedLang;
      }
      _darkMode      = p.getBool('darkMode')        ?? true;  // DARK-FIRST: padrão escuro para novos usuários
      _hapticEnabled = p.getBool('hapticEnabled')   ?? true;
      // Chave de IA — lida com prefixo de usuário se disponível (fallback offline)
      if (uid != null) {
        _openAiKey = p.getString(_k('openAiKey', uid)) ?? '';
      }

      // Dados por usuário (se uid disponível usa cache dedicado)
      final favKey   = _k('favDrugs',         uid);
      final protKey  = _k('favProtocols',     uid);
      final prescKey = _k('favPrescriptions', uid);
      final caseKey  = _k('customCases',      uid);
      final favCaseKey = _k('favCases',       uid);
      final histKey  = _k('myHistories',      uid);

      _favDrugs         = (p.getStringList(favKey)   ?? p.getStringList('favDrugs')         ?? []).toSet();
      _favProtocols     = (p.getStringList(protKey)  ?? p.getStringList('favProtocols')     ?? []).toSet();
      _favPrescriptions = (p.getStringList(prescKey) ?? p.getStringList('favPrescriptions') ?? []).toSet();
      _favCases         = (p.getStringList(favCaseKey) ?? p.getStringList('favCases')       ?? []).toSet();

      // Meu Plantão — carregamento local por uid
      _pinnedDrugIds = p.getStringList(_k('pinnedDrugs', uid)) ?? [];

      // BUILD 443 [P2]: default limpo — sem IDs proibidos pelo regulatório/Apple.
      // IDs removidos do default: 'calc_eletrólitos', 'calc_infusao'.
      // Default anterior (pré-BUILD 443): ['calc_scores','calc_cardio','calc_eletrólitos','calc_infusao']
      const _kForbiddenPinnedCalcIds = {'calc_eletrólitos', 'calc_infusao'};
      final rawPinnedCalcs = p.getStringList(_k('pinnedCalcs', uid))
          ?? ['calc_scores', 'calc_cardio'];

      // BUILD 443 [P2]: migração de startup — purga IDs proibidos de qualquer
      // lista persistida anteriormente (usuários que tinham o default antigo).
      // Executada a cada boot para garantir estado limpo após atualizações.
      _pinnedCalcIds = rawPinnedCalcs
          .where((id) => !_kForbiddenPinnedCalcIds.contains(id))
          .toList();
      _plantaoPatients = (p.getStringList(_k('plantaoPatients', uid)) ?? [])
          .map(PlantaoPatient.fromRaw)
          .whereType<PlantaoPatient>()
          .toList();

      final casesJson = p.getString(caseKey) ?? p.getString('customCases');
      if (casesJson != null) {
        try {
          final decoded = jsonDecode(casesJson);
          if (decoded is List) {
            _customCases = decoded
                .whereType<Map>()
                .map((e) => ClinicalCaseModel.fromJson(
                      e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
                    ))
                .toList();
          }
        } catch (_) {}
      }

      // Histórias clínicas em cache
      final histJson = p.getString(histKey);
      if (histJson != null) {
        try {
          final decoded = jsonDecode(histJson);
          if (decoded is List) {
            _myHistories = decoded
                .whereType<Map>()
                .map((e) => ClinicalHistoryModel.fromJson(
                      e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
                    ))
                .toList();
          }
        } catch (_) {}
      }
    } catch (_) {}
    // BUILD 326: sincroniza UiProvider com valores carregados do SharedPreferences.
    uiProvider.syncValues(lang: _lang, darkMode: _darkMode, hapticEnabled: _hapticEnabled);
    // BUILD 326: sincroniza AiChatProvider com estado de IA.
    aiChatProvider.syncFromAppProvider(
      aiStreaming:      _aiStreamActive,
      hasAnyAi:        hasAnyAi,
      hasAiKey:        hasAiKey,
      geminiConnected: _geminiConnected,
      geminiLoading:   _geminiLoading,
      geminiEmail:     _geminiEmail,
      openAiKey:       _openAiKey,
      aiKeyLoading:    _aiKeyLoading,
    );
    notifyListeners();
  }

  // ── Modo Offline ──────────────────────────────────────────────────────────
  static const _kOfflineMode      = 'offlineMode_v1';
  static const _kOfflineCachedAt  = 'offlineCachedAt_v1';
  static const _kOfflineDrugs     = 'offlineDrugs_v1';
  static const _kOfflineProtocols = 'offlineProtocols_v1';
  static const _kOfflineCases     = 'offlineCasesDb_v1';

  /// Liga/desliga o modo offline. Se ligar, dispara o cache completo.
  Future<void> setOfflineMode(bool value) async {
    _offlineMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOfflineMode, value);
    if (value) {
      await cacheAllDataForOffline();
    }
  }

  /// Salva toda a base de dados local em SharedPreferences em chunks.
  Future<void> cacheAllDataForOffline() async {
    if (_offlineCaching) return;
    _offlineCaching  = true;
    _offlineProgress = 0.0;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1/3 — Medicamentos (BUILD 325: base migrada para WebView, lista vazia)
      _offlineProgress = 0.05; notifyListeners();
      await prefs.setString(_kOfflineDrugs, '[]');
      _offlineProgress = 0.45; notifyListeners();

      // 2/3 — Protocolos
      final protosJson = jsonEncode(
        protocolsDatabase.map((proto) => {
          'id': proto.id,
          'title': proto.title,
          'severity': proto.severity,
          'drugs': proto.drugs,
        }).toList(),
      );
      await prefs.setString(_kOfflineProtocols, protosJson);
      _offlineProgress = 0.75; notifyListeners();

      // 3/3 — Casos clínicos base
      final casesJson = jsonEncode(
        casesDatabase.map((c) => {
          'id': c.id,
          'title': c.title,
          'category': c.category,
          'diagnosis': c.diagnosis,
          'history': c.history,
        }).toList(),
      );
      await prefs.setString(_kOfflineCases, casesJson);
      _offlineProgress = 0.95; notifyListeners();

      // Timestamp do cache
      final now = DateTime.now();
      _offlineCachedAt = now;
      await prefs.setString(_kOfflineCachedAt, now.toIso8601String());
      _offlineProgress = 1.0;
    } catch (_) {
      _offlineMode = false;
    } finally {
      _offlineCaching = false;
      notifyListeners();
    }
  }

  /// Lê o estado offline salvo no boot.
  Future<void> _loadOfflineState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _offlineMode = prefs.getBool(_kOfflineMode) ?? false;
      final cachedAt = prefs.getString(_kOfflineCachedAt);
      if (cachedAt != null) _offlineCachedAt = DateTime.tryParse(cachedAt);
    } catch (_) {}
  }

  Future<void> _saveLocal({String? uid}) async {
    final u = uid ?? _currentUser?.uid;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('lang',          _lang);
      await p.setBool('darkMode',        _darkMode);
      await p.setBool('hapticEnabled',   _hapticEnabled);
      // Chave de IA só persiste com prefixo de usuário (nunca global)
      if (u != null && _openAiKey.isNotEmpty) {
        await p.setString(_k('openAiKey', u), _openAiKey);
      }
      await p.setStringList(_k('favDrugs',         u), _favDrugs.toList());
      await p.setStringList(_k('favProtocols',     u), _favProtocols.toList());
      await p.setStringList(_k('favPrescriptions', u), _favPrescriptions.toList());
      await p.setStringList(_k('favCases',         u), _favCases.toList());
      await p.setString(_k('customCases', u),
          jsonEncode(_customCases.map((c) => c.toJson()).toList()));
    } catch (_) {}
  }

  // Salva apenas as histórias no cache (chamado após sync ou write)
  Future<void> _saveHistoriesLocal(String uid) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k('myHistories', uid),
          jsonEncode(_myHistories.map((h) => h.toJson()).toList()));
    } catch (_) {}
  }

  // ── i18n helpers ──────────────────────────────────────────────────────────
  String tDB(Map<String, String>? field) {
    if (field == null) return '';
    return field[_lang] ?? field['es'] ?? field['pt'] ?? '';
  }

  String t(String key) {
    return _translations[_lang]?[key] ?? _translations['es']?[key] ?? key;
  }

  // ── Cálculos clínicos ─────────────────────────────────────────────────────
  double? _parseNum(String val) {
    final v = double.tryParse(val.replaceAll(',', '.'));
    return (v != null && v.isFinite) ? v : null;
  }

  String _fmt(double v) {
    if (!v.isFinite) return '—';
    if (v.abs() >= 100) return v.round().toString();
    return ((v * 10).round() / 10).toString().replaceAll('.', ',');
  }

  String? get bmi {
    final w = _parseNum(_patient.weight);
    final h = _parseNum(_patient.height);
    if (w == null || h == null || h == 0) return null;
    final hm = h / 100;
    return _fmt(w / (hm * hm));
  }

  String? get clcr {
    final cr = _parseNum(_patient.creatinine);
    final a = _parseNum(_patient.age);
    final w = _parseNum(_patient.weight);
    if (cr == null || a == null || w == null || cr == 0) return null;
    double v = (140 - a) * w / (72 * cr);
    if (_patient.sex == 'Feminino' || _patient.sex == 'Femenino') v *= 0.85;
    return _fmt(v);
  }

  String? get map {
    final s = _parseNum(_hemo.sbp);
    final d = _parseNum(_hemo.dbp);
    if (s == null || d == null) return null;
    return _fmt((s + 2 * d) / 3);
  }

  String? get anionGap {
    final n = _parseNum(_hemo.na);
    final c = _parseNum(_hemo.cl);
    final b = _parseNum(_hemo.hco3);
    if (n == null || c == null || b == null) return null;
    return _fmt(n - (c + b));
  }

  String? get correctedNa {
    final n = _parseNum(_hemo.na);
    final g = _parseNum(_hemo.glucose);
    if (n == null || g == null) return null;
    return _fmt(n + 1.6 * ((g - 100) / 100));
  }

  DoseInfo calculateDose(DrugModel drug) {
    final w = _parseNum(_patient.weight);
    final a = _parseNum(_patient.age);
    final clcrVal = _parseNum(clcr ?? '');
    final alerts = <String>[];

    if ((drug.doseType == 'weight' || drug.doseType == 'infusion') && w == null) {
      // Informativo — não bloqueia exibição da dose de referência
      alerts.add(_lang == 'es'
          ? 'Ingrese el peso del paciente para visualizar los parámetros académicos de referencia (mg/kg) de la literatura médica.'
          : 'Informe o peso do paciente para visualizar os parâmetros acadêmicos de referência (mg/kg) da literatura médica.');
    }

    final renalAlert = drug.getField(drug.renalAlert, _lang);
    if (clcrVal != null && clcrVal > 0 && clcrVal < 50 && renalAlert.isNotEmpty &&
        !renalAlert.toLowerCase().contains('sem ajuste') &&
        !renalAlert.toLowerCase().contains('sin ajuste')) {
      alerts.add('Ajuste renal: ClCr ${clcr ?? '—'} mL/min. $renalAlert');
    }

    final elderlyAlert = drug.getField(drug.elderlyAlert, _lang);
    if (a != null && a >= 65 && elderlyAlert.isNotEmpty) {
      alerts.add('${_lang == 'es' ? 'Paciente anciano: ' : 'Paciente idoso: '}$elderlyAlert');
    }

    if (drug.doseType == 'weight' && w != null && drug.mgKg != null) {
      return DoseInfo(
        main: 'Ref. literatura: ${_fmt(w * drug.mgKg!)} mg (simulação teórica)',
        detail: 'Parâmetro acadêmico: ${drug.mgKg} mg/kg. ${drug.getField(drug.frequency, _lang)} — A dose final é de responsabilidade exclusiva do profissional.',
        alerts: alerts,
      );
    }

    if (drug.doseType == 'infusion' && w != null && drug.mcgKgMinStart != null && drug.mcgKgMinMax != null) {
      return DoseInfo(
        main: 'Ref. literatura: ${_fmt(w * drug.mcgKgMinStart!)}–${_fmt(w * drug.mcgKgMinMax!)} mcg/min (simulação teórica)',
        detail: 'Parâmetro acadêmico: ${drug.mcgKgMinStart}–${drug.mcgKgMinMax} mcg/kg/min em bomba. Titular por resposta — decisão exclusiva do profissional.',
        alerts: alerts,
      );
    }

    final fixedDose = drug.getField(drug.fixedDose, _lang);
    return DoseInfo(
      main: fixedDose.isNotEmpty ? fixedDose : (_lang == 'es' ? 'Consultar literatura de referencia' : 'Consultar literatura de referência'),
      detail: _lang == 'es'
          ? 'A literatura indica individualizar por indicación, función renal/hepática, alergias y presentación. La simulación basada en los parámetros del caso de estudio es responsabilidad exclusiva del profesional.'
          : 'A literatura indica individualizar por indicação, função renal/hepática, alergias e apresentação. A simulação baseada nos parâmetros do caso de estudo é responsabilidade exclusiva do profissional.',
      alerts: alerts,
    );
  }

  /// Interações detectadas via DrugInteractionService (fármacos selecionados + medicamentos do paciente)
  List<DrugInteraction> get drugInteractions {
    if (_selectedDrugIds.isEmpty) return [];
    final selectedNames = selectedDrugs.map((d) => d.name).toList();
    return DrugInteractionService.checkInteractions(
      selectedDrugNames: selectedNames,
      patientMedicationsText: _patient.medications,
    );
  }

  /// Compatibilidade legada — retorna strings simples para widgets antigos
  List<String> get interactionRisks =>
      drugInteractions.map((i) => '${i.drug1} + ${i.drug2}: ${i.effect}').toList();

  // ── Mutations de estado ───────────────────────────────────────────────────
  /// Atualiza nome, profissão e instituição do usuário logado
  Future<void> updateProfile({String? displayName, String? profession, String? institution}) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      displayName: displayName,
      profession: profession,
      institution: institution,
    );
    notifyListeners();
    await FirestoreService.updateUserProfile(
      _currentUser!.uid,
      displayName: displayName,
      profession: profession,
      institution: institution,
    );
  }

  void setLang(String l) {
    _lang = l;
    // Build 100: resetar o language lock da sessão ao trocar o idioma do app.
    _sessionLockedLang = null;
    _saveLocal();
    if (_currentUser != null) {
      FirestoreService.updateUserProfile(_currentUser!.uid, lang: l);
    }
    // BUILD 326: notifica UiProvider (afeta apenas widgets de tema/idioma).
    uiProvider.syncValues(lang: _lang, darkMode: _darkMode, hapticEnabled: _hapticEnabled);
    notifyListeners();
  }

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    _saveLocal();
    if (_currentUser != null) {
      FirestoreService.updateUserProfile(_currentUser!.uid, darkMode: _darkMode);
    }
    // BUILD 326: notifica UiProvider.
    uiProvider.syncValues(lang: _lang, darkMode: _darkMode, hapticEnabled: _hapticEnabled);
    notifyListeners();
  }

  void toggleHaptic() {
    _hapticEnabled = !_hapticEnabled;
    _saveLocal();
    // BUILD 326: notifica UiProvider.
    uiProvider.syncValues(lang: _lang, darkMode: _darkMode, hapticEnabled: _hapticEnabled);
    notifyListeners();
  }

  void updatePatient(String key, String value) {
    switch (key) {
      case 'patientId':    _patient.patientId = value; break;
      case 'age':           _patient.age = value; break;
      case 'sex':           _patient.sex = value; break;
      case 'weight':        _patient.weight = value; break;
      case 'height':        _patient.height = value; break;
      case 'creatinine':    _patient.creatinine = value; break;
      case 'medications':   _patient.medications = value; break;
    }
    notifyListeners();
  }

  void resetPatient() {
    _patient = PatientData();
    _selectedDrugIds = [];
    _activeDrugId = '';
    notifyListeners();
  }

  void updateHemo(String key, String value) {
    switch (key) {
      case 'sbp':     _hemo.sbp = value; break;
      case 'dbp':     _hemo.dbp = value; break;
      case 'na':      _hemo.na = value; break;
      case 'cl':      _hemo.cl = value; break;
      case 'hco3':    _hemo.hco3 = value; break;
      case 'glucose': _hemo.glucose = value; break;
    }
    notifyListeners();
  }

  void setActiveDrug(String id) {
    _activeDrugId = id;
    if (!_selectedDrugIds.contains(id)) _selectedDrugIds.add(id);
    notifyListeners();
  }

  void addDrug(String id) {
    if (!_selectedDrugIds.contains(id)) {
      _selectedDrugIds.add(id);
      _activeDrugId = id;
    }
    notifyListeners();
  }

  void removeDrug(String id) {
    _selectedDrugIds.remove(id);
    if (_selectedDrugIds.isEmpty) {
      _activeDrugId = '';
    } else if (_activeDrugId == id) {
      _activeDrugId = _selectedDrugIds.first;
    }
    notifyListeners();
  }

  void toggleFavDrug(String id) {
    if (_favDrugs.contains(id)) _favDrugs.remove(id); else _favDrugs.add(id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveFavDrugs(_currentUser!.uid, _favDrugs);
    notifyListeners();
  }

  void toggleFavProtocol(String id) {
    if (_favProtocols.contains(id)) _favProtocols.remove(id); else _favProtocols.add(id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveFavProtocols(_currentUser!.uid, _favProtocols);
    notifyListeners();
  }

  void toggleFavPrescription(String id) {
    if (_favPrescriptions.contains(id)) _favPrescriptions.remove(id); else _favPrescriptions.add(id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveFavPrescriptions(_currentUser!.uid, _favPrescriptions);
    notifyListeners();
  }

  void toggleFavCase(String id) {
    if (_favCases.contains(id)) _favCases.remove(id); else _favCases.add(id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveFavCases(_currentUser!.uid, _favCases);
    notifyListeners();
  }

  // ── Meu Plantão — Pin / Unpin ─────────────────────────────────────────────

  /// Fixa um fármaco no plantão.
  /// Retorna [PinResult] indicando sucesso, já fixado ou limite atingido.
  /// Se [replaceOldest] = true e o limite foi atingido, remove o item mais antigo.
  PinResult pinDrug(String id, {bool replaceOldest = false}) {
    if (_pinnedDrugIds.contains(id)) return PinResult.alreadyPinned;
    if (_pinnedDrugIds.length >= _kMaxPinnedDrugs) {
      if (replaceOldest) {
        _pinnedDrugIds.removeLast();
      } else {
        return PinResult.limitReached;
      }
    }
    _pinnedDrugIds.insert(0, id);
    _savePlantaoLocal();
    notifyListeners();
    return PinResult.success;
  }

  /// Remove um fármaco do plantão.
  void unpinDrug(String id) {
    _pinnedDrugIds.remove(id);
    _savePlantaoLocal();
    notifyListeners();
  }

  /// Alterna o estado de fixado do fármaco (pin/unpin).
  /// Retorna [PinResult] com o resultado da operação.
  PinResult togglePinDrug(String id, {bool replaceOldest = false}) {
    if (_pinnedDrugIds.contains(id)) {
      unpinDrug(id);
      return PinResult.unpinned;
    }
    return pinDrug(id, replaceOldest: replaceOldest);
  }

  /// Fixa uma calculadora no plantão.
  PinResult pinCalc(String id, {bool replaceOldest = false}) {
    if (_pinnedCalcIds.contains(id)) return PinResult.alreadyPinned;
    if (_pinnedCalcIds.length >= _kMaxPinnedCalcs) {
      if (replaceOldest) {
        _pinnedCalcIds.removeLast();
      } else {
        return PinResult.limitReached;
      }
    }
    _pinnedCalcIds.insert(0, id);
    _savePlantaoLocal();
    notifyListeners();
    return PinResult.success;
  }

  /// Remove uma calculadora do plantão.
  void unpinCalc(String id) {
    _pinnedCalcIds.remove(id);
    _savePlantaoLocal();
    notifyListeners();
  }

  /// Alterna o estado de fixado da calculadora.
  PinResult togglePinCalc(String id, {bool replaceOldest = false}) {
    if (_pinnedCalcIds.contains(id)) {
      unpinCalc(id);
      return PinResult.unpinned;
    }
    return pinCalc(id, replaceOldest: replaceOldest);
  }

  /// Limpa todos os itens fixados do plantão.
  void clearPlantao() {
    _pinnedDrugIds.clear();
    _pinnedCalcIds.clear();
    _savePlantaoLocal();
    notifyListeners();
  }

  // ── Pacientes do Plantão ──────────────────────────────────────────────────

  /// Adiciona ou actualiza um paciente no plantão.
  /// Build 180: dual-write → SharedPreferences (local) + Firestore (sync Adulto tab).
  void savePlantaoPatient(PlantaoPatient patient) {
    final idx = _plantaoPatients.indexWhere((p) => p.id == patient.id);
    if (idx >= 0) {
      _plantaoPatients[idx] = patient;
    } else {
      _plantaoPatients.insert(0, patient);
    }
    _savePlantaoLocal();
    notifyListeners();

    // ── Build 180: Firestore dual-write para sync em tempo real com aba Adulto ──
    final uid = _currentUser?.uid;
    if (uid != null) {
      _syncPlantaoPatientToFirestore(uid, patient);
    }
  }

  /// Remove um paciente do plantão pelo id.
  /// Build 180: dual-write → remove do local + soft-delete no Firestore.
  void removePlantaoPatient(String id) {
    // Busca chave Firestore antes de remover da lista local
    final sessionKey = 'miguardia_$id';
    _plantaoPatients.removeWhere((p) => p.id == id);
    _savePlantaoLocal();
    notifyListeners();

    // ── Build 180: soft-delete no Firestore para refletir na aba Adulto ───────
    final uid = _currentUser?.uid;
    if (uid != null) {
      InternacionFirestoreService.softDelete(uid, sessionKey).catchError((_) {});
    }
  }

  /// Build 180: Sincroniza um PlantaoPatient para o Firestore como PacienteSession mínima.
  /// Usa prefixo 'miguardia_' para distinguir de sessões de internação completas.
  void _syncPlantaoPatientToFirestore(String uid, PlantaoPatient patient) {
    try {
      final paciente = PacienteInternacaoData(
        nome: patient.name,
        cama: patient.room,
        diagnostico: patient.diagnosis,
        // Notas e tratamento mapeados para campos disponíveis
        idade: '',
        sexo: '',
        diaInternacao: 1,
      );
      final existingKey = 'miguardia_${patient.id}';
      InternacionFirestoreService.saveSession(
        uid: uid,
        paciente: paciente,
        historial: const [],
        existingKey: existingKey,
      ).catchError((_) {});
    } catch (_) {}
  }

  /// Limpa todos os pacientes do plantão.
  void clearPlantaoPatients() {
    _plantaoPatients.clear();
    _savePlantaoLocal();
    notifyListeners();
  }

  // Persiste o estado do plantão em SharedPreferences (local, sem Firestore)
  void _savePlantaoLocal() {
    final uid = _currentUser?.uid;
    SharedPreferences.getInstance().then((p) {
      p.setStringList(_k('pinnedDrugs', uid), _pinnedDrugIds);
      p.setStringList(_k('pinnedCalcs', uid), _pinnedCalcIds);
      p.setStringList(_k('plantaoPatients', uid),
          _plantaoPatients.map((pt) => pt.toRaw()).toList());
    }).catchError((_) {});
  }

  // ── Recentes — chave prefixada por uid para sobreviver a logout/login ─────
  static const _kRecentBase = 'home_recents_v1';

  String _recentKey(String? uid) =>
      uid != null ? '${uid}_$_kRecentBase' : _kRecentBase;

  /// Registra um item como recente (type|id|title), com chave por uid.
  /// Dual-write: SharedPreferences (offline) + Firestore (cross-device).
  Future<void> registerRecent(String type, String id, String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key   = _recentKey(_currentUser?.uid);
      final raw   = prefs.getStringList(key) ?? [];
      final entry = '$type|$id|$title';
      raw.removeWhere((e) => e.startsWith('$type|$id|'));
      raw.insert(0, entry);
      final updated = raw.take(20).toList();
      await prefs.setStringList(key, updated);
      // Sincroniza com Firestore em background
      final uid = _currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        FirestoreService.saveRecents(uid, updated).catchError((_) {});
      }
    } catch (_) {}
  }

  /// Lê a lista de recentes do usuário atual.
  /// Prioridade: Firestore (cross-device) → SharedPreferences (offline).
  Future<List<Map<String, String>>> loadRecents() async {
    try {
      final uid = _currentUser?.uid;

      // 1º tenta Firestore
      if (uid != null && uid.isNotEmpty) {
        final remote = await FirestoreService.loadRecents(uid);
        if (remote.isNotEmpty) {
          // Atualiza cache local com dados do servidor
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(_recentKey(uid), remote);
          return remote.map((e) {
            final parts = e.split('|');
            if (parts.length < 3) return null;
            return {'type': parts[0], 'id': parts[1], 'title': parts.sublist(2).join('|')};
          }).whereType<Map<String, String>>().toList();
        }
      }

      // Fallback: SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final key   = _recentKey(_currentUser?.uid);
      final raw   = prefs.getStringList(key) ?? [];

      // Migra dados locais para Firestore se não havia nada remoto
      if (uid != null && uid.isNotEmpty && raw.isNotEmpty) {
        FirestoreService.saveRecents(uid, raw).catchError((_) {});
      }

      return raw.map((e) {
        final parts = e.split('|');
        if (parts.length < 3) return null;
        return {'type': parts[0], 'id': parts[1], 'title': parts.sublist(2).join('|')};
      }).whereType<Map<String, String>>().toList();
    } catch (_) {
      return [];
    }
  }

  void saveCase(ClinicalCaseModel c) {
    final idx = _customCases.indexWhere((x) => x.id == c.id);
    if (idx >= 0) _customCases[idx] = c; else _customCases.insert(0, c);
    _saveLocal();
    if (_currentUser != null) FirestoreService.saveCase(_currentUser!.uid, c);
    notifyListeners();
  }

  void deleteCase(String id) {
    _customCases.removeWhere((c) => c.id == id);
    _saveLocal();
    if (_currentUser != null) FirestoreService.deleteCase(_currentUser!.uid, id);
    notifyListeners();
  }

  // ── Histórias Clínicas ────────────────────────────────────────────────────
  Future<void> loadHistories() async {
    if (_currentUser == null) return;
    final uid = _currentUser!.uid;
    try {
      // SYNC-FIX: Source.server força leitura direta do Firestore, ignorando
      // o cache local. Resolve o problema de histórias criadas na Web que
      // não apareciam no iOS na primeira abertura do app.
      _myHistories = await FirestoreService.loadHistories(uid);
      notifyListeners();
      // Persiste no cache para uso offline
      await _saveHistoriesLocal(uid);
    } catch (_) {
      // Sem rede: histórias já carregadas do cache em _loadFromLocal()
    }

    // BUILD 334-FORENSE: Fetch-On-Auth-Resolved + stream reativo MULTIPLATAFORMA.
    //
    // DIAGNÓSTICO: loadHistories() ativava streamHistories() apenas em !kIsWeb.
    //   No Web (Safari/Chrome), histórias criadas no iPhone não apareciam em
    //   tempo real — apenas após reload completo da página.
    //
    // SOLUÇÃO: stream Firestore ativado em TODAS as plataformas.
    //   • iOS/Android: mantém comportamento anterior (stream nativo eficiente).
    //   • Web: stream via WebSocket do Firestore SDK — atualiza em <1s quando
    //     qualquer dispositivo da conta salva uma nova HC.
    //   • _historiesStreamSub protege contra múltiplos listeners (cancel+rebind).
    //
    // FETCH-ON-AUTH-RESOLVED: esta função é chamada em setUser() APÓS a chave
    //   de auth ser carregada (_loadAiKeyFromFirestore) — garantia de que o
    //   Firestore Rules já validou a permissão antes do primeiro .listen().
    await _historiesStreamSub?.cancel();
    _historiesStreamSub = FirestoreService.streamHistories(uid).listen(
      (list) {
        _myHistories = list;
        notifyListeners();
        _saveHistoriesLocal(uid).catchError((_) {});
      },
      onError: (_) {/* Stream error: dados em memória preservados */},
    );
  }

  /// Cancela o stream de histórias (chamado no logout).
  Future<void> _cancelHistoriesStream() async {
    await _historiesStreamSub?.cancel();
    _historiesStreamSub = null;
  }

  Future<void> saveHistory(ClinicalHistoryModel h) async {
    if (_currentUser == null) return;

    // ── 1. Atualiza _myHistories na memória ──────────────────────────────────
    final idx = _myHistories.indexWhere((x) => x.id == h.id);
    if (idx >= 0) {
      _myHistories[idx] = h;
    } else {
      _myHistories.insert(0, h);
    }

    // ── 2. Atualiza _publicHistories na memória imediatamente ────────────────
    // Faz isso ANTES do Firestore para que o criador veja a própria HC
    // na aba Comunidade sem precisar recarregar.
    if (h.isPublic) {
      final pubIdx = _publicHistories.indexWhere((x) => x.id == h.id);
      // Garante uploadedAt não-vazio para a exibição local
      final uploadedAt = h.uploadedAt.isNotEmpty
          ? h.uploadedAt
          : DateTime.now().toIso8601String();
      final publicVersion = h.copyWith(uploadedAt: uploadedAt, isHidden: false);
      if (pubIdx >= 0) {
        _publicHistories[pubIdx] = publicVersion;
      } else {
        _publicHistories.insert(0, publicVersion);
      }
      // Re-ordena para manter consistência
      _publicHistories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else {
      // Removeu o isPublic: tira da lista pública local imediatamente
      _publicHistories.removeWhere((x) => x.id == h.id);
    }

    // ── 3. Persiste no cache local e notifica UI ─────────────────────────────
    await _saveHistoriesLocal(_currentUser!.uid);
    notifyListeners();

    // ── 4. Sincroniza com Firestore em background ────────────────────────────
    // Agora awaita + propaga o uploadedAt real de volta ao modelo local
    FirestoreService.saveHistory(_currentUser!.uid, h).then((uploadedAt) {
      if (uploadedAt != null && uploadedAt.isNotEmpty && h.isPublic) {
        // Atualiza uploadedAt no modelo local com o valor confirmado pelo servidor
        final pubIdx = _publicHistories.indexWhere((x) => x.id == h.id);
        if (pubIdx >= 0 && _publicHistories[pubIdx].uploadedAt != uploadedAt) {
          _publicHistories[pubIdx] = _publicHistories[pubIdx].copyWith(uploadedAt: uploadedAt);
          // Também sincroniza em _myHistories
          final myIdx = _myHistories.indexWhere((x) => x.id == h.id);
          if (myIdx >= 0) {
            _myHistories[myIdx] = _myHistories[myIdx].copyWith(uploadedAt: uploadedAt);
          }
          _saveHistoriesLocal(_currentUser!.uid).catchError((_) {});
          notifyListeners();
        }
      }
    }).catchError((_) {
      // Falha no Firestore: dados já estão na memória/cache local.
      // Na próxima conexão, loadHistories() sincroniza automaticamente.
    });
  }

  Future<void> deleteHistory(String id, {bool wasPublic = false}) async {
    if (_currentUser == null) return;
    _myHistories.removeWhere((h) => h.id == id);
    // Remove da lista pública local também (independente de wasPublic)
    _publicHistories.removeWhere((h) => h.id == id);
    // Atualiza cache local imediatamente
    await _saveHistoriesLocal(_currentUser!.uid);
    notifyListeners();
    // Sincroniza deleção com Firestore em background
    FirestoreService.deleteHistory(_currentUser!.uid, id, wasPublic: wasPublic)
        .catchError((_) {});
  }

  Future<void> toggleHistoryPublic(ClinicalHistoryModel h) async {
    final updated = h.copyWith(isPublic: !h.isPublic);
    await saveHistory(updated);
  }

  /// Modera visibilidade de uma HC pública (admin/supervisor).
  /// Atualiza a lista em memória IMEDIATAMENTE — botão muda na hora.
  /// Depois sincroniza com Firestore em background.
  Future<void> toggleHistoryHidden(String historyId) async {
    final uid = _currentUser?.uid ?? '';
    // Encontra na lista pública local
    final idx = _publicHistories.indexWhere((h) => h.id == historyId);
    if (idx < 0) return;

    final current = _publicHistories[idx];
    final nowHidden = !current.isHidden;
    final now = DateTime.now().toIso8601String();

    // Atualiza em memória imediatamente (UI reflete na hora)
    // Usa um objeto temporário para resetar os campos nullable
    final updated = ClinicalHistoryModel(
      id: current.id,
      createdAt: current.createdAt,
      authorUid: current.authorUid,
      authorName: current.authorName,
      authorEmail: current.authorEmail,
      uploadedAt: current.uploadedAt,
      updatedAt: current.updatedAt,
      isPublic: current.isPublic,
      patientInitials: current.patientInitials,
      patientAge: current.patientAge,
      patientSex: current.patientSex,
      patientWeight: current.patientWeight,
      patientHeight: current.patientHeight,
      patientRecord: current.patientRecord,
      chiefComplaint: current.chiefComplaint,
      hpi: current.hpi,
      pastHistory: current.pastHistory,
      familyHistory: current.familyHistory,
      socialHistory: current.socialHistory,
      medications: current.medications,
      allergies: current.allergies,
      reviewOfSystems: current.reviewOfSystems,
      vitalSigns: current.vitalSigns,
      physicalExam: current.physicalExam,
      workingDiagnosis: current.workingDiagnosis,
      differentialDx: current.differentialDx,
      finalDiagnosis: current.finalDiagnosis,
      cid: current.cid,
      labResults: current.labResults,
      imagingResults: current.imagingResults,
      otherResults: current.otherResults,
      treatmentPlan: current.treatmentPlan,
      procedures: current.procedures,
      drugIds: current.drugIds,
      evolutions: current.evolutions,
      outcome: current.outcome,
      dischargeCondition: current.dischargeCondition,
      followUp: current.followUp,
      category: current.category,
      tags: current.tags,
      isHidden: nowHidden,
      hiddenBy: nowHidden ? uid : null,
      hiddenAt: nowHidden ? now : null,
    );
    _publicHistories[idx] = updated;
    notifyListeners();

    // Sincroniza com Firestore em background
    if (nowHidden) {
      FirestoreService.hideHistory(historyId, uid).catchError((_) {});
    } else {
      FirestoreService.unhideHistory(historyId).catchError((_) {});
    }
  }

  // Completer ativo enquanto um fetch está em andamento.
  // Chamadas concorrentes aguardam o mesmo Future em vez de retornar [] silenciosamente.
  Completer<void>? _publicHistoriesCompleter;

  void _debugPublicHistories(String message) {
    if (kDebugMode) debugPrint('[AppProvider.publicHistories] $message');
  }

  Future<void> loadPublicHistories({bool forceRemote = false}) async {
    // Já há um fetch em andamento — aguarda ele terminar (não cancela nem ignora)
    if (_publicHistoriesCompleter != null) {
      await _publicHistoriesCompleter!.future;
      return;
    }

    _publicHistoriesCompleter = Completer<void>();
    _isLoadingPublic = true;
    _publicLoadError = '';
    _debugPublicHistories('load start forceRemote=$forceRemote existing=${_publicHistories.length}');
    notifyListeners();
    try {
      final fetched = await FirestoreService.loadPublicHistories(forceRemote: forceRemote);
      final serviceError = FirestoreService.lastPublicHistoriesErrorMessage.trim();

      // Mescla: preserva HCs locais do criador que ainda não chegaram ao servidor
      final mergedIds = <String>{};
      final merged = <ClinicalHistoryModel>[];
      for (final h in fetched) {
        merged.add(h);
        mergedIds.add(h.id);
      }
      for (final local in _publicHistories) {
        if (!mergedIds.contains(local.id) && local.isPublic) {
          merged.add(local);
        }
      }
      merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _publicHistories = merged;
      _publicLoadError = merged.isEmpty ? serviceError : '';
      _debugPublicHistories(
        'load done fetched=${fetched.length} merged=${merged.length} errorSet=${_publicLoadError.isNotEmpty}',
      );
    } catch (e, st) {
      _publicLoadError = FirestoreService.lastPublicHistoriesErrorMessage.trim().isNotEmpty
          ? FirestoreService.lastPublicHistoriesErrorMessage.trim()
          : 'Falha ao carregar histórias da comunidade: $e';
      _debugPublicHistories('load failed error=$e stack=$st');
    } finally {
      _isLoadingPublic = false;
      _publicHistoriesCompleter!.complete();
      _publicHistoriesCompleter = null;
      notifyListeners();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  void logout() {
    clearUser();
  }

  // ── IA Clínica ────────────────────────────────────────────────────────────

  /// Salva a chave OpenAI GLOBAL do app (admin → todos os usuários).
  /// Persiste em app_config/global.openAiKey + atualiza estado local.
  Future<void> setAppAiKey(String key) async {
    final trimmed = key.trim();
    _openAiKey = trimmed;
    notifyListeners();
    await FirestoreService.saveAppAiKey(trimmed);
    // Atualiza cache local do usuário atual também
    if (_currentUser != null) {
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_k('openAiKey', _currentUser!.uid), trimmed);
      } catch (_) {}
    }
  }

  /// Salva a chave OpenAI vinculada ao UID do usuário logado.
  /// Persiste no Firestore (sync entre dispositivos) + cache local (offline).
  Future<void> setAiKey(String key) async {
    if (_currentUser == null) return;
    _openAiKey = key.trim();
    notifyListeners();
    final uid = _currentUser!.uid;
    // Persiste no Firestore do usuário
    FirestoreService.saveAiKey(uid, _openAiKey).catchError((_) {});
    // Persiste no cache local com prefixo do usuário (funciona offline)
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k('openAiKey', uid), _openAiKey);
    } catch (_) {}
  }

  /// Limpa o histórico de conversa da IA (nova conversa)
  void clearAiHistory() {
    cancelAiStream(); // cancela streaming em curso se houver
    _aiHistory.clear();
    _sessionLockedLang = null; // reset language lock ao iniciar nova sessão
    _threadManager.reset();                  // BUILD 249: reset thread ao iniciar nova conversa
    ClinicalThreadManager.resetStaticState(); // BUILD 304 PURIF-1: limpa _lastTaskLabel/_lastStudyActivityMs
    ClinicalThreadAudit.logFoundComponents(); // BUILD 249: audit log uma vez por sessão
  }

  /// Build 110 — Reconstrói _aiHistory a partir de uma lista de mensagens
  /// restauradas (ex: sessão do histórico de chats).
  /// Recebe lista de {role: 'user'/'assistant', content: '...'}.
  /// Limita a 10 entradas (5 pares) para não inflar o contexto.
  ///
  /// BUILD 293: versão async de rebuildAiHistoryFromMessages.
  /// Aguarda o _firestoreSyncFuture antes de reconstruir — garante que o
  /// Safari não tente ler dados de Firestore antes da conexão estar pronta.
  /// Timeout de 6s como safety-net (mesmo que o sync principal).
  Future<void> rebuildAiHistoryFromMessagesAsync(
      List<Map<String, String>> messages) async {
    final syncFuture = _firestoreSyncFuture;
    if (syncFuture != null) {
      try {
        await syncFuture.timeout(
          const Duration(seconds: 6),
          onTimeout: () {
            debugPrint('[BUILD293][rebuildAiHistory] sync timeout 6s — '
                'prosseguindo com dados locais');
          },
        );
      } catch (e) {
        debugPrint('[BUILD293][rebuildAiHistory] sync error (non-fatal): $e');
      }
    }
    rebuildAiHistoryFromMessages(messages);
  }

  /// ORDEM 53 M1: Agora também chama _threadManager.primeFromHistory() para
  /// reidratar o tópico ativo no ClinicalThreadManager. Sem isso, a próxima
  /// mensagem do usuário cai em `_activeTopic.isEmpty → first_message →
  /// ThreadAction.newThread → _aiHistory.clear()` — destruindo o histórico
  /// recém-restaurado (amnésia ao voltar do background).
  void rebuildAiHistoryFromMessages(List<Map<String, String>> messages) {
    cancelAiStream();
    _aiHistory.clear();
    // Filtra apenas pares válidos user/assistant com conteúdo
    // HOTFIX 247D: exclui mensagens de fallback/safe-card ao restaurar sessão
    final valid = messages
        .where((m) {
          final role    = m['role']    ?? '';
          final content = m['content'] ?? '';
          if (content.isEmpty) return false;
          if (role != 'user' && role != 'assistant') return false;
          // Mensagens da IA são filtradas se forem fallback/safe-card
          if (role == 'assistant' && _isFallbackText(content)) return false;
          return true;
        })
        .toList();
    // Pega as últimas 10 entradas (5 pares) para não exceder o limite da janela
    final window = valid.length > 10 ? valid.sublist(valid.length - 10) : valid;
    _aiHistory.addAll(window);
    if (kDebugMode) {
      final removedCount = messages.length - valid.length;
      if (removedCount > 0) {
        debugPrint('[HISTORY_SANITIZER] rebuildFromMessages removed=$removedCount fallbackMessages finalHistoryMessages=${_aiHistory.length}');
      }
    }
    debugPrint('[AppProvider] rebuildAiHistoryFromMessages: ${_aiHistory.length} entradas restauradas no contexto');

    // ORDEM 53 M1: Reidrata o ClinicalThreadManager com o tópico do histórico
    // restaurado. Impede que a próxima mensagem seja classificada como
    // 'first_message' e destrua o contexto restaurado com um hard reset.
    _threadManager.primeFromHistory(window);
  }

  /// Reset completo da sessão clínica da IA — usado pelo double-tap no FAB.
  ///
  /// Vai além de clearAiHistory(): também zera a memória clínica estruturada
  /// (diagnósticos ativos, fármacos, laboratórios, contexto do paciente) para
  /// garantir que a próxima conversa comece 100% limpa, sem nenhum contexto
  /// residual da sessão anterior contaminando as respostas do modelo.
  void resetAiSessionFull() {
    cancelAiStream();           // cancela qualquer stream em andamento
    _aiHistory.clear();         // limpa histórico de mensagens enviadas à API
    _sessionLockedLang = null;  // libera language lock
    _sessionMemory.reset();     // zera memória clínica estruturada (diag, meds, labs)
    _threadManager.reset();                  // BUILD 249: reset thread clínico ativo
    ClinicalThreadManager.resetStaticState(); // BUILD 304 PURIF-1: limpa _lastTaskLabel/_lastStudyActivityMs
    debugPrint('[AppProvider] resetAiSessionFull — sessão clínica zerada');
  }

  // ── Gemini OAuth — conectar / desconectar ─────────────────────────────────

  /// Inicia fluxo OAuth Google → abre seletor de conta nativo.
  ///
  /// Retorna:
  ///   true  → conectou com sucesso (Android ou web sem redirect)
  ///   false → falha real (cancelou, erro de rede, etc.)
  ///   null  → redirect OAuth iniciado no Safari/web (página vai recarregar;
  ///            o token chegará via checkGeminiSession() no próximo boot)
  Future<bool?> connectGemini() async {
    _geminiLoading = true;
    aiChatProvider.setGeminiLoading(true); // BUILD 326
    notifyListeners();
    try {
      // No web com redirect flow, signIn() retorna false imediatamente após
      // abrir o modal — a página vai recarregar. Precisamos distinguir isso
      // de uma falha real. A flag 'medcases_gsi_modal_opened' no JS sinaliza
      // que o modal foi aberto (redirect em andamento).
      final ok = await GeminiService.signIn()
          .timeout(const Duration(seconds: 30), onTimeout: () => false);

      if (ok) {
        _geminiConnected = true;
        _geminiEmail = await GeminiService.connectedEmail() ?? '';
        // BUILD 326: sync AiChatProvider.
        aiChatProvider.setGeminiConnected(
          connected: true,
          email: _geminiEmail,
          hasAnyAi: hasAnyAi,
          hasAiKey: hasAiKey,
        );
        return true;
      }

      // Verifica se o modal foi aberto (redirect flow no web)
      if (kIsWeb) {
        try {
          final modalOpened = _webGetLS('medcases_gsi_modal_opened');
          if (modalOpened == 'true') {
            _webRemoveLS('medcases_gsi_modal_opened');
            // SUPER ORDEM MASTER 315: salva índice da aba de origem (sempre 2 = IA
            // aqui, mas armazenado como inteiro para generalização futura).
            // checkGeminiSession() lê 'medcases_pre_auth_tab_index' pós-redirect
            // e dispara postOAuthTabNotifier para restaurar a aba sem depender
            // do initState (corrige race condition do Build 14 M3).
            _webSetLS('medcases_pre_auth_tab_index', '2');
            debugPrint('[connectGemini] redirect OAuth iniciado — aguardando reload, tab_index=2 salvo');
            return null; // null = redirect em andamento, não é falha
          }
        } catch (_) {}
      }

      return false;
    } catch (e, st) {
      debugPrint('[connectGemini] ERRO: $e');
      debugPrint('[connectGemini] STACK: $st');
      return false;
    } finally {
      _geminiLoading = false;
      aiChatProvider.setGeminiLoading(false); // BUILD 326
      notifyListeners();
    }
  }

  /// Desconecta a conta Google do Gemini.
  Future<void> disconnectGemini() async {
    _geminiLoading = true;
    aiChatProvider.setGeminiLoading(true); // BUILD 326
    notifyListeners();
    try {
      await GeminiService.signOut();
      _geminiConnected = false;
      _geminiEmail = '';
      // BUILD 326: sync AiChatProvider.
      aiChatProvider.setGeminiConnected(
        connected: false,
        email: '',
        hasAnyAi: hasAnyAi,
        hasAiKey: hasAiKey,
      );
    } finally {
      _geminiLoading = false;
      aiChatProvider.setGeminiLoading(false); // BUILD 326
      notifyListeners();
    }
  }

  bool _isGeminiRetryBlocked() =>
      _geminiRetryAfter != null && DateTime.now().isBefore(_geminiRetryAfter!);

  void _clearGeminiConfigUnavailable() {
    _geminiApiKeyUnavailable = false;
    _geminiRetryAfter = null;
  }

  void _markGeminiConfigUnavailable([Object? error]) {
    _geminiApiKeyUnavailable = true;
    _geminiRetryAfter = DateTime.now().add(_geminiRetryCooldown);
    if (error != null) {
      debugPrint('[checkGeminiSession] app_config/global indisponível: $error');
    }
  }

  // BUILD 336-AUTH-RESILIENCE (PASSO 2): _setGeminiConnectionState agora
  // sincroniza SEMPRE o AiChatProvider antes de notifyListeners().
  // Motivo: checkGeminiSession() chama este método, mas connectGemini() e
  // disconnectGemini() chamavam aiChatProvider.setGeminiConnected() diretamente.
  // No fluxo Web pós-redirect (currentUser==null), apenas checkGeminiSession()
  // é executado — e o AiChatProvider ficava fora de sincronia, impedindo a UI
  // de transicionar para o modo conectado.
  //
  // O guard de igualdade foi preservado para estado+email, mas a sincronização
  // do AiChatProvider é sempre executada quando `connected == true` para garantir
  // que a árvore da ai_screen reconstrua mesmo em re-emissões do stream de auth.
  void _setGeminiConnectionState({
    required bool connected,
    String email = '',
    bool notify = true,
  }) {
    final nextEmail = connected ? email : '';
    final stateChanged =
        _geminiConnected != connected || _geminiEmail != nextEmail;
    _geminiConnected = connected;
    _geminiEmail     = nextEmail;

    // BUILD 336 PASSO 2: sincroniza AiChatProvider SEMPRE que conectado=true
    // (inclusive em re-emissões sem mudança de estado — garante UI responsiva).
    if (connected || stateChanged) {
      aiChatProvider.setGeminiConnected(
        connected: connected,
        email: nextEmail,
        hasAnyAi: hasAnyAi,
        hasAiKey: hasAiKey,
      );
    }

    if (notify && stateChanged) notifyListeners();
    // Força notificação adicional quando conecta, mesmo sem mudança de valor,
    // para remontar a árvore de UI que pode ter sido renderizada antes do token
    // estar disponível (race condition Web: currentUser==null durante o boot).
    if (notify && connected && !stateChanged) {
      debugPrint('[BUILD336] _setGeminiConnectionState: estado inalterado mas '
          'connected=true — forçando notifyListeners() para remontar UI');
      notifyListeners();
    }
  }

  Future<bool> _ensureGeminiApiKey({required String source}) async {
    if (GeminiService.hasApiKey) {
      _clearGeminiConfigUnavailable();
      return true;
    }

    // Tenta restaurar do SharedPreferences/localStorage (sem rede)
    await GeminiService.initFromStorage();
    if (GeminiService.hasApiKey) {
      _clearGeminiConfigUnavailable();
      debugPrint('[checkGeminiSession] API Key restaurada do SharedPrefs ($source) ✓');
      return true;
    }

    // Nota: cooldown de _ensureGeminiApiKey foi removido.
    // O FirestoreService já gerencia cooldown interno para erros de rede/quota.
    // Para permission-denied (usuário não-admin), não há cooldown — a chamada
    // é rápida e é esperado que falhe; o fallback para SharedPrefs já foi tentado.

    // ── BUILD 463-A.1: SECTOR 3 — Bloqueia fetch Firestore se barreira não authReady ──
    // Quando geminiConnected transitiona false→true, verifica o estado da barreira.
    // Se não estiver authReady, descarta o fetch secundário para evitar amplificação
    // de race conditions.
    if (_currentAuthBarrierState != AppAuthBarrierState.authReady) {
      debugPrint('[FIRESTORE_AUTH_BARRIER] '
          'operation=loadGeminiApiKey '
          'allowed=false '
          'reason=barrier_active '
          'state=${_currentAuthBarrierState.name}');
      _markGeminiConfigUnavailable();
      return false;
    }

    debugPrint('[checkGeminiSession] API Key ausente — tentando Firestore...');
    try {
      final geminiKey = await FirestoreService.loadGeminiApiKey()
          .timeout(const Duration(seconds: 5));
      if (geminiKey.isNotEmpty) {
        GeminiService.setGeminiApiKey(geminiKey, source: GeminiKeySource.appConfig); // BUILD 294
        _clearGeminiConfigUnavailable();
        debugPrint('[checkGeminiSession] API Key recarregada do Firestore ✓');
        return true;
      }
    } catch (e) {
      debugPrint('[checkGeminiSession] Firestore falhou: $e — tentando SharedPrefs...');
    }

    // Segunda tentativa de SharedPrefs (pode ter sido persistido após a primeira tentativa)
    await GeminiService.initFromStorage();
    if (GeminiService.hasApiKey) {
      _clearGeminiConfigUnavailable();
      debugPrint('[checkGeminiSession] API Key restaurada do SharedPrefs (fallback) ✓');
      return true;
    }

    // API Key não disponível para este usuário (não-admin sem chave cacheada)
    _geminiApiKeyUnavailable = true;
    debugPrint('[checkGeminiSession] API Key não disponível para este usuário (Firestore: permission-denied ou vazio)');
    return false;
  }

  /// Verifica silenciosamente se há sessão Gemini ativa (chamado no login).
  /// Nunca propaga exceção nem modifica _geminiLoading — é 100% silencioso.
  ///
  /// Nova lógica (Session 4 — API Key auth):
  ///   Fluxo redirect OAuth (Safari/web):
  ///   1. JS em index.html salva email (via tokeninfo) + seta 'medcases_gsi_pending'
  ///   2. Este método detecta a flag, lê o email do localStorage
  ///   3. _geminiConnected = true se email salvo E Gemini API Key carregada
  Future<void> checkGeminiSession() {
    final inFlight = _geminiSessionCheckInFlight;
    if (inFlight != null) return inFlight;

    final future = () async {
      try {
        // ── BUILD 277: SECURITY WIPE for non-admin/non-master accounts ────────
        // On every boot, if the active account is NOT privileged, forcibly purge
        // any cached API key from SharedPreferences and localStorage so that a
        // key loaded during a previous admin session cannot bleed into a regular
        // user's session. Admin/master accounts skip this wipe — their key
        // loading proceeds normally through _ensureGeminiApiKey().
        //
        // ⚠️  BUILD 277 FIX: Detect pending OAuth redirect BEFORE the wipe runs.
        // The race condition: setUser() is called by the auth stream right after
        // the OAuth redirect completes. At that instant _syncFromFirestore() has
        // NOT finished yet, so isAdmin/isMaster are still false for privileged
        // users. If we wipe here we destroy `gemini_google_email` and
        // `medcases_gak` that the JS on index.html saved during the redirect —
        // the OAuth detection block below (line ~1978) then finds an empty email
        // and silently aborts, leaving the user with no Gemini key.
        //
        // Guard: if medcases_gsi_pending is set in either localStorage or
        // sessionStorage, an OAuth redirect just completed. Skip the wipe
        // entirely — the key/email written by the redirect JS are still needed.
        // The wipe will run naturally on the NEXT cold boot when the flag is
        // gone and Firestore has had time to resolve isAdmin/isMaster correctly.
        final bool hasPendingOAuthRedirect = kIsWeb && (
          (_webGetLS('medcases_gsi_pending') == 'true') ||
          (_webSsGet('medcases_gsi_pending') == 'true')
        );

        // BUILD 290: aguarda o Future de _syncFromFirestore() diretamente.
        // Event-driven: zero delay artificial — o boot segue no instante em que
        // o sync completar (ou se já completou, retorna imediatamente).
        // Timeout 6s como safety-net para redes muito lentas ou offline.
        final syncFuture = _firestoreSyncFuture;
        if (syncFuture != null) {
          debugPrint('[BUILD290][SecurityWipe] aguardando _syncFromFirestore (event-driven)...');
          await syncFuture.timeout(
            const Duration(seconds: 6),
            onTimeout: () {
              debugPrint('[BUILD290][SecurityWipe] sync timeout 6s — usando isAdmin/isMaster do cache local');
            },
          );
          debugPrint('[BUILD290][SecurityWipe] sync concluído — isAdmin=$isAdmin isMaster=$isMaster');
        }

        final bool isPrivileged = isAdmin || isMaster;
        if (!isPrivileged && !hasPendingOAuthRedirect) {
          // BUILD 293: wipe apenas UMA vez por sessão de login.
          // Sem esta flag, o wipe apaga a chave → stream re-emite → setUser()
          // re-chamado → checkGeminiSession() → wipe novamente → loop infinito.
          if (!_apiKeyWipedThisSession) {
            _apiKeyWipedThisSession = true;
            try {
              // BUILD 294: clearOAuthCachedApiKey() é a versão segura — só apaga
              // chaves de origem oauth/admin/cache. NUNCA apaga appConfig.
              // Se a chave veio de app_config/global, log mostra 'skipped' e
              // o bool retornado é false — SharedPrefs/localStorage preservados.
              final wiped = GeminiService.clearOAuthCachedApiKey();
              if (wiped) {
                // Só limpa SharedPrefs/localStorage se realmente era OAuth key
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('medcases_gak');
                if (kIsWeb) {
                  _webRemoveLS('medcases_gak');
                  _webRemoveLS('gemini_google_email');
                }
              }
              debugPrint('[BUILD294][SecurityWipe] wiped=$wiped '
                  'source=${GeminiService.keySource.name}');
            } catch (e) {
              debugPrint('[BUILD294][SecurityWipe] wipe error (non-fatal): $e');
            }
          } else {
            debugPrint('[BUILD293][SecurityWipe] wipe já executado nesta sessão — ignorado (loop guard)');
          }
        } else if (hasPendingOAuthRedirect) {
          // OAuth redirect em progresso — wipe SUPRIMIDO para preservar o email
          // e a API key que o JS gravou durante o redirect. O Firestore ainda
          // está sincronizando isAdmin/isMaster — tentaremos novamente no
          // próximo boot quando o estado já estiver estável.
          debugPrint('[BUILD277][SecurityWipe] OAuth redirect pendente — wipe SUPRIMIDO (isPrivileged=$isPrivileged)');
        }

        if (_geminiConnected && _geminiEmail.isNotEmpty && GeminiService.hasApiKey) {
          return;
        }

        if (kIsWeb) {
          // Limpa flag de modal órfã (pode sobrar de tentativas anteriores)
          _webRemoveLS('medcases_gsi_modal_opened');
          // BUILD 315: limpa chave legada do Build 14 M3 (pode estar em localStorage
          // de usuários que fizeram redirect com builds anteriores).
          _webRemoveLS('medcases_redirect_from_ai_tab');

          // ── Detecta retorno do redirect OAuth ─────────────────────────────
          // Safari ITP pode bloquear localStorage no redirect — lê também de
          // sessionStorage que é imune ao ITP dentro da mesma aba.
          final pendingLs = _webGetLS('medcases_gsi_pending');
          final pendingSs = _webSsGet('medcases_gsi_pending');
          final pending   = pendingLs == 'true' || pendingSs == 'true';

          if (pending) {
            // Remove flag de ambos os storages
            _webRemoveLS('medcases_gsi_pending');
            _webSsRemove('medcases_gsi_pending');

            // Tenta ler email: localStorage primeiro, depois sessionStorage
            var email = _webGetLS('gemini_google_email') ?? '';
            if (email.isEmpty) email = _webSsGet('gemini_google_email') ?? '';

            if (email.isEmpty) {
              // Aguarda até 1500ms pelo fetch tokeninfo (fallback assíncrono do JS)
              // O id_token JWT já deveria ter populado o email sincronamente;
              // este delay cobre o caso do fallback fetch (sem id_token no hash).
              for (var i = 0; i < 3; i++) {
                await Future.delayed(const Duration(milliseconds: 500));
                email = _webGetLS('gemini_google_email') ?? '';
                if (email.isEmpty) email = _webSsGet('gemini_google_email') ?? '';
                if (email.isNotEmpty) break;
              }
            }
            if (email.isEmpty) {
              email = await GeminiService.connectedEmail() ?? '';
            }
            if (email.isNotEmpty) {
              // Copia email para localStorage se só estava no sessionStorage
              if ((_webGetLS('gemini_google_email') ?? '').isEmpty) {
                _webSetLS('gemini_google_email', email);
              }
              final hasKey = await _ensureGeminiApiKey(source: 'pós-redirect');
              if (!hasKey) return;
              _setGeminiConnectionState(connected: true, email: email);
              // SUPER ORDEM MASTER 315: restaura aba de origem pós-OAuth redirect.
              // Lê o índice salvo antes do redirect em 'medcases_pre_auth_tab_index'.
              // Dispara postOAuthTabNotifier em runtime — corrige race condition do
              // Build 14 M3 onde postOAuthAiTab era lido antes do checkGeminiSession().
              if (kIsWeb) {
                final savedIdx = _webGetLS('medcases_pre_auth_tab_index');
                if (savedIdx != null && savedIdx.isNotEmpty) {
                  _webRemoveLS('medcases_pre_auth_tab_index');
                  final tabIdx = int.tryParse(savedIdx) ?? 2;
                  // Dispara o notifier via microtask (sem WidgetsBinding — app_provider
                  // não importa flutter/widgets.dart). Future.microtask() garante que
                  // o listener do MainShell já está registrado antes do evento disparar.
                  Future.microtask(() {
                    AppProvider.postOAuthTabNotifier.value = tabIdx;
                    debugPrint('[MASTER315] redirect pós-OAuth → aba $tabIdx sinalizada via notifier');
                  });
                }
              }
              debugPrint('[checkGeminiSession] redirect OAuth OK — $email, apiKey: ${GeminiService.hasApiKey}');
              return;
            }
            debugPrint('[checkGeminiSession] pending=true mas email vazio após 1500ms — redirect falhou');
          }
        }

        final hasKey = await _ensureGeminiApiKey(source: 'sessão existente');
        if (!hasKey) return;

        final connected = await GeminiService.isConnected()
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
        if (connected) {
          final email = await GeminiService.connectedEmail() ?? '';
          _setGeminiConnectionState(connected: true, email: email);
          debugPrint('[checkGeminiSession] sessão existente — $email, apiKey: ${GeminiService.hasApiKey}');
          return;
        }

        if (_geminiConnected || _geminiEmail.isNotEmpty) {
          _setGeminiConnectionState(connected: false, notify: false);
        }
      } catch (e) {
        debugPrint('[checkGeminiSession] erro: $e');
        _setGeminiConnectionState(connected: false, notify: false);
      } finally {
        _geminiSessionCheckInFlight = null;
      }
    }();

    _geminiSessionCheckInFlight = future;
    return future;
  }


  /// Lê um valor do localStorage via função global window.mcLsGet.
  /// A função é registrada no index.html ANTES do Firebase/SES lockdown ser
  /// aplicado — captura a referência nativa ao localStorage enquanto ainda
  /// é acessível. Sem eval, sem proxies congelados: compatível com qualquer CSP.
  String? _webGetLS(String key) {
    if (!kIsWeb) return null;
    try {
      final result = webLsGet(key);
      if (result == null || result.toString() == 'null') return null;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Grava um valor no localStorage via função global window.mcLsSet.
  /// Sem eval — compatível com CSP strict e SES lockdown do Firebase Auth.
  void _webSetLS(String key, String value) {
    if (!kIsWeb) return;
    try {
      webLsSet(key, value);
    } catch (_) {}
  }

  /// Remove uma chave do localStorage via função global window.mcLsRemove.
  /// Sem eval — compatível com CSP strict e SES lockdown do Firebase Auth.
  void _webRemoveLS(String key) {
    if (!kIsWeb) return;
    try {
      webLsRemove(key);
    } catch (_) {}
  }

  // ── sessionStorage helpers — fallback para Safari ITP ────────────────────
  // Safari ITP pode bloquear localStorage em contexto de redirect cross-origin.
  // sessionStorage é imune ao ITP dentro da mesma aba e sobrevive ao redirect.

  String? _webSsGet(String key) {
    if (!kIsWeb) return null;
    try {
      final result = webSsGet(key);
      if (result == null || result.toString() == 'null') return null;
      return result;
    } catch (_) {
      return null;
    }
  }

  void _webSsRemove(String key) {
    if (!kIsWeb) return;
    try { webSsRemove(key); } catch (_) {}
  }

  // ── Stopwords clínicas — palavras genéricas que sozinhas NÃO ativam RAG ──
  // Uma query composta apenas por estas palavras não deve puxar nenhum protocolo
  // nem fármaco, pois o match seria falso positivo (ex: "qual a dose?" → não
  // deve puxar "Doença de Chagas" só porque "dose" aparece lá dentro).
  // IMPORTANTE: sem duplicatas — Dart `const Set` falha se houver elemento repetido.
  static const _clinicalStopwords = <String>{
    // ── Genéricos de tratamento (PT-BR) ──────────────────────────────────────
    'tratamento', 'tratar', 'terapia', 'terapeutica',
    'adequar', 'ajustar', 'ajuste',
    // ── Paciente (PT-BR) ─────────────────────────────────────────────────────
    'paciente', 'doente', 'individuo', 'pessoa',
    // ── Dose (PT-BR) ─────────────────────────────────────────────────────────
    'dose', 'dosagem', 'posologia',
    // ── Uso (PT-BR) ──────────────────────────────────────────────────────────
    'usar', 'uso', 'utilizacao', 'utilizar',
    // ── Quadro clínico (PT-BR) ───────────────────────────────────────────────
    'quadro', 'apresenta', 'apresentacao',
    // ── Caso (PT-BR) ─────────────────────────────────────────────────────────
    'caso', 'casos',
    // ── Faixa etária (PT-BR) ─────────────────────────────────────────────────
    'adulto', 'adultos', 'idoso', 'idosos', 'pediatrico', 'crianca',
    // ── Diagnóstico genérico (PT-BR) ─────────────────────────────────────────
    'doenca', 'patologia', 'condicao', 'sindrome',
    // ── Conduta (PT-BR) ──────────────────────────────────────────────────────
    'conduta', 'manejo', 'abordagem', 'protocolo',
    // ── Prescrição (PT-BR) ───────────────────────────────────────────────────
    'prescricao', 'prescrever', 'medicamento', 'medicacao',
    // ── Interrogativas (PT-BR) ───────────────────────────────────────────────
    'quando', 'como', 'qual', 'quais', 'onde', 'porque', 'motivo',
    // ── Tempo (PT-BR) ────────────────────────────────────────────────────────
    'inicio', 'duracao', 'tempo', 'periodo',
    // ── Sintoma (PT-BR) ──────────────────────────────────────────────────────
    'sintoma', 'sinal', 'queixa', 'historia',
    // ── Forma/tipo (PT-BR) ───────────────────────────────────────────────────
    'forma', 'tipo', 'tipos', 'classe', 'grupo',
    // ── Genéricos de tratamento (ES) — apenas os não presentes acima ─────────
    'tratamiento', 'terapeutico', 'adecuar',
    // ── Paciente (ES) ────────────────────────────────────────────────────────
    'enfermo',
    // ── Dose (ES) ────────────────────────────────────────────────────────────
    'dosis',
    // ── Uso (ES) ─────────────────────────────────────────────────────────────
    'utilizacion',
    // ── Quadro clínico (ES) ──────────────────────────────────────────────────
    'cuadro', 'presenta', 'presentacion',
    // ── Faixa etária (ES) ────────────────────────────────────────────────────
    'anciano',
    // ── Diagnóstico genérico (ES) ────────────────────────────────────────────
    'enfermedad', 'condicion',
    // ── Conduta (ES) ─────────────────────────────────────────────────────────
    'conducta', 'abordaje',
    // ── Prescrição (ES) ──────────────────────────────────────────────────────
    'prescripcion', 'prescribir',
    // ── Interrogativas (ES) — apenas as que diferem de PT ────────────────────
    'cuando', 'cuales',
    // ── Tempo (ES) ───────────────────────────────────────────────────────────
    'duracion', 'tiempo',
    // ── Sintoma (ES) ─────────────────────────────────────────────────────────
    'signo', 'queja',
    // ── Forma/tipo (ES) ──────────────────────────────────────────────────────
    'clase',
    // ── Modificadores de severidade (ES) ──────────────────────────────────────
    'agudo', 'aguda', 'cronico', 'cronica', 'grave', 'leve', 'moderado', 'moderada',
    'severo', 'severa', 'subagudo', 'subaguda',
    // ── Indicação / linha terapêutica (ES) ────────────────────────────────────
    'indicado', 'indicada', 'indicacion', 'indicaciones',
    'primera', 'segunda', 'linea',
    // ── Genérico fármaco (ES) ──────────────────────────────────────────────────
    'farmaco', 'farmacos', 'farmacoterapia',
    // ── Contexto / frequência (ES) ────────────────────────────────────────────
    'segun', 'dependiendo', 'generalmente', 'habitualmente',
  };

  /// Verifica se a query tem pelo menos uma palavra clínica substantiva
  /// (não-stopword, length > 3). Usado para evitar match em queries genéricas.
  bool _hasSubstantiveWord(List<String> words) {
    return words.any((w) => w.length > 3 && !_clinicalStopwords.contains(w));
  }

  /// Retorna sumários dos protocolos cujos títulos/reconhecer contenham keywords da query
  List<String> _matchProtocols(String normalizedQuery) {
    // Protocolos de alta emergência exigem ≥2 palavras da query para match,
    // evitando falsos positivos (ex: "cefaleia" na gripe injeta AVC/HSA).
    const _highRiskIds = {
      'avc_hemorragico', 'avc_isquemico', 'pcr_adulto', 'choque_cardiogenico',
      'hsa', 'meningite', 'sepse', 'iam_congestao', 'tep', 'status_epilepticus',
      // Protocolos com sintomas genéricos (cefaleia, náusea) no recognize:
      // exigem ≥2 palavras para evitar falso positivo em queries simples.
      'eclampsia_hellp', 'hiponatremia_grave', 'intox_monoxido_carbono',
      'caso_enxaqueca_aura', 'gripe_influenza_010',
      // Protocolos psiquiátricos — exigem 2 palavras para não contaminar
      // queries sobre fármacos de outras especialidades (ex: "haloperidol em TEP")
      'agitacao_psicomotriz', 'agitacion_psicom', 'psicose_aguda', 'psicosis_aguda',
      'esquizofrenia', 'bipolar', 'delirium', 'abstinencia_alcool',
    };

    final allWords = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();

    // Fix 2: Bloquear match se não houver pelo menos 1 palavra clínica substantiva
    // (palavra fora das stopwords). Impede "qual a conduta para o paciente?"
    // de puxar qualquer protocolo.
    if (!_hasSubstantiveWord(allWords)) return [];

    // Filtrar stopwords para o match — só palavras com conteúdo clínico real
    final words = allWords
        .where((w) => !_clinicalStopwords.contains(w))
        .toList();

    // Se após filtrar não sobrar nenhuma palavra, abortar retrieval
    if (words.isEmpty) return [];

    final results = <String>[];

    for (final p in protocolsDatabase) {
      final title    = _normalize(tDB(p.title));
      final recognize = _normalize(tDB(p.recognize));

      // Conta quantas palavras clínicas (não-stopword) da query aparecem no título ou recognize
      final matchCount = words.where((w) => title.contains(w) || recognize.contains(w)).length;

      // Protocolo de alta emergência: exige ≥2 palavras para evitar falso positivo
      final isHighRisk = _highRiskIds.any((id) => p.id.contains(id));
      final minScore   = isHighRisk ? 2 : 1;

      if (matchCount >= minScore) {
        final actions = p.getActions(_lang).take(3).join(' | ');
        results.add('• [${tDB(p.title)}] Reconhecer: ${tDB(p.recognize).substring(0, tDB(p.recognize).length.clamp(0, 120))}... Conduta: $actions');
        if (results.length >= 4) break; // máx 4 protocolos para não exceder tokens
      }
    }
    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CLASSIFICADOR DE INTENT — detecta o tipo de consulta para RAG direcionado
  // ══════════════════════════════════════════════════════════════════════════

  /// Classifica o tipo de consulta para direcionar o pipeline RAG.
  /// Retorna string descritiva usada no system prompt como contexto para o Gemini.
  /// Classifica o intent em chave canônica curta usada pelo switch no system prompt.
  /// Ordem importa: mais específico antes de mais genérico.
  String _classifyIntent(String input) {
    final q = _normalize(input);

    // ── Referências bibliográficas ──────────────────────────────────────────
    if (_has(q, ['referencia', 'referencias', 'fonte ', 'fontes', 'bibliografia',
                  'bibliograf', 'citation', 'citar', 'quais fontes', 'qual fonte',
                  'baseado em que', 'evidencia usada', 'guideline usado'])) {
      return 'referencias';
    }

    // ── Fisiopatologia / mecanismo da doença ────────────────────────────────
    if (_has(q, ['fisiopatolog', 'patogenese', 'patogenia', 'mecanismo da doenca',
                  'mecanismo de doenca', 'mecanismo patolog', 'como ocorre a doenca',
                  'como se desenvolve', 'mecanismo fisio', 'fisiopatologia de',
                  'patofisiolog', 'por que ocorre a', 'porque ocorre a'])) {
      return 'fisiopatologia';
    }

    // ── Causas / etiologia ──────────────────────────────────────────────────
    if (_has(q, ['causa ', 'causas ', 'etiolog', 'fator de risco', 'fatores de risco',
                  'factor de riesgo', 'factores de riesgo', 'por que da ', 'porque da ',
                  'o que causa', 'que causa', 'origem de', 'precipita '])) {
      return 'causas';
    }

    // ── Prognóstico / seguimento ────────────────────────────────────────────
    if (_has(q, ['prognostico', 'prognosis', 'pronostico', 'sobrevida', 'mortalidade',
                  'mortalidad', 'seguimento', 'seguimiento', 'acompanhamento',
                  'fator de mau prognostico', 'factor de mal pronostico', 'sobrevivencia'])) {
      return 'prognostico';
    }

    // ── Interação medicamentosa ─────────────────────────────────────────────
    if (_has(q, ['interac', 'interage', 'junto com', 'junto a',
                  'associar com', 'associar a', 'compativel', 'combinacion', 'asociar'])) {
      return 'interacao';
    }

    // ── Emergência / urgência ───────────────────────────────────────────────
    if (_has(q, ['emergencia', 'urgencia', 'pcr ', 'parada cardiac',
                  'choque ', 'shock ', 'anafilax', 'status epilep', 'estado epilep',
                  'protocolo de emergencia', 'iam agudo', 'avc agudo', 'sepse grave'])) {
      return 'emergencia';
    }

    // ── Caso clínico — dados clínicos estruturados ──────────────────────────
    if (_has(q, ['paciente', 'pa ', 'fc ', 'spo2', 'glasgow', 'anos ', 'anos,',
                  'apresenta', 'presenta', 'admitido', 'ingresado', 'internado',
                  'temperatura', 'febre ', 'fiebre ']) &&
        input.trim().split(' ').length >= 6) {
      return 'caso_clinico';
    }

    // ── Tratamento / conduta ────────────────────────────────────────────────
    // REGRA: "tratamento" ou "tratamiento" sozinho NÃO ativa o MODO [A] —
    // sem condição especificada, o modelo não sabe o que tratar.
    // Palavras compostas ("tratamento da", "tratar o", "manejo de") ou
    // queries de 2+ palavras com keyword de tratamento → MODO [A].
    final hasTreatKeyword = _has(q, [
      'tratamento da', 'tratamento do', 'tratamento de', 'tratamento para',
      'tratamiento de', 'tratamiento del', 'tratamiento para',
      'tratar ', 'tratar a', 'tratar o', 'tratar el', 'tratar la',
      'conduta para', 'conduta da', 'conduta do', 'conducta para', 'conducta del',
      'manejo de', 'manejo da', 'manejo do', 'manejo del',
      'como tratar', 'como manejar', 'terapia para', 'terapia de',
      'protocolo de tratamento', 'primeira linha', 'primera linea',
    ]);
    // "tratamento" ou "conduta" sozinhos com outra palavra (não é query vazia)
    final hasTreatAlone = (q == 'tratamento' || q == 'tratamiento' ||
                           q == 'conduta'    || q == 'conducta') &&
                          input.trim().split(RegExp(r'\s+')).length == 1;
    if (hasTreatKeyword && !hasTreatAlone) {
      return 'tratamento';
    }
    // Também ativa se "tratamento"/"tratamiento" aparece com pelo menos 1 outra palavra
    if (!hasTreatAlone &&
        (_has(q, ['tratamento', 'tratamiento', 'conduta', 'conducta']) &&
         input.trim().split(RegExp(r'\s+')).length >= 2)) {
      return 'tratamento';
    }

    // ── Psicofármaco / antipsicótico / psiquiatria ─────────────────────────
    if (_has(q, [
      // Antipsicóticos típicos
      'antipsicotico', 'antipsicótico', 'antipsicóticos', 'antipsychotic',
      'haloperidol', 'haldol', 'droperidol',
      'clorpromazina', 'amplictil', 'thorazine',
      'tioridazina', 'levomepromazina', 'flufenazina',
      'zuclopentixol', 'pimozida', 'sulpirida',
      // Antipsicóticos atípicos
      'risperidona', 'risperdal', 'olanzapina', 'zyprexa',
      'quetiapina', 'seroquel', 'clozapina', 'clozaril', 'leponex',
      'aripiprazol', 'abilify', 'ziprasidona', 'geodon',
      'amisulprida', 'paliperidona', 'lurasidona', 'iloperidona',
      'cariprazina', 'brexpiprazol', 'asenapina',
      // SSRI/SNRI por nome
      'ssri', 'isrs', 'antidepressivo', 'antidepresivo',
      'sertralina', 'fluoxetina', 'paroxetina', 'escitalopram', 'citalopram',
      'fluvoxamina', 'venlafaxina', 'duloxetina', 'desvenlafaxina',
      'milnaciprana', 'mirtazapina', 'trazodona', 'agomelatina', 'vortioxetina',
      // TCAs e IMAOs
      'amitriptilina', 'nortriptilina', 'imipramina', 'clomipramina',
      'desipramina', 'doxepina', 'tranilcipromina', 'fenelzina',
      'moclobemida', 'inibidor monoaminoxidase', 'imao ',
      'antidepressivo triciclico', 'antidepressivo tricicl',
      // Estabilizadores de humor
      'estabilizador humor', 'lition', 'litio ', 'lithium',
      'valproato', 'acido valproico', 'depakote',
      'lamotrigina', 'lamictal', 'carbamazepina', 'tegretol',
      'oxcarbazepina', 'topiramato',
      // Benzodiazepínicos e hipnóticos
      'ansiolit', 'benzodiazep', 'benzo ',
      'diazepam', 'lorazepam', 'clonazepam', 'alprazolam',
      'midazolam', 'bromazepam', 'clobazam',
      'zolpidem', 'zopiclona', 'eszopiclona',
      // Ansiolíticos não-benzo
      'buspirona', 'buspar',
      // Condições psiquiátricas
      'psicosis', 'psicose', 'psicotico', 'psicótico', 'psychosis',
      'brote psic', 'brote maniac', 'brote acut',
      'episodio psicotico', 'episodio maniac', 'episodio hipomania',
      'esquizofrenia', 'schizophrenia', 'esquizofren',
      'delirio psicot', 'alucinacion', 'alucinacoes',
      'agitacion psic', 'agitação psic', 'agitacion agud',
      'psicose aguda', 'psicosis aguda',
      'delirium ', 'confusao agud', 'sindrome confusional agud',
      'depressao maior', 'depressao unipolar', 'depressao bipol',
      'mania agud', 'hipomania', 'episodio maniaco',
      'ansiedade generalizada', 'tag ', 'transtorno ansied',
      'panico psiquiat', 'crise panico',
      'toc ', 'transtorno obsessivo',
      'tept ', 'ptsd ',
      'tdah ', 'adhd ', 'deficit atencao',
      'transtorno personalidade', 'borderline',
      'automutilacao', 'ideacao suicid', 'tentativa suicid',
      'comportamento suicida', 'pensamento suicida',
      'abstinencia alcool', 'delirium tremens', 'withdrawal',
      'sindrome neuroleptica', 'sindrome serotonin',
      'sind neuroleptica', 'emergencia psiquiatric',
    ])) {
      return 'psicofarmaco';
    }

    // ── Farmacológica — fármaco específico ou keywords de dose/posologia ────
    // Build 188: prioridade correta — fármaco específico detectado na drugsDatabase
    // > keywords genéricas de dose. "ceftriaxona" sozinho = farmaco.
    // "ceftriaxona dose" = farmaco (não pediatria, não geral).
    // Só classifica como 'pediatria' se não houver fármaco específico detectado.
    final hasPharmacyKeyword = _has(q, [
      'farmaco', 'farmacos', 'medicament', 'remedio ', 'remedios',
      'droga ', 'antibiot', 'antibio', 'antiviral', 'antifungic',
      'dose', 'dosagem', 'dosis', 'posolog', 'mecanismo de acao',
      'mecanismo de accion', 'indicac', 'contraindicac',
      'efeito adverso', 'efecto adverso', 'ajuste renal', 'gravidez',
    ]);
    if (hasPharmacyKeyword) {
      return 'farmaco';
    }

    // ── Diagnóstico / critérios / definição ────────────────────────────────
    if (_has(q, ['diagnostico', 'diagnosticar', 'criterio', 'criterios',
                  'como diagnosticar', 'diagnostico diferencial', 'classificac',
                  'clasificacion', 'o que e ', 'que es ', 'definic', 'definicion',
                  'exame para diagnosticar', 'exame', 'laborator', 'interpretar'])) {
      return 'diagnostico';
    }

    // ── Condição/doença clínica — palavra única ou curta ───────────────────
    // Queries de 1-4 palavras que são nomes de condições → tratamento direto
    // "diarrea", "fiebre", "pneumonia", "hipertensão" → MODO [A] conduta
    // Sem este bloco, essas queries caem em 'geral' e geram resposta enciclopédica
    final wordCount = input.trim().split(RegExp(r'\s+')).length;
    if (wordCount <= 4) {
      if (_has(q, [
        // Gastrointestinal
        'diarrea', 'diarreia', 'gastroenterit', 'vomito', 'vômito', 'nausea',
        'constipac', 'estrenim', 'hemorragia digest', 'sangrado digest',
        'hepatit', 'cirros', 'colecistit', 'pancreatit', 'apendicit',
        'peritonit', 'obstrucao', 'obstruccion', 'oclusion',
        'ictericia', 'ictericia', 'melena', 'hematoquecia',
        // Respiratório
        'pneumonia', 'bronquit', 'bronchit', 'neumonia',
        'asma', 'dpoc', 'epoc', 'pleurit', 'derrame pleural',
        'embolia pulmon', 'tep ', 'insuficiencia respirat', 'insuficiência respirat',
        'dispneia', 'disnea', 'tosse', 'tos ',
        // Cardiovascular
        'hipertensao', 'hipertension', 'insuficiencia cardiaca', 'insuficiência cardíaca',
        'infarto', 'angina', 'arritmia', 'fibrilacao', 'fibrilacion',
        'trombose', 'trombosis', 'endocardite', 'endocarditis',
        'pericardite', 'pericarditis', 'miocardite', 'miocarditis',
        'edema agudo', 'edema pulmon',
        // Infeccioso
        'febre', 'fiebre',
        'sepse', 'sepsis', 'meningite', 'meningitis', 'encefalite', 'encefalitis',
        'celulite infec', 'celulitis', 'erisipela',
        'endocardite', 'pielonefrit', 'cistit', 'itu ', 'itu.',
        'tuberculose', 'tuberculosis', 'dengue', 'malaria', 'paludismo',
        'covid', 'influenza', 'hiv', 'aids', 'sida',
        'leptospiros', 'chikungunya', 'zika',
        // Metabólico/Endócrino
        'diabetes', 'cetoacidose', 'cetoacidosis', 'hipoglicemia', 'hipoglucemia',
        'hiperglicemia', 'hiperglucemia', 'dislipidemia', 'hipotireoid', 'hipotiroidi',
        'hipertireoid', 'hipertiroid', 'insuficiencia renal', 'insuficiência renal',
        'insuficiencia hepatica', 'insuficiência hepática',
        'hipocalemia', 'hipopotasemia', 'hiponatremia', 'hipercalemia', 'hipernatremia',
        // Neurológico
        'convulsao', 'convulsion', 'epilepsia', 'avc ', 'avc.', 'acv ', 'acv.',
        'enxaqueca', 'migrana', 'migrania', 'migraine', 'delirium',
        'acidente vascular', 'acidente cerebro',
        // Renal
        'insuficiencia renal', 'lesao renal', 'lesion renal', 'nefrit',
        // Hematológico
        'anemia', 'trombocitopenia', 'leucemia', 'linfoma',
        'coagulacao intravascular', 'civd', 'cid ',
        // Reumatológico
        'artrit', 'lupus', 'escleroderm', 'vasculit',
        'gota ', 'gota.',
        // Dor — sintoma inespecífico mas clinicamente válido
        'cefaleia', 'cefalea', 'dor cronic', 'dolor cron',
        'dor abdomin', 'dolor abdomin', 'dor torac', 'dolor toraci',
        // Choque / colapso
        'choque ', 'shock ',
        // Dermatológico
        'dermatite', 'dermatitis', 'urticaria', 'urticária', 'prurido', 'prurito',
        'herpes', 'celulite',
        // Psiquiátrico leve (conduta ≠ psicofármaco)
        'ansiedade', 'ansiedad', 'depressao', 'depresion', 'insonia', 'insomnio',
      ])) {
        return 'tratamento';
      }
    }

    return 'geral';
  }

  /// Verifica se a pergunta é uma query direta/nova (não deve herdar histórico)
  bool _isDirectQuery(String input) {
    final q = input.toLowerCase().trim();
    final directPrefixes = [
      'buscar em gemini:', 'buscar gemini:', 'buscar:', 'pesquisar:',
      'gemini:', 'ia:', 'perguntar:', 'consultar:',
      'search:', 'busca:', 'o que é ', 'o que e ',
      'qual é ', 'qual e ', 'como ', 'quando ', 'por que ', 'porque ',
      'explique ', 'explica ', 'defina ', 'define ',
      'se es ', 'si es ', 'si tiene ', 'se tem ', 'se tiene ',
      'por que no ', 'porque no ', 'por qué no ', 'por que usar ',
      'por que não ', 'pode usar ', 'puede usar ', 'posso dar ',
      'é indicado', 'está indicado', 'está contraindicado',
    ];
    if (directPrefixes.any((p) => q.startsWith(p))) return true;

    // Nomes de fármacos específicos na pergunta → query direta (nunca herdar histórico)
    // LISTA EXPANDIDA — cobre os 541 fármacos da base + variantes PT/ES
    final hasDrugKeyword = _has(_normalize(input), [
      // ── ANTIPSICÓTICOS ───────────────────────────────────────────────────────
      'haloperidol', 'haldol',
      'risperidona', 'risperdal', 'risperidon',
      'olanzapina', 'zyprexa', 'olanzapin',
      'quetiapina', 'seroquel', 'quetiaquin',
      'clozapina', 'clozaril', 'leponex', 'clozapin',
      'aripiprazol', 'abilify', 'aripiprazole',
      'ziprasidona', 'geodon', 'ziprasidon',
      'amisulprida', 'solian', 'amisulprid',
      'clorpromazina', 'amplictil', 'thorazine', 'clorpromazin',
      'tioridazina', 'mellaril', 'tioridazin',
      'levomepromazina', 'nozinan', 'methotrimeprazin',
      'zuclopentixol', 'clopixol',
      'flufenazina', 'fluphenazin', 'modecate',
      'pimozida', 'orap',
      'sulpirida', 'sulpirid', 'dogmatil',
      'paliperidona', 'invega', 'xeplion',
      'lurasidona', 'latuda', 'lurasidon',
      'iloperidona', 'fanapt',
      'cariprazina', 'reagila',
      'brexpiprazol', 'rexulti',
      'asenapina', 'sycrest',
      // ── ANTIDEPRESSIVOS SSRI/SNRI/TCA/IMAO ──────────────────────────────────
      'sertralina', 'zoloft', 'sertraline',
      'fluoxetina', 'prozac', 'fluoxetin',
      'paroxetina', 'paxil', 'seroxat', 'paroxetin',
      'escitalopram', 'lexapro', 'cipralex',
      'citalopram', 'celexa',
      'fluvoxamina', 'luvox', 'fluvoxamin',
      'venlafaxina', 'effexor', 'venlafaxin',
      'desvenlafaxina', 'pristiq', 'desvenlafaxin',
      'duloxetina', 'cymbalta', 'duloxetin',
      'milnaciprana', 'savella', 'milnacipran',
      'levomilnaciprana', 'fetzima',
      'amitriptilina', 'elavil', 'amitriptylin',
      'nortriptilina', 'pamelor', 'nortriptylin',
      'imipramina', 'tofranil', 'imipramin',
      'clomipramina', 'anafranil', 'clomipramim',
      'desipramina', 'norpramin',
      'doxepina', 'sinequan',
      'mirtazapina', 'remeron', 'mirtazapin',
      'trazodona', 'desyrel', 'trazodone',
      'bupropiona', 'wellbutrin', 'zyban', 'bupropion',
      'agomelatina', 'valdoxan', 'agomelatine',
      'vortioxetina', 'brintellix', 'vortioxetin',
      'nefazodona', 'serzone',
      'tranilcipromina', 'parnate', 'tranylcypromin',
      'fenelzina', 'nardil', 'phenelzin',
      'moclobemida', 'manerix', 'moclobemid',
      'selegilina', 'eldepryl', 'selegilin',
      // ── ESTABILIZADORES DE HUMOR ─────────────────────────────────────────────
      'litio', 'lition', 'lithium', 'carbolith', 'eskalith',
      'valproato', 'acido valproico', 'depakene', 'depakote', 'valproic',
      'acido valproic', 'valproato sodio', 'divalproex',
      'carbamazepina', 'tegretol', 'carbamazepine', 'carbamaz',
      'lamotrigina', 'lamictal', 'lamotrigine',
      'topiramato', 'topamax', 'topiramato',
      'oxcarbazepina', 'trileptal', 'oxcarbazepine',
      'gabapentina', 'neurontin', 'gabapentin',
      'pregabalina', 'lyrica', 'pregabaline',
      // ── BENZODIAZEPÍNICOS E HIPNÓTICOS ──────────────────────────────────────
      'diazepam', 'valium', 'diazepame',
      'midazolam', 'dormicum', 'versed',
      'lorazepam', 'ativan',
      'clonazepam', 'rivotril', 'klonopin',
      'alprazolam', 'xanax',
      'bromazepam', 'lexotan',
      'clobazam', 'frisium',
      'nitrazepam', 'mogadon',
      'triazolam', 'halcion',
      'temazepam', 'restoril',
      'zolpidem', 'ambien', 'stilnox',
      'zopiclona', 'imovane', 'zopiclone',
      'eszopiclona', 'lunesta',
      'zaleplon', 'sonata',
      'flumazenil',
      // ── ANSIOLÍTICOS NÃO-BENZO ───────────────────────────────────────────────
      'buspirona', 'buspar', 'buspirona',
      'hidroxizina', 'atarax', 'vistaril', 'hydroxyzine',
      'meprobamate', 'meprobamato',
      // ── ANTICONVULSIVANTES / ANTIEPILÉPTICOS ─────────────────────────────────
      'fenitoina', 'dilantin', 'phenytoin',
      'fenobarbital', 'luminal', 'phenobarbital',
      'levetiracetam', 'keppra', 'levetiracetame',
      'lacosamida', 'vimpat', 'lacosamide',
      'perampanel', 'fycompa',
      'vigabatrina', 'sabril', 'vigabatrin',
      'tiagabina', 'gabitril', 'tiagabin',
      'rufinamida', 'inovelon',
      'clobazam', 'onfi',
      'eslicarbazepina', 'zebinix',
      'cenobamate', 'xcopri',
      // ── OPIÓIDES E ANALGÉSICOS ───────────────────────────────────────────────
      'morfina', 'morphine',
      'fentanil', 'fentanila', 'fentanyl', 'duragesic',
      'tramadol', 'ultram',
      'codeina', 'codein', 'codeine',
      'metadona', 'methadone', 'dolophine',
      'oxicodona', 'oxycodon', 'oxycontin',
      'hidromorfona', 'hydromorphone', 'dilaudid',
      'buprenorfina', 'subutex', 'suboxone', 'buprenorphin',
      'naloxona', 'narcan', 'naloxone',
      'naltrexona', 'revia', 'naltrexone',
      'tapentadol', 'nucynta',
      'meperidina', 'demerol', 'petidina',
      // ── ANTICOAGULANTES ──────────────────────────────────────────────────────
      'warfarina', 'coumadin', 'warfarine',
      'heparina', 'heparin',
      'enoxaparina', 'clexane', 'lovenox', 'enoxaparin',
      'fondaparinux', 'arixtra',
      'rivaroxabana', 'xarelto', 'rivaroxaban',
      'apixabana', 'eliquis', 'apixaban',
      'dabigatrana', 'pradaxa', 'dabigatran',
      'edoxabana', 'lixiana', 'edoxaban',
      'betrixabana', 'bevyxxa',
      'argatrobana', 'argatroban',
      'bivalirudina', 'angiomax',
      // ── ANTIAGREGANTES ───────────────────────────────────────────────────────
      'clopidogrel', 'plavix',
      'ticagrelor', 'brilinta',
      'prasugrel', 'effient',
      'aspirina', 'aas ', 'acido acetilsalicilico', 'aspirin',
      'ticlopidina', 'ticlid',
      'abciximab', 'reopro',
      'eptifibatida', 'integrilin',
      'tirofibana', 'aggrastat',
      'vorapaxar', 'zontivity',
      // ── CARDIOVASCULARES ─────────────────────────────────────────────────────
      'adrenalina', 'epinefrina', 'epinephrine', 'adrenaline',
      'noradrenalina', 'norepinefrina', 'norepinephrine', 'levophed',
      'dopamina', 'intropin', 'dopamine',
      'dobutamina', 'dobutrex', 'dobutamine',
      'vasopresina', 'vasopressine', 'vasopressin', 'pitressin',
      'terlipressina', 'terlipressin', 'glypressin',
      'milrinona', 'primacor', 'milrinone',
      'levosimendana', 'simdax', 'levosimendan',
      'nitroglicerina', 'nitroglycerin', 'nitrato',
      'nitroprussiato', 'nitroprussid', 'nipride',
      'adenosina', 'adenocor', 'adenosine',
      'atropina', 'atropine',
      'amiodarona', 'cordarone', 'amiodarone',
      'lidocaina', 'xilocaina', 'lidocaine', 'xylocaine',
      'sotalol', 'betapace',
      'propafenona', 'rythmol', 'propafenone',
      'flecainida', 'tambocor', 'flecainide',
      'quinidina', 'quinaglute', 'quinidine',
      'procainamida', 'procan', 'procainamide',
      'digoxina', 'lanoxin', 'digoxin',
      'atenolol', 'tenormin',
      'metoprolol', 'seloken', 'lopressor',
      'carvedilol', 'coreg',
      'bisoprolol', 'concor',
      'esmolol', 'brevibloc',
      'labetalol', 'trandate', 'normodyne',
      'propranolol', 'inderal',
      'nebivolol', 'bystolic',
      'enalapril', 'vasotec', 'renitec',
      'captopril', 'capoten',
      'lisinopril', 'zestril', 'prinivil',
      'ramipril', 'altace', 'triatec',
      'perindopril', 'coversyl',
      'losartana', 'losartan', 'cozaar',
      'valsartana', 'valsartan', 'diovan',
      'candesartana', 'candesartan', 'atacand',
      'irbesartana', 'irbesartan', 'avapro',
      'telmisartana', 'telmisartan', 'micardis',
      'olmesartana', 'olmesartan', 'benicar',
      'amlodipina', 'amlodipine', 'norvasc',
      'nifedipina', 'nifedipine', 'adalat',
      'verapamil', 'calan', 'isoptin',
      'diltiazem', 'cardizem', 'tiazac',
      'felodipina', 'felodipine', 'plendil',
      'nimodipino', 'nimotop', 'nimodipine',
      'hidralazina', 'hydralazine', 'apresoline',
      'minoxidil', 'loniten',
      'clonidina', 'catapres', 'clonidine',
      'doxazosina', 'cardura', 'doxazosin',
      'terazosina', 'terazosin', 'hytrin',
      'prazosina', 'minipress', 'prazosin',
      'espironolactona', 'aldactone', 'spironolactone',
      'furosemida', 'lasix', 'furosemide',
      'hidroclorotiazida', 'hypothiazid', 'hydrochlorothiazide',
      'torasemida', 'torsemide', 'demadex',
      'bumetanida', 'bumetanide', 'bumex',
      'acetazolamida', 'diamox', 'acetazolamide',
      'eplerenona', 'inspra', 'eplerenone',
      'trandolapril', 'mavik',
      'fosinopril', 'monopril',
      'ciprofibrato', 'ciprofibrate', 'modalim', 'lipanor',
      'dalteparina', 'dalteparin', 'fragmin',
      'dipiridamol', 'dipyridamole', 'persantine',
      'ibutilida', 'ibutilide', 'corvert',
      'sacubitril', 'entresto', 'valsartana-sacubitril',
      'ivabradina', 'procoralan', 'ivabradine',
      'ranolazina', 'ranexa', 'ranolazine',
      'estatina', 'sinvastatina', 'atorvastatina', 'rosuvastatina',
      'sinvastatin', 'simvastatin', 'zocor',
      'atorvastatin', 'atorvastatina', 'lipitor',
      'rosuvastatina', 'rosuvastatin', 'crestor',
      'pravastatina', 'pravastatin', 'pravachol',
      'fluvastatina', 'fluvastatin', 'lescol',
      'ezetimiba', 'ezetimibe', 'zetia',
      'colchicina', 'colchicine', 'colbenemid',
      // ── ANESTÉSICOS / BLOQUEADORES NEUROMUSCULARES ──────────────────────────
      'sugamadex', 'bridion',
      'atracurio', 'atracurium', 'tracrium',
      'pancuronio', 'pancuronium', 'pavulon',
      'cisatracurio', 'cisatracurium', 'nimbex',
      'tiopental', 'thiopental', 'pentothal',
      'halotano', 'halothane', 'fluothane',
      'sevoflurano', 'sevoflurane',
      'isoflurano', 'isoflurane', 'forane',
      'bupivacaina', 'bupivacaine', 'marcaine',
      'ropivacaina', 'ropivacaine', 'naropin',
      'prilocaina', 'prilocaine', 'citanest',
      // ── ANTIBIÓTICOS ─────────────────────────────────────────────────────────
      'amoxicilina', 'amoxil', 'amoxicillin',
      'ampicilina', 'ampicillin', 'principen',
      'amoxicilina-clavulanato', 'augmentin', 'clavulin',
      'penicilina', 'penicillin',
      'oxacilina', 'oxacillin',
      'nafcilina', 'nafcillin',
      'piperacilina-tazobactam', 'tazocin', 'zosyn',
      'cefazolina', 'cefazolin', 'ancef',
      'cefalexina', 'cephalexin', 'keflex',
      'cefuroxima', 'cefuroxime', 'zinnat',
      'cefoxitina', 'cefoxitin', 'mefoxin',
      'ceftriaxona', 'ceftriaxone', 'rocephin',
      'cefotaxima', 'cefotaxime', 'claforan',
      'ceftazidima', 'ceftazidime', 'fortaz',
      'cefepima', 'cefepime', 'maxipime',
      'ceftarolina', 'ceftaroline', 'teflaro',
      'imipenem', 'tienam',
      'meropenem', 'merrem',
      'ertapenem', 'invanz',
      'doripenem', 'doribax',
      'aztreonam', 'azactam',
      'vancomicina', 'vancomycin', 'vancocin',
      'linezolida', 'linezolid', 'zyvox',
      'daptomicina', 'daptomycin', 'cubicin',
      'teicoplanina', 'targocid', 'teicoplanin',
      'ceftolozana-tazobactam', 'zerbaxa',
      'ceftazidima-avibactam', 'avycaz',
      'imipenem-relebactam', 'recarbrio',
      'ciprofloxacino', 'ciprofloxacin', 'cipro',
      'levofloxacino', 'levofloxacin', 'levaquin',
      'moxifloxacino', 'moxifloxacin', 'avelox',
      'metronidazol', 'metronidazole', 'flagyl',
      'clindamicina', 'clindamycin', 'cleocin',
      'eritromicina', 'erythromycin',
      'estreptomicina', 'streptomycin',
      'minociclina', 'minocycline', 'minocin',
      'azitromicina', 'azithromycin', 'zithromax',
      'claritromicina', 'clarithromycin', 'biaxin',
      'doxiciclina', 'doxycycline', 'vibramycin',
      'tetraciclina', 'tetracycline',
      'cotrimoxazol', 'sulfametoxazol-trimetoprim', 'bactrim', 'septra',
      'nitrofurantoina', 'nitrofurantoin', 'macrobid',
      'fosfomicina', 'fosfomycin', 'monurol',
      'rifampicina', 'rifampin', 'rifadin',
      'isoniazida', 'isoniazid', 'inh ',
      'pirazinamida', 'pyrazinamide',
      'etambutol', 'myambutol',
      'gentamicina', 'gentamycin', 'garamycin',
      'amicacina', 'amikacin',
      'tobramicina', 'tobramycin',
      'colistina', 'colistin', 'polimixina',
      'fidaxomicina', 'fidaxomicin', 'dificid',
      'cloranfenicol', 'chloramphenicol',
      'lincomicina', 'lincomycin',
      'quinupristina-dalfopristina', 'synercid',
      'tedizolida', 'tedizolid', 'sivextro',
      'oritavancina', 'oritavancin', 'orbactiv',
      'dalbavancina', 'dalvance',
      // ── ANTIVIRAIS ───────────────────────────────────────────────────────────
      'aciclovir', 'acyclovir', 'zovirax',
      'valaciclovir', 'valacyclovir', 'valtrex',
      'fanciclovir', 'famciclovir', 'famvir',
      'ganciclovir', 'cytovene',
      'valganciclovir', 'valcyte',
      'foscarnet', 'foscavir',
      'oseltamivir', 'tamiflu',
      'zanamivir', 'relenza',
      'baloxavir', 'xofluza',
      'remdesivir', 'veklury',
      'nirmatrelvir', 'paxlovid',
      'molnupiravir', 'lagevrio',
      'ribavirina', 'ribavirin', 'rebetol',
      'sofosbuvir', 'sovaldi',
      'daclatasvir', 'daklinza',
      'entecavir', 'baraclude',
      'tenofovir', 'viread',
      'lamivudina', 'lamivudine', '3tc', 'epivir',
      'efavirenz', 'sustiva',
      'dolutegravir', 'tivicay',
      'atazanavir', 'reyataz',
      'lopinavir', 'kaletra',
      'tecovirimat', 'tpoxx',
      // ── ANTIFÚNGICOS ─────────────────────────────────────────────────────────
      'fluconazol', 'fluconazole', 'diflucan',
      'itraconazol', 'itraconazole', 'sporanox',
      'voriconazol', 'voriconazole', 'vfend',
      'posaconazol', 'posaconazole', 'noxafil',
      'isavuconazol', 'isavuconazole', 'cresemba',
      'caspofungina', 'caspofungin', 'cancidas',
      'micafungina', 'micafungin', 'mycamine',
      'anidulafungina', 'anidulafungin', 'eraxis',
      'anfotericina b', 'amphotericin b', 'fungizone',
      'terbinafina', 'terbinafine', 'lamisil',
      // ── ANTIPARASITÁRIOS ─────────────────────────────────────────────────────
      'metronidazol', 'metronidazole',
      'albendazol', 'albendazole', 'zentel',
      'mebendazol', 'mebendazole', 'vermox',
      'nitazoxanida', 'nitazoxanide', 'alinia',
      'ivermectina', 'ivermectin', 'stromectol',
      'praziquantel', 'biltricide',
      'cloroquina', 'chloroquine', 'aralen',
      'hidroxicloroquina', 'hydroxychloroquine', 'plaquenil',
      'artemeter', 'artemether',
      'quinina', 'quinine',
      'primaquina', 'primaquine',
      'pirimetamina', 'pyrimethamine', 'daraprim',
      // ── ANTIPARKINSONIANOS ─────────────────────────────────────────────────
      'levodopa', 'carbidopa', 'levodopa-carbidopa', 'sinemet',
      'pramipexol', 'mirapex', 'pramipexole',
      'ropinirol', 'requip', 'ropinirole',
      'rotigotina', 'neupro', 'rotigotine',
      'rasagilina', 'azilect', 'rasagiline',
      'selegilina', 'eldepryl',
      'entacapona', 'comtan', 'entacapone',
      'tolcapona', 'tasmar', 'tolcapone',
      'amantadina', 'symmetrel', 'amantadine',
      'benztropina', 'cogentin', 'benztropine',
      'biperideno', 'akineton', 'biperiden',
      // ── COLINESTERÁSICOS E ANTIDEMÊNCIA ─────────────────────────────────────
      'donepezila', 'donepezil', 'aricept',
      'rivastigmina', 'rivastigmine', 'exelon',
      'galantamina', 'galantamine', 'reminyl',
      'memantina', 'memantine', 'namenda',
      // ── PSICOESTIMULANTES E TDAH ─────────────────────────────────────────────
      'metilfenidato', 'methylphenidate', 'ritalin', 'concerta',
      'anfetamina', 'amphetamine', 'adderall',
      'lisdexanfetamina', 'lisdexamfetamine', 'vyvanse',
      'atomoxetina', 'atomoxetine', 'strattera',
      'modafinil', 'provigil',
      'armodafinil', 'nuvigil',
      // ── CORTICOSTEROIDES ─────────────────────────────────────────────────────
      'dexametasona', 'dexamethasone', 'decadron',
      'prednisona', 'prednisone', 'deltasone',
      'prednisolona', 'prednisolone',
      'metilprednisolona', 'methylprednisolone', 'solu-medrol',
      'hidrocortisona', 'hydrocortisone', 'solu-cortef',
      'betametasona', 'betamethasone', 'celestone',
      'fludrocortisona', 'florinef', 'fludrocortisone',
      'budesonida', 'budesonide', 'pulmicort',
      'fluticasona', 'fluticasone', 'flixotide',
      'beclometasona', 'beclomethasone',
      // ── ANTIDIABÉTICOS ───────────────────────────────────────────────────────
      'metformina', 'glucophage', 'metformin',
      'insulina', 'insulin',
      'glibenclamida', 'glyburide', 'micronase',
      'glipizida', 'glipizide', 'glucotrol',
      'glicazida', 'gliclazide', 'diamicron',
      'sitagliptina', 'sitagliptin', 'januvia',
      'vildagliptina', 'vildagliptin', 'galvus',
      'saxagliptina', 'saxagliptin', 'onglyza',
      'linagliptina', 'linagliptin', 'tradjenta',
      'empagliflozina', 'empagliflozin', 'jardiance',
      'dapagliflozina', 'dapagliflozin', 'forxiga',
      'canagliflozina', 'canagliflozin', 'invokana',
      'liraglutida', 'liraglutide', 'victoza',
      'semaglutida', 'semaglutide', 'ozempic', 'wegovy',
      'exenatida', 'exenatide', 'byetta',
      'dulaglutida', 'dulaglutide', 'trulicity',
      'pioglitazona', 'pioglitazone', 'actos',
      'acarbose', 'acarbosa', 'glucobay',
      'degludeca', 'degludec', 'tresiba', 'insulina degludeca',
      // ── BRONCODILATADORES E RESPIRATÓRIO ─────────────────────────────────────
      'salbutamol', 'albuterol', 'ventolin',
      'ipratropio', 'ipratropium', 'atrovent',
      'tiotropio', 'tiotropium', 'spiriva',
      'formoterol', 'foradil',
      'salmeterol', 'serevent',
      'indacaterol', 'onbrez',
      'glicopirronio', 'glycopyrronium', 'seebri',
      'montelucaste', 'montelukast', 'singulair',
      'teofilina', 'theophylline',
      'budesonida', 'budesonide',
      'fluticasona', 'fluticasone',
      'roflumilaste', 'roflumilast', 'daliresp',
      'ivacaftor', 'kalydeco',
      'dornase alfa', 'pulmozyme',
      // ── INIBIDORES BOMBA DE PRÓTONS E GI ────────────────────────────────────
      'omeprazol', 'prilosec', 'omeprazole',
      'pantoprazol', 'protonix', 'pantoprazole',
      'esomeprazol', 'nexium', 'esomeprazole',
      'lansoprazol', 'prevacid', 'lansoprazole',
      'dexlansoprazol', 'dexlansoprazole', 'dexilant',
      'rabeprazol', 'aciphex', 'rabeprazole',
      'ranitidina', 'zantac', 'ranitidine',
      'famotidina', 'pepcid', 'famotidine',
      'metoclopramida', 'reglan', 'metoclopramide',
      'domperidona', 'motilium', 'domperidone',
      'ondansetrona', 'zofran', 'ondansetron',
      'granisetrona', 'kytril', 'granisetron',
      'aprepitant', 'emend',
      'loperamida', 'imodium', 'loperamide',
      'mesalazina', 'asacol', 'mesalamine',
      'sulfassalazina', 'azulfidine', 'sulfasalazine',
      'infliximabe', 'infliximab', 'remicade',
      'adalimumabe', 'adalimumab', 'humira',
      'vedolizumabe', 'vedolizumab', 'entyvio',
      'ustekinumabe', 'ustekinumab', 'stelara',
      'sucralfato', 'sucralfate', 'carafate',
      'bismuto', 'bismuth',
      'lactulose', 'kristalose',
      'rifaximina', 'xifaxan', 'rifaximin',
      // ── HORMÔNIOS TIREOIDIANOS ───────────────────────────────────────────────
      'levotiroxina', 'synthroid', 'levothyroxine',
      'metimazol', 'methimazole', 'tapazole',
      'propiltiouracil', 'ptu ', 'propylthiouracil',
      'tiamazol', 'carbimazole',
      // ── DIURÉTICOS ───────────────────────────────────────────────────────────
      'furosemida', 'furosemide',
      'espironolactona', 'spironolactone',
      'torasemida', 'torsemide',
      'hidroclorotiazida', 'hydrochlorothiazide',
      'clortalidona', 'chlorthalidone',
      'indapamida', 'indapamide',
      'acetazolamida', 'acetazolamide',
      'amilorida', 'amiloride',
      'triantereno', 'triamterene',
      'tolvaptan', 'samsca',
      'manitol', 'mannitol',
      // ── IMUNOSSUPRESSORES E BIOLÓGICOS ───────────────────────────────────────
      'metotrexato', 'methotrexate',
      'azatioprina', 'azathioprine', 'imuran',
      'ciclosporina', 'cyclosporine', 'sandimmune',
      'tacrolimus', 'prograf',
      'micofenolato', 'mycophenolate', 'cellcept',
      'rituximabe', 'rituximab', 'mabthera',
      'tocilizumabe', 'tocilizumab', 'actemra',
      'abatacepte', 'abatacept', 'orencia',
      'secuquinumabe', 'secukinumab', 'cosentyx',
      'ixequizumabe', 'ixekizumab', 'taltz',
      'dupilumabe', 'dupilumab', 'dupixent',
      'omalizumabe', 'omalizumab', 'xolair',
      'pembrolizumabe', 'pembrolizumab', 'keytruda',
      'nivolumabe', 'nivolumab', 'opdivo',
      'ipilimumabe', 'ipilimumab', 'yervoy',
      'bortezomibe', 'bortezomib', 'velcade',
      'lenalidomida', 'lenalidomide', 'revlimid',
      'talidomida', 'thalidomide', 'thalomid',
      // ── ANTIINFLAMATÓRIOS ─────────────────────────────────────────────────
      'ibuprofeno', 'ibuprofen', 'advil', 'motrin',
      'naproxeno', 'naproxen', 'aleve',
      'diclofenaco', 'diclofenac', 'voltaren',
      'indometacina', 'indomethacin', 'indocin',
      'cetorolaco', 'ketorolac', 'toradol',
      'meloxicam', 'meloxicame', 'mobic',
      'celecoxibe', 'celecoxib', 'celebrex',
      'etoricoxibe', 'etoricoxib', 'arcoxia',
      'paracetamol', 'acetaminophen', 'tylenol',
      'dipirona', 'novalgina', 'metamizol',
      // ── BIFOSFONATOS E OSSO ──────────────────────────────────────────────────
      'alendronato', 'fosamax', 'alendronate',
      'risedronato', 'actonel', 'risedronate',
      'zoledronato', 'zometa', 'zoledronate',
      'ibandronato', 'boniva', 'ibandronate',
      'denosumab', 'prolia', 'xgeva',
      'teriparatida', 'forteo', 'teriparatide',
      'calcio', 'calcium',
      'vitamina d', 'calcitriol', 'colecalciferol',
      // ── ANTINEOPLÁSICOS PRINCIPAIS ─────────────────────────────────────────
      'imatinibe', 'imatinib', 'gleevec',
      'dasatinibe', 'dasatinib', 'sprycel',
      'erlotinib', 'erlotinibe', 'tarceva',
      'gefitinibe', 'gefitinib', 'iressa',
      'osimertinibe', 'osimertinib', 'tagrisso',
      'vemurafenib', 'vemurafenibe', 'zelboraf',
      'tamoxifeno', 'tamoxifen', 'nolvadex',
      'letrozol', 'letrozole', 'femara',
      'anastrozol', 'anastrozole', 'arimidex',
      'trastuzumabe', 'trastuzumab', 'herceptin',
      'cisplatina', 'cisplatin', 'platinol',
      'carboplatina', 'carboplatin', 'paraplatin',
      'doxorrubicina', 'doxorubicin', 'adriamycin',
      'paclitaxel', 'taxol',
      'docetaxel', 'taxotere',
      'vincristina', 'vincristine', 'oncovin',
      '5-fluorouracil', 'fluorouracil', '5fu',
      'oxaliplatina', 'oxaliplatin', 'eloxatin',
      'irinotecan', 'irinotecan', 'camptosar',
      'gemcitabina', 'gemcitabine', 'gemzar',
      'metotrexato', 'methotrexate',
      'hidroxiureia', 'hydroxyurea', 'hydrea',
      // ── MISCELÂNEA FARMACOLÓGICA ──────────────────────────────────────────
      'acido tranexamico', 'acido tranexam', 'tranexamic',
      'vitamina k', 'fitomenadiona', 'phytonadione',
      'n-acetilcisteina', 'nac ', 'acetylcysteine',
      'albumina', 'albumin',
      'gluconato calcio', 'calcium gluconate',
      'sulfato magnesio', 'magnesium sulfate',
      'bicarbonato sodio', 'sodium bicarbonate',
      'desmopressina', 'ddavp', 'desmopressin',
      'ocitocina', 'oxytocin', 'pitocin',
      'misoprostol', 'cytotec',
      'ergometrina', 'ergometrine', 'syntometrine',
      'tiamina', 'thiamine', 'vitamina b1',
      'piridoxina', 'pyridoxine', 'vitamina b6',
      'cianocobalamina', 'cobalamina', 'vitamina b12',
      'acido folico', 'folic acid',
      'sulfato ferroso', 'ferrous sulfate', 'ferro oral',
      'eritropoetina', 'epoetin', 'epo ',
      'filgrastim', 'neupogen',
      'imunoglobulina', 'immunoglobulin', 'ivig',
      'carvao ativado', 'activated charcoal',
      'glucagon',
      'octreotida', 'octreotide', 'sandostatin',
      'vasopresina', 'terlipressina',
      'colchicina', 'colchicine',
      'alopurinol', 'allopurinol', 'zyloprim',
      'febuxostat', 'febuxostato', 'uloric',
      'sildenafil', 'viagra', 'revatio',
      'tadalafil', 'cialis', 'adcirca',
      'vardenafil', 'levitra',
      'cabergolina', 'dostinex', 'cabergoline',
      'levonorgestrel', 'mirena',
      'desmopressina', 'ddavp', 'desmopressin',
      'bromocriptina', 'bromocriptine', 'parlodel',
      'leuprorelin', 'lupron',
      'naloxona', 'naltrexona', 'narcan',
      'flumazenil', 'romazicon',
    ]);
    if (hasDrugKeyword) return true;

    // Termos de psicose/brote psicótico → sempre query direta
    final hasPsychKeyword = _has(_normalize(input), [
      'antipsicotico', 'antipsicótico', 'antipsychotic',
      'psicotic', 'psicotico', 'psicótico', 'psicosis', 'psicose',
      'brote psic', 'brote maniac', 'episodio maniac', 'episodio psicotico',
      'esquizofrenia', 'schizophrenia', 'delirio ', 'alucinac',
      'delirium ', 'agitacion psic', 'agitação psic',
    ]);
    if (hasPsychKeyword) return true;

    final hasClinicalKeywords = _has(_normalize(input), [
      'paciente', 'dor', 'febre', 'dispne', 'tontura', 'choque',
      'pa ', 'fc ', 'spo2', 'glasgow', 'ecg', 'tomograf',
    ]);

    // ── Palavras-chave que indicam FOLLOW-UP — nunca tratar como query direta ──
    // Estas frases curtas precisam do contexto anterior para fazer sentido.
    // Ex: "Tratamiento farmacologico", "qual a dose", "exames", "conduta"
    final hasFollowUpKeyword = _has(_normalize(input), [
      // Tratamento / conduta
      'tratamiento', 'tratamento', 'tratament',
      'farmacolog', 'farmacol',
      'conduta', 'conducta',
      'medicamento', 'medicacion', 'medicação',
      'prescr', 'prescri',
      'terapia', 'terapeutica', 'terapêutica',
      // Diagnóstico / exames
      'diagnostico', 'diagnóstico', 'diagnos',
      'exame', 'examen', 'laborator', 'exam',
      'imagem', 'imagen', 'tomografi', 'radiograf',
      // Dose / ajuste
      'dose', 'dosis', 'dosagem', 'posologia',
      'ajuste', 'ajust',
      // Evolução / seguimento
      'seguimento', 'seguimiento', 'seguim',
      'evolucao', 'evolución', 'evolução', 'evoluc',
      'prognos', 'prognostico', 'pronóstico',
      // Cirurgia / procedimento
      'cirurgia', 'cirugia', 'cirurg',
      'procedimento', 'procedimiento',
      'internacao', 'internación', 'internação', 'intern',
      // Perguntas de contexto curto
      'mais informacoes', 'mas informacion', 'mais info',
      'aprofund', 'aprofundar', 'detalhe', 'detalle', 'detail',
      'como tratar', 'cómo tratar', 'como tratar',
      'qual a conduta', 'cual la conducta',
      'como manejo', 'como manejo',
    ]);
    // Se é uma frase curta que parece follow-up → forçar expansão com histórico
    if (hasFollowUpKeyword && input.trim().split(' ').length <= 6) return false;

    final isShortConceptual = input.trim().split(' ').length <= 6 && !hasClinicalKeywords;
    return isShortConceptual;
  }

  /// Constrói query expandida com contexto do histórico (últimas N msgs do usuário)
  /// Só expande se a pergunta for um follow-up clínico — nunca contamina queries novas
  String _expandedQuery(String currentInput, {int lastN = 3}) {
    // Perguntas diretas/novas: NÃO misturar histórico (evita resposta aleatória)
    if (_isDirectQuery(currentInput)) return currentInput.trim();

    // Follow-up clínico: expande com contexto recente
    final recentUserMsgs = _aiHistory
        .where((m) => m['role'] == 'user')
        .map((m) => m['content'] ?? '')
        .toList();
    // Pega só as últimas N mensagens do usuário
    final tail = recentUserMsgs.length > lastN
        ? recentUserMsgs.sublist(recentUserMsgs.length - lastN)
        : recentUserMsgs;

    // Só inclui histórico se a pergunta for realmente um follow-up
    // (muito curta e sem contexto próprio — ex: "qual a dose?", "tem FA?")
    // Threshold: 6 palavras (cobre "Tratamiento farmacologico", "qual a conduta", etc.)
    final isFollowUp = currentInput.trim().split(' ').length <= 6;
    if (!isFollowUp) return currentInput.trim();

    return '${tail.join(' ')} $currentInput'.trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD AI ANSWER — Pipeline RAG Clínico
  //
  // Pipeline:
  //   1. Classificar intent (tipo de consulta)
  //   2. Expandir query com histórico relevante
  //   3. Retrieval local: matchProtocols + matchDrugs
  //   4. Análise local (fallback e contexto estruturado)
  //   5. Montar system prompt RAG com todos os contextos
  //   6. Chamar Gemini (com Google Search Grounding) ou OpenAI
  //   7. Salvar no histórico e retornar
  // ══════════════════════════════════════════════════════════════════════════
  // Guard de concorrência: impede que chamadas simultâneas (Enter + botão) dupliquem resposta.
  bool _aiAnswerInProgress = false;

  // ══════════════════════════════════════════════════════════════════════════
  // Build 134 — Single-Flight Guard
  //
  // Protege contra rafagas de envio (spam Enter, duplo-tap, network retry)
  // que causariam múltiplos SSE concorrentes para a Gemini API.
  //
  // DIFERENÇA vs _aiAnswerInProgress:
  //   _aiAnswerInProgress: guard legado para o pipeline buildAIAnswer() síncrono.
  //   _aiCallInFlight: guard de voo único para sendAiMessage() — cobre toda a
  //     janela desde o primeiro byte enviado até o finally ter executado,
  //     inclusive timeouts e erros de rede. Liberação GARANTIDA pelo finally.
  //
  // LIBERAÇÃO: sempre no bloco finally de sendAiMessage(), independente de
  //   - conclusão normal do stream
  //   - erro de rede ou timeout
  //   - cancelamento manual pelo usuário
  //   - exceção não capturada interna
  //
  // EFEITO: segunda chamada durante voo ativo → retorna false silenciosamente.
  //   A UI interpreta false como "ignorado" e não exibe spinner duplicado.
  // ══════════════════════════════════════════════════════════════════════════
  bool _aiCallInFlight = false;

  // ══════════════════════════════════════════════════════════════════════════
  // STREAMING V2 — sendAiMessage
  //
  // Substitui buildAIAnswer() quando o Gemini estiver conectado.
  // Em vez de retornar uma String única, emite chunks via callback [onChunk]
  // e sinaliza conclusão via [onDone] / erro via [onError].
  //
  // A UI (ai_screen.dart) chama este método, recebe os callbacks e atualiza
  // a bolha de mensagem em tempo real — sem esperar a resposta completa.
  //
  // FALLBACK: se Gemini não estiver conectado, delega ao buildAIAnswer() legado.
  // ══════════════════════════════════════════════════════════════════════════

  /// Indica se há streaming ativo no momento.
  /// BUILD 326: getter legado mantido — usa _aiStreamActive diretamente.
  /// Novo código deve preferir context.select<AiChatProvider, bool>(p => p.aiStreaming).
  // (getter aiStreaming já declarado nos Getters públicos acima — não duplicar)
  bool _aiStreamActive = false;

  // ── BUILD 462E-A: QA Force-GPT flag ───────────────────────────────────────
  // true  → sendAiMessage() pula Layer 0 (Gemini Free) e abre SSE GPT direto.
  //          BLOQUEADO em produção (alterar para false antes de release).
  // false → fluxo normal (Gemini Free → GPT fallback → Gemini Paid).
  //
  // Ativa exclusivamente para validação E2E do barramento AiEvent.
  static const bool kForceGptFallbackForQa = true;

  // ── BUILD 462E-A.3: Crypto-isolated QA tester UID allowlist ───────────────
  // UIDs explicitamente autorizados a usar o bypass GPT SSE.
  // NUNCA expande em produção — apenas para QA controlado.
  static const Set<String> qaTesterUids = {
    'Wa1AQN8hvCdewLiR2drd01rQo9G3',
  };

  // ── BUILD 462E-A.3: Computed gate — identity-isolated QA bypass ──────────
  //
  // Avalia 3 condições em sequência:
  //   1. kForceGptFallbackForQa deve ser true (master feature flag).
  //   2. FirebaseAuth.instance.currentUser deve ter UID válido (não-nulo/vazio).
  //   3. UID deve estar no allowlist OU usuário deve ter isAdmin/isMaster=true.
  //
  // PROIBIÇÕES:
  //   • Nunca confiar em UID de local storage, query string ou _currentUser
  //     interno — apenas FirebaseAuth.instance.currentUser é aceito.
  //   • Não retornar true para estado não-autenticado mesmo com cache local.
  //
  // Telemetria anonimizada ([AI_QA_GATE]) emitida aqui — 3 branches:
  //   authorized_tester    → uidHash exibido (primeiros 4 chars apenas)
  //   unauthorized_user    → uid não está no allowlist e não tem role
  //   firebase_user_null   → FirebaseAuth.currentUser == null
  // ─────────────────────────────────────────────────────────────────────────
  //
  // evaluateQaGate() — pure static function, fully unit-testable.
  //
  // Aceita os 3 parâmetros de entrada de forma isolada — sem dependência em
  // singletons Firebase, sem I/O — permitindo cobertura de todos os 3 branches
  // em test/services/qa_access_gate_test.dart sem mock de plugin.
  //
  // Returns: enum [_QaGateResult] com o resultado do gate e o motivo.
  //          O getter shouldForceGptFallbackForQa chama este método internamente.
  // ─────────────────────────────────────────────────────────────────────────
  static _QaGateResult evaluateQaGate({
    required bool featureEnabled,
    required String? authenticatedUid,
    required bool isAdminUser,
    required bool isMasterUser,
  }) {
    if (!featureEnabled) return _QaGateResult.featureDisabled;
    if (authenticatedUid == null || authenticatedUid.isEmpty) {
      return _QaGateResult.firebaseUserNull;
    }
    final bool authorized = isAdminUser ||
        isMasterUser ||
        qaTesterUids.contains(authenticatedUid);
    return authorized
        ? _QaGateResult.authorizedTester
        : _QaGateResult.unauthorizedUser;
  }

  bool get shouldForceGptFallbackForQa {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final authenticatedUid = firebaseUser?.uid;

    final result = evaluateQaGate(
      featureEnabled: kForceGptFallbackForQa,
      authenticatedUid: authenticatedUid,
      isAdminUser: isAdmin,
      isMasterUser: isMaster,
    );

    switch (result) {
      case _QaGateResult.featureDisabled:
        return false;
      case _QaGateResult.firebaseUserNull:
        // ignore: avoid_print
        print('[AI_QA_GATE] enabled=true authorized=false reason=firebase_user_null');
        return false;
      case _QaGateResult.authorizedTester:
        // ignore: avoid_print
        print('[AI_QA_GATE] enabled=true authorized=true reason=tester_uid '
            'uidHash=${authenticatedUid!.substring(0, 4)}...');
        return true;
      case _QaGateResult.unauthorizedUser:
        // ignore: avoid_print
        print('[AI_QA_GATE] enabled=true authorized=false reason=unauthorized_user');
        return false;
    }
  }

  /// StreamSubscription AiEvent para o fluxo GPT SSE (BUILD 462E-A).
  StreamSubscription<AiEvent>? _gptStreamSub;

  /// Cliente SSE ativo — permite cancelamento com AbortController upstream.
  GptSseClient? _activeGptClient;

  /// Cancela o streaming em curso (usuário trocou de tela, limpou chat, etc.)
  StreamSubscription<GeminiChunk>? _aiStreamSub;

  void cancelAiStream() {
    // BUILD 462E-A: cancela também o stream GPT SSE se estiver ativo
    final wasGptActive = _gptStreamSub != null;
    if (wasGptActive) {
      // ignore: avoid_print
      print('[AI_E2E][CANCELLED] requestId=$_activeRequestId '
          'reason=user_cancelled_clear provider=gpt_4o_mini');
    }
    _gptStreamSub?.cancel();
    _gptStreamSub = null;
    _activeGptClient?.cancel(reason: 'user_cancelled_clear');
    _activeGptClient = null;
    _aiStreamSub?.cancel();
    _aiStreamSub = null;
    // Build 107 FIX: reseta _aiAnswerInProgress também — sem isso, sendAiMessage()
    // retorna false imediatamente ao testar o guard na linha inicial, bloqueando
    // qualquer nova mensagem enviada após clearChat/restoreSession.
    final wasActive = _aiStreamActive || _aiAnswerInProgress;
    _aiStreamActive      = false;
    _aiAnswerInProgress  = false;
    // Build 134: Single-Flight Guard — também libera _aiCallInFlight no cancelamento.
    // Garante que cancelamento manual (clearChat, troca de tela, timeout da UI)
    // não deixe o guard travado, impedindo novas queries na mesma sessão.
    _aiCallInFlight = false;
    // BUILD 326: sincroniza AiChatProvider.
    if (wasActive) aiChatProvider.setStreaming(false);
    if (wasActive) notifyListeners();
  }

  /// Envia mensagem com streaming token-a-token via GeminiServiceV2.
  ///
  /// Parâmetros de callback (todos opcionais mas úteis):
  ///   [onChunk]  — chamado a cada token recebido; recebe o texto ACUMULADO até agora
  ///   [onDone]   — chamado quando a resposta está completa; recebe o texto final
  ///   [onError]  — chamado em caso de falha; recebe mensagem de erro amigável
  ///
  /// Retorna true se usou streaming V2, false se delegou ao fallback legado.
  // BUILD 238 ADENDO: requestId ativo — invalida respostas atrasadas
  String _activeRequestId = '';

  // Safe-card de timeout (sem EvidenceBox, sem ActionButtons, sem ExternalToolLink)
  //
  // BUILD 244: prefixo canônico estável — ai_screen detecta via _kSafeCardMarker.
  // NÃO alterar estas primeiras linhas sem atualizar _kSafeCardMarker em ai_screen.
  // BUILD 244: public — ai_screen reads these to detect safe-card by canonical prefix
  static const String kSafeCardMarkerPt = '🟥 TEMPO LIMITE ATINGIDO';
  static const String kSafeCardMarkerEs = '🟥 TEMPO LÍMITE ALCANZADO';

  String _timeoutSafeCard(String lang) {
    if (lang == 'es') {
      return '$kSafeCardMarkerEs\n'
          '⚠️ No pude completar la respuesta con seguridad dentro del tiempo límite.\n'
          '📌 Reformule con diagnóstico, signos vitales o estudios clave.';
    }
    return '$kSafeCardMarkerPt\n'
        '⚠️ Não consegui concluir a resposta com segurança dentro do tempo limite.\n'
        '📌 Reformule com diagnóstico, sinais vitais ou exames principais.';
  }

  Future<bool> sendAiMessage(
    String input, {
    required void Function(String accumulated) onChunk,
    required void Function(String finalText) onDone,
    required void Function(String errorMsg) onError,
    bool longResponse = false,  // Motor de Partida (Build 149)
    bool fromButton  = false,   // BUILD 262: true = Quick Action button tap (follow-up clinical turn)
  }) async {
    // ── ADENDO SEGURANÇA Factor 3: SEGUNDA BARREIRA NO PROVIDER (backend guard) ─
    // Verificação redundante e síncrona ANTES de qualquer operação assíncrona.
    // Bloqueia chamadas que escaparam da UI (teclado físico, chip tap, retry,
    // histórico injetado, etc.) sem autenticação real de usuário.
    // Condição idêntica ao Factor 2 em ai_screen.dart → consistência absoluta.
    // _geminiConnected: sessão OAuth Google válida (token real do usuário)
    // _openAiKey:       chave OpenAI pessoal configurada pelo próprio usuário
    // EXCLUÍDO: GeminiService.hasApiKey (chave servidor compartilhada — bypass confirmado)
    final bool hasRealAuth = _geminiConnected || _openAiKey.isNotEmpty;
    if (!hasRealAuth) {
      debugPrint('[BACKEND_GUARD_FACTOR3] Tentativa de envio sem auth real bloqueada. '
          'geminiConnected=$_geminiConnected openAiKey=${_openAiKey.isNotEmpty} '
          'input="${input.substring(0, input.length.clamp(0, 40))}..." → return false');
      // Notifica a UI com código de erro específico para tratamento correto
      onError('AUTH_REQUIRED');
      return false; // ← BARREIRA ABSOLUTA no provider — zero bytes ao backend
    }

    // ── Build 134: Single-Flight Guard ────────────────────────────────────
    // Bloqueia qualquer chamada enquanto um voo já está em curso.
    // Liberação garantida pelo bloco finally abaixo — cobre todos os caminhos:
    // stream completo, erro de rede, timeout, cancelamento e exceção interna.
    if (_aiCallInFlight) {
      debugPrint('[sendAiMessage] Build 134: single-flight drop — voo em andamento');
      return false;
    }
    _aiCallInFlight = true;

    // ── BUILD 238 ADENDO: requestId único por pergunta ────────────────────
    // Permite invalidar respostas atrasadas (stale) após timeout global.
    final thisRequestId = ProviderRouterService.generateRequestId();
    _activeRequestId = thisRequestId;
    final globalStartMs = DateTime.now().millisecondsSinceEpoch;
    if (kDebugMode) debugPrint('[AI_TIMING] requestId=$thisRequestId globalStart=${globalStartMs}ms');

    // BUILD 241: registra request no coordinator para verificação no resume.
    // BUILD 320: passa isEstudoMode para que o coordinator use deadline 90s
    // no Modo Estudo (payload 7000+ tokens) em vez de 30s — evita o falso
    // positivo de timeout que causava a race condition DiagnosticsProperty<void>.
    AppResumeCoordinator.instance.registerAiRequest(
      requestId:    thisRequestId,
      isEstudoMode: longResponse, // BUILD 320: Estudo=90s / Plantão=30s
      onTimeout: () {
        debugPrint('[AI_RESUME][BUILD320] requestId=$thisRequestId '
            'elapsedMs=${DateTime.now().millisecondsSinceEpoch - globalStartMs} '
            'action=timeout_on_resume isEstudoMode=$longResponse');
        // Id Guard: só age se este request ainda é o ativo (não foi completado
        // nem invalidado por um request mais recente do mesmo usuário).
        if (_activeRequestId != thisRequestId) {
          debugPrint('[AI_RESUME][BUILD320] STALE drop: requestId=$thisRequestId '
              'activeId=$_activeRequestId — resume timeout ignored');
          return;
        }
        _activeRequestId = '';
        _aiStreamActive  = false;
        aiChatProvider.setStreaming(false); // BUILD 326.1: resume timeout — UI desbloqueia
        _aiStreamSub?.cancel();
        _aiStreamSub     = null;
        _aiCallInFlight  = false;
        debugPrint('[AI_RESUME][BUILD320] timeout_on_resume fired requestId=$thisRequestId');
        onDone(_timeoutSafeCard(_lang));
        notifyListeners(); // BUILD 254: sincroniza UI após timeout de resume
      },
    );

    try {
    // ── Guard de concorrência (legado — mantido para compatibilidade) ─────
    if (_aiAnswerInProgress || _aiStreamActive) {
      debugPrint('[sendAiMessage] ignorado — resposta em andamento');
      return false;
    }

    // ── MICRO-BUILD 462E-A.5.1: canonicalDecision — SINGLE EXECUTION PER requestId ──
    //
    // Computa a decisão de roteamento de ferramenta externa UMA ÚNICA VEZ
    // por requestId, no ponto de entrada do sendAiMessage(), ANTES de qualquer
    // despacho para os subsistemas downstream (PLANTAO_ANALYSIS, BUILD306,
    // stream handler, etc.).
    //
    // PROIBIÇÃO ABSOLUTA: nenhum subsistema downstream deve chamar
    // resolveExternalToolIntent() ou resolveDecision() independentemente.
    // O canonicalDecision aqui é a ÚNICA fonte de verdade para este ciclo.
    //
    // null → intent == none → embargo total (ferramenta externa não ativada).
    // non-null → intent detectado → authority ladder ativa toRouterTask().
    // ─────────────────────────────────────────────────────────────────────────
    final ExternalToolDecision? canonicalDecision =
        ExternalToolLinkEngine.resolveDecision(thisRequestId, input);
    // ignore: avoid_print
    print('[CANONICAL_DECISION] requestId=$thisRequestId '
        'intent=${canonicalDecision?.intent.name ?? "none"} '
        'routerTask=${canonicalDecision?.toRouterTask() ?? "normalClinicalClassifier"} '
        'source=original_user_input');

    // MICRO-BUILD 462E-A.5.2: function-scope canonical task override.
    // Declared here so ALL downstream paths (QA, free stream, paid fallback,
    // tryPaidFallback) share the same value without re-computing.
    final String _canonicalTaskOverride = (canonicalDecision != null &&
            canonicalDecision.intent != ExternalToolIntent.none)
        ? canonicalDecision.toRouterTask()
        : '';

    // ── BUILD 254 → BUILD 318: wrappers com notifyListeners() ao término ─────
    // wrappedOnDone/wrappedOnError são as ÚNICAS portas de saída do stream.
    // Cada uma: (1) invoca o callback da UI, (2) dispara notifyListeners().
    //
    // BUILD 318 HARDENING — completionFired elevado para os wrappers:
    //   O guard `completionFired` já existia no bloco onData (chunk.isDone),
    //   mas os wrappers em si não tinham proteção. Isso permitia que um segundo
    //   disparo (ex: tryPaidFallback em race condition, ou resume-coordinator
    //   disparando wrappedOnDone após o FREE_STREAM já ter chamado wrappedOnDone)
    //   chegasse ao `onDone` da UI duas vezes — resultando em:
    //     • Bolha AI duplicada (segunda chamada ao setState com o mesmo texto)
    //     • Texto truncado se o segundo call vinha com texto vazio/parcial
    //   Solução: flag `_wrapperFired` local, atômico, fecha a porta após o 1º disparo.
    bool _wrapperFired = false;
    final wrappedOnDone = (String text) {
      if (_wrapperFired) {
        debugPrint('[BUILD318][DEDUP] wrappedOnDone dropped — already fired '
            'requestId=$thisRequestId textLen=${text.length}');
        return;
      }
      _wrapperFired = true;
      onDone(text);
      notifyListeners();
    };
    final wrappedOnError = (String err) {
      if (_wrapperFired) {
        debugPrint('[BUILD318][DEDUP] wrappedOnError dropped — already fired '
            'requestId=$thisRequestId err=$err');
        return;
      }
      _wrapperFired = true;
      onError(err);
      notifyListeners();
    };

    // ══════════════════════════════════════════════════════════════════════════
    // BUILD 462E-A / 462E-A.3 — QA BYPASS: shouldForceGptFallbackForQa
    //
    // BUILD 462E-A.3: kForceGptFallbackForQa (bool estático global) substituído
    // por shouldForceGptFallbackForQa (getter computado) — bypass isolado por
    // identidade Firebase autenticada (UID allowlist + isAdmin/isMaster).
    //
    // Quando shouldForceGptFallbackForQa=true, pula Layer 0 (Gemini Free) inteira e
    // abre fluxo GPT SSE real via ProviderRouterService.callGptProxyStream().
    //
    // PROIBIÇÕES NESTE BLOCO:
    //   • NÃO emitir AiCompleted antes de sanitizeAndCheck()
    //   • NÃO persistir partialText no Firestore ou _aiHistory
    //   • NÃO disparar notifyListeners() amplos — apenas bolha de chat isolada
    //   • NÃO concatenar texto de tentativas diferentes
    //
    // TAGS E2E OBRIGATÓRIAS (visíveis em flutter logs):
    //   [AI_E2E][T0]               → início do ciclo
    //   [AI_E2E][PROVIDER_SWITCH]  → bypass Layer 0, abrindo GPT direto
    //   [AI_E2E][STARTED]          → AiStarted recebido (modelo + provider)
    //   [AI_E2E][T1_FIRST_DELTA]   → primeiro AiTextDelta (prova de streaming)
    //   [AI_E2E][T2_TRANSPORT_DONE]→ AiCompleted recebido do SSE (pré-sanitize)
    //   [AI_E2E][SANITIZED]        → sanitizeAndCheck() executado
    //   [AI_E2E][COMPLETED]        → wrappedOnDone chamado (UI atualizada)
    //   [AI_E2E][CANCELLED]        → cancelamento pelo usuário
    //   [RENDER_AUDIT][HOME_CHAT_BUILD]    → notifyListeners() amplo (deve ser 0)
    //   [RENDER_AUDIT][ACTIVE_BUBBLE_BUILD]→ rebuild da bolha ativa (esperado)
    // ══════════════════════════════════════════════════════════════════════════
    if (shouldForceGptFallbackForQa) {
      // ignore: avoid_print
      print('[AI_E2E][T0] requestId=$thisRequestId attempt=2 '
          'provider=gpt_4o_mini mode=${longResponse ? "estudo" : "plantao"} '
          'shouldForceGptFallbackForQa=true globalStartMs=$globalStartMs');

      // Emitir AiProviderSwitched: Layer 0 bypassada, GPT assume direto
      // ignore: avoid_print
      print('[AI_E2E][PROVIDER_SWITCH] requestId=$thisRequestId '
          'fromProvider=gemini_free toProvider=gpt_4o_mini '
          'reason=shouldForceGptFallbackForQa attempt=2');

      // Obter ID Token para autenticação no gptProxyStream
      // Web: AuthService.getAdminToken() (REST) | Nativo: FirebaseAuth.getIdToken()
      // Tratamento de auth_expired: AiFailed(code:'auth_expired') controlado
      String gptQaToken = '';
      if (kIsWeb) {
        try {
          gptQaToken = await AuthService.getAdminToken();
        } catch (e) {
          debugPrint('[AI_E2E][AUTH_ERROR] requestId=$thisRequestId '
              'error=token_fetch_failed detail=$e');
          wrappedOnError('[auth_expired] Sessão expirada. Faça login novamente.');
          return true;
        }
        if (gptQaToken.isEmpty) {
          debugPrint('[AI_E2E][AUTH_ERROR] requestId=$thisRequestId '
              'error=auth_expired token_empty=true');
          wrappedOnError('[auth_expired] Token vazio. Faça login novamente.');
          return true;
        }
      } else {
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser == null) {
          debugPrint('[AI_E2E][AUTH_ERROR] requestId=$thisRequestId '
              'error=unauthenticated firebaseUser=null');
          wrappedOnError('[auth_expired] Usuário não autenticado.');
          return true;
        }
        try {
          // Force-refresh: garante token fresco, evita 401 por expiração silenciosa
          gptQaToken = await fbUser.getIdToken(true) ?? '';
        } catch (e) {
          debugPrint('[AI_E2E][AUTH_ERROR] requestId=$thisRequestId '
              'error=getIdToken_failed detail=$e');
          wrappedOnError('[auth_expired] Erro ao renovar token. Tente novamente.');
          return true;
        }
        if (gptQaToken.isEmpty) {
          debugPrint('[AI_E2E][AUTH_ERROR] requestId=$thisRequestId '
              'error=auth_expired token_empty=true nativo');
          wrappedOnError('[auth_expired] Token vazio no nativo. Faça login novamente.');
          return true;
        }
      }

      // Montar systemPrompt para este ciclo QA
      // Reutiliza o mesmo pipeline de contexto (RAG, sessionLang, intent)
      final qaSessionLang = _resolveSessionLang(input);
      final qaIntent      = _classifyIntent(input);
      final qaTopicReset  = _sessionMemory.resetIfTopicChanged(input);
      final qaThreadStatus = _threadManager.evaluate(
        currentUserText: input,
        isPlantaoMode:   !longResponse,
        cameFromButton:  fromButton,
      );
      if (qaThreadStatus.action == ThreadAction.newThread && !longResponse) {
        final removed = _aiHistory.length;
        _aiHistory.clear();
        _sessionMemory.reset();
        debugPrint('[AI_E2E][HISTORY_RESET] requestId=$thisRequestId '
            'removed=$removed reason=${qaThreadStatus.reason}');
      }
      final qaExpandedInput = qaTopicReset ? input : _expandedQuery(input);
      final qaNormalized    = _normalize(qaExpandedInput);
      final qaProtos        = _matchProtocolsExtended(qaNormalized);
      final qaFinalProtos   = qaProtos.isNotEmpty ? qaProtos : _matchProtocols(qaNormalized);
      final qaLocalCtx      = _buildLocalAnswer(input);

      final qaSystemPrompt = AiService.buildClinicalSystemPrompt(
        lang:                   qaSessionLang,
        matchedProtocolSummaries: qaFinalProtos,
        matchedDrugSummaries:   const [],
        localAnswerContext:     qaLocalCtx,
        queryIntent:            qaIntent,
        patientAge:             _patient.age.isNotEmpty ? _patient.age : null,
        patientSex:             _patient.sex.isNotEmpty ? _patient.sex : null,
        patientWeight:          _patient.weight.isNotEmpty ? _patient.weight : null,
        patientClcr:            clcr,
        patientMedications:     _patient.medications.isNotEmpty ? _patient.medications : null,
        userQuery:              input,
        memory:                 _sessionMemory,
        isFirstMessage:         _aiHistory.isEmpty,
        isPlantaoMode:          !longResponse,
        proprietaryDrugContext: null,
      );

      final qaHistory = List<Map<String, String>>.from(
        ClinicalThreadManager.buildThreadHistory(
          fullHistory: _sanitizedHistory,
          status: qaThreadStatus,
          isPlantaoMode: !longResponse,
          currentTaskLabel: AiSmartRouter.detectTaskLabel(input,
              canonicalOverride: _canonicalTaskOverride), // MICRO-BUILD 462E-A.5.2
        ).map((m) => {
          'role':    m['role']    ?? '',
          'content': m['content'] ?? '',
        }),
      );

      // Acumulador local — Anti-Frankenstein: isolado por attempt
      final qaAccumulator = StringBuffer();
      bool qaFirstDelta   = false;
      bool qaCompFired    = false;
      int  qaDeltaCount   = 0;

      // Ativar estado de streaming (bolha de chat isolada)
      _aiStreamActive = true;
      aiChatProvider.setStreaming(true);
      // [RENDER_AUDIT]: apenas AiChatProvider rebuild — HomeScreen não é notificado
      // aqui. O notifyListeners() amplo ocorrerá SOMENTE em wrappedOnDone/wrappedOnError.

      // Timer de segurança QA (90s — mesmo orçamento do Modo Estudo)
      final qaTimeoutMs = longResponse ? 90000 : 45000;
      Timer? qaTimer;
      qaTimer = Timer(Duration(milliseconds: qaTimeoutMs), () {
        if (qaCompFired) return;
        qaCompFired = true;
        debugPrint('[AI_E2E][TIMEOUT] requestId=$thisRequestId '
            'timeoutMs=$qaTimeoutMs elapsedMs='
            '${DateTime.now().millisecondsSinceEpoch - globalStartMs}');
        _gptStreamSub?.cancel();
        _gptStreamSub     = null;
        _activeGptClient?.cancel(reason: 'qa_timeout');
        _activeGptClient  = null;
        _aiStreamActive   = false;
        aiChatProvider.setStreaming(false);
        if (_activeRequestId == thisRequestId) _activeRequestId = '';
        // MICRO-BUILD 462E-A.5.2: UI first, then release, then completeAiRequest LAST.
        wrappedOnDone(_timeoutSafeCard(_lang));
        // MICRO-BUILD 462E-A.5.1+5.2: release cache entry on TIMEOUT (after UI).
        ExternalToolLinkEngine.releaseCanonicalDecision(
            requestId: thisRequestId, decision: canonicalDecision);
        AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
      });

      // Criar stream SSE real
      final qaStream = ProviderRouterService.callGptProxyStream(
        userMessage:     input,
        systemPrompt:    qaSystemPrompt,
        idToken:         gptQaToken,
        history:         qaHistory,
        mode:            longResponse ? 'estudo' : 'plantao',
        lang:            _lang,
        requestId:       thisRequestId, // ID UNIFICADO propagado para o GptSseClient
        maxOutputTokens: longResponse ? 2500 : 3200,
      );

      _gptStreamSub = qaStream.listen(
        (AiEvent event) async {
          // Guard: descarta eventos de requestId obsoleto
          if (_activeRequestId != thisRequestId) {
            debugPrint('[AI_E2E][STALE_DROP] requestId=$thisRequestId '
                'activeId=$_activeRequestId event=${event.runtimeType}');
            return;
          }

          switch (event) {
            // ── AiStarted: conexão estabelecida ──────────────────────────────
            case AiStarted e:
              // ignore: avoid_print
              print('[AI_E2E][STARTED] requestId=$thisRequestId '
                  'model=${e.model} provider=${e.provider} attempt=${e.attempt} '
                  'startedAtMs=${e.startedAtMs} '
                  'ttConnect=${DateTime.now().millisecondsSinceEpoch - globalStartMs}ms');

            // ── AiTextDelta: fragmento real da rede ──────────────────────────
            case AiTextDelta e:
              if (e.delta.isEmpty) break;
              // Anti-Frankenstein: descarta fragmentos de attempt errado
              if (e.attempt != GptSseClient.kGptAttempt) {
                debugPrint('[AI_E2E][FRANKENSTEIN_DROP] requestId=$thisRequestId '
                    'delta_attempt=${e.attempt} expected=${GptSseClient.kGptAttempt}');
                break;
              }
              qaDeltaCount++;
              qaAccumulator.write(e.delta);
              // T1: primeiro delta (prova matemática de streaming real)
              if (!qaFirstDelta) {
                qaFirstDelta = true;
                // ignore: avoid_print
                print('[AI_E2E][T1_FIRST_DELTA] requestId=$thisRequestId '
                    'sequence=${e.sequence} delta="${e.delta.length > 20 ? e.delta.substring(0, 20) : e.delta}..." '
                    'T1_ms=${DateTime.now().millisecondsSinceEpoch} '
                    'elapsed=${DateTime.now().millisecondsSinceEpoch - globalStartMs}ms');
              }
              // [RENDER_AUDIT][ACTIVE_BUBBLE_BUILD]: onChunk atualiza SOMENTE a bolha ativa
              // notifyListeners() NÃO é chamado aqui — o AiVisualBuffer usa
              // Timer.periodic(40ms) para drenar e atualizar visibleTextNotifier.
              onChunk(qaAccumulator.toString());

            // ── AiCompleted: transport_done recebido ─────────────────────────
            case AiCompleted e:
              if (qaCompFired) break;
              qaCompFired = true;
              qaTimer?.cancel();
              // ignore: avoid_print
              print('[AI_E2E][T2_TRANSPORT_DONE] requestId=$thisRequestId '
                  'T2_ms=${DateTime.now().millisecondsSinceEpoch} '
                  'elapsed=${DateTime.now().millisecondsSinceEpoch - globalStartMs}ms '
                  'deltaCount=$qaDeltaCount '
                  'textLen=${e.fullText.length} '
                  'T1_before_T2=${qaFirstDelta ? "true" : "NO_DELTA_RECEIVED"} '
                  'provider=${e.usedProvider} attempt=${e.attempt}');

              // ── MICRO-BUILD 462E-A.5.1: Stream Finalization Pyramid ──────────
              // Rigid execution order (no state finalized before barrier passes):
              //   1. Transport Completed (here: AiCompleted event received)
              //   2. Raw Buffer ready
              //   3. TruncationInspector.inspect() [HARD BARRIER]
              //   4. Repair subsystem (if isTruncated && confidence==high)
              //   5. Re-inspection + ResponseValidator
              //   6. Persistence (SessionDedup / _aiHistory)
              //   7. AiCompleted UI event + EXT_TOOL Card
              // Modo Plantão: content provisional until validation passes.
              // ──────────────────────────────────────────────────────────────────
              final qaRawText = e.fullText.trim();
              // ignore: avoid_print
              print('[AI_E2E][SANITIZED] requestId=$thisRequestId '
                  'rawLen=${qaRawText.length} mode=${longResponse ? "estudo" : "plantao"}');

              try {
                // ── STEP 3: TruncationInspector HARD BARRIER ──────────────────
                String qaBarrierText = qaRawText;
                final qaTruncCheck = TruncationInspector.inspect(qaRawText);
                TruncationInspector.emitTelemetry(
                  requestId: thisRequestId,
                  result: qaTruncCheck,
                );

                if (qaTruncCheck.isTruncated &&
                    qaTruncCheck.confidenceLevel == TruncationConfidence.high) {
                  // ── STEP 4: Repair subsystem (AT MOST ONCE per requestId) ──
                  // ignore: avoid_print
                  print('[TRUNCATION_CHECK] BARRIER_TRIGGERED requestId=$thisRequestId '
                      'reason=${qaTruncCheck.violationReason} '
                      'confidence=high → initiating repair');

                  final qaRepairResult = await AiService.repairTruncated(
                    originalText:  qaRawText,
                    requestId:     thisRequestId,
                    isPlantaoMode: !longResponse,
                    appLanguage:   _lang,
                  );

                  if (!qaRepairResult.isValid) {
                    // Catastrophic failure → DROP_PAYLOAD
                    throw AiSafeOutputException(
                      message:   qaRepairResult.failureReason ?? 'repair_failed',
                      requestId: thisRequestId,
                    );
                  }
                  qaBarrierText = qaRepairResult.text;
                  TruncationInspector.emitTelemetry(
                    requestId: thisRequestId,
                    result: qaTruncCheck.withRepair(
                      retried: true,
                      fixed: qaRepairResult.wasRepaired,
                    ),
                  );
                }

                // ── STEP 5: ResponseValidator (sanitizeAndCheck) ───────────────
                final qaSanitized = qaBarrierText.isNotEmpty
                    ? AiSmartRouter.sanitizeAndCheck(
                        qaBarrierText,
                        isPlantaoMode: !longResponse,
                        appLanguage:   _lang,
                      )
                    : null;
                final qaFinalText = qaSanitized?.text ?? qaBarrierText;

                // Validar requestId pós-sanitize (guard de stale state)
                if (_activeRequestId != thisRequestId) {
                  debugPrint('[AI_E2E][POST_SANITIZE_STALE] requestId=$thisRequestId '
                      'activeId=$_activeRequestId — descartado após sanitize');
                  _gptStreamSub = null;
                  _aiStreamActive = false;
                  aiChatProvider.setStreaming(false);
                  AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
                  ExternalToolLinkEngine.releaseCanonicalDecision(
                      requestId: thisRequestId, decision: canonicalDecision);
                  return;
                }

                // ── STEP 6: Persistence (_aiHistory) — ONLY after barrier ───────
                if (qaFinalText.isNotEmpty && !_isFallbackText(qaFinalText)) {
                  _aiHistory
                    ..add({'role': 'user',      'content': input})
                    ..add({'role': 'assistant', 'content': qaFinalText});
                  while (_aiHistory.length > 20) _aiHistory.removeAt(0);
                }

                _gptStreamSub = null;
                _activeGptClient = null;
                _aiStreamActive  = false;
                aiChatProvider.setStreaming(false);

                // ignore: avoid_print
                print('[AI_E2E][COMPLETED] requestId=$thisRequestId '
                    'finalTextLen=${qaFinalText.length} '
                    'durationMs=${DateTime.now().millisecondsSinceEpoch - globalStartMs}ms '
                    'provider=${e.usedProvider}');

                // ── STEP 7: UI emission → State Event → ResumeCoordinator (TERMINAL ORDER) ──
                // MICRO-BUILD 462E-A.5.2: Rigid Transactional Termination Pyramid.
                // Persistence committed (Step 6) ↑ → UI emitted → ResumeCoordinator.complete
                // LAST. Marking complete before UI emit is prohibited — it would signal
                // downstream orchestrators that the transaction finished while render is pending.
                // [RENDER_AUDIT]: notifyListeners() APENAS aqui (via wrappedOnDone)
                wrappedOnDone(
                  qaFinalText.isNotEmpty
                      ? qaFinalText
                      : (_lang == 'es'
                          ? 'No pude generar una respuesta. ¿Puedes reformular? ⚕'
                          : 'Não consegui gerar uma resposta. Pode reformular? ⚕'),
                );
                // Release canonical decision cache entry — strictly after UI emit (COMPLETED).
                ExternalToolLinkEngine.releaseCanonicalDecision(
                    requestId: thisRequestId, decision: canonicalDecision);
                // ResumeCoordinator.complete() — TERMINAL POSITION (after UI + releaseDecision).
                AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
              } on AiSafeOutputException catch (safeError) {
                // ── TERMINAL: DROP_PAYLOAD — Repair critical failure ───────────
                // ignore: avoid_print
                print('[TRUNCATION_CHECK] DROP_PAYLOAD — REPAIR CRITICAL FAILURE '
                    'requestId=${safeError.requestId} '
                    'reason=${safeError.message}');
                _gptStreamSub = null;
                _activeGptClient = null;
                _aiStreamActive  = false;
                aiChatProvider.setStreaming(false);
                // MICRO-BUILD 462E-A.5.2: UI first, then release, then completeAiRequest LAST.
                wrappedOnError(
                  _lang == 'es'
                      ? 'Respuesta interrumpida (validación fallida). Intenta nuevamente. ⚕'
                      : 'Resposta interrompida (validação falhou). Tente novamente. ⚕',
                );
                ExternalToolLinkEngine.releaseCanonicalDecision(
                    requestId: thisRequestId, decision: canonicalDecision);
                AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
                return;
              }

            // ── AiFailed: falha com código clínico ───────────────────────────
            case AiFailed e:
              if (qaCompFired) break;
              qaCompFired = true;
              qaTimer?.cancel();

              // Parcial clínico significativo (≥ 80 chars) — não persistir
              if (e.hasSignificantPartial) {
                // ignore: avoid_print
                print('[AI_E2E][CLINICAL_PARTIAL] requestId=$thisRequestId '
                    'code=${e.code} partialLen=${e.partialText!.length} '
                    'hasSignificantPartial=true — NÃO persistido, exibe aviso');
                _gptStreamSub = null;
                _activeGptClient = null;
                _aiStreamActive  = false;
                aiChatProvider.setStreaming(false);
                // Aviso clínico de resposta interrompida — sem persistência
                final partialWarning = _lang == 'es'
                    ? '⚠️ Respuesta interrumpida antes de la validación final.\n'
                      'El contenido parcial no fue guardado ni validado.\n\n'
                      '${e.partialText}'
                    : '⚠️ Resposta interrompida antes da validação final.\n'
                      'O conteúdo parcial não foi salvo nem validado.\n\n'
                      '${e.partialText}';
                // MICRO-BUILD 462E-A.5.2: UI first, releaseDecision, then completeAiRequest LAST.
                // MICRO-BUILD 462E-A.5.3: AUDIT FIX — CLINICAL_PARTIAL was missing releaseDecision().
                // This path IS a final termination vector: must evict cache entry before completing.
                wrappedOnError(partialWarning);
                ExternalToolLinkEngine.releaseCanonicalDecision(
                    requestId: thisRequestId, decision: canonicalDecision);
                AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
                return;
              }

              // Falha sem parcial significativo — 401 específico
              if (e.code == 'gpt_sse_unauthenticated' || e.code == 'auth_expired') {
                debugPrint('[AI_E2E][AUTH_EXPIRED] requestId=$thisRequestId '
                    'code=${e.code} retryable=${e.retryable}');
                _gptStreamSub = null;
                _activeGptClient = null;
                _aiStreamActive  = false;
                aiChatProvider.setStreaming(false);
                // MICRO-BUILD 462E-A.5.2: UI first, releaseDecision, then completeAiRequest LAST.
                // MICRO-BUILD 462E-A.5.3: AUDIT FIX — AUTH_EXPIRED was missing releaseDecision().
                // This path IS a final termination vector: must evict cache entry before completing.
                wrappedOnError('[auth_expired] Sessão expirada (${e.code}). Faça login novamente.');
                ExternalToolLinkEngine.releaseCanonicalDecision(
                    requestId: thisRequestId, decision: canonicalDecision);
                AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
                return;
              }

              debugPrint('[AI_E2E][FAILED] requestId=$thisRequestId '
                  'code=${e.code} message=${e.message} retryable=${e.retryable} '
                  'elapsedMs=${DateTime.now().millisecondsSinceEpoch - globalStartMs}ms');
              _gptStreamSub = null;
              _activeGptClient = null;
              _aiStreamActive  = false;
              aiChatProvider.setStreaming(false);
              // MICRO-BUILD 462E-A.5.2: UI first, releaseDecision, then completeAiRequest LAST.
              wrappedOnError(
                e.code == 'gpt_sse_budget_guard'
                    ? (_lang == 'es'
                        ? 'Límite de uso alcanzado. Intenta en unos minutos. ⚕'
                        : 'Limite de uso atingido. Tente em alguns minutos. ⚕')
                    : (_lang == 'es'
                        ? 'Error en el asistente IA (${e.code}). Intenta nuevamente. ⚕'
                        : 'Erro no assistente IA (${e.code}). Tente novamente. ⚕'),
              );
              // MICRO-BUILD 462E-A.5.1+5.2: release cache entry on FAILED (after UI).
              ExternalToolLinkEngine.releaseCanonicalDecision(
                  requestId: thisRequestId, decision: canonicalDecision);
              AppResumeCoordinator.instance.completeAiRequest(thisRequestId);

            // ── AiProviderSwitched: sinaliza troca de provider ───────────────
            case AiProviderSwitched e:
              // ignore: avoid_print
              print('[AI_E2E][PROVIDER_SWITCH] requestId=$thisRequestId '
                  'from=${e.fromProvider} to=${e.toProvider} reason=${e.reason}');
              // Limpar acumulador se parcial < 80 chars (Anti-Frankenstein)
              final partial = qaAccumulator.toString();
              if (partial.length < AiFailed.kSignificantPartialThreshold) {
                qaAccumulator.clear();
                qaFirstDelta = false;
                qaDeltaCount = 0;
                debugPrint('[AI_E2E][STREAM_RESET_AUTO] requestId=$thisRequestId '
                    'partialLen=${partial.length} < 80 → buffer limpo');
              }
              // Se parcial ≥ 80: AiFailed virá em seguida (responsabilidade do GptSseClient)

            // ── AiStreamReset: limpa buffers do attempt anterior ─────────────
            case AiStreamReset e:
              // ignore: avoid_print
              print('[AI_E2E][STREAM_RESET] requestId=$thisRequestId '
                  'reason=${e.reason} attempt=${e.attempt}');
              qaAccumulator.clear();
              qaFirstDelta = false;
              qaDeltaCount = 0;

            // ── AiToolResult / AiSources: ignorados no QA path ───────────────
            case AiToolResult _:
            case AiSources _:
              break;
          }
        },
        onError: (Object e) {
          if (qaCompFired) return;
          qaCompFired = true;
          qaTimer?.cancel();
          debugPrint('[AI_E2E][STREAM_EXCEPTION] requestId=$thisRequestId error=$e '
              'elapsedMs=${DateTime.now().millisecondsSinceEpoch - globalStartMs}ms');
          _gptStreamSub    = null;
          _activeGptClient = null;
          _aiStreamActive  = false;
          aiChatProvider.setStreaming(false);
          // MICRO-BUILD 462E-A.5.2: UI first, then release, then completeAiRequest LAST.
          wrappedOnError(
            _lang == 'es'
                ? 'Error de red en el asistente IA. Intenta nuevamente. ⚕'
                : 'Erro de rede no assistente IA. Tente novamente. ⚕',
          );
          // MICRO-BUILD 462E-A.5.1+5.2: release cache entry on STREAM_EXCEPTION (after UI).
          ExternalToolLinkEngine.releaseCanonicalDecision(
              requestId: thisRequestId, decision: canonicalDecision);
          AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
        },
        onDone: () {
          // Stream SSE fechou sem AiCompleted — limpeza silenciosa
          if (qaCompFired) {
            _gptStreamSub = null;
            _aiStreamActive = false;
            aiChatProvider.setStreaming(false);
            return;
          }
          // EOF sem conclusão e sem AiFailed — segurança
          qaCompFired = true;
          qaTimer?.cancel();
          debugPrint('[AI_E2E][EOF_NO_COMPLETION] requestId=$thisRequestId '
              'accumulatorLen=${qaAccumulator.length}');
          _gptStreamSub    = null;
          _activeGptClient = null;
          _aiStreamActive  = false;
          aiChatProvider.setStreaming(false);
          final partialOnEof = qaAccumulator.toString().trim();
          // MICRO-BUILD 462E-A.5.2: UI first, then release, then completeAiRequest LAST.
          if (partialOnEof.isNotEmpty) {
            wrappedOnError(
              _lang == 'es'
                  ? 'Respuesta incompleta recibida. Intenta nuevamente. ⚕'
                  : 'Resposta incompleta recebida. Tente novamente. ⚕',
            );
          } else {
            wrappedOnError(
              _lang == 'es'
                  ? 'Sin respuesta del asistente. Intenta nuevamente. ⚕'
                  : 'Sem resposta do assistente. Tente novamente. ⚕',
            );
          }
          // MICRO-BUILD 462E-A.5.1+5.2: release cache entry on EOF/CANCELLED (after UI).
          ExternalToolLinkEngine.releaseCanonicalDecision(
              requestId: thisRequestId, decision: canonicalDecision);
          AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
        },
        cancelOnError: false,
      );

      return true; // BUILD 462E-A: QA path consumido com sucesso

    } // end shouldForceGptFallbackForQa block
    // ══════════════════════════════════════════════════════════════════════════
    // CONTINUA: fluxo normal (Gemini Free → fallbacks) quando shouldForceGptFallbackForQa=false
    // ══════════════════════════════════════════════════════════════════════════

    // ── Build 156: Client-Side Intelligence — sem gateway intermediário ───
    // AiGatewayService é agora um shim que injeta âncora de modo e delega
    // para GeminiServiceV2.sendStream() com a chave do app (carregada do Firestore).
    // Não há servidor intermediário — o Flutter fala direto com o Google.
    if (kDebugMode) debugPrint('[sendAiMessage] motor=${longResponse ? "ESTUDO" : "PLANTÃO"}');

    // ── ORDEM 49 M2: JIT Double-Check — sincronia atômica de modo ────────────
    // Segunda camada de segurança: confirma que o modo capturado neste exato
    // milissegundo (longResponse) é consistente com o systemPrompt que será
    // montado imediatamente abaixo. Detecta qualquer race condition entre
    // toggle de UI e disparo de request.
    //
    // Log estruturado — visível tanto em debug quanto em release para auditoria
    // de stale-state: se motor≠prompt.mode aparecer nos logs, há dessincronia.
    // NUNCA bloqueia o request — apenas registra para diagnóstico.
    // ignore: avoid_print
    print('[ORDEM49_MODE_SYNC] requestId=$thisRequestId '
        'motor=${longResponse ? "ESTUDO" : "PLANTÃO"} '
        'longResponse=$longResponse '
        'historyLen=${_aiHistory.length} '
        'hasUserMsg=${_aiHistory.any((m) => m["role"] == "user")} '
        'threadTopic=${_threadManager.activeTopic.isEmpty ? "VIRGIN" : _threadManager.activeTopic}');

    // ── Streaming via AiGatewayService ────────────────────────────────────
    _aiStreamActive = true;
    // BUILD 326: notifica AiChatProvider — apenas widgets de chat reconstroem.
    aiChatProvider.setStreaming(true);

    // ── Reutiliza todo o pipeline de contexto do buildAIAnswer ─────────────
    // strictContextIsolation, globalLanguageLock, RAG retrieval, system prompt
    // — nada muda. Só o transporte (streaming vs. batch) é diferente.
    // Build 111: _sessionMemory.reset() (memória clínica estruturada) é separado
    // de _aiHistory (turnos da API). Resetar _aiHistory ao mudar de tema causava
    // amnésia — o Gemini perdia o contexto conversacional. O system_instruction
    // já tem todo o contexto clínico via RAG; o histórico de turnos só ajuda.
    final topicReset  = _sessionMemory.resetIfTopicChanged(input);
    // BUILD 249: ClinicalThreadManager — decide continuar ou iniciar novo thread.
    // Se novo thread (novo caso clínico) → limpa _aiHistory para evitar
    // contaminação cruzada entre casos (ex: amiodarona → gastroenterite).
    // isPlantaoMode = !longResponse (Plantão=true → history mínimo ou vazio)
    final threadStatus = _threadManager.evaluate(
      currentUserText: input,
      isPlantaoMode:   !longResponse,
      cameFromButton:  fromButton,  // BUILD 262: bypasses HARD RESET on follow-up button taps
    );
    // BUILD 300: MODO ESTUDO — bypass absoluto de HARD RESET.
    // ClinicalThreadManager.evaluate() já retorna continueThread no Modo Estudo,
    // mas esta segunda camada garante que NUNCA ocorra _aiHistory.clear() enquanto
    // longResponse=true, mesmo que um caminho de código futuro altere o ThreadManager.
    if (threadStatus.action == ThreadAction.newThread && longResponse) {
      debugPrint('[BUILD300][HISTORY_SANITIZER] bypass reason=study_mode_hard_reset_forbidden '
          'threadReason=${threadStatus.reason} historyLen=${_aiHistory.length}');
    } else if (threadStatus.action == ThreadAction.newThread) {
      // BUILD 250: HARD RESET síncrono — ocorre ANTES de qualquer montagem de payload.
      // Limpa _aiHistory (contexto Gemini) + reseta memória clínica estruturada.
      // Isso elimina os 8.9k tokens de contexto acumulado que causaram truncamento.
      // APLICA-SE APENAS AO MODO PLANTÃO (!longResponse).
      final removed = _aiHistory.length;
      _aiHistory.clear();           // contexto Gemini → zero
      _sessionMemory.reset();       // memória clínica (diag, meds, labs) → zero
      debugPrint('[HISTORY_SANITIZER] HARD RESET ATIVADO: Limpando _aiHistory de forma absoluta. '
          'mode=plantao '
          'strategy=empty sent=0 removed=$removed '
          'reason=${threadStatus.reason}');
    }
    final sessionLang   = _resolveSessionLang(input);
    final intent        = _classifyIntent(input);
    // BUILD 249/250: após HARD RESET, _expandedQuery() lê histórico já vazio →
    // zero contaminação de contexto anterior no payload enviado.
    final expandedInput = topicReset ? input : _expandedQuery(input);
    final normalized    = _normalize(expandedInput);

    // BUILD 325: drug RAG removed — Google Search Grounding + system prompt directives.
    final _extProtos = _matchProtocolsExtended(normalized);
    final finalProtocols = _extProtos.isNotEmpty ? _extProtos : _matchProtocols(normalized);
    final localContext = _buildLocalAnswer(input);

    const String? proprietaryContext = null;

    // Build 104 — isFirstMessage: controla regra de saudação por turno.
    // _aiHistory já foi limpo por resetIfTopicChanged() acima quando o tema
    // muda, então isEmpty=true quando é a primeira mensagem da sessão OU
    // quando o tema mudou (= primeiro turno do novo tópico). Em ambos os casos
    // a saudação breve é permitida uma única vez. Nas mensagens subsequentes do
    // mesmo tema isEmpty=false e o prompt proíbe repetição de saudações.
    final systemPrompt = AiService.buildClinicalSystemPrompt(
      lang: sessionLang,
      matchedProtocolSummaries: finalProtocols,
      matchedDrugSummaries: const [],
      localAnswerContext: localContext,
      queryIntent: intent,
      patientAge:         _patient.age.isNotEmpty ? _patient.age : null,
      patientSex:         _patient.sex.isNotEmpty ? _patient.sex : null,
      patientWeight:      _patient.weight.isNotEmpty ? _patient.weight : null,
      patientClcr:        clcr,
      patientMedications: _patient.medications.isNotEmpty ? _patient.medications : null,
      userQuery:          input,
      memory:             _sessionMemory,
      isFirstMessage:     _aiHistory.isEmpty,
      isPlantaoMode:      !longResponse,
      proprietaryDrugContext: proprietaryContext,
    );

    // BUILD 253: log do tamanho real do systemPrompt (não gateado por kDebugMode).
    // Permite confirmar redução de tokens atingida no modo Plantão.
    final _spChars = systemPrompt.length;
    final _spTokensApprox = (_spChars / 4).round();
    print('[SYSTEM_PROMPT_AUDIT] requestId=${DateTime.now().millisecondsSinceEpoch} '
        'mode=${longResponse ? "estudo" : "plantao"} '
        'systemPromptChars=$_spChars systemPromptTokensApprox=$_spTokensApprox');
    if (_spTokensApprox > 6000) {
      print('[SYSTEM_PROMPT_AUDIT] ⚠️  ALERTA: systemPrompt acima de 6000 tokens '
          '(approx=$_spTokensApprox) — risco de Context Dilution no Plantão.');
    }

    // ── Build 156.2: Resolução automática da chave Gemini ───────────────
    // A chave NÃO é BYOA do usuário — é a chave do app, salva pelo admin
    // em app_config/global.apiKey no Firestore e carregada automaticamente
    // após o login via _loadAiKeyFromFirestore() → GeminiService.setGeminiApiKey().
    // O médico nunca vê ou configura nada — fluxo 100% invisível.
    //
    // Hierarquia de recuperação (igual ao buildAIAnswer):
    //   1. GeminiService._geminiApiKey (em memória — caminho feliz)
    //   2. FirestoreService.loadGeminiApiKey() (se saiu da memória por reload)
    //   3. GeminiService.initFromStorage() (SharedPrefs/localStorage — fallback offline)
    // ── Build 226: Gemini Free Key — provider primário do usuário ─────────────
    // A Gemini Free Key é a chave do app em app_config/global.apiKey.
    // NÃO é a GEMINI_PAID_API_KEY (que fica só no Firebase Secret server-side).
    // Todos os usuários aprovados podem ler app_config/global (rule: isApproved).
    // Hierarquia de recuperação:
    //   1. GeminiService._geminiApiKey em memória (caminho feliz — já carregada)
    //   2. FirestoreService.loadGeminiApiKey() → app_config/global.apiKey
    //   3. GeminiService.initFromStorage() → SharedPrefs/localStorage (fallback)
    // [AI_CONFIG] verbose log removed BUILD 244 — not needed in production

    if (!GeminiService.hasApiKey) {
      // BUILD 244: verbose key-loading logs moved under kDebugMode guard
      if (kDebugMode) debugPrint('[AI_FREE_PROVIDER] source=loading');
      // BUILD 309 [S3]: Força renovação do JWT Android antes do Firestore.
      // No Android, o token Firebase pode estar expirado entre sessões — a call
      // ao Firestore retornaria 401 silencioso → catch → geminiKey vazia →
      // app exibe falso "erro de conexão". getIdToken(true) garante token fresco.
      // Condição: apenas nativo (!kIsWeb) e usuário já autenticado.
      if (!kIsWeb) {
        try {
          final fbUser = FirebaseAuth.instance.currentUser;
          if (fbUser != null) {
            await fbUser
                .getIdToken(true) // force refresh — ignora cache local
                .timeout(const Duration(seconds: 5));
            if (kDebugMode) debugPrint('[BUILD309][S3] JWT renovado para uid=${fbUser.uid}');
          }
        } catch (e) {
          // Falha de renovação não bloqueia o fluxo — fallback para token expirado
          // que pode ainda funcionar se expirou há pouco tempo (<5min de grace).
          if (kDebugMode) debugPrint('[BUILD309][S3] getIdToken(true) falhou (ignorado): $e');
        }
      }
      try {
        final geminiKey = await FirestoreService.loadGeminiApiKey()
            .timeout(const Duration(seconds: 5));
        if (geminiKey.isNotEmpty) {
          GeminiService.setGeminiApiKey(geminiKey, source: GeminiKeySource.appConfig); // BUILD 294
        } else {
          await GeminiService.initFromStorage();
        }
      } catch (e) {
        await GeminiService.initFromStorage();
      }
    }

    // Resolve a chave final — Gemini Free Key em memória.
    // Se vazia: GeminiServiceV2 emitirá chunk.error('api_key_invalid') → tratado abaixo.
    final geminiApiKey = GeminiService.apiKeyForLab;
    if (kDebugMode) debugPrint('[AI_ROUTER] freeKey=${geminiApiKey.isNotEmpty} motor=${longResponse ? "estudo" : "plantao"}');

    final accumulator = StringBuffer();

    // ── Guard anti-duplicata: onDone/onError devem disparar UMA única vez ──
    bool completionFired = false;

    // ── BUILD 432 / BUILD 437 / BUILD 440-MASTER-SHIELD [P1 + P2] ────────────
    // AUTO-RETRY ENGINE — Intercepta resposta vazia (len=0 / finalText.isEmpty)
    // ANTES de mostrar erro ao usuário. Sequência:
    //   1. Stream fecha com acumulador vazio (soluço de rede ou timeout parcial)
    //   2. _freeStreamRetryCount < 1 → re-inicia stream Free via AiGatewayService
    //   3. UI permanece em _thinking=true (EcgLoadingBlock) — retry invisível
    //   4. Se retry também vazio → escala para tryPaidFallback() (Layer 2/3)
    // Máx: 1 retry silencioso por requisição.
    //
    // BUILD 440 [P2] — THREADTOPIC ISOLATION GUARD:
    // O retry (linhas abaixo) re-usa os valores capturados ANTES do início do
    // stream: `input`, `systemPrompt`, `geminiApiKey`, `_sanitizedHistory`.
    // _threadManager.evaluate() NÃO é chamado novamente durante o retry —
    // portanto o `activeTopic` permanece INALTERADO mesmo que o acumulador
    // venha vazio ou corrompido. Fragmentos de texto parcial do stream falho
    // nunca alcançam o ClinicalThreadManager. Isolamento garantido.
    int _freeStreamRetryCount = 0;

    // ── Build 226: requestId único para rastreamento ─────────────────────────
    final requestId = ProviderRouterService.generateRequestId();

    // ── BUILD 245: Smart AI Router — classifica prioridade da requisição ─────
    // Plantão / keywords críticas → pago direto (sem tentar Free primeiro).
    // Acadêmico / conceitual → Free primeiro, pago como fallback.
    final contractName = !longResponse ? 'CONTRACT_PLANTAO' : 'CONTRACT_ESTUDO';
    final (aiPriority, aiPriorityReason) = AiSmartRouter.classifyPriority(
      userMessage:  input,
      isPlantaoMode: !longResponse,
      contractName:  contractName,
    );
    if (kDebugMode) debugPrint(
      '[AI_ROUTER] priority=$aiPriority reason=$aiPriorityReason '
      'provider=${aiPriority == "critical" ? "paid" : "free"} '
      'fallback=${aiPriority == "critical" ? "disabled" : "paid"}',
    );

    // ── Build 226: helper para acionar Gemini Paid após falha do Free ────────
    // Chamado tanto no chunk.isError quanto no onDone vazio.
    // BUILD 245: também chamado diretamente (sem Free) para requisições críticas.
    // BUILD 320: Id Guard — verifica se o requestId ainda é ativo ANTES e DEPOIS
    //   do await callPaidProxy(). O Paid Proxy pode demorar 60-75s no Modo Estudo.
    //   Se o RESUME_COORDINATOR disparou onTimeout nesse intervalo, _activeRequestId
    //   já foi zerado — a resposta tardia do Proxy deve ser descartada silenciosamente
    //   para evitar setState/notifyListeners em contexto já descartado (race condition
    //   que produzia DiagnosticsProperty<void> no Flutter).
    // Nunca expõe a chave paga — usa proxy seguro (Cloud Function).
    Future<bool> tryPaidFallback(String reason) async {
      // MICRO-BUILD 462E-A.5.3: returns true when fallback assumed ownership
      // of terminal events (wrappedOnDone/wrappedOnError + release + complete).
      // Returns false when stale-guard dropped the call or fallback itself failed
      // silently — caller must then execute its own release + complete sequence.
      // BUILD 320: Id Guard — PRÉ-CHAMADA: descarta se requestId já foi invalidado
      if (_activeRequestId != thisRequestId) {
        debugPrint('[BUILD320][STALE_GUARD] tryPaidFallback PRE-CALL drop: '
            'reason=$reason requestId=$requestId thisRequestId=$thisRequestId '
            'activeId=$_activeRequestId — paid proxy call suppressed');
        return false; // stale: caller retains responsibility for terminal events
      }
      if (kDebugMode) debugPrint('[AI_ROUTER] paid_fallback reason=$reason requestId=$requestId');

      // ── BUILD 321: Layer 2 — GPT-4o Mini (antes do Gemini Paid) ──────────
      // Tenta GPT-4o Mini primeiro quando _openAiKey estiver configurada no
      // Firestore (app_config/global.openAiKey preenchido pelo admin).
      // A chave NÃO vai no payload — apenas sinaliza que o admin configurou o
      // provedor OpenAI. O segredo real (OPENAI_API_KEY) é lido server-side na CF.
      if (_openAiKey.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('[BUILD321][LAYER2] Tentando GPT-4o Mini reason=$reason requestId=$requestId');
        }

        // PRE-CALL Id Guard Layer 2 (BUILD 320 pattern preservado)
        if (_activeRequestId != thisRequestId) {
          debugPrint('[BUILD320][STALE_GUARD] tryPaidFallback LAYER2 PRE-CALL drop: '
              'reason=$reason activeId=$_activeRequestId');
          return false; // MICRO-BUILD 462E-A.5.3: stale — caller retains terminal responsibility
        }

        final gptResult = await ProviderRouterService.callGptProxy(
          userMessage:  input,
          systemPrompt: systemPrompt,
          history:      List<Map<String, String>>.from(
            ClinicalThreadManager.buildThreadHistory(
              fullHistory: _sanitizedHistory,
              status: threadStatus,
              isPlantaoMode: !longResponse,
              // MICRO-BUILD 462E-A.5.2: canonical override in paid fallback path.
              currentTaskLabel: AiSmartRouter.detectTaskLabel(input,
                  canonicalOverride: _canonicalTaskOverride),
            ).map((m) => {
              'role':    m['role']    ?? '',
              'content': m['content'] ?? '',
            }),
          ),
          mode:            longResponse ? 'estudo' : 'plantao',
          lang:            _lang,
          requestId:       requestId,
          maxOutputTokens: longResponse ? 2500 : 3200,
        );

        // POST-AWAIT Id Guard Layer 2 (BUILD 320 pattern preservado)
        if (_activeRequestId != thisRequestId) {
          debugPrint('[BUILD320][STALE_GUARD] tryPaidFallback LAYER2 POST-AWAIT drop: '
              'reason=$reason activeId=$_activeRequestId textLen=${gptResult.text.length} '
              '— resultado tardio GPT descartado (Id Guard)');
          return false; // stale post-await: caller retains responsibility
        }

        if (gptResult.success && gptResult.text.isNotEmpty) {
          // ignore: avoid_print
          print('[RAW_AI_OUTPUT][GPT_PROXY] len=${gptResult.text.length} '
              'requestId=$requestId mode=${longResponse ? "estudo" : "plantao"}');
          final gptSanitized = AiSmartRouter.sanitizeAndCheck(
            gptResult.text,
            isPlantaoMode: !longResponse,
            appLanguage:   _lang,
          );
          final gptText = gptSanitized.text;
          if (!_isFallbackText(gptText)) {
            _aiHistory
              ..add({'role': 'user',      'content': input})
              ..add({'role': 'assistant', 'content': gptText});
            while (_aiHistory.length > 20) _aiHistory.removeAt(0);
          } else if (kDebugMode) {
            debugPrint('[HISTORY_SANITIZER] gpt_layer2_blocked reason=isFallbackText');
          }
          debugPrint('[BUILD321][LAYER2] GPT-4o Mini sucesso requestId=$requestId '
              'model=${gptResult.model} durationMs=${gptResult.durationMs}ms');
          wrappedOnDone(gptText);
          // MICRO-BUILD 462E-A.5.3: Layer 2 handled terminal UI event.
          // Fallback owns release + complete here.
          ExternalToolLinkEngine.releaseCanonicalDecision(
              requestId: thisRequestId, decision: canonicalDecision);
          AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
          return true; // Layer 2 resolved — handled terminal events
        }

        // GPT falhou — cai para Layer 3 (Gemini Paid)
        debugPrint('[BUILD321][LAYER2] GPT-4o Mini falhou error=${gptResult.errorCode} '
            '— escalando para Gemini Paid (Layer 3) requestId=$requestId');
      }
      // ── FIM BUILD 321: Layer 2 ────────────────────────────────────────────

      // BUILD 320: Id Guard — PRÉ-CHAMADA Layer 3 (Gemini Paid)
      if (_activeRequestId != thisRequestId) {
        debugPrint('[BUILD320][STALE_GUARD] tryPaidFallback LAYER3 PRE-CALL drop: '
            'reason=$reason activeId=$_activeRequestId — gemini paid suppressed');
        return false; // stale: caller retains responsibility for terminal events
      }

      final paidResult = await ProviderRouterService.callPaidProxy(
        userMessage:  input,
        systemPrompt: systemPrompt,
        history:      List<Map<String, String>>.from(  // BUILD 304: micro-window + intent-reset
          ClinicalThreadManager.buildThreadHistory(
            fullHistory: _sanitizedHistory,
            status: threadStatus,
            isPlantaoMode: !longResponse,
            // MICRO-BUILD 462E-A.5.2: canonical override in paid proxy path.
            currentTaskLabel: AiSmartRouter.detectTaskLabel(input,
                canonicalOverride: _canonicalTaskOverride), // BUILD 304 [G1b]
          ).map((m) => {
            'role':    m['role']    ?? '',
            'content': m['content'] ?? '',
          }),
        ),
        mode:            longResponse ? 'estudo' : 'plantao',
        lang:            _lang,
        requestId:       requestId,
        maxOutputTokens: longResponse ? 2500 : 3200,  // ORDEM 47 M2: Estudo 2048→2500 (lock cognitivo — garante output completo no Pro)
      );

      // BUILD 320: Id Guard — PÓS-AWAIT: descarta se o requestId foi invalidado
      // enquanto callPaidProxy estava em voo (até 75s no Modo Estudo).
      // Cenário: RESUME_COORDINATOR disparou onTimeout durante o await → zerou
      // _activeRequestId → resposta tardia do Proxy chegou → sem este guard,
      // wrappedOnDone chamaria setState num contexto já descartado → crash.
      if (_activeRequestId != thisRequestId) {
        debugPrint('[BUILD320][STALE_GUARD] tryPaidFallback POST-AWAIT drop: '
            'reason=$reason requestId=$requestId thisRequestId=$thisRequestId '
            'activeId=$_activeRequestId textLen=${paidResult.text.length} '
            '— resultado tardio descartado (Id Guard)');
        return false; // stale post-await: caller retains responsibility
      }

      if (paidResult.success && paidResult.text.isNotEmpty) {
        // BUILD 252: print do rawText pago ANTES de sanitizeAndCheck
        // ignore: avoid_print
        print('[RAW_AI_OUTPUT][PAID_PROXY] len=${paidResult.text.length} '
            'requestId=$requestId mode=${longResponse ? "estudo" : "plantao"}');
        if (paidResult.text.length < 100) {
          // ignore: avoid_print
          print('[RAW_AI_OUTPUT] ⚠️  ALERTA resposta curta do Paid: "${paidResult.text.length < 200 ? paidResult.text : paidResult.text.substring(0, 200)}"');
        }
        // BUILD 232: sanitizeAndCheck bloqueia meta leak severo antes de onDone
        final paidSanitized = AiSmartRouter.sanitizeAndCheck(
          paidResult.text,
          isPlantaoMode: !longResponse,
          appLanguage:   _lang,
        );
        final paidText = paidSanitized.text;
        // HOTFIX 247D: nunca adicionar fallback ao histórico da API
        if (!_isFallbackText(paidText)) {
          _aiHistory
            ..add({'role': 'user',      'content': input})
            ..add({'role': 'assistant', 'content': paidText});
          while (_aiHistory.length > 20) _aiHistory.removeAt(0);
        } else if (kDebugMode) {
          debugPrint('[HISTORY_SANITIZER] paid_fallback_blocked reason=isFallbackText');
        }
        wrappedOnDone(paidText);          // BUILD 254: notifyListeners() incluso
        // MICRO-BUILD 462E-A.5.3: fallback owns release + complete.
        ExternalToolLinkEngine.releaseCanonicalDecision(
            requestId: thisRequestId, decision: canonicalDecision);
        AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
        return true; // handled: fallback took ownership of terminal events
      } else {
        // Paid também falhou — mostra mensagem de instabilidade
        debugPrint('[AI_PROVIDER] both_failed requestId=$requestId reason=${paidResult.errorCode}');
        final instabilityMsg = _lang == 'es'
            ? 'Estamos con inestabilidad temporal en la IA.\nIntenta nuevamente en algunos segundos. ⚕'
            : 'Estamos com instabilidade temporária na IA.\nTente novamente em alguns segundos. ⚕';
        wrappedOnError(instabilityMsg);      // BUILD 254
        // Fallback emitted error UI — still owns release + complete.
        ExternalToolLinkEngine.releaseCanonicalDecision(
            requestId: thisRequestId, decision: canonicalDecision);
        AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
        return true; // handled (error path): fallback took ownership
      }
    }

    // ── SUPER ORDEM MASTER 12 M1b: ROUTER BLINDAGEM ─────────────────────────
    // Se o usuário tem sessão Gemini ativa (_geminiConnected), o proxy pago
    // (geminiPaidProxy Cloud Function) retorna 503 — é inútil chamá-lo.
    // Forçamos aiPriority='academic' para usar sempre o caminho Free (streaming
    // direto com a app key), que funciona normalmente para usuários autenticados.
    // O fallback pago ainda existe no caminho acadêmico caso o Free falhe por
    // outros motivos (quota, network), mas o caminho crítico→pago direto é
    // bypassado quando há sessão ativa — evitando o card de timeout falso.
    final effectivePriority = _geminiConnected
        ? 'academic' // blindagem: free path para usuários com sessão ativa
        : aiPriority;
    if (kDebugMode && _geminiConnected && aiPriority == 'critical') {
      debugPrint('[ROUTER_BLINDAGEM] geminiConnected=true → override critical→academic requestId=$requestId');
    }

    // ── BUILD 245: Caminho crítico — vai direto ao pago, sem Free ───────────
    // Se aiPriority == 'critical': Plantão/urgência/dose/sigla — nunca Free.
    // Evita 503→fallback overhead (até 5s perdidos) em contexto de emergência.
    //
    // Proteções de concorrência:
    //   • criticalDone: bool local — garante onDone/onError disparam 1x.
    //   • _aiStreamActive=true durante o voo → bloqueia nova chamada.
    //   • Timer 30s → safe-card se proxy não responder a tempo.
    //     BUILD 245 ADENDO: 30s (era 15s) — paid proxy pode demorar 15-25s.
    if (effectivePriority == 'critical') {
      bool criticalDone = false;
      Timer? criticalTimeoutTimer;

      // Timer: 30s — Cloud Function pode ter cold start + Gemini inference.
      // 15s anterior cortava respostas válidas antes do proxy concluir.
      criticalTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (criticalDone) return;
        criticalDone = true;
        final elapsedMs = DateTime.now().millisecondsSinceEpoch - globalStartMs;
        debugPrint('[AI_TIMEOUT] mode=plantao timeoutMs=30000 provider=paid elapsedMs=$elapsedMs requestId=$thisRequestId');
        if (_activeRequestId == thisRequestId) _activeRequestId = '';
        _aiStreamActive = false;
        aiChatProvider.setStreaming(false); // BUILD 326
        AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
        wrappedOnDone(_timeoutSafeCard(_lang)); // BUILD 254
      });

      // Chama proxy pago direto (sem stream Free).
      unawaited(() async {
        final paidResult = await ProviderRouterService.callPaidProxy(
          userMessage:  input,
          systemPrompt: systemPrompt,
          history: List<Map<String, String>>.from(  // BUILD 304: micro-window + intent-reset
            ClinicalThreadManager.buildThreadHistory(
              fullHistory: _sanitizedHistory,
              status: threadStatus,
              isPlantaoMode: !longResponse,
              // MICRO-BUILD 462E-A.5.2: canonical override in critical direct path.
              currentTaskLabel: AiSmartRouter.detectTaskLabel(input,
                  canonicalOverride: _canonicalTaskOverride), // BUILD 304 [G1b]
            ).map((m) => {
              'role':    m['role']    ?? '',
              'content': m['content'] ?? '',
            }),
          ),
          mode:            longResponse ? 'estudo' : 'plantao',
          lang:            _lang,
          requestId:       requestId,
          maxOutputTokens: longResponse ? 2500 : 3200,  // ORDEM 47 M2: Estudo 2048→2500 (lock cognitivo — garante output completo no Pro)
        );

        criticalTimeoutTimer?.cancel();
        if (criticalDone) return; // timer já disparou — descarta resultado
        criticalDone = true;
        if (_activeRequestId == thisRequestId) _activeRequestId = '';
        _aiStreamActive = false;
        aiChatProvider.setStreaming(false); // BUILD 326
        // MICRO-BUILD 462E-A.5.3: completeAiRequest moved AFTER UI emission below.

        if (paidResult.success && paidResult.text.isNotEmpty) {
          // BUILD 252: print raw antes de sanitizeAndCheck (caminho crítico)
          // ignore: avoid_print
          print('[RAW_AI_OUTPUT][CRITICAL_PAID] len=${paidResult.text.length} '
              'requestId=$requestId mode=${longResponse ? "estudo" : "plantao"}');
          if (paidResult.text.length < 100) {
            // ignore: avoid_print
            print('[RAW_AI_OUTPUT] ⚠️  ALERTA resposta curta (critical): "${paidResult.text.length < 200 ? paidResult.text : paidResult.text.substring(0, 200)}"');
          }
          final paidSanitized = AiSmartRouter.sanitizeAndCheck(
            paidResult.text,
            isPlantaoMode: !longResponse,
            appLanguage:   _lang,
          );
          final paidText = paidSanitized.text;
          // HOTFIX 247D: nunca adicionar fallback ao histórico da API
          if (!_isFallbackText(paidText)) {
            _aiHistory
              ..add({'role': 'user',      'content': input})
              ..add({'role': 'assistant', 'content': paidText});
            while (_aiHistory.length > 20) _aiHistory.removeAt(0);
          } else if (kDebugMode) {
            debugPrint('[HISTORY_SANITIZER] critical_paid_fallback_blocked reason=isFallbackText');
          }
          wrappedOnDone(paidText);             // BUILD 254
          // MICRO-BUILD 462E-A.5.3: release cache + coordinator AFTER UI emission (critical path success).
          ExternalToolLinkEngine.releaseCanonicalDecision(
              requestId: thisRequestId, decision: canonicalDecision);
          AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
        } else {
          debugPrint('[AI_PROVIDER] critical_paid_failed requestId=$requestId reason=${paidResult.errorCode}');
          // Pago falhou → safe-card (sem tentar Free — intencional no modo crítico)
          wrappedOnDone(_timeoutSafeCard(_lang)); // BUILD 254
          // MICRO-BUILD 462E-A.5.3: release cache + coordinator AFTER UI emission (critical path failure).
          ExternalToolLinkEngine.releaseCanonicalDecision(
              requestId: thisRequestId, decision: canonicalDecision);
          AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
        }
      }());

      return true;
    }

    // ── BUILD 323 [OPT-3]: Gateway de Bypass por Volume — Teto 14k chars ─────
    // Após compactação semântica (OPT-1 + OPT-2), payloads Modo Estudo com RAG
    // ativo ainda podem superar 14.000 chars (módulos clínicos + ragAnchor +
    // ragCrossCheck = carga legítima). O gemini_free usa SSE direto para
    // generativelanguage.googleapis.com — buffers de rede web sem backpressure
    // adequado sofrem throttling em payloads massivos → truncamento de stream.
    // Servidores dedicados (GPT-4o Mini / Gemini Paid via CF proxy) possuem
    // buffers HTTP robustos e processam contextos longos sem asfixiar o browser.
    //
    // REGRA: systemPrompt.length > 14.000 → bypassa gemini_free completamente
    //        → aciona tryPaidFallback diretamente (Layer 2 → Layer 3).
    //
    // PRESERVAÇÃO DE GUARDS:
    //   • PRE-CALL Id Guard verificado ANTES do await tryPaidFallback.
    //   • tryPaidFallback() possui seus próprios PRE/POST-AWAIT Id Guards
    //     internos (BUILD 320) — preservados integralmente.
    //   • _geminiConnected=true → effectivePriority='academic' → chegamos aqui
    //     normalmente; bypass também se aplica (Free com sessão ativa também
    //     sofre throttling em payloads massivos).
    const int _kFreeLayerCharCeiling = 20000;
    if (systemPrompt.length > _kFreeLayerCharCeiling) {
      // ignore: avoid_print
      print('[AI_ROUTER] Payload massivo detectado (Chars: ${systemPrompt.length}) '
          '-> Conflitos Removidos -> Ignorando Gemini Free '
          '-> Direcionando para Canal Dedicado');
      // PRE-CALL Id Guard (BUILD 320 pattern)
      if (_activeRequestId != thisRequestId) {
        debugPrint('[BUILD323][BYPASS_GUARD] massive_payload PRE-CALL drop: '
            'activeId=$_activeRequestId thisRequestId=$thisRequestId');
        return false;
      }
      unawaited(tryPaidFallback('massive_payload_bypass_14k'));
      return true;
    }
    // ── FIM BUILD 323 [OPT-3] ────────────────────────────────────────────────

    // ── Caminho acadêmico: Free primeiro, pago como fallback ─────────────────
    // Subscreve o stream via AiGatewayService (shim Build 156):
    //   1. Injeta âncora de modo (ModeAnchorEngine) no systemPrompt
    //   2. Delega para GeminiServiceV2.sendStream() com chave do app
    //   3. SSE direto para generativelanguage.googleapis.com — sem intermediário
    // NOTA: sendStream() inicia HTTP imediatamente (eagerly) — não é lazy.
    if (_canonicalTaskOverride.isNotEmpty) {
      // ignore: avoid_print
      print('[CANONICAL_TASK_ENFORCEMENT] requestId=$thisRequestId '
          'intent=${canonicalDecision!.intent.name} '
          'task=$_canonicalTaskOverride '
          'source=canonicalDecision regexSuppressed=true');
    }

    final stream = AiGatewayService.sendStream(
      userMessage:  input,
      systemPrompt: systemPrompt,
      apiKey:       geminiApiKey,  // ← chave do app (admin), carregada do Firestore
      // BUILD 249: thread-filtered history — empty on new case, minimal on continuation
      history:      List.unmodifiable(ClinicalThreadManager.buildThreadHistory(
        fullHistory: _sanitizedHistory,
        status: threadStatus,
        isPlantaoMode: !longResponse,
        // MICRO-BUILD 462E-A.5.2: canonical override propagated to thread label.
        currentTaskLabel: AiSmartRouter.detectTaskLabel(input,
            canonicalOverride: _canonicalTaskOverride), // BUILD 304 [G1b]
      )),
      useGrounding: true,
      longResponse: longResponse,  // false=Motor Plantão / true=Motor Estudos
      appLanguage:  _lang,          // Build 190: Language Lock Absoluto — idioma do app
      canonicalTaskOverride: _canonicalTaskOverride, // MICRO-BUILD 462E-A.5.2
    );

    // ── BUILD 320: Timer global — caminho acadêmico (Free→Fallback) ───────────
    // BUILD 238/245 ADENDO: Orçamento: Free1=5s + Free2=5s + Paid=20s = 30s.
    // BUILD 320 CORREÇÃO: o Modo Estudo processa payloads de 7000+ tokens via
    //   Paid Proxy — a inferência pode levar 60-75s (Cloud Function cold-start +
    //   Gemini Pro long-context). O timer de 30s cortava respostas válidas antes
    //   do Proxy concluir, disparando wrappedOnDone com safe-card enquanto o
    //   callPaidProxy ainda estava em voo — gerando duplo disparo e a race
    //   condition DiagnosticsProperty<void> no widget tree.
    //
    // NOVO ORÇAMENTO:
    //   Plantão (!longResponse): 30s — urgência real, não pode esperar mais.
    //   Estudo   (longResponse):  90s — payload longo, cold-start incluído.
    //
    // NOTA: o timer só dispara se completionFired=false (stream Free travado).
    // Quando Free falha e Paid começa, completionFired=true → timer neutered.
    // Útil apenas para hung stream (sem chunks, sem erro, sem done).
    final globalTimeoutMs = longResponse ? 90000 : 30000; // BUILD 320
    Timer? _globalTimeoutTimer;
    _globalTimeoutTimer = Timer(Duration(milliseconds: globalTimeoutMs), () {
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - globalStartMs;
      debugPrint('[AI_TIMEOUT][BUILD320] mode=${longResponse ? "estudo" : "academic"} '
          'timeoutMs=$globalTimeoutMs provider=free elapsedMs=$elapsedMs requestId=$thisRequestId');
      if (completionFired) return;
      completionFired = true;
      // BUILD 320: invalida o requestId atomicamente — o Id Guard em tryPaidFallback
      // detectará a invalidação e descartará silenciosamente qualquer resposta tardia
      // do Paid Proxy que chegar após este timer, sem setState em contexto morto.
      if (_activeRequestId == thisRequestId) _activeRequestId = '';
      _aiStreamActive = false;
      aiChatProvider.setStreaming(false); // BUILD 326: global timeout — UI desbloqueia
      _aiStreamSub?.cancel();
      _aiStreamSub = null;
      accumulator.clear();
      // BUILD 241: remove do coordinator (timer interno disparou antes do resume)
      AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
      // MICRO-BUILD 462E-A.5.1: release cache entry on global TIMEOUT
      ExternalToolLinkEngine.releaseCanonicalDecision(
          requestId: thisRequestId, decision: canonicalDecision);
      wrappedOnDone(_timeoutSafeCard(_lang)); // BUILD 254: global timer
    });

    _aiStreamSub = stream.listen(
      (chunk) async {
        if (chunk.isError) {
          // Build 126 — TOLERÂNCIA A FALHAS: conteúdo parcial válido → exibir.
          if (completionFired) return;
          completionFired = true;
          _aiStreamActive = false;
          aiChatProvider.setStreaming(false); // BUILD 326
          _aiStreamSub = null;
          final rawPartial = accumulator.toString().trim();
          final errCode = chunk.errorCode ?? 'network';

          // ── BUILD 278 / BUILD 334 FORENSE: fallback pago para erros recuperáveis
          // REGRA A (BUILD 278 + BUILD 334): erros que SEMPRE escalona para paid,
          //   independente do tamanho do conteúdo parcial:
          //   • http_503 = stream truncado pela infraestrutura Google.
          //   • http_404 = endpoint inexistente (modelo renomeado/deprecado).
          //   • http_400 = payload malformado / thinkingConfig incompatível.
          //   • unexpected = _runPipeline com exceção não categorizada.
          //   Mostrar texto parcial desses erros = conteúdo incompleto = UX ruim.
          //   O paid proxy retorna sempre a resposta COMPLETA.
          //
          // REGRA B (Build 226): outros erros recuperáveis escalona
          //   somente quando sem conteúdo parcial significativo (≤40 chars).
          //   Mantida para 'quota', 'timeout', 'network', 'stream_error' etc.
          const _alwaysFallbackCodes = {
            'http_503', 'http_404', 'http_400', 'unexpected',
          };
          final bool isAlwaysFallback = _alwaysFallbackCodes.contains(errCode);
          if (isAlwaysFallback && ProviderRouterService.shouldTriggerPaidFallback(errCode)) {
            if (kDebugMode) debugPrint('[AI_ROUTER] BUILD334 $errCode → fallback=paid silencioso (${rawPartial.length}c descartados)');
            accumulator.clear(); // descarta parcial — nunca exibir resposta incompleta
            // MICRO-BUILD 462E-A.5.3: delegate to fallback; handle false (stale) case.
            unawaited(() async {
              final handled = await tryPaidFallback(errCode);
              if (!handled) {
                wrappedOnError(_lang == 'es'
                    ? 'Estamos con inestabilidad temporal en la IA. Intenta nuevamente. ⚕'
                    : 'Estamos com instabilidade temporária na IA. Tente novamente. ⚕');
                ExternalToolLinkEngine.releaseCanonicalDecision(
                    requestId: thisRequestId, decision: canonicalDecision);
                AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
              }
            }());
            return;
          }
          if (!isAlwaysFallback && ProviderRouterService.shouldTriggerPaidFallback(errCode) &&
              rawPartial.length <= 40) {
            if (kDebugMode) debugPrint('[AI_ROUTER] free_error errCode=$errCode → aciona paid');
            accumulator.clear();
            // MICRO-BUILD 462E-A.5.3: delegate to fallback; handle false (stale) case.
            unawaited(() async {
              final handled = await tryPaidFallback(errCode);
              if (!handled) {
                wrappedOnError(_lang == 'es'
                    ? 'Estamos con inestabilidad temporal en la IA. Intenta nuevamente. ⚕'
                    : 'Estamos com instabilidade temporária na IA. Tente novamente. ⚕');
                ExternalToolLinkEngine.releaseCanonicalDecision(
                    requestId: thisRequestId, decision: canonicalDecision);
                AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
              }
            }());
            return;
          }

          // Conteúdo parcial significativo OU erro não-recuperável → exibe parcial
          if (rawPartial.length > 40) {
            // BUILD 232: sanitizeAndCheck bloqueia meta leak severo antes de onDone
            final partialSanitized = AiSmartRouter.sanitizeAndCheck(
              rawPartial,
              isPlantaoMode: !longResponse,
              appLanguage: _lang,
            );
            final partialText = partialSanitized.text;
            // HOTFIX 247D: nunca adicionar fallback ao histórico da API
            if (!_isFallbackText(partialText)) {
              _aiHistory
                ..add({'role': 'user',      'content': input})
                ..add({'role': 'assistant', 'content': partialText});
              while (_aiHistory.length > 20) _aiHistory.removeAt(0);
            } else if (kDebugMode) {
              debugPrint('[HISTORY_SANITIZER] partial_fallback_blocked reason=isFallbackText');
            }
            wrappedOnDone(partialText);   // BUILD 254
            return;
          }
          accumulator.clear();
          // Build 155.2: null-safe — errorCode pode ser null em chunks malformados
          final msg = GeminiServiceV2.errorMessage(errCode, _lang);
          wrappedOnError(msg);              // BUILD 254
          return;
        }

        if (chunk.text.isNotEmpty) {
          accumulator.write(chunk.text);
          onChunk(accumulator.toString()); // texto acumulado até agora
        }

        if (chunk.isDone && !chunk.isError) {
          // Resposta completa — dispara somente uma vez (guard anti-duplicata)
          if (completionFired) return;
          completionFired = true;
          _globalTimeoutTimer?.cancel(); // BUILD 241: cancela timer pois terminamos
          AppResumeCoordinator.instance.completeAiRequest(thisRequestId); // BUILD 241
          // BUILD 252: print do rawText ANTES de sanitizeAndCheck — expõe saída bruta.
          final rawText = accumulator.toString().trim();
          // ignore: avoid_print
          print('[RAW_AI_OUTPUT][FREE_STREAM] len=${rawText.length} '
              'requestId=$requestId mode=${longResponse ? "estudo" : "plantao"}');
          if (rawText.length < 100) {
            // ignore: avoid_print
            print('[RAW_AI_OUTPUT] ⚠️  ALERTA resposta curta do Free: "${rawText.length < 200 ? rawText : rawText.substring(0, 200)}"');
          }

          // ── MICRO-BUILD 462E-A.5.1: TruncationInspector HARD BARRIER ──────
          // Free stream path (Gemini Free / Layer 1).
          // Barrier runs BEFORE sanitizeAndCheck() and ANY persistence.
          // Modo Estudo: streaming provisional — no persistence before barrier.
          // ─────────────────────────────────────────────────────────────────
          String barrierText = rawText;
          try {
            final truncCheck = TruncationInspector.inspect(rawText);
            TruncationInspector.emitTelemetry(
              requestId: thisRequestId,
              result: truncCheck,
            );

            if (truncCheck.isTruncated &&
                truncCheck.confidenceLevel == TruncationConfidence.high) {
              // ignore: avoid_print
              print('[TRUNCATION_CHECK] BARRIER_TRIGGERED requestId=$thisRequestId '
                  'reason=${truncCheck.violationReason} '
                  'confidence=high → initiating repair (free_stream path)');

              final repairResult = await AiService.repairTruncated(
                originalText:  rawText,
                requestId:     thisRequestId,
                isPlantaoMode: !longResponse,
                appLanguage:   _lang,
              );

              if (!repairResult.isValid) {
                throw AiSafeOutputException(
                  message:   repairResult.failureReason ?? 'repair_failed',
                  requestId: thisRequestId,
                );
              }
              barrierText = repairResult.text;
              TruncationInspector.emitTelemetry(
                requestId: thisRequestId,
                result: truncCheck.withRepair(
                  retried: true,
                  fixed: repairResult.wasRepaired,
                ),
              );
            }

            // BUILD 232: sanitizeAndCheck — bloqueia meta leak severo antes de onDone.
            // Se isRecoverable=false, text já é o fallback clínico seguro.
            final sanitized = barrierText.isNotEmpty
                ? AiSmartRouter.sanitizeAndCheck(
                    barrierText,
                    isPlantaoMode: !longResponse,
                    appLanguage: _lang,
                  )
                : null;
            final finalText = sanitized?.text ?? barrierText;
            // HOTFIX 247D: nunca adicionar fallback ao histórico da API
            if (finalText.isNotEmpty && !_isFallbackText(finalText)) {
              _aiHistory
                ..add({'role': 'user',      'content': input})
                ..add({'role': 'assistant', 'content': finalText});
              while (_aiHistory.length > 20) _aiHistory.removeAt(0);
            } else if (kDebugMode && finalText.isNotEmpty && _isFallbackText(finalText)) {
              debugPrint('[HISTORY_SANITIZER] free_done_fallback_blocked reason=isFallbackText');
            }
            _aiStreamActive = false;
            aiChatProvider.setStreaming(false); // BUILD 326
            _aiStreamSub    = null;
            // MICRO-BUILD 462E-A.5.2: Rigid Transactional Termination Pyramid.
            // Persistence committed above ↑ → UI emitted → releaseDecision → completeAiRequest LAST.
            wrappedOnDone(finalText.isNotEmpty ? finalText : _lang == 'es'  // BUILD 254
                ? 'No pude generar una respuesta. ¿Puedes reformular? ⚕ Apoyo educacional.'
                : 'Não consegui gerar uma resposta. Pode reformular? ⚕ Apoio educacional.');
            // Release canonical decision cache entry (COMPLETED) — after UI emit.
            ExternalToolLinkEngine.releaseCanonicalDecision(
                requestId: thisRequestId, decision: canonicalDecision);
            // ResumeCoordinator.complete() — TERMINAL POSITION (last in pyramid).
            AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
          } on AiSafeOutputException catch (safeError) {
            // ── TERMINAL: DROP_PAYLOAD — free stream repair failure ───────────
            // ignore: avoid_print
            print('[TRUNCATION_CHECK] DROP_PAYLOAD — REPAIR CRITICAL FAILURE '
                'requestId=${safeError.requestId} '
                'reason=${safeError.message} '
                'path=free_stream');
            _aiStreamActive = false;
            aiChatProvider.setStreaming(false);
            _aiStreamSub    = null;
            // MICRO-BUILD 462E-A.5.2: UI first, then release, then completeAiRequest LAST.
            wrappedOnError(
              _lang == 'es'
                  ? 'Respuesta interrumpida (validación fallida). Intenta nuevamente. ⚕'
                  : 'Resposta interrompida (validação falhou). Tente novamente. ⚕',
            );
            ExternalToolLinkEngine.releaseCanonicalDecision(
                requestId: thisRequestId, decision: canonicalDecision);
            AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
          }
        }
      },
      onError: (e) async {
        // Erro de stream — descarta texto parcial mas PRESERVA histórico.
        // Build 111: um erro de rede não invalida as trocas anteriores bem-sucedidas.
        debugPrint('[sendAiMessage] stream error: $e');
        if (completionFired) return;
        completionFired = true;
        _globalTimeoutTimer?.cancel(); // BUILD 241: cancela timer pois terminamos
        _aiStreamActive = false;
        aiChatProvider.setStreaming(false); // BUILD 326
        _aiStreamSub    = null;
        accumulator.clear();   // descarta texto parcial — nunca exibir
        // MICRO-BUILD 462E-A.5.3: Fallback Isolation Contract.
        // await tryPaidFallback — if it returns true it has taken ownership of
        // wrappedOnDone/wrappedOnError + releaseDecision + completeAiRequest.
        // Only execute terminal sequence here when fallback returned false (stale/dropped).
        final fallbackHandled = await tryPaidFallback('stream_exception');
        if (!fallbackHandled) {
          // Fallback was stale-guarded or skipped — caller owns terminal events.
          // Build 226: both providers failed → instability message.
          wrappedOnError(
            _lang == 'es'
                ? 'Error de red en el asistente IA. Intenta nuevamente. ⚕'
                : 'Erro de rede no assistente IA. Tente novamente. ⚕',
          );
          ExternalToolLinkEngine.releaseCanonicalDecision(
              requestId: thisRequestId, decision: canonicalDecision);
          AppResumeCoordinator.instance.completeAiRequest(thisRequestId); // BUILD 241 — TERMINAL
        }
        // fallbackHandled == true → tryPaidFallback already called release + complete.
      },
      onDone: () {
        // onDone do StreamController — garante limpeza mesmo sem chunk isDone
        // O guard completionFired evita duplo disparo após chunk.isDone=true
        if (completionFired) {
          // Já tratado pelo listener — apenas limpeza silenciosa
          _aiStreamActive = false;
          aiChatProvider.setStreaming(false); // BUILD 326
          _aiStreamSub    = null;
          return;
        }
        completionFired = true;
        _globalTimeoutTimer?.cancel(); // BUILD 241
        AppResumeCoordinator.instance.completeAiRequest(thisRequestId); // BUILD 241
        final finalText = accumulator.toString().trim();
        // HOTFIX 247D: nunca adicionar fallback ao histórico da API
        if (finalText.isNotEmpty && !_isFallbackText(finalText)) {
          _aiHistory
            ..add({'role': 'user',      'content': input})
            ..add({'role': 'assistant', 'content': finalText});
          while (_aiHistory.length > 20) _aiHistory.removeAt(0);
          _aiStreamActive = false;
          aiChatProvider.setStreaming(false); // BUILD 326
          _aiStreamSub    = null;
          wrappedOnDone(finalText);   // BUILD 254
        } else if (finalText.isNotEmpty && _isFallbackText(finalText)) {
          // É texto de fallback — exibe na UI mas não entra no histórico da API
          if (kDebugMode) debugPrint('[HISTORY_SANITIZER] free_onDone_fallback_blocked reason=isFallbackText');
          _aiStreamActive = false;
          aiChatProvider.setStreaming(false); // BUILD 326
          _aiStreamSub    = null;
          wrappedOnDone(finalText);   // BUILD 254
        } else {
          // Stream fechou vazio — BUILD 432: tenta retry silencioso antes do paid fallback
          _aiStreamActive = false;
          aiChatProvider.setStreaming(false); // BUILD 326
          _aiStreamSub    = null;

          // BUILD 432 AUTO-RETRY: até 1 tentativa silenciosa (sem alterar UI)
          if (_freeStreamRetryCount < 1 && _activeRequestId == thisRequestId) {
            _freeStreamRetryCount++;
            completionFired = false; // permite novo disparo após retry
            accumulator.clear();     // limpa acumulador para resposta nova

            // Re-inicia streaming Free preservando estado de _thinking na UI
            // (aiChatProvider.setStreaming reativado para manter EcgLoadingBlock)
            if (kDebugMode) {
              debugPrint('[BUILD432][AUTO_RETRY] stream empty → retry '
                  '$_freeStreamRetryCount/1 requestId=$thisRequestId — '
                  'UI mantida em thinking, soluço de rede ocultado');
            }
            // ignore: avoid_print
            print('[BUILD432][AUTO_RETRY] empty_stream retry=$_freeStreamRetryCount '
                'requestId=$requestId');

            // Re-aciona stream Free via AiGatewayService (mesmo gateway do fluxo original)
            unawaited(() async {
              // Pequeno delay para deixar a rede respirar antes do retry
              await Future<void>.delayed(const Duration(milliseconds: 800));
              if (_activeRequestId != thisRequestId) {
                debugPrint('[BUILD432][AUTO_RETRY] requestId invalidado durante '
                    'delay → retry cancelado');
                return;
              }
              _aiStreamActive = true;
              aiChatProvider.setStreaming(true); // reativa indicador de streaming
              final retryStream = AiGatewayService.sendStream(
                userMessage:  input,
                systemPrompt: systemPrompt,
                apiKey:       geminiApiKey,
                history:      List<Map<String, String>>.from(_sanitizedHistory),
                useGrounding: true,
                longResponse: longResponse,
                appLanguage:  _lang,
              );
              _aiStreamSub = retryStream.listen(
                (chunk) {
                  if (!chunk.isError && chunk.text.isNotEmpty) {
                    accumulator.write(chunk.text);
                    onChunk(accumulator.toString());
                  }
                  if (chunk.isDone && !chunk.isError) {
                    if (completionFired) return;
                    completionFired = true;
                    _globalTimeoutTimer?.cancel();
                    AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
                    final retryText = accumulator.toString().trim();
                    // ignore: avoid_print
                    print('[BUILD432][AUTO_RETRY] done len=${retryText.length} '
                        'requestId=$requestId');
                    if (retryText.isNotEmpty && !_isFallbackText(retryText)) {
                      _aiHistory
                        ..add({'role': 'user',      'content': input})
                        ..add({'role': 'assistant', 'content': retryText});
                      while (_aiHistory.length > 20) _aiHistory.removeAt(0);
                      _aiStreamActive = false;
                      aiChatProvider.setStreaming(false);
                      _aiStreamSub = null;
                      wrappedOnDone(retryText);
                    } else {
                      // Retry também veio vazio → escala para paid
                      _aiStreamActive = false;
                      aiChatProvider.setStreaming(false);
                      _aiStreamSub = null;
                      debugPrint('[BUILD432][AUTO_RETRY] retry also empty → '
                          'escalando para paid fallback');
                      // MICRO-BUILD 462E-A.5.3: delegate terminal ownership to fallback.
                      // If fallback returns false (stale), emit instability msg and complete.
                      unawaited(() async {
                        final handled = await tryPaidFallback('empty_stream_after_retry');
                        if (!handled) {
                          wrappedOnError(_lang == 'es'
                              ? 'Estamos con inestabilidad temporal en la IA. Intenta nuevamente. ⚕'
                              : 'Estamos com instabilidade temporária na IA. Tente novamente. ⚕');
                          ExternalToolLinkEngine.releaseCanonicalDecision(
                              requestId: thisRequestId, decision: canonicalDecision);
                          AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
                        }
                      }());
                    }
                  }
                },
                onError: (_) async {
                  if (completionFired) return;
                  _aiStreamActive = false;
                  aiChatProvider.setStreaming(false);
                  _aiStreamSub = null;
                  // MICRO-BUILD 462E-A.5.3: await fallback; handle false (stale) case.
                  final handled = await tryPaidFallback('retry_stream_error');
                  if (!handled) {
                    wrappedOnError(_lang == 'es'
                        ? 'Error de red en el asistente IA. Intenta nuevamente. ⚕'
                        : 'Erro de rede no assistente IA. Tente novamente. ⚕');
                    ExternalToolLinkEngine.releaseCanonicalDecision(
                        requestId: thisRequestId, decision: canonicalDecision);
                    AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
                  }
                },
                onDone: () {
                  if (completionFired) {
                    _aiStreamActive = false;
                    aiChatProvider.setStreaming(false);
                    _aiStreamSub = null;
                    return;
                  }
                  // Retry onDone sem isDone chunk → paid fallback
                  completionFired = true;
                  _aiStreamActive = false;
                  aiChatProvider.setStreaming(false);
                  _aiStreamSub = null;
                  // MICRO-BUILD 462E-A.5.3: delegate to fallback; handle false (stale) case.
                  unawaited(() async {
                    final handled = await tryPaidFallback('empty_retry_onDone');
                    if (!handled) {
                      wrappedOnError(_lang == 'es'
                          ? 'Estamos con inestabilidad temporal en la IA. Intenta nuevamente. ⚕'
                          : 'Estamos com instabilidade temporária na IA. Tente novamente. ⚕');
                      ExternalToolLinkEngine.releaseCanonicalDecision(
                          requestId: thisRequestId, decision: canonicalDecision);
                      AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
                    }
                  }());
                },
                cancelOnError: false,
              );
            }());
          } else {
            // Esgotou retries → paid fallback
            if (kDebugMode) {
              debugPrint('[AI_ROUTER] stream closed empty (retry esgotado) → '
                  'paid fallback requestId=$thisRequestId');
            }
            // MICRO-BUILD 462E-A.5.3: delegate to fallback; handle false (stale) case.
            unawaited(() async {
              final handled = await tryPaidFallback('empty_stream');
              if (!handled) {
                wrappedOnError(_lang == 'es'
                    ? 'Estamos con inestabilidad temporal en la IA. Intenta nuevamente. ⚕'
                    : 'Estamos com instabilidade temporária na IA. Tente novamente. ⚕');
                ExternalToolLinkEngine.releaseCanonicalDecision(
                    requestId: thisRequestId, decision: canonicalDecision);
                AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
              }
            }());
          }
        }
      },
      cancelOnError: false,
    );

    // ── BUILD 238/241: cancela timer global ao concluir normalmente ───────
    // O timer é criado ANTES do listen() — cancela-o quando onDone/onError
    // disparam normalmente para evitar safe-card tardio.
    // NOTA: os callbacks internos já cancelam via completionFired=true.
    // O timer lê completionFired antes de agir, então é seguro.

    return true; // indica que usou streaming V2

    } // end try — Single-Flight Guard finally abaixo
    finally {
      // Build 134 — Single-Flight Guard: liberação no finally.
      //
      // DESIGN: o listen() registra callbacks e retorna imediatamente (Dart async).
      // Quando chegamos aqui no finally, o stream SSE ainda está em voo se a
      // chamada chegou até o listen(). Nesse caso, _aiStreamActive=true.
      //
      // REGRA: liberamos _aiCallInFlight IMEDIATAMENTE no finally.
      // Isso é seguro porque:
      //   1. O guard legado (_aiAnswerInProgress || _aiStreamActive) ainda bloqueia
      //      chamadas concorrentes enquanto o stream estiver ativo.
      //   2. O _aiCallInFlight serve para bloquear a JANELA entre o início da
      //      chamada e o registro do listen() — a parte mais crítica de race condition.
      //   3. Após o listen() estar registrado, o _aiStreamActive assume o controle.
      //
      // RESULTADO: proteção máxima na janela de setup + handoff limpo ao guard legado.
      _aiCallInFlight = false;
      // BUILD 241: se sendAiMessage() saiu pelo finally antes de registrar o
      // listen() (ex: exception no setup), o coordinator precisa ser limpo.
      // Se o stream ainda estiver ativo, o completeAiRequest virá pelo onDone/timeout.
      // Se _aiStreamActive=false aqui, o request já terminou ou falhou antes do listen.
      if (!_aiStreamActive) {
        AppResumeCoordinator.instance.completeAiRequest(thisRequestId);
      }
    }
  }

  Future<String> buildAIAnswer(String input) async {
    // Guard: rejeita chamada se já há uma em andamento (evita duplicação)
    if (_aiAnswerInProgress) {
      debugPrint('[buildAIAnswer] chamada ignorada — já há resposta em andamento');
      return '';
    }
    _aiAnswerInProgress = true;
    try {
      return await _buildAIAnswerImpl(input);
    } finally {
      _aiAnswerInProgress = false;
    }
  }

  Future<String> _buildAIAnswerImpl(String input) async {
    // ── strictContextIsolation — Passo A: detectar mudança de tema ────────
    // Deve ocorrer ANTES de montar o prompt. Ao mudar de tema:
    //   1. Memória clínica é resetada (sem dados do tema anterior)
    //   2. Retrieval RAG usa APENAS a query pura (sem expansão por histórico)
    //   Isso previne que blocos farmacológicos/clínicos de respostas anteriores
    //   contaminem o novo caso (ex: "Betametasona" aparecendo num caso de TEP).
    // Build 111: igual sendAiMessage — preserva _aiHistory em topicReset.
    final topicReset = _sessionMemory.resetIfTopicChanged(input);
    // BUILD 249: ClinicalThreadManager — decide continuar ou iniciar novo thread.
    // buildAIAnswer é sempre Modo Plantão (isPlantaoMode=true).
    final threadStatusAnswer = _threadManager.evaluate(
      currentUserText: input,
      isPlantaoMode: true,
    );
    if (threadStatusAnswer.action == ThreadAction.newThread) {
      // BUILD 250: HARD RESET síncrono — ocorre ANTES da montagem do systemPrompt.
      final removed = _aiHistory.length;
      _aiHistory.clear();           // contexto Gemini → zero
      _sessionMemory.reset();       // memória clínica → zero (reset duplo seguro)
      debugPrint('[HISTORY_SANITIZER] HARD RESET ATIVADO: Limpando _aiHistory de forma absoluta. '
          'mode=plantao '
          'strategy=empty sent=0 removed=$removed '
          'reason=${threadStatusAnswer.reason}');
    }

    // ── Passo 0: globalLanguageLock — bloqueia idioma da sessão ──────────────
    // Detecta idioma da primeira mensagem e bloqueia para toda a sessão.
    // O prompt é sempre gerado no idioma detectado/bloqueado, nunca misturado.
    final sessionLang = _resolveSessionLang(input);

    // ── Passo 1: Classificar intent ────────────────────────────────────────
    final intent = _classifyIntent(input);

    // strictContextIsolation — Passo B: retrieval isolado por tema
    // Se houve mudança de tema, usa SOMENTE a query pura para o retrieval
    // (sem _expandedQuery que usa histórico do tema anterior e polui RAG).
    // Se mesmo tema, mantém expansão para melhor recall.
    final expandedInput = topicReset ? input : _expandedQuery(input);
    final normalized    = _normalize(expandedInput);

    // ── Passo 2: Retrieval de protocolos (BUILD 325: drug RAG removido) ──────
    final _extP = _matchProtocolsExtended(normalized);
    final finalProtocols = _extP.isNotEmpty ? _extP : _matchProtocols(normalized);

    // RAG telemetry — visível apenas em kDebugMode
    if (kDebugMode) {
      debugPrint('[RAG] intent=$intent | protocols=${finalProtocols.length}');
      if (finalProtocols.isNotEmpty) debugPrint('[RAG] protocols: ${finalProtocols.map((p) => p.substring(0, p.length.clamp(0, 60))).toList()}');
    }

    // ── Passo 3: Análise local estruturada ────────────────────────────────
    final localContext = _buildLocalAnswer(input);

    const String? proprietaryContextAnswer = null;

    // ── Passo 4: System prompt RAG completo ───────────────────────────────
    // Passa userQuery explicitamente para que o RAG Relevance Gate no
    // ai_service.dart filtre protocolos/fármacos/contexto por relevância
    // temática, evitando contaminação cruzada (ex: otite → ICFEr).
    // Build 104 — isFirstMessage: mesma lógica do sendAiMessage().
    // _aiHistory já foi limpo por resetIfTopicChanged() acima quando o tema
    // muda. isEmpty=true na 1ª mensagem da sessão OU no 1º turno de novo tópico.
    final systemPrompt = AiService.buildClinicalSystemPrompt(
      lang: sessionLang,   // ← globalLanguageLock: idioma bloqueado da sessão
      matchedProtocolSummaries: finalProtocols,
      matchedDrugSummaries: const [],
      localAnswerContext: localContext,
      queryIntent: intent,
      patientAge: _patient.age.isNotEmpty ? _patient.age : null,
      patientSex: _patient.sex.isNotEmpty ? _patient.sex : null,
      patientWeight: _patient.weight.isNotEmpty ? _patient.weight : null,
      patientClcr: clcr,
      patientMedications: _patient.medications.isNotEmpty ? _patient.medications : null,
      userQuery: input,
      memory: _sessionMemory,
      isFirstMessage: _aiHistory.isEmpty,
      isPlantaoMode: true,
      proprietaryDrugContext: proprietaryContextAnswer,
    );

    // BUILD 253: log do tamanho real do systemPrompt no caminho buildAIAnswer.
    final _spCharsAns = systemPrompt.length;
    final _spTokensApproxAns = (_spCharsAns / 4).round();
    print('[SYSTEM_PROMPT_AUDIT][buildAIAnswer] '
        'systemPromptChars=$_spCharsAns systemPromptTokensApprox=$_spTokensApproxAns');
    if (_spTokensApproxAns > 6000) {
      print('[SYSTEM_PROMPT_AUDIT] ⚠️  ALERTA buildAIAnswer: systemPrompt acima de 6000 tokens '
          '(approx=$_spTokensApproxAns) — risco de Context Dilution.');
    }

    // ── Passo 5: Gemini (prioridade) com Google Search Grounding ──────────
    // Build 156.2: usa Gemini sempre que a chave do app estiver disponível,
    // independente de _geminiConnected (OAuth de conta Google do usuário).
    // A chave é do APP (admin → Firestore), não do usuário individual.
    // _geminiConnected = flag de OAuth legada; GeminiService.hasApiKey = real.
    if (_geminiConnected || GeminiService.hasApiKey) {
      // Garante API Key presente antes de chamar — pode ter sido perdida por reload
      if (!GeminiService.hasApiKey) {
        debugPrint('[buildAIAnswer] API Key ausente — recuperando automaticamente...');
        try {
          final geminiKey = await FirestoreService.loadGeminiApiKey()
              .timeout(const Duration(seconds: 5));
          if (geminiKey.isNotEmpty) {
            GeminiService.setGeminiApiKey(geminiKey, source: GeminiKeySource.appConfig); // BUILD 294
            debugPrint('[buildAIAnswer] API Key recarregada do Firestore ✓');
          } else {
            // Firestore vazio — SharedPreferences é o fallback primário (sem dart:js/eval)
            await GeminiService.initFromStorage();
            if (GeminiService.hasApiKey) {
              debugPrint('[buildAIAnswer] API Key restaurada do SharedPrefs ✓');
            }
          }
        } catch (e) {
          debugPrint('[buildAIAnswer] Firestore falhou: $e — tentando SharedPrefs...');
          await GeminiService.initFromStorage();
          if (GeminiService.hasApiKey) {
            debugPrint('[buildAIAnswer] API Key restaurada do SharedPrefs (fallback) ✓');
          }
        }
      }

      final geminiResult = await GeminiService.chat(
        userMessage: input,
        systemPrompt: systemPrompt,
        // BUILD 249: thread-filtered history — empty on new case, minimal on continuation
        history: List.unmodifiable(ClinicalThreadManager.buildThreadHistory(
          fullHistory: _sanitizedHistory,
          status: threadStatusAnswer,
          isPlantaoMode: true, // buildAIAnswer is always Plantão mode
        )),
        maxTokens: 2200,  // Token base elevado — retry automático até 4000 se truncar
        useGrounding: true,
      );

      if (!geminiResult.isError) {
        // HOTFIX 247D: nunca adicionar fallback ao histórico da API
        if (!_isFallbackText(geminiResult.text)) {
          _aiHistory
            ..add({'role': 'user', 'content': input})
            ..add({'role': 'assistant', 'content': geminiResult.text});
          while (_aiHistory.length > 20) _aiHistory.removeAt(0);
        } else if (kDebugMode) {
          debugPrint('[HISTORY_SANITIZER] buildAIAnswer_fallback_blocked reason=isFallbackText');
        }
        return geminiResult.text;
      }

      // Gemini falhou — logar o erro para diagnóstico
      debugPrint('[buildAIAnswer] Gemini ERRO: code=${geminiResult.errorCode} text=${geminiResult.text.substring(0, geminiResult.text.length.clamp(0, 100))}');

      // Build 126 — TOLERÂNCIA A FALHAS DE FORMATO:
      // Se o Gemini retornou texto bruto mesmo com isError=true (ex: formato
      // inesperado, SAFETY parcial mas com conteúdo válido, ou erro de parsing
      // interno), exibir o texto bruto é sempre melhor que a mensagem de contingência.
      // A mensagem de contingência só é reservada para falhas de rede reais
      // (timeout, HTTP 500, api_key_invalid, quota) — sem payload textual.
      final rawContent = geminiResult.text.trim();
      final hasUsableRawContent = rawContent.length > 20 &&
          !rawContent.startsWith('CONTEXTO_') &&
          !rawContent.startsWith('INSTRUCAO_') &&
          !rawContent.startsWith('INSTRUCCION_');

      if (hasUsableRawContent) {
        // Texto bruto com conteúdo real → exibir diretamente, sem contingência.
        // HOTFIX 247D: nunca adicionar fallback ao histórico da API
        if (!_isFallbackText(rawContent)) {
          _aiHistory
            ..add({'role': 'user',      'content': input})
            ..add({'role': 'assistant', 'content': rawContent});
          while (_aiHistory.length > 20) _aiHistory.removeAt(0);
        } else if (kDebugMode) {
          debugPrint('[HISTORY_SANITIZER] buildAIAnswer_rawContent_blocked reason=isFallbackText');
        }
        return rawContent;
      }

      final localFallback = _buildLocalAnswer(input);
      // Se o contexto local tem conteúdo médico real (FASE 0/1/2a/2b/3) → exibir
      // Se é contexto interno técnico (FASE 2e/2f) → mostrar mensagem amigável
      final isInternalContext = localFallback.startsWith('CONTEXTO_INTERNO') ||
          localFallback.startsWith('INSTRUCAO_INTERNA') ||
          localFallback.startsWith('INSTRUCCION_INTERNA');

      // Build 156: null-safe switch — errorCode é String? e pode ser null
      // em chunks malformados. Usar ?? 'unknown' garante que o switch sempre
      // caia em um case conhecido, eliminando risco de Null check operator.
      switch (geminiResult.errorCode ?? 'unknown') {
        case 'api_key_invalid':
          // Build 156.2: o médico não configura API — mensagem genérica de erro temporário.
          // Se a chave do app (admin/Firestore) estiver inválida, sair silenciosamente.
          return _lang == 'es'
              ? 'No se pudo conectar al asistente clínico. Intenta nuevamente en unos instantes. ⚕ Apoyo educacional.'
              : 'Não foi possível conectar ao assistente clínico. Tente novamente em instantes. ⚕ Apoio educacional.';
        case 'quota':
          return _lang == 'es'
              ? 'Límite de consultas alcanzado. Intenta nuevamente en unos minutos. ⚕ Apoyo educacional.'
              : 'Limite de consultas atingido. Tente novamente em alguns minutos. ⚕ Apoio educacional.';
        case 'timeout':
        case 'network':
          // Falha de rede real — contingência justificada
          return _lang == 'es'
              ? 'Sin conexión. Verifica tu red e intenta nuevamente. ⚕ Apoyo educacional.'
              : 'Sem conexão. Verifique sua rede e tente novamente. ⚕ Apoio educacional.';
        case 'blocked':
          // SAFETY: sem texto gerado → localFallback ou mensagem mínima
          return isInternalContext
              ? (_lang == 'es'
                  ? 'No pude procesar esa consulta. ¿Puedes reformularla con más contexto clínico? ⚕ Apoyo educacional.'
                  : 'Não consegui processar essa consulta. Pode reformulá-la com mais contexto clínico? ⚕ Apoio educacional.')
              : localFallback;
        default:
          // Erro desconhecido ou null → localFallback (conteúdo médico local)
          return isInternalContext
              ? (_lang == 'es'
                  ? 'No pude procesar esa consulta. ¿Puedes reformularla con más contexto clínico? ⚕ Apoyo educacional.'
                  : 'Não consegui processar essa consulta. Pode reformulá-la com mais contexto clínico? ⚕ Apoio educacional.')
              : localFallback;
      }
    }

    // ── Passo 6: OpenAI (legado) ───────────────────────────────────────────
    // Build 156.2: se chegou aqui sem Gemini disponível, tenta OpenAI legada.
    // Fallback silencioso — sem mensagem de erro visível ao médico.
    if (_openAiKey.isEmpty) {
      final localFallback = _buildLocalAnswer(input);
      final isInternalContext = localFallback.startsWith('CONTEXTO_INTERNO') ||
          localFallback.startsWith('INSTRUCAO_INTERNA') ||
          localFallback.startsWith('INSTRUCCION_INTERNA');
      return isInternalContext
          ? (_lang == 'es'
              ? 'Hola. Puedo ayudarte con protocolos, fármacos y casos clínicos. ⚕ Apoyo educacional.'
              : 'Olá. Posso ajudar com protocolos, fármacos e casos clínicos. ⚕ Apoio educacional.')
          : localFallback;
    }

    final result = await AiService.chat(
      apiKey: _openAiKey,
      userMessage: input,
      systemPrompt: systemPrompt,
      // BUILD 249: thread-filtered history — empty on new case, minimal on continuation
      history: List.unmodifiable(ClinicalThreadManager.buildThreadHistory(
        fullHistory: _sanitizedHistory,
        status: threadStatusAnswer,
        isPlantaoMode: true, // buildAIAnswer is always Plantão mode
      )),
      maxTokens: 1100,  // Passo 6 OpenAI legado — mesmo limite do Gemini
    );

    if (result.isError) {
      // Build 156: null-safe switch — errorCode é String? no AiResult também
      switch (result.errorCode ?? 'unknown') {
        case 'invalid_key':
          return _lang == 'es'
              ? 'Clave de API inválida. Verifica la configuración en el menú. ⚕ Apoyo educacional.'
              : 'Chave de API inválida. Verifique a configuração no menu. ⚕ Apoio educacional.';
        case 'quota':
          return _lang == 'es'
              ? 'Límite de API alcanzado. Intenta nuevamente más tarde. ⚕ Apoyo educacional.'
              : 'Limite de API atingido. Tente novamente mais tarde. ⚕ Apoio educacional.';
        default: {
          final localFallback = _buildLocalAnswer(input);
          final isInternalContext = localFallback.startsWith('CONTEXTO_INTERNO') ||
              localFallback.startsWith('INSTRUCAO_INTERNA') ||
              localFallback.startsWith('INSTRUCCION_INTERNA');
          return isInternalContext
              ? (_lang == 'es'
                  ? 'No pude procesar esa consulta. ¿Puedes reformularla con más contexto clínico? ⚕ Apoyo educacional.'
                  : 'Não consegui processar essa consulta. Pode reformulá-la com mais contexto clínico? ⚕ Apoio educacional.')
              : localFallback;
        }
      }
    }

    // HOTFIX 247D: nunca adicionar fallback ao histórico da API
    if (!_isFallbackText(result.text)) {
      _aiHistory
        ..add({'role': 'user', 'content': input})
        ..add({'role': 'assistant', 'content': result.text});
      while (_aiHistory.length > 20) _aiHistory.removeAt(0);
    } else if (kDebugMode) {
      debugPrint('[HISTORY_SANITIZER] openai_result_blocked reason=isFallbackText');
    }
    return result.text;
  }

  // ── Retrieval estendido: retorna até 6 protocolos (para casos complexos) ──
  List<String> _matchProtocolsExtended(String normalizedQuery) {
    const _highRiskIds = {
      'avc_hemorragico', 'avc_isquemico', 'pcr_adulto', 'choque_cardiogenico',
      'hsa', 'meningite', 'sepse', 'iam_congestao', 'tep', 'status_epilepticus',
      'eclampsia_hellp', 'hiponatremia_grave', 'intox_monoxido_carbono',
      'caso_enxaqueca_aura', 'gripe_influenza_010',
      'agitacao_psicomotriz', 'agitacion_psicom', 'psicose_aguda', 'psicosis_aguda',
      'esquizofrenia', 'bipolar', 'delirium', 'abstinencia_alcool',
    };
    final results = <String>[];

    final allWords = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .toList();

    // Fix 2: sem palavra clínica substantiva → sem retrieval
    if (!_hasSubstantiveWord(allWords)) return [];

    // Apenas palavras não-genéricas participam do match
    final words = allWords
        .where((w) => !_clinicalStopwords.contains(w))
        .toList();

    if (words.isEmpty) return [];

    for (final p in protocolsDatabase) {
      final title    = _normalize(tDB(p.title));
      final recognize = _normalize(tDB(p.recognize));
      final matchCount = words.where((w) => title.contains(w) || recognize.contains(w)).length;
      final isHighRisk = _highRiskIds.any((id) => p.id.contains(id));
      final minScore   = isHighRisk ? 2 : 1;
      if (matchCount >= minScore) {
        final actions = p.getActions(_lang).take(4).join(' | ');
        // Extrai trecho da definition para contexto clínico adicional
        final defRaw = tDB(p.definition);
        final defExcerpt = defRaw.isNotEmpty
            ? defRaw.substring(0, defRaw.length.clamp(0, 160))
            : '';
        final defLine = defExcerpt.isNotEmpty ? '\n  Contexto: $defExcerpt...' : '';
        results.add(
          '• [${tDB(p.title)}]\n'
          '  Reconhecer: ${tDB(p.recognize).substring(0, tDB(p.recognize).length.clamp(0, 180))}...$defLine\n'
          '  Conduta: $actions'
        );
        if (results.length >= 6) break;
      }
    }
    return results;
  }


  /// Resposta local (rule-based) enriquecida — serve como contexto RAG para o Gemini
  /// e como fallback autônomo quando não há IA disponível.
  ///
  /// ARQUITETURA:
  ///   FASE 1 — Sistema de pontuação por condição clínica (29 condições)
  ///   FASE 2 — Lógica contextual para queries sem match direto
  ///   FASE 3 — Render enriquecido: diferenciais, tratamento estruturado, doses, diretrizes
  ///   (BUILD 325: FASE 0 removida — fármacos via Google Search Grounding + WebView)
  ///
  /// OUTPUT: contexto estruturado markdown que o Gemini usa para gerar resposta final.
  String _buildLocalAnswer(String input) {
    final bool es = _lang == 'es';

    // ── Contexto do histórico (follow-up) ────────────────────────────────────
    final recentUserMsgs = _aiHistory
        .where((m) => m['role'] == 'user')
        .map((m) => m['content'] ?? '')
        .toList();
    final historyTail = recentUserMsgs.length > 6
        ? recentUserMsgs.sublist(recentUserMsgs.length - 6)
        : recentUserMsgs;
    final qHistory  = _normalize(historyTail.join(' '));
    final qExpanded = _normalize('$qHistory $input');
    final q         = _normalize(input);

    // ════════════════════════════════════════════════════════════════════════
    // FASE 1 — SISTEMA DE PONTUAÇÃO POR CONDIÇÃO
    //
    // Cada condição tem uma lista de keywords específicas.
    // Score = nº de keywords encontradas em q (mensagem atual).
    // Condições com score 0 são descartadas.
    // Apenas a condição de maior score é renderizada.
    // Em caso de empate, a primeira na lista de prioridade vence.
    // ════════════════════════════════════════════════════════════════════════

    // Estrutura: (id, label, protocolId, keywords, exams, redFlags)
    final conditions = <_CliCondition>[

      // ── PCR / Parada (prioridade máxima) ─────────────────────────────────
      _CliCondition(
        id: 'pcr',
        label: es ? 'Parada Cardiorrespiratoria / PCR' : 'Parada Cardiorrespiratória / PCR',
        protocolId: 'pcr_adulto',
        keywords: ['pcr', 'parada cardiac', 'sem pulso', 'fv ', 'fibrilac ventr', 'tv sem pulso', 'reanimac', 'acls'],
        exams: ['Monitor/desfibrilador', 'Glicemia pós-ROSC', 'Gasometria pós-ROSC', 'ECG pós-ROSC'],
        flags: [es ? 'ACLS inmediato: RCP + desfibrilación' : 'ACLS imediato: RCP de alta qualidade + desfibrilação',
                es ? 'Adrenalina 1 mg IV cada 3–5 min' : 'Adrenalina 1 mg IV cada 3–5 min'],
        differentials: es
            ? ['FV/TVSP (desfibrilable)', 'AESP (no desfibrilable)', 'Asistolia', 'Causas 5H5T (hipoxia, hipovolemia, hipotermia, hipo/hiperpotasemia, hidrogenión, tensión neumotórax, taponamiento, trombosis, tóxicos)']
            : ['FV/TVSP (desfibrilável)', 'AESP (não desfibrilável)', 'Assistolia', 'Causas 5H5T (hipóxia, hipovolemia, hipotermia, hipo/hipercalemia, íon H+, tensão pneumotórax, tamponamento, trombose, tóxicos)'],
        treatment: es
            ? ['1. RCP de alta calidad: 30:2, profundidad 5-6 cm, frecuencia 100-120/min', '2. Desfibrilar FV/TVSP: 200J bifásico inmediatamente', '3. Adrenalina 1 mg IV cada 3-5 min (desde el 2º ciclo en no desfibrilables)', '4. Amiodarona 300 mg IV en FV/TVSP refractaria (2ª dosis: 150 mg)', '5. Identificar y corregir causas reversibles (5H5T)', '6. Cuidados post-ROSC: normoxia, normocapnia, hipotermia terapéutica']
            : ['1. RCP de alta qualidade: 30:2, profundidade 5-6 cm, frequência 100-120/min', '2. Desfibrilar FV/TVSP: 200J bifásico imediatamente', '3. Adrenalina 1 mg IV a cada 3-5 min (a partir do 2º ciclo em não desfibriláveis)', '4. Amiodarona 300 mg IV em FV/TVSP refratária (2ª dose: 150 mg)', '5. Identificar e corrigir causas reversíveis (5H5T)', '6. Cuidados pós-ROSC: normóxia, normocapnia, hipotermia terapêutica'],
        guidelines: ['AHA ACLS 2020', 'ILCOR 2020', 'ERC 2021'],
      ),

      // ── Choque ────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'choque',
        label: es ? 'Choque (cardiogénico / séptico / hipovolémico)' : 'Choque (cardiogênico / séptico / hipovolêmico)',
        protocolId: 'choque_cardiogenico',
        keywords: ['hipotens', 'choque', 'pele fria', 'oliguria', 'lactato', 'hipoperfus', 'extremid frias', 'pam ', 'vasopressor'],
        exams: [es ? 'Lactato arterial' : 'Lactato arterial', 'Gasometria', 'ECG', es ? 'Ecocardiograma a pie de cama' : 'Ecocardiograma beira-leito'],
        flags: [es ? 'PAM <65 → vasopresor inmediato' : 'PAM <65 → vasopressor imediato',
                es ? 'Lactato >4 → reanimación 30 mL/kg' : 'Lactato >4 → reanimação agressiva 30 mL/kg'],
        differentials: es
            ? ['Choque séptico (fiebre, foco infeccioso)', 'Choque cardiogénico (IC, IAM)', 'Choque hipovolémico (hemorragia, deshidratación)', 'Choque distributivo (anafilaxia, neurológico)', 'Choque obstructivo (TEP masivo, taponamiento)']
            : ['Choque séptico (febre, foco infeccioso)', 'Choque cardiogênico (IC, IAM)', 'Choque hipovolêmico (hemorragia, desidratação)', 'Choque distributivo (anafilaxia, neurogênico)', 'Choque obstrutivo (TEP maciço, tamponamento)'],
        treatment: es
            ? ['1. Establecer acceso IV/IO y monitor contínuo', '2. Lactato >4: reanimación con SF 30 mL/kg en 3h', '3. PAM <65 refractaria a volumen: noradrenalina 0,1-3 mcg/kg/min', '4. Choque cardiogénico: dobutamina 5-20 mcg/kg/min + furosemida si congestión', '5. Choque séptico: antibiótico en <1h + hemocultivos', '6. Meta: PAM ≥65, diuresis >0,5 mL/kg/h, lactato decrescente']
            : ['1. Acesso IV/IO + monitor contínuo', '2. Lactato >4: SF 30 mL/kg em 3h', '3. PAM <65 refratária a volume: noradrenalina 0,1-3 mcg/kg/min', '4. Choque cardiogênico: dobutamina 5-20 mcg/kg/min + furosemida se congestão', '5. Choque séptico: antibiótico em <1h + hemoculturas', '6. Meta: PAM ≥65, diurese >0,5 mL/kg/h, lactato decrescente'],
        guidelines: ['Surviving Sepsis Campaign 2021', 'AHA Cardiogenic Shock 2022', 'ESICM 2023'],
      ),

      // ── IAM / SCA ─────────────────────────────────────────────────────────
      _CliCondition(
        id: 'iam',
        label: es ? 'Síndrome Coronario Agudo (IAM/Angina)' : 'Síndrome Coronariana Aguda (IAM/Angina)',
        protocolId: 'iam_congestao',
        keywords: ['dor torac', 'peito', 'iam', 'infarto', 'angina', 'stemi', 'nstemi', ' sca ', 'troponina', 'supradesnivel', 'sindrome coron'],
        // NOTA: ' sca ' com espaços evita falso positivo em "brusca" (bru|sca)
        exams: [es ? 'ECG seriado (0–6–12h)' : 'ECG seriado (0–6–12h)', es ? 'Troponina (0–3h)' : 'Troponina (0–3h)', 'RX tórax', es ? 'Glucemia' : 'Glicemia'],
        flags: [es ? 'Supradesnivel ST → cateterismo urgente' : 'Supradesnivelamento ST → cateterismo urgente',
                es ? 'Hipotensión → choque cardiogénico' : 'Hipotensão → choque cardiogênico'],
        differentials: es
            ? ['IAMCSST (supradesnivel ST, reperfusión urgente)', 'IAMSEST/AI (troponina + sin supra)', 'Disección aórtica (dolor desgarrador, asimetría PA)', 'Pericarditis (mejora sentado, roce)', 'TEP (disnea, hipoxia, S1Q3T3)', 'Espasmo esofágico (alivia con nitrato)']
            : ['IAMCSST (supradesnivelamento ST, reperfusão urgente)', 'IAMSEST/AI (troponina + sem supra)', 'Dissecção aórtica (dor dilacerante, assimetria PA)', 'Pericardite (melhora sentado, atrito)', 'TEP (dispneia, hipóxia, S1Q3T3)', 'Espasmo esofágico (alivia com nitrato)'],
        treatment: es
            ? ['1. IAMCSST: AAS 300 mg + clopidogrel/ticagrelor + heparina → cateterismo en <90 min', '2. IAMSEST alto riesgo: AAS 300 mg + ticagrelor 180 mg + bivalirudina → cath en <24h', '3. Morfina 2-4 mg IV si dolor intenso (con precaución — puede reducir absorción antiagregantes)', '4. Nitratos: isosorbida SL o IV si PA >100 (contraindicado en IAM de VD e hipotensión)', '5. Betabloqueantes VO en ausencia de IC aguda/bradicardia', '6. Killip II-IV: furosemida 40 mg IV + VNI si EAP']
            : ['1. IAMCSST: AAS 300 mg + clopidogrel/ticagrelor + heparina → cateterismo em <90 min', '2. IAMSEST alto risco: AAS 300 mg + ticagrelor 180 mg + bivalirudina → cath em <24h', '3. Morfina 2-4 mg IV se dor intensa (cautela — pode reduzir absorção dos antiplaquetários)', '4. Nitratos: isossorbida SL ou IV se PA >100 (contraindicado em IAM de VD e hipotensão)', '5. Betabloqueadores VO na ausência de IC aguda/bradicardia', '6. Killip II-IV: furosemida 40 mg IV + VNI se EAP'],
        guidelines: ['ESC NSTEMI 2023', 'ESC STEMI 2023', 'AHA/ACC NSTE-ACS 2021'],
      ),

      // ── TEP ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'tep',
        label: es ? 'Tromboembolismo Pulmonar (TEP)' : 'Tromboembolismo Pulmonar (TEP)',
        protocolId: 'tep_agudo',
        keywords: ['tep', 'tromboembol pulm', 'embolia pulm', 'tvp', 'wells', 'd-dimero', 'angiotc torac'],
        exams: [es ? 'D-dímero (si baja probabilidad)' : 'D-dímero (se baixa probabilidade)', es ? 'AngioTC tórax' : 'AngioTC tórax', 'ECG (S1Q3T3)', 'Troponina', 'Score de Wells'],
        flags: [es ? 'Choque/hipotensión → trombolítico sistémico urgente' : 'Choque/hipotensão → trombolítico sistêmico urgente'],
        differentials: es
            ? ['Neumonía/pleuritis (fiebre, crepitantes)', 'IAM/Angina (ECG, troponina)', 'Neumotórax (timpanismo, ausencia de MV)', 'Pericarditis aguda', 'EPOC exacerbado', 'Ansiedad/hiperventilación']
            : ['Pneumonia/pleurite (febre, crepitações)', 'IAM/Angina (ECG, troponina)', 'Pneumotórax (timpanismo, ausência MV)', 'Pericardite aguda', 'DPOC exacerbado', 'Ansiedade/hiperventilação'],
        treatment: es
            ? ['1. TEP masivo (choque): trombólisis alteplase 100 mg IV en 2h (o 0,6 mg/kg em 15 min en PCR)', '2. TEP submasivo (disfunción VD): anticoagulación enoxaparina 1 mg/kg SC c/12h o rivaroxabán 15 mg 2×/día ×21 días', '3. TEP leve: rivaroxabán 15 mg 2×/día ×21 días → 20 mg/día, o apixabán 10 mg 2×/día ×7 días → 5 mg 2×/día', '4. Contraindicación DOAC: heparina + warfarina (INR 2-3)', '5. O2 si SpO2 <94%, vasopresores si hipotensión', '6. Filtro VCI solo si anticoagulación contraindicada']
            : ['1. TEP maciço (choque): trombolítico alteplase 100 mg IV em 2h (ou 0,6 mg/kg em 15 min em PCR)', '2. TEP submaciço (disfunção VD): anticoagulação enoxaparina 1 mg/kg SC 12/12h ou rivaroxabana 15 mg 2×/dia ×21 dias', '3. TEP leve: rivaroxabana 15 mg 2×/dia ×21 dias → 20 mg/dia, ou apixabana 10 mg 2×/dia ×7 dias → 5 mg 2×/dia', '4. Contraindicação DOAC: heparina + warfarina (INR 2-3)', '5. O2 se SpO2 <94%, vasopressores se hipotensão', '6. Filtro de VCI só se anticoagulação contraindicada'],
        guidelines: ['ESC TEP 2019', 'ACCP VTE 2021', 'AHA PE 2023'],
      ),

      // ── FA / Flutter ──────────────────────────────────────────────────────
      _CliCondition(
        id: 'fa',
        label: es ? 'Fibrilación Auricular / Flutter' : 'Fibrilação Atrial / Flutter Atrial',
        protocolId: 'fa_aguda',
        keywords: ['fa ', 'fibrilac atrial', 'fibril atri', 'auricular', 'rr irregular', 'flutter', 'fibrilacao', 'cardioversao', 'anticoag'],
        exams: [es ? 'ECG 12 derivaciones' : 'ECG 12 derivações', 'TSH', es ? 'Electrolitos (K+, Mg2+)' : 'Eletrólitos (K+, Mg2+)', 'Ecocardiograma', es ? 'Score CHA₂DS₂-VASc' : 'Score CHA₂DS₂-VASc'],
        flags: [es ? 'FC >150 + inestabilidad → cardioversión eléctrica inmediata' : 'FC >150 + instabilidade → cardioversão elétrica imediata',
                es ? 'FA >48h sin anticoagulación → riesgo de AVC' : 'FA >48h sem anticoagulação → risco de AVC por trombo'],
        differentials: es
            ? ['Flutter auricular (ondas F en dientes de sierra, conducción 2:1/3:1)', 'TSV (QRS estrecho regular)', 'TV (QRS ancho, no responde a maniobras vagales)', 'WPW (FA preexcitada: PELIGRO con digoxina/verapamilo)']
            : ['Flutter atrial (ondas F em dentes de serra, condução 2:1/3:1)', 'TSV (QRS estreito regular)', 'TV (QRS largo, não responde a manobras vagais)', 'WPW (FA pré-excitada: PERIGO com digoxina/verapamil)'],
        treatment: es
            ? ['1. Inestable (hipotensión/síncope/EAP): cardioversión eléctrica sincronizada 120-200J', '2. Estable con FC >110: control de FC — metoprolol 2,5-5 mg IV o diltiazem 0,25 mg/kg IV', '3. FA <48h: cardioversión farmacológica — amiodarona 150 mg IV en 10 min → 1 mg/min 6h', '4. FA >48h o desconocida: anticoagular 3 semanas ANTES de cardiovertir (o ETE para descartar trombo)', '5. Anticoagulación crónica: CHA₂DS₂-VASc ≥2 (♂) o ≥3 (♀) → DOAC (rivaroxabán/apixabán/dabigatrán)', '6. Control de FC crónica: betabloqueante (metoprolol/carvedilol) o diltiazem']
            : ['1. Instável (hipotensão/síncope/EAP): cardioversão elétrica sincronizada 120-200J', '2. Estável com FC >110: controle da FC — metoprolol 2,5-5 mg IV ou diltiazem 0,25 mg/kg IV', '3. FA <48h: cardioversão farmacológica — amiodarona 150 mg IV em 10 min → 1 mg/min 6h', '4. FA >48h ou desconhecida: anticoagular 3 semanas ANTES de cardioverter (ou ETE para excluir trombo)', '5. Anticoagulação crônica: CHA₂DS₂-VASc ≥2 (♂) ou ≥3 (♀) → DOAC (rivaroxabana/apixabana/dabigatrana)', '6. Controle da FC crônica: betabloqueador (metoprolol/carvedilol) ou diltiazem'],
        guidelines: ['ESC FA 2020', 'AHA/ACC/HRS Afib 2023', 'SBC FA 2022'],
      ),

      // ── IC / EAP ──────────────────────────────────────────────────────────
      _CliCondition(
        id: 'ic',
        label: es ? 'Insuficiencia Cardíaca Descompensada / EAP' : 'Insuficiência Cardíaca Descompensada / EAP',
        protocolId: 'iam_congestao',
        keywords: ['ic ', 'insuf cardiac', 'ortopneia', 'edema pulm', 'crepitac', 'bnp', 'fej', 'frac ejec', 'congest', 'crepit', 'b3 ', 'killip'],
        exams: ['BNP/NT-proBNP', 'RX tórax', 'Ecocardiograma', es ? 'Electrolitos' : 'Eletrólitos', es ? 'Función renal' : 'Função renal'],
        flags: [es ? 'SpO2 <90% → VNI (CPAP/BIPAP) inmediata' : 'SpO2 <90% + esforço respiratório → VNI (CPAP/BIPAP) imediata',
                es ? 'Hipotensión + IC → choque cardiogénico' : 'Hipotensão + IC → choque cardiogênico: cuidado com diurético'],
        differentials: es
            ? ['EPOC exacerbado (historia de tabaquismo, sibilancias)', 'TEP (D-dímero, angioTC)', 'Neumonía (fiebre, infiltrado asimétrico)', 'Crisis hipertensiva (PA muy elevada sin congestión previa)', 'Taponamiento cardíaco (JVD, ruidos apagados, hipotensión)']
            : ['DPOC exacerbado (tabagismo, sibilos)', 'TEP (D-dímero, angioTC)', 'Pneumonia (febre, infiltrado assimétrico)', 'Crise hipertensiva (PA muito elevada sem congestão prévia)', 'Tamponamento cardíaco (TJV, bulhas abafadas, hipotensão)'],
        treatment: es
            ? ['1. Posición sentada + O2 para SpO2 ≥94%', '2. SpO2 <90%: VNI (CPAP 5-10 cmH2O) inmediata — reduz intubación 50%', '3. Furosemida 40-80 mg IV (doble dosis si usuario crónico)', '4. Nitratos IV si PAS >110 (isosorbida 1-10 mg/h) — contraindicados si PAS <100', '5. IC con FEr baja: IECA/ARA II + betabloqueante + espironolactona + SGLT2i (mantenimiento)', '6. Hipotensión + IC: dobutamina 5-20 mcg/kg/min, evitar diuréticos agresivos']
            : ['1. Posição sentada + O2 para SpO2 ≥94%', '2. SpO2 <90%: VNI (CPAP 5-10 cmH2O) imediata — reduz intubação 50%', '3. Furosemida 40-80 mg IV (dose dupla se usuário crônico)', '4. Nitratos IV se PAS >110 (isossorbida 1-10 mg/h) — contraindicados se PAS <100', '5. ICFEr: IECA/BRA + betabloqueador + espironolactona + SGLT2i (manutenção)', '6. Hipotensão + IC: dobutamina 5-20 mcg/kg/min, evitar diurético agressivo'],
        guidelines: ['ESC IC 2021', 'AHA/ACC HF 2022', 'SBC IC 2023'],
      ),

      // ── Dissecção Aórtica ─────────────────────────────────────────────────
      _CliCondition(
        id: 'dissecc',
        label: es ? 'Disección Aórtica Aguda' : 'Dissecção Aórtica Aguda',
        protocolId: 'crise_hipertensiva',
        keywords: ['dissecc', 'dissecao aort', 'dor torn', 'interescap', 'assimetr', 'diseccion aort'],
        exams: [es ? 'AngioTC aorta urgente' : 'AngioTC aorta urgente', 'RX tórax', 'ECG', es ? 'PA en ambos brazos' : 'PA nos 2 braços'],
        flags: [es ? 'NO anticoagular sin confirmar diagnóstico' : 'NÃO anticoagular sem confirmar diagnóstico',
                es ? 'Control FC+PA: meta PAS <120 + FC <60' : 'Controle FC+PA imediato: meta PAS <120 + FC <60'],
        differentials: es
            ? ['IAM (ECG + troponina, pero disección puede cursarlo como IAM)', 'TEP masivo', 'Pericarditis/derrame pericárdico', 'Estenosis aórtica grave', 'Dolor músculo-esquelético intercostal']
            : ['IAM (ECG + troponina, mas dissecção pode mimetizar IAM)', 'TEP maciço', 'Pericardite/derrame pericárdico', 'Estenose aórtica grave', 'Dor musculoesquelética intercostal'],
        treatment: es
            ? ['1. AngioTC aorta URGENTE — confirmar diagnóstico antes de cualquier intervención', '2. Tipo A (aorta ascendente): cirugía de emergencia inmediata', '3. Tipo B (aorta descendente sin complicaciones): tratamiento médico — labetalol 20 mg IV + nitroprusiato', '4. Meta FC <60 lpm + PAS <120 mmHg: esmolol 0,5 mg/kg IV → infusión 50-200 mcg/kg/min', '5. CONTRAINDICADO: anticoagulación sin confirmación de diagnóstico', '6. CUIDADO: en IAM con supra + disección → NO fibrinolítico']
            : ['1. AngioTC aorta URGENTE — confirmar diagnóstico antes de qualquer intervenção', '2. Tipo A (aorta ascendente): cirurgia de emergência imediata', '3. Tipo B (aorta descendente sem complicações): tratamento médico — labetalol 20 mg IV + nitroprussiato', '4. Meta FC <60 bpm + PAS <120 mmHg: esmolol 0,5 mg/kg IV → infusão 50-200 mcg/kg/min', '5. CONTRAINDICADO: anticoagulação sem confirmação diagnóstica', '6. CUIDADO: em IAM com supra + dissecção → NÃO fibrinolítico'],
        guidelines: ['ESC Aorta 2014', 'AHA/ACC Aorta 2022', 'SBH Aorta 2023'],
      ),

      // ── TPSV / Taquiarritmia ──────────────────────────────────────────────
      _CliCondition(
        id: 'tpsv',
        label: es ? 'Taquiarritmia Supraventricular (TPSV)' : 'Taquiarritmia Supraventricular (TPSV)',
        protocolId: 'tpsv',
        keywords: ['tpsv', 'qrs estrei', 'arritm supravent', 'palpit', 'taquic supravent'],
        exams: [es ? 'ECG 12 derivaciones' : 'ECG 12 derivações', es ? 'Electrolitos (K+, Mg2+)' : 'Eletrólitos (K+, Mg2+)', 'TSH'],
        flags: [es ? 'Inestabilidad hemodinámica → cardioversión eléctrica' : 'Instabilidade hemodinâmica → cardioversão elétrica',
                es ? 'Estable con QRS estrecho → maniobras vagales → adenosina' : 'Estável QRS estreito → manobras vagais → adenosina'],
        differentials: es
            ? ['FA/Flutter (RR irregular)', 'Taquicardia sinusal (causa secundaria: deshidratación, anemia, infección)', 'TV (QRS ancho ≥0,12s — más peligrosa)', 'WPW (δ wave en ritmo sinusal)', 'Taquicardia por reentrada nodal (TRNAV): pausa post-adenosina diagnóstica']
            : ['FA/Flutter (RR irregular)', 'Taquicardia sinusal (causa secundária: desidratação, anemia, infecção)', 'TV (QRS largo ≥0,12s — mais perigosa)', 'WPW (δ wave no ritmo sinusal)', 'Taquicardia por reentrada nodal (TRNAV): pausa pós-adenosina diagnóstica'],
        treatment: es
            ? ['1. Inestable (síncope/hipotensión/EAP): cardioversión eléctrica sincronizada 50-100J', '2. Estable QRS estrecho: maniobra de Valsalva modificada (más efectiva: 40 mmHg 15s + decúbito)', '3. Sin respuesta a vagal: adenosina 6 mg IV rápido (+ flush 20 mL SF) → si no: 12 mg → 12 mg', '4. FA preexcitada (WPW): CONTRAINDICADO adenosina/verapamilo/diltiazem/digoxina → procainamida', '5. Metoprolol 2,5-5 mg IV lento si no responde a adenosina y QRS estrecho', '6. Para prevención: ablación por catéter (curación >95% en TRNAV)']
            : ['1. Instável (síncope/hipotensão/EAP): cardioversão elétrica sincronizada 50-100J', '2. Estável QRS estreito: manobra de Valsalva modificada (mais eficaz: 40 mmHg 15s + decúbito)', '3. Sem resposta à vagal: adenosina 6 mg IV rápido (+ flush 20 mL SF) → se não: 12 mg → 12 mg', '4. FA pré-excitada (WPW): CONTRAINDICADO adenosina/verapamil/diltiazem/digoxina → procainamida', '5. Metoprolol 2,5-5 mg IV lento se sem resposta à adenosina e QRS estreito', '6. Para prevenção: ablação por cateter (cura >95% em TRNAV)'],
        guidelines: ['ESC SVT 2019', 'AHA/ACC SVT 2015', 'ACC SVT 2016'],
      ),

      // ── AVC ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'avc',
        label: es ? 'ACV (Isquémico / Hemorrágico)' : 'AVC (Isquêmico / Hemorrágico)',
        protocolId: 'avc_isquemico',
        keywords: ['avc', 'acidente vasc', 'hemiplegi', 'deficit focal', 'afasia', 'hemiparesia', 'desvio boca', 'nihss', 'tpa ', 'alteplase', 'acv ', 'ave '],
        exams: [es ? 'TC cráneo URGENTE (sin contraste)' : 'TC crânio URGENTE (sem contraste)', es ? 'Glucemia capilar' : 'Glicemia capilar', es ? 'Coagulación' : 'Coagulação', 'ECG', 'PA'],
        flags: [es ? 'Ventana trombolítica: <4,5h' : 'Janela trombolítica: <4,5h',
                es ? 'Hipoglucemia mimetiza AVC — siempre checar glucemia' : 'Hipoglicemia mimetiza AVC — checar glicemia sempre',
                es ? 'HTA grave: tratar solo si PAS >220 (sin trombolítico)' : 'HTA grave: tratar só se PAS >220 (sem trombolítico)'],
        differentials: es
            ? ['ACV hemorrágico (TC sin contraste urgente antes de trombolítico)', 'Hipoglucemia (SIEMPRE descartar — mimetiza AVC)', 'Parálisis de Todd (postictal)', 'Encefalopatía hipertensiva', 'Tumor cerebral con déficit agudo', 'Crisis focal epiléptica']
            : ['AVC hemorrágico (TC sem contraste urgente antes do trombolítico)', 'Hipoglicemia (SEMPRE excluir — mimetiza AVC)', 'Paralisia de Todd (pós-ictal)', 'Encefalopatia hipertensiva', 'Tumor cerebral com déficit agudo', 'Crise focal epiléptica'],
        treatment: es
            ? ['1. TC cráneo URGENTE sin contraste (descartar hemorragia)', '2. Glicemia capilar IMEDIATA — corregir si <60 o >180 mg/dL', '3. ACV isquémico + <4,5h + sin CI: alteplase 0,9 mg/kg IV (máx 90 mg, 10% en bolo + 90% en 60 min)', '4. Contraindicaciones tPA: hemorragia en TC, cirugía reciente, INR >1,7, plaquetas <100k', '5. NIHSS ≥6 + oclusión proximal: trombectomía mecánica hasta 24h (seleccionar por imagen)', '6. PA: no tratar si <220/120 (sin trombolítico) — si tPA: meta PA <180/105 durante 24h']
            : ['1. TC crânio URGENTE sem contraste (excluir hemorragia)', '2. Glicemia capilar IMEDIATA — corrigir se <60 ou >180 mg/dL', '3. AVC isquêmico + <4,5h + sem CI: alteplase 0,9 mg/kg IV (máx 90 mg, 10% em bolo + 90% em 60 min)', '4. Contraindicações tPA: hemorragia no TC, cirurgia recente, INR >1,7, plaquetas <100k', '5. NIHSS ≥6 + oclusão proximal: trombectomia mecânica até 24h (selecionar por imagem)', '6. PA: não tratar se <220/120 (sem trombolítico) — se tPA: meta PA <180/105 por 24h'],
        guidelines: ['AHA/ASA Stroke 2019', 'ESC Stroke 2021', 'SBC/SBN AVC 2022'],
      ),

      // ── Hemorragia Intracraniana ───────────────────────────────────────────
      _CliCondition(
        id: 'hic',
        label: es ? 'Hemorragia Intracraneal' : 'Hemorragia Intracraniana',
        protocolId: 'avc_hemorragico',
        keywords: ['hemorrag intracran', 'hemorrag cerebr', 'sangr cerebr', 'hematoma subdur', 'hematoma extradur', 'hsa', 'hic '],
        exams: [es ? 'TC cráneo urgente' : 'TC crânio urgente', es ? 'Coagulación completa' : 'Coagulação completa', 'Plaquetas'],
        flags: [es ? 'CONTRAINDICADO trombolítico y anticoagulantes' : 'CONTRAINDICADO trombolítico e anticoagulantes',
                es ? 'Revertir anticoagulación inmediatamente' : 'Reverter anticoagulação imediatamente'],
        differentials: es
            ? ['HSA (punción lumbar si TC negativa — xantocromía)', 'Hematoma epidural (intervalo lúcido + trauma)', 'Hematoma subdural agudo/crónico', 'HIC espontánea (HTA, angiopatía amiloide, malformación vascular)', 'Transformación hemorrágica de ACV isquémico']
            : ['HSA (punção lombar se TC negativa — xantocromia)', 'Hematoma epidural (intervalo lúcido + trauma)', 'Hematoma subdural agudo/crônico', 'HIC espontânea (HAS, angiopatia amiloide, malformação vascular)', 'Transformação hemorrágica de AVC isquêmico'],
        treatment: es
            ? ['1. CONTRAINDICADOS: tPA, anticoagulantes, AAS', '2. Revertir anticoagulación INMEDIATA: Warfarina → Vit K 10 mg IV + CCP 4F; DOAC → idarucizumab/andexanet', '3. PA: meta PAS 130-150 mmHg (labetalol o nicardipino IV)', '4. Manejo PIC: cabecera 30°, evitar hipotónicas, considerar manitol 0,5-1 g/kg', '5. Convulsiones: LEV 1 g IV (no profilaxis rutinaria)', '6. HSA: nimodipino 60 mg VO c/4h por 21 días (vasoespasmo), clipaje/espiral urgente']
            : ['1. CONTRAINDICADOS: tPA, anticoagulantes, AAS', '2. Reverter anticoagulação IMEDIATA: Varfarina → Vit K 10 mg IV + CCP 4F; DOAC → idarucizumabe/andexanete', '3. PA: meta PAS 130-150 mmHg (labetalol ou nicardipino IV)', '4. Manejo PIC: cabeceira 30°, evitar hipotônicas, considerar manitol 0,5-1 g/kg', '5. Convulsões: LEV 1 g IV (sem profilaxia rotineira)', '6. HSA: nimodipino 60 mg VO 4/4h por 21 dias (vasoespasmo), clipagem/espiral urgente'],
        guidelines: ['AHA/ASA ICH 2022', 'ESC Stroke 2021', 'Neurocrit Care Society 2022'],
      ),

      // ── Status Epilepticus ────────────────────────────────────────────────
      _CliCondition(
        id: 'epilepsia',
        label: es ? 'Status Epiléptico / Convulsión' : 'Status Epilepticus / Convulsão',
        protocolId: 'status_epilepticus',
        keywords: ['convuls', 'epileps', 'status epilep', 'crise convuls', 'crise epilep', 'benzodiaz', 'diazepam', 'midazolam', 'lorazepam'],
        exams: [es ? 'Glucemia' : 'Glicemia', es ? 'Electrolitos (Na+, Mg2+, Ca2+)' : 'Eletrólitos (Na+, Mg2+, Ca2+)', es ? 'TC cráneo' : 'TC crânio', 'EEG se status refratário'],
        flags: [es ? 'Crisis >5 min → benzodiacepina INMEDIATA' : 'Crise >5 min → benzodiazepínico IMEDIATO',
                es ? 'Status refractario → midazolam/propofol en UTI' : 'Status refratário → midazolam/propofol em UTI'],
        differentials: es
            ? ['Hipoglucemia (tratar antes de BZD)', 'AVC/hemorragia (TC urgente)', 'Meningitis/encefalitis (fiebre + rigidez)', 'Intoxicación/abstinencia (opioides, BZD, alcohol)', 'Trastorno metabólico (Na+, Ca2+, uremia)', 'Crisis psicógena no epiléptica (PNES — movimientos asincrónicos)']
            : ['Hipoglicemia (tratar antes do BZD)', 'AVC/hemorragia (TC urgente)', 'Meningite/encefalite (febre + rigidez)', 'Intoxicação/abstinência (opioides, BZD, álcool)', 'Distúrbio metabólico (Na+, Ca2+, uremia)', 'Crise psicogênica não epiléptica (PNES — movimentos assíncronos)'],
        treatment: es
            ? ['1. 0-5 min: posición lateral, O2, glucemia capilar, acceso IV', '2. 5-20 min: lorazepam 0,1 mg/kg IV (máx 4 mg) o diazepam 10 mg IV o midazolam 10 mg IM', '3. 20-40 min (status establecido): fenitoína 20 mg/kg IV a 50 mg/min o LEV 60 mg/kg IV (máx 4,5 g) o valproato 40 mg/kg IV', '4. 40-60 min (status refractario): intubación + midazolam infusión 0,1-2 mg/kg/h o propofol 2-12 mg/kg/h', '5. >60 min (status superrefractario): ketamina, fenobarbital, anestesia general', '6. Investigar y corregir causa subyacente (glucemia, electrolitos, infección)']
            : ['1. 0-5 min: decúbito lateral, O2, glicemia capilar, acesso IV', '2. 5-20 min: lorazepam 0,1 mg/kg IV (máx 4 mg) ou diazepam 10 mg IV ou midazolam 10 mg IM', '3. 20-40 min (status estabelecido): fenitoína 20 mg/kg IV a 50 mg/min ou LEV 60 mg/kg IV (máx 4,5 g) ou valproato 40 mg/kg IV', '4. 40-60 min (status refratário): intubação + midazolam infusão 0,1-2 mg/kg/h ou propofol 2-12 mg/kg/h', '5. >60 min (status super-refratário): cetamina, fenobarbital, anestesia geral', '6. Investigar e corrigir causa subjacente (glicemia, eletrólitos, infecção)'],
        guidelines: ['Neurocrit Care 2023', 'EAN Status 2022', 'SBN Status 2021'],
      ),

      // ── Meningite / Encefalite ────────────────────────────────────────────
      _CliCondition(
        id: 'meningite',
        label: es ? 'Meningitis / Encefalitis Bacteriana' : 'Meningite / Encefalite Bacteriana',
        protocolId: 'sepse',
        keywords: ['meningite', 'encefalite', 'rigidez nuca', 'kernig', 'brudzinski', 'petequi', 'nucal', 'rigidez de nuca'],
        exams: [es ? 'TC cráneo (antes de la PL si focal)' : 'TC crânio (antes da PL se focal)', es ? 'Punción lumbar' : 'Punção lombar', es ? 'Hemocultivos' : 'Hemoculturas', es ? 'Glucemia' : 'Glicemia', 'PCR'],
        flags: [es ? 'ATB INMEDIATO — no demorar por PL' : 'ATB IMEDIATO — não atrasar por PL',
                es ? 'Dexametasona 0,15 mg/kg IV antes o junto al ATB' : 'Dexametasona 0,15 mg/kg IV antes ou junto ao ATB'],
        differentials: es
            ? ['Encefalitis viral herpética (HSV — aciclovir empírico)', 'HSA (TC + PL: xantocromía)', 'Absceso cerebral (fiebre + déficit focal + efecto de masa)', 'Meningitis criptocócica (inmunodeprimido)', 'Meningitis tuberculosa (curso subagudo, LCR con linfocitos)']
            : ['Encefalite viral herpética (HSV — aciclovir empírico)', 'HSA (TC + PL: xantocromia)', 'Abscesso cerebral (febre + déficit focal + efeito de massa)', 'Meningite criptocócica (imunodeprimido)', 'Meningite tuberculosa (curso subagudo, LCR com linfócitos)'],
        treatment: es
            ? ['1. ATB EMPÍRICO INMEDIATO (no demorar por punción): ceftriaxona 2 g IV c/12h', '2. Dexametasona 0,15 mg/kg IV c/6h ×4 días — iniciar ANTES o junto al ATB (reduce mortalidad en bacteriana)', '3. <50 años inmunocompetente: ceftriaxona + vancomicina 15-20 mg/kg IV c/8h', '4. >50 años o inmunosuprimido: + ampicilina 2 g IV c/4h (cobertura Listeria)', '5. HSV sospechado (encefalitis): aciclovir 10 mg/kg IV c/8h', '6. PL solo después de TC negativo para efecto de masa (si hay signos focales)']
            : ['1. ATB EMPÍRICO IMEDIATO (não atrasar por punção): ceftriaxona 2 g IV 12/12h', '2. Dexametasona 0,15 mg/kg IV 6/6h ×4 dias — iniciar ANTES ou junto ao ATB (reduz mortalidade na bacteriana)', '3. <50 anos imunocompetente: ceftriaxona + vancomicina 15-20 mg/kg IV 8/8h', '4. >50 anos ou imunossuprimido: + ampicilina 2 g IV 4/4h (cobertura Listeria)', '5. HSV suspeito (encefalite): aciclovir 10 mg/kg IV 8/8h', '6. PL apenas após TC negativo para efeito de massa (se sinais focais)'],
        guidelines: ['IDSA Meningitis 2017', 'ESC Neuroinfection 2016', 'SBI Meningite 2021'],
      ),

      // ── Sepse ─────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'sepse',
        label: es ? 'Sepsis / Choque Séptico' : 'Sepse / Choque Séptico',
        protocolId: 'sepse',
        keywords: ['sepse', 'seps', 'septic', 'bacterem', 'infec grave', 'choque septic', 'sofa', 'qsofa', 'bundle'],
        exams: ['Lactato', es ? 'Hemocultivos (2 pares)' : 'Hemoculturas (2 pares)', es ? 'Urocultivos' : 'Urocultura', 'PCR/Procalcitonina', es ? 'Función renal' : 'Função renal', 'Gasometria'],
        flags: [es ? 'Antibiótico en <1 HORA' : 'Antibiótico em <1 HORA',
                es ? 'Lactato >4 → 30 mL/kg SF' : 'Lactato >4 → 30 mL/kg SF',
                es ? 'Vasopresor si PAM <65 tras volumen' : 'Vasopressor se PAM <65 após volume'],
        differentials: es
            ? ['Choque cardiogénico (BNP, ecocardiograma)', 'Anafilaxia (exposición alergénica, urticaria)', 'Choque hemorrágico (buscar foco de sangrado)', 'Insuficiencia suprarrenal aguda (hipotensión refractaria)', 'Intoxicación grave (toxicológico)']
            : ['Choque cardiogênico (BNP, ecocardiograma)', 'Anafilaxia (exposição alergênica, urticária)', 'Choque hemorrágico (buscar foco de sangramento)', 'Insuficiência suprarrenal aguda (hipotensão refratária)', 'Intoxicação grave (toxicológico)'],
        treatment: es
            ? ['1. Hemocultivos (2 pares) + urocultivo ANTES del ATB (sin demorar)', '2. ATB en <1h: foco desconocido → piperacilina-tazobactam 4,5 g IV c/6h o meropenem 1 g c/8h', '3. Lactato >2: reanimación SF 30 mL/kg en 3h; lactato >4: UCI urgente', '4. PAM <65 refractaria: noradrenalina 0,1-3 mcg/kg/min (primera línea)', '5. Corticoides solo en choque séptico refractario: hidrocortisona 200 mg/día IV', '6. Controlar foco: drenaje quirúrgico/IR si absceso/empiema/peritonitis; retirar catéter infectado']
            : ['1. Hemoculturas (2 pares) + urocultura ANTES do ATB (sem atrasar)', '2. ATB em <1h: foco desconhecido → piperacilina-tazobactam 4,5 g IV 6/6h ou meropeném 1 g 8/8h', '3. Lactato >2: reanimação SF 30 mL/kg em 3h; lactato >4: UTI urgente', '4. PAM <65 refratária: noradrenalina 0,1-3 mcg/kg/min (primeira linha)', '5. Corticoides apenas em choque séptico refratário: hidrocortisona 200 mg/dia IV', '6. Controlar foco: drenagem cirúrgica/IR se abscesso/empiema/peritonite; retirar cateter infectado'],
        guidelines: ['Surviving Sepsis Campaign 2021', 'ESICM 2023', 'SBI Sepse 2020'],
      ),

      // ── DPOC ─────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'dpoc',
        label: es ? 'EPOC en Exacerbación Aguda' : 'DPOC em Exacerbação Aguda',
        protocolId: 'dpoc_exacerbacao',
        keywords: ['dpoc', 'doenca pulm obstr', 'enfisema', 'bronquite cronica', 'exacerbac pulm', 'epoc', 'paco2', 'hipercapn'],
        exams: ['Gasometria arterial', 'RX tórax', 'SpO2', 'Hemograma', 'PCR'],
        flags: [es ? 'O2 CONTROLADO: SpO2 objetivo 88–92%' : 'O2 CONTROLADO: SpO2 alvo 88–92%',
                es ? 'pH <7,35 + PaCO2 elevado → VNI inmediata' : 'pH <7,35 + PaCO2 elevado → VNI imediata'],
        differentials: es
            ? ['Neumonía (fiebre, infiltrado RX, esputo purulento)', 'Neumotórax (timpanismo, ausencia MV, RX)', 'IC descompensada (ortopnea, edemas, BNP)', 'TEP (hipoxia + disnea aguda + D-dímero)', 'Broncoespasmo por AINE/betabloqueante']
            : ['Pneumonia (febre, infiltrado RX, escarro purulento)', 'Pneumotórax (timpanismo, ausência MV, RX)', 'IC descompensada (ortopneia, edemas, BNP)', 'TEP (hipóxia + dispneia aguda + D-dímero)', 'Broncoespasmo por AINE/betabloqueador'],
        treatment: es
            ? ['1. O2 CONTROLADO: Venturi 24-28% → meta SpO2 88-92% (riesgo de retención CO2 con O2 alto)', '2. Broncodilatadores nebulizados: salbutamol 2,5 mg + ipratropio 0,5 mg cada 20 min × 3, luego c/4h', '3. Corticoides sistémicos: prednisona 40 mg VO 5 días (o prednisolona 0,5 mg/kg/día)', '4. ATB si: esputo purulento + aumento disnea: amoxicilina-clavulanato 875/125 mg c/12h ×5-7d o azitromicina', '5. pH <7,35 + PaCO2 >45 + FR >25: VNI (BIPAP): IPAP 10-20, EPAP 4-8 cmH2O', '6. Falla VNI/apneas/Glasgow ≤8: intubación orotraqueal']
            : ['1. O2 CONTROLADO: Venturi 24-28% → meta SpO2 88-92% (risco de retenção CO2 com O2 alto)', '2. Broncodilatadores nebulizados: salbutamol 2,5 mg + ipratrópio 0,5 mg a cada 20 min × 3, depois 4/4h', '3. Corticoides sistêmicos: prednisona 40 mg VO 5 dias (ou prednisolona 0,5 mg/kg/dia)', '4. ATB se: escarro purulento + aumento dispneia: amoxicilina-clavulanato 875/125 mg 12/12h ×5-7d ou azitromicina', '5. pH <7,35 + PaCO2 >45 + FR >25: VNI (BIPAP): IPAP 10-20, EPAP 4-8 cmH2O', '6. Falha VNI/apneias/Glasgow ≤8: intubação orotraqueal'],
        guidelines: ['GOLD 2024', 'NICE COPD 2023', 'SBPT DPOC 2022'],
      ),

      // ── Asma ─────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'asma',
        label: es ? 'Asma en Crisis / Broncoespasmo' : 'Asma em Crise / Broncoespasmo Agudo',
        protocolId: 'asma_grave',
        keywords: ['asma', 'broncoespas', 'sibilo', 'wheezing', 'peak flow', 'pfe ', 'broncodilatad'],
        exams: ['SpO2', es ? 'PFE (peak flow)' : 'PFE (peak flow)', es ? 'Gasometría si grave' : 'Gasometria se grave', es ? 'RX tórax si duda' : 'RX tórax se dúvida'],
        flags: [es ? 'Silencio auscultatorio + SpO2 <90% → riesgo de PCR inminente' : 'Silêncio auscultório + SpO2 <90% → risco de PCR iminente'],
        differentials: es
            ? ['EPOC exacerbado (fumador, hipercapnia)', 'Neumotórax (dolor pleurítico, asimetría MV)', 'Cuerpo extraño en vía aérea (inicio súbito, sin historia de asma)', 'Anafilaxia (urticaria, angioedema, hipotensión)', 'Insuficiencia cardíaca (ortopnea, BNP)']
            : ['DPOC exacerbado (tabagismo, hipercapnia)', 'Pneumotórax (dor pleurítica, assimetria MV)', 'Corpo estranho nas vias aéreas (início súbito, sem história de asma)', 'Anafilaxia (urticária, angioedema, hipotensão)', 'Insuficiência cardíaca (ortopneia, BNP)'],
        treatment: es
            ? ['1. O2 para SpO2 ≥92% (≥95% en embarazo)', '2. SABA nebulizado: salbutamol 2,5-5 mg c/20 min × 3 (o MDI 4-8 puffs c/20 min)', '3. Ipratropio 0,5 mg nebulizado junto con salbutamol en moderada/grave (primeras 3h)', '4. Corticoides IV: hidrocortisona 100-200 mg c/6h o metilprednisolona 1 mg/kg/día', '5. MgSO4 2 g IV en 20 min: en crisis grave con SpO2 <92% sin respuesta a SABA', '6. Silencio auscultatorio + hipercapnia + fatiga: intubación (Ket 1-2 mg/kg para inducción)']
            : ['1. O2 para SpO2 ≥92% (≥95% na gestação)', '2. SABA nebulizado: salbutamol 2,5-5 mg a cada 20 min × 3 (ou MDI 4-8 puffs a cada 20 min)', '3. Ipratrópio 0,5 mg nebulizado junto ao salbutamol em moderada/grave (primeiras 3h)', '4. Corticoides IV: hidrocortisona 100-200 mg 6/6h ou metilprednisolona 1 mg/kg/dia', '5. MgSO4 2 g IV em 20 min: em crise grave com SpO2 <92% sem resposta ao SABA', '6. Silêncio auscultório + hipercapnia + fadiga: intubação (Ket 1-2 mg/kg para indução)'],
        guidelines: ['GINA 2024', 'BTS/SIGN 2023', 'SBPT Asma 2020'],
      ),

      // ── CAD ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'cad',
        label: es ? 'Cetoacidosis Diabética (CAD)' : 'Cetoacidose Diabética (CAD)',
        protocolId: 'cad_shh',
        keywords: ['cetoacid', 'cad', 'hiperglicemi', 'cetona', 'acidose metabol', 'dka', 'ph baixo+diabet'],
        exams: [es ? 'Glucemia' : 'Glicemia', es ? 'Cetonemia/cetonuria' : 'Cetonemia/cetonúria', es ? 'Gasometría venosa' : 'Gasometria venosa', es ? 'Electrolitos (K+ urgente)' : 'Eletrólitos (K+ urgente)', 'BUN/Cr'],
        flags: [es ? 'K+ <3,3 → SUSPENDER insulina y reponer K+ primero' : 'K+ <3,3 → SUSPENDER insulina e repor K+ primeiro'],
        differentials: es
            ? ['Estado Hiperosmolar Hiperglucémico (EHH): glucemia >600, osmolaridad >320, sin cetonuria', 'Acidosis láctica (lactato, no cetonuria)', 'Cetosis alcohólica (glucemia normal/baja, alcohol)', 'Acidosis metabólica por intoxicación (salicilatos, metanol)', 'Pancreatitis aguda (lipasa, imagen)']
            : ['Estado Hiperosmolar Hiperglicêmico (EHH): glicemia >600, osmolaridade >320, sem cetonúria', 'Acidose lática (lactato, sem cetonúria)', 'Cetose alcoólica (glicemia normal/baixa, álcool)', 'Acidose metabólica por intoxicação (salicilatos, metanol)', 'Pancreatite aguda (lipase, imagem)'],
        treatment: es
            ? ['1. Hidratación: SF 0,9% 1 L/h × 2h → 0,5 L/h según PVC/diuresis', '2. K+ >3,3 y <5,5: insulina regular 0,1 U/kg bolus → 0,1 U/kg/h; K+ <3,3: SUSPENDER insulina, reponer KCl 40 mEq/h primero', '3. Meta: reducir glucemia 50-70 mg/dL/h; cuando <200 → añadir SG5%', '4. K+ cada 2h: meta 4-5 mEq/L (la insulina baja K+ — riesgo fatal)', '5. Bicarbonato solo si pH <6,9 (100 mEq en 2h)', '6. Buscar causa: infección, abandono insulina, IAM, pancreatitis — tratar causa']
            : ['1. Hidratação: SF 0,9% 1 L/h × 2h → 0,5 L/h conforme PVC/diurese', '2. K+ >3,3 e <5,5: insulina regular 0,1 U/kg bolus → 0,1 U/kg/h; K+ <3,3: SUSPENDER insulina, repor KCl 40 mEq/h primeiro', '3. Meta: reduzir glicemia 50-70 mg/dL/h; quando <200 → adicionar SG5%', '4. K+ a cada 2h: meta 4-5 mEq/L (insulina baixa K+ — risco fatal)', '5. Bicarbonato apenas se pH <6,9 (100 mEq em 2h)', '6. Buscar causa: infecção, abandono insulina, IAM, pancreatite — tratar causa'],
        guidelines: ['ADA DKA 2023', 'ISPAD DKA 2022', 'SBD 2023'],
      ),

      // ── Hipoglicemia ──────────────────────────────────────────────────────
      _CliCondition(
        id: 'hipoglicemia',
        label: es ? 'Hipoglucemia Grave' : 'Hipoglicemia Grave',
        protocolId: 'cad_shh',
        keywords: ['hipoglicemi', 'glicemia bai', 'hipoglucemi', 'glicose baixa'],
        exams: [es ? 'Glucemia capilar URGENTE' : 'Glicemia capilar URGENTE', es ? 'Glucemia venosa' : 'Glicemia venosa'],
        flags: [es ? 'Glucemia <60 → 50 mL glucosa 50% IV inmediato' : 'Glicemia <60 → 50 mL glicose 50% IV imediato',
                es ? 'Sin acceso IV → glucagón 1 mg IM/SC' : 'Sem acesso IV → glucagon 1 mg IM/SC'],
        differentials: es
            ? ['Hipoglucemia por insulina/sulfonilureas (más frecuente)', 'Insulinoma (hipoglucemia de ayuno, péptido C elevado)', 'Insuficiencia suprarrenal (hipotensión, hiponatremia)', 'Hipoglucemia alcohólica (gluconeogénesis inhibida)', 'Causa iatrogénica (error de dosis, ayuno inadecuado)']
            : ['Hipoglicemia por insulina/sulfonilureias (mais frequente)', 'Insulinoma (hipoglicemia de jejum, peptídeo C elevado)', 'Insuficiência suprarrenal (hipotensão, hiponatremia)', 'Hipoglicemia alcoólica (gliconeogênese inibida)', 'Causa iatrogênica (erro de dose, jejum inadequado)'],
        treatment: es
            ? ['1. Glucemia <70 consciente: 15-20 g carbohidrato VO (sucrose, jugo); repetir si <70 en 15 min', '2. Glucemia <50 o inconsciente: glucosa 50% 50 mL IV rápido (SOS: glucagón 1 mg IM/SC)', '3. Glicemia post-tratamiento ≥100: alimentación con carbohidrato complejo + proteína', '4. Sulfonilurea/insulina de acción larga: observación mínima 12-24h (riesgo de recurrencia)', '5. Buscar causa: dosis excesiva, aumento ejercicio, disminución ingesta, IRC (ajuste dosis)', '6. Educación: hipoglucemia asintomática → riesgo de no reconocimiento → ajustar umbral terapéutico']
            : ['1. Glicemia <70 consciente: 15-20 g carboidrato VO (sacarose, suco); repetir se <70 em 15 min', '2. Glicemia <50 ou inconsciente: glicose 50% 50 mL IV rápido (SOS: glucagon 1 mg IM/SC)', '3. Glicemia pós-tratamento ≥100: alimentação com carboidrato complexo + proteína', '4. Sulfonilureia/insulina de ação longa: observação mínima 12-24h (risco de recorrência)', '5. Buscar causa: dose excessiva, aumento exercício, diminuição ingestão, IRC (ajuste dose)', '6. Educação: hipoglicemia assintomática → risco de não reconhecimento → ajustar limiar terapêutico'],
        guidelines: ['ADA Hypoglycemia 2023', 'Endocrine Society 2019', 'SBD 2023'],
      ),

      // ── Hipercalemia ──────────────────────────────────────────────────────
      _CliCondition(
        id: 'hipercalemia',
        label: es ? 'Hipercalemia Grave' : 'Hipercalemia Grave',
        protocolId: 'cad_shh',
        keywords: ['hipercalemi', 'hiperpotass', 'k alt', 'hiperkalem', 'onda t apic', 'k+ elev'],
        exams: [es ? 'K+ sérico urgente' : 'K+ sérico urgente', 'ECG', 'Gasometria', es ? 'Función renal' : 'Função renal'],
        flags: [es ? 'K+ >6,5 o cambios ECG → Gluconato Ca2+ IV inmediato' : 'K+ >6,5 ou alteração ECG → Gluconato Ca2+ IV imediato',
                es ? 'Insulina + glucosa + bicarbonato + diálisis si refractario' : 'Insulina + glicose + bicarbonato + diálise se refratório'],
        differentials: es
            ? ['Pseudohiperpotasemia (hemólisis en muestra)', 'IRA/IRC descompensada', 'Hipoaldosteronismo (Addison)', 'Rabdomiólisis', 'Acidosis metabólica severa (redistribución)']
            : ['Pseudo-hipercalemia (hemólise da amostra)', 'IRA/IRC descompensada', 'Hipoaldosteronismo (Addison)', 'Rabdomiólise', 'Acidose metabólica grave (redistribuição)'],
        treatment: es
            ? ['1. ECG alterado (onda T apiculada, ensanchamiento QRS, onda sinusoidal): gluconato Ca2+ 10% 10 mL IV en 2-3 min (estabiliza membrana)', '2. Redistribución intacelular: insulina regular 10 U IV + glucosa 50% 50 mL IV (baja K+ 0,5-1 mEq/L en 30 min)', '3. Bicarbonato: NaHCO3 50 mEq IV si pH <7,2 (distribución intracelular)', '4. Eliminación: furosemida 40-80 mg IV si función renal conservada; kayexalato 15-30 g VO si IRC', '5. K+ >7 refractario o cambios ECG graves → diálisis de emergencia', '6. Suspender fármacos que elevan K+: IECA/ARA II, espirolactona, AINEs, heparina']
            : ['1. ECG alterado (onda T apiculada, alargamento QRS, onda sinusoidal): gluconato de Ca2+ 10% 10 mL IV em 2-3 min (estabiliza membrana)', '2. Redistribuição intracelular: insulina regular 10 U IV + glicose 50% 50 mL IV (baixa K+ 0,5-1 mEq/L em 30 min)', '3. Bicarbonato: NaHCO3 50 mEq IV se pH <7,2 (distribuição intracelular)', '4. Eliminação: furosemida 40-80 mg IV se função renal conservada; kayexalato 15-30 g VO se IRC', '5. K+ >7 refratário ou alterações ECG graves → diálise de emergência', '6. Suspender fármacos que elevam K+: IECA/BRA, espironolactona, AINEs, heparina'],
        guidelines: ['KDIGO AKI 2022', 'ESC Electrolytes 2019', 'ASN 2021'],
      ),

      // ── Hipopotassemia ────────────────────────────────────────────────────
      _CliCondition(
        id: 'hipocalemia',
        label: es ? 'Hipopotasemia Grave' : 'Hipopotassemia Grave',
        protocolId: 'cad_shh',
        keywords: ['hipocalemi', 'hipopotass', 'k bai', 'hipokalem', 'k+ baixo'],
        exams: [es ? 'K+ sérico' : 'K+ sérico', es ? 'ECG (ondas U, QT largo)' : 'ECG (ondas U, QT longo)', 'Mg2+', 'Gasometria'],
        flags: [es ? 'K+ <2,5 o cambios ECG → reposición IV monitorizada' : 'K+ <2,5 ou alteração de ECG → reposição IV monitorada'],
        differentials: es
            ? ['Pérdidas gastrointestinales (vómitos, diarrea, fístulas)', 'Pérdidas renales (diuréticos, hiperaldosteronismo)', 'Redistribución (insulina, alcalosis, beta-agonistas)', 'Hipomagnesemia (siempre corregir Mg2+ en hipopotasemia refractaria)', 'CAD en tratamiento (insulina baja K+)']
            : ['Perdas gastrointestinais (vômitos, diarreia, fístulas)', 'Perdas renais (diuréticos, hiperaldosteronismo)', 'Redistribuição (insulina, alcalose, beta-agonistas)', 'Hipomagnesemia (sempre corrigir Mg2+ em hipopotassemia refratária)', 'CAD em tratamento (insulina baixa K+)'],
        treatment: es
            ? ['1. K+ 3,0-3,5: potasio VO 40-60 mEq/día (cloruro de potasio)', '2. K+ 2,5-3,0: KCl oral 80-120 mEq/día o IV 10-20 mEq/h (max 40 mEq/h en vía central con monitoreo)', '3. K+ <2,5 o síntomas (debilidad, ECG alterado): KCl IV 20-40 mEq/h en vía central + monitoreo contínuo', '4. SIEMPRE verificar y corregir Mg2+ (hipomagnesemia impide la corrección del K+)', '5. Identificar causa: alcalosis → tratar; diuréticos → reducir dosis; diarrea → tratar', '6. K+ no sube con reposición: pensar en síndrome de Bartter/Gitelman']
            : ['1. K+ 3,0-3,5: potássio VO 40-60 mEq/dia (cloreto de potássio)', '2. K+ 2,5-3,0: KCl oral 80-120 mEq/dia ou IV 10-20 mEq/h (máx 40 mEq/h em via central com monitoração)', '3. K+ <2,5 ou sintomas (fraqueza, ECG alterado): KCl IV 20-40 mEq/h em via central + monitoração contínua', '4. SEMPRE verificar e corrigir Mg2+ (hipomagnesemia impede a correção do K+)', '5. Identificar causa: alcalose → tratar; diuréticos → reduzir dose; diarreia → tratar', '6. K+ não sobe com reposição: pensar em síndrome de Bartter/Gitelman'],
        guidelines: ['ASN Electrolytes 2021', 'AHA 2019', 'SBN 2022'],
      ),

      // ── IRA ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'ira',
        label: es ? 'Insuficiencia Renal Aguda (IRA)' : 'Insuficiência Renal Aguda (IRA)',
        protocolId: 'cad_shh',
        keywords: ['insuf renal aguda', 'ira ', 'oliguria', 'anuria', 'creatinina elev', 'uremia', 'aki'],
        exams: [es ? 'Creatinina/Urea seriadas' : 'Creatinina/Ureia seriadas', es ? 'Electrolitos' : 'Eletrólitos', es ? 'Eco renal' : 'Eco renal', 'EAS/urocultura'],
        flags: [es ? 'K+ >6 u oliguria refractaria → diálisis de urgencia' : 'K+ >6 ou oligúria refratária → diálise de urgência',
                es ? 'Descartar prerrenal (volumen) y obstructivo (eco)' : 'Excluir pré-renal (volume) e obstrutivo (eco)'],
        differentials: es
            ? ['Prerrenal (deshidratación, hipotensión, IC): fracción de Na excreción <1%', 'Intrínseca: NTA isquémica/tóxica (AINE, aminoglucósidos, contraste), glomerulonefritis, vasculitis', 'Postrenal: obstrucción (próstata, tumor, litiasis) — eco urgente']
            : ['Pré-renal (desidratação, hipotensão, IC): fração de excreção de Na <1%', 'Intrínseca: NTA isquêmica/tóxica (AINE, aminoglicosídeos, contraste), glomerulonefrite, vasculite', 'Pós-renal: obstrução (próstata, tumor, litíase) — eco urgente'],
        treatment: es
            ? ['1. Prerrenal: hidratación SF 500 mL en 30 min, evaluar respuesta (diuresis >0,5 mL/kg/h)', '2. Suspender nefrotóxicos: AINE, aminoglucósidos, contraste, IECA/ARA II, metformina', '3. Postrenal: sondaje vesical urgente o nefrostomía percutánea', '4. Monitorizar K+, pH: hipercalemia >6 → gluconato Ca2+, insulina/glucosa, diálisis', '5. Diálisis urgente: K+ >6,5 refractario, acidosis pH <7,1, uremia sintomática, sobrecarga hídrica', '6. Ajustar TODAS las dosis de fármacos según ClCr (ver sección farmacológica)']
            : ['1. Pré-renal: hidratação SF 500 mL em 30 min, avaliar resposta (diurese >0,5 mL/kg/h)', '2. Suspender nefrotóxicos: AINE, aminoglicosídeos, contraste, IECA/BRA, metformina', '3. Pós-renal: sondagem vesical urgente ou nefrostomia percutânea', '4. Monitorar K+, pH: hipercalemia >6 → gluconato Ca2+, insulina/glicose, diálise', '5. Diálise urgente: K+ >6,5 refratário, acidose pH <7,1, uremia sintomática, sobrecarga hídrica', '6. Ajustar TODAS as doses de fármacos conforme ClCr (ver seção farmacológica)'],
        guidelines: ['KDIGO AKI 2012 (updated 2023)', 'ERA-EDTA 2023', 'SBN 2022'],
      ),

      // ── HDA ───────────────────────────────────────────────────────────────
      _CliCondition(
        id: 'hda',
        label: es ? 'Hemorragia Digestiva Alta (HDA)' : 'Hemorragia Digestiva Alta (HDA)',
        protocolId: 'hda_varizeal',
        keywords: ['hematemes', 'hemorrag digest', 'melena', 'hamatoquezia', 'hematoquezia', 'sangr gi', 'ulcera sangr', 'varizes esof'],
        exams: [es ? 'Hemograma (Hb, Ht)' : 'Hemograma (Hb, Ht)', es ? 'Coagulación' : 'Coagulação', es ? 'Tipaje sanguíneo' : 'Tipagem sanguínea', es ? 'Función renal' : 'Função renal', es ? 'EDA urgente' : 'EDA urgente'],
        flags: [es ? 'PA <100 + FC >100 → 2 accesos calibrosos + SF inmediato' : 'PA <100 + FC >100 → 2 acessos calibrosos + SF imediato',
                es ? 'Hb objetivo 7–8 g/dL (transfusión restrictiva)' : 'Hb alvo 7–8 g/dL (transfusão restritiva)',
                es ? 'Cirrosis + HDA → octreótido + ATB + Terlipresina' : 'Cirrose + HDA → octreotida + ATB profilático + Terlipressina'],
        differentials: es
            ? ['Úlcera péptica (H. pylori, AINE — más frecuente)', 'Varices esofágicas (cirrosis, hepatopatía)', 'Síndrome de Mallory-Weiss (vómitos repetidos)', 'Lesión de Dieulafoy (sangrado arterial puntual)', 'Cáncer gástrico/esofágico (hemorragia crónica)', 'Hemobilia o fístula aorto-entérica (raro, grave)']
            : ['Úlcera péptica (H. pylori, AINE — mais frequente)', 'Varizes esofágicas (cirrose, hepatopatia)', 'Síndrome de Mallory-Weiss (vômitos repetidos)', 'Lesão de Dieulafoy (sangramento arterial pontual)', 'Câncer gástrico/esofágico (hemorragia crônica)', 'Hemobilia ou fístula aorto-entérica (raro, grave)'],
        treatment: es
            ? ['1. Acceso IV ×2 calibrosos + SF 1 L si PA <100/FC >100 + transfundir si Hb <7 (meta 7-9 g/dL)', '2. IBP IV: omeprazol 80 mg bolus → 8 mg/h infusión (antes de EDA)', '3. No cirrosis: EDA urgente en <12h (alta urgencia) o <24h (sin inestabilidad)', '4. Cirrosis/varices: terlipresina 2 mg IV c/4-6h + ceftriaxona 1 g/día (ATB profiláctico 5-7d)', '5. Score Glasgow-Blatchford ≥12 → EDA en <6h; Rockford C/D → ligadura variceal + octreótido', '6. Refractario: TIPS (shunt intrahepático) o cirugía de urgencia']
            : ['1. Acesso IV ×2 calibrosos + SF 1 L se PA <100/FC >100 + transfundir se Hb <7 (meta 7-9 g/dL)', '2. IBP IV: omeprazol 80 mg bolus → 8 mg/h infusão (antes da EDA)', '3. Sem cirrose: EDA urgente em <12h (alta urgência) ou <24h (sem instabilidade)', '4. Cirrose/varizes: terlipressina 2 mg IV 4/4h-6/6h + ceftriaxona 1 g/dia (ATB profilático 5-7d)', '5. Score Glasgow-Blatchford ≥12 → EDA em <6h; Rockford C/D → ligadura varicosa + octreotida', '6. Refratário: TIPS (shunt intra-hepático) ou cirurgia de urgência'],
        guidelines: ['BSG HDA 2021', 'ESGE 2021', 'SBH HDA 2022'],
      ),

      // ── Abdome Agudo ──────────────────────────────────────────────────────
      _CliCondition(
        id: 'abdome',
        label: es ? 'Abdomen Agudo / Peritonitis' : 'Abdome Agudo / Peritonite',
        protocolId: 'sepse',
        keywords: ['dor abdom', 'abdome agudo', 'peritonite', 'rigidez abd', 'defesa abdom', 'apendicite', 'colecistite', 'obstru intestinal', 'peritonitis'],
        exams: [es ? 'RX abdomen de pie' : 'RX abdome em pé', es ? 'TC abdomen+pelvis con contraste' : 'TC abdome+pelve com contraste', 'Hemograma', 'PCR', 'Lipase/amilase'],
        flags: [es ? 'Signos peritoneales + inestabilidad → cirugía de emergencia' : 'Sinais peritoneais + instabilidade → cirurgia de emergência',
                es ? 'Neumoperitoneo en RX → perforación visceral: cirugía inmediata' : 'Pneumoperitônio no RX → perfuração visceral: cirurgia imediata'],
        differentials: es
            ? ['Apendicitis aguda (fosa ilíaca derecha, Murphy de McBurney)', 'Colecistitis aguda (hipocondrio derecho, Murphy positivo, fiebre)', 'Pancreatitis aguda (epigastrio irradiado a dorso, lipasa >3×)', 'Perforación de víscera hueca (neumoperitoneo, defensa total)', 'Obstrucción intestinal (distensión, ausencia de gases distales)', 'Isquemia mesentérica (dolor intenso, leucocitosis, acidosis, lactato)']
            : ['Apendicite aguda (fossa ilíaca direita, sinal de McBurney)', 'Colecistite aguda (hipocôndrio direito, Murphy positivo, febre)', 'Pancreatite aguda (epigástrio irradiado ao dorso, lipase >3×)', 'Perfuração de víscera oca (pneumoperitônio, defesa total)', 'Obstrução intestinal (distensão, ausência de gases distais)', 'Isquemia mesentérica (dor intensa, leucocitose, acidose, lactato)'],
        treatment: es
            ? ['1. Estabilización: 2 accesos IV, SF 1-2 L, analgesia IV (ketorolac 30 mg o tramadol 100 mg)', '2. Ayuno + SNG si vómitos o distensión importante', '3. ATB empírico si sospecha infección: piperacilina-tazobactam 4,5 g IV c/6h o ampicilina + metronidazol', '4. TC abdomen+pelvis con contraste IV (estudio diagnóstico principal)', '5. Peritonitis/perforación/isquemia: cirugía de emergencia inmediata', '6. Apendicitis confirmada: apendicectomía laparoscópica; colecistitis: colecistectomía en 24-72h']
            : ['1. Estabilização: 2 acessos IV, SF 1-2 L, analgesia IV (cetorrolaco 30 mg ou tramadol 100 mg)', '2. Jejum + SNG se vômitos ou distensão importante', '3. ATB empírico se suspeita infecção: piperacilina-tazobactam 4,5 g IV 6/6h ou ampicilina + metronidazol', '4. TC abdome+pelve com contraste IV (principal exame diagnóstico)', '5. Peritonite/perfuração/isquemia: cirurgia de emergência imediata', '6. Apendicite confirmada: apendicectomia laparoscópica; colecistite: colecistectomia em 24-72h'],
        guidelines: ['WSES Peritonitis 2020', 'SAGES 2023', 'SBC Abdome 2021'],
      ),

      // ── Pancreatite ───────────────────────────────────────────────────────
      _CliCondition(
        id: 'pancreatite',
        label: es ? 'Pancreatitis Aguda' : 'Pancreatite Aguda',
        protocolId: 'sepse',
        keywords: ['pancreatite', 'pancreat', 'dor epigast irrad dorso', 'lipase elev', 'amilase elev', 'bisap', 'balthazar'],
        exams: [es ? 'Lipasa (>3× LSN)' : 'Lipase (>3× LSN diagnóstico)', es ? 'TC abdomen (Balthazar/CTSI)' : 'TC abdome (Balthazar/CTSI)', es ? 'Electrolitos' : 'Eletrólitos', 'Score BISAP'],
        flags: [es ? 'Score BISAP ≥3 → UTI (pancreatitis grave)' : 'Score BISAP ≥3 ou APACHE II alto → UTI',
                es ? 'Necroinfeción: fiebre + empeoramiento → TC + ATB' : 'Necroinfeção: febre + piora clínica → TC + ATB'],
        differentials: es
            ? ['Úlcera péptica perforada (neumoperitoneo, RX)', 'IAM inferior (ECG)', 'Colecistitis aguda (Murphy, eco)', 'Isquemia mesentérica (lactato, dolor + leucocitosis)', 'Obstrucción intestinal alta']
            : ['Úlcera péptica perfurada (pneumoperitônio, RX)', 'IAM inferior (ECG)', 'Colecistite aguda (Murphy, eco)', 'Isquemia mesentérica (lactato, dor + leucocitose)', 'Obstrução intestinal alta'],
        treatment: es
            ? ['1. Hidratación agresiva: Ringer lactato 250-500 mL/h (preferido sobre SF) primeras 24h (BISAP <3)', '2. Analgesia: ketorolac 30 mg IV o morfina 2-4 mg IV (sin evidencia de empeorar pancreatitis)', '3. Nutrición: enteral precoz en <24-48h si tolera; parenteral solo si enteral imposible', '4. BISAP ≥3/necrosante: UTI, monitoreo contínuo, anticipar complicaciones', '5. ATB solo si necroinfeción confirmada (guiada por aspiración con aguja fina TC-guiada): meropenem o imipenem', '6. Colangiopancreatografía (CPRE) urgente en <24h si: cálculo biliar + ictericia + colangitis']
            : ['1. Hidratação agressiva: Ringer lactato 250-500 mL/h (preferido ao SF) primeiras 24h (BISAP <3)', '2. Analgesia: cetorrolaco 30 mg IV ou morfina 2-4 mg IV (sem evidência de piorar pancreatite)', '3. Nutrição: enteral precoce em <24-48h se tolera; parenteral apenas se enteral impossível', '4. BISAP ≥3/necrosante: UTI, monitoramento contínuo, antecipar complicações', '5. ATB apenas em necroinfeção confirmada (guiada por aspiração com agulha fina TC-guiada): meropeném ou imipeném', '6. CPRE urgente em <24h se: cálculo biliar + icterícia + colangite'],
        guidelines: ['AGA Pancreatitis 2018', 'IAP/APA 2015', 'SBH Pancreatite 2021'],
      ),

      // ── Crise Hipertensiva ────────────────────────────────────────────────
      _CliCondition(
        id: 'crise_hipert',
        label: es ? 'Crisis Hipertensiva (Urgencia / Emergencia)' : 'Crise Hipertensiva (Urgência / Emergência)',
        protocolId: 'crise_hipertensiva',
        keywords: ['crise hipert', 'pa muito alta', 'pa >180', 'emergencia hiperten', 'encefalopatia hiperten', 'urgencia hiperten', 'hipertensao grave', 'pa > 180', 'pa 220', 'pa 200'],
        exams: [es ? 'PA en ambos brazos' : 'PA em ambos os braços', 'ECG', es ? 'Fondo de ojo' : 'Fundo de olho', es ? 'Creatinina/urea' : 'Creatinina/ureia', es ? 'TC cráneo si síntomas neurológicos' : 'TC crânio se sintomas neurológicos'],
        flags: [es ? 'Encefalopatía + PA >180 → emergencia: reducción IV controlada' : 'Encefalopatia + PA >180 → emergência: redução IV controlada',
                es ? 'NO reducir PA >25% en 1ª hora' : 'NÃO reduzir PA >25% na 1ª hora'],
        differentials: es
            ? ['Emergencia hipertensiva (lesión órgano diana: encefalopatía, IC aguda, disección, eclampsia)', 'Urgencia hipertensiva (PA muy elevada SIN lesión aguda de órgano)', 'HTA por dolor/ansiedad (tratar la causa)', 'Hipertensión de bata blanca (monitorización ambulatoria)', 'Crisis adrenérgica (feocromocitoma, cocaína — PA muy lábil)']
            : ['Emergência hipertensiva (lesão órgão-alvo: encefalopatia, IC aguda, dissecção, eclâmpsia)', 'Urgência hipertensiva (PA muito elevada SEM lesão aguda de órgão)', 'HAS por dor/ansiedade (tratar a causa)', 'HAS do avental branco (monitorização ambulatorial)', 'Crise adrenérgica (feocromocitoma, cocaína — PA muito lábil)'],
        treatment: es
            ? ['1. Emergencia (lesión diana): reducción PA controlada IV — meta: bajar 20-25% en 1ª hora, NO normalizar', '2. ACV isquémico: solo tratar si PAS >220/120 (sin trombolítico) o >180/105 (con trombolítico)', '3. Encefalopatía/IC aguda/disección: labetalol 20 mg IV → 40-80 mg c/10 min o nitroprusiato 0,25-10 mcg/kg/min', '4. Urgencia (sin lesión diana): antihipertensivo VO — captopril 25-50 mg o amlodipino 5-10 mg', '5. PA >220/120 asintomática: captopril SL + observación 30-60 min → alta si responde', '6. Ajustar medicación habitual + seguimiento en 24-72h']
            : ['1. Emergência (lesão de órgão-alvo): redução PA controlada IV — meta: baixar 20-25% em 1ª hora, NÃO normalizar', '2. AVC isquêmico: apenas tratar se PAS >220/120 (sem trombolítico) ou >180/105 (com trombolítico)', '3. Encefalopatia/IC aguda/dissecção: labetalol 20 mg IV → 40-80 mg a cada 10 min ou nitroprussiato 0,25-10 mcg/kg/min', '4. Urgência (sem lesão de órgão): anti-hipertensivo VO — captopril 25-50 mg ou anlodipino 5-10 mg', '5. PA >220/120 assintomática: captopril SL + observação 30-60 min → alta se responde', '6. Ajustar medicação habitual + seguimento em 24-72h'],
        guidelines: ['ESC/ESH Hipertensão 2023', 'AHA/ACC HTN 2022', 'SBC HAS 2020'],
      ),

      // ── Delirium ──────────────────────────────────────────────────────────
      _CliCondition(
        id: 'delirium',
        label: es ? 'Delirium / Alteración de Consciencia' : 'Delirium / Rebaixamento de Consciência',
        protocolId: 'status_epilepticus',
        keywords: ['delirium', 'confusao aguda', 'agitac', 'rebaixamento conscien', 'glasgow baixo', 'confusao mental', 'cam ', 'alterac conscien'],
        exams: [es ? 'Glucemia capilar URGENTE' : 'Glicemia capilar URGENTE', es ? 'TC cráneo' : 'TC crânio', es ? 'Electrolitos' : 'Eletrólitos', es ? 'Función renal y hepática' : 'Função renal e hepática', 'Gasometria'],
        flags: [es ? 'Excluir SIEMPRE: hipoglucemia, AVC, meningitis, IRA, intoxicación' : 'Excluir SEMPRE: hipoglicemia, AVC, meningite, IRA, intoxicação',
                es ? 'Glasgow ≤8 → proteger vía aérea (IOT)' : 'Glasgow ≤8 → proteger via aérea (IOT)'],
        differentials: es
            ? ['Hipoglucemia (SIEMPRE primera en excluir)', 'AVC agudo (TC urgente)', 'Meningitis/encefalitis (rigidez, fiebre, LCR)', 'Encefalopatía urémica/hepática (creatinina, amoniaco)', 'Intoxicación/síndrome serotoninérgico/anticolinérgico', 'Delirium hipoactivo (agitación mínima — frecuentemente subdiagnosticado en UTI)']
            : ['Hipoglicemia (SEMPRE primeira a excluir)', 'AVC agudo (TC urgente)', 'Meningite/encefalite (rigidez, febre, LCR)', 'Encefalopatia urêmica/hepática (creatinina, amoniaco)', 'Intoxicação/síndrome serotoninérgico/anticolinérgico', 'Delirium hipoativo (agitação mínima — frequentemente subdiagnosticado em UTI)'],
        treatment: es
            ? ['1. Glucemia capilar INMEDIATA (corregir si <60 o >400)', '2. Oxigenación: SpO2 ≥94%; si Glasgow ≤8 → IOT', '3. Búsqueda sistemática de causa: TC, PL, electrolitos, función renal/hepática, toxicológico', '4. Medidas no farmacológicas: reorientación, iluminación diurna, movilización, familia, ciclo sueño-vigilia', '5. Agitación que pone en riesgo: haloperidol 2-5 mg IV (preferir IM en agitación grave) — en QT prolongado: quetiapina', '6. Evitar BZD en delirium no alcohólico (empeoran delirium en ancianos)']
            : ['1. Glicemia capilar IMEDIATA (corrigir se <60 ou >400)', '2. Oxigenação: SpO2 ≥94%; se Glasgow ≤8 → IOT', '3. Busca sistemática de causa: TC, PL, eletrólitos, função renal/hepática, toxicológico', '4. Medidas não farmacológicas: reorientação, iluminação diurna, mobilização, família, ciclo sono-vigília', '5. Agitação que coloca em risco: haloperidol 2-5 mg IV (preferir IM em agitação grave) — em QT longo: quetiapina', '6. Evitar BZD em delirium não alcoólico (pioram delirium em idosos)'],
        guidelines: ['SCCM PADIS 2018', 'APA Delirium 2023', 'ESICM Delirium 2022'],
      ),

      // ── Intoxicação ───────────────────────────────────────────────────────
      _CliCondition(
        id: 'intoxicacao',
        label: es ? 'Intoxicación Exógena / Sobredosis' : 'Intoxicação Exógena / Overdose',
        protocolId: 'pcr_adulto',
        keywords: ['intoxicac', 'overdose', 'envenenam', 'organofosf', 'naloxona', 'flumazenil', 'carvao ativ', 'toxicolog'],
        exams: [es ? 'Toxicológico urinario' : 'Toxicológico urinário', 'Gasometria', es ? 'Electrolitos' : 'Eletrólitos', es ? 'ECG (QT largo)' : 'ECG (QT longo)', es ? 'Glucemia' : 'Glicemia'],
        flags: [es ? 'Contactar Centro de Toxicología (0800 722 6001)' : 'Contato: Centro de Informação Toxicológica (0800 722 6001)',
                es ? 'Antídotos: naloxona (opioides), flumazenil (BZD), N-acetilcisteína (paracetamol)' : 'Antídotos: naloxona (opioides), flumazenil (BZD), N-acetilcisteína (paracetamol)',
                es ? 'Carbón activado 1 g/kg VO si <1h de ingesta' : 'Carvão ativado 1 g/kg VO se <1h da ingestão'],
        differentials: es
            ? ['Identificar toxidrome: anticolinérgico (midriasis, taquicardia, retención urinaria), colinérgico/organofosf (miosis, broncosecreción, bradicardia), opioide (miosis, bradipnea, depresión SNC), simpaticomimético (midriasis, taquicardia, HTA), serotoninérgico (agitación, hiperreflexia, clonus)']
            : ['Identificar toxidrome: anticolinérgico (midríase, taquicardia, retenção urinária), colinérgico/organofosf (miose, broncossecreção, bradicardia), opioide (miose, bradipneia, depressão SNC), simpatomimérico (midríase, taquicardia, HAS), serotoninérgico (agitação, hiperreflexia, clonus)'],
        treatment: es
            ? ['1. ABCDE → vía aérea si Glasgow ≤8 o bradipnea', '2. Carbón activado 1 g/kg VO (max 50 g) si <1h de ingesta y vía aérea protegida (CI: ácidos, bases, hidrocarbonos)', '3. Antídotos específicos: naloxona 0,4-2 mg IV/IM (opioides); flumazenil 0,2 mg IV (BZD — con cuidado en epilépticos); N-acetilcisteína 150 mg/kg IV/VO (paracetamol)', '4. Organofosf/pesticidas: atropina 2-4 mg IV hasta secar secreciones + pralidoxima 1-2 g IV', '5. ECG: QT largo → suspender causal + magnesio 2 g IV; QRS ancho (ADT) → bicarbonato 1-2 mEq/kg', '6. Centro de Toxicología (Brasil): 0800 722 6001 — consultar caso complejo']
            : ['1. ABCDE → via aérea se Glasgow ≤8 ou bradipneia', '2. Carvão ativado 1 g/kg VO (máx 50 g) se <1h da ingestão e via aérea protegida (CI: ácidos, bases, hidrocarbonetos)', '3. Antídotos específicos: naloxona 0,4-2 mg IV/IM (opioides); flumazenil 0,2 mg IV (BZD — cuidado em epilépticos); N-acetilcisteína 150 mg/kg IV/VO (paracetamol)', '4. Organofosf/pesticidas: atropina 2-4 mg IV até secar secreções + pralidoxima 1-2 g IV', '5. ECG: QT longo → suspender causal + magnésio 2 g IV; QRS largo (ADT) → bicarbonato 1-2 mEq/kg', '6. Centro de Informação Toxicológica (Brasil): 0800 722 6001 — consultar caso complexo'],
        guidelines: ['AAPCC 2023', 'ESICM Toxicology 2022', 'SBT 2021'],
      ),

      // ── Eclâmpsia / HELLP ─────────────────────────────────────────────────
      _CliCondition(
        id: 'eclampsia',
        label: es ? 'Preeclampsia Grave / Eclampsia / HELLP' : 'Pré-eclâmpsia Grave / Eclâmpsia / Síndrome HELLP',
        protocolId: 'crise_hipertensiva',
        keywords: ['eclamps', 'pre-eclamps', 'pressao gestac', 'gestante hiperten', 'convulsao gravida', 'hellp', 'preeclamps', 'sulfato magn'],
        exams: [es ? 'PA seriada' : 'PA seriada', es ? 'Proteinuria 24h' : 'Proteinúria 24h', es ? 'Plaquetas' : 'Plaquetas', 'TGO/TGP', 'LDH', es ? 'Creatinina' : 'Creatinina'],
        flags: [es ? 'PA ≥160/110 → antihipertensivo inmediato (hidralazina/nifedipina)' : 'PA ≥160/110 em gestante → anti-hipertensivo imediato',
                es ? 'Convulsión → sulfato de magnesio 4–6 g IV' : 'Convulsão → sulfato de magnésio 4–6 g EV (ataque) + 1–2 g/h manutenção',
                es ? 'HELLP → parto inmediato si ≥34 semanas' : 'HELLP → parto imediato se ≥34 semanas'],
        differentials: es
            ? ['Eclampsia vs status epiléptico en embarazo (siempre MgSO4 primero)', 'HELLP vs hígado graso agudo del embarazo (HGAE): transaminasas muy elevadas + hipoglucemia', 'Síndrome hemolítico urémico atípico (SHUa)', 'Púrpura trombocitopénica trombótica (PTT)']
            : ['Eclâmpsia vs status epiléptico na gestação (sempre MgSO4 primeiro)', 'HELLP vs fígado gorduroso agudo da gestação (FGAG): transaminases muito elevadas + hipoglicemia', 'Síndrome hemolítico urêmico atípico (SHUa)', 'Púrpura trombocitopênica trombótica (PTT)'],
        treatment: es
            ? ['1. PA ≥160/110: antihipertensivo IV INMEDIATO — hidralazina 5-10 mg IV c/20 min o labetalol 20 mg IV o nifedipino 10-20 mg VO', '2. Eclampsia/convulsión: MgSO4 4-6 g IV en 20 min → mantenimiento 1-2 g/h (monitorizar reflejo patelar y diuresis)', '3. MgSO4 toxicidad (reflejo abolido, FR <12): gluconato Ca2+ 1 g IV', '4. HELLP: parto si ≥34 sem o inestabilidad; corticoides (dexametasona 12 mg c/12h) si <34 sem', '5. Meta PA: 140-155/90-105 (evitar caídas bruscas — riesgo fetal)', '6. Corticoides fetales si <34 semanas: betametasona 12 mg IM c/24h ×2 dosis']
            : ['1. PA ≥160/110: anti-hipertensivo IV IMEDIATO — hidralazina 5-10 mg IV a cada 20 min ou labetalol 20 mg IV ou nifedipino 10-20 mg VO', '2. Eclâmpsia/convulsão: MgSO4 4-6 g IV em 20 min → manutenção 1-2 g/h (monitorar reflexo patelar e diurese)', '3. Toxicidade MgSO4 (reflexo abolido, FR <12): gluconato de Ca2+ 1 g IV', '4. HELLP: parto se ≥34 sem ou instabilidade; corticoides (dexametasona 12 mg 12/12h) se <34 sem', '5. Meta PA: 140-155/90-105 (evitar quedas bruscas — risco fetal)', '6. Corticoides fetais se <34 semanas: betametasona 12 mg IM 24/24h ×2 doses'],
        guidelines: ['ACOG Preeclampsia 2020', 'FIGO 2022', 'FEBRASGO 2022'],
      ),

      // ── Cefaleia de alto risco ────────────────────────────────────────────
      // IMPORTANTE: keywords exigem qualificadores de risco reais para ativar.
      // "cefal" sozinho NÃO ativa — precisa de pelo menos 1 red flag associada.
      _CliCondition(
        id: 'cefaleia_grave',
        label: es ? 'Cefalea de alto riesgo — descartar HSA / Meningitis' : 'Cefaleia de alto risco — excluir HSA / Meningite',
        protocolId: 'avc_hemorragico',
        // Apenas red flags reais: início em trovoada, pior da vida, sinais meníngeos,
        // déficit focal, alteração consciência, petéquias — não "cefal" isolado.
        keywords: ['trovoada', 'pior cefaleia', 'pior dor de cabeca', 'inicio subito intenso',
                   'rigidez nuca', 'rigidez de nuca', 'meningismo', 'petequi',
                   'kernig', 'brudzinski', 'deficit focal', 'paralisia facial',
                   'pior cefal', 'thunderclap', 'hsa ', 'hemorragia subarac'],
        exams: [es ? 'TC cráneo sin contraste (descartar HSA)' : 'TC crânio sem contraste (excluir HSA)', es ? 'Punción lumbar si TC negativa' : 'Punção lombar se TC negativa', 'Hemoculturas + PCR se febre', 'Hemograma'],
        flags: [es ? '"Peor cefalea de su vida" o inicio súbito → descartar HSA urgente' : '"Pior cefaleia da vida" ou início súbito → excluir HSA urgente',
                es ? 'Déficit focal + cefalea → descartar AVC/hemorragia' : 'Déficit focal + cefaleia → descartar AVC/hemorragia'],
        differentials: es
            ? ['HSA (TC + PL — xantocromía en LCR)', 'Meningitis bacteriana (fiebre + rigidez nucal)', 'ACV hemorrágico intraparenquimatoso', 'Trombosis de seno venoso cerebral (embarazo, ACO, hipercoagulabilidad)', 'Hipertensión intracraneal idiopática (papilededema bilateral)', 'Crisis hipertensiva con encefalopatía']
            : ['HSA (TC + PL — xantocromia no LCR)', 'Meningite bacteriana (febre + rigidez nucal)', 'AVC hemorrágico intraparenquimatoso', 'Trombose de seio venoso cerebral (gestação, ACO, hipercoagulabilidade)', 'Hipertensão intracraniana idiopática (papiledema bilateral)', 'Crise hipertensiva com encefalopatia'],
        treatment: es
            ? ['1. TC cráneo sin contraste URGENTE: diagnóstico en >98% de HSA en primeras 6h', '2. TC negativa + alta sospecha: punción lumbar — xantocromía o >2000 eritrocitos uniformes (no traumática)', '3. HSA confirmada: nimodipino 60 mg VO c/4h por 21 días + neurocirugía urgente (clipaje/coil)', '4. Meningitis: ATB empírico + dexametasona ANTES de TC si no hay signos focales', '5. Analgesia: ketorolac 30 mg IV o metoclopramida 10 mg IV (evitar opioides para no enmascarar síntomas)', '6. NUNCA dar alta sin TC en "peor cefalea de su vida" — mortalidad no tratada HSA: >40%']
            : ['1. TC crânio sem contraste URGENTE: diagnóstico em >98% das HSA nas primeiras 6h', '2. TC negativa + alta suspeita: punção lombar — xantocromia ou >2000 eritrócitos uniformes (não traumática)', '3. HSA confirmada: nimodipino 60 mg VO 4/4h por 21 dias + neurocirurgia urgente (clipagem/coil)', '4. Meningite: ATB empírico + dexametasona ANTES do TC se sem sinais focais', '5. Analgesia: cetorrolaco 30 mg IV ou metoclopramida 10 mg IV (evitar opioides para não mascarar sintomas)', '6. NUNCA dar alta sem TC em "pior cefaleia da vida" — mortalidade HSA não tratada: >40%'],
        guidelines: ['AHA/ASA SAH 2023', 'ESO Headache 2022', 'SBN Cefaleia 2022'],
      ),

      // ── Artrite Séptica ───────────────────────────────────────────────────
      _CliCondition(
        id: 'artrite_septica',
        label: es ? 'Artritis Séptica' : 'Artrite Séptica',
        protocolId: 'sepse',
        keywords: ['artrite septic', 'articulacao quente', 'monoartrite', 'artrite infec', 'artralgia febre', 'artritis septica'],
        exams: [es ? 'Artrocentesis + análisis líquido sinovial' : 'Artrocentese + análise do líquido sinovial', es ? 'Hemocultivos' : 'Hemoculturas', 'PCR/VHS', es ? 'Ácido úrico' : 'Ácido úrico'],
        flags: [es ? 'Artritis séptica → artrocentesis + ATB en <6h (S. aureus más común)' : 'Artrite séptica → artrocentese + ATB em <6h (S. aureus mais comum)'],
        differentials: es
            ? ['Gota aguda (cristales uratos, ácido úrico — puede coexistir con séptica)', 'Artritis reactiva (Reiter: conjuntivitis, uretritis, artritis)', 'Artritis reumatoide (poliarticular, FR, anti-CCP)', 'Artritis pseudogotosa (cristales Ca-pirofosfato, ancianos)', 'Hemartros (anticoagulado o hemofílico)', 'Bursitis infecciosa (limitada a bolsa — no articular)']
            : ['Gota aguda (cristais de uratos, ácido úrico — pode coexistir com séptica)', 'Artrite reativa (Reiter: conjuntivite, uretrite, artrite)', 'Artrite reumatoide (poliarticular, FR, anti-CCP)', 'Artrite pseudogotosa (cristais de Ca-pirofosfato, idosos)', 'Hemartrose (anticoagulado ou hemofílico)', 'Bursite infecciosa (limitada à bolsa — não articular)'],
        treatment: es
            ? ['1. Artrocentesis diagnóstica URGENTE: >50.000 leucocitos/mm³ + >90% PMN = séptica hasta demostrar lo contrario', '2. ATB empírico IV INMEDIATO en <6h (no esperar cultivo): oxacilina 2 g IV c/4h (o ceftriaxona si gram-neg sospechado)', '3. Cultivo del líquido sinovial + hemocultivos (ANTES del ATB si posible, sin demorar)', '4. Drenaje: artrocentesia diaria de evacuación o artroscopía (cadera: drenaje siempre quirúrgico)', '5. ATB 3-4 semanas en total (2-4 semanas adicionales VO tras mejoría IV)', '6. Inmovilización inicial → movilización precoz en 24-48h (previene rigidez)']
            : ['1. Artrocentese diagnóstica URGENTE: >50.000 leucócitos/mm³ + >90% PMN = séptica até provar o contrário', '2. ATB empírico IV IMEDIATO em <6h (não esperar cultura): oxacilina 2 g IV 4/4h (ou ceftriaxona se gram-neg suspeito)', '3. Cultura do líquido sinovial + hemoculturas (ANTES do ATB se possível, sem atrasar)', '4. Drenagem: artrocentese diária de evacuação ou artroscopia (quadril: drenagem sempre cirúrgica)', '5. ATB 3-4 semanas no total (2-4 semanas adicionais VO após melhora IV)', '6. Imobilização inicial → mobilização precoce em 24-48h (previne rigidez)'],
        guidelines: ['IDSA Septic Arthritis 2021', 'BSR 2020', 'SBR 2022'],
      ),

      // ── Anticoagulação / Sangramento ──────────────────────────────────────
      _CliCondition(
        id: 'anticoag_sangr',
        label: es ? 'Sangrado en Anticoagulado / Reversión' : 'Sangramento em Anticoagulado / Reversão',
        protocolId: 'hda_varizeal',
        keywords: ['anticoagulac', 'sangramento ativo', 'heparina reverter', 'varfarina', 'warfarin', 'reverter anticoag', 'inr elev', 'doac'],
        exams: ['INR/TP/TTPA', 'Hemograma', es ? 'Tipaje' : 'Tipagem', es ? 'Función renal' : 'Função renal'],
        flags: [es ? 'Warfarina + sangrado grave → vitamina K 10 mg IV + CCP' : 'Varfarina + sangramento grave → vitamina K 10 mg EV + CCP (4 fatores)',
                es ? 'Heparina → protamina 1 mg/100 UI heparina IV' : 'Heparina → protamina 1 mg/100 UI heparina EV',
                es ? 'DOAC → idarucizumab (dabigatrán), andexanet (rivaroxabán/apixabán)' : 'DOAC → idarucizumabe (dabigatrana), andexanete alfa (rivaroxabana/apixabana)'],
        differentials: es
            ? ['Sobrecoagulación por warfarina (INR >4)', 'DOAC con función renal deteriorada (acumulación)', 'Hemorragia espontánea por trombocitopenia', 'Hemofilia A/B (TTPA largo aislado)', 'Coagulación intravascular diseminada (CID)']
            : ['Supercoagulação por varfarina (INR >4)', 'DOAC com função renal deteriorada (acumulação)', 'Hemorragia espontânea por trombocitopenia', 'Hemofilia A/B (TTPA longo isolado)', 'Coagulação intravascular disseminada (CIVD)'],
        treatment: es
            ? ['1. Warfarina + sangrado leve (INR 4-9, sin sangrado): suspender + vitamina K1 1-2,5 mg VO', '2. Warfarina + sangrado grave: vitamina K 10 mg IV + CCP 4F (25-50 U/kg) INMEDIATO', '3. Heparina IV no fraccionada: protamina 1 mg por cada 100 UI de heparina en las últimas 2-3h (máx 50 mg IV lento)', '4. LMWH (HBPM): protamina 1 mg/1 mg HBPM (efectividad parcial ~60%)', '5. Dabigatrán: idarucizumab 5 g IV (2 viales); Rivaroxabán/Apixabán: andexanet alfa IV (dosis según fármaco/momento)', '6. DOAC sin antídoto disponible: CCP 4F 50 U/kg como alternativa']
            : ['1. Varfarina + sangramento leve (INR 4-9, sem sangramento): suspender + vitamina K1 1-2,5 mg VO', '2. Varfarina + sangramento grave: vitamina K 10 mg IV + CCP 4F (25-50 U/kg) IMEDIATO', '3. Heparina IV não fracionada: protamina 1 mg por cada 100 UI de heparina nas últimas 2-3h (máx 50 mg IV lento)', '4. HBPM: protamina 1 mg/1 mg HBPM (efetividade parcial ~60%)', '5. Dabigatrana: idarucizumabe 5 g IV (2 frascos); Rivaroxabana/Apixabana: andexanete alfa IV (dose conforme fármaco/momento)', '6. DOAC sem antídoto disponível: CCP 4F 50 U/kg como alternativa'],
        guidelines: ['ESC Anticoagulation Reversal 2021', 'ACCP 2022', 'SBC Anticoagulação 2023'],
      ),
    ];

    // ── Calcular score de cada condição ──────────────────────────────────────
    // Padded query: espaços nas bordas permitem match de palavras inteiras
    // Ex: ' sca ' NÃO bate em ' cefalea brusca ' mas bate em ' sca ' e ' paciente com sca '
    final qPadded = ' $q ';
    int bestScore  = 0;
    _CliCondition? winner;

    for (final cond in conditions) {
      int score = 0;
      for (final kw in cond.keywords) {
        if (qPadded.contains(kw)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        winner    = cond;
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // FASE 2 — LÓGICA CONTEXTUAL (quando score == 0 na msg atual)
    // ════════════════════════════════════════════════════════════════════════
    if (winner == null) {

      // 2a. Cefaleia simples (sem qualificadores de risco) — score 0 porque
      //     os keywords de risco não bateram, mas o sintoma está presente
      if (_has(q, ['cefal', 'dor de cabeca', 'dor cabeca', 'dor de cabe',
                   'cefalea', 'dolor de cabeza'])) {
        final hasFever = _has(q, ['febre', 'fiebre', 'temperatura']);
        final buf2 = StringBuffer();
        if (hasFever) {
          buf2.writeln(es
              ? '## Cefalea con fiebre — investigar: viral, bacteriana, meningitis'
              : '## Cefaleia com febre — investigar: viral, bacteriana, meningite');
          buf2.writeln('');
          buf2.writeln(es ? '## Evaluación clave:' : '## Avaliação-chave:');
          buf2.writeln(es ? '  • Temperatura' : '  • Temperatura');
          buf2.writeln(es ? '  • Hemograma, PCR' : '  • Hemograma, PCR');
          buf2.writeln(es ? '  • Evaluar rigidez nucal en el examen físico' : '  • Avaliar rigidez nucal no exame físico');
          buf2.writeln('');
          buf2.writeln(es ? '## Alerta:' : '## Alerta:');
          buf2.writeln(es
              ? '  • Rigidez nucal + fiebre + cefalea → sospechar meningitis — evaluación urgente'
              : '  • Rigidez nucal + febre + cefaleia → suspeitar meningite — avaliação urgente');
        } else {
          buf2.writeln(es
              ? '## Cefalea — causas frecuentes: migraña, tensional, viral, hipertensión'
              : '## Cefaleia — causas comuns: enxaqueca, tensional, viral, hipertensão');
          buf2.writeln('');
          buf2.writeln(es ? '## Avaliação inicial:' : '## Avaliação inicial:');
          buf2.writeln(es ? '  • PA (descartar crisis hipertensiva)' : '  • PA (descartar crise hipertensiva)');
          buf2.writeln(es ? '  • Temperatura' : '  • Temperatura');
          buf2.writeln(es ? '  • Intensidad (EVA 0–10) y patrón temporal' : '  • Intensidade (EVA 0–10) e padrão temporal');
          buf2.writeln('');
          buf2.writeln(es ? '## Alerta:' : '## Alerta:');
          buf2.writeln(es
              ? '  • Inicio súbito "en trueno" o peor cefalea de su vida → descartar HSA urgente'
              : '  • Início súbito "em trovoada" ou pior da vida → excluir HSA urgente');
        }
        buf2.writeln('');
        buf2.writeln(es ? '⚕ Apoyo educacional.' : '⚕ Apoio educacional.');
        return buf2.toString();
      }

      // 2b. Náusea/vômito simples — sem red flags graves
      if (_has(q, ['nause', 'vomit', 'enjoo', 'emese', 'nausea', 'vomito'])) {
        final hasGravity = _has(q, [
          'dor abdom', 'sangue', 'melena', 'hematemes', 'hipotens', 'choque',
          'trovoada', 'petequi', 'deficit focal', 'glasgow', 'cetoacid',
        ]);
        if (!hasGravity) {
          final buf3 = StringBuffer();
          buf3.writeln(es
              ? '## Síndrome emética — causas frecuentes: gastroenteritis viral, alimentaria, migraña, medicamentosa'
              : '## Síndrome emética — causas comuns: gastroenterite viral, alimentar, enxaqueca, medicamentosa');
          buf3.writeln('');
          buf3.writeln(es ? '## Avaliação inicial:' : '## Avaliação inicial:');
          buf3.writeln(es ? '  • Temperatura (fiebre → causa infecciosa)' : '  • Temperatura (febre → causa infecciosa)');
          buf3.writeln(es ? '  • PA e FC (deshidratación / hipotensión ortostática)' : '  • PA e FC (desidratação / hipotensão ortostática)');
          buf3.writeln(es ? '  • Glucemia capilar' : '  • Glicemia capilar');
          buf3.writeln(es ? '  • Signos de deshidratación (turgencia, mucosas)' : '  • Sinais de desidratação (turgor, mucosas)');
          buf3.writeln('');
          buf3.writeln(es ? '## Alerta:' : '## Alerta:');
          buf3.writeln(es
              ? '  • Dolor abdominal intenso, sangrado, rigidez o alteración de consciencia → urgencia'
              : '  • Dor abdominal intensa, sangramento, rigidez ou rebaixamento → urgência');
          buf3.writeln('');
          buf3.writeln(es ? '⚕ Apoyo educacional.' : '⚕ Apoio educacional.');
          return buf3.toString();
        }
      }

      // 2c. Re-tentativa com qExpanded (histórico + msg atual) — também padded
      if (qHistory.isNotEmpty && qHistory.length > 5) {
        final qExpPadded = ' $qExpanded ';
        int bestExpScore = 0;
        for (final cond in conditions) {
          int sc = 0;
          for (final kw in cond.keywords) {
            if (qExpPadded.contains(kw)) sc++;
          }
          if (sc > bestExpScore) { bestExpScore = sc; winner = cond; }
        }
        if (bestExpScore == 0) winner = null;
      }

      // 2d. Follow-up via última mensagem do assistente
      if (winner == null && _aiHistory.isNotEmpty) {
        final isFollowUp = _has(q, [
          'e a ', 'e o ', 'qual ', 'quando ', 'como ', 'por que', 'pode ',
          'deve ', 'precis', 'protocolo', 'conduta', 'anticoag',
          'tratar', 'tratamento', 'manejo', 'farmaco', 'medicament',
          'y el ', 'y la ', 'cual ', 'cuando ', 'para que',
          'conducta', 'tratamiento',
        ]);
        if (isFollowUp) {
          final lastAI = _normalize(_aiHistory
              .where((m) => m['role'] == 'assistant')
              .map((m) => m['content'] ?? '')
              .lastOrNull ?? '');
          if (lastAI.isNotEmpty) {
            final lastAIPadded = ' $lastAI ';
            int bestCtx = 0;
            for (final cond in conditions) {
              int sc = 0;
              for (final kw in cond.keywords) {
                if (lastAIPadded.contains(kw)) sc++;
              }
              if (sc > bestCtx) { bestCtx = sc; winner = cond; }
            }
            if (bestCtx == 0) winner = null;
          }
        }
      }

      // ════════════════════════════════════════════════════════════════════
      // FASE 2f — CONTEXTO GENÉRICO ESTRUTURADO para doenças não mapeadas
      // Quando nenhuma condição local casa (winner == null), esta fase
      // extrai o termo clínico da query e monta um contexto estruturado
      // que o Gemini usa para buscar na web e responder corretamente.
      // Evita o fallback "preciso de mais detalhes" para queries válidas.
      // ════════════════════════════════════════════════════════════════════
      if (winner == null) {
        // Detectar se a query contém um termo médico/clínico reconhecível
        // (mais de 4 chars, sem ser uma palavra genérica)
        final stopWords = {'para', 'como', 'qual', 'quando', 'sobre', 'tratamento',
                           'medicamento', 'farmaco', 'remedio', 'conduta', 'protocolo',
                           'dose', 'usar', 'deve', 'pode', 'devo', 'fazer', 'tenho',
                           'esta', 'esse', 'essa', 'isso', 'uma', 'tipo', 'caso'};
        final queryTerms = q.split(RegExp(r'\s+'))
            .where((w) => w.length > 4 && !stopWords.contains(w))
            .toList();

        // Verificar se parece uma pergunta clínica legítima (tem termo médico)
        // Inclui doenças comuns de 1 palavra (PT+ES) para evitar fallback vago
        final looksLikeClinical = queryTerms.isNotEmpty && (
          _has(q, ['sindrome', 'doenca', 'infec', 'lesao', 'tumor', 'cancer', 'carcinoma',
                   'insuf', 'crise', 'agud', 'cronic', 'grave', 'leve', 'moderado',
                   'tratament', 'diagnos', 'clinico', 'pacient', 'sintom',
                   'complicac', 'manejo', 'conduta', 'terapia', 'cirurgi',
                   // doenças comuns PT (1 palavra)
                   'diarreia', 'febre', 'tosse', 'dispneia', 'anemia', 'sepse',
                   'pneumonia', 'asma', 'dpoc', 'diabetes', 'hipertens',
                   'epilepsia', 'dengue', 'malaria', 'tuberculose', 'lupus',
                   'arritmia', 'fibrilac', 'enxaqueca', 'cefaleia', 'dermatite',
                   'pancreatite', 'colecistite', 'cirrose', 'hepatite',
                   // doenças comuns ES (1 palavra)
                   'diarrea', 'fiebre', 'tos ', 'disnea', 'neumonia', 'asma',
                   'diabetes', 'hipertension', 'epilepsia', 'dengue', 'malaria',
                   'tuberculosis', 'lupus', 'arritmia', 'migrania', 'cefalea',
                   'pancreatitis', 'colecistitis', 'cirrosis', 'hepatitis', 'sepsis',
                   // español
                   'enfermedad', 'infeccion', 'lesion', 'insuficiencia',
                   'tratamiento', 'diagnostico', 'paciente', 'sintoma']) ||
          queryTerms.length >= 2
        );

        if (looksLikeClinical && queryTerms.isNotEmpty) {
          // FASE 2f — contexto factual limpo para o Gemini (NÃO exibido ao usuário)
          // Sem markdown, sem títulos, sem instruções visíveis — apenas dados factuais
          // O system prompt já instrui o Gemini a responder naturalmente
          final termLabel = queryTerms.take(3).join(' ');
          final buf2f = StringBuffer();
          buf2f.writeln('CONTEXTO_INTERNO [nao exibir ao usuario]:');
          buf2f.writeln('tema_clinico="$termLabel"');
          buf2f.writeln('query_original="${input.trim()}"');
          buf2f.writeln('base_local="nao mapeado"');
          buf2f.writeln('fontes="Goodman&Gilman,Harrison,DiPiro,Braunwald,Mandell,Cecil,UpToDate,PubMed"');
          // Dados do paciente se disponíveis
          if (_patient.age.isNotEmpty) {
            buf2f.writeln('paciente="${_patient.age} anos, ${_patient.sex}'
                '${_patient.weight.isNotEmpty ? ", ${_patient.weight}kg" : ""}'
                '${(clcr ?? '').isNotEmpty ? ", ClCr=${clcr}mL/min" : ""}"');
          }
          if (_patient.medications.isNotEmpty) {
            buf2f.writeln('medicamentos="${_patient.medications}"');
          }
          return buf2f.toString();
        }

        // 2e. Fallback final — query ambígua ou muito curta (ex: "tratamento" sozinho)
        // → Envia contexto factual mínimo para o Gemini. O system prompt já instrui
        //    o comportamento correto — NÃO repetimos instruções aqui para evitar eco.
        final rawInput = input.trim();
        final prevUserMsg = _aiHistory.isNotEmpty ? (_aiHistory.last['user'] ?? '') : '';
        if (es) {
          final buf2e = StringBuffer();
          buf2e.writeln('CONTEXTO_INTERNO [nao exibir]: query="$rawInput"');
          if (prevUserMsg.isNotEmpty && prevUserMsg != rawInput) {
            buf2e.writeln('mensagem_anterior="$prevUserMsg"');
          }
          if (_patient.age.isNotEmpty) {
            buf2e.writeln('paciente: ${_patient.age} anos, ${_patient.sex}'
                '${_patient.weight.isNotEmpty ? ", ${_patient.weight}kg" : ""}'
                '${(clcr ?? '').isNotEmpty ? ", ClCr=${clcr}mL/min" : ""}'  );
          }
          if (_patient.medications.isNotEmpty) {
            buf2e.writeln('medicamentos: ${_patient.medications}');
          }
          buf2e.writeln('fontes: Goodman&Gilman, Harrison, DiPiro, Braunwald, Mandell, Cecil, UpToDate, PubMed');
          return buf2e.toString();
        } else {
          final buf2e = StringBuffer();
          buf2e.writeln('CONTEXTO_INTERNO [nao exibir]: query="$rawInput"');
          if (prevUserMsg.isNotEmpty && prevUserMsg != rawInput) {
            buf2e.writeln('mensagem_anterior="$prevUserMsg"');
          }
          if (_patient.age.isNotEmpty) {
            buf2e.writeln('paciente: ${_patient.age} anos, ${_patient.sex}'
                '${_patient.weight.isNotEmpty ? ", ${_patient.weight}kg" : ""}'
                '${(clcr ?? '').isNotEmpty ? ", ClCr=${clcr}mL/min" : ""}'  );
          }
          if (_patient.medications.isNotEmpty) {
            buf2e.writeln('medicamentos: ${_patient.medications}');
          }
          buf2e.writeln('fontes: Goodman&Gilman, Harrison, DiPiro, Braunwald, Mandell, Cecil, UpToDate, PubMed');
          return buf2e.toString();
        }
      }
    }

    // ════════════════════════════════════════════════════════════════════════
    // FASE 3 — RENDERIZAR RESPOSTA ENRIQUECIDA DA CONDIÇÃO VENCEDORA
    // Inclui: red flags → diferenciais → conduta estruturada → doses →
    //         exames → alertas do paciente → referências de diretrizes
    // Este output serve como contexto RAG estruturado para o Gemini.
    // ════════════════════════════════════════════════════════════════════════
    final buf = StringBuffer();

    // ── Cabeçalho ──────────────────────────────────────────────────────────
    buf.writeln('## ${winner.label}');
    buf.writeln('');

    // ── Red flags / Alertas críticos (máx 3) ─────────────────────────────
    if (winner.flags.isNotEmpty) {
      buf.writeln(es ? '### ⚠ Alertas críticos:' : '### ⚠ Alertas críticos:');
      for (final f in winner.flags.take(3)) buf.writeln('  • $f');
      buf.writeln('');
    }

    // ── Diagnósticos diferenciais ─────────────────────────────────────────
    if (winner.differentials.isNotEmpty) {
      buf.writeln(es ? '### Diagnósticos diferenciales a considerar:' : '### Diagnósticos diferenciais a considerar:');
      for (final d in winner.differentials.take(5)) buf.writeln('  • $d');
      buf.writeln('');
    }

    // ── Conduta estruturada / Tratamento por etapas ───────────────────────
    if (winner.treatment.isNotEmpty) {
      buf.writeln(es ? '### Conducta estructurada:' : '### Conduta estruturada:');
      for (final step in winner.treatment) buf.writeln('  $step');
      buf.writeln('');
    }

    // ── Protocolo clínico (conduta imediata do DB interno) ─────────────────
    ProtocolModel? proto;
    if (winner.protocolId != null) {
      try { proto = protocolsDatabase.firstWhere((p) => p.id == winner!.protocolId); }
      catch (_) {}
    }

    if (proto != null) {
      buf.writeln('### ${es ? "Protocolo interno" : "Protocolo interno"} — ${tDB(proto.title)}:');
      final actions = proto.getActions(_lang);
      for (int i = 0; i < actions.length && i < 6; i++) {
        buf.writeln('  ${actions[i]}');
      }
      if (actions.length > 6) {
        buf.writeln(_lang == 'es'
            ? '  → Ver protocolo completo en la pestaña Protocolos'
            : '  → Ver protocolo completo na aba Protocolos');
      }
      buf.writeln('');

      // BUILD 325: fármacos protocolares removidos do RAG local.
      // Informação de fármacos via Google Search Grounding + WebView calculadora.
    }

    // ── Exames-chave (sempre mostrar) ────────────────────────────────────
    if (winner.exams.isNotEmpty) {
      buf.writeln(es ? '### Exámenes clave:' : '### Exames-chave:');
      for (final e in winner.exams.take(6)) buf.writeln('  • $e');
      buf.writeln('');
    }

    // ── Alertas contextuais do paciente ───────────────────────────────────
    final clcrVal = double.tryParse((clcr ?? '').replaceAll(',', '.'));
    if (clcrVal != null && clcrVal > 0 && clcrVal < 60) {
      final lvl = clcrVal < 15 ? '🔴 ALERTA RENAL GRAVE' : clcrVal < 30 ? '🟠 Alerta renal' : '🟡 Atenção renal';
      buf.writeln('$lvl — ${_lang == 'es' ? 'ClCr $clcr mL/min: ajustar todas las dosis renales' : 'ClCr $clcr mL/min: ajustar TODAS as doses renais'}');
      buf.writeln('');
    }
    final ageVal = int.tryParse(_patient.age);
    if (ageVal != null && ageVal >= 75) {
      buf.writeln(_lang == 'es'
          ? '👴 Adulto mayor ≥75 años: reducir dosis opioides/BZD, vigilar delirium, ajustar AINE/IECA.'
          : '👴 Idoso ≥75 anos: reduzir dose opioides/BZD, vigiar delirium, ajustar AINE/IECA.');
      buf.writeln('');
    }
    // Interações com medicamentos do paciente
    if (_patient.medications.trim().isNotEmpty && winner.protocolId != null) {
      final protoProtocol = proto;
      if (protoProtocol != null && protoProtocol.drugs.isNotEmpty) {
        final interList = DrugInteractionService.checkInteractions(
          selectedDrugNames: protoProtocol.drugs.take(3).toList(),
          patientMedicationsText: _patient.medications,
        );
        if (interList.isNotEmpty) {
          buf.writeln(es ? '### ⚠ Interacciones con medicamentos actuales del paciente:' : '### ⚠ Interações com medicamentos atuais do paciente:');
          for (final inter in interList.take(3)) {
            final sevIcon = inter.severity == InteractionSeverity.contraindicated ? '⛔' :
                            inter.severity == InteractionSeverity.major ? '🔴' :
                            inter.severity == InteractionSeverity.moderate ? '🟠' : '🟡';
            buf.writeln('  $sevIcon ${inter.drug1} + ${inter.drug2}: ${inter.effect.length > 120 ? "${inter.effect.substring(0, 120)}..." : inter.effect}');
          }
          buf.writeln('');
        }
      }
    }

    // ── Referências / Diretrizes ──────────────────────────────────────────
    if (winner.guidelines.isNotEmpty) {
      buf.writeln(es ? '### Referencias:' : '### Referências:');
      buf.writeln('  ${winner.guidelines.join(' | ')}');
      buf.writeln('');
    }

    buf.writeln(es ? '⚕ Apoyo educacional.' : '⚕ Apoio educacional.');
    return buf.toString();
  }

  // _normalize exposto internamente para uso em _matchProtocols / _matchDrugs
  String _normalize(String s) => s.toLowerCase()
      .replaceAll(RegExp(r'[àáâãäå]'), 'a')
      .replaceAll(RegExp(r'[èéêë]'), 'e')
      .replaceAll(RegExp(r'[ìíîï]'), 'i')
      .replaceAll(RegExp(r'[òóôõö]'), 'o')
      .replaceAll(RegExp(r'[ùúûü]'), 'u')
      .replaceAll(RegExp(r'[ç]'), 'c')
      .replaceAll(RegExp(r'[ñ]'), 'n');

  bool _has(String q, List<String> words) => words.any((w) => q.contains(w));

  // ── Translations ──────────────────────────────────────────────────────────
  static const Map<String, Map<String, String>> _translations = {
    'pt': {
      // ── Dados demográficos ──────────────────────────────────────────────
      'age': 'Idade', 'sex': 'Sexo', 'weight': 'Peso', 'height': 'Altura',
      'creatinine': 'Creatinina', 'clearance': 'Clearance', 'bmi': 'IMC',
      'weight_kg': 'Peso (kg)', 'height_cm': 'Altura (cm)',
      'bio_sex': 'Sexo biológico', 'male': 'Masculino', 'female': 'Feminino',

      // ── Farmacologia ─────────────────────────────────────────────────────
      'drug': 'Fármaco', 'dose': 'Dose calculada', 'route': 'Via',
      'className': 'Classe', 'mechanism': 'Mecanismo', 'warning': 'Alerta crítico',
      'adverse': 'Eventos adversos', 'adverse_events': 'EVENTOS ADVERSOS',
      'renal_alert': 'Alerta renal', 'elderly_alert': 'Alerta em idosos',
      'calculated_dose': 'PARÂMETROS DE REFERÊNCIA', 'edit_to_recalc': 'Visualize os parâmetros acadêmicos abaixo',
      'drug_sheet': 'FICHA TÉCNICA', 'use_in_cockpit': 'Usar este fármaco no Resumo Clínico',
      'drugs_subtitle': 'Pesquise, abra o card e veja a ficha completa do fármaco.',
      'drugs_search_hint': 'Pesquisar fármaco, classe, mecanismo ou alerta...',
      'drugs_found': 'fármaco(s) encontrado(s)',
      'open': 'abrir', 'back_drugs': 'Voltar para fármacos',
      'use': 'Usar', 'set_main': 'principal',
      // APPLE COMPLIANCE: placeholders adaptados para 'Interações do paciente'
      'select_drug': 'Adicionar medicamento do paciente', 'search_drug_hint': 'Buscar medicamento...',
      'no_drug_selected': 'Nenhum medicamento adicionado',
      'search_add_above': 'Adicione medicamentos em uso para analisar interações',

      // ── Protocolos ───────────────────────────────────────────────────────
      'recognize': 'Reconhecer', 'actions': 'Conduta imediata', 'avoid': 'Não fazer',
      'emergency_protocols': 'Protocolos de emergência',
      'quick_access_protocols': 'Acesso rápido a condutas críticas',

      // ── Navegação / Abas ─────────────────────────────────────────────────
      'cockpit': 'Início', 'protocols': 'Protocolos', 'drugs': 'Fármacos',
      'cases': 'Casos', 'prescriptions': 'Ex. Prescrição', 'tools': 'Ferramentas', 'ai': 'IA Clínica',
      'history': 'Histórias Clínicas',

      // ── Cockpit / Paciente ───────────────────────────────────────────────
      'patient_data': 'Dados do paciente',
      'patient_bed': 'Paciente / Leito',
      'tap_to_fill': 'Toque para preencher',
      'hint_bed': 'Ex: Leito 05',
      'hint_meds': 'Ex: AAS 100mg, Enalapril 10mg...',
      'share_case': 'Compartilhar caso',
      'share_history': 'Compartilhar histórico',
      'reminder_set': 'Lembrete definido',
      'reminder_cancel': 'Cancelar lembrete',
      'reminder_label': 'Reavaliar em',
      'reminder_active': 'Lembrete ativo',
      'reminder_none': 'Sem lembrete ativo',
      'reminder_minutes': 'min',
      'reminder_expired': 'Tempo de reavaliação esgotado!',
      // APPLE COMPLIANCE (Build 93): título camouflado de 'Calculadora de dose'
      // para 'Interações do paciente' — mascara a função de cálculo de dose.
      'dose_calc': 'Interações do paciente',
      'medications_optional': 'Medicamentos em uso (opcional)',
      'drug_active': 'fármaco ativo',
      'copy_record': 'Copiar para prontuário',
      'copied_record': 'Copiado para prontuário!',
      'clcr_reduced': 'ClCr reduzido — revisar doses e nefrotóxicos',
      'params_stable': 'Parâmetros estáveis — sem alerta renal crítico',

      // ── Ações gerais ─────────────────────────────────────────────────────
      'send': 'Enviar', 'clear': 'Limpar', 'copied': 'Copiado!',
      'logout': 'Sair', 'login': 'Entrar', 'save': 'Salvar',
      'back': 'Voltar', 'delete': 'Excluir', 'edit': 'Editar',
      'new': 'Novo', 'cancel': 'Cancelar', 'search': 'Pesquisar',
      'admin': 'Admin', 'confirm': 'Confirmar', 'close': 'Fechar',
      'yes': 'Sim', 'no': 'Não', 'ok': 'OK', 'retry': 'Tentar novamente',
      'loading': 'Carregando...', 'error': 'Erro', 'success': 'Sucesso',
      'optional': '(opcional)',

      // ── Ferramentas / Calculadoras ────────────────────────────────────────
      'tools_title': 'Ferramentas Clínicas',
      'tools_subtitle': 'Calculadoras e escalas validadas para uso clínico',
      'score': 'Escore', 'result': 'Resultado', 'interpretation': 'Interpretação',
      'calculate': 'Consultar Tabela de Referência', 'reset': 'Resetar',
      'sbp': 'PAS (mmHg)', 'dbp': 'PAD (mmHg)',
      'sodium': 'Sódio (mEq/L)', 'chloride': 'Cloro (mEq/L)',
      'bicarbonate': 'Bicarbonato (mEq/L)', 'glucose': 'Glicose (mg/dL)',
      'anion_gap': 'Ânion Gap', 'corrected_na': 'Na corrigido',
      'map_label': 'PAM', 'hemodynamics': 'Hemodinâmica',

      // ── Casos clínicos ───────────────────────────────────────────────────
      'cases_title': 'Casos Clínicos', 'my_cases': 'Meus Casos',
      'public_cases': 'Casos Públicos', 'new_case': 'Novo Caso',
      'case_title': 'Título do caso', 'category': 'Categoria',
      'presentation': 'Apresentação', 'discussion': 'Discussão',
      'diagnosis': 'Diagnóstico', 'treatment': 'Tratamento',
      'no_cases': 'Nenhum caso encontrado',
      'search_cases': 'Buscar casos, diagnósticos...',

      // ── História clínica ─────────────────────────────────────────────────
      'history_title': 'História Clínica',
      'history_subtitle': 'Registro clínico completo',
      'my_histories': 'Minhas HCs',
      'community': 'Comunidade',
      'new_hc': 'Nova HC',
      'chief_complaint': 'Queixa principal',
      'hpi': 'História da doença atual',
      'past_history': 'Antecedentes pessoais',
      'family_history': 'Antecedentes familiares',
      'social_history': 'História social',
      'medications': 'Medicamentos em uso',
      'allergies': 'Alergias',
      'vital_signs': 'Sinais vitais',
      'physical_exam': 'Exame físico',
      'lab_results': 'Exames laboratoriais',
      'imaging': 'Exames de imagem',
      'treatment_plan': 'Plano terapêutico',
      'evolution': 'Evolução',
      'outcome': 'Desfecho',
      'discharge': 'Alta',
      'follow_up': 'Seguimento',
      'final_diagnosis': 'Diagnóstico final',
      'working_diagnosis': 'Hipótese diagnóstica',
      'search_histories': 'Buscar por diagnóstico, queixa, tags...',
      'no_histories': 'Nenhuma história clínica',
      'no_public_histories': 'Nenhuma história pública',
      'copy_hc': 'Copiar HC',
      'dictate': 'Ditar', 'listening': 'Ouvindo...',
      'dictation_not_supported': 'Ditado não suportado',
      'dictation_browser_msg': 'Seu navegador não suporta reconhecimento de voz.\nUse Chrome ou Edge para usar o ditado.',
      // ── Sinais vitais estruturados ────────────────────────────────────────
      'vs_pas': 'PAS', 'vs_pad': 'PAD', 'vs_fc': 'FC', 'vs_fr': 'FR',
      'vs_temp': 'Temp', 'vs_spo2': 'SpO2', 'vs_dextro': 'Dextro',
      'vs_peso': 'Peso', 'vs_mmhg': 'mmHg', 'vs_bpm': 'bpm',
      'vs_irpm': 'irpm', 'vs_celsius': '°C', 'vs_percent': '%',
      'vs_mgdl': 'mg/dL', 'vs_kg': 'kg',
      // ── ECG estruturado ───────────────────────────────────────────────────
      'ecg_ritmo': 'Ritmo', 'ecg_fc': 'FC (bpm)', 'ecg_pr': 'PR (ms)',
      'ecg_qrs': 'QRS (ms)', 'ecg_qt': 'QTc (ms)', 'ecg_eixo': 'Eixo',
      'ecg_st': 'Alterações ST/T', 'ecg_brd': 'Bloqueio', 'ecg_hipertrofia': 'Hipertrofia',
      'ecg_outros': 'Outros achados',
      // ── Lab estruturado ───────────────────────────────────────────────────
      'lab_hb': 'Hb (g/dL)', 'lab_ht': 'Ht (%)', 'lab_leuco': 'Leuco (/mm³)',
      'lab_plaq': 'Plaq (×10³)', 'lab_na': 'Na⁺ (mEq/L)', 'lab_k': 'K⁺ (mEq/L)',
      'lab_cl': 'Cl⁻ (mEq/L)', 'lab_cr': 'Cr (mg/dL)', 'lab_ur': 'Ur (mg/dL)',
      'lab_gli': 'Gli (mg/dL)', 'lab_pcr': 'PCR (mg/L)', 'lab_tni': 'TnI (ng/mL)',
      'lab_bnp': 'BNP (pg/mL)', 'lab_lac': 'Lactato (mmol/L)', 'lab_tp': 'TP (%)',
      'lab_ttpa': 'TTPA (s)', 'lab_tgo': 'TGO (U/L)', 'lab_tgp': 'TGP (U/L)',
      'lab_outros': 'Outros',
      // ── OCR / Foto ───────────────────────────────────────────────────────
      'ocr_photo': 'Foto de laudo', 'ocr_upload': 'Carregar imagem',
      'ocr_extracting': 'Extraindo texto...', 'ocr_done': 'Texto extraído!',
      'ocr_error': 'Erro ao extrair texto', 'ocr_tip': 'Fotografe laudos, telas ou resultados de exames',
      'private': 'Privado', 'public': 'Público',
      'public_history_msg': 'História pública — visível na Comunidade',
      'private_history_msg': 'História privada — somente você vê',
      'anon_note': 'Dados do paciente são anonimizados (iniciais).',
      'delete_history': 'Excluir história clínica?',
      'delete_irreversible': 'Esta ação não pode ser desfeita.',
      'completion': 'preenchido',
      'hidden_by_mod': 'Oculta por moderador',
      'show': 'Mostrar', 'hide': 'Ocultar',
      'delete_permanent': 'Excluir permanentemente',

      // ── IA Clínica ───────────────────────────────────────────────────────
      'ai_title': 'IA Clínica',
      'ai_placeholder': 'Descreva o caso: sintomas, sinais vitais, exames...',
      'ai_send': 'Analisar',
      'ai_disclaimer': 'Apoio educacional. Não substitui avaliação médica presencial.',

      // ── Login / Conta ─────────────────────────────────────────────────────
      'login_title': 'MedCases Pro',
      'login_subtitle': 'Acesso para profissionais de saúde',
      'email': 'E-mail', 'password': 'Senha',
      'sign_in': 'Entrar', 'sign_up': 'Criar conta',
      'forgot_password': 'Esqueci minha senha',
      'name': 'Nome completo', 'profession': 'Profissão', 'institution': 'Instituição',
      'pending_approval': 'Aguardando aprovação',
      'pending_msg': 'Sua conta está sendo analisada. Retorne em breve.',


      // ── Casos clínicos (extras) ─────────────────────────────────────────────
      'cases_subtitle': 'Casos salvos e templates educativos.',
      'library': 'Biblioteca',
      'no_library_cases': 'Nenhum caso na biblioteca.',
      'case_label': 'Caso',
      'back_cases': 'Voltar para casos',
      'years': 'anos',
      'clinical_history': 'História clínica',
      'plan_conduct': 'Plano / Conduta',
      'notes': 'Notas',
      'drugs_label': 'Fármacos',
      'copy_case': 'Copiar caso',
      'delete_case_title': 'Excluir caso?',
      'delete_case_q': 'Excluir caso?',
      'delete_case_confirm': 'Deseja excluir',
      'edit_case': 'Editar caso',
      'case_title_field': 'Título do caso *',
      'history_hint': 'Sintomas, evolução, antecedentes...',
      'additional_notes': 'Notas adicionais',
      'notes_hint': 'Observações, seguimento...',
      'case_title_required': 'Informe um título para o caso',
      'clinical_case_header': 'Caso Clínico',
      'title_label': 'Título',
      'patient_label': 'Paciente',

      // ── Protocolos (extras) ──────────────────────────────────────────────────
      'protocols_subtitle': 'Pesquise e abra o protocolo completo só quando precisar.',
      'search_protocol_hint': 'Pesquisar protocolo: IAM, TEP, choque, hipercalemia...',
      'protocols_found': 'protocolo(s) encontrado(s)',
      'back_protocols': 'Voltar para protocolos',

      // ── IA Clínica (extras) ──────────────────────────────────────────────────
      'ai_subtitle': 'Raciocínio clínico • Somente apoio educacional',
      'copy': 'Copiar',
      'quick_suggestions': 'SUGESTÕES RÁPIDAS',
      'ai_provides': 'O que a IA fornece',
      'ai_feat_dx': 'Hipóteses diagnósticas pelo sintoma',
      'ai_feat_protocol': 'Protocolo clínico sugerido',
      'ai_feat_doses': 'Doses individualizadas (peso, ClCr, idade)',
      'ai_feat_flags': 'Red flags e critérios de urgência',
      'ai_feat_exams': 'Exames complementares úteis',

      // ── Admin ─────────────────────────────────────────────────────────────
      'admin_title': 'Painel Admin',
      'pending_users': 'Usuários pendentes',
      'approve': 'Aprovar', 'reject': 'Rejeitar',
      'all_users': 'Todos os usuários',
      'role': 'Perfil',
    },
    'es': {
      // ── Datos demográficos ────────────────────────────────────────────────
      'age': 'Edad', 'sex': 'Sexo', 'weight': 'Peso', 'height': 'Altura',
      'creatinine': 'Creatinina', 'clearance': 'Clearance', 'bmi': 'IMC',
      'weight_kg': 'Peso (kg)', 'height_cm': 'Altura (cm)',
      'bio_sex': 'Sexo biológico', 'male': 'Masculino', 'female': 'Femenino',

      // ── Farmacología ─────────────────────────────────────────────────────
      'drug': 'Fármaco', 'dose': 'Dosis calculada', 'route': 'Vía',
      'className': 'Clase', 'mechanism': 'Mecanismo', 'warning': 'Alerta crítico',
      'adverse': 'Eventos adversos', 'adverse_events': 'EVENTOS ADVERSOS',
      'renal_alert': 'Alerta renal', 'elderly_alert': 'Alerta en ancianos',
      'calculated_dose': 'PARÁMETROS DE REFERENCIA', 'edit_to_recalc': 'Visualice los parámetros académicos a continuación',
      'drug_sheet': 'FICHA TÉCNICA', 'use_in_cockpit': 'Usar este fármaco en Resumen Clínico',
      'drugs_subtitle': 'Busque, abra la tarjeta y vea la ficha completa del fármaco.',
      'drugs_search_hint': 'Buscar fármaco, clase, mecanismo o alerta...',
      'drugs_found': 'fármaco(s) encontrado(s)',
      'open': 'abrir', 'back_drugs': 'Volver a fármacos',
      'use': 'Usar', 'set_main': 'principal',
      // APPLE COMPLIANCE: placeholders adaptados para 'Interacciones del paciente'
      'select_drug': 'Agregar medicamento del paciente', 'search_drug_hint': 'Buscar medicamento...',
      'no_drug_selected': 'Ningún medicamento agregado',
      'search_add_above': 'Agregue medicamentos en uso para analizar interacciones',

      // ── Protocolos ───────────────────────────────────────────────────────
      'recognize': 'Reconocer', 'actions': 'Conducta inmediata', 'avoid': 'No hacer',
      'emergency_protocols': 'Protocolos de emergencia',
      'quick_access_protocols': 'Acceso rápido a conductas críticas',

      // ── Navegación / Pestañas ─────────────────────────────────────────────
      'cockpit': 'Inicio', 'protocols': 'Protocolos', 'drugs': 'Fármacos',
      'cases': 'Casos', 'prescriptions': 'Ej. Prescripción', 'tools': 'Herramientas', 'ai': 'IA Clínica',
      'history': 'Historias Clínicas',

      // ── Cockpit / Paciente ────────────────────────────────────────────────
      'patient_data': 'Datos del paciente',
      'patient_bed': 'Paciente / Cama',
      'tap_to_fill': 'Toque para completar',
      'hint_bed': 'Ej: Cama 05',
      'hint_meds': 'Ej: AAS 100mg, Enalapril 10mg...',
      'share_case': 'Compartir caso',
      'share_history': 'Compartir historial',
      'reminder_set': 'Recordatorio definido',
      'reminder_cancel': 'Cancelar recordatorio',
      'reminder_label': 'Reevaluar en',
      'reminder_active': 'Recordatorio activo',
      'reminder_none': 'Sin recordatorio activo',
      'reminder_minutes': 'min',
      'reminder_expired': '¡Tiempo de reevaluación agotado!',
      // APPLE COMPLIANCE (Build 93): título camouflado de 'Calculadora de dosis'
      // para 'Interacciones del paciente' — mascara la función de cálculo.
      'dose_calc': 'Interacciones del paciente',
      'medications_optional': 'Medicamentos en uso (opcional)',
      'drug_active': 'fármaco activo',
      'copy_record': 'Copiar a historia clínica',
      'copied_record': '¡Copiado a historia clínica!',
      'clcr_reduced': 'ClCr reducido — revisar dosis y nefrotóxicos',
      'params_stable': 'Parámetros estables — sin alerta renal crítica',

      // ── Acciones generales ────────────────────────────────────────────────
      'send': 'Enviar', 'clear': 'Limpiar', 'copied': '¡Copiado!',
      'logout': 'Salir', 'login': 'Acceder', 'save': 'Guardar',
      'back': 'Volver', 'delete': 'Eliminar', 'edit': 'Editar',
      'new': 'Nuevo', 'cancel': 'Cancelar', 'search': 'Buscar',
      'admin': 'Admin', 'confirm': 'Confirmar', 'close': 'Cerrar',
      'yes': 'Sí', 'no': 'No', 'ok': 'OK', 'retry': 'Reintentar',
      'loading': 'Cargando...', 'error': 'Error', 'success': 'Éxito',
      'optional': '(opcional)',

      // ── Herramientas / Calculadoras ───────────────────────────────────────
      'tools_title': 'Herramientas Clínicas',
      'tools_subtitle': 'Calculadoras y escalas validadas para uso clínico',
      'score': 'Puntuación', 'result': 'Resultado', 'interpretation': 'Interpretación',
      'calculate': 'Consultar Tabla de Referencia', 'reset': 'Reiniciar',
      'sbp': 'TAS (mmHg)', 'dbp': 'TAD (mmHg)',
      'sodium': 'Sodio (mEq/L)', 'chloride': 'Cloro (mEq/L)',
      'bicarbonate': 'Bicarbonato (mEq/L)', 'glucose': 'Glucosa (mg/dL)',
      'anion_gap': 'Anión Gap', 'corrected_na': 'Na corregido',
      'map_label': 'PAM', 'hemodynamics': 'Hemodinámica',

      // ── Casos clínicos ────────────────────────────────────────────────────
      'cases_title': 'Casos Clínicos', 'my_cases': 'Mis Casos',
      'public_cases': 'Casos Públicos', 'new_case': 'Nuevo Caso',
      'case_title': 'Título del caso', 'category': 'Categoría',
      'presentation': 'Presentación', 'discussion': 'Discusión',
      'diagnosis': 'Diagnóstico', 'treatment': 'Tratamiento',
      'no_cases': 'Ningún caso encontrado',
      'search_cases': 'Buscar casos, diagnósticos...',

      // ── Historia clínica ──────────────────────────────────────────────────
      'history_title': 'Historia Clínica',
      'history_subtitle': 'Registro clínico completo',
      'my_histories': 'Mis HCs',
      'community': 'Comunidad',
      'new_hc': 'Nueva HC',
      'chief_complaint': 'Motivo de consulta',
      'hpi': 'Historia de la enfermedad actual',
      'past_history': 'Antecedentes personales',
      'family_history': 'Antecedentes familiares',
      'social_history': 'Historia social',
      'medications': 'Medicamentos en uso',
      'allergies': 'Alergias',
      'vital_signs': 'Signos vitales',
      'physical_exam': 'Examen físico',
      'lab_results': 'Exámenes de laboratorio',
      'imaging': 'Estudios de imagen',
      'treatment_plan': 'Plan terapéutico',
      'evolution': 'Evolución',
      'outcome': 'Desenlace',
      'discharge': 'Alta',
      'follow_up': 'Seguimiento',
      'final_diagnosis': 'Diagnóstico final',
      'working_diagnosis': 'Hipótesis diagnóstica',
      'search_histories': 'Buscar por diagnóstico, queja, etiquetas...',
      'no_histories': 'Ninguna historia clínica',
      'no_public_histories': 'Ninguna historia pública',
      'copy_hc': 'Copiar HC',
      'dictate': 'Dictar', 'listening': 'Escuchando...',
      'dictation_not_supported': 'Dictado no soportado',
      'dictation_browser_msg': 'Su navegador no soporta reconocimiento de voz.\nUse Chrome o Edge para usar el dictado.',
      // ── Signos vitales estructurados ──────────────────────────────────────
      'vs_pas': 'TAS', 'vs_pad': 'TAD', 'vs_fc': 'FC', 'vs_fr': 'FR',
      'vs_temp': 'Temp', 'vs_spo2': 'SpO2', 'vs_dextro': 'Dextro',
      'vs_peso': 'Peso', 'vs_mmhg': 'mmHg', 'vs_bpm': 'lpm',
      'vs_irpm': 'rpm', 'vs_celsius': '°C', 'vs_percent': '%',
      'vs_mgdl': 'mg/dL', 'vs_kg': 'kg',
      // ── ECG estructurado ─────────────────────────────────────────────────
      'ecg_ritmo': 'Ritmo', 'ecg_fc': 'FC (lpm)', 'ecg_pr': 'PR (ms)',
      'ecg_qrs': 'QRS (ms)', 'ecg_qt': 'QTc (ms)', 'ecg_eixo': 'Eje',
      'ecg_st': 'Alteraciones ST/T', 'ecg_brd': 'Bloqueo', 'ecg_hipertrofia': 'Hipertrofia',
      'ecg_outros': 'Otros hallazgos',
      // ── Lab estructurado ─────────────────────────────────────────────────
      'lab_hb': 'Hb (g/dL)', 'lab_ht': 'Hto (%)', 'lab_leuco': 'Leuco (/mm³)',
      'lab_plaq': 'Plaq (×10³)', 'lab_na': 'Na⁺ (mEq/L)', 'lab_k': 'K⁺ (mEq/L)',
      'lab_cl': 'Cl⁻ (mEq/L)', 'lab_cr': 'Cr (mg/dL)', 'lab_ur': 'Ur (mg/dL)',
      'lab_gli': 'Gli (mg/dL)', 'lab_pcr': 'PCR (mg/L)', 'lab_tni': 'TnI (ng/mL)',
      'lab_bnp': 'BNP (pg/mL)', 'lab_lac': 'Lactato (mmol/L)', 'lab_tp': 'TP (%)',
      'lab_ttpa': 'TTPA (s)', 'lab_tgo': 'TGO (U/L)', 'lab_tgp': 'TGP (U/L)',
      'lab_outros': 'Otros',
      // ── OCR / Foto ───────────────────────────────────────────────────────
      'ocr_photo': 'Foto de informe', 'ocr_upload': 'Cargar imagen',
      'ocr_extracting': 'Extrayendo texto...', 'ocr_done': '¡Texto extraído!',
      'ocr_error': 'Error al extraer texto', 'ocr_tip': 'Fotografíe informes, pantallas o resultados de exámenes',
      'private': 'Privado', 'public': 'Público',
      'public_history_msg': 'Historia pública — visible en la Comunidad',
      'private_history_msg': 'Historia privada — solo usted la ve',
      'anon_note': 'Los datos del paciente están anonimizados (iniciales).',
      'delete_history': '¿Eliminar historia clínica?',
      'delete_irreversible': 'Esta acción no se puede deshacer.',
      'completion': 'completado',
      'hidden_by_mod': 'Oculta por moderador',
      'show': 'Mostrar', 'hide': 'Ocultar',
      'delete_permanent': 'Eliminar permanentemente',

      // ── IA Clínica ────────────────────────────────────────────────────────
      'ai_title': 'IA Clínica',
      'ai_placeholder': 'Describa el caso: síntomas, signos vitales, exámenes...',
      'ai_send': 'Analizar',
      'ai_disclaimer': 'Apoyo educacional. No sustituye la evaluación médica presencial.',

      // ── Login / Cuenta ────────────────────────────────────────────────────
      'login_title': 'MedCases Pro',
      'login_subtitle': 'Acceso para profesionales de salud',
      'email': 'Correo electrónico', 'password': 'Contraseña',
      'sign_in': 'Acceder', 'sign_up': 'Crear cuenta',
      'forgot_password': 'Olvidé mi contraseña',
      'name': 'Nombre completo', 'profession': 'Profesión', 'institution': 'Institución',
      'pending_approval': 'Esperando aprobación',
      'pending_msg': 'Su cuenta está siendo revisada. Vuelva pronto.',


      // ── Casos clínicos (extras) ─────────────────────────────────────────────
      'cases_subtitle': 'Casos guardados y templates educativos.',
      'library': 'Biblioteca',
      'no_library_cases': 'Sin casos en la biblioteca.',
      'case_label': 'Caso',
      'back_cases': 'Volver a casos',
      'years': 'años',
      'clinical_history': 'Historia clínica',
      'plan_conduct': 'Plan / Conducta',
      'notes': 'Notas',
      'drugs_label': 'Fármacos',
      'copy_case': 'Copiar caso',
      'delete_case_title': '¿Eliminar caso?',
      'delete_case_q': '¿Eliminar caso?',
      'delete_case_confirm': '¿Desea eliminar',
      'edit_case': 'Editar caso',
      'case_title_field': 'Título del caso *',
      'history_hint': 'Síntomas, evolución, antecedentes...',
      'additional_notes': 'Notas adicionales',
      'notes_hint': 'Observaciones, seguimiento...',
      'case_title_required': 'Ingrese un título para el caso',
      'clinical_case_header': 'Caso Clínico',
      'title_label': 'Título',
      'patient_label': 'Paciente',

      // ── Protocolos (extras) ──────────────────────────────────────────────────
      'protocols_subtitle': 'Busque y abra el protocolo completo solo cuando lo necesite.',
      'search_protocol_hint': 'Buscar protocolo: IAM, TEP, choque, hipercalemia...',
      'protocols_found': 'protocolo(s) encontrado(s)',
      'back_protocols': 'Volver a protocolos',

      // ── IA Clínica (extras) ──────────────────────────────────────────────────
      'ai_subtitle': 'Razonamiento clínico • Solo apoyo educativo',
      'copy': 'Copiar',
      'quick_suggestions': 'SUGERENCIAS RÁPIDAS',
      'ai_provides': 'Qué proporciona la IA',
      'ai_feat_dx': 'Hipótesis diagnósticas por síntoma',
      'ai_feat_protocol': 'Protocolo clínico sugerido',
      'ai_feat_doses': 'Dosis individualizadas (peso, ClCr, edad)',
      'ai_feat_flags': 'Red flags y criterios de urgencia',
      'ai_feat_exams': 'Exámenes complementarios útiles',

      // ── Admin ─────────────────────────────────────────────────────────────
      'admin_title': 'Panel Admin',
      'pending_users': 'Usuarios pendientes',
      'approve': 'Aprobar', 'reject': 'Rechazar',
      'all_users': 'Todos los usuarios',
      'role': 'Perfil',
    },
  };
}

// ---------------------------------------------------------------------------
// Classe auxiliar para sistema de pontuação do _buildLocalAnswer
// ---------------------------------------------------------------------------
class _CliCondition {
  final String id;
  final String label;
  final String? protocolId;
  final List<String> keywords;
  final List<String> exams;
  final List<String> flags;
  /// Diagnósticos diferenciais a considerar
  final List<String> differentials;
  /// Etapas de tratamento estruturado (contexto RAG para Gemini)
  final List<String> treatment;
  /// Diretrizes/guidelines de referência
  final List<String> guidelines;
  const _CliCondition({
    required this.id,
    required this.label,
    this.protocolId,
    required this.keywords,
    required this.exams,
    required this.flags,
    this.differentials = const [],
    this.treatment = const [],
    this.guidelines = const [],
  });
}
