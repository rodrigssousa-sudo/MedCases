import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
        title: const Row(children: [
          Icon(Icons.admin_panel_settings_rounded, color: kGoldL, size: 20),
          SizedBox(width: 8),
          Text('Painel Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: kGoldL,
          labelColor: kGoldL,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions_rounded, size: 18), text: 'Pendentes'),
            Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'Aprovados'),
            Tab(icon: Icon(Icons.block_rounded, size: 18), text: 'Bloqueados'),
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
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou e-mail...',
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
                      emptyMsg: 'Nenhum usuário pendente',
                      emptyIcon: Icons.check_circle_outline_rounded,
                      adminUid: widget.currentAdmin.uid,
                      onApprove: _approve,
                      onBlock: _block,
                      showApprove: true,
                      showBlock: true,
                    ),
                    _UserList(
                      users: approved,
                      emptyMsg: 'Nenhum usuário aprovado',
                      emptyIcon: Icons.people_outline_rounded,
                      adminUid: widget.currentAdmin.uid,
                      onBlock: _block,
                      onPromote: _promote,
                      showBlock: true,
                      showPromote: true,
                    ),
                    _UserList(
                      users: blocked,
                      emptyMsg: 'Nenhum usuário bloqueado',
                      emptyIcon: Icons.verified_user_outlined,
                      adminUid: widget.currentAdmin.uid,
                      onApprove: _unblock,
                      showApprove: true,
                      approveBtnLabel: 'Desbloquear',
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
            label: Text('$pendingCount pendente${pendingCount > 1 ? 's' : ''}',
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
    if (mounted) _snack('✅ ${u.displayName} aprovado!', Colors.green);
  }

  Future<void> _unblock(UserModel u) async {
    await AuthService.unblockUser(u.uid, widget.currentAdmin.uid);
    if (mounted) _snack('✅ ${u.displayName} desbloqueado!', Colors.green);
  }

  Future<void> _block(UserModel u) async {
    final confirm = await _confirmDialog(
      'Bloquear ${u.displayName}?',
      'O usuário perderá acesso imediatamente.',
    );
    if (!confirm) return;
    await AuthService.blockUser(u.uid);
    if (mounted) _snack('🚫 ${u.displayName} bloqueado.', Colors.orange);
  }

  Future<void> _promote(UserModel u) async {
    final confirm = await _confirmDialog(
      'Promover ${u.displayName} a Admin?',
      'Ele terá acesso total ao painel de administração.',
    );
    if (!confirm) return;
    await AuthService.promoteToAdmin(u.uid);
    if (mounted) _snack('⭐ ${u.displayName} promovido a Admin!', kGold);
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
                child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: kDark, foregroundColor: kGoldL),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
  }

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
  final String adminUid;
  final void Function(UserModel)? onApprove;
  final void Function(UserModel)? onBlock;
  final void Function(UserModel)? onPromote;
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
    required this.adminUid,
    this.onApprove,
    this.onBlock,
    this.onPromote,
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
      itemBuilder: (ctx, i) => _UserCard(
        user: users[i],
        adminUid: adminUid,
        onApprove: showApprove && onApprove != null ? () => onApprove!(users[i]) : null,
        onBlock: showBlock && onBlock != null && users[i].uid != adminUid ? () => onBlock!(users[i]) : null,
        onPromote: showPromote && onPromote != null && users[i].role != UserRole.admin ? () => onPromote!(users[i]) : null,
        approveBtnLabel: approveBtnLabel,
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final String adminUid;
  final VoidCallback? onApprove;
  final VoidCallback? onBlock;
  final VoidCallback? onPromote;
  final String approveBtnLabel;

  static const kDark  = Color(0xFF07110d);
  static const kGreen = Color(0xFF075f45);
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);

  const _UserCard({
    required this.user,
    required this.adminUid,
    this.onApprove,
    this.onBlock,
    this.onPromote,
    required this.approveBtnLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = user.uid == adminUid;

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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
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
                      child: const Text('Você', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGold)),
                    ),
                  const SizedBox(width: 4),
                  _StatusBadge(user.status),
                  if (user.isAdmin) ...[
                    const SizedBox(width: 4),
                    _RoleBadge(),
                  ],
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
            'Cadastro: ${_formatDate(user.createdAt)}${user.approvedAt != null ? '  •  Aprovado: ${_formatDate(user.approvedAt!)}' : ''}',
            style: TextStyle(fontSize: 10, color: kDark.withValues(alpha: 0.35), fontWeight: FontWeight.w500),
          ),

          // Botões de ação
          if (onApprove != null || onBlock != null || onPromote != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (onApprove != null)
                Expanded(child: _ActionBtn(
                  label: approveBtnLabel,
                  icon: Icons.check_circle_outline_rounded,
                  color: kGreen,
                  onTap: onApprove!,
                )),
              if (onApprove != null && (onBlock != null || onPromote != null))
                const SizedBox(width: 8),
              if (onPromote != null)
                Expanded(child: _ActionBtn(
                  label: 'Tornar Admin',
                  icon: Icons.star_outline_rounded,
                  color: kGold,
                  onTap: onPromote!,
                )),
              if (onPromote != null && onBlock != null)
                const SizedBox(width: 8),
              if (onBlock != null)
                Expanded(child: _ActionBtn(
                  label: 'Bloquear',
                  icon: Icons.block_rounded,
                  color: Colors.red,
                  onTap: onBlock!,
                )),
            ]),
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
        bg = Colors.green.withValues(alpha: 0.1); fg = Colors.green; label = 'Aprovado'; break;
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
  static const kGold  = Color(0xFFC5A365);
  static const kGoldL = Color(0xFFFFE8A6);
  const _RoleBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: kGold.withValues(alpha: 0.12),
        border: Border.all(color: kGold.withValues(alpha: 0.4)),
      ),
      child: const Text('Admin', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: kGold)),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }
}
