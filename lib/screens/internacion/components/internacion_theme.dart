// ─────────────────────────────────────────────────────────────────────────────
// InternacionTheme — tokens de cor e tipografia compartilhados entre
// todos os sub-widgets da tela Internación y Evolución.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

class InternacionTheme {
  final bool dark;
  const InternacionTheme(this.dark);

  // Cores semânticas
  static const cyan       = Color(0xFF00E5FF);
  static const cyanDark   = Color(0xFF008CA4);
  static const green      = Color(0xFF22C55E);
  static const amber      = Color(0xFFF59E0B);
  static const red        = Color(0xFFEF4444);

  // Superfícies
  Color get surface    => dark ? const Color(0xFF161920) : Colors.white;
  Color get surfaceAlt => dark ? const Color(0xFF1E2330) : const Color(0xFFF8F9FA);
  Color get card       => dark ? const Color(0xFF1A1E28) : const Color(0xFFF0F2F5);
  Color get border     => dark ? const Color(0xFF2D3340) : const Color(0xFFDDE1E6);
  Color get divider    => dark ? const Color(0xFF232836) : const Color(0xFFEBEDF0);

  // Texto
  Color get textPrimary   => dark ? Colors.white : const Color(0xFF1A1D23);
  Color get textSecondary => dark ? Colors.white.withValues(alpha: 0.55)
                                  : const Color(0xFF6B7280);
  Color get labelColor    => dark ? Colors.white.withValues(alpha: 0.35)
                                  : const Color(0xFF9CA3AF);

  // Seções SOAP — cor da letra da tag
  Color soapTagBg(SoapSection s) {
    switch (s) {
      case SoapSection.s: return const Color(0xFF3B82F6).withValues(alpha: 0.15);
      case SoapSection.o: return const Color(0xFF22C55E).withValues(alpha: 0.13);
      case SoapSection.a: return const Color(0xFFF59E0B).withValues(alpha: 0.13);
      case SoapSection.p: return const Color(0xFF8B5CF6).withValues(alpha: 0.13);
    }
  }

  Color soapTagFg(SoapSection s) {
    switch (s) {
      case SoapSection.s: return const Color(0xFF60A5FA);
      case SoapSection.o: return const Color(0xFF4ADE80);
      case SoapSection.a: return const Color(0xFFFBBF24);
      case SoapSection.p: return const Color(0xFFA78BFA);
    }
  }

  // Bordas e sombra do card SOAP
  BoxDecoration soapCardDecoration(SoapSection s) => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: border, width: 0.8),
  );

  // Sombra sutil
  BoxShadow get softShadow => BoxShadow(
    color: Colors.black.withValues(alpha: dark ? 0.30 : 0.06),
    blurRadius: 8,
    offset: const Offset(0, 2),
  );
}

enum SoapSection { s, o, a, p }

extension SoapSectionLabel on SoapSection {
  String get tag => name.toUpperCase();

  String title(String lang) {
    final isEs = lang == 'es';
    switch (this) {
      case SoapSection.s: return isEs ? 'Subjetivo' : 'Subjetivo';
      case SoapSection.o: return isEs ? 'Objetivo'  : 'Objetivo';
      case SoapSection.a: return isEs ? 'Evaluación' : 'Avaliação';
      case SoapSection.p: return isEs ? 'Plan'       : 'Plano';
    }
  }

  String subtitle(String lang) {
    final isEs = lang == 'es';
    switch (this) {
      case SoapSection.s:
        return isEs ? 'Queja principal · Síntomas · Noche'
                    : 'Queixa principal · Sintomas · Noite';
      case SoapSection.o:
        return isEs ? 'Signos vitales · Examen físico · Labs'
                    : 'Sinais vitais · Exame físico · Exames';
      case SoapSection.a:
        return isEs ? 'Impresión clínica · Problemas activos'
                    : 'Impressão clínica · Problemas ativos';
      case SoapSection.p:
        return isEs ? 'Plan terapéutico · Criterios de alta'
                    : 'Plano terapêutico · Critérios de alta';
    }
  }
}
