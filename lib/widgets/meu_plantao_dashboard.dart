// meu_plantao_dashboard.dart — v6 (Build 325)
// Feature "Meu Plantão / Mi Guardia" — UI CLEAN MODULAR
//
// v6 CHANGES (Build 325 — SUPER ORDEM MASTER 325):
//   • MANDATO 1: _firestorePermissionDenied latch — interrompe reconexão em loop
//               ao receber permission-denied/403. Stream destruído permanentemente;
//               fallback fica 100% local (SharedPreferences). notifyListeners() 1×.
//   • MANDATO 2: _isInitializingStream flag — guard de inicialização única.
//               build() NÃO dispara nova subscrição diretamente; a chamada em
//               build() é protegida por ambas as flags antes de qualquer I/O.
//   • MANDATO 3: logs de depuração reduzidos — apenas transição para offline loga.
//
// v5 CHANGES (Build 183):
//   • FIX 1: StreamBuilder listening to InternacionFirestoreService.sessionsStream(uid)
//            — MEU PLANTÃO now shows exact same data as the Adulto tab (real-time sync)
//   • FIX 2: Triage color mapping based on diagnosis keywords (red/yellow/green)
//   • FIX 3: PatientAccordion hydration fixed via ValueKey(sessionKey)

import 'dart:async';
import 'package:firebase_core/firebase_core.dart'; // kept for FirebaseApp type ref
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/firebase_runtime_guard.dart'; // BUILD 299: safe Firebase.apps access
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/drug_model.dart';
import '../widgets/common_widgets.dart';
import '../screens/internacion/services/internacion_firestore_service.dart';
import '../screens/internacion/services/internacion_persistence.dart';
import '../screens/internacion/models/evolucion_model.dart';
import '../screens/internacion/components/soap/soap_section.dart'
    show soapCompletoString, soapResumidoString, soapPassagemString;
import '../screens/internacion/components/patient_accordion.dart'
    show PacienteInternacaoData;

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE ATALHO DE CALCULADORA
// ─────────────────────────────────────────────────────────────────────────────

class CalcShortcut {
  final String id;
  final String labelPt;
  final String labelEs;
  final IconData icon;
  final Color color;

  const CalcShortcut({
    required this.id,
    required this.labelPt,
    required this.labelEs,
    required this.icon,
    required this.color,
  });

  String label(bool isEs) => isEs ? labelEs : labelPt;
}

const List<CalcShortcut> kAvailableCalcs = [
  // BUILD 408-NATIVE: Biometria → Nefrologia/Función Renal
  CalcShortcut(id: 'calc_biometria',   labelPt: 'Função Renal',  labelEs: 'Función Renal',  icon: Icons.water_drop_rounded,        color: Color(0xFF00B4CC)),
  CalcShortcut(id: 'calc_scores',      labelPt: 'Scores',        labelEs: 'Scores',         icon: Icons.bar_chart_rounded,         color: Color(0xFF8B5CF6)),
  CalcShortcut(id: 'calc_cardio',      labelPt: 'Cardio',        labelEs: 'Cardio',         icon: Icons.favorite_outline_rounded,  color: Color(0xFFEF4444)),
  CalcShortcut(id: 'calc_eletrólitos', labelPt: 'Eletrólitos',   labelEs: 'Electrolitos',   icon: Icons.science_outlined,          color: Color(0xFFF59E0B)),
  CalcShortcut(id: 'calc_infusao',     labelPt: 'Infusão EV',    labelEs: 'Infusión EV',    icon: Icons.water_drop_outlined,       color: Color(0xFF06B6D4)),
  CalcShortcut(id: 'calc_referencia',  labelPt: 'Referência',    labelEs: 'Referencia',     icon: Icons.menu_book_outlined,        color: Color(0xFF10B981)),
  CalcShortcut(id: 'calc_prescricoes', labelPt: 'Prescrições',   labelEs: 'Prescripciones', icon: Icons.receipt_long_outlined,     color: Color(0xFFC5A365)),
  CalcShortcut(id: 'calc_pediatria',   labelPt: 'Pediatria',     labelEs: 'Pediatría',      icon: Icons.child_care_outlined,       color: Color(0xFFEC4899)),
  // BUILD 431: Atalhos diretos para Nefrologia e Hepatologia
  CalcShortcut(id: 'calc_nefrologia',  labelPt: 'Nefrologia',    labelEs: 'Nefrología',     icon: Icons.layers_outlined,           color: Color(0xFF00E5FF)),
  // BUILD 433: âmbar/ouro profundo — identidade cromática hepática exclusiva
  CalcShortcut(id: 'calc_hepatologia', labelPt: 'Hepatologia',   labelEs: 'Hepatología',     icon: Icons.account_tree_outlined,     color: Color(0xFFF59E0B)),
];

/// IDs de calculadoras proibidas por Apple Guideline 1.4.1 + regulatório:
/// "Infusión EV" (calc_infusao) e "Prescripciones" (calc_prescricoes) nunca
/// aparecem no Home Preview nem na lista de Gestionar, em nenhuma circunstância.
const Set<String> _kForbiddenCalcIds = {'calc_infusao', 'calc_prescricoes'};

