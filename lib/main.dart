import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/cockpit_screen.dart';
import 'screens/drugs_screen.dart';
import 'screens/protocols_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/ai_screen.dart';
import 'screens/cases_screen.dart';
import 'screens/admin_screen.dart';
import 'widgets/brand_mark.dart';

// Future global — _AuthGate aguarda antes de ouvir authStateChanges
late final Future<void> _firebaseReady;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final provider = AppProvider();
  await provider.loadPrefs();

  // Guarda o Future para _AuthGate usar — não bloqueia runApp()
  _firebaseReady = Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).then((_) {
    if (kDebugMode) debugPrint('✅ Firebase inicializado');
  }).catchError((e) {
    if (kDebugMode) debugPrint('❌ Firebase init erro: $e');
  });

  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const MedCasesApp(),
    ),
  );
}

class MedCasesApp extends StatelessWidget {
  const MedCasesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    if (kDebugMode) debugPrint('📱 MedCasesApp.build() — darkMode: ${p.darkMode}');
    return MaterialApp(
      title: 'MedCases Pro',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(false),
      darkTheme: _buildTheme(true),
      themeMode: ThemeMode.dark, // Forçar dark sempre para evitar flash
      home: const _AuthGate(),
    );
  }

  ThemeData _buildTheme(bool dark) => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: dark
        ? ColorScheme.dark(
            primary: const Color(0xFFC5A365),
            secondary: const Color(0xFF075f45),
            surface: const Color(0xFF0E1A14),
            onSurface: Colors.white,
          )
        : ColorScheme.light(
            primary: const Color(0xFF07110d),
            secondary: const Color(0xFF075f45),
            surface: const Color(0xFFFFFDF8),
            onSurface: const Color(0xFF07110d),
          ),
    // scaffoldBackgroundColor neutro — cada tela define seu próprio fundo
    // para evitar flash verde/escuro antes das telas de auth carregarem
    scaffoldBackgroundColor: dark ? const Color(0xFF0A1510) : const Color(0xFFF5F0E8),
  );

  // Tema forçado claro — usado nas telas de auth (splash, login, pending)
  // para garantir que o scaffold nunca apareça verde no Safari/iOS
  static ThemeData get _authTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF07110d),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFC5A365),
      secondary: Color(0xFF075f45),
      surface: Color(0xFF07110d),
      onSurface: Colors.white,
    ),
  );
}

// ── Auth Gate — gerencia estados: loading / login / pendente / aprovado ───────
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  /// Envolve uma tela de auth com tema escuro fixo (#07110d)
  /// para garantir que o scaffold nunca mostre o fundo verde do tema escuro
  /// do sistema antes de qualquer widget renderizar.
  Widget _wrapAuth(Widget child) {
    return Theme(
      data: MedCasesApp._authTheme,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Passo 1: aguarda Firebase inicializar antes de ouvir authStateChanges
    // Sem isso, FirebaseAuth.instance acessa Firebase não-inicializado
    // → stream nunca emite → ConnectionState.waiting eterno → tela cinza
    return FutureBuilder<void>(
      future: _firebaseReady,
      builder: (context, firebaseSnap) {
        // Firebase ainda carregando → splash
        if (firebaseSnap.connectionState != ConnectionState.done) {
          return _wrapAuth(const _SplashScreen());
        }

        // Firebase com erro → vai para login mesmo assim (Firebase pode
        // já estar inicializado de uma sessão anterior no browser)
        // ── Passo 2: agora sim ouvir o stream de auth
        return StreamBuilder<User?>(
          stream: AuthService.authStateChanges,
          builder: (context, authSnap) {
            // Carregando estado de auth
            if (authSnap.connectionState == ConnectionState.waiting) {
              return _wrapAuth(const _SplashScreen());
            }

            // Não autenticado → tela de login
            if (authSnap.data == null) {
              return _wrapAuth(const LoginScreen());
            }

            // Autenticado → buscar perfil no Firestore
            return StreamBuilder<UserModel?>(
              stream: AuthService.currentUserStream(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  return _wrapAuth(const _SplashScreen());
                }

                final user = userSnap.data;

                // Perfil não encontrado → login novamente
                if (user == null) {
                  AuthService.logout();
                  return _wrapAuth(const LoginScreen());
                }

                // Usuário bloqueado
                if (user.isBlocked) {
                  AuthService.logout();
                  return _wrapAuth(_BlockedScreen(user: user));
                }

                // Usuário pendente de aprovação
                if (user.isPending) {
                  return _wrapAuth(_PendingScreen(user: user));
                }

                // Aprovado → atualizar provider e abrir app
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final p = context.read<AppProvider>();
                  if (p.currentUser?.uid != user.uid) {
                    p.setUser(user);
                  }
                });

                return const MainShell();
              },
            );
          },
        );
      },
    );
  }
}

