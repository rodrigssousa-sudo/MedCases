import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'home_v2/home_screen_v2.dart';
import 'screens/home_screen.dart'
    show PediatricsMainShellWorkspace, InternacionMainShellWorkspace;
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
    show Timestamp, FirebaseFirestore, Settings;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'providers/ui_provider.dart'; // BUILD 326: sub-provider de UI
import 'providers/ai_chat_provider.dart'; // BUILD 326: sub-provider de IA/chat
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
import 'screens/support_ticket_screen.dart';
import 'screens/professional_gate_screen.dart';
import 'screens/fontes_screen.dart';
// Mantido temporariamente para rollback imediato da Home V3.
// ignore: unused_import
import 'screens/notes_screen.dart';
import 'screens/library_screen.dart';
import 'screens/vaccines_screen.dart';
import 'screens/avaliacao_screen.dart';
import 'screens/laboratory_screen.dart'
    show LaboratoryMainShellWorkspace, LaboratorySessionBridge;
import 'screens/remote_audio_consent_sheet.dart';
import 'screens/notes_audio_local_runtime_screen.dart';
import 'screens/calculadora_screen.dart' show CalculadoraScreen;
import 'services/firestore_service.dart';
import 'services/activity_service.dart';
import 'services/gemini_service.dart';
// ai_gateway_service.dart — Build 156: importado apenas como shim de compatibilidade.
// O gateway Node.js foi desativado; o shim delega para GeminiServiceV2 (BYOA direto).
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'services/offline_calculator_cache_service.dart'; // BUILD 240: smart offline cache
import 'services/calculator_webview_prewarm_service.dart';
import 'services/app_resume_coordinator.dart'; // BUILD 241: background/resume safety
import 'widgets/brand_mark.dart';
import 'widgets/common_widgets.dart' show AppHaptics;
import 'screens/study_workspace_screen.dart';
import 'screens/study_history_screen.dart';
import 'home_v2/components/navigation/home_card_transition.dart';
import 'widgets/medcases_webview_screen.dart'; // BUILD 323 — MANDATO 2: in-app WebView
import 'platform/web_impl.dart' if (dart.library.io) 'platform/web_stub.dart'
    as webPlatform;

Future<void> main() async {
  FlutterError.onError = (FlutterErrorDetails details) {
    // Diagnóstico temporário: imprime o stack completo mesmo em erros repetidos.
    FlutterError.dumpErrorToConsole(details, forceReport: true);
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

  // ── MICRO-BUILD 462E-A.5.3.7.3.2.5.3.1: Runtime boot identity verification ──
  // Emitted immediately after WidgetsFlutterBinding — before any async work.
  // Proves that the active browser cache is executing our latest compiled code
  // and prevents service-worker stale-caching from silently serving old bundles.
  // Values injected at compile time via --dart-define; never hardcoded.
  // Format is machine-parseable for CI log scraping.
  const String buildCommit =
      String.fromEnvironment('BUILD_COMMIT', defaultValue: 'unknown');
  const String bundleVersion =
      String.fromEnvironment('BUNDLE_VERSION', defaultValue: 'dev');
  const String builtAt =
      String.fromEnvironment('BUILT_AT', defaultValue: 'unknown');
  final bool compileIdentityAvailable = buildCommit != 'unknown' &&
      buildCommit.isNotEmpty &&
      bundleVersion != 'dev' &&
      bundleVersion.isNotEmpty &&
      builtAt != 'unknown' &&
      builtAt.isNotEmpty;

  final String compileIdentityState =
      compileIdentityAvailable ? 'AVAILABLE' : 'FALLBACK';

  // ignore: avoid_print
  print('[COMPILE_IDENTITY][$compileIdentityState]\n'
      'sha=$buildCommit\n'
      'bundleVersion=$bundleVersion\n'
      'builtAt=$builtAt\n'
      'canonical=false');

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

  // ── PILAR 4: Post-hydration deploy identity loader ────────────────────────
  // Fire-and-forget — never blocks boot or UI rendering.
  // Fetches /deploy_meta.json written by docker/40-generate-deploy-meta.sh
  // at container start. Cache-busting ?ts= param bypasses SW fetch interception.
  // Safe-catch: any network error is swallowed silently.
  _loadDeployMeta();
}

/// Fetches the runtime deploy identity descriptor generated by the nginx
/// bootstrapper (docker/40-generate-deploy-meta.sh) at container start.
/// Only active on web; on native platforms this is a no-op.
/// No UIDs, auth tokens, or user data are ever logged.
Future<void> _loadDeployMeta() async {
  if (!kIsWeb) return;
  try {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.base.resolve('deploy_meta.json?ts=$ts');
    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final Map<String, dynamic> meta =
          jsonDecode(res.body) as Map<String, dynamic>;
      final String status = meta['status'] as String? ?? 'unavailable';
      final String deployCommit = meta['deployCommit'] as String? ?? 'unknown';
      final String metaBundleVersion =
          meta['bundleVersion'] as String? ?? 'unknown';
      final String containerStartedAt =
          meta['containerStartedAt'] as String? ?? 'unknown';
      if (status == 'available') {
        debugPrint('[DEPLOY_IDENTITY][AVAILABLE] '
            'sha=$deployCommit '
            'bundleVersion=$metaBundleVersion '
            'containerStartedAt=$containerStartedAt '
            'source=runtime_metadata '
            'canonical=true');
      } else {
        debugPrint('[DEPLOY_IDENTITY][UNAVAILABLE] '
            'reason=metadata_unavailable '
            'source=runtime_metadata '
            'canonical=false');
      }
    } else {
      debugPrint('[DEPLOY_IDENTITY][UNAVAILABLE] '
          'reason=http_status '
          'httpStatus=${res.statusCode} '
          'source=runtime_metadata '
          'canonical=false');
    }
  } catch (_) {
    debugPrint('[DEPLOY_IDENTITY][UNAVAILABLE] '
        'reason=metadata_unavailable '
        'source=runtime_metadata '
        'canonical=false');
  }
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

  // AUDIT 453 — Multi-platform Firestore Persistence Config
  //
  // PROBLEMA: Na Web, o SDK Firestore usa IndexedDB para cache offline.
  // No iOS/Android, usa SQLite nativo. Sem configuração explícita, o cache
  // pode ficar limitado ou desativado em determinadas plataformas.
  //
  // SOLUÇÃO:
  //   • Nativo (iOS/Android): persistenceEnabled + CACHE_SIZE_UNLIMITED via Settings()
  //   • Web: não usa Settings() — o SDK Web usa PersistenceSettings/IndexedDB
  //     e já tem cache habilitado por padrão. Não chamar settings= na Web evita
  //     o erro "FirebaseException: Cache size must be between 1 MB and 100 MB" (Web SDK).
  //
  // NOTA: esta configuração NÃO afeta as Firestore Rules — é apenas cache local.
  // A leitura dos dados ainda exige autenticação válida (ver _waitForAuth()).
  try {
    if (FirebaseRuntimeGuard.isReady && !kIsWeb) {
      // Mobile: configura persistência e cache ilimitado uma única vez pós-init
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
      debugPrint('[AUDIT453][FIRESTORE] persistência mobile configurada: '
          'persistenceEnabled=true cacheSizeBytes=UNLIMITED');
    }
    // Web: cache IndexedDB já habilitado por padrão pelo SDK — sem configuração extra.
    // Tentar definir settings= na Web pode lançar exception se o IndexedDB
    // já tiver uma instância aberta (ex: múltiplas abas).
  } catch (e) {
    debugPrint('[AUDIT453][FIRESTORE] settings config ignorado: $e');
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

class MedCasesApp extends StatefulWidget {
  final Future<void> firebaseInit;
  const MedCasesApp({super.key, required this.firebaseInit});

  @override
  State<MedCasesApp> createState() => _MedCasesAppState();

  static ThemeData _buildTheme(bool dark) => ThemeData(
        // MEDCASES_GLOBAL_DARK_THEME_SECOND_BRAND_V2_B_R1_ROOT
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
                primary: const Color(0xFF0D6B57), // MedCases canonical
                onPrimary: const Color(0xFFFFFFFF),
                secondary: const Color(0xFF0D6B57), // single MedCases accent
                onSecondary: const Color(0xFFFFFFFF),
                surface: const Color(0xFF252930), // cards
                onSurface: const Color(0xFFFFFFFF), // texto principal
                surfaceContainerHighest: const Color(0xFF252930),
                surfaceContainerHigh: const Color(0xFF252930),
                surfaceContainer: const Color(0xFF252930),
                surfaceContainerLow: const Color(0xFF1A1D23),
                surfaceDim: const Color(0xFF1A1D23),
                outline: const Color(0xFF374151),
                outlineVariant: const Color(0xFF374151),
                error: const Color(0xFFFF7070),
                onError: Colors.white,
                inverseSurface: const Color(0xFFFFFFFF),
                onInverseSurface: const Color(0xFF1A1D23),
              )
            : const ColorScheme.light(
                // LIGHT_MODE_PREMIUM_V1_A_R14_ROOT_THEME
                primary: Color(0xFF0F172A),
                onPrimary: Color(0xFFFFFFFF),
                secondary: Color(0xFF0D6B57),
                onSecondary: Color(0xFFFFFFFF),
                surface: Color(0xFFFFFFFF),
                onSurface: Color(0xFF0F172A),
                surfaceContainerHighest: Color(0xFFF1F5F9),
                surfaceContainerHigh: Color(0xFFF8FAFC),
                surfaceContainer: Color(0xFFFFFFFF),
                surfaceContainerLow: Color(0xFFF8FAFC),
                surfaceDim: Color(0xFFE2E8F0),
                outline: Color(0xFFCBD5E1),
                outlineVariant: Color(0xFFE2E8F0),
                error: Color(0xFFDC2626),
                onError: Color(0xFFFFFFFF),
                inverseSurface: Color(0xFF1A1D23),
                onInverseSurface: Color(0xFFFFFFFF),
              ),
        scaffoldBackgroundColor:
            dark ? const Color(0xFF1A1D23) : const Color(0xFFF4F7FA),
        cardColor: dark ? const Color(0xFF252930) : Colors.white,
        dividerColor: dark ? const Color(0xFF374151) : const Color(0xFFE2E6EA),
        // Textos padrão do tema
        textTheme: dark
            ? const TextTheme(
                bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
                bodyMedium: TextStyle(color: Color(0xFFFFFFFF)),
                bodySmall: TextStyle(color: Color(0xFFA8B2C1)),
                titleLarge: TextStyle(color: Color(0xFFFFFFFF)),
                titleMedium: TextStyle(color: Color(0xFFFFFFFF)),
                titleSmall: TextStyle(color: Color(0xFFA8B2C1)),
                labelLarge: TextStyle(color: Color(0xFFFFFFFF)),
                labelMedium: TextStyle(color: Color(0xFFA8B2C1)),
                labelSmall: TextStyle(color: Color(0xFF6B7280)),
              )
            : const TextTheme(
                displayLarge: TextStyle(color: Color(0xFF0F172A)),
                displayMedium: TextStyle(color: Color(0xFF0F172A)),
                displaySmall: TextStyle(color: Color(0xFF0F172A)),
                headlineLarge: TextStyle(color: Color(0xFF0F172A)),
                headlineMedium: TextStyle(color: Color(0xFF0F172A)),
                headlineSmall: TextStyle(color: Color(0xFF0F172A)),
                titleLarge: TextStyle(color: Color(0xFF0F172A)),
                titleMedium: TextStyle(color: Color(0xFF0F172A)),
                titleSmall: TextStyle(color: Color(0xFF334155)),
                bodyLarge: TextStyle(color: Color(0xFF0F172A)),
                bodyMedium: TextStyle(color: Color(0xFF334155)),
                bodySmall: TextStyle(color: Color(0xFF64748B)),
                labelLarge: TextStyle(color: Color(0xFF0F172A)),
                labelMedium: TextStyle(color: Color(0xFF475569)),
                labelSmall: TextStyle(color: Color(0xFF64748B)),
              ),
        inputDecorationTheme: dark
            ? const InputDecorationTheme()
            : InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFFFFFFFF),
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
                labelStyle: const TextStyle(
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                ),
                floatingLabelStyle: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF0D6B57),
                    width: 1.4,
                  ),
                ),
              ),
        // Transições de página suaves
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      );

  static ThemeData get _authTheme => ThemeData(
        // MEDCASES_SPLASH_AUTH_THEME_UI_V2_B_R1_AUTH_THEME
        useMaterial3: true,
        fontFamily: 'Roboto',
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1A1D23),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0D6B57),
          secondary: Color(0xFF0D6B57),
          surface: Color(0xFF252930),
          onSurface: Colors.white,
          outline: Color(0xFF374151),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      );
}

class _MedCasesAppState extends State<MedCasesApp> {
  final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  late final _AuthGate _stableAuthGate;

  @override
  void initState() {
    super.initState();

    // O fluxo de autenticação e o shell são criados uma única vez por sessão.
    // A troca de tema atualiza somente ThemeMode e cores herdadas.
    _stableAuthGate = _AuthGate(firebaseInit: widget.firebaseInit);
  }

