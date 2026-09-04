// ─────────────────────────────────────────────────────────────────────────────
// MedCases Pro — Paleta de cores centralizada
// Modo noturno otimizado: cinza neutro moderno, confortável para uso prolongado
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

// ── BACKGROUNDS ──────────────────────────────────────────────────────────────
/// Fundo principal de todas as telas
const kBgPrimary   = Color(0xFF1A1D23);
/// Cards, modais, chat bubbles, list items elevados
const kBgSecondary = Color(0xFF252930);
/// Header superior, status bar, bottom navigation
const kBgHeader    = Color(0xFF0F1116);
/// Campos de input, search bars
const kBgInput     = Color(0xFF252930);

// ── TEXTOS ───────────────────────────────────────────────────────────────────
/// Títulos, headings, texto principal
const kTextPrimary   = Color(0xFFFFFFFF);
/// Subtítulos, descrições, metadados
const kTextSecondary = Color(0xFFA8B2C1);
/// Placeholders, hints, texto desabilitado leve
const kTextTertiary  = Color(0xFF6B7280);
/// Texto inativo/desabilitado
const kTextDisabled  = Color(0xFF4B5563);

// ── BORDAS E DIVISORES ────────────────────────────────────────────────────────
/// Separadores de lista, divisores sutis
const kBorderSoft   = Color(0xFF2D3340);
/// Bordas de cards, containers
const kBorderCard   = Color(0xFF374151);
/// Borda de input focado, elemento ativo
const kBorderActive = Color(0xFF0D6B57);

// ── CORES DE DESTAQUE (accent) ────────────────────────────────────────────────
/// IA, botões principais, elementos ativos
const kAccentBrand = Color(0xFF0D6B57);
/// PEDIATRÍA, links, ações secundárias
const kAccentBlue    = Color(0xFF3B82F6);
/// ADULTO, sucesso
const kAccentGreen   = Color(0xFF10B981);
/// FÁRMACOS, avisos
const kAccentOrange  = Color(0xFFF59E0B);
/// INTERACCIONES
const kAccentMagenta = Color(0xFFEC4899);
/// Erros, exclusões
const kAccentRed     = Color(0xFFEF4444);
/// Favoritos, roxo
const kAccentPurple  = Color(0xFFA855F7);
/// Destaques dourados
const kAccentYellow  = Color(0xFFFBBF24);

// ── SEMÂNTICO ─────────────────────────────────────────────────────────────────
const kSuccess = kAccentGreen;
const kWarning = kAccentOrange;
const kError   = kAccentRed;
const kInfo    = kAccentBlue;

// ── SOMBRAS ───────────────────────────────────────────────────────────────────
const kShadowCard = [
  BoxShadow(
    color: Color(0x26000000),
    offset: Offset(0, 2),
    blurRadius: 8,
    spreadRadius: 0,
  ),
];

const kShadowModal = [
  BoxShadow(
    color: Color(0x40000000),
    offset: Offset(0, 8),
    blurRadius: 16,
    spreadRadius: 0,
  ),
];

const kShadowFloating = [
  BoxShadow(
    color: Color(0x4D0D6B57),
    offset: Offset(0, 4),
    blurRadius: 12,
    spreadRadius: 0,
  ),
];

// ── THEME DATA ────────────────────────────────────────────────────────────────
ThemeData buildDarkTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBgPrimary,
    cardColor: kBgSecondary,
    dividerColor: kBorderSoft,
    colorScheme: const ColorScheme.dark(
      primary:                 kAccentBrand,
      onPrimary:               Colors.white,
      secondary:               kAccentBrand,
      onSecondary:             Colors.white,
      surface:                 kBgSecondary,
      onSurface:               kTextPrimary,
      surfaceContainerHighest: kBgSecondary,
      surfaceContainerHigh:    kBgSecondary,
      surfaceContainer:        kBgSecondary,
      surfaceContainerLow:     kBgPrimary,
      surfaceDim:              kBgHeader,
      outline:                 kBorderCard,
      outlineVariant:          kBorderSoft,
      error:                   kAccentRed,
      inverseSurface:          kTextPrimary,
      onInverseSurface:        kBgHeader,
    ),
    textTheme: const TextTheme(
      bodyLarge:   TextStyle(color: kTextPrimary),
      bodyMedium:  TextStyle(color: kTextPrimary),
      bodySmall:   TextStyle(color: kTextSecondary),
      titleLarge:  TextStyle(color: kTextPrimary),
      titleMedium: TextStyle(color: kTextPrimary),
      titleSmall:  TextStyle(color: kTextSecondary),
      labelLarge:  TextStyle(color: kTextPrimary),
      labelMedium: TextStyle(color: kTextSecondary),
      labelSmall:  TextStyle(color: kTextTertiary),
    ),
  );
}
