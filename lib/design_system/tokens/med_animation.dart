import 'package:flutter/animation.dart';

import 'med_durations.dart';

/// Curvas e configurações oficiais de animação do MedCases Next.
abstract final class MedAnimation {
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve entrance = Curves.easeOutQuart;
  static const Curve exit = Curves.easeInCubic;

  static const Duration fade = MedDurations.normal;
  static const Duration slide = MedDurations.normal;
  static const Duration scale = MedDurations.fast;
  static const Duration hero = MedDurations.slow;
  static const Duration loading = MedDurations.verySlow;

  static const double hiddenOpacity = 0;
  static const double visibleOpacity = 1;
  static const double pressedScale = 0.98;
  static const double initialEntranceScale = 0.96;
}