  @override
  Widget build(BuildContext context) {
    // BUILD 326: context.select<UiProvider> — rebuild APENAS quando darkMode muda.
    // UiProvider é notificado SOMENTE por toggleDarkMode() / setLang() —
    // completamente isolado do streaming de IA e outros notifyListeners().
    final darkMode = context.select<UiProvider, bool>((p) => p.darkMode);
    return MaterialApp(
      navigatorKey: _rootNavigatorKey,
      title: 'MedCases Pro',
      debugShowCheckedModeBanner: false,
      theme: (() {
        // MEDCASES_LIGHT_TOPBAR_GLOBAL_V1_B_R2
        final baseTheme = MedCasesApp._buildTheme(false);
        return baseTheme.copyWith(
          appBarTheme: baseTheme.appBarTheme.copyWith(
            backgroundColor: const Color(0xFFECF1F3),
            foregroundColor: const Color(0xFF05070A),
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(
              color: Color(0xFF05070A),
            ),
            actionsIconTheme: const IconThemeData(
              color: Color(0xFF05070A),
            ),
            titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF05070A),
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      })(),
      darkTheme: MedCasesApp._buildTheme(true),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      // Troca instantânea: evita frames híbridos entre AppProvider e Theme.
      themeAnimationDuration: Duration.zero,
      themeAnimationCurve: Curves.linear,

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
      color: darkMode ? const Color(0xFF0F1116) : const Color(0xFFFFFFFF),

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
        Locale('pt'), // Português (genérico)
        Locale('es'), // Espanhol
        Locale('en'), // Inglês (fallback padrão do Flutter)
      ],
      home: _stableAuthGate,

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
      builder: (context, child) => NotificationOverlay(
        child: ColoredBox(
          color: darkMode ? const Color(0xFF0F1116) : const Color(0xFFFFFFFF),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
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

  // Referência direta ao state filho. findAncestorStateOfType não funciona
  // aqui porque _TimedSplash é DESCENDENTE de _AuthGate, não ancestral.
  final GlobalKey<_TimedSplashState> _timedSplashKey =
      GlobalKey<_TimedSplashState>();

  Widget _wrapAuth(Widget child) => Theme(
        data: MedCasesApp._authTheme,
        child: child,
      );

  void _signalTimedSplashReady() {
    if (!mounted) return;

    final state = _timedSplashKey.currentState;
    if (state != null) {
      state._signalAuthResolved();
      return;
    }

    // Em um primeiro frame muito precoce, o state filho pode ainda não estar
    // montado. A segunda tentativa ocorre depois do frame, sem loop recursivo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _timedSplashKey.currentState?._signalAuthResolved();
    });
  }

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
      _signalTimedSplashReady();
    });
  }

  // BUILD 313 — sinaliza _authResolved ao _TimedSplash sem exigir usuário aprovado.
  // Usado para fluxos onde o auth determinou um estado final (sem usuário,
  // bloqueado, pendente, erro Firebase) — o splash DEVE ser removido nesses casos
  // também, pois o fluxo está estável (LoginScreen / BlockedScreen / PendingScreen).
  // Agendado via addPostFrameCallback para evitar setState() durante build().
  void _signalSplashReady(BuildContext _) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _signalTimedSplashReady();
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
          _signalSplashReady(context);
          return _wrapAuth(const PreLoginPreview());
        }

        // Usuário bloqueado
        if (user.isBlocked) {
          AuthService.logout();
          _onLogout();
          _signalSplashReady(context);
          return _wrapAuth(_BlockedScreen(user: user));
        }

        // Usuário pendente
        if (user.isPending) {
          _signalSplashReady(context);
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
    // _TimedSplash garante visibilidade mínima de 3.2s + fade-out suave.
    // Quando splash e boot terminam → readyBuilder() exibe o fluxo real de auth.
    // A lógica de auth (FutureBuilder → StreamBuilder) é preservada intacta.
    // BUILD 313: _TimedSplash recebe onAuthResolved para atrasar
    // FlutterNativeSplash.remove() até a auth resolver estado estável.
    return _TimedSplash(
      key: _timedSplashKey,
      bootFuture: widget.firebaseInit,
      splash: _wrapAuth(const _SplashScreen()),
      readyBuilder: (context) => _buildAuthFlow(context),
      onAuthResolved: _signalTimedSplashReady,
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
        final maintenanceMessage = maintSnap.data?['message'] as String? ?? '';

        // Admin / Master passam pela manutenção direto
        final bypassMaintenance = widget.user.isAdmin || widget.user.isMaster;

        if (isMaintenanceEnabled && !bypassMaintenance) {
          return widget
              .wrapAuth(MaintenanceScreen(message: maintenanceMessage));
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
  // MEDCASES_AUTH_CONSENT_GATE_UI_V2_B_R1
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
        backgroundColor: Color(0xFF1A1D23),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFF0D6B57))),
      );
    }
    if (_hasConsented!) return const LoginScreen();
    return Stack(children: [
      const LoginScreen(),
      Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.50))),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: ConsentModal(
          lang: Localizations.localeOf(context).languageCode == 'es'
              ? 'es'
              : 'pt',
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
//   • Logo: M+ isolado 150×150, sem moldura, giro 3D horizontal Y 360° no próprio centro + zoom suave
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
  // MEDCASES_SPLASH_AUTH_THEME_UI_V2_B_R1_SPLASH
  // ── Entrada premium (1450 ms) ─────────────────────────────────
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  // MEDCASES_SPLASH_MPLUS_360_ZOOM_PREMIUM_V1_B_R5
  late Animation<double> _logoTurns;
  late Animation<double> _logoIntroScale;

  // ── Pulso contínuo do logo (2400 ms, repeat) ─────────────────
  // Opacity: 1.0 → 0.55 → 1.0 (Curves.easeInOut)
  // Scale:   1.0 → 1.06 → 1.0 (Curves.easeInOut)
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseOpacity;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    // ── Animação de entrada ──────────────────────────────────────
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1450));
    _scale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.65)));
    _slide = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _logoTurns = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic),
    );

    _logoIntroScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.92, end: 1.10).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
        weight: 72,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.10, end: 1.00).chain(
          CurveTween(curve: Curves.easeInOutCubic),
        ),
        weight: 28,
      ),
    ]).animate(_ctrl);

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
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D6B57).withOpacity(0.055),
            ),
          ),
        ),
        Positioned(
          bottom: h * 0.12,
          left: -50,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D6B57).withOpacity(0.035),
            ),
          ),
        ),

        // ── Bloco central: logo + título + tagline ────────────────────────────
        // Posicionado no terço superior da tela para hierarquia visual clara.
        Positioned(
          top: h * 0.27,
          left: 0,
          right: 0,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── M+ 150px: giro horizontal Y 360° + zoom, depois pulso ──
                    // AnimatedBuilder reage ao _pulseCtrl (repeat reverse):
                    // opacidade 1.0↔0.55 e escala 1.0↔1.06 com easeInOut 2.4s.
                    AnimatedBuilder(
                      animation: Listenable.merge([_ctrl, _pulseCtrl]),
                      builder: (_, child) => Opacity(
                        opacity: _pulseOpacity.value,
                        child: Transform.scale(
                          scale: _logoIntroScale.value * _pulseScale.value,
                          alignment: Alignment.center,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0016)
                              ..rotateY(
                                _logoTurns.value * 6.283185307179586,
                              ),
                            child: child,
                          ),
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 150,
                        child: Center(
                          child: Image.asset(
                            'assets/icon/splash_mplus_premium.png',
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
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
                        color: const Color(0xFF0D6B57).withOpacity(0.85),
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
          left: 0,
          right: 0,
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
  State<_SplashLoadingIndicator> createState() =>
      _SplashLoadingIndicatorState();
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
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              const Color(0xFF0D6B57).withOpacity(0.70),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
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
// Com _TimedSplash: a splash sempre exibe por mínimo 3.2s → transição suave.
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
    super.key,
    required this.bootFuture,
    required this.readyBuilder,
    required this.splash,
    this.onAuthResolved,
  });

  @override
  State<_TimedSplash> createState() => _TimedSplashState();
}

class _TimedSplashState extends State<_TimedSplash> {
  static const _kMinMs = 4520; // mínimo 3.2s de splash dinâmico visível
  // BUILD 241: watchdog — se o bootstrap não terminar em 20s, força conclusão.
  // Protege contra: browser throttle, Firebase timeout, aba inativa durante boot.
  static const _kWatchdogMs = 20000;

  bool _minTimeDone = false;
  bool _bootDone = false;
  // SEMÁFORO 3: authResolved — determina a transição splash → conteúdo real.
  // Só muda para true quando _AuthGateState._onUserResolved() sinaliza que
  // o StreamBuilder<UserModel?> já determinou um estado estável de auth
  // (aprovado / bloqueado / pendente / não autenticado).
  bool _authResolved = false;

  // MEDCASES_SPLASH_NO_GRAY_HANDOFF_V1_B_R8
  // O conteúdo real é montado atrás da splash; a splash só começa a sair
  // depois que auth está estável e o conteúdo teve frames reais para pintar.
  bool _handoffScheduled = false;
  bool _handoffDone = false;

  @override
  void initState() {
    super.initState();

    // MEDCASES_SPLASH_NATIVE_TO_FLUTTER_VISUAL_READY_HANDOFF_V1_B_R0
    // O LaunchScreen nativo permanece sobre o Flutter enquanto o Splash 2 real
    // monta e o asset premium M+ é decodificado. A remoção nativa só ocorre
    // depois do precache + dois frames completos de paint do Splash 2.
    //
    // Isso evita que o primeiro frame genérico/sem asset descubra a superfície
    // Flutter e elimina a disputa entre dois owners de FlutterNativeSplash.remove().
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _releaseNativeSplashAfterVisualReady();
      });
    }

    // Timer mínimo
    Future<void>.delayed(const Duration(milliseconds: _kMinMs), () {
      if (mounted) setState(() => _minTimeDone = true);
    });

    // Boot future (Firebase + prefs + auth)
    widget.bootFuture.whenComplete(() {
      if (mounted)
        setState(() {
          _bootDone = true;
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
        if (mounted)
          setState(() {
            _bootDone = true;
            _minTimeDone = true;
          });
      },
    );

    // Timer local como backup: se watchdog não disparou, garante
    // que o splash nunca fica travado para sempre.
    Future<void>.delayed(const Duration(milliseconds: _kWatchdogMs), () {
      if (!mounted) return;
      if (!_bootDone) {
        final elapsed = DateTime.now().difference(bootStart).inMilliseconds;
        debugPrint(
            '[BOOTSTRAP_WATCHDOG] elapsedMs=$elapsed action=force_complete (timer)');
        setState(() {
          _bootDone = true;
          _minTimeDone = true;
        });
        AppResumeCoordinator.instance.completeBootstrap();
      }
    });

    // BUILD 463-A.1.1: The independent 8-second [BUILD313] _authResolved watchdog
    // is REMOVED. Its role caused a race condition: it could fire and unlock
    // the splash gate while the auth convergence manager (AppProvider.setUser())
    // was still awaiting the Firebase SDK latch, leaving the barrier in authPending
    // and allowing Firestore reads to proceed before identity was confirmed.
    //
    // The auth lifecycle is now fully owned by AppProvider's convergence manager.
    // The splash gate unblocks when the auth stream emits a stable final state:
    //   • MATCHED_USER      → _signalAuthResolved() via _onUserResolved()
    //   • STABLE_LOGGED_OUT → _signalSplashReady() via _buildAuthFlow()
    // Both paths call _signalAuthResolved() without any independent timer.
    // The existing 20-second bootstrap watchdog (_kWatchdogMs) remains as the
    // outer safety net for frozen processes — it does not interfere with auth.
  }

  // ── GATE 2: monta o fluxo real após boot + tempo mínimo ───────────────
  // BUILD 331 — correção de deadlock circular:
  // _authResolved é produzido por widgets construídos dentro de readyBuilder().
  // Portanto, ele não pode ser pré-requisito para montar o próprio readyBuilder.
  //
  // Após boot + 3.2s, _buildAuthFlow() é montado. Enquanto Firebase/Auth ainda
  // estiverem resolvendo, o próprio fluxo retorna _SplashScreen; quando chegar
  // a um estado final, ele troca para Login/Home sem tela branca.
  bool get _ready => _minTimeDone && _bootDone;

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

  // MEDCASES_SPLASH_NATIVE_TO_FLUTTER_VISUAL_READY_HANDOFF_V1_B_R0
  // ÚNICO owner produtivo de FlutterNativeSplash.remove().
  Future<void> _releaseNativeSplashAfterVisualReady() async {
    if (!mounted || _splashRemoved || kIsWeb) return;

    // O primeiro frame Flutter já terminou porque este método é iniciado por
    // addPostFrameCallback no initState. Agora garantimos que o M+ premium
    // esteja efetivamente decodificado antes de descobrir a superfície Flutter.
    try {
      await precacheImage(
        const AssetImage('assets/icon/splash_mplus_premium.png'),
        context,
      ).timeout(const Duration(milliseconds: 1500));
    } catch (e) {
      debugPrint(
        '[SPLASH_VISUAL_READY_HANDOFF] precache fallback: $e',
      );
    }
    if (!mounted || _splashRemoved) return;

    // Frame A: Splash 2 com o asset já disponível atravessa layout/paint.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _splashRemoved) return;

    // Frame B: segunda passagem completa para evitar descoberta durante
    // rasterização/primeira composição do asset no iOS.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _splashRemoved) return;

    _splashRemoved = true;
    FlutterNativeSplash.remove();
    debugPrint(
      '[SPLASH_VISUAL_READY_HANDOFF] '
      'native splash removed after asset precache + 2 painted frames',
    );
  }

  Future<void> _releaseSplashAfterContentPaint() async {
    // Frame 1: conteúdo real foi montado atrás da splash.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    // Pequeno buffer para layout/paint/fontes/imagens síncronas estabilizarem.
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    // Frame 2: garante pelo menos um novo pipeline completo com o conteúdo
    // real ainda totalmente coberto pela Splash 2.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    // PHYSICAL FIX: sem crossfade semitransparente. A splash permanece 100%
    // opaca até este frame e então sai atomicamente, evitando expor frames
    // intermediários do Home/Login durante composição.
    setState(() => _handoffDone = true);
  }

  @override
  Widget build(BuildContext context) {
    // O handoff Splash 1 → Splash 2 é resolvido exclusivamente por
    // _releaseNativeSplashAfterVisualReady(). Não existe segundo remove() aqui.

    // GATE 2 — R8: conteúdo real monta ATRÁS da splash.
    // O cinza intermediário não pode ficar exposto ao usuário.
    if (!_ready) {
      return KeyedSubtree(
        key: const ValueKey('splash'),
        child: widget.splash,
      );
    }

    if (_authResolved && !_handoffScheduled) {
      _handoffScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _releaseSplashAfterContentPaint();
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(
          key: const ValueKey('ready-content-behind-splash'),
          child: widget.readyBuilder(context),
        ),
        if (!_handoffDone)
          Positioned.fill(
            child: IgnorePointer(
              child: KeyedSubtree(
                key: const ValueKey('splash-cover-until-rendered'),
                child: widget.splash,
              ),
            ),
          ),
      ],
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
        debugPrint(
            '[PendingScreen] ensureUserProfileExists concluído — uid=${firebaseUser.uid}');
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
    setState(() {
      _checking = true;
      _checkMsg = null;
    });
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
                  const Icon(Icons.hourglass_top_rounded,
                      color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Cadastro em análise',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Olá, ${widget.user.displayName.split(' ').first}!\n\nSua conta está aguardando aprovação do administrador. Você receberá acesso assim que for aprovada.',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.6),
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
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('E-mail cadastrado:',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(widget.user.email,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
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
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.5),
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
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF0F1116)),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label:
                    Text(_checking ? 'Verificando...' : 'Verificar aprovação'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A365),
                  foregroundColor: const Color(0xFF0F1116),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sair e entrar com outra conta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                  const Icon(Icons.block_rounded,
                      color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Acceso suspendido',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu cuenta ha sido suspendida por el administrador.\n\nComunícate con soporte para más información.',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () async {
                  await AuthService.logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Volver al inicio de sesión'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white60,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
      debugPrint(
          '[BOOTSTRAP_WATCHDOG] webGate elapsedMs=$ms action=force_ready (timer)');
      setState(() => _ready = true);
      AppResumeCoordinator.instance
          .completeLoading('_webgate_${widget.user.uid}');
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
    AppResumeCoordinator.instance
        .completeLoading('_webgate_${widget.user.uid}'); // BUILD 241

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
      AppProvider.postOAuthTabNotifier.value =
          2; // IA tab — consumido pelo _MainShellState
      debugPrint(
          '[BUILD334-FORENSE][TAB_RESTORE] hasAnyAi=true → pre-sinaliza tab=2 antes de criar MainShell (gemini=${p.geminiConnected} key=${p.hasAiKey})');
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

  // iPad >=1024: workspace esquerdo independente + IA persistente à direita.
  // Ao tocar na aba IA, preserva a última tela não-IA no painel esquerdo.
  int _lastNonAiWorkspaceTab = 0;

  // ── Callbacks estáveis para HomeScreen ────────────────────────────────────
  // Lambdas inline no build() são recriadas a cada rebuild — geram instabilidade.
  // Métodos da classe são referências estáveis: mesma instância entre rebuilds.
  // PEDIATRIA_MAIN_SHELL_FOOTER_V1_B_R0_BACK
  void _closePediatrics() => _onTabChange(0);

  // PACIENTES_MAIN_SHELL_FOOTER_V1_B_R3_CLOSE
  void _closeInternacionMainShell() => _onTabChange(0);
  // LABORATORIO_SUPER_PREMIUM_MAIN_SHELL_V1_B_R0_BACK
  void _closeLaboratory() => _onTabChange(0);

  // AVALIACAO_MAIN_SHELL_FOOTER_V1_B_R0_BACK
  void _closeAvaliacaoMainShell() => _onTabChange(0);

  void _onTabChange(int t) {
    // LABORATORIO_SUPER_PREMIUM_MAIN_SHELL_V1_B_R0_RESET
    if (_tab == 9 && t != 9) {
      LaboratorySessionBridge.reset();
    }

    if (t != 2) {
      _lastNonAiWorkspaceTab = t;
    }

    // Fecha o teclado SEMPRE que o utilizador muda de aba.
    // Isso previne o bug de "teclado automático" onde o FocusNode da aba anterior
    // (especialmente o AiScreen tab 2) permanece ativo no IndexedStack e
    // re-abre o teclado quando o utilizador navega de volta para a Home.
    //
    // BUILD 292: se um OAuth tab restore está pendente (notifier >= 0) e a
    // mudança é para Home (t == 0), registrar log diagnóstico. A mudança ainda
    // ocorre — é iniciada pelo usuário, não por código de boot.
    if (t == 0 && AppProvider.postOAuthTabNotifier.value >= 0) {
      debugPrint(
          '[BUILD292][TAB_RESTORE] ignored_reset_to_home reason=user_tap_home_while_pending_oauth_tab');
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _tab = t);
    if (t == 3) {
      // MEDCASES_HC_DIRECT_NOVA_ENTRY_V1_B_R0_MAIN_TAB
      HistoryScreen.requestNewWorkspace();
    }
    // BUILD 445: notifica ToolsScreen sobre visibilidade (tab 4 = Ferramentas)
    toolsScreenVisibleNotifier.value = (t == 4);
  }

  void _openClinicalGuide() {
    _onTabChange(5);
  }

  void _openSimulation() {
    _onTabChange(7);
  }

  void _openVaccines() {
    _onTabChange(6);
  }

  void _closeVaccines() {
    _onTabChange(0);
  }

  void _onSubTabChange(int i) => setState(() => _rxProtoSub = i);
  void _onOpenNotes() => _onTabChange(10);
  void _closeNotesWorkspace() => _onTabChange(0);
  void _onScrollNotification(ScrollNotification n) {
    // PEDIATRIA_HORIZONTAL_SUBNAV_SCROLL_AXIS_GUARD_V1_B_R0
    // O motor global do footer reage apenas a scroll vertical de conteúdo.
    // Subnavs horizontais (ex.: Pediatria) não podem alimentar navScrollingDown.
    if (n.metrics.axis != Axis.vertical) return;

    // BUILD 329 — Motor de scroll dinâmico para a bottom nav (todas as abas).
    // Threshold de 4px para ignorar micro-vibrações do overscroll iOS.
    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta ?? 0;
      if (delta > 4 && !MainShell.navScrollingDown.value) {
        MainShell.navScrollingDown.value = true; // scrolling down → encolhe nav
      } else if (delta < -4 && MainShell.navScrollingDown.value) {
        MainShell.navScrollingDown.value = false; // scrolling up  → expande nav
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
      debugPrint(
          '[BUILD334-FORENSE][TAB_RESTORE] pending=$pendingOAuthTab (fast-path initState) _tab=$_tab');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // _tab já foi inicializado pelo field initializer — forçar setState
          // para garantir que o IndexedStack reaja ao valor correto.
          final correctTab = pendingOAuthTab.clamp(0, 5);
          if (_tab != correctTab) {
            setState(() => _tab = correctTab);
            debugPrint(
                '[BUILD334-FORENSE][TAB_RESTORE] setState tab=$correctTab (field-init divergiu)');
          } else {
            debugPrint(
                '[BUILD334-FORENSE][TAB_RESTORE] tab=$_tab já correto (field-init OK)');
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
      RepaintBoundary(
        // 0 — tela inicial
        child: HomeScreenV2(
          onTabChange: _onTabChange,
          onSubTabChange: _onSubTabChange,
          openProtocol: _openProtocol,
          onOpenNotes: _onOpenNotes,
          onOpenClinicalGuide: _openClinicalGuide,
          onOpenSimulation: _openSimulation,
          onOpenVaccine: _openVaccines,
          onCheckUpdate: _forceShowUpdate,
        ),
      ),
      RepaintBoundary(
        // 1 — Rx/Proto combo
        child: _RxProtoCombo(
          subTab: _rxProtoSub,
          onSubTabChange: _onSubTabChange,
        ),
      ),
      const RepaintBoundary(child: AiScreen()), // 2
      const RepaintBoundary(child: HistoryScreen()), // 3
      const RepaintBoundary(child: ToolsScreen()), // 4
      const RepaintBoundary(
        child: ClinicalGuideScreen(),
      ), // 5 — GUIA CLÍNICO / GUÍA CLÍNICA
      RepaintBoundary(
        child: VaccinesScreen(onBack: _closeVaccines),
      ), // 6 — VACINA/VACUNA workspace interno
      const RepaintBoundary(
        child: ClinicalSimulationScreen(),
      ), // 7 — SIMULAÇÃO / SIMULACIÓN workspace interno
      // PEDIATRIA_MAIN_SHELL_FOOTER_V1_B_R0_TAB_8
      RepaintBoundary(
        child: PediatricsMainShellWorkspace(onBack: _closePediatrics),
      ), // 8 — PEDIATRIA / PEDIATRÍA workspace interno com footer global

      // LABORATORIO_SUPER_PREMIUM_MAIN_SHELL_V1_B_R0_TAB_9
      RepaintBoundary(
        child: LaboratoryMainShellWorkspace(onBack: _closeLaboratory),
      ), // 9 — LABORATORIO / LABORATÓRIO com footer global

      RepaintBoundary(
        child: _NotesAudioWorkspace(onBack: _closeNotesWorkspace),
      ), // 10 — NOTAS / ÁUDIO workspace interno

      // PACIENTES_MAIN_SHELL_FOOTER_V1_B_R3_TAB
      RepaintBoundary(
        child: InternacionMainShellWorkspace(
          onBack: _closeInternacionMainShell,
        ),
      ), // 11 — PACIENTES workspace interno com footer global

      // AVALIACAO_MAIN_SHELL_FOOTER_V1_B_R0_TAB_12
      RepaintBoundary(
        child: AvaliacaoScreen(
          embeddedInMainShell: true,
          onBack: _closeAvaliacaoMainShell,
        ),
      ), // 12 — AVALIAÇÃO FÍSICA workspace interno com footer global
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
        onHidden: () {
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
              context
                  .read<AppProvider>()
                  .resumeUsageTimer(fromVisibility: true);
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
        unawaited(
          CalculatorWebViewPrewarmService.instance.prewarm(
            lang: provider.lang,
            dark: provider.darkMode,
          ),
        );
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
      final seen = prefs.getString('last_seen_update') ?? '';
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
      if (t == 3) {
        // MEDCASES_HC_DIRECT_NOVA_ENTRY_V1_B_R2_PENDING_TAB
        HistoryScreen.requestNewWorkspace();
      }
      MainShell.pendingTab.value = -1; // reset imediato após consumir
      // BUILD 445: notifica ToolsScreen sobre visibilidade via pendingTab
      toolsScreenVisibleNotifier.value = (t == 4);
    }
  }

  @override
  void dispose() {
    MainShell.pendingTab.removeListener(_onPendingTab);
    AppProvider.postOAuthTabNotifier
        .removeListener(_onPostOAuthTab); // BUILD 315
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
        OfflineCalculatorCacheService.instance.onAppResumed();
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
    final _ = context.select<AppProvider, String>(
        (p) => p.lang); // reativa nav bar ao trocar idioma
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
  Widget _buildDesktopShell(
      BuildContext context, bool dark, AppProvider p, double width) {
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFFFFFFF);
    final divColor = dark ? const Color(0xFF2D3340) : const Color(0xFFE5E7EB);
    final stackIdx = _tab.clamp(0, _staticScreens.length - 1);

    // Split-View: iPad 13" / desktop largo quando na tela de IA (tab 2)
    // Exibe HomeDashboard (40%) + AiScreen (60%) simultaneamente.
    // Em outras tabs o IndexedStack normal garante a tela selecionada.
    final bool showPersistentAiSplit = width >= 1024;
    final int leftPaneIndex = _tab == 2 ? _lastNonAiWorkspaceTab : stackIdx;

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
                currentRxSubTab: _rxProtoSub,
                dark: dark,
                p: p,
                onOpenDrugs: () {
                  _RxProtoCombo.externalSubTab.value = 1;
                  _onTabChange(1);
                },
                // Volta para Home (tab 0) e scrolla para o topo
                onLogoTap: () => _onTabChange(0),
                onTabChange: _onTabChange,
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
                    child: showPersistentAiSplit
                        // ── SPLIT-VIEW: HomeDashboard 40% | AiScreen 60% ──────
                        ? _buildSplitView(dark, divColor, leftPaneIndex, p.lang)
                        // ── IndexedStack normal para todas as outras tabs ──────
                        : HomeCardWorkspaceTransition(
                            transitionKey: stackIdx,
                            child: RepaintBoundary(
                              child: IndexedStack(
                                index: stackIdx,
                                children: _staticScreens,
                              ),
                            ),
                          ),
                  ),
                  // Banner de auto-update
                  ValueListenableBuilder<bool>(
                    valueListenable: UpdateService.swUpdateAvailable,
                    builder: (_, hasUpdate, __) => hasUpdate
                        ? const _UpdateBanner()
                        : const SizedBox.shrink(),
                  ),
                  _LegalBar(
                    dark: dark,
                    liquidGlass: _tab == 0,
                  ),
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
  Widget _buildSplitView(
      bool dark, Color divColor, int leftPaneIndex, String lang) {
    return Row(
      children: [
        // ── Painel esquerdo: HomeDashboard (40%) ──────────────────────────────
        Flexible(
          flex: 40,
          // MEDCASES_WEB_40_60_LEFT_PANE_NAV_CONTAINMENT_V1_B_R1
          // Desktop Web >=1024: the 40% workspace owns an isolated Navigator.
          // Descendant push/search/sheet routes remain inside this pane and can
          // never replace the persistent 60% AiScreen on the right.
          child: Column(
            children: [
              // MEDCASES_HOME_WEB_40_PANE_CANONICAL_TOPBAR_RESTORE_V1_B_R0
              // Restore the same 48 px canonical Home topbar used by the
              // mobile shell, only while the persistent 40% pane owns Home.
              if (leftPaneIndex == 0)
                SizedBox(
                  height: 48,
                  child: _MobileAppBar(
                    dark: dark,
                    currentTab: 0,
                    lang: lang,
                    isHome: true,
                    onLogoTap: () {},
                  ),
                ),
              Expanded(
                child: ClipRect(
                  // MEDCASES_HOME_CARD_OPEN_TRANSITION_UNIFICATION_WEB_MOBILE_V1_B_R3
                  child: HomeCardWorkspaceTransition(
                    transitionKey: leftPaneIndex,
                    child: Navigator(
                      key: ValueKey<String>('web-left-pane-$leftPaneIndex'),
                      onGenerateRoute: (settings) => MaterialPageRoute<void>(
                        settings: settings,
                        builder: (_) => _staticScreens[leftPaneIndex],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
    final isHome = _tab == 0;
    final isAiTab = _tab == 2;

    return Scaffold(
      backgroundColor: bg,
      extendBodyBehindAppBar: isHome,
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
                  onLogoTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => _tab = 0);
                  },
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
        onNotification: (n) {
          _onScrollNotification(n);
          return false;
        },
        child: MediaQuery.removePadding(
          context: context,
          removeTop: !isHome && _tab != 11 && _tab != 12,
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
                  // HISTORY_CLINICAL_V1_C_R14_R4_EDITOR_TOP_INSET_LIGHT_CONTINUITY
                  ValueListenableBuilder<bool>(
                    valueListenable: HistoryScreen.editorActive,
                    child: Padding(
                      padding: EdgeInsets.only(
                        // LABORATORIO_R8_HOME_TOP_INSET_OWNER
                        top: (isHome ||
                                _tab == 2 ||
                                _tab == 4 ||
                                _tab == 5 ||
                                _tab == 8 ||
                                _tab == 9 ||
                                _tab == 10 ||
                                _tab == 11 ||
                                _tab == 12)
                            ? 0
                            : MediaQuery.of(context).padding.top,
                      ),
                      child: HomeCardWorkspaceTransition(
                        transitionKey: stackIdx,
                        child: IndexedStack(
                          index: stackIdx,
                          children: _staticScreens,
                        ),
                      ),
                    ),
                    builder: (_, historyEditorOpen, child) => ColoredBox(
                      color: dark
                          ? const Color(0xFF1A1D23)
                          : historyEditorOpen
                              ? const Color(0xFFECF1F3)
                              : bg,
                      child: child!,
                    ),
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
                        // LABORATORIO_R8_KEYBOARD_FOOTER_VISIBILITY
                        // MEDCASES_FERRAMENTAS_KEYBOARD_VIEWPORT_SCROLL_PARITY_V1_B_R0
                        final toolsKeyboardOpen = _tab == 4 &&
                            MediaQuery.viewInsetsOf(scaffoldBodyCtx).bottom > 0;
                        final labKeyboardOpen = _tab == 9 &&
                            MediaQuery.viewInsetsOf(scaffoldBodyCtx).bottom > 0;
                        final patientKeyboardOpen = _tab == 11 &&
                            MediaQuery.viewInsetsOf(scaffoldBodyCtx).bottom > 0;
                        final assessmentKeyboardOpen = _tab == 12 &&
                            MediaQuery.viewInsetsOf(scaffoldBodyCtx).bottom > 0;
                        final hidden = editorOpen ||
                            kbOpen ||
                            toolsKeyboardOpen ||
                            labKeyboardOpen ||
                            patientKeyboardOpen ||
                            assessmentKeyboardOpen;
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
                          onMenuTap: () =>
                              Scaffold.of(scaffoldBodyCtx).openEndDrawer(),
                        );
                      },
                    ),
                  ),
                ],
              ), // end Stack
            ), // end SizedBox.expand
          ), // end Builder
        ), // end MediaQuery.removePadding
      ), // end NotificationListener
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
    final p = context.read<AppProvider>();
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

    // 5. Confirma visualmente após a árvore estabilizar.
    // O reset acima reconstrói o Scaffold/AiScreen no mesmo frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null || !messenger.mounted) return;

      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            // MEDCASES_AI_NEW_CHAT_PREMIUM_TOAST_V1_B_R0
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 2600),
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 84),
            padding: EdgeInsets.zero,
            dismissDirection: DismissDirection.down,
            content: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: p.darkMode
                    ? const Color(0xFF252930)
                    : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: p.darkMode
                      ? const Color(0xFF374151)
                      : const Color(0xFFE7EBEF),
                  width: 0.6,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 34,
                    decoration: BoxDecoration(
                      color: p.darkMode
                          ? const Color(0xFF00C781)
                          : const Color(0xFF008F66),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 19,
                    color: p.darkMode
                        ? const Color(0xFF00C781)
                        : const Color(0xFF008F66),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEs
                              ? 'Nueva consulta iniciada'
                              : 'Nova consulta iniciada',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: p.darkMode
                                ? Colors.white
                                : const Color(0xFF05070A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isEs
                              ? 'La consulta anterior quedó guardada en el historial.'
                              : 'A consulta anterior foi salva no histórico.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.2,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                            color: p.darkMode
                                ? const Color(0xFFA7B0BA)
                                : const Color(0xFF59636E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    });
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

class _IaDynamicFloat extends StatefulWidget {
  const _IaDynamicFloat({
    required this.child,
  });

  final Widget child;

  @override
  State<_IaDynamicFloat> createState() => _IaDynamicFloatState();
}

class _IaDynamicFloatState extends State<_IaDynamicFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _lift;
  late final Animation<double> _tilt;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);

    _lift = Tween<double>(
      begin: 0,
      end: -4,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _tilt = Tween<double>(
      begin: -0.5235987755982988,
      end: 0.5235987755982988,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          2 + _lift.value,
        ),
        child: Transform.rotate(
          angle: _tilt.value,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }
}

class _FloatingFooter extends StatefulWidget {
  final bool hidden;
  final bool dark;
  final int currentTab;
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
  static const _medcasesGreen = Color(0xFF0D6B57);
  // M+ usa branco em repouso e verde enquanto pressionado.
  static const _menuLightGreen = Color(0xFF0D6B57);

  // Alturas da barra: normal e encolhida
  static const _barHeightFull = 50.0;
  static const _barHeightShrunk = 38.0;

  bool _shrunk = false; // reflexo local do navScrollingDown
  bool _menuPressed = false;

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
    // MEDCASES_GLOBAL_ACTION_BAR_TRUE_LIQUID_GLASS_V1_B_R1
    // Material óptico premium: preserva leitura do fundo, acrescenta refração
    // visual por blur, tint controlado e brilho especular sem neon/overblur.
    final navBg = widget.dark
        ? const Color(0xFF161B22).withValues(alpha: 0.58)
        : Colors.white.withValues(alpha: 0.56);
    final liquidTop = widget.dark
        ? Colors.white.withValues(alpha: 0.11)
        : Colors.white.withValues(alpha: 0.52);
    final liquidMid = widget.dark
        ? Colors.white.withValues(alpha: 0.035)
        : Colors.white.withValues(alpha: 0.16);
    final liquidBorder = widget.dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.82);
    final liquidSpecular = widget.dark
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.92);

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
      bottom: 0,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Camada de profundidade fora do clip: sombra ambiente real.
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeInOutCubic,
                        height: barHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: widget.dark ? 0.32 : 0.12,
                              ),
                              blurRadius: 26,
                              spreadRadius: -4,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                      ),
                      ClipRRect(
                        // PERF-FIX: clip const e apenas um BackdropFilter.
                        borderRadius:
                            const BorderRadius.all(Radius.circular(32)),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOutCubic,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: navBg,
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: liquidBorder,
                                width: 0.8,
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  liquidTop,
                                  liquidMid,
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.36, 1.0],
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Highlight especular superior fino: assinatura
                                // Liquid Glass sem glow e sem gradiente pesado.
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    height: 0.8,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(99),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          liquidSpecular,
                                          Colors.transparent,
                                        ],
                                        stops: const [0.0, 0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child:
                            widget.isAiActive ? _buildAiRow() : _buildNavRow(),
                      ),
                    ],
                  ),
                ),
              ), // RepaintBoundary

              // ── Base de vidro até a borda física da tela ────────────────
              _LegalGlassShelf(
                dark: widget.dark,
                safeBottom: safeBottom,
                homeLiquidGlass: widget.currentTab == 0,
                child: _LegalBar(dark: widget.dark, insideSafeArea: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Row padrão (abas Home / Ferramentas / etc) ─────────────────────────────
  // [Início | IA | Menu] — Biblioteca removida; 3 ações independentes
  Widget _buildNavRow() => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. INÍCIO — home_outlined inativo / home_rounded (filled) ativo
          Expanded(
              child: _NavItem(
            icon: Icons.home_outlined,
            iconActive: Icons.home_rounded,
            label: widget.lang == 'es' ? 'Inicio' : 'Início',
            isActive: widget.currentTab == 0,
            dark: widget.dark,
            shrunk: _shrunk,
            onTap: () => widget.onTabChange(0),
          )),

          // 2. IA — círculo gradiente + label "IA"
          Expanded(
              child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onFabTap,
            onDoubleTap: widget.onFabDoubleTap,
            child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _IaDynamicFloat(
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: 54,
                          height: 31.5,
                          child: OverflowBox(
                            alignment: Alignment.bottomCenter,
                            minWidth: 54,
                            maxWidth: 54,
                            minHeight: 54,
                            maxHeight: 54,
                            child: SvgPicture.asset(
                              'assets/icons/home_v2/ic_ia.svg',
                              width: 54,
                              height: 54,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _shrunk ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text('IA',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: widget.isAiActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: widget.isAiActive
                                ? (widget.dark
                                    ? _medcasesGreen
                                    : _menuLightGreen)
                                : (widget.dark
                                    ? Colors.white
                                    : const Color(0xFF4B5563)),
                            height: 1.0,
                          )),
                    ),
                  ],
                )),
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
          Expanded(
              child: _NavItem(
            icon: Icons.home_outlined,
            iconActive: Icons.home_rounded,
            label: widget.lang == 'es' ? 'Inicio' : 'Início',
            isActive: false, // nunca ativo quando estamos na aba IA
            dark: widget.dark, shrunk: _shrunk,
            onTap: () => widget.onTabChange(0),
          )),

          // 2. HISTÓRICO — abre histórico de sessões do chat
          Expanded(
              child: ValueListenableBuilder<VoidCallback?>(
            valueListenable: AiScreen.openHistoryCallback,
            builder: (_, callback, __) => Selector<AppProvider, int>(
              selector: (_, provider) =>
                  provider.visibleAiSessionSummaries.length,
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
                          Icon(Icons.history_rounded,
                              size: 22,
                              // Cinza escuro sólido no light — contraste premium
                              color: widget.dark
                                  ? Colors.white
                                  : const Color(0xFF4B5563)),
                          if (count > 0)
                            Positioned(
                              top: -4,
                              right: -6,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFC5A365),
                                ),
                                child: Center(
                                  child: Text('$count',
                                      style: const TextStyle(
                                        fontSize: 7,
                                        fontWeight: FontWeight.w900,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.0, fontWeight: FontWeight.w400,
                          // Cinza escuro sólido no light — contraste premium estilo Instagram
                          color: widget.dark
                              ? Colors.white
                              : const Color(0xFF4B5563),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),

          // 3. NOVO CHAT — branco no dark, cinza oficial no light
          Expanded(
              child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onFabDoubleTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: widget.dark ? Colors.white : const Color(0xFF4B5563),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _shrunk ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    widget.lang == 'es' ? 'Nuevo' : 'Novo',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.w500,
                      color:
                          widget.dark ? Colors.white : const Color(0xFF4B5563),
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
  Widget _buildMenuButton() {
    final menuColor = _menuPressed
        ? (widget.dark ? const Color(0xFF009C3B) : const Color(0xFF009C3B))
        : (widget.dark ? Colors.white : const Color(0xFF4B5563));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (!_menuPressed) {
          setState(() {
            _menuPressed = true;
          });
        }
      },
      onTapUp: (_) {
        if (_menuPressed) {
          setState(() {
            _menuPressed = false;
          });
        }
      },
      onTapCancel: () {
        if (_menuPressed) {
          setState(() {
            _menuPressed = false;
          });
        }
      },
      onTap: widget.onMenuTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Icon(
              Icons.menu_rounded,
              size: 24,
              color: menuColor,
            ),
          ),
          AnimatedOpacity(
            opacity: _shrunk ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Text(
              widget.lang == 'es' ? 'Menú' : 'Menu',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.0,
                fontWeight: FontWeight.w500,
                color: menuColor,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item individual da bottom nav ─────────────────────────────────────────────
// BUILD 331 LIGHT PREMIUM: paleta estilo Instagram no modo claro.
//   • Inativo light: cinza escuro sólido #4B5563 (legível, sem apagado)
//   • Ativo   light: Colors.black87 — preto absoluto (ênfase premium)
//   • Ativo   dark : Color(0xFF0D6B57) — accent canônico MedCases
// iconActive: versão filled/bold do ícone para estado ativo — alternância
// visual sofisticada sem precisar de underline ou círculo.
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData? iconActive; // filled/bold variant for active state
  final String label;
  final bool isActive;
  final bool dark;
  final bool shrunk; // true → barra encolhida → label some
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
    // Dark: branco em repouso e verde no item selecionado.
    // Light: cinza-escuro em repouso e verde no item selecionado.
    final activeColor =
        dark ? const Color(0xFF009C3B) : const Color(0xFF009C3B);
    final inactiveColor = dark ? Colors.white : const Color(0xFF4B5563);
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
  // MEDCASES_GLOBAL_DARK_THEME_SECOND_BRAND_V2_B_R1_TOPBAR
  final bool dark;
  final int currentTab;
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
    // MEDCASES_HOME_TOPBAR_TRUE_LIQUID_GLASS_V1_B_R0
    // Mesmo idioma óptico do dock global, adaptado ao topbar edge-to-edge.
    final glassColor = dark
        ? const Color(0xFF161B22).withValues(alpha: 0.58)
        : Colors.white.withValues(alpha: 0.56);
    final liquidTop = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.46);
    final liquidMid = dark
        ? Colors.white.withValues(alpha: 0.025)
        : Colors.white.withValues(alpha: 0.12);
    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.78);
    final liquidSpecular = dark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.86);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.16 : 0.07),
            blurRadius: 14,
            spreadRadius: -8,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  liquidTop,
                  liquidMid,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.7),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 0.7,
                  child: Container(
                    height: 0.7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          liquidSpecular,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                SafeArea(
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
                                  TextSpan(
                                    text: 'MEDCASES ',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: dark
                                          ? Colors.white
                                          : const Color(0xFF05070A),
                                    ),
                                  ),
                                  TextSpan(
                                    text: currentTab == _kAiTab ? 'IA' : 'PRO',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: currentTab == _kAiTab
                                          ? (dark
                                              ? const Color(0xFF009C3B)
                                              : const Color(0xFF009C3B))
                                          : (dark
                                              ? const Color(0xFF009C3B)
                                              : const Color(0xFF009C3B)),
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
  // MEDCASES_WEB_HOME_CLEAN_ICON_SIDEBAR_GUIDES_5PX_TOPBAR_V1_B_R0
  // Desktop rail: profile + Home fixed, icon-only functions in the middle,
  // Menu fixed at the bottom. Labels live only in tooltips.
  final int currentTab;
  final int currentRxSubTab;
  final bool dark;
  final AppProvider p;
  final ValueChanged<int> onTabChange;
  final VoidCallback onOpenDrugs;
  final VoidCallback onOpenDrawer;
  final VoidCallback onLogoTap;

  const _DesktopSidebar({
    required this.currentTab,
    required this.currentRxSubTab,
    required this.dark,
    required this.p,
    required this.onTabChange,
    required this.onOpenDrugs,
    required this.onOpenDrawer,
    required this.onLogoTap,
  });

  @override
  Widget build(BuildContext context) {
    final navBg = dark
        ? const Color(0xFF161B22).withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.40);
    final liquidTop = dark
        ? Colors.white.withValues(alpha: 0.075)
        : Colors.white.withValues(alpha: 0.36);
    final liquidBorder = dark
        ? Colors.white.withValues(alpha: 0.085)
        : Colors.white.withValues(alpha: 0.62);
    final liquidSpecular = dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.72);
    final isEs = p.lang == 'es';

    Widget nav({
      required IconData icon,
      required String tooltip,
      required bool active,
      required VoidCallback onTap,
      IconData? iconActive,
    }) =>
        _DesktopSidebarIconButton(
          icon: icon,
          iconActive: iconActive,
          tooltip: tooltip,
          active: active,
          dark: dark,
          onTap: onTap,
        );

    return RepaintBoundary(
      child: SizedBox(
        width: 72,
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: navBg,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    liquidTop,
                    Colors.transparent,
                  ],
                ),
                border: Border(
                  right: BorderSide(
                    color: liquidBorder,
                    width: 0.6,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 0.7,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            liquidSpecular,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      const SizedBox(height: 10),

                      // Fixed profile.
                      _DesktopSidebarProfileButton(
                        p: p,
                        dark: dark,
                      ),

                      const SizedBox(height: 8),

                      // Fixed Home.
                      nav(
                        icon: Icons.home_outlined,
                        iconActive: Icons.home_rounded,
                        tooltip: isEs ? 'Inicio' : 'Início',
                        active: currentTab == 0,
                        onTap: onLogoTap,
                      ),

                      const SizedBox(height: 6),

                      // Only the center is vertically scrollable.
                      Expanded(
                        child: SingleChildScrollView(
                          primary: false,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            children: [
                              nav(
                                icon: Icons.psychology_rounded,
                                tooltip: 'IA',
                                active: currentTab == 2,
                                onTap: () => onTabChange(2),
                              ),
                              nav(
                                icon: Icons.medication_rounded,
                                tooltip: 'Fármacos',
                                active: currentTab == 1 && currentRxSubTab == 1,
                                onTap: onOpenDrugs,
                              ),
                              nav(
                                icon: Icons.folder_shared_rounded,
                                tooltip: 'H. Clínica',
                                active: currentTab == 3,
                                onTap: () => onTabChange(3),
                              ),
                              nav(
                                icon: Icons.calculate_rounded,
                                tooltip: isEs ? 'Herramientas' : 'Ferramentas',
                                active: currentTab == 4,
                                onTap: () => onTabChange(4),
                              ),
                              nav(
                                icon: Icons.menu_book_rounded,
                                tooltip: isEs ? 'Guías' : 'Guias',
                                active: currentTab == 5,
                                onTap: () => onTabChange(5),
                              ),
                              nav(
                                icon: Icons.medical_services_rounded,
                                tooltip: isEs ? 'Vacunas' : 'Vacinas',
                                active: currentTab == 6,
                                onTap: () => onTabChange(6),
                              ),
                              nav(
                                icon: Icons.play_circle_outline_rounded,
                                tooltip: isEs ? 'Simulación' : 'Simulação',
                                active: currentTab == 7,
                                onTap: () => onTabChange(7),
                              ),
                              nav(
                                icon: Icons.child_care_rounded,
                                tooltip: isEs ? 'Pediatría' : 'Pediatria',
                                active: currentTab == 8,
                                onTap: () => onTabChange(8),
                              ),
                              nav(
                                icon: Icons.science_rounded,
                                tooltip: isEs ? 'Laboratorio' : 'Laboratório',
                                active: currentTab == 9,
                                onTap: () => onTabChange(9),
                              ),
                              nav(
                                icon: Icons.edit_note_rounded,
                                tooltip: 'Notas',
                                active: currentTab == 10,
                                onTap: () => onTabChange(10),
                              ),
                              nav(
                                icon: Icons.groups_rounded,
                                tooltip: 'Pacientes',
                                active: currentTab == 11,
                                onTap: () => onTabChange(11),
                              ),
                              nav(
                                icon: Icons.fitness_center_rounded,
                                tooltip: isEs ? 'Evaluación' : 'Avaliação',
                                active: currentTab == 12,
                                onTap: () => onTabChange(12),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Fixed bottom Menu.
                      _DesktopSidebarIconButton(
                        icon: Icons.menu_rounded,
                        tooltip: isEs ? 'Menú' : 'Menu',
                        active: false,
                        dark: dark,
                        onTap: onOpenDrawer,
                      ),

                      const SizedBox(height: 10),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebarProfileButton extends StatefulWidget {
  final AppProvider p;
  final bool dark;

  const _DesktopSidebarProfileButton({
    required this.p,
    required this.dark,
  });

  @override
  State<_DesktopSidebarProfileButton> createState() =>
      _DesktopSidebarProfileButtonState();
}

class _DesktopSidebarProfileButtonState
    extends State<_DesktopSidebarProfileButton> {
  String? _avatarBase64;

  String get _avatarPrefsKey {
    final uid = widget.p.currentUser?.uid.trim();
    return 'medcases_profile_avatar_${(uid != null && uid.isNotEmpty) ? uid : 'local'}';
  }

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_avatarPrefsKey);
      if (mounted) setState(() => _avatarBase64 = encoded);
    } catch (_) {
      if (mounted) setState(() => _avatarBase64 = null);
    }
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileAccountScreen(p: widget.p),
      ),
    );
    if (mounted) await _loadAvatar();
  }

  Widget _fallback(Color bg, Color border) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(color: border, width: 0.8),
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 21,
          color: Color(0xFF009C3B),
        ),
      );

  Widget _avatar() {
    final border = widget.dark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.black.withValues(alpha: 0.08);
    final fallbackBg = widget.dark
        ? Colors.white.withValues(alpha: 0.045)
        : Colors.black.withValues(alpha: 0.025);

    final encoded = _avatarBase64;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final bytes = base64Decode(encoded);
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 0.8),
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _fallback(fallbackBg, border),
            ),
          ),
        );
      } catch (_) {
        return _fallback(fallbackBg, border);
      }
    }
    return _fallback(fallbackBg, border);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.p.userName.isNotEmpty ? widget.p.userName : 'Perfil',
      waitDuration: const Duration(milliseconds: 350),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _openProfile,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: _avatar(),
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebarIconButton extends StatelessWidget {
  final IconData icon;
  final IconData? iconActive;
  final String tooltip;
  final bool active;
  final bool dark;
  final VoidCallback onTap;

  const _DesktopSidebarIconButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.dark,
    required this.onTap,
    this.iconActive,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF009C3B);
    final inactiveColor =
        dark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF4B5563);
    final resolvedIcon = active && iconActive != null ? iconActive! : icon;

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 350),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: active
                    ? activeColor.withValues(alpha: dark ? 0.13 : 0.10)
                    : Colors.transparent,
                border: active
                    ? Border.all(
                        color: activeColor.withValues(alpha: 0.18),
                        width: 0.7,
                      )
                    : null,
              ),
              child: Icon(
                resolvedIcon,
                size: 22,
                color: active ? activeColor : inactiveColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RxProtoCombo extends StatefulWidget {
  final int subTab;
  final ValueChanged<int> onSubTabChange;

  // Desktop sidebar direct-entry bridge for the only exposed sub-function:
  // 1=Fármacos.
  static final ValueNotifier<int> externalSubTab = ValueNotifier<int>(0);

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
    _RxProtoCombo.externalSubTab.value = _sub;
    _RxProtoCombo.externalSubTab.addListener(_onExternalSubTab);
  }

  @override
  void dispose() {
    _RxProtoCombo.externalSubTab.removeListener(_onExternalSubTab);
    super.dispose();
  }

  void _onExternalSubTab() {
    final i = _RxProtoCombo.externalSubTab.value;
    if (i < 0 || i > 3 || i == _sub) return;
    setState(() => _sub = i);
    widget.onSubTabChange(i);
  }

  void _select(int i) {
    if (_sub == i) return;
    setState(() => _sub = i);
    _RxProtoCombo.externalSubTab.value = i;
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
    final activeColor =
        dark ? const Color(0xFFFFE8A6) : const Color(0xFF0F1116);
    final inactiveColor =
        dark ? Colors.white.withOpacity(0.30) : const Color(0xFFB8BEC4);
    final activeBg = dark
        ? const Color(0xFF2D3340) // kBorderSoft — active highlight
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
  const _MiniContextBar(
      {required this.tab, required this.dark, required this.onHome});

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
    final bg = dark ? const Color(0xFF0F2A1C) : const Color(0xFF0F3D2E);
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

class _LegalGlassShelf extends StatelessWidget {
  final bool dark;
  final double safeBottom;
  final bool homeLiquidGlass;
  final Widget child;

  const _LegalGlassShelf({
    required this.dark,
    required this.safeBottom,
    this.homeLiquidGlass = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Demais abas preservam byte-semanticamente o material glass anterior.
    if (!homeLiquidGlass) {
      final glassColor = dark
          ? const Color(0xFF252930).withOpacity(0.70)
          : Colors.white.withOpacity(0.70);

      final borderColor =
          dark ? const Color(0xFF374151) : const Color(0xFFDDE4EA);

      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(bottom: safeBottom),
            decoration: BoxDecoration(
              color: glassColor,
              border: Border(
                top: BorderSide(
                  color: borderColor,
                  width: 0.7,
                ),
              ),
            ),
            child: child,
          ),
        ),
      );
    }

    // MEDCASES_HOME_DISCLAIMER_TRUE_LIQUID_GLASS_V1_B_R1
    // Mesmo idioma óptico homologado na Home: blur 16, tint translúcido,
    // hairline e brilho especular fino, adaptados à borda inferior.
    final glassColor = dark
        ? const Color(0xFF161B22).withValues(alpha: 0.58)
        : Colors.white.withValues(alpha: 0.56);
    final liquidTop = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.46);
    final liquidMid = dark
        ? Colors.white.withValues(alpha: 0.025)
        : Colors.white.withValues(alpha: 0.12);
    final borderColor = dark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.78);
    final liquidSpecular = dark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.86);

    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.16 : 0.07),
            blurRadius: 14,
            spreadRadius: -8,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.only(bottom: safeBottom),
            decoration: BoxDecoration(
              color: glassColor,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  liquidTop,
                  liquidMid,
                  Colors.transparent,
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
              border: Border(
                top: BorderSide(
                  color: borderColor,
                  width: 0.7,
                ),
              ),
            ),
            child: Stack(
              children: [
                child,
                Positioned(
                  left: 24,
                  right: 24,
                  top: 0.7,
                  child: Container(
                    height: 0.7,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          liquidSpecular,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
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

// ── Barra legal ───────────────────────────────────────────────────────────────
class _LegalBar extends StatelessWidget {
  final bool dark;

  /// true quando o widget já está dentro de um SafeArea pai (ex.: bottom nav).
  /// Evita duplo recuo — SafeArea aninhado sem parâmetro correto some do layout.
  final bool insideSafeArea;

  /// Variante visual exclusiva da Home em desktop/tablet.
  final bool liquidGlass;

  const _LegalBar({
    required this.dark,
    this.insideSafeArea = false,
    this.liquidGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEs = context.select<AppProvider, bool>((p) => p.lang == 'es');

    // Apple 1.4.1 — contraste sólido e texto permanentemente visível.
    final textColor =
        dark ? Colors.white.withOpacity(0.88) : const Color(0xFF4B5563);

    final disclaimer = isEs
        ? 'Herramienta educativa de apoyo clínico. La decisión y verificación de dosis son responsabilidad exclusiva del médico asistente.'
        : 'Ferramenta educacional de apoio clínico. A decisão e verificação de doses são de responsabilidade exclusiva do médico assistente.';

    final centeredContent = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.info_outline_rounded,
                size: 10,
                color: textColor.withOpacity(0.68),
              ),
            ),
          ),
          Expanded(
            child: Text(
              disclaimer,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color: textColor,
                height: 1.28,
                letterSpacing: 0,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Compensa a largura do ícone para centralização geométrica real.
          const SizedBox(width: 18),
        ],
      ),
    );

    // Mobile: fundo e proteção inferior pertencem à _LegalGlassShelf.
    if (insideSafeArea) {
      return SizedBox(
        width: double.infinity,
        child: centeredContent,
      );
    }

    // Desktop/tablet: faixa tradicional e SafeArea próprias.
    final standaloneBg =
        dark ? const Color(0xFF1A1D23) : const Color(0xFFF0F2F4);

    final standaloneBorder =
        dark ? const Color(0xFF374151) : const Color(0xFFDDE1E6);

    if (!liquidGlass) {
      return SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: standaloneBg,
            border: Border(
              top: BorderSide(
                color: standaloneBorder,
                width: 0.5,
              ),
            ),
          ),
          child: centeredContent,
        ),
      );
    }

    final liquidBg = dark
        ? const Color(0xFF161B22).withValues(alpha: 0.58)
        : Colors.white.withValues(alpha: 0.56);
    final liquidTop = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.46);
    final liquidMid = dark
        ? Colors.white.withValues(alpha: 0.025)
        : Colors.white.withValues(alpha: 0.12);
    final liquidBorder = dark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.white.withValues(alpha: 0.78);

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.16 : 0.07),
              blurRadius: 14,
              spreadRadius: -8,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: liquidBg,
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    liquidTop,
                    liquidMid,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.42, 1.0],
                ),
                border: Border(
                  top: BorderSide(
                    color: liquidBorder,
                    width: 0.7,
                  ),
                ),
              ),
              child: centeredContent,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Task 9: URLs de Privacy Policy e Terms of Use (Guideline 5.1) ────────────
