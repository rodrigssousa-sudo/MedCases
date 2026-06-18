import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show Timestamp;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/pre_login_screen.dart';
import 'screens/upgrade_screen.dart';
import 'screens/drugs_screen.dart';
import 'screens/protocols_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/ai_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/history_screen.dart';
import 'screens/maintenance_screen.dart';
import 'screens/cases_screen.dart';
import 'screens/prescripciones_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/professional_gate_screen.dart';
import 'screens/fontes_screen.dart';
import 'screens/home_screen.dart' show HomeScreen;
import 'screens/notes_screen.dart';
import 'screens/library_screen.dart';
import 'services/firestore_service.dart';
import 'services/activity_service.dart';
import 'services/gemini_service.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'widgets/brand_mark.dart';
import 'widgets/common_widgets.dart' show MedBreakpoints, AppHaptics;
import 'platform/web_impl.dart'
    if (dart.library.io) 'platform/web_stub.dart' as webPlatform;

Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  WidgetsFlutterBinding.ensureInitialized();

  // ── Trava orientação: portrait-only em iPhone e iPad ─────────────────────
  // Info.plist já declara apenas portrait para iOS, mas esta chamada cobre
  // também Android e garante que o SystemChrome respeite no runtime.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Cria o provider — sem await aqui, boot é disparado em background.
  final provider = AppProvider();

  // ── Future criado ANTES do runApp — sem `late`, sem estado global ────────
  // Ao usar `late final`, o iOS pode reutilizar o isolate após force-close e
  // encontrar a variável marcada como inicializada com um Future morto.
  // Solução: variável `final` comum, atribuída antes do runApp(), passada
  // como parâmetro para MedCasesApp → _AuthGate. Cada cold-start cria um
  // Future novo garantido.
  final firebaseInit = _bootInBackground(provider);

  // ── runApp() IMEDIATO — splash aparece em < 500ms ────────────────────────
  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: MedCasesApp(firebaseInit: firebaseInit),
    ),
  );
}

/// Executa todo o boot pesado após runApp() — a UI já está visível.
/// Timeout global de 10s: garante que o app NUNCA fica preso em loading
/// após fechamento forçado, suspensão pelo iOS/Android ou reinicialização.
/// 
/// IMPORTANTE: NÃO usa rethrow — qualquer falha aqui resulta em
/// snapshot.hasError = false → _AuthGate segue para o fluxo normal de auth.
/// Isso evita a tela "loading infinito" após force-close no iOS.
Future<void> _bootInBackground(AppProvider provider) async {
  // 1. SharedPreferences (local, rápido ~50ms) — preferências de tema/idioma
  try {
    await provider.loadPrefs().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('[MedCases] SharedPreferences indisponível: $e');
  }

  // 1b. Histórico de atividades recentes (local, sem rede)
  try {
    await ActivityService.load().timeout(const Duration(seconds: 2));
  } catch (_) {}

  // 2. Gemini key do storage local (síncrono, sem rede)
  try {
    await GeminiService.initFromStorage().timeout(const Duration(seconds: 2));
  } catch (_) {}

  // 2b. NotificationService — sem await para não atrasar boot; timezone init
  //     é síncrono mas leve (~20ms). Não faz nada no Web.
  NotificationService.init().catchError((e) {
    debugPrint('[MedCases] NotificationService.init falhou (ignorado): $e');
  });

  // 3. Firebase init — com timeout e sem rethrow
  // Guard `Firebase.apps.isEmpty` previne dupla inicialização quando o
  // processo iOS/Android é reutilizado após force-close ou suspensão.
  // Sem rethrow: se Firebase falhar, _AuthGate ainda tenta o fluxo web-auth
  // em vez de travar em loading infinito.
  try {
    if (Firebase.apps.isEmpty) {
      // Timeout de 8s: se Firebase demorar mais, o app não trava.
      // TimeoutException é capturada pelo catch abaixo — sem rethrow.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
    }
  } catch (e) {
    // NÃO faz rethrow — deixa _AuthGate lidar com a ausência do Firebase
    // (no Android, vai para LoginScreen; no Web, usa fluxo REST independente)
    // Cobre tanto TimeoutException quanto PlatformException do Firebase
    debugPrint('[MedCases] Firebase.initializeApp falhou (ignorado): $e');
  }

  // 4. Captura parâmetro ?ref= da URL e persiste em SharedPreferences
  // Feito ANTES de restoreSession para garantir que referral_code já está
  // disponível quando o formulario de registro for aberto.
  if (kIsWeb) {
    try {
      final refCode = webPlatform.webGetRefParam();
      if (refCode.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        // Só grava se ainda não houver código salvo (first-touch attribution)
        final existing = prefs.getString('referral_code') ?? '';
        if (existing.isEmpty) {
          await prefs.setString('referral_code', refCode);
          debugPrint('[Referral] Código capturado da URL: $refCode');
        }
      }
    } catch (e) {
      debugPrint('[Referral] Falha ao capturar ?ref= param: $e');
    }
  }

  // 5. Restaura sessão web em paralelo com timeout de segurança
  if (kIsWeb) {
    try {
      await AuthService.restoreSession().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}

class MedCasesApp extends StatelessWidget {
  final Future<void> firebaseInit;
  const MedCasesApp({super.key, required this.firebaseInit});

  @override
  Widget build(BuildContext context) {
    // context.select — rebuild APENAS quando darkMode muda (troca de tema).
    // Antes usava context.watch que rebuildava MaterialApp inteiro a cada
    // notifyListeners() do AppProvider — propagando rebuild para toda a árvore:
    // MaterialApp → _AuthGate → StreamBuilder → MainShell → HomeScreen (piscar).
    final darkMode = context.select<AppProvider, bool>((p) => p.darkMode);
    return NotificationOverlay(child: MaterialApp(
      title: 'MedCases Pro',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(false),
      darkTheme: _buildTheme(true),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      // ── Localização: informa ao Flutter os idiomas suportados ──────────────
      // Necessário para que widgets nativos (DatePicker, etc.) usem o idioma certo
      // e para que Localizations.localeOf(context) funcione corretamente.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'), // Português Brasil
        Locale('pt'),       // Português (genérico)
        Locale('es'),       // Espanhol
        Locale('en'),       // Inglês (fallback padrão do Flutter)
      ],
      home: _AuthGate(firebaseInit: firebaseInit),
      // ── Layout 100% responsivo — sem restrição de largura máxima ─────────────
      // O app ocupa toda a tela em qualquer dispositivo: Web, iPhone, iPad e tablet.
      // O layout responsivo é gerenciado internamente por MedBreakpoints:
      //   < 1024 px  → mobile/tablet shell (AppBar + bottom nav)
      //   >= 1024 px → desktop shell (sidebar lateral + conteúdo expandido)
      // Não há mais centralização forçada ou clamp de 560 px no iPad.
      builder: (context, child) => child ?? const SizedBox.shrink(),
    ));  // fecha NotificationOverlay
  }

  ThemeData _buildTheme(bool dark) => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: dark ? Brightness.dark : Brightness.light,
    // ── Drawer global: scrim escuro e sem largura forçada pelo tema ──────────
    drawerTheme: DrawerThemeData(
      scrimColor: Colors.black.withValues(alpha: 0.52),
      // width: null → cada Drawer define a própria via MediaQuery
    ),
    colorScheme: dark
        ? ColorScheme.dark(
            // ── Dark mode: neutro, menos verde, maior contraste ──────────
            primary:                    const Color(0xFF00E5FF),   // ouro
            onPrimary:                  const Color(0xFF1C1C1C),
            secondary:                  const Color(0xFF10B981),   // verde médio
            onSecondary:                const Color(0xFFFFFFFF),
            surface:                    const Color(0xFF252930),   // cards
            onSurface:                  const Color(0xFFFFFFFF),   // texto principal
            surfaceContainerHighest:    const Color(0xFF252930),
            surfaceContainerHigh:       const Color(0xFF252930),
            surfaceContainer:           const Color(0xFF252930),
            surfaceContainerLow:        const Color(0xFF1A1D23),
            surfaceDim:                 const Color(0xFF1A1D23),
            outline:                    const Color(0xFF374151),
            outlineVariant:             const Color(0xFF2D3340),
            error:                      const Color(0xFFFF7070),
            onError:                    Colors.white,
            inverseSurface:             const Color(0xFFFFFFFF),
            onInverseSurface:           const Color(0xFF1A1D23),
          )
        : ColorScheme.light(
            primary: const Color(0xFF0F1116),
            secondary: const Color(0xFF10B981),
            surface: const Color(0xFFFFFFFF),
            onSurface: const Color(0xFF0F1116),
            surfaceContainerHighest: const Color(0xFFF9F9F9),
          ),
    scaffoldBackgroundColor: dark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF),
    cardColor:               dark ? const Color(0xFF252930) : Colors.white,
    dividerColor:            dark ? const Color(0xFF2D3340) : const Color(0xFFE2E6EA),
    // Textos padrão do tema
    textTheme: dark ? const TextTheme(
      bodyLarge:   TextStyle(color: Color(0xFFFFFFFF)),
      bodyMedium:  TextStyle(color: Color(0xFFFFFFFF)),
      bodySmall:   TextStyle(color: Color(0xFFA8B2C1)),
      titleLarge:  TextStyle(color: Color(0xFFFFFFFF)),
      titleMedium: TextStyle(color: Color(0xFFFFFFFF)),
      titleSmall:  TextStyle(color: Color(0xFFA8B2C1)),
      labelLarge:  TextStyle(color: Color(0xFFFFFFFF)),
      labelMedium: TextStyle(color: Color(0xFFA8B2C1)),
      labelSmall:  TextStyle(color: Color(0xFF6B7280)),
    ) : null,
    // Transições de página suaves
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux:   FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );

  static ThemeData get _authTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F1116),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFC5A365),
      secondary: Color(0xFF10B981),
      surface: Color(0xFF0F1116),
      onSurface: Colors.white,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS:     CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux:   FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS:   CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────
// StatefulWidget — armazena _stableUser em state local para quebrar o loop:
//
//  LOOP ANTIGO (StatelessWidget):
//   _buildMaintenanceGate rebuild
//   → addPostFrameCallback → setUser()
//   → notifyListeners() (múltiplos: _loadAiKey, _syncFromFirestore, _startUsageTimer)
//   → MedCasesApp rebuild (context.watch<AppProvider>())
//   → _AuthGate rebuild (StatelessWidget recria tudo)
//   → StreamBuilder<UserModel?> resubscreve
//   → currentUserStream().snapshots() emite (escrita do _startUsageTimer no Firestore)
//   → _buildMaintenanceGate rebuild → addPostFrameCallback → ... infinito
//
//  SOLUÇÃO (StatefulWidget + _stableUser):
//   • _stableUser guarda o UserModel aprovado — nunca muda dentro de uma sessão
//   • setUser() é chamado em _onUserResolved(), que usa uma flag _setUserCalled
//     para garantir chamada única por sessão (uid estável)
//   • _buildMaintenanceGate não usa addPostFrameCallback — sem callbacks pendentes
//   • notifyListeners() do AppProvider causa rebuild apenas de widgets que usam
//     context.watch<AppProvider>() — não mais do _AuthGate (que usa context.read)
//   • _MaintenanceShell é um StatefulWidget próprio que ouve o stream de
//     manutenção de forma isolada, sem propagar rebuilds para cima
class _AuthGate extends StatefulWidget {
  final Future<void> firebaseInit;
  const _AuthGate({required this.firebaseInit});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  // ── Usuário estável — definido UMA vez por sessão ──────────────────────
  // Nunca é zerado por rebuilds do StreamBuilder. Só muda quando o uid
  // realmente troca (logout → login de outro usuário).
  UserModel? _stableUser;

  // ── Flag: setUser() já foi chamado para este uid ───────────────────────
  // Garante chamada única mesmo que o stream emita múltiplos snapshots
  // com o mesmo uid (escritas do _startUsageTimer, _syncFromFirestore etc.)
  String? _setUserCalledForUid;

  Widget _wrapAuth(Widget child) => Theme(
    data: MedCasesApp._authTheme,
    child: child,
  );

  // ── Chama setUser() uma única vez por uid ──────────────────────────────
  // Sempre chamado de dentro de um builder: (StreamBuilder / ValueListenableBuilder),
  // ou seja, DURANTE o build(). Por isso TODA mutação de state e toda chamada
  // que dispara notifyListeners() é adiada via addPostFrameCallback — o Flutter
  // proíbe setState() ou markNeedsBuild() durante o ciclo de build ativo.
  void _onUserResolved(UserModel user) {
    if (_setUserCalledForUid == user.uid) return; // já chamado para este uid

    // Marca a flag IMEDIATAMENTE (valor primitivo, sem setState) para que
    // chamadas síncronas subsequentes no mesmo frame sejam ignoradas.
    _setUserCalledForUid = user.uid;

    // Adia setState + setUser() para APÓS o término do frame de build atual.
    // Isso elimina o "setState() called during build" que o Xcode reportava
    // na linha 443 (chamada de _onUserResolved dentro do builder do StreamBuilder).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Atualiza _stableUser somente se o uid realmente mudou
      if (_stableUser?.uid != user.uid) {
        setState(() => _stableUser = user);
      }
      // setUser() dispara notifyListeners() — feito após setState para que
      // _stableUser já esteja definido quando os listeners reconstruírem
      context.read<AppProvider>().setUser(user);
    });
  }

  // ── Logout: zera state local para permitir novo ciclo de auth ─────────
  // Também chamado de dentro de builders (StreamBuilder / ValueListenableBuilder),
  // portanto setState() deve ser adiado para evitar "setState() during build".
  void _onLogout() {
    // Zera a flag imediatamente (sem setState) para bloquear re-entradas
    _setUserCalledForUid = null;
    if (_stableUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _stableUser = null);
      });
    }
  }

  // ── Web: ouve ValueNotifier (persiste valor entre rebuilds) ─────────────
  // StreamBuilder perde eventos emitidos ANTES de subscrever.
  // ValueListenableBuilder lê o valor atual imediatamente — sem race condition.
  Widget _buildWebAuthGate(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: AuthService.webUser,
      builder: (context, user, _) {
        // Sem usuário → preview pré-login com histórias públicas
        if (user == null) {
          _onLogout();
          return _wrapAuth(const PreLoginPreview());
        }

        // Usuário bloqueado
        if (user.isBlocked) {
          AuthService.logout();
          _onLogout();
          return _wrapAuth(_BlockedScreen(user: user));
        }

        // Usuário pendente
        if (user.isPending) {
          return _wrapAuth(_PendingScreen(user: user));
        }

        // Usuário aprovado → stream de manutenção (Web usa _WebMainShellGate)
        _onUserResolved(user);
        return _WebMainShellGate(user: user);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // _TimedSplash garante visibilidade mínima de 1.2s + fade-out suave.
    // Quando splash e boot terminam → readyBuilder() exibe o fluxo real de auth.
    // A lógica de auth (FutureBuilder → StreamBuilder) é preservada intacta.
    return _TimedSplash(
      bootFuture: widget.firebaseInit,
      splash: _wrapAuth(const _SplashScreen()),
      readyBuilder: (context) => _buildAuthFlow(context),
    );
  }

  /// Fluxo de autenticação original — sem nenhuma mudança de lógica.
  /// Extraído para método separado apenas para não misturar com o _TimedSplash.
  Widget _buildAuthFlow(BuildContext context) {
    // Etapa 1: aguarda Firebase init (em paralelo ao runApp)
    return FutureBuilder<void>(
      future: widget.firebaseInit,
      builder: (context, firebaseSnap) {
        // Firebase ainda inicializando → splash (pode ocorrer em edge cases)
        if (firebaseSnap.connectionState != ConnectionState.done) {
          return _wrapAuth(const _SplashScreen());
        }

        // Firebase falhou (Safari/iOS: cookies, IndexedDB, CORS, web preview)
        // No Web: NÃO mostra LoginScreen — o auth REST não depende do Firebase SDK.
        // Se mostrarmos LoginScreen aqui, o ValueListenableBuilder(webUser) nunca
        // é construído, então webUser.value mudar após login não causa rebuild.
        // Resultado: login funciona mas app fica preso na LoginScreen para sempre.
        // Solução: no Web, mesmo com Firebase SDK falhando, usamos _buildWebAuthGate.
        // No Android/iOS: Firebase SDK é obrigatório — LoginScreen é o fallback correto.
        if (firebaseSnap.hasError) {
          if (kIsWeb) return _buildWebAuthGate(context);
          return _wrapAuth(const LoginScreen());
        }

        // Etapa 2: Firebase OK → ouve stream de autenticação
        // WEB: usa webUserStream próprio (login REST não registra sessão no Firebase SDK)
        // ANDROID: usa authStateChanges do Firebase SDK + currentUserStream
        if (kIsWeb) {
          return _buildWebAuthGate(context);
        }

        return StreamBuilder<User?>(
          stream: AuthService.authStateChanges,
          builder: (context, authSnap) {
            if (authSnap.connectionState == ConnectionState.waiting) {
              return _wrapAuth(const _SplashScreen());
            }

            // Não autenticado → consent gate → login
            if (authSnap.data == null) {
              _onLogout();
              return _wrapAuth(const _ConsentGate());
            }

            // Etapa 3: autenticado → busca perfil Firestore
            return StreamBuilder<UserModel?>(
              stream: AuthService.currentUserStream(),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) {
                  // Se já temos _stableUser, não mostra splash de novo
                  // (evita piscar ao receber snapshot atualizado do Firestore)
                  if (_stableUser != null) {
                    return _MaintenanceShell(
                      user: _stableUser!,
                      wrapAuth: _wrapAuth,
                    );
                  }
                  return _wrapAuth(const _SplashScreen());
                }

                final user = userSnap.data;

                if (user == null) {
                  AuthService.logout();
                  _onLogout();
                  return _wrapAuth(const LoginScreen());
                }

                if (user.isBlocked) {
                  AuthService.logout();
                  _onLogout();
                  return _wrapAuth(_BlockedScreen(user: user));
                }

                if (user.isPending) {
                  return _wrapAuth(_PendingScreen(user: user));
                }

                // Etapa 4: perfil OK → registra setUser() UMA vez + exibe MainShell
                // _onUserResolved() usa flag de uid — idempotente mesmo que o stream
                // emita múltiplos snapshots (escritas do timer, sync de favoritos, etc.)
                _onUserResolved(user);

                // _stableUser pode ser null no primeiro frame antes de setState concluir.
                // Usa o user atual do stream como fallback seguro.
                return _MaintenanceShell(
                  user: _stableUser ?? user,
                  wrapAuth: _wrapAuth,
                );
              },
            );
          },
        );
      },
    );
  }
}

