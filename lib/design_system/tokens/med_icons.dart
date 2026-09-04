import 'package:flutter/material.dart';

/// Catálogo base e escala oficial de ícones do MedCases Next.
///
/// Os aliases evitam que novos módulos dependam diretamente de escolhas
/// específicas de ícones espalhadas pelas telas.
abstract final class MedIcons {
  static const double small = 16;
  static const double medium = 20;
  static const double large = 24;
  static const double xLarge = 32;

  static const IconData home = Icons.home_outlined;
  static const IconData homeSelected = Icons.home_rounded;
  static const IconData ai = Icons.auto_awesome_outlined;
  static const IconData calculator = Icons.calculate_outlined;
  static const IconData pharmacology = Icons.medication_outlined;
  static const IconData history = Icons.history_outlined;
  static const IconData settings = Icons.settings_outlined;
  static const IconData search = Icons.search_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData forward = Icons.arrow_forward_rounded;
  static const IconData expand = Icons.expand_more_rounded;
  static const IconData collapse = Icons.expand_less_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData remove = Icons.remove_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData copy = Icons.content_copy_outlined;
  static const IconData share = Icons.share_outlined;
  static const IconData favorite = Icons.favorite_border_rounded;
  static const IconData favoriteSelected = Icons.favorite_rounded;
  static const IconData information = Icons.info_outline_rounded;
  static const IconData success = Icons.check_circle_outline_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData premium = Icons.workspace_premium_outlined;
  static const IconData person = Icons.person_outline_rounded;
  static const IconData menu = Icons.menu_rounded;
  static const IconData more = Icons.more_horiz_rounded;
}