const String _kPrivacyUrl =
    'https://www.promedcases.com/politica-de-privacidade';
const String _kTermsUrl = 'https://www.promedcases.com/termos-de-uso';
const String _kSiteUrl = 'https://promedcases.com/';

// ── Drawer lateral — redesenhado (v2) ─────────────────────────────────────────
class _AppDrawer extends StatefulWidget {
  final AppProvider p;
  const _AppDrawer({required this.p});

  @override
  State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer> {
  // MEDCASES_MENU_LATERAL_SETTINGS_SHELL_UI_V2_B_R1
  AppProvider get p => widget.p;

  void _close(BuildContext context) => Navigator.of(context).pop();

  // SIDEBAR_PROFILE_V1_B_R0_R1 — avatar local por usuário.
  // Não altera UserModel/Firestore. A foto escolhida fica somente neste
  // dispositivo, em SharedPreferences, usando bytes comprimidos pelo picker.
  String? _avatarBase64;

  String get _avatarPrefsKey {
    final uid = p.currentUser?.uid.trim();
    return 'medcases_profile_avatar_${(uid != null && uid.isNotEmpty) ? uid : 'local'}';
  }

  @override
  void initState() {
    super.initState();
    _loadLocalAvatar();
  }

  Future<void> _loadLocalAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_avatarPrefsKey);
      if (mounted) setState(() => _avatarBase64 = saved);
    } catch (_) {
      // Avatar opcional; falha local nunca bloqueia o Drawer.
    }
  }

  Future<void> _pickLocalAvatar() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 95,
      );
      if (file == null || !mounted) return;

      final isEs = context.read<AppProvider>().lang == 'es';
      final cropped = await ImageCropper().cropImage(
        sourcePath: file.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 900,
        maxHeight: 900,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar foto',
            toolbarColor: const Color(0xFF1A1D23),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFF0D6B57),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Ajustar foto',
            doneButtonTitle: isEs ? 'Listo' : 'Concluir',
            cancelButtonTitle: 'Cancelar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 520),
          ),
        ],
      );
      if (cropped == null) return;

      final bytes = await cropped.readAsBytes();
      if (bytes.isEmpty) return;
      final encoded = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarPrefsKey, encoded);

      if (!mounted) return;
      setState(() => _avatarBase64 = encoded);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<AppProvider>().lang == 'es'
                ? 'No fue posible editar la foto.'
                : 'Não foi possível editar a foto.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeLocalAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_avatarPrefsKey);
      if (mounted) setState(() => _avatarBase64 = null);
    } catch (_) {}
  }

  Future<void> _showAvatarActions(BuildContext context) async {
    final dark = p.darkMode;
    final isEs = p.lang == 'es';
    final bg = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: bg,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF0D6B57),
                ),
                title: Text(
                  isEs ? 'Elegir foto' : 'Escolher foto',
                  style: TextStyle(
                    color: primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  isEs
                      ? 'Se guarda solo en este dispositivo'
                      : 'Salva apenas neste dispositivo',
                  style: TextStyle(
                    color: secondary,
                    fontSize: 11,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickLocalAvatar();
                },
              ),
              if (_avatarBase64 != null && _avatarBase64!.isNotEmpty) ...[
                Divider(height: 1, color: divider),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFCC3333),
                  ),
                  title: Text(
                    isEs ? 'Quitar foto' : 'Remover foto',
                    style: const TextStyle(
                      color: Color(0xFFCC3333),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removeLocalAvatar();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialog de eliminação de conta ────────────────────────────────────────
  // ── Task 8 — Exclusão de Conta Obrigatória (Apple Guideline 5.1.1(v)) ─────
  // Diálogo em 2 etapas:
  //   Etapa 1: aviso + digitação de "EXCLUIR" para confirmação
  //   Etapa 2: campo de senha (necessário para re-autenticação iOS/Android)
  // Chama AuthService.deleteAccount() que apaga: subcoleções Firestore,
  // documento users/{uid}, credencial Firebase Auth e sessão local.
  Future<void> _showDeleteAccountDialog(
      BuildContext context, AppProvider p) async {
    final isEs = p.lang == 'es';
    final dark = p.darkMode;
    final uid = p.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    // ── Strings bilíngues ─────────────────────────────────────────────────
    final titleT = isEs ? 'Eliminar cuenta' : 'Excluir minha conta';
    final body1 = isEs
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
    final step1Label = isEs
        ? 'Para continuar, escribe EXCLUIR a continuación:'
        : 'Para continuar, digite EXCLUIR abaixo:';
    final step2Title = isEs ? 'Confirma tu contraseña' : 'Confirme sua senha';
    final step2Label = isEs ? 'Contraseña actual' : 'Senha atual';
    final step2Hint = isEs
        ? 'Ingresa tu contraseña para confirmar'
        : 'Digite sua senha para confirmar';
    final cancelT = isEs ? 'Cancelar' : 'Cancelar';
    final continueT = isEs ? 'Continuar' : 'Continuar';
    final confirmT = isEs ? 'Eliminar mi cuenta' : 'Excluir minha conta';
    final wordError = isEs
        ? 'Escribe EXCLUIR para continuar'
        : 'Digite EXCLUIR para continuar';

    final confirmCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? confirmErr;
    String? passErr;
    bool step2 = false; // false = etapa 1 (palavra), true = etapa 2 (senha)
    bool loading = false;
    bool passObscure = true;

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
              setS(() => passErr =
                  isEs ? 'Contraseña obligatoria' : 'Senha obrigatória');
              return;
            }
            setS(() {
              loading = true;
              passErr = null;
            });
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
            if (context.mounted)
              Navigator.of(context, rootNavigator: true).pop();

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
                    (isEs
                        ? 'Error al eliminar la cuenta.'
                        : 'Erro ao excluir conta.')),
                backgroundColor: const Color(0xFFCC3333),
                duration: const Duration(seconds: 4),
              ));
            }
          }

          return AlertDialog(
            backgroundColor: dark ? const Color(0xFF252930) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                child: Text(titleT,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFCC3333))),
              ),
            ]),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!step2) ...[
                    // ── Etapa 1: aviso + palavra ──────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC3333).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFCC3333).withOpacity(0.25)),
                      ),
                      child: Text(body1,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.6,
                            color:
                                dark ? Colors.white70 : const Color(0xFF333344),
                          )),
                    ),
                    const SizedBox(height: 16),
                    Text(step1Label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              dark ? Colors.white60 : const Color(0xFF555555),
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
                          borderSide:
                              const BorderSide(color: Color(0xFFCC3333)),
                        ),
                      ),
                      onChanged: (_) {
                        if (confirmErr != null) {
                          setS(() => confirmErr = null);
                        }
                      },
                    ),
                  ] else ...[
                    // ── Etapa 2: confirmação de senha (nativo) ─
                    Text(step2Title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: dark ? Colors.white : const Color(0xFF222222),
                        )),
                    const SizedBox(height: 6),
                    Text(step2Label,
                        style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white60 : Colors.grey[600],
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
                          icon: Icon(
                              passObscure
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
                          width: 18,
                          height: 18,
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

    final result =
        await AuthService.deleteAccount(uid: uid, password: password);

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
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final bg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final textCol = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subCol =
        dark ? Colors.white.withValues(alpha: 0.58) : const Color(0xFF66717E);

    final initials = p.userName.isNotEmpty
        ? p.userName
            .trim()
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : 'MC';

    // ── Largura responsiva: max 300 em tablets/desktop, 72% em mobile ────────
    final screenW = MediaQuery.of(context).size.width;
    final isTablet = screenW >= 600;
    // MEDCASES_DRAWER_COMPACT_20_PERCENT_VISUAL_DENSITY_V1_B_R3
    // True 20% outer-width reduction: factor + tablet/mobile clamps scaled.
    final drawerW = isTablet
        ? screenW.clamp(0.0, 256.0)
        : (screenW * 0.672).clamp(224.0, 256.0);

    // ── Shape: cantos arredondados à esquerda apenas em tablets ──────────────
    // (endDrawer desliza da direita → arredondar topLeft + bottomLeft)
    final drawerShape = isTablet
        ? const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              bottomLeft: Radius.circular(18),
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
            avatarBase64: _avatarBase64,
            onAvatarTap: () => _showAvatarActions(context),
            onClose: () => _close(context),
            onEditProfile: () async {
              final navigator = Navigator.of(context);
              _close(context);
              await navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileAccountScreen(p: p),
                ),
              );
              if (mounted) await _loadLocalAvatar();
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
                // ADMIN_V2_EXTERNAL_WEB_ONLY: painel administrativo removido do app clínico.
                // O Admin V2 usa entrypoint web dedicado: lib/main_admin.dart

                // ─── 2. MedCases Pro / Paywall — bloco isolado ───────────────
                // Mantém o gate de review e a navegação homologada; altera
                // somente a composição visual entre perfil/Admin e Suporte.
                if (!kIsReviewMode) ...[
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 18),
                ],

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
                      iconColor: const Color(0xFF009C3B),
                      title: p.lang == 'es' ? 'Fuentes' : 'Fontes',
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
                      iconColor: const Color(0xFF009C3B),
                      title: p.lang == 'es' ? 'Soporte' : 'Suporte',
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
                      iconColor: const Color(0xFF009C3B),
                      title: 'Idioma',
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
                      icon: dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      iconColor: const Color(0xFF009C3B),
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
                      iconColor: const Color(0xFF009C3B),
                      title: p.lang == 'es' ? 'Sobre' : 'Sobre',
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
                      title: p.lang == 'es' ? 'Términos' : 'Termos',
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
                      title: p.lang == 'es' ? 'Privacidad' : 'Privacidade',
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
                  label: p.lang == 'es' ? 'CUENTA' : 'CONTA',
                  dark: dark,
                  color: const Color(0xFFCC3333),
                ),
                _DrawerBlock(
                  dividerColor: divider,
                  children: [
                    _DrawerRow(
                      icon: Icons.delete_outline_rounded,
                      iconColor: const Color(0xFFCC3333),
                      title:
                          p.lang == 'es' ? 'Eliminar Cuenta' : 'Excluir Conta',
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
                        if (context.mounted)
                          context.read<AppProvider>().clearUser();
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
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4),
              border: Border(top: BorderSide(color: divider, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              left: false, // evitar padding duplo no endDrawer
              right: false,
              child: Text(
                'MedCases Pro · ${p.lang == 'es' ? 'Solo uso educativo' : 'Uso educacional'}',
                style: TextStyle(
                    fontSize: 8.74,
                    color: subCol,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2),
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
  final String? avatarBase64;
  final VoidCallback onAvatarTap;
  final VoidCallback onClose;
  final VoidCallback onEditProfile;

  const _DrawerHeader({
    required this.p,
    required this.initials,
    required this.dark,
    required this.avatarBase64,
    required this.onAvatarTap,
    required this.onClose,
    required this.onEditProfile,
  });

  static const _kGreen = Color(0xFF009C3B);

  Widget _avatarFallback(Color avatarBg, Color divider) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatarBg,
        border: Border.all(color: divider, width: 0.8),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: _kGreen,
          fontSize: 14.72,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _avatar(Color avatarBg, Color divider) {
    final encoded = avatarBase64;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final bytes = base64Decode(encoded);
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: divider, width: 0.8),
          ),
          child: ClipOval(
            child: Image.memory(
              bytes,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => _avatarFallback(avatarBg, divider),
            ),
          ),
        );
      } catch (_) {
        return _avatarFallback(avatarBg, divider);
      }
    }
    return _avatarFallback(avatarBg, divider);
  }

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xE6252930) : const Color(0xE6FFFFFF);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF18202A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF66717E);
    final tertiary = const Color(0xFF64748B);
    final avatarBg = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              bottom: BorderSide(color: divider, width: 0.6),
            ),
          ),
          child: SafeArea(
            bottom: false,
            left: false,
            right: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 8, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAvatarTap,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _avatar(avatarBg, divider),
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: bg,
                              border: Border.all(color: divider, width: 0.7),
                            ),
                            child: const Icon(
                              Icons.photo_camera_outlined,
                              size: 10,
                              color: _kGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onEditProfile,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              p.userName.isNotEmpty
                                  ? p.userName
                                  : 'MedCases Pro',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primary,
                                fontSize: 13.34,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (p.currentUser?.profession?.isNotEmpty ??
                                false) ...[
                              const SizedBox(height: 2),
                              Text(
                                p.currentUser!.profession!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: secondary,
                                  fontSize: 10.58,
                                  height: 1.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (p.currentUser?.institution?.isNotEmpty ??
                                false) ...[
                              const SizedBox(height: 1),
                              Text(
                                p.currentUser!.institution!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tertiary,
                                  fontSize: 9.66,
                                  height: 1.2,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Text(
                              'Editar perfil',
                              style: const TextStyle(
                                color: _kGreen,
                                fontSize: 9.2,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: p.lang == 'es' ? 'Cerrar' : 'Fechar',
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18.0,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
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
    final col =
        color ?? (dark ? const Color(0xFF94A3B8) : const Color(0xFF66717E));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 5),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8.74,
          fontWeight: FontWeight.w700,
          color: col,
          letterSpacing: 0.82,
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
    final dark = context.select<AppProvider, bool>((p) => p.darkMode);
    final divCol = dividerColor ??
        (dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1)
            Divider(
              height: 1,
              thickness: 0.55,
              color: divCol,
              indent: 48,
              endIndent: 0,
            ),
        ],
      ],
    );
  }
}

// ── Item Premium do Drawer ────────────────────────────────────────────────────
class _DrawerItemPremium extends StatelessWidget {
  final bool dark;
  final VoidCallback onTap;

  const _DrawerItemPremium({
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const accent = Color(0xFF009C3B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.05),
        highlightColor: accent.withValues(alpha: 0.025),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              const SizedBox(
                width: 32,
                child: Icon(
                  Icons.workspace_premium_outlined,
                  size: 19,
                  color: accent,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Upgrade Premium',
                      style: TextStyle(
                        color: primary,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Acesso completo · 500+ casos clínicos',
                      style: TextStyle(
                        color: secondary,
                        fontSize: 9.2,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'VER',
                style: TextStyle(
                  color: accent,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 14.4,
                color: secondary,
              ),
            ],
          ),
        ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: iconColor.withValues(alpha: 0.05),
        highlightColor: iconColor.withValues(alpha: 0.025),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              SizedBox(
                width: 28.8,
                child: Icon(icon, size: 16.56, color: iconColor),
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
                        fontSize: 11.904,
                        fontWeight: FontWeight.w600,
                        color: textCol,
                        letterSpacing: -0.05,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 9.66,
                          fontWeight: FontWeight.w400,
                          color: subCol,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14.4,
                  color: subCol.withValues(alpha: 0.70),
                ),
            ],
          ),
        ),
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
  final Color iconColor;
  final String title;
  final bool dark;
  final Color textCol;
  final Color subCol;
  final String externalUrl;
  final String externalTooltip;
  final VoidCallback onTap;
  final bool showDivider;

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
    this.showDivider = true,
  });

  void _launch(BuildContext context) {
    openAcademicSourceSecurely(context, title, externalUrl);
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor =
        dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: iconColor.withValues(alpha: 0.05),
            highlightColor: iconColor.withValues(alpha: 0.025),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 9, 6, 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 29,
                    child: Icon(icon, size: 16.56, color: iconColor),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11.904,
                        fontWeight: FontWeight.w600,
                        color: textCol,
                        letterSpacing: -0.05,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _launch(context),
                    tooltip: externalTooltip,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: subCol.withValues(alpha: 0.85),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 14.4,
                    color: subCol.withValues(alpha: 0.70),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 0.55,
            color: dividerColor,
            indent: 48,
          ),
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
    const accent = Color(0xFF009C3B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7.92, vertical: 2.7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: accent.withValues(alpha: 0.10),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.66,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 1.0,
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
      width: 34,
      height: 19,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9.5),
        color: dark ? const Color(0xFF009C3B) : const Color(0xFFA8B2C1),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        alignment: dark ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 15.5,
          height: 15.5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
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
      width: 34,
      height: 19,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9.5),
        color: value ? const Color(0xFF009C3B) : const Color(0xFFA8B2C1),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 15.5,
          height: 15.5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration:
              const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
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
    final isEs = p.lang == 'es';
    final textCol = dark ? const Color(0xFFEEEEEE) : const Color(0xFF0F1116);
    final subCol =
        dark ? Colors.white.withOpacity(0.36) : const Color(0xFF9AA0A8);
    final divider = dark ? const Color(0xFF1A2E22) : const Color(0xFFF0EDE8);

    return _DrawerBlock(
      dividerColor: divider,
      children: [
        // Nova Consulta → tab 0 (HomeScreen)
        _DrawerRow(
          icon: Icons.medical_services_outlined,
          iconColor: const Color(0xFF0D6B57),
          title: isEs ? 'Nueva Consulta' : 'Nova Consulta',
          subtitle: isEs ? 'Iniciar caso clínico' : 'Iniciar caso clínico',
          dark: dark,
          textCol: textCol,
          subCol: subCol,
          onTap: () => _go(context, 0),
        ),
        // Assistente IA → tab 2
        _DrawerRow(
          icon: Icons.smart_toy_outlined,
          iconColor: const Color(0xFF8B5CF6),
          title: isEs ? 'Asistente IA' : 'Assistente IA',
          subtitle: isEs ? 'IA Clínica de bolsillo' : 'IA Clínica de bolso',
          dark: dark,
          textCol: textCol,
          subCol: subCol,
          onTap: () => _go(context, 2),
        ),
        // PROTOCOLOS — visível apenas na Web (Apple 1.4.1: oculto no iOS)
        if (kIsWeb) ...[
          _DrawerRow(
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFF0EA5E9),
            title: isEs ? 'Protocolos' : 'Protocolos',
            subtitle: isEs ? 'Guías y directrices' : 'Rx e diretrizes',
            dark: dark,
            textCol: textCol,
            subCol: subCol,
            onTap: () => _go(context, 1),
          ),
          // FARMACOLOGIA — visível apenas na Web (Apple 1.4.1: oculto no iOS)
          _DrawerRow(
            icon: Icons.medication_outlined,
            iconColor: const Color(0xFFF59E0B),
            title: isEs ? 'Farmacología' : 'Farmacologia',
            subtitle: isEs ? 'Base de medicamentos' : 'Base de medicamentos',
            dark: dark,
            textCol: textCol,
            subCol: subCol,
            showDivider: false,
            onTap: () => _go(context, 1),
          ),
        ],
      ],
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
    final lang = context.select<AppProvider, String>((p) => p.lang);
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
                      color: Color(0xFF0D6B57),
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang == 'es'
                        ? 'Apoyo clínico educativo'
                        : 'Apoio clínico educacional',
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
// MEDCASES_LEGAL_ABOUT_SUPPORT_VISUAL_V2_B_R2
class _AboutAppSheet extends StatelessWidget {
  const _AboutAppSheet({
    required this.p,
    required this.dark,
  });