// ── Maintenance Shell — StatefulWidget isolado ────────────────────────────────
// Ouve o stream de manutenção de forma completamente isolada do _AuthGate.
// Rebuilds deste widget NÃO propagam para cima — quebra o segundo vetor do loop:
//
//  LOOP ANTIGO: maintenanceStream emite → _buildMaintenanceGate (método de
//    _AuthGate) reconstrói → addPostFrameCallback → setUser() → notifyListeners()
//    → MedCasesApp rebuild → _AuthGate rebuild → StreamBuilder<UserModel?> rebuild
//    → maintenanceStream emite novamente → ...
//
//  AGORA: maintenanceStream emite → _MaintenanceShellState.build() reconstrói
//    (widget isolado) → NÃO propaga para _AuthGate — loop quebrado.
class _MaintenanceShell extends StatefulWidget {
  final UserModel user;
  final Widget Function(Widget) wrapAuth;
  const _MaintenanceShell({required this.user, required this.wrapAuth});

  @override
  State<_MaintenanceShell> createState() => _MaintenanceShellState();
}

class _MaintenanceShellState extends State<_MaintenanceShell> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: FirestoreService.maintenanceStream(),
      builder: (context, maintSnap) {
        final isMaintenanceEnabled = maintSnap.data?['enabled'] == true;
        final maintenanceMessage   = maintSnap.data?['message'] as String? ?? '';

        // Admin / Master passam pela manutenção direto
        final bypassMaintenance = widget.user.isAdmin || widget.user.isMaster;

        if (isMaintenanceEnabled && !bypassMaintenance) {
          return widget.wrapAuth(MaintenanceScreen(message: maintenanceMessage));
        }

        // Aprovado → MainShell (com gate de declaração profissional)
        // NÃO há addPostFrameCallback aqui — setUser() é gerenciado pelo
        // _AuthGateState._onUserResolved() com flag de idempotência.
        return const ProfessionalDeclarationGateWidget(
          child: MainShell(),
        );
      },
    );
  }
}


// ── Consent Gate (Android) ───────────────────────────────────────────────────
class _ConsentGate extends StatefulWidget {
  const _ConsentGate();
  @override
  State<_ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<_ConsentGate> {
  bool? _hasConsented;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await ConsentGate.hasConsented();
    if (mounted) setState(() => _hasConsented = ok);
  }

  void _onAccepted() => setState(() => _hasConsented = true);

  @override
  Widget build(BuildContext context) {
    if (_hasConsented == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1116),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
      );
    }
    if (_hasConsented!) return const LoginScreen();
    return Stack(children: [
      const LoginScreen(),
      Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.55))),
      Positioned(
        left: 0, right: 0, bottom: 0,
        child: ConsentModal(
          lang: Localizations.localeOf(context).languageCode == 'es' ? 'es' : 'pt',
          onAccepted: _onAccepted,
        ),
      ),
    ]);
  }
}

// ── Splash Screen — v3: tagline atualizada + mesma animação scale+slide ───────
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.72, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
    _slide = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    // Logo posicionado no terço superior (h * 0.32 do topo)
    final logoTop = h * 0.28;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1116), // novo fundo — mais escuro que #0A1610
      body: Stack(children: [
        // Detalhe geométrico de fundo sutil — diferente do splash anterior
        Positioned(
          top: -h * 0.05,
          right: -80,
          child: Container(
            width: 260, height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0E7C52).withValues(alpha: 0.06),
            ),
          ),
        ),
        Positioned(
          bottom: h * 0.15,
          left: -60,
          child: Container(
            width: 180, height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF13A06A).withValues(alpha: 0.04),
            ),
          ),
        ),

        // ── Conteúdo animado ─────────────────────────────────────────────
        Positioned(
          top: logoTop,
          left: 0, right: 0,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo — glow verde (antes era dourado)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0E7C52).withValues(alpha: 0.28),
                            blurRadius: 52, spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const BrandMark(small: false),
                    ),

                    const SizedBox(height: 20),

                    // Nome do app — peso 700 (antes era 900)
                    const Text(
                      'MedCases Pro',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Tagline — posicionamento de produto
                    Text(
                      'IA Clínica de bolso',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF13A06A).withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Indicador de carga — posicionado no terço inferior ───────────
        Positioned(
          bottom: h * 0.18,
          left: 0, right: 0,
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: const Color(0xFF0E7C52).withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Iniciando...',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.25),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Timed Splash wrapper ──────────────────────────────────────────────────────
// Garante que a splash fica visível por pelo menos [minDuration] ms,
// independentemente de quão rápido o boot terminar.
// Sem _TimedSplash: se o Firebase inicializar em < 200ms, a splash pisca
// brevemente — visível apenas em cold starts rápidos (cache quente, WiFi).
// Com _TimedSplash: a splash sempre exibe por mínimo 1.2s → transição suave.
//
// Lógica: dois semáforos em paralelo —
//   • timer 1.2s           → _minTimeDone = true
//   • bootFuture.complete  → _bootDone    = true
// Quando AMBOS são true → chama readyBuilder() (exibe home/login).
// O AnimatedSwitcher no _AuthGate cuida do fade-out automático.
class _TimedSplash extends StatefulWidget {
  final Future<void> bootFuture;
  final Widget Function(BuildContext) readyBuilder;
  final Widget splash;

  const _TimedSplash({
    required this.bootFuture,
    required this.readyBuilder,
    required this.splash,
  });

  @override
  State<_TimedSplash> createState() => _TimedSplashState();
}

class _TimedSplashState extends State<_TimedSplash> {
  static const _kMinMs = 1200; // mínimo 1.2s

  bool _minTimeDone = false;
  bool _bootDone    = false;

  @override
  void initState() {
    super.initState();

    // Timer mínimo
    Future<void>.delayed(const Duration(milliseconds: _kMinMs), () {
      if (mounted) setState(() => _minTimeDone = true);
    });

    // Boot future (Firebase + prefs + auth)
    widget.bootFuture.whenComplete(() {
      if (mounted) setState(() => _bootDone = true);
    });
  }

  bool get _ready => _minTimeDone && _bootDone;

  @override
  Widget build(BuildContext context) {
    // AnimatedSwitcher com fade 350ms entre splash e conteúdo real
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      // FadeTransition personalizado — evita o piscar de borda do default
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: _ready
          ? KeyedSubtree(
              key: const ValueKey('ready'),
              child: widget.readyBuilder(context),
            )
          : KeyedSubtree(
              key: const ValueKey('splash'),
              child: widget.splash,
            ),
    );
  }
}

// ── Tela pendente ─────────────────────────────────────────────────────────────
class _PendingScreen extends StatefulWidget {
  final UserModel user;
  const _PendingScreen({required this.user});

  @override
  State<_PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<_PendingScreen> {
  bool _checking = false;
  String? _checkMsg;

  @override
  void initState() {
    super.initState();
    // Auto-aprovação imediata: qualquer usuário que chegue aqui é aprovado
    // automaticamente sem necessidade de ação do administrador.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoApproveNow());
  }

  /// Auto-aprova o usuário imediatamente ao exibir a tela.
  ///
  /// Build 102 Fix: no nativo (iOS/Android), além de atualizar o doc Firestore
  /// via approveUser, chama ensureUserProfileExists para garantir que o doc
  /// está completo. O currentUserStream() do AuthGate reage ao snapshot
  /// atualizado e navega direto para MainShell — sem intervenção manual.
  Future<void> _autoApproveNow() async {
    if (!mounted) return;
    setState(() => _checking = true);
    try {
      // Usa ensureUserProfileExists para reparar doc + garantir approved
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await AuthService.ensureUserProfileExists(
          firebaseUser,
          platform: kIsWeb ? 'web' : 'ios',
        );
        debugPrint('[PendingScreen] ensureUserProfileExists concluído — uid=${firebaseUser.uid}');
      } else {
        // Fallback: se currentUser for null, tenta approveUser diretamente
        await AuthService.approveUser(widget.user.uid, 'system-auto');
      }
    } catch (e) {
      debugPrint('[PendingScreen] Auto-aprovação falhou (continuando): $e');
    }
    if (!mounted) return;

    // Para o fluxo Web: atualiza webUser para que o ValueListenableBuilder reaja
    if (kIsWeb) {
      final approvedUser = widget.user.copyWith(
        status: UserStatus.approved,
        approvedAt: DateTime.now(),
        approvedBy: 'system-auto',
      );
      await AuthService.saveSession(approvedUser);
      AuthService.webUser.value = approvedUser;
    }
    // Para o nativo (iOS/Android): currentUserStream() já reagirá ao
    // snapshot atualizado no Firestore — não é necessário manipular webUser.
    if (mounted) setState(() => _checking = false);
  }

  /// Verificação manual (botão) — mantida como fallback de UI.
  Future<void> _checkApproval() async {
    setState(() { _checking = true; _checkMsg = null; });
    // Tenta auto-aprovação novamente
    await _autoApproveNow();
    if (mounted && _checking) {
      setState(() {
        _checking = false;
        _checkMsg = 'Aprovando sua conta...';
      });
    }
  }

  bool get _isEs {
    // Lê idioma da sessão; não temos AppProvider aqui (pré-auth)
    // Usa detecção simples baseada no locale do dispositivo como fallback
    return false; // padrão pt-BR para este contexto
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1116),
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
                    'Olá, ${widget.user.displayName.split(' ').first}!\n\nSua conta está aguardando aprovação do administrador. Você receberá acesso assim que for aprovada.',
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
                  Text(widget.user.email, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),

              // Feedback de verificação
              if (_checkMsg != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    _checkMsg!,
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8), height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Botão "Verificar aprovação"
              ElevatedButton.icon(
                onPressed: _checking ? null : _checkApproval,
                icon: _checking
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F1116)),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_checking ? 'Verificando...' : 'Verificar aprovação'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A365),
                  foregroundColor: const Color(0xFF0F1116),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async { await AuthService.logout(); },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sair e entrar com outra conta'),
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
      backgroundColor: const Color(0xFF0F1116),
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
                    'Acceso suspendido',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu cuenta ha sido suspendida por el administrador.\n\nComunícate con soporte para más información.',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7), height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async { await AuthService.logout(); },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Volver al inicio de sesión'),
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

// ── Web Main Shell Gate ───────────────────────────────────────────────────────
// Chama setUser() de forma assíncrona no initState e só exibe MainShell após
// o Future completar. Isso garante que o token está cacheado no AuthService
// ANTES de qualquer tela (ex: HistoryScreen) tentar chamar loadPublicHistories().
//
// SEM este widget, o fluxo era:
//   addPostFrameCallback → MainShell já na tela → HistoryScreen.initState já rodou
//   → loadPublicHistories() chamado → setUser ainda não rodou → token vazio → []
//
// COM este widget:
//   initState → await setUser() → setState(_ready=true) → MainShell exibido
//   → loadPublicHistories() chamado no listener da tab → token já existe → ✅
class _WebMainShellGate extends StatefulWidget {
  final UserModel user;
  const _WebMainShellGate({required this.user});

  @override
  State<_WebMainShellGate> createState() => _WebMainShellGateState();
}

class _WebMainShellGateState extends State<_WebMainShellGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final p = context.read<AppProvider>();
    // Só chama setUser se o provider ainda não tem este usuário — evita
    // chamar duas vezes durante rebuilds do ValueListenableBuilder.
    if (p.currentUser?.uid != widget.user.uid) {
      // Timeout de segurança de 3s: se setUser() travar (rede lenta),
      // mostra o app mesmo assim — dados mínimos já carregados pelo loadPrefs().
      await p.setUser(widget.user).timeout(
        const Duration(seconds: 3),
        onTimeout: () {}, // silencioso — app abre com dados locais
      );
    } else {
      await p.checkGeminiSession().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    // Enquanto setUser não completou, exibe splash — evita que HistoryScreen
    // monte e tente ler publicHistories antes do token existir.
    if (!_ready) {
      return const _SplashScreen();
    }
    return const ProfessionalDeclarationGateWidget(
      child: MainShell(),
    );
  }
}

