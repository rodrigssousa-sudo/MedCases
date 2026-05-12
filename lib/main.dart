import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'screens/cockpit_screen.dart';
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
    // Falha real de configuração (ex: firebase_options errado, JS SDK ausente)
    // _AuthGate mostra LoginScreen graciosamente via snapshot.hasError
    debugPrint('[MedCases] Firebase.initializeApp falhou: $e');
    // CRÍTICO: usar Future.error() direto sem .catchError() faz o Dart emitir
    // um "Uncaught Error" na zona global quando nenhum listener consome o erro
    // antes do GC. Resolvemos capturando o erro antecipadamente com catchError,
    // tornando o Future "consumido" e seguro para o FutureBuilder.
    _firebaseInit = Future<void>.error(e)
      ..catchError((_) {/* erro capturado — FutureBuilder lida via hasError */});
  }

  final provider = AppProvider();

  // SharedPreferences falha em abas anônimas (localStorage bloqueado)
  try {
    await provider.loadPrefs();
  } catch (e) {
    debugPrint('[MedCases] SharedPreferences indisponível: $e');
  }

  // ── Restauração silenciosa de sessão ("Manter conectado") ──────────────────
  // Tenta renovar o refreshToken antes do runApp — se bem-sucedido, webUser.value
  // já estará preenchido quando _AuthGate construir, saltando direto ao MainShell.
  // Timeout de 8 s está dentro de restoreSession(); rede falha → LoginScreen normal.
  if (kIsWeb) {
    try {
      await AuthService.restoreSession();
    } catch (_) {}
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
            surface: const Color(0xFF141A17),
            onSurface: const Color(0xFFEAEBEA),
            surfaceContainerHighest: const Color(0xFF1E2922),
            outline: const Color(0xFF2E3D34),
            outlineVariant: const Color(0xFF253020),
            error: const Color(0xFFFF6B6B),
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: const Color(0xFF0F1C14),
            secondary: const Color(0xFF1F6B48),
            surface: const Color(0xFFFFFDF8),
            onSurface: const Color(0xFF0F1C14),
            surfaceContainerHighest: const Color(0xFFF0EDE6),
          ),
    scaffoldBackgroundColor: dark ? const Color(0xFF101E16) : const Color(0xFFF5F6F8),
    cardColor: dark ? const Color(0xFF141A17) : Colors.white,
    dividerColor: dark ? const Color(0xFF253020) : const Color(0xFFE2E6EA),
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
// Firebase já está inicializado quando chegamos aqui (await no main)
// _AuthGate: aguarda Firebase inicializar via FutureBuilder,
// depois ouve o stream de auth — runApp() já aconteceu, splash aparece imediatamente
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  Widget _wrapAuth(Widget child) => Theme(
    data: MedCasesApp._authTheme,
    child: child,
  );

  // ── Web: ouve ValueNotifier (persiste valor entre rebuilds) ─────────────
  // StreamBuilder perde eventos emitidos ANTES de subscrever.
  // ValueListenableBuilder lê o valor atual imediatamente — sem race condition.
  Widget _buildWebAuthGate(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: AuthService.webUser,
      builder: (context, user, _) {
        // Sem usuário → preview pré-login com histórias públicas
        if (user == null) {
          return _wrapAuth(const PreLoginPreview());
        }

        // Usuário bloqueado
        if (user.isBlocked) {
          AuthService.logout();
          return _wrapAuth(_BlockedScreen(user: user));
        }

        // Usuário pendente
        if (user.isPending) {
          return _wrapAuth(_PendingScreen(user: user));
        }

        // Usuário aprovado → stream de manutenção
        return _buildMaintenanceGate(context, user);
      },
    );
  }

  // ── Etapa final: manutenção → MainShell ──────────────────────────────────
  Widget _buildMaintenanceGate(BuildContext context, UserModel user) {
    // ── Web: NÃO abre stream do Firestore SDK ────────────────────────────
    // FirestoreService.maintenanceStream() usa .snapshots() do SDK do Firestore.
    // No domínio medcasespro.com (não autorizado no Firebase Console), esse SDK
    // falha com CORS silencioso → StreamBuilder fica em ConnectionState.waiting
    // para sempre → MainShell nunca é exibido.
    //
    // Solução: no Web, usamos _WebMainShellGate — um StatefulWidget que chama
    // setUser() no initState e só exibe MainShell após o Future completar.
    // Isso garante que o token está cacheado ANTES de qualquer tela tentar
    // chamar loadPublicHistories(), eliminando a race condition.
    if (kIsWeb) {
      return _WebMainShellGate(user: user);
    }

    // ── Android: stream normal do Firestore SDK (sem CORS) ───────────────
    return StreamBuilder<Map<String, dynamic>>(
      stream: FirestoreService.maintenanceStream(),
      builder: (context, maintSnap) {
        final isMaintenanceEnabled = maintSnap.data?['enabled'] == true;
        final maintenanceMessage   = maintSnap.data?['message'] as String? ?? '';

        // Admin / Master passam pela manutenção direto
        final bypassMaintenance = user.isAdmin || user.isMaster;

        if (isMaintenanceEnabled && !bypassMaintenance) {
          return _wrapAuth(MaintenanceScreen(message: maintenanceMessage));
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
  }

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
              return _wrapAuth(const _ConsentGate());
            }

            // Etapa 3: autenticado → busca perfil Firestore
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

                // Etapa 4: perfil OK → stream de manutenção (só para usuários logados)
                return _buildMaintenanceGate(context, user);
              },
            );
          },
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
        child: ConsentModal(lang: 'pt', onAccepted: _onAccepted),
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
      await p.setUser(widget.user);
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
  // tabs: 0=Cockpit 1=Rx/Proto 2=IA(FAB) 3=H.Clínica 4=Calculadoras
  int _tab = 0;
  // sub-tab dentro do combo Rx+Proto: 0=Rx, 1=Protocolos
  int _rxProtoSub = 0;

  // ── Performance: telas estáticas criadas uma única vez no initState ──────
  // Evita recriar AiScreen/HistoryScreen/ToolsScreen a cada setState/_tab change.
  // CockpitScreen recebe callback por referência — mantém identidade entre builds.
  late final List<Widget> _staticScreens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Instancia telas estáticas UMA VEZ — IndexedStack não recria entre trocas de tab
    _staticScreens = [
      CockpitScreen(openProtocol: _openProtocol), // 0
      const Placeholder(),                         // 1 — _RxProtoCombo (dinâmico, substituído no build)
      const AiScreen(),                            // 2
      const HistoryScreen(),                       // 3
      const ToolsScreen(),                         // 4
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Força logout quando o app é fechado/encerrado pelo SO —
  // MAS só se o usuário NÃO marcou "Manter conectado".
  // iOS: paused → background definitivo (detached raramente dispara no iOS)
  // Android: detached → processo encerrado
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.paused) {
      AuthService.isKeepLoggedInEnabled().then((keep) {
        if (!keep) AuthService.logout();
      });
    }
  }

  void _openProtocol(String id) {
    // Abre o detalhe do protocolo diretamente via bottom sheet
    // sem precisar trocar de aba ou gerenciar pendingId
    openProtocolById(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final bg = dark ? const Color(0xFF101E16) : const Color(0xFFF7F8FA);
    final navBg = dark ? const Color(0xFF121F17) : Colors.white;
    final navBorder = dark ? const Color(0xFF1E3526) : const Color(0xFFE8E1D2);

    // _RxProtoCombo precisa de _rxProtoSub que é estado local — mantido aqui.
    // As demais telas são reutilizadas de _staticScreens (criadas no initState).
    final mainScreens = [
      _staticScreens[0], // CockpitScreen
      _RxProtoCombo(     // dinâmico: reage a _rxProtoSub
        subTab: _rxProtoSub,
        onSubTabChange: (i) => setState(() => _rxProtoSub = i),
      ),
      _staticScreens[2], // AiScreen
      _staticScreens[3], // HistoryScreen
      _staticScreens[4], // ToolsScreen
    ];

    // stackIdx = _tab direto (todas as telas no stack agora)
    final stackIdx = _tab.clamp(0, mainScreens.length - 1);

    return Scaffold(
      backgroundColor: bg,
      endDrawer: _AppDrawer(p: p),
      body: Column(children: [
        // Header global só na tab 0 (Início/Cockpit).
        // Nas demais abas: oculto para liberar espaço — cada tela tem header próprio.
        // O _AppHeader já tem SafeArea interno. Nas outras abas usamos SafeArea aqui
        // para garantir que o status bar seja respeitado sem duplicar em cada tela.
        if (_tab == 0)
          _AppHeader(
            onTabChange: (t) => setState(() => _tab = t),
            currentTab: _tab,
          )
        else
          SafeArea(bottom: false, child: const SizedBox.shrink()),

        Expanded(child: IndexedStack(index: stackIdx.clamp(0, mainScreens.length - 1), children: mainScreens)),
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
                height: 52,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
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
              size: 20,
              color: active ? activeColor : inactiveColor,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 8.5,
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

// ── Combo Rx + Protocolos ─────────────────────────────────────────────────────
class _RxProtoCombo extends StatelessWidget {
  final int subTab;
  final ValueChanged<int> onSubTabChange;

  const _RxProtoCombo({
    required this.subTab,
    required this.onSubTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final bg = dark ? const Color(0xFF101E16) : const Color(0xFFF5F6F8);
    final borderCol = dark ? const Color(0xFF1E3028) : const Color(0xFFE0E4E8);

    return Column(children: [
      // ── Seletor de sub-tab ────────────────────────────────────────────────
      Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: dark ? const Color(0xFF0C1812) : Colors.white,
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
              active: subTab == 0,
              dark: dark,
              onTap: () => onSubTabChange(0),
            ),
            Container(width: 1, height: 24, color: borderCol),
            _SubTabBtn(
              icon: Icons.medication_rounded,
              label: p.t('drugs'),
              active: subTab == 1,
              dark: dark,
              onTap: () => onSubTabChange(1),
            ),
            Container(width: 1, height: 24, color: borderCol),
            _SubTabBtn(
              icon: Icons.emergency_rounded,
              label: p.t('protocols'),
              active: subTab == 2,
              dark: dark,
              onTap: () => onSubTabChange(2),
            ),
            Container(width: 1, height: 24, color: borderCol),
            _SubTabBtn(
              icon: Icons.folder_open_rounded,
              label: p.t('cases'),
              active: subTab == 3,
              dark: dark,
              onTap: () => onSubTabChange(3),
            ),
          ]),
        ),
      ),
      // ── Conteúdo ──────────────────────────────────────────────────────────
      Expanded(
        child: IndexedStack(
          index: subTab,
          children: [
            const PrescripcionesScreen(),
            const DrugsScreen(),
            const ProtocolsScreen(),
            const CasesScreen(),
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
    final bg        = dark ? const Color(0xFF080F0B) : const Color(0xFFF0F2F4);
    final border    = dark ? const Color(0xFF1A2820) : const Color(0xFFDDE1E6);
    final textColor = dark
        ? Colors.white.withValues(alpha: 0.28)
        : const Color(0xFF98A0A8);

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          border: Border(top: BorderSide(color: border, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(children: [
          Icon(Icons.info_outline_rounded, size: 8.5, color: textColor.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'Fines educativos y soporte a la decisión clínica. No reemplaza el juicio médico profesional.',
              style: TextStyle(
                fontSize: 7.5, color: textColor,
                height: 1.3, letterSpacing: 0.15,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
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
                    // Idioma
                    _DrawerRow(
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF1E88E5),
                      title: p.lang == 'es' ? 'Idioma' : 'Idioma',
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1A3020), Color(0xFF0F1C14)],
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
          // Título
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: textCol,
                letterSpacing: -0.1,
              ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: const Color(0xFFC5A365).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFFC5A365).withValues(alpha: 0.38)),
      ),
      child: Text(
        lang.toUpperCase(),
        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: Color(0xFFC5A365), letterSpacing: 1),
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
    final p = context.watch<AppProvider>();
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
            color: Colors.black.withValues(alpha: 0.38),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: const Color(0xFF1F6B48).withValues(alpha: 0.18),
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
                    p.userName.isNotEmpty ? p.userName : 'MedCases Pro',
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
                    p.lang == 'es' ? 'Apoyo clínico educativo' : 'Apoio clínico educacional',
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
                Text(widget.p.lang == 'es' ? 'Editar perfil' : 'Editar perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: titleColor)),
                Text(widget.p.lang == 'es' ? 'Tu información profesional' : 'Suas informações profissionais', style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w500)),
              ]),
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

            // Título
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
              Text(
                _isEs ? 'Enviar Feedback' : 'Enviar Feedback',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: textCol),
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