  final AppProvider p;
  final bool dark;

  static const _accent = Color(0xFF0D6B57);

  @override
  Widget build(BuildContext context) {
    final isEs = p.lang == 'es';
    final background = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF0F4);
    final surface = dark ? const Color(0xFF252930) : Colors.white;
    final text = dark ? const Color(0xFFF7F8FA) : const Color(0xFF18202A);
    final muted = dark ? const Color(0xFFAAB3BF) : const Color(0xFF66717E);
    final line = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    Widget sectionLabel(String value) => Padding(
          padding: const EdgeInsets.fromLTRB(2, 7, 2, 7),
          child: Text(
            value,
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        );

    Widget infoLine({
      required IconData icon,
      required String label,
      required String value,
      VoidCallback? onTap,
    }) {
      final child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: dark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: _accent, size: 16),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: muted,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.55,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: text,
                      fontSize: 13.2,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: muted.withValues(alpha: 0.72),
                size: 20,
              ),
          ],
        ),
      );
      if (onTap == null) return child;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      );
    }

    Widget editorialBlock({
      required IconData icon,
      required String title,
      required String body,
      bool accentSurface = false,
    }) =>
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
          decoration: BoxDecoration(
            color: accentSurface
                ? _accent.withValues(alpha: dark ? 0.15 : 0.07)
                : surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentSurface
                  ? _accent.withValues(alpha: dark ? 0.35 : 0.20)
                  : line,
              width: 0.7,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 18,
                color: accentSurface ? _accent : muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      body,
                      style: TextStyle(
                        color: muted,
                        fontSize: 12.6,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.52,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: background,
            child: Column(
              children: [
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: surface.withValues(
                          alpha: dark ? 0.88 : 0.92,
                        ),
                        border: Border(
                          bottom: BorderSide(color: line, width: 0.7),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 9),
                          Center(
                            child: Container(
                              width: 38,
                              height: 4,
                              decoration: BoxDecoration(
                                color: muted.withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 7, 8, 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isEs
                                        ? 'Sobre MedCases Pro'
                                        : 'Sobre o MedCases Pro',
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.35,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: IconButton(
                                    tooltip: isEs ? 'Cerrar' : 'Fechar',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: muted,
                                      size: 22,
                                    ),
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
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 36),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: line, width: 0.7),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/icon/app_icon.png',
                                width: 54,
                                height: 54,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.local_hospital_rounded,
                                    color: Colors.white,
                                    size: 27,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'MedCases Pro',
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.45,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isEs
                                        ? 'Apoyo clínico educativo'
                                        : 'Apoio clínico educacional',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accent.withValues(alpha: 0.09),
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Text(
                                      isEs
                                          ? 'Herramienta educativa'
                                          : 'Ferramenta educacional',
                                      style: const TextStyle(
                                        color: _accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      sectionLabel(
                        isEs
                            ? 'INFORMACIÓN INSTITUCIONAL'
                            : 'INFORMAÇÃO INSTITUCIONAL',
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line, width: 0.7),
                        ),
                        child: Column(
                          children: [
                            infoLine(
                              icon: Icons.person_outline_rounded,
                              label: isEs
                                  ? 'DESARROLLADO POR'
                                  : 'DESENVOLVIDO POR',
                              value: 'Bruno Rodrigues de Sousa',
                            ),
                            Divider(height: 1, color: line),
                            infoLine(
                              icon: Icons.email_outlined,
                              label: isEs
                                  ? 'CONTACTO INSTITUCIONAL'
                                  : 'CONTATO INSTITUCIONAL',
                              value: 'medcasespro@gmail.com',
                            ),
                            Divider(height: 1, color: line),
                            infoLine(
                              icon: Icons.language_outlined,
                              label: isEs ? 'SITIO WEB' : 'SITE',
                              value: 'promedcases.com',
                              onTap: () => openAcademicSourceSecurely(
                                context,
                                isEs
                                    ? 'MedCases Pro — Sitio Web'
                                    : 'MedCases Pro — Site Oficial',
                                _kSiteUrl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      sectionLabel(
                        isEs ? 'SEGURIDAD Y REVISIÓN' : 'SEGURANÇA E REVISÃO',
                      ),
                      editorialBlock(
                        icon: Icons.verified_user_outlined,
                        title: isEs
                            ? 'Responsabilidad técnica y revisión médica'
                            : 'Responsabilidade técnica e revisão médica',
                        accentSurface: true,
                        body: isEs
                            ? 'El contenido científico, los algoritmos de dosificación, las calculadoras pediátricas y las directrices clínicas incluidos en esta aplicación son revisados, actualizados y validados de forma continua por el Comitê de Revisão Clínica MedCases Pro. Este comité está integrado por profesionales médicos titulados y estudiantes avanzados de medicina, con base en las directrices internacionales vigentes de la World Allergy Organization (WAO), UpToDate y comités de pediatría de referencia.'
                            : 'O conteúdo científico, algoritmos de dosagem, calculadoras pediátricas e diretrizes clínicas contidos neste aplicativo são revisados, atualizados e validados de forma contínua pelo Comitê de Revisão Clínica MedCases Pro, composto por profissionais médicos diplomados e acadêmicos seniores de medicina, com base nas diretrizes internacionais atualizadas da World Allergy Organization (WAO), UpToDate e comitês de pediatria de referência.',
                      ),
                      const SizedBox(height: 8),
                      editorialBlock(
                        icon: Icons.info_outline_rounded,
                        title: 'Propósito',
                        body: isEs
                            ? 'Esta aplicación es una herramienta exclusivamente educativa de apoyo a la toma de decisiones clínicas. No reemplaza el juicio clínico del profesional de salud, ni constituye prescripción médica.'
                            : 'Este aplicativo é uma ferramenta exclusivamente educacional de apoio à tomada de decisão clínica. Não substitui o julgamento clínico do profissional de saúde, nem constitui prescrição médica.',
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'MedCases Pro © ${DateTime.now().year} — '
                        '${isEs ? 'Todos los derechos reservados.' : 'Todos os direitos reservados.'}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: muted.withValues(alpha: 0.72),
                          fontSize: 10.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Bottom sheet de edição de perfil ─────────────────────────────────────────
class ProfileAccountScreen extends StatefulWidget {
  final AppProvider p;

  const ProfileAccountScreen({super.key, required this.p});

  @override
  State<ProfileAccountScreen> createState() => _ProfileAccountScreenState();
}

class _ProfileAccountScreenState extends State<ProfileAccountScreen> {
  // MEDCASES_PROFILE_ACCOUNT_CANONICAL_TOPBAR_EDGELESS_SECTIONS_V1_B_R1
  // Canonical topbar + edgeless section hierarchy; functional flows frozen.
  // MEDCASES_PROFILE_ACCOUNT_UI_V2_B_R1
  static const _green = Color(0xFF0D6B57);
  static const _pageDark = Color(0xFF0F1116);
  static const _surfaceDark = Color(0xFF181D25);
  static const _borderDark = Color(0xFF374151);
  static const _pageLight = Color(0xFFECF0F4);
  static const _surfaceLight = Color(0xFFFFFFFF);
  static const _borderLight = Color(0xFFE2E7EC);

  late final TextEditingController _nameCtrl;
  late final TextEditingController _professionCtrl;
  late final TextEditingController _institutionCtrl;
  late final TextEditingController _currentPasswordCtrl;
  late final TextEditingController _newPasswordCtrl;
  late final TextEditingController _confirmPasswordCtrl;

  String? _avatarBase64;
  bool _avatarLoading = true;
  bool _saving = false;
  bool _changingPassword = false;
  bool _sendingReset = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  AppProvider get p => widget.p;
  bool get isEs => p.lang == 'es';
  bool get dark => p.darkMode;

  String get _avatarPrefsKey {
    final uid = p.currentUser?.uid.trim();
    return 'medcases_profile_avatar_${(uid != null && uid.isNotEmpty) ? uid : 'local'}';
  }

  @override
  void initState() {
    super.initState();
    final u = p.currentUser;
    _nameCtrl = TextEditingController(text: u?.displayName ?? '');
    _professionCtrl = TextEditingController(text: u?.profession ?? '');
    _institutionCtrl = TextEditingController(text: u?.institution ?? '');
    _currentPasswordCtrl = TextEditingController();
    _newPasswordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _loadAvatar();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _professionCtrl.dispose();
    _institutionCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_avatarPrefsKey);
      if (!mounted) return;
      setState(() {
        _avatarBase64 = encoded;
        _avatarLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _avatarLoading = false);
    }
  }

  Future<void> _pickCropAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 95,
      );
      if (picked == null || !mounted) return;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: 900,
        maxHeight: 900,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 88,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Ajustar foto',
            toolbarColor: _pageDark,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: _green,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Ajustar foto',
            doneButtonTitle: isEs ? 'Listo' : 'Concluir',
            cancelButtonTitle: 'Cancelar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPresets: const [CropAspectRatioPreset.square],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 520),
          ),
        ],
      );
      if (cropped == null) return;

      final bytes = await cropped.readAsBytes();
      if (bytes.isEmpty) return;
      final encoded = base64Encode(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarPrefsKey, encoded);

      if (!mounted) return;
      setState(() => _avatarBase64 = encoded);
      _snack(
          isEs ? 'Foto de perfil actualizada.' : 'Foto de perfil atualizada.');
    } catch (_) {
      if (mounted) {
        _snack(
          isEs
              ? 'No fue posible editar la foto.'
              : 'Não foi possível editar a foto.',
          error: true,
        );
      }
    }
  }

  Future<void> _removeAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_avatarPrefsKey);
      if (!mounted) return;
      setState(() => _avatarBase64 = null);
      _snack(isEs ? 'Foto eliminada.' : 'Foto removida.');
    } catch (_) {
      if (mounted) {
        _snack(
          isEs
              ? 'No fue posible eliminar la foto.'
              : 'Não foi possível remover a foto.',
          error: true,
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.length < 2) {
      _snack(
        isEs ? 'Ingresa un nombre válido.' : 'Informe um nome válido.',
        error: true,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await p.updateProfile(
        displayName: name,
        profession: _professionCtrl.text.trim(),
        institution: _institutionCtrl.text.trim(),
      );
      if (mounted) _snack(isEs ? 'Perfil actualizado.' : 'Perfil atualizado.');
    } catch (_) {
      if (mounted) {
        _snack(
          isEs
              ? 'No fue posible guardar el perfil.'
              : 'Não foi possível salvar o perfil.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (_changingPassword) return;
    final current = _currentPasswordCtrl.text;
    final next = _newPasswordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    if (current.isEmpty) {
      _snack(
        isEs ? 'Ingresa tu contraseña actual.' : 'Informe sua senha atual.',
        error: true,
      );
      return;
    }
    if (next.length < 6) {
      _snack(
        isEs
            ? 'La nueva contraseña debe tener al menos 6 caracteres.'
            : 'A nova senha deve ter pelo menos 6 caracteres.',
        error: true,
      );
      return;
    }
    if (next != confirm) {
      _snack(
        isEs ? 'Las contraseñas no coinciden.' : 'As senhas não coincidem.',
        error: true,
      );
      return;
    }
    if (current == next) {
      _snack(
        isEs
            ? 'La nueva contraseña debe ser diferente.'
            : 'A nova senha deve ser diferente.',
        error: true,
      );
      return;
    }

    setState(() => _changingPassword = true);
    final result = await AuthService.changePassword(
      currentPassword: current,
      newPassword: next,
      languageCode: p.lang,
    );
    if (!mounted) return;
    setState(() => _changingPassword = false);

    if (result.success) {
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _snack(result.message ??
          (isEs ? 'Contraseña actualizada.' : 'Senha atualizada.'));
    } else {
      _snack(
        result.error ??
            (isEs
                ? 'No fue posible actualizar la contraseña.'
                : 'Não foi possível atualizar a senha.'),
        error: true,
      );
    }
  }

  Future<void> _sendReset() async {
    if (_sendingReset) return;
    final email = p.currentUser?.email.trim() ?? '';
    if (email.isEmpty) {
      _snack(
        isEs
            ? 'No hay un correo asociado a la cuenta.'
            : 'Não há e-mail associado à conta.',
        error: true,
      );
      return;
    }

    setState(() => _sendingReset = true);
    final result = await AuthService.resetPassword(email);
    if (!mounted) return;
    setState(() => _sendingReset = false);

    if (result.success) {
      _snack(
        isEs
            ? 'Enviamos el enlace de redefinición a $email.'
            : 'Enviamos o link de redefinição para $email.',
      );
    } else {
      _snack(
        isEs
            ? 'No fue posible enviar el enlace de redefinición.'
            : (result.error ??
                'Não foi possível enviar o link de redefinição.'),
        error: true,
      );
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            error ? const Color(0xFFB91C1C) : const Color(0xFF047857),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = dark ? _pageDark : _pageLight;
    return Scaffold(
      backgroundColor: page,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _ProfileAccountTopBar(
              dark: dark,
              title: isEs ? 'Perfil y cuenta' : 'Perfil e conta',
              onBack: () => Navigator.of(context).pop(true),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _avatarCard(),
                        const SizedBox(height: 10),
                        _ProfileAccountSection(
                          dark: dark,
                          title: isEs
                              ? 'Datos profesionales'
                              : 'Dados profissionais',
                          subtitle: isEs
                              ? 'Información que identifica tu perfil en MedCases.'
                              : 'Informações que identificam seu perfil no MedCases.',
                          children: [
                            _ProfileAccountField(
                              controller: _nameCtrl,
                              label: isEs ? 'Nombre completo' : 'Nome completo',
                              icon: Icons.person_outline_rounded,
                              dark: dark,
                            ),
                            const SizedBox(height: 8),
                            _ProfileAccountField(
                              controller: _professionCtrl,
                              label: isEs ? 'Profesión' : 'Profissão',
                              icon: Icons.medical_services_outlined,
                              dark: dark,
                            ),
                            const SizedBox(height: 8),
                            _ProfileAccountField(
                              controller: _institutionCtrl,
                              label: isEs ? 'Institución' : 'Instituição',
                              icon: Icons.apartment_rounded,
                              dark: dark,
                              textInputAction: TextInputAction.done,
                            ),
                            const SizedBox(height: 10),
                            _ProfileAccountButton(
                              label: _saving
                                  ? (isEs ? 'Guardando...' : 'Salvando...')
                                  : (isEs ? 'Guardar datos' : 'Salvar dados'),
                              icon: Icons.check_rounded,
                              loading: _saving,
                              onTap: _saving ? null : _saveProfile,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _securityCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarCard() {
    final surface = dark ? _surfaceDark : _surfaceLight;
    final border = dark ? _borderDark : _borderLight;
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final email = p.currentUser?.email ?? '';
    Uint8List? bytes;
    final encoded = _avatarBase64;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        bytes = base64Decode(encoded);
      } catch (_) {
        bytes = null;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 18),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      dark ? const Color(0xFF2D3340) : const Color(0xFFF1F5F9),
                  border: Border.all(color: border, width: 1),
                ),
                child: ClipOval(
                  child: _avatarLoading
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _green,
                            ),
                          ),
                        )
                      : bytes != null
                          ? Image.memory(bytes,
                              fit: BoxFit.cover, gaplessPlayback: true)
                          : Icon(Icons.person_rounded,
                              size: 42, color: secondary),
                ),
              ),
              Positioned(
                right: -3,
                bottom: 1,
                child: Material(
                  color: _green,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _pickCropAvatar,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.edit_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _nameCtrl.text.trim().isEmpty
                ? (isEs ? 'Tu perfil' : 'Seu perfil')
                : _nameCtrl.text.trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              email,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _ProfilePhotoAction(
                label: isEs ? 'Cambiar foto' : 'Alterar foto',
                icon: Icons.photo_library_outlined,
                dark: dark,
                onTap: _pickCropAvatar,
              ),
              if (bytes != null)
                _ProfilePhotoAction(
                  label: isEs ? 'Quitar' : 'Remover',
                  icon: Icons.delete_outline_rounded,
                  dark: dark,
                  destructive: true,
                  onTap: _removeAvatar,
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            isEs
                ? 'Podrás mover y ampliar la imagen antes de recortarla.'
                : 'Você poderá mover e ampliar a imagem antes de recortar.',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondary, fontSize: 10.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _securityCard() {
    if (kIsWeb) {
      return _ProfileAccountSection(
        dark: dark,
        title: isEs ? 'Seguridad' : 'Segurança',
        subtitle: isEs
            ? 'En la Web, el cambio se protege con un enlace enviado a tu correo.'
            : 'Na Web, a troca é protegida por um link enviado ao seu e-mail.',
        children: [
          _ProfileReadOnlyRow(
            dark: dark,
            label: isEs ? 'Correo de la cuenta' : 'E-mail da conta',
            value: p.currentUser?.email ?? '—',
          ),
          const SizedBox(height: 10),
          _ProfileAccountButton(
            label: _sendingReset
                ? (isEs ? 'Enviando...' : 'Enviando...')
                : (isEs
                    ? 'Enviar enlace de redefinición'
                    : 'Enviar link de redefinição'),
            icon: Icons.lock_reset_rounded,
            loading: _sendingReset,
            onTap: _sendingReset ? null : _sendReset,
          ),
        ],
      );
    }

    return _ProfileAccountSection(
      dark: dark,
      title: isEs ? 'Seguridad' : 'Segurança',
      subtitle: isEs
          ? 'Confirma tu contraseña actual antes de crear una nueva.'
          : 'Confirme sua senha atual antes de criar uma nova.',
      children: [
        _ProfileAccountField(
          controller: _currentPasswordCtrl,
          label: isEs ? 'Contraseña actual' : 'Senha atual',
          icon: Icons.lock_outline_rounded,
          dark: dark,
          obscureText: !_showCurrent,
          suffix: _ProfilePasswordToggle(
            visible: _showCurrent,
            dark: dark,
            onTap: () => setState(() => _showCurrent = !_showCurrent),
          ),
        ),
        const SizedBox(height: 8),
        _ProfileAccountField(
          controller: _newPasswordCtrl,
          label: isEs ? 'Nueva contraseña' : 'Nova senha',
          icon: Icons.password_rounded,
          dark: dark,
          obscureText: !_showNew,
          suffix: _ProfilePasswordToggle(
            visible: _showNew,
            dark: dark,
            onTap: () => setState(() => _showNew = !_showNew),
          ),
        ),
        const SizedBox(height: 8),
        _ProfileAccountField(
          controller: _confirmPasswordCtrl,
          label: isEs ? 'Confirmar nueva contraseña' : 'Confirmar nova senha',
          icon: Icons.verified_user_outlined,
          dark: dark,
          obscureText: !_showConfirm,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _changePassword(),
          suffix: _ProfilePasswordToggle(
            visible: _showConfirm,
            dark: dark,
            onTap: () => setState(() => _showConfirm = !_showConfirm),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isEs ? 'Mínimo de 6 caracteres.' : 'Mínimo de 6 caracteres.',
          style: TextStyle(
            color: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 10),
        _ProfileAccountButton(
          label: _changingPassword
              ? (isEs ? 'Actualizando...' : 'Atualizando...')
              : (isEs ? 'Actualizar contraseña' : 'Atualizar senha'),
          icon: Icons.shield_outlined,
          loading: _changingPassword,
          onTap: _changingPassword ? null : _changePassword,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _sendingReset ? null : _sendReset,
          child: Text(
            isEs ? 'Olvidé mi contraseña' : 'Esqueci minha senha',
            style: const TextStyle(
              color: _green,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAccountTopBar extends StatelessWidget {
  final bool dark;
  final String title;
  final VoidCallback onBack;

  const _ProfileAccountTopBar({
    required this.dark,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final glassColor = dark
        ? const Color(0xFF252930).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.70);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);
    final text = dark ? Colors.white : const Color(0xFF05070A);

    return SizedBox(
      height: topPad + 48,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              border: Border(
                bottom: BorderSide(color: border, width: 0.7),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: topPad),
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: text,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onBack,
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 20,
                              color: text,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileAccountSection extends StatelessWidget {
  final bool dark;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _ProfileAccountSection({
    required this.dark,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final divider = (dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC))
        .withValues(alpha: 0.62);

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: primary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: secondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
          const SizedBox(height: 16),
          Container(
            height: 0.7,
            color: divider,
          ),
        ],
      ),
    );
  }
}

class _ProfileAccountField extends StatelessWidget {
  // MEDCASES_GLOBAL_DARK_THEME_SECOND_BRAND_V2_B_R1_PROFILE
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool dark;
  final bool obscureText;
  final TextInputAction textInputAction;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  const _ProfileAccountField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.dark,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final fill = dark ? const Color(0xFF181D25) : const Color(0xFFFFFFFF);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      autocorrect: !obscureText,
      enableSuggestions: !obscureText,
      cursorColor: const Color(0xFF10B981),
      style: TextStyle(
        color: primary,
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: secondary,
          fontSize: 11.5,
        ),
        prefixIcon: Icon(
          icon,
          size: 18,
          color: secondary,
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: fill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: border.withValues(alpha: 0.42),
            width: 0.55,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF10B981),
            width: 1.0,
          ),
        ),
      ),
    );
  }
}

class _ProfileAccountButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _ProfileAccountButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF0D6B57),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              const Color(0xFF0D6B57).withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        icon: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 17),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ProfilePhotoAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool dark;
  final bool destructive;
  final VoidCallback onTap;

  const _ProfilePhotoAction({
    required this.label,
    required this.icon,
    required this.dark,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFEF4444) : const Color(0xFF0B8A72);

    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 5,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
        ),
      ),
      icon: Icon(
        icon,
        size: 15,
        color: color,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProfilePasswordToggle extends StatelessWidget {
  final bool visible;
  final bool dark;
  final VoidCallback onTap;

  const _ProfilePasswordToggle({
    required this.visible,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 18,
        color: color,
      ),
    );
  }
}

class _ProfileReadOnlyRow extends StatelessWidget {
  final bool dark;
  final String label;
  final String value;

  const _ProfileReadOnlyRow({
    required this.dark,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final fill = dark ? const Color(0xFF181D25) : const Color(0xFFF8FAFC);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);
    final primary = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final secondary = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: border.withValues(alpha: 0.38),
          width: 0.55,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.alternate_email_rounded,
            size: 17,
            color: secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: primary,
                    fontSize: 12.5,
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

// ── Modal "O que há de novo" ──────────────────────────────────────────────────
class _AppUpdateDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AppUpdateDialog({required this.data});

  static const _kDark = Color(0xFF0F1116);
  static const _kGreen = Color(0xFF10B981);
  static const _kGold = Color(0xFFC5A365);
  static const _kGoldL = Color(0xFFFFE8A6);

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? 'Novidades';
    final version = data['version'] as String? ?? '';
    final date = data['date'] as String? ?? '';
    final items = (data['items'] as List<dynamic>? ?? []).cast<String>();

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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: _kGoldL, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                if (version.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kGold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kGold.withOpacity(0.4)),
                    ),
                    child: Text('v$version',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _kGoldL)),
                  ),
                  const SizedBox(width: 8),
                ],
                if (date.isNotEmpty)
                  Text(date,
                      style: TextStyle(
                          fontSize: 11, color: Colors.white.withOpacity(0.5))),
              ]),
            ]),
          ),
          // Lista de novidades
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                      color: _kGreen, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(item,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1A1D23),
                                          height: 1.4)),
                                ),
                              ]),
                        ))
                    .toList(),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Entendido!',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Bottom Sheet de Feedback ──────────────────────────────────────────────────
