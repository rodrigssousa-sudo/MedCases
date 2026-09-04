import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../models/user_model.dart';
import 'support_admin_section.dart';
import '../../services/auth_service.dart';
import '../../models/guide_model.dart';
import '../admin_clinical_guide_editor_screen.dart';

// ADMIN_V2_DASHBOARD_REAL_USERS_REST_V3: retained dashboard baseline.\n// ADMIN_V2_BILLING_FOUNDATION_V1: subscriptions + revenue reader contract for Apple, Google Play and Stripe.

class MedCasesAdminApp extends StatelessWidget {
  const MedCasesAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedCases Admin',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F6F8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D6B57),
          brightness: Brightness.light,
        ),
      ),
      home: const _AdminAuthGate(),
    );
  }
}

class _AdminAuthGate extends StatelessWidget {
  const _AdminAuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _CenteredProgress();
        }

        final firebaseUser = authSnap.data;
        if (firebaseUser == null) {
          return const _AdminLoginScreen();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .get(),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const _CenteredProgress();
            }

            final doc = profileSnap.data;
            if (doc == null || !doc.exists) {
              return const _AccessDenied(
                reason: 'Perfil administrativo não encontrado.',
              );
            }

            final admin = UserModel.fromDoc(doc);
            if (!admin.isAdmin && !admin.isSupervisor) {
              return const _AccessDenied(
                reason: 'Esta área é exclusiva para Supervisor/Admin/Master.',
              );
            }

            return AdminV2Screen(currentAdmin: admin);
          },
        );
      },
    );
  }
}

class _AdminLoginScreen extends StatefulWidget {
  const _AdminLoginScreen();

