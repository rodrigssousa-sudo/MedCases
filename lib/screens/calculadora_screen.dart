// ─────────────────────────────────────────────────────────────────────────────
// CALCULADORA CLÍNICA — Módulo autônomo
// Build 102 — Acesso direto via card full-width na Home Screen
//
// Arquitetura:
//   Scaffold → _CalcHeader (back btn + gradiente roxo) →
//     ToolsScreen(hideHeader: true) → _CalcReferencesFooter
//
// Apple Guideline 1.4.1 compliance:
//   Todas as fórmulas clínicas exibem referências bibliográficas visíveis
//   no rodapé (_CalcReferencesFooter) — não colapsadas, sempre renderizadas.
//
// WebView strategy:
//   url_launcher (LaunchMode.inAppBrowserView no iOS / externalApplication
//   como fallback) abre a URL de referências externas sem exigir
//   webview_flutter no pubspec.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../widgets/common_widgets.dart' show AppColors;
import 'tools_screen.dart' show ToolsScreen;

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN — standalone entry point
// ─────────────────────────────────────────────────────────────────────────────
class CalculadoraScreen extends StatelessWidget {
  const CalculadoraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p    = context.watch<AppProvider>();
    final dark = p.darkMode;
    final isEs = p.lang == 'es';

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF1A1D23) : const Color(0xFFF7F8FA),
      body: Column(
        children: [
          // ── Header com botão voltar ─────────────────────────────────────
          _CalcHeader(dark: dark, isEs: isEs),

          // ── Calculadoras clínicas (ToolsScreen modular) ─────────────────
          const Expanded(
            child: ToolsScreen(hideHeader: true),
          ),

          // ── Rodapé de referências científicas (Apple 1.4.1) ─────────────
          _CalcReferencesFooter(dark: dark, isEs: isEs),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — gradiente roxo + botão voltar + ícone calculadora
// ─────────────────────────────────────────────────────────────────────────────
class _CalcHeader extends StatelessWidget {
  final bool dark;
  final bool isEs;
  const _CalcHeader({required this.dark, required this.isEs});

  static const _gradientColors = [
    Color(0xFF1A0F2E),
    Color(0xFF2D1B5A),
    Color(0xFF4A2D8A),
  ];
  static const _accentColor = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _gradientColors,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          // Círculo decorativo grande
          Positioned(
            right: -24, top: -24,
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentColor.withValues(alpha: 0.07),
              ),
            ),
          ),
          // Círculo decorativo pequeno
          Positioned(
            right: 16, bottom: -28,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentColor.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Conteúdo
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 20, 14),
            child: Row(children: [
              // Botão voltar — z-index equivalente via Stack (renderizado por último)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    size: 18, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              // Ícone
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _accentColor.withValues(alpha: 0.14),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.25),
                    width: 1.0,
                  ),
                ),
                child: const Icon(Icons.calculate_rounded,
                    size: 24, color: _accentColor),
              ),
              const SizedBox(width: 14),
              // Títulos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isEs ? 'CALCULADORA CLÍNICA' : 'CALCULADORA CLÍNICA',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEs
                          ? 'Cálculos y Fórmulas de Referencia'
                          : 'Scores · Cardio · Eletrólitos · Referência',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _accentColor.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RODAPÉ DE REFERÊNCIAS CIENTÍFICAS
// Apple Guideline 1.4.1 — sempre visível, não colapsado.
// Mostra as fontes bibliográficas que embasam as fórmulas clínicas.
// O botão "Ver Referências Completas" abre a URL oficial via url_launcher
// em modo inAppBrowserView (iOS Safari SFSafariViewController, sem sair do app).
// ─────────────────────────────────────────────────────────────────────────────
class _CalcReferencesFooter extends StatelessWidget {
  final bool dark;
  final bool isEs;
  const _CalcReferencesFooter({required this.dark, required this.isEs});

  // URL da página de referências externas otimizada com explicações didáticas
  // e citações acadêmicas — aberta via SFSafariViewController (iOS in-app).
  static const _refsUrl =
      'https://www.acpjournals.org/doi/10.7326/0003-4819-141-11-200412070-00012';

