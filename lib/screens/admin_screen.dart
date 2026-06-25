import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
// Import condicional: pdf_picker_web.dart (Web, usa dart:html) ou stub (iOS/Android, no-op).
// Isola dart:html do compilador nativo — resolve build iOS/Android.
import '../platform/pdf_picker_stub.dart'
    if (dart.library.html) '../platform/pdf_picker_web.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // PARTE 4 BUILD 238
import 'package:shared_preferences/shared_preferences.dart';
// file_picker e firebase_storage usados via StorageService — sem import direto aqui
import '../models/user_model.dart';
import '../models/guide_model.dart';
import '../models/influencer_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/referral_service.dart';
import '../services/provider_router_service.dart'; // Build 226
import '../widgets/common_widgets.dart';

class AdminScreen extends StatefulWidget {
  final UserModel currentAdmin;
  const AdminScreen({super.key, required this.currentAdmin});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String _search = '';

  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);

  bool get _isMaster => widget.currentAdmin.isMaster;

  // ── Stream único compartilhado — evita N polls paralelos por tab ──────────
  StreamSubscription<List<UserModel>>? _usersSub;
  List<UserModel> _allUsers  = [];
  bool            _usersLoading = true;

  // ── Estado do tab Sistema ────────────────────────────────────────────────
  bool _maintEnabled = false;
  bool _maintLoading = false;
  final TextEditingController _maintMsgCtrl = TextEditingController();

  // ── PARTE 4 BUILD 238: Stream de admin_notifications ─────────────────────
  StreamSubscription<List<Map<String, dynamic>>>? _notifSub;
  List<Map<String, dynamic>> _adminNotifs = [];
  int get _unreadNotifCount {
    final adminUid = widget.currentAdmin.uid;
    return _adminNotifs.where((n) {
      final readBy = (n['readBy'] as List?) ?? [];
      return !readBy.contains(adminUid);
    }).length;
  }

  void _subscribeNotifications() {
    final db = FirebaseFirestore.instance;
    _notifSub = db
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList())
        .listen(
      (notifs) {
        if (mounted) setState(() => _adminNotifs = notifs);
      },
      onError: (e) => debugPrint('[ADMIN_NOTIF] stream error: $e'),
    );
  }

  Future<void> _markNotifRead(String notifId) async {
    try {
      final adminUid = widget.currentAdmin.uid;
      await FirebaseFirestore.instance
          .collection('admin_notifications')
          .doc(notifId)
          .update({'readBy': FieldValue.arrayUnion([adminUid])});
      debugPrint('[ADMIN_NOTIF] marcado lido: notifId=$notifId adminUid=$adminUid');
    } catch (e) {
      debugPrint('[ADMIN_NOTIF] erro mark-read: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 10, vsync: this);
    _loadLang();
    _subscribeUsers();
    _subscribeNotifications();
  }

  Future<void> _refreshUsers() async {
    setState(() => _usersLoading = true);
    _usersSub?.cancel();
    _subscribeUsers();
  }

  void _subscribeUsers() {
    _usersSub = AuthService.allUsersStream().listen(
      (users) {
        if (mounted) setState(() { _allUsers = users; _usersLoading = false; });
      },
      onError: (_) {
        if (mounted) setState(() => _usersLoading = false);
      },
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _maintMsgCtrl.dispose();
    _usersSub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      appBar: AppBar(
        backgroundColor: kDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Icon(Icons.admin_panel_settings_rounded, color: kGoldL, size: 20),
          const SizedBox(width: 8),
          Text(
            _isMaster ? _masterPanelLabel : _adminPanelLabel,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          if (_isMaster) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.amber.withValues(alpha: 0.2),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: const Text('MASTER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.amber)),
            ),
          ],
        ]),
        actions: [
          IconButton(
            icon: _usersLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Atualizar lista',
            onPressed: _usersLoading ? null : _refreshUsers,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: kGoldL,
          labelColor: kGoldL,
          unselectedLabelColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(icon: const Icon(Icons.pending_actions_rounded, size: 16), text: _pendingLabel),
            Tab(icon: const Icon(Icons.people_rounded, size: 16), text: _approvedLabel),
            Tab(icon: const Icon(Icons.block_rounded, size: 16), text: _blockedLabel),
            Tab(icon: const Icon(Icons.settings_rounded, size: 16), text: _systemLabel),
            const Tab(icon: Icon(Icons.auto_awesome_rounded, size: 16), text: 'Novidades'),
            const Tab(icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'Stats'),
            const Tab(icon: Icon(Icons.mark_email_unread_rounded, size: 16), text: 'E-mail'),
            const Tab(icon: Icon(Icons.menu_book_rounded, size: 16), text: 'Biblioteca'),
            const Tab(icon: Icon(Icons.people_alt_rounded, size: 16), text: 'Indicações'),
            // PARTE 4 BUILD 238 — Tab Notificações com badge de não-lidos
            Tab(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_rounded, size: 16),
                  if (_unreadNotifCount > 0)
                    Positioned(
                      right: -6, top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          '$_unreadNotifCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              text: 'Notificações',
            ),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          // Tabs de "sistema" não têm barra de busca: 3=Sistema, 4=Novidades,
          // 5=Stats, 6=E-mail, 7=Biblioteca, 8=Indicações, 9=Notificações
          final isSystemTab = _tabs.index >= 3;
          return Column(
            children: [
              // Barra de busca — só nas tabs de usuários (0, 1, 2)
              if (!isSystemTab)
                Container(
                  color: kDark,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                    autocorrect: false,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _searchHint,
                      hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              // Indicador de carregamento inicial (só na primeira carga)
              if (_usersLoading && _allUsers.isEmpty && !isSystemTab)
                const LinearProgressIndicator(color: kGreen, backgroundColor: Colors.transparent),
              // Conteúdo das tabs
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    // ── Tab 0: Pendentes ──────────────────────────────────
                    _UserList(
                      users: _filter(_allUsers, UserStatus.pending),
                      emptyMsg: _emptyPendingMsg,
                      emptyIcon: Icons.check_circle_outline_rounded,
                      currentAdmin: widget.currentAdmin,
                      isMaster: _isMaster,
                      onApprove: _approve,
                      onDelete: _delete,
                      showApprove: true,
                      isPendingTab: true,
                    ),
                    // ── Tab 1: Aprovados ──────────────────────────────────
                    _UserList(
                      users: _filter(_allUsers, UserStatus.approved),
                      emptyMsg: _emptyApprovedMsg,
                      emptyIcon: Icons.people_outline_rounded,
                      currentAdmin: widget.currentAdmin,
                      isMaster: _isMaster,
                      onBlock: _block,
                      onPromote: _promote,
                      onPromoteSupervisor: _isMaster ? _promoteSupervisor : null,
                      onDemote: _isMaster ? _demote : null,
                      onDelete: _delete,
                      showBlock: true,
                      showPromote: true,
                    ),
                    // ── Tab 2: Bloqueados ─────────────────────────────────
                    _UserList(
                      users: _filter(_allUsers, UserStatus.blocked),
                      emptyMsg: _emptyBlockedMsg,
                      emptyIcon: Icons.verified_user_outlined,
                      currentAdmin: widget.currentAdmin,
                      isMaster: _isMaster,
                      onApprove: _unblock,
                      onDelete: _delete,
                      showApprove: true,
                      approveBtnLabel: _unblockLabel,
                    ),
                    // ── Tab 3: Sistema ────────────────────────────────────
                    _SystemTab(
                      currentAdmin: widget.currentAdmin,
                      isMaster: _isMaster,
                      maintEnabled: _maintEnabled,
                      maintLoading: _maintLoading,
                      maintMsgCtrl: _maintMsgCtrl,
                      isEs: _isEs,
                      onToggle: _toggleMaintenance,
                    ),
                    // ── Tab 4: Novidades ──────────────────────────────────
                    _AppUpdatesTab(currentAdmin: widget.currentAdmin),
                    // ── Tab 5: Stats ──────────────────────────────────────
                    _StatsTab(allUsers: _allUsers, loading: _usersLoading),
                    // ── Tab 6: E-mail ─────────────────────────────────────
                    _EmailTab(allUsers: _allUsers, currentAdmin: widget.currentAdmin),
                    // ── Tab 7: Biblioteca ─────────────────────────────────
                    _BibliotecaAdminTab(currentAdmin: widget.currentAdmin),
                    // ── Tab 8: Indicações ─────────────────────────────────
                    const _InfluencersTab(),
                    // ── Tab 9: Notificações (PARTE 4 BUILD 238) ───────────
                    _NotificationsTab(
                      notifications: _adminNotifs,
                      currentAdminUid: widget.currentAdmin.uid,
                      onMarkRead: _markNotifRead,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      // FAB com contagem de pendentes — lê do estado local, sem stream extra
      floatingActionButton: Builder(builder: (_) {
        final pendingCount = _allUsers.where((u) => u.isPending).length;
        if (pendingCount == 0) return const SizedBox.shrink();
        return FloatingActionButton.extended(
          onPressed: () => _tabs.animateTo(0),
          backgroundColor: Colors.orange,
          icon: const Icon(Icons.notification_important_rounded, color: Colors.white),
          label: Text('$pendingCount ${_pendingCountLabel(pendingCount)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        );
      }),
    );
  }

  List<UserModel> _filter(List<UserModel> all, UserStatus status) {
    return all
        .where((u) => u.status == status)
        .where((u) => _search.isEmpty ||
            u.displayName.toLowerCase().contains(_search) ||
            u.email.toLowerCase().contains(_search))
        .toList();
  }

  Future<void> _approve(UserModel u) async {
    try {
      await AuthService.approveUser(u.uid, widget.currentAdmin.uid);
      if (mounted) _snack('${u.displayName} $_approvedSnack', Colors.green);
    } catch (e) {
      if (mounted) _snack('$_errorPrefix: $e', Colors.red);
    }
  }

  Future<void> _unblock(UserModel u) async {
    try {
      await AuthService.unblockUser(u.uid, widget.currentAdmin.uid);
      if (mounted) _snack('${u.displayName} $_unblockedSnack', Colors.green);
    } catch (e) {
      if (mounted) _snack('$_errorPrefix: $e', Colors.red);
    }
  }

  Future<void> _delete(UserModel u) async {
    final confirm = await _confirmDialog(
      'Excluir ${u.displayName}?',
      'O documento do usuário será removido do Firestore permanentemente. Esta ação não pode ser desfeita.',
    );
    if (!confirm) return;
    try {
      await AuthService.deleteUser(u.uid);
      if (mounted) _snack('${u.displayName} excluído.', Colors.red);
    } catch (e) {
      if (mounted) _snack('$_errorPrefix: $e', Colors.red);
    }
  }

  Future<void> _block(UserModel u) async {
    final confirm = await _confirmDialog(
      'Bloquear ${u.displayName}?',
      'O usuário perderá acesso imediatamente.',
    );
    if (!confirm) return;
    try {
      await AuthService.blockUser(u.uid);
      if (mounted) _snack('${u.displayName} $_blockedSnack', Colors.orange);
    } catch (e) {
      if (mounted) _snack('$_errorPrefix: $e', Colors.red);
    }
  }

  Future<void> _promote(UserModel u) async {
    // Admin pode promover a supervisor; Master pode promover a admin
    if (_isMaster) {
      final confirm = await _confirmDialog(
        'Promover ${u.displayName} a Admin?',
        'Ele terá acesso ao painel de administração.',
      );
      if (!confirm) return;
      try {
        await AuthService.promoteToAdmin(u.uid);
        if (mounted) _snack('${u.displayName} $_promotedAdminSnack', kGold);
      } catch (e) {
        if (mounted) _snack('$_errorPrefix: $e', Colors.red);
      }
    } else {
      // Admin normal só pode promover a supervisor
      await _promoteSupervisor(u);
    }
  }

  Future<void> _promoteSupervisor(UserModel u) async {
    final confirm = await _confirmDialog(
      'Promover ${u.displayName} a Supervisor?',
      'Ele poderá ocultar e excluir histórias clínicas públicas.',
    );
    if (!confirm) return;
    try {
      await AuthService.promoteToSupervisor(u.uid);
      if (mounted) _snack('${u.displayName} $_promotedSupervisorSnack', Colors.blue);
    } catch (e) {
      if (mounted) _snack('$_errorPrefix: $e', Colors.red);
    }
  }

  Future<void> _demote(UserModel u) async {
    final confirm = await _confirmDialog(
      'Rebaixar ${u.displayName}?',
      'O usuário voltará a ser um usuário comum, sem poderes administrativos.',
    );
    if (!confirm) return;
    try {
      await AuthService.demoteToUser(u.uid);
      if (mounted) _snack('${u.displayName} $_demotedSnack', Colors.grey);
    } catch (e) {
      if (mounted) _snack('$_errorPrefix: $e', Colors.red);
    }
  }

  Future<bool> _confirmDialog(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFFFFFDF8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kDark)),
            content: Text(body, style: TextStyle(fontSize: 13, color: kDark.withValues(alpha: 0.7))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar / Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: kDark, foregroundColor: kGoldL),
                child: const Text('Confirmar / Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }


  // ── Helpers de idioma ──────────────────────────────────────────────────────
  // AdminScreen não tem AppProvider; usa preferência salva localmente.
  String _currentLang = 'pt';
  bool get _isEs => _currentLang == 'es';

  void _loadLang() {
    // ignorar erro se SharedPreferences não disponível
    try {
      SharedPreferences.getInstance().then((prefs) {
        final lang = prefs.getString('lang') ?? 'pt';
        if (mounted && lang != _currentLang) setState(() => _currentLang = lang);
      });
    } catch (_) {}
  }

  // ── Toggle de manutenção ───────────────────────────────────────────────
  Future<void> _toggleMaintenance(bool value) async {
    setState(() => _maintLoading = true);
    try {
      await FirestoreService.setMaintenance(
        enabled: value,
        updatedBy: widget.currentAdmin.uid,
        message: _maintMsgCtrl.text.trim(),
      );
      setState(() => _maintEnabled = value);
      if (mounted) {
        _snack(
          value
              ? (_isEs ? 'Modo mantenimiento activado' : 'Modo manutenção ativado')
              : (_isEs ? 'Sistema en línea nuevamente' : 'Sistema online novamente'),
          value ? Colors.orange : kGreen,
        );
      }
    } catch (e) {
      if (mounted) _snack('Erro: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _maintLoading = false);
    }
  }

  String get _errorPrefix            => _isEs ? 'Error al ejecutar acción'      : 'Erro ao executar ação';
  String get _masterPanelLabel       => _isEs ? 'Panel Master'                 : 'Painel Master';
  String get _adminPanelLabel        => _isEs ? 'Panel Admin'                  : 'Painel Admin';
  String get _pendingLabel           => _isEs ? 'Pendientes'                   : 'Pendentes';
  String get _approvedLabel          => _isEs ? 'Aprobados'                    : 'Aprovados';
  String get _blockedLabel           => _isEs ? 'Bloqueados'                   : 'Bloqueados';
  String get _systemLabel            => _isEs ? 'Sistema'                      : 'Sistema';
  String get _searchHint             => _isEs ? 'Buscar por nombre o correo...' : 'Buscar por nome ou e-mail...';
  String get _emptyPendingMsg        => _isEs ? 'Ningún usuario pendiente'     : 'Nenhum usuário pendente';
  String get _emptyApprovedMsg       => _isEs ? 'Ningún usuario aprobado'      : 'Nenhum usuário aprovado';
  String get _emptyBlockedMsg        => _isEs ? 'Ningún usuario bloqueado'     : 'Nenhum usuário bloqueado';
  String get _unblockLabel           => _isEs ? 'Desbloquear'                  : 'Desbloquear';
  String get _approvedSnack          => _isEs ? 'aprobado!'                    : 'aprovado!';
  String get _unblockedSnack         => _isEs ? 'desbloqueado!'                : 'desbloqueado!';
  String get _blockedSnack           => _isEs ? 'bloqueado.'                   : 'bloqueado.';
  String get _promotedAdminSnack     => _isEs ? 'promovido a Admin!'           : 'promovido a Admin!';
  String get _promotedSupervisorSnack=> _isEs ? 'promovido a Supervisor!'      : 'promovido a Supervisor!';
  String get _demotedSnack           => _isEs ? 'rebajado a Usuario.'          : 'rebaixado para Usuário.';
  String _pendingCountLabel(int n)   => _isEs ? (n > 1 ? 'pendientes' : 'pendiente') : (n > 1 ? 'pendentes' : 'pendente');

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ));
  }
}



// ── Tab Sistema — toggle de manutenção ────────────────────────────────────────
class _SystemTab extends StatefulWidget {
  final UserModel currentAdmin;
  final bool isMaster;
  final bool maintEnabled;
  final bool maintLoading;
  final TextEditingController maintMsgCtrl;
  final bool isEs;
  final Future<void> Function(bool) onToggle;

  const _SystemTab({
    required this.currentAdmin,
    required this.isMaster,
    required this.maintEnabled,
    required this.maintLoading,
    required this.maintMsgCtrl,
    required this.isEs,
    required this.onToggle,
  });

  @override
  State<_SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends State<_SystemTab> {
  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);

  AppColors get _c => AppColors.of(context);

  // ── OpenAI key state ───────────────────────────────────────────────────────
  final _aiKeyCtrl = TextEditingController();
  bool _aiKeyLoading = false;
  bool _aiKeySaved   = false;
  bool _aiKeyHidden  = true;
  String _aiKeyOriginal = '';

  // ── Gemini Paid Proxy state — Build 226 ────────────────────────────────────
  // SEGURANÇA: A GEMINI_PAID_API_KEY NUNCA é lida/exibida aqui.
  // O painel apenas controla o FLAG de ativação (geminiPaidEnabled).
  // A chave real fica no Firebase Secret (GEMINI_PAID_API_KEY), configurada
  // via terminal: firebase functions:secrets:set GEMINI_PAID_API_KEY
  bool _paidEnabled        = false;
  bool _paidLoading        = false;
  bool _paidTesting        = false;
  bool _paidTestDone       = false;
  bool _paidTestOnline     = false;
  String _paidTestDetail   = '';
  Map<String, dynamic> _paidBudgetCounters = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentAiKey();
    _loadPaidConfig();   // Build 226
  }

  @override
  void dispose() {
    _aiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAiKey() async {
    final key = await FirestoreService.loadAppAiKey();
    if (!mounted) return;
    setState(() {
      _aiKeyOriginal = key;
      if (key.isNotEmpty) _aiKeyCtrl.text = key;
    });
  }

  // ── Build 226: carrega config do Gemini Paid ───────────────────────────────
  Future<void> _loadPaidConfig() async {
    final enabled  = await FirestoreService.loadGeminiPaidEnabled();
    final counters = await FirestoreService.loadPaidBudgetCounters();
    if (!mounted) return;
    setState(() {
      _paidEnabled        = enabled;
      _paidBudgetCounters = counters;
    });
  }

  Future<void> _savePaidEnabled(bool value) async {
    setState(() { _paidLoading = true; });
    try {
      await FirestoreService.saveGeminiPaidEnabled(value);
      if (mounted) {
        setState(() {
          _paidEnabled = value;
          _paidLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _paidLoading = false; });
    }
  }

  Future<void> _testPaidProxy() async {
    setState(() { _paidTesting = true; _paidTestDone = false; });
    try {
      final result = await ProviderRouterService.testPaidProxy();
      if (mounted) {
        setState(() {
          _paidTesting    = false;
          _paidTestDone   = true;
          _paidTestOnline = result.online;
          _paidTestDetail = result.detail;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paidTesting    = false;
          _paidTestDone   = true;
          _paidTestOnline = false;
          _paidTestDetail = e.toString();
        });
      }
    }
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) setState(() { _paidTestDone = false; });
  }

  Future<void> _saveAiKey() async {
    final key = _aiKeyCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() { _aiKeyLoading = true; _aiKeySaved = false; });
    try {
      await FirestoreService.saveAppAiKey(key);
      _aiKeyOriginal = key;
      if (mounted) setState(() { _aiKeyLoading = false; _aiKeySaved = true; });
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() { _aiKeySaved = false; });
    } catch (_) {
      if (mounted) setState(() { _aiKeyLoading = false; });
    }
  }

  Future<void> _removeAiKey() async {
    setState(() { _aiKeyLoading = true; });
    try {
      await FirestoreService.saveAppAiKey('');
      _aiKeyOriginal = '';
      _aiKeyCtrl.clear();
      if (mounted) setState(() { _aiKeyLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _aiKeyLoading = false; });
    }
  }

  // ── Build 226: Widget do card IA Paga / Gemini Fallback ───────────────────
  Widget _buildGeminiPaidCard() {
    const kGeminiBlue  = Color(0xFF4285F4);
    const kGeminiBlueBg = Color(0xFF4285F4);
    final isActive = _paidEnabled;
    final dailyDate     = _paidBudgetCounters['dailyDate'] as String? ?? '';
    final todayKey      = DateTime.now().toIso8601String().substring(0, 10);
    final dailyCount    = dailyDate == todayKey
        ? (_paidBudgetCounters['dailyCount'] as num?)?.toInt() ?? 0
        : 0;
    final estimatedCost = _paidBudgetCounters['estimatedPaidCostUsd']?.toString() ?? '0.000000';

    return Container(
      decoration: BoxDecoration(
        color: _c.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? kGeminiBlue.withValues(alpha: 0.4)
              : _c.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              color: isActive
                  ? kGeminiBlue.withValues(alpha: 0.07)
                  : _c.surface,
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isActive
                      ? kGeminiBlue.withValues(alpha: 0.12)
                      : _c.surface,
                  border: Border.all(
                    color: isActive
                        ? kGeminiBlue.withValues(alpha: 0.4)
                        : _c.border,
                  ),
                ),
                child: Icon(
                  isActive ? Icons.bolt_rounded : Icons.bolt_outlined,
                  size: 18,
                  color: isActive ? kGeminiBlue : _c.textHint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEs ? 'IA Paga / Gemini Fallback' : 'IA Paga / Gemini Fallback',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive
                          ? (widget.isEs
                              ? 'gemini-2.5-flash • fallback activo'
                              : 'gemini-2.5-flash • fallback ativo')
                          : (widget.isEs
                              ? 'Fallback desactivado — solo Gemini gratuito'
                              : 'Fallback desativado — apenas Gemini gratuito'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isActive ? kGeminiBlue : _c.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge Online/Offline
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isActive
                      ? kGeminiBlue.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                ),
                child: Text(
                  isActive
                      ? (widget.isEs ? 'Activo' : 'Ativo')
                      : (widget.isEs ? 'Inactivo' : 'Inativo'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isActive ? kGeminiBlue : Colors.orange.shade600,
                  ),
                ),
              ),
            ]),
          ),

          // ── Toggle + info ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle de ativação
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _c.inputBg,
                    border: Border.all(color: _c.border),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isEs
                                ? 'Activar fallback pagado'
                                : 'Ativar fallback pago',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.isEs
                                ? 'Usa Gemini Paid cuando Free falla (503/timeout/truncado)'
                                : 'Usa Gemini Pago quando Free falha (503/timeout/truncado)',
                            style: TextStyle(
                              fontSize: 10,
                              color: _c.textHint,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _paidLoading
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Switch(
                            value: _paidEnabled,
                            activeColor: kGeminiBlue,
                            onChanged: _savePaidEnabled,
                          ),
                  ]),
                ),

                const SizedBox(height: 10),

                // Botão Testar
                GestureDetector(
                  onTap: (_paidTesting || !_paidEnabled) ? null : _testPaidProxy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: _paidTestDone
                          ? (_paidTestOnline
                              ? const Color(0xFF10A37F).withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.07))
                          : (_paidEnabled
                              ? kGeminiBlueBg.withValues(alpha: 0.08)
                              : _c.surface),
                      border: Border.all(
                        color: _paidTestDone
                            ? (_paidTestOnline
                                ? const Color(0xFF10A37F).withValues(alpha: 0.4)
                                : Colors.red.withValues(alpha: 0.3))
                            : (_paidEnabled
                                ? kGeminiBlue.withValues(alpha: 0.3)
                                : _c.border),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_paidTesting)
                          const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _paidTestDone
                                ? (_paidTestOnline ? Icons.check_circle_rounded : Icons.error_outline_rounded)
                                : Icons.wifi_tethering_rounded,
                            size: 14,
                            color: _paidTestDone
                                ? (_paidTestOnline ? const Color(0xFF10A37F) : Colors.red.shade400)
                                : (_paidEnabled ? kGeminiBlue : _c.textHint),
                          ),
                        const SizedBox(width: 6),
                        Text(
                          _paidTesting
                              ? (widget.isEs ? 'Probando...' : 'Testando...')
                              : _paidTestDone
                                  ? (_paidTestOnline
                                      ? (widget.isEs ? 'Online ✓' : 'Online ✓')
                                      : (widget.isEs ? 'Offline ✗' : 'Offline ✗'))
                                  : (widget.isEs ? 'Testar conexión' : 'Testar conexão'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _paidTestDone
                                ? (_paidTestOnline ? const Color(0xFF10A37F) : Colors.red.shade400)
                                : (_paidEnabled ? kGeminiBlue : _c.textHint),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_paidTestDone && _paidTestDetail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _paidTestDetail,
                    style: TextStyle(
                      fontSize: 10,
                      color: _paidTestOnline ? const Color(0xFF10A37F) : Colors.red.shade400,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Contadores de budget
                if (isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: _c.surface,
                      border: Border.all(color: _c.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEs ? 'USO HOY' : 'USO HOJE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: _c.textHint,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          _paidStatChip(
                            widget.isEs ? 'Llamadas hoy' : 'Chamadas hoje',
                            '$dailyCount / 4000',
                            Icons.auto_graph_rounded,
                          ),
                          const SizedBox(width: 8),
                          _paidStatChip(
                            widget.isEs ? 'Costo aprox.' : 'Custo aprox.',
                            'US\$ $estimatedCost',
                            Icons.attach_money_rounded,
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),

          // ── Info de segurança ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: kGeminiBlue.withValues(alpha: 0.05),
                border: Border.all(color: kGeminiBlue.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded, size: 12, color: kGeminiBlue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.isEs
                          ? 'La clave GEMINI_PAID_API_KEY se configura solo una vez en el servidor (firebase functions:secrets:set GEMINI_PAID_API_KEY). Nunca se envía al app ni aparece en el bundle web. Este panel solo activa/desactiva el fallback.'
                          : 'A chave GEMINI_PAID_API_KEY é configurada uma única vez no servidor (firebase functions:secrets:set GEMINI_PAID_API_KEY). Nunca é enviada ao app nem aparece no bundle web. Este painel apenas ativa/desativa o fallback.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: kGeminiBlue.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paidStatChip(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          color: _c.cardBg,
          border: Border.all(color: _c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: _c.textHint, fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Row(children: [
              Icon(icon, size: 11, color: _c.textSecondary),
              const SizedBox(width: 4),
              Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _c.textPrimary)),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lê o estado de manutenção em tempo real direto do Firestore
    return StreamBuilder<Map<String, dynamic>>(
      stream: FirestoreService.maintenanceStream(),
      builder: (context, snap) {
        final isEnabled = snap.data?['enabled'] == true;

        final lastUpdatedAt = snap.data?['updatedAt'] as String? ?? '';
        final storedMessage = snap.data?['message'] as String? ?? '';

        // Preenche o campo de mensagem com o valor salvo (apenas uma vez)
        if (widget.maintMsgCtrl.text.isEmpty && storedMessage.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.maintMsgCtrl.text = storedMessage;
          });
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Card de Manutenção ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _c.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isEnabled
                      ? Colors.orange.withValues(alpha: 0.4)
                      : kGreen.withValues(alpha: 0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header do card ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      color: isEnabled
                          ? Colors.orange.withValues(alpha: 0.07)
                          : kGreen.withValues(alpha: 0.06),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isEnabled
                              ? Colors.orange.withValues(alpha: 0.12)
                              : kGreen.withValues(alpha: 0.12),
                          border: Border.all(
                            color: isEnabled
                                ? Colors.orange.withValues(alpha: 0.35)
                                : kGreen.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          isEnabled
                              ? Icons.construction_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: isEnabled ? Colors.orange : kGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isEs
                                  ? 'Modo de Mantenimiento'
                                  : 'Modo de Manutenção',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: _c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEnabled
                                  ? (widget.isEs ? 'Sistema fuera de línea para usuarios' : 'Sistema offline para usuários')
                                  : (widget.isEs ? 'Sistema en línea — acceso normal' : 'Sistema online — acesso normal'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isEnabled ? Colors.orange : kGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── Toggle ────────────────────────────────────────────
                      widget.maintLoading
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.orange,
                              ),
                            )
                          : Switch(
                              value: isEnabled,
                              onChanged: widget.onToggle,
                              thumbColor: WidgetStateProperty.resolveWith((states) =>
                                states.contains(WidgetState.selected) ? Colors.orange : kGreen),
                              trackColor: WidgetStateProperty.resolveWith((states) =>
                                states.contains(WidgetState.selected)
                                  ? Colors.orange.withValues(alpha: 0.25)
                                  : kGreen.withValues(alpha: 0.2)),
                            ),
                    ]),
                  ),

                  // ── Campo de mensagem ─────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEs
                              ? 'Mensaje para usuarios (opcional)'
                              : 'Mensagem para usuários (opcional)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _c.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: widget.maintMsgCtrl,
                          maxLines: 3,
                          maxLength: 280,
                          autocorrect: false,
                          spellCheckConfiguration:
                              const SpellCheckConfiguration.disabled(),
                          style: TextStyle(
                            fontSize: 13,
                            color: _c.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.isEs
                                ? 'Ej: Estaremos disponibles a las 18h...'
                                : 'Ex: Voltamos às 18h com melhorias...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: _c.textHint,
                            ),
                            filled: true,
                            fillColor: _c.inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: _c.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: kGold,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                            counterStyle: TextStyle(
                              fontSize: 10,
                              color: _c.textHint,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Botão Salvar mensagem
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: widget.maintLoading
                                ? null
                                : () => widget.onToggle(isEnabled),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                color: kDark,
                                boxShadow: [
                                  BoxShadow(
                                    color: kDark.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(
                                  Icons.save_rounded,
                                  size: 14,
                                  color: kGoldL,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  widget.isEs ? 'Guardar mensaje' : 'Salvar mensagem',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: kGoldL,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),

                  // ── Info de última atualização ────────────────────────────
                  if (lastUpdatedAt.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: _c.surface,
                        ),
                        child: Row(children: [
                          Icon(
                            Icons.history_rounded,
                            size: 12,
                            color: _c.textHint,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${widget.isEs ? "Última actualización" : "Última atualização"}: $lastUpdatedAt',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _c.textHint,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Card OpenAI — chave global do app ─────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _c.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _aiKeyOriginal.isNotEmpty
                      ? const Color(0xFF10A37F).withValues(alpha: 0.35)
                      : _c.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      color: _aiKeyOriginal.isNotEmpty
                          ? const Color(0xFF10A37F).withValues(alpha: 0.07)
                          : _c.surface,
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: _aiKeyOriginal.isNotEmpty
                              ? const Color(0xFF10A37F).withValues(alpha: 0.12)
                              : _c.surface,
                          border: Border.all(
                            color: _aiKeyOriginal.isNotEmpty
                                ? const Color(0xFF10A37F).withValues(alpha: 0.35)
                                : _c.border,
                          ),
                        ),
                        child: Icon(
                          _aiKeyOriginal.isNotEmpty
                              ? Icons.psychology_rounded
                              : Icons.psychology_outlined,
                          size: 18,
                          color: _aiKeyOriginal.isNotEmpty
                              ? const Color(0xFF10A37F)
                              : _c.textHint,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ChatGPT / OpenAI',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: _c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _aiKeyOriginal.isNotEmpty
                                  ? 'GPT-4o mini • ativo para todos os usuários'
                                  : 'Sem chave — IA desativada para usuários',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _aiKeyOriginal.isNotEmpty
                                    ? const Color(0xFF10A37F)
                                    : _c.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Badge de status
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _aiKeyOriginal.isNotEmpty
                              ? const Color(0xFF10A37F).withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.10),
                        ),
                        child: Text(
                          _aiKeyOriginal.isNotEmpty ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _aiKeyOriginal.isNotEmpty
                                ? const Color(0xFF10A37F)
                                : Colors.red.shade400,
                          ),
                        ),
                      ),
                    ]),
                  ),

                  // Campo de chave
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chave de API OpenAI (compartilhada com todos)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _c.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _aiKeyCtrl,
                          obscureText: _aiKeyHidden,
                          autocorrect: false,
                          spellCheckConfiguration:
                              const SpellCheckConfiguration.disabled(),
                          style: TextStyle(
                            fontSize: 13,
                            color: _c.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'monospace',
                          ),
                          decoration: InputDecoration(
                            hintText: 'sk-proj-...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: _c.textHint,
                            ),
                            filled: true,
                            fillColor: _c.inputBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: _c.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF10A37F),
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _aiKeyHidden
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                size: 18,
                                color: _c.textHint,
                              ),
                              onPressed: () =>
                                  setState(() { _aiKeyHidden = !_aiKeyHidden; }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Botões Salvar + Remover
                        Row(children: [
                          // Remover (só aparece quando há chave)
                          if (_aiKeyOriginal.isNotEmpty) ...
                            [
                              GestureDetector(
                                onTap: _aiKeyLoading ? null : _removeAiKey,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(9),
                                    border: Border.all(
                                      color: Colors.red.withValues(alpha: 0.35),
                                    ),
                                    color: Colors.red.withValues(alpha: 0.07),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.delete_outline_rounded,
                                          size: 14,
                                          color: Colors.red.shade400),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Remover',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.red.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          const Spacer(),
                          // Salvar
                          GestureDetector(
                            onTap: _aiKeyLoading ? null : _saveAiKey,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(9),
                                color: _aiKeySaved
                                    ? const Color(0xFF10A37F)
                                    : kDark,
                                boxShadow: [
                                  BoxShadow(
                                    color: kDark.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: _aiKeyLoading
                                  ? const SizedBox(
                                      width: 14, height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _aiKeySaved
                                              ? Icons.check_rounded
                                              : Icons.save_rounded,
                                          size: 14,
                                          color: kGoldL,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _aiKeySaved
                                              ? 'Salvo!'
                                              : 'Salvar chave',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: kGoldL,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),

                  // Info sobre a chave
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _c.surface,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 12, color: _c.textHint),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'A chave fica em config/app_settings e é compartilhada com todos os usuários aprovados. Obtenha em platform.openai.com/api-keys.',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _c.textHint,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Build 226: Card IA Paga / Gemini Fallback ──────────────────
            _buildGeminiPaidCard(),

            const SizedBox(height: 16),

            // ── Aviso sobre bypass de admin ────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kGold.withValues(alpha: 0.07),
                border: Border.all(color: kGold.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: kGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isEs
                          ? 'Los administradores y el Master siempre tienen acceso, incluso durante el mantenimiento.'
                          : 'Administradores e Master sempre têm acesso, mesmo durante a manutenção.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _c.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Lista de usuários ──────────────────────────────────────────────────────
class _UserList extends StatelessWidget {
  final List<UserModel> users;
  final String emptyMsg;
  final IconData emptyIcon;
  final UserModel currentAdmin;
  final bool isMaster;
  final void Function(UserModel)? onApprove;
  final void Function(UserModel)? onBlock;
  final void Function(UserModel)? onPromote;
  final void Function(UserModel)? onPromoteSupervisor;
  final void Function(UserModel)? onDemote;
  final void Function(UserModel)? onDelete;
  final bool showApprove;
  final bool showBlock;
  final bool showPromote;
  final bool isPendingTab;
  final String approveBtnLabel;

  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);

  const _UserList({
    required this.users,
    required this.emptyMsg,
    required this.emptyIcon,
    required this.currentAdmin,
    required this.isMaster,
    this.onApprove,
    this.onBlock,
    this.onPromote,
    this.onPromoteSupervisor,
    this.onDemote,
    this.onDelete,
    this.showApprove = false,
    this.showBlock = false,
    this.showPromote = false,
    this.isPendingTab = false,
    this.approveBtnLabel = 'Aprovar',
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (users.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(emptyIcon, size: 48, color: kGreen.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(emptyMsg, style: TextStyle(color: c.textHint, fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (ctx, i) {
        final u = users[i];
        final isMe = u.uid == currentAdmin.uid;
        // Não pode promover a si mesmo ou ao master
        final canPromote = showPromote && onPromote != null
            && !isMe && !u.isMaster
            && u.role != UserRole.admin; // já é admin, não precisa promover novamente
        final canPromoteSupervisor = isMaster && onPromoteSupervisor != null
            && !isMe && !u.isMaster
            && u.role == UserRole.user;
        final canDemote = isMaster && onDemote != null
            && !isMe && !u.isMaster
            && (u.role == UserRole.admin || u.role == UserRole.supervisor);

        // Botão excluir: disponível para todos exceto o próprio admin e master
        final canDelete = onDelete != null && !isMe && !u.isMaster;

        return _UserCard(
          user: u,
          currentAdmin: currentAdmin,
          isMaster: isMaster,
          onApprove: showApprove && onApprove != null ? () => onApprove!(u) : null,
          onBlock: showBlock && onBlock != null && !isMe && !u.isMaster ? () => onBlock!(u) : null,
          onPromote: canPromote ? () => onPromote!(u) : null,
          onPromoteSupervisor: canPromoteSupervisor ? () => onPromoteSupervisor!(u) : null,
          onDemote: canDemote ? () => onDemote!(u) : null,
          onDelete: canDelete ? () => onDelete!(u) : null,
          isPendingTab: isPendingTab,
          approveBtnLabel: approveBtnLabel,
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final UserModel currentAdmin;
  final bool isMaster;
  final VoidCallback? onApprove;
  final VoidCallback? onBlock;
  final VoidCallback? onPromote;
  final VoidCallback? onPromoteSupervisor;
  final VoidCallback? onDemote;
  final VoidCallback? onDelete;
  final bool isPendingTab;
  final String approveBtnLabel;

  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);

  const _UserCard({
    required this.user,
    required this.currentAdmin,
    required this.isMaster,
    this.onApprove,
    this.onBlock,
    this.onPromote,
    this.onPromoteSupervisor,
    this.onDemote,
    this.onDelete,
    this.isPendingTab = false,
    required this.approveBtnLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = user.uid == currentAdmin.uid;

    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? kGold.withValues(alpha: 0.5) : c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header do card
          Row(children: [
            // Avatar
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF07110d), Color(0xFF075f45)],
                ),
              ),
              child: Center(
                child: Text(
                  user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(color: kGoldL, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(user.displayName,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: c.textPrimary),
                      overflow: TextOverflow.ellipsis),
                  ),
                  if (isMe)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: kGold.withValues(alpha: 0.15), border: Border.all(color: kGold.withValues(alpha: 0.4))),
                      child: const Text('Você / You', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGold)),
                    ),
                  const SizedBox(width: 4),
                  _StatusBadge(user.status),
                  const SizedBox(width: 4),
                  _RoleBadge(user),
                ]),
                Text(user.email, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),

          // Info adicional
          if (user.profession != null || user.institution != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (user.profession != null)
                _InfoChip(Icons.work_outline_rounded, user.profession!),
              if (user.institution != null)
                _InfoChip(Icons.local_hospital_outlined, user.institution!),
            ]),
          ],

          // Data de cadastro / horário da solicitação
          const SizedBox(height: 6),
          Text(
            'Solicitado: ${_formatDateTime(user.createdAt)}${user.approvedAt != null ? '  •  Aprov: ${_formatDate(user.approvedAt!)}' : ''}',
            style: TextStyle(fontSize: 10, color: c.textHint, fontWeight: FontWeight.w500),
          ),

          // Botões de ação
          if (onApprove != null || onBlock != null || onPromote != null || onPromoteSupervisor != null || onDemote != null || onDelete != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onApprove != null)
                  _ActionBtn(label: approveBtnLabel, icon: Icons.check_circle_outline_rounded, color: kGreen, onTap: onApprove!),
                if (onPromote != null)
                  _ActionBtn(label: isMaster ? 'Admin' : 'Supervisor', icon: Icons.star_outline_rounded, color: kGold, onTap: onPromote!),
                if (onPromoteSupervisor != null && onPromote == null)
                  _ActionBtn(label: 'Supervisor', icon: Icons.shield_outlined, color: Colors.blue, onTap: onPromoteSupervisor!),
                if (onDemote != null)
                  _ActionBtn(label: 'Rebaixar', icon: Icons.arrow_downward_rounded, color: Colors.orange, onTap: onDemote!),
                // Tab Pendentes: "Recusar" deleta o documento; demais tabs: "Bloquear"
                if (isPendingTab && onDelete != null)
                  _ActionBtn(label: 'Recusar', icon: Icons.person_remove_outlined, color: Colors.red, onTap: onDelete!)
                else if (!isPendingTab && onBlock != null)
                  _ActionBtn(label: '✕', icon: Icons.block_rounded, color: Colors.red.shade700, onTap: onBlock!),
                // Botão Excluir (lixeira) — visível em todas as tabs exceto Pendentes
                // (no Pendentes o "Recusar" já faz a deleção)
                if (!isPendingTab && onDelete != null)
                  _ActionBtn(label: 'Excluir', icon: Icons.delete_outline_rounded, color: Colors.red, onTap: onDelete!),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  static String _formatDateTime(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

class _StatusBadge extends StatelessWidget {
  final UserStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg; String label;
    switch (status) {
      case UserStatus.approved:
        bg = Colors.green.withValues(alpha: 0.1); fg = Colors.green; label = 'Aprobado/Aprovado'; break;
      case UserStatus.pending:
        bg = Colors.orange.withValues(alpha: 0.12); fg = Colors.orange; label = 'Pendente'; break;
      case UserStatus.blocked:
        bg = Colors.red.withValues(alpha: 0.1); fg = Colors.red; label = 'Bloqueado'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: bg, border: Border.all(color: fg.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: fg)),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserModel user;
  static const kGold  = Color(0xFFC5A365);
  const _RoleBadge(this.user);

  @override
  Widget build(BuildContext context) {
    if (user.role == UserRole.user) return const SizedBox.shrink();

    Color bg; Color fg; Color border; String label; IconData icon;
    if (user.isMaster) {
      bg = Colors.amber.withValues(alpha: 0.15);
      fg = Colors.amber.shade700;
      border = Colors.amber.withValues(alpha: 0.5);
      label = 'Master';
      icon = Icons.workspace_premium_rounded;
    } else if (user.role == UserRole.admin) {
      bg = kGold.withValues(alpha: 0.12);
      fg = kGold;
      border = kGold.withValues(alpha: 0.4);
      label = 'Admin';
      icon = Icons.star_rounded;
    } else {
      // supervisor
      bg = Colors.blue.withValues(alpha: 0.1);
      fg = Colors.blue;
      border = Colors.blue.withValues(alpha: 0.3);
      label = 'Supervisor';
      icon = Icons.shield_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: bg,
        border: Border.all(color: border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 9, color: fg),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: fg)),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  static const kDark = Color(0xFF07110d);
  const _InfoChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: c.surface,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.textSecondary)),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB NOVIDADES — publicar atualizações do app
// ═══════════════════════════════════════════════════════════════════════════
class _AppUpdatesTab extends StatefulWidget {
  final UserModel currentAdmin;
  const _AppUpdatesTab({required this.currentAdmin});
  @override
  State<_AppUpdatesTab> createState() => _AppUpdatesTabState();
}

class _AppUpdatesTabState extends State<_AppUpdatesTab> {
  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);

  AppColors get _c => AppColors.of(context);

  final _versionCtrl = TextEditingController();
  final _titleCtrl   = TextEditingController();
  final _dateCtrl    = TextEditingController();
  final List<TextEditingController> _itemCtrls = [TextEditingController()];

  bool _active   = true;
  bool _loading  = false;
  bool _saving   = false;
  String? _savedMsg;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  @override
  void dispose() {
    _versionCtrl.dispose();
    _titleCtrl.dispose();
    _dateCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    setState(() => _loading = true);
    try {
      final data = await FirestoreService.loadAppUpdate();
      if (data.isNotEmpty) {
        _versionCtrl.text = data['version'] as String? ?? '';
        _titleCtrl.text   = data['title']   as String? ?? '';
        _dateCtrl.text    = data['date']     as String? ?? '';
        _active           = data['active']   as bool?   ?? true;
        final items = (data['items'] as List<dynamic>? ?? []).cast<String>();
        for (final c in _itemCtrls) c.dispose();
        _itemCtrls.clear();
        for (final item in items) {
          _itemCtrls.add(TextEditingController(text: item));
        }
        if (_itemCtrls.isEmpty) _itemCtrls.add(TextEditingController());
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final version = _versionCtrl.text.trim();
    final title   = _titleCtrl.text.trim();
    final date    = _dateCtrl.text.trim();
    final items   = _itemCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (version.isEmpty || title.isEmpty || items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha versão, título e ao menos uma novidade.')),
      );
      return;
    }

    setState(() { _saving = true; _savedMsg = null; });
    try {
      await FirestoreService.saveAppUpdate(
        version: version,
        title: title,
        date: date.isNotEmpty ? date : _today(),
        items: items,
        active: _active,
      );
      if (mounted) setState(() { _savedMsg = 'Publicado com sucesso!'; _saving = false; });
    } catch (e) {
      if (mounted) setState(() { _savedMsg = 'Erro ao salvar: $e'; _saving = false; });
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year}';
  }

  void _addItem() => setState(() => _itemCtrls.add(TextEditingController()));

  void _removeItem(int i) {
    if (_itemCtrls.length <= 1) return;
    setState(() {
      _itemCtrls[i].dispose();
      _itemCtrls.removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kGreen));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [kDark, Color(0xFF123326)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: kGoldL, size: 18),
              const SizedBox(width: 8),
              const Text('Publicar Novidades', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
            const SizedBox(height: 4),
            Text('Os usuários verão o modal ao abrir o app',
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55))),
          ]),
        ),
        const SizedBox(height: 16),

        // Ativo/inativo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: _c.cardBg,
            border: Border.all(color: _c.border),
          ),
          child: Row(children: [
            const Icon(Icons.visibility_rounded, size: 16, color: kGreen),
            const SizedBox(width: 8),
            Expanded(child: Text('Notificação ativa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _c.textPrimary))),
            Switch.adaptive(
              value: _active,
              activeColor: kGreen,
              onChanged: (v) => setState(() => _active = v),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // Versão + Data
        Row(children: [
          Expanded(child: _field(_versionCtrl, 'Versão', '1.2.0', Icons.tag_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _field(_dateCtrl, 'Data', _today(), Icons.calendar_today_rounded)),
        ]),
        const SizedBox(height: 10),

        // Título
        _field(_titleCtrl, 'Título do aviso', 'Novidades da versão 1.2.0', Icons.title_rounded),
        const SizedBox(height: 16),

        // Lista de novidades
        Row(children: [
          Text('Novidades', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _c.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: _addItem,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: kGreen.withValues(alpha: 0.08),
                border: Border.all(color: kGreen.withValues(alpha: 0.25)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, size: 14, color: kGreen),
                SizedBox(width: 4),
                Text('Adicionar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kGreen)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),

        ...List.generate(_itemCtrls.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(
              margin: const EdgeInsets.only(right: 8, top: 14),
              width: 6, height: 6,
              decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle),
            ),
            Expanded(
              child: TextField(
                controller: _itemCtrls[i],
                maxLines: 2, minLines: 1,
                style: TextStyle(fontSize: 13, color: _c.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ex: Login corrigido — maior estabilidade',
                  hintStyle: TextStyle(fontSize: 12, color: _c.textHint),
                  filled: true, fillColor: _c.inputBg,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _c.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: _c.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kGold, width: 1.5)),
                ),
              ),
            ),
            if (_itemCtrls.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 18),
                onPressed: () => _removeItem(i),
              ),
          ]),
        )),

        const SizedBox(height: 16),

        // Mensagem de feedback
        if (_savedMsg != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _savedMsg!.startsWith('Erro')
                  ? const Color(0xFFFFEDED)
                  : const Color(0xFFE8F5EE),
              border: Border.all(color: _savedMsg!.startsWith('Erro')
                  ? Colors.red.withValues(alpha: 0.3)
                  : kGreen.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(
                _savedMsg!.startsWith('Erro') ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                size: 16,
                color: _savedMsg!.startsWith('Erro') ? Colors.red : kGreen,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(_savedMsg!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _savedMsg!.startsWith('Erro') ? Colors.red : kGreen))),
            ]),
          ),

        // Botão publicar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.rocket_launch_rounded, size: 16),
            label: Text(_saving ? 'Publicando...' : 'Publicar para todos os usuários',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kDark, foregroundColor: kGoldL,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, String hint, IconData icon) {
    final c = _c;
    return TextField(
      controller: ctrl,
      style: TextStyle(fontSize: 13, color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: c.textSecondary),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: c.textHint),
        prefixIcon: Icon(icon, size: 16, color: kGold),
        filled: true, fillColor: c.inputBg,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGold, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB DE ESTATÍSTICAS
// ══════════════════════════════════════════════════════════════════════════════
class _StatsTab extends StatelessWidget {
  final List<UserModel> allUsers;
  final bool loading;

  const _StatsTab({required this.allUsers, required this.loading});

  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);

  // ── Helpers ────────────────────────────────────────────────────────────────
  int get _totalUsers    => allUsers.length;
  int get _approved      => allUsers.where((u) => u.isApproved).length;
  int get _pending       => allUsers.where((u) => u.isPending).length;

  int get _totalSeconds  =>
      allUsers.fold(0, (sum, u) => sum + u.totalUsageSeconds);

  int get _totalLogins   =>
      allUsers.fold(0, (sum, u) => sum + u.loginCount);

  String _fmt(int s) {
    if (s <= 0) return '—';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}min';
    if (m > 0) return '${m}min';
    return '<1min';
  }

  String _lastSeenLabel(DateTime? dt) {
    if (dt == null) return 'Nunca acessou';
    return 'Último acesso: ${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Ordena por tempo de uso desc
    final sorted = [...allUsers]
      ..sort((a, b) => b.totalUsageSeconds.compareTo(a.totalUsageSeconds));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: [

        // ── Cards de resumo ─────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _SummaryCard(
            icon: Icons.people_rounded,
            color: kGreen,
            value: '$_totalUsers',
            label: 'Total de usuários',
          )),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(
            icon: Icons.check_circle_rounded,
            color: Colors.green,
            value: '$_approved',
            label: 'Aprovados',
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _SummaryCard(
            icon: Icons.timer_rounded,
            color: const Color(0xFF7C3AED),
            value: _fmt(_totalSeconds),
            label: 'Tempo total de uso',
          )),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(
            icon: Icons.pending_actions_rounded,
            color: Colors.orange,
            value: '$_pending',
            label: 'Pendentes',
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _SummaryCard(
            icon: Icons.login_rounded,
            color: const Color(0xFF7C3AED),
            value: '$_totalLogins',
            label: 'Acessos registados',
          )),
          const SizedBox(width: 10),
          Expanded(child: _SummaryCard(
            icon: Icons.person_search_rounded,
            color: kGreen,
            value: allUsers.where((u) => u.loginCount > 0).length.toString(),
            label: 'Usuários ativos',
          )),
        ]),

        const SizedBox(height: 24),

        // ── Cabeçalho da lista ───────────────────────────────────────────────
        Builder(builder: (context) {
          final c = AppColors.of(context);
          return Row(children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: kGold.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.bar_chart_rounded, size: 16, color: kGold),
            ),
            const SizedBox(width: 10),
            Text('Tempo por usuário',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: c.textPrimary)),
            const Spacer(),
            Text('${allUsers.length} usuários',
              style: TextStyle(
                fontSize: 11, color: c.textHint,
                fontWeight: FontWeight.w600)),
          ]);
        }),
        const SizedBox(height: 12),

        // ── Carregando ───────────────────────────────────────────────────────
        if (loading && allUsers.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: kGreen),
            ),
          )
        else if (allUsers.isEmpty)
          Builder(builder: (context) => Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text('Nenhum usuário ainda.',
                style: TextStyle(color: AppColors.of(context).textHint)),
            ),
          ))
        else
          // ── Lista de usuários com tempo ─────────────────────────────────
          ...sorted.map((u) => _UserUsageRow(
            user: u,
            maxSeconds: sorted.first.totalUsageSeconds,
            lastSeenLabel: _lastSeenLabel(u.lastSeenAt),
          )),
      ],
    );
  }
}

