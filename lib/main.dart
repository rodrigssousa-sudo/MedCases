import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_localizations/flutter_localizations.dart';
// BUILD 280: sincronização nativa splash iOS — elimina blink/flash (Guideline 2.1)
import 'package:flutter_native_splash/flutter_native_splash.dart';

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
import 'providers/ui_provider.dart';       // BUILD 326: sub-provider de UI
import 'providers/ai_chat_provider.dart';  // BUILD 326: sub-provider de IA/chat
import 'providers/tools_state_provider.dart'; // BUILD 445: estado clínico compartilhado
import 'services/auth_service.dart';
import 'services/firebase_runtime_guard.dart'; // BUILD 299: safe Firebase.apps access
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
// ai_gateway_service.dart — Build 156: importado apenas como shim de compatibilidade.
// O gateway Node.js foi desativado; o shim delega para GeminiServiceV2 (BYOA direto).
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'services/offline_calculator_cache_service.dart'; // BUILD 240: smart offline cache
import 'services/app_resume_coordinator.dart';           // BUILD 241: background/resume safety
import 'widgets/brand_mark.dart';
import 'widgets/common_widgets.dart' show MedBreakpoints, AppHaptics;
import 'widgets/medcases_webview_screen.dart'; // BUILD 323 — MANDATO 2: in-app WebView
import 'platform/web_impl.dart'
    if (dart.library.io) 'platform/web_stub.dart' as webPlatform;

Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  // BUILD 280 — CAMADA 3: Assincronismo blindado iOS anti-flash
  // ─────────────────────────────────────────────────────────────────────────
  // ORDEM CRÍTICA: capturar a binding ANTES de qualquer outro código assíncrono,
  // depois IMEDIATAMENTE preservar o LaunchScreen.storyboard nativo.
  //
  // Sem esta chamada, o UIKit encerra o processo do storyboard assim que o
  // Dart isolate emite o primeiro frame Flutter — que ainda é transparente/
  // vazio durante o boot assíncrono (Firebase, prefs, auth). Resultado: 1-3
  // frames de tela escura/branca visíveis → rejeição pela Apple (Guideline 2.1).
  //
  // Com preserve(): o storyboard permanece sobreposto ao Flutter engine até
  // FlutterNativeSplash.remove() ser chamado explicitamente. O iOS não vê
  // nenhum frame intermediário — transição 100% suave garantida.
  //
  // EXCLUSÃO WEB: flutter_native_splash é no-op em Web (sem storyboard), mas
  // a guard kIsWeb garante zero overhead no bundle JS.
  final WidgetsBinding widgetsBinding =
      WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  // ── Trava orientação: portrait-only em iPhone e iPad ─────────────────────
  // Info.plist já declara apenas portrait para iOS, mas esta chamada cobre
  // também Android e garante que o SystemChrome respeite no runtime.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Cria o provider — sem await aqui, boot é disparado em background.
  final provider = AppProvider();
  // BUILD 445: ToolsStateProvider singleton — estado clínico compartilhado entre as 4 abas
  final toolsState = ToolsStateProvider();

  // ── Future criado ANTES do runApp — sem `late`, sem estado global ────────
  // Ao usar `late final`, o iOS pode reutilizar o isolate após force-close e
  // encontrar a variável marcada como inicializada com um Future morto.
  // Solução: variável `final` comum, atribuída antes do runApp(), passada
  // como parâmetro para MedCasesApp → _AuthGate. Cada cold-start cria um
  // Future novo garantido.
  final firebaseInit = _bootInBackground(provider);

  // ── runApp() IMEDIATO — splash aparece em < 500ms ────────────────────────
  runApp(
    // BUILD 326: MultiProvider expõe AppProvider + sub-providers especializados.
    // UiProvider e AiChatProvider são as instâncias criadas pelo AppProvider,
    // garantindo que compartilham o mesmo estado — zero duplicação de lógica.
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider.value(value: provider.uiProvider),
        ChangeNotifierProvider.value(value: provider.aiChatProvider),
        // BUILD 445: ToolsStateProvider — controllers clínicos compartilhados
        ChangeNotifierProvider.value(value: toolsState),
      ],
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
  // Build 156: a key BYOA é usada tanto para o Lab quanto para o chat principal.
  // GeminiServiceV2.sendStream() recebe a key por parâmetro em cada chamada.
  // GeminiService.initFromStorage() carrega a key do SharedPreferences/LocalStorage.
  try {
    await GeminiService.initFromStorage().timeout(const Duration(seconds: 2));
  } catch (_) {}
  // Build 156: AiGatewayService.configure() REMOVIDO — gateway Node.js desativado.
  // O Flutter fala diretamente com generativelanguage.googleapis.com (BYOA).

  // 2b. NotificationService — sem await para não atrasar boot; timezone init
  //     é síncrono mas leve (~20ms). Não faz nada no Web.
  NotificationService.init().catchError((e) {
    debugPrint('[MedCases] NotificationService.init falhou (ignorado): $e');
  });

  // 3. Firebase init — com timeout e sem rethrow
  // BUILD 299: FirebaseRuntimeGuard.safeApps.isEmpty previne dupla inicialização.
  // Usando safeApps (try/catch interno) em vez de Firebase.apps.isEmpty direto,
  // que pode lançar NullError no Safari quando o interop JS está em estado nulo.
  // Sem rethrow: se Firebase falhar, _AuthGate ainda tenta o fluxo web-auth
  // em vez de travar em loading infinito.
  try {
    if (FirebaseRuntimeGuard.safeApps.isEmpty) {
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
  // BUILD 281: AuthService.restoreSession() agora é idempotente via _restoreInFlight.
  // Chamadas concorrentes (ex: visibilitychange + boot) compartilham o mesmo Future,
  // prevenindo dupla troca do refreshToken que destruía a sessão no mobile web.
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
    // BUILD 326: context.select<UiProvider> — rebuild APENAS quando darkMode muda.
    // UiProvider é notificado SOMENTE por toggleDarkMode() / setLang() —
    // completamente isolado do streaming de IA e outros notifyListeners().
    final darkMode = context.select<UiProvider, bool>((p) => p.darkMode);
    return NotificationOverlay(child: MaterialApp(
      title: 'MedCases Pro',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(false),
      darkTheme: _buildTheme(true),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,

      // BUILD 330 — CAMADA 3: Cor primária fixa do MaterialApp
      // ─────────────────────────────────────────────────────────────────────
      // MaterialApp.color é a cor usada pelo sistema operacional como "cor do app"
      // no task switcher (iOS app switcher) e como fallback de 1 frame antes do
      // ThemeData ser injetado pela árvore de providers.
      //
      // Se o Provider ainda não propagou darkMode=true quando o MaterialApp
      // constrói (ex: SharedPreferences ainda carregando), o Flutter pode pintar
      // 1 frame com a cor padrão do sistema (branca no iOS light mode).
      // Fixar #0F1116 aqui neutraliza esse frame residual de forma nativa — sem
      // depender da velocidade do SharedPreferences ou do ThemeData.
      color: const Color(0xFF0F1116), // Dark background canônico do MedCases

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

      // BUILD 280 — CAMADA 3: Builder com ColoredBox de segurança
      // ─────────────────────────────────────────────────────────────────────
      // O builder do MaterialApp é chamado em TODOS os frames antes do child
      // estar pronto. Sem esta proteção, qualquer frame onde child==null
      // resulta em um SizedBox vazio sobre fundo branco (padrão do UIKit).
      //
      // ColoredBox garante que mesmo antes do primeiro frame real do Flutter,
      // qualquer pixel renderizado pela engine seja #0F1116 — nunca branco.
      // Isso fecha o último vetor de flash residual após FlutterNativeSplash.
      //
      // ── Layout 100% responsivo — sem restrição de largura máxima ─────────
      // O app ocupa toda a tela em qualquer dispositivo: Web, iPhone, iPad e tablet.
      // O layout responsivo é gerenciado internamente por MedBreakpoints:
      //   < 1024 px  → mobile/tablet shell (AppBar + bottom nav)
      //   >= 1024 px → desktop shell (sidebar lateral + conteúdo expandido)
      // Não há mais centralização forçada ou clamp de 560 px no iPad.
      builder: (context, child) => ColoredBox(
        color: const Color(0xFF0F1116), // camada de segurança — fundo escuro MedCases
        child: child ?? const SizedBox.shrink(),
      ),
    ));  // fecha NotificationOverlay
  }

  ThemeData _buildTheme(bool dark) => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    brightness: dark ? Brightness.dark : Brightness.light,
    // ── Drawer global: scrim escuro e sem largura forçada pelo tema ──────────
    drawerTheme: DrawerThemeData(
      scrimColor: Colors.black.withOpacity(0.52),
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
        TargetPlatform.iOS:     const CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux:   FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS:   const CupertinoPageTransitionsBuilder(),
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
        TargetPlatform.iOS:     const CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux:   FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS:   const CupertinoPageTransitionsBuilder(),
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

      // BUILD 313 — SEMÁFORO 3: sinaliza ao _TimedSplash que o auth
      // determinou um estado estável (usuário aprovado). O splash nativo
      // iOS só é removido APÓS este callback, eliminando o double-flash
      // causado pelo frame intermediário de auth-loading.
      // O callback é optional (null-safe) para compatibilidade com web.
      if (context.mounted) {
        final splashState =
            context.findAncestorStateOfType<_TimedSplashState>();
        splashState?._signalAuthResolved();
      }
    });
  }

  // BUILD 313 — sinaliza _authResolved ao _TimedSplash sem exigir usuário aprovado.
  // Usado para fluxos onde o auth determinou um estado final (sem usuário,
  // bloqueado, pendente, erro Firebase) — o splash DEVE ser removido nesses casos
  // também, pois o fluxo está estável (LoginScreen / BlockedScreen / PendingScreen).
  // Agendado via addPostFrameCallback para evitar setState() durante build().
  void _signalSplashReady(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final splashState =
          context.findAncestorStateOfType<_TimedSplashState>();
      splashState?._signalAuthResolved();
    });
  }

  // ── Logout: zera state local para permitir novo ciclo de auth ─────────
  // Também chamado de dentro de builders (StreamBuilder / ValueListenableBuilder),
  // portanto setState() deve ser adiado para evitar "setState() durante build".
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
    // BUILD 313: _TimedSplash recebe onAuthResolved para atrasar
    // FlutterNativeSplash.remove() até a auth resolver estado estável.
    return _TimedSplash(
      bootFuture: widget.firebaseInit,
      splash: _wrapAuth(const _SplashScreen()),
      readyBuilder: (context) => _buildAuthFlow(context),
      onAuthResolved: () {
        // Recupera o state do _TimedSplash via context — seguro pois
        // _AuthGateState está diretamente dentro da árvore do _TimedSplash.
        // O cast para _TimedSplashState é válido: este callback só existe
        // quando o Widget pai for _TimedSplash.
        final splashState = context
            .findAncestorStateOfType<_TimedSplashState>();
        splashState?._signalAuthResolved();
      },
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
          // BUILD 313: Firebase falhou → LoginScreen é o estado final; sinaliza splash
          _signalSplashReady(context);
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
              // BUILD 313: estado final (não autenticado) → sinaliza splash
              _signalSplashReady(context);
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
                  // BUILD 313: estado final (sem perfil) → sinaliza splash
                  _signalSplashReady(context);
                  return _wrapAuth(const LoginScreen());
                }

                if (user.isBlocked) {
                  AuthService.logout();
                  _onLogout();
                  // BUILD 313: estado final (bloqueado) → sinaliza splash
                  _signalSplashReady(context);
                  return _wrapAuth(_BlockedScreen(user: user));
                }

                if (user.isPending) {
                  // BUILD 313: estado final (pendente) → sinaliza splash
                  _signalSplashReady(context);
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
      Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(0.55))),
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
// ── BUILD 317: MedCasesSplashScreen ──────────────────────────────────────────
// Tela de carregamento dinâmica que substitui o vácuo visual (tela preta) durante
// o boot assíncrono do app (Firebase, auth, prefs, cache offline).
//
// ARQUITETURA DE CONTINUIDADE VISUAL (padrão banco):
//   1. flutter_native_splash gera storyboard/XML estático com fundo #0F1116 + logo
//      → aparece IMEDIATAMENTE ao abrir o app (< 50ms, pré-Dart)
//   2. MedCasesSplashScreen (este widget) assume quando o Flutter engine inicia
//      → mesmo background + mesmo logo → transição imperceptível
//   3. CircularProgressIndicator anima enquanto dependências resolvem em background
//   4. _TimedSplash (3 semáforos) remove o splash nativo e exibe MainShell/Login
//
// DESIGN:
//   • Background: Color(0xFF0F1116) — idêntico ao storyboard/XML gerado
//   • Logo: app_icon.png 120×120 com glow verde esmeralda
//   • Título: "MedCases Pro" branco, bold, 26px, letterSpacing 1.2
//   • Tagline: "IA Clínica de bolso" verde clínico, w500
//   • Loader: CircularProgressIndicator verde + "Carregando dados clínicos..."
class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  // ── Entrada (700 ms) ─────────────────────────────────────────
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;

  // ── Pulso contínuo do logo (2400 ms, repeat) ─────────────────
  // Opacity: 1.0 → 0.55 → 1.0 (Curves.easeInOut)
  // Scale:   1.0 → 1.06 → 1.0 (Curves.easeInOut)
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseOpacity;
  late Animation<double>   _pulseScale;

  @override
  void initState() {
    super.initState();
    // ── Animação de entrada ──────────────────────────────────────
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade  = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65)));
    _slide = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    // ── Pulso contínuo — inicia após a entrada terminar ──────────
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
    _pulseOpacity = Tween<double>(begin: 1.0, end: 0.55)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseScale = Tween<double>(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    // Começa o pulso depois que a animação de entrada termina
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _pulseCtrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      // ── Background idêntico ao flutter_native_splash (storyboard/XML) ──────
      // Garante continuidade visual perfeita: o storyboard nativo e este widget
      // têm exatamente o mesmo pixel de fundo — zero flash na transição.
      backgroundColor: const Color(0xFF0F1116),
      body: Stack(children: [

        // ── Detalhe geométrico sutil — profundidade sem poluição visual ────────
        Positioned(
          top: -h * 0.04,
          right: -70,
          child: Container(
            width: 240, height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0E7C52).withOpacity(0.055),
            ),
          ),
        ),
        Positioned(
          bottom: h * 0.12,
          left: -50,
          child: Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF13A06A).withOpacity(0.035),
            ),
          ),
        ),

        // ── Bloco central: logo + título + tagline ────────────────────────────
        // Posicionado no terço superior da tela para hierarquia visual clara.
        Positioned(
          top: h * 0.27,
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

                    // ── Logo 120×120 com glow verde + pulso suave ─────────────
                    // AnimatedBuilder reage ao _pulseCtrl (repeat reverse):
                    // opacidade 1.0↔0.55 e escala 1.0↔1.06 com easeInOut 2.4s.
                    AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, child) => Opacity(
                        opacity: _pulseOpacity.value,
                        child: Transform.scale(
                          scale: _pulseScale.value,
                          child: child,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0E7C52).withOpacity(0.30),
                              blurRadius: 60,
                              spreadRadius: 12,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                          // Fallback elegante caso o asset falhe (ex: hot-reload parcial)
                          errorBuilder: (_, __, ___) => Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0F1C14), Color(0xFF1F6B48)],
                              ),
                            ),
                            child: const Center(
                              child: Text('M+', style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFE8A6),
                              )),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Título principal ───────────────────────────────────────
                    // letterSpacing 1.2 para legibilidade premium em splash.
                    const Text(
                      'MedCases Pro',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Tagline de produto ─────────────────────────────────────
                    Text(
                      'IA Clínica de bolso',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF13A06A).withOpacity(0.85),
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

        // ── Bloco inferior: progress indicator animado + label ciclante ──────
        // Posicionado a 72px do fundo com safeBottom para respeitar o sistema.
        Positioned(
          bottom: 72,
          left: 0, right: 0,
          child: FadeTransition(
            opacity: _fade,
            child: _SplashLoadingIndicator(pulseCtrl: _pulseCtrl),
          ),
        ),

      ]),
    );
  }
}