// ── Shell principal ───────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// ValueNotifier estático para navegação de tabs a partir do Drawer.
  /// O Drawer não recebe onTabChange — usa este notifier para comunicar ao _MainShellState.
  /// Uso: MainShell.pendingTab.value = 2; → navega para IA.
  /// Após processar, _MainShellState reseta para -1 automaticamente.
  static final pendingTab = ValueNotifier<int>(-1);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  // tabs: 0=Home 1=Rx/Proto 2=IA(FAB) 3=H.Clínica 4=Calculadoras
  // (Adulto/Cockpit é acessado via card na HomeScreen)
  int _tab = 0;
  // sub-tab dentro do combo Rx+Proto: 0=Rx, 1=Protocolos
  int _rxProtoSub = 0;

  // Scroll-reveal AppBar removido — era exibido de forma intermitente e
  // perturbava a navegação nas telas internas. Infraestrutura mantida mínima.

  // ── Performance: telas criadas uma única vez no initState ─────────────────
  // CRÍTICO: HomeScreen e _RxProtoCombo NÃO podem ser instanciadas dentro de
  // build() — cada notifyListeners() do AppProvider reconstrói o MainShell e
  // recriaria essas telas do zero, causando loop de piscar.
  // Solução: criar TODAS as telas no initState com callbacks estáveis (métodos
  // da classe, não lambdas inline) e reutilizá-las via IndexedStack.
  late final List<Widget> _staticScreens;

  // ── Callbacks estáveis para HomeScreen ────────────────────────────────────
  // Lambdas inline no build() são recriadas a cada rebuild — geram instabilidade.
  // Métodos da classe são referências estáveis: mesma instância entre rebuilds.
  void _onTabChange(int t) {
    // Fecha o teclado SEMPRE que o utilizador muda de aba.
    // Isso previne o bug de "teclado automático" onde o FocusNode da aba anterior
    // (especialmente o AiScreen tab 2) permanece ativo no IndexedStack e
    // re-abre o teclado quando o utilizador navega de volta para a Home.
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = t);
  }
  void _onSubTabChange(int i) => setState(() => _rxProtoSub = i);
  void _onOpenNotes()         => showNotesSheet(context);

  void _onScrollNotification(ScrollNotification n) {
    // Scroll-reveal AppBar removido — não faz nada.
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Ouve pendingTab para navegação iniciada pelo Drawer (sem onTabChange no _AppDrawer)
    MainShell.pendingTab.addListener(_onPendingTab);

    // Instancia TODAS as telas UMA VEZ — IndexedStack reutiliza entre rebuilds.
    // Cada tela é envolta em RepaintBoundary — isola o repaint de cada screen,
    // evitando que a mudança de tab force repaint das telas não visíveis.
    _staticScreens = [
      RepaintBoundary(                             // 0 — tela inicial
        child: HomeScreen(
          onTabChange:    _onTabChange,
          onSubTabChange: _onSubTabChange,
          openProtocol:   _openProtocol,
          onOpenNotes:    _onOpenNotes,
          onCheckUpdate:  _forceShowUpdate,
        ),
      ),
      RepaintBoundary(                             // 1 — Rx/Proto combo
        child: _RxProtoCombo(
          subTab: _rxProtoSub,
          onSubTabChange: _onSubTabChange,
        ),
      ),
      const RepaintBoundary(child: AiScreen()),    // 2
      const RepaintBoundary(child: HistoryScreen()), // 3
      const RepaintBoundary(child: ToolsScreen()), // 4
      const RepaintBoundary(child: LibraryScreen()), // 5
    ];

    // ── Auto-Update / Cache Eviction (Service Worker) ──────────────────────
    // Registra window.onFlutterWebUpdateAvailable ANTES do primeiro frame.
    // Se um SW novo foi detectado antes do boot, a flag _mcUpdatePending já
    // está `true` → banner aparecerá assim que o widget for exibido.
    if (kIsWeb) UpdateService.setupUpdateListener();

    // Verifica novidades ao abrir o app (delay para não competir com splash)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _checkAppUpdate();
      });
    });
  }

  Future<void> _checkAppUpdate() async {
    try {
      final data = await FirestoreService.loadAppUpdate();
      if (data.isEmpty) return;
      if (data['active'] != true) return;
      final version = data['version'] as String? ?? '';
      if (version.isEmpty) return;
      // Verificar se o usuário já viu essa versão
      final prefs = await SharedPreferences.getInstance();
      final seen  = prefs.getString('last_seen_update') ?? '';
      if (seen == version) return;
      // Mostrar modal
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _AppUpdateDialog(data: data),
        );
        await prefs.setString('last_seen_update', version);
      }
    } catch (_) {}
  }

  /// Força exibição do modal de novidades — ignora cache (last_seen_update).
  /// Chamado quando o usuário toca em "Novidades" na HomeScreen.
  Future<void> _forceShowUpdate() async {
    try {
      final data = await FirestoreService.loadAppUpdate();
      if (data.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma novidade publicada no momento.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      if (data['active'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nenhuma novidade ativa no momento.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      // Exibe o modal sempre — independente do last_seen_update
      if (mounted) {
        final version = data['version'] as String? ?? '';
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _AppUpdateDialog(data: data),
        );
        // Atualiza o cache para que não apareça automaticamente na próxima abertura
        if (version.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_seen_update', version);
        }
      }
    } catch (_) {}
  }

  void _onPendingTab() {
    final t = MainShell.pendingTab.value;
    if (t >= 0 && mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _tab = t.clamp(0, 5));
      MainShell.pendingTab.value = -1; // reset imediato após consumir
    }
  }

  @override
  void dispose() {
    MainShell.pendingTab.removeListener(_onPendingTab);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Lifecycle do app — controla timer de uso e logout automático.
  //
  // Estados relevantes:
  //   resumed   → app visível e em foreground (conta tempo de tela)
  //   inactive  → transição (ex: chamada entrando) — pausa o timer
  //   paused    → app em background (Android/iOS) — pausa o timer
  //   hidden    → app oculto sem ser destruído (Flutter 3.13+) — pausa
  //   detached  → processo sendo encerrado — para o timer e desconecta
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final provider = context.read<AppProvider>();

    switch (state) {
      case AppLifecycleState.resumed:
        // App voltou ao foreground — retoma contagem de tempo de tela
        provider.resumeUsageTimer();
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // App foi para background ou ficou inativo — pausa o timer
        // (não cancela — mantém estado para retomar ao voltar)
        provider.pauseUsageTimer();
        // Logout automático apenas se usuário não marcou "Manter conectado"
        if (state == AppLifecycleState.paused) {
          AuthService.isKeepLoggedInEnabled().then((keep) {
            if (!keep) AuthService.logout();
          });
        }
        break;

      case AppLifecycleState.detached:
        // Processo sendo encerrado — para e grava tudo antes de morrer
        provider.pauseUsageTimer();
        AuthService.isKeepLoggedInEnabled().then((keep) {
          if (!keep) AuthService.logout();
        });
        break;
    }
  }

  void _openProtocol(String id) {
    // Abre o detalhe do protocolo diretamente via bottom sheet
    // sem precisar trocar de aba ou gerenciar pendingId
    openProtocolById(context, id);
  }

  @override
  Widget build(BuildContext context) {
    // context.select — rebuild apenas quando darkMode OU lang muda.
    // Evita que os 8+ notifyListeners() do boot rebuildem toda a árvore.
    final dark = context.select<AppProvider, bool>((p) => p.darkMode);
    final _    = context.select<AppProvider, String>((p) => p.lang); // reativa nav bar ao trocar idioma
    // p via read — _AppDrawer (abre on-tap) e p.t() já reativado pelo select acima
    final p = context.read<AppProvider>();

    // ── LayoutBuilder: breakpoint via constraints do parent imediato ──────────
    // MOTIVO: MediaQuery.of(context).size.width pode ser stale no Flutter Web
    // durante redimensionamento do browser ou ao alternar para o emulador mobile
    // do Chrome DevTools (F12 → device toolbar). LayoutBuilder reage frame-a-frame
    // às BoxConstraints do Scaffold pai — não depende do cache do MediaQuery.
    //
    // BREAKPOINTS (Build 136-B — Split-View iPad Fix):
    //   < 768 px   → mobile shell (BottomNav + AppBar — idêntico ao iOS/Android)
    //   768–1023px → desktop shell (sidebar + IndexedStack normal)
    //   ≥ 1024 px  → desktop shell com Split-View quando na tab AI:
    //                  40% HomeDashboard (sempre visível) + 60% AiScreen
    //                  Em qualquer outra tab: sidebar + IndexedStack normal.
    // iPad 13" (≈1366px) → sempre Split-View quando usuário abre IA.
    // iPad mini (768px) → desktop shell normal sem split.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Desktop/tablet largo: sidebar lateral + conteúdo (com ou sem split)
        if (width >= 768) {
          return _buildDesktopShell(context, dark, p, width);
        }
        // Mobile / tablet estreito / browser redimensionado — layout nativo
        return _buildMobileShell(context, dark, p);
      },
    );
  }

  /// Layout desktop: Row(sidebar | conteúdo) — sem AppHeader (barra superior removida)
  /// Build 136-B: width >= 1024 + tab == 2 (AI) → Split-View 40/60
  Widget _buildDesktopShell(BuildContext context, bool dark, AppProvider p, double width) {
    final bg        = dark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF);
    final divColor  = dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB);
    final stackIdx  = _tab.clamp(0, _staticScreens.length - 1);

    // Split-View: iPad 13" / desktop largo quando na tela de IA (tab 2)
    // Exibe HomeDashboard (40%) + AiScreen (60%) simultaneamente.
    // Em outras tabs o IndexedStack normal garante a tela selecionada.
    final bool showSplit = width >= 1024 && _tab == 2;

    return Scaffold(
      backgroundColor: bg,
      endDrawer: _AppDrawer(p: p),
      // Scrim escuro explícito para iPad/desktop (reforça o DrawerTheme global)
      drawerScrimColor: Colors.black.withValues(alpha: 0.52),
      body: Row(
        children: [
          // ── Sidebar de navegação vertical (contém logo + nav + hamburger) ──
          SafeArea(
            right: false,
            child: Builder(
              builder: (scaffoldCtx) => _DesktopSidebar(
                currentTab: _tab,
                dark: dark,
                p: p,
                // Volta para Home (tab 0) e scrolla para o topo
                onLogoTap: () { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _tab = 0); },
                onTabChange: (t) { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _tab = t); },
                // Builder garante que scaffoldCtx está DENTRO do Scaffold
                // → Scaffold.of() encontra o endDrawer corretamente
                onOpenDrawer: () => Scaffold.of(scaffoldCtx).openEndDrawer(),
              ),
            ),
          ),

          // ── Divisor vertical sutil (sidebar → conteúdo) ───────────────────
          Container(width: 1, color: divColor),

          // ── Área de conteúdo principal ─────────────────────────────────────
          Expanded(
            child: SafeArea(
              left: false,
              child: Column(
                children: [
                  Expanded(
                    child: showSplit
                        // ── SPLIT-VIEW: HomeDashboard 40% | AiScreen 60% ──────
                        ? _buildSplitView(dark, divColor)
                        // ── IndexedStack normal para todas as outras tabs ──────
                        : RepaintBoundary(
                            child: IndexedStack(
                              index: stackIdx,
                              children: _staticScreens,
                            ),
                          ),
                  ),
                  // Banner de auto-update
                  ValueListenableBuilder<bool>(
                    valueListenable: UpdateService.swUpdateAvailable,
                    builder: (_, hasUpdate, __) =>
                        hasUpdate ? const _UpdateBanner() : const SizedBox.shrink(),
                  ),
                  _LegalBar(dark: dark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build 136-B — Split-View para iPad 13" / desktop largo na tab IA.
  /// HomeDashboard (40%) + divisor + AiScreen (60%).
  /// Ambos os painéis ficam vivos — sem remontar ao alternar.
  Widget _buildSplitView(bool dark, Color divColor) {
    return Row(
      children: [
        // ── Painel esquerdo: HomeDashboard (40%) ──────────────────────────────
        Flexible(
          flex: 40,
          child: RepaintBoundary(
            child: _staticScreens[0], // HomeScreen — sempre visível no split
          ),
        ),

        // ── Divisor central ───────────────────────────────────────────────────
        Container(width: 1, color: divColor),

        // ── Painel direito: AiScreen (60%) ────────────────────────────────────
        Flexible(
          flex: 60,
          child: RepaintBoundary(
            child: _staticScreens[2], // AiScreen — sempre ativo no split
          ),
        ),
      ],
    );
  }

  /// Layout mobile/tablet: Scaffold com AppBar no topo + bottom nav
  Widget _buildMobileShell(BuildContext context, bool dark, AppProvider p) {
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF);
    final navBg = dark ? const Color(0xFF0F1116) : Colors.white;
    final navBorder = dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB);
    final stackIdx = _tab.clamp(0, _staticScreens.length - 1);
    final isHome   = _tab == 0;

    return Scaffold(
      backgroundColor: bg,
      endDrawer: _AppDrawer(p: p),
      // Scrim escuro explícito para iPad/tablet (reforça o DrawerTheme global)
      drawerScrimColor: Colors.black.withValues(alpha: 0.52),
      // ── AppBar HOME: sempre visível, cor verde luxury ─────────────────────
      // Tabs 1-5: sem appBar fixo — scroll-reveal via overlay no body.
      appBar: isHome
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Builder(
                builder: (scaffoldCtx) => _MobileAppBar(
                  dark: dark,
                  currentTab: _tab,
                  lang: p.lang,
                  isHome: true,
                  onLogoTap: () { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _tab = 0); },
                  onMenuTap: () => Scaffold.of(scaffoldCtx).openEndDrawer(),
                ),
              ),
            )
          : null,
      // ── Body: IndexedStack + scroll-reveal bar para tabs não-HOME ────────
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) { _onScrollNotification(n); return false; },
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true, // Sempre remove o top do MediaQuery — cada camada gerencia o próprio inset
          child: SizedBox.expand(
            child: Stack(
              children: [
                // ── Conteúdo principal — deslocado para baixo da status bar ──
                // Padding.top = statusBarHeight garante que TODAS as telas do
                // IndexedStack começam abaixo da status bar do dispositivo,
                // sem depender de SafeArea(top:true) em cada tela individualmente.
                Padding(
                  padding: EdgeInsets.only(
                    top: isHome ? 0 : MediaQuery.of(context).padding.top,
                  ),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: UpdateService.swUpdateAvailable,
                    builder: (ctx, hasUpdate, _) => Stack(
                      children: [
                        IndexedStack(index: stackIdx, children: _staticScreens),
                        if (hasUpdate) const _UpdateBanner(),
                      ],
                    ),
                  ),
                ),

                // Scroll-reveal AppBar removido — não aparece mais nas telas internas.
              ],
            ),
          ),
        ),
      ),
      // ── Bottom navigation bar (native notch) + FAB docked ─────────────────
      // Build 99 — substituído o Stack manual por BottomAppBar nativo com
      // CircularNotchedRectangle + FloatingActionButtonLocation.centerDocked.
      // Isso elimina o bug TestFlight onde o FAB sobrepunha H.Clínica e
      // bloqueava o 5.º ícone (Ferramentas).
      //   • floatingActionButton: _NavFab (widget separado)
      //   • floatingActionButtonLocation: centerDocked
      //   • BottomAppBar: notchMargin 5, Row com SizedBox(width:60) no centro
      //   • _LegalBar abaixo do BottomAppBar via bottomNavigationBar Column
      // Fix #5: oculta o FAB quando o teclado do chat está aberto.
      // ValueListenableBuilder reage ao ValueNotifier estático do AiScreen
      // sem forçar rebuild de todo o Scaffold — apenas o FAB é reconstruído.
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: AiScreen.chatKeyboardOpen,
        builder: (_, kbOpen, child) => AnimatedScale(
          scale: kbOpen ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: AnimatedOpacity(
            opacity: kbOpen ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 160),
            child: child,
          ),
        ),
        child: _buildAiCenterFab(dark, p),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // ── Bottom nav: BottomAppBar nativo + LegalBar ────────────────────────
      // Build 103 FIX: A Column interna tinha 48(icons) + ~38.6(LegalBar) = 86.6pt
      // mas o BottomAppBar padrão Flutter 3.x tem height mínimo 80pt — clampeia
      // e causa BOTTOM OVERFLOWED BY 6.5 PIXELS na Column interna.
      //
      // SOLUÇÃO: BottomAppBar contém APENAS os ícones (48pt fixo, sem overflow).
      // A _LegalBar é movida para o bottomNavigationBar como Column envolvente:
      //   Column[
      //     BottomAppBar (48pt, só ícones),
      //     SafeArea(top:false) > _LegalBar (absorve homeIndicator + disclaimer)
      //   ]
      // O Scaffold lê a altura total da Column corretamente via IntrinsicHeight
      // e aloca body = screen - appBar - (48 + legalBar + homeIndicator).
      bottomNavigationBar: SafeArea(
        bottom: true,
        top: false,
        left: false,
        right: false,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── BottomAppBar: APENAS ícones (48pt fixo, sem SafeArea, sem overflow) ──
          BottomAppBar(
            color: navBg,
            shape: const CircularNotchedRectangle(),
            notchMargin: 5.0,
            elevation: 0,
            padding: EdgeInsets.zero,
            height: 42, // 42pt — padrão premium Bruno: barra fina, ícone+label colados
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 0 — INICIO
                _buildNavBtn(
                  0,
                  Icons.home_rounded,
                  p.lang == 'es' ? 'Inicio' : 'Início',
                  dark, p,
                ),
                // 3 — HISTÓRIA CLÍNICA
                _buildNavBtn(
                  3,
                  Icons.assignment_ind_outlined,
                  'H. Clínica',
                  dark, p,
                ),
                // ── Slot central — FAB docked ─────────────────────────────
                const SizedBox(width: 60),
                // 5 — BIBLIOTECA
                _buildNavBtn(
                  5,
                  Icons.menu_book_rounded,
                  'Biblioteca',
                  dark, p,
                ),
                // 4 — FERRAMENTAS
                _buildNavBtn(
                  4,
                  Icons.calculate_rounded,
                  p.lang == 'es' ? 'Herramientas' : 'Ferramentas',
                  dark, p,
                ),
              ],
            ),
          ),
          // ── Disclaimer legal fora do BottomAppBar — sem risco de overflow ──
          _LegalBar(dark: dark, insideSafeArea: true),
        ],
        ),
      ),
    );
  }

  // Build 104c — barra premium Bruno: 42pt, ícone 20pt + label 9pt colados (1pt gap).
  // Geometria mínima: padding vertical zero no ícone, tudo centralizado nos 42pt.
  Widget _buildNavBtn(int idx, IconData icon, String label, bool dark, dynamic p) {
    final active        = _tab == idx;
    final activeColor   = dark ? const Color(0xFF10B981) : const Color(0xFF0A7C4E);
    final inactiveColor = dark ? const Color(0xFF6B7280) : const Color(0xFFB0B8C0);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _tab = idx);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              // padding vertical zero — ícone ocupa apenas 20pt dos 42pt da barra
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: active
                    ? (dark
                        ? const Color(0xFF10B981).withValues(alpha: 0.14)
                        : const Color(0xFF0A7C4E).withValues(alpha: 0.09))
                    : Colors.transparent,
              ),
              child: Icon(icon, size: 21,
                color: active ? activeColor : inactiveColor),
            ),
            const SizedBox(height: 1), // 1pt entre ícone e label — colados
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? activeColor : inactiveColor,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Double-tap FAB: reset completo da sessão clínica (Build 105) ───────────
  //
  // Fluxo:
  //   1. HapticFeedback.lightImpact() — toque físico sutil no aparelho
  //   2. Navega para aba de IA (caso não esteja lá)
  //   3. Dispara _clearChat() via AiScreen.clearChatCallback
  //      → salva sessão anterior no histórico
  //      → limpa mensagens e reinserve o greeting
  //      → limpa campo de texto e remove foco
  //   4. p.resetAiSessionFull()
  //      → cancela streaming ativo
  //      → limpa _aiHistory (contexto enviado à API)
  //      → zera _sessionMemory (diag, meds, labs, language lock)
  //   5. SnackBar bilíngue confirma o reset ao médico
  void _resetAndStartNewChat() {
    final p    = context.read<AppProvider>();
    final isEs = p.lang == 'es';

    // 1. Feedback tátil sutil — médico sente fisicamente o reset
    AppHaptics.light(context);

    // 2. Garante navegação para a aba de IA
    if (_tab != 2) {
      setState(() => _tab = 2);
    }

    // 3. Reseta a UI do chat via callback estático do AiScreen
    //    (funciona mesmo quando AiScreen está desmontado — o callback
    //    é registrado no initState e removido no dispose do AiScreen)
    final clearFn = AiScreen.clearChatCallback.value;
    if (clearFn != null) {
      clearFn();
    }

    // 4. Reset profundo do contexto clínico no provider
    //    clearFn() já chama p.clearAiHistory(), mas resetAiSessionFull()
    //    vai além: também zera _sessionMemory (diag, meds, labs, language lock)
    //    e cancela qualquer stream ativo que clearFn() possa ter perdido.
    p.resetAiSessionFull();

    // 5. Confirma visualmente ao médico com SnackBar clínico bilíngue
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.restart_alt_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEs
                        ? 'Nueva consulta iniciada — contexto anterior eliminado'
                        : 'Nova consulta iniciada — contexto anterior eliminado',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0A7C4E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
    }
  }

  // ── FAB ConnectMind AI — Build 100: nativo centerDocked, 46×46 (-20%) ──────────
  // Retorna um widget pill autónomo que o Scaffold encaixa na entalhação do
  // BottomAppBar via FloatingActionButtonLocation.centerDocked.
  // Não usa mais Transform.translate manual — o Flutter posiciona o FAB
  // corretamente acima da barra sem sobrepor os botões laterais.
  Widget _buildAiCenterFab(bool dark, dynamic p) {
    final isAiActive = _tab == 2;
    final gradStart  = isAiActive
        ? const Color(0xFF008CA4)
        : (dark ? const Color(0xFF374151) : const Color(0xFF0A2540));
    final gradEnd    = isAiActive
        ? const Color(0xFF0A2540)
        : (dark ? const Color(0xFF252930) : const Color(0xFF0F3B68));
    final glowColor  = const Color(0xFF00E5FF);

    return GestureDetector(
      // Tap simples: navega para a aba de IA
      onTap: () {
        AppHaptics.light(context);
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _tab = 2);
      },
      // Double-tap: reset completo da sessão clínica (Build 105)
      // O médico sente que o chat foi zerado via haptic sutil +
      // SnackBar informativo. Nenhum contexto residual da consulta
      // anterior contamina a próxima resposta da IA.
      onDoubleTap: () => _resetAndStartNewChat(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradStart, gradEnd],
          ),
          shape: BoxShape.circle,
          boxShadow: isAiActive
              ? [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.60),
                    blurRadius: 16,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: const Color(0xFF0A2540).withValues(alpha: 0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
          border: Border.all(
            color: isAiActive
                ? const Color(0xFF00E5FF).withValues(alpha: 0.75)
                : const Color(0xFF005E9C).withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.psychology_rounded,
          size: 22,
          color: isAiActive ? const Color(0xFF00E5FF) : Colors.white,
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE APP BAR — topo do Scaffold mobile com logo + ações contextuais + hambúrguer
// Isolado do _AppHeader (desktop) para não quebrar o layout desktop.
// Quando currentTab == 2 (IA MedCases), injeta botões "Histórico" e "Limpar"
// antes do hambúrguer, usando os ValueNotifiers estáticos do AiScreen.
// ─────────────────────────────────────────────────────────────────────────────
class _MobileAppBar extends StatelessWidget {
  final bool dark;
  final int  currentTab;
  final String lang;
  final bool isHome;
  final VoidCallback onLogoTap;
  final VoidCallback onMenuTap;

  const _MobileAppBar({
    required this.dark,
    required this.currentTab,
    required this.lang,
    required this.isHome,
    required this.onLogoTap,
    required this.onMenuTap,
  });

  // Tab index da tela de IA (deve corresponder a _staticScreens[2])
  static const _kAiTab = 2;
  // Paleta dourada para botões AI (combina com o _WaHeader)
  static const _kGold  = Color(0xFFC5A365);
  static const _kGoldL = Color(0xFFFFE8A6);

  @override
  Widget build(BuildContext context) {
    // AppBar: header escuro uniforme em todos os contextos (dark mode)
    final bg = dark ? const Color(0xFF0F1116) : (isHome ? const Color(0xFF0A7C4E) : const Color(0xFFF0F5F1));
    final borderCol = dark ? const Color(0xFF2D3340) : (isHome ? const Color(0xFF085E3A) : const Color(0xFFD4E0D8));
    final iconBg = dark
        ? Colors.white.withValues(alpha: 0.08)
        : (isHome ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF0A7C4E).withValues(alpha: 0.08));
    final iconBorder = dark
        ? Colors.white.withValues(alpha: 0.12)
        : (isHome ? Colors.white.withValues(alpha: 0.30) : const Color(0xFF0A7C4E).withValues(alpha: 0.20));
    final iconColor = dark
        ? Colors.white.withValues(alpha: 0.85)
        : (isHome ? Colors.white : const Color(0xFF0A7C4E));

    // ── AppBar decoration ─────────────────────────────────────────────────────
    // Dark mode: header escuro uniforme (#0F1116) + sutil glow cyan na HOME.
    // Light mode: verde médico na HOME, neutro nas demais.
    final BoxDecoration barDecoration = BoxDecoration(
      color: bg,
      border: Border(bottom: BorderSide(color: borderCol, width: 0.5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? 0.40 : 0.12),
          blurRadius: 8.0,
          offset: const Offset(0, 3),
        ),
        if (dark && isHome)
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
      ],
    );

    return Container(
      decoration: barDecoration,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // ── Logo / Brand clicável → volta para Home ────────────────
                GestureDetector(
                  onTap: onLogoTap,
                  child: const BrandMark(small: true),
                ),
                const Spacer(),

                // ── Botões contextuais da IA (só na aba 2) ─────────────────
                if (currentTab == _kAiTab) ...[
                  // Botão Conectar IA — aparece quando IA não está conectada
                  ValueListenableBuilder<bool>(
                    valueListenable: AiScreen.aiConnectedNotifier,
                    builder: (_, isConnected, __) => isConnected
                        ? const SizedBox.shrink()
                        : GestureDetector(
                            onTap: AiScreen.openSettingsCallback.value,
                            child: Container(
                              height: 38,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFFC5A365),
                                border: Border.all(
                                    color: const Color(0xFFFFE8A6).withValues(alpha: 0.4),
                                    width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.link_rounded, size: 14,
                                      color: Color(0xFF1A1100)),
                                  const SizedBox(width: 5),
                                  Text(
                                    lang == 'es' ? 'Conectar IA' : 'Conectar IA',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A1100),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),

                  // Botão Histórico — badge com contagem de sessões salvas
                  // IMPORTANTE: usa ValueListenableBuilder para AMBOS os notifiers
                  // (historyCount e openHistoryCallback) para garantir que o onTap
                  // sempre leia o callback atual — não o valor nulo do momento do build.
                  ValueListenableBuilder<VoidCallback?>(
                    valueListenable: AiScreen.openHistoryCallback,
                    builder: (_, callback, __) => ValueListenableBuilder<int>(
                    valueListenable: AiScreen.historyCountNotifier,
                    builder: (_, count, __) => GestureDetector(
                      onTap: callback,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 38, height: 38,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: iconBg,
                              border: Border.all(color: iconBorder, width: 1),
                            ),
                            child: Icon(Icons.history_rounded, size: 20, color: iconColor),
                          ),
                          if (count > 0)
                            Positioned(
                              top: -3, right: 5,
                              child: Container(
                                width: 15, height: 15,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _kGold,
                                ),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1A1100),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ), // fecha ValueListenableBuilder<VoidCallback?>

                  // Botão Limpar — só aparece quando há mensagens reais
                  ValueListenableBuilder<bool>(
                    valueListenable: AiScreen.hasMessagesNotifier,
                    builder: (_, hasMessages, __) => hasMessages
                        ? GestureDetector(
                            onTap: AiScreen.clearChatCallback.value,
                            child: Container(
                              height: 38,
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: _kGold,
                                border: Border.all(
                                    color: _kGoldL.withValues(alpha: 0.4), width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  lang == 'es'
                                      ? 'Limpiar'
                                      : 'Limpar',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A1100),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],

                // ── Botão hambúrguer → abre endDrawer ─────────────────────
                GestureDetector(
                  onTap: onMenuTap,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: iconBg,
                      border: Border.all(color: iconBorder, width: 1),
                    ),
                    child: Icon(Icons.menu_rounded, size: 20, color: iconColor),
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

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP SIDEBAR — navegação vertical estilo rail
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopSidebar extends StatelessWidget {
  final int currentTab;
  final bool dark;
  final AppProvider p;
  final ValueChanged<int> onTabChange;
  final VoidCallback onOpenDrawer;
  final VoidCallback onLogoTap; // navega para Home (tab 0)

  const _DesktopSidebar({
    required this.currentTab,
    required this.dark,
    required this.p,
    required this.onTabChange,
    required this.onOpenDrawer,
    required this.onLogoTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg          = dark ? const Color(0xFF0F1116) : const Color(0xFFFFFFFF);
    final activeCol   = dark ? const Color(0xFF10B981) : const Color(0xFF0A7C4E);
    final inactiveCol = dark ? const Color(0xFF6B7280) : const Color(0xFFADB5BD);
    final activeBg    = dark
        ? const Color(0xFF10B981).withValues(alpha: 0.12)
        : const Color(0xFF0A7C4E).withValues(alpha: 0.08);
    final isEs        = p.lang == 'es';


    return RepaintBoundary(
      child: Container(
        width: MedBreakpoints.sidebarWidth,
        color: bg,
        child: Column(
          children: [
            // ── Logo M+ no TOPO — clicável → volta para Home ────────────
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Tooltip(
                message: 'Início',
                preferBelow: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLogoTap,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0E7C52), Color(0xFF064D32)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0E7C52).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 46, height: 46,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('M+',
                            style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900,
                              color: Color(0xFFFFE8A6))),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── Divisor sutil ─────────────────────────────────────────────
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),

            const SizedBox(height: 10),

            // ── Itens de navegação ────────────────────────────────────────
            _SidebarItem(
              icon: Icons.home_rounded,
              label: isEs ? 'Inicio' : 'Início',
              active: currentTab == 0,
              dark: dark,
              activeCol: activeCol,
              inactiveCol: inactiveCol,
              activeBg: activeBg,
              onTap: () => onTabChange(0),
            ),
            _SidebarItem(
              icon: Icons.psychology_rounded,
              label: 'IA',
              active: currentTab == 2,
              dark: dark,
              activeCol: dark ? const Color(0xFF00E5FF) : const Color(0xFF008CA4),
              inactiveCol: inactiveCol,
              activeBg: const Color(0xFF00E5FF).withValues(alpha: 0.10),
              onTap: () => onTabChange(2),
            ),
            _SidebarItem(
              icon: Icons.folder_shared_rounded,
              label: isEs ? 'H. Clínica' : 'H. Clínica',
              active: currentTab == 3,
              dark: dark,
              activeCol: activeCol,
              inactiveCol: inactiveCol,
              activeBg: activeBg,
              onTap: () => onTabChange(3),
            ),
            _SidebarItem(
              icon: Icons.menu_book_rounded,
              label: isEs ? 'Biblio.' : 'Biblio.',
              active: currentTab == 5,
              dark: dark,
              activeCol: activeCol,
              inactiveCol: inactiveCol,
              activeBg: activeBg,
              onTap: () => onTabChange(5),
            ),
            _SidebarItem(
              icon: Icons.calculate_rounded,
              label: isEs ? 'Calc.' : 'Calc.',
              active: currentTab == 4,
              dark: dark,
              activeCol: activeCol,
              inactiveCol: inactiveCol,
              activeBg: activeBg,
              onTap: () => onTabChange(4),
            ),

            const Spacer(),

            // ── Divisor antes do rodapé ───────────────────────────────────
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            const SizedBox(height: 8),

            // ── Botão hambúrguer na BASE — abre drawer de perfil/menu ─────
            Tooltip(
              message: p.userName.isNotEmpty ? p.userName : 'Menu',
              preferBelow: false,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onOpenDrawer,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.transparent,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ícone hambúrguer (3 linhas) — claramente indica "menu"
                        Icon(
                          Icons.menu_rounded,
                          size: 26,
                          color: inactiveCol,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Menu',
                          style: TextStyle(
                            fontSize: 7.0,
                            fontWeight: FontWeight.w500,
                            color: inactiveCol,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool dark;
  final Color activeCol;
  final Color inactiveCol;
  final Color activeBg;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.dark,
    required this.activeCol,
    required this.inactiveCol,
    required this.activeBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = active ? activeCol : inactiveCol;
    return Tooltip(
      message: label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active ? activeBg : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: iconColor),
              if (label.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: iconColor,
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Combo Rx + Protocolos ─────────────────────────────────────────────────────
// _RxProtoCombo — StatefulWidget com sub-tab interno.
// CRÍTICO: mora em _staticScreens (criado no initState do MainShell) para que
// notifyListeners() do AppProvider não o recrie a cada rebuild do pai.
// O sub-tab é estado interno (_sub) — independente de rebuild externo.
// onSubTabChange notifica o MainShell apenas para sincronismo (ex: deep links).
class _RxProtoCombo extends StatefulWidget {
  final int subTab;
  final ValueChanged<int> onSubTabChange;

  const _RxProtoCombo({
    required this.subTab,
    required this.onSubTabChange,
  });

  @override
  State<_RxProtoCombo> createState() => _RxProtoComboState();
}

class _RxProtoComboState extends State<_RxProtoCombo> {
  late int _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.subTab;
  }

  void _select(int i) {
    if (_sub == i) return;
    setState(() => _sub = i);
    widget.onSubTabChange(i);
  }

  @override
  Widget build(BuildContext context) {
    // context.select — rebuild apenas quando darkMode ou lang muda
    final dark = context.select<AppProvider, bool>((p) => p.darkMode);
    // p via read — usado somente para p.t() (só muda quando lang muda)
    final p = context.read<AppProvider>();
    final bg = dark ? const Color(0xFF121E18) : const Color(0xFFFFFFFF);
    final borderCol = dark ? const Color(0xFF2A3A30) : const Color(0xFFE0E4E8);

    return Column(children: [
      // ── Seletor de sub-tab ────────────────────────────────────────────────
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: dark ? const Color(0xFF1A2620) : Colors.white,
            border: Border.all(color: borderCol, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.18 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(children: [
            _SubTabBtn(
              icon: Icons.description_rounded,
              label: p.t('prescriptions'),
              active: _sub == 0,
              dark: dark,
              onTap: () => _select(0),
            ),
            Container(width: 1, height: 24, color: borderCol),
            _SubTabBtn(
              icon: Icons.medication_rounded,
              label: p.t('drugs'),
              active: _sub == 1,
              dark: dark,
              onTap: () => _select(1),
            ),
            Container(width: 1, height: 24, color: borderCol),
            _SubTabBtn(
              icon: Icons.emergency_rounded,
              label: p.t('protocols'),
              active: _sub == 2,
              dark: dark,
              onTap: () => _select(2),
            ),
            Container(width: 1, height: 24, color: borderCol),
            _SubTabBtn(
              icon: Icons.folder_open_rounded,
              label: p.t('cases'),
              active: _sub == 3,
              dark: dark,
              onTap: () => _select(3),
            ),
          ]),
        ),
      ),
      // ── Conteúdo ──────────────────────────────────────────────────────────
      Expanded(
        child: IndexedStack(
          index: _sub,
          children: const [
            PrescripcionesScreen(),
            DrugsScreen(),
            ProtocolsScreen(),
            CasesScreen(),
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
    final activeColor   = dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1116);
    final inactiveColor = dark
        ? Colors.white.withValues(alpha: 0.30)
        : const Color(0xFFB8BEC4);
    final activeBg = dark
        ? const Color(0xFF2D3340)   // kBorderSoft — active highlight
        : const Color(0xFF0F1116).withValues(alpha: 0.09);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: active ? activeBg : Colors.transparent,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: (dark
                              ? const Color(0xFFFFE8A6)
                              : const Color(0xFF0F1116))
                          .withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(
              icon,
              size: 14,
              color: active ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? activeColor : inactiveColor,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Mini barra de contexto (header recolhido nas sub-telas) ─────────────────
// ignore: unused_element
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D23), Color(0xFF162E1F), Color(0xFF1A5C3A)],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
          child: Row(children: [
            // Breadcrumb: logo → nome da aba
            GestureDetector(
              onTap: onHome,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const BrandMark(small: true),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                const SizedBox(width: 3),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
              ]),
            ),
            const Spacer(),
            // Botão home
            GestureDetector(
              onTap: onHome,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.13),
                    width: 0.8,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    Icons.home_rounded,
                    size: 13,
                    color: const Color(0xFFFFE8A6).withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Inicio',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFE8A6),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 6),
            // Botão menu
            GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.13),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.menu_rounded,
                  size: 16,
                  color: const Color(0xFFFFE8A6).withValues(alpha: 0.85),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Banner de Auto-Update (Service Worker) ────────────────────────────────────
// Exibido como overlay fixo na parte inferior do app quando um novo SW é detectado.
// Ocupa toda a largura, fundo verde escuro com borda dourada sutil.
// "Atualizar Agora" → chama UpdateService.applyUpdate() → SKIP_WAITING → reload.
// "✕" → dispensa o banner sem atualizar (aparece novamente ao redetectar SW).
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg   = dark ? const Color(0xFF0F2A1C) : const Color(0xFF0F3D2E);
    final border = const Color(0xFFC5A365);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              top: BorderSide(color: border.withValues(alpha: 0.45), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Ícone
              const Icon(Icons.system_update_alt_rounded,
                  color: Color(0xFFC5A365), size: 20),
              const SizedBox(width: 10),
              // Texto
              const Expanded(
                child: Text(
                  'Uma nova atualização do MedCases está disponível!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botão "Atualizar Agora"
              TextButton(
                onPressed: UpdateService.applyUpdate,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A365),
                  foregroundColor: const Color(0xFF07110d),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Atualizar'),
              ),
              // Botão fechar
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white54, size: 18),
                onPressed: UpdateService.dismissUpdate,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Dispensar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Barra legal ───────────────────────────────────────────────────────────────
class _LegalBar extends StatelessWidget {
  final bool dark;
  /// true quando o widget já está dentro de um SafeArea pai (ex.: bottom nav).
  /// Evita duplo recuo — SafeArea aninhado sem parâmetro correto some do layout.
  final bool insideSafeArea;
  const _LegalBar({required this.dark, this.insideSafeArea = false});

  @override
  Widget build(BuildContext context) {
    // context.select — rebuild apenas quando lang muda
    final isEs = context.select<AppProvider, bool>((p) => p.lang == 'es');
    final bg        = dark ? const Color(0xFF0F1116) : const Color(0xFFF0F2F4);
    final border    = dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6);
    // Apple 1.4.1 — disclaimer deve ser legível: opacidade 0.85 no dark, cor
    // sólida no light. Não usar valores abaixo de 0.70.
    final textColor = dark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF5A6370);

    // Texto exigido pela Apple guideline 1.4.1 — permanece visível em todas as telas
    final disclaimer = isEs
        ? 'Herramienta educativa de apoyo clínico. La decisión y verificación de dosis son responsabilidad exclusiva del médico asistente.'
        : 'Ferramenta educacional de apoio clínico. A decisão e verificação de doses são de responsabilidade exclusiva do médico assistente.';

    final content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      // Apple 1.4.1 — texto legível mas compacto
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 11, color: textColor.withValues(alpha: 0.7)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            disclaimer,
            style: TextStyle(
              // Apple 1.4.1 — mínimo 10px; 11px garante leitura
              fontSize: 11, color: textColor,
              height: 1.3, letterSpacing: 0.1,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );

    // insideSafeArea=true → conteúdo puro (SafeArea já aplicado pelo pai).
    // insideSafeArea=false → envolve com SafeArea(top:false) para standalone.
    if (insideSafeArea) return content;
    return SafeArea(top: false, child: content);
  }
}

// ── Task 9: URLs de Privacy Policy e Terms of Use (Guideline 5.1) ────────────
const String _kPrivacyUrl = 'https://www.promedcases.com/politica-de-privacidade';
const String _kTermsUrl   = 'https://www.promedcases.com/termos-de-uso';
const String _kSiteUrl    = 'https://promedcases.com/';


// ── Drawer lateral — redesenhado (v2) ─────────────────────────────────────────
class _AppDrawer extends StatefulWidget {
  final AppProvider p;
  const _AppDrawer({required this.p});

  @override
  State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer> {
  AppProvider get p => widget.p;

  void _close(BuildContext context) => Navigator.of(context).pop();

  // ── Dialog de eliminação de conta ────────────────────────────────────────
  // ── Task 8 — Exclusão de Conta Obrigatória (Apple Guideline 5.1.1(v)) ─────
  // Diálogo em 2 etapas:
  //   Etapa 1: aviso + digitação de "EXCLUIR" para confirmação
  //   Etapa 2: campo de senha (necessário para re-autenticação iOS/Android)
  // Chama AuthService.deleteAccount() que apaga: subcoleções Firestore,
  // documento users/{uid}, credencial Firebase Auth e sessão local.
  Future<void> _showDeleteAccountDialog(BuildContext context, AppProvider p) async {
    final isEs = p.lang == 'es';
    final dark = p.darkMode;
    final uid  = p.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    // ── Strings bilíngues ─────────────────────────────────────────────────
    final titleT   = isEs ? 'Eliminar cuenta'  : 'Excluir minha conta';
    final body1    = isEs
        ? 'Esta acción es PERMANENTE e IRREVERSIBLE.\n\n'
          '• Todos tus datos clínicos serán eliminados\n'
          '• Historial de consultas con la IA\n'
          '• Anotaciones y configuraciones\n'
          '• Tu acceso a MedCases Pro\n\n'
          'Esta operación no puede deshacerse.'
        : 'Esta ação é PERMANENTE e IRREVERSÍVEL.\n\n'
          '• Todos os seus dados clínicos serão apagados\n'
          '• Histórico de consultas com a IA\n'
          '• Anotações e configurações\n'
          '• Seu acesso ao MedCases Pro\n\n'
          'Esta operação não pode ser desfeita.';
    final step1Label  = isEs ? 'Para continuar, escribe EXCLUIR a continuación:' : 'Para continuar, digite EXCLUIR abaixo:';
    final step2Title  = isEs ? 'Confirma tu contraseña' : 'Confirme sua senha';
    final step2Label  = isEs ? 'Contraseña actual' : 'Senha atual';
    final step2Hint   = isEs ? 'Ingresa tu contraseña para confirmar' : 'Digite sua senha para confirmar';
    final cancelT     = isEs ? 'Cancelar'  : 'Cancelar';
    final continueT   = isEs ? 'Continuar' : 'Continuar';
    final confirmT    = isEs ? 'Eliminar mi cuenta' : 'Excluir minha conta';
    final wordError   = isEs ? 'Escribe EXCLUIR para continuar' : 'Digite EXCLUIR para continuar';

    final confirmCtrl = TextEditingController();
    final passCtrl    = TextEditingController();
    String? confirmErr;
    String? passErr;
    bool step2         = false; // false = etapa 1 (palavra), true = etapa 2 (senha)
    bool loading       = false;
    bool passObscure   = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {

          // ── Botão "Excluir definitivamente" ──────────────────────────────
          Future<void> doDelete() async {
            if (loading) return;
            final pwd = passCtrl.text.trim();
            if (!kIsWeb && pwd.isEmpty) {
              setS(() => passErr = isEs
                  ? 'Contraseña obligatoria'
                  : 'Senha obrigatória');
              return;
            }
            setS(() { loading = true; passErr = null; });
            Navigator.pop(ctx);

            // Loading overlay enquanto processa
            if (context.mounted) {
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const _DeletingAccountOverlay(),
              );
            }

            final result = await AuthService.deleteAccount(
              uid: uid,
              password: kIsWeb ? null : pwd,
            );

            // Fecha overlay
            if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

            if (result.success) {
              if (context.mounted) context.read<AppProvider>().clearUser();
              return;
            }

            if (result.requiresReauth && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isEs
                    ? 'Por seguridad, inicia sesión de nuevo e intenta otra vez.'
                    : 'Por segurança, faça login novamente e tente outra vez.'),
                backgroundColor: const Color(0xFFCC3333),
                duration: const Duration(seconds: 4),
              ));
              return;
            }

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result.error ??
                    (isEs ? 'Error al eliminar la cuenta.' : 'Erro ao excluir conta.')),
                backgroundColor: const Color(0xFFCC3333),
                duration: const Duration(seconds: 4),
              ));
            }
          }

          return AlertDialog(
            backgroundColor: dark ? const Color(0xFF252930) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFCC3333).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: Color(0xFFCC3333), size: 22),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(titleT, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: Color(0xFFCC3333))),
              ),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!step2) ...[ // ── Etapa 1: aviso + palavra ──────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC3333).withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCC3333).withValues(alpha: 0.25)),
                      ),
                      child: Text(body1, style: TextStyle(
                        fontSize: 12.5, height: 1.6,
                        color: dark ? Colors.white70 : const Color(0xFF333344),
                      )),
                    ),
                    const SizedBox(height: 16),
                    Text(step1Label, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: dark ? Colors.white60 : const Color(0xFF555555),
                    )),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmCtrl,
                      autofocus: true,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, letterSpacing: 2.0),
                      decoration: InputDecoration(
                        hintText: 'EXCLUIR',
                        errorText: confirmErr,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFCC3333), width: 1.5),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFCC3333)),
                        ),
                      ),
                      onChanged: (_) {
                        if (confirmErr != null) {
                          setS(() => confirmErr = null);
                        }
                      },
                    ),
                  ] else ...[ // ── Etapa 2: confirmação de senha (nativo) ─
                    Text(step2Title, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : const Color(0xFF222222),
                    )),
                    const SizedBox(height: 6),
                    Text(step2Label, style: TextStyle(
                      fontSize: 12, color: dark ? Colors.white60 : Colors.grey[600],
                    )),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passCtrl,
                      autofocus: true,
                      obscureText: passObscure,
                      decoration: InputDecoration(
                        hintText: step2Hint,
                        errorText: passErr,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFCC3333), width: 1.5),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(passObscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                              size: 20),
                          onPressed: () =>
                              setS(() => passObscure = !passObscure),
                        ),
                      ),
                      onChanged: (_) {
                        if (passErr != null) setS(() => passErr = null);
                      },
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: Text(cancelT,
                    style: const TextStyle(color: Color(0xFF6B7280))),
              ),
              if (!step2)
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFCC3333),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (confirmCtrl.text.trim().toUpperCase() != 'EXCLUIR') {
                      setS(() => confirmErr = wordError);
                      return;
                    }
                    // Web não precisa de senha — vai direto para exclusão
                    if (kIsWeb) {
                      Navigator.pop(ctx);
                      _executeDeleteAccount(context, p, uid, null);
                    } else {
                      setS(() => step2 = true);
                    }
                  },
                  child: Text(continueT),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFCC3333),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: loading ? null : doDelete,
                  child: loading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(confirmT),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Executa deleteAccount com loading overlay.
  /// Separado do dialog para permitir chamada direta na branch Web (sem senha).
  Future<void> _executeDeleteAccount(
    BuildContext context,
    AppProvider p,
    String uid,
    String? password,
  ) async {
    final isEs = p.lang == 'es';

    // Loading overlay
    if (context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _DeletingAccountOverlay(),
      );
    }

    final result = await AuthService.deleteAccount(uid: uid, password: password);

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (result.success) {
      if (context.mounted) context.read<AppProvider>().clearUser();
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error ??
            (isEs ? 'Error al eliminar la cuenta.' : 'Erro ao excluir conta.')),
        backgroundColor: const Color(0xFFCC3333),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usa context.watch DENTRO do StatefulWidget para que rebuilds do drawer
    // fiquem isolados — não fecham o drawer ao mudar darkMode/offlineMode.
    final p       = context.watch<AppProvider>();
    final dark    = p.darkMode;
    final bg      = dark ? const Color(0xFF1A1D23) : const Color(0xFFFAFBFC);
    final divider = dark ? const Color(0xFF2D3340) : const Color(0xFFF0EDE8);
    final textCol = dark ? const Color(0xFFEEEEEE) : const Color(0xFF0F1116);
    final subCol  = dark ? Colors.white.withValues(alpha: 0.36) : const Color(0xFF9AA0A8);

    final initials = p.userName.isNotEmpty
        ? p.userName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : 'MC';

    // ── Largura responsiva: max 300 em tablets/desktop, 72% em mobile ────────
    final screenW   = MediaQuery.of(context).size.width;
    final isTablet  = screenW >= 600;
    final drawerW   = isTablet ? screenW.clamp(0.0, 300.0) : screenW * 0.72;

    // ── Shape: cantos arredondados à esquerda apenas em tablets ──────────────
    // (endDrawer desliza da direita → arredondar topLeft + bottomLeft)
    final drawerShape = isTablet
        ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft:    Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
          )
        : const RoundedRectangleBorder(borderRadius: BorderRadius.zero);

    return Drawer(
      width: drawerW,
      backgroundColor: bg,
      shape: drawerShape,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── CABEÇALHO — perfil do usuário ──────────────────────────────────
          _DrawerHeader(
            p: p,
            initials: initials,
            dark: dark,
            onClose: () => _close(context),
            onEditProfile: () {
              _close(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _ProfileEditSheet(p: p),
              );
            },
          ),

          // ── MENU — lista rolável ────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              children: [

                // ─── 1. Bloco: Admin (TOPO — visível sem scroll) ─────────────
                // Permissões inalteradas: if (p.isAdmin || p.isMaster)
                if ((p.isAdmin || p.isMaster) && p.currentUser != null) ...[
                  _DrawerSectionLabel(
                    label: p.isMaster ? '⚡ MASTER' : '⚡ ADMIN',
                    dark: dark,
                    color: const Color(0xFFFF8C00),
                  ),
                  _DrawerBlock(
                    children: [
                      _DrawerRow(
                        icon: Icons.admin_panel_settings_rounded,
                        iconColor: const Color(0xFFFF8C00),
                        title: p.lang == 'es' ? 'Panel Admin' : 'Painel Admin',
                        subtitle: 'Usuários · Links · Indicações',
                        dark: dark,
                        textCol: textCol,
                        subCol: subCol,
                        showDivider: false,
                        onTap: () {
                          _close(context);
                          final admin = p.currentUser;
                          if (admin == null) return;
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => AdminScreen(currentAdmin: admin),
                          ));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],

                // ─── 2. Bloco: Premium (upgrade) — oculto em modo de revisão Apple
                if (!kIsReviewMode)
                  _DrawerBlock(
                    children: [
                      _DrawerItemPremium(
                        dark: dark,
                        onTap: () {
                          _close(context);
                          showUpgradeScreen(context, lang: p.lang);
                        },
                      ),
                    ],
                  ),

                // ─── 3. Acesso Rápido ─────────────────────────────────────
                // APPLE COMPLIANCE (Build 93) — bloco ACCESO RÁPIDO oculto.
                // Guideline 1.4.1/1.4.2: links diretos para Protocolos,
                // Farmacología, Asistente IA e Nueva Consulta foram considerados
                // ferramentas clínicas pela revisão Apple.
                // Widget _DrawerQuickAccess preservado intacto — reativar:
                //   1. Remover o bloco de comentário abaixo
                //   2. Restaurar _DrawerSectionLabel + _DrawerQuickAccess
                // if (kIsWeb) ...[ // alternativa: reativar apenas no Web
                //   _DrawerSectionLabel(
                //     label: p.lang == 'es' ? 'ACCESO RÁPIDO' : 'ACESSO RÁPIDO',
                //     dark: dark,
                //   ),
                //   _DrawerQuickAccess(p: p, dark: dark, onClose: () => _close(context)),
                // ],

                // ─── 4. Sua Atividade (oculto se vazio) ──────────────────
                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'TU ACTIVIDAD' : 'SUA ATIVIDADE',
                  dark: dark,
                ),
                _DrawerActivity(
                  p: p,
                  dark: dark,
                  onClose: () => _close(context),
                ),

                // ─── 5. Suporte ──────────────────────────────────────────
                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'SOPORTE' : 'SUPORTE',
                  dark: dark,
                ),
                _DrawerBlock(
                  dividerColor: divider,
                  children: [
                    // ── Fontes e Diretrizes (Task 6 — App Store Guideline 1.4.1) ──
                    _DrawerRow(
                      icon: Icons.menu_book_rounded,
                      iconColor: const Color(0xFF0D7A55),
                      title: p.lang == 'es' ? 'Fuentes y Directrices' : 'Fontes e Diretrizes',
                      subtitle: p.lang == 'es'
                          ? 'AHA, Harrison, ESC, IDSA y más'
                          : 'AHA, Harrison, ESC, IDSA e mais',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      onTap: () {
                        _close(context);
                        showFontesScreen(context, isEs: p.lang == 'es');
                      },
                    ),
                    _DrawerRow(
                      icon: Icons.support_agent_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: p.lang == 'es' ? 'Feedback y Soporte' : 'Feedback e Suporte',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      showDivider: false,
                      onTap: () {
                        _close(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _FeedbackSheet(p: p, dark: dark),
                        );
                      },
                    ),
                  ],
                ),

                // ─── 7. Preferências ────────────────────────────────────
                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'PREFERENCIAS' : 'PREFERÊNCIAS',
                  dark: dark,
                ),
                _DrawerBlock(
                  dividerColor: divider,
                  children: [
                    // Idioma — toca para alternar PT ↔ ES
                    _DrawerRow(
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF1E88E5),
                      title: 'Idioma',
                      subtitle: p.lang == 'es'
                          ? 'Toca para cambiar a Português'
                          : 'Toque para mudar para Español',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      trailing: _LangBadge(lang: p.lang),
                      onTap: () {
                        final newLang = p.lang == 'pt' ? 'es' : 'pt';
                        p.setLang(newLang);
                        SharedPreferences.getInstance()
                            .then((prefs) => prefs.setString('lang', newLang));
                      },
                    ),
                    // Tema
                    _DrawerRow(
                      icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      iconColor: dark ? const Color(0xFFFFCC44) : const Color(0xFF6B6B8A),
                      title: p.lang == 'es' ? 'Apariencia' : 'Aparência',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      trailing: _ThemeToggle(dark: dark),
                      onTap: () => p.toggleDarkMode(),
                    ),
                    // Vibração tátil removida do menu lateral (Apple App Store review)
                    // A funcionalidade haptic continua activa internamente via AppHaptics;
                    // apenas o controle visual foi ocultado para conformidade com as
                    // diretrizes de UI limpa e revisão Apple/Google (Build 100+).
                  ],
                ),

                // ─── 8. Modo Offline ─────────────────────────────────────
                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'MODO SIN CONEXIÓN' : 'MODO OFFLINE',
                  dark: dark,
                  color: const Color(0xFF1D4ED8),
                ),
                _OfflineDrawerCard(p: p, dark: dark),

                // ─── 9. Sobre + Legal (unificados) ───────────────────────
                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'SOBRE Y LEGAL' : 'SOBRE E LEGAL',
                  dark: dark,
                ),
                _DrawerBlock(
                  dividerColor: divider,
                  children: [
                    _DrawerRow(
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF0D9488),
                      title: p.lang == 'es' ? 'Sobre MedCases Pro' : 'Sobre o MedCases Pro',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      onTap: () {
                        _close(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _AboutAppSheet(p: p, dark: dark),
                        );
                      },
                    ),
                    // Task 9 — Termos: in-app viewer + botão link externo
                    _DrawerLegalRow(
                      icon: Icons.article_outlined,
                      iconColor: const Color(0xFF546E7A),
                      title: p.lang == 'es' ? 'Términos de Uso' : 'Termos de Uso',
                      subtitle: p.lang == 'es' ? 'Ver en la app' : 'Ver no app',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      externalUrl: _kTermsUrl,
                      externalTooltip: p.lang == 'es'
                          ? 'Abrir en navegador'
                          : 'Abrir no navegador',
                      onTap: () {
                        _close(context);
                        showLegalSheet(context, LegalType.terms, p.lang);
                      },
                    ),
                    // Task 9 — Privacidade: in-app viewer + botão link externo
                    _DrawerLegalRow(
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF546E7A),
                      title: p.lang == 'es'
                          ? 'Política de Privacidad'
                          : 'Política de Privacidade',
                      subtitle: p.lang == 'es' ? 'Ver en la app' : 'Ver no app',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      externalUrl: _kPrivacyUrl,
                      externalTooltip: p.lang == 'es'
                          ? 'Abrir en navegador'
                          : 'Abrir no navegador',
                      showDivider: false,
                      onTap: () {
                        _close(context);
                        showLegalSheet(context, LegalType.privacy, p.lang);
                      },
                    ),
                  ],
                ),

                // ─── 9. Conta e Gestão (zona de perigo — SEMPRE NO FINAL) ───
                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'CUENTA Y GESTIÓN' : 'CONTA E GESTÃO',
                  dark: dark,
                  color: const Color(0xFFCC3333),
                ),
                _DrawerBlock(
                  dividerColor: divider,
                  children: [
                    _DrawerRow(
                      icon: Icons.delete_outline_rounded,
                      iconColor: const Color(0xFFCC3333),
                      title: p.lang == 'es' ? 'Eliminar Cuenta' : 'Excluir Conta',
                      dark: dark,
                      textCol: const Color(0xFFCC3333),
                      subCol: subCol,
                      onTap: () {
                        _close(context);
                        _showDeleteAccountDialog(context, p);
                      },
                    ),
                    _DrawerRow(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFCC3333),
                      title: p.lang == 'es' ? 'Cerrar sesión' : 'Sair da conta',
                      dark: dark,
                      textCol: const Color(0xFFCC3333),
                      subCol: subCol,
                      showDivider: false,
                      onTap: () async {
                        _close(context);
                        await AuthService.logout();
                        if (context.mounted) context.read<AppProvider>().clearUser();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── RODAPÉ ─────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF0F1116) : const Color(0xFFF0EDE8),
              border: Border(top: BorderSide(color: divider, width: 0.5)),
            ),
            child: SafeArea(
              top:   false,
              left:  false,  // evitar padding duplo no endDrawer
              right: false,
              child: Text(
                'MedCases Pro · ${p.lang == 'es' ? 'Solo uso educativo' : 'Uso educacional'}',
                style: TextStyle(fontSize: 9.5, color: subCol, fontWeight: FontWeight.w500, letterSpacing: 0.2),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cabeçalho do Drawer — v3 compacto ─────────────────────────────────────────
// Layout de 2 linhas (reduzido de 3):
//   Linha 1: logo BrandMark (esq) + [ADMIN badge opcional] + botão ✕ (dir)
//   Linha 2: avatar 42px + nome/profissão + botão Editar
// Altura total ~20% menor que v2; não mexe em nenhuma lógica ou permissão.
class _DrawerHeader extends StatelessWidget {
  final AppProvider p;
  final String initials;
  final bool dark;
  final VoidCallback onClose;
  final VoidCallback onEditProfile;

  const _DrawerHeader({
    required this.p,
    required this.initials,
    required this.dark,
    required this.onClose,
    required this.onEditProfile,
  });

  static const _kGold  = Color(0xFFC5A365);
  static const _kGoldL = Color(0xFFFFE8A6);

  @override
  Widget build(BuildContext context) {
    final hasBadge = p.isAdmin || p.isMaster;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F1116), Color(0xFF1A1D23), Color(0xFF252930)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        left:   false,
        right:  false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Linha 1: logo  |  badge admin (opcional)  |  botão ✕ ───────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const BrandMark(small: true),
                  const SizedBox(width: 8),
                  // Badge Admin/Master — inline na mesma linha do logo
                  if (hasBadge) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _kGold.withValues(alpha: 0.14),
                        border: Border.all(color: _kGold.withValues(alpha: 0.40)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.verified_rounded, size: 9, color: _kGoldL),
                        const SizedBox(width: 3),
                        Text(
                          p.isMaster ? 'MASTER' : 'ADMIN',
                          style: const TextStyle(
                            fontSize: 8.5, fontWeight: FontWeight.w900,
                            color: _kGoldL, letterSpacing: 0.8,
                          ),
                        ),
                      ]),
                    ),
                  ],
                  const Spacer(),
                  // Botão fechar
                  GestureDetector(
                    onTap: onClose,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: Colors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10), width: 0.8),
                      ),
                      child: Icon(
                        Icons.close_rounded, size: 14,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Linha 2: avatar 42px + nome/profissão + botão editar ─────────
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Avatar compacto 42px
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1F4030), Color(0xFF1A1D23)],
                    ),
                    border: Border.all(
                      color: _kGold.withValues(alpha: 0.55), width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: _kGold.withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w900, color: _kGoldL),
                    ),
                  ),
                ),
                const SizedBox(width: 11),

                // Nome + profissão/instituição
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.userName.isNotEmpty ? p.userName : 'MedCases Pro',
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.3, height: 1.15,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if ((p.currentUser?.profession?.isNotEmpty ?? false) ||
                          (p.currentUser?.institution?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (p.currentUser?.profession?.isNotEmpty ?? false)
                              p.currentUser!.profession!,
                            if (p.currentUser?.institution?.isNotEmpty ?? false)
                              p.currentUser!.institution!,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.42),
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Botão editar perfil
                GestureDetector(
                  onTap: onEditProfile,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      color: _kGold.withValues(alpha: 0.14),
                      border: Border.all(
                        color: _kGold.withValues(alpha: 0.40), width: 0.9),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_rounded, size: 12, color: _kGoldL),
                      const SizedBox(width: 4),
                      const Text(
                        'Editar',
                        style: TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700, color: _kGoldL),
                      ),
                    ]),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rótulo de seção do Drawer ─────────────────────────────────────────────────
