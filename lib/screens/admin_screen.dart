import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
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

  // Atalho: o admin atual é Master?
  bool get _isMaster => widget.currentAdmin.isMaster;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadLang();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
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
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: kGoldL,
          labelColor: kGoldL,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          tabs: [
            Tab(icon: const Icon(Icons.pending_actions_rounded, size: 18), text: _pendingLabel),
            Tab(icon: const Icon(Icons.people_rounded, size: 18), text: _approvedLabel),
            Tab(icon: const Icon(Icons.block_rounded, size: 18), text: _blockedLabel),
          ],
        ),
      ),
      body: Column(
        children: [
          // Barra de busca
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
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          // Lista de usuários
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: AuthService.allUsersStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: kGreen));
                }
                if (snap.hasError) {
                  return Center(child: Text('Erro: ${snap.error}', style: const TextStyle(color: Colors.red)));
                }

                final all = snap.data ?? [];
                final pending  = _filter(all, UserStatus.pending);
                final approved = _filter(all, UserStatus.approved);
                final blocked  = _filter(all, UserStatus.blocked);

                return TabBarView(
                  controller: _tabs,
                  children: [
                    _UserList(
                      users: pending,
                      emptyMsg: _emptyPendingMsg,
                      emptyIcon: Icons.check_circle_outline_rounded,
                      currentAdmin: widget.currentAdmin,
                      isMaster: _isMaster,
                      onApprove: _approve,
                      onBlock: _block,
                      showApprove: true,
                      showBlock: true,
                    ),
                    _UserList(
                      users: approved,
                      emptyMsg: _emptyApprovedMsg,
                      emptyIcon: Icons.people_outline_rounded,
                      currentAdmin: widget.currentAdmin,
                      isMaster: _isMaster,
                      onBlock: _block,
                      onPromote: _promote,
                      onPromoteSupervisor: _isMaster ? _promoteSupervisor : null,
                      onDemote: _isMaster ? _demote : null,
                      showBlock: true,
                      showPromote: true,
                    ),
                    _UserList(
                      users: blocked,
                      emptyMsg: _emptyBlockedMsg,
                      emptyIcon: Icons.verified_user_outlined,
                      currentAdmin: widget.currentAdmin,
                      isMaster: _isMaster,
                      onApprove: _unblock,
                      showApprove: true,
                      approveBtnLabel: _unblockLabel,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // FAB com estatísticas
      floatingActionButton: StreamBuilder<List<UserModel>>(
        stream: AuthService.allUsersStream(),
        builder: (context, snap) {
          final all = snap.data ?? [];
          final pendingCount = all.where((u) => u.isPending).length;
          if (pendingCount == 0) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _tabs.animateTo(0),
            backgroundColor: Colors.orange,
            icon: const Icon(Icons.notification_important_rounded, color: Colors.white),
            label: Text('$pendingCount ${_pendingCountLabel(pendingCount)}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          );
        },
      ),
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
    await AuthService.approveUser(u.uid, widget.currentAdmin.uid);
    if (mounted) _snack('✅ \${u.displayName} $_approvedSnack', Colors.green);
  }

  Future<void> _unblock(UserModel u) async {
    await AuthService.unblockUser(u.uid, widget.currentAdmin.uid);
    if (mounted) _snack('✅ \${u.displayName} $_unblockedSnack', Colors.green);
  }

  Future<void> _block(UserModel u) async {
    final confirm = await _confirmDialog(
      'Bloquear ${u.displayName}?',
      'O usuário perderá acesso imediatamente.',
    );
    if (!confirm) return;
    await AuthService.blockUser(u.uid);
    if (mounted) _snack('🚫 \${u.displayName} $_blockedSnack', Colors.orange);
  }

  Future<void> _promote(UserModel u) async {
    // Admin pode promover a supervisor; Master pode promover a admin
    if (_isMaster) {
      final confirm = await _confirmDialog(
        'Promover ${u.displayName} a Admin?',
        'Ele terá acesso ao painel de administração.',
      );
      if (!confirm) return;
      await AuthService.promoteToAdmin(u.uid);
      if (mounted) _snack('⭐ \${u.displayName} $_promotedAdminSnack', kGold);
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
    await AuthService.promoteToSupervisor(u.uid);
    if (mounted) _snack('🔰 \${u.displayName} $_promotedSupervisorSnack', Colors.blue);
  }

  Future<void> _demote(UserModel u) async {
    final confirm = await _confirmDialog(
      'Rebaixar ${u.displayName}?',
      'O usuário voltará a ser um usuário comum, sem poderes administrativos.',
    );
    if (!confirm) return;
    await AuthService.demoteToUser(u.uid);
    if (mounted) _snack('↘ \${u.displayName} $_demotedSnack', Colors.grey);
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

  String get _masterPanelLabel       => _isEs ? 'Panel Master'                 : 'Painel Master';
  String get _adminPanelLabel        => _isEs ? 'Panel Admin'                  : 'Painel Admin';
  String get _pendingLabel           => _isEs ? 'Pendientes'                   : 'Pendentes';
  String get _approvedLabel          => _isEs ? 'Aprobados'                    : 'Aprovados';
  String get _blockedLabel           => _isEs ? 'Bloqueados'                   : 'Bloqueados';
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
  String _pendingCountLabel(int n)   => _isEs ? 'pendiente\${n > 1 ? "s" : ""}' : 'pendente\${n > 1 ? "s" : ""}';

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
  final bool showApprove;
  final bool showBlock;
  final bool showPromote;
  final String approveBtnLabel;

  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);

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
    this.showApprove = false,
    this.showBlock = false,
    this.showPromote = false,
    this.approveBtnLabel = 'Aprovar',
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(emptyIcon, size: 48, color: kGreen.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(emptyMsg, style: TextStyle(color: kDark.withValues(alpha: 0.4), fontWeight: FontWeight.w600)),
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

        return _UserCard(
          user: u,
          currentAdmin: currentAdmin,
          isMaster: isMaster,
          onApprove: showApprove && onApprove != null ? () => onApprove!(u) : null,
          onBlock: showBlock && onBlock != null && !isMe && !u.isMaster ? () => onBlock!(u) : null,
          onPromote: canPromote ? () => onPromote!(u) : null,
          onPromoteSupervisor: canPromoteSupervisor ? () => onPromoteSupervisor!(u) : null,
          onDemote: canDemote ? () => onDemote!(u) : null,
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
    required this.approveBtnLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = user.uid == currentAdmin.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isMe ? kGold.withValues(alpha: 0.5) : kDark.withValues(alpha: 0.07)),
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
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: kDark),
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
                Text(user.email, style: TextStyle(fontSize: 11, color: kDark.withValues(alpha: 0.5), fontWeight: FontWeight.w500)),
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

          // Data de cadastro
          const SizedBox(height: 6),
          Text(
            'Reg: ${_formatDate(user.createdAt)}${user.approvedAt != null ? '  •  Aprov: ${_formatDate(user.approvedAt!)}' : ''}',
            style: TextStyle(fontSize: 10, color: kDark.withValues(alpha: 0.35), fontWeight: FontWeight.w500),
          ),

          // Botões de ação
          if (onApprove != null || onBlock != null || onPromote != null || onPromoteSupervisor != null || onDemote != null) ...[
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
                  _ActionBtn(label: '↘', icon: Icons.arrow_downward_rounded, color: Colors.orange, onTap: onDemote!),
                if (onBlock != null)
                  _ActionBtn(label: '✕', icon: Icons.block_rounded, color: Colors.red, onTap: onBlock!),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
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
        bg = Colors.orange.withValues(alpha: 0.12); fg = Colors.orange; label = '⏳'; break;
      case UserStatus.blocked:
        bg = Colors.red.withValues(alpha: 0.1); fg = Colors.red; label = '🚫'; break;
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
  static const kGoldL = Color(0xFFFFE8A6);
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: kDark.withValues(alpha: 0.05),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: kDark.withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kDark.withValues(alpha: 0.55))),
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
