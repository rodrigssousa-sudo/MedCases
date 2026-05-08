import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/login_screen.dart';
import 'screens/cockpit_screen.dart';
import 'screens/drugs_screen.dart';
import 'screens/protocols_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/ai_screen.dart';
import 'screens/cases_screen.dart';
import 'widgets/brand_mark.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final provider = AppProvider();
  await provider.loadPrefs();
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
      home: p.loggedIn ? const MainShell() : const LoginScreen(),
    );
  }

  ThemeData _buildTheme(bool dark) {
    return ThemeData(
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
      scaffoldBackgroundColor: dark ? const Color(0xFF0A1510) : const Color(0xFFF5F0E8),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  String? _pendingProtocolId;

  void _openProtocol(String id) {
    setState(() {
      _tab = 2;
      _pendingProtocolId = id;
    });
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

    final navItems = [
      _NavItem(icon: Icons.home_rounded, label: p.t('cockpit')),
      _NavItem(icon: Icons.medication_rounded, label: p.t('drugs')),
      _NavItem(icon: Icons.emergency_rounded, label: p.t('protocols')),
      _NavItem(icon: Icons.calculate_rounded, label: p.t('tools')),
      _NavItem(icon: Icons.psychology_rounded, label: p.t('ai')),
      _NavItem(icon: Icons.folder_open_rounded, label: p.t('cases')),
    ];

    return Scaffold(
      backgroundColor: bg,
      body: Column(children: [
        _AppHeader(onTabChange: (t) => setState(() => _tab = t), currentTab: _tab),
        Expanded(child: IndexedStack(index: _tab, children: screens)),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(top: BorderSide(color: navBorder, width: 1)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: navItems.asMap().entries.map((e) {
                final idx = e.key;
                final item = e.value;
                final active = _tab == idx;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _tab = idx),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: active ? const Color(0xFF07110d) : Colors.transparent,
                        ),
                        child: Icon(item.icon, size: 20,
                          color: active ? const Color(0xFFFFE8A6) : (dark ? Colors.white38 : const Color(0xFF888888))),
                      ),
                      const SizedBox(height: 2),
                      Text(item.label,
                        style: TextStyle(
                          fontSize: 9, fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                          color: active ? const Color(0xFF07110d) : (dark ? Colors.white38 : const Color(0xFF888888)),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
              Text(p.userName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white), overflow: TextOverflow.ellipsis),
              Text(p.lang == 'es' ? 'Apoyo clínico educativo' : 'Apoio clínico educacional',
                style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.55), fontWeight: FontWeight.w600)),
            ])),
            // Lang toggle
            GestureDetector(
              onTap: () => p.setLang(p.lang == 'pt' ? 'es' : 'pt'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                child: Text(p.lang.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFFFE8A6), letterSpacing: 1)),
              ),
            ),
            const SizedBox(width: 8),
            // Dark mode toggle
            GestureDetector(
              onTap: () => p.toggleDarkMode(),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white.withValues(alpha: 0.1), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                child: Icon(dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 16, color: const Color(0xFFFFE8A6)),
              ),
            ),
            const SizedBox(width: 8),
            // Logout
            GestureDetector(
              onTap: () => p.logout(),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.red.withValues(alpha: 0.15), border: Border.all(color: Colors.red.withValues(alpha: 0.25))),
                child: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFFFAAAA)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
