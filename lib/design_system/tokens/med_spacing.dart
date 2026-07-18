import 'package:flutter/widgets.dart';

/// Escala oficial de espaçamento do MedCases Next.
abstract final class MedSpacing {
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double x2l = 32;
  static const double x3l = 48;
  static const double x4l = 64;

  static const EdgeInsets pageMobile = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: lg,
  );

  static const EdgeInsets pageTablet = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: xl,
  );

  static const EdgeInsets pageDesktop = EdgeInsets.symmetric(
    horizontal: x2l,
    vertical: xl,
  );

  static const EdgeInsets card = EdgeInsets.all(lg);
  static const EdgeInsets cardCompact = EdgeInsets.all(md);
  static const EdgeInsets field = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
}
