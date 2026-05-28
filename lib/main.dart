import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'screens/home_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/library_screen.dart';
import 'services/firestore_service.dart';
import 'services/gemini_service.dart';
import 'widgets/brand_mark.dart';
import 'widgets/common_widgets.dart' show MedBreakpoints;

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

  // 2. Gemini key do storage local (síncrono, sem rede)
  try {
    await GeminiService.initFromStorage().timeout(const Duration(seconds: 2));
  } catch (_) {}

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

  // 4. Restaura sessão web em paralelo com timeout de segurança
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
    return MaterialApp(
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
      // ── Contenção de largura para iPad nativo (não afeta web desktop) ────────
      // • Web desktop (kIsWeb): sem restrição — ocupa toda a viewport.
      // • iPhone (< 600 px): transparente — nada muda.
      // • iPad nativo (>= 600 px, não web): centraliza com no máximo 560 px
      //   para que o layout de celular não "estique" em telas grandes.
      builder: (context, child) {
        // Web: nunca restringir — o app deve ocupar a tela toda
        if (kIsWeb) return child ?? const SizedBox.shrink();
        final screenW = MediaQuery.of(context).size.width;
        if (screenW <= 600) return child ?? const SizedBox.shrink();
        // iPad nativo: centraliza com faixa de no máximo 560 px
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  ThemeData _buildTheme(bool dark) => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: dark
        ? ColorScheme.dark(
            // ── Dark mode: neutro, menos verde, maior contraste ──────────
            primary:                    const Color(0xFFD4A96A),   // ouro
            onPrimary:                  const Color(0xFF1C1C1C),
            secondary:                  const Color(0xFF2E8A62),   // verde médio
            onSecondary:                const Color(0xFFF7F7F7),
            surface:                    const Color(0xFF1E1E1E),   // cards
            onSurface:                  const Color(0xFFF7F7F7),   // texto principal
            surfaceContainerHighest:    const Color(0xFF252525),
            surfaceContainerHigh:       const Color(0xFF242424),
            surfaceContainer:           const Color(0xFF1E1E1E),
            surfaceContainerLow:        const Color(0xFF1A1A1A),
            surfaceDim:                 const Color(0xFF141414),
            outline:                    const Color(0xFF333333),
            outlineVariant:             const Color(0xFF2A2A2A),
            error:                      const Color(0xFFFF7070),
            onError:                    Colors.white,
            inverseSurface:             const Color(0xFFF7F7F7),
            onInverseSurface:           const Color(0xFF141414),
          )
        : ColorScheme.light(
            primary: const Color(0xFF0F1C14),
            secondary: const Color(0xFF1F6B48),
            surface: const Color(0xFFFFFDF8),
            onSurface: const Color(0xFF0F1C14),
            surfaceContainerHighest: const Color(0xFFF0EDE6),
          ),
    scaffoldBackgroundColor: dark ? const Color(0xFF141414) : const Color(0xFFF5F6F8),
    cardColor:               dark ? const Color(0xFF1E1E1E) : Colors.white,
    dividerColor:            dark ? const Color(0xFF2A2A2A) : const Color(0xFFE2E6EA),
    // Textos padrão do tema
    textTheme: dark ? const TextTheme(
      bodyLarge:   TextStyle(color: Color(0xFFF7F7F7)),
      bodyMedium:  TextStyle(color: Color(0xFFF7F7F7)),
      bodySmall:   TextStyle(color: Color(0xFFCCCCCC)),
      titleLarge:  TextStyle(color: Color(0xFFF7F7F7)),
      titleMedium: TextStyle(color: Color(0xFFF7F7F7)),
      titleSmall:  TextStyle(color: Color(0xFFDDDDDD)),
      labelLarge:  TextStyle(color: Color(0xFFF7F7F7)),
      labelMedium: TextStyle(color: Color(0xFFCCCCCC)),
      labelSmall:  TextStyle(color: Color(0xFF888888)),
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
    scaffoldBackgroundColor: const Color(0xFF0F1C14),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFC5A365),
      secondary: Color(0xFF1F6B48),
      surface: Color(0xFF0F1C14),
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
    // Etapa 1: aguarda Firebase init (em paralelo ao runApp)
    return FutureBuilder<void>(
      future: widget.firebaseInit,
      builder: (context, firebaseSnap) {
        // Firebase ainda inicializando → splash nativa Flutter (sem tela verde)
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

        // Aprovado → MainShell
        // NÃO há addPostFrameCallback aqui — setUser() é gerenciado pelo
        // _AuthGateState._onUserResolved() com flag de idempotência.
        return const MainShell();
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
        backgroundColor: Color(0xFF0F1C14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4A96A))),
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

// ── Splash Screen ─────────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1610),
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Logo com glow sutil
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC5A365).withValues(alpha: 0.20),
                  blurRadius: 48,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const BrandMark(small: false),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFFFFE8A6).withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Cargando MedCases Pro...',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.30),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ]),
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

  /// Re-lê o documento users/{uid} via Firestore REST.
  /// Se o admin já aprovou, atualiza webUser para que _AuthGate navegue.
  Future<void> _checkApproval() async {
    setState(() { _checking = true; _checkMsg = null; });
    try {
      final token = await AuthService.getAdminToken();
      if (token.isEmpty) {
        setState(() {
          _checking = false;
          _checkMsg = _isEs
              ? 'Sesión expirada. Cierra sesión e inicia de nuevo.'
              : 'Sessão expirada. Saia e faça login novamente.';
        });
        return;
      }

      const projectId = 'medcases-pro';
      const fsBase    = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
      final uid       = widget.user.uid;

      final resp = await http.get(
        Uri.parse('$fsBase/users/$uid'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) {
        setState(() {
          _checking = false;
          _checkMsg = _isEs
              ? 'No se pudo verificar. Intenta de nuevo.'
              : 'Não foi possível verificar. Tente novamente.';
        });
        return;
      }

      final fsBody  = jsonDecode(resp.body) as Map<String, dynamic>;
      final fields  = fsBody['fields'] as Map<String, dynamic>? ?? {};
      final status  = (fields['status']?['stringValue'] as String?) ?? 'pending';

      if (status == 'approved') {
        // Reconstrói UserModel com status atualizado e atualiza o ValueNotifier.
        // _AuthGate reage imediatamente via ValueListenableBuilder.
        final updatedMap = <String, dynamic>{};
        fields.forEach((k, v) {
          final val = v as Map<String, dynamic>;
          if (val.containsKey('stringValue'))        updatedMap[k] = val['stringValue'];
          else if (val.containsKey('booleanValue'))  updatedMap[k] = val['booleanValue'];
          else if (val.containsKey('integerValue'))  updatedMap[k] = int.tryParse(val['integerValue'].toString());
          else if (val.containsKey('doubleValue'))   updatedMap[k] = val['doubleValue'];
          else if (val.containsKey('timestampValue')) {
            updatedMap[k] = Timestamp.fromDate(
              DateTime.parse(val['timestampValue'] as String),
            );
          }
        });
        updatedMap['uid'] = uid;
        final freshUser = UserModel.fromMap(updatedMap);

        // Persiste o JSON atualizado na sessão salva
        await AuthService.saveSession(freshUser);

        // Actualiza o notifier — _AuthGate navega automaticamente
        AuthService.webUser.value = freshUser;
      } else {
        setState(() {
          _checking = false;
          _checkMsg = _isEs
              ? 'Tu cuenta aún está pendiente. El administrador recibirá una notificación.'
              : 'Sua conta ainda está pendente. O administrador será notificado.';
        });
      }
    } catch (e) {
      setState(() {
        _checking = false;
        _checkMsg = _isEs
            ? 'Error de conexión. Verifica tu internet.'
            : 'Erro de conexão. Verifique sua internet.';
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
      backgroundColor: const Color(0xFF0F1C14),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F1C14)),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_checking ? 'Verificando...' : 'Verificar aprovação'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A365),
                  foregroundColor: const Color(0xFF0F1C14),
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
      backgroundColor: const Color(0xFF0F1C14),
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
    return const MainShell();
  }
}

