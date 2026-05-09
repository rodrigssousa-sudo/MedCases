import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'screens/admin_screen.dart';
import 'screens/history_screen.dart';
import 'screens/maintenance_screen.dart';
import 'services/firestore_service.dart';
import 'widgets/brand_mark.dart';

// Future global — já resolvido quando runApp() é chamado
// Mantido para compatibilidade com _AuthGate FutureBuilder
late final Future<void> _firebaseInit;

void main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  WidgetsFlutterBinding.ensureInitialized();

  // Firebase DEVE ser inicializado com await ANTES do runApp()
  // Sem isso, qualquer uso de Auth/Firestore explode com [core/no-app]
  // mesmo dentro de FutureBuilder — porque streams internos disparam cedo
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Já concluído — Future.value() resolve imediatamente no FutureBuilder
    _firebaseInit = Future.value();
  } catch (e) {
    // Falha real de configuração (ex: firebase_options errado)
    // _AuthGate mostra LoginScreen graciosamente
    debugPrint('[MedCases] Firebase.initializeApp falhou: $e');
    _firebaseInit = Future.error(e);
  }

  final provider = AppProvider();

  // SharedPreferences falha em abas anônimas (localStorage bloqueado)
  try {
    await provider.loadPrefs();
  } catch (e) {
    debugPrint('[MedCases] SharedPreferences indisponível: $e');
  }

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
    return MaterialApp(
      title: 'MedCases Pro',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(false),
      darkTheme: _buildTheme(true),
      themeMode: p.darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const _AuthGate(),
    );
  }

  ThemeData _buildTheme(bool dark) => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: dark
        ? ColorScheme.dark(
            primary: const Color(0xFFD4A96A),
            onPrimary: const Color(0xFF1A1A1A),
            secondary: const Color(0xFF2E7D5E),
            onSecondary: Colors.white,
            surface: const Color(0xFF1C1C1E),
            onSurface: const Color(0xFFE8E8EA),
            surfaceContainerHighest: const Color(0xFF2C2C2E),
            outline: const Color(0xFF48484A),
            outlineVariant: const Color(0xFF3A3A3C),
            error: const Color(0xFFFF6B6B),
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: const Color(0xFF07110d),
            secondary: const Color(0xFF075f45),
            surface: const Color(0xFFFFFDF8),
            onSurface: const Color(0xFF07110d),
          ),
    scaffoldBackgroundColor: dark ? const Color(0xFF111113) : const Color(0xFFF7F8FA),
    cardColor: dark ? const Color(0xFF1C1C1E) : Colors.white,
    dividerColor: dark ? const Color(0xFF3A3A3C) : const Color(0xFFE2E6EA),
  );

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

