import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
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
  // Um único StreamSubscription alimenta _allUsers; as tabs filtram localmente.
  StreamSubscription<List<UserModel>>? _usersSub;
  List<UserModel> _allUsers  = [];
  bool            _usersLoading = true;

  // ── Estado do tab Sistema ────────────────────────────────────────────────
  bool _maintEnabled = false;
  bool _maintLoading = false;
  final TextEditingController _maintMsgCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _loadLang();
    _subscribeUsers();
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
          tabAlignment: TabAlignment.fill,
          tabs: [
            Tab(icon: const Icon(Icons.pending_actions_rounded, size: 16), text: _pendingLabel),
            Tab(icon: const Icon(Icons.people_rounded, size: 16), text: _approvedLabel),
            Tab(icon: const Icon(Icons.block_rounded, size: 16), text: _blockedLabel),
            Tab(icon: const Icon(Icons.settings_rounded, size: 16), text: _systemLabel),
            const Tab(icon: Icon(Icons.auto_awesome_rounded, size: 16), text: 'Novidades'),
            const Tab(icon: Icon(Icons.bar_chart_rounded, size: 16), text: 'Stats'),
          ],
        ),
      ),
      body: AnimatedBuilder(
        animation: _tabs,
        builder: (context, _) {
          final isSystemTab = _tabs.index == 3 || _tabs.index == 4 || _tabs.index == 5;
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

  @override
  void initState() {
    super.initState();
    _loadCurrentAiKey();
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
                              activeThumbColor: Colors.orange,
                              activeTrackColor: Colors.orange.withValues(alpha: 0.25),
                              inactiveThumbColor: kGreen,
                              inactiveTrackColor: kGreen.withValues(alpha: 0.2),
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