class _DrawerSectionLabel extends StatelessWidget {
  final String label;
  final bool dark;
  final Color? color;

  const _DrawerSectionLabel({
    required this.label,
    required this.dark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final col = color ??
        (dark ? Colors.white.withValues(alpha: 0.28) : const Color(0xFFAAB0B8));
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 5),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: col,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Bloco agrupado do Drawer (card com bordas arredondadas) ───────────────────
class _DrawerBlock extends StatelessWidget {
  final List<Widget> children;
  final Color? dividerColor;

  const _DrawerBlock({
    required this.children,
    this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = dark ? const Color(0xFF252930) : Colors.white;
    final borderCol = dark ? const Color(0xFF374151) : const Color(0xFFECE9E4);
    final divCol = dividerColor ?? (dark ? const Color(0xFF2D3340) : const Color(0xFFECE9E4));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.18 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, thickness: 0.5, color: divCol, indent: 50, endIndent: 0),
          ],
        ],
      ),
    );
  }
}

// ── Item Premium do Drawer ────────────────────────────────────────────────────
class _DrawerItemPremium extends StatelessWidget {
  final bool dark;
  final VoidCallback onTap;
  const _DrawerItemPremium({required this.dark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: dark
                ? [const Color(0xFF252930), const Color(0xFF1A1D23)]
                : [const Color(0xFF2D3340), const Color(0xFF0F1116)],
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFC5A365).withValues(alpha: 0.18),
            ),
            child: const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFFFFE8A6)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Upgrade Premium', style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: Color(0xFFFFE8A6), letterSpacing: -0.1)),
            const SizedBox(height: 1),
            Text('Acesso completo · 500+ casos clínicos',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.40))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: const Color(0xFFC5A365).withValues(alpha: 0.22),
              border: Border.all(color: const Color(0xFFC5A365).withValues(alpha: 0.50)),
            ),
            child: const Text('VER', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w900,
              color: Color(0xFFFFE8A6), letterSpacing: 0.8)),
          ),
        ]),
      ),
    );
  }
}

