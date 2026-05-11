import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

// ── Consent Gate (Android) ────────────────────────────────────────────────────
// Aparece UMA única vez antes do login. Após aceite grava consent_v1=true
// via SharedPreferences e exibe LoginScreen normalmente.
class _ConsentGate extends StatefulWidget {
  const _ConsentGate();
  @override
  State<_ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<_ConsentGate> {
  bool? _hasConsented; // null = ainda carregando

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await ConsentGate.hasConsented();
    if (mounted) setState(() => _hasConsented = ok);
  }

  void _onAccepted() {
    // ConsentGate.saveConsent() já foi chamado dentro do ConsentModal
    setState(() => _hasConsented = true);
  }

  @override
  Widget build(BuildContext context) {
    // Ainda carregando prefs → splash simples
    if (_hasConsented == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1C14),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4A96A))),
      );
    }

    // Já consentiu → vai direto para login
    if (_hasConsented!) return const LoginScreen();

    // Primeira vez → mostra LoginScreen com modal de consentimento por cima
    return Stack(
      children: [
        const LoginScreen(),
        // Barreira escura que bloqueia interação com o login até aceitar
        Positioned.fill(
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
        ),
        // Modal de consentimento ancorado na base
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: ConsentModal(
            lang: 'pt', // padrão inicial — usuário ainda não escolheu idioma
            onAccepted: _onAccepted,
          ),
        ),
      ],
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
  // FIX DEFINITIVO: sem Navigator.push — LoginScreen é exibida inline.
  bool _showLogin = false;
  // Consent gate Web — null=carregando, false=precisa consentir, true=ok
  bool? _hasConsented;
  // Tab selecionada: 0=Casos Clínicos, 1=Prescrições
  int _demoTab = 0;

  static const _kDark    = Color(0xFF0F1C14);
  static const _kGreen   = Color(0xFF1F6B48);
  static const _kGold    = Color(0xFFC5A365);
  static const _kGoldL   = Color(0xFFFFE8A6);

  // ── Casos clínicos curados en español ─────────────────────────────────────
  static const _demoCases = [
    _DemoCase(
      category: 'Urgencias',
      badge: 'Alta',
      badgeColor: Color(0xFF065F46),
      title: 'Dolor torácico con elevación del ST',
      age: '58 años • Masculino',
      dx: 'IAM con elevación del ST (STEMI) — TpI 4.2 ng/mL',
      hipotese: '',
      excerpt: 'Paciente con dolor retroesternal irradiado al brazo izquierdo, diaforesis y disnea de 40 min de evolución. ECG: elevación del ST en V1–V4. Activación del código infarto, angioplastia primaria exitosa.',
      author: 'Dr. Alejandro Ramírez',
      tags: ['Cardiología', 'STEMI', 'Código Infarto'],
    ),
    _DemoCase(
      category: 'UCI',
      badge: 'Internado',
      badgeColor: Color(0xFFC5A365),
      title: 'Sepsis de foco pulmonar con shock',
      age: '72 años • Femenino',
      dx: 'Sepsis grave — SOFA 9 — Klebsiella pneumoniae',
      hipotese: '',
      excerpt: 'Fiebre 39.8°C, PA 80/50, FC 128, FR 32, SatO₂ 86%. Inicio de antibioticoterapia empírica (Piperacilina-Tazobactam), soporte vasopresor con Noradrenalina 0.18 mcg/kg/min. VM protectora.',
      author: 'Dra. Carmen Villanueva',
      tags: ['Infectología', 'UCI', 'Sepsis'],
    ),
    _DemoCase(
      category: 'Neurología',
      badge: 'Alta',
      badgeColor: Color(0xFF065F46),
      title: 'ACV isquémico agudo — ventana trombolítica',
      age: '64 años • Masculino',
      dx: 'Accidente cerebrovascular isquémico — NIHSS 12',
      hipotese: '',
      excerpt: 'Hemiparesia derecha de inicio brusco, afasia motora. TC sin hemorragia. Dentro de ventana de 3h. tPA iv 0.9 mg/kg administrado. NIHSS post-trombólisis: 4. Alta con antiagregación dual.',
      author: 'Dr. Miguel Ángel Torres',
      tags: ['Neurología', 'ACV', 'Trombólisis'],
    ),
    _DemoCase(
      category: 'Clínica Médica',
      badge: 'Internado',
      badgeColor: Color(0xFFC5A365),
      title: 'Cetoacidosis diabética grave',
      age: '27 años • Femenino',
      dx: 'CAD grave — pH 7.14 — Glucosa 520 mg/dL',
      hipotese: '',
      excerpt: 'Debut diabético con náuseas, vómitos y dolor abdominal. K⁺ 2.9 mEq/L. Protocolo CAD: hidratación agresiva, reposición de potasio, insulina regular en infusión continua. Cierre de brecha aniónica a 18h.',
      author: 'Dra. Sofía Mendoza',
      tags: ['Endocrinología', 'CAD', 'Diabetes'],
    ),
  ];

  // ── Prescrições modelo curadas en español ──────────────────────────────────
  static const _demoRx = [
    _DemoRx(
      title: 'Sepsis — Protocolo Antibiótico Empírico',
      specialty: 'Infectología · UCI',
      indication: 'Sepsis de foco pulmonar adquirida en la comunidad',
      items: [
        '1. Piperacilina-Tazobactam 4.5 g IV c/6h (infusión extendida 4h)',
        '2. Noradrenalina 0.05–0.3 mcg/kg/min IV (titular PAM ≥65 mmHg)',
        '3. SF 0.9% 30 mL/kg en 3h (reanimación inicial)',
        '4. Hidrocortisona 200 mg/día IV (shock refractario)',
        '5. Enoxaparina 40 mg SC/día (profilaxis TVP)',
        '6. Omeprazol 40 mg IV/día (gastroprotección)',
        '7. Control glucémico: glicemia 140–180 mg/dL',
      ],
      warning: 'Ajustar antibiótico según cultivo y antibiograma a las 48–72h.',
    ),
    _DemoRx(
      title: 'STEMI — Protocolo Post-Angioplastia',
      specialty: 'Cardiología · Urgencias',
      indication: 'IAM con elevación del ST — post ACTP primaria',
      items: [
        '1. AAS 100 mg VO/día (indefinido)',
        '2. Ticagrelor 90 mg VO c/12h por 12 meses',
        '3. Atorvastatina 80 mg VO/noche',
        '4. Metoprolol succinato 25–100 mg VO/día',
        '5. Ramipril 2.5 mg VO/día (titular hasta 10 mg)',
        '6. Heparina no fraccionada IV 24h post-ACTP',
        '7. Pantoprazol 40 mg VO/día (con doble antiagregación)',
      ],
      warning: 'Evitar AINEs. Contraindicado fibrinolítico post-ACTP. Ecocardiograma a los 30 días.',
    ),
    _DemoRx(
      title: 'Cetoacidosis Diabética (CAD)',
      specialty: 'Endocrinología · Emergencias',
      indication: 'CAD grave pH <7.2 con brecha aniónica >20',
      items: [
        '1. SF 0.9% 1000 mL IV en 1h → 500 mL/h × 2h → 250 mL/h',
        '2. KCl: si K⁺ <3.5 → 40 mEq/h antes de insulina',
        '3. Insulina regular 0.1 U/kg/h IV (iniciar con K⁺ >3.5)',
        '4. Dextrosa 5% al alcanzar glucosa <250 mg/dL',
        '5. Bicarbonato: solo si pH <6.9 (50 mEq en 1h)',
        '6. Control: glucosa/hora, electrolitos c/2h, GSA c/4h',
        '7. Transición a insulina SC cuando: pH >7.3, BI <18, V.O. tolerado',
      ],
      warning: 'Riesgo de edema cerebral con corrección rápida. No suspender insulina IV hasta 2h post-SC.',
    ),
    _DemoRx(
      title: 'Crisis Hipertensiva con Daño de Órgano',
      specialty: 'Cardiología · Medicina Interna',
      indication: 'PA >180/120 mmHg con encefalopatía o EAP',
      items: [
        '1. Nitroprusiato 0.3–10 mcg/kg/min IV (titular cada 5 min)',
        '2. Furosemida 40–80 mg IV (si EAP / sobrecarga)',
        '3. Labetalol 20 mg IV en 2 min (alternativa en disección)',
        '4. Meta inicial: reducir PAM 25% en 1h',
        '5. Monitoreo invasivo de PA (arteria radial)',
        '6. Amlodipino 5–10 mg VO (mantenimiento oral posterior)',
        '7. Enalaprilato 1.25 mg IV c/6h (alternativa oral no posible)',
      ],
      warning: 'Reducción brusca de PA aumenta riesgo de ACV isquémico. Meta: 160/100 en 6h, no normalizar en urgencia.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkConsent();
  }

  Future<void> _checkConsent() async {
    final ok = await ConsentGate.hasConsented();
    if (mounted) setState(() => _hasConsented = ok);
  }

  void _onConsentAccepted() => setState(() => _hasConsented = true);

  void _goLogin() => setState(() => _showLogin = true);
  void _backToPreview() => setState(() => _showLogin = false);

  @override
  Widget build(BuildContext context) {
    // FIX DEFINITIVO: sem Navigator.push — LoginScreen inline.
    // _AuthGate troca o widget raiz quando webUser muda, sem conflito de stack.
    if (_showLogin) {
      // Consent gate Web — aguarda leitura das prefs
      if (_hasConsented == null) {
        return Theme(
          data: MedCasesApp._authTheme,
          child: const Scaffold(
            backgroundColor: Color(0xFF0F1C14),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD4A96A)),
            ),
          ),
        );
      }
      // Precisa consentir — LoginScreen coberta pelo ConsentModal
      if (!_hasConsented!) {
        return Theme(
          data: MedCasesApp._authTheme,
          child: Stack(children: [
            LoginScreen(onBack: _backToPreview),
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: ConsentModal(
                lang: 'pt',
                onAccepted: _onConsentAccepted,
              ),
            ),
          ]),
        );
      }
      // Já consentiu — LoginScreen direto
      return Theme(
        data: MedCasesApp._authTheme,
        child: LoginScreen(onBack: _backToPreview),
      );
    }
    return Scaffold(
      backgroundColor: _kDark,
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kDark, Color(0xFF1B3D2A), _kGreen],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const BrandMark(small: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('VISTA PREVIA', style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900,
                        color: Color(0xBFFFE8A6), letterSpacing: 2)),
                      const SizedBox(height: 1),
                      Text('Casos y Prescripciones',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85))),
                    ]),
                  ),
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
                const SizedBox(height: 14),
                // ── Tabs demo ──────────────────────────────────────────────
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withValues(alpha: 0.07),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(children: [
                    _DemoTab(
                      label: 'Casos Clínicos',
                      icon: Icons.folder_special_rounded,
                      active: _demoTab == 0,
                      onTap: () => setState(() => _demoTab = 0),
                      gold: _kGoldL,
                    ),
                    _DemoTab(
                      label: 'Prescripciones',
                      icon: Icons.medication_rounded,
                      active: _demoTab == 1,
                      onTap: () => setState(() => _demoTab = 1),
                      gold: _kGoldL,
                    ),
                  ]),
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
            color: _kGold.withValues(alpha: 0.10),
            border: Border.all(color: _kGold.withValues(alpha: 0.30)),
          ),
          child: Row(children: [
            const Icon(Icons.star_rounded, size: 18, color: _kGoldL),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
                  children: [
                    TextSpan(text: 'Contenido de muestra — ', style: TextStyle(color: _kGoldL.withValues(alpha: 0.9), fontWeight: FontWeight.w800)),
                    TextSpan(text: 'inicia sesión para crear, guardar y compartir tus propios casos.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65))),
                  ],
                ),
              ),
            ),
          ]),
        ),

        // ── Contenido demo ────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 100),
            children: _demoTab == 0
                ? _demoCases.map((c) => _DemoCaseCard(data: c, onTap: _goLogin)).toList()
                : _demoRx.map((r) => _DemoRxCard(data: r, onTap: _goLogin)).toList(),
          ),
        ),
      ]),

      // ── FAB fixo "Criar conta / Entrar" ─────────────────────────────────────
      floatingActionButton: GestureDetector(
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

  // ignore: unused_element
  Widget _buildError() {
    return const SizedBox.shrink();
  }

  // ignore: unused_element
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.folder_open_rounded, size: 48, color: Colors.white.withValues(alpha: 0.2)),
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


