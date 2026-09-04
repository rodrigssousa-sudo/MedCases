// ─────────────────────────────────────────────────────────────────────────────
// InternacionTheme — Build 162 — Tokens de cor premium sem neon
//
// PURGA NEON (Build 162):
//   • Removidos TODOS os tons cyan/neon (#00E5FF, #00C6E0, #008CA4) dos dois temas.
//   • Substitutos: verde corporativo sóbrio (#059669 light / #34D399 dark)
//     alinhado ao padrão dos cards ADULTO do app.
//   • Modo claro: fundos soft-grey/white, textos dark-charcoal (#111827), zero neon.
//   • Modo escuro: identidade dark premium, contrastes revisados para uso em
//     ambientes de baixa luminosidade (plantão noturno).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

// MEDCASES_PACIENTES_PHYSICAL_SURFACE_CONTRACT_V1
const Color kPacientesPageLightPhysical = Color(0xFFECF1F3);
const Color kPacientesCardLightPhysical = Color(0xFFFFFFFF);
const Color kPacientesPageDarkPhysical = Color(0xFF1A1D23);
const Color kPacientesCardDarkPhysical = Color(0xFF252930);
const Color kPacientesBorderLightPhysical = Color(0xFFD8DEE7);
const Color kPacientesBorderDarkPhysical = Color(0xFF374151);

class InternacionTheme {
  final bool dark;
  const InternacionTheme(this.dark);

  // ── Cor de destaque principal — verde corporativo sóbrio ─────────────────
  // Light: verde vibrante mas controlado (#059669 — Emerald 600)
  // Dark:  verde luminoso para contraste noturno (#34D399 — Emerald 400)
  static const Color accentLight = Color(0xFF0D6B57); // accent canônico MedCases
  static const Color accentDark = Color(0xFF0D6B57); // accent canônico MedCases

  /// Verde de destaque atual dependente do contexto — usa nos lugares onde
  /// o código anterior usava `InternacionTheme.cyan`.
  Color get accent => dark ? accentDark : accentLight;

  // ── Cores semânticas (mantidas, sem alteração) ───────────────────────────
  static const Color green = Color(0xFF22C55E);

  // Semantic/status tokens: visually preserve the pre-split green.
  static const Color semanticSuccess = Color(0xFF059669);
  static const Color semanticStable = Color(0xFF059669);
  static const Color semanticProcessing = Color(0xFF059669);
  static const Color semanticActiveStatus = Color(0xFF059669);

  // Clinical/taxonomy tokens that must not inherit the brand accent.
  static const Color evolutionAccent = Color(0xFF059669);
  Color get pharmaAccent =>
      dark ? const Color(0xFF34D399) : const Color(0xFF059669);
  static const Color amber = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);

  // ── Compat: alias estático para código legado que use InternacionTheme.cyan
  // Aponta para a cor de destaque light — sem neon, verde corporativo.
  static const Color cyan = Color(0xFF0D6B57); // compat alias -> canonical brand
  static const Color cyanDark = Color(0xFF0D6B57); // compat alias -> canonical brand

  // ── Superfícies ──────────────────────────────────────────────────────────
  // Light: fundos brancos/cinza suave — limpeza visual total
  // Dark:  paleta dark rica sem tons de azul gelo
  Color get surface => dark ? const Color(0xFF1A1D23) : const Color(0xFFECF1F3);
  Color get surfaceAlt =>
      dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
  Color get card => dark ? const Color(0xFF252930) : const Color(0xFFFFFFFF);
  Color get border => dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);
  Color get divider => dark ? const Color(0xFF374151) : const Color(0xFFD8DEE7);

  // ── Texto ─────────────────────────────────────────────────────────────────
  // Light: dark charcoal (#111827) — legibilidade máxima, zero interferência neon
  // Dark:  branco com alphas calibrados para plantão noturno
  Color get textPrimary => dark
      ? Colors.white.withOpacity(0.93)
      : const Color(0xFF111827); // Charcoal — alto contraste

  Color get textSecondary =>
      dark ? const Color(0xFFB2C0D0) : const Color(0xFF4B5563);

  Color get labelColor =>
      dark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

  // ── Seções SOAP — paleta interna mantida (azul S, verde O, âmbar A, violeta P)
  // Cores de FOREGROUND calibradas por modo para contraste adequado
  Color soapTagBg(SoapSection s) {
    switch (s) {
      case SoapSection.s:
        return dark
            ? const Color(0xFF3B82F6).withOpacity(0.18)
            : const Color(0xFF3B82F6).withOpacity(0.10);
      case SoapSection.o:
        return dark
            ? const Color(0xFF22C55E).withOpacity(0.16)
            : const Color(0xFF22C55E).withOpacity(0.10);
      case SoapSection.a:
        return dark
            ? const Color(0xFFF59E0B).withOpacity(0.16)
            : const Color(0xFFF59E0B).withOpacity(0.10);
      case SoapSection.p:
        return dark
            ? const Color(0xFF8B5CF6).withOpacity(0.16)
            : const Color(0xFF8B5CF6).withOpacity(0.10);
    }
  }

  Color soapTagFg(SoapSection s) {
    // Dark: cores vivas para legibilidade noturna
    // Light: cores escurecidas para contraste sobre fundo branco
    switch (s) {
      case SoapSection.s:
        return dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
      case SoapSection.o:
        return dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      case SoapSection.a:
        return dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case SoapSection.p:
        return dark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
    }
  }

  // ── Decoration de card SOAP (helper) ─────────────────────────────────────
  BoxDecoration soapCardDecoration(SoapSection s) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 0.7),
      );

  // ── Sombra sutil ──────────────────────────────────────────────────────────
  BoxShadow get softShadow => const BoxShadow(
        color: Colors.transparent,
        blurRadius: 0,
        offset: Offset.zero,
      );

  // ── Gradient de destaque (botões de ação primária) ───────────────────────
  // Substituído: era [#00C6E0 → #0051C3] (neon). Agora: verde escuro premium.
  LinearGradient get accentGradient => dark
      ? const LinearGradient(
          colors: [Color(0xFF0D6B57), Color(0xFF0D6B57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      : const LinearGradient(
          colors: [Color(0xFF0D6B57), Color(0xFF0D6B57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
}

enum SoapSection { s, o, a, p }

extension SoapSectionLabel on SoapSection {
  String get tag => name.toUpperCase();

  String title(String lang) {
    final isEs = lang == 'es';
    switch (this) {
      case SoapSection.s:
        return isEs ? 'Subjetivo' : 'Subjetivo';
      case SoapSection.o:
        return isEs ? 'Objetivo' : 'Objetivo';
      case SoapSection.a:
        return isEs ? 'Evaluación' : 'Avaliação';
      case SoapSection.p:
        return isEs ? 'Plan' : 'Plano';
    }
  }

  String subtitle(String lang) {
    final isEs = lang == 'es';
    switch (this) {
      case SoapSection.s:
        return isEs
            ? 'Queja principal · Síntomas · Noche'
            : 'Queixa principal · Sintomas · Noite';
      case SoapSection.o:
        return isEs
            ? 'Signos vitales · Examen físico · Labs'
            : 'Sinais vitais · Exame físico · Exames';
      case SoapSection.a:
        return isEs
            ? 'Impresión clínica · Problemas activos'
            : 'Impressão clínica · Problemas ativos';
      case SoapSection.p:
        return isEs
            ? 'Plan terapéutico · Criterios de alta'
            : 'Plano terapêutico · Critérios de alta';
    }
  }
}