// ── Auth Gate ─────────────────────────────────────────────────────────────────
// Firebase já está inicializado quando chegamos aqui (await no main)
// _AuthGate: aguarda Firebase inicializar via FutureBuilder,
// depois ouve o stream de auth — runApp() já aconteceu, splash aparece imediatamente
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  Widget _wrapAuth(Widget child) => Theme(
    data: MedCasesApp._authTheme,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    // Etapa 1: aguarda Firebase init (em paralelo ao runApp)
    return FutureBuilder<void>(
      future: _firebaseInit,
      builder: (context, firebaseSnap) {
        // Firebase ainda inicializando → splash nativa Flutter (sem tela verde)
        if (firebaseSnap.connectionState != ConnectionState.done) {
          return _wrapAuth(const _SplashScreen());
        }

        // Firebase falhou (Safari/iOS: cookies, IndexedDB, CORS)
        // → abre LoginScreen normalmente; Auth falhará graciosamente ao tentar logar
        if (firebaseSnap.hasError) {
          return _wrapAuth(const LoginScreen());
        }

        // Etapa 2: Firebase OK → ouve stream de manutenção em tempo real
        return StreamBuilder<Map<String, dynamic>>(
          stream: FirestoreService.maintenanceStream(),
          builder: (context, maintSnap) {
            final isMaintenanceEnabled = maintSnap.data?['enabled'] == true;
            final maintenanceMessage =
                maintSnap.data?['message'] as String? ?? '';

            // Etapa 3: ouve stream de autenticação
            return StreamBuilder<User?>(
              stream: AuthService.authStateChanges,
              builder: (context, authSnap) {
                if (authSnap.connectionState == ConnectionState.waiting) {
                  return _wrapAuth(const _SplashScreen());
                }

                // Não autenticado → login (manutenção não bloqueia login)
                if (authSnap.data == null) {
                  return _wrapAuth(const LoginScreen());
                }

                // Autenticado → buscar perfil Firestore
                return StreamBuilder<UserModel?>(
                  stream: AuthService.currentUserStream(),
                  builder: (context, userSnap) {
                    if (userSnap.connectionState == ConnectionState.waiting) {
                      return _wrapAuth(const _SplashScreen());
                    }

                    final user = userSnap.data;

                    if (user == null) {
                      AuthService.logout();
                      return _wrapAuth(const LoginScreen());
                    }

                    if (user.isBlocked) {
                      AuthService.logout();
                      return _wrapAuth(_BlockedScreen(user: user));
                    }

                    if (user.isPending) {
                      return _wrapAuth(_PendingScreen(user: user));
                    }

                    // Admin / Master passam pela manutenção direto
                    final bypassMaintenance = user.isAdmin || user.isMaster;

                    if (isMaintenanceEnabled && !bypassMaintenance) {
                      return _wrapAuth(
                        MaintenanceScreen(message: maintenanceMessage),
                      );
                    }

                    // Aprovado → atualiza provider e abre o app
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Tela de erro Firebase ─────────────────────────────────────────────────────
class _FirebaseErrorScreen extends StatelessWidget {
  final String error;
  const _FirebaseErrorScreen({required this.error});

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
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(children: [
                  const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF8888), size: 40),
                  const SizedBox(height: 12),
                  const Text('Sem conexão com o servidor',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 8),
                  const Text('Verifique sua conexão e tente novamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                ]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075f45),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  // Recarrega a página
                  // ignore: avoid_web_libraries_in_flutter
                  // Usa Navigator para forçar rebuild
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const _AuthGate()),
                    (_) => false,
                  );
                },
                child: const Text('Tentar novamente', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tela pendente ─────────────────────────────────────────────────────────────
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
                onPressed: () async { await AuthService.logout(); },
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

// ── Tela bloqueada ────────────────────────────────────────────────────────────
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

// ── Shell principal ───────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  // tabs: 0=Cockpit 1=Rx/Proto 2=IA(FAB) 3=H.Clínica 4=Calculadoras
  int _tab = 0;
  // sub-tab dentro do combo Rx+Proto: 0=Rx, 1=Protocolos
  int _rxProtoSub = 0;
  String? _pendingProtocolId;
  // Header recolhível: visível apenas na tab 0 (Cockpit/Início)
  bool get _headerVisible => _tab == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Força logout quando o app é mandado para background (fechado/minimizado)
  // Na próxima abertura, Firebase Auth não terá sessão ativa → volta para LoginScreen
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      AuthService.logout();
    }
  }

  void _openProtocol(String id) {
    setState(() {
      _tab = 1;
      _rxProtoSub = 1;
      _pendingProtocolId = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final bg = dark ? const Color(0xFF0A1510) : const Color(0xFFF7F8FA);
    final navBg = dark ? const Color(0xFF0E1A14) : Colors.white;
    final navBorder = dark ? const Color(0xFF1A2E20) : const Color(0xFFE8E1D2);

    // Tela combo Rx + Protocolos com TabBar interna
    final rxProtoScreen = _RxProtoCombo(
      subTab: _rxProtoSub,
      onSubTabChange: (i) => setState(() => _rxProtoSub = i),
      pendingProtocolId: _pendingProtocolId,
      onProtocolConsumed: () => setState(() => _pendingProtocolId = null),
    );

    // Ordem das telas no IndexedStack
    // tab: 0=Cockpit | 1=Rx+Proto | 2=IA(FAB) | 3=H.Clínica | 4=Calculadoras
    // stack: 0=Cockpit | 1=Rx+Proto | 2=IA | 3=H.Clínica | 4=Calculadoras
    final mainScreens = [
      CockpitScreen(openProtocol: _openProtocol), // 0
      rxProtoScreen,                               // 1
      const AiScreen(),                            // 2 — FAB central
      const HistoryScreen(),                       // 3 — H.Clínica integrada
      const ToolsScreen(),                         // 4
    ];

    // stackIdx = _tab direto (todas as telas no stack agora)
    final stackIdx = _tab.clamp(0, mainScreens.length - 1);

    return Scaffold(
      backgroundColor: bg,
      endDrawer: _AppDrawer(p: p),
      body: Column(children: [
        // Nas abas IA (2) e H. Clínica (3) esconde o header global — cada tela tem o seu
        if (_tab != 2 && _tab != 3)
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: _headerVisible
                ? _AppHeader(
                    onTabChange: (t) => setState(() => _tab = t),
                    currentTab: _tab,
                  )
                : _MiniContextBar(
                    tab: _tab,
                    dark: dark,
                    onHome: () => setState(() => _tab = 0),
                  ),
          ),
        Expanded(child: IndexedStack(index: stackIdx.clamp(0, mainScreens.length - 1), children: mainScreens)),
      ]),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Barra de navegação principal ─────────────────────────────────
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
              bottom: false, // LegalBar cuida do padding inferior
              child: SizedBox(
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 0 — Início
                        _buildNavBtn(0, Icons.home_rounded, p.t('cockpit'), dark, p),
                        // 1 — Rx + Protocolos (combo)
                        _buildNavBtn(1, Icons.layers_rounded, 'Fármaco', dark, p),
                        // espaço para o FAB central (IA)
                        const SizedBox(width: 68),
                        // 3 — História Clínica (tab no stack)
                        _buildNavBtn(3, Icons.folder_shared_rounded, 'H. Clínica', dark, p),
                        // 4 — Calculadoras
                        _buildNavBtn(4, Icons.calculate_rounded, p.t('tools'), dark, p),
                      ],
                    ),
                    Positioned(
                      top: -18,
                      child: _buildAiNavBtn(dark, p),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // ── Disclaimer legal — ABAIXO da nav bar ─────────────────────────
          _LegalBar(dark: dark),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: active
                  ? const Color(0xFF07110d).withValues(alpha: 0.12)
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 20,
              color: active
                  ? (dark ? const Color(0xFFFFE8A6) : const Color(0xFF07110d))
                  : (dark ? Colors.white38 : const Color(0xFFAAAAAA)),
            ),
          ),
          const SizedBox(height: 1),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontSize: 8.5,
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

  // Botão de ação (sem índice de tab — faz push de rota)
  Widget _buildNavBtnAction(IconData icon, String label, bool dark, dynamic p, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 22,
              color: dark ? Colors.white38 : const Color(0xFFAAAAAA),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: dark ? Colors.white38 : const Color(0xFFAAAAAA),
            ),
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: active ? 52 : 48,
              height: active ? 52 : 48,
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
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 8.5,
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

// ── Combo Rx + Protocolos ─────────────────────────────────────────────────────
class _RxProtoCombo extends StatelessWidget {
  final int subTab;
  final ValueChanged<int> onSubTabChange;
  final String? pendingProtocolId;
  final VoidCallback onProtocolConsumed;

  const _RxProtoCombo({
    required this.subTab,
    required this.onSubTabChange,
    this.pendingProtocolId,
    required this.onProtocolConsumed,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final bg = dark ? const Color(0xFF0A1510) : const Color(0xFFF7F8FA);
    final borderCol = dark ? const Color(0xFF1A2E20) : const Color(0xFFE2E6EA);

    return Column(children: [
      // ── Seletor de sub-tab ────────────────────────────────────────────────
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: dark ? const Color(0xFF0E1A14) : Colors.white,
            border: Border.all(color: borderCol),
          ),
          child: Row(children: [
            _SubTabBtn(
              icon: Icons.medication_rounded,
              label: p.t('drugs'),
              active: subTab == 0,
              dark: dark,
              onTap: () => onSubTabChange(0),
            ),
            Container(width: 1, height: 24, color: borderCol),
            _SubTabBtn(
              icon: Icons.emergency_rounded,
              label: p.t('protocols'),
              active: subTab == 1,
              dark: dark,
              onTap: () => onSubTabChange(1),
            ),
          ]),
        ),
      ),
      // ── Conteúdo ──────────────────────────────────────────────────────────
      Expanded(
        child: IndexedStack(
          index: subTab,
          children: [
            const DrugsScreen(),
            ProtocolsScreen(
              key: ValueKey(pendingProtocolId),
              initialProtocolId: pendingProtocolId,
              onConsumed: onProtocolConsumed,
            ),
          ],
        ),
      ),
    ]);
  }
}

class _SubTabBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  const _SubTabBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = dark ? const Color(0xFFFFE8A6) : const Color(0xFF07110d);
    final inactiveColor = dark ? Colors.white38 : const Color(0xFFAAAAAA);
    final activeBg = dark
        ? const Color(0xFF1A3528)
        : const Color(0xFF07110d).withValues(alpha: 0.08);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? activeBg : Colors.transparent,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16,
              color: active ? activeColor : inactiveColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: active ? activeColor : inactiveColor,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Mini barra de contexto (header recolhido nas sub-telas) ─────────────────
class _MiniContextBar extends StatelessWidget {
  final int tab;
  final bool dark;
  final VoidCallback onHome;
  const _MiniContextBar({required this.tab, required this.dark, required this.onHome});

  static const _tabNames = [
    '',
    'Fármacos',
    'IA Clínica',
    'H. Clínica',
    'Calculadoras',
  ];

  @override
  Widget build(BuildContext context) {
    final name = tab < _tabNames.length ? _tabNames[tab] : '';
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF07110d), Color(0xFF123326), Color(0xFF075f45)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
          child: Row(children: [
            GestureDetector(
              onTap: onHome,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const BrandMark(small: true),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 14,
                    color: Colors.white.withValues(alpha: 0.45)),
                const SizedBox(width: 4),
                Text(name,
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: -0.2,
                  )),
              ]),
            ),
            const Spacer(),
            // Botão home
            GestureDetector(
              onTap: onHome,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.home_rounded, size: 13,
                      color: const Color(0xFFFFE8A6).withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  const Text('Início',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: Color(0xFFFFE8A6),
                    )),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            // Botão menu lateral
            GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: Icon(Icons.menu_rounded, size: 16,
                    color: const Color(0xFFFFE8A6).withValues(alpha: 0.9)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Barra legal ───────────────────────────────────────────────────────────────
class _LegalBar extends StatelessWidget {
  final bool dark;
  const _LegalBar({required this.dark});

  @override
  Widget build(BuildContext context) {
    final bg     = dark ? const Color(0xFF060E09) : const Color(0xFFEFF1F3);
    final border = dark ? const Color(0xFF1A2E20) : const Color(0xFFDDE0E4);
    final textColor = dark
        ? Colors.white.withValues(alpha: 0.32)
        : const Color(0xFF9098A0);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 9, color: textColor),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Fins educacionais · Não substitui julgamento clínico · AHA 2020 · ESC 2023 · Harrison\'s 21ed · ANVISA · ACLS/ATLS',
            style: TextStyle(fontSize: 7.5, color: textColor, height: 1.2, letterSpacing: 0.1),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

// ── Botão Admin com badge ─────────────────────────────────────────────────────
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

// ── Drawer lateral estilo banco (desliza da direita) ─────────────────────────
class _AppDrawer extends StatelessWidget {
  final AppProvider p;
  const _AppDrawer({required this.p});

  static const _kDark  = Color(0xFF07110d);
  static const _kGreen = Color(0xFF075f45);
  static const _kGold  = Color(0xFFC5A365);
  static const _kGoldL = Color(0xFFFFE8A6);

  void _close(BuildContext context) => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final dark = p.darkMode;
    final bg      = dark ? const Color(0xFF0D1A12) : Colors.white;
    final divider = dark ? const Color(0xFF1A2E20) : const Color(0xFFEEEBE4);
    final textCol = dark ? Colors.white : _kDark;
    final subCol  = dark ? Colors.white38 : const Color(0xFF888888);

    return Drawer(
      width: 290,
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabeçalho do drawer ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_kDark, Color(0xFF123326), _kGreen],
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const BrandMark(small: false),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _close(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: Icon(Icons.close_rounded, size: 16,
                          color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(
                  p.userName.isNotEmpty ? p.userName : 'MedCases Pro',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                if (p.currentUser?.profession?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    p.currentUser!.profession!,
                    style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (p.currentUser?.institution?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 1),
                  Text(
                    p.currentUser!.institution!,
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (p.isAdmin) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _kGold.withValues(alpha: 0.2),
                      border: Border.all(color: _kGold.withValues(alpha: 0.5)),
                    ),
                    child: const Text('ADMIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _kGoldL, letterSpacing: 0.5)),
                  ),
                ],
              ]),
            ),

            // ── Itens do menu ────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [

                  // ── Editar perfil ───────────────────────────────────────
                  _DrawerItem(
                    icon: Icons.person_outline_rounded,
                    iconColor: _kGold,
                    title: p.lang == 'es' ? 'Editar perfil' : 'Editar perfil',
                    subtitle: p.lang == 'es' ? 'Nombre, profesión, institución' : 'Nome, profissão, instituição',
                    dark: dark,
                    textCol: textCol,
                    subCol: subCol,
                    onTap: () {
                      _close(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _ProfileEditSheet(p: p),
                      );
                    },
                  ),

                  Divider(height: 1, color: divider, indent: 16, endIndent: 16),

                  // ── Idioma ──────────────────────────────────────────────
                  _DrawerItem(
                    icon: Icons.language_rounded,
                    iconColor: const Color(0xFF1E88E5),
                    title: p.lang == 'es' ? 'Idioma' : 'Idioma',
                    subtitle: p.lang == 'pt' ? 'Trocar para Español' : 'Cambiar a Português',
                    dark: dark,
                    textCol: textCol,
                    subCol: subCol,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: _kGold.withValues(alpha: 0.12),
                        border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        p.lang.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _kGold, letterSpacing: 1),
                      ),
                    ),
                    onTap: () {
                      final newLang = p.lang == 'pt' ? 'es' : 'pt';
                      p.setLang(newLang);
                      // Salva permanentemente nas prefs
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setString('lang', newLang);
                      });
                    },
                  ),

                  Divider(height: 1, color: divider, indent: 16, endIndent: 16),

                  // ── Modo escuro / claro ─────────────────────────────────
                  _DrawerItem(
                    icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    iconColor: dark ? const Color(0xFFFFCC44) : const Color(0xFF555577),
                    title: p.lang == 'es' ? 'Apariencia' : 'Aparência',
                    subtitle: dark
                        ? (p.lang == 'es' ? 'Cambiar a modo claro' : 'Mudar para modo claro')
                        : (p.lang == 'es' ? 'Cambiar a modo oscuro' : 'Mudar para modo escuro'),
                    dark: dark,
                    textCol: textCol,
                    subCol: subCol,
                    trailing: Container(
                      width: 42, height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: dark ? _kGreen : const Color(0xFFDDDDDD),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        alignment: dark ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 20, height: 20,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        ),
                      ),
                    ),
                    onTap: () => p.toggleDarkMode(),
                  ),

                  Divider(height: 1, color: divider, indent: 16, endIndent: 16),

                  // ── Admin (apenas para admins) ───────────────────────────
                  if (p.isAdmin) ...[
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_rounded,
                      iconColor: const Color(0xFFFF8C00),
                      title: 'Painel Admin',
                      subtitle: p.lang == 'es' ? 'Gestión de usuarios' : 'Gestão de usuários',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      onTap: () {
                        _close(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AdminScreen(currentAdmin: p.currentUser!),
                        ));
                      },
                    ),
                    Divider(height: 1, color: divider, indent: 16, endIndent: 16),
                  ],

                  const SizedBox(height: 8),

                  // ── Sair ─────────────────────────────────────────────────
                  _DrawerItem(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFCC3333),
                    title: p.lang == 'es' ? 'Cerrar sesión' : 'Sair',
                    subtitle: p.userName.isNotEmpty
                        ? p.userName.split(' ').first
                        : (p.lang == 'es' ? 'Cerrar cuenta' : 'Encerrar sessão'),
                    dark: dark,
                    textCol: const Color(0xFFCC3333),
                    subCol: subCol,
                    onTap: () async {
                      _close(context);
                      await AuthService.logout();
                      if (context.mounted) context.read<AppProvider>().clearUser();
                    },
                  ),
                ],
              ),
            ),

            // ── Rodapé ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: divider, width: 0.5)),
              ),
              child: Text(
                'MedCases Pro · Uso educacional',
                style: TextStyle(fontSize: 10, color: subCol, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item de linha do Drawer ────────────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool dark;
  final Color textCol;
  final Color subCol;
  final Widget? trailing;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.dark,
    required this.textCol,
    required this.subCol,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withValues(alpha: 0.12),
              border: Border.all(color: iconColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textCol)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: subCol, fontWeight: FontWeight.w500)),
          ])),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ]),
      ),
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
            GestureDetector(
              onTap: () => onTabChange(0),
              child: const BrandMark(small: true),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(p.userName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                ),

              ]),
              Text(p.lang == 'es' ? 'Apoyo clínico educativo' : 'Apoio clínico educacional',
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
            ])),

            // Botão hamburguer → abre Drawer lateral direito
            GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    p.lang.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6), letterSpacing: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.menu_rounded, size: 15,
                      color: const Color(0xFFFFE8A6).withValues(alpha: 0.85)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Bottom sheet de edição de perfil ─────────────────────────────────────────