// ── Loading indicator ciclante (usado pelo _SplashScreen) ────────────────────
// Exibe um CircularProgressIndicator verde + texto que cicla entre 4 mensagens
// a cada 3.5 s. Usa o mesmo _pulseCtrl do logo para sincronizar o fade do texto
// com o pulso visual (opacity share).
class _SplashLoadingIndicator extends StatefulWidget {
  final AnimationController pulseCtrl;
  const _SplashLoadingIndicator({required this.pulseCtrl});
  @override
  State<_SplashLoadingIndicator> createState() => _SplashLoadingIndicatorState();
}

class _SplashLoadingIndicatorState extends State<_SplashLoadingIndicator> {
  static const _msgs = [
    'Carregando dados clínicos...',
    'Inicializando IA clínica...',
    'Preparando protocolos...',
    'Quase lá...',
  ];
  int _msgIdx = 0;

  @override
  void initState() {
    super.initState();
    // Cicla as mensagens a cada 3.5 s
    Future<void>.delayed(const Duration(milliseconds: 3500), _nextMsg);
  }

  void _nextMsg() {
    if (!mounted) return;
    setState(() => _msgIdx = (_msgIdx + 1) % _msgs.length);
    Future<void>.delayed(const Duration(milliseconds: 3500), _nextMsg);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFF13A06A).withOpacity(0.70),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Text(
            _msgs[_msgIdx],
            key: ValueKey(_msgIdx),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.42),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
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
  // BUILD 313 — terceiro semáforo: notifica quando auth resolve estado estável.
  // Passado como callback para que _AuthGateState possa sinalizar ao splash
  // que o fluxo de auth determinou um usuário aprovado/bloqueado/pendente,
  // impedindo que FlutterNativeSplash.remove() dispare antes desse momento.
  final VoidCallback? onAuthResolved;

  const _TimedSplash({
    required this.bootFuture,
    required this.readyBuilder,
    required this.splash,
    this.onAuthResolved,
  });

  @override
  State<_TimedSplash> createState() => _TimedSplashState();
}

class _TimedSplashState extends State<_TimedSplash> {
  static const _kMinMs = 1200;  // mínimo 1.2s de splash dinâmico visível
  // BUILD 241: watchdog — se o bootstrap não terminar em 20s, força conclusão.
  // Protege contra: browser throttle, Firebase timeout, aba inativa durante boot.
  static const _kWatchdogMs = 20000;

  bool _minTimeDone    = false;
  bool _bootDone       = false;
  // SEMÁFORO 3: authResolved — determina a transição splash → conteúdo real.
  // Só muda para true quando _AuthGateState._onUserResolved() sinaliza que
  // o StreamBuilder<UserModel?> já determinou um estado estável de auth
  // (aprovado / bloqueado / pendente / não autenticado).
  bool _authResolved   = false;

  @override
  void initState() {
    super.initState();

    // Timer mínimo
    Future<void>.delayed(const Duration(milliseconds: _kMinMs), () {
      if (mounted) setState(() => _minTimeDone = true);
    });

    // Boot future (Firebase + prefs + auth)
    widget.bootFuture.whenComplete(() {
      if (mounted) setState(() {
        _bootDone    = true;
        _minTimeDone = true; // se boot terminou, min também está OK
      });
      AppResumeCoordinator.instance.completeBootstrap(); // BUILD 241
    });

    // BUILD 241: watchdog independente — garante que bootstrap nunca trava.
    // Usa DateTime.now() para medir tempo real, não um Timer que pode ser
    // throttled pelo browser em abas inativas.
    final bootStart = DateTime.now();
    AppResumeCoordinator.instance.registerBootstrap(
      onTimeout: () {
        final elapsed = DateTime.now().difference(bootStart).inMilliseconds;
        debugPrint('[BOOTSTRAP_WATCHDOG] elapsedMs=$elapsed '
            'action=force_complete (resume timeout)');
        if (mounted) setState(() { _bootDone = true; _minTimeDone = true; });
      },
    );

    // Timer local como backup: se watchdog não disparou, garante
    // que o splash nunca fica travado para sempre.
    Future<void>.delayed(const Duration(milliseconds: _kWatchdogMs), () {
      if (!mounted) return;
      if (!_bootDone) {
        final elapsed = DateTime.now().difference(bootStart).inMilliseconds;
        debugPrint('[BOOTSTRAP_WATCHDOG] elapsedMs=$elapsed action=force_complete (timer)');
        setState(() { _bootDone = true; _minTimeDone = true; });
        AppResumeCoordinator.instance.completeBootstrap();
      }
    });

    // Watchdog para _authResolved: garante que o splash nunca fica travado
    // se o callback de auth não for disparado (ex.: fluxo web, timeout de
    // Firestore, cold start com usuário não autenticado).
    // Timeout de 8s: tempo suficiente para qualquer fluxo de auth resolver.
    Future<void>.delayed(const Duration(milliseconds: 8000), () {
      if (!mounted || _authResolved) return;
      debugPrint('[BUILD313] _authResolved watchdog: forçando auth resolved após 8s');
      setState(() => _authResolved = true);
    });
  }

