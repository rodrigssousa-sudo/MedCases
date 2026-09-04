import 'package:flutter/material.dart';

/// Identidade cromática exclusivamente dos ícones da Home V2.
///
/// Não define fundos, textos, bordas, divisores, estados clínicos ou lógica.
abstract final class HomeV2IconPalette {
  static const Color farmacosLight = Color(0xFF087F7B);
  static const Color farmacosDark = Color(0xFF2DD4BF);

  static const Color pacienteLight = Color(0xFF3478C7);
  static const Color pacienteDark = Color(0xFF60A5FA);

  static const Color pediatriaLight = Color(0xFFC58A1A);
  static const Color pediatriaDark = Color(0xFFFBBF24);

  static const Color ferramentasLight = Color(0xFF465568);
  static const Color ferramentasDark = Color(0xFFB2C0D0);

  static const Color historiaLight = Color(0xFF0F766E);
  static const Color historiaDark = Color(0xFF2DD4BF);

  static const Color avaliacaoLight = Color(0xFF16845B);
  static const Color avaliacaoDark = Color(0xFF34D399);

  static const Color notasLight = Color(0xFF7659B8);
  static const Color notasDark = Color(0xFFA78BFA);

  static const Color timerLight = Color(0xFFC64A4A);
  static const Color timerDark = Color(0xFFFB7185);

  static const Color plantaoLight = Color(0xFF087A55);
  static const Color plantaoDark = Color(0xFF34D399);

  static const Color cardioLight = Color(0xFFC64A52);
  static const Color cardioDark = Color(0xFFFB7185);

  static const Color nefroLight = Color(0xFF267EAE);
  static const Color nefroDark = Color(0xFF38BDF8);

  static const Color hepatoLight = Color(0xFFC97828);
  static const Color hepatoDark = Color(0xFFFB923C);

  static Color farmacos(bool dark) {
    return dark ? farmacosDark : farmacosLight;
  }

  static Color paciente(bool dark) {
    return dark ? pacienteDark : pacienteLight;
  }

  static Color pediatria(bool dark) {
    return dark ? pediatriaDark : pediatriaLight;
  }

  static Color ferramentas(bool dark) {
    return dark ? ferramentasDark : ferramentasLight;
  }

  static Color historia(bool dark) {
    return dark ? historiaDark : historiaLight;
  }

  static Color avaliacao(bool dark) {
    return dark ? avaliacaoDark : avaliacaoLight;
  }

  static Color notas(bool dark) {
    return dark ? notasDark : notasLight;
  }

  static Color timer(bool dark) {
    return dark ? timerDark : timerLight;
  }

  static Color plantao(bool dark) {
    return dark ? plantaoDark : plantaoLight;
  }

  static Color cardio(bool dark) {
    return dark ? cardioDark : cardioLight;
  }

  static Color nefro(bool dark) {
    return dark ? nefroDark : nefroLight;
  }

  static Color hepato(bool dark) {
    return dark ? hepatoDark : hepatoLight;
  }
}