// ── Splash Screen ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07110d),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const BrandMark(small: false),
          const SizedBox(height: 32),
          SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: const Color(0xFFFFE8A6).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Carregando MedCases Pro...',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}

// ── Tela de conta pendente ────────────────────────────────────────────────────
class _PendingScreen extends StatelessWidget {
  final UserModel user;
  const _PendingScreen({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07110d),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandMark(small: false),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Cadastro em análise',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Olá, ${user.displayName.split(' ').first}!\n\nSua conta está aguardando aprovação do administrador. Você receberá acesso assim que for aprovado.',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('E-mail cadastrado:', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(user.email, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sair e fazer novo login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tela de conta bloqueada ───────────────────────────────────────────────────
class _BlockedScreen extends StatelessWidget {
  final UserModel user;
  const _BlockedScreen({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07110d),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandMark(small: false),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Column(children: [
                  const Icon(Icons.block_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Acesso suspenso',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sua conta foi suspensa pelo administrador.\n\nEntre em contato para mais informações.',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async { await AuthService.logout(); },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Voltar ao login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shell principal (após aprovação) ─────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  String? _pendingProtocolId;

  void _openProtocol(String id) {
    setState(() { _tab = 2; _pendingProtocolId = id; });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final bg = dark ? const Color(0xFF0A1510) : const Color(0xFFF5F0E8);
    final navBg = dark ? const Color(0xFF0E1A14) : Colors.white;
    final navBorder = dark ? const Color(0xFF1A2E20) : const Color(0xFFE8E1D2);

    final screens = [
      CockpitScreen(openProtocol: _openProtocol),
      const DrugsScreen(),
      ProtocolsScreen(
        key: ValueKey(_pendingProtocolId),
        initialProtocolId: _pendingProtocolId,
        onConsumed: () => setState(() => _pendingProtocolId = null),
      ),
      const ToolsScreen(),
      const AiScreen(),
      const CasesScreen(),
    ];

    // Ordem: Cockpit | Fármacos | [IA central] | Protocolos | Calculadoras
    // índice IA = 4 na lista screens, mas fica no centro visualmente
    // Mapeamento: visual [0,1,2=IA,3,4] → screens [0,1,4,2,3]
    // Simplificado: reordenar screens para que IA fique no índice 2
    final reorderedScreens = [
      screens[0], // Cockpit
      screens[1], // Fármacos
      screens[4], // IA ← centro
      screens[2], // Protocolos
      screens[3], // Calculadoras
    ];

    // Tradução do índice visual para índice original (para openProtocol)
    // Se _tab == 3 (visual Protocolos), o índice original era 2
    // Tratamos isso atualizando _openProtocol para usar índice visual

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _AppHeader(
          onTabChange: (t) => setState(() => _tab = t),
          currentTab: _tab,
        ),
        Expanded(child: IndexedStack(index: _tab, children: reorderedScreens)),
      ]),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Barra de segurança jurídica ──────────────────────────────────
          _LegalBar(dark: dark),
          // ── Navegação principal ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: navBg,
              border: Border(top: BorderSide(color: navBorder, width: 1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 72,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    // ── Linha de botões regulares ──────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildNavBtn(0, Icons.home_rounded, p.t('cockpit'), dark, p),
                        _buildNavBtn(1, Icons.medication_rounded, p.t('drugs'), dark, p),
                        // Espaço reservado para o botão IA flutuante
                        const SizedBox(width: 76),
                        _buildNavBtn(3, Icons.emergency_rounded, p.t('protocols'), dark, p),
                        _buildNavBtn(4, Icons.calculate_rounded, p.t('tools'), dark, p),
                      ],
                    ),
                    // ── Botão IA flutuante central ─────────────────────────
                    Positioned(
                      top: -22,
                      child: _buildAiNavBtn(dark, p),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBtn(int idx, IconData icon, String label, bool dark, dynamic p) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = idx),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: active
                  ? const Color(0xFF07110d).withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 22,
              color: active
                  ? (dark ? const Color(0xFFFFE8A6) : const Color(0xFF07110d))
                  : (dark ? Colors.white38 : const Color(0xFFAAAAAA)),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontSize: 9,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active
                  ? (dark ? const Color(0xFFFFE8A6) : const Color(0xFF07110d))
                  : (dark ? Colors.white38 : const Color(0xFFAAAAAA)),
            ),
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }

  Widget _buildAiNavBtn(bool dark, dynamic p) {
    final active = _tab == 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = 2),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Círculo flutuante principal ──────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: active ? 60 : 56,
              height: active ? 60 : 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: active
                      ? [const Color(0xFFD4AF5A), const Color(0xFFC5A365), const Color(0xFF8B6914)]
                      : [const Color(0xFF0D2018), const Color(0xFF07110d), const Color(0xFF075f45)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: active
                        ? const Color(0xFFC5A365).withValues(alpha: 0.65)
                        : const Color(0xFF075f45).withValues(alpha: 0.5),
                    blurRadius: active ? 22 : 14,
                    spreadRadius: active ? 3 : 1,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: active
                      ? const Color(0xFFFFE8A6).withValues(alpha: 0.6)
                      : const Color(0xFF1A3528).withValues(alpha: 0.8),
                  width: active ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.psychology_rounded,
                    key: ValueKey(active),
                    size: active ? 30 : 27,
                    color: active ? const Color(0xFF07110d) : const Color(0xFFFFE8A6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // ── Label ──────────────────────────────────────────────────────
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                color: active
                    ? const Color(0xFFC5A365)
                    : (dark ? Colors.white54 : const Color(0xFF777777)),
              ),
              child: Text(p.t('ai')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barra legal / segurança jurídica ─────────────────────────────────────────
class _LegalBar extends StatelessWidget {
  final bool dark;
  const _LegalBar({required this.dark});

  @override
  Widget build(BuildContext context) {
    final bg   = dark ? const Color(0xFF060E09) : const Color(0xFFEFEADF);
    final border = dark ? const Color(0xFF1A2E20) : const Color(0xFFD8D0C0);
    final textColor = dark
        ? Colors.white.withValues(alpha: 0.32)
        : const Color(0xFF888070);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 10, color: textColor),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Fins educacionais. Não substitui julgamento clínico. '
              'Baseado em: AHA 2020, ESC 2023, Harrison\'s 21ª ed., '
              'ANVISA, ACLS/ATLS, SBEM, Micromedex.',
              style: TextStyle(
                fontSize: 8.5,
                color: textColor,
                height: 1.4,
                letterSpacing: 0.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ── Botão Admin com badge de pendentes em tempo real ──────────────────────────
class _AdminBadgeButton extends StatelessWidget {
  final UserModel currentAdmin;
  const _AdminBadgeButton({required this.currentAdmin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => AdminScreen(currentAdmin: currentAdmin),
          )),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: count > 0
                      ? const Color(0xFFFF8C00).withValues(alpha: 0.2)
                      : const Color(0xFFC5A365).withValues(alpha: 0.15),
                  border: Border.all(
                    color: count > 0
                        ? const Color(0xFFFF8C00).withValues(alpha: 0.6)
                        : const Color(0xFFC5A365).withValues(alpha: 0.35),
                  ),
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 16,
                  color: count > 0 ? const Color(0xFFFF8C00) : const Color(0xFFFFE8A6),
                ),
              ),
              // Badge com número de pendentes
              if (count > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Header do app ─────────────────────────────────────────────────────────────
class _AppHeader extends StatelessWidget {
  final ValueChanged<int> onTabChange;
  final int currentTab;
  const _AppHeader({required this.onTabChange, required this.currentTab});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF07110d), Color(0xFF123326), Color(0xFF075f45)],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(children: [
            const BrandMark(small: true),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(p.userName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                ),
                // Badge de Admin
                if (p.isAdmin)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFFC5A365).withValues(alpha: 0.2),
                      border: Border.all(color: const Color(0xFFC5A365).withValues(alpha: 0.5)),
                    ),
                    child: const Text('ADMIN', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6), letterSpacing: 0.5)),
                  ),
              ]),
              Text(p.lang == 'es' ? 'Apoyo clínico educativo' : 'Apoio clínico educacional',
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
            ])),
            // Botão Admin com badge de pendentes (apenas para admins)
            if (p.isAdmin) ...[
              _AdminBadgeButton(currentAdmin: p.currentUser!),
              const SizedBox(width: 8),
            ],
            // Lang toggle
            GestureDetector(
              onTap: () => p.setLang(p.lang == 'pt' ? 'es' : 'pt'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(p.lang.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6), letterSpacing: 1)),
              ),
            ),
            const SizedBox(width: 8),
            // Dark mode
            GestureDetector(
              onTap: () => p.toggleDarkMode(),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 16, color: const Color(0xFFFFE8A6)),
              ),
            ),
            const SizedBox(width: 8),
            // Logout
            GestureDetector(
              onTap: () async {
                await AuthService.logout();
                if (context.mounted) context.read<AppProvider>().clearUser();
              },
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.red.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFFFAAAA)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Tela de erro Firebase ─────────────────────────────────────────────────────
class _FirebaseErrorScreen extends StatelessWidget {
  const _FirebaseErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: MedCasesApp._authTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFF07110d),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BrandMark(small: false),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Column(children: [
                    const Icon(Icons.cloud_off_rounded, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Erro ao conectar Firebase',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Não foi possível conectar aos serviços do Firebase.\n\nVerifique sua conexão e tente novamente.',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Força refresh da página no web
                    if (kIsWeb) {
                      launchUrl(Uri.parse(Uri.base.toString()));
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Recarregar app'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