// ══════════════════════════════════════════════════════════════════════════════
// MODELOS DE DADOS PARA DEMO
// ══════════════════════════════════════════════════════════════════════════════

class _DemoCase {
  final String category;
  final String badge;
  final Color badgeColor;
  final String title;
  final String age;
  final String dx;
  final String hipotese;
  final String excerpt;
  final String author;
  final List<String> tags;
  const _DemoCase({
    required this.category, required this.badge, required this.badgeColor,
    required this.title, required this.age, required this.dx,
    required this.hipotese, required this.excerpt,
    required this.author, required this.tags,
  });
}

class _DemoRx {
  final String title;
  final String specialty;
  final String indication;
  final List<String> items;
  final String warning;
  const _DemoRx({
    required this.title, required this.specialty, required this.indication,
    required this.items, required this.warning,
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB SELECTOR DEMO
// ══════════════════════════════════════════════════════════════════════════════

class _DemoTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color gold;
  const _DemoTab({required this.label, required this.icon, required this.active,
    required this.onTap, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: active ? const Color(0xFF0F1C14) : Colors.transparent,
            border: active ? Border.all(color: gold.withValues(alpha: 0.3)) : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 13, color: active ? gold : Colors.white38),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: active ? gold : Colors.white38,
            )),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD DE CASO CLÍNICO DEMO
// ══════════════════════════════════════════════════════════════════════════════

class _DemoCaseCard extends StatelessWidget {
  final _DemoCase data;
  final VoidCallback onTap;
  const _DemoCaseCard({required this.data, required this.onTap});

  static const _kDark       = Color(0xFF0F1C14);
  static const _kGold       = Color(0xFFC5A365);
  static const _kGoldL      = Color(0xFFFFE8A6);
  static const _kCardBg     = Color(0xFF111D15);
  static const _kCardBorder = Color(0xFF1E3526);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _kCardBg,
          border: Border.all(color: _kCardBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Topo: categoria + badge + "ver completo" ─────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kCardBorder)),
            ),
            child: Row(children: [
              // Categoria
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _kDark,
                ),
                child: Text(data.category,
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _kGoldL)),
              ),
              const SizedBox(width: 6),
              // Badge outcome
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: data.badgeColor.withValues(alpha: 0.15),
                  border: Border.all(color: data.badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(data.badge,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: data.badgeColor)),
              ),
              const Spacer(),
              // Ver completo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _kGold.withValues(alpha: 0.12),
                  border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.login_rounded, size: 10, color: _kGold),
                  SizedBox(width: 4),
                  Text('Ver completo', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w800, color: _kGold)),
                ]),
              ),
            ]),
          ),

          // ── Corpo principal ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Título
              Text(data.title,
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900,
                  color: Colors.white, height: 1.2, letterSpacing: -0.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),

              // Idade/sexo
              Text(data.age, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.42))),
              const SizedBox(height: 10),

              // Diagnóstico
              if (data.dx.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFF065F46).withValues(alpha: 0.15),
                    border: Border.all(color: const Color(0xFF065F46).withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF6BCCA0)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Dx: ${data.dx}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Color(0xFF6BCCA0), height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              const SizedBox(height: 10),

              // Excerpt (trecho borrado — teaser)
              Stack(
                children: [
                  Text(data.excerpt,
                    style: TextStyle(
                      fontSize: 12, height: 1.5, fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.55)),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                  // Gradiente de blur no final para efeito "bloqueado"
                  Positioned(bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 24,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _kCardBg.withValues(alpha: 0),
                            _kCardBg.withValues(alpha: 0.92),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tags
              Wrap(spacing: 6, runSpacing: 4, children: data.tags.map((tag) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(tag, style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.4))),
                ),
              ).toList()),
              const SizedBox(height: 10),

              // Autor + lock
              Row(children: [
                const Icon(Icons.person_outline_rounded, size: 12, color: Color(0xFF4A7A5A)),
                const SizedBox(width: 5),
                Expanded(child: Text(data.author,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: Color(0xFF4A7A5A)),
                  overflow: TextOverflow.ellipsis)),
                const Icon(Icons.lock_rounded, size: 10, color: Color(0xFF3A5A46)),
                const SizedBox(width: 4),
                Text('Iniciar sesión para leer todo',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.22))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARD DE PRESCRIÇÃO DEMO