  // ── GATE 1: remoção do splash nativo iOS ─────────────────────────────────
  // BUILD 330 — OTIMIZAÇÃO CRÍTICA iOS: desacopla FlutterNativeSplash.remove()
  // do semáforo _authResolved.
  //
  // PROBLEMA ANTERIOR: _ready = _minTimeDone && _bootDone && _authResolved
  // gateava a remoção do storyboard nativo AO MESMO TEMPO que a transição para
  // o conteúdo real. _authResolved só dispara após currentUserStream() resolver
  // (Firestore cold-start = 6–8s em 4G/LTE) → storyboard estático ficava 6–8s.
  //
  // SOLUÇÃO: dois gates separados com responsabilidades distintas:
  //   • _nativeSplashReady = boot concluído → remove storyboard (~1-2s)
  //     O Flutter engine já pintou o primeiro frame dinâmico (_SplashScreen),
  //     então o UIKit pode encerrar o storyboard sem flash intermediário.
  //   • _ready = boot + auth resolvido → transição para o conteúdo real
  //     (LoginScreen / HomeScreen). Auth pode demorar mais; durante esse
  //     intervalo o médico vê o splash dinâmico animado, não a tela estática.
  //
  // TIMING iOS (BUILD 330):
  //   [t=0ms]    runApp() → Dart engine ativo
  //   [t=~200ms] 1º frame Flutter pintado (_SplashScreen com logo respirando)
  //   [t=~800ms] Firebase + prefs inicializados (_bootDone = true)
  //   [t=1200ms] _minTimeDone = true → _nativeSplashReady = true
  //              → FlutterNativeSplash.remove() no próximo frame
  //              → STORYBOARD ENCERRADO: médico vê splash dinâmico em < 1.5s
  //   [t=var]    currentUserStream() resolve → _authResolved = true → _ready
  //              → AnimatedSwitcher transiciona para HomeScreen/LoginScreen
  bool get _nativeSplashReady => _minTimeDone && _bootDone;

  // ── GATE 2: transição para o conteúdo real ────────────────────────────────
  // Exige os 3 semáforos: boot + min + auth resolvido.
  // No web (kIsWeb), _authResolved não é relevante para remoção do splash nativo
  // (não existe FlutterNativeSplash no web), mas ainda controla o AnimatedSwitcher.
  bool get _ready => _minTimeDone && _bootDone && (kIsWeb || _authResolved);

  // Chamado pelo _AuthGateState via widget.onAuthResolved — sinaliza que
  // a árvore de auth já renderizou pelo menos um estado estável.
  void _signalAuthResolved() {
    if (!_authResolved && mounted) {
      setState(() => _authResolved = true);
    }
  }

  // BUILD 280 — CAMADA 3: flag de idempotência para FlutterNativeSplash.remove()
  // Garante que remove() seja chamado exatamente UMA VEZ, mesmo que build()
  // seja invocado múltiplas vezes quando _nativeSplashReady transiciona false→true.
  // Sem esta flag, múltiplos addPostFrameCallback seriam registrados em builds
  // consecutivos no mesmo frame, causando chamadas duplicadas ao plugin nativo.
  bool _splashRemoved = false;