// ── Shell principal ───────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  // tabs: 0=Home 1=Rx/Proto 2=IA(FAB) 3=H.Clínica 4=Calculadoras
  // (Adulto/Cockpit é acessado via card na HomeScreen)
  int _tab = 0;
  // sub-tab dentro do combo Rx+Proto: 0=Rx, 1=Protocolos
  int _rxProtoSub = 0;

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
  void _onTabChange(int t)    => setState(() => _tab = t);
  void _onSubTabChange(int i) => setState(() => _rxProtoSub = i);
  void _onOpenNotes()         => showNotesSheet(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Instancia TODAS as telas UMA VEZ — IndexedStack reutiliza entre rebuilds.
    // HomeScreen e _RxProtoCombo agora ficam aqui (não mais no build()) para
    // que notifyListeners() do AppProvider não as recrie a cada rebuild.
    _staticScreens = [
      HomeScreen(                                  // 0 — tela inicial
        onTabChange:    _onTabChange,
        onSubTabChange: _onSubTabChange,
        openProtocol:   _openProtocol,
        onOpenNotes:    _onOpenNotes,
        onCheckUpdate:  _forceShowUpdate,
      ),
      _RxProtoCombo(                               // 1 — Rx/Proto combo
        subTab: _rxProtoSub,
        onSubTabChange: _onSubTabChange,
      ),
      const AiScreen(),                            // 2
      const HistoryScreen(),                       // 3
      const ToolsScreen(),                         // 4
      const LibraryScreen(),                       // 5
    ];

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

  @override
  void dispose() {
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
    final bp = MedBreakpoints.of(context);

    // Desktop: sidebar lateral + conteúdo expandido sem bottom nav
    if (bp.isDesktop) {
      return _buildDesktopShell(context, dark, p);
    }
    // Mobile/Tablet: layout original com bottom nav
    return _buildMobileShell(context, dark, p);
  }

  /// Layout desktop: Row(sidebar | conteúdo)
  Widget _buildDesktopShell(BuildContext context, bool dark, AppProvider p) {
    final bg       = dark ? const Color(0xFF141414) : const Color(0xFFF7F8FA);
    final stackIdx = _tab.clamp(0, _staticScreens.length - 1);

    return Scaffold(
      backgroundColor: bg,
      endDrawer: _AppDrawer(p: p),
      body: SafeArea(
        child: Row(
          children: [
            // ── Sidebar de navegação vertical ─────────────────────────────
            _DesktopSidebar(
              currentTab: _tab,
              dark: dark,
              p: p,
              onTabChange: (t) => setState(() => _tab = t),
              onOpenDrawer: () => Scaffold.of(context).openEndDrawer(),
            ),

            // ── Divisor vertical sutil ─────────────────────────────────────
            Container(
              width: 1,
              color: dark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E1D2),
            ),

            // ── Conteúdo principal expansivo ──────────────────────────────
            Expanded(
              child: Column(
                children: [
                  // Header só na tab 0 (Home/Cockpit)
                  if (_tab == 0)
                    _AppHeader(
                      onTabChange: (t) => setState(() => _tab = t),
                      currentTab: _tab,
                    ),

                  Expanded(
                    child: IndexedStack(
                      index: stackIdx,
                      children: _staticScreens,
                    ),
                  ),

                  // Legal bar na parte inferior
                  _LegalBar(dark: dark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Layout mobile/tablet: Scaffold com bottom nav (layout original)
  Widget _buildMobileShell(BuildContext context, bool dark, AppProvider p) {
    final bg = dark ? const Color(0xFF141414) : const Color(0xFFF7F8FA);
    final navBg = dark ? const Color(0xFF1E1E1E) : Colors.white;
    final navBorder = dark ? const Color(0xFF333333) : const Color(0xFFE8E1D2);
    final stackIdx = _tab.clamp(0, _staticScreens.length - 1);

    return Scaffold(
      backgroundColor: bg,
      endDrawer: _AppDrawer(p: p),
      body: Stack(children: [
        Column(children: [
          // Header global só na tab 0 (Início/Cockpit).
          if (_tab == 0)
            _AppHeader(
              onTabChange: _onTabChange,
              currentTab: _tab,
            )
          else
            const SafeArea(bottom: false, child: SizedBox.shrink()),

          Expanded(child: IndexedStack(index: stackIdx, children: _staticScreens)),
        ]),
      ]),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Barra de navegação principal ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: navBg,
              border: Border(top: BorderSide(color: navBorder, width: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.30 : 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
                BoxShadow(
                  color: (dark ? const Color(0xFF1F6B48) : const Color(0xFF0F1C14))
                      .withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: SizedBox(
                height: 42,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 0 — Início
                        _buildNavBtn(0, Icons.home_rounded, p.t('cockpit'), dark, p),
                        // 3 — História Clínica
                        _buildNavBtn(3, Icons.folder_shared_rounded, 'H. Clínica', dark, p),
                        // espaço central para o FAB (IA Clínica)
                        const SizedBox(width: 72),
                        // 5 — Biblioteca
                        _buildNavBtn(5, Icons.menu_book_rounded, 'Biblioteca', dark, p),
                        // 4 — Ferramentas
                        _buildNavBtn(4, Icons.calculate_rounded, 'Ferramentas', dark, p),
                      ],
                    ),
                    Positioned(
                      top: -26,
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
    final activeColor  = dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1C14);
    final inactiveColor = dark ? Colors.white.withValues(alpha: 0.32) : const Color(0xFFB0B8C0);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _tab = idx),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: active
                  ? (dark
                      ? const Color(0xFFFFE8A6).withValues(alpha: 0.10)
                      : const Color(0xFF0F1C14).withValues(alpha: 0.08))
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 17,
              color: active ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(height: 1),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 7.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active ? activeColor : inactiveColor,
              letterSpacing: active ? 0.2 : 0,
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              width: active ? 54 : 50,
              height: active ? 54 : 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: active
                      ? [const Color(0xFFE8C070), const Color(0xFFC5A365), const Color(0xFF8B6914)]
                      : [const Color(0xFF162A1C), const Color(0xFF0F1C14), const Color(0xFF1F6B48)],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: active
                        ? const Color(0xFFC5A365).withValues(alpha: 0.70)
                        : const Color(0xFF1F6B48).withValues(alpha: 0.45),
                    blurRadius: active ? 28 : 16,
                    spreadRadius: active ? 2 : 0,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.40),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: active
                      ? const Color(0xFFFFE8A6).withValues(alpha: 0.65)
                      : const Color(0xFF1F3D28).withValues(alpha: 0.9),
                  width: active ? 2 : 1.5,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    Icons.psychology_rounded,
                    key: ValueKey(active),
                    size: active ? 30 : 26,
                    color: active
                        ? const Color(0xFF0F1C14)
                        : const Color(0xFFFFE8A6).withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
                color: active
                    ? const Color(0xFFC5A365)
                    : (dark
                        ? Colors.white.withValues(alpha: 0.38)
                        : const Color(0xFF909090)),
              ),
              child: Text(p.t('ai')),
            ),
          ],
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

  const _DesktopSidebar({
    required this.currentTab,
    required this.dark,
    required this.p,
    required this.onTabChange,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final bg          = dark ? const Color(0xFF1A1A1A) : Colors.white;
    final activeCol   = dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1C14);
    final inactiveCol = dark ? Colors.white.withValues(alpha: 0.32) : const Color(0xFFB0B8C0);
    final activeBg    = dark
        ? const Color(0xFFFFE8A6).withValues(alpha: 0.10)
        : const Color(0xFF0F1C14).withValues(alpha: 0.07);
    final isEs        = p.lang == 'es';

    return Container(
      width: MedBreakpoints.sidebarWidth,
      color: bg,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Logo / brandmark compacto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F6B48), Color(0xFF0F1C14)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: Text('M',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFE8A6),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Itens de navegação ──────────────────────────────────────────
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
            icon: Icons.auto_awesome_rounded,
            label: isEs ? 'IA' : 'IA',
            active: currentTab == 2,
            dark: dark,
            activeCol: const Color(0xFFC5A365),
            inactiveCol: inactiveCol,
            activeBg: const Color(0xFFC5A365).withValues(alpha: 0.10),
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

          // Botão de menu (drawer)
          _SidebarItem(
            icon: Icons.menu_rounded,
            label: '',
            active: false,
            dark: dark,
            activeCol: activeCol,
            inactiveCol: inactiveCol,
            activeBg: activeBg,
            onTap: onOpenDrawer,
          ),
          const SizedBox(height: 16),
        ],
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                    color: iconColor,
                    letterSpacing: 0.2,
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
    final bg = dark ? const Color(0xFF121E18) : const Color(0xFFF5F6F8);
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
    final activeColor   = dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1C14);
    final inactiveColor = dark
        ? Colors.white.withValues(alpha: 0.30)
        : const Color(0xFFB8BEC4);
    final activeBg = dark
        ? const Color(0xFF1A3528)
        : const Color(0xFF0F1C14).withValues(alpha: 0.09);

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
                              : const Color(0xFF0F1C14))
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
          colors: [Color(0xFF0A1610), Color(0xFF162E1F), Color(0xFF1A5C3A)],
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

// ── Barra legal ───────────────────────────────────────────────────────────────
class _LegalBar extends StatelessWidget {
  final bool dark;
  const _LegalBar({required this.dark});

  @override
  Widget build(BuildContext context) {
    // context.select — rebuild apenas quando lang muda
    final isEs = context.select<AppProvider, bool>((p) => p.lang == 'es');
    final bg        = dark ? const Color(0xFF080F0B) : const Color(0xFFF0F2F4);
    final border    = dark ? const Color(0xFF1A2820) : const Color(0xFFDDE1E6);
    final textColor = dark
        ? Colors.white.withValues(alpha: 0.28)
        : const Color(0xFF98A0A8);

    // Texto exigido pela Apple guideline 1.4.1 — permanece visível em todas as telas
    final disclaimer = isEs
        ? 'Herramienta educativa de apoyo clínico. La decisión y verificación de dosis son responsabilidad exclusiva del médico asistente.'
        : 'Ferramenta educacional de apoio clínico. A decisão e verificação de doses são de responsabilidade exclusiva do médico assistente.';

    // Container fora do SafeArea: a borda e o bg cobrem toda a largura,
    // o SafeArea interno só aplica padding no conteúdo — sem sobrepor a nav bar.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 8.5, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                disclaimer,
                style: TextStyle(
                  fontSize: 7.5, color: textColor,
                  height: 1.35, letterSpacing: 0.15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Drawer lateral — redesenhado (v2) ─────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  final AppProvider p;
  const _AppDrawer({required this.p});

  void _close(BuildContext context) => Navigator.of(context).pop();

  // ── Dialog de eliminação de conta ────────────────────────────────────────
  Future<void> _showDeleteAccountDialog(BuildContext context, AppProvider p) async {
    final isEs   = p.lang == 'es';
    final titleT = isEs ? 'Eliminar cuenta' : 'Eliminar conta';
    final body1  = isEs
        ? 'Esta acción es permanente e irreversible. Se eliminarán todos sus datos del sistema, incluido su historial de consultas y configuraciones.'
        : 'Esta ação é permanente e irreversível. Todos os seus dados serão removidos do sistema, incluindo histórico de consultas e configurações.';
    final body2  = isEs
        ? 'Para confirmar, escriba ELIMINAR en el campo abajo.'
        : 'Para confirmar, digite ELIMINAR no campo abaixo.';
    final cancelT  = isEs ? 'Cancelar'  : 'Cancelar';
    final confirmT = isEs ? 'Eliminar'  : 'Eliminar';
    final errorT   = isEs
        ? 'Escribe ELIMINAR para confirmar'
        : 'Digite ELIMINAR para confirmar';

    final ctrl = TextEditingController();
    String? fieldError;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: p.darkMode ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFCC3333), size: 22),
            const SizedBox(width: 8),
            Text(titleT,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFCC3333)),
            ),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body1, style: TextStyle(
                fontSize: 12.5, height: 1.5,
                color: p.darkMode ? Colors.white70 : const Color(0xFF333344),
              )),
              const SizedBox(height: 14),
              Text(body2, style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: p.darkMode ? Colors.white60 : const Color(0xFF555555),
              )),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5),
                decoration: InputDecoration(
                  hintText: 'ELIMINAR',
                  errorText: fieldError,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCC3333), width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  if (fieldError != null) setS(() => fieldError = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(cancelT, style: const TextStyle(color: Color(0xFF888888))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFCC3333),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (ctrl.text.trim() != 'ELIMINAR') {
                  setS(() => fieldError = errorT);
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    await user.delete();
                  }
                  await AuthService.logout();
                  if (context.mounted) context.read<AppProvider>().clearUser();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(isEs
                          ? 'Error al eliminar la cuenta. Vuelve a iniciar sesión e inténtalo de nuevo.'
                          : 'Erro ao eliminar conta. Faça login novamente e tente outra vez.'),
                      backgroundColor: const Color(0xFFCC3333),
                    ));
                  }
                }
              },
              child: Text(confirmT),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark    = p.darkMode;
    final bg      = dark ? const Color(0xFF0B1510) : const Color(0xFFFAFBFC);
    final divider = dark ? const Color(0xFF1A2E22) : const Color(0xFFF0EDE8);
    final textCol = dark ? const Color(0xFFEEEEEE) : const Color(0xFF0F1C14);
    final subCol  = dark ? Colors.white.withValues(alpha: 0.36) : const Color(0xFF9AA0A8);

    final initials = p.userName.isNotEmpty
        ? p.userName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : 'MC';

    return Drawer(
      width: 288,
      backgroundColor: bg,
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

                // ─── Bloco: Premium ─────────────────────────────────────────
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

                // ─── Bloco: Suporte ──────────────────────────────────────────
                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'SOPORTE' : 'SUPORTE',
                  dark: dark,
                ),
                _DrawerBlock(
                  children: [
                    _DrawerRow(
                      icon: Icons.rate_review_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      title: 'Enviar Feedback',
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

                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'PREFERENCIAS' : 'PREFERÊNCIAS',
                  dark: dark,
                ),

                // ─── Bloco: Preferências ─────────────────────────────────────
                _DrawerBlock(
                  dividerColor: divider,
                  children: [
                    // Idioma — toca para alternar PT ↔ ES
                    _DrawerRow(
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF1E88E5),
                      title: p.lang == 'es' ? 'Idioma' : 'Idioma',
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
                        // Persiste explicitamente para sobrescrever o padrão do sistema
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
                  ],
                ),

                // ─── Bloco: Modo Offline ─────────────────────────────────────
                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'MODO SIN CONEXIÓN' : 'MODO OFFLINE',
                  dark: dark,
                  color: const Color(0xFF1D4ED8),
                ),
                _OfflineDrawerCard(p: p, dark: dark),

                // ─── Bloco: Sobre o App (exigido pela Apple 1.5.0) ──────────
                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'ACERCA DE' : 'SOBRE O APP',
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
                      showDivider: false,
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
                  ],
                ),

                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'LEGAL' : 'LEGAL',
                  dark: dark,
                ),

                // ─── Bloco: Legal ────────────────────────────────────────────
                _DrawerBlock(
                  dividerColor: divider,
                  children: [
                    _DrawerRow(
                      icon: Icons.article_outlined,
                      iconColor: const Color(0xFF546E7A),
                      title: p.lang == 'es' ? 'Términos de Uso' : 'Termos de Uso',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      onTap: () {
                        _close(context);
                        showLegalSheet(context, LegalType.terms, p.lang);
                      },
                    ),
                    _DrawerRow(
                      icon: Icons.shield_outlined,
                      iconColor: const Color(0xFF546E7A),
                      title: p.lang == 'es' ? 'Política de Privacidad' : 'Política de Privacidade',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      onTap: () {
                        _close(context);
                        showLegalSheet(context, LegalType.privacy, p.lang);
                      },
                    ),
                  ],
                ),

                // ─── Bloco: Admin (condicional) ──────────────────────────────
                if ((p.isAdmin || p.isMaster) && p.currentUser != null) ...[
                  _DrawerSectionLabel(
                    label: p.isMaster ? 'MASTER' : 'ADMIN',
                    dark: dark,
                    color: const Color(0xFFFF8C00),
                  ),
                  _DrawerBlock(
                    children: [
                      _DrawerRow(
                        icon: Icons.admin_panel_settings_rounded,
                        iconColor: const Color(0xFFFF8C00),
                        title: p.lang == 'es' ? 'Panel Admin' : 'Painel Admin',
                        dark: dark,
                        textCol: textCol,
                        subCol: subCol,
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
                ],

                _DrawerSectionLabel(
                  label: p.lang == 'es' ? 'CUENTA' : 'CONTA',
                  dark: dark,
                  color: const Color(0xFFCC3333),
                ),

                // ─── Bloco: Zona de perigo ───────────────────────────────────
                _DrawerBlock(
                  dividerColor: divider,
                  children: [
                    _DrawerRow(
                      icon: Icons.delete_outline_rounded,
                      iconColor: const Color(0xFFCC3333),
                      title: p.lang == 'es' ? 'Eliminar Cuenta' : 'Eliminar Conta',
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
              color: dark ? const Color(0xFF070E09) : const Color(0xFFF0EDE8),
              border: Border(top: BorderSide(color: divider, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
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

// ── Cabeçalho do Drawer (card de perfil) ──────────────────────────────────────
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF091410), Color(0xFF142A1C), Color(0xFF1A5035)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Linha 1: logo + botão fechar
              Row(children: [
                const BrandMark(small: true),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white.withValues(alpha: 0.07),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 0.8),
                    ),
                    child: Icon(Icons.close_rounded, size: 15, color: Colors.white.withValues(alpha: 0.55)),
                  ),
                ),
              ]),

              const SizedBox(height: 14),

              // Linha 2: Avatar + info + botão editar
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Avatar
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1F4030), Color(0xFF101E16)],
                    ),
                    border: Border.all(color: _kGold.withValues(alpha: 0.55), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: _kGold.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _kGoldL),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nome + profissão
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        p.userName.isNotEmpty ? p.userName : 'MedCases Pro',
                        style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w900,
                          color: Colors.white, letterSpacing: -0.3, height: 1.15,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if ((p.currentUser?.profession?.isNotEmpty ?? false) ||
                          (p.currentUser?.institution?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (p.currentUser?.profession?.isNotEmpty ?? false)
                              p.currentUser!.profession!,
                            if (p.currentUser?.institution?.isNotEmpty ?? false)
                              p.currentUser!.institution!,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withValues(alpha: 0.45),
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _kGold.withValues(alpha: 0.14),
                      border: Border.all(color: _kGold.withValues(alpha: 0.40), width: 0.9),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.edit_rounded, size: 13, color: _kGoldL),
                      const SizedBox(width: 5),
                      Text(
                        p.lang == 'es' ? 'Editar' : 'Editar',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kGoldL),
                      ),
                    ]),
                  ),
                ),
              ]),

              // Badge admin/master (inline, compacto)
              if (p.isAdmin || p.isMaster) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _kGold.withValues(alpha: 0.14),
                      border: Border.all(color: _kGold.withValues(alpha: 0.40)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.verified_rounded, size: 10, color: _kGoldL),
                      const SizedBox(width: 4),
                      Text(
                        p.isMaster ? 'MASTER' : 'ADMIN',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _kGoldL, letterSpacing: 0.8),
                      ),
                    ]),
                  ),
                ]),
              ],
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
    final cardBg = dark ? const Color(0xFF0F1A14) : Colors.white;
    final borderCol = dark ? const Color(0xFF1A2E22) : const Color(0xFFECE9E4);
    final divCol = dividerColor ?? (dark ? const Color(0xFF1A2E22) : const Color(0xFFECE9E4));

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
                ? [const Color(0xFF242424), const Color(0xFF1A1A1A)]
                : [const Color(0xFF1A3020), const Color(0xFF0F1C14)],
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