class _ProfileEditSheet extends StatefulWidget {
  final AppProvider p;
  const _ProfileEditSheet({required this.p});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _profCtrl;
  late final TextEditingController _instCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final u = widget.p.currentUser;
    _nameCtrl = TextEditingController(text: u?.displayName ?? '');
    _profCtrl = TextEditingController(text: u?.profession ?? '');
    _instCtrl = TextEditingController(text: u?.institution ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _profCtrl.dispose();
    _instCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'O nome não pode ficar em branco.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.p.updateProfile(
        displayName: name,
        profession: _profCtrl.text.trim(),
        institution: _instCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Erro ao salvar. Tente novamente.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.p.darkMode;
    final bg = dark ? const Color(0xFF0E1A14) : Colors.white;
    final titleColor = dark ? Colors.white : const Color(0xFF07110d);
    final subColor = dark ? Colors.white54 : const Color(0xFF888888);
    final borderColor = dark ? const Color(0xFF1A3528) : const Color(0xFFE8E1D2);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: dark ? Colors.white24 : const Color(0xFFDDD8CE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFC5A365).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFFC5A365).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFFC5A365)),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Editar perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
                Text('Suas informações profissionais', style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w500)),
              ]),
            ]),
            const SizedBox(height: 24),

            // Campo — Nome
            _SheetField(
              label: 'Nome completo',
              controller: _nameCtrl,
              icon: Icons.badge_outlined,
              dark: dark,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // Campo — Profissão
            _SheetField(
              label: 'Profissão (ex: Médico, Residente)',
              controller: _profCtrl,
              icon: Icons.work_outline_rounded,
              dark: dark,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // Campo — Instituição
            _SheetField(
              label: 'Instituição / Hospital',
              controller: _instCtrl,
              icon: Icons.local_hospital_outlined,
              dark: dark,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),

            // Erro
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.red.withValues(alpha: 0.08),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
              ),
            ],

            const SizedBox(height: 20),

            // Botões
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _saving ? null : () => Navigator.pop(context),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    alignment: Alignment.center,
                    child: Text('Cancelar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: subColor)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _saving ? null : _save,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: const Color(0xFF07110d),
                      boxShadow: [BoxShadow(color: const Color(0xFF07110d).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFE8A6)))
                        : const Text('Salvar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6))),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Campo de texto interno do sheet de perfil ─────────────────────────────────
class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool dark;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  const _SheetField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.dark,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = dark ? const Color(0xFF162820) : const Color(0xFFF5F0E8);
    final textColor = dark ? Colors.white : const Color(0xFF07110d);
    final hintColor = dark ? Colors.white38 : const Color(0xFFAAAAAA);
    final borderColor = dark ? const Color(0xFF1A3528) : const Color(0xFFE8E1D2);

    return TextField(
      controller: controller,
      textInputAction: textInputAction,
      enableSuggestions: false,
      autocorrect: false,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: hintColor, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFFC5A365)),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFC5A365), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
