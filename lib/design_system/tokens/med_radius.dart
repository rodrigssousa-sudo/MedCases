import 'package:flutter/widgets.dart';

/// Escala oficial de raios do MedCases Next.
abstract final class MedRadius {
  static const double noneValue = 0;
  static const double smallValue = 4;
  static const double mediumValue = 8;
  static const double largeValue = 12;
  static const double xLargeValue = 16;
  static const double pillValue = 999;

  static const BorderRadius none = BorderRadius.zero;
  static const BorderRadius small = BorderRadius.all(
    Radius.circular(smallValue),
  );
  static const BorderRadius medium = BorderRadius.all(
    Radius.circular(mediumValue),
  );
  static const BorderRadius large = BorderRadius.all(
    Radius.circular(largeValue),
  );
  static const BorderRadius xLarge = BorderRadius.all(
    Radius.circular(xLargeValue),
  );
  static const BorderRadius pill = BorderRadius.all(
    Radius.circular(pillValue),
  );

  static BorderRadius circle(double diameter) {
    return BorderRadius.circular(diameter / 2);
  }
}