  @override
  Widget build(BuildContext context) {
    // BUILD 330 — GATE 1: remoção do splash nativo iOS em < 1.5s
    // ───────────────────────────────────────────────────────────────────────
    // Dispara quando Firebase + prefs terminaram E o timer mínimo de 1.2s
    // expirou — independentemente de _authResolved.
    //
    // Nesse momento o Flutter JÁ pintou pelo menos um frame da _SplashScreen
    // dinâmica (logo respirando + "Carregando dados clínicos..."), portanto o
    // UIKit pode encerrar o LaunchScreen.storyboard sem nenhum flash intermediário.
    //
    // A guard !kIsWeb é mandatória: no Web não existe FlutterNativeSplash.
    // A flag _splashRemoved previne chamadas duplicadas entre builds.
    if (_nativeSplashReady && !_splashRemoved && !kIsWeb) {
      _splashRemoved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove();
        debugPrint('[BUILD330] FlutterNativeSplash.remove() — '
            'storyboard encerrado após boot (sem aguardar auth)');
      });
    }

    // GATE 2: AnimatedSwitcher — splash ↔ conteúdo real
    // Transição de 350ms com fade suave.
    // _ready exige boot + auth → garante que a transição só ocorre quando
    // o _AuthGate já sabe se o usuário está autenticado ou não.
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
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('E-mail cadastrado:', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), fontWeight: FontWeight.w600)),
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
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Text(
                    _checkMsg!,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8), height: 1.5),
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
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
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
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.25)),
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
                    style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7), height: 1.6),
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
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
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

  // BUILD 241: timestamp de início para watchdog baseado em tempo real
  late final DateTime _initStart;

  @override
  void initState() {
    super.initState();
    _initStart = DateTime.now();
    // BUILD 241: registra no coordinator — se o app voltar do background
    // após 20s ainda carregando, força _ready=true para liberar a UI.
    AppResumeCoordinator.instance.registerLoading(
      '_webgate_${widget.user.uid}',
      onTimeout: () {
        final ms = DateTime.now().difference(_initStart).inMilliseconds;
        debugPrint('[BOOTSTRAP_WATCHDOG] webGate elapsedMs=$ms '
            'action=force_ready (resume timeout)');
        if (mounted && !_ready) setState(() => _ready = true);
      },
    );
    // Timer local de backup — garante liberação mesmo sem resume event
    Future<void>.delayed(const Duration(seconds: 20), () {
      if (!mounted || _ready) return;
      final ms = DateTime.now().difference(_initStart).inMilliseconds;
      debugPrint('[BOOTSTRAP_WATCHDOG] webGate elapsedMs=$ms action=force_ready (timer)');
      setState(() => _ready = true);
      AppResumeCoordinator.instance.completeLoading('_webgate_${widget.user.uid}');
    });
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
    AppResumeCoordinator.instance.completeLoading('_webgate_${widget.user.uid}'); // BUILD 241

    // BUILD 334 / BUILD 334-FORENSE — TAB_RESTORE pós-auth:
    // Quando _ready flipa de false → true, o MainShell é criado NESTE frame.
    // O _MainShellState field-initializer lê postOAuthTabNotifier.value para
    // definir _tab inicial. Se o OAuth redirect já consumiu o notifier (value=-1)
    // mas o provider tem IA conectada (Gemini, BYOK ou OpenAI), o MainShell
    // iniciaria com _tab=0 (Home) em vez de permanecer na aba de IA.
    //
    // COBERTURA EXPANDIDA (FORENSE):
    //   • BUILD 334 original: cobria apenas geminiConnected.
    //   • BUILD 334-FORENSE: cobre hasAnyAi (Gemini OAuth + BYOK + OpenAI key)
    //     para que qualquer usuário com IA ativa abra diretamente na aba IA.
    //   • Também cobre o caso onde checkGeminiSession() ainda não completou —
    //     mas setUser() já carregou a chave local (hasApiKey=true).
    //
    // Fix: se nenhum OAuth redirect está pendente E usuário tem IA disponível,
    // sinalizar tab=2 antes de criar o MainShell para que o field-initializer
    // capture o valor correto. O notifier é consumido pelo initState fast-path.
    if (mounted && AppProvider.postOAuthTabNotifier.value < 0 && p.hasAnyAi) {
      AppProvider.postOAuthTabNotifier.value = 2; // IA tab — consumido pelo _MainShellState
      debugPrint('[BUILD334-FORENSE][TAB_RESTORE] hasAnyAi=true → pre-sinaliza tab=2 antes de criar MainShell (gemini=${p.geminiConnected} key=${p.hasAiKey})');
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

  /// BUILD 329 — Notifier global de scroll para todas as abas.
  /// true  → usuário está scrollando para baixo → nav bar encolhe
  /// false → usuário está scrollando para cima / parado → nav bar expande
  static final navScrollingDown = ValueNotifier<bool>(false);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  // tabs: 0=Home 1=Rx/Proto 2=IA(FAB) 3=H.Clínica 4=Calculadoras
  // (Adulto/Cockpit é acessado via card na HomeScreen)
  //
  // BUILD 292: inicializa _tab diretamente do postOAuthTabNotifier.value.
  // Se o notifier já foi setado ANTES da criação deste State (race condition
  // onde _MainShellState é recriado após redirect OAuth), o valor correto (2)
  // é usado desde o primeiro frame — sem flash na Home.
  // Se não há OAuth pendente, o valor é -1 → fallback para 0 (Home).
  int _tab = AppProvider.postOAuthTabNotifier.value >= 0
      ? AppProvider.postOAuthTabNotifier.value.clamp(0, 5)
      : 0;
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
    //
    // BUILD 292: se um OAuth tab restore está pendente (notifier >= 0) e a
    // mudança é para Home (t == 0), registrar log diagnóstico. A mudança ainda
    // ocorre — é iniciada pelo usuário, não por código de boot.
    if (t == 0 && AppProvider.postOAuthTabNotifier.value >= 0) {
      debugPrint('[BUILD292][TAB_RESTORE] ignored_reset_to_home reason=user_tap_home_while_pending_oauth_tab');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = t);
    // BUILD 445: notifica ToolsScreen sobre visibilidade (tab 4 = Ferramentas)
    toolsScreenVisibleNotifier.value = (t == 4);
  }
  void _onSubTabChange(int i) => setState(() => _rxProtoSub = i);
  void _onOpenNotes()         => showNotesSheet(context);

  void _onScrollNotification(ScrollNotification n) {
    // BUILD 329 — Motor de scroll dinâmico para a bottom nav (todas as abas).
    // Threshold de 4px para ignorar micro-vibrações do overscroll iOS.
    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      if (delta > 4 && !MainShell.navScrollingDown.value) {
        MainShell.navScrollingDown.value = true;   // scrolling down → encolhe nav
      } else if (delta < -4 && MainShell.navScrollingDown.value) {
        MainShell.navScrollingDown.value = false;  // scrolling up  → expande nav
      }
    } else if (n is ScrollEndNotification) {
      // Ao parar o scroll, sempre expande a nav para garantir acessibilidade.
      MainShell.navScrollingDown.value = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Ouve pendingTab para navegação iniciada pelo Drawer (sem onTabChange no _AppDrawer)
    MainShell.pendingTab.addListener(_onPendingTab);

    // SUPER ORDEM MASTER 315: ouve postOAuthTabNotifier para restaurar aba pós-OAuth.
    // Substitui o mecanismo postOAuthAiTab (static bool) que sofria de race condition:
    // o bool era lido em initState ANTES de checkGeminiSession() setar true.
    // O ValueNotifier dispara em runtime → _onPostOAuthTab() responde imediatamente.
    AppProvider.postOAuthTabNotifier.addListener(_onPostOAuthTab);
    // BUILD 291/292 / BUILD 334-FORENSE: race-condition fix multicamada.
    //
    // CAMADA 1 (field-initializer): _tab = postOAuthTabNotifier.value >= 0
    //   ? value.clamp(0,5) : 0  — já executado antes de initState().
    //
    // CAMADA 2 (initState fast-path): se o notifier ainda tem valor >= 0
    //   (pre-sinalizado por _WebMainShellGate._initUser()), confirmar _tab
    //   via setState e consumir o notifier (reset para -1).
    //   Uso de addPostFrameCallback garante que o frame inicial já foi
    //   renderizado antes do setState — evita rebuild durante build.
    //
    // CAMADA 3 (NOVA — BUILD 334-FORENSE): listener em runtime via
    //   _onPostOAuthTab() captura sinalizações tardias de checkGeminiSession()
    //   que podem completar em background DEPOIS do MainShell ser criado.
    final pendingOAuthTab = AppProvider.postOAuthTabNotifier.value;
    if (pendingOAuthTab >= 0) {
      debugPrint('[BUILD334-FORENSE][TAB_RESTORE] pending=$pendingOAuthTab (fast-path initState) _tab=$_tab');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // _tab já foi inicializado pelo field initializer — forçar setState
          // para garantir que o IndexedStack reaja ao valor correto.
          final correctTab = pendingOAuthTab.clamp(0, 5);
          if (_tab != correctTab) {
            setState(() => _tab = correctTab);
            debugPrint('[BUILD334-FORENSE][TAB_RESTORE] setState tab=$correctTab (field-init divergiu)');
          } else {
            debugPrint('[BUILD334-FORENSE][TAB_RESTORE] tab=$_tab já correto (field-init OK)');
          }
          if (AppProvider.postOAuthTabNotifier.value >= 0) {
            AppProvider.postOAuthTabNotifier.value = -1; // consome notifier
          }
        }
      });
    }

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

    // BUILD 241: visibilitychange handler (Web only).
    // Flutter Web não envia AppLifecycleState.paused ao trocar de aba na maioria
    // dos browsers — apenas quando a janela TODA perde o foco em alguns casos.
    // Este handler garante que o AppResumeCoordinator seja notificado quando o
    // usuário troca de aba, garantindo verificação de AI requests e bootstrap.
    if (kIsWeb) {
      webPlatform.setupVisibilityHandler(
        onHidden:  () {
          debugPrint('[VISIBILITY] hidden=true → coordinator.onBackground()');
          AppResumeCoordinator.instance.onBackground();
          // Also pause usage timer (fromVisibility=true skips duplicate
          // coordinator.onBackground() call)
          if (mounted) {
            try {
              context.read<AppProvider>().pauseUsageTimer(fromVisibility: true);
            } catch (_) {}
          }
        },
        onVisible: () {
          debugPrint('[VISIBILITY] hidden=false → coordinator.onForeground()');
          AppResumeCoordinator.instance.onForeground();
          // Also resume usage timer if paused (fromVisibility=true skips
          // duplicate coordinator.onForeground() call)
          if (mounted) {
            try {
              context.read<AppProvider>().resumeUsageTimer(fromVisibility: true);
            } catch (_) {}
          }
        },
      );
    }

    // Verifica novidades ao abrir o app (delay para não competir com splash)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _checkAppUpdate();
      });
    });

    // BUILD 240: inicia download em background da calculadora offline.
    // Não bloqueia a Home — roda após primeiro frame, nunca lança erro visível.
    // Apenas mobile (kIsWeb=false): path_provider não suporta Web.
    // BUILD 242: injeta callback de AI-busy antes de iniciar o sync, para que
    // o downloader throttle automaticamente quando a IA estiver em uso.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<AppProvider>();
        OfflineCalculatorCacheService.instance.setAiBusyCheck(
          () => provider.aiStreaming || provider.offlineCaching,
        );
        OfflineCalculatorCacheService.instance.startBackgroundSync();
      });
    }
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

  // SUPER ORDEM MASTER 315: callback do ValueNotifier postOAuthTabNotifier.
  // Disparado por AppProvider.checkGeminiSession() após auth OAuth bem-sucedido.
  // Restaura o índice da aba de origem (salvo antes do redirect) sem race condition.
  //
  // BUILD 292: _tab pode já ter sido inicializado com o valor correto via campo
  // (field initializer lê postOAuthTabNotifier.value na construção do State).
  // Neste caso, o callback apenas confirma e reseta o notifier para -1.
  void _onPostOAuthTab() {
    final tabIdx = AppProvider.postOAuthTabNotifier.value;
    if (tabIdx < 0 || !mounted) return;

    debugPrint('[BUILD292][TAB_RESTORE] pending=$tabIdx applying=true');
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = tabIdx.clamp(0, 5));
    AppProvider.postOAuthTabNotifier.value = -1; // consome e reseta
    debugPrint('[BUILD292][TAB_RESTORE] applied tab=${tabIdx.clamp(0, 5)}');
    debugPrint('[MASTER315] postOAuthTabNotifier → aba $tabIdx restaurada');
  }

  void _onPendingTab() {
    final t = MainShell.pendingTab.value;
    if (t >= 0 && mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _tab = t.clamp(0, 5));
      MainShell.pendingTab.value = -1; // reset imediato após consumir
      // BUILD 445: notifica ToolsScreen sobre visibilidade via pendingTab
      toolsScreenVisibleNotifier.value = (t == 4);
    }
  }

  @override
  void dispose() {
    MainShell.pendingTab.removeListener(_onPendingTab);
    AppProvider.postOAuthTabNotifier.removeListener(_onPostOAuthTab); // BUILD 315
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
    // 🛡️ BUILD 251: No ambiente Web, ignore completamente mudanças de ciclo de vida.
    // Cliques no DevTools/Console causam window blur → Flutter dispara inactive/hidden
    // erroneamente → coordinator.onBackground() decepava o stream SSE da IA no meio.
    // O Web já usa o listener de visibilitychange (initState acima) como fonte de
    // verdade para background/foreground — este handler é redundante e prejudicial.
    if (kIsWeb) return;

    if (!mounted) return;
    final provider = context.read<AppProvider>();
    debugPrint('[LIFECYCLE] state=${state.name}');

    switch (state) {
      case AppLifecycleState.resumed:
        // App voltou ao foreground — retoma contagem de tempo de tela
        // BUILD 241: resumeUsageTimer() agora também chama
        // AppResumeCoordinator.instance.onForeground() para verificar
        // operações pendentes com base em tempo real.
        provider.resumeUsageTimer();
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // App foi para background ou ficou inativo — pausa o timer
        // (não cancela — mantém estado para retomar ao voltar)
        // BUILD 241: pauseUsageTimer() agora também chama
        // AppResumeCoordinator.instance.onBackground() para registrar timestamp.
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
      drawerScrimColor: Colors.black.withOpacity(0.52),
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

  /// Layout mobile/tablet: Scaffold com AppBar no topo + floating bottom nav (Build 158)
  Widget _buildMobileShell(BuildContext context, bool dark, AppProvider p) {
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF);
    final stackIdx = _tab.clamp(0, _staticScreens.length - 1);
    final isHome   = _tab == 0;
    final isAiTab  = _tab == 2;

    return Scaffold(
      backgroundColor: bg,
      endDrawer: _AppDrawer(p: p),
      drawerScrimColor: Colors.black.withOpacity(0.52),
      // ── AppBar HOME: sempre visível ───────────────────────────────────────
      appBar: isHome
          ? PreferredSize(
              // BUILD 316 M1: 36px base — SafeArea.top expande para notch/Dynamic Island.
              // Web/sem-notch → 36px útil. iPhone com ilha/entalhada → 36+padding.top.
              // BUILD 329 M3: preferredSize 36→48px (sincronizado com height: 48 interno)
              preferredSize: const Size.fromHeight(48),
              child: Builder(
                // BUILD 329: onMenuTap removido — menu migrou para bottom nav (M+ circular)
                builder: (_) => _MobileAppBar(
                  dark: dark,
                  currentTab: _tab,
                  lang: p.lang,
                  isHome: true,
                  onLogoTap: () { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _tab = 0); },
                ),
              ),
            )
          : null,

      // ── Body: IndexedStack + floating bottom nav overlay (Build 158) ──────
      // A bottom nav é agora um overlay flutuante posicionado com Positioned,
      // em vez de bottomNavigationBar nativo. Isso permite:
      //   1. Animação de slide-down quando usuário lê histórico (hide-on-scroll)
      //   2. Fundo blur glassmorphism com cantos arredondados
      //   3. Controle total sobre o posicionamento e animação
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) { _onScrollNotification(n); return false; },
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Builder(
            builder: (scaffoldBodyCtx) => SizedBox.expand(
            child: Stack(
              children: [
                // ── Conteúdo principal ─────────────────────────────────────
                // isHome (tab 0) e IA (tab 2) partem do y=0 — cada tela cuida
                // do seu próprio SafeArea interno (_MobileAiActionBar SafeArea).
                // BUILD 281: _UpdateBanner REMOVIDO do mobile shell Stack.
                // No mobile web, o toast HTML nativo (#pwa-update-toast) já
                // cobre a notificação de SW — o banner Flutter gerava o DUPLO
                // botão "ATUALIZAR" visível nas screenshots do bug.
                // Demais abas (sem topbar própria) recebem padding.top manual.
                Padding(
                  padding: EdgeInsets.only(
                    top: (isHome || _tab == 2) ? 0 : MediaQuery.of(context).padding.top,
                  ),
                  child: IndexedStack(index: stackIdx, children: _staticScreens),
                ),

                // ── Build 158.3 / BUILD 329: Floating footer unificado ───────
                // FloatingBottomNav + LegalBar formam um ÚNICO bloco animado.
                // BUILD 329: hidden agora depende de editorOpen | kbOpen apenas.
                // O scroll-shrink dinâmico é gerido internamente por _FloatingFooter
                // via MainShell.navScrollingDown — suporte a TODAS as abas.
                ValueListenableBuilder<bool>(
                  valueListenable: HistoryScreen.editorActive,
                  builder: (_, editorOpen, __) =>
                  ValueListenableBuilder<bool>(
                    valueListenable: AiScreen.chatKeyboardOpen,
                    builder: (_, kbOpen, __) {
                      final hidden = editorOpen || kbOpen;
                      return _FloatingFooter(
                        hidden: hidden,
                        dark: dark,
                        currentTab: _tab,
                        lang: p.lang,
                        onTabChange: (t) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => _tab = t);
                        },
                        onFabTap: () {
                          AppHaptics.light(context);
                          FocusManager.instance.primaryFocus?.unfocus();
                          setState(() => _tab = 2);
                        },
                        onFabDoubleTap: () => _resetAndStartNewChat(),
                        isAiActive: isAiTab,
                        // BUILD 329: abre o endDrawer via Builder dentro do Scaffold
                        onMenuTap: () => Scaffold.of(scaffoldBodyCtx).openEndDrawer(),
                      );
                    },
                  ),
                ),
              ],
            ),   // end Stack
          ),     // end SizedBox.expand
        ),       // end Builder
      ),         // end MediaQuery.removePadding
    ),           // end NotificationListener
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

}