CalcShortcut? calcById(String id) {
  try { return kAvailableCalcs.firstWhere((c) => c.id == id); } catch (_) { return null; }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL — colapsável
// ─────────────────────────────────────────────────────────────────────────────

class MeuPlantaoDashboard extends StatefulWidget {
  final void Function(DrugModel drug) onOpenDrug;
  final void Function(String calcId) onOpenCalc;
  final void Function() onManageTap;
  // Build 195: passa PacienteSession para pré-carregar ao navegar para InternacionScreen
  final void Function(PacienteSession session)? onOpenInternacion;

  const MeuPlantaoDashboard({
    super.key,
    required this.onOpenDrug,
    required this.onOpenCalc,
    required this.onManageTap,
    this.onOpenInternacion,
  });

  @override
  State<MeuPlantaoDashboard> createState() => _MeuPlantaoDashboardState();
}

class _MeuPlantaoDashboardState extends State<MeuPlantaoDashboard>
    with SingleTickerProviderStateMixin {
  bool _expanded = true; // começa expandido se tiver conteúdo, fechado se vazio
  late AnimationController _chevronCtrl;
  late Animation<double> _chevronAngle;
  // Rastreia o estado vazio anterior para detectar a transição vazio→com-conteúdo
  // e auto-expandir o painel no primeiro pin (Web + Mobile).
  bool _wasEmpty = true;
  // Cache do último isEmpty para evitar chamadas redundantes de didChangeDependencies
  bool _lastIsEmpty = true;

  // ── Build 183 FIX 1: Firestore stream for real-time patient sync ───────────
  StreamSubscription<List<PacienteSession>>? _sessionsSub;
  List<PacienteSession> _firestoreSessions = [];
  String? _lastStreamUid;

  // ── BUILD 325 — MANDATO 1: Offline Bypass Latch ──────────────────────────
  // Quando true, bloqueia PERMANENTEMENTE novas tentativas de conexão ao
  // Firestore na sessão atual. Ativado ao receber permission-denied / 403.
  // Reseta apenas na próxima sessão do app (re-login ou restart).
  bool _firestorePermissionDenied = false;

  // ── BUILD 325 — MANDATO 2: Guard de inicialização única ──────────────────
  // Impede que build() ou didChangeDependencies() disparem múltiplas
  // subscrições simultâneas enquanto a primeira ainda está sendo configurada.
  bool _isInitializingStream = false;

  @override
  void initState() {
    super.initState();
    _chevronCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // 1 = expandido
    );
    _chevronAngle = Tween<double>(begin: 0.0, end: 0.5)
        .animate(CurvedAnimation(parent: _chevronCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _sessionsSub?.cancel();
    _chevronCtrl.dispose();
    super.dispose();
  }

  // ── BUILD 325 — MANDATO 1+2: Subscribes to Firestore sessions stream ─────
  //
  // PATOLOGIA CORRIGIDA (BUILD 321 introduzia loop infinito com permission-denied):
  //   stream error → onError → _lastStreamUid = null → _loadSessionsFallback()
  //   → setState() → build() → _subscribeToSessions() [uid ok, _lastStreamUid null]
  //   → novo stream → permission-denied imediato → LOOP INFINITO.
  //
  // SOLUÇÃO BUILD 325:
  //   1. _firestorePermissionDenied latch: ao detectar permission-denied/403,
  //      cancela o stream permanentemente e NUNCA tenta reconectar. Fallback
  //      fica 100% em SharedPreferences local — zero tráfego Firestore.
  //   2. _isInitializingStream guard: bloqueia chamadas concorrentes de
  //      build() e didChangeDependencies() durante a setup do stream.
  //   3. _lastStreamUid NÃO é mais resetado em erros de permissão —
  //      apenas em erros recuperáveis (índice ausente, rede instável).
  void _subscribeToSessions(String uid) {
    // MANDATO 1: trava permanente por permissão negada — aborta imediatamente
    if (_firestorePermissionDenied) {
      _loadLocalCacheOnly();
      return;
    }

    // MANDATO 2: guard de inicialização única — evita subscrições concorrentes
    if (_isInitializingStream) return;

    // Guard de uid já subscrito — evita re-subscrição durante rebuilds normais
    if (_lastStreamUid == uid) return;

    _isInitializingStream = true;
    _lastStreamUid = uid;
    _sessionsSub?.cancel();

    // BUILD 321 CACHE-FIRST: exibe dados locais imediatamente enquanto Firestore carrega
    _loadLocalCacheFirst();

    _sessionsSub = InternacionFirestoreService.sessionsStream(uid).listen(
      (sessions) {
        _isInitializingStream = false;
        if (!mounted) return;
        setState(() => _firestoreSessions = sessions);
        _notifyEmptyChange();
      },
      onError: (e) {
        _isInitializingStream = false;
        final errStr = e.toString().toLowerCase();
        final isPermissionError = errStr.contains('permission-denied')
            || errStr.contains('insufficient permissions')
            || errStr.contains('permission_denied')
            || errStr.contains('403');

        if (isPermissionError) {
          // MANDATO 1: ativa trava permanente — destroi stream, bloqueia toda
          // reconexão futura ao Firestore para este widget na sessão atual.
          // BUILD 288 DIAG: captura uid e path no momento exato do 403
          final _diagUid = context.read<AppProvider>().currentUser?.uid ?? 'null';
          debugPrint('[MeuPlantao][PATH] collection=users/$_diagUid/internaciones');
          debugPrint('[MeuPlantao][UID]  uid=$_diagUid');
          debugPrint('[MeuPlantao][AUTH] raw_error=$e');
          debugPrint('[MeuPlantao] ERRO PERMISSÃO (403/permission-denied). '
              'Sincronização remota suspensa. Modo offline ativado.');
          _firestorePermissionDenied = true;
          _sessionsSub?.cancel();
          _sessionsSub = null;
          // Não reseta _lastStreamUid — impede re-subscrição por build()
          _loadLocalCacheOnly();
        } else {
          // Erro recuperável (índice ausente, rede instável): permite retry
          // na próxima reconexão, mas NÃO na próxima chamada de build().
          // _lastStreamUid mantido — rebuild normal não re-subscreve.
          // Usuário precisa sair e voltar para forçar retry.
          debugPrint('[MeuPlantao] Erro de stream (recuperável): $e');
          _loadSessionsFallback(uid);
        }
      },
    );
  }

  // BUILD 321/325 CACHE-FIRST: carrega silenciosamente do SharedPreferences local
  // antes mesmo de o Firestore responder — zero latência percebida pelo usuário.
  // BUILD 325: uid removido do parâmetro (não utilizado internamente).
  Future<void> _loadLocalCacheFirst() async {
    try {
      final local = await InternacionPersistence.loadAllSessions();
      if (!mounted) return;
      // Só aplica se Firestore ainda não preencheu (evita sobrescrever dados novos)
      if (_firestoreSessions.isEmpty && local.isNotEmpty) {
        setState(() => _firestoreSessions = local);
        _notifyEmptyChange();
      }
    } catch (_) {
      // falha silenciosa — o Firestore ainda vai tentar
    }
  }

  // BUILD 325 — MANDATO 1: Fallback 100% local para erros de permissão.
  // Chamado apenas quando _firestorePermissionDenied == true.
  // Zero tráfego de rede — lê exclusivamente do SharedPreferences.
  // setState() chamado no MÁXIMO 1× por sessão (guarda de estado vazio).
  Future<void> _loadLocalCacheOnly() async {
    // Se já temos dados em memória, não precisa recarregar do SP
    if (_firestoreSessions.isNotEmpty) return;
    try {
      final local = await InternacionPersistence.loadAllSessions();
      if (!mounted) return;
      setState(() => _firestoreSessions = local);
      _notifyEmptyChange();
    } catch (_) {
      // falha silenciosa — SP corrompido ou vazio é estado válido
    }
  }

  // BUILD 321/325 OFFLINE-FIRST: cascata Firestore one-shot → SharedPreferences.
  // Chamado apenas para erros RECUPERÁVEIS (índice ausente, rede instável).
  // NUNCA chamado após _firestorePermissionDenied == true.
  Future<void> _loadSessionsFallback(String uid) async {
    // Tentativa 1: Firestore one-shot (pode funcionar mesmo com stream falhando)
    try {
      final sessions = await InternacionFirestoreService.loadAllSessions(uid);
      if (!mounted) return;
      setState(() => _firestoreSessions = sessions);
      _notifyEmptyChange();
      return; // sucesso — não precisa do cache local
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      // Se one-shot também retorna permissão negada, ativa latch e vai para SP
      if (errStr.contains('permission-denied') || errStr.contains('insufficient permissions')
          || errStr.contains('permission_denied') || errStr.contains('403')) {
        debugPrint('[MeuPlantao] One-shot também bloqueado (permissão). '
            'Modo offline permanente ativado.');
        _firestorePermissionDenied = true;
      }
    }

    // Tentativa 2: SharedPreferences local (100% offline, sem permissão)
    try {
      final local = await InternacionPersistence.loadAllSessions();
      if (!mounted) return;
      setState(() => _firestoreSessions = local);
      _notifyEmptyChange();
    } catch (_) {
      // SP vazio ou corrompido — estado válido, UI fica com lista vazia
    }
  }

  // BUILD 279: módulo sempre expandido — auto-colapso removido.
  // O dashboard exibe sempre o header + AddFirstPatientRow + atalhos padrão.
  void _notifyEmptyChange() {
    AppProvider p;
    try { p = context.read<AppProvider>(); } catch (_) { return; }
    final hasDrugs = p.pinnedDrugs.isNotEmpty;
    final filteredIds = p.pinnedCalcIds
        .where((id) => !_kForbiddenCalcIds.contains(id))
        .toList();
    final hasPatients = _firestoreSessions.isNotEmpty;
    final isEmpty = !hasPatients && !hasDrugs && !filteredIds.isNotEmpty;
    if (isEmpty == _lastIsEmpty) return;
    _lastIsEmpty = isEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // BUILD 279: apenas auto-expande ao transição vazio→com-conteúdo;
      // NÃO colapsa quando fica vazio (módulo sempre visível).
      if (_wasEmpty && !isEmpty && !_expanded) {
        setState(() { _expanded = true; _chevronCtrl.forward(); });
      }
      _wasEmpty = isEmpty;
    });
  }

  // ── Reage a mudanças no provider SEM estar dentro do build() ──────────────
  // CORREÇÃO CRÍTICA DO BUG: o postFrameCallback estava dentro do build(),
  // o que causava um loop destrutivo:
  //   tap → _toggle → setState(_expanded=true) → rebuild → callback →
  //   isEmpty && _expanded → setState(_expanded=false) → rebuild → ...
  // Resultado: card abria e fechava instantaneamente, nunca permanécendo aberto.
  //
  // didChangeDependencies() é chamado quando o InheritedWidget (AppProvider)
  // muda — ou seja, quando pinnedCalcIds/pinnedDrugs/plantaoPatients mudam.
  // NÃO é chamado por um toggle manual, portanto não interfere no gesto do usuário.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ── NULL-SAFETY: provider pode estar em inicialização após flutter clean ──
    AppProvider p;
    try {
      p = context.read<AppProvider>();
    } catch (e) {
      debugPrint('ERRO CRÍTICO MI GUARDIA [didChangeDependencies/read]: $e');
      return; // aborta silenciosamente — build() também tem guard
    }

    // ── Build 183 FIX 1: subscribe to Firestore stream when uid is available ──
    // BUILD 325 MANDATO 2: _subscribeToSessions() é protegido pelas flags
    // _firestorePermissionDenied e _isInitializingStream internamente —
    // a chamada aqui é segura mesmo em rebuilds frequentes.
    // BUILD 299: FirebaseRuntimeGuard.isUnavailable substitui Firebase.apps.isEmpty.
    // Firebase.apps pode lançar NullError no Safari — guard via try/catch centralizado.
    final uid = p.currentUser?.uid;
    if (uid != null && !(kIsWeb && FirebaseRuntimeGuard.isUnavailable)) {
      _subscribeToSessions(uid);
    } else if (kIsWeb && FirebaseRuntimeGuard.isUnavailable) {
      debugPrint('[BUILD299][PLANTAO_STREAM] skipped reason=firebase_runtime_unavailable');
    }

    final hasPatients = _firestoreSessions.isNotEmpty;
    final hasDrugs    = (p.pinnedDrugs).isNotEmpty;
    final filteredIds = (p.pinnedCalcIds)
        .where((id) => !_kForbiddenCalcIds.contains(id))
        .toList();
    final isEmpty = !hasPatients && !hasDrugs && !filteredIds.isNotEmpty;

    // Só reage quando o estado vazio/não-vazio muda — nunca interrompe toggle manual
    if (isEmpty == _lastIsEmpty) return;
    _lastIsEmpty = isEmpty;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // BUILD 279: apenas auto-expande ao transição vazio→com-conteúdo;
      // NÃO colapsa quando fica vazio (módulo sempre visível na Home).
      if (_wasEmpty && !isEmpty && !_expanded) {
        // Primeiro item pinado: expande para revelar conteúdo
        setState(() {
          _expanded = true;
          _chevronCtrl.forward();
        });
      }
      _wasEmpty = isEmpty;
    });
  }

  void _toggle(bool hasContent) {
    AppHaptics.selection(context);
    // BUILD 279: toggle normal para qualquer estado (vazio ou com conteúdo).
    // O module sempre permanece expansível — não força manage sheet no vazio.
    final nowExpanded = !_expanded;
    setState(() => _expanded = nowExpanded);
    if (nowExpanded) {
      _chevronCtrl.forward();
    } else {
      _chevronCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── NULL-SAFETY GUARD — trava MI GUARDIA contra tela branca ──────────────
    // Após flutter clean / primeiro boot, context.watch pode lançar
    // ProviderException se o provider ainda não está pronto na árvore.
    // O try/catch garante que o card nunca quebre silenciosamente.
    AppProvider p;
    try {
      p = context.watch<AppProvider>();
    } catch (e, st) {
      debugPrint('ERRO CRÍTICO MI GUARDIA [build/watch]: $e\n$st');
      // BUILD 280: em vez de SizedBox.shrink() (que tornava o módulo invisível
      // no mobile), retorna um placeholder mínimo com o cabeçalho MEU PLANTÃO
      // até o provider estar pronto. Isso garante que o card seja sempre visível.
      final c = AppColors.of(context);
      return _PlantaoLoadingShell(colors: c);
    }

    final c    = AppColors.of(context);
    final isEs = p.lang == 'es';

    // ── Build 183 FIX 1: patients come from Firestore stream ─────────────────
    // BUILD 325 MANDATO 2: _subscribeToSessions() é um no-op seguro quando:
    //   • _firestorePermissionDenied == true  (latch permanente ativo)
    //   • _isInitializingStream == true       (setup em andamento)
    //   • _lastStreamUid == uid               (já subscrito)
    // Garante que build() nunca dispara nova conexão de rede em rebuilds.
    // BUILD 299: FirebaseRuntimeGuard.isUnavailable substitui Firebase.apps.isEmpty.
    // Safari: Firebase.apps getter pode lançar NullError — encapsulado no guard.
    final uid = p.currentUser?.uid;
    if (uid != null && !(kIsWeb && FirebaseRuntimeGuard.isUnavailable)) {
      _subscribeToSessions(uid);
    } else if (kIsWeb && FirebaseRuntimeGuard.isUnavailable) {
      debugPrint('[BUILD299][PLANTAO_STREAM] skipped reason=firebase_runtime_unavailable');
    }
    final firestoreSessions = _firestoreSessions;

    // ── Leitura defensiva de listas — nunca acessa null diretamente ──────────
    final drugs           = p.pinnedDrugs;        // List.unmodifiable([]) se vazio
    final hasPatients     = firestoreSessions.isNotEmpty;
    final hasDrugs        = drugs.isNotEmpty;
    // ── Filtra IDs proibidos ao nível do estado raiz ──────────────────────────
    // Garante que hasCalcs seja consistente com o que _PlantaoContent renderiza.
    // Sem este filtro, pinned forbidden IDs causam isEmpty=false mas UI vazia.
    final filteredRootCalcIds = p.pinnedCalcIds
        .where((id) => !_kForbiddenCalcIds.contains(id))
        .toList();
    final hasCalcs = filteredRootCalcIds.isNotEmpty;
    final isEmpty = !hasPatients && !hasDrugs && !hasCalcs;

    // NOTA: a lógica de auto-colapso/auto-expand foi REMOVIDA daqui.
    // Ela está em didChangeDependencies(), onde pertence.
    // Colocar postFrameCallback no build() causava loop:
    //   tap → _toggle → setState(_expanded=true) → rebuild → callback →
    //   isEmpty && _expanded → setState(_expanded=false) → rebuild → ...
    // O resultado era o card abrindo e fechando instantaneamente.

    // SUPER ORDEM MASTER 14 M6: layout minimalista premium.
    // Cabeçalho sempre visível (card gradiente com botão único).
    // _PlantaoContent só aparece quando há pacientes reais — sem bloco cinza vazio.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabeçalho premium — card gradiente auto-contido ────────────────
        _PlantaoHeader(
          isEs: isEs,
          colors: c,
          expanded: _expanded,
          isEmpty: isEmpty,
          chevronAngle: _chevronAngle,
          onHeaderTap: () => _toggle(true),
          onManageTap: widget.onManageTap,
          onAddPatient: () => _showPatientEditSheet(context, isEs, c, p),
          // Fix#8: propaga onOpenCalc para os 3 atalhos rápidos do header
          onOpenCalc: widget.onOpenCalc,
        ),

        // ── Lista de pacientes — apenas quando existem dados reais ──────────
        if (hasPatients || hasDrugs || hasCalcs)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _PlantaoContent(
                      isEs: isEs,
                      colors: c,
                      p: p,
                      firestoreSessions: firestoreSessions,
                      onOpenDrug: widget.onOpenDrug,
                      onOpenCalc: widget.onOpenCalc,
                      onAddPatient: () => _showPatientEditSheet(context, isEs, c, p),
                      onEditPatient: (pt) => _showPatientEditSheet(context, isEs, c, p, existing: pt),
                      onOpenInternacion: widget.onOpenInternacion,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  void _showPatientEditSheet(
    BuildContext context,
    bool isEs,
    AppColors c,
    AppProvider p, {
    PlantaoPatient? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PatientEditSheet(
        isEs: isEs,
        existing: existing,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CABEÇALHO — com chevron e botões de ação
// ─────────────────────────────────────────────────────────────────────────────

class _PlantaoHeader extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final bool expanded;
  final bool isEmpty;
  final Animation<double> chevronAngle;
  final VoidCallback onHeaderTap;
  final VoidCallback onManageTap;
  final VoidCallback onAddPatient;
  // Fix#8 — atalhos MI GUARDIA: REFERENCIAS · CARDIO · ELECTROLITOS
  final void Function(String calcId) onOpenCalc;

  const _PlantaoHeader({
    required this.isEs,
    required this.colors,
    required this.expanded,
    required this.isEmpty,
    required this.chevronAngle,
    required this.onHeaderTap,
    required this.onManageTap,
    required this.onAddPatient,
    required this.onOpenCalc,
  });

  @override
  Widget build(BuildContext context) {
    // CORREÇÃO 1: container intermediário removido — botão e atalhos ficam
    // diretamente sobre o fundo do card principal "MEU PLANTÃO", sem camada
    // cinza escura adicional com borda dourada redundante.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Linha título: ícone pulso + label ──────────────────────────
        Row(
          children: [
            const Icon(Icons.monitor_heart_outlined, size: 18, color: kGoldLight),
            const SizedBox(width: 8),
            Text(
              isEs ? 'MI GUARDIA' : 'MEU PLANTÃO',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
                color: kGoldLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Botão outline único centralizado ────────────────────────────
        GestureDetector(
          onTap: () {
            AppHaptics.selection(context);
            onAddPatient();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: kGoldLight.withOpacity(0.55),
                width: 1.2,
              ),
              color: Colors.white.withOpacity(0.04),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 15,
                    color: kGoldLight.withOpacity(0.9)),
                const SizedBox(width: 6),
                Text(
                  isEs
                      ? '+ Agregar Paciente a la Guardia'
                      : '+ Adicionar Paciente ao Plantão',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kGoldLight.withOpacity(0.9),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Fix#8 — Atalhos rápidos: REFERENCIAS · CARDIO · ELECTROLITOS ──
        const SizedBox(height: 12),
        _GuardiaShortcutsRow(isEs: isEs, onOpenCalc: onOpenCalc),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 431: ATALHOS RÁPIDOS MI GUARDIA (CARDIO · NEFROLOGÍA · HEPATOLOGÍA)
// Row de 3 mini-cards sempre visível dentro do header do plantão.
// Cada card navega diretamente para a sub-aba correspondente em Ferramentas:
//   • CARDIO       → toolsScreenTabNotifier(1) + onTabChange(4)
//   • NEFROLOGÍA   → toolsScreenTabNotifier(0) + onTabChange(4)
//   • HEPATOLOGÍA  → toolsScreenTabNotifier(3) + onTabChange(4)
// 100% AppColors adaptive — sem cor hardcoded.
// ─────────────────────────────────────────────────────────────────────────────

class _GuardiaShortcutsRow extends StatelessWidget {
  final bool isEs;
  final void Function(String calcId) onOpenCalc;

  const _GuardiaShortcutsRow({
    required this.isEs,
    required this.onOpenCalc,
  });

  // BUILD 431: Os 3 atalhos fixos — CARDIO, NEFROLOGÍA, HEPATOLOGÍA
  // IDs mapeados em home_screen.dart → calcTabMap:
  //   calc_cardio      → toolsScreenTabNotifier.value = 1 (Cardio)
  //   calc_nefrologia  → toolsScreenTabNotifier.value = 0 (Nefrologia)
  //   calc_hepatologia → toolsScreenTabNotifier.value = 3 (Hepatologia)
  static const _kShortcutIds = [
    'calc_cardio',
    'calc_nefrologia',
    'calc_hepatologia',
  ];

  // BUILD 431 — IDs que NÃO devem aparecer em _PinnedCalcsGrid pois já são
  // cobertos pelo _GuardiaShortcutsRow acima.
  // Exposto como Set estático para ser consultado por _PlantaoContent.
  static const kFixedShortcutIds = <String>{
    'calc_cardio',
    'calc_nefrologia',
    'calc_hepatologia',
    'calc_scores', // mapeia para tab 0 — coberto pelo contexto geral
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < _kShortcutIds.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _GuardiaShortcutCard(
              calcId: _kShortcutIds[i],
              isEs: isEs,
              onTap: () => onOpenCalc(_kShortcutIds[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// Card individual de atalho — sem RepaintBoundary (já dentro de um card naval).
/// Usa AnimatedScale para feedback tátil sem Impeller flicker.
class _GuardiaShortcutCard extends StatefulWidget {
  final String calcId;
  final bool isEs;
  final VoidCallback onTap;

  const _GuardiaShortcutCard({
    required this.calcId,
    required this.isEs,
    required this.onTap,
  });

  @override
  State<_GuardiaShortcutCard> createState() => _GuardiaShortcutCardState();
}

class _GuardiaShortcutCardState extends State<_GuardiaShortcutCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final shortcut = calcById(widget.calcId);
    if (shortcut == null) return const SizedBox.shrink();

    final label = widget.isEs ? shortcut.labelEs : shortcut.labelPt;
    final color = shortcut.color;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection(context);
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            // Fundo com leve tint da cor do atalho — funciona em dark e light
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withOpacity(0.30),
              width: 1.1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(shortcut.icon, size: 20, color: color),
              const SizedBox(height: 5),
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CORPO COM CONTEÚDO — 3 sub-seções
// ─────────────────────────────────────────────────────────────────────────────

// ── Build 183 FIX 2: Triage color mapping based on diagnosis keywords ────────
// RED = critical/emergency, YELLOW = urgent/intermediate, GREEN = stable
Color _triageColorFromDiag(String diag) {
  final d = diag.toLowerCase();
  // RED — critical / emergency
  const redTerms = [
    'shock', 'choque', 'sca', 'síndromo coronario agudo', 'síndrome coronariano agudo',
    'infarto', 'iamcsst', 'iamssst', 'parada', 'pcrce', 'sepsis severa',
    'falla orgánica', 'falla organica', 'falha orgânica', 'falha organica',
    'iam', 'tep instável', 'tep instavel', 'edema agudo', 'insuficiencia respiratoria aguda',
    'insuficiência respiratória aguda', 'status epileptico', 'status epilético',
    'coma', 'stroke', 'avc isquemico', 'avc hemorragico', 'hemorragia',
    'hemorragia cerebral', 'iam com supra', 'emergencia hipertensiva',
    'emergencia hipertensíva', 'emergencia hipertensiva', 'anafilaxia', 'anafilaxis',
    'tamponamento', 'pericardico', 'pericardi', 'eap', 'insuficiencia cardíaca aguda',
  ];
  // YELLOW — urgent / intermediate
  const yellowTerms = [
    'sepsis', 'sepse', 'pneumonia', 'neumonía', 'neumonia', 'pielonefritis',
    'pielonefrite', 'celulitis', 'celulite', 'ictericia', 'ictericia obstructiva',
    'icterícia', 'colangitis', 'colangite', 'sdra', 'ards', 'irc descompensada',
    'dra', 'irc', 'insuficiencia renal', 'insuficiência renal',
    'epoc', 'epoc agudizado', 'dpoc', 'dpoc agudizado', 'crisis asmatica',
    'crise asmática', 'hta', 'hipertension urgencia', 'hipertensão urgencia',
    'disritmia', 'fibrilacão atrial', 'fibrilacion auricular', 'icpp', 'icc',
    'diabetes descompensada', 'cetoacidose', 'cetoacidosis',
    'meningitis', 'meningite', 'encefalitis', 'encefalite',
    'trombosis', 'tvp', 'tep', 'embolismo pulmonar', 'embolia pulmonar',
  ];
  for (final term in redTerms) {
    if (d.contains(term)) return const Color(0xFFEF4444); // red
  }
  for (final term in yellowTerms) {
    if (d.contains(term)) return const Color(0xFFF59E0B); // amber/yellow
  }
  return const Color(0xFF10B981); // green = stable
}

class _PlantaoContent extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final AppProvider p;
  final List<PacienteSession> firestoreSessions;
  final void Function(DrugModel) onOpenDrug;
  final void Function(String) onOpenCalc;
  final VoidCallback onAddPatient;
  final void Function(PlantaoPatient) onEditPatient;
  // Build 195: passa PacienteSession para pré-carregar ao navegar para InternacionScreen
  final void Function(PacienteSession session)? onOpenInternacion;

  const _PlantaoContent({
    required this.isEs,
    required this.colors,
    required this.p,
    required this.firestoreSessions,
    required this.onOpenDrug,
    required this.onOpenCalc,
    required this.onAddPatient,
    required this.onEditPatient,
    this.onOpenInternacion,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final hasPatients = firestoreSessions.isNotEmpty; // FIX 1: Firestore-sourced
    final hasDrugs    = p.pinnedDrugs.isNotEmpty;
    // Filtra IDs proibidos antes de checar se há calcs para exibir
    final filteredCalcIds = p.pinnedCalcIds
        .where((id) => !_kForbiddenCalcIds.contains(id))
        .toList();

    // Fix#9 — Remove da grade de pins os IDs já cobertos pelo _GuardiaShortcutsRow
    // (atalhos fixos sempre visíveis no header). Evita duplicata visual sem apagar
    // os dados de pinning do usuário — apenas suprime a renderização redundante.
    final deduplicatedCalcIds = filteredCalcIds
        .where((id) => !_GuardiaShortcutsRow.kFixedShortcutIds.contains(id))
        .toList();
    final hasDeduplicatedCalcs = deduplicatedCalcIds.isNotEmpty;

    // SUPER ORDEM MASTER 306 M1: purga total — sem _AddFirstPatientRow,
    // sem _DefaultCalcShortcutsGrid. Apenas dados reais.
    if (!hasPatients && !hasDrugs && !hasDeduplicatedCalcs) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── PACIENTES — lista minimalista Firestore ───────────────────────────
        if (hasPatients) ...[
          _FirestoreSessionsColumn(
            sessions: firestoreSessions,
            isEs: isEs,
            colors: c,
            onOpenInternacion: onOpenInternacion,
          ),
          if (hasDrugs || hasDeduplicatedCalcs) const SizedBox(height: 12),
        ],

        // ── FÁRMACOS — scroll horizontal ─────────────────────────────────────
        if (hasDrugs) ...[
          _PinnedDrugsRow(
            drugs: p.pinnedDrugs,
            isEs: isEs,
            colors: c,
            onTap: onOpenDrug,
            onUnpin: (drug) {
              AppHaptics.medium(context);
              p.unpinDrug(drug.id);
            },
          ),
          if (hasDeduplicatedCalcs) const SizedBox(height: 12),
        ],

        // ── CALCULADORAS PINADAS — grid compacto (IDs fixos já deduplificados) ─
        if (hasDeduplicatedCalcs) ...[
          _PinnedCalcsGrid(
            calcIds: deduplicatedCalcIds, // Fix#9: sem IDs cobertos por _GuardiaShortcutsRow
            isEs: isEs,
            colors: c,
            onTap: onOpenCalc,
            onUnpin: (id) {
              AppHaptics.medium(context);
              p.unpinCalc(id);
            },
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 279 — SUB-CARDS DE ATALHO PADRÃO (Scores + Biometria)
// Grid sempre visível quando nenhuma calculadora está pinada.
// Representa os dois atalhos de acesso rápido exibidos no contrato visual
// image_11.png: Card 1 = Scores (roxo, bar_chart), Card 2 = Biometria (azul, monitor_weight).
// ─────────────────────────────────────────────────────────────────────────────

class _DefaultCalcShortcutsGrid extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final void Function(String calcId) onOpenCalc;

  const _DefaultCalcShortcutsGrid({
    required this.isEs,
    required this.colors,
    required this.onOpenCalc,
  });

  // IDs dos atalhos padrão exibidos na Home (Scores + Biometria)
  static const _kDefaultIds = ['calc_scores', 'calc_biometria'];

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const cols = 2;
        final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Row(
          children: [
            for (int i = 0; i < _kDefaultIds.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Builder(builder: (_) {
                final shortcut = calcById(_kDefaultIds[i]);
                if (shortcut == null) return SizedBox(width: itemW);
                return SizedBox(
                  width: itemW,
                  child: _DefaultCalcCard(
                    shortcut: shortcut,
                    isEs: isEs,
                    colors: c,
                    onTap: () => onOpenCalc(shortcut.id),
                  ),
                );
              }),
            ],
          ],
        );
      },
    );
  }
}

/// Card de atalho padrão — sem botão de unpin (não é pinada, é sempre visível).
class _DefaultCalcCard extends StatefulWidget {
  final CalcShortcut shortcut;
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;

  const _DefaultCalcCard({
    required this.shortcut,
    required this.isEs,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_DefaultCalcCard> createState() => _DefaultCalcCardState();
}

class _DefaultCalcCardState extends State<_DefaultCalcCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final s = widget.shortcut;

    return GestureDetector(
      onTap: () { AppHaptics.selection(context); widget.onTap(); },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: s.color.withOpacity(0.20), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(c.dark ? 0.22 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: s.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s.icon, size: 18, color: s.color),
              ),
              const SizedBox(height: 7),
              Text(
                s.label(widget.isEs),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: c.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LINHA "ADICIONAR PRIMEIRO PACIENTE"
// ─────────────────────────────────────────────────────────────────────────────

class _AddFirstPatientRow extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  const _AddFirstPatientRow({required this.isEs, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return GestureDetector(
      onTap: () { AppHaptics.selection(context); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.20), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Color(0xFF3B82F6)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEs ? 'Agregar paciente al turno' : 'Adicionar paciente ao plantão',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEs ? 'Habitación, diagnóstico, tratamiento' : 'Quarto, diagnóstico, tratamento',
                    style: TextStyle(fontSize: 11, color: c.textHint),
                  ),
                ],
              ),
            ),
            const Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(0xFF3B82F6)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COLUNA DE PACIENTES
// ─────────────────────────────────────────────────────────────────────────────

class _PatientsColumn extends StatelessWidget {
  final List<PlantaoPatient> patients;
  final bool isEs;
  final AppColors colors;
  final void Function(PlantaoPatient) onEdit;
  final void Function(PlantaoPatient) onRemove;

  const _PatientsColumn({
    required this.patients,
    required this.isEs,
    required this.colors,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < patients.length; i++) ...[
          _PatientCard(
            patient: patients[i],
            isEs: isEs,
            colors: colors,
            onTap: () => onEdit(patients[i]),
            onRemove: () => onRemove(patients[i]),
          ),
          if (i < patients.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 183 FIX 1+2: COLUNA DE SESSÕES FIRESTORE (MEU PLANTÃO)
// Renderiza PacienteSession com triage color dinâmico baseado em diagnóstico
// ─────────────────────────────────────────────────────────────────────────────

class _FirestoreSessionsColumn extends StatelessWidget {
  final List<PacienteSession> sessions;
  final bool isEs;
  final AppColors colors;
  // Build 195: passa PacienteSession para pré-carregar ao navegar para InternacionScreen
  final void Function(PacienteSession session)? onOpenInternacion;

  const _FirestoreSessionsColumn({
    required this.sessions,
    required this.isEs,
    required this.colors,
    this.onOpenInternacion,
  });

  // Build 198: deduplicação à prova de balas — null-safe em todos os campos.
  // Agrupa por nome normalizado, mantém a sessão mais recente por paciente.
  // Em caso de qualquer erro, retorna a lista original sem deduplicar.
  List<PacienteSession> _deduplicated() {
    try {
      final Map<String, PacienteSession> byPatient = {};
      for (final s in sessions) {
        // Null-safe máximo: paciente pode ser nulo; nome é String não-nula
        final nome = s.paciente?.nome.trim() ?? '';
        final key = nome.isNotEmpty ? nome.toLowerCase() : s.sessionKey;
        final existing = byPatient[key];
        if (existing == null ||
            (s.savedAt.isAfter(existing.savedAt))) {
          byPatient[key] = s;
        }
      }
      final result = byPatient.values.toList()
        ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      return result;
    } catch (e) {
      debugPrint('[MeuPlantao] _deduplicated error: $e');
      return List<PacienteSession>.from(sessions); // fallback: cópia defensiva
    }
  }

  @override
  Widget build(BuildContext context) {
    final deduped = _deduplicated();
    return Column(
      children: [
        for (int i = 0; i < deduped.length; i++) ...[
          _FirestoreSessionCard(
            session: deduped[i],
            isEs: isEs,
            colors: colors,
            onOpenInternacion: onOpenInternacion,
          ),
          if (i < deduped.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Build 192 Fix 3: _FirestoreSessionCard
// Toque curto → onOpenInternacion (navega para aba Adulto)
// Toque longo → showDialog com prévia SOAP completa + seletor de histórico
// ═════════════════════════════════════════════════════════════════════════════
class _FirestoreSessionCard extends StatelessWidget {
  final PacienteSession session;
  final bool isEs;
  final AppColors colors;
  // Build 195: passa PacienteSession para pré-carregar ao navegar para InternacionScreen
  final void Function(PacienteSession session)? onOpenInternacion;

  const _FirestoreSessionCard({
    required this.session,
    required this.isEs,
    required this.colors,
    this.onOpenInternacion,
    super.key,
  });

  // Abre o pop-up de prévia SOAP completa com seletor de histórico
  // BUILD 319: propaga onOpenInternacion para o dialog → botão "Evoluir" direto
  void _showSoapPreview(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _SoapPreviewDialog(
        session: session,
        isEs: isEs,
        dark: colors.dark,
        onOpenInternacion: onOpenInternacion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final p = session.paciente;
    final nome = p.nome.isNotEmpty ? p.nome : (isEs ? 'Paciente' : 'Paciente');
    final cama = p.cama.isNotEmpty ? p.cama : '';
    final diag = p.diagnostico;
    final evol = session.historial.length;

    // FIX 2: triage color — keyword-based on diagnosis
    final triageColor = _triageColorFromDiag(diag);

    // Build 188: RepaintBoundary isola cada card do grid — 120Hz fluido
    // Build 187: wraps card with Material+InkWell for tap-to-navigate
    // Build 192 Fix 3: onLongPress abre pop-up de prévia SOAP
    return RepaintBoundary(child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpenInternacion != null
            ? () {
                AppHaptics.selection(context);
                onOpenInternacion!(session);
              }
            : null,
        onLongPress: () {
          AppHaptics.medium(context);
          _showSoapPreview(context);
        },
        borderRadius: BorderRadius.circular(14),
        splashColor: triageColor.withOpacity(0.10),
        highlightColor: triageColor.withOpacity(0.06),
        child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: triageColor.withOpacity(0.70),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: triageColor.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ícone com cor de triagem ────────────────────────────────────
          Column(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: triageColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bed_rounded, size: 20, color: triageColor),
              ),
              if (cama.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: triageColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cama,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: triageColor),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 12),

          // ── Dados do paciente ─────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nome
                Text(
                  nome,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (diag.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dx: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textHint)),
                      Expanded(
                        child: Text(
                          diag,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (evol > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.history_rounded, size: 10, color: triageColor),
                      const SizedBox(width: 3),
                      Text(
                        isEs
                            ? 'Día ${p.diaInternacao} · $evol evol.'
                            : 'Dia ${p.diaInternacao} · $evol evol.',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: triageColor),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── Ícone de prévia (toque longo) + indicador de triagem ──────
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: triageColor),
              if (evol > 0) ...[
                const SizedBox(height: 6),
                Icon(Icons.preview_rounded, size: 13, color: triageColor.withOpacity(0.60)),
              ],
            ],
          ),
        ],
      ),
    ),  // end InkWell child (AnimatedContainer)
      ),  // end InkWell
    ));  // end Material + RepaintBoundary
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Build 192 Fix 3: _SoapPreviewDialog
// Pop-up reativamente atualizável com seletor de histórico.
// Exibe a SOAP completa da evolução selecionada + cópia para clipboard.
// ═════════════════════════════════════════════════════════════════════════════
class _SoapPreviewDialog extends StatefulWidget {
  final PacienteSession session;
  final bool isEs;
  final bool dark;
  // BUILD 319: CTA de ação rápida — navega para InternacionScreen com contexto
  final void Function(PacienteSession session)? onOpenInternacion;

  const _SoapPreviewDialog({
    required this.session,
    required this.isEs,
    required this.dark,
    this.onOpenInternacion,
  });

  @override
  State<_SoapPreviewDialog> createState() => _SoapPreviewDialogState();
}

class _SoapPreviewDialogState extends State<_SoapPreviewDialog> {
  late int _selectedEvolIndex;

  @override
  void initState() {
    super.initState();
    // Inicia na evolução mais recente (última do historial)
    _selectedEvolIndex = widget.session.historial.isNotEmpty
        ? widget.session.historial.length - 1
        : -1;
  }

  bool get isEs => widget.isEs;
  bool get dark => widget.dark;

  // Formata a data de uma evolução para o DropdownButton
  String _evolLabel(int index) {
    final ev = widget.session.historial[index];
    final d = ev.fecha;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return isEs ? 'Día $dateStr' : 'Dia $dateStr';
  }

  // Constrói o texto SOAP completo de uma evolução específica
  String _buildSoapText(EvolucionModel ev) {
    final buf = StringBuffer();
    final s = ev.subjetivo;
    final o = ev.objetivo;
    final sv = o.signosVitales;
    final ef = o.examenFisico;
    final ex = o.examenes;
    final a = ev.evaluacion;
    final p = ev.plan;

    buf.writeln(isEs ? '── S — SUBJETIVO ──' : '── S — SUBJETIVO ──');
    if (s.notePasaNoche.isNotEmpty) buf.writeln(s.notePasaNoche);
    final syms = <String>[];
    if (s.fiebre) syms.add(isEs ? 'Fiebre' : 'Febre');
    if (s.disnea) syms.add(isEs ? 'Disnea' : 'Dispneia');
    if (s.nauseas) syms.add(isEs ? 'Náuseas' : 'Náuseas');
    if (s.tos) syms.add(isEs ? 'Tos' : 'Tosse');
    if (syms.isNotEmpty) buf.writeln(syms.join(' · '));
    if (s.dolorEscala != null && s.dolorEscala! > 0)
      buf.writeln('EVA: ${s.dolorEscala}/10');
    if (s.notasLibres.isNotEmpty) buf.writeln(s.notasLibres);

    buf.writeln('');
    buf.writeln(isEs ? '── O — OBJETIVO ──' : '── O — OBJETIVO ──');
    if (!sv.isEmpty) {
      final parts = <String>[];
      if (sv.pa.isNotEmpty) parts.add('PA: ${sv.pa}');
      if (sv.fc.isNotEmpty) parts.add('FC: ${sv.fc}');
      if (sv.fr.isNotEmpty) parts.add('FR: ${sv.fr}');
      if (sv.satO2.isNotEmpty) parts.add('SatO₂: ${sv.satO2}%');
      if (sv.temperatura.isNotEmpty) parts.add('T: ${sv.temperatura}°C');
      buf.writeln(parts.join('  '));
    }
    if (ef.estadoGeneral.isNotEmpty) buf.writeln('EG: ${ef.estadoGeneral}');
    if (ef.acv.isNotEmpty) buf.writeln('CV: ${ef.acv}');
    if (ef.ar.isNotEmpty) buf.writeln('Resp: ${ef.ar}');
    if (ef.abdomen.isNotEmpty) buf.writeln('Abd: ${ef.abdomen}');
    if (ef.extremidades.isNotEmpty) buf.writeln('MMII: ${ef.extremidades}');
    if (ex.laboratorio.isNotEmpty)
      buf.writeln('${isEs ? 'Lab' : 'Lab'}: ${ex.laboratorio}');
    if (ex.imagenes.isNotEmpty)
      buf.writeln('${isEs ? 'Imágenes' : 'Imagens'}: ${ex.imagenes}');
    if (ex.culturas.isNotEmpty) buf.writeln('Culturas: ${ex.culturas}');
    if (ex.ecg.isNotEmpty) buf.writeln('ECG: ${ex.ecg}');
    if (o.tratamientoActual.isNotEmpty)
      buf.writeln('${isEs ? 'Tto. actual' : 'Tto. atual'}: ${o.tratamientoActual}');

    buf.writeln('');
    buf.writeln(isEs ? '── A — EVALUACIÓN ──' : '── A — AVALIAÇÃO ──');
    if (a.problemasActivos.isNotEmpty)
      buf.writeln(a.problemasActivos.join(', '));
    if (a.notasEvaluacion.isNotEmpty) buf.writeln(a.notasEvaluacion);
    if (a.estado != null) buf.writeln(a.estado!.label(isEs ? 'es' : 'pt'));

    buf.writeln('');
    buf.writeln(isEs ? '── P — PLAN ──' : '── P — PLANO ──');
    if (p.planTerapeutico.isNotEmpty) buf.writeln(p.planTerapeutico);
    if (p.criteriosAlta.isNotEmpty)
      buf.writeln('${isEs ? 'Criterios de alta' : 'Critérios de alta'}: ${p.criteriosAlta}');

    // metadadosAdicionais — exibe se houver dados extras capturados pela IA
    if (ev.metadadosAdicionais.isNotEmpty) {
      buf.writeln('');
      buf.writeln(isEs ? '── DADOS ADICIONAIS ──' : '── DADOS ADICIONAIS ──');
      ev.metadadosAdicionais.forEach((k, v) => buf.writeln('$k: $v'));
    }

    return buf.toString().trim();
  }

  // Build 196: abre ModalBottomSheet com 3 formatos (Completo, Resumido, Passagem)
  void _showCopySheet(
    BuildContext context,
    EvolucionModel ev,
    PacienteInternacaoData paciente,
  ) {
    final lang = isEs ? 'es' : 'pt';
    final autorNombre = ev.autorNombre;

    void doCopy(String text) {
      Navigator.of(context).pop(); // fecha o sheet
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.copy_rounded, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Text(isEs
              ? 'Evolución copiada al portapapeles'
              : 'Evolução copiada para a área de transferência'),
        ]),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SoapCopySheet(
        dark: dark,
        lang: lang,
        onCopyFull: () => doCopy(soapCompletoString(ev, isEs, autorNombre, paciente)),
        onCopyResumida: () => doCopy(soapResumidoString(ev, isEs, autorNombre, paciente)),
        onCopyPasaje: () => doCopy(soapPassagemString(ev, isEs, paciente)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final p = session.paciente;
    final nome = p.nome.isNotEmpty ? p.nome : (isEs ? 'Paciente' : 'Paciente');
    final hasHistorial = session.historial.isNotEmpty;
    final selectedEv =
        hasHistorial && _selectedEvolIndex >= 0 && _selectedEvolIndex < session.historial.length
            ? session.historial[_selectedEvolIndex]
            : null;
    final soapText = selectedEv != null ? _buildSoapText(selectedEv) : '';
    final triageColor = _triageColorFromDiag(p.diagnostico);

    final bg = dark ? const Color(0xFF0F1116) : Colors.white;
    final textPrimary = dark ? Colors.white : const Color(0xFF0D1117);
    final textSecondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = dark ? const Color(0xFF1A1F2E) : const Color(0xFFF8F9FA);
    final borderColor = dark ? const Color(0xFF2D3748) : const Color(0xFFE5E7EB);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 28),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 560, maxWidth: 520),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: triageColor.withOpacity(0.35),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.40 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              decoration: BoxDecoration(
                color: triageColor.withOpacity(dark ? 0.12 : 0.07),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: triageColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bed_rounded, size: 18, color: triageColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          [
                            if (p.cama.isNotEmpty)
                              isEs ? 'Cama ${p.cama}' : 'Leito ${p.cama}',
                            if (p.diagnostico.isNotEmpty) p.diagnostico,
                          ].join('  ·  '),
                          style: TextStyle(fontSize: 11, color: textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Build 196: Botão Copiar — abre tri-format ModalBottomSheet
                  if (selectedEv != null)
                    IconButton(
                      icon: Icon(Icons.copy_all_rounded, size: 18, color: triageColor),
                      tooltip: isEs ? 'Exportar evolución' : 'Exportar evolução',
                      onPressed: () => _showCopySheet(context, selectedEv, session.paciente),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),

            // ── Seletor de histórico (DropdownButton) ────────────────────
            if (hasHistorial && session.historial.length > 1) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 14, color: triageColor),
                    const SizedBox(width: 6),
                    Text(
                      isEs ? 'Evolución:' : 'Evolução:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButton<int>(
                        value: _selectedEvolIndex,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        dropdownColor: bg,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                        icon: Icon(Icons.expand_more_rounded, size: 18, color: triageColor),
                        items: List.generate(session.historial.length, (i) {
                          final label = _evolLabel(i);
                          final isLatest = i == session.historial.length - 1;
                          return DropdownMenuItem<int>(
                            value: i,
                            child: Text(
                              isLatest
                                  ? '$label  ${isEs ? '(más reciente)' : '(mais recente)'}'
                                  : label,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: textPrimary,
                                fontWeight: isLatest ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          );
                        }),
                        onChanged: (idx) {
                          if (idx != null) setState(() => _selectedEvolIndex = idx);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (hasHistorial) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 13, color: triageColor),
                    const SizedBox(width: 5),
                    Text(
                      _evolLabel(0),
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: triageColor),
                    ),
                  ],
                ),
              ),
            ],

            // ── Corpo scrollável — SOAP completo ─────────────────────────
            Flexible(
              child: !hasHistorial
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isEs ? 'Sin evoluciones registradas.' : 'Sem evoluções registradas.',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Build 196: empty-state global quando soapText vazio
                          if (soapText.trim().isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                isEs
                                    ? 'Sin datos completados en esta evolución.'
                                    : 'Sem dados preenchidos nesta evolução.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          // Texto SOAP formatado em blocos visuais
                          if (soapText.trim().isNotEmpty)
                            ...soapText.split('\n──').map((block) {
                              if (block.trim().isEmpty) return const SizedBox.shrink();
                              final lines = ('──$block').split('\n');
                              final header = lines.isNotEmpty ? lines.first.trim() : '';
                              final body = lines.skip(1).join('\n').trim();
                              final isHeader = header.startsWith('──');
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isHeader)
                                    Container(
                                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: triageColor.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        header.replaceAll('──', '').replaceAll('─', '').trim(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: triageColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  // Build 196: fallback "Sem dados preenchidos" por seção
                                  if (body.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        body,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: textPrimary,
                                          height: 1.5,
                                        ),
                                      ),
                                    )
                                  else if (isHeader)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        isEs ? 'Sin datos completados' : 'Sem dados preenchidos',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
            ),

            // ── Footer: pills demográficas + CTA Evoluir ────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(19)),
                border: Border(top: BorderSide(color: borderColor, width: 0.8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pills demográficas
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (p.idade.isNotEmpty)
                        _infoPill(isEs ? 'Edad: ${p.idade}' : 'Idade: ${p.idade}',
                            triageColor, dark),
                      if (p.sexo.isNotEmpty)
                        _infoPill(p.sexo == 'M'
                            ? (isEs ? 'Masculino' : 'Masculino')
                            : (isEs ? 'Femenino' : 'Feminino'),
                            triageColor, dark),
                      _infoPill(
                          isEs
                              ? 'Día ${p.diaInternacao}'
                              : 'Dia ${p.diaInternacao}',
                          triageColor, dark),
                      _infoPill(
                          isEs
                              ? '${session.historial.length} evol.'
                              : '${session.historial.length} evol.',
                          triageColor, dark),
                    ],
                  ),

                  // BUILD 319: CTA "Evoluir" — navega direto para InternacionScreen
                  // Fecha o dialog e entrega a sessão ao onOpenInternacion do shell.
                  if (widget.onOpenInternacion != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.of(context).pop(); // fecha o dialog
                            widget.onOpenInternacion!(session);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  triageColor.withOpacity(0.85),
                                  triageColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: triageColor.withOpacity(0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isEs ? 'Evoluir paciente' : 'Evoluir paciente',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoPill(String label, Color color, bool dark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(dark ? 0.15 : 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.30), width: 0.8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Build 196: _SoapCopySheet — ModalBottomSheet tri-formato de cópia SOAP
// Exibido quando médico toca o botão copiar no _SoapPreviewDialog.
// Formatos: Completo (SOAP full) | Resumido (inline) | Passagem de Plantão (30s)
// ─────────────────────────────────────────────────────────────────────────────
class _SoapCopySheet extends StatelessWidget {
  final bool dark;
  final String lang;
  final VoidCallback onCopyFull;
  final VoidCallback onCopyResumida;
  final VoidCallback onCopyPasaje;

  const _SoapCopySheet({
    required this.dark,
    required this.lang,
    required this.onCopyFull,
    required this.onCopyResumida,
    required this.onCopyPasaje,
  });

  bool get isEs => lang == 'es';

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF0F1116) : Colors.white;
    final textPrimary = dark ? Colors.white : const Color(0xFF0D1117);
    final textSecondary = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = dark ? const Color(0xFF1A1F2E) : const Color(0xFFF8F9FA);
    final borderColor = dark ? const Color(0xFF2D3748) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFF059669).withOpacity(0.25)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        20 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Título
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF047857)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.copy_all_rounded, size: 17, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Exportar Evolución' : 'Exportar Evolução',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      isEs
                          ? 'Selecciona el formato de exportación'
                          : 'Selecione o formato de exportação',
                      style: TextStyle(fontSize: 11.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Modelo 1: Completo
          _SoapCopyTile(
            dark: dark,
            icon: Icons.description_rounded,
            iconColor: const Color(0xFF3B82F6),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            title: isEs ? 'Evolucion Completa' : 'Evolução Completa',
            subtitle: isEs
                ? 'Encabezado hospitalar + S/O/A/P jerárquico + firma'
                : 'Cabeçalho hospitalar + S/O/A/P hierárquico + assinatura',
            badgeLabel: 'SOAP',
            badgeColor: const Color(0xFF3B82F6),
            onTap: onCopyFull,
          ),
          const SizedBox(height: 8),

          // Modelo 2: Resumido
          _SoapCopyTile(
            dark: dark,
            icon: Icons.compress_rounded,
            iconColor: const Color(0xFF059669),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            title: isEs ? 'Evolucion Resumida' : 'Evolução Resumida',
            subtitle: isEs
                ? 'Formato horizontal denso — ideal para sistemas legados'
                : 'Formato horizontal denso — ideal para sistemas legados',
            badgeLabel: 'INLINE',
            badgeColor: const Color(0xFF059669),
            onTap: onCopyResumida,
          ),
          const SizedBox(height: 8),

          // Modelo 3: Passagem de Plantão
          _SoapCopyTile(
            dark: dark,
            icon: Icons.transfer_within_a_station_rounded,
            iconColor: const Color(0xFFF59E0B),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            title: isEs ? 'Pasaje de Guardia' : 'Passagem de Plantão',
            subtitle: isEs
                ? 'Ultra-objetivo para transición de turno en menos de 30s'
                : 'Ultra-objetivo para passagem de plantão em menos de 30s',
            badgeLabel: '30s',
            badgeColor: const Color(0xFFF59E0B),
            onTap: onCopyPasaje,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SoapCopyTile extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final Color iconColor;
  final Color cardBg;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final String title;
  final String subtitle;
  final String badgeLabel;
  final Color badgeColor;
  final VoidCallback onTap;

  const _SoapCopyTile({
    required this.dark,
    required this.icon,
    required this.iconColor,
    required this.cardBg,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 0.9),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(dark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 18, color: textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE PACIENTE (legacy — kept for PlantaoPatient edit sheet compatibility)
// ─────────────────────────────────────────────────────────────────────────────

class _PatientCard extends StatefulWidget {
  final PlantaoPatient patient;
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _PatientCard({
    required this.patient,
    required this.isEs,
    required this.colors,
    required this.onTap,
    required this.onRemove,
  });

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  bool _showRemove = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final pt = widget.patient;

    return GestureDetector(
      onTap: () {
        if (_showRemove) { setState(() => _showRemove = false); return; }
        AppHaptics.selection(context);
        widget.onTap();
      },
      onLongPress: () {
        AppHaptics.medium(context);
        setState(() => _showRemove = true);
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _showRemove
                ? AppColors.alertRedBg
                : c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showRemove
                  ? AppColors.alertRedBorder
                  : const Color(0xFF3B82F6).withOpacity(0.22),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(c.dark ? 0.20 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _showRemove
              ? _RemoveConfirmRow(
                  isEs: widget.isEs,
                  colors: c,
                  label: pt.name.isNotEmpty ? pt.name : (widget.isEs ? 'este paciente' : 'este paciente'),
                  onConfirm: widget.onRemove,
                  onCancel: () => setState(() => _showRemove = false),
                )
              : _PatientCardContent(patient: pt, isEs: widget.isEs, colors: c),
        ),
      ),
    );
  }
}

class _PatientCardContent extends StatelessWidget {
  final PlantaoPatient patient;
  final bool isEs;
  final AppColors colors;

  const _PatientCardContent({required this.patient, required this.isEs, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final pt = patient;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ícone quarto ───────────────────────────────────────────────────
        Column(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.bed_rounded, size: 20, color: Color(0xFF3B82F6)),
            ),
            if (pt.room.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pt.room,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF3B82F6)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: 12),

        // ── Dados do paciente ──────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome
              if (pt.name.isNotEmpty)
                Text(
                  pt.name,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

              // Diagnóstico
              if (pt.diagnosis.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Dx: ' : 'Dx: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textHint),
                    ),
                    Expanded(
                      child: Text(
                        pt.diagnosis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Tratamento
              if (pt.treatment.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEs ? 'Tto: ' : 'Trat: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.textHint),
                    ),
                    Expanded(
                      child: Text(
                        pt.treatment,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Notas
              if (pt.notes.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pt.notes,
                    style: TextStyle(fontSize: 10.5, color: c.textHint, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Chevron editar ─────────────────────────────────────────────────
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, size: 16, color: colors.textHint),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM ROW — remove patient / unpin
// ─────────────────────────────────────────────────────────────────────────────

class _RemoveConfirmRow extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final String label;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _RemoveConfirmRow({
    required this.isEs,
    required this.colors,
    required this.label,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.alertRed),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isEs ? 'Eliminar $label?' : 'Remover $label?',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.alertRed),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onCancel,
          child: Text(
            isEs ? 'No' : 'Não',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.textSecondary),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: onConfirm,
          child: const Text(
            'OK',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.alertRed),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUILD 280 — LOADING SHELL (substituição do SizedBox.shrink() no null-guard)
// Exibido quando context.watch<AppProvider>() lança exceção no primeiro frame.
// Garante que o card MEU PLANTÃO nunca seja invisível no mobile.
// ─────────────────────────────────────────────────────────────────────────────

class _PlantaoLoadingShell extends StatelessWidget {
  final AppColors colors;
  const _PlantaoLoadingShell({required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return Row(
      children: [
        // Ícone verde (mesmo do _PlantaoHeader)
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A7C4E), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.local_hospital_outlined, size: 16, color: kGoldLight),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'MEU PLANTÃO',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: c.gold,
            ),
          ),
        ),
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(c.green.withOpacity(0.60)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatefulWidget {
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;

  const _EmptyState({required this.isEs, required this.colors, required this.onTap});

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;

    return GestureDetector(
      onTap: () { AppHaptics.selection(context); widget.onTap(); },
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, __) => CustomPaint(
          painter: _DashedBorderPainter(
            color: c.green.withOpacity(_pulseAnim.value * 0.4),
            radius: 16, dashWidth: 6, dashSpace: 5,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: c.green.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ícones de hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HintChip(icon: Icons.bed_outlined, label: widget.isEs ? 'Pacientes' : 'Pacientes', color: const Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    _HintChip(icon: Icons.medication_outlined, label: widget.isEs ? 'Fármacos' : 'Fármacos', color: const Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    _HintChip(icon: Icons.calculate_outlined, label: widget.isEs ? 'Calcs' : 'Calcs', color: const Color(0xFF8B5CF6)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c.green.withOpacity(0.10),
                    shape: BoxShape.circle,
                    border: Border.all(color: c.green.withOpacity(0.25), width: 1.5),
                  ),
                  child: Icon(Icons.add_rounded, size: 22, color: c.green),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isEs ? 'Personaliza tu guardia' : 'Personalize seu plantão',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.3),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.isEs
                      ? 'Fija pacientes, fármacos y calculadoras\npara acceso inmediato en tu turno.'
                      : 'Fixe pacientes, fármacos e calculadoras\npara acesso imediato no plantão.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(color: c.green, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    widget.isEs ? 'Empezar →' : 'Começar →',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HintChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER — borda tracejada animada
// ─────────────────────────────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({required this.color, required this.radius, required this.dashWidth, required this.dashSpace});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 1.8..style = PaintingStyle.stroke;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final next = distance + (draw ? dashWidth : dashSpace);
        if (draw) canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// LABEL DE SEÇÃO
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors colors;
  final Color? accent;
  final Widget? trailing;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.colors,
    this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? colors.textHint;
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: color),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROW DE FÁRMACOS FIXADOS (scroll horizontal)
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedDrugsRow extends StatelessWidget {
  final List<DrugModel> drugs;
  final bool isEs;
  final AppColors colors;
  final void Function(DrugModel) onTap;
  final void Function(DrugModel) onUnpin;

  const _PinnedDrugsRow({required this.drugs, required this.isEs, required this.colors, required this.onTap, required this.onUnpin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // ListView horizontal dentro de SingleChildScrollView vertical:
        // eixos diferentes, sem conflito. Height fixa via SizedBox garante
        // que o pai não precise calcular altura — layout correto e fluido.
        clipBehavior: Clip.none,
        itemCount: drugs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _DrugPinnedCard(
          drug: drugs[i], isEs: isEs, colors: colors,
          onTap: () => onTap(drugs[i]),
          onUnpin: () => onUnpin(drugs[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE FÁRMACO FIXADO
// ─────────────────────────────────────────────────────────────────────────────

class _DrugPinnedCard extends StatefulWidget {
  final DrugModel drug;
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const _DrugPinnedCard({required this.drug, required this.isEs, required this.colors, required this.onTap, required this.onUnpin});

  @override
  State<_DrugPinnedCard> createState() => _DrugPinnedCardState();
}

class _DrugPinnedCardState extends State<_DrugPinnedCard> {
  bool _pressed = false;
  bool _showUnpin = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final drug = widget.drug;
    final route = drug.route.toUpperCase();
    final className = (drug.className[widget.isEs ? 'es' : 'pt'] ?? drug.className['es'] ?? '');
    final classShort = className.length > 14 ? '${className.substring(0, 13)}…' : className;

    return GestureDetector(
      onTap: () {
        if (_showUnpin) { setState(() => _showUnpin = false); return; }
        AppHaptics.selection(context);
        widget.onTap();
      },
      onLongPress: () { AppHaptics.medium(context); setState(() => _showUnpin = !_showUnpin); },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 130,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _showUnpin ? AppColors.alertRedBg : c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _showUnpin ? AppColors.alertRedBorder : c.border, width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(c.dark ? 0.25 : 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: _showUnpin
              ? _UnpinOverlay(isEs: widget.isEs, colors: c, onConfirm: widget.onUnpin, onCancel: () => setState(() => _showUnpin = false))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: c.green.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(route.length > 8 ? route.substring(0, 8) : route,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: c.green, letterSpacing: 0.5)),
                    ),
                    const Spacer(),
                    Text(drug.nameL10n(widget.isEs ? 'es' : 'pt'), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.3)),
                    const SizedBox(height: 2),
                    Text(classShort, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: c.textHint)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OVERLAY DE DESAFIXAR
// ─────────────────────────────────────────────────────────────────────────────

class _UnpinOverlay extends StatelessWidget {
  final bool isEs;
  final AppColors colors;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _UnpinOverlay({required this.isEs, required this.colors, required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.push_pin_outlined, size: 20, color: AppColors.alertRed),
        const SizedBox(height: 6),
        Text(isEs ? 'Desfijar?' : 'Desafixar?',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.alertRed)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(onTap: onCancel, child: Text(isEs ? 'No' : 'Não',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: colors.textSecondary))),
            const SizedBox(width: 16),
            GestureDetector(onTap: onConfirm, child: const Text('OK',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.alertRed))),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID DE CALCULADORAS FIXADAS — Wrap 3 colunas, design modular limpo
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedCalcsGrid extends StatelessWidget {
  final List<String> calcIds;
  final bool isEs;
  final AppColors colors;
  final void Function(String) onTap;
  final void Function(String) onUnpin;

  const _PinnedCalcsGrid({
    required this.calcIds,
    required this.isEs,
    required this.colors,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    // Defesa belt-and-suspenders: nunca renderiza IDs proibidos
    final safeIds = calcIds
        .where((id) => !_kForbiddenCalcIds.contains(id))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 3 colunas com gap de 8px entre elas
        const gap = 8.0;
        const cols = 3;
        final itemW = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final id in safeIds)
              Builder(builder: (_) {
                final shortcut = calcById(id);
                if (shortcut == null) return const SizedBox.shrink();
                return SizedBox(
                  width: itemW,
                  child: _CalcPinnedCard(
                    shortcut: shortcut,
                    isEs: isEs,
                    colors: colors,
                    onTap: () => onTap(shortcut.id),
                    onUnpin: () => onUnpin(shortcut.id),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROW DE CALCULADORAS FIXADAS — scroll horizontal (mantido para retrocompat.)
// ─────────────────────────────────────────────────────────────────────────────

class _PinnedCalcsRow extends StatelessWidget {
  final List<String> calcIds;
  final bool isEs;
  final AppColors colors;
  final void Function(String) onTap;
  final void Function(String) onUnpin;

  const _PinnedCalcsRow({required this.calcIds, required this.isEs, required this.colors, required this.onTap, required this.onUnpin});

  @override
  Widget build(BuildContext context) {
    final safeIds = calcIds
        .where((id) => !_kForbiddenCalcIds.contains(id))
        .toList();

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: safeIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final shortcut = calcById(safeIds[i]);
          if (shortcut == null) return const SizedBox.shrink();
          return _CalcPinnedCard(
            shortcut: shortcut, isEs: isEs, colors: colors,
            onTap: () => onTap(shortcut.id),
            onUnpin: () => onUnpin(shortcut.id),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE CALCULADORA FIXADA
// ─────────────────────────────────────────────────────────────────────────────

class _CalcPinnedCard extends StatefulWidget {
  final CalcShortcut shortcut;
  final bool isEs;
  final AppColors colors;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const _CalcPinnedCard({required this.shortcut, required this.isEs, required this.colors, required this.onTap, required this.onUnpin});

  @override
  State<_CalcPinnedCard> createState() => _CalcPinnedCardState();
}

class _CalcPinnedCardState extends State<_CalcPinnedCard> {
  bool _pressed = false;
  bool _showUnpin = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final s = widget.shortcut;

    return GestureDetector(
      onTap: () {
        if (_showUnpin) { setState(() => _showUnpin = false); return; }
        AppHaptics.selection(context);
        widget.onTap();
      },
      onLongPress: () { AppHaptics.medium(context); setState(() => _showUnpin = !_showUnpin); },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          // Sem width fixo — o SizedBox pai do grid controla a largura
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: _showUnpin ? AppColors.alertRedBg : c.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showUnpin
                  ? AppColors.alertRedBorder
                  : s.color.withOpacity(0.20),
              width: 1.2,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(c.dark ? 0.22 : 0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: _showUnpin
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.alertRed),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: widget.onUnpin,
                      child: const Text('OK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.alertRed)),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: s.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(s.icon, size: 18, color: s.color),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      s.label(widget.isEs),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: c.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET DE EDIÇÃO DE PACIENTE
// ─────────────────────────────────────────────────────────────────────────────

class _PatientEditSheet extends StatefulWidget {
  final bool isEs;
  final PlantaoPatient? existing;

  const _PatientEditSheet({required this.isEs, this.existing});

  @override
  State<_PatientEditSheet> createState() => _PatientEditSheetState();
}

class _PatientEditSheetState extends State<_PatientEditSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _roomCtrl;
  late TextEditingController _dxCtrl;
  late TextEditingController _ttoCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    final pt = widget.existing;
    _nameCtrl  = TextEditingController(text: pt?.name ?? '');
    _roomCtrl  = TextEditingController(text: pt?.room ?? '');
    _dxCtrl    = TextEditingController(text: pt?.diagnosis ?? '');
    _ttoCtrl   = TextEditingController(text: pt?.treatment ?? '');
    _notesCtrl = TextEditingController(text: pt?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _roomCtrl.dispose(); _dxCtrl.dispose();
    _ttoCtrl.dispose();  _notesCtrl.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final p = context.read<AppProvider>();
    final isEdit = widget.existing != null;

    final patient = PlantaoPatient(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      room: _roomCtrl.text.trim(),
      diagnosis: _dxCtrl.text.trim(),
      treatment: _ttoCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      savedAt: widget.existing?.savedAt ?? DateTime.now(),
    );

    if (patient.name.isEmpty && patient.room.isEmpty && patient.diagnosis.isEmpty) {
      Navigator.pop(context);
      return;
    }

    p.savePlantaoPatient(patient);
    AppHaptics.medium(context);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        isEdit
            ? (widget.isEs ? 'Paciente actualizado.' : 'Paciente atualizado.')
            : (widget.isEs ? 'Paciente agregado al turno.' : 'Paciente adicionado ao plantão.'),
      ),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isEs = widget.isEs;
    final screenH = MediaQuery.of(context).size.height;
    final isEdit = widget.existing != null;

    return SizedBox(
      height: screenH * 0.90,
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // ── Título ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bed_rounded, size: 18, color: Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit
                              ? (isEs ? 'Editar Paciente' : 'Editar Paciente')
                              : (isEs ? 'Nuevo Paciente en Turno' : 'Novo Paciente no Plantão'),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.3),
                        ),
                        Text(
                          isEs ? 'Presione guardar para fijar en el turno' : 'Pressione salvar para fixar no plantão',
                          style: TextStyle(fontSize: 11, color: c.textHint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Formulário ──────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome + Quarto (lado a lado)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _FieldBlock(
                            label: isEs ? 'Nombre del paciente' : 'Nome do paciente',
                            icon: Icons.person_outline_rounded,
                            controller: _nameCtrl,
                            hint: isEs ? 'Ej: Juan Pérez' : 'Ex: João Silva',
                            colors: c,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _FieldBlock(
                            label: isEs ? 'Habitación / Cama' : 'Quarto / Leito',
                            icon: Icons.bed_outlined,
                            controller: _roomCtrl,
                            hint: '204-A',
                            colors: c,
                            maxLines: 1,
                            accent: const Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Diagnóstico
                    _FieldBlock(
                      label: isEs ? 'Diagnóstico principal' : 'Diagnóstico principal',
                      icon: Icons.medical_information_outlined,
                      controller: _dxCtrl,
                      hint: isEs ? 'Ej: Neumonía adquirida en la comunidad' : 'Ex: Pneumonia adquirida na comunidade',
                      colors: c,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // Tratamento
                    _FieldBlock(
                      label: isEs ? 'Tratamiento / medicamentos' : 'Tratamento / medicamentos',
                      icon: Icons.medication_outlined,
                      controller: _ttoCtrl,
                      hint: isEs ? 'Ej: Amoxicilina 875mg 12/12h + O2 2L/min' : 'Ex: Amoxicilina 875mg 12/12h + O2 2L/min',
                      colors: c,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    // Notas
                    _FieldBlock(
                      label: isEs ? 'Notas del turno' : 'Notas do plantão',
                      icon: Icons.notes_rounded,
                      controller: _notesCtrl,
                      hint: isEs ? 'Evolución, pendientes, alertas…' : 'Evolução, pendências, alertas…',
                      colors: c,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Botões
                    Row(
                      children: [
                        if (isEdit) ...[
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                AppHaptics.medium(context);
                                context.read<AppProvider>().removePlantaoPatient(widget.existing!.id);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.alertRedBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.alertRedBorder),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.alertRed),
                                    SizedBox(width: 6),
                                    Text('Remover', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.alertRed)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: () => _save(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0A7C4E), Color(0xFF10B981)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF0A7C4E).withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.save_outlined, size: 16, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    isEs ? 'Guardar en turno' : 'Salvar no plantão',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMPO DO FORMULÁRIO
// ─────────────────────────────────────────────────────────────────────────────

class _FieldBlock extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final AppColors colors;
  final int maxLines;
  final Color? accent;

  const _FieldBlock({
    required this.label,
    required this.icon,
    required this.controller,
    required this.hint,
    required this.colors,
    required this.maxLines,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final ac = accent ?? c.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: ac),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac, letterSpacing: 0.3)),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: 1,
          style: TextStyle(fontSize: 13.5, color: c.textPrimary, height: 1.4),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12.5, color: c.textHint),
            filled: true,
            fillColor: c.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: ac.withOpacity(0.50), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET DE GERENCIAMENTO — abre via showPlantaoManageSheet()
// ─────────────────────────────────────────────────────────────────────────────

void showPlantaoManageSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PlantaoManageSheet(),
  );
}

class _PlantaoManageSheet extends StatefulWidget {
  const _PlantaoManageSheet();

  @override
  State<_PlantaoManageSheet> createState() => _PlantaoManageSheetState();
}

class _PlantaoManageSheetState extends State<_PlantaoManageSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final c = AppColors.of(context);
    final isEs = p.lang == 'es';
    final screenH = MediaQuery.of(context).size.height;

    return SizedBox(
      height: screenH * 0.88,
      child: Container(
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.push_pin_outlined, size: 20, color: c.gold),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEs ? 'Gestionar Mi Guardia' : 'Gerenciar Meu Plantão',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.textPrimary, letterSpacing: -0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                isEs
                    ? 'Toca para fijar/desfijar. Límites: ${AppProvider.kMaxPinnedDrugsPublic} fármacos, ${AppProvider.kMaxPinnedCalcsPublic} calculadoras.'
                    : 'Toque para fixar/desafixar. Limites: ${AppProvider.kMaxPinnedDrugsPublic} fármacos, ${AppProvider.kMaxPinnedCalcsPublic} calculadoras.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.textSecondary, height: 1.4),
              ),
            ),
            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: Colors.white,
                  unselectedLabelColor: c.textSecondary,
                  indicator: BoxDecoration(color: c.green, borderRadius: BorderRadius.circular(8)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  padding: const EdgeInsets.all(3),
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  tabs: [
                    Tab(text: isEs ? 'Fármacos' : 'Fármacos'),
                    Tab(text: isEs ? 'Calculadoras' : 'Calculadoras'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            AnimatedBuilder(
              animation: _tabCtrl,
              builder: (_, __) {
                if (_tabCtrl.index != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 14, color: c.textPrimary),
                    decoration: InputDecoration(
                      hintText: isEs ? 'Buscar fármaco…' : 'Buscar medicamento…',
                      hintStyle: TextStyle(fontSize: 13, color: c.textHint),
                      prefixIcon: Icon(Icons.search_rounded, color: c.textHint, size: 18),
                      filled: true,
                      fillColor: c.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                  ),
                );
              },
            ),

            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _DrugSelectorList(searchQuery: _searchCtrl.text, p: p, c: c, isEs: isEs),
                  _CalcSelectorList(p: p, c: c, isEs: isEs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA DE SELEÇÃO DE FÁRMACOS
// ─────────────────────────────────────────────────────────────────────────────

class _DrugSelectorList extends StatelessWidget {
  final String searchQuery;
  final AppProvider p;
  final AppColors c;
  final bool isEs;

  const _DrugSelectorList({required this.searchQuery, required this.p, required this.c, required this.isEs});

  @override
  Widget build(BuildContext context) {
    final q = searchQuery.toLowerCase().trim();
    final drugs = q.isEmpty
        ? p.drugsDB
        : p.drugsDB.where((d) =>
            d.name.toLowerCase().contains(q) ||
            (d.className[isEs ? 'es' : 'pt'] ?? '').toLowerCase().contains(q) ||
            d.group.toLowerCase().contains(q)).toList();

    if (drugs.isEmpty) {
      return Center(child: Text(isEs ? 'Sin resultados' : 'Sem resultados', style: TextStyle(color: c.textHint, fontSize: 14)));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: drugs.length,
      itemBuilder: (_, i) {
        final drug = drugs[i];
        final isPinned = p.isDrugPinned(drug.id);
        final limitReached = p.pinnedDrugIds.length >= AppProvider.kMaxPinnedDrugsPublic;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () {
              AppHaptics.selection(context);
              final result = p.togglePinDrug(drug.id);
              if (result == PinResult.limitReached) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEs
                      ? 'Límite de ${AppProvider.kMaxPinnedDrugsPublic} fármacos alcanzado.'
                      : 'Limite de ${AppProvider.kMaxPinnedDrugsPublic} fármacos atingido.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isPinned ? c.green.withOpacity(0.08) : c.cardBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isPinned ? c.green.withOpacity(0.35) : c.border, width: isPinned ? 1.5 : 1.0),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(drug.nameL10n(isEs ? 'es' : 'pt'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
                        const SizedBox(height: 2),
                        Text(drug.className[isEs ? 'es' : 'pt'] ?? drug.className['es'] ?? '',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.textHint)),
                      ],
                    ),
                  ),
                  if (!isPinned && limitReached)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(6)),
                      child: Text(isEs ? 'Lleno' : 'Cheio', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: c.textHint)),
                    ),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: isPinned ? c.green : c.surface, shape: BoxShape.circle),
                    child: Icon(isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        size: 14, color: isPinned ? Colors.white : c.textHint),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA DE SELEÇÃO DE CALCULADORAS
// ─────────────────────────────────────────────────────────────────────────────

class _CalcSelectorList extends StatelessWidget {
  final AppProvider p;
  final AppColors c;
  final bool isEs;

  const _CalcSelectorList({required this.p, required this.c, required this.isEs});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      itemCount: kAvailableCalcs.length,
      itemBuilder: (_, i) {
        final shortcut = kAvailableCalcs[i];
        // ⛔ CRÍTICO — nunca exibe calc proibida (Apple 1.4.1 + regulatório)
        if (_kForbiddenCalcIds.contains(shortcut.id)) return const SizedBox.shrink();
        final isPinned = p.isCalcPinned(shortcut.id);
        final limitReached = p.pinnedCalcIds.length >= AppProvider.kMaxPinnedCalcsPublic;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () {
              AppHaptics.selection(context);
              final result = p.togglePinCalc(shortcut.id);
              if (result == PinResult.limitReached) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(isEs
                      ? 'Límite de ${AppProvider.kMaxPinnedCalcsPublic} calculadoras alcanzado.'
                      : 'Limite de ${AppProvider.kMaxPinnedCalcsPublic} calculadoras atingido.'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isPinned ? shortcut.color.withOpacity(0.07) : c.cardBg2,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isPinned ? shortcut.color.withOpacity(0.35) : c.border, width: isPinned ? 1.5 : 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: shortcut.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(shortcut.icon, size: 20, color: shortcut.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(shortcut.label(isEs), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary))),
                  if (!isPinned && limitReached)
                    Text(isEs ? 'Lleno' : 'Cheio', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.textHint)),
                  const SizedBox(width: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: isPinned ? shortcut.color : c.surface, shape: BoxShape.circle),
                    child: Icon(isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                        size: 14, color: isPinned ? Colors.white : c.textHint),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