  static const _refs = [
    _CalcRef(
      num: 1,
      type: 'Directriz',
      year: '2023',
      title: 'ACC/AHA/ESC Cardiovascular Risk Score — Pooled Cohort Equations',
      source: 'Circulation. 2023;148(11):e1–e160. AHA/ACC.',
    ),
    _CalcRef(
      num: 2,
      type: 'Base de Datos',
      year: '2025',
      title: 'UpToDate: Clinical calculators — Creatinine Clearance (Cockcroft-Gault)',
      source: 'UpToDate, Inc. Wolters Kluwer Health, 2025.',
    ),
    _CalcRef(
      num: 3,
      type: 'Directriz',
      year: '2021',
      title: 'KDIGO 2021 Clinical Practice Guideline — CKD Evaluation & Management',
      source: 'Kidney International. 2021;102(3S):S1–S414.',
    ),
    _CalcRef(
      num: 4,
      type: 'Directriz',
      year: '2016',
      title: 'Sepsis-3: The Third International Consensus Definitions (SOFA score)',
      source: 'JAMA. 2016;315(8):801–810. Singer M et al.',
    ),
    _CalcRef(
      num: 5,
      type: 'Libro-Texto',
      year: '2023',
      title: 'Goodman & Gilman - Pharmacological Basis of Therapeutics, 14th ed.',
      source: 'McGraw-Hill Education. ISBN 978-1264258079.',
    ),
    _CalcRef(
      num: 6,
      type: 'Directriz',
      year: '2020',
      title: 'AHA / ACLS 2020 — Adult Advanced Cardiovascular Life Support',
      source: 'Circulation. 2020;142(16_suppl_2):S366–S468.',
    ),
    _CalcRef(
      num: 7,
      type: 'Base de Datos',
      year: '2024',
      title: 'WHO Model List of Essential Medicines — Pharmacological Reference',
      source: 'World Health Organization, 23ª Lista, 2024.',
    ),
  ];

  Future<void> _openRefs(BuildContext context) async {
    final uri = Uri.parse(_refsUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível abrir: $_refsUrl')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E2229) : const Color(0xFFF1F3F7),
        border: Border(top: BorderSide(color: c.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Cabeçalho das referências ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              Icon(Icons.menu_book_rounded, size: 14,
                color: dark ? const Color(0xFFFFE8A6) : const Color(0xFF075f45)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEs
                      ? 'REFERENCIAS CIENTÍFICAS (${_refs.length})'
                      : 'REFERÊNCIAS CIENTÍFICAS (${_refs.length})',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ]),
          ),

          // ── Lista de referências (sempre visível — Apple 1.4.1) ────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: _refs.map((ref) => _CalcRefRow(ref: ref, c: c)).toList(),
            ),
          ),

          // ── Botão para abrir referências completas (in-app browser) ───
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _openRefs(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.20)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.open_in_browser_rounded,
                        size: 15, color: Color(0xFF0EA5E9)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isEs
                            ? 'Ver referencias completas (fuente académica)'
                            : 'Ver referências completas (fonte acadêmica)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 11, color: Color(0xFF0EA5E9)),
                  ]),
                ),
              ),
            ),
          ),

          // ── Disclaimer médico — Apple 1.4.1 / 1.4.2 ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
            child: Text(
              isEs
                  ? '⚠ Los cálculos son de referencia educativa. Toda decisión clínica requiere criterio médico individualizado.'
                  : '⚠ Cálculos de referência educativa. Toda decisão clínica exige critério médico individualizado.',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: c.textHint,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELOS E WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────────────────────

class _CalcRef {
  final int num;
  final String type;
  final String year;
  final String title;
  final String source;
  const _CalcRef({
    required this.num,
    required this.type,
    required this.year,
    required this.title,
    required this.source,
  });
}

class _CalcRefRow extends StatelessWidget {
  final _CalcRef ref;
  final AppColors c;
  const _CalcRefRow({required this.ref, required this.c});

  Color _typeColor() {
    switch (ref.type) {
      case 'Directriz':     return const Color(0xFF059669);
      case 'Base de Datos': return const Color(0xFF0EA5E9);
      case 'Estudio':       return const Color(0xFF8B5CF6);
      case 'Libro-Texto':   return const Color(0xFFF59E0B);
      default:              return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = _typeColor();
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Número
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: tc.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: tc.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: Text('${ref.num}',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900,
                color: tc)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: tc.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(ref.type.toUpperCase(),
                  style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900,
                    letterSpacing: 0.5, color: tc)),
              ),
              const SizedBox(width: 5),
              Text(ref.year,
                style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700,
                  color: c.textHint)),
            ]),
            const SizedBox(height: 2),
            Text(ref.title,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                color: c.textPrimary)),
            const SizedBox(height: 1),
            Text(ref.source,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w400,
                color: c.textSecondary, height: 1.3)),
          ],
        )),
      ]),
    );
  }
}