// ─────────────────────────────────────────────────────────────────────────────
// Build 158 — FLOATING BOTTOM NAVIGATION BAR com Hide-on-Scroll
//
// Design baseado no mockup premium (IMG_3206 + Captura de Tela):
//   • Fundo dark semitransparente com blur glassmorphism
//   • 3 itens: Inicio (esquerda) | FAB IA central com glow neon | Herramientas (direita)
//   • FAB central: círculo proeminente, gradiente teal, glow ciano pulsante
//   • Disclaimer legal abaixo da barra (sempre visível)
//
// Comportamento Hide-on-Scroll:
//   • Scroll para baixo na aba IA → barra desliza para fora da tela (slide-down)
//   • Scroll para cima / não está na aba IA → barra reaparece (slide-up suave)
//   • Teclado aberto → barra desaparece (comportamento existente)
//
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// BUILD 329 — _FloatingFooter (StatefulWidget)
//
// Bloco unificado: FloatingBottomNav + LegalBar, posicionado com safeBottom dinâmico.
// BUILD 316: bottom = MediaQuery.padding.bottom > 0 ? padding.bottom : 16.0
//            garante que em Android com botões virtuais (padding.bottom == 0)
//            o dock flutua 16px acima da barra do sistema (ergonomia Realme/AOSP).
// NOVIDADES BUILD 329:
//   • 4 botões: [Início | IA (FAB) | Ferramentas | Menu M+]
//   • Scroll-shrink dinâmico via MainShell.navScrollingDown:
//       scroll down → barHeight 50→38px (AnimatedContainer suave)
//       scroll up   → barHeight 38→50px
//   • Botão Menu M+: avatar circular estilo Instagram com fundo verde esmeralda
//     e logotipo "M+" em ouro metálico, abre o endDrawer lateral
// ─────────────────────────────────────────────────────────────────────────────
class _FloatingFooter extends StatefulWidget {
  final bool hidden;
  final bool dark;
  final int  currentTab;
  final String lang;
  final ValueChanged<int> onTabChange;
  final VoidCallback onFabTap;
  final VoidCallback onFabDoubleTap;
  final VoidCallback onMenuTap;
  final bool isAiActive;

  const _FloatingFooter({
    required this.hidden,
    required this.dark,
    required this.currentTab,
    required this.lang,
    required this.onTabChange,
    required this.onFabTap,
    required this.onFabDoubleTap,
    required this.onMenuTap,
    required this.isAiActive,
  });

  @override
  State<_FloatingFooter> createState() => _FloatingFooterState();
}

class _FloatingFooterState extends State<_FloatingFooter> {
  static const _neonCyan   = Color(0xFF00E5FF);
  // Paleta do avatar M+ — verde esmeralda médico + ouro metálico
  static const _avatarGreen      = Color(0xFF0D7A5F); // verde petróleo esmeralda
  static const _avatarGreenLight = Color(0xFF34D399); // borda luminosa
  static const _avatarGold       = Color(0xFFD4AF37); // ouro fosco canônico

  // Alturas da barra: normal e encolhida
  static const _barHeightFull    = 50.0;
  static const _barHeightShrunk  = 38.0;

  bool _shrunk = false; // reflexo local do navScrollingDown

  @override
  void initState() {
    super.initState();
    MainShell.navScrollingDown.addListener(_onScrollChange);
  }

  @override
  void dispose() {
    MainShell.navScrollingDown.removeListener(_onScrollChange);
    super.dispose();
  }

  void _onScrollChange() {
    final s = MainShell.navScrollingDown.value;
    if (s != _shrunk) setState(() => _shrunk = s);
  }

  @override
  Widget build(BuildContext context) {
    final navBg = widget.dark
        ? const Color(0xFF0F1116).withOpacity(0.68)
        : Colors.white.withOpacity(0.65);

    // BUILD 329: altura dinâmica — encolhe suavemente durante scroll down
    final barHeight = _shrunk ? _barHeightShrunk : _barHeightFull;

    // BUILD 315 → BUILD 316 — Safe-area bottom padding para o dock flutuante.
    //
    // Contexto:
    //   • Aparelhos Android com botões virtuais (Voltar/Home/Recentes) — ex: Realme
    //     ColorOS, AOSP — têm MediaQuery.padding.bottom == 0: os botões do sistema
    //     ficam sobrepostos à UI sem gerar safe-area padding, esmagando o dock
    //     contra a barra e tornando os ícones (Inicio/IA/Ferramentas/Menu) instáveis.
    //   • Aparelhos com gesture navigation (iOS home indicator, Android gesture bar)
    //     têm padding.bottom > 0 refletindo a zona de gesto — usar esse valor
    //     garante que o dock flutua naturalmente acima da área protegida.
    //
    // Solução ergonômica definitiva:
    //   padding.bottom > 0  → usa o valor de safe-area real do SO
    //   padding.bottom == 0 → força 16px de respiro anatômico mínimo para
    //                         desgrudar o dock dos botões virtuais do Android
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final safeBottom = bottomInset > 0 ? bottomInset : 16.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: safeBottom,
      child: AnimatedSlide(
        // Slide total quando hidden (teclado aberto / editor de história)
        offset: Offset(0, widget.hidden ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 300),
        curve: widget.hidden ? Curves.easeInCubic : Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: widget.hidden ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 250),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Floating Dock glassmorphism ────────────────────────────────
              // PERF-FIX: RepaintBoundary isola o dock do resto do frame —
              // o Impeller só redesenha esta camada quando barHeight muda,
              // não quando o conteúdo da tela principal atualiza.
              RepaintBoundary(
                child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: ClipRRect(
                  // PERF-FIX: borderRadius const → o Impeller não recalcula o
                  // clipper a cada frame; cache de layer garantido.
                  borderRadius: const BorderRadius.all(Radius.circular(32)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: AnimatedContainer(
                      // BUILD 329: animação suave de encolhimento via scroll
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: navBg,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: widget.dark
                              ? _neonCyan.withOpacity(0.18)
                              // Modo claro: borda teal petróleo slim — identifica o dock
                              // sobre fundos brancos sem pesar no glassmorphism
                              : const Color(0xFF0F766E).withOpacity(0.18),
                          width: 0.9,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.dark
                                ? Colors.black.withOpacity(0.45)
                                : Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                          if (widget.dark)
                            BoxShadow(
                              color: _neonCyan.withOpacity(0.05),
                              blurRadius: 24,
                              offset: const Offset(0, -4),
                            ),
                        ],
                      ),
                      // BUILD 331: Row contextual — muda conforme a aba ativa.
                      // Aba IA (isAiActive) → [Início|Histórico|Novo Chat|Menu]
                      // Demais abas              → [Início|IA|Ferramentas|Menu]
                      child: widget.isAiActive
                          ? _buildAiRow()
                          : _buildNavRow(),
                    ),
                  ),
                ),
              ),
              ), // RepaintBoundary

              // ── LegalBar — faz parte do bloco animado ─────────────────────
              _LegalBar(dark: widget.dark, insideSafeArea: true),
            ],
          ),
        ),
      ),
    );
  }

  // ── Row padrão (abas Home / Ferramentas / etc) ─────────────────────────────
  // [Início | IA | Ferramentas | Menu] — 4×Expanded 25%
  Widget _buildNavRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [

      // 1. INÍCIO — home_outlined inativo / home_rounded (filled) ativo
      Expanded(child: _NavItem(
        icon: Icons.home_outlined,
        iconActive: Icons.home_rounded,
        label: widget.lang == 'es' ? 'Inicio' : 'Início',
        isActive: widget.currentTab == 0,
        dark: widget.dark, shrunk: _shrunk,
        onTap: () => widget.onTabChange(0),
      )),

      // 2. IA — círculo gradiente + label "IA"
      Expanded(child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onFabTap,
        onDoubleTap: widget.onFabDoubleTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 26, height: 26,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: widget.isAiActive
                        ? [const Color(0xFF008CA4), const Color(0xFF005566)]
                        : [const Color(0xFF374151), const Color(0xFF1E2330)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isAiActive
                        ? _neonCyan.withOpacity(0.80) : const Color(0xFF4B5563),
                    width: 1.5,
                  ),
                  boxShadow: widget.isAiActive
                      ? [BoxShadow(color: _neonCyan.withOpacity(0.50), blurRadius: 12)]
                      : [BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Icon(Icons.psychology_rounded, size: 16,
                    color: widget.isAiActive ? _neonCyan : Colors.white70),
              ),
            ),
            AnimatedOpacity(
              opacity: _shrunk ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Text('IA', maxLines: 1,
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: widget.isAiActive ? FontWeight.w700 : FontWeight.w400,
                  color: widget.isAiActive
                      // Ativo: neon (dark) / preto sólido estilo Instagram (light)
                      ? (widget.dark ? _neonCyan : Colors.black87)
                      // Inativo: cinza médio (dark) / cinza escuro sólido (light)
                      : (widget.dark ? const Color(0xFF6B7280) : const Color(0xFF4B5563)),
                  height: 1.0,
                )),
            ),
          ],
        ),
      )),

      // 3. FERRAMENTAS — calculate_outlined inativo / calculate_rounded (filled) ativo
      Expanded(child: _NavItem(
        icon: Icons.calculate_outlined,
        iconActive: Icons.calculate_rounded,
        label: widget.lang == 'es' ? 'Herramientas' : 'Ferramentas',
        isActive: widget.currentTab == 4,
        dark: widget.dark, shrunk: _shrunk,
        onTap: () => widget.onTabChange(4),
      )),

      // 4. MENU M+
      Expanded(child: _buildMenuButton()),
    ],
  );

  // ── Row contextual IA — substitui toda a barra quando a aba IA está ativa ──
  // [Início | Histórico | Novo Chat | Menu] — 4×Expanded 25%
  Widget _buildAiRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [

      // 1. INÍCIO — volta para Home (sempre inativo no contexto IA)
      Expanded(child: _NavItem(
        icon: Icons.home_outlined,
        iconActive: Icons.home_rounded,
        label: widget.lang == 'es' ? 'Inicio' : 'Início',
        isActive: false, // nunca ativo quando estamos na aba IA
        dark: widget.dark, shrunk: _shrunk,
        onTap: () => widget.onTabChange(0),
      )),

      // 2. HISTÓRICO — abre histórico de sessões do chat
      Expanded(child: ValueListenableBuilder<VoidCallback?>(
        valueListenable: AiScreen.openHistoryCallback,
        builder: (_, callback, __) => ValueListenableBuilder<int>(
          valueListenable: AiScreen.historyCountNotifier,
          builder: (_, count, __) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: callback,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  // Badge de contagem sobre o ícone
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.history_rounded, size: 22,
                          // Cinza escuro sólido no light — contraste premium
                          color: widget.dark
                              ? const Color(0xFF6B7280) : const Color(0xFF4B5563)),
                      if (count > 0)
                        Positioned(
                          top: -4, right: -6,
                          child: Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFC5A365),
                            ),
                            child: Center(
                              child: Text('$count',
                                style: const TextStyle(
                                  fontSize: 7, fontWeight: FontWeight.w900,
                                  color: Color(0xFF1A1100),
                                )),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: _shrunk ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    widget.lang == 'es' ? 'Historial' : 'Histórico',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.0, fontWeight: FontWeight.w400,
                      // Cinza escuro sólido no light — contraste premium estilo Instagram
                      color: widget.dark
                          ? const Color(0xFF6B7280) : const Color(0xFF4B5563),
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )),

      // 3. NOVO CHAT — círculo com gradiente neonCyan, ícone add_rounded
      Expanded(child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onFabDoubleTap, // mesma ação do double-tap do FAB
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [const Color(0xFF008CA4), const Color(0xFF005566)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _neonCyan.withOpacity(0.75), width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _neonCyan.withOpacity(0.35),
                      blurRadius: 10, spreadRadius: 0,
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
              ),
            ),
            AnimatedOpacity(
              opacity: _shrunk ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Text(
                widget.lang == 'es' ? 'Nuevo' : 'Novo',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.0, fontWeight: FontWeight.w500,
                  color: widget.dark ? _neonCyan : const Color(0xFF008CA4),
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      )),

      // 4. MENU M+
      Expanded(child: _buildMenuButton()),
    ],
  );

  // ── Avatar M+ circular — compartilhado entre as duas Rows ──────────────────
  Widget _buildMenuButton() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: widget.onMenuTap,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF16A87C), Color(0xFF0A5C45)],
              ),
              border: Border.all(
                color: _avatarGreenLight.withOpacity(0.70), width: 1.8,
              ),
              boxShadow: [
                BoxShadow(color: _avatarGreen.withOpacity(0.45), blurRadius: 8),
              ],
            ),
            child: Center(
              child: Text('M+',
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w900,
                  color: _avatarGold, letterSpacing: 0.3, height: 1.0,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.40), blurRadius: 3)],
                )),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _shrunk ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.lang == 'es' ? 'Menú' : 'Menu',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.0, fontWeight: FontWeight.w500,
              // Cinza escuro sólido (light) — consistente com padrão Instagram
              color: widget.dark
                  ? const Color(0xFF6B7280) : const Color(0xFF4B5563),
              height: 1.0,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Item individual da bottom nav ─────────────────────────────────────────────
