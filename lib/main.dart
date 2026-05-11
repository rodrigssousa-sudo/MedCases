import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'
    show Timestamp, FirebaseFirestore, GetOptions, Source;
import 'package:http/http.dart' as http;
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
import 'screens/cases_screen.dart';
import 'screens/prescripciones_screen.dart';
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

  // ── Web: ouve ValueNotifier (persiste valor entre rebuilds) ─────────────
  // StreamBuilder perde eventos emitidos ANTES de subscrever.
  // ValueListenableBuilder lê o valor atual imediatamente — sem race condition.
  Widget _buildWebAuthGate(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: AuthService.webUser,
      builder: (context, user, _) {
        // Sem usuário → preview pré-login com histórias públicas
        if (user == null) {
          return _wrapAuth(const _PreLoginPreview());
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

            // Não autenticado → login direto, sem abrir stream de manutenção
            if (authSnap.data == null) {
              return _wrapAuth(const LoginScreen());
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

// ── Preview pré-login ─────────────────────────────────────────────────────────
// Mostra histórias clínicas públicas antes do usuário fazer login.
// A leitura do Firestore é anônima — as regras de segurança já permitem
// leitura da coleção public_histories sem autenticação.
class _PreLoginPreview extends StatefulWidget {
  const _PreLoginPreview();

  @override
  State<_PreLoginPreview> createState() => _PreLoginPreviewState();
}

class _PreLoginPreviewState extends State<_PreLoginPreview> {
  List<Map<String, dynamic>> _histories = [];
  bool _loading = true;
  String? _error;
  // FIX DEFINITIVO: sem Navigator.push — LoginScreen é exibida inline.
  // Quando webUser muda, _AuthGate troca o widget raiz sem conflito de Navigator.
  bool _showLogin = false;

  static const _kDark    = Color(0xFF07110d);
  static const _kGreen   = Color(0xFF075f45);
  static const _kGold    = Color(0xFFC5A365);
  static const _kGoldL   = Color(0xFFFFE8A6);

  @override
  void initState() {
    super.initState();
    _loadPublic();
  }

  Future<void> _loadPublic() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await FirestoreService.loadPublicHistories();
      final maps = list.map((h) => h.toJson()).toList();
      if (mounted) setState(() { _histories = maps; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _goLogin() => setState(() => _showLogin = true);
  void _backToPreview() => setState(() => _showLogin = false);

  @override
  Widget build(BuildContext context) {
    // FIX DEFINITIVO: sem Navigator.push — LoginScreen inline.
    // _AuthGate troca o widget raiz quando webUser muda, sem conflito de stack.
    if (_showLogin) {
      return Theme(
        data: MedCasesApp._authTheme,
        child: LoginScreen(onBack: _backToPreview),
      );
    }
    return Scaffold(
      backgroundColor: _kDark,
      body: Column(children: [
        // ── Header compacto ──────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kDark, Color(0xFF123326), _kGreen],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Row(children: [
                // Logo + nome
                const BrandMark(small: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('COMUNIDADE', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w900,
                      color: Color(0xBFFFE8A6), letterSpacing: 2)),
                    const SizedBox(height: 1),
                    Text('Histórias clínicas públicas',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.85))),
                  ]),
                ),
                // Botão "Entrar"
                GestureDetector(
                  onTap: _goLogin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD4AF5A), _kGold],
                      ),
                      boxShadow: [
                        BoxShadow(color: _kGold.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: const Text('Entrar', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900, color: _kDark)),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Banner teaser ────────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _kGold.withValues(alpha: 0.12),
            border: Border.all(color: _kGold.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            const Icon(Icons.lock_open_rounded, size: 18, color: _kGold),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
                  children: [
                    TextSpan(text: 'Preview gratuito — ', style: TextStyle(color: _kGoldL.withValues(alpha: 0.9), fontWeight: FontWeight.w800)),
                    TextSpan(text: 'faça login para criar, salvar e compartilhar suas próprias histórias clínicas.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65))),
                  ],
                ),
              ),
            ),
          ]),
        ),

        // ── Lista de histórias ────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kGold, strokeWidth: 2.5))
              : _error != null
                  ? _buildError()
                  : _histories.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: _kGold,
                          onRefresh: _loadPublic,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(0, 10, 0, 100),
                            itemCount: _histories.length,
                            itemBuilder: (_, i) => _PreviewCard(
                              data: _histories[i],
                              onTap: _goLogin,
                            ),
                          ),
                        ),
        ),
      ]),

      // ── FAB fixo "Criar conta / Entrar" ─────────────────────────────────────
      floatingActionButton: _loading
          ? null
          : GestureDetector(
              onTap: _goLogin,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _kDark,
                  border: Border.all(color: _kGold.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 6)),
                    BoxShadow(color: _kGold.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.login_rounded, size: 18, color: _kGoldL),
                  const SizedBox(width: 8),
                  const Text('Entrar ou criar conta', style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900, color: _kGoldL)),
                ]),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('Não foi possível carregar as histórias.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadPublic,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: _kGold),
              child: const Text('Tentar novamente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kDark)),
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _goLogin,
            child: Text('Ir para login →', style: TextStyle(fontSize: 13, color: _kGold.withValues(alpha: 0.8), fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.folder_open_rounded, size: 48, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('Ainda sem histórias públicas.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.5)),
            textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Faça login e seja o primeiro a compartilhar!',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.35), fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _goLogin,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: _kGold),
              child: const Text('Entrar agora', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kDark)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Card de preview pré-login ─────────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _PreviewCard({required this.data, required this.onTap});

  static const _kDark   = Color(0xFF07110d);
  static const _kGold   = Color(0xFFC5A365);
  static const _kGoldL  = Color(0xFFFFE8A6);
  static const _kCardBorder = Color(0xFF1A2E20);

  String _str(String key) => (data[key] ?? '').toString();

  String get _title {
    final cc = _str('chiefComplaint');
    final fd = _str('finalDiagnosis');
    final wd = _str('workingDiagnosis');
    if (cc.isNotEmpty) return cc;
    if (fd.isNotEmpty) return fd;
    if (wd.isNotEmpty) return wd;
    return 'História Clínica';
  }

  String get _category => _str('category').isNotEmpty ? _str('category') : 'Clínica Geral';
  String get _finalDx  => _str('finalDiagnosis');
  String get _workingDx => _str('workingDiagnosis');
  String get _author   => _str('authorName').isNotEmpty ? _str('authorName') : 'Anônimo';
  String get _age      => _str('patientAge');
  String get _sex      => _str('patientSex');
  String get _outcome  => _str('outcome');

  Color get _outcomeColor {
    switch (_outcome) {
      case 'alta':         return const Color(0xFF065F46);
      case 'obito':        return const Color(0xFFCC2222);
      case 'transferencia': return const Color(0xFF1E40AF);
      default:             return const Color(0xFFC5A365);
    }
  }
  String get _outcomeLabel {
    switch (_outcome) {
      case 'alta':         return 'Alta';
      case 'obito':        return 'Óbito';
      case 'transferencia': return 'Transferência';
      default:             return 'Internado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF0E1A14),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Topo com categoria + outcome ──────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1A2E20))),
            ),
            child: Row(children: [
              // Categoria
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _kDark),
                child: Text(_category, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _kGoldL)),
              ),
              const SizedBox(width: 6),
              // Outcome
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _outcomeColor.withValues(alpha: 0.15),
                  border: Border.all(color: _outcomeColor.withValues(alpha: 0.4)),
                ),
                child: Text(_outcomeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _outcomeColor)),
              ),
              const Spacer(),
              // Ícone "ver" — indica que precisa de login
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _kGold.withValues(alpha: 0.12),
                  border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.login_rounded, size: 10, color: _kGold),
                  SizedBox(width: 4),
                  Text('Ver completo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _kGold)),
                ]),
              ),
            ]),
          ),

          // ── Corpo do card ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Título
              Text(_title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Dados do paciente
              if (_age.isNotEmpty || _sex.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  [if (_age.isNotEmpty) '$_age anos', if (_sex.isNotEmpty) _sex].join(' • '),
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w600),
                ),
              ],
              // Diagnóstico final
              if (_finalDx.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF065F46).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF065F46).withValues(alpha: 0.4)),
                  ),
                  child: Text('Dx: $_finalDx',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6BCCA0)),
                    overflow: TextOverflow.ellipsis),
                ),
              ] else if (_workingDx.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF92400E).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF92400E).withValues(alpha: 0.4)),
                  ),
                  child: Text('Hipótese: $_workingDx',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFB347)),
                    overflow: TextOverflow.ellipsis),
                ),
              ],
              // Autor
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 12, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(_author,
                    style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                ),
                // Indicador "bloqueado" — conteúdo completo só com login
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_rounded, size: 10, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(width: 4),
                  Text('Login para ler tudo',
                    style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.25), fontWeight: FontWeight.w600)),
                ]),
              ]),
            ]),
          ),
        ]),
      ),
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
            'Cargando MedCases Pro...',
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF07110d)),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(_checking ? 'Verificando...' : 'Verificar aprovação'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A365),
                  foregroundColor: const Color(0xFF07110d),
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
  // Header recolhível: visível apenas na tab 0 (Cockpit/Início)
  bool get _headerVisible => _tab == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    final bg = dark ? const Color(0xFF0A1510) : const Color(0xFFF7F8FA);
    final navBg = dark ? const Color(0xFF0E1A14) : Colors.white;
    final navBorder = dark ? const Color(0xFF1A2E20) : const Color(0xFFE8E1D2);

    // Tela combo Rx + Protocolos com TabBar interna
    final rxProtoScreen = _RxProtoCombo(
      subTab: _rxProtoSub,
      onSubTabChange: (i) => setState(() => _rxProtoSub = i),
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

  const _RxProtoCombo({
    required this.subTab,
    required this.onSubTabChange,
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
            Container(width: 1, height: 24, color: borderCol),
            _SubTabBtn(
              icon: Icons.folder_open_rounded,
              label: p.t('cases'),
              active: subTab == 2,
              dark: dark,
              onTap: () => onSubTabChange(2),
            ),
            Container(width: 1, height: 24, color: borderCol),
            _SubTabBtn(
              icon: Icons.description_rounded,
              label: p.t('prescriptions'),
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
            const DrugsScreen(),
            const ProtocolsScreen(),
            const CasesScreen(),
            const PrescripcionesScreen(),
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
                  const Text('Inicio',
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
                if (p.isAdmin || p.isMaster) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _kGold.withValues(alpha: 0.2),
                      border: Border.all(color: _kGold.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      p.isMaster ? 'MASTER' : 'ADMIN',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _kGoldL, letterSpacing: 0.5),
                    ),
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
                    title: 'Editar perfil',
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
                    title: 'Idioma',
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

                  // ── Admin (apenas para admins e master) ─────────────────
                  // Guarda null-safety: p.currentUser pode ser null no primeiro
                  // frame após login Web (setUser() é agendado via microtask).
                  if ((p.isAdmin || p.isMaster) && p.currentUser != null) ...[
                    _DrawerItem(
                      icon: Icons.admin_panel_settings_rounded,
                      iconColor: const Color(0xFFFF8C00),
                      title: p.lang == 'es' ? 'Panel Admin' : 'Painel Admin',
                      subtitle: p.lang == 'es' ? 'Gestión de usuarios' : 'Gestão de usuários',
                      dark: dark,
                      textCol: textCol,
                      subCol: subCol,
                      onTap: () {
                        _close(context);
                        final admin = p.currentUser;
                        if (admin == null) return; // guarda extra por race condition
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AdminScreen(currentAdmin: admin),
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
                      color: const Color(0xFF07110d),
                      boxShadow: [BoxShadow(color: const Color(0xFF07110d).withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
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

// ── Modal "O que há de novo" ──────────────────────────────────────────────────
class _AppUpdateDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AppUpdateDialog({required this.data});

  static const _kDark  = Color(0xFF07110d);
  static const _kGreen = Color(0xFF075f45);
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
                colors: [_kDark, Color(0xFF123326)],
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