// ── Linha de item padrão do Drawer ────────────────────────────────────────────
class _DrawerRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool dark;
  final Color textCol;
  final Color subCol;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool showDivider;

  const _DrawerRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.dark,
    required this.textCol,
    required this.subCol,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: iconColor.withValues(alpha: 0.07),
      highlightColor: iconColor.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          // Ícone simples (sem container/borda ao redor)
          SizedBox(
            width: 36,
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 4),
          // Título + subtítulo opcional
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textCol,
                    letterSpacing: -0.1,
                  ),
                ),
                if (subtitle != null) ...
                  [
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: subCol.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
              ],
            ),
          ),
          // Trailing ou chevron
          if (trailing != null) trailing!
          else Icon(Icons.chevron_right_rounded, size: 16, color: subCol.withValues(alpha: 0.45)),
        ]),
      ),
    );
  }
}

// ── Task 9: DrawerRow com botão de link externo (Privacy / Terms) ─────────────
// Exibe o item normal do drawer (abre in-app) + um ícone de "abrir no navegador"
// à direita. O Apple App Store exige que links de Privacy Policy e EULA estejam
// acessíveis diretamente no app E também como URL pública.
class _DrawerLegalRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   title;
  final String?  subtitle;
  final bool     dark;
  final Color    textCol;
  final Color    subCol;
  final String   externalUrl;
  final String   externalTooltip;
  final VoidCallback onTap;
  final bool     showDivider;

  const _DrawerLegalRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.dark,
    required this.textCol,
    required this.subCol,
    required this.externalUrl,
    required this.externalTooltip,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
  });

  Future<void> _launch() async {
    final uri = Uri.parse(externalUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = dark
        ? const Color(0xFF1A2E22)
        : const Color(0xFFF0EDE8);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: iconColor.withValues(alpha: 0.07),
          highlightColor: iconColor.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 4, 11),
            child: Row(children: [
              SizedBox(
                width: 36,
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textCol,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: subCol.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Botão ícone: abre no navegador externo
              Tooltip(
                message: externalTooltip,
                child: IconButton(
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.75),
                  ),
                  onPressed: _launch,
                  splashRadius: 18,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
            ]),
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 0.7, color: dividerColor,
              indent: 14, endIndent: 14),
      ],
    );
  }
}