// BUILD 331 LIGHT PREMIUM: paleta estilo Instagram no modo claro.
//   • Inativo light: cinza escuro sólido #4B5563 (legível, sem apagado)
//   • Ativo   light: Colors.black87 — preto absoluto (ênfase premium)
//   • Ativo   dark : Colors(0xFF00E5FF) — neon cyan (contraste no escuro)
// iconActive: versão filled/bold do ícone para estado ativo — alternância
// visual sofisticada sem precisar de underline ou círculo.
class _NavItem extends StatelessWidget {
  final IconData  icon;
  final IconData? iconActive; // filled/bold variant for active state
  final String    label;
  final bool      isActive;
  final bool      dark;
  final bool      shrunk;     // true → barra encolhida → label some
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.dark,
    required this.onTap,
    this.iconActive,
    this.shrunk = false,
  });

  @override
  Widget build(BuildContext context) {
    // Dark mode: neon cyan ativo / cinza médio inativo (contraste sobre escuro)
    // Light mode: preto absoluto ativo / cinza escuro sólido inativo (Instagram-style)
    final activeColor   = dark ? const Color(0xFF00E5FF) : Colors.black87;
    final inactiveColor = dark ? const Color(0xFF6B7280) : const Color(0xFF4B5563);
    final color = isActive ? activeColor : inactiveColor;

    // Alterna ícone filled↔outline conforme estado (quando iconActive fornecido)
    final resolvedIcon = (isActive && iconActive != null) ? iconActive! : icon;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícone — 22px; filled quando ativo + iconActive definido
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Icon(resolvedIcon, size: 22, color: color),
          ),
          // Label — some suavemente quando a barra encolhe (scroll down)
          AnimatedOpacity(
            opacity: shrunk ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: color,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE APP BAR — topo do Scaffold mobile com logo centralizada + botões contextuais
// BUILD 329: hambúrguer REMOVIDO — menu migrou para o 4º botão (M+ circular) da bottom nav.
// Quando currentTab == 2 (IA MedCases), injeta botões "Histórico" e "Novo Chat"
// à direita, usando os ValueNotifiers estáticos do AiScreen.
// ─────────────────────────────────────────────────────────────────────────────
class _MobileAppBar extends StatelessWidget {
  final bool dark;
  final int  currentTab;
  final String lang;
  final bool isHome;
  final VoidCallback onLogoTap;

  const _MobileAppBar({
    required this.dark,
    required this.currentTab,
    required this.lang,
    required this.isHome,
    required this.onLogoTap,
  });

  // Tab index da tela de IA (deve corresponder a _staticScreens[2])
  static const _kAiTab = 2;

  @override
  Widget build(BuildContext context) {
    // BUILD 331 HOME: topbar SEMPRE Black Piano (#000000) — identidade premium.
    // Nunca branco, nunca transparente — fundo sólido absoluto.
    // MEDCASES (branco w900) + PRO (dourado #FFD700 w900) — RichText bicolor.
    const barDecoration = BoxDecoration(
      color: Color(0xFF000000),                         // Black Piano absoluto
      border: Border(
        bottom: BorderSide(color: Color(0xFF2D3340), width: 0.5),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x59000000),                     // black 35% opacity
          blurRadius: 6.0,
          offset: Offset(0, 2),
        ),
      ],
    );

    return Container(
      decoration: barDecoration,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          // BUILD 316 M1: altura útil 36px — SafeArea acima já absorve o
          // padding do sistema (notch / Dynamic Island / status bar).
          // BUILD 328 M2: altura 36→46px — AppBar mais robusta e imponente
          // BUILD 329 M3: +2px → 48px — respiro perfeito ao cabeçalho
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Título centralizado (HOME e IA tab) ───────────────────
                // BUILD 278: "MEDCASES IA" com "IA" em ouro fosco na aba AI
                // BUILD 331 HOME: Black Piano → título sempre branco + dourado
                // "MEDCASES " branco w900 | "PRO"/"IA" dourado #FFD700 w900
                if (isHome || currentTab == _kAiTab)
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'MEDCASES ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Colors.white,             // SEMPRE branco
                          ),
                        ),
                        TextSpan(
                          text: currentTab == _kAiTab ? 'IA' : 'PRO',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: Color(0xFFFFD700),        // SEMPRE dourado
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Row com botões contextuais (direita) ──────────────────
                // BUILD 329: hambúrguer removido — apenas botões IA contextuais
                // à direita. Título centralizado pelo Stack acima sem placeholder.
                // BUILD 331: Topbar IA limpa — botões Histórico/Novo Chat migrados
                // para a bottom nav contextual (isAiActive). Apenas título centralizado.
                Row(
              children: [
                const Spacer(),
                // (sem botões — topbar só título)
              ],
            ), // end inner Row
              ], // end Stack children
            ), // end Stack
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
        ? const Color(0xFF10B981).withOpacity(0.12)
        : const Color(0xFF0A7C4E).withOpacity(0.08);
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
                          color: const Color(0xFF0E7C52).withOpacity(0.35),
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
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.05),
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
              activeBg: const Color(0xFF00E5FF).withOpacity(0.10),
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
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.05),
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
                color: Colors.black.withOpacity(dark ? 0.18 : 0.04),
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
        ? Colors.white.withOpacity(0.30)
        : const Color(0xFFB8BEC4);
    final activeBg = dark
        ? const Color(0xFF2D3340)   // kBorderSoft — active highlight
        : const Color(0xFF0F1116).withOpacity(0.09);

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
                          .withOpacity(0.08),
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
            color: Colors.black.withOpacity(0.30),
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
                  color: Colors.white.withOpacity(0.35),
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
                  color: Colors.white.withOpacity(0.07),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.13),
                    width: 0.8,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    Icons.home_rounded,
                    size: 13,
                    color: const Color(0xFFFFE8A6).withOpacity(0.85),
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
                  color: Colors.white.withOpacity(0.07),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.13),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  Icons.menu_rounded,
                  size: 16,
                  color: const Color(0xFFFFE8A6).withOpacity(0.85),
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
              top: BorderSide(color: border.withOpacity(0.45), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
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
        ? Colors.white.withOpacity(0.85)
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
      // BUILD 328 M4: padding v:1→5 — disclaimer totalmente visível acima da nav
      // fontSize 9→10, maxLines 1→2, icon 8→10 — legibilidade Apple 1.4.1
      // BUILD 329 M3: fontSize 10→11 — legibilidade definitiva e sólida
      // BUILD 331 LB: −2px everywhere — vertical 5→3, icon 11→9, fontSize 11→9 (minimalista)
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 9, color: textColor.withOpacity(0.55)),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            disclaimer,
            style: TextStyle(
              fontSize: 9, color: textColor,
              height: 1.3, letterSpacing: 0.0,
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
                  color: const Color(0xFFCC3333).withOpacity(0.12),
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
                        color: const Color(0xFFCC3333).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFCC3333).withOpacity(0.25)),
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
    final subCol  = dark ? Colors.white.withOpacity(0.36) : const Color(0xFF9AA0A8);

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
                // BUILD 327: _OfflineDrawerCard unificado — inclui controles da
                // calculadora offline (Versão, Actualizar, Limpiar) dentro do
                // mesmo bloco, sem rótulos separados que exponham "Calculadora".
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
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [

              // ── Linha 1: badge (opcional) | Spacer | botão ✕ ─────────────────
              // BUILD 326 — M1: BrandMark removido; X e badge mantidos no topo
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Badge Admin/Master — inline na linha do topo
                  if (hasBadge) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _kGold.withOpacity(0.14),
                        border: Border.all(color: _kGold.withOpacity(0.40)),
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
                        color: Colors.white.withOpacity(0.07),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10), width: 0.8),
                      ),
                      child: Icon(
                        Icons.close_rounded, size: 14,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── BUILD 326 — M1: Selo centralizado  ——  [M+]  —— ──────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Divider(
                      color: const Color(0xFF334155).withOpacity(0.45),
                      endIndent: 10,
                      thickness: 0.8,
                    ),
                  ),
                  const Text(
                    'M+',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 2.0,
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: const Color(0xFF334155).withOpacity(0.45),
                      indent: 10,
                      thickness: 0.8,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ── BUILD 326 — M2/M3: Avatar 58px + Stack lápis + coluna de texto ─
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // BUILD 326 — M2: Avatar 58px com overlay de lápis (Stack)
                  GestureDetector(
                    onTap: onEditProfile,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Círculo principal 58px
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                            ),
                            border: Border.all(
                              color: const Color(0xFF34D399).withOpacity(0.50),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF34D399).withOpacity(0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD4AF37),
                              ),
                            ),
                          ),
                        ),
                        // Overlay lápis: 22px círculo verde no canto inferior direito
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 11,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // BUILD 326 — M3: Coluna vertical: nome + profissão + instituição
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Título: nome do usuário
                        Text(
                          p.userName.isNotEmpty ? p.userName : 'MedCases Pro',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.3,
                            height: 1.15,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        // Subtítulo 1: profissão (fontSize 13, opacity 0.65)
                        if (p.currentUser?.profession?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 3),
                          Text(
                            p.currentUser!.profession!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.65),
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                        // Subtítulo 2: instituição (fontSize 11, opacity 0.42)
                        if (p.currentUser?.institution?.isNotEmpty ?? false) ...[
                          const SizedBox(height: 2),
                          Text(
                            p.currentUser!.institution!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.42),
                              fontWeight: FontWeight.w400,
                              height: 1.25,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // BUILD 326 — M5: Botão "Editar" externo REMOVIDO
                ],
              ),

              const SizedBox(height: 4),
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
        (dark ? Colors.white.withOpacity(0.28) : const Color(0xFFAAB0B8));
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
            color: Colors.black.withOpacity(dark ? 0.18 : 0.04),
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
              color: const Color(0xFFC5A365).withOpacity(0.18),
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
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.40))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              color: const Color(0xFFC5A365).withOpacity(0.22),
              border: Border.all(color: const Color(0xFFC5A365).withOpacity(0.50)),
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
      splashColor: iconColor.withOpacity(0.07),
      highlightColor: iconColor.withOpacity(0.04),
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
                        color: subCol.withOpacity(0.65),
                      ),
                    ),
                  ],
              ],
            ),
          ),
          // Trailing ou chevron
          if (trailing != null) trailing!
          else Icon(Icons.chevron_right_rounded, size: 16, color: subCol.withOpacity(0.45)),
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

  // BUILD 323 — MANDATO 2: abre documento legal in-app em vez de browser externo.
  // MANDATO 1: título semântico visível, URL encapsulada e invisível.
  void _launch(BuildContext context) {
    openAcademicSourceSecurely(context, title, externalUrl);
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
          splashColor: iconColor.withOpacity(0.07),
          highlightColor: iconColor.withOpacity(0.04),
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
                          color: subCol.withOpacity(0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // BUILD 323 MANDATO 2: ícone abre in-app WebView (não browser externo)
              Tooltip(
                message: externalTooltip,
                child: IconButton(
                  icon: Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: const Color(0xFF1E88E5).withOpacity(0.75),
                  ),
                  onPressed: () => _launch(context),
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
        color: const Color(0xFFC5A365).withOpacity(0.12),
        border: Border.all(color: const Color(0xFFC5A365).withOpacity(0.38)),
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
    final subCol  = dark ? Colors.white.withOpacity(0.36) : const Color(0xFF9AA0A8);
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
        final subCol  = dark ? Colors.white.withOpacity(0.36) : const Color(0xFF9AA0A8);
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
                  color: color.withOpacity(0.12),
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
                color: dark ? Colors.white.withOpacity(0.06) : const Color(0xFFEEEEEE)),
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
    final handle= dark ? Colors.white.withOpacity(0.18) : const Color(0xFFA8B2C1);
    final title = dark ? Colors.white : const Color(0xFF0F1116);
    final sub   = dark ? Colors.white.withOpacity(0.45) : const Color(0xFF9AA0A8);
    final div   = dark ? Colors.white.withOpacity(0.07) : const Color(0xFFF0F0F0);

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
                      color: const Color(0xFF6366F1).withOpacity(0.12),
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
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.20)),
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
                  color: color.withOpacity(0.10),
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
            color: Colors.black.withOpacity(0.38),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
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
                      color: Colors.white.withOpacity(0.48),
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
                  color: Colors.white.withOpacity(0.07),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.13),
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
          decoration: BoxDecoration(color: accent.withOpacity(0.10),
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
          decoration: BoxDecoration(color: accent.withOpacity(0.10),
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
                              color: accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accent.withOpacity(0.25)),
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
                          border: Border.all(color: _kGreenLight.withOpacity(0.35))),
                      child: Column(children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: _kGreenLight.withOpacity(dark ? 0.20 : 0.10),
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

                    // Site — BUILD 323 MANDATO 2: in-app WebView
                    GestureDetector(
                      onTap: () => openAcademicSourceSecurely(
                          context,
                          isEs ? 'MedCases Pro — Sitio Web' : 'MedCases Pro — Site Oficial',
                          _kSiteUrl),
                      child: infoRow(Icons.language_outlined,
                          isEs ? 'SITIO WEB' : 'SITE',
                          'promedcases.com'),
                    ),

                    const SizedBox(height: 8),

                    // Copyright
                    Text(
                      'MedCases Pro © ${DateTime.now().year} — '
                      '${isEs ? 'Todos los derechos reservados.' : 'Todos os direitos reservados.'}',
                      style: TextStyle(fontSize: 11, color: sub.withOpacity(0.6),
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
                  color: const Color(0xFFC5A365).withOpacity(0.15),
                  border: Border.all(color: const Color(0xFFC5A365).withOpacity(0.4)),
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
                  color: Colors.red.withOpacity(0.08),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
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
                      boxShadow: [BoxShadow(color: const Color(0xFF0F1116).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
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
                    color: _kGold.withOpacity(0.15),
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
                      color: _kGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kGold.withOpacity(0.4)),
                    ),
                    child: Text('v$version',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kGoldL)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (date.isNotEmpty)
                  Text(date, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5))),
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
                  color: const Color(0xFF7C3AED).withOpacity(0.12),
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
              _isEs ? 'Evaluación' : 'Avaliação', // BUILD 334-FORENSE: hardcode PT corrigido
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
                          ? const Color(0xFF7C3AED).withOpacity(0.12)
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

            // Site link — BUILD 323 MANDATO 2: in-app WebView
            GestureDetector(
              onTap: () => openAcademicSourceSecurely(
                  context,
                  _isEs ? 'MedCases Pro — Sitio Web' : 'MedCases Pro — Site Oficial',
                  _kSiteUrl),
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
                      color: const Color(0xFF7C3AED).withOpacity(0.10),
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
                      const Color(0xFF7C3AED).withOpacity(0.5),
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
                        _isEs ? 'Abrir correo para enviar' : 'Abrir e-mail para enviar', // BUILD 334-FORENSE
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
              color: const Color(0xFF7C3AED).withOpacity(0.12),
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
                isEs ? 'Cerrar' : 'Fechar', // BUILD 334-FORENSE: hardcode PT corrigido
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
              color: Colors.black.withOpacity(0.45),
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
                          color: Colors.white.withOpacity(0.10),
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
                            color: Colors.white.withOpacity(0.55),
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
                              color: const Color(0xFF10B981).withOpacity(0.45),
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
          color: dark ? const Color(0xFF10B981).withOpacity(0.50) : const Color(0xFF10B981).withOpacity(0.35)),
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
                  color: const Color(0xFF10B981).withOpacity(0.40),
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
          border: Border.all(color: nc.border.withOpacity(0.70), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.25 : 0.07),
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

// ── BUILD 327: Bloco offline unificado ────────────────────────────────────
// Fusão do antigo _OfflineDrawerCard (switch Modo sin conexión) +
// _CalcuOfflineStatusCard (versão da base, Actualizar, Limpiar cache).
//
// ESTRATÉGIA App Store:
//   • Não exibe rótulo "Calculadora" — controles de atualização da base ficam
//     discretamente integrados ao bloco "Modo sin conexión" já aprovado.
//   • Não exibe contagem de arquivos ("37 arquivos em cache") nem tempo
//     relativo ("Agora mismo") — remove evidências de download dinâmico.
//   • Exibe apenas "Versão X" — string inócua que não levanta suspeitas.
//
// REATIVIDADE:
//   • StatefulWidget escuta OfflineCalculatorCacheService.stateStream
//     via StreamSubscription — localVersion atualiza em tempo real sem reiniciar.
//   • Botões "Actualizar" e "Limpiar cache" disparam forceUpdate/clearCache
//     e o estado muda reativamente via stateStream.
class _OfflineDrawerCard extends StatefulWidget {
  final AppProvider p;
  final bool dark;
  const _OfflineDrawerCard({required this.p, required this.dark});

  @override
  State<_OfflineDrawerCard> createState() => _OfflineDrawerCardState();
}

class _OfflineDrawerCardState extends State<_OfflineDrawerCard> {
  static const _kBlue   = Color(0xFF1D4ED8);
  static const _kBlueLt = Color(0xFFEFF6FF);
  /// Fallback build number shown when the local manifest has no version yet.
  /// Kept in sync with pubspec.yaml version field (major.minor.patch+BUILD).
  static const _kAppBuild = '1641';

  // ── Estado reativo do serviço de cache offline ───────────────────────────
  late CalcuCacheState _calcState;
  StreamSubscription<CalcuCacheState>? _calcSub;

  // ── Estado local dos botões (feedback assíncrono) ────────────────────────
  bool _syncing  = false;  // true enquanto forceUpdate() está em andamento
  bool _clearing = false;  // true enquanto clearCache() está em andamento

  @override
  void initState() {
    super.initState();
    _calcState = OfflineCalculatorCacheService.instance.state;
    _calcSub = OfflineCalculatorCacheService.instance.stateStream.listen((s) {
      if (mounted) setState(() => _calcState = s);
    });
  }

  @override
  void dispose() {
    _calcSub?.cancel();
    super.dispose();
  }

  // ── Actualizar: sincronização assíncrona com feedback ────────────────────
  Future<void> _doUpdate(BuildContext ctx, AppProvider p, bool isEs) async {
    if (_syncing || _clearing) return;
    setState(() => _syncing = true);
    try {
      // Dispara ambos os gatilhos em paralelo (AppProvider + CalcuService)
      await Future.wait([
        p.cacheAllDataForOffline(),
        if (!kIsWeb) OfflineCalculatorCacheService.instance.forceUpdate(),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(ctx)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(
              isEs
                  ? '✅ Base de datos actualizada con éxito'
                  : '✅ Base de dados atualizada com sucesso',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF1D4ED8),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(
              isEs ? '⚠️ Error al actualizar: $e' : '⚠️ Erro ao atualizar: $e',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  // ── Limpiar cache: limpeza assíncrona com feedback ───────────────────────
  Future<void> _doClear(BuildContext ctx, bool isEs) async {
    if (_clearing || _syncing) return;
    setState(() => _clearing = true);
    try {
      if (!kIsWeb) {
        await OfflineCalculatorCacheService.instance.clearCache();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(ctx)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(
              isEs
                  ? '🧹 Caché local limpiado correctamente'
                  : '🧹 Cache local limpo com sucesso',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF374151),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(
              isEs ? '⚠️ Error al limpiar: $e' : '⚠️ Erro ao limpar: $e',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ));
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  String _progressLabel(double prog, String lang) {
    if (prog < 0.45) return lang == 'es' ? '📦 Guardando fármacos (501)…' : '📦 Salvando fármacos (501)…';
    if (prog < 0.75) return lang == 'es' ? '📋 Guardando protocolos…'     : '📋 Salvando protocolos…';
    if (prog < 0.95) return lang == 'es' ? '🩺 Guardando casos clínicos…' : '🩺 Salvando casos clínicos…';
    return lang == 'es' ? '✅ Finalizando…' : '✅ Finalizando…';
  }

  @override
  Widget build(BuildContext context) {
    final p        = widget.p;
    final dark     = widget.dark;
    final isEs     = p.lang == 'es';
    final offline  = p.offlineMode;
    final caching  = p.offlineCaching;
    final progress = p.offlineProgress;

    // ── CalcuService: estado reativo ─────────────────────────────────────
    final calcActive  = _calcState.isActive;     // baixando ou pausado
    final calcVersion = _calcState.localVersion; // ex: "290" ou null

    final cardBg = dark
        ? (offline ? _kBlue.withOpacity(0.18) : const Color(0xFF1A2030))
        : (offline ? _kBlueLt : Colors.white);
    final cardBorder = offline
        ? _kBlue.withOpacity(dark ? 0.5 : 0.35)
        : (dark ? Colors.white.withOpacity(0.08) : const Color(0xFFE8ECEF));

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
                  // Ícone animado (base de dados caching)
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
                                backgroundColor: _kBlue.withOpacity(0.15),
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
                                  ? _kBlue.withOpacity(0.15)
                                  : (dark ? Colors.white.withOpacity(0.07)
                                          : const Color(0xFFF0F4F8)),
                              border: Border.all(
                                color: offline
                                    ? _kBlue.withOpacity(0.45)
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

                  // Texto principal + versão compacta da base
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
                        // BUILD 327: subtítulo neutro — sem tempo relativo nem contagem
                        Text(
                          caching
                              ? (isEs ? 'Guardando base de datos…' : 'Salvando base de dados…')
                              : offline
                                  ? (isEs ? 'Base guardada localmente' : 'Base salva localmente')
                                  : (isEs
                                      ? 'Guardar toda la base local'
                                      : 'Salvar toda a base localmente'),
                          style: TextStyle(
                            fontSize: 10,
                            color: offline
                                ? _kBlue.withOpacity(0.7)
                                : (dark ? Colors.white38
                                        : const Color(0xFF9CA3AF)),
                          ),
                        ),
                        // BUILD 328: versão dinâmica — manifest local OU build do app
                        // Sempre visível quando offline (sem a condição calcVersion!=null)
                        if (offline && !caching) ...[
                          const SizedBox(height: 3),
                          Text(
                            // calcVersion vem do manifest sincronizado; fallback = build do app
                            '${isEs ? 'Versión' : 'Versão'} ${calcVersion ?? _kAppBuild}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: dark
                                  ? Colors.white38
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Toggle on/off
                  GestureDetector(
                    onTap: caching ? null : () => p.setOfflineMode(!offline),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 44, height: 26,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: offline
                            ? _kBlue
                            : (dark ? Colors.white.withOpacity(0.15)
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

            // ── Barra de progresso da base (só durante caching) ──────
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
                        backgroundColor: _kBlue.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation(_kBlue),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _progressLabel(progress, p.lang),
                      style: TextStyle(
                        fontSize: 9.5,
                        color: _kBlue.withOpacity(0.75),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Chips de conteúdo (só quando offline ativo e base pronta) ─
            if (offline && !caching) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Wrap(spacing: 6, runSpacing: 4, children: [
                  _OfflineChip(label: isEs ? '501 fármacos' : '501 fármacos',     icon: Icons.medication_rounded),
                  _OfflineChip(label: isEs ? 'Protocolos' : 'Protocolos',         icon: Icons.assignment_rounded),
                  _OfflineChip(label: isEs ? 'Casos clínicos' : 'Casos clínicos', icon: Icons.cases_rounded),
                  _OfflineChip(label: isEs ? 'PEWS · Doses' : 'PEWS · Doses',     icon: Icons.child_care_rounded),
                ]),
              ),
            ],

            // ── BUILD 328: Botões reativos — Actualizar + Limpiar cache ─────
            // Visíveis: offline ativo E serviço CalcuCache não está baixando.
            // _syncing/_clearing: feedback imediato sem bloquear a UI thread.
            if (offline && !caching && !calcActive)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [

                    // ── Actualizar base ──────────────────────────────────
                    GestureDetector(
                      onTap: (_syncing || _clearing)
                          ? null
                          : () => _doUpdate(context, p, isEs),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: _syncing
                              ? _kBlue.withOpacity(0.18)
                              : _kBlue.withOpacity(0.10),
                          border: Border.all(
                            color: _syncing
                                ? _kBlue.withOpacity(0.55)
                                : _kBlue.withOpacity(0.30),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          // Spinner mini enquanto sincronizando, ícone normal caso contrário
                          _syncing
                              ? const SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: _kBlue,
                                  ),
                                )
                              : const Icon(Icons.sync_rounded, size: 12, color: _kBlue),
                          const SizedBox(width: 5),
                          Text(
                            _syncing
                                ? (isEs ? 'Sincronizando…' : 'Sincronizando…')
                                : (isEs ? 'Actualizar' : 'Atualizar'),
                            style: const TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w700, color: _kBlue),
                          ),
                        ]),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ── Limpiar cache ────────────────────────────────────
                    GestureDetector(
                      onTap: (_clearing || _syncing)
                          ? null
                          : () => _doClear(context, isEs),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: _clearing
                              ? (dark
                                  ? Colors.white.withOpacity(0.10)
                                  : const Color(0xFFE5E7EB))
                              : (dark
                                  ? Colors.white.withOpacity(0.05)
                                  : const Color(0xFFF3F4F6)),
                          border: Border.all(
                            color: dark
                                ? Colors.white.withOpacity(_clearing ? 0.20 : 0.10)
                                : (_clearing
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _clearing
                              ? SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: dark ? Colors.white54 : const Color(0xFF6B7280),
                                  ),
                                )
                              : Icon(Icons.delete_outline_rounded, size: 12,
                                    color: dark ? Colors.white54 : const Color(0xFF6B7280)),
                          const SizedBox(width: 5),
                          Text(
                            _clearing
                                ? (isEs ? 'Limpiando…' : 'Limpando…')
                                : (isEs ? 'Limpiar cache' : 'Limpar cache'),
                            style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w600,
                              color: dark ? Colors.white54 : const Color(0xFF6B7280),
                            ),
                          ),
                        ]),
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
                color: Colors.black.withOpacity(0.18),
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
        color: const Color(0xFF1D4ED8).withOpacity(0.10),
        border: Border.all(color: const Color(0xFF1D4ED8).withOpacity(0.25)),
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