// ══════════════════════════════════════════════════════════════════════════════

class _DemoRxCard extends StatelessWidget {
  final _DemoRx data;
  final VoidCallback onTap;
  const _DemoRxCard({required this.data, required this.onTap});

  static const _kDark       = Color(0xFF0F1C14);
  static const _kGold       = Color(0xFFC5A365);
  static const _kGoldL      = Color(0xFFFFE8A6);
  static const _kCardBg     = Color(0xFF111D15);
  static const _kCardBorder = Color(0xFF1E3526);

  @override
  Widget build(BuildContext context) {
    // Mostra apenas os 3 primeiros itens + "bloqueado" no resto
    final visibleItems = data.items.take(3).toList();
    final lockedCount  = data.items.length - visibleItems.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: _kCardBg,
          border: Border.all(color: _kCardBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header do card ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F1C14), Color(0xFF183024), Color(0xFF1A4A32)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Especialidade + ícone
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _kGold.withValues(alpha: 0.15),
                  ),
                  child: const Icon(Icons.medication_rounded, size: 14, color: _kGoldL),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.specialty, style: const TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w900,
                    color: Color(0xBFFFE8A6), letterSpacing: 1.5)),
                  const SizedBox(height: 1),
                  Text(data.title, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w900,
                    color: Colors.white, letterSpacing: -0.2),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ])),
                // Badge "Modelo"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _kGold.withValues(alpha: 0.12),
                    border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                  ),
                  child: const Text('Modelo', style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w900, color: _kGold)),
                ),
              ]),
              const SizedBox(height: 8),
              // Indicação
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.06),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 11,
                    color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(data.indication,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.6)),
                    maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ]),
          ),

          // ── Itens visíveis da prescrição ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final item in visibleItems) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3, right: 8),
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4ADE80),
                      ),
                    ),
                    Expanded(child: Text(item,
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: Colors.white70, height: 1.4))),
                  ]),
                ),
              ],

              // Itens bloqueados
              if (lockedCount > 0) ...[
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: _kGold.withValues(alpha: 0.08),
                      border: Border.all(color: _kGold.withValues(alpha: 0.25)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.lock_rounded, size: 12, color: _kGold),
                      const SizedBox(width: 6),
                      Text('+$lockedCount ítems — Iniciar sesión para ver todo',
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: _kGold)),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ]),
          ),

          // ── Aviso clínico ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF92400E).withValues(alpha: 0.12),
              border: Border.all(color: const Color(0xFF92400E).withValues(alpha: 0.35)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFFFB347)),
              const SizedBox(width: 7),
              Expanded(child: Text(data.warning,
                style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: Color(0xFFFFB347), height: 1.4))),
            ]),
          ),

          // ── CTA final ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _kDark,
                  border: Border.all(color: _kGold.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.login_rounded, size: 14, color: _kGoldL),
                  const SizedBox(width: 7),
                  const Text('Crear cuenta para guardar y usar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _kGoldL)),
                ]),
              ),
            ),
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
  // Header recolhível: visível apenas na tab 0 (Cockpit/Início)
  // ignore: unused_element
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
    final bg = dark ? const Color(0xFF101E16) : const Color(0xFFF7F8FA);
    final navBg = dark ? const Color(0xFF121F17) : Colors.white;
    final navBorder = dark ? const Color(0xFF1E3526) : const Color(0xFFE8E1D2);

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