// ── Badge de idioma ───────────────────────────────────────────────────────────
class _LangBadge extends StatelessWidget {
  final String lang;
  const _LangBadge({required this.lang});

  @override
  Widget build(BuildContext context) {
    // Mostra a bandeira + nome curto do idioma atual
    final label = lang == 'pt' ? '🇧🇷 PT' : '🇪🇸 ES';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: const Color(0xFFC5A365).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFFC5A365).withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFC5A365), letterSpacing: 0.5),
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
        color: dark ? const Color(0xFF1F6B48) : const Color(0xFFDDDDDD),
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
          colors: [Color(0xFF141414), Color(0xFF1E1E1E), Color(0xFF252525)],
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
                    userName.isNotEmpty ? userName : 'MedCases Pro',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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
  static const _kGold       = Color(0xFFD4A96A);

  @override
  Widget build(BuildContext context) {
    final isEs  = p.lang == 'es';
    final bg    = dark ? const Color(0xFF111A14) : const Color(0xFFF7F9F7);
    final card  = dark ? const Color(0xFF1A2820) : Colors.white;
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
                    infoRow(Icons.language_outlined,
                        isEs ? 'SITIO WEB' : 'SITE',
                        'medcasespro.com'),

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
    final bg = dark ? const Color(0xFF121F17) : Colors.white;
    final titleColor = dark ? Colors.white : const Color(0xFF0F1C14);
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
                      color: const Color(0xFF0F1C14),
                      boxShadow: [BoxShadow(color: const Color(0xFF0F1C14).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
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
    final fillColor = dark ? const Color(0xFF162820) : const Color(0xFFF5F0E8);
    final textColor = dark ? Colors.white : const Color(0xFF0F1C14);
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

// ── Modal "O que há de novo" ──────────────────────────────────────────────────
class _AppUpdateDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AppUpdateDialog({required this.data});

  static const _kDark  = Color(0xFF0F1C14);
  static const _kGreen = Color(0xFF1F6B48);
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
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A), height: 1.4)),
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
    {'icon': '🐛', 'label': 'Erro no app'},
    {'icon': '💡', 'label': 'Sugestão'},
    {'icon': '💊', 'label': 'Fármaco/Protocolo'},
    {'icon': '⭐', 'label': 'Elogio'},
    {'icon': '❓', 'label': 'Outro'},
  ];
  final List<Map<String, String>> _categoriesEs = const [
    {'icon': '🐛', 'label': 'Error en la app'},
    {'icon': '💡', 'label': 'Sugerencia'},
    {'icon': '💊', 'label': 'Fármaco/Protocolo'},
    {'icon': '⭐', 'label': 'Elogio'},
    {'icon': '❓', 'label': 'Otro'},
  ];

  List<Map<String, String>> get _categories => _isEs ? _categoriesEs : _categoriesPt;

  @override
  void initState() {
    super.initState();
    _category = _isEs ? 'Sugerencia' : 'Sugestão';
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
        'FEEDBACK — MedCases Pro\n'
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
    final textCol = dark ? Colors.white : const Color(0xFF1A1A1A);
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
                child: const Icon(Icons.rate_review_rounded,
                    color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(
                _isEs ? 'Enviar Feedback' : 'Enviar Feedback',
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
                  ? 'Tu opinión nos ayuda a mejorar el app.'
                  : 'Sua opinião nos ajuda a melhorar o app.',
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
                    ? 'Cuéntanos tu experiencia o sugerencia...'
                    : 'Conta sua experiência ou sugestão...',
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
                    ? 'Se abrirá tu app de correo con el mensaje listo.'
                    : 'Seu app de e-mail abrirá com a mensagem pronta.',
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
    final textCol = dark ? Colors.white : const Color(0xFF1A1A1A);
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
            color: dark ? const Color(0xFF161616) : const Color(0xFFF7F8FA),
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

    final panelBg   = dark ? const Color(0xFF161616) : const Color(0xFFF7F8FA);
    final searchBg  = dark ? const Color(0xFF222222) : Colors.white;
    final borderCol = dark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    final textCol   = dark ? Colors.white             : const Color(0xFF0F1C14);
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
                    ? [const Color(0xFF0F1C14), const Color(0xFF1A2820), const Color(0xFF1F3A28)]
                    : [const Color(0xFF0F1C14), const Color(0xFF1B3D2A), const Color(0xFF1F6B48)],
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
                          color: const Color(0xFF1F6B48),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1F6B48).withValues(alpha: 0.45),
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
                    color: Color(0xFF1F6B48), strokeWidth: 2))
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
          color: dark ? const Color(0xFF1F6B48).withValues(alpha: 0.50) : const Color(0xFF1F6B48).withValues(alpha: 0.35)),
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
              color: const Color(0xFF1F6B48),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1F6B48).withValues(alpha: 0.40),
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
    final textCol = dark ? Colors.white : const Color(0xFF1A1A1A);
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
                  backgroundColor: dark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  title: Text(
                    isEs ? 'Eliminar nota' : 'Excluir anotação',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : const Color(0xFF1A1A1A),
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