// ── Badge de idioma ───────────────────────────────────────────────────────────
// Sem bandeiras — texto puro PT/ES para neutralidade global
// (América Latina, Portugal, Guiné-Bissau, Angola, países hispânicos)
class _LangBadge extends StatelessWidget {
  final String lang;
  const _LangBadge({required this.lang});

  @override
  Widget build(BuildContext context) {
    final label = lang == 'pt' ? 'PT' : 'ES';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: const Color(0xFFC5A365).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFFC5A365).withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFFC5A365),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ── Toggle de tema ────────────────────────────────────────────────────────────
class _ThemeToggle extends StatelessWidget {
  final bool dark;
  const _ThemeToggle({required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: dark ? const Color(0xFF10B981) : const Color(0xFFA8B2C1),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: dark ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18, height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
      ),
    );
  }
}

// Toggle genérico on/off — verde quando ligado, cinza quando desligado
class _OnOffToggle extends StatelessWidget {
  final bool value;
  const _OnOffToggle({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: value ? const Color(0xFF10B981) : const Color(0xFFA8B2C1),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18, height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
      ),
    );
  }
}



// ── Bloco "Acesso Rápido" do Drawer ───────────────────────────────────────────
// 4 atalhos para as principais telas: usa MainShell.pendingTab para navegar
// sem precisar de onTabChange. Zero lógica de permissão.
class _DrawerQuickAccess extends StatelessWidget {
  final AppProvider p;
  final bool dark;
  final VoidCallback onClose;

  const _DrawerQuickAccess({
    required this.p,
    required this.dark,
    required this.onClose,
  });

  void _go(BuildContext context, int tab) {
    onClose();
    // Post-frame para garantir que o drawer fechou antes de mudar de tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MainShell.pendingTab.value = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEs    = p.lang == 'es';
    final textCol = dark ? const Color(0xFFEEEEEE) : const Color(0xFF0F1116);
    final subCol  = dark ? Colors.white.withValues(alpha: 0.36) : const Color(0xFF9AA0A8);
    final divider = dark ? const Color(0xFF1A2E22) : const Color(0xFFF0EDE8);

    return _DrawerBlock(
      dividerColor: divider,
      children: [
        // Nova Consulta → tab 0 (HomeScreen)
        _DrawerRow(
          icon: Icons.medical_services_outlined,
          iconColor: const Color(0xFF10B981),
          title: isEs ? 'Nueva Consulta' : 'Nova Consulta',
          subtitle: isEs ? 'Iniciar caso clínico' : 'Iniciar caso clínico',
          dark: dark, textCol: textCol, subCol: subCol,
          onTap: () => _go(context, 0),
        ),
        // Assistente IA → tab 2
        _DrawerRow(
          icon: Icons.smart_toy_outlined,
          iconColor: const Color(0xFF8B5CF6),
          title: isEs ? 'Asistente IA' : 'Assistente IA',
          subtitle: isEs ? 'IA Clínica de bolsillo' : 'IA Clínica de bolso',
          dark: dark, textCol: textCol, subCol: subCol,
          onTap: () => _go(context, 2),
        ),
        // PROTOCOLOS — visível apenas na Web (Apple 1.4.1: oculto no iOS)
        if (kIsWeb) ...[
          _DrawerRow(
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFF0EA5E9),
            title: isEs ? 'Protocolos' : 'Protocolos',
            subtitle: isEs ? 'Guías y directrices' : 'Rx e diretrizes',
            dark: dark, textCol: textCol, subCol: subCol,
            onTap: () => _go(context, 1),
          ),
          // FARMACOLOGIA — visível apenas na Web (Apple 1.4.1: oculto no iOS)
          _DrawerRow(
            icon: Icons.medication_outlined,
            iconColor: const Color(0xFFF59E0B),
            title: isEs ? 'Farmacología' : 'Farmacologia',
            subtitle: isEs ? 'Base de medicamentos' : 'Base de medicamentos',
            dark: dark, textCol: textCol, subCol: subCol,
            showDivider: false,
            onTap: () => _go(context, 1),
          ),
        ],
      ],
    );
  }
}

// ── Bloco "Sua Atividade" do Drawer ───────────────────────────────────────────
// Mostra as últimas atividades recentes do usuário no app (IA, Protocolos, etc.)
// Sempre visível após a primeira ação. Abre _RecentActivitySheet ao tocar.
class _DrawerActivity extends StatelessWidget {
  final AppProvider p;
  final bool dark;
  final VoidCallback onClose;

  const _DrawerActivity({
    required this.p,
    required this.dark,
    required this.onClose,
  });

  void _openSheet(BuildContext context) {
    onClose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _RecentActivitySheet(dark: dark, lang: p.lang),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ActivityItem>>(
      valueListenable: ActivityService.items,
      builder: (context, items, _) {
        if (items.isEmpty) return const SizedBox.shrink();

        final isEs    = p.lang == 'es';
        final textCol = dark ? const Color(0xFFEEEEEE) : const Color(0xFF0F1116);
        final subCol  = dark ? Colors.white.withValues(alpha: 0.36) : const Color(0xFF9AA0A8);
        final divider = dark ? const Color(0xFF1A2E22) : const Color(0xFFF0EDE8);
        final recent  = items.take(3).toList();
        final total   = items.length;

        return _DrawerBlock(
          dividerColor: divider,
          children: [
            // ── Header clicável ─────────────────────────────────────────────
            _DrawerRow(
              icon: Icons.history_edu_rounded,
              iconColor: const Color(0xFF6366F1),
              title: isEs ? 'Historial de Consultas' : 'Histórico de Consultas',
              subtitle: isEs
                  ? '$total ${total == 1 ? 'acción reciente' : 'acciones recientes'}'
                  : '$total ${total == 1 ? 'ação recente' : 'ações recentes'}',
              dark: dark, textCol: textCol, subCol: subCol,
              showDivider: recent.isNotEmpty,
              onTap: () => _openSheet(context),
            ),
            // ── Preview das 3 mais recentes ─────────────────────────────────
            ...recent.asMap().entries.map((entry) {
              final idx  = entry.key;
              final item = entry.value;
              final isLast = idx == recent.length - 1;
              return _DrawerActivityRow(
                item: item,
                lang: p.lang,
                dark: dark,
                textCol: textCol,
                subCol: subCol,
                showDivider: !isLast,
                onTap: () => _openSheet(context),
              );
            }),
          ],
        );
      },
    );
  }
}

// ── Mini-row de item de atividade no Drawer ────────────────────────────────────
class _DrawerActivityRow extends StatelessWidget {
  final ActivityItem item;
  final String lang;
  final bool dark;
  final Color textCol;
  final Color subCol;
  final bool showDivider;
  final VoidCallback onTap;

  const _DrawerActivityRow({
    required this.item,
    required this.lang,
    required this.dark,
    required this.textCol,
    required this.subCol,
    required this.showDivider,
    required this.onTap,
  });

  String _timeAgo(DateTime dt, String lang) {
    final diff = DateTime.now().difference(dt);
    final isEs = lang == 'es';
    if (diff.inMinutes < 1)  return isEs ? 'ahora'          : 'agora';
    if (diff.inMinutes < 60) return isEs ? 'hace ${diff.inMinutes} min' : 'há ${diff.inMinutes} min';
    if (diff.inHours < 24)   return isEs ? 'hace ${diff.inHours} h'    : 'há ${diff.inHours} h';
    return isEs ? 'hace ${diff.inDays} d' : 'há ${diff.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(item.type.colorValue);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.circle, size: 8, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textCol),
                  ),
                  if (item.subtitle.isNotEmpty)
                    Text(
                      '${item.type.label(lang)} · ${item.subtitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: subCol),
                    )
                  else
                    Text(
                      item.type.label(lang),
                      style: TextStyle(fontSize: 10.5, color: subCol),
                    ),
                ]),
              ),
              const SizedBox(width: 6),
              Text(
                _timeAgo(item.timestamp, lang),
                style: TextStyle(fontSize: 9.5, color: subCol),
              ),
            ]),
          ),
          if (showDivider)
            Divider(height: 1, indent: 52,
                color: dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFEEEEEE)),
        ],
      ),
    );
  }
}

// ── Bottom Sheet completo de Atividades Recentes ──────────────────────────────
class _RecentActivitySheet extends StatelessWidget {
  final bool dark;
  final String lang;
  const _RecentActivitySheet({required this.dark, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isEs  = lang == 'es';
    final bg    = dark ? const Color(0xFF0F1116) : Colors.white;
    final handle= dark ? Colors.white.withValues(alpha: 0.18) : const Color(0xFFA8B2C1);
    final title = dark ? Colors.white : const Color(0xFF0F1116);
    final sub   = dark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF9AA0A8);
    final div   = dark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF0F0F0);

    return ValueListenableBuilder<List<ActivityItem>>(
      valueListenable: ActivityService.items,
      builder: (context, items, _) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle ──────────────────────────────────────────────────────
              const SizedBox(height: 10),
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: handle, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),

              // ── Header ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_edu_rounded, size: 18, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        isEs ? 'Historial de Consultas' : 'Histórico de Consultas',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: title),
                      ),
                      Text(
                        isEs ? 'Tus últimas acciones en el app' : 'Suas últimas ações no app',
                        style: TextStyle(fontSize: 11, color: sub),
                      ),
                    ]),
                  ),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await ActivityService.clear();
                      },
                      child: Text(
                        isEs ? 'Limpiar' : 'Limpar',
                        style: const TextStyle(
                          fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: div),

              // ── Lista ou empty state ─────────────────────────────────────────
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(children: [
                    Icon(Icons.history_toggle_off_rounded, size: 52,
                        color: dark ? Colors.white24 : Colors.black12),
                    const SizedBox(height: 12),
                    Text(
                      isEs ? 'Sin actividad reciente' : 'Sem atividade recente',
                      style: TextStyle(fontSize: 14, color: sub, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEs
                          ? 'Consulta protocolos, fármacos o usa la IA'
                          : 'Consulte protocolos, fármacos ou use a IA',
                      style: TextStyle(fontSize: 12, color: sub),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                )
              else
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 32),
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => Divider(height: 1, indent: 68, color: div),
                    itemBuilder: (context, i) {
                      final item  = items[i];
                      final color = Color(item.type.colorValue);
                      return _ActivityTile(
                        item: item, color: color, lang: lang,
                        dark: dark, titleCol: title, subCol: sub,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tile individual no sheet de atividades ─────────────────────────────────────
class _ActivityTile extends StatelessWidget {
  final ActivityItem item;
  final Color color;
  final String lang;
  final bool dark;
  final Color titleCol;
  final Color subCol;

  const _ActivityTile({
    required this.item,
    required this.color,
    required this.lang,
    required this.dark,
    required this.titleCol,
    required this.subCol,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    final isEs = lang == 'es';
    if (diff.inMinutes < 1)  return isEs ? 'ahora mismo'       : 'agora mesmo';
    if (diff.inMinutes < 60) return isEs ? 'hace ${diff.inMinutes} min' : 'há ${diff.inMinutes} min';
    if (diff.inHours < 24)   return isEs ? 'hace ${diff.inHours} h'    : 'há ${diff.inHours} h';
    if (diff.inDays == 1)    return isEs ? 'ayer'               : 'ontem';
    return isEs ? 'hace ${diff.inDays} días' : 'há ${diff.inDays} dias';
  }

  // Ícone real por tipo (flutter IconData)
  IconData get _icon {
    switch (item.type) {
      case ActivityType.ia:          return Icons.psychology_rounded;
      case ActivityType.protocolo:   return Icons.fact_check_rounded;
      case ActivityType.farmaco:     return Icons.medication_rounded;
      case ActivityType.calculadora: return Icons.calculate_rounded;
      case ActivityType.interacao:   return Icons.swap_horiz_rounded;
      case ActivityType.prescricao:  return Icons.receipt_long_rounded;
      case ActivityType.laboratorio: return Icons.biotech_rounded;
      case ActivityType.caso:        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        // ── Ícone colorido ──────────────────────────────────────────────────
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.20)),
          ),
          child: Icon(_icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        // ── Textos ─────────────────────────────────────────────────────────
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: titleCol),
            ),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  item.type.label(lang),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color),
                ),
              ),
              if (item.subtitle.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: subCol),
                  ),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        // ── Timestamp ──────────────────────────────────────────────────────
        Text(
          _timeAgo(item.timestamp),
          style: TextStyle(fontSize: 10, color: subCol),
        ),
      ]),
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
    // context.select — rebuild apenas quando userName ou lang muda
    final userName = context.select<AppProvider, String>((p) => p.userName);
    final lang     = context.select<AppProvider, String>((p) => p.lang);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1D23), Color(0xFF252930), Color(0xFF252930)],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 14, 13),
          child: Row(children: [
            // Logo clicável
            GestureDetector(
              onTap: () => onTabChange(0),
              child: const BrandMark(small: true),
            ),
            const SizedBox(width: 12),
            // Nome + subtítulo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userName.isNotEmpty ? userName : 'MedCases IA',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00E5FF),
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang == 'es' ? 'Apoyo clínico educativo' : 'Apoio clínico educacional',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.48),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Botão hamburguer — limpo, sem badge de idioma
            GestureDetector(
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.07),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.13),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  size: 20,
                  color: Color(0xFFFFE8A6),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Sobre o App — sheet institucional (Apple 1.5.0) ──────────────────────────