// ── Card de resumo ────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  const _SummaryCard({
    required this.icon, required this.color,
    required this.value, required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.1),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 10),
        Text(value,
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: color,
            letterSpacing: -0.5)),
        const SizedBox(height: 2),
        Text(label,
          style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280))),
      ]),
    );
  }
}

// ── Linha de uso por usuário ──────────────────────────────────────────────────
class _UserUsageRow extends StatelessWidget {
  final UserModel user;
  final int maxSeconds;
  final String lastSeenLabel;
  const _UserUsageRow({
    required this.user,
    required this.maxSeconds,
    required this.lastSeenLabel,
  });

  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);

  Color get _barColor {
    if (user.totalUsageSeconds == 0) return const Color(0xFFE5E7EB);
    if (user.totalUsageSeconds >= 3600) return kGreen;
    if (user.totalUsageSeconds >= 600)  return kGold;
    return const Color(0xFF93C5FD);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final pct = maxSeconds > 0
        ? (user.totalUsageSeconds / maxSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Linha superior: nome + tempo ──────────────────────────────────
        Row(children: [
          // Avatar inicial
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kGreen.withValues(alpha: 0.1),
            ),
            child: Center(
              child: Text(
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w900,
                  color: kGreen),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.displayName,
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: kDark),
                overflow: TextOverflow.ellipsis),
              Text(user.email,
                style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF)),
                overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          // Tempo total
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(user.usageFormatted,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900,
                color: user.totalUsageSeconds > 0 ? kGreen : const Color(0xFFD1D5DB))),
            Text(lastSeenLabel,
              style: const TextStyle(
                fontSize: 10, color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500)),
          ]),
        ]),

        const SizedBox(height: 10),

        // ── Barra de progresso ────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 5,
            backgroundColor: const Color(0xFFF3F4F6),
            valueColor: AlwaysStoppedAnimation(_barColor),
          ),
        ),

        const SizedBox(height: 8),

        // ── Linha inferior: status + role ─────────────────────────────────
        Row(children: [
          _MiniChip(
            label: user.statusLabel,
            color: user.isApproved
                ? Colors.green
                : user.isPending
                    ? Colors.orange
                    : Colors.red,
          ),
          const SizedBox(width: 6),
          _MiniChip(
            label: user.roleLabel,
            color: user.isMaster
                ? Colors.amber
                : user.isAdmin
                    ? kGold
                    : const Color(0xFF9CA3AF),
          ),
          if (user.loginCount > 0) ...[  
            const SizedBox(width: 6),
            _MiniChip(
              label: '${user.loginCount}× acessos',
              color: const Color(0xFF7C3AED),
            ),
          ],
          const Spacer(),
          Text(
            'Entrou: ${user.createdAt.day.toString().padLeft(2,'0')}/'
            '${user.createdAt.month.toString().padLeft(2,'0')}/'
            '${user.createdAt.year}',
            style: TextStyle(
              fontSize: 9, color: c.textHint,
              fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

// ── Mini chip de status/role ──────────────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB E-MAIL — enviar notificação por e-mail para todos os usuários registrados
// ══════════════════════════════════════════════════════════════════════════════
class _EmailTab extends StatefulWidget {
  final List<UserModel> allUsers;
  final UserModel currentAdmin;
  const _EmailTab({required this.allUsers, required this.currentAdmin});

  @override
  State<_EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<_EmailTab> {
  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);
  static const kBlue  = Color(0xFF1A56DB);

  AppColors get _c => AppColors.of(context);

  // ── Campos do formulário ──────────────────────────────────────────────────
  final _subjectCtrl = TextEditingController();
  final _bodyCtrl    = TextEditingController();

  // ── Config EmailJS ────────────────────────────────────────────────────────
  final _serviceCtrl  = TextEditingController();
  final _templateCtrl = TextEditingController();
  final _pubKeyCtrl   = TextEditingController();
  bool _configHidden  = true;
  bool _configSaving  = false;
  bool _configSaved   = false;
  bool _configLoaded  = false;

  // ── Estado de envio ───────────────────────────────────────────────────────
  String _recipients    = 'approved'; // 'approved' | 'all'
  bool   _sending       = false;
  int    _sentCount     = 0;
  int    _totalCount    = 0;
  String?_sendResult;
  bool   _sendSuccess   = false;

  // ── Histórico ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];
  bool _historyLoading = false;
  bool _showHistory    = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadHistory();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    _serviceCtrl.dispose();
    _templateCtrl.dispose();
    _pubKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final cfg = await FirestoreService.loadEmailJsConfig();
    if (!mounted) return;
    setState(() {
      _serviceCtrl.text  = cfg['serviceId']  ?? '';
      _templateCtrl.text = cfg['templateId'] ?? '';
      _pubKeyCtrl.text   = cfg['publicKey']  ?? '';
      _configLoaded      = true;
    });
  }

  Future<void> _saveConfig() async {
    final sid = _serviceCtrl.text.trim();
    final tid = _templateCtrl.text.trim();
    final pk  = _pubKeyCtrl.text.trim();
    if (sid.isEmpty || tid.isEmpty || pk.isEmpty) {
      _snack('Preencha todos os campos da configuração.', Colors.red);
      return;
    }
    setState(() { _configSaving = true; _configSaved = false; });
    try {
      await FirestoreService.saveEmailJsConfig(
        serviceId: sid, templateId: tid, publicKey: pk,
      );
      if (mounted) setState(() { _configSaving = false; _configSaved = true; });
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) setState(() => _configSaved = false);
    } catch (e) {
      if (mounted) {
        setState(() => _configSaving = false);
        _snack('Erro ao salvar: $e', Colors.red);
      }
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _historyLoading = true);
    _history = await FirestoreService.loadEmailCampaigns();
    if (mounted) setState(() => _historyLoading = false);
  }

  List<UserModel> get _targetUsers {
    if (_recipients == 'approved') {
      return widget.allUsers.where((u) => u.isApproved).toList();
    }
    return widget.allUsers;
  }

  Future<void> _send() async {
    final subject = _subjectCtrl.text.trim();
    final body    = _bodyCtrl.text.trim();
    final sid     = _serviceCtrl.text.trim();
    final tid     = _templateCtrl.text.trim();
    final pk      = _pubKeyCtrl.text.trim();

    if (subject.isEmpty || body.isEmpty) {
      _snack('Preencha o assunto e o corpo do e-mail.', Colors.orange);
      return;
    }
    if (sid.isEmpty || tid.isEmpty || pk.isEmpty) {
      _snack('Configure o EmailJS antes de enviar.', Colors.red);
      setState(() => _configHidden = false);
      return;
    }

    final targets = _targetUsers;
    if (targets.isEmpty) {
      _snack('Nenhum usuário encontrado para envio.', Colors.orange);
      return;
    }

    // Confirmação
    final confirm = await _confirmSend(targets.length);
    if (!confirm) return;

    setState(() {
      _sending    = true;
      _sentCount  = 0;
      _totalCount = targets.length;
      _sendResult = null;
    });

    int successCount = 0;
    final List<String> errors = [];

    for (final user in targets) {
      try {
        await FirestoreService.sendEmailViaEmailJs(
          serviceId:   sid,
          templateId:  tid,
          publicKey:   pk,
          toEmail:     user.email,
          toName:      user.displayName.isNotEmpty ? user.displayName : user.email,
          subject:     subject,
          message:     body,
          fromName:    'MedCases Pro',
        );
        successCount++;
      } catch (e) {
        errors.add('${user.email}: $e');
      }
      if (mounted) setState(() => _sentCount = successCount + errors.length);
      // Pequeno delay para não sobrecarregar a API
      await Future.delayed(const Duration(milliseconds: 300));
    }

    // Salva no histórico
    final hasErrors = errors.isNotEmpty;
    await FirestoreService.saveEmailCampaign(
      subject:        subject,
      body:           body,
      sentBy:         widget.currentAdmin.email,
      recipients:     _recipients,
      recipientCount: successCount,
      status:         hasErrors && successCount == 0 ? 'error' : 'sent',
      errorMsg:       errors.take(3).join(' | '),
    );

    if (mounted) {
      setState(() {
        _sending     = false;
        _sendSuccess = successCount > 0;
        _sendResult  = successCount > 0
            ? '✓ $successCount e-mail${successCount > 1 ? 's' : ''} enviado${successCount > 1 ? 's' : ''} com sucesso!'
            : 'Falha ao enviar. Verifique a configuração do EmailJS.';
        if (hasErrors && successCount > 0) {
          _sendResult = '✓ $successCount enviados, ${errors.length} com erro.';
        }
      });
      _loadHistory();
    }
  }

  Future<bool> _confirmSend(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFFFFFDF8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kBlue.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.send_rounded, size: 18, color: kBlue),
              ),
              const SizedBox(width: 10),
              const Text('Confirmar envio',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: kDark)),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Você está prestes a enviar um e-mail para',
                style: TextStyle(fontSize: 13, color: kDark.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kBlue.withValues(alpha: 0.06),
                  border: Border.all(color: kBlue.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.people_rounded, size: 18, color: kBlue),
                  const SizedBox(width: 8),
                  Text('$count destinatário${count > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: kBlue)),
                ]),
              ),
              const SizedBox(height: 8),
              Text(
                'Assunto: "${_subjectCtrl.text.trim()}"',
                style: TextStyle(fontSize: 12, color: kDark.withValues(alpha: 0.6)),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Esta ação não pode ser desfeita.',
                style: TextStyle(fontSize: 11, color: Colors.red.shade400),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.send_rounded, size: 14),
                label: const Text('Enviar agora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kBlue, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final targets = _targetUsers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ────────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF0F1E4A), Color(0xFF1A3A8F), kBlue],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('E-mail para Usuários',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              Text(
                '${widget.allUsers.length} registrados  ·  ${widget.allUsers.where((u) => u.isApproved).length} aprovados',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65)),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Seletor de destinatários ──────────────────────────────────────
        _sectionLabel('DESTINATÁRIOS', Icons.people_rounded),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _RecipientChip(
            label: 'Aprovados',
            subtitle: '${widget.allUsers.where((u) => u.isApproved).length} usuários',
            icon: Icons.verified_user_rounded,
            color: kGreen,
            selected: _recipients == 'approved',
            onTap: () => setState(() => _recipients = 'approved'),
          )),
          const SizedBox(width: 10),
          Expanded(child: _RecipientChip(
            label: 'Todos',
            subtitle: '${widget.allUsers.length} usuários',
            icon: Icons.group_rounded,
            color: kBlue,
            selected: _recipients == 'all',
            onTap: () => setState(() => _recipients = 'all'),
          )),
        ]),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            '${targets.length} e-mail${targets.length != 1 ? 's' : ''} serão enviados',
            style: TextStyle(fontSize: 11, color: _c.textHint, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),

        // ── Formulário ─────────────────────────────────────────────────────
        _sectionLabel('MENSAGEM', Icons.edit_rounded),
        const SizedBox(height: 8),
        _buildField(
          controller: _subjectCtrl,
          label: 'Assunto',
          hint: 'Ex: Novidades do MedCases Pro 🎉',
          icon: Icons.subject_rounded,
          maxLines: 1,
        ),
        const SizedBox(height: 10),
        _buildField(
          controller: _bodyCtrl,
          label: 'Corpo do e-mail',
          hint: 'Escreva a mensagem que os usuários receberão...\n\nEx: Olá {{to_name}},\nTemos novidades para você no MedCases Pro!\n\nAtenciosamente,\nEquipe MedCases',
          icon: Icons.article_rounded,
          maxLines: 8,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            'Use {{to_name}} para inserir o nome do usuário automaticamente.',
            style: TextStyle(fontSize: 10, color: _c.textHint),
          ),
        ),
        const SizedBox(height: 16),

        // ── Barra de progresso durante envio ──────────────────────────────
        if (_sending) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: kBlue.withValues(alpha: 0.06),
              border: Border.all(color: kBlue.withValues(alpha: 0.2)),
            ),
            child: Column(children: [
              Row(children: [
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kBlue),
                ),
                const SizedBox(width: 10),
                Text(
                  'Enviando $_sentCount de $_totalCount...',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kBlue),
                ),
              ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _totalCount > 0 ? _sentCount / _totalCount : 0,
                  minHeight: 6,
                  backgroundColor: kBlue.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation(kBlue),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Resultado do envio ─────────────────────────────────────────────
        if (_sendResult != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _sendSuccess
                  ? kGreen.withValues(alpha: 0.07)
                  : Colors.red.withValues(alpha: 0.07),
              border: Border.all(
                color: _sendSuccess
                    ? kGreen.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
              ),
            ),
            child: Row(children: [
              Icon(
                _sendSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 18,
                color: _sendSuccess ? kGreen : Colors.red,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_sendResult!,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: _sendSuccess ? kGreen : Colors.red,
                ))),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // ── Botão enviar ───────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 16),
            label: Text(
              _sending
                  ? 'Enviando... $_sentCount/$_totalCount'
                  : 'Enviar para ${targets.length} usuário${targets.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Configuração EmailJS (colapsável) ─────────────────────────────
        GestureDetector(
          onTap: () => setState(() => _configHidden = !_configHidden),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _c.cardBg,
              border: Border.all(
                color: (_serviceCtrl.text.isNotEmpty && _templateCtrl.text.isNotEmpty)
                    ? kGreen.withValues(alpha: 0.3)
                    : _c.border,
              ),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: (_serviceCtrl.text.isNotEmpty)
                      ? kGreen.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.settings_rounded, size: 16,
                  color: (_serviceCtrl.text.isNotEmpty) ? kGreen : Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Configuração EmailJS',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _c.textPrimary)),
                Text(
                  (_serviceCtrl.text.isNotEmpty && _templateCtrl.text.isNotEmpty)
                      ? '✓ Configurado — pronto para envio'
                      : '⚠ Configure para enviar e-mails',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: (_serviceCtrl.text.isNotEmpty) ? kGreen : Colors.orange,
                  ),
                ),
              ])),
              Icon(
                _configHidden ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                size: 18, color: _c.textHint,
              ),
            ]),
          ),
        ),

        if (!_configHidden) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _c.cardBg,
              border: Border.all(color: _c.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Instruções
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: kBlue.withValues(alpha: 0.05),
                  border: Border.all(color: kBlue.withValues(alpha: 0.15)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: kBlue),
                    SizedBox(width: 6),
                    Text('Como configurar o EmailJS',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kBlue)),
                  ]),
                  const SizedBox(height: 6),
                  _instrLine('1.', 'Crie conta gratuita em emailjs.com'),
                  _instrLine('2.', 'Conecte seu Gmail/Outlook em "Email Services"'),
                  _instrLine('3.', 'Crie um template com variáveis: {{to_name}}, {{subject}}, {{message}}, {{from_name}}'),
                  _instrLine('4.', 'Copie Service ID, Template ID e Public Key abaixo'),
                ]),
              ),
              const SizedBox(height: 12),
              _buildField(controller: _serviceCtrl,  label: 'Service ID',  hint: 'service_xxxxxxx',  icon: Icons.dns_rounded,    maxLines: 1),
              const SizedBox(height: 8),
              _buildField(controller: _templateCtrl, label: 'Template ID', hint: 'template_xxxxxxx', icon: Icons.description_rounded, maxLines: 1),
              const SizedBox(height: 8),
              _buildField(controller: _pubKeyCtrl,   label: 'Public Key',  hint: 'xxxxxxxxxxxx',     icon: Icons.vpn_key_rounded,    maxLines: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _configSaving ? null : _saveConfig,
                  icon: _configSaving
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(_configSaved ? Icons.check_rounded : Icons.save_rounded, size: 14),
                  label: Text(
                    _configSaving ? 'Salvando...' : _configSaved ? 'Salvo!' : 'Salvar configuração',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _configSaved ? kGreen : kDark,
                    foregroundColor: kGoldL,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
          ),
        ],

        const SizedBox(height: 24),

        // ── Histórico de campanhas ─────────────────────────────────────────
        GestureDetector(
          onTap: () {
            setState(() => _showHistory = !_showHistory);
            if (_showHistory) _loadHistory();
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _c.cardBg,
              border: Border.all(color: _c.border),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: kGold.withValues(alpha: 0.1),
                ),
                child: const Icon(Icons.history_rounded, size: 16, color: kGold),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('Histórico de envios',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _c.textPrimary))),
              if (_history.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: kGold.withValues(alpha: 0.12),
                  ),
                  child: Text('${_history.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kGold)),
                ),
              const SizedBox(width: 6),
              Icon(
                _showHistory ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18, color: _c.textHint,
              ),
            ]),
          ),
        ),

        if (_showHistory) ...[
          const SizedBox(height: 10),
          if (_historyLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: kGreen),
            ))
          else if (_history.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _c.cardBg,
                border: Border.all(color: _c.border),
              ),
              child: Center(child: Text('Nenhum e-mail enviado ainda.',
                style: TextStyle(color: _c.textHint, fontSize: 13))),
            )
          else
            ...(_history.map((h) => _HistoryCard(data: h))),
        ],

        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 13, color: _c.textHint),
      const SizedBox(width: 6),
      Text(text,
        style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w900,
          letterSpacing: 1.2, color: _c.textHint,
        )),
    ]);
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required int maxLines,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: 1,
      autocorrect: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      style: TextStyle(fontSize: 13, color: _c.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _c.textSecondary, fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12, color: _c.textHint),
        prefixIcon: Icon(icon, size: 16, color: kGold),
        prefixIconConstraints: const BoxConstraints(minWidth: 40),
        filled: true, fillColor: _c.inputBg,
        isDense: true,
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBlue, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _instrLine(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(num, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kBlue)),
        const SizedBox(width: 6),
        Expanded(child: Text(text,
          style: TextStyle(fontSize: 11, color: _c.textSecondary))),
      ]),
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
    ));
  }
}