// MEDCASES_SUPPORT_TICKET_FOUNDATION_V2_B_R1
class _FeedbackSheet extends StatelessWidget {
  const _FeedbackSheet({
    required this.p,
    required this.dark,
  });

  final AppProvider p;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return SupportTicketScreen(
      p: p,
      dark: dark,
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
    final bg = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final textCol = dark ? Colors.white : const Color(0xFF1A1D23);
    final subCol = dark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280);

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
                color: dark ? const Color(0xFF48484A) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Ícone de sucesso
          Container(
            width: 72,
            height: 71,
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
                isEs
                    ? 'Cerrar'
                    : 'Fechar', // BUILD 334-FORENSE: hardcode PT corrigido
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

// ─────────────────────────────────────────────────────────────────────────────
// MEDCASES NOTAS + ÁUDIO — FULLSCREEN WORKSPACE V1
// Home NOTAS -> MainShell tab 9. Reuses the productive Notes owner.
// Audio remains fail-closed: no real-patient remote callsite is wired here.
// ─────────────────────────────────────────────────────────────────────────────
class _NotesAudioWorkspace extends StatefulWidget {
  const _NotesAudioWorkspace({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_NotesAudioWorkspace> createState() => _NotesAudioWorkspaceState();
}

class _NotesAudioWorkspaceState extends State<_NotesAudioWorkspace> {
  int _section = 1;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    final page = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final surface = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final subnav = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final border = dark ? const Color(0xFF374151) : const Color(0xFFE7EBEF);
    final text = dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);
    final sub = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const accent = Color(0xFF0D6B57);
    final topPad =
        View.of(context).padding.top / View.of(context).devicePixelRatio;
    final topbarGlass = dark
        ? const Color(0xFF252930).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.70);

    return Material(
      color: page,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: topPad + 48,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: topbarGlass,
                      border: Border(
                        bottom: BorderSide(
                          color: dark
                              ? const Color(0xFF374151)
                              : const Color(0xFFE2E7EC),
                          width: 0.7,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(top: topPad),
                      child: SizedBox(
                        height: 48,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                isEs ? 'Área de Estudio' : 'Área de Estudos',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: dark
                                      ? Colors.white
                                      : const Color(0xFF05070A),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.onBack,
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 20,
                                      color: dark
                                          ? Colors.white
                                          : const Color(0xFF05070A),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              height: 40,
              color: subnav,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _NotesAudioWorkspaceTab(
                    label: 'Notas',
                    icon: Icons.edit_note_rounded,
                    selected: _section == 0,
                    accent: accent,
                    text: text,
                    sub: sub,
                    border: border,
                    showDivider: true,
                    onTap: () => setState(() => _section = 0),
                  ),
                  _NotesAudioWorkspaceTab(
                    label: isEs ? 'Estudio' : 'Estudos',
                    icon: Icons.auto_stories_outlined,
                    selected: _section == 1,
                    accent: accent,
                    text: text,
                    sub: sub,
                    border: border,
                    showDivider: true,
                    onTap: () => setState(() => _section = 1),
                  ),
                  _NotesAudioWorkspaceTab(
                    label: isEs ? 'Historial' : 'Histórico',
                    icon: Icons.history_rounded,
                    selected: _section == 2,
                    accent: accent,
                    text: text,
                    sub: sub,
                    border: border,
                    showDivider: false,
                    onTap: () => setState(() => _section = 2),
                  ),
                ],
              ),
            ),
            Container(height: 0.7, color: border),
            Expanded(
              child: IndexedStack(
                index: _section,
                children: [
                  _NotesPanelContent(
                    onClose: widget.onBack,
                    scrollController: PrimaryScrollController.maybeOf(context),
                    workspaceMode: true,
                  ),
                  StudyWorkspaceScreen(isEs: isEs),
                  StudyHistoryScreen(isEs: isEs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotesAudioWorkspaceTab extends StatelessWidget {
  const _NotesAudioWorkspaceTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.text,
    required this.sub,
    required this.border,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final Color text;
  final Color sub;
  final Color border;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeBackground = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0D6B57).withValues(alpha: 0.10)
        : const Color(0xFF0D6B57).withValues(alpha: 0.08);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? activeBackground : Colors.transparent,
          ),
          child: Stack(
            children: [
              Center(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? text : sub,
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.05,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 9,
                  child: Container(
                    height: 2,
                    color: accent,
                  ),
                ),
              if (showDivider)
                Positioned(
                  top: 10,
                  bottom: 10,
                  right: 0,
                  child: Container(
                    width: 0.7,
                    color: border,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesAudioWorkspaceAudio extends StatelessWidget {
  const _NotesAudioWorkspaceAudio({
    required this.isEs,
    required this.page,
    required this.surface,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
  });

  final bool isEs;
  final Color page;
  final Color surface;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;

  Future<void> _requestPurposeSpecificConsent(
    BuildContext context, {
    required String mode,
    required bool longForm,
  }) async {
    final accepted = await ClinicalLongFormRemoteAudioConsentUi.showIfNeeded(
      context,
      language: isEs ? 'es' : 'pt',
    );

    if (!context.mounted || !accepted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        settings: RouteSettings(name: 'notes_audio_local:$mode'),
        builder: (_) => longForm
            ? NotesAudioLongFormLocalRuntimeScreen(isEs: isEs)
            : NotesAudioConsultationLocalRuntimeScreen(isEs: isEs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(1, 1, 1, 124),
        children: [
          _NotesAudioHero(
            isEs: isEs,
            surface: surface,
            border: border,
            text: text,
            sub: sub,
            accent: accent,
          ),
          const SizedBox(height: 8),
          _NotesAudioModeCard(
            icon: Icons.medical_services_outlined,
            title: 'Consulta clínica',
            subtitle: isEs
                ? 'Captura de voz para transcripción y organización de la historia clínica.'
                : 'Captura de voz para transcrição e organização da história clínica.',
            badge: 'Consulta',
            lockedLabel: isEs ? 'Local y privado' : 'Local e privado',
            onTap: () => _requestPurposeSpecificConsent(
              context,
              mode: 'Consulta clínica',
              longForm: false,
            ),
            surface: surface,
            border: border,
            text: text,
            sub: sub,
            accent: accent,
          ),
          const SizedBox(height: 6),
          _NotesAudioModeCard(
            icon: Icons.school_outlined,
            title: isEs ? 'Clase / audio largo' : 'Aula / áudio longo',
            subtitle: isEs
                ? 'Grabación segmentada, transcripción cronológica, revisión y borrado del audio tras confirmar.'
                : 'Gravação segmentada, transcrição cronológica, revisão e exclusão do áudio após confirmar.',
            badge: isEs ? 'Modo estudio' : 'Modo estudo',
            lockedLabel: isEs ? 'Local y privado' : 'Local e privado',
            onTap: () => _requestPurposeSpecificConsent(
              context,
              mode: isEs ? 'Clase / audio largo' : 'Aula / áudio longo',
              longForm: true,
            ),
            surface: surface,
            border: border,
            text: text,
            sub: sub,
            accent: accent,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NotesAudioHero extends StatelessWidget {
  const _NotesAudioHero({
    required this.isEs,
    required this.surface,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
  });

  final bool isEs;
  final Color surface;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
        border: null,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.graphic_eq_rounded, size: 23, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEs ? 'Audio y transcripción' : 'Áudio e transcrição',
                        style: TextStyle(
                          color: text,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isEs
                      ? 'Un espacio para consulta, clases y transcripciones con revisión antes de guardar.'
                      : 'Um espaço para consulta, aulas e transcrições com revisão antes de salvar.',
                  style: TextStyle(
                    color: sub,
                    fontSize: 10.5,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
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

class _NotesAudioModeCard extends StatelessWidget {
  const _NotesAudioModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.lockedLabel,
    required this.onTap,
    required this.surface,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final String lockedLabel;
  final VoidCallback onTap;
  final Color surface;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
          border: null,
        ),
        child: Row(
          children: [
            SizedBox(width: 32, child: Icon(icon, size: 19, color: accent)),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: sub,
                      fontSize: 10.5,
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: accent,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          lockedLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sub,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: sub),
          ],
        ),
      ),
    );
  }
}

class _NotesAudioWorkspaceHistory extends StatelessWidget {
  const _NotesAudioWorkspaceHistory({
    required this.isEs,
    required this.page,
    required this.surface,
    required this.border,
    required this.text,
    required this.sub,
    required this.accent,
  });

  final bool isEs;
  final Color page;
  final Color surface;
  final Color border;
  final Color text;
  final Color sub;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(1, 1, 1, 124),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(8),
              border: null,
            ),
            child: Column(
              children: [
                Icon(Icons.history_rounded, size: 30, color: accent),
                const SizedBox(height: 9),
                Text(
                  isEs
                      ? 'Sin transcripciones confirmadas'
                      : 'Nenhuma transcrição confirmada',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEs
                      ? 'Las sesiones aparecerán aquí después de la revisión y confirmación del usuario.'
                      : 'As sessões aparecerão aqui depois da revisão e confirmação do usuário.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: sub,
                    fontSize: 10.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
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

void showNotesSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.36,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        final panelBg =
            dark ? const Color(0xFF1A1D23) : const Color(0xFFF7F8FA);
        final surfaceStrong =
            dark ? const Color(0xFF2D3340) : const Color(0xFFE9EDF2);
        final border = dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: border, width: 0.8),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.fromLTRB(0, 9, 0, 5),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: surfaceStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: _NotesPanelContent(
                onClose: () => Navigator.pop(ctx),
                scrollController: scrollController,
              ),
            ),
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
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
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
    final size = MediaQuery.of(context).size;
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
  final bool workspaceMode;
  const _NotesPanelContent({
    required this.onClose,
    this.scrollController,
    this.workspaceMode = false,
  });

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
    if (uid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    _sub = FirestoreService.notesStream(uid).listen(
      (notes) {
        if (mounted)
          setState(() {
            _allNotes = notes;
            _loading = false;
          });
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
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
      final t = (n['title'] as String? ?? '').toLowerCase();
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
    final uid = context.read<AppProvider>().currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final dark = context.read<AppProvider>().darkMode;
    final lang = context.read<AppProvider>().lang;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteEditorSheet(
        uid: uid,
        note: note,
        dark: dark,
        lang: lang,
        onDelete: note == null || (note['id'] as String? ?? '').isEmpty
            ? null
            : () => _deleteNote(note['id'] as String),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // NOTES V3.0 — PAINEL MINIMALISTA SEM CARDS ANINHADOS
    final p = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    final panelBg = dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
    final surface = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final borderCol = dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);
    final accent = dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);
    final textCol = dark ? const Color(0xFFF3F4F6) : const Color(0xFF111318);
    final subCol = dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: ColoredBox(
        color: panelBg,
        child: Column(
          children: [
            if (!widget.workspaceMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 14, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: widget.onClose,
                      tooltip: isEs ? 'Volver' : 'Voltar',
                      icon: const Icon(Icons.chevron_left_rounded),
                      iconSize: 25,
                      color: textCol,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEs ? 'Mis Anotaciones' : 'Minhas Anotações',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textCol,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _allNotes.isEmpty
                                ? (isEs
                                    ? 'Sin anotaciones'
                                    : 'Nenhuma anotação')
                                : '${_allNotes.length} ${isEs ? 'anotación${_allNotes.length != 1 ? "es" : ""}' : 'anotaç${_allNotes.length != 1 ? "ões" : "ão"}'}',
                            style: TextStyle(
                              color: subCol,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _openEditor(),
                      style: TextButton.styleFrom(
                        foregroundColor: accent,
                        backgroundColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 10,
                        ),
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 19),
                      label: Text(
                        isEs ? 'Nueva' : 'Nova',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // MEDCASES_NOTES_SEARCH_BAR_VISUAL_V1_R1
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(
                    color: textCol,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        isEs ? 'Buscar anotaciones...' : 'Buscar anotações...',
                    hintStyle: TextStyle(
                      color: subCol,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: subCol,
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                            tooltip: isEs ? 'Limpiar' : 'Limpar',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: subCol,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: surface,
                    isDense: true,
                    contentPadding: const EdgeInsets.fromLTRB(0, 10, 8, 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: borderCol,
                        width: 0.7,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: borderCol,
                        width: 0.7,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: accent,
                        width: 1,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: borderCol,
                        width: 0.7,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _search = value.trim().toLowerCase());
                  },
                ),
              ),
            ),
            Container(height: 0.7, color: borderCol),
            Expanded(
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: accent,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _filtered.isEmpty
                      ? _PanelEmptyState(
                          isEs: isEs,
                          dark: dark,
                          onNew: () => _openEditor(),
                        )
                      : ListView.separated(
                          controller: widget.scrollController,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            widget.workspaceMode ? 112 : 18,
                          ),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 0.7,
                            color: borderCol,
                          ),
                          itemBuilder: (ctx, i) {
                            final note = _filtered[i];
                            return _PanelNoteCard(
                              note: note,
                              dark: dark,
                              isEs: isEs,
                              onTap: () => _openEditor(note: note),
                              onDelete: () => _deleteNote(
                                note['id'] as String? ?? '',
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
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
  const _PanelEmptyState(
      {required this.isEs, required this.dark, required this.onNew});

  @override
  Widget build(BuildContext context) {
    // NOTES V3.1 — ESTADO VAZIO MINIMALISTA
    final accent = dark ? const Color(0xFF0D6B57) : const Color(0xFF0D6B57);
    final textCol = dark ? const Color(0xFFF3F4F6) : const Color(0xFF111318);
    final subCol = dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 30,
              color: accent,
            ),
            const SizedBox(height: 10),
            Text(
              isEs ? 'Ninguna anotación' : 'Nenhuma anotação',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textCol,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isEs
                  ? 'Crea una nota para guardar información importante.'
                  : 'Crie uma nota para guardar informações importantes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subCol,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onNew,
              style: TextButton.styleFrom(
                foregroundColor: accent,
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(
                Icons.add_rounded,
                size: 18,
              ),
              label: Text(
                isEs ? 'Nueva anotación' : 'Nova anotação',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
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
  const _NoteColor2(
      {required this.hex,
      required this.light,
      required this.dark,
      required this.border});
}

const _panelNoteColors = [
  _NoteColor2(
      hex: '#FFFEF0',
      light: Color(0xFFFFFEF0),
      dark: Color(0xFF2A2800),
      border: Color(0xFFE8E0A0)),
  _NoteColor2(
      hex: '#F0FFF4',
      light: Color(0xFFF0FFF4),
      dark: Color(0xFF002A0F),
      border: Color(0xFFA0DEB8)),
  _NoteColor2(
      hex: '#F0F4FF',
      light: Color(0xFFF0F4FF),
      dark: Color(0xFF00102A),
      border: Color(0xFFA0B8E8)),
  _NoteColor2(
      hex: '#FFF0F4',
      light: Color(0xFFFFF0F4),
      dark: Color(0xFF2A0010),
      border: Color(0xFFE8A0B8)),
  _NoteColor2(
      hex: '#FFF6F0',
      light: Color(0xFFFFF6F0),
      dark: Color(0xFF2A1200),
      border: Color(0xFFE8C0A0)),
  _NoteColor2(
      hex: '#F6F0FF',
      light: Color(0xFFF6F0FF),
      dark: Color(0xFF1A0028),
      border: Color(0xFFC0A0E8)),
];

_NoteColor2 _panelColorFromHex(String hex) => _panelNoteColors
    .firstWhere((c) => c.hex == hex, orElse: () => _panelNoteColors[0]);

class _PanelNoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  final bool dark;
  final bool isEs;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _PanelNoteCard({
    required this.note,
    required this.dark,
    required this.isEs,
    required this.onTap,
    required this.onDelete,
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
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // NOTES V3.0 — ITEM MINIMALISTA COM MARCADOR SEMÂNTICO
    final surface = dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
    final textCol = dark ? const Color(0xFFF3F4F6) : const Color(0xFF111318);
    final subCol = dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final deleteCol = dark ? const Color(0xFFF28B82) : const Color(0xFFB42318);

    final hex = note['color'] as String? ?? '#FFFEF0';
    final nc = _panelColorFromHex(hex);
    final noteAccent = nc.border;

    final title = (note['title'] as String? ?? '').trim();
    final content = (note['content'] as String? ?? '').trim();
    final dateStr = _formatDate(
      note['updatedAt'] ?? note['createdAt'],
    );
    final displayTitle =
        title.isEmpty ? (isEs ? 'Sin título' : 'Sem título') : title;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 0, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: content.isEmpty ? 38 : 52,
              decoration: BoxDecoration(
                color: noteAccent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textCol,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subCol,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      dateStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subCol,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      isEs ? 'Eliminar nota' : 'Excluir anotação',
                      style: TextStyle(
                        color: textCol,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    content: Text(
                      isEs
                          ? '¿Eliminar esta nota?'
                          : 'Deseja excluir esta anotação?',
                      style: TextStyle(
                        color: subCol,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(
                            color: subCol,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onDelete();
                        },
                        child: Text(
                          isEs ? 'Eliminar' : 'Excluir',
                          style: TextStyle(
                            color: deleteCol,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              visualDensity: VisualDensity.compact,
              tooltip: isEs ? 'Eliminar' : 'Excluir',
              icon: Icon(
                Icons.delete_outline_rounded,
                color: deleteCol,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── MEDCASES_OFFLINE_MINIMAL_CACHE_REFRESH_V1_R2 ─────────────────────────────────────────────
// Contrato visual: somente Ativar/Desativar Offline + Limpar cache.
// "Limpar cache" limpa/recria a base offline da Calculadora e solicita reload.
class _OfflineDrawerCard extends StatefulWidget {
  final AppProvider p;
  final bool dark;
  const _OfflineDrawerCard({required this.p, required this.dark});

  @override
  State<_OfflineDrawerCard> createState() => _OfflineDrawerCardState();
}

class _OfflineDrawerCardState extends State<_OfflineDrawerCard> {
  // MEDCASES_OFFLINE_MINIMAL_CACHE_REFRESH_V1_R2
  bool _clearing = false;

  Future<void> _doClear(BuildContext ctx, bool isEs) async {
    if (_clearing) return;
    setState(() => _clearing = true);

    try {
      if (!kIsWeb) {
        await OfflineCalculatorCacheService.instance.clearCache();
        await OfflineCalculatorCacheService.instance.forceUpdate();
      }

      CalculadoraScreen.requestCacheRefresh();

      if (!mounted) return;
      ScaffoldMessenger.of(ctx)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isEs
                  ? 'Caché de la calculadora borrada y actualizada'
                  : 'Cache da calculadora limpo e atualizado',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF1D4ED8),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              isEs
                  ? 'No se pudo actualizar la caché de la calculadora'
                  : 'Não foi possível atualizar o cache da calculadora',
            ),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final dark = widget.dark;
    final isEs = p.lang == 'es';
    final offline = p.offlineMode;
    final caching = p.offlineCaching;
    final textCol = dark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final subCol = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final divider = dark ? const Color(0xFF374151) : const Color(0xFFE2E7EC);

    return _DrawerBlock(
      dividerColor: divider,
      children: [
        _DrawerRow(
          icon: offline ? Icons.offline_bolt_rounded : Icons.cloud_off_outlined,
          iconColor: const Color(0xFF1D4ED8),
          title: isEs ? 'Modo sin conexión' : 'Modo offline',
          dark: dark,
          textCol: textCol,
          subCol: subCol,
          trailing: _OnOffToggle(value: offline),
          onTap: () {
            if (caching || _clearing) return;
            p.setOfflineMode(!offline);
          },
        ),
        _DrawerRow(
          icon: Icons.cleaning_services_outlined,
          iconColor: const Color(0xFF64748B),
          title: _clearing
              ? (isEs ? 'Limpiando…' : 'Limpando…')
              : (isEs ? 'Limpiar caché' : 'Limpar cache'),
          dark: dark,
          textCol: textCol,
          subCol: subCol,
          trailing: _clearing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.6),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          onTap: () {
            if (_clearing) return;
            _doClear(context, isEs);
          },
        ),
      ],
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
                width: 40,
                height: 40,
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