// Usa DraggableScrollableSheet para garantir que header+X fiquem sempre fixos
// no topo e nunca desapareçam, independente do tamanho do conteúdo.
class _AboutAppSheet extends StatelessWidget {
  final AppProvider p;
  final bool dark;
  const _AboutAppSheet({required this.p, required this.dark});

  static const _kGreen      = Color(0xFF075f45);
  static const _kGreenLight = Color(0xFF0D9488);
  static const _kGold       = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final isEs  = p.lang == 'es';
    final bg    = dark ? const Color(0xFF111A14) : const Color(0xFFF7F9F7);
    final card  = dark ? const Color(0xFF2D3340) : Colors.white;
    final hdl   = dark ? const Color(0xFF2E4038) : const Color(0xFFDDE6E0);
    final ttl   = dark ? const Color(0xFFECECEC) : const Color(0xFF07110D);
    final sub   = dark ? const Color(0xFF8A9E92) : const Color(0xFF5A6E62);
    final bdr   = dark ? const Color(0xFF1E3028) : const Color(0xFFD4E0D8);
    final accent = dark ? _kGold : _kGreen;

    Widget infoRow(IconData icon, String label, String value) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: card,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: bdr)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
              color: accent, letterSpacing: 0.9)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
              color: ttl, height: 1.3)),
        ])),
      ]),
    );

    Widget textBlock(IconData icon, String label, String value) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: card,
          borderRadius: BorderRadius.circular(12), border: Border.all(color: bdr)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
              color: accent, letterSpacing: 0.9)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 13, color: sub, height: 1.55)),
        ])),
      ]),
    );

    // ── DraggableScrollableSheet garante header sempre fixo no topo ──────────
    // initialChildSize=0.82: ocupa 82% da tela ao abrir
    // maxChildSize=0.92: máximo de 92% — nunca cobre a status bar
    // O builder retorna uma Column:
    //   - Header fixo (handle + título + X + divisor) → nunca scrolla
    //   - ListView scrollável com o restante do conteúdo
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Handle pill — fixo, nunca scrolla ──────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: hdl, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),

              // ── Título + botão X — fixo, nunca scrolla ─────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 8, 10),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      isEs ? 'Sobre MedCases Pro' : 'Sobre o MedCases Pro',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
                          color: ttl, letterSpacing: -0.3),
                    ),
                  ),
                  // Botão fechar — SEMPRE visível no topo direito
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.close_rounded, size: 24, color: sub),
                      ),
                    ),
                  ),
                ]),
              ),

              // ── Divisor ────────────────────────────────────────────────
              Divider(height: 1, thickness: 0.5, color: hdl),

              // ── Conteúdo scrollável (ListView usa o scrollController) ───
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [

                    // Card: ícone + nome + badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: bdr)),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 56, height: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(color: _kGreen,
                                  borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.local_hospital_rounded,
                                  size: 28, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('MedCases Pro',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                                  color: ttl, letterSpacing: -0.4)),
                          const SizedBox(height: 3),
                          Text(isEs ? 'Apoyo clínico educativo' : 'Apoio clínico educacional',
                              style: TextStyle(fontSize: 12, color: sub,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accent.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              isEs ? 'Herramienta educativa' : 'Ferramenta educacional',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: accent, letterSpacing: 0.3)),
                          ),
                        ])),
                      ]),
                    ),

                    // Desenvolvedor
                    infoRow(Icons.person_outline_rounded,
                        isEs ? 'DESARROLLADO POR' : 'DESENVOLVIDO POR',
                        'Bruno Rodrigues de Sousa'),

                    // Contato
                    infoRow(Icons.email_outlined,
                        isEs ? 'CONTACTO TÉCNICO Y SOPORTE' : 'CONTATO TÉCNICO E SUPORTE',
                        'medcasespro@gmail.com'),

                    // Comitê de Revisão Clínica
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kGreenLight.withValues(alpha: 0.35))),
                      child: Column(children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _kGreenLight.withValues(alpha: dark ? 0.20 : 0.10),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.verified_user_rounded, size: 16, color: _kGreenLight),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                isEs
                                    ? 'RESPONSABILIDAD TÉCNICA Y REVISIÓN MÉDICA'
                                    : 'RESPONSABILIDADE TÉCNICA E REVISÃO MÉDICA',
                                style: const TextStyle(fontSize: 9.5,
                                    fontWeight: FontWeight.w800, color: _kGreenLight,
                                    letterSpacing: 0.8),
                              ),
                            ),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Text(
                            isEs
                                ? 'El contenido científico, los algoritmos de dosificación, las calculadoras '
                                  'pediátricas y las directrices clínicas incluidos en esta aplicación son '
                                  'revisados, actualizados y validados de forma continua por el Comitê de '
                                  'Revisão Clínica MedCases Pro. Este comité está integrado por profesionales '
                                  'médicos titulados y estudiantes avanzados de medicina, con base en las '
                                  'directrices internacionales vigentes de la World Allergy Organization (WAO), '
                                  'UpToDate y comités de pediatría de referencia.'
                                : 'O conteúdo científico, algoritmos de dosagem, calculadoras pediátricas e '
                                  'diretrizes clínicas contidos neste aplicativo são revisados, atualizados e '
                                  'validados de forma contínua pelo Comitê de Revisão Clínica MedCases Pro, '
                                  'composto por profissionais médicos diplomados e acadêmicos seniores de '
                                  'medicina, com base nas diretrizes internacionais atualizadas da World Allergy '
                                  'Organization (WAO), UpToDate e comitês de pediatria de referência.',
                            style: TextStyle(fontSize: 13, color: sub, height: 1.55),
                          ),
                        ),
                      ]),
                    ),

                    // Propósito
                    textBlock(Icons.gavel_rounded,
                        isEs ? 'PROPÓSITO' : 'PROPÓSITO',
                        isEs
                            ? 'Esta aplicación es una herramienta exclusivamente educativa de apoyo a la '
                              'toma de decisiones clínicas. No reemplaza el juicio clínico del profesional '
                              'de salud, ni constituye prescripción médica.'
                            : 'Este aplicativo é uma ferramenta exclusivamente educacional de apoio à tomada '
                              'de decisão clínica. Não substitui o julgamento clínico do profissional de '
                              'saúde, nem constitui prescrição médica.'),

                    // Site
                    GestureDetector(
                      onTap: () => launchUrl(
                          Uri.parse(_kSiteUrl),
                          mode: LaunchMode.externalApplication),
                      child: infoRow(Icons.language_outlined,
                          isEs ? 'SITIO WEB' : 'SITE',
                          'promedcases.com'),
                    ),

                    const SizedBox(height: 8),

                    // Copyright
                    Text(
                      'MedCases Pro © ${DateTime.now().year} — '
                      '${isEs ? 'Todos los derechos reservados.' : 'Todos os direitos reservados.'}',
                      style: TextStyle(fontSize: 11, color: sub.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
      setState(() => _error = widget.p.lang == 'es' ? 'El nombre no puede estar vacío.' : 'O nome não pode ficar em branco.');
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
      if (mounted) setState(() { _saving = false; _error = widget.p.lang == 'es' ? 'Error al guardar. Intente nuevamente.' : 'Erro ao salvar. Tente novamente.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.p.darkMode;
    final bg = dark ? const Color(0xFF1A1D23) : Colors.white;
    final titleColor = dark ? Colors.white : const Color(0xFF0F1116);
    final subColor = dark ? Colors.white54 : const Color(0xFF6B7280);
    final borderColor = dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB);

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

            // Título + botão fechar
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
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.p.lang == 'es' ? 'Editar perfil' : 'Editar perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
                Text(widget.p.lang == 'es' ? 'Tu información profesional' : 'Suas informações profissionais', style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w500)),
              ])),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 22, color: subColor),
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(8),
                visualDensity: VisualDensity.compact,
              ),
            ]),
            const SizedBox(height: 24),

            // Campo — Nome
            _SheetField(
              label: widget.p.lang == 'es' ? 'Nombre completo' : 'Nome completo',
              controller: _nameCtrl,
              icon: Icons.badge_outlined,
              dark: dark,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // Campo — Profissão
            _SheetField(
              label: widget.p.lang == 'es' ? 'Profesión (ej: Médico, Residente)' : 'Profissão (ex: Médico, Residente)',
              controller: _profCtrl,
              icon: Icons.work_outline_rounded,
              dark: dark,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),

            // Campo — Instituição
            _SheetField(
              label: widget.p.lang == 'es' ? 'Institución / Hospital' : 'Instituição / Hospital',
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
                    child: Text(widget.p.lang == 'es' ? 'Cancelar' : 'Cancelar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: subColor)),
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
                      color: const Color(0xFF0F1116),
                      boxShadow: [BoxShadow(color: const Color(0xFF0F1116).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    alignment: Alignment.center,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFE8A6)))
                        : Text(widget.p.lang == 'es' ? 'Guardar' : 'Salvar', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6))),
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
    final fillColor = dark ? const Color(0xFF252930) : const Color(0xFFF9F9F9);
    final textColor = dark ? Colors.white : const Color(0xFF0F1116);
    final hintColor = dark ? Colors.white38 : const Color(0xFFAAAAAA);
    final borderColor = dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB);

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

// ── Modal "O que há de novo" ──────────────────────────────────────────────────
class _AppUpdateDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AppUpdateDialog({required this.data});

  static const _kDark  = Color(0xFF0F1116);
  static const _kGreen = Color(0xFF10B981);
  static const _kGold  = Color(0xFFC5A365);
  static const _kGoldL = Color(0xFFFFE8A6);

  @override
  Widget build(BuildContext context) {
    final title   = data['title']   as String? ?? 'Novidades';
    final version = data['version'] as String? ?? '';
    final date    = data['date']    as String? ?? '';
    final items   = (data['items']  as List<dynamic>? ?? []).cast<String>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [_kDark, Color(0xFF1B3D2A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: _kGoldL, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                if (version.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                    ),
                    child: Text('v$version',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kGoldL)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (date.isNotEmpty)
                  Text(date, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
              ]),
            ]),
          ),
          // Lista de novidades
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: _kGreen, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D23), height: 1.4)),
                    ),
                  ]),
                )).toList(),
              ),
            ),
          ),
          // Botão
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kDark,
                  foregroundColor: _kGoldL,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Entendido!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Bottom Sheet de Feedback ──────────────────────────────────────────────────
class _FeedbackSheet extends StatefulWidget {
  final AppProvider p;
  final bool dark;
  const _FeedbackSheet({required this.p, required this.dark});
  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _msgCtrl = TextEditingController();
  int _rating = 0;
  String _category = '';
  bool _sending = false;
  bool _sent = false;
  String? _error;

  static const _destEmail = 'medcasespro@gmail.com';
  bool get _isEs => widget.p.lang == 'es';

  final List<Map<String, String>> _categoriesPt = const [
    {'icon': '🆘', 'label': 'Suporte / Ajuda'},
    {'icon': '🐛', 'label': 'Erro no app'},
    {'icon': '💡', 'label': 'Sugestão'},
    {'icon': '💊', 'label': 'Fármaco/Protocolo'},
    {'icon': '💳', 'label': 'Assinatura / Conta'},
    {'icon': '⭐', 'label': 'Elogio'},
    {'icon': '❓', 'label': 'Outro'},
  ];
  final List<Map<String, String>> _categoriesEs = const [
    {'icon': '🆘', 'label': 'Soporte / Ayuda'},
    {'icon': '🐛', 'label': 'Error en la app'},
    {'icon': '💡', 'label': 'Sugerencia'},
    {'icon': '💊', 'label': 'Fármaco/Protocolo'},
    {'icon': '💳', 'label': 'Suscripción / Cuenta'},
    {'icon': '⭐', 'label': 'Elogio'},
    {'icon': '❓', 'label': 'Otro'},
  ];

  List<Map<String, String>> get _categories => _isEs ? _categoriesEs : _categoriesPt;

  @override
  void initState() {
    super.initState();
    _category = _isEs ? 'Soporte / Ayuda' : 'Suporte / Ajuda';
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) {
      setState(() => _error = _isEs
          ? 'Escribe tu mensaje antes de enviar.'
          : 'Escreva sua mensagem antes de enviar.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final userName  = widget.p.userName.isNotEmpty ? widget.p.userName : 'Usuário';
      final userEmail = widget.p.userEmail.isNotEmpty ? widget.p.userEmail : 'sem-email';
      final stars     = _rating > 0 ? '${'⭐' * _rating} ($_rating/5)' : 'Não avaliado';
      final subject = Uri.encodeComponent('[MedCases Feedback] $_category — $userName');
      final body = Uri.encodeComponent(
        '━━━━━━━━━━━━━━━━━━━━━━━\n'
        'FEEDBACK & SUPORTE — MedCases Pro\n'
        '━━━━━━━━━━━━━━━━━━━━━━━\n\n'
        '👤 Usuário: $userName\n'
        '📧 E-mail: $userEmail\n'
        '🏷️ Categoria: $_category\n'
        '⭐ Avaliação: $stars\n\n'
        '💬 Mensagem:\n$msg\n\n'
        '━━━━━━━━━━━━━━━━━━━━━━━\n'
        'Enviado pelo app MedCases Pro',
      );
      final uri = Uri.parse('mailto:$_destEmail?subject=$subject&body=$body');
      if (!await launchUrl(uri)) {
        final fallback = Uri(
          scheme: 'mailto',
          path: _destEmail,
          query: 'subject=[MedCases] $_category&body=$msg',
        );
        if (!await launchUrl(fallback)) {
          throw Exception('Não foi possível abrir o app de e-mail.');
        }
      }
      setState(() {
        _sent = true;
        _sending = false;
      });
    } catch (e) {
      setState(() {
        _sending = false;
        _error = _isEs
            ? 'No se pudo abrir el cliente de correo. Intente de nuevo.'
            : 'Não foi possível abrir o app de e-mail. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final bg   = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final textCol = dark ? Colors.white : const Color(0xFF1A1D23);
    final subCol  = dark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280);
    final surfCol = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6);

    if (_sent) {
      return _SuccessView(
        dark: dark,
        isEs: _isEs,
        onClose: () => Navigator.of(context).pop(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 0,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF48484A) : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Título + botão fechar
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                _isEs ? 'Feedback y Soporte' : 'Feedback e Suporte',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: textCol),
              )),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 22, color: subCol),
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(8),
                visualDensity: VisualDensity.compact,
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              _isEs
                  ? 'Feedback, problemas, sugerencias o cualquier duda — estamos aquí.'
                  : 'Feedback, problemas, sugestões ou qualquer dúvida — estamos aqui.',
              style: TextStyle(fontSize: 13, color: subCol),
            ),
            const SizedBox(height: 24),

            // Avaliação por estrelas
            Text(
              _isEs ? 'Avaliação' : 'Avaliação',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: textCol),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (i) {
                final filled = i < _rating;
                return GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled
                          ? const Color(0xFFFBBF24)
                          : (dark ? const Color(0xFF48484A) : const Color(0xFFD1D5DB)),
                      size: 34,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // Categoria
            Text(
              _isEs ? 'Categoría' : 'Categoria',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: textCol),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final selected = _category == cat['label'];
                return GestureDetector(
                  onTap: () => setState(() => _category = cat['label']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                          : surfCol,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF7C3AED)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '${cat['icon']}  ${cat['label']}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected
                            ? const Color(0xFF7C3AED)
                            : textCol,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Mensagem
            Text(
              _isEs ? 'Mensaje' : 'Mensagem',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: textCol),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _msgCtrl,
              maxLines: 4,
              maxLength: 500,
              style: TextStyle(fontSize: 14, color: textCol),
              decoration: InputDecoration(
                hintText: _isEs
                    ? 'Describe tu problema, sugerencia o lo que necesitas...'
                    : 'Descreva seu problema, sugestão ou o que precisar...',
                hintStyle: TextStyle(color: subCol, fontSize: 13),
                filled: true,
                fillColor: surfCol,
                counterStyle: TextStyle(color: subCol, fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF7C3AED), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),

            // Erro
            if (_error != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 14, color: Color(0xFFEF4444)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFEF4444))),
                ),
              ]),
            ],

            const SizedBox(height: 20),

            // Site link
            GestureDetector(
              onTap: () => launchUrl(
                  Uri.parse(_kSiteUrl),
                  mode: LaunchMode.externalApplication),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: surfCol,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: dark
                          ? const Color(0xFF48484A)
                          : const Color(0xFFD1D5DB)),
                ),
                child: Row(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.language_outlined,
                        size: 16, color: Color(0xFF7C3AED)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEs ? 'SITIO WEB' : 'SITE',
                        style: const TextStyle(
                            fontSize: 9.5, fontWeight: FontWeight.w800,
                            color: Color(0xFF7C3AED), letterSpacing: 0.9),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'promedcases.com',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600,
                            color: textCol),
                      ),
                    ],
                  )),
                  Icon(Icons.open_in_new_rounded,
                      size: 16, color: subCol),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // Botão enviar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF7C3AED).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isEs ? 'Abrir e-mail para enviar' : 'Abrir e-mail para enviar',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                _isEs
                    ? 'Se abrirá tu app de correo con el mensaje listo. Respondemos en hasta 48h.'
                    : 'Seu app de e-mail abrirá com a mensagem pronta. Respondemos em até 48h.',
                style: TextStyle(fontSize: 11, color: subCol),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Confirmação de envio ──────────────────────────────────────────────────────