  @override
  State<_AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<_AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? 'Falha ao entrar.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Falha ao entrar.');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E7EC)),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 28,
                    offset: Offset(0, 12),
                    color: Color(0x14000000),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'MedCases Admin',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Acesso exclusivo para Supervisor/Admin/Master',
                      style: TextStyle(
                        color: Color(0xFF68727D),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      onSubmitted: (_) => _login(),
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFB42318)),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _login,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 44,
                  color: Color(0xFFB42318),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Acesso negado',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(reason, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: FirebaseAuth.instance.signOut,
                  child: const Text('Sair'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

// ADMIN_V2_USERS_MIGRATION_V1: real Users management moved into Admin V2.
// ADMIN_V2_AI_COSTS_MIGRATION_V1: Master-only AI control and cost observability moved into Admin V2.
// ADMIN_V2_ERRORS_HEALTH_CENTER_V1: REST-only operational incident center with lifecycle actions.
// ADMIN_V2_CONTENT_GUIDES_MIGRATION_V1: clinical guides core management moved into Admin V2.
// ADMIN_V2_CONTENT_CANONICAL_CMS_V2: canonical bilingual CMS is native to Content.
// ADMIN_V2_COMMUNICATION_MIGRATION_V1: notifications, push and email operations are native to Admin V2.
// ADMIN_V2_SETTINGS_MIGRATION_V1: maintenance and app updates are native to Admin V2.
// ADMIN_V2_FINAL_AUDIT_ALERTS_V1
// ADMIN_V2_AI_COSTS_V2: GPT + Gemini observability, secure GPT unlock and expanded metrics.
enum _AdminSection {
  dashboard,
  users,
  subscriptions,
  aiCosts,
  errors,
  support,
  content,
  communication,
  audit,
  settings,
}

class AdminV2Screen extends StatefulWidget {
  const AdminV2Screen({
    required this.currentAdmin,
    super.key,
  });

  final UserModel currentAdmin;

  @override
  State<AdminV2Screen> createState() => _AdminV2ScreenState();
}

// ADMIN_V2_SUPERVISOR_LOGIN_SAFE_SURFACE_FIX_V1
class _AdminV2ScreenState extends State<AdminV2Screen> {
  late _AdminSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.currentAdmin.isSupervisor
        ? _AdminSection.errors
        : _AdminSection.dashboard;
  }

  bool get _isMaster => widget.currentAdmin.isMaster;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _AdminSidebar(
            currentAdmin: widget.currentAdmin,
            selected: _section,
            onSelected: (value) => setState(() => _section = value),
          ),
          Expanded(
            child: Column(
              children: [
                _AdminTopbar(title: _sectionTitle(_section)),
                Expanded(child: _buildSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    _AdminUsersRestLoader.setAuditActor(
      uid: widget.currentAdmin.uid,
      email: widget.currentAdmin.email.toString(),
    );

    switch (_section) {
      case _AdminSection.dashboard:
        return const _Dashboard();
      case _AdminSection.errors:
        return _ErrorsHealthCenterSection(
          currentAdmin: widget.currentAdmin,
        );
            // ADMIN_V2_SUPPORT_TICKET_FOUNDATION_V2_B_R1
      case _AdminSection.support:
        return SupportAdminSection(
          currentAdmin: widget.currentAdmin,
        );
case _AdminSection.aiCosts:
        return _AiCostsSection(
          currentAdmin: widget.currentAdmin,
        );
      case _AdminSection.subscriptions:
        return _SubscriptionsRevenueSection(allowed: _isMaster);
      case _AdminSection.users:
        return _UsersManagementSection(
          currentAdmin: widget.currentAdmin,
        );
      case _AdminSection.content:
        return _ContentGuidesSection(
          currentAdmin: widget.currentAdmin,
        );
      case _AdminSection.communication:
        return _CommunicationSection(
          currentAdmin: widget.currentAdmin,
        );
      case _AdminSection.audit:
        return _AuditAlertsSection(
          currentAdmin: widget.currentAdmin,
        );
      case _AdminSection.settings:
        return _SettingsSection(
          currentAdmin: widget.currentAdmin,
        );
    }
  }

  String _sectionTitle(_AdminSection section) {
    switch (section) {
      case _AdminSection.dashboard:
        return 'Dashboard';
      case _AdminSection.users:
        return 'Usuários';
      case _AdminSection.subscriptions:
        return 'Assinaturas & Receita';
      case _AdminSection.aiCosts:
        return 'IA & Custos';
      case _AdminSection.errors:
        return 'Erros & Saúde';
            case _AdminSection.support:
        return 'Suporte';
case _AdminSection.content:
        return 'Conteúdo';
      case _AdminSection.communication:
        return 'Comunicação';
      case _AdminSection.audit:
        return 'Auditoria';
      case _AdminSection.settings:
        return 'Configurações';
    }
  }

}

// ADMIN_V2_LEGACY_BRIDGE_FINAL_REMOVAL_V1
class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.currentAdmin,
    required this.selected,
    required this.onSelected,
  });

  final UserModel currentAdmin;
  final _AdminSection selected;
  final ValueChanged<_AdminSection> onSelected;
  @override
  Widget build(BuildContext context) {
    const items = <(_AdminSection, IconData, String)>[
      (_AdminSection.dashboard, Icons.dashboard_outlined, 'Dashboard'),
      (_AdminSection.users, Icons.group_outlined, 'Usuários'),
      (_AdminSection.subscriptions, Icons.credit_card_outlined, 'Assinaturas'),
      (_AdminSection.aiCosts, Icons.auto_awesome_outlined, 'IA & Custos'),
      (_AdminSection.errors, Icons.monitor_heart_outlined, 'Erros'),
      (_AdminSection.support, Icons.support_agent_outlined, 'Suporte'),
      (_AdminSection.content, Icons.menu_book_outlined, 'Conteúdo'),
      (_AdminSection.communication, Icons.campaign_outlined, 'Comunicação'),
      (_AdminSection.audit, Icons.fact_check_outlined, 'Auditoria'),
      (_AdminSection.settings, Icons.settings_outlined, 'Configurações'),
    ];

    return Container(
      width: 220,
      color: const Color(0xFF111827),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MedCases Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final item in currentAdmin.isSupervisor
                      ? items.where((item) =>
                          item.$1 == _AdminSection.errors ||
                          item.$1 == _AdminSection.support ||
                          item.$1 == _AdminSection.communication ||
                          item.$1 == _AdminSection.settings)
                      : items)
                    _SidebarItem(
                      icon: item.$2,
                      label: item.$3,
                      selected: selected == item.$1,
                      onTap: () => onSelected(item.$1),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: Color(0xFF2B3442)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2734),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 17,
                        child: Icon(Icons.person_outline, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentAdmin.displayName.isEmpty
                                  ? currentAdmin.email
                                  : currentAdmin.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentAdmin.isMaster
                                  ? 'MASTER'
                                  : currentAdmin.isSupervisor
                                      ? 'SUPERVISOR'
                                      : 'ADMIN',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? const Color(0xFF243244) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected ? Colors.white : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFD1D5DB),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

class _AdminTopbar extends StatelessWidget {
  const _AdminTopbar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 58,
          decoration: const BoxDecoration(
            color: Color(0xE6FFFFFF),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E7EC), width: 0.7),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              const _StatusPill(),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Sair',
                onPressed: FirebaseAuth.instance.signOut,
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFB9E6D3)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: Color(0xFF14815F)),
            SizedBox(width: 6),
            Text(
              'Produção',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF176B54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dashboard extends StatefulWidget {
  const _Dashboard();

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  late Future<Map<String, dynamic>> _adminMetricsFuture;
  late Future<Map<String, dynamic>> _errorMetricsFuture;

  @override
  void initState() {
    super.initState();
    _primeDashboardLoads();
  }

  void _primeDashboardLoads() {
    _usersFuture = _AdminUsersRestLoader.load();
    _adminMetricsFuture =
        _AdminUsersRestLoader.loadDocument('admin_metrics/realtime');
    _errorMetricsFuture =
        _AdminUsersRestLoader.loadDocument('admin_error_metrics/realtime');
  }

  void _reloadAll() {
    if (!mounted) return;
    setState(_primeDashboardLoads);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, usersSnap) {
        final userMetrics = _AdminUserMetrics.fromRows(usersSnap.data);
        final usersReady = usersSnap.hasData && !usersSnap.hasError;

        return FutureBuilder<Map<String, dynamic>>(
          future: _adminMetricsFuture,
          builder: (context, adminSnap) {
            final adminData = adminSnap.data ?? const <String, dynamic>{};

            return FutureBuilder<Map<String, dynamic>>(
              future: _errorMetricsFuture,
              builder: (context, errorSnap) {
                final errorData = errorSnap.data ?? const <String, dynamic>{};

                final loading =
                    usersSnap.connectionState == ConnectionState.waiting ||
                        adminSnap.connectionState == ConnectionState.waiting ||
                        errorSnap.connectionState == ConnectionState.waiting;

                final dashboardError =
                    usersSnap.error ?? adminSnap.error ?? errorSnap.error;

                String userValue(int value) => usersReady ? '$value' : '—';

                final criticalRaw =
                    adminData['criticalErrors24h'] ?? errorData['critical24h'];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Visão executiva, operação e saúde do MedCases Pro.',
                            style: TextStyle(
                              color: Color(0xFF68727D),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        _LiveSourcePill(
                          loading: loading,
                          error: dashboardError != null,
                          onTap: loading ? null : _reloadAll,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MetricGrid(
                      cards: [
                        _MetricData(
                          'Usuários',
                          userValue(userMetrics.total),
                          Icons.group_outlined,
                          usersReady
                              ? '${userMetrics.approved} aprovados'
                              : 'REST Admin',
                        ),
                        _MetricData(
                          'Ativos hoje',
                          userValue(userMetrics.dau),
                          Icons.bolt_outlined,
                          usersReady ? 'WAU ${userMetrics.wau}' : 'Últimas 24h',
                        ),
                        _MetricData(
                          'Premium',
                          userValue(userMetrics.premium),
                          Icons.workspace_premium_outlined,
                          usersReady
                              ? '${userMetrics.trial} em trial'
                              : 'Assinaturas',
                        ),
                        _MetricData(
                          'Receita mês',
                          _metric(
                            adminData,
                            'revenueMonth',
                            prefix: r'US$ ',
                          ),
                          Icons.payments_outlined,
                          'Bruta consolidada',
                        ),
                        _MetricData(
                          'Erros críticos',
                          criticalRaw?.toString() ?? '—',
                          Icons.error_outline_rounded,
                          'Últimas 24 horas',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _UsageCard(
                            metrics: userMetrics,
                            ready: usersReady,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SystemHealthCard(data: errorData),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AttentionCard(
                      userMetrics: userMetrics,
                      usersReady: usersReady,
                      usersError: dashboardError != null,
                      usersErrorText: dashboardError?.toString(),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  static String _metric(
    Map<String, dynamic> data,
    String key, {
    String prefix = '',
  }) {
    final value = data[key];
    if (value == null) return '—';
    return '$prefix$value';
  }
}

class _AdminUsersRestLoader {
  static Future<Map<String, dynamic>> callAdminCallable(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final safeName = functionName.trim();
    if (safeName.isEmpty) {
      throw StateError('Cloud Function administrativa ausente.');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Sessão Firebase ausente.');
    }

    var token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      token = await user.getIdToken(true);
    }
    if (token == null || token.isEmpty) {
      throw StateError('Token Firebase vazio.');
    }

    final uri = Uri.parse(
      'https://us-central1-medcases-pro.cloudfunctions.net/$safeName',
    );

    Future<http.Response> send(String legacyBearer) async {
      // GPT_UNLOCK_FORCE_REFRESH_ID_TOKEN_V1
      final bearer = (await user.getIdToken(true))?.trim() ?? '';
      if (bearer.isEmpty) {
        throw StateError('Token Firebase vazio.');
      }

      return http.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $bearer',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'data': data}),
      );
    }

    var response = await send(token);

    if (response.statusCode == 401 || response.statusCode == 403) {
      final refreshed = await user.getIdToken(true);
      if (refreshed != null && refreshed.isNotEmpty) {
        response = await send(refreshed);
      }
    }

    Map<String, dynamic> decoded = const <String, dynamic>{};
    try {
      final raw = jsonDecode(response.body);
      if (raw is Map<String, dynamic>) decoded = raw;
    } catch (_) {}

    if (response.statusCode != 200) {
      final error = decoded['error'];
      var message = 'Cloud Function HTTP ${response.statusCode}.';
      if (error is Map) {
        final candidate = error['message']?.toString().trim() ?? '';
        if (candidate.isNotEmpty) message = candidate;
      }
      throw StateError(message);
    }

    final result = decoded['result'] ?? decoded['data'];
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }

    return const <String, dynamic>{};
  }

  static String _auditActorUid = '';
  static String _auditActorEmail = '';

  static void setAuditActor({
    required String uid,
    required String email,
  }) {
    _auditActorUid = uid.trim();
    _auditActorEmail = email.trim();
  }

  static Map<String, dynamic> _withAuditMetadata(
    Map<String, dynamic> values,
  ) {
    if (_auditActorUid.isEmpty) {
      return Map<String, dynamic>.from(values);
    }
    return <String, dynamic>{
      ...values,
      '_adminAuditBy': _auditActorUid,
      '_adminAuditEmail': _auditActorEmail,
      '_adminAuditAt': DateTime.now().toUtc(),
    };
  }

  static const _documentsBase =
      'https://firestore.googleapis.com/v1/projects/medcases-pro/databases/(default)/documents';

  static Future<String> _resolveToken() async {
    // 1) Preserve the canonical REST-token cache path used by the existing app.
    try {
      final cached = await AuthService.getAdminToken();
      if (cached.isNotEmpty) return cached;
    } catch (_) {
      // Continue to the dedicated Admin V2 SDK-session fallback.
    }

    // 2) Admin V2 logs in through FirebaseAuth SDK. Therefore a valid SDK
    // session may exist even when AuthService's separate REST cache is empty.
    final sdkUser = FirebaseAuth.instance.currentUser;
    if (sdkUser == null) {
      throw StateError(
        'Sessão Admin ausente. Faça login novamente.',
      );
    }

    try {
      final sdkToken = await sdkUser.getIdToken();
      if (sdkToken != null && sdkToken.isNotEmpty) {
        return sdkToken;
      }

      final refreshed = await sdkUser.getIdToken(true);
      if (refreshed != null && refreshed.isNotEmpty) {
        return refreshed;
      }
    } catch (error) {
      throw StateError(
        'Não foi possível obter o token da sessão Admin: $error',
      );
    }

    throw StateError(
      'Token Admin indisponível. Faça login novamente.',
    );
  }

  static Future<http.Response> _authorizedGet(
    Uri uri,
    String token,
  ) async {
    var response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    // One SDK refresh retry is allowed only for an authentication failure.
    if (response.statusCode == 401) {
      final sdkUser = FirebaseAuth.instance.currentUser;
      if (sdkUser != null) {
        final refreshed = await sdkUser.getIdToken(true);
        if (refreshed != null && refreshed.isNotEmpty) {
          response = await http.get(
            uri,
            headers: {'Authorization': 'Bearer $refreshed'},
          );
        }
      }
    }

    return response;
  }

  static Future<List<Map<String, dynamic>>> load() async {
    final token = await _resolveToken();
    final rows = <Map<String, dynamic>>[];
    String? pageToken;

    do {
      final query = <String, String>{'pageSize': '1000'};
      if (pageToken != null && pageToken.isNotEmpty) {
        query['pageToken'] = pageToken;
      }

      final uri = Uri.parse(
        '$_documentsBase/users',
      ).replace(queryParameters: query);

      final response = await _authorizedGet(uri, token);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError(
          'Acesso Admin/Master negado ao listar usuários '
          '(HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode != 200) {
        throw StateError(
          'Falha ao carregar usuários (HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Resposta Firestore inválida.');
      }

      final documents = decoded['documents'];
      if (documents is List) {
        for (final raw in documents) {
          if (raw is! Map) continue;
          final fields = raw['fields'];
          if (fields is! Map) {
            rows.add(const <String, dynamic>{});
            continue;
          }

          final decodedFields = _decodeFields(
            Map<String, dynamic>.from(fields),
          );
          final documentName = raw['name']?.toString() ?? '';
          if ((decodedFields['uid']?.toString().trim().isEmpty ?? true) &&
              documentName.isNotEmpty) {
            decodedFields['uid'] = documentName.split('/').last;
          }
          rows.add(decodedFields);
        }
      }

      final next = decoded['nextPageToken']?.toString().trim() ?? '';
      pageToken = next.isEmpty ? null : next;
    } while (pageToken != null);

    return rows;
  }

  static Future<Map<String, dynamic>> loadDocument(
    String documentPath,
  ) async {
    final token = await _resolveToken();
    final uri = Uri.parse('$_documentsBase/$documentPath');

    final response = await _authorizedGet(uri, token);

    // Aggregated documents are optional until their dedicated phases.
    // Missing docs / rules not yet enabled must not block real user KPIs.
    if (response.statusCode == 403 || response.statusCode == 404) {
      return const <String, dynamic>{};
    }

    if (response.statusCode == 401) {
      throw StateError(
        'Sessão Admin expirada ao carregar métricas.',
      );
    }

    if (response.statusCode != 200) {
      return const <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return const <String, dynamic>{};
    }

    final fields = decoded['fields'];
    if (fields is! Map) {
      return const <String, dynamic>{};
    }

    return _decodeFields(
      Map<String, dynamic>.from(fields),
    );
  }

  static Future<void> patchUserFields(
    String uid,
    Map<String, dynamic> values,
  ) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      throw StateError('UID do usuário ausente.');
    }
    if (values.isEmpty) return;

    final token = await _resolveToken();
    final uri = Uri.parse(
      '$_documentsBase/users/${Uri.encodeComponent(safeUid)}',
    ).replace(
      queryParameters: <String, dynamic>{
        'updateMask.fieldPaths': _withAuditMetadata(
          values,
        ).keys.toList(growable: false),
      },
    );

    final auditedValues = _withAuditMetadata(values);
    final body = jsonEncode({
      'fields': auditedValues.map(
        (key, value) => MapEntry(key, _encodeValue(value)),
      ),
    });

    var response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 401) {
      final refreshed =
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (refreshed != null && refreshed.isNotEmpty) {
        response = await http.patch(
          uri,
          headers: {
            'Authorization': 'Bearer $refreshed',
            'Content-Type': 'application/json',
          },
          body: body,
        );
      }
    }

    if (response.statusCode != 200) {
      throw StateError(
        'Falha ao atualizar usuário (HTTP ${response.statusCode}).',
      );
    }
  }

  static Future<void> deleteUserDocument(String uid) async {
    final safeUid = uid.trim();
    if (safeUid.isEmpty) {
      throw StateError('UID do usuário ausente.');
    }

    if (_auditActorUid.isNotEmpty) {
      await patchUserFields(
        safeUid,
        const <String, dynamic>{'_adminAuditDelete': true},
      );
    }

    final token = await _resolveToken();
    final uri = Uri.parse(
      '$_documentsBase/users/${Uri.encodeComponent(safeUid)}',
    );

    var response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      final refreshed =
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (refreshed != null && refreshed.isNotEmpty) {
        response = await http.delete(
          uri,
          headers: {'Authorization': 'Bearer $refreshed'},
        );
      }
    }

    if (response.statusCode != 200) {
      throw StateError(
        'Falha ao excluir documento do usuário '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  static Map<String, dynamic> _encodeValue(dynamic value) {
    if (value == null) return const {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    return {'stringValue': value.toString()};
  }

  static Future<List<Map<String, dynamic>>> listCollection(
    String collectionPath, {
    int pageSize = 1000,
  }) async {
    final safePath = collectionPath.trim();
    if (safePath.isEmpty) {
      throw StateError('Coleção administrativa ausente.');
    }

    final token = await _resolveToken();
    final rows = <Map<String, dynamic>>[];
    String? pageToken;

    do {
      final query = <String, String>{
        'pageSize': '${pageSize.clamp(1, 1000)}',
      };
      if (pageToken != null && pageToken.isNotEmpty) {
        query['pageToken'] = pageToken;
      }

      final uri = Uri.parse(
        '$_documentsBase/$safePath',
      ).replace(queryParameters: query);

      final response = await _authorizedGet(uri, token);

      if (response.statusCode == 404) {
        return rows;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError(
          'Acesso administrativo negado a $safePath '
          '(HTTP ${response.statusCode}).',
        );
      }

      if (response.statusCode != 200) {
        throw StateError(
          'Falha ao carregar $safePath '
          '(HTTP ${response.statusCode}).',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Resposta Firestore administrativa inválida.',
        );
      }

      final documents = decoded['documents'];
      if (documents is List) {
        for (final raw in documents) {
          if (raw is! Map) continue;
          final fields = raw['fields'];
          if (fields is! Map) continue;

          final row = _decodeFields(
            Map<String, dynamic>.from(fields),
          );
          final name = raw['name']?.toString() ?? '';
          if (name.isNotEmpty) {
            row['_documentId'] = name.split('/').last;
          }
          rows.add(row);
        }
      }

      final next = decoded['nextPageToken']?.toString().trim() ?? '';
      pageToken = next.isEmpty ? null : next;
    } while (pageToken != null);

    return rows;
  }

  static Future<String> createCollectionDocument(
    String collectionPath,
    Map<String, dynamic> values,
  ) async {
    final safePath = collectionPath.trim();
    if (safePath.isEmpty) {
      throw StateError('Coleção administrativa ausente.');
    }

    var token = await _resolveToken();
    final uri = Uri.parse('$_documentsBase/$safePath');
    final body = jsonEncode(<String, dynamic>{
      'fields': <String, dynamic>{
        for (final entry in _withAuditMetadata(values).entries)
          entry.key: _encodeValue(entry.value),
      },
    });

    Future<http.Response> send(String bearer) {
      return http.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $bearer',
          'Content-Type': 'application/json',
        },
        body: body,
      );
    }

    var response = await send(token);

    if (response.statusCode == 401) {
      final refreshed =
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (refreshed != null && refreshed.isNotEmpty) {
        token = refreshed;
        response = await send(token);
      }
    }

    if (response.statusCode != 200) {
      throw StateError(
        'Falha ao criar documento em $safePath '
        '(HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final name = decoded['name']?.toString().trim() ?? '';
      if (name.isNotEmpty) return name.split('/').last;
    }

    return '';
  }

  static Future<void> deleteDocument(String documentPath) async {
    final safePath = documentPath.trim();
    if (safePath.isEmpty) {
      throw StateError('Caminho do documento ausente.');
    }

    if (_auditActorUid.isNotEmpty) {
      await patchDocumentFields(
        safePath,
        const <String, dynamic>{'_adminAuditDelete': true},
      );
    }

    final token = await _resolveToken();
    final uri = Uri.parse('$_documentsBase/$safePath');

    var response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 401) {
      final refreshed =
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (refreshed != null && refreshed.isNotEmpty) {
        response = await http.delete(
          uri,
          headers: {'Authorization': 'Bearer $refreshed'},
        );
      }
    }

    if (response.statusCode != 200) {
      throw StateError(
        'Falha ao excluir documento '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  static Future<void> patchDocumentFields(
    String documentPath,
    Map<String, dynamic> values,
  ) async {
    final safePath = documentPath.trim();
    if (safePath.isEmpty) {
      throw StateError('Caminho do documento ausente.');
    }
    if (values.isEmpty) return;

    final token = await _resolveToken();
    final uri = Uri.parse('$_documentsBase/$safePath').replace(
      queryParameters: <String, dynamic>{
        'updateMask.fieldPaths': _withAuditMetadata(
          values,
        ).keys.toList(growable: false),
      },
    );

    final auditedValues = _withAuditMetadata(values);
    final body = jsonEncode({
      'fields': auditedValues.map(
        (key, value) => MapEntry(key, _encodeValue(value)),
      ),
    });

    var response = await http.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 401) {
      final refreshed =
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (refreshed != null && refreshed.isNotEmpty) {
        response = await http.patch(
          uri,
          headers: {
            'Authorization': 'Bearer $refreshed',
            'Content-Type': 'application/json',
          },
          body: body,
        );
      }
    }

    if (response.statusCode != 200) {
      throw StateError(
        'Falha ao atualizar configuração '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  static Map<String, dynamic> _decodeFields(
    Map<String, dynamic> fields,
  ) {
    return fields.map(
      (key, value) => MapEntry(key, _decodeValue(value)),
    );
  }

  static dynamic _decodeValue(dynamic raw) {
    if (raw is! Map) return null;
    final value = Map<String, dynamic>.from(raw);

    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];

    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue'].toString());
    }

    if (value.containsKey('doubleValue')) {
      final rawDouble = value['doubleValue'];
      if (rawDouble is num) return rawDouble.toDouble();
      return double.tryParse(rawDouble.toString());
    }

    if (value.containsKey('timestampValue')) {
      return DateTime.tryParse(value['timestampValue'].toString());
    }

    final array = value['arrayValue'];
    if (array is Map) {
      final values = array['values'];
      if (values is List) {
        return values.map(_decodeValue).toList(growable: false);
      }
      return const <dynamic>[];
    }

    final map = value['mapValue'];
    if (map is Map) {
      final nestedFields = map['fields'];
      if (nestedFields is Map) {
        return _decodeFields(
          Map<String, dynamic>.from(nestedFields),
        );
      }
      return const <String, dynamic>{};
    }

    return value.values.isEmpty ? null : value.values.first;
  }
}

class _AdminUserMetrics {
  const _AdminUserMetrics({
    required this.total,
    required this.approved,
    required this.pending,
    required this.blocked,
    required this.dau,
    required this.wau,
    required this.mau,
    required this.premium,
    required this.trial,
    required this.new7d,
  });

  const _AdminUserMetrics.empty()
      : total = 0,
        approved = 0,
        pending = 0,
        blocked = 0,
        dau = 0,
        wau = 0,
        mau = 0,
        premium = 0,
        trial = 0,
        new7d = 0;

  final int total;
  final int approved;
  final int pending;
  final int blocked;
  final int dau;
  final int wau;
  final int mau;
  final int premium;
  final int trial;
  final int new7d;

  factory _AdminUserMetrics.fromRows(
    List<Map<String, dynamic>>? rows,
  ) {
    if (rows == null) return const _AdminUserMetrics.empty();

    final now = DateTime.now();
    final dayAgo = now.subtract(const Duration(hours: 24));
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));

    var approved = 0;
    var pending = 0;
    var blocked = 0;
    var dau = 0;
    var wau = 0;
    var mau = 0;
    var premium = 0;
    var trial = 0;
    var new7d = 0;

    for (final data in rows) {
      final status = _normalized(data['status']);
      final plan = _normalized(data['plan']);
      final subscription = _normalized(data['subscriptionStatus']);
      final lastSeenAt = _asDate(data['lastSeenAt']);
      final createdAt = _asDate(data['createdAt']);

      if (status == 'approved') approved++;
      if (status == 'pending') pending++;
      if (status == 'blocked') blocked++;

      if (lastSeenAt != null) {
        if (!lastSeenAt.isBefore(dayAgo)) dau++;
        if (!lastSeenAt.isBefore(weekAgo)) wau++;
        if (!lastSeenAt.isBefore(monthAgo)) mau++;
      }

      final hasPremiumPlan =
          plan == 'premium' || plan == 'pro' || plan == 'paid';
      final hasActiveSubscription = subscription == 'active' ||
          subscription == 'premium' ||
          subscription == 'paid';
      if (hasPremiumPlan || hasActiveSubscription) premium++;
      if (subscription == 'trial') trial++;

      if (createdAt != null && !createdAt.isBefore(weekAgo)) new7d++;
    }

    return _AdminUserMetrics(
      total: rows.length,
      approved: approved,
      pending: pending,
      blocked: blocked,
      dau: dau,
      wau: wau,
      mau: mau,
      premium: premium,
      trial: trial,
      new7d: new7d,
    );
  }

  static String _normalized(dynamic value) =>
      value?.toString().trim().toLowerCase() ?? '';

  static DateTime? _asDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }
}

class _LiveSourcePill extends StatelessWidget {
  const _LiveSourcePill({
    required this.loading,
    required this.error,
    this.onTap,
  });

  final bool loading;
  final bool error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = error
        ? 'Falha de leitura'
        : loading
            ? 'Carregando'
            : 'Atualizado';
    final icon = error
        ? Icons.refresh_rounded
        : loading
            ? Icons.circle
            : Icons.check_circle_outline_rounded;
    final iconSize = error || !loading ? 13.0 : 7.0;
    final foreground =
        error ? const Color(0xFFB42318) : const Color(0xFF176B54);
    final background =
        error ? const Color(0xFFFFEFED) : const Color(0xFFEAF7F2);
    final border = error ? const Color(0xFFF3C0BA) : const Color(0xFFB9E6D3);

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: foreground),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.caption);

  final String label;
  final String value;
  final IconData icon;
  final String caption;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cards});

  final List<_MetricData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 760
            ? 5
            : width >= 520
                ? 2
                : 1;
        final gap = 10.0;
        final cardWidth = (width - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: _MetricCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(data.icon, size: 16, color: const Color(0xFF52606D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF52606D),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF87919C),
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.metrics, required this.ready});

  final _AdminUserMetrics metrics;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    String value(int number) => ready ? '$number' : '—';

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: 198,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Uso do MedCases',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              const Text(
                'Atividade calculada por lastSeenAt',
                style: TextStyle(color: Color(0xFF87919C), fontSize: 10.5),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                      child:
                          _MiniStat(label: 'DAU', value: value(metrics.dau))),
                  Expanded(
                      child:
                          _MiniStat(label: 'WAU', value: value(metrics.wau))),
                  Expanded(
                      child:
                          _MiniStat(label: 'MAU', value: value(metrics.mau))),
                  Expanded(
                    child: _MiniStat(
                      label: 'Novos 7d',
                      value: value(metrics.new7d),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _CompactStatus(
                      label: 'Pendentes',
                      value: value(metrics.pending),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactStatus(
                      label: 'Bloqueados',
                      value: value(metrics.blocked),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactStatus extends StatelessWidget {
  const _CompactStatus({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7EBEF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF68727D),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  const _SystemHealthCard({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final critical = data['critical24h'] ?? '—';
    final total = data['total24h'] ?? '—';
    final affected = data['affectedUsers24h'] ?? '—';

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          height: 198,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saúde do sistema',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _HealthRow(
                label: 'Firebase / Auth',
                value: data['authStatus']?.toString() ?? 'Sem telemetria',
              ),
              _HealthRow(
                label: 'IA',
                value: data['aiStatus']?.toString() ?? 'Sem telemetria',
              ),
              _HealthRow(
                label: 'Áudio / Transcrição',
                value: data['audioStatus']?.toString() ?? 'Sem telemetria',
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Erros 24h',
                      value: '$total',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'Críticos',
                      value: '$critical',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      label: 'Usuários',
                      value: '$affected',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF68727D),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF87919C), fontSize: 10),
        ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.userMetrics,
    required this.usersReady,
    required this.usersError,
    required this.usersErrorText,
  });

  final _AdminUserMetrics userMetrics;
  final bool usersReady;
  final bool usersError;
  final String? usersErrorText;

  @override
  Widget build(BuildContext context) {
    final message = usersError
        ? 'Falha ao ler usuários via REST Admin. '
            '${usersErrorText ?? 'Use Atualizar para tentar novamente.'}'
        : usersReady && userMetrics.pending > 0
            ? '${userMetrics.pending} usuário(s) aguardando revisão administrativa.'
            : 'Nenhum alerta operacional de usuários neste momento. Consulte Auditoria para incidentes, notificações e falhas de campanhas.';

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            const Icon(Icons.notifications_active_outlined, size: 19),
            const SizedBox(width: 10),
            const Text(
              'Requer atenção',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF68727D),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCostsSection extends StatefulWidget {
  const _AiCostsSection({required this.currentAdmin});

  final UserModel currentAdmin;

  @override
  State<_AiCostsSection> createState() => _AiCostsSectionState();
}

class _AiCostsSectionState extends State<_AiCostsSection> {
  late Future<_AiCostsSnapshot> _future;
  final _gptUnlockCode = TextEditingController();

  bool _savingFallback = false;
  bool _savingGpt = false;
  String? _actionError;
  String? _actionSuccess;

  bool get _allowed => widget.currentAdmin.isMaster;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _gptUnlockCode.dispose();
    super.dispose();
  }

  Future<_AiCostsSnapshot> _load() async {
    final docs = await Future.wait<Map<String, dynamic>>([
      _AdminUsersRestLoader.loadDocument('app_config/global'),
      _AdminUsersRestLoader.loadDocument('app_config/paid_budget'),
      _AdminUsersRestLoader.loadDocument('admin_ai_metrics/realtime'),
      _AdminUsersRestLoader.loadDocument('app_config/ai_control'),
    ]);

    return _AiCostsSnapshot(
      appConfig: docs[0],
      paidBudget: docs[1],
      metrics: docs[2],
      aiControl: docs[3],
    );
  }

  void _reload() {
    if (!mounted || !_allowed) return;
    setState(() {
      _actionError = null;
      _actionSuccess = null;
      _future = _load();
    });
  }

  Future<void> _setPaidFallback(bool enabled) async {
    if (!_allowed || _savingFallback) return;

    setState(() {
      _savingFallback = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      await _AdminUsersRestLoader.patchDocumentFields(
        'app_config/global',
        <String, dynamic>{'geminiPaidEnabled': enabled},
      );

      if (!mounted) return;
      setState(() {
        _savingFallback = false;
        _actionSuccess = enabled
            ? 'Fallback Gemini pago ativado.'
            : 'Fallback Gemini pago desativado.';
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingFallback = false;
        _actionError = error.toString();
      });
    }
  }

  Future<void> _setGptEnabled(bool enabled) async {
    if (!_allowed || _savingGpt) return;

    final code = _gptUnlockCode.text.trim();

    if (enabled && code.isEmpty) {
      setState(() {
        _actionError =
            'Informe o código de liberação GPT para ativar o provedor.';
        _actionSuccess = null;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              enabled ? 'Liberar GPT/OpenAI?' : 'Desativar GPT/OpenAI?',
            ),
            content: Text(
              enabled
                  ? 'O código será validado exclusivamente no backend e '
                      'não será salvo no navegador nem no Firestore.'
                  : 'O GPT será marcado como indisponível no controle '
                      'operacional.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(enabled ? 'Liberar GPT' : 'Desativar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _savingGpt = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      await _AdminUsersRestLoader.callAdminCallable(
        'adminSetGptOperationalState',
        <String, dynamic>{
          'enabled': enabled,
          if (enabled) 'code': code,
        },
      );

      _gptUnlockCode.clear();

      if (!mounted) return;
      setState(() {
        _savingGpt = false;
        _actionSuccess = enabled
            ? 'GPT/OpenAI liberado pelo backend.'
            : 'GPT/OpenAI desativado.';
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingGpt = false;
        _actionError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) {
      return const _SectionScaffold(
        title: 'IA & Custos',
        subtitle: 'Tokens, modelos, roteamento e custos operacionais de IA.',
        child: _Panel(
          child: Padding(
            padding: EdgeInsets.all(34),
            child: Column(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 38,
                  color: Color(0xFF68727D),
                ),
                SizedBox(height: 12),
                Text(
                  'Área exclusiva do Master',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Controles de provedores e custos críticos não ficam '
                  'disponíveis para Admin ou Supervisor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF68727D),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<_AiCostsSnapshot>(
      future: _future,
      builder: (context, snap) {
        final data = snap.data ?? const _AiCostsSnapshot.empty();
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = _actionError ?? snap.error?.toString();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'IA & Custos',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'GPT/OpenAI + Gemini · chamadas, tokens, custos e operação.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _AiCostsStatusPill(
                  loading: loading,
                  error: error != null,
                  onTap: loading ? null : _reload,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _AiCostsNotice(
              icon: Icons.security_rounded,
              title: 'Segredos permanecem no backend',
              body: 'Nenhuma chave de provedor é carregada, exibida ou '
                  'gravada pelo Admin V2. O código GPT é validado por '
                  'Cloud Function contra Firebase Secret e nunca é persistido.',
            ),
            if (_actionSuccess != null) ...[
              const SizedBox(height: 10),
              _AiCostsNotice(
                icon: Icons.check_circle_outline_rounded,
                title: 'Operação concluída',
                body: _actionSuccess!,
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              _AiCostsNotice(
                icon: Icons.error_outline_rounded,
                title: 'Falha de leitura ou atualização',
                body: error,
                danger: true,
              ),
            ],
            const SizedBox(height: 12),
            _AiCostsMetricsGrid(data: data),
            const SizedBox(height: 12),
            _AiProviderGrid(
              data: data,
              gptUnlockCode: _gptUnlockCode,
              savingGpt: _savingGpt,
              savingGemini: _savingFallback,
              onGptChanged: _setGptEnabled,
              onGeminiFallbackChanged: _setPaidFallback,
            ),
            const SizedBox(height: 12),
            _AiCostsOperationalSources(data: data),
          ],
        );
      },
    );
  }
}

class _AiCostsSnapshot {
  const _AiCostsSnapshot({
    required this.appConfig,
    required this.paidBudget,
    required this.metrics,
    required this.aiControl,
  });

  const _AiCostsSnapshot.empty()
      : appConfig = const <String, dynamic>{},
        paidBudget = const <String, dynamic>{},
        metrics = const <String, dynamic>{},
        aiControl = const <String, dynamic>{};

  final Map<String, dynamic> appConfig;
  final Map<String, dynamic> paidBudget;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> aiControl;

  bool get paidFallbackEnabled => appConfig['geminiPaidEnabled'] == true;
  bool get gptEnabled => aiControl['gptEnabled'] == true;
  bool get gptUnlockVerified => aiControl['gptUnlockVerified'] == true;
  String get gptVerifiedAt =>
      aiControl['gptUnlockVerifiedAt']?.toString().trim() ?? '';

  int get paidDailyCount {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final counterDate = paidBudget['dailyDate']?.toString() ?? '';
    if (counterDate.isNotEmpty && counterDate != today) return 0;
    return _intFrom(
      paidBudget,
      const ['dailyCount', 'requestsToday', 'paidRequestsToday'],
    );
  }

  double? get estimatedPaidCostUsd => _doubleFrom(
        paidBudget,
        const [
          'estimatedPaidCostUsd',
          'estimatedCostUsd',
          'costUsd',
        ],
      );

  Map<String, dynamic> _provider(String provider) {
    final providers = metrics['providers'];
    if (providers is Map) {
      final raw = providers[provider];
      if (raw is Map) return Map<String, dynamic>.from(raw);
    }

    final raw = metrics[provider];
    if (raw is Map) return Map<String, dynamic>.from(raw);

    return const <String, dynamic>{};
  }

  _AiProviderSnapshot get openAi => _AiProviderSnapshot(
        provider: 'OpenAI / GPT',
        operational: gptEnabled,
        data: _provider('openai'),
        root: metrics,
        prefix: 'openai',
      );

  _AiProviderSnapshot get gemini => _AiProviderSnapshot(
        provider: 'Gemini',
        operational: true,
        data: _provider('gemini'),
        root: metrics,
        prefix: 'gemini',
      );

  int? get requests24h => _nullableIntFrom(
        metrics,
        const ['requests24h', 'requests_24h', 'totalRequests24h'],
      );

  int? get inputTokens24h => _nullableIntFrom(
        metrics,
        const ['inputTokens24h', 'input_tokens_24h', 'promptTokens24h'],
      );

  int? get outputTokens24h => _nullableIntFrom(
        metrics,
        const [
          'outputTokens24h',
          'output_tokens_24h',
          'completionTokens24h',
        ],
      );

  int? get totalTokens24h {
    final explicit = _nullableIntFrom(
      metrics,
      const ['totalTokens24h', 'tokens24h', 'total_tokens_24h'],
    );
    if (explicit != null) return explicit;
    if (inputTokens24h == null && outputTokens24h == null) return null;
    return (inputTokens24h ?? 0) + (outputTokens24h ?? 0);
  }

  double? get costTodayUsd => _doubleFrom(
        metrics,
        const ['costTodayUsd', 'cost24hUsd', 'estimatedCostTodayUsd'],
      );

  double? get estimatedMonthCostUsd => _doubleFrom(
        metrics,
        const [
          'estimatedMonthCostUsd',
          'estimatedCostUsdMonth',
          'costUsdMonth',
          'monthCostUsd',
        ],
      );

  int? get errors24h => _nullableIntFrom(
        metrics,
        const ['errors24h', 'errors_24h', 'failedRequests24h'],
      );

  double? get errorRate24h => _doubleFrom(
        metrics,
        const ['errorRate24h', 'error_rate_24h'],
      );

  String get primaryModel => _firstText(
        <Map<String, dynamic>>[metrics, appConfig],
        const ['primaryModel', 'activePrimaryModel', 'aiPrimaryModel'],
      );

  String get fallbackModel => _firstText(
        <Map<String, dynamic>>[metrics, appConfig],
        const ['fallbackModel', 'activeFallbackModel', 'aiFallbackModel'],
      );

  String get routingMode => _firstText(
        <Map<String, dynamic>>[metrics, appConfig],
        const ['routingMode', 'aiRoutingMode', 'routerMode'],
      );

  static int _intFrom(
    Map<String, dynamic> source,
    List<String> keys,
  ) =>
      _nullableIntFrom(source, keys) ?? 0;

  static int? _nullableIntFrom(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static double? _doubleFrom(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String _firstText(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final source in sources) {
      for (final key in keys) {
        final value = source[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
    }
    return '';
  }
}

class _AiProviderSnapshot {
  const _AiProviderSnapshot({
    required this.provider,
    required this.operational,
    required this.data,
    required this.root,
    required this.prefix,
  });

  final String provider;
  final bool operational;
  final Map<String, dynamic> data;
  final Map<String, dynamic> root;
  final String prefix;

  dynamic _value(List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key)) return data[key];
      final flat =
          '${prefix}${key.substring(0, 1).toUpperCase()}${key.substring(1)}';
      if (root.containsKey(flat)) return root[flat];
    }
    return null;
  }

  int? _int(List<String> keys) {
    final value = _value(keys);
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _double(List<String> keys) {
    final value = _value(keys);
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _string(List<String> keys) => _value(keys)?.toString().trim() ?? '';

  int? get requests24h => _int(const ['requests24h', 'calls24h', 'requests']);

  int? get inputTokens24h =>
      _int(const ['inputTokens24h', 'inputTokens', 'promptTokens']);

  int? get outputTokens24h =>
      _int(const ['outputTokens24h', 'outputTokens', 'completionTokens']);

  int? get totalTokens24h {
    final explicit = _int(const ['totalTokens24h', 'tokens24h', 'totalTokens']);
    if (explicit != null) return explicit;
    if (inputTokens24h == null && outputTokens24h == null) return null;
    return (inputTokens24h ?? 0) + (outputTokens24h ?? 0);
  }

  double? get costTodayUsd =>
      _double(const ['costTodayUsd', 'cost24hUsd', 'dailyCostUsd']);

  double? get costMonthUsd =>
      _double(const ['costMonthUsd', 'monthCostUsd', 'estimatedMonthCostUsd']);

  int? get errors24h =>
      _int(const ['errors24h', 'failedRequests24h', 'errors']);

  double? get avgLatencyMs =>
      _double(const ['avgLatencyMs', 'averageLatencyMs', 'latencyMs']);

  String get model => _string(const ['model', 'activeModel', 'modelName']);
}

class _AiCostsStatusPill extends StatelessWidget {
  const _AiCostsStatusPill({
    required this.loading,
    required this.error,
    required this.onTap,
  });

  final bool loading;
  final bool error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = loading
        ? 'Carregando'
        : error
            ? 'Recarregar'
            : 'Atualizado';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: error ? const Color(0xFFFFF4F2) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: error ? const Color(0xFFF5C2BA) : const Color(0xFFB7E8D3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: error ? const Color(0xFFB42318) : const Color(0xFF087A55),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AiCostsNotice extends StatelessWidget {
  const _AiCostsNotice({
    required this.icon,
    required this.title,
    required this.body,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 19,
              color: danger ? const Color(0xFFB42318) : const Color(0xFF087A55),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Color(0xFF68727D),
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCostsMetricsGrid extends StatelessWidget {
  const _AiCostsMetricsGrid({required this.data});

  final _AiCostsSnapshot data;

  @override
  Widget build(BuildContext context) {
    String usd(double? value) =>
        value == null ? '—' : '\$${value.toStringAsFixed(4)}';

    final cards = <_AiCostsMetricData>[
      _AiCostsMetricData(
        title: 'Requisições 24h',
        value: data.requests24h?.toString() ?? '—',
        subtitle: 'GPT + Gemini',
        icon: Icons.bolt_outlined,
      ),
      _AiCostsMetricData(
        title: 'Tokens 24h',
        value: data.totalTokens24h?.toString() ?? '—',
        subtitle:
            '${data.inputTokens24h ?? '—'} entrada · ${data.outputTokens24h ?? '—'} saída',
        icon: Icons.data_usage_rounded,
      ),
      _AiCostsMetricData(
        title: 'Custo 24h',
        value: usd(data.costTodayUsd),
        subtitle: 'Estimativa consolidada',
        icon: Icons.today_outlined,
      ),
      _AiCostsMetricData(
        title: 'Custo IA mês',
        value: usd(data.estimatedMonthCostUsd),
        subtitle: 'Estimativa consolidada',
        icon: Icons.attach_money_rounded,
      ),
      _AiCostsMetricData(
        title: 'Erros 24h',
        value: data.errors24h?.toString() ?? '—',
        subtitle: data.errorRate24h == null
            ? 'Taxa indisponível'
            : '${(data.errorRate24h! * 100).toStringAsFixed(2)}%',
        icon: Icons.error_outline_rounded,
      ),
      _AiCostsMetricData(
        title: 'Proxy pago hoje',
        value: data.paidDailyCount.toString(),
        subtitle: data.estimatedPaidCostUsd == null
            ? 'Chamadas registradas'
            : '\$${data.estimatedPaidCostUsd!.toStringAsFixed(6)} estimado',
        icon: Icons.alt_route_rounded,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 3
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _AiCostsMetricCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _AiCostsMetricData {
  const _AiCostsMetricData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
}

class _AiCostsMetricCard extends StatelessWidget {
  const _AiCostsMetricCard({required this.data});

  final _AiCostsMetricData data;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  data.icon,
                  size: 16,
                  color: const Color(0xFF53606D),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    data.title,
                    style: const TextStyle(
                      color: Color(0xFF53606D),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              data.value,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              data.subtitle,
              style: const TextStyle(
                color: Color(0xFF87919C),
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiProviderGrid extends StatelessWidget {
  const _AiProviderGrid({
    required this.data,
    required this.gptUnlockCode,
    required this.savingGpt,
    required this.savingGemini,
    required this.onGptChanged,
    required this.onGeminiFallbackChanged,
  });

  final _AiCostsSnapshot data;
  final TextEditingController gptUnlockCode;
  final bool savingGpt;
  final bool savingGemini;
  final ValueChanged<bool> onGptChanged;
  final ValueChanged<bool> onGeminiFallbackChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 900;
        final width =
            split ? (constraints.maxWidth - 10) / 2 : constraints.maxWidth;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _AiGptProviderCard(
                provider: data.openAi,
                enabled: data.gptEnabled,
                verified: data.gptUnlockVerified,
                verifiedAt: data.gptVerifiedAt,
                controller: gptUnlockCode,
                saving: savingGpt,
                onChanged: onGptChanged,
              ),
            ),
            SizedBox(
              width: width,
              child: _AiGeminiProviderCard(
                provider: data.gemini,
                paidFallbackEnabled: data.paidFallbackEnabled,
                paidDailyCount: data.paidDailyCount,
                paidCost: data.estimatedPaidCostUsd,
                saving: savingGemini,
                onChanged: onGeminiFallbackChanged,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AiGptProviderCard extends StatelessWidget {
  const _AiGptProviderCard({
    required this.provider,
    required this.enabled,
    required this.verified,
    required this.verifiedAt,
    required this.controller,
    required this.saving,
    required this.onChanged,
  });

  final _AiProviderSnapshot provider;
  final bool enabled;
  final bool verified;
  final String verifiedAt;
  final TextEditingController controller;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AiProviderHeader(
              title: 'OpenAI / GPT',
              subtitle: provider.model.isEmpty
                  ? 'Sem uso registrado nas últimas 24h'
                  : '${provider.model} · observado 24h',
              enabled: enabled,
              trailing: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch.adaptive(
                      value: enabled,
                      onChanged: onChanged,
                    ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              enabled: !saving,
              decoration: InputDecoration(
                labelText: 'Código de liberação GPT',
                hintText: enabled
                    ? 'Digite apenas para nova validação'
                    : 'Obrigatório para liberar',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(
                  Icons.password_rounded,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              enabled && verified
                  ? 'Código validado no backend${verifiedAt.isEmpty ? '' : ' · $verifiedAt'}'
                  : 'O código nunca é salvo ou retornado ao navegador.',
              style: TextStyle(
                color: enabled && verified
                    ? const Color(0xFF087A55)
                    : const Color(0xFF68727D),
                fontSize: 10.5,
                fontWeight:
                    enabled && verified ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const Divider(height: 24),
            _AiProviderMetrics(provider: provider),
          ],
        ),
      ),
    );
  }
}

class _AiGeminiProviderCard extends StatelessWidget {
  const _AiGeminiProviderCard({
    required this.provider,
    required this.paidFallbackEnabled,
    required this.paidDailyCount,
    required this.paidCost,
    required this.saving,
    required this.onChanged,
  });

  final _AiProviderSnapshot provider;
  final bool paidFallbackEnabled;
  final int paidDailyCount;
  final double? paidCost;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AiProviderHeader(
              title: 'Gemini',
              subtitle: provider.model.isEmpty
                  ? 'Sem uso registrado nas últimas 24h'
                  : '${provider.model} · observado 24h',
              enabled: true,
              trailing: const _AiProviderStatusBadge(
                label: 'CONECTADO',
                active: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fallback pago',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Flag operacional existente em app_config/global.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (saving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: paidFallbackEnabled,
                    onChanged: onChanged,
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              '$paidDailyCount chamada(s) no proxy pago hoje'
              '${paidCost == null ? '' : ' · \$${paidCost!.toStringAsFixed(6)}'}',
              style: const TextStyle(
                color: Color(0xFF68727D),
                fontSize: 10.5,
              ),
            ),
            const Divider(height: 24),
            _AiProviderMetrics(provider: provider),
          ],
        ),
      ),
    );
  }
}

class _AiProviderHeader extends StatelessWidget {
  const _AiProviderHeader({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFECFDF5) : const Color(0xFFF3F5F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 19,
            color: enabled ? const Color(0xFF087A55) : const Color(0xFF68727D),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF68727D),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }
}

class _AiProviderStatusBadge extends StatelessWidget {
  const _AiProviderStatusBadge({
    required this.label,
    required this.active,
  });

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? const Color(0xFFECFDF5) : const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF087A55) : const Color(0xFF68727D),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AiProviderMetrics extends StatelessWidget {
  const _AiProviderMetrics({required this.provider});

  final _AiProviderSnapshot provider;

  @override
  Widget build(BuildContext context) {
    String value(dynamic v) => v == null ? '—' : v.toString();
    String usd(double? v) => v == null ? '—' : '\$${v.toStringAsFixed(4)}';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AiCostsInlineValue(
                label: 'Chamadas 24h',
                value: value(provider.requests24h),
              ),
            ),
            Expanded(
              child: _AiCostsInlineValue(
                label: 'Tokens 24h',
                value: value(provider.totalTokens24h),
              ),
            ),
            Expanded(
              child: _AiCostsInlineValue(
                label: 'Erros 24h',
                value: value(provider.errors24h),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _AiCostsInlineValue(
                label: 'Tokens entrada',
                value: value(provider.inputTokens24h),
              ),
            ),
            Expanded(
              child: _AiCostsInlineValue(
                label: 'Tokens saída',
                value: value(provider.outputTokens24h),
              ),
            ),
            Expanded(
              child: _AiCostsInlineValue(
                label: 'Latência média',
                value: provider.avgLatencyMs == null
                    ? '—'
                    : '${provider.avgLatencyMs!.toStringAsFixed(0)} ms',
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: _AiCostsInlineValue(
                label: 'Custo 24h',
                value: usd(provider.costTodayUsd),
              ),
            ),
            Expanded(
              child: _AiCostsInlineValue(
                label: 'Custo mês',
                value: usd(provider.costMonthUsd),
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _AiCostsInlineValue extends StatelessWidget {
  const _AiCostsInlineValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF87919C),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ADMIN_V2_AI_COSTS_SEMANTIC_CONSISTENCY_V1
class _AiCostsOperationalSources extends StatelessWidget {
  const _AiCostsOperationalSources({required this.data});

  final _AiCostsSnapshot data;

  @override
  Widget build(BuildContext context) {
    final primary = data.primaryModel.isEmpty ? 'Backend' : data.primaryModel;
    final fallback =
        data.fallbackModel.isEmpty ? 'Backend' : data.fallbackModel;
    final routing = data.routingMode.isEmpty
        ? 'Backend'
        : data.routingMode == 'observed_provider_usage'
            ? 'Uso observado nas últimas 24h'
            : data.routingMode;

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contrato operacional',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            const _AiCostsSourceRow(
              label: 'Configuração',
              value: 'app_config/global',
            ),
            const _AiCostsSourceRow(
              label: 'Controle GPT',
              value: 'app_config/ai_control',
            ),
            const _AiCostsSourceRow(
              label: 'Budget pago',
              value: 'app_config/paid_budget',
            ),
            const _AiCostsSourceRow(
              label: 'Telemetria operacional',
              value: 'admin_ai_metrics/realtime',
            ),
            const Divider(height: 22, color: Color(0xFFE8ECF0)),
            _AiCostsSourceRow(label: 'Modelo mais usado (24h)', value: primary),
            _AiCostsSourceRow(label: 'Outro modelo observado (24h)', value: fallback),
            _AiCostsSourceRow(label: 'Base da leitura', value: routing),
            const SizedBox(height: 6),
            const Text(
              'Os modelos exibidos refletem uso observado nas últimas 24h. '
              'Esta tela não altera a lógica clínica nem troca modelos. '
              'Ela controla disponibilidade operacional e apresenta '
              'telemetria produzida pelo backend.',
              style: TextStyle(
                color: Color(0xFF68727D),
                fontSize: 10.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCostsSourceRow extends StatelessWidget {
  const _AiCostsSourceRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 142,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF53606D),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF68727D),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _UsersV2Filter { all, pending, approved, blocked, staff }

enum _UsersV2Action {
  approve,
  block,
  unblock,
  promoteSupervisor,
  promoteAdmin,
  demoteUser,
  delete,
}

class _UsersManagementSection extends StatefulWidget {
  const _UsersManagementSection({required this.currentAdmin});

  final UserModel currentAdmin;

  @override
  State<_UsersManagementSection> createState() =>
      _UsersManagementSectionState();
}

class _UsersManagementSectionState extends State<_UsersManagementSection> {
  late Future<List<Map<String, dynamic>>> _future;
  final _search = TextEditingController();
  _UsersV2Filter _filter = _UsersV2Filter.all;
  String? _busyUid;
  String? _localError;

  bool get _isMaster => widget.currentAdmin.isMaster;

  @override
  void initState() {
    super.initState();
    _future = _AdminUsersRestLoader.load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _localError = null;
      _future = _AdminUsersRestLoader.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        final visible = _filtered(rows);
        final counts = _UsersV2Counts.fromRows(rows);
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = _localError ?? snap.error?.toString();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usuários',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Cadastro, acesso, status e permissões administrativas.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _LiveSourcePill(
                  loading: loading,
                  error: error != null,
                  onTap: loading ? null : _reload,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _UsersV2Summary(counts: counts),
            const SizedBox(height: 12),
            _UsersV2Toolbar(
              controller: _search,
              filter: _filter,
              onFilter: (value) => setState(() => _filter = value),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (loading && rows.isEmpty)
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (error != null && rows.isEmpty)
              _Panel(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 34,
                        color: Color(0xFFB42318),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
            else if (visible.isEmpty)
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(34),
                  child: Center(
                    child: Text(
                      'Nenhum usuário corresponde aos filtros.',
                      style: TextStyle(color: Color(0xFF68727D)),
                    ),
                  ),
                ),
              )
            else
              _Panel(
                child: Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      _UsersV2Row(
                        row: visible[i],
                        currentAdmin: widget.currentAdmin,
                        isMaster: _isMaster,
                        busy: _busyUid == visible[i]['uid']?.toString().trim(),
                        onAction: (action) => _runAction(visible[i], action),
                      ),
                      if (i != visible.length - 1)
                        const Divider(
                          height: 1,
                          color: Color(0xFFE8ECF0),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _filtered(
    List<Map<String, dynamic>> rows,
  ) {
    final q = _search.text.trim().toLowerCase();

    bool filterOk(Map<String, dynamic> row) {
      final status = _norm(row['status']);
      final role = _norm(row['role']);
      return switch (_filter) {
        _UsersV2Filter.all => true,
        _UsersV2Filter.pending => status == 'pending',
        _UsersV2Filter.approved => status == 'approved',
        _UsersV2Filter.blocked => status == 'blocked',
        _UsersV2Filter.staff =>
          role == 'master' || role == 'admin' || role == 'supervisor',
      };
    }

    bool searchOk(Map<String, dynamic> row) {
      if (q.isEmpty) return true;
      final text = [
        row['displayName'],
        row['email'],
        row['profession'],
        row['institution'],
        row['professionalCategory'],
        row['uid'],
      ].map((v) => v?.toString().toLowerCase() ?? '').join(' ');
      return text.contains(q);
    }

    return rows
        .where((row) => filterOk(row) && searchOk(row))
        .toList(growable: false);
  }

  Future<void> _runAction(
    Map<String, dynamic> row,
    _UsersV2Action action,
  ) async {
    final uid = row['uid']?.toString().trim() ?? '';
    final role = _norm(row['role']);

    if (uid.isEmpty || _busyUid != null) return;

    final isSelf = uid == widget.currentAdmin.uid;
    final isTargetMaster = role == 'master';

    if (isSelf || isTargetMaster) {
      _snack(
        isSelf
            ? 'Sua própria conta não pode ser alterada aqui.'
            : 'A conta Master não pode ser alterada.',
        error: true,
      );
      return;
    }

    if ((action == _UsersV2Action.promoteAdmin ||
            action == _UsersV2Action.demoteUser) &&
        !_isMaster) {
      _snack(
        'Esta alteração de permissão é exclusiva do Master.',
        error: true,
      );
      return;
    }

    if (!await _confirm(row, action) || !mounted) return;

    setState(() {
      _busyUid = uid;
      _localError = null;
    });

    try {
      switch (action) {
        case _UsersV2Action.approve:
        case _UsersV2Action.unblock:
          await _AdminUsersRestLoader.patchUserFields(
            uid,
            {
              'status': 'approved',
              'approvedAt': DateTime.now(),
              'approvedBy': widget.currentAdmin.uid,
            },
          );
        case _UsersV2Action.block:
          await _AdminUsersRestLoader.patchUserFields(
            uid,
            {'status': 'blocked'},
          );
        case _UsersV2Action.promoteSupervisor:
          await _AdminUsersRestLoader.patchUserFields(
            uid,
            {'role': 'supervisor'},
          );
        case _UsersV2Action.promoteAdmin:
          await _AdminUsersRestLoader.patchUserFields(
            uid,
            {'role': 'admin'},
          );
        case _UsersV2Action.demoteUser:
          await _AdminUsersRestLoader.patchUserFields(
            uid,
            {'role': 'user'},
          );
        case _UsersV2Action.delete:
          await _AdminUsersRestLoader.deleteUserDocument(uid);
      }

      if (!mounted) return;
      _snack('Usuário atualizado.');
      setState(() {
        _busyUid = null;
        _future = _AdminUsersRestLoader.load();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busyUid = null;
        _localError = e.toString();
      });
      _snack('Falha ao atualizar usuário: $e', error: true);
    }
  }

  Future<bool> _confirm(
    Map<String, dynamic> row,
    _UsersV2Action action,
  ) async {
    final name = _name(row);
    final copy = switch (action) {
      _UsersV2Action.approve => (
          'Aprovar $name?',
          'O usuário passará a ter status aprovado.'
        ),
      _UsersV2Action.unblock => (
          'Desbloquear $name?',
          'O usuário voltará ao status aprovado.'
        ),
      _UsersV2Action.block => (
          'Bloquear $name?',
          'O usuário perderá acesso imediatamente.'
        ),
      _UsersV2Action.promoteSupervisor => (
          'Promover $name a Supervisor?',
          'O usuário receberá permissões de Supervisor.',
        ),
      _UsersV2Action.promoteAdmin => (
          'Promover $name a Admin?',
          'O usuário terá acesso administrativo.',
        ),
      _UsersV2Action.demoteUser => (
          'Rebaixar $name?',
          'O usuário voltará ao role comum.',
        ),
      _UsersV2Action.delete => (
          'Excluir $name?',
          'O documento será removido permanentemente do Firestore.',
        ),
    };

    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(copy.$1),
            content: Text(copy.$2),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  action == _UsersV2Action.delete ? 'Excluir' : 'Confirmar',
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor:
            error ? const Color(0xFFB42318) : const Color(0xFF176B54),
      ),
    );
  }

  static String _norm(dynamic value) =>
      value?.toString().trim().toLowerCase() ?? '';

  static String _name(Map<String, dynamic> row) {
    final name = row['displayName']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final email = row['email']?.toString().trim() ?? '';
    return email.isNotEmpty ? email : 'usuário';
  }
}

class _UsersV2Counts {
  const _UsersV2Counts({
    required this.total,
    required this.pending,
    required this.approved,
    required this.blocked,
    required this.staff,
  });

  final int total;
  final int pending;
  final int approved;
  final int blocked;
  final int staff;

  factory _UsersV2Counts.fromRows(List<Map<String, dynamic>> rows) {
    var pending = 0;
    var approved = 0;
    var blocked = 0;
    var staff = 0;

    for (final row in rows) {
      final status = row['status']?.toString().trim().toLowerCase() ?? '';
      final role = row['role']?.toString().trim().toLowerCase() ?? '';
      if (status == 'pending') pending++;
      if (status == 'approved') approved++;
      if (status == 'blocked') blocked++;
      if (role == 'master' || role == 'admin' || role == 'supervisor') {
        staff++;
      }
    }

    return _UsersV2Counts(
      total: rows.length,
      pending: pending,
      approved: approved,
      blocked: blocked,
      staff: staff,
    );
  }
}

class _UsersV2Summary extends StatelessWidget {
  const _UsersV2Summary({required this.counts});

  final _UsersV2Counts counts;

  @override
  Widget build(BuildContext context) {
    final data = <(String, int)>[
      ('Total', counts.total),
      ('Pendentes', counts.pending),
      ('Aprovados', counts.approved),
      ('Bloqueados', counts.blocked),
      ('Equipe', counts.staff),
    ];

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Wrap(
          spacing: 22,
          runSpacing: 8,
          children: [
            for (final item in data)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${item.$2}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.$1,
                    style: const TextStyle(
                      color: Color(0xFF68727D),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _UsersV2Toolbar extends StatelessWidget {
  const _UsersV2Toolbar({
    required this.controller,
    required this.filter,
    required this.onFilter,
    required this.onChanged,
  });

  final TextEditingController controller;
  final _UsersV2Filter filter;
  final ValueChanged<_UsersV2Filter> onFilter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = <(_UsersV2Filter, String)>[
      (_UsersV2Filter.all, 'Todos'),
      (_UsersV2Filter.pending, 'Pendentes'),
      (_UsersV2Filter.approved, 'Aprovados'),
      (_UsersV2Filter.blocked, 'Bloqueados'),
      (_UsersV2Filter.staff, 'Equipe'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 310,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar nome, e-mail, profissão ou UID',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        for (final item in options)
          ChoiceChip(
            label: Text(item.$2),
            selected: filter == item.$1,
            onSelected: (_) => onFilter(item.$1),
          ),
      ],
    );
  }
}

class _UsersV2Row extends StatelessWidget {
  const _UsersV2Row({
    required this.row,
    required this.currentAdmin,
    required this.isMaster,
    required this.busy,
    required this.onAction,
  });

  final Map<String, dynamic> row;
  final UserModel currentAdmin;
  final bool isMaster;
  final bool busy;
  final ValueChanged<_UsersV2Action> onAction;

  @override
  Widget build(BuildContext context) {
    final uid = row['uid']?.toString().trim() ?? '';
    final name = row['displayName']?.toString().trim() ?? '';
    final email = row['email']?.toString().trim() ?? '';
    final profession = row['profession']?.toString().trim() ?? '';
    final status = row['status']?.toString().trim().toLowerCase() ?? 'pending';
    final role = row['role']?.toString().trim().toLowerCase() ?? 'user';
    final plan = row['plan']?.toString().trim().toLowerCase() ?? 'free';

    final isSelf = uid.isNotEmpty && uid == currentAdmin.uid;
    final isTargetMaster = role == 'master';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? email : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (name.isNotEmpty) email,
                    if (profession.isNotEmpty) profession,
                  ].where((v) => v.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF87919C),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              status.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF52606D),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              role.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Color(0xFF52606D),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              plan.toUpperCase(),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF68727D),
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<_UsersV2Action>(
                    enabled: !isSelf && !isTargetMaster,
                    tooltip: 'Ações',
                    onSelected: onAction,
                    itemBuilder: (_) => _menu(
                      status: status,
                      role: role,
                      isMaster: isMaster,
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: isSelf || isTargetMaster
                          ? const Color(0xFFC5CBD2)
                          : const Color(0xFF52606D),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static List<PopupMenuEntry<_UsersV2Action>> _menu({
    required String status,
    required String role,
    required bool isMaster,
  }) {
    final result = <PopupMenuEntry<_UsersV2Action>>[];

    if (status == 'pending') {
      result.add(
        const PopupMenuItem(
          value: _UsersV2Action.approve,
          child: Text('Aprovar'),
        ),
      );
    } else if (status == 'blocked') {
      result.add(
        const PopupMenuItem(
          value: _UsersV2Action.unblock,
          child: Text('Desbloquear'),
        ),
      );
    } else {
      result.add(
        const PopupMenuItem(
          value: _UsersV2Action.block,
          child: Text('Bloquear'),
        ),
      );
    }

    if (role == 'user') {
      result.add(
        const PopupMenuItem(
          value: _UsersV2Action.promoteSupervisor,
          child: Text('Promover a Supervisor'),
        ),
      );
      if (isMaster) {
        result.add(
          const PopupMenuItem(
            value: _UsersV2Action.promoteAdmin,
            child: Text('Promover a Admin'),
          ),
        );
      }
    } else if (isMaster && (role == 'admin' || role == 'supervisor')) {
      result.add(
        const PopupMenuItem(
          value: _UsersV2Action.demoteUser,
          child: Text('Rebaixar para Usuário'),
        ),
      );
    }

    result.add(const PopupMenuDivider());
    result.add(
      const PopupMenuItem(
        value: _UsersV2Action.delete,
        child: Text(
          'Excluir usuário',
          style: TextStyle(color: Color(0xFFB42318)),
        ),
      ),
    );
    return result;
  }
}

class _SubscriptionsRevenueSection extends StatefulWidget {
  const _SubscriptionsRevenueSection({required this.allowed});

  final bool allowed;

  @override
  State<_SubscriptionsRevenueSection> createState() =>
      _SubscriptionsRevenueSectionState();
}

class _SubscriptionsRevenueSectionState
    extends State<_SubscriptionsRevenueSection> {
  late Future<List<Map<String, dynamic>>> _usersFuture;
  late Future<Map<String, dynamic>> _billingFuture;

  @override
  void initState() {
    super.initState();
    _prime();
  }

  void _prime() {
    _usersFuture = _AdminUsersRestLoader.load();
    _billingFuture =
        _AdminUsersRestLoader.loadDocument('admin_billing_metrics/realtime');
  }

  void _reload() {
    if (!mounted) return;
    setState(_prime);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.allowed) {
      return const _SectionScaffold(
        title: 'Assinaturas & Receita',
        subtitle:
            'Apple, Google Play, Stripe, trials, MRR, churn e receita líquida.',
        child: _EmptyState(
          title: 'Área exclusiva do Master',
          body:
              'Dados financeiros e de billing não ficam disponíveis para Admin comum.',
        ),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _usersFuture,
      builder: (context, usersSnap) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _billingFuture,
          builder: (context, billingSnap) {
            final usersReady = usersSnap.hasData && !usersSnap.hasError;
            final userMetrics = _BillingUserMetrics.fromRows(usersSnap.data);
            final billing = billingSnap.data ?? const <String, dynamic>{};
            final billingConnected = billing.isNotEmpty;
            final loading =
                usersSnap.connectionState == ConnectionState.waiting ||
                    billingSnap.connectionState == ConnectionState.waiting;
            final error = usersSnap.error ?? billingSnap.error;

            final currency =
                billing['currency']?.toString().trim().toUpperCase();
            final effectiveCurrency =
                currency == null || currency.isEmpty ? 'USD' : currency;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assinaturas & Receita',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Apple App Store, Google Play e Stripe consolidados pelo backend.',
                            style: TextStyle(
                              color: Color(0xFF68727D),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _LiveSourcePill(
                      loading: loading,
                      error: error != null,
                      onTap: loading ? null : _reload,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _BillingLaunchBanner(
                  activePaid: usersReady ? userMetrics.activePaid : null,
                  trial: usersReady ? userMetrics.trial : null,
                  billingConnected: billingConnected,
                ),
                const SizedBox(height: 12),
                _MetricGrid(
                  cards: [
                    _MetricData(
                      'Premium ativos',
                      usersReady ? '${userMetrics.activePaid}' : '—',
                      Icons.workspace_premium_outlined,
                      'Perfis com entitlement pago',
                    ),
                    _MetricData(
                      'Trial',
                      usersReady ? '${userMetrics.trial}' : '—',
                      Icons.hourglass_top_rounded,
                      usersReady
                          ? '${userMetrics.trialEnding7d} vencem em 7d'
                          : 'Período de teste',
                    ),
                    _MetricData(
                      'MRR',
                      _BillingFormat.money(
                        billing['mrr'],
                        currency: effectiveCurrency,
                      ),
                      Icons.show_chart_rounded,
                      'Receita recorrente mensal',
                    ),
                    _MetricData(
                      'Receita bruta',
                      _BillingFormat.money(
                        billing['grossRevenueMonth'],
                        currency: effectiveCurrency,
                      ),
                      Icons.account_balance_wallet_outlined,
                      'Mês atual',
                    ),
                    _MetricData(
                      'Receita líquida',
                      _BillingFormat.money(
                        billing['netRevenueMonth'],
                        currency: effectiveCurrency,
                      ),
                      Icons.savings_outlined,
                      'Após taxas informadas',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 860;
                    final cards = [
                      _BillingProviderCard(
                        title: 'Apple App Store',
                        icon: Icons.apple,
                        active: usersReady ? userMetrics.appleActive : null,
                        revenue: _BillingFormat.money(
                          billing['appleGrossRevenueMonth'],
                          currency: effectiveCurrency,
                        ),
                        billingConnected: billingConnected,
                      ),
                      _BillingProviderCard(
                        title: 'Google Play',
                        icon: Icons.android_rounded,
                        active: usersReady ? userMetrics.googleActive : null,
                        revenue: _BillingFormat.money(
                          billing['googleGrossRevenueMonth'],
                          currency: effectiveCurrency,
                        ),
                        billingConnected: billingConnected,
                      ),
                      _BillingProviderCard(
                        title: 'Stripe Web',
                        icon: Icons.language_rounded,
                        active: usersReady ? userMetrics.stripeActive : null,
                        revenue: _BillingFormat.money(
                          billing['stripeGrossRevenueMonth'],
                          currency: effectiveCurrency,
                        ),
                        billingConnected: billingConnected,
                      ),
                    ];

                    if (stacked) {
                      return Column(
                        children: [
                          for (var i = 0; i < cards.length; i++) ...[
                            cards[i],
                            if (i != cards.length - 1)
                              const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 10),
                        Expanded(child: cards[2]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 900;
                    final lifecycle = _BillingLifecycleCard(
                      canceled: usersReady ? userMetrics.canceled : null,
                      expired: usersReady ? userMetrics.expired : null,
                      pastDue: usersReady ? userMetrics.pastDue : null,
                      unknownProvider:
                          usersReady ? userMetrics.unknownProvider : null,
                      churn: _BillingFormat.percent(billing['churnPct']),
                      refunds: _BillingFormat.money(
                        billing['refundsMonth'],
                        currency: effectiveCurrency,
                      ),
                    );
                    const contract = _BillingContractCard();

                    if (stacked) {
                      return Column(
                        children: [
                          lifecycle,
                          const SizedBox(height: 10),
                          contract,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: lifecycle),
                        const SizedBox(width: 10),
                        const Expanded(child: contract),
                      ],
                    );
                  },
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  _Panel(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFFB42318),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Falha de leitura administrativa: $error',
                              style: const TextStyle(
                                color: Color(0xFF68727D),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _BillingUserMetrics {
  const _BillingUserMetrics({
    required this.activePaid,
    required this.trial,
    required this.trialEnding7d,
    required this.canceled,
    required this.expired,
    required this.pastDue,
    required this.appleActive,
    required this.googleActive,
    required this.stripeActive,
    required this.unknownProvider,
  });

  const _BillingUserMetrics.empty()
      : activePaid = 0,
        trial = 0,
        trialEnding7d = 0,
        canceled = 0,
        expired = 0,
        pastDue = 0,
        appleActive = 0,
        googleActive = 0,
        stripeActive = 0,
        unknownProvider = 0;

  final int activePaid;
  final int trial;
  final int trialEnding7d;
  final int canceled;
  final int expired;
  final int pastDue;
  final int appleActive;
  final int googleActive;
  final int stripeActive;
  final int unknownProvider;

  factory _BillingUserMetrics.fromRows(
    List<Map<String, dynamic>>? rows,
  ) {
    if (rows == null) return const _BillingUserMetrics.empty();

    final now = DateTime.now();
    final sevenDays = now.add(const Duration(days: 7));

    var activePaid = 0;
    var trial = 0;
    var trialEnding7d = 0;
    var canceled = 0;
    var expired = 0;
    var pastDue = 0;
    var appleActive = 0;
    var googleActive = 0;
    var stripeActive = 0;
    var unknownProvider = 0;

    for (final data in rows) {
      final plan = _normalized(data['plan']);
      final status = _normalized(data['subscriptionStatus']);
      final provider = _firstNormalized(
        data,
        const [
          'subscriptionProvider',
          'billingProvider',
          'store',
          'provider',
        ],
      );

      final paidByPlan = plan == 'premium' || plan == 'pro' || plan == 'paid';
      final paidByStatus =
          status == 'active' || status == 'premium' || status == 'paid';
      final isActivePaid = paidByPlan || paidByStatus;

      if (isActivePaid) {
        activePaid++;
        if (_isApple(provider)) {
          appleActive++;
        } else if (_isGoogle(provider)) {
          googleActive++;
        } else if (_isStripe(provider)) {
          stripeActive++;
        } else {
          unknownProvider++;
        }
      }

      if (status == 'trial') {
        trial++;
        final endAt = _firstDate(
          data,
          const [
            'trialEndAt',
            'trialEndsAt',
            'trialExpiresAt',
            'subscriptionExpiresAt',
          ],
        );
        if (endAt != null &&
            !endAt.isBefore(now) &&
            !endAt.isAfter(sevenDays)) {
          trialEnding7d++;
        }
      }

      if (status == 'canceled' ||
          status == 'cancelled' ||
          status == 'cancelado' ||
          status == 'cancelada') {
        canceled++;
      }

      if (status == 'expired' || status == 'expirado' || status == 'expirada') {
        expired++;
      }

      if (status == 'past_due' || status == 'pastdue' || status == 'past-due') {
        pastDue++;
      }
    }

    return _BillingUserMetrics(
      activePaid: activePaid,
      trial: trial,
      trialEnding7d: trialEnding7d,
      canceled: canceled,
      expired: expired,
      pastDue: pastDue,
      appleActive: appleActive,
      googleActive: googleActive,
      stripeActive: stripeActive,
      unknownProvider: unknownProvider,
    );
  }

  static String _normalized(dynamic value) =>
      value?.toString().trim().toLowerCase() ?? '';

  static String _firstNormalized(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = _normalized(data[key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static DateTime? _firstDate(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is DateTime) return value;
      if (value is Timestamp) return value.toDate();
      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static bool _isApple(String provider) =>
      provider == 'apple' ||
      provider == 'appstore' ||
      provider == 'app_store' ||
      provider == 'apple_app_store' ||
      provider == 'ios';

  static bool _isGoogle(String provider) =>
      provider == 'google' ||
      provider == 'googleplay' ||
      provider == 'google_play' ||
      provider == 'playstore' ||
      provider == 'play_store' ||
      provider == 'android';

  static bool _isStripe(String provider) =>
      provider == 'stripe' || provider == 'web';
}

class _BillingFormat {
  const _BillingFormat._();

  static String money(
    dynamic value, {
    required String currency,
  }) {
    final number = _asNumber(value);
    if (number == null) return '—';

    final normalizedCurrency =
        currency.trim().isEmpty ? 'USD' : currency.trim().toUpperCase();
    final rendered = number.toStringAsFixed(2).replaceAll('.', ',');
    return '$normalizedCurrency $rendered';
  }

  static String percent(dynamic value) {
    final number = _asNumber(value);
    if (number == null) return '—';
    return '${number.toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  static double? _asNumber(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class _BillingLaunchBanner extends StatelessWidget {
  const _BillingLaunchBanner({
    required this.activePaid,
    required this.trial,
    required this.billingConnected,
  });

  final int? activePaid;
  final int? trial;
  final bool billingConnected;

  @override
  Widget build(BuildContext context) {
    final preLaunch = (activePaid ?? 0) == 0 && !billingConnected;
    final title = preLaunch
        ? 'Pré-lançamento — sem assinantes pagos'
        : 'Billing preparado para operação';
    final body = preLaunch
        ? 'Hoje existem ${trial ?? 0} usuários em trial e nenhum Premium pago. '
            'O painel já lê os perfis e o agregador administrativo; quando o '
            'paywall começar a gerar eventos, receita e origem de cobrança '
            'passam a aparecer automaticamente.'
        : 'Os dados de assinatura e receita estão sendo consolidados pelas '
            'fontes administrativas disponíveis.';

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              preLaunch
                  ? Icons.rocket_launch_outlined
                  : Icons.verified_outlined,
              size: 20,
              color: const Color(0xFF176B54),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Color(0xFF68727D),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingProviderCard extends StatelessWidget {
  const _BillingProviderCard({
    required this.title,
    required this.icon,
    required this.active,
    required this.revenue,
    required this.billingConnected,
  });

  final String title;
  final IconData icon;
  final int? active;
  final String revenue;
  final bool billingConnected;

  @override
  Widget build(BuildContext context) {
    final status = (active ?? 0) > 0
        ? 'Com assinaturas ativas'
        : billingConnected
            ? 'Sem assinaturas ativas'
            : 'Aguardando eventos de billing';

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: const Color(0xFF52606D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              active == null ? '—' : '$active',
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'assinaturas ativas',
              style: TextStyle(
                color: Color(0xFF87919C),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                const Text(
                  'Receita mês',
                  style: TextStyle(
                    color: Color(0xFF68727D),
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  revenue,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: const TextStyle(
                color: Color(0xFF87919C),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingLifecycleCard extends StatelessWidget {
  const _BillingLifecycleCard({
    required this.canceled,
    required this.expired,
    required this.pastDue,
    required this.unknownProvider,
    required this.churn,
    required this.refunds,
  });

  final int? canceled;
  final int? expired;
  final int? pastDue;
  final int? unknownProvider;
  final String churn;
  final String refunds;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ciclo da assinatura',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _BillingLine(label: 'Cancelados', value: canceled),
            _BillingLine(label: 'Expirados', value: expired),
            _BillingLine(label: 'Pagamento pendente', value: pastDue),
            _BillingLine(
              label: 'Provider não identificado',
              value: unknownProvider,
            ),
            const Divider(height: 22, color: Color(0xFFE8ECF0)),
            _BillingTextLine(label: 'Churn', value: churn),
            _BillingTextLine(label: 'Reembolsos no mês', value: refunds),
          ],
        ),
      ),
    );
  }
}

class _BillingContractCard extends StatelessWidget {
  const _BillingContractCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Padding(
        padding: EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contrato de dados',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12),
            _BillingContractRow(
              title: 'Perfis',
              body: 'plan · subscriptionStatus · subscriptionProvider',
            ),
            _BillingContractRow(
              title: 'Agregador',
              body: 'admin_billing_metrics/realtime',
            ),
            _BillingContractRow(
              title: 'Canais',
              body: 'Apple App Store · Google Play · Stripe',
            ),
            _BillingContractRow(
              title: 'Segurança',
              body:
                  'Segredos e validação de compra permanecem no backend; nunca no navegador.',
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingContractRow extends StatelessWidget {
  const _BillingContractRow({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF52606D),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              body,
              style: const TextStyle(
                color: Color(0xFF68727D),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingLine extends StatelessWidget {
  const _BillingLine({
    required this.label,
    required this.value,
  });

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    return _BillingTextLine(
      label: label,
      value: value == null ? '—' : '$value',
    );
  }
}

class _BillingTextLine extends StatelessWidget {
  const _BillingTextLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF68727D),
                fontSize: 11,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditAlertsSection extends StatefulWidget {
  const _AuditAlertsSection({required this.currentAdmin});
  final UserModel currentAdmin;

  @override
  State<_AuditAlertsSection> createState() => _AuditAlertsSectionState();
}

class _AuditAlertsSectionState extends State<_AuditAlertsSection> {
  late Future<_AuditAlertsBundle> _future;
  final _search = TextEditingController();

  bool get _canReadAudit =>
      widget.currentAdmin.isAdmin || widget.currentAdmin.isMaster;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_AuditAlertsBundle> _load() async {
    final incidents =
        await _AdminUsersRestLoader.listCollection('admin_incidents');
    final notifications =
        await _AdminUsersRestLoader.listCollection('admin_notifications');
    final pushes =
        await _AdminUsersRestLoader.listCollection('global_push_campaigns');
    final emails =
        await _AdminUsersRestLoader.listCollection('email_campaigns');
    final maintenance =
        await _AdminUsersRestLoader.loadDocument('app_config/maintenance');

    var auditLogs = const <Map<String, dynamic>>[];
    String? auditUnavailable;

    if (_canReadAudit) {
      try {
        final loaded =
            await _AdminUsersRestLoader.listCollection('admin_audit_logs');
        loaded.sort((a, b) => _AuditData.dateOf(b['createdAt'])
            .compareTo(_AuditData.dateOf(a['createdAt'])));
        auditLogs = loaded.take(250).toList(growable: false);
      } catch (error) {
        auditUnavailable = error.toString();
      }
    } else {
      auditUnavailable = 'Audit Log restrito a Admin/Master.';
    }

    return _AuditAlertsBundle(
      incidents: incidents,
      notifications: notifications,
      pushes: pushes,
      emails: emails,
      maintenance: maintenance,
      auditLogs: auditLogs,
      auditUnavailable: auditUnavailable,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuditAlertsBundle>(
      future: _future,
      builder: (context, snap) {
        final bundle = snap.data ?? const _AuditAlertsBundle.empty();
        final loading = snap.connectionState == ConnectionState.waiting;
        final alerts = _AuditData.alertsFor(bundle, widget.currentAdmin.uid);
        final q = _search.text.trim().toLowerCase();
        final logs = bundle.auditLogs.where((row) {
          if (q.isEmpty) return true;
          return [
            _AuditData.text(row['action']),
            _AuditData.text(row['resourceType']),
            _AuditData.text(row['resourceId']),
            _AuditData.text(row['actorUid']),
            _AuditData.text(row['actorEmail']),
          ].join(' ').toLowerCase().contains(q);
        }).toList(growable: false);

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auditoria & Alertas',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Trilha administrativa imutável e alertas operacionais reais.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _LiveSourcePill(
                  loading: loading,
                  error: snap.hasError,
                  onTap:
                      loading ? null : () => setState(() => _future = _load()),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AuditAlertMetrics(
              alertCount: alerts.length,
              criticalCount:
                  alerts.where((a) => a.severity == 'critical').length,
              auditCount: bundle.auditLogs.length,
              backendReady: bundle.auditUnavailable == null,
            ),
            const SizedBox(height: 12),
            _Panel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Alertas operacionais',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Derivados de incidentes, notificações, campanhas e manutenção — sem nova collection de alerts.',
                      style:
                          TextStyle(color: Color(0xFF68727D), fontSize: 10.5),
                    ),
                    const SizedBox(height: 12),
                    if (alerts.isEmpty)
                      const Text(
                        'Nenhum alerta operacional ativo.',
                        style: TextStyle(
                          color: Color(0xFF087A55),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    else
                      for (final alert in alerts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AuditAlertRow(alert: alert),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _Panel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Audit Log',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ),
                        _AuditImmutableBadge(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cloud Functions escrevem. O browser possui leitura, nunca escrita.',
                      style:
                          TextStyle(color: Color(0xFF68727D), fontSize: 10.5),
                    ),
                    if (bundle.auditUnavailable != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Audit Log ainda não disponível neste ambiente: '
                        '${bundle.auditUnavailable}',
                        style: const TextStyle(
                          color: Color(0xFF9A6700),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        hintText: 'Buscar ação, recurso, ator ou ID',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (logs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Nenhum registro de auditoria disponível.',
                          style:
                              TextStyle(color: Color(0xFF68727D), fontSize: 11),
                        ),
                      )
                    else
                      for (final row in logs) _AuditLogRow(row: row),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AuditAlertsBundle {
  const _AuditAlertsBundle({
    required this.incidents,
    required this.notifications,
    required this.pushes,
    required this.emails,
    required this.maintenance,
    required this.auditLogs,
    required this.auditUnavailable,
  });

  const _AuditAlertsBundle.empty()
      : incidents = const <Map<String, dynamic>>[],
        notifications = const <Map<String, dynamic>>[],
        pushes = const <Map<String, dynamic>>[],
        emails = const <Map<String, dynamic>>[],
        maintenance = const <String, dynamic>{},
        auditLogs = const <Map<String, dynamic>>[],
        auditUnavailable = null;

  final List<Map<String, dynamic>> incidents;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> pushes;
  final List<Map<String, dynamic>> emails;
  final Map<String, dynamic> maintenance;
  final List<Map<String, dynamic>> auditLogs;
  final String? auditUnavailable;
}


// ADMIN_V2_ACTIONABLE_ALERTS_NOTIFICATION_IDENTITY_V1
class _AuditAlert {
  const _AuditAlert({
    required this.severity,
    required this.title,
    required this.source,
    required this.sourceLabel,
    required this.detail,
    required this.resolution,
  });

  final String severity;
  final String title;
  final String source;
  final String sourceLabel;
  final String detail;
  final String resolution;
}

class _AuditAlertMetrics extends StatelessWidget {
  const _AuditAlertMetrics({
    required this.alertCount,
    required this.criticalCount,
    required this.auditCount,
    required this.backendReady,
  });

  final int alertCount;
  final int criticalCount;
  final int auditCount;
  final bool backendReady;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData('Alertas', '$alertCount', Icons.notifications_active_outlined,
          'Fontes reais'),
      _MetricData('Críticos', '$criticalCount', Icons.error_outline_rounded,
          'Ação imediata'),
      _MetricData('Audit Log', '$auditCount', Icons.fact_check_outlined,
          'Registros carregados'),
      _MetricData(
        'Backend',
        backendReady ? 'Ativo' : 'Pendente',
        Icons.verified_user_outlined,
        'Server-side audit',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: _MetricCard(data: card)),
          ],
        );
      },
    );
  }
}


class _AuditAlertRow extends StatelessWidget {
  const _AuditAlertRow({required this.alert});

  final _AuditAlert alert;

  @override
  Widget build(BuildContext context) {
    final critical = alert.severity == 'critical';
    final color =
        critical ? const Color(0xFFB42318) : const Color(0xFF9A6700);
    final background =
        critical ? const Color(0xFFFFF1F0) : const Color(0xFFFFF8E8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            critical
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        alert.title,
                        style: TextStyle(
                          color: color,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        critical ? 'CRÍTICO' : 'ATENÇÃO',
                        style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert.detail,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  alert.resolution,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Onde resolver: ${alert.sourceLabel}',
                  style: const TextStyle(
                    color: Color(0xFF68727D),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditImmutableBadge extends StatelessWidget {
  const _AuditImmutableBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          'SERVER-SIDE · IMUTÁVEL',
          style: TextStyle(
            color: Color(0xFF087A55),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final action = _AuditData.text(row['action'], fallback: 'admin.action');
    final resource = _AuditData.text(row['resourceType'], fallback: '—');
    final id = _AuditData.text(row['resourceId']);
    final actor = _AuditData.text(row['actorEmail']).isNotEmpty
        ? _AuditData.text(row['actorEmail'])
        : _AuditData.text(row['actorUid'], fallback: 'sistema');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 15, color: Color(0xFF52606D)),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              '$action · $resource${id.isEmpty ? '' : ' · $id'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              actor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF68727D), fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              _AuditData.dateLabel(row['createdAt']),
              textAlign: TextAlign.end,
              style: const TextStyle(color: Color(0xFF87919C), fontSize: 9.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditData {
  const _AuditData._();

  static String text(dynamic value, {String fallback = ''}) {
    final output = value?.toString().trim() ?? '';
    return output.isEmpty ? fallback : output;
  }

  static List<String> stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static DateTime dateOf(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String dateLabel(dynamic value) {
    final date = dateOf(value);
    if (date.millisecondsSinceEpoch == 0) return '—';
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }


  static List<_AuditAlert> alertsFor(
    _AuditAlertsBundle bundle,
    String adminUid,
  ) {
    final result = <_AuditAlert>[];

    final critical = bundle.incidents.where((row) {
      final severity = text(row['severity']).toLowerCase();
      final status = text(row['status']).toLowerCase();
      return (severity == 'critical' || severity == 'fatal') &&
          status != 'resolved';
    }).length;

    if (critical > 0) {
      result.add(_AuditAlert(
        severity: 'critical',
        title: '$critical incidente(s) crítico(s) aberto(s)',
        source: 'admin_incidents',
        sourceLabel: 'Erros > Críticos',
        detail:
            'Existem incidentes técnicos de prioridade máxima ainda não resolvidos.',
        resolution:
            'Como resolver: abra Erros, filtre por Críticos, revise os detalhes '
            'do incidente e altere o status para Investigando ou Resolvido.',
      ));
    }

    final unread = bundle.notifications.where((row) {
      return !stringList(row['readBy']).contains(adminUid);
    }).length;

    if (unread > 0) {
      result.add(_AuditAlert(
        severity: 'warning',
        title: '$unread notificação(ões) administrativa(s) aguardam revisão',
        source: 'admin_notifications',
        sourceLabel: 'Comunicação > Notificações',
        detail:
            'Isto não é uma falha do sistema. São avisos administrativos que '
            'ainda não foram marcados como lidos por este administrador.',
        resolution:
            'Como resolver: abra Comunicação > Notificações, revise cada item '
            'e use “Marcar lida” após conferir o cadastro ou aviso.',
      ));
    }

    final pushErrors = bundle.pushes
        .where((row) => text(row['status']).toLowerCase() == 'error')
        .length;

    if (pushErrors > 0) {
      result.add(_AuditAlert(
        severity: 'warning',
        title: '$pushErrors campanha(s) push com falha',
        source: 'global_push_campaigns',
        sourceLabel: 'Comunicação > Push global',
        detail:
            'Uma ou mais campanhas de push terminaram com status de erro.',
        resolution:
            'Como resolver: abra Comunicação > Push global e revise o Histórico '
            'de push para identificar a campanha e o status retornado.',
      ));
    }

    final emailErrors = bundle.emails
        .where((row) => text(row['status']).toLowerCase() == 'error')
        .length;

    if (emailErrors > 0) {
      result.add(_AuditAlert(
        severity: 'warning',
        title: '$emailErrors campanha(s) de e-mail com falha',
        source: 'email_campaigns',
        sourceLabel: 'Comunicação > E-mail',
        detail:
            'Uma ou mais campanhas de e-mail não concluíram o envio corretamente.',
        resolution:
            'Como resolver: abra Comunicação > E-mail e revise o Histórico de '
            'e-mail e a configuração EmailJS antes de reenviar.',
      ));
    }

    if (bundle.maintenance['enabled'] == true) {
      result.add(const _AuditAlert(
        severity: 'critical',
        title: 'Modo de manutenção ativo',
        source: 'app_config/maintenance',
        sourceLabel: 'Configurações > Sistema',
        detail:
            'O aplicativo está em modo de manutenção para usuários comuns.',
        resolution:
            'Como resolver: abra Configurações > Sistema. Se a manutenção não '
            'for intencional, desative o modo e salve o estado.',
      ));
    }

    return result;
  }
}

enum _SettingsPane {
  maintenance,
  appUpdates,
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({
    required this.currentAdmin,
  });

  final UserModel currentAdmin;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  late Future<_SettingsBundle> _future;

  final _maintenanceMessage = TextEditingController();

  final _updateVersion = TextEditingController();
  final _updateDate = TextEditingController();
  final _updateTitle = TextEditingController();
  final _updateItems = TextEditingController();

  _SettingsPane _pane = _SettingsPane.maintenance;
  bool _maintenanceEnabled = false;
  bool _updateActive = false;
  bool _seededMaintenance = false;
  bool _seededUpdate = false;
  bool _busy = false;
  String? _actionError;
  String? _actionSuccess;

  bool get _isMaster => widget.currentAdmin.isMaster;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _maintenanceMessage.dispose();
    _updateVersion.dispose();
    _updateDate.dispose();
    _updateTitle.dispose();
    _updateItems.dispose();
    super.dispose();
  }

  Future<_SettingsBundle> _load() async {
    final maintenance = await _AdminUsersRestLoader.loadDocument(
      'app_config/maintenance',
    );
    final appUpdate = await _AdminUsersRestLoader.loadDocument(
      'app_updates/current',
    );

    return _SettingsBundle(
      maintenance: maintenance,
      appUpdate: appUpdate,
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _seededMaintenance = false;
      _seededUpdate = false;
      _actionError = null;
      _actionSuccess = null;
      _future = _load();
    });
  }

  void _seed(_SettingsBundle bundle) {
    if (!_seededMaintenance) {
      _seededMaintenance = true;
      _maintenanceEnabled = bundle.maintenance['enabled'] == true;
      _maintenanceMessage.text =
          _SettingsData.text(bundle.maintenance['message']);
    }

    if (!_seededUpdate) {
      _seededUpdate = true;
      _updateActive = bundle.appUpdate['active'] == true;
      _updateVersion.text = _SettingsData.text(bundle.appUpdate['version']);
      _updateDate.text = _SettingsData.text(bundle.appUpdate['date']);
      _updateTitle.text = _SettingsData.text(bundle.appUpdate['title']);
      _updateItems.text = _SettingsData.stringList(
        bundle.appUpdate['items'],
      ).join('\n');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SettingsBundle>(
      future: _future,
      builder: (context, snap) {
        final bundle = snap.data ?? const _SettingsBundle.empty();
        final loading = snap.connectionState == ConnectionState.waiting;
        final readError = snap.error?.toString();

        if (snap.data != null) {
          _seed(bundle);
        }

        final error = _actionError ?? readError;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configurações',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Controles críticos do sistema e comunicação de versão.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _LiveSourcePill(
                  loading: loading,
                  error: error != null,
                  onTap: loading ? null : _reload,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SettingsStatusGrid(
              maintenanceEnabled: bundle.maintenance['enabled'] == true,
              updateActive: bundle.appUpdate['active'] == true,
              updateVersion: _SettingsData.text(bundle.appUpdate['version']),
              isMaster: _isMaster,
            ),
            const SizedBox(height: 12),
            _SettingsPanePicker(
              value: _pane,
              onChanged: (value) {
                setState(() => _pane = value);
              },
            ),
            const SizedBox(height: 10),
            if (!_isMaster)
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: Color(0xFF68727D),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esta aba é somente leitura para Admin e Supervisor. '
                          'Alterações críticas exigem Master.',
                          style: TextStyle(
                            color: Color(0xFF68727D),
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_actionSuccess != null) ...[
              const SizedBox(height: 10),
              _Panel(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _actionSuccess!,
                    style: const TextStyle(
                      color: Color(0xFF087A55),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              _Panel(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (loading && snap.data == null)
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              switch (_pane) {
                _SettingsPane.maintenance => _buildMaintenance(bundle),
                _SettingsPane.appUpdates => _buildAppUpdates(bundle),
              },
            const SizedBox(height: 12),
            const _SettingsOwnershipNotice(),
          ],
        );
      },
    );
  }

  Widget _buildMaintenance(_SettingsBundle bundle) {
    final lastUpdated = _SettingsData.text(bundle.maintenance['updatedAt']);
    final updatedBy = _SettingsData.text(bundle.maintenance['updatedBy']);

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _maintenanceEnabled
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 20,
                  color: _maintenanceEnabled
                      ? const Color(0xFFB7791F)
                      : const Color(0xFF087A55),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Modo de Manutenção',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _maintenanceEnabled
                            ? 'Sistema offline para usuários comuns.'
                            : 'Sistema online — acesso normal.',
                        style: TextStyle(
                          color: _maintenanceEnabled
                              ? const Color(0xFF9A6700)
                              : const Color(0xFF087A55),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _maintenanceEnabled,
                  onChanged: _isMaster && !_busy
                      ? (value) {
                          setState(
                            () => _maintenanceEnabled = value,
                          );
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _maintenanceMessage,
              enabled: _isMaster && !_busy,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mensagem para os usuários',
                hintText:
                    'Ex.: Estamos realizando uma atualização. Voltaremos em breve.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (lastUpdated.isNotEmpty || updatedBy.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                [
                  if (lastUpdated.isNotEmpty)
                    'Última atualização: $lastUpdated',
                  if (updatedBy.isNotEmpty) 'por $updatedBy',
                ].join(' · '),
                style: const TextStyle(
                  color: Color(0xFF87919C),
                  fontSize: 10,
                ),
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Administradores e Master continuam com acesso '
                    'durante a manutenção.',
                    style: TextStyle(
                      color: Color(0xFF68727D),
                      fontSize: 10.5,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isMaster && !_busy ? _saveMaintenance : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.save_outlined,
                          size: 16,
                        ),
                  label: const Text('Salvar estado'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppUpdates(_SettingsBundle bundle) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Color(0xFF315B96),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Novidades do App',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Conteúdo exibido no modal de novidades ao abrir o app.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _updateActive,
                  onChanged: _isMaster && !_busy
                      ? (value) {
                          setState(() => _updateActive = value);
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _updateVersion,
                    enabled: _isMaster && !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Versão',
                      hintText: '1.2.0',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _updateDate,
                    enabled: _isMaster && !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      hintText: '26/08/2026',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _updateTitle,
              enabled: _isMaster && !_busy,
              decoration: const InputDecoration(
                labelText: 'Título do aviso',
                hintText: 'Novidades da versão 1.2.0',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _updateItems,
              enabled: _isMaster && !_busy,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: 'Novidades — uma por linha',
                hintText:
                    'Nova funcionalidade\nMelhoria de desempenho\nCorreções',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _updateActive
                        ? 'O modal ficará ativo após salvar.'
                        : 'O modal ficará inativo após salvar.',
                    style: const TextStyle(
                      color: Color(0xFF68727D),
                      fontSize: 10.5,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isMaster && !_busy ? _saveAppUpdate : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.publish_outlined,
                          size: 16,
                        ),
                  label: const Text('Salvar novidades'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveMaintenance() async {
    if (!_isMaster || _busy) return;

    final message = _maintenanceMessage.text.trim();

    if (_maintenanceEnabled) {
      final confirmed = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Ativar modo de manutenção?'),
              content: const Text(
                'Usuários comuns perderão o acesso até que o modo '
                'de manutenção seja desativado. Admin e Master '
                'continuam com acesso.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Ativar manutenção'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed || !mounted) return;
    }

    setState(() {
      _busy = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      await _AdminUsersRestLoader.patchDocumentFields(
        'app_config/maintenance',
        <String, dynamic>{
          'enabled': _maintenanceEnabled,
          'message': message,
          'updatedBy': widget.currentAdmin.uid,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionSuccess = _maintenanceEnabled
            ? 'Modo de manutenção ativado.'
            : 'Sistema online novamente.';
        _seededMaintenance = false;
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = error.toString();
      });
    }
  }

  Future<void> _saveAppUpdate() async {
    if (!_isMaster || _busy) return;

    final version = _updateVersion.text.trim();
    final date = _updateDate.text.trim();
    final title = _updateTitle.text.trim();
    final items = _updateItems.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    if (version.isEmpty || title.isEmpty) {
      setState(() {
        _actionError = 'Preencha versão e título das novidades.';
        _actionSuccess = null;
      });
      return;
    }

    if (_updateActive && items.isEmpty) {
      setState(() {
        _actionError =
            'Adicione ao menos uma novidade antes de ativar o modal.';
        _actionSuccess = null;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Salvar novidades do app?'),
            content: Text(
              _updateActive
                  ? 'O aviso da versão $version ficará ATIVO para '
                      'os usuários após salvar.'
                  : 'O aviso da versão $version ficará salvo, porém '
                      'INATIVO para os usuários.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      await _AdminUsersRestLoader.patchDocumentFields(
        'app_updates/current',
        <String, dynamic>{
          'version': version,
          'title': title,
          'date': date,
          'items': items,
          'active': _updateActive,
          'updatedBy': widget.currentAdmin.uid,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionSuccess = _updateActive
            ? 'Novidades publicadas e ativas.'
            : 'Novidades salvas como inativas.';
        _seededUpdate = false;
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = error.toString();
      });
    }
  }
}

class _SettingsBundle {
  const _SettingsBundle({
    required this.maintenance,
    required this.appUpdate,
  });

  const _SettingsBundle.empty()
      : maintenance = const <String, dynamic>{},
        appUpdate = const <String, dynamic>{};

  final Map<String, dynamic> maintenance;
  final Map<String, dynamic> appUpdate;
}

class _SettingsPanePicker extends StatelessWidget {
  const _SettingsPanePicker({
    required this.value,
    required this.onChanged,
  });

  final _SettingsPane value;
  final ValueChanged<_SettingsPane> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          selected: value == _SettingsPane.maintenance,
          onSelected: (_) => onChanged(_SettingsPane.maintenance),
          label: const Text('Sistema'),
        ),
        ChoiceChip(
          selected: value == _SettingsPane.appUpdates,
          onSelected: (_) => onChanged(_SettingsPane.appUpdates),
          label: const Text('Novidades'),
        ),
      ],
    );
  }
}

class _SettingsStatusGrid extends StatelessWidget {
  const _SettingsStatusGrid({
    required this.maintenanceEnabled,
    required this.updateActive,
    required this.updateVersion,
    required this.isMaster,
  });

  final bool maintenanceEnabled;
  final bool updateActive;
  final String updateVersion;
  final bool isMaster;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        'Sistema',
        maintenanceEnabled ? 'Manutenção' : 'Online',
        maintenanceEnabled
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded,
        'app_config/maintenance',
      ),
      _MetricData(
        'Novidades',
        updateActive ? 'Ativas' : 'Inativas',
        Icons.auto_awesome_outlined,
        updateVersion.isEmpty
            ? 'Sem versão publicada'
            : 'Versão $updateVersion',
      ),
      _MetricData(
        'Permissão',
        isMaster ? 'Master' : 'Leitura',
        Icons.admin_panel_settings_outlined,
        isMaster ? 'Alterações críticas liberadas' : 'Sem mutação nesta aba',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _MetricCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _SettingsOwnershipNotice extends StatelessWidget {
  const _SettingsOwnershipNotice();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 17,
              color: Color(0xFF315B96),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Separação de owners preservada: chaves e fallback de IA '
                'ficam em IA & Custos; EmailJS fica em Comunicação. '
                'Configurações não lê nem exibe chaves de provedor.',
                style: TextStyle(
                  color: Color(0xFF68727D),
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsData {
  const _SettingsData._();

  static String text(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static List<String> stringList(dynamic value) {
    if (value is! List) return const <String>[];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

enum _CommunicationPane {
  notifications,
  push,
  email,
}

class _CommunicationSection extends StatefulWidget {
  const _CommunicationSection({
    required this.currentAdmin,
  });

  final UserModel currentAdmin;

  @override
  State<_CommunicationSection> createState() => _CommunicationSectionState();
}

class _CommunicationSectionState extends State<_CommunicationSection> {
  late Future<_CommunicationBundle> _future;

  _CommunicationPane _pane = _CommunicationPane.notifications;

  final _pushTitle = TextEditingController();
  final _pushBody = TextEditingController();

  final _emailSubject = TextEditingController();
  final _emailBody = TextEditingController();

  bool _busy = false;
  String? _actionError;
  String? _actionSuccess;
  String _emailRecipients = 'approved';

  bool get _canMutate =>
      widget.currentAdmin.isMaster || widget.currentAdmin.isAdmin;

  bool get _canConfigureEmail => widget.currentAdmin.isMaster;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _pushTitle.dispose();
    _pushBody.dispose();
    _emailSubject.dispose();
    _emailBody.dispose();
    super.dispose();
  }

  Future<_CommunicationBundle> _load() async {
    final notifications =
        await _AdminUsersRestLoader.listCollection('admin_notifications');
    final pushes =
        await _AdminUsersRestLoader.listCollection('global_push_campaigns');
    final emails =
        await _AdminUsersRestLoader.listCollection('email_campaigns');
    // ADMIN_V2_COMMUNICATION_FINAL_OPERATIONAL_CLOSURE_V1
    // Supervisor is read-only and does not need the full users directory.
    final users = _canMutate
        ? await _AdminUsersRestLoader.load()
        : const <Map<String, dynamic>>[];
    final emailConfig =
        await _AdminUsersRestLoader.loadDocument('app_config/emailjs');

    notifications.sort(
      (a, b) => _CommunicationData.dateOf(
        b['createdAt'],
      ).compareTo(
        _CommunicationData.dateOf(a['createdAt']),
      ),
    );

    pushes.sort(
      (a, b) => _CommunicationData.dateOf(
        b['createdAt'],
      ).compareTo(
        _CommunicationData.dateOf(a['createdAt']),
      ),
    );

    emails.sort(
      (a, b) => _CommunicationData.dateOf(
        b['sentAt'],
      ).compareTo(
        _CommunicationData.dateOf(a['sentAt']),
      ),
    );

    return _CommunicationBundle(
      notifications: notifications.take(50).toList(growable: false),
      pushes: pushes.take(30).toList(growable: false),
      emailCampaigns: emails.take(20).toList(growable: false),
      users: users,
      emailConfig: emailConfig,
    );
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _actionError = null;
      _actionSuccess = null;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CommunicationBundle>(
      future: _future,
      builder: (context, snap) {
        final bundle = snap.data ?? const _CommunicationBundle.empty();
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = _actionError ?? snap.error?.toString();

        final unread = bundle.notifications
            .where(
              (row) => !_CommunicationData.isReadBy(
                row,
                widget.currentAdmin.uid,
              ),
            )
            .length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comunicação',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Notificações administrativas, push global e campanhas de e-mail.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _LiveSourcePill(
                  loading: loading,
                  error: error != null,
                  onTap: loading ? null : _reload,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CommunicationMetricGrid(
              unread: unread,
              pushCount: bundle.pushes.length,
              emailCount: bundle.emailCampaigns.length,
              emailReady: _CommunicationData.emailConfigReady(
                bundle.emailConfig,
              ),
            ),
            const SizedBox(height: 12),
            _CommunicationPanePicker(
              value: _pane,
              unread: unread,
              onChanged: (value) => setState(() => _pane = value),
            ),
            if (!_canMutate) ...[
              const SizedBox(height: 10),
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 17,
                        color: Color(0xFF68727D),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Supervisor possui acesso somente leitura. '
                          'Disparos exigem Admin ou Master.',
                          style: TextStyle(
                            color: Color(0xFF68727D),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_actionSuccess != null) ...[
              const SizedBox(height: 10),
              _Panel(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    _actionSuccess!,
                    style: const TextStyle(
                      color: Color(0xFF087A55),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              _Panel(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (loading && snap.data == null)
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else
              switch (_pane) {
                _CommunicationPane.notifications => _buildNotifications(bundle),
                _CommunicationPane.push => _buildPush(bundle),
                _CommunicationPane.email => _buildEmail(bundle),
              },
          ],
        );
      },
    );
  }

  Widget _buildNotifications(_CommunicationBundle bundle) {
    if (bundle.notifications.isEmpty) {
      return const _Panel(
        child: Padding(
          padding: EdgeInsets.all(34),
          child: Center(
            child: Text(
              'Nenhuma notificação administrativa.',
              style: TextStyle(
                color: Color(0xFF68727D),
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < bundle.notifications.length; i++) ...[
          _AdminNotificationCard(
            row: bundle.notifications[i],
            currentAdminUid: widget.currentAdmin.uid,
            busy: _busy,
            canMarkRead: _canMutate,
            onMarkRead: () => _markNotificationRead(
              bundle.notifications[i],
            ),
          ),
          if (i != bundle.notifications.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildPush(_CommunicationBundle bundle) {
    return Column(
      children: [
        _Panel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Push global',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Cria uma campanha pending em global_push_campaigns. '
                  'A Cloud Function existente processa o envio em massa.',
                  style: TextStyle(
                    color: Color(0xFF68727D),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pushTitle,
                  enabled: _canMutate && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _pushBody,
                  enabled: _canMutate && !_busy,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Destino: todos os usuários cadastrados',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed:
                          _canMutate && !_busy ? _confirmAndSendPush : null,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.campaign_outlined,
                              size: 16,
                            ),
                      label: const Text('Disparar push'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _CommunicationHistoryPanel(
          title: 'Histórico de push',
          empty: 'Nenhuma campanha de push encontrada.',
          children: [
            for (final row in bundle.pushes)
              _CommunicationHistoryRow(
                title: _CommunicationData.text(
                  row['title'],
                  fallback: 'Push sem título',
                ),
                subtitle: _CommunicationData.text(
                  row['body'] ?? row['message'],
                ),
                status: _CommunicationData.text(
                  row['status'],
                  fallback: 'unknown',
                ),
                date: _CommunicationData.dateLabel(row['createdAt']),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmail(_CommunicationBundle bundle) {
    final configReady = _CommunicationData.emailConfigReady(bundle.emailConfig);
    final approved = bundle.users
        .where(
          _CommunicationData.isApprovedUser,
        )
        .length;

    return Column(
      children: [
        _Panel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'E-mail para usuários',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Mantém o provedor EmailJS já usado pelo MedCases.',
                            style: TextStyle(
                              color: Color(0xFF68727D),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _EmailConfigBadge(ready: configReady),
                    if (_canConfigureEmail) ...[
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _editEmailConfig(
                                  bundle.emailConfig,
                                ),
                        icon: const Icon(
                          Icons.settings_outlined,
                          size: 15,
                        ),
                        label: const Text('Configurar'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'O campo Public Key do EmailJS é um identificador público '
                  'do cliente. Nenhuma Private Key deve ser armazenada no app.',
                  style: TextStyle(
                    color: Color(0xFF68727D),
                    fontSize: 10.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _emailRecipients,
                  decoration: const InputDecoration(
                    labelText: 'Destinatários',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'approved',
                      child: Text('Aprovados ($approved)'),
                    ),
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(
                        'Todos com e-mail (${bundle.users.length})',
                      ),
                    ),
                  ],
                  onChanged: _canMutate && !_busy
                      ? (value) {
                          if (value == null) return;
                          setState(() => _emailRecipients = value);
                        }
                      : null,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailSubject,
                  enabled: _canMutate && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Assunto',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailBody,
                  enabled: _canMutate && !_busy,
                  minLines: 5,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        configReady
                            ? 'Configuração EmailJS disponível.'
                            : 'Configure o EmailJS antes de enviar.',
                        style: const TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _canMutate && !_busy && configReady
                          ? () => _confirmAndSendEmail(bundle)
                          : null,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.send_outlined,
                              size: 16,
                            ),
                      label: const Text('Enviar campanha'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _CommunicationHistoryPanel(
          title: 'Histórico de e-mail',
          empty: 'Nenhuma campanha de e-mail encontrada.',
          children: [
            for (final row in bundle.emailCampaigns)
              _CommunicationHistoryRow(
                title: _CommunicationData.text(
                  row['subject'],
                  fallback: 'Campanha sem assunto',
                ),
                subtitle:
                    '${_CommunicationData.text(row['recipients'], fallback: '—')}'
                    ' · ${_CommunicationData.intValue(row['recipientCount'])} enviados',
                status: _CommunicationData.text(
                  row['status'],
                  fallback: 'unknown',
                ),
                date: _CommunicationData.dateLabel(row['sentAt']),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _markNotificationRead(
    Map<String, dynamic> row,
  ) async {
    if (!_canMutate || _busy) return;

    final id = _CommunicationData.documentId(row);
    if (id.isEmpty) return;

    final existing = _CommunicationData.stringList(row['readBy']);
    if (existing.contains(widget.currentAdmin.uid)) return;

    setState(() {
      _busy = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      await _AdminUsersRestLoader.patchDocumentFields(
        'admin_notifications/$id',
        <String, dynamic>{
          'readBy': <String>[
            ...existing,
            widget.currentAdmin.uid,
          ],
        },
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = error.toString();
      });
    }
  }

  Future<void> _confirmAndSendPush() async {
    final title = _pushTitle.text.trim();
    final body = _pushBody.text.trim();

    if (title.isEmpty || body.isEmpty) {
      setState(() {
        _actionError = 'Preencha título e mensagem do push.';
        _actionSuccess = null;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirmar disparo em massa'),
            content: Text(
              'Isso enviará uma notificação push para TODOS os '
              'usuários cadastrados.\n\nTítulo: "$title"\n\n'
              'Esta ação não pode ser desfeita.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirmar envio'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      await _AdminUsersRestLoader.createCollectionDocument(
        'global_push_campaigns',
        <String, dynamic>{
          'title': title,
          'body': body,
          'status': 'pending',
          'targetRole': 'all',
          'createdAt': DateTime.now().toUtc(),
          'sentBy': widget.currentAdmin.uid,
          'sentByEmail': widget.currentAdmin.email.toString().trim(),
          'createdBy': widget.currentAdmin.uid,
          'createdByEmail': widget.currentAdmin.email.toString().trim(),
        },
      );

      _pushTitle.clear();
      _pushBody.clear();

      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionSuccess =
            'Campanha push criada. A Cloud Function processará o envio.';
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = error.toString();
      });
    }
  }

  Future<void> _editEmailConfig(
    Map<String, dynamic> current,
  ) async {
    if (!_canConfigureEmail || _busy) return;

    final service = TextEditingController(
      text: _CommunicationData.text(current['serviceId']),
    );
    final template = TextEditingController(
      text: _CommunicationData.text(current['templateId']),
    );
    final publicKey = TextEditingController(
      text: _CommunicationData.text(current['publicKey']),
    );

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Configurar EmailJS'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: service,
                decoration: const InputDecoration(
                  labelText: 'Service ID',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: template,
                decoration: const InputDecoration(
                  labelText: 'Template ID',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: publicKey,
                decoration: const InputDecoration(
                  labelText: 'Public Key',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Nunca insira Private Key ou segredo do provedor aqui.',
                style: TextStyle(
                  color: Color(0xFFB42318),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final sid = service.text.trim();
              final tid = template.text.trim();
              final pk = publicKey.text.trim();

              if (sid.isEmpty || tid.isEmpty || pk.isEmpty) {
                return;
              }

              Navigator.pop(
                dialogContext,
                <String, String>{
                  'serviceId': sid,
                  'templateId': tid,
                  'publicKey': pk,
                },
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    service.dispose();
    template.dispose();
    publicKey.dispose();

    if (result == null || !mounted) return;

    setState(() {
      _busy = true;
      _actionError = null;
      _actionSuccess = null;
    });

    try {
      await _AdminUsersRestLoader.patchDocumentFields(
        'app_config/emailjs',
        <String, dynamic>{
          ...result,
          'updatedAt': DateTime.now().toUtc(),
          'updatedBy': widget.currentAdmin.uid,
        },
      );

      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionSuccess = 'Configuração EmailJS atualizada.';
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = error.toString();
      });
    }
  }

  Future<void> _confirmAndSendEmail(
    _CommunicationBundle bundle,
  ) async {
    final subject = _emailSubject.text.trim();
    final body = _emailBody.text.trim();

    if (subject.isEmpty || body.isEmpty) {
      setState(() {
        _actionError = 'Preencha assunto e mensagem do e-mail.';
        _actionSuccess = null;
      });
      return;
    }

    final config = bundle.emailConfig;
    final serviceId = _CommunicationData.text(config['serviceId']);
    final templateId = _CommunicationData.text(config['templateId']);
    final publicKey = _CommunicationData.text(config['publicKey']);

    if (serviceId.isEmpty || templateId.isEmpty || publicKey.isEmpty) {
      setState(() {
        _actionError = 'Configuração EmailJS incompleta.';
        _actionSuccess = null;
      });
      return;
    }

    final recipients = bundle.users.where((row) {
      final email = _CommunicationData.userEmail(row);
      if (email.isEmpty) return false;
      if (_emailRecipients == 'all') return true;
      return _CommunicationData.isApprovedUser(row);
    }).toList(growable: false);

    if (recipients.isEmpty) {
      setState(() {
        _actionError = 'Nenhum destinatário elegível encontrado.';
        _actionSuccess = null;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirmar campanha de e-mail'),
            content: Text(
              'Enviar "$subject" para ${recipients.length} '
              'destinatário(s)?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Enviar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _actionError = null;
      _actionSuccess = null;
    });

    var successCount = 0;
    final errors = <String>[];

    for (final user in recipients) {
      final email = _CommunicationData.userEmail(user);
      final name = _CommunicationData.userName(user);

      try {
        await _sendEmailViaEmailJs(
          serviceId: serviceId,
          templateId: templateId,
          publicKey: publicKey,
          toEmail: email,
          toName: name,
          subject: subject,
          message: body,
        );
        successCount++;
      } catch (error) {
        errors.add('$email: $error');
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );
    }

    final status = errors.isNotEmpty && successCount == 0 ? 'error' : 'sent';

    try {
      await _AdminUsersRestLoader.createCollectionDocument(
        'email_campaigns',
        <String, dynamic>{
          'subject': subject,
          'body': body,
          'sentBy': widget.currentAdmin.email.toString().trim(),
          'recipients': _emailRecipients,
          'recipientCount': successCount,
          'status': status,
          'errorMsg': errors.take(3).join(' | '),
          'sentAt': DateTime.now().toUtc(),
        },
      );
    } catch (historyError) {
      errors.add('history: $historyError');
    }

    if (!mounted) return;

    if (successCount > 0) {
      _emailSubject.clear();
      _emailBody.clear();
    }

    setState(() {
      _busy = false;
      _actionSuccess = successCount > 0
          ? '$successCount e-mail(s) enviado(s) com sucesso.'
          : null;
      _actionError = errors.isNotEmpty ? errors.take(3).join('\n') : null;
      _future = _load();
    });
  }

  Future<void> _sendEmailViaEmailJs({
    required String serviceId,
    required String templateId,
    required String publicKey,
    required String toEmail,
    required String toName,
    required String subject,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: const <String, String>{
        'Content-Type': 'application/json',
      },
      body: jsonEncode(
        <String, dynamic>{
          'service_id': serviceId,
          'template_id': templateId,
          'user_id': publicKey,
          'template_params': <String, dynamic>{
            'to_email': toEmail,
            'to_name': toName,
            'subject': subject,
            'message': message,
            'from_name': 'MedCases Pro',
          },
        },
      ),
    );

    if (response.statusCode != 200) {
      throw StateError(
        'EmailJS HTTP ${response.statusCode}',
      );
    }
  }
}

class _CommunicationBundle {
  const _CommunicationBundle({
    required this.notifications,
    required this.pushes,
    required this.emailCampaigns,
    required this.users,
    required this.emailConfig,
  });

  const _CommunicationBundle.empty()
      : notifications = const <Map<String, dynamic>>[],
        pushes = const <Map<String, dynamic>>[],
        emailCampaigns = const <Map<String, dynamic>>[],
        users = const <Map<String, dynamic>>[],
        emailConfig = const <String, dynamic>{};

  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> pushes;
  final List<Map<String, dynamic>> emailCampaigns;
  final List<Map<String, dynamic>> users;
  final Map<String, dynamic> emailConfig;
}

class _CommunicationMetricGrid extends StatelessWidget {
  const _CommunicationMetricGrid({
    required this.unread,
    required this.pushCount,
    required this.emailCount,
    required this.emailReady,
  });

  final int unread;
  final int pushCount;
  final int emailCount;
  final bool emailReady;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        'Não lidas',
        '$unread',
        Icons.notifications_none_rounded,
        'Alertas administrativos',
      ),
      _MetricData(
        'Push recentes',
        '$pushCount',
        Icons.campaign_outlined,
        'Últimas campanhas',
      ),
      _MetricData(
        'E-mails recentes',
        '$emailCount',
        Icons.mark_email_read_outlined,
        'Histórico carregado',
      ),
      _MetricData(
        'EmailJS',
        emailReady ? 'Pronto' : 'Pendente',
        Icons.outgoing_mail,
        'Configuração do provedor',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840 ? 4 : 2;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _MetricCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _CommunicationPanePicker extends StatelessWidget {
  const _CommunicationPanePicker({
    required this.value,
    required this.unread,
    required this.onChanged,
  });

  final _CommunicationPane value;
  final int unread;
  final ValueChanged<_CommunicationPane> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          selected: value == _CommunicationPane.notifications,
          onSelected: (_) => onChanged(_CommunicationPane.notifications),
          label: Text(
            unread > 0 ? 'Notificações ($unread)' : 'Notificações',
          ),
        ),
        ChoiceChip(
          selected: value == _CommunicationPane.push,
          onSelected: (_) => onChanged(_CommunicationPane.push),
          label: const Text('Push global'),
        ),
        ChoiceChip(
          selected: value == _CommunicationPane.email,
          onSelected: (_) => onChanged(_CommunicationPane.email),
          label: const Text('E-mail'),
        ),
      ],
    );
  }
}


class _AdminNotificationCard extends StatelessWidget {
  const _AdminNotificationCard({
    required this.row,
    required this.currentAdminUid,
    required this.busy,
    required this.canMarkRead,
    required this.onMarkRead,
  });

  final Map<String, dynamic> row;
  final String currentAdminUid;
  final bool busy;
  final bool canMarkRead;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final read = _CommunicationData.isReadBy(
      row,
      currentAdminUid,
    );

    final type = _CommunicationData.text(row['type']).toLowerCase();
    final userName = _CommunicationData.text(row['userName']);
    final userEmail = _CommunicationData.text(row['userEmail']);
    final profession = _CommunicationData.text(row['userProfession']);
    final institution = _CommunicationData.text(row['userInstitution']);
    final userStatus = _CommunicationData.text(row['userStatus']);

    final isNewUser = type == 'new_user';

    final title = isNewUser
        ? 'Novo usuário cadastrado'
        : _CommunicationData.text(
            row['title'] ?? row['type'],
            fallback: 'Notificação administrativa',
          );

    final genericBody = _CommunicationData.text(
      row['body'] ?? row['message'] ?? row['description'],
    );

    final identity = <String>[
      if (userName.isNotEmpty) userName,
      if (userEmail.isNotEmpty) userEmail,
    ].join(' · ');

    final profile = <String>[
      if (profession.isNotEmpty) profession,
      if (institution.isNotEmpty) institution,
      if (userStatus.isNotEmpty) 'Status: $userStatus',
    ].join(' · ');

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              read
                  ? Icons.notifications_none_rounded
                  : Icons.notifications_active_rounded,
              size: 18,
              color:
                  read ? const Color(0xFF87919C) : const Color(0xFFB7791F),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    read ? FontWeight.w600 : FontWeight.w800,
                              ),
                            ),
                            if (identity.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                identity,
                                style: const TextStyle(
                                  color: Color(0xFF374151),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            if (profile.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                profile,
                                style: const TextStyle(
                                  color: Color(0xFF68727D),
                                  fontSize: 10,
                                  height: 1.3,
                                ),
                              ),
                            ],
                            if (!isNewUser && genericBody.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                genericBody,
                                style: const TextStyle(
                                  color: Color(0xFF68727D),
                                  fontSize: 10.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _CommunicationData.dateLabel(
                          row['createdAt'] ?? row['createdAtLabel'],
                        ),
                        style: const TextStyle(
                          color: Color(0xFF87919C),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!read && canMarkRead) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: busy ? null : onMarkRead,
                child: const Text('Marcar lida'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommunicationHistoryPanel extends StatelessWidget {
  const _CommunicationHistoryPanel({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (children.isEmpty)
              Text(
                empty,
                style: const TextStyle(
                  color: Color(0xFF68727D),
                  fontSize: 11,
                ),
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}

class _CommunicationHistoryRow extends StatelessWidget {
  const _CommunicationHistoryRow({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.date,
  });

  final String title;
  final String subtitle;
  final String status;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF68727D),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF52606D),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              date,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF87919C),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailConfigBadge extends StatelessWidget {
  const _EmailConfigBadge({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFECFDF5) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
        child: Text(
          ready ? 'CONFIGURADO' : 'PENDENTE',
          style: TextStyle(
            color: ready ? const Color(0xFF087A55) : const Color(0xFF9A6700),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CommunicationData {
  const _CommunicationData._();

  static String text(
    dynamic value, {
    String fallback = '',
  }) {
    final output = value?.toString().trim() ?? '';
    return output.isEmpty ? fallback : output;
  }

  static int intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime dateOf(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String dateLabel(dynamic value) {
    final date = dateOf(value);
    if (date.millisecondsSinceEpoch == 0) return '—';

    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  static String documentId(Map<String, dynamic> row) {
    return text(row['_documentId'] ?? row['id']);
  }

  static List<String> stringList(dynamic value) {
    if (value is! List) return const <String>[];

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static bool isReadBy(
    Map<String, dynamic> row,
    String uid,
  ) {
    return stringList(row['readBy']).contains(uid);
  }

  static bool emailConfigReady(Map<String, dynamic> config) {
    return text(config['serviceId']).isNotEmpty &&
        text(config['templateId']).isNotEmpty &&
        text(config['publicKey']).isNotEmpty;
  }

  static bool isApprovedUser(Map<String, dynamic> row) {
    final status = text(row['status']).toLowerCase();
    return status == 'approved' || row['isApproved'] == true;
  }

  static String userEmail(Map<String, dynamic> row) {
    return text(row['email']);
  }

  static String userName(Map<String, dynamic> row) {
    final candidate = text(
      row['displayName'] ?? row['name'] ?? row['fullName'],
    );

    if (candidate.isNotEmpty) return candidate;

    final email = userEmail(row);
    if (email.contains('@')) return email.split('@').first;
    return email.isEmpty ? 'Usuário MedCases' : email;
  }
}

enum _GuideFilter {
  all,
  published,
  draft,
}

class _ContentGuidesSection extends StatefulWidget {
  const _ContentGuidesSection({
    required this.currentAdmin,
  });

  final UserModel currentAdmin;

  @override
  State<_ContentGuidesSection> createState() => _ContentGuidesSectionState();
}

class _ContentGuidesSectionState extends State<_ContentGuidesSection> {
  late Future<List<Map<String, dynamic>>> _future;
  final _search = TextEditingController();
  _GuideFilter _filter = _GuideFilter.all;
  String? _busyId;
  String? _actionError;

  bool get _canMutate =>
      widget.currentAdmin.isMaster || widget.currentAdmin.isAdmin;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _AdminUsersRestLoader.listCollection(
      'clinical_guides',
    );

    rows.sort((a, b) {
      final aDate = _GuideData.dateOf(a);
      final bDate = _GuideData.dateOf(b);
      return bDate.compareTo(aDate);
    });

    return rows;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _actionError = null;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        final guides = rows.map(_GuideData.fromMap).toList(growable: false);
        final visible = _filtered(guides);
        final metrics = _GuideMetrics.fromGuides(guides);
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = _actionError ?? snap.error?.toString();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conteúdo',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Biblioteca de Guias Clínicos e publicação.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_canMutate)
                  FilledButton.icon(
                    onPressed: _openCmsEditor,
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 17,
                    ),
                    label: const Text('Novo guia'),
                  ),
                const SizedBox(width: 8),
                _LiveSourcePill(
                  loading: loading,
                  error: error != null,
                  onTap: loading ? null : _reload,
                ),
              ],
            ),
            const SizedBox(height: 14),
            const _Panel(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: Color(0xFF315B96),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Conteúdo agora abre diretamente o CMS bilíngue '
                        'homologado. Novo guia, capa, PDFs PT/ES, blocos, '
                        'rascunho, pré-visualização e publicação ficam no '
                        'mesmo editor canônico.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _GuideMetricGrid(metrics: metrics),
            const SizedBox(height: 12),
            _GuideToolbar(
              controller: _search,
              filter: _filter,
              onFilter: (value) => setState(() => _filter = value),
              onChanged: (_) => setState(() {}),
            ),
            if (!_canMutate) ...[
              const SizedBox(height: 10),
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 17,
                        color: Color(0xFF68727D),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Supervisor possui acesso somente leitura.',
                          style: TextStyle(
                            color: Color(0xFF68727D),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              _Panel(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (loading && rows.isEmpty)
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (visible.isEmpty)
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(38),
                  child: Center(
                    child: Text(
                      'Nenhum guia encontrado.',
                      style: TextStyle(
                        color: Color(0xFF68727D),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    _GuideOperationalCard(
                      guide: visible[i],
                      canMutate: _canMutate,
                      busy: _busyId == visible[i].id,
                      onEdit: () => _editGuide(visible[i]),
                      onTogglePublished: () => _togglePublished(visible[i]),
                      onDelete: () => _deleteGuide(visible[i]),
                    ),
                    if (i != visible.length - 1) const SizedBox(height: 9),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }

  List<_GuideData> _filtered(List<_GuideData> guides) {
    final q = _search.text.trim().toLowerCase();

    bool filterOk(_GuideData item) => switch (_filter) {
          _GuideFilter.all => true,
          _GuideFilter.published => item.isPublished,
          _GuideFilter.draft => !item.isPublished,
        };

    bool queryOk(_GuideData item) {
      if (q.isEmpty) return true;
      return [
        item.title,
        item.authors,
        item.year,
        item.url,
      ].join(' ').toLowerCase().contains(q);
    }

    return guides
        .where((item) => filterOk(item) && queryOk(item))
        .toList(growable: false);
  }

  Future<void> _togglePublished(_GuideData guide) async {
    if (!_canMutate || _busyId != null || guide.id.isEmpty) return;

    if (!guide.isPublished) {
      await _openCmsEditor(guide);
      return;
    }

    setState(() {
      _busyId = guide.id;
      _actionError = null;
    });

    try {
      await _AdminUsersRestLoader.patchDocumentFields(
        'clinical_guides/${guide.id}',
        <String, dynamic>{
          'isPublished': false,
          'updatedAt': DateTime.now(),
          'updatedBy': widget.currentAdmin.uid,
        },
      );

      if (!mounted) return;
      setState(() {
        _busyId = null;
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyId = null;
        _actionError = error.toString();
      });
    }
  }

  Future<void> _editGuide(_GuideData guide) async {
    await _openCmsEditor(guide);
  }

  Future<void> _openCmsEditor([_GuideData? guide]) async {
    if (!_canMutate || _busyId != null) return;

    GuideModel? fullGuide;

    if (guide != null) {
      if (guide.id.isEmpty) return;

      setState(() {
        _busyId = guide.id;
        _actionError = null;
      });

      try {
        final full = await _AdminUsersRestLoader.loadDocument(
          'clinical_guides/${guide.id}',
        );

        fullGuide = GuideModel.fromJson(
          <String, dynamic>{
            ...full,
            'id': guide.id,
            'title': full['title'] ?? guide.title,
            'authors': full['authors'] ?? guide.authors,
            'year': full['year'] ?? guide.year,
            'pdfUrl':
                full['pdfUrl'] ?? full['url'] ?? full['fileUrl'] ?? guide.url,
            'fileSize': full['fileSize'] ?? full['filesize'] ?? guide.fileSize,
            'isPublished': full['isPublished'] ?? guide.isPublished,
            'uploadedAt': full['uploadedAt'] ??
                full['createdAt'] ??
                guide.uploadedAt?.toIso8601String() ??
                DateTime.now().toUtc().toIso8601String(),
            'fileName': full['fileName'] ?? '',
          },
        );
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _busyId = null;
          _actionError = error.toString();
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _busyId = null;
      });
    }

    if (!mounted) return;

    final adminName =
        FirebaseAuth.instance.currentUser?.email?.trim().isNotEmpty == true
            ? FirebaseAuth.instance.currentUser!.email!.trim()
            : 'Admin V2';

    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminClinicalGuideEditorScreen(
          guide: fullGuide,
          adminName: adminName,
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _actionError = null;
      _future = _load();
    });
  }

  Future<void> _deleteGuide(_GuideData guide) async {
    if (!_canMutate || _busyId != null || guide.id.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Excluir Guia Clínico?'),
            content: Text(
              'O registro "${guide.title}" será removido do Firestore. '
              'O arquivo físico no Storage permanece preservado nesta '
              'etapa e será tratado junto com a migração de upload.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Excluir registro'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() {
      _busyId = guide.id;
      _actionError = null;
    });

    try {
      await _AdminUsersRestLoader.deleteDocument(
        'clinical_guides/${guide.id}',
      );

      if (!mounted) return;
      setState(() {
        _busyId = null;
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyId = null;
        _actionError = error.toString();
      });
    }
  }
}

class _GuideData {
  const _GuideData({
    required this.id,
    required this.title,
    required this.authors,
    required this.year,
    required this.url,
    required this.fileSize,
    required this.isPublished,
    required this.uploadedAt,
  });

  final String id;
  final String title;
  final String authors;
  final String year;
  final String url;
  final int fileSize;
  final bool isPublished;
  final DateTime? uploadedAt;

  factory _GuideData.fromMap(Map<String, dynamic> data) {
    return _GuideData(
      id: _text(data['_documentId'] ?? data['id']),
      title: _text(data['title']).isEmpty
          ? 'Guia sem título'
          : _text(data['title']),
      authors: _text(data['authors']),
      year: _text(data['year']),
      url: _text(data['url']),
      fileSize: _int(
        data['filesize'] ?? data['fileSize'] ?? data['size'],
      ),
      isPublished: data['isPublished'] == true,
      uploadedAt: _date(
        data['uploadedAt'] ?? data['createdAt'],
      ),
    );
  }

  static DateTime dateOf(Map<String, dynamic> data) =>
      _date(data['uploadedAt'] ?? data['createdAt']) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '');
  }
}

class _GuideMetrics {
  const _GuideMetrics({
    required this.total,
    required this.published,
    required this.draft,
  });

  final int total;
  final int published;
  final int draft;

  factory _GuideMetrics.fromGuides(List<_GuideData> guides) {
    var published = 0;
    for (final guide in guides) {
      if (guide.isPublished) published++;
    }

    return _GuideMetrics(
      total: guides.length,
      published: published,
      draft: guides.length - published,
    );
  }
}

class _GuideMetricGrid extends StatelessWidget {
  const _GuideMetricGrid({required this.metrics});

  final _GuideMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        'Guias',
        '${metrics.total}',
        Icons.menu_book_outlined,
        'Total cadastrado',
      ),
      _MetricData(
        'Publicados',
        '${metrics.published}',
        Icons.public_rounded,
        'Disponíveis aos usuários',
      ),
      _MetricData(
        'Rascunhos',
        '${metrics.draft}',
        Icons.edit_note_rounded,
        'Não publicados',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 1;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _MetricCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _GuideToolbar extends StatelessWidget {
  const _GuideToolbar({
    required this.controller,
    required this.filter,
    required this.onFilter,
    required this.onChanged,
  });

  final TextEditingController controller;
  final _GuideFilter filter;
  final ValueChanged<_GuideFilter> onFilter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = <(_GuideFilter, String)>[
      (_GuideFilter.all, 'Todos'),
      (_GuideFilter.published, 'Publicados'),
      (_GuideFilter.draft, 'Rascunhos'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 330,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar título, autor, ano ou URL',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        for (final option in options)
          ChoiceChip(
            label: Text(option.$2),
            selected: filter == option.$1,
            onSelected: (_) => onFilter(option.$1),
          ),
      ],
    );
  }
}

class _GuideOperationalCard extends StatelessWidget {
  const _GuideOperationalCard({
    required this.guide,
    required this.canMutate,
    required this.busy,
    required this.onEdit,
    required this.onTogglePublished,
    required this.onDelete,
  });

  final _GuideData guide;
  final bool canMutate;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onTogglePublished;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.picture_as_pdf_outlined,
                size: 20,
                color: Color(0xFF52606D),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          guide.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _GuidePublishBadge(
                        published: guide.isPublished,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 12,
                    runSpacing: 5,
                    children: [
                      if (guide.authors.isNotEmpty)
                        _GuideMeta(
                          icon: Icons.person_outline_rounded,
                          text: guide.authors,
                        ),
                      if (guide.year.isNotEmpty)
                        _GuideMeta(
                          icon: Icons.calendar_today_outlined,
                          text: guide.year,
                        ),
                      if (guide.fileSize > 0)
                        _GuideMeta(
                          icon: Icons.sd_storage_outlined,
                          text: _GuideUi.fileSize(guide.fileSize),
                        ),
                      if (guide.uploadedAt != null)
                        _GuideMeta(
                          icon: Icons.schedule_rounded,
                          text: _GuideUi.date(guide.uploadedAt),
                        ),
                    ],
                  ),
                  if (guide.url.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      guide.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF315B96),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (busy)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (canMutate)
              PopupMenuButton<String>(
                tooltip: 'Ações',
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'publish':
                      onTogglePublished();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Abrir editor'),
                  ),
                  PopupMenuItem(
                    value: 'publish',
                    child: Text(
                      guide.isPublished ? 'Despublicar' : 'Publicar no CMS',
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Excluir registro',
                      style: TextStyle(
                        color: Color(0xFFB42318),
                      ),
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_horiz_rounded),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuidePublishBadge extends StatelessWidget {
  const _GuidePublishBadge({required this.published});

  final bool published;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: published ? const Color(0xFFECFDF5) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        child: Text(
          published ? 'PUBLICADO' : 'RASCUNHO',
          style: TextStyle(
            color:
                published ? const Color(0xFF087A55) : const Color(0xFF68727D),
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _GuideMeta extends StatelessWidget {
  const _GuideMeta({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: const Color(0xFF87919C),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF68727D),
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _GuideUi {
  const _GuideUi._();

  static String fileSize(int bytes) {
    if (bytes <= 0) return '—';
    const mb = 1024 * 1024;
    const kb = 1024;

    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
    return '${(bytes / kb).toStringAsFixed(0)} KB';
  }

  static String date(DateTime? value) {
    if (value == null) return 'Sem data';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }
}

enum _IncidentFilter {
  all,
  open,
  investigating,
  critical,
  resolved,
}

class _ErrorsHealthCenterSection extends StatefulWidget {
  const _ErrorsHealthCenterSection({
    required this.currentAdmin,
  });

  final UserModel currentAdmin;

  @override
  State<_ErrorsHealthCenterSection> createState() =>
      _ErrorsHealthCenterSectionState();
}

class _ErrorsHealthCenterSectionState
    extends State<_ErrorsHealthCenterSection> {
  late Future<List<Map<String, dynamic>>> _future;
  final _search = TextEditingController();
  _IncidentFilter _filter = _IncidentFilter.all;
  String? _busyId;
  String? _actionError;

  bool get _canMutate =>
      widget.currentAdmin.isMaster || widget.currentAdmin.isAdmin;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _AdminUsersRestLoader.listCollection(
      'admin_incidents',
    );

    rows.sort((a, b) {
      final aDate = _IncidentData.dateOf(a);
      final bDate = _IncidentData.dateOf(b);
      return bDate.compareTo(aDate);
    });

    return rows;
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _actionError = null;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        final incidents =
            rows.map(_IncidentData.fromMap).toList(growable: false);
        final metrics = _IncidentMetrics.fromIncidents(incidents);
        final visible = _filtered(incidents);
        final loading = snap.connectionState == ConnectionState.waiting;
        final error = _actionError ?? snap.error?.toString();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Erros & Saúde',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Incidentes técnicos, impacto e ciclo de resolução.',
                        style: TextStyle(
                          color: Color(0xFF68727D),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                _LiveSourcePill(
                  loading: loading,
                  error: error != null,
                  onTap: loading ? null : _reload,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _IncidentMetricGrid(metrics: metrics),
            const SizedBox(height: 12),
            _IncidentToolbar(
              controller: _search,
              filter: _filter,
              onFilter: (value) => setState(() => _filter = value),
              onChanged: (_) => setState(() {}),
            ),
            if (!_canMutate) ...[
              const SizedBox(height: 10),
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 17,
                        color: Color(0xFF68727D),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Supervisor possui acesso somente leitura. '
                          'Mudanças de status exigem Admin ou Master.',
                          style: TextStyle(
                            color: Color(0xFF68727D),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              _Panel(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    error,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (loading && rows.isEmpty)
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (visible.isEmpty)
              const _Panel(
                child: Padding(
                  padding: EdgeInsets.all(38),
                  child: Center(
                    child: Text(
                      'Nenhum incidente encontrado.',
                      style: TextStyle(
                        color: Color(0xFF68727D),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    _IncidentOperationalCard(
                      incident: visible[i],
                      canMutate: _canMutate,
                      busy: _busyId == visible[i].id,
                      onStatus: (status) => _setStatus(visible[i], status),
                    ),
                    if (i != visible.length - 1) const SizedBox(height: 9),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }

  List<_IncidentData> _filtered(List<_IncidentData> incidents) {
    final q = _search.text.trim().toLowerCase();

    bool filterOk(_IncidentData item) => switch (_filter) {
          _IncidentFilter.all => true,
          _IncidentFilter.open => item.status == 'open',
          _IncidentFilter.investigating => item.status == 'investigating',
          _IncidentFilter.critical => item.severity == 'critical',
          _IncidentFilter.resolved => item.status == 'resolved',
        };

    bool queryOk(_IncidentData item) {
      if (q.isEmpty) return true;
      return [
        item.message,
        item.module,
        item.screen,
        item.action,
        item.platform,
        item.device,
        item.appVersion,
        item.safeUserId,
        item.stackTrace,
      ].join(' ').toLowerCase().contains(q);
    }

    return incidents
        .where((item) => filterOk(item) && queryOk(item))
        .toList(growable: false);
  }

  Future<void> _setStatus(
    _IncidentData incident,
    String status,
  ) async {
    // ADMIN_V2_ERRORS_FINAL_OPERATIONAL_CLOSURE_V1
    const allowedStatuses = <String>{'open', 'investigating', 'resolved'};
    if (!allowedStatuses.contains(status)) return;
    if (!_canMutate || _busyId != null || incident.id.isEmpty) return;

    setState(() {
      _busyId = incident.id;
      _actionError = null;
    });

    try {
      await _AdminUsersRestLoader.patchDocumentFields(
        'admin_incidents/${incident.id}',
        <String, dynamic>{
          'status': status,
          'updatedAt': DateTime.now(),
          if (status == 'investigating')
            'acknowledgedBy': widget.currentAdmin.uid,
          if (status == 'investigating') 'acknowledgedAt': DateTime.now(),
          'resolvedBy':
              status == 'resolved' ? widget.currentAdmin.uid : null,
          'resolvedAt': status == 'resolved' ? DateTime.now() : null,
        },
      );

      if (!mounted) return;
      setState(() {
        _busyId = null;
        _future = _load();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busyId = null;
        _actionError = error.toString();
      });
    }
  }
}

class _IncidentData {
  const _IncidentData({
    required this.id,
    required this.message,
    required this.severity,
    required this.status,
    required this.module,
    required this.screen,
    required this.action,
    required this.stackTrace,
    required this.platform,
    required this.device,
    required this.appVersion,
    required this.buildNumber,
    required this.safeUserId,
    required this.frequency,
    required this.affectedUsers,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  final String id;
  final String message;
  final String severity;
  final String status;
  final String module;
  final String screen;
  final String action;
  final String stackTrace;
  final String platform;
  final String device;
  final String appVersion;
  final String buildNumber;
  final String safeUserId;
  final int frequency;
  final int affectedUsers;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;

  factory _IncidentData.fromMap(Map<String, dynamic> data) {
    return _IncidentData(
      id: _text(data['_documentId'] ?? data['id']),
      message: _text(
        data['message'] ??
            data['errorMessage'] ??
            data['title'] ??
            'Incidente sem mensagem',
      ),
      severity: _normalize(
        data['severity'] ?? data['level'] ?? 'unknown',
      ),
      status: _normalize(data['status'] ?? 'open'),
      module: _text(data['module']),
      screen: _text(data['screen']),
      action: _text(data['action']),
      stackTrace: _text(
        data['stackTrace'] ?? data['stack'] ?? data['trace'],
      ),
      platform: _text(data['platform']),
      device: _text(
        data['device'] ?? data['deviceModel'],
      ),
      appVersion: _text(data['appVersion'] ?? data['version']),
      buildNumber: _text(data['buildNumber'] ?? data['build']),
      safeUserId: _text(
        data['safeUserId'] ?? data['userHash'] ?? data['userIdMasked'],
      ),
      frequency: _int(data['frequency'] ?? data['count'], fallback: 1),
      affectedUsers: _int(data['affectedUsers'] ?? data['usersAffected']),
      firstSeenAt: _date(
        data['firstSeenAt'] ?? data['createdAt'],
      ),
      lastSeenAt: _date(
        data['lastSeenAt'] ?? data['updatedAt'] ?? data['createdAt'],
      ),
    );
  }

  static DateTime dateOf(Map<String, dynamic> data) =>
      _date(
        data['lastSeenAt'] ?? data['updatedAt'] ?? data['createdAt'],
      ) ??
      DateTime.fromMillisecondsSinceEpoch(0);

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static String _normalize(dynamic value) =>
      value?.toString().trim().toLowerCase() ?? '';

  static int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '');
  }
}

class _IncidentMetrics {
  const _IncidentMetrics({
    required this.total24h,
    required this.criticalOpen,
    required this.open,
    required this.affectedUsers,
  });

  final int total24h;
  final int criticalOpen;
  final int open;
  final int affectedUsers;

  factory _IncidentMetrics.fromIncidents(
    List<_IncidentData> incidents,
  ) {
    final threshold = DateTime.now().subtract(const Duration(hours: 24));

    var total24h = 0;
    var criticalOpen = 0;
    var open = 0;
    var affected = 0;

    for (final item in incidents) {
      final last = item.lastSeenAt ?? item.firstSeenAt;
      if (last != null && !last.isBefore(threshold)) {
        total24h += item.frequency < 1 ? 1 : item.frequency;
      }

      if (item.status != 'resolved') {
        open++;
        if (item.severity == 'critical') criticalOpen++;
        affected += item.affectedUsers;
      }
    }

    return _IncidentMetrics(
      total24h: total24h,
      criticalOpen: criticalOpen,
      open: open,
      affectedUsers: affected,
    );
  }
}

class _IncidentMetricGrid extends StatelessWidget {
  const _IncidentMetricGrid({required this.metrics});

  final _IncidentMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricData>[
      _MetricData(
        'Eventos 24h',
        '${metrics.total24h}',
        Icons.timeline_rounded,
        'Frequência registrada',
      ),
      _MetricData(
        'Críticos abertos',
        '${metrics.criticalOpen}',
        Icons.error_outline_rounded,
        'Prioridade máxima',
      ),
      _MetricData(
        'Incidentes abertos',
        '${metrics.open}',
        Icons.bug_report_outlined,
        'Inclui investigando',
      ),
      _MetricData(
        'Usuários afetados',
        '${metrics.affectedUsers}',
        Icons.group_outlined,
        'Soma reportada',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 840 ? 4 : 2;
        final gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _MetricCard(data: card),
              ),
          ],
        );
      },
    );
  }
}

class _IncidentToolbar extends StatelessWidget {
  const _IncidentToolbar({
    required this.controller,
    required this.filter,
    required this.onFilter,
    required this.onChanged,
  });

  final TextEditingController controller;
  final _IncidentFilter filter;
  final ValueChanged<_IncidentFilter> onFilter;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = <(_IncidentFilter, String)>[
      (_IncidentFilter.all, 'Todos'),
      (_IncidentFilter.open, 'Abertos'),
      (_IncidentFilter.investigating, 'Investigando'),
      (_IncidentFilter.critical, 'Críticos'),
      (_IncidentFilter.resolved, 'Resolvidos'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar erro, módulo, usuário ou versão',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        for (final option in options)
          ChoiceChip(
            label: Text(option.$2),
            selected: filter == option.$1,
            onSelected: (_) => onFilter(option.$1),
          ),
      ],
    );
  }
}

class _IncidentOperationalCard extends StatelessWidget {
  const _IncidentOperationalCard({
    required this.incident,
    required this.canMutate,
    required this.busy,
    required this.onStatus,
  });

  final _IncidentData incident;
  final bool canMutate;
  final bool busy;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IncidentSeverityBadge(severity: incident.severity),
                const SizedBox(width: 8),
                _IncidentStatusBadge(status: incident.status),
                const Spacer(),
                Text(
                  _IncidentUi.formatDate(incident.lastSeenAt),
                  style: const TextStyle(
                    color: Color(0xFF87919C),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              incident.message,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 14,
              runSpacing: 7,
              children: [
                if (incident.module.isNotEmpty)
                  _IncidentMeta(
                    icon: Icons.widgets_outlined,
                    text: incident.module,
                  ),
                if (incident.screen.isNotEmpty)
                  _IncidentMeta(
                    icon: Icons.web_asset_outlined,
                    text: incident.screen,
                  ),
                if (incident.action.isNotEmpty)
                  _IncidentMeta(
                    icon: Icons.touch_app_outlined,
                    text: incident.action,
                  ),
                if (incident.platform.isNotEmpty)
                  _IncidentMeta(
                    icon: Icons.devices_outlined,
                    text: incident.platform,
                  ),
                if (incident.appVersion.isNotEmpty)
                  _IncidentMeta(
                    icon: Icons.tag_outlined,
                    text: incident.buildNumber.isEmpty
                        ? incident.appVersion
                        : '${incident.appVersion} (${incident.buildNumber})',
                  ),
                if (incident.safeUserId.isNotEmpty)
                  _IncidentMeta(
                    icon: Icons.person_outline_rounded,
                    text: incident.safeUserId,
                  ),
              ],
            ),
            if (incident.stackTrace.isNotEmpty) ...[
              const SizedBox(height: 11),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 118),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xFFE2E7EC),
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    incident.stackTrace,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Color(0xFF52606D),
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 11),
            Row(
              children: [
                Text(
                  'Frequência ${incident.frequency}',
                  style: const TextStyle(
                    color: Color(0xFF68727D),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  '${incident.affectedUsers} usuários afetados',
                  style: const TextStyle(
                    color: Color(0xFF68727D),
                    fontSize: 10.5,
                  ),
                ),
                const Spacer(),
                if (busy)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (canMutate)
                  PopupMenuButton<String>(
                    tooltip: 'Alterar status',
                    onSelected: onStatus,
                    itemBuilder: (_) => [
                      if (incident.status != 'open')
                        PopupMenuItem(
                          value: 'open',
                          child: Text(
                            incident.status == 'resolved'
                                ? 'Reabrir incidente'
                                : 'Marcar como aberto',
                          ),
                        ),
                      if (incident.status != 'investigating')
                        const PopupMenuItem(
                          value: 'investigating',
                          child: Text('Marcar investigando'),
                        ),
                      if (incident.status != 'resolved')
                        const PopupMenuItem(
                          value: 'resolved',
                          child: Text('Marcar resolvido'),
                        ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_outlined, size: 14),
                          SizedBox(width: 5),
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentSeverityBadge extends StatelessWidget {
  const _IncidentSeverityBadge({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final data = switch (severity) {
      'critical' => (
          'CRÍTICO',
          const Color(0xFFFFECEA),
          const Color(0xFFB42318),
        ),
      'high' => (
          'ALTO',
          const Color(0xFFFFF4E5),
          const Color(0xFF9A6700),
        ),
      'medium' => (
          'MÉDIO',
          const Color(0xFFFFF9DB),
          const Color(0xFF7A5C00),
        ),
      'low' => (
          'BAIXO',
          const Color(0xFFEEF4FF),
          const Color(0xFF315B96),
        ),
      _ => (
          'SEM NÍVEL',
          const Color(0xFFF2F4F7),
          const Color(0xFF68727D),
        ),
    };

    return _IncidentBadge(
      label: data.$1,
      background: data.$2,
      foreground: data.$3,
    );
  }
}

class _IncidentStatusBadge extends StatelessWidget {
  const _IncidentStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final data = switch (status) {
      'resolved' => (
          'RESOLVIDO',
          const Color(0xFFECFDF5),
          const Color(0xFF087A55),
        ),
      'investigating' => (
          'INVESTIGANDO',
          const Color(0xFFEEF4FF),
          const Color(0xFF315B96),
        ),
      _ => (
          'ABERTO',
          const Color(0xFFFFF4E5),
          const Color(0xFF9A6700),
        ),
    };

    return _IncidentBadge(
      label: data.$1,
      background: data.$2,
      foreground: data.$3,
    );
  }
}

class _IncidentBadge extends StatelessWidget {
  const _IncidentBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _IncidentMeta extends StatelessWidget {
  const _IncidentMeta({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: const Color(0xFF87919C),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF68727D),
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _IncidentUi {
  const _IncidentUi._();

  static String formatDate(DateTime? value) {
    if (value == null) return 'Sem horário';
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(44),
        child: Column(
          children: [
            const Icon(
              Icons.monitor_heart_outlined,
              size: 42,
              color: Color(0xFF87919C),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF68727D)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionScaffold extends StatelessWidget {
  const _SectionScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
        ),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(color: Color(0xFF68727D))),
        const SizedBox(height: 22),
        child,
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E7EC)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 6),
            color: Color(0x0A000000),
          ),
        ],
      ),
      child: child,
    );
  }
}