// ── Drawer lateral estilo banco (desliza da direita) ─────────────────────────
class _AppDrawer extends StatelessWidget {
  final AppProvider p;
  const _AppDrawer({required this.p});

  static const _kDark  = Color(0xFF0F1C14);
  static const _kGreen = Color(0xFF1F6B48);
  static const _kGold  = Color(0xFFC5A365);
  static const _kGoldL = Color(0xFFFFE8A6);

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
    final dark = p.darkMode;
    final bg      = dark ? const Color(0xFF0B1510) : Colors.white;
    final divider = dark ? const Color(0xFF1E3526) : const Color(0xFFEEEBE4);
    final textCol = dark ? Colors.white : _kDark;
    final subCol  = dark ? Colors.white.withValues(alpha: 0.38) : const Color(0xFF888888);

    // Iniciais para o avatar no drawer
    final initials = p.userName.isNotEmpty
        ? p.userName.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : 'M';

    return Drawer(
      width: 292,
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Cabeçalho do drawer ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0A1610), Color(0xFF162E1F), Color(0xFF1A5C3A)],
                  stops: [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Linha topo: logo + fechar
                Row(children: [
                  const BrandMark(small: false),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _close(context),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(Icons.close_rounded, size: 15,
                          color: Colors.white.withValues(alpha: 0.65)),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // Avatar + nome lado a lado
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  // Avatar circular
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F4030), Color(0xFF162A1C)],
                      ),
                      border: Border.all(
                        color: _kGold.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFE8A6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nome + profissão
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        p.userName.isNotEmpty ? p.userName : 'MedCases Pro',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.2,
                          height: 1.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (p.currentUser?.profession?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 3),
                        Text(
                          p.currentUser!.profession!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.52),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (p.currentUser?.institution?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 1),
                        Text(
                          p.currentUser!.institution!,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.35),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ]),
                  ),
                ]),
                // Badge admin
                if (p.isAdmin || p.isMaster) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: _kGold.withValues(alpha: 0.15),
                      border: Border.all(color: _kGold.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      p.isMaster ? 'MASTER' : 'ADMIN',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: _kGoldL,
                        letterSpacing: 0.8,
                      ),
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

                  // ── Legal ───────────────────────────────────────────────
                  _DrawerItem(
                    icon: Icons.article_outlined,
                    iconColor: const Color(0xFF546E7A),
                    title: p.lang == 'es' ? 'Términos de Uso' : 'Termos de Uso',
                    subtitle: p.lang == 'es' ? 'Condiciones del servicio' : 'Condições do serviço',
                    dark: dark,
                    textCol: textCol,
                    subCol: subCol,
                    onTap: () {
                      _close(context);
                      showLegalSheet(context, LegalType.terms, p.lang);
                    },
                  ),

                  Divider(height: 1, color: divider, indent: 16, endIndent: 16),

                  _DrawerItem(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF546E7A),
                    title: p.lang == 'es' ? 'Política de Privacidad' : 'Política de Privacidade',
                    subtitle: p.lang == 'es' ? 'LGPD · Protección de datos' : 'LGPD · Proteção de dados',
                    dark: dark,
                    textCol: textCol,
                    subCol: subCol,
                    onTap: () {
                      _close(context);
                      showLegalSheet(context, LegalType.privacy, p.lang);
                    },
                  ),

                  Divider(height: 1, color: divider, indent: 16, endIndent: 16),

                  _DrawerItem(
                    icon: Icons.delete_forever_rounded,
                    iconColor: const Color(0xFFCC3333),
                    title: p.lang == 'es' ? 'Eliminar Cuenta' : 'Eliminar Conta',
                    subtitle: p.lang == 'es' ? 'Elimina tus datos permanentemente' : 'Remove seus dados permanentemente',
                    dark: dark,
                    textCol: textCol,
                    subCol: subCol,
                    onTap: () {
                      _close(context);
                      _showDeleteAccountDialog(context, p);
                    },
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
                p.lang == 'es'
                    ? 'MedCases Pro · Solo uso educativo'
                    : 'MedCases Pro · Uso educacional',
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
      borderRadius: BorderRadius.circular(8),
      splashColor: iconColor.withValues(alpha: 0.06),
      highlightColor: iconColor.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: iconColor.withValues(alpha: 0.10),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.22),
                width: 0.8,
              ),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textCol,
                letterSpacing: -0.1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: subCol,
                fontWeight: FontWeight.w400,
              ),
            ),
          ])),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else ...[
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: subCol.withValues(alpha: 0.5),
            ),
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