class _SuccessView extends StatelessWidget {
  final bool dark;
  final bool isEs;
  final VoidCallback onClose;
  const _SuccessView({
    required this.dark,
    required this.isEs,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bg      = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final textCol = dark ? Colors.white : const Color(0xFF1A1D23);
    final subCol  = dark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 32),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: dark
                    ? const Color(0xFF48484A)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Ícone de sucesso
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_rounded,
                color: Color(0xFF7C3AED), size: 36),
          ),
          const SizedBox(height: 20),

          Text(
            isEs ? '¡Listo!' : 'Pronto!',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w900, color: textCol),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isEs
                  ? 'Tu app de correo se abrió con el mensaje. Solo envíalo y listo — ¡gracias por tu feedback!'
                  : 'Seu app de e-mail abriu com a mensagem pronta. Só enviar — obrigado pelo feedback!',
              style: TextStyle(fontSize: 14, color: subCol, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                isEs ? 'Fechar' : 'Fechar',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINEL LATERAL RETRÁTIL — ANOTAÇÕES
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// ABRE O PAINEL DE NOTAS COMO BOTTOM SHEET (igual a Recentes / Favoritos)
// ─────────────────────────────────────────────────────────────────────────────
void showNotesSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.50,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF161616) : const Color(0xFFFFFFFF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Pill handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(child: _NotesPanelContent(
              onClose: () => Navigator.pop(ctx),
              scrollController: scrollController,
            )),
          ]),
        );
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINEL LATERAL LEGADO — mantido apenas para compatibilidade interna
// (o botão tab verde foi removido; acesso via botão Notas na home)
// ─────────────────────────────────────────────────────────────────────────────
class _SideNotesPanel extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const _SideNotesPanel({required this.isOpen, required this.onToggle});

  @override
  State<_SideNotesPanel> createState() => _SideNotesPanelState();
}

class _SideNotesPanelState extends State<_SideNotesPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
  }

  @override
  void didUpdateWidget(_SideNotesPanel old) {
    super.didUpdateWidget(old);
    if (widget.isOpen != old.isOpen) {
      widget.isOpen ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    // Largura do painel: 88% em mobile, máx 400px
    final panelW = (size.width * 0.88).clamp(0.0, 400.0);

    return Stack(children: [
      // ── Overlay escuro quando aberto ──────────────────────────────────────
      if (widget.isOpen)
        FadeTransition(
          opacity: _fadeAnim,
          child: GestureDetector(
            onTap: widget.onToggle,
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
        ),

      // ── Painel deslizante (slide da esquerda) ─────────────────────────────
      AnimatedBuilder(
        animation: _slideAnim,
        builder: (_, __) {
          final offset = (1.0 - _slideAnim.value) * -(panelW + 8);
          return Positioned(
            left: offset,
            top: 0,
            bottom: 0,
            width: panelW,
            child: _NotesPanelContent(
              onClose: widget.onToggle,
            ),
          );
        },
      ),

      // Botão tab lateral removido — acesso via botão Notas na HomeScreen
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTEÚDO INTERNO DO PAINEL — lista de anotações reutilizando lógica existente
// ─────────────────────────────────────────────────────────────────────────────
class _NotesPanelContent extends StatefulWidget {
  final VoidCallback onClose;
  final ScrollController? scrollController;
  const _NotesPanelContent({required this.onClose, this.scrollController});

  @override
  State<_NotesPanelContent> createState() => _NotesPanelContentState();
}

class _NotesPanelContentState extends State<_NotesPanelContent> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> _allNotes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _search = _searchCtrl.text.toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  void _subscribe() {
    final uid = context.read<AppProvider>().currentUser?.uid ?? '';
    if (uid.isEmpty) { setState(() => _loading = false); return; }
    _sub = FirestoreService.notesStream(uid).listen(
      (notes) { if (mounted) setState(() { _allNotes = notes; _loading = false; }); },
      onError: (_) { if (mounted) setState(() => _loading = false); },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _allNotes;
    return _allNotes.where((n) {
      final t = (n['title']   as String? ?? '').toLowerCase();
      final c = (n['content'] as String? ?? '').toLowerCase();
      return t.contains(_search) || c.contains(_search);
    }).toList();
  }

  Future<void> _deleteNote(String noteId) async {
    final uid = context.read<AppProvider>().currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    await FirestoreService.deleteNote(uid: uid, noteId: noteId);
  }

  void _openEditor({Map<String, dynamic>? note}) {
    final uid  = context.read<AppProvider>().currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final dark = context.read<AppProvider>().darkMode;
    final lang = context.read<AppProvider>().lang;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteEditorSheet(uid: uid, note: note, dark: dark, lang: lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    final panelBg   = dark ? const Color(0xFF161616) : const Color(0xFFFFFFFF);
    final searchBg  = dark ? const Color(0xFF222222) : Colors.white;
    final borderCol = dark ? const Color(0xFF2D3340) : const Color(0xFFE0E0E0);
    final textCol   = dark ? Colors.white             : const Color(0xFF0F1116);
    final subCol    = dark ? Colors.white54           : Colors.black45;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: panelBg,
        ),
        child: Column(children: [
          // ── Header do painel ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? [const Color(0xFF0F1116), const Color(0xFF2D3340), const Color(0xFF1F3A28)]
                    : [const Color(0xFF0F1116), const Color(0xFF1B3D2A), const Color(0xFF10B981)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    // Botão fechar painel
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                        child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          isEs ? 'Mis Anotaciones' : 'Minhas Anotações',
                          style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          _allNotes.isEmpty
                              ? (isEs ? 'Sin anotaciones' : 'Nenhuma anotação')
                              : '${_allNotes.length} ${isEs
                                  ? 'anotación${_allNotes.length != 1 ? "es" : ""}'
                                  : 'anotaç${_allNotes.length != 1 ? "ões" : "ão"}'}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.55),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]),
                    ),
                    // Botão nova nota
                    GestureDetector(
                      onTap: () => _openEditor(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: const Color(0xFF10B981),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.45),
                              blurRadius: 10, offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add_rounded, color: Colors.white, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            isEs ? 'Nueva' : 'Nova',
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // Busca
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: searchBg,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: borderCol, width: 0.8),
                    ),
                    child: Row(children: [
                      const SizedBox(width: 10),
                      Icon(Icons.search_rounded, size: 15, color: subCol),
                      const SizedBox(width: 7),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: TextStyle(fontSize: 12, color: textCol),
                          decoration: InputDecoration(
                            hintText: isEs ? 'Buscar...' : 'Buscar anotações...',
                            hintStyle: TextStyle(fontSize: 12, color: subCol),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (_search.isNotEmpty)
                        GestureDetector(
                          onTap: () => _searchCtrl.clear(),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.close_rounded, size: 14, color: subCol),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),

          // ── Lista de notas ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(
                    color: Color(0xFF10B981), strokeWidth: 2))
                : _filtered.isEmpty
                    ? _PanelEmptyState(isEs: isEs, dark: dark,
                        onNew: () => _openEditor())
                    : ListView.separated(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final note = _filtered[i];
                          return _PanelNoteCard(
                            note: note,
                            dark: dark,
                            isEs: isEs,
                            onTap: () => _openEditor(note: note),
                            onDelete: () => _deleteNote(note['id'] as String? ?? ''),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO VAZIO DO PAINEL
// ─────────────────────────────────────────────────────────────────────────────
class _PanelEmptyState extends StatelessWidget {
  final bool isEs;
  final bool dark;
  final VoidCallback onNew;
  const _PanelEmptyState({required this.isEs, required this.dark, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final subCol = dark ? Colors.white30 : Colors.black26;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.edit_note_rounded, size: 48,
          color: dark ? const Color(0xFF10B981).withValues(alpha: 0.50) : const Color(0xFF10B981).withValues(alpha: 0.35)),
        const SizedBox(height: 12),
        Text(
          isEs ? 'Sin anotaciones aún' : 'Nenhuma anotação ainda',
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: dark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isEs ? 'Toca "Nueva" para comenzar' : 'Toque "Nova" para começar',
          style: TextStyle(fontSize: 12, color: subCol),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: onNew,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF10B981),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.40),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                isEs ? 'Nueva anotación' : 'Nova anotação',
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD DE NOTA NO PAINEL
// ─────────────────────────────────────────────────────────────────────────────
class _NoteColor2 {
  final String hex;
  final Color light;
  final Color dark;
  final Color border;
  const _NoteColor2({required this.hex, required this.light, required this.dark, required this.border});
}

const _panelNoteColors = [
  _NoteColor2(hex:'#FFFEF0', light:Color(0xFFFFFEF0), dark:Color(0xFF2A2800), border:Color(0xFFE8E0A0)),
  _NoteColor2(hex:'#F0FFF4', light:Color(0xFFF0FFF4), dark:Color(0xFF002A0F), border:Color(0xFFA0DEB8)),
  _NoteColor2(hex:'#F0F4FF', light:Color(0xFFF0F4FF), dark:Color(0xFF00102A), border:Color(0xFFA0B8E8)),
  _NoteColor2(hex:'#FFF0F4', light:Color(0xFFFFF0F4), dark:Color(0xFF2A0010), border:Color(0xFFE8A0B8)),
  _NoteColor2(hex:'#FFF6F0', light:Color(0xFFFFF6F0), dark:Color(0xFF2A1200), border:Color(0xFFE8C0A0)),
  _NoteColor2(hex:'#F6F0FF', light:Color(0xFFF6F0FF), dark:Color(0xFF1A0028), border:Color(0xFFC0A0E8)),
];

_NoteColor2 _panelColorFromHex(String hex) => _panelNoteColors.firstWhere(
  (c) => c.hex == hex, orElse: () => _panelNoteColors[0]);

class _PanelNoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final bool dark;
  final bool isEs;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _PanelNoteCard({
    required this.note, required this.dark, required this.isEs,
    required this.onTap, required this.onDelete,
  });

  String _formatDate(dynamic ts) {
    if (ts == null) return '';
    try {
      DateTime dt;
      if (ts is DateTime) {
        dt = ts;
      } else {
        dt = (ts as dynamic).toDate() as DateTime;
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final hex     = note['color'] as String? ?? '#FFFEF0';
    final nc      = _panelColorFromHex(hex);
    final cardBg  = dark ? nc.dark : nc.light;
    final textCol = dark ? Colors.white : const Color(0xFF1A1D23);
    final subCol  = dark ? Colors.white54 : Colors.black45;
    final title   = note['title']   as String? ?? '';
    final content = note['content'] as String? ?? '';
    final dateStr = _formatDate(note['updatedAt'] ?? note['createdAt']);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: nc.border.withValues(alpha: 0.70), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.25 : 0.07),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title.isNotEmpty) ...[
                Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: textCol,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              if (content.isNotEmpty)
                Text(content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: subCol, height: 1.4),
                ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(dateStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: dark ? Colors.white30 : Colors.black26,
                  ),
                ),
              ],
            ]),
          ),
          // Botão deletar
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: dark ? const Color(0xFF252930) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text(
                    isEs ? 'Eliminar nota' : 'Excluir anotação',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : const Color(0xFF1A1D23),
                    ),
                  ),
                  content: Text(
                    isEs ? '¿Eliminar esta nota?' : 'Deseja excluir esta anotação?',
                    style: TextStyle(
                      fontSize: 13,
                      color: dark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(isEs ? 'Cancelar' : 'Cancelar',
                        style: const TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () { Navigator.pop(context); onDelete(); },
                      child: const Text('Excluir',
                        style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Icon(Icons.delete_outline_rounded,
                size: 17,
                color: dark ? Colors.white24 : Colors.black26),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Botão Modo Offline no Drawer ───────────────────────────────────────────
class _OfflineDrawerCard extends StatelessWidget {
  final AppProvider p;
  final bool dark;
  const _OfflineDrawerCard({required this.p, required this.dark});

  static const _kBlue   = Color(0xFF1D4ED8);
  static const _kBlueLt = Color(0xFFEFF6FF);

  String _formatDate(DateTime? dt, String lang) {
    if (dt == null) return lang == 'es' ? 'Nunca sincronizado' : 'Nunca sincronizado';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return lang == 'es' ? 'Hace un momento' : 'Agora mesmo';
    if (diff.inMinutes < 60) return lang == 'es'
        ? 'Hace ${diff.inMinutes} min'
        : 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24)   return lang == 'es'
        ? 'Hace ${diff.inHours}h'
        : 'Há ${diff.inHours}h';
    return lang == 'es'
        ? 'Hace ${diff.inDays} día(s)'
        : 'Há ${diff.inDays} dia(s)';
  }

  @override
  Widget build(BuildContext context) {
    final isEs     = p.lang == 'es';
    final offline  = p.offlineMode;
    final caching  = p.offlineCaching;
    final progress = p.offlineProgress;
    final cachedAt = p.offlineCachedAt;

    final cardBg = dark
        ? (offline ? _kBlue.withValues(alpha: 0.18) : const Color(0xFF1A2030))
        : (offline ? _kBlueLt : Colors.white);
    final cardBorder = offline
        ? _kBlue.withValues(alpha: dark ? 0.5 : 0.35)
        : (dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8ECEF));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: cardBg,
          border: Border.all(color: cardBorder, width: 1.2),
        ),
        child: Column(
          children: [
            // ── Linha principal: ícone + texto + toggle ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  // Ícone animado
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: caching
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 36, height: 36,
                            child: Stack(alignment: Alignment.center, children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2.5,
                                color: _kBlue,
                                backgroundColor: _kBlue.withValues(alpha: 0.15),
                              ),
                              Text('${(progress * 100).toInt()}',
                                style: const TextStyle(
                                  fontSize: 8, fontWeight: FontWeight.w900,
                                  color: _kBlue)),
                            ]),
                          )
                        : Container(
                            key: const ValueKey('icon'),
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: offline
                                  ? _kBlue.withValues(alpha: 0.15)
                                  : (dark ? Colors.white.withValues(alpha: 0.07)
                                          : const Color(0xFFF0F4F8)),
                              border: Border.all(
                                color: offline
                                    ? _kBlue.withValues(alpha: 0.45)
                                    : Colors.transparent),
                            ),
                            child: Icon(
                              offline
                                  ? Icons.wifi_off_rounded
                                  : Icons.download_for_offline_outlined,
                              size: 18,
                              color: offline
                                  ? _kBlue
                                  : (dark ? Colors.white54
                                          : const Color(0xFF6B7280)),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Texto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs ? 'Modo sin conexión' : 'Modo offline',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: offline
                                ? _kBlue
                                : (dark ? Colors.white70
                                        : const Color(0xFF374151)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          caching
                              ? (isEs ? 'Guardando base de datos…' : 'Salvando base de dados…')
                              : offline
                                  ? _formatDate(cachedAt, p.lang)
                                  : (isEs
                                      ? 'Guardar toda la base local'
                                      : 'Salvar toda a base localmente'),
                          style: TextStyle(
                            fontSize: 10,
                            color: offline
                                ? _kBlue.withValues(alpha: 0.7)
                                : (dark ? Colors.white38
                                        : const Color(0xFF9CA3AF)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Toggle
                  GestureDetector(
                    onTap: caching ? null : () => p.setOfflineMode(!offline),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 44, height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: offline
                            ? _kBlue
                            : (dark ? Colors.white.withValues(alpha: 0.15)
                                    : const Color(0xFFD1D5DB)),
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 250),
                        alignment: offline
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          width: 20, height: 20,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Barra de progresso (só durante caching) ───────────────
            if (caching)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: _kBlue.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation(_kBlue),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isEs
                          ? _progressLabel(progress, 'es')
                          : _progressLabel(progress, 'pt'),
                      style: TextStyle(
                        fontSize: 9.5,
                        color: _kBlue.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Chips de info quando ativo ────────────────────────────
            if (offline && !caching) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Wrap(spacing: 6, runSpacing: 4, children: [
                  _OfflineChip(label: isEs ? '501 fármacos' : '501 fármacos',    icon: Icons.medication_rounded),
                  _OfflineChip(label: isEs ? 'Protocolos' : 'Protocolos',        icon: Icons.assignment_rounded),
                  _OfflineChip(label: isEs ? 'Casos clínicos' : 'Casos clínicos', icon: Icons.cases_rounded),
                  _OfflineChip(label: isEs ? 'PEWS · Doses' : 'PEWS · Doses',    icon: Icons.child_care_rounded),
                ]),
              ),
            ],

            // ── Botão "Atualizar cache" quando já ativo ───────────────
            if (offline && !caching && cachedAt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: GestureDetector(
                  onTap: () => p.cacheAllDataForOffline(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _kBlue.withValues(alpha: 0.10),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.30)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.sync_rounded, size: 13, color: _kBlue),
                      const SizedBox(width: 6),
                      Text(
                        isEs ? 'Actualizar caché' : 'Atualizar cache',
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _kBlue),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _progressLabel(double p, String lang) {
    if (p < 0.45) return lang == 'es' ? '📦 Guardando fármacos (501)…' : '📦 Salvando fármacos (501)…';
    if (p < 0.75) return lang == 'es' ? '📋 Guardando protocolos…'     : '📋 Salvando protocolos…';
    if (p < 0.95) return lang == 'es' ? '🩺 Guardando casos clínicos…' : '🩺 Salvando casos clínicos…';
    return lang == 'es' ? '✅ Finalizando…' : '✅ Finalizando…';
  }
}

// ── Task 8: Loading overlay durante exclusão de conta ─────────────────────
class _DeletingAccountOverlay extends StatelessWidget {
  const _DeletingAccountOverlay();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFCC3333),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Excluindo sua conta…',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white : const Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Removendo todos os seus dados.\nIsso pode levar alguns segundos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: dark ? Colors.white54 : Colors.grey[600],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _OfflineChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF1D4ED8).withValues(alpha: 0.10),
        border: Border.all(color: const Color(0xFF1D4ED8).withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: const Color(0xFF1D4ED8)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: Color(0xFF1D4ED8))),
      ]),
    );
  }
}