// ── Card de recipiente (aprovados / todos) ────────────────────────────────────
class _RecipientChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _RecipientChip({
    required this.label, required this.subtitle, required this.icon,
    required this.color, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? color.withValues(alpha: 0.08) : c.cardBg,
          border: Border.all(
            color: selected ? color : c.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: color.withValues(alpha: selected ? 0.15 : 0.08),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800,
                color: selected ? color : c.textPrimary,
              )),
            Text(subtitle,
              style: TextStyle(fontSize: 10, color: c.textHint)),
          ])),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 16, color: color),
        ]),
      ),
    );
  }
}

// ── Card de histórico de campanha ─────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);

  const _HistoryCard({required this.data});

  String _formatTs(dynamic ts) {
    if (ts == null) return '—';
    if (ts is DateTime) {
      final d = ts.toLocal();
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} '
             '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    }
    // Firestore Timestamp — converte via runtimeType para evitar import direto
    try {
      final d = (ts as dynamic).toDate() as DateTime;
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} '
             '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) {}
    if (false) {
      return '';
    }
    return ts.toString();
  }

  @override
  Widget build(BuildContext context) {
    final c       = AppColors.of(context);
    final ok      = (data['status'] as String?) == 'sent';
    final count   = (data['recipientCount'] as int?) ?? 0;
    final subject = (data['subject'] as String?) ?? '';
    final sentBy  = (data['sentBy'] as String?) ?? '';
    final recip   = (data['recipients'] as String?) ?? '';
    final ts      = data['sentAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: c.cardBg,
        border: Border.all(
          color: ok
              ? kGreen.withValues(alpha: 0.2)
              : Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 14,
            color: ok ? kGreen : Colors.red,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(subject,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: c.textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: ok
                  ? kGreen.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
            ),
            child: Text(
              ok ? '$count enviados' : 'Falha',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800,
                color: ok ? kGreen : Colors.red,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.people_outline_rounded, size: 11, color: c.textHint),
          const SizedBox(width: 4),
          Text(
            recip == 'approved' ? 'Aprovados' : 'Todos',
            style: TextStyle(fontSize: 10, color: c.textHint),
          ),
          const SizedBox(width: 12),
          Icon(Icons.person_outline_rounded, size: 11, color: c.textHint),
          const SizedBox(width: 4),
          Expanded(child: Text(sentBy,
            style: TextStyle(fontSize: 10, color: c.textHint),
            overflow: TextOverflow.ellipsis)),
          Text(_formatTs(ts),
            style: TextStyle(fontSize: 10, color: c.textHint, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BIBLIOTECA CLÍNICA — Admin Tab
// _BibliotecaAdminTab · _AdminGuideCard · _GuideUploadDialog · _Field
// ─────────────────────────────────────────────────────────────────────────────

class _BibliotecaAdminTab extends StatefulWidget {
  final dynamic currentAdmin;
  const _BibliotecaAdminTab({required this.currentAdmin});
  @override
  State<_BibliotecaAdminTab> createState() => _BibliotecaAdminTabState();
}

class _BibliotecaAdminTabState extends State<_BibliotecaAdminTab> {
  static const _kGreen = Color(0xFF075f45);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(children: [
      // ── Header ──
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        decoration: BoxDecoration(
          color: _kGreen,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        child: Row(children: [
          const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Biblioteca Clínica',
              style: TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w800)),
          ),
          FilledButton.icon(
            onPressed: () => _openUploadDialog(context),
            icon: const Icon(Icons.upload_file_rounded, size: 16),
            label: const Text('Novo PDF', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ),

      // ── Lista de guias ──
      Expanded(
        child: StreamBuilder<List<GuideModel>>(
          stream: FirestoreService.guidesAdminStream(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(
                  color: _kGreen, strokeWidth: 2));
            }
            final guides = snap.data ?? [];
            if (guides.isEmpty) {
              return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_rounded, size: 52,
                      color: c.textHint.withValues(alpha: 0.4)),
                  const SizedBox(height: 14),
                  Text('Nenhum guia publicado ainda',
                      style: TextStyle(color: c.textHint, fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Toque em "Novo PDF" para adicionar',
                      style: TextStyle(color: c.textHint, fontSize: 12)),
                ],
              ));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              itemCount: guides.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _AdminGuideCard(
                guide: guides[i],
                onEdit: () => _openUploadDialog(context, guide: guides[i]),
                onToggle: () => FirestoreService.toggleGuidePublished(
                    guides[i].id, !guides[i].isPublished),
                onDelete: () => _confirmDelete(context, guides[i]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  void _openUploadDialog(BuildContext context, {GuideModel? guide}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GuideUploadDialog(
        guide: guide,
        adminName: widget.currentAdmin?.displayName as String? ?? 'Admin',
      ),
    );
  }

  void _confirmDelete(BuildContext context, GuideModel guide) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir guia?'),
        content: Text('Isso removerá "${guide.title}" permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirestoreService.deleteGuide(guide.id);
            },
            child: const Text('Excluir',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AdminGuideCard extends StatelessWidget {
  final GuideModel guide;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  const _AdminGuideCard({
    required this.guide,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  static const _kGreen = Color(0xFF075f45);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final published = guide.isPublished;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: published
              ? _kGreen.withValues(alpha: 0.25)
              : c.textHint.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // ícone PDF
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: _kGreen, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(guide.title,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: c.textPrimary),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(guide.category,
                style: TextStyle(fontSize: 11, color: _kGreen,
                    fontWeight: FontWeight.w600)),
            ],
          )),
          // badge publicado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: published
                  ? _kGreen.withValues(alpha: 0.12)
                  : c.textHint.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              published ? 'Publicado' : 'Rascunho',
              style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: published ? _kGreen : c.textHint),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        if (guide.description.isNotEmpty) ...[
          Text(guide.description,
            style: TextStyle(fontSize: 12, color: c.textHint, height: 1.4),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
        ],
        // meta info
        Row(children: [
          if (guide.year.isNotEmpty) ...[
            Icon(Icons.calendar_today_rounded, size: 11, color: c.textHint),
            const SizedBox(width: 3),
            Text(guide.year,
              style: TextStyle(fontSize: 11, color: c.textHint)),
            const SizedBox(width: 10),
          ],
          Icon(Icons.download_rounded, size: 11, color: c.textHint),
          const SizedBox(width: 3),
          Text('${guide.downloadCount} downloads',
            style: TextStyle(fontSize: 11, color: c.textHint)),
          const SizedBox(width: 10),
          Icon(Icons.storage_rounded, size: 11, color: c.textHint),
          const SizedBox(width: 3),
          Text(guide.fileSizeLabel,
            style: TextStyle(fontSize: 11, color: c.textHint)),
        ]),
        const SizedBox(height: 10),
        // ações
        Row(children: [
          _ActionBtn(
            icon: Icons.edit_rounded,
            label: 'Editar',
            color: const Color(0xFF1565C0),
            onTap: onEdit,
          ),
          const SizedBox(width: 8),
          _ActionBtn(
            icon: published
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            label: published ? 'Despublicar' : 'Publicar',
            color: published ? Colors.orange : _kGreen,
            onTap: onToggle,
          ),
          const Spacer(),
          _ActionBtn(
            icon: Icons.delete_outline_rounded,
            label: 'Excluir',
            color: Colors.red,
            onTap: onDelete,
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _GuideUploadDialog extends StatefulWidget {
  final GuideModel? guide;
  final String adminName;
  const _GuideUploadDialog({this.guide, required this.adminName});
  @override
  State<_GuideUploadDialog> createState() => _GuideUploadDialogState();
}

class _GuideUploadDialogState extends State<_GuideUploadDialog> {
  static const _kGreen = Color(0xFF075f45);

  final _titleCtrl       = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _authorsCtrl     = TextEditingController();
  final _yearCtrl        = TextEditingController();

  String _category       = GuideModel.categories.first;
  Uint8List? _pdfBytes;
  String?    _pdfFileName;
  int?       _pdfFileSize;

  bool   _uploading      = false;
  double _uploadProgress = 0;
  String? _error;

  bool get _isEditing => widget.guide != null;

  @override
  void initState() {
    super.initState();
    final g = widget.guide;
    if (g != null) {
      _titleCtrl.text   = g.title;
      _descCtrl.text    = g.description;
      _authorsCtrl.text = g.authors;
      _yearCtrl.text    = g.year;
      _category         = g.category;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _authorsCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _pickPdf() {
    // Delega ao helper condicional: pdf_picker_web.dart (Web) ou stub (iOS/Android).
    webPickPdf().then((result) {
      if (result == null) return;
      setState(() {
        _pdfBytes    = result.bytes;
        _pdfFileName = result.name;
        _pdfFileSize = result.size;
        _error       = null;
      });
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'O título é obrigatório.');
      return;
    }
    if (!_isEditing && _pdfBytes == null) {
      setState(() => _error = 'Selecione um arquivo PDF.');
      return;
    }

    setState(() { _uploading = true; _error = null; });

    try {
      String pdfUrl      = widget.guide?.pdfUrl ?? '';
      String fileName    = widget.guide?.fileName ?? '';
      int    fileSize    = widget.guide?.fileSize ?? 0;

      // Upload novo PDF se selecionado
      if (_pdfBytes != null && _pdfFileName != null) {
        final result = await StorageService.uploadGuidePdf(
          bytes: _pdfBytes!,
          fileName: _pdfFileName!,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
        pdfUrl   = result.url;
        fileName = _pdfFileName!;
        fileSize = _pdfFileSize ?? 0;
      }

      final guide = GuideModel(
        id:          widget.guide?.id ?? '',
        title:       title,
        description: _descCtrl.text.trim(),
        category:    _category,
        authors:     _authorsCtrl.text.trim(),
        year:        _yearCtrl.text.trim(),
        pdfUrl:      pdfUrl,
        fileName:    fileName,
        fileSize:    fileSize,
        uploadedAt:  widget.guide?.uploadedAt ?? '',
        uploadedBy:  widget.guide?.uploadedBy ?? widget.adminName,
        isPublished: widget.guide?.isPublished ?? false,
        downloadCount: widget.guide?.downloadCount ?? 0,
      );

      await FirestoreService.saveGuide(guide);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _uploading = false;
        _error = 'Erro ao salvar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: const BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              Icon(_isEditing ? Icons.edit_rounded : Icons.upload_file_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isEditing ? 'Editar Guia' : 'Novo Guia Clínico',
                  style: const TextStyle(color: Colors.white, fontSize: 15,
                      fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                onPressed: _uploading ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                visualDensity: VisualDensity.compact,
              ),
            ]),
          ),

          // ── Corpo ──
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Field(label: 'Título *', controller: _titleCtrl,
                      hint: 'ex: Protocolo Sepse 2024'),
                  const SizedBox(height: 12),
                  _Field(label: 'Descrição', controller: _descCtrl,
                      hint: 'Breve resumo do conteúdo', maxLines: 3),
                  const SizedBox(height: 12),

                  // Categoria
                  const Text('Categoria *',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                    items: GuideModel.categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c,
                            style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) { if (v != null) setState(() => _category = v); },
                  ),
                  const SizedBox(height: 12),

                  Row(children: [
                    Expanded(child: _Field(label: 'Autores', controller: _authorsCtrl,
                        hint: 'ex: Silva JA, Santos MR')),
                    const SizedBox(width: 12),
                    SizedBox(width: 100, child: _Field(label: 'Ano',
                        controller: _yearCtrl, hint: '2024',
                        keyboardType: TextInputType.number)),
                  ]),
                  const SizedBox(height: 16),

                  // Seleção de PDF
                  const Text('Arquivo PDF',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  // Botão explícito — GestureDetector não dispara FilePicker no web/Dialog
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _uploading ? null : _pickPdf,
                      icon: Icon(
                        _pdfBytes != null
                            ? Icons.picture_as_pdf_rounded
                            : Icons.upload_file_rounded,
                        size: 20,
                        color: _pdfBytes != null ? _kGreen : Colors.grey[600],
                      ),
                      label: Text(
                        _pdfFileName ??
                            (_isEditing
                                ? 'Substituir PDF'
                                : 'Selecionar PDF'),
                        style: TextStyle(
                          fontSize: 13,
                          color: _pdfBytes != null ? _kGreen : Colors.grey[700],
                          fontWeight: _pdfBytes != null
                              ? FontWeight.w600 : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        alignment: Alignment.centerLeft,
                        backgroundColor: _pdfBytes != null
                            ? _kGreen.withValues(alpha: 0.06)
                            : Colors.grey.withValues(alpha: 0.04),
                        side: BorderSide(
                          color: _pdfBytes != null
                              ? _kGreen.withValues(alpha: 0.40)
                              : Colors.grey.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (_pdfFileSize != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatSize(_pdfFileSize!),
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],

                  // Barra de progresso
                  if (_uploading) ...[
                    const SizedBox(height: 14),
                    LinearProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      color: _kGreen,
                      backgroundColor: _kGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _uploadProgress > 0
                          ? 'Enviando... ${(_uploadProgress * 100).toInt()}%'
                          : 'Salvando...',
                      style: const TextStyle(fontSize: 11, color: _kGreen),
                    ),
                  ],

                  // Erro
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Footer ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
            ),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _uploading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _uploading ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kGreen,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _isEditing ? 'Salvar alterações' : 'Publicar guia',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfluencersTab — Sistema de Indicações (Referral)
// ─────────────────────────────────────────────────────────────────────────────

class _InfluencersTab extends StatefulWidget {
  const _InfluencersTab();

  @override
  State<_InfluencersTab> createState() => _InfluencersTabState();
}

class _InfluencersTabState extends State<_InfluencersTab> {
  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);

  // ── Formulário ──────────────────────────────────────────────────────────
  final _nameCtrl     = TextEditingController();
  final _couponCtrl   = TextEditingController();
  final _discCtrl     = TextEditingController();
  final _slugPreview  = ValueNotifier<String>('');
  bool  _saving       = false;
  String? _formError;

  // ── Lista + contagens ────────────────────────────────────────────────────
  List<InfluencerModel> _influencers = [];
  Map<String, int>      _counts      = {};
  bool _listLoading = true;

  // URL base do app para gerar o link de indicação
  static const _baseUrl = 'https://medcasespro.com';

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChanged);
    _loadInfluencers();
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    _couponCtrl.dispose();
    _discCtrl.dispose();
    _slugPreview.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final slug = ReferralService.generateSlug(_nameCtrl.text);
    _slugPreview.value = slug;
  }

  Future<void> _loadInfluencers() async {
    setState(() => _listLoading = true);
    try {
      final list = await ReferralService.getInfluencers();
      final ids  = list.map((i) => i.id).toList();
      final counts = ids.isEmpty
          ? <String, int>{}
          : await ReferralService.getBatchConversionCounts(ids);
      if (!mounted) return;
      setState(() {
        _influencers  = list;
        _counts       = counts;
        _listLoading  = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _listLoading = false);
      _showSnack('Erro ao carregar indicadores: $e', isError: true);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'Nome obrigatório.');
      return;
    }
    final coupon = _couponCtrl.text.trim();
    final discStr = _discCtrl.text.trim();
    final disc    = discStr.isNotEmpty ? int.tryParse(discStr) : null;
    if (discStr.isNotEmpty && disc == null) {
      setState(() => _formError = 'Desconto deve ser um número inteiro (ex: 20).');
      return;
    }
    setState(() { _saving = true; _formError = null; });

    try {
      await ReferralService.createInfluencer(
        name:            name,
        couponCode:      coupon.isNotEmpty ? coupon : null,
        discountPercent: disc,
      );
      _nameCtrl.clear();
      _couponCtrl.clear();
      _discCtrl.clear();
      _showSnack('Influenciador cadastrado com sucesso!');
      await _loadInfluencers();
    } catch (e) {
      setState(() => _formError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(InfluencerModel inf) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F1F17),
        title: const Text('Remover influenciador?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'O influenciador "${inf.name}" será removido permanentemente.\n'
          'Os usuários já indicados por ele NÃO serão afetados.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ReferralService.deleteInfluencer(inf.id);
      _showSnack('Influenciador removido.');
      await _loadInfluencers();
    } catch (e) {
      _showSnack('Erro ao remover: $e', isError: true);
    }
  }

  void _copyLink(String slug) {
    final link = '$_baseUrl?ref=$slug';
    // Clipboard funciona em web via Flutter
    Clipboard.setData(ClipboardData(text: link));
    _showSnack('Link copiado: $link');
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: isError ? Colors.red[700] : kGreen,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kDark,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Cabeçalho ──────────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.people_alt_rounded, color: kGold, size: 20),
            const SizedBox(width: 8),
            const Text('Sistema de Indicações',
                style: TextStyle(color: kGoldL, fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(
              tooltip: 'Atualizar lista',
              onPressed: _loadInfluencers,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 18),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            'Cadastre influenciadores para gerar links únicos (?ref=slug). '
            'Os usuários que acessarem via link serão vinculados automaticamente.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 20),

          // ── Formulário de cadastro ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kGreen.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cadastrar novo influenciador',
                    style: TextStyle(color: kGoldL, fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),

                // Nome
                _InfluField(
                  label: 'Nome do influenciador *',
                  hint: 'Ex: Dr. Marcos - Cardiologia',
                  controller: _nameCtrl,
                ),
                const SizedBox(height: 8),

                // Preview do slug gerado
                ValueListenableBuilder<String>(
                  valueListenable: _slugPreview,
                  builder: (_, slug, __) {
                    if (slug.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        const Icon(Icons.link_rounded,
                            size: 13, color: Colors.white38),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$_baseUrl?ref=$slug',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                    );
                  },
                ),

                // Cupom + Desconto em linha
                Row(children: [
                  Expanded(
                    child: _InfluField(
                      label: 'Código do cupom (opcional)',
                      hint: 'Ex: PLANTAO20',
                      controller: _couponCtrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: _InfluField(
                      label: 'Desconto %',
                      hint: '20',
                      controller: _discCtrl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // Erro do formulário
                if (_formError != null) ...[
                  Text(_formError!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                  const SizedBox(height: 8),
                ],

                // Botão Cadastrar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_rounded, size: 16),
                    label: Text(_saving ? 'Cadastrando...' : 'Cadastrar Influenciador'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Tabela de influenciadores ───────────────────────────────────
          Row(children: [
            const Text('Influenciadores Cadastrados',
                style: TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (!_listLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: kGreen.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_influencers.length}',
                    style: const TextStyle(
                        color: kGoldL, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
          ]),
          const SizedBox(height: 10),

          if (_listLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: kGreen),
            ))
          else if (_influencers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    const Text('Nenhum influenciador cadastrado ainda.',
                        style: TextStyle(color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            // Layout adaptativo: cards no mobile, DataTable no desktop
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                if (isMobile) {
                  // ── Cards para mobile ──────────────────────────────────────
                  return Column(
                    children: _influencers.map((inf) {
                      final count = _counts[inf.id] ?? 0;
                      final link  = '$_baseUrl?ref=${inf.id}';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: kGreen.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nome + badge conversões
                            Row(children: [
                              Expanded(
                                child: Text(inf.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: count > 0
                                      ? kGreen.withValues(alpha: 0.35)
                                      : Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('$count conv.',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: count > 0
                                            ? kGoldL
                                            : Colors.white38)),
                              ),
                            ]),
                            const SizedBox(height: 6),
                            // Cupom (se houver)
                            if (inf.couponCode != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(children: [
                                  const Icon(Icons.discount_outlined,
                                      size: 12, color: kGoldL),
                                  const SizedBox(width: 4),
                                  Text(inf.couponLabel,
                                      style: const TextStyle(
                                          fontSize: 11, color: kGoldL)),
                                ]),
                              ),
                            // Link
                            Text(link,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.white38),
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            // Botões — Copiar + Remover
                            Row(children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _copyLink(inf.id),
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 13, color: kGoldL),
                                  label: const Text('Copiar Link',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: kGoldL,
                                          fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: kGold.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Remover',
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: Colors.redAccent),
                                onPressed: () => _delete(inf),
                              ),
                            ]),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }

                // ── DataTable para desktop ─────────────────────────────────
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                          kGreen.withValues(alpha: 0.25)),
                      dataRowColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? kGreen.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.03),
                      ),
                      columnSpacing: 20,
                      headingTextStyle: const TextStyle(
                          color: kGoldL, fontSize: 11, fontWeight: FontWeight.w800),
                      dataTextStyle: const TextStyle(
                          color: Colors.white, fontSize: 12),
                      columns: const [
                        DataColumn(label: Text('Nome do Influenciador')),
                        DataColumn(label: Text('Cupom')),
                        DataColumn(label: Text('Link de Indicação')),
                        DataColumn(label: Text('Conversões'), numeric: true),
                        DataColumn(label: Text('Ações')),
                      ],
                      rows: _influencers.map((inf) {
                        final count = _counts[inf.id] ?? 0;
                        final link  = '$_baseUrl?ref=${inf.id}';
                        return DataRow(cells: [
                          DataCell(ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(inf.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          )),
                          DataCell(Text(inf.couponLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: inf.couponCode != null ? kGoldL : Colors.white38))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 180),
                                child: Text(link,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, color: Colors.white54)),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _copyLink(inf.id),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kGreen.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.copy_rounded, size: 11, color: kGoldL),
                                    SizedBox(width: 4),
                                    Text('Copiar', style: TextStyle(fontSize: 10, color: kGoldL, fontWeight: FontWeight.w700)),
                                  ]),
                                ),
                              ),
                            ],
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? kGreen.withValues(alpha: 0.35)
                                  : Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('$count',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                                    color: count > 0 ? kGoldL : Colors.white38)),
                          )),
                          DataCell(IconButton(
                            tooltip: 'Remover influenciador',
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 16, color: Colors.redAccent),
                            onPressed: () => _delete(inf),
                          )),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 32),

          // ── Nota informativa ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: Colors.amber),
                  SizedBox(width: 6),
                  Text('Como funciona',
                      style: TextStyle(color: Colors.amber,
                          fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
                SizedBox(height: 8),
                Text(
                  '1. Cadastre o influenciador — o slug é gerado automaticamente pelo nome.\n'
                  '2. Compartilhe o link gerado (ex: medcasespro.com?ref=dr_marcos).\n'
                  '3. Quando um médico acessa via esse link e se cadastra, '
                     'ele é vinculado automaticamente ao influenciador.\n'
                  '4. "Conversões" = médicos que completaram o cadastro pelo link.\n'
                  '5. Cupom e desconto ficam prontos para aplicação automática '
                     'no checkout assim que a monetização for ativada.',
                  style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input field estilizado para a aba Indicações ──────────────────────────────

class _InfluField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _InfluField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: const Color(0xFF075f45).withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF075f45)),
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tab 9 — NOTIFICAÇÕES ADMIN (PARTE 4 BUILD 238)
// ═════════════════════════════════════════════════════════════════════════════
//
// Mostra as notificações em /admin_notifications, mais recentes primeiro.
// Cada card tem botão "Marcar como lida" → readBy: arrayUnion(adminUid).
// Notificações não lidas aparecem com borda dourada.
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationsTab extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final String currentAdminUid;
  final Future<void> Function(String notifId) onMarkRead;

  const _NotificationsTab({
    required this.notifications,
    required this.currentAdminUid,
    required this.onMarkRead,
  });

  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);

  bool _isRead(Map<String, dynamic> notif) {
    final readBy = (notif['readBy'] as List?) ?? [];
    return readBy.contains(currentAdminUid);
  }

  String _formatTs(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      final dt = ts.toDate().toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return ts.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.notifications_none_rounded, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          const Text('Nenhuma notificação ainda.',
              style: TextStyle(color: Colors.white38, fontSize: 14)),
        ]),
      );
    }

    final unread = notifications.where((n) => !_isRead(n)).length;

    return Column(children: [
      // ── Header com contagem de não lidas ─────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: kDark,
        child: Row(children: [
          Icon(Icons.notifications_active_rounded, color: kGoldL, size: 16),
          const SizedBox(width: 8),
          Text(
            unread > 0
                ? '$unread não lida${unread > 1 ? 's' : ''} · ${notifications.length} total'
                : '${notifications.length} notificaç${notifications.length > 1 ? 'ões' : 'ão'} · todas lidas',
            style: TextStyle(
              color: unread > 0 ? kGoldL : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
      // ── Lista de notificações ─────────────────────────────────────────────
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: notifications.length,
          itemBuilder: (_, i) {
            final n = notifications[i];
            final notifId   = n['id'] as String;
            final read      = _isRead(n);
            final userName  = (n['userName']  as String?) ?? 'Usuário';
            final userEmail = (n['userEmail'] as String?) ?? '—';
            final profession= (n['userProfession'] as String?) ?? '—';
            final institution=(n['userInstitution'] as String?) ?? '—';
            final status    = (n['userStatus'] as String?) ?? 'approved';
            final tsLabel   = _formatTs(n['createdAt']);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF111a14),
                border: Border.all(
                  color: read
                      ? Colors.white12
                      : kGold.withValues(alpha: 0.6),
                  width: read ? 0.5 : 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Linha de cabeçalho ──────────────────────────────────
                  Row(children: [
                    Icon(
                      Icons.person_add_rounded,
                      size: 16,
                      color: read ? Colors.white38 : kGoldL,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🆕  $userName',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: read ? FontWeight.w500 : FontWeight.w800,
                          color: read ? Colors.white60 : Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!read)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                        ),
                        child: const Text('NOVA',
                            style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  // ── Detalhes ────────────────────────────────────────────
                  _notifRow(Icons.email_rounded, userEmail, read),
                  _notifRow(Icons.work_rounded, profession, read),
                  _notifRow(Icons.location_city_rounded, institution, read),
                  Row(children: [
                    Icon(Icons.circle, size: 6,
                        color: status == 'approved' ? Colors.greenAccent : Colors.orange),
                    const SizedBox(width: 6),
                    Text(status,
                        style: TextStyle(
                          fontSize: 11,
                          color: status == 'approved'
                              ? Colors.greenAccent.withValues(alpha: 0.8)
                              : Colors.orange,
                          fontWeight: FontWeight.w600,
                        )),
                    const Spacer(),
                    Text(tsLabel,
                        style: const TextStyle(fontSize: 10, color: Colors.white24)),
                  ]),
                  // ── Botão marcar como lida ──────────────────────────────
                  if (!read) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () => onMarkRead(notifId),
                        icon: const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFFFFE8A6)),
                        label: const Text('Marcar como lida',
                            style: TextStyle(color: Color(0xFFFFE8A6), fontSize: 12, fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          backgroundColor: kGold.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _notifRow(IconData icon, String text, bool read) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Icon(icon, size: 11, color: Colors.white24),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              style: TextStyle(
                fontSize: 11,
                color: read ? Colors.white38 : Colors.white60,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}
